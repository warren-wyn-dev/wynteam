# WYN-182 — Bottom Nav: Filled Icon on Active + Spacious Layout

> สถานะ: **APPROVED by Founder** (2026-09-20) — ดูกระบวนการตัดสินใจเต็มที่ `.wyn/company/DECISIONS.md`, 2026-09-20 "WYN-182 — ทิศทางใหม่แท็บล่าง"
> Owner: AI Design
> ต่อเนื่องจาก WYN-178/179/180 (icon shapes, icon size 28px, bar height 50px — ทั้งหมด PASS QA แล้ว ไม่แตะรอบนี้)

## สรุปสำหรับ AI Coding ก่อนอ่านรายละเอียด

Founder พูดถึง "เหมือนเธรด" — ตาม DS-001 ข้อ 2 (`.wyn/docs/design/ds-001-color-system.md`) **ห้ามลอกโครงหน้าจอ/ลำดับ element/ท่า interaction ของ Threads** งานนี้จึงหยิบมาเฉพาะ **3 ลักษณะที่ Founder เลือกไว้ชัดเจน** เท่านั้น ไม่ใช่การ clone bottom nav ของ Threads ทั้งชุด:

1. ไอคอน outline → filled เมื่อ active (ไม่มีสี ไม่มี chip ไม่มีเส้น indicator)
2. บาร์ยังคงแบนราบเหมือนเดิม — **ไม่มีปุ่มยกลอย** (ตัดแนวคิดปุ่มโพสต์ยกลอยที่เคยเสนอทิ้งไปแล้ว)
3. เพิ่ม padding/gap ให้บาร์ดูโปร่งขึ้น

Label ทุกแท็บ**ยังคงแสดงเหมือนเดิมทั้ง active/inactive** — Founder ไม่ได้เลือกตัวเลือก "ไอคอนล้วนไม่มี label"

---

Screen: แท็ปบาร์ล่าง (bottom navigation) ทั้งระบบเว็บ — `web/components/bottom-navigation.tsx`, `web/app/bottom-nav.css`

Purpose: ปรับการสื่อสารสถานะ active/inactive จาก "สี+น้ำหนักตัวหนังสือ" เดิมให้เพิ่ม "รูปทรงไอคอนทึบ" เข้ามาด้วย พร้อมเพิ่มช่องไฟให้บาร์ดูโปร่งขึ้น — ตอบโจทย์ที่ Founder ปัดตกทิศทางเดิม 2 รอบ (รอบ 1: เปลี่ยนแค่ active-state indicator, รอบ 2: เปลี่ยนโครงสร้าง/ยกปุ่มโพสต์ลอย) แล้วชี้ชัดว่าต้องการ 3 ลักษณะนี้เท่านั้น

User Flow: ไม่เปลี่ยนจากเดิมแม้แต่จุดเดียว — กดแท็บ → เปลี่ยนหน้า, กด Home/Profile ตอน active อยู่แล้ว → scroll-to-top หรือ refresh (พฤติกรรมเดิมใน `bottom-navigation.tsx`), กดโพสต์ → เปิด compose sheet เหมือนเดิมทุกประการ

Components:
1. **ไอคอน "หน้าหลัก"** — โค้ดปัจจุบันมี `fill={selected ? "currentColor" : "none"}` อยู่แล้ว (ทึบตอน active) **ไม่ต้องแก้**
2. **ไอคอน "คลับ"** — ต้องเพิ่ม filled variant ตอน `selected=true`: คนหน้า 2 คน (circle + body path ที่ปัจจุบัน stroke-only) เปลี่ยนเป็น `fill="currentColor" stroke="none"`; คนหลังตรงกลางยังใช้เทคนิค mask เดิม (`fill="var(--wyn-bg)"`) ที่ WYN-178 วางไว้แล้ว — ไม่แตะพิกัด/geometry เดิม แก้แค่ fill/stroke attribute ตาม state
3. **ไอคอน "แชท"** — ตอน active: bubble path เปลี่ยนจาก `fill="none" stroke="currentColor"` เป็น `fill="currentColor" stroke="none"`; จุดไข่ปลา 3 จุด (ปัจจุบัน `fill="currentColor"` ตลอด) ต้องเปลี่ยนเป็น `fill="var(--wyn-bg)"` เมื่อ active เท่านั้น (ไม่งั้นจุดจะกลืนหายเข้ากับ bubble ทึบสีเดียวกัน) — inactive คงเดิมทุกจุด
4. **ไอคอน "โปรไฟล์"** — ตอน active: circle + body path เปลี่ยนเป็น `fill="currentColor" stroke="none"` เหมือนกัน
5. **ไอคอน "โพสต์"** — ไม่มี state active ในโค้ดปัจจุบัน (เป็นปุ่มเปิด compose sheet ไม่ใช่ route) **ไม่ต้องแก้เลย** ยังเป็น outline เสมอ
6. **Label** — ทั้ง 5 แท็บยังแสดงข้อความเหมือนเดิมทุกสถานะ ไม่ซ่อน ไม่มีเงื่อนไขใหม่

Interactions:
- เพิ่มช่องไฟ `.route-nav-link`: `padding: 1px 3px 2px` → **`padding: 4px 4px 4px`**, `gap: 1px` → **`gap: 3px`** (ทุก breakpoint ที่มีอยู่ ปรับตามสัดส่วนเดิม — breakpoint แคบ <359px คงอัตราส่วนใกล้เคียง เช่น padding `3px 3px 3px`/gap `2px`)
- **ไม่แตะ** `--wyn-bottom-nav-height` (คงที่ 50px/48px/64px ตาม WYN-180 ที่เพิ่ง PASS QA) — เพิ่ม breathing room ด้วย padding ภายในคอลัมน์แทนการขยายความสูงบาร์ทั้งก้อน เพื่อไม่ชนงานที่เพิ่งอนุมัติ
- Press feedback เดิมไม่เปลี่ยน: `transform: scale(var(--wyn-motion-press-scale))` (0.96) ที่ `:active`, `transition: transform var(--wyn-motion-duration) var(--wyn-motion-easing)` (160ms spring)
- **ต้อง verify ด้วยตัวเลขจริง (DOM measurement)** ว่า padding ใหม่ไม่ทำให้ icon (28px) + label (10px) รวมกันล้นพื้นที่ 50px content height ที่มีอยู่ — คำนวณคร่าวๆ: padding บน+ล่าง 8px + icon 28px + gap 3px + label ~11px (line-height 1) = 50px พอดี แต่ **AI Coding ต้อง render จริงแล้ววัด ไม่เดาจากตัวเลขนี้อย่างเดียว** (เรียนรู้จาก WYN-180 ที่เจอบั๊ก cross-subtree CSS scoping ที่ทุก harness ก่อนหน้าพลาดจับ)

States:
- **Inactive**: icon `stroke="currentColor" stroke-width="1.9" fill="none"` (เหมือนเดิมทุกไอคอนยกเว้นที่ระบุ), `color: var(--wyn-text-secondary)`, `font-weight: 400`
- **Active**: icon เปลี่ยนเป็นทึบตามสเปกข้อ Components ด้านบน, `color: var(--wyn-text)`, `font-weight: 700` (เหมือนเดิม — แค่เพิ่มมิติ filled ให้ icon)
- ไม่มีสี accent, ไม่มี background chip, ไม่มีเส้น indicator ที่จุดไหนเลย — ตรงตามที่ Founder เลือกชัดเจน ("ไม่มีสี/chip/เส้น")

Responsive Behavior: ปรับ padding/gap ทั้ง 3 breakpoint (แคบ <359px / หลัก 390px / กว้าง ≥681px floating dock) ตามสัดส่วนเดิมของแต่ละ breakpoint — ต้อง render จริงที่ทั้ง 3 ความกว้างแล้ววัด `scrollHeight`/`clientHeight` ยืนยันไม่มี content overflow (วิธีเดียวกับที่ AI QA & Security ใช้ใน WYN-179/180)

Accessibility:
- `aria-label` ทุกไอคอนคงเดิมทุกจุด, ไอคอนยัง `aria-hidden="true"` (label จริงมาจาก `aria-label` บน `<Link>`)
- Touch target คงเดิม (คอลัมน์เต็มความสูงบาร์ ~78px กว้างที่ 390px) — padding ที่เพิ่มอยู่ *ภายใน* touch target เดิม ไม่ทำให้พื้นที่กดเล็กลง
- Contrast: **ไม่เปลี่ยนสีใด ๆ** เลย (active ยังใช้ `--wyn-text`, inactive ยังใช้ `--wyn-text-secondary` เหมือน WYN-178 ที่ผ่าน AA ทั้ง 2 ธีมไปแล้ว — filled icon ใช้สีเดียวกับ label ที่อยู่ข้าง ๆ จึงไม่มีความเสี่ยง contrast ใหม่) — QA ยัง verify ซ้ำได้แต่คาดว่าตัวเลขเดิมจาก WYN-178 ยังใช้ได้

Design Rules:
- **ห้ามก็อปโครงหน้าจอ/ปุ่ม/ลำดับ interaction ของ Threads** (DS-001 ข้อ 2) — งานนี้เอาแค่ 3 ลักษณะที่ระบุไว้ข้างต้นเท่านั้น ไม่ใช่การ reproduce bottom nav ของ Threads
- ไม่ใช้สี accent (`--wyn-accent` แดง สงวนไว้เฉพาะ like/error/destructive ตาม `wynos-web-base-design-system.md`)
- ไม่แตะ `--wyn-bottom-nav-height`, breakpoint values, icon size (28px) ที่เพิ่งอนุมัติใน WYN-179/180
- ลำดับ/จำนวน/ชื่อ 5 แท็บ (หน้าหลัก/คลับ/โพสต์/แชท/โปรไฟล์) ไม่เปลี่ยน — คำสั่งถาวรของ Founder (16 ก.ย. 2026, ดู `.wyn/logs/deployments/2026-09-16-web-bottom-nav-revert-deploy.md`)
- ต้องผ่าน WCAG AA ทั้ง light/dark เหมือนเดิม

Handoff: → **AI Coding**
- แก้ `web/components/bottom-navigation.tsx`: เพิ่ม filled SVG variant ให้ club/chat/profile เมื่อ `selected=true` ตามสเปก Components ข้อ 2-4
- แก้ `web/app/bottom-nav.css`: ปรับ `.route-nav-link` padding/gap ตามสเปก Interactions (ทุก breakpoint)
- รัน `npm run check` (lint + typecheck + build) ก่อนส่งต่อ QA เสมอ
- อ้างอิง: Artifact เปรียบเทียบทิศทาง https://claude.ai/artifact/P2sAcfYmzKwDBU71UYE8BG (รอบ 1 = active-state options, รอบ 2 = โครงสร้าง — งานนี้หยิบ Concept A ของรอบ 1 มาเป็นฐาน + เพิ่ม spacing), บันทึกคำตัดสินใจเต็มที่ `.wyn/company/DECISIONS.md` (2026-09-20, "WYN-182")
- ส่งต่อ **AI QA & Security** หลัง coding เสร็จ — เน้น verify ด้วยตัวเลขจริงจาก DOM ไม่ใช่แค่ดูภาพ (ตามบทเรียนจาก WYN-179/180)
