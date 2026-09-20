# Product Task — WYN-182

Status: active
Owner: AI Product Manager
Parent Epic: WYN-174 (Web Native App Feel รอบ 2) — Track 4, P2
Feature: Platform Integration Polish — safe-area inset coverage + pull-to-refresh/overscroll coverage ทั้งแอป
Goal: ปิดช่องว่างสุดท้ายของ epic WYN-174 ให้ทุกหน้าจอ/ทุก scroll surface ของ `wynos.online` จัดการ notch, home indicator และพฤติกรรม scroll ให้เหมือนแอปมือถือจริงสม่ำเสมอทั้งระบบ ไม่ใช่แค่บางจุดที่เคยทำไปแล้ว
Target User: ผู้ใช้ WYNOS บนมือถือที่มี notch/home indicator (iPhone X ขึ้นไป) และผู้ใช้ทั่วไปที่ scroll list ต่างๆ ในแอป

## Scope (จาก epic WYN-174 requirement P2)

แบ่งเป็น 2 sub-audit:

1. **Safe-area inset audit** — ตรวจทุกหน้า/ทุก fixed หรือ sticky element (bottom nav, header, composer/input bar, action sheet, modal, install banner ฯลฯ) ว่ามี `env(safe-area-inset-*)` ครอบคลุมจริงหรือไม่ จุดไหนขาดให้เพิ่ม
2. **Pull-to-refresh / overscroll audit** — ตรวจทุก scroll surface ว่ามี `overscroll-behavior` กัน rubber-band bounce โผล่พื้นหลังขาว/ผิดที่ และตรวจว่า pull-to-refresh ควรมีอยู่ที่ไหนบ้าง (ปัจจุบันมีแค่ home feed) จุดไหนควรมีแต่ยังไม่มี

## Preliminary findings (ตรวจโค้ดจริงเบื้องต้นแล้ว 2026-09-20)

- `env(safe-area-inset-*)` มีใช้อยู่แล้ว 81 จุดกระจายใน 26 ไฟล์ CSS — coverage กว้างพอสมควรจากงานที่ผ่านมา (WYN-158/163/175/176/181) แต่ยังไม่เคยมีการ audit อย่างเป็นระบบว่าครบทุกจุดจริงหรือไม่
- `overscroll-behavior` มีใช้แค่ 7 จุดใน 6 ไฟล์ (`profile-golden-final.css`, `parity-closure.css`, `interaction-parity-final.css`, `chat-notes.css`, `phase2.css`, `home.css`) — **`html`/`body` ระดับ global ใน `globals.css` ไม่มี base rule เลย** ต้องตรวจว่าเป็นปัญหาจริงหรือไม่ (rubber-band ที่ตัว document เอง ไม่ใช่แค่ scroll container ย่อย)
- Pull-to-refresh พบ implementation จริงแค่ใน `components/home/home-screen.tsx` จุดเดียว — ต้องตรวจว่าหน้าอื่นที่เป็น list/feed แบบเดียวกัน (Club, Notifications, Search results, Bookmarks) ควรมีด้วยหรือไม่ (ไม่ใช่ทุก scroll surface ควรมี เช่น Chat/detail view ไม่ใช่ pattern ที่ควร pull-to-refresh)

## Requirements

1. Design/Coding ทำ audit เต็มรูปแบบ (ไม่ใช่สุ่มตรวจ) ทุก route ใน `web/app/*/page.tsx` + ทุก fixed/sticky selector ใน CSS — สรุปเป็นตารางจุดที่ผ่าน/จุดที่ขาด พร้อมอ้าง grep evidence จริง (ตามวินัยของ session นี้ — ห้ามเดา ห้ามสรุปจากการ sample)
2. เสนอ fix เฉพาะจุดที่ขาดจริง — ห้ามเปลี่ยน layout/behavior ของจุดที่ทำถูกอยู่แล้ว
3. Pull-to-refresh: เสนอเฉพาะจุดที่เป็น feed/list pattern เดียวกับ home ชัดเจน ไม่ใช่ทุก scroll surface (ตามที่ epic เขียนไว้ว่า "ตรวจให้ครบ" ไม่ใช่ "เพิ่มทุกที่")
4. ห้ามเปลี่ยน business logic, Supabase contract หรือ feature ที่ใช้งานอยู่ (ตาม acceptance criteria เดิมของ epic)
5. Regression: lint/typecheck/build ต้องผ่าน + QA อิสระต้องตรวจซ้ำก่อนเข้า Deploy gate ตามมาตรฐานเดิมของ epic นี้ทุก track ที่ผ่านมา

## Acceptance Criteria

- มี audit report ที่ระบุจุดขาดจริงทุกจุดพร้อม evidence (grep/ตรวจ source) ไม่ใช่ assumption
- ทุกจุดที่ระบุว่า "ขาด" ต้องได้รับการแก้ไขจริงและ verify ซ้ำ (ไม่ implement เกิน scope ที่ audit พบ)
- Pull-to-refresh ใหม่ (ถ้ามี) ต้อง reuse mechanism เดิมจาก home feed ไม่ implement ซ้ำใหม่จากศูนย์
- QA ยืนยัน PASS ก่อน Deploy — ตามมาตรฐาน "never trust self-report" ของ epic นี้ทุก track

## Priority

P2 (ตามลำดับเดิมของ epic — เริ่มหลัง Track 2/3 เสร็จ)

## Handoff

→ **AI Design** ทำ audit เต็มรูปแบบทั้ง 2 หัวข้อ (safe-area + overscroll/pull-to-refresh) แล้วเขียน spec พร้อมตารางจุดขาด/ข้อเสนอแก้ ให้ Founder อนุมัติก่อน AI Coding เริ่ม (ตามกติกาถาวรของ epic — audit/technical polish ก็ยังต้องผ่าน spec review แม้ไม่ใช่ UI ใหม่ เพราะบางจุดอาจกระทบ spacing ที่มองเห็นได้)

## Design Audit — ผลสรุป (AI Design, 2026-09-20)

Spec เต็ม: `.wyn/docs/design/wyn-182-platform-integration-polish.md`

**Audit 1 (Safe-area)**: ตรวจ position:fixed/sticky ครบทุก selector ใน `web/app/*.css` (36 ไฟล์) + module CSS (2 ไฟล์) — พบ GAP จริง 3 จุด: `.wyn-profile-tabs`, `.golden-club-tabs` (ทั้งคู่เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch) + `.home-drawer` (defensive ล้วนๆ) ตรวจ cascade ตามบทเรียน WYN-175 ด้วย พบ cascade regression จริงนอก scope ทางการ 2 จุด (`.wyn-profile-topbar`, `.flutter-chat-header`) รายงานแยกให้ Founder ตัดสินใจ

**Audit 2 (Overscroll/PTR)**: ยืนยัน `html`/`body` ไม่มี base `overscroll-behavior` จริง — เสี่ยงสูงเพราะ Home/Club/Chat/Profile scroll ผ่าน document ตรงๆ ไม่มี nested container และ Home's PTR ไม่เรียก `preventDefault()` เลย (เสี่ยง native Android pull-to-refresh ชนซ้อน) พบ scroll container ขาด `overscroll-behavior` อีก 6 จุด (action sheet/modal ที่ reuse กว้าง) วิเคราะห์กลไก PTR ของ Home ละเอียดสำหรับ extract เป็น hook กลาง ตรวจทีละหน้าจริงแล้วแนะนำเพิ่ม PTR ที่ Club posts tab, Notifications, Bookmarks (Profile feed เข้าเกณฑ์เดียวกันแต่เสนอแยกเป็นตัวเลือก ไม่รวม default)

**รอ Founder ตัดสินใจ 3 ประเด็นก่อน AI Coding เริ่ม**: (ก) safe-area tabs 2 จุดที่เปลี่ยน spacing บนอุปกรณ์มี notch (ข) `overscroll-behavior-y: contain` ที่ html/body ที่เปลี่ยนพฤติกรรม scroll ทั้งแอป (ค) PTR ใหม่ 3 หน้า (+Profile เป็นตัวเลือกเสริม) ต้อง gate ด้วย staged-rollout (`isDeveloperAccount()`) หรือไม่

## Founder Decision (2026-09-20)

ตอบผ่าน AskUserQuestion ครบ 3 ข้อ:
1. **Safe-area tabs (`.wyn-profile-tabs`, `.golden-club-tabs`)** — **อนุมัติ** ให้แก้ตามที่เสนอ
2. **`overscroll-behavior-y: contain` ที่ `html`/`body`** — **อนุมัติ** ให้แก้ตามที่เสนอ
3. **Pull-to-refresh scope** — **อนุมัติให้รวม Profile feed เข้าไปด้วย เป็น 4 หน้ารวม**: Club detail (แท็บโพสต์), Notifications, Bookmarks, Profile feed — Founder ไม่ได้เลือกตัวเลือก "ไม่ต้อง gate" จึงยึดตาม default ที่ spec เสนอไว้: **gate ทั้ง 4 หน้าด้วย staged-rollout (`isDeveloperAccount()`)** ตาม WYN-125 เนื่องจากเป็น user-facing feature ใหม่

**Scope สุดท้ายสำหรับ AI Coding**: fix proposal ข้อ 1-10 ทั้งหมดตาม spec (safe-area 3 จุด + overscroll 7 จุด รวม html/body) + extract pull-to-refresh hook จาก `home-screen.tsx` ไปใช้ใน 4 หน้า (Club posts tab, Notifications, Bookmarks, Profile feed) โดย gate ด้วย `isDeveloperAccount()` เป็นค่าเริ่มต้น

→ ส่งต่อ **AI Coding** implement ตาม scope นี้

## Implementation (AI Coding, 2026-09-20)

Implement ตาม fix proposal ทั้ง 10 ข้อ + pull-to-refresh 4 หน้า ตรงตาม scope ที่ Founder อนุมัติ ไม่ขยาย/ไม่ตัดข้อไหน ก่อนแก้แต่ละจุด re-verify selector/line จริงในโค้ดปัจจุบัน (ไม่เชื่อ line number ใน spec เฉยๆ) และ grep cascade ซ้ำทุกจุด — สอดคล้องกับคำเตือนใน task brief

### A. Safe-area (3 จุด — ตรงตาม spec เป๊ะ)
- `web/app/profile-golden-final.css` — `.wyn-profile-tabs`: เพิ่ม `padding-top: env(safe-area-inset-top)`, เปลี่ยน `height`/`min-height` เป็น `calc(56px + env(safe-area-inset-top))`
- `web/app/club-detail-golden.css` — `.golden-club-tabs`: เพิ่ม `padding-top: env(safe-area-inset-top)`, เปลี่ยน `height` เป็น `calc(54px + env(safe-area-inset-top))`
- `web/app/parity-final.css` — `.drawer-menu-list`: เพิ่ม `padding-bottom: env(safe-area-inset-bottom)`

### B. Overscroll (7 จุด — ตรงตาม spec เป๊ะ)
- `web/app/globals.css`: เพิ่ม rule ใหม่ `html, body { overscroll-behavior-y: contain; }` ต่อจาก `body {}` เดิม
- `.route-modal` (`phase3.css`), `.requests-modal` (`parity-completion.css`), `.detail-activity-content` (`post-detail-parity.css`), `.golden-drop-sheet` (`golden-drop-card.css`), `.golden-club-sheet` (`club-detail-golden.css`), `.audit-action-sheet` (`parity-audit.css`) — เพิ่ม `overscroll-behavior: contain;` เข้า rule เดิมทุกจุด

Cascade re-verify: grep ทั้ง 9 selector ที่แก้ (safe-area 3 + overscroll 6, ไม่รวม html/body) ยืนยันว่าแต่ละ selector ประกาศ property ที่แก้เพียงจุดเดียวใน `app/*.css` ทั้ง repo (มี `.route-modal` ประกาศซ้ำใน `phase3.css` media query `@media (min-width:681px)` แต่แก้แค่ `border-radius` ไม่แตะ `overflow`/`overscroll-behavior` จึงไม่ใช่ cascade conflict)

### C. Pull-to-refresh — extract hook + roll out 4 หน้า (gated)
- สร้าง `web/lib/use-pull-to-refresh.ts` — extract เฉพาะ pull-gesture logic (canPull/damping/threshold/haptic/spinner state) จาก `home-screen.tsx` เดิม (บรรทัด ~715-846) เป็น hook `usePullToRefresh({ enabled, onRefresh })` คืนค่า `{ pullDistance, refreshing, onTouchStart, onTouchMove, onTouchEnd, onTouchCancel, refresh }` — `enabled` รับได้ทั้ง `boolean` หรือ `() => boolean` (Home ต้องใช้ getter เพราะอ่านค่าจาก ref `visibleModeRef.current` ซึ่ง React's `react-hooks/refs` lint rule ห้ามอ่านตรงๆ ตอน render) — เพิ่ม `refresh()` แยกสำหรับ trigger แบบ manual (ใช้กับปุ่มแตะ bottom-nav tab ซ้ำของ Home ที่ใช้ spinner state เดียวกับ pull เดิม)
- Refactor `web/components/home/home-screen.tsx`: horizontal tab-swipe logic (ผูกกับ `modeIndex`/`switchMode`) ยังคงอยู่ใน component เดิมทั้งหมด ไม่แตะ — เรียก `pull.onTouchMove/onTouchEnd` แบบ unconditional ทุก touch event แล้วปล่อยให้ hook เองตัดสินใจว่าจะ pull หรือไม่ (พิสูจน์ทางคณิตศาสตร์แล้วว่าเงื่อนไข shouldRefresh กับเงื่อนไข tab-switch แยกกันเป็น mutually exclusive จึงไม่ต้อง coordinate ระหว่างสอง gesture) — `refreshVisibleMode` ตัดการจัดการ `refreshing`/`pullDistance` state ของตัวเองออก (ย้ายไปอยู่ใน hook) เหลือแค่ fetch+apply snapshot
- สร้าง `web/lib/use-is-developer-account.ts` — wrap `client.rpc("is_developer_account")` แบบเดียวกับที่ `components/settings-route.tsx`'s `VersionFooter` ใช้อยู่แล้ว (fail-closed: false จนกว่าจะได้ `true` จริง) เพื่อไม่ต้อง inline RPC call ซ้ำ 4 จุด
- Wire เข้า 4 หน้า ตาม scope: `web/components/notifications-route.tsx`, `web/components/bookmarks-route.tsx`, `web/components/profile-route.tsx` (`ProfileFeed`), `web/components/club-detail-golden.tsx` (เฉพาะตอนแท็บ "posts" active — `enabled: isDeveloper && tab === "posts"`) — ทุกจุด reuse spinner UI pattern เดียวกับ Home (`route-system-spinner tiny`)
- Home's own pull-to-refresh **ไม่ gate** (ของเดิมที่ชิปแล้ว) — 4 หน้าใหม่ gate ด้วย `useIsDeveloperAccount` ตามที่ Founder อนุมัติ

### Validation
- `npm run lint` / `npm run typecheck` / `npm run build` ใน `web/` — ผ่านสะอาดทั้ง 3 (ไม่มี error ใหม่, warning 3 จุดเดิมที่มีอยู่ก่อนแก้ไม่เปลี่ยนแปลง — ยืนยันด้วย `git stash` เทียบ baseline)
- เขียน Playwright harness ชั่วคราว (`web/__wyn182_verify.mjs`, ลบแล้วหลังใช้) รันกับ dev server จริง (`next dev --port 3100`) ผ่านทั้งหมด **36/36 checks**:
  - Static CSS source check ทั้ง safe-area 3 จุด + overscroll 7 จุด + cascade re-verify
  - Live browser check บน route สาธารณะ (`/welcome`, ไม่ต้อง auth เพราะ CSS ทั้งหมด import แบบ global ใน `app/layout.tsx` ใช้ร่วมทุก route) จำลอง safe-area inset จริงผ่าน Chrome DevTools Protocol (`Emulation.setSafeAreaInsetsOverride`, 47px/34px) ยืนยัน computed padding/height ตรงตามสูตร ทั้งกรณีมี inset และ baseline (inset=0, ไม่เปลี่ยนพฤติกรรมเดิมบนอุปกรณ์ไม่มี notch) — และยืนยัน overscroll-behavior ชนะ cascade จริงทั้ง 7 จุด รวม html/body
  - Pull-to-refresh: สร้าง dev-only fixture ชั่วคราว (pattern เดียวกับ `/dev/home-fixture` ที่มีอยู่แล้วในระบบ, ลบแล้วหลังใช้) mount `usePullToRefresh` ของจริง จำลอง touch gesture จริงผ่าน CDP `Input.dispatchTouchEvent` — ยืนยัน trigger `onRefresh` เมื่อ gate เปิดและลากผ่าน threshold, ไม่ trigger เมื่อลากไม่ถึง threshold, ไม่ trigger และไม่ขยับ spinner state เลยเมื่อ gate ปิด, กลับมาทำงานปกติเมื่อเปิด gate ใหม่
  - Wiring check (source-level): ยืนยันทั้ง 4 หน้าใหม่ import และเรียก `useIsDeveloperAccount`/`usePullToRefresh` จริง, Club detail gate เฉพาะแท็บ posts, Home ใช้ hook + คง horizontal-swipe logic เดิม + tab-tap-refresh ใช้ `pull.refresh()`
- **ข้อจำกัดที่ต้องแจ้ง QA**: sandbox นี้ไม่มี Supabase backend จริง (`.env.local` ไม่ถูกตั้งค่า) จึงไม่สามารถ mount route ที่ผ่าน `DeveloperRouteGate` จริง (Notifications/Bookmarks/Club detail/Profile) พร้อม session จริงได้ — การทดสอบ pull-gesture ข้างต้นเป็นการ mount hook จริงผ่าน fixture แยก (ไม่ใช่ route จริง) และการ wire เข้า 4 หน้าเป็น source-level verification (grep/regex ยืนยันจริงว่ามีการเรียกใช้ ไม่ใช่แค่ assumption) — **QA ต้องทดสอบซ้ำบน environment ที่มี Supabase backend จริง (staging)**: (1) `is_developer_account()` RPC gate เปิด/ปิดจริงกับบัญชี dev/บัญชีทั่วไป (2) pull-to-refresh ทำงานจริงใน Club detail (ต้องไม่ทำงานตอนแท็บแชท/เกี่ยวกับ), Notifications, Bookmarks, Profile feed (3) Home's pull-to-refresh + horizontal tab-swipe ยังทำงานเหมือนเดิมทุกอย่างบน route จริง (ผู้เขียนพิสูจน์ทางคณิตศาสตร์แล้วว่า 2 gesture นี้ mutually exclusive แต่ควรยืนยันด้วยการใช้งานจริงอีกชั้น) (4) native pull-to-refresh ของ Android Chrome ไม่ชนกับของแอปอีกต่อไปหลังเพิ่ม `overscroll-behavior-y: contain` (Design spec เองก็ระบุไว้ว่าต้องทดสอบบน Android Chrome จริงเท่านั้น ไม่ใช่ desktop emulation)
- Revert `web/next-env.d.ts` ที่ dev server auto-touch แล้ว (`git checkout -- web/next-env.d.ts`)

### สรุปไฟล์ที่แก้
CSS: `globals.css`, `phase3.css`, `parity-completion.css`, `post-detail-parity.css`, `golden-drop-card.css`, `club-detail-golden.css`, `parity-audit.css`, `parity-final.css`, `profile-golden-final.css`
Component: `components/home/home-screen.tsx`, `components/notifications-route.tsx`, `components/bookmarks-route.tsx`, `components/profile-route.tsx`, `components/club-detail-golden.tsx`
ใหม่: `lib/use-pull-to-refresh.ts`, `lib/use-is-developer-account.ts`

→ ส่งต่อ **AI QA & Security** ตรวจซ้ำอิสระก่อนเข้า Deploy gate (ห้ามเชื่อ self-report ของ AI Coding ตามมาตรฐานเดิมของ epic)

## QA (AI QA & Security, 2026-09-20)

**หมายเหตุ environment ก่อนเริ่ม (สำคัญ ไม่ใช่บั๊กของ WYN-182 แต่เป็น process finding ที่ต้องบันทึก)**: worktree ที่ได้รับมอบหมาย (`.claude/worktrees/agent-a276daa8c6894895c`) ตอนเริ่มงานอยู่ที่ branch `worktree-agent-a276daa8c6894895c` (HEAD = merge commit `3239b681`, PR #561) ซึ่ง**ไม่มี** commit `f58586a1` อยู่ในประวัติเลย (`git merge-base --is-ancestor f58586a1 HEAD` = false) — ไฟล์ `web/lib/use-pull-to-refresh.ts`/`use-is-developer-account.ts` ไม่มีอยู่จริงในต้นไม้ของ worktree เลยตอนนั้น ตรวจพบตอนรัน `npm run dev`/build แล้วเจอ "Module not found" หลัง `npm run build` รอบแรกผ่าน (เพราะรอบแรก build จากโค้ดคนละคอมมิทโดยไม่รู้ตัว) แก้ด้วย `git checkout --detach f58586a1` เข้า worktree เดิม (ไม่แตะ branch `claude/wynos-online-version-1pqqws` ที่ worktree อื่นเช็คเอาท์อยู่ ไม่ force push/rewrite ใดๆ) ยืนยัน `git log -1` = `f58586a1` และไฟล์ `lib/` ครบถูกต้องก่อนเริ่มตรวจใหม่ทั้งหมด — **ทุกผลลัพธ์ด้านล่างนี้มาจากการตรวจซ้ำบนคอมมิท `f58586a1` จริงเท่านั้น** (lint/typecheck/build/regression suite รอบแรกที่รันผิดคอมมิทถูกทิ้งไปทั้งหมด ไม่ถูกนับ)

**Test Cases**: อ่าน diff จริงทีละไฟล์ (`git show f58586a1`) + re-verify cascade ทุก selector ที่แก้ด้วย grep ทั้ง repo (ไม่ใช่แค่ `app/`) อิสระจาก AI Coding + ตรวจ `layout.tsx` CSS import order + อ่านโค้ดเต็มไฟล์ `use-pull-to-refresh.ts`/`use-is-developer-account.ts`/`home-screen.tsx`/4 หน้าที่ wire ทีละบรรทัด + พิสูจน์ทางคณิตศาสตร์ซ้ำเองว่าเงื่อนไข pull-gesture กับ tab-swipe mutually exclusive จริง (ไม่เชื่อคำอ้าง "พิสูจน์แล้ว") + สร้าง Playwright harness ใหม่ทั้งหมดของตัวเอง (ไม่ reuse ของ AI Coding) รันกับ dev server จริง ใช้ CDP `Emulation.setSafeAreaInsetsOverride` จำลอง notch จริง + สร้าง dev-only fixture ของตัวเองมาวาง hook จริง (`usePullToRefresh`) แล้วจำลอง touch gesture จริงผ่าน CDP `Input.dispatchTouchEvent` + typecheck/lint/build อิสระ + รัน regression suite เต็ม (`npx playwright test`) หลังติดตั้ง browser binaries เอง + ตรวจ RPC `is_developer_account()` ใน `supabase/schema.sql` (SECURITY DEFINER, fail-closed, auth.uid()-only)

### A. Safe-area (3 จุด)
ยืนยันตรงตาม diff ที่อ้างเป๊ะทั้ง 3 จุด (`profile-golden-final.css:200-212`, `club-detail-golden.css:31`, `parity-final.css:219`) — grep ทั้ง repo (ไม่ใช่แค่ `app/`) ยืนยันทั้ง 3 selector ประกาศ base rule ครั้งเดียวเท่านั้น ไม่มี selector อื่นแตะ `height`/`padding-top`/`padding-bottom` ของ 3 ตัวนี้ซ้ำที่ไหนเลย (child selector อย่าง `.golden-club-tabs button` ไม่กระทบ parent) — ไม่มีความเสี่ยง cascade แบบ WYN-175 จริง `layout.tsx` import `globals.css` เป็นไฟล์แรกสุด (บรรทัด 8) แต่ไม่มีผลต่อ tie-break เพราะไม่มี selector คู่แข่งอยู่แล้ว

Live verification ด้วย CDP `Emulation.setSafeAreaInsetsOverride` (top:47/bottom:34 จำลอง iPhone notch) บน dev server จริง: `.wyn-profile-tabs` computed `height`=103px `padding-top`=47px ตรงสูตร `calc(56px+inset)` เป๊ะ, `.golden-club-tabs` computed `height`=101px `padding-top`=47px ตรงสูตร `calc(54px+inset)`, `.drawer-menu-list` computed `padding-bottom`=34px ตรง `env(safe-area-inset-bottom)` — รีเซ็ต inset=0 (จำลอง Android ส่วนใหญ่ไม่มี notch) ยืนยัน 3 selector กลับมาเหมือนค่าก่อนแก้เป๊ะ (56px/54px/0 โดยไม่มี padding เพิ่ม) **ไม่มี regression บนอุปกรณ์ไม่มี notch**

### B. Overscroll (7 declaration)
ยืนยันทั้ง 7 จุดตรงตามที่อ้าง (`globals.css` html/body + 6 sheet/modal) grep ทั้ง repo ยืนยันซ้ำเองว่าทั้ง 6 selector (ไม่รวม html/body) ประกาศครั้งเดียวในทั้งระบบ อ่าน `phase3.css:471-472` เอง (media query `min-width:681px`) ยืนยันแก้แค่ `border-radius` จริง ไม่แตะ `overflow`/`overscroll-behavior` ตามที่ AI Coding อ้าง และอ่าน `system-parity-lock.css:472-473` เพิ่มเติมเอง (จุดที่ AI Coding ไม่ได้พูดถึง แต่ก็แตะ `.route-modal-backdrop:has(...)` เหมือนกัน) พบว่าแก้แค่ `padding`/`align-items` สำหรับ composer variant เท่านั้น ไม่กระทบเช่นกัน — ยืนยัน cascade ปลอดภัยครบ

Live verification (browser จริง ไม่ใช่แค่อ่าน source): computed `overscroll-behavior-y` = `contain` ทั้ง `html` และทั้ง 6 selector (`.route-modal`, `.requests-modal`, `.detail-activity-content`, `.golden-drop-sheet`, `.golden-club-sheet`, `.audit-action-sheet`) — ยืนยัน cascade ชนะจริงในเบราว์เซอร์ ไม่ใช่แค่ใน source

### C. Pull-to-refresh
อ่าน `use-pull-to-refresh.ts`/`use-is-developer-account.ts` เต็มไฟล์ — คุณภาพโค้ดดี: fail-closed โดยธรรมชาติ (`useState(false)` ไม่เปลี่ยนจนกว่า RPC ตอบ `true` จริง), ใช้ `refreshingRef` (ref) แทน state ธรรมดาสำหรับ gating ภายใน hook เอง (แม่นยำกว่าเดิมที่อ่าน closure state ที่อาจ stale)

**พิสูจน์ mutual-exclusivity ซ้ำเอง** (ไม่เชื่อคำอ้าง): เทียบเงื่อนไขจริงบรรทัดต่อบรรทัดระหว่าง hook ใหม่กับโค้ดเดิมก่อนแก้ (`git show f58586a1^:web/components/home/home-screen.tsx`) — เงื่อนไข trigger ของ hook (`deltaY>0 && |deltaY|>1.1|deltaX|`) implies `|deltaY|>|deltaX|` เสมอ (เพราะ 1.1>1) ซึ่งขัดแย้งกับเงื่อนไข swipe เดิม (`|deltaX|>8 && |deltaX|>|deltaY|`) โดยธรรมชาติทางคณิตศาสตร์ — ตรวจแล้วว่า mutually exclusive จริง ไม่ใช่แค่คำกล่าวอ้าง และไล่เทียบทุก branch (onTouchMove/onTouchEnd/onTouchCancel) ระหว่างโค้ดเก่ากับใหม่ทีละเงื่อนไข ยืนยัน behavior เทียบเท่ากันทุกกรณี รวมถึงกรณี "pull สำเร็จแล้ว spring-back ไม่ trigger switchMode ซ้ำ" ที่ AI Coding อ้างไว้

**Wiring 4 หน้า** (grep+read จาก `git show f58586a1` และไฟล์จริงใน worktree หลังแก้ checkout แล้วตรงกัน 100%):
- Notifications (`notifications-route.tsx:189-190`): `enabled: isDeveloper`
- Bookmarks (`bookmarks-route.tsx:47-48`): `enabled: isDeveloper`
- Profile feed (`profile-route.tsx:86-87`): `enabled: isDeveloper`
- Club detail (`club-detail-golden.tsx:558-559`): `enabled: isDeveloper && tab === "posts"` — **ตรวจ trace เอง ไม่เชื่อว่ามี `&& tab === "posts"` แล้วจบ**: touch handler (`pull.onTouchStart/Move/End/Cancel`) ผูกอยู่กับ `<section className="golden-club-posts">` ที่ render เฉพาะตอน `tab === "posts"` เท่านั้น (อยู่ใน ternary `{tab === "posts" ? (...) : tab === "chat" ? ... : ...}`) — เป็น double-guard (ทั้ง `enabled` prop และ DOM ไม่ถูก mount เลยตอนอยู่แท็บอื่น) ปลอดภัยกว่าที่ spec ขอด้วยซ้ำ
- Home (`home-screen.tsx:441`): `enabled: () => mode === visibleModeRef.current` — **ไม่มี** `useIsDeveloperAccount` ใน import/เนื้อไฟล์เลย (grep ยืนยัน 0 match) — Home ยังคง ungated ตรงตาม Founder decision

**ตรวจ pattern บั๊กที่ session นี้เจอซ้ำๆ (guard ใส่ไม่ครบทุกจุดใน batch เดียวกัน แบบ WYN-176)**: ไล่ทั้ง 4 จุดแล้ว **ไม่พบ** ความไม่สม่ำเสมอ — ทุกจุด gate ด้วย `isDeveloper` ครบ, Club detail เพิ่ม tab-scope ถูกต้อง, Home ไม่ gate ตามที่ควรจะเป็น ไม่มีจุดไหนลืม/ใส่ผิด

**Live gesture test อิสระ**: สร้าง dev-only fixture ของตัวเอง (`app/dev/qa-wyn182-ptr-fixture/page.tsx`, mount `usePullToRefresh` ของจริงตรงๆ ไม่ mock) ลบทิ้งหลังใช้แล้ว รันผ่าน CDP `Input.dispatchTouchEvent` จำลองการลากนิ้วจริง:
- gate ปิด (ค่าเริ่มต้น) → ลากเกิน threshold → `onRefresh` **ไม่ถูกเรียกเลย** และ `pullDistance` ไม่ขยับแม้แต่น้อย (ยืนยัน fail-closed สมบูรณ์ ไม่ใช่แค่ปิดปลายทาง)
- เปิด gate → ลากเกิน threshold → `onRefresh` ถูกเรียก**พอดี 1 ครั้ง**
- เปิด gate → ลากสั้นกว่า threshold → ไม่ trigger
- เปิด gate → ลากแนวนอนล้วนๆ → ไม่ trigger (sanity check mutual-exclusivity เวอร์ชัน generic)
- ปิด gate กลับ → ลากเกิน threshold อีกครั้ง → ไม่ trigger (ยืนยัน toggle กลับทำงานถูกต้อง ไม่ค้างสถานะเดิม)

**ข้อจำกัดที่ยืนยันตรงกับที่ AI Coding แจ้งไว้ (ตรวจสอบเองแล้ว ไม่ใช่แค่เชื่อ)**: environment นี้ไม่มี Supabase backend จริงเช่นกัน (ตรวจแล้ว: ไม่มี `.env.local`, ไม่มี `NEXT_PUBLIC_SUPABASE_*` ใน env variables เลย) — จึงทดสอบ live gate ผ่าน RPC จริงกับบัญชี dev/ทั่วไปจริงไม่ได้ในรอบนี้เช่นกัน **ยังต้องทดสอบบน staging/production ที่มี Supabase จริงก่อนเปิดให้ non-dev เห็นฟีเจอร์นี้** — สิ่งที่ตรวจแทนได้และตรวจแล้ว: (1) ฟังก์ชัน `is_developer_account()` เอง (`supabase/schema.sql:14079-14092`) เป็นกลไกเดิมที่ผ่าน QA มาแล้วจาก WYN-125 (SECURITY DEFINER, เช็คแค่ `auth.uid()` ของผู้เรียกเอง, ไม่มี SELECT policy ให้ client เห็น, fail-closed สมบูรณ์) WYN-182 ไม่ได้แก้ RPC/schema/RLS ใดๆ เลย ใช้ตรงๆ ตามที่มีอยู่แล้ว (2) hook wrapper (`use-is-developer-account.ts`) ฝั่ง client เรียก RPC ถูกต้อง fail-closed ถูกต้อง (3) กลไก gesture ของ hook เองทำงานถูกต้อง 100% (ยืนยันด้วย live test ข้างบน) จุดเดียวที่ยืนยันไม่ได้ในนี้คือ "RPC ตอบ `true` จริงสำหรับบัญชี dev จริงบน production DB" ซึ่งเป็น environment-only gap ไม่ใช่ code defect และ (4) native pull-to-refresh ของ Android Chrome จริงต้องทดสอบบนอุปกรณ์จริงเท่านั้น (Chromium headless ไม่ reproduce พฤติกรรมระดับ browser chrome นี้) — ยังไม่ได้ยืนยัน ต้องทำก่อนเปิดวงกว้าง

### D. Regression + Build
`npm run lint`: 0 errors, warning 3 จุดเดิม (`chat-inbox-parity.tsx`, `home-screen.tsx`, `profile-route.tsx`) — ยืนยันเป็น pre-existing จริงด้วยการเทียบโค้ดกับ parent commit (`f58586a1^`) เอง ไม่ใช่แค่เชื่อคำอ้าง
`npm run typecheck`: ผ่านสะอาด 0 error
`npm run build`: สำเร็จ ไม่มี error, ทุก route generate ครบ (31 route)
`git status` หลัง build: สะอาด ไม่มี `next-env.d.ts` diff ค้าง
Regression suite เต็ม (`npx playwright test`, ติดตั้ง chromium+webkit binaries เองก่อนรัน): **159/159 ผ่านทั้งหมด (0 failed)** — ดีกว่า baseline ที่ระบุไว้ใน task brief (6 failures จาก missing `chromium_headless_shell`) เพราะ environment นี้ติดตั้ง browser binary ครบ ไม่มี failure ที่เกี่ยวหรือไม่เกี่ยวกับ diff นี้เลย

### E. Security Review
`is_developer_account()` (`supabase/schema.sql:14062-14102`): `SECURITY DEFINER`, เช็คเฉพาะ `auth.uid()` ของผู้เรียกเอง ไม่รับ parameter (ไม่มีทาง enumerate บัญชีคนอื่น), ตาราง `developer_accounts` ไม่มี SELECT policy ให้ client เลย (อ่านได้ผ่านฟังก์ชันนี้ทางเดียว), fail-closed ด้วย `coalesce(..., false)` — **เป็นกลไกที่ deploy และผ่าน QA ไปแล้วตั้งแต่ WYN-125** WYN-182 ไม่แตะ schema/RLS/RPC นี้เลย เรียกใช้ตรงๆ เหมือนที่ `settings-route.tsx` ทำอยู่แล้ว — ไม่ใช่ security boundary ใหม่ที่ต้อง re-review ทั้งหมด เป็นแค่ UI-level staged-rollout flag (ไม่ใช่ authorization boundary จริง เพราะ pull-to-refresh ไม่ได้เปิด data access ใหม่ใดๆ — `refresh()`/`load()` ของทั้ง 4 หน้าเรียก fetch function เดิมที่มีอยู่แล้วซึ่งผ่าน RLS ปกติอยู่แล้ว ไม่มี query ใหม่)

ตรวจ diff ทั้งหมดยืนยันไม่มีการแก้ schema/RLS/migration/auth architecture ใดๆ เลย (`git show f58586a1 --stat` มีแค่ CSS 9 ไฟล์ + component 5 ไฟล์ + lib ใหม่ 2 ไฟล์ + doc 2 ไฟล์ ไม่มี `supabase/` เลย) — ไม่ลดระดับ security policy ใดๆ ตรงตามกติกา `AGENTS.md`

**Passed**: 24/24 live-check เองผ่านทั้งหมด (safe-area 8, overscroll 7, pull-to-refresh gesture 9) + wiring/cascade/mutual-exclusivity source-review ทุกจุดตรงตามที่อ้าง + typecheck/lint/build สะอาด + regression suite 159/159

**Failed**: ไม่มี — ไม่พบบั๊กใหม่จาก diff นี้เลยสักจุด

**Severity**: N/A (ไม่มี CRITICAL/HIGH/MEDIUM/LOW บั๊กจากตัว diff เอง)

**Security Findings**: ไม่มี CRITICAL/HIGH — ไม่แตะ RLS/auth architecture, ไม่มี new data-access surface, staged-rollout flag เดิมที่ผ่าน review แล้วจาก WYN-125 ถูกใช้ตรงตามที่ออกแบบไว้

**หมายเหตุ LOW ที่พบเอง (ไม่ block, เป็น process/operational finding ไม่ใช่บั๊กใน diff)**: worktree assignment ที่ได้รับตอนเริ่มงาน HEAD ไม่ตรงกับคอมมิทที่ต้องตรวจจริง (ดูหมายเหตุ environment ด้านบน) แนะนำ DevOps/CTO ตรวจสอบ process การ assign worktree ให้ QA agent ว่า sync กับ branch ที่ระบุใน task ก่อนส่งมอบงานเสมอ เพื่อไม่ให้ QA agent อื่นในอนาคตตรวจโค้ดผิดคอมมิทโดยไม่รู้ตัว (ครั้งนี้จับได้เพราะ build error ชัดเจน แต่ถ้า AI Coding ไม่ได้เพิ่มไฟล์ใหม่ ควรมีจุดสังเกตอื่นที่ชัดกว่านี้)

**Recommendation**: Approve — WYN-182 พร้อมเข้า Deploy gate ต่อ (CTO Final Review → Staging) โดยมีเงื่อนไขต้องยืนยันก่อนเปิดฟีเจอร์ pull-to-refresh ให้ non-developer account เห็นจริง (ตามที่ออกแบบไว้แต่แรกว่าต้อง staged-rollout): (1) ทดสอบ `is_developer_account()` gate จริงบน staging ด้วยบัญชี dev และบัญชีทั่วไป ยืนยัน gate เปิด/ปิดถูกต้อง (2) ทดสอบ pull-to-refresh จริงทั้ง 4 หน้าบนอุปกรณ์จริง โดยเฉพาะ Club detail ต้องไม่ทำงานตอนแท็บแชท/เกี่ยวกับ (3) ทดสอบ Android Chrome จริงว่า native pull-to-refresh ไม่ชนซ้อนกับของแอปอีกต่อไป — ทั้ง 3 ข้อนี้เป็นเงื่อนไขที่ AI Coding เองก็ระบุไว้แต่แรกว่าต้องรอ environment ที่มี Supabase จริง ไม่ใช่ finding ใหม่จาก QA รอบนี้ ไม่ block การเข้า Deploy gate (staging) แต่ต้อง verify ก่อน production widen scope ให้ non-dev เห็น

**Final Status: PASS**
