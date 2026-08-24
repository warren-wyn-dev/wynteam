# Product Task — WYN-047

Status: approved (Independent QA PASS + 1 Major finding fixed as fast-follow — ดูหัวข้อ "Independent QA" ท้ายไฟล์ — ส่งต่อ AI Deploy & DevOps)
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

## Coding Output (2026-08-24)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-046 ท้ายไฟล์): `export_my_data()` (SECURITY DEFINER, ไม่มี parameter, ผูกกับ `auth.uid()` เท่านั้น) รวม profile/drops (เฉพาะที่ยังอยู่ในหน้าต่าง restore 30 วันของ WYN-037)/pops/comment ทั้ง 3 ประเภท/following+followers/saves/club memberships/notification settings/ข้อความแชทที่ส่งเอง — **ไม่รวม** moderation/report/appeal ตามที่ Product ล็อกสโคปไว้ — `delete_my_account()` (SECURITY DEFINER, ไม่มี parameter) ลบ `auth.users` โดยตรง cascade ผ่าน FK ที่มีอยู่แล้ว 88 จุด — Coding ตรวจสอบ stub `auth.users` ในทุก test script (17 ไฟล์) แล้วยืนยันไม่มีที่ไหนอ้างอิง `auth.identities`/`auth.sessions`/`auth.refresh_tokens` เลย สรุปว่า Supabase's managed auth schema จัดการ cascade ส่วนนั้นเอง (**ยังไม่สามารถยืนยันกับ Supabase project จริงได้เพราะยังไม่มี** — ต้อง verify อีกครั้งตอน deploy จริง)

**SQL test ใหม่** (`supabase/tests/wyn_047_data_rights_test.sh`) — **37 checks** ครอบ: `export_my_data()` scope ถูกต้อง (มีแต่ข้อมูลตัวเอง ไม่มีข้อมูลคนอื่นปนแม้แต่ที่ตัวเองเคยโต้ตอบด้วย), `delete_my_account()` ลบครบทุกตารางที่เกี่ยวข้อง (0 แถวเหลือทั้ง drops/pops/follows/saves/club_members/notification_settings/sent messages/owned club/profiles/auth.users) พร้อมยืนยัน user อื่นไม่ถูกกระทบเลย, ทั้ง 2 ฟังก์ชันไม่มี parameter จริง (`pg_get_function_arguments()`) — **37/37 PASS** (ยืนยันรันซ้ำเองอิสระ) — รันซ้ำ SQL regression ทั้ง 20 สคริปต์ **ผ่านหมดไม่มี cross-task regression** (ยืนยันรันซ้ำเองอิสระ) — `check_schema_ordering.py` ผ่าน (ยืนยันรันซ้ำเองอิสระ)

**Flutter**: `DataRightsRepository` ใหม่ (แยกจาก `AuthRepository` เพราะไม่ใช่ auth-flow concern) — `settings_screen.dart` เพิ่ม section "ข้อมูลของฉัน" ก่อน "กฎหมาย" ตรงตำแหน่งที่ Design กำหนด (แถว export เรียก RPC ตรงจาก `onTap` ไม่เปิดหน้าใหม่ + spinner ชั่วคราวใน leading icon + เปิด share sheet ด้วย `SharePlus.instance.share(ShareParams(files: [XFile.fromData(...)]))` ไม่ต้องเขียนไฟล์ลง storage) — `DeleteAccountScreen` ใหม่ตาม Design spec เป๊ะ (typed confirmation match "ลบบัญชี" หลัง trim + AlertDialog ชั้นสอง + ปุ่มสี `colorScheme.error` + ไม่มีคำว่า "กู้คืนได้" ที่ไหนเลย + sign out หลังลบสำเร็จ)

**Build/Tests (ยืนยันโดย orchestrator หลัง merge เข้า main checkout ไม่ใช่แค่เชื่อ Coding Output — ตรวจ diff ละเอียดเป็นพิเศษเพราะเป็น destructive RPC)**: `flutter analyze` **0 issues**, `flutter test` **714/714 PASS**, SQL 20/20 สคริปต์ผ่านหมด, `check_schema_ordering.py` ผ่าน — ทั้ง `export_my_data()`/`delete_my_account()` ยืนยันแล้วว่าไม่มีทาง parameter ใดๆ ให้ระบุ user อื่นได้เลย (ผูกกับ `auth.uid()` ทุกจุด)

**Known Issue/Gap (ตั้งใจ ไม่ใช่บั๊ก)**: ไม่มี grace period สำหรับ Account Deletion (ตัดสินใจแล้วใน Product spec เพราะไม่มี cron infra) — สมมติฐานเรื่อง `auth.identities`/`auth.sessions`/`auth.refresh_tokens` cascade อัตโนมัติจาก Supabase ยังไม่ได้ verify กับ Supabase project จริง (ยังไม่มี)

Handoff: AI QA & Security — **เน้นตรวจ destructive-RPC guarantees เป็นพิเศษ** ตามที่ Product's Risks ระบุไว้: **(ก) cascade ครบจริงทุกตาราง ไม่มี orphan record เหลือ** (ตรวจซ้ำอิสระ ไม่เชื่อ 37 checks เดิมอย่างเดียว), **(ข) ไม่มีทางลบ/export บัญชีคนอื่นได้เลยไม่ว่าด้วยวิธีใด** (probe adversarial เพิ่มเติม), **(ค) `export_my_data()` ไม่รั่วข้อมูลคนอื่นแม้แต่นิดเดียว** โดยเฉพาะจุดที่เกี่ยวกับการโต้ตอบข้ามบัญชี (Comment/Chat message), **(ง) UX ของ `DeleteAccountScreen` ป้องกันการกดพลาดได้จริง** (ทดสอบ near-miss ของข้อความยืนยัน)

## Independent QA (2026-08-24) — PASS + พบ 1 Major finding แก้ทันทีเป็น fast-follow

```
Feature: WYN-047 Data Rights — Export + Account Deletion
Environment: Flutter 3.47.1 (/opt/flutter), PostgreSQL 16 local, branch claude/wyn-044-0saj5u @ c3bb046 — ตรวจแบบ adversarial เข้มข้นกว่าปกติเพราะเป็น destructive RPC ที่ย้อนกลับไม่ได้

Test Cases: flutter analyze/test เต็มชุดอิสระ, SQL 20 สคริปต์ทั้งหมด, check_schema_ordering.py, **seed user ครอบ 44 หมวดข้อมูลที่เป็นเจ้าของ** (มากกว่า 37 checks เดิมมาก รวมทุกตารางที่ Product ไม่ได้ระบุด้วย เช่น drop_drafts/follow_requests/blocks/mutes/push_tokens/user_document_acceptances/moderation_actions ทั้งในฐานะเป้าหมายและผู้ตรวจ/appeals/ZOKY tables) แล้วเรียก `delete_my_account()` ยืนยันว่าง 0 แถวทุกจุด, cross-user targeting probe ทุกมุม (เรียกด้วย parameter ตรงๆ, หา overload function, ทดสอบ role anon), `export_my_data()` leak testing เจาะจงจุดโต้ตอบข้ามบัญชี (Chat สองทิศทาง, Club membership ที่ไม่ใช่เจ้าของ, Comment ปนกับ Like), UX friction testing (near-miss confirmation text ทุกรูปแบบ, AlertDialog เป็น hard gate จริง, RPC fail ไม่ sign out), export content sanity (อ่าน JSON เต็มจริง)

Passed: flutter analyze 0 issues, flutter test 714/714, SQL 20/20 สคริปต์ (wyn_047 37/37), check_schema_ordering.py OK, cascade completeness ผ่านครบ 44/44 หมวด (เกินกว่าที่ commit ไว้), cross-user targeting เป็นไปไม่ได้ทุกเส้นทาง, export ไม่รั่วข้อมูลคนอื่นแม้แต่จุดเดียว, UX friction ทำงานถูกต้องครบ

Failed: ไม่มีข้อไหนที่ตรงกับ Acceptance Criteria/checks บังคับ FAIL — แต่พบ finding ใหม่ที่ไม่มีใครคาดไว้ก่อนหน้า (ดู Security Findings ข้อ 1)

Security Findings:
1. **[Major, พบใหม่] Ban evasion ผ่าน self-account-deletion**: ผู้ใช้ที่ถูก Restrict/Suspend/Ban เรียก `delete_my_account()` ได้สำเร็จ (ไม่มี guard ใดๆ) ลบ `moderation_actions`/`appeals` ของตัวเองทิ้งไปพร้อมบัญชี (cascade จาก `profiles`, WYN-029/030) แล้วสมัครบัญชีใหม่ได้แบบไม่มีประวัติ — ไม่ใช่การละเมิด requirement ที่ระบุไว้ตรงๆ (Product ไม่เคยพูดถึง Trust & Safety ของ RPC นี้เลย) แต่เป็นความสามารถใหม่ที่ WYN-047 เปิดขึ้นมาโดยไม่มีใครคิดถึงผลกระทบด้าน Safety
2. **[Minor] `export_my_data()` ขาด Likes กับข้อมูล ZOKY/Shop**: ครบตามที่ Product's Requirement 1 ระบุทุกข้อ แต่ PDPA Access request ทั่วไปมักคาดหวัง Likes (สิ่งที่กดถูกใจ) และข้อมูล Shop (ร้าน/ตะกร้า/ออเดอร์/รีวิว — ระบบมีจริงแม้จะพักไว้) ด้วย — เสนอเป็น fast-follow แยกเหมือนที่ Product เคย exclude moderation data ไว้แล้ว
3. **[Informational, ไม่ใช่ regression]** `reports.target_id` เป็น polymorphic ไม่มี FK (WYN-026 ตั้งใจ) — report ที่คนอื่นรายงานผู้ใช้ที่ถูกลบไปแล้วเหลือ UUID ค้างที่ไม่ resolve อะไร (พฤติกรรมเดิมตั้งแต่ก่อน WYN-047 ไม่ใช่ของใหม่)
4. **[Open item]** สมมติฐาน `auth.identities`/`auth.sessions`/`auth.refresh_tokens` cascade อัตโนมัติยัง verify กับ Supabase project จริงไม่ได้ (ไม่มี) — QA ยืนยันว่า disclosure ของ Coding ตรงไปตรงมาไม่โอ้อวด — ต้อง verify ซ้ำตอน Deploy จริง

Recommendation: อนุมัติ merge/deploy-readiness — แนะนำแก้ finding #1 ก่อนหรือทันทีหลัง PASS (ไม่ต้องรอ QA รอบใหม่)

Final Status: PASS
```

### Fast-follow แก้ทันที (orchestrator, หลัง QA PASS) — ปิด finding #1 (Major)

เพิ่ม guard ใน `delete_my_account()` เรียก `internal.is_posting_blocked(auth.uid())` (ฟังก์ชันเดิมที่ใช้ gate การโพสต์/คอมเมนต์อยู่แล้วทั่วสคีมา) — ถ้าอยู่ระหว่าง Restrict/Suspend ที่ยังไม่หมดอายุ หรือถูก Ban ถาวร → `raise exception` ปฏิเสธการลบบัญชีทันที ผู้ใช้ที่ Suspend หมดอายุแล้วยังลบได้ปกติ (ไม่ใช่การลงโทษถาวรเกินจริง) — เพิ่ม CHECK38-42 ใน `wyn_047_data_rights_test.sh` (banned ลบไม่ได้ + profile ยังอยู่, suspended active ลบไม่ได้, suspended ที่หมดอายุแล้วลบได้ + profile หายจริง) — รัน SQL ทั้ง 20 สคริปต์ซ้ำผ่านหมด

**Deferred (ไม่ block, บันทึกเป็น backlog item เล็กสำหรับอนาคต)**: finding #2 (Likes/ZOKY ใน export) และ #4 (verify auth.* cascade กับ Supabase จริงตอน deploy) — ยังไม่ทำตอนนี้เพราะไม่กระทบความถูกต้อง/ความปลอดภัยของสิ่งที่ deliver แล้ว

**ผลลัพธ์สุดท้าย**: **WYN-047 — PASS + ปิด Major finding ด้วย fast-follow** ย้ายเข้า `.wyn/tasks/approved/` แล้ว — **Phase 6 เหลือ WYN-048 (Consent management, Audit log foundation, Security incident workflow) เป็น task สุดท้าย**
