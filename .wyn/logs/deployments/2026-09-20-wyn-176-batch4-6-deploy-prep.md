# Deployment Log — WYN-176 Batches 4-6 (Profile/Settings, Search/Club, dead code cleanup)

**Release**: WYN-176 batches 4-6 — part of epic WYN-174
**QA Status**: PASS on all three batches (each needed one fix/re-verify round — batch 4: disabled-button guard bug; batch 5: same pattern on Club chat send button; batch 6: parity.spec.ts contract-coverage gap — all fixed and QA re-verified PASS)
**Build Status**: `typecheck`/`lint`/`build` clean (0 errors, 3 pre-existing unrelated warnings) after merging `main`

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**: CSS-only press-feedback additions (batches 4-5) + pure dead-code deletion + a test-coverage fix (batch 6) across `web/app/*.css`, `web/tests/browser/parity.spec.ts`. No `.tsx` logic changes, no radius/size/color changes beyond what Founder explicitly approved (batch 4's pill-shape decision).

**Merge with `main`**: branch had diverged from `main` (another parallel session's WYN-179/180 bottom-nav resize work touched `web/app/bottom-nav.css` and `web/tests/browser/parity.spec.ts`, overlapping files with this work) — merged cleanly via `git merge origin/main`, no conflicts, both branches' changes coexist correctly (verified `.route-create-destination` stayed removed and `club_channels`/`club_events` contract checks stayed present post-merge). Re-ran `typecheck`/`lint`/`build` and the regression suite after the merge — all still clean.

**Deployment Result**: Not yet deployed — awaiting Founder's explicit "เปิด PR" instruction before opening a pull request, per standing house rule.

**Production Verification**: N/A — pending deploy

**Rollback Plan**: Revert the merge commit (`53de114f`) or the individual batch commits via a follow-up PR; all changes are CSS/test-only, no data/schema impact — safe to revert instantly if needed
