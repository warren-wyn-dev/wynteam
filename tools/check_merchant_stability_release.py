#!/usr/bin/env python3
"""Fail-closed policy for the live-based Merchant stability repair only."""
import argparse
import datetime
import json
import re
import subprocess
from pathlib import Path

import yaml

# Reuse only parsing/git primitives; the published UI release policy is unchanged.
from check_merchant_ui_release import EXCLUDED, WorkflowLoader, git, require, validate_git_deploy_config

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / ".wyn/docs/deployment/zoky-merchant-stability-release.json"
WORKFLOW = ROOT / ".github/workflows/zoky-merchant-stability-release.yml"
BASE = "b2e5c184eeaef42aeb7b94ef10e54627d5d594ab"
BRANCH = "release/zoky-merchant-stability-20261026"
ROLLBACK = "dpl_CACVkPQDL3MDfFSZvY64Ggpyqu8v"
TEAM = "team_Kamt1PUT5XKn9MWrF404re1w"
PROJECT = "prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a"
GATE = "github.ref == 'refs/heads/main' && github.repository == 'warren-wyn-dev/wynteam' && inputs.confirmation == 'ZOKY_MERCHANT_STABILITY_20261026'"
FROZEN = (
    ".github", "tools", "supabase", "web/next.config.ts", "web/proxy.ts",
    "web/app/auth", "web/lib/supabase", "web/lib/return-to.ts",
    ".wyn/docs/deployment/zoky-merchant-ui-release.json",
)
FILES = {
    ".wyn/learning/LESSONS_LEARNED.md",
    ".wyn/tasks/active/zoky-merchant-flutter-integration.md",
    "web/components/merchant/merchant-auth.tsx",
    "web/components/merchant/merchant-flutter-app.tsx",
    "web/components/merchant/merchant-flutter-authenticated.tsx",
    "web/app/merchant/login/page.tsx", "web/app/merchant/merchant.css",
    "web/lib/merchant-auth-return.ts",
    "web/merchant_flutter/lib/data/merchant_controller.dart",
    "web/merchant_flutter/test/stability_refresh_test.dart",
    "web/package.json", "web/playwright.merchant-flutter.config.ts",
    "web/tests/merchant-flutter-routing.test.mjs",
}


def allowed(path):
    return not any(part in {".", "..", ""} for part in path.split("/")) and (
        path in FILES or path.startswith((
            "web/components/merchant/merchant-auth-", "web/tests/merchant-auth-",
            "web/tests/merchant-browser/", "docs/qa/zoky-merchant-flutter/",
            "web/public/brand/zoky/",
        ))
    )


def validate(release, sha, tip, m, today=None):
    today = today or datetime.datetime.now(datetime.timezone.utc).date()
    require(today <= datetime.date.fromisoformat(m["expiresUtc"]), "Stability release approval expired")
    require(re.fullmatch(r"[0-9a-f]{40}", sha) is not None and sha != "0" * 40,
            "Finalize a reviewed full SHA before dispatch")
    require(sha == m["releaseSha"] == tip and sha != BASE, "Use the reviewed repair pin and branch tip")
    require(m["productionBase"] == BASE and m["releaseBranch"] == BRANCH and
            m["rollbackDeployment"] == ROLLBACK, "Unexpected live base, branch or recovery target")
    require(m["projectId"] == PROJECT and m["teamId"] == TEAM, "Unexpected Vercel target")
    require(m["merchantFlutterEnabled"] == "1" and m["legacyFoodRedirect"] == "0",
            "Preserve the reviewed Merchant and Food phases")
    require(git(release, "rev-parse", "HEAD").stdout.strip() == sha, "Wrong candidate checkout")
    require(not git(release, "status", "--porcelain", "--untracked-files=no").stdout.strip(), "Dirty candidate checkout")
    require(git(release, "merge-base", "--is-ancestor", BASE, sha, check=False).returncode == 0,
            "The actual current live source must be an ancestor")
    for excluded in EXCLUDED:
        require(git(release, "merge-base", "--is-ancestor", excluded, sha, check=False).returncode != 0,
                "Unaccepted homepage work is in the stability release")
    for path in ("web/lib/food-home-banners.ts", "web/lib/food-featured-stores.ts"):
        require(git(release, "cat-file", "-e", f"{sha}:{path}", check=False).returncode != 0,
                "Unaccepted homepage module exists")
    paths = git(release, "diff", "--no-renames", "--name-only", BASE, sha).stdout.splitlines()
    approved = m["approvedPaths"]
    require(paths and sorted(paths) == sorted(approved) and len(set(approved)) == len(approved),
            "Candidate differs from the exact reviewed path manifest")
    for path in paths:
        require(allowed(path), f"Out-of-scope stability file: {path}")
        mode = git(release, "ls-tree", sha, "--", path).stdout.split(" ", 1)[0]
        require(mode in {"", "100644", "100755"}, f"Symlink/submodule forbidden: {path}")
    require(not git(release, "diff", "--name-only", BASE, sha, "--", *FROZEN).stdout.strip(),
            "Food/auth/database/release boundaries changed")
    # The package edit is test wiring, not a dependency/framework change.
    if "web/package.json" in paths:
        before = json.loads(git(release, "show", f"{BASE}:web/package.json").stdout)
        after = json.loads(git(release, "show", f"{sha}:web/package.json").stdout)
        for package in (before, after):
            for key in ("test:merchant-flutter", "qa:merchant-flutter"):
                package.get("scripts", {}).pop(key, None)
        require(before == after, "Only Merchant test script wiring may change in package.json")
    return paths


def validate_workflow(doc):
    require(set(doc.get("on", {})) == {"workflow_dispatch"}, "Release must remain manual-only")
    require(doc.get("permissions") == {"contents": "read"}, "Keep read-only workflow permissions")
    inputs = doc["on"]["workflow_dispatch"]["inputs"]
    require(set(inputs) == {"release_sha", "confirmation"} and inputs["release_sha"]["required"] == "true",
            "Only a required source pin and confirmation are dispatch inputs")
    require(inputs["confirmation"].get("default") == "CANCEL" and
            inputs["confirmation"].get("options") == ["CANCEL", "ZOKY_MERCHANT_STABILITY_20261026"],
            "Keep the typed stability confirmation")
    require(doc.get("concurrency", {}).get("cancel-in-progress") == "false", "Do not cancel an in-flight release")
    require(doc.get("env") == {"RELEASE_BRANCH": BRANCH, "VERCEL_ORG_ID": TEAM, "VERCEL_PROJECT_ID": PROJECT},
            "Unexpected workflow target pins")
    jobs = doc["jobs"]
    require(set(jobs) == {"guard", "verify", "stage", "promote"}, "Keep all release gates")
    for name, job in jobs.items():
        require(job.get("if") == GATE and "permissions" not in job and "continue-on-error" not in job,
                "Keep every main/repository/confirmation gate and failure")
        require("secrets." not in json.dumps(job.get("env", {})), "Scope credentials only to their reviewed authentication step")
        require(not set(job.get("env", {})) & set(doc["env"]), "Do not override target pins")
        for step in job["steps"]:
            text = json.dumps(step)
            require("continue-on-error" not in step, "Step failures must block")
            require("if" not in step or (step["if"] == "always()" and str(step.get("uses", "")).startswith("actions/upload-artifact@")), "Do not skip verification steps")
            require(not set(step.get("env", {})) & set(doc["env"]), "Do not override target pins")
            if "uses" in step:
                require(re.fullmatch(r"actions/[a-z-]+@[0-9a-f]{40}", step["uses"]) is not None, "Pin every Action")
                if step["uses"].startswith("actions/checkout@"):
                    require(step.get("with", {}).get("persist-credentials") == "false", "Do not persist checkout credentials")
            require("${{" not in step.get("run", "") and "GITHUB_ENV" not in text and "GITHUB_PATH" not in text,
                    "Do not interpolate shell expressions or override pins through runner files")
            require("--token" not in text and "vercel@latest" not in text, "Use environment auth and pinned CLI")
            require("secrets." not in text or name in {"stage", "promote"}, "Credentials require production review")
    require(jobs["verify"].get("needs") == "guard", "Verify needs guard")
    require(set(jobs["stage"].get("needs", [])) == {"guard", "verify"}, "Stage needs all verification")
    require(set(jobs["promote"].get("needs", [])) == {"guard", "verify", "stage"}, "Promote needs tested stage")
    for name in ("stage", "promote"):
        job = jobs[name]
        require(job.get("environment") == "production", "Keep both existing Production reviews")
        checks = [i for i, s in enumerate(job["steps"]) if "check_merchant_stability_release.py" in s.get("run", "")]
        secret = next(i for i, s in enumerate(job["steps"]) if "secrets." in json.dumps(s))
        require(checks and checks[0] < secret, "Revalidate pin/expiry after review and before secrets")
        script = "\n".join(s.get("run", "") for s in job["steps"])
        require("vercel@63.1.2" in script and "merchant_stability_release_ops.mjs current" in script,
                "Pin CLI and recheck live routing after review")
    verify = json.dumps(jobs["verify"])
    require("npm run check" in verify and "npm run qa:merchant-flutter" in verify,
            "Keep full build and compiled-browser verification")
    verify_script = "\n".join(s.get("run", "") for s in jobs["verify"]["steps"])
    require(verify_script.index("npm run check") < verify_script.index("npm run qa:merchant-flutter") <
            verify_script.index("npx playwright test tests/browser/wynos-merchant.spec.ts"),
            "Run compiled production verification before legacy development mode can change .next")
    stage, promote = json.dumps(jobs["stage"]), json.dumps(jobs["promote"])
    require("--prod --skip-domain" in stage and "ZOKY_MERCHANT_FLUTTER_ENABLED=1" in stage and
            "ZOKY_LEGACY_FOOD_REDIRECT=0" in stage and "vercel promote" not in stage,
            "Stage production without customer domains and preserve product flags")
    require("vercel deploy --prod --skip-domain --force" in stage and "--with-cache" not in stage,
            "Build the staged artifact without reusing the incomplete Flutter SDK cache")
    require(jobs["stage"].get("outputs") == {"url": "${{ steps.stage.outputs.url }}", "id": "${{ steps.stage.outputs.id }}"},
            "Export the inspected immutable URL and ID")
    require("staged-output" in stage and "vercel curl" in stage and "canvaskit.wasm" in stage and "merchant-tools-3d.png" in stage,
            "Inspect the staged ID and verify its actual assets")
    require("${{ needs.stage.outputs.url }}" in promote and "${{ needs.stage.outputs.id }}" in promote and
            "merchant_stability_release_ops.mjs staged" in promote and "vercel promote" in promote and
            "merchant_stability_release_ops.mjs promoted" in promote, "Promote only the inspected URL/ID pair")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-root", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--branch-tip", required=True)
    args = parser.parse_args()
    try:
        validate_git_deploy_config(json.loads((ROOT / "web/vercel.json").read_text()))
        validate_workflow(yaml.load(WORKFLOW.read_text(), Loader=WorkflowLoader))
        paths = validate(args.release_root, args.sha, args.branch_tip, json.loads(MANIFEST.read_text()))
    except (ValueError, KeyError, StopIteration, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"Merchant stability release blocked: {exc}") from exc
    print(f"PASS isolated Merchant stability source {args.sha}: {len(paths)} exact reviewed paths")


if __name__ == "__main__":
    main()
