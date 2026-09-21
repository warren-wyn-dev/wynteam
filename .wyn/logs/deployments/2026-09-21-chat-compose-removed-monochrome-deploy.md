# Deployment Log — Chat compose button removed, thread colors reverted to monochrome

**Release**: Founder feedback on the live `/chat` page (screenshot with the
"เขียนข้อความใหม่" compose icon circled), sent immediately after the Messages
redesign v2 deploy (PR #589) earlier the same day.

**Request**: remove the compose button from the Chat Inbox header; revert
the conversation thread's accent-red color scheme (introduced in PR #589)
back to black/white.

**Changes**:
- Removed the compose button and all of its dead supporting code from
  `chat-inbox-parity.tsx` (state, handlers, modal JSX, unused imports).
- Reverted outgoing message bubbles, the "read" receipt color, and the
  "ออนไลน์" online-status text from `var(--wyn-accent)` back to
  `var(--wyn-text)`/`var(--wyn-bg)`. Kept the asymmetric 6px bubble-corner
  fix from PR #589 (unrelated real bug fix).
- Left the green online-status dot and the red notification-badge dot on
  the inbox "..." menu unchanged (semantic status/notification colors, not
  the decorative "chat theme" color the request was about).
- Updated the stale `system-visual-parity.spec.ts` assertion that expected
  the compose button to exist.

**Verification**: `npm run check` PASS. Throwaway visual fixture (not
committed) confirmed via computed styles: compose button gone, outgoing
bubble `rgb(10, 10, 10)`/white text, incoming bubble unchanged
`rgb(250, 250, 250)`, read-status no longer red. Full
`npx playwright test` across all 3 CI browser projects: 267/267 PASS.

**PR**: [#590](https://github.com/warren-wyn-dev/wynteam/pull/590)
(`claude/messages-monochrome-v3` → `main`), merged by the Founder directly.

**Rollback Plan**: Standard PR revert — no migrations, no schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #176
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35631863575) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35631863429) —
  **success**.
- Deployed to `wynos.online`.
