#!/usr/bin/env python3
"""Fail-closed regression gate for the WYNOS all-features-before-production freeze.

The ZOKY exception and edge deploy workflows are checked on their parsed YAML
(PyYAML, required; fails closed without it). Not a substitute for reviewer /
GitHub production environment approvals.
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
    overwrite the other), and refuse duplicate keys outright. Same loader as
    tools/check_production_secret_scoping.py (#1225)."""


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

# These historic one-shot promotions must never silently redeploy on push.
for retired in ("admin-control-centers-one-time-release.yml", "web-promote-public-features.yml"):
    assert not (WF / retired).exists(), f"Legacy auto-production release still exists: {retired}"

acceptance = [str(x) for x in range(1142, 1152)]
script = (ROOT / ".github" / "scripts" / "require-wynos-final-release-ready.sh").read_text()
for issue in acceptance:
    assert issue in script.split("for issue in", 1)[1].split("do", 1)[0], f"Missing acceptance issue {issue}"

legacy = ["deploy-admin.yml", "deploy-web.yml", "web-next-phase5-production.yml"]
for name in legacy:
    workflow = (WF / name).read_text()
    assert "workflow_dispatch:" in workflow, f"{name}: manual-only trigger absent"
    assert "    if:" in workflow, f"{name}: explicit branch and release gate absent"
    assert "inputs.release_confirmation == 'RELEASE_ALL_APPROVED'" in workflow, (
        f"{name}: required confirmation missing"
    )
    assert "environment: production" in workflow, f"{name}: requires protected production environment"
    assert "Enforce WYNOS final cross-system release freeze" in workflow, (
        f"{name}: shared acceptance guard not invoked"
    )
    assert "require-wynos-final-release-ready.sh" in workflow
    assert "issues: read" in workflow, f"{name}: cannot fetch acceptance issues"
    trigger = workflow.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
    assert "  push:" not in trigger, f"{name}: unexpected push-based production deploy"

for name in ("wynos-admin-consolidated-release.yml", "wyn-158-production-deploy.yml"):
    workflow = (WF / name).read_text()
    assert "workflow_dispatch:" in workflow
    assert "RELEASE_ALL_APPROVED" in workflow
    assert "environment: production" in workflow
    for issue in acceptance:
        assert issue in workflow, f"{name}: acceptance issue #{issue} absent"
    trigger = workflow.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
    assert "  push:" not in trigger, f"{name}: unexpected push deployment"

def load_workflow(path):
    """Parse a workflow as YAML (anchors/aliases resolved, comments dropped)."""
    try:
        data = yaml.load(path.read_text(), Loader=WorkflowLoader)
    except yaml.YAMLError as error:
        raise AssertionError(f"{path.name}: rejected YAML ({error})") from None
    assert isinstance(data, dict), f"{path.name}: not a YAML mapping"
    return data


def trigger_of(workflow):
    return workflow.get("on")


def as_list(value):
    return value if isinstance(value, list) else [value]


def steps_of(job):
    steps = job.get("steps")
    assert isinstance(steps, list) and all(isinstance(step, dict) for step in steps), "steps must be a list of mappings"
    return steps


def runs_of(job):
    return [str(step["run"]) for step in steps_of(job) if "run" in step]


def shell_text(job):
    return "\n".join(runs_of(job))


def uses(step, action):
    return str(step.get("uses", "")).split("@", 1)[0] == action


# Deny by default (Codex #1226): no ${{ }} expression of any kind in a run
# body (inputs, github.event, format() ... reach the shell only via env:), and
# no use of the secrets context outside the gated jobs' literal references.
EXPRESSION = re.compile(r"\$\{\{(.*?)\}\}", re.S)
SECRETS_WORD = re.compile(r"(?<![A-Za-z0-9_.-])secrets(?![A-Za-z0-9_-])", re.I)
LITERAL_SECRET = re.compile(r"""secrets\s*(?:\.\s*([A-Za-z_][A-Za-z0-9_]*)|\[\s*['"]([A-Za-z_][A-Za-z0-9_]*)['"]\s*\])""", re.I)


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


def expressions(value):
    return [expression for text in strings(value) for expression in EXPRESSION.findall(text)]


def secrets_key(value):
    if isinstance(value, dict):
        return "secrets" in value or any(secrets_key(item) for item in value.values())
    if isinstance(value, list):
        return any(secrets_key(item) for item in value)
    return False


def any_secrets(value):
    """Any reference to the secrets context, literal or dynamic, or `secrets:` (inherit)."""
    return secrets_key(value) or any(SECRETS_WORD.search(expression) for expression in expressions(value))


def dynamic_secrets(value):
    """Secrets used other than as a literal secrets.NAME / secrets['NAME']."""
    return secrets_key(value) or any(SECRETS_WORD.search(LITERAL_SECRET.sub("", e)) for e in expressions(value))


def literal_secret_names(value):
    return {a or b for e in expressions(value) for a, b in LITERAL_SECRET.findall(e)}

EXPIRY_TEST = '[[ "$today" > "$ZOKY_EXCEPTION_EXPIRES_UTC" ]]'

# Deny by default (Codex #1226 4308136674): the workflow-level constants may
# not be redefined anywhere else, and nothing may skip or soften a step.
ALLOWED_TOP_KEYS = {"name", "on", "permissions", "concurrency", "env", "jobs"}
ALLOWED_JOB_KEYS = {"name", "needs", "if", "environment", "runs-on", "defaults", "steps"}
ALLOWED_STEP_KEYS = {"name", "id", "if", "uses", "with", "run", "env", "working-directory"}
ALLOWED_ACTIONS = {"actions/checkout@v4", "actions/setup-node@v4", "denoland/setup-deno@v2", "supabase/setup-cli@v1"}
ALLOWED_STEP_ENV = {
    "RELEASE_SHA", "PHASE", "FIREBASE_SUPPLIED", "NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
    "VERCEL_TOKEN", "VERCEL_ORG_ID", "VERCEL_PROJECT_ID", "SUPABASE_ACCESS_TOKEN", "SUPABASE_URL",
    "SUPABASE_PUBLISHABLE_KEY", "FIREBASE_WEB_API_KEY", "FIREBASE_WEB_APP_ID", "FIREBASE_MESSAGING_SENDER_ID",
    "FIREBASE_PROJECT_ID", "FIREBASE_AUTH_DOMAIN", "FIREBASE_STORAGE_BUCKET", "FIREBASE_VAPID_KEY",
}
ALLOWED_STEP_IFS = {("guard", "Domain and phase preconditions"): "inputs.phase != 'EDGE'"}
ENV_FILE_WRITE = re.compile(r"GITHUB_ENV|GITHUB_PATH|BASH_ENV", re.I)
# Builtins that can (re)assign a variable by a computed name.
INDIRECT = re.compile(
    r"(?:^|[;&|(]|\b(?:then|do|else|elif)\b)\s*(?:eval|declare|typeset|readonly|local|let|export|unset|source|\.|read)(?=\s|$)"
    r"|printf\s+-v", re.M,
)
ALLOWED_READ = "while IFS= read -r file; do"
PIN_CHECK = (
    "python3 -c 'import sys, tomllib; c = tomllib.load(open(\"supabase/config.toml\", \"rb\")); "
    "sys.exit(0 if c.get(\"functions\", {}).get(\"wynos-maps-geocode\", {}).get(\"verify_jwt\") is False else 1)'"
)

# Founder-approved ZOKY-only freeze exception (DECISIONS 2026-10-18, Option A).
# The file may be deleted (exception closed); while it exists its scope guards
# must stay intact. Structural checks run on the parsed YAML, per job (CTO
# review R3; Codex #1226: text parsing missed quoted/flow/aliased job keys).
zoky = WF / "zoky-web-exception-release.yml"
if zoky.exists():
    name = zoky.name
    wf = load_workflow(zoky)
    trigger = trigger_of(wf)
    assert isinstance(trigger, dict) and set(trigger) == {"workflow_dispatch"}, f"{name}: must be workflow_dispatch only"
    inputs = (trigger["workflow_dispatch"] or {}).get("inputs") or {}
    assert inputs.get("phase", {}).get("type") == "choice" and inputs["phase"].get("options") == ["EDGE", "PHASE1", "PHASE2"], (
        f"{name}: phase options changed"
    )
    assert inputs.get("confirmation", {}).get("options") == ["CANCEL", "ZOKY_FREEZE_EXCEPTION_20261018"], (
        f"{name}: confirmation options changed"
    )
    assert wf.get("permissions") == {"contents": "read"}, f"{name}: permissions must stay contents: read"

    wyn158 = load_workflow(WF / "wyn-158-production-deploy.yml")
    assert wf.get("concurrency") == {"group": "zoky-web-exception-release", "cancel-in-progress": False, "queue": "max"}, (
        f"{name}: concurrency must be group zoky-web-exception-release, cancel-in-progress false, queue max"
    )
    assert wf["concurrency"]["group"] != (wyn158.get("concurrency") or {}).get("group"), (
        f"{name}: must not share wyn-158's cancel-in-progress lane"
    )

    assert set(wf) <= ALLOWED_TOP_KEYS, f"{name}: unexpected top-level keys {sorted(set(wf) - ALLOWED_TOP_KEYS)}"
    env = wf.get("env") or {}
    constants = {str(key) for key in env}
    for key, value in {
        "ZOKY_EXCEPTION_EXPIRES_UTC": "2026-11-30",
        "ZOKY_RELEASE_BRANCH": "release/zoky-web-20261018",
        "ZOKY_PRODUCTION_BASE_SHA": "b19687afdec361da846a2d9ceb11429547c92a24",
        "ZOKY_EXCLUDED_SHAS": "806390ed8ab56810c6141b925e6b8aa6eb3eca49 55a290e9168ac8b82b5656cecf9ff10f4fce7bc0",
        "ZOKY_EDGE_FUNCTIONS": "food-stripe-checkout food-stripe-cancel wynos-maps-geocode",
    }.items():
        assert env.get(key) == value, f"{name}: {key} changed or removed"

    jobs = wf.get("jobs")
    assert isinstance(jobs, dict) and set(jobs) == {"guard", "deploy", "edge"} and all(
        isinstance(job, dict) for job in jobs.values()
    ), f"{name}: jobs must be exactly guard + deploy + edge, got {sorted(jobs or {})}"
    guard_job, deploy_job, edge_job = jobs["guard"], jobs["deploy"], jobs["edge"]
    gate = "github.ref == 'refs/heads/main' && inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018'"
    expected_if = {
        "guard": gate,
        "deploy": gate + " && inputs.phase != 'EDGE'",
        "edge": gate + " && inputs.phase == 'EDGE'",
    }
    for job_name, job in jobs.items():
        assert job.get("if") == expected_if[job_name], f"{name}: {job_name} job lost its main-only + confirmation + phase gate"
        assert "env" not in job, f"{name}: {job_name} job-level env could override the workflow constants"
        assert set(job) <= ALLOWED_JOB_KEYS, f"{name}: {job_name} job must not set {sorted(set(job) - ALLOWED_JOB_KEYS)}"
        expected_defaults = {"run": {"working-directory": "web"}} if job_name == "deploy" else None
        assert job.get("defaults") == expected_defaults, f"{name}: {job_name} job defaults changed"
        for step in steps_of(job):
            step_name = str(step.get("name", step.get("uses", "")))
            assert set(step) <= ALLOWED_STEP_KEYS, f"{name}: {job_name}/{step_name} must not set {sorted(set(step) - ALLOWED_STEP_KEYS)}"
            assert "uses" not in step or step["uses"] in ALLOWED_ACTIONS, f"{name}: {job_name} uses an unapproved action {step.get('uses')}"
            assert step.get("if") == ALLOWED_STEP_IFS.get((job_name, step_name)), f"{name}: {job_name}/{step_name} step if changed"
            step_env = {str(key) for key in (step.get("env") or {})}
            clash = {key for key in step_env if key.upper() in {c.upper() for c in constants}}
            assert not clash, f"{name}: {job_name}/{step_name} env redefines workflow constants {sorted(clash)}"
            assert step_env <= ALLOWED_STEP_ENV, f"{name}: {job_name}/{step_name} unexpected env {sorted(step_env - ALLOWED_STEP_ENV)}"
            body = str(step.get("run", ""))
            assert not ENV_FILE_WRITE.search(body), f"{name}: {job_name}/{step_name} must not touch GITHUB_ENV/GITHUB_PATH/BASH_ENV"
            reads_constant = False
            for constant in constants:
                for match in re.finditer(re.escape(constant), body, re.I):
                    before = body[max(0, match.start() - 2):match.start()]
                    assert before.endswith("$") or before.endswith("${"), (
                        f"{name}: {job_name}/{step_name} may only read {constant} (found a non-read use)"
                    )
                    reads_constant = True
            if reads_constant:
                assert not INDIRECT.search(body.replace(ALLOWED_READ, "")), (
                    f"{name}: {job_name}/{step_name} reads workflow constants, so it may not use eval/declare/export/unset/read/source/printf -v"
                )
        first = steps_of(job)[0]
        assert first.get("name") == "Exception has not expired" and EXPIRY_TEST in str(first.get("run", "")), (
            f"{name}: {job_name} must start with the expiry check"
        )
        assert shell_text(job).count(EXPIRY_TEST) == 1, f"{name}: {job_name} expiry comparison removed"
        for body in runs_of(job):
            assert "${{" not in body, f"{name}: no ${{{{ }}}} expressions in run bodies; pass values via env: ({body.strip()[:60]})"

    assert "environment" not in guard_job and "needs" not in guard_job, f"{name}: guard job must run before (not inside) the review"
    assert not any_secrets(guard_job), f"{name}: guard job must not read secrets"
    assert not any_secrets({key: value for key, value in wf.items() if key != "jobs"}), (
        f"{name}: secrets outside jobs would reach the guard job"
    )
    for job_name in ("deploy", "edge"):
        assert not dynamic_secrets(jobs[job_name]), f"{name}: {job_name} may only name secrets literally"
    assert literal_secret_names(edge_job) <= {"SUPABASE_ACCESS_TOKEN", "SUPABASE_URL"}, (
        f"{name}: edge job may only read SUPABASE_ACCESS_TOKEN and SUPABASE_URL"
    )
    for job_name in ("deploy", "edge"):
        job = jobs[job_name]
        assert job.get("environment") == "production", f"{name}: {job_name} job must use the protected production environment"
        assert as_list(job.get("needs")) == ["guard"], f"{name}: {job_name} must wait for scope guards"
        checkouts = [step for step in steps_of(job) if uses(step, "actions/checkout")]
        assert len(checkouts) == 1 and (checkouts[0].get("with") or {}).get("ref") == "${{ inputs.release_sha }}", (
            f"{name}: {job_name} must check out the pinned release_sha"
        )
        assert 'test "$(git rev-parse HEAD)" = "$RELEASE_SHA"' in shell_text(job), f"{name}: {job_name} must re-verify HEAD"

    all_steps = [step for job in jobs.values() for step in steps_of(job)]
    checkouts = [step for step in all_steps if uses(step, "actions/checkout")]
    assert len(checkouts) == 3 and all((step.get("with") or {}).get("persist-credentials") is False for step in checkouts), (
        f"{name}: every checkout must set persist-credentials: false"
    )
    dumped = json.dumps(wf)
    assert "vercel@latest" not in dumped and "npx --yes vercel@63.1.2 deploy --prod" in shell_text(deploy_job), (
        f"{name}: Vercel CLI must stay pinned"
    )

    guard_text, deploy_text, edge_text = shell_text(guard_job), shell_text(deploy_job), shell_text(edge_job)
    for check in (
        "^[0-9a-f]{40}$",
        'git merge-base --is-ancestor "$ZOKY_PRODUCTION_BASE_SHA" "$RELEASE_SHA"',
        "web/lib/food-home-banners.ts web/lib/food-featured-stores.ts",
        "Out-of-scope path in release",
        "git diff --no-renames --name-only",
        'case "$PHASE" in EDGE|PHASE1|PHASE2) ;; *)',
        "verify_jwt = false|#.*|",
    ):
        assert check in guard_text, f"{name}: guard job missing: {check}"
    assert "verify_jwt = (true" not in guard_text, f"{name}: guard must only allow the verify_jwt = false geocode entry"
    assert "npm run qa:browser" in deploy_text, f"{name}: deploy job missing: npm run qa:browser"

    # PHASE1/PHASE2 pin ZOKY_LEGACY_FOOD_REDIRECT on the deployment (Codex P1).
    vercel = [step for step in steps_of(deploy_job) if "vercel@" in str(step.get("run", ""))]
    assert len(vercel) == 1 and (vercel[0].get("env") or {}).get("PHASE") == "${{ inputs.phase }}", (
        f"{name}: the Vercel deploy step must read the phase via env:"
    )
    for check in ("PHASE1) legacy_redirect=0 ;;", "PHASE2) legacy_redirect=1 ;;", '--env ZOKY_LEGACY_FOOD_REDIRECT="$legacy_redirect"'):
        assert check in vercel[0]["run"], f"{name}: deploy job must pin ZOKY_LEGACY_FOOD_REDIRECT per phase ({check})"
    assert dumped.count("legacy_redirect=") == 2, f"{name}: ZOKY_LEGACY_FOOD_REDIRECT mapping changed"

    # Edge phase: only the 3 allowlisted functions, pinned CLI, verify_jwt pin.
    deploy_steps = [step for step in all_steps if "functions deploy" in str(step.get("run", ""))]
    assert len(deploy_steps) == 1 and deploy_steps[0] in steps_of(edge_job) and (
        "for fn in $ZOKY_EDGE_FUNCTIONS; do" in deploy_steps[0]["run"]
        and 'supabase functions deploy "$fn" --project-ref "$PROJECT_REF"' in deploy_steps[0]["run"]
    ) and dumped.count("functions deploy") == 1, f"{name}: edge job may only deploy the allowlisted functions"
    assert "--no-verify-jwt" not in dumped, f"{name}: verify_jwt must come from supabase/config.toml"
    assert PIN_CHECK in edge_text, f"{name}: edge job lost the wynos-maps-geocode verify_jwt = false pin"
    clis = [step for step in all_steps if uses(step, "supabase/setup-cli")]
    assert len(clis) == 1 and clis[0] in steps_of(edge_job) and str((clis[0].get("with") or {}).get("version")) == "2.120.0", (
        f"{name}: Supabase CLI must stay pinned"
    )
    assert "VERCEL" not in json.dumps(edge_job).upper(), f"{name}: edge job must not read Vercel credentials"
    assert "ZOKY_FREEZE_EXCEPTION" not in (WF / "wyn-158-production-deploy.yml").read_text(), (
        "wyn-158-production-deploy.yml must not carry the ZOKY exception"
    )

# Production edge deploys are Founder-gated and cannot ship wynos-maps-geocode
# without verify_jwt = false pinned in config.toml (CTO review R2; Founder F2).
edge_name = "deploy-edge-functions.yml"
edge_wf = load_workflow(WF / edge_name)
edge_jobs = edge_wf.get("jobs")
assert isinstance(edge_jobs, dict) and set(edge_jobs) == {"deploy"}, f"{edge_name}: unexpected jobs {sorted(edge_jobs or {})}"
edge_deploy = edge_jobs["deploy"]
assert edge_deploy.get("environment") == "production", f"{edge_name}: deploy job must use production environment"
edge_steps = [str(step.get("name")) for step in steps_of(edge_deploy)]
pin_step, deploy_step = "wynos-maps-geocode verify_jwt is pinned", "Deploy"
assert pin_step in edge_steps and deploy_step in edge_steps, f"{edge_name}: verify_jwt pin step or Deploy step missing"
assert edge_steps.index(pin_step) < edge_steps.index(deploy_step), f"{edge_name}: verify_jwt pin must run before Deploy"
pin = steps_of(edge_deploy)[edge_steps.index(pin_step)]
assert PIN_CHECK in str(pin.get("run", "")), f"{edge_name}: verify_jwt = false pin check altered"
assert (pin.get("env") or {}).get("FUNCTION_NAME") == "${{ inputs.function }}", f"{edge_name}: pin step must read the input via env:"

# ZOKY-ADMIN-001: preview builds are allowed for QA. Production is a Founder
# exception to the freeze for ZOKY Admin only (2026-10-25): typed exception and
# production confirmations plus the protected environment.
zoky = load_workflow(WF / "deploy-zoky-admin.yml")
zoky_job = zoky["jobs"]["deploy"]
assert set(zoky["on"]) == {"workflow_dispatch"}, "deploy-zoky-admin.yml: manual-only trigger required"
assert zoky_job.get("environment") == "production", "deploy-zoky-admin.yml: protected environment required"
assert "inputs.release_confirmation == 'ZOKY_ADMIN_EXCEPTION_APPROVED'" in zoky_job["if"], "deploy-zoky-admin.yml: exception confirmation absent"
assert "inputs.target == 'preview'" in zoky_job["if"], "deploy-zoky-admin.yml: only preview may skip the release confirmation"
zoky_steps = {step.get("name"): step for step in zoky_job["steps"]}
zoky_verify = zoky_steps["Verify requested environment and link the existing project"]["run"]
assert "DEPLOY_ZOKY_ADMIN_PRODUCTION" in zoky_verify and '"$RELEASE_CONFIRMATION" != "ZOKY_ADMIN_EXCEPTION_APPROVED"' in zoky_verify
# The exception covers ZOKY Admin only: WYNOS Admin keeps the full freeze.
assert "--prod" in zoky_steps["Deploy"]["run"] and 'DEPLOY_TARGET" = production' in zoky_steps["Deploy"]["run"]
assert zoky_steps["Attach zoky-admin.wynos.online"].get("if") == "inputs.target == 'production'"

print("PASS coordinated final-release freeze: legacy promotions retired, acceptance gates active")
