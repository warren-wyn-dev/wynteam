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
| `clubChatActions` | WYN-135 Club chat edit / pin / search | spec + migration (separate SQL approval) |
| `clubAnnouncements` | WYN-137 Club announcements | spec + migration (separate SQL approval) |

WYN-188 (theme) and WYN-189 (Thai/English) were released to everyone on 2026-09-27, before this
process existed. The Founder chose to keep them live.
