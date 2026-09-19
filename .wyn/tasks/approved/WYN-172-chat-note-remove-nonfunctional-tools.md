# Design Task — WYN-172

Status: implemented and verified — PASS by AI QA & Security, พร้อม Deploy
Owner: AI Design → Founder → AI Debug Engineer → รอ QA
Screen: WYNOS Web Chat Inbox — Note Composer (`web/components/chat-inbox-parity.tsx`,
`web/app/chat-notes.css`)
Purpose: เอาปุ่ม "สถานที่"/"อีโมจิ" ในหน้าเขียนโน้ตออก เพราะพบระหว่าง audit ฟังก์ชันโน้ต (2026-09-19) ว่า
ปุ่มทั้งสองไม่มี `onClick` ใดๆ เลย — กดแล้วไม่ทำอะไร แต่มี `aria-label` ทำให้ screen reader ประกาศราวกับใช้
งานได้จริง เป็นการหลอกผู้ใช้ (pattern เดียวกับที่ AI Design ปฏิเสธไม่เพิ่มปุ่ม filter ปลอมใน WYN-170)
User Flow: ไม่เปลี่ยนฟังก์ชันหลัก (พิมพ์โน้ต/แชร์/ลบยังทำงานเหมือนเดิมทุกประการ) แค่เอา UI ที่ไม่ทำงานออก
Components: เอา `<div className="wyn-note-tools">` ทั้งบล็อก (ปุ่ม "สถานที่" + "อีโมจิ") ออกจาก
`chat-inbox-parity.tsx`, เอา CSS ที่เกี่ยวข้องออกจาก `chat-notes.css` (`.wyn-note-tools`, `.wyn-note-tool`,
`.wyn-note-tool > span`, `.wyn-note-tool small`) รวมถึง responsive override ที่เกี่ยวข้อง
(`@media (max-height: 760px)` มี `.wyn-note-tools { margin-top: 14px }` ต้องเอาออกด้วย)
Interactions: ไม่มี (ลบ UI ที่ไม่มี interaction อยู่แล้วออก)
States: ไม่มีผลต่อ state ใดๆ ของ composer (ไม่แตะ noteDraft/noteSaving/noteOpen)
Responsive Behavior: หลังเอาออก ต้องตรวจว่า layout ของ `.wyn-note-stage` (avatar + editor) ยังดูสมดุลดี
ไม่เหลือช่องว่างแปลกๆ ด้านล่าง — ถ้าดูโหว่เกินไป ให้ปรับ spacing เล็กน้อยได้ (เช่น `padding-bottom` ของ
`.wyn-note-stage`) แต่ไม่ต้องรื้อ layout ใหม่
Accessibility: การลบปุ่มที่ไม่ทำงานออกทำให้ accessibility ดีขึ้นเอง (screen reader จะไม่ประกาศปุ่มหลอกอีก
ต่อไป)
Design Rules: ไม่ประดิษฐ์ปุ่ม/ฟีเจอร์ใหม่มาแทน ถ้า Founder อยากได้ฟีเจอร์ตำแหน่ง/อีโมจิจริงในอนาคต ต้องเป็น
งานแยกที่ผ่าน Product Manager ก่อน (เป็นฟีเจอร์ใหม่ ไม่ใช่แค่ UI cleanup)
Handoff: พร้อมส่ง Coding ทันที รวมไปกับ WYN-171 (ไฟล์เดียวกัน คนละจุดในไฟล์ ไม่ทับซ้อนกัน) ความเสี่ยง
regression ต่ำมาก (ลบ UI ที่ไม่เคยมีการเรียกใช้ logic ใดๆ)

## Resolution (AI Debug Engineer, 2026-09-19)

**Implementation**: ยืนยันก่อนแก้ด้วย `grep -n "wyn-note-tools\|wyn-note-tool"` ว่าปุ่มทั้งสองไม่มี
`onClick` ใดๆ จริงตามที่ AI Design รายงาน จากนั้นลบ:

- `web/components/chat-inbox-parity.tsx`: ลบ JSX block `<div className="wyn-note-tools">...</div>`
  (ปุ่ม "สถานที่" + "อีโมจิ") ทั้งหมด — ไม่แตะ `noteOpen`/`noteDraft`/`noteSaving`/`openMyNote`/`saveNote`/
  `removeNote`/`writeMyNote` เลย (ฟังก์ชันหลักไม่เปลี่ยน)
- `web/app/chat-notes.css`: ลบ `.wyn-note-tools`, `.wyn-note-tool`, `.wyn-note-tool > span`,
  `.wyn-note-tool small` และ responsive override `@media (max-height: 760px) { .wyn-note-tools {
  margin-top: 14px } }` ครบทุกจุด

**Spacing adjustment (authorized in task file above)**: หลังลบแล้วเช็ค layout ของ `.wyn-note-stage`
พบช่องว่างด้านล่างเกินไปจริงตามที่คาด — ปรับ `min-height` ลงตามสัดส่วนเดิม (ไม่ได้รื้อ layout ใหม่):
- Base: `318px → 240px`
- `@media (max-height: 760px)`: `285px → 210px`

**Verification**: `grep -rn "wyn-note-tool"` หลังแก้ → ไม่พบ reference เหลือทั้งใน `.tsx` และ `.css`
(ไม่มี orphaned CSS/JSX) `npm run check` ผ่านทั้งหมด (lint + typecheck + build), 0 error

**Commit**: `21bbef58` บน branch `claude/ux-ui-button-design-ult3lz` (รวมกับ WYN-171)

**ส่งต่อ**: AI QA & Security เพื่อยืนยันว่าปุ่มหายไปจริงไม่มี orphan และ flow พิมพ์/แชร์/ลบโน้ตยังทำงานปกติ

## QA Verification (AI QA & Security, 2026-09-19)

- `grep -rn "wyn-note-tool" web/components web/app --include="*.tsx" --include="*.css"` → ไม่พบเลย (ไม่มี
  orphaned JSX/CSS หลงเหลือ) ✅
- ตรวจ diff ของ commit `21bbef58` ตรง — ลบ JSX block ครบ, ลบ CSS ครบทั้ง 4 selector + responsive override ✅
- `.wyn-note-stage` วัดจริงด้วย Playwright: `min-height` = 240px (ปกติ), 210px (`@media max-height:760px`)
  ตรงกับที่รายงาน ไม่มี layout โหว่ผิดปกติ ✅
- ตรวจ core logic composer (`openMyNote`/`saveNote`/`removeNote`/`writeMyNote`/`NOTE_MAX_LENGTH`/
  `NOTE_LIFETIME_MS`) ทั้งหมดยังอยู่ครบ ไม่ถูกแตะเลย ตรงกับ diff ที่มีแค่ 11 บรรทัดลบใน `.tsx` (JSX บล็อกเดียว)
  ✅
- `npm run check` (lint + typecheck + build): 0 error, มีแค่ 3 warning เดิมที่ไม่เกี่ยวข้อง ✅

**Final Status: PASS**
