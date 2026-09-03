# Design Task — WYN-106

Status: active (Founder อนุมัติแล้ว 2026-09-03 ผ่าน popup เลือก "อนุมัติ ส่ง AI Coding แก้เลย" — ส่งต่อ AI Coding)
Owner: AI Design
Screen: `HomeFeedScreen` และ widget ลูกทั้งหมด (`HomeExplainerBanner`, `NewPostsPill`,
`SuggestedFollowList`/`FollowActionButton`, `HomeDropCard`/`HomePopCard` + `ActionMetric`)
Purpose: รวมปุ่มทุกแบบบนหน้าจอ Home เป็นระบบเดียว (6 ประเภท) ยืนยันว่าใช้ token สีเดิมชุดเดียวกันครบ
ไม่มีสีใหม่ พร้อมชี้ 1 gap จริงเรื่อง touch target ที่ต่ำกว่าเกณฑ์ระบบเอง
User Flow: ไม่เปลี่ยน — ทุกปุ่มทำงานเหมือนเดิม เอกสารนี้เป็นชั้นรวบรวม/ตรวจสอบ ไม่ใช่ฟีเจอร์ใหม่
Components: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-106-home-button-system.md`
Interactions: ไม่เปลี่ยน
States: ดูรายละเอียดเต็มที่เอกสาร design + Artifact preview ("Home Button System")
Responsive Behavior: ไม่กระทบ (mobile-first, px คงที่)
Accessibility: พบ 1 gap — ปุ่ม X ปิด `HomeExplainerBanner` พื้นที่กด ~19×19px ต่ำกว่าเกณฑ์ 44×44px
Design Rules: ดูเอกสาร design เต็ม — ห้ามเพิ่มประเภทปุ่มใหม่นอก 6 แบบที่ระบุโดยไม่ทวนกับ Founder ก่อน
Handoff:
1. รอ Founder ยืนยันผ่าน Artifact preview ก่อน
2. เมื่ออนุมัติ → ส่ง AI Coding แก้ `home_explainer_banner.dart` (ขยาย touch target ปุ่ม X เป็น
   44×44 แบบเดียวกับ `action_metric.dart`, ไม่กระทบภาพที่เห็น) + เพิ่ม widget test ยืนยันขนาด hit-test
3. ข้อสังเกตรอง (ไม่เร่งด่วน, รอ Founder ตัดสินใจ): ไอคอน "⋯" ใน `home_drop_card.dart` ไม่ระบุ
   size/color ชัดเจนตาม `design-reference/SPEC.md` §4.6 (16px, faint) — touch target ผ่านอยู่แล้ว
