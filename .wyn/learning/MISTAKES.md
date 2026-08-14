# Mistakes Log

บันทึกข้อผิดพลาดที่เกิดขึ้น เพื่อป้องกัน QA และทีมไม่ให้พลาดซ้ำ

## รูปแบบ

```
### [YYYY-MM-DD] Task WYN-XXX
- ข้อผิดพลาด:
- ผลกระทบ:
- วิธีป้องกันในอนาคต:
- Regression test ที่เพิ่ม (ถ้ามี):
```

## รายการ

### [2026-08-13] Task WYN-002
- ข้อผิดพลาด: (1) `AuthGate` ฟังแค่ Supabase auth-state event แต่หน้า Welcome/AuthMethod/Phone/OTP ถูก push ทับไว้ด้านบนโดยไม่มีจุด pop กลับ ทำให้ผู้ใช้ค้างหน้าเดิมหลัง sign-in สำเร็จทุกเส้นทาง (Google/Apple/Phone) ไม่ใช่แค่ตอนตั้ง username ตามที่ QA รายงานไว้ในตอนแรก (2) `setUsername()` ไม่ catch unique-constraint violation จริงจาก race condition (3) OTP input ใช้ช่องเดียวแทนที่จะเป็น 6 ช่องแยกตาม design spec
- ผลกระทบ: ผู้ใช้ทุกคนที่ sign-in สำเร็จ (ไม่ว่าวิธีไหน) จะไม่เห็นหน้าจอเปลี่ยนอัตโนมัติ ต้อง force-restart แอป — เป็น blocker ที่ทำให้ onboarding ใช้งานไม่ได้เลยถ้าไม่แก้
- วิธีป้องกันในอนาคต: เมื่อออกแบบ flow ที่มี auth-state gate ผสมกับหลายหน้า push ต่อกัน ให้ระบุจุด pop-back ชัดเจนตั้งแต่ตอน Design/Coding ไม่ใช่รอ QA มาเจอ และ AI Coding ควร inject dependency (เช่น `AuthRepository`) แบบ testable มากกว่านี้ เพื่อให้เขียน regression test ครอบคลุม navigation behavior ได้ (ตอนนี้ `AuthGate` สร้าง `AuthRepository` เองภายใน ทำให้ยังเขียน widget test สำหรับ pop-back behavior ไม่ได้)
- Regression test ที่เพิ่ม: `app/test/otp_box_input_test.dart` (4 เคส ครอบคลุมปัญหา #3 เต็มรูปแบบ) — ปัญหา #1 (pop-back) และ #2 (race condition) ยังไม่มี automated regression test เพราะสถาปัตยกรรมปัจจุบันไม่รองรับการ inject fake backend ได้ง่าย (บันทึกเป็นข้อเสนอปรับปรุงใน `.wyn/learning/IMPROVEMENTS.md`)

### [2026-08-13] Task WYN-004
- ข้อผิดพลาด: `FeedScreen._toggleLike(Post post)` รับ `post` เป็น parameter ที่ถูก capture ไว้ตอน build ล่าสุด แล้วใช้ค่านั้นตัดสินใจ insert/delete ใน `likes` table — ไม่ได้อ่าน `_posts[index]` สดใหม่ในตัว method เอง (ต่างจาก `PostDetailScreen._toggleLike()` ที่เขียนถูกต้องอยู่แล้วในไฟล์ชุดเดียวกัน) ผลคือกดปุ่ม Like ซ้ำเร็ว ๆ ก่อนหน้าจอ rebuild ทำให้ทั้งสอง network call ใช้ค่าเดิมผิด ๆ ซ้ำกัน เสี่ยง duplicate insert ที่ violate primary key แล้ว rollback UI กลับไปสถานะผิด แบบเงียบ ๆ (ไม่แสดง error) — จุดเดียวกันนี้เกิดซ้ำในรูปแบบอื่นที่ `CreatePostScreen._post()` ซึ่งไม่มี `if (_isPosting) return;` guard เลย เปิดช่องให้กดปุ่ม "โพสต์" ซ้ำสร้างโพสต์ซ้ำได้
- ผลกระทบ: กระทบ Acceptance Criteria หลักของ WYN-004 โดยตรง ("กดไลก์แล้วเห็นจำนวนเพิ่มทันที กดซ้ำเพื่อเลิกไลก์ได้") — เป็นบั๊กที่เกิดได้จริงบนมือถือ (ผู้ใช้ใจร้อน/เครื่อง lag) ไม่ใช่แค่ทฤษฎี
- วิธีป้องกันในอนาคต: เมื่อ widget เดียวกันมี async button handler มากกว่า 1 จุดที่ทำงานคล้ายกัน (เช่น toggle like ทั้งใน Feed และ Post Detail) ให้ AI Coding ใช้ pattern เดียวกันทุกจุดตั้งแต่แรก (อ่าน mutable state สดใหม่ในตัว method เสมอ ไม่รับเป็น parameter/closure ที่ capture ไว้ตอน build) และทุกปุ่มที่เรียก async operation ที่ไม่ควรถูกเรียกซ้อนกัน ต้องมี explicit guard (`if (_isXxx) return;`) เป็นบรรทัดแรกของ handler เสมอ ไม่ใช่พึ่งแค่ disabled state ของปุ่มซึ่ง lag ไปหนึ่ง frame เสมอ
- Regression test ที่เพิ่ม: `app/test/feed_screen_test.dart`, `app/test/create_post_screen_test.dart` — พิสูจน์ทั้งสองจุดได้จริงแบบ dynamic โดยเรียก widget's `onPressed` callback สองครั้งติดกันแบบ synchronous (แม่นยำกว่า `tester.tap()` สองครั้งซึ่งเป็น async และปล่อยให้ call แรกทำงานจบก่อนได้) ใช้เทคนิคใหม่ 2 อย่างที่ทำให้ testable: (1) `RecordingPostRepository` — subclass ของ `PostRepository` ที่ override method แทนการเพิ่ม interface ใหม่ (2) `fake_supabase_session.dart` — ปลอม signed-in session แบบ local-only (ไม่ยิง network จริง) ให้ widget ที่พึ่ง `Supabase.instance.client.auth.currentUser` ตรง ๆ (เช่น `FeedScreen`) pump ได้ในการทดสอบ — บันทึกเป็น pattern ใหม่ใน `.wyn/learning/PATTERNS.md`

### [2026-08-14] Task WYN-005
- ข้อผิดพลาด: ทั้ง Product spec และ Design spec ของ WYN-005 ระบุ "Like Comment" ไว้ตรงกันชัดเจน (Product's Requirements: "Like Comment ได้"; Design's Screen 3 Components: "ปุ่ม Like เล็ก ๆ ข้างคอมเมนต์") แต่ AI Coding implement ข้ามฟีเจอร์นี้ไปทั้งระบบ — ไม่มีทั้งตาราง DB, repository method, และปุ่ม UI เลยแม้แต่จุดเดียว โดยไม่ได้บันทึกไว้เป็น known/deferred scope เหมือนจุดอื่นที่ตัดออกอย่างตั้งใจ (เช่น hashtag click-through ที่ Founder ยืนยันแล้วว่าทำทีหลัง) — แสดงว่าเป็นการมองข้ามจริง ไม่ใช่การตัดขอบเขต
- ผลกระทบ: กระทบ requirement ที่ระบุไว้ตรงกันในสองเอกสาร (Product + Design) — ถ้า QA ไม่ได้เทียบ requirement/component list ทีละบรรทัดกับโค้ดจริง จะไม่มีทางจับได้เลยเพราะ flow หลัก (โพสต์, ไลก์ Drop, คอมเมนต์, Save) ทำงานถูกต้องปกติทุกอย่าง มีแค่ปุ่มเดียวที่หายไปเงียบ ๆ
- วิธีป้องกันในอนาคต: AI Coding ควรไล่ checklist ทุกบรรทัดของทั้ง Product Requirements และ Design Components ก่อนส่งงาน (ไม่ใช่แค่ implement ตามความเข้าใจคร่าว ๆ ของ flow หลัก) และ AI QA & Security ควรเทียบ requirement/component list ทีละบรรทัดกับโค้ดจริงเสมอเป็นขั้นตอนบังคับ ไม่ใช่แค่ทดสอบ flow หลักแล้วผ่าน
- Regression test ที่เพิ่ม: `app/test/drop_comment_like_test.dart` (double-tap safety ของปุ่ม Like Comment ใหม่ พิสูจน์แล้วว่า fail จริงก่อนแก้/pass หลังแก้), `app/test/drop_comment_test.dart` (ขยายให้ครอบคลุม `toggledLike`/`likeCount` field ใหม่) — ระหว่างเขียน regression test เจอ gotcha ของ Flutter testing เพิ่มเติม (ไม่ใช่บั๊กจริงในโค้ด) บันทึกไว้ที่ `.wyn/learning/PATTERNS.md`: `find.byType()`/`find.text()` มองไม่เห็น widget ที่อยู่นอก viewport ใน `ListView`/`Sliver` ต้อง `scrollUntilVisible` ก่อนเสมอ

### [2026-08-14] Task WYN-005 (QA รอบ 2)
- ข้อผิดพลาด: หลัง Debug Engineer แก้บั๊ก "Like Comment" หายจากรอบ 1 แล้ว QA รอบ 2 ไล่ตรวจ Acceptance Criteria ทุกบรรทัดใหม่ทั้งหมด (ไม่ใช่แค่จุดที่เพิ่งแก้) พบว่า **"ลบ Comment ของตัวเองได้" ก็หายไปทั้งระบบเช่นกัน** — Product spec ระบุไว้ตรง ๆ ทั้งใน Requirements ("ลบ Comment ของตัวเองได้") และ Acceptance Criteria ("ลบคอมเมนต์ของตัวเองได้") แต่ `DropRepository` ไม่มี `deleteComment` เลย และ `DropDetailScreen` ไม่มีปุ่มลบหรือแม้แต่การเทียบ `comment.authorId == currentUserId` เลยสักจุด (ต่างจาก `isOwnDrop` ที่เทียบไว้ถูกต้องสำหรับตัว Drop เอง) — DB level มี RLS delete policy รองรับไว้แล้วตั้งแต่รอบ Coding แรก แต่ไม่มี client path ไปถึงมันเลย เหมือนกับกรณี Like Comment ในรอบ 1 เป๊ะ ตรวจสอบแล้วว่าไม่ใช่ gap ที่สืบทอดจาก WYN-004 (WYN-004 มี requirement แค่ "ลบโพสต์" ไม่เคยมี "ลบ comment") และ Design spec เองก็ไม่ได้ระบุปุ่มลบคอมเมนต์ไว้ใน Component list เช่นกัน (Design พลาดจุดนี้ตั้งแต่ต้น ไม่ใช่แค่ Coding)
- ผลกระทบ: กระทบ Acceptance Criteria ที่ระบุไว้ตรง ๆ ใน Product spec — Comment มี 3 ความสามารถ (เพิ่ม/ลบ/Like) แต่ทำงานจริงแค่ 2/3 แม้จะผ่าน Debug รอบ 1 มาแล้ว
- วิธีป้องกันในอนาคต: QA ต้องไล่ **ทุกหัวข้อ** ของ spec แยกกัน (Requirements, Design Component list, **และ** Acceptance Criteria) ทีละบรรทัดเสมอ ไม่ใช่แค่หัวข้อเดียว เพราะแต่ละหัวข้ออาจระบุรายละเอียดที่หัวข้ออื่นไม่ได้พูดถึง และ QA รอบถัดไปของ task ที่เคย FAIL ต้องไล่ checklist แบบครบทุกหัวข้อใหม่ทั้งหมดเสมอ ไม่ใช่แค่ตรวจจุดที่ Debug เพิ่งแก้เท่านั้น — Design ก็ควรไล่ checklist ทุกบรรทัดของ Product Requirements ก่อนออกแบบ Component list เช่นกัน ไม่ใช่แค่ Coding
- Regression test ที่เพิ่ม: ยังไม่มี (บั๊กเพิ่งถูกพบในรอบ QA — จะถูกเพิ่มพร้อมกับ fix ในรอบ Debug ถัดไป)
