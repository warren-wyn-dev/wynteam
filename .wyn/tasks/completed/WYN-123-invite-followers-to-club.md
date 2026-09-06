# Product Task — WYN-123

## Note — Renamed from WYN-115 (2026-09-06, merge time)

ตอนทำงานนี้ทั้งหมด (Product → Design → Coding → QA) ใช้เลข `WYN-115` มาตลอด ระหว่าง merge เข้า `main` ก่อน deploy พบว่ามีอีก session ใช้ `WYN-115` ไปแล้วสำหรับฟีเจอร์คนละเรื่อง (`WYN-115-club-poll`, merge เข้า main ไปแล้วก่อนหน้านี้) — ID collision class เดียวกับที่เจอมาแล้วหลายครั้ง (`WYN-078`, `WYN-114`) เปลี่ยนเป็น `WYN-123` (เลขถัดจากที่ใช้ล่าสุดบน `main` ตอน merge คือ 122) เนื้อหางาน/โค้ด/การตัดสินใจทั้งหมดข้างล่างนี้เหมือนเดิมทุกประการ เปลี่ยนแค่เลข ID

Status: completed -- Deploy สำเร็จขึ้น production 2026-09-06 (merge PR #282, `deploy-web.yml` run #93), Founder ทดลองใช้จริงยืนยัน "เสร็จแล้ว" วันเดียวกัน. หมายเหตุ: กลไกการส่ง invite ที่ทดสอบจริงคือของ **WYN-124** (Notification แทน Chat message) ไม่ใช่กลไกเดิมที่ commit นี้ ship ตอนแรก -- ดู WYN-124 สำหรับรายละเอียดการเปลี่ยนทิศทาง audience/UI ของหน้านี้ (Followers+Following, ปุ่ม "เชิญจากผู้ติดตาม") ยังคงเป็นของ WYN-123 เดิมทั้งหมด
Owner: AI Product Manager
Feature: Invite Followers to Club (pick-from-followers, not just link sharing)
Goal: ให้สมาชิกคลับชวนคนที่ติดตามตัวเองเข้าคลับได้โดยตรงในแอป ไม่ต้องพึ่งการก็อปลิงก์ไปแปะที่อื่นเพียงอย่างเดียว
Target User: สมาชิกที่ approved แล้วของคลับใดก็ตาม (คนเดียวกับที่เห็นปุ่ม "ชวนเพื่อนเข้ากลุ่ม" อยู่แล้วตอนนี้)
Problem: ตอนนี้ปุ่ม "ชวนเพื่อนเข้ากลุ่ม" ใน `club_members_tab.dart` (ผ่าน `onInvite` ใน `club_page.dart:404`) เปิดแค่ `showShareSheet` ทั่วไป (แชร์ลิงก์ผ่านระบบมือถือ / คัดลอกลิงก์ / แชร์เข้า Chat) — ตัวเลือก "แชร์เข้า Chat" ที่มีอยู่แล้ว (`ShareToChatScreen`) ก็ค้นหาได้แค่จาก **conversation ที่เคยคุยด้วยแล้ว** หรือ **ค้นหาชื่อผู้ใช้ทั่วทั้งระบบ** (`ProfileRepository.searchProfiles`) — ไม่มีทางเลือก "ดูรายชื่อคนที่ติดตามฉัน แล้วเลือกชวนตรงๆ" เลย ต้องรู้ชื่อ username หรือเคยคุยกันมาก่อนเท่านั้น
Requirements:
- เพิ่มตัวเลือกในหน้าจอชวนเข้าคลับ: แสดงรายชื่อ**คนที่ติดตามผู้ใช้ปัจจุบัน + คนที่ผู้ใช้ปัจจุบันติดตาม** (รวมสองทิศทาง, dedupe คนซ้ำ — Founder ตัดสินใจ 2026-09-06 หลังเทียบกับ Instagram Group Chat ที่ใช้ pattern เดียวกัน; ดู "Founder Decision" ท้ายไฟล์) — ใช้ `FollowRepository.fetchFollowers()` + `fetchFollowing()` ที่มีอยู่แล้วทั้งคู่ ไม่ต้องเขียน query ใหม่ แต่ต้อง merge/dedupe ฝั่ง client
- เลือกได้ทีละคนหรือหลายคน (Design ตัดสินใจว่าเหมาะกับแบบไหนมากกว่า)
- กดเชิญแล้วเกิดอะไรขึ้น (Design/Coding ตัดสินใจร่วมกับ Founder ตอน spec นี้ถูกหยิบไปทำจริง — ตัวเลือกที่เป็นไปได้โดยใช้ของที่มีอยู่แล้ว ไม่ต้องสร้าง infra ใหม่):
  - (ก) ส่งเป็นข้อความ "แชร์เข้า Chat" อัตโนมัติพร้อมลิงก์คลับ (ต่อยอด `ChatRepository`/`SharedContentType.club` ที่มีอยู่แล้วจาก WYN-033) หรือ
  - (ข) ส่ง Notification ประเภทใหม่ตรงๆ ("X ชวนคุณเข้าคลับ Y") ผ่านระบบ Notification ที่มีอยู่แล้ว
- ~~คนที่ถูกเลือกไม่จำเป็นต้อง follow กลับ (ทิศทางเดียวพอ)~~ **แก้ไข 2026-09-06**: ไม่เกี่ยวแล้วเพราะรวมทั้งสองทิศทาง (follower หรือ following ก็เชิญได้ทั้งคู่)
- ไม่กระทบตัวเลือกเดิม (แชร์ลิงก์ผ่านระบบมือถือ/แชร์เข้า Chat แบบค้นหาทั่วไป/คัดลอกลิงก์) ยังใช้งานได้เหมือนเดิมทั้งหมด เป็นตัวเลือกเสริม ไม่ใช่แทนที่
Acceptance Criteria:
- สมาชิกคลับกด "ชวนเพื่อนเข้ากลุ่ม" แล้วเห็นตัวเลือกดูรายชื่อ follower ของตัวเองได้ โดยไม่ต้องรู้ username ล่วงหน้า
- เลือกคนจาก follower list แล้ว "เชิญ" สำเร็จ คนที่ถูกเชิญได้รับลิงก์/แจ้งเตือนจริง เปิดแล้วเข้าคลับได้ (ขึ้นกับ WYN-114 deep-link fix ใช้งานได้ก่อน ถ้าใช้ช่องทางลิงก์)
- ทดสอบกับคนที่ไม่มี follower เลย (list ว่าง) ต้องไม่ crash แสดงข้อความที่เหมาะสม
Dependencies: **WYN-114 (Share links ไม่เด้งไปหน้าที่ถูกต้อง)** ถ้าช่องทางเชิญจะพึ่งลิงก์ — แนะนำให้ WYN-114 ผ่าน QA ก่อน ไม่งั้นเชิญไปแล้วคนกดลิงก์ก็ยังไม่เจอหน้าคลับอยู่ดี — ใช้ `FollowRepository.fetchFollowers()`/`fetchFollowing()` ที่มีอยู่แล้วทั้งคู่, ต่อยอด `ShareToChatScreen`/`SharedContentType.club` (WYN-033) ที่มีอยู่แล้วถ้าเลือกทาง (ก) ข้างบน
Priority: P2 — เป็นการปรับปรุง UX ของฟีเจอร์ที่มีอยู่แล้ว (invite ทำได้อยู่แล้วผ่านลิงก์) ไม่ใช่ฟีเจอร์ที่ขาดหายไปเลยทั้งหมด
Risks: ไม่มีความเสี่ยงด้าน data/security ใหม่ (`fetchFollowers` เป็น query ที่มีอยู่แล้ว ผ่าน RLS เดิม) — ความเสี่ยงหลักคือ UX เลือกผิดแบบ (list ยาวเกินไปถ้า follower เยอะ ควรมี search/filter ในตัว list ด้วยถ้า Design เห็นว่าจำเป็น)
Recommendation: **ต้องมี mockup ให้ Founder ดูและอนุมัติก่อนเริ่มเขียนโค้ด** ตามกติกาถาวรที่ Founder ตั้งไว้เอง (`.wyn/company/DECISIONS.md`, [2026-09-03] "ขอดูรูปก่อน เขียนโค้ดนะ" — งาน UI ใดๆ ต้องมี Artifact/mockup ก่อนเสมอ ไม่ว่าจะเปลี่ยนเล็กแค่ไหน) — ยังไม่ได้ทำมาก่อนหน้านี้เพราะเรื่องนี้เพิ่งถูกอธิบายเป็นคำพูดในการสนทนา ยังไม่มีภาพประกอบ
Handoff: ส่งต่อ AI Design เพื่อออกแบบหน้าจอ/bottom sheet เลือก follower ก่อน (ต่อยอดจาก `club_members_tab.dart`'s ปุ่มเชิญเดิม) แล้วค่อยส่ง AI Coding พร้อม mockup ที่ Founder อนุมัติแล้ว

## AI Design Output (2026-09-06)

Design spec เต็มอยู่ที่ `.wyn/docs/design/wyn-115-invite-followers-to-club.md` — สรุปการตัดสินใจหลัก:

- **ตอบ Requirement "เลือกทีละคนหรือหลายคน"**: เลือกทีละคน กดแล้วเชิญทันที ไม่มีขั้นตอน confirm แยก — ทำตาม pattern ที่ `ShareToChatScreen` (WYN-033) ใช้อยู่แล้วเป๊ะ (single-tap-to-send) ไม่ต้องคิด interaction ใหม่ ต่างแค่จุดเดียว: หน้าจอนี้**ไม่ปิดตัวเองหลังเชิญสำเร็จ** (แถวเปลี่ยนเป็น "เชิญแล้ว" ค้างไว้แทน) เพราะธรรมชาติของงานคือเชิญหลายคนต่อเนื่องในครั้งเดียวที่เปิดหน้าจอ ไม่ใช่ "แชร์ 1 ชิ้นให้ 1 คน" แบบเดิม
- **ตอบ Requirement "กดเชิญแล้วเกิดอะไรขึ้น"**: เลือกทาง (ก) — ส่งผ่าน "แชร์เข้า Chat" เดิม (`ChatRepository.getOrCreateConversation` + `sendMessage(sharedContentType: club)`) ไม่สร้าง Notification ประเภทใหม่ (ทาง ข) เพราะทาง (ก) ใช้ของที่มีอยู่แล้ว 100% ไม่ต้องแตะ schema/RLS/Edge Function ใดๆ เลย ความเสี่ยงต่ำกว่ามาก
- Entry point: เพิ่มแถวที่ 4 ("เชิญจากผู้ติดตาม") บนสุดของ `showShareSheet` เดิม เฉพาะตอน `sharedContentType == club` เท่านั้น — ปุ่ม "ชวนเพื่อนเข้ากลุ่ม"/ไอคอนแชร์ header เดิมไม่ต้องเปลี่ยนอะไรเลย
- หน้าจอใหม่ `InviteToClubScreen` reuse โครงแถว/ช่องค้นหา/infinite-scroll จาก `FollowListScreen` ทั้งหมด ต่างแค่ trailing widget (ปุ่ม "เชิญ"/"เชิญแล้ว" แทนปุ่ม Follow)
- **ไม่กรองคนที่เป็นสมาชิกคลับอยู่แล้วออกจาก list** ในรอบแรกนี้ (ตั้งใจตัดสโคป — เหตุผลเต็มอยู่ใน design doc "Known Limitation") ไม่ใช่ bug

**รอ Founder อนุมัติ mockup ก่อนส่งต่อ AI Coding** ตามกติกา "ขอดูรูปก่อน เขียนโค้ดนะ" — ยังไม่มีการเขียนโค้ดใดๆ ในรอบนี้

## Founder Decision (2026-09-06)

Founder ถามเทียบกับ Instagram/X ว่าเชิญจากรายชื่อไหน — AI Design ตอบตามที่รู้จริง: Instagram Close Friends ใช้ follower, X Communities ใช้ following, ไม่มีมาตรฐานเดียวกัน **Founder เลือก: รวมทั้งสองทาง (Followers + Following, dedupe คนซ้ำ)** — ตรงกับ pattern ของ Instagram Group Chat "Add People"

ผลต่อ Design/implementation:
- `InviteToClubScreen` ต้องดึงทั้ง `fetchFollowers()` และ `fetchFollowing()` แล้ว merge + dedupe ด้วย profile id ฝั่ง client (ไม่มี RPC รวมสองทางสำเร็จรูปในระบบตอนนี้ ต่างจาก `fetchMutualFollows()` ที่เป็นค่า intersection ไม่ใช่ union)
- Pagination ซับซ้อนขึ้นเล็กน้อย: ต้อง track ว่าแต่ละ list (`followers`/`following`) ยังมีหน้าถัดไปไหมแยกกัน โหลดต่อจากอันที่ยังมีอยู่จนกว่าจะได้แถวใหม่พอ (คน dedupe ซ้ำออกไปแล้วนับไม่ครบ page ก็ต้องโหลดต่อ) — รายละเอียด algorithm ปล่อยให้ AI Coding ตัดสินใจตอน implement จริง ไม่ specify ตายตัวในนี้
- UI/ตัวอย่างใน mockup ไม่เปลี่ยน (แถวหน้าตาเหมือนเดิมไม่ว่าจะมาจาก follower หรือ following) เปลี่ยนแค่แหล่งข้อมูลเบื้องหลัง

## AI Coding Output (2026-09-06)

Implementation:
- `showShareSheet()` (`app/lib/features/chat/presentation/share_sheet.dart`) รับ 2 param ใหม่แบบ optional: `FollowRepository? followRepository`, `String? clubName` — แสดง `ListTile` ใหม่ "เชิญจากผู้ติดตาม" (`Icons.person_add_alt_1`) เป็นแถวบนสุด เฉพาะตอน `sharedContentType == SharedContentType.club && followRepository != null && clubName != null` — เรียกไปที่ `InviteToClubScreen` ใหม่ ตัวเลือกเดิม 3 อัน (แชร์เข้า Chat/แชร์ผ่านระบบมือถือ/คัดลอกลิงก์) ไม่แตะเลย ยังคงทำงานเหมือนเดิมทุกจุด (Drop/Profile ไม่ผ่านเงื่อนไขนี้เลย)
- `club_page.dart` — เพิ่ม field `_followRepository = FollowRepository(Supabase.instance.client)` (pattern เดียวกับ `_chatRepository`/`_profileRepository`/`_reportRepository` ที่มีอยู่แล้วในไฟล์เดียวกัน) ส่งเข้า `showShareSheet` พร้อม `clubName: club.name`
- ไฟล์ใหม่ `app/lib/features/club/presentation/invite_to_club_screen.dart` (`InviteToClubScreen`) — โครงแถว/ช่องค้นหา copy จาก `FollowListScreen` (avatar radius 21 + ring, ชื่อ/@username, search bar pill) ต่างที่:
  - ดึงข้อมูลจาก `FollowRepository.fetchFollowers()` **และ** `fetchFollowing()` พร้อมกัน (`Future.wait`) แล้ว merge + dedupe ด้วย `profile.id` ฝั่ง client (ตาม Founder Decision ข้างบน) — paginate ทั้งสอง source อิสระต่อกัน มี bounded loop (สูงสุด 5 รอบต่อการเรียก 1 ครั้ง) กันกรณี merge แล้วไม่ได้ unique เพิ่มเลยจาก overlap หนัก แล้วปล่อยให้ scroll listener เรียกต่อเองแทนที่จะวน fetch ไม่จำกัด
  - แถวไม่ tappable (ตัดโปรไฟล์ทิ้ง ต่างจาก `FollowListScreen` ตามที่ design spec ระบุ) trailing widget เป็นปุ่ม "เชิญ"/spinner "กำลังส่ง"/"เชิญแล้ว" (3 states อิสระต่อแถว เก็บใน `Map<String, _InviteState>`)
  - กด "เชิญ" → `ChatRepository.getOrCreateConversation()` + `sendMessage(sharedContentType: club, sharedContentId: clubId)` (แพทเทิร์นเดียวกับ `ShareToChatScreen._sendToNewConversation`/`_doSend` เป๊ะ) สำเร็จ → `WynFeedback.toggle()` + ปุ่มเปลี่ยนเป็น "เชิญแล้ว" ค้างไว้ ไม่ auto-close หน้าจอ ล้มเหลว → กลับเป็น "เชิญ" + SnackBar "เชิญไม่สำเร็จ ลองใหม่อีกครั้ง"
  - Empty state: "คุณยังไม่มีผู้ติดตามให้เชิญตอนนี้ — ลองแชร์ลิงก์ผ่านช่องทางอื่นดูก่อนได้" ตรงตาม design spec

Files Changed:
- `app/lib/features/chat/presentation/share_sheet.dart`
- `app/lib/features/club/presentation/club_page.dart`
- `app/lib/features/club/presentation/invite_to_club_screen.dart` (ใหม่)
- `app/test/invite_to_club_screen_test.dart` (ใหม่)
- `app/test/share_sheet_test.dart` (ใหม่)

Reason: ตาม Product spec + Design spec ที่ Founder อนุมัติแล้ว ทั้งหมดข้างบน — ไม่มีการเปลี่ยนแปลงนอกเหนือจาก spec

Tests: เขียนไว้ครบตามที่ design doc's Handoff ระบุ —
- `invite_to_club_screen_test.dart`: แสดงชื่อคลับใน preview, merge+dedupe followers/following, empty state, search filter, ปุ่มเชิญ 3 states ครบ (idle→sending→invited, ยืนยันด้วย `sendMessageGate` ว่าไม่ auto-close หน้าจอ), path ล้มเหลว (revert + SnackBar)
- `share_sheet_test.dart`: แถวใหม่โผล่เฉพาะ club+ครบ param, ไม่โผล่ถ้าขาด param (regression guard), ไม่โผล่เลยสำหรับ drop/profile แม้ส่ง param ไปก็ตาม (กัน WYN-033 regression), กดแล้วเปิด `InviteToClubScreen` จริง

**ยังไม่ได้รันจริง — sandbox session นี้ไม่มี Flutter SDK ติดตั้งเลย (`which flutter`/`which dart` ไม่พบ, หาทั้งเครื่องแล้วไม่เจอ)** ตรวจความถูกต้องด้วยการอ่าน source cross-reference ทุกจุดแทน (โดยเฉพาะจุดที่พบและแก้เอง 1 จุดระหว่างตรวจทาน: parameter `followRepository`/`clubName` เป็น nullable ในฟังก์ชัน แต่ `InviteToClubScreen` ต้องการ non-nullable — type promotion ข้าม closure ของ `onTap` ไม่เกิดขึ้นอัตโนมัติใน Dart ต้องใส่ `!` ตรงจุดใช้งานแทน ไม่งั้น compile ไม่ผ่าน) — **AI QA & Security ต้องรัน `cd app && flutter analyze && flutter test` เต็ม suite ก่อนอนุมัติ deploy เด็ดขาด**

Build: ไม่ได้รัน (ต้องมี Flutter SDK) — ไม่มีการแตะ `pubspec.yaml`/dependency ใดๆ ในงานนี้ ไม่ควรกระทบ build

Known Issues:
- ไม่กรอง follower/following ที่เป็นสมาชิกคลับอยู่แล้วออกจาก list (ตั้งใจ ตามที่ design spec ระบุไว้แล้วว่าเป็น scope decision ไม่ใช่บั๊ก)
- Deep link ที่ส่งไปทาง chat message (ผ่าน `sharedContentType: club`) แสดงผลเป็น shared-content card ใน `ConversationScreen` อยู่แล้ว (ของเดิมจาก WYN-033) การกดเข้าไปดู Club จริงจาก card นั้นไม่เกี่ยวกับ deep-link ผ่าน URL เลย (คนละ code path จาก WYN-114) จึงไม่มี dependency ที่บล็อกการ merge อันนี้จริงๆ กับ WYN-114 อย่างที่ระบุไว้ใน Dependencies เดิม — **แก้ไขความเข้าใจ**: ถ้าเชิญผ่าน "เชิญจากผู้ติดตาม" นี้ ผู้รับเห็น shared-content card ใน chat แล้วกดเข้า Club ได้โดยตรงในแอปเลย ไม่ต้องพึ่ง URL เลย (URL/deep-link เกี่ยวกับ 3 ตัวเลือกเดิม "แชร์ผ่านระบบมือถือ"/"คัดลอกลิงก์" เท่านั้นที่ผลิต URL จริงออกไปนอกแอป) — **หมายเหตุเพิ่ม ณ ตอน merge**: พบว่า `WYN-114` ที่แท้จริง (คนละ session, deploy แล้วก่อนหน้า) แก้แค่โดเมนให้ URL เปิดเว็บได้ ไม่ได้ทำ routing พาไปหน้าที่ถูกต้อง — งาน routing จริง (ที่ Dependencies เดิมข้างบนหมายถึง) ต่อมาถูกจัดเก็บเป็น `WYN-119` (ยัง partial ณ ตอน merge นี้ — ดูรายละเอียดที่ `.wyn/tasks/active/WYN-119-club-deep-linking.md`)
- Regression test ไม่ได้ cover เคส "โหลดหน้าถัดไป" (infinite scroll) แบบ end-to-end เพราะต้องจำลอง scroll ผ่าน viewport จริงซึ่งซับซ้อนเกินสัดส่วนสำหรับ merge-pagination logic ที่ unit-test ได้ยากกว่า UI — ครอบคลุมแค่ merge/dedupe ของหน้าแรกเท่านั้น (เนื้อหาหลักของ requirement นี้) แนะนำ QA ทดสอบ manual/เพิ่ม test ถ้าเห็นว่าจำเป็น

Handoff: ส่งต่อ AI QA & Security — เน้นตรวจ (1) `flutter analyze`/`flutter test` ผ่านจริงทั้ง suite ไม่ใช่แค่ 2 ไฟล์ใหม่ (2) merge/dedupe logic ถูกต้องจริงกับข้อมูลจริง/กึ่งจริง (ไม่ใช่แค่ mock เล็กๆ ใน unit test) (3) 3 ตัวเลือกเดิมของ share sheet (Drop/Profile/Club) ยังทำงานปกติไม่มี regression (4) ปุ่มเชิญกด "ต่อเนื่องหลายคน" ได้จริงในเครื่องจริงไม่มี state รั่วข้ามแถว

## QA & Security Report (2026-09-06)

Feature: WYN-123 — Invite Followers to Club (`showShareSheet`'s new "เชิญจากผู้ติดตาม" option + `InviteToClubScreen`)

Environment: sandbox session ไม่มี Flutter SDK ติดตั้งเลย — **แก้ปัญหาด้วยการ trigger `.github/workflows/ci.yml` จริงผ่าน GitHub Actions API (`workflow_dispatch`) บน branch `claude/consultation-8azkvp`** แทนการรันในเครื่อง เพื่อให้ได้ผลทดสอบจริงจาก Flutter 3.47.1 (เวอร์ชันเดียวกับที่ `deploy-web.yml` ใช้ build production) ไม่ใช่แค่ตรวจโค้ดด้วยสายตา — รันทั้งหมด 3 รอบ:

- **รอบ 1** (commit `49aa65e`): `flutter analyze` FAIL — 2 `unnecessary_non_null_assertion` warnings ที่ `share_sheet.dart:65,68` (จาก `!` ที่ AI Coding ใส่ไว้แบบระแวงเกินจำเป็น) → แก้แล้ว (commit `6f42de0`, พร้อม fix accessibility parity ที่เจอระหว่างตรวจ: ปุ่มเชิญขาด `Semantics(button: true)` เทียบกับ pattern เดิมของ `FollowListScreen`)
- **รอบ 2** (commit `6f42de0`): `flutter analyze` PASS, `flutter test` FAIL — 10 tests ล้มเหลวจริง 2 กลุ่ม:
  1. `share_sheet_test.dart` 5 tests: `!timersPending` — สร้าง `RecordingChatRepository()`/`RecordingProfileRepository()`/`RecordingFollowRepository()` ใหม่ทุกครั้งข้างใน `onPressed` closure ของปุ่มทดสอบ (อยู่ใน FakeAsync zone ของ `testWidgets` เอง) ทำให้ Timer จาก `SupabaseClient`/`GoTrueClient` ที่แต่ละ Recording repo สร้างขึ้นเองรั่วออกมา ตรงกับ bug class เดียวกับ WYN-072's `auth_gate_test.dart` timer leak ที่เคยเจอมาก่อน
  2. `deep_link_service_test.dart` 5 tests: "You must initialize the supabase instance before calling Supabase.instance" — `DeepLinkService._handle()` เรียก `Supabase.instance.client` แบบไม่มีเงื่อนไขก่อนเช็ค path เลย ทำให้ path ที่ไม่ควรต้องพึ่ง Supabase เลย (`/club` ไม่มี id, `/@` เดี่ยวๆ, prefix ที่ไม่รู้จัก, และ `/pop/<id>` ที่แค่โชว์ SnackBar) พังไปด้วย

  ทั้งสองจุดแก้แล้ว (commit `2013715`): ย้าย `Supabase.instance.client` เข้าไปเฉพาะ branch ที่ใช้จริง + ย้ายการสร้าง Recording repo ไปไว้ใน `setUp()` (นอก FakeAsync zone) ตรงกับ pattern ที่ `invite_to_club_screen_test.dart`/`push_notification_service_test.dart` ใช้อยู่แล้วสำเร็จ — จุดที่ 1 เป็นบั๊กจริงในโค้ด production ด้วย (ไม่ใช่แค่ test workaround) เพราะ deep-link ที่ไม่ต้องใช้ network ไม่ควรไปแตะ `Supabase.instance` เลย
- **รอบ 3** (commit `2013715`, run [34041885759](https://github.com/warren-wyn-dev/wynteam/actions/runs/34041885759)): **`flutter analyze` 0 issues, `flutter test` 1259/1259 ผ่านหมด** ✅ — Admin (Next.js) lint/typecheck, Supabase Edge Functions (Deno), `schema.sql` ordering ผ่านทั้งหมดเช่นกัน (ไม่เกี่ยวกับงานนี้แต่ยืนยันว่าไม่มี regression ข้าม package)

Test Cases: 10 (5 ใหม่ใน `invite_to_club_screen_test.dart` + 5 ใหม่ใน `share_sheet_test.dart`) รวมกับ suite เดิม 1249 (รวม `deep_link_service_test.dart` 6 จาก WYN-114 ก่อนหน้า) = 1259 ทั้งหมด

Passed: 1259/1259 (100%)
Failed: 0 (หลังแก้ 2 รอบตามที่บันทึกไว้ข้างบน — ไม่มี test ที่ถูกลบ/ลดความเข้มงวดเพื่อให้ผ่าน)

Severity: N/A (ไม่มี finding ค้าง)

Security Findings:
- ตรวจ authorization ของทางเข้าใหม่ 2 จุด (ปุ่ม "เชิญเพื่อน" ใน Members tab ที่ gate ด้วย `widget.myRole != null`, และไอคอนแชร์ที่ header ซึ่งไม่ gate สมาชิก) — ไม่พบช่องโหว่ยกระดับสิทธิ์ใหม่: การ "เชิญ" เป็นแค่การส่ง shared-content chat card ผ่านกลไก WYN-033 เดิม ไม่ให้สิทธิ์เข้าคลับโดยตรง (ยังต้องผ่าน `joinClub()`/อนุมัติสำหรับ private club เหมือนเดิมทุกประการ) และคนที่ไม่ใช่สมาชิกก็แชร์ลิงก์คลับได้อยู่แล้วผ่าน 3 ตัวเลือกเดิมก่อนหน้านี้ ไม่ใช่ความสามารถใหม่ที่เพิ่มขึ้น
- ไม่มี secret/credential ใดๆ ถูก hardcode ในไฟล์ใหม่ทั้ง 3 ไฟล์
- Merge/dedupe logic (`fetchFollowers`+`fetchFollowing`) ใช้ RLS/query เดิมที่มีอยู่แล้ว ไม่มี query ใหม่ที่ต้องตรวจ RLS เพิ่ม

Recommendation: อนุมัติ deploy ได้ — ไม่มี known issue ที่บล็อก เหลือแค่ scope decision ที่ตั้งใจไว้แล้ว (ไม่กรอง follower ที่เป็นสมาชิกอยู่แล้ว, ไม่มี test ครอบคลุม infinite-scroll แบบ end-to-end) บันทึกไว้ใน design doc แล้วว่าเป็น follow-up ไม่ใช่ blocker

Final Status: **PASS**
