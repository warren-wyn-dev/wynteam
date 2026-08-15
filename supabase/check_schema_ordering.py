#!/usr/bin/env python3
"""Regression test for SCHEMA-001: verify `supabase/schema.sql` has no
forward references -- i.e. no `create table` or `alter table ... add
column` statement references a `public.<table>` that is defined later
(or not at all) in the file.

Supabase's SQL Editor (and `psql -f`) executes the file top-to-bottom
against a plain, empty database. A forward reference -- a table
declaring `references public.X` before `public.X`'s own
`create table` statement appears in the file -- aborts the whole
script partway through with `relation "public.X" does not exist"`,
leaving the database in a half-migrated state. This bug class hit
`public.notifications` (which referenced `public.clubs`/
`public.club_posts` before they existed) -- see
`.wyn/tasks/bugs/SCHEMA-001-notifications-clubs-forward-reference.md`.

This script has no dependencies beyond the Python 3 standard library
and does not require a live database connection -- it's a static text
check, run any time `schema.sql` is edited.

Usage:
    python3 supabase/check_schema_ordering.py

Exit code 0 and "OK" printed when no forward reference is found.
Exit code 1 and a list of offending lines otherwise.
"""

import re
import sys
from pathlib import Path

SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"

CREATE_TABLE_RE = re.compile(r"^create table if not exists public\.(\w+)")
ALTER_TABLE_RE = re.compile(r"^alter table public\.(\w+)")
REFERENCES_RE = re.compile(r"references public\.(\w+)")


def find_table_definitions(lines: list[str]) -> dict[str, int]:
    table_def_line: dict[str, int] = {}
    for i, line in enumerate(lines, 1):
        m = CREATE_TABLE_RE.match(line)
        if m:
            table_def_line[m.group(1)] = i
    return table_def_line


def check(lines: list[str]) -> list[tuple[str, str, int, int, str, int | None]]:
    table_def_line = find_table_definitions(lines)
    issues: list[tuple[str, str, int, int, str, int | None]] = []

    # 1. Forward references inside `create table` column lists.
    current_table = None
    current_table_start = None
    in_table = False
    for i, line in enumerate(lines, 1):
        m = CREATE_TABLE_RE.match(line)
        if m:
            in_table = True
            current_table = m.group(1)
            current_table_start = i
        if in_table:
            for ref in REFERENCES_RE.findall(line):
                ref_line = table_def_line.get(ref)
                if ref_line is None or ref_line > current_table_start:
                    issues.append(
                        ("create table body", current_table, current_table_start, i, ref, ref_line)
                    )
            if line.strip() == ");":
                in_table = False

    # 2. Forward references (or missing target table) in standalone
    #    `alter table public.X ... references public.Y` statements.
    for i, line in enumerate(lines, 1):
        am = ALTER_TABLE_RE.match(line)
        if not am:
            continue
        alter_table_name = am.group(1)
        target_line = table_def_line.get(alter_table_name)
        if target_line is None or target_line > i:
            issues.append(
                ("alter table target not yet created", alter_table_name, i, i, alter_table_name, target_line)
            )
        for ref in REFERENCES_RE.findall(line):
            ref_line = table_def_line.get(ref)
            if ref_line is None or ref_line > i:
                issues.append(("alter table", alter_table_name, i, i, ref, ref_line))

    return issues


def main() -> int:
    lines = SCHEMA_PATH.read_text().splitlines(keepends=True)
    issues = check(lines)
    if not issues:
        print(f"OK: no forward references found in {SCHEMA_PATH}")
        return 0

    print(f"FAIL: {len(issues)} forward reference(s) found in {SCHEMA_PATH}:")
    for kind, table, start_line, ref_line_in_stmt, ref, ref_def_line in issues:
        target = f"line {ref_def_line}" if ref_def_line else "never defined"
        print(
            f"  [{kind}] public.{table} (statement starting at line {start_line}) "
            f"references public.{ref} at line {ref_line_in_stmt}, "
            f"but public.{ref} is defined at {target}"
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())
