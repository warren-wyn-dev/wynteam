# Product Task — WYN-174

Status: backlog
Owner: AI Product Manager
Feature: WYNOS Web Beta1 — Native App Feel รอบ 2 (ต่อยอดจาก WYN-158 "mobile app feel" และ WYN-163 visual redesign)
Goal: ให้ `wynos.online` (WYNOS Web Beta1) ให้ความรู้สึกเหมือนแอปมือถือจริงมากที่สุดเท่าที่เว็บทำได้ — ทั้งด้าน install/launch, gesture/touch, transition, perceived performance และ visual polish — โดยไม่เปลี่ยน business logic/backend contract เดิม
Target User: ผู้ใช้ WYNOS ทั่วไปที่เข้าเว็บผ่านมือถือ (iOS Safari/Android Chrome) เป็นหลัก รวมถึงผู้ที่ install เป็น PWA บน home screen
Problem: Founder ให้ทิศทางกว้างว่า "อยากพัฒนา web Beta1 ให้เหมือนแอปจริงที่สุด" — งานบางส่วนถูกทำไปแล้วใน WYN-158 (PR #468/#469: PWA manifest, service worker, swipe-back gesture, bottom nav, touch-target, tap-highlight/overscroll fix) และ WYN-163 (กำลัง iterate สี/ทรงปุ่มแนว Apple ink/paper อยู่ เฉพาะหน้า Auth) แต่ยังมีช่องว่างที่ทำให้เว็บรู้สึก "เป็นเว็บ" อยู่หลายจุด

## Current state (ตรวจโค้ดจริงแล้ว 2026-09-19)

ทำไปแล้ว:
- PWA installable: `web/app/manifest.ts` (standalone display, icons 192/512/maskable)
- Service worker: `web/public/sw.js` (cache static asset, web push ผ่าน FCM, notification click focus)
- iOS home-screen meta: `apple-mobile-web-app-capable`, status bar style (`web/app/layout.tsx`)
- Gesture: `web/components/swipe-back-gesture.tsx`, bottom navigation คงที่ (`bottom-navigation.tsx`)
- Interaction polish: `-webkit-tap-highlight-color: transparent` และ `overscroll-behavior: contain` กระจายอยู่หลายไฟล์ CSS, pull-to-refresh มีจริงใน home feed (`home-screen.tsx`)
- Visual redesign (WYN-163): กำลังทำอยู่ รอบ 7 แล้ว ขอบเขตปัจจุบัน = เฉพาะหน้า Auth/Onboarding เท่านั้น ยังไม่ finalize

ช่องว่างที่ยังไม่ทำ (ตรวจแล้วไม่พบในโค้ด):
1. **Route transition animation** — สลับหน้าในเว็บตอนนี้เป็น instant/snap ไม่มี slide/fade แบบแอป native
2. **Skeleton loading state** — ยังไม่ยืนยันว่าครอบคลุมทุกหน้า (เทียบกับ spinner/blank ที่ดู "เว็บ" มากกว่า)
3. **Custom install prompt UI** — ตอนนี้พึ่ง browser native prompt เท่านั้น ไม่มี banner "เพิ่ม WYNOS ที่หน้าจอหลัก" ของเราเอง
4. **iOS splash screen ตอนเปิดจาก home screen** — iOS ต้องการ static launch image แยกจาก manifest icon ยังไม่พบใน repo
5. **Visual redesign (WYN-163)** ยัง scope แค่ Auth ไม่ครอบคลุมทั้งระบบ (Home/Chat/Profile/Club ฯลฯ ยังเป็นดีไซน์เดิม)
6. **Safe-area inset (notch/home indicator)** — พบแค่บางจุดใน CSS ยังไม่ยืนยัน coverage ทั้งแอป
7. **Micro-interaction/press feedback** (scale-down เมื่อกดปุ่ม/การ์ด) — ยังไม่เห็นเป็น pattern มาตรฐานทั้งระบบ

## Requirements

แบ่งเป็น 4 sub-track ตาม priority (แต่ละ track = 1 WYN task แยกเมื่อเริ่มทำจริง):

- **P0 — Perceived Speed & Motion**: route/page transition animation, skeleton loading state มาตรฐานทั้งระบบ, micro-interaction press feedback
- **P0 — Visual Design Rollout**: รอ WYN-163 finalize แนว Apple ink/paper ก่อน แล้วขยาย scope จาก Auth ไปทั้งระบบ (Home/Chat/Profile/Club/Settings)
- **P1 — Install & Launch Experience**: custom install prompt banner, iOS splash screen images
- **P2 — Platform Integration Polish**: safe-area inset audit ทุกหน้า, ตรวจ pull-to-refresh/overscroll ให้ครบทุก scroll surface

## Acceptance Criteria

- ทุก sub-track ต้องมี Design spec + ภาพ mockup ให้ Founder อนุมัติก่อน AI Coding เริ่ม (ตามกติกาถาวร "UI ใหม่ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด")
- ห้ามเปลี่ยน business logic, Supabase contract (Auth/RLS/RPC/storage) หรือ feature ที่ใช้งานอยู่
- Feature ใหม่ที่ user-facing ต้อง gate ด้วย Staged Rollout (WYN-125) เป็นค่าเริ่มต้น ตาม WORKFLOW.md
- ต้องไม่กระทบ WYN-163 ที่กำลัง in-progress อยู่ (รอ finalize ก่อนขยาย scope)
- Regression: lint/typecheck/build ผ่านทุก batch, ทดสอบจริงบน iPhone Safari (physical device) ก่อนถือว่า done ตามบทเรียนของ WYN-158

## Dependencies

- WYN-163 (visual redesign แนว Apple) ต้อง finalize ก่อนเริ่ม "Visual Design Rollout" track
- WYN-158 mobile app feel work (PR #468/#469) เป็น foundation ที่ต่อยอด ไม่ใช่เริ่มใหม่

## Priority

P0 (Perceived Speed & Motion, Visual Design Rollout) → P1 (Install & Launch) → P2 (Platform Integration Polish)
รอ Founder ยืนยันลำดับก่อนส่งต่อ AI Design

## Risks

- Scope กว้างมาก ("เหมือนแอปจริงที่สุด" ไม่มีขอบเขตชัดในคำสั่งเดิม) — เสี่ยง scope creep ถ้าไม่ตัด sub-track ชัดเจน จึงแบ่งเป็น task ย่อยตาม priority แทนที่จะทำเป็นก้อนเดียว
- Route transition animation อาจกระทบ perceived performance ถ้าทำ animation หนักเกินไปบนมือถือรุ่นล่าง ต้อง budget ไว้ (<300ms, ใช้ CSS/transform ไม่ใช่ JS-heavy)
- Visual Design Rollout ชนกับ WYN-163 ที่ยัง in-progress — ต้องรอ finalize ก่อนไม่งั้นต้องทำซ้ำ

## Recommendation

เริ่มจาก **P0 — Perceived Speed & Motion** ก่อน เพราะเป็นสิ่งที่ทำให้ "รู้สึกเป็นเว็บ" ชัดที่สุดตอนนี้ (การสลับหน้าแบบ snap ทันที) และไม่ต้องรอ WYN-163 finalize ส่วน **Visual Design Rollout** ให้ต่อคิวหลัง WYN-163 เสร็จ

## Handoff

**[2026-09-19] Founder ยืนยันแล้ว**: เริ่ม Track 1 — Perceived Speed & Motion ก่อน (ตามคำแนะนำ) → แตกเป็น `WYN-175-web-perceived-speed-motion.md` ส่งต่อ AI Design ทำ audit + motion spec + preview ให้ Founder อนุมัติก่อน AI Coding เริ่ม

**[2026-09-19] Track 1 (WYN-175) เสร็จสมบูรณ์**: Design → Coding → QA (FAIL รอบ 1 → Debug fix → PASS รอบ 2) → Deploy (PR #552 merge, production deploy สำเร็จ) → Founder ยืนยัน production ใช้งานจริงแล้ว ย้ายไป `.wyn/tasks/completed/WYN-175-web-perceived-speed-motion.md`

Track อื่น (Visual Design Rollout — รอ WYN-163 finalize ก่อน / Install & Launch Experience / Platform Integration Polish) ยังอยู่ใน backlog รอคิวถัดไป ยังไม่มีคำสั่งให้เริ่ม

**[2026-09-20] Track 2 (Visual Design Rollout) เสร็จสมบูรณ์**: แตกเป็น `WYN-176-visual-design-rollout-squircle.md` — ทำครบ 6 batch (Home chrome → Composer → Chat → Profile/Settings → Search/Club → dead code cleanup) แต่ละ batch ผ่าน Design preview → Coding → QA (batch 4/5/6 มีรอบ fix/re-verify) → Deploy production สำเร็จครบ (PR #553/#554/#559/#561) Founder ยืนยัน production แล้วสำหรับ batch 1 ("ชอบผ่าน") ส่วน batch 2-6 deploy สำเร็จรอ Founder ยืนยัน physical device

Founder สั่ง "ทำต่อเลย" — เริ่ม **Track 3: Install & Launch Experience (P1)** ต่อไป (custom install prompt banner + iOS splash screen images)

**[2026-09-20] Track 3 (Install & Launch Experience) เสร็จสมบูรณ์**: แตกเป็น `WYN-181-install-launch-experience.md` — 2 sub-task (custom install prompt banner + iOS splash screen 32 ไฟล์) แต่ละ sub-task ผ่าน Design → Coding → QA (sub-task 1 มีรอบ fix/re-verify สำหรับบั๊ก iPad detection + accept-persistence) → Deploy production สำเร็จ (PR #562)

**[2026-09-20] Founder ยืนยัน "เสร็จแล้ว"** — ทดสอบจริงบน `wynos.online` ผ่านครบทั้ง Track 2 (WYN-176 ทุก batch 1-6) และ Track 3 (WYN-181 ทั้ง 2 sub-task) ย้ายทั้งสอง task ไป `.wyn/tasks/completed/` แล้ว เหลือ **Track 4: Platform Integration Polish (P2)** ใน backlog ยังไม่เริ่ม รอคำสั่ง Founder

Founder สั่ง "เริ่มเลย" — เริ่ม **Track 4: Platform Integration Polish (P2)** ต่อไป (safe-area inset audit + pull-to-refresh/overscroll audit ทั้งแอป) แตกเป็น `WYN-182-platform-integration-polish.md`

**[2026-09-20] Track 4 (Platform Integration Polish) เสร็จสมบูรณ์ — track สุดท้ายของ epic นี้**: Full audit (safe-area 3 gap, overscroll 7 gap, pull-to-refresh scoped ให้ 4 หน้า) → Founder อนุมัติ scope 3 ประเด็นผ่าน AskUserQuestion → Coding implement ครบ → QA PASS อิสระ 0 บั๊ก (regression 159/159) → Deploy production สำเร็จ (PR #570, run #157, CI #1438)

**Epic WYN-174 ครบทั้ง 4 track แล้ว** (Perceived Speed & Motion / Visual Design Rollout / Install & Launch Experience / Platform Integration Polish) ฝั่ง implementation/QA/deploy — WYN-182 รอ Founder ยืนยัน physical device ก่อนปิด epic นี้อย่างสมบูรณ์
