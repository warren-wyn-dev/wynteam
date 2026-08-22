# Product Task — WYN-029

Status: backlog
Owner: AI Product Manager

Feature: Moderation Queue + Action (ขั้นต่ำในแอป Flutter เดิม)

Goal: ให้ Report ที่เข้ามาจาก WYN-026 ถูกตรวจสอบและดำเนินการได้จริงโดยผู้มีสิทธิ์ (moderator/admin) ตั้งแต่ Phase 1 นี้ ผ่านหน้าจอขั้นต่ำในแอป Flutter เดิม — โดยไม่ต้องรอ WYN Admin (เว็บ, Phase 7) ตามที่ Founder ยืนยัน (2026-08-22)

Target User: ผู้ใช้ที่มีบทบาท moderator/admin ของแพลตฟอร์ม (รอบแรกคือ Founder/ทีมภายในที่ Founder ตั้งค่าให้ผ่าน DB โดยตรง) — ผลลัพธ์ปลายทางคือผู้ใช้ทั่วไปที่ได้รับความปลอดภัยจากการที่ Report ถูกดำเนินการจริง ไม่ค้างเฉย ๆ

Problem: WYN-026 ทำให้ผู้ใช้ส่ง Report ได้แล้ว แต่ยังไม่มีใคร/ที่ใดให้ตรวจสอบและตัดสินใจ — Master Spec ข้อ 25 กำหนด Workflow ไว้ว่า "Report → Moderation Queue → Review → Action (No Action/Warning/Remove Content/Restrict/Suspend/Ban) → Appeal" — WYN Admin ที่ตั้งใจเป็นเครื่องมือหลักของทีม Moderation ยังไม่เริ่มสร้างจนกว่าจะถึง Phase 7 (แยก tech stack เป็นเว็บ) ทำให้ต้องมีหน้าจอขั้นต่ำในแอปเดิมไปก่อนตามที่ Founder ตัดสินใจ

Requirements:

**Platform Role (พื้นฐานใหม่ที่ยังไม่มีในระบบ)**
- เพิ่มคอลัมน์ `platform_role` ใน `profiles` (ค่า: `user` (default) / `moderator` / `admin`) — **ตั้งค่าได้เฉพาะทาง Supabase โดยตรงในรอบนี้เท่านั้น ไม่มี UI ในแอปให้ตั้งเอง** (ไม่มีใครสามารถเลื่อนสิทธิ์ตัวเองผ่าน client ได้ — ป้องกัน privilege escalation ตั้งแต่ต้น)
- `admin` เห็น/ทำได้ทุกอย่างที่ `moderator` ทำได้ + จัดการ `platform_role` ของคนอื่น (ผ่าน DB โดยตรงในรอบนี้เหมือนกัน ยังไม่มี UI จัดการ role ใครเลยในแอป)

**Moderation Queue Screen (เข้าถึงได้เฉพาะ platform_role = moderator/admin)**
- Entry point ซ่อนอยู่ (ไม่ปรากฏในเมนูของผู้ใช้ทั่วไป) — แนะนำเข้าถึงผ่านปุ่มลับใน Settings ที่โผล่เฉพาะเมื่อ `platform_role != 'user'` เท่านั้น (ผู้ใช้ทั่วไปไม่เห็นแม้แต่ทางเข้า)
- แสดงรายการ Report ที่ status = `pending`/`reviewing` เรียงจากเก่าไปใหม่ (FIFO อย่างง่ายรอบนี้ — ไม่ทำ priority scoring ซับซ้อน)
- แต่ละแถวแสดง: Category, Target Type, สรุปเนื้อหา/ผู้ใช้เป้าหมาย (ลิงก์เปิดดูเนื้อหา/โปรไฟล์จริงได้), รายละเอียดเพิ่มเติมจากผู้รายงาน, เวลาที่รายงาน — **ไม่แสดงตัวตนผู้รายงาน** (คงกติกา privacy จาก WYN-026)
- แตะเข้ารายละเอียด Report หนึ่งอัน → เห็นปุ่ม Action 6 แบบตาม Master Spec: **No Action, Warning, Remove Content, Restrict, Suspend, Ban**
- เลือก Action → กรอกเหตุผล (บังคับ, ใช้เป็นข้อมูลให้ผู้ใช้เห็นตอน Appeal) → ยืนยัน → Report เปลี่ยน status เป็น `actioned` (หรือ `dismissed` ถ้าเลือก No Action) บันทึกลง `moderation_actions` พร้อม reviewer/เวลา

**ความหมายและผลของแต่ละ Action**
- **No Action**: ปิดเคส ไม่มีผลใด ๆ ต่อเนื้อหา/ผู้ใช้ (dismissed)
- **Warning**: ส่ง notification ถึงผู้ถูก Report แจ้งว่าเนื้อหา/พฤติกรรมของเขาละเมิดกฎ พร้อมเหตุผล ไม่มีผลจำกัดการใช้งานใด ๆ เพิ่มเติม
- **Remove Content**: เนื้อหาเป้าหมาย (Drop/Comment/Club Post) ถูกลบแบบ soft-delete (ผู้เขียนเห็นว่าเนื้อหาถูกลบเพราะละเมิดกฎ, คนอื่นมองไม่เห็นอีกต่อไป) — เฉพาะ target ที่เป็นเนื้อหา ไม่ใช้กับ target ที่เป็น User/Club
- **Restrict**: จำกัดความสามารถของบัญชีชั่วคราว (โพสต์ Drop ใหม่ไม่ได้, Comment ไม่ได้, สร้าง Club ไม่ได้ — ยังคง Login/ดู/Like/Follow ได้ปกติ) มีกำหนดระยะเวลา (เลือกได้: 1 วัน / 3 วัน / 7 วัน) หมดเวลาแล้วคืนสิทธิ์อัตโนมัติ
- **Suspend**: ระงับบัญชีชั่วคราว (Login ไม่ได้เลยระหว่างช่วงเวลาที่กำหนด — ตัวเลือกเดียวกับ Restrict: 1/3/7 วัน) หมดเวลาแล้วคืนสิทธิ์อัตโนมัติ
- **Ban**: ระงับบัญชีถาวร (Login ไม่ได้อีกเลยจนกว่า admin จะ Unban ด้วยมือ — ไม่มี auto-expire)

**บังคับใช้ Restrict/Suspend/Ban จริงในแอป**
- Suspend/Ban: พยายาม Login → แสดงข้อความแจ้งสถานะบัญชีและเหตุผล (ถ้ามี) ไม่ปล่อยเข้าแอป — เซสชันที่ login ค้างอยู่ก่อนหน้าต้องถูกบังคับ logout ด้วย (force logout)
- Restrict: ปุ่มโพสต์ Drop/Comment/สร้าง Club ถูกปิดใช้งานพร้อมข้อความอธิบายสถานะและวันหมดเขต

Acceptance Criteria:
- [ ] บัญชี `platform_role = user` (ค่าเริ่มต้น) → ไม่เห็นทางเข้า Moderation Queue เลยในทุกจุดของแอป
- [ ] บัญชี `platform_role = moderator` หรือ `admin` → เห็นทางเข้าและเปิด Moderation Queue ได้ เห็นรายการ Report สถานะ pending/reviewing เรียง FIFO
- [ ] เปิดรายละเอียด Report → เห็นเนื้อหา/target ที่ถูกรายงานจริง ไม่เห็นตัวตนผู้รายงาน
- [ ] เลือก Action "No Action" → Report ปิดเป็น dismissed ไม่มีผลกับเนื้อหา/ผู้ใช้
- [ ] เลือก "Warning" → ผู้ถูก report ได้รับ notification พร้อมเหตุผล ไม่ถูกจำกัดสิทธิ์อะไร
- [ ] เลือก "Remove Content" บน Drop/Comment/Club Post → เนื้อหาถูกลบจริง (ผู้เขียนเห็นสถานะถูกลบเพราะละเมิดกฎ คนอื่นมองไม่เห็น)
- [ ] เลือก "Restrict" 3 วัน → บัญชีเป้าหมายโพสต์/comment ไม่ได้ทันที ยัง login/ดู/like ได้ปกติ ครบ 3 วันแล้วคืนสิทธิ์อัตโนมัติ
- [ ] เลือก "Suspend" 3 วัน → บัญชีเป้าหมาย login ไม่ได้ทันที เซสชันเดิมถูก force logout ครบ 3 วันแล้ว login ได้อัตโนมัติ
- [ ] เลือก "Ban" → บัญชีเป้าหมาย login ไม่ได้ถาวรจนกว่า admin จะ unban ด้วยมือ (ไม่มี auto-expire)
- [ ] ทุก Action บันทึกลง `moderation_actions` ครบ (report_id, action_type, reason, reviewer_id, เวลา) ตรวจสอบผ่าน DB ได้
- [ ] Regression: ผู้ใช้ทั่วไป (`platform_role = user`) ใช้งานทุกฟีเจอร์เดิมได้ปกติไม่มีอะไรเปลี่ยน

Dependencies: WYN-026 (Report — ต้องเสร็จก่อน เพราะ Queue อ่านจากตาราง `reports`), WYN-002/003 (Auth/Profile — Approved, ต้องแก้ login flow ให้เช็ค suspend/ban)

Priority: P0 — ตามคำตัดสินใจของ Founder (2026-08-22) ให้ Phase 1 ใช้งานได้จริงตั้งแต่ตอนนี้ ไม่รอ Phase 7

Risks:
- **Privilege escalation ผ่าน `platform_role`**: ต้องแน่ใจว่าไม่มี RLS/RPC ใดให้ client เปลี่ยนค่า `platform_role` ของตัวเองหรือคนอื่นได้เลย (ไม่มี update policy บน column นี้จาก client ฝั่งไหนทั้งสิ้น) — ตั้งค่าได้ทาง Supabase Dashboard/SQL โดย Founder เท่านั้นในรอบนี้ ล้อ pattern เดียวกับที่ WYN-014 ป้องกัน owner_id ไม่ให้ client แก้เอง
- **Restrict/Suspend/Ban ต้องบังคับใช้ที่ RLS ไม่ใช่แค่ UI**: ถ้าจำกัดแค่ฝั่ง Dart (ซ่อนปุ่ม) ผู้ใช้ที่ถูก Restrict ยังเรียก Supabase API ตรงเพื่อโพสต์ได้ — ต้องมี RLS policy บน `drops`/`club_posts`/`drop_comments` เช็คสถานะบัญชีก่อน insert เสมอ, Suspend/Ban ต้องเช็คตอน login (ก่อน issue session ใหม่) และ invalidate session เดิมจริง (ตรวจสอบวิธี force-logout ที่ Supabase Auth รองรับ)
- **Auto-expire ของ Restrict/Suspend ต้องมีกลไกจริง**: ไม่ใช่แค่เก็บ `expires_at` เฉย ๆ — ต้องมี logic เช็ค `expires_at < now()` ทุกจุดที่ enforce (RLS/login check) แทนพึ่ง cron job แยกที่ยังไม่มีในระบบ (แนะนำเช็คแบบ on-read/on-write ไม่ใช่ batch job เพื่อไม่ต้องเพิ่ม infrastructure ใหม่)
- **หน้าจอนี้เป็นเครื่องมือภายในชั่วคราว**: เมื่อถึง Phase 7 (WYN Admin) ต้องตัดสินใจว่าจะถอดหน้าจอนี้ออกจากแอป consumer หรือเก็บไว้เป็น fallback — บันทึกไว้เป็นการตัดสินใจที่ต้องทำตอนถึง Phase 7 ไม่ใช่ตอนนี้
- **ยังไม่มี Priority/Risk Classification อัตโนมัติ**: Master Spec ข้อ 41 (Admin Report Center, Phase 7) พูดถึง "Reports → Priority → Risk Classification" แต่รอบนี้ (ขั้นต่ำ) ใช้แค่ FIFO เรียงตามเวลา — ยกเว้นไว้เป็นงานของ Phase 7 ที่ทำเต็มรูปแบบ

Recommendation:
1. ทำหลัง WYN-026 เสร็จสมบูรณ์ (ต้องมี Report ให้ดูก่อนถึงจะทดสอบ Queue ได้จริง) — ทำขนานกับ WYN-027/028 ได้เพราะ scope ไม่ชนกัน
2. เก็บ UI ให้เรียบง่ายที่สุดเท่าที่ทำงานได้จริง (list + detail + action button) ไม่ต้องขัดเกลาสวยงามระดับ Production Admin เพราะจะถูกแทนที่ด้วย WYN Admin ใน Phase 7 อยู่แล้ว — ไม่ควรลงทุนเวลากับ UI polish ของหน้าจอนี้มากเกินจำเป็น
3. ตั้งค่า `platform_role` ให้ Founder เป็น `admin` ทันทีที่ deploy เป็นบัญชีแรก (ทำผ่าน SQL โดย AI Deploy & DevOps ตอน deploy จริง ไม่ใช่ AI Coding ตอน implement)

Handoff: AI Design — ออกแบบ Moderation Queue screen (list + detail + action confirmation ขั้นต่ำ), entry point ที่ซ่อนใน Settings, และ UI แจ้งสถานะบัญชีตอน Restrict/Suspend/Ban (ทั้งตอน login และตอนพยายามโพสต์)
