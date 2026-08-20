# Design Spec — WYN-024: Profile Identity Fields (Cover Image / Website / Username Edit)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-024-profile-identity-fields.md`
อ้างอิง Design System: `.wyn/docs/design/ds-001-color-system.md` (Cyan/Black/White/Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok/Threads โดยตรง) — งานนี้ไม่เพิ่ม token สี/spacing/radius ใหม่แม้แต่ตัวเดียว ใช้ค่าที่มีอยู่แล้วทั้งหมด
อ้างอิง Pattern ที่มีอยู่แล้ว (ต้อง reuse ตรง ๆ ไม่ประดิษฐ์ใหม่):
- `ViewProfileScreen`/`EditProfileScreen` เดิม (WYN-003, WYN-013) — `app/lib/features/profile/presentation/view_profile_screen.dart`, `edit_profile_screen.dart`
- Avatar upload flow เดิม (`_showImageSourceSheet` + `image_picker` + Storage bucket `avatars`) ใน `edit_profile_screen.dart`
- Username availability-check flow เดิม (debounce 400ms + `AuthRepository.isUsernameAvailable`/`setUsername`) ใน `app/lib/features/auth/presentation/username_setup_screen.dart`
- **Cover + overlapping-avatar composition ที่ผ่าน QA แล้วใน Club Core (WYN-014)** — `app/lib/features/club/presentation/club_page.dart`'s `_buildHeader()` (fixed-height 140px rounded cover card + avatar วงกลมทับขอบล่าง) และ `edit_club_info_screen.dart`'s `_buildCoverPicker()`/`_buildIconPicker()` (full-width 16:9 picker + camera badge มุมล่างขวา) — นี่คือ precedent ตรงที่สุดในระบบสำหรับ "cover เหนือ avatar" อยู่แล้ว ไม่ต้องคิดองค์ประกอบใหม่
- `Form`/`TextFormField`/`GlobalKey<FormState>`/`validator` pattern จาก `zoky_checkout_address_screen.dart` — precedent เดียวในแอปสำหรับ client-side format validation ที่บล็อกการบันทึกได้
- Icon+text metadata row จาก `store_screen.dart` (`Icon(size:18) + SizedBox(width: space2) + Expanded(Text(...))`) — ใช้เป็นต้นแบบแถว Website
- Link-style ตัวหนังสือจาก `HashtagText` (`core/widgets/hashtag_text.dart`) — `colorScheme.primary` + `FontWeight.w600` ไม่มี underline — สีลิงก์เดียวที่แอปมีอยู่แล้ว

---

## 0. Risk Verification (บังคับตาม Handoff ของ Product Task) — Mention system ผูกกับ `user_id` ไม่ใช่ username string — ปลอดภัย

ตรวจสอบแล้วจาก `supabase/schema.sql` และ `.wyn/docs/design/wyn-021-mention-system.md`:

- `drop_mentions`/`club_post_mentions` (schema.sql บรรทัด 3075-3112) เก็บ `mentioned_user_id uuid not null references public.profiles (id) on delete cascade` — **เป็น foreign key ไปที่ `profiles.id` (uuid ถาวร) ไม่ใช่ username string เลย**
- ค่านี้ถูก populate จาก `MentionInput`'s resolved id set **ตอนสร้างโพสต์** (WYN-021 doc: "not derived by re-parsing the caption server-side") — id ที่บันทึกไว้ไม่มีทางเปลี่ยนแม้ username ของคนถูก mention จะเปลี่ยนภายหลัง
- Notification triggers (`notify_drop_mention`/`notify_club_post_mention`) ก็ join ผ่าน `mentioned_user_id` (uuid) เช่นกัน — self-mention guard และ recipient ถูกต้องเสมอไม่ว่า username จะเปลี่ยนกี่ครั้ง
- `author_username`/`prof.username` ทุกจุดในระบบ (home_feed/saved_feed views, `ProfileRepository.fetchProfile`) **query จาก `profiles.username` สด ๆ ทุกครั้ง ไม่มีคอลัมน์ไหนใน DB เก็บ username แบบ denormalize/snapshot ไว้ที่อื่นเลย** (ตรวจแล้วทั้งไฟล์ schema.sql, grep `author_username` เจอเฉพาะใน view definition) — เพราะงั้นเมื่อเปลี่ยน username คำว่า `@username` ที่แสดงบนการ์ด/Follow list/comment ทุกจุดจะอัปเดตอัตโนมัติทันทีที่ query ใหม่ ไม่ต้อง backfill/migrate อะไรเพิ่ม ปิด Acceptance Criteria ข้อ "บันทึกสำเร็จแล้วอัปเดตทุกจุดที่อ้างอิง username เดิม" ได้ทันทีโดยไม่ต้องเขียนโค้ดเพิ่มเพื่อ propagate เอง

**สรุป: R3 (แก้ username ได้) ปลอดภัยต่อ mention system 100% ไม่ต้องมี migration/backfill พิเศษ — เขียน Coding ต่อได้ตามแผนเดิม**

**ผลข้างเคียงเล็กน้อยที่ควรบันทึกไว้ (ไม่ block, ไม่ใช่สิ่งที่ต้องแก้ในงานนี้)**: ข้อความแคปชันดิบที่เคยพิมพ์ `@oldusername` ไว้ตอนโพสต์ (เก็บเป็น literal text ใน `drops.caption`/`club_posts.content`) จะยังคงเป็นข้อความเดิมตลอดไป — ถ้าคนอื่นแตะ span `@oldusername` นั้นหลังเจ้าของเปลี่ยนชื่อแล้ว `HashtagText._openMentionedProfile()` จะ `fetchProfileByUsername('oldusername')` ได้ `null` (เพราะไม่มีแถวไหนชื่อนั้นแล้ว) → เงียบไม่เปิดหน้าอะไร (`return` เฉย ๆ) ตรงกับ posture "unresolvable mention fails silently" ที่ WYN-021 ออกแบบไว้อยู่แล้วสำหรับกรณี typo/บัญชีถูกลบ — เป็น**พฤติกรรมเดิมของระบบที่ยอมรับอยู่แล้ว ไม่ใช่ bug ใหม่จาก WYN-024** แต่ควรบันทึกไว้ให้ AI Coding/QA รู้ที่มาเผื่อเจอตอนทดสอบ ไม่ต้องแก้อะไรเพิ่ม (การแก้จริง เช่น "resolve เป็น id ตอนพิมพ์แล้วเก็บ id ลงในสแปนแทน" เป็นงานคนละ scope ของ WYN-021 เอง)

---

## R1: Cover Image

### Screen: `ViewProfileScreen` — Header (Cover + Avatar)

Purpose: แสดงภาพปกเหนือ avatar ให้โปรไฟล์ดูมีตัวตนมากขึ้น สอดคล้องกับที่ Social platform ทั่วไปทำ (ภาพปกกว้างด้านบน + avatar วงกลมทับขอบล่าง) โดยไม่ลอก layout ของ Instagram/TikTok/Threads ตรง ๆ (WYN ใช้ avatar อยู่กึ่งกลาง ไม่ใช่ชิดซ้ายแบบ IG)

User Flow: ไม่มี flow ใหม่ในหน้านี้ — เป็นการแสดงผล read-only เหมือน avatar/bio เดิม ผู้ใช้กด "แก้ไขโปรไฟล์" เพื่อเปลี่ยน (ดู Edit Profile ด้านล่าง)

Decision (โครงสร้าง): ใช้ composition เดียวกับ `ClubPage._buildHeader()` เป๊ะ — การ์ดปกความสูงคงที่ **140px** มุมมน `WynSpacing.radiusMd` (12) เต็มความกว้างที่มีอยู่ (ไม่ทะลุขอบจอ) วางอยู่ **ภายใน `Padding(EdgeInsets.all(WynSpacing.space6))` เดิม** ที่ห่อ header ทั้งก้อนของ `ViewProfileScreen` อยู่แล้ว (ไม่เพิ่ม inset ใหม่ค่าอื่น ต่างจาก Club ที่มี padding เฉพาะของตัวเอง `16,16,16,12` — Profile ใช้ padding เดิมของหน้าตัวเอง `space6`=24 ที่มีอยู่แล้วเพื่อไม่ให้เกิดค่า inset สองมาตรฐานในหน้าเดียวกัน)

ต่างจาก Club ตรงที่ **avatar อยู่กึ่งกลางแนวนอน ไม่ใช่ชิดซ้าย** (ตาม layout เดิมของ Profile ที่ทุกอย่างจัดกึ่งกลางอยู่แล้ว — เหตุผล: (1) คงความสม่ำเสมอกับ Display Name/@username/Bio ที่จัดกึ่งกลางมาตั้งแต่ WYN-003 (2) หลีกเลี่ยงการ "ลอก" ท่า avatar-ชิดซ้าย-ทับมุมล่างซ้ายที่เป็นเอกลักษณ์ของ Instagram/Facebook Cover Photo ตรง ๆ ตามกติกา DS-001 ข้อ 2)

Components:
- `Stack` ภายใน header padding เดิม:
  - เลเยอร์ล่าง: การ์ดปก สูง 140, กว้างเต็มพื้นที่, มุมมน `radiusMd` — ถ้า `profile.coverUrl != null` แสดงรูปด้วย `BoxFit.cover`; ถ้า `null` แสดงพื้นสี `colorScheme.surfaceContainerHighest` เปล่า ๆ (fallback เดียวกับที่ `ClubPage` ใช้ตอน `club.coverUrl == null` — ไม่ error ไม่มีไอคอน broken-image)
  - เลเยอร์บน: avatar เดิม (`AvatarCircle`, radius 40 ค่า default เดิม) จัดกึ่งกลางแนวนอน ทับขอบล่างของการ์ดปกพอดี (จุดกึ่งกลางแนวตั้งของ avatar อยู่ที่เส้นขอบล่างของการ์ดปก เท่ากับ avatar ยื่นลงมาต่ำกว่าการ์ดปกครึ่งหนึ่งของเส้นผ่านศูนย์กลางของมันเอง คือ 40px) — ห่อ `AvatarCircle` ด้วยวงแหวนสี `colorScheme.surface` หนา ~4px (มิเรอร์เทคนิคเดียวกับ `ClubPage`'s `CircleAvatar(radius:32, backgroundColor: surface)` ครอบ `CircleAvatar(radius:28, ...)`) เพื่อแยกขอบ avatar ออกจากภาพปกด้านหลังให้ชัดเจน ไม่ใช่ liquid glass/blur ใด ๆ (เป็นพื้นทึบสี surface ธรรมดา ตรงตาม DS-001 ข้อ 1)
- หลัง `Stack`: เพิ่ม `SizedBox(height: WynSpacing.space10)` (40) ใหม่ ก่อนถึง `SizedBox(height: WynSpacing.space4)` เดิมที่คั่นระหว่าง avatar กับชื่อ — ชดเชยระยะที่ avatar ยื่นลงมาต่ำกว่ากรอบ `Stack` (ไม่แก้ค่า `space4` เดิม เพิ่มค่าใหม่ต่อจากมันเท่านั้น ทั้งสองค่าเป็น token ที่มีอยู่แล้วในระบบ ไม่มีค่าใหม่)

Interactions: ไม่มี tap ใด ๆ ในหน้านี้ (read-only เหมือน avatar เดิม)

States:
- Loading: อยู่ใน `FutureBuilder` เดิมของหน้า — ยังไม่แสดง header เลยจนกว่าจะโหลดเสร็จ (พฤติกรรมเดิมของหน้านี้ ไม่เปลี่ยน)
- Loaded + มี Cover: แสดงรูปจริง
- Loaded + ไม่มี Cover (null): พื้น `surfaceContainerHighest` เปล่า — **นี่คือ fallback UI ที่ AC ต้องการ ไม่ใช่ error ไม่ใช่ช่องว่างที่ดูเหมือน bug**

Responsive Behavior: ความสูงคงที่ 140px ไม่ผูกกับความกว้างจอ (ตาม pattern เดียวกับ Club — เหตุผลเดิม: "ไม่ใช่ AspectRatio เต็มความกว้างจอแบบ FB hero" กันไม่ให้จอกว้างทำให้ปกสูงจนเกะกะ)

Accessibility: `Semantics(label: 'ภาพปกของ {profile.nameOrUsername}', image: true, excludeSemantics: true)` ห่อการ์ดปก มิเรอร์ pattern เดียวกับ `AvatarCircle`'s `'รูปโปรไฟล์ของ {fallbackText}'` เป๊ะ — เมื่อไม่มีปก (`coverUrl == null`) **ไม่ต้องมี Semantics label แยก** (เหมือนที่ Bio ว่างไม่มี placeholder ให้ screen reader อ่าน — พื้นที่ว่างเปล่าไม่ใช่ข้อมูลที่ต้องประกาศ)

Design Rules: ห้าม gradient/blur ทับรูปปก (ไม่ใช่ liquid glass) ห้ามใช้ Cyan เป็นพื้นหลังของการ์ดปก (การ์ดปกไม่ใช่ shape เล็กแบบปุ่ม/badge ตาม DS-001 ข้อ 6 ที่จำกัดพื้นที่ Cyan ต่อเนื่อง)

---

### Screen: `EditProfileScreen` — Cover + Avatar Picker (WYSIWYG กับ View Profile)

Purpose: ให้แก้ไข Cover Image ด้วย composition เดียวกับที่ View Profile จะแสดงจริง (WYSIWYG) แทนที่จะมีฟอร์มแยกที่หน้าตาไม่ตรงกับผลลัพธ์

User Flow: จาก Edit Profile เดิม → แตะที่การ์ดปก (นอกพื้นที่วงกลม avatar) → เปิด bottom sheet เดียวกับที่ avatar ใช้อยู่แล้ว ("ถ่ายรูปใหม่"/"เลือกจากคลังภาพ") → เลือก/ถ่ายเสร็จ preview ทันทีในตำแหน่งเดิม (ยังไม่ upload จนกว่าจะกด "บันทึก") — เหมือน avatar เป๊ะทุกขั้นตอน คนละ tap target เท่านั้น

Decision (reuse avatar's bottom sheet, ไม่ใช่ gallery-only แบบ Club): Product Task R1 ระบุตรง ๆ ว่าให้ reuse "upload/resize flow เดียวกับ avatar" — ต่างจาก `EditClubInfoScreen._pickCover()` ที่เปิด gallery ตรง ๆ (ไม่มี action sheet) เพราะรูปปก Club มักเป็นภาพที่เตรียมมาแล้ว แต่ภาพปก Profile ผู้ใช้ทั่วไปน่าจะอยากถ่ายสดได้เหมือนกับที่ทำกับ avatar — คงความสม่ำเสมอของ interaction model ภายในหน้าเดียวกัน (สองปุ่มบนหน้าเดียวกันควรมีพฤติกรรม tap เหมือนกัน ต่างแค่ปลายทาง state ที่อัปเดต)

Components:
- โครงสร้าง `Stack` เดียวกับ View Profile เป๊ะ (การ์ดปก 140px + avatar ทับขอบล่างกึ่งกลาง + วงแหวน surface) — ต่างที่:
  - การ์ดปก: ถ้ามีรูปที่เพิ่งเลือก (`_pickedCoverBytes`) แสดง preview จาก memory; ถ้าไม่มีและมี `profile.coverUrl` เดิม แสดงรูปเดิม; ถ้าไม่มีทั้งคู่ แสดงไอคอนกลาง `Icons.add_photo_alternate_outlined` ขนาด 32 บนพื้น `surfaceContainerHighest` (ไอคอนเดียวกับที่ `EditClubInfoScreen._buildCoverPicker()` ใช้ตอนไม่มีรูป — สื่อ "แตะเพื่อเพิ่มรูป" ชัดเจนกว่าพื้นเปล่าเฉย ๆ ซึ่งเหมาะกับโหมด "แก้ไข" มากกว่าโหมด "ดู")
  - เพิ่ม badge กล้องเล็ก (`CircleAvatar(radius:14, backgroundColor: surface, child: Icon(Icons.camera_alt, size:16))`) มุมขวาล่างของการ์ดปก — **องค์ประกอบเดียวกันเป๊ะกับ badge กล้องที่ avatar ใช้อยู่แล้ว** วางที่มุมขวาล่างของการ์ดปก (คนละตำแหน่งกับ badge กล้องของ avatar ที่อยู่มุมขวาล่างของวงกลม avatar เอง — ไม่ทับกัน เพราะ avatar อยู่กึ่งกลางแนวนอน ส่วนการ์ดปกกว้างเต็มพื้นที่)
  - `GestureDetector` ของการ์ดปกครอบเฉพาะพื้นที่การ์ดปก (140px, กว้างเต็ม) — `GestureDetector`/`InkWell` ของ avatar เดิม (วงกลม 80px กึ่งกลาง) ยังคงเป็น hit target แยกซ้อนอยู่ด้านบน ไม่ชนกัน เพราะ avatar เป็น child ที่แคบกว่าและอยู่ลึกกว่าใน `Stack` (gesture arena เลือก widget ที่เฉพาะเจาะจงกว่าเมื่อพื้นที่ทับกัน — เทคนิคเดียวกับที่ WYN-013 Screen 6 ใช้แยก tap avatar/ชื่อ ออกจาก tap ทั้งการ์ด)
- ตำแหน่งในหน้า Edit Profile: อยู่บนสุด (แทนที่บล็อก "avatar เดี่ยว ๆ" เดิม) ตามด้วยฟิลด์ข้อความ (ดู R3 สำหรับลำดับฟิลด์เต็ม)

Interactions:
- แตะการ์ดปก → เปิด bottom sheet "ถ่ายรูปใหม่"/"เลือกจากคลังภาพ" (สร้าง instance ที่สองของ sheet เดิม หรือ parameterize sheet เดิมให้รู้ว่ากำลังเลือกรูปให้ field ไหน — เป็นดุลยพินิจของ AI Coding ว่าจะแชร์ method เดียวกันแบบมี parameter หรือแยก method คู่ขนาน ขอแค่ UI/behavior ที่ผู้ใช้เห็นต้องเหมือนกันทุกประการกับของ avatar)
- ใช้ `image_picker` พารามิเตอร์เดียวกับที่ `EditClubInfoScreen._pickCover()` ใช้สำหรับภาพปก (`maxWidth: 1600, maxHeight: 900, imageQuality: 85`) — **ต่างจาก avatar ที่ใช้ 1024×1024** เพราะภาพปกเป็นภาพแนวนอนกว้าง ไม่ใช่สี่เหลี่ยมจัตุรัส ค่านี้มี precedent อยู่แล้วใน Club ไม่ต้องคิดใหม่
- กด "บันทึก" → upload cover (ถ้าเปลี่ยน) ไปที่ bucket `avatars` เดิม path `{userId}/cover.{ext}` (ตามที่ Product Task R1 ระบุ) — เหมือนขั้นตอน `uploadAvatar` เป๊ะ (ดู Handoff ด้านล่างสำหรับ repository method ใหม่)

States: เหมือน avatar เดิมทุกประการ (Default/Image picking/Saving/Error) ไม่มี state ใหม่ที่ไม่เคยมีมาก่อน — แค่มีตัวแปร `_pickedCoverBytes`/`_pickedCoverExtension` เพิ่มขนานกับ `_pickedImageBytes`/`_pickedImageExtension` เดิม

Accessibility: ไม่ต้องเพิ่ม `Semantics` แยกให้การ์ดปกใน Edit mode — มิเรอร์ว่า avatar picker เดิมก็ไม่มี `Semantics` label เพิ่มตอนอยู่ใน edit mode เช่นกัน (ปล่อยให้ default GestureDetector semantics ทำงานตามปกติของ Flutter) ความสม่ำเสมอสำคัญกว่าการเพิ่ม accessibility ที่ avatar เองก็ไม่มีอยู่ในหน้าเดียวกัน (ไม่ใช่ regression เพราะเป็นสภาพเดิมของโค้ด)

Design Rules: ใช้ token/สีชุดเดียวกับ avatar picker ทั้งหมด (badge กล้อง, `surface`, `surfaceContainerHighest`) ห้ามคิดสี/ไอคอนใหม่

---

## R2: Website Field

### Screen: `EditProfileScreen` — Website field

Purpose: ให้ผู้ใช้กรอกลิงก์เว็บไซต์/โซเชียลของตัวเอง (ไม่บังคับ)

Decision (ตำแหน่งในฟอร์ม): วางไว้**หลัง Bio ก่อนปุ่ม "บันทึก"** — มิเรอร์ลำดับการแสดงผลใน View Profile (Avatar/Cover → ชื่อแสดง → @username → Bio → [Website ใหม่ตรงนี้] → จำนวนผู้ติดตาม) ให้ Edit Profile กับ View Profile เรียงลำดับฟิลด์ตรงกันเป๊ะ (WYSIWYG เชิงลำดับ ไม่ใช่แค่เชิงภาพ) — ดู R3 ด้านล่างสำหรับตำแหน่งของ Username field ที่แทรกอยู่ระหว่างชื่อแสดงกับ Bio

Components:
- `TextFormField` ใหม่ (แปลง `TextField` ของ Bio/ชื่อแสดงเดิมเป็น `TextFormField` ทั้งหมดในคราวเดียวเพื่อให้อยู่ใน `Form` เดียวกัน — ดู Handoff):
  - `decoration`: `prefixIcon: Icon(Icons.link)`, `labelText: 'เว็บไซต์'`, `helperText: 'ลิงก์เว็บไซต์หรือโซเชียลของคุณ (ไม่บังคับ)'`
  - `keyboardType: TextInputType.url`
  - `maxLength: 200` (ไม่ต้องมี counter แสดง เหมือนฟิลด์ชื่อแสดงที่มี `maxLength` แต่ไม่มี custom counter widget — เป็น URL เดี่ยว ไม่ใช่ข้อความยาวที่ผู้ใช้ต้องนับตัวอักษรเองแบบ Bio)
  - `validator`: ฟังก์ชันใหม่ (private ในไฟล์นี้ มิเรอร์ตำแหน่งที่ `_usernameRegExp` เป็น field ส่วนตัวของ `username_setup_screen.dart` เอง — ไม่ดันเข้า `core/text_utils.dart` เพราะมีจุดใช้งานเดียว ตาม precedent เดิมของ codebase ที่ regex เฉพาะจุดอยู่ในไฟล์ตัวเอง ไม่ใช่ shared util จนกว่าจะมีจุดใช้ที่สอง) — คืน `null` (ผ่าน) ถ้าช่องว่างเปล่า (ฟิลด์นี้ไม่บังคับ) หรือถ้าข้อความตรงกับ pattern โดเมนที่ยอมรับทั้งมี/ไม่มี `http(s)://` นำหน้า เช่น `^(https?:\/\/)?([\w-]+\.)+[a-zA-Z]{2,}(:\d+)?(\/\S*)?$` (ตัวอย่าง pattern ให้ AI Coding พิจารณาปรับ ไม่บังคับตายตัวเป๊ะทุกอักขระ ตาม Product Task ที่บอกว่า "ไม่ต้องเข้มงวดเกินไป") — ถ้าไม่ผ่าน คืนข้อความ error `'ลิงก์เว็บไซต์รูปแบบไม่ถูกต้อง'`

Interactions:
- ไม่ validate ระหว่างพิมพ์ทุกตัวอักษร (ต่างจาก username ที่ต้อง debounce เพราะเป็น async network call — Website format check เป็น synchronous regex ล้วน ๆ ไม่มีเหตุผลต้อง debounce) — validate เกิดตอนกด "บันทึก" เท่านั้น ผ่าน `_formKey.currentState!.validate()` (มิเรอร์ `zoky_checkout_address_screen.dart`'s `_next()` เป๊ะ)
- ถ้า validate ไม่ผ่าน: `TextFormField` แสดง error ใต้ช่องทันที (built-in ของ `Form`/`TextFormField`) และ **ไม่เรียก network call ใด ๆ เลย** (บล็อกตั้งแต่ client-side ก่อนถึงขั้นตอน upload/save)
- ก่อนบันทึกจริง: normalize ค่าที่ผ่าน validate แล้ว — ถ้าไม่มี `http://`/`https://` นำหน้า ให้เติม `https://` ให้อัตโนมัติก่อนส่งเข้า `updateProfile` (เก็บค่าที่มี scheme ครบเสมอใน DB ไม่เก็บ raw input ที่กำกวม) — ทำให้ตอน render ฝั่ง View Profile ไม่ต้องเดา/เติม scheme ทีหลังอีกครั้ง (logic เดียว จุดเดียว ตอน save)

States: เหมือนฟิลด์ข้อความอื่นในหน้านี้ทุกประการ (`enabled: !_isSaving`)

Accessibility: `TextFormField` มาตรฐานประกาศ label/error ให้ screen reader เองอยู่แล้วผ่าน `InputDecoration` (เหมือนทุกฟิลด์อื่นในหน้านี้ ไม่ต้องเพิ่ม `Semantics` พิเศษ)

Design Rules: ไอคอน `Icons.link` ใช้สี default ของ `prefixIcon` (ไม่บังคับสี Cyan — ไอคอนในฟอร์มไม่ใช่ "ลิงก์ที่กดได้" ในบริบทนี้ เป็นแค่ label icon ของฟิลด์กรอกข้อมูล ต่างจากตอนแสดงผลใน View Profile ที่เป็นลิงก์กดได้จริงและต้องใช้สี link ตาม R2's View Profile section ด้านล่าง)

---

### Screen: `ViewProfileScreen` — Website link display

Purpose: แสดงลิงก์เว็บไซต์ที่กดได้ เปิด browser ภายนอก

Decision (ตำแหน่ง): วางเป็นแถวใหม่ **ใต้ Bio ก่อนแถวจำนวนผู้ติดตาม** (ตรงกับตำแหน่งในฟอร์ม Edit Profile ด้านบน) — ถ้าไม่มี Bio ให้แถว Website อยู่ถัดจาก `@username` แทน (ระยะห่างเท่ากับที่ Bio เคยอยู่ — ใช้เงื่อนไข "ถ้ามีอันก่อนหน้าแสดง ให้เว้น `space4` เท่ากันเสมอ" แบบเดียวกับที่ Bio เองก็มีเงื่อนไข "ถ้าไม่มีให้ซ่อนไปเลย" อยู่แล้วในโค้ดปัจจุบัน)

Components:
- ถ้า `profile.website == null` → **ไม่แสดงแถวนี้เลย** (มิเรอร์ Bio's precedent เป๊ะ: "ถ้ายังไม่มีให้ซ่อนไปเลย ไม่ใช้ placeholder 'ยังไม่มีเว็บไซต์'" — นี่คือ fallback UI ที่ AC ต้องการสำหรับ Website ที่ยังไม่ได้ตั้งค่า)
- ถ้ามีค่า: แถว `Row` กึ่งกลางแนวนอน (`mainAxisAlignment: center`, มิเรอร์ layout centered ของทั้ง header) ประกอบด้วย `Icon(Icons.link, size: 18)` + `SizedBox(width: WynSpacing.space2)` + ข้อความลิงก์ — โครงร่างเดียวกับ `store_screen.dart`'s ที่อยู่ร้าน แต่จัดกึ่งกลางแทน left-align (เพราะ header ทั้งก้อนของ Profile จัดกึ่งกลางอยู่แล้ว ต่างบริบทกับ Store ที่ left-align)
- ข้อความที่แสดง: ตัด scheme (`https://`/`http://`) ออกเพื่อความอ่านง่าย (ค่าที่เก็บใน DB มี scheme เสมอตาม normalize ใน Edit Profile ข้างบน แต่แสดงแบบตัด scheme เพื่อไม่ให้ยาวเกะกะ — เมื่อกดถึงเปิดด้วย URL เต็มที่เก็บไว้จริง ไม่ใช่ข้อความที่ตัดแล้ว)
- สไตล์ข้อความ: **สีและน้ำหนักเดียวกับ `HashtagText`'s tappable span เป๊ะ** — `colorScheme.primary` + `FontWeight.w600` ไม่มี underline (สีลิงก์เดียวที่แอปมีอยู่แล้ว ไม่ประดิษฐ์สีลิงก์ใหม่) — ยอมรับ contrast ต่ำกว่า AA บนพื้นขาวใน light mode ตามที่ DS-001 Section 3.0/4 ระบุไว้แล้วว่าเป็นความเสี่ยงที่ Founder รับทราบและยอมรับสำหรับ "ลิงก์/ไอคอนเปล่าบนพื้นขาว" — **ไม่ใช่ gap ใหม่ที่ WYN-024 สร้างขึ้น เป็นการสืบทอด token เดิมที่มีความเสี่ยงนี้อยู่แล้วตรง ๆ**
- ห่อทั้งแถวด้วย `InkWell` (มิเรอร์เทคนิคของ `_FollowCountTarget` ที่มีอยู่แล้วในไฟล์เดียวกัน — `InkWell` + `Padding` แนวตั้งเพื่อให้ hit area ถึง 44px ขั้นต่ำแม้ตัวอักษรจะสูงไม่ถึง)

Interactions: แตะแถว → เปิด URL เต็ม (ที่เก็บไว้ใน `profile.website`) ด้วย `url_launcher`'s `launchUrl(uri, mode: LaunchMode.externalApplication)` (เปิด browser ภายนอกจริงตามที่ Product Task ระบุ ไม่ใช่ in-app WebView — เหตุผล: แอปยังไม่มี in-app WebView ที่ไหนเลย การเพิ่ม WebView component ใหม่เกินขอบเขตของงานนี้ ขณะที่ external browser ตรงตาม requirement อยู่แล้วโดยไม่ต้องเพิ่ม component ใหม่)

States:
- ไม่มี loading state แยก (URL เปิดผ่าน OS โดยตรง เหมือน native picker ของ avatar ที่ไม่มี custom loading)
- ถ้า `launchUrl` คืน `false`/throw (ไม่มีแอปเปิดได้ กรณีหายาก) → เงียบไม่ error dialog (มิเรอร์ posture "fail silently" เดียวกับที่ `HashtagText`'s unresolvable mention ใช้อยู่แล้ว — ความเสี่ยงต่ำ ไม่ใช่ core flow ของแอป)

Accessibility: `Semantics(label: 'ลิงก์เว็บไซต์ {ข้อความที่ตัด scheme แล้ว} กดเพื่อเปิด', button: true, excludeSemantics: true)` มิเรอร์ pattern ของ `_FollowCountTarget`/ปุ่ม Follow ที่มีอยู่แล้วในไฟล์เดียวกันเป๊ะ

Design Rules: ห้ามใช้ underline แบบ hyperlink เว็บทั่วไป (ตรงตามที่ WYN-013 Design Rules ระบุไว้แล้วว่า "ไม่ mark ด้วยสีหรือ underline แบบลิงก์เว็บ ให้ความรู้สึกกดได้ผ่าน ripple" — ในที่นี้ยกเว้นเรื่องสีเพราะ Website เป็นลิงก์จริงที่ต้องสื่อสารด้วยสีตาม convention สากลที่ `HashtagText` วางไว้แล้ว แต่ยังคงไม่มี underline เหมือนกัน)

---

## R3: Username Edit Flow

### Decision: รวมเข้า Edit Profile เดิม ไม่สร้างหน้าจอแยก

เหตุผล:
1. Product Task เปิดทางเลือกไว้ทั้งสองแบบ ("เปิดหน้าจอแก้ Username ใหม่ หรือเพิ่มเข้า `edit_profile_screen.dart` เดิม") — เลือกรวมเข้า Edit Profile เพราะทุกฟิลด์ identity อื่น (Display Name/Bio/Cover/Website) อยู่ในจุดเดียวกันหมดแล้วตาม pattern เดิมของ WYN-003 ("หน้าเดียวแก้ทุกอย่าง") การแยก Username ออกไปเป็นหน้าที่สองจะทำให้ผู้ใช้ต้องเข้า-ออกสองรอบเพื่อแก้โปรไฟล์ตัวเองโดยไม่มีเหตุผลทาง UX รองรับ
2. Username field ใช้ `TextFormField` + `validator` ร่วมกับ Website field ได้ใน `Form` เดียวกัน (ดูด้านล่าง) — ลด mechanism ซ้ำซ้อน

Purpose: ให้แก้ Username ได้หลัง onboarding โดยใช้ validation/availability-check UX เดียวกับตอนตั้งครั้งแรก

Decision (ตำแหน่งในฟอร์ม): วางไว้**ระหว่างชื่อแสดงกับ Bio** (Cover/Avatar → ชื่อแสดง → **Username** → Bio → Website → บันทึก) — เพราะ Username เป็น identity field ระดับเทคนิค/ระบบ (คล้ายกับที่ View Profile แสดง `@username` เป็นบรรทัดที่สองต่อจากชื่อแสดงทันที ก่อน Bio) จึงควรอยู่ถัดจากชื่อแสดงในฟอร์มด้วยเหตุผลเดียวกัน

Components:
- `TextFormField` ใหม่ **มิเรอร์หน้าตาของ `username_setup_screen.dart`'s `TextField` เป๊ะ**: `prefixText: '@'`, `labelText: 'ชื่อผู้ใช้'`, `helperText: 'ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น (3-20 ตัวอักษร)'` (ข้อความเดียวกันคำต่อคำ), `suffixIcon` เดียวกัน (spinner ตอน checking, `Icons.check_circle` สีเขียวตอน available), `errorText` เดียวกัน (`'ชื่อผู้ใช้นี้ถูกใช้แล้ว'`/`'รูปแบบไม่ถูกต้อง'`)
- ใช้ regex เดียวกันเป๊ะ: `^[a-z0-9_]{3,20}$` (ตามที่ Product Task R3 ระบุตรง ๆ ให้ใช้ตัวเดียวกับ onboarding)
- prefill ด้วย `widget.profile.username` เดิมตอน `initState` (ต่างจาก onboarding ที่เริ่มจากช่องว่างเปล่า)

### จุดที่ต้องระวังเป็นพิเศษ (ไม่ใช่แค่ copy-paste onboarding ตรง ๆ ได้) — self-exclusion ของ availability check

`AuthRepository.isUsernameAvailable(username)` (`app/lib/features/auth/data/auth_repository.dart`) query แค่ `.eq('username', username)` แล้วเช็คว่าเจอแถวไหม — **ไม่มี parameter ให้ exclude user id ของตัวเอง** เพราะตอน onboarding (WYN-002) ไม่มีทางที่จะเจอ username ซ้ำกับของตัวเองได้ (ยังไม่มี username เดิม) แต่ตอนแก้ไขใน Edit Profile ผู้ใช้จะเห็น username เดิมของตัวเองที่ prefill ไว้แล้ว — ถ้า debounce เรียก `isUsernameAvailable(currentUsername)` ตรง ๆ จะเจอแถวของตัวเองแล้วรายงานผิดว่า **"ถูกใช้แล้ว" ทั้งที่เป็นของตัวเอง**

Product Task สั่งไว้ตรง ๆ ให้ reuse `isUsernameAvailable` "ตรง ๆ ไม่ต้องเขียน availability-check ใหม่" — เพราะงั้น**ห้ามแก้ signature ของ `AuthRepository.isUsernameAvailable`/`setUsername`** (ทั้งสอง method ใช้ร่วมกับ onboarding อยู่ การเพิ่ม `excludeUserId` parameter จะกระทบ call site เดิมด้วย แม้จะทำเป็น optional param ได้ก็เกินคำสั่งของ Product ที่ระบุชัดว่า "ไม่ต้องเขียนใหม่") — วิธีแก้ที่ถูกต้องคือ **short-circuit ที่ฝั่ง Edit Profile เอง (client-side compare กับค่าเดิมที่จำไว้ตอน `initState`) ก่อนเรียก repository**:

- ถ้าค่าที่พิมพ์ (หลัง debounce) **เท่ากับ `widget.profile.username` เดิมเป๊ะ** → ข้ามการเรียก `isUsernameAvailable` ไปเลย ตั้ง status เป็น "ไม่ต้องเช็ค/ใช้ได้" ทันที (ไม่ต้องรอ network) — เทียบเท่ากับ `_UsernameStatus.available` ในทางปฏิบัติ (ปุ่มบันทึกกดได้) แต่ไม่มี network round-trip โดยไม่จำเป็น
- ถ้าต่างจากค่าเดิม → เรียก debounce + `isUsernameAvailable` แบบเดียวกับ onboarding ทุกประการ

**เดียวกันนี้ต้องระวังตอนกด "บันทึก" ด้วย**: `AuthRepository.setUsername()` เรียก `isUsernameAvailable` ซ้ำอีกครั้งก่อนเขียนจริง (race-condition guard เดิม) — ถ้า username ไม่ได้ถูกแก้เลย (ผู้ใช้แก้แค่ Bio/Website แล้วกด บันทึก) **ห้ามเรียก `setUsername` เลย** ไม่งั้นจะโดน self-exclusion bug เดียวกันตอน save จริง — ให้ `_save()` เช็คก่อนว่า `_usernameController.text.trim() != widget.profile.username` แล้วค่อยเรียก `setUsername` แบบมีเงื่อนไข (มิเรอร์ pattern เดียวกับที่ `_save()` ปัจจุบันมีอยู่แล้วสำหรับ avatar: `if (_pickedImageBytes != null) { ... upload ... }` — ใช้หลักการเดียวกัน "เรียก mutation เฉพาะตอนมีการเปลี่ยนแปลงจริง" ไม่ใช่ pattern ใหม่)

### Decision: ลำดับการบันทึกตอนกด "บันทึก" — Username ต้องเสร็จก่อนฟิลด์อื่นเสมอ (fail-fast)

ถ้า username ถูกแก้และซ้ำกับคนอื่น (race condition ตอนกดบันทึกพร้อมกัน) แล้ว mutation อื่น (avatar/cover upload, `updateProfile` ของ display_name/bio/website) เกิดขึ้นไปก่อนแล้ว จะเหลือ**สถานะครึ่ง ๆ กลาง ๆ**: ฟิลด์อื่นบันทึกสำเร็จแต่ username ไม่สำเร็จ ผู้ใช้เห็น error แต่ข้อมูลจริงเปลี่ยนไปแล้วบางส่วน สับสน — เพราะงั้น `_save()` ต้องเรียงลำดับ:

1. ถ้า username ถูกแก้ (ต่างจากเดิม) → เรียก `setUsername` **ก่อน** อย่างอื่นทั้งหมด — ถ้า throw `UsernameTakenException` ให้หยุดทันที (เหมือน `_UsernameSetupScreenState._submit()`'s catch เป๊ะ: `setState(() => _status = _UsernameStatus.taken)`) ไม่แตะ avatar/cover/`updateProfile` เลย ผู้ใช้เห็น error ตรงช่อง username ทันทีโดยไม่มีอะไรถูกบันทึกไปก่อน
2. ผ่านขั้นตอน 1 แล้ว (หรือ username ไม่ได้ถูกแก้เลย ข้ามขั้นตอนนี้) → upload avatar (ถ้าเปลี่ยน) แล้ว upload cover (ถ้าเปลี่ยน) — ลำดับระหว่างสองอันนี้ไม่สำคัญ (independent operations)
3. สุดท้ายเรียก `updateProfile` (ขยายให้รับ `website` เพิ่มจากเดิม `displayName`/`bio`) เขียน display_name/bio/website ในคำเรียกเดียว (เหมือนเดิมที่เป็น update เดียวอยู่แล้ว)

Interactions (ภาพรวม R3): พิมพ์ในช่อง Username → debounce 400ms (ใช้ `Timer` เหมือน onboarding เป๊ะ) → เช็คทั้ง short-circuit (เท่าค่าเดิม) และ `isUsernameAvailable` (ต่างจากค่าเดิม) → suffix icon/errorText อัปเดตตาม `_UsernameStatus` เดียวกับ onboarding

States: `_UsernameStatus` enum เดียวกับ onboarding (`idle, checking, available, taken, invalid`) — เพิ่มการตีความใหม่แค่ตอน initial: ค่า prefill ที่ยังไม่ถูกแตะเลยถือเป็น "พร้อมบันทึก" โดยไม่ต้องรอ debounce ก่อน (ผู้ใช้ที่ไม่อยากแก้ username เลยต้องกด "บันทึก" ได้ทันทีโดยไม่ติด gate แบบ onboarding ที่บังคับต้องเห็น available ก่อนเสมอ)

Accessibility: mirror `username_setup_screen.dart` ทุกจุด (มี `errorText`/`helperText` มาตรฐานของ `InputDecoration` อยู่แล้ว ไม่ต้องเพิ่ม Semantics พิเศษ เหมือนต้นฉบับ)

Design Rules: ห้ามเปลี่ยนข้อความ helper/error จาก onboarding แม้แต่คำเดียว (ผู้ใช้ต้องเห็นภาษาเดียวกันไม่ว่าจะตั้งครั้งแรกหรือแก้ทีหลัง — ความสม่ำเสมอของ copywriting)

---

## Design Rules (รวมทั้งงาน)

- ไม่มีการเพิ่ม color/spacing/radius token ใหม่ในงานนี้ทั้งหมด — ทุกจุดใช้ `WynSpacing`/`colorScheme` ที่มีอยู่แล้ว
- Cover Image ใช้ composition เดียวกับ `ClubPage`/`EditClubInfoScreen` (140px + overlap avatar + camera badge) ทุกจุด ต่างแค่ avatar อยู่กึ่งกลางแทนชิดซ้าย
- Username field มิเรอร์ `username_setup_screen.dart` เป๊ะ (ข้อความ/ไอคอน/regex) ห้ามมีถ้อยคำ/พฤติกรรมต่างจากตอน onboarding
- Website link ใช้สี/น้ำหนักตัวอักษรเดียวกับ `HashtagText`'s tappable span เป๊ะ (`colorScheme.primary`, w600, ไม่ underline)
- ฟิลด์ที่ยังไม่ตั้งค่า (Cover=null, Website=null) → ซ่อน/fallback แบบเดียวกับที่ Bio ใช้อยู่แล้ว ไม่มี placeholder ข้อความ "ยังไม่มี..."
- Username field เป็นข้อยกเว้นเดียวที่ **ห้าม** ซ่อนเมื่อว่าง (ไม่มีทางว่างอยู่แล้วเพราะเป็น field บังคับตั้งแต่ onboarding)

---

## Handoff: AI Coding

### Database (`supabase/schema.sql`) — additive เท่านั้น ไม่ต้องขออนุมัติ Founder (ไม่ใช่ destructive change)
1. `alter table public.profiles add column if not exists cover_url text;`
2. `alter table public.profiles add column if not exists website text;`
3. ไม่ต้องแตะ `username`/constraint ใด ๆ ที่มีอยู่แล้ว — ไม่มีการเพิ่ม format CHECK ใหม่ในรอบนี้ (นอกขอบเขตของ Product Task R3 ที่ระบุแค่ client-side validation — ถ้า Product อยากได้ DB-level CHECK เพิ่มในอนาคต ให้เป็น task แยก เพราะต้องตรวจ backward-compat กับ username ที่มีอยู่แล้วในระบบก่อน)

### `app/lib/features/profile/data/profile.dart`
- เพิ่ม field `coverUrl`/`website` (`String?`) เข้า `Profile` + `Profile.fromMap` (`map['cover_url']`/`map['website']`) — ตาม pattern เดียวกับ `avatarUrl`/`bio` เดิมเป๊ะ

### `app/lib/features/profile/data/profile_repository.dart`
- `fetchProfile`/`fetchProfileByUsername`/`searchProfiles`: เพิ่ม `cover_url, website` เข้า `.select(...)` string ทั้ง 3 จุด (ปัจจุบัน select แค่ `id, username, display_name, bio, avatar_url`)
- `updateProfile`: เพิ่ม parameter `website` (required เหมือน `displayName`/`bio` เดิม — ฟิลด์ว่างได้แต่ต้องส่งเสมอ ใช้ `normalizeOptionalText` เดียวกับ `displayName` เพื่อแปลง `''` เป็น `null` ก่อนเขียน DB เนื่องจากยังไม่มี CHECK constraint บังคับ min-length แต่ก็ควรเก็บเป็น `null` ไม่ใช่ `''` ให้สอดคล้องกับ convention เดิมของไฟล์นี้)
- เพิ่ม `uploadCover({required userId, required bytes, required fileExtension})` — **คัดลอกโครงสร้างจาก `uploadAvatar` เป๊ะ** ต่างแค่ path เป็น `'$userId/cover.$fileExtension'` และเขียนคอลัมน์ `cover_url` แทน `avatar_url` (รวม cache-busting `?v=timestamp` แบบเดียวกัน)

### `app/lib/features/profile/presentation/edit_profile_screen.dart` — เปลี่ยนมากที่สุด
1. ครอบทั้งฟอร์มด้วย `Form(key: _formKey)` (`GlobalKey<FormState>` ใหม่) — แปลง `TextField` ทั้งหมด (ชื่อแสดง, Bio) เป็น `TextFormField` (ไม่ต้องมี `validator` สำหรับสองฟิลด์นี้ เหมือนเดิมที่ไม่มี client-side format validation)
2. เพิ่ม Username `TextFormField` (validator ผูกกับ `_usernameStatus` local state) ตาม R3
3. เพิ่ม Website `TextFormField` (validator ตาม regex ใน R2) ตาม R2
4. เปลี่ยน avatar picker เดี่ยว ๆ เดิมเป็น `Stack` cover+avatar ตาม R1 — เพิ่ม `_pickedCoverBytes`/`_pickedCoverExtension` + `_pickCover()`/sheet สำหรับ cover (มิเรอร์ `_pickImage()`/`_showImageSourceSheet()` เดิม)
5. `_save()`: เพิ่ม `if (!(_formKey.currentState?.validate() ?? false)) return;` เป็นบรรทัดแรก (block username-status error + website format error พร้อมกันในจุดเดียว) จากนั้นทำตามลำดับ fail-fast ที่ระบุใน R3 (username ก่อน → avatar/cover → `updateProfile` รวม website)
6. `pop(Profile(...))` ตอนจบ: เพิ่ม `username` (ค่าใหม่ถ้าเปลี่ยน), `coverUrl`, `website` เข้า object ที่ส่งกลับ (ปัจจุบัน `Profile(...)` ที่ pop กลับไม่มี `coverUrl`/`website`/username คงเดิม — ต้องส่งค่าที่อัปเดตแล้วครบเพื่อให้ `ViewProfileScreen._reload()` ไม่ต้อง refetch ซ้ำโดยไม่จำเป็น — แม้ตอนนี้ `_openEdit` จะเรียก `_reload()` เสมออยู่แล้วก็ตาม ให้คง object ที่ pop กลับให้ครบถ้วนสอดคล้องกับ field ใหม่เพื่อไม่ทิ้ง dead field)

### `app/lib/features/profile/presentation/view_profile_screen.dart`
1. เพิ่ม `Stack` cover+avatar ตาม R1 แทนที่ `AvatarCircle` เดี่ยว ๆ เดิมในบล็อก header
2. เพิ่มแถว Website ตาม R2 (ใต้ Bio, ก่อนแถวจำนวนผู้ติดตาม) — ต้อง import `package:url_launcher/url_launcher.dart`

### `app/pubspec.yaml`
- เพิ่ม `url_launcher: ^6.3.0` เข้า `dependencies:` ตรง ๆ (ปัจจุบันมีแค่เป็น **transitive dependency** ผ่าน `share_plus` เท่านั้น ยังไม่เคย import ใช้ตรงในโค้ดแอปเลยสักจุด — ต้องประกาศเป็น direct dependency ก่อนใช้งานจริงเพื่อไม่ให้ผูกเวอร์ชันไว้กับ `share_plus`'s transitive resolution โดยบังเอิญ)

### Regression test ที่ต้องมี (ตาม Acceptance Criteria ของ Product Task)
1. Cover/Avatar upload flow (mirror `edit_profile_screen_test.dart` เดิมของ avatar อัปโหลด — เพิ่มเคสเดียวกันสำหรับ cover)
2. Website format validation: reject ข้อความไม่ใช่ URL, accept ทั้งมี/ไม่มี `https://` นำหน้า, ค่า `null`/ว่างไม่ error, บันทึกแล้วเก็บค่าที่มี scheme เสมอ
3. **Username self-exclusion (สำคัญที่สุดของงานนี้ — ต้อง red→green proof จริง)**: กด "บันทึก" โดยไม่แก้ username เลย (คงค่าเดิม) ต้องสำเร็จ ไม่ error "ถูกใช้แล้ว" — เขียน test ที่ล้มก่อนถ้าไม่มี short-circuit (เรียก `RecordingAuthRepository`/fake ที่จำลอง `isUsernameAvailable` คืน `false` เมื่อ query ตรงกับ username ปัจจุบันของผู้ใช้เอง เหมือนพฤติกรรมจริงของ DB) แล้วพิสูจน์ว่าผ่านหลังใส่ short-circuit
4. Username เปลี่ยนสำเร็จ → `pop()` คืน `Profile` ใหม่ที่มี username อัปเดต, `ViewProfileScreen` แสดง `@username` ใหม่ทันที
5. Username ซ้ำกับคนอื่น (จริง ไม่ใช่ตัวเอง) → ยัง block ได้เหมือนเดิม (ไม่ regression กับพฤติกรรม onboarding)
6. Fail-fast ordering: username ซ้ำ (mock throw `UsernameTakenException`) → ยืนยันว่า `updateProfile`/`uploadAvatar`/`uploadCover` **ไม่ถูกเรียกเลย** (ใช้ `Recording*Repository` spy pattern เดิมของโปรเจกต์นับจำนวนครั้งที่ถูกเรียก)
7. `flutter analyze`/`flutter test` ต้องผ่านครบ ไม่มี regression กับ WYN-003/WYN-013/WYN-021 (โดยเฉพาะ mention tap-resolve ต้องยังทำงานถูกต้องหลัง username เปลี่ยน — ทดสอบ mention เก่าที่อ้าง username เดิมแล้ว resolve ไม่เจอ = คาดหวังเงียบ ไม่ error ตาม Section 0)

### QA ต้องตรวจเพิ่มเป็นพิเศษ
- **Self-exclusion bug** (ข้อ 3 ด้านบน) — จุดเสี่ยงที่สุดของงานนี้ เพราะเป็น false-positive ที่จะบล็อกผู้ใช้ทุกคนที่กด "บันทึก" โปรไฟล์โดยไม่ได้ตั้งใจแก้ username เลย ถ้าไม่มี short-circuit จริง
- Fail-fast ordering เมื่อ username ซ้ำ ต้องไม่มี partial write เกิดขึ้นก่อนหน้า (avatar/cover/display_name/bio/website ต้องไม่เปลี่ยนเลยถ้า username save ไม่ผ่าน)
- Mention เก่ายังชี้ไปคนถูกต้อง (ผ่าน `mentioned_user_id`) แม้ caption จะยังมีข้อความ `@oldusername` ค้างอยู่ — ตรวจว่า notification/แจ้งเตือนเก่าไม่ผิดคน
- Storage RLS: `{userId}/cover.{ext}` path ยังผ่าน policy เดิม (`(storage.foldername(name))[1] = auth.uid()::text`) โดยไม่ต้องแก้ policy ใด ๆ

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement R1/R2/R3 ตาม Design decisions ข้างต้น — ดู Product Task `.wyn/tasks/backlog/WYN-024-profile-identity-fields.md` สำหรับ Requirements/Acceptance Criteria ฉบับเต็ม Risk เรื่อง mention/username coupling ได้ตรวจสอบและยืนยันความปลอดภัยแล้วใน Section 0 ด้านบน (ผูกกับ `user_id` ไม่ใช่ username string) — Coding ไม่ต้องตรวจซ้ำ แต่ต้องระวังจุด self-exclusion ของ `isUsernameAvailable`/fail-fast ordering ที่ระบุไว้ใน R3 ให้ครบ เพราะเป็นความเสี่ยง UX/data-integrity ตัวจริงของงานนี้ (ไม่ใช่ mention เหมือนที่ Product กังวลไว้แต่แรก)
