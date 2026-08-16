# Founder Decisions Log

เอกสารนี้บันทึกการตัดสินใจถาวรของ Founder เมื่อ Founder ให้ feedback ในลักษณะ เช่น "จำไว้", "ต่อไปให้ทำแบบนี้", "ไม่เอาแบบนี้", "เปลี่ยนวิธีทำ", "อยากให้ WYN เป็นแบบนี้" ทีม AI ต้องบันทึกไว้ที่นี่ทันทีและห้าม override โดยไม่แจ้ง Founder

## รูปแบบการบันทึก

```
### [YYYY-MM-DD] หัวข้อการตัดสินใจ
- บริบท:
- คำตัดสินใจของ Founder:
- ผลกระทบ:
- อ้างอิง (task/PR ถ้ามี):
```

## รายการการตัดสินใจ

### [2026-08-13] WYN Core Product & Target Users
- บริบท: Founder ตอบคำถามเริ่มต้นผ่านคำสั่ง `/product` เพื่อเริ่มกำหนด WYN Vision และ Tech Stack
- คำตัดสินใจของ Founder:
  - Core Product: โซเชียลมีเดียทั่วไป (general social media platform)
  - Target Users: วัยรุ่น / Gen Z
  - Platform และ Tech Stack: มอบหมายให้ AI Product Manager เสนอคำแนะนำ แล้วรอ Founder อนุมัติ
- ผลกระทบ: ใช้เป็นฐานในการร่าง Vision/Mission และคำแนะนำ Platform/Tech Stack ใน WYN-001 อัปเดตใน `.wyn/company/CONTEXT.md`
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/active/WYN-001-vision-and-tech-stack.md`

### [2026-08-13] WYN Vision/Mission และ Platform/Tech Stack — อนุมัติแล้ว
- บริบท: Founder ตอบ "ยืนยัน" ต่อร่าง Vision/Mission และคำแนะนำ Platform/Tech Stack ที่ AI Product Manager เสนอใน WYN-001
- คำตัดสินใจของ Founder:
  - อนุมัติถ้อยคำ Vision และ Mission ตามร่างทั้งหมด (ไม่มีแก้ไข)
  - อนุมัติ Platform: Mobile-first — React Native (Expo) + TypeScript
  - อนุมัติ Backend: Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions)
- ผลกระทบ: `.wyn/company/CONTEXT.md` อัปเดตเป็นค่าสุดท้ายแล้ว WYN-001 เสร็จสมบูรณ์ AI Design และ AI Coding ใช้ข้อมูลนี้เป็นฐานอ้างอิงได้ทันที การเปลี่ยน Platform/Tech Stack ในอนาคตต้องขออนุมัติใหม่ (Major Architecture)
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/completed/WYN-001-vision-and-tech-stack.md`

### [2026-08-13] เปลี่ยน Frontend Framework เป็น Flutter (Dart)
- บริบท: หลัง WYN-001 อนุมัติ React Native/Expo ไปแล้ว Founder แจ้งตรงว่า "โค้ดที่ใช้เขียนแอป ภาษา Dart กับ Flutter"
- คำตัดสินใจของ Founder: ใช้ **Flutter (ภาษา Dart)** เป็น mobile framework หลักของ WYN แทนที่ React Native (Expo) + TypeScript ที่เคยอนุมัติไว้
- ผลกระทบ:
  - `.wyn/company/CONTEXT.md` (Technology Stack, Architecture) อัปเดตเป็น Flutter/Dart แล้ว
  - Backend ยังคงเป็น Supabase เหมือนเดิม (มี `supabase_flutter` package รองรับ Flutter โดยตรง ไม่กระทบ)
  - AI Coding ต้องใช้ Dart/Flutter convention (ตัวแปร, class, widget เป็นภาษาอังกฤษตาม `AGENTS.md`) เมื่อเริ่ม implement
  - `.wyn/company/APPROVALS.md` รายการเดิมถูกทำเครื่องหมายว่าส่วน frontend ถูกแทนที่แล้ว (audit trail ยังคงไว้ ไม่ลบของเดิม)
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/completed/WYN-001-vision-and-tech-stack.md`, `.wyn/company/APPROVALS.md`

### [2026-08-13] วิธีการถามคำถาม Founder ต้องใช้ Popup พร้อมตัวเลือกคำตอบ
- บริบท: Founder แจ้งว่า "เวลาจะถามคำถามอะไรให้ตอบ เด้งเป็นหน้าป็อบอัพ พร้อมคำตอบด้วย" และยืนยันให้บันทึกเป็นกติกาถาวร
- คำตัดสินใจของ Founder: ทุกครั้งที่ AI role ต้องถามคำถาม/ขอการตัดสินใจ/ขออนุมัติจาก Founder ให้ใช้ popup แบบเลือกคำตอบเป็นค่าเริ่มต้น แทนการพิมพ์ถามเป็นข้อความเปล่า ๆ ยกเว้นคำถามเชิงบรรยายที่ใส่เป็นตัวเลือกไม่ได้ตามธรรมชาติ
- ผลกระทบ: บันทึกกติกาไว้ที่ `.wyn/company/RULES.md` (หัวข้อ "วิธีการถามคำถาม Founder") ทุก AI role ต้องปฏิบัติตามตั้งแต่นี้ไป
- อ้างอิง (task/PR ถ้ามี): `.wyn/company/RULES.md`

### [2026-08-13] Authentication Methods สำหรับ WYN V0.1
- บริบท: AI Product Manager เริ่ม WYN-002 (Authentication & Onboarding) และเสนอวิธียืนยันตัวตนให้ Founder อนุมัติผ่าน popup
- คำตัดสินใจของ Founder: อนุมัติให้ WYN V0.1 รองรับ **Social Login (Google + Apple) และ Phone Number + OTP** เท่านั้น ไม่มี Email + Password
- ผลกระทบ: กำหนดเป็น requirement ใน `.wyn/tasks/backlog/WYN-002-authentication-onboarding.md` และเป็นฐานให้ AI Design/AI Coding ใช้อ้างอิงเมื่อเริ่มงาน การเปลี่ยนแปลง authentication architecture ในอนาคตต้องขออนุมัติใหม่
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/backlog/WYN-002-authentication-onboarding.md`

### [2026-08-13] Deployment Target สำหรับ WYN V0.1 — Internal Testing
- บริบท: WYN-002 ผ่าน QA รอบ 3 (PASS) แล้ว AI Deploy & DevOps ถามผ่าน popup ว่าควร deploy ไปที่ไหนเป็นอันดับแรก
- คำตัดสินใจของ Founder: เลือก **Internal Testing** (ทีมภายในเท่านั้น) — TestFlight (iOS) + Firebase App Distribution หรือ Google Play Internal Testing Track (Android) ไม่ใช่ public store release ในตอนนี้
- ผลกระทบ: `.wyn/tasks/approved/WYN-002-authentication-onboarding.md` และ `.wyn/logs/deployments/2026-08-13-wyn-002-readiness.md` ใช้เป้าหมายนี้เป็นฐานวางแผน deployment การเปลี่ยนเป็น public release ในอนาคตต้องขออนุมัติใหม่
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/approved/WYN-002-authentication-onboarding.md`

### [2026-08-13] Feature ถัดไปคือ User Profile — ขอบเขต Display Name + Bio + Avatar
- บริบท: หลัง WYN-002 ผ่าน QA, AI Product Manager ถาม Founder ผ่าน popup ว่า feature ถัดไปควรเป็นอะไร
- คำตัดสินใจของ Founder: เลือก **User Profile** เป็น feature ถัดไป (WYN-003) และเลือกให้มีครบทั้ง 3 อย่างตั้งแต่รอบแรก: ชื่อแสดง (Display Name), Bio, และรูปโปรไฟล์ (Avatar upload) — ไม่แบ่งเป็นเฟสย่อย
- ผลกระทบ: กำหนดเป็น requirement ใน `.wyn/tasks/backlog/WYN-003-user-profile.md` ต้องเพิ่ม Supabase Storage bucket สำหรับ avatar และขยาย `profiles` table
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/backlog/WYN-003-user-profile.md`

### [2026-08-13] ต้องส่ง Push Notification ทุกครั้งที่ถามคำถาม Founder
- บริบท: Founder ถามว่าเวลาถามคำถามหรือให้ Founder ตอบอะไร มีเสียงแจ้งเตือนได้ไหม — ทดลองส่ง push notification ให้ดูแล้ว Founder ยืนยันให้บันทึกเป็นกติกาถาวร
- คำตัดสินใจของ Founder: ทุกครั้งที่ AI role ถามคำถามหรือรอคำตอบ/การตัดสินใจจาก Founder ให้ส่ง push notification แจ้งเตือนไปด้วยเสมอ (นอกเหนือจาก popup ที่มีอยู่แล้ว)
- ผลกระทบ: บันทึกกติกาไว้ที่ `.wyn/company/RULES.md` (หัวข้อ "วิธีการถามคำถาม Founder") และ `AGENTS.md` ทุก AI role ต้องปฏิบัติตามตั้งแต่นี้ไป
- อ้างอิง (task/PR ถ้ามี): `.wyn/company/RULES.md`

### [2026-08-13] Feature ถัดไปคือ Feed & Post — ขอบเขต Global Feed + ข้อความ/รูป + Like + Comment + ลบโพสต์
- บริบท: หลัง WYN-002/WYN-003 ผ่าน QA, AI Product Manager ถาม Founder ผ่าน popup ว่า feature ถัดไปควรเป็นอะไร
- คำตัดสินใจของ Founder: เลือก **Feed & Post** เป็น feature ถัดไป (WYN-004) พร้อมขอบเขตครบตั้งแต่รอบแรก:
  - Post เนื้อหา: ข้อความ + รูปภาพ
  - Feed: Global Feed (เห็นโพสต์ทุกคน เพราะยังไม่มีระบบ Follow)
  - Interactions: มีทั้ง Like และ Comment
  - ผู้ใช้ลบโพสต์ของตัวเองได้
- ผลกระทบ: กำหนดเป็น requirement ใน `.wyn/tasks/backlog/WYN-004-feed-and-post.md` ต้องสร้างตาราง `posts`/`likes`/`comments` ใหม่ พร้อม Storage bucket สำหรับรูปโพสต์ และเปลี่ยน `HomeScreen` จาก placeholder เป็น Feed จริง
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/backlog/WYN-004-feed-and-post.md`

### [2026-08-14] แทนที่ Product Structure เดิมทั้งหมดด้วย "WYN V0.1 — CORE APP FEATURE PROMPT" (Home / Drop / Pop / Profile)
- บริบท: Founder ส่ง spec ใหม่ทั้งฉบับ ("WYN V0.1 — CORE APP FEATURE PROMPT") ที่นิยาม WYN V0.1 ใหม่ทั้งหมดเป็น Bottom Navigation 4 เมนู: Home (Search + Feed รวม Drop/Pop), Drop (โพสต์รูปภาพ ระบบแยกต่างหาก), Pop (โพสต์คลิปสั้นแนวตั้งแบบ TikTok), Profile — พร้อมระบบ Social เต็มรูปแบบ (Like, Comment, Share, Save, Follow, Notification, Search) ต่างจากขอบเขตที่สร้างไปแล้วมาก: WYN-004 (Feed & Post) ที่เพิ่งพัฒนาเสร็จเป็น **Feed เดียวรวมโพสต์ข้อความ+รูปภาพ** ไม่ได้แยก Drop/Pop เป็นคนละแท็บ และยังไม่มี Share/Save/Follow/Notification/Search เลย ถามยืนยันผ่าน popup ว่าจะทำอย่างไรกับของเดิม
- คำตัดสินใจของ Founder: **แทนที่ทิศทาง Product เดิมทั้งหมด** ด้วย spec ใหม่นี้ — เริ่ม `/product` ใหม่ตาม "WYN V0.1 — CORE APP FEATURE PROMPT" ตั้งแต่ต้น (ไม่ใช่แค่เพิ่มเป็น roadmap ระยะยาวที่ยังไม่ทำ) ขอบเขต V0.1 ใหม่ตามที่ Founder ระบุคือ: Login/Register/Home/Search/Drop/Create Drop/Upload Image/Pop/Create Pop/Upload Video/Profile/Like/Comment/Share/Save/Follow/Notifications เท่านั้น — ห้ามทำ Shop/ZOKY/Payment/Cart/Order/Live/AI/Creator Monetization/Ads/Advanced Recommendation Algorithm จนกว่าจะได้รับคำสั่งใหม่ Color Direction: Blue + White + Soft Gray, ไม่ใช้ Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok โดยตรง
- ผลกระทบ: WYN-002 (Auth) และ WYN-003 (Profile) ยังใช้ได้เป็นฐานอยู่ (ตรงกับ Register/Login/Logout/Edit Profile ใน spec ใหม่) แต่ WYN-004 (Feed & Post) ที่เพิ่งผ่าน Coding+Debug และรอ QA รอบ 2 อยู่ **จะถูกแทนที่/แยกออกเป็น Drop กับ Pop** ตาม spec ใหม่ — ต้องรัน `/product` ใหม่เพื่อวาง roadmap V0.1 ใหม่ทั้งหมดก่อนเริ่ม Design/Coding ของ Drop/Pop/Search/Notification/Follow/Share/Save งานที่ค้างอยู่ (QA รอบ 2 ของ WYN-004 debug fix) จะทำให้เสร็จตามที่ Founder สั่งไว้ก่อน (Merge PR #23 + QA รอบ 2) เพื่อปิด loop เดิมให้เรียบร้อยก่อนเปลี่ยนทิศทาง
- อ้างอิง (task/PR ถ้ามี): PR #21-23 (WYN-004), จะสร้าง `.wyn/tasks/backlog/` ใหม่สำหรับ Drop/Pop/Search/Notification/Follow/Share/Save หลัง `/product` รอบใหม่เสร็จ

### [2026-08-14] ขอบเขต WYN-005 (Drop) รอบแรก และกติกาที่ใช้ร่วมทั้ง roadmap V0.1 ใหม่
- บริบท: AI Product Manager วาง roadmap ใหม่ (`.wyn/docs/product/wyn-v0.1-roadmap.md`) และ spec ของ WYN-005 (Drop) แล้วถามยืนยัน 4 คำถามผ่าน popup ก่อนส่งต่อ AI Design
- คำตัดสินใจของ Founder (ทั้งหมดตามที่แนะนำ):
  1. เริ่มพัฒนาที่ **WYN-005 (Drop)** ก่อนฟีเจอร์อื่นทั้งหมดใน roadmap ใหม่
  2. **Hashtag/Mention ใน WYN-005 รอบแรก**: ทำแค่ "พิมพ์ในแคปชันได้ ระบบจำ/บันทึกได้" เท่านั้น ส่วนการแตะ hashtag/mention แล้วไปหน้าค้นหา/โปรไฟล์ ทำทีหลังผูกกับ WYN-009 (Search) ไม่ทำใน WYN-005
  3. **Follow ใช้ได้กับทั้ง Drop และ Pop** (ไม่ใช่แค่ Pop ตามที่ spec เดิมระบุไว้ไม่ชัด) — ระบบ Follow เดียว (WYN-008) ใช้ร่วมกันทั้งแอป
  4. **Home Feed (WYN-007) เป็น Global ก่อน** (เห็นโพสต์ของทุกคน เหมือน WYN-004 เดิม) ยังไม่กรองตาม Follow จนกว่าจะมีการตัดสินใจเพิ่มเติมในอนาคต
- ผลกระทบ: อัปเดตขอบเขตใน `.wyn/tasks/backlog/WYN-005-drop-post-image.md` และ `.wyn/docs/product/wyn-v0.1-roadmap.md` ให้ตรงกับคำตัดสินใจนี้ แล้วส่งต่อ AI Design (`/design`) เพื่อออกแบบหน้าจอของ WYN-005
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/backlog/WYN-005-drop-post-image.md`, `.wyn/docs/product/wyn-v0.1-roadmap.md`

### [2026-08-14] อนุญาตให้ทีม AI ทำงานต่อเนื่องอัตโนมัติตาม roadmap โดยไม่ต้องหยุดถามทีละ task
- บริบท: Founder จะเข้านอน ขอให้ทีม AI ทำงานต่อเนื่องได้เองโดยไม่ต้องรอถามทุกขั้นตอน ถามยืนยันขอบเขตผ่าน popup ก่อนว่าจะทำแค่ WYN-005 ให้เสร็จแล้วหยุด หรือทำต่อเนื่องทั้ง roadmap
- คำตัดสินใจของ Founder: **ทำงานต่อเนื่องตาม roadmap ทั้งหมดโดยอัตโนมัติ** — เริ่มจาก merge PR #28 → QA WYN-005 → เข้า Debug ถ้า FAIL จนกว่าจะ PASS → ต่อด้วย WYN-006 (Pop) และ task ถัดไปตามลำดับใน `.wyn/docs/product/wyn-v0.1-roadmap.md` โดยไม่ต้องหยุดขอ AskUserQuestion ทีละขั้นตอนอีก **จนกว่า Founder จะกลับมา**
- ผลกระทบ: กติกาถาวรอื่น ๆ ยังใช้อยู่เหมือนเดิม (ห้าม force-push ที่เป็นอันตราย, ห้ามเปลี่ยน Major Architecture/Vision/Security โดยไม่ขออนุมัติ, ต้องบันทึกทุกอย่างลง PR/DECISIONS.md/CONTEXT.md ให้ตรวจย้อนหลังได้) — สิ่งที่เปลี่ยนคือ **ไม่ต้องรอ Founder ตอบ popup ก่อน merge PR/เริ่ม task ถัดไปในช่วงนี้** จนกว่าจะมีคำสั่งเปลี่ยนแปลงจาก Founder หรือเจอสถานการณ์ที่ต้องขออนุมัติตาม RULES.md จริง ๆ (เช่น ต้องเปลี่ยน Vision/Business Model/Security Architecture) ซึ่งกรณีนั้นยังต้องหยุดรอ Founder เหมือนเดิม
- อ้างอิง (task/PR ถ้ามี): PR #28 เป็นต้นไป

### [2026-08-14] ชะตากรรมของโค้ด/สคีมา WYN-004 เดิม เมื่อเริ่ม WYN-007 (Home)
- บริบท: WYN-005 (Drop) และ WYN-006 (Pop) ผ่าน QA แล้ว ทำให้ Home (WYN-007) เริ่มได้ ต้องตัดสินใจว่าจะทำอย่างไรกับโค้ด/ตาราง WYN-004 (`FeedScreen`/`PostRepository`/`PostCard`, ตาราง `posts`/`likes`/`comments`) ที่ไม่มี route ใดชี้ไปแล้วตั้งแต่ WYN-005 แทนที่ด้วย `RootShell` — เรื่องนี้ค้างมาตั้งแต่ WYN-005 Coding Output ที่ระบุว่า "รอ Founder/Product ตัดสินใจ"
- คำตัดสินใจของ AI Product Manager (ทำเองได้ตามอำนาจที่ RULES.md ให้ไว้ ไม่ใช่ Major Architecture change): แยกเป็น 2 ส่วน —
  1. **ลบโค้ด Dart ทิ้ง** (`app/lib/features/feed/` ทั้งโฟลเดอร์ + test ที่เกี่ยวข้อง) มอบหมายให้ AI Coding ทำระหว่าง implement WYN-007 — เหตุผล: ไม่มี client ไหนอ้างอิงแล้ว, Home ใหม่ query `drops`/`pops` ตรง ๆ ไม่ใช้ `posts` เดิม, git history เก็บโค้ดเดิมไว้ครบถ้าต้องอ้างอิงย้อนหลัง
  2. **ไม่ลบตาราง `posts`/`likes`/`comments` ออกจาก schema เอง** เพราะเป็น "โครงสร้างฐานข้อมูลแบบทำลายล้าง" ที่ต้องขออนุมัติ Founder ก่อนเสมอตาม RULES.md — บันทึกคำขออนุมัติไว้ที่ `.wyn/company/APPROVALS.md` (สถานะ: รออนุมัติ) แทน ไม่ดำเนินการเองจนกว่า Founder จะตอบ
- ผลกระทบ: `app/lib/features/feed/` จะถูกลบใน PR ของ WYN-007 Coding แต่ `supabase/schema.sql` ยังคงตาราง WYN-004 ไว้เหมือนเดิมจนกว่าจะมีคำตอบจาก Founder ที่ `.wyn/company/APPROVALS.md`
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/backlog/WYN-007-home-feed.md`, `.wyn/company/APPROVALS.md`

### [2026-08-14] ต้องรายงานความคืบหน้างานเป็นเปอร์เซ็นต์เป็นระยะ
- บริบท: Founder ขอให้ระบบแจ้งความคืบหน้าของงานที่มอบหมายไปเป็นระยะ พร้อมบอกเป็นเปอร์เซ็นต์ ไม่ใช่รอจนงานเสร็จสมบูรณ์ค่อยแจ้งทีเดียว
- คำตัดสินใจของ Founder: ทุก AI role ต้องรายงานความคืบหน้าเป็นเปอร์เซ็นต์เมื่อเสร็จ milestone ย่อยที่มีความหมาย (เช่น Product spec เสร็จ, Design เสร็จ, Coding เสร็จ, QA ผ่าน/ไม่ผ่าน) ไม่ใช่แค่ตอนเริ่มกับตอนจบงานทั้งก้อน
- ผลกระทบ: บันทึกกติกาไว้ที่ `.wyn/company/RULES.md` (หัวข้อ "การรายงานความคืบหน้างาน") ทุก AI role ต้องปฏิบัติตามตั้งแต่นี้ไป
- อ้างอิง (task/PR ถ้ามี): `.wyn/company/RULES.md`

### [2026-08-14] ระงับการพัฒนาฟีเจอร์ Pop (คลิปสั้น) ไว้ก่อน — ไม่ใช่การยกเลิก
- บริบท: Founder แจ้งให้ระงับการพัฒนาฟีเจอร์ Pop (WYN-006 และงานต่อยอดที่เกี่ยวข้อง) ไว้ก่อน เพื่อหันไปทำ WYN CLUB (ฟีเจอร์ Community/กลุ่ม) แทน
- คำตัดสินใจของ Founder: **ระงับ (suspend) ไม่ใช่ยกเลิก (cancel)** — Pop ที่มีอยู่แล้ว (WYN-006, ผ่าน QA แล้ว) **ยังคงอยู่ในแอปตามปกติ** ไม่ต้องถอดออกจาก Bottom Navigation หรือปิดการใช้งาน สิ่งที่เปลี่ยนคือ **ไม่เริ่ม/ไม่ทำงานพัฒนาใหม่ที่เกี่ยวกับ Pop ต่อ** จนกว่าจะได้รับคำสั่งให้กลับมาทำต่อ
- ผลกระทบ: หยุดพิจารณา task ที่เกี่ยวกับ Pop โดยตรงในรอบ roadmap ถัดไป (เช่น ปรับปรุง Pop เพิ่มเติม) จนกว่า Founder จะสั่งให้กลับมาทำต่อ — โค้ด/schema/route ของ Pop ที่มีอยู่แล้วไม่ถูกแตะต้อง
- อ้างอิง (task/PR ถ้ามี): ไม่มี PR เกี่ยวข้อง (เป็นการหยุดงานอนาคต ไม่ใช่ rollback งานเดิม)

### [2026-08-14] เพิ่มฟีเจอร์ใหม่ WYN CLUB (Community/กลุ่มความสนใจ) เข้า roadmap — ทำเฉพาะ Core System รอบแรก
- บริบท: Founder ส่ง spec ฉบับเต็มสำหรับ "WYN CLUB" — พื้นที่ Community/กลุ่มตามความสนใจภายใน WYN (คล้าย Facebook Groups แต่ออกแบบ UI/UX เป็นเอกลักษณ์ของ WYN เอง) ครอบคลุม 19 หัวข้อ: สร้าง/เข้าร่วม Club, Club Page, โพสต์ใน Club, ระบบสมาชิก/Role (Owner/Admin/Moderator/Member), ระบบ Admin จัดการ Club, Pinned Post, กฎ Club, Discovery/Explore, Search integration, Notification integration, Profile integration, Home integration, และ data structure (Club/ClubMember/ClubPost) — Founder ระบุชัดว่า **ใน Version แรกทำเฉพาะ Core Club System ก่อน อย่าใส่ฟีเจอร์อนาคต** (Events/Marketplace/Live/Chat/Poll ฯลฯ) และห้ามเปลี่ยนโครงสร้างเดิมของ Home/Drop/Pop/Profile/Navigation ที่ทำไว้แล้ว
- คำตัดสินใจของ Founder: เพิ่ม WYN CLUB เป็นฟีเจอร์ใหม่ในระบบ โดย **ไม่สร้าง Bottom Navigation tab ใหม่** — Club อยู่ภายในหน้า Home (คงโครงสร้าง Home | Drop | Pop | ZOKY | Profile เดิม) ทำเฉพาะ Core Club System ในรอบแรก
- ผลกระทบ: AI Product Manager จะแบ่งขอบเขตเป็น task ใหม่ตาม pattern เดิมของ roadmap (Core system ก่อน แล้วค่อยทำ Discovery/Search/Notification/Home integration เป็น task ต่อยอดทีหลัง เหมือนที่ Drop/Pop ได้ Home+Search+Notification integration เป็นงานแยกทีหลัง) — งานนี้มาแทนที่/แซงคิว WYN-010 (Share formalization) ในลำดับความสำคัญของ roadmap แต่ไม่กระทบ WYN-012 (Notification) ที่กำลังทำอยู่ตอนนี้ ให้ทำ WYN-012 ให้เสร็จสมบูรณ์ (ผ่าน QA) ก่อนแล้วค่อยเริ่ม WYN CLUB
- อ้างอิง (task/PR ถ้ามี): จะสร้าง `.wyn/tasks/backlog/WYN-014-club-core.md` เป็นต้นไปหลัง WYN-012 เสร็จ

### [2026-08-14] ขยาย WYN เป็น WYN Platform — เพิ่ม ZOKY Marketplace / ZOKY Sellers by WYN / WYN Admin / Shared Backend
- บริบท: หลัง WYN CLUB (WYN-014/WYN-015) ผ่าน QA ครบและ merge เข้า `main` แล้ว Founder ส่ง "WYN PLATFORM — MASTER DEVELOPMENT PROMPT" ฉบับเต็ม (38 หัวข้อ) กำหนดทิศทางใหม่ให้ WYN ขยายจาก Social app เดียวเป็น **WYN Platform** ที่ประกอบด้วย 5 ส่วน: (1) WYN Social (ของเดิม), (2) ZOKY Marketplace (E-commerce ใหม่), (3) ZOKY Sellers by WYN (แอป/ระบบสำหรับร้านค้า), (4) WYN Admin (หลังบ้านกลางของทั้ง Platform), (5) Shared Backend — พร้อมกติกาบังคับ: ห้ามลบ/ทำลายฟีเจอร์ WYN เดิม, ห้ามเปลี่ยน Navigation เดิมโดยไม่จำเป็น, ห้ามเขียนระบบซ้ำถ้า reuse ได้, Mobile-first, ออกแบบให้ขยายได้ในอนาคต (เผื่อ ZOKY Food/Rider/Delivery ภายหลัง แต่ **ยังไม่ทำรอบนี้** — โฟกัส Marketplace ก่อน), พัฒนาเป็น Phase ตามลำดับ (Phase 1 ตรวจสอบของเดิม → Phase 2-3 ZOKY Marketplace Customer → Phase 4 ZOKY Sellers → Phase 5 เชื่อมระบบ → Phase 6 WYN Admin → Phase 7-8 เชื่อม Admin + Finance/Fees/Analytics/Moderation) ตัว master prompt เองระบุ GitHub structure ตัวอย่างเป็น JS/TS-style monorepo (`apps/customer`, `apps/sellers`, `apps/admin`, `packages/ui` ฯลฯ) ซึ่ง**ไม่ตรงกับ stack จริงของโปรเจกต์**ที่เป็น Flutter (Dart) แอปเดียว + Supabase — AI Product Manager ตรวจสอบ repo จริงแล้วพบว่าไม่มี monorepo tooling ใด ๆ (ไม่มี Melos/workspace), ไม่มี routing package (ใช้ `Navigator.push`/`MaterialPageRoute` + `IndexedStack` ธรรมดา), ไม่มี state management library (ใช้ StatefulWidget + Repository pattern เรียก Supabase ตรง ๆ ต่อ feature)
- คำตัดสินใจของ AI Product Manager (ทำได้เองตาม RULES.md เพราะเป็น "วางแผน/Plan" ไม่ใช่การเปลี่ยน Major Architecture ของ stack เดิม — ยังคง Flutter+Supabase เหมือนเดิมทุกประการ ไม่ได้เปลี่ยน tech stack หรือ business model หลักของ WYN Social แต่อย่างใด เป็นการ**ต่อยอด**ตามคำสั่งตรงของ Founder):
  1. **ZOKY Marketplace (Customer)** รอบแรกนี้จะพัฒนาเป็น **feature module ใหม่ภายในแอป Flutter เดียวเดิม** (`app/lib/features/zoky/`) ไม่สร้างแอปแยก — ตรงตามกติกา "ห้ามเขียนระบบซ้ำ", "Mobile-first" และ "ห้ามเปลี่ยน Architecture เดิมโดยไม่จำเป็น" ของ Founder เอง
  2. **Navigation**: เพิ่ม Bottom Navigation tab ที่ 5 ชื่อ "ZOKY" ต่อจาก Home/Drop/Pop/Profile เดิม (ไม่แทรกกลาง ไม่ลบ/ย้ายตำแหน่งของเดิม) ตรงตามกติกา "ห้ามเปลี่ยน Navigation เดิมโดยไม่จำเป็น" และ Section 3 ของ master prompt ที่ระบุตรงว่า "เพิ่ม: ZOKY"
  3. **Backend**: ใช้ Supabase project เดียวกัน เพิ่ม table domain ใหม่ (stores/products/product_variants/categories/carts/cart_items/orders/order_items/reviews ฯลฯ) เข้า `supabase/schema.sql` ไฟล์เดิม ไม่แยก database ใหม่ — reuse RLS/security-definer RPC pattern ที่พิสูจน์แล้วจาก WYN Social (โดยเฉพาะ RPC-over-raw-RLS จาก WYN-014 สำหรับ permission graph ของ Seller/Order status transition)
  4. **Task numbering**: ใช้ prefix ใหม่ **ZOKY-XXX** แยกจาก WYN-XXX เดิม เพื่อให้ติดตามงานสองสายผลิตภัณฑ์ (WYN Social vs ZOKY Marketplace) แยกกันชัดเจนใน `.wyn/tasks/`/CONTEXT.md/METRICS.md แต่ยังอยู่ใน governance/workflow เดียวกันทั้งหมด (Product→Design→Code→QA→Debug, PR-per-role, Thai/English convention เดิมทุกประการ)
  5. **ขอบเขตรอบนี้ (ตาม Phase 1-3 ของ master prompt)**: ทำเฉพาะ ZOKY Marketplace **Customer-facing** (Home/Search/Product Detail/Store/Cart/Checkout/Order/Review) ก่อน — **ยังไม่ทำ** ZOKY Sellers by WYN (Phase 4), WYN Admin (Phase 6), Finance/Analytics/Moderation เต็มรูปแบบ (Phase 8), หรือ ZOKY Food/Rider/Delivery ตามที่ master prompt ระบุชัดว่ายังไม่ต้องทำ — จะประเมินสถาปัตยกรรม "แอปแยก vs feature module" ของ Seller/Admin อีกครั้งเมื่อถึง Phase 4/6 จริง ไม่ตัดสินใจล่วงหน้าตอนนี้
  6. **ค่าธรรมเนียม (ZOKY_MARKETPLACE_FEE)**: เก็บเป็นค่า configuration ที่แก้ไขได้ (ไม่ hard-code หลายจุด) ตามที่ master prompt ระบุไว้ตรง ๆ ค่าเริ่มต้น 10% ต่อ Order — จะออกแบบรายละเอียดที่ layer ไหน (DB config table vs Dart constant) ตอนเขียน task spec ของ Checkout/Order
- ผลกระทบ: จะสร้าง `.wyn/docs/product/zoky-platform-roadmap.md` (แจกแจง Phase และ task ZOKY-001 เป็นต้นไป) และ `.wyn/tasks/backlog/ZOKY-001-...md` (task แรก) ตามหลัง entry นี้ทันที — WYN Social ทั้งหมด (Home/Drop/Pop/Club/Profile/Search/Notification) **ไม่ถูกแตะต้อง** ยังทำงานเหมือนเดิมทุกประการ — งาน WYN-010 (Share formalization) และคำขออนุมัติค้างเรื่องลบตาราง `posts`/`likes`/`comments` (WYN-004 เดิม) ใน `.wyn/company/APPROVALS.md` ยังคงค้างอยู่เหมือนเดิม ไม่ได้ถูกยกเลิกหรือแทนที่ด้วยงานนี้
- อ้างอิง (task/PR ถ้ามี): จะสร้าง `.wyn/docs/product/zoky-platform-roadmap.md`, `.wyn/tasks/backlog/ZOKY-001-marketplace-foundation.md`

### [2026-08-15] ZOKY Marketplace Customer-facing scope (Phase 2-3) เสร็จสมบูรณ์ครบวงจร — หยุดรอ Founder ก่อนเริ่ม Phase 4
- บริบท: ตามคำสั่ง Founder "ทำจนเสร็จให้หมดทุกอย่างเลยนะ พอดีจะนอนแล้ว" (2026-08-15) ทีม AI ทำงานต่อเนื่องอัตโนมัติจน ZOKY-003 (Cart & Checkout & Order) และ ZOKY-004 (Review) ผ่าน QA และ merge เข้า `main` ครบทั้งคู่ — ZOKY-004 ใช้เวลา 2 รอบ QA (รอบ 1 FAIL เพราะพบช่องโหว่ security ระดับ Critical ใน `reviews`' update RLS policy, Debug แก้แล้วรอบ 2 PASS) ปิดจบ ZOKY Marketplace Customer-facing scope ทั้งสาย: Browse (ZOKY-001) → Search & Filter (ZOKY-002) → Cart & Checkout & Order (ZOKY-003) → Review (ZOKY-004) ตาม roadmap Phase 2-3 ครบทุก task
- คำตัดสินใจของ AI Product Manager: **หยุดที่จุดนี้ ไม่เริ่ม Phase 4 (ZOKY Sellers by WYN) เองโดยอัตโนมัติ** แม้คำสั่ง "ทำจนเสร็จให้หมดทุกอย่างเลยนะ" จะยังไม่ถูกยกเลิก เพราะ roadmap doc (`.wyn/docs/product/zoky-platform-roadmap.md`, Phase 4) และ DECISIONS.md entry ก่อนหน้านี้ (2026-08-14) ระบุไว้ชัดเจนแล้วว่า Phase 4 ต้อง **"ประเมินสถาปัตยกรรม 'แอป Flutter แยกต่างหาก vs feature module ภายในแอปเดียว vs Flutter module แบบ add-to-app' ตอนถึง Phase นี้จริง ไม่ตัดสินใจล่วงหน้า"** — นี่คือคำตัดสินใจระดับ Major Architecture ที่กระทบโครงสร้าง repository/deployment ทั้งหมด (repo ปัจจุบันไม่มี monorepo tooling เลย การสร้างแอปที่สองจริง ๆ ต้องลงทุนโครงสร้างใหม่ก่อน) ต่างจาก ZOKY-001 ถึง ZOKY-004 ที่เป็นการต่อยอด feature module เดิมที่ Founder อนุมัติทิศทางไว้แล้วชัดเจนตั้งแต่ต้น (2026-08-14) — ตาม RULES.md การเปลี่ยนแปลง Major Architecture ต้องขออนุมัติ Founder ก่อนเสมอ ไม่ใช่สิ่งที่ AI ตัดสินใจเองต่อเนื่องได้แม้จะมีคำสั่งทำงานอัตโนมัติทั่วไปอยู่ก็ตาม
- ผลกระทบ: งานทั้งหมดที่ทำได้ภายใต้คำสั่งเดิมเสร็จสมบูรณ์แล้ว ระบบรอ Founder ตื่นมาตัดสินใจทิศทาง Phase 4 ก่อนจะเริ่มงานต่อ (แอปแยก vs feature module vs add-to-app module) — ไม่มีงานค้างคาที่เป็นความเสี่ยง data-integrity/security ใด ๆ ทุก task ที่ merge แล้วผ่าน QA ครบ (รวม security fix ของ ZOKY-004)
- อ้างอิง (task/PR ถ้ามี): PR #77-86 (ZOKY-003/ZOKY-004 ทุกรอบ), `.wyn/tasks/approved/ZOKY-003-cart-checkout-order.md`, `.wyn/tasks/approved/ZOKY-004-review.md`, `.wyn/tasks/bugs/ZOKY-004-review-update-rls-gap.md`

### [2026-08-15] Phase 4 (ZOKY Sellers by WYN) — เลือกสถาปัตยกรรม Feature module ในแอปเดียวเดิม
- บริบท: Founder ตื่นแล้ว กลับมาตัดสินใจสถาปัตยกรรมของ Phase 4 ตามที่ระบบหยุดรอไว้ (ดู entry ก่อนหน้า 2026-08-15) — ระบบเสนอ 3 ทางเลือก: (1) Feature module ในแอป Flutter เดียวเดิม (2) แอปแยกต่างหาก (เช่น Shopee Seller Center) (3) Flutter add-to-app module
- คำตัดสินใจของ Founder: เลือก **Feature module ในแอปเดียวเดิม** — เหตุผลตรงตาม AI ที่แนะนำ: repo ปัจจุบันไม่มี monorepo tooling เลย, ไม่ต้องลงทุนโครงสร้างใหม่, สอดคล้องกับ pattern ที่ทำมาตลอดตั้งแต่ ZOKY Marketplace Customer (feature module เดียวกันหมด), ผู้ใช้ที่เป็นทั้งผู้ซื้อและผู้ขาย (พบเห็นบ่อยใน marketplace ขนาดเล็ก-กลาง) ใช้แอปเดียวสลับ role ได้เลยไม่ต้องโหลดสองแอป
- ผลกระทบ: ZOKY Sellers by WYN จะพัฒนาเป็น `app/lib/features/seller/` (หรือชื่อเทียบเท่า) ในแอป Flutter เดียวเดิม ไม่มีการสร้าง repository/project ใหม่ — แนวทาง UI ที่เป็นไปได้ (ให้ AI Design ตัดสินใจรายละเอียดตอนออกแบบจริง): เพิ่ม role-based UI entry point (เช่น "โหมดร้านค้า" ใน Profile หรือ Settings) แทนที่จะเพิ่ม Bottom Nav tab ที่ 6 (เพราะ Bottom Nav เต็มแล้วที่ 5 tab และ Seller ไม่ใช่ทุกคนที่มี ต่างจาก ZOKY ที่ทุกคนช้อปได้) — **รอ Founder ส่งเนื้อหาเต็มของ master prompt Section ที่เกี่ยวกับ Seller** (Section 12-17 โดยประมาณ) มาใหม่ก่อนเขียน Product spec จริง เพราะเนื้อหาเต็มไม่เคยถูกเก็บไว้ใน repo เลย มีแค่ summary ระดับสูงใน entry ก่อนหน้า (2026-08-14) — Founder เลือกให้ส่ง section มาใหม่แทนที่จะให้ AI กำหนดขอบเขตเอง
- อ้างอิง (task/PR ถ้ามี): รอเนื้อหา Seller section จาก Founder ก่อนสร้าง `.wyn/tasks/backlog/ZOKY-005-...md` (หรือเลขถัดไป) เป็นต้นไป

### [2026-08-15] Phase 4 (ZOKY Sellers by WYN) — Founder แก้ไขคำตัดสินใจเป็นแอปแยกต่างหาก (ยกเลิก entry ก่อนหน้าเรื่อง feature module)
- บริบท: หลัง entry ก่อนหน้า (เลือก Feature module ในแอปเดียวเดิม) ไม่นาน Founder กลับมาแก้ไขคำตัดสินใจตรง ๆ ("แอปแยกนะ ZOKY Seller by WYN") — **entry นี้ยกเลิก/แทนที่คำตัดสินใจ Feature module ก่อนหน้าโดยสมบูรณ์** ยังไม่มีงานใดถูก implement ไปตามคำตัดสินใจเดิมเลย (ยังอยู่ขั้นตอนรอเนื้อหา Seller section) จึงไม่มี rework ทางเทคนิคเกิดขึ้นจากการแก้ไขนี้
- คำตัดสินใจของ Founder: **ZOKY Sellers by WYN จะพัฒนาเป็นแอป Flutter แยกต่างหาก** (ไม่ใช่ feature module ในแอปเดิม) — เทียบเท่าโมเดล Shopee Seller Center/Lazada Seller Center ที่แยก app ชัดเจนจากฝั่งลูกค้า
- ผลกระทบ (สิ่งที่ต้องเตรียมก่อนเริ่ม Phase 4 จริง เพราะ repo ปัจจุบันไม่มี monorepo tooling ใด ๆ):
  1. **โครงสร้าง repository**: ต้องตัดสินใจว่าจะสร้างแอปที่สองในรูปแบบไหน — (ก) โปรเจกต์ Flutter ใหม่แยกทั้งหมดใน repo เดียวกัน (เช่น `seller_app/` คู่กับ `app/` เดิม โดยยังไม่ใช้ monorepo tool อย่างเป็นทางการ แค่โฟลเดอร์แยก) หรือ (ข) ตั้ง monorepo tooling จริงจัง (เช่น Melos) เพื่อ share package ระหว่างสองแอป (models/repository/design system ร่วมกัน) — เป็นการตัดสินใจย่อยที่ AI Product Manager/Coding จะเสนอทางเลือกให้ Founder อีกครั้งตอนเริ่ม implement จริง เพราะกระทบ build/CI/deploy pipeline
  2. **Backend**: ยังคงใช้ Supabase project เดียวกัน (ไม่มี Shared Backend แยก) ตามที่ master prompt ระบุไว้แต่ต้นว่า "Shared Backend" เป็นส่วนหนึ่งของ 5 ส่วนของ WYN Platform — แค่ฝั่ง client (Flutter) แยกเป็นสองแอป ไม่ใช่แยก backend
  3. **Design system**: ต้องตัดสินใจว่าจะ share Flutter package (widgets/theme) ระหว่างสองแอปยังไง หรือจะ duplicate/reimplement เพื่อความเรียบง่ายในรอบแรก (ให้ AI Design เสนอตอนเริ่มออกแบบจริง)
  4. ยังคง **รอ Founder ส่งเนื้อหาเต็มของ master prompt Section ที่เกี่ยวกับ Seller** เหมือน entry ก่อนหน้า — เงื่อนไขนี้ไม่เปลี่ยน
- อ้างอิง (task/PR ถ้ามี): รอเนื้อหา Seller section จาก Founder ก่อนเริ่มงานจริง — entry นี้แทนที่ entry ก่อนหน้า (2026-08-15, "เลือกสถาปัตยกรรม Feature module ในแอปเดียวเดิม") อย่างสมบูรณ์

### [2026-08-15] Phase 4 (ZOKY Sellers by WYN) — Founder ส่งเนื้อหา Section 12-17 เต็มแล้ว, AI Product Manager วาง task breakdown + ตัดสินใจ implementation detail ที่เหลือ
- บริบท: Founder ส่ง "WYN PLATFORM — MASTER DEVELOPMENT PROMPT" ฉบับเต็มมาอีกครั้ง (มีเนื้อหา Section 12-17 ที่ขาดหายไปจาก repo ตั้งแต่ต้น) — AI Product Manager ตรวจสอบ repo (`app/pubspec.yaml`, bundle ID `io.wyn.wyn`, `app/lib/main.dart`'s theme setup, `app/lib/core/env.dart`'s dart-define pattern, `app/lib/features/auth/` 6 หน้าจอ, `supabase/schema.sql`'s RLS ปัจจุบันของ `stores`/`products`/`orders`) ก่อนวาง task breakdown ตาม Section 37 ของ master prompt เอง
- คำตัดสินใจของ AI Product Manager (ทำได้เองตาม RULES.md เพราะเป็นรายละเอียด implementation ต่อยอดจากคำตัดสินใจสถาปัตยกรรมหลักที่ Founder ยืนยันแล้ว — แอปแยก, ไม่ใช่ Major Architecture/Vision/Business Model/Security change ใหม่):
  1. **Repository ของแอปที่สอง**: โฟลเดอร์ `seller_app/` ที่ root ของ repo เดียวกัน (คู่กับ `app/`) — **ไม่ใช้ Melos/monorepo tooling ในรอบแรก** เพราะยังไม่มี pain จริงจากการไม่มี shared package (แค่ 2 แอป) ประเมินใหม่ในอนาคตถ้า duplication เริ่มเจ็บปวดจริง
  2. **Bundle ID**: `io.wyn.zokyseller` (เทียบกับ `app/`'s `io.wyn.wyn`)
  3. **Authentication**: reuse Supabase Auth เดียวกับ WYN Social ทั้งหมด (`auth.users`/`profiles` เดิม) — Seller คือผู้ใช้ WYN ที่มีอยู่แล้วที่ "สมัครร้าน" เพิ่ม (สร้างแถว `stores` ใหม่ที่ `owner_id = auth.uid()` — คอลัมน์นี้มีอยู่แล้วตั้งแต่ ZOKY-001) ไม่สร้างระบบ auth ใหม่แยกต่างหาก ตรงตามกติกา "ห้ามเขียนระบบซ้ำ" ของ master prompt เอง — sign-in screen เป็น UI code ใหม่ (เพราะเป็นคนละ Flutter binary ไม่มี package infra ให้ share) แต่เรียก backend เดียวกัน
  4. **Design system**: duplicate seed color (`0xFF2D6CDF`) + Material 3 setup เข้า `seller_app/main.dart` ตรง ๆ ไม่สร้าง shared package (เหตุผลเดียวกับ Env — ไฟล์เล็กเกินไปที่จะคุ้มค่าลงทุน infra ใหม่)
  5. **Order status ขยายจาก 3 เป็น 8 สถานะ**: ตาม master prompt Section 10 ที่ระบุไว้ตั้งแต่ต้น (Pending Payment/Paid/Seller Processing/Ready to Ship/Shipped/Delivered/Cancelled/Refunded) — ZOKY-003 บันทึกไว้ชัดเจนแล้วว่าเป็น known simplification ที่รอจุดนี้พอดี (ดู `.wyn/tasks/approved/ZOKY-003-cart-checkout-order.md`, Risks) — แยกเป็น SELLER-003 เพราะกระทบโค้ด Customer-facing ที่ผ่าน QA แล้วมากที่สุด (`OrderStatusBadge`, `ZokyOrderDetailScreen`) ต้อง migration ระมัดระวังเป็นพิเศษ
  6. **Payment/Shipping Provider**: ยังไม่ทำจริงเหมือนเดิม (ตาม master prompt เองก็ระบุไว้ตรง ๆ ว่า Shipping ไม่ต้องสร้างบริษัทขนส่งเอง) — Finance (SELLER-005) คำนวณจาก `Order.total` ที่มีอยู่แล้ว ไม่ใช่จาก payment gateway จริง
  7. **Seller Approval**: auto-approved ทันทีที่ "สมัครร้าน" รอบนี้ (ไม่มี Admin ให้อนุมัติเพราะ Phase 6 ยังไม่เริ่ม) บันทึกเป็น Known Issue ชัดเจน
- ผลกระทบ: แบ่ง Phase 4 เป็น 5 task (SELLER-001 Foundation → SELLER-002 Product Management → SELLER-003 Order Management (ขยายสถานะ) → SELLER-004 Store Management → SELLER-005 Finance) บันทึกรายละเอียดเต็มที่ `.wyn/docs/product/zoky-platform-roadmap.md` (Phase 4 section) — เริ่ม SELLER-001 ทันที
- อ้างอิง (task/PR ถ้ามี): จะสร้าง `.wyn/tasks/backlog/SELLER-001-foundation.md` ต่อจาก entry นี้ทันที

### [2026-08-15] เปลี่ยน Color Direction ของ WYN: Blue → Cyan (Founder เลือกทางเลือก B — Cyan ดิบตามที่กำหนดมา)
- บริบท: Founder ส่ง brief "WYN DESIGN SYSTEM REFINEMENT" ขอปรับ UI/UX ให้เป็น Minimal Social Platform ระดับ production โดยกำหนด palette ใหม่มาเอง — AI Product Manager ทำ audit (`.wyn/tasks/backlog/DS-001-design-system-audit.md`) และ AI Design ทำ color system spec + หน้าเปรียบเทียบ 3 ทางเลือกบนหน้าจอจริงทั้ง light/dark ให้ Founder ดูก่อนตัดสิน (Founder ขอ "ดูตัวอย่างก่อนตัดสิน")
- **คำตัดสินใจของ Founder: เลือกทางเลือก B — ใช้ค่าสีที่กำหนดมาตรง ๆ ทั้ง light และ dark** (หลังเห็นหน้าเปรียบเทียบที่แสดงผลจริงของทั้ง 3 ทางเลือกแล้ว)
- **คำตัดสินใจนี้แทนที่ (supersede) คำตัดสินใจเดิม** "Color Direction: Blue + White + Soft Gray" (2026-08-14, จาก "WYN V0.1 — CORE APP FEATURE PROMPT") อย่างสมบูรณ์ — seed color `#2D6CDF` ที่ใช้อยู่ทั้งสองแอปจะถูกแทนที่
- Palette ที่ Founder กำหนด (ผูกพันแล้ว):
  - WYN Primary (accent เท่านั้น ห้ามใช้เป็นพื้นหลังขนาดใหญ่): Cyan `#00C8FF`
  - WYN Black `#0A0A0A` / White `#FFFFFF` / Gray `#6B7280` / Border `#E5E7EB`
  - Dark: BG `#000000` / Surface `#111111` / Border `#222222`
  - ZOKY Primary (commerce layer แยก identity): Orange `#FF6B35` ใช้เฉพาะ price/CTA/seller badge/commerce state — ห้ามเปลี่ยนทั้งหน้าจอเป็นส้ม
- กติกาเดิมที่ยังคงอยู่ ไม่ถูกแทนที่: ห้ามใช้ Liquid Glass, ห้ามลอก layout ของ Instagram/TikTok (เพิ่ม Threads เข้าไปในรายการ — ใช้เป็นแรงบันดาลใจเรื่องความเรียบได้ แต่ห้ามลอก)
- **ความเสี่ยงที่ทีมแจ้งไว้แล้วและ Founder รับทราบก่อนตัดสินใจ** (บันทึกไว้เพื่อความโปร่งใส ไม่ใช่การคัดค้านคำตัดสินใจ): Cyan `#00C8FF` บนพื้นขาวได้ contrast 1.96:1 และ Orange `#FF6B35` บนพื้นขาวได้ 2.84:1 ซึ่งต่ำกว่าเกณฑ์ WCAG AA (ตัวหนังสือต้อง ≥4.5:1, UI component ต้อง ≥3.0:1) — บนพื้นดำทั้งคู่ผ่านสบาย (10.09:1 และ 6.98:1) ผลกระทบที่ตามมาคือ light mode อาจถูกทักท้วงตอนรีวิว accessibility ของ App Store/Play Store และผู้ใช้กลางแดดอ่านยาก รายละเอียดเต็มอยู่ที่ `.wyn/docs/design/ds-001-color-system.md`
- **Theme mode**: Founder ยืนยันให้ **คงพฤติกรรมเดิมคือตามธีมของเครื่อง (`ThemeMode.system`)** — ไม่ตั้ง dark-first ตามที่ AI Design เสนอ ทั้ง light และ dark ต้องใช้งานได้จริงเท่าเทียมกัน
- ผลกระทบ: กระทบทุกหน้าจอทั้ง 45 หน้าในสองแอป (blast radius กว้างที่สุดเท่าที่เคยทำในโปรเจกต์นี้) — แบ่งงานเป็น DS-001..DS-008 ทำทีละขั้น ไม่ทำรวดเดียว, `.wyn/docs/design/design-principles.md` ต้องอัปเดตหัวข้อสีให้ตรงกับ entry นี้
- อ้างอิง: `.wyn/tasks/backlog/DS-001-design-system-audit.md`, `.wyn/docs/design/ds-001-color-system.md`, หน้าเปรียบเทียบที่ Founder ใช้ตัดสิน (artifact)

### [2026-08-16] ข้ามหน้าล็อกอินชั่วคราวสำหรับ Internal Testing (ยังไม่ได้ตั้งค่า Google OAuth/Apple Developer/Twilio)
- บริบท: Founder ยังไม่ได้สมัคร Google OAuth Client ID / Apple Developer Account / Twilio (SMS OTP) — ทั้งสามอย่างเป็น dependency ของ WYN-002's sign-in flow เดิม (Google/Apple OAuth + Phone OTP เท่านั้น ไม่มี Email/Password ตาม decision วันที่ 2026-08-13) Founder ขอให้ "หยุดหน้าล็อกไว้ก่อน ใช้งานแบบไม่ล็อกอิน" เพื่อให้ทีมทดสอบแอปได้ระหว่างรอสมัคร account ทั้งสาม
- คำตัดสินใจของ Founder: เพิ่มทางเข้าใช้งานแบบไม่ต้องล็อกอินชั่วคราว (ไม่ใช่แทนที่ Google/Apple/Phone OTP ถาวร) — ใช้ Supabase's built-in **Anonymous Sign-In** (ฟรี, ไม่ต้องพึ่ง third-party account ใด ๆ, แค่เปิด toggle "Allow anonymous sign-ins" ใน Supabase Dashboard ของ project ที่มีอยู่แล้ว `akawuzukstmbztyajxsr`) เพราะให้ session/`auth.uid()` จริงที่ RLS policy ทำงานได้ปกติทุกจุด ต่างจากการปลอมข้อมูล/mock ซึ่งใช้ไม่ได้กับ backend จริง
- ผลกระทบ: เพิ่มปุ่ม "ทดลองใช้โดยไม่ต้องเข้าสู่ระบบ" ใน `app/`'s `WelcomeScreen` และ `seller_app/`'s `SellerSignInScreen` (ทั้งสองแอปเรียก `AuthRepository`/`SellerAuthRepository.signInAnonymously()` ใหม่) — ไม่ลบ/ซ่อนปุ่ม Google/Apple/Phone OTP เดิม แค่เพิ่มทางเลือกคู่กัน onboarding flow (username setup → RootShell) ทำงานเหมือนผู้ใช้ปกติทุกประการเพราะ anonymous session ก็มี `auth.uid()` ที่ใช้ได้จริง — **มีขั้นตอนเดียวที่ Founder ต้องทำเอง**: เปิด toggle "Allow anonymous sign-ins" ที่ Supabase Dashboard → Authentication → Settings (ฟรี ไม่ต้องผูกบัตร) มิฉะนั้นปุ่มนี้จะ error
- ข้อจำกัดที่บันทึกไว้เพื่อความโปร่งใส: ผู้ใช้ anonymous ยังไม่มีการเชื่อมกับ Google/Apple/เบอร์โทรจริง (ถ้าถอนการติดตั้งแอปจะเข้าบัญชีเดิมไม่ได้อีก) — Supabase รองรับการ "upgrade" anonymous user เป็นบัญชีจริงภายหลังผ่าน `linkIdentity` โดยไม่เสียข้อมูล/โปรไฟล์เดิม แต่เส้นทางนี้ยังไม่ได้เชื่อมเข้า UI ในรอบนี้ (เป็นงานต่อยอดถ้าต้องการ) — เป็นทางลัดสำหรับ Internal Testing เท่านั้น ก่อน public launch ต้องกลับมาบังคับ Google/Apple/Phone OTP ตามเดิม
- อ้างอิง (task/PR ถ้ามี): `app/lib/features/auth/data/auth_repository.dart`, `app/lib/features/auth/presentation/welcome_screen.dart`, `seller_app/lib/features/auth/data/seller_auth_repository.dart`, `seller_app/lib/features/auth/presentation/seller_sign_in_screen.dart`
