#!/usr/bin/env python3
"""Fail-closed gate: production credentials are only readable behind the
Founder-reviewed `production` GitHub environment (Founder decision C1,
2026-10-18; .wyn/docs/engineering/deploy-secrets-environment-migration.md).

Every job that mentions SUPABASE_ACCESS_TOKEN or VERCEL_TOKEN must declare
`environment: production`, and those names may not appear anywhere outside a
job. Workflows are parsed as YAML (anchors and aliases resolved, comments
dropped), and any case-insensitive mention of either name counts, whatever
the expression syntax or whitespace around it. Not a substitute for the
environment's reviewer/branch policy.
"""
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # fail closed: never pass without parsing
    sys.exit("PyYAML is required (python3-yaml); refusing to pass without parsing workflows")

ROOT = Path(__file__).resolve().parent.parent
WF = ROOT / ".github" / "workflows"
CREDENTIAL = re.compile(r"(?<![A-Za-z0-9_])(SUPABASE_ACCESS_TOKEN|VERCEL_TOKEN)(?![A-Za-z0-9_])", re.I)


# Deny by default: outside the production environment a job may only name a
# secret literally (secrets.NAME or secrets['NAME']). Any other use of the
# secrets context (format(), toJSON(secrets), secrets: inherit) could reach a
# production credential without spelling it out.
EXPRESSION = re.compile(r"\$\{\{(.*?)\}\}", re.S)
SECRETS_WORD = re.compile(r"(?<![A-Za-z0-9_.-])secrets(?![A-Za-z0-9_-])", re.I)
LITERAL_SECRET = re.compile(r"""secrets\s*(?:\.\s*[A-Za-z_][A-Za-z0-9_]*|\[\s*['"][A-Za-z_][A-Za-z0-9_]*['"]\s*\])""", re.I)


def strings(value):
    if isinstance(value, dict):
        for key, item in value.items():
            yield str(key)
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif value is not None:
        yield str(value)


def dynamic_secrets(value):
    if isinstance(value, dict):
        if str(value.get("secrets", "")).strip().lower() == "inherit":
            return True
        return any(dynamic_secrets(item) for item in value.values())
    if isinstance(value, list):
        return any(dynamic_secrets(item) for item in value)
    return any(
        SECRETS_WORD.search(LITERAL_SECRET.sub("", expression))
        for text in strings(value)
        for expression in EXPRESSION.findall(text)
    )


def mentions(value):
    return bool(CREDENTIAL.search(json.dumps(value, default=str))) or dynamic_secrets(value)


def gated(job):
    env = job.get("environment")
    if isinstance(env, dict):
        env = env.get("name")
    return env == "production"


errors = []
workflows = sorted(WF.glob("*.yml")) + sorted(WF.glob("*.yaml"))
for path in workflows:
    try:
        doc = yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        errors.append(f"{path.name}: not parseable YAML ({exc.__class__.__name__})")
        continue
    if not isinstance(doc, dict):
        if mentions(doc):
            errors.append(f"{path.name}: credential referenced but workflow is not a mapping")
        continue
    jobs = doc.get("jobs")
    if mentions({key: value for key, value in doc.items() if key != "jobs"}):
        errors.append(f"{path.name}: credential appears outside a job")
    if not isinstance(jobs, dict):
        if mentions(jobs):
            errors.append(f"{path.name}: credential referenced but jobs: is not a mapping")
        continue
    for name, job in jobs.items():
        if not mentions(job):
            continue
        if not isinstance(job, dict) or not gated(job):
            errors.append(f"{path.name}: job '{name}' reads a production credential without environment: production")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"PASS production credentials are environment-scoped in {len(workflows)} workflows")
