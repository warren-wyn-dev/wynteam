# Product Task — WYN-046

Status: coded, awaiting QA
Owner: AI Product Manager

Feature: Platform Documents (ToS/Privacy/Community Guidelines/Copyright/Report/Appeal Policy) + Acceptance Flow

Goal: task แรกของ Phase 6 (Legal & Compliance Layer) — สร้างโครงสร้างพื้นฐานทางเทคนิคสำหรับเอกสารข้อกำหนดของแพลตฟอร์ม (Master Spec section 27) พร้อมระบบให้ผู้ใช้ยอมรับก่อนใช้งานจริง (Master Spec section 28) — **ขอบเขตจำกัดเฉพาะ "ระบบ" เท่านั้น ไม่ใช่ "เนื้อหากฎหมายจริง"** ตามที่ roadmap ระบุไว้ตรงๆ ว่า "ทีม AI ออกแบบ Compliance Layer ทางเทคนิคเท่านั้น (data flow/schema/flow) — เนื้อหาเอกสารกฎหมายจริงและการวิเคราะห์ว่า WYN เข้าข่าย DPS ประเภทไหนต้องให้ผู้เชี่ยวชาญกฎหมายตรวจสอบก่อนเผยแพร่จริง"

Target User: ผู้ใช้ทุกคนที่ต้องยอมรับข้อกำหนดก่อนใช้งาน WYN จริง (compliance requirement) และ Founder ที่ต้องมีระบบพร้อมใช้ทันทีที่ได้เอกสารฉบับผ่านการตรวจสอบจากทนายความแล้ว

Problem: ยืนยันจากการอ่านโค้ดจริง — ไม่มีระบบเอกสาร/การยอมรับข้อกำหนดใดๆ อยู่ในระบบเลย: ไม่มีตารางเก็บเอกสาร ไม่มีที่เก็บว่าใครยอมรับอะไรไปแล้วเวอร์ชันไหน ไม่มีหน้าจอใดๆ ในขั้นตอน onboarding (`AuthGate`/`WelcomeScreen`/`UsernameSetupScreen`) ที่ถามผู้ใช้เรื่องนี้เลย และ `SettingsScreen` ไม่มี section "กฎหมาย" (ตั้งใจไว้ตั้งแต่ WYN-045 ว่ายังไม่สร้างเพราะไม่มีเนื้อหาให้ใส่ — ตอนนี้ task นี้สร้างเนื้อหา placeholder ให้แล้ว จึงสร้าง section ได้จริง)

Requirements:

**1. ตาราง `platform_documents` — เก็บเอกสาร versioned 6 ประเภท**
- คอลัมน์: `id uuid`, `type text check (in ('terms_of_service', 'privacy_policy', 'community_guidelines', 'copyright_policy', 'report_policy', 'appeal_policy'))`, `version integer not null`, `title text not null`, `content text not null`, `effective_at timestamptz not null`, `created_at timestamptz not null default now()` — unique `(type, version)`
- **ไม่รวม "Future Commerce Terms"** ตามที่ Master Spec section 27 ระบุไว้ (สำหรับ WYN Shop ในอนาคต) — ZOKY/Marketplace ถูกถอดออกจาก WYN App แล้วตั้งแต่ WYN-024 (พักไว้ V2) ไม่มีอะไรให้เอกสารนี้ครอบคลุมตอนนี้
- RLS: select-all-authenticated (`using (true)`) — เอกสารข้อกำหนดต้องอ่านได้โดยทุกคนที่ล็อกอินแล้ว ไม่ใช่ข้อมูลส่วนตัว ไม่มี insert/update/delete policy ให้ client เลย (เนื้อหาเปลี่ยนผ่านการ migrate schema เท่านั้นในตอนนี้ ยังไม่มีหน้า Admin ให้แก้ไขเอง — WYN Admin เป็นระบบเบื้องหลังที่ยังไม่ถูกสร้าง Phase 7)
- **เนื้อหา (`content`) รอบนี้ต้องเป็น placeholder ที่ระบุชัดเจนว่ายังไม่ใช่ฉบับสมบูรณ์** เช่น "เอกสารฉบับนี้อยู่ระหว่างการตรวจสอบโดยผู้เชี่ยวชาญกฎหมาย ยังไม่ใช่ฉบับสมบูรณ์ที่มีผลผูกพันทางกฎหมาย — เนื้อหาฉบับเต็มจะปรับปรุงหลังผ่านการตรวจสอบ" ต่อท้ายด้วยหัวข้อโครงร่างสั้นๆ ของแต่ละประเภทเอกสาร (เช่น ToS มีหัวข้อ "การใช้งาน/บัญชีผู้ใช้/เนื้อหาที่ต้องห้าม/การยกเลิกบัญชี" แต่ไม่มีเนื้อหาเชิงกฎหมายจริงในแต่ละหัวข้อ) — **ห้ามเขียนเนื้อหากฎหมายจริงที่ฟังดูสมบูรณ์** เพราะเสี่ยงให้ Founder หรือผู้ใช้เข้าใจผิดว่าผ่านการตรวจสอบแล้ว ตรงตามที่ roadmap ระบุขอบเขตไว้ชัดเจนว่าเป็นหน้าที่ผู้เชี่ยวชาญกฎหมายเท่านั้น
- บันทึก `APPROVAL_REQUIRED` ที่ `.wyn/company/APPROVALS.md`: ต้องได้เนื้อหาจริงจากผู้เชี่ยวชาญกฎหมาย + การวิเคราะห์ว่า WYN เข้าข่าย DPS ประเภทไหน ก่อนเผยแพร่ให้ผู้ใช้จริงใช้งาน (production) แม้ระบบทางเทคนิคจะพร้อมแล้วก็ตาม

**2. ตาราง `user_document_acceptances` — บันทึกการยอมรับรายผู้ใช้**
- คอลัมน์: `user_id uuid references profiles`, `document_type text`, `version integer`, `accepted_at timestamptz not null default now()`, primary key `(user_id, document_type)` (แถวเดียวต่อ user ต่อประเภท เก็บแค่เวอร์ชันล่าสุดที่ยอมรับ — ไม่ต้องเก็บประวัติทุกเวอร์ชันในรอบนี้ เพียงพอสำหรับเช็คว่า "ยอมรับเวอร์ชันปัจจุบันหรือยัง")
- RLS: select/insert/update จำกัดเจ้าของแถวเท่านั้น (`auth.uid() = user_id`) มิเรอร์ pattern `notification_settings` (WYN-044)

**3. Acceptance Gate — บังคับยอมรับ 3 เอกสารหลักก่อนใช้งานแอป**
- **บังคับยอมรับ**: Terms of Service, Privacy Policy, Community Guidelines (3 ฉบับ) — เอกสารทั่วไปที่แอปส่วนใหญ่บังคับให้ยอมรับก่อนใช้งานจริง
- **ไม่บังคับ (อ่านอย่างเดียว ไม่มี gate)**: Copyright Policy, Report Policy, Appeal Policy — เป็นเอกสารอ้างอิงที่ผู้ใช้เข้าถึงตามบริบท (ตอน Report/Appeal) ไม่ใช่สิ่งที่ต้อง gate การใช้งานทั้งแอป (มิเรอร์ว่าแอปทั่วไปก็ไม่บังคับกดยอมรับ "Copyright Policy" แยกต่างหากจาก ToS)
- Gate ทำงานสำหรับ**ทุกบัญชีที่ล็อกอินแล้วและไม่ได้ถูกจำกัดสิทธิ์** (ไม่ใช่แค่ผู้ใช้ใหม่) — ถ้าเวอร์ชันปัจจุบันของ 3 เอกสารหลักมีอันใดที่ยังไม่เคยยอมรับ หรือยอมรับเวอร์ชันเก่ากว่าปัจจุบัน ต้องเจอหน้ายอมรับก่อนเข้าแอปเสมอ (รองรับ "อัปเดตเอกสารแล้วต้องให้ผู้ใช้เดิมยอมรับใหม่" ในอนาคตด้วยกลไกเดียวกัน ไม่ต้องแก้เพิ่ม)
- ตำแหน่งใน `AuthGate`'s decision tree: **หลัง moderation status check (Suspended/Banned ยังเจอ AccountRestrictedScreen ก่อนเหมือนเดิม ไม่ต้องยอมรับเอกสารถ้าเข้าแอปไม่ได้อยู่แล้ว) และก่อน username check** — เพราะต้องใช้ได้กับทั้งผู้ใช้ใหม่ (ยังไม่มี username) และผู้ใช้เดิม (มี username แล้วแต่เอกสารเวอร์ชันใหม่กว่า) เหมือนกัน
- กดยอมรับครั้งเดียว → insert/update ทั้ง 3 แถวใน `user_document_acceptances` พร้อมกัน (checkbox เดียว ไม่ใช่ 3 checkbox แยก — ลดแรงเสียดทาน UX เหมือนแอปทั่วไปที่รวม ToS+Privacy ไว้ในการกดยอมรับเดียว)

**4. Section "กฎหมาย" ใหม่ใน `SettingsScreen`**
- ตอนนี้สร้างได้จริงแล้วเพราะมีเนื้อหา (แม้จะเป็น placeholder) — WYN-045 ตั้งใจไม่สร้างไว้ก่อนเพราะไม่มีอะไรให้กด
- 6 แถว (ทุกประเภทเอกสาร รวมทั้ง 3 ที่ไม่บังคับ) เปิดหน้าดูเนื้อหาเอกสารปัจจุบัน — ผู้ใช้ต้องกลับมาอ่านซ้ำได้ตลอดเวลาไม่ใช่แค่ตอน onboarding

Acceptance Criteria:
- [ ] ผู้ใช้ใหม่สมัครบัญชีสำเร็จ (ยังไม่มี username) → เจอหน้ายอมรับเอกสารก่อนหน้า Username Setup
- [ ] กดยอมรับ → insert 3 แถวใน `user_document_acceptances` (ToS/Privacy/Community Guidelines) ด้วย version ปัจจุบัน → เข้าสู่ Username Setup ตามปกติ
- [ ] ผู้ใช้เดิมที่เคยยอมรับเวอร์ชัน 1 ไปแล้ว → เพิ่มเวอร์ชัน 2 ของ ToS เข้า `platform_documents` (จำลอง Founder แก้เอกสาร) → ผู้ใช้เดิมเปิดแอปครั้งถัดไป เจอหน้ายอมรับอีกครั้ง (เฉพาะจนกว่าจะกดยอมรับเวอร์ชันใหม่)
- [ ] บัญชีที่ถูก Suspend/Ban ไม่เจอหน้ายอมรับเอกสารเลย (เจอ `AccountRestrictedScreen` ก่อนเหมือนเดิม)
- [ ] ผู้ใช้เข้า Settings → "กฎหมาย" → เห็นครบ 6 เอกสาร กดดูเนื้อหาได้ทุกอันแม้จะไม่ใช่ 3 ที่บังคับยอมรับตอน onboarding
- [ ] ผู้ใช้ A ไม่มีทางเห็น/แก้ไข `user_document_acceptances` ของผู้ใช้ B ได้ (RLS probe)
- [ ] ไม่มี client ไหน insert/update/delete `platform_documents` ได้เลย (RLS probe — เนื้อหาเปลี่ยนผ่าน migration เท่านั้น)

Dependencies: WYN-002 (Auth/`AuthGate`), WYN-029/030 (moderation check ที่ gate นี้ต้องเรียงต่อจาก), WYN-045 (Settings section ที่ตั้งใจเว้นว่างไว้รอ task นี้)

Priority: P1 — Compliance requirement ที่ Master Spec ระบุว่า "ตั้งแต่ V1 ควรมีระบบรองรับ" ไม่ใช่ทำทีหลังได้ แต่**ไม่ block การพัฒนา feature อื่นทั้งหมด** เพราะยังไม่มี production/ผู้ใช้จริงอยู่ดี (Readiness Gate เดิมยังไม่ผ่าน)

Risks:
- **เนื้อหาที่ส่งมอบรอบนี้เป็น placeholder ล้วนๆ ไม่ใช่เอกสารกฎหมายที่ใช้งานได้จริง** — ห้าม deploy ให้ผู้ใช้จริงยอมรับเอกสารชุดนี้เป็นทางการจนกว่าจะมีเนื้อหาจริงจากผู้เชี่ยวชาญกฎหมายมาแทนที่ (บันทึก APPROVAL_REQUIRED แล้ว)
- **ไม่มีการวิเคราะห์ว่า WYN เข้าข่าย DPS (Digital Platform Services) ประเภทไหนตามกฎหมายไทย** — นอกเหนือขอบเขตของทีม AI ทั้งหมด ต้องรอ Founder ปรึกษาผู้เชี่ยวชาญกฎหมายแยกต่างหาก ไม่กระทบการสร้างระบบเทคนิครอบนี้
- Gate ใหม่ที่เพิ่มใน `AuthGate` เพิ่มจุดที่ต้อง query ก่อนเข้าแอปอีก 1 จุด (เหมือน moderation status check เดิม) — ความเสี่ยง fail-open ต้องออกแบบให้เหมือน moderation check (ถ้า query ล้มเหลวชั่วคราวไม่ควรล็อกทุกคนออกจากแอป) แต่ต่างจาก moderation ตรงที่นี่เป็น compliance gate ที่ "fail-closed" อาจเหมาะกว่าในทางทฤษฎี — Product ตัดสินใจให้ **fail-open เหมือนกัน** (โหลดไม่สำเร็จ → ให้เข้าแอปได้ปกติ ไม่ใช่ค้างหน้าจอ) เพราะไม่มีผู้ใช้จริงในระบบตอนนี้ที่การ fail-closed จะปกป้องอะไรจริงจัง และการล็อกทุกคนออกจากแอปเพราะ network hiccup เป็นความเสี่ยง UX ที่แย่กว่า

Recommendation: ทำต่อเนื่องตาม roadmap Phase 6 ทันที — ส่งต่อ AI Design ออกแบบหน้า Acceptance Screen + Document Viewer Screen + Settings section ใหม่ จากนั้น AI Coding implement โดยเน้นว่า**เนื้อหาเอกสารต้องเป็น placeholder ที่ระบุสถานะชัดเจนตามที่ Product กำหนด ห้าม Coding เขียนเนื้อหากฎหมายเองเพิ่มเติม**

Handoff: AI Design — ออกแบบ (1) หน้า Acceptance Screen ใหม่ (checkbox เดียว + ลิงก์เปิดอ่านแต่ละเอกสาร 3 ฉบับ + ปุ่มยอมรับ) เข้าคิวใน `AuthGate` (2) หน้า Document Viewer แบบ generic ใช้ซ้ำได้ทั้ง 6 ประเภท (3) section ใหม่ "กฎหมาย" ใน `SettingsScreen` — ไม่ต้องออกแบบเนื้อหาเอกสารเอง (Product กำหนด placeholder ไว้แล้วตาม Requirement 1)

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-045 ท้ายไฟล์): ตาราง `platform_documents` (6 ประเภทเอกสาร, select-all-authenticated, ไม่มี insert/update/delete policy ให้ client เลย) + `user_document_acceptances` (RLS มิเรอร์ `notification_settings` ของ WYN-044 เป๊ะ, PK `(user_id, document_type)` เก็บแค่เวอร์ชันล่าสุดที่ยอมรับตามที่ Product กำหนด) — seed 6 แถว version 1 ด้วย placeholder text ตามที่ Product ระบุไว้ตรงๆ คำต่อคำ (ย่อหน้าแรกเหมือนกันทุกฉบับ + โครงหัวข้อสั้นๆ ต่อประเภท ไม่มีเนื้อหากฎหมายจริง)

**SQL test ใหม่** (`supabase/tests/wyn_046_platform_documents_test.sh`) — 9 checks ครอบ: อ่านได้ครบ 6 เอกสาร, insert/update/delete ตาราง `platform_documents` ถูกปฏิเสธหมด (RLS), user สร้าง/อ่านแถวยอมรับของตัวเองได้ คนอื่นอ่าน/แก้ไม่ได้, upsert แทนที่เวอร์ชันได้จริงไม่สร้างแถวซ้ำ (พิสูจน์กลไก "อัปเดตเอกสารแล้ว re-prompt" ที่ data layer) — **9/9 PASS** (ยืนยันรันซ้ำเองอิสระ) — รันซ้ำ SQL regression ทั้ง 20 สคริปต์ (รวมของเดิมทั้งหมด) **ผ่านหมดไม่มี cross-task regression** (ยืนยันรันซ้ำเองอิสระ) — `check_schema_ordering.py` ผ่าน (ยืนยันรันซ้ำเองอิสระ)

**Flutter**: `PlatformDocumentRepository` ใหม่ (`fetchLatest`/`hasAcceptedMandatoryDocuments`/`acceptMandatoryDocuments` — 2 query รวมไม่ N+1) + `DocumentAcceptanceScreen`/`DocumentViewerScreen` ใหม่ตาม Design spec เป๊ะ — แก้ `auth_gate.dart` เพิ่ม gate ใหม่ตำแหน่งถูกต้อง (หลัง moderation check, ก่อน username check, fail-open) — แก้ `settings_screen.dart` เพิ่ม section "กฎหมาย" ท้ายสุดของหน้า unconditional ทุก role — เทสต์ใหม่ครอบ `DocumentAcceptanceScreen`/`DocumentViewerScreen`/`auth_gate_test.dart` (ยืนยัน ordering: บัญชีถูกบล็อกไม่เจอ Acceptance gate, บัญชีที่ยังไม่ยอมรับเจอก่อน Username Setup)/`settings_screen_test.dart` ต่อ

**Build/Tests (ยืนยันโดย orchestrator หลัง merge เข้า main checkout ไม่ใช่แค่เชื่อ Coding Output)**: `flutter analyze` **0 issues**, `flutter test` **699/699 PASS**, SQL 20/20 สคริปต์ผ่านหมด, `check_schema_ordering.py` ผ่าน

**Known Issue/Gap (ตั้งใจ ไม่ใช่บั๊ก)**: เนื้อหาเอกสารเป็น placeholder ล้วนๆ ตามที่ Product ล็อกสโคปไว้ (ดู APPROVAL_REQUIRED ที่ `.wyn/company/APPROVALS.md`)

Handoff: AI QA & Security — เน้นตรวจ: **(ก) ลำดับ gate ใน `AuthGate` ถูกต้อง** (Suspended/Banned ต้องเจอ `AccountRestrictedScreen` ก่อนเสมอ ไม่มีทางข้ามไปเจอ Acceptance gate), **(ข) fail-open จริงเมื่อโหลดสถานะการยอมรับล้มเหลว** (ไม่ควรล็อกผู้ใช้ออกจากแอปเพราะ network hiccup), **(ค) version bump re-prompt ทำงานจริงทั้ง data layer และ UI** (ไม่ใช่แค่เชื่อ SQL check เดียว), **(ง) ไม่มีทาง client ไหน insert/update/delete `platform_documents` ได้เลยแม้แต่ admin/moderator role** (probe adversarial เพิ่มเติมนอกเหนือ 3 checks ที่มีอยู่แล้ว), **(จ) ยืนยันเนื้อหา placeholder ไม่มีอะไรที่ดูเหมือนเนื้อหากฎหมายจริงหลุดเข้าไป**
