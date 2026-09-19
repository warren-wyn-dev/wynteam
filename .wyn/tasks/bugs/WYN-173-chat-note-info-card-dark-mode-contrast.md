# Bug Report — WYN-173

Status: deployed to production (PR #551, merge commit d3ffcbfd) — รอ Founder ยืนยัน production จริงบน
device ก่อนปิดงาน
Owner: AI QA & Security
Parent: none (pre-existing production bug, ไม่เกี่ยวกับ WYN-171/172 ที่เพิ่งแก้) — พบระหว่างตรวจสอบ
(verify) การแก้ WYN-171 ในไฟล์เดียวกัน (`web/app/chat-notes.css`)

## Bug

การ์ดข้อมูล "แสดงเป็นเวลา 24 ชั่วโมง / แสดงให้ผู้ติดตามที่คุณติดตามกลับ / แชร์ความรู้สึกได้สั้น ๆ"
(`.wyn-note-info-card`) ที่อยู่ใต้กล่องเขียนโน้ตโดยตรงในหน้า Note Composer **อ่านแทบไม่ออกเลยในโหมดมืด** —
เป็นบั๊ก pattern เดียวกับ WYN-168 และ WYN-171 เป๊ะ (background hardcode เป็น hex ไม่ผูกกับ dark mode token
ขณะที่ตัวหนังสือผูก token ถูกต้อง) และเป็นตัวเลข contrast **เท่ากับ WYN-171 ก่อนแก้เป๊ะ** เพราะใช้สี
`#f7f7f8` เดียวกัน

## Reproduction

Environment: `playwright-core` + `/opt/pw-browsers/chromium` โหลด CSS จริงทุกไฟล์จาก repo ตามลำดับ import
จริงใน `app/layout.tsx` (44 ไฟล์) แล้ว emulate `colorScheme: "dark"`/`"light"` — พบระหว่างตรวจสอบ (verify)
การแก้ WYN-171 ในไฟล์เดียวกัน จึงขยายการทดสอบมาที่ selector ข้างเคียงในหน้าเดียวกันด้วย

1. เปิดหน้าเขียนโน้ต (Note Composer) ในโหมดมืด
2. เลื่อนลงมาดูการ์ดข้อมูล 3 บรรทัดใต้กล่องเขียนโน้ต
3. ตัวหนังสือในการ์ดจะจางมากจนแทบมองไม่เห็น (โดยเฉพาะหัวข้อตัวหนา)

## Root Cause

`web/app/chat-notes.css` บรรทัด ~435: `.wyn-note-info-card { background: #f7f7f8; ... }` — hardcode สีเทา
อ่อนคงที่ ไม่ผูกกับ theme token ขณะที่ตัวหนังสือข้างในสืบทอด `color: var(--wyn-text)` จาก `.wyn-note-screen`
(บรรทัด ~272 ซึ่งผูกถูกต้อง) และ `.wyn-note-info-row small` ใช้ `color: var(--wyn-text-secondary)` (ผูกถูกต้อง
เช่นกัน)

คำนวณ WCAG contrast จริง (สูตร relative luminance เดียวกับ WYN-168/171):
- **หัวข้อตัวหนา (`strong`, สืบทอด `--wyn-text`)**: ขาว `rgb(255,255,255)` บนพื้นหลัง `rgb(247,247,248)` =
  **1.07:1** — เท่ากับ WYN-171 ก่อนแก้เป๊ะ (มองไม่เห็นเลย)
- **คำอธิบายย่อย (`small`, `--wyn-text-secondary`)**: `rgb(138,136,128)` บนพื้นหลังเดียวกัน = **3.32:1** —
  ไม่ผ่าน WCAG AA (ต้องการ ≥4.5:1)

โหมดสว่างไม่มีปัญหา (18.49:1 หัวข้อ / 4.98:1 คำอธิบาย — ผ่านทั้งคู่ แม้ตัวหลังจะฉิวเฉียด เหมือน WYN-171)

นี่คือ instance ที่ 3 ของ pattern เดียวกัน (WYN-168 → ปุ่มติดตาม, WYN-171 → note bubble ของตัวเอง, WYN-173 →
การ์ดข้อมูลนี้) ยืนยันสมมติฐานที่บันทึกไว้ใน `.wyn/learning/LESSONS_LEARNED.md` (entry 2026-09-19 เรื่อง
"บั๊ก dark-mode contrast แบบ hardcode-hex-background เกิดซ้ำ pattern เดิม") ว่าโค้ดเก่าก่อน dark mode pass
(2026-09-16) น่าจะมี pattern นี้หลงเหลืออีกหลายจุดที่ยังไม่มีใครเจอ

## Fix (proposed by AI QA & Security, พร้อมส่ง AI Debug Engineer ถ้า Founder อนุมัติ)

Drop-in token swap เดียวกับ WYN-168/171 เป๊ะ ไม่ประดิษฐ์สีใหม่:

`.wyn-note-info-card { background: #f7f7f8; ... }` → `background: var(--wyn-surface);`

- โหมดสว่าง: `--wyn-surface` = `#fafafa` (ใกล้เคียงเดิมมาก แทบไม่ต่างด้วยตา)
- โหมดมืด: `--wyn-surface` = `#111111` → ผ่าน WCAG AA ขาดลอยทั้งคู่ (ตัวเลขคาดว่าใกล้เคียงกับที่ WYN-171 ได้
  จริง: ~18.9:1 / ~5.3:1 เพราะสีตั้งต้นและ token เหมือนกันทุกประการ)

มีจุดเดียวในไฟล์ (ไม่ซ้ำเหมือน WYN-171) — ยืนยันด้วย `grep -n "wyn-note-info-card"` แล้ว พบประกาศ 1 ครั้ง

## Tests

หลังแก้: คำนวณ WCAG contrast จริงซ้ำทั้ง 2 element (strong/small) × 2 ธีม ยืนยัน ≥4.5:1 ทุกจุด ด้วยวิธี
เดียวกับที่ใช้เจอบั๊กนี้ (real CSS cascade + Playwright)

## Regression Risk

ต่ำมาก — แก้แค่ background 1 property ใน selector เดียว ไม่กระทบ layout/ขนาด/ฟังก์ชันอื่น

## Severity

**HIGH** — เหมือน WYN-168/171 ทุกประการ อยู่ในหน้าเดียวกับ WYN-171 ที่เพิ่งแก้ไป ผู้ใช้เห็นทุกครั้งที่เปิดหน้า
เขียนโน้ตในโหมดมืด (ไม่ต้องมีโน้ตอยู่ก่อนด้วยซ้ำ — การ์ดนี้แสดงเสมอตอนเปิด composer) ตาม AGENTS.md, HIGH
finding ต้องได้รับการแก้ไขหรือ Founder รับความเสี่ยงอย่างชัดเจนก่อน release ถัดไปที่เกี่ยวข้อง

## Handoff

พบโดย AI QA & Security ระหว่างตรวจสอบ (verify) การแก้ WYN-171 — **ไม่ block การอนุมัติ WYN-171/172** เพราะ
เป็นบั๊กเดิมที่มีอยู่ก่อนแล้ว ไม่เกี่ยวกับการเปลี่ยนแปลงของ commit `21bbef58` เลย (ไม่ได้แตะ
`.wyn-note-info-card` เลยทั้ง WYN-171 และ WYN-172) — แนะนำ: ถ้า Founder อยากแก้ทันทีเหมือน WYN-171
(เพราะเป็น fix 1 บรรทัดที่ตัดสินใจไว้แล้ว) ส่งต่อ AI Debug Engineer ได้เลย → AI QA & Security ยืนยัน contrast
ซ้ำ → Deploy พร้อมกับรอบถัดไป

## Resolution (AI Debug Engineer, 2026-09-19)

**Reproduction (ก่อนแก้, independent)**: Playwright + full 44-file CSS cascade จริงจาก `app/layout.tsx`,
emulate `colorScheme: dark`/`light` วัด contrast จริงได้ตรงกับที่ AI QA & Security รายงานทุกตัวเลข:
- Dark, strong: **1.07:1** | Dark, small: **3.32:1**
- Light, strong: **18.49:1** | Light, small: **4.98:1**

ยืนยัน root cause ตรงกัน: `background: #f7f7f8` hardcode ที่ `.wyn-note-info-card` (บรรทัด ~435 ของ
`web/app/chat-notes.css`) — จุดเดียวในไฟล์ ไม่ซ้ำเหมือน WYN-171 (เช็คด้วย `grep -n "wyn-note-info-card"`
ก่อนแก้ พบประกาศ 1 ครั้ง)

**Fix ที่ใช้จริง**: `.wyn-note-info-card { background: #f7f7f8 }` → `background: var(--wyn-surface)`
(token เดียวกับ WYN-168/171 ไม่ประดิษฐ์สีใหม่)

**Verification (หลังแก้)**: วัด contrast ซ้ำ —
- Dark, strong: 1.07:1 → **18.88:1** ✅ | Dark, small: 3.32:1 → **5.32:1** ✅
- Light, strong: 18.49:1 → **18.97:1** ✅ | Light, small: 4.98:1 → **5.11:1** ✅

ทุกค่า ≥4.5:1 ตาม WCAG AA ครบ — ตัวเลขตรงกับที่ WYN-171 ได้เป๊ะ (เพราะใช้สีตั้งต้นและ token เดียวกันทุก
ประการ) `grep -n "wyn-note-info-card" chat-notes.css` ซ้ำหลังแก้ยังพบจุดเดียวเดิม ไม่มีจุดอื่นตกหล่น

**Regression check**: `npm run check` (lint + typecheck + build) ผ่านทั้งหมด, 0 error, มีแค่ 3 warning เดิม
ที่ไม่เกี่ยวข้อง (pre-existing) แก้แค่ background 1 property ใน selector เดียว ไม่กระทบ layout/ขนาด/ฟังก์ชัน
อื่นใดๆ ตามที่ประเมินความเสี่ยงไว้ว่าต่ำมาก

**ส่งต่อ**: AI QA & Security เพื่อยืนยัน contrast ซ้ำแบบอิสระ ก่อนไป Deploy พร้อมกับ WYN-171/172

## QA Verification (AI QA & Security, 2026-09-19)

**Diff check**: `git show 83df6f79 -- web/app/chat-notes.css` ยืนยันแก้แค่ 1 บรรทัด (`background: #f7f7f8` →
`background: var(--wyn-surface)` ใน `.wyn-note-info-card`) ไม่กระทบส่วนอื่นของไฟล์ที่เพิ่งผ่าน QA ไปแล้วใน
รอบ WYN-171/172 เลย

**Contrast re-measurement (independent, full 44-file CSS cascade)**:
- Dark, strong: **18.88:1** ✅ | Dark, small: **5.32:1** ✅
- Light, strong: **18.97:1** ✅ | Light, small: **5.11:1** ✅

ทุกค่า ≥4.5:1 ตาม WCAG AA — ตรงกับที่ AI Debug Engineer รายงานทุกตัวเลข

**Orphan hex check**: `grep -n "f7f7f8" web/app/chat-notes.css` เหลือจุดเดียว (บรรทัด 75,
`.flutter-chat-search` — คนละ selector คนละ scope ไม่เกี่ยวกับ WYN-173) ยืนยันว่า `.wyn-note-info-card` ไม่มี
hardcode หลงเหลือแล้ว

**Regression**: `npm run check` (lint + typecheck + build): 0 error, 3 warning เดิมที่ไม่เกี่ยวข้อง

**Final Status: PASS** — WYN-171, WYN-172, WYN-173 ผ่าน QA ครบทั้ง 3 เรื่อง พร้อมส่งต่อ AI Deploy & DevOps
