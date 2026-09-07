# Design Task — WYN-140

Status: **audit เสร็จ, Founder เลือกทำทั้ง 3 sub-task แล้ว (2026-09-07)** — ดู spec เต็มของแต่ละ sub-task ที่ `.wyn/tasks/active/WYN-140a-error-message-consistency.md`, `WYN-140b-skeleton-loading.md`, `WYN-140c-motion-transition.md` (ย้ายจาก backlog ไป active แล้ว ส่งต่อ AI Coding ตามลำดับ a → b → c)
Owner: AI Design
Screen: หลายหน้าจอ (audit ทั้งแอป ไม่ใช่หน้าเดียว — ดูรายละเอียดในเอกสาร audit)
Purpose: Founder ขอ "ทำเว็บแอปให้ดีสุดๆ เสถียรสุดๆ ฟีเจอครบ ไม่มีบัค เหมือนแพลตฟอร์มใหญ่ๆ" (2026-09-07) — งานนี้คือส่วนที่อยู่ในขอบเขต AI Design จริง (perceived quality ผ่าน UX/UI) หลังแยกส่วนที่เป็นหน้าที่ role อื่นออกไปแล้ว (บัค → QA/Debug, เสถียรภาพ → DevOps, ฟีเจอร์ครบ → Product)
User Flow: N/A (audit-level, ไม่ใช่ user flow เดียว)
Components: Skeleton loading state (ขยายจาก `HomeFeedSkeleton`/`ProfileSkeleton` ที่มีอยู่แล้ว), error-message utility (`errorMessageFor`), motion/transition primitives
Interactions: N/A ที่ระดับนี้ — จะลงรายละเอียดต่อ sub-task
States: Loading/Error ทั่วทั้งแอป เป็นหัวข้อหลักของ audit นี้
Responsive Behavior: ไม่เปลี่ยนจากที่มีอยู่ (ds-008 ยังใช้ได้เหมือนเดิม)
Accessibility: ไม่เปลี่ยนทิศทางจาก `design-principles.md`/ds-008 — skeleton/error ใหม่ต้องรองรับ screen reader เหมือนของเดิม
Design Rules: ห้ามใช้ shimmer animation ใน skeleton (constraint จริงจาก `pumpAndSettle()` — ดูเหตุผลเต็มในเอกสาร audit) ต้องเป็น static block เหมือน `HomeFeedSkeleton`/`ProfileSkeleton` เดิม
Handoff: รายละเอียดเต็มที่ `.wyn/docs/design/wyn-140-big-platform-polish-audit.md` — แบ่งเป็น 3 sub-task ตาม priority (WYN-140a error-message, WYN-140b skeleton loading, WYN-140c motion/transition) รอ Founder เลือกก่อนเขียน spec เต็มรูปแบบทีละตัว
