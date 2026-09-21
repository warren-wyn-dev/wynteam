# Deployment Log — Chat Inbox Redesign (reverses 3 WYN-170 decisions)

**Release**: Founder-supplied before/after mockup for the Chat Inbox screen
(`/chat`, `web/components/chat-inbox-parity.tsx`), asking for bigger
notes-row/chat-row sizing to an exact pixel spec, a header compose button +
"..." overflow menu, no trailing chevron on rows, and a real online-status
green dot.

**Decision note**: 3 of the requested changes (header compose button back,
leading back-arrow removed, "คำขอข้อความ" access moved off a persistent
header button into the new "..." menu) directly reverse explicit decisions
from WYN-170 (2026-09-19, 6 rounds of Founder feedback, confirmed live in
production). Stopped and confirmed with the Founder via a clarifying
question before finalizing — confirmed as an intentional change of
direction. Full context: `.wyn/company/DECISIONS.md` (2026-09-21 entry).

**New infrastructure**: item 6 (online status) needed a real presence
system — the app never tracked live online/offline state anywhere before
(`user_presence.show_online_status` was a stored privacy toggle nothing
ever read). Founder chose the simple option (Supabase Realtime Presence).
Added `web/lib/presence.ts`: one shared Presence channel per browser tab,
mounted via `AppChrome` (runs on effectively every authenticated screen,
no new global provider needed), gated by the existing privacy toggle.

**Bug found and fixed during visual verification**:
`pixel-parity-audit-closure.css` hardcoded `.flutter-chat-header-action` to
always render a back-arrow via a CSS mask (hiding the actual child `<svg>`)
— a leftover from when that class was exclusively the back button. Reusing
it for the new compose/menu buttons made both incorrectly render as
back-arrows. Fixed by giving the new buttons their own class
(`wyn-chat-header-icon`) instead of touching the legacy rule.

**Verification**:
- Built a throwaway static fixture (not committed) mirroring the real JSX
  with mock data, rendered through the actual dev server + global CSS
  cascade, screenshotted at each state (inbox default, menu open, requests
  drilled-in) to visually confirm against the mockup.
- Computed styles confirmed exact spec match: search bar 48px/24px radius,
  note avatar 62px, bubble max-width 116px, chat row 80px, name
  font-weight 600.
- `npm run check` PASS, 0 errors, 2 pre-existing warnings.
- Updated `system-visual-parity.spec.ts`'s WYN-170-era assertions to match
  the new, Founder-confirmed behavior.
- `npx playwright test` across all 3 CI browser projects (`webkit-iphone`,
  `chromium-android`, `chromium-desktop`): 267/267 PASS.

**PR**: [#588](https://github.com/warren-wyn-dev/wynteam/pull/588)
(`claude/chat-inbox-redesign` → `main`), merged by the Founder directly.

**Rollback Plan**: Standard PR revert — no migrations, no schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #174
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35609320556) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35609320894) —
  **success**.
- Deployed to `wynos.online`.
