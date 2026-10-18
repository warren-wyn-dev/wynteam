# Deploy secrets → `production` environment migration (C1)

- Author: WYN Deploy & DevOps (AI) | Date: 2026-10-18 | Branch: `ci/deploy-secrets-environment` (from `origin/main` `42a8f937`), **unmerged**
- Decision: Founder approved C1 on 2026-10-18 (`DECISIONS.md` on `docs/zoky-foundation`, "ZOKY release — ย้ายกุญแจ deploy เข้า production environment"). Moving the secrets and changing GitHub/Vercel/Supabase settings is done by the Founder. Agents prepare the workflow changes only.
- Mode: read-only audit. No GitHub settings or secrets read or changed, no secret values seen, no dispatch, deploy or merge. The GitHub settings API (environments, secret names) is blocked from this session, so the current environment configuration is **not verified**. Run history was read through the REST API.

## สรุปสำหรับ Founder (ภาษาไทย)

**ปัญหา:** ตอนนี้กุญแจ deploy 2 ดอก (`VERCEL_TOKEN` กับ `SUPABASE_ACCESS_TOKEN`) วางไว้ระดับ repository ทำให้ workflow ไหนก็หยิบไปใช้ได้ทันที รวมถึง workflow เวอร์ชันเก่าบน branch เก่า ๆ ด้วย จึงแก้ฐานข้อมูลจริงหรือขึ้น production ได้โดยไม่ต้องรอ Founder อนุมัติ

**วิธีแก้:** ย้ายกุญแจ 2 ดอกนี้เข้าไปเก็บใน environment `production` ตั้งให้ Founder เป็นคนอนุมัติ และให้ใช้ได้จาก branch `main` เท่านั้น

**สิ่งที่ทีมเตรียมไว้แล้ว (ยังไม่ merge):**
- เพิ่ม `environment: production` ให้ทุก workflow ที่ใช้กุญแจ 2 ดอกนี้ (71 ไฟล์) ระบบที่ยังใช้อยู่จึงไม่พังหลังย้ายกุญแจ
- เพิ่มตัวตรวจอัตโนมัติใน CI ถ้ามีใครเพิ่ม workflow ใหม่ที่ใช้กุญแจโดยไม่ผ่าน environment, CI จะไม่ผ่าน
- ปิดการรันอัตโนมัติของ workflow นำเข้าสถานที่ (Overture) ซึ่งเดิมเขียนข้อมูลลงฐานข้อมูลจริงทันทีที่มีคนแก้ไฟล์

**สิ่งที่ Founder ต้องรู้:**
1. หลังเปลี่ยน งานที่เคยรันเองจะ "รอ Founder กดอนุมัติ" ก่อน เช่น หลัง deploy wyn-158 แต่ละครั้งจะมีงาน Auth อีก 3 งานรอให้กดอนุมัติ
2. **กระทบ ZOKY:** โค้ด Edge Function 3 ตัวบน branch ZOKY ต่างจาก `main` เมื่อจำกัดให้ใช้ได้เฉพาะ `main` จะ deploy Edge Function จาก branch ZOKY ไม่ได้ ทีมจึงเพิ่มขั้น EDGE เข้าไปใน workflow ข้อยกเว้นของ ZOKY แล้ว (CTO อนุมัติแบบมีเงื่อนไข) ดูหัวข้อ "ZOKY impact"
   - **ทำ ZOKY staging (preview) ให้เสร็จก่อนส่วน E** เพราะหลังลบกุญแจเก่า จะทำ preview จาก branch ZOKY ไม่ได้อีก
3. มี workflow เก่าที่ใช้ครั้งเดียวแล้วจบอีก 50 ไฟล์ ซึ่งเสนอให้ลบทิ้ง (ยังไม่ได้ลบ ต้องรอ Founder อนุมัติ) ระหว่างนี้ทุกไฟล์ถูกล็อกด้วยการอนุมัติแล้ว จึงไม่มีความเสี่ยงเพิ่ม

### ขั้นตอนบน iPad สำหรับ Founder (ทำหลังจาก PR นี้ merge แล้วเท่านั้น)

**ส่วน A — ตั้งค่า environment `production` (GitHub, Safari)**
1. เปิด `github.com/warren-wyn-dev/wynteam` แล้วแตะ **Settings** (ถ้าไม่เห็น ให้แตะ "…" หรือเลื่อนแถบเมนูไปทางขวา)
2. เมนูซ้าย แตะ **Environments** แล้วแตะ **production**
3. หัวข้อ **Deployment protection rules**: ติ๊ก **Required reviewers** แล้วใส่ชื่อบัญชีของ Founder ให้ **ปิด** "Prevent self-review" ไว้ (ถ้าเปิด Founder จะอนุมัติงานที่ตัวเองกดรันไม่ได้) แล้วแตะ **Save protection rules**
4. ถ้ามีช่อง **Allow administrators to bypass configured protection rules** ให้ **เอาติ๊กออก**
5. หัวข้อ **Deployment branches and tags**: เลือก **Selected branches and tags** แตะ **Add deployment branch or tag rule** พิมพ์ `main` แล้วแตะ **Add rule** (ต้องมีแค่ `main` อันเดียว)

**ส่วน B — สร้างกุญแจใหม่ (อย่าใช้กุญแจเดิม)**
6. **Vercel:** เข้า `vercel.com` แตะรูปโปรไฟล์ แล้วแตะ **Account Settings** → **Tokens**
7. ตั้งชื่อ `github-production-2026-10` เลือก Scope เป็นทีม **warren14** ตั้งวันหมดอายุ (แนะนำ 180 วัน และใส่เตือนในปฏิทินด้วย) แล้วแตะ **Create** จากนั้น **คัดลอกกุญแจไว้ชั่วคราว** (หน้าเว็บจะแสดงให้เห็นแค่ครั้งเดียว)
8. **Supabase:** เข้า `supabase.com/dashboard/account/tokens` แตะ **Generate new token** ตั้งชื่อ `github-production-2026-10` (ถ้ามีให้เลือกวันหมดอายุ ให้เลือก) แตะ **Generate** แล้วคัดลอกกุญแจ (ขึ้นต้นด้วย `sbp_`)

**ส่วน C — ใส่กุญแจใหม่ลงใน environment**
9. กลับไปที่ GitHub → **Settings** → **Environments** → **production** หัวข้อ **Environment secrets** แตะ **Add environment secret**
10. Name: `VERCEL_TOKEN` (ตัวพิมพ์ใหญ่ตามนี้ทุกตัว) วางกุญแจ Vercel ใหม่ แล้วแตะ **Add secret**
11. แตะ **Add environment secret** อีกครั้ง Name: `SUPABASE_ACCESS_TOKEN` วางกุญแจ Supabase ใหม่ แล้วแตะ **Add secret**
12. ลบกุญแจที่คัดลอกไว้ชั่วคราวออกจากคลิปบอร์ด/โน้ตทันที (เช่น คัดลอกข้อความอื่นทับ)

**ส่วน D — ทดสอบว่ากุญแจใหม่ใช้ได้ (ปลอดภัย อ่านข้อมูลอย่างเดียว)**
13. GitHub → แตะ **Actions** เลือก workflow **admin-supabase-status-check** แตะ **Run workflow** (branch `main`) แล้วแตะ **Run workflow**
14. เปิดงานที่เพิ่งเริ่ม จะเห็นปุ่ม **Review deployments** ให้แตะ ติ๊ก **production** แล้วแตะ **Approve and deploy** รอจนขึ้นเครื่องหมายถูกสีเขียว (ถ้ากุญแจผิด งานจะขึ้นสีแดง; ถ้าแตะเปิด log จะเห็นคำว่า `ACTIVE_HEALTHY`)
15. ทำแบบเดียวกันกับ workflow **admin-vercel-logs-check** ถ้าทั้ง 2 งานเป็นสีเขียว แปลว่ากุญแจใหม่ใช้ได้ (ถ้าเป็นสีแดง ให้หยุดตรงนี้แล้วส่งลิงก์ให้ทีม DevOps)

**ส่วน E — ลบกุญแจเก่าและยกเลิกกุญแจเก่า** (เริ่มส่วนนี้ได้เมื่อ ZOKY staging preview เสร็จแล้วเท่านั้น)
16. GitHub → **Settings** → **Secrets and variables** → **Actions** แท็บ **Secrets** หัวข้อ **Repository secrets**
17. แตะไอคอนถังขยะที่ `VERCEL_TOKEN` แล้วยืนยัน จากนั้นทำแบบเดียวกันที่ `SUPABASE_ACCESS_TOKEN` (**ห้ามลบตัวอื่น** เช่น `SUPABASE_URL`, `VERCEL_ORG_ID`, `FIREBASE_…` ให้เก็บไว้ตามเดิม)
18. Vercel → **Account Settings** → **Tokens** **อ่านชื่อกุญแจแต่ละอันก่อน** แล้วลบ (Delete) อันเดิมที่ GitHub ใช้ **ยกเว้น** `github-production-2026-10` ถ้าเจอกุญแจที่ไม่แน่ใจว่าเครื่องมืออื่นใช้อยู่หรือไม่ (เช่น CLI บนคอมพิวเตอร์) ให้ถามทีมก่อน เพราะลบแล้วเครื่องมือนั้นจะใช้ไม่ได้ทันที
19. Supabase → **Access Tokens** **อ่านชื่อก่อนเช่นกัน** แล้วแตะ **Revoke** ที่อันเดิม **ยกเว้น** `github-production-2026-10`
20. **กุญแจ Android (`ANDROID_SECRETS_TOKEN`)** กุญแจนี้เขียนทับ secrets อื่นของ repo ได้ และ workflow ที่ใช้มันไม่มีปุ่มอนุมัติ
    - ถ้าเคยสร้าง Android upload key ไปแล้ว (ในหน้า Repository secrets มี `ANDROID_UPLOAD_KEYSTORE_BASE64`): ลบ secret `ANDROID_SECRETS_TOKEN` (ไอคอนถังขยะ) แล้วไปที่ GitHub → รูปโปรไฟล์ → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** แล้วแตะ **Delete** ที่ token นั้น
    - ถ้ายังไม่เคยสร้าง: บอกทีมก่อน ทีมจะเพิ่มปุ่มอนุมัติให้ workflow นั้นก่อนใช้ครั้งเดียว แล้วจึงลบตามข้อบน
21. ทำข้อ 13–15 ซ้ำอีกรอบ ถ้ายังเป็นสีเขียวทั้งคู่ถือว่าเสร็จ แล้วบอกทีมว่า "C1 เสร็จแล้ว" เพื่อบันทึกลง DECISIONS/APPROVALS

**ถ้ามีอะไรพัง:** ห้ามนำกุญแจเก่ากลับมาใช้ ให้สร้างกุญแจใหม่ตามข้อ 6–11 แล้วแจ้งทีม DevOps

---

## Technical detail (English)

### What moves and what stays

| Secret | Nature | Action |
|---|---|---|
| `VERCEL_TOKEN` | Account/team credential. It can deploy, promote and alias **any** project in team `warren14`. A Vercel token cannot be limited to preview-only. | **Move** to the `production` environment as a **new** token, then delete the repo secret and revoke the old token |
| `SUPABASE_ACCESS_TOKEN` | Personal access token with full Management API access: SQL as postgres, config, functions, restarts | **Move** (same steps) |
| `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` | Identifiers. Useless without the token | Stay repo-level |
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | Shipped to every browser as `NEXT_PUBLIC_*`. Access is enforced by RLS | Stay repo-level (CI, Android and `chat-pgrst-cache-check` read them without an environment) |
| `FIREBASE_*` (web, Android) | Public client config, also shipped in the bundle. VAPID is the public key | Stay repo-level |
| `ANDROID_*`, `ANDROID_SECRETS_TOKEN` | Outside C1 scope. `android-release` already uses environment `android-release`. **`ANDROID_SECRETS_TOKEN` (used by `android-upload-key.yml`, no environment) can write repository secrets, so it is an integrity risk for the values the production deploys read (CTO S2, HIGH).** | No workflow change. Handled in Part E step 20: if the upload key exists, delete the secret and the PAT; otherwise gate the job with an environment before its single run, then delete |

The non-sensitive values stay as repository *secrets*, not variables. Converting them would touch about 77 references for no security gain, and secrets keep log masking. They can become `vars.*` later if wanted.

GitHub behaviour this plan relies on:
- An environment secret overrides a same-name repository secret for jobs that declare that environment. So step (b) switches every gated job to the new token immediately, and step (c) only removes the fallback.
- A job without `environment: production` sees an empty value once the repo secret is deleted. That includes old workflow versions on old branches and tags (C1), and they fail closed.
- The `main` deployment-branch rule stops a workflow dispatched on any other ref from entering the environment.

### Audit of origin/main workflows that read the credentials (77 of 96 workflows)

Data sources: the workflow source on `origin/main` `42a8f937`, plus `gh run list` and the run-jobs REST API. "Applied" means the apply job itself concluded `success`. A run whose jobs were all skipped was not counted. "SB_TOKEN" = `SUPABASE_ACCESS_TOKEN`.

Before this change, only the 5 production deploy workflows had `environment: production`. **Every DB apply, Management-API diagnostic, restart, edge deploy and Vercel alias job ran without approval.** Four of them run automatically:
- `web-beta1-auth-password-policy` (push + `workflow_run`)
- `web-beta1-email-readiness` (push + `workflow_run`)
- `web-beta1-safe-recovery-email` (`workflow_run`)
- `wynos-maps-import-overture-places` (push with `dry_run=false` forced)

That is the gap noted by the CTO, and this PR closes it by gating every one of these jobs.

| Workflow | Trigger | Credentials | env before | What it does | Proposal |
|---|---|---|---|---|---|
| `admin-apply-inactive-reminders` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `admin-apply-merchant-finance` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `admin-attach-domain` | dispatch | VERCEL_TOKEN | - | Vercel domain attach | KEEP gated (needed for zoky.wynos.online) |
| `admin-supabase-full-restart` | dispatch | SB_TOKEN | - | Ops: restart Supabase project | KEEP gated (ops) |
| `admin-supabase-status-check` | dispatch | SB_TOKEN | - | Diagnostic (Mgmt API) | KEEP gated (ops; post-migration smoke) |
| `admin-vercel-logs-check` | dispatch | VERCEL_TOKEN | - | Diagnostic (Vercel logs) | KEEP gated (ops; post-migration smoke) |
| `chat-enable-conversations-realtime` | dispatch | SB_TOKEN | - | One-off DB change (alter publication) | RETIRE (one-off, ran 2026-09-04) |
| `chat-fk-detail-check` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `chat-postgrest-restart` | dispatch | SB_TOKEN | - | Ops: PostgREST reload/restart | KEEP gated (ops) |
| `chat-realtime-check` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `chat-recent-logs` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `chat-recent-messages-check` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `chat-unread-badge-diagnostic` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `deploy-admin` | dispatch | VERCEL_TOKEN | production | Prod admin deploy (freeze-guarded) | KEEP |
| `deploy-edge-functions` | dispatch | SB_TOKEN | - | Prod edge function deploy | KEEP; gated (mirrors ZOKY branch a62c1018) |
| `deploy-web` | dispatch | VERCEL_TOKEN | production | Prod web deploy (legacy, freeze-guarded) | KEEP |
| `diag-p0-followup-check` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `diag-wyn116-schema-check` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `food-apply-merchant-sales-report` | dispatch | SB_TOKEN | - | Prod DB migration apply (never run) | KEEP gated until Database Engineer confirms status |
| `food-apply-order-push` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-share-code` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-share-preview` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-stripe-payment-core` | dispatch | SB_TOKEN | - | Prod DB migration apply (never run) | KEEP gated until Database Engineer confirms status |
| `food-apply-wyn193-wyn194` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn196` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn197` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn203` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn206` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn207` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn210` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn211` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn213` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn214` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `food-apply-wyn216` | dispatch | SB_TOKEN | - | Prod DB migration apply (never run) | KEEP gated until Database Engineer confirms status |
| `food-merchant-apply-launch-hardening` | dispatch | SB_TOKEN | - | Prod DB migration apply (never run) | KEEP gated until Database Engineer confirms status |
| `food-payment-integrity-readonly-check` | dispatch | SB_TOKEN | - | Diagnostic (payments, read-only) | KEEP gated (ops) |
| `maps-apply-place-photos` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `maps-apply-saved-places` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `merchant-apply-gp-v1` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `merchant-apply-order-reminders` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `push-apply-wyn215` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `setup-database-webhook` | dispatch | SB_TOKEN | - | Ops: DB webhook setup (action input) | KEEP gated (ops) |
| `storage-upload-validator` | dispatch | SB_TOKEN | - | Ops: storage/edge config (action input) | KEEP gated (ops) |
| `web-beta1-apply-qa-hardening` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `web-beta1-auth-password-policy` | pull_request[]paths=3 push[main]paths=3 workflow_run dispatch | SB_TOKEN | - | Prod Auth config apply (auto after wyn-158 / push) | KEEP gated; now waits for approval |
| `web-beta1-email-readiness` | pull_request[]paths=3 push[main]paths=3 dispatch workflow_run | SB_TOKEN | - | Prod Auth email audit (read-only, full token) | KEEP gated; now waits for approval |
| `web-beta1-safe-recovery-email` | pull_request[]paths=6 dispatch workflow_run | SB_TOKEN | - | Prod Auth email template apply (auto after wyn-158) | KEEP gated; now waits for approval |
| `web-next-phase5-preview` | pull_request[main]paths=2 dispatch | VERCEL_TOKEN | - | Vercel preview deploy (prod-capable token) | KEEP gated; PR path dead (PR 996/1008 merged) - retire later |
| `web-next-phase5-production` | dispatch | VERCEL_TOKEN | production | Prod cutover (freeze-guarded) | KEEP |
| `wyn-158-production-deploy` | dispatch | VERCEL_TOKEN | production | Prod web deploy (Vercel) | KEEP (unchanged; Founder: wyn-158 stays as is) |
| `wyn-posting-activation-promote` | dispatch | VERCEL_TOKEN | - | Prod Vercel alias to hard-coded Sept deployment | RETIRE (re-run would roll production back) |
| `wyn113-apply-invite-only-access-gate-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn115-apply-club-poll-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn116-apply-club-reengagement-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn117-apply-club-insights-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn118-apply-club-events-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn120-delete-drop-failure-diagnostic` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `wyn122-apply-chat-lockdown-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn122-toggle-chat-lockdown` | dispatch | SB_TOKEN | - | Ops: chat kill switch | KEEP gated (ops) |
| `wyn124-apply-club-invite-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn125-apply-developer-accounts-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn125-manage-developer-accounts` | dispatch | SB_TOKEN | - | Ops: developer account admin | KEEP gated (ops) |
| `wyn127-apply-club-channels-schema` | dispatch | SB_TOKEN | - | Prod DB migration apply (never run) | KEEP gated until Database Engineer confirms status |
| `wyn128-apply-club-channel-messages-schema` | dispatch | SB_TOKEN | - | Prod DB migration apply (never run) | KEEP gated until Database Engineer confirms status |
| `wyn129-apply-club-member-badges-schema` | dispatch | SB_TOKEN | - | Prod DB migration apply (never run) | KEEP gated until Database Engineer confirms status |
| `wyn133-apply-club-channel-categories-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn134-apply-dm-new-message-notification-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn136-apply-club-invite-link-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn138-apply-dm-message-edit-pin-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn139-apply-dm-presence-schema` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn187-cleanup-legacy-social-links` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn219-apply-admin-permissions-foundation` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn219-apply-step2-maps` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn219-apply-step2-system` | dispatch | SB_TOKEN | - | One-off prod DB migration apply | RETIRE (applied: job succeeded) |
| `wyn219-dump-admin-check-definitions` | dispatch | SB_TOKEN | - | One-off diagnostic (full-power token) | RETIRE (dated incident diagnostic) |
| `wynos-admin-consolidated-release` | dispatch | VERCEL_TOKEN | production | Prod admin stage+promote | KEEP |
| `wynos-maps-import-overture-places` | push[main]paths=1 dispatch | SB_TOKEN | - | Prod DB write (Places import) | KEEP gated; push trigger removed (forced dry_run=false) |

Workflows with no production credential: `ci.yml`, `android*.yml`, `web-next-ci`, `web-phase*`, `web-beta1-*` QA, `merchant-browser-qa`, `food-first-order-pg-qa`, `chat-pgrst-cache-check`, `wynos-visual-gate`, and others. These are unaffected. Other leftovers that hold no credential but should be retired later:
- `dispatch-deploy-web-once-20260912` (a no-op archive)
- `apply-all-non-profile-ui-once` (push, `contents: write`)
- `wyn141-founder-ui-one-shot` (push on an old branch, `contents: write`)

### Workflow changes prepared on `ci/deploy-secrets-environment`

1. Commit `f2156481`:
   - `environment: production` on every job that reads `SUPABASE_ACCESS_TOKEN` or `VERCEL_TOKEN`: 71 workflows, one job each. The 5 production deploy workflows were already gated, and `wyn-158` is unchanged.
   - `deploy-edge-functions.yml` is a byte-identical copy of `ci/zoky-web-exception-release` (`a62c1018` + `e73566b8`), so the two branches merge in either order.
   - `wynos-maps-import-overture-places.yml`: the push trigger and the forced `dry_run=false` are removed. That trigger would also have fired a production write when this PR merged.
   - New `tools/check_production_secret_scoping.py` and `tools/test_check_production_secret_scoping.py` (11 ungated variants rejected), wired into the `ci.yml` `schema` job. They fail any job that reads these credentials without `environment: production` (inline or `name:` form), and any exposure outside a recognised job. Job keys are detected at any indentation, quoted, or followed by a comment (CTO S4).
   - `admin-supabase-status-check.yml`: `curl --fail-with-body`, so a bad token fails the Part D smoke instead of showing green (CTO S1).
2. **Not done: retiring the 49 RETIRE rows above plus `dispatch-deploy-web-once-20260912`.** The bulk deletion was refused by this session's permission guard, so it stays a proposal for an explicit Founder go-ahead. It can be a follow-up commit on this branch (`git rm` the 50 files). Deleting is reversible with `git revert`. The SQL and rollback files stay in `supabase/`. The only references are historical `.wyn/tasks/*` notes. Until then, every one of them is gated and harmless.

Validation run: `yaml.safe_load` on all workflows, and `bash -n` on every `run:` block of the changed workflows. The checks `check_production_secret_scoping.py`, `test_check_production_secret_scoping.py` and `check_wynos_release_freeze.py` all PASS. Not run: actionlint, and the workflows themselves (no dispatch).

### Minimal safe migration order

| Step | Who | Action | Breaks? |
|---|---|---|---|
| 0 | Founder (verify) | The `production` environment exists and is used by 5 workflows today. The repo is public and user-owned (CTO review), so required reviewers and branch policies are available. | - |
| a | CTO review, QA, Founder merge | Merge `ci/deploy-secrets-environment`. Repo secrets are still in place, so every workflow keeps working and only gains an approval step. On merge, `web-beta1-auth-password-policy` and `web-beta1-email-readiness` start (their push paths include their own file) and wait for review. Approving them is safe because both are idempotent and already ran on 2026-10-13. Rejecting is also fine. | No |
| a' | (optional, separate commit) | Retire the 50 one-offs after Founder approval | No |
| b | Founder (Parts A–C) | Set the `production` reviewers to the Founder, without self-review prevention and without admin bypass. Set deployment branches to `main` only. Create **new** Vercel and Supabase tokens and add them as environment secrets `VERCEL_TOKEN` and `SUPABASE_ACCESS_TOKEN`. | No: gated jobs now use the new tokens |
| b' | Founder (Part D) | Smoke test: dispatch `admin-supabase-status-check` and `admin-vercel-logs-check` on `main`, then approve. Both are read-only. | - |
| b'' | Team + Founder | **Finish the ZOKY staging preview** (release plan step 7, `web-next-phase5-preview` on the release ref) before (c). After (c) that ungated release-branch copy gets no `VERCEL_TOKEN`, and `main`'s gated copy cannot preview another ref (CTO S3). | - |
| c | Founder (Part E) | Delete the repo secrets `VERCEL_TOKEN` and `SUPABASE_ACCESS_TOKEN`. Check token names, then revoke the old tokens in Vercel and Supabase. Handle `ANDROID_SECRETS_TOKEN` (step 20). Repeat the smoke test. | Only ungated paths (old refs), by design |
| d | DevOps | Record in `DECISIONS`/`APPROVALS` and in `.wyn/logs/deployments/`. Update the CTO review C1 status. | - |

Step (c) must come after (b'). Revoking is required, not optional: the old tokens may exist outside GitHub (laptops, other repos, CI logs from before masking).

### Operational consequences

- Every gated run pauses at "Review deployments" until the Founder approves, for up to 30 days. After each `wyn-158` production deploy, 3 follow-up runs wait for approval: auth policy, email readiness and recovery email.
- `deploy-edge-functions`, `admin-attach-domain` and the ops tools can only run from `main` once the branch rule is set.
- `web-next-phase5-preview`: its PR trigger is dead (PRs 996 and 1008 are merged), so it is effectively dispatch-only and needs Founder approval. Previews should come from the Vercel Git integration if that is connected (not verified).

### ZOKY impact

Resolved with option A: phase `EDGE` on `ci/zoky-web-exception-release` (`10af1344`), CTO re-review approved with conditions. Staging: see step b'' (finish the ZOKY preview before Part E). Original analysis below.


`origin/release/zoky-web-20261018` differs from `main` for:
- `food-stripe-checkout` (3 files)
- `food-stripe-cancel`
- `wynos-maps-geocode`

After step (b) with `main`-only, two things fail:
- Dispatching `deploy-edge-functions` on the release ref is refused by the branch policy.
- The release branch's own 2026-10-12 copy of that workflow has no environment, so after step (c) it gets no token.

Options:
- **(A, recommended)** Add an edge job to `zoky-web-exception-release.yml`. It runs from `main`, checks out the pinned `release_sha` and deploys only the 3 allowlisted functions, with the verify_jwt pin, behind `environment: production`. This is a workflow change that needs CTO re-review.
- **(B)** Temporarily allow `release/zoky-web-20261018` in the environment's branch rules **and** add `environment: production` to that branch's `deploy-edge-functions.yml`. This weakens the policy and enlarges the release branch.
- **(C)** Deploy edge functions from `main` after the code lands there. This conflicts with the freeze.

The web deploy through the exception workflow is unaffected: it is dispatched on `main`.

### Rollback

- Workflow changes: revert the PR. The repo secrets still exist until step (c).
- After (b): delete the environment secrets, and jobs fall back to the repo secrets.
- After (c): there is no fallback by design. Create a new token and add it as an environment secret. Never restore the old tokens.

### Residual risks / not verified

- Environment reviewers, branch policy, admin bypass and the current secret locations could not be read (API blocked here).
- Whether other systems use the old tokens (local CLIs, other repos) is unknown. Revocation may break those, which is intended.
- `ANDROID_SECRETS_TOKEN` stays repo-level and ungated until the Founder handles it in Part E step 20.
- No claim of zero regression. The workflows were not executed.
