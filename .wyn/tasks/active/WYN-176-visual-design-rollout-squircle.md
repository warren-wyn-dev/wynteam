# Product Task — WYN-176

Status: batch 1 DONE (deployed + Founder ยืนยัน production แล้ว "ชอบผ่าน", 2026-09-19); batch 2+ (Composer/Chat/Profile/Search/Notifications/Club) ยังไม่เริ่ม — WYN-176 โดยรวมยังเป็น active จนกว่าจะครบทุก batch
Owner: AI Product Manager → AI Design (batch 1 เสร็จ) → AI Coding (batch 1 เสร็จ) → AI QA & Security (batch 1 PASS) → AI Deploy & DevOps (batch 1 deploy สำเร็จ) → Founder (ยืนยัน batch 1 แล้ว)
Feature: WYNOS Web Beta1 — Visual Design Rollout (WYN-174 Track 2) — extend WYN-163's Apple-style squircle direction system-wide
Goal: Make the rest of WYNOS Web (Home, Composer, Chat, Profile/Settings, Search/Notifications/Club) visually consistent with the Auth screens' Apple-style redesign (WYN-163), instead of the app looking like two different products depending on which screen you're on
Target User: All WYNOS Web users — the whole app, not just onboarding
Problem: this is a continuation/reconciliation of two prior efforts, not a fresh redesign:

1. **WYN-160** (2026-09-17) set out to consolidate ~20 stray font-size/border-radius values into a 7/5-value scale across the whole web app, in 8 sequenced batches. Batches 1-6 (tokens, Auth, Home/Nav, Composer, Chat, Profile/Settings) shipped. Batch 7 (Search/Notifications/Club) and batch 8 (dead CSS cleanup) never happened — the task file is still sitting in `.wyn/tasks/backlog/`.
2. **WYN-163** (2026-09-19, two days after WYN-160 batch 6) redesigned Auth specifically, and picked *different, bigger* values than WYN-160's original targets after the Founder rejected the first attempt as "เหมือนแอปอื่นเลย": buttons `24px radius / 58px height / 16px-700 text` (not WYN-160's `999px pill`), inputs `18px radius / 56px height` (not WYN-160's `10px`), screen headlines `32px/800` (not WYN-160's `20px title`), plus a new spring-ish press-feedback (`scale(0.96)`, 160ms cubic-bezier). WYN-163's own design doc flagged this exact gap in advance (Design Rule #9): "ถ้าจะขยายทั้งเว็บต้องเป็นงานแยก" (extending this everywhere would need to be its own task) — that task is this one.

**Net effect right now**: Auth screens (`/welcome`, `/login`, `/signup/*`, `/onboarding/profile`, `/forgot-password`) look meaningfully bigger/bolder than every other screen in the app, which still carries WYN-160's older, more conservative values. Search/Notifications/Club never got *either* pass and still have the original ~20-value drift WYN-160 was written to fix.

## Requirements

Two things need Founder confirmation before AI Design starts (see Recommendation): whether WYN-163's values become the new system-wide target (superseding WYN-160's original numbers for buttons/inputs/headlines), and which batch to do first.

Assuming WYN-163 tokens become the system-wide target, the remaining work is:

- **Re-apply with new values**: Home/Bottom Nav, Composer, Chat, Profile/Settings — already consolidated once under WYN-160's older numbers, now need the WYN-163 button/input/headline values applied on top (colors/spacing/other radii from WYN-160 stay — only the squircle-specific numbers change)
- **First-time consolidation with new values**: Search, Notifications, Club — never got either pass, go straight to WYN-163's numbers, skip WYN-160's superseded intermediate values entirely
- **Known parity exception** (from WYN-160 batch 3): Home's post card already mirrors Flutter's `home_drop_card.dart` 1:1 for cross-platform visual parity and has its own locked tests — do not force the 7-value font scale or squircle radii onto it; this was correctly left alone before and should stay that way unless Founder explicitly asks to break Flutter parity
- **Batch 8 (dead CSS cleanup)** from WYN-160's original plan still applies once everything above lands

## Acceptance Criteria

- Every batch gets a before/after visual preview approved by Founder before AI Coding touches it (per the standing rule from WYN-141/WYN-160: "roll out in batches, never a single sweeping refactor," and the general "UI ใหม่ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด" rule)
- No batch changes business logic, Supabase contracts, or existing feature behavior — visual/token layer only
- Home's Flutter-parity-locked post card is not touched unless Founder explicitly says to break parity
- Each batch passes QA (functional + visual regression, screen-reader/contrast spot check) before moving to the next
- `prefers-reduced-motion` respected wherever the new press-feedback spring is applied (same pattern as WYN-163/WYN-175)

## Dependencies

- WYN-160 (`.wyn/docs/design/wyn-160-web-design-system-consolidation.md`, `.wyn/tasks/backlog/WYN-160-web-design-system-consolidation.md`) — this task effectively completes and supersedes it; WYN-160's task file should close into this one once Founder confirms
- WYN-163 (`.wyn/docs/design/wyn-163-onboarding-button-redesign.md`) — source of the token values being extended
- WYN-175 (`.wyn/tasks/completed/WYN-175-web-perceived-speed-motion.md`) — the press-feedback/motion utility pattern this can reuse for the spring-press interaction

## Priority

Founder-selected P0 (WYN-174 Track 2) — was blocked on WYN-163 finalizing, which it now has (deployed and Founder-confirmed 2026-09-19)

## Risks

- **Largest-scope track in WYN-174** — touches nearly every screen in the app across several batches; the batch-by-batch + visual-preview discipline exists specifically to keep this from becoming one risky sweeping change
- Token conflict between WYN-160 and WYN-163 could cause confusion if not explicitly reconciled with Founder first — doing so before any code avoids re-doing a batch twice
- Home's post card has a real, tested Flutter-parity lock — accidentally touching it would break cross-platform visual consistency and locked regression tests

## Recommendation

Two decisions before AI Design starts:
1. **Confirm WYN-163's tokens (24px/58px button, 18px/56px input, 32px/800 headline, scale(0.96) press) become the system-wide standard**, replacing WYN-160's original (never-shipped-everywhere) numbers for those same properties
2. **Confirm batch order** — recommend continuing WYN-160's original sequence (Home/Nav next, since Auth is done), but Search/Notifications/Club could go first instead since those screens never got any consolidation pass at all and are the rawest gap

## Handoff

**[2026-09-19] Founder ยืนยันแล้วทั้ง 2 จุด**: (1) ใช้ค่า WYN-163 เป็นมาตรฐานทั้งเว็บ แทนค่าเดิมของ WYN-160 (2) เริ่ม batch **Home/Bottom Nav** ก่อน (ต่อลำดับเดิมของ WYN-160)

→ **AI Design**: ทำ batch 1 (Home/Bottom Nav) — audit CSS จริงของหน้า Home/Nav (เทียบ cascade เต็มเหมือนที่ WYN-175 ทำ ไม่ใช่แค่ rule แรกที่เจอ), แยกให้ชัดว่าจุดไหนเป็น Bottom Nav (แก้ได้) vs การ์ดโพสต์ที่ล็อก Flutter parity (ห้ามแตะ), ทำภาพก่อน-หลังด้วย token ใหม่จาก WYN-163 (ปุ่ม 24px/58px/16px-700, input 18px/56px, หัวข้อ 32px/800, press scale 0.96) ให้ Founder อนุมัติก่อนส่ง AI Coding

## Batch 1 Implementation (AI Coding, 2026-09-19)

**Implementation**: ตรวจ full cascade ของทุก selector ที่จะแก้ก่อน (เรียนบทเรียนจาก WYN-175 bug) ไม่พบ override ที่จะทำให้ค่าใหม่ไม่ได้ผล:
1. `.drawer-identity` — radius 18→20px + press feedback spring (`scale(0.96)`, 160ms cubic-bezier) (`app/parity-final.css`)
2. `.drawer-menu-row` — radius 14→16px + press feedback (`app/parity-final.css`)
3. `.home-drawer-close .icon-button` — press feedback เพิ่ม (ไม่เคยมี) (`app/parity-final.css`)
4. `.audit-sheet-row` (share/save/hide/report) — press feedback เพิ่ม (`app/parity-audit.css`)
5. `.route-primary`/`.route-secondary`/`.route-pill`/`.route-more` — press feedback เพิ่ม (ใช้ร่วมกับ Search/Notifications ด้วย) (`app/phase3.css`)

**ตั้งใจไม่แตะ**: `.wyn-redrop-sheet-option`/`.wyn-redrop-sheet-cancel` — ตรวจแล้วมี press feedback ของตัวเองอยู่แล้ว (`scale(0.992)` + `filter: brightness`, สไตล์ต่างจาก spring ของ WYN-163 โดยตั้งใจ) ไม่ได้อยู่ใน "ตอนนี้" ที่ Artifact แสดงไว้ตรงๆ จึงไม่แก้ทับของเดิมที่ทำงานอยู่แล้วโดยไม่มีการอนุมัติใหม่ (smallest safe change) — `.wyn-home-header-action` (ปุ่ม header) ก็ไม่ต้องแก้เพราะมี press feedback สเปกเดียวกันเป๊ะอยู่แล้วจาก WYN-167

**Files Changed**: `web/app/parity-final.css`, `web/app/parity-audit.css`, `web/app/phase3.css`

**Reason**: ตาม design spec `.wyn/docs/design/wyn-176-batch1-home-chrome.md`, Founder อนุมัติ preview แล้ว

**Tests**: สร้าง harness ยืนยันด้วย Playwright จริง (โหลด CSS ทั้ง 38 ไฟล์ตามลำดับ import จริงใน `layout.tsx`) — ตรวจ radius คำนวณจริง 2 จุด + press feedback จริงด้วย mouse down/up 8 จุด + ยืนยัน `.wyn-redrop-sheet-option` ยังมี feedback เดิมไม่ถูกทับ + `prefers-reduced-motion` ปิด transition ได้จริง — **12/12 ผ่าน**

**Build**: `npm run typecheck` (0 errors), `npm run lint` (0 errors, warning เดิม 3 จุดไม่เกี่ยวข้อง), `npm run build` (สำเร็จทุก route) — ตรวจ `git diff --stat` ยืนยันว่าไม่ได้แตะ `home.css`/`bottom-nav.css` (ไฟล์ที่ล็อก Flutter parity) เลยแม้แต่บรรทัดเดียว

**Known Issues**: batch 1 นี้ครอบคลุมแค่ Home chrome (เมนูลิ้น/sheet/retry button) — Composer, Chat, Profile/Settings, Search/Notifications/Club ยังเป็น batch ถัดไปที่ยังไม่เริ่ม (ดู WYN-176 scope เต็ม)

**Handoff**: → **AI QA & Security** ตรวจ: (1) radius/press feedback ตรงตาม spec จริงบน dev server ไม่ใช่แค่ harness แยก (2) เมนูลิ้นที่ใช้ร่วมกับ Notifications ก็ได้ผลด้วย (ตรวจทั้ง `/` และ `/notifications`) (3) ไม่มี regression ต่อการ์ดโพสต์/bottom nav (Flutter parity test เดิมต้องผ่านหมด) (4) `wyn-redrop-sheet-option` ยังทำงานเหมือนเดิมไม่เปลี่ยน

## QA Batch 1 (AI QA & Security, 2026-09-19)

**Test Cases**: ไม่เชื่อผลที่ AI Coding รายงานเอง ทำ harness แยกใหม่ทั้งหมด — (1) console/HTTP error sweep บน `/`, `/notifications`, `/search`, `/welcome` ด้วย dev server จริง (2) radius คำนวณจริง 2 จุด ผ่าน full CSS cascade (38 ไฟล์ตามลำดับ import จริง) (3) press feedback จริงด้วย mouse down/up 8 จุด + ตรวจว่า release กลับเป็น `none` ถูกต้อง (4) ยืนยัน `wyn-redrop-sheet-option`/`.wyn-home-header-action` ไม่ถูกแตะ/ทับ (5) `prefers-reduced-motion` ปิด transition 4 จุด (6) ตรวจ `parity.spec.ts` (source-parity gate เดิม) ว่าอ้างอิงแค่ text content ของ `.tsx` ไม่ใช่ CSS computed value — ยืนยันว่า diff รอบนี้แตะแค่ไฟล์ CSS ไม่แตะ `.tsx` เลย จึงไม่มีความเสี่ยงต่อ parity test เดิม (7) `typecheck`/`lint`/`build` อิสระใหม่

**Passed**: 32/32 (console/HTTP 8 + radius 2 + press feedback 16 + unchanged-behavior 2 + reduced-motion 4) + lint/typecheck/build สะอาดหมด

**Failed**: ไม่มี

**Severity**: N/A

**Security Findings**: ไม่มี — CSS-only diff ไม่แตะ logic/data/auth

**Recommendation**: Approve batch 1 — เข้า Deploy gate ปกติ

**Final Status: PASS**

Batch 1 PASS — ส่งต่อ AI Deploy & DevOps deploy เฉพาะ batch 1 นี้ก่อน (ไม่ย้าย task ไป `approved/` ทั้งไฟล์ เพราะ WYN-176 เป็น multi-batch task ยังมี batch อื่นค้างอยู่ — ตาม pattern เดียวกับ WYN-160 ที่แต่ละ batch deploy แยกกันแต่ task หลักยังอยู่ active จนกว่าจะครบทุก batch)

## Batch 2 Implementation (AI Coding, 2026-09-19)

**Implementation**: เพิ่ม press feedback spring (`scale(0.96)`, 160ms cubic-bezier เดียวกับ WYN-163) ให้ 8 จุดที่ยังไม่มีเลย — ไม่แก้ radius/ขนาดใดๆ (WYN-160 batch 4 ทำไปแล้วตรง target scale):
1. `.beta4-cancel` / `.beta4-post` — ปุ่ม header ยกเลิก/โพสต์ (`app/system-parity-final.css`)
2. `.beta4-add-option` — ลิงก์เพิ่มตัวเลือกโพล (`app/system-parity-final.css`)
3. `.beta4-ratio-chips button` — chip อัตราส่วนรูป (`app/system-parity-final.css`)
4. `.beta4-image-preview > button` — ปุ่มลบรูป (`app/system-parity-final.css`)
5. `.quickAction` — 4 ปุ่ม quick action (ผู้ชม/รูป/กล้อง/โพล) (`components/beta4-composer-refresh.module.css`)
6. `.audienceOption` — แถวเลือกผู้ชมใน sheet (`components/beta4-composer-refresh.module.css`)
7. `.sheetHeader button` — ปุ่มปิด audience sheet (`components/beta4-composer-refresh.module.css`)

ตรวจ cascade ก่อนแก้ทุก selector พบว่า `.beta4-cancel`/`.beta4-post`/`.beta4-add-option`/`.beta4-ratio-chips button`/`.beta4-image-preview > button` มีนิยามซ้ำ 2 จุดในไฟล์เดียวกัน (ค่าที่สองทับค่าแรกบางส่วน) — เพิ่ม press feedback rule ไว้หลังนิยามที่ชนะจริงเพื่อไม่ให้ถูกทับ, ยืนยันว่า `.beta4-toolbar-actions`/`.beta4-audience-row` เป็น dead code จริง (ไม่มีการอ้างอิงใน `.tsx`) ไม่แตะ

**Files Changed**: `web/app/system-parity-final.css`, `web/components/beta4-composer-refresh.module.css` — diff เป็น additive ล้วนๆ (ไม่มีบรรทัดถูกลบ/แก้เลย ยืนยันด้วย `git diff`)

**Reason**: ตาม design spec `.wyn/docs/design/wyn-176-batch2-composer.md`, Founder อนุมัติ preview แล้ว

**Tests**: harness Playwright จริง (โหลด CSS 38 ไฟล์ + module.css ตามลำดับจริง) ตรวจ press feedback ด้วย mouse down/up จริง 8 จุด + release กลับ `none` + reduced-motion 8 จุด — **24/24 ผ่าน**

**Build**: `typecheck`/`lint`/`build` สะอาดหมด (0 errors, warning เดิม 3 จุดไม่เกี่ยวข้อง)

**Known Issues**: `.wynos-confirm-dialog` (ปุ่ม "บันทึกร่าง" ตอนปิดหน้าจอกลางทาง) ยังไม่มี press feedback — ตั้งใจไม่แตะเพราะเป็น shared component ข้ามหน้าจอ ไม่ใช่ Composer-specific เก็บไว้เป็นงานแยก (อาจเป็น batch "shared dialogs" ในอนาคต)

**Handoff**: → **AI QA & Security** ตรวจ: (1) press feedback ทำงานจริงบน `/compose-post` จริง (2) ไม่มี regression ต่อ Flutter-parity ที่ล็อกไว้ (compose text 22px, row height 70px ฯลฯ) (3) `.wynos-confirm-dialog` ยังทำงานเหมือนเดิมไม่ถูกกระทบ

## QA Batch 2 (AI QA & Security, 2026-09-19)

**Test Cases**: ไม่เชื่อผลที่ AI Coding รายงานเอง — (1) console/HTTP error sweep บน `/`, `/compose-post`, `/notifications`, `/search` จริง (2) ตรวจ source-parity gate string 5 จุดที่ล็อก Flutter dimension (70px header, 22px compose text, 72px/42px post button, `beta4-ratio-chips` className) ยังอยู่ครบใน source จริง (3) press feedback จริงด้วย mouse down/up 8 จุด + release (4) reduced-motion 8 จุด (5) `typecheck`/`lint`/`build` อิสระใหม่

**Passed**: 32/32 (console/HTTP 8 + press feedback 16 + reduced-motion 8) + source-parity string 5/5 ครบ + lint/typecheck/build สะอาดหมด

**Failed**: ไม่มี

**Severity**: N/A

**Security Findings**: ไม่มี — CSS-only diff

**Recommendation**: Approve batch 2

**Final Status: PASS**

ส่งต่อ AI Deploy & DevOps deploy เฉพาะ batch 2 นี้ (WYN-176 โดยรวมยังไม่ปิด เหลือ batch 3-7)
