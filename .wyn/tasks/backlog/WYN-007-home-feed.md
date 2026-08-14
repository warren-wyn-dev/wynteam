# Product Task — WYN-007

Status: backlog
Owner: AI Product Manager (เสร็จ) → AI Design (ถัดไป)

Feature: Home (Search bar + Feed รวม Drop/Pop)

Goal: ให้ Home เป็นแท็บแรกที่ผู้ใช้เห็นทันทีหลังเปิดแอป แสดงเนื้อหาทั้ง Drop (รูปภาพ) และ Pop (วิดีโอสั้น) รวมกันเป็น feed เดียวเรียงตามเวลา พร้อม Search bar ที่หัวจอ ตาม "WYN V0.1 — CORE APP FEATURE PROMPT" (ดู `.wyn/company/DECISIONS.md` 2026-08-14)

Target User: วัยรุ่น / Gen Z ที่เปิดแอปมาแล้วอยากเห็นภาพรวมทุกอย่างที่เกิดขึ้นในทันที ไม่ต้องสลับแท็บไปมาระหว่าง Drop กับ Pop เพื่อดูของใหม่

Problem: ตอนนี้ WYN-005 (Drop) และ WYN-006 (Pop) เป็นสองแท็บแยกกันสมบูรณ์ ไม่มีที่ไหนในแอปที่แสดงเนื้อหาทั้งสองประเภทรวมกัน ทำให้แท็บ Home (ที่ RootShell จองที่ไว้ตั้งแต่ WYN-005) ยังเป็น placeholder "เร็ว ๆ นี้" อยู่

Requirements:
- **Feed รวม Drop + Pop เรียงตามเวลา (chronological)**: การ์ดของ Drop และ Pop ปรากฏปนกันใน feed เดียว เรียงจากใหม่ไปเก่าตาม `created_at` ข้ามสองประเภทเนื้อหา (ไม่ใช่ query drops ทั้งหมดตามด้วย pops ทั้งหมดแบบแยกเป็นสองช่วง) — ดู Risks สำหรับแนวทางเทคนิคที่แนะนำ
- **การ์ดแต่ละประเภทแสดงผลต่างกันตามชนิดเนื้อหา**:
  - การ์ด Drop: รูปภาพ 1:1 + caption + avatar/username + จำนวน Like/Comment (รูปแบบเดียวกับที่ `DropDetailScreen`/`DropGridTile` แสดงอยู่แล้ว เลือกระดับรายละเอียดที่เหมาะกับ single-column feed)
  - การ์ด Pop: thumbnail วิดีโอ 9:16 (หรือ preview เล่นสั้น ๆ ถ้า Design เห็นว่าคุ้มค่า) + caption + avatar/username + จำนวน Like/Comment/View
  - แตะการ์ดใดก็ได้ → เปิดหน้ารายละเอียดของเนื้อหานั้นตามประเภทจริง (Drop → `DropDetailScreen`, Pop → เข้า `PopFeedScreen` ที่คลิปนั้นหรือหน้าเทียบเท่า — ให้ Design ตัดสินใจ UX ที่เหมาะสม)
- **Search bar ที่หัวจอ**: แสดงตลอดเวลาด้านบนของ Home (ตาม spec เดิม "Home (Search+Feed รวม)") — **รอบนี้เป็น placeholder เท่านั้น ยังไม่ทำ Search จริง** (ดู Recommendation ด้านล่างสำหรับเหตุผล) แตะแล้วนำไปหน้า placeholder ที่บอกชัดเจนว่ากำลังจะมา ไม่ใช่ปุ่มที่กดแล้วไม่มีอะไรเกิดขึ้นเลย (UX ต้องรู้สึกว่า "ยังไม่มา" ไม่ใช่ "พัง")
- **Global feed**: แสดงเนื้อหาของทุกคน ไม่กรองตาม Follow (Founder ยืนยันแล้ว — Follow filtering ผูกกับ WYN-008/WYN-013 ทีหลัง)
- **Infinite scroll + pull-to-refresh**: pattern เดียวกับ Drop Feed/Pop Feed ที่มีอยู่แล้ว
- Pull-to-refresh ต้องโหลดเนื้อหาทั้งสองประเภทใหม่พร้อมกัน ไม่ใช่แค่ประเภทเดียว

Acceptance Criteria:
- [ ] เปิดแอปแล้วเห็น Home เป็นแท็บแรก (index 0 ใน Bottom Nav) แสดง feed ที่มีทั้งการ์ด Drop และการ์ด Pop ปนกัน
- [ ] การ์ดเรียงตามเวลาใหม่สุดก่อนจริง ไม่ว่าจะเป็น Drop หรือ Pop (ทดสอบด้วยการสร้าง Drop ใหม่หลัง Pop แล้วต้องเห็น Drop นั้นอยู่บนสุด และกลับกัน)
- [ ] แตะการ์ด Drop → เปิด Drop Detail ได้ถูกต้อง, แตะการ์ด Pop → เข้าถึงคลิปนั้นได้ถูกต้อง
- [ ] เลื่อนถึงล่างสุด → โหลดเนื้อหาเพิ่มอัตโนมัติ (ทั้งสองประเภทต่อเนื่องกัน ไม่ใช่โหลด Drop หมดก่อนแล้วค่อยเริ่ม Pop)
- [ ] Pull-to-refresh โหลด feed ใหม่ทั้งหมด
- [ ] เห็น Search bar ที่หัวจอ Home ตลอดเวลา แตะแล้วไปหน้า placeholder ที่สื่อสารชัดเจนว่ายังไม่พร้อมใช้งาน (ไม่ crash ไม่เงียบ)
- [ ] Home แสดงเนื้อหาของทุกคน ไม่กรองตาม Follow
- [ ] Empty state (ยังไม่มี Drop/Pop เลยในระบบ) แสดงข้อความเชิญชวนที่เหมาะสม
- [ ] Error state (โหลดไม่สำเร็จ) มีปุ่มลองใหม่

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved), WYN-005 (Drop — Approved), WYN-006 (Pop — Approved)

Priority: P1 — ตาม roadmap dependency graph (ต้องมี Drop และ Pop ทำงานได้ก่อนถึงจะรวม feed ได้จริง) เริ่มทันทีหลัง WYN-006 approved ตามลำดับที่วางไว้

Risks:
- **การรวม feed ข้าม 2 ตารางที่มี repository แยกกัน (`drops`/`pops`) เป็นความเสี่ยงทางเทคนิคหลักของ task นี้** — ถ้า merge/paginate ผิดวิธี (เช่น client ดึง Drop หน้าแรก + Pop หน้าแรกมา sort รวมกันเองแล้ว paginate ต่อด้วย offset แยกกันของแต่ละฝั่ง) จะเกิดปัญหา item ซ้ำ/หาย/เรียงผิดเมื่อเลื่อนหลายหน้า — **แนะนำให้ AI Design/Coding ออกแบบด้วยแนวทาง database-side merge** (เช่น สร้าง SQL view ที่รวม `drops`/`pops` เป็น unified result set ด้วย `UNION ALL` เรียงตาม `created_at` แล้ว paginate บน view นั้นตรง ๆ ด้วย `range()`/`order()` เดียว ไม่ใช่ client-side merge สอง cursor) รายละเอียด implementation จริงให้ AI Coding ตัดสินใจตอน implement แต่ต้องแก้ปัญหา correctness ของการ paginate ข้าม 2 ตารางให้ได้จริง ไม่ใช่แค่ "ดูเหมือนทำงาน" ตอน dataset เล็ก
- Search bar เป็น placeholder ในรอบนี้ — เสี่ยงที่ผู้ใช้คาดหวังว่าค้นหาได้จริงแล้วผิดหวัง ต้องออกแบบ empty/coming-soon state ให้สื่อสารชัดเจน ไม่ใช่แค่ไม่มีอะไรเกิดขึ้น
- ยังไม่มี Content Moderation หรือ Recommendation Algorithm (นอก scope ของ V0.1 ทั้งคู่ ตาม spec เดิม)

Codebase Decision — ชะตากรรมของโค้ด WYN-004 เดิม (ตัดสินใจแล้วโดย AI Product Manager, ไม่ใช่ Major Architecture change ที่ต้องขออนุมัติ Founder ตาม `.wyn/company/RULES.md`):
- **ลบโค้ด Dart ที่ไม่ใช้แล้วทิ้ง**: `app/lib/features/feed/` ทั้งโฟลเดอร์ (`FeedScreen`, `PostRepository`, `PostCard`, `PostDetailScreen`, `CreatePostScreen`, model `Post`/`Comment`) รวมถึง test ที่เกี่ยวข้อง (`feed_screen_test.dart`, `post_*_test.dart`, `comment_test.dart`, `create_post_screen_test.dart`, `recording_post_repository.dart`) — เหตุผล: ไม่มี route ไหนชี้ไปเลยตั้งแต่ WYN-005 (ถูกแทนที่ด้วย `RootShell`), Home ใหม่ของ WYN-007 นี้จะ query `drops`/`pops` ตรง ๆ ไม่ใช้ `posts` เดิมเลย จึงไม่มีเหตุผลทางเทคนิคให้เก็บไว้ต่อ — โค้ดเดิมยังอยู่ใน git history เต็มรูปแบบ (ไม่ได้หายไปจริง) หากต้องการดูอ้างอิงภายหลังสามารถ checkout ย้อนกลับได้เสมอ ตรงตามหลักการ "ห้ามเก็บโค้ดที่ไม่ใช้แล้วไว้เผื่ออนาคตที่ไม่แน่นอน" ของทีม
- **ไม่ลบตาราง `posts`/`likes`/`comments` ออกจาก `supabase/schema.sql`**: การ drop ตาราง DB เป็น "โครงสร้างฐานข้อมูลแบบทำลายล้าง" ซึ่งอยู่ในรายการที่ต้องขออนุมัติ Founder ก่อนเสมอตาม `.wyn/company/RULES.md` (ต่างจากการลบโค้ด Dart ที่เป็นการตัดสินใจเชิง product/technical ทั่วไป) — บันทึกคำขออนุมัติไว้ที่ `.wyn/company/APPROVALS.md` แล้ว (สถานะ: รออนุมัติ) ตารางเหล่านี้จะยังอยู่ในสคีมาต่อไปจนกว่า Founder จะตัดสินใจ (ไม่มีผลกระทบต่อการทำงานของแอป เพราะไม่มี route ไหนอ้างอิงตารางเหล่านี้อีกแล้ว)

Recommendation:
1. เริ่ม WYN-007 ทันทีตาม roadmap ที่ Founder อนุมัติไว้แล้ว
2. **Search bar เป็น placeholder ในรอบนี้ ไม่ทำ partial search** — เหตุผล: (ก) WYN-009 (Search จริง — Users/Drop/Pop/Hashtag) จะมาแทนที่อยู่ดี การทำ partial search ตอนนี้แล้วต้องเขียนใหม่ทั้งหมดตอน WYN-009 คือ throwaway work (ข) partial search (เช่น filter caption ที่โหลดมาแล้วในเครื่อง) ให้ผลลัพธ์ที่เข้าใจผิดได้ง่าย (ค้นแล้วเจอแค่เนื้อหาที่บังเอิญโหลดมาแล้ว ไม่ใช่ค้นทั้งระบบจริง) ซึ่งแย่กว่าการบอกตรง ๆ ว่า "ยังไม่พร้อม" (ค) สอดคล้องกับ precedent ของ WYN-005/006 ที่เลือกบันทึก deferred scope ไว้ชัดเจนแทนที่จะทำแบบครึ่ง ๆ กลาง ๆ
3. **ลบโค้ด WYN-004 ที่ไม่ใช้แล้วทิ้งระหว่าง implement WYN-007** (ดูหัวข้อ Codebase Decision ด้านบน) — มอบหมายให้ AI Coding ทำเป็นส่วนหนึ่งของงานนี้

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบหน้าจอ Home (feed รวม Drop/Pop, การ์ดแต่ละประเภท, Search bar placeholder, states ต่าง ๆ) — ต้องตัดสินใจ UX ของการแตะการ์ด Pop จาก Home (เปิด `PopFeedScreen` ที่ตำแหน่งคลิปนั้น หรือเปิดมุมมองอื่น) และออกแบบ placeholder ของ Search bar ให้สื่อสารชัดเจนว่า "กำลังจะมา" ไม่ใช่ "พัง"
