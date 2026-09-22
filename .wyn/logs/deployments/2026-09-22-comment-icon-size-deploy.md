# Deployment Log — Comment icon size nudge

**Release**: Founder feedback right after the post-action-icons swap (PR
#594) deployed — the comment bubble icon reads visually smaller than the
other 4 post-action icons even at the same nominal size.

**Changes**:
- Bumped `CommentIcon` from `size={22}` to `size={24}` in the two places
  it renders at 22px: `post-actions.tsx` (Home feed, Profile) and
  `golden-drop-card.tsx`'s `homeParity=false` fallback (Search,
  Bookmarks).
- Left Post Detail's `CommentIcon` untouched — its row already has
  separate CSS-forced per-icon sizes hand-tuned for visual balance from
  an earlier pass, independent of the component's `size` prop.

**Verification**: `npm run check` PASS. Throwaway visual fixture (not
committed) measured real bounding boxes (comment 24×24 vs the row's other
icons at 22×22) and confirmed the row reads visually balanced via
screenshot. Full `npx playwright test` across all 3 CI browser projects:
267/267 PASS.

**PR**: [#595](https://github.com/warren-wyn-dev/wynteam/pull/595)
(`claude/comment-icon-size` → `main`), merged by the Founder directly.

**Rollback Plan**: Standard PR revert — no migrations, no schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #181
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35681794148) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35681794144) —
  **success**.
- Deployed to `wynos.online`.
