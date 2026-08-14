# Design Spec — WYN-013: Profile V2

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-013-profile-v2.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `DropGridTile`/`DropFeedScreen` (WYN-005, 3-column grid), ปุ่ม Follow ใน `DropDetailScreen`/`PopClipView` (WYN-008), `HomePopCard`'s thumbnail 1:1 + play icon overlay + duration badge (WYN-007), `ViewProfileScreen` เดิม (WYN-003)

## ทิศทางภาพรวม: หน้าเดียว สองบุคลิก ไม่ใช่สองหน้าจอแยกกัน

`ViewProfileScreen` เดิมยังคงเป็น entry point เดียวสำหรับดูโปรไฟล์ ไม่ว่าจะเป็นของตัวเองหรือของคนอื่น — สิ่งที่เปลี่ยนคือ**สลับส่วนที่โต้ตอบได้ตาม `userId == currentUserId` เท่านั้น** ไม่ใช่สร้างหน้าจอใหม่คนละไฟล์ เพื่อไม่ให้ต้อง maintain logic ของ header/tabs สองชุดที่ต้อง sync กันตลอด

Tab bar 3 อัน (Drop/Pop/Saved) ใช้ `TabBar` มาตรฐานของ Material พร้อม icon+label เสมอ (ไม่ใช่ icon-only แบบ Instagram ที่ผู้ใช้ต้องเดาความหมาย) — ตรงตามที่แอปทำมาตลอดตั้งแต่ Bottom Nav (WYN-005) ที่มี label กำกับทุกปุ่ม

---

## Screen 1: `ViewProfileScreen` — Header สองบุคลิก

Purpose: แสดงข้อมูลโปรไฟล์ + ปุ่มที่เหมาะกับว่าเป็นโปรไฟล์ของใคร

Components (ส่วนที่ไม่เปลี่ยนจาก WYN-003/008: avatar, ชื่อ, @username, bio, จำนวน Followers/Following):
- **AppBar actions**: `isOwnProfile == true` → ปุ่ม logout (เหมือนเดิม); `isOwnProfile == false` → **ไม่มี action ใด ๆ** (ไม่มีเหตุผลให้ logout จากโปรไฟล์คนอื่น)
- **ปุ่มด้านล่าง bio**: `isOwnProfile == true` → ปุ่ม "แก้ไขโปรไฟล์" (`OutlinedButton`, เหมือนเดิมทุกประการ); `isOwnProfile == false` → ปุ่ม Follow/Unfollow **mirror สไตล์เดียวกับใน `DropDetailScreen`** (`OutlinedButton`, สี Primary Blue, ข้อความ "ติดตาม"/"กำลังติดตาม", โหลดสถานะจริงก่อนแสดง ไม่ default false — ใช้ `FollowRepository` ตัวเดียวกัน) — **ตำแหน่งเดียวกัน component ต่างกัน** ไม่ใช่โชว์ทั้งคู่พร้อมกันหรือมีที่ว่างเหลือ

Accessibility: ปุ่ม Follow ที่นี่ใช้ Semantics label แบบเดียวกับทุกจุดอื่นในแอป ("กำลังติดตาม กดเพื่อเลิกติดตาม" / "กดเพื่อติดตาม")

---

## Screen 2: Tab bar — Drop grid / Pop list / Saved

Components:
- `TabBar` ใต้ header (ใต้ปุ่มแก้ไข/Follow) — แต่ละ tab มี icon+label เสมอ:
  - "Drop" (`Icons.grid_view_outlined`) — แสดงเสมอทั้งสองบุคลิก
  - "Pop" (`Icons.play_circle_outline`) — แสดงเสมอทั้งสองบุคลิก
  - "บันทึก" (`Icons.bookmark_border`) — **แสดงเฉพาะ `isOwnProfile == true`**
- **การซ่อน tab Saved อย่างเป็นธรรมชาติ**: ไม่ใช่แสดง tab แล้ว disable/เว้นว่าง — สร้าง `List<Tab>`/`List<Widget>` แบบ conditional ตั้งแต่ต้น (2 tab เมื่อดูคนอื่น, 3 tab เมื่อดูตัวเอง) ผ่าน `DefaultTabController(length: isOwnProfile ? 3 : 2, ...)` — ผลคือโปรไฟล์คนอื่นมีแค่ 2 tab กว้างเท่า ๆ กัน ไม่มีช่องว่างหรือ tab ที่กดไม่ได้ค้างอยู่เลย
- แต่ละ tab content คือ grid (ดู Screen 3/4/5) พร้อม loading/error/empty state ของตัวเอง (pattern เดียวกับทุก feed ในแอป) — สลับ tab ไม่ reload tab อื่นที่โหลดไปแล้ว (`AutomaticKeepAliveClientMixin` หรือเทียบเท่า)

Design Rules:
- **ห้าม tab bar แบบ icon-only ไม่มี label** (ต่างจาก Instagram ที่ใช้แค่ไอคอน) — WYN ใช้ icon+label ทุกจุดของ navigation ตั้งแต่ Bottom Nav มาตลอด ต้องสม่ำเสมอ

---

## Screen 3: Drop grid tab

Components: **reuse `DropGridTile`/grid layout ของ `DropFeedScreen` ตรง ๆ** (3 คอลัมน์, `SliverGridDelegateWithFixedCrossAxisCount`) — ต่างแค่แหล่งข้อมูล (Drop ของเจ้าของโปรไฟล์คนนี้ ไม่ใช่ global feed) Empty state: "ยังไม่มี Drop เลย" (เจ้าของโปรไฟล์) หรือ "{ชื่อ} ยังไม่มี Drop เลย" (คนอื่น)

Interactions: แตะ tile → เปิด `DropDetailScreen` เหมือนเดิมทุกประการ

---

## Screen 4: Pop list tab

Purpose: แสดง Pop ทั้งหมดของเจ้าของโปรไฟล์ แบบ scan ได้เร็ว ไม่ใช่ full-screen swipe ทีละคลิปแบบ Pop Feed

Components: **grid 3 คอลัมน์แบบเดียวกับ Drop grid** (ไม่ใช่ list แนวตั้ง 1 คอลัมน์ — คำว่า "Pop list" ใน Product spec หมายถึง "รายการของ Pop" ไม่ใช่ "list layout") แต่ละ tile ใช้โครงสร้างสื่อของ `HomePopCard` (thumbnail 1:1 crop + play icon วงกลมทึบตรงกลาง + duration badge มุมล่างขวา) ตัดส่วน header (avatar/ชื่อ) และแถวปฏิสัมพันธ์ออกเพราะอยู่ใน grid หนาแน่นแบบเดียวกับ Drop grid ไม่ใช่การ์ดเดี่ยวแบบ Home — สม่ำเสมอทางสายตากับ Drop grid ข้าง ๆ (สองคอลัมน์เดียวกันมีแค่ play icon ต่างออกไป)

Empty state: "ยังไม่มี Pop เลย" / "{ชื่อ} ยังไม่มี Pop เลย"

Interactions: แตะ tile → เปิด `PopSingleClipScreen` (reuse ตรง ๆ จาก WYN-007 — คลิปเดียวเต็มจอ ไม่ swipe ต่อ เหตุผลเดียวกับที่ WYN-007 ใช้ตอนแตะการ์ด Pop จาก Home)

---

## Screen 5: Saved tab (เฉพาะเจ้าของโปรไฟล์)

Purpose: ดูเนื้อหาที่บันทึกไว้ (Drop+Pop ปนกัน) เรียงตามเวลาบันทึกล่าสุดก่อน

Components: **grid 3 คอลัมน์แบบเดียวกับ Drop/Pop grid ข้างต้น** — ทุก tile ใช้โครงสร้างสื่อเดียวกัน (Drop: รูปภาพ 1:1 ตรง ๆ; Pop: thumbnail 1:1 + play icon + duration badge เหมือน Screen 4) ทำให้ทั้ง 3 tab มี "ตระกูลภาพ" เดียวกันตาม pattern ที่ WYN-007 วางไว้แล้วสำหรับ Home (สื่อสารความต่าง Drop/Pop ผ่าน play icon ไม่ใช่ผ่าน layout ที่ต่างกัน)

Empty state: "ยังไม่มีอะไรที่บันทึกไว้ ลองกดบันทึก Drop หรือ Pop ที่ชอบดูสิ" (ไม่มี persona อื่นเพราะ tab นี้เจ้าของโปรไฟล์เท่านั้นที่เห็น)

Interactions: แตะ tile Drop → เปิด `DropDetailScreen`, แตะ tile Pop → เปิด `PopSingleClipScreen` (เหมือน Screen 3/4)

---

## Screen 6: จุด Tap-to-Profile ใหม่ (ทั่วแอป)

เพิ่มจุดแตะใหม่ให้เปิดโปรไฟล์ได้ **โดยไม่ชนกับ tap ที่มีอยู่แล้ว** — หลักการ: **เฉพาะ avatar + ชื่อผู้เขียน** เป็นจุดเปิดโปรไฟล์เสมอทุกที่ในแอป ส่วนอื่นของการ์ด/หน้าจอทำหน้าที่เดิม:

- **`DropDetailScreen` header**: ห่อ `AvatarCircle` + `Text(authorNameOrUsername)` ด้วย `InkWell` เปิดโปรไฟล์ — ปุ่ม Follow/ลบ (ที่อยู่ในแถวเดียวกัน) ยังคงเป็น tap target แยกของตัวเอง ไม่ถูกครอบ
- **`PopClipView`**: เหมือนกัน — ห่อ `AvatarCircle` + ชื่อด้วย `InkWell` เปิดโปรไฟล์ ปุ่ม Follow/ลบ แยกเหมือนเดิม
- **การ์ด Home (`HomeDropCard`/`HomePopCard`)**: ห่อเฉพาะแถว avatar+ชื่อ ด้านบนของการ์ดด้วย `InkWell` เปิดโปรไฟล์ — **ส่วนที่เหลือของการ์ด (รูป/thumbnail + แถวปฏิสัมพันธ์) ยังคงพฤติกรรมเดิมทุกประการ** (แตะรูปเปิด Detail, แตะ Like/Comment/Share/Save ทำงานของตัวเอง) — ป้องกันการชนกันด้วยการทำให้ `InkWell` ของ avatar/ชื่อเป็น widget แยก ไม่ซ้อนกับ `InkWell` ของทั้งการ์ด (Flutter's gesture arena จะให้ widget ที่อยู่ลึกกว่า/เฉพาะเจาะจงกว่าชนะเมื่อพื้นที่ทับกัน ซึ่ง avatar/ชื่อเป็น child ของการ์ดอยู่แล้ว)
- **`FollowListScreen` (WYN-008)**: ตอนนี้**ทั้งแถว**กลายเป็น tap target เปิดโปรไฟล์ (เพิ่ม `InkWell`/ripple ที่ตั้งใจไม่ใส่ไว้ตอน WYN-008 เพราะตอนนั้นยังไม่มีปลายทาง — ตอนนี้มีแล้ว) พร้อม Semantics label ปรับจาก "ผู้ใช้ {ชื่อ} ยูสเซอร์เนม {username}" เป็นแบบ button ("ผู้ใช้ {ชื่อ} ยูสเซอร์เนม {username} กดเพื่อดูโปรไฟล์")

Design Rules:
- **ไม่ mark avatar/ชื่อด้วยสีหรือ underline แบบลิงก์เว็บ** — ให้ความรู้สึกกดได้ผ่าน ripple effect (`InkWell`) ตอนแตะเท่านั้น ตรงตาม convention เดิมของแอปที่ไม่ใช้ visual affordance แบบ hyperlink

Handoff: AI Coding —
1. Database: สร้าง view `saved_feed` (ตามที่ Product แนะนำใน Risks) — `UNION ALL` ระหว่าง `saves` join `drops`/`pops` แยกฝั่งตาม `content_type`, เรียงตาม `saves.created_at`, `security_invoker = true` เพื่อให้ RLS ของ `saves` (private ต่อ user) ยังบังคับใช้จริงผ่าน view
2. เพิ่ม `DropRepository.fetchByAuthor({authorId, page})`, `PopRepository.fetchByAuthor({authorId, page})` ใหม่ (อย่าแก้ `fetchFeed` เดิม)
3. เพิ่ม `SavedRepository`/method ใหม่ query view `saved_feed` (คืน model รวม Drop+Pop คล้าย `HomeFeedItem` ของ WYN-007 — พิจารณา reuse `HomeFeedItem` ตรง ๆ ถ้าโครงสร้างเข้ากันได้ แทนที่จะสร้าง model ใหม่ซ้ำซ้อน)
4. แก้ `ViewProfileScreen` ให้มี `isOwnProfile` + `TabController` + 3 tab content ตามที่ระบุ
5. เพิ่ม tap-to-profile ใน 4 จุดที่ระบุใน Screen 6 — ทุกจุด push ไปที่ `ViewProfileScreen(userId: <ผู้เขียน/แถวนั้น>, ...)` เดิม ไม่สร้างหน้าจอใหม่
6. ต้อง QA & Security ตรวจสอบก่อนอนุมัติ — เน้นตรวจ: persona สองแบบไม่ชนกัน (โดยเฉพาะ self-follow guard ต้องยังทำงานถูกต้องเมื่อเข้าถึงผ่านเส้นทางใหม่), tap-to-profile ไม่ชนกับ tap เดิมของการ์ด Home, Saved tab เห็นเฉพาะเจ้าของจริง (RLS + UI), regression กับ Drop/Pop/Home/Follow เดิมทั้งหมด

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-6 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-013-profile-v2.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
