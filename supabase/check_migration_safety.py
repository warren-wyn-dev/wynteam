#!/usr/bin/env python3
"""Fail PRs that add destructive SQL without an explicit approval marker.

Usage:
    python3 supabase/check_migration_safety.py <base_sha> <head_sha>

Only added lines in changed `supabase/migrations*.sql` files are inspected so
legacy migrations do not make the gate fail retroactively.

A destructive migration must contain a human-reviewable marker:

    -- WYNOS-DESTRUCTIVE-MIGRATION-APPROVED: <reason / approval reference>

The marker does not replace Founder review. It makes destructive intent visible
in the diff and prevents accidental data-loss statements from slipping through.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

APPROVAL_RE = re.compile(
    r"--\s*WYNOS-DESTRUCTIVE-MIGRATION-APPROVED:\s*\S+",
    re.IGNORECASE,
)

RISKY_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("DROP DATABASE", re.compile(r"\bDROP\s+DATABASE\b", re.IGNORECASE)),
    ("DROP SCHEMA", re.compile(r"\bDROP\s+SCHEMA\b", re.IGNORECASE)),
    ("DROP TABLE", re.compile(r"\bDROP\s+TABLE\b", re.IGNORECASE)),
    ("DROP COLUMN", re.compile(r"\bDROP\s+COLUMN\b", re.IGNORECASE)),
    ("DROP TYPE", re.compile(r"\bDROP\s+TYPE\b", re.IGNORECASE)),
    ("TRUNCATE", re.compile(r"\bTRUNCATE(?:\s+TABLE)?\b", re.IGNORECASE)),
    ("DELETE FROM", re.compile(r"\bDELETE\s+FROM\b", re.IGNORECASE)),
)


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout


def changed_migrations(base_sha: str, head_sha: str) -> list[str]:
    output = git(
        "diff",
        "--name-only",
        "--diff-filter=ACMR",
        base_sha,
        head_sha,
        "--",
        "supabase/migrations*.sql",
    )
    return [line.strip() for line in output.splitlines() if line.strip()]


def added_sql(base_sha: str, head_sha: str, path: str) -> str:
    diff = git("diff", "--unified=0", base_sha, head_sha, "--", path)
    lines: list[str] = []
    for line in diff.splitlines():
        if line.startswith("+++"):
            continue
        if line.startswith("+"):
            lines.append(line[1:])
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: check_migration_safety.py <base_sha> <head_sha>", file=sys.stderr)
        return 2

    base_sha, head_sha = sys.argv[1:]
    paths = changed_migrations(base_sha, head_sha)
    if not paths:
        print("Migration safety: no changed supabase/migrations*.sql files.")
        return 0

    failures: list[str] = []
    approved: list[str] = []

    for path in paths:
        additions = added_sql(base_sha, head_sha, path)
        if not additions.strip():
            continue

        matches = [name for name, pattern in RISKY_PATTERNS if pattern.search(additions)]
        if not matches:
            continue

        file_text = Path(path).read_text(encoding="utf-8")
        if APPROVAL_RE.search(file_text):
            approved.append(f"{path}: {', '.join(matches)}")
        else:
            failures.append(f"{path}: {', '.join(matches)}")

    for item in approved:
        print(f"::warning::Explicit destructive-migration marker present: {item}")

    if failures:
        print("Destructive SQL added without an approval marker:", file=sys.stderr)
        for item in failures:
            print(f"  - {item}", file=sys.stderr)
        print(
            "Add `-- WYNOS-DESTRUCTIVE-MIGRATION-APPROVED: <reason / approval reference>` "
            "only after the destructive change has been explicitly reviewed and approved.",
            file=sys.stderr,
        )
        return 1

    print(f"Migration safety: checked {len(paths)} changed migration file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
