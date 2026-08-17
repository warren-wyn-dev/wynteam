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

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-028-trending-top10-search.md` — สรุปการตัดสินใจหลัก:

1. **ข้อค้นพบสำคัญ**: อ่านโค้ดจริงของ `HashtagFeedScreen` (WYN-020) แล้วพบว่า **ไม่มี query "จัดอันดับ hashtag ข้ามระบบ" ให้ reuse ตรงๆ ตามที่ R1 เขียนไว้** — Trending tab ของ WYN-020 แค่เรียง**โพสต์ของ 1 tag ที่รู้อยู่แล้ว**ตาม `likeCount + commentCount` (ไม่มี time window ด้วยซ้ำ แม้ WYN-020's R3 จะตั้งใจอ้างอิง WYN-017's window ก็ไม่ได้ implement จริง) ดังนั้นสิ่งที่ reuse ได้จริงคือ 3 ส่วนประกอบ ไม่ใช่ query เดียวทั้งก้อน: (ก) tokenizer `extractHashtags()` เดิมเป๊ะ (ข) นิยาม "ช่วงเวลาสั้น" ยืมจาก `HomeRepository._trendingWindow` (48 ชม., WYN-017 — window เดียวที่มีอยู่จริงในระบบ) (ค) pattern "bounded candidate fetch → rank client-side" เดียวกับ `fetchTrending()`/`fetchRankedFeed()` ที่มีอยู่แล้ว — ต้องเขียน repository method ใหม่จริง (`HashtagRepository.fetchTopTrendingHashtags`) แต่ประกอบจากชิ้นส่วนที่มีอยู่แล้วทั้งหมด ไม่ใช่คิด algorithm ใหม่
2. **Trending scope = Drop + Club post เท่านั้น ไม่รวม Pop** — สอดคล้องกับ scope ของระบบ hashtag ทั้งระบบตาม WYN-020 (แม้ Pop จะมี `searchByCaption` อยู่แล้วก็ตาม เพราะ `HashtagFeedScreen` เองก็ไม่รวม Pop)
3. **Layout**: TabBar (User/Drop/Pop/Club) **ซ่อนทั้งหมดตอน query ว่าง** แทนที่ด้วยหน้าเดียว scroll เดียว — Recent Searches (แสดงเฉพาะมีประวัติ, เป็น `Wrap` ของ `Chip` มี delete icon ในตัว) อยู่บน, "WYN TRENDING" (vertical numbered list 1-10, ไม่ใช่ horizontal tile แบบ Home's Trending เพราะเป็นข้อความไม่ใช่รูป) อยู่ล่าง — เมื่อ query ไม่ว่างแล้ว (พิมพ์เองหรือแตะ Recent chip) กลับไปพฤติกรรม TabBar เดิมของ WYN-009 ทุกประการ
4. **Recent Searches storage**: `shared_preferences` (มีอยู่แล้วใน `pubspec.yaml`, เคยใช้กับ `pop_mute_preference.dart`) — key เดียว `'recent_searches'` เก็บเป็น `List<String>` ตรงๆ ผ่าน `getStringList`/`setStringList` (ไม่ต้อง JSON) จำกัด 10 รายการ, dedupe case-insensitive, บันทึกเฉพาะตอน "เลือกผลลัพธ์จริง" ไม่ใช่ทุก debounce query (กันประวัติเต็มไปด้วยคำพิมพ์ไม่จบ) — ลบทีละรายการ/ลบทั้งหมด **ไม่มี confirm dialog** (ต่างจาก `confirm_delete_dialog.dart` ที่ใช้กับเนื้อหาถาวร เพราะนี่แค่ประวัติส่วนตัวบนอุปกรณ์ ความเสี่ยงต่ำ)
5. **R3 ยืนยัน**: ไม่มี realtime rank-change indicator ใดๆ คำนวณสดทุกครั้งที่เปิดหน้า Search (fresh query ทุก `initState`) ไม่ cache/ไม่เก็บอันดับรอบก่อนไว้เทียบ
6. **จำกัด 10 รายการเป๊ะที่ data layer** (`.take(10)` ใน repository ไม่ใช่แค่ตัดที่ UI) และ **fail-safe เงียบ** (`SizedBox.shrink()`) เมื่อ Trending fetch กำลังโหลด/ล้มเหลว มิเรอร์ pattern ของ Home's Trending row (WYN-017) เพื่อไม่บล็อกส่วนอื่นของหน้า

Handoff: ส่งต่อ AI Coding (`/code`) — รายละเอียดไฟล์ใหม่/ไฟล์ที่ต้องแก้/test ที่ต้องมีอยู่ใน Handoff section ของ `.wyn/docs/design/wyn-028-trending-top10-search.md`
