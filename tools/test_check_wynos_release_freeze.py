#!/usr/bin/env python3
"""Regression test: the freeze guard fails when the ZOKY exception workflow is
loosened, and still passes when the exception workflow is deleted.

Runs the real guard against a temporary copy of the files it reads, so the
repository itself is never modified.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "tools/check_wynos_release_freeze.py"
ZOKY = ".github/workflows/zoky-web-exception-release.yml"


def run_guard(mutate=None):
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "tools").mkdir()
        shutil.copy(ROOT / GUARD, tmp / GUARD)
        shutil.copytree(ROOT / ".github", tmp / ".github")
        if mutate:
            mutate(tmp / ZOKY)
        result = subprocess.run([sys.executable, "-I", str(tmp / GUARD)], capture_output=True, text=True)
        return result.returncode, result.stdout + result.stderr


def replace(old, new):
    def mutate(path):
        text = path.read_text()
        assert old in text, f"test fixture drift: {old!r} not found"
        path.write_text(text.replace(old, new, 1))
    return mutate


code, out = run_guard()
assert code == 0, out

code, out = run_guard(lambda path: path.unlink())
assert code == 0, f"deleting the exception workflow must be allowed: {out}"

loosened = {
    "push trigger": replace("on:\n  workflow_dispatch:", "on:\n  push:\n    branches: [release/zoky-web-20261018]\n  workflow_dispatch:"),
    "no production environment": replace("environment: production", "environment: preview"),
    "main-only guard removed": replace("if: github.ref == 'refs/heads/main' && inputs.confirmation", "if: inputs.confirmation"),
    "expiry extended": replace('ZOKY_EXCEPTION_EXPIRES_UTC: "2026-11-30"', 'ZOKY_EXCEPTION_EXPIRES_UTC: "2027-12-31"'),
    "base SHA changed": replace("b19687afdec361da846a2d9ceb11429547c92a24", "42a8f9373fe900ff1de14b18cf0bc6ad8ae8b1de"),
    "#1133 exclusion removed": replace("806390ed8ab56810c6141b925e6b8aa6eb3eca49 ", ""),
    "path allowlist removed": replace("Out-of-scope path in release", "path note"),
    "write permission": replace("permissions:\n  contents: read", "permissions:\n  contents: write"),
    "cancels in-progress": replace("cancel-in-progress: false", "cancel-in-progress: true"),
    "deploys repo ref instead of pinned SHA": replace("ref: ${{ inputs.release_sha }}", "ref: main"),
    "guard job not required": replace("needs: guard", "needs: []"),
}
for label, mutate in loosened.items():
    code, out = run_guard(mutate)
    assert code != 0, f"freeze guard accepted a loosened exception workflow: {label}"

print(f"PASS freeze guard rejects {len(loosened)} loosened variants of {Path(ZOKY).name}")
