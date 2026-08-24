# Product Task — WYN-068

Status: backlog
Owner: AI Product Manager

Feature: แก้ไข Username (@) จากหน้า Edit Profile

Goal: ให้ผู้ใช้เปลี่ยน @username ของตัวเองได้ พร้อมตรวจสอบว่าไม่ซ้ำกับผู้ใช้อื่น

Target User: ผู้ใช้ทุกคนที่ต้องการเปลี่ยนชื่อ @ ของตัวเอง (เช่น @warren → @wynos)

Problem: ตรวจ `edit_profile_screen.dart` ปัจจุบันมีแค่ Display Name + Bio + Avatar เท่านั้น (ตาม WYN-003 เดิม) ไม่มีช่อง Username เลย และไม่พบ RPC/query สำหรับตรวจสอบ username ซ้ำหรืออัปเดต username ใน `profile_repository.dart`/schema.sql — เป็นฟีเจอร์ใหม่ทั้งหมด ไม่ใช่แก้ของเดิม

Requirements:
- R1. เพิ่มช่อง Username ใน Edit Profile แยกจาก Display Name (คนละ field กัน ตามระบบปัจจุบันที่มีทั้งสองอยู่แล้ว)
- R2. ตรวจสอบ availability แบบ real-time ขณะพิมพ์ (debounce เหมือน Search WYN-009) แสดงสถานะ Available/Unavailable ชัดเจน
- R3. Validation: รูปแบบถูกต้อง (ตัวอักษร a-z/A-Z, ตัวเลข 0-9, underscore `_` เท่านั้น), ห้ามมีช่องว่าง, ห้ามซ้ำกับผู้ใช้อื่น (case-insensitive เพื่อกัน `@WYNOS` กับ `@wynos` ซ้ำกัน), ความยาวขั้นต่ำ/สูงสุดตาม convention ทั่วไป (แนะนำ 3–20 ตัวอักษร)
- R4. บันทึก username ใหม่ผ่าน RPC ที่ตรวจซ้ำอีกครั้งฝั่ง server ก่อน update จริง (กัน race condition ระหว่างสองคนเปลี่ยนเป็นชื่อเดียวกันพร้อมกัน — ต้องมี unique constraint ระดับ DB ไม่ใช่แค่ check ฝั่ง client)
- R5. Username ใหม่ต้องอัปเดตแสดงผลทันทีทุกจุดที่อ้างอิง (Profile header, การ์ด Home, Comment, Follow list, ฯลฯ) — เนื่องจากทุกจุดใช้ query สดจาก `profiles` table เดิมอยู่แล้ว (ไม่ cache username แยก) คาดว่าจะอัปเดตอัตโนมัติโดยไม่ต้องแก้จุดอื่นเพิ่ม แต่ต้อง QA ยืนยันจริง

Acceptance Criteria:
- [ ] เปลี่ยน @username ได้จากหน้า Edit Profile
- [ ] พิมพ์ username ที่มีคนใช้แล้ว → แสดง "ไม่ว่าง"/Unavailable ชัดเจน กดบันทึกไม่ได้
- [ ] พิมพ์ username รูปแบบผิด (มีช่องว่าง/อักขระพิเศษ) → แสดง error ชัดเจน
- [ ] บันทึกสำเร็จ → username ใหม่แสดงถูกต้องทันทีในทุกหน้าที่เคยแสดง username เดิม
- [ ] ทดสอบ race condition: 2 คนพยายามเปลี่ยนเป็นชื่อเดียวกันพร้อมกัน → มีแค่คนเดียวสำเร็จ อีกคน error ชัดเจน ไม่ silent fail

Dependencies: ต้องเพิ่ม RPC ใหม่ (`is_username_available`/`update_username` หรือเทียบเท่า) ใน schema.sql — เป็นการเพิ่มของใหม่ (additive) แต่แตะ `profiles` table ที่เป็นแกนกลางของระบบ ต้องทดสอบ local ก่อน apply production เสมอ (ตามแนวทางที่ใช้แก้บั๊ก WYN-063 วันนี้)

Priority: กลาง — เป็นฟีเจอร์ที่ผู้ใช้ร้องขอชัดเจน (Founder ยกตัวอย่าง @warren → @wynos ตรงๆ) แต่ไม่ใช่ core flow ที่บล็อกการใช้งาน

Risks: username เป็น identifier ที่ใช้อ้างอิงหลายจุดในระบบ (deep link, mention ในอนาคต, share link `profileShareLink`) — เปลี่ยนแล้ว share link เก่าที่มีคนโพสต์ไว้แล้วจะใช้ไม่ได้ (เพราะ URL ปัจจุบันอิง username ไม่ใช่ user id) ต้องแจ้ง Founder ให้ทราบ trade-off นี้ชัดเจนก่อนเริ่ม Coding — ทางเลือกระยะยาวคือเปลี่ยน URL scheme ไปใช้ user id แทน แต่เกินขอบเขตงานนี้

Recommendation: เพิ่ม cooldown เตือนผู้ใช้ก่อนเปลี่ยน username ว่า "ลิงก์โปรไฟล์เดิมจะใช้ไม่ได้อีก" (dialog confirm) แทนการเปลี่ยนแบบเงียบๆ — และพิจารณาจำกัดความถี่การเปลี่ยน (เช่น เปลี่ยนได้ทุก 14 วัน) เพื่อกัน username squatting/churn แต่ปล่อยให้ Founder ตัดสินใจว่าจะเพิ่ม cooldown รอบนี้หรือทำแบบไม่จำกัดก่อน

Handoff: **ต้องขอ Founder ตัดสินใจ** ก่อนส่ง Design: (1) จะมี cooldown จำกัดความถี่เปลี่ยนหรือไม่ (2) ยอมรับ trade-off ที่ share link เก่าจะพังหรือไม่ — ถามผ่าน popup ตามกติกา RULES.md ก่อนเริ่ม Design/Coding
