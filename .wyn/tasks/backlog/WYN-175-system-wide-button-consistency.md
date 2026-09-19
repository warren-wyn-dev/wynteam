# Product Task — WYN-175

Status: merged into WYN-160 (Founder ตัดสินใจ 2026-09-19 — "รวมเข้ากับ WYN-160 เป็นงานเดียว") — เก็บไฟล์นี้
ไว้เป็น reference/audit trail เท่านั้น ดูงานจริงที่ `.wyn/tasks/active/WYN-160-web-design-system-consolidation.md`
Owner: AI Product Manager
Feature: ปุ่มทั้งระบบเว็บไปในทิศทางเดียวกัน (System-wide Button Consistency)

Goal: ผู้ใช้เห็นปุ่มแบบเดียวกัน (ขนาด, สี, มุมโค้ง, การตอบสนองตอนกด) ในทุกหน้าของ WYNOS Web ไม่ว่าจะเป็น
ปุ่มที่สร้างเมื่อไหร่หรือใครเป็นคนทำ — ลด "ความรู้สึกทำมาไม่ครบ" ที่ QA เคยจับได้ในงานก่อนหน้า
(ดู `.wyn/learning/LESSONS_LEARNED.md` entry เรื่อง auth-reference.css shared class)

Target User: ผู้ใช้ WYNOS Web ทุกคน (ทุกหน้าจอที่มีปุ่ม)

Problem: สำรวจโค้ดจริงพบว่ามี class ที่เกี่ยวกับปุ่ม/action control **~72 ตัว** กระจายอยู่ใน CSS ไฟล์ต่างๆ
ของ `web/app/*.css` สร้างขึ้นทีละหน้าจอ/ทีละ task ตลอดหลายเดือน — มี design system เอกสารอยู่แล้ว
(`wynos-web-base-design-system.md`: primary black/outline, pill 999px หรือ rounded 12px, สูง 50px ปกติ/
44px compact) แต่**ไม่มีการบังคับใช้ (enforcement) จริง** ทำให้เกิดความไม่ตรงกันหลายมิติ:

1. **Press feedback ไม่ทั่วถึง**: มีแค่ 5 ไฟล์ CSS ที่มี `:active` state, มีแค่ 3 ไฟล์ที่ใช้ motion token
   `scale(0.96)` (คิดค้นใน WYN-169/170 สำหรับ Chat Inbox เท่านั้น) — ปุ่มส่วนใหญ่ในระบบกดแล้วไม่มี feedback
   ใดๆ เลย
2. **สี danger/accent ไม่สม่ำเสมอ**: พบระหว่าง WYN-174 ว่าปุ่ม delete บางจุดใช้ hardcode hex (`#d33c32`
   ใน `wyn-note-delete`) บางจุดใช้ token `var(--wyn-accent)` (`#e0203d`) — คนละสีกันสำหรับ "การกระทำแบบ
   เดียวกัน" (destructive action)
3. **Border-radius/ขนาดหลุดสเปก**: WYN-160 (backlog เดิม) เคยสำรวจแล้วว่ามี border-radius ~20 ค่าทั่วระบบ
   ทั้งที่ spec กำหนดไว้แค่ 5 ระดับ — ปุ่มเป็นหนึ่งใน component ที่หลุดสเปกบ่อยที่สุด
4. **Touch target ไม่คงที่**: บางปุ่ม (เช่น `.wyn-note-delete` ที่เพิ่งเจอ) สูงแค่ 36px ต่ำกว่ามาตรฐาน
   DS-008 (44px) บางปุ่มไม่กำหนด min-height เลย

## Requirements

1. กำหนด **Button Interaction Spec** เพิ่มเข้าไปใน `wynos-web-base-design-system.md` (ต่อยอดของเดิม
   ไม่ใช่เขียนใหม่) ให้ครอบคลุม:
   - Sizing scale ที่มีอยู่แล้ว (50px/44px) + compact variant สำหรับปุ่ม text-link (เช่น "ลบรูปโปรไฟล์")
   - Motion token มาตรฐาน: `transform: scale(0.96)` บน `:active`,
     `transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1)` (ใช้ formula เดิมที่พิสูจน์แล้วจาก
     WYN-169/170/171) + `@media (prefers-reduced-motion: reduce)` เสมอ
   - Danger/destructive variant ที่ใช้ token เดียว (`var(--wyn-accent)`) ไม่ hardcode hex อีก
   - Touch target ขั้นต่ำ 44px สำหรับปุ่มที่เป็น primary action, ผ่อนได้เฉพาะปุ่ม text-link รองที่ไม่ใช่
     primary action (ต้องระบุเกณฑ์ชัดว่าอันไหนเข้าข่ายยกเว้น)
2. Audit ปุ่มทั้ง ~72 class ทั่วระบบ จัดกลุ่มเป็น: (a) ตรงสเปกอยู่แล้ว (b) หลุดสเปกเล็กน้อย แก้ token
   อย่างเดียวได้ (c) หลุดสเปกมาก ต้องออกแบบใหม่ (d) จงใจต่างจากสเปก (มีเหตุผลเฉพาะทาง — ต้องบันทึกเหตุผลไว้
   ไม่ใช่แค่มองข้าม)
3. Rollout เป็นเฟส แยกตาม risk/traffic ไม่ทำทีเดียวทั้งระบบ (ดู Priority ด้านล่าง)

## Acceptance Criteria

- ปุ่ม primary action ทุกปุ่มในหน้าที่ rollout แล้วมี `:active` press feedback ด้วย motion token มาตรฐาน
  เดียวกัน (เว้นแต่ `prefers-reduced-motion`)
- ไม่มีปุ่ม danger/destructive ที่ hardcode สีแยกจาก `var(--wyn-accent)` ในหน้าที่ rollout แล้ว
- Border-radius ของปุ่มในหน้าที่ rollout แล้วตรงกับ 5 ระดับตามสเปก WYN-160 เท่านั้น
- Touch target ของปุ่ม primary action ทุกปุ่ม ≥44px ในหน้าที่ rollout แล้ว
- WCAG AA contrast ผ่านทั้ง light/dark mode ทุกปุ่มที่แก้ (ใช้วิธีวัด contrast จริงตามที่ QA ใช้มาตลอด
  ไม่ใช่ดูด้วยตา)
- ปุ่มที่ "จงใจต่างจากสเปก" มีเหตุผลบันทึกไว้ในโค้ด/เอกสาร ไม่ใช่แค่หลงเหลือจากความไม่ตั้งใจ

## Dependencies

- **WYN-160** (backlog, ยังไม่เริ่ม) — ทับซ้อนกันมาก โดยเฉพาะ border-radius/สี token ที่ WYN-160 คุมอยู่แล้ว
  แนะนำ**รวมเป็นงานเดียวกัน**แทนที่จะแยก 2 epic คู่ขนาน (ดู Recommendation)
- เอกสาร `wynos-web-base-design-system.md` ต้องอัปเดต Button Interaction Spec ก่อนเริ่ม rollout จริง
  (Design ทำ ไม่ใช่ Coding ตัดสินใจเอง)

## Priority

**P1** (สำคัญแต่ไม่บล็อกอะไร) — ไม่ใช่บั๊กที่กระทบผู้ใช้โดยตรงแบบ WYN-171/173 (contrast อ่านไม่ออก) แต่เป็น
"ความรู้สึกทำมาไม่ครบ" ที่สะสมมาเรื่อยๆ ถ้าปล่อยไว้นานจะยิ่งขยายช่องว่างระหว่างหน้าใหม่ (มี motion) กับหน้าเก่า
(ไม่มี) มากขึ้นเรื่อยๆ

เสนอแบ่งเฟส (ตาม traffic/ความเสี่ยง จากน้อยไปมาก):
1. **เฟส 0**: อัปเดต Button Interaction Spec ในเอกสาร (ไม่แตะโค้ด) — Design ทำ, Founder อนุมัติ
2. **เฟส 1**: หน้าที่เพิ่งแก้ไปหมาดๆ ในรอบนี้ (Chat Inbox — เช็คว่าครบตามสเปกใหม่จริง, เป็น baseline)
3. **เฟส 2**: หน้าที่มี traffic สูงสุด — Home feed, Bottom Nav, Auth/Login/Signup
4. **เฟส 3**: Profile, Settings, Search, Notifications
5. **เฟส 4**: Club, Admin (traffic ต่ำกว่า)

## Risks

- **Scope creep**: "ทั้งระบบ" ถ้าไม่แบ่งเฟสจะกลายเป็นงานที่ไม่มีวันจบ ต้อง lock เฟสละ scope ชัดเจน
- **Regression**: ทุกครั้งที่แก้ shared CSS class มีประวัติเจอปัญหา "ไม่ grep หา consumer ให้ครบก่อนแก้"
  มาแล้วหลายครั้ง (ดู LESSONS_LEARNED.md) ต้องบังคับ grep sweep ก่อนแก้ทุกครั้ง
- **ปุ่มที่จงใจต่างจากสเปก**: เสี่ยงถูก "แก้ให้เหมือนกันหมด" ทั้งที่ตั้งใจให้ต่างด้วยเหตุผล UX เฉพาะทาง (เช่น
  ปุ่ม floating action, ปุ่มที่ฝังอยู่ใน third-party component) ต้อง Design ตรวจสอบทีละจุดก่อนแก้ ไม่ใช่
  find-replace เหมาเข่ง

## Recommendation

แนะนำ**รวม WYN-175 นี้เข้ากับ WYN-160** เป็นงานเดียว (ไม่ใช่ 2 epic คู่ขนานที่แก้ CSS ไฟล์เดียวกันซ้อนกัน)
โดยขยาย scope ของ WYN-160 ให้มี "Button Interaction Spec" เป็น deliverable ที่ชัดเจนกว่าเดิม (ของเดิมพูดถึง
แค่ font-size/border-radius/สี ไม่ได้พูดถึง motion/touch-target) — เหตุผล: ทั้งสองงานแก้ไฟล์ CSS ชุดเดียวกัน
(`web/app/*.css` ทั่วระบบ), ใช้ grep sweep methodology เดียวกัน, และ rollout ตามลำดับหน้าเดียวกัน
(WYN-160 มี rollout order อยู่แล้ว: CSS variable กลาง → Auth → Home/Nav → Composer → Chat →
Profile/Settings → Search/Notifications/Club → ลบ dead code) — ทำพร้อมกันในแต่ละหน้าจะมีประสิทธิภาพกว่า
แยกไปแก้ทีละรอบ

## Handoff

รอ Founder ยืนยัน scope (แยกงานหรือรวมกับ WYN-160) ก่อนส่งต่อ AI Design ให้ทำ "Button Interaction Spec"
(เฟส 0) เป็นอันดับแรก
