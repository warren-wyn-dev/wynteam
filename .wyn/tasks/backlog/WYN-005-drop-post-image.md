# Product Task — WYN-005

Status: backlog (รอ Founder ยืนยันคำถามเปิดใน `.wyn/docs/product/wyn-v0.1-roadmap.md` ก่อนส่งต่อ AI Design)
Owner: AI Product Manager

Feature: Drop (โพสต์รูปภาพ)

Goal: ให้ผู้ใช้โพสต์รูปภาพพร้อมแคปชัน hashtag และ mention ได้ เป็นเนื้อหาหลักประเภทแรกของ WYN V0.1 ตาม spec ใหม่ ("WYN V0.1 — CORE APP FEATURE PROMPT" ดู `.wyn/company/DECISIONS.md` 2026-08-14)

Target User: วัยรุ่น / Gen Z ที่ต้องการแชร์รูปภาพและมีปฏิสัมพันธ์กับโพสต์ของคนอื่น

Problem: หลังเปลี่ยนทิศทาง Product ใหม่ WYN ยังไม่มีฟีเจอร์โพสต์รูปภาพแบบที่ spec ใหม่ต้องการ (Feed & Post เดิมจาก WYN-004 รวมข้อความ+รูปในโพสต์เดียว ไม่ตรงกับที่ spec ใหม่ต้องการให้ Drop เป็นระบบรูปภาพโดยเฉพาะ)

Requirements:
- **สร้าง Drop**: กดปุ่ม "+ Create Drop" แล้ว:
  - เลือกรูปภาพจากอุปกรณ์ หรือถ่ายรูปใหม่
  - เขียน Caption
  - เพิ่ม Hashtag ในแคปชัน (พิมพ์ `#คำ` ระบบรู้จำ — ยังไม่ต้องทำหน้ารวมผลลัพธ์ hashtag ในรอบนี้ ผูกกับ WYN-009)
  - Mention ผู้ใช้ในแคปชัน (พิมพ์ `@username` ระบบรู้จำ — ยังไม่ต้องส่ง Notification ในรอบนี้ ผูกกับ WYN-012)
  - กด Post
- **รูปภาพ**: อัตราส่วน Square / 1:1 เป็นหลัก (ตาม spec) — crop หรือ constrain ให้เป็น 1:1 ตอนแนบรูป
- **แสดงผล Drop แต่ละอัน**: Profile picture, Username, รูปภาพ, Caption, ปุ่ม Like/Comment/Share/Save, จำนวน Like, จำนวน Comment
- **Like**: กด Like/Unlike ได้ เห็นจำนวนอัปเดตทันที
- **Comment**: เพิ่ม Comment ได้, ลบ Comment ของตัวเองได้, Like Comment ได้
- **Share**: Share Content ออกไปนอกแอป + Copy Link (ขอบเขตเบื้องต้น:ใช้ share sheet ของระบบปฏิบัติการ + generate ลิงก์ไปหน้า Drop นั้น)
- **Save**: บันทึก Drop ไว้ดูทีหลังได้ (แสดงใน Profile → Saved ที่ WYN-013 จะทำ)
- ผู้ใช้ลบ Drop ของตัวเองได้

Acceptance Criteria:
- [ ] กดปุ่ม "+ Create Drop" เลือกรูปจากอุปกรณ์หรือถ่ายใหม่ พิมพ์ caption (มี/ไม่มี hashtag/mention ก็โพสต์ได้) กด Post แล้วเห็น Drop ใหม่ปรากฏทันที
- [ ] Drop ที่ไม่มีรูปภาพ โพสต์ไม่ได้ (รูปภาพเป็น**บังคับ**สำหรับ Drop ต่างจาก Feed & Post เดิมที่เลือกได้ระหว่างข้อความ/รูป — นี่คือความแตกต่างสำคัญจาก WYN-004 ที่ AI Design/Coding ต้องรู้)
- [ ] รูปภาพแสดงเป็นสี่เหลี่ยมจัตุรัส (1:1) สม่ำเสมอทุก Drop ไม่ว่าไฟล์ต้นฉบับจะเป็นสัดส่วนใด
- [ ] กดไลก์ Drop แล้วเห็นจำนวนไลก์เพิ่มทันที กดซ้ำเพื่อเลิกไลก์ได้ (ต้องไม่มีบั๊ก double-tap แบบที่เจอใน WYN-004 QA รอบ 1 — ดู `.wyn/learning/PATTERNS.md`)
- [ ] คอมเมนต์ได้ ลบคอมเมนต์ของตัวเองได้ กด Like คอมเมนต์ได้
- [ ] กด Share เปิด share sheet ของระบบ หรือ copy ลิงก์ไปยัง clipboard ได้
- [ ] กด Save แล้วบันทึกไว้ได้ (ที่เก็บจริงไปแสดงใน Profile รอ WYN-013)
- [ ] ผู้ใช้เห็นปุ่มลบเฉพาะ Drop ของตัวเองเท่านั้น
- [ ] ผู้ใช้อื่นแก้ไข/ลบ Drop ของเราไม่ได้ (RLS บังคับ)
- [ ] ผู้ใช้อื่นลบไลก์/คอมเมนต์/save ของเราแทนเราไม่ได้ (RLS บังคับ)

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved)

Priority: P0 — สูงสุดในรอบใหม่นี้ (ดูเหตุผลเต็มที่ `.wyn/docs/product/wyn-v0.1-roadmap.md`)

Risks:
- Hashtag/Mention แบบเต็มรูปแบบ (ค้นหาได้, แตะแล้วไปหน้าที่เกี่ยวข้อง) ยังไม่ทำในรอบนี้ — ทำแค่ "parse และบันทึก" ก่อน ผูกกับ WYN-009/WYN-012 ทีหลัง ถ้า Founder ต้องการให้ครบในรอบเดียวต้องแจ้งก่อนเริ่ม Design
- Save ต้องมีที่เก็บข้อมูล (ตาราง `saves` หรือคล้ายกัน) แต่หน้าจอแสดงผล (Profile → Saved) อยู่ใน WYN-013 — ต้องออกแบบ schema ให้รองรับทั้งสอง task ตั้งแต่รอบนี้เพื่อไม่ต้อง migrate ซ้ำ
- Share ที่ "Copy Link" ต้องมี URL scheme/deep link ที่ใช้งานได้จริง — ถ้ายังไม่มี hosting/domain จริง อาจทำได้แค่ copy ข้อความ placeholder ก่อน ต้องคุยกับ Founder เรื่อง domain ก่อน Deploy จริง
- ยังไม่มี Content Moderation (นอก scope เหมือน WYN-004)

Recommendation: เริ่มที่ WYN-005 ก่อนฟีเจอร์อื่นทั้งหมดในรอบใหม่ (ดูเหตุผลที่ `.wyn/docs/product/wyn-v0.1-roadmap.md`) — แต่ก่อนส่งต่อ AI Design ต้องให้ Founder ยืนยัน 3 คำถามเปิดในเอกสารเดียวกันก่อน

Handoff: รอ Founder ยืนยันคำถามเปิด + อนุมัติขอบเขตนี้ แล้วส่งต่อ AI Design (`/design`) เพื่อออกแบบหน้าจอ Drop Feed, Create Drop, Drop Detail
