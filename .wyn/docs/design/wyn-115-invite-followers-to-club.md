# Design Spec — WYN-115 (Invite Followers to Club)

> โดย AI Design — 2026-09-06 | ต่อยอด Product spec `.wyn/tasks/backlog/WYN-115-invite-followers-to-club.md`

## บริบท: reuse ของเดิม ไม่สร้าง pattern ใหม่

ตรวจ `.wyn/docs/design/wyn-014-club-core.md` (Design Rules: "เมนู action ทั้งหมดใช้ pattern เดียวกัน") และ `.wyn/docs/design/wyn-033-share-to-chat.md` แล้ว พบว่าทุกชิ้นส่วนที่ต้องใช้**มีอยู่แล้วในระบบ**:

- ปุ่ม "ชวนเพื่อนเข้ากลุ่ม" (`club_members_tab.dart:onInvite`) กับปุ่มแชร์ที่ header (`club_page.dart:619`) เรียก `_openShareSheet()` เดียวกันเป๊ะ (`club_page.dart:214-225`) ซึ่งเปิด `showShareSheet()` — sheet 3 ตัวเลือกที่ WYN-033 สร้างไว้ (แชร์เข้า Chat / แชร์ผ่านระบบมือถือ / คัดลอกลิงก์)
- แถวรายชื่อคนพร้อม avatar+ชื่อ+@username มี pattern สำเร็จรูปอยู่แล้ว 2 แบบ: `FollowListScreen._buildRow` (`AvatarCircle` radius 21 + ring, ใช้กับ Followers/Following ของ Profile) และ `ShareToChatScreen`'s `ListTile` (ใช้กับ "แชร์เข้า Chat")
- ข้อมูล follower/following ของผู้ใช้ปัจจุบันดึงได้จาก `FollowRepository.fetchFollowers()`/`fetchFollowing()` ตรงๆ (มีอยู่แล้วทั้งคู่ ไม่ต้องเขียน query ใหม่ — **Founder ตัดสินใจ 2026-09-06 ให้ใช้ทั้งสองทาง รวมกัน** หลังเทียบกับ Instagram Group Chat ที่ใช้ pattern เดียวกัน ดูรายละเอียดที่ task file's "Founder Decision")
- ช่องทางส่งคำเชิญจริง (ลิงก์คลับ) มีโครงส่งอยู่แล้วทั้งชุดผ่าน `ChatRepository.getOrCreateConversation()` + `sendMessage(sharedContentType: SharedContentType.club, ...)` (WYN-033)

**สรุปทิศทาง**: นี่ไม่ใช่ฟีเจอร์ใหม่ที่ต้องคิด flow ใหม่ทั้งหมด แต่คือการ**เพิ่มตัวเลือกที่ 4** เข้าไปใน sheet เดิม (เฉพาะตอนแชร์ Club เท่านั้น ไม่กระทบ Drop/Profile) ที่เปิดไปหน้าจอใหม่ 1 หน้าซึ่งประกอบจากชิ้นส่วนข้างบนทั้งหมด — ไม่มีการคิดทิศทาง visual ใหม่ตามกติกาบทบาทนี้

---

## Screen 1: `showShareSheet` — เพิ่มตัวเลือกที่ 4 เฉพาะบริบท Club

Purpose: ให้ทางเข้าสู่ "เชิญจากผู้ติดตาม" อยู่จุดเดียวกับที่คนกดอยู่แล้วทุกวันนี้ (ปุ่ม "ชวนเพื่อนเข้ากลุ่ม") แทนที่จะเพิ่มปุ่มใหม่ที่อื่นในหน้าจอ

User Flow: กด "ชวนเพื่อนเข้ากลุ่ม" (หรือไอคอนแชร์ที่ header) → sheet เดิมโผล่ขึ้นมา แต่ตอนนี้มี 4 แถวแทน 3 → กด "เชิญจากผู้ติดตาม" (แถวบนสุด) → ปิด sheet → เปิด Screen 2

Components:
- `showShareSheet()` (`app/lib/features/chat/presentation/share_sheet.dart`) รับ parameter ใหม่ 1 ตัว: `followRepository` (required เฉพาะตอนเรียกจาก Club — ดู Handoff) ใช้ตัดสินว่าจะแสดงแถวใหม่หรือไม่ ร่วมกับเช็ค `sharedContentType == SharedContentType.club`
- แถวใหม่ (บนสุดของ sheet, เหนือ "แชร์เข้า Chat"): `ListTile(leading: Icon(Icons.person_add_alt_1), title: Text('เชิญจากผู้ติดตาม'))` — ไอคอนคนละแบบกับ "แชร์เข้า Chat" (`Icons.chat_bubble_outline`) เพื่อไม่ให้สับสนว่าเป็นตัวเลือกเดียวกัน

Interactions: กดแล้ว `Navigator.of(sheetContext).pop()` ปิด sheet ก่อน (ทำตาม pattern เดิมทุกแถวใน sheet นี้) แล้วค่อย push Screen 2 — ไม่มี haptic ใหม่ตรงนี้ (การเปิด sheet/หน้าจอไม่ใช่ action ที่ต้อง feedback ตาม DS-010 หมวด "สิ่งที่ตั้งใจไม่ใส่ haptic")

States: ไม่มี state พิเศษ — เป็น static list ตาม `sharedContentType`

Responsive Behavior: ไม่เปลี่ยน — sheet เดิมเป็น `showModalBottomSheet` มาตรฐานอยู่แล้ว รองรับทุกความกว้างจอ

Accessibility: แถวใหม่ต้องมี touch target ≥44px แนวตั้ง (มาตรฐาน `ListTile` ของ Material อยู่แล้วที่ 56px ผ่านเกณฑ์)

Design Rules: อยู่บนสุดของ sheet เพราะเป็น action ที่ตรงเจตนาที่สุดของปุ่ม "ชวนเพื่อนเข้ากลุ่ม" (ตัวเลือกอื่นเป็น "แชร์" ทั่วไปที่ยืมมาใช้) — ไม่แสดงเลยถ้า `sharedContentType != SharedContentType.club` (Drop/Profile share sheet หน้าตาเหมือนเดิมทุกประการ ไม่มีแถวนี้)

---

## Screen 2: `InviteToClubScreen` (ใหม่)

Purpose: ให้เลือกคนจาก**รายชื่อคนที่ติดตามตัวเอง + คนที่ตัวเองติดตาม** (รวมสองทาง dedupe คนซ้ำ) แล้วส่งคำเชิญเข้าคลับได้ทีละคนแบบต่อเนื่อง (เชิญหลายคนในครั้งเดียวที่เปิดหน้าจอ ไม่ใช่เชิญคนเดียวแล้วปิดหน้าจอทันที — ต่างจาก `ShareToChatScreen` ที่ pop กลับทันทีหลังส่ง เพราะที่นั่น "แชร์ 1 ชิ้นให้ 1 คน" คือทั้ง flow แต่ที่นี่ "เชิญคนเข้ากลุ่ม" ธรรมชาติของงานคือเชิญได้หลายคนรวดเดียว)

User Flow:
1. เปิดมาเห็นรายชื่อคนที่ติดตามตัวเอง + คนที่ตัวเองติดตาม รวมกัน dedupe คนซ้ำ (เรียง created_at เหมือน `FollowListScreen` เดิม) พร้อมช่องค้นหา
2. เลื่อนหา/ค้นหาคนที่ต้องการ
3. กดปุ่ม "เชิญ" ท้ายแถว → แถวนั้นเปลี่ยนเป็น "เชิญแล้ว" (ปิดใช้งานปุ่มนั้นต่อ ไม่ต้อง reload หน้าทั้งหมด)
4. เชิญกี่คนก็ได้ต่อเนื่องกัน แล้วกดย้อนกลับเองเมื่อพอ (ไม่มี auto-close)

Components:
- Header: `AppBar` เดียวกับ `FollowListScreen` (ปุ่มย้อนกลับ `Icons.chevron_left`, title "เชิญเพื่อนเข้ากลุ่ม", divider เส้นล่าง `WynColors.hairline`) — ใต้ AppBar เพิ่ม 1 บรรทัด preview label สไตล์เดียวกับ `ShareToChatScreen.previewLabel` (`WynSpacing.space4` padding, `Theme.of(context).colorScheme.onSurfaceVariant`): "เชิญเข้า Club {ชื่อ Club}"
- Search bar: **คัดลอก `FollowListScreen._buildSearchBar()` ทั้งหมด** (pill ทรงแคปซูล `WynColors.surfaceTint` + border `WynColors.hairline`, ไอคอนแว่นขยาย 14px `WynColors.mutedNeutral`, hint "ค้นหา") — กรองเฉพาะ list ที่โหลดมาแล้วในเครื่อง (client-side filter) เหมือนต้นแบบเป๊ะ ไม่ยิง query ใหม่ทุกครั้งที่พิมพ์
- แถวรายชื่อ: **คัดลอกโครง `FollowListScreen._buildRow` ทั้งหมด** — `AvatarCircle(radius: 21, ring: true)` + Column(ชื่อ 15px w600 `WynColors.ink`, "@username" 13px `WynColors.mutedNeutral`) — ต่างจากต้นแบบแค่ trailing widget (ดู Interactions/States ด้านล่าง) แทนที่ `FollowActionButton`
- Trailing button ("เชิญ" / "เชิญแล้ว"): ปุ่มทรงเดียวกับ `OutlinedButton` ที่ `FollowListScreen`'s ปุ่ม "ลบ" ใช้อยู่แล้ว (ไม่ใช่ปุ่มเต็ม sapphire แบบ "ติดตาม" — เพราะการเชิญเป็น action รองที่ทำซ้ำได้หลายครั้งในหน้าเดียว ไม่ใช่ primary CTA เดี่ยวของหน้าจอ)
- Empty state: ไอคอน + ข้อความ style เดียวกับ `FollowListScreen`'s empty state ("ยังไม่มีใครติดตามคุณเลย") — ข้อความใหม่: **"คุณยังไม่มีผู้ติดตามให้เชิญตอนนี้ — ลองแชร์ลิงก์ผ่านช่องทางอื่นดูก่อนได้"** (ชี้กลับไปยัง 2 ตัวเลือกเดิมใน sheet แทนที่จะเป็นทางตัน)
- Infinite scroll + pull-to-refresh: เหมือน `FollowListScreen` เป๊ะ (`ScrollController` + `FollowRepository.pageSize` เป็นเกณฑ์ `hasMore`, `RefreshIndicator`)

Interactions:
- แตะทั้งแถว (ไม่ใช่แค่ปุ่ม) **ไม่เปิดโปรไฟล์** ต่างจาก `FollowListScreen` โดยตั้งใจ — หน้าจอนี้มีจุดประสงค์เดียวคือเชิญ การกดพลาดแล้วหลุดไปหน้าโปรไฟล์คนอื่นจะขัด flow "เชิญต่อเนื่องหลายคน" ปุ่ม "เชิญ" เท่านั้นที่ tap ได้ (ส่วนที่เหลือของแถวไม่มี `InkWell`)
- กด "เชิญ": disable ปุ่มทันที (ป้องกันกดซ้ำ) → เรียก `ChatRepository.getOrCreateConversation(profile.id)` แล้ว `sendMessage(sharedContentType: club, sharedContentId: clubId)` (โครงเดียวกับ `ShareToChatScreen._sendToNewConversation`/`_doSend`) → สำเร็จ: เปลี่ยนปุ่มเป็น "เชิญแล้ว" ค้างไว้ (ไม่ revert), haptic `WynFeedback.toggle()` (กลุ่ม "light" ตาม DS-010 — น้ำหนักเดียวกับ Follow/Save ไม่ใช่ระดับ "success" ของการโพสต์สำเร็จ) → ล้มเหลว: ปุ่มกลับเป็น "เชิญ" เหมือนเดิม + `SnackBar('เชิญไม่สำเร็จ ลองใหม่อีกครั้ง')` (ข้อความเดียวกับ pattern error ทั่วทั้งแอป)
- Pull-to-refresh: reload รายชื่อใหม่ทั้งหมด (สถานะ "เชิญแล้ว" ที่ตั้งไว้ก่อนหน้าจะหายไป กลับเป็น "เชิญ" ปกติ — เป็น trade-off ที่ยอมรับได้เพราะ state นี้เป็น session-only ไม่ persist ไว้ที่ไหน ดู Known Limitation)

States: ต่อแถว มี 3 สถานะอิสระต่อกัน (ไม่ผูกกับสถานะแถวอื่น):
1. ปกติ — ปุ่ม `OutlinedButton` label "เชิญ" กดได้
2. กำลังส่ง — ปุ่มแสดง `CircularProgressIndicator(strokeWidth: 2)` ขนาด 16×16 แทน label (เหมือน pattern `_removingIds` ของ `FollowListScreen`)
3. เชิญแล้ว — ปุ่ม disabled, label "เชิญแล้ว" + `Icons.check` 14px นำหน้า, สี `WynColors.mutedNeutral` (บอกว่าไม่ใช่ CTA ที่ยังกดได้แล้ว)

Responsive Behavior: Mobile-first เหมือนทั้งระบบ (`.wyn/docs/design/ds-008-responsive-accessibility.md` §3 — ไม่มี breakpoint พิเศษสำหรับ tablet/desktop จนกว่า Founder จะสั่งเพิ่ม) รายการเป็น `ListView.builder` เต็มความกว้างจอ ปรับตามความกว้างอัตโนมัติอยู่แล้วเหมือน `FollowListScreen`

Accessibility:
- ปุ่ม "เชิญ"/"เชิญแล้ว" ห่อด้วย `SizedBox(height: WynSpacing.touchTargetMin)` เท่ากับปุ่ม "ลบ" ต้นแบบ (44px ผ่านเกณฑ์ WCAG 2.5.5 ตาม DS-008 §1)
- `Semantics` ต่อแถว: `'ผู้ใช้ ${nameOrUsername} ยูสเซอร์เนม ${username}'` (ไม่มี "กดเพื่อดูโปรไฟล์" ต่อท้ายเหมือนต้นแบบ เพราะแถวนี้กดไม่ได้แล้วตามการตัดสินใจข้างบน) + ปุ่มเชิญมี label แยก `'เชิญ ${nameOrUsername} เข้ากลุ่ม'` / `'เชิญ ${nameOrUsername} แล้ว'` ตามสถานะ

Design Rules:
- ห้ามเพิ่มสีใหม่ — ปุ่ม "เชิญ"/"เชิญแล้ว" ใช้โทน `OutlinedButton` มาตรฐานของระบบ (border `WynColors.hairline`/ข้อความ `WynColors.ink` ปกติ, label "เชิญแล้ว" ใช้ `WynColors.mutedNeutral` แทนสีสถานะเขียว/เทาแบบอื่น — ตรงกับกติกา DS-005 เรื่อง role badge "ไม่ใช้สีสถานะแยก" แม้เป็นบริบทคนละงาน แต่หลักการเดียวกัน)
- ไม่กรอง follower ที่เป็นสมาชิกคลับอยู่แล้วออกจาก list ใน v1 (ดู Known Limitation) — ไม่ใช่บั๊ก เป็นการตัดสินใจลดสโคปที่ตั้งใจ

## Known Limitation (ตั้งใจเว้นไว้ ไม่ใช่ตกหล่น)

1. **ไม่กรองคนที่เป็นสมาชิกคลับอยู่แล้ว**: `FollowRepository.fetchFollowers()` ไม่รู้ว่าใครเป็นสมาชิกคลับนี้อยู่แล้วบ้าง การจะกรองออกต้อง cross-reference กับ `ClubRepository.fetchApprovedMembers()`/`fetchPendingMembers()` ซึ่งเป็น paginated query แยก (ต้องดึงทุกหน้าเพื่อรวบ id set มาเทียบ) — เพิ่ม round-trip และความซับซ้อนเกินสัดส่วนของ P2 improvement นี้ ผลกระทบจริงถ้าไม่กรอง: กด "เชิญ" คนที่เป็นสมาชิกอยู่แล้ว → เขาได้ข้อความ Chat มีลิงก์คลับที่เข้าได้อยู่แล้วเฉยๆ (ไม่ error ไม่มีผลเสียเชิงข้อมูล/สิทธิ์ ใครก็ตามที่เป็นสมาชิกอยู่แล้วเปิดลิงก์ก็แค่เห็นคลับปกติ) เป็นแค่ความรำคาญเล็กน้อย ไม่ใช่บั๊ก — เก็บเป็น follow-up ถ้า Founder เห็นว่าคุ้มทำภายหลัง
2. **"เชิญแล้ว" เป็น session-only**: ไม่บันทึกลง DB ว่าเชิญใครไปแล้วบ้าง ถ้าออกจากหน้าจอนี้แล้วกลับเข้ามาใหม่ ทุกแถวเป็น "เชิญ" ปกติหมด (เชิญซ้ำได้ไม่จำกัด — เหมือนพฤติกรรมเดิมของปุ่ม "แชร์เข้า Chat"/"แชร์ผ่านระบบมือถือ" ที่ส่งซ้ำได้ไม่จำกัดอยู่แล้วเช่นกัน ไม่ใช่พฤติกรรมใหม่ที่ต่างจากของเดิม)
3. **Deep-link ต้องพึ่ง WYN-114**: ลิงก์ที่ส่งไปคือ `clubShareLink()` เดิม ถ้า WYN-114 (deep-link fix) ยังไม่ผ่าน QA/deploy คนที่ถูกเชิญกดลิงก์แล้วจะยังไม่เจอหน้าคลับ (ดู Dependency ใน Product spec)

## Handoff

ส่งต่อ AI Coding:
1. `app/lib/features/chat/presentation/share_sheet.dart` — เพิ่ม parameter `FollowRepository? followRepository` ให้ `showShareSheet()`, เพิ่ม `ListTile` ใหม่ (เงื่อนไข `sharedContentType == SharedContentType.club && followRepository != null`) วางไว้แถวบนสุด
2. `app/lib/features/club/presentation/club_page.dart:214-225` (`_openShareSheet`) — ส่ง `followRepository: widget.followRepository` (มี field นี้อยู่แล้วในคลาสนี้หรือไม่ต้องเช็ค ถ้าไม่มีให้เพิ่มแบบ optional-defaulted ตาม pattern เดิมทั้งไฟล์)
3. ไฟล์ใหม่ `app/lib/features/club/presentation/invite_to_club_screen.dart` (`InviteToClubScreen`) — โครงตาม Screen 2 ข้างบนทั้งหมด รับ `followRepository`, `chatRepository`, `clubId`, `clubName` เป็น required param — ต้องดึงทั้ง `fetchFollowers()` และ `fetchFollowing()` แล้ว merge + dedupe ด้วย profile id ฝั่ง client (ไม่มี RPC รวมสองทางสำเร็จรูป ต่างจาก `fetchMutualFollows()` ที่เป็น intersection ไม่ใช่ union) — วิธี paginate ทั้งสอง source พร้อมกันปล่อยให้ AI Coding ตัดสินใจตอน implement จริง (Design ไม่ specify algorithm ตายตัว)
4. Regression test: cover 3 states ของปุ่มเชิญ (ปกติ → กำลังส่ง → เชิญแล้ว), empty state, search filter, และ sheet ใหม่ที่**ไม่โผล่**ตอนแชร์ Drop/Profile (กัน regression ของ WYN-033 เดิม)
5. ต้องผ่าน AI QA & Security ก่อน merge/deploy ตามปกติ (ห้ามข้าม QA)
