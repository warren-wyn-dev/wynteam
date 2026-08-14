# Design Spec — WYN-014: Club — Core System

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok/Facebook โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-014-club-core.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: แถวของ `FollowListScreen` (WYN-008/013), `TabBar` icon+label ของ `ViewProfileScreen` (WYN-013), ไอคอนกระดิ่ง+badge (WYN-012), `DropDetailScreen`'s comment list + interaction row (WYN-005), `AvatarCircle`, ฟอร์มอัปโหลดรูปของ Create Drop/Edit Profile

## ทิศทางภาพรวม: Club เป็น "พื้นที่" ที่มีโครงสร้างเดียวกับ Profile — Header สองส่วน + Tab เนื้อหา

`ClubPage` ใช้โครงสร้างเดียวกับ `ViewProfileScreen` (WYN-013) ในระดับแนวคิด: header คงที่ด้านบน (รูป+ข้อมูล+ปุ่มหลัก) ตามด้วย `TabBar` สลับเนื้อหา — ต่างจาก Facebook Groups ตรงที่ **ไม่มี cover ที่ทับ header แบบเต็มจอ ไม่มี pinned-post banner เต็มความกว้างแบบ FB** cover เป็นแค่แถบสี่เหลี่ยมมุมมนสูงพอประมาณ (เหมือนพื้นหลังการ์ด ไม่ใช่ hero image เต็มจอ) — Icon ของ Club วางซ้อนมุมล่างซ้ายของ cover แบบ circle avatar (คล้าย pattern avatar-ทับ-cover ที่ social app ทั่วไปใช้ แต่ทำให้เล็กกว่าและเรียบง่ายกว่า FB)

---

## Screen 1: ส่วน CLUB ใน Home

Purpose: entry point เข้า Club ที่เข้าร่วมแล้ว + ปุ่มลัดสร้าง/สำรวจ โดยไม่แย่งพื้นที่ Feed หลัก

Components:
- วางเป็น section สูงจำกัด (ไม่เกิน ~180px) ใต้แถวบนสุด (search bar + กระดิ่ง จาก WYN-012) เหนือ Feed
- แถวหัวข้อ: `Text('CLUB')` (ตัวหนา) + ปุ่ม text เล็ก "ดูทั้งหมด" ชิดขวา (สำรอง entry point ไปหน้า "Club ของฉัน" เต็มรูปแบบ — Screen 2)
- แถวปุ่มลัดแนวนอน scroll ได้ 2 ปุ่ม: **"+ สร้าง Club"** (`OutlinedButton.icon`, `Icons.add`) และ **"สำรวจ Club"** (`OutlinedButton.icon`, `Icons.explore_outlined` — ปุ่มนี้เปิด placeholder screen แบบเดียวกับที่ Search เคยเป็นใน WYN-007 ก่อน WYN-009 จะทำจริง เพราะ Discovery เต็มรูปแบบอยู่ใน WYN-015 ไม่ใช่รอบนี้)
- แถว card แนวนอน scroll ได้ (`ListView` horizontal) ของ Club ที่เข้าร่วมแล้ว (`ClubMiniCard`): icon วงกลม 48px + ชื่อ Club (1 บรรทัด, ellipsis) + จำนวนสมาชิก ตัวเล็ก — กว้างคงที่ ~100px ต่อใบ
- **ถ้ายังไม่เข้าร่วม Club ไหนเลย**: แถว card แทนที่ด้วยข้อความเดียว "ยังไม่ได้เข้าร่วม Club ไหนเลย ลองสร้างหรือค้นหาดูสิ" (ไม่ใช่พื้นที่ว่างเปล่า)

Interaction: แตะ card → เปิด `ClubPage` (Screen 3) ของ Club นั้น, แตะ "+ สร้าง Club" → `CreateClubScreen` (Screen 2), แตะ "สำรวจ Club"/"ดูทั้งหมด" → placeholder (รอ WYN-015)

---

## Screen 2: `CreateClubScreen`

Purpose: ฟอร์มสร้าง Club ใหม่

Components: **reuse โครงสร้างฟอร์มเดียวกับ Edit Profile (WYN-003)** — `TextField` สำหรับ Name (จำกัดความยาว), `TextField` multiline สำหรับ Description, ตัวเลือกรูป Cover (แตะเปิด image picker, แสดง preview 16:9 มุมมน) และ Icon (แตะเปิด image picker, แสดง preview วงกลม — **reuse `AvatarCircle`-style picker เดียวกับ avatar upload ของ Edit Profile ทุกประการ**), `DropdownButtonFormField` สำหรับ Category (ตัวเลือกคงที่ตาม Product: All ไม่แสดงตอนสร้าง เพราะต้องเลือกจริง / Technology / Gaming / Education / Lifestyle / Food / Sports / Entertainment / Business / Marketplace), `SegmentedButton`หรือ `RadioListTile` 2 ตัวเลือกสำหรับ Privacy (Public/Private) พร้อมคำอธิบายสั้นใต้แต่ละตัวเลือก ("ทุกคนค้นหาและเข้าร่วมได้ทันที" / "ต้องส่งคำขอ ผู้ดูแลต้องอนุมัติก่อน")

ปุ่ม "สร้าง Club" ด้านล่าง (เต็มความกว้าง, disabled จนกว่าจะกรอกครบ Name+Privacy อย่างน้อย — Cover/Icon/Description/Category เป็น optional เหมือน bio ของ Profile)

Interaction: สร้างสำเร็จ → เปิด `ClubPage` ของ Club ที่เพิ่งสร้างทันที (ผู้สร้างเป็น Owner อัตโนมัติ)

---

## Screen 3: `ClubPage` — Header

Purpose: ข้อมูล Club + ปุ่มหลัก

Components:
- Cover: `AspectRatio` 16:9 มุมมน (ไม่ใช่เต็มความกว้างจอทะลุขอบแบบ FB) วางในการ์ดเหมือน card อื่นๆ ของแอป
- Icon Club วางซ้อนมุมล่างซ้ายของ Cover (circle, border ขาวรอบขอบกันกลืนกับพื้นหลัง Cover)
- ชื่อ Club (`headlineSmall`), Category chip เล็กข้างชื่อ, Description (2-3 บรรทัดแรก + "ดูเพิ่มเติม" ถ้ายาวเกิน)
- จำนวนสมาชิก (ข้อความธรรมดา ไม่ใช่ tap target แบบ Follower count ของ Profile เพราะแตะแล้วจะไปหน้า Members อยู่แล้วผ่าน TabBar ด้านล่าง ไม่ต้องมี 2 ทางไปที่เดียวกัน)
- แถวปุ่ม: **Join/Joined/รออนุมัติ** (ปุ่มหลัก, `OutlinedButton`) + **Share** (`IconButton`, mirror `dropShareLink`/`popShareLink` pattern — สร้าง `clubShareLink`) + **More** (`IconButton`, `Icons.more_vert` — เปิดเมนู)
  - **สถานะปุ่ม Join 3 แบบ**: ยังไม่เข้าร่วม → "เข้าร่วม" (Primary Blue outline, เหมือนปุ่ม Follow); เข้าร่วมแล้ว → "เข้าร่วมแล้ว" (สี `outline`, กดแล้วเปิด dialog ยืนยัน "ออกจาก Club?"); ส่งคำขอแล้วรออนุมัติ (Private เท่านั้น) → "รออนุมัติ" (disabled, สี `outline`, ไม่ต้องกดอะไรได้ — กดยกเลิกคำขอทำผ่านเมนู More แทนเพื่อไม่ให้ปุ่มหลักมี 2 ความหมายซ้อนกัน)
- เมนู More: ถ้าเป็น Owner/Admin → มีตัวเลือก "แก้ไขข้อมูล Club", "เปลี่ยนความเป็นส่วนตัว" (Public↔Private), "จัดการสิทธิ์สมาชิก" (ลิงก์ไปหน้า Members) — ถ้าเป็นสมาชิกทั่วไปที่เข้าร่วมแล้ว → มีแค่ "ออกจาก Club", "รายงาน Club" (ปุ่มเฉยๆ ไม่ต้องมี backend จริงรอบนี้ เก็บไว้เป็น placeholder เหมือนที่ปุ่ม "More" ของโพสต์อื่นในแอปเคยทำ) — ถ้ายังไม่เข้าร่วมเลย → มีแค่ "รายงาน Club"

Accessibility: ปุ่ม Join ใช้ `Semantics` label ตามสถานะจริง ("กดเพื่อเข้าร่วม" / "เข้าร่วมแล้ว กดเพื่อออกจาก Club" / "ส่งคำขอเข้าร่วมแล้ว รอการอนุมัติ")

---

## Screen 4: `ClubPage` — TabBar (Posts / Members / About)

Components: `TabBar` icon+label 3 แท็บใต้ header — "โพสต์" (`Icons.grid_view_outlined`... ไม่ใช่ grid เพราะโพสต์ Club เป็น list ไม่ใช่ grid ใช้ `Icons.article_outlined` แทน), "สมาชิก" (`Icons.people_outline`), "เกี่ยวกับ" (`Icons.info_outline`)

**คนที่ยังไม่เข้าร่วม**: แท็บ "โพสต์" ยังคงแสดงอยู่ (ไม่ซ่อนแบบ conditional length เหมือน Saved tab ของ WYN-013 เพราะทุกคนควรรู้ว่า Club นี้มีแท็บโพสต์อยู่) แต่เนื้อหาข้างในแทนที่ด้วยข้อความ "เข้าร่วม Club เพื่อดูโพสต์" + ปุ่ม Join ซ้ำ (ไม่ใช่ list ว่างเปล่าเฉยๆ) — แท็บ "สมาชิก"/"เกี่ยวกับ" ดูได้ปกติไม่ต้องเข้าร่วม (จำนวนสมาชิก/กฎ Club เป็นข้อมูลสาธารณะที่ช่วยให้คนตัดสินใจเข้าร่วม)

---

## Screen 5: Posts tab — การ์ดโพสต์ + Create Post

Components: **infinite-scroll list มิเรอร์โครงสร้าง comment list ของ `DropDetailScreen`** (ไม่ใช่ grid) — โพสต์ที่ปักหมุดเรียงบนสุดเสมอ คั่นด้วย label เล็ก "ปักหมุด" (ไอคอน `Icons.push_pin`, สี `outline`) ก่อนรายการโพสต์ปกติที่เหลือ

การ์ดโพสต์ (`ClubPostCard`): avatar+ชื่อผู้โพสต์ (ไม่ต้องมี tap-to-profile รอบนี้ — เชื่อมกับ WYN-013's `ViewProfileScreen` เป็น nice-to-have ไว้ทีหลังได้ ไม่ critical สำหรับ core) + เวลา (`relativeTimeLabel`, reuse จาก WYN-012) + เนื้อหา (Text เสมอถ้ามี, รูปเดี่ยวเป็น `AspectRatio` 1:1 เหมือน Drop, หลายรูปเป็น horizontal `PageView`/carousel พร้อมจุดบอกตำแหน่ง, Link เป็นการ์ดย่อยแสดง URL ตัวหนังสือธรรมดา — ไม่ทำ link preview/opengraph fetch รอบนี้เพื่อไม่ over-engineer) + แถวปฏิสัมพันธ์ Like/Comment/Share/Bookmark เหมือนกับ Drop/Pop ทุกประการ (icon+count, `Semantics` label เดียวกัน) + ปุ่ม More (`Icons.more_vert`) มุมขวาบนของการ์ด

เมนู More ของโพสต์:
- เจ้าของโพสต์เอง → "ลบโพสต์"
- Owner/Admin/Moderator (ไม่ใช่เจ้าของโพสต์) → "ลบโพสต์", "ปักหมุด"/"เลิกปักหมุด" (toggle ตามสถานะปัจจุบัน)
- คนอื่นที่ไม่มีสิทธิ์ → เมนูว่างหรือไม่แสดงปุ่ม More เลย

ปุ่ม "+ สร้างโพสต์" ลอยมุมขวาล่างของแท็บ Posts (`FloatingActionButton`, เฉพาะสมาชิกที่ approved แล้วเท่านั้นถึงจะเห็น) → เปิด `CreateClubPostScreen`

### `CreateClubPostScreen`
Components: ถ้าเปิดจากใน Club → header แสดง "โพสต์ใน [ชื่อ Club]" ล็อกไว้ ไม่มีตัวเลือกอื่น (ตามที่ Product กำหนด) — ช่อง Text (multiline), ปุ่มแนบรูป (เลือกได้หลายรูป, แสดง thumbnail แถวแนวนอนพร้อมปุ่มลบทีละรูป), ช่อง Link (URL, optional, validate รูปแบบเบื้องต้น) ปุ่ม "โพสต์" (เต็มความกว้าง, disabled ถ้าไม่มีทั้ง Text/รูป/Link เลยสักอย่าง — ต้องมีอย่างน้อย 1 อย่าง)

---

## Screen 6: Members tab

Components: **reuse โครงสร้างแถวของ `FollowListScreen` ทุกประการ** (avatar+ชื่อ+@username) เพิ่ม **role badge** เล็กท้ายแถว (chip สีต่างกันตาม role: Owner สี Primary Blue เข้ม, Admin สี Primary Blue อ่อน, Moderator สี `outline`, Member ไม่มี badge เพื่อไม่ให้รกเกินไปเมื่อสมาชิกส่วนใหญ่เป็น Member ธรรมดา)

**สมาชิกที่รออนุมัติ (Private club)**: แสดงเป็น section แยกด้านบนสุด "คำขอเข้าร่วม (N)" **เฉพาะ Owner/Admin เห็นเท่านั้น** แต่ละแถวมีปุ่ม "อนุมัติ"/"ปฏิเสธ" ข้างๆ แทนที่ role badge

เมนู More ต่อแถว (เฉพาะที่ Owner/Admin/Moderator เห็นตามสิทธิ์):
- Owner เห็นในทุกแถว (ยกเว้นแถวตัวเอง): "แต่งตั้งเป็น Admin", "แต่งตั้งเป็น Moderator" (หรือ "ถอดจากตำแหน่ง" ถ้ามี role อยู่แล้ว), "ลบออกจาก Club", "แบน"
- Admin เห็นในแถว Moderator/Member เท่านั้น (ไม่เห็นในแถว Owner/Admin คนอื่น): "แต่งตั้งเป็น Moderator"/"ถอดจากตำแหน่ง", "ลบออกจาก Club", "แบน"
- Moderator เห็นในแถว Member เท่านั้น: "ลบออกจาก Club", "แบน" (ไม่มีตัวเลือกจัดการ role)
- Member ทั่วไปไม่เห็นเมนู More เลย

---

## Screen 7: About tab

Components: ข้อความล้วน จัดเป็น section คั่นด้วย label หัวข้อเล็ก (สไตล์เดียวกับ field label ของฟอร์ม Edit Profile): "คำอธิบาย" (Description เต็ม), "หมวดหมู่" (Category), "ความเป็นส่วนตัว" (Public/Private พร้อมไอคอนล็อก/โลกเล็กๆ กำกับ), "สร้างเมื่อ" (วันที่แบบเต็ม ไม่ใช่ relative time เพราะนี่คือข้อมูลอ้างอิงถาวรไม่ใช่ activity feed), "กฎของ Club" (ข้อความอิสระที่ Owner/Admin เขียนไว้ — ถ้ายังไม่มีให้แสดง "Club นี้ยังไม่มีกฎ" แทนที่จะซ่อน section ไปเลย เพื่อให้ผู้ใช้รู้ว่ามี section นี้อยู่)

ถ้าเป็น Owner/Admin: ปุ่ม "แก้ไขกฎ" ท้าย section กฎ Club → เปิด `TextField` multiline แบบเดียวกับแก้ Description

---

## Design Rules

- ไม่ใช้ cover เต็มจอแบบ FB Groups — cover เป็นการ์ดมุมมนความสูงจำกัดเหมือนทุกการ์ดอื่นในแอป
- Role badge ใช้สีเข้ม/อ่อนต่างระดับของ Primary Blue เดียวกัน ไม่ใช้สีสถานะแยก (แดง/เขียว/เหลือง) เพื่อคงทิศทาง Blue+White+Soft Gray
- เมนู action ทั้งหมด (โพสต์, สมาชิก, Club header) ใช้ pattern เดียวกัน — `IconButton(Icons.more_vert)` เปิด `showModalBottomSheet`/`PopupMenuButton` แสดงเฉพาะตัวเลือกที่สิทธิ์ปัจจุบันทำได้จริง ไม่ใช่แสดงทุกตัวเลือกแล้ว disable (ป้องกัน UI รกและสับสนว่าทำไมกดไม่ได้)
- ทุก TabBar มี icon+label เสมอ ไม่มี icon-only

Handoff: AI Coding —
1. Database: ตาราง `clubs`, `club_members` (มี status pending/approved/banned), `club_posts` (มี `image_urls text[]`, `link_url`, `pinned`), `club_post_likes`/`club_post_comments` (มิเรอร์ `drop_likes`/`drop_comments` ทุกประการ) — RLS ของ `club_posts`/`club_post_likes`/`club_post_comments` ต้อง join เช็ค `club_members.status = 'approved'` ก่อนอนุญาต select ไม่ใช่ select-all-authenticated แบบ Drop/Pop — ขยาย `saves.content_type` check constraint ให้รองรับ `'club_post'` เพิ่ม
2. Storage: bucket ใหม่สำหรับ cover/icon/post images ของ Club — RLS ต้องเช็ค club membership ไม่ใช่แค่ folder ตรงกับ user_id
3. Role permission logic ต้องบังคับใช้ทั้งฝั่ง RLS policy (ห้าม bypass ผ่าน PostgREST ตรงๆ) และ UI (ซ่อนปุ่มที่กดไม่ได้)
4. เขียน regression test ครอบคลุมทุก AC ใน Product spec โดยเฉพาะ role permission boundary (Admin แต่งตั้ง Admin ใหม่ไม่ได้, Moderator แตะ role คนอื่นไม่ได้ ฯลฯ) และ post visibility (คนไม่ join เห็น Posts ไม่ได้ไม่ว่า Public/Private)
5. ต้อง QA & Security ตรวจสอบก่อนอนุมัติ — เน้นตรวจ privilege escalation ผ่าน RLS policy โดยตรง ไม่ใช่แค่ผ่าน UI

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-7 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-014-club-core.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
