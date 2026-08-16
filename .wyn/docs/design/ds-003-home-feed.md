# Design Spec — DS-003 (Home Feed — card-less continuous feed)

> โดย AI Design — 2026-08-16 | ต่อจาก DS-001 (token foundation) + DS-002 (global style pass, Card flattening) ตามลำดับ 8 เฟสที่ DS-001's Recommendation วางไว้

## Audit ก่อนออกแบบ (สำคัญ — เปลี่ยนขอบเขตงานนี้)

อ่าน `home_drop_card.dart`/`home_pop_card.dart` (`app/lib/features/home/presentation/widgets/`) แล้วพบว่า **Home Feed ไม่เคยใช้ `Card` widget เลยตั้งแต่ต้น** — แต่ละรายการเป็น `Column` เปล่าห่อด้วย `Padding`/`InkWell` ธรรมดา ไม่มี `elevation`, ไม่มีเส้นขอบ, ไม่มีพื้นหลังต่างจากพื้น Scaffold รูปภาพก็เป็น full-bleed (`AspectRatio` + `Image.network` ตรง ๆ ไม่มี `ClipRRect` มุมโค้ง) — เข้าเกณฑ์ "card-less" ตามชื่อ task นี้อยู่แล้วโดยไม่ต้องแก้อะไร

ดังนั้นขอบเขตงานนี้ **ไม่ใช่ "รื้อการ์ดออก"** (ไม่มีการ์ดให้รื้อ) แต่เป็นการเติมช่องว่างเดียวที่เหลือ: ปัจจุบันแต่ละรายการคั่นกันด้วย **ช่องว่างเปล่าล้วน** (`EdgeInsets.symmetric(vertical: WynSpacing.space2)` = 8px บน-ล่าง รวมเป็น 16px ระหว่างโพสต์) ไม่มีเส้นแบ่งภาพใดๆ เลย — สำหรับ feed ที่เลื่อนต่อเนื่องยาวๆ การไม่มีจุดคั่นสายตาอาจทำให้โพสต์ติดกันดูไม่ออกว่าจบโพสต์หนึ่งเริ่มอีกโพสต์ตรงไหนเมื่อโพสต์สั้น (เช่น ไม่มี caption)

## การตัดสินใจ

เพิ่ม **เส้นคั่นบาง (hairline divider) เส้นเดียว** ระหว่างรายการ — ไม่ใช่การ์ด ไม่ใช่เงา ไม่ใช่พื้นหลังสลับสี เป็นแค่เส้นตกแต่งบางที่สุดเท่าที่ Material ให้มาตามธรรมชาติ ตรงกับที่ DS-001's spec (`ds-001-color-system.md`, "การแก้ข้อขัดแย้งเรื่อง token file") อนุญาตไว้แล้วว่า border ระดับ subtle (`WynColors.borderSubtleLight`/`borderSubtleDark`, map เข้า `colorScheme.outlineVariant`) ใช้กับ "เส้นแบ่งตกแต่ง (divider)" ได้ — ต่างจาก `border-strong` ที่บังคับเฉพาะขอบของสิ่งที่กดได้ (WCAG 1.4.11) ซึ่ง divider ระหว่างโพสต์ไม่ใช่สิ่งที่กดได้เอง จึงไม่ต้องผ่านเกณฑ์ 3.0:1 นั้น

ใช้ Flutter `Divider(height: 1)` ธรรมดา — ไม่ประดิษฐ์ widget ใหม่ เพราะ Material 3's `DividerThemeData` default ดึงสีจาก `colorScheme.outlineVariant` อยู่แล้วซึ่งตรงกับ token ที่ต้องการเป๊ะ (ยืนยันจาก `wyn_colors.dart`: `outlineVariant: borderSubtleLight`/`borderSubtleDark`) — ไม่ต้อง hardcode สีเอง `indent`/`endIndent` เป็นค่าเริ่มต้น 0 อยู่แล้ว = full-bleed ชิดขอบจอทั้งสองด้าน ตรงกับคอนเซปต์ "continuous feed" (ต่างจาก card ที่มักมี margin ข้าง)

**สิ่งที่ไม่แตะ**: padding ภายในการ์ดเดิม (8px บน-ล่างต่อรายการ), รูปภาพ 1:1 full-bleed, layout ปุ่ม like/comment/share/save, ทุก interaction เดิม — งานนี้เป็น visual layer จุดเดียวเท่านั้น (เพิ่มเส้นคั่น) ตรงตามหลัก "ห้ามลบ/เปลี่ยนพฤติกรรมฟีเจอร์" ที่ DS-001 วางไว้

## Requirements

R1. เพิ่ม `Divider(height: 1)` คั่นระหว่างทุกรายการใน Home Feed's `ListView` (ทั้งโหมด "สำหรับคุณ" และ "จาก Club ของคุณ")
R2. ไม่เพิ่มเส้นคั่นซ้ำที่ท้ายรายการสุดท้ายก่อน loading spinner (spinner ไม่ใช่เนื้อหาโพสต์ ไม่ต้องมีเส้นคั่นนำหน้ามันด้วยเหตุผลเดียวกับที่ไม่มีเส้นคั่นก่อนรายการแรก) — ใช้ `separatorBuilder` เฉพาะระหว่างรายการเนื้อหาจริง ไม่ครอบคลุม spinner
R3. ไม่แก้ `home_drop_card.dart`/`home_pop_card.dart` เลย — งานอยู่ที่ระดับ `home_feed_screen.dart`'s ListView เท่านั้น (`ListView.builder` → `ListView.separated`)
R4. ไม่มี hardcoded color ใหม่ — ใช้ `Divider()` เปล่า ให้ theme (`colorScheme.outlineVariant`) กำหนดสีเอง ทั้ง light/dark

## Acceptance Criteria

- [ ] มีเส้นคั่นบาง (1px) ระหว่างทุกโพสต์ใน Home Feed ทั้งสองโหมด (For You / From Your Clubs)
- [ ] ไม่มีเส้นคั่นก่อนรายการแรกหรือหลังรายการสุดท้าย (ก่อน loading spinner)
- [ ] ไม่มี `Card`/`elevation`/`BoxShadow`/`ClipRRect` มุมโค้งใหม่เพิ่มเข้ามาที่ไหนเลย (ยืนยัน card-less ยังคงจริง)
- [ ] `flutter analyze`/`flutter test` ผ่านสะอาดใน `app/`
- [ ] เส้นคั่นเปลี่ยนสีถูกต้องเองระหว่าง light/dark (ผ่าน `colorScheme.outlineVariant` อัตโนมัติ ไม่ hardcode)

## Handoff

ส่งต่อ AI Coding: แก้เฉพาะ `home_feed_screen.dart`'s `_buildBody()` — เปลี่ยน `ListView.builder` → `ListView.separated` พร้อม `separatorBuilder` ที่คืน `Divider(height: 1)` เฉพาะดัชนีที่ไม่ใช่ตำแหน่ง spinner ท้ายสุด
