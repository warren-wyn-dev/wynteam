# Product Task — WYN-004

Status: bugs (QA รอบ 1 — FAIL)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — FAIL) → AI Debug Engineer (ถัดไป)

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

---

## QA & Security Report — รอบ 1 (AI QA & Security)

Feature: WYN-004 — Feed & Post (Global Feed, Like, Comment, Delete)

Environment: Code review + static analysis บน `main` หลัง merge PR #21 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับ WYN-002/003 (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode ให้ dynamic-test)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. Feed: pagination (`.range()`), `_hasMore` heuristic, pull-to-refresh, infinite-scroll guard (code review)
4. Create Post: validation ("ต้องมีข้อความหรือรูปอย่างน้อย 1 อย่าง") เทียบกับ `posts_have_content`/`posts_text_content_length` ใน `supabase/schema.sql` ทีละบรรทัด (บั๊กแบบเดียวกับที่เจอใน WYN-003 — ตรวจซ้ำว่าไม่เกิดอีก)
5. **Like/Unlike: optimistic update + rollback เมื่อ network ล้มเหลว — ตรวจ race condition จากการกดซ้ำเร็ว ๆ**
6. **Create Post: ตรวจ race condition จากการกดปุ่ม "โพสต์" ซ้ำเร็ว ๆ**
7. Comment: เพิ่ม/แสดง, เรียงจากเก่าไปใหม่ตามที่ตั้งใจ (ตรงข้ามกับ feed)
8. Delete Post: confirm dialog, optimistic remove + rollback, RLS
9. RLS policies ของ `posts`/`likes`/`comments` + storage bucket `post-images` ตรวจสอบว่าครอบคลุมตาม Acceptance Criteria ("ผู้ใช้อื่นแก้ไข/ลบโพสต์ของเราไม่ได้", "ผู้ใช้อื่นลบไลก์/คอมเมนต์ของเราแทนเราไม่ได้")
10. Layout robustness: `PostDetailScreen`'s overflow fix ที่ AI Coding เจอเองระหว่างเขียน (ดู Coding Output ด้านบน) — ตรวจว่าแก้ถูกจุดจริง
11. Accessibility: `PostCard`'s like button `Semantics(excludeSemantics: true)`
12. Regression: WYN-002 (Auth/Onboarding) และ WYN-003 (Profile) ไม่ได้รับผลกระทบจากการย้าย logout ไป `ViewProfileScreen` และการขยาย `AuthGate` listener ให้ฟัง `signedOut`
13. Secret/credential exposure check ในโค้ดใหม่ทั้งหมด

Passed: 11/13 (#1, #2, #3, #4, #7, #8, #9, #10, #11, #12, #13)

Failed: 2/13 (#5, #6) — **สาเหตุเดียวกัน (root cause เดียวกัน) เขียนรวมเป็น 1 bug**

Severity: **Major**

### Failed Case #5 + #6 — Major: กดปุ่ม Like หรือปุ่ม "โพสต์" ซ้ำเร็ว ๆ (double-tap ก่อนหน้าจอ rebuild) ทำให้ state ไม่ตรงกับ database แบบเงียบ ๆ / สร้างโพสต์ซ้ำ

พบจาก code review เชิงลึก (trace ลำดับการทำงานแบบ async ทีละบรรทัด) — **ยังไม่ได้ verify แบบ dynamic เพราะ sandbox นี้ไม่มี live Supabase backend ให้จำลอง "call แรกสำเร็จ call ที่สองล้มเหลวเพราะ unique constraint" ได้จริง และ `PostRepository` เป็น concrete class ผูกกับ `SupabaseClient` ตรง ๆ ไม่มี interface ให้ mock/spy การเรียกได้ในสถาปัตยกรรมปัจจุบัน** — แต่ logic flaw เห็นชัดเจนจากโค้ดโดยไม่ต้องเดา ดูรายละเอียด reproduction ด้านล่าง

**Reproduction Steps — #5 (Like button, `app/lib/features/feed/presentation/feed_screen.dart`):**
1. ใน `_buildBody`, ปุ่ม Like ถูกสร้างด้วย `onTapLike: () => _toggleLike(post)` โดย `post` คือตัวแปร local ที่ผูกกับ `_posts[index]` ณ ตอน build ล่าสุด (`feed_screen.dart:225-231`)
2. `_toggleLike(Post post)` (`feed_screen.dart:93-107`) ใช้ `post.likedByMe` (ค่าที่ถูก capture ไว้ตอน build) เพื่อตัดสินใจว่าจะ insert หรือ delete row ใน `likes` table — **ไม่ได้อ่านค่า `_posts[index].likedByMe` สดใหม่**
3. ผู้ใช้แตะปุ่ม Like สองครั้งติดกันเร็วมาก (ก่อนที่ frame ถัดไปจะ rebuild — เกิดขึ้นได้จริงบนมือถือที่ lag หรือผู้ใช้ใจร้อน) — ปุ่มยัง bind กับ closure เดิม (`post` ตัวเดิม ค่าเดิม) เพราะ widget ยังไม่ rebuild
4. ทั้งสอง tap เรียก `_postRepository.toggleLike(postId: post.id, currentlyLiked: post.likedByMe)` ด้วยค่า `currentlyLiked` **เดิมเหมือนกันทั้งคู่** (เช่น `false` ทั้งคู่) → ทั้งสอง network call พยายาม `insert` like row ซ้ำกัน
5. บน database จริง: `likes` table มี PK คือ `(post_id, user_id)` (`supabase/schema.sql` WYN-004 section) — insert ครั้งที่สองจะ violate unique constraint และล้มเหลว
6. เมื่อ call ที่สองล้มเหลว catch block (`feed_screen.dart:103-106`) จะ `setState(() => _posts[index] = post)` — คืนค่ากลับไปเป็น **`post` ตัวเดิมก่อนแตะเลย (unliked)** โดยไม่สนใจว่า call แรกสำเร็จไปแล้วจริง (like ถูกบันทึกใน DB แล้ว)

Expected: กดไลก์ซ้ำเร็ว ๆ ควรจะ debounce/ignore การกดซ้ำระหว่างที่ยังมี request ค้างอยู่ หรืออย่างน้อย state ที่แสดงต้องตรงกับ DB เสมอหลัง request ทั้งหมด resolve แล้ว

Actual: หน้าจอกลับไปแสดง "ยังไม่ได้ไลก์" (ผิด) ทั้งที่ DB มี like row บันทึกอยู่จริง — ไม่มี error message ใด ๆ แสดงให้ผู้ใช้เห็น ผู้ใช้เห็น UI ว่ายังไม่ได้ไลก์จึงกดไลก์ซ้ำอีกครั้ง ก็จะเจอ error เดิมซ้ำอีก (เพราะ DB มี row นั้นอยู่แล้ว) วนเป็นปัญหาเรื้อรังจนกว่าจะ pull-to-refresh เพื่อ sync สถานะจริงจาก DB — ขัดกับ Acceptance Criteria "กดไลก์โพสต์แล้วเห็นจำนวนไลก์เพิ่มทันที กดซ้ำเพื่อเลิกไลก์ได้"

**เทียบกับโค้ดที่ถูกต้องอยู่แล้วในไฟล์เดียวกันของ WYN-004 เอง**: `PostDetailScreen._toggleLike()` (`post_detail_screen.dart:46-58`) อ่านค่า `_post` (mutable field) สดใหม่ทุกครั้งที่ถูกเรียก (`final previous = _post;` ที่จุดเริ่มของ method) จึงไม่มีปัญหานี้ — เป็น pattern ที่ถูกต้องอยู่แล้ว เพียงแต่ `FeedScreen._toggleLike` ไม่ได้ใช้ pattern เดียวกัน (รับ `post` เป็น parameter ที่ถูก capture ไว้ตอน build แทนที่จะอ่านจาก `_posts[index]` สดใหม่ในตัว method เอง)

**Reproduction Steps — #6 (ปุ่ม "โพสต์", `app/lib/features/feed/presentation/create_post_screen.dart`):**
1. ปุ่ม "โพสต์" ผูกกับ `onPressed: _canPost ? _post : null` (`create_post_screen.dart:122-123`) ซึ่งประเมินค่า `_canPost` ตอน build ล่าสุดเท่านั้น
2. `_post()` (`create_post_screen.dart:87-107`) ไม่มี guard `if (_isPosting) return;` ที่จุดเริ่มของ method — อาศัยแค่ปุ่มถูก disable ผ่าน `_canPost` ซึ่งอัปเดตช้ากว่า 1 frame เสมอ (เพราะ `setState` แค่ schedule การ rebuild ไม่ได้ rebuild ทันที)
3. ผู้ใช้แตะปุ่ม "โพสต์" สองครั้งติดกันเร็วมาก (ก่อน frame ถัดไป) — call ที่สองยังผ่านเข้ามาได้เพราะปุ่มยังไม่ทัน disable
4. ทั้งสอง call เรียก `widget.postRepository.createPost(...)` ด้วยเนื้อหาเดียวกัน → มีความเสี่ยงสร้างโพสต์ซ้ำ 2 โพสต์จาก 1 ครั้งที่ผู้ใช้ตั้งใจโพสต์

Expected: กด "โพสต์" ซ้ำเร็ว ๆ ควรสร้างโพสต์ได้แค่ 1 โพสต์เท่านั้น

Actual: มีความเสี่ยงสร้างโพสต์ซ้ำที่ปรากฏใน Global Feed ของทุกคน (ไม่ใช่แค่ผู้โพสต์เห็นเอง) — กระทบภาพลักษณ์ฟีเจอร์หลักของสินค้าโดยตรง

Security Findings:
- ไม่พบ secret/credential hardcode ในโค้ดใหม่ทั้งหมด (`app/lib/features/feed/`, test files ใหม่)
- RLS policies ของ `posts`/`likes`/`comments` ตรวจแล้วถูกต้องตามเจตนา — select เปิดให้ authenticated ทุกคน (ตรงกับ Global Feed), insert/delete จำกัดเฉพาะแถวของตัวเอง (`auth.uid()`) ครบทั้ง 3 ตาราง ไม่มี update policy สำหรับ `posts`/`comments` (ถูกต้อง เพราะไม่มีฟีเจอร์ edit)
- Storage bucket `post-images`: insert-only RLS ตาม `auth.uid()` เหมือน `avatars` bucket เดิม ถูกต้อง — **[Low] ไม่มีการจำกัดขนาดไฟล์ที่ระดับ bucket** เหมือนที่ไม่มีใน `avatars` bucket ของ WYN-003 (ความเสี่ยงเดิม ไม่ใช่ regression ใหม่ — ผู้ใช้ที่ bypass การบีบอัดของแอปแล้วเรียก Storage API ตรง ๆ ด้วย token ที่ valid อาจอัปโหลดไฟล์ใหญ่ผิดปกติได้ แนะนำให้ Founder/Deploy ตั้ง file size limit ที่ระดับ Supabase bucket ตอน provision infra จริง)
- **[Low] `ImagePicker().pickImage()` ใน `CreatePostScreen._pickImage` ไม่มี try/catch ครอบ** — ถ้าผู้ใช้ปฏิเสธสิทธิ์กล้อง/คลังภาพ จะเกิด unhandled `PlatformException` (ไม่มี error message ให้ผู้ใช้เห็น ปุ่มดูเหมือน "ไม่ทำอะไร") — ตรวจแล้วพบว่าเป็น pattern เดิมที่มีอยู่แล้วใน `EditProfileScreen._pickImage` ของ WYN-003 (ผ่าน QA มาแล้ว) ไม่ใช่ regression ใหม่ของ WYN-004 แต่เป็นจุดที่ควรแก้พร้อมกันทั้งระบบในโอกาสถัดไป

Recommendation: ส่งกลับ AI Debug Engineer แก้ #5 และ #6 (Major, root cause เดียวกัน) — แนวทางที่แนะนำ:
- `FeedScreen._toggleLike`: อ่าน `_posts[index]` สดใหม่ในตัว method แทนการใช้ parameter `post` ที่ถูก capture ไว้ตอน build (mirror pattern ที่ถูกต้องอยู่แล้วใน `PostDetailScreen._toggleLike`) และ/หรือเพิ่ม guard กันการกดซ้ำระหว่างที่ยัง pending (เช่น เก็บ `Set<String> _pendingLikePostIds` แล้วเช็คก่อนเริ่ม)
- `CreatePostScreen._post`: เพิ่ม `if (_isPosting) return;` เป็นบรรทัดแรกสุดของ method ก่อน `setState` ใด ๆ
- ควรมี regression test คุ้มครองทั้งสองจุด (เช่น `tester.tap()` สองครั้งติดกันโดยไม่ `pump()` คั่นกลาง แล้วตรวจว่า repository/state ไม่ถูกเรียกซ้ำ) เท่าที่ทำได้ในสถาปัตยกรรมปัจจุบัน — ถ้าทำไม่ได้เพราะ `PostRepository` ไม่มี interface ให้ mock ให้พิจารณาเพิ่ม abstraction บางเบา (เช่น extract เป็น `abstract class PostRepository` หรือรับ callback ที่ mock ได้) เป็นส่วนหนึ่งของการแก้บั๊กนี้

Final Status: **FAIL**
