# Design Task — WYN-111

Status: approved (QA รอบ 2 ผ่าน 2026-09-05 — ดู `.wyn/docs/qa/wyn-110-111-round2-qa.md` — ส่งต่อ AI
Deploy & DevOps)
Owner: AI Design → AI Coding
Screen: `PostImageCarousel` (`core/widgets/post_media.dart`) — ใช้ร่วมกัน 3 หน้า: การ์ดฟีด Home,
Drop Detail, Club
Purpose: ทำให้รูปตรงกลาง/กำลังดูเด่นกว่ารูปข้างเคียงระหว่างเลื่อน (เหมือน Threads ในคลิปที่ Founder ส่งมา)
โดยไม่แตะ physics การ snap/fling/รายงาน index ที่มีอยู่แล้ว
User Flow: ไม่เปลี่ยน
Components: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-111-carousel-center-emphasis.md`
Interactions: ไม่เปลี่ยน
States: ไม่มี state ใหม่
Responsive Behavior: ทดสอบ 320/390/430
Accessibility: ไม่กระทบ
Design Rules: ห้ามเปลี่ยนขนาดการ์ดที่จุดพัก (82% เดิม) ห้ามแตะ physics/stride เดิม ห้ามแตะ caller ทั้ง 3 จุด
Handoff:
1. เพิ่ม `Transform.scale` ต่อการ์ดใน `PostImageCarousel` คำนวณจากระยะห่างจากตำแหน่งเลื่อนปัจจุบัน
2. เทสต์เดิม 5 ตัวต้องผ่านไม่ต้องแก้ + เพิ่มเทสต์ใหม่คุมพฤติกรรม scale
3. flutter analyze + flutter test ผ่านครบ

---

## COMPLETED — 2026-09-05

Deploy ขึ้น production 2 รอบ: รอบแรก (workflow run #64, commit `ee917d1`) และรอบแก้บั๊กช่องขาว/bounce
ที่ Founder เจอจากคลิปหลัง deploy รอบแรก (workflow run #65, commit `95c1653`, PR #230) **Founder
ยืนยันด้วยตาแล้วว่าใช้งานได้จริงบน `wynos.online`** ("โอเคแล้ว")

Deployment log: `.wyn/logs/deployments/2026-09-05-wyn-110-111-real-deploy.md`

---

## Follow-up bug found after "COMPLETED" — 2026-09-05

Founder เจอบั๊กเพิ่มอีกจุดหลังจากยืนยัน "โอเคแล้ว" ข้างบน: รูปที่เลื่อนผ่านไปแล้วไม่ peek โผล่มาทางซ้าย
เลย (หายไป 0px ต่างจากช่องขาวที่แก้ไปรอบก่อนหน้า) — แก้แล้วใน PR #231 (commit `d5ecc41`) deploy ขึ้น
production แล้ว (workflow run #66) **รอ Founder ยืนยันซ้ำ** ก่อนถือว่าปิดสนิทจริง ๆ

รายละเอียดเต็ม: `.wyn/logs/deployments/2026-09-05-wyn-110-111-real-deploy.md` หัวข้อ "Deploy รอบที่ 3"

---

## Round 3 verified — 2026-09-05

Founder ยืนยันด้วยคลิปสกรีนเรคคอร์ดจริงจาก `wynos.online` แล้ว (10:28 UTC) — รูปก่อนหน้ายัง peek
โผล่มาทางซ้ายตามที่แก้ใน PR #231 ครบทุกจุด (ซ้าย/ขวา peek + ไม่มีช่องขาว) ปิดงานสมบูรณ์ทั้ง 3 รอบของ
carousel fix แล้ว

---

## Round 4 — round 3 reverted per Founder request — 2026-09-05

Founder เห็น production จริงของ round 3 (left-peek) แล้วไม่ชอบ (มุมโค้ง 16px กินพื้นที่ peek แคบๆ
จนเห็นพื้นขาว) หลังดูตัวอย่างเปรียบเทียบแล้วยังไม่เข้าใจ Founder ชี้แจงใหม่ว่าต้องการแค่ "ให้รูปแรกที่
เลื่อนดู ไปสุดอีกฝั่งหนึ่งเฉยๆ" — คือรูปที่ผ่านไปแล้วให้เลื่อนหายไปเลย ไม่ต้องมี peek ค้าง

Revert PR #231 ทั้งหมดใน PR #233 (commit `f0b4608`) — กลับไปพฤติกรรมของ round 2 (ไม่มีช่องขาว +
bounce ปลายแถว ยังอยู่ครบ) deploy แล้ว (workflow run #68) **รอ Founder ยืนยันซ้ำบน production**

รายละเอียดเต็ม: `.wyn/logs/deployments/2026-09-05-wyn-110-111-real-deploy.md` หัวข้อ "Deploy รอบที่ 4"
