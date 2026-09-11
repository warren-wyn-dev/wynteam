#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("check_migration_safety.py").resolve()


def run(*args: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args),
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


class MigrationSafetyIntegrationTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        (self.repo / "supabase").mkdir()

        self.assertEqual(run("git", "init", "-q", cwd=self.repo).returncode, 0)
        self.assertEqual(
            run("git", "config", "user.email", "ci@example.invalid", cwd=self.repo).returncode,
            0,
        )
        self.assertEqual(
            run("git", "config", "user.name", "WYNOS CI", cwd=self.repo).returncode,
            0,
        )

        migration = self.repo / "supabase" / "migrations_test.sql"
        migration.write_text("create table public.example (id bigint primary key);\n", encoding="utf-8")
        self.assertEqual(run("git", "add", ".", cwd=self.repo).returncode, 0)
        self.assertEqual(run("git", "commit", "-qm", "baseline", cwd=self.repo).returncode, 0)
        self.base = run("git", "rev-parse", "HEAD", cwd=self.repo).stdout.strip()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _commit(self, sql: str) -> str:
        migration = self.repo / "supabase" / "migrations_test.sql"
        migration.write_text(sql, encoding="utf-8")
        self.assertEqual(run("git", "add", ".", cwd=self.repo).returncode, 0)
        self.assertEqual(run("git", "commit", "-qm", "change", cwd=self.repo).returncode, 0)
        return run("git", "rev-parse", "HEAD", cwd=self.repo).stdout.strip()

    def _check(self, head: str) -> subprocess.CompletedProcess[str]:
        return run(sys.executable, str(SCRIPT), self.base, head, cwd=self.repo)

    def test_safe_migration_passes(self) -> None:
        head = self._commit(
            "create table public.example (id bigint primary key, label text);\n"
            "create index if not exists example_label_idx on public.example(label);\n"
        )
        result = self._check(head)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_destructive_migration_fails_without_marker(self) -> None:
        head = self._commit("drop table public.example;\n")
        result = self._check(head)
        self.assertEqual(result.returncode, 1)
        self.assertIn("DROP TABLE", result.stderr)

    def test_destructive_migration_passes_with_explicit_marker(self) -> None:
        head = self._commit(
            "-- WYNOS-DESTRUCTIVE-MIGRATION-APPROVED: founder-approved-test\n"
            "drop table public.example;\n"
        )
        result = self._check(head)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Explicit destructive-migration marker", result.stdout)

    def test_non_migration_sql_is_ignored(self) -> None:
        other = self.repo / "supabase" / "schema.sql"
        other.write_text("drop table public.example;\n", encoding="utf-8")
        self.assertEqual(run("git", "add", ".", cwd=self.repo).returncode, 0)
        self.assertEqual(run("git", "commit", "-qm", "schema only", cwd=self.repo).returncode, 0)
        head = run("git", "rev-parse", "HEAD", cwd=self.repo).stdout.strip()
        result = self._check(head)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
