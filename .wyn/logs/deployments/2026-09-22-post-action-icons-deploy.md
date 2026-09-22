# Deployment Log — Post action icons swap (wynos-post-icons.zip)

**Release**: Founder-supplied icon set (like, comment, repost, share,
bookmark) with "เปลี่ยนปุ่มให้หน่อย", followed by a full Post Detail mockup
with "หน้านี้ด้วย" — confirmed via clarifying question that only the icon
swap was in scope, not the mockup's other layout differences.

**Changes**:
- New `components/ui/post-action-icons.tsx` (CommentIcon, RepostIcon,
  SaveIcon) carries the new shapes standalone, kept out of `WynosIcon`'s
  shared iconMap since those names are also used by unrelated UI.
- `AnimatedHeart` (like) and `WynosShareIcon` (share) updated in place.
- Wired into every primary post-action-row surface: `post-actions.tsx`
  (Home feed, Profile), `post-detail-route.tsx`'s own row, and
  `golden-drop-card.tsx`'s `homeParity=false` fallback (Search,
  Bookmarks). `club-detail-golden.tsx`'s own action row left untouched
  (separate implementation).
- Fixed a real bug found along the way: Post Detail's
  `.flutter-detail-actions` had `display: none` on the real `<svg>` for
  comment/repost/share/bookmark, replaced by a CSS mask drawing hardcoded
  old Flutter Material icon shapes (`pixel-parity-final.css`) — same
  footgun as the earlier chat-header back-arrow mask bug. Removed.
- Updated stale test assertions across 5 spec files, including a share
  icon path-count assertion (2 → 1, since the new glyph is a single
  closed path).

**Verification**: `npm run check` PASS. Throwaway visual fixture (not
committed) screenshot-confirmed all 5 icons match the mockup and
computed-style-confirmed the CSS mask fix. Full `npx playwright test`
across all 3 CI browser projects: an initial run surfaced 3 failures (all
the same stale assertion); fixed and a clean re-run passed 267/267.

**PR**: [#594](https://github.com/warren-wyn-dev/wynteam/pull/594)
(`claude/post-action-icons` → `main`), merged by the Founder directly.

**Rollback Plan**: Standard PR revert — no migrations, no schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #180
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35680815700) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35680815722) —
  **success**.
- Deployed to `wynos.online`.
