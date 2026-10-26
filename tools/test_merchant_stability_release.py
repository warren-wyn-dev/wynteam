#!/usr/bin/env python3
"""Negative checks for the new repair policy; no deployment or credentials."""
import copy
import datetime
import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

import check_merchant_stability_release as guard

SHA = "a" * 40
TODAY = datetime.date(2026, 10, 26)


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.m = json.loads(guard.MANIFEST.read_text())
        self.m.update(releaseSha=SHA, approvedPaths=["web/merchant_flutter/lib/data/merchant_controller.dart"])
        self.paths = self.m["approvedPaths"].copy()
        self.dirty = self.no_base = self.frozen = self.symlink = False
        self.excluded_ancestor = self.homepage_module = None
        self.before = {"name": "web", "dependencies": {"next": "same"}, "scripts": {"build": "same", "test:merchant-flutter": "old"}}
        self.after = copy.deepcopy(self.before)

    def fake_git(self, root, *args, check=True):
        out, code = "", 0
        if args == ("rev-parse", "HEAD"):
            out = SHA
        elif args[0] == "status":
            out = " M file" if self.dirty else ""
        elif args[0] == "merge-base":
            code = int(self.no_base) if args[2] == guard.BASE else int(args[2] != self.excluded_ancestor)
        elif args[0] == "cat-file":
            code = int(args[2].split(":", 1)[1] != self.homepage_module)
        elif args[0] == "diff":
            out = "web/proxy.ts" if "--" in args and self.frozen else "" if "--" in args else "\n".join(self.paths)
        elif args[0] == "ls-tree":
            out = ("120000" if self.symlink else "100644") + " blob hash\tfile"
        elif args[0] == "show":
            out = json.dumps(self.before if args[1].startswith(guard.BASE) else self.after)
        else:
            self.fail(args)
        return subprocess.CompletedProcess(args, code, out, "")

    def check(self, sha=SHA, tip=SHA, today=TODAY):
        with patch.object(guard, "git", self.fake_git):
            return guard.validate(Path("fixture"), sha, tip, self.m, today)

    def test_reviewed_live_based_repair(self):
        self.assertEqual(self.check(), self.paths)

    def test_unfinalized_stale_or_wrong_source(self):
        for sha, tip in [("0" * 40, "0" * 40), ("bad", SHA), (SHA, "b" * 40), (guard.BASE, guard.BASE)]:
            with self.subTest(sha=sha), self.assertRaises(ValueError):
                self.check(sha, tip)
        for key in ("productionBase", "releaseBranch", "rollbackDeployment", "projectId", "teamId", "merchantFlutterEnabled", "legacyFoodRedirect"):
            old = self.m[key]
            self.m[key] = "wrong"
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check()
            self.m[key] = old

    def test_expiry_dirty_symlink_missing_base_and_frozen_controls(self):
        with self.assertRaises(ValueError):
            self.check(today=datetime.date(2026, 12, 1))
        for field in ("dirty", "symlink", "no_base", "frozen"):
            setattr(self, field, True)
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.check()
            setattr(self, field, False)

    def test_exact_paths_and_narrow_product_scope(self):
        self.paths.append("web/components/merchant/merchant-auth.tsx")
        with self.assertRaises(ValueError):
            self.check()
        for path in ["web/proxy.ts", "supabase/file.sql", ".github/workflows/deploy.yml", "web/lib/supabase/browser.ts", "web/lib/food-origin.ts", "web/components/merchant/wynos-merchant-app.tsx", "web/merchant_flutter/../../food/file.tsx"]:
            self.paths = [path]
            self.m["approvedPaths"] = self.paths.copy()
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.check()
        self.paths = [".wyn/learning/LESSONS_LEARNED.md", "docs/qa/zoky-merchant-flutter/stability.md"]
        self.m["approvedPaths"] = self.paths.copy()
        self.assertEqual(self.check(), self.paths)

    def test_package_edit_is_only_merchant_test_wiring(self):
        self.paths = ["web/package.json"]
        self.m["approvedPaths"] = self.paths.copy()
        self.after["scripts"]["test:merchant-flutter"] = "new regression"
        self.assertEqual(self.check(), self.paths)
        self.after["dependencies"]["next"] = "unreviewed"
        with self.assertRaises(ValueError):
            self.check()


    def test_unaccepted_homepage_history_and_modules_remain_excluded(self):
        self.assertEqual(guard.EXCLUDED, (
            "806390ed8ab56810c6141b925e6b8aa6eb3eca49",
            "55a290e9168ac8b82b5656cecf9ff10f4fce7bc0",
        ))
        for commit in guard.EXCLUDED:
            self.excluded_ancestor = commit
            with self.subTest(commit=commit), self.assertRaisesRegex(ValueError, "homepage work"):
                self.check()
        self.excluded_ancestor = None
        for path in ("web/lib/food-home-banners.ts", "web/lib/food-featured-stores.ts"):
            self.homepage_module = path
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "homepage module"):
                self.check()
        self.homepage_module = None
        self.assertEqual(self.check(), self.paths)

    def test_authenticated_view_split_is_an_explicit_merchant_file_allowance(self):
        self.paths = ["web/components/merchant/merchant-flutter-app.tsx",
                      "web/components/merchant/merchant-flutter-authenticated.tsx",
                      "web/tests/merchant-flutter-routing.test.mjs"]
        self.m["approvedPaths"] = self.paths.copy()
        self.assertEqual(self.check(), self.paths)
        self.paths.append("web/components/merchant/merchant-flutter-unreviewed.tsx")
        self.m["approvedPaths"] = self.paths.copy()
        with self.assertRaisesRegex(ValueError, "Out-of-scope"):
            self.check()


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.doc = yaml.load(guard.WORKFLOW.read_text(), Loader=guard.WorkflowLoader)

    def test_reviewed_workflow(self):
        guard.validate_workflow(self.doc)

    def test_release_boundaries_cannot_be_removed(self):
        def no_stage_review(w): w["jobs"]["stage"].pop("environment")
        def no_promote_review(w): w["jobs"]["promote"]["environment"] = "preview"
        def skip_verify(w): w["jobs"]["verify"]["if"] = "false"
        def ignored_failure(w): w["jobs"]["stage"]["continue-on-error"] = "true"
        def auto(w): w["on"]["push"] = {}
        def wrong_target(w): w["env"]["VERCEL_PROJECT_ID"] = "other"
        def input_url(w): w["on"]["workflow_dispatch"]["inputs"]["url"] = {"required": "true"}
        def no_id(w): w["jobs"]["stage"]["outputs"].pop("id")
        def no_needs(w): w["jobs"]["promote"]["needs"] = ["stage"]
        def no_recheck(w): w["jobs"]["promote"]["steps"] = [s for s in w["jobs"]["promote"]["steps"] if "check_merchant_stability_release.py" not in s.get("run", "")]
        def unpinned(w): w["jobs"]["guard"]["steps"][0]["uses"] = "actions/checkout@v4"
        def leaked_secret(w): w["jobs"]["verify"]["env"]["TOKEN"] = "${{ secrets.VERCEL_TOKEN }}"
        def assign_early(w):
            for step in w["jobs"]["stage"]["steps"]:
                if "run" in step: step["run"] = step["run"].replace("--prod --skip-domain", "--prod")
        def bypass_id(w):
            for step in w["jobs"]["promote"]["steps"]:
                step.get("env", {}).pop("MERCHANT_DEPLOYMENT_ID", None)
        def dev_before_production(w):
            for step in w["jobs"]["verify"]["steps"]:
                if "run" in step and "npm run qa:merchant-flutter" in step["run"]:
                    step["run"] = "npx playwright test tests/browser/wynos-merchant.spec.ts\nnpm run qa:merchant-flutter"
        def cached_stage(w):
            for step in w["jobs"]["stage"]["steps"]:
                if "run" in step: step["run"] = step["run"].replace("--force", "")
        def reenable_cache(w):
            for step in w["jobs"]["stage"]["steps"]:
                if "run" in step: step["run"] = step["run"].replace("--force", "--force --with-cache")
        for mutate in [no_stage_review, no_promote_review, skip_verify, ignored_failure, auto, wrong_target, input_url, no_id, no_needs, no_recheck, unpinned, leaked_secret, assign_early, bypass_id, dev_before_production, cached_stage, reenable_cache]:
            doc = copy.deepcopy(self.doc)
            mutate(doc)
            with self.subTest(mutation=mutate.__name__), self.assertRaises(ValueError):
                guard.validate_workflow(doc)

    def test_duplicate_workflow_keys_rejected(self):
        with self.assertRaises(ValueError):
            yaml.load("jobs:\n  stage: {}\n  stage: {}\n", Loader=guard.WorkflowLoader)


if __name__ == "__main__":
    unittest.main()
