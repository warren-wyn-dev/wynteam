# Deployment Log — DM Conversation Screen UX Polish

**Release**: Founder screenshot review of the chat/DM conversation screen (a
`@devwnos` test thread), asking for a fix toward big-app (Instagram/LINE/
WhatsApp) conventions, with an explicit call-out: the follow button should be
removed from the chat screen once already following.

**Root Cause / Changes**: `web/components/chat-routes.tsx`,
`web/components/wynii-chat.tsx`, `web/components/ui/wynos-icon.tsx`,
`web/app/conversation-modern.css`:
- Follow button now disappears entirely once already following (matched to
  the existing Home feed pattern in `post-author-row.tsx`), instead of
  showing a "+" icon next to "ติดตามแล้ว".
- Read-receipt checkmark now visually differs (single check muted / double
  check accent-colored) — previously both sent and read states rendered the
  identical glyph, only the `aria-label` differed.
- Fixed a same-specificity CSS override shrinking the "..." more-options
  button from 48px to 40px (below the 44px touch-target minimum).
- Send button grown 38px → 44px to meet the same minimum.
- Profile-intro hero card now only renders for a brand-new, empty
  conversation instead of always duplicating the sticky header's small
  avatar+name.
- Added `aria-expanded` (more-options toggle), `aria-label` (image-attach),
  `aria-pressed` (follow button).

**Verification**: Visually confirmed with a throwaway static fixture (not
committed) reusing the real CSS classes — follow button hides correctly,
hero collapses correctly, read-receipt icons differ correctly, and computed
styles confirmed 48px/44px hit areas. `npm run check` PASS. Full
`npx playwright test` across all 3 CI browser projects (`webkit-iphone`,
`chromium-android`, `chromium-desktop`): 267/267 PASS.

**PR**: [#587](https://github.com/warren-wyn-dev/wynteam/pull/587)
(`claude/dm-conversation-ux-polish` → `main`), merged by the Founder directly.

**Rollback Plan**: Standard PR revert — CSS/JSX-only diff, no migrations, no
schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #173
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35603265575) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35603265559) —
  **success**.
- Deployed to `wynos.online`.
