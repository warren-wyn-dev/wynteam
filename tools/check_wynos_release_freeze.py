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
    data = yaml.safe_load(path.read_text())
    assert isinstance(data, dict), f"{path.name}: not a YAML mapping"
    return data


def trigger_of(workflow):
    # PyYAML (YAML 1.1) reads the bare key `on` as boolean True.
    return workflow.get("on", workflow.get(True))


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


INPUT_IN_SHELL = re.compile(r"\$\{\{[^}]*\binputs\.|github\.event\.inputs", re.I)
SECRET_REF = re.compile(r"secrets\s*[.\[]", re.I)
EXPIRY_TEST = '[[ "$today" > "$ZOKY_EXCEPTION_EXPIRES_UTC" ]]'
PIN_AWK = (
    "awk '/^\\[/ { s = ($0 == \"[functions.wynos-maps-geocode]\") } "
    "s && /^verify_jwt[[:space:]]*=[[:space:]]*false[[:space:]]*$/ { f = 1 } END { exit !f }' supabase/config.toml"
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

    env = wf.get("env") or {}
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
        for key in ("permissions", "concurrency", "uses", "strategy", "container", "services"):
            assert key not in job, f"{name}: {job_name} job must not set {key}"
        first = steps_of(job)[0]
        assert first.get("name") == "Exception has not expired" and EXPIRY_TEST in str(first.get("run", "")), (
            f"{name}: {job_name} must start with the expiry check"
        )
        assert shell_text(job).count(EXPIRY_TEST) == 1, f"{name}: {job_name} expiry comparison removed"
        for body in runs_of(job):
            assert not INPUT_IN_SHELL.search(body), f"{name}: inputs must reach run steps only via env: ({body.strip()[:60]})"

    assert "environment" not in guard_job and "needs" not in guard_job, f"{name}: guard job must run before (not inside) the review"
    assert not SECRET_REF.search(json.dumps(guard_job)), f"{name}: guard job must not read secrets"
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
    assert PIN_AWK in edge_text, f"{name}: edge job lost the wynos-maps-geocode verify_jwt = false pin"
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
assert PIN_AWK in str(pin.get("run", "")), f"{edge_name}: verify_jwt = false pin check altered"
assert (pin.get("env") or {}).get("FUNCTION_NAME") == "${{ inputs.function }}", f"{edge_name}: pin step must read the input via env:"

print("PASS coordinated final-release freeze: legacy promotions retired, acceptance gates active")
