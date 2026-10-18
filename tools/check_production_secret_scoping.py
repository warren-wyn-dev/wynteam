#!/usr/bin/env python3
"""Fail-closed gate: production credentials are only readable behind the
Founder-reviewed `production` GitHub environment (Founder decision C1,
2026-10-18; .wyn/docs/engineering/deploy-secrets-environment-migration.md).

Every job that references secrets.SUPABASE_ACCESS_TOKEN or secrets.VERCEL_TOKEN
must declare `environment: production`, and those secrets may not be exposed
through workflow-level `env:`. A narrow structural text check (no YAML
dependency), not a substitute for the environment's reviewer/branch policy.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WF = ROOT / ".github" / "workflows"
CREDENTIAL = re.compile(r"secrets\.(SUPABASE_ACCESS_TOKEN|VERCEL_TOKEN)\b")
ENV_INLINE = re.compile(r"^    environment:[ ]*['\"]?production['\"]?[ ]*(#.*)?$", re.M)
ENV_BLOCK = re.compile(r"^    environment:[ ]*\n      name:[ ]*['\"]?production['\"]?[ ]*(#.*)?$", re.M)

errors = []
workflows = sorted(WF.glob("*.yml")) + sorted(WF.glob("*.yaml"))
for path in workflows:
    text = "\n".join(line for line in path.read_text().splitlines() if not line.lstrip().startswith("#")) + "\n"
    if "\njobs:\n" not in text:
        if CREDENTIAL.search(text):
            errors.append(f"{path.name}: credential referenced but jobs: block not recognised")
        continue
    head, body = text.split("\njobs:\n", 1)
    if CREDENTIAL.search(head):
        errors.append(f"{path.name}: credential exposed outside a job (workflow-level env)")
    parts = re.split(r"^  ([A-Za-z0-9_-]+):[ ]*$", body, flags=re.M)
    for i in range(1, len(parts), 2):
        job, job_body = parts[i], parts[i + 1]
        if CREDENTIAL.search(job_body) and not (ENV_INLINE.search(job_body) or ENV_BLOCK.search(job_body)):
            errors.append(f"{path.name}: job '{job}' reads a production credential without environment: production")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"PASS production credentials are environment-scoped in {len(workflows)} workflows")
