# ZOKY-LINE-003 — LINE Login ผ่าน LIFF ID token (ออก session ฝั่ง server) — Design

Status: **Design / Proposal — ยังไม่ได้รับอนุมัติ ห้าม implement จนกว่า Founder อนุมัติรายการในข้อ 7 และผ่าน Spike S0 (ข้อ 8)**
Roles: WYN Software Architect + CTO + QA & Security — 2026-11-08
ขอบเขตรอบนี้: เอกสารเท่านั้น ไม่แก้ source, ไม่สร้าง migration จริง, ไม่ commit, ไม่ต่อ Supabase/LINE จริง, ไม่อ่าน secrets
ต่อจาก: `zoky-line-002-line-login-and-server-cart.md` (T1/T2/T3), `zoky-line-login-design-review.md` (ข้อกำหนด 12 ข้อ, threat model T-A1…T-A19), `docs/qa/zoky-line-002/real-flow-code-analysis.md`

---

## 0. บทสรุปผู้บริหาร

**ปัญหา:** T1 (Supabase custom OIDC แบบ redirect) ล้มบน iOS จริง: LINE สลับไปแอป LINE แล้วส่งผลกลับในหน้าต่างอื่น PKCE verifier หาย และเอกสาร LINE ไม่รับประกันการ authorize ใน LIFF browser

**ข้อเสนอ ("ข้อ ก"):** ใน LIFF ผู้ใช้ล็อกอิน LINE อยู่แล้ว `liff.getIDToken()` ให้ ID token ได้โดย **ไม่ต้องเปลี่ยนหน้า/ไม่ต้อง redirect** ส่ง token ให้ Edge Function ใหม่ `line-login` (verify_jwt=false) → verify กับ LINE → หา/สร้างผู้ใช้ Supabase จาก `sub` → ออก session กลับมา

**ข้อสรุปเทคนิค (สั้น):**
1. วิธีออก session ที่แนะนำ = **`auth.admin.generateLink({type:'magiclink'})` + `verifyOtp({token_hash})` ทำใน Edge Function แล้วคืน session ให้ client `setSession`** (ไม่เขียน JWT เอง, ไม่ใช้ JWT secret) ต้องใช้ **อีเมลสังเคราะห์แบบสุ่ม** (`line-<uuid>@line-login.zoky.invalid`) เพราะ GoTrue ไม่มี API ออก session ให้ user ที่ไม่มีอีเมล — อีเมลนี้ **ไม่ใช่ identity และไม่ถูกใช้จับคู่เด็ดขาด**
2. ที่เก็บ mapping = **ตารางใหม่ `line_login_identities`** (ไม่ใช้ `line_links`, ไม่ใช้ `app_metadata`) ต้องมี migration แบบ additive → Founder gate
3. นี่คือ **Authentication Architecture Change** + **Edge Function สาธารณะที่ออก session** (ความเสี่ยงสูงสุดของระบบ) ต้อง Founder อนุมัติ และมี kill switch ฝั่ง server
4. มี **3 สมมติฐานที่อาจฆ่า design นี้** ต้องพิสูจน์ใน Spike S0 ก่อนเขียนโค้ดจริง (ข้อ 8.0): (ก) LIFF ที่ endpoint `food.wynos.online/line` ให้ `getIDToken()` ได้บนหน้า `/food/login` และบน origin ที่ลูกค้าใช้จริง (ข) LINE ผูก `nonce` กับ LIFF ID token ได้หรือไม่ (ค) ผลข้างเคียงของอีเมลสังเคราะห์ (Stripe `customer_email`, account switcher)

---

## 1. สถาปัตยกรรมที่เสนอ

### 1.1 Flow

```
[LIFF WebView: /food/login]  (flag เปิด + liff.isInClient() + มี ID token)
  1. user กด "เข้าสู่ระบบด้วย LINE" (ไม่เปลี่ยนหน้า)
  2. web: idToken = liff.getIDToken()           # LIFF ให้อยู่แล้ว ไม่มี redirect
  3. web -> POST {SUPABASE}/functions/v1/line-login   { idToken }      (ไม่มี Authorization ของ user)
  4. Edge Function line-login (verify_jwt=false):
       a. kill switch / origin / method / body-size / rate-limit (ก่อนเรียก LINE)
       b. verify ID token กับ LINE (client_id = LINE_FOOD_LOGIN_CHANNEL_ID) + ตรวจ iss/aud/exp/sub ซ้ำ (+ nonce ถ้า S0 ยืนยันว่าทำได้)
       c. sub -> line_login_identities -> user_id  (ไม่มี -> สร้าง auth user ใหม่ + แถว mapping แบบ atomic)
       d. admin.generateLink(magiclink, email ของ user นั้น) -> verifyOtp(token_hash) ฝั่ง server (anon client, ไม่เก็บ session)
       e. คืน { access_token, refresh_token, expires_in, expires_at }  (ไม่ log, ไม่ cache)
  5. web: client.auth.setSession(...) -> getUser() -> registerCurrentAccount() -> window.location.replace("/food") 
         (เส้นทางเดียวกับ login อีเมลเดิม จึงได้ตะกร้า guest / takeLineAutoLink เหมือนเดิม)
```

ข้อดีเชิงโครงสร้างเทียบ T1: ไม่มี OAuth redirect, ไม่มี PKCE verifier ข้ามหน้าต่าง, ไม่ต้องพึ่งพฤติกรรม authorize ใน LIFF browser ที่ LINE ไม่รับประกัน, ตะกร้า/sessionStorage อยู่หน้าเดิมตลอด

### 1.2 เปรียบเทียบวิธีออก session (หัวใจของ design)

ข้อเท็จจริงเดิมจากเอกสารรอบก่อน: `signInWithIdToken` รองรับเฉพาะ provider ที่ Supabase กำหนด (Google/Apple/Facebook/Kakao/Keycloak) ไม่รองรับ `custom:line` — **ไม่ได้ตรวจซ้ำในรอบนี้** (ค้น docs search แล้วผลไม่ชัดพอ ให้ยืนยันซ้ำใน S0)

| ทางเลือก | วิธีทำ | ข้อดี | ข้อเสีย/ความเสี่ยง | ข้อเสนอ |
|---|---|---|---|---|
| **M1 (แนะนำ)** generateLink + verifyOtp ฝั่ง server | service role `admin.generateLink({type:'magiclink', email})` ได้ `hashed_token` → ฟังก์ชันเรียก `verifyOtp({token_hash, type:'magiclink'})` ด้วย anon client ที่ไม่ persist → คืน session | ใช้ API ทางการ; session จริงของ GoTrue (มี refresh token, อยู่ใน `auth.sessions`, revoke ได้); OTP ถูกใช้ทันที ไม่ค้างเป็น credential | ต้องมีอีเมลบน user; side effect ต่ออีเมล/identity (ดู 1.3); service role ในฟังก์ชันสาธารณะ | **เลือก** |
| M2 | เหมือน M1 แต่คืน `token_hash` ให้ client เรียก `verifyOtp` เอง | session ถูกสร้างใน client lib ตรง ๆ | `token_hash` เป็น bearer credential ค้างใน network/memory/log ของ browser จนใช้ | สำรอง (ถ้า M1 ใช้ไม่ได้เพราะ IP/UA ของ session) |
| M3 | เซ็น JWT เอง (HS256 JWT secret / signing key) | ไม่ต้องมีอีเมล | custom crypto, ต้องเอา JWT secret/คีย์เข้า function, ไม่มี refresh token/ไม่อยู่ใน `auth.sessions`, revoke ไม่ได้ | **ห้าม** (ขัด SECURITY_RULES "ไม่สร้าง custom cryptography") |
| M4 | password ที่คำนวณจาก HMAC(secret, sub) + `signInWithPassword` | ไม่มี magic link | ยังต้องมีอีเมล; secret รั่ว = ยึดทุกบัญชี; หมุนคีย์ลำบาก | ไม่เลือก |
| M5 | `signInWithIdToken` ส่ง LINE token เข้า Supabase | ไม่มีโค้ด mint เอง | ไม่รองรับ `custom:line` (ตามเอกสารเดิม; ยืนยันซ้ำใน S0) | ใช้ไม่ได้ ถ้าเปลี่ยนค่อยทบทวน |
| M6 | Supabase Third-Party Auth | — | LINE ไม่อยู่ในรายการ (สมมติฐาน ยังไม่ตรวจ) | ไม่เลือก |
| M7 | T1 redirect (ล้มจริงแล้ว) | — | ล้มบน iOS | เลิก |

**ทำไม M1 ฝั่ง server ดีกว่า M2:** OTP ถูกบริโภคใน function ทันที ไม่มี one-time credential ค้างฝั่ง client; สิ่งที่ออกจาก function เหมือนผลของ `/token` ปกติ (access+refresh) ต้องไม่ log เท่านั้น

### 1.3 อีเมลสังเคราะห์: ข้อกำหนดและผลข้างเคียง (ห้ามสมมติว่ามีอีเมลจริง)

- LINE อาจไม่ส่งอีเมล (เราไม่ขอ scope `email` และ LIFF ต้องไม่เปิด scope email) — **ไม่อ่าน claim `email` ของ ID token เลย** แม้จะมีมา
- อีเมลสังเคราะห์ = `line-<uuid v4 สุ่ม>@line-login.zoky.invalid` สร้างด้วย `admin.createUser({ email, email_confirm: true, app_metadata: { zoky_login: "line" } })`
  - ใช้ **UUID สุ่ม ไม่ใช่ hash ของ sub**: ถ้าอีเมลคำนวณได้จาก sub ผู้โจมตีรู้ sub ของเหยื่อ (ไม่ใช่ความลับสูง) สมัคร `signUp` ด้วยอีเมลนั้นก่อน (pre-account takeover: ตั้งรหัสผ่านไว้บนบัญชี unconfirmed แล้ว login ของเหยื่อมา confirm ให้) — UUID สุ่มตัดช่องนี้ (และ TLD `.invalid` รับเมลไม่ได้ จึงยืนยันเองไม่ได้)
  - อีเมลนี้ไม่เคยถูกใช้ค้นหาผู้ใช้; การค้นหาใช้ `sub -> line_login_identities` เท่านั้น แล้วอ่านอีเมลจาก `auth.users` ของ user_id นั้นเพื่อทำ generateLink
- ผลข้างเคียงที่ต้องจัดการ (ไฟล์จริงที่พบ):
  - `supabase/functions/food-stripe-checkout/index.ts:169` — `if (user.email) params.set("customer_email", …)` จะส่งอีเมล `.invalid` ให้ Stripe (ปฏิเสธ → ชำระเงินล้ม) → **ต้องแก้** ให้ข้ามเมื่อ `app_metadata.zoky_login === "line"` และอีเมลลงท้าย `.invalid` (production Edge Function → ต้อง Founder อนุมัติ)
  - `supabase/functions/merchant-stripe-connect/index.ts:555` ใช้ `user.email ?? null` (เป็นฝั่ง Merchant; ผู้ใช้ LINE ไม่ควรเข้า — ตรวจ T-L19)
  - `web/lib/account-registry.ts`, `web/components/auth-flow/screens.tsx`, `web/lib/account-password.ts` อ่าน `user.email`; `web/lib/auth-repository.ts:202` ใช้ `app_metadata.provider === "email"` ตัดสินว่า "สมัครด้วยอีเมล/รหัสผ่าน" — user ที่สร้างผ่าน GoTrue ด้วยอีเมลอาจได้ `provider: "email"` ต้องแก้ให้ไม่ตีความผู้ใช้ LINE ว่าเป็น password user (เสนอ helper เดียว `realEmailOf(user)` คืน null เมื่อเป็นอีเมลสังเคราะห์ แล้วใช้ทุกจุดที่แสดง/ส่งอีเมล)
  - flow ลืมรหัสผ่านของ `.invalid` ส่งเมลไม่ได้ (ปลอดภัยโดยธรรมชาติ) แต่ UI ต้องไม่ชวนผู้ใช้ LINE-only ไป "ลืมรหัสผ่าน"
- **ที่ยังไม่รู้ (S0):** `admin.createUser` โดย **ไม่มี** email/phone ใช้ได้ไหม และถ้าได้ ก็ยัง mint ไม่ได้อยู่ดี (generateLink ต้องใช้อีเมล) ; `admin.updateUserById` ล้างอีเมลหลังสร้างได้ไหม (คาดว่าไม่ได้); verifyOtp magiclink เพิ่ม `email` identity/`providers` ใน `app_metadata` หรือไม่ — ใช้ผลนี้ตัดสินว่า helper `realEmailOf` ต้องดูอะไรบ้าง

### 1.4 Edge Function `line-login` — สัญญา

- Path: `supabase/functions/line-login/{index.ts,_lib.ts,_lib.test.ts}`; `supabase/config.toml` เพิ่ม `[functions.line-login] verify_jwt = false` พร้อมคอมเมนต์เหตุผล (ผู้เรียกยังไม่มี session; ป้องกันด้วย LINE ID token; ตามแบบ `wynos-maps-geocode`/`line-webhook`)
- Request: `POST` JSON `{ "action": "login", "idToken": "<JWT รูปแบบ 3 ส่วน ≤4096>", "nonce"?: "<…>" }` อ่าน body ได้ไม่เกิน 8 KB ปฏิเสธ field อื่น/`lineUserId`/`userId`/`email` ที่ client ส่งมา (ไม่อ่านเลย)
- Response สำเร็จ: `{ "session": { access_token, refresh_token, expires_in, expires_at, token_type: "bearer" } }` + header `Cache-Control: no-store`
- Error (เหมือนกันทุกกรณี token ไม่ผ่าน เพื่อไม่ leak เหตุผล): `401 invalid_line_token`, `400 invalid_body`, `429 rate_limited`, `503 line_login_disabled`, `500 internal_error`
- Env ที่ใช้ (ไม่มี secret ใหม่): `LINE_FOOD_LOGIN_CHANNEL_ID` (มีแล้ว ใช้โดย `line-link`), `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY` (ระบบจัดให้), **ใหม่แบบไม่ลับ:** `LINE_LOGIN_ENABLED` (kill switch; ต้องเป็น `"1"` ตรง ๆ) และ `LINE_LOGIN_EXTRA_ORIGINS` (staging, รูปแบบเดียวกับ `extraOrigins` ของ `line-link`)
- ไม่ใช้ channel secret (verify endpoint ต้องการแค่ `client_id`)
- Reuse: `verifiedLineUserId`, `corsHeaders`, `extraOrigins`, regex ของ `line-link/_lib.ts` — แนะนำ import ตรงจาก `../line-link/_lib.ts` (เพิ่มพารามิเตอร์ `nonce` แบบ optional ที่เข้ากันย้อนหลังได้) แล้วค่อยย้ายเข้า `_shared/` เมื่อ guard ของ `line-link` ขึ้น production แล้ว (หลีกเลี่ยงการ redeploy `line-link` โดยไม่จำเป็น) **หมายเหตุ:** `verifiedLineUserId` ปัจจุบัน **ไม่ตรวจ nonce** และ `line-link` ปัจจุบันไม่ผูก nonce

### 1.5 สร้างผู้ใช้ใหม่แบบ race-safe

1. `select user_id from line_login_identities where line_sub = $sub` → พบ: ไปขั้น generateLink
2. ไม่พบ: `admin.createUser(...)` → `insert into line_login_identities(line_sub, user_id)` (PK `line_sub`, `unique(user_id)`)
3. ถ้า insert ชน unique (อีกคำขอสร้างก่อน): `admin.deleteUser(<user ที่เพิ่งสร้างเองในคำขอนี้>)` แล้วใช้แถวของผู้ชนะ (ลบเฉพาะ user ที่ function เพิ่งสร้างเองและยังไม่มี mapping/ข้อมูลใด)
4. ถ้า function ตายระหว่าง 2→3 อาจเหลือ user กำพร้า (อีเมลสังเคราะห์ ไม่มี mapping) — ไม่มีผลต่อความปลอดภัย (ไม่มีใครล็อกอินเข้าได้) เสนอ query ตรวจรายเดือนใน runbook; **ห้ามลบอัตโนมัติ**

---

## 2. การจับคู่ตัวตน (Identity)

### 2.1 หลักการ (บังคับ)
- ตัวระบุเดียว = `sub` ของ ID token ที่ LINE verify แล้วเท่านั้น (รูปแบบ `^U[0-9a-f]{32}$`) จาก channel ของ LIFF ลูกค้า (Provider เดียวกับ OA → `sub` ตรงกับ `line_links.line_user_id`)
- **ห้ามจับคู่/รวมบัญชีด้วยอีเมล เบอร์ ชื่อ รูป** ในทุกชั้น (client / Edge / SQL) ไม่ว่าอีเมลจริงหรือสังเคราะห์; ห้ามเรียก API ที่ค้นผู้ใช้ด้วยอีเมลในฟังก์ชันนี้
- ผู้ใช้ LINE ใหม่ = บัญชีใหม่เสมอ (ตรงกับ D-4); ไม่ auto-merge กับ Google/อีเมลเดิม
- LIFF ต้องไม่เปิด scope `email` (Founder ตรวจในหน้า LIFF/LINE Login channel); ถึงเปิดก็ไม่อ่าน claim

### 2.2 ที่เก็บ mapping — เปรียบเทียบ

| ตัวเลือก | ข้อดี | ข้อเสีย | Migration/Gate |
|---|---|---|---|
| **A. ใช้ `line_links` เดิม** | ไม่มี migration | `line_links` คือ "ช่องทางแจ้งเตือน" ไม่ใช่ identity: ผู้ใช้ลบเองได้ (RLS delete own) = เสียทางล็อกอิน; unique ต่อ `audience`; **เขียนโดย auto-link ที่ไม่ต้องกดยืนยัน** (ผู้ที่ถือเครื่องที่ล็อกอินค้างและเปิด LIFF ด้วย LINE ของตัวเอง จะผูก LINE ของตนกับบัญชีนั้น แล้วกลายเป็น backdoor ล็อกอินถาวร) ; พฤติกรรม "ย้าย link" เดิม/guard PR-4 ขัดกับความหมาย identity | ไม่ต้อง — **ปฏิเสธ (T3 ยังไม่อนุมัติเหมือนเดิม)** |
| **B. ตารางใหม่ `line_login_identities` (แนะนำ)** | unique atomic (กัน race สร้างซ้ำ), FK `on delete cascade` กับ `auth.users` (ลบบัญชี = ลบ mapping), มี `created_at/last_login_at` สำหรับ audit/cap, RLS deny-all (เฉพาะ service role), ไม่ปะปนกับ notification | ต้อง migration (บน **project เดียวกับ production** เพราะ staging ใช้ project เดียวกัน) | Founder อนุมัติ migration (additive, มี rollback) |
| C. `app_metadata.line_sub` | ไม่มีตาราง | ไม่มี unique constraint (race → 2 บัญชีต่อ 1 sub), ค้นด้วย `listUsers` ไม่ได้ในทางปฏิบัติ, สร้าง index บน `auth.users` ไม่ได้ → ต้องมี RPC/migration อยู่ดี | ไม่ลดภาระ ไม่แนะนำ |
| D. เขียน `auth.identities` ตรง ๆ | — | แตะ schema `auth` ของ Supabase, ไม่มี API รองรับ | **ห้าม** |

**ร่าง schema (ไม่ใช่ migration จริง — ห้ามสร้างจนกว่าจะอนุมัติ):**
```
line_login_identities(
  line_sub text primary key check (line_sub ~ '^U[0-9a-f]{32}$'),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_login_at timestamptz not null default now()
)  -- enable RLS; revoke all from anon, authenticated; ไม่มี policy; เขียนเฉพาะ service role
line_login_rate_limits(bucket text, at timestamptz default now())  -- + index (bucket, at) + RPC reserve แบบ advisory lock (ตามแบบ migrations_wyn149_location_search_rate_limit.sql)
```
ไม่เก็บ ชื่อ/รูป/อีเมล/ID token ใด ๆ; rollback = drop 2 ตาราง + 1 function (ทำได้ **ต่อเมื่อไม่มีผู้ใช้ LINE-only** — ไม่เช่นนั้นให้ปิดด้วย kill switch แทน ห้ามลบ mapping)

### 2.3 การผูก LINE กับบัญชี Google/อีเมลเดิม (flow "link")
- ทำได้เฉพาะเมื่อผู้ใช้ **ล็อกอินบัญชีเดิมอยู่ (Authorization: Bearer JWT ของ user)** และส่ง ID token ที่ผ่าน verify ในคำขอเดียวกัน: `action: "link"` → `insert line_login_identities(line_sub, user_id = auth user จาก JWT)`
- ถ้า `sub` ถูกถือโดยบัญชีอื่น → `409 already_linked_elsewhere` **ไม่ย้าย ไม่รวม** (สอดคล้อง guard ของ `line-link`)
- ต้องเป็น **การกดยืนยันชัดเจน** (ห้าม auto-link แบบ ZOKY-LINE-001) เพราะผลคือเพิ่มช่องทางล็อกอินถาวร
- Authorization header (ไม่ใช่ cookie) → CSRF ไม่ใช่ปัญหา; ownership ยึด user จาก JWT เท่านั้น
- **ข้อจำกัดจริง:** ผู้ใช้ Google ล็อกอินใน LIFF WebView ไม่ได้ และ storage ของ LIFF WebView แยกจาก Safari จึงมี session ของบัญชีเดิมใน WebView ไม่ได้ ดังนั้น flow link ใช้ได้จริงเฉพาะคนที่ล็อกอินอีเมล/รหัสผ่านใน LIFF → **จัดเป็น P2 ไม่อยู่ใน MVP** (ผู้ใช้ Google เดิมได้บัญชี LINE ใหม่ตาม D-4 พร้อม copy ชัดเจน)
- เส้นทางสำรองสำหรับผู้ใช้ LINE-only ภายหลัง (P2): `updateUser({email})` ด้วยอีเมลจริงที่ผู้ใช้ยืนยัน (ถ้าอีเมลซ้ำกับบัญชีอื่น = ปฏิเสธ ไม่ merge)

---

## 3. ความปลอดภัย

### 3.1 การตรวจ ID token
| รายการ | การควบคุม |
|---|---|
| signature/iss | ให้ LINE `POST /oauth2/v2.1/verify` ตรวจ + ฟังก์ชันตรวจ `iss === "https://access.line.me"` ซ้ำ |
| aud | ส่ง `client_id = LINE_FOOD_LOGIN_CHANNEL_ID` และตรวจ `aud === channelId` ซ้ำ (กัน token ของ channel อื่น/token confusion) |
| exp | ปฏิเสธเมื่อ `exp*1000 <= now` ; เสนอเพดานอายุเพิ่ม (`now - iat` ไม่เกิน N นาที) ถ้า S0 พบว่า LIFF ออก token ใหม่ได้ถี่พอ |
| sub | regex `^U[0-9a-f]{32}$`; ใช้ค่าจาก claim ที่ LINE ยืนยันเท่านั้น (ไม่รับจาก body) |
| **nonce / replay** | **สมมติฐาน (ต้องยืนยัน S0):** verify endpoint ของ LINE รับ `nonce` ได้, แต่ LIFF อาจไม่ให้แอปกำหนด nonce ในการ login ถ้าทำไม่ได้: ID token ที่ถูกขโมย (ต้องมี XSS/เครื่องถูกยึด) ใช้ได้จนหมดอายุ ซึ่งความเสี่ยงใกล้เคียงการขโมย session อยู่แล้ว; ลดผลด้วย (1) เพดานอายุ token (2) บันทึก `last_login_at` และ rate limit ต่อ sub (3) CSP/ไม่ log token. ถ้า LIFF ผูก nonce ได้ ให้ใช้ nonce ที่ server ออก (challenge แบบใช้ครั้งเดียว) แทน — ต้องเพิ่ม action `challenge` และตารางสั้นอายุ (ตัดสินหลัง S0) |
| log | ห้าม log idToken, session, `sub` เต็ม, ชื่อ, รูป, body; log เฉพาะ event + รหัสเหตุผล + sub แบบ mask (`U***cdef` ตามแบบ `maskLineUserId` ใน branch guard) |

หมายเหตุ: payload ของ ID token (scope `profile`) มีชื่อ/รูป — ฟังก์ชันได้รับ PII นี้โดยธรรมชาติ ต้องไม่เก็บ ไม่ log ไม่ส่งต่อ

### 3.2 Abuse / session minting hijack
- **Endpoint สาธารณะที่ออก session = พื้นผิวโจมตีหลัก.** ข้อห้ามของโค้ด: ไม่มีเส้นทางที่ออก session โดยไม่ผ่าน verify สำเร็จ; ไม่มี debug/bypass/allow-all env; ไม่รับ `userId`/`email` จาก client; fail closed (error ใด ๆ = ไม่ออก session)
- **Rate limit (ก่อนเรียก LINE เพื่อกัน amplification):** L1 ต่อ isolate ในหน่วยความจำ (best effort) + L2 ในฐานข้อมูลต่อ IP (hash) เช่น 20 ครั้ง/นาที ผ่าน RPC reserve แบบ advisory lock; IP จาก header ของ proxy ที่เชื่อถือได้ (ยืนยันชื่อ header ที่แพลตฟอร์มตั้งใน S0 ห้ามเชื่อ `x-forwarded-for` ที่ client ใส่เอง); fail-safe = ปฏิเสธ (429) เมื่อ limiter พัง
- **จำกัดการสร้างบัญชีใหม่ทั้งระบบ:** นับจาก `line_login_identities.created_at` (เช่น ไม่เกิน 30 บัญชี/ชั่วโมง ปรับได้ด้วย env) เกิน → `429` และแจ้งเตือน (กันบัญชี LINE จำนวนมาก; ผู้โจมตีต้องมี LINE account จริงและเข้า LIFF ของเรา)
- **Kill switch ฝั่ง server:** `LINE_LOGIN_ENABLED` ไม่เป็น `"1"` → `503` ทันที (ต่างจาก flag ฝั่ง UI ที่เป็น build-time) นี่คือ rollback ปกติแทนการ disable provider
- **CORS:** allowlist origin (reuse `corsHeaders`) — ไม่ใช่ authorization (client นอก browser เรียกได้) การป้องกันจริงคือ ID token; ไม่ใช้ `*`
- **CSRF:** ไม่ใช้ cookie/ambient credential; login ไม่ผูกกับ session ปัจจุบัน; ถ้ามี session อยู่แล้วและ login เป็นอีกบัญชี → ใช้ logic Add Account เดิม (`account-registry`) ไม่เขียนทับเงียบ ๆ
- **Service role ในฟังก์ชันสาธารณะ:** ใช้เฉพาะ `auth.admin` + 2 ตารางนี้, ไม่มี dynamic SQL, ทุกค่าที่เข้า query ผ่าน regex/parameter; ไม่ส่ง error ดิบของ GoTrue/Postgres กลับ client
- **ผู้ใช้ถูกแบน/ลบ:** ถ้า `banned_until` หรือ verifyOtp ปฏิเสธ → `401` generic; ลบบัญชี = cascade ลบ mapping → login ครั้งถัดไปสร้างบัญชีใหม่ (เป็นพฤติกรรมที่ตั้งใจ ต้องบอกในนโยบาย)

### 3.3 ความสัมพันธ์กับ `line-link` (PR-4 guard)
- `line_links` (แจ้งเตือน) และ `line_login_identities` (ล็อกอิน) เป็นคนละเรื่อง **ห้ามใช้ `line_links` เป็นหลักฐานล็อกอิน** (เหตุผลข้อ 2.2-A)
- หลังล็อกอิน LINE ใน LIFF, auto-link ของ ZOKY-LINE-001 จะเรียก `line-link` ด้วย `sub` เดียวกัน: ถ้าบัญชี Google เดิมถือ `line_links` ของ sub นั้นอยู่ guard ต้องตอบ `already_linked_elsewhere` (ไม่ย้ายเงียบ ๆ) ผู้ใช้ใหม่ไม่ได้แจ้งเตือน LINE จนกว่าจะยืนยันย้ายอย่างชัดเจน → **PR-4 guard (branch `claude/line-link-guard`) ต้อง deploy ก่อนเปิด LINE Login** (เป็นเงื่อนไขเดิม HIGH)
- `line-link` ต้อง **ไม่** รับ session จาก flow นี้แล้วทำสิ่งต่างจากผู้ใช้ปกติ (ผู้ใช้ LINE-only เป็นผู้ใช้ Supabase ปกติ)

### 3.4 Recovery, เพิกถอน, privacy
- **LINE-only ไม่มีอีเมลกู้บัญชี:** กลับเข้าได้ด้วย LINE เดิม (`sub` เดิม). ถ้าผู้ใช้เสีย LINE account → `sub` ใหม่ → บัญชีใหม่ (ออเดอร์เก่าเข้าไม่ได้) → ต้องมีทาง support-assisted (นอกขอบเขต) และ prompt เพิ่มอีเมลจริงหลังออเดอร์แรก (P2) — ยอมรับเป็นความเสี่ยง MEDIUM โดย Founder
- **ห้ามให้ unlink LINE login** ถ้าเป็นวิธีล็อกอินเดียวของบัญชี
- **เพิกถอน:** logout ปกติ; เหตุฉุกเฉิน = kill switch + (ด้วยการอนุมัติ) revoke sessions ของ user ที่ `app_metadata.zoky_login='line'` ผ่าน admin API; ไม่ลบ `auth.users` ใน rollback ใด ๆ
- **Privacy:** เก็บ `sub` (ตัวระบุ personal) + เวลาสร้าง/ล็อกอินล่าสุด เท่านั้น; ไม่เก็บชื่อ/รูป; ต้องอัปเดตนโยบายความเป็นส่วนตัวก่อนเปิด (ใช้ LINE userId เพื่อเข้าสู่ระบบ) ; ตรวจ/ออกแบบการลบบัญชีให้ลบ mapping (cascade) — **ยังไม่ได้ตรวจว่าแอปมีปุ่มลบบัญชีหรือไม่**

---

## 4. การเปลี่ยนแปลงฝั่ง Web

### 4.1 พฤติกรรม
- ปุ่ม "เข้าสู่ระบบด้วย LINE" แสดงเมื่อ **ครบทั้งหมด:** `NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED === "1"` (ปิดเป็นค่าเริ่มต้น; ไม่รับ `"test"` อีกต่อไป เพราะ browser ปกติไม่มี LIFF ID token) + UA `Line/` + `liff.isInClient()` + `liff.getIDToken()` ไม่ว่าง
- กดแล้ว **ไม่ navigate**: เรียก `line-login` → `setSession` → `registerCurrentAccount` → `window.location.replace("/food")` (เส้นทางเดียวกับ login อีเมลใน `food-auth.tsx` `submit()`); ไม่ล้าง `wynos-food-guest-basket-v1`, `rememberSharedFoodStore`, `zoky.line-autolink.v1` จึงคืนตะกร้า guest/ปลายทางด้วยกลไกเดิม (`safeLineDestination` ยังเป็นด่านเดียวของปลายทาง)
- state: loading / error (token หมดอายุ → ขอ token ใหม่ผ่าน LIFF แล้วลองใหม่ 1 ครั้ง) / disabled (429/503 → ข้อความสุภาพ เสนออีเมล/รหัสผ่าน) ; a11y: label, focus, disabled; mobile-first; ข้อความ copy D-4 ("LINE จะสร้างบัญชีใหม่ ถ้าเคยใช้ Google ให้เข้าด้วย Google")
- ใช้ client เดิม `getSupabaseBrowserClient()` (multi-account storage key) — ต้องยืนยันใน S0 ว่า `setSession` ทำงานกับ slot `getActiveAccountStorageKey()` ถูกต้อง
- ชื่อ fallback ที่ UI: ไม่แสดงอีเมลสังเคราะห์ ผ่าน `realEmailOf`

### 4.2 Reuse / ทิ้งจากงาน T1 (branch `claude/zoky-line-login-impl`, HEAD `87dd546a`)
| ชิ้นงาน T1 | การจัดการ |
|---|---|
| `web/components/food/line-login-button.tsx` (UI, สถานะ slot, CSS `wf-auth-line-login`) | **Reuse** เปลี่ยน `onStart` + เงื่อนไขแสดง (ตัดโหมด `test`) |
| `isLineLoginEnabled()` ใน `web/lib/line-liff.ts` | **Reuse** แต่เหลือเฉพาะ `=== "1"` |
| `isLineLoginTestMode`, `LINE_OAUTH`, `LINE_LOGIN_PROVIDER = "custom:line"` | **ทิ้ง** |
| generalise `startOAuth(client, redirectTo, config)` ใน `google-pwa-oauth.ts` | **ทิ้ง** (ไม่มี OAuth redirect แล้ว; ถ้าไม่ใช้ที่อื่นให้คืน `startGoogleOAuth` เดิมเพื่อลด diff/regression) |
| `line()` ใน `food-auth.tsx` (signInWithOAuth) | **แทนที่** ด้วย handler ใหม่ |
| ข้อความ callback เป็นกลางต่อ provider (`/food/auth/callback`) | ไม่จำเป็น — **ไม่นำมา** (ไม่มี callback ใหม่) |
| test harness T-A4 (`safeLineDestination` payload), flag ปิดไม่มีปุ่ม, อีเมล null | **Reuse** ปรับ |
| workflow ข้าม build cache ของ staging (`0577b36a`) | Reuse ถ้ายังจำเป็น |
| Supabase provider `custom:line` + Callback URL ของ Supabase ใน LINE channel + Redirect URL ของ staging | **เก็บกวาด** ภายใต้การอนุมัติ (ข้อ 7) — ลด R-7/R-2 (email auto-link ระดับ project) เมื่อเลิก T1 |

ควรเริ่ม branch ใหม่จาก baseline ที่ Founder ระบุ (ไม่ใช่ต่อบน T1 ทั้งก้อน เพราะ diff ของ T1 กว้างและมีไฟล์ที่ไม่เกี่ยว) แล้ว cherry-pick เฉพาะชิ้นที่ reuse

---

## 5. ข้อจำกัดการทดสอบและแผนทดสอบจริง

**ข้อเท็จจริง:** LIFF ของลูกค้า `2012311758-OEhTuU5V` มี endpoint ที่ลงทะเบียน `https://food.wynos.online/line` (APPROVALS 2026-11-05) ชี้ production; staging (Vercel preview/ติด Vercel Authentication) เปิดใน LIFF จริงไม่ได้ และ **staging ใช้ Supabase project เดียวกับ production** (APPROVALS 2026-11-08) ดังนั้นการทดสอบ LIFF จริง = เขียนข้อมูลทดสอบลง DB production เสมอ

| ทาง | วิธี | ข้อดี | ความเสี่ยง/ต้นทุน |
|---|---|---|---|
| **T-1 LIFF app ทดสอบแยก (แนะนำเป็นด่านแรก)** | เพิ่ม LIFF app ที่ 2 ใน channel เดิม (สถานะ Developing) ชี้ endpoint ของโดเมนทดสอบที่เปิดสาธารณะได้ (เช่น โดเมนย่อยเฉพาะ staging ที่ไม่เปิด Vercel Authentication) ; build ของ preview ใช้ `NEXT_PUBLIC_LIFF_ID_FOOD` ของ LIFF ทดสอบ | `aud` = channel เดิม ฟังก์ชัน production ไม่ต้องรับ channel เพิ่ม; เห็น LIFF จริงบน iOS/Android; Developing → เฉพาะ admin/tester เปิดได้ | ต้องมีโดเมนทดสอบสาธารณะ (DNS/Vercel domain = การเปลี่ยน infra → อนุมัติ; Vercel Authentication เปิดไม่ได้ใน WebView; bypass-cookie ผ่าน query ใช้ไม่ได้เพราะ LIFF endpoint เปิดตายตัว); โค้ดที่ยังไม่รีวิวเปิดสาธารณะ (flag ปิดบน production แต่ preview ต้องเปิด); เพิ่ม origin ใน `LINE_LOGIN_EXTRA_ORIGINS` (ขยาย CORS ของฟังก์ชัน production); เขียน DB production ด้วยบัญชี LINE ทดสอบ |
| T-2 Canary บน production | deploy ปกติ แต่ปิดทั้ง UI flag และ kill switch; เปิดเฉพาะ allowlist ฝั่ง server (`LINE_LOGIN_CANARY_SUBS` — รายการ sub ของ LINE ทดสอบของ Founder, ตั้งผ่าน dashboard) ; ฟังก์ชันตอบ 403 สำหรับ sub นอกรายการ | ทดสอบใน LIFF/โดเมน/UA จริงที่สุด; ตัวกรองอยู่ฝั่ง server (ไม่ใช่แค่ UI) | ต้อง production deploy + Founder gate; โค้ด mint อยู่บน production ตั้งแต่ต้น (ถ้า kill switch ปิด → 503); ต้องรู้ `sub` ของผู้ทดสอบก่อน (ใช้ S0 ที่ฟังก์ชันโหมด dry-run คืนค่า mask หรือดูจาก LINE console ไม่ได้) ; ถ้าช่อง allowlist ผิด = ล็อกผู้ทดสอบ |
| T-3 Channel ทดสอบแยก (aud แยก) | LINE Login channel ทดสอบ + Supabase branch/project ทดสอบ | แยกข้อมูลโดยสมบูรณ์ | ต้องสร้าง Supabase branch/project (ค่าใช้จ่าย; org เกินโควตา — risk ที่เปิดอยู่ในสถานะงาน) และ `aud`/`sub` คนละ Provider → ผล `sub` ไม่เทียบกับ production; ฟังก์ชันต้องรับ channel เพิ่ม (ถ้าทำใน project เดียวกัน = ขยายสิ่งที่ยอมรับ ไม่แนะนำ) |
| T-0 Offline | Deno tests + fake fetch/fake admin client (แบบ `_lib.test.ts`); Supabase **local stack** (`supabase start`) เพื่อพิสูจน์พฤติกรรม GoTrue (createUser/generateLink/verifyOtp, อีเมลสังเคราะห์, setSession) โดยไม่แตะ production | ไม่มีความเสี่ยงต่อข้อมูลจริง | ไม่ครอบคลุม LIFF จริง; ต้องมี Docker (ยังไม่ได้ตรวจว่า environment ของทีมมี) |

**ลำดับที่แนะนำ:** T-0 (ทุก PR) → Spike S0 ด้วย T-1 หรือ T-2 ตามที่ Founder เลือก → staging matrix เต็มบน T-1 → canary T-2 ก่อนเปิดทั่วไป. ข้อมูลทดสอบ: บัญชี LINE ทดสอบเท่านั้น; บันทึกแถวที่สร้างเพื่อให้ Founder อนุมัติลบ (ห้ามลบเอง)

---

## 6. Threat model, Test matrix, Severity

### 6.1 Threat model
| # | ภัย | การควบคุม |
|---|---|---|
| X-1 | ID token ปลอม/ของ channel อื่น/หมดอายุ/iss ผิด | verify กับ LINE + ตรวจ iss/aud/exp ซ้ำ |
| X-2 | ส่ง `sub`/`userId`/`email` ปลอมใน body | ไม่อ่านค่าเหล่านั้น; มี test |
| X-3 | Replay ID token ที่ขโมยมา | เพดานอายุ + rate limit + (nonce ถ้าทำได้); ความเสี่ยงคงเหลือ ระบุใน 3.1 |
| X-4 | Mint session ให้ผู้ใช้ผิดคน (bug mapping) | PK/unique, resolve จาก `sub` เท่านั้น, test หลายบัญชี/race |
| X-5 | Account takeover ผ่านอีเมล / pre-account takeover บนอีเมลสังเคราะห์ | อีเมล UUID สุ่ม; ไม่ค้นด้วยอีเมล; `.invalid`; ปิด provider `custom:line` (ไม่มีอีเมลจริงจาก LINE) |
| X-6 | สร้างบัญชีจำนวนมาก / DoS ผ่าน amplification ไปหา LINE | rate limit ก่อน verify + cap บัญชีใหม่ + kill switch |
| X-7 | service role รั่วผ่านฟังก์ชันสาธารณะ (log/error/response) | ไม่ log; error generic; โค้ดเล็ก; review โดย QA |
| X-8 | race สร้างผู้ใช้ซ้ำ | unique + compensating delete |
| X-9 | auto-link (`line_links`) กลายเป็น backdoor ล็อกอิน | แยกตาราง; ไม่ใช้ `line_links` ล็อกอิน; link flow ต้องกดยืนยัน |
| X-10 | ผู้ใช้ LINE-only ถูกล็อก (LINE channel ระงับ/kill switch) | kill switch เป็นทางปกติ (ไม่ใช่ disable provider); แผน recovery P2; session เดิมยังอยู่ |
| X-11 | อีเมลสังเคราะห์รั่วเข้า Stripe/UI/log | `realEmailOf`, แก้ `food-stripe-checkout` |
| X-12 | PII (ชื่อ/รูปใน token) รั่วใน log/storage | ไม่ log/ไม่เก็บ |
| X-13 | ผู้ใช้ LINE ได้สิทธิ์ Merchant/Admin | ไม่มีการให้สิทธิ์; ตรวจ allowlist Merchant/Admin ผูก email หรือ uid (**ยังไม่ได้ตรวจ**) |
| X-14 | XSS บน origin ลูกค้าขโมย ID token/session | CSP/ของเดิม; token ไม่ถูกเก็บ storage โดยโค้ดเรา |
| X-15 | CORS/Origin ผิด, preview origin ค้างใน allowlist | allowlist เข้ม + ลบ origin ทดสอบหลังจบ |
| X-16 | ผู้ใช้ session ซ้อนข้ามบัญชี (Add Account) | ใช้ account-registry เดิม |

### 6.2 Test matrix (ต้องผ่านก่อน release; ทุกข้อใช้บัญชี/ข้อมูลสังเคราะห์)
| ID | กรณี | ผลที่ต้องได้ | Severity ถ้าล้ม |
|---|---|---|---|
| T-L1 | ID token ปลอม/ลายเซ็นเสีย | 401 ไม่มี session ไม่มี user ใหม่ | CRITICAL |
| T-L2 | `aud` ของ channel อื่น (เช่น Merchant/คนละ Provider) | 401 | CRITICAL |
| T-L3 | `iss` ผิด / `exp` ผ่านแล้ว / LINE ตอบ 200 แต่ exp ย้อน | 401 | CRITICAL |
| T-L4 | body มี `lineUserId`/`userId`/`email`/`sub` ปลอมควบ token ที่ถูก | ใช้เฉพาะ sub จาก token; ค่าที่ส่งมาถูกเมิน | CRITICAL |
| T-L5 | ไม่มี idToken / รูปแบบผิด / >4096 / body >8KB / method ผิด | 400/405 ไม่เรียก LINE | MEDIUM |
| T-L6 | token ใช้ซ้ำ (replay) ภายใน/หลังเพดานอายุ; nonce ผิด (ถ้าใช้) | ตามนโยบายใน 3.1; บันทึกพฤติกรรมจริง | HIGH |
| T-L7 | LINE ล่ม/timeout ระหว่าง verify | ไม่ออก session; 401/500 generic | CRITICAL |
| T-L8 | sub ใหม่ | สร้าง user 1 + mapping 1 + profile; session ใช้งานได้ | HIGH |
| T-L9 | sub เดิม login ซ้ำ (หลายครั้ง/หลายเครื่อง) | ได้ user เดิมเสมอ ไม่สร้างใหม่ | HIGH |
| T-L10 | 2 คำขอพร้อมกันของ sub ใหม่ | เหลือ user 1/mapping 1; ทั้งสองคำขอได้ session ของ user เดียวกัน; ไม่มี user กำพร้า | HIGH |
| T-L11 | **อีเมลชนกัน:** บัญชี Google/อีเมลจริงที่อีเมลเหมือนอีเมลที่ LINE (ถ้ามี) / ผู้โจมตี `signUp` ด้วยรูปแบบอีเมลสังเคราะห์ก่อน | ไม่ merge; user คนละ id เสมอ | CRITICAL |
| T-L12 | ตรวจ `auth.users`/identities ของ user LINE: อีเมลเป็นสังเคราะห์, `app_metadata.zoky_login='line'`, ไม่มีรหัสผ่าน, ลืมรหัสผ่านไม่ได้ผล | ตามสเปก | HIGH |
| T-L13 | rate limit: ยิงเกินโควต่อ IP; cap บัญชีใหม่/ชั่วโมง; limiter พัง | 429 ไม่เรียก LINE; fail-safe | HIGH |
| T-L14 | kill switch (`LINE_LOGIN_ENABLED` ไม่ใช่ "1") | 503 ทันที; session เดิมยังใช้ได้; Google/อีเมลปกติ | HIGH |
| T-L15 | log/response/network/bundle: ไม่มี idToken, session, sub เต็ม, ชื่อ, รูป, service key | สะอาด (Edge logs + browser) | HIGH |
| T-L16 | CORS: origin นอก allowlist; preflight; ไม่มี `*` | ไม่ได้ ACAO | MEDIUM |
| T-L17 | web: flag ปิด → ไม่มีปุ่ม/ไม่เรียกฟังก์ชัน; นอก LINE/ไม่ใช่ `isInClient` → ไม่มีปุ่ม | ตามสเปก | MEDIUM |
| T-L18 | ตะกร้า guest + ร้านที่เปิดอยู่ + `zoky.line-autolink.v1` หลัง login | ยังอยู่ ไปปลายทางผ่าน `safeLineDestination` เท่านั้น; payload T-A4 ทั้งชุด | HIGH |
| T-L19 | ผู้ใช้ LINE เรียก API ตรงของ Merchant/Admin / เมนู Merchant | ไม่ได้สิทธิ์ | HIGH |
| T-L20 | ชำระเงิน Stripe ด้วยผู้ใช้อีเมลสังเคราะห์ (หลังแก้ `customer_email`), account switcher, ตั้งค่าบัญชี, แจ้งเตือน | ไม่ crash ไม่แสดง `.invalid`/`null` | HIGH |
| T-L21 | ผู้ใช้ถูกแบน / ลบบัญชีแล้ว login ซ้ำ | แบน: ปฏิเสธ; ลบ: สร้างใหม่ ไม่มีข้อมูลเดิม | MEDIUM |
| T-L22 | Add Account (มี session บัญชีอื่นอยู่) ด้วย LINE | ใช้ registry เดิม ไม่เขียนทับ | MEDIUM |
| T-L23 | `line-link` + guard: sub ที่ `line_links` อยู่กับบัญชี Google เดิมแล้ว login LINE (บัญชีใหม่) | auto-link ถูกปฏิเสธ `already_linked_elsewhere`; บัญชีเดิมไม่เสียแจ้งเตือน (ต้อง deploy guard ก่อน) | HIGH |
| T-L24 | iOS + Android LIFF จริง: `getIDToken` บน `/food/login`, บน origin ที่ลูกค้าใช้ (`food.` vs `zoky.`), token หมดอายุระหว่างหน้า, LINE Desktop | สำเร็จหรือมี fallback ชัดเจน | HIGH (บล็อกฟีเจอร์) |
| T-L25 | regression: Google/อีเมลเดิม (browser, iOS PWA), `/line` entry, friendship prompt | ไม่เปลี่ยน | HIGH |
| T-L26 | link flow (P2) เมื่อทำ: ไม่มี JWT / JWT ผู้อื่น / sub ถือโดยบัญชีอื่น | 401/409 ไม่ย้าย ไม่ merge | CRITICAL |

เกณฑ์ผ่าน: ไม่มี CRITICAL; HIGH แก้แล้วหรือ Founder รับความเสี่ยงเป็นลายลักษณ์อักษร; MEDIUM มี owner; มีหลักฐาน (วันที่ ผู้ทดสอบ เครื่อง/OS ผล) โดยไม่มีข้อมูลส่วนตัวจริง

### 6.3 Severity ของความเสี่ยงหลัก (สรุป)
CRITICAL: verify หละหลวม (aud/iss/exp/sub จาก client), merge ด้วยอีเมล, mint ผิดคน, service key รั่ว. HIGH: replay (ถ้าไม่มี nonce), สร้างบัญชีมหาศาล/ไม่มี rate limit, race สร้างซ้ำ, อีเมลสังเคราะห์รั่วเข้าการชำระเงิน, log รั่ว, ไม่มี kill switch, ไม่ deploy guard `line-link` ก่อน, ผู้ใช้ LINE-only ไม่มีแผน recovery. MEDIUM: CORS/origin ค้าง, orphan user, ข้อมูลทดสอบใน DB production. LOW: ข้อความ error/enumeration, copy

---

## 7. รายการที่ต้องให้ Founder อนุมัติ (บันทึกที่ `.wyn/company/APPROVALS.md` รูป `APPROVAL_REQUIRED` แยกรายการ)

| # | เรื่อง | Proposed change / Benefit | Risk | Files affected | Rollback | คำแนะนำ |
|---|---|---|---|---|---|---|
| F-1 | **Authentication Architecture Change:** เลิก T1, อนุมัติเส้นทางออก session เอง (T2 แบบ M1) | แก้ปัญหา LIFF ที่ T1 แก้ไม่ได้บน iOS | endpoint สาธารณะที่ออก session (สูงสุดของระบบ) | `supabase/functions/line-login/*`, `supabase/config.toml`, `web/*` | kill switch `LINE_LOGIN_ENABLED`; unset flag + redeploy | อนุมัติแบบมีเงื่อนไข: ผ่าน S0 และ T-L1…T-L4, T-L10, T-L11, T-L13…T-L15 |
| F-2 | Edge Function ใหม่ `line-login` (`verify_jwt=false`) deploy production | — | service role ใน function สาธารณะ | ดังบน | redeploy/ปิด function | ต้องมี QA review โค้ดก่อน deploy |
| F-3 | **Migration additive:** `line_login_identities` (+ rate-limit table/RPC) บน project เดียวกับ production | unique atomic, audit, cascade | schema production เปลี่ยน; ข้อมูลทดสอบอยู่ DB เดียวกัน | `supabase/migrations/*_zoky_line_login.sql` + rollback + test shell | drop ตาราง (ได้เมื่อไม่มี LINE-only user) | อนุมัติ; ไม่ใช้ `line_links` |
| F-4 | Secrets/ค่า config: reuse `LINE_FOOD_LOGIN_CHANNEL_ID`, service role (ที่มีอยู่); ค่าใหม่ไม่ลับ `LINE_LOGIN_ENABLED`, `LINE_LOGIN_EXTRA_ORIGINS`, (canary) `LINE_LOGIN_CANARY_SUBS` | — | Founder เป็นผู้ตั้งค่าใน Dashboard เอง (AI ไม่อ่าน/ไม่ขอค่า) | Supabase function secrets | unset | อนุมัติ |
| F-5 | แก้ `food-stripe-checkout` ไม่ส่ง `customer_email` สังเคราะห์ | กันชำระเงินล้ม | แก้ Edge production ที่เกี่ยวกับเงิน | `supabase/functions/food-stripe-checkout/index.ts` (+test) | redeploy เวอร์ชันก่อน | อนุมัติ (แคบ) |
| F-6 | เก็บกวาด T1: disable provider `custom:line`, ลบ Callback URL ของ Supabase ใน LINE channel, ลบ Redirect URL staging, ตัดสินใจเรื่องบัญชีทดสอบ `custom:line` ที่เคยสร้าง (ไม่ลบเอง) | ลดพื้นที่โจมตี/ความเสี่ยง email auto-link ระดับ project | ถ้าเคยมีผู้ใช้จริงผ่าน T1 จะล็อก (ตามสถานะ ยังไม่เปิดลูกค้า) | Dashboard เท่านั้น | enable กลับ | แนะนำ หลัง S0 ผ่าน |
| F-7 | LIFF/LINE console: ยืนยัน scope = `openid` (+`profile` ถ้าจำเป็น) **ไม่เปิด email**; ตรวจสถานะ channel (Developing/Published); เพิ่ม LIFF ทดสอบ; ตัดสินเรื่อง endpoint โดเมน (`food.` vs `zoky.`) | เงื่อนไขทดสอบ/ความถูกต้อง | Published = ลูกค้าทั่วไปได้ token | Founder ทำเอง | — | ต้องทำก่อน S0 |
| F-8 | โครงสร้างทดสอบ: โดเมน/สภาพแวดล้อม staging สาธารณะสำหรับ LIFF ทดสอบ (T-1) หรือ canary production (T-2) | ทดสอบ LIFF จริง | infra/ค่าใช้จ่าย; โค้ดยังไม่รีวิวเปิดสาธารณะ | Vercel/DNS | ลบโดเมน | Founder เลือก T-1 หรือ T-2 |
| F-9 | ยอมรับความเสี่ยงเหลือ: replay (ถ้า LIFF ไม่รองรับ nonce), LINE-only ไม่มีอีเมลกู้, ผู้ใช้ Google เดิมได้บัญชีใหม่ (D-4) | — | MEDIUM–HIGH | — | — | บันทึกเป็นลายลักษณ์อักษรหลัง S0 |
| F-10 | นโยบายความเป็นส่วนตัว (LINE userId) ก่อน Release; deploy guard `line-link` ก่อน Release | — | — | policy, `line-link` | — | บังคับก่อนเปิด |
| F-11 | design B (server cart) ยัง **ไม่อนุมัติ** ต่อไป | — | — | — | — | ยืนยัน |

ทุก commit/push/merge/deploy ต้องขออนุมัติตาม Git Safety; production release ผ่าน Release Gates เดิม

---

## 8. แผน implement เป็น PR เล็ก ๆ

**S0 — Spike (ก่อนทุก PR โค้ด; ไม่มีโค้ดเข้า main):** ทำกับ Supabase local + LIFF ทดสอบ ตอบ 8 ข้อ: (1) `getIDToken()` ใช้ได้บน `/food/login` และบน origin ที่ลูกค้าเข้าจริง/ต้องย้าย endpoint หรือไม่ (2) LIFF ผูก nonce ได้ไหม + verify รับ nonce ไหม + อายุ/การต่ออายุ token (3) GoTrue: `createUser` ไม่มีอีเมลได้ไหม; clear email ได้ไหม (4) generateLink+verifyOtp server-side → session ใช้งานได้, `app_metadata.provider(s)`/identity ที่เกิด (5) `setSession` กับ multi-account storage key (6) header IP ที่เชื่อถือได้บน Supabase Edge (7) `signInWithIdToken` ยังไม่รองรับ custom จริงไหม (docs ล่าสุด) (8) `profiles` trigger / `food_customer_access_enabled()` ทำงานกับ user นี้. ผลลัพธ์: บันทึกสั้น ๆ + ตัดสิน go/no-go

| PR | เนื้อหา | ไฟล์หลัก | ทดสอบ | Gate |
|---|---|---|---|---|
| PR-0 | บันทึก APPROVAL_REQUIRED F-1…F-11 + ADR (supersede T1) | `.wyn/company/APPROVALS.md`, docs | – | Founder |
| PR-1 | Migration + rollback + SQL test (identity table, rate-limit table/RPC) — **ไม่ apply** จนกว่าอนุมัติ | `supabase/migrations/*`, `supabase/rollbacks/*`, `supabase/tests/*` | local DB: unique/RLS/cascade | Founder + CTO |
| PR-2 | `line-login/_lib.ts` (parse, verify+nonce, resolve/create ด้วย store/admin interface, rate-limit decision, mask) + `_lib.test.ts` | `supabase/functions/line-login/_lib*.ts`, (optional nonce param ใน `line-link/_lib.ts`) | Deno: T-L1–T-L10 แบบ mock | Implementation |
| PR-3 | `index.ts` + `config.toml` entry; ปิดโดยค่าเริ่มต้น (kill switch ไม่ตั้ง = 503); ยังไม่ deploy | `supabase/functions/line-login/index.ts`, `supabase/config.toml` | local stack integration T-L8–T-L15 | QA & Security |
| PR-4 | Web: helper เรียกฟังก์ชัน, ปุ่ม/flag, `realEmailOf`, ข้อความ; tests | `web/lib/line-liff.ts`, `web/lib/line-login.ts`(ใหม่ ถ้าจำเป็น), `web/components/food/{food-auth,line-login-button}.tsx`, `web/lib/account-registry.ts`, `web/lib/auth-repository.ts` | node --test, lint, typecheck, build; T-L17, T-L18, T-L20 | Implementation |
| PR-5 | แก้ `food-stripe-checkout` (`customer_email`) + test | `supabase/functions/food-stripe-checkout/*` | Deno | Founder (production Edge) |
| PR-6 | (มีอยู่แล้ว) deploy guard `line-link` ตาม branch `claude/line-link-guard` | – | T-L23 | Founder |
| Staging gate | LIFF ทดสอบ (T-1) หรือ canary (T-2) รัน T-L1…T-L25 บน iOS+Android | – | หลักฐานอุปกรณ์จริง | QA & Security + Staging |
| PR-7 | privacy policy + copy | policy | review | Founder |
| Release | Founder สั่ง: deploy function + migration (ถ้ายังไม่ทำ) → ตั้ง `LINE_LOGIN_ENABLED=1` → ตั้ง flag UI=1 + redeploy → smoke | – | smoke: login, ตะกร้า, ชำระ, log สะอาด | Founder → Production Gate |
| PR-8 (P2) | link flow + เพิ่มอีเมลจริงให้ผู้ใช้ LINE-only | – | T-L26 | แยกอนุมัติ |
| Cleanup | F-6 | Dashboard | – | Founder |

Rollback (เบา→หนัก): (1) unset `LINE_LOGIN_ENABLED` = หยุดออก session ทันที (2) unset flag UI + redeploy / Vercel rollback ตามกติกา Owner (3) redeploy function เวอร์ชันก่อน/ลบ function (4) ไม่ลบ `auth.users`/mapping/profiles ในทุกชั้น; ห้าม rollback เองตาม RULES.md — รายงาน Owner

---

## 9. สรุป: ตรวจแล้ว / ไม่ได้ตรวจ / สมมติฐาน / คำแนะนำ

**ตรวจแล้ว (จากไฟล์จริง):** AGENTS.md, `TEAM.md`, `SECURITY_RULES.md`, `.wyn/company/RULES.md`; เอกสาร design เดิมและ design-review (ข้อกำหนด 12 ข้อ, T-A1…T-A19), `real-flow-code-analysis.md`, STATUS 2026-11-08, ท้าย APPROVALS; `supabase/functions/line-link/{_lib,index}.ts` และ migration `20261031120000_zoky_line_links.sql` (RLS, unique, ผู้เขียน); diff branch `claude/line-link-guard` (`linkLineUser`, `maskLineUserId`, 409); `supabase/config.toml` (verify_jwt ของ line-link/webhook); pattern rate limit (`migrations_wyn149_location_search_rate_limit.sql`); การใช้ `user.email` ใน Edge Functions (`food-stripe-checkout:169`, `merchant-stripe-connect:555`) และ web; worktree T1 (`food-auth.tsx`, `line-liff.ts`, `line-entry.tsx`, `browser.ts`, `app/food/auth/callback/page.tsx`, `line-login-button.tsx`, `google-pwa-oauth.ts` exports)

**ไม่ได้ตรวจ:** ไม่ต่อ Supabase/LINE/Vercel จริง ไม่อ่าน secrets/env; ไม่รันโค้ด/test/build; ไม่ได้ทดสอบ LIFF บนเครื่องจริง; ไม่ได้ตรวจสถานะ channel (Developing/Published), scope ของ LIFF, plan/Auth settings, rate limits ของ Auth, การมีปุ่มลบบัญชี, allowlist Merchant/Admin ผูก email หรือ uid, ว่า Edge Function จริงบน production ตรงกับ source; ไม่ได้ตรวจ `food_customer_access_enabled()` ว่าเงื่อนไขอะไร

**ข้อสันนิษฐาน (ต้องพิสูจน์ใน S0):** (1) GoTrue ไม่มี API ออก session ให้ user ที่ไม่มีอีเมล (จึงต้องอีเมลสังเคราะห์) (2) `getIDToken()` ใช้ได้บนหน้า `/food/login` และบน origin ที่ลูกค้าอยู่ — endpoint ที่ลงทะเบียนคือ `food.wynos.online/line` ส่วนโดเมนหลักคือ `zoky.wynos.online` (storage/session แยกกัน) (3) LIFF ผูก nonce ได้และ verify endpoint รับ `nonce` (4) `signInWithIdToken` ยังไม่รองรับ custom provider (5) `admin.createUser` รับ `app_metadata` และ verifyOtp magiclink ไม่สร้างผลข้างเคียงที่ทำให้ผู้ใช้ LINE เป็น "email/password user" (6) channel เดิมยัง Developing ทำให้เป็น canary ธรรมชาติ (ยังไม่ยืนยัน) (7) header IP ที่เชื่อถือได้มีบน Edge

**คำแนะนำตรง ๆ — ควรทำต่อหรือไม่:**
**ควรทำต่อ แต่แบบมีประตู ไม่ใช่ลุย implement ทันที.** เหตุผล: นี่เป็นทางเดียวที่ตอบปัญหาจริง (ลูกค้าใน LIFF ล็อกอินไม่ได้) โดยไม่พึ่ง redirect ที่ล้มแล้ว และ rollback ทันทีด้วย kill switch ฝั่ง server ได้ดีกว่า T1 แต่ต้นทุนคือโค้ดออก session เองที่เปิดสาธารณะ ซึ่งเป็นความเสี่ยงสูงสุดที่ทีมเคยเลี่ยง. ขั้นแรกให้ทำเฉพาะ **S0 (1–2 วัน, ไม่มีโค้ดเข้า main)** ถ้า (1) หรือ (2) ล้ม (ID token ใช้ไม่ได้บน origin ลูกค้า / ไม่มี nonce และ Founder ไม่ยอมรับ replay) ให้หยุดและเลือกทางที่ถูกกว่า: ให้ลูกค้าใน LIFF ใช้อีเมล/รหัสผ่านที่ใช้ได้อยู่แล้วพร้อม guidance เดิม (ลดแรงเสียดทานด้วย UX) แทนการสร้าง auth path ใหม่ ถ้า S0 ผ่านค่อยขออนุมัติ F-1…F-5 และไล่ PR ตามข้อ 8 อย่าเปิดทั่วไปก่อนผ่านเครื่องจริง iOS+Android และ deploy guard `line-link` แล้ว
