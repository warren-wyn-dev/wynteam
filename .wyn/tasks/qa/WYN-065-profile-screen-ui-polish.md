# Product Task — WYN-065

Status: coded, self-verified (flutter analyze 0 issues, flutter test 768/768) — รอ AI QA & Security อิสระ
Owner: AI Product Manager → AI Design (ตรวจสอบของเดิมก่อนออกแบบใหม่) → AI Coding (เสร็จ) → AI QA & Security (รอ)

Feature: Profile Screen — UI/UX Polish (4 จุด)

Goal: ปรับปรุง UI/UX ของ `ViewProfileScreen` (Bottom Nav → Profile tab) ตาม 4 รายการที่ Founder ระบุ: Layout & Alignment, Visual Hierarchy, Grid Layout, Loading State

Target User: ผู้ใช้ WYN Social ทุกคนที่เข้าหน้าโปรไฟล์ (ตัวเองหรือคนอื่น)

Problem / Requirements (แยกตามรายการที่ Founder ระบุ):

**R1. Layout & Alignment**: ปุ่ม "แก้ไขโปรไฟล์" แคบเกินไป (พอดีกับความยาวข้อความเท่านั้น ไม่สมดุลกับความกว้างจอ) และไอคอน Settings/Logout บน Top Navigation Bar ชิดกันเกินไป (ไม่มี gap ระหว่างสองปุ่ม)

**R2. Visual Hierarchy**: ตรวจสอบแล้ว — ตัวเลข "ผู้ติดตาม"/"กำลังติดตาม" (`_FollowCountTarget`) มี `fontWeight: FontWeight.bold` อยู่แล้วตั้งแต่ WYN-013 **ไม่ต้องแก้ไขเพิ่ม** รายการนี้ผ่านอยู่แล้ว

**R3. Grid Layout**: ตรวจสอบแล้ว — Grid ทั้ง 3 คอลัมน์ (`DropGridTile`/`SavedGridTile`/`PopGridTile`/`DraftGridTile`) ทุกตัวใช้ `AspectRatio(aspectRatio: 1)` + `Image.network(..., fit: BoxFit.cover)` อยู่แล้ว (1:1 square crop เท่ากันทุกรูปจริง) และ Overlay ที่มีอยู่ (like-count scrim บน `DropGridTile`) เป็นแถบ gradient บางๆ แค่ขอบล่างสุดเท่านั้น ไม่ทับเนื้อหาสำคัญกลางภาพอยู่แล้ว **ไม่ต้องแก้ไขเพิ่ม** รายการนี้ผ่านอยู่แล้วเช่นกัน

**R4. Loading State**: หน้าจอโหลด initial fetch (`_loadFuture`) แสดงแค่ `CircularProgressIndicator` กลางจอเปล่าๆ ไม่มีโครงร่างของเนื้อหาที่กำลังจะมา

Acceptance Criteria:
- [x] ปุ่ม "แก้ไขโปรไฟล์" กว้างเต็มพื้นที่ที่มี (เท่ากับความกว้างจอลบ padding มาตรฐาน) ไม่ใช่แค่พอดีข้อความ
- [x] ไอคอน Settings และ Logout บน Top Navigation Bar มี gap ระหว่างกันชัดเจน ไม่ชิดกันเกินไป
- [x] ตัวเลข "ผู้ติดตาม"/"กำลังติดตาม" หนา (Bold) — ยืนยันว่าผ่านอยู่แล้ว ไม่มี regression
- [x] Grid 3 คอลัมน์ทุก tab ใช้ Aspect Ratio 1:1 เท่ากันทุกรูป — ยืนยันว่าผ่านอยู่แล้ว ไม่มี regression
- [x] หน้าจอโหลด initial fetch แสดง Skeleton Loading (โครงร่าง avatar/ชื่อ/จำนวนติดตาม/ปุ่ม/grid) แทน spinner เปล่ากลางจอ
- [x] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression

Dependencies: ไม่มี — ปรับ `ViewProfileScreen` (WYN-003/WYN-013) ที่ผ่าน QA แล้ว ไม่แตะ schema/repository ใดๆ เป็น UI-layer ล้วนๆ

Priority: ต่ำ-กลาง — คุณภาพ UX ล้วนๆ ไม่บล็อกฟีเจอร์อื่น ความเสี่ยงต่ำมาก

Risks: ต่ำมาก — ไม่มี schema/repository change, ไม่แตะ logic ทางธุรกิจใดๆ ความเสี่ยงเดียวคือ Skeleton ใหม่ต้องไม่ทำให้ layout ของเนื้อหาจริง (หลังโหลดเสร็จ) เปลี่ยนไป — ตรวจสอบแล้วว่า `ProfileSkeleton` เป็น widget แยกที่แสดงเฉพาะระหว่าง `!snapshot.hasData` เท่านั้น ไม่กระทบ tree ของเนื้อหาจริง

Recommendation: R2/R3 ตรวจสอบโค้ดที่มีอยู่แล้วก่อนเริ่มแก้ พบว่าผ่านอยู่แล้วทั้งคู่ (ป้องกันการแก้ไขซ้ำซ้อนโดยไม่จำเป็น) — เหลือแค่ R1/R4 ที่ต้องแก้จริง

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบอิสระตาม Acceptance Criteria ทั้งหมด โดยเฉพาะการดูภาพจริง (screenshot) ของ Skeleton Loading และปุ่ม "แก้ไขโปรไฟล์" ที่ความกว้างจอจริงหลายขนาด เพราะ widget test พิสูจน์ได้แค่ขนาด/โครงสร้าง ไม่ใช่ความสวยงามที่ตาเห็นจริง

---

## Design Output

ตรวจสอบ `.wyn/docs/design/wyn-003-user-profile.md`/`wyn-013-profile-v2.md` และโค้ดจริงก่อน — ยืนยันว่า R2 (bold follower count)/R3 (1:1 grid + non-obscuring overlay) มีอยู่แล้วจริงตาม design system เดิม ไม่ใช่ gap ให้แก้ ส่วน R1/R4 ไม่ต้องมี design spec แยก:
- R1: ปุ่ม "แก้ไขโปรไฟล์" → `SizedBox(width: double.infinity, child: OutlinedButton(...))` มาตรฐานเดียวกับปุ่มเต็มความกว้างที่อื่นในแอป — ไอคอน Settings/Logout → เพิ่ม `SizedBox(width: WynSpacing.space2)` คั่นระหว่างสองปุ่ม (token มาตรฐานของ design system เดิม ไม่ใช่ค่าใหม่)
- R4: Skeleton แทน spinner — placeholder แบบ static block (ไม่ animate/shimmer) ใช้สี `colorScheme.surfaceContainerHighest` มิเรอร์โครงสร้างจริงของหน้าจอ (avatar circle → 2 บรรทัดข้อความ → แถวตัวเลข 2 ช่อง → ปุ่มเต็มความกว้าง → grid 3 คอลัมน์) เหตุผลที่ไม่ animate: หลีกเลี่ยงปัญหา indeterminate-animation ที่ทำให้ `pumpAndSettle` ค้างไม่จบ ซึ่งโปรเจกต์นี้เคยเจอและบันทึกไว้แล้วใน `delete_account_screen_test.dart`/`zoky_checkout_summary_screen_test.dart`

## Coding Output (2026-08-24)

**Implementation**:
- `app/lib/features/profile/presentation/view_profile_screen.dart`: (R1) ห่อปุ่ม "แก้ไขโปรไฟล์" ด้วย `SizedBox(width: double.infinity, ...)`, เพิ่ม `SizedBox(width: WynSpacing.space2)` คั่นระหว่างไอคอน Settings/Logout (และหลัง Logout อีกจุดก่อนขอบจอ) — (R4) เปลี่ยน `if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }` เป็น `return const ProfileSkeleton();`
- `app/lib/features/profile/presentation/widgets/profile_skeleton.dart` (ไฟล์ใหม่): `ProfileSkeleton` widget — placeholder block สีทึบ (ไม่ shimmer) มิเรอร์โครงสร้างจริง (avatar/ชื่อ/username/จำนวนติดตาม 2 ช่อง/ปุ่มเต็มความกว้าง/grid 3 คอลัมน์ 9 ช่อง) ห่อด้วย `SingleChildScrollView` กันจอเตี้ย overflow
- R2/R3: **ไม่แก้ไขโค้ด** — ตรวจสอบแล้วผ่านอยู่แล้วตาม Design Output ข้างต้น

**Files Changed**:
- `app/lib/features/profile/presentation/view_profile_screen.dart`
- `app/lib/features/profile/presentation/widgets/profile_skeleton.dart` (ใหม่)
- `app/test/view_profile_screen_test.dart` (เพิ่ม 2 เทส: skeleton แสดง/หายถูกจังหวะ, ปุ่ม Edit กว้าง >400px)

**Reason**: ตรงตาม Acceptance Criteria ทุกข้อ — R2/R3 ข้ามการแก้ไขเพราะพิสูจน์แล้วว่าผ่านอยู่แล้วจริงในโค้ด ป้องกันการแก้ไขที่ไม่จำเป็น (ตรงตามหลัก "เปลี่ยนแปลงให้น้อยที่สุด" ของ AGENTS.md)

**Tests**: `flutter analyze` — 0 issues. `flutter test` (ทั้ง suite) — **768/768 PASS** ไม่มี regression กับ Profile/Follow/Block/Mute/Club/Chat/Draft/ReDrop/Saved เดิมทั้งหมด

**Known Issues**:
- Skeleton เป็นการประมาณโครงร่างคงที่ (9 ช่อง grid เสมอ) ไม่ได้สะท้อนจำนวนเนื้อหาจริงที่กำลังจะโหลดมา (เป็นเรื่องปกติของ skeleton loading ทั่วไป ไม่ใช่บั๊ก)
- ยังไม่เคยเห็นภาพจริงบนอุปกรณ์/browser จริง (ไม่มี Flutter run environment ที่ render ภาพได้ในเซสชันนี้) — ตรวจสอบด้วย widget test + อ่านโค้ดเทียบ design เท่านั้น

**Handoff**: ส่งต่อ AI QA & Security — เน้นตรวจภาพจริงของ Skeleton Loading และปุ่ม Edit ที่ความกว้างจอจริงหลายขนาด (360/375/390/414/430px) ตามธรรมเนียมเดิมของโปรเจกต์นี้
