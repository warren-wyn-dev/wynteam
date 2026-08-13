# Improvements Log

ข้อเสนอปรับปรุงกระบวนการ/เอกสาร/เครื่องมือที่ระบุจาก retrospective

## รูปแบบ

```
### [YYYY-MM-DD] ข้อเสนอ
- ปัญหาที่พบ:
- ข้อเสนอ:
- สถานะ: เสนอ / นำไปใช้แล้ว / ปฏิเสธ
```

## รายการ

### [2026-08-13] ทำให้ `AuthRepository` inject ได้เพื่อเขียน regression test ครอบคลุม navigation/backend behavior
- ปัญหาที่พบ: `AuthGate` สร้าง `AuthRepository(Supabase.instance.client)` เองภายใน constructor ทำให้เขียน widget test ที่ครอบคลุม auth-state-driven navigation (เช่น pop-back หลัง sign-in, หรือ setUsername race condition) ไม่ได้เลยถ้าไม่มี Supabase project จริงเชื่อมต่อ ระหว่างแก้บั๊ก WYN-002 จึงเขียน regression test ได้แค่ 1 ใน 3 ปัญหา (ดู `.wyn/learning/MISTAKES.md`)
- ข้อเสนอ: เพิ่ม constructor parameter ให้ `AuthGate` รับ `AuthRepository` จากภายนอกได้ (dependency injection) และพิจารณาทำ interface/abstract class ให้ `AuthRepository` เพื่อสร้าง fake implementation สำหรับ test ได้โดยไม่ต้องพึ่ง Supabase จริง
- **อัปเดต [2026-08-13] — ยกระดับความสำคัญเป็นสูง**: ช่องว่างนี้ทำให้เกิด regression จริงแล้ว — การแก้บั๊ก Critical รอบ 1 ของ WYN-002 (navigation หลัง sign-in) เอง introduce บั๊ก Critical ใหม่ (logout ไม่ได้สำหรับผู้ใช้ใหม่) ที่ QA รอบ 2 ถึงจะจับได้ ไม่มี automated test ไหนจับได้เลยเพราะช่องว่างนี้เป๊ะ ๆ ควรทำก่อนเริ่ม feature ถัดไปที่แตะ auth flow (เช่น Profile, Feed) ไม่ใช่แค่ "เสนอ" เฉย ๆ
- สถานะ: เสนอ (priority สูง)
