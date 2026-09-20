# Product Task — WYN-184

Status: active
Owner: AI Product Manager
Parent Epic: WYN-174 (Web Native App Feel รอบ 2) — follow-up หลัง Track 4 (WYN-182)
Feature: Safe-area inset audit รอบ 2 — ครอบคลุม header ที่ไม่ใช่ sticky/fixed
Goal: WYN-182 audit เฉพาะ selector ที่เป็น `position: fixed`/`sticky` เท่านั้น (ตาม scope ที่ Founder อนุมัติไว้ตอนนั้น) — ระหว่างทางเจอ 2 จุดจริงที่นอก scope นั้นแต่เป็นปัญหาเดียวกัน (`.wyn-profile-topbar`, `.flutter-chat-header`) งานนี้ขยาย audit ให้ครอบคลุม **header ทุกแบบที่ไม่ใช่ shared `.route-header`** ไม่ว่าจะ sticky/fixed หรือ static-in-flow ก็ตาม เพื่อปิดช่องว่างให้ครบจริง

## Known findings จาก WYN-182 (ยืนยันแล้ว ไม่ต้องตรวจซ้ำ แต่ยังไม่ได้แก้)

1. **`.wyn-profile-topbar`** (`web/app/profile-golden-final.css:10-18`) — header หน้า Profile (ปุ่มย้อนกลับ/username/ตั้งค่า) ใช้ใน `/profile/[id]`, `/profile/me` — ไม่ใช่ sticky/fixed (อยู่ในเนื้อหาปกติ) ไม่มี `padding-top` safe-area เลย เพราะ `headerMode="hidden"` ทำให้ AppChrome ไม่ใส่ `.route-header` ให้ ปุ่มย้อนกลับ/ชื่อเรนเดอร์ใต้ notch พอดีตั้งแต่โหลดหน้าครั้งแรก
2. **`.flutter-chat-header`** (Chat inbox, `/chat`) — cascade regression จริง: `pixel-parity-audit-closure.css:9-11` เคยใส่ `padding: env(safe-area-inset-top) 12px 0 0;` ไว้ แต่ `chat-notes.css` (บรรทัด 11 และ 537, ตัวหลังชนะ) ประกาศทับด้วย selector specificity สูงกว่า + `!important` โดยไม่มี safe-area เลย — เหมือน cascade bug ที่ WYN-175 เคยเจอ

## Scope (Founder อนุมัติ — เปิด audit ใหม่เต็มรูปแบบ ไม่ใช่แค่ 2 จุดข้างต้น)

1. หา route ทั้งหมดที่ใช้ `headerMode="hidden"` (จาก WYN-182's audit ทราบแล้วว่ามี: Home, Profile, Notifications, Search, Chat inbox, Chat conversation, Club detail, Post detail, Profile follow list) — ตรวจแต่ละหน้าว่า header ที่ประกอบเองมี safe-area-inset-top ครบหรือไม่ (ไม่ใช่แค่ 2 จุดที่รู้แล้ว — ต้องตรวจครบทุกหน้าในลิสต์นี้จริง)
2. สำหรับหน้าที่พบว่ามี safe-area declaration อยู่แล้ว (เช่น `.wyn-home`, `.flutter-search-header`, `.conversation-modern-header` ที่ WYN-182 เคยตรวจว่า OK ไปแล้วในฐานะ sticky element) — ไม่ต้องตรวจซ้ำ เว้นแต่มี cascade risk ใหม่ที่ยังไม่เคยตรวจ
3. เจาะเฉพาะ**header ที่ไม่ใช่ sticky/fixed** (static-in-flow) ที่ WYN-182 ไม่ได้ครอบคลุม — นี่คือช่องว่างที่แท้จริงของรอบนี้
4. ตรวจ cascade ทุกจุดที่พบว่าขาด (ตามวินัยเดิมของ epic — grep ทั้ง repo ก่อนสรุปว่า "ขาด" จริง เผื่อมีการแก้ไว้ที่อื่นแล้วแต่โดนทับ เหมือนกรณี `.flutter-chat-header`)

## Requirements

- ตรวจให้ครบทุก route ที่ใช้ `headerMode="hidden"` ไม่ sample
- เสนอ fix เฉพาะจุดที่ขาดจริง พร้อม evidence file:line
- ห้ามเปลี่ยน business logic/Supabase contract
- Regression: lint/typecheck/build ผ่าน + QA อิสระตรวจซ้ำก่อน Deploy ตามมาตรฐานเดิม

## Priority

P3 (follow-up หลัง Track 4 ของ epic WYN-174 — epic หลักปิดแล้ว งานนี้เป็น gap-closing รอบเสริม)

## Handoff

→ **AI Design** ทำ audit เต็มรูปแบบตาม scope ข้างต้น เขียน spec พร้อมตาราง evidence + fix proposal ให้ Founder อนุมัติก่อน AI Coding เริ่ม (ตามกติกาเดิมของ epic)

## Design Audit — ผลสรุป

**Spec เต็ม**: `.wyn/docs/design/wyn-184-non-sticky-header-safe-area-audit.md` (audit + spec only, ยังไม่แก้โค้ด)

ยืนยัน route enumeration ของ WYN-182 ซ้ำด้วย grep จริง (`headerMode="hidden"` เจอ 9 จุด ตรงกับลิสต์เดิมทุกตัว: Home, Profile, Notifications, Search, Chat inbox, Chat conversation, Club detail, Post detail, Profile follow list) ตรวจ header จริงของทั้ง 9 route ครบ ไม่ sample พบว่า header จริงที่เป็น **static-in-flow** (ไม่ใช่ sticky/fixed) มี 4 กรณี: Home, Profile, Chat inbox, Club detail (ส่วนอีก 5 route path header จริงเป็น sticky อยู่แล้ว หรือ reuse selector เดียวกับ Profile — นอก scope ของ WYN-184 ตามนิยาม trust WYN-182)

**พบ GAP จริง 2 จุด CSS** (กระทบ 5 route path รวมกัน เพราะ 1 selector reuse กัน 2 route):

1. **`.wyn-profile-topbar`** (`web/app/profile-golden-final.css:10-18`) — ไม่มี safe-area เลย ไม่เคยมีใครแก้มาก่อน (ประกาศไฟล์เดียว ไม่มี cascade risk) กระทบ **4 route path**: `/profile/[id]`, `/profile/me`, `/profile/[id]/followers`, `/profile/[id]/following` (Profile follow list ใช้ selector เดียวกันซ้ำ — เพิ่งพบระหว่าง audit นี้ ไม่เคยถูกเอ่ยถึงใน known finding เดิม)
2. **`.flutter-chat-header`** (Chat inbox, `/chat`) — ยืนยัน cascade regression ซ้ำด้วยหลักฐานเต็ม พบว่าจริงๆ มี **5 ไฟล์** ประกาศ selector นี้ (ไม่ใช่ 2 ไฟล์อย่างที่ known finding เดิมระบุ) ไล่ specificity + `!important` + import order แล้วสรุปชัดว่า rule ที่ชนะจริงคือ `web/app/chat-notes.css:537-542` (ไม่มี safe-area) ไม่ใช่ `pixel-parity-audit-closure.css:9-11` ที่เคยพยายามแก้ไว้แต่โดนทับ — **fix ต้องแก้ที่ rule ผู้ชนะเท่านั้น**

**ตรวจแล้วยืนยันว่า OK ไม่ใช่ GAP**: Home (`.wyn-home-header` เป็น static แต่ parent `.wyn-home` เป็น sticky+safe-area อยู่แล้ว) และ Club detail (`.golden-club-back` ปุ่มย้อนกลับมี `top: calc(env(safe-area-inset-top) + 8px)` ถูกต้องอยู่แล้ว)

ทั้ง 2 fix proposal เป็นการเปลี่ยน spacing ที่มองเห็นได้จริงบนอุปกรณ์มี notch/Dynamic Island เท่านั้น (ไม่มีจุดไหนเป็น defensive-only ในรอบนี้) ไม่แตะ business logic/Supabase contract — รอ Founder อนุมัติก่อน AI Coding เริ่ม

**ข้อจำกัด**: session นี้ไม่มี Bash/browser tool จึงตรวจได้แค่จากการอ่าน source + cascade evidence เท่านั้น ยังไม่ได้ยืนยัน computed style บนอุปกรณ์จริง ต้องให้ QA ยืนยันซ้ำบน iPhone ที่มี notch ก่อนปิด task

## Founder Decision (2026-09-20)

ตอบผ่าน AskUserQuestion — **อนุมัติทั้ง 2 จุด**:
1. `.wyn-profile-topbar` เพิ่ม `padding-top: env(safe-area-inset-top)` (หรือเทียบเท่าตามที่ spec เสนอ)
2. `.flutter-chat-header` แก้ที่ rule ผู้ชนะจริง (`web/app/chat-notes.css:537-542`) ให้มี safe-area — **ห้ามแก้ที่ `pixel-parity-audit-closure.css` เพราะเป็น dead code ที่โดนทับอยู่แล้ว**

→ ส่งต่อ **AI Coding** implement ตาม fix proposal ในสเปกเต็ม

## Implementation (AI Coding, 2026-09-20)

Branch ไม่ behind `origin/main` (fetch ยืนยันแล้ว, HEAD เป็น ancestor ที่ตามหลัง merge ล่าสุดของ PR #570 อยู่แล้ว) ไม่ต้อง merge ก่อนเริ่ม — grep ซ้ำยืนยัน selector/บรรทัดตรงกับ spec เป๊ะ ไม่มีอะไรขยับ

### 1. `.wyn-profile-topbar` (`web/app/profile-golden-final.css:10-18`)
Grep ซ้ำยืนยันประกาศไฟล์เดียวในทั้ง repo จริง (ไม่มี cascade risk) แก้ตาม fix proposal เป๊ะ:
```css
.wyn-profile-topbar {
  height: calc(52px + env(safe-area-inset-top));
  padding: env(safe-area-inset-top) 4px 0;
  ...
}
```
ใช้ pattern เดียวกับ `.wyn-profile-tabs` ที่ WYN-182 แก้ไปแล้ว กระทบ 4 route path ที่ reuse selector นี้ (`/profile/[id]`, `/profile/me`, `/profile/[id]/followers`, `/profile/[id]/following`)

### 2. `.flutter-chat-header` cascade fix
ก่อนแก้ re-verify cascade ใหม่ทั้งหมดด้วยตัวเอง (ไม่เชื่อ spec เฉยๆ ตามคำเตือนใน task brief): grep ยืนยันครบ 5 rule declaration ใน 4 ไฟล์จริง (`system-parity-lock.css:209`, `pixel-parity-audit-closure.css:9`, `notifications-clean.css:206`, `chat-notes.css:11` และ `chat-notes.css:537`), เช็ค import order ใน `layout.tsx` ตรงกับที่ spec อ้างเป๊ะ (`system-parity-lock.css` → `pixel-parity-audit-closure.css` → `notifications-clean.css` → `chat-notes.css`) ไล่ cascade เอง: rule ที่ไม่มี `!important` (A, B) แพ้ทันทีให้ทุก rule ที่มี `!important` โดยไม่สนใจ specificity/order — เหลือ C/D/E ที่มี `!important`; C specificity (0,1,0) แพ้ D/E (0,2,0); D กับ E specificity เท่ากันอยู่ไฟล์เดียวกัน (`chat-notes.css`) — E (บรรทัด 537) มาหลัง D (บรรทัด 11) ในไฟล์เดียวกันจึงชนะ ตรวจ media query เสริมอีก 2 จุด (`:497`, `:744`) ด้วย ยืนยันว่าแก้แค่ `padding-left`/`padding-right` (longhand) ไม่แตะ `padding-top` เลย ไม่กระทบผลสรุป

**ผลการ re-verify อิสระ: ตรงกับ spec 100% ไม่มี discrepancy** — rule ที่ชนะจริงคือ `chat-notes.css:537-542` แก้ที่นี่:
```css
.wyn-chat-inbox .flutter-chat-header {
  height: calc(68px + env(safe-area-inset-top)) !important;
  padding: calc(env(safe-area-inset-top) + 6px) 18px 0 14px !important;
  ...
}
```
คง `!important` ทุกตัวไว้เหมือนเดิม ไม่แตะ `pixel-parity-audit-closure.css:9-11` (dead code ตามที่ scope ระบุห้ามแตะ)

### Validation
- `npm run lint` / `npm run typecheck` / `npm run build` (`npm run check`) ใน `web/` — ผ่านสะอาดทั้ง 3 (lint มี warning 3 จุดเดิมที่มีอยู่ก่อนแก้ ไม่เพิ่ม error ใหม่)
- เขียน Playwright harness ชั่วคราว (`web/__wyn184-safe-area-check.mjs`, ลบแล้วหลังใช้) รันกับ `next dev` จริง (ไม่ใช่ static fixture คัดลอก CSS มาเอง — ใช้ route สาธารณะ `/welcome` ที่ไม่ต้อง auth แล้ว inject markup จริงของทั้ง 2 header เข้า DOM ที่โหลด bundled CSS จริงจาก `app/layout.tsx` ทั้ง 36 ไฟล์ตามลำดับจริง) จำลอง notch ผ่าน CDP `Emulation.setSafeAreaInsetsOverride` (top=59px) และ non-notch (top=0) — **10/10 checks ผ่าน**:
  - Profile topbar: `padding-top`/`height` คำนวณตรงสูตรทั้งกรณี notch (59px / 111px) และ non-notch (0px / 52px เดิม ไม่มี regression)
  - Chat header: `padding-top`/`height` ตรงสูตรทั้งกรณี notch (65px / 127px) และ non-notch (6px / 68px เดิม ไม่มี regression) — ยืนยันเพิ่มด้วย `grid-template-columns` (`40px ...` เป็นลายเซ็นเฉพาะของ rule E เท่านั้น ต่างจาก A/C/D ที่ใช้ `48px`) ว่า rule ที่แก้เป็นตัวที่ชนะ cascade จริงในหน้าที่ render จริง ไม่ใช่แค่ตรวจ source
- Reason ที่ใช้ dev server จริงแทน static fixture: routes ที่มี header ทั้ง 2 (`/profile/[id]`, `/chat`) ต้องผ่าน `DeveloperRouteGate` (ต้องมี Supabase session จริง, sandbox นี้ไม่มี live backend) จึง inject markup เข้า route สาธารณะที่ share stylesheet bundle เดียวกันแทน — ได้ CSS ที่ผ่าน Next's bundler จริง ไม่ใช่การเดา specificity จาก source อย่างเดียว
- Revert `web/next-env.d.ts` ที่ `next dev`/`next build` auto-touch แล้ว (`git checkout -- web/next-env.d.ts`) — ยืนยัน `git status` เหลือแค่ 2 ไฟล์ CSS ที่ตั้งใจแก้

### สรุปไฟล์ที่แก้
CSS: `web/app/profile-golden-final.css`, `web/app/chat-notes.css` (2 ไฟล์เท่านั้น ตรงตาม scope ที่ Founder อนุมัติ)

→ ส่งต่อ **AI QA & Security** ตรวจซ้ำอิสระบนอุปกรณ์/เบราว์เซอร์ที่มี notch/Dynamic Island จริงก่อนเข้า Deploy gate (sandbox นี้ไม่มี Supabase backend จริง — QA ต้องยืนยันซ้ำบน environment ที่มี auth จริงว่า Profile/Profile follow list/Chat inbox หน้าจริง render header ถูกต้อง ไม่ใช่แค่ fixture ที่ inject เข้า `/welcome`)

## QA (AI QA & Security, 2026-09-20)

**หมายเหตุ environment ก่อนเริ่ม (ไม่ใช่บั๊กของ WYN-184 แต่เป็น process finding ที่ต้องบันทึกตามวินัยเดิมของ epic)**: worktree ที่ได้รับมอบหมาย ตอนเริ่มงาน HEAD = `17a1403c` (merge commit ของ PR #570) ซึ่ง**ไม่ตรง**กับ `568997d2` ที่ต้องตรวจ (`git log -1` ไม่ match ตั้งแต่แรก) — `git status` ยืนยัน working tree สะอาดก่อนแก้ จึงปลอดภัยที่จะ `git checkout --detach 568997d2` ในเฉพาะ worktree ของตัวเอง (ไม่แตะ branch/worktree อื่น ไม่ force push/rewrite ใดๆ) ยืนยัน `git log -1` = `568997d2af3945114fb697824119285034096297` ตรงเป๊ะก่อนเริ่มตรวจใหม่ทั้งหมด — **ทุกผลลัพธ์ด้านล่างมาจากคอมมิทนี้จริงเท่านั้น**

**Test Cases**: อ่าน diff จริง (`git show 568997d2`) + grep ทั้ง repo อิสระ (ไม่จำกัด extension) ยืนยัน cascade ทั้ง 2 selector เอง ไม่เชื่อคำอ้างของ AI Coding + ตรวจ `layout.tsx` CSS import order เอง + ติดตั้ง `npm install` + Playwright browser binaries (`chromium`, `chromium-headless-shell`, `webkit` — มีอยู่แล้วที่ `/opt/pw-browsers` ในสภาพแวดล้อมนี้) + สร้าง Playwright harness ของตัวเองใหม่ทั้งหมด (ไม่ reuse ของ AI Coding ซึ่งลบไปแล้ว) รันกับ `next dev` จริง ใช้ CDP `Emulation.setSafeAreaInsetsOverride` จำลอง notch จริงทั้งกรณี notch/non-notch + typecheck/lint/build อิสระ + รัน regression suite เต็ม (`npx playwright test`, 159 test ทั้ง 3 project) + ตรวจ `pixel-parity-audit-closure.css` ไม่ถูกแตะ + ตรวจ security surface ของ diff

### 1. `.wyn-profile-topbar` (`web/app/profile-golden-final.css`)
ยืนยัน CSS แก้ตรงตามที่อ้างเป๊ะ (`height: calc(52px + env(safe-area-inset-top))`, `padding: env(safe-area-inset-top) 4px 0`) grep ทั้ง repo ทุกนามสกุลไฟล์ (ไม่จำกัด `.css`/`.tsx`) ยืนยันมีแค่ 1 base rule (`profile-golden-final.css:10`) ในทั้ง repo — sub-selector อื่น (`button`, `strong`, `.wyn-profile-account-switcher`) เป็น descendant selector ที่ไม่กระทบ `height`/`padding` ของ parent เอง ไม่มี cascade risk จริง

Live verification ด้วย CDP `Emulation.setSafeAreaInsetsOverride` (inject markup จริงเข้า `/welcome` ที่โหลด global stylesheet bundle จริงจาก `layout.tsx`): notch (top=59px) → computed `padding-top`=59px, `height`=111px (ตรงสูตร `52+59`) เป๊ะ; non-notch (top=0) → `padding-top`=0px, `height`=52px **เหมือนค่าก่อนแก้ทุกประการ ไม่มี regression**

### 2. `.flutter-chat-header` cascade — ประเด็นความเสี่ยงสูงสุด

**Re-derive cascade อิสระทั้งหมดเอง (ไม่เชื่อ grep/สรุปของ AI Coding แม้แต่จุดเดียว)**: grep `flutter-chat-header` ทั้ง repo (ไม่จำกัด extension) พบตรงกับที่ AI Coding อ้าง **5 rule declaration ใน 4 ไฟล์**:

| # | ไฟล์:บรรทัด | Selector | Specificity | `!important` | padding-top |
|---|---|---|---|---|---|
| A | `system-parity-lock.css:209` | `.flutter-chat-header` | (0,1,0) | ไม่มี | `0` |
| B | `pixel-parity-audit-closure.css:9` | `.flutter-chat-header` | (0,1,0) | ไม่มี | `env(safe-area-inset-top)` (dead code) |
| C | `notifications-clean.css:206` | `.flutter-chat-header` | (0,1,0) | มี | `8px` |
| D | `chat-notes.css:11` | `.wyn-chat-inbox .flutter-chat-header` | (0,2,0) | มี | `8px` |
| E | `chat-notes.css:537` | `.wyn-chat-inbox .flutter-chat-header` | (0,2,0) | มี | `6px` → หลังแก้ = `calc(env(safe-area-inset-top)+6px)` |

**บทสรุปการไล่ cascade ของตัวเอง**: (1) `!important` ทั้งหมดชนะ non-`!important` ก่อนเสมอไม่สนใจ specificity/order → ตัด A, B ทิ้ง (2) เหลือ C/D/E ที่มี `!important` — C specificity (0,1,0) ต่ำกว่า D/E (0,2,0) → ตัด C ทิ้ง (3) D กับ E specificity เท่ากัน อยู่ไฟล์เดียวกัน (`chat-notes.css`) — source order tie-break: บรรทัดหลังชนะ → **E (บรรทัด 537) ชนะ D (บรรทัด 11)** ยืนยัน `layout.tsx` import order เองด้วย (`system-parity-lock.css:25` → `pixel-parity-audit-closure.css:29` → `notifications-clean.css:40` → `chat-notes.css:41`) ตรงตามที่อ้าง แต่ไม่ใช่ปัจจัยตัดสินในกรณีนี้เพราะ D/E อยู่ไฟล์เดียวกันอยู่แล้ว ตรวจ media query เสริม (`:497`, `:744`) ด้วยตัวเอง ยืนยันแก้แค่ `padding-left`/`padding-right` ไม่แตะ `padding-top`/`height` จริง ไม่กระทบผลสรุป

**ผลการ re-derive อิสระของ QA: ตรงกับที่ AI Coding อ้าง 100% ไม่มี discrepancy — rule ที่ชนะจริงคือ `chat-notes.css:537-542` (E) ซึ่งเป็น rule เดียวกับที่ถูกแก้ในคอมมิทนี้ ไม่ใช่ no-op**

**Live verification** (สำคัญที่สุด — ไม่ใช่แค่ตรวจ source): inject markup จริงพร้อม wrapper `.wyn-chat-inbox`, notch (top=59px) → computed `padding-top`=65px (ตรงสูตร `59+6`), `height`=127px (ตรงสูตร `68+59`); non-notch → `padding-top`=6px, `height`=68px **เหมือนค่าก่อนแก้ ไม่มี regression** ยืนยันเพิ่มด้วย signature check: computed `grid-template-columns` เริ่มด้วย `"40px"` ซึ่งเป็นค่าเฉพาะของ rule E เท่านั้น (A/B ใช้ 48px/56px, C/D ใช้ 48px) — พิสูจน์ว่า rule ที่แก้เป็นตัวที่ชนะ cascade จริงในหน้าที่ render จริง ไม่ใช่แค่การเดาจาก source

ยืนยัน `pixel-parity-audit-closure.css:9-11` **ไม่ถูกแตะ** (`git diff 568997d2^ 568997d2 -- web/app/pixel-parity-audit-closure.css` ว่างเปล่า) ตรงตาม scope ที่ Founder อนุมัติ (ห้ามแก้ dead code)

### 3. Regression + Build — **พบบั๊กจริงที่ AI Coding ไม่จับได้**
`npm run lint`: 0 error, warning 3 จุดเดิม (`chat-inbox-parity.tsx`, `home-screen.tsx`, `profile-route.tsx`) ตรงตามที่อ้าง
`npm run typecheck`: ผ่านสะอาด 0 error
`npm run build`: สำเร็จ ไม่มี error, generate ครบ 31/31 route
`git status` หลัง build/dev: มี `web/next-env.d.ts` ถูก auto-touch จริงตามที่ AI Coding อธิบาย (`next dev`/`next build` เปลี่ยน path เป็น `.next/dev/types/...`) — revert แล้วด้วย `git checkout -- web/next-env.d.ts` ยืนยัน `git status` สะอาด

**Regression suite เต็ม (`npx playwright test`, ติดตั้ง `chromium`/`chromium-headless-shell`/`webkit` ครบเองก่อนรัน)**: **3 failed / 156 passed** (ไม่ใช่ 159/159 แบบ WYN-182 QA) — **ทั้ง 3 failure ไม่ใช่ baseline เดิม** (ไม่เกี่ยวกับ `chromium_headless_shell` ที่ขาดหาย เพราะ binary ติดตั้งครบแล้วในสภาพแวดล้อมนี้) แต่เป็น **regression จริงที่เกิดจาก diff นี้โดยตรง**: `tests/browser/parity.spec.ts:162` — `expect(profileGoldenCss).toContain("height: 52px")` fail ทั้ง 3 browser project (`webkit-iphone`, `chromium-android`, `chromium-desktop`) เพราะ WYN-184 เปลี่ยน `.wyn-profile-topbar { height: 52px; }` เป็น `height: calc(52px + env(safe-area-inset-top));` ทำให้สตริง literal `"height: 52px"` หายไปจากไฟล์จริง (grep ยืนยัน: ไม่มี match เหลือใน `profile-golden-final.css` อีกแล้ว) — reproduce ซ้ำแบบ isolated (`npx playwright test tests/browser/parity.spec.ts -g "source contracts cannot regress" --project=chromium-desktop`) ได้ผลเดิมทุกครั้ง ยืนยันด้วย `git show 568997d2^:web/app/profile-golden-final.css` ว่า parent commit มีสตริงนี้จริง (แปลว่า test นี้ผ่านมาก่อนหน้า diff นี้แน่นอน)

**Root cause**: `parity.spec.ts:162` เป็น literal-string regression guard ที่ hardcode ค่าเก่า ไม่ทนต่อการเปลี่ยนแปลงที่ถูกต้องและอนุมัติแล้วของ WYN-184 — CSS ที่แก้ **ถูกต้อง** (ยืนยันด้วย live verification ข้างบนแล้ว) แต่ test ยังไม่อัปเดตตาม ต้องแก้ assertion ที่ test ไม่ใช่ CSS

**สาเหตุที่ AI Coding พลาด**: validation ที่รายงานไว้มีแค่ `npm run check` (lint+typecheck+build) และ ad hoc harness ของตัวเอง — **ไม่ได้รัน `web/tests/browser/` (regression suite ที่มีอยู่แล้ว) เลย** ทั้งที่ task brief ของ epic ระบุไว้ชัดว่าต้องรัน — เป็นสาเหตุที่บั๊กนี้หลุดมาถึง QA แทนที่จะถูกจับตั้งแต่ตอน implement และ CI workflow `web-phase4-browser-qa.yml` (trigger บน PR ที่แตะ `web/**`) จะ fail แดงจริงถ้า merge ไปโดยไม่แก้

รายละเอียด repro + fix proposal เต็ม: `.wyn/tasks/bugs/WYN-184-regression-suite-literal-height-assertion-broken.md`

### 4. Security Review
Diff เป็น pure CSS เปลี่ยนแค่ 2 property (`height`, `padding`) ของ 2 selector ที่มีอยู่แล้ว ไม่มี selector ใหม่ ไม่มี `url()`/`@import`/data-URI/`expression()` ใหม่ (grep ยืนยัน) ไม่แตะ component/JS/schema/RLS/auth ใดๆ เลย (`git show 568997d2 --stat` มีแค่ 2 ไฟล์ CSS + 1 ไฟล์ doc) ไม่มี data-access surface ใหม่ ไม่มี secret/credential ใน diff — **ไม่มี security finding ระดับใดเลย ตรงตามที่คาดไว้ว่าเป็น pure CSS change**

**Passed**: safe-area live-check 9/9 (ของ QA เอง) + cascade re-derivation อิสระตรงกับ AI Coding 100% + lint/typecheck/build สะอาด + scope check (`pixel-parity-audit-closure.css` ไม่ถูกแตะ) + security review สะอาด

**Failed**: Regression suite `tests/browser/parity.spec.ts:162` fail ทั้ง 3 browser project เนื่องจาก literal-string assertion เก่าไม่ทันการเปลี่ยนแปลงที่ถูกต้องของ WYN-184 (ดูรายละเอียด #3 ด้านบน)

**Severity**: HIGH — ไม่ใช่ security bug และไม่กระทบผู้ใช้จริงบนอุปกรณ์ (CSS ที่แก้ถูกต้องและยืนยันแล้วด้วย live test) แต่เป็น regression suite ที่พังจริงจาก diff นี้โดยตรง ซึ่งเป็น required release gate ตาม requirement ของ WYN-184 เอง ("Regression: lint/typecheck/build ผ่าน + QA อิสระตรวจซ้ำ") และจะทำให้ CI workflow `web-phase4-browser-qa.yml` แดงจริงถ้าเข้า PR/merge โดยไม่แก้ — block release ตามกติกา QA gate ("ห้ามอนุมัติงานที่ยังไม่ได้ทดสอบจริง" + Definition of Done ต้องการ "tests ที่เกี่ยวข้องผ่าน")

**Security Findings**: ไม่มี CRITICAL/HIGH/MEDIUM/LOW — pure CSS change ไม่มี security surface ใหม่

**Recommendation**: **ส่งต่อ AI Debug Engineer** แก้ `web/tests/browser/parity.spec.ts:162` ให้ assertion ตรงกับ CSS ใหม่ที่ถูกต้อง (**ห้ามแก้ CSS กลับ** — ค่าที่แก้ไปแล้วถูกต้องตาม Founder approval และยืนยันด้วย live verification แล้ว) ดูรายละเอียดที่ `.wyn/tasks/bugs/WYN-184-regression-suite-literal-height-assertion-broken.md` หลังแก้แล้วให้ QA รัน `npx playwright test` เต็ม suite ซ้ำอีกรอบยืนยัน 0 failed ก่อนอนุมัติเข้า Deploy gate — **ไม่ต้องตรวจซ้ำ cascade/safe-area ของ 2 จุด CSS อีก** (ตรวจผ่านสมบูรณ์แล้วในรอบนี้ ทั้ง source-level cascade re-derivation และ live CDP rendering ไม่มี discrepancy กับที่ AI Coding อ้าง)

**Final Status: FAIL**

(หมายเหตุ: FAIL รอบนี้มาจาก regression suite เท่านั้น ไม่ใช่จากตัว fix ของ WYN-184 เอง — ทั้ง `.wyn-profile-topbar` และ `.flutter-chat-header` cascade fix ตรวจสอบอิสระแล้วว่าถูกต้อง 100% ตรงตามที่ AI Coding อ้างทุกจุด รวมถึง cascade analysis ที่เป็นความเสี่ยงสูงสุดของงานนี้)

## Debug Fix (AI Debug Engineer, 2026-09-20)

**Bug**: `web/tests/browser/parity.spec.ts:162` — assertion `expect(profileGoldenCss).toContain("height: 52px")` เป็น literal-string regression guard ที่ hardcode ค่า `.wyn-profile-topbar { height: 52px; }` เดิม (มีไว้ตั้งแต่ก่อน WYN-184 คู่กับบรรทัดก่อนหน้าที่กัน regression กลับไปเป็นดีไซน์ cover-photo เก่า `height: calc(170px...)`) เมื่อ WYN-184 เปลี่ยน `.wyn-profile-topbar` เป็น `height: calc(52px + env(safe-area-inset-top));` ตามที่ Founder อนุมัติ สตริง literal `"height: 52px"` จึงหายไปจากไฟล์จริง ทำให้ assertion fail ทั้ง 3 browser project — ไม่ใช่ regression ของ product code เป็น stale test assertion ล้วนๆ ตรงตามที่ QA วินิจฉัยไว้ใน bug report

**Root Cause**: ยืนยันซ้ำเองด้วย `git show 568997d2 -- web/app/profile-golden-final.css` และอ่าน context รอบบรรทัด 161-162 ของ `parity.spec.ts` — assertion นี้เจตนาป้องกัน 2 อย่างคู่กัน: (1) ห้ามกลับไปใช้ header สูง 170px แบบ cover-photo เก่า (บรรทัด 161, `.not.toContain`) และ (2) ยืนยันว่า metric สำคัญ 3 ตัวของ topbar (`font-size: 17px`, `min-height: 44px`, `height: 52px`) ยังอยู่ — invariant ที่แท้จริงคือ "topbar ยังคงใช้ฐาน 52px ไม่ใช่ 170px" ไม่ใช่ "ต้องเป็น `height: 52px` เป๊ะโดยไม่มี safe-area" WYN-184 เปลี่ยนแค่สูตรให้บวก safe-area เข้าไป ฐาน 52px ยังอยู่ครบ (`calc(52px + env(safe-area-inset-top))`) จึงไม่ใช่การผิด invariant จริง — เป็นแค่ assertion ที่เขียนแบบ literal substring ไม่ทนต่อการเปลี่ยนสูตรที่ถูกต้อง

**Fix**: แก้ literal string ใน assertion เดียว จาก `"height: 52px"` เป็น `"height: calc(52px + env(safe-area-inset-top))"` (ตรงกับ CSS ปัจจุบันเป๊ะ) ใช้ pattern เดียวกับ assertion อื่นในโค้ดเบสที่เช็ค safe-area formula แบบ exact substring อยู่แล้ว (เช่น `final-source-parity-gate.spec.ts:41` และ `system-visual-parity.spec.ts:250` ที่เช็ค `"height: calc(70px + env(safe-area-inset-top))"`) — ไม่เปลี่ยนไปใช้ regex หรือ pattern ใหม่ เพื่อคงความเรียบง่ายและ consistency กับ convention เดิมของไฟล์

```diff
- for (const metric of ["font-size: 17px", "min-height: 44px", "height: 52px"]) expect(profileGoldenCss).toContain(metric);
+ for (const metric of ["font-size: 17px", "min-height: 44px", "height: calc(52px + env(safe-area-inset-top))"]) expect(profileGoldenCss).toContain(metric);
```

**ตรวจสอบ stale assertion อื่นที่อาจเกี่ยวกับ 2 selector ของ WYN-184 เพิ่มเติม** (ไม่เชื่อว่า QA เจอครบแค่เพราะรัน full suite ครั้งเดียว — grep เองทั้ง `web/tests/browser/` หา `wyn-profile-topbar`, `flutter-chat-header`, `52px`, `68px`, `safe-area-inset-top`):
- `parity.spec.ts:204` มี literal `"height: 52px"` อีกจุด แต่เป็นของ `completionCss` (`app/parity-completion.css`) ซึ่ง WYN-184 ไม่ได้แตะ — grep ยืนยัน match จริงคือ `.club-list-avatar { width: 52px; height: 52px; ... }` (ไม่เกี่ยวกับ topbar) ยังผ่านปกติ ไม่ใช่ stale assertion ที่ต้องแก้
- ไม่มี test ไฟล์ไหนอ้างอิง `.wyn-profile-topbar` โดยตรง (grep ทั้ง `web/tests/browser/` ไม่พบ)
- `.flutter-chat-header`/`chat-notes.css`: มีแค่ `system-visual-parity.spec.ts` ที่ `readFile("app/chat-notes.css")` เก็บไว้ในตัวแปร `notesCss` แต่ assertion ทั้งหมดที่ใช้ตัวแปรนี้ (`.wyn-chat-note-plus`, `grid-template-rows`, ฯลฯ) ไม่แตะ `height`/`padding` ของ `.flutter-chat-header` เลย (เช็คแต่ metric ของ note bubble/plus button ส่วนอื่น) — ไม่มี stale assertion ซ่อนอยู่สำหรับ selector นี้
- สรุป: มี stale assertion จุดเดียวจริงตามที่ QA รายงาน (บรรทัด 162) ไม่มีจุดอื่นที่ "ผ่านโดยบังเอิญ" ที่ต้องแก้เพิ่ม

**Files Changed**: `web/tests/browser/parity.spec.ts` (1 บรรทัด, บรรทัด 162) — ไม่แตะ CSS ไฟล์ใดเลย (`profile-golden-final.css`, `chat-notes.css` ไม่มีการเปลี่ยนแปลง ยืนยันด้วย `git diff` ก่อน commit)

**Tests**:
- `npx playwright test tests/browser/parity.spec.ts -g "source contracts cannot regress"` (ทั้ง 3 browser project): **3/3 passed** (ก่อนแก้ fail ทั้ง 3, หลังแก้ผ่านทั้ง 3)
- Full regression suite `npx playwright test`: **159 passed, 0 failed** (clean baseline ครบ ไม่มี failure จาก `chromium_headless_shell` เพราะ binary มีอยู่แล้วที่ `/opt/pw-browsers` ในสภาพแวดล้อมนี้)
- `npm run check` (`lint` + `typecheck` + `build`) ใน `web/`: ผ่านสะอาดทั้ง 3 ขั้น (lint มี warning 3 จุดเดิมที่มีอยู่ก่อนแก้ — ไม่เพิ่ม error/warning ใหม่, build generate ครบ 31/31 route)
- `web/next-env.d.ts` ถูก `next build` auto-touch ระหว่างรัน `npm run check` — ตรวจแล้วว่ากลับมาสะอาดเองหลัง build เสร็จ (`git status` เหลือแค่ `parity.spec.ts`) ไม่ต้อง revert เพิ่ม

**Regression Risk**: ต่ำมาก — แก้แค่ literal string ใน test assertion ให้ตรงกับ CSS ที่ถูกต้องและอนุมัติแล้ว ไม่กระทบ production code/behavior ใดๆ

**Handoff to QA**: ส่งกลับ **AI QA & Security** ตรวจซ้ำอิสระอีกรอบก่อนเข้า Deploy gate — ต้องยืนยัน `npx playwright test` เต็ม suite เป็น 159/159 ด้วยตัวเอง (ไม่ต้องตรวจซ้ำ cascade/safe-area ของ 2 จุด CSS อีก เพราะ QA รอบก่อนหน้ายืนยันสมบูรณ์แล้วว่า CSS ถูกต้อง — รอบนี้ตรวจแค่ว่า test fix ถูกต้องและ regression suite กลับมาเขียวจริง)

## QA Re-verification (AI QA & Security, 2026-09-20)

**หมายเหตุ environment ก่อนเริ่ม**: worktree ที่ได้รับมอบหมาย ตอนเริ่มงาน HEAD = `17a1403c` (merge commit ของ PR #570) ไม่ตรงกับ `eb9c2fa8` ที่ต้องตรวจ — `git status` ยืนยัน working tree สะอาดก่อนแก้ จึง `git checkout --detach eb9c2fa8` ในเฉพาะ worktree ของตัวเอง (ไม่แตะ branch/worktree อื่น) ยืนยัน `git log -1` = `eb9c2fa80377e8eea56cb251fccb298f69632f8d` ตรงเป๊ะก่อนเริ่มตรวจ — **ทุกผลลัพธ์ด้านล่างมาจากคอมมิทนี้จริงเท่านั้น** นี่เป็น process finding ซ้ำแบบเดียวกับ QA รอบก่อนหน้า (worktree ยังไม่ sync กับ HEAD ล่าสุดของ branch โดยอัตโนมัติ) ไม่ใช่บั๊กของ WYN-184

**Scope รอบนี้เป็น re-verification ไม่ใช่ full re-audit** — cascade/safe-area ของ 2 จุด CSS (`.wyn-profile-topbar`, `.flutter-chat-header`) ตรวจผ่านสมบูรณ์แล้วในรอบ QA ก่อนหน้า ไม่ตรวจซ้ำ รอบนี้ตรวจเฉพาะ: (1) diff ของ debug fix ตรงตามที่อ้างจริงหรือไม่ (2) regression suite กลับมาเขียวจริงหรือไม่ (3) claim เรื่อง "ไม่มี stale assertion อื่น" จริงหรือไม่ (4) typecheck/lint/build (5) `next-env.d.ts` สะอาด (6) security sanity check

### 1. ยืนยัน diff ของ debug fix ตรงตามที่อ้างเป๊ะ
`git show eb9c2fa8 -- web/tests/browser/parity.spec.ts` ยืนยัน **มีการเปลี่ยนแค่ 1 บรรทัดจริง** (บรรทัด 162): จาก `"height: 52px"` เป็น `"height: calc(52px + env(safe-area-inset-top))"` ตรงกับ CSS ปัจจุบันของ `.wyn-profile-topbar` เป๊ะ (`web/app/profile-golden-final.css`) ยืนยันเพิ่มด้วย `git diff 568997d2 eb9c2fa8 -- web/app/profile-golden-final.css web/app/chat-notes.css` → **diff ว่างเปล่า** ทั้ง 2 ไฟล์ CSS ที่ WYN-184 แก้ไม่ถูกแตะเลยตั้งแต่คอมมิทที่ QA รอบก่อนตรวจผ่าน (`git show eb9c2fa8 --stat` แสดงไฟล์ที่เปลี่ยนแค่ 5 ไฟล์: `.wyn/learning/LESSONS_LEARNED.md`, `.wyn/learning/MISTAKES.md`, task doc นี้, bug report, และ `parity.spec.ts` — ไม่มีไฟล์ CSS) ตรงตามที่อ้าง 100%

### 2. Regression suite เต็ม — รันเองอิสระ
ติดตั้ง dependency (`npm install`, browser binary มีอยู่แล้วที่ `/opt/pw-browsers` — `npx playwright install` ไม่ต้อง download ใหม่) รัน `npx playwright test` เต็ม suite ได้ผล **159 passed, 0 failed, exit code 0** (2.8 นาที) ตรงกับที่ AI Debug Engineer รายงาน ยืนยันเจาะจุดที่เคย fail ด้วย: `tests/browser/parity.spec.ts:30:5 "source contracts cannot regress to staged migration UI"` ผ่านทั้ง 3 browser project (`chromium-desktop`, `chromium-android`, `webkit-iphone` — นับรวมใน 159 total) ไม่มี failure ใดๆ เหลืออยู่

### 3. ยืนยัน claim "ไม่มี stale assertion อื่น" ด้วย grep อิสระของตัวเอง
`grep -rn "wyn-profile-topbar" web/tests/browser/` → ไม่มีผลลัพธ์ (ไม่มี test ไฟล์ไหนอ้างอิง selector นี้โดยตรง)
`grep -rn "flutter-chat-header" web/tests/browser/` → ไม่มีผลลัพธ์
`grep -rn "height: 52px" web/tests/browser/` → เจอ 2 จุด: `parity.spec.ts:204` (ตรวจแล้วเป็นของ `completionCss`/`.club-list-avatar` ใน `parity-completion.css` ที่ WYN-184 ไม่ได้แตะ) และ `system-visual-parity.spec.ts:113` (`min-height: 52px` ของ `finalLock` ซึ่งอ่านจาก `app/system-parity-final.css` — ไฟล์คนละไฟล์ ไม่เกี่ยวกับ WYN-184) — ทั้ง 2 จุดไม่ใช่ stale assertion ตรงตามที่ AI Debug Engineer อ้าง ไม่มีจุดอื่นที่ค้างอยู่

### 4. Typecheck / Lint / Build — อิสระ
`npm run lint`: 0 error, warning 3 จุดเดิม (`chat-inbox-parity.tsx`, `home-screen.tsx`, `profile-route.tsx`) ตรงตามที่อ้าง ไม่มี warning ใหม่
`npm run typecheck`: ผ่านสะอาด 0 error
`npm run build`: สำเร็จ compile ใน 8.7s, generate ครบ 31/31 route ไม่มี error

### 5. `web/next-env.d.ts`
ก่อนรัน suite: สะอาด หลังรัน `npx playwright test` (ซึ่ง spawn `next dev` เป็น webServer): พบ auto-touch ตามแพทเทิร์นเดิมที่เคยพบใน QA/Debug รอบก่อน (`import "./.next/types/...` → `import "./.next/dev/types/...`) — revert ด้วย `git checkout -- web/next-env.d.ts` ยืนยัน `git status` สะอาดหลัง revert ไม่ใช่การแก้ไขที่ตั้งใจ ไม่ใช่บั๊ก

### 6. Security Sanity Check
Diff ของคอมมิทนี้เป็น test assertion (1 บรรทัด) + learning docs + task docs เท่านั้น ไม่มี CSS/JS/component/schema/auth ใดถูกแตะ ไม่มี selector/data-access surface ใหม่ ไม่มี secret/credential ในดิฟ — ไม่มี security finding ระดับใดเลย ตรงตามที่คาดไว้สำหรับ test-only change

### สรุป
Debug fix ตรงตามที่อ้างเป๊ะ 100% (diff 1 บรรทัดจริง ไม่แตะ CSS) regression suite กลับมาเขียวจริง 159/159 (ยืนยันเองอิสระ ไม่เชื่อคำอ้าง) claim เรื่องไม่มี stale assertion อื่นตรวจสอบแล้วถูกต้อง typecheck/lint/build สะอาด ไม่มี security finding ใหม่ cascade/safe-area ของ 2 จุด CSS หลักยังคงตรวจผ่านสมบูรณ์จากรอบก่อนหน้า (ไม่มีการเปลี่ยนแปลงใดๆ ต่อ CSS ในคอมมิทนี้)

**Final Status: PASS**

→ พร้อมเข้า Deploy gate (CTO Final Review → Staging → Founder Approval → Production) บันทึกปิด bug report `WYN-184-regression-suite-literal-height-assertion-broken.md` เป็น verified/closed แล้ว
