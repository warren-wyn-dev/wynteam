# Product Task — WYN-014

Status: backlog
Owner: AI Product Manager (เสร็จ) → AI Design (ถัดไป)

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
