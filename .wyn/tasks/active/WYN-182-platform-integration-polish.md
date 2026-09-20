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
