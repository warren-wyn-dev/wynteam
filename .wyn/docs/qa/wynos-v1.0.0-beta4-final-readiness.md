# WYNOS v1.0.0 Beta4 — Final Readiness Report

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta4-master-implementation-j5lke8`
> สถานะตอนเขียนรายงาน: **push ขึ้น feature branch แล้ว · ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy** — รอคำสั่ง/อนุมัติจาก Founder ตาม §0
>
> **อัปเดต 2026-09-03 17:24 — หลัง Founder สั่ง "PR Merge deploy ต่อเลย":**
> PR เปิดและ merge เข้า `main` แล้ว · deploy production แล้ว (`https://wynos.online`) ·
> Edge Function `send-push-notification` deploy แล้ว (run `33780460047`) ·
> **Firebase Web config ครบทั้ง 7 ค่าใน production build แล้ว** (run `33784128418`, `0ffcc15`) →
> `PushEnv.isWebPushConfigured == true` บน production
> เหลือฝั่ง server 2 ชิ้นก่อนส่ง push ได้จริง: `FCM_SERVICE_ACCOUNT` ใน Supabase และ Database Webhook (ดู K-1)
> Environment: Flutter 3.47.1 (SDK เดียวกับที่ `ci.yml` และ `deploy-web.yml` pin) · Deno 2.x · PostgreSQL ไม่ได้ใช้ใน session นี้
> **ไม่มี Supabase production credential และไม่มี Firebase project ใน session นี้** — ทุกข้อความในเอกสารชุด Beta4 ระบุว่าตรวจที่ไหน

---

## 1. ผลการทดสอบอัตโนมัติ

| ชุด | ผล | หมายเหตุ |
|---|---|---|
| `app` — `flutter analyze` | ✅ **0 issues** | |
| `app` — `flutter test` | ✅ **1164 / 1164** | ก่อน Beta4: 1107 → เพิ่ม 57 test |
| `seller_app` — `flutter analyze` | ✅ 0 issues | Beta4 ไม่แตะ ZOKY |
| `seller_app` — `flutter test` | ⚠️ **96 ผ่าน / 2 ไม่ผ่าน** | **เป็นอยู่แบบนี้ก่อน Beta4 แล้ว** — ดู §7 F-1 |
| Edge Function — `deno check` | ✅ | |
| Edge Function — `deno test` | ✅ **20 / 20** | ก่อน Beta4: 17 → เพิ่ม 3 |
| `supabase/check_schema_ordering.py` | ✅ OK, ไม่มี forward reference | Beta4 ไม่แตะ `schema.sql` |

**ไม่ได้รัน:** `supabase/tests/*.sh` (30+ ไฟล์, ต้องมี PostgreSQL 16 ที่สร้าง database ได้) และ `next build` ของ admin — ทั้งคู่อยู่นอกขอบเขต Beta4 และ CONTRIBUTING.md ระบุไว้แล้วว่า CI ยังไม่ครอบคลุม

---

## 2. Implementation — ทำอะไรเสร็จแล้ว

### ไฟล์ที่แก้ทั้งหมด: 65 ไฟล์ (+3,851 / −907 บรรทัด)

| กลุ่ม | ไฟล์ |
|---|---|
| Design system | `wyn_colors.dart` (+5 token) |
| Profile | `view_profile_screen.dart`, `profile_photo_crop_screen.dart` |
| Account | `auth_gate.dart`, `account_switcher_sheet.dart` |
| Draft | `create_drop_screen.dart`, `drafts_screen.dart` (ใหม่), `draft_list.dart` (ย้าย) |
| ReDrop/Quote | `redrop_action_sheet.dart` (ใหม่), `home_drop_card.dart`, `drop_detail_screen.dart` |
| Club | `club.dart`, `club_repository.dart`, `club_page.dart`, `create_club_screen.dart`, `edit_club_info_screen.dart`, `club_avatar.dart` (ใหม่), + 6 widget |
| Push | `push_env.dart` (ใหม่), `push_notification_service.dart`, `push_permission_card.dart` (ใหม่), `main.dart`, `web/firebase-messaging-sw.js` (ใหม่) |
| Notification | `notification_list_screen.dart`, `notification_settings_screen.dart`, `root_shell.dart` |
| Edge Function | `_lib.ts`, `index.ts` |
| Token cleanup | 11 ไฟล์ที่เคย inline `#F1EFE9` / `#2B2A26` |
| Tests | 18 ไฟล์ (7 ไฟล์ใหม่) |

### §1-§3 Profile

* Header จัดใหม่: avatar ซ้าย + คอลัมน์ตัวตนทั้งหมดทางขวา (ชื่อ → @ → bio → stats → ปุ่ม)
* stats เหลือ 2 ตัว (กำลังติดตาม ก่อน ผู้ติดตาม) ตัด "โพสต์" ออก → **profile load ลดจาก 4 query เหลือ 3**
* `ชื่อที่แสดง ⌄` เป็นทางเข้า account switcher (own profile เท่านั้น) แทนที่จะซ่อนอยู่ 3 แตะลึกใน Settings
* other profile: `[ติดตาม] [ส่งข้อความ]` ไม่เปลี่ยน ใช้ `ChatRepository` เดิม ไม่สร้างระบบ chat ใหม่

### §4-§5 Saved / Draft ออกจาก Profile

* Saved: ระบบเดิม 100% — ทางเข้า `Home → ☰ → บันทึกไว้` **มีอยู่แล้วตั้งแต่ WYN-100** เอาแค่ไอคอนซ้ำที่ไม่มีป้ายบน Profile ออก
* Draft: ย้ายไฟล์ `profile/` → `drop/`, ทางเข้าใหม่คือปุ่ม **"ร่าง"** ในหัว composer, empty state ใช้ `EmptyStateBlock` ร่วมกับที่อื่น

### §6 ReDrop / Quote

* `showRedropSheet()` ตัวเดียวใช้ร่วม 2 หน้า (เดิมมี 2 สำเนาที่ **ไม่ตรงกันแล้ว**)
* emoji `🔄`/`💬` → `Icons.repeat` / `Icons.format_quote` 18px สี `ink` ผ่าน `ActionSheetRow`
* ป้าย "💬 Quote รีโพสต์" → **"อ้างอิง"** ตามคำในโจทย์

### §7 Image UI

* Club post → `PostImageFrame`/`PostImageCarousel` ร่วมกับ Drop (สัดส่วน 1:1 คงเดิม เพราะ `club_posts` ไม่มีคอลัมน์ dimension)
* `ClubAvatar` แทน `CircleAvatar` ดิบ 5 ชุด → ได้ decode bound + error fallback + guard ครบทุกจุด
* Edit Club preview: `Image.network` ดิบ → `NetworkThumbnail`

### §8 Club

* **`Club.identityImageUrl` เป็น read path เดียว** — แก้ปัญหาที่รูปที่อัปไปขึ้นแค่ในการ์ด Explore ส่วนที่อื่นเป็นวงกลมเทาเสมอ
* `createClub` และ upload รวมเหลือพารามิเตอร์รูปชุดเดียว → "Club ที่มี 2 รูป" เป็นไปไม่ได้เชิง type
* Create Club เรียงตาม §8.2 + สรุป "ตรวจสอบข้อมูล" ก่อนปุ่ม
* Club banner คืนรูป identity กลับมา **พร้อมชื่อ Club ที่ไม่หายอีกแล้ว** (เหตุผลที่ Beta3 เอารูปออก)
* ไม่มี migration — `cover_url` คงอยู่เป็น fallback ให้ Club เดิม

### §9-§10, §15 UI / Icon / State

* Token ใหม่ 5 ตัว: `iconIdle`, `iconActive`, `iconLikeActive`, `surfaceTint`, `inkSoft` — **ไม่มีค่าสีไหนเปลี่ยนแม้แต่ค่าเดียว**
* แทน literal ที่ซ้ำ 24 จุด (10 × `Colors.red`, 12 × `#F1EFE9`, 2 × `#2B2A26`)
* `design_system_guard_test.dart` อ่าน source จริงและ fail ถ้ามีใคร inline กลับมา

### §11 Notification & Web Push

* **Permission ไม่ถูกขอเองอีกแล้ว** — ย้ายไปหลังการ์ดอธิบายบนหน้า Notifications และแถวในตั้งค่า
* 4 สถานะแยกกันจริง (`unsupported` / `notDetermined` / `granted` / `denied`) รวม "denied กู้คืนในแอปไม่ได้ ชี้ไปตั้งค่าระบบ"
* **Web Push ทำงานได้เป็นครั้งแรก** — service worker + `FirebaseOptions` จาก `--dart-define`
* Duplicate protection: collapse key = notification row id บนทั้ง 3 ชั้นการส่ง
* Badge refresh ตอน resume + ตอน foreground push (ไม่มี polling)

### §13 Account Switching Safety

* `RootShell` key ด้วย user id — ปิดบั๊กที่ state ของ A ตกทอดไป B ทั้งก้อน
* ลบ push token ตอนที่ยังเป็น A ก่อนสลับ — ปิดบั๊กที่ push ของ A เด้งบนเครื่องที่ B ใช้อยู่

---

## 3. บั๊กจริงที่พบและแก้ (ไม่ได้อยู่ในโจทย์)

| # | บั๊ก | ความรุนแรง | พบได้อย่างไร |
|---|---|---|---|
| B4-A1 | `_RootShellState` รอดข้ามการสลับบัญชี — badge/feed/notifications/profile/push ของ A ตกทอดไป B | **สูง** | อ่าน `AuthGate` + `RootShell` ตอน inspect §13 |
| B4-A2 | push token ค้างชี้บัญชีเดิมหลังสลับ (RLS บล็อกไม่ให้บัญชีใหม่แก้ การ upsert ล้มเงียบ) | **สูง** | อ่าน RLS ใน `schema.sql` ประกอบกับ B4-A1 |
| B4-N1 | badge ค้างได้นานเท่าที่แอปเปิดอยู่ (อ่านครั้งเดียวใน `initState`) | กลาง | grep หา realtime subscription แล้วไม่เจอ |
| B4-C1 | รูป Club ที่อัปไปขึ้นแค่การ์ด Explore — ที่อื่นเป็นวงกลมเทาเสมอ (2 คอลัมน์ เขียนอันหนึ่ง อ่านอีกอัน) | กลาง | ตรวจ §8.1 |
| R-1 | Profile stats ล้นจอ 200px ที่ 320px | กลาง | **test §14 เจอ** |
| R-2 | Profile header ล้นความสูง 102px ที่ 568px เมื่อ bio ยาว | กลาง | **test §14 เจอ** |
| R-3 | ชื่อ Club ล้น banner ที่จอเล็ก | ต่ำ | **test §14 เจอ** |
| R-4 | ปุ่ม "ร่าง" touch target 40px (`visualDensity` ลบ 8px จาก `minimumSize`) | ต่ำ | **test เจอ** |
| B4-T1 | test ของ Beta3 เรื่อง Club banner กลายเป็น vacuous (กรอง `image is NetworkImage` แต่ `NetworkThumbnail` ห่อด้วย `ResizeImage`) — เขียวแม้ banner จะไม่ render อะไรเลย | กลาง (test) | ตรวจตอนแก้ §8.3 |

**ข้อสังเกต:** 4 ใน 9 ตัวถูกพบโดย test ที่เขียนตาม §14 ไม่ใช่โดยการอ่านโค้ด — นี่คือเหตุผลที่ §14 ขอให้ตรวจ responsive จริง

---

## 4. QA ที่ทำ

| หมวด | ผล | หลักฐาน |
|---|---|---|
| **Functional (§17)** | ✅ | Profile (23 test), Draft (4 test ใหม่ + 7 เดิม), ReDrop/Quote (7 test ใหม่ + 5 ปรับ), Club (9+5+4 test), Notifications (7 test ใหม่ + 3 badge) |
| **Visual (§18)** | ✅ | icon size/colour วัดจากค่า `Icon.color`/`Icon.size` จริงใน test · Feed ↔ Notifications ใช้ token เดียวกันแล้ว (พิสูจน์ใน `icon_color_consistency_test`) |
| **Responsive (§20)** | ✅ | 320/390/430/834 บน Profile + Club + Create Club — วัด `takeException()` และพิกัดจริง |
| **Security (§19)** | ✅ | อ่าน RLS ของ `notifications` / `push_tokens` / `clubs` จาก `schema.sql` โดยตรง ไม่มี policy ไหนถูกแตะ |
| **Account Switching (§13)** | ✅ | 2 test ที่ยืนยันกลไก key |
| **Notification (§11)** | ✅ (ยกเว้น end-to-end) | ดู §7 K-1 |
| **Regression (§21)** | ✅ | 1164/1164 — Auth, Feed, Post, Like, Comment, Follow, Search, Notifications, Profile, Saved, Draft, ReDrop/Quote, Club ครบ |

---

## 5. Definition of Done — §0 checklist

| ข้อ | สถานะ |
|---|---|
| Profile UX/UI เสร็จ | ✅ |
| Own Profile ถูกต้อง | ✅ |
| Other Profile ถูกต้อง | ✅ |
| Followers / Following Navigation ถูกต้อง | ✅ (ตรวจแล้ว ไม่พบปัญหา ไม่ต้องแก้) |
| Account Switch UX ถูกต้อง | ✅ |
| Account State แยกกัน | ✅ **แก้บั๊กจริง** |
| Saved อยู่ใน Home Menu | ✅ (มีอยู่แล้ว — เอาที่ซ้ำบน Profile ออก) |
| Draft อยู่ใน Post Creation Flow | ✅ |
| Repost / Quote UI ถูกต้อง | ✅ |
| Repost / Quote ใช้ WYNOS Icon System | ✅ |
| Image UI Consistency ผ่าน | ✅ |
| Club UX/UI ได้รับการปรับปรุง | ✅ |
| Create Club Flow เข้าใจง่าย | ✅ |
| Club ใช้รูปเพียง 1 รูป | ✅ |
| ไม่มี Cover Image แยก | ✅ (คอลัมน์ยังอยู่เป็น fallback — ไม่มีใครเขียน) |
| ไม่มี Background Image แยก | ✅ (banner กับ identity image เป็นรูปเดียวกันแล้ว) |
| Icon Color Consistency ผ่าน | ✅ |
| Feed / Notifications ใช้ Visual Language เดียวกัน | ✅ |
| UI States สอดคล้องกัน | ✅ |
| Responsive Profile ผ่าน | ✅ **แก้บั๊กจริง 2 ตัว** |
| Responsive Club ผ่าน | ✅ **แก้บั๊กจริง 1 ตัว** |
| Account Switching Safety ผ่าน | ✅ |
| In-App Notifications ผ่าน | ✅ |
| Web Push ทำงานตาม Platform ที่รองรับ | ⚠️ **โค้ดครบ ยังไม่ได้ทดสอบจริง** — ดู §7 K-1 |
| Notification Permission Flow ผ่าน | ✅ |
| Notification Badge ถูกต้อง | ✅ **แก้บั๊กจริง** |
| Notification Deep Link ผ่าน | ✅ (ไม่เปลี่ยน 24 type) |
| Push Subscription Isolation ผ่าน | ✅ **แก้บั๊กจริง** |
| Duplicate Notification Protection ผ่าน | ✅ |
| Notification Security ผ่าน | ✅ |
| Functional QA ผ่าน | ✅ |
| Visual QA ผ่าน | ✅ |
| Responsive QA ผ่าน | ✅ |
| Security QA ผ่าน | ✅ |
| Regression QA ผ่าน | ✅ |
| QA Documentation ครบ | ✅ 7 ไฟล์ |
| Final Readiness Report เสร็จ | ✅ ไฟล์นี้ |

---

## 6. สิ่งที่ Beta4 **ไม่** ทำ ตามที่ §0 ห้าม

* ❌ ไม่เพิ่ม Product Area ใหม่
* ❌ ไม่แตะ ZOKY (`seller_app/` ไม่มีไฟล์ไหนถูกแก้เลย — ยืนยันด้วย `git diff --name-only`)
* ❌ ไม่ทำ Beta3 ซ้ำ
* ❌ ไม่เปลี่ยน Product Direction (mobile-first ไม่มี breakpoint — ยังคงเดิม)
* ❌ ไม่กำหนดสีใหม่เอง (token ใหม่ 5 ตัว ค่าเดิมทั้งหมด)
* ❌ ไม่สร้าง Icon System / Design System / Notification System ใหม่
* ❌ ไม่ทำ Database Migration
* ❌ ไม่ Rewrite Architecture (ไม่แตะ state management, ไม่เปลี่ยนโครง navigation)
* ❌ ไม่ลบ functionality ที่ยังจำเป็น (Saved/Draft ย้ายทางเข้า ไม่ได้ลบ)
* ❌ **ไม่ deploy · ไม่ merge · ไม่เปิด PR** — จริงตลอดช่วง implement · ทั้งสามอย่างเกิดขึ้นภายหลัง **ตามคำสั่งตรงของ Founder** ("PR Merge deploy ต่อเลย") ไม่ใช่การตัดสินใจเอง

---

## 7. Remaining Issues — ทั้งหมด ตามความจริง

### ต้องให้ Founder ตัดสิน

| # | เรื่อง | รายละเอียด |
|---|---|---|
| **F-1** | **`seller_app` มี test แดง 2 ตัว มาตั้งแต่ก่อน Beta4** | `test/design/token_sync_test.dart` บังคับให้ `seller_app/lib/core/design/wyn_colors.dart` และ `wyn_typography.dart` เหมือน `app/` **byte-for-byte** แต่ทั้งสองไฟล์ diverge ตั้งแต่ commit `a989396` (**2026-08-30**) ตอนที่ `app/` ถูก re-brand Cyan → Sapphire โดย Founder อนุมัติให้ **scope เฉพาะ `app/`** และ `seller_app` ยังใช้ Cyan อยู่ · CI (เพิ่ม 2026-09-03) รัน `flutter test` บน `seller_app` ด้วย **job นั้นจึงแดงมาตั้งแต่วันแรกที่มี CI** · **Beta4 ไม่แก้** เพราะทางแก้มีแค่ 2 ทางและทั้งคู่ต้องให้ Founder ตัดสิน: (ก) copy ทับ = re-brand ZOKY เป็น Sapphire ซึ่ง §0 ห้ามแตะ ZOKY และขัดกับการตัดสินใจ 2026-08-29 หรือ (ข) แก้/ลบ test = เปลี่ยนนโยบาย mirror · **หมายเหตุตรงไปตรงมา:** Beta4 เพิ่ม token 5 ตัวในไฟล์ canonical ทำให้ diff กว้างขึ้น แต่ **ไม่ได้เปลี่ยนสถานะ pass/fail** (แดงอยู่แล้ว) |
| **Q-1** | `📍` หน้าชื่อสถานที่ check-in | เป็น emoji ในตำแหน่งที่ทำหน้าที่เหมือน icon เข้าข่ายเดียวกับที่ §6 ห้าม **แต่**เป็น copy ตามตัวอักษรใน Product spec ของ WYN-098 Beta4 จึงไม่เปลี่ยนเอง — ต้องการคำตัดสิน |
| **Q-2** | layout ยืดเต็มความกว้างบน tablet/web | ไม่มีอะไรพัง (test ผ่านที่ 834px) แต่บรรทัดยาวเกินระยะอ่านสบาย การใส่ `max-width` เป็น product direction ที่ DS-008 เปิดค้างไว้ตั้งแต่ 2026-08-16 |

### Known Issues ที่ไม่บล็อก

| # | เรื่อง | ความรุนแรง |
|---|---|---|
| ~~K-1c~~ | ~~**Edge Function ที่ Beta4 แก้ ยังไม่ได้ deploy**~~ → **✅ ปิดแล้ว** deploy สำเร็จ run `33780460047` (2026-09-03 16:45): `Deployed Functions on project kqokpocajhfbidcxpvhh: send-push-notification` · production ได้ collapse key กัน notification ซ้ำแล้ว · ใช้เวลา 8 runs — 6 ครั้งแรกติดที่ secret/สิทธิ์ ไม่ใช่ที่โค้ด ประวัติครบอยู่ใน notification audit ข้อ 7 · ผลพลอยได้: มี `.github/workflows/deploy-edge-functions.yml` ให้กดปุ่มเดียวได้ตลอดไป | ปิดแล้ว |
| K-1 | **Push ยังไม่เคยส่งจริงแม้แต่ครั้งเดียว** — อัปเดต 2026-09-03 17:24: ฝั่ง client ครบแล้ว (Firebase project `wynos-78e85` · 7 secret `present` ใน build จริง · service worker เสิร์ฟที่ production `200`) และ Edge Function deploy แล้ว · **ยังเหลือ `FCM_SERVICE_ACCOUNT` ใน Supabase และ Database Webhook บน `notifications`** ซึ่งเป็นสองชิ้นสุดท้ายของเส้นทาง · ทุกอย่างยังยืนยันด้วยการอ่านโค้ด + widget test + `deno test` เท่านั้น **end-to-end delivery ยังไม่ได้พิสูจน์** | — (ต้องทดสอบหลังตั้งค่าครบ) |
| K-1b | **`web/firebase-messaging-sw.js` เกือบไม่ได้ถูก commit** — `app/.gitignore` ทำ `/web/*` แล้ว allowlist ทีละไฟล์ (มีมาก่อน Beta4) service worker ใหม่จึงถูก ignore เงียบๆ · จับได้ตอนอ่าน `deploy-web.yml` ก่อน deploy ครั้งแรก · **แก้แล้ว** — ถ้าไม่เจอ production จะไม่มีไฟล์นี้และ Web Push จะยังเป็นไปไม่ได้ ทั้งที่เอกสารบอกว่าทำได้ | — (แก้แล้ว) |
| K-2 | Android Gradle plugin ของ google-services ยังไม่ apply — push บน Android จะยังไม่ทำงาน (เจตนาเดิมตั้งแต่ WYN-016: apply โดยไม่มีไฟล์จริงจะพัง build) | กลาง |
| K-3 | Badge ยังไม่ realtime — อัปเดตตอน resume และตอน foreground push เท่านั้น | ต่ำ |
| K-4 | iOS Safari ต้องติดตั้งเป็น PWA ก่อนจึงจะได้ Web Push (ข้อจำกัดของ Apple) และยังไม่มี UI อธิบายเรื่องนี้ | ต่ำ |
| K-5 | `edit_club_info_screen.dart` ไม่มี test file ของตัวเอง (มีมาก่อน Beta4) — Beta4 แก้ picker ในหน้านี้แล้วยืนยันด้วย analyze + อ่านโค้ด | กลาง |
| K-6 | `cover_url` ยังอยู่ใน DB โดยไม่มีใครเขียน — ตั้งใจ การ migrate + drop ต้องให้ Founder อนุมัติ | ต่ำ |
| K-7 | `forgetAndSwitchToNextIfAny` ไม่ล้าง push token เอง (พึ่ง caller ที่ล้างไปก่อนแล้ว) — ไม่รั่วในทางปฏิบัติแต่ควรรวมเป็นทางเดียว | ต่ำ-กลาง |
| K-8 | Profile header ยังไม่ scroll ไปกับเนื้อหา — ปิดอาการล้นด้วยการจำกัด bio 4 บรรทัดแล้ว | ต่ำ |
| K-9 | `ProfileSavedTab` / `ProfilePopGridTab` / `ProfileRepliesTab` เป็น dead code (posture ของโปรเจกต์: unmount ไม่ลบ) | ต่ำ |
| K-10 | ยังไม่ได้ทดสอบ text scale ใหญ่ (accessibility font size) — เป็นสาเหตุ overflow ที่พบบ่อยพอๆ กับจอแคบ ไม่อยู่ใน scope §14 | กลาง |
| K-11 | ยังไม่ได้ทดสอบบนอุปกรณ์จริงเลย — ทุกผลมาจาก Flutter test binding ซึ่งใช้กลไก layout ตัวเดียวกับบนอุปกรณ์ แต่ไม่ครอบคลุมสิ่งที่ต้องดูด้วยตา (safe area จริง, notch, ความคมของภาพ) | — |
| K-12 | `supabase/tests/*.sh` (30+ ไฟล์, coverage เดียวที่ RLS มี) ยังไม่ได้รัน — ต้องมี PostgreSQL 16 · Beta4 ไม่แตะ `schema.sql` หรือ policy ใดเลย | ต่ำ |

---

## 8. ข้อเสนอต่อ Founder

1. **ตัดสิน F-1 ก่อน merge** — เป็นเรื่องเดียวที่ทำให้ CI ไม่เขียวทั้งหมด และมันไม่ใช่ของ Beta4 แต่ Beta4 เป็นรอบที่เจอมัน
2. ตอบ Q-1 (`📍`) และ Q-2 (max-width บนจอกว้าง) เมื่อสะดวก — ไม่บล็อก
3. ถ้าต้องการให้ Push ทำงานจริง ต้องทำ 7 ขั้นตอนใน `wynos-v1.0.0-beta4-notification-audit.md` §10 (เป็นงานตั้งค่าทั้งหมด ไม่ใช่งานโค้ด) แล้วจึงทดสอบ end-to-end (K-1) — **ข้อ 1/2(web)/3/4/7 เสร็จแล้ว เหลือข้อ 5 และ 6** (ข้อ 2 ฝั่ง native ยังคงเป็น K-2 ตามเดิม)
4. Beta4 พร้อมให้ QA รอบมนุษย์บนอุปกรณ์จริง (K-11) — สิ่งที่ automated test พิสูจน์ไม่ได้

---

## 9. เอกสารชุด Beta4

| ไฟล์ | ครอบคลุม |
|---|---|
| `wynos-v1.0.0-beta4-profile-ux-audit.md` | §1 §2 §3 §4 §5 §12 |
| `wynos-v1.0.0-beta4-account-switching-audit.md` | §13 §11.5 §19 |
| `wynos-v1.0.0-beta4-icon-color-audit.md` | §6 §9 §10 §15 §22 |
| `wynos-v1.0.0-beta4-notification-audit.md` | §11 ทั้งหมด |
| `wynos-v1.0.0-beta4-club-audit.md` | §8 ทั้งหมด + §7 (Club) |
| `wynos-v1.0.0-beta4-responsive-audit.md` | §14 §20 |
| `wynos-v1.0.0-beta4-final-readiness.md` | ไฟล์นี้ — §24 |
