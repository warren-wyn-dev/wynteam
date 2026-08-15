# Product Task — SELLER-004

Status: backlog
Owner: AI Product Manager

Feature: ZOKY Sellers by WYN — Store Management (edit store profile: name/description/logo/banner/address/contact/business hours)

Goal: แทนที่ "ร้านค้า" tab (index 3 ของ `SellerHomeShell`) ที่ยังเป็น `SellerComingSoonScreen` placeholder ด้วยหน้าจอแก้ไขข้อมูลร้านจริง ให้ seller ที่สมัครร้านผ่าน SELLER-001 ไปแล้ว (ตอนนั้นตั้งใจให้กรอกแค่ชื่อ+คำอธิบายสั้นที่สุด) กลับมาเติม/แก้ไขข้อมูลร้านให้ครบตาม master prompt Section 16 ได้ในภายหลัง — และให้ข้อมูลใหม่เหล่านี้ (โดยเฉพาะ banner ที่มีคอลัมน์ `banner_url` อยู่แล้วตั้งแต่ ZOKY-001 แต่ไม่เคยมีทาง set หรือแสดงผลเลยจนถึงตอนนี้) ปรากฏจริงบน `StoreScreen` ฝั่งลูกค้าด้วย

Target User: Seller ที่มีร้านค้าแล้ว (ผ่าน SELLER-001's "สมัครร้าน") ที่ต้องการเติม/แก้ไขข้อมูลร้านให้ลูกค้าเห็นครบถ้วนน่าเชื่อถือขึ้น

Problem: `CreateStoreScreen` (SELLER-001) ตั้งใจเก็บแค่ชื่อร้าน+คำอธิบายตอนสมัครร้าน (บันทึกไว้ชัดเจนในตอนนั้นว่า "โลโก้/แบนเนอร์ยกไป SELLER-004 Store Management") — ตอนนี้ seller ไม่มีทางแก้ไขข้อมูลร้านของตัวเองเลยแม้แต่ชื่อ/คำอธิบายที่กรอกไปตอนสมัคร ไม่มีทาง upload โลโก้/แบนเนอร์ (ทั้งที่คอลัมน์ `logo_url`/`banner_url` มีอยู่ใน `stores` ตั้งแต่ ZOKY-001) ไม่มีที่อยู่/เบอร์ติดต่อ/เวลาทำการให้ลูกค้าเห็นเลย — ฝั่งลูกค้า `StoreScreen` เองก็ไม่เคยแสดง `banner_url` เลยแม้จะมีคอลัมน์อยู่แล้ว (ไม่มี producer ฝั่งไหนเคย set ค่านี้จริง)

Requirements:

**1. แทนที่ tab "ร้านค้า" (`SellerHomeShell` index 3)**
- เปลี่ยนจาก `const SellerComingSoonScreen(label: 'ร้านค้า')` เป็น `SellerStoreScreen` จริง — tab "การเงิน" (index 4) ยังเป็น placeholder เหมือนเดิมจนกว่า SELLER-005 จะเติม ไม่แตะ tab นั้น

**2. `SellerStoreScreen` — ฟอร์มแก้ไขข้อมูลร้านโดยตรง (ไม่มีโหมด view แยกจาก edit)**
- เป็นฟอร์มเดียวที่ pre-fill ด้วยข้อมูลร้านปัจจุบันเสมอ (ไม่ใช่หน้า view-only ที่ต้องกด "แก้ไข" ก่อน) — มิเรอร์ pattern `EditClubInfoScreen` ตรง ๆ (คนละแอปจึงต้อง duplicate โค้ด แต่ยึดโครง/pattern เดียวกันตามธรรมเนียมของโปรเจกต์นี้)
- ฟิลด์ที่แก้ไขได้ทั้งหมด:
  - **ชื่อร้าน** (บังคับ, 1-100 ตัวอักษร — ตรงกับ constraint เดิม `stores_name_length` ที่มีอยู่แล้ว ไม่เปลี่ยน)
  - **คำอธิบาย** (ไม่บังคับ)
  - **โลโก้** (ไม่บังคับ, รูปเดียว, แสดงเป็น circle picker เหมือน `EditClubInfoScreen`'s icon picker — ถ้ายังไม่มีให้เห็น placeholder icon แทน initials ที่ `StoreScreen` ฝั่งลูกค้าใช้ fallback อยู่แล้ว)
  - **Banner/Cover** (ไม่บังคับ, รูปเดียว, แสดงเป็น 16:9 picker เหมือน `EditClubInfoScreen`'s cover picker — คอลัมน์ `banner_url` มีอยู่แล้วแต่ไม่เคยมีทาง set ค่าได้เลยจนถึงตอนนี้)
  - **ที่อยู่** (ไม่บังคับ, free text หลายบรรทัด — คอลัมน์ใหม่ `address`)
  - **เบอร์ติดต่อ** (ไม่บังคับ, free text — คอลัมน์ใหม่ `contact_phone`; ตั้งใจเป็น free text ไม่ validate รูปแบบเบอร์โทรเข้มงวด เพราะ seller อาจใช้ช่องนี้ใส่ LINE ID หรือช่องทางติดต่ออื่นแทนเบอร์โทรจริงก็ได้ในทางปฏิบัติ — ไม่ implement ช่องทางติดต่อแยกหลายประเภทในรอบนี้)
  - **เวลาทำการ** (ไม่บังคับ, free text — คอลัมน์ใหม่ `business_hours`) — **ตัดสินใจ: free text ฟิลด์เดียว ไม่ทำเป็น structured data ต่อวัน (เช่น 7 แถว วัน+ช่วงเวลาเปิด-ปิด)** เหตุผล: master prompt roadmap summary (Section 16) ไม่ได้ระบุ requirement ที่ต้องพึ่ง structured data จริง (เช่น badge "เปิดอยู่ตอนนี้"/"ปิดแล้ว" บน `StoreScreen` ฝั่งลูกค้า) — ถ้าทำ structured data ตอนนี้จะต้องออกแบบ UI 7 วัน × ช่วงเวลา (multi time-range ต่อวันด้วยซ้ำถ้าจะสมบูรณ์) ซึ่งใหญ่กว่าขอบเขต "Logo/Name/Banner/Description/Address/Contact" ที่ roadmap ระบุไว้มาก ไม่คุ้มค่าใน MVP รอบนี้ — free text ("จันทร์-ศุกร์ 9:00-18:00 น.") ยังให้ประโยชน์เกือบเท่ากันกับลูกค้าที่แค่ต้องการอ่านข้อมูล ไม่ต้องการ badge อัตโนมัติ — ย้ายไป structured field ในอนาคตได้โดยไม่ทำลายข้อมูลเดิม (เพิ่มคอลัมน์ใหม่ ไม่ใช่แปลงคอลัมน์เดิม)
- ทุกฟิลด์ข้อความไม่บังคับ ใช้ pattern `normalizeOptionalText` เดียวกับ SELLER-002 (empty string → null ก่อนบันทึก ไม่เก็บ empty string ปนกับ null)
- ปุ่ม "บันทึก" ปิดใช้งานระหว่างกำลังบันทึกหรือชื่อร้านว่าง เหมือน `EditClubInfoScreen`/`CreateStoreScreen` — error message ที่สื่อความหมายถ้าบันทึกไม่สำเร็จ ไม่ crash

**3. Sync ข้อมูลร้านที่แก้ไขแล้วไปยัง tab อื่นในเซสชันเดียวกัน (ป้องกันข้อมูลเก่าค้าง)**
- `SellerHomeShell` ถือ `Store` เป็น field เดียวส่งต่อให้ทุก tab (`SellerDashboardScreen` ใช้ `widget.store.name` แสดงผลจริง) — ถ้า seller แก้ชื่อร้านใน `SellerStoreScreen` แล้วสลับไป tab Dashboard โดยไม่ปิดแอป ต้องเห็นชื่อใหม่ทันที ไม่ใช่ชื่อเก่าค้างจนกว่าจะ sign-in ใหม่
- **กลไก**: `SellerStoreScreen` รับ callback `onStoreUpdated(Store updated)` (มิเรอร์ pattern `onStoreCreated`/`onUsernameSet` — callback-to-parent-rebuild ที่ใช้ทั่วทั้งโปรเจกต์นี้) — `SellerHomeShell` เปลี่ยนจาก `StatelessWidget`-like การใช้ `widget.store` ตรง ๆ เป็นเก็บ `_store` เป็น mutable state แล้ว `setState` เมื่อ callback ถูกเรียก เพื่อให้ tab list ทั้งหมด rebuild ด้วยค่าล่าสุด (ไม่ต้อง re-fetch จาก server ซ้ำ เพราะ response ของการบันทึกสำเร็จมี row ล่าสุดอยู่แล้ว)

**4. Database — เพิ่มคอลัมน์ใหม่ใน `stores` (ไม่มีคอลัมน์ไหนซ้ำกับที่มีอยู่แล้ว — ตรวจสอบจาก `supabase/schema.sql` แล้ว: `id`/`owner_id`/`name`/`description`/`logo_url`/`banner_url`/`created_at` มีอยู่แล้วทั้งหมด ไม่ต้องเพิ่มซ้ำ)**
- `address text` (nullable), constraint `stores_address_length` (`address is null or char_length(address) <= 300`)
- `contact_phone text` (nullable), constraint `stores_contact_phone_length` (`contact_phone is null or char_length(contact_phone) <= 50`)
- `business_hours text` (nullable), constraint `stores_business_hours_length` (`business_hours is null or char_length(business_hours) <= 200`)
- ใช้ `alter table public.stores add column if not exists ...` เหมือน pattern เดิมของ SELLER-002's `products.is_active`/`products.sku` — เป็นการเปลี่ยนแปลงแบบ additive ล้วน (เพิ่มคอลัมน์ nullable ใหม่) **ไม่ใช่ "โครงสร้างฐานข้อมูลแบบทำลายล้าง"** ตาม RULES.md จึงไม่ต้องขออนุมัติ Founder ก่อน (เหมือนที่ SELLER-001/002 ทำมาแล้ว)

**5. RLS — ยืนยันว่าไม่ต้องเพิ่ม policy ใหม่**
- `stores` update policy ที่มีอยู่แล้วตั้งแต่ SELLER-001 (`using (auth.uid() = owner_id) with check (auth.uid() = owner_id)`) **ไม่ได้ระบุรายคอลัมน์** — เป็น row-level policy ที่ครอบคลุมทุกคอลัมน์ของแถวนั้นโดยอัตโนมัติ (Postgres RLS policy ไม่มีแนวคิด per-column เว้นแต่จะทำ column-level GRANT/REVOKE แยกต่างหาก ซึ่งไม่มีจุดไหนของ `stores` เคยทำ) → คอลัมน์ใหม่ทั้ง 3 (`address`/`contact_phone`/`business_hours`) รวมถึง `logo_url`/`banner_url`/`name`/`description` เดิม **แก้ไขได้ทันทีผ่าน policy เดิมโดยไม่ต้องเพิ่มอะไรเลย** — นี่คือ SELLER task แรกที่ไม่ต้องแก้ RLS ของตารางหลักเลยแม้แต่บรรทัดเดียว (ต่างจาก SELLER-002/003 ที่ต้องเพิ่ม policy ใหม่ทุกครั้ง)
- สิ่งที่ต้องเพิ่มจริงคือ **storage policy ใหม่** สำหรับ bucket โลโก้/แบนเนอร์เท่านั้น (ข้อ 6)

**6. Storage — bucket ใหม่ `store-media`**
- **Public bucket** (เหมือนเหตุผลของ `product-images` ใน SELLER-002: `stores` เป็น select-all-authenticated อยู่แล้ว ไม่มี privacy boundary ให้ต้องทำ signed-URL แบบ `club-media`) — ต่างจาก `club-media` ที่ private เพราะ club มีขอบเขตความเป็นส่วนตัว (approved-members-only) ซึ่ง store ไม่มี
- **1 bucket ใช้ร่วมกันทั้งโลโก้และแบนเนอร์** (มิเรอร์ pattern `club-media`'s "1 bucket ต่อ 2 ชนิดรูป แยกด้วย path prefix" ไม่ใช่แยก 2 bucket) — path convention: `{store_id}/logo-{timestamp}.{ext}` และ `{store_id}/banner-{timestamp}.{ext}` (timestamp กัน CDN/cache เสิร์ฟรูปเก่าซ้ำ เหมือน `product-images`'s `{store_id}/{timestamp}-{n}.*`)
- insert/update/delete storage policy scope ผ่าน `exists` join กลับ `stores.owner_id = auth.uid()` จาก `(storage.foldername(name))[1]` — **pattern เดียวกันเป๊ะกับ `product-images` ใน SELLER-002** (ownership ผ่านร้าน ไม่ใช่ผ่าน uploader id ตรง ๆ เพราะ V1 ยังเป็น 1 seller ต่อ 1 ร้านอยู่แล้ว แต่ยึดหลักการเดียวกับ SELLER-002's comment: "a store's images belong to the *store*, not personally to whichever owner happened to upload them")
- Upload ก่อน update `stores.logo_url`/`banner_url` เสมอ (มิเรอร์ "upload first" ของ `createProduct`/`ClubPostRepository.createPost`)

**7. StoreScreen ฝั่งลูกค้า (`app/lib/features/zoky/presentation/store_screen.dart`) ต้องแสดงข้อมูลใหม่ — เป็นการแก้โค้ดที่ผ่าน QA แล้ว (ZOKY-001) ต้องระมัดระวังเป็นพิเศษ**
- **Banner**: เพิ่มรูป banner (16:9 หรือใกล้เคียง) เหนือ Row(โลโก้+ชื่อร้าน) เดิม เมื่อ `store.bannerUrl != null` — ถ้าเป็น `null` ไม่แสดงพื้นที่ว่างเปล่าแทน (ไม่เปลี่ยน layout เดิมสำหรับร้านที่ไม่มี banner เลย — ร้าน seed เดิมทั้งหมดจาก ZOKY-001 ไม่มี banner จนถึงตอนนี้)
- **ข้อมูลร้านค้า (Address/Contact/Business Hours)**: เพิ่ม section ใหม่ใต้ description เดิม แสดงเฉพาะแถวที่มีค่า (ไม่แสดงแถวว่างของฟิลด์ที่เป็น `null`) — ถ้าทั้ง 3 ฟิลด์เป็น `null` หมด **ไม่แสดง section นี้เลย** (ไม่ใช่ section ว่างเปล่าที่ทำให้ดูเหมือนบั๊ก) — สำคัญเพราะร้านเดิมทั้งหมดที่ QA เคยตรวจผ่านจะไม่มีฟิลด์ใหม่เหล่านี้เลย ต้อง regression-safe 100%
- **ไม่ต้องเพิ่ม realtime subscription** — `StoreScreen` fetch ข้อมูลร้านใหม่ทุกครั้งที่ `initState()` ถูกเรียก (ทุกครั้งที่ push หน้านี้ใหม่) อยู่แล้ว ยืนยันจากโค้ดจริงว่าไม่มี cache ข้าม navigation เลย — การที่ลูกค้าเห็นข้อมูลอัปเดตหลัง seller แก้ไข (ครั้งถัดไปที่เปิดหน้าร้าน) เพียงพอแล้ว ไม่จำเป็นต้องเป็น live update ระหว่างที่ลูกค้าค้างอยู่หน้าเดิม (ไม่มี requirement ไหนต้องการความสดขนาดนั้น ต่างจากตัวเลข Dashboard ของ seller เองที่ต้องคำนวณสดเพราะเป็นข้อมูลธุรกิจที่เปลี่ยนบ่อย)
- แก้ `Store.fromMap` ทั้ง 2 จุด (`app/lib/features/zoky/data/store.dart`, `seller_app/lib/features/store/data/store.dart`) ให้ parse ฟิลด์ใหม่ 3 ตัว — **ไม่ต้องแก้ query ใด ๆ ใน `ZokyRepository`/`SellerRepository`** เพราะทุกจุดที่ query ตาราง `stores` ใช้ `.select()` (wildcard) อยู่แล้ว ไม่ใช่ column list แบบเจาะจง คอลัมน์ใหม่จะไหลผ่านมาเองอัตโนมัติ

Acceptance Criteria:
- [ ] tab "ร้านค้า" แสดง `SellerStoreScreen` จริงแทน placeholder เดิม — tab "การเงิน" ยังเป็น placeholder เหมือนเดิม ไม่ crash
- [ ] `SellerStoreScreen` pre-fill ข้อมูลร้านปัจจุบันครบทุกฟิลด์ (ชื่อ/คำอธิบาย/โลโก้/แบนเนอร์/ที่อยู่/เบอร์ติดต่อ/เวลาทำการ)
- [ ] แก้ไขชื่อร้านให้ว่างเปล่าไม่สามารถบันทึกได้ (ปุ่มบันทึก disabled) — ฟิลด์อื่นทั้งหมดไม่บังคับ
- [ ] อัปโหลดโลโก้/แบนเนอร์ใหม่สำเร็จ → `stores.logo_url`/`banner_url` อัปเดตด้วย public URL ใหม่ (path มี timestamp กัน cache ค้าง)
- [ ] ที่อยู่/เบอร์ติดต่อ/เวลาทำการ บันทึกถูกต้อง, เกินความยาวที่กำหนด (300/50/200 ตัวอักษรตามลำดับ) ถูกปฏิเสธด้วย error ที่สื่อความหมาย ไม่ crash, ค่าว่าง (empty string) ถูก normalize เป็น `null` ก่อนบันทึกเสมอ
- [ ] แก้ไขข้อมูลร้านสำเร็จแล้วสลับไป tab Dashboard (ไม่ปิดแอป) เห็นชื่อร้านใหม่ทันที ไม่ใช่ชื่อเก่าค้าง (ยืนยัน `onStoreUpdated` callback ทำงานถูกต้อง)
- [ ] Seller A (ร้าน X) ไม่สามารถ update ข้อมูลร้าน Y หรืออัปโหลดรูปเข้า path ของร้าน Y ได้เลยแม้พยายามส่ง id/path ตรง ๆ (RLS ของ `stores` ที่มีอยู่แล้ว + storage policy ใหม่ของ `store-media` ต้องปฏิเสธทั้งคู่)
- [ ] ยืนยันด้วยการอ่านโค้ด/policy ว่า **ไม่มีการเพิ่ม RLS policy ใหม่ให้ `stores`** (ใช้ policy update เดิมจาก SELLER-001 ครอบคลุมคอลัมน์ใหม่ทั้งหมดโดยอัตโนมัติ)
- [ ] `store-media` bucket เป็น public, insert/update/delete จำกัดเฉพาะ path ของร้านตัวเอง (ownership ผ่าน `stores.owner_id`)
- [ ] `StoreScreen` ฝั่งลูกค้าแสดง banner เมื่อมีค่า, ไม่แสดงพื้นที่ว่างเมื่อไม่มี banner (regression: ร้านเดิมทั้งหมดที่ไม่มี banner ต้องแสดงผลเหมือนเดิมทุกประการ)
- [ ] `StoreScreen` ฝั่งลูกค้าแสดง section "ข้อมูลร้านค้า" เฉพาะเมื่อมีอย่างน้อย 1 ใน 3 ฟิลด์ (address/contact_phone/business_hours) ไม่เป็น `null` — แสดงเฉพาะแถวที่มีค่าจริง ไม่แสดง section เลยถ้าทั้ง 3 เป็น `null` หมด
- [ ] `StoreScreen`/`fetchStore` ยังคง fetch สดทุกครั้งที่เปิดหน้าใหม่เหมือนเดิม (ไม่มีการเพิ่ม realtime subscription) — ยืนยันว่าเพียงพอตาม requirement
- [ ] SELLER-001/002/003 (auth/dashboard/product/order tabs) และ ZOKY-001/002/003/004 (Home/Search/Product Detail/Cart/Checkout/Order/Review ฝั่งลูกค้า) เดิมทั้งหมดยังทำงานปกติ ไม่มี regression — โดยเฉพาะ `StoreScreen`'s test suite เดิมของ ZOKY-001 ต้องผ่านครบทุกเคสหลังแก้ไฟล์

Dependencies: SELLER-001 (Foundation — Approved, ให้ `SellerHomeShell`/`SellerRepository`/`Store` model/`stores` insert-update RLS ที่ SELLER-004 reuse ตรง ๆ ไม่ต้องแก้), ZOKY-001 (Approved, ให้ `stores` table + `StoreScreen`/`Store` model ฝั่งลูกค้าที่ SELLER-004 ต้องขยาย)

Priority: P1 ของ Phase 4 — งานสุดท้ายก่อน SELLER-005 (Finance) จะปิด Phase 4 ครบทั้ง 5 task ตาม roadmap (SELLER-004 ไม่ผูกกับ SELLER-002/003 เลย ทำเมื่อไหร่ก็ได้ตามที่ roadmap ระบุไว้แต่ต้น แต่ตอนนี้เป็นงานเดียวที่เหลือก่อนถึง SELLER-005)

Risks:
- **แก้โค้ดของ task ที่ผ่าน QA แล้ว 2 จุดฝั่งลูกค้า** (`app/lib/features/zoky/presentation/store_screen.dart`, `app/lib/features/zoky/data/store.dart`) — ต้อง regression-test `StoreScreen`'s test suite เดิมของ ZOKY-001 ครบทุกเคส ไม่ใช่แค่เคสใหม่ (มาตรฐานเดียวกับ SELLER-002's Risks เรื่องแก้ `zoky_repository.dart`/`create_orders()`)
- **Same-session staleness ถ้า `onStoreUpdated` callback ต่อสาย SellerHomeShell ผิด**: ถ้า Coding ลืมทำให้ `SellerHomeShell` เป็น mutable state หรือลืมส่ง `_store` ตัวใหม่ให้ทุก tab ตอน rebuild, Dashboard tab จะยังโชว์ชื่อ/ข้อมูลร้านเก่าค้างจนกว่าจะ sign-out/sign-in ใหม่ — เตือน QA ให้ทดสอบ "แก้ชื่อร้านแล้วสลับ tab โดยไม่ปิดแอป" เป็นเคสเฉพาะ เพราะเป็น interaction pattern ใหม่ที่ SELLER-001/002/003 ไม่เคยมี (tab อื่นไม่เคยแก้ไขข้อมูลที่ tab อื่นแสดงผลมาก่อน)
- **Business hours เป็น free text ไม่ใช่ structured data**: ยอมรับว่าจะทำ "เปิดอยู่ตอนนี้/ปิดแล้ว" แบบอัตโนมัติไม่ได้ในรอบนี้ (ต้องเป็น structured data ถึงจะคำนวณได้) — เป็นการตัดสินใจ scope ของ Product ตามเหตุผลที่ระบุไว้ในข้อ 2 ของ Requirements ไม่ใช่ oversight สามารถ migrate เป็น structured field ในอนาคตได้โดยไม่ทำลายข้อมูล free text เดิม (เพิ่มคอลัมน์ใหม่ ไม่แปลงคอลัมน์เดิม)
- **`contact_phone` ไม่ validate รูปแบบเบอร์โทร**: seller อาจใส่ข้อมูลที่ไม่ใช่เบอร์โทรจริง (LINE ID ฯลฯ) — ยอมรับความเสี่ยงนี้เพื่อความยืดหยุ่น ตามที่ระบุไว้ในข้อ 2
- **ไม่มีการจำกัดขนาดไฟล์รูปที่ storage-policy level** สำหรับ `store-media` (เหมือน `product-images`/`avatars`/`club-media` เดิมทั้งหมดที่ไม่เคยบังคับที่ชั้นนี้เช่นกัน) — เป็นความเสี่ยงระดับ pattern เดิมของทั้งโปรเจกต์ ไม่ใช่สิ่งใหม่ที่ SELLER-004 สร้างขึ้น พึ่ง `ImagePicker`'s `maxWidth`/`maxHeight`/`imageQuality` ที่ชั้น client เหมือนเดิม

Recommendation:
1. เริ่ม Design ทันทีหลังจาก Product spec นี้ — reuse `EditClubInfoScreen`'s banner(16:9)+icon(circle) picker pattern เกือบทั้งหมด (โครงเดียวกันเป๊ะ เปลี่ยนแค่ label/ฟิลด์เพิ่มเติม) เพื่อไม่ต้องประดิษฐ์ visual language ใหม่
2. นี่คือ SELLER task แรกที่ **ไม่ต้องแก้ RLS ของตารางหลักเลย** (แค่เพิ่มคอลัมน์ nullable 3 ตัว + storage policy ใหม่ 1 ชุด) — ความเสี่ยง DB-level ต่ำกว่า SELLER-002/003 มาก แต่ความเสี่ยง cross-app UI (staleness ระหว่าง tab, regression ของ `StoreScreen` ฝั่งลูกค้า) สูงกว่าปกติ ให้ QA เน้นสองจุดนี้เป็นพิเศษแทน
3. Coding ต้อง sync branch ใหม่ก่อนแก้ `store_screen.dart`/`store.dart` (`app/`) และรัน regression suite เดิมของ ZOKY-001 อิสระให้ครบก่อนส่ง QA เหมือนมาตรฐานเดิมทุก task ที่แก้โค้ดข้ามแอป

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) `SellerStoreScreen` (banner/logo picker + ฟอร์ม 7 ฟิลด์ + ปุ่มบันทึก) มิเรอร์ `EditClubInfoScreen` (2) การต่อสาย `onStoreUpdated` callback ให้ `SellerHomeShell` rebuild tab อื่นถูกต้อง (3) ส่วนที่เพิ่มใน `StoreScreen` ฝั่งลูกค้า (banner header + section "ข้อมูลร้านค้า" แบบ conditional-render ต่อฟิลด์) — ใช้ Design system เดิมทั้งสองแอป (Blue+White+Soft Gray, seed `0xFF2D6CDF`, Material 3, ห้าม Liquid Glass) เมื่อ Design/Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น %

## Design Output

Status: **Design เสร็จแล้ว** — เขียนที่ `.wyn/docs/design/seller-004-store-management.md`

สรุปการตัดสินใจหลัก:
1. **`SellerStoreScreen` ใหม่**: มิเรอร์ `EditClubInfoScreen._buildCoverPicker()`/`._buildIconPicker()` เป๊ะ (banner 16:9 + logo circle picker, placeholder icon เดียวกัน) + ฟอร์ม 7 ฟิลด์ (ชื่อ/คำอธิบาย/ที่อยู่/เบอร์ติดต่อ/เวลาทำการ + รูป 2 ชนิด) — `maxLength` ของแต่ละ `TextField` ตรงกับ DB CHECK constraint ที่ Product spec กำหนด (100/300/50/200) — ปุ่ม "บันทึก" disable เมื่อชื่อร้านว่างหรือกำลังบันทึกเท่านั้น (ฟิลด์อื่นไม่บังคับ)
2. **จุดต่างสำคัญจาก `EditClubInfoScreen`**: `SellerStoreScreen` เป็น tab body ใน `IndexedStack` ไม่ใช่ pushed route → **ห้าม `Navigator.pop()` หลังบันทึกสำเร็จ** ใช้ `SnackBar` แจ้งผลแทนแล้วอยู่หน้าเดิมต่อ
3. **`SellerRepository.updateStoreInfo` เป็น 1 เมธอดรวม** (upload รูปที่เปลี่ยนก่อน แล้ว update ทุกฟิลด์ครั้งเดียว) แทนที่จะแยก 3 เมธอดแบบ `ClubRepository` — เพราะ `store-media` เป็น public bucket (เหมือน `product-images`) ได้ URL ทันทีจาก `getPublicUrl()` ไม่ต้อง round-trip fetch signed URL แบบ `club-media` ที่ private
4. **`SellerHomeShell` เปลี่ยนเป็น mutable `_store` state**: เพิ่ม `late Store _store = widget.store;`, ทุก tab (Dashboard/Product/Order/Store) อ้าง `_store` ไม่ใช่ `widget.store`, `SellerStoreScreen`'s `onStoreUpdated` callback → `setState(() => _store = updated)` — มิเรอร์ pattern `onStoreCreated`/`onUsernameSet` เดิม (callback-to-parent-rebuild)
5. **`StoreScreen` ฝั่งลูกค้า แก้ 2 จุดแทรกเท่านั้น**: (ก) banner edge-to-edge เหนือ `_buildHeader` เดิม ใช้ `if` ใน children list (ไม่ใช่ `SizedBox.shrink()`) เพื่อไม่กิน element tree เปล่า ๆ เมื่อไม่มี banner (ข) "ข้อมูลร้านค้า" section (`Card` + icon+text row ต่อฟิลด์) แทรกหลัง description เดิม ก่อนปุ่ม "ติดตามร้าน" — render เฉพาะเมื่อมีอย่างน้อย 1 ใน 3 ฟิลด์ไม่ null — **ไม่แตะ** `_buildProductsTab`/`_buildReviewsTab`/`TabBar`/AppBar เพื่อลดความเสี่ยง regression ของ ZOKY-001's test suite เดิม
6. **ไม่ใช้ pattern Stack+Positioned overlap ของ `club_page.dart`'s cover** สำหรับ banner ฝั่งลูกค้า — เลือก layout เรียบง่ายกว่า (banner ธรรมดาเหนือ header เดิม ไม่ overlap) ตรงตาม Product spec ที่ระบุ "เหนือ Row(โลโก้+ชื่อร้าน) เดิม" และลด diff ให้เล็กที่สุด
7. Data model: เพิ่ม `address`/`contactPhone`/`businessHours` (`String?`) เข้า `Store`/`Store.fromMap` ทั้ง 2 ไฟล์ (`app/`, `seller_app/`) — ไม่กระทบ constructor signature อื่น

Handoff: ส่งต่อ AI Coding (`/code`) — รายละเอียดครบทุก Screen/Widget/Data Model/Repository method ที่ต้อง implement อยู่ใน `.wyn/docs/design/seller-004-store-management.md` ทั้งหมด (รวม "เตือน Coding" 6 ข้อท้ายเอกสารที่ย้ำจุดเสี่ยงจาก Product spec's Risks ที่กระทบ UI/UX โดยตรง — โดยเฉพาะ `onStoreUpdated` wiring และ banner conditional-render)

## QA Output (รอบ 1 — 2026-08-15)

Status: **FAIL** — ส่งต่อ AI Debug Engineer พร้อม bug report ที่ `.wyn/tasks/bugs/SELLER-004-store-screen-header-overflow.md` (ยังไม่ย้ายเข้า `.wyn/tasks/approved/`)

```
Feature: SELLER-004 (Store Management) — SellerStoreScreen ใหม่ + SellerRepository.updateStoreInfo + SellerHomeShell mutable _store (cross-tab sync) + stores.address/contact_phone/business_hours + storage bucket store-media + StoreScreen ฝั่งลูกค้า (banner + section "ข้อมูลร้านค้า")
Environment: Static/code-level review + `flutter test`/`flutter analyze` จริงบน Flutter 3.47.0 ทั้ง `app/` และ `seller_app/` + widget test ที่ QA เขียนขึ้นเองเพื่อวัด layout บนขนาดจอมือถือจริง (ไม่มี live Supabase project ให้ทดสอบ dynamic เหมือนทุก task ก่อนหน้า) — sync branch `claude/pwd-nxsvf5` กับ `origin/main` (91c1a44, PR #110) ก่อนเริ่ม ยืนยัน HEAD == origin/main == merge-base
Test Cases:
  1. onStoreUpdated cross-tab sync — อ่าน `seller_home_shell.dart` ยืนยัน `late Store _store = widget.store` + ทุก tab (Dashboard/Product/Order/Store) อ้าง `_store` ครบ 4 จุด + grep `widget.store` ทั้ง lib ยืนยันไม่มีจุดค้าง + รัน test flow จริง (แก้ชื่อร้าน → สลับไป Dashboard เห็นชื่อใหม่ทันที)
  2. RLS ของ stores — ยืนยัน update policy เดิมจาก SELLER-001 เป็น row-level ไม่มี column scoping + SELLER-004 ไม่เพิ่ม/แก้ policy ของ stores เลยแม้แต่บรรทัดเดียว
  3. storage bucket store-media — public + insert/update/delete join กลับ stores.owner_id ผ่าน (storage.foldername(name))[1] เทียบ product-images ทีละบรรทัด + attack scenario seller A เขียน path ของร้าน B
  4. StoreScreen ฝั่งลูกค้า (โค้ดที่ผ่าน QA แล้วจาก ZOKY-001) — อ่าน diff ยืนยัน banner ใช้ `if` ใน children list จริง + section แสดงเฉพาะเมื่อมี >= 1 field + แต่ละแถว conditional ตาม field ตัวเอง + regression suite เดิมครบ
  5. Known Issue overflow ที่ Coding แจ้งไว้ — วัดจริงด้วย widget test บน 360x640 / 375x667 / 390x844 / 430x932 / แนวนอน / textScaler 1.3
  6. SellerStoreScreen ฟอร์ม — maxLength เทียบ DB CHECK constraint ทีละฟิลด์, ชื่อร้านว่าง/เว้นวรรคล้วน, ไม่ pop หลังบันทึก, error path, double-tap, paste เกิน maxLength
  7. ไล่ Requirements 7 ข้อ / Design Components / Acceptance Criteria 12 ข้อ แยกกันทีละบรรทัดเทียบโค้ดจริง
  8. Regression เต็ม: `python3 supabase/check_schema_ordering.py` + `seller_app/` 67 test + `app/` 265 test + `flutter analyze` ทั้งคู่ หลัง sync main ใหม่
Passed: 7/8 หัวข้อ, `seller_app/` flutter test 67/67, `app/` flutter test 265/265, `flutter analyze` สะอาดทั้งคู่, check_schema_ordering.py OK
Failed: 1 (หัวข้อ 5 — StoreScreen header overflow บนมือถือจริง)
Severity: **Major (blocking)**
Reproduction Steps: เปิด StoreScreen ของร้านที่มี banner + ที่อยู่/เบอร์/เวลาทำการ ครบ บนจอ 360x640 หรือ 375x667 (หรือจอใหญ่กว่าที่ผู้ใช้ตั้ง font scale 1.3) — รายละเอียดการวัดครบทุกขนาดจออยู่ใน bug report
Expected: ลูกค้ายังเห็นและเลื่อนดูรายการสินค้า/รีวิวของร้านได้ตามปกติ ไม่มี render overflow
Actual: RenderFlex overflow 50-169 px (สูงสุด 366 px เมื่อที่อยู่ยาวแต่ยังไม่เกินเพดาน DB), `Expanded(TabBarView)` ถูกบีบเหลือความสูง 0.0 → แท็บ "สินค้าทั้งหมด"/"รีวิว" ไม่แสดงเนื้อหาเลย (ProductGridTile count = 0) — ลูกค้ามองไม่เห็นสินค้าและกดซื้อไม่ได้ ขณะที่ร้านที่ไม่มีฟิลด์ใหม่ (baseline ก่อน SELLER-004) ไม่ overflow ในทุกขนาดจอที่ทดสอบ
Security Findings:
  - ไม่พบช่องโหว่ใหม่ — RLS ของ stores ไม่ถูกแตะจริง (row-level policy ครอบคลุมคอลัมน์ใหม่อัตโนมัติตามที่ Product spec ระบุ), storage policy ของ store-media เหมือน product-images ทุกบรรทัด (ownership ผ่าน stores.owner_id ไม่ใช่ uploader id) — seller A อัปโหลด/แก้/ลบไฟล์ใน path ของร้าน B ไม่ได้
  - `updateStoreInfo` ใช้ `.eq('id', storeId)` ล้วนโดยไม่มี owner filter — พึ่ง RLS เป็น security boundary ตรงตาม pattern ที่ทั้งโปรเจกต์ใช้อยู่ (ถ้า storeId ถูก tamper ฝั่ง client จะ update ไม่โดนแถวไหนเลยแล้ว `.single()` โยน error → UI แสดงข้อความ error ปกติ ไม่ crash)
  - ไม่มี secret/token/credential หลุดใน diff (สแกนแล้ว), ไม่มีการ log ข้อมูลผู้ใช้
  - `((storage.foldername(name))[1])::uuid` โยน error เมื่อ path แรกไม่ใช่ UUID → ปฏิเสธการเขียน ไม่ใช่ช่องทาง bypass (pattern เดิมจาก product-images ตั้งแต่ SELLER-002)
Recommendation: ส่ง `.wyn/tasks/bugs/SELLER-004-store-screen-header-overflow.md` ให้ AI Debug Engineer แก้ (ต้องให้ AI Design ยืนยันแนวทาง layout ก่อน เพราะ Design spec เดิมจำกัดขอบเขตไว้ที่ "แทรก 2 จุด ห้ามแตะ TabBar/AppBar" ซึ่งไม่ครอบคลุมกรณีนี้) — ส่วนอื่นของ SELLER-004 (seller_app ทั้งหมด, schema, storage policy, cross-tab sync) ผ่านครบไม่ต้องแก้
Final Status: FAIL
```

ข้อสังเกต Minor ที่ไม่ block (บันทึกไว้ให้รอบถัดไป ไม่ต้องแก้ตอนนี้):
1. `SellerStoreScreen` ไม่ล้าง `_logoBytes`/`_bannerBytes` หลังบันทึกสำเร็จ — ถ้า seller กดบันทึกซ้ำอีกครั้งโดยไม่เลือกรูปใหม่ ระบบจะอัปโหลดรูปเดิมซ้ำเป็นไฟล์ใหม่ (ไฟล์เก่ากลายเป็น orphan ใน bucket, สิ้นเปลืองพื้นที่แต่ไม่กระทบความถูกต้องของข้อมูลหรือความปลอดภัย)
2. ไม่มีทาง "ลบ" โลโก้/แบนเนอร์ออกได้หลังตั้งค่าแล้ว (มีแต่เปลี่ยนเป็นรูปใหม่) — ไม่มี AC ข้อไหนกำหนดไว้
3. `alter table ... add constraint` ทั้ง 3 ตัวไม่มี guard `if not exists` (Postgres ไม่รองรับ syntax นี้ตรง ๆ) → รัน `schema.sql` ซ้ำรอบสองจะ error — เป็น pattern เดิมของทั้งไฟล์ตั้งแต่ WYN-003 (`profiles_display_name_length`/`profiles_bio_length`) ไม่ใช่สิ่งที่ SELLER-004 สร้างขึ้นใหม่ แต่ควรมี ADR ตัดสินเรื่อง idempotency ของ schema.sql รวมทีเดียวในอนาคต

---

## QA & Security Report — รอบ 2 (AI QA & Security, 2026-08-15)

**ผลสรุป: PASS**

### Sync และ environment

`git fetch origin` แล้วยืนยัน `claude/pwd-nxsvf5` == `origin/main` == merge-base ที่ `f7035c8` (PR #112, Debug fix) อยู่แล้วตั้งแต่ต้น ไม่ต้อง rebase — Flutter 3.47.0 ผ่าน `flutter --version`

### (1) Re-run device-size matrix เดิมด้วยตัวเอง — ไม่เชื่อตัวเลขจาก Debug Output

เขียน widget test ชุดใหม่ทั้งหมดเองอิสระ (`app/test/qa_seller004_round2_verification_test.dart`, ลบทิ้งหลังยืนยันผลแล้วตามธรรมเนียมเดิมของ QA ในโปรเจกต์นี้ที่ไม่ commit ไฟล์ test ของตัวเอง — regression coverage ถาวรเป็นหน้าที่ของ Debug/Coding) ด้วย fixture คนละชุดกับทั้ง QA รอบ 1 และ Debug Output (ที่อยู่/ชื่อร้าน/คำอธิบายต่างกันหมด) ครอบคลุม 360x640, 375x667, 390x844+textScaler 1.3, 430x932+textScaler 1.3, ที่อยู่ยาว 265 ตัวอักษรไม่มี banner, แนวนอน 667x375 — ดัก `FlutterError.onError` เก็บ error **ทุกตัว** เองตามที่ Founder กำชับ (ไม่ใช้ `tester.takeException()` เลยสักจุดเดียวในทุกเทสต์ที่วัด overflow)

ผลวัดจริงของ QA เอง: **ทุกเคสไม่มี overflow, `TabBarView` สูง > 0 และ >= ครึ่งจอเสมอ, `ProductGridTile` ถูก layout จริงและมีความสูง > 0 ทุกตัว** — ตรงกับตัวเลขที่ Debug รายงานในเชิงคุณภาพ (ตัวเลข px แตกต่างกันเล็กน้อยเพราะ fixture คนละชุด ตามคาด)

### (2) SliverOverlapAbsorber/Injector — พิสูจน์อิสระว่าสินค้าแถวแรกกดได้จริง ไม่ถูก TabBar บัง

เขียน 2 เทสต์แยกเจาะจงจุดนี้:
- viewport สูงพอ (390x1400) ให้ header+TabBar+แถวสินค้าแรกพอดีในจอเดียวโดยไม่ scroll เลย → แตะ `ProductGridTile` แถวแรกทันที → เปิด `ProductDetailScreen` สำเร็จ (ไม่ใช่ tap ไปโดน TabBar ที่ pinned)
- viewport เล็ก (360x640) ที่ต้อง scroll ก่อนถึงจะเห็นเนื้อหาแท็บ → scroll แล้วแตะแถวสินค้าแรกที่อยู่ติดขอบล่างของ TabBar ที่ pinned ทันที → เปิด `ProductDetailScreen` สำเร็จเช่นกัน

ทั้งสองเทสต์ผ่าน ยืนยันว่า `SliverOverlapAbsorber`/`SliverOverlapInjector` ทำงานถูกต้องจริง ไม่ใช่แค่เชื่อคำอธิบายของ Debug — (หมายเหตุ: ที่ 390x844 พอดี ด้วย fixture ของ QA เอง (description ยาวกว่า Debug's เล็กน้อย) TabBarView เหลือแค่ ~104px แถวแรกโผล่มาแค่ ~29px ต้อง scroll เพิ่มอีกนิด — เป็นพฤติกรรมปกติของหน้าที่ scroll ได้ ไม่ใช่บั๊ก จึงขยับไปทดสอบที่ viewport สูงกว่าสำหรับเคส "zero scroll" โดยเฉพาะ)

### (3) Regression พฤติกรรมเดิมของ StoreScreen (ผ่าน QA จาก ZOKY-001 มาก่อน)

ทดสอบอิสระครบทุกจุดที่ Founder ระบุ: Share/Copy Link ปุ่ม (ยังอยู่), follow store button (SnackBar "ฟีเจอร์นี้จะมาเร็ว ๆ นี้" ทำงานถูกต้อง — พบว่าต้อง `ensureVisible` ก่อนแตะเมื่อร้านมี banner+ข้อมูลครบ เพราะหน้าเป็น scrollable แล้วตามการออกแบบใหม่ที่ตั้งใจ ไม่ใช่บั๊ก), rating header (แสดงค่าเฉลี่ยถูกต้อง), ไม่มีปุ่ม Chat, ร้านที่ไม่มี banner/ข้อมูลเพิ่มเติม render เหมือนก่อน SELLER-004 ทุกประการ (ไม่มี `AspectRatio` 16:9, ไม่มี icon ของ section ข้อมูลร้าน), ร้านไม่พบยังแสดงข้อความ "ไม่พบร้านค้านี้" ปกติ — ผ่านทุกเคส

**เปลี่ยนแท็บ Products↔Reviews แล้วกลับมา — ตรวจ PageStorageKey ตามที่ Founder สั่งเจาะจง**: เขียนเทสต์วัด `ScrollPosition.pixels` ของ Products tab ตรง ๆ ก่อน/หลังสลับแท็บ พบว่า **scroll position รีเซ็ตเป็น 0 หลังสลับกลับมา แม้จะมี `PageStorageKey` แล้วก็ตาม** — ตรวจสอบเพิ่มเติมด้วยการ checkout โค้ด `store_screen.dart` เวอร์ชันก่อน SELLER-004 ทั้งหมด (`git show 2ab800c:...`, ตอนยังใช้ `GridView.builder`/`ListView.builder` ไม่มี `PageStorageKey` เลย) มาทดสอบซ้ำด้วยเทสต์เดียวกัน (ปรับ finder เป็น `GridView`): **พฤติกรรมเดิมก็รีเซ็ตเป็น 0 เหมือนกันทุกประการ** — ยืนยันว่า**ไม่ใช่ regression ที่ SELLER-004 สร้างขึ้น** เป็นพฤติกรรมเดิมของ `TabBarView` ที่ไม่เคยรักษา scroll position ข้ามแท็บมาตั้งแต่ ZOKY-001 (`PageStorageKey` ที่เพิ่มมาไม่ได้แก้ปัญหานี้จริงในบริบทนี้ แต่ก็ไม่ได้ทำให้แย่ลงกว่าเดิม) — บันทึกไว้เป็นข้อสังเกต ไม่ block เพราะไม่ใช่ regression และไม่มี AC ข้อไหนกำหนดพฤติกรรมนี้ไว้ชัดเจน

### (4) Minor fix เรื่อง image bytes ไม่ถูกล้างหลังบันทึกสำเร็จ

ยืนยันด้วยการอ่านโค้ด `seller_store_screen.dart`'s `_save()`: หลัง `onStoreUpdated(updated)` เรียกสำเร็จ มี `setState(() { _logoBytes = null; _logoExtension = null; _bannerBytes = null; _bannerExtension = null; })` ทันที (บรรทัด 149-154) — ตรวจ `SellerRepository.updateStoreInfo` ยืนยันว่า `uploadBinary` ถูกเรียก **เฉพาะเมื่อ** `newLogoBytes != null && newLogoExtension != null` (เช่นเดียวกับ banner) เท่านั้น ดังนั้นการบันทึกครั้งที่สองโดยไม่เลือกรูปใหม่ (bytes เป็น `null` แล้วจากการ reset) จะไม่เรียก `uploadBinary` เลยทั้งคู่ — ปิด orphan-file bug ตามที่ตั้งใจ ยืนยันด้วย logic-trace ที่ชัดเจนสมบูรณ์

**ข้อจำกัดการทดสอบแบบ dynamic เต็มรูปแบบ**: ไม่สามารถจำลอง flow "เลือกรูปใหม่ → บันทึก → บันทึกซ้ำ" ผ่าน widget test ได้จริง เพราะ `image_picker` ใช้ platform channel ที่ sandbox นี้ไม่เคย mock ไว้เลยทั้งโปรเจกต์ (ยืนยันด้วย `grep` ไม่พบ mock ของ `ImagePicker`/`image_picker` ที่ไหนในทั้งสองแอป) ตรงกับ comment ที่มีอยู่แล้วในไฟล์เทสต์เดิม ("ImagePicker goes through a platform channel this sandbox never mocks, same convention as every other picker in this project") — เป็นข้อจำกัดของ infra การทดสอบที่มีมาก่อน SELLER-004 ไม่ใช่ gap ที่ SELLER-004 สร้างขึ้น ตรวจแทนด้วย static code review ที่ชัดเจนสมบูรณ์ตามข้างต้น

### (5) ไล่ Requirements/Design Components/Acceptance Criteria ทั้งหมดใหม่ทีละบรรทัด

- Requirements ทั้ง 7 ข้อ (tab replacement, ฟอร์ม 7 ฟิลด์, cross-tab sync, DB 3 คอลัมน์ใหม่, RLS ไม่แก้, storage bucket `store-media`, StoreScreen ฝั่งลูกค้า) — ตรงกับโค้ดจริงทุกข้อ ตรวจ schema.sql บรรทัดต่อบรรทัดยืนยัน `stores_address_length`/`stores_contact_phone_length`/`stores_business_hours_length` ตรงกับ 300/50/200 เป๊ะ, storage policy 4 ตัว (select/insert/update/delete) เทียบ `product-images` ทีละบรรทัดตรงกันหมด
- Design Components ทุกจุด (banner/logo picker มิเรอร์ `EditClubInfoScreen`, ฟอร์ม 7 ฟิลด์+maxLength, ไม่ `Navigator.pop()`, `onStoreUpdated` callback, banner conditional-render ด้วย `if` ไม่ใช่ `SizedBox.shrink()`) — ตรงกับโค้ดทุกจุด
- Acceptance Criteria ทั้ง 12 ข้อ — ผ่านครบทุกข้อ รวมข้อที่เคย FAIL ตอนรอบ 1 (banner/section render โดยไม่ทำให้ tab content หายไป) ยืนยันแล้วว่าผ่านสมบูรณ์
- Cross-tab sync (`SellerHomeShell._store` mutable state, ทุก tab อ้าง `_store` ไม่ใช่ `widget.store`) — grep ยืนยันไม่มีจุดค้าง `widget.store` เหลืออยู่เลยแม้แต่จุดเดียว

### (6) Schema ordering

`python3 supabase/check_schema_ordering.py` → `OK: no forward references found` — ยืนยันว่า branch sync ถูกต้อง ไม่มีอะไรหลุดมาจาก SCHEMA-001

### (7) Full test suites อิสระ (หลัง sync main ใหม่)

- `app/`: **291/291 ผ่าน** (276 เดิม + 15 เทสต์ QA เขียนเอง, ลบออกก่อน commit ตามธรรมเนียม) — `flutter analyze` สะอาด
- `seller_app/`: **67/67 ผ่าน** — `flutter analyze` สะอาด
- ตรงกับตัวเลขที่ Debug รายงาน (276/67) หลังหักเทสต์ชั่วคราวของ QA ออก

### New finding (ไม่ block SELLER-004 — pre-existing bug นอกขอบเขต)

พบบั๊กใหม่ระหว่างทดสอบ device matrix อิสระ: **`_buildHeader`'s rating `Row` (บรรทัด ~286 ของ `store_screen.dart`) overflow จริงบนทุกขนาดจอมือถือมาตรฐาน (165-235px) สำหรับร้านที่มีรีวิวอย่างน้อย 1 รีวิว** — ยืนยันด้วย `git log`/`git show 135af7a` ว่าโค้ดจุดนี้ไม่เคยถูกแก้ตั้งแต่ ZOKY-004 เลย **SELLER-004 ไม่ได้แตะโค้ดจุดนี้เลยแม้แต่บรรทัดเดียว** ไม่เคยถูกจับได้มาก่อนเพราะทุกเทสต์เดิมที่ store มีรีวิวรันที่ viewport เริ่มต้น 800x600 ของ `flutter_test` (กว้างพอที่ overflow จะไม่เกิด) — บันทึกเป็น bug report แยกที่ `.wyn/tasks/bugs/ZOKY-004-store-header-rating-row-overflow.md` เพื่อส่งต่อ Debug ในรอบถัดไป **ไม่ block การอนุมัติ SELLER-004 รอบนี้** เพราะเป็นโค้ดที่มีมาก่อน SELLER-004 สองงาน (ZOKY-004) ไม่อยู่ใน Requirements/AC ของ SELLER-004 เลย และ SELLER-004's BUG-1 fix ที่กำลังตรวจสอบรอบนี้พิสูจน์แล้วว่าทำงานถูกต้องสมบูรณ์แยกต่างหาก

### Final Status: PASS

อนุมัติเข้า `.wyn/tasks/approved/` — SELLER-004 (Store Management) ปิดจบสมบูรณ์ในรอบ QA ที่ 2 (1 FAIL จาก header overflow เดิม, 1 PASS หลัง Debug แก้ด้วย `NestedScrollView`+`SliverPersistentHeader`+`SliverOverlapAbsorber`/`Injector`) — Phase 4 (ZOKY Sellers by WYN) เหลือแค่ SELLER-005 (Finance) เป็น task สุดท้าย
