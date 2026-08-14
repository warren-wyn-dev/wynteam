# Design Spec — WYN-015: Club Discovery & Integration

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok/Facebook โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-015-club-discovery-integration.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `ClubMiniCard`/`ClubPostCard`/`ClubPage`'s `_tabController.animateTo()` (WYN-014), `SearchScreen`'s shared query box + `TabBar` (WYN-009), `NotificationListScreen`'s row (WYN-012), `ViewProfileScreen` (WYN-013), Home's top row + CLUB section (WYN-007/WYN-014)

## ทิศทางภาพรวม: ต่อของเดิมทุกจุด ไม่ประดิษฐ์ pattern ใหม่

WYN-015 ไม่มีหน้าจอไหนที่เป็น "โครงสร้างใหม่ทั้งหมด" — ทุกจุดต่อยอดจาก component/หน้าจอที่มีอยู่แล้วและผ่าน QA แล้วทั้งหมด (`ClubMiniCard`, `ClubPostCard`, `TabBar` เดิมของ Search, แถวเดิมของ Notification, header เดิมของ Profile, top row เดิมของ Home)

---

## Screen 1: `ExploreClubsScreen` (แทนที่ Placeholder ของ WYN-014)

Purpose: ให้ค้นพบ Club ที่ยังไม่ได้เข้าร่วม แบ่งกลุ่ม "กำลังนิยม"/"ใหม่ล่าสุด"

Components:
- AppBar "สำรวจ Club"
- แถว filter chip แนวนอน scroll ได้ ใต้ AppBar: "ทั้งหมด" + 9 category เดิมจาก `CreateClubScreen` (`ChoiceChip`, เลือกได้ทีละอัน, ค่าเริ่มต้น "ทั้งหมด")
- เนื้อหาเป็น `ListView` แนวตั้งเดียว แบ่ง 2 section เรียงจากบนลงล่างเสมอ (ไม่ใช่ tab แยก เพราะทั้งสองกลุ่มควรเห็นพร้อมกันในหน้าเดียวตามที่ Founder's brief ตั้งใจ):
  1. **"กำลังนิยม"** (label หัวข้อ + จำนวน จำกัดแสดง 10 อันดับแรกเรียงตามจำนวนสมาชิกมากไปน้อย ไม่ต้องมี pagination รอบนี้)
  2. **"ใหม่ล่าสุด"** (จำกัด 10 อันดับแรกเรียงตามวันที่สร้างใหม่ไปเก่า)
- **การ์ดในทั้งสอง section ใช้ widget เดียวกัน**: `ClubDiscoveryCard` (ใหม่) — แถวเต็มความกว้าง (ไม่ใช่การ์ดแนวตั้งแคบแบบ `ClubMiniCard` ของ Home เพราะหน้านี้เป็นหน้าเรียกดูเฉพาะทาง มีพื้นที่พอให้แสดงรายละเอียดมากกว่า): icon วงกลม 40px ซ้าย + ชื่อ Club (ตัวหนา) + category chip เล็ก + "· N สมาชิก" ในบรรทัดเดียวกัน + คำอธิบายสั้น 1 บรรทัด (ตัด ellipsis) ถ้ามี — มิเรอร์โครงสร้างแถวของ `FollowListScreen`/`ClubMembersTab` ทุกประการ (avatar/icon ซ้าย + ข้อมูลขวา) เพื่อ reuse ได้ทั้งในหน้านี้และ Screen 2
- Category chip ที่เลือกกรองทั้งสอง section พร้อมกัน (ไม่ใช่กรองแยก)
- Empty state ต่อ section แยกกัน ("ยังไม่มี Club ในหมวดนี้" ถ้ากรองแล้วไม่เจอ)

Interaction: แตะการ์ด → เปิด `ClubPage` เดิมของ WYN-014 ตรงๆ (reuse ทั้งหมด ไม่มีหน้ารายละเอียดแยก)

Accessibility: `ClubDiscoveryCard` ทั้งใบเป็น tap target เดียว (`InkWell` ครอบทั้งแถว) `Semantics` label รวม "ชื่อ Club, หมวดหมู่, จำนวนสมาชิก คน"

---

## Screen 2: Club tab ที่ 4 ใน `SearchScreen`

Components: เพิ่ม `Tab(icon: Icon(Icons.groups_outlined), text: 'Club')` ต่อท้าย User/Drop/Pop เดิม ใช้ query box บนสุดร่วมกันทั้ง 4 tab ทุกประการ (ไม่มีช่องค้นหาแยก) — ผลลัพธ์แสดงเป็น `ListView.builder` ของ `ClubDiscoveryCard` เดียวกับ Screen 1 เป๊ะ (reuse ตรงๆ ไม่ต้องสร้าง card ใหม่) infinite-scroll debounce เดิม 400ms ตาม pattern ของ User/Drop/Pop tab อยู่แล้ว

Empty/loading state: มิเรอร์ `SearchStateMessage` widget เดิมของ WYN-009 ตรงๆ

---

## Screen 3: Notification 4 ประเภทใหม่ (ต่อยอด `NotificationListScreen` เดิม)

ไม่มี UI ใหม่ — ต่อของเดิม (avatar+ข้อความ+เวลา, ไม่มี icon แยกตาม type อยู่แล้วในดีไซน์เดิมของ WYN-012) เพิ่มแค่ข้อความ type-specific ใหม่ 4 แบบ (ต้องมีชื่อ Club ประกอบข้อความด้วย ต่างจาก Like/Comment/Follow เดิมที่ไม่ต้องมีชื่อเนื้อหาประกอบ):
- `club_join_request`: "**{actor}** ขอเข้าร่วม **{club}** ของคุณ"
- `club_join_approved`: "**{actor}** อนุมัติคำขอเข้าร่วม **{club}** ของคุณแล้ว"
- `club_post_like`: "**{actor}** ถูกใจโพสต์ของคุณใน **{club}**"
- `club_post_comment`: "**{actor}** แสดงความคิดเห็นในโพสต์ของคุณใน **{club}**"

(ตัวหนาแค่ในเอกสารนี้เพื่อความชัดเจน ไม่ใช่ rich text จริงในแอป — ข้อความ type-specific เดิมของ WYN-012 ก็เป็น plain `Text` ธรรมดา ทำแบบเดียวกัน)

Interaction (ปลายทางเมื่อแตะ):
- `club_join_request` → เปิด `ClubPage` ของ Club นั้น **เปิดตรงแท็บ Members ทันที** (reuse `_tabController.animateTo(1)` mechanism ที่มีอยู่แล้วใน `ClubPage` สำหรับ More menu's "จัดการสิทธิ์สมาชิก" — เรียกกลไกเดียวกัน ไม่ต้องสร้างใหม่) เพื่อให้ Owner/Admin เห็นคำขอที่รอ Approve/Reject ทันทีไม่ต้องกดอีกที
- `club_join_approved` → เปิด `ClubPage` ของ Club นั้น (แท็บ Posts ปกติ)
- `club_post_like`/`club_post_comment` → เปิด `ClubPostDetailScreen` ของโพสต์นั้น (มิเรอร์ทุกประการกับที่ Like/Comment Drop/Pop เปิด `DropDetailScreen`/`PopSingleClipScreen` — กรณีโพสต์ถูกลบไปแล้วแสดง SnackBar เดียวกับ pattern เดิม "...นี้ถูกลบไปแล้ว")

---

## Screen 4: "Club ของฉัน" section ใน `ViewProfileScreen`

Components: section ใหม่คั่นด้วย label เล็ก "Club ของฉัน" (สไตล์เดียวกับ label "CLUB" ของ Home section) วางใต้ปุ่ม "แก้ไขโปรไฟล์" **เฉพาะตอนดูโปรไฟล์ตัวเอง** ก่อน `TabBar` — แถวแนวนอน scroll ได้ของ `ClubMiniCard` (reuse ตรงๆ จาก WYN-014 ไม่ปรับแก้อะไรเลย) สูงจำกัดเท่า `ClubMiniCard` เดิม (~120px รวม label)

**กติกาที่ต่างจาก CLUB section ของ Home โดยตั้งใจ**: ถ้ายังไม่ได้เข้าร่วม Club ไหนเลย **ไม่ต้องแสดง section นี้เลย** (ไม่มี empty-state message แบบที่ Home มี) เพราะ Profile ไม่ใช่ entry point หลักสำหรับชวนสร้าง/เข้าร่วม Club (Home ทำหน้าที่นั้นอยู่แล้ว) — การโชว์ label เปล่าๆ ไม่มีเนื้อหาข้างใต้จะรกจอโดยไม่จำเป็น

Interaction: แตะการ์ด → เปิด `ClubPage` ของ Club นั้น (เหมือน Home ทุกประการ)

---

## Screen 5: Toggle "สำหรับคุณ" / "จาก Club ของคุณ" บน Home

Components: `SegmentedButton<HomeFeedMode>` (2 ตัวเลือก "สำหรับคุณ" / "จาก Club ของคุณ") วางระหว่าง CLUB section (WYN-014 เดิม อยู่บนสุดเสมอไม่ขึ้นกับ toggle เพราะเป็น entry point จัดการ Club ไม่ใช่เนื้อหา feed) กับ Feed หลัก — ค่าเริ่มต้นเป็น "สำหรับคุณ" เสมอทุกครั้งที่เปิดแอป (ไม่ persist ระหว่าง session รอบนี้ เพื่อความง่าย)

- **"สำหรับคุณ"**: Feed เดิมของ WYN-007 ทุกประการ ไม่เปลี่ยนแปลงอะไรเลย (Drop+Pop เรียงเวลา)
- **"จาก Club ของคุณ"**: list โพสต์ Club จากทุก Club ที่เข้าร่วมแล้ว (`club_role() is not null` ในทุก Club ไม่ใช่ Club เดียว) เรียงเวลาใหม่สุดก่อน ใช้ `ClubPostCard` เดิมของ WYN-014 แสดงผลตรงๆ ทุกประการ (interaction row, More menu ครบ) — ถ้ายังไม่ได้เข้าร่วม Club ไหนเลย แสดงข้อความ "เข้าร่วม Club เพื่อดูโพสต์ที่นี่" (คำเดียวกับ placeholder ของ `ClubPostsTab` ที่ไม่ join แต่ไม่มีปุ่ม Join ในบริบทนี้เพราะยังไม่รู้ว่าจะ join Club ไหน — มีแค่ปุ่ม "สำรวจ Club" ให้ไปหน้า Screen 1 แทน)

Design Rule: `SegmentedButton` ไม่ใช่ `TabBar` เพราะนี่ไม่ใช่การสลับ "หมวดเนื้อหาแยกอิสระ" แบบ Search/Profile แต่เป็นการสลับ "มุมมอง" ของ feed เดียวกัน (ตำแหน่งจึงอยู่เหนือ feed ไม่ใช่โครงสร้าง TabBar+TabBarView ที่กิน vertical space มากกว่า)

---

## Design Rules

- ทุกจุดของ WYN-015 reuse widget เดิม 100%: `ClubMiniCard`, `ClubPostCard`, `SearchStateMessage`, แถวเดิมของ `NotificationListScreen`, กลไก `_tabController.animateTo()` เดิมของ `ClubPage` — จุดใหม่เดียวที่ต้องสร้างจริงคือ `ClubDiscoveryCard` (ใช้ร่วมกันทั้ง Screen 1 และ Screen 2)
- ไม่มีหน้าจอไหนใน WYN-015 เป็น Bottom Nav tab ใหม่ (Explore Clubs เข้าถึงผ่านปุ่มใน CLUB section เดิม, Club search เข้าถึงผ่าน Search เดิม)
- สี/ตัวอักษร/spacing ทั้งหมดตาม `design-principles.md` เดิม ไม่มีทิศทางใหม่

## Handoff: AI Coding —

1. **Database**: เพิ่ม `club_id`/`club_post_id` (nullable) เข้าตาราง `notifications` เดิม, ขยาย `type` CHECK constraint ให้รองรับ 4 ค่าใหม่ (`club_join_request`/`club_join_approved`/`club_post_like`/`club_post_comment`), เขียน trigger function ใหม่ 4 ตัว — **ระวังเป็นพิเศษ**: `club_join_request` ต้อง fan-out insert หลายแถว (หนึ่งแถวต่อ Owner/Admin หนึ่งคนของ Club นั้น) ต่างจาก trigger เดิมทุกตัวของ WYN-012 ที่ insert แถวเดียวเสมอ — self-notification guard ต้องกันไม่ให้ actor เห็น notification ของตัวเอง (เช่น Owner/Admin ที่ approve ไม่ควรได้ notification `club_join_approved` ของตัวเอง — เคสนี้ไม่มีทางเกิดเพราะ recipient คือผู้ขอเสมอ ไม่ใช่ผู้อนุมัติ แต่ยังต้องกัน Owner ถูกนับเป็นคนที่ "ขอเข้าร่วม" club ตัวเอง ซึ่งเป็นไปไม่ได้อยู่แล้วเพราะ Owner membership สร้างจาก trigger ไม่ใช่ insert ปกติ)
2. `ClubPostRepository` ต้องมี `fetchById` ใหม่ (มิเรอร์ `DropRepository.fetchById`/`PopRepository.fetchById` ของ WYN-012 — คืน `null` ถ้าโพสต์ถูกลบ) สำหรับเปิดจาก notification
3. `NotificationRepository`/`WynNotification` ต้องขยายรองรับ 4 type ใหม่ + embed ชื่อ Club (join `clubs`/`club_posts`→`clubs`)
4. Query "จาก Club ของคุณ" (Screen 5) ควร query `club_posts` ข้าม Club ทั้งหมดที่ `club_role() is not null` โดยตรงผ่าน PostgREST (ไม่ต้องสร้าง DB view ใหม่ถ้า RLS เดิมของ `club_posts` รองรับ query แบบไม่ระบุ `club_id` ได้อยู่แล้ว) — **ระวัง**: `ClubPostCard` ต้องรู้ `myRole` ของผู้ใช้ **ต่อ Club ของแต่ละโพสต์** ไม่ใช่ค่าเดียวคงที่แบบตอนอยู่ใน `ClubPage` เดียว (โพสต์แต่ละใบในหน้านี้อาจมาจากคนละ Club ที่ role ต่างกัน) ต้อง fetch/cache role แยกตาม club_id ที่ปรากฏในหน้านี้
5. เขียน regression test ครอบคลุมทุก AC ใน Product spec โดยเฉพาะ fan-out notification (หลาย Admin ต้องได้ notification ครบทุกคน), self-notification guard ของ 4 type ใหม่, "จาก Club ของคุณ" ไม่รั่วโพสต์จาก Club ที่ไม่ได้เข้าร่วม
6. QA & Security ต้องตรวจ RLS ของ `notifications` เดิมยังปิด insert/delete ให้ client เหมือนเดิม (ไม่มี policy ใหม่เปิดช่องจาก column ที่เพิ่ม), regression กับทุก feature เดิมรวม WYN-014

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-5 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-015-club-discovery-integration.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
