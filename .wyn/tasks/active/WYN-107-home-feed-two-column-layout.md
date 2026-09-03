# Design Task — WYN-107

Status: active (Founder อนุมัติโครงแล้ว 2026-09-03 — "ชอบแบบนี้" · เหลือ 2 คำถามค้างก่อนส่งโค้ด)
Owner: AI Design → AI Coding
Screen: `HomeDropCard` (ฟีด Home ทุกแท็บ, 3 แท็บ Profile, hashtag feed) — `HomePopCard` รอ Founder ตัดสิน
Purpose: เปลี่ยนการ์ดโพสต์จาก stack เต็มความกว้าง เป็นสองคอลัมน์ (avatar ซ้าย / เนื้อหาขวา) ให้ทุกอย่าง
เริ่มตรงแนวชื่อผู้โพสต์ ตาม `design-reference/01-home.tsx` ที่อนุมัติไว้แล้วแต่ยังไม่ได้ทำตาม
User Flow: ไม่เปลี่ยน — ทุก gesture/ปุ่มทำงานเหมือนเดิม เปลี่ยนเฉพาะตำแหน่งการวาง
Components: ดูผังเต็มที่ `.wyn/docs/design/wyn-107-home-feed-two-column-layout.md`
Interactions: ไม่เปลี่ยน
States: ไม่มี state ใหม่ · สีทุกสถานะคงเดิม (หัวใจแดง / รีโพสต์ sapphire / ที่เหลือ graphite)
Responsive Behavior: ต้องทดสอบที่จอ 360 (คอลัมน์เนื้อหาเหลือ 282) และ textScale 130%
Accessibility: ไม่กระทบ — Semantics เดิมทั้งหมด, touch target แถวปุ่มยังคง 44px
Design Rules:
- ทุก section ในคอลัมน์เนื้อหาเริ่มที่แนวเดียวกัน (x=78 บนจอ 390)
- ล้นได้เฉพาะขอบขวา ห้ามล้นขอบซ้าย
- ห้ามทำตามไฟล์อ้างอิง 6 จุดที่ Founder สั่งเปลี่ยนไปแล้ว (สีหัวใจ/แถวปุ่ม/แท็บ/ไอคอนแชท/ฟอนต์/สีพื้น)
Handoff:
1. `home_drop_card.dart` — เปลี่ยนโครงเป็น Row(avatar, Expanded(Column)) ย้าย padding แนวนอนเป็น
   right:24 ต่อ section เว้นเฉพาะแถวรูป
2. `PostImageCarousel` — เปลี่ยนฐานที่คูณ 82% จากความกว้างจอ เป็นความกว้างคอลัมน์เนื้อหา
3. `PostImageFrame` (รูปเดียว) — เพิ่มมุมโค้ง 16 (ระวังกระทบ Drop Detail ที่ใช้ร่วมกัน)
4. อัปเดต widget/golden test ที่ผูกกับตำแหน่ง pixel
5. `flutter analyze` + `flutter test` ผ่านครบ

คำตอบจาก Founder (2026-09-03):
1. `HomePopCard` — **แก้ด้วย** "ให้ทั้งฟีดหน้าตาเหมือนกัน" (ข้อยกเว้นเฉพาะไฟล์นี้ ไฟล์ Pop อื่นห้ามแตะ)
2. ทรงหัวใจ — **แบบ B (lucide)** แยกเป็น WYN-108 ทำหลังงานนี้ merge
