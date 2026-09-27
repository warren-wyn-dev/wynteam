# WYNOS Web Beta2 — developer-only development

Founder decision (2026-09-27): "มาพัฒนา Beta2 ก่อน อย่าพึ่งปล่อยจริง". Beta2 is built on the same site
(wynos.online), hidden from everyone except developer accounts until the Founder releases each feature.

## How a Beta2 feature ships

1. Add the feature to `BETA2_RELEASED` in `web/lib/beta2.ts` with `false`.
2. Render its UI only when `useBeta2Feature("<name>", client, userId)` is true. That hook fails closed
   through the `is_developer_account()` RPC.
3. Any new server capability (RPC, table, policy, Edge Function behavior) must also check
   `is_developer_account()` on the server until release, so the feature cannot be reached directly
   through the API.
4. The feature goes through the usual PR, per-PR staging and CI. Merging deploys it to production, but
   it stays hidden from non-developers.
5. **Release** happens only after an explicit Founder approval. Record it in
   `.wyn/company/APPROVALS.md` as `Beta2 release: <name>`, then flip the entry to `true` in a PR.
   `npm run test:i18n` (which includes `tests/beta2-gate.test.mjs`) fails if a feature is flipped
   without that approval entry.

Before any release, confirm with the Founder whether it goes to everyone or only to developers.

## Current Beta2 features

| Feature key | Task | Status |
|---|---|---|
| `chatThreads` | WYN-159 Threads-style chat: grouping, tap for time, hold menu (reactions, reply, edit ≤30 min, forward, copy, delete for me, unsend, pin, report) | Founder approved design; merged developer-only; reactions migration approved |
| `clubChatActions` | WYN-135 Club chat edit / pin / search | [PR #741](https://github.com/warren-wyn-dev/wynteam/pull/741) merged developer-only; exact-SHA approved production SQL applied; authenticated developer UAT pending (#748) |
| `clubAnnouncements` | WYN-137 Club announcements: "ประกาศ" tab (Club-wide), staff post/edit/delete; no notifications until release | built; migration `migrations_web_beta2_club_announcements.sql` approved by the Founder, applied after merge once main CI is green; see release notes below |

WYN-188 (theme) and WYN-189 (Thai/English) were released to everyone on 2026-09-27, before this
process existed. The Founder chose to keep them live.

## WYN-137 release prerequisites

- Founder decision (2026-09-27): while in Beta2, announcements send **no notifications**. Web and the
  Flutter app share one `notifications` table, and the installed Flutter app throws on an unknown
  notification type and loses its whole list (WYN-043).
- The web already renders a `club_announcement` notification (text, push text, deep link
  `/club/<id>?tab=announcements`). Releasing means a follow-up migration that adds the type and the
  member fan-out and drops the developer gates (its own SQL approval), after the Founder decides how
  to handle Flutter users.

## Verified 2026-09-27 rollout state

- WYN-159 / PR #735, WYN-137 / PR #745, and WYN-135 / PR #741 are merged
  developer-only. All three `BETA2_RELEASED` entries remain `false`.
- The approved WYN-135 production SQL ran successfully through the manual
  exact-SHA-256 gate, and read-only Production SQL confirms three columns,
  three indexes and four developer-only RPCs. **Do not re-run the migration.**
- Existing per-PR protected Vercel previews still share Production Supabase;
  an isolated Free staging database now exists but has no test Auth users or
  protected Vercel runtime yet. See `WEB_STAGING.md` and Issue #749.
- Automated CI and production route smoke passed on the merged baseline.
  Real signed-in developer and non-developer denial tests remain PENDING in
  Issue #748; none of these changes authorizes public Beta2 release.

## WYN-135 historical pre-merge checklist (retained for audit)

- Club message actions are Web Beta2 developer-only; **never** flip `clubChatActions` without separate Founder approval. Keep Web Beta1 message UI and existing Flutter behavior unchanged.
- [PR #741](https://github.com/warren-wyn-dev/wynteam/pull/741) adds three developer-gated action/search SQL RPCs plus one developer-only readiness RPC, editable timestamps, per-channel staff-only pin metadata, PostgreSQL full-text GIN search and pg_trgm GIN substring fallback for Thai. The migration installs `pg_trgm` in the dedicated `extensions` schema if absent.
- Before merge: pass `npm run check`, maintained disposable PostgreSQL tests and protected preview QA. Test on developer accounts with Thai/English, light/dark, editing and cross-channel search, including native mobile browser.
- The preview **shares production Supabase**, so it cannot test newly added RPCs before the Founder-authorized production migration. The Club chat page fails closed to Beta1 chat until the migration's final `club_chat_actions_available()` RPC returns true for a developer. Do not treat green build alone as live feature verification. The production migration workflow is manual-only and requires a separate documented Founder decision.
- The gated code may merge after normal Founder production-merge approval and passing PR checks: the new UI remains disabled until the migration's readiness RPC is installed. Then, after separate approval and Founder-run SQL apply, inspect RLS/grants and run authenticated developer smoke tests. Since merging web PRs auto-deploys production, do not merge prematurely. No public Beta2 release is implied.
