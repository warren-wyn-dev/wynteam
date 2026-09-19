# Product Task — WYN-175

Status: PASS (QA รอบ 2, 2026-09-19) — approved, ส่งต่อ AI Deploy & DevOps
Owner: AI Product Manager → AI Design (`.wyn/docs/design/wyn-175-perceived-speed-motion.md`) → AI Coding (เสร็จ 2026-09-19) → AI QA & Security (FAIL รอบ 1) → AI Debug Engineer (fix เสร็จ) → AI QA & Security (PASS รอบ 2) → AI Deploy & DevOps
Feature: WYNOS Web Beta1 — Perceived Speed & Motion (WYN-174 Track 1, Founder เลือก 2026-09-19)
Goal: ทำให้การใช้งาน `wynos.online` รู้สึกเหมือนแอปมือถือ native มากที่สุด ด้วยการเปลี่ยนจากการสลับหน้าแบบ instant/snap เป็นมี motion, และแทน spinner/blank loading ด้วย skeleton state + press feedback ที่ตอบสนองทันทีเมื่อแตะ
Target User: ผู้ใช้ WYNOS ทั่วไปที่เข้าเว็บผ่านมือถือ (iOS Safari/Android Chrome) เป็นหลัก
Problem: (แก้ไขจาก audit เดิม — ดู DECISIONS.md 2026-09-19 "AI Design ตรวจโค้ดจริง") ที่จริง `PageTransition` และ skeleton system มีอยู่แล้ว (ใช้ใน Home/Profile/Chat) ช่องว่างจริงมีแค่: (1) Search/Notifications ยังใช้ spinner แทน skeleton (2) การ์ด/แถวบางจุดยังไม่มี press feedback (3) route transition ปัจจุบันตั้งใจให้เบามาก (fade 70ms) — ต้องให้ Founder ตัดสินใจว่าจะคงไว้หรือเพิ่ม motion ให้ชัดขึ้น

## ขอบเขต (3 ส่วนย่อย)

1. **Route/page transition animation** — เปลี่ยนหน้าใน Next.js router (เช่น Home → Profile, เปิด Post detail, เปิด Chat conversation) ต้องมี motion แบบ native (slide-in/fade คล้าย iOS push/pop หรือ Android shared-axis) แทนการ snap ทันที
   - Budget performance: < 300ms, ใช้ CSS transform/opacity เท่านั้น ห้ามใช้ JS-heavy animation ที่กระทบ frame rate บนมือถือรุ่นล่าง
   - ต้อง respect `prefers-reduced-motion`
2. **Skeleton loading state มาตรฐานทั้งระบบ** — แทนที่ spinner/blank ด้วย skeleton placeholder (โครงร่าง content คร่าวๆ) ระหว่างรอข้อมูลจาก Supabase ในหน้าหลักที่มี data fetch: Home feed, Profile, Chat list/conversation, Search, Notifications, Club
3. **Micro-interaction press feedback** — ปุ่ม/การ์ด/รายการที่กดได้ทั้งระบบ ต้องมี visual feedback ทันทีเมื่อแตะ (เช่น scale-down เล็กน้อย/opacity เปลี่ยน) ก่อนที่ action จริงจะเกิดขึ้น — ให้ความรู้สึก responsive แบบ native

## Requirements

- ไม่เปลี่ยน business logic, data fetching contract, Supabase Auth/RLS/RPC ใดๆ — เป็นงาน presentation layer ล้วนๆ
- ใช้ design system/shared component ที่มีอยู่ (`design-system.css` และ token ที่ WYN-141/WYN-163 วางไว้) ไม่สร้าง pattern ใหม่ซ้ำซ้อน
- Reuse ของเดิมที่มีอยู่แล้วก่อนสร้างใหม่ (เช่น `overscroll-behavior`/`tap-highlight` pattern ที่มีอยู่แล้วหลายไฟล์ CSS)
- ไม่แตะ WYN-163 (visual redesign สี/ทรงปุ่ม) ที่ยัง in-progress — งานนี้คือ motion/timing ไม่ใช่สี/ทรง
- ทดสอบบน physical iPhone Safari จริงก่อนถือว่า done (บทเรียนจาก WYN-158: CI เขียว ≠ ใช้งานได้จริงบนอุปกรณ์จริง)

## Acceptance Criteria

- [ ] เปลี่ยนหน้า (Home/Profile/Chat/Post detail อย่างน้อย) มี transition ที่เห็นชัด ไม่ snap ทันที, วัดเวลา animation < 300ms
- [ ] `prefers-reduced-motion: reduce` ปิด/ลด animation ให้เหลือ fade สั้นๆ หรือไม่มี animation เลย
- [ ] Home feed, Profile, Chat list, Search, Notifications อย่างน้อย มี skeleton loading แทน spinner/blank เดิม
- [ ] ปุ่ม primary/secondary และการ์ดที่กดได้ (post card, chat list item) มี press feedback ที่สังเกตเห็นได้ภายใน 1 frame ของการแตะ
- [ ] ไม่มี regression ต่อ business logic เดิม (lint/typecheck/build ผ่าน, browser smoke test ผ่าน)
- [ ] Founder เห็น mockup/preview ของ motion ก่อน AI Coding เริ่ม implement จริง (ตามกติกาถาวร "UI ใหม่ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด" — สำหรับ motion อาจเป็นวิดีโอ/GIF preview แทนภาพนิ่ง)

## Dependencies

- ต่อยอดจาก WYN-158 (mobile app feel foundation: PWA, gesture, touch-target) — ไม่ทำซ้ำสิ่งที่มีอยู่แล้ว
- ไม่ block และไม่ถูก block โดย WYN-163 (คนละ layer: motion vs. color/shape)

## Priority

P0 — Founder ยืนยันให้เริ่ม track นี้ก่อนใน WYN-174 (2026-09-19)

## Risks

- Animation ที่ทำไม่ดีอาจทำให้ perceived performance แย่ลงแทนที่จะดีขึ้น (โดยเฉพาะมือถือรุ่นล่าง) — ต้องทดสอบจริงบนอุปกรณ์ ไม่ใช่แค่ desktop browser
- Skeleton loading ถ้าออกแบบไม่ตรงกับ layout จริงของ content จะเกิด layout shift ตอนข้อมูลโหลดเสร็จ (ต้องออกแบบ skeleton ให้ขนาด/ตำแหน่งตรงกับ content จริง)
- Scope อาจ creep ไปทุกหน้าในระบบถ้าไม่ล็อกรายการหน้าที่ทำรอบแรกให้ชัด (ล็อกไว้ที่ Home/Profile/Chat/Search/Notifications ก่อนตาม Acceptance Criteria)

## Recommendation

ส่งต่อ **AI Design** ทำ audit หน้าที่ต้องมี transition/skeleton/press-feedback ทั้งหมด + ทำ motion spec (timing, easing, reduced-motion behavior) และ mockup/preview ให้ Founder อนุมัติก่อนส่ง AI Coding

## Handoff

→ **AI Design**: ทำ audit + motion spec + preview สำหรับ route transition, skeleton loading, press feedback ตามขอบเขตนี้ ก่อนส่งต่อ AI Coding

## Implementation (AI Coding, 2026-09-19)

**Implementation**:
1. Skeleton — เพิ่ม `SearchUserSkeleton`, `SearchClubSkeleton`, `SearchDiscoverySkeleton`, `NotificationSkeleton` ใน `components/ui/skeleton.tsx` (reuse `SkeletonBlock`/`SkeletonCircle` เดิม, ขนาด row ตรงกับ CSS จริงของ `.route-person-row`/`.route-club-row`/`.notification-row`) และเปลี่ยน `<LoadingState />` เป็น skeleton ที่ตรงจุดใน `search-route.tsx` (4 จุด: Users/Clubs/Discovery + Drops tab ใช้ `FeedSkeleton` ที่มีอยู่แล้วเพราะ `DropPreviewCard` render เป็น full post card ไม่ใช่ grid ตามที่ design mockup เคยสมมติผิดไว้) และ `notifications-route.tsx` (1 จุด)
2. Press feedback — เพิ่ม `:active { transform: scale(0.96) }` (90ms, มี `prefers-reduced-motion` guard) ให้ `.route-person-main`, `.route-club-row`, `.notification-row` ใน `app/phase3.css`
3. Route transition — แก้ `components/ui/page-transition.tsx` จาก opacity fade 70ms เป็น slide(24px)+fade 220ms, easing `cubic-bezier(.22,.61,.36,1)`, ใช้ `useReducedMotion()` ของ framer-motion ยุบ slide เหลือ fade เฉยๆ เมื่อผู้ใช้เปิด reduced motion (ตาม Design Rules ข้อ "ตัดการเดินทาง ไม่ตัดสถานะ")

**Files Changed**: `web/components/ui/skeleton.tsx`, `web/app/skeleton.css`, `web/components/search-route.tsx`, `web/components/notifications-route.tsx`, `web/app/phase3.css`, `web/components/ui/page-transition.tsx`

**Reason**: ตาม design spec `.wyn/docs/design/wyn-175-perceived-speed-motion.md` และ Founder decision เลือก route transition Option B (2026-09-19)

**Tests**: ไม่มี automated test เดิมครอบคลุม loading state ของ Search/Notifications หรือ `PageTransition` — ไม่ได้เพิ่ม test ใหม่ในรอบนี้ (ไม่มี regression test framework สำหรับ visual/motion behavior ใน repo นี้ นอกจาก Playwright browser test ที่ไม่ได้รันในรอบนี้) เป็น **Known Issue** ที่ควรพิจารณาก่อน production

**Build**:
- `npm run lint` → ผ่าน (0 errors, 3 pre-existing warnings ที่ไม่เกี่ยวกับไฟล์ที่แก้)
- `npm run typecheck` → ผ่าน (0 errors)
- `npm run build` (Next.js production build) → สำเร็จ ทุก route compile ผ่านรวมถึง `/search` และ `/notifications`
- ยืนยันแล้วว่า error ที่เจอตอน typecheck รอบแรก (ก่อน `npm install`) เป็นเพราะ dependency ยังไม่ได้ติดตั้งในสภาพแวดล้อมนี้ ไม่เกี่ยวกับโค้ดที่แก้ — รัน `npm install` แล้วทุกอย่างผ่านสะอาด

**Known Issues**:
- **Post card / feed press feedback ยังไม่ทำ** — `GoldenDropCard` (ใช้ใน Home/Profile/Club feed และ Search Drops tab) มี interactive element ซ้อนกันหลายชั้น (avatar link, author link, more-menu button, like/comment/redrop actions ที่มี animation เฉพาะตัวอยู่แล้วเช่น double-tap burst) — เพิ่ม `:active` scale ที่ตัว `<article>` ทั้งใบจะทำให้การ์ดยุบตัวทุกครั้งที่กดปุ่มย่อยข้างในด้วย (เพราะ `:active` bubble ขึ้นมาตาม DOM ancestor) ซึ่งอาจขัดกับ animation ที่มีอยู่แล้ว — ตัดสินใจไม่แตะในรอบนี้ตามกติกา "smallest safe change" ต้องออกแบบแยกว่าจะใส่ press feedback เฉพาะพื้นที่ "เปิดดูโพสต์" หรือทั้งการ์ด แล้วส่งเป็น task ต่อยอด
- ยังไม่ได้ทดสอบบน physical iPhone Safari จริง (ตามบทเรียน WYN-158 ว่า CI เขียว/build ผ่าน ≠ ใช้งานได้จริงบนอุปกรณ์จริง) — QA/Founder ต้องยืนยันเพิ่ม

**Handoff**: → **AI QA & Security** ตรวจ: (1) skeleton ไม่ทำให้ layout shift ตอนข้อมูลจริงโหลดเสร็จ (2) press feedback ไม่ค้างสถานะ scale หลังปล่อยนิ้ว (3) route transition ทำงานถูกทั้งสองทิศทาง (ไปหน้าใหม่/กลับ) และ `prefers-reduced-motion` ลด slide ได้จริง (4) `aria-live`/`aria-label` ของ skeleton อ่านออกเสียงได้เหมาะสมกับ screen reader

## Debug Fix (AI Debug Engineer, 2026-09-19)

**Bug**: `.wyn/tasks/bugs/WYN-175-skeleton-row-height-cascade-mismatch.md` — `NotificationSkeleton` (76px vs. real 62px) และ hashtag row ใน `SearchDiscoverySkeleton` (44px vs. real 63px) ใช้ขนาดที่ copy มาจาก CSS rule แรกที่เจอ ไม่ใช่ rule ที่ชนะ cascade จริง

**Reproduction**: reproduce ซ้ำด้วย harness เดิมของ QA ก่อนแก้ — ได้ผล FAIL เดียวกันทุกประการ (76px/62px, 44px/63px) ยืนยัน root cause ตรงกับที่ QA ระบุโดยอ่าน source จริง (`app/pixel-parity-audit-closure.css:184-190`, `app/parity-completion.css:22`) ไม่ได้เชื่อ bug report เฉยๆ

**Fix**: แก้ `web/app/skeleton.css` เฉพาะ 2 selector (`.wyn-skeleton-notification-row`, `.wyn-skeleton-hashtag-row`) ให้ min-height/padding/gap/grid-template-columns ตรงกับ CSS rule ที่ชนะ cascade จริง (`pixel-parity-audit-closure.css`/`parity-completion.css`) แทนที่ base rule เดิมที่ถูก override — ไม่แตะไฟล์อื่น ไม่แตะ component ใน `skeleton.tsx`

**Verification**: rerun harness เดิม → 13/13 ผ่าน (จาก 11/13) — เพิ่ม regression test จริงเข้า repo: `web/components/dev/wyn-175-skeleton-fixture.tsx` + `web/app/dev/wyn-175-skeleton-fixture/page.tsx` (fixture route ตาม pattern `/dev/home-fixture` เดิม) + `web/tests/browser/wyn-175-skeleton-parity.spec.ts` (Playwright, ยืนยันรันผ่านจริงกับ dev server ก่อน commit ไม่ใช่แค่เขียนแล้วเชื่อว่าถูก — ระหว่างเขียนพบ bug เพิ่มอีก 2 จุดในตัว test เอง: comment `*/ ` ปิด JSDoc พลาดกลางคำ "parity-*/pixel-parity-*", และ Playwright strict-mode locator ชน element ซ้ำในหน้า Discovery ที่มี 3 hashtag row — แก้ทั้งสองจุดแล้วยืนยัน pass จริงก่อน commit) — `npm run lint`/`typecheck`/`build` ผ่านหมด (0 errors, warning เดิม 3 จุดไม่เกี่ยวข้อง)

**Files Changed**: `web/app/skeleton.css` (fix), `web/components/dev/wyn-175-skeleton-fixture.tsx`, `web/app/dev/wyn-175-skeleton-fixture/page.tsx`, `web/tests/browser/wyn-175-skeleton-parity.spec.ts` (regression test, ใหม่ทั้งหมด)

**Regression Risk**: ต่ำ — แก้แค่ CSS value ในไฟล์เดียว ไม่แตะ logic/data/auth บันทึกบทเรียนไว้ที่ `.wyn/learning/LESSONS_LEARNED.md` และ `.wyn/learning/MISTAKES.md` แล้ว (pattern "อ่าน CSS rule แรกที่เจอ ไม่ใช่ rule ที่ชนะ cascade" ในไฟล์ที่มี parity/pixel-parity override ซ้อนกันหลายชั้น)

**Handoff to QA**: → **AI QA & Security** ตรวจซ้ำตามที่ระบุไว้ใน Handoff เดิมทั้งหมด + ยืนยัน regression test ใหม่ทำงานถูกต้องใน CI (`.github/workflows/web-phase4-browser-qa.yml`/`web-next-phase5-preview.yml` รัน `npm run qa:browser` ซึ่งจะรวม spec ใหม่นี้โดยอัตโนมัติ)

## QA รอบ 2 (AI QA & Security, 2026-09-19)

**Test Cases**: รัน independent ใหม่ทั้งหมด ไม่เชื่อผลที่ AI Debug Engineer รายงานเอง — (1) harness เดิม 13 จุด (dimension parity 4 skeleton, shimmer, press feedback 3 จุดด้วย mouse down/up จริง, reduced-motion 2 จุด) (2) regression spec ใหม่ (`wyn-175-skeleton-parity.spec.ts` logic) 6 จุด ผ่าน raw Playwright script เพราะ `npx playwright test` ชน browser-version mismatch ในสภาพแวดล้อมนี้เอง (ไม่ใช่บั๊กของโค้ด — CI จริงมี `playwright install` ก่อนรันเสมอ) (3) e2e เพิ่มเติมรอบนี้: HTTP 200 + ไม่มี console/page error บน `/`, `/search`, `/notifications`, `/welcome`, `PageTransition` mount ไม่พัง, fixture route ใหม่ไม่ถูก link จากที่ไหนในแอป (4) `lint`/`typecheck`/`build` ใหม่ทั้งหมด

**Passed**: 13/13 (harness เดิม) + 6/6 (regression spec logic) + 10/10 (e2e เพิ่มเติม) = 29/29, lint 0 errors, typecheck 0 errors, build สำเร็จ

**Failed**: ไม่มี

**Severity**: N/A

**Security Findings**: ไม่มี — diff ทั้งหมดยังเป็น presentational layer, fixture route ใหม่ไม่มี real data/auth bypass (unauthenticated แต่ไม่มีข้อมูลจริงให้เข้าถึง เหมือน `/dev/home-fixture` เดิม)

**Known Issues ที่ไม่ block PASS** (ตรวจสอบแล้วว่าไม่ใช่ regression ของงานนี้):
- Physical iPhone Safari จริง — สภาพแวดล้อมนี้ไม่มีอุปกรณ์จริงให้ทดสอบ ยืนยันเองไม่ได้ (ตามบทเรียน WYN-158 "Production Verification คือใครยืนยัน") ต้องรอ Founder ยืนยันหลัง deploy จริง
- `GoldenDropCard` press feedback — ตั้งใจไม่ทำในรอบนี้ตามที่ AI Coding บันทึกไว้ (Known Issue เดิม) ไม่ใช่บั๊ก เป็น scope ที่ตัดออกอย่างมีเหตุผล

**Recommendation**: Approve — เข้า Deploy gate ปกติ (ต้องผ่าน Founder approval ก่อน production ตาม Release Gates) ระบุใน deployment record ให้ชัดว่า physical device verification ยังไม่เกิดขึ้น รอ Founder ยืนยันหลัง deploy

**Final Status: PASS**

ย้าย task ไป `.wyn/tasks/approved/` ส่งต่อ AI Deploy & DevOps

## Deploy (AI Deploy & DevOps, 2026-09-19)

PR #552 เปิดตามคำสั่ง Founder "เปิดเลย" → Founder merge เอง (`warren-wyn-dev`) ~44 วินาทีหลังเปิด → `WYN-158 Production Deploy` run #139 สำเร็จทุก step (preflight, Vercel deploy, verify production routes) → post-merge `CI` บน `main` เขียวด้วย รายละเอียดเต็ม: `.wyn/logs/deployments/2026-09-19-wyn-175-perceived-speed-motion-prep.md`

**ยังไม่ย้ายไป `completed/`** ตามกติกา WORKFLOW.md — ต้องรอ Founder ยืนยัน physical device (`wynos.online/search`, `/notifications` บนมือถือจริง) ก่อนถึงจะถือว่า production verification เสร็จสมบูรณ์
