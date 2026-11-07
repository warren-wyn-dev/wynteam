# ZOKY-LINE-002 — ทำให้ flow "แอด LINE OA แล้วสั่งอาหารใน LIFF" ใช้ง่ายขึ้น

Status: **Proposed — Founder ตอบ decisions รอบแรกแล้ว (2026-11-07) แต่ยังไม่เริ่ม implement**

## Founder decisions (2026-11-07)

- D-3 LINE Login: **อนุมัติแบบมีเงื่อนไข** — เริ่มหลังวัด baseline usability test และหลัง Architect/CTO ออก design แล้วต้องส่งให้ Founder อนุมัติ design อีกรอบก่อนลงมือ implement
- D-4 บัญชี Google เดิม: **ไม่ auto-merge** ด้วยอีเมล
- D-2 Guest checkout: **ตะกร้าก่อน ล็อกอินตอนสั่ง**
- D-5 ขอบเขต: **เฉพาะลูกค้า (food) ไม่รวม Merchant**
- D-6 ตะกร้าฝั่ง server: **เลือกทำ** แต่เป็นข้อมูล/DB ใหม่ ต้องมี design + migration ที่ผ่าน review และ Founder gate แยกก่อน apply
- Baseline usability test: **ทำก่อนแก้**
- **อัปเดต 2026-11-07:** Founder สั่งเริ่มข้อ 2 (ข้อความแนะนำเปิดเบราว์เซอร์ที่ /food/login) และ **อนุมัติข้อ 3 (LINE Login, design A ใน docs/architecture/zoky-line-002-line-login-and-server-cart.md)** ตามเงื่อนไขเดิม: ยังไม่เริ่ม implement จนกว่าจะวัด baseline usability test และ CTO/QA review design แล้ว; design B (ตาราง cart handoff) **ยังไม่ได้อนุมัติ**
- ยังไม่ได้ตอบ: D-7 (ผู้ดำเนิน test/ผู้ร่วมทดสอบ/OA ทดสอบ), baseline branch/commit, privacy policy
Requested: Founder, 2026-11-07 — แจ้งว่า flow "ลูกค้ากดแอด LINE OA แล้วเข้ามาสั่งใน LINE Mini App/LIFF" ใช้ยาก; Founder เลือกขอบเขต 4 ข้อตามที่ AI เสนอ
Author: AI Product Manager (เอกสารนี้นิยาม WHAT เท่านั้น ไม่มีการแก้ source code)
Related: `.wyn/tasks/approved/ZOKY-LINE-001-line-oa-notifications-liff.md`, APPROVALS.md (หัวข้อ ZOKY-LINE-001, ZOKY store QR, Automatic LINE notification link, Store QR prompts LINE friendship)

> **สำคัญ:** ข้อ 2 (LINE Login) เป็น **Authentication Architecture Change** — ตาม `.wyn/company/RULES.md` และ `AGENTS.md` ต้องได้รับ explicit Founder approval ก่อนเริ่มงานส่วนนั้น และต้องบันทึกใน `APPROVALS.md` ข้อ 1, 3, 4 ไม่แตะ auth architecture จึงอนุมัติแยกกันได้

---

## 1. Current state (ตรวจจาก repo 2026-11-07)

หลักฐานจากไฟล์ใน working tree + APPROVALS.md ที่ตรวจได้จริง:

| เรื่อง | สถานะที่ตรวจพบ | หลักฐาน |
|---|---|---|
| LIFF entry `/line` | มี: เปิดหน้า `/food` หรือ `/food?order=WF…` ตาม allowlist และหน้าเชื่อม/ยกเลิก LINE | `web/components/line/line-entry.tsx`, `web/lib/line-liff.ts` |
| ZOKY-LINE-001 | source implemented; APPROVALS บันทึกว่า backend (`line_links`, `line-link`, `line-webhook`) deployed แบบ inert 2026-10-31 | ZOKY-LINE-001 หัวข้อ 9, APPROVALS |
| Store QR → LIFF (`?to=/s/<code>`), auto-link แจ้งเตือน, friendship prompt ก่อนเปิดร้าน | APPROVALS บันทึกว่า approved และมี release (2026-11-04/05, PR #1335) แต่ **โค้ดใน working tree นี้ยังไม่มีส่วนเหล่านี้** (`safeLineDestination` ใน tree นี้อนุญาตเฉพาะ `/food` และ `/food?order=`; ไม่มี path `/s/`) — แปลว่า working tree นี้ตามหลัง branch/release ที่ deploy แล้ว | `web/lib/line-liff.ts` เทียบกับ APPROVALS 2026-11-04/05 |
| ลูกค้าที่ยังไม่ login เปิด `/food` | **เห็นร้าน/เมนูได้และใส่ตะกร้าได้** (`FoodGuestBrowse`, ตะกร้าเก็บใน sessionStorage/localStorage) แต่ปุ่มสุดท้ายคือ "เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ" แล้วพาไป `/food/login` และกลับมา import ตะกร้า | `web/components/food/wynos-food-developer-app.tsx` (~บรรทัด 3684–3692), `web/components/food/food-guest-browse.tsx` (~บรรทัด 205–212, 538) |
| วิธี login ลูกค้า | Supabase session: Google OAuth + email/password (ไม่มี LINE Login) | ZOKY-LINE-001 หัวข้อ 1; `signInWithOAuth` ใน `web/components/auth-flow/screens.tsx`, `web/lib/google-pwa-oauth.ts` |
| Google ใน LINE in-app browser | Google ปฏิเสธ (`disallowed_useragent`); โค้ดปัจจุบันแก้ด้วยข้อความ "ใช้อีเมล/รหัสผ่านหรือเปิดในเบราว์เซอร์" เฉพาะหน้า `/line?mode=link` — หน้า `/food/login` ไม่พบการตรวจ/แนะนำเรื่องนี้ (ค้นหา LINE ใน `web/app/food/login/page.tsx` ไม่พบ) | `line-entry.tsx`, `web/app/food/login/page.tsx` |
| ขั้นตอน "ใส่เบอร์" | พบการใช้ `phone` ใน food app 10 จุด (น่าจะเป็นเบอร์ติดต่อในที่อยู่/checkout) — **ยังไม่ได้ไล่อ่านทุกจุด** ต้องให้ Architect/Full-Stack ยืนยันก่อนว่าเบอร์เก็บที่ไหนและบังคับตอนไหน | grep `phone` ใน `wynos-food-developer-app.tsx` |

### สรุปปัญหา (สมมติฐานจากโครงสร้างโค้ด — ต้องยืนยันด้วย usability test ข้อ 4)

1. ลูกค้าจาก LIFF มักไม่มี session ZOKY ใน LINE in-app browser → ถึงจุดยืนยันออเดอร์ต้อง login
2. ผู้ใช้ Google (กลุ่มใหญ่) ถูก Google บล็อกใน in-app browser → ทางออกคือกรอกอีเมล/รหัสผ่านที่อาจไม่มี หรือ "เปิดในเบราว์เซอร์" ซึ่งทำให้ออกจาก LINE แล้ว context หลุด
3. การเข้ามาจาก "แอด OA" ตรง ๆ ยังไม่พาเข้าหน้าร้านที่ลูกค้าตั้งใจสั่ง (ถ้าไม่ผ่าน QR ร้าน) ลูกค้าต้องหาร้านเอง
4. guest browse + ตะกร้ามีอยู่แล้ว แต่ **ไม่แน่ใจว่าลูกค้าเห็นและเข้าใจว่า "เลือกเมนูได้ก่อน"** เพราะยังไม่มี usability data

## 2. Goal

ลดจำนวนขั้นตอนและจุดที่ลูกค้าเลิกกลางคันระหว่าง "สแกน QR/กดแอด OA" → "ส่งออเดอร์/ชำระเงินสำเร็จ" โดยไม่ลด security ของ order/payment และไม่กระทบ Web Push, ZOKY-LINE-001

Success metrics (baseline ต้องวัดก่อนตามข้อ 4):
- สัดส่วนผู้เปิดร้านจาก LIFF ที่ส่งออเดอร์สำเร็จ (completion rate)
- เวลาเฉลี่ยจากเปิด LIFF ถึงส่งออเดอร์
- จำนวนครั้งที่ต้องออกจาก LINE (เปิดเบราว์เซอร์ภายนอก) ต่อออเดอร์
- อัตราเลิกที่หน้า login

## 3. Scope และ priority

| # | หัวข้อ | Priority | ต้อง Founder อนุมัติ auth/architecture? |
|---|---|---|---|
| A | Usability test baseline (ข้อ 4, รอบก่อนแก้) | **P0** | ไม่ |
| B | Guest checkout ใน LIFF (ข้อ 1) | **P0** | ไม่ (ไม่เปลี่ยน auth) แต่ต้อง Architect review เรื่อง guest data |
| C | QR/ลิงก์ "แอดเพื่อน + เปิดร้านต่อ" (ข้อ 3) | **P0** (ส่วนที่ deploy แล้ว = ตรวจสอบ/ปิดช่องว่าง) / **P1** (ส่วนใหม่) | ไม่ แต่เพิ่ม allowlist path |
| D | LINE Login เป็น auth method (ข้อ 2) | **P1** (ขึ้นกับผล baseline และการอนุมัติ) | **ใช่ — Authentication Architecture Change** |
| E | Usability test รอบหลังแก้ (ข้อ 4) | **P0** (เป็นเงื่อนไขปิดงาน) | ไม่ |
| F | แจ้งทางออกชัดเจนเมื่อ Google ถูกบล็อกใน LINE ที่ `/food/login` (ทางลัดถ้า D ไม่ได้รับอนุมัติ) | **P0 ถ้า D ยังไม่อนุมัติ** | ไม่ |
| G | Persona/ภาษาอังกฤษ, analytics ละเอียด, เลือกเก็บเบอร์ใน guest | P2 | ไม่ |

ลำดับแนะนำ: A → (B, C, F ทำขนานได้) → ตัดสินใจ D จากผล A → E

---

## 4. ข้อ 1 — Guest checkout ใน LIFF (P0)

เป้าหมาย: ลูกค้าเลือกเมนู/ตะกร้า/ใส่เบอร์ติดต่อได้ก่อน และถูกขอ login เฉพาะตอนจะ "ยืนยัน/ชำระเงิน" เท่านั้น — และกลับมาที่เดิมโดยข้อมูลไม่หาย

หมายเหตุ: ฐานของ guest browse + ตะกร้ามีอยู่แล้ว ข้อนี้คือ **ขยายและทำให้ต่อเนื่องใน LIFF** ไม่ใช่สร้างใหม่ทั้งหมด และ **ไม่อนุญาตให้ guest สร้างออเดอร์โดยไม่มีบัญชี** (ดู D-2)

### User stories
- **US-G1** ในฐานะลูกค้าที่เปิดร้านจาก LIFF โดยยังไม่ login ฉันดูเมนู เลือก ใส่ตัวเลือก/โน้ตลงตะกร้าได้ทันที โดยไม่ถูกเด้งไปหน้า login ก่อน
- **US-G2** ในฐานะลูกค้า guest ฉันกรอกเบอร์ติดต่อ (และที่อยู่ถ้าส่งเดลิเวอรี) ก่อน login ได้ และเมื่อ login เสร็จข้อมูลยังอยู่
- **US-G3** ในฐานะลูกค้า ฉันถูกขอ login เฉพาะตอนกดยืนยันออเดอร์ และหลัง login ฉันกลับมาที่หน้ายืนยันของร้านเดิมพร้อมตะกร้าเดิมใน LIFF ไม่ต้องเริ่มใหม่
- **US-G4** ในฐานะลูกค้าที่ login ไม่สำเร็จ/ยกเลิก ฉันยังเห็นตะกร้าและกดลองใหม่ได้

### Acceptance criteria
- AC-G1 หน้าร้านที่เปิดจาก LIFF แสดงเมนูและเพิ่มตะกร้าได้โดยไม่ต้องมี session; ไม่มี redirect ไป login ก่อนมีสินค้าในตะกร้า
- AC-G2 ปุ่มยืนยันขณะ guest แสดงข้อความชัด เช่น "เข้าสู่ระบบเพื่อยืนยันออเดอร์" และบอกว่าตะกร้าจะไม่หาย
- AC-G3 หลัง login สำเร็จ ผู้ใช้กลับมาที่ร้านเดิมและตะกร้า (รวม options/โน้ต/จำนวน) ถูกนำเข้าครบ — ผ่านทั้งกรณี login ใน LINE in-app browser และกรณีต้องเปิดเบราว์เซอร์ภายนอก (ดู edge case EC-G2)
- AC-G4 ฝั่ง server ทุกการสร้างออเดอร์/quote/ชำระเงินยังต้องใช้ session จริง; **ราคา ยอดรวม สต็อก ค่าส่ง คำนวณใหม่ฝั่ง server จากข้อมูลร้าน ไม่เชื่อค่าจากตะกร้าที่เก็บในเครื่อง** (ตะกร้า guest ถือเป็น untrusted input)
- AC-G5 ข้อมูล guest (เบอร์/ที่อยู่) ถ้าเก็บก่อน login เก็บเฉพาะบนอุปกรณ์ (browser storage) ไม่ส่งขึ้น server จนกว่า login; หมดอายุ/ล้างได้ (เสนอ 24 ชม. สำหรับเบอร์/ที่อยู่, ล้างเมื่อสั่งสำเร็จ) และไม่ log ค่าเหล่านี้
- AC-G6 ตะกร้า guest ที่ร้านถูกปิด/เมนูหมด/ราคาเปลี่ยนระหว่างรอ login แสดงการแจ้งเตือนและปรับตะกร้า ไม่ปล่อยให้สั่งสำเร็จด้วยข้อมูลเก่าเงียบ ๆ
- AC-G7 anonymous Supabase session ห้ามเรียก private order/payment endpoint (คงกติกาที่มีใน `food-guest-browse.tsx`)

### Edge cases
- EC-G1 ตะกร้ามีหลายร้าน → ตะกร้า guest ผูก 1 ร้าน (ตามโครงสร้างเดิม `storeId`); เปลี่ยนร้านต้องถามยืนยันล้างตะกร้า
- EC-G2 ผู้ใช้ต้องออกจาก LINE ไปเบราว์เซอร์ภายนอกเพื่อ login (Google) → sessionStorage ของ LINE in-app **ไม่แชร์** กับเบราว์เซอร์ภายนอก: ตะกร้าจะหาย. ต้องมีกลไกพา "ร้าน + ตะกร้า" ไปด้วยอย่างปลอดภัย (เช่น ส่ง store reference ที่ allowlist แล้วให้สร้างตะกร้าใหม่ หรือ draft ฝั่ง server หลัง login) — Architect ต้องเสนอ; ถ้าทำไม่ได้ในรอบแรก ต้องแจ้งผู้ใช้ชัดว่าตะกร้าจะไม่ถูกย้าย (ซึ่งเป็นเหตุผลให้ข้อ 2 สำคัญ)
- EC-G3 private mode/storage ถูกปิด → fallback เก็บใน memory พร้อมเตือนว่าตะกร้าอาจหาย
- EC-G4 เบอร์โทรรูปแบบผิด/เบอร์ต่างประเทศ/ใส่ emoji → validate ทั้ง client และ server
- EC-G5 หลายแท็บ/อุปกรณ์: ตะกร้า guest ผูกกับอุปกรณ์ ไม่ sync
- EC-G6 ผู้ใช้กดย้อนกลับจาก login → ต้องกลับเห็นตะกร้า
- EC-G7 ร้านเปลี่ยนเป็นปิด/busy mode ระหว่างรอ → ใช้ logic busy/pickup เดิมตอน server quote

### Dependencies / ข้อจำกัด
- ต้องตรวจก่อนว่า "เบอร์" ปัจจุบันถูกบังคับที่ขั้นไหน (ดูหัวข้อ 1 แถวสุดท้าย) และ schema/RPC รองรับการส่งเบอร์พร้อมออเดอร์ได้เท่าเดิม
- ถ้าต้องเก็บ guest draft ฝั่ง server (EC-G2) = มี DB/PII ใหม่ → ต้อง Database Engineer + Founder approval ตาม change control (ไม่รวมในขอบเขตนี้จนกว่าจะอนุมัติ)

---

## 5. ข้อ 2 — LINE Login เป็น auth method ภายใน LINE (P1, ต้อง Founder approval)

### ⚠ ประกาศ: Authentication Architecture Change
ZOKY-LINE-001 ระบุชัดว่า LINE Login ไม่อยู่ใน scope และ D1 ระบุให้เป็น "auth architecture change แยก task" — เอกสารนี้คือ task แยกนั้น **ห้ามเริ่ม implement จนกว่า Founder จะอนุมัติ D-3 (และบันทึกใน APPROVALS.md)**

### ปัญหา
Google OAuth ถูกบล็อกใน LINE in-app browser (`disallowed_useragent`) → ผู้ใช้ Google เข้า ZOKY ใน LINE ไม่ได้ ต้องออกไปเบราว์เซอร์ภายนอก

### ข้อเสนอ
เพิ่ม "เข้าสู่ระบบด้วย LINE" เป็นวิธี login ลำดับเพิ่ม (ไม่แทน Google/email) โดยในเบราว์เซอร์ปกติยังใช้ได้ตามเดิม และใน LINE in-app แสดง LINE Login เป็นตัวเลือกหลัก

### ทางเทคนิคที่ Architect ต้องประเมิน (PM ไม่เลือกเอง)
| ทาง | แนวคิด | ข้อสังเกตเบื้องต้น |
|---|---|---|
| T1 | ใช้ custom OIDC/OAuth provider ของ Supabase Auth ถ้า project/version รองรับ | ใช้ session mechanism เดิม ลดโค้ด auth เอง — **ต้องตรวจว่ารองรับจริง** (ยังไม่ได้ตรวจ) |
| T2 | Edge Function ตรวจ LINE ID token แล้วออก session | ควบคุมได้แต่เป็นโค้ดออก session เอง = ความเสี่ยงด้าน security สูงกว่า |
| T3 | ใช้ `line_links` (มีอยู่แล้ว) เป็นตัวจับคู่ LINE userId → account | ใช้ได้เฉพาะคนที่เคยเชื่อมแล้ว ไม่ครอบคลุมผู้ใช้ใหม่ |

### User stories
- **US-L1** ในฐานะลูกค้าใหม่ใน LINE ฉันกด "เข้าสู่ระบบด้วย LINE" ครั้งเดียวและสั่งอาหารต่อได้โดยไม่ออกจาก LINE
- **US-L2** ในฐานะลูกค้าเดิมที่สมัครด้วย Google ฉันเข้าสู่บัญชีเดิม (ประวัติออเดอร์/ที่อยู่) ได้เมื่อใช้ LINE โดยไม่ถูกสร้างบัญชีซ้ำ — หลังพิสูจน์ความเป็นเจ้าของบัญชีเดิมแล้ว
- **US-L3** ในฐานะผู้ใช้ ฉันเห็นว่าบัญชีนี้ login ด้วยวิธีใดบ้าง และยกเลิกการผูก LINE ได้ (ต้องยังเหลือวิธี login อย่างน้อย 1 วิธี)

### Acceptance criteria
- AC-L1 ทุก token/ID token ถูก verify ฝั่ง server (`iss`, `aud`, `exp`, nonce/state ตามที่ LINE Login รองรับ); ห้ามเชื่อ userId/email จาก client
- AC-L2 **ห้าม auto-merge บัญชีด้วยอีเมลอย่างเดียว** (LINE อาจไม่ส่งอีเมล, อีเมลอาจไม่ verified, และเสี่ยง account takeover) การผูกกับบัญชี Google เดิมต้องผ่านการพิสูจน์ว่าเป็นเจ้าของบัญชีเดิม (login บัญชีเดิมแล้วกด "ผูก LINE" ที่ตั้งค่า) หรือผ่านทาง T3 ที่ `line_links` ถูกสร้างจากการพิสูจน์สองฝั่งอยู่แล้ว (ถ้า Architect/Founder เห็นชอบ)
- AC-L3 ผู้ใช้ที่ไม่ได้ผูกและไม่ได้พิสูจน์ จะได้บัญชีใหม่แยกต่างหาก พร้อมข้อความอธิบายและทางผูกบัญชีทีหลัง — ไม่ทำให้ประวัติเดิมถูกเข้าถึงโดยคนอื่น
- AC-L4 LINE userId เดียวผูกกับบัญชีเดียว (สอดคล้อง AC2 ของ ZOKY-LINE-001); Provider ต้องตรงกับ Provider ของ OA ลูกค้า ("Zoky • สั่งอาหาร") เพื่อให้ userId ตรงกับ `line_links`
- AC-L5 ปฏิเสธ open redirect: `redirect_to`/`state`/`to` ใช้ allowlist เดียวกับข้อ 3
- AC-L6 rate limit และ audit log ของการ login/ผูก/ยกเลิก (ไม่ log token หรือ userId เต็ม)
- AC-L7 Google/email-password ยังทำงานเหมือนเดิม (regression); Merchant app ไม่เปลี่ยนพฤติกรรม login ใน task นี้ (ขอบเขต = ลูกค้า `food` เท่านั้น เว้นแต่ Founder สั่งเพิ่ม)
- AC-L8 ปิดฟีเจอร์ได้ด้วย feature flag ทันที โดยผู้ใช้ที่ login ด้วย LINE อย่างเดียวต้องยังมีทางเข้า (ดู rollback)

### Edge cases
- EC-L1 ผู้ใช้ปฏิเสธ scope / กดยกเลิกที่หน้า LINE → กลับพร้อมตะกร้าเดิมและข้อความ ไม่ error ค้าง
- EC-L2 LINE ไม่ส่งอีเมล (ปกติต้องขอ scope `email` แยกและผู้ใช้อาจไม่มีอีเมล) → ระบบต้องไม่พึ่งอีเมลเป็นตัวระบุ; ถ้าต้องมีอีเมลเพื่อ recovery/ใบเสร็จ ต้องขอเพิ่มและ validate
- EC-L3 ผู้ใช้ LINE เปลี่ยน/ลบบัญชี LINE, หรือบล็อก OA → บัญชี ZOKY ต้องยังเข้าได้ด้วยวิธีอื่น/มี recovery path
- EC-L4 ผู้ใช้สมัครด้วย LINE ก่อน แล้วภายหลังใช้ Google อีเมลเดียวกัน → ต้องไม่ merge เงียบ ๆ (AC-L2)
- EC-L5 LIFF app/Login channel อยู่คนละ Provider กับ OA → userId ไม่ตรง; ต้องตรวจก่อนเปิดใช้
- EC-L6 iOS Home Screen PWA: redirect LINE Login อาจออกนอก PWA (ความเสี่ยงเดิมใน ZOKY-LINE-001)
- EC-L7 ผู้ใช้ที่ login ใน LINE และเปิดซ้ำในเบราว์เซอร์ภายนอก → session แยกกัน ต้องไม่ทำให้เกิดบัญชีซ้ำโดยไม่ตั้งใจ

### ผลต่อบัญชีเดิมที่สมัครด้วย Google
- **ไม่มีการย้ายหรือแก้ข้อมูลบัญชีเดิมโดยอัตโนมัติ** บัญชีเดิมยังเข้าได้ด้วย Google ตามเดิม
- ผู้ใช้ Google เดิมที่ต้องการใช้ LINE login ต้องผูกเองก่อน (พิสูจน์ด้วยการ login Google ในเบราว์เซอร์ภายนอกหนึ่งครั้ง) — ผู้ใช้กลุ่มนี้จะยังเจอแรงเสียดทานหนึ่งครั้ง; ถ้าไม่ผูก จะถูกสร้างเป็นบัญชีใหม่ (ประวัติออเดอร์ไม่ตามมา) ซึ่งต้องสื่อสารชัดเจนในหน้า login
- ผู้ที่เคยเชื่อม LINE แจ้งเตือนแล้ว (`line_links`) เป็นกลุ่มเดียวที่ระบบ "รู้" ว่า LINE userId นี้ = บัญชีไหน → Founder/Architect ตัดสินว่าจะใช้ข้อมูลนี้ให้ login ได้โดยตรงหรือไม่ (D-4)
- ต้องระบุใน privacy policy (ยังเป็น placeholder ตาม ZOKY-LINE-001) ว่าใช้ LINE userId เพื่อ login ด้วย ไม่ใช่แค่แจ้งเตือน

### Risks
| ความเสี่ยง | ระดับ | บรรเทา |
|---|---|---|
| Account takeover จากการ merge ด้วยอีเมล/จับคู่ผิด | สูง | AC-L2, ไม่ auto-merge, QA test ข้ามบัญชี |
| บัญชีซ้ำ/ประวัติแยก ทำให้ลูกค้างง | กลาง | ข้อความชัด + ทางผูกภายหลัง + วัดใน usability test |
| ผิด Provider ทำให้ userId ไม่ตรง | กลาง | ตรวจ config ก่อนเปิด flag; staging กับ OA ทดสอบ |
| เปลี่ยน auth surface = เพิ่มพื้นที่โจมตี (state/nonce/redirect) | สูง | QA & Security เต็มรูปแบบ, CTO review, ไม่เขียนโค้ดออก session เองหากมี T1 |
| พึ่งพา LINE (ล่ม/นโยบายเปลี่ยน) | ต่ำ-กลาง | คง Google/email เป็นทางสำรอง |
| ผู้ใช้ที่มีแต่ LINE login ถูกล็อกเมื่อ rollback | กลาง | ดู rollback |

### Rollback
- Feature flag ปิดปุ่ม "เข้าสู่ระบบด้วย LINE" ทันที; Google/email ไม่ถูกแตะ (additive)
- ผู้ใช้ที่สร้างบัญชีด้วย LINE อย่างเดียว: ก่อนเปิดใช้ต้องมีแผน recovery (เช่น ตั้งอีเมล/รหัสผ่านภายหลัง หรือให้ flag ปิดเฉพาะปุ่มแต่ session เดิมยังใช้ได้) — Architect ระบุใน design
- การเปลี่ยนแปลง DB (ถ้ามี identity mapping เพิ่ม) ต้องเป็น additive พร้อม rollback SQL ที่ review แล้ว และ **ไม่ลบบัญชี/identity ของผู้ใช้อัตโนมัติ** (destructive ต้องขออนุมัติแยก)
- การ rollback production ตามกติกาเดิม: ต้องให้ Founder/Owner สั่ง (ห้าม rollback เอง ตาม `RULES.md`)

### Founder action ภายนอกโค้ด
LINE Developers: ยืนยัน LINE Login channel ของ Provider "Zoky • สั่งอาหาร", เปิดใช้ scope ที่ต้องการ (`openid profile`, `email` เฉพาะถ้าอนุมัติ), ตั้ง callback URL; ใส่ secrets ผ่าน Supabase/Vercel เอง ห้ามส่งในแชทหรือ commit

---

## 6. ข้อ 3 — QR/ลิงก์ "แอดเพื่อน + เปิดหน้าร้านนั้นต่อทันที" (LIFF deep link)

สถานะ: ส่วนหลักมีใน APPROVALS ว่า approved/released แล้ว (QR ร้านเปิด `https://liff.line.me/<ZOKY LIFF>?to=/s/<code>`, friendship prompt ก่อนเปิดร้าน) แต่ **โค้ดใน working tree นี้ไม่มี** — ก่อนทำงานนี้ Full-Stack/CTO ต้องยืนยันว่าอ้างอิง branch/commit ล่าสุด (เช่น main หรือ release ที่ deploy: `dpl_J6cmTuDhoWXWr6ks3UuYaT9mPJWK` ตาม APPROVALS) ไม่ใช่ tree นี้ ข้อนี้จึงเน้น **ตรวจสอบพฤติกรรมจริง ปิดช่องว่าง และ allowlist**

### User stories
- **US-Q1** ในฐานะลูกค้าที่สแกน QR ร้านหรือกดลิงก์ ฉันถูกชวนแอดเพื่อน OA แล้วเปิดหน้าร้านนั้นต่อทันที ไม่ต้องหาร้านเอง
- **US-Q2** ในฐานะร้าน ฉันแชร์ QR/ลิงก์ร้านและรู้ว่าลูกค้าเปิดร้านฉันตรง ๆ
- **US-Q3** ในฐานะลูกค้าที่เป็นเพื่อนอยู่แล้วหรือกดยกเลิกตอนแอด ฉันยังเข้าร้านได้ตามปกติ (ไม่บังคับแอดเพื่อน)

### Acceptance criteria
- AC-Q1 deep link รูปแบบ `liff.line.me/<LIFF>?to=<path>` เปิดร้านเป้าหมายหลังขั้นตอน add-friend; ไม่บังคับเป็นเพื่อนก่อนสั่ง
- AC-Q2 **allowlist path เข้ม:** รับเฉพาะ (1) `/food` (2) `/food?order=<ZF-/WF number>` (3) `/s/<code 6 ตัวที่ตรวจ format>` (4) `/food?store=<uuid>`; ปฏิเสธ absolute URL, `//host`, `\`, scheme อื่น, encoded variants (`%2f%2f`, `%5c`), ความยาวเกินกำหนด, query/fragment ที่ไม่อยู่ใน allowlist → fallback `/food`
- AC-Q3 ต้องผ่าน unit test รวม payload open-redirect (`https://evil.test`, `//evil.test`, `/\evil.test`, `javascript:`, double-encoding, ช่องว่าง/CRLF) ทั้งในฝั่ง `/line`, `/s/[code]` route และ (ถ้ามีข้อ 2) callback ของ LINE Login
- AC-Q4 รหัสร้านที่ไม่มีอยู่/ร้านปิดถาวร → หน้า "ไม่พบร้าน" พร้อมปุ่มไปรายการร้าน ไม่ error ขาว
- AC-Q5 ไม่ใส่ข้อมูลส่วนตัวใน URL (ไม่มี userId/token/เบอร์ใน query)
- AC-Q6 ตัวเลือก (P1): ลิงก์ "แอด OA + ร้าน" สำหรับแชร์ทางข้อความที่ให้พฤติกรรมเดียวกับ QR
- AC-Q7 ถ้า LIFF/OA ไม่ได้ตั้งค่า (เช่น staging) ต้อง fallback เป็นเว็บลิงก์ปกติ ไม่พัง

### Edge cases
- EC-Q1 ลูกค้าเปิด QR นอกแอป LINE (กล้องมือถือ/เบราว์เซอร์) → `liff.line.me` พาเปิดใน LINE หรือเว็บ; ต้องไม่ทำให้ loop
- EC-Q2 LINE เวอร์ชันเก่า/Desktop LINE → friendship prompt อาจใช้ไม่ได้ → fallback ลิงก์ profile OA (ตามที่ APPROVALS ระบุ) และเปิดร้านต่อ
- EC-Q3 ลูกค้าถูกบล็อก/เคยบล็อก OA → ไม่เด้ง prompt ซ้ำวน
- EC-Q4 QR เก่าที่พิมพ์ไปแล้วต้องยังใช้ได้ (APPROVALS: "The existing printed QR remains valid")
- EC-Q5 LIFF `liff.state` redirect ซ้อนกับ `to` (ต้องไม่ถูกปลอมแทรก path ที่ไม่ allowlist)
- EC-Q6 เปิดลิงก์ในเบราว์เซอร์ภายนอกทำให้ session LINE ไม่ตามมา → ไปเส้นทาง guest (ข้อ 1)
- EC-Q7 ลิงก์ที่มี `to` ซ้ำหลายค่า (`to=a&to=b`) → ใช้ค่าเดียวที่ปลอดภัยหรือ fallback

---

## 7. ข้อ 4 — แผน usability test (P0 ก่อนและหลัง)

### วัตถุประสงค์
วัดจุดที่ลูกค้าติดจริง เพื่อยืนยัน/หักล้างสมมติฐานในหัวข้อ 1 ก่อนลงทุนข้อ 2 (auth change) และพิสูจน์ว่าข้อ 1, 3 ช่วยจริง

### ผู้เข้าร่วม 3–5 คน (ต่อรอบ)
- ลูกค้าจริงหรือใกล้เคียง ไม่ใช่ทีม WYN; อย่างน้อย 2 คนใช้ Google เป็นหลัก, อย่างน้อย 1 คนไม่เคยใช้ ZOKY, ผสม iOS/Android
- ใช้ **staging + OA ทดสอบ + ข้อมูลสังเคราะห์/ร้านทดสอบ** ไม่ใช้ production DB จริงหรือบัญชีผู้ใช้จริงของผู้เข้าร่วม; ไม่เก็บข้อมูลส่วนบุคคลเกินจำเป็น ขอความยินยอมก่อนบันทึกหน้าจอ/เสียง และลบตามกำหนดที่แจ้ง (ถ้ามีการใช้ production ต้องให้ Founder อนุมัติแยก)
- ความคุ้มค่า: 5 คนเพียงพอพบปัญหาหลักส่วนใหญ่ แต่เป็น qualitative ไม่ใช่สถิติ — ห้ามอ้างเปอร์เซ็นต์ทางสถิติจาก n=5

### Script (ภาษาไทย ผู้ดำเนินการไม่ช่วยเว้นแต่ติดเกิน 2 นาที)
1. เปิด: อธิบายว่ากำลังทดสอบระบบ ไม่ได้ทดสอบผู้ใช้ ขอให้พูดความคิดออกเสียง (think aloud)
2. สถานการณ์ A (QR): "คุณเดินผ่านร้านที่มี QR ให้สแกนเพื่อสั่งอาหาร ลองสั่งข้าวมัน 1 จาน รับที่ร้าน" — ให้เริ่มจากสแกน/กดลิงก์
3. สถานการณ์ B (แอด OA เอง): "เพื่อนบอกให้แอด LINE ของ ZOKY แล้วสั่งอาหาร" — เริ่มจากค้นหา/แอด OA แล้วหาร้านที่กำหนด
4. สถานการณ์ C (มีบัญชีเดิม): ผู้ใช้ที่เคยสมัครด้วย Google สั่งอาหารอีกครั้ง
5. สถานการณ์ D (ชำระเงิน): ชำระ/ส่งสลิปภายในเวลา (ใช้ช่องทางทดสอบ)
6. ปิด: คำถามหลังทำ — จุดที่งง? ขั้นไหนอยากเลิก? เปรียบกับแอปสั่งอาหารอื่นที่เคยใช้? ให้คะแนนความง่าย 1–5 (SEQ) ต่อสถานการณ์

### Metrics ต่อสถานการณ์
| Metric | วิธีวัด |
|---|---|
| Task completion (ส่งออเดอร์สำเร็จ / ไม่สำเร็จ / ต้องช่วย) | ผู้สังเกตบันทึก |
| จุดที่เลิกกลางคัน (drop-off step) | funnel ขั้น: เปิด LIFF → เห็นร้าน → เพิ่มตะกร้า → กดยืนยัน → หน้า login → login สำเร็จ → กลับมาเห็นตะกร้า → ส่งออเดอร์ → ชำระ — บันทึกขั้นสุดท้ายที่ทำได้ |
| เวลาถึงแต่ละขั้น / เวลารวม | นาฬิกาจับเวลา |
| จำนวนครั้งที่ออกจาก LINE ไป browser ภายนอก | ผู้สังเกตนับ |
| Error/ความสับสน (เช่น เจอ disallowed_useragent, ตะกร้าหาย, ไม่รู้ต้องแอดเพื่อนไหม) | บันทึกเหตุการณ์ + คำพูด |
| SEQ 1–5 และคำพูดสำคัญ | แบบสอบถามหลังงาน |

ผลที่ต้องส่ง: ตาราง funnel ต่อคน, อันดับปัญหา (ความถี่ × ความรุนแรง), คลิปสั้น (ถ้ายินยอม), สรุปข้อเสนอ — ไม่ใส่ชื่อ/เบอร์จริงของผู้เข้าร่วมในเอกสาร

### เกณฑ์ตัดสิน (เสนอ — Founder ปรับได้)
- ถ้ามีผู้ใช้ Google ≥ 2 ใน 5 คนที่ติดหรือเลิกที่หน้า login ใน LINE → ถือว่ามีหลักฐานสนับสนุนข้อ 2 (เสนอเข้า D-3)
- ถ้ามีคน ≥ 2 ที่ไม่เข้าใจว่าเลือกเมนูได้ก่อน login → ปรับ UX ข้อ 1 ก่อน (copy/ลำดับหน้า)
- รอบหลังแก้: ไม่มีสถานการณ์ใดที่คนส่วนใหญ่ต้องออกจาก LINE เพื่อสั่งสำเร็จ และ drop-off ที่หน้า login ลดลงเทียบ baseline (เป้าตัวเลขให้กำหนดหลังเห็น baseline — **ไม่ตั้งตัวเลขเดาตอนนี้**)

### ข้อจำกัดที่ต้องรู้
- ต้องใช้เครื่องจริง iOS/Android + LINE จริง; ZOKY-LINE-001 บันทึกว่ายังไม่เคยทดสอบกับ LINE จริง และ Staging/OA ทดสอบต้องพร้อม (Founder เตรียม OA ทดสอบ)
- ใครเป็นผู้ดำเนินการ (Founder/ทีม) และการหาผู้เข้าร่วมเป็นงานนอก AI

---

## 8. Non-functional (ทุกข้อ)
- Security: server-side authorization ทุก protected action, validate ทุก trust boundary, ไม่ log token/userId เต็ม/เบอร์/ที่อยู่, ไม่ใช้ production secrets หรือ DB จริงในการทดสอบ
- Mobile-first, accessibility (ปุ่มใหญ่ อ่านง่ายใน LINE in-app), loading/empty/error states ครบ
- Web Push และ LINE แจ้งเตือนเดิมต้องทำงานเหมือนเดิม (regression)
- Visual direction ตามแนว WYN/ZOKY เดิม (UI/UX Engineer รับช่วง)

## 9. Decisions ที่ต้องให้ Founder อนุมัติ

| # | เรื่อง | ข้อเสนอ PM | ผลถ้าไม่อนุมัติ |
|---|---|---|---|
| D-1 | อนุมัติ scope ภาพรวม + ลำดับ A → B/C/F → D → E | อนุมัติ | งานไม่เริ่ม |
| D-2 | Guest checkout = guest ตะกร้า/กรอกข้อมูลบนอุปกรณ์เท่านั้น **ไม่ใช่สร้างออเดอร์แบบไม่มีบัญชี** (login ยังบังคับก่อนสร้างออเดอร์/ชำระเงิน) | อนุมัติ | ถ้าต้องการ "สั่งโดยไม่มีบัญชีจริง" = เปลี่ยน security/product model ต้อง task ใหม่ + approval |
| D-3 | **Authentication Architecture Change:** เพิ่ม LINE Login สำหรับลูกค้า (food) เป็น auth method — แนะนำ **อนุมัติแบบมีเงื่อนไข:** เริ่มหลังได้ baseline จากข้อ 4 และหลัง Architect/CTO เสนอ design (T1 ก่อน T2) | อนุมัติเงื่อนไข / หรือ "ยังไม่ทำ ใช้ทาง F แทน" | ถ้าไม่อนุมัติ ทำ F (ทางออกชัดเจนใน LINE) และ guest ต่อไป |
| D-4 | กับบัญชีเดิม (Google): ห้าม auto-merge ด้วยอีเมล; ผูกเมื่อพิสูจน์เจ้าของบัญชีเดิม; จะให้ผู้ที่มี `line_links` อยู่แล้ว login ผ่าน LINE ได้โดยตรงหรือไม่ | ไม่ auto-merge ด้วยอีเมล; ให้ Architect เสนอ T3 พร้อมความเสี่ยง | ถ้า Founder ต้องการ merge อัตโนมัติ ต้องรับความเสี่ยง account takeover แบบ documented |
| D-5 | scope ของ LINE Login = ลูกค้า (`food`) เท่านั้น ไม่รวม Merchant | อนุมัติ | ขยาย scope = approval เพิ่ม |
| D-6 | Dependency/infra: ไม่เพิ่ม dependency ใหม่ ใช้ `@line/liff` เดิม; หากต้อง server-side draft ตะกร้า (EC-G2) หรือ DB เพิ่ม → ขออนุมัติแยก | อนุมัติหลักการ | |
| D-7 | Usability test: ใช้ staging + OA ทดสอบ + ข้อมูลสังเคราะห์; เกณฑ์ตัดสินตามหัวข้อ 7; ใครเป็นผู้ดำเนินการและหาผู้เข้าร่วม | ยืนยัน | ถ้าต้องการทดสอบบน production จริงต้องอนุมัติแยก |
| D-8 | Release: ตาม release gates เดิม (staging → Founder approval → scoped production release) ไม่ deploy ใด ๆ จากเอกสารนี้ | ยืนยัน | |

## 10. Dependencies
- ZOKY-LINE-001 สถานะ: backend inert, ต้องมี LINE secrets/OA ตั้งค่าบน staging/production ก่อนทดสอบจริง
- Branch/commit ที่ตรงกับสถานะ production ล่าสุด (ดูหัวข้อ 1 แถวที่ 4) — working tree ที่ตรวจไม่ตรง
- OA ทดสอบ + LIFF ทดสอบ + ผู้เข้าร่วมทดสอบ (Founder)
- Privacy policy (ยัง placeholder) ต้องอัปเดตก่อนเปิด LINE Login ทั่วไป

## 11. Risks รวม
- ข้อ 2 เพิ่ม attack surface ด้าน auth; ทำก่อนมีข้อมูลยืนยันปัญหาอาจเสียเปล่า → จึงจัดหลัง baseline
- สมมติฐานปัญหายังไม่ได้ยืนยันกับผู้ใช้จริง
- ตะกร้า guest ข้ามเบราว์เซอร์ไม่ติดตามไปด้วย (EC-G2) อาจทำให้ข้อ 1 ช่วยได้จำกัดหากไม่มีข้อ 2
- ความไม่ตรงกันของ working tree กับ production ทำให้เสี่ยงทำงานซ้ำ/ชนกัน

## 12. Rollback (ภาพรวม)
- ข้อ 1, 3: web-only release → Vercel rollback ไปยัง deployment ก่อนหน้า โดย Founder/Owner สั่ง; ไม่มี DB change
- ข้อ 2: feature flag + additive change ตามหัวข้อ 5
- ห้าม rollback เองตาม `RULES.md`; เจอปัญหาให้หยุด รายงาน รอคำสั่ง

## Handoff
Founder อนุมัติ D-1…D-8 → (ขนาน) Full-Stack ยืนยัน baseline branch + ตรวจจุด phone/guest flow; Founder จัดการ usability test รอบ baseline → CTO/Architect ออกแบบ guest handoff (EC-G2) และ LINE Login (T1/T2/T3) พร้อม threat model → UI/UX (login ใน LINE, copy guest) + Database (ถ้าจำเป็น) → Full-Stack → QA & Security (open redirect, account takeover, cross-user, ตะกร้า untrusted) → staging → usability test รอบหลังแก้ → CTO final review → Founder approval → scoped production release
