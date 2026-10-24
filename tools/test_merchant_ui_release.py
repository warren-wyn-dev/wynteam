#!/usr/bin/env python3
"""Fail-closed regression tests for the isolated Merchant release boundary."""
import copy
import datetime
import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("merchant_guard", ROOT / "tools/check_merchant_ui_release.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
SHA = "a" * 40
TODAY = datetime.date(2026, 10, 24)


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(guard.MANIFEST.read_text())
        self.manifest.update(releaseSha=SHA, approvedPaths=["web/merchant_flutter/lib/main.dart"])
        self.paths = self.manifest["approvedPaths"].copy()
        self.symlink = self.dirty = self.missing_base = self.excluded = False

    def fake_git(self, root, *args, check=True):
        code, out = 0, ""
        if args == ("rev-parse", "HEAD"):
            out = SHA
        elif args[0] == "status":
            out = " M web/merchant_flutter/lib/main.dart" if self.dirty else ""
        elif args[0] == "merge-base":
            code = (1 if self.missing_base else 0) if args[2] == self.manifest["productionBase"] else (0 if self.excluded else 1)
        elif args[0] == "cat-file":
            code = 1
        elif args[0] == "diff":
            out = "\n".join(self.paths)
        elif args[0] == "ls-tree":
            out = ("120000" if self.symlink else "100644") + " blob abc\tfile"
        elif args[0] == "show":
            code = 1  # These controls are absent from the historical live base.
        else:
            self.fail(f"Unhandled git command {args}")
        return subprocess.CompletedProcess(args, code, out, "")

    def check(self, sha=SHA, tip=SHA, today=TODAY):
        with patch.object(guard, "git", self.fake_git):
            return guard.validate(Path("fixture"), sha, tip, self.manifest, today)

    def test_valid_isolated_candidate(self):
        self.assertEqual(self.check(), self.paths)

    def test_wrong_or_unfinalized_sha_and_stale_tip(self):
        for sha, tip in [("bad", SHA), ("0" * 40, "0" * 40), ("b" * 40, SHA), (SHA, "b" * 40)]:
            with self.subTest(sha=sha, tip=tip), self.assertRaises(ValueError):
                self.check(sha, tip)

    def test_expired_release(self):
        with self.assertRaises(ValueError):
            self.check(today=datetime.date(2026, 12, 1))

    def test_outside_paths_and_renamed_source(self):
        for path in ["web/components/food/wynos-food-developer-app.tsx", "supabase/schema.sql", ".github/workflows/ci.yml", "web/lib/food-origin.ts", "web/merchant_flutter/../../food/file.tsx"]:
            self.paths = [path]
            self.manifest["approvedPaths"] = self.paths
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.check()

    def test_unreviewed_extra_path(self):
        self.paths.append("web/merchant_flutter/lib/extra.dart")
        with self.assertRaises(ValueError):
            self.check()

    def test_symlink_dirty_missing_ancestor_and_excluded_commit(self):
        for key in ["symlink", "dirty", "missing_base", "excluded"]:
            setattr(self, key, True)
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check()
            setattr(self, key, False)

    def test_wrong_project_and_food_phase(self):
        for key in ["projectId", "teamId", "legacyFoodRedirect", "productionBase", "rollbackDeployment", "releaseBranch"]:
            old = self.manifest[key]
            self.manifest[key] = "unexpected"
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check()
            self.manifest[key] = old


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.workflow = yaml.load((ROOT / ".github/workflows/zoky-merchant-ui-release.yml").read_text(), Loader=guard.WorkflowLoader)

    def test_reviewed_workflow(self):
        guard.validate_workflow(self.workflow)

    def test_security_boundary_mutations(self):
        def release_review(w): w["jobs"]["promote"].pop("environment")
        def stage_review(w): w["jobs"]["stage"]["environment"] = "preview"
        def skipped_qa(w): w["jobs"]["verify"]["if"] = "false"
        def failure_ignored(w): w["jobs"]["stage"]["continue-on-error"] = "true"
        def missing_dependency(w): w["jobs"]["promote"]["needs"] = ["guard"]
        def automatic(w): w["on"]["push"] = {"branches": ["main"]}
        def preview_promotion(w):
            for step in w["jobs"]["stage"]["steps"]:
                if "run" in step: step["run"] = step["run"].replace("--prod --skip-domain", "--yes")
        def unsafe_secret(w): w["jobs"]["verify"]["steps"].append({"run": "echo nope", "env": {"TOKEN": "${{ secrets.VERCEL_TOKEN }}"}})
        def unpinned_action(w): w["jobs"]["guard"]["steps"][0]["uses"] = "actions/checkout@v4"
        def missing_post_review_recheck(w):
            w["jobs"]["promote"]["steps"] = [s for s in w["jobs"]["promote"]["steps"] if "check_merchant_ui_release.py" not in s.get("run", "")]
        def skipped_guard(w): w["jobs"]["stage"]["steps"][2]["if"] = "false"
        def expression_in_shell(w): w["jobs"]["stage"]["steps"][2]["run"] += "\necho ${{ github.event.inputs['release_sha'] }}"
        def target_override(w): w["jobs"]["promote"]["env"] = {"VERCEL_PROJECT_ID": "wrong"}
        def file_override(w): w["jobs"]["stage"]["steps"][2]["run"] += '\necho VERCEL_PROJECT_ID=wrong >> "$GITHUB_ENV"'
        for mutate in [release_review, stage_review, skipped_qa, failure_ignored, missing_dependency, automatic, preview_promotion, unsafe_secret, unpinned_action, missing_post_review_recheck, skipped_guard, expression_in_shell, target_override, file_override]:
            workflow = copy.deepcopy(self.workflow)
            mutate(workflow)
            with self.subTest(mutation=mutate.__name__), self.assertRaises(ValueError):
                guard.validate_workflow(workflow)

    def test_duplicate_keys_fail_closed(self):
        for text in ["jobs:\n  stage: {}\n  stage: {}\n", "jobs:\n  <<: {}\n"]:
            with self.assertRaises((ValueError, yaml.YAMLError)):
                yaml.load(text, Loader=guard.WorkflowLoader)


if __name__ == "__main__":
    unittest.main()
