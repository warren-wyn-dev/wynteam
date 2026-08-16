# Product Task — WYN-020

Status: backlog
Owner: AI Product Manager

Feature: Hashtag System — tappable #hashtag + Hashtag Feed screen (Latest/Trending)

Goal: ทำให้ #hashtag ใน caption ของ Drop/Club post กดได้จริง เปิดหน้า Hashtag Feed แสดงโพสต์ทั้งหมดที่ใช้ hashtag นั้น พร้อม Latest/Trending tab ตามที่ spec ข้อ 3 ระบุ

Target User: ผู้ใช้ WYN Social ที่อยากค้นหา/ติดตาม content ตาม topic (#WYN #มหาสารคาม ฯลฯ)

Problem: WYN-009 (Search) ตัดสินใจ defer hashtag entity system ไปแล้ว ใช้แค่ caption ILIKE substring search แทน — วิธีนี้หาโพสต์ที่ "มีคำนั้นอยู่ในแคปชัน" ได้ แต่ #hashtag ในแคปชันปัจจุบัน**ไม่ใช่ tappable text เลย** (เป็นแค่ plain string) และไม่มีหน้า Hashtag Feed แยกที่มี Latest/Trending

Requirements:

R1. Render caption เป็น `RichText`/`TextSpan` ที่ parse `#word` เป็น tappable span (สีเน้น, แตะแล้วเปิด Hashtag Feed) — ใช้ regex เดียวกันทุกจุดที่แสดง caption (Home card, Drop card, Drop detail, Club post) ผ่าน shared widget/helper ตัวเดียว ไม่ duplicate regex 4 ที่
R2. หน้า Hashtag Feed ใหม่: query caption ILIKE `%#tag%` ข้าม Drop+Club post (reuse pattern ของ WYN-009's `searchByCaption`) — **ไม่สร้างตาราง `hashtags` แยกรอบนี้** เพื่อไม่ขัดกับการตัดสินใจ defer ของ WYN-009 และหลีกเลี่ยงระบบซ้ำซ้อนตามกติกา RULES.md
R3. Latest tab = chronological, Trending tab = จำนวนโพสต์ที่ใช้ hashtag นี้ในช่วงเวลาสั้น (นิยามเดียวกับ WYN-017's Trending window ถ้าทำแล้ว) — คำนวณแบบ query-time COUNT ไม่ใช่ counter คอลัมน์แยก (เพื่อความง่าย รอบแรก)
R4. เขียนไว้ชัดใน Design spec: การค้นหาแบบ ILIKE ไม่แม่นยำ 100% เมื่อ data โตขึ้น (เช่น `#WYNfamily` จะ match เมื่อค้นหา `#WYN` ด้วย ถ้าไม่ทำ word-boundary ให้ถูก) — ต้องมี regex/query ที่ตรวจ boundary ถูกต้อง ไม่ใช่ substring ธรรมดา

Acceptance Criteria:
- [ ] #hashtag ในแคปชันทุกจุดที่แสดง (Home/Drop feed/Drop detail/Club post) เป็น tappable และแตะแล้วเปิด Hashtag Feed ถูก tag
- [ ] Hashtag Feed มี Latest/Trending tab ทำงานถูกต้อง ไม่ค้าง ไม่ crash เมื่อไม่มีผลลัพธ์ (Empty state)
- [ ] Hashtag matching มี word-boundary ถูกต้อง (ไม่ปนกับ hashtag ที่มีคำนำหน้าเดียวกัน)
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับหน้าที่แสดง caption เดิมทุกจุด

Dependencies: ทำได้อิสระ ไม่ต้องรอ WYN-017/018/019 — แต่ถ้าทำหลัง WYN-017 จะได้ Trending-window query มาต่อยอดได้เลย

Priority: กลาง (spec ข้อ 3 เป็น requirement ชัดเจน แต่ไม่ใช่ blocker ของ Home/Drop restructure หลัก)

Risks: ILIKE-based approach (แทนที่จะมี hashtag entity table) จะช้าลงเมื่อข้อมูลโตมาก — ยอมรับความเสี่ยงนี้รอบแรกตาม precedent ของ WYN-009 แต่ควรบันทึกเป็น known limitation ให้ Founder ทราบชัดเจน เผื่อต้องย้อนกลับมาสร้าง entity table จริงภายหลัง

Recommendation: ทำแบบ ILIKE ต่อจาก WYN-009 เพื่อความสม่ำเสมอและไม่สร้างระบบซ้ำซ้อน ตามกติกา RULES.md ข้อ "ห้ามสร้างระบบซ้ำซ้อน" — เสนอปรับเป็น entity table ในอนาคตถ้า usage จริงเริ่มมีปัญหา performance

Handoff: AI Design ออกแบบ Hashtag Feed screen (reuse tab-bar/card pattern เดิม) + กำหนด regex/tap-target ของ hashtag span ให้ตรงกันทุกจุดที่ใช้ ก่อนส่งต่อ AI Coding
