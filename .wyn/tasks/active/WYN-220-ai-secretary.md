# Product Task — WYN-220

Status: active — Phase 1 foundation implemented on `feature/wyn-220-ai-secretary-foundation`; not applied, not deployed
Owner: WYN CTO (coordination) / Full-Stack Engineer (implementation)
Feature: WYNOS AI Secretary — AI executive assistant inside WYNOS Admin (admin.wynos.online/ai)
Goal: AI ที่วิเคราะห์ข้อมูลจริงของ WYNOS พร้อมแหล่งที่มา ภายใต้สิทธิ์ การตรวจสอบ และการอนุมัติ
Target User: super admin (Phase 1); admin รายระบบใน Phase 2 หลัง Founder อนุมัติ
Requirements: Founder Master Prompt (2026-10-10) · Architecture/plan: `.wyn/docs/engineering/wyn-220-ai-secretary-architecture.md`
Acceptance Criteria (Phase 1): ดู architecture doc ข้อ 6
Dependencies: WYN-219 foundation applied ก่อน; Founder approval รายการในหัว architecture doc (data sharing กับ AI provider, cost, dependency, migration apply, ผู้ใช้งาน)
Priority: P1
Risks: ส่งข้อมูลรวมไปยัง provider ภายนอก; ค่าใช้จ่าย API; prompt injection (จำกัดผลกระทบด้วย read-only tools)
Handoff: lint + tsc + next build + `npm test` (33) + `supabase/tests/wyn_220_ai_secretary_foundation_test.sh` (63) ผ่าน. ยังไม่ได้เรียกโมเดลจริงและยังไม่ E2E ในเบราว์เซอร์. Next: Founder approval → QA & Security → CTO final review → staging
