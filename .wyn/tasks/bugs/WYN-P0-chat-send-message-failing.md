# Bug Report — WYN-P0 (Chat: sending a message fails on the live app)

Status: active (blocked on Founder/production evidence, not on code)
Owner: AI Debug Engineer (this session)

Bug: Founder reports the Chat feature (WYN-031/032/033) is broken on the live app: "ฟังชั่นแชท ยังส่งแชท คุยกันยังไม่ได้นะ". Clarified via popup: the user **can** open a conversation (chat room loads), types a message, taps Send, and the send **fails / shows an error** (the generic "ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้ง" SnackBar in `ConversationScreen._send()`).

Reproduction: **Could not reproduce live.** This sandbox's egress proxy denies (HTTP 403, policy denial) both the production Vercel URL (`https://web-neon-sigma-66.vercel.app`) and the production Supabase project (`https://kqokpocajhfbidcxpvhh.supabase.co`) — confirmed via direct `curl`, same class of tooling limitation already documented in `WYN-P0-google-signin-broken-on-web.md`. No production credentials (Supabase Personal Access Token / Vercel token) exist in this repo to query production any other way (by design — see RELEASE_NOTES.md "Credentials ที่ต้องมี... เก็บไว้ที่ Founder ไม่ใช่ในโค้ด").

What **was** verified directly, against the current codebase (not old QA notes):
1. `flutter analyze` on `app/` — clean, 0 issues.
2. Full `flutter test` suite — **834/834 pass**, including every chat widget/unit test (`chat_model_test.dart`, `chat_inbox_screen_test.dart`, `conversation_screen_test.dart`, `new_message_screen_test.dart`), specifically "sending a text message calls sendMessage and shows the sent bubble".
3. Installed a local PostgreSQL 16 + Flutter 3.47.2 in this sandbox (none pre-installed) and re-ran the **actual SQL regression scripts against the current `supabase/schema.sql`** (not a stale snapshot): `wyn_031_chat_test.sh` (29/29 PASS), `wyn_032_message_request_test.sh` (30/30 PASS), `wyn_033_share_to_chat_test.sh` (12/12 PASS) — every RLS/RPC path a send can take (participant/non-participant, blocked, posting-blocked/Restrict-Suspend-Ban, pending Message Request, shared-content messages) passes under the real `authenticated` role.
4. Traced the client wiring end-to-end: `RootShell` → real `ChatRepository(Supabase.instance.client)` → `HomeFeedScreen`/`ChatInboxScreen`/`ConversationScreen` — no stub/null repository anywhere in the path.
5. **Confirmed the live deploy is stale**: `RELEASE_NOTES.md` documents the last known production deploy as commit `92ce16d` (2026-08-24) — the current branch is **99 commits ahead** of that, including 6 chat-specific commits today (Chat Inbox/Thread restyle, and building `NewMessageScreen` for the first time — before today the compose/pencil icon in Chat Inbox was explicitly wired to nothing: `"The compose icon has no real destination yet ... Shown muted/disabled for now"`). This doesn't match the symptom Founder confirmed (composer opens fine, Send itself fails), since the "ส่งข้อความ" button on `ViewProfileScreen` already worked at `92ce16d`, but it does mean **whatever Founder is testing may not even be running this branch's code** — worth confirming before chasing this as a pure code bug.

Root Cause: **Not confirmed — do not guess.** The generic SnackBar in `_send()`'s `catch (_)` block was swallowing the real exception, so there was no way (not from this sandbox, not from Founder's own browser) to see whether the live failure is a `PostgrestException` (RLS/schema mismatch), a storage error (image upload), or a network/CORS error. Every code path this session could exercise (client logic, current `schema.sql` under real RLS) is correct and passing. The leading hypothesis, given this project's own history (Google Sign-In and Phone OTP were both **production infra/config gaps invisible to local testing**, not code bugs) and the schema.sql churn since the last confirmed deploy (`WYN-062`/`WYN-063`/`WYN-064` all touched `schema.sql` after 92ce16d), is **schema drift**: the production Supabase database may not have every migration in the current `schema.sql` applied (this project has no CI/CD auto-migration — schema is applied manually via the Supabase Management API per `RELEASE_NOTES.md`). This is a hypothesis to verify, not a finding.

Fix (partial — diagnostic, not a root-cause fix): `ConversationScreen._send()`'s catch block now `debugPrint`s the caught exception + stack trace instead of silently discarding it, so the real error is visible in the browser DevTools console (Flutter Web `debugPrint` writes to the JS console even in release builds). Every other catch block in this screen stays intentionally silent (a fallback UI state already covers those) — this one doesn't have a fallback state, so it was the one truly invisible failure.

Files Changed: `app/lib/features/chat/presentation/conversation_screen.dart` (`_send()` only).

Tests: `flutter analyze` clean. `flutter test` full suite 834/834 pass (no regression). SQL: `wyn_031_chat_test.sh` 29/29, `wyn_032_message_request_test.sh` 30/30, `wyn_033_share_to_chat_test.sh` 12/12, all against current `schema.sql`.

Regression Risk: None — the change is additive logging only, no behavior change (same catch, same SnackBar, same `finally`).

**Blocked on**: need one of the following to close this out with a real root cause (per this project's own no-guessing rule):
1. Founder reproduces the failure again after this fix ships and shares the browser DevTools Console output (or a screenshot of it) — mirrors exactly how `WYN-P0-google-signin-broken-on-web.md` was diagnosed.
2. Or: AI Deploy & DevOps (who should hold the Supabase Personal Access Token / dashboard access this session deliberately does not) checks (a) whether `supabase/schema.sql`'s post-`92ce16d` changes were actually applied to the production project, and (b) the production Postgres/API logs around the failed send for the real rejection reason.
3. Or: confirm what commit is actually live right now (redeploy if it's stale — Vercel's 100-deploys/day quota has bitten this project before per the Google Sign-In bug entry).

Handoff to QA: **Not yet — do not re-run QA against production until the above is resolved.** Once the real error is known, re-open this file with the actual Root Cause/Fix and hand off per the normal Bug → Debug → Fix → Regression Test → QA flow.
