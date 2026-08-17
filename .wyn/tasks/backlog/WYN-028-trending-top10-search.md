# Product Task — WYN-028

Status: backlog
Owner: AI Product Manager

Feature: WYN Trending Top 1-10 (ใน Search) + Recent Searches

Goal: master prompt ต้องการ "WYN Trending Top 1-10" เป็น hashtag ranking list ใน Search screen (ต่างจาก Home's Trending row ของ WYN-017 ที่เป็น content card ไม่ใช่ hashtag list) — ปัจจุบันมี Hashtag Feed (WYN-020) ที่มี Trending tab ต่อ-hashtag แต่ไม่มีหน้า/ส่วนที่รวม Top 10 hashtag ข้ามระบบมาแสดงใน Search เลย และ Search เองก็ไม่มี recent-search history

Target User: ผู้ใช้ WYN ที่เปิด Search เพื่อ discover เนื้อหา ไม่ใช่แค่ค้นหาคำเจาะจง

Problem: Search ปัจจุบัน (WYN-009) ต้องพิมพ์คำค้นก่อนถึงจะเห็นอะไร — ไม่มีทาง discover ว่าตอนนี้ hashtag ไหนกำลังนิยม และพิมพ์คำค้นซ้ำเดิมทุกครั้งเพราะไม่มี recent search

Requirements:

R1. **Trending Top 10 hashtag**: query hashtag ที่ถูกใช้บ่อยที่สุดในช่วงเวลาสั้น (นิยามเดียวกับ Hashtag Feed's Trending tab ของ WYN-020 — reuse ตรงๆ ไม่สร้าง logic ใหม่ซ้ำ) จำกัดแสดงแค่ 10 อันดับ แสดงในหน้า Search ตอนยังไม่ได้พิมพ์คำค้น (empty-query state) — แตะ hashtag ใน list → เปิด Hashtag Feed (WYN-020) ของ tag นั้น
R2. **Recent Searches**: เก็บคำค้นล่าสุดที่ผู้ใช้พิมพ์ (local device — `shared_preferences`, ยังไม่มี backend table สำหรับ search history และไม่จำเป็นต้องมีเพราะเป็นข้อมูลส่วนตัวระดับอุปกรณ์ ไม่ต้อง sync ข้ามเครื่อง) แสดงในหน้า Search ตอนยังไม่ได้พิมพ์คำค้น (ร่วมพื้นที่กับ Trending Top 10) จำกัดจำนวนที่เก็บ (เช่น 10 รายการล่าสุด) มีปุ่มลบทีละรายการ/ลบทั้งหมด
R3. ไม่ทำ Realtime rank-change indicator (↑3/↓2) เพราะไม่มี Supabase Realtime infra ในโปรเจกต์ — Top 10 คำนวณสดทุกครั้งที่เปิดหน้า Search (query-time) ไม่ใช่ push แบบ realtime

Acceptance Criteria:
- [ ] เปิด Search โดยยังไม่พิมพ์อะไร → เห็น "WYN TRENDING" list สูงสุด 10 hashtag (ไม่เกิน 10 เด็ดขาด) และ Recent Searches (ถ้ามีประวัติ)
- [ ] แตะ hashtag ใน Trending list → เปิด Hashtag Feed ของ tag นั้นถูกต้อง
- [ ] พิมพ์คำค้นและกด/เลือกผลลัพธ์ → คำนั้นถูกบันทึกใน Recent Searches (ไม่ซ้ำ, ล่าสุดอยู่บนสุด)
- [ ] ลบ Recent Search รายการเดียว/ทั้งหมดได้ ข้อมูลหายจริงจากอุปกรณ์
- [ ] Trending list ว่างเปล่า (ยังไม่มี hashtag ในระบบ) → แสดง empty state ที่เหมาะสม ไม่ error/พัง
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-009/WYN-020

Dependencies: WYN-009 (Search), WYN-020 (Hashtag + Trending tab query ที่จะ reuse)

Priority: กลาง

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Trending query (COUNT แบบ query-time ตาม WYN-020) ช้าเมื่อข้อมูลโตขึ้น | ต่ำ | เหมือนกับที่ WYN-020 ยอมรับไว้แล้วเป็น known tradeoff รอบแรก ไม่ใช่ gap ใหม่ |

Recommendation: ทำได้อิสระ ไม่ต้องรอ task อื่น

Handoff: ส่งต่อ AI Design เพื่อออกแบบตำแหน่ง/หน้าตา Trending Top 10 + Recent Searches ในหน้า Search แล้วส่งต่อ AI Coding
