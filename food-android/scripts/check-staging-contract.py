#!/usr/bin/env python3
"""Fail-closed, OFFLINE Food staging metadata gate. This never connects or writes."""
import argparse
import json
import re
import sys
from pathlib import Path


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def audit_contract(manifest, snapshot, scope="full"):
    if scope not in ("foundation", "full"):
        raise ValueError("invalid scope")
    failures = []
    ref = snapshot.get("project_ref", "")
    if not isinstance(ref, str) or re.fullmatch(r"[a-z0-9]{20}", ref) is None:
        failures.append("invalid project ref")
    if ref == manifest["protectedProductionRef"]:
        failures.append("REFUSED: production project is not staging")

    selected = lambda x: scope == "full" or x["scope"] == "foundation"
    funcs = {v["name"]: v for v in snapshot.get("functions", []) if isinstance(v, dict) and "name" in v}
    tables = {v["name"]: v for v in snapshot.get("tables", []) if isinstance(v, dict) and "name" in v}
    edges = set(snapshot.get("edge_functions", []))

    for expected in manifest["rpcs"]:
        if not selected(expected):
            continue
        name = expected["name"]
        found = funcs.get(name)
        if found is None:
            failures.append("MISSING RPC " + name)
            continue
        actual_args = found.get("arguments", "")
        params = set(re.findall(r"\b(p_[a-z0-9_]+)\s+", actual_args))
        missing = set(expected.get("parameters", [])) - params
        if missing:
            failures.append("RPC SIGNATURE " + name + ": " + ", ".join(sorted(missing)))

    for expected in manifest["tables"]:
        if not selected(expected):
            continue
        name = expected["name"]
        found = tables.get(name)
        if found is None:
            failures.append("MISSING TABLE " + name)
        elif found.get("rls_enabled") is not True:
            failures.append("RLS DISABLED " + name)

    for expected in manifest["edgeFunctions"]:
        if selected(expected) and expected["name"] not in edges:
            failures.append("MISSING EDGE FUNCTION " + expected["name"])
    return failures


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--snapshot", required=True, help="Explicit NON-production metadata snapshot JSON")
    ap.add_argument("--scope", choices=("foundation", "full"), default="full")
    ap.add_argument("--manifest", default=str(Path(__file__).resolve().parents[1] / "phase1" / "contract_manifest.json"))
    args = ap.parse_args(argv)
    try:
        manifest = load(args.manifest)
        snapshot = load(args.snapshot)
        errors = audit_contract(manifest, snapshot, args.scope)
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print("BLOCKED: invalid contract snapshot: " + str(exc), file=sys.stderr)
        return 2
    print("Scope=" + args.scope + " project=" + snapshot["project_ref"])
    for err in errors:
        print("BLOCKED: " + err)
    if errors:
        print("NOT READY: " + str(len(errors)) + " missing/unsafe metadata checks")
        return 1
    print("METADATA PRESENT ONLY. Not a certificate for buyer RLS, E2E, Stripe Test Mode or release.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
