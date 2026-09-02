# Product Full Spec — WYN-100

Status: full spec complete (2026-09-02) — ready for AI Design (สโคปเล็กลงมากจากที่ backlog เดิมสมมติไว้ — อ่าน Problem section ก่อน)
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` ข้อ 7/28, `.wyn/tasks/backlog/WYN-100.md`, `.wyn/company/DECISIONS.md` (2026-09-02, คำตอบข้อ 3/4)

Feature: เมนู 3 ขีด (hamburger) ที่หน้า Home → เปิด Side Menu ที่มีอยู่แล้ว + เพิ่มทางลัด "สร้าง Club" เข้าไปใน Side Menu นั้น

Goal: ให้ผู้ใช้เข้าถึงเมนูรวมทางลัด (สร้าง Club, Club ของฉัน ฯลฯ) จากมุมซ้ายบนของหน้า Home ได้ตามภาพที่ Founder วงไว้ใน PDF

Target User: ผู้ใช้ WYN Social ทุกคน

## Problem — คำเตือนสำคัญที่สุดของสเปกนี้: สโคปเดิมใน backlog เข้าใจผิดจากสถานะจริงของโค้ด

backlog เดิม (`.wyn/tasks/backlog/WYN-100.md`) เขียนไว้ว่า "Club core มีอยู่แล้วบางส่วนจาก WYN-014/015 **แต่ไม่มีทาง 'สร้าง Club' เอง**" และ Founder ตัดสินใจ (DECISIONS.md 2026-09-02) ให้ "สร้างฟีเจอร์ 'สร้าง Club' แบบเต็ม" โดยอิงความเข้าใจนั้น

**ตรวจโค้ดจริงแล้วพบว่าความเข้าใจนี้ผิด** — ฟีเจอร์ "สร้าง Club" **มีอยู่แล้วครบเต็มรูปแบบ** ตั้งแต่ WYN-014 (2026-08 ที่ผ่านมา, สถานะ `approved`, ผ่าน QA รอบ 1 แล้ว):

- `CreateClubScreen` (`app/lib/features/club/presentation/create_club_screen.dart`) — ฟอร์มสร้าง Club ครบ: ชื่อ, คำอธิบาย, รูปปก, หมวดหมู่, privacy (สาธารณะ/ส่วนตัว) — เขียนแล้ว ทำงานจริง ผูกกับ `ClubRepository.createClub()` จริง
- เข้าถึงได้แล้ววันนี้ผ่านปุ่ม "+ สร้าง Club" ใน `ClubSection` (widget ที่แสดงอยู่บน Home feed อยู่แล้ว ระหว่างแถวบนสุดกับ Feed หลัก) และผ่าน `ExploreClubsScreen`
- ระบบสมาชิก 4 Role (Owner/Admin/Moderator/Member), Admin system, Pinned Post, Club Rules, โพสต์ในนาม Club (Text/รูปเดี่ยว/หลายรูป/Link) — **ครบทั้งหมดแล้ว** (ตาราง `clubs`/`club_members`/`club_posts`/`club_post_likes`/`club_post_comments`, 5 RPC function, storage bucket `club-media` แยกสิทธิ์ cover/icon กับรูปโพสต์)
- แท็บ "จาก Club ของคุณ" ในหน้า Home — ก็มีอยู่แล้วเช่นกัน (`FromYourClubsFeed` widget, ผูกกับ feed-mode toggle ใน `home_feed_screen.dart`) ดึงโพสต์จาก Club ที่เป็นสมาชิกจริงตาม RLS ของ `club_posts`

**สิ่งที่ตรวจแล้วว่ายังไม่มีจริงคือแค่ 2 อย่าง**:
1. **ไม่มีไอคอน 3 ขีด (hamburger) ที่หน้า Home เลย** — ตรวจ `home_feed_screen.dart` บรรทัด 679-686 พบ doc comment ที่ตั้งใจ**ไม่ใส่**ไอคอนนี้ไว้ตั้งแต่ WYN-031 ("The reference's hamburger is left out on purpose rather than added as a dead button: this app's destinations already all live in the Bottom Nav...and there's no second menu for a hamburger here to open") — เหตุผลนั้นหมดอายุแล้วเพราะตอนนี้มี `SideMenu` (Drawer) จริงที่สร้างไว้แล้วสำหรับหน้า Notifications (`notification_list_screen.dart`) แต่ **Home ไม่มีทางเข้าถึง Drawer เดียวกันนี้เลย** — Founder ตอนนี้ขอ hamburger ที่ Home ตรงๆ (ข้อ 7 วงตำแหน่งไว้ชัดในภาพ) ซึ่ง override เหตุผลเดิมที่เคยตั้งใจไม่ใส่
2. **`SideMenu` (Drawer ที่มีอยู่แล้ว) ไม่มีทางลัด "สร้าง Club"** — ตรวจ `app/lib/features/root/presentation/side_menu.dart` มีแค่ 3 แถว: โปรไฟล์ / Club ของฉัน / บันทึกไว้ — ไม่มี "สร้าง Club" ตามที่ Founder อยากให้อยู่ในเมนูนี้ ("จะเอาฟีเจอต่างๆไปอยู่ในนั้น เช่น สร้าง Club, Club ของเรา")

**สรุป**: สโคปที่แท้จริงของ WYN-100 คือ **เพิ่มไอคอน hamburger ที่ Home + เพิ่ม 1 แถวเมนูใหม่ ("สร้าง Club") ใน Drawer ที่มีอยู่แล้ว** ไม่ใช่การสร้างระบบ Club/Create Club ใหม่ทั้งหมดตามที่ backlog เดิมสื่อไว้ — งานเล็กลงมากจากที่ Founder ตัดสินใจไว้บนความเข้าใจที่คลาดเคลื่อน **ต้องแจ้ง Founder เรื่องนี้อย่างชัดเจนก่อนเริ่ม Design/Coding จริง** (ดู Handoff) เพราะเป็นการแก้ไข assumption ที่ Founder ใช้ตัดสินใจไปแล้ว ไม่ใช่แค่รายละเอียดทางเทคนิคเล็กน้อย

## Data Model Impact
**ไม่มี** — ไม่ต้องแก้ schema เลยสำหรับสโคปที่แท้จริง (hamburger icon + เมนูใหม่ 1 แถวเป็น UI-only, ผูกกับ `CreateClubScreen`/`ClubRepository` ที่มีอยู่แล้วทั้งหมด)

## Requirements (UI/UX)

**1. เพิ่มไอคอน hamburger ที่ Home** (`home_feed_screen.dart`, `_buildHeader()`)
- แทนที่ `SizedBox(width: 48)` (ตัวถ่วงน้ำหนักด้านซ้ายที่ใช้แค่จัด wordmark ให้อยู่กึ่งกลาง) ด้วย `IconButton(icon: Icons.menu)` เปิด `Scaffold.of(context).openDrawer()`
- ต้องเพิ่ม `drawer: SideMenu(...)` ให้ `Scaffold` ของ `HomeFeedScreen` (ปัจจุบันยังไม่มี — เช็คจริงว่า `HomeFeedScreen` ใช้ `Scaffold` ของตัวเองหรือแชร์กับ `RootShell` แล้วผูก dependency (`profileRepository`/`followRepository`/`dropRepository`/`popRepository`/`savedRepository`/`clubRepository`/`clubPostRepository`) ให้ครบตาม constructor ของ `SideMenu` ที่มีอยู่แล้ว)
- Semantics label: "เมนู"

**2. เพิ่มแถว "สร้าง Club" ใน `SideMenu`**
- ตำแหน่ง: อยู่เหนือ "Club ของฉัน" (ให้ "สร้าง"/"ของฉัน" อยู่ติดกัน เป็นกลุ่ม Club) — icon `Icons.add_circle_outline`, label "สร้าง Club"
- กดแล้ว: ปิด Drawer ก่อน แล้ว push `CreateClubScreen` (เหมือน pattern `_openMyClubs()`/`_openSaved()` ที่มีอยู่แล้วในไฟล์เดียวกันทุกประการ) — ต้องส่ง `clubPostRepository` เพิ่มเข้า `CreateClubScreen` (constructor ต้องการทั้ง `clubRepository`+`clubPostRepository` อยู่แล้ว)

**3. ตรวจสอบ (ไม่ใช่สร้างใหม่) ว่า "จาก Club ของคุณ" ยังทำงานถูกต้อง** — เป็น regression check เท่านั้น ไม่ใช่ requirement ใหม่

## Edge Cases
1. **ผู้ใช้ไม่ได้เป็นสมาชิก Club ใดเลย กด hamburger → "สร้าง Club"**: ทำงานได้ปกติ (ไม่มีเงื่อนไขต้องเป็นสมาชิก Club มาก่อนถึงจะสร้างได้ — `CreateClubScreen` ไม่มีเงื่อนไขแบบนั้นอยู่แล้ว)
2. **บัญชีถูก Restrict (moderation)**: `CreateClubScreen` มี `RestrictionBanner` gate การสร้าง Club อยู่แล้ว (ปุ่ม "สร้าง Club" ถูก disable พร้อม Semantics label อธิบายเหตุผล) — ไม่ต้องทำอะไรเพิ่ม
3. **หน้าอื่นที่ยังไม่มี hamburger** (Search/Notification/Profile): backlog นี้ระบุแค่ตำแหน่งที่ Founder วงไว้คือ Home เท่านั้น — Notification มี Drawer อยู่แล้ว, หน้าอื่นไม่ได้ถูกร้องขอ ไม่เพิ่มเอง (ดู Out of Scope)

## Acceptance Criteria
- [ ] กดไอคอน 3 ขีดที่มุมซ้ายบนของ Home → Drawer (`SideMenu`) เปิดขึ้นมา
- [ ] ใน Drawer มีแถว "สร้าง Club" กดแล้วเปิด `CreateClubScreen` จริง
- [ ] สร้าง Club สำเร็จจากทางเข้านี้ → เหมือนสร้างผ่านปุ่มเดิมใน `ClubSection` ทุกประการ (Owner อัตโนมัติ, เปิด `ClubPage` ทันที)
- [ ] "Club ของฉัน"/"บันทึกไว้"/"โปรไฟล์" ที่มีอยู่แล้วใน Drawer ยังทำงานปกติ (regression)
- [ ] "จาก Club ของคุณ" บน Home ยังทำงานปกติ (regression — ไม่ใช่งานใหม่)
- [ ] wordmark "WYNOS" ยังอยู่กึ่งกลางหลังเพิ่ม hamburger (แทนที่ SizedBox ถ่วงน้ำหนักแล้วต้องไม่ทำให้ layout เพี้ยน)

## Dependencies
ไม่มี — ใช้ `SideMenu`/`CreateClubScreen`/`ClubRepository`/`ClubPostRepository` ที่มีอยู่แล้วทั้งหมด (WYN-014/015)

## Out of Scope (รอบนี้)
- **ระบบ "สร้าง Club" เอง — มีอยู่แล้วครบ ไม่ใช่ของใหม่** (นี่คือประเด็นหลักของสเปกนี้)
- Club username/handle (`@club-handle`) — ตรวจ schema แล้วไม่มีคอลัมน์นี้ใน `clubs` table วันนี้ (มีแค่ name/description/category/cover/rules/privacy) — backlog เดิมพูดถึง "username" แต่ Founder's Problem quote จริง (ข้อ 7) ไม่ได้พูดถึงเรื่องนี้เลย พูดแค่ "สร้าง Club, Club ของเรา" ในเมนู — ถ้า Founder ต้องการ Club handle สำหรับแชร์ลิงก์ในอนาคต ควรเป็น task แยก
- ระบบเชิญสมาชิกเฉพาะเจาะจง (invite-by-username/invite-link) — ตรวจแล้วไม่มีอยู่จริงวันนี้ มีแค่ join (public)/ส่งคำขอ+อนุมัติ (private) ซึ่งครอบคลุม "จัดการสมาชิก" ตามที่ Founder พูดถึงในภาพรวมแล้ว — "เชิญ" แบบระบุตัวคนไม่ได้ถูกพูดถึงตรงๆ ใน Problem quote ของ Founder ถ้าต้องการเพิ่มควรเป็น task แยก ไม่ผูกกับงานเมนู 3 ขีดนี้
- hamburger icon ที่หน้าจออื่นนอกจาก Home (Search/Profile) — Notification มีอยู่แล้ว, หน้าอื่นไม่ได้ถูกวงในภาพ
- Club ownership transfer / ลบ Club ทั้งกลุ่ม — นอกสโคปตั้งแต่ WYN-014 แล้ว ไม่เปลี่ยนแปลง

## Risks

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | **Founder ตัดสินใจ "ทำฟีเจอร์สร้าง Club แบบเต็ม" บนความเข้าใจที่คลาดเคลื่อนว่ายังไม่มี** — ถ้าไม่แจ้งกลับตรงๆ อาจทำให้ Founder คาดหวังงานใหญ่แต่ได้ผลลัพธ์เล็กกว่าที่คิดไว้มาก | สูง | แจ้ง Founder ชัดเจนก่อนเข้า Design/Coding (ดู Handoff) — ไม่ใช่การเปลี่ยนวิสัยทัศน์ แค่แก้ข้อเท็จจริงทางเทคนิคที่ใช้ประกอบการตัดสินใจ |
| R2 | เพิ่ม `drawer:` ให้ `HomeFeedScreen` อาจชนกับ gesture edge-swipe ที่มีอยู่แล้ว (เช่น swipe ระหว่าง feed-mode tab) | ต่ำ | ทดสอบ gesture ทั้งหมดหลังเพิ่ม Drawer ไม่ให้ conflict กับ TabBarView/PageView ที่มีอยู่ |

## Recommendation
เดินหน้าสโคปที่แท้จริง (hamburger + 1 แถวเมนูใหม่) — งานนี้เล็กและเสี่ยงต่ำมาก ไม่จำเป็นต้องผ่าน AI Design เต็มรูปแบบเหมือนงานอื่นในกลุ่มนี้ก็ได้ (แค่ 2 การเปลี่ยนแปลง UI เล็กๆ ที่ reuse component เดิมทั้งหมด) แต่**ต้องแจ้ง Founder เรื่องสโคปที่เล็กลงก่อน** เพราะเป็นการแก้ premise ของการตัดสินใจเดิม ไม่ใช่แค่รายละเอียด implementation

## Handoff
**ก่อนส่งต่อ Design/Coding**: ต้องมี popup/ข้อความแจ้ง Founder สั้นๆ สรุปว่า "ตรวจโค้ดแล้วพบว่าระบบ 'สร้าง Club' มีอยู่ครบแล้วจริงตั้งแต่ WYN-014 — งานที่เหลือจริงๆ ของข้อ 7 คือแค่เพิ่มไอคอน 3 ขีดที่ Home ให้เปิดเมนูที่มีอยู่แล้ว บวกเพิ่มทางลัด 'สร้าง Club' เข้าไปในเมนูนั้น จะเดินหน้าแบบนี้เลยได้ไหม หรือมีฟีเจอร์ Club อื่นที่ Founder อยากได้เพิ่มจริงๆ ที่ยังไม่มี (เช่น username/invite-by-user) — บอกมาได้ จะเปิดเป็น task แยก"

หลังจากนั้น ส่งต่อ **AI Design** (`/design`) แบบเบา (แค่ยืนยันตำแหน่ง/สไตล์ไอคอน hamburger ให้ตรง Design System เดิม ไม่ต้องออกแบบหน้าจอใหม่) → AI Coding → AI QA (regression หลัก: Club core เดิมทั้งหมดต้องไม่พัง)
