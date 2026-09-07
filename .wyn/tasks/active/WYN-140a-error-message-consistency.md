# Design Task — WYN-140a

Status: active — Design spec เสร็จ, พร้อมส่งต่อ AI Coding
Owner: AI Design → AI Coding
Priority: 1 ของ 3 (เร็วสุด เสี่ยงต่ำสุด)
Screen: 44 จุดทั่วแอปที่ยังใช้ข้อความ error แบบ hardcoded — ดูรายชื่อไฟล์เต็มใน spec
Purpose: ให้ผู้ใช้แยกออกว่า "เน็ตตัวเองหลุด" กับ "WYNOS มีปัญหาจริง" เป็นคนละเรื่อง — utility ที่ถูกต้อง (`errorMessageFor`) มีอยู่แล้ว แค่ยังใช้ไม่ครบ (4/49 จุด)
User Flow: [request ล้มเหลว] → catch block เดิม → เปลี่ยนจาก return ข้อความ hardcoded เป็น `errorMessageFor(error, serverMessage: '<ข้อความเดิม>')` → แสดงผลด้วย widget เดิมทุกอย่าง ไม่เปลี่ยน flow
Components: `core/network_error.dart`'s `errorMessageFor()`/`networkErrorMessage` — ไม่สร้าง component/utility ใหม่
Interactions: ไม่เปลี่ยน (ปุ่ม "ลองใหม่", ตำแหน่ง, timing เดิมทั้งหมด) — เปลี่ยนแค่ string ที่เลือกแสดง
States: Error state เดิมทุกจุดคงรูปแบบเดิมทั้งหมด — งานนี้ไม่เปลี่ยน state shape ใดๆ
Responsive Behavior: ไม่เปลี่ยน — `networkErrorMessage` สั้นกว่า/เท่ากับข้อความเดิมทุกจุด
Accessibility: ไม่เปลี่ยน — Semantics label เดิมยังใช้ได้ตรงตัว
Design Rules: ห้ามเปลี่ยนคำเดิม (`serverMessage`) — แค่เพิ่มเงื่อนไข "ถ้าเป็น network error ใช้ข้อความอื่นแทน"
Handoff: Spec เต็ม + รายชื่อ 44 ไฟล์ที่ `.wyn/docs/design/wyn-140-big-platform-polish-audit.md` (หัวข้อ "WYN-140a") — AI Coding ไล่ทีละไฟล์ รันเทสเดิมผ่านทุกไฟล์ แล้วส่ง AI QA & Security ตรวจก่อน deploy
