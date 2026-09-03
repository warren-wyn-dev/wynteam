# Design Task — WYN-108

Status: backlog (Founder เลือกทรงแล้ว รอ WYN-107 merge ก่อนเริ่ม — ทั้งสองงานแตะไฟล์การ์ดเดียวกัน)
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
