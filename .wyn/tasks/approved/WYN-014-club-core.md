# Product Task — WYN-014

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS รอบ 1) → AI Deploy & DevOps (รอ infra จาก Founder)

Feature: WYN CLUB — Core System (สร้าง/เข้าร่วม Club, Club Page, โพสต์ใน Club, ระบบสมาชิก/Role, Admin, Pinned Post, กฎ Club)

Goal: ให้ผู้ใช้สร้างและเข้าร่วม Community/กลุ่มตามความสนใจ (Club) ภายใน WYN ได้ครบวงจรด้วยตัวเอง — สร้าง Club, เข้าร่วม, โพสต์คุยกันในนั้น, มีระบบดูแลจัดการที่เหมาะสม — เป็น "แกนกลาง" ของ WYN CLUB ก่อน ยังไม่เชื่อมกับ Home Feed/Search/Notification/Profile ของแอปหลัก (ดู WYN-015 ใน Recommendation)

Target User: วัยรุ่น / Gen Z ที่อยากรวมตัวกับคนที่สนใจเรื่องเดียวกัน (เกม, มหาวิทยาลัย, การเรียน, กีฬา, เพลง, ถ่ายภาพ, ซื้อขาย, อาหาร ฯลฯ) ไม่ใช่แค่ follow คนคนเดียว

Problem: WYN ตอนนี้มีแค่ระบบ follow คนต่อคน (WYN-008) ไม่มีพื้นที่รวมกลุ่มตามหัวข้อ/ความสนใจเลย — Founder ส่ง spec เต็มมาที่ `.wyn/docs/product/wyn-club-founder-brief.md` (19 หัวข้อ) ระบุชัดว่า Version แรกทำเฉพาะ **Core Club System** ก่อน อย่าใส่ฟีเจอร์อนาคต (Events/Marketplace/Live/Chat/Poll ฯลฯ)

Requirements:

**สร้าง/เข้าร่วม Club**
- สร้าง Club ใหม่ได้ กรอก: Club Name, Description, Cover, Icon, Category, Privacy (Public/Private)
- **Public**: ค้นหาเจอและกด Join เข้าร่วมได้ทันที ไม่ต้องรออนุมัติ
- **Private**: กด Join ส่งเป็น "คำขอเข้าร่วม" (pending) เจ้าของ/Admin ต้องอนุมัติก่อนถึงจะเป็นสมาชิกจริง (reject = ลบคำขอทิ้ง ขอใหม่ได้ภายหลัง)
- ออกจาก Club ได้ (ยกเว้น Owner — Owner ต้องโอนสิทธิ์หรือลบ Club ก่อนเท่านั้น แต่ **การโอนสิทธิ์/ลบ Club ทั้งกลุ่มไม่อยู่ใน scope รอบนี้** ดู Risks)

**Club Page**
- ส่วนบน: Cover Image, Club Icon, Club Name, Description, จำนวนสมาชิก, ปุ่ม Join/Joined (หรือ "รออนุมัติ" ถ้าเป็น Private ที่ส่งคำขอแล้ว), Share, More (เมนู 3 จุด)
- Navigation ย่อย 3 แท็บ: **Posts | Members | About**
- **โพสต์ใน Club มองเห็นได้เฉพาะสมาชิกที่ได้รับอนุมัติแล้วเท่านั้น** ไม่ว่า Club จะเป็น Public หรือ Private (ตัดสินใจตามข้อความ Requirement ต้นฉบับของ Founder ที่ระบุว่า "โพสต์จะแสดงเฉพาะสมาชิก Club ตามสิทธิ์ของ Club" โดยไม่แยกเงื่อนไขตาม privacy — Public ต่างจาก Private แค่ตรงที่เข้าเป็นสมาชิกได้ทันทีไม่ต้องรออนุมัติเท่านั้น ไม่ใช่เรื่องมองเห็นโพสต์ได้ก่อนเข้าร่วม) คนที่ยังไม่เข้าร่วมเห็นได้แค่ Club Page ส่วนบน (Cover/ชื่อ/คำอธิบาย/จำนวนสมาชิก) ไม่เห็นเนื้อหาโพสต์
- **About tab**: แสดง Description เต็ม, Category, Privacy, วันที่สร้าง, และ **กฎของ Club** (ดูหัวข้อ Club Rules ด้านล่าง)

**โพสต์ใน Club**
- สมาชิก (ทุก Role) สร้างโพสต์ในหน้า Club ได้ รองรับ: Text, Image (เดี่ยว), Multiple Images, Link
- แต่ละโพสต์มี: Like, Comment, Share, Bookmark, More (เมนูลบ/ปักหมุด สำหรับ Owner/Admin/Moderator หรือเจ้าของโพสต์เอง)
- **ปุ่ม "+ Create Post" ในหน้า Club**: เลือกโพสต์ใน "My Profile" (ไปที่ระบบ Drop เดิม — นอก scope ของ task นี้ ปุ่มนี้แค่ลิงก์ไปแยก) หรือ "Club" (ถ้าเข้ามาจาก Club อยู่แล้ว ให้เลือก Club นั้นเป็นค่าเริ่มต้นและล็อกไว้ ไม่ต้องเลือก Club อื่น — การสร้างโพสต์ Club จากที่อื่นที่ไม่ใช่ในหน้า Club นั้นๆ ไม่อยู่ใน scope รอบนี้)

**ระบบสมาชิก / Role**
- 4 ระดับ: **Owner** (ผู้สร้าง Club, มีทั้งหมด 1 คนต่อ Club, สิทธิ์สูงสุด) → **Admin** (Owner แต่งตั้ง) → **Moderator** (Owner หรือ Admin แต่งตั้ง) → **Member** (สมาชิกทั่วไป)
- หน้า Members: แสดง Profile/Name/Username/Role ของสมาชิกทั้งหมด (เฉพาะที่ status = approved)

**Admin System — สิทธิ์แยกตาม Role**
- **Owner**: ทำได้ทุกอย่างด้านล่าง + แต่งตั้ง/ถอด Admin และ Moderator
- **Admin**: Approve/Remove/Ban Members, Delete Posts, Pin Posts, Edit Club Information, Change Club Privacy, แต่งตั้ง/ถอด **Moderator** เท่านั้น (แต่งตั้ง Admin คนอื่นทำไม่ได้ — สิทธิ์นี้เป็นของ Owner เท่านั้น เพื่อป้องกันไม่ให้ Admin ตั้ง Admin ใหม่มาแทนที่ Owner)
- **Moderator**: Delete Posts, Pin Posts, Remove/Ban Members ทั่วไป (**ไม่รวม** Approve คำขอเข้าร่วม, แก้ไขข้อมูล Club, เปลี่ยน Privacy, จัดการ Role — ตรงตามที่ spec ระบุว่า "ช่วยดูแลโพสต์และสมาชิกได้ แต่ไม่มีสิทธิ์ระดับ Owner")
- **Member**: โพสต์/Like/Comment/ออกจาก Club เท่านั้น

**Pinned Post**
- Owner/Admin/Moderator ปักหมุดโพสต์ได้ (ไม่จำกัดจำนวน แต่ UI ควรเรียงโพสต์ที่ปักหมุดไว้บนสุดของ Posts tab เสมอ)

**Club Rules**
- Owner (และ Admin ตามสิทธิ์ Edit Club Information) เขียนกฎของ Club ได้เป็นข้อความอิสระ (free-form list) แสดงในแท็บ About ให้สมาชิก/ผู้สนใจอ่านก่อนเข้าร่วมได้

Acceptance Criteria:
- [ ] สร้าง Club ใหม่ (กรอกครบ Name/Description/Cover/Icon/Category/Privacy) → Club ปรากฏจริง ผู้สร้างเป็น Owner อัตโนมัติ
- [ ] Join Club แบบ Public → เป็นสมาชิกทันที เห็นโพสต์ได้ทันที
- [ ] Join Club แบบ Private → สถานะเป็น "รออนุมัติ" ยังไม่เห็นโพสต์จนกว่า Admin/Owner จะอนุมัติ
- [ ] Owner/Admin อนุมัติคำขอเข้าร่วม → ผู้ขอเข้าร่วมกลายเป็นสมาชิกจริง เห็นโพสต์ได้ทันที
- [ ] คนที่ยังไม่เข้าร่วม Club เปิด Club Page → เห็นข้อมูลทั่วไป (Cover/ชื่อ/คำอธิบาย/จำนวนสมาชิก) แต่**ไม่เห็น**เนื้อหาโพสต์ใน Posts tab
- [ ] สมาชิกสร้างโพสต์ (Text/Image/หลายรูป/Link) ในหน้า Club → โพสต์ปรากฏจริงในแท็บ Posts เฉพาะสมาชิกที่ได้รับอนุมัติแล้วเห็น
- [ ] Like/Comment โพสต์ใน Club ได้ ค่า count อัปเดตถูกต้อง
- [ ] Owner/Admin/Moderator ปักหมุดโพสต์ → โพสต์นั้นอยู่บนสุดของ Posts tab เสมอ
- [ ] Owner/Admin ลบโพสต์ของสมาชิกคนอื่นได้ Moderator ก็ทำได้เช่นกัน แต่ Member ทั่วไปลบได้แค่โพสต์ตัวเอง
- [ ] Owner/Admin ลบ/แบนสมาชิกได้ Moderator ทำได้เฉพาะ remove/ban ทั่วไป (ไม่แตะ role คนอื่น)
- [ ] Owner แต่งตั้ง Admin/Moderator ได้ Admin แต่งตั้งได้แค่ Moderator (แต่งตั้ง Admin ใหม่ไม่ได้)
- [ ] เปลี่ยน Privacy ของ Club (Public↔Private) โดย Owner/Admin ได้จริง
- [ ] แก้ไขข้อมูล Club (Name/Description/Cover/Icon/Category) โดย Owner/Admin ได้จริง
- [ ] เขียน/แก้กฎ Club แสดงในแท็บ About ถูกต้อง
- [ ] ออกจาก Club ได้ (ยกเว้น Owner) หลังออกไม่เห็นโพสต์อีกต่อไป
- [ ] Drop/Pop/Home/Follow/Profile/Search/Notification เดิมทั้งหมดยังทำงานปกติ ไม่มี regression

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved) — ไม่ต้องพึ่ง Drop/Pop/Home/Search/Notification โดยตรงในรอบนี้เพราะยังไม่เชื่อม integration (ดู WYN-015)

Priority: P1 (ใหม่) — Founder ยืนยันให้ทำต่อจาก WYN-012 ทันที แทนที่คิวเดิมของ WYN-010 (Share formalization) (2026-08-14) — Pop (WYN-006) ถูกระงับการพัฒนาเพิ่มเติมไว้ก่อนพร้อมกัน (ไม่กระทบ task นี้)

Risks:
- **Role-based permission เป็นแนวคิดใหม่ที่ไม่เคยมีในระบบมาก่อน**: Follow (WYN-008) เป็นแค่ true/false ไม่มีระดับสิทธิ์ — ต้องออกแบบ authorization ใหม่ทั้งหมด (RLS policy ต้อง join กับ `club_members` เพื่อเช็ค role ก่อนอนุญาตทุก write บน `club_posts`/`club_members` เอง) ซับซ้อนกว่า pattern เดิมทุกจุดที่เคยทำมา ต้องระวังไม่ให้เกิดช่องโหว่ privilege escalation (เช่น Member ที่ยิง request ตรงไป PostgREST พยายามตั้งตัวเองเป็น Admin)
- **Owner มีได้แค่ 1 คนต่อ Club**: ต้องมี constraint/logic ป้องกันไม่ให้มี Owner ซ้ำ หรือแต่งตั้ง Owner คนที่สอง — รอบนี้ไม่ทำระบบโอนสิทธิ์ Owner (transfer ownership) หรือลบ Club ทั้งกลุ่ม เพราะไม่ได้ระบุไว้ใน spec ต้นฉบับชัดเจนและเพิ่มความซับซ้อนเกินจำเป็นสำหรับ Core system รอบแรก — ถ้า Founder ต้องการทีหลังค่อยทำเป็น task แยก
- **Multiple Images ไม่เคยมี pattern มาก่อน**: Drop (WYN-005) มีแค่ 1 รูปต่อโพสต์ ต้องออกแบบใหม่ (แนะนำ column `image_urls text[]` แทนตารางแยก เพื่อความง่าย ไม่ over-engineer)
- **Storage RLS ซับซ้อนกว่า Drop/Pop เดิม**: รูป Cover/Icon/โพสต์ใน Club ต้องเช็คสิทธิ์ตาม "เป็นสมาชิก Club ที่ approved แล้วหรือ Owner/Admin ของ Club นั้น" ไม่ใช่แค่ "โฟลเดอร์ตรงกับ user_id ของตัวเอง" แบบ Drop/Pop เดิม (`avatars`/`drop-images`/`pop-videos`) — ต้องออกแบบ Storage policy ใหม่ที่ query join กับ `club_members`
- **โพสต์ Club reuse pattern Like/Comment ของ Drop ได้เกือบทั้งหมด**: แนะนำสร้าง `club_post_likes`/`club_post_comments` มิเรอร์ `drop_likes`/`drop_comments` ทุกประการ (โครงสร้างเดียวกัน แค่ RLS select ต้องเช็ค club membership แทนที่จะเป็น select-all-authenticated) — Bookmark ของโพสต์ Club แนะนำ reuse ตาราง `saves` เดิม (WYN-005 ออกแบบไว้แล้วว่า `content_type` ขยายได้ในอนาคต) เพิ่ม `content_type = 'club_post'` เข้าไปแทนที่จะสร้างตารางใหม่ — ต้องตรวจสอบว่า Saved tab ของ Profile V2 (WYN-013) จะต้องอัปเดตด้วยหรือไม่ (แนะนำ **ไม่รวม** club post เข้า Saved tab เดิมในรอบนี้เพื่อไม่ให้กระทบ `saved_feed` view ที่ผ่าน QA แล้ว — bookmark ของ Club post เก็บไว้แต่ยังไม่ต้องมีหน้าจอแสดงผลรวมในรอบนี้ ดู WYN-015)
- ยังไม่มี Content Moderation อัตโนมัติ (นอก scope เหมือนทุก feature ก่อนหน้า)

Recommendation:
1. เริ่ม WYN-014 (Club Core) ทันทีตามที่ Founder ยืนยันแล้ว — ครอบคลุมเฉพาะสิ่งที่ระบุใน Requirements ข้างต้นเท่านั้น
2. **แบ่ง scope ที่เหลือของ WYN CLUB brief ออกเป็น WYN-015 (Club Discovery & Integration) เป็น task ต่อยอดในอนาคต** — ยังไม่เริ่มตอนนี้ ครอบคลุม: Explore Clubs (Search/Categories/Popular/New/Recommended), Search integration เข้าระบบค้นหาเดิมของ WYN-009, Notification integration เข้าตาราง `notifications` เดิมของ WYN-012 (เพิ่ม type ใหม่: club_post_reply, club_post_like, club_announcement, club_join_request, club_mention, club_new_post), Profile integration ("My Clubs" section ใน `ViewProfileScreen`), Home integration ("For You"/"From Your Clubs" แบ่ง tab หรือ toggle ใน Home Feed) — เหตุผลที่แยก: เหมือน pattern ที่ Drop/Pop เคยทำ (สร้าง core content type ก่อน แล้ว Home/Search/Notification integration ตามมาทีหลังเป็น task แยกต่างหาก) ทำให้แต่ละ task มีขอบเขตทดสอบได้จริงและไม่ใหญ่เกินไป
3. **ตำแหน่ง UI ส่วน "CLUB" ใน Home**: วางเป็น section ใหม่ใต้แถวบนสุด (search bar + ไอคอนกระดิ่งจาก WYN-012) และเหนือ Feed หลัก — แสดงปุ่มลัด ("+ สร้าง Club", "Club ของฉัน", "สำรวจ Club") และ card แนวนอน scroll ได้ของ Club ที่เข้าร่วมแล้ว/กำลังนิยม (รายละเอียด UI ให้ AI Design ตัดสินใจ) — **หมายเหตุ**: ส่วนนี้เป็นแค่ entry point เข้า Club ที่มีอยู่ ตัวเนื้อหา "Club ที่กำลังนิยม" แบบ Discovery เต็มรูปแบบยังไม่ทำในรอบนี้ (รอ WYN-015) รอบนี้แสดงแค่ "Club ของฉัน" (ที่เข้าร่วมแล้ว) พอ
4. **โพสต์ Club มองเห็นเฉพาะสมาชิกที่ approved แล้ว** ไม่ว่า Public/Private — เหตุผลอยู่ใน Requirements ข้างต้น
5. **Role permission**: Owner แต่งตั้ง Admin+Moderator ได้, Admin แต่งตั้งได้แค่ Moderator, Moderator ดูแลโพสต์/สมาชิกทั่วไปแต่แตะ role/ข้อมูล Club/privacy ไม่ได้ — เหตุผลอยู่ใน Requirements ข้างต้น
6. **ไม่ทำระบบโอนสิทธิ์ Owner หรือลบ Club ทั้งกลุ่มในรอบนี้** — เหตุผลอยู่ใน Risks

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) UI ส่วน CLUB ใน Home (ปุ่มลัด + card แนวนอนของ Club ของฉัน) (2) หน้า Create Club (3) Club Page (header + tab Posts/Members/About) (4) โพสต์ใน Club (การ์ดโพสต์, Create Post flow เลือก My Profile/Club) (5) หน้า Members (list + role badge + เมนูจัดการสำหรับ Owner/Admin/Moderator) (6) About tab (กฎ Club) (7) Admin action UI (Approve/Remove/Ban/Pin/Delete/Change Privacy/Manage Roles) — ต้องออกแบบให้ไม่ลอก Facebook Groups โดยตรง ใช้ Design system เดิมของ WYN (Blue+White+Soft Gray, Rounded Cards, ไม่ใช้ Liquid Glass)

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-014-club-core.md` — สรุป: `ClubPage` ใช้โครงสร้างเดียวกับ `ViewProfileScreen` ในระดับแนวคิด (header คงที่ + TabBar) แต่ cover เป็นการ์ดมุมมนความสูงจำกัด ไม่ใช่ hero เต็มจอแบบ FB Groups — 7 หน้าจอ: (1) CLUB section ใน Home สูงจำกัด ~180px ใต้แถวบนสุด มีปุ่มลัด + card แนวนอนของ Club ที่เข้าร่วมแล้ว (2) `CreateClubScreen` reuse ฟอร์ม Edit Profile (3) `ClubPage` header ปุ่ม Join 3 สถานะ + Share + More (4) TabBar Posts/สมาชิก/เกี่ยวกับ ที่ไม่ join ก็เห็นแท็บอยู่แต่เนื้อหา Posts ถูกแทนที่ด้วย join-gate (5) การ์ดโพสต์รองรับ Text/รูปเดี่ยว/หลายรูป carousel/Link มิเรอร์ interaction row ของ Drop (6) Members tab role badge (สี Primary Blue เข้ม/อ่อนตาม role ไม่ใช้สีสถานะ) + section คำขอเข้าร่วมสำหรับ Owner/Admin + เมนูจัดการ role-gated ต่อแถว (7) About tab กฎ Club แก้ไขได้โดย Owner/Admin — เน้นย้ำ handoff: role permission logic ต้องบังคับทั้ง RLS และ UI, storage RLS ต้องเช็ค membership ไม่ใช่แค่ folder=user_id

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- Database (`supabase/schema.sql`): ตาราง `clubs`/`club_members`/`club_posts`/`club_post_likes`/`club_post_comments` ใหม่ — `category` เป็น nullable ตาม Design's "Name+Privacy บังคับ อย่างอื่น optional" (Product's AC พูดถึง "กรอกครบ" แต่ Design ชี้ชัดกว่าว่า field ไหนบังคับจริง ใช้ Design เป็นหลักสำหรับ UI behavior) — `club_role(club_id, user_id)` เป็น `security definer` SQL function ตัวเดียวที่ทุก RLS policy/storage policy เรียกใช้ร่วมกัน (คืน role ถ้าเป็นสมาชิก approved, null ถ้าไม่ใช่) ป้องกัน self-referential RLS recursion บน `club_members` เอง — trigger `clubs_add_owner_membership` สร้างสมาชิกภาพ Owner อัตโนมัติตอนสร้าง Club — trigger `clubs_prevent_owner_id_change` (พบเองระหว่างเขียน ไม่ได้ระบุไว้ใน spec ต้นฉบับ) กัน Owner/Admin ที่มีสิทธิ์ update `clubs` ทั่วไปแอบเปลี่ยน `owner_id` ผ่าน update ปกติ เพราะ RLS update policy เช็คแค่ role ของผู้ทำ ไม่ได้ตรวจว่าคอลัมน์ `owner_id` เองถูกแก้หรือไม่ — role/status mutation ทั้งหมด (approve/reject/set role/remove/ban) เป็น RPC function 5 ตัวแทน raw RLS (มิเรอร์ `increment_pop_view_count` ของ WYN-006) เพราะ permission graph ซับซ้อนเกินจะเขียนเป็น RLS policy ตรงๆ ได้ปลอดภัย — ทุก RPC re-derive role ของผู้เรียกเองจาก `club_role()` ไม่เชื่อค่าที่ client ส่งมา และกัน self-target/owner-target ทุกตัว — `club_members` **ไม่มี raw update policy เลย** — storage bucket `club-media` เป็น **non-public bucket แรกของโปรเจกต์** (ต่างจาก `avatars`/`drop-images`/`post-images`/`pop-videos`) เพราะโพสต์ Club ต้องเห็นเฉพาะสมาชิก approved เท่านั้นแม้ Club จะเป็น Public — RLS select แยก cover/icon (segment เดียว, ใครก็ได้ที่ login) กับรูปโพสต์ (segment มากกว่า 1, เฉพาะสมาชิก approved) — ขยาย `saves.content_type` ให้รองรับ `'club_post'` (reuse ตารางเดิมของ WYN-005 ตามที่ Product แนะนำไว้)
- `ClubRepository`/`ClubPostRepository` (ใหม่ทั้งคู่): เพราะ bucket ไม่ public จึงเก็บ **storage path** ใน `cover_url`/`icon_url`/`image_urls` แทน display URL แล้ว mint signed URL (`createSignedUrl`, TTL 1 ชั่วโมง) สดใหม่ทุกครั้งที่ fetch แทนการ cache URL ถาวรแบบ bucket public เดิม — `createPost` อัปโหลดรูปไปยัง path ที่ระบุด้วย user_id+timestamp (ไม่ใช้ post_id เพราะยังไม่มี id ก่อน insert) **ก่อน** insert แถวโพสต์ ไม่ใช่หลัง เพื่อไม่ให้แถวโพสต์-รูปอย่างเดียวไม่มีข้อความ/ลิงก์ชนกับ `club_posts_have_content` CHECK ตอน insert ครั้งแรก (ถ้า insert ก่อนแล้วค่อย update image_urls ทีหลัง แถวชั่วคราวจะ content=null ทั้งหมดและ insert ไม่ผ่าน)
- Models: `Club`, `ClubMember` (พร้อม `ClubMemberRolePermissions` extension `canModeratePosts`/`canManageClub`), `ClubPost` (มิเรอร์ `Drop` + `imageUrls`/`linkUrl`/`pinned`), `ClubPostComment` (ไม่มี per-comment like — ไม่ถูกระบุไว้ใน spec ทั้งสองฉบับสำหรับ Club จึงไม่เพิ่มโดยไม่จำเป็น ต่างจาก `DropComment`)
- UI ครบ 7 หน้าจอตาม Design: `ClubSection` (widget ใน Home, ผูก `TabController` เอง — ไม่ใช้ `DefaultTabController` เพราะ More menu ต้อง jump ไป Members tab จาก context ที่อยู่เหนือมันในทรี), `CreateClubScreen`/`EditClubInfoScreen`, `ClubPage` (header 3 สถานะปุ่ม Join + role-gated More menu + TabBar), `ClubPostsTab`+`ClubPostCard`+`ClubPostImages` (carousel รูปหลายรูป reuse ได้ทั้งใน card list และ detail screen)+`ClubPostDetailScreen` (มิเรอร์ `DropDetailScreen` เพราะ spec ไม่ได้นิยาม comment-thread UI แยกไว้), `CreateClubPostScreen`, `ClubMembersTab` (pending section + role-gated action menu), `ClubAboutTab`, `MyClubsScreen`+`ExploreClubsPlaceholderScreen` (ปลายทางของ "ดูทั้งหมด"/"สำรวจ Club" ใน Design's Screen 1)
- `app/lib/features/home/presentation/home_feed_screen.dart`/`root_shell.dart`: เพิ่ม `ClubSection` ระหว่างแถวบนสุดกับ Feed หลัก, เพิ่ม `ClubRepository`/`ClubPostRepository` เป็น shared instance

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. **Layout overflow ใน `ClubPage` header**: Cover ใช้ `AspectRatio(16:9)` เต็มความกว้างจอตอนแรก ทำให้สูงเกินงบประมาณพื้นที่ที่เหลือใน Column ที่ไม่ scroll (header+TabBar+Expanded) จน overflow บน viewport แคบ — แก้เป็น fixed height 140px ตาม Design's "cover เป็นการ์ดมุมมนความสูงจำกัด...ไม่ใช่เต็มความกว้างจอทะลุขอบแบบ FB" ที่ระบุไว้แต่ตอนแรก implement ผิดไปใช้ AspectRatio
2. Path การอัปโหลดรูปโพสต์หลายรูปที่ชนกับ `club_posts_have_content` CHECK (อธิบายไว้ใน Implementation ข้างบน)

Files Changed:
- `supabase/schema.sql`: เพิ่มตาราง `clubs`/`club_members`/`club_posts`/`club_post_likes`/`club_post_comments`, function `club_role()`, trigger `clubs_add_owner_membership`/`clubs_prevent_owner_id_change`, RPC 5 ตัว, storage bucket `club-media` + policy, แก้ `saves.content_type` CHECK
- ใหม่ทั้งหมด: `app/lib/features/club/data/{club,club_member,club_post,club_post_comment,club_repository,club_post_repository}.dart`, `app/lib/features/club/presentation/{create_club_screen,edit_club_info_screen,club_page,create_club_post_screen,club_post_detail_screen,my_clubs_screen}.dart`, `app/lib/features/club/presentation/widgets/{club_section,club_mini_card,club_posts_tab,club_post_card,club_members_tab,club_about_tab,explore_clubs_placeholder_screen}.dart`
- แก้: `app/lib/features/home/presentation/home_feed_screen.dart` (เพิ่ม `ClubSection` + Key บน ListView หลักเพื่อไม่ชนกับ Scrollable ใหม่ในเทสต์), `app/lib/features/root/presentation/root_shell.dart` (shared repositories)
- test ใหม่: `app/test/{club_members_tab_test,club_posts_tab_test,club_page_test,create_club_screen_test}.dart`, `app/test/support/{recording_club_repository,recording_club_post_repository}.dart`
- test แก้: `app/test/home_feed_screen_test.dart` (เพิ่ม club repositories, แก้ `scrollUntilVisible` ให้ระบุ Scrollable ที่ถูกต้องแทน `.first`)

Reason: implement ตาม Product spec + Design spec ของ WYN-014 ครบตามขอบเขต Core — สร้าง/เข้าร่วม Club, Club Page, โพสต์ (Text/รูปเดี่ยว/หลายรูป/Link), ระบบสมาชิก 4 Role, Admin system, Pinned Post, กฎ Club — role-based permission enforce ทั้ง RLS/RPC (ห้าม bypass ผ่าน PostgREST ตรงๆ) และ UI (ซ่อนตัวเลือกที่กดไม่ได้แทนที่จะแสดงแล้ว disable)

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 148/148 ผ่านทั้งหมด (เพิ่มจาก 124 เดิม — 24 เทสต์ใหม่: 11 ใน `club_members_tab_test.dart` ครอบคลุม role-permission boundary matrix ทุกคู่ role×action ที่ Product ระบุ, 5 ใน `club_posts_tab_test.dart` ครอบคลุม post-visibility gating + pinned-first ordering, 6 ใน `club_page_test.dart` ครอบคลุม Join button 3 สถานะ + More menu role gating, 2 ใน `create_club_screen_test.dart` ครอบคลุม required-field gating)
- **ทำ red→green regression proof อิสระ 2 จุดที่ safety-critical ที่สุด**:
  1. **Privilege escalation — Admin แต่งตั้ง Admin**: เพิ่ม `_MemberAction('ตั้งเป็น Admin', ...)` ชั่วคราวเข้าไปใน branch ของ Admin viewer ใน `_actionsFor` (`club_members_tab.dart`) จำลองบั๊กที่ Admin จะเห็นตัวเลือกตั้ง Admin คนอื่นได้ (ผิด AC "Admin แต่งตั้งได้แค่ Moderator") → รัน `club_members_tab_test.dart` เฉพาะเทสต์ "never sees ตั้งเป็น Admin" → **FAIL จริง** (`Expected: no matching candidates, Actual: Found 1 widget with text "ตั้งเป็น Admin"`) → revert → รันซ้ำ **PASS** ทั้ง 11 เทสต์ในไฟล์
  2. **Post-visibility gating — non-member เห็นเนื้อหาโพสต์**: เปลี่ยน `bool get _isMember => widget.myRole != null;` เป็น `=> true;` ชั่วคราวใน `club_posts_tab.dart` จำลองบั๊กที่คนไม่ join เห็นโพสต์ได้ (ผิด Product's core requirement ที่ระบุชัดว่า "โพสต์จะแสดงเฉพาะสมาชิก Club...ไม่ใช่เรื่องมองเห็นโพสต์ได้ก่อนเข้าร่วม") → รัน test "never the post content" → **FAIL จริง** (ไม่เจอข้อความ join-prompt เพราะ gate หายไป) → revert → รันซ้ำ **PASS**

Known Issues:
- WYN-015 (Discovery/Search/Notification/Profile/Home integration) ยังไม่เริ่ม — "สำรวจ Club" เป็น placeholder เฉย ๆ ตอนนี้
- ยังไม่ทดสอบ RLS/RPC/storage policy จริงกับ Supabase project จริง (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า) — โดยเฉพาะ 5 RPC function และ signed URL flow ที่ตรวจได้แค่ระดับ code review ในตอนนี้
- Club ownership transfer และ club deletion ไม่อยู่ใน scope รอบนี้ตามที่ Product ตัดสินใจไว้ (ดู Risks)
- `ClubPostDetailScreen` ไม่มี tap-to-profile บน avatar ผู้โพสต์ (ตาม Design spec ที่บอกว่าไม่ critical รอบนี้ เก็บไว้เป็น nice-to-have ทีหลัง)

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ WYN-014 ก่อนอนุมัติ — เน้นตรวจเป็นพิเศษ: (ก) privilege escalation ผ่านทุก RPC function โดยตรง (ไม่ใช่แค่ผ่าน UI) โดยเฉพาะ Admin-แต่งตั้ง-Admin, Admin-แตะ-Admin-อื่น, Moderator-แตะ-role, ทุกคน-แตะ-Owner (ข) RLS ของ `club_members`/`club_posts`/`club_post_likes`/`club_post_comments` ป้องกัน bypass ผ่าน PostgREST ตรงๆ จริง โดยเฉพาะ post-visibility ที่ไม่ join (Public หรือ Private ก็ตาม) (ค) `club-media` storage bucket policy แยก cover/icon (public-ish) กับรูปโพสต์ (members-only) ถูกต้องจริง (ง) `clubs_prevent_owner_id_change` trigger ป้องกัน Admin ชิงความเป็นเจ้าของจริง (จ) `club_members` insert policy ผูก status กับ privacy ของ club จริง ไม่ให้ self-insert เป็น approved เข้า Private club ได้ (ฉ) regression กับ Drop/Pop/Home/Follow/Profile/Search/Notification เดิมทั้งหมด (ช) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัด

---

## QA & Security Report — รอบ 1 (AI QA & Security)

```
Feature: WYN-014 Club Core (สร้าง/เข้าร่วม Club, Club Page, โพสต์, Role 4 ระดับ, Admin system, Pinned Post, กฎ Club)
Environment: flutter analyze + flutter test (static/widget-test level เท่านั้น — ยังไม่มี Supabase project จริงเหมือนทุก feature ก่อนหน้า, ตรวจ RLS/RPC/trigger/storage policy ด้วยการอ่านโค้ดและให้เหตุผลเท่านั้น ไม่มี live Postgres ให้รันจริง)
```

**หมายเหตุก่อนเริ่ม**: sync `main` ใหม่หลัง merge PR #63 แล้วรัน `flutter analyze`/`flutter test` อิสระเองก่อนอ่านโค้ด ไม่เชื่อตัวเลข 148/148 หรือคำอธิบาย gap ที่ Coding Output รายงานไว้เฉย ๆ — ผลตรงกัน: `flutter analyze` สะอาด, `flutter test` 148/148 ผ่าน

### ไล่ Requirements ทีละบรรทัด (Product spec)
- [x] สร้าง Club (Name/Description/Cover/Icon/Category/Privacy) — ยืนยันจาก `CreateClubScreen`/`ClubRepository.createClub` จริง — **หมายเหตุ**: Design ระบุชัดว่าบังคับแค่ Name+Privacy (Cover/Icon/Description/Category optional เหมือน bio ของ Profile) ซึ่งต่างจากคำว่า "กรอกครบ" ใน Requirements ตรงตัว — ยืนยันว่า Coding ทำตาม Design ถูกต้อง (Design มีรายละเอียด UI behavior ที่ชัดเจนกว่า และ AC #1 เขียนแบบ "กรอกครบ...→ Club ปรากฏจริง" ซึ่งไม่ขัดกับ optional fields — ครบตามเงื่อนไข "ถ้ากรอกครบก็ต้องปรากฏจริง" โดยไม่ได้บังคับว่าต้องกรอกครบเสมอ)
- [x] Public ค้นหาเจอ+join ทันที, Private ต้องส่งคำขอ+อนุมัติ — ยืนยันจาก `joinClub()` (status ตาม `club.privacy`) และ `club_members` insert policy cross-check กับ `clubs.privacy` จริง (อ่าน SQL ยืนยัน — ดู Security Findings)
- [x] ออกจาก Club ได้ยกเว้น Owner — ยืนยัน `club_members` delete policy `role <> 'owner'` จริง และ UI (`_buildJoinButton`) ไม่ล็อกปุ่มไว้แต่ RLS เป็นตัวบังคับจริง
- [x] Club Page header ครบ (Cover/Icon/Name/Description/จำนวนสมาชิก/Join-Joined/Share/More) + TabBar 3 แท็บ — ยืนยันจากโค้ด `club_page.dart` ตรงตาม Design Screen 3-4
- [x] **โพสต์เห็นเฉพาะสมาชิก approved ไม่ว่า Public/Private** — นี่คือ core requirement ที่สำคัญที่สุดของ task — ยืนยัน **สองชั้น**: (1) DB — `club_posts`/`club_post_likes`/`club_post_comments` select policy ทุกตัวเช็ค `club_role(...) is not null` ไม่ใช่ select-all-authenticated เลย (2) UI — `ClubPostsTab._isMember` gate แสดง join-prompt แทน list เมื่อ `myRole == null` — ทำ red→green proof เองอิสระยืนยันทั้งสองทิศทาง (ดูด้านล่าง)
- [x] โพสต์รองรับ Text/Image/Multiple Images/Link — ยืนยัน `club_posts.image_urls text[]`/`link_url`, `CreateClubPostScreen` มี text field + multi-image picker + link field, `ClubPostImages` แสดง carousel เมื่อมากกว่า 1 รูป
- [x] Role 4 ระดับ (Owner/Admin/Moderator/Member) — ยืนยัน `club_members.role` CHECK + `ClubMemberRole` enum ตรงกัน 4 ค่า
- [x] Admin System สิทธิ์แยกตาม Role ครบ (Approve/Remove/Ban/Delete/Pin/Edit Info/Change Privacy/Manage Moderator) — ยืนยันทีละสิทธิ์ในหัวข้อ Security Findings ด้านล่าง
- [x] Pinned Post — ยืนยัน `club_posts.pinned` + "Club staff can pin or unpin" RLS (`owner`/`admin`/`moderator`) + `fetchPosts` sort `pinned desc, created_at desc`
- [x] Club Rules free-form text ในแท็บ About — ยืนยัน `clubs.rules` + `ClubAboutTab` แก้ไขได้เฉพาะ `canManageClub`

### ไล่ Design Components ทีละบรรทัด (Screen 1-7)
- [x] Screen 1 (Home) — section สูงจำกัด (`ConstrainedBox(maxHeight: 180)`), ปุ่มลัด "+ สร้าง Club"/"สำรวจ Club", card แนวนอน `ClubMiniCard`, empty state ข้อความตรงตาม spec เป๊ะ
- [x] Screen 2 (Create Club) — reuse ฟอร์ม Edit Profile ตรงตาม spec, `SegmentedButton` แทน `RadioListTile` ที่ deprecated ใน Flutter SDK เวอร์ชันนี้ (Design เปิดทางเลือกไว้ทั้งสองแบบ "SegmentedButton หรือ RadioListTile" — Coding เลือก SegmentedButton ถูกต้องเพื่อเลี่ยง deprecation warning โดยยังคงคำอธิบายใต้ตัวเลือกไว้ตาม spec)
- [x] Screen 3 (ClubPage header) — Cover มุมมนความสูงจำกัด (**ไม่ใช่** AspectRatio เต็มจอ — ตรวจพบว่า Coding แก้ bug overflow นี้เองแล้วก่อนส่ง เป็นไปตาม Design "cover เป็นการ์ดมุมมนความสูงจำกัด...ไม่ใช่เต็มความกว้างจอทะลุขอบแบบ FB" จริง), Icon ซ้อนมุมล่างซ้าย, ปุ่ม Join 3 สถานะ + Semantics label ตรงตาม spec คำต่อคำทั้ง 3 ข้อความ
- [x] Screen 4 (TabBar) — คนไม่ join ยังเห็นทั้ง 3 แท็บ, Posts tab แทนที่ด้วย join-gate placeholder ตรงตาม spec (ตรวจแล้วว่า Members/About tab ไม่ gate แต่ Posts tab เท่านั้นที่ gate — ถูกต้อง)
- [x] Screen 5 (Posts tab) — ปักหมุดเรียงบนสุด + label "ปักหมุด", การ์ดโพสต์ interaction row เหมือน Drop, More menu role-gated ตรงตาม spec (เจ้าของเห็นลบอย่างเดียว, staff เห็นลบ+ปักหมุดบนโพสต์คนอื่น), FAB เฉพาะสมาชิก approved
- [x] Screen 6 (Members tab) — role badge สี Primary Blue เข้ม/อ่อนตาม role (ไม่ใช้สีสถานะ), section คำขอเข้าร่วมเฉพาะ Owner/Admin, เมนูจัดการ role-gated ต่อแถวตรงตาม spec — ตรวจ code จริงยืนยันสีที่ใช้เป็น `colorScheme.primary`/`.withValues(alpha:0.5)` เท่านั้น ไม่มีสีแดง/เขียว/เหลือง
- [x] Screen 7 (About tab) — section label style เดียวกับฟอร์ม Edit Profile, "Club นี้ยังไม่มีกฎ" placeholder เมื่อว่าง, ปุ่มแก้ไขกฎเฉพาะ Owner/Admin, วันที่สร้างแบบเต็มไม่ใช่ relative — ยืนยันจากโค้ดจริง (`_formatFullDate` ไม่ใช้ `relativeTimeLabel`)

### ไล่ Acceptance Criteria ทีละข้อ (16 ข้อ)
1. [x] สร้าง Club → ปรากฏจริง ผู้สร้างเป็น Owner อัตโนมัติ — ยืนยันด้วย `clubs_add_owner_membership` trigger + มี regression test (`create_club_screen_test.dart`)
2. [x] Join Public → สมาชิกทันที เห็นโพสต์ทันที — ยืนยันด้วย logic + RLS
3. [x] Join Private → "รออนุมัติ" ยังไม่เห็นโพสต์ — มี regression test จริง (`club_page_test.dart` pending scenario)
4. [x] Owner/Admin อนุมัติ → เป็นสมาชิกจริง เห็นโพสต์ทันที — ยืนยัน `approve_club_member` RPC + มี regression test (`club_members_tab_test.dart` "is visible with Approve/Reject buttons")
5. [x] คนไม่ join เห็นข้อมูลทั่วไปแต่ไม่เห็นโพสต์ — ยืนยันสองชั้น (DB+UI) พร้อม red→green proof อิสระ (ดูด้านล่าง)
6. [x] สร้างโพสต์ทุกประเภท ปรากฏเฉพาะสมาชิก approved — ยืนยันจากโค้ด+RLS
7. [x] Like/Comment count อัปเดตถูกต้อง — ยืนยัน optimistic update pattern เดียวกับ Drop ที่ผ่าน QA มาแล้ว
8. [x] ปักหมุด → อยู่บนสุดเสมอ — มี regression test จริง (`club_posts_tab_test.dart` "ปักหมุด label")
9. [x] Owner/Admin/Moderator ลบโพสต์คนอื่นได้ Member ลบได้แค่ตัวเอง — ยืนยัน RLS delete policy ตรงตาม spec
10. [x] Owner/Admin ลบ/แบนได้ Moderator ทำได้เฉพาะทั่วไป — ยืนยัน `remove_club_member`/`ban_club_member` RPC + มี regression test ครบ 11 เคส (`club_members_tab_test.dart`)
11. [x] Owner แต่งตั้ง Admin/Moderator ได้ Admin แต่งตั้งได้แค่ Moderator — ยืนยัน `set_club_member_role` RPC + red→green proof อิสระ (ดูด้านล่าง)
12. [x] เปลี่ยน Privacy โดย Owner/Admin ได้จริง — มี regression test จริง (`club_page_test.dart` More menu)
13. [x] แก้ไขข้อมูล Club โดย Owner/Admin ได้จริง — ยืนยัน `EditClubInfoScreen` + `updateClubInfo` gated โดย `canManageClub`
14. [x] เขียน/แก้กฎ Club แสดงถูกต้อง — ยืนยัน `ClubAboutTab`
15. [x] ออกจาก Club ได้ (ยกเว้น Owner) หลังออกไม่เห็นโพสต์ — ยืนยัน RLS delete policy + post-visibility gate เดียวกับข้อ 5
16. [x] Drop/Pop/Home/Follow/Profile/Search/Notification เดิมไม่มี regression — `flutter test` เต็ม 148/148 ผ่าน (รันเองอิสระ 2 ครั้ง รวม 124 เทสต์เดิมทั้งหมด)

### Red→Green Regression Proof (ทำเองอิสระ 2 จุด ไม่เชื่อคำอธิบายจาก Coding Output)

**จุดที่ 1 — Privilege escalation (Admin แต่งตั้ง Admin)**: ทำซ้ำ reproduction steps เดียวกับที่ Coding รายงาน (เพิ่ม `_MemberAction('ตั้งเป็น Admin', ...)` เข้า branch ของ Admin viewer ใน `_actionsFor`) → รัน `club_members_tab_test.dart --plain-name "never sees"` → **FAIL จริง** ตรงกับที่ Coding รายงาน → revert → รันเต็มไฟล์ **PASS ทั้ง 11 เทสต์**

**จุดที่ 2 — Post-visibility gating (ทำทิศตรงข้ามจากที่ Coding ทดสอบ)**: Coding ทดสอบทิศ "non-member เห็นเนื้อหาได้" (เปลี่ยน `_isMember` เป็น `=> true` เสมอ) — QA ทดสอบทิศตรงข้าม: เปลี่ยน `_isMember` เป็น `=> false` เสมอ (จำลองบั๊กที่สมาชิกจริงถูกบล็อกผิด ๆ ไม่เห็นโพสต์ทั้งที่ join แล้ว) → รัน `club_posts_tab_test.dart --plain-name "an approved member sees"` → **FAIL จริง** (`Expected: exactly one matching candidate, Actual: Found 0 widgets with text "สวัสดีชาว Club"`) → revert → รันเต็มไฟล์ + `flutter test` ทั้งโปรเจกต์ **PASS 148/148** — ยืนยันว่า gate ทำงานถูกต้องทั้งสองทิศทาง ไม่ใช่แค่ทิศเดียวที่ Coding ลองแล้ว

### Security Findings
- **`club_role()` เป็น single source of truth**: ยืนยันทุก RLS policy/RPC/storage policy ที่เกี่ยวกับ Club เรียกผ่านฟังก์ชันนี้ทั้งหมด ไม่มี policy ไหนเขียน EXISTS subquery ตรงๆ แยกกันเอง (ลดความเสี่ยง logic ไม่ตรงกันระหว่างจุด)
- **RPC ทั้ง 5 ตัว re-derive role ของผู้เรียกเองจาก `club_role(p_club_id, auth.uid())` ไม่เชื่อค่าจาก client**: ยืนยันครบทุกตัว ไม่มีตัวไหนรับ `p_caller_role` เป็น parameter จาก client เลย
- **NULL-safety ของเงื่อนไข permission**: ตรวจ `approve_club_member`/`reject_club_member` ใช้ `coalesce(club_role(...), '') not in (...)` ป้องกัน `null not in (...)` ที่จะ evaluate เป็น NULL (ไม่ใช่ true) แล้วปล่อยให้คนแปลกหน้าผ่านไปเงียบๆ — ยืนยันว่าถ้าไม่ coalesce จริงจะเป็นช่องโหว่จริง (คนที่ไม่ใช่สมาชิกเลยเรียก approve ได้) — Coding ป้องกันไว้ถูกต้องแล้ว ส่วน `set_club_member_role`/`remove_club_member`/`ban_club_member` ใช้ pattern อื่น (positive-match branch + `else raise`) ที่ปลอดภัยจาก NULL อยู่แล้วโดยไม่ต้อง coalesce (NULL ไม่ match branch บวกใดๆ จึงตกไป else เสมอ) — ตรวจสอบ logic ทั้งสอง pattern ถูกต้องจริง
- **`club_members` ไม่มี raw UPDATE policy เลย**: ยืนยันจากการอ่าน schema.sql ทั้ง section ไม่พบ `for update` policy บนตารางนี้เลยแม้แต่ตัวเดียว — client พยายาม `update()` role/status ตรงๆ ผ่าน PostgREST จะถูก RLS ปฏิเสธเสมอ (ไม่มี policy = deny by default เมื่อ RLS enabled)
- **`club_members` insert policy ผูก status กับ privacy จริง**: อ่าน WITH CHECK ยืนยัน `status='approved'` อนุญาตเฉพาะเมื่อ club เป็น `'public'`, `status='pending'` เฉพาะเมื่อเป็น `'private'` — ทดลองไล่ logic เคส Private club: client พยายาม insert `status='approved'` ตรงๆ จะไม่ผ่านเงื่อนไข exists-subquery (เพราะ subquery กรอง `privacy = 'public'` เท่านั้น) → insert ถูกปฏิเสธจริง ป้องกัน privilege escalation "self-approve เข้า Private club" ได้จริง
- **`clubs_prevent_owner_id_change` trigger**: ยืนยัน `before update` + เทียบ `new.owner_id <> old.owner_id` แล้ว raise exception — ปิดช่องที่ Owner/Admin ใช้สิทธิ์ update `clubs` ปกติ (Edit Info) แอบเปลี่ยน `owner_id` ได้ — เป็นจุดที่ Coding คิดเพิ่มเองนอกเหนือจาก spec ต้นฉบับ ตรวจแล้วเป็นการป้องกันที่ถูกต้องและจำเป็นจริง (ถ้าไม่มี trigger นี้ RLS update policy เดิมของ `clubs` จะปล่อยให้ Admin ตั้งตัวเองเป็น Owner ได้ผ่าน update ปกติ)
- **Storage bucket `club-media` (`public: false`)**: ยืนยัน select policy แยกตาม `array_length(storage.foldername(name), 1)` ถูกต้อง (=1 → cover/icon เปิดให้ authenticated ทุกคน, >1 → ต้องมี `club_role(...) is not null`) — insert policy คู่กันก็ถูกต้อง (cover/icon เฉพาะ owner/admin, รูปโพสต์เฉพาะสมาชิก approved) — ยืนยันว่า flow การอัปโหลด cover/icon (สร้าง Club ก่อน → trigger สร้าง owner membership ทันที → ค่อยอัปโหลด) ไม่มี race condition เพราะ insert ของ Postgres commit ก่อนที่ client จะเรียก storage upload request แยกต่างหากเสมอ
- **Signed URL แทน public URL**: ยืนยัน `ClubRepository`/`ClubPostRepository` เก็บ storage path ใน DB ไม่ใช่ display URL และ mint signed URL (`createSignedUrl`, TTL 3600 วินาที) สดใหม่ทุกครั้งที่อ่าน — ถูกต้องตามที่ bucket เป็น non-public เพราะการ cache public URL ถาวรจะ bypass RLS ทันทีที่ URL หลุดออกไป
- **`club_posts_have_content` CHECK ไม่ถูก bypass ได้ผ่าน multi-image upload flow**: ตรวจ `createPost()` อัปโหลดรูปก่อน insert แถว (ไม่ใช่ insert แถวว่างก่อนแล้วค่อย update) — ยืนยันว่าไม่มี window ที่แถวว่างเปล่าถูก insert สำเร็จชั่วคราว
- ไม่พบ secret exposure ใหม่ใน diff

### Regression กับ Drop/Pop/Home/Follow/Profile/Search/Notification เดิม
`flutter test` เต็ม 148/148 ผ่าน ครอบคลุมทุก feature เดิมทั้งหมด (124 เทสต์เดิม + 24 ใหม่) — จุดที่แก้ของเดิมมี 2 จุด: (1) `home_feed_screen.dart` เพิ่ม `ClubSection` ระหว่างแถวบนสุดกับ Feed — มี regression test คุ้มครอง (Home feed เดิมยังแสดง/ทำงานถูกต้องทุกจุด) (2) `home_feed_screen_test.dart`'s `scrollUntilVisible` เปลี่ยนจาก `find.byType(Scrollable).first` เป็นระบุ Scrollable เจาะจงผ่าน Key — ตรวจแล้วเป็นการแก้ test ให้ตรงเป้าหมายเดิม ไม่ใช่การลด coverage (ScrollUntilVisible เคยพึ่ง ".first" ซึ่งตอนนี้ชี้ผิด Scrollable เพราะ `ClubSection` เพิ่ม horizontal ListView ใหม่ที่มาก่อนในทรี — แก้ให้ระบุ Scrollable ที่ถูกต้องแทนคือ fix ที่ถูกต้อง ไม่ใช่ workaround)

```
Passed: 148/148 (`flutter test`, รันเองอิสระ 2 ครั้ง — ครั้งแรกยืนยันตัวเลขจาก Coding Output, ครั้งที่สองหลัง red→green proof ทั้งสองจุดเพื่อยืนยัน restore ถูกต้อง)
Failed: 0
Severity: Minor เดียว (ผู้ใช้ที่ถูกแบนพยายาม join ซ้ำ เห็นข้อความ error ทั่วไป "เข้าร่วม Club ไม่สำเร็จ" แทนข้อความเฉพาะว่าถูกแบน — ปลอดภัย ไม่ crash ไม่มีช่องโหว่ security เพราะ unique constraint บล็อกไว้ที่ DB อยู่แล้วจริง แค่ UX ไม่ได้บอกเหตุผลตรงจุด — ไม่ถูกระบุไว้ใน Product/Design spec เลยและไม่กระทบ Acceptance Criteria ข้อไหน)

Recommendation: เพิ่ม error message เฉพาะสำหรับกรณี "ถูกแบน" ในอนาคตเป็น fast-follow (ไม่ block การอนุมัติรอบนี้)

Final Status: PASS
```

Handoff: อนุมัติ WYN-014 (Club Core) — ย้ายเข้า `.wyn/tasks/approved/` และส่งต่อ AI Deploy & DevOps (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า) — WYN-015 (Club Discovery & Integration) ยังไม่เริ่ม รอ Founder ตัดสินใจคิวถัดไป
