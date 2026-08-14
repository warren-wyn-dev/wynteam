# Product Task — WYN-006

Status: backlog
Owner: AI Product Manager → AI Design (ถัดไป)

Feature: Pop (คลิปสั้นแนวตั้ง)

Goal: ให้ผู้ใช้โพสต์คลิปวิดีโอสั้นแนวตั้งพร้อมแคปชันได้ เป็นเนื้อหาหลักประเภทที่สองของ WYN V0.1 ("WYN V0.1 — CORE APP FEATURE PROMPT" ดู `.wyn/company/DECISIONS.md` 2026-08-14) คู่กับ Drop (WYN-005 — Approved แล้ว)

Target User: วัยรุ่น / Gen Z ที่ต้องการดูและสร้างคลิปวิดีโอสั้นแนวตั้ง มีปฏิสัมพันธ์กับคลิปของคนอื่น

Problem: ตอนนี้ WYN มีแค่ Drop (โพสต์รูปภาพ) เป็นเนื้อหาหลัก ยังไม่มีรูปแบบวิดีโอสั้นเลย ทั้งที่ spec ใหม่กำหนดให้ Pop เป็นหนึ่งใน 4 แท็บหลักของ Bottom Nav — Home (WYN-007) ต้องรอทั้ง Drop และ Pop มีเนื้อหาก่อนถึงจะรวม feed ได้จริง

Requirements:
- **สร้าง Pop**: กดปุ่ม "+ Create Pop" แล้ว:
  - เลือกวิดีโอจากอุปกรณ์ หรือถ่ายวิดีโอใหม่ (ความยาวจำกัด — ดู Risks สำหรับข้อเสนอ limit)
  - เขียน Caption
  - เพิ่ม Hashtag ในแคปชัน (พิมพ์ `#คำ` ระบบรู้จำ — ยังไม่ต้องทำหน้ารวมผลลัพธ์ hashtag ในรอบนี้ ผูกกับ WYN-009 เหมือน WYN-005)
  - Mention ผู้ใช้ในแคปชัน (พิมพ์ `@username` ระบบรู้จำ — ยังไม่ต้องส่ง Notification ในรอบนี้ ผูกกับ WYN-012 เหมือน WYN-005)
  - กด Post
- **วิดีโอ**: อัตราส่วนแนวตั้ง (9:16) เป็นหลักตาม spec — วิดีโอที่ไม่ใช่ 9:16 อยู่แล้วให้ constrain/crop ให้แสดงผลเป็น 9:16 สม่ำเสมอ
- **Vertical swipe feed**: เลื่อนขึ้น/ลงเพื่อไปคลิปถัดไป/ก่อนหน้า ทีละคลิปเต็มจอ (คลิปเดียวเต็มจอเสมอ ไม่ใช่ list/grid) — **ห้ามลอก Layout ของ TikTok โดยตรง** ตามกติกาที่ Founder กำหนดไว้ตายตัว (ดู `.wyn/docs/design/design-principles.md`) ให้ AI Design ตีความสิ่งนี้เป็นโจทย์การออกแบบที่ต้องแก้ ไม่ใช่แค่ก็อปปี้แล้วเปลี่ยนสี
- **แสดงผลคลิปแต่ละอัน**: Profile picture, Username, Caption, ปุ่ม Like/Comment/Share/Save, จำนวน Like, จำนวน Comment, **จำนวน View**
- **Like**: กด Like/Unlike ได้ เห็นจำนวนอัปเดตทันที (ต้องไม่มีบั๊ก double-tap แบบที่เจอใน WYN-004 — pattern ที่ถูกต้องมีอยู่แล้วใน `DropDetailScreen._toggleLike` ให้อ้างอิงตรง ๆ ได้เลยครั้งนี้ ต่างจาก WYN-005 ที่ยังไม่มี pattern ให้อ้างอิงตอนเริ่ม)
- **Comment**: เพิ่ม Comment ได้, **ลบ Comment ของตัวเองได้**, **Like Comment ได้** — ทั้ง 3 ความสามารถต้องมีตั้งแต่รอบแรก (ดู Risks ด้านล่าง: นี่คือจุดที่ WYN-005 พลาดไป 2 รอบติดกันเพราะไม่มี pattern จาก WYN-004 ให้อ้างอิง — รอบนี้ **มี** pattern ที่ถูกต้องแล้วจาก WYN-005 หลัง Debug รอบ 2 ให้ AI Coding อ้างอิงได้ตรง ๆ ไม่มีข้อแก้ตัวให้พลาดซ้ำ)
- **Views**: นับจำนวนครั้งที่คลิปถูกเปิดดู (นับแบบง่ายที่สุดในรอบนี้ — เปิดดูครั้งเดียวนับ 1 ไม่ต้อง dedup ต่อ user/session ในรอบแรก เก็บรายละเอียด dedup ไว้ปรับปรุงทีหลังถ้า Founder ต้องการ)
- **Follow**: กด Follow/Unfollow เจ้าของคลิปได้จากหน้า Pop — ใช้ระบบ Follow เดียวกับที่จะสร้างใน WYN-008 (ยืนยันแล้วว่า Follow ใช้ร่วมกันทั้ง Drop และ Pop ไม่แยกทำสองระบบ) **WYN-006 นี้จะยังไม่สร้างระบบ Follow เอง** เพราะ WYN-008 ยังไม่เริ่ม — ใส่ปุ่ม UI ไว้ก่อนได้แต่ยังไม่ผูก backend จริงจนกว่า WYN-008 จะเสร็จ (ดู Dependencies)
- **Save**: บันทึกคลิปไว้ดูทีหลังได้ — ใช้ตาราง `saves` เดียวกับ WYN-005 (`content_type`/`content_id` ออกแบบรองรับ Pop ไว้แล้วตั้งแต่ต้น ไม่ต้อง migrate schema ใหม่ — เปลี่ยนแค่ `content_type = 'pop'`)
- **Share**: Share Content ออกไปนอกแอป + Copy Link (pattern เดียวกับ WYN-005 — share sheet ของระบบปฏิบัติการ + generate ลิงก์ไปหน้า Pop นั้น ยังใช้ placeholder domain จนกว่า Founder จะยืนยัน domain จริง)
- ผู้ใช้ลบ Pop ของตัวเองได้

Acceptance Criteria:
- [ ] กดปุ่ม "+ Create Pop" เลือกวิดีโอจากอุปกรณ์หรือถ่ายใหม่ พิมพ์ caption (มี/ไม่มี hashtag/mention ก็โพสต์ได้) กด Post แล้วเห็น Pop ใหม่ปรากฏในฟีด
- [ ] Pop ที่ไม่มีวิดีโอ โพสต์ไม่ได้ (วิดีโอเป็น**บังคับ**สำหรับ Pop เหมือนที่รูปภาพเป็นบังคับสำหรับ Drop)
- [ ] วิดีโอแสดงเป็นแนวตั้ง (9:16) สม่ำเสมอทุกคลิป ไม่ว่าไฟล์ต้นฉบับจะเป็นสัดส่วนใด
- [ ] เลื่อนขึ้น/ลง (swipe) เพื่อไปคลิปถัดไป/ก่อนหน้าได้ ทีละคลิปเต็มจอ วิดีโอเล่นอัตโนมัติเมื่อคลิปนั้นอยู่ในจอ หยุดเมื่อเลื่อนออกจากจอ
- [ ] กดไลก์คลิปแล้วเห็นจำนวนไลก์เพิ่มทันที กดซ้ำเพื่อเลิกไลก์ได้ (ต้องไม่มีบั๊ก double-tap)
- [ ] คอมเมนต์ได้ ลบคอมเมนต์ของตัวเองได้ กด Like คอมเมนต์ได้ (**ครบทั้ง 3 อย่างตั้งแต่รอบแรก**)
- [ ] จำนวน View เพิ่มขึ้นเมื่อคลิปถูกเปิดดู
- [ ] กด Share เปิด share sheet ของระบบ หรือ copy ลิงก์ไปยัง clipboard ได้
- [ ] กด Save แล้วบันทึกไว้ได้ (ที่เก็บจริงไปแสดงใน Profile รอ WYN-013 เหมือน Drop)
- [ ] ผู้ใช้เห็นปุ่มลบเฉพาะ Pop ของตัวเองเท่านั้น
- [ ] ผู้ใช้อื่นแก้ไข/ลบ Pop ของเราไม่ได้ (RLS บังคับ)
- [ ] ผู้ใช้อื่นลบไลก์/คอมเมนต์/save ของเราแทนเราไม่ได้ (RLS บังคับ)
- [ ] ผู้ใช้อื่นแก้ไข/ลบคอมเมนต์ของเราแทนเราไม่ได้ (RLS บังคับ)

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved), WYN-005 (Drop — Approved, ใช้เป็นจุดอ้างอิง pattern โดยตรงสำหรับ Like/Comment/Save/Share/schema RLS)

Priority: P0 — เท่ากับ WYN-005 ตาม roadmap dependency graph (ดู `.wyn/docs/product/wyn-v0.1-roadmap.md`) แต่เริ่มหลัง WYN-005 ตามลำดับที่ Founder ยืนยันแล้ว

Risks:
- **Video handling เป็นความเสี่ยงใหม่ที่โปรเจกต์นี้ยังไม่เคยทำมาก่อนเลย** (WYN-002/003/004/005 มีแค่รูปภาพ) — ขนาดไฟล์วิดีโอใหญ่กว่ารูปมาก, ต้องมี compression/encoding ก่อน upload ไม่งั้น Storage และ bandwidth จะโดนกระทบหนัก, ต้องคุยเรื่อง thumbnail (frame แรกหรือ frame ที่กำหนด) สำหรับใช้เป็น placeholder ระหว่างโหลด
- **ความยาวคลิปสูงสุด**: spec ต้นฉบับไม่ได้ระบุตัวเลขชัดเจน เสนอ 60 วินาทีเป็นค่าเริ่มต้น (มาตรฐานทั่วไปของ short-form video, ปรับได้ทีหลังถ้า Founder ต้องการอย่างอื่น) — ให้ AI Design/Coding ล็อกที่ 60 วินาทีไปก่อนในรอบนี้ และ reject วิดีโอที่ยาวเกินตอนเลือกไฟล์ พร้อม error message ชัดเจน
- **Autoplay + เสียง**: TikTok/Reels convention คือ autoplay พร้อมเสียง (ไม่ mute default) — แต่ autoplay-with-sound มีข้อพิจารณาเรื่อง UX/battery/data usage ที่ควรให้ AI Design ตัดสินใจอย่างมีเหตุผล ไม่ใช่แค่ copy convention มาเฉย ๆ (ต้องสอดคล้องกับกติกา "ห้ามลอก Layout ของ TikTok โดยตรง" ด้วย — เป็นได้ทั้งเรื่อง layout และ behavior)
- **View count dedup**: รอบแรกนับแบบง่าย (เปิดดู = +1 ไม่ dedup) อาจทำให้ตัวเลขสูงเกินจริงถ้าผู้ใช้เลื่อนกลับไปกลับมาซ้ำ ๆ — ยอมรับเป็น known limitation ของรอบนี้ (เหมือนที่ WYN-005 ยอมรับ auto-crop แบบไม่มี interactive drag เป็น known limitation) ปรับปรุงทีหลังได้ถ้า Founder ต้องการความแม่นยำมากกว่านี้
- **Storage bucket ใหม่สำหรับวิดีโอ**: ต้องแยกจาก `drop-images` (คนละ bucket, คนละ RLS policy รูปแบบเดียวกัน) เพราะเป็นคนละ content type และขนาดไฟล์ต่างกันมาก
- ยังไม่มี Content Moderation (นอก scope เหมือน WYN-004/WYN-005)
- Follow button ใน UI จะยังไม่ทำงานจริงจนกว่า WYN-008 จะเสร็จ — ต้องตัดสินใจว่าจะซ่อนปุ่มไปก่อนหรือใส่ไว้แบบ disabled ให้ AI Design เสนอทางเลือก

Founder ยืนยันแล้ว (สืบเนื่องจากการตัดสินใจของ WYN-005 ที่ครอบคลุมทั้ง Drop และ Pop ดู `.wyn/company/DECISIONS.md` 2026-08-14):
- Hashtag/Mention รอบนี้ทำแค่ "พิมพ์ในแคปชันได้ ระบบจำ/บันทึกได้" — แตะแล้วไปหน้าค้นหา/โปรไฟล์ผูกกับ WYN-009 ทีหลัง (เหมือน WYN-005)
- Follow (WYN-008 เมื่อถึงคิว) จะใช้ได้กับ Pop ด้วย ไม่ใช่แค่ Drop — ระบบเดียวใช้ร่วมกันทั้งแอป
- Home Feed (WYN-007) จะเป็น Global ก่อน ไม่กรองตาม Follow

Recommendation: ดำเนินการต่อจาก WYN-005 ทันทีตาม roadmap ที่ Founder อนุมัติไว้แล้ว (P0, ลำดับที่ 2 ต่อจาก Drop) — เน้นย้ำให้ AI Design/Coding ไล่ checklist "Comment: เพิ่ม/ลบ/Like" ให้ครบทั้ง 3 อย่างตั้งแต่ต้น โดยอ้างอิงโค้ดของ WYN-005 หลัง Debug รอบ 2 ตรง ๆ (`DropRepository`/`DropDetailScreen` ปัจจุบันมี pattern ที่ถูกต้องครบแล้วทั้ง Like Comment และ Delete Comment) เพื่อไม่ให้เกิดการ "มองข้ามเพราะไม่มี pattern อ้างอิง" ซ้ำเป็นครั้งที่ 3

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบหน้าจอ Pop Feed (vertical swipe), Create Pop, และองค์ประกอบ Comment/Like/Share/Save ที่ใช้ร่วมกับ Pop Detail (ถ้าออกแบบเป็นหน้าแยก) หรือ overlay บนตัว feed เอง (ถ้าออกแบบแบบ TikTok-inspired-but-not-copied) — ให้ AI Design ตัดสินใจและอธิบายเหตุผลว่าทำไมไม่ใช่การลอก Layout ของ TikTok โดยตรง เหมือนที่ WYN-005 อธิบายเหตุผลของ grid-vs-feed ไว้ใน `.wyn/docs/design/wyn-005-drop.md`
