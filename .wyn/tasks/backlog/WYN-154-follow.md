# Design Task — WYN-154

Status: backlog
Owner: AI Design
Screen: Follow (follow_list, follow_request_list, close_friends, exclude_friends)
Purpose: รีสกิน 4 หน้าจอกลุ่ม Follow (ผู้ติดตาม/กำลังติดตาม, คำขอติดตาม, เพื่อนที่สนิท, เลือกเพื่อนที่จะซ่อน) ด้วย Flare visual identity ใหม่ทั้งหมด โดยไม่เปลี่ยน functional requirement เดิม (audience/privacy ตาม wyn-097-099)
User Flow: ดูรายชื่อผู้ติดตาม/กำลังติดตาม พร้อมค้นหา+กด follow ได้ทันที, จัดการคำขอติดตาม (ยอมรับ/ปฏิเสธ), เปิด/ปิดรายชื่อเพื่อนที่สนิทแบบถาวร, เลือกเพื่อนที่จะซ่อนโพสต์เป็นรายโพสต์
Components: Top App Bar, Segmented Tab (ประกอบจาก token), Search Bar, List Item, Avatar, Primary/Secondary/Text Button, Switch (adaptive, สี accent), Checkbox (กำหนดรูปแบบใหม่), Modal, Toast, Loading/Skeleton, Empty State
Interactions: ดูรายละเอียดในเอกสาร
States: ดูรายละเอียดในเอกสาร
Responsive Behavior: ดูรายละเอียดในเอกสาร
Accessibility: ดูรายละเอียดในเอกสาร
Design Rules: ดูรายละเอียดทั้งหมดใน `.wyn/docs/design/wyn-154-follow.md`
Handoff: รอ Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding
