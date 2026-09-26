# Bug Report — WEB-B1-QA-04 (LOW) Upload buckets accept application/octet-stream with no content validation

Status: open (non-blocking, LOW)
Owner: AI Debug Engineer
Found by: Codex review of PR #731 (Web Beta1 QA sign-off), verified by AI QA & Security 2026-09-26
Bug: `supabase/migrations_web_beta1_storage_upload_limits.sql` limits `avatars`, `drop-images`,
`chat-media`, `club-media` to raster image types plus `application/octet-stream`, because the Flutter
app uploads without an explicit `contentType` (`FileOptions(upsert: true)` /
`immutableUploadFileOptions`) and may fall back to that type. Neither the buckets nor
`web/lib/upload-image.ts` read the file signature or decode the content. The web validator only
checks the client MIME type and extension.
AGENTS.md mandatory rule: "File uploads ต้องตรวจชนิด ขนาด content และ authorization;
ห้ามเชื่อ extension หรือ client MIME เพียงอย่างเดียว".
Reproduction (logic, not executed against production): with a valid session, call the Storage API
directly and upload `<uid>/x.bin` with `Content-Type: application/octet-stream` and non-image
bytes (≤10 MB avatars / ≤20 MB others) into `drop-images`.
Expected: non-image content is rejected.
Actual: accepted under the caller's own path (RLS still enforces ownership).
Impact: no script execution on wynos.online. The file is served as `application/octet-stream`
(downloaded, not rendered) and `X-Content-Type-Options: nosniff` is set. The residual risk is using
WYNOS public buckets to host arbitrary files, plus storage cost.
Root Cause: the octet-stream fallback is kept for Flutter compatibility; no server-side content check.
Fix (proposed):
1. Flutter: pass `contentType` derived from the validated image type on every upload.
2. After Flutter builds with (1) are the only ones in use: drop `application/octet-stream` from
   `allowed_mime_types` (Founder-applied migration).
3. Optional, stronger: a storage upload hook / Edge Function that checks magic bytes before the
   object becomes public.
Files Changed: —
Tests: extend `supabase/tests/web_beta1_qa_hardening_test.sh` to assert octet-stream is rejected
after step 2; Flutter upload unit test for `contentType`.
Regression Risk: Medium for step 2, because older Flutter builds' uploads would fail. Gate on
Flutter adoption.
Handoff to QA: attempt the octet-stream upload on staging after step 2.
