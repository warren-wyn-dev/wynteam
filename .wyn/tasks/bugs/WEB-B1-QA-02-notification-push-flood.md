# Bug Report — WEB-B1-QA-02 (MEDIUM) Unthrottled follow/like toggling floods a user with notifications and Push

Status: bugs
Owner: AI Debug Engineer
Found by: AI QA & Security — WYNOS Web Beta1 full-system QA, 2026-09-26
Bug: `public.notify_follow()` (latest definition in `supabase/migrations_web_beta1_official_autofollow.sql`
/ `schema.sql`) inserts a new `notifications` row on every `follows` INSERT, and the same pattern applies
to `notify_drop_like()` / like triggers. There is no dedupe window or per-actor rate limit, and
`send-push-notification` uses the notification row id as collapse key, so each row becomes a
separate Push banner.
Reproduction (logic, from SQL — not executed against production): account A repeatedly
follow → unfollow → follow account B (or like/unlike one of B's posts) via the API. Each INSERT
creates a new notification and a new Push to every device of B. There is no server-side limit on
how fast A can loop.
Expected: repeated identical actor/target/type events within a short window collapse into one
notification (or are skipped), and write RPCs/tables have a basic per-account rate limit.
Actual: unbounded notifications/Push → harassment and Push-quota abuse vector.
Root Cause: notification triggers have no dedupe; follow/like tables have no rate limit
(only `record_drop_view` and location search are rate-limited in the schema).
Fix: (proposed) in notify_follow/notify_*_like skip the insert when an identical
(recipient, actor, type, target) notification exists in the last N minutes; longer term a
per-account write rate limit. DB change → new `supabase/migrations_*.sql`, Founder applies.
Mitigation today: the victim can block A or turn off the category in notification settings.
Files Changed: —
Tests: SQL integration test in the PostgreSQL CI job: follow/unfollow ×5 → 1 notification.
Regression Risk: Medium — must not drop legitimate distinct events.
Handoff to QA: re-run the loop scenario on staging and count notifications/Push.
