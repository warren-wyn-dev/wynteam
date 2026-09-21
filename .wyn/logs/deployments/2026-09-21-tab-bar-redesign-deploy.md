# Deployment Log — Bottom nav icon redesign (Tab Bar A: เส้นบาง)

**Release**: Founder-supplied design mockup (`TabBar.dc.html`, "Tab Bar A:
เส้นบาง") for the root bottom navigation icon set.

**Changes**:
- Replaced all 5 tab icons (home, club, post, chat, profile) in
  `MaterialNavGlyph` (`bottom-navigation.tsx`) with the simpler line-icon
  shapes from the mockup.
- Moved fill-on-selected behavior from the home icon to the chat icon,
  matching the mockup's toggle (only chat fills solid when active).
- Flattened `strokeWidth` to a constant `1.7`.
- Inactive tab color `var(--wyn-text-secondary)` → `var(--wyn-text-muted)`,
  inactive `font-weight` `400` → `500`, both to match the mockup's lighter
  "faint" treatment using the closest existing design token.
- Kept icon size (28px), font size (10px), and border-top treatment as-is
  — real-device-tested responsive/safe-area infrastructure the mockup's
  static 390px canvas doesn't need to dictate pixel-for-pixel.

**Verification**: `npm run check` PASS. Throwaway visual fixture (not
committed) confirmed via computed styles and screenshots: all 5 icons
correct, active color/weight (`rgb(10, 10, 10)` / `700`) and inactive
(`rgb(154, 154, 154)` / `500`) correct, glyph size unchanged at 28×28px,
chat icon fills solid only when active. Full `npx playwright test` across
all 3 CI browser projects: 267/267 PASS.

**PR**: [#591](https://github.com/warren-wyn-dev/wynteam/pull/591)
(`claude/tab-bar-redesign` → `main`), merged by the Founder directly.

**Rollback Plan**: Standard PR revert — no migrations, no schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #177
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35635892990) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35635893113) —
  **success**.
- Deployed to `wynos.online`.

**Note**: immediately after this deploy, the Founder asked for a follow-up
— all tab icons (not just chat) should fill solid black when active. See
the next entry in `.wyn/company/DECISIONS.md` and deployment log for that
follow-up fix.
