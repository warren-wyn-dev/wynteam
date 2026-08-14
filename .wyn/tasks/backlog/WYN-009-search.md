# Product Task — WYN-009

Status: backlog
Owner: AI Product Manager (เสร็จ) → AI Design (ถัดไป)

Feature: Search (ค้นหา User/Drop/Pop จริง แทนที่ placeholder เดิมใน Home)

Goal: ให้ผู้ใช้ค้นหา user (username/ชื่อที่แสดง), Drop, และ Pop ได้จริงจาก search bar ที่มีอยู่แล้วใน Home (WYN-007) ซึ่งตอนนี้เป็นแค่ placeholder ข้อความ "เร็ว ๆ นี้"

Target User: วัยรุ่น / Gen Z ที่จำ username เพื่อนได้แต่ยังไม่ได้ follow, หรืออยากหา Drop/Pop ที่เคยเห็นแคปชันเกี่ยวกับเรื่องอะไรสักอย่าง

Problem: `SearchPlaceholderScreen` (`app/lib/features/home/presentation/search_placeholder_screen.dart`) เปิดจาก search bar บน Home แล้วแสดงแค่ข้อความ "ฟีเจอร์ค้นหากำลังจะมาเร็ว ๆ นี้" ไม่มีการค้นหาจริงเลยตั้งแต่ WYN-007 — `DropRepository`/`PopRepository`/`ProfileRepository` ที่มีอยู่แล้วก็ไม่มี method ค้นหาด้วย keyword เลยสักตัว

Requirements:
- **แทนที่ `SearchPlaceholderScreen` ในตำแหน่งเดิม**: ยังคงเปิดจากการแตะ search bar บน Home เหมือนเดิมทุกประการ (ไม่ย้าย entry point ไปที่อื่น) แต่เนื้อหาข้างในเป็นหน้าค้นหาจริงแทนข้อความ placeholder
- **ค้นหาได้ 3 ประเภท แยกกันชัดเจน ไม่ปนกันเป็นลิสต์เดียว**: User (ตาม `username`/`display_name`), Drop (ตาม `caption`), Pop (ตาม `caption`) — ใช้ `TabBar` icon+label แบบเดียวกับที่ `ViewProfileScreen` (WYN-013) เพิ่งวางไว้ ไม่ใช่ list ผสมที่ต้องคิด ranking ข้ามประเภทเนื้อหาที่ไม่เทียบกันได้ (user vs. รูปภาพ vs. วิดีโอ ไม่มี "ความใหม่" ร่วมกันแบบที่ Home/Saved เทียบกันได้)
- **Live search พร้อม debounce**: พิมพ์แล้วค้นหาอัตโนมัติโดยไม่ต้องกดปุ่ม แต่ต้อง debounce (รอผู้ใช้หยุดพิมพ์ก่อนค่อยยิง query จริง — ไม่ยิงทุกตัวอักษร) และต้องพิมพ์อย่างน้อย 2 ตัวอักษรก่อนเริ่มค้นหา (คำค้นสั้นเกินไปจะได้ผลลัพธ์เยอะเกินและช้าโดยไม่มีประโยชน์)
- **ผลลัพธ์ User**: แสดงเป็น list (avatar+ชื่อ+@username ต่อแถว — reuse โครงสร้างแถวเดียวกับ `FollowListScreen`, WYN-008/013) แตะแล้วเปิด `ViewProfileScreen(userId: ...)` (WYN-013 — ใช้ดูโปรไฟล์ใครก็ได้แล้ว)
- **ผลลัพธ์ Drop**: แสดงเป็น grid 3 คอลัมน์ (reuse `DropGridTile`, WYN-005) แตะแล้วเปิด `DropDetailScreen`
- **ผลลัพธ์ Pop**: แสดงเป็น grid 3 คอลัมน์ (reuse `PopGridTile`, WYN-013) แตะแล้วเปิด `PopSingleClipScreen`
- **Empty states แยกกันตามสถานการณ์**: ยังไม่พิมพ์อะไรเลย (prompt ให้พิมพ์คำค้น) vs. พิมพ์แล้วแต่ไม่พบผลลัพธ์ (ข้อความ "ไม่พบ ... สำหรับ \"{คำค้น}\"") — ข้อความต่างกันตาม tab ที่เลือกอยู่
- **Case-insensitive**: ค้นหาไม่สนตัวพิมพ์เล็ก/ใหญ่ (ผู้ใช้พิมพ์ "Namfah" ต้องเจอ user "namfah")
- **Hashtag search — Defer รอบนี้** (ดู Risks สำหรับเหตุผลเต็ม): คำค้นที่มี `#` นำหน้าจะยังคงค้นหาผ่าน caption ILIKE ตามปกติเหมือนคำค้นทั่วไป (ไม่มี logic พิเศษ แต่ก็ยังหา Drop/Pop ที่แคปชันมีคำนั้นเจอได้อยู่ดีเพราะ hashtag เป็นแค่ข้อความในแคปชัน) — สิ่งที่ยังไม่ทำรอบนี้คือ hashtag-as-entity (แตะ hashtag แล้วไปหน้ารวมโพสต์ที่ใช้ hashtag เดียวกัน, hashtag trending ฯลฯ)

Acceptance Criteria:
- [ ] แตะ search bar บน Home → เปิดหน้าค้นหาที่มี TabBar 3 tab (User/Drop/Pop) พร้อมช่องพิมพ์คำค้น
- [ ] ยังไม่พิมพ์อะไร → เห็น prompt ให้พิมพ์คำค้น ไม่ใช่ผลลัพธ์ว่างเปล่าหรือ error
- [ ] พิมพ์ username ของ user ที่มีอยู่จริง (ตัวพิมพ์เล็ก/ใหญ่ต่างจากที่บันทึกไว้) → tab User เจอ user นั้นถูกต้อง แตะแล้วเปิดโปรไฟล์เขาได้จริง
- [ ] พิมพ์คำที่อยู่ในแคปชันของ Drop ที่มีอยู่จริง → tab Drop เจอ Drop นั้น แตะแล้วเปิด `DropDetailScreen` ถูกต้อง
- [ ] พิมพ์คำที่อยู่ในแคปชันของ Pop ที่มีอยู่จริง → tab Pop เจอ Pop นั้น แตะแล้วเปิด `PopSingleClipScreen` ถูกต้อง
- [ ] พิมพ์คำค้นที่ไม่มีใครตรงเลย → เห็นข้อความ "ไม่พบผลลัพธ์" ที่ตรงกับ tab/ประเภทที่กำลังดูอยู่ ไม่ใช่ error หรือค้างที่ loading
- [ ] พิมพ์คำค้นสั้นกว่า 2 ตัวอักษร → ยังไม่ยิง query จริง (เห็น prompt เหมือนยังไม่พิมพ์)
- [ ] พิมพ์เร็ว ๆ ต่อเนื่องกันหลายตัวอักษร → ไม่มีการยิง query ซ้อนกันทุกตัวอักษร (debounce ทำงานจริง — ตรวจสอบด้วย call-count assertion บน RecordingRepository)
- [ ] ลบคำค้นออกจนว่างเปล่า → กลับไปเห็น prompt เดิม ไม่ใช่ผลลัพธ์ค้างจากคำค้นก่อนหน้า
- [ ] Drop/Pop/Home/Follow/Profile เดิมทั้งหมดยังทำงานปกติ ไม่มี regression

Dependencies: WYN-005 (Drop — Approved), WYN-006 (Pop — Approved), WYN-007 (Home — Approved, search bar entry point เดิม), WYN-013 (Profile V2 — Approved, `ViewProfileScreen` ใช้ดูโปรไฟล์ใครก็ได้แล้ว จำเป็นสำหรับผลลัพธ์ User)

Priority: P2 — ตาม roadmap เดิม แต่ Founder ยืนยันให้ทำต่อจาก WYN-013 ทันที (ข้าม WYN-012 Notification และการทำ WYN-010 Share ให้เป็น task ทางการ ไปก่อน) หลังดูสรุปภาพรวม roadmap (2026-08-14)

Risks:
- **Hashtag-as-entity อยู่นอกขอบเขตรอบนี้โดยตั้งใจ**: roadmap เดิมเขียนว่า WYN-009 ครอบคลุม "Users, Drop, Pop, Hashtag" แต่ตอนนี้ไม่มีตาราง `hashtags` หรือ parsing hashtag ออกจากแคปชันเป็น entity แยกเลย (ตั้งแต่ WYN-005/006 hashtag เป็นแค่ข้อความธรรมดาฝังอยู่ใน caption) — การสร้างระบบ hashtag เต็มรูปแบบ (extract, index, hashtag feed, trending) เป็นงานอีกก้อนหนึ่งที่ไม่จำเป็นต้องทำพร้อมกับ Search พื้นฐาน เพราะ ILIKE บน caption ที่ทำรอบนี้ก็ยังหาคำที่มี `#` นำหน้าเจอได้อยู่ดี (แค่ไม่มี entity/index แยกให้ browse) — เสนอแยกเป็น task ใหม่ในอนาคตถ้า Founder ต้องการ Hashtag feed/trending จริงจัง
- **ILIKE query ไม่มี full-text index**: `.ilike('caption', '%$query%')` แบบ substring match จะ scan ตารางทั้งหมดถ้าไม่มี index รองรับ (`pg_trgm`/`GIN` index) — ที่ scale ปัจจุบัน (ยังไม่มี production data) ไม่ใช่ปัญหา แต่ควรบันทึกเป็นข้อเสนอปรับปรุงสำหรับตอนที่ข้อมูลโตขึ้น (เหมือนที่ WYN-013 บันทึกเรื่อง index บน `author_id` ไว้)
- **Debounce ต้อง cancel timer เก่าเสมอ ไม่ใช่แค่ delay**: ถ้า implement debounce ผิด (เช่น ใช้ `Future.delayed` เดี่ยว ๆ โดยไม่ cancel ตัวก่อนหน้า) จะยิง query ซ้อนหลายตัวพร้อมกันและผลลัพธ์อาจกลับมาไม่เรียงตามลำดับที่พิมพ์ (race condition แบบเดียวกับปัญหา stale state ที่เจอมาก่อนในโปรเจกต์นี้ — ดู `.wyn/learning/PATTERNS.md`) — Coding ต้องใช้ `Timer`/`Timer.cancel()` หรือเทียบเท่า ไม่ใช่ delay เฉย ๆ
- **ไม่ใช่ unified search view แบบ `home_feed`/`saved_feed`**: ตั้งใจไม่สร้าง DB view รวม User+Drop+Pop เพราะ Search ไม่มีปัญหา cross-table pagination แบบเดียวกับ Home/Saved (แต่ละ tab paginate อิสระของตัวเอง ไม่ต้อง merge เรียงเวลาข้ามประเภท) — การสร้าง view รวมจะซับซ้อนเกินความจำเป็นและผิดจากเหตุผลเดิมที่ทำให้ต้องมี view (pagination correctness ข้ามตาราง)

Recommendation:
1. เริ่ม WYN-009 ทันทีตามที่ Founder ยืนยันแล้ว
2. **Hashtag search แบบ substring ผ่าน caption เพียงพอสำหรับรอบนี้ ไม่ต้องสร้างระบบ hashtag entity เต็มรูปแบบ** — เหตุผลอยู่ใน Risks ข้างต้น
3. **TabBar 3 tab แยกตามประเภท ไม่ใช่ unified list** — เพราะ user/Drop/Pop ไม่มีมาตรวัดความเกี่ยวข้อง (relevance) ร่วมกันที่สมเหตุสมผลจะเรียงปนกันได้ ต่างจาก Home/Saved ที่ใช้เวลาเป็นตัวเรียงร่วมได้ทั้งสองประเภท
4. **ไม่ต้องสร้าง DB view ใหม่** — เพิ่ม method ค้นหาใน repository ที่มีอยู่แล้ว 3 ตัว (`ProfileRepository.searchProfiles`, `DropRepository.searchByCaption`, `PopRepository.searchByCaption`) พอ

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) หน้าค้นหา (แทนที่ `SearchPlaceholderScreen`) — ช่องพิมพ์คำค้น + TabBar 3 tab (2) list layout ของผลลัพธ์ User (3) grid layout ของผลลัพธ์ Drop/Pop (4) empty state 2 แบบ (ยังไม่พิมพ์ vs. ไม่พบผลลัพธ์) แยกตาม tab (5) loading state ระหว่างรอ debounce/query
