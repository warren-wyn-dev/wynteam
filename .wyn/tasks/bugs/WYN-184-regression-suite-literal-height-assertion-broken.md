# Bug Report — WYN-184

Status: closed — verified fixed by AI QA & Security (2026-09-20)
Owner: AI Debug Engineer

Bug:
`web/tests/browser/parity.spec.ts:162` ยืนยัน (literal substring match) ว่า `web/app/profile-golden-final.css` ต้องมีสตริง `"height: 52px"` อยู่จริง — commit `568997d2af3945114fb697824119285034096297` (WYN-184) แก้ `.wyn-profile-topbar` จาก `height: 52px;` เป็น `height: calc(52px + env(safe-area-inset-top));` ทำให้สตริง `"height: 52px"` ไม่ปรากฏใน CSS ไฟล์นี้อีกต่อไป (grep ยืนยัน) ส่งผลให้ test นี้ **fail ทั้ง 3 browser project** (`webkit-iphone`, `chromium-android`, `chromium-desktop`) — ไม่ใช่ pre-existing baseline failure (ไม่เกี่ยวกับ `chromium_headless_shell` binary ที่ขาดหาย) เป็น regression ที่เกิดจาก diff ของ WYN-184 โดยตรง 100%

Reproduction:
1. Checkout commit `568997d2` ใน `web/`
2. `npm install && npx playwright install chromium chromium-headless-shell webkit`
3. `npx playwright test tests/browser/parity.spec.ts -g "source contracts cannot regress" --project=chromium-desktop`
4. ผลลัพธ์: FAIL ที่บรรทัด `tests/browser/parity.spec.ts:162:106` —
   ```
   for (const metric of ["font-size: 17px", "min-height: 44px", "height: 52px"])
     expect(profileGoldenCss).toContain(metric);
   ```
   `expect(profileGoldenCss).toContain("height: 52px")` ล้มเหลว เพราะไฟล์จริงตอนนี้มีแต่ `"height: calc(52px + env(safe-area-inset-top))"` (grep ยืนยัน: `grep -n "height: 52px" web/app/profile-golden-final.css` → ไม่มีผลลัพธ์)
5. รันเต็ม suite (`npx playwright test`) ยืนยันซ้ำ: **3 failed / 156 passed** — ทั้ง 3 failure คือ test เดียวกันนี้ x 3 browser project เท่านั้น ไม่มี failure อื่น

Root Cause:
`parity.spec.ts:162` เขียนเป็น literal string assertion ที่ hardcode ค่า `"height: 52px"` ของ `.wyn-profile-topbar` ไว้เป็น regression guard (เดิมมีไว้กันไม่ให้ header กลับไปใช้ดีไซน์ cover-photo เก่าที่สูง 170px — ดู `expect(profileGoldenCss).not.toContain("height: calc(170px")` บรรทัดก่อนหน้า) แต่ assertion นี้ไม่ทนต่อการเปลี่ยน `height: 52px` เป็นสูตรที่ถูกต้องตาม safe-area (`calc(52px + env(safe-area-inset-top))`) ซึ่งเป็นการเปลี่ยนแปลงที่ Founder อนุมัติแล้วและถูกต้องตาม spec ของ WYN-184 — CSS ปัจจุบันถูกต้อง แต่ test ยัง hardcode ค่าเก่าที่ไม่ทันการเปลี่ยนแปลงที่ตั้งใจนี้

**AI Coding ไม่ได้รัน regression suite จริง (`web/tests/browser/`)** ก่อนส่ง QA — validation ที่รายงานไว้มีแค่ `npm run lint`/`typecheck`/`build` (`npm run check`) และ ad hoc Playwright harness ของตัวเอง (`__wyn184-safe-area-check.mjs`) ซึ่งไม่ครอบคลุม `tests/browser/parity.spec.ts` เลย จึงไม่จับ regression นี้ได้ก่อนส่งมอบ

Fix (เสนอ ไม่ใช่คำสั่งบังคับรูปแบบเดียว — ให้ AI Debug Engineer/AI Coding เลือกวิธีที่เหมาะสมที่สุด):
อัปเดต assertion ที่ `web/tests/browser/parity.spec.ts:162` ให้ยอมรับ formula ใหม่แทนค่าคงที่เดิม เช่น เปลี่ยน `"height: 52px"` เป็น `"height: calc(52px + env(safe-area-inset-top))"` (ตรงกับ CSS ปัจจุบันเป๊ะ) หรือใช้ regex/substring ที่ยืดหยุ่นกว่า (เช่น เช็คแค่ `"52px"` ปรากฏใน context ของ `.wyn-profile-topbar` height) — **ห้ามแก้กลับ CSS ให้ตรงกับ test เดิม** เพราะ `height: 52px` แบบไม่มี safe-area คือบั๊กที่ WYN-184 เพิ่งแก้ไปตาม Founder approval (ตรวจแล้วว่าถูกต้องด้วย live CDP verification จาก QA)

Files Changed (ที่ควรแก้): `web/tests/browser/parity.spec.ts` (บรรทัด 162 เท่านั้น — ไม่แตะไฟล์ CSS ที่ WYN-184 แก้ไปแล้ว เพราะถูกต้องแล้ว)

Tests: หลังแก้ต้องรัน `npx playwright test tests/browser/parity.spec.ts` ยืนยันผ่านทั้ง 3 project และรัน `npx playwright test` เต็ม suite ยืนยัน 0 failed ก่อนส่งกลับ QA

Regression Risk: ต่ำ — เป็นการแก้ test assertion ให้ตรงกับ CSS ที่ถูกต้องอยู่แล้ว ไม่กระทบ production code

Handoff to QA: หลังแก้แล้วให้ AI QA & Security รัน `npx playwright test` เต็ม suite อีกรอบอิสระ ยืนยัน 0 failed ก่อนอนุมัติเข้า Deploy gate — ไม่ต้องตรวจซ้ำ cascade/safe-area ของ 2 จุด CSS อีก (ตรวจผ่านแล้วในรอบ QA นี้ ไม่มี discrepancy)

## Fix Applied (AI Debug Engineer, 2026-09-20)

แก้ตาม fix ที่เสนอไว้เป๊ะ: เปลี่ยน literal string ใน `web/tests/browser/parity.spec.ts:162` จาก `"height: 52px"` เป็น `"height: calc(52px + env(safe-area-inset-top))"` (ตรงกับ CSS ปัจจุบันของ `.wyn-profile-topbar` เป๊ะ) ใช้ pattern เดียวกับ assertion อื่นที่มีอยู่แล้วในโค้ดเบสสำหรับเช็ค safe-area formula แบบ exact substring (`final-source-parity-gate.spec.ts:41`, `system-visual-parity.spec.ts:250`) ไม่ได้เปลี่ยนเป็น regex หรือ pattern ใหม่ ไม่แตะไฟล์ CSS ใดเลย (`profile-golden-final.css`, `chat-notes.css` ไม่มีการเปลี่ยนแปลง)

**ตรวจ stale assertion อื่นเพิ่มเติม**: grep ทั้ง `web/tests/browser/` หา `wyn-profile-topbar`, `flutter-chat-header`, `52px`, `68px` — พบอีกจุดที่มี literal `"height: 52px"` คือ `parity.spec.ts:204` แต่เป็นของ `completionCss` (`app/parity-completion.css`, `.club-list-avatar`) ซึ่งไม่เกี่ยวกับ WYN-184 และไม่ได้ถูกแตะ ยังผ่านปกติ ไม่ใช่ stale assertion — ไม่มี test ไฟล์ไหนอ้างอิง `.wyn-profile-topbar` โดยตรงนอกจาก `parity.spec.ts:162` และไม่มี assertion ใน `system-visual-parity.spec.ts` (ซึ่งอ่าน `chat-notes.css` เก็บไว้ในตัวแปร `notesCss`) ที่เช็ค `height`/`padding` ของ `.flutter-chat-header` เลย — สรุป: มี stale assertion จุดเดียวจริงตามที่รายงานไว้ ไม่มีจุดอื่นที่ต้องแก้เพิ่ม

**Tests after fix**:
- `npx playwright test tests/browser/parity.spec.ts -g "source contracts cannot regress"` — 3/3 pass (ทั้ง 3 browser project, จากที่ fail ทั้ง 3 ก่อนแก้)
- Full regression suite `npx playwright test` — **159 passed, 0 failed** (clean baseline เต็ม ไม่มี pre-existing `chromium_headless_shell` failure เพราะ binary มีอยู่แล้วที่ `/opt/pw-browsers`)
- `npm run check` (`lint`+`typecheck`+`build`) — ผ่านสะอาด 0 error (warning 3 จุดเดิม ไม่เพิ่มใหม่)

Files Changed: `web/tests/browser/parity.spec.ts` เท่านั้น (1 บรรทัด)

Regression Risk: ต่ำมาก — test-only, แก้ literal string ให้ตรงกับ CSS ที่ถูกต้องอยู่แล้ว ไม่กระทบ production code

Handoff: → **AI QA & Security** ตรวจซ้ำอิสระก่อนเข้า Deploy gate — ยืนยัน `npx playwright test` เต็ม suite 159/159 ด้วยตัวเอง (ไม่ต้องตรวจซ้ำ cascade/safe-area ของ 2 จุด CSS อีก — QA รอบก่อนหน้ายืนยันสมบูรณ์แล้ว)

## QA Re-verification (AI QA & Security, 2026-09-20)

ยืนยันอิสระที่ commit `eb9c2fa8` (HEAD ปัจจุบันของ branch): `git show eb9c2fa8 -- web/tests/browser/parity.spec.ts` มีการเปลี่ยนแค่บรรทัด 162 จริงตามที่อ้าง (`"height: 52px"` → `"height: calc(52px + env(safe-area-inset-top))"`) ไม่แตะ CSS ไฟล์ใดเลย (`git diff 568997d2 eb9c2fa8 -- web/app/profile-golden-final.css web/app/chat-notes.css` ว่างเปล่า) รัน `npx playwright test` เต็ม suite เองอิสระ (ไม่เชื่อคำอ้าง) ได้ **159 passed, 0 failed** grep ยืนยันอิสระด้วยว่าไม่มี stale assertion อื่นที่อ้างอิง `.wyn-profile-topbar`/`.flutter-chat-header` ค้างอยู่ใน `web/tests/browser/` ตรงตามที่ AI Debug Engineer อ้าง typecheck/lint/build สะอาดทั้งหมด — รายละเอียดเต็มที่ `.wyn/tasks/active/WYN-184-non-sticky-header-safe-area-audit.md` ("## QA Re-verification")

**Final Status: PASS** — บั๊กนี้ปิดแล้ว ยืนยัน fix ถูกต้องสมบูรณ์
