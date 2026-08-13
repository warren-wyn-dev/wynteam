# Mistakes Log

บันทึกข้อผิดพลาดที่เกิดขึ้น เพื่อป้องกัน QA และทีมไม่ให้พลาดซ้ำ

## รูปแบบ

```
### [YYYY-MM-DD] Task WYN-XXX
- ข้อผิดพลาด:
- ผลกระทบ:
- วิธีป้องกันในอนาคต:
- Regression test ที่เพิ่ม (ถ้ามี):
```

## รายการ

### [2026-08-13] Task WYN-002
- ข้อผิดพลาด: (1) `AuthGate` ฟังแค่ Supabase auth-state event แต่หน้า Welcome/AuthMethod/Phone/OTP ถูก push ทับไว้ด้านบนโดยไม่มีจุด pop กลับ ทำให้ผู้ใช้ค้างหน้าเดิมหลัง sign-in สำเร็จทุกเส้นทาง (Google/Apple/Phone) ไม่ใช่แค่ตอนตั้ง username ตามที่ QA รายงานไว้ในตอนแรก (2) `setUsername()` ไม่ catch unique-constraint violation จริงจาก race condition (3) OTP input ใช้ช่องเดียวแทนที่จะเป็น 6 ช่องแยกตาม design spec
- ผลกระทบ: ผู้ใช้ทุกคนที่ sign-in สำเร็จ (ไม่ว่าวิธีไหน) จะไม่เห็นหน้าจอเปลี่ยนอัตโนมัติ ต้อง force-restart แอป — เป็น blocker ที่ทำให้ onboarding ใช้งานไม่ได้เลยถ้าไม่แก้
- วิธีป้องกันในอนาคต: เมื่อออกแบบ flow ที่มี auth-state gate ผสมกับหลายหน้า push ต่อกัน ให้ระบุจุด pop-back ชัดเจนตั้งแต่ตอน Design/Coding ไม่ใช่รอ QA มาเจอ และ AI Coding ควร inject dependency (เช่น `AuthRepository`) แบบ testable มากกว่านี้ เพื่อให้เขียน regression test ครอบคลุม navigation behavior ได้ (ตอนนี้ `AuthGate` สร้าง `AuthRepository` เองภายใน ทำให้ยังเขียน widget test สำหรับ pop-back behavior ไม่ได้)
- Regression test ที่เพิ่ม: `app/test/otp_box_input_test.dart` (4 เคส ครอบคลุมปัญหา #3 เต็มรูปแบบ) — ปัญหา #1 (pop-back) และ #2 (race condition) ยังไม่มี automated regression test เพราะสถาปัตยกรรมปัจจุบันไม่รองรับการ inject fake backend ได้ง่าย (บันทึกเป็นข้อเสนอปรับปรุงใน `.wyn/learning/IMPROVEMENTS.md`)
