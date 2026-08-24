# Product Task — WYN-066

Status: backlog
Owner: AI Product Manager

Feature: Profile — ซ่อนแท็บ/เนื้อหา Pop ชั่วคราวใน V1.0.0 Beta

Goal: ลด Profile ให้เน้น Drop/ReDrop/ข้อมูลโปรไฟล์ตาม UX ที่ Founder ต้องการสำหรับ Beta โดยไม่ลบระบบ Pop ออกจาก codebase

Target User: ผู้ใช้ทุกคนที่เข้าดู Profile (ตัวเองหรือคนอื่น)

Problem: ตรวจ `view_profile_screen.dart` ปัจจุบันยืนยันว่า Pop เป็นหนึ่งใน TabBar หลักของ Profile (แถวเดียวกับ Drop/ReDrops) แสดงเสมอทั้งโปรไฟล์ตัวเองและคนอื่น — Founder ต้องการซ่อนออกจาก Profile ชั่วคราวสำหรับ V1.0.0 Beta โดยยังคงเก็บโค้ด/route/ตาราง DB ของ Pop ไว้ทั้งหมด (Pop Feed จาก Bottom Nav ยังใช้งานได้ปกติ — ขอบเขตนี้จำกัดเฉพาะ tab ใน Profile เท่านั้น)

Requirements:
- R1. เอาแท็บ "Pop" ออกจาก TabBar ของ Profile (`ViewProfileScreen`) ทั้งโปรไฟล์ตัวเองและคนอื่น
- R2. ไม่แสดง Pop content/section ใดๆ บนหน้า Profile อีกต่อไปในเวอร์ชันนี้
- R3. **ห้ามลบ**: โค้ด `ProfilePopGridTab`, `PopRepository`, ตาราง `pops` ใน schema, route ของ Pop Feed จาก Bottom Nav (WYN-006) ต้องคงอยู่และทำงานปกติทุกจุด — เปลี่ยนแค่การไม่ผูก `ProfilePopGridTab` เข้ากับ `TabBarView` ของ Profile เท่านั้น
- R4. `DefaultTabController(length: ...)` ต้องปรับจำนวน tab ให้ตรงกับที่เหลือจริง (ปัจจุบัน 5/3 → ต้องลดลง 1 ทั้งสองกรณี) เพื่อไม่ให้ TabBarView error

Acceptance Criteria:
- [ ] เปิด Profile (ตัวเองหรือคนอื่น) ไม่เห็นแท็บ Pop อีกต่อไป
- [ ] แท็บที่เหลือ (Drop/ReDrops/บันทึก/ร่าง) ยังทำงานถูกต้องทุกจุด ไม่มี TabController length mismatch error
- [ ] Pop Feed จาก Bottom Nav ยังคงทำงานปกติ 100% (ไม่ถูกแตะต้อง)
- [ ] โค้ด `ProfilePopGridTab`/`PopRepository` และตาราง `pops` ยังอยู่ใน codebase/schema ครบ ไม่มีการลบ

Dependencies: แก้เฉพาะ `view_profile_screen.dart` (TabBar/TabBarView/DefaultTabController length) ไม่แตะไฟล์อื่น

Priority: กลาง — เป็นการซ่อน UI ง่ายๆ ไม่ซับซ้อน แต่มีผลต่อภาพรวม UX ของ Beta ตามที่ Founder ระบุชัดเจน

Risks: ต่ำมาก — เป็นการซ่อน UI element เดียว ย้อนกลับได้ทันทีถ้าต้องการเปิด Pop กลับมาใน Profile ภายหลัง (แค่เพิ่ม Tab กลับ)

Recommendation: ทำเป็น flag/condition ง่ายๆ (เช่น `const _showPopTabInProfile = false;`) แทนการลบโค้ดส่วนนั้นทิ้ง เพื่อให้เปิดกลับมาได้เร็วในอนาคตโดยไม่ต้องเขียนใหม่

Handoff: AI Design ยืนยัน layout ของ TabBar ที่เหลือ (Drop/ReDrops/บันทึก/ร่าง) ว่ายัง balance ดีหลังลด Pop ออก ก่อนส่ง AI Coding — งานเล็ก อาจข้าม Design step แยกได้ถ้า Design เห็นว่าไม่จำเป็น
