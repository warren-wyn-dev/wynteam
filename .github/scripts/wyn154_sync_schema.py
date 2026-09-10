from pathlib import Path

schema_path = Path("supabase/schema.sql")
migration_path = Path("supabase/migrations_wyn154_club_invite_preview_not_found.sql")
marker = "-- WYN-154 / BUG-004 follow-up: make club invite preview total for unknown codes."

schema = schema_path.read_text()
if marker in schema:
    print("WYN-154 already present in schema.sql")
    raise SystemExit(0)

migration = migration_path.read_text().strip()
schema_path.write_text(schema.rstrip() + "\n\n" + migration + "\n")
print("Appended WYN-154 to schema.sql")
