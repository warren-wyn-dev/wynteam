# Design Spec — WYN-104: หน้า Crop รูปโปรไฟล์ (Pinch-to-zoom + Drag)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-104.md`, `.wyn/docs/product/wyn-104-profile-photo-crop.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/profile/presentation/edit_profile_screen.dart` (`_pickImage()` บรรทัด ~127-148, `_showImageSourceSheet`, avatar preview `CircleAvatar radius: 46` บรรทัด ~265-290), `app/pubspec.yaml` (ยืนยันแล้วว่า**ไม่มี** image-cropping dependency ใดๆ อยู่ในโปรเจกต์วันนี้ — `crop`/`image_cropper`/`crop_your_image` ไม่มีชื่อปรากฏเลย งานนี้เป็น dependency ใหม่จริงตามที่ Product spec ระบุ)
Design system: `WynColors.sapphire`/`paper`/`ink` ตาม `app/lib/core/design/wyn_colors.dart` ปัจจุบัน (Sapphire era) — ไม่มีสีใหม่นอกเหนือจากพื้นเข้ม (ดู Design Rules — ข้อยกเว้นเดียวกับที่ระบบมีอยู่แล้วสำหรับ media viewer เต็มจอ)

---

## Screen 1 — หน้า Crop รูปโปรไฟล์

**Purpose:** ให้ผู้ใช้ปรับตำแหน่ง/ซูมรูปที่เลือกไว้ในกรอบวงกลม ก่อนบันทึกจริง แทนที่การ auto-crop/แสดงวงกลมเฉยๆ แบบเดิมที่ไม่ crop ไฟล์จริงเลย

**User Flow:** ผู้ใช้แตะปุ่มแก้ไข avatar ใน `EditProfileScreen` (`_showImageSourceSheet` เดิม) → เลือก "กล้อง"/"คลังภาพ" (ปุ่มเดิม ไม่เปลี่ยน) → `ImagePicker` เลือกรูปเสร็จ → **เปิดหน้า Crop นี้ทันที** (push เต็มจอ ไม่ใช่กลับไป `EditProfileScreen` ก่อน) → ผู้ใช้ pinch/drag ปรับตำแหน่ง → กด "เสร็จสิ้น" → crop จริงเกิดขึ้น → pop กลับไป `EditProfileScreen` พร้อมรูปที่ crop แล้วเป็น preview ใหม่ (แทนที่ `_pickedImageBytes` เดิม) → กด "บันทึก" ตามปกติ (timing การอัปโหลดไม่เปลี่ยน ยังอัปโหลดตอนกด "บันทึก" เหมือนเดิม)

**Components:**
```
┌─────────────────────────────────────┐
│ ยกเลิก      ปรับตำแหน่งรูป      เสร็จสิ้น │  ← AppBar เข้ม, ข้อความ/ปุ่มสีขาว
├─────────────────────────────────────┤
│                                       │
│         ┌───────────┐                │
│         │  ⬤ วงกลม   │                │  ← พื้นหลังเข้ม (นอกวงกลม)
│         │  preview   │                │     รูปอยู่ในวงกลม (ในกรอบ)
│         │  (รูปที่    │                │
│         │  เลือกไว้) │                │
│         └───────────┘                │
│                                       │
│         [ −  ━━━●━━  + ]              │  ← แถบซูมสำรอง +/- (accessibility)
│                                       │
└─────────────────────────────────────┘
```
- **AppBar**: พื้นเข้มเดียวกับพื้นหลังทั้งหน้า (ไม่ใช่ `WynColors.paper` มาตรฐาน — ดู Design Rules) — ปุ่ม "ยกเลิก" (ซ้าย, `TextButton` สีขาว), หัวข้อ "ปรับตำแหน่งรูป" (กึ่งกลาง, สีขาว), ปุ่ม "เสร็จสิ้น" (ขวา, `TextButton` สีขาว ตัวหนา — primary action ของหน้านี้)
- **พื้นหลังหน้า**: สีเข้ม (`Colors.black` หรือใกล้เคียง — มิเรอร์ pattern เดียวกับ media viewer เต็มจอที่ระบบมีอยู่แล้ว เช่น Pop clip view/`DropImageViewer` ของ WYN-071 Screen 4 ที่ใช้ "พื้นดำเสมอ ไม่ผูกกับ theme หลักที่ fix เป็น light — media viewer เป็นข้อยกเว้นที่มีอยู่แล้วในระบบ") — **นี่คือ precedent เดียวกันที่ทำให้พื้นเข้มของหน้านี้ไม่ขัดกับกติกา "ห้ามคิดทิศทาง visual ใหม่"** เพราะเป็น pattern ที่มีอยู่แล้วในระบบสำหรับบริบท "ตัดต่อ/ดูรูปเต็มจอ" ไม่ใช่ผิวธีมทั่วไป
- **วงกลม preview**: กึ่งกลางจอ ขนาดคงที่ (ไม่ปรับตามรูป ตาม Product spec) — ส่วนนอกวงกลม (มุมสี่เหลี่ยมรอบๆ) ทึบเข้ม/มี overlay ทึบแสงเพื่อให้กรอบวงกลมเด่นชัด (มิเรอร์ mask overlay มาตรฐานของ image cropper — ไม่ใช่แนวคิดใหม่ เป็น pattern สากลที่ผู้ใช้คุ้นเคยจาก IG/FB ตามที่ Product spec เทียบไว้)
- **แถบซูมสำรอง +/-**: ใต้วงกลม preview — `IconButton(Icons.remove)` + `Slider` (หรือเทียบเท่า) + `IconButton(Icons.add)` — **บังคับมีตาม Product spec Edge Case 5 (accessibility)** ไม่ใช่ optional เพราะ pinch gesture ใช้กับ screen reader ไม่ได้ ทุกสีบนแถบนี้เป็นสีขาว/เทาอ่อนตัดกับพื้นเข้ม (ไม่ใช้ sapphire เพราะพื้นเข้มไม่ตัดกับ sapphire ให้ contrast พอ — ใช้ `Colors.white`/`Colors.white70` แทน)

**Interactions:**
- **Pinch-to-zoom** (2 นิ้ว): ซูมรูปภายในกรอบวงกลม ตั้งแต่ 1.0x (fit วงกลมพอดี ไม่ให้เห็นขอบว่าง) ถึงอย่างน้อย 3.0x
- **Drag** (1 นิ้ว): ลากรูปขยับตำแหน่งภายในกรอบ (rubber-band/bounded ไม่ให้ลากจนเห็นขอบว่างในวงกลม)
- แถบ +/- ซิงค์กับ gesture (ปรับ slider แล้วรูป zoom ตาม และในทางกลับกัน pinch แล้ว slider ขยับตาม)
- แตะ "ยกเลิก" → pop กลับ `EditProfileScreen` โดยรูปเดิมไม่เปลี่ยนแปลง (เหมือนไม่เคยกดเลือกรูปใหม่เลย ตาม Product spec Edge Case 1)
- แตะ "เสร็จสิ้น" → คำนวณ crop rectangle จริงจากตำแหน่ง/ซูมปัจจุบัน → crop เป็นสี่เหลี่ยมจัตุรัส (ไม่ใช่วงกลมจริงมี alpha — ตาม Product spec) → pop กลับพร้อม bytes ที่ crop แล้ว

**States:**
- รูปแนวนอน/แนวตั้งสุดขั้ว (panorama) → บังคับ min zoom ให้ด้านสั้นกว่าเต็มพอดีวงกลมเสมอ (ไม่มีขอบว่าง)
- EXIF orientation จากกล้องมือถือ → ต้องอ่าน/แก้ orientation ก่อนเข้าสู่หน้านี้ (แสดงถูกทิศทางตั้งแต่เฟรมแรกที่เห็น ไม่ใช่หมุนผิดแล้วค่อยแก้)
- ระหว่างกำลังประมวลผล crop จริง (หลังกด "เสร็จสิ้น") → ปุ่ม "เสร็จสิ้น" แสดง `CircularProgressIndicator` เล็กแทน label ชั่วคราว (กันกดซ้ำ) — ถ้าประมวลผลเร็วมาก (client-side, ไม่มี network call) อาจไม่ทันเห็น state นี้เลยก็ได้ ไม่ใช่ requirement บังคับต้องมี delay เทียม

**Responsive Behavior:** ทดสอบทั้ง 3 platform (iOS/Android/Web ตาม Product spec Acceptance Criteria) — ขนาดวงกลม preview ปรับตามความกว้างจอที่แคบสุด (360px) ไม่ให้ล้นขอบซ้าย-ขวา แถบ +/- ต้องไม่แน่นจนกดพลาดที่จอแคบ (ใช้ `WynSpacing.touchTargetMin` 44px เป็นขนาดขั้นต่ำของปุ่ม +/-)

**Accessibility:**
- แถบ +/- คือทางเข้าถึงหลักสำหรับผู้ใช้ screen reader (ไม่พึ่ง gesture อย่างเดียว ตาม Product spec Edge Case 5)
- ปุ่ม "ยกเลิก"/"เสร็จสิ้น" มี `Semantics(button: true)` มาตรฐาน, label ชัดเจนตรงตัว
- Slider มี `Semantics(label: 'ระดับการซูม', value: '...')`

**Design Rules:**
- **ข้อยกเว้นสีเดียวของเอกสารนี้**: พื้นหลังเข้ม/ปุ่ม AppBar สีขาว — อนุญาตเพราะมี precedent อยู่แล้วในระบบสำหรับบริบท media-editing เต็มจอ (WYN-071 Screen 4, Pop clip view) **ไม่ใช่การคิดทิศทางสีใหม่** — ทุกอย่างอื่นนอกเหนือจากพื้นเข้ม/ปุ่มขาวยังต้องอ้างอิง `WynColors` ปกติ (เช่น ถ้ามี error state ให้ใช้ `WynColors.errorLight`/`errorDark` ตามบริบท ไม่ใช่คิดสีแดงใหม่)
- ไม่มี "Liquid Glass"/blur effect ใหม่ใดๆ (ตาม Product spec Handoff เตือนไว้ตรงๆ)

**Handoff:** AI Coding — widget ใหม่ `ProfilePhotoCropScreen`, เรียกจาก `EditProfileScreen._pickImage()` ทันทีหลัง `ImagePicker` คืนค่ารูปมา (ก่อน `setState(() => _pickedImageBytes = ...)` เดิม — เปลี่ยนเป็น push หน้านี้ก่อน แล้ว `setState` เมื่อได้ผลลัพธ์ crop กลับมาเท่านั้น) — **ต้องยืนยัน package ก่อนติดตั้งจริง**: Product spec แนะนำ `crop_your_image` (pure-Dart, ไม่พึ่ง native platform channel, เข้ากับ Web ที่โปรเจกต์ target) แทน `image_cropper` (native, มีข้อจำกัดบน Web ที่ทราบแล้ว) — AI Coding ต้องเช็คว่า package ที่เลือก maintain ดีและรองรับ Flutter SDK เวอร์ชันปัจจุบันของโปรเจกต์จริงก่อนเพิ่มเข้า `pubspec.yaml` (ไม่ใช่จุดตัดสินใจ pixel-level ของ AI Design — เป็นการตัดสินใจ technical dependency ที่ต้องยืนยันซ้ำตอน implement ตาม Product spec เอง)

---

## Out of Scope (ตรงตาม Product spec — ไม่ออกแบบเพิ่ม)

- Crop รูปปก Club (`CreateClubScreen`/`EditClubInfoScreen`'s cover picker, 16:9 ไม่ใช่วงกลม) — Founder ระบุเฉพาะรูปโปรไฟล์เท่านั้น
- Filter/effect รูป (ความสว่าง/contrast ฯลฯ)
- Crop รูปโพสต์ (Drop/Club post images)
- บันทึกตำแหน่ง crop ไว้แก้ไขซ้ำภายหลัง (one-way operation ต่อการอัปโหลดครั้งนั้น)

## Handoff รวม

ส่งต่อ **AI Coding** (`/code`) — ไม่มี data model ใหม่ (`profiles.avatar_url` เก็บ URL เดิม เปลี่ยนแค่ไฟล์ที่ถูกอัปโหลดให้เป็นรูปที่ crop แล้วแทนรูปดิบ) ความเสี่ยงหลักคือ (1) เลือก/ติดตั้ง package ที่รองรับ 3 platform จริง (2) EXIF orientation handling ให้ถูกต้องบนอุปกรณ์จริงหลายรุ่น (โดยเฉพาะกล้อง iOS ตาม Product spec Risk R2) — QA ต้องทดสอบทั้งสองประเด็นนี้เป็นพิเศษก่อน deploy
