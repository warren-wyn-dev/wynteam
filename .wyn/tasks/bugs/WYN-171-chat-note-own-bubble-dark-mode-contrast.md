# Bug Report — WYN-171

Status: fixed and verified — PASS by AI QA & Security, พร้อม Deploy
Owner: AI Design
Parent: none (pre-existing production bug, unรelated to WYN-169/170) — พบระหว่าง Founder ขอให้ตรวจสอบ
ฟังก์ชันโน้ต (Chat Inbox) 2026-09-19

## Bug

การ์ด "โน้ตของคุณ" (self note bubble, `.wyn-chat-note-card.is-mine .wyn-chat-note-bubble`) ใน Notes row ของ
Chat Inbox **อ่านแทบไม่ออกเลยในโหมดมืด** เพราะพื้นหลัง hardcode เป็น hex ตรงๆ ไม่ใช้ token ที่รองรับ dark
mode — **นี่คือบั๊ก pattern เดียวกับ WYN-168 เป๊ะ** (ที่เพิ่งปิดไปเมื่อครู่นี้เอง) และรุนแรงกว่าด้วย — พบตอนที่
Founder ขอให้ AI Design ตรวจฟังก์ชันโน้ตหลัง WYN-170 deploy เสร็จ

## Reproduction

Environment: `playwright-core` + `/opt/pw-browsers/chromium` โหลด CSS จริงจาก repo ตรงๆ
(`globals.css` → `design-system.css` → `chat-notes.css`) แล้ว emulate `colorScheme: "dark"`

1. เปิด Chat Inbox ในโหมดมืด
2. ตั้งโน้ตของตัวเอง (พิมพ์ข้อความแล้วกด "แชร์")
3. ดูที่การ์ด "โน้ตของคุณ" — ตัวหนังสือในบับเบิลจะจางมากจนแทบมองไม่เห็น

## Root Cause

`web/app/chat-notes.css` ประกาศ `.wyn-chat-note-card.is-mine .wyn-chat-note-bubble { background: #f7f7f8 }`
(hardcode 2 จุดในไฟล์ — บรรทัด ~158 และ ~682 ซึ่งจุดหลังชนะ cascade จริงเพราะอยู่หลังสุด) — เป็นสีเทาอ่อน
เกือบขาวคงที่ ไม่เปลี่ยนตามธีม ขณะที่ตัวหนังสือใช้ `color: var(--wyn-text)` (base rule ของ
`.wyn-chat-note-bubble`) ซึ่ง**ปรับตามธีมถูกต้อง** กลายเป็นสีขาวในโหมดมืด

คำนวณ WCAG contrast จริง (สูตร relative luminance เดียวกับที่ใช้เจอ WYN-168):
- **State มีโน้ตแล้ว (has-note)**: ขาว `rgb(255,255,255)` บนพื้นหลัง `rgb(247,247,248)` = **1.07:1** —
  แย่กว่า WYN-168 (1.13:1) อีก ถือว่ามองไม่เห็นเลย
- **State ยังไม่มีโน้ต (empty, "เพิ่มโน้ต")**: เทารอง `var(--wyn-text-secondary)` = `rgb(138,136,128)` บน
  พื้นหลังเดียวกัน = **3.32:1** — ไม่ผ่าน WCAG AA (ต้องการ ≥4.5:1) เช่นกัน แม้จะยังพอมองออกบ้าง
- เทียบกับโน้ตของเพื่อน (ไม่ใช่ `.is-mine`) ที่ใช้ `background: var(--wyn-bg)` ถูกต้องอยู่แล้ว: 19.8:1
  (light) / 21:1 (dark) — ยืนยันว่าบั๊กอยู่ที่การ์ดของตัวเองเท่านั้น เพราะมีการ override สีพื้นหลังแยกไว้
  ต่างหาก

โหมดสว่างไม่มีปัญหา (18.49:1 has-note / 4.97:1 empty — ผ่านทั้งคู่ แม้ empty จะฉิวเฉียด)

นี่คือ pattern เดียวกับที่ `.wyn/docs/design/wyn-160-web-design-system-consolidation.md` เคยเตือนไว้ทั่วไป
("ห้ามมีไฟล์ CSS ไหน hardcode สีเทา/ขาว/ดำเป็น hex ตรงๆ") และเป็นโค้ดเก่าจาก WYN-162 (Notes row เดิม) ที่มี
มาก่อนการทำ dark mode pass (2026-09-16) และไม่เคยถูกแก้ตอนนั้น — ไม่เกี่ยวกับ WYN-169/170 เลย (ไม่ได้แตะ
`.wyn-chat-note-*` ใดๆ ทั้ง 2 งานนั้น)

## Fix (decided by AI Design, 2026-09-19 — พร้อมส่ง AI Debug Engineer)

Drop-in token swap เหมือน WYN-168 เป๊ะ ไม่ประดิษฐ์สีใหม่:

`.wyn-chat-note-card.is-mine .wyn-chat-note-bubble { background: #f7f7f8 }`
→ `background: var(--wyn-surface)`

- โหมดสว่าง: `--wyn-surface` = `#fafafa` (ใกล้เคียง `#f7f7f8` มาก แทบไม่ต่างจากเดิมเลยด้วยตา)
- โหมดมืด: `--wyn-surface` = `#111111` → ขาวบนพื้นหลัง `#111111` = **18.88:1** (has-note),
  `--wyn-text-secondary` บน `#111111` = ประมาณ **5-6:1** (empty state) — ผ่าน WCAG AA ทั้งคู่แบบขาดลอย

ต้องแก้ **ทั้ง 2 จุด** ที่ประกาศซ้ำในไฟล์ (บรรทัด ~158 และ ~682) ให้ตรงกัน — เหมือนที่ WYN-168 เจอปัญหา
lock-test เพราะแก้ไม่ครบทุกจุดที่ประกาศซ้ำมาก่อน ควรระวังจุดนี้เป็นพิเศษ

**Handoff**: AI Debug Engineer — 2-line change (2 จุด) ใน `web/app/chat-notes.css` ไม่ต้องแก้ `.tsx`

## Tests

หลังแก้: คำนวณ WCAG contrast จริงซ้ำทั้ง 2 state (has-note/empty) × 2 ธีม (light/dark) ยืนยัน ≥4.5:1 ทุกจุด
เหมือนวิธีที่ใช้เจอบั๊กนี้ — ถ้ามี regression test สำหรับ Chat Inbox dark mode อยู่แล้ว (ยังไม่มีในตอนนี้)
ควรเพิ่มเคสนี้เข้าไปด้วย

## Regression Risk

ต่ำ — แก้แค่ background 1 property ใน selector เดิม ไม่กระทบ layout/ขนาด/ฟังก์ชันอื่น เช็คแค่ว่าโหมดสว่างยัง
ดูใกล้เคียงเดิม (ตามที่คำนวณไว้ด้านบนว่าต่างกันน้อยมาก)

## Severity

**HIGH** — เหมือน WYN-168 ทุกประการ (จริงๆ รุนแรงกว่าเล็กน้อยในแง่ตัวเลข contrast) เป็นฟีเจอร์ที่ผู้ใช้เห็น
บ่อย (ทุกครั้งที่เข้า Chat Inbox ถ้าตั้งโน้ตไว้) และเป็น "โน้ตของตัวเอง" ที่ผู้ใช้เพิ่งพิมพ์เอง — อ่านไม่ออก
ทันทีที่ปิดแล้วเปิดโหมดมืดกลับมาดู ตาม AGENTS.md, HIGH finding ต้องได้รับการแก้ไขหรือ Founder รับความเสี่ยง
อย่างชัดเจนก่อน release ถัดไปที่เกี่ยวข้อง

## Handoff

พบโดย AI Design ระหว่าง audit ฟังก์ชันโน้ตตามคำขอ Founder (2026-09-19) — แนะนำ: ถ้า Founder อยากแก้ทันที
ส่งต่อ AI Debug Engineer ได้เลย (fix ตัดสินใจไว้แล้ว เหมือน WYN-168 ทุกประการ) → AI QA & Security ยืนยัน
contrast ซ้ำ → Deploy

## Resolution (AI Debug Engineer, 2026-09-19)

**Reproduction (ก่อนแก้, independent — ไม่เชื่อตัวเลขจาก AI Design เฉยๆ)**: สร้าง Playwright harness ใหม่
(โหลด CSS จริงจาก repo ผ่าน static file server, ลำดับเดียวกับ `app/layout.tsx`) แล้ว emulate
`colorScheme: dark`/`light` วัด contrast จริงได้ตรงกับรายงานของ AI Design ทุกตัวเลข:
- Dark, has-note: **1.07:1**
- Dark, empty: **3.32:1**
- Light, has-note: **18.49:1**
- Light, empty: **4.98:1**

ยืนยัน root cause ตรงกัน: `background: #f7f7f8` hardcode ซ้ำ 2 จุดใน `web/app/chat-notes.css`
(บรรทัด ~158 และ ~682)

**Fix ที่ใช้จริง**: แก้ทั้ง 2 จุดตามที่ AI Design ระบุ —
`.wyn-chat-note-card.is-mine .wyn-chat-note-bubble { background: #f7f7f8 }` →
`background: var(--wyn-surface)` (ทั้งคู่ ไม่มีจุดใดหลงเหลือ hardcode — เช็คด้วย `grep -n "f7f7f8"` ซ้ำ
หลังแก้ ไม่พบอีก)

**Verification (หลังแก้)**: วัด contrast ซ้ำด้วย harness เดิม —
- Dark, has-note: 1.07:1 → **18.88:1** ✅
- Dark, empty: 3.32:1 → **5.32:1** ✅ (ผ่าน WCAG AA แล้ว)
- Light, has-note: 18.49:1 → **18.97:1** ✅ (ยังใกล้เคียงเดิมตามคาด)
- Light, empty: 4.98:1 → **5.11:1** ✅

ทุกค่า ≥4.5:1 ตาม WCAG AA ครบ 4 combination

**Regression check**: `npm run check` (lint + typecheck + build) ผ่านทั้งหมด, 0 error, มีแค่ 3 warning เดิม
ที่ไม่เกี่ยวข้อง (pre-existing, ไม่ได้เกิดจาก commit นี้) ไม่ได้แตะ layout/ขนาด/ฟังก์ชันอื่นใดๆ ตามที่ประเมิน
ความเสี่ยงไว้ว่าต่ำ

**Commit**: `21bbef58` บน branch `claude/ux-ui-button-design-ult3lz` (รวมกับ WYN-172 ในคอมมิตเดียวกัน
เพราะแก้ไฟล์เดียวกัน คนละจุด ไม่ทับซ้อนกัน)

**ส่งต่อ**: AI QA & Security เพื่อยืนยัน contrast ซ้ำแบบอิสระ + regression เต็มรูปแบบของ Notes composer

## QA Verification (AI QA & Security, 2026-09-19)

วัด contrast จริงซ้ำแบบอิสระด้วย Playwright + full 44-file CSS cascade จริงจาก `app/layout.tsx` (ไม่ใช่แค่
3 ไฟล์ที่เกี่ยวข้องโดยตรง เพื่อป้องกัน false-positive/negative แบบที่เคยเจอใน WYN-169) ได้ตัวเลขตรงกับที่
AI Debug Engineer รายงานทุกตัว:
- Dark, has-note: **18.88:1** ✅ | Dark, empty: **5.32:1** ✅
- Light, has-note: **18.97:1** ✅ | Light, empty: **5.11:1** ✅

`grep -n "f7f7f8" web/app/chat-notes.css` ยืนยันไม่มี hardcode เหลือใน selector นี้อีก (2 จุดเดิมแก้ครบแล้ว)
— ดูหัวข้อ "Security Findings" ด้านล่างสำหรับบั๊กใหม่ที่เจอข้างเคียง (WYN-173 — ไม่เกี่ยวกับ commit นี้)

**Final Status: PASS**
