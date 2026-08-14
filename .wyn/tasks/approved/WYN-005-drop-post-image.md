# Product Task — WYN-005

Status: approved (QA รอบ 3 — PASS)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — FAIL รอบ 1) → AI Debug Engineer (เสร็จ — รอบ 1) → AI QA & Security (เสร็จ — FAIL รอบ 2) → AI Debug Engineer (เสร็จ — รอบ 2) → AI QA & Security (เสร็จ — PASS รอบ 3) → AI Deploy & DevOps (รอ infra จาก Founder)

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

---

## QA & Security Report — รอบ 1 (AI QA & Security)

Feature: WYN-005 — Drop (โพสต์รูปภาพ)

Environment: Code review + static analysis บน `main` หลัง merge PR #28 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับ WYN-002/003/004 (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. **เทียบ Requirements ของ Product spec + Component list ของ Design spec กับโค้ดจริงทีละบรรทัด ไม่ใช่แค่เชื่อ Coding Output** (บทเรียนจาก WYN-002/003/004: QA ต้องไล่ trace เอง)
4. RLS ของ `drops`/`drop_likes`/`drop_comments`/`saves` เทียบกับ Acceptance Criteria (โดยเฉพาะ `saves` ต้อง select เป็นส่วนตัว)
5. Double-tap safety ของ Like/Save/Share ปุ่มต่าง ๆ (สืบเนื่องจากบั๊ก Major ที่เจอใน WYN-004 QA รอบ 1)
6. Layout: `DropDetailScreen` รวม header+comment list เป็น scrollable เดียวจริงหรือไม่ (สืบเนื่องจากบั๊กที่เจอใน WYN-004)
7. `square_crop.dart` ความถูกต้องของการ crop (landscape/portrait/square)
8. Regression WYN-002/003/004 จากการเปลี่ยน `AuthGate`, `confirm_delete_dialog.dart`, `main.dart` (สี)
9. Secret/credential exposure check ในโค้ดใหม่ทั้งหมด

Passed: 8/9 (#1, #2, #4, #5, #6, #7, #8, #9)

Failed: 1/9 (#3)

Severity: **Major**

### Failed Case #3 — Major: ไม่มีปุ่ม "Like Comment" เลย ทั้งที่ Product spec และ Design spec ระบุไว้ชัดเจน

Reproduction (เทียบเอกสารกับโค้ดจริง ไม่ใช่เดา):
1. Product spec (`.wyn/tasks/review/WYN-005-drop-post-image.md` หัวข้อ Requirements) ระบุไว้ตรง ๆ: **"Comment: เพิ่ม Comment ได้, ลบ Comment ของตัวเองได้, Like Comment ได้"**
2. Design spec (`.wyn/docs/design/wyn-005-drop.md` Screen 3: Drop Detail, หัวข้อ Components) ระบุไว้ตรง ๆ เช่นกัน: **"รายการ Comment (avatar เล็ก + ชื่อ + ข้อความ + เวลา + ปุ่ม Like เล็ก ๆ ข้างคอมเมนต์)"**
3. อ่านโค้ดจริงที่ `app/lib/features/drop/presentation/drop_detail_screen.dart` (comment list rendering, บรรทัดประมาณ 296-320): แต่ละคอมเมนต์แสดงแค่ `AvatarCircle` + ชื่อ + ข้อความ เท่านั้น **ไม่มีปุ่ม Like ติดอยู่กับคอมเมนต์เลยแม้แต่จุดเดียว**
4. ตรวจ `supabase/schema.sql` (WYN-005 section) ยืนยันว่าไม่มีตาราง `drop_comment_likes` หรือเทียบเท่าเลย — ยืนยันว่าไม่ใช่แค่ UI ที่ขาด แต่เป็น feature ที่ขาดทั้งระบบตั้งแต่ schema
5. ตรวจ `grep -rn "CommentLike\|comment_like\|likeComment"` ทั่วทั้ง `app/lib/features/drop/` และ `supabase/schema.sql` — ไม่พบแม้แต่ร่องรอยเดียว
6. ตรวจ Coding Output ของ WYN-005 (หัวข้อ Known Issues) — **ไม่ได้ระบุว่า "Like Comment" ถูกตัดออกจาก scope โดยตั้งใจ** ต่างจาก hashtag/mention click-through ที่ระบุชัดว่าตัดออกตามที่ Founder ยืนยันแล้ว แสดงว่านี่คือ oversight ไม่ใช่การตัดขอบเขตที่ตั้งใจ

Expected: ผู้ใช้กดปุ่ม Like เล็ก ๆ ข้างคอมเมนต์แต่ละอันได้ ตามที่ทั้ง Product และ Design ระบุไว้ตรงกัน

Actual: ไม่มีปุ่ม Like ให้กดที่คอมเมนต์เลยแม้แต่จุดเดียว — เป็นฟีเจอร์ที่ระบุไว้ชัดเจนในสองเอกสารแต่หายไปทั้งระบบ (ไม่มีทั้ง UI, repository method, และตาราง DB)

Security Findings:
- ไม่พบ secret/credential hardcode ในโค้ดใหม่ทั้งหมด
- RLS ของ `drops`/`drop_likes`/`drop_comments` ตรวจแล้วถูกต้องตาม pattern ของ WYN-004 ทุกประการ — `saves` ตรวจแล้วว่า select ถูกจำกัดเฉพาะ `auth.uid() = user_id` จริง (ไม่ใช่ select-all-authenticated แบบตารางอื่น) ตรงตามที่ Coding Output ระบุว่าตั้งใจให้เป็นส่วนตัว
- **[Low] `CreateDropScreen._pickImage`**: guard การกดเลือกรูปซ้ำเช็คแค่ `_isSharing` ไม่ได้เช็ค `_isCropping` ด้วย — เปิดช่องแคบ ๆ ให้ผู้ใช้เปิด picker ซ้ำระหว่างที่ยัง crop รูปแรกไม่เสร็จ (ต่างจาก native picker เองที่บล็อกอยู่แล้วระหว่างเปิดกล้อง/คลังภาพ ช่องโหว่มีแค่ช่วง crop สั้น ๆ) ผลกระทบแค่ UI แสดงรูปผิดขณะ race กัน ไม่มีการเขียนข้อมูลซ้ำหรือ data corruption เพราะยังไม่ได้กด "แชร์" — ไม่ block การอนุมัติแต่แนะนำให้แก้พร้อมกับรอบนี้เพราะแก้ง่าย (เพิ่ม `_isCropping` เข้า guard เดียวกับ `_isSharing`)
- **[Low] `centerCropToSquare` ไม่มี try/catch ครอบใน `_pickImage`**: ถ้ารูปเสียหาย/format แปลก ๆ จน decode ไม่ได้ จะเป็น unhandled exception เงียบ ๆ (ผู้ใช้ไม่เห็น error, แค่รูปไม่ถูกเลือก) — เป็น pattern เดิมที่มีอยู่แล้วในการเลือกรูปของ WYN-003/004 (ไม่ใช่ regression ใหม่) ระบุไว้เผื่อแก้พร้อมกันทั้งระบบในโอกาสถัดไป

Recommendation: ส่งกลับ AI Debug Engineer เพิ่มฟีเจอร์ "Like Comment" ให้ครบ (Major) — แนวทางที่แนะนำ:
- เพิ่มตาราง `drop_comment_likes` ใน `supabase/schema.sql` (pattern เดียวกับ `drop_likes` ทุกประการ: `comment_id` + `user_id` composite PK, RLS select-all-authenticated, insert/delete เฉพาะของตัวเอง)
- เพิ่ม `likeCount`/`likedByMe` ใน `DropComment` model + `toggledLike()` helper (mirror `Drop`/`Post` ที่มีอยู่แล้ว)
- เพิ่ม `toggleCommentLike`/`fetchLikedCommentIds` ใน `DropRepository`
- เพิ่มปุ่ม Like เล็ก ๆ ข้างคอมเมนต์ใน `DropDetailScreen` — **ต้องอ่าน state สดใหม่ในตัว handler เสมอ ไม่ capture ค่าตอน build** (ใช้ pattern เดียวกับที่ `DropDetailScreen._toggleLike`/`_toggleSave` ทำถูกอยู่แล้วสำหรับตัว Drop เอง หรือ pattern ของ `FeedScreen._toggleLike` ที่แก้บั๊กแล้วใน WYN-004 — ห้ามพลาดซ้ำรอบที่ 3)
- ถือโอกาสแก้ [Low] สองจุดข้างต้นพร้อมกัน (`_isCropping` เข้า guard, try/catch รอบ `centerCropToSquare`) เพราะแก้ง่ายและอยู่ในไฟล์เดียวกันที่กำลังแก้อยู่แล้ว
- เพิ่ม regression test คุ้มครองปุ่ม Like Comment ใหม่ (โดยเฉพาะ double-tap safety) ตาม pattern ที่มีอยู่แล้วใน `app/test/support/`

Final Status: **FAIL**

---

## Debug Engineer Report (AI Debug Engineer)

Bug: Major จาก QA รอบ 1 (ด้านบน) — ฟีเจอร์ "Like Comment" หายไปทั้งระบบ ทั้งที่ Product spec และ Design spec ระบุไว้ตรงกัน

Reproduction: ยืนยันตรงกับที่ QA รายงาน — อ่าน `app/lib/features/drop/presentation/drop_detail_screen.dart` (comment list rendering) ยืนยันว่าไม่มีปุ่ม Like ติดกับคอมเมนต์เลย และ `supabase/schema.sql` ไม่มีตาราง `drop_comment_likes`

Root Cause: ตอน implement WYN-005 (AI Coding) เขียน `DropDetailScreen`/`DropRepository`/schema โดยอ้างอิง pattern ของ WYN-004 (posts/likes/comments) เป็นหลัก แต่ WYN-004 ไม่เคยมี "Like Comment" (มีแค่ Like Post/Delete Comment) จึงไม่มี pattern ให้อ้างอิงตรง ๆ — เมื่อ implement ตาม mental model ของ "โครงสร้างคล้าย WYN-004" แทนที่จะไล่ checklist ทีละบรรทัดจาก Product Requirements/Design Components ใหม่ของ WYN-005 เอง จึงพลาดข้อกำหนดที่ไม่เคยมีมาก่อนไปทั้งหมด

Fix:
- เพิ่มตาราง `drop_comment_likes` (`comment_id`+`user_id` composite PK, RLS select-all-authenticated + insert/delete เฉพาะของตัวเอง — pattern เดียวกับ `drop_likes` ทุกประการ) ใน `supabase/schema.sql`
- เพิ่ม `likeCount`/`likedByMe` field และ `toggledLike()`/`copyWith()` helper ใน `DropComment` model
- เพิ่ม `toggleCommentLike`/`_fetchLikedCommentIds` ใน `DropRepository`, ปรับ `fetchComments` ให้ join `drop_comment_likes(count)` และคำนวณ `likedByMe` ต่อคอมเมนต์ (mirror `fetchFeed`'s pattern สำหรับ `likedByMe`/`savedByMe` ของ Drop เอง), ปรับ `addComment` ให้ return คอมเมนต์ใหม่ด้วย `likedByMe: false` (คอมเมนต์ใหม่ยังไม่มีใครกดไลก์ได้)
- ปรับ `DropDetailScreen`: เปลี่ยนจาก cache `Future<List<DropComment>>` ที่ `.then()` ต่อกันเรื่อย ๆ (แก้ไข item เดี่ยว ๆ ในนั้นไม่ได้) เป็น mutable `List<DropComment>? _comments` field ตรง ๆ (mirror `FeedScreen._posts` ของ WYN-004) แล้วเพิ่มปุ่ม Like เล็ก ๆ (`iconSize: 16`) ข้างคอมเมนต์แต่ละอัน — `_toggleCommentLike(String commentId)` รับแค่ id แล้วอ่าน `_comments[index]` สดใหม่ในตัว method เสมอ (mirror `FeedScreen._toggleLike` ที่แก้บั๊ก double-tap แล้วใน WYN-004 QA รอบ 1 — ไม่ใช้ pattern รับ `DropComment` เป็น parameter ที่เคยผิดมาก่อน)
- แก้ 2 จุด Low severity พร้อมกัน: `CreateDropScreen._pickImage` เพิ่ม `if (_isCropping) return;` เป็นบรรทัดแรก และ guard ของพื้นที่เลือกรูปเช็ค `_isCropping` ด้วย (ไม่ใช่แค่ `_isSharing`); เพิ่ม `try/catch` รอบ `centerCropToSquare` แสดง error message ให้ผู้ใช้เห็นแทนที่จะเงียบ ๆ

Files Changed:
- `supabase/schema.sql` (เพิ่มตาราง `drop_comment_likes`)
- `app/lib/features/drop/data/drop_comment.dart` (เพิ่ม likeCount/likedByMe/toggledLike/copyWith)
- `app/lib/features/drop/data/drop_repository.dart` (เพิ่ม toggleCommentLike, ปรับ fetchComments/addComment)
- `app/lib/features/drop/presentation/drop_detail_screen.dart` (mutable comments list + ปุ่ม Like Comment)
- `app/lib/features/drop/presentation/create_drop_screen.dart` (แก้ 2 จุด Low severity)
- `app/test/drop_comment_test.dart` (ขยายครอบคลุม field ใหม่)
- `app/test/drop_comment_like_test.dart` (ใหม่ — regression test double-tap safety)
- `app/test/support/recording_drop_repository.dart` (เพิ่ม `comments` seed list, `toggleCommentLike` recording)

Reason: implement ฟีเจอร์ "Like Comment" ที่ขาดไปให้ครบตาม Product spec + Design spec ของ WYN-005 พร้อมป้องกันบั๊ก double-tap แบบเดียวกับที่เจอใน WYN-004 ตั้งแต่รอบแรก

Tests:
- `flutter analyze` (รันซ้ำอย่างอิสระ) — **No issues found**
- `flutter test` (รันซ้ำอย่างอิสระ) — **All tests passed! (63/63)** เพิ่ม 3 เคสใหม่ใน `drop_comment_test.dart` (toggledLike, fromMap with likeCount) และ 1 เคสใหม่ใน `drop_comment_like_test.dart`
- **พิสูจน์แล้วว่า regression test จับบั๊กได้จริง**: ย้อน `_toggleCommentLike` กลับไปรับ `DropComment` เป็น parameter (แบบเดียวกับที่เคยผิดใน WYN-004) ชั่วคราวแล้วรัน `drop_comment_like_test.dart` ซ้ำ — **FAIL จริง** (`[false, false]` แทนที่จะเป็น `[false, true]`) ก่อน restore กลับมาแก้แล้ว **PASS**
- ระหว่างเขียน test เจอ Flutter testing gotcha ที่ไม่ใช่บั๊กจริง (เสียเวลา debug พอสมควรก่อนเข้าใจ): `find.byType()`/`find.text()` มองไม่เห็น widget ที่อยู่นอก viewport ใน `ListView`/`Sliver` (comment ถูกดันไปไกลเกินจอเพราะรูปภาพ Drop สูง 800px ในสภาพแวดล้อมทดสอบ) ต้อง `scrollUntilVisible` ก่อน — บันทึกไว้ที่ `.wyn/learning/PATTERNS.md` กันเจอซ้ำ

Regression Risk: ต่ำ — มี unit test คุ้มครองจริงทั้ง model logic และ double-tap safety การเปลี่ยน `_commentsFuture` เป็น `_comments` list เป็นการ refactor ภายในเฉพาะ state management ของ `DropDetailScreen` ไม่กระทบ public API/constructor ของ screen เลย ไม่มี call site อื่นต้องแก้

Handoff to QA: ส่งกลับ AI QA & Security (`/qa`) ทดสอบรอบ 2 — เน้นตรวจสอบว่า: (ก) ปุ่ม Like Comment ทำงานถูกต้องปกติ (ไม่ double-tap) ทั้ง optimistic update และ rollback เมื่อ network ล้มเหลว (ข) RLS ของ `drop_comment_likes` ถูกต้อง (ค) ไม่มี regression กับ Comment เดิม (เพิ่ม/ลบคอมเมนต์, ดูรายการ) หรือ Like/Save/Share ของ Drop เอง จากการเปลี่ยน state management เป็น mutable list (ง) 2 จุด Low severity ที่แก้เพิ่มทำงานถูกต้อง

---

## QA & Security Report — รอบ 2 (AI QA & Security)

Feature: WYN-005 — Drop (โพสต์รูปภาพ) — หลัง Debug Engineer แก้ Like Comment

Environment: Code review + static analysis บน `main` หลัง merge PR #30 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับรอบก่อนหน้า (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. ตรวจโค้ดจริงของ fix: `DropDetailScreen._toggleCommentLike` อ่าน `_comments[index]` สดใหม่จริงหรือไม่ (ไม่ capture parameter) + มี rollback เมื่อ network fail จริงหรือไม่
4. ตรวจ `drop_comment_likes` RLS ในสคีมาจริง (select-all-authenticated, insert/delete เฉพาะของตัวเอง) เทียบกับ `drop_likes` pattern
5. ตรวจ regression test `drop_comment_like_test.dart` ว่าพิสูจน์ double-tap จริงหรือไม่ (อ่านโค้ด test เอง ไม่ใช่แค่เชื่อ Debug Report) — และลองย้อน fix กลับไปพิสูจน์ red→green ซ้ำด้วยตัวเอง
6. ตรวจ 2 จุด Low severity ที่แก้ (`_isCropping` guard, try/catch รอบ `centerCropToSquare`) ตรงกับที่ report จริงหรือไม่
7. **ไล่ Acceptance Criteria ทุกบรรทัดของ WYN-005 กับโค้ดจริงอีกครั้งทั้งหมด ไม่ใช่แค่จุดที่เพิ่งแก้** (บทเรียนจากรอบ 1: QA รอบ 1 เทียบแค่ Requirements/Component list แต่พลาดไม่ได้ไล่ Acceptance Criteria checklist แบบเดียวกันแบบครบทุกข้อ)
8. Regression กับ Like/Save/Share/Comment เดิมของ Drop จากการเปลี่ยน `_commentsFuture` → `_comments` mutable list
9. Secret/credential exposure check ในโค้ดที่เปลี่ยนใหม่

Passed: 6/9 (#1, #2, #3, #4, #5, #6, #8, #9 — นับจริง 8/9)

Failed: 1/9 (#7)

Severity: **Major**

### Failed Case #7 — Major: ไม่มีทางลบ Comment ของตัวเองได้เลย ทั้งที่ Product spec ระบุไว้ตรง ๆ ทั้งใน Requirements และ Acceptance Criteria

Reproduction (เทียบเอกสารกับโค้ดจริง):
1. Product spec (`.wyn/tasks/qa/WYN-005-drop-post-image.md` หัวข้อ Requirements, บรรทัด "Comment"): **"เพิ่ม Comment ได้, ลบ Comment ของตัวเองได้, Like Comment ได้"**
2. Acceptance Criteria ข้อที่ตรงกัน: **"คอมเมนต์ได้ ลบคอมเมนต์ของตัวเองได้ กด Like คอมเมนต์ได้"** — เป็น checkbox เดียวที่รวม 3 ความสามารถ และมีแค่ 2/3 ที่ทำงานจริง (เพิ่ม + Like) ส่วนลบยังไม่มีเลย
3. อ่าน `app/lib/features/drop/data/drop_repository.dart` ทั้งไฟล์ (219 บรรทัด): มี `deleteDrop(String dropId)` สำหรับลบ Drop แต่**ไม่มี `deleteComment`/`removeComment` เลยแม้แต่ method เดียว**
4. อ่าน `app/lib/features/drop/presentation/drop_detail_screen.dart` ส่วน render comment list (บรรทัด ~347-404): แต่ละคอมเมนต์แสดง avatar/ชื่อ/ข้อความ/ปุ่ม Like เท่านั้น ไม่มีปุ่มลบ ไม่มี long-press/swipe-to-delete หรือกลไกอื่นใดเลย และ**ไม่มีการเทียบ `comment.authorId == currentUserId` เลยสักจุดในการ render comment** (ต่างจาก `isOwnDrop` ที่เทียบไว้ถูกต้องสำหรับตัว Drop เองที่บรรทัด 203/231) — ยืนยันว่าไม่ใช่แค่ UI ที่ขาด แต่ไม่มี logic ตรวจสอบความเป็นเจ้าของคอมเมนต์เลยด้วยซ้ำ
5. ตรวจ `supabase/schema.sql`: DB-level มี RLS policy "Users can delete their own drop comments" (`for delete ... using (auth.uid() = author_id)`) รองรับไว้แล้วตั้งแต่รอบ Coding แรก — แปลว่า backend พร้อมรองรับ แต่ไม่มี client path ใด ๆ ไปถึงมันเลย เหมือนกับกรณี Like Comment ในรอบ 1 เป๊ะ (DB พร้อม แต่ไม่มีทางเรียกใช้จาก UI)
6. ตรวจว่านี่ไม่ใช่ gap ที่สืบทอดมาจาก WYN-004: เปิด `.wyn/tasks/approved/WYN-004-feed-and-post.md` พบว่า WYN-004 Requirements ระบุแค่ "ลบโพสต์ของตัวเองได้" (ลบ**โพสต์** ไม่ใช่ลบ**คอมเมนต์**) — WYN-004 ไม่เคยมี requirement "ลบ comment" เลย จึงไม่มี pattern ให้ WYN-005 Coding อ้างอิงได้ตรง ๆ เหมือนกับ root cause ของบั๊ก Like Comment ในรอบ 1 ทุกประการ (feature ใหม่ที่ WYN-004 ไม่เคยมี ถูกมองข้ามเมื่อ implement ตาม mental model ของ WYN-004 แทนที่จะไล่ checklist จาก spec ของ WYN-005 เอง)
7. ตรวจ Design spec (`.wyn/docs/design/wyn-005-drop.md`) Screen 3 Components — พบว่า Design เองก็ไม่ได้ระบุปุ่มลบคอมเมนต์ไว้ในรายการ component เลย (มีแค่ "ปุ่มลบ (ถังขยะ, เฉพาะ Drop ของตัวเอง)" สำหรับตัว Drop ที่บรรทัด 94) แปลว่า Design ก็พลาดจุดนี้ไปตั้งแต่ต้นเช่นกัน ไม่ใช่ Coding พลาดฝ่ายเดียว — แต่ Product spec (ต้นทาง requirement) ระบุไว้ชัดเจน ดังนั้นยังถือเป็นบั๊กที่ต้องแก้ ไม่ใช่การตัดขอบเขตที่ตั้งใจ (ไม่มีบันทึกไว้ที่ไหนว่าตัดออก)

Expected: ผู้ใช้เห็นปุ่ม/ทางลบคอมเมนต์ของตัวเองเท่านั้น (เหมือน `isOwnDrop` guard ของตัว Drop) กดแล้วคอมเมนต์หายไปจากรายการและ `commentCount` ของ Drop ลดลง

Actual: ไม่มีทางลบคอมเมนต์ได้เลยไม่ว่าจะเป็นคอมเมนต์ของตัวเองหรือคนอื่น — ทั้งที่ RLS ฝั่ง database รองรับไว้แล้ว

Security Findings:
- ไม่พบ secret/credential hardcode ในโค้ดที่เปลี่ยนใหม่ทั้งหมดของรอบนี้ (Debug Engineer's diff)
- `drop_comment_likes` RLS ตรวจแล้วถูกต้องตรงตาม pattern ของ `drop_likes` ทุกประการ: select-all-authenticated, insert/delete จำกัดเฉพาะ `auth.uid() = user_id`, composite PK (`comment_id`, `user_id`) ป้องกัน duplicate like ที่ database level ด้วย (ไม่ใช่แค่พึ่ง client logic)
- `DropDetailScreen._toggleCommentLike` ตรวจโค้ดจริงแล้วยืนยันว่าอ่าน `_comments[index]` สดใหม่ทุกครั้งจริง (ไม่ capture parameter ที่ build-time) และมี rollback (`setState(() => _comments![index] = previous)`) ใน catch block จริง — ตรงตามที่ Debug Report ระบุ
- ลองรัน regression test ซ้ำด้วยตัวเอง: ย้อน `_toggleCommentLike` กลับไปรับ `DropComment` เป็น parameter ชั่วคราว รัน `flutter test test/drop_comment_like_test.dart` → **FAIL จริง** (`Expected: [false, true], Actual: [false, false]`) แล้ว restore กลับมา → **PASS** — ยืนยันว่า regression test มีความหมายจริง ไม่ใช่ test ที่ผ่านเสมอไม่ว่าจะแก้บั๊กหรือไม่
- 2 จุด Low severity ที่แก้ (`_isCropping` guard ครอบทั้งปุ่มและพื้นที่รูปภาพ, try/catch รอบ `centerCropToSquare` พร้อม error message ให้ผู้ใช้เห็น) ตรวจโค้ดจริงแล้วตรงตามที่ report ทุกจุด
- ไม่พบ regression กับ Like/Save/Share ของ Drop เอง หรือการเพิ่มคอมเมนต์ใหม่ (`_sendComment` ยัง append เข้า `_comments` list ถูกต้อง, `_drop.withExtraComment()` ยัง sync `commentCount` ถูกต้อง)

Recommendation: ส่งกลับ AI Debug Engineer เพิ่มความสามารถ "ลบ Comment ของตัวเอง" ให้ครบ (Major) — แนวทางที่แนะนำ:
- เพิ่ม `deleteComment({required String commentId})` ใน `DropRepository` (`_client.from('drop_comments').delete().eq('id', commentId)` — RLS ฝั่ง DB บังคับความเป็นเจ้าของอยู่แล้ว ไม่ต้องเช็ค authorId ฝั่ง client ซ้ำก่อนยิง request แต่ต้องเช็คเพื่อ**แสดง/ซ่อนปุ่ม**)
- เพิ่มปุ่มลบ (ไอคอนถังขยะเล็ก ๆ หรือ long-press menu) ข้างคอมเมนต์ **เฉพาะที่ `comment.authorId == currentUserId`** (mirror `isOwnDrop` guard ที่มีอยู่แล้วสำหรับตัว Drop เอง บรรทัด 203/231 ของไฟล์เดียวกัน)
- ใช้ dialog ยืนยันก่อนลบเหมือน Drop เอง (`confirmDeletePost`/`confirmDeleteDrop` ที่ generalize ไว้แล้วตั้งแต่ WYN-005 รอบแรก — เรียกด้วย `itemLabel` ที่เหมาะกับ "คอมเมนต์" ได้เลยไม่ต้องสร้างใหม่)
- ลบคอมเมนต์แล้วต้องอัปเดต `_comments` list (เอาออก) และลด `_drop.commentCount` ลง 1 (mirror `withExtraComment()` แต่ทิศตรงข้าม — พิจารณาเพิ่ม `withoutExtraComment()`/`withRemovedComment()` helper ใน `Drop` model)
- เพิ่ม regression test ครอบคลุม: ปุ่มลบแสดงเฉพาะเจ้าของคอมเมนต์เท่านั้น (คนอื่นมองไม่เห็นปุ่ม), ลบแล้วหายจาก list จริง, commentCount ลดลงจริง
- แนะนำให้ AI Design เพิ่มบรรทัด "ปุ่มลบคอมเมนต์ (เฉพาะของตัวเอง)" เข้า Component list ของ Screen 3 ใน `.wyn/docs/design/wyn-005-drop.md` ด้วย เพื่อไม่ให้ document กับโค้ดไม่ตรงกันต่อไป (Design เองก็พลาดจุดนี้ตั้งแต่ต้น)

Final Status: **FAIL**

---

## Debug Engineer Report — รอบ 2 (AI Debug Engineer)

Bug: Major จาก QA รอบ 2 (ด้านบน) — ไม่มีทางลบ Comment ของตัวเองได้เลย ทั้งที่ Product spec ระบุไว้ตรงทั้ง Requirements และ Acceptance Criteria

Reproduction: ยืนยันตรงกับที่ QA รายงาน — อ่าน `app/lib/features/drop/data/drop_repository.dart` ทั้งไฟล์ ไม่มี `deleteComment` เลย และอ่าน `app/lib/features/drop/presentation/drop_detail_screen.dart` ส่วน render comment list ไม่มีปุ่มลบและไม่มีการเทียบ `comment.authorId == currentUserId` เลยสักจุด ยืนยันด้วยว่า `supabase/schema.sql` มี RLS delete policy บน `drop_comments` (`"Users can delete their own drop comments"`) รองรับไว้แล้วตั้งแต่รอบ Coding แรก — สอดคล้องกับที่ QA สรุปไว้ทุกประการ

Root Cause: เดียวกับบั๊กรอบ 1 เป๊ะ — WYN-004 (ที่ WYN-005 อ้างอิง mental model ตอน implement) มี requirement แค่ "ลบโพสต์ของตัวเองได้" ไม่เคยมี "ลบ comment ของตัวเองได้" เลย จึงไม่มี pattern ให้อ้างอิงตรง ๆ เมื่อ implement ตามโครงสร้างคล้าย WYN-004 แทนที่จะไล่ checklist ทีละบรรทัดจาก Product Requirements/Acceptance Criteria ใหม่ของ WYN-005 เอง จึงพลาดข้อกำหนดนี้ไปเช่นเดียวกับที่เคยพลาด Like Comment มาก่อน — เพิ่มเติมคือ Design spec เองก็ไม่ได้ระบุ component ปุ่มลบคอมเมนต์ไว้เลย (มีแต่ปุ่มลบ Drop) ทำให้ Coding ไม่มีทั้งฝั่ง Product checklist และ Design component ที่ชี้ทางให้ตรง ๆ

Fix:
- เพิ่ม `Drop.withRemovedComment()` ใน `drop.dart` — `copyWith(commentCount: commentCount - 1)` (mirror `withExtraComment()` ทิศตรงข้าม)
- เพิ่ม `DropRepository.deleteComment(String commentId)` — `_client.from('drop_comments').delete().eq('id', commentId)` ไม่ต้องเช็ค ownership ฝั่ง client ก่อนยิง request เพราะ RLS บังคับไว้อยู่แล้วที่ DB (เหมือน `deleteDrop`) แต่ต้องเช็คฝั่ง client ก่อน**แสดงปุ่ม**
- เพิ่มปุ่มลบ (ไอคอนถังขยะเล็ก `iconSize: 16`) ข้างคอมเมนต์ใน `DropDetailScreen` **เฉพาะที่ `comment.authorId == currentUserId`** (mirror `isOwnDrop` guard ที่มีอยู่แล้วสำหรับตัว Drop เอง)
- เพิ่ม `_deleteComment(String commentId)`: เรียก `confirmDeletePost(context, itemLabel: 'คอมเมนต์')` (ใช้ dialog ที่ generalize ไว้แล้วตั้งแต่ WYN-005 รอบแรก ไม่ต้องสร้างใหม่) ก่อนลบจริงเสมอ แล้วเรียก `dropRepository.deleteComment`, สำเร็จแล้วเอาคอมเมนต์ออกจาก `_comments` list ด้วย `.where((c) => c.id != commentId)` และเรียก `_drop.withRemovedComment()` เพื่อ sync `commentCount`, ล้มเหลวแสดง SnackBar error (mirror `_deleteDrop` ทุกจุด)

Files Changed:
- `app/lib/features/drop/data/drop.dart` (เพิ่ม `withRemovedComment()`)
- `app/lib/features/drop/data/drop_repository.dart` (เพิ่ม `deleteComment`)
- `app/lib/features/drop/presentation/drop_detail_screen.dart` (ปุ่มลบคอมเมนต์ + `_deleteComment` handler)
- `app/test/drop_test.dart` (เพิ่ม unit test `withRemovedComment`)
- `app/test/drop_comment_delete_test.dart` (ใหม่ — regression test: ปุ่มลบแสดงเฉพาะเจ้าของคอมเมนต์, ลบแล้วหายจาก list, commentCount ลดลงจริง)
- `app/test/support/recording_drop_repository.dart` (เพิ่ม `deleteCommentCalls` tracking)

Reason: implement ความสามารถ "ลบ Comment ของตัวเอง" ที่ขาดไปให้ครบตาม Product spec ของ WYN-005 โดยใช้ pattern เดียวกับปุ่มลบ Drop ที่มีอยู่แล้วทุกจุด (ownership guard, confirm dialog, error handling)

Tests:
- `flutter analyze` — **No issues found**
- `flutter test` — **All tests passed! (66/66)** เพิ่ม 1 เคสใหม่ใน `drop_test.dart` (`withRemovedComment`) และ 2 เคสใหม่ใน `drop_comment_delete_test.dart` (ปุ่มลบแสดงเฉพาะเจ้าของ, ลบแล้วหายจาก list + commentCount ลดลง)
- **พิสูจน์แล้วว่า regression test จับบั๊กได้จริง**: คอมเมนต์เงื่อนไขแสดงปุ่มลบชั่วคราวเป็น `if (false && comment.authorId == currentUserId)` แล้วรัน `drop_comment_delete_test.dart` ซ้ำ — **FAIL จริง** (`Expected: exactly one matching candidate, Actual: Found 0 widgets with icon delete_outline`) ก่อน restore กลับมาแก้แล้ว **PASS ทั้ง 66 เทสต์**

Regression Risk: ต่ำ — เพิ่ม method/UI ใหม่ล้วน ๆ ไม่ได้แก้ signature หรือ behavior ของโค้ดเดิมที่มีอยู่แล้วเลย (`deleteComment` เป็น method ใหม่ทั้งหมด, ปุ่มลบเป็น conditional widget ใหม่ที่ไม่กระทบ layout เดิมเมื่อ `comment.authorId != currentUserId`) ทดสอบแล้วว่า Like Comment/เพิ่มคอมเมนต์/Like-Save-Share ของ Drop เองยังทำงานถูกต้องปกติ (test เดิมทั้งหมดยังผ่าน)

Handoff to QA: ส่งกลับ AI QA & Security (`/qa`) ทดสอบรอบ 3 — เน้นตรวจสอบว่า: (ก) ปุ่มลบคอมเมนต์แสดงเฉพาะเจ้าของคอมเมนต์เท่านั้นจริง ไม่ใช่แค่ในเทสต์ (ข) ลบคอมเมนต์แล้ว list/commentCount sync ถูกต้อง รวมถึง rollback/error handling เมื่อ network ล้มเหลว (ค) RLS ของ `drop_comments` delete policy ยังถูกต้องตามเดิม (ง) ไล่ Acceptance Criteria **ทุกบรรทัด** อีกครั้งทั้งหมด (ทั้ง Requirements, Design Components, Acceptance Criteria แยกกัน) เผื่อมีจุดอื่นที่ยังพลาดอยู่ ก่อนจะอนุมัติจริง — บทเรียนจากสองรอบที่ผ่านมาคือห้ามเชื่อว่าตรวจครบแค่เพราะรอบก่อนหน้าเทียบมาแล้วบางหัวข้อ

---

## QA & Security Report — รอบ 3 (AI QA & Security)

Feature: WYN-005 — Drop (โพสต์รูปภาพ) — หลัง Debug Engineer แก้ "ลบ Comment ของตัวเองได้" (รอบ 2)

Environment: Code review + static analysis บน `main` หลัง merge PR #32 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับรอบก่อนหน้า (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. ตรวจโค้ดจริงของ fix รอบ 2: `deleteComment`/`withRemovedComment`/ปุ่มลบคอมเมนต์ที่มี ownership guard ตรงตาม report จริงหรือไม่
4. ตรวจว่า `supabase/schema.sql` ไม่ถูกแก้ในรอบนี้ (RLS delete policy ของ `drop_comments` ต้องเหมือนเดิมตั้งแต่รอบ Coding แรก ไม่ใช่ของใหม่ที่ยังไม่ผ่านการตรวจ)
5. ตรวจ regression test `drop_comment_delete_test.dart` ว่าพิสูจน์บั๊กจริงหรือไม่ (อ่านโค้ด test เอง) — ownership visibility + list/commentCount sync
6. ตรวจ error/rollback handling ของ `_deleteComment` เมื่อ network ล้มเหลว (`catch` block, ไม่แตะ `_comments`/`_drop` เมื่อ fail, แสดง SnackBar)
7. **ไล่ Product Requirements ทุกบรรทัดกับโค้ดจริงใหม่ทั้งหมด** (แยกจาก Design/AC)
8. **ไล่ Design Components ของทั้ง 3 หน้าจอทุกบรรทัดกับโค้ดจริงใหม่ทั้งหมด** (แยกจาก Requirements/AC)
9. **ไล่ Acceptance Criteria ทุกข้อกับโค้ดจริงใหม่ทั้งหมด** (แยกจาก Requirements/Design)
10. Regression กับ Like Comment (รอบ 1), Like/Save/Share/เพิ่มคอมเมนต์ ของ Drop เอง

Passed: 9/10 (#1, #2, #3, #4, #5, #6, #7, #9, #10)

Failed: 0/10 — พบ 1 ข้อสังเกตระดับ **Minor** จาก #8 ที่ไม่ block การอนุมัติ (ดูด้านล่าง)

Severity: **Minor** (ไม่ block)

### ข้อสังเกต Minor (จาก #8 — ไล่ Design Components): ไม่แสดงเวลาที่โพสต์ (relative time) เลยทั้งใน Drop header และ comment แต่ละอัน

Reproduction:
1. Design spec (`.wyn/docs/design/wyn-005-drop.md` Screen 3, Components) ระบุไว้ 2 จุด: "แถวผู้โพสต์: `AvatarCircle` + ชื่อแสดง/@username + **เวลาที่โพสต์ (relative time)** + ปุ่มลบ" และ "รายการ Comment (avatar เล็ก + ชื่อ + ข้อความ + **เวลา** + ปุ่ม Like เล็ก ๆ ข้างคอมเมนต์)"
2. `grep -n "createdAt\|relative\|timeago\|ago" app/lib/features/drop/presentation/drop_detail_screen.dart app/lib/features/drop/presentation/drop_feed_screen.dart app/lib/features/drop/presentation/widgets/drop_grid_tile.dart` → **ไม่พบเลยแม้แต่บรรทัดเดียว** — `Drop.createdAt`/`DropComment.createdAt` มีอยู่ใน model และถูก parse จาก DB ถูกต้อง แต่ไม่เคยถูกนำมาแสดงผลที่ไหนเลยในทั้ง 3 หน้าจอ
3. เทียบกับ WYN-004: `PostCard._relativeTime(DateTime)` (`app/lib/features/feed/presentation/widgets/post_card.dart:25`) implement ไว้แล้วและใช้งานจริง — มี pattern พร้อมให้ WYN-005 อ้างอิง/reuse ได้ตรง ๆ แต่ไม่ได้ถูกทำ

Expected: เห็นเวลาที่โพสต์แบบ relative (เช่น "5 นาทีที่แล้ว") ทั้งที่แถวผู้โพสต์ของ Drop และข้างคอมเมนต์แต่ละอัน

Actual: ไม่แสดงเวลาที่โพสต์เลยทั้งสองจุด

เหตุผลที่ไม่ทำให้ FAIL รอบนี้: ไม่ปรากฏใน Product Requirements หรือ Acceptance Criteria เลย (มีเฉพาะใน Design Component list) ไม่กระทบ flow การใช้งานหลักข้อใดของ Acceptance Criteria ที่เป็นเกณฑ์อนุมัติจริงของ task นี้ และเป็น information display gap ไม่ใช่ capability ที่หายไปทั้งระบบแบบ 2 บั๊กก่อนหน้า (Like Comment / Delete Comment) — ตรงตามบรรทัดฐานที่ตั้งไว้ในรอบ 1 ที่ 2 จุด Low severity (crop guard, try/catch) ก็ไม่ block การอนุมัติเช่นกัน

Recommendation: เพิ่มการแสดงเวลาที่โพสต์แบบ relative time ทั้ง 2 จุดในรอบถัดไปที่แตะไฟล์เหล่านี้ (ไม่จำเป็นต้องเป็นรอบ Debug แยก) — แนะนำให้แยก `_relativeTime` ของ `PostCard` (WYN-004) ออกมาเป็น shared utility function (เช่น `lib/core/relative_time.dart`) แล้วให้ทั้ง WYN-004 และ WYN-005 เรียกใช้ร่วมกัน แทนที่จะ copy โค้ดซ้ำหรือปล่อยให้ WYN-005 implement แยกเอง

### สรุปผลตรวจ Requirements/Design/Acceptance Criteria ทั้ง 3 หัวข้อแยกกัน (รอบนี้)

- **Product Requirements** (ทุกบรรทัด): ครบทุกข้อแล้ว — สร้าง Drop (รูปบังคับ), รูปภาพ 1:1, แสดงผล Drop (profile pic/username/รูป/caption/ปุ่ม 4 ปุ่ม/จำนวน like/จำนวน comment), Like, **Comment (เพิ่ม+ลบ+Like ครบทั้ง 3 อย่างแล้ว)**, Share, Save, ลบ Drop ของตัวเอง — ผ่านหมด
- **Design Components** (ทั้ง 3 หน้าจอ ทุกบรรทัด): ครบเกือบทั้งหมด ยกเว้น relative time (Minor ด้านบน) — Screen 1 (AppBar+/grid 3 คอลัมน์/scrim heart+count/pull-to-refresh/infinite scroll/loading-empty-error-loading more states/semantics label ต่อช่อง) ผ่านหมด, Screen 2 (AppBar close+title+share/action sheet/preview 1:1/caption+counter 500/share disabled จนกว่ามีรูป/error state ไม่เสียข้อมูล) ผ่านหมด, Screen 3 (ทุกจุดยกเว้นเวลา) ผ่าน
- **Acceptance Criteria** (ทุก checkbox): ครบทุกข้อแล้วรวมถึงข้อที่เพิ่งแก้ในรอบนี้ ("คอมเมนต์ได้ ลบคอมเมนต์ของตัวเองได้ กด Like คอมเมนต์ได้" — ครบทั้ง 3 ความสามารถเป็นครั้งแรก)

Security Findings:
- ไม่พบ secret/credential hardcode ในโค้ดที่เปลี่ยนใหม่ของรอบนี้ (Debug รอบ 2)
- `DropRepository.deleteComment` ไม่เช็ค ownership ฝั่ง client ก่อนยิง request — ตรวจสอบแล้วว่าปลอดภัยเพราะ RLS policy `"Users can delete their own drop comments"` (`using (auth.uid() = author_id)`) บังคับที่ระดับ database อยู่แล้ว แม้ผู้ใช้จะพยายามเรียก API ตรง ๆ ข้าม UI ก็ลบคอมเมนต์คนอื่นไม่ได้ — ตรงตาม defense-in-depth pattern เดียวกับ `deleteDrop`
- ปุ่มลบคอมเมนต์ฝั่ง UI (`comment.authorId == currentUserId`) ตรวจแล้วว่าเป็นแค่ UX guard (ซ่อนปุ่มไม่ให้กดผิด) ไม่ใช่ security boundary เดียว — RLS คือ security boundary จริง ถูกต้องตามหลักการ
- `_deleteComment`'s catch block ตรวจแล้วว่าไม่แตะ `_comments`/`_drop` เมื่อ fail (ต่างจาก Like ที่ต้อง rollback เพราะมี optimistic update ก่อนยิง request — delete ไม่มี optimistic update ก่อน จึงไม่มีอะไรต้อง rollback ถูกต้องแล้ว)
- ไม่พบ regression กับ RLS หรือ security posture อื่นใดจากรอบก่อนหน้า (schema.sql ไม่ถูกแก้ในรอบนี้ ยืนยันด้วย `git diff` ระหว่าง commit ก่อน/หลัง PR #32)

Recommendation: **อนุมัติ WYN-005 เข้าสู่ `.wyn/tasks/approved/`** — ข้อสังเกต Minor เรื่อง relative time ให้บันทึกไว้เป็นรายการปรับปรุงสำหรับรอบถัดไปที่แตะไฟล์เหล่านี้ ไม่ต้องเปิดรอบ Debug แยกเพื่อเรื่องนี้โดยเฉพาะ

Final Status: **PASS**
