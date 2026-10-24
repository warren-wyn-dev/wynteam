#!/usr/bin/env python3
"""Validate a committed, isolated Merchant candidate using the trusted control checkout.

No credentials, database connection, dependency install, or deployment is needed.
The literal manifest is finalized only after the candidate has passed QA.
"""
import argparse
import datetime
import json
import re
import subprocess
from pathlib import Path

import yaml


class WorkflowLoader(yaml.BaseLoader):
    """GitHub-style string mapping keys; reject duplicate or merged keys."""


def construct_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result or key == "<<":
            raise ValueError("Duplicate or merged workflow mapping key")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


WorkflowLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping)

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / ".wyn/docs/deployment/zoky-merchant-ui-release.json"
FROZEN = (
    ".github/scripts/require-wynos-final-release-ready.sh",
    ".github/workflows/wyn-158-production-deploy.yml",
    ".github/workflows/zoky-web-exception-release.yml",
    "tools/check_wynos_release_freeze.py",
)
EXCLUDED = (
    "806390ed8ab56810c6141b925e6b8aa6eb3eca49",
    "55a290e9168ac8b82b5656cecf9ff10f4fce7bc0",
)
SHARED = {
    "web/.gitignore", "web/package.json", "web/next.config.ts",
    "web/eslint.config.mjs", "web/proxy.ts", "web/app/auth/callback/page.tsx",
    "web/components/push-prompt.tsx", "web/lib/food-merchant.ts",
    "web/scripts/check-web-fonts.mjs", "web/playwright.merchant-flutter.config.ts",
    "web/tests/web-font-policy.test.mjs",
    "web/app/merchant/merchant.css", "web/lib/i18n/en.ts",
    "web/lib/push-notifications.ts",
    "web/tests/browser/wynos-merchant.spec.ts", "web/tests/push-toggle-enable.test.mjs",
}


def git(root, *args, check=True):
    return subprocess.run(["git", "-C", str(root), *args], check=check,
                          capture_output=True, text=True)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def allowed(path):
    if any(part in {".", "..", ""} for part in path.split("/")):
        return False
    return (path in SHARED or path.startswith((
        "web/merchant_flutter/", "web/app/merchant/flutter/",
        "web/components/merchant/merchant-", "web/lib/merchant-",
        "web/tests/merchant-", "web/tests/merchant-browser/",
        "web/public/brand/zoky/", "docs/qa/zoky-merchant-flutter/",
    )) or path in {
        "web/components/merchant/wynos-merchant-app.tsx",
        ".wyn/company/APPROVALS.md",
        ".wyn/company/DECISIONS.md",
        ".wyn/tasks/active/zoky-merchant-flutter-integration.md",
    })


def validate_git_deploy_config(config):
    require(config.get("git", {}).get("deploymentEnabled") == {"main": False},
            "Disable automatic all-main deployments while preserving preview branches")


def validate(release, sha, branch_tip, manifest, today=None):
    today = today or datetime.datetime.now(datetime.timezone.utc).date()
    require(today <= datetime.date.fromisoformat(manifest["expiresUtc"]), "Merchant release approval expired")
    require(re.fullmatch(r"[0-9a-f]{40}", sha) is not None and sha != "0" * 40, "Use a finalized full commit SHA")
    require(sha == manifest["releaseSha"] == branch_tip, "Candidate must equal the reviewed pin and release branch tip")
    require(manifest["productionBase"] == "e6f577dcccb86b51c68d91e754b19fe4cfa27222", "Unexpected live production base")
    require(manifest["releaseBranch"] == "release/zoky-merchant-ui-20261024", "Unexpected release branch")
    require(manifest["projectId"] == "prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a" and
            manifest["teamId"] == "team_Kamt1PUT5XKn9MWrF404re1w", "Unexpected Vercel target")
    require(manifest["rollbackDeployment"] == "dpl_HhzmnfVpb9qyHd7yeiAiiUmkbPV9", "Unexpected rollback deployment")
    require(manifest["legacyFoodRedirect"] == "0", "Food behavior must remain at the live phase")
    require(git(release, "rev-parse", "HEAD").stdout.strip() == sha, "Checkout is not the pinned candidate")
    require(not git(release, "status", "--porcelain", "--untracked-files=no").stdout.strip(), "Candidate has uncommitted changes")
    base = manifest["productionBase"]
    require(git(release, "merge-base", "--is-ancestor", base, sha, check=False).returncode == 0,
            "Current production must be the candidate ancestor")
    for excluded in EXCLUDED:
        require(git(release, "merge-base", "--is-ancestor", excluded, sha, check=False).returncode != 0,
                "Unaccepted homepage work is in the release")
    for path in ("web/lib/food-home-banners.ts", "web/lib/food-featured-stores.ts"):
        require(git(release, "cat-file", "-e", f"{sha}:{path}", check=False).returncode != 0,
                "Unaccepted homepage module exists")
    paths = git(release, "diff", "--no-renames", "--name-only", base, sha).stdout.splitlines()
    approved = manifest["approvedPaths"]
    require(paths and sorted(paths) == sorted(approved) and len(set(approved)) == len(approved),
            "Candidate paths differ from the reviewed manifest")
    for path in paths:
        require(allowed(path), f"Out-of-scope candidate file: {path}")
        mode = git(release, "ls-tree", sha, "--", path).stdout.split(" ", 1)[0]
        require(mode in {"", "100644", "100755"}, f"Symlink or submodule is forbidden: {path}")
    # Both the candidate and control checkout retain the existing freeze controls.
    for path in FROZEN:
        expected = git(release, "show", f"{base}:{path}", check=False)
        if expected.returncode != 0:
            # Controls introduced after this production base must match main's
            # approved version, and must never be added to the release artifact.
            require(path not in paths, f"Candidate changes release controls: {path}")
            continue
        require(git(release, "show", f"{sha}:{path}").stdout == expected.stdout,
                f"Candidate changes release controls: {path}")
    return paths


def validate_workflow(doc):
    """Keep the new exception narrower than the existing all-system freeze."""
    require(set(doc.get("on", {})) == {"workflow_dispatch"}, "Merchant release must remain manual-only")
    require(doc.get("permissions") == {"contents": "read"}, "Unexpected workflow permissions")
    require(doc.get("concurrency", {}).get("cancel-in-progress") in (False, "false"), "A newer run must not cancel this release")
    require(doc.get("env") == {
        "RELEASE_BRANCH": "release/zoky-merchant-ui-20261024",
        "VERCEL_ORG_ID": "team_Kamt1PUT5XKn9MWrF404re1w",
        "VERCEL_PROJECT_ID": "prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a",
    }, "Unexpected workflow target")
    jobs = doc["jobs"]
    require(set(jobs) == {"guard", "verify", "stage", "promote"}, "Unexpected release jobs")
    for job_name, job in jobs.items():
        require("continue-on-error" not in job, "Release failures must block dependent jobs")
        require(job.get("if") == "github.ref == 'refs/heads/main' && github.repository == 'warren-wyn-dev/wynteam' && inputs.confirmation == 'ZOKY_MERCHANT_UI_20261024'", "Keep the main/repository/confirmation gate on every job")
        require("permissions" not in job, "Job must inherit read-only permissions")
        require(not set(job.get("env", {})) & set(doc["env"]), "Job must not override target pins")
        for step in job["steps"]:
            require("continue-on-error" not in step, "Release step failures must block")
            require("if" not in step or (step.get("if") == "always()" and str(step.get("uses", "")).startswith("actions/upload-artifact@")), "Check steps must not be skipped")
            require(not set(step.get("env", {})) & set(doc["env"]), "Step must not override target pins")
            if "uses" in step:
                require(re.fullmatch(r"actions/[a-z-]+@[0-9a-f]{40}", step["uses"]) is not None, "Pin every Action to a reviewed SHA")
            text = json.dumps(step)
            require("${{" not in step.get("run", ""), "Do not interpolate expressions into shell code")
            require("GITHUB_ENV" not in text and "GITHUB_PATH" not in text, "Do not override runtime pins through runner files")
            require(not ("secrets." in text and job_name not in {"stage", "promote"}), "Secrets may only appear behind production review")
            require("--token" not in text and "vercel@latest" not in text, "Use environment authentication and pinned CLI")
    require(jobs["verify"]["needs"] == "guard", "Verification must need the guard")
    require(set(jobs["stage"]["needs"]) == {"guard", "verify"}, "Staging must need all verification")
    require(set(jobs["promote"]["needs"]) == {"guard", "verify", "stage"}, "Promotion must need the tested staged artifact")
    for name in ("stage", "promote"):
        require(jobs[name].get("environment") == "production", "Keep the existing production environment review")
        steps = jobs[name]["steps"]
        guard_at = next((i for i, step in enumerate(steps) if "check_merchant_ui_release.py" in step.get("run", "")), None)
        require(guard_at is not None, "Revalidate candidate/expiry after every production review")
        secret_at = next(i for i, step in enumerate(steps) if "secrets." in json.dumps(step))
        require(guard_at < secret_at, "Revalidate before credentials")
        script = "\n".join(step.get("run", "") for step in steps)
        require("vercel@63.1.2" in script, "Pin the reviewed Vercel CLI")
        require("merchant_ui_release_ops.mjs current" in script, "Check production drift after review")
    stage = json.dumps(jobs["stage"])
    require("--prod --skip-domain" in stage and "ZOKY_MERCHANT_FLUTTER_ENABLED=1" in stage and "ZOKY_LEGACY_FOOD_REDIRECT=0" in stage,
            "Stage production without domains and preserve explicit product flags")
    require("vercel curl" in stage and "canvaskit.wasm" in stage and "merchant-tools-3d.png" in stage,
            "Verify the immutable artifact before promotion")
    promote = json.dumps(jobs["promote"])
    require("${{ needs.stage.outputs.url }}" in promote and "merchant_ui_release_ops.mjs staged" in promote and "vercel promote" in promote,
            "Promote only the inspected staged production artifact")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-root", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--branch-tip", required=True)
    args = parser.parse_args()
    try:
        validate_git_deploy_config(json.loads((ROOT / "web/vercel.json").read_text()))
        paths = validate(args.release_root, args.sha, args.branch_tip,
                         json.loads(MANIFEST.read_text()))
    except (ValueError, KeyError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"Merchant release blocked: {exc}") from exc
    print(f"PASS isolated Merchant release {args.sha}: {len(paths)} reviewed files; Food, database and release controls preserved")


if __name__ == "__main__":
    main()
