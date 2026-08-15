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

## Phase 4 — ZOKY Sellers by WYN (รอเนื้อหา Seller section จาก Founder)

ZOKY Marketplace Customer (ZOKY-001 ถึง ZOKY-004) เสร็จสมบูรณ์แล้ว มี Order จริงให้ Seller จัดการแล้ว — **Founder ตัดสินใจสถาปัตยกรรมแล้วเมื่อ 2026-08-15: Feature module ภายในแอป Flutter เดียวเดิม** (ไม่สร้างแอปแยก ไม่ทำ add-to-app module) ดูเหตุผลเต็มที่ `.wyn/company/DECISIONS.md` (2026-08-15 "Phase 4 (ZOKY Sellers by WYN) — เลือกสถาปัตยกรรม Feature module ในแอปเดียวเดิม") — จะพัฒนาเป็น `app/lib/features/seller/` ต่อยอด pattern เดิมทั้งหมด (RLS/security-definer RPC, Repository pattern, `Navigator.push`/`IndexedStack`) แนวทาง UI ที่เป็นไปได้: entry point แบบ role-based (เช่น "โหมดร้านค้า" ใน Profile/Settings) แทนการเพิ่ม Bottom Nav tab ที่ 6 — รอ AI Design ตัดสินใจรายละเอียดตอนออกแบบจริง

**สถานะปัจจุบัน**: รอ Founder ส่งเนื้อหาเต็มของ "WYN PLATFORM — MASTER DEVELOPMENT PROMPT" ส่วนที่เกี่ยวกับ Seller (Section 12-17 โดยประมาณ) มาใหม่ก่อนเริ่มเขียน Product spec จริง — เนื้อหาเต็มไม่เคยถูกเก็บไว้ใน repo เลยตั้งแต่ต้น มีแค่ summary ระดับสูงที่ AI Product Manager สรุปไว้ตอนวาง roadmap นี้ (2026-08-14)

## Phase 5 — เชื่อม Customer ↔ Seller ↔ Backend (ยังไม่เริ่ม)

## Phase 6 — WYN Admin V0.1 (ยังไม่เริ่ม)

รอจนกว่า Phase 4-5 จะเสร็จ — เช่นเดียวกับ Phase 4 จะประเมินสถาปัตยกรรม (แอปแยก vs web dashboard vs feature module) ตอนถึง Phase นี้จริง

## Phase 7-8 — เชื่อม Admin + Finance/Fees/Analytics/Moderation (ยังไม่เริ่ม)

## ขอบเขตที่ยืนยันแล้วว่า "ยังไม่ทำ" รอบนี้ (ตามที่ master prompt ระบุไว้ตรง ๆ)

- ZOKY Food / ZOKY Rider / ZOKY Delivery เต็มระบบ — เตรียม Architecture ให้ขยายได้เท่านั้น ไม่ implement
- ZOKY Sellers by WYN, WYN Admin — Phase 4/6 ตามลำดับ
- Coupon/Campaign/Flash Sale/Featured Products (Admin Promotions, Section 28) — ทำได้แค่ "รองรับในอนาคต" ตามที่ระบุ ไม่ implement เต็มรูปแบบรอบนี้
- Shipping Provider integration จริง (Section 19) — ออกแบบ Order ให้มีช่อง Shipping Provider/Tracking Number/Shipment Status รองรับ แต่ไม่เชื่อมต่อผู้ให้บริการขนส่งจริง

## Naming & Numbering Convention

- Task ID prefix: **ZOKY-XXX** (แยกจาก WYN-XXX เดิมของ WYN Social) — เก็บใน `.wyn/tasks/` workflow เดียวกันทุกประการ (backlog → review → approved)
- Branding: **ZOKY** เป็นชื่อ Marketplace (ไม่ใช่ "WYN Shop") ตามที่ Founder ระบุห้ามใช้ชื่อนั้นตรง ๆ ใน master prompt Section 34
- Governance: WYN AI Company workflow เดียวกันทั้งหมด (Product→Design→Code→QA→Debug, Thai สำหรับ Founder-facing, English สำหรับโค้ด, PR-per-role squash-merge, progress % reporting)
