# Design Task — WYN-140

Status: active (Design เสร็จ, รอ Founder ดู mockup + ตอบคำถามก่อนส่ง AI Coding)
Owner: AI Design
Screen: Home Feed (Header, Feed Tabs, Post Card, Action Bar, Media, Bottom Nav/Drop Button, Loading)
Purpose: ยกระดับ UX/UI ของหน้า Home ให้มีคุณภาพระดับ Production/Premium ตามบรีฟละเอียดของ Founder
  (2026-09-08) โดยล็อกโครงสร้างโพสต์เดิมของ WYN-107 ไว้ทั้งหมด — ปรับเฉพาะ spacing/typography rhythm/
  animation/interaction detail
User Flow: ไม่มี flow ใหม่ในภาพรวม — ปรับรายละเอียดของ flow เดิม (ดูแต่ละ Screen block ในเอกสารดีไซน์)
Components: Post Card (avatar/name/badge/time/caption/hashtag/media/action bar), Header, Feed Tabs,
  Action Metric, Media Frame, Bottom Nav, Drop Button, Home Feed Skeleton
Interactions: ดูรายละเอียดครบใน design doc — สรุปคือ animate tab indicator, press-scale Drop button,
  image fade-in, spacing rhythm ใหม่
States: ไม่เปลี่ยน state ที่มีอยู่แล้ว — เพิ่ม transition state ระหว่าง animate เท่านั้น
Responsive Behavior: ทดสอบ 320/375/390/430px ตามมาตรฐานเดิมของโปรเจกต์ — ไม่มี breakpoint ใหม่
Accessibility: ไม่ลด touch target/Semantics ที่มีอยู่แล้วแม้แต่จุดเดียว — ตรวจซ้ำหลังปรับ spacing
Design Rules: ใช้ token สี/spacing/motion เดิม 100% ไม่มี token ใหม่ — ดู 2 จุดที่บรีฟอ้างข้อมูลเก่ากว่าโค้ด
  จริง (สี Cyan เก่า vs Sapphire จริง, hashtag แยกบรรทัด vs inline จริง) ในเอกสารดีไซน์ก่อนเริ่ม implement
Handoff: แบ่ง Phase 1 (ปลอดภัย พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติภาพ) / Phase 2 (feed tab swipe,
  custom pull-to-refresh animation — ต้องอนุมัติ scope เพิ่มแยกต่างหาก เพราะเป็นฟีเจอร์ใหม่ไม่ใช่รายละเอียด)
  — ดูตารางเต็มใน `.wyn/docs/design/wyn-140-home-feed-premium-polish.md`

## เอกสารเต็ม

`.wyn/docs/design/wyn-140-home-feed-premium-polish.md`

## รออะไรอยู่

1. Founder ดู Artifact mockup (Before/After รวม Phase 1 ทั้งหมด) แล้วอนุมัติ
2. Founder ตอบคำถาม: (ก) สี Sapphire (ปัจจุบัน) หรือ Cyan (ตามบรีฟ) — เอกสารนี้ใช้ Sapphire เพราะเพิ่ง
   ยืนยันในเซสชันนี้เอง (ข) hashtag inline (ปัจจุบัน) หรือแยกบรรทัด (ค) Drop button ควรมี haptic ไหม
   (ขัดกับกติกา DS-010 ที่ล็อกไว้ว่า "กด + ใน Bottom Nav ไม่ต้องมี haptic") (ง) เริ่ม Phase 2 (swipe/
   custom pull animation) เลยไหม หรือทำ Phase 1 ก่อนแล้วค่อยว่ากัน
3. หลังตอบครบ → ส่งต่อ AI Coding (Phase 1 เท่านั้น เว้นแต่ Founder สั่ง Phase 2 ด้วย)
