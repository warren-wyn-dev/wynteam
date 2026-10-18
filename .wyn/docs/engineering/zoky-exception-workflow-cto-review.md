# CTO Review — ZOKY web production-freeze exception workflow

- Reviewer: WYN CTO (AI) | Date: 2026-10-18 | Mode: read-only review (no env/secrets read, no dispatch, no deploy, no push, no PR)
- Branch: `ci/zoky-web-exception-release` @ `d40f98fb` (2 commits on `origin/main` `42a8f937`)
- Files reviewed: `.github/workflows/zoky-web-exception-release.yml` (new), `tools/check_wynos_release_freeze.py`, `tools/test_check_wynos_release_freeze.py` (new), `.github/workflows/ci.yml`, `.github/workflows/deploy-edge-functions.yml`; compared with `wyn-158-production-deploy.yml` (main) and the workflows on `release/zoky-web-20261018` @ `31f13fb3`
- Inputs: `AGENTS.md`, `docs/engineering/GIT_WORKFLOW.md`, `docs/engineering/SECURITY_RULES.md`, `zoky-web-release-plan.md` (release branch HEAD), Founder decisions 2026-10-18 (`docs/zoky-foundation:.wyn/company/DECISIONS.md`)

## Verdict: **CHANGES REQUIRED** (small, workflow-only; re-review is a diff check)

The design matches Option A and the Founder conditions closely: dispatch-only, `main`-only definition, choice-typed confirmation, pinned SHA checked out and re-verified, fail-closed scope guards, no inputs interpolated into shell, secrets only in the `production`-gated job, `wyn-158` and #1142–#1151 untouched. Four defects must be fixed before merge (R1–R4), and one pre-existing HIGH risk must be mitigated or explicitly accepted by the Founder before the first production dispatch (C1).

## สรุปสำหรับ Founder (ภาษาไทย)

- โครงสร้าง workflow ดีและตรงกับที่อนุมัติ (ส่งเฉพาะ commit ที่ระบุ, ตรวจขอบเขตไฟล์, หมดอายุ 30 พ.ย., ต้องผ่าน environment `production` ก่อน deploy) แต่ **ยังไม่ควร merge** จนกว่าจะแก้ 4 ข้อเล็ก ๆ:
  1. **กันไม่ให้ถูกยกเลิกกลางทาง** — ถ้ามีคนกด wyn-158 ระหว่างที่ ZOKY กำลัง deploy ระบบจะยกเลิก ZOKY ทันที (อาจค้างครึ่งทาง ขึ้น production แล้วแต่ยังไม่ได้ตรวจ) → แยกคิวของ ZOKY ออกจาก wyn-158
  2. **Edge functions ยังไม่มีปุ่มอนุมัติของ Founder** — workflow deploy edge function ไม่มี `environment: production` ใครมีสิทธิ์เขียน repo ก็ deploy ได้เลย และตัวเลือกใหม่ `wynos-maps-geocode` อาจทำให้ค้นหาที่อยู่แบบไม่ล็อกอินพัง → เพิ่ม environment และให้ระบบหยุดเองถ้ายังไม่ได้ตั้งค่า verify_jwt
  3. ตัวตรวจ freeze ยังมีช่องโหว่ (ย้าย environment ไปไว้ผิด job แล้วยังผ่าน) → ปิดช่อง
  4. ตรวจวันหมดอายุซ้ำตอน Founder กดอนุมัติ (ตอนนี้ตรวจก่อนรออนุมัติเท่านั้น)
- **ความเสี่ยงเดิมระดับ HIGH ที่ Founder ต้องรู้ก่อน deploy**: branch `release/zoky-web-20261018` มี workflow เก่า (`wyn-158` เวอร์ชัน 12 ต.ค., `deploy-web.yml`) ที่กด deploy production ได้ **โดยไม่ต้องผ่านการอนุมัติ** ถ้า Vercel token ยังเป็น repository secret (หลักฐานบ่งชี้ว่าใช่) — แปลว่า freeze ทั้งหมด (ไม่ใช่แค่ ZOKY) ข้ามได้ ต้องย้าย secrets ไปอยู่ใน environment `production` หรือ Founder รับความเสี่ยงเป็นลายลักษณ์อักษร

## Checks run (this review)

| Check | Result |
|---|---|
| `python3 tools/check_wynos_release_freeze.py` | PASS |
| `python3 tools/test_check_wynos_release_freeze.py` | PASS (11 loosened variants rejected; deletion allowed) |
| `yaml.safe_load` on exception, ci, edge, wyn-158 workflows | all parse |
| `bash -n` on every `run:` block of the exception workflow | all 0 |
| `${{ … }}` expressions inside `run:` bodies | none (inputs only via `env:`) |
| Deploy step vs wyn-158 deploy step (comments stripped) | byte-identical |
| `git diff --name-only` vs `--no-renames` on `b19687af..31f13fb3` | identical; outside `web/ docs/ .wyn/` only the 2 auth scripts + 3 edge functions |
| Guard gap probe (scratch copy): move `environment: production` from `deploy` to `guard` | freeze guard still PASSES — gap (R3) |
| Push triggers on release tip workflows | all branch-filtered to `main`/other; pushing the release branch auto-deploys nothing |

Not run: actionlint (not installed), the workflow itself, Playwright, Deno — no dispatch by design.

## Findings

| ID | Severity | Finding |
|---|---|---|
| F1 | HIGH | Concurrency: exception uses group `wyn-158-production` with `cancel-in-progress: false`, but `wyn-158` uses the same group with `cancel-in-progress: true`. A new run's own setting governs, so **any** `wyn-158` dispatch (even one that would later fail its acceptance check — cancellation happens at queue time, before any step) cancels an exception run that is waiting for review or is mid-deploy. Mid-deploy cancellation can leave Vercel production moved but unverified. The old `wyn-158` on the release branch has the same group/`true`. |
| F2 | HIGH | `deploy-edge-functions.yml` has no `environment:` and no branch gate (pre-existing M3), so a production edge deploy is not Founder-gated by GitHub, contrary to the 2026-10-18 condition "each step requires Founder production approval". The new `wynos-maps-geocode` option widens that surface, and its verify_jwt hazard is protected only by a YAML comment. |
| F3 | MEDIUM | Freeze guard is substring-based: `environment: production` count == 1 passes even if the line is moved to the `guard` job (verified), leaving `deploy` (which holds the Vercel secrets) ungated. Same class: `cancel-in-progress: false` can be satisfied by a comment; no assertion that inputs never appear in `run:` bodies or that the group differs from wyn-158. |
| F4 | MEDIUM | Expiry is checked only in `guard`. A run can wait for environment approval for up to 30 days, so `deploy` could start after 2026-11-30. |
| C1 | HIGH (pre-existing, release-relevant) | `release/zoky-web-20261018` (pushed) carries the 2026-10-12 `wyn-158-production-deploy.yml` (`workflow_dispatch`, no `if`, no `environment`) and `deploy-web.yml` (`workflow_dispatch: {}`, `vercel deploy --prod`, no environment). Dispatching either **on the release ref** deploys production with no review and none of the exception guards. The 2026-10-12 production deploy ran from exactly that ungated workflow, which indicates `VERCEL_TOKEN`/`VERCEL_ORG_ID`/`VERCEL_PROJECT_ID` are repository-level secrets. This also applies to any old branch/tag, so the whole freeze is only advisory until deploy secrets are environment-scoped. Not introduced by this PR; the exception's "cannot ship anything else / every deploy Founder-approved" claim depends on it. |
| M1 | MEDIUM | `release_sha` is bound to "tip of the release branch", not to the Founder-recorded SHA; `web/**` is broadly allowlisted, so anyone who can push the release branch can change what ships. Binding relies on the Founder comparing the run-summary SHA with APPROVALS at review time. Branch has no confirmed protection. |
| L1 | LOW | `npx vercel@latest` and tag-pinned actions (`@v4`) — parity with wyn-158, but SECURITY_RULES asks for pinned sources in CI/CD. |
| L2 | LOW | `actions/checkout` persists the (read-only) `GITHUB_TOKEN` in `.git/config` while `npm ci` / Playwright run third-party code. |
| L3 | LOW | Verify step drops wyn-158's `maps_geo` warning/summary although this release changes `wynos-maps-geocode`. |
| L4 | LOW | Guard precondition proves `zoky.wynos.online` returns 200, not that it is attached to Vercel project `web` (PHASE1 smoke after deploy catches it; acceptable). |
| L5 | LOW | `git diff --name-only` relies on default rename detection; equivalent today (verified) but `--no-renames` is more robust. |

Confirmed OK: no script injection (all inputs via `env:`; `phase`/`confirmation` are choice types; step name interpolation is display-only); `guard` job holds no secrets and makes only an unauthenticated GET to `zoky.wynos.online` with output to `/tmp` and no redirects followed (fails closed); `permissions: contents: read`; definition runs only from `refs/heads/main`; deploy checks out `inputs.release_sha` and re-asserts `HEAD == RELEASE_SHA` (SHA immutable, so the guard→review→deploy gap is not a TOCTOU on content); ancestry + excluded SHAs + file/RPC-name checks cover cherry-picked re-introductions of #1133/#1135; config.toml check is strict (prefix-identical + one appended verify_jwt entry); `npm ci` (lockfile present on release tip) is stricter than wyn-158's `npm install`; `environment: production` precedes every step that touches production; secret handling identical to wyn-158 and never echoed; `wyn-158` asserted free of the exception string.

## Required changes before merge (R1–R4)

**R1 — Concurrency (fixes F1).** Do not modify `wyn-158` (Founder: wyn-158 stays unchanged). Give the exception its own lane:
```yaml
concurrency:
  group: zoky-web-exception-release
  cancel-in-progress: false
```
Rationale: removes the cancellation path; a real wyn-158 deploy cannot reach Vercel while #1142–#1151 are open (Founder decision keeps them open), and both workflows require the Founder's `production` review, which is the serialization point. Update the header comment, the freeze guard (assert the group is not `wyn-158-production`) and the test. Operational rule stays: do not dispatch wyn-158 during an exception release.

**R2 — Edge deploy gate (fixes F2).** In `deploy-edge-functions.yml`: add `environment: production` to the `deploy` job (strengthens; repository secrets remain readable; also required if C1 moves secrets). Replace the comment-only warning with a fail-closed step before deploy: if `inputs.function == 'wynos-maps-geocode'` and `supabase/config.toml` has no `[functions.wynos-maps-geocode]` entry, fail with the F2 instruction. Pass `inputs.function` via `env:` in the new step. Add freeze-guard assertions for both.

**R3 — Structural freeze guard (fixes F3).** Assert per job, not per file: e.g. split on `\n  deploy:\n` / `\n  guard:\n` and require `environment: production` inside `deploy` and absent from `guard`; require `secrets.` absent from `guard`; match `cancel-in-progress: false` as an uncommented line under `concurrency:`; assert no `${{ inputs.` appears in any `run:` body (allow `env:` and `with:`). Add the corresponding loosened variants to the test (env moved to guard; group set to `wyn-158-production`; inputs in run; edge environment removed).

**R4 — Expiry in deploy (fixes F4).** Repeat the "Exception has not expired" check as the first step of `deploy` (after environment approval) and assert it twice in the freeze guard.

## Conditions before the first production dispatch (A4/A5) — Founder

- **C1 (HIGH, pre-existing)** — choose one and record in DECISIONS/APPROVALS:
  (a) recommended: move `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`, `SUPABASE_ACCESS_TOKEN` to `production` environment secrets with deployment-branch policy `main` + required reviewers (note: `web-next-phase5-preview.yml` preview deploys and other environment-less users of these secrets then need a separate preview-scoped token); or
  (b) explicit, documented Founder risk acceptance that ungated workflows on old refs (including the release branch) can deploy production until (a) is done.
  Changing secret scoping is a security/infra change → Founder approval, not an agent action.
- **M1** — protect `release/zoky-web-20261018` (no force-push, no deletion, restricted pushers). At every `production` review the Founder compares the run-summary `release_sha` and commit list with the APPROVALS entry for that phase.
- F1/F2/F3 of the release plan (Vercel production = `b19687af`; `production` env reviewers; geocode Verify JWT state; OAuth/Firebase origins) and `zoky.wynos.online` attached (currently 404).

## Recommended (non-blocking)

- L1: pin `vercel@<exact version>` (the version that last deployed successfully) in this workflow; SHA-pin actions when wyn-158 is next touched.
- L2: `persist-credentials: false` on both checkouts.
- L3: restore the `maps_geo` summary/warning lines from wyn-158.
- L5: `git diff --no-renames --name-only`.
- Write the rollback target (`web-5djnkfh16` / `b19687af` for PHASE1; the PHASE1 deployment URL for PHASE2) into the guard summary so the reviewer sees it before approving.

## Rollback assessment

Adequate as documented in the release plan §7: Vercel Instant Rollback (no build) + domain redirect for phase 1; Instant Rollback to the phase-1 deployment for phase 2. The workflow has no automatic rollback: if post-deploy verification fails, production has already moved — the runbook must say "on red verify step, Founder performs Instant Rollback to the recorded target, then investigate". A rollback through the workflow requires a revert commit on the release branch (guard requires the branch tip) — auditable and acceptable. Edge rollback depends on R2/F2 (same verify_jwt setting). Merging this PR itself deploys nothing; reverting it is a normal revert PR.

## Residual risks / not verified

- `production` environment reviewer list, branch policy and secret scoping (API not accessible here; C1 inference is from the 2026-10-12 run history in the release plan).
- Workflow never executed; actionlint not run.
- No claim of zero regression.

## Resolution (Deploy & DevOps, 2026-10-18)

Applied on `ci/zoky-web-exception-release`; workflow/guard changes only, nothing dispatched or deployed, `wyn-158-production-deploy.yml` unchanged. Re-review = diff check.

| Item | Commit | Change |
|---|---|---|
| R1 / F1 | `ea5c86b1` | Exception concurrency group `zoky-web-exception-release`, `cancel-in-progress: false`; wyn-158 untouched |
| R4 / F4 | `8bcc33e5` | "Exception has not expired" repeated as the first `deploy` step (after environment approval) |
| R2 / F2 | `a62c1018` | `deploy-edge-functions.yml`: `environment: production` on `deploy`; fail-closed step blocks a `wynos-maps-geocode` deploy when `supabase/config.toml` has no `[functions.wynos-maps-geocode]` entry (input via `env:`) |
| L1/L2/L3/L5 + rollback | `e73566b8` | `vercel@63.1.2` (the CLI npx resolved for wyn-158's last successful production deploy of `b19687af`, run 38241263711; also pinned by `wynos-admin-consolidated-release.yml`); `persist-credentials: false` on all checkouts; `maps_geo` warning restored; `git diff --no-renames`; guard summary shows rollback target `web-5djnkfh16` / `b19687af` (PHASE2: the recorded PHASE1 deployment) |
| R3 / F3 | `c267f422` | Freeze guard checks per job (env on `deploy` only, no secrets in `guard`, jobs exactly guard+deploy, concurrency group/cancel uncommented, expiry first in both jobs, no `${{ inputs.* }}`/`github.event.inputs` in any `run:` body incl. comments, checkout creds, pinned CLI) and asserts the edge gates; tests now reject 23 + 3 loosened variants (incl. env moved to guard, wyn-158 group, inputs in run) |
| Edge phase (C1 follow-up) | `10af1344` | Phase `EDGE` + `edge` job: main-only, `needs: guard`, `environment: production`, expiry re-check, pinned `release_sha` checkout (`persist-credentials: false`) + HEAD re-verify, fail-closed `[functions.wynos-maps-geocode]` pin, deno check/test, Supabase CLI `2.120.0` (what setup-cli `latest` resolved to for run 38213758869 on 2026-10-12, per npm publish times; 2.121.0 came out 2026-10-14), deploys only `ZOKY_EDGE_FUNCTIONS` = food-stripe-checkout, food-stripe-cancel, wynos-maps-geocode. Web `deploy` skips EDGE. Freeze guard enforces all of it (34 + 3 loosened variants rejected). **Needs CTO re-review** (new production path) |

Validation: `yaml.safe_load` on exception/edge/ci/wyn-158; `bash -n` on every `run:` step (0 failures); `check_wynos_release_freeze.py` PASS; `test_check_wynos_release_freeze.py` PASS; edge pin step simulated (geocode without entry fails, with entry / other functions pass). Not run: actionlint, the workflows themselves.

Release plan section 9 notes (to apply on `release/zoky-web-20261018` with the next plan update):
- Runbook step 11 (A4) changes. Dispatch **this workflow** with `phase=EDGE` and the APPROVALS `release_sha`, then approve the `production` review. Do **not** dispatch `deploy-edge-functions.yml` on the release ref. After C1 (`main`-only environment) that is refused, and the release branch's own 2026-10-12 copy of that workflow has no environment.
- The order stays EDGE, then PHASE1, then PHASE2. The workflow cannot check from the guard (no secrets) that EDGE already ran, so the Founder enforces the order at each review (APPROVALS entry per phase).
- F2 is now a hard precondition. The EDGE job fails unless the release SHA's `supabase/config.toml` has the `[functions.wynos-maps-geocode]` entry. The guard already allows exactly that one appended entry.
- Edge rollback is `deploy-edge-functions.yml` dispatched on `main`, because `main` equals the current production source of all three functions (verified with `git diff b19687af origin/main` and `27e9b64d..main`). For `wynos-maps-geocode`, `main`'s config.toml needs the same verify_jwt entry, or its pin step blocks the rollback. Land that one-line entry on `main` (small PR, CTO/QA) before A4.
- `ci/deploy-secrets-environment` (C1) merges cleanly with this branch (simulated). `deploy-edge-functions.yml` is byte-identical on both.

Still open (Founder): C1, M1 and release-plan F1–F3 before the first production dispatch. Pre-existing `${{ inputs.function }}` in edge `run:` bodies left as-is (choice-typed, not injectable; out of scope).

## CTO Re-review (2026-10-18) — R1–R4 + EDGE phase

- Reviewer: WYN CTO (AI) | Branch tip reviewed: `81bbb3a5` | Mode: read-only (no env/secrets, no dispatch, no deploy, no PR, no merge)

### Verdict: **APPROVED WITH CONDITIONS**

Merge is approved: merging deploys nothing (only `ci.yml` fires on push). The conditions below apply **before the first `phase=EDGE` dispatch (A4)**, not before merge.

### สรุปสำหรับ Founder (ภาษาไทย)

- แก้ครบทั้ง 4 ข้อ (R1–R4) ตรวจแล้วถูกต้อง และขั้น EDGE ใหม่ (deploy edge function 3 ตัวจาก commit ที่ล็อกไว้) ปลอดภัย: ต้องรันจาก `main`, ต้องผ่านปุ่มอนุมัติ `production`, deploy ได้แค่ 3 ตัวที่กำหนด, ไม่ใช้กุญแจ Vercel, ตรวจวันหมดอายุซ้ำ และหยุดเองถ้ายังไม่ได้ตั้งค่า verify_jwt ของ geocode
- **merge ได้** แต่ก่อนกด EDGE ครั้งแรกต้องทำ 3 อย่าง:
  1. เพิ่มบรรทัดตั้งค่า `[functions.wynos-maps-geocode]` (ค่าที่อ่านจาก Supabase ในข้อ F2) ทั้งบน branch release **และบน `main`** — ไม่งั้น rollback geocode จาก `main` จะถูกบล็อก
  2. รู้ไว้ว่า: ถ้าเปิด ZOKY (ขั้น 1/2) ไปแล้ว **ห้าม rollback edge function อย่างเดียว** เพราะเวอร์ชันบน `main` ยังไม่รู้จัก `zoky.wynos.online` → จ่ายบัตรบน ZOKY จะพัง ต้อง rollback เว็บก่อนแล้วค่อย rollback edge
  3. rollback edge ต้องให้ Founder กดอนุมัติเช่นกัน (ช้ากว่ากดเองได้ทันที) — ให้วางแผนเวลาที่ Founder ว่างตอน release

### R1–R4 verification

| Item | Verified at `81bbb3a5` | Result |
|---|---|---|
| R1 / F1 | `concurrency.group: zoky-web-exception-release`, `cancel-in-progress: false`; guard asserts group != wyn-158's group; wyn-158 untouched vs `origin/main` | OK |
| R2 / F2 | `deploy-edge-functions.yml`: `environment: production` on `deploy`; fail-closed geocode pin step with input via `env:`; freeze guard asserts both (3 loosened variants rejected) | OK |
| R3 / F3 | Per-job structural checks (`jobs_of`, `job_key`, `run_bodies`): env only on `deploy`/`edge`, none + no `secrets.` on `guard`, exact job set, exact `if:` per job, expiry first step in every job, no `${{ inputs.* }}`/`github.event.inputs` in any `run:` body (raw text incl. comments), pinned CLIs, checkout creds | OK |
| R4 / F4 | "Exception has not expired" is the first step of `deploy` and `edge` (after environment approval) and of `guard` | OK |
| L1/L2/L3/L5 | `vercel@63.1.2`, `persist-credentials: false` on all 3 checkouts, `maps_geo` lines restored, `--no-renames` | OK |

### EDGE job review

Confirmed OK:
- Gate: `needs: guard` (guard re-proves release SHA = branch tip, base ancestry, #1133/#1135 exclusion, path allowlist, config.toml = base + exactly one appended geocode `verify_jwt` entry); job `if:` = main-only + confirmation + `phase == 'EDGE'`; `environment: production`; web `deploy` job skips EDGE, so one dispatch never ships both.
- Pinned content: checks out `inputs.release_sha` (immutable) and re-asserts HEAD. All three function directories are self-contained (`food-stripe-cancel` imports `../food-stripe-checkout/_lib.ts`, deployed from the same SHA; no `_shared`, no import map). Only `npm:@supabase/supabase-js@2.112.3` (pinned).
- Allowlist: `ZOKY_EDGE_FUNCTIONS` is a workflow constant, the only `functions deploy` call in the file, no `--no-verify-jwt`; verify_jwt comes from config.toml at the release SHA (base entries for both Stripe functions are `verify_jwt = true`).
- Secrets: only `SUPABASE_ACCESS_TOKEN`/`SUPABASE_URL` in the deploy step env; no Vercel credentials; token never echoed; `deno check/test` steps run without secrets in env.
- No injection: inputs reach shell only via `env:`; `ref:` interpolation is not shell.
- Supabase CLI pin `2.120.0`: plausible and acceptable. npm publish times: 2.119.0 2026-09-30, **2.120.0 2026-10-06**, 2.121.0 2026-10-14; no 2.120.x patch; the GitHub release asset `v2.120.0/supabase_linux_amd64.tar.gz` exists (302). So `latest` on 2026-10-12 resolved to 2.120.0. Still an inference (run log not read); a wrong guess is low-risk because the deploy fails loudly, it does not misdeploy. Deno `v2.9.7` asset exists.
- With `ci/deploy-secrets-environment` merged, `check_production_secret_scoping.py` passes (both `deploy` and `edge` carry `environment: production`).

Findings (new):

| ID | Severity | Finding | Disposition |
|---|---|---|---|
| E1 | MEDIUM (ops) | Edge rollback is `deploy-edge-functions.yml` on `main`. `main` has no `[functions.wynos-maps-geocode]` entry (verified), so its pin step blocks a geocode rollback. Release tip `31f13fb3` also lacks it, so EDGE fails closed today (intended). | **Condition A**: land the one-line entry, with the same value read in F2, on `main` (small PR, CTO/QA) **and** on the release branch before A4. If F2 says `verify_jwt = false`, QA confirms the function's own origin check / rate limiting first. |
| E2 | MEDIUM (ops) | `main`'s `food-stripe-checkout`/`-cancel` equal production `b19687af` and do **not** allow `https://zoky.wynos.online`. Rolling back those functions alone after PHASE1 (or PHASE2, when all Food traffic is on zoky) breaks card checkout/cancel on ZOKY. | **Condition B**: runbook says edge rollback after PHASE1 = roll back web first (Vercel Instant Rollback), then edge. Before PHASE1 an edge rollback is safe. |
| E3 | LOW (ops) | Rollback through `deploy-edge-functions.yml` now needs the Founder's `production` approval, so recovery time depends on Founder availability. Partial failure (set -e stops mid-loop) leaves earlier functions deployed; the summary lists which. | Condition C: Founder available for the EDGE window; rollback per listed function. |
| E4 | LOW | `phase` relies on GitHub's choice validation; the guard does not itself reject a value outside EDGE/PHASE1/PHASE2 (a non-listed value would take the web path and skip the PHASE2 precondition). | Recommended: `case "$PHASE" in EDGE|PHASE1|PHASE2) ;; *) exit 1;; esac` in the guard. Non-blocking. |
| E5 | LOW | No automated post-deploy smoke for the 3 functions (manual plan section 4 smoke). | Acceptable; run the section 4 smoke immediately after approval. |

Observation (outside this PR): the release branch changes `.github/scripts/sync-auth-password-policy.sh` (additive ZOKY redirect URLs), but no exception path runs it; ZOKY auth redirect URLs must reach production another way (release plan F3 / Founder dashboard). `main`'s version is additive too, so it never removes ZOKY entries.

Still open from the first review: C1 (in progress via `ci/deploy-secrets-environment`), M1 (protect `release/zoky-web-20261018`), release-plan F1–F3.

### Checks run (re-review)

| Check | Result |
|---|---|
| `check_wynos_release_freeze.py` / `test_check_wynos_release_freeze.py` (branch) | PASS / PASS (34 + 3 loosened variants rejected) |
| `yaml.safe_load` all 97 workflows + `bash -n` on all 224 bash `run:` blocks (`${{ }}` stubbed) | 0 failures |
| Simulated merge of both CI branches into `origin/main` (either order; identical trees, `ci.yml` auto-merges) | all guards PASS (freeze + test, secret scoping + test, schema ordering, `test-auth-*.sh`); 97 workflows parse; 225 run blocks `bash -n` clean; 78 credential workflows / 80 jobs all `environment: production` |
| Push-trigger simulation of this branch's diff | only `ci.yml` fires on merge |
| `deploy-edge-functions.yml` vs `ci/deploy-secrets-environment` | byte-identical |

Not run: actionlint, deno (not installed), the workflows themselves. No claim of zero regression.

### Merge order

1. `ci/deploy-secrets-environment` first (closes the ungated production-credential gap at merge time and removes the Overture push-triggered write), 2. this branch. Either order is conflict-free and yields the same tree. See `deploy-secrets-environment-cto-review.md` on that branch for the full sequence.
