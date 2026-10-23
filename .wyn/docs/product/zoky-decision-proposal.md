# ZOKY — ข้อเสนอการตัดสินใจ (Decision Record Draft)

> สถานะ: **PENDING FOUNDER APPROVAL — ยังไม่ได้อนุมัติ ห้ามนำไปดำเนินการ**
> ผู้เสนอ: AI Product Manager · วันที่: 2026-10-17
> PRD: `.wyn/tasks/backlog/ZOKY-100-zoky-customer-app.md`
>
> ตามกติกา `.wyn/company/RULES.md` คำขออนุมัติบันทึกใน `.wyn/company/APPROVALS.md` (มีรายการ `APPROVAL_REQUIRED` ชี้มาที่ไฟล์นี้แล้ว)
> และเมื่อ Founder อนุมัติ ให้คัดลอกข้อความ "ร่างสำหรับ DECISIONS.md" ด้านล่างไปบันทึกใน `.wyn/company/DECISIONS.md`
> พร้อมวันที่และคำพูดของ Founder จริง — **AI PM ไม่ได้แก้ DECISIONS.md**

ทิศทางที่ Founder ให้ไว้ในแชทวันที่ 2026-10-17 (ส่งต่อผ่าน agent ที่มอบหมายงาน) ถูกสรุปไว้ใน PRD ส่วน "Founder direction"
เอกสารนี้แยกเป็นข้อ ๆ เพื่อให้ Founder อนุมัติ/ปฏิเสธได้ทีละข้อ เพราะแต่ละข้อมีความเสี่ยงและ rollback ต่างกัน

---

## D1. เปลี่ยนแบรนด์ WYNOS Food (ฝั่งลูกค้า) เป็น ZOKY

- **Proposed change:** ชื่อ/โลโก้/ไอคอน/copy ที่ลูกค้าเห็นทั้งหมดของ WYNOS Food เปลี่ยนเป็น ZOKY บนเว็บ และใช้ชื่อเดียวกันกับแอป iOS/Android; ZOKY เป็นผลิตภัณฑ์ใหม่ ไม่เกี่ยวกับ ZOKY Marketplace เดิม (ZOKY-001..005 / SELLER-001..005); task ใหม่ใช้เลข `ZOKY-1xx`
- **Reason:** Founder ต้องการให้บริการสั่งอาหารมีแบรนด์ของตัวเอง
- **Benefits:** แบรนด์จำง่าย แยกจาก Social; พร้อมสำหรับชื่อแอปใน store
- **Risks:** ชื่ออาจชนเครื่องหมายการค้า (ยังไม่ตรวจ); ผู้ใช้เดิมสับสนช่วงเปลี่ยน; ข้อความแบรนด์บางส่วนอยู่ใน database/edge function (ต้อง migration/redeploy); WYNOS Merchant/Admin ยังเรียก "WYNOS Food" (Q10)
- **Files affected (เมื่อ implement):** `web/app/food/**`, `web/components/food/**`, `web/lib/food-*.ts`, `web/public/icons/food/*`, `web/public/sw.js`, tests ที่เกี่ยวข้อง; ข้อความใน `supabase/functions/food-stripe-checkout` และ SQL ที่มีคำว่า "WYNOS Food" (งานแยก)
- **Not changed:** ชื่อตาราง/RPC/bucket `food_*`, storage keys `wynos-food-*`, พฤติกรรมของแอป
- **Rollback:** revert PR ของ web rebrand (assets เป็นไฟล์ versioned ใหม่ ไม่ทับของเดิม)
- **Recommendation:** อนุมัติหลัง ZOKY-101 (ตรวจชื่อ/trademark) ผ่าน
- **สถานะ:** รออนุมัติ (PENDING)

## D2. โดเมน `zoky.online` + redirect จาก `food.wynos.online`

- **Proposed change:** `zoky.online` เป็นโดเมนหลักของเว็บ ZOKY บน Vercel Consumer Web project เดิม; `food.wynos.online` และ `wynos.online/food*` redirect ไป `zoky.online` โดยคง path+query (เริ่ม 307 แล้วเปลี่ยนเป็น 308 หลังยืนยัน); อัปเดต Supabase Auth redirect URLs, Google OAuth, Stripe success/cancel/origin, CORS ของ edge functions
- **Reason:** Founder ต้องการเปลี่ยนทั้งชื่อและโดเมน และต้องไม่ทำให้ลิงก์เดิมเสีย
- **Benefits:** URL ตรงกับแบรนด์; ลิงก์เก่า/QR poster ยังใช้ได้
- **Risks:** ผู้ใช้เว็บต้องล็อกอินใหม่; ตะกร้า/ร้านโปรดในเครื่องไม่ตามมา; PWA และ web push ต้องติดตั้ง/เปิดใหม่; ถ้า config ภายนอกพลาด Google login/อีเมลยืนยัน/Stripe อาจพัง; ต้องต่ออายุ `wynos.online` ตลอดไป; เป็น production infrastructure change ระหว่าง freeze
- **Cost:** ค่าจดโดเมนรายปี (Founder ตรวจราคาที่ registrar); custom domain บน Vercel project เดิมไม่คาดว่ามีค่าใช้จ่ายเพิ่ม (ต้องยืนยันข้อจำกัดของ plan ปัจจุบัน)
- **Files affected:** `web/proxy.ts`, `web/app/food/s/[code]/route.ts`, `web/lib/food-share.ts`, `web/components/food/food-auth.tsx`, `web/app/food/auth/callback/page.tsx`, `web/app/food/layout.tsx`, `supabase/functions/food-stripe-checkout/index.ts`, `supabase/functions/food-stripe-cancel/index.ts`, `supabase/functions/wynos-maps-geocode/index.ts`; config ใน Vercel, DNS, Supabase Auth, Google Cloud, Stripe
- **Rollback:** ปิด redirect (proxy/Vercel) → โดเมนเดิมเสิร์ฟเหมือนเดิม; คง redirect allowlist ของโดเมนเดิมไว้ตลอดช่วงเปลี่ยนผ่าน; ไม่มีการเปลี่ยนข้อมูลใน database
- **Recommendation:** ซื้อโดเมนทันทีหลังชื่อผ่าน; ทำ cutover ใน coordinated release หลังปลด freeze ตามลำดับใน roadmap
- **สถานะ:** รออนุมัติ (PENDING) — ต้องได้รับอนุมัติแยกอีกครั้งตอน production cutover

## D3. แอป iOS + Android เป็น Flutter แอปใหม่หนึ่งแอป (ฟีเจอร์เท่าเว็บ)

- **Proposed change:** สร้างแอป Flutter ใหม่ในโฟลเดอร์แยก (เสนอชื่อ `zoky_app/` — Architect ยืนยัน) ใช้ Supabase project/RPC/edge function เดิม ฟีเจอร์ตาม parity matrix 96 รายการ; UI แบรนด์เดียวกันและส่วนของระบบเป็น platform-adaptive
- **Reason:** Founder เลือก Flutter เพราะทีมเคยใช้ใน `app/`; แอปเดียวได้ทั้งสองแพลตฟอร์ม
- **Benefits:** โค้ดเดียวสอง store; reuse ประสบการณ์ `supabase_flutter`, `firebase_messaging`, `geolocator` จาก `app/`
- **Risks:** ต้องดูแลสองโค้ดเบส (Next.js + Flutter) สำหรับฟีเจอร์เดียวกัน; ตรรกะ client ต้องเขียนซ้ำใน Dart (parity drift); backend changes ที่จำเป็น (Stripe origin, push routing, maps origin) เป็น security-sensitive และติด freeze; **ขัดกับกติกาเดิม** ที่ให้พักแอป Flutter (decision 2026-09-19) และพัก Android native (decision 2026-10-10) — ข้อเสนอนี้คือแอปใหม่แยกโฟลเดอร์ ไม่ใช่การฟื้น `app/`, `seller_app/` หรือ `android/` ซึ่งยังพักต่อ
- **Files affected:** โฟลเดอร์ใหม่ทั้งหมด (`zoky_app/**`), CI config ใหม่; ไม่แตะ `app/`, `seller_app/`, `android/`
- **Rollback:** ไม่เผยแพร่/ถอดแอปจาก store; โฟลเดอร์แยกจึงลบหรือพักได้โดยไม่กระทบเว็บ
- **Recommendation:** อนุมัติ พร้อมระบุชัดว่าเป็นข้อยกเว้นของ decision 2026-09-19 เฉพาะแอป ZOKY
- **สถานะ:** รออนุมัติ (PENDING)

## D4. Cloud build สำหรับ iOS (Codemagic) และบัญชีผู้พัฒนา — ค่าใช้จ่ายใหม่

- **Proposed change:** ใช้ Codemagic (cloud macOS) build และ sign แอป iOS แล้วส่ง TestFlight; Android build ได้ทั้งบน Codemagic หรือ GitHub Actions (Linux, มี pattern เดิมใน `.github/workflows/android-release.yml`); สมัคร Apple Developer Program และ Google Play Console
- **Reason:** Founder มีแค่ iPad ไม่มี Mac — build iOS ต้องใช้ macOS
- **Options:**
  - A. **Codemagic** (แนะนำ) — ออกแบบมาสำหรับ Flutter, จัดการ code signing + ส่ง TestFlight ได้, มี free tier สำหรับบุคคล (ณ ข้อมูลที่ AI ทราบ ราว 500 นาที macOS ต่อเดือน; **ต้องตรวจราคาปัจจุบันจากเว็บ Codemagic ก่อนอนุมัติ**)
  - B. GitHub Actions macOS runners — ใช้ระบบเดิม แต่นาที macOS คิดแพงกว่า Linux หลายเท่าและต้องเขียน signing/upload เอง
  - C. เช่า Mac บน cloud — แพงและต้องดูแลเครื่องเอง ไม่แนะนำ
- **ค่าใช้จ่ายที่ต้องอนุมัติ (ตรวจราคาจริงก่อน):** Apple Developer Program (รายปี, ราว 99 USD), Google Play Console (ครั้งเดียว, ราว 25 USD), Codemagic (free tier หรือ pay-as-you-go ตามจำนวนนาที)
- **Risks:** ใบรับรอง/คีย์ signing และ App Store Connect API key ต้องเก็บใน secret store ของ CI เท่านั้น (ห้าม commit); ผูกกับ vendor ภายนอก; บัญชีนิติบุคคลต้องมี D-U-N-S (ใช้เวลา)
- **Files affected:** `codemagic.yaml` (ใหม่) หรือ workflow ใหม่ใน `.github/workflows/`
- **Rollback:** หยุดใช้ Codemagic ได้ทันที (ไม่มีสัญญาผูกมัดใน free tier); ย้ายไป GitHub Actions macOS ได้
- **Recommendation:** อนุมัติ A เริ่มที่ free tier และตั้งเพดานค่าใช้จ่าย; ตัดสินบัญชีบุคคล/นิติบุคคลก่อนสมัคร (Q5)
- **สถานะ:** รออนุมัติ (PENDING)

## D5. ตัวตนของแอป (App identity) — ข้อเสนอ

- **Proposed change (ข้อเสนอ ยังไม่ตัดสิน):**
  - iOS Bundle ID: `online.zoky.app`
  - Android applicationId: `online.zoky.app`
  - ชื่อที่แสดงบนหน้าจอ: `ZOKY`
  - Universal Links / App Links: `https://zoky.online` (paths `/s/*`, `/?store=`, `/?order=`, auth callback)
  - URL scheme สำรอง: `online.zoky.app://` (Architect ยืนยัน)
- **Reason:** reverse-DNS ของโดเมนที่เป็นของบริษัท; แยกจาก `io.wyn.wyn` (แอป WYNOS เดิม) ชัดเจน
- **Alternative:** `io.wyn.zoky` (ตามแนวเดิมของ `io.wyn.zokyseller` ใน roadmap เก่า) — ใช้ได้แม้ยังไม่ได้ซื้อโดเมน แต่ไม่สอดคล้องกับแบรนด์
- **Risks:** Bundle ID/applicationId **เปลี่ยนไม่ได้หลังเผยแพร่**; ถ้าไม่ได้ครอบครอง `zoky.online` ไม่ควรใช้ reverse-DNS ของโดเมนนั้น
- **Rollback:** เปลี่ยนได้ก่อนส่ง store ครั้งแรกเท่านั้น
- **Recommendation:** ใช้ `online.zoky.app` เมื่อซื้อโดเมนแล้ว
- **สถานะ:** รออนุมัติ (PENDING)

## D6. Backend changes ที่แอปต้องใช้ (รับทราบล่วงหน้า — แต่ละข้อขออนุมัติแยกตอน implement)

ไม่ได้ขออนุมัติให้ทำตอนนี้ — ระบุเพื่อให้ Founder เห็นขอบเขตที่ "reuse backend เดิม" ยังต้องแตะ:

1. `food-stripe-checkout` / `food-stripe-cancel`: origin check (`https://food.wynos.online`) และ success/cancel URL — security-sensitive
2. `send-food-promotion`: ส่งเฉพาะ `platform = web`
3. `send-push-notification`: routing token ของแอป ZOKY
4. `wynos-maps-geocode`: Origin allowlist
5. ข้อความแบรนด์ใน SQL/edge function
6. (ถ้า Founder ตอบ Q3/Q4 ว่าทำ) Sign in with Apple, การลบบัญชีในแอป — authentication architecture change

---

## ร่างสำหรับ DECISIONS.md (ใช้หลัง Founder อนุมัติเท่านั้น)

```markdown
## [YYYY-MM-DD] ZOKY — WYNOS Food (ฝั่งลูกค้า) เปลี่ยนเป็น ZOKY บน Web + iOS + Android

Founder ตัดสินใจ (คำพูดจริงของ Founder: "…"):
- ZOKY เป็นผลิตภัณฑ์ใหม่ = WYNOS Food ฝั่งลูกค้าที่เปลี่ยนแบรนด์ ไม่ใช่ ZOKY Marketplace เดิม; task ใช้เลข ZOKY-1xx
- โดเมนหลัก zoky.online; food.wynos.online redirect (คง path+query) — cutover ใน coordinated release หลังปลด freeze
- iOS + Android เป็นแอป Flutter ใหม่แอปเดียว (โฟลเดอร์แยก) ฟีเจอร์เท่าเว็บตาม `.wyn/docs/product/zoky-feature-parity.md`;
  เป็นข้อยกเว้นของ decision 2026-09-19 เฉพาะแอปนี้ (`app/`, `seller_app/`, `android/` ยังพัก)
- ฝั่งลูกค้าเท่านั้น; WYNOS Merchant ยังชื่อเดิม
- แบรนด์เดียวกันทุกแพลตฟอร์ม ส่วนของระบบปรับตาม iOS/Android
- iOS build ผ่าน Codemagic (อนุมัติค่าใช้จ่าย: …); ทดสอบผ่าน TestFlight / Play internal testing
- App identity: … (bundle ID ที่อนุมัติ)
- คำตอบ Open Questions: Q1 … Q16 …
```
