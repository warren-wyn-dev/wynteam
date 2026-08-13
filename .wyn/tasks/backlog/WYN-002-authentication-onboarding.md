# Product Task — WYN-002

Status: backlog
Owner: AI Product Manager

Feature: Authentication & Onboarding

Goal: ให้ผู้ใช้ใหม่สมัคร/เข้าสู่ระบบ WYN ได้อย่างรวดเร็วและ friction ต่ำที่สุด เพื่อเป็นฐานให้ feature อื่น ๆ (Profile, Feed) ทำงานต่อได้ เนื่องจากทุก feature ต้องมี user ที่ยืนยันตัวตนแล้วก่อนเสมอ

Target User: วัยรุ่น / Gen Z ที่คุ้นเคยกับการ login ด้วย social account หรือเบอร์โทรศัพท์ ไม่คุ้นเคย/ไม่ชอบกรอก email+password

Problem: ปัจจุบัน WYN ยังไม่มี source code หรือระบบ authentication ใด ๆ ทำให้ยังไม่มี user account และ feature อื่นทั้งหมด (Profile, Feed) ยังเริ่มไม่ได้

Requirements:
- สมัครสมาชิก/เข้าสู่ระบบผ่าน **Social Login: Google และ Apple**
- สมัครสมาชิก/เข้าสู่ระบบผ่าน **Phone Number + OTP** (รองรับเบอร์ไทย)
- ไม่มี Email + Password ใน V0.1 (ลด friction ตามที่ Founder อนุมัติ)
- หลังสมัครสำเร็จครั้งแรก ต้องพาผู้ใช้เข้าสู่ขั้นตอน onboarding เบื้องต้น (อย่างน้อย: ตั้งชื่อผู้ใช้/username)
- ใช้ Supabase Auth เป็นระบบยืนยันตัวตน (ตามที่อนุมัติใน WYN-001 — Google/Apple OAuth provider + Phone OTP provider)
- Session ต้องคงอยู่ (persist) หลังปิดแอป ไม่ต้อง login ใหม่ทุกครั้ง

Acceptance Criteria:
- [ ] ผู้ใช้ใหม่กด "สมัครด้วย Google" แล้วเข้าสู่แอปได้สำเร็จภายในไม่กี่ขั้นตอน
- [ ] ผู้ใช้ใหม่กด "สมัครด้วย Apple" แล้วเข้าสู่แอปได้สำเร็จ (iOS)
- [ ] ผู้ใช้ใหม่กรอกเบอร์โทร รับ OTP ทาง SMS และยืนยันตัวตนสำเร็จ
- [ ] ผู้ใช้เดิม (เคยสมัครแล้ว) login ซ้ำด้วยวิธีเดิมแล้วเข้าระบบสำเร็จ ไม่สร้าง account ซ้ำ
- [ ] ผู้ใช้ใหม่ถูกพาไปตั้ง username ก่อนเข้าหน้าแรกของแอป
- [ ] ปิดแอปแล้วเปิดใหม่ ยังอยู่ในสถานะ login (ไม่ต้อง login ซ้ำ)
- [ ] Logout ได้ และหลัง logout เข้าหน้าที่ต้อง login ไม่ได้อีก
- [ ] ไม่มีการเก็บรหัสผ่านหรือ credential ที่อ่อนไหวไว้ใน client-side โดยไม่เข้ารหัส (ดู `.wyn/company/RULES.md`)

Dependencies: WYN-001 (Vision & Tech Stack — เสร็จแล้ว: Flutter + Supabase)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป (Profile, Feed ต้องมี user ที่ login แล้ว)

Risks:
- Apple Sign-In มีข้อกำหนดเฉพาะจาก Apple (บังคับต้องมีถ้ามี social login อื่นบน iOS) — ต้องตรวจสอบตอน implement
- Phone OTP ผ่าน SMS มีต้นทุนต่อข้อความ (Supabase ใช้ผ่าน third-party SMS provider เช่น Twilio) — ต้องแจ้ง Founder เรื่องค่าใช้จ่ายก่อน implement จริง
- Onboarding ที่ยาวเกินไปจะเพิ่ม drop-off ในกลุ่ม Gen Z ต้องออกแบบให้สั้นที่สุด (ส่งต่อให้ AI Design พิจารณา)

Recommendation: เริ่ม implement Authentication & Onboarding เป็น feature แรกของ WYN หลังจาก AI Design ออกแบบ flow/screen เสร็จ

Handoff: ส่งต่อ AI Design เพื่อออกแบบ user flow และหน้าจอ (Welcome screen, Social login buttons, Phone OTP input, Username setup) ก่อนส่งต่อ AI Coding — เรียกด้วย `/design`
