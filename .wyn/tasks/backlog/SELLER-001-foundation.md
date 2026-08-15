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

---

## Coding Output (AI Coding)

Implementation:
- **สร้างแอปใหม่ `seller_app/`** ที่ root repo (sibling ของ `app/`) ด้วย `flutter create --org io.wyn --project-name zoky_seller --platforms=android,ios seller_app` แล้วปรับ bundle ID/applicationId ด้วยมือให้ตรง `io.wyn.zokyseller` เป๊ะทั้ง Android (`namespace`/`applicationId` ใน `build.gradle.kts`, Kotlin package path) และ iOS (`PRODUCT_BUNDLE_IDENTIFIER` ทุกจุดใน `project.pbxproj`) — ไม่ใช้ Melos/monorepo tooling ตามที่ Product spec ระบุ, `analysis_options.yaml`/`.gitignore` copy ตรงจาก `app/` เพื่อความสม่ำเสมอ
- **Env/Theme**: `core/env.dart` duplicate pattern จาก `app/lib/core/env.dart` เป๊ะ (dart-define เดียวกัน ชี้ Supabase project เดียวกัน), `main.dart` ใช้ seed color/Material 3 setup เดียวกับ `app/lib/main.dart` เป๊ะ (`0xFF2D6CDF`, light+dark)
- **Auth reuse**: `SellerAuthRepository` (ใหม่) mirror `AuthRepository`'s method signatures เป๊ะ ต่างแค่ OAuth redirect scheme (`io.wyn.zokyseller://login-callback`) — `PhoneEntryScreen`/`OtpVerificationScreen`/`UsernameSetupScreen`/`OtpBoxInput` ported ตรงจาก `app/` ไม่เปลี่ยน logic ใด ๆ (เปลี่ยนแค่ import path) — `SellerSignInScreen` ใหม่ (รวม Welcome+AuthMethod เป็นหน้าเดียวตาม Design spec)
- **`SellerAuthGate`**: mirror `AuthGate`'s `StreamBuilder<AuthState>`/pop-to-first-route-on-sign-in-out pattern เป๊ะ เพิ่มชั้นที่ 3 ตรวจ `stores` ผ่าน `FutureBuilder<Store?>` — จงใจเช็ค `connectionState != ConnectionState.done` แทน `hasData` สำหรับชั้นนี้ (บทเรียนตรงจากบั๊กจริงที่เจอใน ZOKY-001's `StoreScreen`: `Store?` resolve เป็น `null` ได้ถูกต้องตามธุรกิจ ถ้าเช็ค `hasData` จะวนลูป spinner ตลอดกาลสำหรับ seller ที่ยังไม่มีร้านจริง ๆ) — เพิ่ม constructor injection ที่เป็น optional (`authRepository`/`sellerRepository`) เพื่อให้ทดสอบ branching ได้จริงด้วย widget test (ต่างจาก `app/`'s `AuthGate` ที่ทดสอบตรงไม่ได้เพราะสร้าง `AuthRepository` เองภายในเสมอ ตามที่บันทึกไว้ใน `.wyn/learning/MISTAKES.md`, WYN-002 — เป็นการปรับปรุงเล็ก ๆ ที่จำกัดผลกระทบแค่แอปใหม่นี้ ไม่แตะ `app/`)
- **`CreateStoreScreen`**: ฟอร์มชื่อร้าน (บังคับ) + คำอธิบาย (ไม่บังคับ) ใช้ callback-to-parent-rebuild pattern เดียวกับ `UsernameSetupScreen`'s `onUsernameSet` (`onStoreCreated`)
- **`SellerHomeShell`**: Bottom Nav 5 tab (`IndexedStack` mirror `RootShell`) — Dashboard tab แรกเต็มรูปแบบ, 4 tab หลัง (`สินค้า`/`คำสั่งซื้อ`/`ร้านค้า`/`การเงิน`) ใช้ `SellerComingSoonScreen` เดียวกัน (`zokyComingSoonMessage` string duplicate ตรงตาม Design spec ระบุ)
- **`SellerDashboardScreen`**: New/Total Orders count, Sales วันนี้/เดือนนี้/รวมทั้งหมด (เฉพาะ `status = 'delivered'`), Best Selling top 5 (aggregate `order_items` join `orders!inner` ผ่าน embedded-resource filter `.eq('order.store_id', ...)`/`.eq('order.status', 'delivered')`), ส่วน Balance/Payout แสดง "เร็ว ๆ นี้" ตรงตาม Product spec ("ห้ามแสดงเลข 0 ปลอม") — ทุกค่าคำนวณสดทุกครั้งที่เปิดหน้า/pull-to-refresh ไม่ cache (mirror `fetchProductRating`/`fetchStoreRating`'s client-side aggregation pattern จาก ZOKY-004)
- **Database** (`supabase/schema.sql`, section ใหม่ท้ายไฟล์ "SELLER-001"): เพิ่ม insert/update policy ให้ `stores` (`with check`/`using` ทั้งคู่ตรวจ `auth.uid() = owner_id`) และ select policy ใหม่ให้ `orders`/`order_items` scoped ผ่าน `exists` join กลับ `stores.owner_id = auth.uid()` (ไม่ใช่เช็ค `store_id` ตรง ๆ ตามคำเตือนของ Design/Product) — ทั้งสองเป็น select policy เพิ่มเติม (permissive, รวมกันด้วย OR) ไม่แตะ policy select ฝั่ง buyer เดิมเลย, ไม่มี insert/update/delete policy ใหม่ให้ `orders`/`order_items` ตามขอบเขตที่ตกลงไว้ (SELLER-003 เป็นคนทำ RPC สำหรับ status transition)

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. `SellerDashboardScreen._load()` เขียนเป็น `setState(() => _statsFuture = _fetchStats())` ตอนแรก — arrow closure คืนค่าของ assignment expression (คือค่า `Future` ที่ `_fetchStats()` ส่งกลับ) ทำให้ Flutter throw "setState() callback argument returned a Future" ตอน `initState()` เรียก `_load()` ครั้งแรก เจอจาก `flutter test` ล้มทันทีตั้งแต่รอบแรก — แก้เป็น block body `setState(() { _statsFuture = _fetchStats(); })` แทน เป็นรูปแบบบั๊กใหม่ที่ยังไม่เคยบันทึกไว้ใน `.wyn/learning/`
2. สร้าง `RecordingSellerAuthRepository`/`RecordingSellerRepository` inline ใน `testWidgets` callback ในทุกไฟล์ test ตอนแรก (gotcha "Timer is still pending" เดิมที่เคยบันทึกไว้แล้วจาก ZOKY-002/ZOKY-004) ทำให้ `flutter test` ล้ม 9 เทสต์ — ย้ายทั้งหมดเข้า `setUp()` เป็น named field ตามธรรมเนียม แก้แล้วผ่านหมด

Files Changed:
- ใหม่ทั้งหมด: `seller_app/` (แอป Flutter ใหม่ทั้งแอป — `android/`, `ios/`, `lib/`, `test/`, `pubspec.yaml`/`.lock`, `analysis_options.yaml`, `.gitignore`, `README.md`)
- แก้: `supabase/schema.sql` (เพิ่ม SELLER-001 section ท้ายไฟล์ — 2 select policy ใหม่ + insert/update policy ของ `stores`, ไม่แก้ policy เดิมจุดใดเลย)
- ไม่แตะไฟล์ใดใน `app/` เลยแม้แต่บรรทัดเดียว

Tests:
- `seller_app/test/`: `seller_auth_gate_test.dart` (4 เคส — signed out/no-username-with-store/no-store/has-store, ยืนยันลำดับการตรวจสอบ 4 ชั้นถูกต้องรวมถึง edge case "มีร้านแต่ยังไม่มี username ต้องเจอ UsernameSetupScreen ก่อนเสมอ"), `create_store_screen_test.dart` (3 เคส — validation/success/failure), `seller_dashboard_screen_test.dart` (3 เคส — คำนวณ+แสดงผลตัวเลขถูกต้อง, empty state, "เร็ว ๆ นี้" ไม่ใช่เลข 0), `seller_home_shell_test.dart` (3 เคส — 5 destination, 4 placeholder ไม่ crash, `IndexedStack` ไม่ unmount), `otp_box_input_test.dart` (4 เคส ported ตรงจาก `app/test/`) — รวม 17/17 ผ่าน
- `flutter analyze` (`seller_app/`): สะอาด, ไม่มี issue
- `flutter test` (`seller_app/`): **17/17 ผ่าน**
- `flutter analyze` (`app/`): สะอาด (ไม่กระทบจาก schema.sql เพิ่มเติม เพราะ Dart ไม่ query schema.sql ตรง ๆ)
- `flutter test` (`app/`): **255/255 ผ่าน** — RLS policy ใหม่ใน `supabase/schema.sql` ไม่กระทบ regression กับ WYN Social/ZOKY Marketplace Customer เดิมเลย (ไม่มี raw SQL query จริงในเทสต์ ยืนยันด้วยการรัน suite เดิมซ้ำทั้งหมดหลัง sync branch)

Build: `flutter build apk`/`flutter build ios` ยังไม่ได้ทำ — sandbox นี้ไม่มี Android SDK/Xcode ให้ build ไฟล์ APK/IPA จริง (เหมือนสถานะเดิมของ `app/` ตั้งแต่ WYN-002) ต้องทำในเครื่อง dev/CI ที่มี toolchain ครบ

Known Issues:
- Seller Approval auto-approved (รอ WYN Admin, Phase 6) — ตามที่ Product spec ระบุไว้ชัดเจนแล้วว่าเป็นความเสี่ยงที่ยอมรับได้ชั่วคราว
- 1 seller ต่อ 1 ร้าน, ไม่มี store switcher UI — ขอบเขต V1 ตามที่ตกลงไว้
- OAuth native URL scheme (`io.wyn.zokyseller://login-callback`) ยังไม่ได้ตั้งค่าจริงใน `AndroidManifest.xml`/`Info.plist` (เหมือนสถานะเดิมของ `app/`'s `io.wyn.app://` ตั้งแต่ WYN-002 — ต้องทำก่อน deploy จริง ไม่ใช่ blocker ของ Coding phase นี้)
- Balance/Payout แสดง "เร็ว ๆ นี้" ตามที่ Product spec ตั้งใจไว้ ไม่ใช่ gap

Handoff: ส่งต่อ AI QA & Security (`/qa`) — เน้นตรวจ RLS ใหม่ทั้ง 3 policy เป็นพิเศษ (attack scenario: seller A พยายามเห็น/แก้ store หรือ order ของ seller/buyer อื่น), ตรวจ `SellerAuthGate`'s ลำดับ 4 ชั้นให้ตรงกับ Design spec เป๊ะ, ตรวจว่า `app/` ไม่ถูกแตะเลยจริง
