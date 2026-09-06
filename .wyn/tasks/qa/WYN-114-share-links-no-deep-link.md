# Bug Report — WYN-114

Status: qa (fixed by AI Debug Engineer, 2026-09-06 — awaiting QA re-check; flutter analyze/flutter test could not be run in this sandbox, no Flutter SDK installed here — see Tests section)
Owner: AI Debug Engineer
Severity: **Major** — every "share" button in the app produces a link that does nothing useful when opened
พบโดย: Founder, ทดสอบเปิดลิงก์คลับ `https://wynos.online/club/b3f010b9-b788-41f8-8e86-c7abb717b6d2` จริงบน production

## Bug

เปิดลิงก์คลับที่ก็อปมาจากปุ่มแชร์ในแอป (`https://wynos.online/club/<id>`) แล้ว**ไม่เด้งไปหน้าคลับ** — ตรวจสอบแล้วพบว่าเป็นปัญหากว้างกว่านั้นมาก: **ปุ่ม "แชร์" ทุกจุดในแอปสร้างลิงก์ที่ผิดทั้งสองชั้น**:

1. **โดเมนผิด**: `dropShareLink`/`popShareLink`/`clubShareLink`/`clubPostShareLink`/`profileShareLink` (5 ฟังก์ชัน ใน `drop_detail_screen.dart`/`pop_clip_view.dart`/`club_page.dart`/`club_post_detail_screen.dart`/`view_profile_screen.dart`) hardcode โดเมน `https://wyn.app/...` ซึ่งไม่ใช่โดเมน production จริง (`https://wynos.online` — ยืนยันจาก `RELEASE_NOTES.md`/`CONTEXT.md`) — ลิงก์ที่คัดลอกไปแชร์จะเปิดไม่ติดเลยด้วยซ้ำถ้าไม่มีใครไปตั้ง `wyn.app` เอง (จาก log พบว่าคุณทดสอบด้วย URL ที่แก้โดเมนเป็น `wynos.online` เองแล้ว)
2. **ไม่มีระบบ routing รับ path เหล่านี้เลย**: แม้เปิดโดเมนที่ถูกต้อง (`wynos.online`) เซิร์ฟเวอร์ (Vercel) ตอบ HTTP 200 กลับมาถูกต้อง (SPA fallback ทำงานอยู่แล้ว ยืนยันด้วย `curl`) แต่ตัวแอป Flutter Web เองไม่เคยอ่าน path จาก URL เลยสักจุด — `app/lib/main.dart:130` ตั้ง `MaterialApp(home: const AuthGate())` ตรงๆ ไม่มี route table, ไม่มี `onGenerateRoute`, ไม่มี `GoRouter`, grep ทั้ง `app/lib` หา `GoRouter`/`onGenerateRoute`/`Uri.base` ไม่เจอเลยสักจุดก่อนแก้ไขนี้ — ดังนั้นไม่ว่าจะเปิด path ไหน Flutter boot ขึ้นมาแล้วพาไปที่ `AuthGate` → หน้า login/home ตามปกติเสมอ ไม่สนใจ path ที่เปิดมาเลย

## Reproduction

1. เปิด `https://wynos.online/club/<club-id-ที่มีอยู่จริง>` ในเบราว์เซอร์ (แก้โดเมนจาก `wyn.app` เป็น `wynos.online` ก่อน เพราะโดเมนเดิมเปิดไม่ติดด้วยซ้ำ)
2. คาดหวัง: เห็นหน้าคลับนั้นโดยตรง
3. จริง: เห็นหน้า login/home ตามปกติ ไม่มีร่องรอยของคลับที่ id ระบุเลย

(ไม่สามารถ verify ด้วย browser automation จริงใน sandbox นี้ได้ — Chromium ของ sandbox เจอ `ERR_CONNECTION_RESET` ทุกครั้งที่พยายามต่อ HTTPS ออกไปยัง production เหมือนข้อจำกัดเดียวกับที่เจอตอนตรวจ WYN-P0 — สรุปผลจากการอ่าน source code โดยตรงแทน ซึ่งชัดเจนพอที่จะสรุปได้โดยไม่ต้องพึ่ง live browser: ไม่มี routing logic อยู่เลยสักบรรทัด)

## Root Cause

แอปนี้ไม่เคยมีระบบ deep-link/URL routing มาตั้งแต่ต้น — ฟังก์ชันสร้างลิงก์แชร์ (`*ShareLink()`) ถูกเขียนขึ้นตั้งแต่ WYN-005/006/014/033 โดยตั้งใจให้เป็น "ลิงก์ที่แชร์ออกไปได้" แต่ไม่มีงานไหนเคยต่อฝั่งรับ (การอ่าน path ตอนแอป boot แล้ว navigate ไปหน้าที่ถูกต้อง) เข้ามาเลย — เป็น gap ที่ไม่มีใครสังเกตเพราะไม่มีใครทดสอบเปิดลิงก์แชร์จริงจนกระทั่งรอบนี้

## Fix

1. **แก้โดเมนผิด**: เปลี่ยน `https://wyn.app` → `https://wynos.online` ใน `*ShareLink()` ทั้ง 5 จุด
2. **เพิ่มระบบ deep-link (เฉพาะ Web)**: สร้าง `app/lib/core/navigation/deep_link_service.dart` (`DeepLinkService`) — อ่าน `Uri.base.path` ตอนแอป boot ครั้งแรก (เฉพาะ `kIsWeb`, เว็บเท่านั้น) แล้ว parse path ตามรูปแบบเดียวกับที่ `*ShareLink()` สร้างไว้:
   - `/drop/<id>` → `DropDetailScreen` (fetch ด้วย `DropRepository.fetchById`)
   - `/pop/<id>` → แสดง SnackBar "เนื้อหานี้ไม่พร้อมใช้งานแล้ว" แทนการเปิดจริง (Pop ถูกปิดใช้งานไปแล้วตาม WYN-102 — ต้องคงกติกาเดิมไว้ ไม่เปิดช่องเข้าถึง Pop ใหม่ผ่านทางลิงก์)
   - `/club/<id>` → `ClubPage`
   - `/club-post/<id>` → `ClubPostDetailScreen` (fetch ด้วย `ClubPostRepository.fetchById`)
   - `/@<username>` → `ViewProfileScreen` (resolve username → id ด้วย `ProfileRepository.fetchProfileByUsername` ก่อน)

   เรียกจาก `RootShell.initState()` (ผ่าน `WidgetsBinding.instance.addPostFrameCallback`) — จุดเดียวกับที่ `PushNotificationService.initialize()` ถูกเรียกอยู่แล้ว เพื่อให้ยิงแค่ครั้งเดียวต่อการ sign-in จริง ไม่ใช่ทุกครั้งที่ widget rebuild (โครง/เหตุผลเดียวกับ comment ของ `PushNotificationService` ใน `root_shell.dart` ที่อธิบายไว้แล้ว) — logic การเปิดแต่ละหน้าเขียนตามแพทเทิร์นเป๊ะจาก `PushNotificationService._openDrop/_openProfile/_openClub/_openClubPost` (ใช้ repository/screen constructor ชุดเดียวกัน)

## Files Changed

- `app/lib/core/navigation/deep_link_service.dart` — ใหม่
- `app/lib/features/root/presentation/root_shell.dart` — เรียก `DeepLinkService.handleInitialLink()` ใน `initState()`
- `app/lib/features/drop/presentation/drop_detail_screen.dart`, `app/lib/features/pop/presentation/widgets/pop_clip_view.dart`, `app/lib/features/club/presentation/club_page.dart`, `app/lib/features/club/presentation/club_post_detail_screen.dart`, `app/lib/features/profile/presentation/view_profile_screen.dart` — แก้โดเมนใน `*ShareLink()`
- `app/test/deep_link_service_test.dart` — ใหม่

## Tests

**ไม่สามารถรัน `flutter analyze`/`flutter test` ได้จริงใน session นี้ — sandbox นี้ไม่มี Flutter SDK ติดตั้งอยู่เลย** (`which flutter` ไม่พบ, ตรวจสอบแล้วไม่มีที่ไหนในเครื่องนี้) ตรวจสอบความถูกต้องด้วยการอ่าน source ตรงๆ แทน (import ครบ, ชื่อ method/constructor ตรงกับที่มีจริงในแต่ละไฟล์ที่ import — ตรวจ cross-reference ทีละจุด) แต่**นี่ไม่ทดแทนการรันจริง** — ต้องให้ AI QA & Security หรือใครก็ตามที่มี Flutter environment รัน:
```
cd app && flutter analyze && flutter test
```
ก่อน merge/deploy เด็ดขาด (ตามกติกา "ห้ามข้าม QA")

`app/test/deep_link_service_test.dart` (เขียนไว้แล้ว รอรันยืนยัน) ครอบคลุม:
- `/pop/<id>` แสดง SnackBar แทนการ navigate (ไม่ต้องพึ่งเครือข่ายจริง)
- path ที่ผิดรูปแบบ/ไม่รู้จัก (`''`, `/`, `/club`, `/club/`, `/@`, `/unknown/x123`) ไม่ throw ไม่ navigate
- `handleInitialLink()` เป็น no-op บน test target ปกติ (ไม่ใช่ web, `kIsWeb == false`) — ป้องกันไม่ให้ test อ่าน `Uri.base` ของตัว test runner เองมาตีความเป็น URL จริง
- `handleInitialLink()` ยิงแค่ครั้งเดียวแม้เรียกซ้ำ

**ยังไม่มี test ครอบคลุม happy path จริง** (`/drop/<id>` → เปิด `DropDetailScreen` จริง, `/club-post/<id>`, `/@username`) เพราะ method พวกนี้เรียก `fetchById`/`fetchProfileByUsername` ซึ่งต้องต่อเครือข่ายจริงไปยัง Supabase — ข้อจำกัดเดียวกับที่ `push_notification_service_test.dart`'s เดิมก็ไม่ได้ทดสอบ `_openDrop`/`_openClub`/`_openClubPost` ด้วยเหตุผลเดียวกัน (ไม่มี fake HTTP layer ให้ inject) ต้องให้ AI QA & Security ตรวจ happy path จริงกับ Supabase project จริง/local ก่อนอนุมัติ

## Regression Risk

**ต่ำ-ปานกลาง**:
- แก้โดเมนใน `*ShareLink()`: ต่ำมาก เปลี่ยนแค่ string literal
- `DeepLinkService`: ใหม่ทั้งหมด ไม่แตะโค้ดเดิมนอกจาก 1 บรรทัดเรียกใน `RootShell.initState()` (เป็น `addPostFrameCallback`, ไม่ block build) — ความเสี่ยงหลักคือ**เฉพาะเว็บเท่านั้น** (`kIsWeb` guard) จึงไม่กระทบ native mobile เลย แต่ยังไม่ได้ทดสอบ interaction กับ deep-link ที่เปิดตอนยังไม่ login (เช่น คนที่ไม่เคย sign-in กดลิงก์แชร์ครั้งแรก) — ตอนนี้ `RootShell` mount ได้ก็ต่อเมื่อผ่าน AuthGate ครบแล้วเท่านั้น ดังนั้นคนที่ยังไม่ login จะเห็นหน้า Welcome/Onboarding ตามปกติก่อน แล้ว deep-link จะ**ไม่ทำงานอีกเลย**หลังจากนั้น (ยิงแค่ครั้งเดียวตอน RootShell แรกสุด ซึ่งคนที่ยังไม่ login จะไม่ถึงจุดนั้นเลยในตอนที่กดลิงก์) — เป็น known limitation ที่ควรบันทึกเป็น follow-up แยก ไม่ใช่ blocker ของ fix นี้ (Founder ทดสอบตอนเป็นสมาชิกที่ login อยู่แล้ว ซึ่งกรณีนี้ทำงานถูกต้อง)

## Known Follow-ups (ไม่ได้แก้ในรอบนี้)

1. **Deep link ตอนยังไม่ login**: ถ้าคนที่ไม่เคย sign-in กดลิงก์แชร์ ตอนนี้จะเห็น Welcome เฉยๆ แล้วลิงก์ที่ตั้งใจแชร์หายไปเลย (ไม่มี "จำไว้แล้วพาไปหลัง login สำเร็จ") — ควรเป็นงานแยกถ้า Founder เห็นว่าคุ้มทำ (ต้องรอ AuthGate/Onboarding เสร็จก่อน ค่อยเช็ค path ที่ค้างไว้)
2. **Native mobile deep-link**: iOS/Android ยังไม่รับ path พวกนี้เลย เพราะต้องตั้งค่า iOS Associated Domains / Android App Links (ไฟล์ `apple-app-site-association`/`assetlinks.json` บน production + entitlement ในแอป) ซึ่งเป็น platform config นอกเหนือจากโค้ด Dart ล้วนๆ — เหมือนกรณี WYN-P0/Apple Sign-In ที่ต้องรอ account/config ของ Founder ไม่ใช่สิ่งที่แก้ในเซสชันนี้ได้
3. **SCHEMA-004 style drift**: ยังไม่ได้ตรวจว่า `wyn.app` ถูก hardcode ไว้ที่อื่นนอกแอป (เช่น ข้อความ marketing ภายนอก, Supabase email template ฯลฯ) — อยู่นอกขอบเขต repo นี้

## Handoff to QA

รัน `flutter analyze && flutter test` เต็ม suite ก่อนอื่น (ยังไม่เคยรันในเซสชันนี้เลย) จากนั้นตรวจ happy path จริงกับ Supabase/URL จริง 5 แบบ: `/drop/<id>`, `/club/<id>`, `/club-post/<id>`, `/@<username>`, `/pop/<id>` (ต้องเห็น SnackBar ไม่ใช่เปิด Pop จริง) — ทั้งกรณี id/username มีอยู่จริงและไม่มีอยู่จริง (ต้องไม่ crash, เงียบๆ อยู่ที่ Home เดิมถ้า fetch ได้ `null`)
