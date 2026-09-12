# Design Task — WYN-145

Status: backlog
Owner: AI Design
Screen: Navigation Shell (Bottom Nav + Auth Gate)
Purpose: นิยาม visual ใหม่ (Flare) ของโครง navigation หลักที่ทุกหน้าจอ mount อยู่ข้างใน — Bottom Navigation Shell (5 tab: Home/Search/Drop/Notifications/Profile) และ Auth Gate/Splash (router ตัดสิน route ตามสถานะ login/onboarding/moderation) โดยไม่เปลี่ยน business logic/routing logic เดิม
User Flow: AuthGate ตัดสินสถานะ (blocked/session/moderation/document/onboarding) แล้วส่งต่อ RootShell → ผู้ใช้สลับ 5 tab, แตะ Drop เปิด CreateDropScreen แบบ action ไม่ใช่ tab, guest ถูก gate ที่ Drop/Notifications/Profile
Components: Bottom Tab Bar, Top App Bar, Splash/Loading
Interactions: ดูรายละเอียดในเอกสาร
States: ดูรายละเอียดในเอกสาร
Responsive Behavior: ดูรายละเอียดในเอกสาร
Accessibility: ดูรายละเอียดในเอกสาร
Design Rules: ดูรายละเอียดทั้งหมดใน `.wyn/docs/design/wyn-145-navigation-shell.md`
Handoff: รอ Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding
