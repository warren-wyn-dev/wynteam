# Product Task — DS-008

Status: approved (QA — PASS, 2026-08-16) — 8th และเฟสสุดท้ายของ 8-part design system rollout (DS-001 → DS-002 → DS-003 → DS-004 → DS-005 → DS-006 → DS-007 → **DS-008**) — **ปิด item 8 ที่ Founder สั่งทำครบทั้งหมด**
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (PASS)

Feature: Responsive + accessibility + known-issue closeout

Goal: ปิดของค้าง 3 เรื่องที่ DS-002 เว้นไว้ตั้งแต่ต้น (touch-target audit, 70 micro-spacing literal, known issue) บวกกับ audit เรื่อง responsive ที่ DS-001 เคยพบเป็นช่องว่าง

Target User: ผู้ใช้ WYN ทุกกลุ่ม (โดยเฉพาะผู้ใช้ที่พึ่งพา touch target ที่แม่นยำ — WCAG 2.5.5)

Requirements/Acceptance Criteria: ดูรายละเอียดเต็มใน `.wyn/docs/design/ds-008-responsive-accessibility.md`

สรุปผล:
- [x] Touch-target audit: พบ 8 จุดต่ำกว่า 44px, แก้ไป 6 จุด (`app/`), เว้น 2 จุดใน Pop feature ตามกติกา suspended-feature protection ของ DS-001 เอง
- [x] 70 micro-spacing literals: ตัดสินใจแล้ว (ยอมรับเป็นข้อยกเว้นที่ตั้งใจ ไม่บังคับเข้า 4px grid) — ปิด item อย่างเป็นทางการ ไม่ใช่ปล่อยค้าง
- [x] StoreScreen overflow: ยืนยันปิดแล้วตั้งแต่ต้นเซสชัน (ZOKY-004)
- [x] Responsive tablet/desktop: audit ยืนยันสถานะเดิม ตัดสินใจไม่สร้างใหม่ในรอบนี้ (นอกขอบเขต mobile-first, ไม่มี requirement จาก Founder) — เก็บเป็นคำถามเปิด

Dependencies: DS-001 ถึง DS-007 ทั้งหมด

Priority: กลาง-สูง (accessibility fix มีผลจริงต่อผู้ใช้)

Risks: ต่ำ — touch-target fix เป็นการขยาย SizedBox เท่านั้น ไม่แตะ logic ยืนยันด้วย `flutter analyze`/`flutter test` เต็มชุด

Recommendation: อนุมัติ — **item 8 (DS-003 ถึง DS-008) เสร็จสมบูรณ์ครบทุกเฟสแล้ว**

Handoff: ไม่มีงานต่อในสาย DS-XXX รอบนี้ — เหลือ 2 คำถามเปิดให้ Founder ตัดสินใจถ้าต้องการ: (1) push notification จริงสำหรับ order (ค้างจาก ZOKY-005) (2) responsive tablet/desktop (ค้างจาก DS-008)

---

## Coding Output

- `club_post_detail_screen.dart`, `drop_detail_screen.dart` (×2), `club_section.dart`: ขยาย `SizedBox` ที่ห่อปุ่ม/element ที่กดได้จาก 28-36px เป็น `WynSpacing.touchTargetMin` (44px)
- `drop_detail_screen_test.dart`: เพิ่ม assertion วัดขนาดจริงของปุ่ม "ติดตาม" ในเทสเดิม + เทสใหม่ 1 ชุดวัดขนาดปุ่มลบ/ถูกใจคอมเมนต์
- ไม่แตะไฟล์ Pop ใดๆ (ตามกติกา DS-001 Risk R3)
- ไม่มีการแก้ไข micro-spacing literal (ตัดสินใจเก็บไว้ตามเดิม พร้อมเหตุผลบันทึกไว้)
- ไม่มีการสร้าง responsive layout ใหม่ (ตัดสินใจไม่ทำ พร้อมเหตุผลบันทึกไว้)

## QA Verification (2026-08-16)

```
Feature: DS-008 touch-target fixes + micro-spacing/responsive decisions
Environment: Local Flutter (app/), same branch tip
Test Cases:
  1. flutter analyze -- No issues found.
  2. flutter test (full suite) -- 289/289 PASS (was 288 before this task's +1 new test).
  3. Dedicated regression tests confirm the Follow button and per-comment delete/like
     buttons in DropDetailScreen now measure >=44px in both dimensions (were 30px/32px).
  4. Verified via grep that zero files under app/lib/features/pop/ were touched --
     complies with DS-001's suspended-feature protection (Risk R3).
  5. Verified seller_app/ has zero touch-target violations of this pattern (grep found
     none) -- no changes needed there.
  6. Confirmed ZOKY-004 (StoreScreen overflow) is already closed from earlier in this
     session (.wyn/tasks/bugs/ZOKY-004-store-header-rating-row-overflow.md, PASS).
Passed: 6/6
Failed: 0
Recommendation: Approve. Move DS-008 to .wyn/tasks/approved/. This closes out the
  full 8-part design system rollout DS-001's Recommendation proposed on 2026-08-16 --
  Founder's "ทำข้อ7-8-9" instruction is now fully satisfied across all sub-items.
Final Status: PASS
```
