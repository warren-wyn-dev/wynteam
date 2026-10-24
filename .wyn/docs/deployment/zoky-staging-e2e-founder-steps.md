# ZOKY ทดสอบระบบจ่ายเงิน/คืนเงินบน "เว็บทดสอบ" (Stripe โหมดทดสอบ) — ขั้นตอนสำหรับ Founder

- จัดทำโดย: WYN Deploy & DevOps (AI) | วันที่ 2026-10-23
- ใช้กับ: ขั้นที่ 1 ของแผน `.wyn/docs/deployment/zoky-stripe-only-rollout-plan.md`
- Workflow: `.github/workflows/zoky-staging-e2e.yml` (branch `ci/zoky-staging-e2e` ยังไม่ merge)
- การอนุมัติที่ใช้: Founder 2026-09-27 "อนุมัติให้ใช้โปรเจกต์ Free แยก หากมีค่าใช้จ่ายต้องขออนุมัติใหม่"

## อธิบายสั้น ๆ

เราจะสร้าง "ฐานข้อมูลทดสอบ" แยกจากของจริงทั้งหมด แล้วให้ระบบลองจ่ายเงินด้วยพร้อมเพย์และลองคืนเงินด้วย
**เงินปลอมของ Stripe (โหมดทดสอบ)** ไม่มีเงินจริงเกิดขึ้น และไม่แตะลูกค้า ร้าน หรือฐานข้อมูลจริงเลย

ใช้เวลาของ Founder ประมาณ **1 ชั่วโมง 15 นาที** (ส่วน A–C ราว 45 นาที ส่วน D ราว 30 นาที ส่วนใหญ่เป็นการรอ)
ทำบน iPad ด้วย Safari ได้ทั้งหมด

## กฎ 5 ข้อ (สำคัญที่สุด)

1. **ห้ามส่งรหัส/กุญแจใด ๆ ในแชท** (ทุกอย่างที่ขึ้นต้นด้วย `sbp_`, `sk_`, `whsec_` หรือรหัสผ่านฐานข้อมูล) ให้คัดลอกแล้ววางในช่องที่บอกเท่านั้น
2. **ห้ามใช้บัญชี Supabase เดิม (ของจริง)** ในส่วน A ให้ใช้บัญชีใหม่ในแท็บส่วนตัว (Private) เท่านั้น
3. **ใน Stripe ต้องเห็นคำว่า "Test mode" / "โหมดทดสอบ" ตลอดเวลา** กุญแจต้องขึ้นต้นด้วย `sk_test_` เท่านั้น ถ้าเห็น `sk_live_` ให้หยุด
4. **ห้ามกดอัปเกรดแพ็กเกจ (Upgrade/Pro)** ใน Supabase เด็ดขาด ต้องเป็น Free เท่านั้น
5. ถ้าไม่แน่ใจข้อไหน ให้หยุดตรงนั้นแล้วบอกทีมว่า "ติดข้อ X" ได้เลย

---

## ส่วน A — สร้างบัญชีและโปรเจกต์ Supabase สำหรับทดสอบ (~15 นาที)

1. เปิด Safari แล้วเปิด **แท็บส่วนตัว** (แตะไอคอนแท็บ → แตะ **ส่วนตัว / Private**)
2. ในแท็บส่วนตัว ไปที่ `https://supabase.com/dashboard/sign-up`
3. ช่อง Email ใส่ **อีเมลเดิมของ Founder แต่เติม `+staging` หน้าเครื่องหมาย @** (เช่น `ชื่อเดิม+staging@icloud.com`) ตั้งรหัสผ่านใหม่ แล้วแตะ **Sign up**
   - ถ้าไม่มีอีเมลยืนยันมาใน 5 นาที: ใช้ "ซ่อนอีเมลของฉัน" (Hide My Email) ของ iCloud สร้างอีเมลใหม่แทน แล้วสมัครใหม่
4. เปิดอีเมลยืนยันจาก Supabase แล้วแตะลิงก์ **Confirm** (ให้เปิดในแท็บส่วนตัวเดิม)
5. เมื่อระบบถามให้สร้าง Organization: ตั้งชื่อ `zoky-staging` เลือก Type **Personal** เลือก Plan **Free - $0/month** แล้วแตะ **Create organization**
6. แตะ **New project** ตั้งค่าดังนี้
   - Project name: `zoky-staging`
   - Database Password: แตะ **Generate a password** (ไม่ต้องจด เพราะข้อ B7 จะสร้างใหม่ให้)
   - Region: **Southeast Asia (Singapore)**
   - ส่วนอื่นปล่อยตามเดิม แล้วแตะ **Create new project**
7. รอจนหน้าโปรเจกต์ขึ้นว่าพร้อมใช้งาน (ประมาณ 2 นาที)
8. เมนูซ้ายล่าง แตะ **Project Settings** (รูปเฟือง) → **General** ดูช่อง **Project ID** (ตัวอักษร 20 ตัว) — ค่านี้ **ไม่ใช่ความลับ** ใช้ในข้อ B9 เปิดหน้านี้ค้างไว้
9. ตรวจให้แน่ใจว่ามุมขวาบนเป็นบัญชี `+staging` ใหม่ (แตะรูปโปรไฟล์ดู) และเห็นโปรเจกต์ **zoky-staging เพียงโปรเจกต์เดียว**

**ห้ามทำในส่วน A:**
- ห้ามเชิญบัญชีใหม่นี้เข้า organization ของ WYNOS เดิม และห้ามเชิญบัญชีเดิมเข้ามาที่นี่
- ห้ามเปิดโปรเจกต์ของจริงในแท็บนี้
- ห้ามกด Upgrade หรือเพิ่มบัตรเครดิต

---

## ส่วน B — ตั้งค่า environment `staging` บน GitHub (~10 นาที)

ใช้แท็บ Safari ปกติ (ไม่ใช่แท็บส่วนตัว) สำหรับ GitHub

1. เปิด `https://github.com/warren-wyn-dev/wynteam` แล้วแตะ **Settings** (ถ้าไม่เห็น ให้เลื่อนแถบเมนูไปทางขวา)
2. เมนูซ้าย แตะ **Environments** → แตะ **New environment** → พิมพ์ `staging` (ตัวพิมพ์เล็กทั้งหมด) → แตะ **Configure environment**
3. หัวข้อ **Deployment protection rules**: ติ๊ก **Required reviewers** ใส่ชื่อบัญชีของ Founder **ปิด** "Prevent self-review" แล้วแตะ **Save protection rules**
4. หัวข้อ **Deployment branches and tags**: เลือก **Selected branches and tags** → แตะ **Add deployment branch or tag rule** → พิมพ์ `main` → แตะ **Add rule**
5. กลับไปที่ **แท็บส่วนตัว (Supabase staging)** แตะรูปโปรไฟล์มุมขวาบน → **Account preferences** → **Access Tokens** (หรือเปิด `https://supabase.com/dashboard/account/tokens`) → แตะ **Generate new token** ตั้งชื่อ `github-staging` (ถ้ามีให้เลือกวันหมดอายุ เลือก 30 วัน) → แตะ **Generate** → แตะ **Copy** (ขึ้นต้นด้วย `sbp_`)
6. กลับไปแท็บ GitHub หน้า environment `staging` หัวข้อ **Environment secrets** แตะ **Add environment secret** → Name: `STAGING_SUPABASE_ACCESS_TOKEN` → วางค่าที่คัดลอก → แตะ **Add secret**
7. กลับไปแท็บส่วนตัว (Supabase staging) → **Project Settings** → **Database** → หัวข้อ Database password แตะ **Reset database password** → แตะ **Generate a password** → แตะ **Copy** → แตะ **Reset password**
8. กลับไปแท็บ GitHub → **Add environment secret** → Name: `STAGING_SUPABASE_DB_PASSWORD` → วางรหัส → แตะ **Add secret**
9. หัวข้อ **Environment variables** แตะ **Add environment variable** → Name: `STAGING_SUPABASE_PROJECT_REF` → Value: Project ID 20 ตัวจากข้อ A8 → แตะ **Add variable**
10. คัดลอกข้อความอื่นทับคลิปบอร์ด (เช่น คัดลอกคำว่า `ok`) เพื่อล้างรหัสที่เพิ่งคัดลอก

**ห้ามทำในส่วน B:**
- ห้ามใส่ค่าพวกนี้ใน environment `production` หรือใน **Repository secrets**
- ห้ามตั้งชื่อ secret ว่า `SUPABASE_ACCESS_TOKEN` (ชื่อนี้สงวนไว้ให้ของจริงเท่านั้น) ต้องขึ้นต้นด้วย `STAGING_` ตามที่เขียนไว้
- ห้ามใส่กุญแจ Stripe ใน GitHub (กุญแจ Stripe ใส่ใน Supabase staging เท่านั้น ส่วน C)

---

## ส่วน C — Stripe โหมดทดสอบ (~20 นาที)

ทำในแท็บ Safari ปกติ ด้วยบัญชี Stripe แพลตฟอร์มเดิม

1. เปิด `https://dashboard.stripe.com` แล้วเปิด **Test mode** (สวิตช์มุมขวาบน หรือแตะชื่อบัญชีมุมซ้ายบนแล้วเลือก **Switch to test mode**) ต้องเห็นแถบหรือป้าย **Test mode** สีส้ม
   - ถ้าบัญชีมีให้เลือกแค่ **Sandbox** ไม่มี Test mode: หยุดตรงนี้แล้วบอกทีม
2. เมนู **Developers** → **API keys** → แถว **Secret key** แตะ **Reveal test key** → ตรวจว่าขึ้นต้นด้วย `sk_test_` → แตะคัดลอก
3. ไปที่แท็บส่วนตัว (Supabase staging) → เมนูซ้าย **Edge Functions** → **Secrets** (หรือ **Project Settings** → **Edge Functions**) → แตะ **Add new secret** → Name: `STRIPE_SECRET_KEY` → วางค่า → แตะ **Save**
4. กลับไป Stripe (ยังอยู่ใน Test mode) → **Developers** → **Webhooks** → แตะ **Add destination** (หรือ **Add endpoint**)
5. หัวข้อ "Events from": เลือก **Connected accounts** (บัญชีที่เชื่อมต่อ) — ไม่ใช่ "Your account"
6. เลือก events ตามรายการนี้ให้ครบ 11 ตัว (ใช้ช่องค้นหาพิมพ์ทีละชื่อ แล้วติ๊ก):
   1. `checkout.session.completed`
   2. `checkout.session.async_payment_succeeded`
   3. `checkout.session.async_payment_failed`
   4. `checkout.session.expired`
   5. `payment_intent.payment_failed`
   6. `charge.refunded`
   7. `charge.refund.updated`
   8. `refund.created`
   9. `refund.updated`
   10. `refund.failed`
   11. `account.updated`
7. แตะ **Continue** เลือก **Webhook endpoint** → ช่อง Endpoint URL พิมพ์ `https://<Project ID>.supabase.co/functions/v1/stripe-webhook` (แทน `<Project ID>` ด้วยค่า 20 ตัวจากข้อ A8) → แตะ **Create destination**
8. ในหน้าของ endpoint ที่เพิ่งสร้าง หัวข้อ **Signing secret** แตะ **Reveal** → แตะคัดลอก (ขึ้นต้นด้วย `whsec_`)
9. ไปที่แท็บส่วนตัว (Supabase staging) → **Edge Functions** → **Secrets** → **Add new secret** → Name: `STRIPE_WEBHOOK_SECRET` → วางค่า → แตะ **Save**
10. กลับไป Stripe (Test mode) → **Settings** (รูปเฟือง) → **Payments** → **Payment methods** → เลือกแท็บ/ส่วน **Connected accounts** → ตรวจว่า **PromptPay** และ **Cards** เปิด (On) ถ้ายังปิด ให้แตะเปิด
11. คัดลอกข้อความอื่นทับคลิปบอร์ดเพื่อล้างกุญแจ

**บัญชีร้านทดสอบ (connected account) ไม่ต้องสร้างเอง** — workflow จะสร้างให้ในส่วน D แล้วส่งลิงก์ให้กรอกข้อมูลทดสอบ

**ห้ามทำในส่วน C:**
- ห้ามแก้หรือลบ webhook ของจริง (Live mode) ที่มีอยู่แล้ว
- ห้ามใส่กุญแจที่ขึ้นต้นด้วย `sk_live_` หรือ `rk_live_` ใน Supabase staging
- ห้ามใช้ข้อมูลจริง (บัตรประชาชน/บัญชีธนาคารจริง) ในหน้าลงทะเบียนร้านทดสอบ

---

## ส่วน D — รันการทดสอบ (~30 นาทีของ Founder, รอระบบรวมราว 1 ชั่วโมง)

**ก่อนเริ่ม:** ทีมต้องเปิด PR ของ branch `ci/zoky-staging-e2e` แล้ว Founder อนุมัติให้ merge เข้า `main` ก่อน (GitHub แสดงปุ่ม Run workflow เฉพาะ workflow ที่อยู่บน `main`) การ merge นี้ไม่ deploy อะไรขึ้นของจริง

1. เปิด `https://github.com/warren-wyn-dev/wynteam/actions` → เมนูซ้ายแตะ **ZOKY staging E2E (Stripe test mode)**
2. แตะ **Run workflow** → Branch: `main` → step: **setup** → ช่อง backend_sha และ web_sha **ปล่อยตามค่าเดิม** → ช่อง confirm พิมพ์ `ZOKY-STAGING-TEST-MODE` → แตะ **Run workflow**
3. แตะงานที่เพิ่งเริ่ม → แตะ **Review deployments** → ติ๊ก **staging** → แตะ **Approve and deploy**
4. รอจนขึ้นเครื่องหมายถูกสีเขียว (ครั้งแรกประมาณ 15 นาที) ถ้าเป็นสีแดง ให้ส่ง **ลิงก์ของงาน** ให้ทีม (ส่งลิงก์ได้ ไม่มีความลับ)
5. ในหน้างาน เลื่อนลงไปที่ **Summary** จะเห็นบรรทัด `ACTION (Founder): open this Stripe TEST onboarding link` → แตะลิงก์นั้น **ภายใน 5 นาที**
6. ในหน้าลงทะเบียนของ Stripe ต้องเห็นคำว่า Test mode/โหมดทดสอบ ให้แตะ **Use test data / ใช้ข้อมูลทดสอบ** ทุกหน้าที่มีปุ่มนี้ ถ้าต้องกรอกเอง:
   - เบอร์โทร `000 000 0000` และรหัส SMS `000000`
   - เลขประจำตัว/ภาษี ใส่ `000000000` ส่วนบัญชีธนาคารเลือก **Use test account** (บัญชีทดสอบ)
   - ที่อยู่ใส่ที่อยู่ใดก็ได้ในไทย
7. เมื่อกรอกเสร็จ Stripe จะพาไปหน้า `merchant.wynos.online` **ไม่ต้องทำอะไรต่อ ปิดแท็บได้เลย** (ถ้าลิงก์หมดอายุ ให้ทำข้อ 2–5 ใหม่)
8. รัน **setup** อีกครั้ง (ทำข้อ 2–4 ซ้ำ) ใน Summary ต้องเห็นคำว่า **READY** ถ้ายังไม่ READY ให้รอ 10 นาทีแล้วรันอีกครั้ง ถ้ายังไม่ได้ให้ส่งลิงก์งานให้ทีม
9. แตะ **Run workflow** อีกครั้ง → step: **e2e** → confirm `ZOKY-STAGING-TEST-MODE` → แตะ **Run workflow** → **Review deployments** → **Approve and deploy**
10. ระหว่างรอ (ประมาณ 45 นาที) ถ้าใน log หรือ Summary มีบรรทัด `MANUAL: open this test Checkout link` ให้แตะลิงก์นั้น **ภายใน 8 นาที** แตะปุ่มจ่าย แล้วแตะ **Authorize test payment** (เงินทดสอบ ไม่มีเงินจริง)
11. เมื่อเสร็จ เปิด **Summary** จะเห็นตาราง 10 รายการ แต่ละแถวเป็น PASS / MANUAL / FAIL → ส่ง **ลิงก์ของงาน** ให้ทีม (ไม่ต้องแคปหน้าจอ)

### เช็กเพิ่มด้วยมือ (ทำเฉพาะเมื่อทีมขอ)

- **M1 — คืนเงินพร้อมเพย์ที่รอเลขบัญชีลูกค้า** (ถ้ารายการที่ 3 ขึ้น MANUAL): Stripe (Test mode) → **Payments** → แตะรายการ ฿50 ล่าสุดที่จ่ายด้วย PromptPay → ดูหัวข้อ Refund → แคปหน้าจอเฉพาะส่วนนั้นส่งทีม (หน้านี้ไม่มีความลับ)
- **M2 — ส่ง event ซ้ำ** (ไม่บังคับ ระบบตรวจอัตโนมัติแล้วในรายการที่ 10): Stripe (Test mode) → **Developers** → **Webhooks** → endpoint staging → แท็บ **Event deliveries** → แตะ `checkout.session.completed` อันล่าสุด → แตะ **Resend** → บอกทีมว่ากดแล้ว เพื่อให้ทีมตรวจว่าไม่มีแจ้งเตือนซ้ำ
- **M3 — ไม่มีเงินจริง**: Stripe → ปิด Test mode ชั่วคราว → **Payments** ต้อง **ไม่มี** รายการ ฿50 ของวันนี้ → เปิด Test mode กลับ

### ถ้าต้องการเริ่ม staging ใหม่ทั้งหมด

บอกทีมก่อน แล้วลบโปรเจกต์ `zoky-staging` ในแท็บส่วนตัว (Project Settings → General → Delete project) สร้างใหม่ตามข้อ A6–A8 แล้วทำข้อ B7–B9 และ C3, C7–C9 ใหม่ (Project ID เปลี่ยน) ห้ามลบโปรเจกต์อื่นเด็ดขาด

---

## บทเรียนจากการทำจริง (2026-10-23/24)

- **ส่วน A:** ใช้บัญชี `adminwynos_s+zokyqa@gmail.com` (Project ID `kzgkdrchkcgveaoxmdsy`, Sydney) ใช้ได้ ไม่ต้องเป็น Singapore
- **ส่วน B ข้อ 5:** หน้า token ใหม่ของ Supabase ให้แตะ **Create legacy token** (บัญชีนี้มีแต่โปรเจกต์ทดสอบ จึงปลอดภัย) ด่าน Isolation guard ยืนยันแล้วว่า token มองไม่เห็นของจริง
- **ส่วน C (สำคัญ):** กุญแจ `sk_test_` กับ webhook **ต้องอยู่ที่เดียวกัน** — ถ้ากุญแจมาจาก **ZOKY-QA โหมดทดสอบ** webhook ก็ต้องสร้างใน **ZOKY-QA โหมดทดสอบ** (กด "ออกจากแซนด์บ็อกซ์" ก่อน) ไม่ใช่ในแซนด์บ็อกซ์ ร้านทดสอบ (`acct_1UTlqNLkHkLO2gVB`) อยู่ฝั่งโหมดทดสอบ
- **ส่วน D:** ลิงก์ลงทะเบียนร้านหมดอายุเร็ว ให้ Founder เปิดจาก Summary ของงานเองทันทีที่เป็นสีเขียว ไม่ต้องรอทีมส่งต่อ; ต้องกรอกจนกด Submit; หน้า merchant.wynos.online ที่เด้งมาหลังกรอกเสร็จ **ไม่ต้องล็อกอิน**
- **ห้ามแคปหน้าจอตอนรหัสผ่านโชว์** (แตะรูปตาให้เป็นจุดก่อน)

## สิ่งที่การทดสอบนี้ยังไม่ครอบคลุม

- หน้าเว็บ ZOKY จริงบน iPad (Vercel Preview ที่ชี้มาที่ staging) — การสร้าง Preview ต้องใช้กุญแจ Vercel ซึ่งเก็บไว้ใน `production` เท่านั้น ต้องตัดสินใจแยกต่างหาก ทีมจะเสนอทางเลือกให้ภายหลัง
- ค่าธรรมเนียมคืนเงินพร้อมเพย์ ฿10 และอีเมลที่ Stripe ส่งถึงลูกค้า (โหมดทดสอบไม่ส่งอีเมลจริง)
