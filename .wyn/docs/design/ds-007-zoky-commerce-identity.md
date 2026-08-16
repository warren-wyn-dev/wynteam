# Design Spec — DS-007 (ZOKY commerce identity, orange accent)

> โดย AI Design — 2026-08-16 | ต่อจาก DS-005 (Club) + DS-006 (Profile/Search audit-only)

## Audit ก่อนออกแบบ (พบช่องว่างจริง — ต่างจาก DS-004/DS-006)

DS-001's Design Output (`.wyn/docs/design/ds-001-color-system.md`, Section 3.4 + 4) นิยาม **5 จุด** ที่ ZOKY Orange ใช้ได้ พร้อมระบุไฟล์ของ `app/` เอง (`product_grid_tile.dart`, `product_detail_screen`, `cart`, `order`, `store_screen`, `OrderStatusBadge`, `root_shell.dart`) — แต่ตรวจ DS-001b's Coding Output จริงแล้วพบว่า **สร้าง Orange ColorScheme (`ZokyTheme`) ไว้ให้แค่ `seller_app/` เท่านั้น** — `app/lib/core/design/` ไม่มีไฟล์ theme ของ ZOKY เลย (`ls app/lib/core/design/` ไม่มี `wyn_zoky_theme.dart` ต่างจาก `seller_app/`) `app/`'s `WynTheme` เดียวที่มีอยู่แม็ป `colorScheme.tertiary` เป็น **Cyan** (ใช้เป็นสี link ข้อความเปล่า ตาม comment ใน `wyn_colors.dart`) ไม่ใช่ Orange

ผลคือ: ทุกจุดใน `app/`'s ZOKY Marketplace ที่เรียก `Theme.of(context).colorScheme.tertiary` (พบ 6 จุดใน 5 ไฟล์ — ราคาสินค้าทุกที่: grid tile, product detail, cart, checkout summary, order detail) **แสดงผลเป็น Cyan จริง ไม่ใช่ Orange** ทั้งที่โค้ดตั้งใจเรียก tertiary เพื่อให้ได้ Orange ตาม DS-001's สเปกเป๊ะ — เป็น gap การ implement ที่ไม่ตรงกับ spec ตัวเองมาตั้งแต่ DS-001c

## การตัดสินใจ

สร้าง `ZokyAccentTheme` widget ใหม่ใน `app/lib/core/design/wyn_zoky_accent.dart` — สลับเฉพาะ `tertiary`/`onTertiary`/`tertiaryContainer`/`onTertiaryContainer` จาก Cyan เป็น Orange (ค่าตรงตัวจาก `seller_app/lib/core/design/wyn_zoky_theme.dart`'s `_lightScheme`/`_darkScheme` — ไม่ประดิษฐ์ค่าใหม่) ส่วนอื่นทั้งหมด (`primary`/`surface`/`outline`/`textTheme`) คงเดิมจาก `WynTheme` — **ไม่ใช่ theme แยกทั้งแอปแบบ `seller_app/`'s `ZokyTheme`** เพราะ ZOKY เป็นแค่ 1 ใน 5 แท็บของ `app/` ไม่ใช่ทั้งแอปเหมือน `seller_app/`

**ทำไมต้อง wrap ทีละหน้าจอ ไม่ wrap ที่จุดเดียว**: `Navigator.push(MaterialPageRoute(...))` (ที่ทุกการเปลี่ยนหน้าจอในโปรเจกต์นี้ใช้) **ไม่สืบทอด `Theme` override ที่ห่อแค่ widget ต้นทาง** — หน้าจอใหม่ถูกแทรกเป็น sibling ใน `Navigator`'s `Overlay` ไม่ใช่ descendant ของ `Theme` ที่ห่อปุ่มที่กด push ดังนั้นการห่อแค่ `ZokyHomeScreen` (tab entry) จุดเดียวจะไม่ไหลไปถึงหน้าที่ push ต่อ (`ProductDetailScreen`, `StoreScreen`, `ZokyCartScreen`, checkout flow, order screens) ซึ่งเป็นจุดที่ DS-001's spec ระบุไว้ตรงๆ ว่าต้องมี Orange — จึงต้องห่อทุกหน้าจอ ZOKY ที่มี `Scaffold` ของตัวเองแยกกัน (10 ไฟล์)

## Requirements

R1. สร้าง `ZokyAccentTheme` (`app/lib/core/design/wyn_zoky_accent.dart`) — ค่าตรงกับ `seller_app`'s `ZokyTheme` เป๊ะ
R2. ห่อ `Scaffold` ของทั้ง 10 หน้าจอ ZOKY (`zoky_home_screen`, `zoky_search_screen`, `store_screen`, `product_detail_screen`, `zoky_cart_screen`, `zoky_checkout_address_screen`, `zoky_checkout_summary_screen`, `zoky_order_list_screen`, `zoky_order_detail_screen`, `product_reviews_screen`) ด้วย `ZokyAccentTheme`
R3. เพิ่มสี Orange ที่ "จุด entry ของ ZOKY" (DS-001 Section 4, ข้อ 5) — ไอคอนแท็บ ZOKY ตอน active ใน `root_shell.dart`'s BottomNav
R4. ไม่แตะ `primary`/`surface`/`outline`/typography — สลับแค่ tertiary family
R5. ไม่ทำ badge จำนวนของในตะกร้าบน BottomNav icon รอบนี้ (ดูหัวข้อ "เลื่อนออกไป" ด้านล่าง)

## สิ่งที่เลื่อนออกไป (ไม่ทำรอบนี้)

- **Badge จำนวนสินค้าในตะกร้าบนไอคอนแท็บ ZOKY** (DS-001 Section 4 ข้อ 5, ส่วนที่สอง) — ต้องเพิ่ม state การนับตะกร้าใน `RootShell` เอง (ปัจจุบันมีแค่ใน `ZokyHomeScreen`'s AppBar) เป็น scope ใหญ่กว่าสีไอคอนล้วนๆ (ต้อง sync ข้าม tab, invalidate เมื่อตะกร้าเปลี่ยนจากที่อื่น) แยกเป็น task ในอนาคตถ้า Founder ต้องการ
- **`OrderStatusBadge` commerce-state orange** (DS-001 Section 4 ข้อ 4, "จัดส่งแล้ว/กำลังจัดส่ง") — ตรวจ `order_status_badge.dart` แล้วใช้สี semantic (เขียว/เหลือง) ต่อสถานะอยู่แล้ว การเปลี่ยนเป็น Orange ต้องคิดใหม่ว่าจะขัดกับ semantic success/warning หรือไม่ (DS-001's เอง "ห้ามใช้เด็ดขาด: สีสถานะ error/warning ต้องใช้สี semantic เพราะส้มกับแดงแยกไม่ออกสำหรับคนตาบอดสี") — ต้องมี Design Output แยกสำหรับจุดนี้ ไม่ใช่ mechanical wrap เหมือน R2 จึงเลื่อนไปพิจารณาแยก

## Acceptance Criteria

- [x] ราคาสินค้าทุกจุดใน `app/`'s ZOKY Marketplace แสดง Orange จริง (ยืนยันด้วย widget test ของ `ZokyAccentTheme` เอง)
- [x] หน้าจอ Social (Home/Drop/Pop/Club/Profile/Search/Notification) ยังเห็น Cyan เหมือนเดิม ไม่มี leak
- [x] ไอคอนแท็บ ZOKY ตอน active เป็น Orange
- [x] `flutter analyze`/`flutter test` ผ่านสะอาด
- [x] ไม่แตะ `seller_app/` เลย (เพราะมี `ZokyTheme` ของตัวเองอยู่แล้ว ผ่าน QA แล้วตั้งแต่ DS-001)

## Handoff

ส่งต่อ AI Coding: สร้าง `ZokyAccentTheme` + ห่อ 10 หน้าจอ + แก้ `root_shell.dart` 1 บรรทัด — ดู Coding Output/QA Verification ใน task file
