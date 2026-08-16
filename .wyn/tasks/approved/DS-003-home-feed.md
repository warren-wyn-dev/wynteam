# Product Task — DS-003

Status: approved (QA — PASS, 2026-08-16) — 3rd of the 8-part design system rollout DS-001's Recommendation proposed (DS-001 → DS-002 → **DS-003** → DS-004 → ... → DS-008)
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (PASS)

Feature: Home Feed — card-less continuous feed

Goal: ทำให้ Home Feed อ่านง่ายเมื่อเลื่อนต่อเนื่องยาวๆ โดยไม่ใช้ card/border/shadow แบบเดิม ๆ ตามทิศทาง "card-less continuous feed" ที่ DS-001's Recommendation ตั้งชื่อ task นี้ไว้

Target User: ผู้ใช้ WYN ทุกกลุ่ม (Home คือหน้าแรกที่เห็นทุกครั้งที่เปิดแอป)

Problem (จาก audit ก่อนออกแบบ — เปลี่ยนขอบเขตงานจริง):
อ่าน `home_drop_card.dart`/`home_pop_card.dart` แล้วพบว่า Home Feed **ไม่เคยใช้ `Card` widget เลยตั้งแต่ WYN-007** — แต่ละรายการเป็น `Column` เปล่าไม่มี elevation/border/พื้นหลังต่างจากพื้น Scaffold รูปภาพ full-bleed ไม่มีมุมโค้ง เข้าเกณฑ์ "card-less" อยู่แล้วโดยไม่ต้องแก้อะไร ช่องว่างจริงที่เหลือมีจุดเดียว: รายการคั่นกันด้วยช่องว่างเปล่าล้วน (16px รวม) ไม่มีจุดคั่นสายตาเลย ทำให้โพสต์สั้น (ไม่มี caption) ดูติดกับโพสต์ถัดไป

Requirements:
R1. เพิ่มเส้นคั่นบาง (`Divider(height: 1)`) ระหว่างทุกรายการใน Home Feed's ListView ทั้ง 2 โหมด (สำหรับคุณ / จาก Club ของคุณ)
R2. ไม่มีเส้นคั่นก่อนรายการแรกหรือหลังรายการสุดท้าย (ก่อน loading spinner)
R3. ไม่แตะ `home_drop_card.dart`/`home_pop_card.dart` เลย — แก้แค่ `home_feed_screen.dart`'s ListView
R4. ไม่ hardcode สีใหม่ — ใช้ `Divider()` เปล่าให้ theme (`colorScheme.outlineVariant` = `WynColors.borderSubtleLight`/`borderSubtleDark`) กำหนดเอง

Acceptance Criteria:
- [x] มีเส้นคั่นบาง (1px) ระหว่างทุกโพสต์ใน Home Feed ทั้งสองโหมด
- [x] ไม่มีเส้นคั่นก่อนรายการแรกหรือหลังรายการสุดท้าย
- [x] ไม่มี `Card`/`elevation`/`BoxShadow`/`ClipRRect` มุมโค้งใหม่เพิ่มเข้ามาที่ไหนเลย
- [x] `flutter analyze`/`flutter test` ผ่านสะอาดใน `app/`
- [x] เส้นคั่นเปลี่ยนสีถูกต้องเองระหว่าง light/dark ผ่าน `colorScheme.outlineVariant` (ไม่ hardcode)

Dependencies: DS-001 (token foundation), DS-002 (global Card flattening) — ทั้งคู่เสร็จแล้ว

Priority: กลาง (ต่อเนื่องจากลำดับ 8 เฟสที่ DS-001 วางไว้)

Risks: ต่ำ — เปลี่ยนแค่ `ListView.builder` → `ListView.separated` ใน 1 ไฟล์ ไม่แตะ data layer/repository/schema เลย

Recommendation: อนุมัติ ขอบเขตเล็กชัดเจน ต่อด้วย DS-004 (Drop — image-first) ตามลำดับเดิม

Handoff: ส่งต่อ AI Design → AI Coding แล้วเสร็จสมบูรณ์ (ดู Design Output/Coding Output/QA Verification ด้านล่าง)

---

## Design Output

> โดย AI Design — 2026-08-16 | spec เต็ม: `.wyn/docs/design/ds-003-home-feed.md`

สรุป: ใช้ Flutter `Divider(height: 1)` มาตรฐานตรง ๆ ไม่ประดิษฐ์ widget ใหม่ เพราะ Material 3's `DividerThemeData` default ดึงสีจาก `colorScheme.outlineVariant` ซึ่งตรงกับ token ที่ต้องการอยู่แล้ว (`wyn_colors.dart`: `outlineVariant: borderSubtleLight`/`borderSubtleDark`) — border ระดับ subtle (ไม่ใช่ border-strong) ใช้ถูกต้องตาม DS-001's กติกาที่ระบุว่า subtle border ใช้กับ "เส้นแบ่งตกแต่ง" ได้ (ต่างจาก border-strong ที่บังคับเฉพาะขอบสิ่งที่กดได้ตาม WCAG 1.4.11 ซึ่ง divider ระหว่างโพสต์ไม่ใช่สิ่งที่กดได้เอง)

## Coding Output

- `app/lib/features/home/presentation/home_feed_screen.dart`: `ListView.builder` → `ListView.separated`, `separatorBuilder` คืน `Divider(height: 1)` เฉพาะระหว่างรายการเนื้อหาจริง (`index + 1 < _items.length`) ไม่รวมตำแหน่งก่อน loading spinner
- ไม่แตะไฟล์อื่นเลย

## QA Verification (2026-08-16)

```
Feature: DS-003 Home Feed hairline divider
Environment: Local Flutter (app/), same branch tip
Test Cases:
  1. flutter analyze -- No issues found
  2. flutter test (full suite) -- 284/284 PASS (was 283 before this task's +1 new test)
  3. Dedicated widget test using a tall custom viewport (tester.view.physicalSize, mirrors
     store_screen_test.dart's pattern) so both a Drop and Pop post plus the divider between
     them stay inside ListView's cache extent simultaneously without scrolling -- confirms
     exactly 1 Divider renders between 2 posts.
  4. Manual read of home_drop_card.dart/home_pop_card.dart -- confirmed untouched (git diff
     scoped to home_feed_screen.dart + test file only).
  5. grep for new Card/BoxShadow/ClipRRect in the diff -- none found.
Passed: 5/5
Failed: 0
Severity: N/A
Recommendation: Approve. Move DS-003 to .wyn/tasks/approved/. Continue to DS-004 (Drop --
  image-first) next per DS-001's 8-part rollout order.
Final Status: PASS
```
