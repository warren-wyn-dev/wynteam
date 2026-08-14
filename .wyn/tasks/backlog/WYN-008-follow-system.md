# Product Task — WYN-008

Status: backlog
Owner: AI Product Manager (เสร็จ) → AI Design (ถัดไป)

Feature: Follow system (Follow/Unfollow, Followers/Following list)

Goal: ให้ผู้ใช้ติดตาม (Follow) ผู้ใช้คนอื่นได้ ระบบเดียวใช้ร่วมกันทั้ง Drop และ Pop ตามที่ Founder ยืนยันไว้แล้ว (ดู `.wyn/docs/product/wyn-v0.1-roadmap.md` บรรทัด 46) เป็นพื้นฐานให้ WYN-012 (Notification — Follow event) และ WYN-013 (Profile V2 — Followers/Following tab เต็มรูปแบบ) ทำต่อได้

Target User: วัยรุ่น / Gen Z ที่อยากติดตามคนที่โพสต์ Drop/Pop ที่ชอบ เพื่อดูเนื้อหาของคนนั้นต่อเนื่อง (ยังไม่ใช่ตัวกรอง feed ในรอบนี้ — ดู Requirements)

Problem: ตอนนี้ WYN-006 (Pop) มีปุ่ม "ติดตาม" ใน `PopClipView` อยู่แล้วแต่เป็น **UI-only** (แค่ `setState` สลับข้อความในเครื่อง ไม่มี backend, ไม่ persist, กด refresh แล้วหาย) — `DropDetailScreen` (WYN-005) ไม่มีปุ่ม Follow เลยด้วยซ้ำ ทั้งที่ Founder ยืนยันแล้วว่า Follow ต้องใช้ร่วมกันทั้งสองประเภทเนื้อหา

Requirements:
- **Follow/Unfollow ผู้ใช้อื่น**: กดปุ่ม Follow/Unfollow ได้จากทั้ง `DropDetailScreen` (เพิ่มปุ่มใหม่) และ `PopClipView`/`PopSingleClipScreen` (เชื่อมปุ่มเดิมที่มีอยู่แล้วให้ทำงานจริงแทนที่ UI-only เดิม) — **ใช้ตาราง/repository เดียวกันทั้งสองจุด ไม่แยกทำสองระบบ** ตามที่ Founder ยืนยันไว้แล้ว
- **ห้าม Follow ตัวเอง**: ทั้งฝั่ง UI (ซ่อนปุ่ม Follow เมื่อดูเนื้อหาของตัวเอง — ใช้ pattern เดียวกับ `isOwnDrop`/`isOwnPop` ที่มีอยู่แล้วสำหรับซ่อนปุ่มลบ/แสดงปุ่ม Follow เฉพาะเนื้อหาของคนอื่น) และฝั่ง DB (constraint ป้องกัน self-follow ไม่ให้เกิดขึ้นได้แม้ผ่าน client ที่แก้ไขเอง)
- **แสดงจำนวน Followers/Following**: เพิ่มตัวเลข Followers และ Following ใน `ViewProfileScreen` (โปรไฟล์ของตัวเอง — หน้าเดียวที่มีอยู่ในแอปตอนนี้ ดู Recommendation สำหรับเหตุผลที่ยังไม่ทำหน้าโปรไฟล์ของคนอื่น)
- **Followers/Following list**: แตะตัวเลข Followers หรือ Following จาก `ViewProfileScreen` แล้วเปิดหน้ารายชื่อ (list ของ username/avatar/display name) ได้ — รายการแบบเรียบง่าย ยังไม่ต้องมีปุ่ม Follow-back ในหน้า list นี้ในรอบนี้ (ดู Risks)
- **ปุ่ม Follow ต้องแสดงสถานะปัจจุบันถูกต้องเสมอ**: ถ้าติดตามอยู่แล้วต้องแสดง "กำลังติดตาม" ไม่ใช่ "ติดตาม" ตั้งแต่โหลดหน้าครั้งแรก (ต้อง query สถานะจริงจาก DB ไม่ใช่ default เป็น false เสมอเหมือนของเดิมใน WYN-006)
- **ต้องไม่มีบั๊ก double-tap**: กด Follow/Unfollow ซ้ำเร็ว ๆ ต้องได้ผลลัพธ์ถูกต้อง — ใช้ pattern เดียวกับ Like/Save ที่ผ่าน QA มาแล้วทุก feature ก่อนหน้า (อ่าน state สดใหม่ในตัว handler เสมอ ไม่ capture ค่าตอน build)
- **Home ยังไม่กรองตาม Follow ในรอบนี้**: ตามที่ยืนยันไว้แล้วใน roadmap — WYN-008 นี้ทำแค่ระบบ Follow/Unfollow + แสดงจำนวน/list เท่านั้น ไม่แตะ `HomeFeedScreen`/`home_feed` view เลย

Acceptance Criteria:
- [ ] เปิด Drop ของคนอื่น เห็นปุ่ม Follow/Unfollow ข้างชื่อผู้เขียน กดแล้วสถานะเปลี่ยนทันที (optimistic UI)
- [ ] เปิด Pop ของคนอื่น เห็นปุ่ม Follow/Unfollow ทำงานจริง (ไม่ใช่ UI-only เหมือนเดิม) สถานะ sync กับที่กดจาก Drop ของคนเดียวกัน (Follow คนคนเดียวจาก Pop แล้วไปเปิด Drop ของเขา ต้องเห็นว่า "กำลังติดตาม" อยู่แล้ว — พิสูจน์ว่าใช้ระบบเดียวกันจริง)
- [ ] เปิด Drop/Pop ของตัวเอง ไม่เห็นปุ่ม Follow เลย (ป้องกัน self-follow ทาง UI)
- [ ] พยายาม self-follow ผ่าน DB โดยตรง (เช่น insert ตรง ๆ) ต้องถูก DB ปฏิเสธ (constraint บังคับ ไม่ใช่พึ่ง client-side เพียงอย่างเดียว)
- [ ] กด Follow ซ้ำเร็ว ๆ (double-tap) ได้ผลลัพธ์ถูกต้องตามจำนวนครั้งที่กดจริง ไม่ toggle ผิดจังหวะ
- [ ] เปิด `ViewProfileScreen` ของตัวเอง เห็นจำนวน Followers และ Following ถูกต้องตามข้อมูลจริง
- [ ] แตะจำนวน Followers เปิดหน้ารายชื่อผู้ติดตามได้ถูกต้อง, แตะจำนวน Following เปิดหน้ารายชื่อที่ติดตามได้ถูกต้อง
- [ ] Follow คนใหม่แล้วกลับมาที่ `ViewProfileScreen` เห็นจำนวน Following เพิ่มขึ้นจริง (ไม่ต้อง force-restart แอป)
- [ ] ผู้ใช้อื่นสั่ง follow/unfollow แทนเราไม่ได้ (RLS บังคับ — เฉพาะเจ้าของ follow record เท่านั้นที่ลบได้)
- [ ] Home feed (WYN-007) ยังทำงานปกติเหมือนเดิมทุกอย่าง ไม่มี regression จากการเพิ่มปุ่ม Follow ใน Drop/Pop detail screens

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved, ให้ `ViewProfileScreen`/`ProfileRepository` เป็นจุดต่อยอด), WYN-005 (Drop — Approved, เพิ่มปุ่ม Follow เข้าไปใน `DropDetailScreen`), WYN-006 (Pop — Approved, เชื่อมปุ่ม Follow ที่มีอยู่แล้วใน `PopClipView` ให้ทำงานจริง)

Priority: P1 — ตาม roadmap dependency graph (ดู `.wyn/docs/product/wyn-v0.1-roadmap.md`) เริ่มทันทีหลัง WYN-007 approved ตามลำดับที่ Founder ยืนยันแล้ว (2026-08-14)

Risks:
- **Follow แยกจาก Like/Save เชิงโครงสร้าง**: Like/Save ผูกกับ `content_id` (Drop/Pop แต่ละชิ้น) แต่ Follow ผูกกับ `user_id` (คน ไม่ใช่เนื้อหา) — ตาราง `follows` จึงมีรูปแบบต่างจาก `drop_likes`/`pop_likes`/`saves` ที่มีอยู่แล้ว (ไม่มี `content_type`/`content_id` แต่มี `follower_id`/`following_id` แทน) ให้ AI Coding ออกแบบ schema ใหม่ตามรูปแบบที่เหมาะกับ user-to-user relationship โดยตรง ไม่ต้องพยายาม reuse โครงสร้างเดิมที่ไม่เข้ากัน
- **Self-follow ต้องกันสองชั้น**: ทั้ง UI (ซ่อนปุ่ม) และ DB (`CHECK` constraint `follower_id <> following_id`) เพราะ RLS อย่างเดียวกันแค่ "ใครเป็นเจ้าของ record" ไม่ได้กันเนื้อหาของ record นั้นเอง (เหมือนที่ WYN-005/006 ใช้ RLS กัน "แก้ของคนอื่น" แต่ยังต้องมี application logic แยกกัน "self-follow เป็นค่าที่ไม่ควรมีอยู่เลย")
- **หน้าโปรไฟล์ของคนอื่นยังไม่มีในแอป**: `ViewProfileScreen` ตอนนี้ผูกกับ `userId` ของตัวเองเท่านั้นผ่าน `RootShell` (ไม่มี route ไหนเปิดโปรไฟล์คนอื่นเลย) — WYN-008 นี้**ไม่สร้าง**หน้าโปรไฟล์ของคนอื่น (ดู Recommendation สำหรับเหตุผล) ดังนั้น Followers/Following list ของรอบนี้จะแสดงแค่ username/avatar/display name เฉย ๆ **แตะรายชื่อในลิสต์แล้วยังไปไหนไม่ได้ในรอบนี้** (เหมือนที่ Search bar ของ WYN-007 เป็น placeholder ที่ตั้งใจ) — WYN-013 (Profile V2) จะเป็นจุดที่ทำหน้าโปรไฟล์คนอื่นแบบเต็มรูปแบบพร้อม routing จาก list นี้
- **Follow-back จากหน้า list**: รอบนี้ไม่ทำปุ่ม Follow ในหน้า Followers/Following list (ต้องเปิดโปรไฟล์/เนื้อหาของคนนั้นก่อนถึงจะกด Follow ได้ ซึ่งยังทำไม่ได้ในรอบนี้ตามข้อจำกัดด้านบน) — ยอมรับเป็น known limitation ของรอบนี้ เหมือนที่ WYN-006 ยอมรับ view-count ไม่ dedup เป็น known limitation ปรับปรุงทีหลังได้เมื่อ WYN-013 ทำหน้าโปรไฟล์คนอื่นเสร็จ
- ยังไม่มี Notification เมื่อถูก Follow (ผูกกับ WYN-012 ทีหลัง)
- Home ยังไม่กรองตาม Follow (ผูกกับ WYN-013 ทีหลัง ตามที่ยืนยันไว้แล้ว)

Recommendation:
1. เริ่ม WYN-008 ทันทีตาม roadmap ที่ Founder อนุมัติไว้แล้ว
2. **Followers/Following list รอบนี้ทำแบบเรียบง่ายที่สุด (แสดงรายชื่อเฉย ๆ ไม่มี routing ไปโปรไฟล์คนอื่น) แทนที่จะรอทำเต็มรูปแบบใน WYN-013** — เหตุผล: (ก) การนับ/แสดงจำนวน Followers/Following ที่ถูกต้องคือ core value ของ Follow system เอง ถ้ารอ WYN-013 จะทำให้ WYN-008 เสร็จแล้วแต่ "downstream feature" (จำนวน/list) ยังใช้ไม่ได้จริง ไม่ตรงกับที่ AC ต้องพิสูจน์ (ข) การสร้างแค่ list แบบอ่านอย่างเดียว (ไม่มี routing ไปหน้าโปรไฟล์คนอื่นที่ยังไม่มี) เป็นงานเล็กมาก ไม่ throwaway เพราะ WYN-013 จะมาต่อยอด (เพิ่ม routing) ไม่ใช่เขียนใหม่ทั้งหมด (ค) สอดคล้องกับ precedent ของ WYN-007 ที่เลือกทำ Search bar เป็น placeholder ที่ตั้งใจ แทนที่จะข้ามไปเงียบ ๆ — รอบนี้ก็บันทึกข้อจำกัด "แตะรายชื่อแล้วยังไปไหนไม่ได้" ไว้ชัดเจนเหมือนกัน ไม่ใช่ mistake ที่มองข้าม
3. **ไม่สร้างหน้าโปรไฟล์ของคนอื่น (`ViewProfileScreen` สำหรับ `userId` ที่ไม่ใช่ตัวเอง) ในรอบนี้** — เหตุผล: เป็นงานคนละขอบเขตกับ Follow system เอง (ต้องคิดเรื่อง grid Drop, list Pop, Saved tab ของคนอื่น ฯลฯ ซึ่งเป็น scope ของ WYN-013 Profile V2 ตรง ๆ ตาม roadmap) การทำแบบง่าย ๆ ตอนนี้แล้วต้องรื้อใหม่ตอน WYN-013 คือ throwaway work เหมือนเหตุผลที่ WYN-007 ใช้ตัดสินใจเรื่อง Search
4. Follow button ใน `PopClipView` ที่มีอยู่แล้ว (UI-only) ให้เปลี่ยนจาก local `setState` เป็นเรียก repository จริง พร้อมโหลดสถานะ Follow ปัจจุบันตอนเปิดคลิป (ไม่ default เป็น false เสมอเหมือนเดิม)

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) ตำแหน่ง/ลักษณะปุ่ม Follow ใน `DropDetailScreen` ให้เข้ากับ header ที่มีอยู่แล้ว (มิเรอร์ตำแหน่งเดียวกับใน `PopClipView`) (2) หน้าจอ Followers/Following list ใหม่ (เรียบง่าย — avatar+ชื่อ+username เรียงเป็น list, empty state เมื่อยังไม่มีใคร) (3) การแสดงจำนวน Followers/Following ใน `ViewProfileScreen` (ตำแหน่ง, tap target, sync ทันทีหลัง follow/unfollow) — อ้างอิง pattern ปุ่ม Follow เดิมใน `PopClipView`/`.wyn/docs/design/wyn-006-pop.md` เป็นจุดตั้งต้น
