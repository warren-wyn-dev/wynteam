# Product Task — ZOKY-001

Status: backlog
Owner: AI Product Manager

Feature: ZOKY Marketplace Foundation — ZOKY Bottom Nav tab, ZOKY Home (browse), Product Detail (view), Store page (view)

Goal: เปิดทางให้ผู้ใช้ WYN เข้าสู่ ZOKY Marketplace ได้จาก Bottom Navigation เดิม แล้วเรียกดูสินค้า/ร้านค้าได้จริง (Browse-only รอบนี้ — ยังไม่มี Cart/Checkout/Order ทำงานจริง ผูกกับ ZOKY-003) เป็นรากฐานให้ ZOKY-002 (Search), ZOKY-003 (Cart/Checkout/Order), ZOKY-004 (Review) ต่อยอดได้

Target User: ผู้ใช้ WYN Social เดิมที่อยากซื้อสินค้าผ่านแอปเดียวกันโดยไม่ต้องออกจากแอป — ตาม Founder's WYN PLATFORM master prompt (2026-08-14) ที่ขยาย WYN จาก Social app เดียวเป็น WYN Platform (ดู `.wyn/docs/product/zoky-platform-roadmap.md`)

Problem: WYN ตอนนี้เป็น Social app ล้วน (Home/Drop/Pop/Club/Profile/Search/Notification) ไม่มีทางซื้อ-ขายสินค้าในระบบเลย Founder ต้องการเพิ่ม ZOKY Marketplace เป็นส่วนที่สองของ WYN Platform โดยไม่แตะ/ทำลายฟีเจอร์ Social เดิมแม้แต่จุดเดียว

Requirements:

**Navigation**
- เพิ่ม Bottom Navigation tab ที่ 5 ชื่อ "ZOKY" ต่อจาก Home/Drop/Pop/Profile เดิมใน `RootShell` — **ห้ามเปลี่ยนลำดับ/ลบ/ย้าย tab เดิมทั้ง 4 อัน** (ตรงตามกฎ "ห้ามเปลี่ยน Navigation เดิมโดยไม่จำเป็น" ของ Founder)

**ZOKY Home**
- หน้า Marketplace Home ใหม่ (`ZokyHomeScreen`) ประกอบด้วย: Search Bar (placeholder รอบนี้ — ของจริงผูกกับ ZOKY-002 เหมือนที่ Home Search bar ของ WYN Social เป็น placeholder จนกว่าจะถึง WYN-009), ปุ่ม Cart (placeholder — เชื่อมจริงที่ ZOKY-003), ปุ่ม Orders (placeholder — เชื่อมจริงที่ ZOKY-003), Product Categories (แถว chip/grid หมวดหมู่), Banner/Promotions (placeholder เนื้อหาคงที่ — ไม่มีระบบจัดการ Banner จริงจนกว่าจะถึง WYN Admin), Recommended Products, Best Selling Products, New Products (3 section รายการสินค้า), Recommended Stores, Product Grid หลัก
- **"Recommended"/"Best Selling" รอบแรกนี้**: เหมือนที่ "แนะนำสำหรับคุณ" ของ Explore Clubs (WYN-015) ถูก defer เพราะไม่มี behavioral signal — Best Selling เรียงตามยอดขายจริงได้ (มี Order data ให้นับ) แต่ Order ยังไม่มีในระบบจนกว่า ZOKY-003 จะเสร็จ ดังนั้นรอบนี้ **Best Selling/Recommended จะว่างเปล่าหรือใช้ placeholder data ชั่วคราว** จนกว่าจะมี Order จริง — New Products ทำได้จริงทันที (เรียงตาม `created_at`)

**Product Detail**
- หน้า `ProductDetailScreen` แสดง: Product Images (carousel, มิเรอร์ pattern รูปหลายรูปของ `ClubPostCard` จาก WYN-014), Product Name, Price, Original Price + Discount (ถ้ามี), Stock, Product Variants (Color/Size — เลือกได้แต่ยังไม่ผูกกับ Cart จริงรอบนี้), Description, Rating, Reviews (แสดงถ้ามี — ระบบ Review จริงมาที่ ZOKY-004), Store Information (การ์ดสรุปร้านค้า แตะไป Store page)
- ปุ่ม "Add to Cart"/"Buy Now" **แสดงผลตาม Design แต่ยังไม่ทำงานจริงรอบนี้** (disabled หรือ SnackBar "เร็ว ๆ นี้" — มิเรอร์ pattern placeholder ของ Search bar ใน WYN-007 ตอนที่ WYN-009 ยังไม่เสร็จ) ผูกจริงที่ ZOKY-003

**Store**
- หน้า `StoreScreen` แสดง: Store Logo, Store Name, Store Rating, Followers count (placeholder ตัวเลข — ระบบ Follow Store จริงเป็น open question ที่ Design ต้องตัดสินใจ ดู Risks), Product Count, Store Description, Products (grid), Best Sellers, Reviews
- ปุ่ม "Follow Store" **แสดงผลตาม Design แต่ยังไม่ทำงานจริงรอบนี้** (ดู Risks — ต้องออกแบบ data model ใหม่ก่อน)
- ปุ่ม "Chat Seller" **defer ทั้งหมดรอบนี้** — ไม่มีระบบ chat ในโปรเจกต์นี้เลย เป็นงานคนละขนาด (ดู Risks) ซ่อนปุ่มนี้ไปเลยรอบนี้ไม่ต้องแสดงเป็น placeholder ก็ได้ (ต่างจาก Add to Cart/Follow Store ที่ยังต้องโชว์ตำแหน่งไว้ตาม Design เพราะจะผูกจริงในรอบถัดไปที่ใกล้กว่า)

**Backend (Supabase)**
- ตารางใหม่เข้า `supabase/schema.sql` เดิม (ไม่แยก database): `categories` (id, name, ตายตัวคล้าย `clubCategories` แต่เป็น commerce category), `stores` (id, owner_id → profiles, name, description, logo_url, banner_url, created_at — **ยังไม่มี Seller approval workflow รอบนี้** เพราะ ZOKY Sellers by WYN คือ Phase 4 ที่ยังไม่เริ่ม ดู Risks), `products` (id, store_id, category_id, name, description, price, original_price nullable, stock, image_urls, created_at), `product_variants` (id, product_id, variant_type ('color'/'size'/...), variant_value, price_delta nullable, stock)
- RLS: อ่านได้ทุกคน (authenticated) เหมือน `clubs`/`drops`/`pops` (select-all-authenticated) เพราะเป็นเนื้อหาสาธารณะของ Marketplace ไม่ใช่เนื้อหาส่วนตัว — เขียน (insert/update/delete) **ยังไม่เปิดให้ client รอบนี้เลย** เพราะยังไม่มี Seller app/workflow ตัดสินใจสิทธิ์ให้ครบ (ดู Risks) — ใส่ seed/mock data ผ่าน migration หรือ Supabase Studio ตรง ๆ ระหว่างพัฒนา ไม่ใช่ผ่าน client insert

Acceptance Criteria:
- [ ] เปิดแอป → เห็น Bottom Nav 5 tab (Home/Drop/Pop/ZOKY/Profile) เรียงลำดับถูกต้อง ตำแหน่ง/พฤติกรรม 4 tab เดิมไม่เปลี่ยน
- [ ] แตะ ZOKY tab → เข้าหน้า ZOKY Home เห็น Categories/Banner-placeholder/Product sections/Product Grid ถูกต้อง
- [ ] แตะสินค้าใน Grid → เปิด Product Detail เห็นข้อมูลครบตาม Requirements
- [ ] แตะ Store Information ใน Product Detail → เปิด Store page เห็นข้อมูลครบตาม Requirements
- [ ] ปุ่ม Add to Cart/Buy Now/Follow Store แสดงผลถูกต้องตาม Design แต่ไม่ทำงานจริง (ไม่ crash เมื่อกด)
- [ ] WYN Social เดิมทั้งหมด (Home/Drop/Pop/Club/Profile/Search/Notification) ยังทำงานปกติ ไม่มี regression

Dependencies: WYN Social ทั้งหมด (Auth/Profile/Storage pattern) — ไม่ block โดย WYN-XXX task ใดที่ยังไม่เสร็จ เพราะเป็น feature module ใหม่แยกจาก Social เดิม

Priority: P0 ของสาย ZOKY — ต้องมีก่อนเพราะ ZOKY-002/003/004 ทั้งหมดต้องมี Product/Store ให้อ้างอิงก่อน

Risks:
- **Store Follow ต้อง data model ใหม่ ไม่ reuse `follows` เดิม**: ระบบ Follow ของ WYN Social (WYN-008) เป็น user-to-user เท่านั้น Store ไม่ใช่ profile จึงต้องมีตาราง `store_follows` แยก — เสนอ **ไม่สร้างตารางนี้รอบนี้** ปุ่ม Follow Store แสดงผลอย่างเดียว (visual only เหมือนปุ่ม Follow ของ Pop ตอน WYN-006 ก่อน WYN-008 จะทำให้ทำงานจริง) แล้วผูก data จริงเป็น task แยกทีหลัง
- **Chat Seller เป็นงานคนละขนาด**: ไม่มี messaging system ในโปรเจกต์นี้เลย เสนอซ่อนปุ่มนี้ไปก่อนรอบนี้ทั้งหมด ไม่ทำแม้แต่ placeholder
- **Seller เขียนข้อมูลลง `stores`/`products` เองไม่ได้รอบนี้**: เพราะ ZOKY Sellers by WYN (Phase 4) ยังไม่เริ่ม — ข้อมูลสาธิต/ทดสอบรอบนี้ต้อง seed ผ่าน Supabase Studio/migration ตรง ๆ ไม่ใช่ผ่าน UI ผู้ใช้จริง เมื่อ Phase 4 เริ่มจะต้องเพิ่ม RLS insert/update policy ให้ Seller เขียนข้อมูลร้าน/สินค้าตัวเองได้ (คล้าย pattern RPC-over-raw-RLS ของ WYN-014)
- **"Best Selling"/"Recommended" ยังไม่มีข้อมูลจริงรองรับ**: ต้องรอ ZOKY-003 (Order) ให้มี sales data ก่อนถึงจะ rank ได้จริง — รอบนี้ใช้ placeholder/ว่างเปล่าไปก่อน เหมือนที่ Explore Clubs (WYN-015) defer "แนะนำสำหรับคุณ"
- **Product Variants (Color/Size) ยังไม่ผูกกับ Stock/Price จริงในการคำนวณ Cart**: เพราะ Cart ยังไม่มีในรอบนี้ — UI เลือก variant ได้ แต่แค่ preview ไม่ใช่ transactional state ที่ต้องคำนวณราคาสุดท้ายจริงจนกว่าจะถึง ZOKY-003

Recommendation:
1. เริ่ม ZOKY-001 ทันทีตามที่ Founder สั่งในลำดับ Phase 2-3 ของ master prompt
2. **Store Follow/Chat Seller เป็น visual-only หรือซ่อนไปก่อนตามที่ระบุใน Risks** — ไม่ทำ data model เพิ่มในรอบนี้เพื่อไม่ให้ scope บวมเกินไป
3. **Seed ข้อมูล Product/Store ตัวอย่างผ่าน Supabase Studio** สำหรับทดสอบ/สาธิตรอบนี้ ไม่ต้องรอ Seller app จริง

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) ZOKY tab icon/ตำแหน่งใน Bottom Nav (2) ZOKY Home layout (Categories/Banner/Product sections/Grid) (3) Product Detail screen (4) Store screen — ต้องตัดสินใจ resolution ของ Store Follow/Chat Seller ตาม Risks ข้างต้น ใช้ Design system เดิม (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass) reuse component เดิมให้มากที่สุด (carousel รูปหลายรูปจาก `ClubPostCard`, grid tile จาก `PopGridTile`/`DropGridTile`, search bar placeholder pattern จาก WYN-007)
