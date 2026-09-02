# Feature Request — WYN-100

Status: design complete (light pass), ready for AI Coding (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 7/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่มเมนู 3 ขีด (hamburger) + สร้างฟีเจอร์ "สร้าง Club" แบบเต็ม
Goal: ให้ผู้ใช้สร้าง Club ของตัวเองได้ และมีเมนูรวมฟีเจอร์ Club (สร้าง Club, Club ของเรา ฯลฯ)
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ตรงที่วงสีแดง อยากให้ใส่ 3 ขีด เพราะว่าจะเอาฟีเจอต่างๆไปอยู่ในนั้น เช่น สร้าง Club, Club ของเรา" — Founder ยืนยันให้ทำฟีเจอร์ "สร้าง Club" แบบเต็ม ไม่ใช่แค่เพิ่มปุ่มเมนูเฉยๆ
Requirements:
- เพิ่มไอคอนเมนู 3 ขีดที่มุมซ้ายบนหน้า Home (จุดที่ Founder วงไว้) เปิด drawer/menu รวมทางลัดฟีเจอร์ Club และรายการอื่นที่มีอยู่แล้ว (โปรไฟล์/Club ของฉัน/บันทึกไว้ ฯลฯ ตามเมนูที่มีอยู่แล้วในภาพหน้า 4)
- **สร้างฟีเจอร์ "สร้าง Club" แบบเต็มใหม่**: ฟอร์มสร้าง Club (ชื่อ, username, รูปโปรไฟล์ Club, คำอธิบาย, ตั้งค่าความเป็นส่วนตัว public/private), ระบบสมาชิก (เจ้าของ/ผู้ดูแล/สมาชิก), หน้าโพสต์ในนาม Club, การเชิญ/จัดการสมาชิก
- เชื่อมกับแท็บ "จาก Club ของคุณ" ที่มีอยู่แล้วในหน้า Home ให้ดึงโพสต์จาก Club ที่ผู้ใช้เป็นสมาชิกจริง
Acceptance Criteria:
- [ ] กดเมนู 3 ขีดเปิด drawer ที่มีทางลัด "สร้าง Club"/"Club ของฉัน"
- [ ] สร้าง Club ใหม่สำเร็จ มีหน้า Club, โพสต์ในนาม Club ได้, เชิญสมาชิกได้
- [ ] แท็บ "จาก Club ของคุณ" แสดงโพสต์จาก Club ที่เป็นสมาชิกจริง
Dependencies: ควรตรวจสอบว่ามีระบบ Club เดิมอยู่แล้วบางส่วนหรือไม่ (เห็นจากภาพมี "Wynos Club" ตัวอย่างอยู่แล้ว) ก่อนเริ่ม เพื่อไม่สร้างซ้ำ
Priority: สูง (ฟีเจอร์ใหญ่ที่สุดในรอบนี้ กระทบ data model มาก)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Club feature มีอยู่บางส่วนแล้ว (เห็น Wynos Club ในภาพตัวอย่าง) แต่ยังไม่มีทาง "สร้าง Club" เอง — เสี่ยงสร้างซ้ำซ้อนกับของเดิม | สูง | AI Product Manager ตรวจโค้ด/schema เดิมเรื่อง Club ให้ครบก่อนเขียน spec |
Recommendation: อนุมัติ (Founder ยืนยันแบบเต็ม) — เริ่ม Product spec ก่อนเป็นอันดับแรกเพราะใหญ่และมีผลกระทบมาก
Handoff: AI Product Manager ทำ spec เต็ม (ตรวจของเดิมก่อน) → AI Design → AI Coding → AI QA

## Product Full Spec Output (2026-09-02)

**พบว่าสมมติฐานที่ Founder ใช้ตัดสินใจ ("สร้างฟีเจอร์สร้าง Club แบบเต็ม") คลาดเคลื่อนจากความจริง** — ตรวจโค้ดยืนยันว่า **"สร้าง Club" มีอยู่แล้วครบเต็มรูปแบบตั้งแต่ WYN-014** (`CreateClubScreen`, ระบบสมาชิก 4 role, Admin system, โพสต์ในนาม Club, "จาก Club ของคุณ" บน Home — ทั้งหมดทำงานจริงแล้ว ผ่าน QA รอบ 1 แล้ว) สิ่งที่ยังไม่มีจริงคือแค่ 2 อย่าง: (1) ไอคอน hamburger ที่ Home ไม่มีเลย (ตั้งใจถอดออกตั้งแต่ WYN-031 ด้วยเหตุผลที่หมดอายุแล้ว) (2) Side Menu (Drawer) ที่มีอยู่แล้ว ไม่มีทางลัด "สร้าง Club" — สโคปที่แท้จริงจึงเล็กลงมากเหลือแค่ 2 จุดนี้ ไม่ใช่การสร้างระบบ Club ใหม่

**นอกสโคปที่ปรับใหม่ (ต้องแจ้ง Founder)**: ระบบ Club username/handle และระบบเชิญสมาชิกเฉพาะเจาะจง (invite-by-user) — ไม่มีอยู่จริงและไม่ถูกพูดถึงตรงๆ ใน Problem quote ของ Founder ข้อ 7 (พูดแค่ "สร้าง Club, Club ของเรา" ในเมนู) ถ้าต้องการเพิ่มควรเป็น task แยก

**ต้อง ping Founder ก่อนเข้า Design/Coding จริง** (ไม่ใช่แค่รายละเอียดทางเทคนิค — เป็นการแก้ premise ของการตัดสินใจเดิม): "ตรวจโค้ดแล้วพบว่าระบบสร้าง Club มีอยู่ครบแล้วจริง งานที่เหลือจริงๆ คือแค่เพิ่มไอคอน 3 ขีดที่ Home ให้เปิดเมนูที่มีอยู่แล้ว + เพิ่มทางลัด 'สร้าง Club' เข้าไป จะเดินหน้าแบบนี้เลยได้ไหม หรือมีฟีเจอร์ Club อื่นที่อยากได้เพิ่มจริงๆ (เช่น username/invite-by-user)"

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-100-club-menu-create-club.md`

Handoff: รอ Founder ยืนยันสโคปที่ปรับใหม่ก่อน → ส่งต่อ AI Design (`/design`) แบบเบา (ไม่ต้องออกแบบหน้าจอใหม่ แค่ยืนยันตำแหน่ง/สไตล์ไอคอน hamburger)

## Design Output (2026-09-02)

เขียน design spec (light pass) เสร็จแล้วที่ `.wyn/docs/design/wyn-100-club-menu-create-club.md` — ยืนยันตามที่ Product spec ขอ: (1) ไอคอน hamburger บน Home **ใช้ไอคอน/สไตล์เดียวกับที่มีอยู่แล้วจริงใน `notification_list_screen.dart`เป๊ะ** (`Icons.menu`, size 20, สี `WynColors.ink`, tooltip "เมนู") แทนที่ `SizedBox(width: 48)` เดิม ตำแหน่งเดิมตรงกับที่ Founder วงไว้ในภาพ PDF อยู่แล้ว (2) แถวใหม่ "สร้าง Club" ใน `SideMenu` reuse `_MenuRow` widget เดิม (icon `Icons.add_circle_outline`) วางเหนือ "Club ของฉัน" ให้อยู่กลุ่มเดียวกัน — ทั้งสองจุด reuse component/pattern ที่มีอยู่แล้ว 100% ไม่มี component ใหม่ ไม่มี schema change ตรงตามที่ Product spec ประเมินว่างานเล็ก/เสี่ยงต่ำ

Handoff: ส่งต่อ AI Coding (`/code`)

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — งานใหม่ตรงตามสโคปที่ Design ยืนยันไว้ (light pass, reuse 100%)

การเปลี่ยนแปลง:
1. **`app/lib/features/home/presentation/home_feed_screen.dart`**: เพิ่ม `_scaffoldKey = GlobalKey<ScaffoldState>()` (มิเรอร์ `notification_list_screen.dart` เป๊ะ), เพิ่ม `key: _scaffoldKey` + `drawer: SideMenu(...)` เข้า `Scaffold` (ผูก repository ที่ `HomeFeedScreen` มีอยู่แล้วทุกตัว ไม่ต้อง thread dependency ใหม่ — `profileRepository`/`followRepository`/`dropRepository`/`popRepository`/`savedRepository`/`clubRepository`/`clubPostRepository` มีครบในมืออยู่แล้ว), แทนที่ `const SizedBox(width: 48)` ใน `_buildHeader()` ด้วย `IconButton(icon: Icons.menu, size: 20, color: WynColors.ink, tooltip: 'เมนู', onPressed: () => _scaffoldKey.currentState?.openDrawer())` ตรงตาม Design spec เป๊ะ — อัปเดต doc comment เดิมที่เคยบอกว่า "hamburger ตั้งใจไม่ใส่เพราะไม่มีเมนูให้เปิด" ให้ตรงกับความจริงใหม่
2. **`app/lib/features/root/presentation/side_menu.dart`**: import `create_club_screen.dart`, เพิ่ม `_openCreateClub()` (มิเรอร์ `_openMyClubs()` เป๊ะ — pop แล้ว push `CreateClubScreen(clubRepository:..., clubPostRepository:...)`), เพิ่มแถว `_MenuRow(icon: Icons.add_circle_outline, label: 'สร้าง Club', onTap: _openCreateClub)` เหนือ "Club ของฉัน" ตามลำดับที่ Design ระบุ (โปรไฟล์ → สร้าง Club → Club ของฉัน → บันทึกไว้) — อัปเดต doc comment เดิมที่บอกว่า drawer "เปิดได้จาก Notification เท่านั้น" ให้ตรงกับความจริงใหม่ (เปิดได้จาก Home ด้วย)

Files Changed:
- `app/lib/features/home/presentation/home_feed_screen.dart`
- `app/lib/features/root/presentation/side_menu.dart`
- `app/test/home_feed_screen_test.dart` — เพิ่มเทส "the hamburger icon opens the SideMenu drawer" (แตะไอคอน `Icons.menu` แล้วยืนยันเห็น "สร้าง Club"/"Club ของฉัน" ใน drawer ที่เปิดมา)
- `app/test/side_menu_test.dart` — เพิ่มเทส "tapping 'สร้าง Club' opens CreateClubScreen (WYN-100)"

Reason: Founder ข้อ 7/28 (สโคปปรับใหม่ตามที่ยืนยันแล้วใน DECISIONS.md 2026-09-02) — เพิ่มไอคอน hamburger บน Home + ทางลัด "สร้าง Club" ใน `SideMenu` ที่มีอยู่แล้ว (ระบบสร้าง Club เต็มรูปแบบมีอยู่แล้วตั้งแต่ WYN-014 ไม่ต้องสร้างใหม่)

Tests:
- `flutter analyze`: สะอาด (No issues found!)
- `flutter test`: **919/919 ผ่านหมด** (เพิ่มจาก 917 เดิม — เพิ่มสุทธิ 2 เทสใหม่)
- Red→green พิสูจน์จริง: รันเทสทั้งสองไฟล์ก่อนแก้โค้ด (เทสใหม่ยืนยัน fail จริงเพราะยังไม่มี `Icons.menu`/drawer บน Home และยังไม่มีแถว "สร้าง Club" ใน `SideMenu`) แก้โค้ดแล้วรันซ้ำผ่านหมดทั้งไฟล์

Build: ไม่ได้รัน `flutter build` จริง (ไม่มี Android SDK/Xcode ใน session นี้) — ไม่แตะ schema/backend เลย เป็นการเปลี่ยน UI ล้วนๆ

Known Issues:
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator) — โดยเฉพาะ (1) wordmark "WYNOS" ยังอยู่กึ่งกลางจริงหลังแทนที่ `SizedBox(width: 48)` ด้วย `IconButton` ที่ความกว้างจอต่างๆ (360-430px ตาม Design spec Responsive Behavior) (2) swipe-from-edge เปิด Drawer ไม่ชนกับ gesture อื่นของ Home (feed-mode tab horizontal scroll) ตาม Risk R2 ของ Product spec — ทดสอบใน widget test ทำได้แค่ tap ไอคอนตรงๆ ไม่ได้ทดสอบ edge-swipe gesture จริง
- ไม่ได้เพิ่ม regression test แยกสำหรับ "Club ของฉัน"/"บันทึกไว้"/"โปรไฟล์" ใน Drawer เดิมยังทำงานปกติ — ของเดิมมีเทสอยู่แล้วครบใน `side_menu_test.dart` (ไม่ได้แตะ/ลบเทสเดิมเลย ยังผ่านหมดตามที่รายงานด้านบน) จึงไม่ต้องเขียนซ้ำ

Handoff: ส่งต่อ AI QA & Security — (1) ยืนยัน wordmark กึ่งกลางจริงที่ทุกความกว้างจอบนอุปกรณ์จริง/เบราว์เซอร์ (2) ยืนยัน edge-swipe ของ Home ไม่ชนกับ Drawer ใหม่ (3) ยืนยัน "สร้าง Club" จาก Home ไปจบที่ `CreateClubScreen` ได้จริงและ flow สร้าง Club เดิม (WYN-014) ยังทำงานถูกต้องทุกจุด (4) ยืนยัน Drawer เปิดได้จากทั้ง Home และ Notification โดยไม่มี regression กับจุดเดิม
