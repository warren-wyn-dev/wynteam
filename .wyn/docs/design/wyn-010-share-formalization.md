# Design — WYN-010 (Share formalization: ZOKY Product/Store)

อ้างอิง Product spec: `.wyn/tasks/backlog/WYN-010-share-formalization.md` — เพิ่ม Share + Copy Link ให้ `ProductDetailScreen`/`StoreScreen` ตาม pattern เดียวกับ Drop/Pop/Club post เป๊ะ ไม่ประดิษฐ์ใหม่

## Screen: ProductDetailScreen — เพิ่ม AppBar actions

Purpose: ให้แชร์/คัดลอกลิงก์สินค้าได้ เหมือนที่ Drop/Pop/Club post ทำได้อยู่แล้ว

User Flow: เปิดหน้า Product Detail → เห็นไอคอน 2 อันที่มุมขวาบนของ AppBar (ต่อจาก title) → แตะ "แชร์" เปิด native share sheet, แตะ "คัดลอกลิงก์" คัดลอก + SnackBar ยืนยัน

Components:
- `AppBar(title: Text(product.name), actions: [...])` — เพิ่ม `actions` list เข้า AppBar ที่มีอยู่แล้ว (ปัจจุบันไม่มี actions เลย)
- `IconButton(icon: Icon(Icons.share_outlined), tooltip: 'แชร์', onPressed: _share)` — ไอคอน/tooltip เดียวกับ `DropDetailScreen`/`PopClipView`/`ClubPostDetailScreen` เป๊ะ
- `IconButton(icon: Icon(Icons.link), tooltip: 'คัดลอกลิงก์', onPressed: _copyLink)` — เช่นเดียวกัน

Interactions: `_share()` เรียก `SharePlus.instance.share(ShareParams(text: productShareLink(product.id), title: 'สินค้าบน WYN'))` (title ตาม convention เดิม `"<ประเภท> บน WYN"` — Drop ใช้ "Drop บน WYN", Pop ใช้ "Pop บน WYN", Club post ใช้ "โพสต์ใน Club บน WYN" → Product ใช้ "สินค้าบน WYN" ให้สอดคล้อง) `_copyLink()` เรียก `Clipboard.setData` + `ScaffoldMessenger` SnackBar ข้อความ "คัดลอกลิงก์แล้ว" เหมือนทุกจุดเดิมเป๊ะ

States: ไม่มี state พิเศษ (เหมือนต้นแบบ Drop/Pop/Club post — ปุ่มกดได้เสมอไม่มี loading/disabled)

Responsive Behavior: AppBar actions มาตรฐาน Flutter ไม่มีจุดพิเศษ

Accessibility: `tooltip` ทำหน้าที่เป็น accessible label อยู่แล้ว (ตรงตาม pattern เดิมที่ไม่ได้ใช้ `Semantics` แยกสำหรับปุ่ม Share/Copy Link ใน Drop/Pop/Club post เช่นกัน)

Design Rules: ใช้ icon/tooltip/ข้อความ SnackBar เดียวกับที่มีอยู่แล้วทุกจุดในแอป ห้ามคิด icon ใหม่

Handoff: `String productShareLink(String productId) => 'https://wyn.app/product/$productId';` วางไว้ใน `product_detail_screen.dart` เหมือนที่ `dropShareLink` วางไว้ใน `drop_detail_screen.dart`

---

## Screen: StoreScreen — เพิ่ม AppBar actions

Purpose/User Flow/Components/Interactions: เหมือน ProductDetailScreen ทุกประการ เปลี่ยนแค่ target เป็นร้านค้า — `storeShareLink(String storeId) => 'https://wyn.app/store/$storeId';`, share title "ร้านค้าบน WYN"

States/Responsive/Accessibility/Design Rules: เหมือน ProductDetailScreen

Handoff: ส่งต่อ AI Coding (`/code`)
