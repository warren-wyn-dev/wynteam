# Design Task — WYN-072

Status: backlog
Owner: AI Design
Screen: Welcome, Auth Method Selection, Guest Mode (new)
Purpose: 1) แก้ wordmark "WYN"→"WYNOS" ในหน้า Welcome/Auth Method 2) ซ่อนปุ่ม "เข้าสู่ระบบด้วย Apple" ชั่วคราว (Apple Developer Program ยังไม่สมัคร) 3) เพิ่มทางเข้าชม WYNOS แบบไม่ล็อกอิน (guest browsing ผ่าน Anonymous Sign-In ที่มีอยู่แล้ว) — ดูโพสต์ได้ แต่หน้า/action ที่ผูกกับตัวตน (โปรไฟล์, สร้าง Drop, แจ้งเตือน, แชท, Like/Comment/Save/ReDrop/Poll vote/Follow, Club create/join) ต้องล็อกอินก่อน
User Flow: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md`
Components: ดูรายละเอียดเต็มในเอกสาร design
Interactions: ดูรายละเอียดเต็มในเอกสาร design
States: ดูรายละเอียดเต็มในเอกสาร design
Responsive Behavior: ไม่เปลี่ยนจากเดิม (ใช้ layout/component เดิมทั้งหมด)
Accessibility: Semantics label ชัดเจนบนปุ่ม guest ใหม่ + dialog gate ต้อง trap focus ตาม Material default
Design Rules: ไม่แตะสี/ฟอนต์/spacing ใดๆ จาก design-principles.md — reuse component เดิมทั้งหมด (OutlinedButton/TextButton/AlertDialog มาตรฐาน), reuse pattern `_phoneLoginEnabled` เดิมสำหรับซ่อนปุ่ม Apple, ห้ามเขียน gate dialog ซ้ำมือทีละจุด ต้องมี helper เดียวใช้ร่วมกันทั้ง 7 จุด
Handoff: ส่งต่อ AI Coding (`/code`) — ดู Handoff เต็มในเอกสาร design (3 ส่วน: auth_gate.dart เพิ่ม anonymous bypass, GuestGate helper ใหม่, dialog signOut ก่อนเปิดหน้าล็อกอินจริง) ต้องผ่าน AI QA & Security ก่อน deploy เสมอ (ห้ามข้าม QA) — แจ้ง Founder ยืนยันรายการ gate 7 จุดก่อน deploy จริง เพราะ Founder ระบุแค่ "เช่นโปรไฟล์" เป็นตัวอย่าง ส่วนที่เหลือเป็นการตีความต่อยอดของ AI Design
