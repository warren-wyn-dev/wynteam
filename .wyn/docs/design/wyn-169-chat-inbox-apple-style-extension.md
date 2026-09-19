# Design — WYN-169: ขยายภาษา Apple-style (WYN-163/167) มาที่ WYNOS Web Chat Inbox

Owner: AI Design → รอ Founder อนุมัติ → AI Coding
Ref: `.wyn/docs/design/wyn-163-onboarding-button-redesign.md`, `.wyn/docs/design/
wyn-167-home-feed-apple-style-extension.md` (แนวทางเดียวกัน — ขยาย motion ไม่แตะขนาด/สี), `web/app/
chat-notes.css`, `web/components/chat-inbox-parity.tsx`

## ทำไมไม่ใช่การคิดทิศทางใหม่ + สิ่งที่ตรวจพบจากโค้ดจริง

มีเอกสารเก่าชื่อ **WYN-159** (`.wyn/docs/design/wyn-159-chat-web-threads-redesign.md`, สถานะ **backlog** —
Founder ไม่เคยอนุมัติ) ที่ออกแบบการรื้อหน้าแชทใหม่ทั้งหน้า (message grouping, bubble tail, timestamp reveal,
read receipt) — **งานนี้ไม่ใช่ WYN-159 และไม่ได้ทำ WYN-159** สองเหตุผล: (1) ขอบเขตใหญ่กว่าที่ Founder ขอวันนี้
มาก ("ไปต่อหน้า Chat inbox" ตรงกับรูปแบบ WYN-167 ที่เพิ่งอนุมัติ คือขยาย **motion** ไม่ใช่รื้อ UX/layout) (2)
เอกสาร WYN-159 อ้างอิง "DS-001 ยืนยันสีแบรนด์ WYN คือ Cyan `#00C8FF`" ซึ่ง**ไม่ตรงกับโค้ดจริงของเว็บตอนนี้เลย**
— เว็บใช้ `--wyn-bg`/`--wyn-text`/`--wyn-surface` ขาว-ดำ-เทา + `--wyn-accent: #e0203d` (แดง, สงวนไว้ error
เท่านั้น) ไม่มี Cyan อยู่ในระบบ token ของเว็บเลยสักจุด — แปลว่า WYN-159 อ้างอิง color system คนละชุดกับเว็บจริง
(น่าจะเขียนอิงจาก Flutter's `wyn_colors.dart` ที่คนละ track กัน) **WYN-159 ยังเป็น backlog ที่ต้องตรวจสอบใหม่
ทั้งฉบับก่อนใช้งานจริง ไม่ใช่ของที่หยิบมาทำได้เลย — ถ้า Founder อยากทำ WYN-159 เต็มรูปแบบ ควรเป็นงานแยกที่ผ่าน
การตรวจทานใหม่ก่อน**

งานนี้จึง**ตรงกับรูปแบบ WYN-167 เป๊ะ**: ขยายภาษา **press-scale motion** ของ WYN-163 มาที่ปุ่มที่เป็นของ Chat
Inbox เท่านั้น ไม่แตะขนาด/สี/layout/UX ใดๆ

ไล่ grep หาปุ่มที่เป็นของ Chat Inbox จริงๆ (ไม่ใช่ `.route-primary`/`.route-secondary`/`.route-pill`/
`.route-icon-button` ที่ใช้ร่วมกับอีก 13 ไฟล์ทั่วแอป — ยืนยันซ้ำแบบเดียวกับ WYN-167 ว่าไม่แตะ class เหล่านี้)
เจอ 3 กลุ่ม:

1. **`.wyn-chat-compose-action`** (ปุ่มไอคอน "ข้อความใหม่" มุมขวาบน) และ **`.wyn-chat-requests-link`**
   (ปุ่ม "คำขอ N" ข้างๆ กัน) — ทั้งคู่ประกาศอยู่ใน `web/app/chat-notes.css` **ไฟล์เดียว** ไม่ถูกใช้ที่อื่นเลย
   (ยืนยันด้วย grep — component เดียวที่ import คือ `chat-inbox-parity.tsx`) **ปลอดภัยที่สุด อยู่ในขอบเขตนี้**
2. **`.flutter-chat-header-action`** (ปุ่มย้อนกลับ ←) — **พบปัญหาจริง**: class นี้ถูกประกาศซ้ำใน **4 ไฟล์ CSS
   คนละไฟล์** (`chat-notes.css`, `notifications-clean.css`, `pixel-parity-audit-closure.css`,
   `system-parity-lock.css`) แม้จะมี component เดียวที่ใช้จริง (`chat-inbox-parity.tsx`) ก็ตาม — ร่องรอย CSS
   ซ้ำซ้อนแบบที่ WYN-160's audit เคยเตือนไว้ทั่วไป ("37 ไฟล์ import ซ้อนกัน...ร่องรอยการแก้ทีละจุดหลายรอบ")
   **ไม่แตะจุดนี้ในรอบนี้** เพราะต้องตรวจให้แน่ใจก่อนว่า cascade order จริงให้ไฟล์ไหนชนะ ก่อนจะเพิ่ม CSS ใหม่
   เข้าไปโดยไม่รู้ว่าจะมีผลจริงหรือไม่ — เก็บเป็นรายการ cleanup แยกต่างหาก (คล้ายที่ WYN-167 เก็บ
   `.route-primary`/`.route-secondary` ไว้เป็นงานแยก)
3. **`.wyn-chat-note-card`** (การ์ดโน้ตของตัวเอง, เป็น `<button>` จริง) — เป็นการ์ดเนื้อหา ไม่ใช่ปุ่ม CTA/ไอคอน
   ธรรมดา และ WYN-159 (แม้ไม่ได้ทำทั้งฉบับ) มีสเปกละเอียดสำหรับพื้นที่นี้อยู่แล้วในอนาคต — **ไม่แตะในรอบนี้**
   เพื่อไม่ให้ขอบเขตกว้างเกินไป คงเป็นแค่ "ปุ่ม header 2 จุด" ตามที่ WYN-167 ทำกับ Home ก็คือ "ไอคอน header"
   เท่านั้น ไม่ใช่การ์ด/เนื้อหา

## Screen: WYNOS Web Chat Inbox (`/chat`, `web/components/chat-inbox-parity.tsx`)

Purpose: เพิ่ม press feedback ให้ 2 ปุ่ม header ที่ยังไม่มี motion เลย ใช้สูตรเดียวกับ WYN-163/167 เป๊ะ
(`transform: scale(0.96)`, `prefers-reduced-motion` fallback) ไม่ประดิษฐ์ค่าใหม่

User Flow: ไม่เปลี่ยน

Components:
- `.wyn-chat-compose-action` — คงขนาด 42×42/ไม่มี border-radius เดิม (ไอคอนล้วน ไม่มีกรอบ) — **เพิ่ม `:active`
  press-scale**
- `.wyn-chat-requests-link` — คงรูปทรงเดิม (ข้อความ+ตัวเลข ไม่มีกรอบ) — **เพิ่ม `:active` press-scale**

Interactions: `:active { transform: scale(0.96) }`, `transition: transform 160ms
cubic-bezier(0.34, 1.56, 0.64, 1)` — สูตรเดียวกับ WYN-163/167 เป๊ะ

States: เพิ่ม pressed state ใหม่ 2 จุด (เดิมไม่มีเลย)

Responsive Behavior: ไม่เปลี่ยน

Accessibility: เพิ่ม `@media (prefers-reduced-motion: reduce)` ครอบทั้ง 2 จุด (`chat-notes.css` ปัจจุบันยังไม่
มี reduced-motion handling เลย เหมือนที่ `home.css` เคยขาดก่อน WYN-167 — อุดพร้อมกันในรอบนี้)

Design Rules:
1. ใช้ motion token เดิมจาก WYN-163/167 เป๊ะ ไม่ประดิษฐ์ค่าใหม่
2. **ไม่แตะ** ขนาด/radius/สี/spacing ของปุ่มทั้งสอง หรือของหน้า Chat Inbox โดยรวม
3. **ไม่แตะ** `.flutter-chat-header-action` (ความเสี่ยง CSS ซ้ำซ้อน 4 ไฟล์ — ต้องตรวจ cascade ก่อนแยกต่างหาก)
4. **ไม่แตะ** `.route-primary`/`.route-secondary`/`.route-pill`/`.route-icon-button` (ใช้ร่วมหลายหน้าจอ)
5. **ไม่ทำ** WYN-159 (message grouping/bubble tail/timestamp/read-receipt) — ของเก่าที่ยังไม่อนุมัติและ
   สมมติฐานสีล้าสมัย ถ้า Founder อยากสานต่อควรเป็นงานแยกที่ทบทวนใหม่ทั้งฉบับก่อน

## Handoff

พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติ — **ไฟล์เดียว** (`web/app/chat-notes.css`) เพิ่ม CSS ล้วนๆ ไม่ต้อง
แก้ `.tsx` ไฟล์ไหนเลย ความเสี่ยง regression ต่ำมาก เหมือน WYN-167 ทุกประการ

**คำถามสำหรับ Founder**:
1. เห็นด้วยกับขอบเขตนี้ไหม (แค่ปุ่ม header 2 จุด ไม่แตะปุ่มย้อนกลับ/การ์ดโน้ต/ไม่ทำ WYN-159)?
2. อยากให้หยิบ WYN-159 (rebuild หน้าแชทแบบเธรดเต็มรูปแบบ) มาทบทวนใหม่เป็นงานแยกในอนาคตไหม?
