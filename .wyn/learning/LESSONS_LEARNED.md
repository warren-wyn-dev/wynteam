# Lessons Learned

บทเรียนที่สะสมจากงานที่ผ่านมา เพื่อลดการทำผิดซ้ำ

## รูปแบบ

```
### [YYYY-MM-DD] หัวข้อ
- บริบท:
- บทเรียน:
- การนำไปใช้ในอนาคต:
```

## รายการ

### [2026-08-13] อย่าผสม declarative auth-state UI กับ imperative Navigator.push โดยไม่คิดเรื่อง pop
- บริบท: WYN-002 มี `AuthGate` ที่ตัดสินใจหน้าจอจาก auth state แบบ declarative (`StreamBuilder`) แต่หน้า Welcome/AuthMethod/Phone/OTP ใช้ `Navigator.push` แบบ imperative ต่อกันเป็น stack เมื่อ auth state เปลี่ยนที่ route ฐาน หน้าที่ถูก push ไว้ด้านบนไม่ถูก pop อัตโนมัติ ผู้ใช้เลยค้างอยู่หน้าเดิม
- บทเรียน: เมื่อผสม pattern การนำทางสองแบบ (state-driven ที่ route ฐาน + imperative push ด้านบน) ต้องมีจุดที่ pop กลับ route ฐานอย่างชัดเจนเมื่อ state ที่ route ฐานเปลี่ยน ไม่งั้นผู้ใช้จะไม่เห็นการเปลี่ยนแปลงเลย
- การนำไปใช้ในอนาคต: เวลาออกแบบ flow ที่มีทั้ง auth-state gate และหลายหน้าที่ push ต่อกัน ให้ AI Coding ระบุใน Implementation ชัดเจนว่าจุดไหน pop กลับ และ AI QA & Security ควรไล่ trace Navigator stack ทีละ step ไม่ใช่แค่เช็คว่า state เปลี่ยนถูกต้องหรือไม่

### [2026-08-13] Root cause ที่ QA ระบุอาจไม่ครอบคลุมทุกเส้นทางที่ทำให้เกิดบั๊กเดียวกัน
- บริบท: QA รอบแรกของ WYN-002 รายงานบั๊ก Critical เฉพาะเส้นทาง "ตั้ง username เสร็จแล้วไม่ไป Home" แต่ตอน AI Debug Engineer ไล่โค้ดจริงพบว่า root cause กว้างกว่านั้น — กระทบทุกเส้นทาง sign-in (Google/Apple/Phone OTP) ไม่ใช่แค่ username step
- บทเรียน: เวลา Debug Engineer แก้บั๊ก ต้องไล่ trace โค้ดจริงให้ครบทุกเส้นทางที่อาจโดนปัญหาเดียวกัน ไม่ใช่แก้แค่จุดที่ QA เขียน reproduction steps ไว้ตรง ๆ
- การนำไปใช้ในอนาคต: ก่อนปิดบั๊ก ให้ Debug Engineer ถามตัวเองเสมอว่า "root cause นี้กระทบเส้นทางอื่นด้วยหรือไม่" แล้วแก้ให้ครบในรอบเดียว

### [2026-08-13] แก้บั๊ก navigation ให้ไล่ trace ต่อจนถึง lifecycle ถัดไป ไม่ใช่แค่จุดที่ QA รายงาน
- บริบท: QA รอบ 1 รายงานว่า "ตั้ง username แล้วไม่ไป Home" Debug Engineer แก้ด้วย `Navigator.pushReplacement` เพื่อให้ไปถึง Home ได้จริง แต่วิธีนี้ทำให้ route ของ `AuthGate` ถูกแทนที่/ทำลายไปทั้งหมด ผลคือผู้ใช้กลุ่มเดียวกันนี้ (ผู้ใช้ใหม่) พอกด logout จาก Home แล้วกลับไป Welcome ไม่ได้อีก — เป็น regression ใหม่ที่ QA รอบ 2 เจอ
- บทเรียน: การแก้ navigation bug ที่ "ไปถึงหน้าถัดไปได้แล้ว" ไม่ได้แปลว่าจบ ต้องไล่ trace ต่อไปถึง lifecycle ถัดไปของหน้านั้นด้วยเสมอ (เช่น ถ้าหน้านั้น login ได้ ต้องเช็คว่า logout จากเส้นทางเดียวกันนี้ยังทำงานถูกต้องไหม)
- การนำไปใช้ในอนาคต: เมื่อ AI Debug Engineer แก้บั๊กที่เกี่ยวกับ Navigator/route lifecycle ให้ตรวจสอบว่า widget ที่ถูกแทนที่/ทำลายไปมีผลข้างเคียงอะไรหรือไม่ (เช่น stream subscription, state ที่ widget อื่นพึ่งพา) ก่อนปิดงาน และ AI QA & Security ควรทดสอบ full lifecycle ของทุก user segment (ผู้ใช้ใหม่ และผู้ใช้เดิม) แยกกันเสมอ ไม่ใช่แค่ segment เดียว
