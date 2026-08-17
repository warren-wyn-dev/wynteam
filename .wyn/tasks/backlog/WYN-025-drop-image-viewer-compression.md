# Product Task — WYN-025

Status: backlog
Owner: AI Product Manager

Feature: Drop Fullscreen Image Viewer + Smart Compression

Goal: เติมเต็ม 2 จุดที่ master prompt ระบุไว้ชัดเจนแต่ยังไม่มีในระบบเลย — (1) แตะรูปใน Drop แล้วไม่มีทางดูเต็มจอ/ซูมได้ (2) รูปที่อัปโหลดใช้ค่า compression ตายตัว (`maxWidth:1600, maxHeight:1600, quality:85` ทุกภาพเท่ากันหมด) ไม่ปรับตามขนาด/ความละเอียดต้นฉบับจริงตามที่ spec ขอ

Target User: ผู้ใช้ WYN ทุกคนที่ดู/โพสต์ Drop โดยเฉพาะ Drop หลายรูป (WYN-024)

Problem: ปัจจุบันดูรูป Drop ได้แค่ขนาดที่แสดงในการ์ด/detail เท่านั้น ไม่มีทาง zoom เข้าไปดูรายละเอียด และผู้ใช้ที่อัปรูปเล็ก (เช่น 500KB) ก็โดน process/บีบเหมือนผู้ใช้ที่อัปรูปใหญ่ (20MB) ทั้งที่ไม่จำเป็น

Requirements:

R1. **Fullscreen Image Viewer**: แตะรูปใน Horizontal Row (WYN-024) → เปิด fullscreen viewer เต็มจอ รองรับ Swipe ซ้าย/ขวาดูรูปถัดไปในโพสต์เดียวกัน, Pinch-to-zoom, Double-tap zoom, ปุ่ม Close, ตัวนับรูป (เช่น "3 / 9") — ใช้ library ที่เหมาะสม (เช่น `photo_view`, ยังไม่มีในโปรเจกต์นี้ ต้องเพิ่มเป็น dependency ใหม่ — ตรวจสอบก่อนว่าไม่มีของเดิมที่ทำงานเดียวกันได้ ตามกติกา RULES.md ข้อ "ก่อนเพิ่ม Dependency ใหม่")
R2. **Dynamic Compression**: แทนที่ค่าตายตัวปัจจุบันด้วย logic ที่พิจารณาขนาดไฟล์ต้นฉบับจริงก่อนเลือกค่า compression (เช่น ไฟล์ <1MB ใช้ quality สูงแทบไม่บีบ, ไฟล์ 5-20MB บีบมากขึ้นตามสัดส่วน) — เป้าหมายคือ "ลด File Size มากที่สุดเท่าที่เหมาะสม โดยยังรักษาความคมชัด" ไม่ใช่ค่าคงที่เดียวกับทุกภาพ ยังคง flow เดิม (validate → decode → resize → crop 1:1 → compress → upload) แต่ปรับ parameter ตามขนาดต้นฉบับ
R3. **Failure handling**: ถ้ารูปใหญ่จนประมวลผลบนอุปกรณ์ไม่ไหว ต้องแสดง error ที่เข้าใจง่าย + ปุ่ม retry + cleanup temporary resource — ห้าม crash/freeze/infinite loading (ปัจจุบันยังไม่มี error path นี้เลย เป็นความเสี่ยงที่มีอยู่ก่อนแล้วแม้กับ Drop รูปเดียว)

Acceptance Criteria:
- [ ] แตะรูปใดก็ได้ใน Drop (1 รูปหรือหลายรูป) → เปิด fullscreen viewer ถูกรูปที่แตะ
- [ ] Swipe ซ้าย/ขวาเปลี่ยนรูปในโพสต์เดียวกันได้ครบทุกรูป พร้อมตัวนับอัปเดตถูกต้อง
- [ ] Pinch-to-zoom และ double-tap zoom ทำงานลื่น ไม่กระทบการปิดหน้าจอโดยไม่ตั้งใจ
- [ ] อัปโหลดรูปขนาดต่างกัน (เช่น 500KB, 5MB, 15MB) ได้ compressed file size ต่างกันตามสัดส่วนที่สมเหตุสมผล ไม่ใช่ตัวเลขเดียวกันหมด
- [ ] จำลองรูปใหญ่เกินกว่าอุปกรณ์จะประมวลผลไหว → แสดง error + retry ได้ ไม่ crash
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression

Dependencies: **WYN-024 ต้องเสร็จก่อน** (viewer ต้องรองรับหลายรูป/โพสต์)

Priority: สูง — ต่อเนื่องจาก WYN-024 โดยตรง ทำคู่กันได้ถ้า capacity พอ

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เพิ่ม dependency ใหม่ (photo_view หรือเทียบเท่า) | ต่ำ | เลือก library ที่ maintain ดี ใช้กันแพร่หลายใน Flutter ecosystem ตรวจ license ก่อนเพิ่ม |
| R2 | Dynamic compression ทำให้ upload ช้าลงถ้า logic ซับซ้อนเกินจำเป็น | ต่ำ | เริ่มจาก rule-based ง่ายๆ (ขั้นบันไดตามขนาดไฟล์ 3-4 ระดับ) ไม่ต้องทำ ML-based หรือซับซ้อนเกินความจำเป็นตามกติกา DO NOT OVERENGINEER |

Recommendation: ทำต่อจาก WYN-024 ทันที

Handoff: ส่งต่อ AI Design เพื่อเลือก/ยืนยัน image-viewer library และออกแบบ compression tiering ที่ชัดเจน แล้วส่งต่อ AI Coding
