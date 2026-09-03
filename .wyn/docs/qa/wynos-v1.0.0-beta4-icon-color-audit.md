# WYNOS v1.0.0 Beta4 — Icon & Color Consistency Audit

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta4-master-implementation-j5lke8` — **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ขอบเขต: Beta4 §6 (Repost/Quote icons), §9 (Global UI Polish), §10 (Icon Color & UI State), §15 (UI State Consistency), §22 (Design System Audit)
> วิธีตรวจ: grep ทุก color literal และทุก icon call site ใน `app/lib` (250 ไฟล์) — ไม่ใช่แค่ 2 หน้าที่ Founder ระบุ ตามที่ §10 สั่ง ("ต้อง Audit ทั้งระบบ ไม่ใช่แก้เฉพาะสองหน้า")

---

## 0. ข้อสรุปที่สำคัญที่สุด

**ไม่มีสีไหน "ผิด" เลยแม้แต่สีเดียว** — สิ่งที่พบคือ *ค่าเดียวกันถูกเขียนซ้ำด้วยมือหลายที่* ซึ่งเป็นคนละปัญหาและอันตรายกว่า

ประวัติที่พิสูจน์ว่านี่ไม่ใช่ทฤษฎี: **WYN-076** (2026-09-01) — หัวใจสีแดงมี 10 ที่ 2 ที่ในนั้น drift ไปเป็น sapphire ไม่มีใครเห็น จนกระทั่ง Founder ส่ง screenshot มา และวิธีแก้คือไปตามแก้ค่าเดิมอีก 2 จุด

Beta4 จึง **ไม่เปลี่ยนค่าสีใดๆ ทั้งสิ้น** (§0 ห้าม "กำหนดสีใหม่เอง") แต่ตั้งชื่อให้ค่าที่กระจายอยู่ เพื่อให้สำเนาที่ 11 เป็นไปไม่ได้

---

## 1. สิ่งที่ grep เจอ

| ค่า | เจอกี่ที่ | เป็นอะไร | ทำอะไร |
|---|---|---|---|
| `Colors.red` | **10** ไฟล์ | หัวใจที่ถูกกด like | → `WynColors.iconLikeActive` |
| `Color(0xFFF1EFE9)` | **12** ครั้ง / 11 ไฟล์ (+ 1 private const) | พื้นหลังนวลของ surface เงียบๆ | → `WynColors.surfaceTint` |
| `Color(0xFF2B2A26)` | **2** ไฟล์ (คนละชื่อ private const) | ตัวอักษรที่เบากว่า ink | → `WynColors.inkSoft` |
| `WynColors.graphite` เป็นสีไอคอน idle | หลายสิบ | ไอคอนสถานะปกติ | → `WynColors.iconIdle` (alias) |
| `WynColors.sapphire` เป็นสีไอคอน active | หลายที่ | ReDropped / Saved | → `WynColors.iconActive` (alias) |
| `Colors.redAccent` | **1** | ข้อความ error บนพื้นดำ (crop screen) | → `WynColors.errorDark` |
| `Colors.white70` | 3 (ไฟล์ Pop) | — | **ไม่แตะ** — ดู §5 |

### ทำไมต้องตั้งชื่อ ไม่ใช่แค่ปล่อยไว้

`Color(0xFFF1EFE9)` ปรากฏเหมือนกันเป๊ะใน 11 ไฟล์ที่ไม่รู้จักกัน: แถบค้นหา, วงกลมไอคอนใน empty state, ฟองแชทฝั่งที่เข้ามา, ปุ่ม "กำลังติดตาม" — ค่าที่ปรากฏซ้ำกันเองมากขนาดนั้นคือ token ของระบบอยู่แล้ว ไม่ว่าจะมีใครตั้งชื่อให้หรือไม่ ทางเลือกไม่ใช่ "ตั้งชื่อ vs. ไม่ตั้งชื่อ" แต่คือ "ตั้งชื่อ vs. รอให้สำเนาที่ 12 drift"

เป็นการ promote แบบเดียวกันและด้วยเหตุผลเดียวกับ `WynColors.mutedNeutral` (`#B7B4AC`) ที่ทำไปแล้วก่อนหน้านี้

---

## 2. Token ใหม่ 5 ตัว — ไม่มีตัวไหนเป็นสีใหม่

```dart
static const Color iconIdle       = graphite;          // #8A8880 — ไม่เปลี่ยน
static const Color iconActive     = sapphire;          // #1B3A6B — ไม่เปลี่ยน (WYN-089)
static const Color iconLikeActive = Color(0xFFF44336); // = Colors.red — ไม่เปลี่ยน (WYN-076)
static const Color surfaceTint    = Color(0xFFF1EFE9); // ไม่เปลี่ยน
static const Color inkSoft        = Color(0xFF2B2A26); // ไม่เปลี่ยน
```

### `iconLikeActive` — จุดที่ต้องระวังที่สุด

ค่าคือ `Colors.red` (`#F44336`) **byte ต่อ byte** ไม่ใช่ `WynColors.likeLight` (`#E11D48`)

`likeLight` มีอยู่ใน design system มาก่อน แต่:
* ไม่มีใครอ้างถึงเลยแม้แต่ที่เดียว
* มันมาก่อนการตัดสินใจของ Founder เมื่อ 2026-09-01 ("ใจอยากได้สีแดง")
* การเอามาใช้ตรงนี้ = **เปลี่ยนสีที่ Founder เลือกไว้** ซึ่ง §0 ห้ามชัดเจน

จึงปล่อย `likeLight` ทิ้งไว้เฉยๆ ไม่ลบ ไม่เอามาใช้ และมี test คุมว่าห้ามสับสนกัน

---

## 3. §6 — Repost / Quote icons

### สภาพก่อน

```dart
ListTile(
  leading: const Icon(Icons.repeat),
  title: Text(item.redroppedByMe ? 'ยกเลิกรีโพสต์' : '🔄 รีโพสต์'),
),
ListTile(
  leading: const Icon(Icons.chat_bubble_outline),
  title: const Text('💬 Quote รีโพสต์'),
),
```

อยู่ **2 ที่** (`home_drop_card.dart`, `drop_detail_screen.dart`) เป็นสำเนากันคนละชุด — และ 2 สำเนานั้น *ไม่ตรงกันแล้ว* (แถว ReDrop ทิ้ง emoji ตอนอยู่ในสถานะ undo แต่แถว Quote ไม่เคยทิ้ง)

### ทำไม emoji เป็นปัญหาจริง ไม่ใช่เรื่องรสนิยม

Emoji **ไม่ใช่ icon** ในระบบนี้:

| คุณสมบัติ | Icon (`IconData`) | Emoji ในข้อความ |
|---|---|---|
| รับสีจาก `WynColors` | ✅ | ❌ วาดด้วยสีของ platform |
| ขนาดคุมได้ | ✅ `size:` | ❌ ตามขนาด font |
| Baseline | icon baseline | text baseline |
| Pressed / Active / Selected / Disabled state | ✅ | ❌ **ไม่มีเลย** |

สองแถวนี้คือทางเข้าของ action ที่ผลกระทบหนักที่สุดที่การ์ดในฟีดมี (ReDrop กระจายไปยัง follower ของคนกด) และมันเป็นสองแถวเดียวในผลิตภัณฑ์ที่กฎ state ของ icon system เอื้อมไม่ถึง

### สภาพหลัง

`showRedropSheet()` ตัวเดียว ใช้ร่วมกันทั้งสองหน้า สร้างจาก `ActionSheetBody` / `ActionSheetRow` เหมือน "..." menu ทุกอันในแอป:

| | ก่อน | หลัง |
|---|---|---|
| โครงสร้าง | `Wrap` + `ListTile` ดิบ | `ActionSheetBody` + `ActionSheetRow` |
| ไอคอน | 🔄 / 💬 (emoji) | `Icons.repeat` / `Icons.format_quote` |
| ขนาดไอคอน | ตาม font | 18px ทั้งคู่ |
| สีไอคอน | สีของ platform | `WynColors.ink` ทั้งคู่ |
| Divider ระหว่างแถว | ไม่มี | มี (เหมือน sheet อื่น) |
| Chevron ท้ายแถว | ไม่มี | มี |
| Pressed state | ListTile default | `InkWell` ripple เดียวกับทุก sheet |
| Touch target | ListTile default | ≥ 44px วัดจริงใน test |
| จำนวนสำเนาในโค้ด | 2 | **1** |
| ป้าย Quote | "💬 Quote รีโพสต์" (ปนอังกฤษ) | **"อ้างอิง"** (ตามคำในโจทย์ §6) |

**เลือก `Icons.format_quote` ไม่ใช่ `Icons.chat_bubble_outline`:** ปลายทางคือ "เพิ่มคำพูดของคุณเหนือโพสต์นี้" และ `chat_bubble_outline` ถูกจองไว้แล้วสำหรับ "คอมเมนต์" ใน action bar ที่อยู่เหนือ sheet นี้พอดี — ใช้ซ้ำจะทำให้ไอคอนเดียวหมายถึงสองอย่างในระยะ 100px

**ไอคอนเดิมในสถานะ undo:** แถว ReDrop ใช้ `Icons.repeat` ทั้งสองสถานะ เปลี่ยนแค่คำ — เวอร์ชัน emoji เดิมทำให้แถวเปลี่ยน *รูปร่าง* ตามสถานะ ReDrop ของผู้ใช้เอง

---

## 4. §10/§15 — State consistency ทั้งระบบ

ตรวจตามรายการที่ §10 ระบุ:

| Surface | Default | Pressed | Active/Selected | Disabled | ผล |
|---|---|---|---|---|---|
| Home / Feed action bar | `iconIdle` | `InkWell` ripple + scale pop 220ms | `iconLikeActive` / `iconActive` | — | ✅ |
| Notifications type badge | — | InkWell row | badge สี (like = `iconLikeActive` แล้ว) | — | ✅ **แก้แล้ว** |
| Notifications tab (ทั้งหมด/การกล่าวถึง) | `mutedNeutral` + w400 | InkWell | `ink` + w600 + underline `sapphire` | — | ✅ |
| Profile TabBar | `mutedNeutral` + w400 | Material default | `ink` + w600 + indicator `sapphire` | — | ✅ ตรงกับ Notifications |
| Bottom Navigation | outline icon | Material default | filled icon | — | ✅ |
| Post Detail action bar | `iconIdle` | IconButton splash | `iconLikeActive` / `iconActive` | — | ✅ |
| Club post card | `iconIdle` | InkWell | `iconLikeActive` | — | ✅ **แก้แล้ว** |
| Action sheets ทุกอัน | `ink` 18px | InkWell | — | — | ✅ **รวม ReDrop แล้ว** |
| ปุ่ม Follow | sapphire fill | Material | `surfaceTint` fill + graphite text | `onPressed: null` ตอน in-flight | ✅ |
| ปุ่มสร้าง Club / โพสต์ | sapphire fill | Material | — | `hairline` fill + `mutedNeutral` text | ✅ |

**ข้อสรุป §18 (Feed ↔ Notifications ใช้ Visual Language เดียวกัน):** สองหน้านี้ใช้ระบบเดียวกันแล้วจริง — tab style ตรงกัน, สีหัวใจตรงกัน (ผ่าน token เดียว ไม่ใช่ความบังเอิญ), reading tone ตรงกัน (`inkSoft` token เดียว), ไอคอนหัวจอ (`menu`, `search`) สี `ink` ขนาดใกล้กัน

---

## 5. สิ่งที่ตั้งใจ **ไม่แตะ**

| จุด | เหตุผล |
|---|---|
| `Colors.white70` ใน `pop_clip_view.dart` (3 จุด) | Pop ถูกระงับการพัฒนา (DECISIONS.md 2026-08-14) และ DS-001 Risk R3 ระบุ "ห้ามแก้ไฟล์ Pop โดยตรง" — Beta4 แตะไฟล์ Pop เฉพาะการ swap สีหัวใจซึ่ง byte-identical (precedent เดียวกับ DS-001c) |
| ~70 micro-spacing literal | DS-008 ตัดสินอย่างเป็นทางการแล้วว่าเป็น intentional exception ไม่ใช่งานค้าง |
| `notificationBadgeComment` / `notificationBadgeRepost` | Founder-approved exception (2026-08-29) ผูกกับ badge 18px เท่านั้น — Beta4 ไม่ดูดกลืน ไม่เปลี่ยนชื่อ ไม่ทาสีใหม่ |
| `rainbowAccent` | DS-009 Option B ที่ Founder อนุมัติ ใช้ 2 จุด decorative |
| `Color(0xFF5A5850)` (`_replyTextColor`, top reply preview) | ปรากฏที่เดียว — 1 ที่ไม่ใช่ pattern การ promote จะสร้าง token ที่ไม่มีใครใช้ |
| **`📍` หน้าชื่อสถานที่ check-in** | ดู §7 — เป็นคำถามเปิดถึง Founder ไม่ใช่สิ่งที่ Beta4 เปลี่ยนเอง |

---

## 6. Guard test — ทำให้ audit นี้ยังจริงหลังจากวันนี้

`test/design_system_guard_test.dart` **อ่าน source จริงใน `lib/`** และ fail ถ้า:

1. `Colors.red` กลับมาอยู่นอก `wyn_colors.dart`
2. `0xFFF1EFE9` ถูกเขียนซ้ำ
3. `0xFF2B2A26` ถูกเขียนซ้ำ
4. มีใครอ่าน `club.iconUrl` / `club.coverUrl` ตรงๆ แทน `identityImageUrl` (§8.1)
5. 🔄 หรือ 💬 กลับมาเป็น icon

เอกสารที่เขียนว่า "อย่าทำแบบนั้นอีก" ไม่รอด feature ถัดไป test รอด

**ขอบเขตแคบโดยตั้งใจ:** ห้ามเฉพาะการ inline ค่าที่มีชื่อแล้ว ไม่ได้ห้าม hardcoded color ทั่วไป — `wyn_colors.dart` คือที่ที่สีเป็น literal ได้ นั่นคือหน้าที่มัน

---

## 7. Known Issues / คำถามเปิดถึง Founder

| # | เรื่อง | รายละเอียด |
|---|---|---|
| Q-1 | **`📍` หน้าชื่อสถานที่ check-in** | อยู่ใน `home_drop_card.dart` และ `drop_detail_screen.dart` เป็น emoji ในตำแหน่งที่ทำหน้าที่คล้าย icon (หน้า metadata) ซึ่งเข้าข่ายเดียวกับที่ §6 ห้าม **แต่** มันเป็น copy ตามตัวอักษรใน Product spec ของ WYN-098 (`"📍 {ชื่อสถานที่}"`) และมีคอมเมนต์ระบุว่าตั้งใจ Beta4 จึงไม่เปลี่ยนเอง — **ต้องการคำตัดสินจาก Founder** ว่าจะเปลี่ยนเป็น `Icons.place_outlined` หรือคงไว้ |
| K-1 | `WynColors.likeLight` ยังไม่มีใครใช้ | คงไว้ ไม่ลบ เผื่อ Founder ตัดสินใจเรื่อง like color ใหม่ในอนาคต มี test คุมไม่ให้สับสนกับ `iconLikeActive` |
| K-2 | ยังไม่มี dark mode | `socialDarkScheme` มีอยู่แต่ `WynApp` บังคับ `ThemeMode.light` (WYN-071) token ใหม่ทั้ง 5 ตัวเป็นค่าเดียวไม่แยก theme — สอดคล้องกับสถานะปัจจุบัน ถ้าเปิด dark mode ในอนาคตต้องกลับมาทบทวน |
| K-3 | ตรวจด้วย grep + widget test ไม่ใช่ตาเปล่าบนอุปกรณ์ | ไม่มี device ใน session นี้ สีและขนาดยืนยันจาก test ที่อ่านค่า `Icon.color` / `Icon.size` จริง |
