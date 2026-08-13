# Product Task — WYN-003

Status: review (Coding เสร็จแล้ว รอ AI QA & Security ทดสอบ)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (ถัดไป)

Feature: User Profile (View & Edit)

Goal: ให้ผู้ใช้มีตัวตนที่สมบูรณ์กว่าแค่ username — ใส่รูป ชื่อแสดง และคำอธิบายตัวเองได้ เป็นฐานให้ feature ต่อไป (Feed, Follow) แสดงข้อมูลผู้ใช้ได้ครบถ้วน

Target User: วัยรุ่น / Gen Z ที่ต้องการปรับแต่งตัวตนบนแอปให้เป็นของตัวเอง

Problem: หลัง WYN-002 ผู้ใช้มีแค่ username เท่านั้น ไม่มีทางแสดงตัวตน (รูป, ชื่อเล่น, คำโปรย) ให้คนอื่นเห็น และยังไม่มีหน้าจอให้ผู้ใช้จัดการข้อมูลส่วนตัวของตัวเองเลย

Requirements:
- เพิ่มฟิลด์ใน `profiles` table: **display_name** (ชื่อแสดง), **bio** (คำอธิบายสั้น ๆ), **avatar_url** (รูปโปรไฟล์)
- หน้าจอ **ดูโปรไฟล์ตัวเอง**: แสดงรูปโปรไฟล์, ชื่อแสดง, @username, bio
- หน้าจอ **แก้ไขโปรไฟล์**: เปลี่ยนรูปโปรไฟล์ (เลือกจากคลังภาพ/ถ่ายรูปใหม่), แก้ชื่อแสดง, แก้ bio
- อัปโหลดรูปโปรไฟล์ไปเก็บที่ Supabase Storage (bucket `avatars`) ไม่ใช่ base64 ฝังใน database
- เข้าถึงหน้าโปรไฟล์ได้จาก `HomeScreen`
- Username ยังคงแก้ไขไม่ได้ในเฟสนี้

Acceptance Criteria (สถานะ implement — ยังไม่ผ่าน QA):
- [x] View Profile แสดงรูป/ชื่อแสดง/username/bio จาก Supabase (compile ผ่าน ยังไม่ทดสอบกับ project จริง)
- [x] แก้ไขชื่อแสดงได้ (จำกัด 50 ตัวอักษรผ่าน `maxLength` ของ TextField)
- [x] แก้ไข bio ได้ (จำกัด 160 ตัวอักษร มีตัวนับ + เปลี่ยนสีเป็น error เมื่อเหลือ < 20 ตัวอักษร — ยืนยันด้วย widget test จริงแล้ว)
- [x] เลือกรูปจากคลังภาพ/กล้องได้ผ่าน `image_picker` (compress เหลือ 1024x1024, quality 85 ก่อน) preview ทันที อัปโหลดจริงตอนกด "บันทึก" เท่านั้น
- [x] Placeholder เป็นตัวอักษรแรกของ username บนพื้นสี primary (ไม่ใช่ broken image) — ยืนยันด้วย widget test จริงแล้ว
- [x] Persist ผ่าน Supabase `profiles` table จริง (ยังไม่ทดสอบกับ project จริง)
- [x] RLS: insert/update policy เดิมจาก WYN-002 (`auth.uid() = id`) ครอบคลุมฟิลด์ใหม่โดยอัตโนมัติ + เพิ่ม Storage RLS ใหม่เฉพาะ avatar

**หมายเหตุสำคัญ**: เครื่องหมาย [x] หมายถึง "implement แล้วและผ่าน static analysis + unit/widget test" เท่านั้น — ยังไม่ได้ทดสอบ end-to-end กับ Supabase project จริงหรือบนอุปกรณ์จริง (เหมือน WYN-002)

Dependencies: WYN-002 (เสร็จแล้ว, ผ่าน QA รอบ 3)

Priority: สูง — เป็นฐานให้ Feed/Follow ในอนาคต

Risks:
- Permission strings (`NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`, Android `CAMERA`) เพิ่มแล้ว แต่ยังไม่เคยทดสอบ permission flow จริงบนอุปกรณ์
- `supabase/schema.sql` มีการเพิ่ม `alter table`/`add constraint`/storage bucket ใหม่ — ถ้า environment ไหนรัน schema.sql ไปแล้วรอบ WYN-002 ต้องรันซ้ำเฉพาะส่วนใหม่ (ไฟล์เดียวกัน รันซ้ำได้อย่างปลอดภัยสำหรับ column แต่ `add constraint` จะ error ถ้ารันซ้ำสอง — ต้องระวังตอน apply จริง)
- Bio content moderation ยังอยู่นอก scope (ตามที่ระบุไว้ตั้งแต่ Product spec)

Recommendation: ส่งต่อ AI QA & Security สำหรับรีวิว static analysis/test — การทดสอบ end-to-end (permission จริง, อัปโหลดรูปจริง) ต้องรอ Supabase project จริงเหมือน WYN-002

## Coding Output (AI Coding)

Implementation: สร้าง `lib/features/profile/` — `Profile` model, `ProfileRepository` (fetch/update profile, upload avatar to Supabase Storage), `AvatarCircle` widget (placeholder ตัวอักษรแรก), `ViewProfileScreen`, `EditProfileScreen` (image picker action sheet, preview-then-upload-on-save, bio counter with warning color) เพิ่มปุ่มไอคอนโปรไฟล์ใน `HomeScreen` เดิม ขยาย `supabase/schema.sql` เพิ่มคอลัมน์ + length constraints + Storage bucket `avatars` พร้อม RLS เพิ่ม `image_picker` dependency และ permission strings ใน `Info.plist`/`AndroidManifest.xml`

Files Changed:
- `app/pubspec.yaml`, `app/pubspec.lock` (เพิ่ม `image_picker`)
- `app/ios/Runner/Info.plist`, `app/android/app/src/main/AndroidManifest.xml` (permission strings)
- `app/lib/features/profile/data/profile.dart`, `profile_repository.dart` (ใหม่)
- `app/lib/features/profile/presentation/view_profile_screen.dart`, `edit_profile_screen.dart` (ใหม่)
- `app/lib/features/profile/presentation/widgets/avatar_circle.dart` (ใหม่)
- `app/lib/features/home/presentation/home_screen.dart` (เพิ่มปุ่มไอคอนโปรไฟล์)
- `app/test/avatar_circle_test.dart`, `edit_profile_screen_test.dart` (ใหม่ — regression test)
- `supabase/schema.sql` (เพิ่ม column, constraints, storage bucket + RLS)

Reason: Implement WYN-003 ตาม Design Spec เพื่อให้ผู้ใช้มีตัวตนที่สมบูรณ์กว่า username เปล่า ๆ

Tests: เขียน widget test ใหม่ 6 เคส (`avatar_circle_test.dart` 3 เคส, `edit_profile_screen_test.dart` 3 เคส) ครอบคลุม placeholder letter, semantics label, NetworkImage wiring, pre-fill ค่าจาก profile เดิม, ตัวนับ bio อัปเดตตามพิมพ์, ตัวนับเปลี่ยนสีเมื่อใกล้เต็ม — **รันจริงแล้ว: `flutter test` → All tests passed! (12/12 รวมของเดิม)**

ระหว่างเขียน test เจอบั๊กจริง 1 จุดและแก้แล้ว: `AvatarCircle`'s placeholder letter (`Text('N')`) รั่ว semantics เข้าไปรวมกับ label หลัก กลายเป็น `"รูปโปรไฟล์ของ namfah\nN"` แทนที่จะเป็น label เดียวสะอาด ๆ — แก้ด้วย `excludeSemantics: true`

Build:
- `flutter pub get` — สำเร็จ (เพิ่ม `image_picker` และ platform plugins ของมัน)
- `flutter analyze` — **No issues found**
- `flutter test` — **All tests passed! (12/12)**
- `flutter build apk`/`flutter build ios` — ยังไม่ได้รัน (ข้อจำกัดเดิมของ environment นี้ — ไม่มี Android SDK/Xcode)

Known Issues:
- ยังไม่ได้ทดสอบ permission flow จริงบนอุปกรณ์ (ขอ camera/photo library แล้ว user กด allow/deny จริง ๆ)
- ยังไม่ได้ทดสอบอัปโหลดรูปจริงกับ Supabase Storage project จริง
- `supabase/schema.sql` — ถ้า environment ไหนเคย apply ไฟล์นี้จาก WYN-002 ไปแล้ว ต้องรัน section ใหม่ (WYN-003) แยกด้วยความระมัดระวังเรื่อง constraint ซ้ำ (ดู Risks)

Handoff: ส่งต่อ AI QA & Security (`/qa`) สำหรับรีวิว static analysis/test — การทดสอบ end-to-end (permission, อัปโหลดรูปจริง) ต้องรอ Supabase project จริงเหมือน WYN-002
