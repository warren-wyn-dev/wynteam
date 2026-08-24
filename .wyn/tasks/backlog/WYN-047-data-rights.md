# Product Task — WYN-047

Status: backlog
Owner: AI Product Manager

Feature: Data Rights — Access, Correction, Deletion, Export, Account Deletion (PDPA)

Goal: task ที่สองของ Phase 6 (Legal & Compliance Layer) — สร้างกลไกให้ผู้ใช้ใช้สิทธิ์ตามกฎหมายคุ้มครองข้อมูลส่วนบุคคล (PDPA ของไทย, Master Spec section 28: "Privacy, Data Access, Data Correction, Data Deletion, Account Deletion, Data Export") ได้จริงด้วยตัวเอง ไม่ต้องรอ Admin ทำให้ (WYN Admin ยังไม่ถูกสร้าง, Phase 7)

Target User: ผู้ใช้ทุกคนที่ต้องการเห็นข้อมูลที่ WYN เก็บเกี่ยวกับตัวเอง (Access), แก้ไขข้อมูลผิดพลาด (Correction), ลบเนื้อหา/บัญชีของตัวเอง (Deletion), หรือขอสำเนาข้อมูลออกไปใช้ที่อื่น (Export)

Problem: ยืนยันจากการอ่านโค้ดจริงทีละสิทธิ์ตาม PDPA —

**1. Data Access + Correction — มีอยู่แล้วจริง ไม่ต้องสร้างใหม่**: ผู้ใช้เห็นข้อมูลตัวเอง (Profile, Drop/Pop ของตัวเอง, Following/Followers, Saved, Notification/Privacy settings) ผ่านหน้าจอที่มีอยู่แล้วทั้งหมด — แก้ไขได้ผ่าน `EditProfileScreen` (WYN-003/013) — **แต่ไม่มีจุดรวมศูนย์ที่บอกผู้ใช้ชัดเจนว่า "นี่คือข้อมูลทั้งหมดที่ WYN เก็บเกี่ยวกับคุณ"** ตามที่ PDPA คาดหวัง (สิทธิ์ Access ต้องเข้าถึงได้ง่าย ไม่ใช่แค่กระจายอยู่หลายหน้า)

**2. Data Deletion (เนื้อหารายชิ้น) — มีอยู่แล้วจริง ไม่ต้องสร้างใหม่**: ลบ Drop ของตัวเอง (WYN-037, soft-delete + restore 30 วัน), ลบ Comment ของตัวเอง (WYN-005/006), Unfollow (WYN-008), ลบออกจาก Saved (WYN-005/006/007), ลบ Draft (WYN-036) — ครบทุกประเภทเนื้อหาหลักแล้ว

**3. Data Export — ไม่มีอยู่เลย**: ไม่มีทางใดที่ผู้ใช้จะขอสำเนาข้อมูลของตัวเองออกมาเป็นไฟล์ได้เลยแม้แต่จุดเดียว

**4. Account Deletion — ไม่มีอยู่เลย**: `AuthRepository` มีแค่ `signOut()` ไม่มี method ลบบัญชีใดๆ ไม่มี RPC ในสคีมาที่ลบ `auth.users` เลย — ผู้ใช้ที่ต้องการลบบัญชีถาวรทำไม่ได้เลยด้วยตัวเอง

Requirements:

**1. Data Export — RPC `export_my_data()` (SECURITY DEFINER) รวมข้อมูลเป็น JSON เดียว**
- ครอบคลุม: ข้อมูลโปรไฟล์ (`profiles` ของตัวเอง), Drop/Pop ที่สร้างเอง (ไม่รวมที่ถูกลบแบบ soft-delete ไปแล้วเกิน 30 วัน — เนื้อหาที่ยังกู้คืนได้นับเป็นข้อมูลของตัวเองอยู่), Comment ที่เขียนเอง (Drop/Pop/Club Post), รายชื่อ Following/Followers, รายการ Saved, Club ที่เป็นสมาชิก, การตั้งค่า Notification/Privacy (WYN-044/045), ข้อความ Chat ที่เป็นผู้ส่งเอง (WYN-031)
- **ไม่รวมโดยเจตนา (scope decision)**: ประวัติ Moderation/Report ที่เกี่ยวข้องกับตัวเอง (ทั้งที่ถูกรายงานและที่ตัวเองไปรายงานคนอื่น) — ระบบมี privacy protection เฉพาะทางอยู่แล้ว (ผู้รายงานไม่เปิดเผยตัวตนแม้แต่กับผู้ถูกรายงาน, WYN-026/029) การรวมเข้า export อาจรั่วไหลข้อมูลที่ระบบตั้งใจปกปิดไว้ — ถ้า Founder ต้องการให้ครอบคลุมสิทธิ์ Access เต็มรูปแบบ (รวมข้อมูลที่ platform เก็บเกี่ยวกับ moderation ต่อบัญชีตัวเอง ไม่ใช่ของคนอื่น) เสนอเป็น fast-follow แยก
- Output เป็น JSON string เดียว → ฝั่ง Flutter ใช้ `share_plus` (มีอยู่แล้วใน `pubspec.yaml`, ใช้ `Share.share()` แบบ text-only อยู่แล้วหลายจุด — รอบนี้ใช้ API แบบแชร์ไฟล์เพิ่มเติม) เปิด share sheet ของระบบให้ผู้ใช้เลือกบันทึก/ส่งไฟล์ JSON เอง — ไม่ต้องเขียนไฟล์ลง device storage ตรงๆ (ไม่ต้องเพิ่ม permission ใหม่)

**2. Account Deletion — RPC `delete_my_account()` (SECURITY DEFINER) ลบถาวรทันที ไม่มี grace period**
- ลบแถวใน `auth.users` ของ `auth.uid()` ตรงๆ — `on delete cascade` ที่มีอยู่แล้วทั่วทั้งสคีมา (88 จุด) จะลบข้อมูลที่เชื่อมกับ `profiles.id` ทั้งหมดโดยอัตโนมัติ (Drop/Pop/Comment/Like/Follow/Save/Chat message/Club membership/Notification/ทุกอย่าง)
- **ตัดสินใจ "ลบทันทีไม่มี grace period" (ต่างจาก Drop's 30-day soft-delete ของ WYN-037)**: เหตุผลคือไม่มี cron/scheduled-job infrastructure ในระบบเลย (ยืนยันซ้ำจากบันทึกเดิมหลายจุด เช่น WYN-030/WYN-043) การทำ "soft-delete บัญชีแล้วรอ purge อัตโนมัติหลัง 30 วัน" ต้องมีกลไกรันเป็นระยะที่ไม่มีอยู่จริง — เลือกลบจริงทันทีตามความหมายตรงตัวของ PDPA "สิทธิ์ในการลบ/ทำลายข้อมูล" แทนที่จะสร้างสถานะ "รอลบ" ที่ไม่มีอะไรมาทำให้เสร็จจริง — ถ้า Founder ต้องการ grace period ในอนาคต เสนอเป็น task แยกที่ต้องออกแบบ cron infrastructure ก่อน (เหมือนที่ WYN-043 เสนอ "Trending Notification Engine" แยกไว้ด้วยเหตุผลเดียวกัน)
- **ต้องยืนยันตัวตนก่อนลบ**: ผู้ใช้ต้องพิมพ์ข้อความยืนยัน (เช่น "ลบบัญชี") ให้ตรงก่อนปุ่มลบจะกดได้ — ป้องกันการกดพลาด เพราะเป็น action ที่ย้อนกลับไม่ได้เด็ดขาด (ไม่เหมือน Drop ที่มีทางกู้คืน)
- หลัง RPC สำเร็จ: client เรียก `signOut()` ทันที (JWT เดิมไม่มีความหมายอีกต่อไปเพราะ user row หายไปแล้ว แต่ token ที่ถืออยู่อาจยังไม่หมดอายุทางเทคนิค ต้อง sign out เชิงรุกไม่รอ) → กลับสู่ `WelcomeScreen`
- **Coding ต้องตรวจสอบว่าไม่มี orphan record หลงเหลือในตาราง `auth.*` อื่น** (เช่น `auth.identities`/`auth.sessions`/`auth.refresh_tokens`) หลัง delete `auth.users` — ถ้า Supabase's own schema ไม่ cascade ให้ครบ ต้องลบเพิ่มในฟังก์ชันเดียวกัน

**3. หน้าจอรวมศูนย์ "ข้อมูลของฉัน" (Data & Privacy) ใหม่ใน `SettingsScreen`**
- เพิ่ม section ใหม่ "ข้อมูลของฉัน" มี 2 แถว: "ดาวน์โหลดข้อมูลของฉัน" (เรียก Export) และ "ลบบัญชี" (เปิดหน้ายืนยันการลบ)
- ตำแหน่ง: ก่อน section "กฎหมาย" (WYN-046) ที่อยู่ท้ายสุด — เพราะ "ข้อมูลของฉัน" เป็น action ที่ผู้ใช้ต้องเจอบ้างเป็นครั้งคราว (บ่อยกว่าเอกสารกฎหมายที่แทบไม่มีใครกด)

Acceptance Criteria:
- [ ] ผู้ใช้กด "ดาวน์โหลดข้อมูลของฉัน" → เปิด share sheet พร้อมไฟล์ JSON ที่มีข้อมูลของตัวเองจริง (Profile/Drop/Pop/Comment/Follow/Saved/Club/Settings/Chat ที่ตัวเองส่ง)
- [ ] JSON ที่ export ไม่มีข้อมูลของผู้ใช้คนอื่นปนอยู่เลย (เช่น เนื้อหา Chat ที่คนอื่นส่งมาไม่ถูกรวม เอาแค่ที่ตัวเองเป็นผู้ส่ง)
- [ ] ผู้ใช้ A เรียก `export_my_data()`/`delete_my_account()` ไม่มีทางกระทบข้อมูล/บัญชีของผู้ใช้ B ได้เลย (RPC ผูกกับ `auth.uid()` เท่านั้น ไม่รับ parameter ให้ระบุ user อื่น)
- [ ] ผู้ใช้กด "ลบบัญชี" → ต้องพิมพ์ข้อความยืนยันให้ตรงก่อนปุ่มยืนยันจะกดได้
- [ ] ยืนยันลบสำเร็จ → บัญชีหายไปจริง (login ซ้ำด้วยเบอร์/บัญชีเดิมไม่เจอ profile เดิม), Drop/Pop/Comment ทั้งหมดของบัญชีนั้นหายไปจากทุกจุดที่เคยแสดง (Home Feed, Search, โปรไฟล์คนอื่นที่เคย Follow), ไม่มี error ที่จุดอื่นเพราะ FK ขาด (cascade ทำงานถูกต้องครบ)
- [ ] หลังลบบัญชีสำเร็จ กลับสู่ `WelcomeScreen` ทันที ไม่ค้างอยู่ในสถานะ error/session แปลกๆ
- [ ] Regression: ผู้ใช้ที่ยังไม่ได้ลบบัญชี ใช้งานทุกฟีเจอร์เดิมได้ปกติไม่มีอะไรเปลี่ยน

Dependencies: WYN-002 (Auth), WYN-003/013 (Profile, satisfies Correction), WYN-037 (soft-delete precedent, satisfies content-level Deletion), WYN-044/045 (settings ที่ export ต้องรวม)

Priority: P1 — Compliance requirement ตาม Master Spec เช่นเดียวกับ WYN-046 — ไม่ block feature อื่นเพราะยังไม่มี production จริง

Risks:
- **Account Deletion เป็น destructive operation ที่ย้อนกลับไม่ได้เด็ดขาด** — ต่างจากทุก "delete" อื่นในระบบที่มักมี soft-delete/restore window (Drop 30 วัน) เพราะไม่มี cron infra รองรับ grace period ได้จริง — ต้อง QA ทดสอบอย่างเข้มงวดเป็นพิเศษก่อนอนุมัติ (cascade ครบจริงไหม, orphan record เหลือไหม, RLS ป้องกันลบบัญชีคนอื่นได้จริงไหม)
- **ไม่มีการยืนยันตัวตนซ้ำแบบ re-authentication** (เช่น กรอกรหัสผ่าน/OTP ใหม่) ก่อนลบบัญชี — เพราะระบบ Auth ของ WYN ไม่มี password และ OTP session ที่ auth.uid() มีอยู่แล้วถือเป็นการยืนยันตัวตนที่เพียงพอในบริบทนี้ (เหมือนการลบ Drop ที่ก็ไม่ต้อง re-auth) — ใช้ typed-confirmation text แทนตามที่ระบุใน Requirement 2

Recommendation: ทำต่อเนื่องตาม roadmap Phase 6 — ส่งต่อ AI Design ออกแบบหน้า "ข้อมูลของฉัน" section ใหม่ + หน้ายืนยันลบบัญชี (typed confirmation) เน้นย้ำว่าต้องสื่อสารความเสี่ยง "ลบถาวรไม่มีทางกู้คืน" ให้ชัดเจนที่สุดในทุกจุดของ UX

Handoff: AI Design — ออกแบบ (1) section "ข้อมูลของฉัน" ใหม่ใน `SettingsScreen` ก่อน section "กฎหมาย" (2) หน้ายืนยันลบบัญชี (typed confirmation, คำเตือนชัดเจน) — ไม่ต้องออกแบบ UI สำหรับ Access/Correction/Deletion รายชิ้น (มีอยู่แล้ว)
