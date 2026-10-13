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

print("PASS coordinated final-release freeze: legacy promotions retired, acceptance gates active")
