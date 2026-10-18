#!/usr/bin/env python3
"""Fail-closed regression gate for the WYNOS all-features-before-production freeze.

This is an intentionally narrow source-code structural check, not a YAML parser
or a substitute for reviewer / GitHub production environment approvals.
"""
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

# Founder-approved ZOKY-only freeze exception (DECISIONS 2026-10-18, Option A).
# The file may be deleted (exception closed); while it exists its scope guards
# must stay intact.
zoky = WF / "zoky-web-exception-release.yml"
if zoky.exists():
    workflow = zoky.read_text()
    trigger = workflow.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
    for forbidden in ("  push:", "  pull_request", "  workflow_run:", "  schedule:", "  repository_dispatch:"):
        assert forbidden not in trigger, f"{zoky.name}: must be workflow_dispatch only ({forbidden.strip()})"
    assert "  workflow_dispatch:" in trigger, f"{zoky.name}: manual-only trigger absent"
    permissions = workflow.split("\npermissions:\n", 1)[1].split("\n\n", 1)[0]
    assert permissions.strip() == "contents: read", f"{zoky.name}: permissions must stay contents: read"
    assert "cancel-in-progress: false" in workflow, f"{zoky.name}: must not cancel an in-progress release"
    guard = "if: github.ref == 'refs/heads/main' && inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018'"
    assert workflow.count(guard) == 2, f"{zoky.name}: main-only + confirmation guard must gate both jobs"
    assert workflow.count("environment: production") == 1, f"{zoky.name}: deploy must use protected production env"
    assert "needs: guard" in workflow, f"{zoky.name}: deploy must wait for scope guards"
    assert 'ZOKY_EXCEPTION_EXPIRES_UTC: "2026-11-30"' in workflow, f"{zoky.name}: expiry changed or removed"
    assert "Exception has not expired" in workflow, f"{zoky.name}: expiry check removed"
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
        "ref: ${{ inputs.release_sha }}",
        'test "$(git rev-parse HEAD)" = "$RELEASE_SHA"',
        "npm run qa:browser",
    ):
        assert check in workflow, f"{zoky.name}: guard missing: {check}"
    assert "ZOKY_FREEZE_EXCEPTION" not in (WF / "wyn-158-production-deploy.yml").read_text(), (
        "wyn-158-production-deploy.yml must not carry the ZOKY exception"
    )

print("PASS coordinated final-release freeze: legacy promotions retired, acceptance gates active")
