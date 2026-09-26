# Bug Report — WEB-B1-QA-03 (MEDIUM, pre-existing) Storage buckets have no server-side MIME/size limit

Status: resolved — live in production 2026-09-26 (PR #725, deploy #275, DB apply run 36250193842)
Owner: AI Debug Engineer
Found by: AI QA & Security — WYNOS Web Beta1 full-system QA, 2026-09-26 (first noted as LOW in WYN-004 QA)
Bug: Buckets `avatars`, `drop-images` (public) and `club-media`, `chat-media` (private) are created
with no `allowed_mime_types` / `file_size_limit` anywhere in `supabase/schema.sql` or migrations.
The storage RLS policies correctly scope the path to the owner/participant, but nothing server-side
checks type or size. The web client also trusts the client MIME/extension
(`web/lib/phase3-data.ts` `uploadProfileImage` builds the path extension from `file.name` and sends
`file.type`).
AGENTS.md mandatory rule: "File uploads ต้องตรวจชนิด ขนาด content และ authorization;
ห้ามเชื่อ extension หรือ client MIME เพียงอย่างเดียว".
Reproduction (logic, not executed against production): with a valid session call the Storage API
directly and upload `<uid>/avatar.html` with `Content-Type: text/html`, or a very large
non-image file, into `avatars` / `drop-images`.
Expected: the bucket rejects non-image types and oversized files.
Actual: accepted, subject only to the project-wide Supabase upload limit. Not verified whether the
production project has bucket limits set by hand in the Supabase Dashboard — if it does, this
becomes documentation-only.
Root Cause: bucket creation SQL never set limits; client-side checks are bypassable.
Fix: (proposed) `update storage.buckets set allowed_mime_types = '{image/jpeg,image/png,image/webp,image/heic,image/heif,image/gif}', file_size_limit = <agreed MB> where id in (...)`;
Founder applies via SQL editor. Derive the upload extension from the validated MIME type, not `file.name`.
Files Changed: —
Tests: PostgreSQL/storage integration test or manual staging check with a text/html upload.
Regression Risk: Low–Medium: confirm every client (web + Flutter) only uploads the allowed types
and that HEIC from iOS is included.
Handoff to QA: attempt the non-image upload on staging after the change.

Resolution (2026-09-26): `supabase/migrations_web_beta1_storage_upload_limits.sql` (image allow-list + octet-stream for Flutter, no SVG/HTML; 10 MB avatars / 20 MB others) and `web/lib/upload-image.ts` on every web upload (type/extension from validated MIME, Thai errors) + `tests/upload-image.test.mjs`. Bucket limits are live only after the Founder runs `.github/workflows/web-beta1-apply-qa-hardening.yml`.
