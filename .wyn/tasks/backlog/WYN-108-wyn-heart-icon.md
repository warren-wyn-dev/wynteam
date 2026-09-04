# Design Task — WYN-108

Status: review (เขียนเสร็จแล้ว 2026-09-04 · analyze สะอาด · test 1188/1188 · รอ AI QA ตรวจ)
Owner: AI Design → AI Coding
Screen: ทุกจุดในแอปที่วาดหัวใจถูกใจ (13 ไฟล์)
Purpose: เปลี่ยนทรงหัวใจทั้งแอปเป็นทรง lucide ตามไฟล์อ้างอิง — ต้นเหตุคือ 01-home.tsx ใช้ไอคอน lucide
แต่ตอน implement ใช้ Icons.favorite ของ Material ซึ่งคนละทรง
User Flow: ไม่เปลี่ยน
Components: WynHeartIcon (CustomPainter, ไม่เพิ่ม dependency) — ดูสเปคเต็มที่
`.wyn/docs/design/wyn-108-wyn-heart-icon.md`
Interactions: ไม่เปลี่ยน
States: ถูกใจแล้ว = ทึบสีแดง / ยังไม่ถูกใจ = เส้นสี graphite (เหมือนเดิมทุกค่า)
Responsive Behavior: ไม่กระทบ
Accessibility: ไม่กระทบ (ใส่ ExcludeSemantics ให้ CustomPaint)
Design Rules: หัวใจถูกใจทั้งแอปต้องใช้ WynHeartIcon ตัวเดียวกันเสมอ ห้ามใช้ Icons.favorite อีก
Handoff:
1. สร้าง app/lib/core/widgets/wyn_heart_icon.dart
2. ไล่เปลี่ยน 13 จุด (ตรวจ 2 ไฟล์ settings ก่อนว่าเป็นหัวใจถูกใจจริงไหม ถ้าไม่ใช่ห้ามแตะ)
3. แก้เงื่อนไข pop animation ใน action_metric.dart ให้ยังทำงาน (สำคัญ ห้ามให้ animation หาย)
4. widget test 2 สถานะ + animation
5. ห้ามแตะ pop_clip_view.dart / pop_comment_sheet.dart (ยังอยู่ใต้กติกา Pop freeze)

---

## QA & Security — รอบ 1 (2026-09-04)

**Final Status: FAIL**

ผ่าน: animation pop ยังเล่นเมื่อ `likedByMe` เปลี่ยน (เปลี่ยนตัวเทียบเป็น `iconState` ทำถูก) ·
หัวใจ double-tap ยังมีเงา สีขาว ขนาด 72 · สีทุกสถานะครบ 11 จุดไม่เปลี่ยน ·
ไฟล์ Pop 2 ไฟล์ไม่ถูกแตะ · ไอคอนหัวข้อเมนูใน settings ไม่ถูกแตะ

**บั๊ก B-108-1 (Major)** — หัวใจข้างคอมเมนต์ในหน้า Drop Detail โตจาก 16px เป็น 24px
(`drop_detail_screen.dart:1239-1247` — `IconButton.iconSize: 16` ไม่มีผลกับ widget ที่ระบุ `size` เอง)
ใบ bug: `.wyn/tasks/bugs/WYN-108-comment-heart-size-regression.md`

Minor: ปุ่มรีโพสต์ได้ pop animation ที่เดิมไม่มี · ไม่ได้ใส่ `ExcludeSemantics` ตามที่ spec สั่ง (ไม่มีผลจริง)

รายงานเต็ม: `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa.md`
