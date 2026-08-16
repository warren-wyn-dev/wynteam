# Product Task — DS-007

Status: approved (QA — PASS, 2026-08-16) — 7th ของ 8 เฟส (DS-001 → ... → DS-006 → **DS-007** → DS-008)
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (PASS)

Feature: ZOKY commerce identity (orange accent)

Goal: ทำให้ ZOKY Marketplace ใน `app/` แสดง Orange accent จริงตามที่ DS-001's Design Output กำหนดไว้ (ราคา/CTA/badge/entry point) — ปิดช่องว่างที่พบว่ายังไม่เคย implement จริงตั้งแต่ DS-001

Target User: ลูกค้าที่ใช้ ZOKY Marketplace ใน WYN Social app

## Audit ผล (สำคัญ — พบ gap จริง ไม่ใช่แค่ audit-confirm เหมือน DS-004/DS-006)

DS-001's spec (`.wyn/docs/design/ds-001-color-system.md`, Section 3.4 + 4) ระบุ 5 จุดที่ต้องใช้ Orange พร้อมชื่อไฟล์ `app/` เองตรงๆ แต่ DS-001b's Coding Output สร้าง Orange `ColorScheme` (`ZokyTheme`) ไว้ให้ **แค่ `seller_app/`** เท่านั้น — `app/lib/core/design/` ไม่มีไฟล์ theme ของ ZOKY เลย ทุกจุดที่โค้ด ZOKY เรียก `colorScheme.tertiary` (ราคาสินค้า 6 จุดใน 5 ไฟล์) จึงได้ **Cyan** จริง (ค่า tertiary ของ `WynTheme`) ไม่ใช่ Orange ตามที่ตั้งใจ — เป็น gap ที่ค้างมาตั้งแต่ DS-001c โดยไม่มีใครสังเกต (ไม่มี test ใดเช็คสีจริง)

Requirements: ดูรายละเอียดเต็มใน `.wyn/docs/design/ds-007-zoky-commerce-identity.md`

Acceptance Criteria:
- [x] ราคาสินค้าทุกจุดใน ZOKY Marketplace (`app/`) เป็น Orange จริง
- [x] หน้าจอ Social ไม่มี Orange leak เลย (ยืนยันด้วย test)
- [x] ไอคอนแท็บ ZOKY active เป็น Orange
- [x] `flutter analyze`/`flutter test` ผ่านสะอาด
- [x] `seller_app/` ไม่ถูกแตะเลย

Dependencies: DS-001 (token foundation), DS-005, DS-006

Priority: สูง — เป็น gap ที่ทำให้ AC ของ DS-001 เองยังไม่ satisfied เต็มที่มาตลอด

Risks: ต่ำ-กลาง — แตะ 12 ไฟล์ (10 หน้าจอ + root_shell.dart + ไฟล์ theme ใหม่) แต่เป็นแค่การห่อ `Theme` override ไม่แก้ logic ใดๆ เลย ยืนยันด้วย `flutter analyze` (bracket matching ถูกต้อง) + full test suite ทุกไฟล์

Recommendation: อนุมัติ ไปต่อ DS-008 (Responsive + accessibility, เฟสสุดท้าย)

Handoff: เสร็จสมบูรณ์

---

## Coding Output

- **ใหม่** `app/lib/core/design/wyn_zoky_accent.dart` — `ZokyAccentTheme` widget สลับ `tertiary`/`onTertiary`/`tertiaryContainer`/`onTertiaryContainer` เป็น Orange (ค่าตรงกับ `seller_app`'s `ZokyTheme` เป๊ะ) คงส่วนอื่นทั้งหมดจาก `WynTheme`
- ห่อ `Scaffold` ด้วย `ZokyAccentTheme` ใน 10 ไฟล์: `zoky_home_screen.dart`, `zoky_search_screen.dart`, `store_screen.dart`, `product_detail_screen.dart`, `zoky_cart_screen.dart`, `zoky_checkout_address_screen.dart`, `zoky_checkout_summary_screen.dart`, `zoky_order_list_screen.dart`, `zoky_order_detail_screen.dart`, `product_reviews_screen.dart`
- `root_shell.dart`: ไอคอนแท็บ ZOKY ตอน active (`selectedIcon`) ใส่ `color: WynColors.orange500` ตรงๆ (Icon's explicit color ชนะ NavigationBar's IconTheme เสมอ ไม่ต้องห่อ `ZokyAccentTheme`)
- **ใหม่** `app/test/wyn_zoky_accent_test.dart` — 3 test ยืนยัน: (1) ภายใน `ZokyAccentTheme` ได้ Orange จริง (2) นอก `ZokyAccentTheme` ยังได้ Cyan เหมือนเดิม ไม่ leak (3) slot อื่นของ ColorScheme ไม่เปลี่ยน
- **เลื่อนออกไป** (ดูเหตุผลใน Design doc): badge จำนวนตะกร้าบน BottomNav, `OrderStatusBadge` orange

## QA Verification (2026-08-16)

```
Feature: DS-007 ZOKY commerce identity (orange accent) in app/
Environment: Local Flutter (app/), same branch tip
Test Cases:
  1. flutter analyze -- No issues found (confirms every wrapped Scaffold's bracket
     matching is syntactically correct across all 10 files).
  2. flutter test (full suite) -- 288/288 PASS (was 285 before this task's +3 new tests).
  3. Dedicated ZokyAccentTheme widget tests: confirmed tertiary=orange500/onTertiary=ink
     inside the wrapper, confirmed tertiary=cyan500 (unaffected) for a sibling screen
     outside the wrapper (no app-wide leak), confirmed primary/surface/outline pass
     through unchanged.
  4. grep confirms ZokyAccentTheme wraps exactly the 10 real ZOKY screen files (zoky_
     strings.dart, a constants-only file, correctly excluded).
  5. Confirmed seller_app/ has zero diff (git status scoped to app/ only for this task).
  6. Manual read of root_shell.dart's NavigationDestination change -- explicit Icon
     color, no ambient IconTheme conflict risk since Icon's own color always wins.
Passed: 6/6
Failed: 0
Recommendation: Approve. Move DS-007 to .wyn/tasks/approved/. Continue to DS-008
  (Responsive + accessibility), the final phase of the 8-part rollout.
Final Status: PASS
```
