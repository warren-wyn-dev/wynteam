# Product Task — WYN-219

Status: active — Phase 1 (#1076), step 1 foundation (#1078) and step 3 team page (#1080) merged; not deployed. Next: foundation apply, staging QA (.wyn/docs/qa/wyn-219-admin-staging-checklist.md), step 2 per system
Owner: AI Product Manager
Feature: WYNOS Admin Control Center — Admin ควบคุมได้ทุกระบบ (Account, Social, Food, Merchant, Maps)
Goal: จัด Admin เป็นหัวข้อหลักตามระบบ แล้วแยกสิทธิ์ admin ตามระบบ
Target User: ทีมดูแลระบบ WYNOS (super admin, admin ของแต่ละระบบ, moderator)
Problem: Sidebar ของ Admin เป็นรายการเดียวไม่แบ่งตามระบบ, Maps ซ่อนอยู่ใต้ Food และสิทธิ์มีแค่ admin/moderator
Requirements: ดู `.wyn/docs/product/wyn-219-admin-control-center.md`
Acceptance Criteria: ดู spec (Phase 1 และ Phase 2)
Dependencies: Phase 2 ต้องมี architecture proposal ที่ Founder อนุมัติ (authorization change)
Priority: P0 (Phase 1–2), P1 (Phase 3+)
Risks: privilege escalation / admin lockout ใน Phase 2; ลิงก์ `/food/places` เดิม
Recommendation: ทำ Phase 1 ก่อน (ไม่แตะสิทธิ์/DB) แล้วค่อยออกแบบ Phase 2
Handoff: Phase 1 approved (2026-10-10) and implemented in `admin/` (grouped sidebar, `/maps/places`, `/food/places` redirect, moderator-hidden Orders/Ads, child-route active state). Checks: admin lint + typegen + tsc pass; local visual check at 1280px and 390px for admin and moderator. Next: QA & Security → CTO final review → staging → Founder approval → production. Phase 2 needs the moderator answer and an Architect authorization proposal.
