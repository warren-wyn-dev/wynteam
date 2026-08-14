# Design Spec — WYN-006: Pop (คลิปสั้นแนวตั้ง)

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (โดยเฉพาะกติกาตายตัวของ Founder: Blue + White + Soft Gray, ห้าม Liquid Glass, **ห้ามลอก Layout ของ TikTok โดยตรง**)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-006-pop-short-video.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `AvatarCircle` (WYN-003), Drop interaction row + comment list + Like/Delete Comment pattern ที่ถูกต้องครบแล้วหลัง Debug รอบ 2 (WYN-005 — `DropDetailScreen`), scrim gradient (WYN-005 `DropGridTile`), confirm-delete dialog ที่ generalize ไว้แล้ว (`confirmDeletePost`)

## ทิศทางภาพรวม: ทำไม Pop ไม่ใช่ "TikTok สีน้ำเงิน"

Pop ต้องเป็นคลิปแนวตั้งเต็มจอ เลื่อนทีละคลิปเหมือนกันกับ short-form video ทุกแอปเพราะเป็น **interaction pattern มาตรฐานของ format นี้** (full-screen vertical swipe คือสิ่งที่ผู้ใช้คาดหวังเมื่อเห็นคลิปแนวตั้ง ไม่ใช่ลักษณะเฉพาะของ TikTok) — สิ่งที่ต้องออกแบบให้เป็นของ WYN เองคือ **การจัดวางองค์ประกอบ UI ทับบนวิดีโอ** และ **พฤติกรรมเสียง** ไม่ใช่ swipe gesture:

1. **แถบปฏิสัมพันธ์แนวนอนด้านล่าง แทนแถบไอคอนแนวตั้งด้านขวา** — TikTok/IG Reels วางปุ่ม Like/Comment/Share/Save เรียงเป็นแนวตั้งชิดขอบขวาจอ Pop ของ WYN วาง**แถวปฏิสัมพันธ์แนวนอน**ที่ด้านล่างจอแทน (Like/Comment/Share/Save/View count เรียงในแถวเดียว) — ใช้ pattern เดียวกับแถวปฏิสัมพันธ์ของ `DropDetailScreen` ที่มีอยู่แล้วใน WYN (ความคุ้นเคยข้ามฟีเจอร์ภายในแอปเดียวกัน สำคัญกว่าความคุ้นเคยกับแอปคู่แข่ง) ไม่ใช่แค่เปลี่ยนสี ไอคอน แล้วเรียกว่าออกแบบใหม่
2. **เสียง: เริ่มเปิดเสียงจริงตามค่าที่ผู้ใช้ตั้งไว้ล่าสุด ไม่ reset ทุกครั้งที่เข้าแอป** — เนื้อหาคลิปสั้นส่วนใหญ่ต้องพึ่งเสียง (พูด/เพลง/มุกตลก) จึงเริ่มด้วยเสียงเปิดตามค่าเริ่มต้นของระบบ แต่ต่างจากหลายแอปที่ reset การตั้งค่าเสียงทุกครั้งที่เปิดแอปใหม่ WYN จะ**จำค่าที่ผู้ใช้เลือกล่าสุดไว้ในเครื่อง** (ปิดเสียงไว้ครั้งก่อน เข้าแอปใหม่ก็ยังปิดอยู่) ลดความหงุดหงิดที่ต้องกดปิดเสียงซ้ำทุกครั้ง — เป็นการตัดสินใจเชิง UX ที่มีเหตุผลของตัวเอง ไม่ใช่การเลียนแบบ
3. **ไม่มี Liquid Glass บนตัว overlay** — ข้อความ/ปุ่มที่ทับบนวิดีโอใช้ **gradient scrim ทึบสีเข้มบาง ๆ ไล่จากล่างขึ้นบน** (pattern เดียวกับ `DropGridTile`) ไม่ใช่พื้นผิวเบลอ/โปร่งแสงแบบกระจกฝ้าที่หลายแอปคู่แข่งใช้กับ overlay ปุ่ม

---

## Screen 1: Pop Feed (แท็บ Pop ใน Bottom Nav)

Purpose: เลื่อนดูคลิปวิดีโอสั้นทีละคลิปเต็มจอ มีปฏิสัมพันธ์ (Like/Comment/Share/Save) ได้ทันทีโดยไม่ออกจากฟีด

User Flow: แตะแท็บ "Pop" → เห็นคลิปแรกเล่นอัตโนมัติเต็มจอ → เลื่อนขึ้น (swipe up) → คลิปถัดไป (คลิปก่อนหน้าหยุดเล่น) → แตะ Comment → comment sheet เลื่อนขึ้นมาจากล่าง (วิดีโอยังเล่นต่อเบื้องหลัง) → ปิด sheet กลับมาดูคลิปเดิมต่อ

Components:
- Video player เต็มจอ สัดส่วน 9:16 (`fit: BoxFit.cover` ถ้าวิดีโอต้นฉบับไม่ใช่ 9:16 พอดี — crop กึ่งกลางเหมือนหลักการเดียวกับรูป Drop ไม่ใช่ letterbox ที่มีแถบดำ)
- แถบข้อมูลผู้โพสต์+แคปชัน มุมล่างซ้าย เหนือแถบปฏิสัมพันธ์ (ไม่ชนกับแถบปฏิสัมพันธ์): `AvatarCircle` เล็ก + ชื่อแสดง/@username + **ปุ่ม Follow ขนาดเล็ก** (pill button ข้างชื่อ — ดู Design Rules สำหรับสถานะ WYN-008) + แคปชัน (ตัดบรรทัดถ้ายาวเกิน พร้อม "อ่านเพิ่มเติม" ถ้าจำเป็น)
- **แถวปฏิสัมพันธ์แนวนอน** ใต้แถบข้อมูลผู้โพสต์ (ไม่ใช่แถบตั้งขวา — ดูทิศทางภาพรวม): ปุ่ม Like (หัวใจ + จำนวน) / ปุ่ม Comment (บับเบิล + จำนวน, เปิด comment sheet) / ปุ่ม Share (เปิด share sheet + คัดลอกลิงก์) / ปุ่ม Save (bookmark, toggle filled/outline) / ไอคอนตา + จำนวน View (แสดงอย่างเดียว ไม่ใช่ปุ่มกด)
- ปุ่มลบ (ถังขยะ, เฉพาะ Pop ของตัวเอง) — วางในแถบข้อมูลผู้โพสต์ ข้าง ๆ ชื่อ (เหมือน pattern ของ Drop header)
- ไอคอนลำโพง/mute toggle มุมบนขวา (แตะเพื่อสลับเปิด/ปิดเสียง — จำค่าไว้ ดูทิศทางภาพรวมข้อ 2)
- gradient scrim ทึบไล่จากโปร่งใสตรงกลางจอไปสีเข้มที่ขอบล่าง (ให้ข้อความ/ปุ่มอ่านง่ายบนพื้นหลังวิดีโอสีอะไรก็ได้ — ไม่ใช่ Liquid Glass)
- Comment sheet (modal bottom sheet, ลากขึ้นเต็มจอได้บางส่วน): รายการ Comment (avatar เล็ก + ชื่อ + ข้อความ + เวลา + **ปุ่ม Like เล็ก ๆ ข้างคอมเมนต์** + **ปุ่มลบ เฉพาะคอมเมนต์ของตัวเอง**) + ช่อง input คอมเมนต์ bottom-anchored ในตัว sheet เอง

Interactions:
- Swipe ขึ้น/ลง → เปลี่ยนคลิป (คลิปที่เลื่อนออกจอ **ต้องหยุดเล่นและ dispose ตัว video controller ทันที** ไม่ปล่อยเล่นเบื้องหลังค้างไว้ — สำคัญมากสำหรับ memory/battery)
- แตะที่ตัววิดีโอ (ไม่ใช่บนปุ่ม) → pause/resume สลับกัน (gesture มาตรฐานของ video player ทั่วไป ไม่เฉพาะ TikTok)
- แตะไอคอน mute → สลับเปิด/ปิดเสียง จำค่าไว้ในเครื่อง
- แตะ Follow → toggle UI ทันที (ดู Design Rules — ยังไม่ผูก backend จริงจนกว่า WYN-008)
- กด Like/Save → toggle ทันที optimistic UI (pattern เดียวกับ `DropDetailScreen._toggleLike`/`_toggleSave` — อ่าน state สดใหม่ทุกครั้งที่ handler ถูกเรียก ไม่ capture ค่าตอน build)
- กด Comment → เปิด comment sheet (วิดีโอเล่นต่อเบื้องหลัง ไม่ pause อัตโนมัติ)
- ใน comment sheet: เพิ่ม/ลบ/Like คอมเมนต์ (pattern เดียวกับ `DropDetailScreen` เป๊ะ — ปุ่มลบแสดงเฉพาะเจ้าของคอมเมนต์เท่านั้น, ปุ่ม Like อ่าน state สดใหม่เสมอ)
- กด Share → เปิด native share sheet + ตัวเลือกคัดลอกลิงก์ (เหมือน Drop)
- กดปุ่มลบ Pop (เฉพาะของตัวเอง) → dialog ยืนยัน "ลบ Popนี้?" ก่อนลบจริงเสมอ (ใช้ `confirmDeletePost(context, itemLabel: ...)` ที่ generalize ไว้แล้ว ไม่สร้าง dialog ใหม่)
- เข้าคลิปแล้วนับ View ทันที (นับแบบง่าย — ดู Product spec Risks เรื่อง dedup)

States:
- Loading คลิปแรก — spinner กลางจอบนพื้นหลังสีเข้ม
- Playing — ปกติ, autoplay ทันทีที่คลิปอยู่ในจอ
- Paused (ผู้ใช้แตะ pause) — แสดงไอคอน play ค้างกลางจอจาง ๆ จนกว่าจะแตะซ้ำ
- Buffering (ระหว่างเล่น) — spinner เล็กมุมใดมุมหนึ่งที่ไม่บังเนื้อหา
- Error (โหลดวิดีโอไม่สำเร็จ) — พื้นหลังเทาเข้ม + ไอคอน error + ข้อความ "โหลดคลิปไม่สำเร็จ" + ปุ่มลองใหม่ (คลิปอื่นในฟีดยังเลื่อนดูได้ปกติ ไม่ block ทั้งฟีด)
- Empty feed (ยังไม่มี Pop เลยในระบบ) — ข้อความเชิญชวน "ยังไม่มีใครโพสต์คลิปเลย เป็นคนแรกสิ!" พร้อมปุ่มไปสร้าง Pop ใหม่ (จัดกลางจอ พื้นหลัง Soft Gray แทนวิดีโอ)
- Comment sheet: Loading/Loaded/Empty ("ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!")/Sending/Error — เหมือน `DropDetailScreen` ทุกประการ

Responsive Behavior: เต็มจอเสมอไม่ว่าอัตราส่วนหน้าจอมือถือจะต่างกันแค่ไหน (คลิปเป็น `BoxFit.cover` เต็มพื้นที่ที่มี ไม่ใช่คงสัดส่วน 9:16 คงที่แบบมีแถบดำ) — comment sheet สูงประมาณ 60-70% ของจอ ลากขยายเพิ่มได้

Accessibility: ปุ่ม Like/Save/Follow/mute ประกาศสถานะปัจจุบันเสมอ (เช่น "ถูกใจแล้ว กดเพื่อเลิกถูกใจ" / "ปิดเสียงอยู่ กดเพื่อเปิดเสียง") ข้อความ/ปุ่มที่ทับวิดีโอต้องผ่าน contrast AA จริงบน scrim (ไม่ใช่แค่บนพื้นหลังทดสอบสีเรียบ ๆ) วิดีโอที่มี caption/dialogue สำคัญ — เสนอให้ผู้ใช้ใส่คำบรรยายในแคปชันได้ (ไม่ทำ auto-caption/speech-to-text ในรอบนี้ นอก scope)

Design Rules:
- **Comment ต้องมีครบ 3 ความสามารถตั้งแต่ต้น: เพิ่ม, ลบของตัวเอง, Like** — WYN-005 พลาดสองจุดหลังไปคนละรอบ QA เพราะไม่มี pattern จาก WYN-004 ให้อ้างอิงตอนเริ่ม รอบนี้**มี** pattern ที่ถูกต้องครบแล้วจาก `DropDetailScreen`/`DropRepository`/`DropComment` (หลัง Debug รอบ 2) — AI Coding ต้อง reuse โครงสร้างเดียวกันตรง ๆ ไม่มีข้อแก้ตัวให้พลาดซ้ำเป็นครั้งที่ 3
- **ปุ่ม Follow ใส่ UI ไว้ก่อนแต่ยังไม่ผูก backend จริง** จนกว่า WYN-008 จะเสร็จ — `onPressed` ให้ toggle แค่ local UI state ชั่วคราว (ไม่เขียนลง DB) พร้อม comment ในโค้ดชี้ไปที่ WYN-008 ชัดเจน ป้องกันไม่ให้ AI Coding ลืมว่าเป็น placeholder แล้วเข้าใจผิดว่า Follow ทำงานจริง
- Video ที่เลื่อนออกจอต้อง dispose controller ทันที ห้ามปล่อยเล่นเบื้องหลังค้าง — ย้ำเพราะเป็นความเสี่ยง memory leak ใหม่ที่ไม่เคยเจอในฟีเจอร์รูปภาพมาก่อน (Drop/Feed ไม่มีปัญหานี้)
- ห้ามใช้ Liquid Glass บน overlay ใด ๆ ที่ทับวิดีโอ — ใช้ gradient scrim ทึบเท่านั้น

Handoff: AI Coding — ใช้ `PageView` แนวตั้ง (`scrollDirection: Axis.vertical`) + `video_player` package (มาตรฐานของ Flutter ไม่ต้องเพิ่ม package แปลกใหม่) เล่นเฉพาะ page ที่ active (`onPageChanged` ควบคุม play/pause/dispose ของ controller ทีละตัว ไม่สร้าง controller ล่วงหน้าทุกคลิปพร้อมกัน) reuse `DropRepository`/`DropComment`/`DropDetailScreen`'s comment-list-with-Like-and-Delete pattern ตรง ๆ (เปลี่ยนชื่อ/ปรับให้เหมาะกับ Pop repository ใหม่ ไม่ต้องคิดใหม่)

---

## Screen 2: Create Pop

Purpose: ให้ผู้ใช้เลือก/ถ่ายวิดีโอ (สูงสุด 60 วินาที), เขียนแคปชัน (พร้อม hashtag/mention แบบพิมพ์อย่างเดียว), แล้วโพสต์

User Flow: จาก Pop Feed กด "+" → เลือกวิดีโอจากคลัง/ถ่ายใหม่ → ถ้ายาวเกิน 60 วิ แจ้ง error ทันที ให้เลือกใหม่ → เห็น preview เล่นวิดีโอได้ (มี play/pause) + เขียนแคปชัน → กด "แชร์" → กลับ Pop Feed เห็น Pop ใหม่ (อัปโหลดเสร็จ)

Components:
- AppBar: ปุ่มปิด (กากบาท ซ้าย) + title "Pop ใหม่" + ปุ่ม "แชร์" (primary action, ขวาสุด)
- ขั้นตอนเลือกวิดีโอ: action sheet เดียวกับ pattern ของ WYN-003/004/005 (ถ่ายวิดีโอใหม่ / เลือกจากคลัง)
- Preview วิดีโอ 9:16 เต็มความกว้างจอ พร้อมปุ่ม play/pause กลางจอ (แตะเพื่อดูตัวอย่างก่อนโพสต์จริง)
- Text field แคปชัน ใต้ preview — placeholder "เขียนแคปชัน... ใส่ #hashtag หรือ @mention ได้" (เหมือน WYN-005)
- ตัวนับตัวอักษร (max 500, pattern เดียวกับ WYN-003/005)
- แถบแสดงความยาววิดีโอ (เช่น "0:45 / 0:60") ใต้ preview

Interactions:
- เลือก/ถ่ายวิดีโอแล้ว → ตรวจความยาวทันที ถ้า > 60 วิ แสดง error "วิดีโอยาวเกิน 60 วินาที เลือกคลิปสั้นกว่านี้" ไม่รับไฟล์ (ไม่ตัดอัตโนมัติในรอบนี้ — ตัดต่อ/trim เป็น nice-to-have ทีหลัง)
- ปุ่ม "แชร์" **disable จนกว่าจะมีวิดีโอที่ผ่านการตรวจความยาวแล้ว** (เหมือนที่รูปภาพเป็นบังคับสำหรับ Drop)
- พิมพ์ `#คำ`/`@username` ในแคปชัน → บันทึกข้อความดิบอย่างเดียว ไม่ต้อง autocomplete/highlight (เหมือน WYN-005 — Founder ยืนยันขอบเขตนี้แล้ว)
- กด "แชร์" → upload วิดีโอ (+ thumbnail จาก frame แรก) → สร้าง Pop → loading บนปุ่มระหว่างรอ (อัปโหลดวิดีโอใช้เวลานานกว่ารูปมาก — ต้องมี progress indicator ไม่ใช่แค่ spinner เฉย ๆ ถ้าทำได้) → สำเร็จปิดหน้าจอกลับ Pop Feed

States:
- ยังไม่ได้เลือกวิดีโอ — placeholder สี่เหลี่ยมสัดส่วน 9:16 สี Soft Gray พร้อมไอคอน + ข้อความ "แตะเพื่อเลือกวิดีโอ"
- Video picking (native picker กำลังเปิด)
- ตรวจสอบความยาว (สั้นมาก อาจไม่ต้องแสดง state แยกถ้าตรวจเร็ว)
- มีวิดีโอแล้ว, กำลังพิมพ์แคปชัน (ปกติ)
- Sharing (กำลัง upload + สร้าง Pop) — disable ทุก input, ปุ่ม "แชร์" แสดง progress/spinner
- Error (แชร์ไม่สำเร็จ, หรือวิดีโอยาวเกิน) — inline error เหนือปุ่ม ไม่เสียวิดีโอ/แคปชันที่เลือกไว้ (ยกเว้น error ความยาวที่ต้องเลือกใหม่)

Responsive Behavior: Preview คงสัดส่วน 9:16 เสมอ แคปชัน scroll ได้อิสระถ้ายาว

Accessibility: พื้นที่ placeholder มี label "แตะเพื่อเลือกหรือถ่ายวิดีโอ" ปุ่ม "แชร์" ที่ disable ประกาศเหตุผล (เช่น "ต้องมีวิดีโอที่ความยาวไม่เกิน 60 วินาทีก่อนถึงจะแชร์ได้")

Design Rules: **จำกัดความยาว 60 วินาทีเป็นการตัดสินใจลดขอบเขตโดยเจตนา** (เหมือนที่ WYN-005 ยอมรับ auto-crop แบบไม่มี interactive drag) — trim/ตัดต่อวิดีโอเป็น nice-to-have เสนอทำรอบถัดไปถ้า Founder ต้องการ ไม่ block WYN-006 รอบแรก

Handoff: AI Coding — ใช้ `image_picker` (`pickVideo`, มีอยู่แล้วในโปรเจกต์) ตรวจความยาวผ่าน `video_player`'s `VideoPlayerController.initialize()` แล้วเช็ค `controller.value.duration` ก่อนอนุญาตให้แชร์ generate thumbnail จาก frame แรกด้วย `video_thumbnail` package หรือเทียบเท่า (package ใหม่ — ต้องเพิ่มใน `pubspec.yaml`) เขียน parser หา `#hashtag`/`@mention` จาก caption string ใช้ฟังก์ชันเดียวกับที่มีอยู่แล้วถ้า WYN-005 แยกออกมาเป็น utility (ถ้ายังไม่แยก ให้แยกตอนนี้เพื่อไม่ให้โค้ดซ้ำ)

---

## สรุป Flow รวม

```
Pop Feed (vertical swipe) ──(กด "+")──> Create Pop ──(แชร์สำเร็จ)──> กลับ Pop Feed (เห็น Pop ใหม่)
Pop Feed ──(กด Comment)──> Comment Sheet (overlay, วิดีโอเล่นต่อเบื้องหลัง) ──(ปิด sheet)──> กลับดู Pop เดิม
```

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement ทั้ง 2 หน้าจอข้างต้น — ต้องสร้างตาราง `pops`/`pop_likes`/`pop_comments`/`pop_comment_likes` ใน Supabase พร้อม RLS (pattern เดียวกับ `drops`/`drop_likes`/`drop_comments`/`drop_comment_likes` ของ WYN-005 **ทุกประการ รวมถึง Like Comment และ Delete Comment ตั้งแต่ตาราง schema แรก**), Storage bucket ใหม่แยกจาก `drop-images` สำหรับวิดีโอ (เช่น `pop-videos`) และอีก bucket/field สำหรับ thumbnail, เพิ่ม view count field/ตารางนับ view, ใช้ตาราง `saves` เดิมของ WYN-005 (`content_type = 'pop'`) ไม่ต้อง migrate schema ใหม่ อัปเดต `RootShell` ให้แท็บ Pop ชี้ไปหน้าจอจริงแทน placeholder "เร็ว ๆ นี้" ต้อง QA & Security ตรวจสอบก่อน deploy เสมอ (ห้ามข้าม QA) — เน้นตรวจ **Comment ครบทั้ง 3 ความสามารถตั้งแต่รอบแรก**, video controller dispose ถูกต้อง (memory leak), double-tap guard ของ Like/Save/Follow เหมือนที่ตรวจทุกฟีเจอร์ก่อนหน้า
