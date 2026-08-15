# Product Task — SELLER-001

Status: backlog
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ)

Feature: ZOKY Sellers by WYN — Foundation (new app, seller sign-in, store registration, Dashboard)

Goal: Stand up the new `seller_app/` Flutter app, let an existing WYN user sign in and register a store ("สมัครร้าน"), and land on a Seller Dashboard showing real stats computed from their own store's data — the foundation every other SELLER-XXX task builds on.

Target User: WYN users who want to sell products on ZOKY Marketplace

Problem: Nothing in ZOKY-001 through ZOKY-004 ever gave a seller a way to manage their own store/products/orders — `stores`/`products`/`product_variants` have select-only RLS for every client (no insert/update/delete path at all), and there's no app for a seller to use even if the RLS allowed it. Right now the only way products/stores exist in the database is if someone seeds them directly.

Requirements:

**สถาปัตยกรรมที่ตัดสินใจแล้วก่อนเริ่ม** (อ้างอิง DECISIONS.md 2026-08-15 "Phase 4 (ZOKY Sellers by WYN) — Founder ส่งเนื้อหา Section 12-17 เต็มแล้ว..."):
- **แอปใหม่ `seller_app/`** ที่ root ของ repo เดียวกัน (คู่กับ `app/`) — ไม่ใช้ Melos/monorepo tooling รอบแรก, bundle ID `io.wyn.zokyseller`, ชื่อแอป "ZOKY Sellers by WYN"
- **Backend เดียวกัน**: Supabase project เดียวกับ `app/` — duplicate `Env` (dart-define pattern) เข้า `seller_app/` ตรง ๆ
- **Authentication reuse ทั้งหมด**: ไม่สร้างระบบ auth ใหม่ — Seller คือผู้ใช้ WYN ที่มีอยู่แล้ว sign-in ด้วย Supabase Auth เดียวกัน (Google/Apple OAuth + Phone OTP — 3 วิธีเดียวกับที่ `AuthRepository`/`AuthMethodScreen` ของ `app/` มีอยู่แล้ว เพราะผู้ใช้อาจสมัคร WYN เดิมด้วยวิธีไหนก็ได้ จำกัดแค่วิธีเดียวจะล็อกบางคนออก) — ถ้า user sign-in สำเร็จแต่ยังไม่มีแถว `profiles` เลย (เข้า Seller app ก่อนเคยใช้แอป WYN Social) ให้ reuse ขั้นตอนตั้งชื่อผู้ใช้เดียวกับ `UsernameSetupScreen` ก่อน ไม่ปล่อยเป็น dead end
- **Design system**: seed color เดียวกัน (`0xFF2D6CDF`), Material 3, Blue+White+Soft Gray เหมือนเดิมทุกประการ

**สมัครร้าน** (Section 12):
- หลัง sign-in สำเร็จ (และมี `profiles` row แล้ว) → ตรวจว่า user มีร้านของตัวเองหรือยัง (`stores` where `owner_id = auth.uid()`)
- **ยังไม่มีร้าน** → แสดงฟอร์ม "สร้างร้านค้า" (ชื่อร้านบังคับ, คำอธิบายไม่บังคับ — โลโก้/แบนเนอร์ยกไป SELLER-004 Store Management เพื่อให้ SELLER-001 ขอบเขตเล็กที่สุดเท่าที่ยังใช้งานได้จริง) → กดสร้าง → insert แถว `stores` ใหม่ (`owner_id = auth.uid()`) → เข้า Dashboard
- **มีร้านอยู่แล้ว** → ข้ามฟอร์มไปที่ Dashboard ตรง ๆ
- **ขอบเขต V1: 1 seller ต่อ 1 ร้านค้า** (ไม่รองรับหลายร้านต่อคนในรอบนี้ — master prompt ไม่ได้ระบุชัดว่าต้องรองรับหลายร้าน เป็นขอบเขตที่ตัดสินใจเพื่อความง่าย ขยายได้ในอนาคตถ้า Founder ต้องการ)
- **Seller Approval (Section 25)**: auto-approved ทันทีที่สร้างร้าน ไม่มีขั้นตอนรออนุมัติจาก Admin รอบนี้ เพราะ WYN Admin (Phase 6) ยังไม่เริ่ม — บันทึกเป็น Known Issue ชัดเจน ไม่ใช่การมองข้าม

**Seller Dashboard** (Section 13 — เฉพาะส่วนที่ทำได้จริงตอนนี้):
- **New Orders**: จำนวน order ของร้านตัวเองที่สถานะ `pending` (ยังไม่ได้ประมวลผล)
- **Total Orders**: จำนวน order ทั้งหมดของร้านตัวเอง (ทุกสถานะ)
- **Today's Sales / Monthly Sales / Revenue**: ผลรวม `total` ของ order สถานะ `delivered` เท่านั้น (นับเป็นยอดขายจริงเมื่อลูกค้ายืนยันได้รับสินค้าแล้วเท่านั้น ไม่นับ pending/cancelled) กรองตามช่วงเวลา (วันนี้/เดือนนี้/ทั้งหมด)
- **Best Selling Products**: top 5 สินค้าตาม quantity รวมจาก `order_items` ของ order ร้านตัวเองที่ delivered แล้ว
- **Available Balance / Pending Payout**: **ยังทำไม่ได้รอบนี้** เพราะไม่มีระบบ Payout/Transaction เลย (Section 17/31) — แสดง "เร็ว ๆ นี้" แทน ไม่ใช่เลข 0 ปลอมที่ทำให้เข้าใจผิดว่าคำนวณแล้ว
- ทุกค่าคำนวณจาก query สดทุกครั้งที่เปิดหน้า ไม่ cache/denormalize (เหตุผลเดียวกับ ZOKY-004's rating — ตัวเลขธุรกิจต้องสะท้อนสถานะปัจจุบันเสมอ)

**Navigation shell**:
- Bottom Nav 5 tab: Dashboard (ทำเต็มรูปแบบรอบนี้) / สินค้า / คำสั่งซื้อ / ร้านค้า / การเงิน — 4 tab หลังเป็น placeholder "เร็ว ๆ นี้" จนกว่า SELLER-002/003/004/005 จะเสร็จ (มิเรอร์ pattern เดียวกับที่ ZOKY-001 ทำ placeholder ไว้ก่อน ZOKY-003 มาเติมทีหลัง)

**Database**:
- เพิ่ม insert/update policy ใหม่ให้ `stores` scoped `owner_id = auth.uid()` (ปัจจุบันมีแค่ select เท่านั้น)
- เพิ่ม select policy ใหม่ให้ `orders`/`order_items` scoped ให้ seller เห็น order ของร้านตัวเองได้ (ปัจจุบันมีแค่ select policy ฝั่ง buyer เท่านั้น) — **ยังไม่เพิ่ม write policy ให้ seller รอบนี้** (status transition ต้องผ่าน RPC ใหม่ ทำใน SELLER-003)

Acceptance Criteria:
- [ ] Sign-in ด้วย Google/Apple/Phone OTP ได้จริง (backend เดียวกับ WYN Social ทั้งหมด)
- [ ] User ที่ยังไม่มี `profiles` row ถูกพาไปตั้งชื่อผู้ใช้ก่อน ไม่ค้าง/crash
- [ ] User ที่ไม่มีร้านเห็นฟอร์มสร้างร้าน กรอกชื่อร้านแล้วสร้างสำเร็จ → เข้า Dashboard
- [ ] User ที่มีร้านอยู่แล้ว sign-in ครั้งถัดไปเข้า Dashboard ตรง ๆ ไม่เห็นฟอร์มสร้างร้านซ้ำ
- [ ] Dashboard แสดง New Orders/Total Orders/Sales/Revenue/Best Selling Products ที่คำนวณจากข้อมูลจริงของร้านตัวเองเท่านั้น (ไม่เห็นของร้านอื่น)
- [ ] User A (seller ร้าน X) ไม่เห็น order/สินค้าของร้าน Y เลยแม้จะพยายาม query ตรง ๆ — ตรวจฝั่ง server (RLS)
- [ ] Bottom Nav 5 tab แสดงถูกต้อง 4 tab ที่ยังไม่ทำแสดง placeholder ไม่ crash
- [ ] WYN Social (`app/`) และ ZOKY Marketplace Customer เดิมทั้งหมดยังทำงานปกติ ไม่มี regression (ไม่ได้แก้ไฟล์ใน `app/` เลยนอกจากที่จำเป็นสำหรับ RLS ใหม่ใน `supabase/schema.sql` ซึ่งเป็นการเพิ่ม ไม่ใช่แก้ policy เดิม)

Dependencies: ZOKY-001 ถึง ZOKY-004 (Marketplace Customer — Approved ทั้งหมด, ต้องมี `stores`/`products`/`orders` schema อยู่แล้ว)

Priority: P0 ของ Phase 4 — ทุก SELLER-XXX task ถัดไปต้องมีแอปนี้เป็นฐานก่อน

Risks:
- **1 seller ต่อ 1 ร้านเป็นข้อจำกัดที่ตั้งใจ**: ถ้า Founder ต้องการให้ 1 คนเปิดหลายร้านได้ในอนาคต ต้องออกแบบ UI เลือกร้าน (store switcher) เพิ่ม — ไม่ใช่แค่ schema change เพราะ `stores.owner_id` ไม่ unique อยู่แล้ว รองรับหลายร้านต่อ owner ได้จาก DB แต่ UI รอบนี้ไม่ทำ
- **Seller Approval auto-approved**: ไม่มีการตรวจสอบร้านก่อนเปิดขายเลยรอบนี้ (spam store เปิดได้อิสระ) — ต้องรอ WYN Admin (Phase 6) มาปิดช่องว่างนี้ เตือน Founder ไว้ชัดเจนว่าเป็นความเสี่ยงที่ยอมรับได้ชั่วคราวไม่ใช่การมองข้าม
- **RLS ใหม่ต้องตรวจสอบละเอียดเป็นพิเศษ**: `products`/`orders` insert/select policy ใหม่ต้อง scope ผ่าน `stores.owner_id` ให้ถูกต้อง ผิดจุดเดียวจะทำให้ seller เห็น/แก้ข้อมูลร้านอื่นได้ — เตือน Coding/QA ให้เน้นเป็นพิเศษเหมือนที่เคยพบช่องโหว่จริงใน ZOKY-004 QA รอบ 1

Recommendation:
1. เริ่ม SELLER-001 ทันทีเป็นฐานของ Phase 4 ทั้งหมด
2. เน้น RLS ให้ถูกต้องเป๊ะตั้งแต่ต้น (บทเรียนตรงจาก ZOKY-004's update-policy-gap) — insert policy ของ `stores` และ select policy ใหม่ของ `orders`/`order_items` ต้องมี `exists`/ownership check ที่ทดสอบ attack scenario ครบ
3. ขอบเขต Dashboard เล็กที่สุดเท่าที่ยังมีประโยชน์จริง (ไม่พยายามทำ Balance/Payout ที่ยังไม่มีระบบรองรับ)

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) Seller sign-in flow (จำนวนหน้าจอ/รายละเอียด reuse จาก `app/`'s auth screens เท่าไหร่) (2) ฟอร์มสร้างร้านค้า (3) Seller Dashboard layout (stat card, best-selling list) (4) Bottom Nav 5 tab + placeholder screens — ใช้ Design system เดิม (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass) reuse component pattern จาก `app/` ที่ทำได้ (จะต้อง duplicate โค้ดเพราะเป็นคนละแอป แต่ให้ยึด "โครง"/pattern เดียวกันเสมอ ไม่ประดิษฐ์ visual language ใหม่)

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/seller-001-foundation.md` — สรุป: `SellerAuthGate` mirror `AuthGate` เดิมเป๊ะ เพิ่มชั้นตรวจร้านค้า (sign-in → username → store → shell) — `SellerSignInScreen` รวม Welcome+AuthMethod เดิมเป็นหน้าเดียว (ไม่ต้องมี flow "สมัครใหม่" เพราะ Seller เป็น WYN user เดิมเสมอ) reuse Google/Apple/Phone OTP 3 วิธี, `PhoneEntryScreen`/`OtpVerificationScreen`/`UsernameSetupScreen` ported ตรงจาก `app/` ไม่ปรับ logic — `CreateStoreScreen` ใหม่ (ชื่อร้าน+คำอธิบาย สั้นที่สุดเท่าที่ใช้งานได้จริง ไม่มีโลโก้/แบนเนอร์รอบนี้) — `SellerHomeShell` Bottom Nav 5 tab (`IndexedStack` mirror `RootShell`) Dashboard เต็มรูปแบบ+4 placeholder ผ่าน `SellerComingSoonScreen` เดียวกัน — `SellerDashboardScreen` stat card (New/Total Orders, Sales วันนี้/เดือนนี้/รวม, Best Selling top 5) + "เร็ว ๆ นี้" แทนตัวเลขปลอมสำหรับ Balance/Payout ที่ยังไม่มีระบบรองรับ — เตือน Coding เรื่อง RLS ใหม่ต้องตรวจ ownership ผ่าน `exists` join กลับ `stores.owner_id` ให้ถูกต้อง, 1 seller ต่อ 1 ร้าน (`maybeSingle()`), ตัวเลข Dashboard คำนวณสดทุกครั้ง

Handoff: ส่งต่อ AI Coding (`/code`)
