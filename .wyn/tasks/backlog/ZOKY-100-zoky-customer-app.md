# Product Task — ZOKY-100 — ZOKY: เปลี่ยน WYNOS Food (ฝั่งลูกค้า) เป็น ZOKY บน Web + iOS + Android

Status: backlog — **PENDING FOUNDER APPROVAL** (PRD draft; ยังไม่มีการอนุมัติ scope, ค่าใช้จ่าย หรือการเปลี่ยนโดเมน)
Owner: AI Product Manager
Date: 2026-10-17
Type: Epic (แตกเป็น slice ZOKY-101..115 ใน `.wyn/docs/product/zoky-roadmap.md`)

เอกสารที่เกี่ยวข้อง:
- Feature parity matrix (96 ฟีเจอร์): `.wyn/docs/product/zoky-feature-parity.md`
- Roadmap + rebrand checklist: `.wyn/docs/product/zoky-roadmap.md`
- ข้อเสนอการตัดสินใจ (รออนุมัติ): `.wyn/docs/product/zoky-decision-proposal.md` และรายการ `APPROVAL_REQUIRED` ใน `.wyn/company/APPROVALS.md`

## ระบบเลข task (ID scheme)

ใช้ **`ZOKY-1xx`** (เริ่ม `ZOKY-100`) เพราะ:
- prefix `ZOKY-` ตรงกับชื่อผลิตภัณฑ์ใหม่ ค้นหาง่าย และแยกจาก `WYN-xxx` ของ WYNOS
- `ZOKY-001..005` และ `SELLER-001..005` ถูกใช้ไปแล้วกับ ZOKY Marketplace เดิม (ไฟล์ยังอยู่ใน `.wyn/tasks/approved/`, `completed/`, `bugs/`
  และ `.wyn/docs/design/zoky-00x-*.md`) — ช่วง 100 ขึ้นไปจึงไม่ชนกันและเห็นได้ทันทีว่าเป็นคนละรุ่น
- ตรวจแล้วไม่มี `ZOKY-1xx` ใดใน repo
- งานที่แตะเฉพาะโค้ดกลางของ WYNOS (เช่น edge function ที่ Merchant ใช้ร่วม) ยังใช้ `WYN-xxx` ได้ตามปกติ แล้วอ้างอิง ZOKY-1xx

## Founder direction (ส่งต่อมาจากการคุยกับ Founder วันที่ 2026-10-17)

> บันทึกตามที่ได้รับแจ้ง — ข้อที่มีผลต่อโดเมน ค่าใช้จ่าย สถาปัตยกรรม หรือ production ยังต้องได้รับอนุมัติอย่างเป็นทางการตาม `.wyn/company/RULES.md`

1. ZOKY คือผลิตภัณฑ์ใหม่ที่เริ่มจากศูนย์ **ไม่ใช่ ZOKY Marketplace เดิม** และห้ามใช้เลข task เดิม
2. ZOKY = WYNOS Food ฝั่งลูกค้าที่มีอยู่ (food.wynos.online) เปลี่ยนแบรนด์ทั้งหมดเป็น ZOKY
3. เปลี่ยนทั้งชื่อและโดเมน: โดเมนใหม่ `zoky.online` (Founder ตรวจแล้วว่าว่าง แต่**ยังไม่ยืนยันว่าซื้อแล้ว**); `food.wynos.online` ต้อง redirect เพื่อให้ลิงก์/bookmark/ลิงก์แชร์เดิมยังใช้ได้
4. แพลตฟอร์ม: Web + iOS + Android ทุกตัว**ฟีเจอร์เท่าเว็บเดิม** ("ทำให้เท่าเว็บเดิม")
5. เทคโนโลยี: Web ใช้ Next.js เดิม (rebrand อย่างเดียว); iOS + Android เป็น**แอป Flutter ใหม่หนึ่งแอป**; backend ใช้ Supabase RPC/edge function เดิม
6. Scope: ฝั่งลูกค้าเท่านั้น ร้านค้ายังเป็น WYNOS Merchant (ไม่ทำ rider)
7. UX: แบรนด์ ZOKY เหมือนกันทั้งสองแพลตฟอร์ม (สี โลโก้ ฟอนต์ การ์ด nav copy) แต่ส่วนของระบบปรับตามแพลตฟอร์ม (dialog, action sheet, date/time picker, switch, ไอคอน share/back, scroll physics, page transition)
8. Founder มีแค่ iPad (ไม่มี Mac) → build iOS บน cloud macOS CI (เสนอ Codemagic, ต้องอนุมัติเพราะเป็นค่าใช้จ่ายใหม่) ทดสอบผ่าน TestFlight / Google Play internal testing
9. Production freeze มีผลอยู่ (`docs/engineering/WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md`, PR #1141) — ห้ามทำงาน production จนกว่า gate จะผ่าน

## Feature

ZOKY — แอปสั่งอาหารฝั่งลูกค้า (ชื่อเดิม WYNOS Food) บน Web (`zoky.online`), iOS และ Android โดยแอปมือถือมีฟีเจอร์เท่าเว็บปัจจุบันครบ 96 รายการตาม parity matrix

## Goal

1. ลูกค้าจำและเรียกชื่อบริการสั่งอาหารได้ง่ายด้วยแบรนด์ของตัวเอง (ZOKY) และโดเมนของตัวเอง
2. ลูกค้าบน iPhone/Android สั่งอาหารผ่านแอปจาก App Store / Google Play ได้ครบทุกอย่างที่เว็บทำได้
3. ลิงก์เดิมทุกแบบ (bookmark, ลิงก์แชร์ร้าน `/s/<code>`, QR poster ของร้าน, ลิงก์จากแจ้งเตือน) ยังพาไปที่ถูกต้อง

## Target User

- ลูกค้าที่สั่งอาหาร (ปัจจุบันให้บริการในจังหวัดมหาสารคาม) — ทั้งผู้ใช้เว็บเดิมและผู้ใช้ใหม่จาก App Store / Play
- ผู้ที่ได้รับลิงก์ร้านจากเพื่อนหรือจากร้าน (ยังไม่ล็อกอิน)
- ผลกระทบทางอ้อม: ร้านค้าใน WYNOS Merchant (ลิงก์/QR ที่แชร์ออกไป), ทีมทดสอบ (บัญชีนักพัฒนา)

## Problem

- "WYNOS Food" ผูกกับแบรนด์ WYNOS (Social) ทำให้บริการสั่งอาหารไม่มีตัวตนของตัวเอง
- ลูกค้าบนมือถือใช้ได้แค่เว็บ/PWA ซึ่งมีข้อจำกัด: ต้อง "เพิ่มลงหน้าจอหลัก" เอง, push บน iOS ต้องติดตั้ง PWA ก่อน, เคยมีปัญหา PWA ผูก origin ผิด (ดูจอ legacy ใน `food-auth.tsx`), ไม่มีแอปใน store ให้ค้นหา

## Scope (In)

1. **Brand identity ZOKY**: ชื่อ, โลโก้, app icon, สี (ตามแนวทาง white 80–90% + rainbow accents 10–20% ของ `AGENTS.md`), ฟอนต์, น้ำเสียง copy — ใช้ร่วมกันทั้งเว็บและแอป
2. **Web rebrand**: เปลี่ยนทุกจุดที่ลูกค้าเห็นใน `/food` เป็น ZOKY (รายการเต็มใน rebrand checklist ของ roadmap) โดยไม่เปลี่ยนพฤติกรรม
3. **โดเมน**: `zoky.online` เป็นโดเมนหลักของเว็บ ZOKY; `food.wynos.online` (และ `wynos.online/food`) redirect ไป `zoky.online` โดยคง path และ query
4. **แอป Flutter ใหม่ (iOS + Android)** ฟีเจอร์เท่าเว็บตาม `.wyn/docs/product/zoky-feature-parity.md` (96 รายการ) ใช้ Supabase project/RPC/edge function เดิม
5. **ช่องทางทดสอบ**: TestFlight (iOS) และ Google Play internal testing (Android) ผ่าน cloud CI
6. **Deep links**: Universal Links / App Links สำหรับ `zoky.online` (ลิงก์ร้าน, ออเดอร์, การกลับจาก Stripe, auth callback)
7. **Store listing**: App Store Connect และ Google Play Console ในชื่อ ZOKY (หลัง gate ผ่าน)

## Out of Scope

- WYNOS Merchant, Rider, Admin — ยังเป็นชื่อเดิม (ยกเว้น Founder สั่งเพิ่ม; ดู Q10)
- ฟีเจอร์ใหม่ที่เว็บยังไม่มี เช่น แชทจริงในแท็บข้อความ, sync ร้านโปรด/โค้ดที่เก็บข้ามอุปกรณ์, สั่งล่วงหน้า/รับที่ร้าน (ถูกถอดตาม decision 2026-10-10)
- เปลี่ยนชื่อตาราง/RPC/bucket ใน database (`food_*` คงเดิม — เป็นชื่อภายใน)
- ฟื้นแอป Flutter เดิม (`app/`, `seller_app/`) ที่พักไว้ตาม decision 2026-09-19 หรือ Android native (`android/`) ที่พักตาม decision 2026-10-10
- Sign in with Apple และการลบบัญชีในแอป — **ยังไม่อยู่ใน scope จนกว่า Founder ตัดสิน** (Q3, Q4) แม้ store อาจบังคับ
- Production deploy, การ apply migration production, การผูกโดเมน production ระหว่าง freeze

## User Stories

1. ในฐานะลูกค้า ฉันเปิด `zoky.online` แล้วเห็นแบรนด์ ZOKY ทั้งหน้า และสั่งอาหารได้เหมือนเดิมทุกขั้นตอน
2. ในฐานะลูกค้าที่ bookmark `food.wynos.online` ไว้ เมื่อเปิด ฉันถูกพาไป `zoky.online` หน้าเดียวกันโดยไม่ต้องทำอะไร
3. ในฐานะคนที่ได้รับลิงก์ร้าน `food.wynos.online/s/abc234` (หรือสแกน QR poster เก่าของร้าน) ฉันยังเปิดร้านนั้นได้
4. ในฐานะผู้ใช้ iPhone/Android ฉันค้นหา "ZOKY" ใน App Store/Play ติดตั้ง แล้วล็อกอินด้วยบัญชีเดิม (อีเมลหรือ Google) และเห็นที่อยู่/ออเดอร์เดิมของฉัน
5. ในฐานะลูกค้าบนแอป ฉันค้นหาร้าน ดูเมนู เลือกตัวเลือก ใส่ตะกร้า ใช้โค้ดส่วนลด ปักหมุดที่อยู่ สร้างออเดอร์ และจ่ายด้วย QR/สลิป หรือบัตร ได้ครบเหมือนเว็บ
6. ในฐานะลูกค้าบนแอป ฉันได้รับ push เมื่อร้านรับออเดอร์/กำลังส่ง/ส่งถึง และแตะแล้วเปิดออเดอร์นั้นทันที
7. ในฐานะลูกค้าบนแอป ฉันติดตามสถานะแบบ realtime เห็นรูปหลักฐานการส่ง และรีวิวร้านได้
8. ในฐานะผู้ใช้ iPhone ฉันเห็น dialog, action sheet, switch และการปัดกลับแบบ iOS; ในฐานะผู้ใช้ Android ฉันใช้ปุ่ม back ของระบบได้ถูกต้อง — แต่ทั้งสองแอปดูเป็น ZOKY เหมือนกัน
9. ในฐานะคนที่ได้รับลิงก์ร้านและมีแอป ZOKY ลิงก์เปิดในแอป; ถ้าไม่มีแอป ลิงก์เปิดเว็บ
10. ในฐานะ Founder (มีแค่ iPad) ฉันติดตั้ง build ทดสอบผ่าน TestFlight ได้โดยไม่ต้องมี Mac

## Acceptance Criteria

### Brand และเว็บ
1. ทุกข้อความ/โลโก้/ไอคอน/metadata ที่ลูกค้าเห็นใน Food web แสดง ZOKY ตาม rebrand checklist; ค้นหาคำว่า "WYNOS Food" ในไฟล์ฝั่งลูกค้าเหลือเฉพาะที่ระบุว่าตั้งใจคงไว้ (เช่น storage key, ชื่อตาราง)
2. พฤติกรรมเว็บไม่เปลี่ยน: browser/regression tests เดิมของ Food ผ่าน (ปรับเฉพาะ assertion ข้อความแบรนด์)
3. Storage key เดิม (`wynos-food-*`) ไม่ถูกเปลี่ยนชื่อ
4. Brand assets ผ่านการตรวจ accessibility contrast (WCAG AA) และใช้ rainbow เป็น accent ไม่เกิน ~20%

### โดเมนและ redirect
5. `https://zoky.online/` เปิดแอปลูกค้า; `/login`, `/signup`, `/s/<code>`, `/?store=`, `/?order=`, `/?promo=` ทำงานเหมือนบน `food.wynos.online` เดิม
6. ทุก URL บน `food.wynos.online` และ `wynos.online/food*` redirect ไป `zoky.online` path+query เดิม (ทดสอบอย่างน้อย: `/`, `/s/<code>`, `/?store=<uuid>`, `/?order=WF0001`, `/?promo=CODE`, `/food/login`, `/food/signup`, `/food/auth/callback?code=…`)
7. Link preview ของลิงก์ร้านบน LINE/Messenger แสดงชื่อร้าน + แบรนด์ ZOKY ทั้งลิงก์ใหม่และลิงก์เดิมที่ถูก redirect
8. Google sign-in, ยืนยันอีเมล, รีเซ็ตรหัสผ่าน, Stripe success/cancel ทำงานบน `zoky.online`
9. มีแผนสื่อสารผู้ใช้เว็บเดิม (ต้องล็อกอินใหม่, ติดตั้ง PWA ใหม่, เปิดแจ้งเตือนใหม่) ก่อน cutover

### แอป Flutter
10. ทุกแถว P0 และ P1 ใน parity matrix ผ่าน QA บน iOS และ Android ก่อนส่ง store แบบ public; P2 ผ่านหรือ Founder ยอมรับให้ตามมาทีหลังเป็นลายลักษณ์อักษร
11. ทุกการคำนวณเงิน (ราคา, ค่าส่ง, ส่วนลด, ยอดรวม) ที่ลูกค้าเห็นตอนยืนยันมาจาก server quote; แอปไม่ส่งราคาไป server
12. แอปไม่ฝัง service-role key หรือ secret ใด ๆ; ใช้เฉพาะ publishable/anon key; authorization ทั้งหมดยังอยู่ที่ RLS/RPC
13. แอปเรียกเฉพาะ RPC/edge function ที่เว็บใช้อยู่ (รายการใน parity matrix) — การแก้ backend ทุกจุด (เช่น Stripe origin, push routing) มีงานและการอนุมัติแยก
14. Platform-adaptive: iOS ใช้ Cupertino dialog/action sheet/switch/date picker, swipe-back, bounce scroll; Android ใช้ Material dialog/bottom sheet/switch, system back/predictive back; สี/โลโก้/ฟอนต์/การ์ด/nav/copy เหมือนกัน (ตรวจด้วย screenshot เทียบสองแพลตฟอร์ม)
15. Accessibility: VoiceOver/TalkBack อ่านปุ่มหลักได้ทุกจอ, รองรับ Dynamic Type/font scale ถึง 200% โดยไม่ตัดข้อความสำคัญ, touch target ≥44pt/48dp
16. Deep link: แตะ push ออเดอร์ → เปิดออเดอร์นั้น (ทั้งตอนแอปเปิด/อยู่ background/ปิดอยู่); ลิงก์ `zoky.online/s/<code>` เปิดร้านในแอปเมื่อติดตั้ง
17. ติดตั้งผ่าน TestFlight บน iPad ของ Founder ได้ และผ่าน Play internal testing บนอุปกรณ์ Android อย่างน้อย 1 เครื่อง
18. Staged rollout (WYN-125): เวอร์ชันทดสอบแจกเฉพาะ tester ที่กำหนด; การเปิด public ต้องรอคำสั่ง Founder

### Governance
19. ไม่มี production deploy, migration production หรือการผูกโดเมน production ใด ๆ จนกว่า freeze จะปลดและผ่าน gate ครบ (Scope → Technical → Implementation → QA & Security → Staging → Founder → Production)
20. ค่าใช้จ่ายใหม่ทุกรายการ (Codemagic, Apple Developer Program, Google Play Console, โดเมน) ได้รับอนุมัติจาก Founder ก่อนสมัคร

## Priority

- Epic โดยรวม: **P1 ของ Founder** (เริ่มได้ทันทีในส่วนที่ไม่แตะ production: brand, PRD, architecture, scaffold แอป)
- ภายใน epic ใช้ P0/P1/P2 ตาม parity matrix: P0 53 รายการ, P1 36 รายการ, P2 7 รายการ

## Edge Cases

1. ผู้ใช้เว็บเดิมมีตะกร้า/ร้านโปรด/คำค้นล่าสุด/โค้ดที่เก็บไว้ใน localStorage ของ `food.wynos.online` → หลังย้ายโดเมนข้อมูลในเครื่องจะไม่ตามมา (คนละ origin) — ต้องยอมรับหรือทำทางย้ายข้อมูล (Q11)
2. Session ล็อกอินผูกกับ origin → ผู้ใช้เว็บทุกคนต้องล็อกอินใหม่บน `zoky.online`
3. PWA ที่ติดตั้งจาก `food.wynos.online` จะยังเปิด origin เดิม → redirect ออกจาก standalone; ต้องมีจอแนะนำให้ติดตั้งใหม่ (คล้ายจอ legacy เดิม)
4. Web Push subscription ผูกกับ origin เดิม → แจ้งเตือนบนเว็บเดิมจะหยุดเมื่อ token หมดอายุ ต้องเปิดใหม่บน `zoky.online`
5. QR poster/ลิงก์สั้นที่ร้านพิมพ์แล้ว → ต้อง redirect ได้ตลอด (ต้องต่ออายุ `wynos.online`)
6. ลิงก์ยืนยันอีเมล/รีเซ็ตรหัสผ่านที่ส่งก่อน cutover (ชี้ `food.wynos.online`) → ต้องยังใช้ได้ผ่าน redirect + Supabase redirect allowlist ทั้งเก่าและใหม่ช่วงเปลี่ยนผ่าน
7. Stripe checkout ที่เปิดค้างไว้ตอน cutover → success/cancel URL เดิมต้อง redirect มาที่ order ถูกต้อง
8. ลูกค้าเปิดลิงก์ร้านบนมือถือที่ติดตั้งแอปแล้วแต่ยังไม่ล็อกอินในแอป → แสดงร้านแบบ guest แล้วพาไปล็อกอินโดยจำร้านไว้
9. ผู้ใช้ใช้ทั้งเว็บและแอปพร้อมกัน → ตะกร้าแยกตามอุปกรณ์ (เหมือนเว็บข้ามเบราว์เซอร์วันนี้); ออเดอร์/ที่อยู่ sync จาก server
10. แอปอยู่ background ระหว่างนับถอยหลังชำระเงิน 10 นาที → กลับมาต้องคำนวณเวลาเหลือใหม่จาก `payment_due_at`
11. ปฏิเสธสิทธิ์ตำแหน่ง/รูปภาพ/แจ้งเตือน → มีทางเลือก (ค้นหาสถานที่แทน GPS, ข้อความแนะนำเปิดใน Settings)
12. แอปเวอร์ชันเก่าเรียก RPC ที่ถูกเปลี่ยน signature ภายหลัง → ต้องมีนโยบาย backward compatibility/บังคับอัปเดต (Architect)
13. ผู้ใช้นอกมหาสารคาม → ข้อความ "ส่งได้เฉพาะในจังหวัดมหาสารคาม" เหมือนเว็บ (server ตรวจ)
14. บัญชีนักพัฒนาต้องข้ามการตรวจพื้นที่ได้เหมือนเว็บ เพื่อให้ทีมทดสอบนอกพื้นที่ได้
15. ร้านเปลี่ยนเมนู/ราคา/สต็อกระหว่างลูกค้าอยู่ในตะกร้า → quote ใหม่และบล็อกเหมือนเว็บ

## Dependencies

1. **Founder**: ยืนยันชื่อหลังตรวจ trademark, ซื้อโดเมน `zoky.online`, อนุมัติค่าใช้จ่าย (Codemagic, Apple Developer Program, Google Play Console), เลือกบัญชีผู้พัฒนา (บุคคล/นิติบุคคล), อนุมัติ brand
2. **Production freeze** ต้องปลด/ผ่าน coordinated release ก่อนทำงาน production ใด ๆ (web rebrand deploy, โดเมน, migration, edge function)
3. **Backend changes ที่ต้องมีงานแยก + security review** (ยังไม่ได้รับอนุมัติ):
   - `food-stripe-checkout` / `food-stripe-cancel`: ตรวจ `Origin` เป็น `https://food.wynos.online` ใน live mode และ hardcode success/cancel URL — ต้องรองรับ `zoky.online` และแอป native
   - `send-food-promotion`: query token เฉพาะ `platform = web` — ต้องรองรับ iOS/Android
   - `send-push-notification`: ยืนยัน routing ของ token แอป ZOKY (ค่า `push_tokens.app`/`platform`)
   - `wynos-maps-geocode`: CORS/Origin allowlist ต้องเพิ่ม `zoky.online` (และพิจารณา request จากแอปที่ไม่มี Origin)
   - Copy แบรนด์ที่อยู่ใน SQL (เช่น ข้อความแจ้งเตือน, ชื่อผู้รีวิว fallback, ชื่อสินค้าใน Stripe `WYNOS Food #…`) ต้องใช้ migration/redeploy
4. **External config**: Vercel domain + DNS, Supabase Auth Site URL/redirect allowlist, Google OAuth clients (web + iOS + Android), Apple (APNs key, bundle ID, Associated Domains), Firebase (iOS/Android apps ใน FCM project), Stripe branding
5. **Software Architect**: technical design แอป Flutter (โฟลเดอร์, state/routing, map SDK, auth flow, deep links, push, local storage, CI)
6. **UI/UX Engineer**: ZOKY design system สำหรับ web + Flutter และ platform-adaptive spec
7. **QA & Security**: test matrix iOS/Android + auth/authz/upload/deep-link abuse

## Risks

(รายละเอียดและแนวทางลดความเสี่ยงอยู่ใน roadmap)

1. R1 Stripe edge functions ปฏิเสธ request จากแอป native/โดเมนใหม่ (origin check + URL hardcode)
2. R2 Push โปรโมชันส่งเฉพาะ web token; routing push ของแอปใหม่ยังไม่ยืนยัน
3. R3 App Store reject: Sign in with Apple (4.8), ลบบัญชีในแอป (5.1.1(v)), privacy label
4. R4 ย้ายโดเมนแล้วผู้ใช้เว็บหลุด session, ตะกร้า/ร้านโปรดในเครื่องหาย, PWA และ web push ต้องตั้งใหม่
5. R5 ลิงก์/QR เก่าต้อง redirect ตลอดไป (พึ่งพาการต่ออายุ `wynos.online`)
6. R6 ชื่อ "ZOKY" อาจชน trademark; โดเมนยังไม่ได้ซื้อ
7. R7 Maps: route `/api/maps/*` เป็น Next.js server route, edge function มี Origin allowlist, เงื่อนไขการใช้ tiles บนมือถือ
8. R8 Parity drift: ตรรกะฝั่ง client (เวลาเปิดร้าน, ตะกร้า, ระยะทาง, ที่อยู่) ต้องเขียนซ้ำใน Dart และเว็บยังพัฒนาต่อระหว่างนี้
9. R9 Founder มีแค่ iPad: ทดสอบ iPhone layout ได้จำกัด และไม่มีเครื่อง Android; ต้องดูแล signing ของ iOS บน cloud
10. R10 Production freeze ทำให้ backend changes ที่แอปต้องใช้ apply ไม่ได้จนกว่าจะปลด
11. R11 อีเมลยืนยัน/รีเซ็ตของ Supabase Auth ใช้ร่วมกับ WYNOS Social (แบรนด์ WYNOS)

## Open Questions for Founder

1. **Q1 ZOKY กับ WYNOS สัมพันธ์กันอย่างไร?** เช่น "ZOKY" เดี่ยว ๆ หรือ "ZOKY by WYNOS"; บัญชียังเรียกว่า "WYNOS Account" ไหม; ยังมีลิงก์ไป WYNOS Social และทางลัดจาก Social เข้า ZOKY ไหม
2. **Q2 Redirect แบบถาวรเมื่อไร?** แนะนำ 307 (ชั่วคราว) ช่วงทดสอบ แล้วเปลี่ยนเป็น 308 (ถาวร) หลังยืนยัน; และบน `zoky.online` จะคง path `/food/login` เดิมหรือใช้ `/login` ตรง ๆ
3. **Q3 Sign in with Apple** — เพิ่มไหม (อาจจำเป็นต่อการผ่าน App Store เพราะมี Google login; เป็น authentication architecture change)
4. **Q4 ลบบัญชีในแอป** — ทำในแอป ZOKY หรือพาไปหน้าลบบัญชีกลางของ WYNOS (บัญชีเดียวกับ Social: ลบแล้วหายทั้ง Social ด้วย)
5. **Q5 ค่าใช้จ่ายและบัญชีผู้พัฒนา** — อนุมัติ Codemagic, Apple Developer Program, Google Play Console ไหม; สมัครในนามบุคคลหรือนิติบุคคล (นิติบุคคลต้องมี D-U-N-S)
6. **Q6 Bundle ID** — ใช้ `online.zoky.app` (เสนอ) หรือ `io.wyn.zoky`; ตั้งแล้วเปลี่ยนไม่ได้หลังเผยแพร่
7. **Q7 ข้อมูลที่เว็บเก็บในเครื่อง** (ร้านโปรด, "เก็บโค้ด", คำค้นล่าสุด) — แอปเก็บในเครื่องแบบเดียวกันใช่ไหม (sync ข้ามอุปกรณ์ = ฟีเจอร์ใหม่ ต้องมี backend)
8. **Q8 แท็บ "ข้อความ"** ที่ยังเป็น placeholder — แสดงในแอปเหมือนเว็บ หรือซ่อนไว้จนมีแชทจริง
9. **Q9 เลขออเดอร์ขึ้นต้น "WF"** — คงไว้ไหม (เปลี่ยน = แก้ฝั่ง database และ Merchant)
10. **Q10 ชื่อในฝั่งร้าน/แอดมิน/แจ้งเตือน** — WYNOS Merchant, Admin และข้อความแจ้งเตือนที่ร้านเห็น ("WYNOS Food") เปลี่ยนเป็น ZOKY ด้วยไหม
11. **Q11 ย้ายโดเมนแล้วข้อมูลในเครื่องหาย** (ตะกร้า ร้านโปรด) — ยอมรับได้ไหม หรือต้องทำทางย้ายข้อมูล
12. **Q12 สีแบรนด์** — ปัจจุบัน Food ใช้แดง `#e32636` + splash ชมพู; ZOKY จะใช้แนวทาง white + rainbow accents ของ WYN หรือมีสีหลักของตัวเอง
13. **Q13 ภาษา** — แอป/เว็บ ZOKY ภาษาไทยอย่างเดียวเหมือนเว็บ Food ปัจจุบันใช่ไหม
14. **Q14 iPad** — แอปรองรับเฉพาะ iPhone (เปิดบน iPad แบบ compatibility) หรือทำ layout iPad ด้วย (เพิ่มงาน)
15. **Q15 ผู้ทดสอบ Android** — ใครเป็นคนทดสอบบนเครื่อง Android จริง
16. **Q16 ระหว่าง freeze** — อนุญาตให้ทำ TestFlight/Play internal (ไม่ใช่ production web) ได้ไหม ในเมื่อ backend fixes บางข้อยัง apply production ไม่ได้

## Recommendation

1. อนุมัติ PRD นี้เป็น scope ทิศทาง แล้วเริ่มงานที่ไม่แตะ production ก่อน: ตรวจชื่อ/trademark (ZOKY-101), brand (ZOKY-102), architecture (ZOKY-103)
2. ซื้อโดเมน `zoky.online` ทันทีเมื่อชื่อผ่านการตรวจ เพื่อกันคนอื่นจดก่อน (ค่าใช้จ่ายต่ำ แต่ต้องเป็นการตัดสินใจของ Founder)
3. ให้ Architect ทำ design ของ backend changes (R1, R2, R7) ก่อนเขียนแอป เพราะเป็น blocker ของ payment และ push
4. รวม web rebrand + domain cutover เข้า coordinated release ตาม freeze document ไม่ทำแยกระหว่าง freeze
5. ตอบ Q3/Q4 ก่อนส่ง TestFlight review ภายนอก (internal testing ยังไม่ต้องผ่าน App Review แบบเต็ม)

## Handoff

Founder อนุมัติ PRD + ตอบ Open Questions + อนุมัติ `APPROVAL_REQUIRED` ของ ZOKY ใน `.wyn/company/APPROVALS.md`
→ CTO review → Software Architect (ZOKY-103: Flutter architecture + backend changes design)
→ UI/UX (ZOKY-102 brand + design system, platform-adaptive spec) + Database (ตรวจผลกระทบ push/Stripe/copy migration)
→ Full-Stack (ZOKY-104 scaffold + CI, แล้ว slice ZOKY-105..111)
→ QA & Security (ZOKY-112) → CTO final review → TestFlight/Play internal → Staging (web rebrand)
→ Founder approval → Production (domain cutover + store release, ZOKY-113..115)
