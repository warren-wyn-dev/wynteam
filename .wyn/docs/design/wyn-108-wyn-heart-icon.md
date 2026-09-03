# Design Spec — WYN-108: `WynHeartIcon` — เปลี่ยนทรงหัวใจทั้งแอปเป็นทรงตามไฟล์อ้างอิง

Owner: AI Design → AI Coding
Ref: Founder สั่ง "รูปหัวใจ ทำสวยๆหน่อย ❤️" (2026-09-03) แล้วเลือก **แบบ B (lucide)** จาก 3 ทรงที่เสนอ
Preview: Artifact "ฟีดจัดแนวใหม่ กับหัวใจสามทรง"
แยกจาก WYN-107 (โครงสองคอลัมน์) เพราะเป็นคนละลักษณะงาน และรวมกันจะเป็น PR ใหญ่เกินรีวิว

---

## ต้นเหตุที่หัวใจดูไม่ตรงกับที่ออกแบบไว้

`design-reference/01-home.tsx` บรรทัด 1-15 `import { Heart } from "lucide-react"` — ไฟล์อ้างอิง
ใช้ไอคอนชุด **lucide** แต่ตอน implement ใช้ `Icons.favorite` / `Icons.favorite_border` ของ **Material**
ซึ่งเป็นคนละทรงกันชัดเจน (Material อ้วนกว่า ไหล่กว้างกว่า ปลายล่างมนกว่า ร่องกลางตื้นกว่า)

ไม่มีใครทำผิด — ตอนนั้นไม่มีใครสังเกตว่าไอคอนคนละชุด แต่ผลคือหน้าจอจริงไม่ตรงกับแบบที่อนุมัติไว้

## Screen

ทุกจุดในแอปที่วาด "หัวใจถูกใจ" — 13 ไฟล์ (ยกเว้น 2 ไฟล์ Pop ที่ถูกระงับ ดูด้านล่าง)

## Purpose

ให้หัวใจทั้งแอปเป็นทรงเดียวกันและตรงกับไฟล์อ้างอิง โดยไม่ต้องเพิ่ม dependency ใหม่

## Components

### `WynHeartIcon` — widget ใหม่ที่ `app/lib/core/widgets/wyn_heart_icon.dart`

```dart
WynHeartIcon({
  required bool filled,   // true = ถูกใจแล้ว (ทึบ) / false = ยังไม่ถูกใจ (เส้น)
  required double size,   // ขนาดเท่าที่ Icon เดิมใช้อยู่ตรงจุดนั้น
  required Color color,
})
```

**วิธี implement (ไม่เพิ่ม dependency)**: `CustomPainter` วาด `Path` ตามพิกัดของ lucide บน viewBox
24×24 แล้วสเกลตาม `size` — โครงการนี้ยังไม่มี `flutter_svg` และไม่ควรเพิ่มแพ็กเกจใหม่เพื่อไอคอนเดียว

พิกัด lucide (viewBox 24×24) ที่ต้องวาดให้ตรง:
```
M20.84 4.61
a 5.5 5.5 0 0 0 -7.78 0
L 12 5.67
l -1.06 -1.06
a 5.5 5.5 0 0 0 -7.78 7.78
l 1.06 1.06
L 12 21.23
l 7.78 -7.78
l 1.06 -1.06
a 5.5 5.5 0 0 0 0 -7.78
z
```

- **สถานะเส้น (`filled: false`)**: `PaintingStyle.stroke` · `strokeWidth` = 1.5 บน viewBox 24
  (สเกลตามขนาดจริง) · `strokeCap`/`strokeJoin` = `round` — ตรงกับ `strokeWidth={1.4}` ของไฟล์อ้างอิง
  ปัดขึ้นเล็กน้อยเพราะ Flutter วาดเส้นบางกว่า SVG ที่ขนาดเดียวกัน
- **สถานะทึบ (`filled: true`)**: `PaintingStyle.fill` เส้นเดียวกัน

### จุดที่ต้องเปลี่ยน (13 ไฟล์)

`double_tap_like.dart` · `home_drop_card.dart` · `home_pop_card.dart` · `drop_detail_screen.dart` (2 จุด) ·
`drop_image_viewer.dart` · `drop_grid_tile.dart` · `trending_tile.dart` · `club_post_card.dart` ·
`club_post_detail_screen.dart` · `notification_list_screen.dart` · `saved_post_row.dart`

**ตรวจก่อนแก้**: `settings_screen.dart` และ `notification_settings_screen.dart` ก็มี `Icons.favorite`
แต่น่าจะเป็นไอคอนหัวข้อเมนู ไม่ใช่ปุ่มถูกใจ — **ถ้าไม่ใช่หัวใจถูกใจ ห้ามแตะ** (ไอคอนเมนูควรเป็นชุด
Material เหมือนไอคอนเมนูอื่น ๆ รอบตัวมัน)

### จุดที่ห้ามแตะ

`pop_clip_view.dart` และ `pop_comment_sheet.dart` — ยังอยู่ใต้กติกา **"ห้ามแก้ไฟล์ Pop โดยตรง"**
(DS-001 Risk R3) ข้อยกเว้นที่ Founder ให้ไว้ครอบคลุมแค่ `home_pop_card.dart` ไฟล์เดียว
→ บันทึกเป็น known gap: หัวใจใน 2 หน้าจอนี้จะยังเป็นทรง Material จนกว่า Pop จะถูกปลดล็อก

## Interactions / States

ไม่เปลี่ยนพฤติกรรมใด ๆ — แค่เปลี่ยนรูปทรงที่วาด สถานะ/สี/ขนาด/animation เดิมทั้งหมด:
- สีถูกใจแล้ว = `WynColors.iconLikeActive` (แดง) · ยังไม่ถูกใจ = `WynColors.iconIdle` (graphite)
- `ActionMetric` ยังทำ scale-pop animation ตอนสถานะเปลี่ยนเหมือนเดิม (ต้องตรวจว่า animation ยังทำงาน
  เพราะมันดูจาก `widget.icon != oldWidget.icon` — พอเปลี่ยนจาก `IconData` เป็น widget อาจต้องปรับ
  เงื่อนไขให้ดูที่ `filled` แทน **จุดนี้สำคัญ ห้ามทำ animation หาย**)
- `double_tap_like.dart` หัวใจขาวเด้งกลางรูป — เปลี่ยนทรงด้วย สีขาวเหมือนเดิม

## Accessibility

ไม่กระทบ — `Semantics` ทุกจุดอยู่ที่ระดับปุ่ม ไม่ได้อยู่ที่ตัวไอคอน · ต้องใส่
`ExcludeSemantics` ให้ `CustomPaint` เพื่อไม่ให้ประกาศตัวเองเพิ่ม

## Design Rules

1. **หัวใจถูกใจทั้งแอปต้องเป็น `WynHeartIcon` ตัวเดียวกันเสมอ** — ห้ามใช้ `Icons.favorite` กับ
   ปุ่มถูกใจอีกต่อไป (นี่คือบทเรียนตรงจาก WYN-076 ที่สีหัวใจเคยหลุดไปคนละสีใน 5 จุดเพราะไม่มีตัวกลาง)
2. ไอคอนอื่นทั้งแอป **ยังใช้ Material เหมือนเดิม** — งานนี้เปลี่ยนเฉพาะหัวใจ ไม่ใช่การเปลี่ยน icon set
   ทั้งระบบ (ถ้าอนาคตอยากเปลี่ยนชุดไอคอนทั้งแอปต้องเป็นงานแยกที่ขออนุมัติใหม่)

## Handoff

1. สร้าง `app/lib/core/widgets/wyn_heart_icon.dart` ตามสเปคด้านบน
2. ไล่เปลี่ยน 13 จุด (ตรวจ 2 ไฟล์ settings ก่อนว่าเป็นหัวใจถูกใจจริงไหม)
3. แก้เงื่อนไข pop animation ใน `action_metric.dart` ให้ยังทำงาน
4. เขียน widget test: หัวใจ 2 สถานะวาดจริง + animation ยังเล่นตอนสถานะเปลี่ยน
5. `flutter analyze` สะอาด + `flutter test` ผ่านครบ
6. **ทำหลัง WYN-107 merge แล้ว** เพราะทั้งสองงานแตะ `home_drop_card.dart`/`home_pop_card.dart`
