# Product Task — WYN-175

Status: design (spec + preview ready, route transition รอ Founder เลือก A/B)
Owner: AI Product Manager → AI Design (ดู `.wyn/docs/design/wyn-175-perceived-speed-motion.md`)
Feature: WYNOS Web Beta1 — Perceived Speed & Motion (WYN-174 Track 1, Founder เลือก 2026-09-19)
Goal: ทำให้การใช้งาน `wynos.online` รู้สึกเหมือนแอปมือถือ native มากที่สุด ด้วยการเปลี่ยนจากการสลับหน้าแบบ instant/snap เป็นมี motion, และแทน spinner/blank loading ด้วย skeleton state + press feedback ที่ตอบสนองทันทีเมื่อแตะ
Target User: ผู้ใช้ WYNOS ทั่วไปที่เข้าเว็บผ่านมือถือ (iOS Safari/Android Chrome) เป็นหลัก
Problem: (แก้ไขจาก audit เดิม — ดู DECISIONS.md 2026-09-19 "AI Design ตรวจโค้ดจริง") ที่จริง `PageTransition` และ skeleton system มีอยู่แล้ว (ใช้ใน Home/Profile/Chat) ช่องว่างจริงมีแค่: (1) Search/Notifications ยังใช้ spinner แทน skeleton (2) การ์ด/แถวบางจุดยังไม่มี press feedback (3) route transition ปัจจุบันตั้งใจให้เบามาก (fade 70ms) — ต้องให้ Founder ตัดสินใจว่าจะคงไว้หรือเพิ่ม motion ให้ชัดขึ้น

## ขอบเขต (3 ส่วนย่อย)

1. **Route/page transition animation** — เปลี่ยนหน้าใน Next.js router (เช่น Home → Profile, เปิด Post detail, เปิด Chat conversation) ต้องมี motion แบบ native (slide-in/fade คล้าย iOS push/pop หรือ Android shared-axis) แทนการ snap ทันที
   - Budget performance: < 300ms, ใช้ CSS transform/opacity เท่านั้น ห้ามใช้ JS-heavy animation ที่กระทบ frame rate บนมือถือรุ่นล่าง
   - ต้อง respect `prefers-reduced-motion`
2. **Skeleton loading state มาตรฐานทั้งระบบ** — แทนที่ spinner/blank ด้วย skeleton placeholder (โครงร่าง content คร่าวๆ) ระหว่างรอข้อมูลจาก Supabase ในหน้าหลักที่มี data fetch: Home feed, Profile, Chat list/conversation, Search, Notifications, Club
3. **Micro-interaction press feedback** — ปุ่ม/การ์ด/รายการที่กดได้ทั้งระบบ ต้องมี visual feedback ทันทีเมื่อแตะ (เช่น scale-down เล็กน้อย/opacity เปลี่ยน) ก่อนที่ action จริงจะเกิดขึ้น — ให้ความรู้สึก responsive แบบ native

## Requirements

- ไม่เปลี่ยน business logic, data fetching contract, Supabase Auth/RLS/RPC ใดๆ — เป็นงาน presentation layer ล้วนๆ
- ใช้ design system/shared component ที่มีอยู่ (`design-system.css` และ token ที่ WYN-141/WYN-163 วางไว้) ไม่สร้าง pattern ใหม่ซ้ำซ้อน
- Reuse ของเดิมที่มีอยู่แล้วก่อนสร้างใหม่ (เช่น `overscroll-behavior`/`tap-highlight` pattern ที่มีอยู่แล้วหลายไฟล์ CSS)
- ไม่แตะ WYN-163 (visual redesign สี/ทรงปุ่ม) ที่ยัง in-progress — งานนี้คือ motion/timing ไม่ใช่สี/ทรง
- ทดสอบบน physical iPhone Safari จริงก่อนถือว่า done (บทเรียนจาก WYN-158: CI เขียว ≠ ใช้งานได้จริงบนอุปกรณ์จริง)

## Acceptance Criteria

- [ ] เปลี่ยนหน้า (Home/Profile/Chat/Post detail อย่างน้อย) มี transition ที่เห็นชัด ไม่ snap ทันที, วัดเวลา animation < 300ms
- [ ] `prefers-reduced-motion: reduce` ปิด/ลด animation ให้เหลือ fade สั้นๆ หรือไม่มี animation เลย
- [ ] Home feed, Profile, Chat list, Search, Notifications อย่างน้อย มี skeleton loading แทน spinner/blank เดิม
- [ ] ปุ่ม primary/secondary และการ์ดที่กดได้ (post card, chat list item) มี press feedback ที่สังเกตเห็นได้ภายใน 1 frame ของการแตะ
- [ ] ไม่มี regression ต่อ business logic เดิม (lint/typecheck/build ผ่าน, browser smoke test ผ่าน)
- [ ] Founder เห็น mockup/preview ของ motion ก่อน AI Coding เริ่ม implement จริง (ตามกติกาถาวร "UI ใหม่ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด" — สำหรับ motion อาจเป็นวิดีโอ/GIF preview แทนภาพนิ่ง)

## Dependencies

- ต่อยอดจาก WYN-158 (mobile app feel foundation: PWA, gesture, touch-target) — ไม่ทำซ้ำสิ่งที่มีอยู่แล้ว
- ไม่ block และไม่ถูก block โดย WYN-163 (คนละ layer: motion vs. color/shape)

## Priority

P0 — Founder ยืนยันให้เริ่ม track นี้ก่อนใน WYN-174 (2026-09-19)

## Risks

- Animation ที่ทำไม่ดีอาจทำให้ perceived performance แย่ลงแทนที่จะดีขึ้น (โดยเฉพาะมือถือรุ่นล่าง) — ต้องทดสอบจริงบนอุปกรณ์ ไม่ใช่แค่ desktop browser
- Skeleton loading ถ้าออกแบบไม่ตรงกับ layout จริงของ content จะเกิด layout shift ตอนข้อมูลโหลดเสร็จ (ต้องออกแบบ skeleton ให้ขนาด/ตำแหน่งตรงกับ content จริง)
- Scope อาจ creep ไปทุกหน้าในระบบถ้าไม่ล็อกรายการหน้าที่ทำรอบแรกให้ชัด (ล็อกไว้ที่ Home/Profile/Chat/Search/Notifications ก่อนตาม Acceptance Criteria)

## Recommendation

ส่งต่อ **AI Design** ทำ audit หน้าที่ต้องมี transition/skeleton/press-feedback ทั้งหมด + ทำ motion spec (timing, easing, reduced-motion behavior) และ mockup/preview ให้ Founder อนุมัติก่อนส่ง AI Coding

## Handoff

→ **AI Design**: ทำ audit + motion spec + preview สำหรับ route transition, skeleton loading, press feedback ตามขอบเขตนี้ ก่อนส่งต่อ AI Coding
