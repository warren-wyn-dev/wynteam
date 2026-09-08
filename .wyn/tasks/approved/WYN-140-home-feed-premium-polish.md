# Design Task — WYN-140

Status: approved (Phase 1 + Phase 2 swipe (rebuilt บน PageView จริง) — QA PASS ผ่าน CI 1443/1443, รอ deploy
  รอบใหม่แล้วรอ Founder ยืนยันของจริงบนแอปก่อนย้ายเข้า completed/ — ดู "รออะไรอยู่" ด้านล่าง)
Owner: AI Design
Screen: Home Feed (Header, Feed Tabs, Post Card, Action Bar, Media, Bottom Nav/Drop Button, Loading)
Purpose: ยกระดับ UX/UI ของหน้า Home ให้มีคุณภาพระดับ Production/Premium ตามบรีฟละเอียดของ Founder
  (2026-09-08) โดยล็อกโครงสร้างโพสต์เดิมของ WYN-107 ไว้ทั้งหมด — ปรับเฉพาะ spacing/typography rhythm/
  animation/interaction detail
User Flow: ไม่มี flow ใหม่ในภาพรวม — ปรับรายละเอียดของ flow เดิม (ดูแต่ละ Screen block ในเอกสารดีไซน์)
Components: Post Card (avatar/name/badge/time/caption/hashtag/media/action bar), Header, Feed Tabs,
  Action Metric, Media Frame, Bottom Nav, Drop Button, Home Feed Skeleton
Interactions: ดูรายละเอียดครบใน design doc — สรุปคือ animate tab indicator, press-scale Drop button,
  image fade-in, spacing rhythm ใหม่
States: ไม่เปลี่ยน state ที่มีอยู่แล้ว — เพิ่ม transition state ระหว่าง animate เท่านั้น
Responsive Behavior: ทดสอบ 320/375/390/430px ตามมาตรฐานเดิมของโปรเจกต์ — ไม่มี breakpoint ใหม่
Accessibility: ไม่ลด touch target/Semantics ที่มีอยู่แล้วแม้แต่จุดเดียว — ตรวจซ้ำหลังปรับ spacing
Design Rules: ใช้ token สี/spacing/motion เดิม 100% ไม่มี token ใหม่ — ดู 2 จุดที่บรีฟอ้างข้อมูลเก่ากว่าโค้ด
  จริง (สี Cyan เก่า vs Sapphire จริง, hashtag แยกบรรทัด vs inline จริง) ในเอกสารดีไซน์ก่อนเริ่ม implement
Handoff: แบ่ง Phase 1 (ปลอดภัย พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติภาพ) / Phase 2 (feed tab swipe,
  custom pull-to-refresh animation — ต้องอนุมัติ scope เพิ่มแยกต่างหาก เพราะเป็นฟีเจอร์ใหม่ไม่ใช่รายละเอียด)
  — ดูตารางเต็มใน `.wyn/docs/design/wyn-140-home-feed-premium-polish.md`

## เอกสารเต็ม

`.wyn/docs/design/wyn-140-home-feed-premium-polish.md`

## สถานะ implement (อัปเดต 2026-09-08, หลัง Founder สั่ง "เริ่มทำได้เลย")

**Phase 1 — เขียนโค้ดเสร็จแล้ว push ขึ้น branch แล้ว (commit `c7eafe1`)**: spacing 3 จุดใน
HomeDropCard/HomePopCard, label "Club", motion token บน tab indicator (220ms/DS-010, ไม่ใช่ sliding ข้าม
ตำแหน่งแบบที่มอคอัพ HTML โชว์ — ดูเหตุผลด้านล่าง), haptic บนปุ่ม Drop, HomeFeedSkeleton ปรับ 2 คอลัมน์ตรงกับ
การ์ดจริง, PostImage fade-in ตอนโหลดเสร็จ — **sandbox นี้ไม่มี Flutter SDK ติดตั้ง ตรวจสอบด้วยการอ่านโค้ด+
เทียบกับทุก test ที่อ้างถึงไฟล์ที่แก้ ไม่ใช่การรัน `flutter analyze`/`flutter test` จริง — ต้องรอ CI ยืนยัน**

**จุดที่ตัดสินใจไม่ทำตามมอคอัพ HTML เป๊ะ**: indicator ที่ "เลื่อนข้ามตำแหน่งจริง" (แบบที่มอคอัพ interactive
โชว์) ต้องรื้อโครงสร้าง toggle เดิมเป็น Stack + GlobalKey + วัด RenderBox แทนของเดิม — widget นี้ผ่านการแก้
overflow/wrapping มาแล้ว 4 รอบ (ประวัติอยู่ใน `home_feed_screen_test.dart`) เป็นจุดที่เปราะบางที่สุดจุดหนึ่งใน
แอป การรื้อโครงสร้างแบบนี้โดยไม่มี compiler/test runner ยืนยันคือความเสี่ยงจริงที่ไม่คุ้ม จึงทำแค่ปรับ
duration/curve ให้เป็น token เดิม (220ms, เคารพ reduced-motion) แทน — ยังคง "ไม่กระโดด" ตามที่บรีฟขอ แค่ไม่ใช่
กลไก sliding ข้ามตำแหน่งแบบมอคอัพ

**Phase 2 — Founder ยอมรับความเสี่ยงแล้ว ("ยอมรับความเสี่ยง — ให้ลุย Phase 2 ต่อเลย") เขียนโค้ดเสร็จแล้ว
push ขึ้น branch แล้ว (commit `52b6aac` + fix `3eb8dcb`)**: implement เฉพาะ swipe gesture ระหว่างแท็บ ด้วย
วิธีตัด scope ลง — ไม่รื้อสถาปัตยกรรม pagination เดิมตามที่ประเมินไว้ครั้งแรก แต่ใช้
`GestureDetector.onHorizontalDragEnd` ครอบ `CustomScrollView` เดิม เรียก `_selectFeedMode()` (แยกจาก logic
เดิมของแท็บ) ตัวเดียวกับที่แท็บใช้อยู่ ไม่แตะ `_items`/`_page`/pagination state เลย — เทส interactive ~30 ตัว
เดิม (Like/Save/ReDrop/Poll/Hide/Undo) จึงไม่กระทบ, velocity-gated ที่ 200px/s กันลากช้าๆ ไม่ให้สลับแท็บผิด
เจตนา **custom pull-to-refresh เต็มรูปแบบ — ตัดสินใจไม่ทำ**: `RefreshIndicator` ใช้สี Sapphire ถูกต้องอยู่แล้ว
โดยไม่ต้องแก้โค้ด ส่วนการรื้อกลไกทั้งหมดเพื่อทำ animation แบรนด์เองมีความเสี่ยงไม่คุ้ม (ดูเหตุผลเต็มใน
DECISIONS.md) — นี่คือ scope ที่ตัดออกโดยเปิดเผย ไม่ใช่งานค้าง

**QA Phase 2 — PASS ผ่าน CI จริง**: รอบแรก (run #328) พบ 5 เทสใหม่ล้มเหลวจาก `tester.drag()` ไม่จำลอง
velocity พอ + timer รั่วจาก repository fixture ที่สร้างผิด pattern — แก้แล้ว push commit `3eb8dcb` รอบสอง
(run [#329](https://github.com/warren-wyn-dev/wynteam/actions/runs/34197650825)) **`flutter analyze`: 0
issues, `flutter test`: 1442/1442 ผ่านทั้งหมด** พร้อมเข้าสู่ขั้น deploy

## สถานะคำถาม (อัปเดต 2026-09-08)

1. ✅ Founder ดู Artifact mockup Before/After แล้ว
2. ✅ สี: **Sapphire** (ของจริง) — ไม่ใช้ Cyan ตามบรีฟ
3. ✅ Hashtag: **inline** (ของจริง) — ไม่แยกบรรทัด
4. ✅ Drop button haptic: **เพิ่ม** — แก้ไข DS-010 §3 แล้ว (`ds-010-interaction-feedback.md`,
   `.wyn/company/DECISIONS.md` entry 2026-09-08)
5. ⏳ **Phase 1 vs Phase 1+2**: Founder ขอดูตัวอย่างแบบโต้ตอบได้จริงก่อน (มอคอัพภาพนิ่งโชว์ animation
   ไม่ได้) — ส่ง Artifact แบบกดเล่นได้จริงแล้ว (indicator เลื่อน/ปุ่ม Drop กด+haptic ring/รูป fade-in)
   รอ Founder ดูแล้วตัดสินใจ

## QA — PASS (2026-09-08)

**Environment จริง ไม่ใช่แค่อ่านโค้ด**: trigger `ci.yml` ตรงผ่าน `workflow_dispatch` บน branch นี้เอง (run
[#323](https://github.com/warren-wyn-dev/wynteam/actions/runs/34193968155), Flutter 3.47.1) เพราะ
sandbox ของทั้ง Coding และ QA session นี้ไม่มี Flutter SDK ติดตั้งเลย — **`flutter analyze` สะอาด 0 issues,
`flutter test` ผ่าน 1437/1437** (รวม label "Club" ที่เปลี่ยนในเทสแล้ว, `active_segment_accent` key,
HomeFeedSkeleton, PostImage ทุกจุด)

**พบ 2 ข้อสังเกตเล็กน้อย ไม่ block**: (1) คอมเมนต์ 2 จุดใน `home_feed_screen_test.dart` ล้าสมัยหลัง rename
label (บรรยาย "Club" ว่ายาว 15 ตัวอักษร/เป็น label ที่กว้างที่สุด ซึ่งไม่จริงแล้ว) — ไม่กระทบการทำงานของเทส
เก็บไว้แก้ทีหลัง (2) Drop ที่มีรูปแต่ไม่มี caption ยังมีช่องว่าง 0px ระหว่างเวลากับรูป — เป็นของเดิมก่อน
WYN-140 ไม่ใช่ regression จากรอบนี้ ไม่อยู่ใน scope ที่อนุมัติ

**Final Status: PASS** — ย้ายเข้า `approved/` แล้ว รายละเอียดเต็มอยู่ในแชท session นี้

## Deploy — Phase 2 (2026-09-08)

PR #315 merge เข้า `main` (squash, commit `b7cf7a6`) → `deploy-web.yml` run
[#107](https://github.com/warren-wyn-dev/wynteam/actions/runs/34198710747) SUCCESS →
`curl https://wynos.online/` ยืนยัน HTTP 200, last-modified ตรงกับเวลา deploy จริง — รายละเอียดเต็มอยู่ใน
`.wyn/logs/deployments/2026-09-08-wyn-140-home-feed-premium-polish-phase2-deploy.md`

**ยังไม่ทำ**: custom pull-to-refresh animation เต็มรูปแบบ — ตัดออกโดยเปิดเผยแล้ว (เหตุผลใน DECISIONS.md)
ไม่ใช่งานค้าง

## Phase 2 follow-up: รื้อเป็น PageView จริง (2026-09-08)

Founder ลองบน production แล้วบอก "ไม่ค่อยลื่น" → เพิ่ม rubber-band cue (deploy แล้ว) → Founder ขอต่อ "อยากให้
Swipe หลายๆหน้า เหมือนแพตฟอมใหญ่ๆ" → ยืนยันรับความเสี่ยงรื้อสถาปัตยกรรมจริงเป็นครั้งที่ 2 (เจาะจงกว่ารอบแรก) →
ดึง logic ของ "สำหรับคุณ"/"ติดตาม" ออกเป็น widget ใหม่ `ModeFeedPage` (รูปแบบเดียวกับ `FromYourClubsFeed` เดิม)
โฮสต์ทั้ง 3 โหมดใน `PageView.builder` จริง แต่ละแท็บมี state/scroll position เป็นของตัวเอง (ดีขึ้นกว่าเดิมที่
reload ทุกครั้งที่สลับ) — QA PASS ผ่าน CI จริงหลังแก้ 3 รอบ (lint, timer รั่วจาก repository fixture, timer รั่ว
จาก DoubleTapLike) **`flutter analyze` 0 issues, `flutter test` 1443/1443** (run
[#339](https://github.com/warren-wyn-dev/wynteam/actions/runs/34203396687)) — รายละเอียดเต็มใน
DECISIONS.md — พร้อม deploy รอบใหม่ทับ deploy เดิม

## รออะไรอยู่

Deploy ขึ้น production รอบแรก (rubber-band) แล้ว — รอบนี้ (PageView จริง) QA PASS แล้ว รอ deploy รอบใหม่ — หลัง
deploy แล้ว รอ Founder เปิดแอปจริงยืนยัน 2 เรื่อง:
1. Phase 1: ความรู้สึกของ haptic ตอนกดปุ่ม Drop (เว็บพรีวิวบนคอมพิวเตอร์ไม่มีแรงสั่นให้ลองจริง)
2. Phase 2: ความรู้สึกของ swipe ระหว่างแท็บแบบ PageView จริง — ลื่นสมจริงแค่ไหน ชนกับการเลื่อนรูปหลายรูป
   (carousel) หรือ back-gesture ของเบราว์เซอร์/ระบบไหม — นี่คือความเสี่ยงที่ Founder ยอมรับไว้แล้วตั้งแต่ต้นว่า
   CI ตอบให้ไม่ได้ ต้องลองจริง

หลังยืนยันครบทั้ง 2 เรื่อง ย้าย task เข้า `completed/`
