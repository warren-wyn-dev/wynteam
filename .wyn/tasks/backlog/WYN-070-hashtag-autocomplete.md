# Product Task — WYN-070

Status: backlog
Owner: AI Product Manager

Feature: Hashtag Autocomplete ตอนพิมพ์ในหน้า Create Drop

Goal: ช่วยแนะนำ hashtag ที่มีอยู่แล้วพร้อมจำนวนโพสต์ ขณะผู้ใช้พิมพ์ `#` ใน Composer

Target User: ผู้ใช้ที่กำลังสร้าง Drop และอยากใช้ hashtag ที่คนอื่นใช้อยู่แล้ว (เพิ่มการมองเห็น)

Problem: WYN-020 (Hashtag System, ผ่าน QA แล้ว) ทำแค่ 2 อย่าง: (1) render `#hashtag` ในแคปชันที่แสดงผลแล้วให้ tap ได้ (2) หน้า Hashtag Feed (Latest/Trending) — **ไม่มี autocomplete ขณะพิมพ์ในหน้า Create Drop เลย** เป็นฟีเจอร์ใหม่ทั้งหมด ต้องต่อยอดจาก `hashtagPattern`/`extractHashtags` ที่ WYN-020 สร้างไว้แล้ว ไม่ใช่เขียน tokenizer ใหม่

Requirements:
- R1. ขณะพิมพ์ caption ใน Create Drop Composer ถ้าตรวจพบว่ากำลังพิมพ์ `#คำ` (cursor อยู่ในหรือท้าย token ที่ขึ้นต้นด้วย `#`) ให้แสดง dropdown แนะนำ hashtag ที่ตรง/ใกล้เคียง
- R2. แต่ละรายการ suggestion แสดงชื่อ hashtag เต็ม + จำนวนโพสต์ที่ใช้ (นับจาก Drop + Club post เหมือนที่ WYN-020's Hashtag Feed ทำอยู่แล้ว ผ่าน ILIKE + `extractHashtags` exact-match re-check เดิม)
- R3. เรียงตามความเกี่ยวข้อง (แนะนำ: จำนวนโพสต์มากสุดก่อน ตาม pattern เดียวกับ Trending tab ของ WYN-020)
- R4. แตะ suggestion → ใส่ hashtag เต็มลงใน caption แทนที่ token ที่พิมพ์ค้างอยู่ (ไม่ใช่ต่อท้าย) แล้วปิด dropdown
- R5. Debounce การ query (400ms ตาม pattern ที่ WYN-009 Search ใช้อยู่แล้ว) ไม่ query ทุกตัวอักษรที่พิมพ์

Acceptance Criteria:
- [ ] พิมพ์ `#` ตามด้วยตัวอักษร → dropdown suggestion ปรากฏภายใน debounce time ที่กำหนด
- [ ] Suggestion แสดงชื่อ hashtag + จำนวนโพสต์ถูกต้อง ตรงกับที่ Hashtag Feed (WYN-020) นับได้
- [ ] แตะ suggestion → hashtag ถูกแทรกเข้า caption ถูกตำแหน่ง ไม่ทำลายข้อความอื่นที่พิมพ์ไว้ก่อน/หลัง
- [ ] พิมพ์ hashtag ที่ไม่มีใครใช้มาก่อน → ไม่มี suggestion แต่ยังพิมพ์ต่อและโพสต์ได้ปกติ (ไม่ error)
- [ ] Regression: `flutter test` ผ่านครบ ไม่กระทบ Hashtag rendering/Hashtag Feed เดิมจาก WYN-020

Dependencies: ต่อยอดจาก WYN-020 โดยตรง (ใช้ `hashtagPattern`/`extractHashtags`/`DropRepository.searchByCaption`/`ClubPostRepository.searchByContent` เดิมทั้งหมด) — ไม่ต้องสร้างตาราง `hashtags` แยก (ตามการตัดสินใจเดิมของ WYN-009/WYN-020 ที่ยังไม่เปลี่ยน)

Priority: ต่ำ-กลาง — เป็น nice-to-have ที่ช่วย engagement แต่ไม่ใช่ core flow ผู้ใช้ยังพิมพ์ hashtag เองได้ปกติแม้ไม่มี autocomplete

Risks: ใช้ ILIKE query แบบเดียวกับ WYN-020 ซึ่งมี known limitation เรื่อง performance เมื่อข้อมูลโตมาก (บันทึกไว้แล้วใน WYN-020) ยิ่งเป็น query-per-keystroke (แม้มี debounce) ยิ่งเพิ่ม load ได้มากกว่า Search ปกติ — ควร cap ผลลัพธ์ (เช่น แสดงสูงสุด 5 รายการ) และพิจารณา cache ผลลัพธ์ล่าสุดไว้ระหว่าง session

Recommendation: จำกัด suggestion ไว้ 5 รายการ และ query เฉพาะเมื่อพิมพ์อย่างน้อย 1 ตัวอักษรหลัง `#` (ไม่ query ตอนพิมพ์แค่ `#` เปล่าๆ ซึ่งจะคืนผลลัพธ์กว้างเกินไปและ query หนักที่สุด)

Handoff: AI Design ออกแบบตำแหน่ง/สไตล์ dropdown (ลอยเหนือ keyboard, ไม่บัง input field) ให้ตรง Design Language เดิม ก่อนส่ง AI Coding
