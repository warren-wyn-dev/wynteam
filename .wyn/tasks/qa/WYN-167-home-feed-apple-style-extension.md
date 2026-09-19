# Design Task — WYN-167

Status: implemented (AI Coding) — waiting for AI QA & Security
Owner: AI QA & Security
Screen: WYNOS Web Home Feed (`/home`, `web/components/home/*.tsx`, `web/app/home.css`)
Purpose: ขยายภาษา interaction motion จาก WYN-163 (Apple-style press-scale) มาที่ Home feed ตามแผน rollout
เดิมของ WYN-160 (ลำดับที่ 3: Home/Bottom Nav ต่อจาก Auth) — ขอบเขตแคบมาก: เพิ่ม press feedback ให้ปุ่ม
"ติดตาม" + ไอคอน header 3 ปุ่ม และทำเส้นใต้แท็บให้ animate แทนสลับทันที ไม่แตะขนาด/สี/spacing/layout ใดๆ
User Flow: ไม่เปลี่ยน
Components: `.wyn-post-follow-pill`, `.wyn-home-header-action`, `.wyn-home-tab-indicator` (ทั้งหมดประกาศใน
`web/app/home.css` เท่านั้น ไม่ใช้ร่วมกับหน้าอื่น — ยืนยันด้วย grep แล้ว)
Interactions: press-scale `transform: scale(0.96)` (สูตรเดียวกับ WYN-163) บน 2 ปุ่มแรก, animate transition
บนเส้นใต้แท็บ
States: เพิ่ม pressed state ใหม่ 2 จุด
Responsive Behavior: ไม่เปลี่ยน
Accessibility: เพิ่ม `prefers-reduced-motion` fallback ทั้ง 3 จุด (ปัจจุบัน `home.css` ไม่มีเลย)
Design Rules: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-167-home-feed-apple-style-extension.md` — **ไม่แตะ**
`.route-primary`/`.route-secondary` (ใช้ร่วม 13 ไฟล์ทั่วแอป, นอกขอบเขต), **ไม่แตะ** action row (มี press
feedback ดีอยู่แล้ว), **ไม่แตะ** ขนาด/radius/สี ของ Home (คง compact/conversation-first ไว้ตามเจตนาเดิม)
Handoff: พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติ scope — ไฟล์เดียว (`web/app/home.css`), ความเสี่ยง
regression ต่ำมาก (เพิ่ม CSS transition/`:active` ล้วนๆ)

## คำถามรอ Founder ตอบ

1. ~~เห็นด้วยกับขอบเขตนี้ไหม~~ **Founder ตอบแล้ว: "เห็นด้วยกับขอบเขตนี้ ทำได้เลย"**
2. อยากขยาย `.route-primary`/`.route-secondary` (ใช้ทั่วแอป 13 หน้าจอ) เป็นงานถัดไปด้วยไหม หรือเก็บไว้ทีหลัง?
   (ยังไม่ได้ถามซ้ำ — ยังไม่ใช่ scope ของรอบนี้)

## Implementation (2026-09-19, AI Coding)

แก้ไฟล์เดียว `web/app/home.css` เพิ่ม CSS ล้วนๆ ไม่แตะ `.tsx` ไฟล์ไหนเลย (class name ครบอยู่แล้ว):

1. `.wyn-home-header-action` — เพิ่ม `transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1)` +
   `:active { transform: scale(0.96) }` (สูตรเดียวกับ WYN-163 เป๊ะ)
2. `.wyn-post-follow-pill` — เพิ่มแบบเดียวกัน
3. `.wyn-home-tab-indicator` — **ปรับจากที่ spec เขียนไว้เล็กน้อย**: spec เดิมสื่อว่าจะ "เลื่อนตำแหน่ง" (สื่อถึง
   sliding transform) แต่ตรวจโครงสร้าง DOM จริงแล้วพบว่าเส้นใต้แท็บไม่ใช่ element เดียวที่เลื่อนไปมา — แต่ละ
   แท็บมี indicator ของตัวเองแยกกัน (`width: 120px` คงที่ทุกอัน) แค่สลับ `background-color` ระหว่างโปร่งใส/
   ดำ ตาม `.is-active` เท่านั้น ("เลื่อนตำแหน่ง" จริงๆ ไม่มีอะไรให้เลื่อน) จึงปรับเป็น **animate
   `background-color` transition (220ms)** แทน ให้เอฟเฟกต์ fade แทนการสลับสีทันที — ตรงเจตนาเดิม
   ("ไม่ให้สลับทันที") แต่ไม่ต้องรื้อโครงสร้าง component ใหม่ (ซึ่งจะเพิ่มความเสี่ยง regression เกินขอบเขตที่
   อนุมัติไว้)
4. เพิ่ม `@media (prefers-reduced-motion: reduce)` ท้ายไฟล์ ปิด transition ทั้ง 3 จุด

**Verification**: `npm run typecheck`/`lint`/`build` ผ่านหมด (0 error, 3 pre-existing warning เดิม) ทดสอบผ่าน
Playwright จริงบน dev server (`/dev/home-fixture`, `playwright-core` + `/opt/pw-browsers/chromium` — sandbox
นี้ยังรัน `@playwright/test` runner เองไม่ได้เหมือนทุกรอบก่อนหน้า):
- ยืนยัน `getComputedStyle().transition` ของทั้ง 3 selector ตรงตามที่ใส่ไว้
- สลับแท็บไปมาได้ปกติ ไม่มี console error
- ยืนยันด้วย `reducedMotion: "reduce"` emulation ว่า `transitionDuration` กลายเป็น `0s` ทั้ง 3 จุดจริง
- Screenshot ก่อน/หลังเหมือนกันทุกพิกเซล (ตามคาด — งานนี้เปลี่ยนแค่ความรู้สึกตอนโต้ตอบ ไม่เปลี่ยนภาพนิ่ง)

**Files Changed**: `web/app/home.css` เท่านั้น

**Regression Risk**: ต่ำมาก — เพิ่ม CSS transition/`:active`/`@media` ล้วนๆ ไม่แตะ layout, class ที่ใช้ร่วมกับ
หน้าอื่น, หรือ business logic ใดๆ

**Handoff to QA**: ตรวจว่า 3 จุดกดแล้วรู้สึกได้จริงบนอุปกรณ์จริง/emulate, ตรวจ `prefers-reduced-motion`
ทำงานถูก, ตรวจว่าไม่มี regression กับหน้าอื่นที่ใช้ `home.css` ร่วม (ตรวจแล้วว่าไม่มีไฟล์อื่นใช้ 3 class นี้
แต่ QA ควรยืนยันซ้ำอิสระ), sweep console error หน้า Home + หน้าอื่นที่เกี่ยวข้อง
