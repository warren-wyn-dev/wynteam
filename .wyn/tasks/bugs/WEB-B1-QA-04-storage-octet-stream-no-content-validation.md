# Bug Report — WEB-B1-QA-04 (LOW) Upload buckets accept application/octet-stream with no content validation

Status: **resolved**. Live in production 2026-09-26 (PR #732, spoof test passed)
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
3. **Required:** trusted server-side content validation, for example a storage upload hook or
   Edge Function that checks magic bytes or decodes the image before the object is accepted or
   made public. Steps 1–2 alone do not satisfy "Expected": a direct Storage API call can still
   send non-image bytes labelled `image/jpeg`.
Closure condition: this finding closes only when step 3 is live and a spoofed allowed MIME type
(non-image bytes sent as `image/jpeg`/`image/png`) is rejected on staging or production. Rejecting
`application/octet-stream` alone is not enough.
Files Changed: —
Tests: (a) spoofed-MIME upload (non-image bytes as `image/jpeg`) is rejected; (b) octet-stream is
rejected after step 2; (c) a real JPEG/PNG/HEIC still uploads; (d) Flutter upload unit test for
`contentType`.
Regression Risk: Medium for step 2, because older Flutter builds' uploads would fail. Gate on
Flutter adoption.
Handoff to QA: attempt the octet-stream upload on staging after step 2.

## Fix — step 3 implemented (2026-09-26, Web Beta2)

Founder decisions (AskUserQuestion): **validate after upload and delete non-images** (not an
upload proxy); the AI may deploy the function and install the webhook after CI passes.

- `supabase/functions/validate-upload/`: an Edge Function that receives the storage.objects
  webhook, reads the first 64 bytes of the object (service role, `Range`), and recognises
  JPEG/PNG/GIF/WebP/HEIC/HEIF/AVIF by magic bytes. It **deletes** the object if the bytes are not an
  image. The claimed MIME type is ignored, so spoofed `image/jpeg` and `application/octet-stream`
  are both covered. It fails open on read errors and logs bucket, object id and outcome, never the
  path. Only the four image buckets are inspected. `pop-videos` and `appeal-evidence` are untouched.
  Tests: `supabase/functions/validate-upload/_lib.test.ts` (runs in CI with `deno test`).
- `.github/workflows/storage-upload-validator.yml`: `create` installs an AFTER INSERT trigger and an
  AFTER UPDATE trigger (fires only when `metadata` changes, i.e. a new upsert, not on reads) on
  `storage.objects` for those buckets. `test` is the end-to-end closure test: a text file uploaded
  as `image/jpeg` must disappear within 60 s and a real PNG must stay. `remove` is the rollback.
- `deploy-edge-functions.yml`: adds the `validate-upload` option.

Known limit: a non-image can be readable for a few seconds before it is deleted (accepted with the
design choice). Existing objects are not rescanned.

Closure: this finding closes when the function is deployed, the triggers are created, and the
`test` action passes on production.

## Resolution (2026-09-26)
- PR #732 merged at `e9d35e5`.
- `deploy-edge-functions.yml` (validate-upload), run `36266920543`: success.
- `storage-upload-validator.yml` `create`, run `36266962485`: both triggers installed on `storage.objects`.
- `storage-upload-validator.yml` `test`, run `36266985757`: **PASS** on production. A text file uploaded to
  `drop-images` as `image/jpeg` was removed, and a real PNG was kept. Both test objects were cleaned up.
- Closure condition met: a spoofed allowed MIME type is rejected server-side.
