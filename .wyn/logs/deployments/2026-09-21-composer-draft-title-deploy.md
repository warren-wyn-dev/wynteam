# Deployment Log — Composer: remove save-draft button, tappable draft title

**Release**: Founder feedback on the post composer's empty state
(screenshot): remove the redundant "บันทึกร่าง" quick-action button, and
make the "ฉบับร่าง" header title tappable.

**Changes**:
- Removed the "บันทึกร่าง" quick-action button, its `saveDraftExplicit()`
  handler, and the unused `Save` icon import from `beta4-composer.tsx` —
  same save-draft option already exists in the Cancel button's
  close-confirmation dialog. Also fixes the previous orphaned-button
  layout, since the quick-action grid is a fixed 4-column CSS grid.
- Made the "ฉบับร่าง" header title a real button. No content → navigates
  straight to `/drafts`. With unsaved content → reuses the Cancel button's
  close-confirmation dialog first, then continues to `/drafts` once
  resolved. The Cancel button's own flow (always lands on `/`) is
  unaffected — verified independently.
- `.draftTitle` CSS given the border/background/font resets and
  press-feedback the other header buttons already have.

**Verification**: `npm run check` PASS. Throwaway visual/interaction
fixtures (not committed) confirmed the 4-button single-row layout and all
5 tap behaviors via a Playwright script. Full `npx playwright test` across
all 3 CI browser projects: an initial run was contaminated by mid-run
source edits (2 unrelated failures); a clean re-run after all edits
settled passed 267/267.

**PR**: [#593](https://github.com/warren-wyn-dev/wynteam/pull/593)
(`claude/composer-remove-save-draft-button` → `main`), merged by the
Founder directly.

**Rollback Plan**: Standard PR revert — no migrations, no schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #179
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35640319528) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35640319526) —
  **success**.
- Deployed to `wynos.online`.
