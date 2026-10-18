#!/usr/bin/env python3
"""Fail-closed regression gate for the WYNOS all-features-before-production freeze.

This is an intentionally narrow source-code structural check, not a YAML parser
or a substitute for reviewer / GitHub production environment approvals.
"""
import re
from pathlib import Path

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

def uncommented(text):
    """Drop full-line comments so a commented-out line never satisfies a check."""
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))


def scalar(value):
    """Plain YAML scalar without a trailing ` # comment`."""
    return re.sub(r"\s+#.*$", "", value).strip()


def top_level_block(text, key):
    match = re.search(rf"^{key}:\n((?:[ ]{{2}}.*\n?)*)", text, re.M)
    return match.group(1) if match else None


def block_value(block, key):
    values = re.findall(rf"^[ ]{{2}}{key}:[ ]*(\S.*?)\s*$", block or "", re.M)
    return scalar(values[0]) if len(values) == 1 else None


def jobs_of(text):
    """Map job id -> uncommented job body, split on 2-space-indented keys under `jobs:`."""
    body = text.split("\njobs:\n", 1)[1]
    parts = re.split(r"^  ([A-Za-z0-9_-]+):[ ]*$", body, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def job_key(job, key):
    return [scalar(v) for v in re.findall(rf"^[ ]{{4}}{key}:[ ]*(.*?)\s*$", job, re.M)]


def run_bodies(text):
    """Yield the shell text of every `run:` key (inline or block scalar)."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        match = re.match(r"^(\s*)(- )?run:[ ]*(.*)$", line)
        if not match:
            continue
        column = len(match.group(1)) + len(match.group(2) or "")
        value = match.group(3)
        if value[:1] not in ("|", ">"):
            yield value
            continue
        body = []
        for following in lines[i + 1:]:
            if following.strip() and len(following) - len(following.lstrip()) <= column:
                break
            body.append(following)
        yield "\n".join(body)


def step_names(job):
    return [scalar(v) for v in re.findall(r"^[ ]{6}- name:[ ]*(.*?)\s*$", job, re.M)]


INPUT_IN_SHELL = re.compile(r"\$\{\{[^}]*\binputs\.|github\.event\.inputs")
EXPIRY_TEST = '[[ "$today" > "$ZOKY_EXCEPTION_EXPIRES_UTC" ]]'

# Founder-approved ZOKY-only freeze exception (DECISIONS 2026-10-18, Option A).
# The file may be deleted (exception closed); while it exists its scope guards
# must stay intact. Checks are per job (CTO review R3), not per file.
zoky = WF / "zoky-web-exception-release.yml"
if zoky.exists():
    raw = zoky.read_text()
    workflow = uncommented(raw)
    trigger = workflow.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
    for forbidden in ("  push:", "  pull_request", "  workflow_run:", "  schedule:", "  repository_dispatch:"):
        assert forbidden not in trigger, f"{zoky.name}: must be workflow_dispatch only ({forbidden.strip()})"
    assert "  workflow_dispatch:" in trigger, f"{zoky.name}: manual-only trigger absent"
    permissions = top_level_block(workflow, "permissions")
    assert permissions is not None and permissions.strip() == "contents: read", (
        f"{zoky.name}: permissions must stay contents: read"
    )

    concurrency = top_level_block(workflow, "concurrency")
    group = block_value(concurrency, "group")
    wyn158_group = block_value(
        top_level_block(uncommented((WF / "wyn-158-production-deploy.yml").read_text()), "concurrency"), "group"
    )
    assert group == "zoky-web-exception-release", f"{zoky.name}: concurrency group must be zoky-web-exception-release"
    assert group != wyn158_group, f"{zoky.name}: must not share wyn-158's cancel-in-progress lane"
    assert block_value(concurrency, "cancel-in-progress") == "false", (
        f"{zoky.name}: must not cancel an in-progress release"
    )

    jobs = jobs_of(workflow)
    assert set(jobs) == {"guard", "deploy"}, f"{zoky.name}: jobs must be exactly guard + deploy, got {sorted(jobs)}"
    guard_job, deploy_job = jobs["guard"], jobs["deploy"]
    gate = "github.ref == 'refs/heads/main' && inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018'"
    for name, job in jobs.items():
        assert job_key(job, "if") == [gate], f"{zoky.name}: {name} job lost the main-only + confirmation gate"
    assert job_key(deploy_job, "environment") == ["production"], (
        f"{zoky.name}: deploy job must use the protected production environment"
    )
    assert job_key(guard_job, "environment") == [], f"{zoky.name}: guard job must run before (not inside) the review"
    assert "secrets." not in guard_job, f"{zoky.name}: guard job must not read secrets"
    assert job_key(deploy_job, "needs") == ["guard"], f"{zoky.name}: deploy must wait for scope guards"

    for name, job in jobs.items():
        names = step_names(job)
        assert names and names[0] == "Exception has not expired", f"{zoky.name}: {name} must start with the expiry check"
        assert job.count(EXPIRY_TEST) == 1, f"{zoky.name}: {name} expiry comparison removed"

    # Raw text: GitHub interpolates ${{ }} even inside shell comments.
    for body in run_bodies(raw):
        assert not INPUT_IN_SHELL.search(body), f"{zoky.name}: inputs must reach run steps only via env: ({body.strip()[:60]})"

    checkouts = workflow.count("uses: actions/checkout@")
    assert checkouts == 2 and workflow.count("persist-credentials: false") == checkouts, (
        f"{zoky.name}: every checkout must set persist-credentials: false"
    )
    assert "vercel@latest" not in workflow and "npx --yes vercel@63.1.2 deploy --prod" in deploy_job, (
        f"{zoky.name}: Vercel CLI must stay pinned"
    )
    assert 'ZOKY_EXCEPTION_EXPIRES_UTC: "2026-11-30"' in workflow, f"{zoky.name}: expiry changed or removed"
    assert "ZOKY_RELEASE_BRANCH: release/zoky-web-20261018" in workflow, f"{zoky.name}: release branch changed"
    assert "ZOKY_PRODUCTION_BASE_SHA: b19687afdec361da846a2d9ceb11429547c92a24" in workflow, (
        f"{zoky.name}: pinned production base SHA changed"
    )
    for excluded in ("806390ed8ab56810c6141b925e6b8aa6eb3eca49", "55a290e9168ac8b82b5656cecf9ff10f4fce7bc0"):
        assert excluded in workflow, f"{zoky.name}: exclusion of {excluded[:8]} (#1133/#1135) removed"
    for check in (
        "^[0-9a-f]{40}$",
        'git merge-base --is-ancestor "$ZOKY_PRODUCTION_BASE_SHA" "$RELEASE_SHA"',
        "web/lib/food-home-banners.ts web/lib/food-featured-stores.ts",
        "Out-of-scope path in release",
        "git diff --no-renames --name-only",
    ):
        assert check in guard_job, f"{zoky.name}: guard job missing: {check}"
    for check in (
        "ref: ${{ inputs.release_sha }}",
        'test "$(git rev-parse HEAD)" = "$RELEASE_SHA"',
        "npm run qa:browser",
    ):
        assert check in deploy_job, f"{zoky.name}: deploy job missing: {check}"
    assert "ZOKY_FREEZE_EXCEPTION" not in (WF / "wyn-158-production-deploy.yml").read_text(), (
        "wyn-158-production-deploy.yml must not carry the ZOKY exception"
    )

# Production edge deploys are Founder-gated and cannot ship wynos-maps-geocode
# without a pinned verify_jwt entry (CTO review R2).
edge_name = "deploy-edge-functions.yml"
edge = uncommented((WF / edge_name).read_text())
edge_jobs = jobs_of(edge)
assert set(edge_jobs) == {"deploy"}, f"{edge_name}: unexpected jobs {sorted(edge_jobs)}"
edge_deploy = edge_jobs["deploy"]
assert job_key(edge_deploy, "environment") == ["production"], f"{edge_name}: deploy job must use production environment"
edge_steps = step_names(edge_deploy)
pin_step, deploy_step = "wynos-maps-geocode verify_jwt is pinned", "Deploy"
assert pin_step in edge_steps and deploy_step in edge_steps, f"{edge_name}: verify_jwt pin step or Deploy step missing"
assert edge_steps.index(pin_step) < edge_steps.index(deploy_step), f"{edge_name}: verify_jwt pin must run before Deploy"
assert "grep -qx '\\[functions\\.wynos-maps-geocode\\]' supabase/config.toml" in edge_deploy, (
    f"{edge_name}: verify_jwt pin check altered"
)
assert "FUNCTION_NAME: ${{ inputs.function }}" in edge_deploy, f"{edge_name}: pin step must read the input via env:"

print("PASS coordinated final-release freeze: legacy promotions retired, acceptance gates active")
