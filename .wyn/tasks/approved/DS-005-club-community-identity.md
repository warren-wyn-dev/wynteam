# Product Task — DS-005

Status: approved (QA — PASS, 2026-08-16) — 5th ของ 8 เฟส (DS-001 → ... → DS-004 → **DS-005** → DS-006 → DS-007 → DS-008)
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (PASS)

Feature: Club — community identity

Goal: ตรวจสอบว่า Club มี community identity ที่ชัดเจน (cover/avatar, role badge, pin indicator, card-less) ตามที่ DS-001's Recommendation ตั้งชื่อ task นี้ไว้ และปิดช่องว่างที่พบจริง

Target User: ผู้ใช้ WYN ที่เข้าร่วม/สร้าง Club

## Audit ผล

เหมือน DS-004: Club มี community identity ครบตั้งแต่ WYN-014/WYN-015 อยู่แล้ว (cover+avatar header, role badge, pin indicator, card-less rows ทั้งหมด — ดูตารางเต็มใน `.wyn/docs/design/ds-005-club-community-identity.md`) ช่องว่างจริงที่พบมีจุดเดียว: **Club Posts tab ยังไม่มีเส้นคั่นระหว่างโพสต์** ทั้งที่เป็น chronological feed แบบเดียวกับ Home Feed ที่ DS-003 เพิ่งกำหนดภาษาภาพไปแล้ว

Requirements:
R1. เพิ่ม `Divider(height: 1)` ระหว่างโพสต์ใน Club Posts tab (mirror DS-003's Home Feed diff เป๊ะ)

Acceptance Criteria:
- [x] Club Posts tab มีเส้นคั่นบางระหว่างโพสต์ สอดคล้องกับ Home Feed
- [x] ไม่แตะ `club_post_card.dart` หรือรายการ entity-browse อื่น (My Clubs/Explore Clubs)
- [x] `flutter analyze`/`flutter test` ผ่านสะอาด

Dependencies: DS-003 (กำหนดภาษาภาพ divider), DS-004

Priority: กลาง

Risks: ต่ำ — diff 1 ไฟล์ mirror pattern ที่ผ่าน QA แล้วจาก DS-003

Recommendation: อนุมัติ ไปต่อ DS-006 (Profile + Search)

Handoff: เสร็จสมบูรณ์ ดู Coding Output/QA Verification ด้านล่าง

---

## Coding Output

- `app/lib/features/club/presentation/widgets/club_posts_tab.dart`: `ListView.builder` → `ListView.separated`, `separatorBuilder` คืน `Divider(height: 1)` ระหว่างโพสต์จริงเท่านั้น (mirror `home_feed_screen.dart` DS-003 diff)
- `app/test/club_posts_tab_test.dart`: เพิ่ม 1 test ยืนยันมีเส้นคั่น 1 เส้นระหว่าง 2 โพสต์

## QA Verification (2026-08-16)

```
Feature: DS-005 Club Posts tab hairline divider
Environment: Local Flutter (app/), same branch tip
Test Cases:
  1. flutter analyze -- No issues found
  2. flutter test (full suite) -- 285/285 PASS (was 284 before this task's +1 new test)
  3. Dedicated widget test confirms exactly 1 Divider between 2 posts (no giant-image
     virtualization issue here since Club post test fixtures have no images).
  4. grep confirms zero Card/BoxShadow/elevation anywhere in Club presentation code --
     community identity achieved without any card artifacts, matching DS-003/DS-004's
     established pattern.
  5. Confirmed club_post_card.dart untouched (diff scoped to club_posts_tab.dart + test only).
Passed: 5/5
Failed: 0
Recommendation: Approve. Move DS-005 to .wyn/tasks/approved/. Continue to DS-006
  (Profile + Search) next.
Final Status: PASS
```
