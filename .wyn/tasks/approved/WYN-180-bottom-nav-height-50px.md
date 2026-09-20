# Design Task — WYN-180

Status: coding done, QA pending — Founder revised the bottom bar height target after seeing the
Home-screen proportions audit (https://claude.ai/artifact/59nJwU9PG5JsWtCwcWtXNK)
Owner: AI Design
Screen: แท็ปบาร์ล่าง — `web/app/bottom-nav.css` เท่านั้น
Purpose: Founder สั่ง "ลดขนาด Bottom Bar เหลือ 50" หลังเห็น audit ที่เทียบสัดส่วนปัจจุบัน (40px content, รวม
safe-area ~60px) กับตัวเลขอ้างอิงเดิมที่ Founder ให้มา (~75px) — ตีความว่า Founder ปรับเป้าหมายของตัวเองลงจาก
~75px เหลือ 50px (ใช้ convention เดียวกับ `--wyn-bottom-nav-height` ที่เป็นค่า content height ไม่รวม safe-area
เหมือนที่ใช้มาตลอดใน WYN-179) — ค่านี้มากกว่า 40px ที่เพิ่ง merge ไปใน WYN-179 (ให้พื้นที่มากขึ้น ไม่ใช่บีบแคบลง)
จึงไม่กระทบการ fit ของไอคอน 28px ที่เพิ่งขยายไป เลยไม่ต้องกังวลเรื่อง overflow
User Flow: ไม่เปลี่ยน
Components: แก้ `--wyn-bottom-nav-height` เท่านั้น
1. มือถือ (breakpoint หลัก): 40px → **50px**
2. Breakpoint แคบ <359px: 38px → **48px** (คงส่วนต่าง 2px เท่าเดิมตามที่เคยทำใน WYN-179)
3. Breakpoint กว้าง ≥681px (floating dock): ไม่แตะ ยังคง 64px เดิม
4. Padding/gap/font-size ของ `.route-nav-link` และขนาดไอคอน (28px) — **ไม่เปลี่ยน** เพราะพื้นที่ใหม่ (50px) มากกว่า
   เดิม (40px) อยู่แล้ว ของเดิมพอดีสบายกว่าเดิมด้วยซ้ำ ไม่มีความเสี่ยง overflow
Interactions: ไม่เปลี่ยน
States: ไม่เปลี่ยน
Responsive Behavior: verified ผ่าน real-CSS-cascade DOM measurement ที่ 340/390/700px — ไม่มี overflow ทุกจุด
Accessibility: ไม่เปลี่ยน (พื้นที่แตะใหญ่ขึ้น ถ้ามีผลก็เป็นผลดี)
Design Rules: ไม่แตะสี/ไอคอน/โครงสร้าง เป็นแค่ตัวเลขความสูงเดียว
Handoff: → **AI Coding** (ทำแล้ว) → **AI QA & Security**

## AI Coding (2026-09-20)

Implementation: แก้ `--wyn-bottom-nav-height` ใน `web/app/bottom-nav.css` จาก 40px→50px (มือถือหลัก) และ
38px→48px (breakpoint แคบ) เท่านั้น ไม่แตะ padding/gap/font/icon size เพราะพื้นที่ใหม่กว้างกว่าเดิม ไม่มีความเสี่ยง
fit ปัญหา — อัปเดต test assertion ที่ล็อกค่าเดิมไว้ 2 จุด (`home-visual-parity.spec.ts`,
`system-visual-parity.spec.ts`) ให้ตรงค่าใหม่ (เรียนรู้จาก WYN-179 ที่เจอ CI แดงเพราะลืมจุดนี้มาก่อน คราวนี้แก้ไปพร้อมกัน)

Files Changed: `web/app/bottom-nav.css`, `web/tests/browser/home-visual-parity.spec.ts`,
`web/tests/browser/system-visual-parity.spec.ts`

Reason: ตรงตามคำสั่ง Founder

Tests: Render จริงผ่าน real-CSS-cascade Playwright (`file://`) วัดค่า DOM จริงที่ viewport 340/390/700px —
`--wyn-bottom-nav-height` = 48/50/64px ตรงสเปกทุกจุด, `scrollHeight === clientHeight` ทุกจุด (ไม่มี overflow)
รัน local Playwright test เฉพาะจุดที่แก้ (`system-visual-parity.spec.ts` dock geometry) ผ่าน

Build: `npm run check` เขียว — 0 error, warning เดิม 3 จุดไม่เกี่ยวข้อง

Known Issues: ไม่มี — พื้นที่เพิ่มขึ้น ความเสี่ยงต่ำกว่า WYN-179 (ที่ลดพื้นที่ลง) เสียอีก

Handoff: → **AI QA & Security**

## AI QA & Security (2026-09-20)

Feature: WYN-180 — bottom nav height 40→50px (มือถือหลัก), 38→48px (breakpoint แคบ)

Environment: sandbox, Playwright + `/opt/pw-browsers/chromium`, real-CSS-cascade render ผ่าน `file://`

Test Cases:
1. `git status --short` + `git diff origin/main HEAD --stat` — ยืนยันว่ามีแค่ 3 ไฟล์เปลี่ยน
   (`bottom-nav.css`, `home-visual-parity.spec.ts`, `system-visual-parity.spec.ts`) ไม่กระทบไฟล์อื่น
2. Render จริง + วัดค่า DOM (`getComputedStyle`/`getBoundingClientRect`/`scrollHeight` vs `clientHeight`) ที่
   viewport 340/390/700px: `--wyn-bottom-nav-height` = 48px/50px/64px ตรงสเปกทุกจุด, ไม่มี content overflow
   เลยสักจุด (scrollHeight === clientHeight ทั้ง 3 breakpoint)
3. Grep หา hardcode 40px/38px ที่เหลือในโฟลเดอร์ test ทั้งหมด — ยืนยันไม่มีจุดตกหล่น (จุดอื่นที่เจอ 40px เป็น
   `grid-template-columns`/avatar size คนละเรื่อง ตรวจ context แล้วไม่เกี่ยวกับ bottom nav)
4. รัน local Playwright จริง 4 test ที่เกี่ยวข้อง (`pixel-parity-pass-2`, `system-visual-parity` dock geometry
   + canonical stylesheet, `parity.spec.ts` source contracts) — ผ่านทั้งหมด 4/4 ไม่ใช่แค่เชื่อ assertion ตรงตัวเลข
5. `npm run check` รันอิสระอีกรอบ — เขียว 0 error, warning เดิม 3 จุดไม่เกี่ยวข้อง

Passed: 5/5
Failed: ไม่มี
Severity: -

Security Findings: ไม่มี — CSS ตัวแปรความสูงเดียว ไม่มี logic เปลี่ยน

Recommendation: PASS — ความเสี่ยงต่ำมาก (เพิ่มพื้นที่ ไม่ใช่ลด) verify ครบทุกจุดที่เคยพลาดใน WYN-179

Final Status: **PASS**

## CRITICAL fix (2026-09-20, Codex P1 finding on PR #560 — pre-existing production bug, not new)

Codex found something much bigger than a WYN-180 nitpick: **the persistent bottom nav bar's real rendered
height has never actually been controlled by `--wyn-bottom-nav-height` as scoped in `bottom-nav.css`, in
production, at all** — since long before this session touched it.

**Root cause**: `app/layout.tsx` renders `<AppBottomNavHost />` (which renders `.route-bottom-nav`) as a
**sibling** of `<PageTransition>{children}</PageTransition>` (which is where `.route-with-bottom-nav`, from
`phase3-ui.tsx`, actually lives) — both are children of `<body>`, not ancestor/descendant. A CSS custom
property declared on `.route-with-bottom-nav` (where every past change to this variable, mine included, was
scoped) is invisible to `.route-bottom-nav` in the sibling subtree — custom properties only inherit down the
DOM tree. `.route-bottom-nav`'s `height: calc(var(--wyn-bottom-nav-height) + ...)` was instead resolving
`--wyn-bottom-nav-height` from **`app/parity.css`'s `:root` block, which declared its own unrelated value:
`80px`** (tagged WYN-158, predates this session entirely).

**Proven, not assumed** — rebuilt a static harness that mirrors `layout.tsx`'s actual sibling structure
(not the flawed nested one every prior harness used) and loaded the pre-fix files from commit `d54b84f8`
(this PR's own last commit before this fix):
- Real nav height: **80px**
- `.route-with-bottom-nav` padding-bottom: **50px**
- → a 30px gap where the last 30px of page content sits behind the nav bar, on every page with the bottom
  nav visible, in production, right now (and has been since long before WYN-179/180 — the 40px/44px values
  from earlier tasks never reached the real bar either, only ever the 80px from parity.css)

**Why every prior test/harness missed it**: `home-visual-parity.spec.ts`'s browser test renders `HomeFixture`
(`components/home/home-fixture.tsx`), which nested `<BottomNavigation>` *inside* the `.route-with-bottom-nav`
div — a structure that does not match `layout.tsx`. That gave the test (and every manual Playwright harness
built during WYN-178/179/180, mine included) a false pass. The file-content-assertion tests only checked
that `--wyn-bottom-nav-height`'s *declared value* matched a string, never where it was scoped or what
actually won the cascade for the real component tree.

**Fix**:
1. `bottom-nav.css` — moved `--wyn-bottom-nav-height` (and its two breakpoint overrides) from
   `.route-with-bottom-nav` to `:root`, so both sibling subtrees agree on one value
2. `parity.css` — deleted its competing `--wyn-bottom-nav-height: 80px` from `:root` (the actual value that
   had been winning)
3. `home-fixture.tsx` — moved `<BottomNavigation>` out to be a sibling of the `.route-with-bottom-nav` div
   (matching `layout.tsx` exactly), so this fixture's Playwright test exercises the real architecture
   instead of masking this class of bug again
4. `system-visual-parity.spec.ts` — added assertions locking `--wyn-bottom-nav-height` to `:root` in
   `bottom-nav.css` and forbidding its declaration in every other stylesheet that has ever redefined
   bottom-nav rules, so this exact regression can't silently return

**Re-verified after the fix**, same real-sibling-structure harness, current files: nav height = 50px,
`.route-with-bottom-nav` padding-bottom = 50px — now agree. `npm run check` green. 4 local Playwright tests
covering the affected contracts (including the newly strengthened one) pass.

**Impact on already-merged work**: WYN-179 (merged, live in production) never actually resized the real bar
either — production's real bottom nav has been 80px this whole time, not 44px/40px as every deployment log
claimed. This fix corrects that for real, for the first time. Flagging this explicitly to the Founder as a
production-impacting bug that predates this task, now resolved in the same PR.
