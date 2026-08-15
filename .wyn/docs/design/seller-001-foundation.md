# Design — SELLER-001 (ZOKY Sellers by WYN: Foundation)

อ้างอิง Product spec: `.wyn/tasks/backlog/SELLER-001-foundation.md` — สร้างแอปใหม่ `seller_app/`, sign-in reuse WYN Auth เดิม, สมัครร้าน, Dashboard พื้นฐาน

Design system เดิมทั้งหมด (Blue+White+Soft Gray seed `0xFF2D6CDF`, Material 3, Rounded Cards, ห้าม Liquid Glass) — โครง/pattern ทุกอย่าง mirror จาก `app/` ที่มีอยู่แล้ว เพราะเป็นคนละ Flutter binary ต้อง duplicate โค้ดจริง แต่ต้องยึด "หน้าตา/พฤติกรรม" เดียวกันเป๊ะ ไม่ประดิษฐ์ visual language ใหม่

## Screen: SellerAuthGate (ตรรกะ ไม่ใช่ UI — mirror `AuthGate` ของ `app/` เป๊ะ)

Purpose: ตัดสินใจว่าจะแสดงหน้าจอไหนตาม auth + onboarding + store state

User Flow (ลำดับการตรวจสอบ):
1. ยังไม่ sign-in → `SellerSignInScreen`
2. Sign-in แล้วแต่ยังไม่มี `profiles` row (`hasUsername` false — mirror `AuthRepository.hasUsername` เดิม) → `UsernameSetupScreen` (ported จาก `app/` แทบทั้งดุ้น เปลี่ยนแค่ปลายทางหลังตั้งชื่อเสร็จ)
3. มี `profiles` แล้วแต่ยังไม่มี `stores` ของตัวเอง (`owner_id = auth.uid()`) → `CreateStoreScreen`
4. มีทั้งคู่ → `SellerHomeShell`

Components: `StreamBuilder<AuthState>` ฟัง `authStateChanges` เดียวกับ `AuthGate`, `FutureBuilder<bool>` เช็ค username, `FutureBuilder<Store?>` เช็คร้าน (เพิ่มจาก `AuthGate` เดิม 1 ชั้น) — pop-to-first บน sign-in/sign-out event เดียวกันเป๊ะ (กัน user ค้างหน้าจอเก่าหลัง state เปลี่ยน ตาม `.wyn/learning/MISTAKES.md`)

Handoff: `SellerRepository` (ใหม่) ต้องมี `fetchMyStore()` คืน `Store?` (`stores` where `owner_id = auth.uid()` — reuse `Store` model เดียวกับที่มีอยู่แล้วใน `app/`'s `ZokyRepository`, duplicate model class เข้า `seller_app/` เพราะคนละ binary)

---

## Screen: SellerSignInScreen (ใหม่ — แทนที่ `WelcomeScreen`+`AuthMethodScreen` รวมกัน)

Purpose: ให้ seller ที่มีบัญชี WYN อยู่แล้ว sign-in เข้า Seller app

User Flow: เปิดแอป (ยังไม่ sign-in) → เห็นโลโก้ "ZOKY Sellers by WYN" + ปุ่ม 3 วิธี (Google/Apple/Phone) → เลือกวิธี → สำเร็จ → `SellerAuthGate` ตัดสินใจหน้าถัดไปเอง

Components: รวม `WelcomeScreen`'s branding block กับ `AuthMethodScreen`'s ปุ่ม 3 วิธีเป็นหน้าเดียว (ไม่ต้องแยก 2 หน้าเหมือน `app/` เพราะ Seller app ไม่มี flow "สมัครใหม่" ที่ต้องอธิบายก่อน — ผู้ใช้ที่เปิดแอปนี้คือ WYN user ที่ตั้งใจมาสมัครร้านอยู่แล้ว) — ปุ่ม "เข้าสู่ระบบด้วย Google"/"เข้าสู่ระบบด้วย Apple" (mirror `AuthMethodScreen`'s wording เป๊ะ) + ปุ่ม "เข้าสู่ระบบด้วยเบอร์โทร" เปิด `PhoneEntryScreen`→`OtpVerificationScreen` (ported ตรงจาก `app/` ทั้งคู่ ไม่ต้องปรับ logic เลยเพราะ `AuthRepository`'s `sendPhoneOtp`/`verifyPhoneOtp` เหมือนเดิมทุกประการ)

Interactions/States: เหมือน `AuthMethodScreen`/`PhoneEntryScreen`/`OtpVerificationScreen` เดิมทุกจุด (loading state ระหว่างรอ OAuth/OTP, error SnackBar เมื่อ fail)

Design Rules: ข้อความอธิบายเพิ่มเติมใต้โลโก้ระบุชัดว่านี่คือแอปสำหรับร้านค้า เช่น "เข้าสู่ระบบด้วยบัญชี WYN ของคุณเพื่อเริ่มขายของบน ZOKY" กันผู้ใช้สับสนว่าเป็นแอปเดียวกับ WYN Social

Handoff: `SellerAuthRepository` (ใหม่ใน `seller_app/`) มิเรอร์ `AuthRepository`'s method signatures เป๊ะ (`signInWithGoogle`/`signInWithApple`/`sendPhoneOtp`/`verifyPhoneOtp`/`hasUsername`/`authStateChanges`/`currentSession`) — ชี้ไปที่ Supabase project เดียวกัน

---

## Screen: CreateStoreScreen (ใหม่)

Purpose: ให้ seller "สมัครร้าน" ครั้งแรก

User Flow: `SellerAuthGate` พาเข้ามาเมื่อ sign-in แล้วแต่ยังไม่มีร้าน → กรอกชื่อร้าน (บังคับ) + คำอธิบาย (ไม่บังคับ) → กด "สร้างร้านค้า" → insert `stores` row สำเร็จ → `SellerAuthGate` rebuild เข้า `SellerHomeShell` อัตโนมัติ (เหมือน `UsernameSetupScreen`'s `onUsernameSet` callback pattern)

Components: `TextField` ชื่อร้าน (mirror `CreateDropScreen`'s caption field styling), `TextField` คำอธิบาย (multiline, optional), `FilledButton` "สร้างร้านค้า" (disable จนกว่าจะกรอกชื่อร้าน, แสดง loading ระหว่างส่ง)

States: error (SnackBar "สร้างร้านค้าไม่สำเร็จ ลองใหม่อีกครั้ง" ถ้า insert fail), submitting (disable ปุ่ม+loading indicator กันกดซ้ำ — mirror ปุ่มยืนยันคำสั่งซื้อจาก ZOKY-003)

Design Rules: ไม่มีฟิลด์โลโก้/แบนเนอร์ในหน้านี้ (ยกไป SELLER-004 ตามที่ Product spec ตัดสินใจ) — หน้านี้ต้องสั้นที่สุดเท่าที่ยังใช้งานได้จริงเพื่อลด friction ตอนสมัครร้านครั้งแรก

Handoff: `SellerRepository.createStore({required String name, String? description})` insert `stores` แล้วคืน `Store` ที่สร้างเสร็จ

---

## Screen: SellerHomeShell (ใหม่ — Bottom Nav shell)

Purpose: โครง navigation หลักของ Seller app หลัง sign-in + มีร้านแล้ว

User Flow: เปิดแอปแล้ว sign-in + มีร้านแล้ว → เห็น Bottom Nav 5 tab ทันที เริ่มที่ Dashboard

Components: `IndexedStack` + `NavigationBar` (mirror `RootShell`'s pattern เป๊ะ — เก็บ state ทุก tab ไม่ unmount ตอนสลับ) 5 tab: Dashboard (`Icons.dashboard_outlined`) / สินค้า (`Icons.inventory_2_outlined`) / คำสั่งซื้อ (`Icons.receipt_long_outlined`) / ร้านค้า (`Icons.storefront_outlined`) / การเงิน (`Icons.account_balance_wallet_outlined`)

States: 4 tab หลัง (สินค้า/คำสั่งซื้อ/ร้านค้า/การเงิน) เป็น placeholder screen เดียวกัน (`SellerComingSoonScreen`, รับ label เป็น parameter) แสดงข้อความ "ฟีเจอร์นี้จะมาเร็ว ๆ นี้" (`zokyComingSoonMessage` เดิม duplicate เข้า `seller_app/`) จนกว่า SELLER-002/003/004/005 จะเติมแต่ละ tab

Design Rules: ลำดับ tab ตรงกับลำดับที่ระบุใน Product spec เป๊ะ (Dashboard ต้องเป็น tab แรกเสมอเพราะเป็นหน้า landing หลักของ seller)

Handoff: ส่งต่อ AI Coding

---

## Screen: SellerDashboardScreen (ใหม่)

Purpose: แสดงสถิติร้านตัวเองที่คำนวณได้จริงตอนนี้

User Flow: เปิด Dashboard tab → เห็น stat card 4 กลุ่ม (New Orders, Total Orders, Sales/Revenue, Best Selling) เรียงจากบนลงล่าง โหลดสดทุกครั้งที่เปิดหน้า (ไม่ cache)

Components:
- Header: ชื่อร้าน + "แดชบอร์ด" (mirror `AppBar` เดิม)
- Stat card แถวคู่ (2 คอลัมน์): "คำสั่งซื้อใหม่" (New Orders count) + "คำสั่งซื้อทั้งหมด" (Total Orders count) — ใช้ `Card` แบบ rounded เดียวกับ `OrderSummaryCard`/สินค้า card ที่มีอยู่แล้วในโปรเจกต์ (ตัวเลขใหญ่เด่น + label เล็กด้านล่าง)
- Sales summary card: ยอดขายวันนี้ / เดือนนี้ / รวมทั้งหมด (3 แถวในการ์ดเดียว, mirror `_summaryRow` pattern จาก `ZokyOrderDetailScreen`)
- "สินค้าขายดี" section: list สูงสุด 5 รายการ (ชื่อสินค้า + จำนวนที่ขายได้) — ถ้ายังไม่มีสินค้าขายเลยแสดง "ยังไม่มีข้อมูลการขาย" (ไม่ error)
- "ยอดคงเหลือ"/"รอโอน" card: แสดงข้อความ "เร็ว ๆ นี้" แทนตัวเลข (ตามที่ Product spec ระบุชัดว่ายังทำไม่ได้ — **ห้ามแสดงเลข 0 ที่ทำให้เข้าใจผิดว่าคำนวณแล้วจริง**)

Interactions: pull-to-refresh (`RefreshIndicator`) รีโหลดสถิติใหม่ (mirror pattern ที่มีอยู่แล้วใน feed screens ของ `app/`)

States: loading (skeleton/`CircularProgressIndicator` ตอนโหลดครั้งแรก), error (silent-fail แสดงค่าว่าง/"โหลดไม่สำเร็จ" ไม่ทำให้ทั้งหน้าพัง — mirror `_showComingSoon` error-tolerance pattern ที่ ZOKY ใช้ทั่วไป)

Design Rules: ตัวเลขเงินใช้ `thaiBahtLabel` เดิม (`core/text_utils.dart`, duplicate เข้า `seller_app/`) เพื่อความสม่ำเสมอของ format

Handoff: `SellerRepository` เมธอดใหม่: `fetchOrderCounts(storeId)` คืน `(int newOrders, int totalOrders)`, `fetchSalesSummary(storeId)` คืน `(double today, double thisMonth, double allTime)` (sum `orders.total` where `status = 'delivered'`), `fetchBestSellingProducts(storeId, {limit = 5})` คืน `List<(String productName, int quantitySold)>` (aggregate `order_items` join `orders` where `store_id` ตรงและ `status = 'delivered'`)

---

## Screen: SellerComingSoonScreen (widget ใหม่ reuse ได้)

Purpose: placeholder เดียวสำหรับ 4 tab ที่ยังไม่ทำ

Components: `Scaffold(appBar: AppBar(title: Text(label)), body: Center(child: Text(zokyComingSoonMessage)))` — รับ `label` เป็น parameter (ชื่อ tab)

Handoff: ส่งต่อ AI Coding (`/code`)

---

## เตือน Coding (จาก Product spec's Risks)

1. **RLS ใหม่ต้องตรวจสอบละเอียดเป็นพิเศษ** (บทเรียนตรงจาก ZOKY-004 QA รอบ 1) — `stores`'s insert/update policy ต้อง `with check`/`using` ตรวจ `owner_id = auth.uid()` ทั้งคู่ (insert และ update), `orders`/`order_items`'s select policy ใหม่ฝั่ง seller ต้อง `exists` join กลับไปที่ `stores.owner_id = auth.uid()` ให้ถูกต้อง ไม่ใช่แค่เช็ค `store_id` ตรง ๆ (เพราะ client ส่ง `store_id` เองไม่ได้ในบริบทนี้ แต่ query filter ต้อง join ผ่าน stores เสมอ)
2. **1 seller ต่อ 1 ร้าน**: `fetchMyStore()` ควร `maybeSingle()`/limit 1 — ถ้ามีมากกว่า 1 แถวในอนาคต (ยังไม่ enforce unique constraint ระดับ DB รอบนี้ตาม Product spec) ต้องไม่ crash แค่เอาแถวแรก
3. **ทุกตัวเลขใน Dashboard คำนวณสดทุกครั้ง ห้าม cache/denormalize** (หลักการเดียวกับ ZOKY-004's rating)
