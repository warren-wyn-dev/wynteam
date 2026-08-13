# Product Task — WYN-004

Status: review (AI Coding เสร็จแล้ว รอส่งต่อ AI QA & Security)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (ถัดไป)

Feature: Feed & Post (with Like and Comment)

Goal: ให้ผู้ใช้โพสต์ข้อความ/รูปภาพและเห็นโพสต์ของคนอื่นได้ เป็นหัวใจหลักของการเป็นแอปโซเชียลมีเดีย — เปลี่ยน `HomeScreen` จาก placeholder ("Feed จะมาใน feature ถัดไป") ให้เป็น Feed จริง

Target User: วัยรุ่น / Gen Z ที่ต้องการแชร์เรื่องราวและมีปฏิสัมพันธ์กับโพสต์ของคนอื่น

Problem: ตอนนี้ WYN มีแค่ Auth (WYN-002) และ Profile (WYN-003) แต่ยังไม่มีฟีเจอร์หลักที่ทำให้เป็น "โซเชียลมีเดีย" จริง ๆ เลย — ผู้ใช้ login เข้ามาแล้วไม่มีอะไรให้ทำต่อ

Requirements:
- **Global Feed**: แสดงโพสต์ของผู้ใช้ทุกคน เรียงจากใหม่ไปเก่า (ยังไม่มีระบบ Follow ในตอนนี้)
- **สร้างโพสต์**: ข้อความ + แนบรูปภาพได้ (ต้องมีอย่างน้อย 1 อย่าง)
- **Like**: กดไลก์/เลิกไลก์โพสต์ได้ เห็นจำนวนไลก์
- **Comment**: คอมเมนต์ใต้โพสต์ได้ เห็นจำนวนคอมเมนต์ กดดูคอมเมนต์ทั้งหมดได้
- **ลบโพสต์**: ผู้ใช้ลบโพสต์ของตัวเองได้
- แสดงข้อมูลผู้โพสต์ในแต่ละโพสต์: avatar, ชื่อแสดง/username
- รูปภาพที่แนบโพสต์เก็บใน Supabase Storage (bucket ใหม่ `post-images`)

Acceptance Criteria:
- [ ] เปิดแอปแล้วเห็น Feed ที่มีโพสต์ของทุกคน เรียงใหม่สุดอยู่บนสุด
- [ ] กดปุ่มสร้างโพสต์ พิมพ์ข้อความและ/หรือแนบรูป กดโพสต์แล้วเห็นโพสต์ใหม่ปรากฏใน Feed ทันที
- [ ] โพสต์ที่ไม่มีทั้งข้อความและรูปภาพ โพสต์ไม่ได้
- [ ] กดไลก์โพสต์แล้วเห็นจำนวนไลก์เพิ่มทันที กดซ้ำเพื่อเลิกไลก์ได้
- [ ] กดเข้าไปดูโพสต์แล้วคอมเมนต์ได้ เห็นคอมเมนต์ของคนอื่นครบ
- [ ] ผู้ใช้เห็นปุ่มลบเฉพาะโพสต์ของตัวเองเท่านั้น
- [ ] ลบโพสต์แล้วหายจาก Feed ของทุกคนทันที
- [ ] ผู้ใช้อื่นแก้ไข/ลบโพสต์ของเราไม่ได้ (RLS บังคับ)
- [ ] ผู้ใช้อื่นลบไลก์/คอมเมนต์ของเราแทนเราไม่ได้ (RLS บังคับ)

Dependencies: WYN-002 (Auth — เสร็จแล้ว), WYN-003 (Profile — เสร็จแล้ว)

Priority: สูงสุด — เป็นหัวใจของผลิตภัณฑ์

Risks:
- Global Feed ไม่มีการกรองเนื้อหา (content moderation) — ความเสี่ยงระยะยาว นอก scope ของ WYN-004
- ต้องมี pagination/infinite scroll ตั้งแต่ต้น ไม่ใช่โหลดทั้งหมดทีเดียว
- ต้นทุน Storage ไม่จำกัดเหมือน avatar (โพสต์มีรูปได้ไม่จำกัดจำนวน)

Recommendation: ส่งต่อ AI Coding เพื่อ implement ตาม Design Spec ทันที

Handoff: Design เสร็จแล้ว — ดู Design Spec เต็มที่ `.wyn/docs/design/wyn-004-feed-and-post.md` งานถัดไปคือ AI Coding (`/code`) implement 3 screens (Feed, Create Post, Post Detail/Comments) — ต้อง refactor `HomeScreen` เดิมทั้งหมด (ย้ายปุ่ม logout ไปหน้าโปรไฟล์) และสร้างตาราง `posts`/`likes`/`comments` ใหม่พร้อม RLS

## Coding Output (AI Coding)

Implementation:
- Database: เพิ่ม section WYN-004 ใน `supabase/schema.sql` — ตาราง `posts` (text_content, image_url, CHECK ต้องมีอย่างน้อย 1 อย่าง, CHECK ความยาว text ≤ 500), `likes` (composite PK post_id+user_id), `comments` (CHECK ความยาว text 1-500) ทั้งหมดอ้างอิง `public.profiles(id)` (ไม่ใช่ `auth.users(id)` ตรง ๆ) เพื่อให้ PostgREST embed ข้อมูล author ได้ในคำสั่งเดียว — RLS ทุกตาราง: select ต้อง authenticated, insert/delete เฉพาะของตัวเอง (`auth.uid()`) เพิ่ม storage bucket `post-images` (public, insert-only RLS ตาม `auth.uid()`)
- `lib/core/text_utils.dart`: ดึง `normalizeOptionalText()` ออกมาจาก `profile_repository.dart` ให้ใช้ร่วมกันกับ `posts.text_content` (บั๊กเดิมจาก WYN-003 คือ '' ไม่เท่ากับ NULL) พร้อมเพิ่ม `displayNameOrUsername()` ให้ Profile/Post/Comment ใช้ร่วมกัน
- `lib/features/feed/data/`: `post.dart`, `comment.dart` (model + `fromMap` พาร์ส embedded author และ embedded count `[{'count': N}]` ของ PostgREST), `post_repository.dart` (fetchFeed แบบ pagination `.range()`, createPost พร้อม upload รูปเข้า Storage, toggleLike, fetchComments, addComment, deletePost)
- `lib/features/feed/presentation/`: `feed_screen.dart` (แทนที่ `HomeScreen` เดิม — infinite scroll, pull-to-refresh, FAB สร้างโพสต์), `create_post_screen.dart` (แนบรูปจากกล้อง/คลังภาพ), `post_detail_screen.dart` (ดู/คอมเมนต์), widgets ที่ใช้ร่วมกัน (`post_card.dart`, `confirm_delete_dialog.dart`)
- ย้ายปุ่ม logout จาก `HomeScreen` (ลบไฟล์ทิ้งแล้ว) ไปที่ `ViewProfileScreen`'s AppBar ตาม Design Spec
- แก้ `AuthGate` เชิงป้องกัน: เดิมฟัง auth event แค่ `signedIn` แต่การย้าย logout ไปหน้า Profile (ซึ่งถูก push ทับ AuthGate) ทำให้เกิดบั๊กแบบเดียวกับที่เจอใน WYN-002 QA รอบ 1-2 ซ้ำได้ (หน้าจอค้างหลัง sign out) — ขยาย listener ให้ฟัง `signedOut` ด้วยและ pop กลับ route แรกเสมอ (พบและแก้ก่อนส่ง QA ไม่ใช่บั๊กที่ QA เจอ)

Files Changed:
- `supabase/schema.sql` (เพิ่ม section WYN-004)
- `app/lib/core/text_utils.dart` (ใหม่)
- `app/lib/features/profile/data/profile.dart`, `profile_repository.dart` (refactor ใช้ text_utils.dart ร่วมกัน)
- `app/lib/features/feed/data/post.dart`, `comment.dart`, `post_repository.dart` (ใหม่)
- `app/lib/features/feed/presentation/feed_screen.dart`, `create_post_screen.dart`, `post_detail_screen.dart` (ใหม่)
- `app/lib/features/feed/presentation/widgets/post_card.dart`, `confirm_delete_dialog.dart` (ใหม่)
- `app/lib/features/profile/presentation/view_profile_screen.dart` (เพิ่มปุ่ม logout)
- `app/lib/features/auth/presentation/auth_gate.dart` (ฟัง signedOut ด้วย, ชี้ไป FeedScreen แทน HomeScreen)
- `app/lib/features/home/presentation/home_screen.dart` (ลบทิ้ง — ถูกแทนที่ด้วย FeedScreen ทั้งหมด)
- `app/test/post_test.dart`, `comment_test.dart`, `post_card_test.dart`, `post_detail_screen_test.dart` (ใหม่)
- `app/test/profile_repository_test.dart` (แก้ import ให้ตรงกับ text_utils.dart)

Reason: implement ตาม Product spec + Design Spec ของ WYN-004 (`.wyn/docs/design/wyn-004-feed-and-post.md`) ครบทั้ง 3 หน้าตามที่ Founder เลือก (Global Feed, ข้อความ+รูปภาพ, Like+Comment, ลบโพสต์ของตัวเองได้)

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 35/35 ผ่านทั้งหมด (รวม test ใหม่ของ WYN-004: model logic ของ Post/Comment เช่น toggledLike/withExtraComment/fromMap, widget test ของ PostCard เช่น ปุ่มลบแสดงเฉพาะเจ้าของโพสต์, สถานะ like)
- พบบั๊ก UI จริงระหว่างเขียน test เอง (ไม่ใช่ QA เจอ): `PostDetailScreen` เดิมวาง `PostCard` ไว้นอกส่วน scroll ของ comment list ทำให้ถ้าโพสต์มีทั้งข้อความยาว+รูปภาพ อาจ overflow บนจอกว้าง/เตี้ย (เช่น tablet, phone แนวนอน) — แก้โดยรวม PostCard เข้าไปเป็น header ของ ListView เดียวกับ comment list แล้วเขียน regression test (`post_detail_screen_test.dart`) ยืนยันว่าไม่ overflow อีก

Build: ยังไม่ได้ build จริง (`flutter build apk/ios`) — sandbox นี้ไม่มี Android SDK/Xcode ให้ verify ได้ ต้องรอขั้นตอน Deploy หรือ CI จริง

Known Issues:
- Pagination ใช้ offset-based (`.range()`) — ยอมรับ known limitation เรื่อง drift ถ้ามีโพสต์ใหม่แทรกระหว่างเลื่อนหน้า (scope ของ V0.1 ยังไม่ทำ cursor-based)
- ยังไม่ทดสอบกับ Supabase project จริง (ต้องรอ infra จาก Founder เหมือน WYN-002/003)
- ไม่มี content moderation (ตามที่ระบุไว้เป็น Risk ใน spec — นอก scope ของ WYN-004)

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบ functional/regression/security ตาม Acceptance Criteria ด้านบนก่อนอนุมัติ deploy
