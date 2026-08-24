# Product Task — WYN-048

Status: approved (Independent QA FAIL รอบแรก — พบช่องโหว่ Major, แก้ทันทีเป็น fast-follow — ดูหัวข้อ "Independent QA" ท้ายไฟล์ — ส่งต่อ AI Deploy & DevOps)
Owner: AI Product Manager

Feature: Consent Management (confirm satisfied) + Audit Log Foundation + Security Incident Workflow (runbook)

Goal: task สุดท้ายของ Phase 6 (Legal & Compliance Layer) — ปิด 3 หัวข้อที่เหลือของ Master Spec section 28: "Consent Management, ..., Security Incident Workflow, ..., Audit Log"

Target User: Founder/ทีมงาน (ต้องมี audit trail เพื่อตรวจสอบย้อนหลังและมี runbook พร้อมใช้ถ้าเกิดเหตุจริง) และผู้ใช้ทุกคน (ได้รับประโยชน์ทางอ้อมจากระบบที่ตรวจสอบได้และมีกระบวนการรับมือเหตุการณ์ชัดเจน)

Problem: ยืนยันจากการอ่านโค้ดจริงทีละหัวข้อ —

**1. Consent Management — ตรวจสอบแล้วว่ามีกลไกอยู่แล้วจริง ไม่ต้องสร้างใหม่**: WYN-046 (`user_document_acceptances`) คือกลไก consent tracking ที่มีเวอร์ชัน/timestamp ต่อเอกสารอยู่แล้ว, WYN-044/045 (Notification/Privacy permission toggles) คือ consent ต่อการประมวลผลข้อมูลเชิงพฤติกรรมที่ผู้ใช้ควบคุมได้ — WYN ไม่มี consent ประเภทอื่นที่ต้องขอเพิ่ม (ไม่มี Marketing communication, ไม่มี Analytics tracking แยกที่ต้องขอ opt-in, ไม่มี Third-party data sharing) ตาม feature ที่มีอยู่จริงตอนนี้ — ถ้าในอนาคตมี feature ใหม่ที่ต้องขอ consent เพิ่ม (เช่น Push Notification permission ของ OS เอง ซึ่งเป็นกลไกของระบบปฏิบัติการอยู่แล้วไม่ใช่ของ WYN) ให้ต่อยอด pattern เดียวกับ `user_document_acceptances`

**2. Audit Log — ไม่มีอยู่เลย**: Action ที่มีสิทธิ์สูง (moderation action, การตัดสินอุทธรณ์, ประกาศจาก admin, การลบ/export บัญชีตัวเอง) ไม่มีที่ไหนบันทึกไว้แบบรวมศูนย์เลย — `moderation_actions`/`appeals` เก็บแค่ข้อมูลเฉพาะโดเมนตัวเอง ไม่ใช่ audit trail ทั่วระบบ และที่สำคัญ **`moderation_actions.target_user_id`/`appeals`'s FK เป็น `on delete cascade`** — ถ้าผู้ใช้ที่เคยถูก sanction ลบบัญชีตัวเองสำเร็จ (เช่น Suspend ที่หมดอายุแล้ว) ประวัติ moderation ต่อคนนั้นจะหายไปพร้อมบัญชีทันที ไม่มีร่องรอยเหลือให้ตรวจสอบย้อนหลังเลย

**3. Security Incident Workflow — ไม่มีอยู่เลย**: ไม่มีเอกสาร/กระบวนการใดๆ ที่นิยามว่าทีมจะทำอะไรถ้าเกิดเหตุการณ์ด้านความปลอดภัยจริง (เช่น พบช่องโหว่ที่ถูกโจมตีแล้ว, ข้อมูลผู้ใช้รั่วไหล, บัญชี admin ถูกยึด)

Requirements:

**1. Consent Management — ไม่มี requirement ใหม่**, บันทึกในเอกสารนี้ว่าครอบคลุมแล้วผ่าน WYN-044/045/046 ตามที่ระบุใน Problem

**2. ตาราง `audit_log` ใหม่ — append-only, บันทึกทุก action สิทธิ์สูงที่มีอยู่แล้ว 5 จุด**
- คอลัมน์: `id uuid`, `actor_id uuid` (**ไม่มี FK/cascade ไปยัง `profiles`** — เป็นการตัดสินใจสถาปัตยกรรมที่สำคัญที่สุดของ task นี้ ดูเหตุผลด้านล่าง), `actor_username_snapshot text` (username ของ actor ณ เวลาที่บันทึก เก็บแบบ denormalized เพื่อให้ log ยังอ่านรู้เรื่องได้แม้บัญชี actor จะถูกลบไปแล้วภายหลัง), `event_type text check (in ('moderation_action_applied', 'appeal_decided', 'system_notification_sent', 'account_deleted', 'data_exported'))`, `target_id uuid` (nullable, ไม่มี FK เช่นกัน — polymorphic ตาม `event_type` มิเรอร์ pattern `reports.target_id` ของ WYN-026), `detail jsonb`, `created_at timestamptz not null default now()`
- **เหตุผลที่ `actor_id`/`target_id` ต้องไม่มี `on delete cascade`**: Audit log มีไว้เพื่อ "จำ" แม้ต้นตอจะหายไปแล้ว — ถ้าผูก cascade ไว้ ทันทีที่มีการลบบัญชี (ไม่ว่าจะโดย WYN-047's self-deletion หรือในอนาคตโดย Admin) log ที่บันทึกเหตุการณ์การลบนั้นเองจะหายไปพร้อมกัน ทำให้ audit log ไม่มีความหมายในจุดที่สำคัญที่สุด (การลบบัญชี/การกระทำต่อบัญชีที่มีปัญหา) — ตรงข้ามกับทุกตารางอื่นในสคีมาที่ cascade เป็น pattern มาตรฐาน จุดนี้ต้อง**ไม่ตาม pattern เดิม**โดยเจตนา
- RLS: **ไม่มี select/insert/update/delete policy ให้ client role ใดๆ เลยแม้แต่ admin/moderator** — ยังไม่มีหน้า Admin (Phase 7, WYN-054 จะสร้างหน้าดู Audit Log ต่อยอดจากตารางนี้) การเปิดให้ client อ่านตอนนี้จะทำก่อนมี access control ที่ออกแบบมาเฉพาะ (เช่น เฉพาะ admin เห็นได้ ไม่ใช่ moderator) — insert เกิดจาก SECURITY DEFINER function เท่านั้น (bypass RLS แบบเดียวกับ notify_* triggers)
- helper function `internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb)` (SECURITY DEFINER) — เรียกจากภายใน 5 ฟังก์ชันที่มีอยู่แล้ว: `apply_moderation_action()`, `decide_appeal()`, `send_system_notification()` (WYN-043), `delete_my_account()`, `export_my_data()` (ทั้งคู่ WYN-047) — เพิ่ม 1 บรรทัดเรียก helper นี้ท้ายแต่ละฟังก์ชัน ไม่แก้ logic เดิมของฟังก์ชันเหล่านั้นเลย

**3. Security Incident Response Runbook — เอกสาร ไม่ใช่โค้ด**
- สร้าง `.wyn/docs/security/incident-response-runbook.md` นิยามขั้นตอนเมื่อเกิดเหตุการณ์ด้านความปลอดภัยจริง: ตรวจพบ (Detect) → ควบคุมความเสียหาย (Contain) → ประเมินผลกระทบ (Assess, ใช้ `audit_log` เป็นเครื่องมือหลักในการตรวจสอบย้อนหลัง) → แจ้งผู้เกี่ยวข้อง (Notify — Founder เสมอ, ผู้ใช้ที่ได้รับผลกระทบถ้าจำเป็นตามกฎหมาย) → แก้ไข (Remediate) → สรุปบทเรียน (Post-mortem, บันทึกที่ `.wyn/learning/`)
- **เหตุผลที่เป็นเอกสารไม่ใช่ฟีเจอร์**: ยังไม่มี production/ผู้ใช้จริง (Readiness Gate เดิมยังไม่ผ่าน) ยังไม่มี Admin panel ให้ตรวจสอบ/ตอบสนองแบบ real-time (Phase 7) — การสร้างกระบวนการที่ทำได้จริงตอนนี้คือเอกสารที่พร้อมใช้ทันทีที่มีเหตุการณ์จริง ไม่ใช่ automation ที่ไม่มี trigger ให้ใช้งาน (เหตุผลเดียวกับที่ WYN-043 เลื่อน Trending notification engine ออกเพราะไม่มี cron)

Acceptance Criteria:
- [ ] Admin เรียก `apply_moderation_action()` → เกิดแถวใหม่ใน `audit_log` (`event_type = 'moderation_action_applied'`)
- [ ] Moderator เรียก `decide_appeal()` → เกิดแถวใหม่ (`event_type = 'appeal_decided'`)
- [ ] Admin เรียก `send_system_notification()` → เกิดแถวใหม่ (`event_type = 'system_notification_sent'`)
- [ ] ผู้ใช้เรียก `delete_my_account()` สำเร็จ → เกิดแถวใหม่ (`event_type = 'account_deleted'`) **และแถวนี้ยังอยู่หลังบัญชีถูกลบไปแล้ว** (พิสูจน์ว่าไม่ cascade จริง — จุดสำคัญที่สุดของ task นี้)
- [ ] ผู้ใช้เรียก `export_my_data()` สำเร็จ → เกิดแถวใหม่ (`event_type = 'data_exported'`)
- [ ] ไม่มี client role ใดๆ (`user`/`moderator`/`admin`) อ่าน/เขียน `audit_log` โดยตรงได้เลย (RLS probe)
- [ ] `actor_username_snapshot` ของแถวที่บันทึกไว้ก่อนบัญชี actor ถูกลบ ยังอ่านชื่อได้ถูกต้องแม้ query `profiles` ของ actor คนนั้นจะไม่เจอแถวแล้ว
- [ ] Regression: ทั้ง 5 ฟังก์ชันเดิมยังทำงานถูกต้องทุกประการ (SQL regression suite เดิมทั้งหมดต้องผ่าน) — การเพิ่ม audit logging ต้องไม่เปลี่ยนพฤติกรรมเดิมแม้แต่นิดเดียว

Dependencies: WYN-026/029/030 (`reports`/`moderation_actions`/`appeals`), WYN-043 (`send_system_notification`), WYN-047 (`delete_my_account`/`export_my_data`)

Priority: P2 — เป็นงาน foundation ที่ไม่กระทบผู้ใช้โดยตรง (ไม่มี UI ใหม่) แต่ปิด Master Spec requirement และเตรียมฐานให้ WYN-054 (Admin's Audit Log UI, Phase 7) ต่อยอดได้ทันที

Risks:
- **`audit_log` ไม่มี UI ให้ดูเลยในรอบนี้** (ต้องรอ WYN-054) — ข้อมูลถูกบันทึกไว้จริงแต่เข้าถึงได้แค่ผ่าน SQL โดยตรงเท่านั้นตอนนี้ (Founder ผ่าน Supabase SQL editor) จนกว่าจะมี Admin panel — ยอมรับได้เพราะเป้าหมายของ task นี้คือ "foundation" ไม่ใช่ feature ที่ใช้งานได้ครบวงจร
- **การไม่มี cascade ทำให้ `audit_log` โตขึ้นเรื่อยๆ ไม่มีกลไก cleanup** — ตั้งใจ (audit trail ต้องไม่ถูกลบทิ้งเอง) แต่ถ้าข้อมูลโตมากในอนาคต Founder อาจต้องมีนโยบาย retention แยกต่างหาก (ไม่ใช่สโคปตอนนี้)

Recommendation: ทำต่อเนื่องปิด Phase 6 ให้ครบ — ส่งต่อ AI Design (ไม่มี UI ใหม่ ข้ามไป AI Coding ได้เลยตามที่จะระบุใน Handoff)

Handoff: AI Coding — ไม่มี UI ใหม่ในรอบนี้ ข้ามขั้นตอน AI Design ได้ (ยืนยันกับ Product แล้วว่าไม่มีอะไรให้ออกแบบ) เริ่มจาก SQL ตาราง `audit_log` + helper + wiring เข้า 5 ฟังก์ชันเดิม ตามด้วยเอกสาร runbook

## Coding Output (2026-08-24)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-047 ท้ายไฟล์): ตาราง `audit_log` (append-only, **ไม่มี FK/cascade ที่ `actor_id`/`target_id` เลยโดยเจตนา** — ตรงข้ามกับทุกตารางอื่นในสคีมา เพื่อให้ log รอดจากการลบบัญชีที่มันบันทึกไว้ได้จริง, RLS เปิดแต่**ไม่มี policy ให้ role ไหนเลยแม้แต่ admin/moderator**) + `internal.log_audit_event()` (SECURITY DEFINER, ไม่ grant ให้ authenticated เพราะรับ parameter ที่ caller กำหนดได้) — wire เข้า 5 ฟังก์ชันเดิมที่ approved แล้ว (`apply_moderation_action`/`decide_appeal`/`send_system_notification`/`delete_my_account`/`export_my_data`) เพิ่มแค่ 1 บรรทัดต่อจุดไม่แตะ logic เดิม — **จุดสำคัญที่สุด**: `delete_my_account()` log ก่อนลบ (จับ username ตอนยังมีชีวิตอยู่), `send_system_notification()` log เฉพาะกรณีที่ preference อนุญาตให้ส่งจริง (ไม่ log ถ้าถูก gate โดย WYN-044) — **พบและแก้ gotcha เอง**: `export_my_data()` ต้องเปลี่ยนจาก `language sql`/`stable` เป็น `plpgsql`/`volatile` เพราะ SQL function resolve forward reference ตอน CREATE FUNCTION ทันที (พิสูจน์ empirically จริงกับ Postgres) ต่างจาก plpgsql ที่ defer ไปตอนเรียกใช้จริง

**SQL test ใหม่** (`supabase/tests/wyn_048_audit_log_test.sh`) — 28 checks ครอบ: ทั้ง 5 ฟังก์ชันสร้างแถว audit_log ถูกต้องครบ (รวมกรณี opt-out ไม่สร้างแถว), **แถว `account_deleted` รอดจากการลบบัญชีจริง** (ยืนยันหลัง `profiles`/`auth.users` ไม่มีแถวแล้ว `audit_log` ยังอยู่พร้อม `actor_username_snapshot` ถูกต้อง — จุดสำคัญที่สุดของ task นี้), ไม่มี role ไหน (`user`/`moderator`/`admin`) เข้าถึง `audit_log` โดยตรงได้เลย — **28/28 PASS** (ยืนยันรันซ้ำเองอิสระ) — รันซ้ำ SQL regression ทั้ง 21 สคริปต์ **ผ่านหมดไม่มี cross-task regression แม้แต่จุดเดียวใน 5 ฟังก์ชันที่แก้** (ยืนยันรันซ้ำเองอิสระ — สำคัญเป็นพิเศษเพราะแก้ฟังก์ชันที่ approved แล้ว) — `check_schema_ordering.py` ผ่าน

**เอกสาร**: `.wyn/docs/security/incident-response-runbook.md` ใหม่ — Detect → Contain → Assess (ใช้ `audit_log` เป็นเครื่องมือหลัก พร้อมตัวอย่าง SQL query จริง) → Notify → Remediate → Post-mortem — ระบุข้อจำกัดตรงไปตรงมา (ไม่มี monitoring/alerting, `audit_log` ครอบแค่ 5 event ไม่รวม login/session)

**ไม่มี Flutter/UI เปลี่ยนแปลงเลยในรอบนี้** ตามที่ Product ระบุไว้

**Build/Tests (ยืนยันโดย orchestrator หลัง merge เข้า main checkout)**: SQL 21/21 สคริปต์ผ่านหมด, `check_schema_ordering.py` ผ่าน — ไม่มี Flutter test เพราะไม่มีไฟล์ Flutter เปลี่ยนแปลง

**Known Issue/Gap (ตั้งใจ ไม่ใช่บั๊ก)**: `audit_log` ยังไม่มี UI ให้ดู (รอ WYN-054, Phase 7), ไม่มีนโยบาย retention/cleanup (audit trail ต้องไม่ถูกลบทิ้งเอง)

Handoff: AI QA & Security — เน้นตรวจ: **(ก) RLS ของ `audit_log` ปิดสนิทจริงทุก role** รวม admin/moderator, **(ข) แถว `account_deleted` รอดจากการลบจริง** (ตรวจซ้ำอิสระ ไม่เชื่อ CHECK12-13 เดิมอย่างเดียว), **(ค) พฤติกรรมเดิมของ 5 ฟังก์ชันที่แก้ไม่เปลี่ยนแปลงแม้แต่นิดเดียว** (รัน `wyn_029`/`wyn_030`/`wyn_043`/`wyn_047` ทั้งหมดอิสระ), **(ง) อ่าน runbook ประเมินว่าใช้งานได้จริงไหมถ้าเกิดเหตุจริง**

## Independent QA (2026-08-24) — รอบแรก FAIL, แก้ทันทีเป็น fast-follow

```
Feature: WYN-048 Audit Log Foundation + Security Incident Runbook
Environment: PostgreSQL 16 local, branch claude/wyn-044-0saj5u @ af0529d

Test Cases: SQL 21 สคริปต์ทั้งหมดอิสระ (เน้น wyn_029/030/043/047 เพราะเป็น 5 ฟังก์ชันที่แก้), check_schema_ordering.py, **อ่าน diff ทั้ง 5 ฟังก์ชันทีละบรรทัด** ยืนยันมีแค่ audit-log call เพิ่มเข้าไปไม่มี logic อื่นเปลี่ยน (รวม `export_my_data()`'s language sql→plpgsql conversion ยืนยันเนื้อหา query เหมือนเดิม 100%), reproduce "account_deleted row รอดจากการลบ" เองอิสระตั้งแต่ต้น, RLS adversarial probe บน `audit_log` ทุก role, **ตรวจ grant/exposure ของ `internal.log_audit_event()`** (จุดที่ระบุไว้ตรงๆ ในโจทย์ให้มิเรอร์ WYN-044's finding), `send_system_notification()`'s conditional logging, อ่าน runbook ประเมิน practical usability

Passed: SQL 21/21 สคริปต์ผ่านหมดไม่มี regression บน 5 ฟังก์ชันเดิม, diff review ยืนยันสะอาด, account-deletion-survives ยืนยันจริง, RLS ของ `audit_log` เองปิดสนิททุก role, `send_system_notification()`'s conditional logging ถูกต้อง, runbook ใช้งานได้จริง

Failed: **`internal.log_audit_event()` เรียกตรงได้โดย authenticated ธรรมดา** — Coding Output อ้างว่า "ไม่ grant ให้ authenticated" แต่ไม่มี `revoke execute ... from public` จริง (ช่องโหว่คลาสเดียวกับ WYN-044 round 1 เป๊ะ ที่มี fix อยู่ในไฟล์เดียวกันเป็นตัวอย่างอยู่แล้วแต่ไม่ถูกนำมาใช้กับฟังก์ชันใหม่นี้) — พิสูจน์ exploit จริง: authenticated user เรียกตรงแล้ว insert แถวปลอมลง `audit_log` ได้สำเร็จ (เช่น สร้างแถว `account_deleted` ปลอมให้คนอื่น) — ยืนยัน methodology ถูกต้องด้วยการเทียบกับ `internal.notification_enabled()` ที่มี fix แล้วให้ผลตรงข้าม

Severity: Major (Security)

Recommendation: แก้ทันที (เพิ่ม revoke + regression test) ไม่ต้องรอ QA รอบใหม่เพราะเป็น one-line schema fix ความเสี่ยงต่ำไม่ใช่ architecture change

Final Status: FAIL (รอบแรก)
```

### Fast-follow แก้ทันที (orchestrator, หลัง QA FAIL)

บันทึก bug report ที่ `.wyn/tasks/bugs/WYN-048-log-audit-event-missing-revoke.md` แล้วแก้ตรงจุด: เพิ่ม `revoke execute on function internal.log_audit_event(uuid, text, uuid, jsonb) from public;` ต่อท้ายฟังก์ชัน (มิเรอร์ fix ของ `internal.notification_enabled()` เป๊ะ) + เพิ่ม CHECK14 ใน `wyn_048_audit_log_test.sh` (มิเรอร์ `wyn_044`'s CHECK20) ยืนยัน direct call ถูกปฏิเสธ — รัน SQL ทั้ง 21 สคริปต์ซ้ำผ่านหมด ยืนยันช่องโหว่ปิดจริงและไม่มี regression

**ผลลัพธ์สุดท้าย**: **WYN-048 — PASS หลังปิดช่องโหว่ Major ด้วย fast-follow** ย้ายเข้า `.wyn/tasks/approved/` แล้ว — **Phase 6 (Legal & Compliance Layer) ปิดครบทั้ง 3 task** (WYN-046/047/048) — ขั้นต่อไปตาม roadmap คือ Phase 7 (WYN Admin, Web) เริ่มจาก WYN-049 (Admin foundation)
