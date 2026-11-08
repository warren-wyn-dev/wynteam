# ZOKY-LINE-002 — CTO Technical Review และ QA & Security Design Review: LINE Login (design A)

Status: **Review เสร็จ — พร้อมให้ Founder ลงบันทึกอนุมัติ แล้วจึงเริ่ม implement ตามขั้นที่กำหนด (ยังไม่มีการแก้ source / commit / deploy)**
Reviewers: WYN CTO (ส่วน A), WYN QA & Security (ส่วน B) — 2026-11-08
เอกสารที่ถูก review: `docs/architecture/zoky-line-002-line-login-and-server-cart.md` (หัวข้อ 1, 3.1, 4.1, 5, 6A), `.wyn/tasks/proposed/ZOKY-LINE-002-order-flow-simplification.md`, `docs/qa/zoky-line-002/real-flow-code-analysis.md`
Baseline ที่อ่านเทียบ: git worktree `rc-wt` (HEAD `e0bcc109`, production baseline) — `web/components/food/food-auth.tsx`, `web/app/food/auth/callback/page.tsx`, `web/app/auth/callback/page.tsx`, `web/lib/google-pwa-oauth.ts`, `web/lib/line-liff.ts`, `web/lib/return-to.ts`, `web/next.config.ts`, `supabase/config.toml`, migrations ที่ผูกกับ `auth.users`
ข้อจำกัดงาน: ไม่อ่าน secrets/env ไม่ต่อ Supabase/LINE จริง ไม่แก้ source

**ขอบเขตที่ Founder สั่งในรอบนี้**
- ทำ **design A (LINE Login) เท่านั้น** และ waive เงื่อนไข "วัด baseline usability ก่อน" (D-3)
- **design B (ตาราง `food_cart_handoffs` / Edge Function `food-cart-handoff` / หน้า `/food/resume`) ยังไม่ได้รับอนุมัติ — ห้ามรวมในขอบเขต implement ทุก PR ด้านล่างต้องไม่มี migration, ไม่มีตารางใหม่, ไม่มี endpoint สาธารณะใหม่**

---

## 1. ส่วน A — ข้อสรุป CTO

### 1.1 คำตัดสิน

**อนุมัติ T1 (Supabase custom OIDC `custom:line` + redirect flow) แบบ "ปรับ" — ไม่ใช่ตามเอกสารเดิมทุกข้อ** เหตุผลหลัก:

1. T1 ไม่มีโค้ดออก session เอง ใช้ session/PKCE/state/nonce/JWKS ของ Supabase Auth ที่ระบบใช้อยู่แล้ว ตรงหลัก "reuse before duplication" และ "ไม่เขียน security-critical code เอง" ของ AGENTS.md
2. Rollback ง่าย (flag + ซ่อนปุ่ม) และไม่มี DB migration
3. T2 ยังคงห้าม (เป็น Authentication Architecture Change เพิ่มเติม ต้องขอ Founder ใหม่), T3 (`line_links` เป็นตัว login) ไม่อนุมัติ — `line_links` เป็น notification link ไม่ใช่ identity

**สิ่งที่ปรับจากเอกสาร design (ผลจากการอ่านโค้ด baseline จริง)**

| # | ประเด็นในเอกสารเดิม | ปัญหาที่พบ | การปรับ |
|---|---|---|---|
| P1 | `redirectTo = <origin>/auth/callback?to=<allowlisted path>` (หัวข้อ 1.3) | (ก) `/auth/callback` คือ callback ของ **Social** ซึ่ง fallback ไป `/signup/step-1` (onboarding Social) ถ้าไม่มี `next` ที่ผ่าน `isSafeReturnPath` — ไม่ใช่ที่ของลูกค้า food (ข) โค้ด baseline เองบันทึกไว้ว่า Supabase production redirect allowlist เป็น **exact** การแนบ `?to=` ใน `redirectTo` อาจ fallback ไป Site URL เงียบ ๆ (คอมเมนต์ใน `food-auth.tsx` ฟังก์ชัน `google()`) | ใช้ **callback เดิมที่ allowlist แล้วสำหรับ Google: `/food/auth/callback` แบบไม่มี query** (ไม่ต้องเพิ่ม redirect URL ใน Supabase) ส่วนปลายทางหลัง login ใช้กลไกเดิมที่ validated แล้ว (ข้อ 1.3) ไม่ส่งผ่าน URL |
| P2 | ไม่ขอ `email` scope + `email_optional` (ข้อ 1.4) | ถูกต้องและต้องคงไว้ แต่เอกสารไม่ได้ตรวจว่าโค้ดฝั่งเรา/DB รองรับ `auth.users.email = null` | ตรวจแล้ว: trigger `wynos_profile_on_auth_insert` สร้าง `profiles(id)` เท่านั้น (`username` เป็น nullable) ไม่ต้องใช้อีเมล; `account-registry.ts` มี fallback เมื่อ email เป็น null; `food-stripe-checkout` ใส่ `customer_email` เฉพาะเมื่อมี email — **ไม่พบ blocker แต่ต้องยืนยัน T-A2/T-A15 บน staging** |
| P3 | `linkIdentity` / manual linking เป็นส่วนของ T1 รอบแรก (ข้อ 1.4 ข้อ 3, 1.9) | "manual linking" เป็น **setting ระดับ project** ที่ Supabase ระบุเป็น beta และมีผลต่อ Social/Merchant/Admin ที่ใช้ project เดียวกัน; ยังไม่เคยยืนยันว่าใช้ได้กับ `custom:` provider | **แยกเป็น PR สุดท้าย (PR-6) และเป็น optional/gated** — LINE Login ปล่อยได้โดยไม่มี linkIdentity ตาม D-4 ("ไม่ auto-merge" = ยอมให้เป็นบัญชีใหม่); ผู้ใช้ Google เดิมได้รับ copy อธิบายชัดเจน |
| P4 | ใช้ `startGoogleOAuth` pattern (ตามบริบท) | `startGoogleOAuth` ฮาร์ดโค้ด `provider: "google"` และ `queryParams: { prompt: "select_account" }` — `select_account` **ไม่ใช่ค่าที่ LINE รองรับ** (LINE รองรับ `prompt=consent/none`) ส่งไปอาจทำให้ authorize ล้ม | generalise เป็นรับ `provider` และ `queryParams` เฉพาะ provider (reuse โค้ด iOS PWA popup เดิม, ไม่สร้างไฟล์ใหม่) |
| P5 | ข้อความ error/loader ใน callback | `/food/auth/callback` ข้อความทั้งหมดบอกว่า "Google" | ทำเป็นข้อความกลาง (provider-neutral) ไม่สร้าง callback ใหม่ |
| P6 | หมายเหตุว่า `/s/` ไม่อยู่ใน allowlist ปัจจุบัน (ข้อ 1.6) | **baseline มีแล้ว**: `FOOD_STORE_PATH` ใน `web/lib/line-liff.ts` รองรับ `/s/<code>` และ `/food?store=<uuid>` | ปิดประเด็นนี้ ไม่ต้องขยาย allowlist |
| P7 | "ไม่แก้ `line-link` ในเฟสนี้" (ข้อ 1.9) | พฤติกรรมเดิมของ `line-link` ลบ link ของบัญชีอื่นเมื่อ LINE userId ซ้ำ (`delete … .neq("user_id", user.id)`) และ **ถูกเรียกอัตโนมัติ** หลัง login ใน LIFF — พอมี LINE Login แล้ว ผู้ใช้ Google เดิมที่ลอง LINE Login (ได้บัญชีใหม่) จะ "ขโมย" การแจ้งเตือนจากบัญชีเก่าเงียบ ๆ เกือบแน่นอนว่าเกิดจริง | เปลี่ยนจาก "ข้อสังเกต" เป็น **release blocker ระดับ HIGH** ต้องมี PR guard เล็ก ๆ ที่ `line-link` (PR-4) หรือ Founder ลงนามรับความเสี่ยง (ข้อ 5) |
| P8 | Feature flag `NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED` | flag ฝั่ง UI **ไม่ใช่ security control** — ใครก็เรียก `signInWithOAuth({provider:'custom:line'})` ตรง ๆ กับ anon key ได้ถ้า provider เปิดอยู่ และ provider เป็นของ **ทั้ง project** (Social/Merchant/Admin ใช้ร่วม) ดังนั้น D-5 ("เฉพาะ food") บังคับระดับ provider ไม่ได้ | ยอมรับเป็นความเสี่ยงที่ระบุชัด (MEDIUM, ข้อ 2.2 R-7): provider จะ **เปิดเฉพาะบน staging** ก่อน; production เปิดเมื่อ Founder สั่งเท่านั้น; ปุ่มและ flag มีเฉพาะฝั่ง food; Merchant/Social ไม่มี UI และต้องมี test T-A13 ว่า login เดิมไม่เปลี่ยน |
| P9 | ใช้ channel ใหม่ใน Provider เดียวกับ OA | ถูกต้องเรื่อง Provider แต่ **ง่ายและปลอดภัยกว่าถ้าเพิ่ม callback URL ของ Supabase เข้า LINE Login channel เดิมที่เป็นเจ้าของ LIFF ของ food** (`LINE_FOOD_LOGIN_CHANNEL_ID` ที่ `line-link` ใช้ verify) — `sub` จะตรงกับ `line_links.line_user_id` โดยโครงสร้าง ตัด L-6 ทิ้ง | แนะนำให้ Founder ตรวจก่อนว่า channel เดิมมีแพลตฟอร์ม Web app และ Published หรือไม่ ถ้าไม่ได้ค่อยสร้างใหม่ใน Provider เดียวกัน |

### 1.2 ขอบเขต implement ขั้นต่ำที่ปลอดภัย (Minimum Safe Scope)

ทุกข้อเป็นเงื่อนไขบังคับ; ข้อใดไม่ผ่านถือว่าไม่ผ่าน Technical Gate

1. **Feature flag ปิดเป็นค่าเริ่มต้น:** `NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED` ไม่ตั้ง = ปิด; ค่าที่เปิดต้องเป็น `"1"` ตรง ๆ เท่านั้น (ไม่ truthy กว้าง); ปิดแล้วปุ่ม/โค้ด LINE ไม่ render และไม่เรียก `signInWithOAuth`
2. **ปุ่มเฉพาะฝั่งลูกค้า food/ZOKY:** วางใน `FoodLoginScreen` (`food-auth.tsx`) เท่านั้น **ไม่แตะ** `web/components/auth-flow/screens.tsx` ของ Social, ไม่แตะ Merchant app/Admin, ไม่แตะ `/auth/callback` (Social)
3. **ไม่ auto-merge ด้วยอีเมล:** ไม่ขอ scope `email` (`scopes = openid profile` — หรือ `openid` อย่างเดียวถ้า UI ไม่ต้องแสดงชื่อ) + `email_optional = true`; ห้ามมีโค้ดค้น/จับคู่ user ด้วย email, phone หรือชื่อ ในทุกชั้น (client, Edge Function, SQL)
4. **ตัวระบุตัวตน = ID token claim `sub` เท่านั้น:** ผ่าน `auth.identities` (`provider='custom:line'`, `provider_id = sub`) ที่ Supabase เติมเอง; ห้ามใช้ `name`, `picture`, `email`, `user_metadata` หรือ `liff.getProfile().userId` ฝั่ง client เป็นตัวระบุหรือเงื่อนไข authorization; staging ต้องยืนยันว่า `provider_id` ตรง `sub` ของ ID token (T-A16)
5. **nonce / state / PKCE:** ใช้ของ Supabase (`flowType: "pkce"` ใน `web/lib/supabase/browser.ts` ตั้งไว้แล้ว); `skip_nonce_check = false`; ห้ามตั้ง `acceptable_client_ids` เพิ่ม; ห้ามเขียน state/nonce เอง
6. **Callback:** ใช้ `/food/auth/callback` เดิม (exact, ไม่มี query) ทั้งใน **LIFF WebView** (redirect เต็มหน้าในหน้าต่างเดียวกัน) และ **iOS Home Screen PWA** (ใช้ popup path เดิม: `isInstalledIosWebApp()` → `window.open` เปิดก่อน await, ส่งเฉพาะ one-time `code` กลับ opener ที่ถือ PKCE verifier, ไม่ส่ง access/refresh token) และ browser ปกติ; ห้ามเพิ่มพารามิเตอร์ปลายทาง (`to`/`next`/`redirect`) ใน callback ใหม่
7. **การคืนตะกร้า/ร้านหลัง login (ไม่ต้องมี server cart):**
   - ตะกร้า guest และ "ร้านที่เปิดอยู่" อยู่ใน `sessionStorage` ของ webview เดียวกัน (`wynos-food-guest-basket-v1`, `rememberSharedFoodStore`) — redirect เต็มหน้าไป `access.line.me` แล้วกลับมา origin เดิมใน top-level browsing context เดิม ควรคงอยู่ (**ต้องยืนยันบนเครื่องจริง** T-A14)
   - ปลายทางหลัง login ในกรณีสแกน QR/เข้าผ่าน `/line`: ใช้กลไกเดิมคือ `rememberLineAutoLink` → `takeLineAutoLink` (allowlist ด้วย `safeLineDestination`, อายุ 30 นาที) ซึ่งทำงานอยู่แล้วหลัง login ด้วยอีเมล; ปุ่ม LINE Login ใหม่ต้องคงสัญญาเดียวกัน (ไม่ล้าง key นี้ก่อน redirect)
   - ถ้า sessionStorage ถูกล้าง (LINE ปิด/รีสตาร์ท webview, EC-L7): แสดงข้อความให้เลือกร้านใหม่ ไม่ error ขาว — **ห้ามแก้ด้วย server cart (design B ยังไม่อนุมัติ)**
8. **Open redirect:** ปลายทางทุกจุดผ่าน `safeLineDestination("food", …)` เดิมเท่านั้น; `redirectTo` ที่ส่งให้ Supabase เป็น URL คงที่ประกอบจาก `foodAuthOrigin()` (origin ที่รู้จัก) + `/food/auth/callback` ไม่รับอินพุตผู้ใช้
9. **ไม่ขยายสิทธิ์:** ผู้ใช้ LINE ได้สิทธิ์เท่าลูกค้า food ทั่วไป (ผ่าน RLS/`food_customer_access_enabled()` เดิม) ไม่มี role/สิทธิ์เพิ่ม; ไม่เขียน/แก้ policy
10. **ไม่แตะ:** `line-webhook`, schema `line_links`, Merchant, design B, secrets, payment flow
11. **Logging:** log เฉพาะ event + รหัสเหตุผล (`line_login_started/succeeded/failed`) ไม่ log token, `sub` เต็ม, ชื่อ, รูป; ไม่ใส่ code/token ใน URL ที่ถูก log (callback เรียก `history.replaceState` ล้าง `?code=` อยู่แล้ว ให้คงไว้)
12. **Dependency:** ไม่เพิ่ม dependency ใหม่ (ใช้ `@supabase/supabase-js` เดิม; ไม่ใช้ `@line/liff` เพื่อทำ login ใหม่ใน PR นี้)

### 1.3 ผลตรวจโค้ด baseline ที่มีผลต่อ design (หลักฐานจริง)

- `web/components/food/food-auth.tsx` — `google()` ใช้ callback exact `/food/auth/callback`; PWA path ใช้ `GOOGLE_PWA_*` + `isInstalledIosWebApp`; หลัง login สำเร็จ `window.location.replace("/food")` (อีเมล) หรือ `foodHomeUrl()` (callback) → จุดที่ `FoodCustomerInner` อ่าน `takeLineAutoLink()` ได้ ปุ่มใหม่จึง reuse ได้โดยไม่ต้องมีเส้นทางคืนปลายทางใหม่
- `web/app/food/auth/callback/page.tsx` — provider-agnostic ยกเว้นข้อความ; มี `registerCurrentAccount`; ล้าง `?code=` ด้วย `replaceState`; ไม่รับ `to/next` เลย (ปลอดภัยต่อ open redirect โดยโครงสร้าง) ข้อสังเกต: `params.has("error")` ถูก throw เป็น error generic
- `web/app/auth/callback/page.tsx` (Social) — มี `next` + `isSafeReturnPath` แต่ default ไป `/signup/step-1` → ห้ามใช้เป็น callback ของ LINE
- `web/lib/google-pwa-oauth.ts` — `startGoogleOAuth` ฮาร์ดโค้ด google + `prompt: select_account`; ตรวจ URL ที่ได้จาก Supabase ต้อง origin เดียวกับ `NEXT_PUBLIC_SUPABASE_URL` (ควรคงไว้ เพราะป้องกัน OAuth URL ปลอม)
- `web/next.config.ts` redirects — กฎ `openExternalBrowser` **ยกเว้น LIFF browser** (UA `Line/x.y.z LIFF` หรือ `LIFF/SubWindow`) และ `?code=` แต่ **ไม่ยกเว้น `?error=...`** และ chat-link browser ธรรมดา (ไม่ใช่ LIFF) ผลคือ: ใน LIFF ได้ใช้ LINE Login ได้ตามปกติ; ผู้ใช้ที่ cancel ที่หน้า LINE ใน **in-app browser ที่ไม่ใช่ LIFF** จะถูกเด้งออก Safari (T-A3/T-A14) — แนะนำให้แสดงปุ่ม LINE Login **เฉพาะเมื่อ `isLineInAppBrowser` และ `liff.isInClient()` เป็นจริง** ในรอบแรก (นอก LINE ใช้ Google/อีเมลเดิม) ลดพื้นที่ทดสอบและตัดกรณี PWA/desktop ที่ยังไม่ยืนยัน
- Trigger `wynos_profile_on_auth_insert` (migrations_wynos_food_profile_integrity_v1.sql) สร้าง `profiles` ให้ทุก non-anonymous user — ผู้ใช้ LINE จะมีแถว `profiles` ที่ `username = null` เหมือนผู้ใช้ food อื่น (ไม่ต้องผ่าน Social onboarding); trigger `wynos_merchant_auth_user_created` ถูก drop แล้วใน `migrations_wynos_merchant_shared_auth_v1.sql` (ไม่มี auto-merchant) — **ต้องยืนยันว่า migration นี้ถูก apply บน production จริง** (ไม่ได้เชื่อม DB)
- `supabase/functions/line-link/index.ts` (ใน working tree หลัก ไม่อยู่ใน rc-wt) — verify LIFF ID token ด้วย `LINE_FOOD_LOGIN_CHANNEL_ID`, ย้าย link ระหว่างบัญชี (ข้อ P7); `line_links` มี `unique (audience, line_user_id)` และ RLS select/delete เฉพาะของตัวเอง ไม่มี insert/update policy (ดี)
- `rc-wt` ไม่มี source ของ `line-link`/`line-webhook`/migration `line_links` — ตรวจ deployment จริงของฟังก์ชันไม่ได้จาก tree นั้น

### 1.4 ความเสี่ยงทางสถาปัตยกรรมที่ CTO ยอมรับ / ไม่ยอมรับ

- **ยอมรับ:** ผู้ใช้ Google เดิมที่ใช้ LINE Login จะได้บัญชีใหม่ (ประวัติออเดอร์เก่าอยู่ที่บัญชีเดิม) — ตรงกับ D-4 ต้องมี copy ชัดเจนที่ปุ่ม
- **ยอมรับ:** พึ่งพา LINE เป็น IdP ภายนอก; ผู้ใช้ LINE-only ไม่มีอีเมล (ไม่มีกู้บัญชีทางอีเมล แต่ login LINE ซ้ำเข้าบัญชีเดิมด้วย `sub` เดิม)
- **ไม่ยอมรับ:** การปิด provider เป็นวิธี rollback ปกติ (ล็อกผู้ใช้ LINE-only) — ดูข้อ 4.3
- **ไม่ยอมรับ:** การเปิด manual linking ใน project ก่อนผ่านการทดสอบ (P3)

---

## 2. ส่วน B — QA & Security: Threat model ที่อัปเดต และ Test matrix

### 2.1 ความเห็นต่อ threat model เดิม

Threat model เดิม (L-1…L-12) ครอบคลุมดี เพิ่มเติม/ปรับจากการอ่านโค้ด:

| # | ภัยเพิ่ม/ปรับ | ที่มา |
|---|---|---|
| R-1 | **Notification hijack ที่เกิดอัตโนมัติ** (ปรับ L-8 จาก MEDIUM เป็น HIGH) | LINE Login + auto-link ใน LIFF ทำให้ผู้ใช้ Google เดิมสร้างบัญชีใหม่แล้ว `line-link` ย้าย link อัตโนมัติ (ข้อ P7) |
| R-2 | **Account takeover ผ่านอีเมล** (L-1/L-2 คงไว้ CRITICAL) | Supabase auto-link ด้วย verified email — กันด้วยการไม่ขอ `email` scope; แต่เป็น config ที่ผิดพลาดแล้วเปลี่ยนภายหลังได้ (เช่น มีคนเปิด scope email ทีหลังใน Dashboard) → ต้องมี test ที่รันซ้ำทุกครั้งที่แก้ config provider |
| R-3 | **userId/`sub` ซ้ำหรือไม่ตรง:** (ก) LINE channel คนละ Provider ให้ `sub` คนละค่า → คนเดียวได้ 2 บัญชี/`line_links` ไม่ตรง; (ข) แถว `line_links` ซ้ำ `line_user_id` ถูกกันโดย `unique (audience, line_user_id)` แต่ `line-link` ลบแถวเก่าก่อน upsert (ไม่ atomic) | L-6 + code `line-link` |
| R-4 | **ผู้ใช้ LINE-only ถูกล็อก** ถ้าปิด provider หรือ LINE channel ถูกระงับ/เปลี่ยน secret | L-10 คงไว้ MEDIUM; ยกเป็น HIGH ถ้าไม่มีแผน recovery ก่อนเปิดทั่วไป |
| R-5 | **Callback open redirect / destination injection** | L-4; baseline callback ไม่รับ `to/next` เลย (ปลอดภัยโดยโครงสร้าง) แต่ `takeLineAutoLink` ต้องผ่าน allowlist ทุกครั้งที่อ่าน (ทำอยู่แล้ว) |
| R-6 | **PKCE verifier หาย** (LINE ล้าง webview / เปิดใน tab ใหม่) → exchange ล้ม | ต้องมี error state ที่พากลับ `/food/login` พร้อมตะกร้า (ไม่ค้างหน้าโหลด) |
| R-7 | **Provider เป็นระดับ project (ไม่ใช่ food-only)** → D-5 บังคับไม่ได้ที่ provider | `signInWithOAuth` ตรง ๆ จาก origin ใดก็ได้ที่ redirect allowlist ให้; ผู้ใช้ LINE จะได้ `auth.users` + `profiles` เท่านั้น ไม่ได้สิทธิ์ Merchant/Admin (ต้องผ่าน approval/allowlist เดิม — **ยังไม่ได้ตรวจ allowlist ของ Admin ว่าผูกกับ email หรือ uid**) |
| R-8 | **Rate limit / signup abuse** — LINE Login เปิดให้สร้าง `auth.users` ได้ไม่ต้องยืนยันอีเมล | ผู้โจมตีสร้างบัญชีจำนวนมากด้วย LINE ปลอมได้ยากกว่าอีเมล (ต้องมี LINE account จริง) แต่ต้องตรวจ Auth rate limits บน staging |
| R-9 | **PII ใน `user_metadata`** (`name`, `picture` จาก scope `profile`) | เก็บเฉพาะที่จำเป็น; ไม่ log; privacy policy ต้องอัปเดต |

### 2.2 Severity ของจุดเสี่ยง (สรุป)

| ความเสี่ยง | Severity | ผลต่อ release |
|---|---|---|
| Supabase merge บัญชี LINE เข้าบัญชี Google/email เดิมด้วยอีเมลเดียวกัน (R-2/T-A1) | **CRITICAL** | block release |
| `linkIdentity`/callback ผูก LINE ของคนหนึ่งเข้าบัญชีอีกคน (T-A5) — *ใช้เฉพาะเมื่อทำ PR-6* | **CRITICAL** | block PR-6 |
| ID token/nonce/aud ปลอมถูกยอมรับ (T-A7) | **CRITICAL** | block release |
| `line-link` ย้าย notification link เงียบ ๆ จากบัญชีเก่าไปบัญชี LINE ใหม่ (R-1/T-A6) | **HIGH** | ต้องแก้ (PR-4) หรือ Founder ลงนามรับความเสี่ยง |
| Open redirect ผ่าน callback/destination (T-A4) | **HIGH** | ต้องแก้ก่อน release |
| Regression Google/email login (T-A8) | **HIGH** | ต้องแก้ก่อน release |
| ผู้ใช้ LINE-only ล็อกเมื่อปิด provider / ไม่มี recovery plan (R-4/T-A11) | **HIGH** ถ้าไม่มี plan, **MEDIUM** ถ้ามี | ต้องมี plan ก่อนเปิดทั่วไป |
| `unlinkIdentity` เหลือ identity เดียว (T-A9) — *เฉพาะ PR-6* | **HIGH** | block PR-6 |
| Log/analytics/bundle รั่ว token/`sub`/ชื่อ (T-A12) | **HIGH** | ต้องแก้ก่อน release |
| Merchant/Social login ถูกกระทบ (T-A13) | **HIGH** | ต้องแก้ก่อน release |
| provider ระดับ project เรียกจาก origin อื่นได้ (R-7) | **MEDIUM** | ต้องมี owner + ยอมรับเป็นลายลักษณ์อักษร |
| `auth.users.email = null` กระทบ flow (T-A2/T-A15) | **MEDIUM** | แก้ก่อน release ถ้า flow ล้ม |
| Provider/channel ไม่ตรงทำให้ `sub` ไม่ตรง (R-3/T-A10) | **MEDIUM** | checklist ก่อนเปิด |
| PKCE verifier หาย/ยกเลิกที่หน้า LINE (R-6/T-A3) | **LOW–MEDIUM** | UX error state |
| Account enumeration ผ่านข้อความ (L-9) | **LOW** | track |

### 2.3 Test matrix ที่ต้องผ่านก่อน release

ใช้ **staging + LINE channel/OA ทดสอบ + บัญชีและข้อมูลสังเคราะห์เท่านั้น** (ไม่ใช้ production, ไม่ใช้ข้อมูลลูกค้าจริง) ทดสอบซ้ำทุกครั้งที่แก้ config ของ provider

| ID | กรณี | ผลที่ต้องได้ | Severity ถ้าล้ม |
|---|---|---|---|
| T-A1 | **Account takeover ผ่านอีเมล:** สร้างผู้ใช้ Google/email ทดสอบ ที่อีเมลตรงกับอีเมลของบัญชี LINE ทดสอบ แล้ว login ด้วย LINE (1) ตามค่า production (ไม่ขอ email) (2) จำลองกรณีบังเอิญเปิด scope email บน staging เพื่อวัดว่ารุนแรงแค่ไหน | (1) ได้ `auth.users` คนละ id เสมอ บัญชีเดิมไม่ถูกแตะ (2) บันทึกพฤติกรรม ใช้เป็นหลักฐานว่าห้ามเปิด scope email | CRITICAL |
| T-A1b | **Pre-account takeover:** ผู้โจมตีสมัครอีเมลของเหยื่อ (ยังไม่ยืนยัน) ก่อน แล้วเหยื่อ login LINE | ไม่เกิด merge; ไม่มีใครได้ session ของอีกฝ่าย | CRITICAL |
| T-A2 | LINE ไม่ส่งอีเมล (`email_optional`) | สร้างบัญชีสำเร็จ ไม่ error ค้าง; `profiles` ถูกสร้าง | MEDIUM |
| T-A3 | ผู้ใช้กดยกเลิก/ปฏิเสธที่หน้า LINE (`?error=access_denied`) ทั้งใน LIFF และ in-app browser ธรรมดา | กลับ `/food/login` พร้อมข้อความ ไม่ค้าง ตะกร้าไม่หาย; ไม่ถูกเด้งออก Safari ใน LIFF | LOW |
| T-A4 | **Callback/destination open redirect:** ทดสอบ `to` ที่ autolink/return อ่านได้: `https://evil.test`, `//evil.test`, `/\evil.test`, `javascript:`, `%2f%2f`, `%5c`, double-encode, CRLF, ซ้ำ, ยาว >64, `/s/` ผิดรูป; และ `/food/auth/callback?next=https://evil.test` | ไปเฉพาะ `/food`/store/order ที่ allowlist; พารามิเตอร์เกินเพิกเฉย | HIGH |
| T-A5 | `linkIdentity` โดยไม่มี session / state เก่า / state ของผู้ใช้อื่น — *เมื่อทำ PR-6* | ปฏิเสธ; ไม่ผูก LINE เข้าบัญชีอื่น; `identity_already_exists` เมื่อ LINE นั้นผูกบัญชีอื่นแล้ว | CRITICAL |
| T-A6 | **line_links ย้ายเงียบ ๆ:** บัญชี A (Google) ผูก LINE userId U แล้ว; login LINE (sub=U) เป็นบัญชี A′ ใน LIFF ที่ auto-link ทำงาน | หลังแก้ PR-4: link ของ A ไม่ถูกลบโดยไม่มีการยืนยันชัดเจน; A′ ได้ข้อความอธิบาย; ไม่มีการเปลี่ยนแปลงลับ; ก่อนแก้ ให้บันทึกพฤติกรรมเป็นหลักฐาน | HIGH |
| T-A6b | **userId ซ้ำ:** สองบัญชีพยายามผูก U พร้อมกัน (race); `unique (audience, line_user_id)` ทนต่อ delete→upsert ที่ไม่ atomic | เหลือ 1 แถว ไม่มี 2 บัญชีรับข้อความเดียวกัน; error ที่ผู้แพ้ race สุภาพ | HIGH |
| T-A7 | ID token ปลอม/หมดอายุ/`aud` ผิด/nonce ผิด/`iss` ผิด (เลียนแบบ callback ด้วย code ปลอม, code ซ้ำ, code ของ client อื่น) | Supabase ปฏิเสธ; callback แสดง error; ไม่มี session | CRITICAL |
| T-A8 | Login Google และอีเมลเดิม (browser, LIFF, iOS PWA) หลังเพิ่ม LINE | ทำงานเหมือนเดิม (regression) รวม `select_account` ของ Google ยังอยู่ | HIGH |
| T-A9 | `unlinkIdentity` เมื่อเหลือ identity เดียว — *เมื่อทำ PR-6* | ปฏิเสธ; ยัง login ได้ | HIGH |
| T-A10 | LINE Login channel คนละ Provider กับ OA/LIFF | ตรวจเจอจาก checklist ก่อนเปิด flag; `sub` เทียบกับ `line_links.line_user_id` ตรงกัน | MEDIUM |
| T-A11 | **ผู้ใช้ที่มีแต่ LINE ถูกล็อกถ้าปิด provider:** (1) ปิดปุ่ม/flag → session เดิมยังอยู่ ผู้ใช้ใหม่ไม่เห็นปุ่ม (2) disable provider บน staging → วัดว่า session/refresh เดิมยังทำงานไหม และผู้ใช้ที่ logout แล้วเข้าได้ไหม | (1) ไม่มี error ขาว (2) บันทึกผลจริงเป็นหลักฐานของ rollback plan; ยืนยันว่ามีทางเข้า recovery ที่ Founder รับรู้ | HIGH |
| T-A12 | Log/analytics/network/client bundle/URL ค้างใน history | ไม่มี token, `sub` เต็ม, ชื่อ, picture, secret; `?code=` ถูกล้างหลัง exchange | HIGH |
| T-A13 | Merchant app, Admin, Social login | พฤติกรรมไม่เปลี่ยน; ไม่มีปุ่ม LINE; ผู้ใช้ LINE ที่เรียก API ตรง ๆ ไม่ได้สิทธิ์ Merchant/Admin | HIGH |
| T-A14 | LINE in-app บน iOS/Android จริง (LIFF), LINE Desktop, in-app ธรรมดา (ไม่ใช่ LIFF), iOS Home Screen PWA, Safari/Chrome ปกติ | flow สำเร็จหรือมี fallback ชัดเจน; sessionStorage ตะกร้า+ร้านยังอยู่หลัง redirect; ไม่ถูก `openExternalBrowser` เด้งกลางทาง | MEDIUM |
| T-A15 | ผู้ใช้ `email = null` ในทุก flow ลูกค้า: สั่ง, ชำระ (Stripe `customer_email` ว่าง), ตั้งค่าบัญชี, account switcher, notification | ไม่ crash; ข้อความไม่แสดง `null`/`undefined` | MEDIUM |
| T-A16 | ตรวจ `auth.identities`: `provider='custom:line'`, `provider_id` = `sub` ของ ID token; ไม่มี identity ของผู้ใช้อื่นชี้บัญชีเดียวกัน | ตรงกัน และเทียบได้กับ `line_links.line_user_id` | HIGH |
| T-A17 | Direct API bypass: เรียก `signInWithOAuth('custom:line')` จาก origin อื่นที่ไม่อยู่ใน redirect allowlist และเรียก authorize ด้วย `redirect_to` นอก allowlist | ถูกปฏิเสธ/fallback Site URL ไม่ redirect ไปโดเมนภายนอก | HIGH |
| T-A18 | Flag ปิด (ค่าเริ่มต้น) | ไม่มีปุ่ม ไม่มีการเรียก LINE; bundle ไม่ทำ network ไปหา `access.line.me`; regression ทั้งหน้า login | MEDIUM |
| T-A19 | Rate limit / spam: login LINE ซ้ำเร็ว ๆ, สร้างบัญชีจำนวนมากด้วยบัญชี LINE ทดสอบ | ถูก limit ตาม Auth config; ไม่ crash | MEDIUM |

เกณฑ์ผ่าน Gate: ไม่มี CRITICAL; HIGH ทุกข้อแก้แล้วหรือมีบันทึกรับความเสี่ยงจาก Founder; MEDIUM มี owner/แผน; มีหลักฐานการทดสอบ (วันที่ ผู้ทดสอบ อุปกรณ์/OS ผลลัพธ์) ที่ audit ได้ โดยไม่ใส่ข้อมูลส่วนตัวจริง

---

## 3. สิ่งที่ Founder / เจ้าของระบบต้องทำเอง (AI ทำแทนไม่ได้)

**กติกาข้อมูลลับ:** ห้ามพิมพ์/ส่ง Channel ID, Channel secret, anon/service key, token ใด ๆ เข้าแชทหรือ commit ให้พิมพ์ค่าลงในช่องของ Dashboard โดยตรงเท่านั้น AI จะไม่ขอและไม่อ่านค่าเหล่านี้ ถ้าต้องการให้ AI ช่วยตรวจ ให้ส่งเฉพาะภาพหน้าจอที่ **ปิดบังค่า secret** หรือบอกว่า "ตั้งแล้ว/ยังไม่ตั้ง"

ทำตามลำดับ (ทุกขั้นทำจากมือถือหรือเว็บได้ผ่านเบราว์เซอร์)

### ขั้น 0 — ตัดสินใจ/อนุมัติ (ก่อนทุกอย่าง)
1. ตอบ Founder gate ข้อ 5 และให้บันทึกใน `.wyn/company/APPROVALS.md` (รวมการ waive baseline และการ **ไม่รวม design B**)

### ขั้น 1 — LINE Developers Console (developers.line.biz)
1. เข้าสู่ระบบด้วยบัญชี LINE ที่เป็นเจ้าของ Provider ของ "Zoky • สั่งอาหาร"
2. เลือก Provider เดียวกับ OA ลูกค้า (ห้ามสร้างคนละ Provider มิฉะนั้น `sub` ไม่ตรง)
3. **ทางที่แนะนำ:** เปิด **LINE Login channel เดิมที่เป็นเจ้าของ LIFF ของ food** (ช่องที่ใช้ verify ID token ของ `line-link`) → แท็บ *LINE Login* → ตรวจว่าเปิดใช้ "Web app"; ถ้าไม่มี ให้สร้าง LINE Login channel ใหม่ชนิด *Web app* ใน Provider เดียวกัน
4. ในแท็บ *LINE Login* ช่อง **Callback URL** ใส่ URL ที่ Supabase แสดงให้ในขั้น 2 (รูปแบบ `https://<project-ref>.supabase.co/auth/v1/callback`) — **ใส่ URL นี้เท่านั้น ไม่ต้องใส่โดเมน ZOKY**
5. ในแท็บ *OpenID Connect* **ไม่ต้องขอสิทธิ์ Email address** (ปล่อยว่าง/ไม่ยื่นขอ) นี่คือเงื่อนไข D-4
6. ในแท็บ *Basic settings* คัดลอก Channel ID และ Channel secret เก็บไว้ในที่ปลอดภัย (ใช้วางในขั้น 2 เท่านั้น ห้ามส่งแชท)
7. เปลี่ยนสถานะ channel จาก *Developing* เป็น **Published** (ถ้าไม่ Published จะเข้าได้เฉพาะแอดมิน/ผู้ทดสอบ) — ทำบน staging/ทดสอบก่อน
8. เข้า Supabase (ขั้นถัดไป) ด้วยบัญชีเจ้าของ project

### ขั้น 2 — Supabase Dashboard (project **staging ก่อน** production)
1. Authentication → *Sign In / Providers* (หรือ *Third-party / Custom providers*) → *Add provider* → *OIDC*
2. ใส่ค่า: Identifier `custom:line` · Issuer `https://access.line.me` (ให้ Supabase ดึง discovery เอง) · Client ID = Channel ID · Client secret = Channel secret (พิมพ์ลงช่องเอง) · Scopes `openid profile` (หรือ `openid`) · **เปิด `email_optional`** · **ปิด `skip_nonce_check`** · PKCE เปิด · ห้ามใส่ `acceptable_client_ids`
3. คัดลอก Callback URL ที่ Supabase แสดง ไปวางที่ LINE Developers (ขั้น 1.4)
4. Authentication → *URL Configuration* → ตรวจว่ารายการ Redirect URLs มี `https://zoky.wynos.online/food/auth/callback` (และ `https://food.wynos.online/food/auth/callback` ถ้ายังใช้) อยู่แล้ว (เป็น URL เดียวกับ Google; **ไม่ต้องใช้ wildcard**) ถ้ามี wildcard กว้างให้แจ้ง CTO
5. **อย่าเปิด "manual linking" ในรอบนี้** (รอ PR-6 และผลทดสอบ)
6. ตรวจว่า provider นี้ **Enabled เฉพาะ staging**; production ปล่อยปิด (Disabled) จนกว่า Founder สั่งเปิดในขั้น "Release"
7. จดจำนวน custom provider ที่ใช้อยู่ (Free plan จำกัด 3) และ plan ของ project แจ้งผลให้ทีม (บอกเพียง "ใช้ได้/ไม่ได้")

### ขั้น 3 — Vercel (ตั้ง env flag)
1. Vercel → project ของ web → Settings → Environment Variables
2. เพิ่ม `NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED` = `1` **เฉพาะ environment Preview/Staging** (ไม่ใช่ Production) — ค่า `NEXT_PUBLIC_*` เป็น build-time ต้อง redeploy ถึงมีผล
3. ปล่อย Production ไม่ตั้งค่า (= ปิด) จนกว่าจะ Release
4. ห้ามเพิ่มค่า secret ใด ๆ ในตัวแปร `NEXT_PUBLIC_*`

### ขั้น 4 — ทดสอบ (ผู้ทดสอบ: ระบุตาม D-7)
1. เตรียมบัญชี LINE ทดสอบ 2 บัญชี (A, B) และบัญชี Google ทดสอบที่มีอีเมลเดียวกับ A เพื่อทำ T-A1
2. เปิดลิงก์ staging ในแอป LINE บนมือถือ (iOS 1 เครื่อง Android 1 เครื่อง) ทำตามเมทริกซ์ ส่งผลเป็นข้อความ/ภาพที่ไม่มีข้อมูลส่วนตัว

### ขั้น 5 — Release (เมื่อ QA/CTO ผ่านและ Founder สั่ง)
1. Supabase production: Enable provider `custom:line` (ใส่ค่าด้วยตนเองเหมือนขั้น 2)
2. Vercel production: ตั้ง `NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED=1` แล้ว Redeploy
3. ตรวจ smoke test ตามข้อ 4.2 แล้วรายงานผล

### ขั้น 6 — ฉุกเฉิน (rollback)
ดูข้อ 4.3 (ตั้ง flag เป็นว่าง/ลบตัวแปร แล้ว Redeploy หรือ Vercel → Deployments → Promote deployment ก่อนหน้า; ไม่ปิด provider เว้นแต่เหตุด้านความปลอดภัย)

---

## 4. แผน implement เป็นขั้น (PR เล็ก ๆ) และ Rollback

หลักการ: PR ละหนึ่งหน้าที่, ทุก PR merge ได้โดยพฤติกรรม production ไม่เปลี่ยน (flag ปิด), ไม่มี migration, ไม่มี dependency ใหม่, **ไม่มี design B** ตาม AGENTS.md การ commit/push/merge/deploy ต้องมี Founder อนุมัติแต่ละครั้ง และใช้ branch แยกจาก production branch (ห้าม force push)

| PR | เนื้อหา | ไฟล์หลัก (ประมาณ) | ทดสอบ | Gate |
|---|---|---|---|---|
| **PR-0** (เอกสาร) | บันทึก APPROVAL_REQUIRED ใน `.wyn/company/APPROVALS.md`: อนุมัติ T1 ที่ปรับ, waive baseline, **ไม่รวม B**; ADR-1…3 | `.wyn/company/APPROVALS.md`, `docs/architecture/…` | – | Founder |
| **PR-1** helper + flag (ไม่มี UI) | ฟังก์ชัน `isLineLoginEnabled()` (อ่าน flag แบบเข้มงวด `=== "1"`), `LINE_LOGIN_PROVIDER = "custom:line"`, scope/queryParams ของ provider; generalise `startGoogleOAuth` → รับ provider โดยค่าเริ่มต้นยัง Google และ **ไม่ส่ง `select_account` ให้ LINE** | `web/lib/google-pwa-oauth.ts` (หรือแยกฟังก์ชันบางๆ ในไฟล์เดียวกัน), `web/lib/line-liff.ts` | unit test (node --test ตามแบบ `tests/google-pwa-oauth.test.mjs`): flag ปิดเป็นค่าเริ่มต้น, ค่าแปลกไม่เปิด, Google ไม่เปลี่ยน | Implementation |
| **PR-2** ปุ่ม + callback copy | ปุ่ม "เข้าสู่ระบบด้วย LINE" + copy D-4 ("LINE จะสร้างบัญชีใหม่ ถ้าเคยใช้ Google ให้เข้าด้วย Google") ใน `FoodLoginScreen` เฉพาะเมื่อ flag เปิด **และ** `isLineInAppBrowser` + `liff.isInClient()`; ใช้ `/food/auth/callback` เดิม; เปลี่ยนข้อความ callback ให้เป็นกลางต่อ provider; state loading/error/cancel; ไม่ล้าง `zoky.line-autolink.v1` | `web/components/food/food-auth.tsx`, `web/app/food/auth/callback/page.tsx`, `web/components/food/line-login-guidance.tsx` (ถ้าจำเป็น), css เดิมของ `wf-auth-*` | unit/ component test (flag ปิด = ไม่มีปุ่ม; ปลายทางผ่าน allowlist), `npm run test:line`, lint, typecheck, build; a11y: ปุ่มมี label/focus/disabled state; mobile-first | Implementation |
| **PR-3** QA harness | test mock (ไม่ต่อ LINE จริง): `safeLineDestination` กับ payload T-A4, callback ไม่รับ `to/next`, flag/ปุ่ม, อีเมล null ใน account registry; Playwright mock Supabase loopback ตามแบบ `google-pwa-oauth` | `web/tests/*.test.mjs`, `web/tests/browser/*` | ทั้งหมดผ่าน | QA |
| **staging gate** | Founder ทำขั้น 1–3 บน staging; QA รัน T-A1…T-A19 บนเครื่องจริง; CTO ตรวจผล | – | เมทริกซ์ในข้อ 2.3 | QA & Security + Staging |
| **PR-4** (แยก, HIGH) guard `line-link` | ป้องกันการย้าย link อัตโนมัติ: เมื่อ `line_user_id` ถูกถือโดยบัญชีอื่น ให้ตอบ `409 already_linked_elsewhere` ไม่ลบ และ UI แจ้งผู้ใช้ให้เลือก (ย้ายโดยกดยืนยันชัดเจนเท่านั้น); ไม่เปลี่ยน schema; ไม่แตะ `line-webhook` | `supabase/functions/line-link/*`, `web/components/line/line-entry.tsx` | Deno test + test ใน T-A6/T-A6b | CTO + QA + Founder (แก้ Edge Function production) — **หรือ** Founder ลงนามรับความเสี่ยง (ข้อ 5) แล้วข้าม |
| **PR-5** privacy/ข้อความ | อัปเดตนโยบายความเป็นส่วนตัว (ใช้ LINE userId/ชื่อโปรไฟล์เพื่อ login) และ copy แนะนำเพิ่มวิธีเข้าสู่ระบบสำรอง | ตาม policy ของ Founder | review | Founder |
| **Release** | Founder สั่ง: เปิด provider + flag บน production ตามขั้น 5 → smoke test | – | smoke ข้อ 4.2 | Founder Gate → Production Gate |
| **PR-6** (optional, ภายหลัง) `linkIdentity`/`unlinkIdentity` | หน้าตั้งค่า "ผูก LINE กับบัญชีนี้" สำหรับผู้ใช้ที่ login อยู่ + เปิด manual linking (beta) **หลัง** staging พิสูจน์ T-A5/T-A9 และ Founder ยอมรับ setting ระดับ project | หน้าบัญชี food | T-A5, T-A9 | แยก approval |

### 4.1 การตรวจก่อน merge ทุก PR
- review diff ก่อน commit; commit แบบ conventional (อังกฤษ); ไม่มี secret/ค่า env ใน diff (`git diff` + สแกน)
- รัน `npm run check` ส่วนที่เกี่ยวข้อง (`lint`, `typecheck`, `test:line`, `test:google-pwa-oauth`, `build`) และรายงานผลจริง
- ยืนยันว่าไม่มีไฟล์ใน `supabase/migrations*` หรือ `supabase/functions/food-cart-handoff` ถูกเพิ่ม (B ยังไม่อนุมัติ)

### 4.2 Smoke test หลังเปิดบน production (ผู้ทดสอบทำด้วยบัญชีทดสอบ)
1. ปุ่ม LINE แสดงเฉพาะใน LINE; Google/อีเมลยัง login ได้
2. login LINE ใหม่ → เข้า `/food` ได้ ตะกร้า guest ยังอยู่ → สั่งได้ตามปกติ (ขั้นตอนชำระใช้ของเดิม)
3. ตรวจ log/Auth logs ว่าไม่มี token/`sub` เต็ม (T-A12) และมีค่าอัตรา error ผิดปกติหรือไม่

### 4.3 Rollback (เรียงจากเบาไปหนัก)
1. **ซ่อนปุ่มสำหรับผู้ใช้ใหม่:** ลบ/ตั้งว่าง `NEXT_PUBLIC_ZOKY_LINE_LOGIN_ENABLED` ใน Vercel แล้ว Redeploy (ผลหลัง build — ไม่ใช่ kill switch ทันที)
2. **Vercel rollback:** Deployments → Promote deployment ก่อนหน้า (เจ้าของสั่งเท่านั้น ตาม RULES.md)
3. **Disable provider `custom:line` ใน Supabase:** ใช้เฉพาะเหตุฉุกเฉินด้านความปลอดภัยเท่านั้น (เช่นพบ T-A1 ล้มบน production) เพราะผู้ใช้ LINE-only ที่ออกจากระบบแล้วจะเข้าไม่ได้ ต้องแจ้ง Founder ก่อนและเตรียมประกาศ/วิธี recovery
4. **ไม่ลบ** `auth.users` / `auth.identities` / `profiles` ใด ๆ ใน rollback ทุกชั้น (ไม่มี destructive step)
5. ไม่มี DB migration ใน PR-1…PR-3, PR-5 → ไม่มีการ rollback DB; PR-4 rollback = redeploy Edge Function เวอร์ชันก่อนหน้า

---

## 5. ข้อกำกับที่ต้องให้ Founder อนุมัติเพิ่ม

บันทึกใน `.wyn/company/APPROVALS.md` รูปแบบ `APPROVAL_REQUIRED` (Proposed change / Reason / Benefits / Risks / Files affected / Recommendation) แยกรายการเพื่อให้ตอบทีละข้อได้

| # | เรื่อง | คำแนะนำของ CTO/QA |
|---|---|---|
| F-1 | อนุมัติ **Authentication Architecture Change: T1 ตามฉบับปรับ** (ข้อ 1.1–1.2) และบันทึกการ waive baseline ลงเอกสาร | อนุมัติแบบมีเงื่อนไข: ผ่าน T-A1, T-A1b, T-A7, T-A8, T-A13 ก่อนเปิดบน production |
| F-2 | ยืนยันเงื่อนไข **ไม่ขอ email scope** (ผลข้างเคียง: บัญชี LINE ไม่มีอีเมลสำหรับใบเสร็จ/กู้บัญชี) | ยืนยัน |
| F-3 | **ยืนยันว่า design B ยังไม่อนุมัติ** และห้ามอยู่ใน PR ใด ๆ ของงานนี้ (ไม่มีตาราง/Edge Function/หน้า resume) | ยืนยัน |
| F-4 | **แก้ `line-link` (PR-4)** กัน notification link ถูกย้ายเงียบ ๆ ซึ่งเป็นการแก้ production Edge Function | แนะนำให้ทำ ถ้าไม่ทำ ต้องมีลายลักษณ์อักษร "Founder risk acceptance" ของ T-A6 (HIGH) พร้อมรับทราบว่าผู้ใช้ Google เดิมจะเสียการแจ้งเตือนบัญชีเดิม |
| F-5 | **ใช้ LINE Login channel เดิม (เจ้าของ LIFF) เพิ่ม callback URL ของ Supabase** แทนสร้าง channel ใหม่ | แนะนำ (ลดความเสี่ยง Provider ไม่ตรง) — ต้องให้ Founder ตรวจสถานะ Published |
| F-6 | **Provider ของ Supabase เป็นระดับ project** (กระทบ Social/Merchant/Admin ในเชิงเทคนิค) — ยอมรับ R-7 และให้เปิดบน production เฉพาะเมื่อ Founder สั่ง | ยอมรับพร้อมเงื่อนไข T-A13/T-A17 |
| F-7 | **ไม่เปิด manual linking** ในรอบนี้ ทำ `linkIdentity` เป็น PR-6 แยกอนุมัติ | แนะนำ |
| F-8 | **นโยบายความเป็นส่วนตัว** ต้องอัปเดตก่อนเปิดทั่วไป (ใช้ LINE userId/ชื่อโปรไฟล์ เก็บใน Supabase) | จำเป็นก่อน Release |
| F-9 | **แผน recovery** สำหรับผู้ใช้ LINE-only (เช่น prompt เพิ่ม Google/อีเมลหลังสั่งออเดอร์แรก) — ยอมรับว่าไม่ทำในรอบแรกได้หรือไม่ | ถ้ายอมรับ ต้องห้ามปิด provider เป็น rollback ปกติ |
| F-10 | D-7: ผู้ทดสอบ/อุปกรณ์/บัญชี LINE ทดสอบ/OA ทดสอบ และ baseline branch/commit ที่ใช้ implement (rc-wt `e0bcc109` หรือ branch อื่น) | ต้องระบุก่อนเริ่ม PR-1 |
| F-11 | ขอบเขต scope ของ LINE: `openid profile` (มีชื่อ/รูปใน `user_metadata`) หรือ `openid` อย่างเดียว | แนะนำ `openid` อย่างเดียวถ้า UI ไม่ต้องแสดงชื่อจาก LINE (collect เท่าที่จำเป็น); ถ้าต้องการชื่อให้ใช้ `openid profile` |

---

## 6. รายงานสั้น: ตรวจแล้ว / ยังไม่ได้ตรวจ

**ตรวจแล้ว (จากไฟล์จริง)**
- อ่าน: `AGENTS.md`, `docs/engineering/SECURITY_RULES.md`, `.wyn/company/RULES.md`, เอกสาร design `zoky-line-002-line-login-and-server-cart.md` ทั้งไฟล์, task proposed (Founder decisions D-1…D-8), `docs/qa/zoky-line-002/real-flow-code-analysis.md` (หัวข้อ 2.x)
- อ่านโค้ด production baseline (`rc-wt`): `food-auth.tsx`, `food/auth/callback/page.tsx`, `auth/callback/page.tsx`, `google-pwa-oauth.ts`, `line-liff.ts`, `return-to.ts`, `line-login-guidance.tsx`, `next.config.ts` (redirect rule), `account-registry.ts` (ส่วนที่ใช้ email), `food-origin.ts`, `supabase/config.toml`, migrations `profile_integrity_v1` และ `merchant_shared_auth_v1` (trigger บน `auth.users`), `food-stripe-checkout` (การใช้ `user.email`)
- อ่าน `supabase/functions/line-link/index.ts` และ migration `20261031120000_zoky_line_links.sql` ใน working tree หลัก (RLS, unique, พฤติกรรมย้าย link)

**ยังไม่ได้ตรวจ / ตรวจไม่ได้ (ตามข้อห้าม)**
- ไม่ได้เชื่อม Supabase/LINE/Vercel จริง ไม่อ่าน env/secrets: ไม่ทราบ plan, Auth version, จำนวน custom provider, สถานะ manual linking, Auth rate limits, redirect URL ที่ตั้งไว้จริง, สถานะ Published/แพลตฟอร์ม Web app ของ LINE channel, ว่า migration `merchant_shared_auth_v1` ถูก apply บน production หรือไม่
- ไม่ได้ทดสอบ flow จริง (redirect ใน LIFF/in-app/iOS PWA, `sub` ใน `auth.identities`, พฤติกรรม email = null ใน Supabase, ผลหลัง disable provider) — ทั้งหมดเป็นข้อกำหนดทดสอบบน staging
- ไม่ได้รัน test/lint/build ใด ๆ และไม่ได้เปิด Playwright; ยังไม่ได้ตรวจ allowlist ของ Admin ว่าผูก email หรือ uid; ไม่ได้ตรวจโค้ด checkout/ตะกร้าทุกบรรทัด
- ไม่ได้ตรวจเอกสารทางการของ Supabase/LINE ซ้ำในรอบนี้ — ข้อมูลเรื่อง custom OIDC, `email_optional`, auto-link ด้วยอีเมล และ `signInWithIdToken` อ้างจากผลตรวจในเอกสาร design เดิม; ค่า `prompt` ที่ LINE รองรับอ้างจากความรู้ทั่วไป ต้องยืนยันกับเอกสาร LINE ก่อนแก้ PR-1
- ไม่ได้ review design B (ตามคำสั่ง) และไม่ได้แก้ source / commit / deploy ใด ๆ
- ไม่มีการอ้างว่า "ไม่มี regression" — ยังไม่มีหลักฐานทดสอบ
