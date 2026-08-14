# Product Task — WYN-013

Status: backlog
Owner: AI Product Manager (เสร็จ) → AI Design (ถัดไป)

Feature: Profile V2 (โปรไฟล์ของคนอื่น + Followers/Following + Drop grid + Pop list + Saved tab)

Goal: ให้ `ViewProfileScreen` ใช้ดูโปรไฟล์ของ**ใครก็ได้**ไม่ใช่แค่ตัวเอง พร้อมแสดงเนื้อหาของเจ้าของโปรไฟล์ (Drop/Pop) และเนื้อหาที่บันทึกไว้ (Saved — เฉพาะเจ้าของโปรไฟล์เห็น) เป็นจุดที่ทำให้ WYN-008 (Follow) และความสามารถ Save (มีอยู่แล้วตั้งแต่ WYN-005/006) มี "ที่ทาง" ใช้งานจริงในแอปเป็นครั้งแรก

Target User: วัยรุ่น / Gen Z ที่อยากดูโปรไฟล์ของคนอื่น (จากการแตะชื่อ/avatar ใน Drop/Pop/Home/Followers list) เพื่อดูผลงานทั้งหมดของเขา หรืออยากย้อนดูสิ่งที่ตัวเองเคยบันทึกไว้

Problem: ตอนนี้ `ViewProfileScreen` เปิดได้แค่โปรไฟล์ตัวเอง (เรียกจาก `RootShell` Profile tab เท่านั้น ไม่มี route อื่นเปิดได้) — ผลคือ (1) `FollowListScreen` (WYN-008) ที่แตะรายชื่อ Followers/Following แล้ว "ยังไปไหนไม่ได้" ตามที่ตั้งใจไว้ชั่วคราว (2) ปุ่ม Save ที่มีอยู่แล้วทุกจุดตั้งแต่ WYN-005 ไม่มีที่ให้ดูผลลัพธ์เลย (3) ไม่มีทางดูว่าใครคนหนึ่งเคยโพสต์ Drop/Pop อะไรไว้บ้างนอกจากเลื่อนหา Home ทีละหน้า

Requirements:
- **`ViewProfileScreen` ต้องแสดงโปรไฟล์ของ user ใดก็ได้**: รับ `userId` เป็นพารามิเตอร์เหมือนเดิม (ไม่เปลี่ยน) แต่ต้องพารามิเตอร์ให้ถูกต้องตามว่าเป็นโปรไฟล์ตัวเองหรือคนอื่น — เป็นตัวเอง: เห็นปุ่ม "แก้ไขโปรไฟล์" + ปุ่ม logout เหมือนเดิม; เป็นคนอื่น: เห็นปุ่ม Follow/Unfollow แทน (reuse component เดียวกับที่มีอยู่แล้วใน `DropDetailScreen`/`PopClipView`) **ไม่เห็น**ปุ่มแก้ไข/logout
- **เปิดโปรไฟล์คนอื่นได้จริงจากทุกจุดที่มีอยู่แล้วในแอป**: แตะชื่อ/avatar ผู้เขียนใน `DropDetailScreen`, `PopClipView`, การ์ด Home (`HomeDropCard`/`HomePopCard`), และแถวใน `FollowListScreen` (WYN-008 — ปัจจุบันแตะแล้วไม่ทำอะไรเลยตามที่ตั้งใจไว้ชั่วคราว ตอนนี้ต้องเปิดโปรไฟล์ได้จริง)
- **Drop grid tab**: แสดง Drop ทั้งหมดของเจ้าของโปรไฟล์ (ไม่ใช่ global feed) เป็น grid เหมือน `DropFeedScreen` เดิม (3 คอลัมน์) — แตะแล้วเปิด `DropDetailScreen` ตามปกติ
- **Pop list tab**: แสดง Pop ทั้งหมดของเจ้าของโปรไฟล์ — **ไม่ใช่** full-screen vertical swipe แบบ Pop Feed เดิม (ไม่เหมาะกับการเป็น tab ย่อยในหน้าอื่น) ให้ Design ตัดสินใจ layout ที่เหมาะสม (เช่น thumbnail grid คล้าย Drop) แตะแล้วเปิดดูคลิปนั้น (reuse `PopSingleClipScreen` ที่มีอยู่แล้วจาก WYN-007 ได้ตรง ๆ)
- **Saved tab**: **เห็นเฉพาะเจ้าของโปรไฟล์เท่านั้น** (ไม่แสดง tab นี้เลยเมื่อดูโปรไฟล์คนอื่น — RLS ของตาราง `saves` เดิมก็จำกัดไว้แบบนี้อยู่แล้วตั้งแต่ WYN-005 คือ private โดยดีไซน์) แสดง Drop และ Pop ที่บันทึกไว้**ปนกันเรียงตามเวลาที่บันทึก** (ไม่ใช่ตามเวลาโพสต์) ใหม่สุดก่อน — ดู Risks สำหรับแนวทางเทคนิคที่แนะนำ (reuse pattern database-side view แบบเดียวกับ `home_feed` ของ WYN-007)
- **แถวใน `FollowListScreen` (WYN-008) กดได้จริงแล้ว**: เพิ่ม tap → เปิดโปรไฟล์ของ user แถวนั้น (แก้จากที่ตั้งใจให้ "ยังไปไหนไม่ได้" ในรอบ WYN-008 เป็น "ไปได้แล้ว" ตอนนี้)
- **จำนวน Followers/Following (WYN-008) ยังทำงานเหมือนเดิมทุกประการ** ไม่ว่าจะดูโปรไฟล์ตัวเองหรือคนอื่น — แตะแล้วเปิด `FollowListScreen` ของ user คนนั้น (ไม่ใช่ของตัวเองเสมอไปเหมือนตอนนี้)

Acceptance Criteria:
- [ ] แตะชื่อ/avatar ผู้เขียน Drop ของคนอื่นใน `DropDetailScreen` → เปิดโปรไฟล์ของเขาได้ถูกต้อง
- [ ] แตะชื่อ/avatar ผู้เขียน Pop ของคนอื่นใน `PopClipView`/`PopSingleClipScreen` → เปิดโปรไฟล์ของเขาได้ถูกต้อง
- [ ] แตะการ์ด Home (Drop/Pop) ของคนอื่นที่ส่วนชื่อ/avatar → เปิดโปรไฟล์ของเขาได้ถูกต้อง (ไม่ใช่เปิด Drop/Pop Detail เหมือนแตะส่วนอื่นของการ์ด)
- [ ] แตะรายชื่อใน `FollowListScreen` → เปิดโปรไฟล์ของคนนั้นได้ถูกต้อง
- [ ] เปิดโปรไฟล์ตัวเอง เห็นปุ่มแก้ไขโปรไฟล์ + logout เหมือนเดิม ไม่เห็นปุ่ม Follow (follow ตัวเองไม่ได้)
- [ ] เปิดโปรไฟล์คนอื่น เห็นปุ่ม Follow/Unfollow ทำงานถูกต้อง ไม่เห็นปุ่มแก้ไขโปรไฟล์/logout
- [ ] เปิดโปรไฟล์คนอื่น เห็น Drop grid/Pop list ของเขา ไม่เห็น Saved tab เลย
- [ ] เปิดโปรไฟล์ตัวเอง เห็นทั้ง 3 tab (Drop/Pop/Saved) ครบ
- [ ] แตะ Drop ใน grid → เปิด `DropDetailScreen` ถูกต้อง, แตะ Pop ใน list → เปิดดูคลิปนั้นถูกต้อง
- [ ] บันทึก Drop/Pop ใหม่จากที่ไหนก็ได้ในแอปแล้วเปิด Saved tab ของตัวเอง → เห็นรายการนั้นจริง เรียงจากบันทึกล่าสุดก่อน
- [ ] เอา Drop/Pop ออกจาก Saved (unsave) แล้วกลับมาที่ Saved tab → หายไปจริง
- [ ] จำนวน Followers/Following ที่เห็นตอนดูโปรไฟล์คนอื่นถูกต้องตามข้อมูลจริงของเขา (ไม่ใช่ของเราเอง)
- [ ] Drop/Pop/Home/Follow เดิมทั้งหมดยังทำงานปกติ ไม่มี regression

Dependencies: WYN-005 (Drop — Approved), WYN-006 (Pop — Approved), WYN-007 (Home — Approved, การ์ดต้องเพิ่ม tap-to-profile), WYN-008 (Follow — Approved, ปุ่ม Follow/`FollowListScreen` reuse ตรง ๆ)

Priority: P1 — ตาม roadmap dependency graph เดิม แต่ Founder ยืนยันให้ทำต่อจาก WYN-008 ทันที (ข้าม WYN-009/010 ที่เป็น P2) เพราะเป็นจุดที่ทำให้ Follow/Save มี "ที่ทางใช้งานจริง" (2026-08-14)

Risks:
- **Saved tab ต้องการ pagination ที่ถูกต้องข้าม 2 ตาราง เหมือนปัญหาที่ WYN-007 เจอตอนรวม `home_feed`**: `saves` เก็บแค่ `content_type`/`content_id` ไม่มี FK ตรงไปตาราง `drops`/`pops` (เพราะ 1 คอลัมน์ใช้ชี้ 2 ตารางที่เป็นไปได้) การ fetch แบบ "ดึง saves ของ user แล้ว query drops/pops แยกด้วย id" ธรรมดาจะพอสำหรับ 1 หน้า แต่ paginate ข้ามหลายหน้าจะมีปัญหาเดียวกับที่ WYN-007 เจอ — **แนะนำสร้าง SQL view `saved_feed`** (มิเรอร์แนวทางของ `home_feed`) join `saves` กับ `drops`/`pops` แยกฝั่งด้วย `UNION ALL` กรอง `content_type` ให้ตรง เรียงตาม `saves.created_at` (เวลาบันทึก ไม่ใช่เวลาโพสต์) แล้ว paginate บน view เดียวนั้นตรง ๆ — ต้องมี `security_invoker = true` เพื่อให้ RLS ของ `saves` (private ต่อ user) ยังบังคับใช้ผ่าน view
- **`ViewProfileScreen` ต้องรองรับ 2 persona (เจ้าของ vs คนอื่น) ในโค้ดเดียวกัน**: ความเสี่ยงคือถ้าไม่ระวัง ปุ่มแก้ไข/logout/Follow อาจแสดงผิดเงื่อนไข (เช่น เห็นปุ่ม Follow ตัวเอง) — ต้องเทียบ `userId` พารามิเตอร์กับ `Supabase.instance.client.auth.currentUser!.id` ให้ถูกต้องแบบเดียวกับที่ `isOwnDrop`/`isOwnPop` ทำอยู่แล้ว ไม่ใช่ logic ใหม่ที่ยังไม่เคยพิสูจน์
- **ต้องเพิ่ม repository method ใหม่**: `DropRepository`/`PopRepository` ยังไม่มี "fetch by author" (มีแต่ `fetchFeed` แบบ global) — ต้องเพิ่ม method ใหม่ (เช่น `fetchByAuthor({authorId, page})`) ไม่ใช่ hack `fetchFeed` เดิม เพื่อไม่ให้กระทบ Drop/Pop Feed ที่ผ่าน QA มาแล้ว
- **Pop list tab layout**: Pop Feed เดิม (WYN-006) ออกแบบมาเป็น full-screen vertical swipe โดยเฉพาะ ไม่เหมาะเป็น tab ย่อย — ต้องมี layout ใหม่ (แนะนำ thumbnail grid เหมือน Drop เพื่อความสม่ำเสมอทางสายตา ตาม pattern ที่ WYN-007 วางไว้แล้วสำหรับการ์ด Pop ใน Home ที่ crop เป็น 1:1 + play icon) ให้ Design ตัดสินใจรายละเอียดสุดท้าย
- ยังไม่มี Content Moderation (นอก scope เหมือนทุก feature ก่อนหน้า)

Recommendation:
1. เริ่ม WYN-013 ทันทีตามที่ Founder ยืนยันแล้ว ข้าม WYN-009 (Search)/WYN-010 (Share — ทำไปแล้วบางส่วนตั้งแต่ WYN-005/006/007)/WYN-011 (Save — ทำไปแล้วบางส่วนเช่นกัน) ไปก่อน
2. **รวม scope ที่เหลือของ WYN-011 (Saved tab) เข้ามาใน WYN-013 นี้เลย ไม่แยกทำ WYN-011 เป็น task ต่างหากก่อน** — เหตุผล: (ก) ปุ่ม Save toggle เองทำงานสมบูรณ์แล้วตั้งแต่ WYN-005/006/007 สิ่งที่ขาดมีแค่ "หน้าจอแสดงผล" ซึ่งตรงกับ Saved tab ของ WYN-013 พอดี แยกทำสองรอบจะต้องเขียน query เดียวกัน (join saves กับ drops/pops) ซ้ำสองที (ข) สอดคล้องกับ precedent ที่ WYN-008 เคยรวม scope ของตัวเองให้ครบ (Followers/Following list) แทนที่จะรอ WYN-013 เหมือนกัน — ครั้งนี้เป็นทิศทางตรงกันข้ามที่สมเหตุสมผลเท่ากัน เพราะเนื้อหาที่ต้องดึงมันคาบเกี่ยวกันจริง
3. **Saved tab แสดง Drop+Pop ปนกันเรียงตามเวลาบันทึก** (ไม่แยก 2 tab ย่อย) — เหตุผล: ผู้ใช้บันทึกเพราะ "ชอบเนื้อหานี้" ไม่ได้สนใจว่าเป็นรูปหรือวิดีโอตอนกลับมาดูซ้ำ การแยก sub-tab เพิ่มความซับซ้อนโดยไม่มีประโยชน์ชัดเจน สอดคล้องกับที่ Home (WYN-007) เลือกรวม Drop+Pop เป็น feed เดียวด้วยเหตุผลเดียวกัน

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) `ViewProfileScreen` สองโหมด (เจ้าของ/คนอื่น) ในหน้าเดียวกัน (2) TabBar/สลับ 3 tab (Drop grid/Pop list/Saved) ที่ไม่ลอก Instagram/TikTok โดยตรง (3) layout ของ Pop list tab (4) จุด tap-to-profile ใหม่ทั้งหมด (Drop Detail/Pop Clip/Home card/FollowListScreen) — ต้องตัดสินใจ UX ที่ชัดเจนว่าแตะตรงไหนของแต่ละหน้าจอถึงจะเปิดโปรไฟล์ ไม่ปนกับ tap ที่มีอยู่แล้ว (เช่น แตะการ์ด Home ทั้งการ์ดเปิด Detail อยู่แล้ว ต้องมีจุดแยกสำหรับเปิดโปรไฟล์)
