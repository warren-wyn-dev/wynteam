# ZOKY web — Release Plan (production-freeze exception)

- Author: WYN Deploy & DevOps (AI) | Date: 2026-10-18 | Mode: READ-ONLY preparation (no deploy, no dispatch, no push, no Vercel/Supabase/DNS change, no secrets read)
- Scope: ZOKY web on `zoky.wynos.online` (ZOKY-113/114, ZOKY-135..138, two-phase flag `ZOKY_LEGACY_FOOD_REDIRECT`) + edge functions `food-stripe-checkout`, `food-stripe-cancel`, `wynos-maps-geocode`
- Inputs: Founder decisions 2026-10-18 (`docs/zoky-foundation:.wyn/company/DECISIONS.md`, last 4 entries), handoff `.wyn/tasks/active/ZOKY-113-114-web-rebrand-handoff.md`, CTO review `.wyn/docs/engineering/zoky-web-rebrand-cto-review.md`, workflows `wyn-158-production-deploy.yml`, `deploy-web.yml`, `deploy-edge-functions.yml`, `web-beta1-auth-password-policy.yml`, `web-next-phase5-preview.yml`, `tools/check_wynos_release_freeze.py`, `.github/scripts/require-wynos-final-release-ready.sh`, `docs/engineering/GIT_WORKFLOW.md`, `WEB_STAGING.md`, GitHub deployments/Actions history (read-only API)

---

## สรุปสำหรับ Founder (ภาษาไทย)

**ผลตรวจหลัก: ต้องหยุดและรายงานตามเงื่อนไขข้อยกเว้น** — ถ้า deploy จาก `main` ตามปกติ (workflow `wyn-158`) จะมีงานที่ยังไม่ผ่าน acceptance ติดขึ้น production ไปด้วย

1. **production ตอนนี้ (Consumer Web, Vercel project `web`)** คือ commit `b19687af` (12 ต.ค. 2026, run `wyn-158` #38241263711, deployment `web-5djnkfh16-warren14.vercel.app` → alias `wynos.online`) — หลังจากนั้นทุกครั้งที่พยายาม deploy เว็บถูกยกเลิกหรือล้มเหลว (ครั้งล่าสุด 13 ต.ค. ล้มเพราะโควตา Vercel 100 deploy/วันเต็ม ไม่ได้สร้าง deployment)
2. **`main` ตอนนี้ (`42a8f93`) มี 20 commit ที่ยังไม่ขึ้น production** ส่วนใหญ่เป็นงาน Admin (โฟลเดอร์ `admin/` ไม่อยู่ในเว็บลูกค้า) และ workflow/เอกสาร แต่มี **2 PR ที่แก้หน้าเว็บลูกค้าจริง**: PR #1133 (แบนเนอร์หน้าแรกจาก Admin) และ PR #1135 (ร้านแนะนำจาก Admin) — ทั้งสองอยู่ใน acceptance **#1142 "Food หน้าแรก ค้นหา ร้านแนะนำ แบนเนอร์" ซึ่งยัง open** → ถ้า deploy จาก main งานนี้จะขึ้นไปด้วย = ผิดเงื่อนไข
3. **ทางที่ปลอดภัยที่สุด (แนะนำ)**: ตัด branch ปล่อยของ `release/zoky-web-20261018` จาก commit ที่อยู่บน production (`b19687af`) แล้วใส่เฉพาะ commit ของ ZOKY (ทดลองบนเครื่องแล้ว: ใส่ได้ครบ มีจุดชนกัน 3 จุดซึ่งเป็นโค้ดแบนเนอร์/ร้านแนะนำของ #1133/#1135 พอดี — แก้โดยตัดส่วนนั้นออก) ผลคือเว็บที่จะขึ้น = production เดิม + ZOKY เท่านั้น
4. **กลไกข้อยกเว้น**: เพิ่ม workflow ใหม่แยกเฉพาะครั้งนี้ `zoky-web-exception-release.yml` (ไม่แก้ `wyn-158`, ไม่ปิด issue #1142–#1151, ไม่ลด protection ของ environment `production` — ยังต้องให้ Founder กดอนุมัติทุกครั้ง) ที่ deploy ได้เฉพาะ commit ที่ Founder อนุมัติไว้ ตรวจอัตโนมัติว่าไม่มีไฟล์นอกขอบเขต ZOKY และหมดอายุเองตามวันที่กำหนด — **การแก้ workflow ต้องได้รับอนุมัติจาก Founder ก่อน (ตอนนี้เป็นแค่ข้อเสนอ)**
5. **Edge functions**: `food-stripe-checkout`, `food-stripe-cancel` deploy ผ่าน workflow เดิมได้; `wynos-maps-geocode` **ไม่มีใน workflow** (ต้องเพิ่มตัวเลือก) และ **มีความเสี่ยงซ่อน**: ถ้า deploy ด้วยค่าเริ่มต้นจะเปิด "ตรวจ JWT" ซึ่งอาจทำให้ผู้ใช้ที่ยังไม่ล็อกอินค้นหาที่อยู่ไม่ได้ — ต้องให้ Founder ดูค่าปัจจุบันใน Supabase Dashboard ก่อน แล้วตั้งค่าใน `supabase/config.toml` ให้ตรง
6. **Merge เข้า main = แก้ Supabase Auth production ทันที** (เพิ่ม redirect URL ของ zoky 3 รายการ แบบเพิ่มอย่างเดียว ไม่ลบของเดิม) — merge ได้หลังเพิ่มโดเมนใน Vercel แล้วเท่านั้น และไม่ทำให้เว็บ deploy เอง
7. **DNS**: เอกสาร repo (APPROVALS 2026-10-11) ระบุว่า `*.wynos.online` ชี้ไป Vercel อยู่แล้ว และตรวจแล้ว `zoky.wynos.online` resolve ไป IP ของ Vercel แล้ว → **ไม่น่าต้องแก้ DNS** แค่เพิ่มโดเมนในโปรเจกต์ `web` ของ Vercel

**สิ่งที่ Founder ต้องตัดสิน/อนุมัติ (เรียงลำดับ)** — รายละเอียดในหัวข้อ 6
- A1 ยืนยันว่าจะใช้ทาง release branch จาก production (แนะนำ) หรือทางอื่นในหัวข้อ 3
- A2 อนุมัติ PR แก้ workflow (exception workflow + เพิ่ม `wynos-maps-geocode` ใน edge workflow + ปรับ freeze check)
- A3 อนุมัติ push/PR/merge `feat/zoky-web-rebrand` เข้า main (= เพิ่ม Auth redirect URL production)
- A4 อนุมัติ deploy edge functions 3 ตัว (production)
- A5 อนุมัติ phase 1 (เปิด zoky.wynos.online, food เหมือนเดิม) — กดอนุมัติใน GitHub environment `production`
- A6 อนุมัติ phase 2 (เปิด redirect food → zoky) หลัง smoke phase 1 ผ่าน
- รับความเสี่ยง L3–L5 ตาม CTO review และแผนสื่อสารผู้ใช้ (AC9)

---

## 1. What is live vs `origin/main` (evidence)

### 1.1 Consumer Web production (Vercel project `web`, `prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`, team `warren14`)

| Item | Value | Source |
|---|---|---|
| Live commit | `b19687afdec361da846a2d9ceb11429547c92a24` "Merchant: 24h completed orders, order history and customer feedback" | WYN-158 run `38241263711` (push, 2026-10-12T11:13Z), all steps success incl. "Verify production routes" |
| Live deployment | `https://web-5djnkfh16-warren14.vercel.app`, "Aliased https://wynos.online" at 2026-10-12T11:35:56Z | run log |
| Later attempts | run `38376948250` @ `806390ed` cancelled during browser QA; run `38379557100` @ `55a290e9` failed at "Deploy to Vercel production": `Resource is limited - try again in 24 hours (more than 100, code: "api-deployments-free-per-day")` — **no deployment created** | job logs |
| Other paths that deploy to `web` | `deploy-web.yml` last run 2026-09-13; `web-next-phase5-production.yml` 2026-09-13; `web-promote-public-features.yml` 2026-09-30 (retired); `dispatch-deploy-web-once-20260912.yml` 2026-09-12 — none after 2026-10-12 | Actions run lists |
| GitHub env `production` deployments after 10-12 | only `admin-control-centers-one-time-release.yml` runs (Admin project `prj_Ca3S…`, not Consumer Web) | deployments API |

Caveat: GitHub cannot show manual Vercel dashboard actions (Instant Rollback/Promote). **Founder must confirm in Vercel → project `web` → Deployments that the current Production deployment is `web-5djnkfh16` / `b19687af`** before any release (step F1).

Side finding: Vercel GitHub integration project **`wynteam-gesb`** creates "Production – wynteam-gesb" deployments on every push to `main` (latest `42a8f937`, `wynteam-gesb-7gw38glk8-warren14.vercel.app`) and previews on every branch push. Per CONTEXT.md (2026-08-25) these `wynteam-*` projects are stray/not user-facing, but they **consume the same 100 deployments/day quota** that broke the 10-13 release. Founder should confirm `wynteam-gesb` has no custom domain and consider disconnecting it (separate decision, not part of this release).

### 1.2 Edge functions currently deployed (Supabase `kqokpocajhfbidcxpvhh`)

| Function | Last CI deploy | Delta to release content |
|---|---|---|
| `food-stripe-checkout` | `deploy-edge-functions.yml` run `38213758869` @ `27e9b64d` (2026-10-12) | only ZOKY commit `574f12e8` (+ test commit `738d4818`); no other main change since `27e9b64d` |
| `food-stripe-cancel` | not found in CI history back to 2026-09-26 (deployed outside CI, version unknown) | `index.ts` unchanged on main since 2026-10-10; ZOKY adds `import { isFoodWebOrigin } from "../food-stripe-checkout/_lib.ts"` (pure helper) |
| `wynos-maps-geocode` | never via CI (not an option in the workflow); version unknown | ZOKY adds 1 allowlist line |

### 1.3 Commits on `origin/main` not in production (`b19687af..42a8f937`, 20 commits)

| Commit | Title | Touches | Classification |
|---|---|---|---|
| `897da66f`, `cf2e2cf9` | Ponytail instructions (PR #1120) | `AGENTS.md` | docs — not shipped |
| `c47e0f7c` | Admin: Food and Merchant control centers (PR #1125) | `admin/` | **Admin, unaccepted** (#1142–#1151) — not in web build |
| `7a8fdae2`, `5b3be565`, `15a0dbfa`, `7f542cb9` | release(admin) one-time releases | `.github/workflows` | CI — Admin project |
| `eb85fec2` | Admin: live per-store delivery (PR #1128) | `admin/`, migration | **Admin, unaccepted** (#1148) |
| `d119479e` | Admin Food: first-order campaign terms | `admin/` | **Admin, unaccepted** (#1144) |
| `292d53dc` | Admin Merchant: live menu catalog (PR #1131) | `admin/`, migration | **Admin, unaccepted** (#1147) |
| `806390ed` | **Food: live homepage banners managed in Admin (PR #1133)** | `admin/`, migration, **`web/app/food/food-app.css`, `web/components/food/*`, `web/lib/food-home-banners.ts`, `web/lib/i18n/en.ts`** | **Consumer web, unaccepted (#1142)** — would ship via `main` |
| `55a290e9` | **Admin Food: featured stores + homepage placements (PR #1135)** | `admin/`, migration, **`web/components/food/*`, `web/lib/food-featured-stores.ts`** | **Consumer web, unaccepted (#1142)** — would ship via `main` |
| `1644b27c` | Admin Food: review moderation (PR #1137) | `admin/`, migration | **Admin, unaccepted** (#1145) |
| `92a09477` | Admin Merchant: open/close + prep (PR #1138) | `admin/`, migration | **Admin, unaccepted** (#1148) |
| `0802d70f`, `fe077f2b`, `44a3feba`, `b7955bbf`, `0ad86382`, `42a8f937` | freeze / consolidated release CI + docs | `.github/`, `tools/`, docs | CI/governance — not shipped |

All 10 acceptance issues #1142–#1151 are **open** (checked 2026-10-18). Six Admin migrations (`20261013*`) are in `main`; whether they are applied to production DB is out of scope here, but the ZOKY release does not depend on them.

Note: GP v1 (`27e9b64d`, #1149 area) is already in production web (`b19687af` contains it) and edge (`food-stripe-checkout`) since 2026-10-12, before the freeze. The proposed release base keeps that unchanged — no new exposure.

## 2. Does deploying from `main` ship unaccepted work?

**Yes.** `wyn-158` deploys the whole `web/` directory of `main`. `git diff b19687af origin/main -- web/` = 6 files, +165 lines, all from PR #1133/#1135 (homepage banners via RPC `food_active_home_banners` + bucket `food-banners`, "ร้านแนะนำ" via RPC `food_active_featured_stores`). They are hidden when the RPC returns nothing, but they are live customer-facing behaviour controlled by unaccepted Admin features (#1142). Per the Founder's exception condition this is a **STOP-and-report** item: do not run `wyn-158` (and do not close any acceptance issue) for this release.

`wyn-158` is also structurally unusable for the exception: it requires `github.ref == main` and all of #1142–#1151 closed.

## 3. Options for a scoped release

| Option | What ships | Pros | Cons | Verdict |
|---|---|---|---|---|
| **A. Release branch from production commit + ZOKY commits, deployed by a dedicated exception workflow** | `b19687af` + ZOKY only | exact "production + ZOKY"; no Admin/#1142 code; `main` untouched for Admin team; auditable separate workflow | two branches to keep in sync until merge-back; one workflow PR needed | **Recommended** |
| B. Revert #1133/#1135 web parts on `main`, then deploy `main` with an exception | `main` minus banner/featured web code | single branch | rewrites Admin team's in-progress work on `main` (must re-apply later); still needs an exception workflow; Admin/web coupling risk | not recommended |
| C. Add an exception input to `wyn-158` | whole `main` | small change | still ships #1133/#1135; weakens the main freeze workflow itself | rejected |
| D. Founder deploys manually with Vercel CLI from a local checkout | whatever is on the laptop | no workflow change | violates "no deploy from local change", no CI gate, poor audit | rejected |

### 3.1 Option A — release branch recipe (verified locally in a throwaway worktree, then deleted)

Base: `b19687afdec361da846a2d9ceb11429547c92a24`. Branch name: `release/zoky-web-20261018`.

Cherry-pick, in order, with `-x` (keeps the source SHA in each message for audit):
`ffd3ac65 bb2f44c9 574f12e8 bdcd0a1a 5e0bec50 738d4818 15fc1e3b 729a3e27 3ea034dd a28de101 b15d2e61 2fa7a4a2` (+ this plan doc's commit and any later ZOKY fixes).

Trial result (2026-10-18, local only, nothing pushed):
- 10 of 12 apply cleanly.
- `ffd3ac65` conflicts in `web/components/food/food-guest-browse.tsx` and `web/components/food/wynos-food-developer-app.tsx`: the only conflicting hunks are the #1133/#1135 banner / "ร้านแนะนำ" JSX blocks (re-labelled "แบนเนอร์ ZOKY" in the ZOKY branch). Resolution: keep the production (HEAD) side, i.e. drop those blocks.
- `15fc1e3b` conflicts in `web/app/food/food-app.css`: resolution = keep HEAD and append only the `/* ZOKY-137 … */ .fx-app .wf-form …:focus` block; drop the `.fx-home-banner*` CSS.
- Resulting tree vs `feat/zoky-web-rebrand` differs **only** by the #1133/#1135 web code, the six `20261013*` Admin migrations/tests, and the freeze script — exactly the unaccepted set. No banner/featured references remain in `web/`. Outside `web/` and `.wyn/` the release differs from production only in: `.github/scripts/{sync,test}-auth-password-policy.sh`, `docs/engineering/WEB_STAGING.md`, `supabase/functions/food-stripe-{checkout,cancel}`, `supabase/functions/wynos-maps-geocode`.
- **Not run on the trial tree**: lint/typecheck/unit/build/Playwright (QA agent owns the worktree; heavy installs avoided). These must pass on the real release branch (step C3) before any approval.

Keep in sync: every later ZOKY fix lands on `feat/zoky-web-rebrand` first and is cherry-picked to the release branch. After phase 2 is stable, `feat/zoky-web-rebrand` is merged into `main` (or already merged at step C2) so the next coordinated release does not regress ZOKY.

### 3.2 Proposed exception workflow (PROPOSAL ONLY — needs Founder approval + CTO review before anyone writes it)

New file on `main` via a workflow-only PR: `.github/workflows/zoky-web-exception-release.yml`. Design goals: scoped to this release, auditable, cannot ship anything else, does **not** touch `wyn-158`, the acceptance issues, or the `production` environment settings.

- Trigger: `workflow_dispatch` only (no `push`). Inputs:
  - `release_sha` (string, required) — must equal the SHA recorded in `.wyn/company/APPROVALS.md` for this phase.
  - `phase` (choice `PHASE1`, `PHASE2`) — drives post-deploy assertions.
  - `confirmation` (choice `CANCEL`, `ZOKY_FREEZE_EXCEPTION_20261018`).
- Job guard: `if: github.ref == 'refs/heads/main' && inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018'`. Dispatched from `main` so the workflow definition that runs is the reviewed one on `main` (a definition taken from a feature branch could rewrite its own guards); the release code is fetched with `actions/checkout` `ref: ${{ inputs.release_sha }}`.
- `environment: production` — same required reviewers; **no change to environment settings**. Concurrency group `wyn-158-production`, `cancel-in-progress: false` (cannot race a coordinated release).
- Fail-closed guards before any deploy:
  1. Expiry: fail if `date -u` is after a fixed date (proposal 2026-11-30) — the exception dies on its own.
  2. `release_sha` is the tip of `origin/release/zoky-web-20261018`.
  3. `git merge-base --is-ancestor b19687afdec361da846a2d9ceb11429547c92a24 <release_sha>`.
  4. `git merge-base --is-ancestor 806390ed <release_sha>` and same for `55a290e9` must both be **false**; `web/lib/food-home-banners.ts` and `web/lib/food-featured-stores.ts` must not exist.
  5. Path allowlist: `git diff --name-only <base>..<release_sha>` ⊆ `web/**`, `supabase/functions/{food-stripe-checkout,food-stripe-cancel,wynos-maps-geocode}/**`, `supabase/config.toml` (only if the verify_jwt line in section 4 is added), `.github/scripts/{sync,test}-auth-password-policy.sh`, `docs/**`, `.wyn/**`. Anything else fails.
  6. Print the commit list `<base>..<release_sha>` and the diffstat to `$GITHUB_STEP_SUMMARY` (audit record attached to the run).
- Then the same steps as `wyn-158` (`npm run check`, `qa:browser` Chromium+WebKit, `vercel deploy --prod` with the same secret wiring, the same `wynos.online` route / maps / push-config verification), plus ZOKY assertions:
  - `https://zoky.wynos.online/` 200, `<title>` contains `ZOKY`, canonical `https://zoky.wynos.online`.
  - `https://wynos.online/food?promo=X` → 307 `https://zoky.wynos.online/?promo=X`.
  - PHASE1: `https://food.wynos.online/` 200 (no redirect), `/sw.js` does not contain `ZOKY-136`.
  - PHASE2: `https://food.wynos.online/s/abc?x=1` → 307 `https://zoky.wynos.online/s/abc?x=1`; `/sw.js` contains the cleanup worker marker.
- Freeze guard: extend `tools/check_wynos_release_freeze.py` to assert this file keeps `workflow_dispatch` only, `environment: production`, the `refs/heads/main` guard, the pinned base SHA, and the expiry check — so CI fails if anyone loosens it. `wyn-158`/`deploy-web.yml`/acceptance list remain asserted unchanged.
- Audit trail: DECISIONS + APPROVALS entries (exception scope, release SHA per phase, approver, run URL), deployment logs in `.wyn/logs/deployments/`, run summary. After phase 2 is stable: Founder-approved PR deletes the workflow (or it expires).

Unknown (API blocked from this sandbox): the `production` environment's reviewer list and deployment-branch policy. Dispatching from `main` satisfies a "main only" branch policy, so no environment change is needed either way. Founder should still confirm in Settings → Environments → `production` that required reviewers are set (F1).

## 4. Edge-function deploy path (CTO RB2)

- `food-stripe-checkout`, `food-stripe-cancel`: already options in `deploy-edge-functions.yml`. Dispatch from `main` after ZOKY merge (C2) — main's versions equal "deployed + ZOKY" (section 1.2) — or from the release branch (identical function content, verified). Both are `verify_jwt = true` in `supabase/config.toml` (unchanged).
- `wynos-maps-geocode`: **not an option** in the workflow. Proposal (same workflow-only PR as 3.2): add `- wynos-maps-geocode` to the `function` choice list. Alternative: Founder deploys with Supabase CLI and records it — weaker audit, not recommended.
- **Hidden risk (new finding)**: `wynos-maps-geocode` has **no `[functions.wynos-maps-geocode]` entry in `supabase/config.toml`**, so `supabase functions deploy` defaults to `verify_jwt = true`. The function authenticates callers itself via the `apikey` header (`LEGACY_PUBLIC_API_KEY` / `SUPABASE_PUBLISHABLE_KEYS`, line ~335) and the web calls it with `client.functions.invoke(...)` (`web/lib/food-customer.ts:1232`) — guests send the publishable key, which is not a JWT. If production currently runs it with JWT verification off, a CI deploy would switch it on and break guest geocoding (maps/food address search fallback) silently. Required before deploying: Founder reads Supabase Dashboard → Edge Functions → `wynos-maps-geocode` → "Verify JWT" (read-only). If it is off, AI Coding adds `[functions.wynos-maps-geocode]\nverify_jwt = false` with a comment (code change → QA + CTO), to `feat/zoky-web-rebrand` and the release branch, before dispatch.
- M3 (pre-existing): `deploy-edge-functions.yml` has no `environment: production` gate. Treat each dispatch as a Founder-gated production change (record approval). Optional hardening proposal for the same workflow PR: add `environment: production` (strengthens, does not weaken; repo secret `SUPABASE_ACCESS_TOKEN` stays readable).
- Order: edge functions **before** web phase 1 — they are backward compatible (food origin still accepted, return URL stays on food when the request came from food).
- Smoke after each function (developer account, live mode, on current `food.wynos.online`): card checkout opens and returns to food; cancel a card order; address search fallback works signed-out and signed-in. Watch function logs for 401/403 (`live_stripe_origin_required`, JWT errors).
- Rollback: redeploy the previous version — for `food-stripe-checkout` dispatch from `27e9b64d` (identical to prior deploy); for `food-stripe-cancel`/`wynos-maps-geocode` dispatch from `b19687af` (function source unchanged since 2026-10-10; geocode rollback still needs the workflow option and the same verify_jwt setting).

## 5. Merge-to-main side effect: Supabase Auth allowlist (CTO M2)

- `web-beta1-auth-password-policy.yml` job `apply` runs on push to `main` touching `.github/scripts/sync-auth-password-policy.sh` (the ZOKY merge does) and after every successful `WYN-158 Production Deploy` on `main`; also on `workflow_dispatch` from **any** branch. It has no `environment:` protection (pre-existing).
- Effect: PATCH `uri_allow_list` adding exactly `https://zoky.wynos.online/food/auth/callback`, `https://zoky.wynos.online/auth/callback?next=%2Ffood`, `https://zoky.wynos.online/reset-password?returnTo=%2Ffood%2Flogin`; keeps every existing entry (additive, idempotent); also enforces `password_min_length >= 12` (pre-existing behaviour).
- The exception workflow does not trigger `apply` (its `workflow_run` listens only to `WYN-158 Production Deploy`), so the allowlist change happens at merge (C2). Merge only after `zoky.wynos.online` is attached and verified in Vercel (no window where an unclaimed host is allowlisted).
- Verify after merge: `apply` job green and commit status `wynos/auth-policy` = success; Founder confirms in Supabase → Auth → URL Configuration that 3 zoky + all food entries exist, Site URL still `https://wynos.online`.
- Rollback: remove the 3 zoky URLs in the dashboard (not needed for web rollback; harmless to keep).

## 6. Ordered runbook

Legend: **F** = Founder (dashboard/decision), **A** = approval record required (DECISIONS/APPROVALS), **C** = agent/CI, **S** = smoke. Nothing below has been executed.

### Phase 0 — confirm facts (read-only)
1. **F1** Vercel → project `web`: current Production deployment = `web-5djnkfh16` (`b19687af`); note it as rollback target. Project `wynteam-gesb`: no custom domains. GitHub → Settings → Environments → `production`: required reviewers present.
2. **F2** Supabase → Edge Functions → `wynos-maps-geocode`: read "Verify JWT" state; send to DevOps.
3. **F3** Google Cloud: does the OAuth client list Authorized JavaScript origins containing `https://food.wynos.online`? Does the Firebase browser API key restrict HTTP referrers? (Answers only; changes in step 9.)

### Phase 1 — approvals and preparation
4. **A1** Founder chooses Option A (release branch from production + exception workflow).
5. **A2** Founder approves the workflow-only PR (3.2 exception workflow, `wynos-maps-geocode` option, optional `environment: production` for edge deploys, freeze-check update). **C** DevOps implements on a branch from `main` → CI (incl. freeze guard) → CTO review → merge. Merging changes no web code and deploys nothing.
6. **C** If F2 says JWT verification is off: AI Coding adds the `verify_jwt = false` entry → QA → CTO.
7. **C** AI Coding builds `release/zoky-web-20261018` per 3.1 (pushing this branch needs explicit Founder approval — request it together with A1). QA runs on it: `npm ci`, lint, typecheck, unit, build, freeze guard, Deno check/test for the 3 functions, local host-header smoke both flag states, Playwright. Staging: dispatch `web-next-phase5-preview.yml` on the release ref (Vercel preview, never moves the production alias) and check brand/UI on phone. Record the release SHA.

### Phase 2 — domain, merge, edge
8. **F** Vercel → project `web` → Settings → Domains → add `zoky.wynos.online`; keep `food.wynos.online`. DNS: `*.wynos.online` already points to Vercel (APPROVALS 2026-10-11, `admin-attach-domain.yml` header) and `zoky.wynos.online` already resolves to Vercel IPs (`64.29.17.65`, `216.198.79.1`, checked 2026-10-18) — expect no DNS change; if Vercel shows a CNAME/TXT requirement, add only that record and do not touch `food`/`merchant`/`maps`/`admin`/`tiles`. Wait for Valid Configuration + SSL. Until phase 1, zoky serves the current build (Social at `/`) — acceptable for a short window.
9. **F** Google OAuth JavaScript origins / Firebase key referrers: add `https://zoky.wynos.online` / `zoky.wynos.online/*` only where food is already listed (from F3). Stripe: nothing to register.
10. **A3** Founder approves push + PR + merge of `feat/zoky-web-rebrand` into `main` knowing merge = Supabase Auth allowlist change. **C** merge → verify `apply` + `wynos/auth-policy` (section 5). **F** confirm in Supabase Auth URL Configuration.
11. **A4** Founder approves edge deploys. **C** dispatch `deploy-edge-functions.yml` (ref `main`) three times: `food-stripe-checkout`, `food-stripe-cancel`, `wynos-maps-geocode`. **S** section 4 smoke on `food.wynos.online`. Deployment log in `.wyn/logs/deployments/`.

### Phase 3 — web phase 1 (zoky live, food unchanged)
12. **F** Vercel → project `web` → Environment Variables (Production): confirm `ZOKY_LEGACY_FOOD_REDIRECT` is absent (or not `1`/`true`). AI does not set it.
13. Check Vercel quota headroom (avoid pushes that create previews right before; 10-13 release failed on the 100/day limit).
14. **A5** Founder records approval with the release SHA. **C** dispatch `zoky-web-exception-release.yml` from `main`: `release_sha=<SHA>`, `phase=PHASE1`, `confirmation=ZOKY_FREEZE_EXCEPTION_20261018`. **F** approve the `production` environment review in GitHub.
15. **S** (developer accounts) `zoky.wynos.online`: title/theme/manifest/icons ZOKY; Google + email login; signup + email confirmation; password reset lands on zoky (if it falls back to Site URL, Founder adds `https://zoky.wynos.online/reset-password**`); order + Stripe live success/cancel returns to zoky; cancel paid order; address search (geocode) signed-out and signed-in; `/s/<code>`, `/?store=`, `/?order=`, `/?promo=`; LINE link preview; Push on Android/iOS PWA; PWA install. `food.wynos.online`: `/` 200 Food (ZOKY brand), `/login` → `/food/login` on food, `/sw.js` real worker, login + card payment return to food. `wynos.online/food?promo=X` → zoky. Regression: `wynos.online` Social routes, `/maps` (order button → zoky), `merchant.wynos.online` (orders; share URL = zoky), `admin.wynos.online` opens. Confirm **no** banner/"ร้านแนะนำ" sections from #1133/#1135 appear.
16. **C** Deployment record (`.wyn/logs/deployments/2026-10-xx-zoky-web-phase1.md`): SHA, run URL, Vercel deployment URL, approvals, smoke results, rollback target. Monitor: Vercel 4xx/5xx on zoky/food, edge 403 `live_stripe_origin_required`, Stripe success rate.

### Phase 4 — web phase 2 (redirect food → zoky)
17. **A6** Founder approves after phase 1 smoke + monitoring. **F** set `ZOKY_LEGACY_FOOD_REDIRECT=1` in Vercel Production env (server-only, no `NEXT_PUBLIC_`).
18. **C** dispatch the exception workflow again with the **same** `release_sha`, `phase=PHASE2`; **F** approve environment review (env vars bind per deployment → redeploy required).
19. **S** `food.wynos.online/*`, `/s/<code>`, `/food/auth/callback?code=…` → 307 zoky with path+query; `/_next/*`, `/api/*` not redirected; `food.wynos.online/sw.js` = cleanup worker; zoky unchanged. Send AC9 communication (re-login, reinstall PWA, re-enable notifications). Monitor 1–2 weeks, then Founder decides 307 → 308 (Q2).
20. **C** Deployment record for phase 2; after stability, Founder-approved PR removes the exception workflow; DECISIONS entry closing the exception. Acceptance issues #1142–#1151 stay open and untouched throughout.

## 7. Rollback

| Stage | Fast rollback | Notes |
|---|---|---|
| Auth allowlist (C2) | remove 3 zoky URLs in Supabase dashboard | normally keep; additive |
| Edge functions | redeploy previous source (section 4) | keep both origins accepted during the whole transition |
| Phase 1 | Vercel Instant Rollback to `web-5djnkfh16` (`b19687af`) **and** Vercel domain redirect `zoky.wynos.online` → `food.wynos.online` (307) immediately (CTO M4; the old build does not know host zoky and would show Social) | never remove either domain; no DB change; nothing irreversible in phase 1 |
| Phase 2 | Vercel Instant Rollback to the phase-1 deployment (no build), or unset the env var and redeploy phase 1 via the exception workflow | irreversible: push subscriptions/caches already removed by the cleanup worker on the food origin |
| Permanent | revert on the release branch / `main` and redeploy through the gate | Founder decides per GIT_WORKFLOW "Recovery" |

## 8. Not verified / residual risks

- Current Vercel Production state beyond GitHub evidence (manual promote/rollback) — needs F1.
- `production` environment settings and branch policy — API blocked; needs F1.
- Live JWT setting of `wynos-maps-geocode`; deployed version of `food-stripe-cancel` and `wynos-maps-geocode` — needs F2 / Supabase dashboard.
- Release-branch trial tree was not built or tested; QA must run the full suite on the real branch.
- DNS evidence is a sandbox resolver lookup plus repo docs, not a registrar check.
- Vercel daily deployment quota is shared with stray `wynteam-*` projects; a release can fail mid-way (no partial production change in that failure mode — the 10-13 attempt created no deployment).
- `web-beta1-auth-password-policy.yml` `apply` has no environment gate and can be dispatched from any branch (pre-existing, CTO M2) — recommend separate hardening.
- No claim of zero regression; evidence is the commit/diff analysis above and the QA/CTO results recorded in the handoff and review.
