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
