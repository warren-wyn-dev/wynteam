# Product Task — WYN-048

Status: backlog
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
