# Design Spec — WYN-025: Drop Composer Polish (JPEG fix / Draft UX / Fullscreen Viewer)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-025-drop-composer-polish.md`
อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md`, `.wyn/docs/design/ds-001-color-system.md` (palette ปัจจุบัน Cyan/Black/White/Gray, ห้าม Liquid Glass) — งานนี้ไม่เพิ่ม color token ใหม่จุดใดเลย
อ้างอิง Pattern ที่มีอยู่แล้ว (ต้อง reuse ตรงๆ ไม่ประดิษฐ์ใหม่):
- `confirmDeletePost`/`confirmDeleteDrop` (`app/lib/core/widgets/confirm_delete_dialog.dart`, `app/lib/features/drop/presentation/widgets/confirm_delete_drop_dialog.dart`) — `AlertDialog` แบบสั้น: title จบด้วย "?", content เป็นประโยคผลลัพธ์สั้นๆ, 2 ปุ่ม `TextButton` ("ยกเลิก" / คำกริยาเดี่ยว) ไม่มีสีพิเศษ
- `CreateDropScreen` (`app/lib/features/drop/presentation/create_drop_screen.dart`) ปัจจุบัน: ทางออกเดียวที่มีอยู่คือ AppBar leading `IconButton(Icons.close)` เรียก `Navigator.of(context).pop(false)` ตรงๆ — **ไม่มี `PopScope`/`WillPopScope` ที่ไหนในโปรเจกต์เลย** (ตรวจด้วย grep ทั้ง `app/lib` แล้วไม่พบ) แปลว่าปุ่ม back ของระบบ (Android hardware back / iOS swipe-back) ปิดหน้านี้ได้ตรงๆ อยู่แล้วโดยไม่มีการดักจับใดๆ ทั้งสิ้นในปัจจุบัน
- `DropDetailScreen` (`app/lib/features/drop/presentation/drop_detail_screen.dart`) แสดงรูปด้วย `AspectRatio(aspectRatio: 1, child: Image.network(_drop.imageUrl, fit: BoxFit.cover))` — แตะแล้วไม่มีอะไรเกิดขึ้นในปัจจุบัน
- **ไม่มี draft-persistence pattern ใดๆ ในโปรเจกต์เลย** (grep `draft|Draft` ทั้ง `app/lib` ไม่พบไฟล์) — pattern local-storage เดียวที่มีคือ `pop_mute_preference.dart` ซึ่งเก็บแค่ `bool` เดียวผ่าน `shared_preferences` (ไม่เทียบเท่ากับการเก็บ caption+รูปภาพ)
- `pubspec.yaml` ปัจจุบัน**ไม่มี** `path_provider`/`photo_view`/package ซูมรูปใดๆ เลย — มีแค่ `image_picker`/`share_plus`/`video_player`/`video_thumbnail`/`shared_preferences`/`firebase_*`

## ทิศทางภาพรวม

งานนี้เป็นงาน "ต่อยอด/แก้ gap" ไม่ใช่ทิศทาง visual ใหม่ — R1 ไม่ต้องมี Design เลยตามที่ Product Task ระบุตรงๆ R2 ต้อง**เลือกแนวทาง** ระหว่าง dialog ยืนยัน vs auto-save (อ่านโค้ดจริงแล้วตัดสินใจด้านล่าง) R3 ต้องออกแบบ widget ใหม่ 1 ตัวโดยใช้ `InteractiveViewer` ในตัว Flutter เท่านั้น ไม่มีจุดใดในงานนี้ที่ต้องคิด color/typography/layout language ใหม่ — ทุกอย่าง reuse ของเดิม

---

## R1: JPEG re-encode fix — ไม่ต้อง Design

ตามที่ Product Task ระบุไว้ตรงๆ ว่าเป็น bug fix ล้วนๆ (เปลี่ยน output format ของ `centerCropToSquare()` ใน `square_crop.dart` จาก PNG เป็น JPEG) ไม่มีการเปลี่ยนหน้าตา/พฤติกรรมที่ผู้ใช้เห็นเลย (ผู้ใช้ยังเห็น preview รูปสี่เหลี่ยมจัตุรัสเหมือนเดิมทุกประการ) — ไม่มีจุดใดต้องตัดสินใจเรื่อง HOW เพิ่ม ส่งตรง AI Coding

Reference สำหรับ AI Coding (ระบุข้อมูลทางเทคนิคที่ตรวจสอบแล้วเพื่อความชัดเจน ไม่ใช่ design decision): `dart:ui`'s `ui.ImageByteFormat` enum มีแค่ `rawRgba`/`rawStraightRgba`/`rawUnmodified`/`png` — **ไม่มีตัวเลือก JPEG ให้เลือกเลย** ดังนั้นการ encode เป็น JPEG จริงจะทำด้วย `dart:ui` อย่างเดียวไม่ได้ ต้องเพิ่ม package `image` (pub.dev, ไม่ใช่ `image_picker` ที่มีอยู่แล้ว) เพื่อ decode `ui.Image`/raw RGBA แล้ว re-encode เป็น JPEG คุณภาพ 85-90 ตามที่ Product Task ระบุ — เป็น dependency ใหม่ 1 ตัวที่ประเมินแล้วว่าจำเป็นจริง (ไม่ใช่ overengineer) เพราะไม่มีทางเลือกอื่นในตัว Flutter/dart:ui ที่ทำ JPEG encode ได้

---

## R2: Draft Persistence UX

Screen/Component: `CreateDropScreen` (`app/lib/features/drop/presentation/create_drop_screen.dart`)

### การวิเคราะห์ก่อนตัดสินใจ

อ่านโค้ดจริงแล้วพบว่าโปรเจกต์นี้**ไม่มี pattern ของทั้งสองแนวทางอยู่ก่อนเลย** ทั้ง (ก) confirm-dialog-on-exit และ (ข) auto-save-draft จึงต้องตัดสินใจจากปัจจัยอื่น:

1. **(ข) Auto-save ต้องเก็บทั้ง caption *และ* รูปภาพที่ crop แล้ว** (`Uint8List`, ขนาดหลัง crop+compress อาจถึงหลักร้อย KB) ให้รอดจากการปิดแอปสนิท (Product Task ระบุ "ออกจากหน้าจอโดยยังไม่ publish (กดปุ่ม back, **สลับแอป**, **โทรศัพท์เข้า**)") — เก็บ string (caption) ด้วย `shared_preferences` ทำได้ตรงไปตรงมา แต่เก็บ **ไฟล์รูปภาพแบบ binary ให้รอดข้าม process** ต้องเขียนลงไฟล์จริงบนเครื่อง ซึ่งต้องเพิ่ม dependency ใหม่ (`path_provider` หรือเทียบเท่า — ไม่มีอยู่ใน `pubspec.yaml` ปัจจุบันเลย) เก็บ `base64` string ยาวๆ ใน `shared_preferences` เป็น anti-pattern ที่ไม่ควรทำ (ช้า, เสี่ยงชน quota ของ platform, ไม่ตรงกับที่ `shared_preferences` ถูกออกแบบมาใช้)
2. **(ข) ยังต้องตัดสินใจ UX เพิ่มอีกชั้น**: เจอ draft เดิมตอนเปิดหน้าใหม่แล้วควร "restore เงียบๆ" หรือ "ถามก่อน" — ถ้าถามก่อนก็วนกลับไปมี dialog อยู่ดี (แค่ย้ายจังหวะจาก "ตอนออก" เป็น "ตอนเข้า") ถ้า restore เงียบๆ ผู้ใช้ที่ตั้งใจ "เริ่มใหม่" ทุกครั้งจะเจอรูป/ข้อความเก่าโผล่มาโดยไม่ได้ขอ ซึ่งขัดกับ Gen Z tone ที่เน้น "ไม่งง ไม่เซอร์ไพรส์" ใน `design-principles.md`
3. **(ก) Confirm-dialog ไม่ต้องเก็บอะไรลงดิสก์เลย** — เช็คแค่ "ตอนนี้มีข้อความ/รูปค้างอยู่ใน memory ไหม" (`_captionController.text`/`_imageBytes` ที่มีอยู่แล้ว) แล้วถามตรงจุดที่ผู้ใช้พยายามออก ไม่ต้องมี dependency ใหม่ ไม่ต้องมี state เพิ่มนอกเหนือจาก field ที่มีอยู่แล้ว
4. **(ก) ตรงกับ convention ที่โปรเจกต์นี้ใช้ซ้ำแล้วซ้ำอีก**: `confirmDeletePost`/`confirmDeleteDrop` คือ pattern "ถามยืนยันก่อน action ที่ทำลายข้อมูล/กู้คืนไม่ได้" ที่มีอยู่แล้ว 2 จุด — การออกจากหน้าที่มีเนื้อหาค้างโดยไม่ publish ก็เป็น "action ที่ทำลายข้อมูล (draft ที่พิมพ์ไว้)" ในทางความหมายเดียวกันเป๊ะ ใช้โครงหน้าตา dialog เดียวกันได้ทันทีโดยไม่ต้องคิด pattern ใหม่
5. Product Task's Recommendation เองก็ระบุให้ "AI Design ตัดสินใจ UX ของ R2 ... ให้สอดคล้องกับ pattern ที่โปรเจกต์นี้เคยใช้ (ถ้ามี)" — เมื่อไม่มี pattern ของทั้งสองแนวทางอยู่ก่อน เกณฑ์ตัดสินจึงเป็น "แนวทางไหนเพิ่ม complexity/dependency น้อยที่สุดและใกล้เคียงของเดิมที่สุด" ซึ่งคือ (ก)

### Decision: เลือกแนวทาง (ก) — Dialog ยืนยัน "ทิ้งการเปลี่ยนแปลง?"

**ไม่ทำ local draft persistence ข้ามการปิดแอป** — เมื่อผู้ใช้พยายามออกจาก `CreateDropScreen` ขณะมี caption หรือรูปค้างอยู่ (ยังไม่กด "แชร์" สำเร็จ) ไม่ว่าจะออกทางไหน (ปุ่มปิดมุมซ้ายบน หรือปุ่ม/ท่าทาง back ของระบบ) ให้เด้ง dialog ถามยืนยันก่อนเสมอ ถ้าผู้ใช้ยืนยัน "ทิ้ง" ถึงจะออกจริง — สลับแอป/โทรศัพท์เข้าไม่ได้ทำให้ widget ถูก dispose (แค่ pause ที่ background) จึง state ใน memory (`_captionController`/`_imageBytes`) ยังอยู่ครบเมื่อกลับมาที่แอปอยู่แล้วโดยธรรมชาติ ไม่ต้องทำอะไรเพิ่มสำหรับเคสนี้

**ผลต่อ Acceptance Criteria ข้อ "Publish สำเร็จแล้ว draft ที่เก็บไว้ต้องถูกล้างทิ้ง"**: ภายใต้แนวทางนี้**ไม่มี draft ถูกเก็บลงที่ไหนเลยตั้งแต่ต้น** (state อยู่ใน memory ของ `State` object เท่านั้น) ดังนั้นเงื่อนไขนี้เป็นจริงโดยอัตโนมัติ — พอ publish สำเร็จ `Navigator.of(context).pop(true)` ทำให้ `CreateDropScreen`'s State ถูก dispose ไปเลย ไม่มีอะไรให้ "ล้างทิ้ง" เพิ่มเติม บันทึกไว้ตรงนี้ให้ QA รอบถัดไปเข้าใจตรงกันว่า AC ข้อนี้ผ่านโดยธรรมชาติของสถาปัตยกรรม ไม่ใช่ช่องโหว่ที่ถูกมองข้าม

### Components

1. **Dialog ใหม่**: `confirmDiscardChanges(BuildContext context)` — ไฟล์ใหม่ `app/lib/core/widgets/confirm_discard_dialog.dart` (อยู่คู่กับ `confirm_delete_dialog.dart` ที่มีอยู่แล้ว ไม่ใช่ไฟล์เดียวกัน เพราะความหมาย action ต่างกัน — อันหนึ่งลบข้อมูลถาวร อีกอันคือออกจากหน้าจอ) โครงเดียวกับ `confirmDeletePost` เป๊ะ:
   ```
   Future<bool> confirmDiscardChanges(BuildContext context) async {
     final confirmed = await showDialog<bool>(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('ทิ้งการเปลี่ยนแปลง?'),
         content: const Text('สิ่งที่พิมพ์หรือเลือกไว้จะหายไปถ้าออกตอนนี้'),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(false),
             child: const Text('ยกเลิก'),
           ),
           TextButton(
             onPressed: () => Navigator.of(context).pop(true),
             child: const Text('ทิ้ง'),
           ),
         ],
       ),
     );
     return confirmed ?? false;
   }
   ```
   ตั้งใจให้เป็น widget กลางที่ reuse ได้กับ composer อื่นในอนาคต (`CreatePopScreen` มีปัญหาเดียวกันทุกประการแต่**ไม่อยู่ในขอบเขตของ WYN-025** — ดู Non-goal ด้านล่าง) เหมือนที่ `confirm_delete_dialog.dart` เป็นกลางให้ Drop/Pop/Comment ใช้ร่วมกันอยู่แล้ว
2. **`CreateDropScreen` เพิ่ม**:
   - getter `_hasUnsavedContent` — `_captionController.text.trim().isNotEmpty || _imageBytes != null`
   - ห่อ `Scaffold` เดิมทั้งก้อนด้วย `PopScope` (Flutter's ตัวปัจจุบัน ไม่ใช่ `WillPopScope` ที่ deprecated แล้ว):
     - `canPop: !_isSharing && !_hasUnsavedContent`
     - `onPopInvokedWithResult`: ถ้า `didPop` เป็น true ไม่ต้องทำอะไร (ปิดไปแล้วปกติ) ถ้าเป็น false: ถ้า `_isSharing` ให้ไม่ทำอะไรเลย (บล็อกเงียบๆ ไม่เด้ง dialog — ดูเหตุผลด้านล่าง) ไม่งั้นเรียก `confirmDiscardChanges(context)` แล้ว pop จริงถ้าผู้ใช้เลือก "ทิ้ง"
   - เมธอดใหม่ `_requestExit()` ที่ทำ logic เดียวกัน (เช็ค `_hasUnsavedContent` → ถ้าไม่มีก็ `pop(false)` ตรงๆ, ถ้ามีก็ถามก่อน) — ใช้ทั้งจาก `onPopInvokedWithResult` และจาก AppBar close button (ข้อ 3) เพื่อไม่ให้ logic ซ้ำสองที่
   - AppBar's leading `IconButton(Icons.close)`: `onPressed: _isSharing ? null : _requestExit` (เดิมเรียก `pop(false)` ตรงๆ ไม่มีเงื่อนไข) — ปุ่มนี้ disable ระหว่าง `_isSharing` เพื่อให้สอดคล้องกับ input อื่นทั้งหมดในหน้านี้ที่ disable ระหว่าง sharing อยู่แล้ว (`MentionInput`'s `enabled: !_isSharing`)

### Interactions

- พิมพ์ caption หรือเลือกรูปแล้ว กด X มุมซ้ายบน → เด้ง dialog "ทิ้งการเปลี่ยนแปลง?" → กด "ยกเลิก" กลับมาหน้าเดิม เนื้อหาที่พิมพ์/เลือกไว้ยังอยู่ครบ (ไม่มีอะไรถูกล้าง) → กด "ทิ้ง" ออกจากหน้าจอจริง กลับไป Drop Feed
- พิมพ์ caption หรือเลือกรูปแล้ว กด back ของระบบ (Android hardware back / iOS swipe-back gesture) → พฤติกรรมเดียวกับปุ่ม X ทุกประการ (dialog เดียวกัน ผ่าน `PopScope`)
- ยังไม่ได้พิมพ์อะไร/ยังไม่เลือกรูป กด X หรือ back → ออกทันที ไม่มี dialog (เหมือนพฤติกรรมเดิมของหน้านี้ทุกประการ — ไม่มี regression สำหรับเคสปกติ)
- ระหว่างกำลัง "แชร์" (`_isSharing == true`, มีรูป+อาจมี caption แน่นอนเพราะรูปเป็นเงื่อนไขบังคับก่อน "แชร์" กดได้) กด X (ถูก disable กดไม่ได้อยู่แล้ว) หรือกด back ของระบบ → **ถูกบล็อกเงียบๆ ไม่มี dialog** เหตุผล: ผู้ใช้ไม่ได้ "ตัดสินใจจะออก" อยู่แล้ว (ไม่ได้กดอะไรตั้งใจ) การเด้ง dialog ทับตอนกำลังอัปโหลดจะสับสน (ทั้ง network call ที่กำลังวิ่งอยู่ และ dialog ที่ค้าง) จึงเลือกบล็อกทื่อๆ แทน สอดคล้องกับที่หน้านี้ disable input อื่นทั้งหมดระหว่าง sharing อยู่แล้ว
- publish สำเร็จ (`_share()`'s success path เรียก `Navigator.of(context).pop(true)` ตรงๆ) → **ไม่ผ่าน `_requestExit()`/dialog เลย** เพราะเป็นการเรียก `Navigator.pop()` แบบ imperative จาก event handler ของโค้ดเอง ไม่ใช่ back gesture/ปุ่ม back ของระบบ — ตาม Flutter's documented behavior ของ `PopScope`, `canPop`/`onPopInvokedWithResult` มีผลเฉพาะกับการ pop ที่ระบบเริ่ม (system back button/gesture) หรือเรียกผ่าน `Navigator.maybePop()` เท่านั้น ไม่ครอบคลุมการเรียก `Navigator.pop()` ตรงๆ แบบนี้ — ดังนั้นไม่ต้องแก้ `_share()` เลย ออกจากหน้าจอได้ปกติทันทีที่ publish สำเร็จเหมือนเดิมทุกประการ

### States

ไม่มี state ใหม่ที่ต้องเพิ่มนอกเหนือจาก getter `_hasUnsavedContent` (คำนวณสดจาก field ที่มีอยู่แล้ว ไม่ cache) — ไม่มี state persist ข้าม session ตามที่ตัดสินใจไว้ข้างต้น

### Accessibility

Dialog ใช้ `AlertDialog` มาตรฐานของ Flutter (มี focus trap/announce ให้อัตโนมัติเหมือน `confirmDeletePost`/`confirmDeleteDrop` ที่ผ่าน QA มาแล้ว) ไม่ต้องเพิ่ม `Semantics` พิเศษ — ปุ่ม X ที่ตอนนี้ disable ได้ระหว่าง sharing ต้องสะท้อนสถานะนั้นให้ screen reader ด้วย (Flutter's `IconButton` ประกาศ disabled state ให้อัตโนมัติเมื่อ `onPressed: null` อยู่แล้ว ไม่ต้องเพิ่มโค้ด)

### Responsive Behavior

ไม่มีผลกระทบ — `AlertDialog` ปรับขนาดตามเนื้อหา/จอเองอัตโนมัติเหมือนสองจุดเดิมที่มีอยู่แล้ว

### Non-goal ที่ตั้งใจไม่ทำรอบนี้ (บันทึกไว้ให้ชัดเจน)

`CreatePopScreen` (`app/lib/features/pop/presentation/create_pop_screen.dart`) มีปัญหาเดียวกันทุกประการ (ไม่มี guard เมื่อออกจากหน้าจอที่มี caption/วิดีโอค้าง) แต่**ไม่อยู่ในขอบเขตของ WYN-025** (Product Task ระบุเฉพาะ Drop composer) — เพราะ `confirmDiscardChanges` ถูกวางไว้ที่ `core/widgets/` แบบ generic ตั้งแต่ต้นแล้ว การเพิ่ม guard แบบเดียวกันให้ `CreatePopScreen` ในอนาคตทำได้ทันทีโดยไม่ต้องสร้าง dialog ใหม่ แนะนำเป็น fast-follow task ระบุไว้ใน Handoff ด้านล่าง

---

## R3: Fullscreen Image Viewer

Screen: `FullscreenImageViewer` (widget ใหม่) — เปิดจาก `DropDetailScreen`

Purpose: ให้ผู้ใช้ดูรูป Drop แบบเต็มจอ ซูมดูรายละเอียดได้ (เช่น ข้อความในรูป, ลายละเอียดเล็กๆ) ซึ่งมุมมอง 1:1 ใน scroll ปกติของ Drop Detail ทำไม่ได้

User Flow: อยู่หน้า Drop Detail → แตะที่ตัวรูปภาพ (ไม่ใช่ทั้งการ์ด) → เปิด `FullscreenImageViewer` เต็มจอ พื้นหลังดำ → pinch เพื่อซูมเข้า/ออก หรือแตะสองครั้งเพื่อ toggle ซูม → แตะปุ่มย้อนกลับมุมซ้ายบน → กลับมาหน้า Drop Detail เดิม (scroll position เดิม เพราะเป็นแค่ push/pop route ปกติ ไม่ได้ rebuild `DropDetailScreen`)

### Components

- ไฟล์ใหม่: `app/lib/core/widgets/fullscreen_image_viewer.dart` (วางที่ `core/widgets/` ไม่ใช่ `features/drop/` ตั้งใจให้เป็น widget กลาง เพราะเป็น "ดูรูปเดี่ยวเต็มจอ" ทั่วไป ไม่ผูกกับ Drop โดยเฉพาะ — รูปแบบเดียวกับ `AvatarCircle`/`confirm_delete_dialog.dart` ที่ reuse ข้ามฟีเจอร์ได้ Club post image/ZOKY product image ในอนาคตใช้ตัวเดียวกันได้โดยไม่ต้องเขียนใหม่)
- `FullscreenImageViewer` รับ constructor param เดียว: `imageUrl` (`String`, required) — ไม่ต้องพึ่ง repository ใดๆ (เป็น view-only screen)
- โครงสร้างจอ: `Scaffold(backgroundColor: Colors.black, body: Stack([InteractiveViewer(...), ปุ่มย้อนกลับลอยมุมซ้ายบน]))` — **ไม่มี `AppBar`** (ให้รูปเต็มจอจริงๆ ไม่มีแถบชนขอบบนมากิน space) ปุ่มย้อนกลับเป็น `IconButton(Icons.arrow_back, color: Colors.white)` ลอยอยู่บน `SafeArea` มุมซ้ายบนแทน — ใช้ไอคอนลูกศรกลับมาตรฐาน (ไม่ใช่กากบาท) เพราะนี่คือการ "ย้อนกลับ" ไปหน้าเดิม ตรงกับ convention ของ `DropDetailScreen`'s AppBar เอง ("ปุ่มย้อนกลับมาตรฐาน" ตาม `.wyn/docs/design/wyn-005-drop.md` Screen 3) ไม่ใช่การ "ปิด" แบบ modal composer อย่าง `CreateDropScreen`
- พื้นหลังหลังปุ่มย้อนกลับ: **ไม่ใช้ Liquid Glass** — ถ้าต้องการ scrim ให้อ่านง่ายขึ้นบนรูปสว่าง ใช้ `Container` สีทึบโปร่งแสงธรรมดา (`Colors.black.withValues(alpha: 0.3)` เป็นวงกลมพื้นหลังไอคอนเท่านั้น ไม่ใช่ blur เต็มแถบ) ตรงตามกติกา "ห้ามใช้ Liquid Glass" ของ `design-principles.md`
- `InteractiveViewer`:
  - `minScale: 1.0`, `maxScale: 4.0` (ให้พอซูมเห็นรายละเอียดโดยไม่ถึงขั้นรูปแตกเกินไป — รูปต้นทางถูก resize ไว้สูงสุด 1600x1600 ตอนเลือกอยู่แล้วจาก `image_picker`'s `maxWidth`/`maxHeight`)
  - child: `Image.network(imageUrl, fit: BoxFit.contain)` — **ใช้ `contain` ไม่ใช่ `cover`** ต่างจากทุกจุดอื่นที่แสดง Drop (การ์ด grid, Drop Detail's summary, ฯลฯ ที่ตั้งใจ `cover` เพื่อเติมช่องสี่เหลี่ยม) เพราะจุดประสงค์ของหน้านี้คือ "ดูรูปแบบเต็มไม่ถูกครอปเพิ่ม" — แม้ตัวรูปจะถูก crop เป็น 1:1 มาแล้วตั้งแต่ตอนสร้าง Drop แต่ `contain` ยังจำเป็นสำหรับจอที่ไม่ใช่สี่เหลี่ยมจัตุรัสพอดี (จอมือถือทั่วไปเป็นแนวตั้งยาว) เพื่อไม่ครอปขอบรูปทิ้งเพิ่มอีกชั้นโดยไม่จำเป็น
- Double-tap zoom: ใช้ `GestureDetector` ครอบ `InteractiveViewer` พร้อม `TransformationController` (สร้างเอง เก็บใน State) — `onDoubleTapDown` เก็บตำแหน่งที่แตะไว้ชั่วคราว, `onDoubleTap` toggle ระหว่าง 1.0x (identity matrix, `controller.value = Matrix4.identity()`) กับ 3.0x centered ที่ตำแหน่งที่แตะ (คำนวณ translate ก่อน scale ให้จุดที่แตะยังอยู่ตำแหน่งเดิมบนจอหลังซูม) — ค่า 3.0x เลือกให้ต่ำกว่า `maxScale` (4.0x) เล็กน้อยเพื่อเหลือพื้นที่ให้ pinch ซูมต่อได้อีกถ้าต้องการละเอียดกว่านั้น — แนะนำห่อ animate ด้วย `AnimationController` สั้นๆ (150-200ms) ให้ transition ไม่กระตุก แทนสลับ matrix ทันทีแบบไม่มี animation (รายละเอียด implementation ปล่อยให้ AI Coding ตัดสินใจ ไม่ใช่ design decision)

### Interactions

- ใน `DropDetailScreen`'s header, ห่อเฉพาะตัว `Image.network` (ไม่ใช่ทั้ง `AspectRatio` block ที่รวม caption/interaction row) ด้วย `GestureDetector(onTap: _openFullscreenViewer)` — เมธอดใหม่ `_openFullscreenViewer()`: `Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => FullscreenImageViewer(imageUrl: _drop.imageUrl)))`
  - `fullscreenDialog: true` ให้ transition แบบ slide-up-from-bottom มาตรฐานของ platform ซึ่งสื่อว่า "เปิด overlay ใหม่เต็มจอ" ต่างจาก push ปกติที่สื่อว่า "ไปหน้าถัดไปในลำดับชั้นเดิม" — เหมาะกับ fullscreen viewer มากกว่า push ธรรมดาที่ `DropDetailScreen`/`CreateDropScreen` ใช้อยู่ (ทั้งสองไม่ใช่ full-screen "overlay" แบบนี้)
- Pinch (สองนิ้ว) → ซูมเข้า/ออกต่อเนื่องระหว่าง 1.0x-4.0x, pan ได้เมื่อซูมเกิน 1.0x (พฤติกรรม default ของ `InteractiveViewer`)
- Double-tap → toggle ระหว่าง 1.0x กับ 3.0x centered ที่จุดแตะ
- แตะปุ่มย้อนกลับมุมซ้ายบน → `Navigator.of(context).pop()` กลับ `DropDetailScreen`
- ปุ่ม/ท่าทาง back ของระบบ → ปิดตามปกติเหมือนหน้าจอ push อื่นๆ ทุกจุดในแอป (ไม่ต้องมี `PopScope` เพราะไม่มีข้อมูลอะไรให้เสีย — เป็น view-only screen)
- **ตั้งใจไม่ทำ tap-นอกรูป-เพื่อปิด**: เพราะพื้นที่ทั้งหน้าจอเป็น hit area ของ `InteractiveViewer` อยู่แล้ว (สำหรับ pan/pinch) การเพิ่ม single-tap-to-close จะชนกับ gesture ซูม/pan โดยเฉพาะตอนผู้ใช้ซูมอยู่แล้วพยายามลากดูมุมอื่นของรูป (อาจแตะโดนพื้นที่ที่ตีความเป็น "นอกรูป" แล้วปิดหน้าจอไปโดยไม่ตั้งใจ) ปุ่มย้อนกลับที่ชัดเจนจุดเดียวปลอดภัยกว่า
- **ยังไม่รองรับ swipe ซ้าย-ขวาข้ามหลายรูป** ตามที่ Product Task ระบุชัดเจนว่า Drop ยังเป็น 1 รูป/โพสต์ในรอบนี้ — เพิ่มทีหลังตอน WYN's multi-image feature เสร็จ (ไม่ทำ infra รองรับ multi-image ล่วงหน้าในงานนี้ เพราะยังไม่รู้ shape ของ multi-image API จริง)

### States

- Default: fit เต็มจอที่ 1.0x ทันทีที่เปิด (ไม่มี loading เพิ่ม เพราะรูปเดียวกันนี้แสดงอยู่แล้วใน `DropDetailScreen` ก่อนหน้า แทบจะอยู่ใน Flutter's `ImageCache` เสมอ — ไม่ต้องทำ shared/Hero transition ก็ดูลื่นในทางปฏิบัติ)
- Loading edge case (cache ถูกเคลียร์ไปแล้วพอดี, ต้องโหลดใหม่จาก network): ใช้ `Image.network`'s `loadingBuilder` แสดง `CircularProgressIndicator` สีขาวกลางจอเรียบๆ (ไม่ต้อง skeleton ซับซ้อน เพราะเป็น edge case ที่เกิดยาก)
- Error (โหลดรูปไม่สำเร็จ, เช่น ตัดเน็ตพอดี): `Image.network`'s `errorBuilder` แสดงไอคอน `Icons.broken_image_outlined` สีขาว + ข้อความสั้น "โหลดรูปไม่สำเร็จ" กลางจอ — ไม่ต้องมีปุ่ม retry (ผู้ใช้กดปุ่มย้อนกลับแล้วแตะรูปใหม่ได้อยู่แล้ว ไม่ต้อง engineer ทางลัดเพิ่ม)
- Zoomed (1.0x-4.0x): ไม่ต้องมี state indicator ใดๆ บนจอบอกระดับซูมปัจจุบัน (ตรงกับ convention ทั่วไปของ photo viewer ที่ไม่โชว์ตัวเลขซูม)

### Accessibility

- `Semantics(label: 'ดูรูปเต็มจอ', button: true)` ครอบ `GestureDetector` ใน `DropDetailScreen` ที่เปิด viewer (มิเรอร์ pattern ของ `CreateDropScreen`'s image area ที่มี label บอก tap action ชัดเจนอยู่แล้ว)
- ปุ่มย้อนกลับใน `FullscreenImageViewer` ใช้ `IconButton`'s `tooltip: 'ย้อนกลับ'` (มาตรฐาน Flutter ประกาศ accessible name ให้อัตโนมัติจาก tooltip)
- Contrast: ไอคอนสีขาวบนพื้นหลังดำ/รูปภาพ — ผ่าน AA สบายเสมอบนพื้นดำเต็ม ส่วนตอนซ้อนบนรูปภาพจริง ให้วง scrim โปร่งแสงบางๆ หลังไอคอน (ระบุใน Components ด้านบน) กันกรณีรูปสว่างจนไอคอนขาวจมหาย

### Responsive Behavior

`InteractiveViewer` + `Image.network(fit: BoxFit.contain)` ปรับตามขนาดจอ/orientation (portrait/landscape) โดยอัตโนมัติอยู่แล้วตามธรรมชาติของ Flutter — ไม่ต้องเขียน logic เพิ่มสำหรับ responsive ในหน้านี้

### Design Rules

- ห้ามเพิ่ม package ภายนอกสำหรับซูมรูป (`photo_view` หรือเทียบเท่า) — ใช้ `InteractiveViewer` ในตัว Flutter เท่านั้น ตาม "DO NOT OVERENGINEER" ของ Product Task และยืนยันแล้วว่า `pubspec.yaml` ไม่มี package แบบนี้อยู่ก่อน
- ห้ามใช้ Hero animation ระหว่าง `DropDetailScreen`'s รูปย่อกับ `FullscreenImageViewer` ในรอบนี้ — เป็นการเพิ่ม visual polish ที่ไม่ได้อยู่ใน Acceptance Criteria (which ต้องการแค่ "เปิด/ซูม/ปิดได้ ไม่ crash") เพิ่ม complexity ของ transition โดยไม่จำเป็น พิจารณาเป็น fast-follow ถ้า Founder ต้องการทีหลัง
- ห้ามทำ tap-outside-to-close (เหตุผลใน Interactions ด้านบน — ชนกับ gesture ซูม/pan)
- พื้นหลังต้องเป็นสีทึบ (`Colors.black`) เสมอ ไม่ใช่ blur/translucent เต็มจอ ตามกติกาห้าม Liquid Glass

---

## Design Rules (รวมทั้งงาน)

- R1 ไม่มีการเปลี่ยนแปลง UI ที่ผู้ใช้เห็นเลย เป็น pure encoding fix
- R2 ไม่สร้าง local draft persistence ใดๆ ข้ามการปิดแอป — ใช้ confirm-dialog ที่ reuse โครง `AlertDialog` เดียวกับ `confirmDeletePost`/`confirmDeleteDrop` เป๊ะ (title จบด้วย "?", content สั้น, 2 ปุ่ม `TextButton` ไม่มีสีพิเศษ)
- R3 ใช้ `InteractiveViewer` ในตัว Flutter เท่านั้น ไม่มี package ใหม่สำหรับการซูม (มีแค่ R1 ที่อาจต้องเพิ่ม `image` package สำหรับ JPEG encode ซึ่งเป็นเหตุผลทางเทคนิคที่จำเป็นจริง ไม่ใช่ overengineer)
- ไม่มีจุดใดในงานนี้ที่แตะ color token/typography scale/spacing scale ใหม่ — ใช้ `WynSpacing`/`Theme.of(context)` ของเดิมทั้งหมดในจุดที่มี UI ใหม่ (ปุ่มย้อนกลับ/dialog)

## Handoff: AI Coding

1. **R1** (`app/lib/features/drop/data/square_crop.dart`): เปลี่ยน output จาก PNG เป็น JPEG คุณภาพ 85-90 — ต้องเพิ่ม package `image` ใน `pubspec.yaml` (เหตุผล: `dart:ui`'s `ImageByteFormat` ไม่มี JPEG ให้เลือก — ดู Reference ด้านบน) ตรวจสอบว่ารูปเก่าที่โพสต์เป็น PNG ไปแล้วยังเปิดดูได้ปกติ (ไม่ต้อง migrate ของเก่า ตาม Product Task's Risks) เขียน test เทียบขนาดไฟล์ก่อน/หลัง fix ด้วยภาพตัวอย่างเดียวกัน (ต้องเล็กลงอย่างมีนัยสำคัญ) และ test ยืนยัน `imageExtension` ที่ส่งเข้า `createDrop()` เปลี่ยนจาก `'png'` เป็น `'jpg'`/`'jpeg'` ตามจริง (ปัจจุบัน `_pickImage()` ใน `create_drop_screen.dart` hardcode `_imageExtension = 'png'` หลัง crop — ต้องแก้บรรทัดนี้ให้ตรงกับ format ใหม่ด้วย ไม่ใช่แค่แก้ `square_crop.dart` อย่างเดียว)
2. **R2** (`app/lib/features/drop/presentation/create_drop_screen.dart` + ไฟล์ใหม่ `app/lib/core/widgets/confirm_discard_dialog.dart`): implement ตาม Components/Interactions ด้านบนทั้งหมด — จุดสำคัญที่ต้องไม่พลาด: (a) ปุ่ม X ต้อง route ผ่าน `_requestExit()` ไม่ใช่ `pop(false)` ตรงๆ แบบเดิม (b) `PopScope` ต้องครอบทั้ง `Scaffold` (c) `_share()`'s success path (`Navigator.of(context).pop(true)`) **ห้ามแก้** ปล่อยให้เรียกตรงๆ เหมือนเดิม (ไม่ผ่าน guard ตามที่อธิบายไว้ใน Interactions) เขียน widget test ครอบคลุม: มีเนื้อหา+กด X → เห็น dialog / กด "ยกเลิก" → ยังอยู่หน้าเดิม เนื้อหาไม่หาย / กด "ทิ้ง" → หน้าจอปิด, ไม่มีเนื้อหา+กด X → ปิดทันทีไม่มี dialog, จำลอง system back (`didPop` ผ่าน `PopScope`) ให้พฤติกรรมตรงกับปุ่ม X, ระหว่าง `_isSharing == true` ปุ่ม X ต้อง disable และ back ต้องถูกบล็อกเงียบๆ ไม่มี dialog, publish สำเร็จต้องปิดหน้าจอได้ปกติไม่ติด dialog ค้าง
3. **R3**: สร้าง `app/lib/core/widgets/fullscreen_image_viewer.dart` ตาม Components/Interactions ด้านบน แล้วแก้ `app/lib/features/drop/presentation/drop_detail_screen.dart` ห่อเฉพาะ `Image.network` (ไม่ใช่ทั้ง header block) ด้วย `GestureDetector`+`Semantics` ตามที่ระบุ เขียน widget test: แตะรูปเปิด `FullscreenImageViewer` จริง (ยืนยัน route ใหม่ปรากฏ), แตะปุ่มย้อนกลับปิดกลับมา `DropDetailScreen` เดิม, และอย่างน้อย 1 test ยืนยันว่า `InteractiveViewer`/`TransformationController` ถูก wire เข้าไปจริง (เช่น ยืนยันว่ามี `InteractiveViewer` widget อยู่ใน tree พร้อม `minScale`/`maxScale` ตรงตาม spec — ไม่จำเป็นต้อง simulate pinch gesture จริงถ้าทำได้ยากใน widget test แต่ต้องยืนยัน config ถูกต้องอย่างน้อย)
4. `flutter analyze`/`flutter test` ต้องผ่านครบ ไม่มี regression กับ WYN-005/WYN-019 ตาม Acceptance Criteria ของ Product Task
5. **บันทึกไว้ให้ Product พิจารณาเป็น fast-follow** (ไม่ใช่ scope ของ WYN-025): `CreatePopScreen` มีปัญหาเดียวกันกับที่ R2 แก้ให้ Drop composer ทุกประการ (ไม่มี exit guard) — เพราะ `confirmDiscardChanges` ถูกวางเป็น widget กลางที่ `core/widgets/` แล้ว การทำแบบเดียวกันให้ Pop composer ในอนาคตคือการ reuse ตรงๆ ความเสี่ยงต่ำเท่ากับงานนี้

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement R1/R2/R3 ตาม Design decisions ข้างต้น — R1 เป็น bug fix ล้วนๆ ไม่ต้องรอ Design (ส่งตรงได้ตั้งแต่ Product Task) R2/R3 พร้อมส่งต่อ AI Coding แล้วหลัง Design ตัดสินใจครบทั้งคู่ ดู Product Task `.wyn/tasks/backlog/WYN-025-drop-composer-polish.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
