# Design Spec — WYN-100: Hamburger Icon บน Home + ทางลัด "สร้าง Club" ใน SideMenu (Light Pass)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-100.md`, `.wyn/docs/product/wyn-100-club-menu-create-club.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/home/presentation/home_feed_screen.dart` (`_buildHeader()` บรรทัด ~677-705, `const SizedBox(width: 48)` ที่ต้องถูกแทนที่), `app/lib/features/notification/presentation/notification_list_screen.dart` (บรรทัด ~584-588, precedent ของ hamburger icon ที่มีอยู่แล้วจริงในระบบ), `app/lib/features/root/presentation/side_menu.dart` (`SideMenu`/`_MenuRow` ที่มีอยู่แล้ว)
Design system: `WynColors.ink`/`WynSpacing` เดิม — ไม่มีสีใหม่ (ตรวจ `app/lib/core/design/wyn_colors.dart` แล้ว — งานนี้ reuse ค่าที่ `notification_list_screen.dart` ใช้อยู่แล้วเป๊ะ)

> **สโคปยืนยันแล้ว**: Founder ยืนยันสโคปเล็กนี้แล้ว (`.wyn/company/DECISIONS.md`, 2026-09-02 — "Founder ยืนยันให้เดินหน้าตามสโคปจริงนี้") — ระบบ "สร้าง Club" มีอยู่ครบแล้วตั้งแต่ WYN-014 งานที่เหลือจริงคือแค่ 2 จุดเล็กด้านล่าง ตามที่ Product spec ระบุ ตรงกับที่ Product spec's Handoff ขอไว้ว่า **"แค่ยืนยันตำแหน่ง/สไตล์ไอคอน hamburger ไม่ต้องออกแบบหน้าจอใหม่"** — เอกสารนี้จึงสั้นตามสัดส่วนงานจริง ไม่ออกแบบใหม่เกินความจำเป็น

---

## Screen 1 — ไอคอน Hamburger บน Home

**Purpose:** เปิด `SideMenu` (Drawer) ที่มีอยู่แล้วจาก Home — ปัจจุบัน Home ไม่มีทางเข้าถึง Drawer นี้เลย มีแค่ Notification เท่านั้น

**User Flow:** ผู้ใช้เปิด Home → เห็นไอคอน 3 ขีดมุมซ้ายบน (แทนที่ `SizedBox(width: 48)` เดิม) → แตะ → `SideMenu` เลื่อนเข้ามาจากซ้าย (พฤติกรรม `Drawer` มาตรฐานของ Flutter) → เหมือนกดจากหน้า Notification ทุกประการ

**Components:** **ยืนยันให้ใช้ไอคอน/สไตล์เดียวกับที่มีอยู่แล้วจริงใน `notification_list_screen.dart` เป๊ะ ไม่ประดิษฐ์ใหม่**:
```dart
IconButton(
  icon: const Icon(Icons.menu, size: 20, color: WynColors.ink),
  tooltip: 'เมนู',
  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
)
```
- ตำแหน่ง: แทนที่ `const SizedBox(width: 48)` ที่มุมซ้ายของ `_buildHeader()`'s `Row` (บรรทัด 693 ของ `home_feed_screen.dart`) — **ตำแหน่งเดิมตรงกับที่ Founder วงไว้ในภาพ PDF อยู่แล้ว** (มุมซ้ายบน ข้าง wordmark "WYNOS") ไม่ต้องย้ายที่ไหน
- ขนาด: `IconButton` มาตรฐาน (~48×48 touch target ตาม Material default) — เดิม `SizedBox(width: 48)` ถูกใช้แค่ "ถ่วงน้ำหนัก" ให้ wordmark อยู่กึ่งกลาง ตอนนี้ไอคอนจริงเข้ามาแทนที่ทำหน้าที่ถ่วงน้ำหนักแบบเดียวกันไปในตัว (ความกว้างใกล้เคียงกัน ~48px) — **ต้องทดสอบว่า wordmark ยังอยู่กึ่งกลางจริงหลังเปลี่ยน** (Acceptance Criteria ของ Product spec ระบุไว้ตรงๆ)

**Interactions:** แตะ → เปิด Drawer (มาตรฐาน Flutter — swipe-from-edge ก็เปิดได้ตามพฤติกรรม default ของ `Drawer`, ต้องเช็คว่าไม่ชนกับ gesture อื่นของ Home ตาม Risk R2 ของ Product spec เช่น swipe ระหว่าง feed-mode tab)

**States:** ไม่มี state พิเศษ — ปุ่มเปิด/ปิด Drawer เป็น stateless action

**Responsive Behavior:** ต้องคง wordmark กึ่งกลางที่ทุกความกว้างจอ (360-430px) เหมือนที่ Product spec Acceptance Criteria ระบุ — ถ้า `IconButton` (48px) กับ chat icon ฝั่งขวา (ก็ ~48px ตาม comment เดิม "Balances the chat IconButton's own ~48px width") ไม่เท่ากันเป๊ะจน wordmark เบี้ยว ให้ AI Coding ปรับ padding เล็กน้อยเพื่อความสมมาตร (ไม่ใช่จุดตัดสินใจ pixel-perfect ของเอกสารนี้)

**Accessibility:** `tooltip: 'เมนู'` (ตรงกับ pattern เดิมของ Notification เป๊ะ) — Semantics label มาตรฐานของ `IconButton`+`tooltip` เพียงพอ ไม่ต้องเพิ่ม `Semantics` wrapper แยก

**Design Rules:** **ห้ามออกแบบไอคอน/สไตล์ใหม่** — ใช้ `Icons.menu`/size 20/สี `WynColors.ink`/tooltip "เมนู" ตรงตาม precedent ที่มีอยู่แล้วเป๊ะ เพื่อความสม่ำเสมอของ hamburger icon ทั้งสองจุดในแอป (Home + Notification)

**Handoff:** AI Coding — เพิ่ม `GlobalKey<ScaffoldState>` ให้ `HomeFeedScreen` (มิเรอร์ `notification_list_screen.dart`'s `_scaffoldKey` เป๊ะ) + `drawer: SideMenu(...)` ผูก dependency ครบ (`profileRepository`/`followRepository`/`dropRepository`/`popRepository`/`savedRepository`/`clubRepository`/`clubPostRepository`) ตามที่ `SideMenu`'s constructor ต้องการอยู่แล้ว — ตรวจสอบว่า `HomeFeedScreen` มี repository เหล่านี้ครบในมือแล้วหรือต้อง thread เพิ่มจาก parent

---

## Screen 2 — แถวใหม่ "สร้าง Club" ใน `SideMenu`

**Purpose:** เพิ่มทางลัดสร้าง Club เข้าไปในเมนูที่มีอยู่แล้ว

**User Flow:** เปิด Drawer (จาก Screen 1 หรือจาก Notification เดิม) → เห็นแถว "สร้าง Club" เพิ่มเข้ามา → แตะ → Drawer ปิด → เปิด `CreateClubScreen` (หน้าเดิมที่มีอยู่แล้วครบ ตั้งแต่ WYN-014)

**Components:** **reuse `_MenuRow` widget ที่มีอยู่แล้วใน `side_menu.dart` เป๊ะ ไม่ประดิษฐ์ใหม่**:
```dart
_MenuRow(icon: Icons.add_circle_outline, label: 'สร้าง Club', onTap: _openCreateClub),
```
- ตำแหน่ง: **เหนือ** "Club ของฉัน" (จัดกลุ่ม "สร้าง"/"ของฉัน" ให้อยู่ติดกันเป็นหมวด Club เดียวกัน ตาม Product spec) — ลำดับใหม่ของ 4 แถว: โปรไฟล์ → **สร้าง Club** → Club ของฉัน → บันทึกไว้
- icon: `Icons.add_circle_outline` (สื่อความหมาย "สร้างใหม่" ตรงไปตรงมา ตรงกับ icon set แบบ `_outlined` ที่ทั้งแอปใช้สม่ำเสมอ)

**Interactions:** แตะ → `Navigator.of(context).pop()` (ปิด Drawer ก่อน) → `Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateClubScreen(...)))` — **มิเรอร์ `_openMyClubs()`/`_openSaved()` ที่มีอยู่แล้วในไฟล์เดียวกันทุกประการ** (pop-then-push 2 บรรทัด)

**States:** ไม่มี state พิเศษ — `CreateClubScreen` เดิมจัดการ `RestrictionBanner`/validation ของตัวเองอยู่แล้วครบ (ตาม Product spec Edge Case 2)

**Responsive Behavior:** ไม่มีอะไรใหม่ — แถวเดียวกับ `_MenuRow` อื่นๆ ที่ทดสอบผ่านแล้ว

**Accessibility:** `_MenuRow` เดิมไม่มี `Semantics` wrapper พิเศษ (ใช้ text label ตรงๆ ผ่าน `Text` widget) — คงพฤติกรรมเดิมเหมือน "Club ของฉัน"/"บันทึกไว้" ทุกประการ ไม่ต้องเพิ่มอะไรพิเศษให้แถวใหม่นี้ต่างจากแถวเดิม

**Design Rules:** ใช้ `_MenuRow` เดิมเป๊ะ ห้ามสร้าง widget ใหม่สำหรับแถวนี้

**Handoff:** AI Coding — เพิ่ม `_openCreateClub()` method ใน `_SideMenuState` (มิเรอร์ `_openMyClubs()` เป๊ะ) + เพิ่ม `_MenuRow` 1 แถวในตำแหน่งที่ระบุ — **ต้องส่ง `clubPostRepository` เพิ่มเข้า `CreateClubScreen`** (constructor ต้องการทั้ง `clubRepository`+`clubPostRepository` อยู่แล้วตาม Product spec — `SideMenu` มี `clubPostRepository` อยู่ในมือแล้วจาก constructor ปัจจุบัน ไม่ต้องเพิ่ม dependency ใหม่)

---

## Handoff รวม

ส่งต่อ **AI Coding** (`/code`) — งานนี้เล็กและเสี่ยงต่ำ (ตามที่ Product spec ประเมินไว้แล้ว) ไม่มี schema change, ไม่มี component ใหม่ ทั้งสองจุดล้วน reuse widget/pattern ที่มีอยู่แล้วในระบบ 100% — regression หลักที่ QA ต้องตรวจ: "Club ของฉัน"/"บันทึกไว้"/"โปรไฟล์" ใน Drawer เดิมยังทำงานปกติ, "จาก Club ของคุณ" บน Home ยังทำงานปกติ, gesture edge-swipe ของ Home ไม่ชนกับ Drawer ใหม่ (Risk R2 ของ Product spec)
