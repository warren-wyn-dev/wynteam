# Product Task — WYN-005

Status: review (AI Coding เสร็จแล้ว รอส่งต่อ AI QA & Security)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (ถัดไป)

Feature: Drop (โพสต์รูปภาพ)

Goal: ให้ผู้ใช้โพสต์รูปภาพพร้อมแคปชัน hashtag และ mention ได้ เป็นเนื้อหาหลักประเภทแรกของ WYN V0.1 ตาม spec ใหม่ ("WYN V0.1 — CORE APP FEATURE PROMPT" ดู `.wyn/company/DECISIONS.md` 2026-08-14)

Target User: วัยรุ่น / Gen Z ที่ต้องการแชร์รูปภาพและมีปฏิสัมพันธ์กับโพสต์ของคนอื่น

Problem: หลังเปลี่ยนทิศทาง Product ใหม่ WYN ยังไม่มีฟีเจอร์โพสต์รูปภาพแบบที่ spec ใหม่ต้องการ (Feed & Post เดิมจาก WYN-004 รวมข้อความ+รูปในโพสต์เดียว ไม่ตรงกับที่ spec ใหม่ต้องการให้ Drop เป็นระบบรูปภาพโดยเฉพาะ)

Requirements:
- **สร้าง Drop**: กดปุ่ม "+ Create Drop" แล้ว:
  - เลือกรูปภาพจากอุปกรณ์ หรือถ่ายรูปใหม่
  - เขียน Caption
  - เพิ่ม Hashtag ในแคปชัน (พิมพ์ `#คำ` ระบบรู้จำ — ยังไม่ต้องทำหน้ารวมผลลัพธ์ hashtag ในรอบนี้ ผูกกับ WYN-009)
  - Mention ผู้ใช้ในแคปชัน (พิมพ์ `@username` ระบบรู้จำ — ยังไม่ต้องส่ง Notification ในรอบนี้ ผูกกับ WYN-012)
  - กด Post
- **รูปภาพ**: อัตราส่วน Square / 1:1 เป็นหลัก (ตาม spec) — crop หรือ constrain ให้เป็น 1:1 ตอนแนบรูป
- **แสดงผล Drop แต่ละอัน**: Profile picture, Username, รูปภาพ, Caption, ปุ่ม Like/Comment/Share/Save, จำนวน Like, จำนวน Comment
- **Like**: กด Like/Unlike ได้ เห็นจำนวนอัปเดตทันที
- **Comment**: เพิ่ม Comment ได้, ลบ Comment ของตัวเองได้, Like Comment ได้
- **Share**: Share Content ออกไปนอกแอป + Copy Link (ขอบเขตเบื้องต้น:ใช้ share sheet ของระบบปฏิบัติการ + generate ลิงก์ไปหน้า Drop นั้น)
- **Save**: บันทึก Drop ไว้ดูทีหลังได้ (แสดงใน Profile → Saved ที่ WYN-013 จะทำ)
- ผู้ใช้ลบ Drop ของตัวเองได้

Acceptance Criteria:
- [ ] กดปุ่ม "+ Create Drop" เลือกรูปจากอุปกรณ์หรือถ่ายใหม่ พิมพ์ caption (มี/ไม่มี hashtag/mention ก็โพสต์ได้) กด Post แล้วเห็น Drop ใหม่ปรากฏทันที
- [ ] Drop ที่ไม่มีรูปภาพ โพสต์ไม่ได้ (รูปภาพเป็น**บังคับ**สำหรับ Drop ต่างจาก Feed & Post เดิมที่เลือกได้ระหว่างข้อความ/รูป — นี่คือความแตกต่างสำคัญจาก WYN-004 ที่ AI Design/Coding ต้องรู้)
- [ ] รูปภาพแสดงเป็นสี่เหลี่ยมจัตุรัส (1:1) สม่ำเสมอทุก Drop ไม่ว่าไฟล์ต้นฉบับจะเป็นสัดส่วนใด
- [ ] กดไลก์ Drop แล้วเห็นจำนวนไลก์เพิ่มทันที กดซ้ำเพื่อเลิกไลก์ได้ (ต้องไม่มีบั๊ก double-tap แบบที่เจอใน WYN-004 QA รอบ 1 — ดู `.wyn/learning/PATTERNS.md`)
- [ ] คอมเมนต์ได้ ลบคอมเมนต์ของตัวเองได้ กด Like คอมเมนต์ได้
- [ ] กด Share เปิด share sheet ของระบบ หรือ copy ลิงก์ไปยัง clipboard ได้
- [ ] กด Save แล้วบันทึกไว้ได้ (ที่เก็บจริงไปแสดงใน Profile รอ WYN-013)
- [ ] ผู้ใช้เห็นปุ่มลบเฉพาะ Drop ของตัวเองเท่านั้น
- [ ] ผู้ใช้อื่นแก้ไข/ลบ Drop ของเราไม่ได้ (RLS บังคับ)
- [ ] ผู้ใช้อื่นลบไลก์/คอมเมนต์/save ของเราแทนเราไม่ได้ (RLS บังคับ)

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved)

Priority: P0 — สูงสุดในรอบใหม่นี้ (ดูเหตุผลเต็มที่ `.wyn/docs/product/wyn-v0.1-roadmap.md`)

Risks:
- Save ต้องมีที่เก็บข้อมูล (ตาราง `saves` หรือคล้ายกัน) แต่หน้าจอแสดงผล (Profile → Saved) อยู่ใน WYN-013 — ต้องออกแบบ schema ให้รองรับทั้งสอง task ตั้งแต่รอบนี้เพื่อไม่ต้อง migrate ซ้ำ
- Share ที่ "Copy Link" ต้องมี URL scheme/deep link ที่ใช้งานได้จริง — ถ้ายังไม่มี hosting/domain จริง อาจทำได้แค่ copy ข้อความ placeholder ก่อน ต้องคุยกับ Founder เรื่อง domain ก่อน Deploy จริง
- ยังไม่มี Content Moderation (นอก scope เหมือน WYN-004)

Founder ยืนยันแล้ว (2026-08-14 ดู `.wyn/company/DECISIONS.md`):
- Hashtag/Mention รอบนี้ทำแค่ "พิมพ์ในแคปชันได้ ระบบจำ/บันทึกได้" — แตะแล้วไปหน้าค้นหา/โปรไฟล์ผูกกับ WYN-009 ทีหลัง
- Follow (WYN-008 เมื่อถึงคิว) จะใช้ได้กับ Drop ด้วย ไม่ใช่แค่ Pop
- Home Feed (WYN-007) จะเป็น Global ก่อน ไม่กรองตาม Follow

Recommendation: เริ่มที่ WYN-005 ก่อนฟีเจอร์อื่นทั้งหมดในรอบใหม่ ตามที่ Founder อนุมัติแล้ว

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบหน้าจอ Drop Feed, Create Drop, Drop Detail

---

## Coding Output (AI Coding)

Implementation:
- Database: เพิ่ม section WYN-005 ใน `supabase/schema.sql` — ตาราง `drops` (image_url NOT NULL ต่างจาก posts, caption optional พร้อม CHECK ความยาว), `drop_likes`, `drop_comments` (pattern เดียวกับ WYN-004 ทุกประการ), และ `saves` (ออกแบบด้วย `content_type` + `content_id` แทนการอ้างอิงตรงไปที่ `drops` เพื่อให้ WYN-011 เพิ่ม Pop เข้ามาทีหลังได้โดยไม่ต้อง migrate ซ้ำ — ตาม Risk ที่ Product ระบุไว้) `saves` มี RLS select เฉพาะของตัวเอง (ต่างจาก likes/comments ที่ select-all-authenticated) เพราะ Saved list ควรเป็นส่วนตัวตาม convention ทั่วไป (IG/Twitter Bookmarks) เพิ่ม storage bucket `drop-images`
- `lib/features/drop/data/`: `drop.dart`, `drop_comment.dart` (model + `fromMap`, mิเรอร์ `post.dart`/`comment.dart` ของ WYN-004), `drop_repository.dart` (fetchFeed แบบ grid pagination page size 21 — หาร 3 ลงตัวพอดีเติมแถวเต็มเสมอ, createDrop บังคับต้องมีรูป, toggleLike, toggleSave, fetchComments, addComment, deleteDrop), `square_crop.dart` (center-crop เป็น 1:1 ด้วย `dart:ui` ล้วน ไม่ต้องเพิ่ม package ตามที่ design spec แนะนำ)
- `lib/features/drop/presentation/`: `drop_feed_screen.dart` (grid 3 คอลัมน์ผ่าน `SliverGrid`, infinite scroll + pull-to-refresh pattern เดียวกับ WYN-004), `create_drop_screen.dart` (เลือก/ถ่ายรูป → auto center-crop → แคปชัน → แชร์, ปุ่มแชร์ disable จนกว่าจะมีรูป), `drop_detail_screen.dart` (รูปเต็ม + แคปชัน + Like/Comment/Share/Save + คอมเมนต์ **รวมเป็น ListView เดียวตั้งแต่แรก** ตามที่ design spec เตือนไว้ ไม่ให้พลาดซ้ำแบบ WYN-004), widgets: `drop_grid_tile.dart` (grid tile + like-count scrim), `confirm_delete_drop_dialog.dart` (wrap `confirmDeletePost` เดิมของ WYN-004 ที่ generalize ให้รับ `itemLabel` แล้ว ไม่สร้าง dialog ซ้ำ)
- `lib/features/root/presentation/root_shell.dart`: Bottom Navigation 4 แท็บ (Home/Drop/Pop/Profile) ผ่าน `IndexedStack` — Home/Pop เป็น placeholder "เร็ว ๆ นี้" (ยังไม่ implement ตามลำดับ roadmap), Drop คือ `DropFeedScreen` เต็มรูปแบบ, Profile ใช้ `ViewProfileScreen` เดิมจาก WYN-003 ตรง ๆ ไม่มีการแก้ไข
- `AuthGate`: เปลี่ยนให้ return `RootShell` แทน `FeedScreen` เดิมของ WYN-004 เมื่อผู้ใช้ onboard ครบแล้ว — ตรวจสอบแล้วว่า popUntil(isFirst) logic เดิม (ป้องกันหน้าจอค้างหลัง sign-out) ยังทำงานถูกต้องเหมือนเดิมทุกกรณี เพราะ `RootShell` เป็น base route เดียวกับที่ `FeedScreen` เคยเป็น การสลับแท็บผ่าน `IndexedStack` ไม่แตะ Navigator stack เลย ส่วนหน้าที่ push จากภายในแต่ละแท็บ (เช่น `CreateDropScreen`, `EditProfileScreen`) ยัง pop กลับมาที่ base route ได้ถูกต้องเหมือนเดิม (ไล่ trace แล้ว ไม่ใช่แค่เดา)
- `main.dart`: เปลี่ยน `colorSchemeSeed` เป็นสีน้ำเงิน (`#2D6CDF`) ตาม Color Direction ใหม่ที่ Founder กำหนด แทนสีม่วงเดิม
- เพิ่ม dependency `share_plus` (จำเป็นสำหรับปุ่ม Share ตาม spec — ไม่มีทางทำ native share sheet ได้โดยไม่มี package นี้) ลิงก์ที่แชร์/copy เป็น placeholder domain (`wyn.app`) เพราะยังไม่มี domain จริง (ตาม Risk ที่ Product ระบุไว้ — ต้องทบทวนก่อน Deploy จริง)

Files Changed:
- `supabase/schema.sql` (เพิ่ม section WYN-005)
- `app/lib/features/drop/` (ใหม่ทั้งหมด — data/ 3 ไฟล์, presentation/ 3 screens + 2 widgets)
- `app/lib/features/root/presentation/root_shell.dart` (ใหม่)
- `app/lib/features/auth/presentation/auth_gate.dart`, `username_setup_screen.dart` (ชี้ไป `RootShell` แทน `FeedScreen`)
- `app/lib/features/feed/presentation/widgets/confirm_delete_dialog.dart` (generalize รับ `itemLabel` — backward compatible, ไม่กระทบ call site เดิมของ WYN-004)
- `app/lib/main.dart` (สี Primary ใหม่)
- `app/pubspec.yaml` (เพิ่ม `share_plus`)
- `app/test/drop_test.dart`, `drop_comment_test.dart`, `square_crop_test.dart`, `create_drop_screen_test.dart`, `drop_detail_screen_test.dart`, `drop_grid_tile_test.dart`, `support/recording_drop_repository.dart` (ใหม่ทั้งหมด)

Reason: implement ตาม Product spec + Design Spec ของ WYN-005 (`.wyn/docs/design/wyn-005-drop.md`) ครบตามขอบเขตที่ Founder ยืนยัน (auto-crop 1:1, hashtag/mention พิมพ์อย่างเดียว, Like/Comment/Share/Save, grid feed แยกจาก Home)

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 59/59 ผ่านทั้งหมด (รวม test ใหม่ 22 เคสของ WYN-005)
- **ป้องกันบั๊ก double-tap แบบ WYN-004 เชิงรุก**: `DropDetailScreen._toggleLike`/`_toggleSave` อ่าน `_drop` field สดใหม่ทุกครั้งที่ถูกเรียก (mirror pattern ที่ถูกต้องของ `PostDetailScreen` ไม่ใช่ pattern ที่เคยผิดของ `FeedScreen` เดิม) ส่วน `CreateDropScreen._share` มี `if (_isSharing) return;` guard ตั้งแต่เขียนครั้งแรก — DropFeedScreen (grid) ไม่มีปุ่ม Like/Save แบบ interactive ต่อ tile เลยตาม design spec (มีแค่ scrim แสดงจำนวน) จึงไม่มีพื้นผิวที่จะเกิดบั๊กคลาสเดียวกับ `FeedScreen` เดิมได้ตั้งแต่ต้น
- **ป้องกันบั๊ก layout overflow แบบ WYN-004 เชิงรุก**: `DropDetailScreen` รวม header + comment list เป็น `ListView` เดียวตั้งแต่เขียนครั้งแรก มี regression test (`drop_detail_screen_test.dart`) ยืนยันด้วย viewport กว้าง/เตี้ยเหมือนที่ WYN-004 เจอปัญหา

Build: ยังไม่ได้ build จริง (`flutter build apk/ios`) — sandbox นี้ไม่มี Android SDK/Xcode ให้ verify ได้

Known Issues:
- Crop เป็น center-crop อัตโนมัติเท่านั้น ไม่มี interactive drag-to-reposition (ตามที่ design spec ยอมรับเป็น known limitation ของรอบนี้)
- Share/Copy Link ใช้ placeholder domain (`wyn.app`) ที่ไม่ใช่ URL จริงที่เข้าถึงได้ — ต้องทบทวนก่อน Deploy จริงเมื่อ Founder ยืนยัน domain
- Hashtag/Mention ยังเป็นแค่ข้อความดิบใน caption ไม่มี parsing/แตะได้ (ตามขอบเขตที่ Founder ยืนยันแล้วว่าทำทีหลังใน WYN-009)
- ยังไม่ทดสอบกับ Supabase project จริง (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า)
- `FeedScreen`/`PostRepository`/`PostCard` ของ WYN-004 (Feed & Post แบบรวม) **ยังไม่ถูกลบออกจากโค้ด** แม้จะไม่มี route ไหนชี้ไปแล้ว (ถูกแทนที่ด้วย `RootShell`) — Coding ตัดสินใจไม่ลบเพราะ "ลบ feature ที่ผ่าน QA แล้ว" เป็นการตัดสินใจที่ใหญ่กว่าขอบเขตงาน "implement WYN-005" เสนอให้ Founder/Product ตัดสินใจว่าจะลบทิ้งหรือ repurpose โค้ดบางส่วนไปใช้ตอนทำ WYN-007 (Home) ทีหลัง

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ WYN-005 ก่อนอนุมัติ deploy — เน้นตรวจ RLS ของ `saves` (select ต้องเป็นส่วนตัวจริง), การรวม header+comment list ของ Drop Detail, และ regression กับ WYN-002/003/004 จากการเปลี่ยน `AuthGate`/`confirm_delete_dialog.dart`
