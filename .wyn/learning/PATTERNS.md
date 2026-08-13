# Reusable Patterns

Pattern การเขียนโค้ด/ออกแบบ/ทดสอบที่พิสูจน์แล้วว่าใช้ได้ดีใน WYN

## รูปแบบ

```
### Pattern: ชื่อ
- บริบทที่ใช้:
- รายละเอียด:
- ตัวอย่าง (ถ้ามี):
```

## รายการ

### Pattern: Callback-to-parent-rebuild แทน Navigator เมื่อ child ต้องแจ้ง auth-state gate
- บริบทที่ใช้: หน้าจอที่ auth-state gate (เช่น `AuthGate`) render โดยตรง (ไม่ได้ผ่าน `Navigator.push`) แล้วต้องการแจ้งให้ gate เปลี่ยนไปแสดงหน้าอื่นหลังทำ side effect สำเร็จ (เช่น เขียนข้อมูลลง database ที่ไม่ได้ยิง auth event)
- รายละเอียด: อย่าให้ child widget เรียก `Navigator.push`/`pushReplacement` เพื่อ "ไปหน้าถัดไป" เอง เพราะจะสร้าง route ใหม่แทนที่ route ของ gate ทำให้ gate (และ state/subscription ของมัน) ถูกทำลายทิ้งโดยไม่ตั้งใจ ให้ gate ส่ง `VoidCallback` ลงไปให้ child เรียกแทน แล้ว callback นั้นแค่ `setState(() {})` บน gate เอง เพื่อให้ gate rebuild และตัดสินใจหน้าจอใหม่ด้วยตัวเอง (เหมือนที่มันทำอยู่แล้วปกติ)
- ตัวอย่าง: `UsernameSetupScreen` (WYN-002) รับ `required VoidCallback onUsernameSet` จาก `AuthGate` เรียกหลัง `setUsername()` สำเร็จ แทนที่จะ `Navigator.pushReplacement` ไป `HomeScreen` เอง — แก้ regression Critical ที่เคยเกิดขึ้นจริงตอนใช้ Navigator (ดู `.wyn/learning/MISTAKES.md` และ `.wyn/learning/LESSONS_LEARNED.md`)
