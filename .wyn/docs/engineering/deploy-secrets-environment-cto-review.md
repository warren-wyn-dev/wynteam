# CTO Review — deploy secrets into the `production` environment (C1)

- Reviewer: WYN CTO (AI) | Date: 2026-10-18 | Mode: read-only (no env/secrets read, no settings changed, no dispatch, no deploy, no PR, no merge)
- Branch: `ci/deploy-secrets-environment` @ `0d9dc1f4` (2 commits on `origin/main` `42a8f937`)
- Reviewed: 71 workflows gaining `environment: production`, `wynos-maps-import-overture-places.yml`, `deploy-edge-functions.yml`, `ci.yml`, `tools/check_production_secret_scoping.py`, `tools/test_check_production_secret_scoping.py`, `.wyn/docs/engineering/deploy-secrets-environment-migration.md`
- Inputs: `AGENTS.md`, Founder decision 2026-10-18 "ZOKY release — ย้ายกุญแจ deploy เข้า production environment" (`docs/zoky-foundation:.wyn/company/DECISIONS.md`), `zoky-exception-workflow-cto-review.md` (C1), `zoky-web-release-plan.md` (release branch)

## Verdict: **APPROVED WITH CONDITIONS**

The workflow change is correct and safe to merge: every job on `main` that reads `SUPABASE_ACCESS_TOKEN` or `VERCEL_TOKEN` (78 jobs in 77 workflows) now declares `environment: production`, PR-triggered runs skip every gated job, and nothing breaks while the repo secrets still exist. The conditions are about the Founder steps and the ZOKY sequence, which happen **after** merge. One small guard fix is recommended.

## สรุปสำหรับ Founder (ภาษาไทย)

- **merge ได้** — หลัง merge ระบบเดิมยังทำงานเหมือนเดิม แค่งานที่ใช้กุญแจ production จะรอ Founder กดอนุมัติก่อน ตอน merge จะมีงาน 2 งานขึ้นมารออนุมัติ (Auth password policy, Email readiness) กดอนุมัติหรือปฏิเสธก็ได้ ปลอดภัยทั้งคู่
- **ก่อนทำขั้นตอน iPad ต้องแก้/รู้ 4 เรื่อง:**
  1. **ข้อ 13–14 (ทดสอบกุญแจ Supabase) ให้ผลผิดได้** — workflow `admin-supabase-status-check` ขึ้นสีเขียวแม้กุญแจผิด ต้องแก้ workflow ก่อน (เพิ่ม `--fail`) หรือเปิดดู log ว่ามีคำว่า `ACTIVE_HEALTHY` ไม่ใช่ `Unauthorized`
  2. **กุญแจ `ANDROID_SECRETS_TOKEN`** เขียนทับ secrets ของ repo ได้ และ workflow ที่ใช้มันไม่มีปุ่มอนุมัติ — ถ้าสร้าง Android upload key ไปแล้ว ให้ลบ secret นี้และยกเลิก token ใน GitHub ไปพร้อมส่วน E
  3. **ZOKY staging**: แผน release ให้ทำ preview ของ branch ZOKY ด้วย `web-next-phase5-preview` — หลังลบกุญแจเก่า (ส่วน E) จะทำ preview จาก branch ZOKY ไม่ได้อีก → ทำ staging preview ของ ZOKY ให้เสร็จก่อนส่วน E หรือให้ทีมเพิ่มขั้น preview ใน workflow ข้อยกเว้น
  4. ข้อ 18–19 "ลบ/ยกเลิกกุญแจเดิมทุกอัน": ถ้ามีกุญแจที่เครื่องมืออื่นยังใช้ (เช่น CLI บนเครื่อง) จะใช้ไม่ได้ทันที — ตั้งใจให้เป็นแบบนั้น แต่ให้ดูชื่อก่อนลบ
- ลำดับ merge ที่แนะนำ: PR นี้ก่อน แล้วค่อย PR workflow ข้อยกเว้น ZOKY (ไม่ชนกัน)

## Checks run

| Check | Result |
|---|---|
| `check_production_secret_scoping.py` / its test | PASS (96 workflows) / PASS (7 ungated variants rejected, block form accepted) |
| `check_wynos_release_freeze.py`, `supabase/check_schema_ordering.py` | PASS |
| Independent YAML audit (PyYAML, per job): jobs reading the 2 credentials | `origin/main`: 77 workflows, 6 gated; branch: 77 workflows, **78/78 jobs gated**, none at workflow level; no `secrets[...]`, `toJSON(secrets)`, `secrets: inherit`, `workflow_call` or `schedule` users |
| Duplicate-key YAML load (GitHub rejects duplicates, PyYAML does not) | 0 duplicates |
| `yaml.safe_load` + `bash -n` on every bash `run:` block | 0 failures |
| Trigger simulation of the merge diff (push to `main` / this PR) | push: `ci.yml`, `web-beta1-auth-password-policy` (`apply` waits for approval), `web-beta1-email-readiness` (`audit` waits). PR: those 2 + `web-beta1-safe-recovery-email` + `web-next-phase5-preview` run only ungated jobs; every gated job's `if:` excludes `pull_request`, so no PR check hangs on approval. Overture import: the new file version has no push trigger, so the merge does not fire it |
| Simulated merge of both CI branches into `origin/main` (either order, identical trees) | all guards and tests PASS (freeze + test, scoping + test, schema ordering, `test-auth-*.sh`); 97 workflows parse; 225 run blocks clean; 78 credential workflows / 80 jobs gated |
| Repo facts (unauthenticated public API) | `warren-wyn-dev/wynteam` is **public** and **user-owned**: required reviewers and branch policies are available on every plan; there are no organization secrets that could shadow a deleted repo secret |

Not run: actionlint, the workflows. Environment settings and secret locations not readable here.

## Findings

| ID | Severity | Finding | Disposition |
|---|---|---|---|
| S1 | MEDIUM | Founder step 13–14 smoke test can pass with a bad token: `admin-supabase-status-check.yml` runs `curl -sS ... \| jq .` without `--fail`, so a 401 `{"message":"Unauthorized"}` still exits 0 and shows green. Step 15 (Vercel) does fail on auth errors. | **Condition 1** (before Part D): add `--fail` (or `--fail-with-body`) to that curl on this branch, or amend steps 14/20 to require `"status": "ACTIVE_HEALTHY"` in the log. |
| S2 | HIGH (pre-existing, C1-adjacent) | `ANDROID_SECRETS_TOKEN` (fine-grained PAT, Secrets read/write) stays repo-level and is read by `android-upload-key.yml` with no environment. Anyone with write access can dispatch an edited branch copy (dropping its `if:`) and overwrite repo secrets such as `SUPABASE_URL`, `VERCEL_PROJECT_ID` or `FIREBASE_*` that the Founder-approved production deploys consume (integrity attack, not a read). The workflow itself says to delete the token after use. | **Condition 2** (with Part E): if the upload key already exists, delete the `ANDROID_SECRETS_TOKEN` repo secret and revoke the PAT; otherwise gate that job with an environment before its single run, then delete. Add this as a step in Part E. |
| S3 | HIGH (ZOKY sequence) | ZOKY release plan step 7 stages via `web-next-phase5-preview.yml` dispatched **on the release ref**. That copy has no environment, so after step (c) it gets no `VERCEL_TOKEN`; `main`'s gated copy cannot preview the release (the `main`-only policy refuses other refs). The migration doc's "ZOKY impact" covers edge deploys but not staging. | **Condition 3**: either finish the ZOKY staging preview before step (c) (minimal, no code), or add a release-SHA-pinned preview phase to the exception workflow (code change, CTO review). Record the choice in APPROVALS. |
| S4 | MEDIUM | `check_production_secret_scoping.py` fails open on 3 syntactic forms (verified in a scratch copy): 4-space-indented `jobs:`, a job key with a trailing comment (`  evil: # x`) and a quoted job key — the credential is attributed to no job or to the previous gated job. GitHub-side enforcement after step (c) is the real control, so this is defence in depth. | Recommended before merge (small): fail when a credential appears in the text before the first recognised job, and accept `^  ['"]?([A-Za-z0-9_-]+)['"]?:[ ]*(#.*)?$` as a job key; add the 3 variants to the test. Non-blocking. |
| S5 | LOW | Migration doc step 0 says a private repo needs Pro/Team/Enterprise for required reviewers. The repo is public, so it is moot; for private repos on non-Enterprise plans required reviewers are not available. | Doc correction when next edited. |
| S6 | LOW | Steps 18–19 revoke "every old token" in Vercel/Supabase; other tools using them (local CLI, connectors) break. Intended, but the Thai text should say "check names first". | Doc wording. |
| S7 | LOW (ops) | After merge, every `wyn-158` success queues 3 approval-waiting runs (auth policy, email readiness, recovery email); runs left unapproved expire after 30 days. Overture import becomes dispatch-only (default `dry_run: true`) — correct. | Accepted; documented in the migration doc. |

Founder steps (Parts A–E) check: GitHub UI names are accurate (Settings → Environments → production; Deployment protection rules → Required reviewers, "Prevent self-review" off is correct for a sole reviewer who also dispatches; "Allow administrators to bypass configured protection rules" untick; Deployment branches and tags → Selected branches and tags → Add deployment branch or tag rule → `main`; Environment secrets → Add environment secret; Repository secrets trash icon). Order is right: new tokens → environment secrets (they override same-name repo secrets) → smoke → delete repo secrets → revoke old tokens → smoke again. Rollback guidance (never restore old tokens) is right. `workflow_run` and `push` jobs run on `main` and satisfy the branch rule.

Things that keep working after merge (repo secrets still present): all 77 credential workflows (now approval-gated), CI (`ci.yml` reads no credential), Android workflows (own environment / no credential), PR checks. After step (c): any ungated copy on an old branch/tag gets empty credentials (intended, closes C1); the `web-next-phase5-preview` path only previews `main` (S3).

## Conditions

Before merge: none blocking (S4 recommended).

Before the Founder runs Part D: Condition 1 (S1).

Before Part E / step (c): Condition 2 (S2) added to Part E; Condition 3 (S3) decided and, if "staging first", the ZOKY staging preview done.

## Recommended merge and execution order

1. Merge `ci/deploy-secrets-environment` (this PR). Approve or reject the 2 queued auth runs (both idempotent).
2. Merge `ci/zoky-web-exception-release` (CTO re-review: APPROVED WITH CONDITIONS). Conflict-free in either order; this order closes the ungated-credential gap first.
3. Small PR to `main`: `[functions.wynos-maps-geocode]` verify_jwt entry (value from release-plan F2), needed for edge rollback; same entry on the release branch.
4. Founder Parts A–C (reviewer = Founder, `main` only, new tokens as environment secrets), then Part D with Condition 1 fixed.
5. ZOKY staging preview on the release ref (if Condition 3 = staging first).
6. Founder Part E (delete repo secrets, revoke old tokens, `ANDROID_SECRETS_TOKEN`), smoke again, record C1 done in DECISIONS/APPROVALS.
7. ZOKY: EDGE → PHASE1 → PHASE2 through the exception workflow, each with its own Founder approval.

## Rollback

Revert the PR (repo secrets remain until step (c)). After (b): delete the environment secrets to fall back. After (c): new token into the environment; never restore old tokens.

## Residual risks / not verified

- Current `production` environment reviewers, branch policy and admin-bypass setting, and where the secrets live today (API not accessible).
- The 50 RETIRE workflows remain (gated, harmless); deletion awaits Founder go-ahead.
- A stray Vercel Git-integration project (`wynteam-gesb`, per release plan) deploys on every push; it holds no production domain per CONTEXT.md, unverified here.
- No claim of zero regression; workflows not executed.
