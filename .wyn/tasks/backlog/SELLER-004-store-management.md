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
