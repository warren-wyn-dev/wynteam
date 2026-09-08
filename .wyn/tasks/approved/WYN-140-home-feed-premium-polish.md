# Design Task — WYN-140

Status: approved (Phase 1 — QA PASS, CI ยืนยันจริง 1437/1437, รอ Founder สั่ง deploy)
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

**Phase 2 — ยังไม่เริ่มเขียนโค้ด**: ทั้ง swipe gesture ระหว่างแท็บ และ custom pull-to-refresh ต้องการรื้อ
สถาปัตยกรรมจริง (Phase 2's swipe ต้องแยก pagination state ของ forYou/following ออกจากกันเป็นราย mode แทนที่
จะใช้ state ก้อนเดียวสลับกันแบบตอนนี้ — กระทบเทสส่วนใหญ่ใน `home_feed_screen_test.dart`; custom pull-refresh
ต้องเขียนทดแทนกลไก `RefreshIndicator` ทั้งหมด ซึ่งความเสี่ยงขึ้นกับ API ที่มีจริงใน Flutter SDK เวอร์ชันที่
โปรเจกต์ pin ไว้ — sandbox นี้ไม่มี SDK ให้ตรวจสอบ) — **นี่ไม่ใช่ "รายละเอียด" แต่เป็นการรื้อสถาปัตยกรรมของ
หน้าที่ซับซ้อน/มีเทสมากที่สุดในแอป โดยไม่มี compiler ยืนยันเลย ขัดกับกติกาที่ Founder เขียนไว้เองในบรีฟ ("ห้าม
รื้อ Architecture โดยไม่จำเป็น") — หยุดรอคำตัดสินใจ Founder ก่อนเริ่ม ไม่ใช่ลุยเดาต่อ**

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

## รออะไรอยู่

Phase 1 พร้อม deploy แล้ว รอ Founder สั่ง — Phase 2 รอวางแผนเป็น task ใหม่ (AI Product Manager spec +
AI QA ร่วมคิดตั้งแต่ต้น) หลัง Phase 1 deploy เสถียร
