# ZOKY-LINE-002 — Technical Design: LINE Login (ลูกค้า food) และ Server-side Cart Draft

Status: **DRAFT สำหรับ CTO review และ Founder design-approval รอบที่สอง — ยังไม่อนุมัติให้ implement**
Authors: WYN Software Architect + Database Engineer (2026-11-07)
Task: `.wyn/tasks/proposed/ZOKY-LINE-002-order-flow-simplification.md` (Founder decisions D-2, D-3, D-4, D-5, D-6)
ขอบเขต: ลูกค้า (`food`) เท่านั้น ไม่รวม Merchant (D-5)

> เอกสารนี้เป็นการออกแบบเท่านั้น ไม่มีการแก้ source code, ไม่มี migration จริง, ไม่ได้เชื่อมต่อ DB/secrets/env ใด ๆ SQL ในหัวข้อ 3 เป็น **ร่างเพื่อ review** ไม่ใช่ไฟล์ migration
> ทั้งสองส่วนเป็น (1) Authentication Architecture Change และ (2) DB/PII ใหม่ ต้องผ่าน Founder gate แยกกัน (หัวข้อ 6) และตาม task ต้อง **เริ่มหลังวัด baseline usability test**

## 0. สรุปสำหรับผู้ตัดสินใจ

1. **LINE Login: แนะนำ T1** (Supabase Auth custom OIDC provider ชื่อ `custom:line`) เพราะ session, PKCE, state, nonce และการ verify ID token ผ่าน JWKS ทำโดย Supabase Auth ไม่ต้องเขียนโค้ดออก session เอง
   - เอกสาร Supabase ทางการระบุว่า custom OIDC provider มีอยู่ใน hosted project (Free plan สูงสุด 3 provider) ตรวจแล้วดูหัวข้อ 1.2
   - **เงื่อนไขสำคัญ:** ห้ามขอ scope `email` จาก LINE และเปิด `email_optional` เพื่อไม่ให้ Supabase "automatic linking by email" ไป merge บัญชีเอง ซึ่งขัดกับ D-4
2. **T2 (Edge Function mint session) ไม่แนะนำ** — เป็นโค้ดออก session เอง ความเสี่ยงสูงสุด ใช้เป็น fallback เฉพาะถ้า T1 ไม่ผ่านการทดสอบบน staging และต้องกลับมาขออนุมัติใหม่
3. **T3 (ใช้ `line_links` เป็นตัว login)** ทำไม่ได้โดยไม่มี T2 เพราะ `line_links` ไม่ใช่ identity ของ Supabase Auth — ใช้ได้เฉพาะเป็น "ตัวบอกใบ้ให้ UI เสนอการผูกบัญชี" ไม่ใช่ตัวให้ session
4. **ผู้ใช้ Google เดิม** ต้องเข้าบัญชีเดิมด้วย Google หนึ่งครั้ง แล้วกด "ผูก LINE" (`linkIdentity`) จึงจะ login ด้วย LINE เข้าบัญชีเดิมได้ ถ้าไม่ผูกจะได้บัญชีใหม่ (ตรง D-4)
5. **Cart draft ฝั่ง server**: ทำเป็น "ซองส่งต่อตะกร้าแบบใช้ครั้งเดียว" (one-time handoff envelope) ไม่ใช่ตะกร้าถาวรของผู้ใช้ — เข้าถึงผ่าน token สุ่ม 256 บิต (เก็บแค่ hash) หมดอายุ 15 นาที ถูกลบทันทีที่ claim ไม่มีเบอร์/ที่อยู่ ไม่มี policy ให้ client อ่านตารางตรง ๆ ทุกอย่างผ่าน Edge Function (service role) เหมือนรูปแบบ `line_links`
6. **ลำดับที่แนะนำ:** ทำ LINE Login (T1) ก่อน เพราะถ้าลูกค้า login ได้ใน LINE ความจำเป็นของ cart handoff จะเหลือเฉพาะกรณีเปิดลิงก์นอก LINE ให้ Founder ตัดสินว่าจะทำ cart handoff ต่อหรือไม่หลังเห็นผล (หัวข้อ 6)

## 1. LINE Login สำหรับลูกค้า

### 1.1 เปรียบเทียบ T1 / T2 / T3

| เกณฑ์ | T1 Supabase custom OIDC | T2 Edge Function ตรวจ ID token แล้วออก session | T3 `line_links` เป็นตัวจับคู่ |
|---|---|---|---|
| ใครออก session | Supabase Auth (กลไกเดิม) | โค้ดของเราเอง (เช่น `admin.generateLink` + `verifyOtp`, หรือ JWT เอง) | ไม่มีใน Supabase — ต้องพึ่ง T2 อยู่ดี |
| state / PKCE / nonce | Supabase ทำให้ (PKCE เปิดโดยปริยายสำหรับ custom provider, `nonce`/`state` เป็น reserved param) | เราต้องทำเอง | เราต้องทำเอง |
| Verify ID token (iss, aud, exp, signature) | Supabase verify ด้วย JWKS จาก discovery | เราทำเอง (ตัวอย่างเดิม `verifiedLineUserId` เรียก LINE verify endpoint) | เหมือน T2 |
| ผู้ใช้ใหม่ | รองรับ (สร้าง `auth.users` + identity) | รองรับถ้าเราสร้าง user เอง | **ไม่รองรับ** (ต้องเคยเชื่อมแล้ว) |
| ผู้ใช้ Google เดิม | ผูกด้วย `linkIdentity` หลัง login Google (พิสูจน์สองฝั่ง) | ต้องออกแบบ flow ผูกเอง | ผูกได้เฉพาะคนที่เคยทำ ZOKY-LINE-001 และยังเป็นการ "ข้ามตัวตน" ถ้าให้ login ได้ตรง |
| โค้ดใหม่ | น้อยที่สุด (UI ปุ่ม + callback + การตั้งค่า provider) | มาก + เป็นโค้ด security-critical | น้อย แต่ไม่ตอบโจทย์ |
| Attack surface ใหม่ | ต่ำ-กลาง (อยู่ใน Supabase Auth ที่ถูกใช้อยู่แล้ว) | สูง (session minting, replay, token confusion) | กลาง |
| Rollback | ปิดปุ่ม และ/หรือ disable provider ได้ทันที | ปิด function | n/a |
| ความเสี่ยง auto-merge ด้วยอีเมล | มีถ้าขอ email scope — **ปิดได้** ด้วยไม่ขอ email + `email_optional` | ควบคุมเองได้ | ไม่เกี่ยว |

**คำแนะนำ: T1** ตามหลัก "prefer existing capability / ไม่เขียนโค้ดออก session เอง" ของ AGENTS.md และตาม task ข้อ 5 (T1 ก่อน T2) หาก T1 ไม่ผ่านเงื่อนไขทดสอบ (หัวข้อ 1.9) ให้หยุดและกลับมาขออนุมัติทางเลือกอื่น ห้ามสลับไป T2 เองเพราะเป็น Authentication Architecture Change เพิ่มเติม

**หมายเหตุ `signInWithIdToken`:** เอกสาร Supabase ระบุว่า native ID-token sign-in รองรับเฉพาะ Google, Apple, Facebook, Kakao และ Keycloak ไม่ใช่ custom provider ดังนั้น T1 ต้องใช้ redirect flow (`signInWithOAuth({ provider: 'custom:line' })`) ไม่ใช่การส่ง `liff.getIDToken()` เข้า Supabase ตรง ๆ

### 1.2 ผลตรวจว่า Supabase รองรับหรือไม่

| ประเด็น | ผล | หลักฐาน |
|---|---|---|
| Custom OIDC/OAuth provider บน Supabase hosted | **รองรับ** identifier ต้องขึ้นต้น `custom:`; ตั้งค่าได้ทาง Dashboard หรือ Auth admin API | เอกสาร "Custom OAuth/OIDC Providers" (supabase.com/docs/guides/auth/custom-oauth-providers) ค้นผ่าน docs search ของ Supabase ใน session นี้ |
| Free plan จำกัด 3 custom providers | ระบุในเอกสาร | เอกสารเดียวกัน |
| OIDC: verify ID token ด้วย JWKS จาก discovery | ระบุในเอกสาร | เอกสารเดียวกัน |
| PKCE เปิดโดยปริยาย / `state`, `nonce` เป็น reserved param | ระบุในเอกสาร | เอกสารเดียวกัน |
| `email_optional`, `skip_nonce_check` (default false) | ระบุในเอกสาร | เอกสารเดียวกัน |
| LINE OIDC discovery | issuer `https://access.line.me`; authorization `https://access.line.me/oauth2/v2.1/authorize`; token `https://api.line.me/oauth2/v2.1/token`; jwks `https://api.line.me/oauth2/v2.1/certs`; ID token alg `ES256`; PKCE `S256`; scope `openid profile email`; token auth `client_secret_basic`/`client_secret_post` | ดึงจาก `https://access.line.me/.well-known/openid-configuration` ใน session นี้ |
| Automatic linking ด้วยอีเมลเดียวกัน | **Supabase ทำให้อัตโนมัติ** เมื่อ provider ส่งอีเมล | เอกสาร "Identity Linking" — เหตุผลที่ต้องไม่ขอ `email` scope (หัวข้อ 1.4) |
| Manual linking (`linkIdentity`) | ต้องเปิด "manual linking" ใน Auth settings ของ project; ระบุว่าเป็น beta | เอกสาร "Identity Linking" |

**ตรวจไม่ได้ / ต้องยืนยันบน staging ก่อน implement** (ไม่ได้เชื่อมต่อ project จริงตามข้อจำกัดงานนี้):

- ปัจจุบัน project ของ ZOKY (plan, Auth version, จำนวน custom provider ที่ใช้ไป) รองรับ custom provider หรือไม่
- การตั้งค่า manual linking ปัจจุบันของ project เปิดอยู่หรือไม่ และ `linkIdentity` ใช้กับ `custom:` provider ได้จริงหรือไม่ (เอกสารตัวอย่างใช้ built-in provider)
- ว่า identity ของ `custom:line` เก็บ `sub` เป็น `provider_id` ตรงกับ LINE userId (`U` + 32 hex) เหมือน `line_links.line_user_id` หรือไม่ (จำเป็นต่อหัวข้อ 1.5)
- พฤติกรรมเมื่อ LINE ไม่ส่งอีเมลและ `email_optional=true` (สร้าง user ที่ `email` เป็น null ได้จริงหรือไม่)
- redirect flow ทำงานใน LINE in-app browser/LIFF webview ได้ครบ (PKCE verifier เก็บใน storage ของ webview เดียวกัน) และ LINE Login channel สถานะ Published รองรับผู้ใช้ทั่วไป (ไม่อยู่ในสถานะ Developing ที่จำกัดเฉพาะผู้ดูแล/ผู้ทดสอบ)
- refresh token ของ session เดิมยังใช้ได้หลัง disable provider หรือไม่ (มีผลต่อ rollback หัวข้อ 1.8)

### 1.3 Flow (T1)

```
[LINE in-app / LIFF /food] --กด "เข้าสู่ระบบด้วย LINE"-->
  client: signInWithOAuth({ provider: 'custom:line',
            options: { redirectTo: <origin>/auth/callback?to=<allowlisted path> } })
  --> Supabase /auth/v1/authorize  (สร้าง state + nonce + PKCE)
  --> access.line.me (LINE Login, scope: openid profile  ไม่มี email)
  --> Supabase /auth/v1/callback  (แลก code, verify ID token: sig/iss/aud/exp/nonce)
  --> <origin>/auth/callback?code=...   (PKCE exchange ฝั่ง client เหมือน Google ปัจจุบัน)
  --> กลับ path ที่ allowlist (ตะกร้า guest เดิมยังอยู่ใน storage ของ webview เดียวกัน)
```

- ใน LINE in-app ตะกร้า guest (sessionStorage/localStorage) อยู่ใน webview เดียวกันตลอด flow จึงไม่ต้องใช้ cart draft (ต่างจากการออกไป browser ภายนอก)
- ปุ่ม LINE Login แสดงเป็นตัวเลือกหลักเมื่อ user agent เป็น LINE (`/\bLine\//i` หรือ `liff.isInClient()`); นอก LINE แสดงเป็นตัวเลือกเสริมต่อจาก Google/email (ไม่แทนที่) ตาม AC-L7
- ที่ `/food/login` ต้องมีข้อความอธิบายก่อนกด: "เข้าสู่ระบบด้วย LINE จะสร้างบัญชีใหม่ ถ้าเคยใช้ Google ให้เข้าด้วย Google ก่อนแล้วผูก LINE ที่ตั้งค่า" (กันบัญชีซ้ำ D-4)

### 1.4 ห้าม auto-merge ด้วยอีเมล (D-4)

กลไก Supabase จะ link identity อัตโนมัติเมื่ออีเมลเดียวกัน จึงต้องกันที่ต้นทางหลายชั้น:

1. **ไม่ขอ scope `email`** ที่ provider (`scopes: ['openid','profile']`) และตั้ง `email_optional: true` — identity ของ LINE จึงไม่มีอีเมลให้จับคู่
2. ห้ามเขียนโค้ดฝั่งเราที่ค้น/จับคู่ผู้ใช้ด้วยอีเมล, `phone` หรือชื่อ ไม่ว่าในขั้นใด
3. การผูกกับบัญชีเดิมทำได้ทางเดียวคือ **ผู้ใช้ login บัญชีเดิมอยู่** แล้วเรียก `linkIdentity({ provider: 'custom:line' })` (พิสูจน์ความเป็นเจ้าของสองฝั่ง: session ของบัญชีเดิม + การยืนยันตัวตนกับ LINE)
4. **Staging test บังคับ (ข้อ T-A1):** สร้างผู้ใช้ทดสอบ Google/email ที่อีเมลตรงกับอีเมลบัญชี LINE ทดสอบ แล้ว login ด้วย LINE ต้องได้ `auth.users` คนละ id เสมอ — ถ้า Supabase merge ได้ในกรณีใดก็ตาม ถือเป็น CRITICAL และห้ามเปิด flag
5. LINE userId ที่มี `line_links` ผูกกับบัญชี A อยู่แล้ว แต่ผู้ใช้ login LINE เข้าบัญชีใหม่ A′: **ไม่ย้ายและไม่ merge อัตโนมัติ** ดูหัวข้อ 1.5

### 1.5 การผูกกับ `line_links` เดิม

มีสองแนวคิดแยกกัน ต้องไม่ปนกัน:

| แนวคิด | ที่เก็บ | ใช้ทำอะไร |
|---|---|---|
| Login identity | `auth.identities` (provider `custom:line`, ผ่าน Supabase Auth) | พิสูจน์ตัวตนเพื่อ login |
| Notification link | `public.line_links` (ZOKY-LINE-001) | ส่งข้อความ LINE OA ให้บัญชีนี้ |

ข้อเสนอ (ไม่แก้ schema เดิมของ `line_links`):

- หลัง login ด้วย LINE ครั้งแรก ผู้ใช้ยังต้องกด "รับแจ้งเตือนทาง LINE" เองตามกลไกเดิม (ใช้ `line-link` Edge Function ที่ verify ID token ของ LIFF) เพื่อให้ consent สำหรับแจ้งเตือนชัดเจน — **ไม่ผูก `line_links` อัตโนมัติจากการ login** ในเฟสแรก (กัน scope creep และเรื่อง privacy)
- ปัญหาที่ต้องจัดการ: `line-link` เดิม "ย้าย" `line_user_id` มาที่บัญชีที่พิสูจน์ล่าสุด (ลบแถวบัญชีเก่า) หากผู้ใช้มีบัญชี Google A (เคยผูกแล้ว) และบัญชีใหม่ A′ จาก LINE Login การผูกจาก A′ จะทำให้ A เสียการแจ้งเตือนเงียบ ๆ ข้อเสนอ: ก่อน implement ให้ Full-Stack เพิ่มการแจ้งเตือนชัดเจนใน UI ก่อนย้าย และ QA ต้องทดสอบกรณีนี้ (T-A6) การเปลี่ยนพฤติกรรมของ `line-link` เองต้องเป็น change ที่ review แยก ไม่รวมในเอกสารนี้
- ใช้ `line_links` เป็น **hint เท่านั้น:** ถ้าเรามีแถว `line_links` ของ LINE userId นี้อยู่ (เทียบโดย server เท่านั้น ไม่ส่งข้อมูลบัญชีกลับ client เกินจำเป็น) สามารถแสดงข้อความทั่วไป "LINE นี้เคยเชื่อมกับบัญชี ZOKY แล้ว เข้าสู่ระบบด้วยวิธีเดิมแล้วผูก LINE ที่ตั้งค่า" **โดยไม่เปิดเผยว่าเป็นบัญชีไหน** (ป้องกัน account enumeration) ข้อนี้เป็น P1 ไม่จำเป็นต้องมีในรอบแรก
- Provider: LINE Login channel ที่ใช้กับ Supabase ต้องอยู่ใน **Provider เดียวกับ OA ลูกค้า "Zoky • สั่งอาหาร"** มิฉะนั้น `sub` ไม่ตรงกับ `line_links.line_user_id` (AC-L4, EC-L5) ต้องตรวจก่อนเปิด flag

### 1.6 Nonce / state / ID token verification

| กลไก | ผู้รับผิดชอบ | หมายเหตุ |
|---|---|---|
| `state` (CSRF ของ OAuth) | Supabase Auth | reserved param ปรับแต่งไม่ได้; client ไม่ต้องทำ |
| PKCE (S256) | Supabase Auth + client library | LINE รองรับ S256 ตาม discovery |
| `nonce` | Supabase Auth | `skip_nonce_check` ต้องคงเป็น `false` |
| ตรวจ `iss`, `aud`, `exp`, ลายเซ็น ES256 | Supabase Auth ด้วย JWKS | `client_id` ต้องเป็น LINE Login channel ที่ตั้งไว้ |
| `redirectTo` | Supabase redirect allowlist + allowlist ของเราเอง | ดูด้านล่าง |
| Secrets (Channel secret) | ใส่ใน Supabase Dashboard โดย Founder/Owner เท่านั้น | ห้ามอยู่ในแชท/commit/log |

**Open redirect:** callback ของเราไม่รับ URL เต็ม รับเฉพาะ `to` แล้วผ่าน `safeLineDestination`-style allowlist เดียวกับ task ข้อ 3 (AC-Q2/AC-L5): `/food`, `/food?order=<ZF|WF number>`, `/s/<code>`, `/food?store=<uuid>` ปฏิเสธ absolute URL, `//`, `\`, scheme อื่น, encoded variants, ความยาวเกินกำหนด, `to` ซ้ำ ถ้าไม่ผ่านใช้ `/food` และต้องเพิ่ม **Supabase redirect URL allowlist แบบ exact path** ไม่ใช้ wildcard กว้าง
(หมายเหตุ: working tree ที่ตรวจไม่มี `/s/` ใน allowlist ปัจจุบัน — ต้องยืนยัน baseline branch ก่อน ดู task หัวข้อ 1)

### 1.7 Session handling

- ใช้ Supabase session เดิมทั้งหมด (access/refresh token ตามกลไก `@supabase/supabase-js` ที่ repo ใช้) ไม่มี cookie/JWT ชนิดใหม่
- ใน LINE in-app webview และ browser ภายนอกเป็นคนละ storage partition → session แยกกัน (EC-L7) ซึ่งเป็นเหตุให้ไม่มีบัญชีซ้ำโดยตั้งใจก็ตาม ต้องมี copy อธิบาย; ห้ามส่ง access/refresh token ข้าม browser ทุกกรณี (สอดคล้องแนวทางเดิมใน `google-pwa-oauth.ts` ที่ไม่ส่ง token ระหว่างหน้าต่าง)
- iOS Home Screen PWA: redirect ไป `access.line.me` อาจออกนอก PWA (EC-L6) — ไม่เปิดปุ่ม LINE Login นอก LINE client ในเฟสแรกถ้า usability test ยืนยันว่าเป็นปัญหา (ตัดสินที่ staging)
- ทุก API ที่ต้อง login ยังบังคับ session จริงฝั่ง server; anon ห้ามเรียก private order/quote/payment (AC-G7) ไม่เปลี่ยน
- ผู้ใช้ที่มี identity LINE อย่างเดียว: เสนอให้มีหน้าตั้งค่า "เพิ่มวิธีเข้าสู่ระบบสำรอง" (เพิ่ม Google หรืออีเมลผ่าน flow ที่พิสูจน์อีเมลจริง) และ `unlinkIdentity` ทำได้เมื่อเหลืออย่างน้อย 2 identity (กฎของ Supabase) ตรง US-L3
- Audit/log: log เฉพาะ event (`line_login_started/succeeded/failed/linked/unlinked`) พร้อมรหัสเหตุผล ไม่ log token, `sub` เต็ม, ชื่อ, รูป; เก็บ `sub` แบบ truncate 4 ตัวท้ายถ้าจำเป็น rate limit ของ login ใช้ของ Supabase Auth (ตรวจ config ที่ staging, ดูหัวข้อ 3.6)

### 1.8 Feature flag และ rollback

ชั้นป้องกัน (จากเร็วไปช้า):

1. **Provider kill switch (ทันที):** `enabled=false` ที่ `custom:line` ใน Supabase Dashboard (Owner เป็นผู้สั่ง) — UI ต้องจัดการ error ของ authorize อย่างสุภาพและซ่อนปุ่ม ไม่ค้าง
2. **UI flag:** `NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED` (build-time ตามรูปแบบ `NEXT_PUBLIC_LIFF_ID_*` เดิม) ต้อง redeploy ถึงจะมีผล จึงไม่ใช่ kill switch ทันที ใช้เป็นตัวควบคุม rollout; ค่าเริ่มต้น `off` (ไม่เพิ่ม dependency/infra ใหม่)
3. **Vercel rollback** ไป deployment ก่อนหน้า (Founder/Owner สั่งเท่านั้น ตาม RULES.md)

Rollback ผู้ใช้ที่มีแต่ LINE:

- การปิดปุ่ม/flag **ไม่ลบ** `auth.users` หรือ identity ใด ๆ (ไม่มี destructive step)
- session ที่ login อยู่ยังใช้ได้ (ต้องยืนยันบน staging ว่า refresh ยังทำงานหลัง disable provider — ข้อ 1.2)
- ผู้ใช้ที่ออกจากระบบแล้วและถูกปิดช่องทางจะเข้าไม่ได้จนกว่าจะเปิด provider คืน → ดังนั้น **ห้ามปิดตัว provider เพื่อ rollback ปกติ** ให้ใช้เฉพาะเหตุฉุกเฉินด้านความปลอดภัย และใช้การซ่อนปุ่มสำหรับผู้ใช้ใหม่ (stage 2) พร้อมคงทางเข้าให้ identity เดิม
- ก่อนเปิดใช้ทั่วไปต้องมีแผน recovery ที่ Founder รับทราบ (เช่น ให้ผู้ใช้ LINE-only เพิ่มอีเมล/Google ภายหลัง และแสดง prompt หลังสั่งออเดอร์แรก)
- ไม่มี DB migration ใน T1 (ใช้ตาราง `auth.*` ของ Supabase) → rollback ฝั่ง DB ไม่มี

### 1.9 ไฟล์ที่คาดว่าได้รับผลกระทบ (LINE Login)

| ไฟล์/ส่วน | การเปลี่ยน |
|---|---|
| `web/components/auth-flow/screens.tsx` (และหน้า `web/app/food/login/page.tsx`) | ปุ่ม LINE Login + copy อธิบาย D-4 |
| `web/lib/line-liff.ts` | ขยาย allowlist destination (ถ้ายังไม่มีใน baseline) และฟังก์ชันตรวจ LINE client |
| auth callback route ของ food (ที่ใช้อยู่) | จำกัด `to` ด้วย allowlist |
| หน้าตั้งค่าบัญชีของ food | แสดง/ผูก/ยกเลิก identity LINE (`linkIdentity`/`unlinkIdentity`) |
| Supabase Auth settings (นอกโค้ด) | เพิ่ม provider `custom:line`, redirect URL allowlist, manual linking — **Founder/Owner ทำเอง** |
| LINE Developers console (นอกโค้ด) | Login channel ใน Provider เดียวกับ OA, callback URL, สถานะ Published |
| `docs`/privacy policy | อัปเดตว่าใช้ LINE userId เพื่อ login |
| tests | unit test allowlist/redirect; staging test matrix (หัวข้อ 4) |

ไม่แก้ `supabase/functions/line-link`, `line-webhook`, หรือ schema `line_links` ในเฟสนี้ (ยกเว้นการ review แยกตามหัวข้อ 1.5)

## 2. Server-side Cart Draft (D-6)

### 2.1 ปัญหาและขอบเขตที่เล็กที่สุด

EC-G2: ผู้ใช้ต้องออกจาก LINE ไป browser ภายนอก (เช่น login Google) → storage ไม่แชร์ → ตะกร้าหาย เป้าหมาย: ส่ง "ร้าน + รายการตะกร้า" ข้าม browser **โดยไม่ต้องมีบัญชีล่วงหน้า** และไม่เปิดช่อง cross-user/open redirect

ทางเลือก:

| ทาง | ข้อดี | ข้อเสีย | สรุป |
|---|---|---|---|
| H1 ตะกร้าถาวรผูก `user_id` | sync หลายอุปกรณ์ | ต้อง login ก่อน → แก้ EC-G2 ไม่ได้ (ตะกร้าหายก่อน login); เพิ่ม PII/ขอบเขตมาก | ไม่ทำ |
| H2 ซองส่งต่อ one-time (token สุ่ม) | แก้ EC-G2 ตรงจุด, ข้อมูลน้อย, อายุสั้น | ผู้ถือลิงก์ที่ claim ก่อนจะได้ตะกร้า (ข้อมูลไม่ sensitive) | **แนะนำ** |
| H3 ใส่ตะกร้าใน URL ตรง ๆ | ไม่มี DB | ยาว, รั่วใน history/referrer/log, ปลอมได้ง่าย | ไม่ทำ |

ตะกร้าที่ได้จาก H2 ยังเป็น **untrusted input** เหมือน guest basket เดิม: ราคา ยอด สต็อก ค่าส่ง คำนวณฝั่ง server ตอน quote/สร้างออเดอร์เสมอ (AC-G4) ตะกร้านี้ไม่ใช่แหล่งความจริงด้านราคา

### 2.2 Flow

```
[LINE in-app] ผู้ใช้กด "ไปเข้าสู่ระบบในเบราว์เซอร์" (เฉพาะเมื่อจำเป็นต้องออกนอก LINE)
 1. client POST food-cart-handoff {action:'create', storeId, lines[]}  (anon ได้, apikey เท่านั้น)
 2. server: validate + rate limit + insert (เก็บ sha256(token)) -> ตอบ { token }  (token แสดงครั้งเดียว)
 3. client สร้างลิงก์จาก origin คงที่ในโค้ด:  https://<food-origin>/food/resume#d=<token>
    แล้วเปิดด้วย liff.openWindow({ url, external: true })   (ต้องยืนยันพฤติกรรมบนเครื่องจริง)
[Browser ภายนอก]
 4. หน้า /food/resume อ่าน token จาก fragment (ไม่ส่งไป server ใน GET/Referer/log), ล้าง fragment ด้วย history.replaceState
 5. client POST {action:'claim', token}  -> server: delete ... returning (atomic, ใช้ครั้งเดียว, ไม่หมดอายุ)
 6. client เขียนผลเข้า guest basket (ผ่าน validator เดิม readGuestFoodBasket-style) แล้ว redirect ไป /food?store=<uuid ที่ server ส่งกลับและ validate รูปแบบ>
 7. ผู้ใช้ login (Google/อีเมล/LINE) และกลับมายืนยันออเดอร์ตาม flow เดิม
```

### 2.3 ร่าง schema (additive — ยังไม่ใช่ migration)

```sql
-- DRAFT ONLY. ไม่ใช่ไฟล์ migration; ต้องผ่าน review + Founder gate แยกก่อนสร้างจริง
create table public.food_cart_handoffs (
  id          uuid primary key default gen_random_uuid(),
  token_hash  bytea not null unique check (octet_length(token_hash) = 32),   -- sha256 ของ token สุ่ม 32 bytes
  store_id    uuid not null references public.food_stores(id) on delete cascade,
  lines       jsonb not null
    check (jsonb_typeof(lines) = 'array'
       and jsonb_array_length(lines) between 1 and 50
       and pg_column_size(lines) <= 16384),
  client_key  bytea check (client_key is null or octet_length(client_key) = 32), -- HMAC(secret, ip) สำหรับ rate limit เท่านั้น
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '15 minutes',
  check (expires_at > created_at and expires_at <= created_at + interval '30 minutes')
);

create index food_cart_handoffs_expires_idx on public.food_cart_handoffs (expires_at);
create index food_cart_handoffs_client_idx  on public.food_cart_handoffs (client_key, created_at);

alter table public.food_cart_handoffs enable row level security;
revoke all on table public.food_cart_handoffs from anon, authenticated;
-- ไม่มี policy ใด ๆ: เฉพาะ service_role (Edge Function) อ่าน/เขียนได้
```

หลักการ: ไม่มีคอลัมน์ `user_id` และไม่ผูกกับบัญชี (ซองถูกสร้างก่อน login) ไม่เก็บ IP ดิบ ไม่เก็บเบอร์/ที่อยู่/ชื่อ ไม่เก็บราคา

เลือก Edge Function (service role) แทน RPC `anon`: ทำ rate limit/ตรวจเมนูได้ครบและสอดคล้องกับรูปแบบ `line_links`; `verify_jwt = false` เพราะ guest ไม่มี JWT (แนวเดียวกับ `wynos-maps-geocode` ใน `supabase/config.toml`) — เป็นการเพิ่ม public endpoint จึงต้องผ่าน QA & Security เป็นพิเศษ

### 2.4 RLS / Ownership

- ไม่มี ownership ผูกบัญชี: ความเป็นเจ้าของ = การถือ token ที่เดาไม่ได้ (capability) ดังนั้น **ห้ามมีทางอ่านตารางตรงจาก client** (revoke ทั้งหมด, ไม่มี policy, ไม่มี view, ไม่มี RPC ที่ grant ให้ anon/authenticated)
- Edge Function ใช้ service role เฉพาะสองคำสั่งแคบ ๆ: `insert` และ `delete ... where token_hash = $1 and expires_at > now() returning store_id, lines`
- ไม่มี list/get/search endpoint → ไม่มีทาง enumerate ซองของคนอื่น
- ตอบ error แบบเดียวกันทุกกรณี claim ไม่สำเร็จ (`not_found_or_expired`) เพื่อไม่บอกว่าซองมีอยู่/หมดอายุ/ถูก claim แล้ว

### 2.5 การตรวจ input (ที่ trust boundary: Edge Function)

- `storeId`: uuid, ร้านต้องมีอยู่และเปิดให้ลูกค้าเห็น (ใช้เกณฑ์เดียวกับ anonymous storefront RPC เดิม)
- `lines`: 1–50 รายการ; `menu_item_id` uuid และต้องอยู่ใน `storeId` (ตรวจกับ `food_menu_items`); `quantity` จำนวนเต็ม 1–99; `note` string ≤ 200 ตัวอักษร ตัดอักขระควบคุม; `selected_options` เป็น array ขนาดจำกัด แต่ละรายการมี `group_id`, `choice_id` uuid เท่านั้น (ตามรูป `FoodCartLine` ที่ server re-resolve ชื่อ/ราคาเอง) ตัด field ที่ไม่รู้จักทิ้ง (กัน mass-assignment)
- ปฏิเสธ body > ~20 KB, content-type ผิด, method ผิด

### 2.6 TTL / การลบ

- อายุ 15 นาที (ค่าสูงสุดที่ constraint ยอม 30 นาที)
- claim = ลบทันที (ใช้ครั้งเดียว) ผลข้างเคียง: ถ้า response หายหลัง claim ผู้ใช้ต้องสร้างตะกร้าใหม่ (ยอมรับได้ ราคาต่ำกว่าความเสี่ยงของ replay)
- **กัน link preview bot:** การ claim ทำด้วย `POST` จาก JS ของหน้า resume เท่านั้น ไม่ทำใน GET/SSR และ token อยู่ใน fragment ซึ่ง crawler ไม่ส่งมาที่ server
- ลบของหมดอายุ: `pg_cron` ทุก 15 นาที `delete ... where expires_at < now()` (repo มีรูปแบบ pg_cron อยู่แล้ว เช่น food promo cron) + ลบแบบ opportunistic ตอน create; รายละเอียด cron อยู่ใน migration ที่จะ review ภายหลัง และต้องไม่ใช้ Vault secret ใหม่ถ้าไม่จำเป็น (job เป็น SQL ล้วนไม่ต้องเรียก HTTP)
- ตารางไม่เก็บประวัติ/ไม่มี soft delete; backup ของ Supabase อาจมีสำเนาชั่วคราวตามรอบ backup (ระบุใน privacy note)

### 2.7 PII / Privacy

| ข้อมูล | จัดการ |
|---|---|
| เบอร์โทร/ที่อยู่/ชื่อ | **ไม่ส่งและไม่เก็บ** ใน handoff (AC-G5 เดิม: เก็บบนอุปกรณ์เท่านั้น ผู้ใช้กรอกใหม่หลัง login ถ้าข้ามเบราว์เซอร์) |
| `note` ต่อรายการ | free text อาจมี PII โดยไม่ตั้งใจ — จำกัด 200 ตัวอักษร, อายุ 15 นาที, ไม่ log, ลบเมื่อ claim |
| IP | ไม่เก็บดิบ; เก็บเฉพาะ `client_key` = HMAC-SHA256 ด้วย secret ของ Edge Function (Founder/Owner ตั้งค่าเอง) ใช้ rate limit และถูกลบพร้อมแถว |
| token | ไม่เก็บ plaintext (เก็บ SHA-256 เท่านั้น); ไม่ log; ไม่ส่งใน query string |
| Logging | log เฉพาะ event + รหัสผลลัพธ์ + ขนาด ไม่ log `lines`, `note`, token, IP |
| Privacy policy | ยังเป็น placeholder — ต้องอัปเดตก่อนเปิด (ระบุข้อมูลตะกร้าถูกเก็บชั่วคราว ≤ 15 นาทีเพื่อส่งต่อ browser) |

### 2.8 ป้องกัน cross-user access และ open redirect

- Token เดา/brute-force ไม่ได้ (256 บิต, ใช้ครั้งเดียว, อายุสั้น, rate limit claim)
- ผู้ถือลิงก์ที่ claim ก่อนจะได้ตะกร้า (เมนู+จำนวน+โน้ต) เท่านั้น ไม่ได้ session, ไม่ได้ข้อมูลบัญชีใด ๆ และไม่กระทบออเดอร์ (ออเดอร์ต้องมี session และ server คำนวณใหม่)
- หน้า `/food/resume` **ไม่รับพารามิเตอร์ปลายทางใด ๆ** (`to`/`next`/`redirect` ถูกเพิกเฉย) ปลายทางคือ `/food?store=<uuid>` ที่ประกอบจากค่า `store_id` ที่ server ส่งกลับและตรวจรูปแบบ uuid ฝั่ง client อีกครั้ง
- ลิงก์ถูกประกอบที่ client จาก origin คงที่ในโค้ด/ค่า config ไม่ใช้ URL ที่ server ส่งกลับ → server ที่ถูกโจมตีก็ชี้ผู้ใช้ไปโดเมนอื่นไม่ได้
- ส่งต่อด้วย `Referrer-Policy: no-referrer` และ `Cache-Control: no-store` สำหรับหน้า `/food/resume`
- ข้อมูลใน handoff ไม่รวม userId/token ของบัญชี (AC-Q5)

### 2.9 Abuse / Rate limit

- Create (anon): จำกัดต่อ `client_key` เช่น **10 ครั้ง/ชั่วโมง** โดยนับจากแถวในตาราง (ทนต่อหลาย instance ต่างจาก in-memory ของ `maps-rate-limit.ts` ที่ระบุเองว่าเป็น best-effort) + เพดานรวมจำนวนซองที่ยังไม่หมดอายุ (เช่น 5,000) เกิน → 429 พร้อม `Retry-After` — ตัวเลขเป็นข้อเสนอเริ่มต้น ปรับตามผล QA
- Claim: จำกัดต่อ IP แบบ in-memory ชั้นแรก (30/นาที) — เพียงพอเพราะ token เดาไม่ได้
- ขนาด body/จำนวนรายการจำกัด (หัวข้อ 2.5); CORS จำกัดเฉพาะ origin ของ ZOKY (รูปแบบเดียวกับ `line-link`)
- Fail safe: ถ้าตรวจ rate limit ไม่ได้ (DB error) ให้ปฏิเสธ create ไม่ใช่ปล่อยผ่าน
- ไม่ใช้ในการ "สแปม" ร้านค้า: ซองไม่สร้างออเดอร์/แจ้งเตือนใด ๆ ให้ร้าน

### 2.10 Rollback / ไฟล์ที่คาดว่าได้รับผลกระทบ (Cart draft)

- ปิดด้วย flag ฝั่ง UI (`NEXT_PUBLIC_ZOKY_CART_HANDOFF_ENABLED`, ค่าเริ่มต้น off) และ Edge Function ตอบ 503 เมื่อ env ปิด (รูปแบบเดียวกับ `LINE_NOTIFICATIONS_ENABLED`)
- Rollback DB: ไฟล์ `supabase/rollbacks/<ts>_zoky_cart_handoffs_rollback.sql` (drop cron job, drop table) — **destructive จริง** ต่อข้อมูลในตารางนี้ แต่ข้อมูลเป็น transient อายุ ≤ 15 นาที; ยังต้องให้ Founder อนุมัติก่อนรันบน production ตามกฎ
- ไฟล์คาดว่าเกี่ยวข้อง: migration ใหม่ + rollback + `supabase/tests/zoky_cart_handoffs_test.sh` (ตามแบบ `zoky_line_links_test.sh`), `supabase/functions/food-cart-handoff/*` (ใหม่), `supabase/config.toml` (เพิ่ม `[functions.food-cart-handoff] verify_jwt=false`), `web/app/food/resume/page.tsx` (ใหม่), `web/components/food/food-guest-browse.tsx` และ `web/lib/food-customer.ts` (reuse validator/ชนิด `FoodCartLine`), workflow apply ของ migration (ตาม pattern `.github/workflows/zoky-line-apply.yml`)
- ไม่เพิ่ม dependency ใหม่ (D-6 ข้อ dependency)

## 3. Threat model (สั้น)

### 3.1 LINE Login

| # | ภัย | ผลกระทบ | การป้องกัน |
|---|---|---|---|
| L-1 | Account takeover ผ่าน auto-merge อีเมล | สูง | ไม่ขอ `email`, `email_optional`, test T-A1 ต้องผ่าน, ไม่มีโค้ดจับคู่อีเมล |
| L-2 | Pre-account takeover (ผู้โจมตีสร้างบัญชีด้วยอีเมลของเหยื่อก่อน) | สูง | LINE identity ไม่มีอีเมล → ไม่ถูก link; ไม่ให้ identity ที่ไม่ verified รวมกับบัญชีอื่น |
| L-3 | OAuth CSRF / code injection | สูง | state + PKCE + nonce โดย Supabase; `skip_nonce_check=false` |
| L-4 | Open redirect ผ่าน `to`/`redirectTo` | กลาง-สูง | allowlist exact, Supabase redirect allowlist ไม่ใช้ wildcard |
| L-5 | ID token จาก channel อื่น (token confusion) | สูง | Supabase ตรวจ `aud` = client_id ของเรา; ไม่รับ `acceptable_client_ids` เพิ่ม |
| L-6 | Provider ผิดทำให้ `sub` ไม่ตรงกับ `line_links` | กลาง | ตรวจ config ก่อนเปิด flag; staging กับ OA ทดสอบ |
| L-7 | ผูก LINE ของเหยื่อเข้าบัญชีผู้โจมตี (login CSRF / session fixation) | สูง | `linkIdentity` ต้องมี session ที่ valid, ใช้ state/PKCE; ทดสอบ T-A5 |
| L-8 | Notification hijack ผ่าน `line-link` ย้าย userId | กลาง | UI เตือนก่อนย้าย, test T-A6 (ยังเป็น behavior เดิมของ ZOKY-LINE-001) |
| L-9 | Account enumeration (บอกว่า LINE นี้มีบัญชี) | ต่ำ-กลาง | ข้อความทั่วไป ไม่ระบุบัญชี |
| L-10 | ผู้ใช้ LINE-only ถูกล็อกเมื่อ rollback | กลาง | ไม่ disable provider เป็น rollback ปกติ, แผน recovery |
| L-11 | Log รั่ว token/`sub`/ชื่อ | กลาง | ห้าม log; ตรวจใน QA |
| L-12 | Brute force/สแปม login | ต่ำ-กลาง | rate limit ของ Supabase Auth (ต้องตรวจค่า staging) |

### 3.2 Cart handoff

| # | ภัย | ผลกระทบ | การป้องกัน |
|---|---|---|---|
| C-1 | เดา/enumerate token | กลาง | 256 บิต, เก็บ hash, rate limit, ไม่มี list endpoint |
| C-2 | Replay/ใช้ลิงก์ซ้ำ | ต่ำ-กลาง | delete-on-claim atomic, TTL 15 นาที |
| C-3 | อ่านตารางตรงผ่าน PostgREST | สูง | revoke all, ไม่มี policy, ทดสอบ T-B2 |
| C-4 | Open redirect ผ่านหน้า resume | กลาง | ไม่รับพารามิเตอร์ปลายทาง, ปลายทางประกอบจาก uuid |
| C-5 | Token รั่วผ่าน Referer/log/history/preview bot | กลาง | fragment, `no-referrer`, POST-only claim, ล้าง fragment |
| C-6 | ใช้เป็นช่องฝากข้อมูล/สแปม storage | กลาง | จำกัดขนาด, validate เมนูของร้าน, rate limit, เพดานรวม, TTL, cron ลบ |
| C-7 | ตะกร้าเก่า/ราคาปลอม | กลาง | ไม่เก็บราคา; server re-quote ตอนสั่ง (AC-G4, AC-G6) |
| C-8 | DoS endpoint สาธารณะ | กลาง | rate limit + fail closed + ขนาด body จำกัด |
| C-9 | PII ใน `note` ค้างใน backup | ต่ำ | TTL สั้น, แจ้งใน privacy policy |
| C-10 | SSRF/injection | ต่ำ | ใช้ parameterized query ผ่าน supabase-js, ไม่มี fetch URL จาก input |

## 4. Test matrix (สำหรับ QA & Security — ใช้ staging + OA ทดสอบ + ข้อมูลสังเคราะห์เท่านั้น)

### 4.1 LINE Login

| ID | กรณี | ผลที่ต้องได้ | Severity ถ้าล้ม |
|---|---|---|---|
| T-A1 | ผู้ใช้ Google ที่อีเมลตรงกับ LINE (หรือ LINE ส่งอีเมลมา) login ด้วย LINE | ได้ `auth.users` คนละ id; บัญชี Google ไม่ถูกแตะ | CRITICAL |
| T-A2 | LINE ไม่ส่งอีเมล | สร้างบัญชีได้ (`email` ว่าง) ไม่ error ค้าง | MEDIUM |
| T-A3 | ผู้ใช้ปฏิเสธ/ยกเลิกที่หน้า LINE | กลับหน้าเดิมพร้อมตะกร้า + ข้อความ | LOW |
| T-A4 | `to`/`redirectTo` = `https://evil.test`, `//evil.test`, `/\evil.test`, `javascript:`, `%2f%2f`, `%5c`, double-encoding, CRLF, `to` ซ้ำ, ยาวเกิน | fallback `/food` ทุกกรณี | HIGH |
| T-A5 | `linkIdentity` โดยไม่มี session / ด้วย state เก่าหรือของผู้ใช้อื่น | ปฏิเสธ; ไม่ผูก LINE เข้าบัญชีอื่น | CRITICAL |
| T-A6 | LINE userId ที่มี `line_links` กับบัญชี A แล้วผูกจากบัญชี A′ | UI เตือนก่อนย้าย; ไม่มีการเปลี่ยนแปลงลับ ๆ; A ไม่ถูกลบ | HIGH |
| T-A7 | ID token ปลอม/หมดอายุ/`aud` ผิด/nonce ผิด (เลียนแบบ callback) | ปฏิเสธโดย Supabase | CRITICAL |
| T-A8 | Login ด้วย Google/email เดิมหลังเพิ่ม LINE | ทำงานเหมือนเดิม (regression) | HIGH |
| T-A9 | `unlinkIdentity` เมื่อเหลือ identity เดียว | ปฏิเสธ; ยังเข้าระบบได้ | HIGH |
| T-A10 | Provider ผิด (LINE Login คนละ Provider กับ OA) | ตรวจพบก่อนเปิด flag (checklist); ไม่ผูก `line_links` ผิด | MEDIUM |
| T-A11 | ปิด flag/ซ่อนปุ่ม/disable provider บน staging | ปุ่มหาย, ไม่ error ขาว; session เดิมทำงานต่อ (ตามผลจริง) | HIGH |
| T-A12 | Log/analytics/client bundle | ไม่มี token, `sub` เต็ม, ชื่อ, secret | HIGH |
| T-A13 | Merchant app | พฤติกรรม login ไม่เปลี่ยน (D-5) | HIGH |
| T-A14 | LINE in-app บน iOS/Android จริง, LINE Desktop, iOS PWA | flow สำเร็จหรือมี fallback ชัดเจน; ตะกร้า guest ยังอยู่ | MEDIUM |

### 4.2 Cart handoff

| ID | กรณี | ผลที่ต้องได้ | Severity ถ้าล้ม |
|---|---|---|---|
| T-B1 | create → claim สำเร็จ | ได้ตะกร้าเดิม; แถวถูกลบ | MEDIUM |
| T-B2 | anon/authenticated `select/insert/update/delete` ตาราง `food_cart_handoffs` ผ่าน PostgREST | ถูกปฏิเสธทุกกรณี | CRITICAL |
| T-B3 | claim ซ้ำ / claim หลังหมดอายุ / token มั่ว / token สั้นเกิน | `not_found_or_expired` เหมือนกันทุกกรณี | HIGH |
| T-B4 | claim พร้อมกัน 2 คำขอ (race) | สำเร็จเพียงคำขอเดียว | HIGH |
| T-B5 | `menu_item_id` ของร้านอื่น/ไม่มีอยู่, quantity 0/-1/100/NaN, note ยาว/อักขระควบคุม/emoji, field แปลกปลอม, lines > 50, body ใหญ่ | ปฏิเสธ 400 | HIGH |
| T-B6 | ร้านไม่มี/ปิดถาวร | ปฏิเสธตอน create; ตอน claim หลังร้านเปลี่ยน → หน้า "ไม่พบร้าน" | MEDIUM |
| T-B7 | `/food/resume` พร้อม `?to=https://evil.test`, `?next=//evil.test` | เพิกเฉยพารามิเตอร์; ไปเฉพาะ `/food?store=<uuid>` | HIGH |
| T-B8 | Token ใน Referer/log/server access log/analytics | ไม่มี (fragment, `no-referrer`) | HIGH |
| T-B9 | link preview bot (GET) | ไม่ consume ซอง | MEDIUM |
| T-B10 | Rate limit create/claim, เพดานรวม, DB error | 429 + `Retry-After`; DB error → ปฏิเสธ (fail closed) | HIGH |
| T-B11 | cron/TTL ลบของหมดอายุ | ไม่มีแถวหมดอายุค้างเกินรอบ cron | MEDIUM |
| T-B12 | Order ที่สร้างหลัง claim | ราคา/สต็อก/ค่าส่ง คำนวณ server; ตะกร้าเก่า/ราคาเปลี่ยนแจ้งผู้ใช้ | HIGH |
| T-B13 | anon session เรียก private order/quote/payment | ปฏิเสธ (AC-G7) | CRITICAL |
| T-B14 | Private mode/storage ปิดที่ฝั่งปลายทาง | fallback memory + เตือน (EC-G3) | LOW |
| T-B15 | Feature flag off | UI ซ่อน, Edge Function 503, ไม่มี error ขาว | MEDIUM |

## 5. ความเสี่ยงคงเหลือและการตัดสินใจเชิงสถาปัตยกรรมที่ต้องบันทึก

- ADR-1: ใช้ Supabase custom OIDC (`custom:line`) ไม่ใช้ session minting เอง
- ADR-2: ห้ามขอ email scope จาก LINE; identity ของ LINE ไม่ใช้อีเมลเป็นตัวระบุ
- ADR-3: `line_links` ไม่ใช่ identity สำหรับ login (notification link เท่านั้น)
- ADR-4: Cart handoff = ซองใช้ครั้งเดียว ไม่ใช่ตะกร้าถาวร ไม่ผูกบัญชี ไม่เก็บ PII ที่ระบุตัวตนโดยตรง
- ความเสี่ยงคงเหลือ: พฤติกรรมของ Supabase ที่ยังไม่ได้ตรวจบนโปรเจกต์จริง (หัวข้อ 1.2); `linkIdentity` เป็น beta; ผู้ใช้ Google เดิมยังมีแรงเสียดทานหนึ่งครั้ง; ซอง claim ก่อนโดยผู้ถือลิงก์; การเปลี่ยนพฤติกรรมของ `line-link` เมื่อ "ย้าย" userId; working tree ที่ตรวจตามหลัง production (ต้องยืนยัน baseline branch)

## 6. สิ่งที่ต้องให้ Founder อนุมัติ (design approval รอบที่สอง)

ต้องบันทึกใน `.wyn/company/APPROVALS.md` ตามรูปแบบ `APPROVAL_REQUIRED` (Proposed change / Reason / Benefits / Risks / Files affected / Recommendation) แยกเป็นสองรายการ เพื่ออนุมัติหรือปฏิเสธทีละส่วนได้

### A. APPROVAL_REQUIRED: Authentication Architecture Change — LINE Login (T1)

| หัวข้อ | รายละเอียด |
|---|---|
| Proposed change | เพิ่ม `custom:line` (Supabase custom OIDC) เป็นวิธี login ของลูกค้า food; ไม่ขอ email scope; ผูกบัญชีเดิมด้วย `linkIdentity` เท่านั้น |
| Reason | Google ถูกบล็อกใน LINE in-app (`disallowed_useragent`) ทำให้ผู้ใช้ต้องออกจาก LINE |
| Benefits | ลูกค้า login ใน LINE ได้ครั้งเดียว; ใช้ session กลไกเดิม; โค้ดใหม่น้อย |
| Risks | account takeover จาก merge/CSRF (ลดด้วยข้อ 1.4, 1.6); บัญชี LINE-only ถูกล็อกเมื่อปิดช่องทาง; พึ่งพา LINE; เพิ่ม attack surface; พฤติกรรม Supabase บางข้อยังไม่ได้ตรวจ |
| Rollback | ซ่อนปุ่ม/flag; Vercel rollback โดย Owner; disable provider เฉพาะเหตุฉุกเฉิน; ไม่ลบ user/identity อัตโนมัติ; ไม่มี DB migration |
| Files affected | ตามหัวข้อ 1.9 |
| Recommendation | อนุมัติแบบมีเงื่อนไข: ผ่าน staging test T-A1, T-A5, T-A7 ก่อนเปิด flag; ผู้ดำเนินการตั้งค่า provider/secret คือ Founder/Owner; privacy policy อัปเดตก่อนเปิดทั่วไป |

สิ่งที่ Founder/Owner ต้องทำเอง (นอกโค้ด): สร้าง/ยืนยัน LINE Login channel ใน Provider เดียวกับ OA ลูกค้า และเปลี่ยนสถานะเป็น Published; ตั้ง callback URL ของ Supabase; ใส่ client id/secret ใน Supabase Dashboard; เปิด manual linking; เพิ่ม redirect allowlist — ห้ามส่ง secret ในแชทหรือ commit

### B. APPROVAL_REQUIRED: DB ใหม่ + PII ชั่วคราว — Cart handoff (D-6)

| หัวข้อ | รายละเอียด |
|---|---|
| Proposed change | ตาราง `food_cart_handoffs` (additive) + Edge Function `food-cart-handoff` (public, `verify_jwt=false`) + pg_cron cleanup + หน้า `/food/resume` |
| Reason | EC-G2: ตะกร้าไม่ตามไปเมื่อต้องออกจาก LINE ไป browser ภายนอก |
| Benefits | ไม่ต้องสร้างตะกร้าใหม่ในกรณีที่ต้องออก LINE |
| Risks | endpoint สาธารณะใหม่ (abuse/DoS); `note` อาจมี PII ชั่วคราว; token รั่วผ่านช่องทางแชร์ลิงก์; ความซับซ้อนเพิ่ม |
| Rollback | flag off + Edge Function 503; rollback SQL (drop cron/table) — ข้อมูล transient ≤ 15 นาที ต้องให้ Founder อนุมัติก่อนรันบน production |
| Files affected | ตามหัวข้อ 2.10 |
| Recommendation | อนุมัติ "หลักการ" ของ design นี้ แต่ **เลื่อนการ implement** จนกว่า LINE Login (A) ผ่านและ usability test รอบหลังแก้แสดงว่ายังมีผู้ใช้จำนวนมากต้องออกจาก LINE — ถ้า A ใช้ได้ผลดี อาจไม่ต้องทำ B เลย การ apply migration จริงต้องผ่าน Founder gate แยก (ตาม D-6) หลัง review SQL, test script และ rollback |

### ข้อที่ต้องการคำตอบจาก Founder เพิ่ม

1. ยืนยันว่า T1 เป็นทิศทางที่อนุมัติ และ T2 ต้องขอใหม่ถ้า T1 ใช้ไม่ได้
2. ยืนยันเงื่อนไข "ไม่ขอ email scope จาก LINE" (ผลข้างเคียง: ไม่มีอีเมลสำหรับใบเสร็จ/กู้บัญชีจาก LINE)
3. เลือกทำ B พร้อม A หรือรอผลจาก A
4. D-7 ที่ยังไม่ตอบ (ผู้ดำเนิน test/ผู้ร่วมทดสอบ/OA ทดสอบ), baseline branch/commit, privacy policy

## 7. รายงานสิ่งที่ตรวจแล้ว / ยังไม่ได้ตรวจ

**ตรวจแล้ว (จากไฟล์และเอกสารจริง)**
- อ่านครบ: `AGENTS.md`, `docs/engineering/TEAM.md`, `docs/engineering/SECURITY_RULES.md`, `.wyn/company/RULES.md`, `.wyn/tasks/proposed/ZOKY-LINE-002-order-flow-simplification.md` (รวม Founder decisions 2026-11-07)
- อ่านโค้ด/สคริปต์ที่เกี่ยวข้อง: `supabase/migrations/20261031120000_zoky_line_links.sql`, `supabase/functions/line-link/index.ts` และ `_lib.ts` (ส่วน verify ID token), `web/lib/line-liff.ts` (allowlist ปัจจุบันมีเฉพาะ `/food` และ `?order=WF…`), `web/components/food/food-guest-browse.tsx` (guest basket + validator), `web/lib/food-customer.ts` (`FoodCartLine`), `web/lib/google-pwa-oauth.ts`, `web/lib/server/maps-rate-limit.ts` (rate limit แบบ in-memory), `supabase/config.toml`
- ตรวจเอกสารทางการของ Supabase ผ่านเครื่องมือ docs search: custom OAuth/OIDC providers, identity linking, `signInWithIdToken` (ผลสรุปในหัวข้อ 1.2)
- ดึง OIDC discovery document สาธารณะของ LINE (`access.line.me/.well-known/openid-configuration`)
- ยืนยันชื่อตารางที่อ้างถึง: `public.food_stores`, `public.food_menu_items` มีอยู่ใน migrations

**ยังไม่ได้ตรวจ (ระบุเพื่อไม่ให้เข้าใจผิด)**
- ไม่ได้เชื่อมต่อ Supabase project จริง/ไม่ได้อ่านค่า env/secrets (ตามข้อห้าม): ไม่ทราบ plan, Auth version, จำนวน custom provider, สถานะ manual linking, rate limit ของ Auth ที่ตั้งไว้
- ไม่ได้ทดสอบ flow จริงกับ LINE/LIFF (redirect ใน in-app browser, `liff.openWindow` external, สถานะ Published ของ channel) และ `linkIdentity` กับ `custom:` provider
- ไม่ได้ตรวจ `web/app/food/login/page.tsx`, auth callback route และโค้ดตะกร้า-checkout ทุกจุด (รวมจุดที่ใช้ `phone`) แบบ line-by-line; รายชื่อไฟล์ที่ได้รับผลกระทบเป็นการประมาณ
- ไม่ได้ตรวจ APPROVALS.md รายการล่าสุดหรือ branch/commit ที่ตรงกับ production (task ระบุว่า working tree ตามหลัง)
- ไม่ได้เขียน/รัน SQL หรือ test ใด ๆ; ตัวเลข rate limit/TTL เป็นข้อเสนอเริ่มต้นยังไม่ผ่านการวัดหรือ QA
- ไม่ได้ผ่าน CTO review หรือ QA & Security review
