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
KEY = r"['\"]?([A-Za-z0-9_-]+)['\"]?:[ ]*(?:#.*)?$"

errors = []
workflows = sorted(WF.glob("*.yml")) + sorted(WF.glob("*.yaml"))
for path in workflows:
    lines = [line for line in path.read_text().splitlines() if not line.lstrip().startswith("#")]
    text = "\n".join(lines) + "\n"
    jobs_at = next((i for i, line in enumerate(lines) if re.match(r"^jobs:[ ]*(?:#.*)?$", line)), None)
    if jobs_at is None:
        if CREDENTIAL.search(text):
            errors.append(f"{path.name}: credential referenced but jobs: block not recognised")
        continue
    if CREDENTIAL.search("\n".join(lines[:jobs_at])):
        errors.append(f"{path.name}: credential exposed outside a job (workflow-level env)")
    body = lines[jobs_at + 1:]
    # Job keys sit at the indentation of the first key under `jobs:` (any width).
    first = next((line for line in body if line.strip()), "")
    indent = len(first) - len(first.lstrip())
    job_key = re.compile(rf"^[ ]{{{indent}}}{KEY}")
    env_inline = re.compile(rf"^[ ]{{{indent + 2}}}environment:[ ]*['\"]?production['\"]?[ ]*(?:#.*)?$", re.M)
    env_block = re.compile(
        rf"^[ ]{{{indent + 2}}}environment:[ ]*(?:#.*)?\n[ ]{{{indent + 4}}}name:[ ]*['\"]?production['\"]?[ ]*(?:#.*)?$", re.M
    )
    jobs, current, end = [], None, len(body)
    for index, line in enumerate(body):
        if line.strip() and len(line) - len(line.lstrip()) < indent:
            end = index  # next top-level key ends the jobs block
            break
        match = job_key.match(line) if indent else None
        if match:
            current = [match.group(1), []]
            jobs.append(current)
        elif current is None:
            if CREDENTIAL.search(line):
                errors.append(f"{path.name}: credential appears before the first recognised job")
        else:
            current[1].append(line)
    if CREDENTIAL.search("\n".join(body[end:])):
        errors.append(f"{path.name}: credential appears outside a recognised job")
    for job, job_lines in jobs:
        job_body = "\n".join(job_lines)
        if CREDENTIAL.search(job_body) and not (env_inline.search(job_body) or env_block.search(job_body)):
            errors.append(f"{path.name}: job '{job}' reads a production credential without environment: production")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"PASS production credentials are environment-scoped in {len(workflows)} workflows")
