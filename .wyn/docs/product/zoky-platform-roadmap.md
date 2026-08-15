# ZOKY Marketplace Roadmap — WYN Platform Expansion (2026-08-14)

> อ้างอิงคำตัดสินใจของ Founder ที่ `.wyn/company/DECISIONS.md` (2026-08-14 "ขยาย WYN เป็น WYN Platform") — ต้นฉบับเต็มคือ "WYN PLATFORM — MASTER DEVELOPMENT PROMPT" (38 หัวข้อ) ที่ Founder ส่งมาหลัง WYN CLUB (WYN-014/WYN-015) ผ่าน QA ครบ

## Phase 1 — ตรวจสอบโปรเจกต์ WYN ปัจจุบัน (เสร็จแล้ว)

ตรวจสอบโดย AI Product Manager ก่อนวาง roadmap นี้:

- **Repository**: single Flutter project ที่ `app/` (ไม่มี monorepo tooling ใด ๆ — ไม่มี Melos/workspace) + `supabase/schema.sql` เป็น source of truth เดียวของ backend schema — **ต่างจากตัวอย่าง GitHub structure ใน master prompt (Section 33)** ที่เป็น JS/TS-style monorepo (`apps/customer`, `apps/sellers`, `apps/admin`, `packages/ui` ฯลฯ) — โครงสร้างนั้นไม่ตรงกับ stack จริงของโปรเจกต์ จึงไม่ใช้ตามตัวอักษร (ดูเหตุผลเต็มใน DECISIONS.md)
- **Framework**: Flutter (Dart), ไม่มี routing package (`Navigator.push`/`MaterialPageRoute` + `IndexedStack` สำหรับ Bottom Nav tab persistence)
- **State Management**: ไม่มี library เฉพาะ — `StatefulWidget` + Repository pattern (คลาสต่อ feature เรียก Supabase ตรง ๆ ผ่าน constructor-injected `SupabaseClient`, ไม่มี DI framework, instantiate ที่ `RootShell` แล้ว prop-drill ลงไป)
- **Components ที่มีอยู่แล้วที่ ZOKY ควร reuse ได้ตรง ๆ**: `AvatarCircle`, `relativeTimeLabel`, `ConfirmDeleteDialog` (`app/lib/core/widgets/`), แถว list แบบ `FollowListScreen`/`ClubDiscoveryCard`, การ์ด grid แบบ `PopGridTile`/`DropGridTile`/`SavedGridTile`, debounce+`TabBar` search pattern จาก `SearchScreen` (WYN-009), signed-URL pattern สำหรับ non-public storage bucket จาก `club-media` (WYN-014)
- **Routing/Navigation**: 4-tab Bottom Nav ปัจจุบัน (Home/Drop/Pop/Profile) ใน `RootShell` (`app/lib/features/root/presentation/root_shell.dart`) — `IndexedStack` เก็บ state ของทุกแท็บไว้ ไม่ unmount เวลาเปลี่ยนแท็บ
- **Database**: Supabase (PostgreSQL + Auth + Storage + Realtime) — RLS ทุกตาราง, RPC-over-raw-RLS pattern สำหรับ permission graph ซับซ้อน (พิสูจน์แล้วที่ WYN-014 Club role system), security-definer trigger pattern สำหรับ side-effect ที่ต้องเกิดขึ้นเสมอไม่ว่า client path ไหนเรียก (notifications)
- **Authentication**: Supabase Auth (`auth.uid()`), ทุก RLS policy/RPC อ้างอิง `auth.uid()` ตรง ไม่เชื่อค่าที่ client ส่งมา
- **Backend/API**: ไม่มี custom backend server — Flutter เรียก Supabase (PostgREST + RPC) ตรงผ่าน `supabase_flutter` package ทั้งหมด ไม่มี Edge Function ใช้งานจริงในโปรเจกต์นี้ ณ ตอนนี้ (มีแค่ระบุไว้ใน tech stack ตั้งแต่ WYN-001 ว่าใช้ได้ในอนาคตถ้าจำเป็น)

**สรุป**: ZOKY Marketplace รอบนี้จะพัฒนาเป็น **feature module ใหม่ภายในแอป Flutter เดียวเดิม** ไม่สร้างแอปแยก ไม่เปลี่ยน routing/state-management approach ที่มีอยู่ — ต่อยอด pattern เดิมทั้งหมด (ดูเหตุผลเต็มใน DECISIONS.md)

## Phase 2-3 — ZOKY Marketplace Customer (Browse → Cart → Checkout → Order → Review)

แตกจาก master prompt Section 3-11 เป็น task ขนาดที่ทีมเคยพิสูจน์แล้วว่าจัดการได้ดี (bounded vertical slice ต่อ task เหมือน WYN-005/006/007 เดิม):

| Task | Feature | ครอบคลุม (Section master prompt) | Depends on |
|---|---|---|---|
| **ZOKY-001** | Marketplace Foundation — Home/Product Detail/Store (Browse only) | Section 3 (Navigation), 4 (ZOKY Home), 6 (Product Detail — ไม่รวม Add to Cart ทำงานจริง), 7 (Store — ไม่รวม Follow/Chat ทำงานจริง) | WYN Social ทั้งหมด (ใช้ Auth/Profile/Storage pattern เดิม) |
| **ZOKY-002** | Search & Filter | Section 5 | ZOKY-001 (ต้องมี Product/Store ให้ค้นหา) |
| **ZOKY-003** | Cart & Checkout & Order | Section 8 (Cart), 9 (Checkout), 10 (Order + Order Status), ค่าธรรมเนียม `ZOKY_MARKETPLACE_FEE` (Section 18) | ZOKY-001 |
| **ZOKY-004** | Review | Section 11 (ต้องมี Order ที่ Delivered แล้วถึงจะรีวิวได้) | ZOKY-003 |

**เหตุผลที่แบ่งแบบนี้**: ZOKY-001 ให้ผลลัพธ์ที่ทดสอบ/เห็นผลได้จริงเร็วที่สุด (เปิดแอปแล้วเห็น ZOKY tab, เรียกดูสินค้า/ร้านค้าได้) โดยยังไม่ต้องแตะระบบเงิน/คำสั่งซื้อที่ซับซ้อนกว่าและมีความเสี่ยงด้าน data-integrity สูงกว่า (Order status transition, Fee calculation) — Search (ZOKY-002) ต้องมี Product/Store ให้ค้นหาก่อนถึงจะมีความหมาย เหมือนที่ WYN-009 (Search) มาหลัง WYN-005/006 (Drop/Pop) — Cart/Checkout/Order (ZOKY-003) เป็นก้อนเดียวเพราะ 3 ส่วนนี้เป็น flow ต่อเนื่องเดียวกันแยกไม่ได้จริง (Cart ว่างเปล่าไม่มีความหมายถ้าไม่มี Checkout ไปต่อ) — Review (ZOKY-004) ต้องรอ Order Delivered ให้เกิดได้จริงก่อน จึงมาหลัง ZOKY-003 เสมอ

### ประเด็นที่ยังไม่ตัดสินใจ ณ จุดนี้ (ปล่อยให้ AI Design ตัดสินใจตอนออกแบบ ZOKY-001)

- **Store Follow**: master prompt (Section 7) ระบุปุ่ม "Follow Store" แต่ระบบ Follow เดิมของ WYN Social (WYN-008, `FollowRepository`) เป็นการ follow **ผู้ใช้ (profile)** ไม่ใช่ follow **ร้านค้า (store)** ซึ่งเป็น entity คนละแบบ (store เป็นเจ้าของโดย seller คนหนึ่งแต่ไม่ใช่ profile ของลูกค้าที่จะ follow กัน) — ต้องออกแบบตาราง follow ใหม่แยกสำหรับ store (เช่น `store_follows`) ไม่ reuse ตาราง `follows` เดิมตรง ๆ
- **Chat Seller**: master prompt (Section 7) ระบุปุ่ม "Chat Seller" แต่โปรเจกต์นี้ไม่เคยมีระบบ chat/messaging เลยแม้แต่จุดเดียว (WYN Social ทั้งหมดเป็น content-based ไม่ใช่ 1-on-1 messaging) — เป็นงานคนละขนาดจาก Marketplace browsing ปกติ เสนอ **defer ปุ่มนี้ไปเป็น task แยกในอนาคต** (คล้ายที่ hashtag-click-through/mention ถูก defer มาหลายรอบในโปรเจกต์นี้) ไม่ทำใน ZOKY-001

## Phase 4 — ZOKY Sellers by WYN

ZOKY Marketplace Customer (ZOKY-001 ถึง ZOKY-004) เสร็จสมบูรณ์แล้ว มี Order จริงให้ Seller จัดการแล้ว — **Founder ตัดสินใจสถาปัตยกรรมสุดท้ายเมื่อ 2026-08-15: แอป Flutter แยกต่างหาก** (ไม่ใช่ feature module ในแอปเดิม) เทียบเท่าโมเดล Shopee/Lazada Seller Center — ดูเหตุผลเต็มที่ `.wyn/company/DECISIONS.md` (2026-08-15 "Phase 4 (ZOKY Sellers by WYN) — Founder แก้ไขคำตัดสินใจเป็นแอปแยกต่างหาก") — Founder ส่งเนื้อหาเต็มของ master prompt Section 12-17 มาแล้ว (2026-08-15)

### สถาปัตยกรรมที่ตัดสินใจแล้วสำหรับ Phase 4 (AI Product Manager ตรวจสอบ repo แล้วก่อนเริ่ม)

- **Repository ของแอปที่สอง**: โฟลเดอร์ใหม่ `seller_app/` ที่ root ของ repo เดียวกัน (คู่กับ `app/` เดิม) — **ไม่ใช้ Melos/monorepo tooling ในรอบแรก** เพราะยังไม่มี pain จริงจากการไม่มี shared package (โปรเจกต์เล็ก มีแค่ 2 แอป) การตั้ง monorepo tooling เป็นการลงทุนโครงสร้างที่ยังไม่จำเป็น — ถ้า duplication เริ่มเจ็บปวดจริงในอนาคต (เช่น ต้องแก้ widget เดียวกันสองที่บ่อย ๆ) ค่อยประเมิน Melos ใหม่ตอนนั้น
- **Bundle ID/ชื่อแอป**: `app/`'s bundle ID ปัจจุบันคือ `io.wyn.wyn` (ทั้ง Android/iOS) — `seller_app/` ใช้ `io.wyn.zokyseller` ให้สอดคล้องกัน ชื่อแอป "ZOKY Sellers by WYN" ตาม branding ที่ Founder ระบุ (Section 34)
- **Backend**: Supabase project เดียวกันกับ `app/` (Shared Backend ตาม master prompt) — อ่าน `Env`/`--dart-define` pattern เดิมจาก `app/lib/core/env.dart` แล้ว duplicate เข้า `seller_app/` (ไฟล์เล็กมาก ไม่คุ้มสร้าง shared package สำหรับไฟล์เดียว)
- **Authentication**: **reuse Supabase Auth เดียวกันกับ WYN Social ทั้งหมด** (`auth.users`/`profiles` เดิม) — Seller คือผู้ใช้ WYN ที่มีอยู่แล้วซึ่ง "สมัครร้าน" เพิ่ม (สร้างแถวใน `stores` ที่ `owner_id = auth.uid()` — คอลัมน์นี้มีอยู่แล้วตั้งแต่ ZOKY-001) — **ไม่สร้างระบบ auth ใหม่แยกต่างหาก** ตรงตามกติกา "ห้ามเขียนระบบซ้ำ" ของ master prompt เอง — sign-in screen ของ `seller_app/` เรียก Supabase Auth เดียวกัน แต่เป็น UI ใหม่แยกไฟล์ (ไม่ share widget code กับ `app/` เพราะเป็นคนละ Flutter binary และยังไม่มี package infra ให้ share) — ขอบเขต flow ที่แน่นอน (reuse mechanism ไหนจาก 6 หน้าจอ auth เดิมของ WYN Social) ให้ AI Design ตัดสินใจตอนออกแบบ SELLER-001
- **Design system**: ใช้ seed color เดียวกัน (`0xFF2D6CDF`, Blue+White+Soft Gray, Material 3) — duplicate `ThemeData` setup เข้า `seller_app/main.dart` ตรง ๆ (ไม่ share package เหตุผลเดียวกับ Env)
- **Database — RLS ที่ต้องเพิ่มใหม่** (ตารางเดิมทั้งหมดมีอยู่แล้วตั้งแต่ ZOKY-001/003 แต่เป็น select-only สำหรับ client ทั้งหมด ไม่มี seller เขียนได้เลยสักจุด):
  - `stores`: เพิ่ม insert/update policy scoped `owner_id = auth.uid()`
  - `products`/`product_variants`: เพิ่ม insert/update/delete policy scoped ผ่าน `exists` subquery ยืนยันว่า `products.store_id` เป็นร้านของ `auth.uid()` เอง (pattern เดียวกับ `club_posts`'s `club_role()` check จาก WYN-014)
  - `orders`/`order_items`: เพิ่ม **select** policy ใหม่ให้ seller เห็น order ของร้านตัวเอง (ปัจจุบันมีแค่ select policy ฝั่ง buyer เท่านั้น) — ยังไม่เพิ่ม write policy ให้ seller ตรง ๆ รอบนี้ (status transition ของ seller ต้องผ่าน RPC ใหม่เหมือน buyer-side เดิม เหตุผลเดียวกัน — ทำใน SELLER-003)
- **Order status ต้องขยายจาก 3 สถานะเป็น 8 สถานะ** ตามที่ master prompt Section 10 ระบุไว้ตั้งแต่ต้น (Pending Payment → Paid → Seller Processing → Ready to Ship → Shipped → Delivered / Cancelled / Refunded) — ZOKY-003 ตั้งใจทำแค่ 3 สถานะ (pending/delivered/cancelled) และบันทึกไว้ชัดเจนในตอนนั้นว่า **"เมื่อ ZOKY Sellers by WYN เริ่มจริง จะต้องออกแบบสถานะเพิ่ม (confirmed/shipped) และ migration/RPC ใหม่ที่ผูกกับสิทธิ์ของ Seller"** (ดู `.wyn/tasks/approved/ZOKY-003-cart-checkout-order.md`, Risks) — ถึงจุดนั้นแล้วตอนนี้ งานนี้แยกเป็น SELLER-003 (Order Management) เพราะเป็นจุดที่กระทบโค้ด Customer-facing ที่ผ่าน QA แล้ว (`OrderStatusBadge`, `ZokyOrderDetailScreen`) มากที่สุด ต้องระมัดระวังเป็นพิเศษไม่ให้ regression

### Task breakdown (SELLER-XXX)

| Task | Feature | ครอบคลุม (Section master prompt) | Depends on |
|---|---|---|---|
| **SELLER-001** | Foundation — แอปใหม่, Seller sign-in (reuse WYN auth), "สมัครร้าน" flow, Seller Dashboard (สถิติที่ทำได้จริงตอนนี้) | Section 12 (สมัคร/สร้างร้าน), 13 (Dashboard — บางส่วน) | ZOKY-001 ถึง ZOKY-004 (Marketplace Customer ต้องเสร็จ มี Order จริงให้แสดง) |
| **SELLER-002** | Product Management — Add/Edit/Delete/Enable-Disable, Price, Discount, Images, Variants, Stock, SKU | Section 14 | SELLER-001 |
| **SELLER-003** | Order Management — ขยายสถานะ 3→8, View/Accept/Process/Ready to Ship/Tracking/Update Status | Section 10 (ขยายสถานะ), 15, 19 (Shipping fields) | SELLER-001, กระทบ ZOKY-003 เดิมด้วย (ต้อง migration) |
| **SELLER-004** | Store Management — Logo/Name/Banner/Description/Address/Contact | Section 16 | SELLER-001 |
| **SELLER-005** | Finance — Gross Sales/ZOKY Fee/Net Revenue/Balance/Payout History | Section 17, 18 (fee config ใช้ `platform_config` เดิมจาก ZOKY-003) | SELLER-003 (ต้องมี Order ที่จบ flow แล้วถึงจะมียอดขายจริงคำนวณได้) |

**เหตุผลที่แบ่งแบบนี้**: SELLER-001 ต้องมาก่อนเพราะเป็นจุดที่ตั้งค่าโครงสร้างแอปใหม่ทั้งหมด (auth/nav/theme) ให้ task อื่นต่อยอดได้ — SELLER-002 (จัดการสินค้า) ทำก่อน SELLER-003 (จัดการ Order) เพราะต้องมีสินค้าที่ seller คุมเองได้ก่อนถึงจะทดสอบ order flow แบบ end-to-end จริงได้ — SELLER-004 (ข้อมูลร้าน) ไม่ผูกกับ order/product เลยทำคู่ขนานกับ SELLER-002/003 ได้ — SELLER-005 (การเงิน) ต้องรอ Order ที่จบ flow จริงจาก SELLER-003 ก่อนถึงจะมียอดขายให้คำนวณค่าธรรมเนียม/รายได้จริง

### ประเด็นที่ยังไม่ตัดสินใจ ณ จุดนี้ (ปล่อยให้ AI Design/Coding ตัดสินใจตอนออกแบบแต่ละ task)

- **Payment/Payment Method**: master prompt Section 9 (Checkout) และ Section 18/26 (Finance) พูดถึง Payment Method/Payment Fee แต่ ZOKY-003 ตั้งใจไม่ทำ payment gateway จริง (Order สร้างตรงเทียบเท่าเก็บเงินปลายทาง) — **ยังไม่เปลี่ยนการตัดสินใจนี้ใน Phase 4** เพราะยังไม่มี payment provider จริงให้เชื่อม (เป็นคนละงานจาก Sellers app) — SELLER-005's Finance จะคำนวณจาก Order.total ที่มีอยู่แล้ว ไม่ใช่จาก payment gateway จริง — Payment Fee field ใน UI จะแสดงเป็น 0/ไม่มีจนกว่าจะมี payment provider จริง
- **Shipping Provider integration**: ตาม master prompt Section 19 เอง ระบุชัดว่า "ไม่ต้องสร้างบริษัทขนส่งเอง" รอบนี้ — SELLER-003 จะเพิ่มช่อง Shipping Provider (free text)/Tracking Number/Shipment Status ให้ Order รองรับ แต่ไม่เชื่อมต่อ API ขนส่งจริง
- **Seller Approval workflow** (Section 25 — Admin อนุมัติ Seller ก่อนเปิดขาย): เป็นงานของ WYN Admin (Phase 6) ที่ยังไม่เริ่ม — SELLER-001 รอบนี้ให้ "สมัครร้าน" แล้วขายได้ทันที (auto-approved) เพราะยังไม่มี Admin ให้อนุมัติ บันทึกเป็น Known Issue ชัดเจน ไม่ใช่การมองข้าม

## Phase 5 — เชื่อม Customer ↔ Seller ↔ Backend (ยังไม่เริ่ม)

## Phase 6 — WYN Admin V0.1 (ยังไม่เริ่ม)

รอจนกว่า Phase 4-5 จะเสร็จ — เช่นเดียวกับ Phase 4 จะประเมินสถาปัตยกรรม (แอปแยก vs web dashboard vs feature module) ตอนถึง Phase นี้จริง

## Phase 7-8 — เชื่อม Admin + Finance/Fees/Analytics/Moderation (ยังไม่เริ่ม)

## ขอบเขตที่ยืนยันแล้วว่า "ยังไม่ทำ" รอบนี้ (ตามที่ master prompt ระบุไว้ตรง ๆ)

- ZOKY Food / ZOKY Rider / ZOKY Delivery เต็มระบบ — เตรียม Architecture ให้ขยายได้เท่านั้น ไม่ implement
- WYN Admin — Phase 6 ยังไม่เริ่ม (รวมถึง Seller Approval workflow)
- Coupon/Campaign/Flash Sale/Featured Products (Admin Promotions, Section 28) — ทำได้แค่ "รองรับในอนาคต" ตามที่ระบุ ไม่ implement เต็มรูปแบบรอบนี้
- Shipping Provider integration จริง (Section 19) — ออกแบบ Order ให้มีช่อง Shipping Provider/Tracking Number/Shipment Status รองรับ แต่ไม่เชื่อมต่อผู้ให้บริการขนส่งจริง
- Payment gateway จริง (Section 9/18/26) — Order/Finance คำนวณจาก Order.total ที่มีอยู่แล้ว ไม่ใช่จาก payment provider จริง

## Naming & Numbering Convention

- Task ID prefix: **ZOKY-XXX** สำหรับ ZOKY Marketplace Customer (แยกจาก WYN-XXX เดิมของ WYN Social), **SELLER-XXX** สำหรับ ZOKY Sellers by WYN (Phase 4) — เก็บใน `.wyn/tasks/` workflow เดียวกันทุกประการ (backlog → review → approved)
- Branding: **ZOKY** เป็นชื่อ Marketplace (ไม่ใช่ "WYN Shop") ตามที่ Founder ระบุห้ามใช้ชื่อนั้นตรง ๆ ใน master prompt Section 34 — แอป Seller ชื่อ **"ZOKY Sellers by WYN"**
- Governance: WYN AI Company workflow เดียวกันทั้งหมด (Product→Design→Code→QA→Debug, Thai สำหรับ Founder-facing, English สำหรับโค้ด, PR-per-role squash-merge, progress % reporting)
