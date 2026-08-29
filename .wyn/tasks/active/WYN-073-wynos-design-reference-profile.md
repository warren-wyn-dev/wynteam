# Product Task — WYN-073

Status: active — ส่งต่อ AI Coding
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
- [ ] Own-profile header เหลือแค่ title + Settings gear icon (ไม่มี logout icon แยกแล้ว)
- [ ] Settings screen มีปุ่ม sign-out ที่ทำงานได้จริง (unregister push token + auth.signOut()) พร้อม
      confirmation ก่อนออกจากระบบจริง
- [ ] "Club ของฉัน" shelf หายไปจาก own-profile
- [ ] Action row ตรงตาม reference (pill กลาง + ไอคอนไม่มีขอบ 2 อัน) และลิงก์ปลายทางเดิมยังถูกต้อง
- [ ] Tabs เหลือ 3 อัน (โพสต์/ReDrop/ถูกใจ) ทำงานถูกต้อง ไม่มี Replies/Media tab ค้างในมุมมองนี้
- [ ] `flutter analyze` สะอาด, `flutter test` เต็ม suite ผ่าน (อัปเดต test ที่อ้างอิง 5-tab เดิมหรือ header
      logout icon เดิมให้ตรงกับโครงสร้างใหม่)
- [ ] ไม่แตะ branch โปรไฟล์คนอื่น (`!isOwnProfile`) เลย
- [ ] `ProfileRecommendationSection` ยังทำงานเหมือนเดิม (ไม่ได้แตะ ตามการตีความด้านบน)

Dependencies: ใช้ token file ร่วมกับ WYN-072 (Home) — เช็ค `.wyn/tasks/active/WYN-072-wynos-design-
reference-home-feed.md` และ diff ปัจจุบันของ branch ก่อนเริ่ม เพื่อลดโอกาส conflict/สร้างซ้ำ

Priority: สูง — Founder สั่งให้ทำต่อทันที (2026-08-29), ข้ามหน้า 2-4 เพราะมีทีมอื่นทำอยู่แล้ว

Risks:
- `TabBarView`'s children ที่ตัดออก (`ProfileRepliesTab` เป็นต้น) อาจถูก reuse จากที่อื่นในแอป (เช่น ถ้า
  โปรไฟล์คนอื่นก็ใช้ widget เดียวกัน) — ต้องตรวจก่อนลบไฟล์จริง แค่เลิกเรียกจาก own-profile ก็พอถ้าไม่แน่ใจ
- Sign-out ต้องคง behavior เดิมทุกจุด (unregister push token ก่อน signOut) ห้ามลดขั้นตอนตอนย้ายโค้ด

Recommendation: เริ่มจาก R1 (ยืนยัน/ใช้ token ร่วมกับ WYN-072) ก่อนเสมอ แล้วไล่ R2-R7 ตามลำดับ

Handoff: ส่งต่อ AI Coding ทันที — เสร็จแล้วโชว์ผลก่อนเปิด task หน้าถัดไป
