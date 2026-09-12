# Design Task — WYN-144

Status: backlog
Owner: AI Design
Screen: Auth / Onboarding (7 หน้าจอ: welcome, auth_method, phone_entry, email_auth, otp_verification, redeem_invite_code, account_restricted)
Purpose: Restyle หน้าจอ Auth/Onboarding ทั้ง 7 หน้าจอของ WYNOS ให้ตรงกับ visual identity ใหม่ "Flare" (สี Coral/ink/paper, ฟอนต์ Space Grotesk + Manrope, radius มนขึ้น) โดยไม่เปลี่ยน business logic, authentication flow หรือ flag การเปิด-ปิดฟีเจอร์ที่มีอยู่เดิม (Google/Apple/Email/Phone sign-in, Guest browsing, Invite-Only Gate WYN-113, Account Restricted + Appeal WYN-029/030)
User Flow: เปิดแอปครั้งแรก (ยังไม่มี session) → Welcome → กด "เริ่มต้นใช้งาน" → Auth Method Selection (เช็ค Invite Gate ก่อนเสมอ ถ้าถูกบล็อกไป Redeem Invite Code ก่อน) → เลือกวิธีเข้าสู่ระบบ (Google / Apple / อีเมล ผ่าน Email Auth / เบอร์โทรผ่าน Phone Entry → OTP Verification / Guest) → สำเร็จแล้ว AuthGate ตรวจสถานะบัญชีก่อนเข้าแอปจริง ถ้าบัญชีถูก Suspend/Ban จะเห็น Account Restricted แทนแอปจนกว่าจะกด "ตกลง" ออกจากระบบ (มีช่องทางอุทธรณ์ถ้ามี actionId)
Components: Primary Button, Secondary Button, Text Button, Social Login Button, Text Input, OTP Input, Top App Bar, Loading/Skeleton (Spinner), Inline error/success message, Badge/Chip (BETA badge)
Interactions: ดูรายละเอียดในเอกสาร
States: ดูรายละเอียดในเอกสาร
Responsive Behavior: ดูรายละเอียดในเอกสาร
Accessibility: ดูรายละเอียดในเอกสาร
Design Rules: ดูรายละเอียดทั้งหมดใน `.wyn/docs/design/wyn-144-auth-onboarding.md`
Handoff: รอ Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding
