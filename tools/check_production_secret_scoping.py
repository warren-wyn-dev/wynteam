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

class WorkflowLoader(yaml.SafeLoader):
    """Read mapping keys as GitHub does: plain strings (PyYAML's YAML 1.1
    resolver turns keys like `on`/`yes` into True and lets one silently
    overwrite the other), and refuse duplicate keys outright."""


def _construct_mapping(loader, node, deep=False):
    loader.flatten_mapping(node)  # resolve `<<` merge keys first
    mapping = {}
    for key_node, value_node in node.value:
        key = key_node.value if isinstance(key_node, yaml.ScalarNode) else loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise yaml.constructor.ConstructorError(None, None, f"duplicate key {key!r}", key_node.start_mark)
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


WorkflowLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_mapping)

ROOT = Path(__file__).resolve().parent.parent
WF = ROOT / ".github" / "workflows"
CREDENTIAL = re.compile(r"(?<![A-Za-z0-9_])(SUPABASE_ACCESS_TOKEN|VERCEL_TOKEN)(?![A-Za-z0-9_])", re.I)


# Deny by default: outside the production environment a job may only name a
# secret literally (secrets.NAME or secrets['NAME']). Any other use of the
# secrets context (format(), toJSON(secrets), secrets: inherit) could reach a
# production credential without spelling it out.
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
    """True when any string (mapping keys included) uses the secrets context
    other than as a literal secrets.NAME / secrets['NAME']. Deliberately does
    not try to find where an expression ends: everything from the first `${{`
    to the end of the string is treated as expression text, so quoted `}}`
    tricks cannot hide a later reference."""
    if isinstance(value, dict) and str(value.get("secrets", "")).strip().lower() == "inherit":
        return True
    if isinstance(value, dict):
        return any(dynamic_secrets(item) for item in value.values()) or any(
            dynamic_secrets(str(key)) for key in value
        )
    if isinstance(value, list):
        return any(dynamic_secrets(item) for item in value)
    for text in strings(value):
        start = text.find("${{")
        if start != -1 and SECRETS_WORD.search(LITERAL_SECRET.sub("", text[start:])):
            return True
    return False


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
        doc = yaml.load(path.read_text(), Loader=WorkflowLoader)
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
