# Product Task — WYN-073

Status: coding done — ส่งต่อ AI QA & Security
Owner: AI Product Manager → AI Coding → AI QA & Security

Feature: WYNOS Design Reference Rollout — Screen 05: Profile (own profile)

Goal: หน้าถัดไปในลำดับ reference ตามที่ Founder สั่ง (หน้า 1-4 มีทีมอื่นทำอยู่แล้ว ข้ามมาที่หน้า 5 ตรงตาม
คำสั่ง 2026-08-29) — implement Profile screen (เฉพาะ **มุมมองเจ้าของโปรไฟล์ (own profile)**) ให้ตรงกับ
`/05-profile.tsx`

Target User: ผู้ใช้ทุกคนเมื่อดูโปรไฟล์ตัวเอง (แท็บ Profile ใน Bottom Nav)

Reference file: `/05-profile.tsx` — ไฟล์นี้ไม่มี `SPEC.md` แยกแบบหน้า Home; **ไฟล์ `.tsx` เองคือ spec**
(มี doc comment หัวไฟล์ระบุ token system เดียวกับหน้า Home + รายการการเปลี่ยนแปลงที่ตั้งใจไว้ชัดเจน)

**สโคปสำคัญ: task นี้ครอบคลุมเฉพาะโปรไฟล์ของตัวเอง (isOwnProfile == true) เท่านั้น** — โปรไฟล์ของคนอื่น
(`18-other-profile.tsx`) เป็น task แยกที่ยังไม่ถึงคิว ห้ามแตะ branch `else` (isOwnProfile == false) ใน
`view_profile_screen.dart`

## สิ่งที่ reference สั่งเปลี่ยนชัดเจน (ระบุไว้ใน doc comment ของไฟล์เอง)

1. **ตัด tab "ตอบกลับ" (Replies) และ "มีเดีย" (Media) ออก** — เหลือ 3 tab: โพสต์ / ReDrop / ถูกใจ
   (ปัจจุบันโค้ดมี 5 tab คงที่: Posts/ReDrops/Replies/Media/Likes จาก WYN-071 R5 — **นี่คือการย้อนกลับ
   requirement บางส่วนของ WYN-071 โดยตรง ตาม reference ใหม่ที่ Founder อัปโหลดเอง ไม่ต้องถามซ้ำ**)
2. **เอาไอคอน logout ออกจาก header** — ย้ายเข้าไปอยู่ใน Settings (gear) menu แทน (ปัจจุบัน
   `view_profile_screen.dart` มี `IconButton(Icons.logout, onPressed: _signOut)` แยกอยู่ใน AppBar ของ
   own-profile โดยตรง, บรรทัด ~989-993 — ต้องย้าย logic ของ `_signOut()` (unregister push token +
   `Supabase.instance.client.auth.signOut()`) ไปเป็นปุ่ม/แถวใน `SettingsScreen`
   (`app/lib/features/settings/presentation/settings_screen.dart`, 683 บรรทัด — ปัจจุบันยังไม่มีปุ่ม
   sign-out ในนี้เลย ต้องเพิ่มใหม่ ไม่ใช่แค่ย้าย)
3. **เอา "Club ของฉัน" shelf ออกจาก Profile** — ปัจจุบันมี horizontal shelf นี้อยู่แล้ว (บรรทัด ~887-913
   ของ `view_profile_screen.dart`, comment อ้าง WYN-015 Screen 4) — ลบออกจาก own-profile ทั้งหมด
4. **ลด emphasis ของปุ่ม "แก้ไขโปรไฟล์"**: จากปุ่มเต็มความกว้างมีขอบ + ไอคอนมีขอบอีก 2 ปุ่ม → เหลือ pill
   เล็กตรงกลาง + ไอคอนไม่มีขอบ 2 อัน (Bookmark, PenLine) ข้างๆ ตาม `ActionRow` ใน reference บรรทัด
   147-164

## สิ่งที่ reference "ไม่พูดถึง" (ตีความตามหลักการเดียวกับ WYN-072/Home — ไม่ใช่คำสั่งให้ลบ)

- **`ProfileRecommendationSection`** (WYN-071 R4, การ์ดแนะนำผู้ใช้ใต้ ActionRow) — ไม่ปรากฏใน layout ของ
  reference (`IdentityBlock → StatsRow → ActionRow → Tabs` ตรงๆ ไม่มีช่องให้ recommendation section) แต่
  doc comment หัวไฟล์ที่แจกแจงการเปลี่ยนแปลง**ไม่ได้พูดถึงการลบส่วนนี้เลย** ต่างจาก 4 ข้อข้างบนที่ระบุชัด —
  **การตัดสินใจ: คงไว้เหมือนเดิม ไม่แตะ** (เหมือนที่ WYN-072 คง ClubSection/Trending ของ Home ไว้) ถ้า AI
  Coding เห็นว่าตำแหน่งมันขัดกับ layout ใหม่หลัง ActionRow ให้บันทึกเป็น Known Issue พร้อมข้อเสนอ ไม่ใช่ลบเอง
- **ไอคอน Search/Notifications ใน AppBar**: ตรวจโค้ดแล้วพบว่าปัจจุบันไอคอนเหล่านี้อยู่แค่ branch
  `!isOwnProfile` (โปรไฟล์คนอื่น) เท่านั้น — **own-profile ไม่มีไอคอนพวกนี้อยู่แล้วตั้งแต่ต้น** จึงไม่มีความ
  ขัดแย้งกับ reference ในจุดนี้ ไม่ต้องแก้อะไร

## Requirements

- R1. ใช้ token file เดียวกับที่ WYN-072 สร้างไว้ (`app/lib/core/design/wynos_home_tokens.dart` หรือชื่อ
  ที่ WYN-072 ตั้งจริง — **ตรวจสอบก่อนว่ามีอยู่แล้วหรือยัง เพราะ WYN-072 กำลังทำขนานอยู่ในอีก branch/agent**
  ถ้ายังไม่มี/ยังไม่ merge เข้า branch นี้ ให้สร้าง subset เดียวกันเองตาม token values ใน doc comment ของ
  `05-profile.tsx` เอง (มีครบอยู่แล้ว: ink/paper/canvas/graphite/faint/hairline/sapphire) โดยตั้งชื่อไฟล์/
  class ให้เหมือนกันเป๊ะเพื่อลด conflict ตอน merge ภายหลัง — **ห้ามสร้าง token set คู่ขนานที่ชื่อไม่ตรงกัน**
- R2. Identity block: avatar (76px + sapphire-alpha ring), name (17px weight 700) + verified badge ถ้ามี,
  handle (13px graphite), bio (13px, center) — ทั้งหมด centered เป็นหน่วยเดียว
- R3. Stats row: ผู้ติดตาม / กำลังติดตาม / โพสต์ พร้อม divider แนวตั้งระหว่างแต่ละอัน (ตัวเลขต้องมาจาก
  ข้อมูลจริง ไม่ใช่ mock ตามที่ reference ใช้)
- R4. Action row ใหม่ตามข้อ 4 ด้านบน — Bookmark icon ต้องยังลิงก์ไปหน้า Saved/Bookmarks เดิม, PenLine
  icon ต้องยังลิงก์ไปจุดเดิมที่มันเคยลิงก์ (ตรวจโค้ดปัจจุบันว่ามันคือปุ่มอะไร ก่อนย้ายตำแหน่ง)
- R5. Tabs: เหลือ 3 tab (โพสต์/ReDrop/ถูกใจ) พร้อม underline indicator สีเดียว (sapphire, ไม่ใช่ rainbow
  gradient เดิม) — **`DefaultTabController(length: ...)` ต้องเปลี่ยนจาก 5 เป็น 3 และ `TabBarView` ต้องตัด
  `ProfileRepliesTab`/media tab ออกจากมุมมอง own-profile เท่านั้น** (เช็คว่า widget เหล่านี้ยังถูกใช้ที่อื่น
  ไหมก่อนตัดสินใจว่าจะลบไฟล์ widget เองหรือแค่เลิกเรียกใช้)
- R6. Post row: full-width text row (เวลา, เนื้อหาเต็ม, hashtag, action bar 4 อย่างแบบเดียวกับ Home
  WYN-072 — Heart/Comment/Repost/Eye) — **ถ้า WYN-072 (Home) เสร็จก่อนและมี shared post-row/action-bar
  widget ที่ reuse ได้ ให้ reuse แทนเขียนซ้ำ ถ้ายังไม่เสร็จให้เขียนแยกไปก่อนแล้วค่อย refactor รวมทีหลัง**
- R7. Logout: ย้าย `_signOut()` logic เข้า `SettingsScreen` เป็นปุ่ม/แถวใหม่ (ตำแหน่งท้ายสุด แยกด้วย
  visual separation ตามธรรมเนียมเดิมของ 11-settings.tsx ที่ README บอกไว้ — "Logout lives here, at the
  bottom, visually separated") — ต้องมี confirmation dialog ก่อน sign out จริง (ตรวจสอบว่าปัจจุบันมี
  confirm dialog อยู่แล้วหรือไม่ก่อนตัดสินใจเพิ่ม)

Acceptance Criteria:
- [x] Own-profile header เหลือแค่ title + Settings gear icon (ไม่มี logout icon แยกแล้ว)
- [x] Settings screen มีปุ่ม sign-out ที่ทำงานได้จริง (unregister push token + auth.signOut()) พร้อม
      confirmation ก่อนออกจากระบบจริง
- [x] "Club ของฉัน" shelf หายไปจาก own-profile
- [x] Action row ตรงตาม reference (pill กลาง + ไอคอนไม่มีขอบ 2 อัน) และลิงก์ปลายทางเดิมยังถูกต้อง
- [x] Tabs เหลือ 3 อัน (โพสต์/ReDrop/ถูกใจ) ทำงานถูกต้อง ไม่มี Replies/Media tab ค้างในมุมมองนี้
- [x] `flutter analyze` สะอาด (0 issues ในไฟล์ที่แก้ทั้งหมด — ดู Coding Output ด้านล่างสำหรับ 2 รายการ
      `info`-level ที่เหลือใน Home ซึ่งเป็นงานของ WYN-072 agent ที่ทำงานขนานกันอยู่ ไม่เกี่ยวกับ task นี้)
      `flutter test` เต็ม suite ผ่าน (อัปเดต test ที่อ้างอิง 5-tab เดิม, full-width edit button เดิม,
      header logout icon เดิม, และ "Club ของฉัน" section เดิม ให้ตรงกับโครงสร้างใหม่ + เพิ่ม test ใหม่ให้
      SettingsScreen's sign-out row)
- [x] ไม่แตะ branch โปรไฟล์คนอื่น (`!isOwnProfile`) เลย -- แยกเป็น `_buildOtherProfileBody` ของตัวเอง
      ไม่เปลี่ยน output ที่ render ให้ผู้ใช้เห็นเลยแม้แต่จุดเดียว
- [x] `ProfileRecommendationSection` ยังทำงานเหมือนเดิม (ไม่ได้แตะ ตามการตีความด้านบน -- และพบว่าจริงๆ
      แล้วมันไม่เคยแสดงบน own-profile อยู่แล้วตั้งแต่ WYN-071 เพราะ gate ด้วย `if (!isOwnProfile)` ใน
      โค้ดเดิม เห็นจุดนี้ตอน implement จึงยืนยันว่าไม่มี Known Issue อะไรให้บันทึกในหัวข้อนี้)

Dependencies: ใช้ token file ร่วมกับ WYN-072 (Home) — เช็ค `.wyn/tasks/active/WYN-072-wynos-design-
reference-home-feed.md` และ diff ปัจจุบันของ branch ก่อนเริ่ม เพื่อลดโอกาส conflict/สร้างซ้ำ

Priority: สูง — Founder สั่งให้ทำต่อทันที (2026-08-29), ข้ามหน้า 2-4 เพราะมีทีมอื่นทำอยู่แล้ว

Risks:
- `TabBarView`'s children ที่ตัดออก (`ProfileRepliesTab` เป็นต้น) อาจถูก reuse จากที่อื่นในแอป (เช่น ถ้า
  โปรไฟล์คนอื่นก็ใช้ widget เดียวกัน) — ต้องตรวจก่อนลบไฟล์จริง แค่เลิกเรียกจาก own-profile ก็พอถ้าไม่แน่ใจ
- Sign-out ต้องคง behavior เดิมทุกจุด (unregister push token ก่อน signOut) ห้ามลดขั้นตอนตอนย้ายโค้ด

Recommendation: เริ่มจาก R1 (ยืนยัน/ใช้ token ร่วมกับ WYN-072) ก่อนเสมอ แล้วไล่ R2-R7 ตามลำดับ

Handoff: ส่งต่อ AI Coding ทันที — เสร็จแล้วโชว์ผลก่อนเปิด task หน้าถัดไป

## Coding Output (2026-08-29)

Implementation:
- R1: `app/lib/core/design/wynos_home_tokens.dart` — ระหว่าง implement พบว่า WYN-072 (Home) กำลังทำงาน
  ขนานอยู่จริงบน working tree เดียวกัน (ตามที่ risk เดิมเตือนไว้) และสร้างไฟล์นี้ก่อนเสร็จ พร้อม
  `GoogleFonts.inter/fraunces`-based `TextStyle` helpers ครบชุด (`postBody`, `caption()`, `hashtag`,
  `redropAttribution` ฯลฯ) — ใช้ไฟล์เวอร์ชันของ WYN-072 ตรงๆ ทั้งหมด (ไม่สร้างคู่ขนาน), reuse
  `app/lib/core/widgets/wynos_ringed_avatar.dart` ของ WYN-072 สำหรับ avatar ring แทนที่จะเขียนเอง
- R2-R4: `_buildOwnProfileBody` ใหม่ใน `view_profile_screen.dart` — avatar 76px (`WynosRingedAvatar`
  radius 38) + sapphire ring, name 17px/700, handle ใช้ `WynosHomeTokens.caption()` (graphite ตามที่ R2
  ระบุไว้ตรงๆ, ไม่ใช่ `faint` ที่ tsx ใช้จริงๆ กับ handle -- ดู Known Issues), bio ใช้ `bodySmall(color:
  ink)`, action row เป็น pill กลาง (`StadiumBorder`) + ไอคอน Bookmark/PenLine ไม่มีขอบ (onPressed เดิม
  `_openSaved`/`_openDrafts` ไม่เปลี่ยน). ไม่มี verified badge (ไม่มี field นี้ใน `Profile` model เลย --
  ข้ามไปตามที่ R2 บอกว่า "ถ้ามี")
- R3: เพิ่ม `DropRepository.countByAuthor()` (RPC-less, `.count(CountOption.exact)` แบบเดียวกับ
  `ClubRepository.countMembers`) + `postCount` field ใหม่ใน `_ProfileWithCounts` -- query เฉพาะตอน
  `isOwnProfile` เท่านั้น (ไม่กระทบ query count ของ branch คนอื่น)
- R5: `DefaultTabController(length: isOwnProfile ? 3 : 5)`, TabBar ของ own-profile ใช้
  `indicatorColor: sapphire` + `WynosHomeTokens.filterTab()` แยกจาก TabBar เดิมของ other-profile
  (ไม่แตะ)
- R6: สร้างใหม่ 2 ไฟล์ -- `widgets/wynos_post_row.dart` (`WynosPostRow`, display widget) และ
  `widgets/wynos_profile_post_list.dart` (`PostRowData` + `WynosProfilePostListTab`, generic paginated
  list ใช้ร่วม 3 tab). Action bar (Heart/Comment/Repost/Eye) จับ icon size/gap/color ให้ตรงกับ
  `HomeDropCard`'s action bar ที่ WYN-072 เพิ่งทำเสร็จเป๊ะ (17/17/17/16px, sapphire-when-active,
  `WynSpacing.space5` gap, `WynosHomeTokens.caption()` count label) -- ไม่ reuse `HomeDropCard` ตรงๆ
  เพราะ layout ของมัน (avatar+ชื่อ header, image carousel) ไม่ตรงกับ `/05-profile.tsx`'s PostRow (ไม่มี
  author identity ต่อแถว, "text-first" ไม่ใช่ photo-grid) -- ดู Known Issues สำหรับแผน consolidate
- R7: ย้าย `_signOut()` logic ทั้งหมด (unregister push token best-effort + real sign-out) เข้า
  `SettingsScreen` เป็นแถวใหม่ท้ายสุด (`ListTile`, แยกด้วย `Divider` + spacing ตามธรรมเนียม
  `/11-settings.tsx`) พร้อม `AlertDialog` confirm (รูปแบบเดียวกับ `confirmBlock`/`confirmUnblock`
  ใน block_dialogs.dart -- ไม่มี red styling). Sign-out เปลี่ยนจากเรียก
  `Supabase.instance.client.auth.signOut()` ตรงๆ เป็นผ่าน `AuthRepository` (pattern เดียวกับ
  `DeleteAccountScreen`) เพื่อให้ test ได้จริงด้วย `RecordingAuthRepository` โดยไม่แตะ network จริง
- ลบ "Club ของฉัน" shelf ทั้งหมด (`_buildMyClubsSection`, `_myClubsFuture`, `_openClub`,
  imports ของ `club.dart`/`club_page.dart`/`club_mini_card.dart`) -- `clubRepository`/
  `clubPostRepository` fields ยังอยู่ (ยังใช้ส่งต่อให้ `_openSearch`/`_openNotifications`)

Files Changed:
- `app/lib/core/design/wynos_home_tokens.dart` (ของ WYN-072, ไม่ได้แก้เพิ่ม)
- `app/lib/features/profile/presentation/view_profile_screen.dart`
- `app/lib/features/profile/presentation/widgets/wynos_post_row.dart` (ใหม่)
- `app/lib/features/profile/presentation/widgets/wynos_profile_post_list.dart` (ใหม่)
- `app/lib/features/settings/presentation/settings_screen.dart`
- `app/lib/features/drop/data/drop_repository.dart`
- `app/test/view_profile_screen_test.dart`
- `app/test/settings_screen_test.dart`
- `app/test/support/recording_drop_repository.dart`

Reason: ตาม Requirements R1-R7 ด้านบน

Tests:
- อัปเดต `view_profile_screen_test.dart`: full-width edit button test → pill-width test, 5-tab own
  profile test → 3-tab, "Drop tab shows Icons.favorite" (grid tile) → assert caption text +
  `favorite_border`, ReDrops tab tap label "ReDrops" → "ReDrop", ลบ Club group 4 tests → รวมเป็น 1 test
  ยืนยันว่าไม่โชว์อีกต่อไป (ยัง supply ClubRepository จริงเพื่อพิสูจน์ว่าไม่ใช่แค่ list ว่าง)
- เพิ่มใน `settings_screen_test.dart`: กลุ่ม `ออกจากระบบ (WYN-073)` 3 tests (แสดงแถวท้ายสุด+แยกด้วย
  Divider, cancel ไม่ signOut, confirm เรียก signOut จริงผ่าน `RecordingAuthRepository`)
- ผลรัน: `flutter test test/view_profile_screen_test.dart` 13/13 ผ่าน,
  `flutter test test/settings_screen_test.dart` 30/30 ผ่าน, `flutter test` เต็ม suite 790 ผ่าน/10 fail
  (10 fail ทั้งหมดอยู่ใน `hashtag_feed_screen_test.dart`/`home_feed_screen_test.dart` -- งานของ WYN-072
  ที่ commit ไปแล้ว (55ff2b4) ไม่เกี่ยวกับไฟล์ที่ task นี้แก้เลยแม้แต่ไฟล์เดียว, ยืนยันแล้วว่าไม่ใช่
  regression จาก WYN-073)

Build: ไม่ได้รัน `flutter build` จริง (ไม่มี target device/signing ใน sandbox) -- `flutter analyze`
สะอาด (0 issues ในทุกไฟล์ที่ WYN-073 แตะ) ถือเป็นสัญญาณ compile-correctness ที่แรงพอสำหรับขั้นตอนนี้

## Known Issues

1. **Handle color: R2 ระบุ "graphite" ตรงๆ แต่ literal tsx ใช้ `#B7B4AC` (ไม่ตรงกับ 7 token ที่ประกาศไว้ใน
   header comment ของ `05-profile.tsx` เป๊ะ)** -- เลือกทำตาม R2 requirement ที่ระบุชัดเจนกว่า (graphite,
   token ทางการ) แทนค่าที่ต่างเล็กน้อยใน mockup เอง ถือเป็นการตัดสินใจ ไม่ใช่ gap ที่ต้องแก้ แต่บันทึกไว้
   เผื่อ QA เทียบ pixel กับ reference แล้วเจอส่วนต่างเล็กน้อยตรงนี้
2. **Fraunces/Inter ยังไม่ได้ผูกกับหน้า Profile จริง** -- ใช้ `WynosHomeTokens`'s `GoogleFonts.inter(...)`
   ทุกจุดตามที่ WYN-072 วางไว้แล้ว (ปัญหา "font ยังไม่ bundle" ที่เคยกังวลไว้ตอนเริ่ม task นี้ WYN-072
   แก้ให้แล้วด้วย `google_fonts` package) -- ไม่มี gap เหลือในส่วนนี้แล้ว
3. **Consolidate `WynosPostRow`/`WynosProfilePostListTab` กับ `HomeDropCard`** -- ทั้งสองฝั่งตอนนี้มี action
   bar (Heart/Comment/Repost/Eye) ที่ style เหมือนกันทุกประการ (จงใจจับให้ตรงกัน) แต่เป็นโค้ดคนละไฟล์ --
   เสนอให้ทีมถัดไปที่แตะทั้งสองหน้าพร้อมกัน (หรือ dedicated refactor task) ดึง action bar ออกเป็น shared
   widget ตัวเดียว (`HomeDropCard` ยังมี avatar/header/image-carousel ที่ Profile ไม่ต้องการ จึงไม่ใช่แค่
   เปลี่ยน import ตรงๆ ต้องดีไซน์ interface ร่วมกันใหม่)
4. **Poll voting ตอนนี้ใช้งานได้ทั้ง 3 tab ของ own-profile (โพสต์/ReDrop/ถูกใจ)** -- ก่อนหน้านี้เฉพาะ
   ReDrop tab (ผ่าน `HomeDropCard`) เท่านั้นที่ vote ได้แบบ inline, ส่วน Posts/Likes (grid เดิม) ต้องเปิด
   DropDetailScreen ก่อนถึง vote ได้ -- ตอนนี้ทั้ง 3 tab vote ได้ inline เหมือนกันหมดเพราะใช้ widget
   ร่วมกันตัวเดียว (`WynosProfilePostListTab`) ถือเป็นการเพิ่ม capability ไม่ใช่ลด ไม่กระทบ scope อื่น แต่
   บันทึกไว้เผื่อ QA อยากตรวจสอบว่าไม่ใช่ side-effect ที่ไม่ตั้งใจ
5. **ไม่มี verified badge** -- `Profile` model ไม่มี field สำหรับสถานะ verified เลย (R2 บอกไว้แล้วว่า "ถ้ามี"
   เป็นเงื่อนไข) -- ไม่ได้เพิ่ม backend field ใหม่ในรอบนี้ (นอกสโคป), ข้ามไปตามเงื่อนไข ไม่ใช่ gap
6. **`flutter`/`dart` SDK ไม่ได้ติดตั้งไว้ล่วงหน้าใน sandbox นี้** -- ต้องดาวน์โหลด Flutter 3.47.1 เอง
   (ตรงกับ workflow ใน `.github/workflows`) ก่อนรัน `flutter analyze`/`flutter test` ได้จริง บันทึกไว้เผื่อ
   session ถัดไปเจอปัญหาเดียวกัน (ไม่ใช่ gap ของ WYN-073 เอง แต่เป็นข้อสังเกตด้าน environment)
