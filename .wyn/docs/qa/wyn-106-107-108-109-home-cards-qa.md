# QA & Security Report — WYN-106 / WYN-107 / WYN-108 / WYN-109b–d

> วันที่: 2026-09-04
> Branch: `claude/home-button-ux-ui-design-cbjkzm` (13 commit เหนือ `main`, base = `0e23d8a`) — **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ผู้ตรวจ: AI QA & Security
> ขอบเขต: 4 งานที่ AI Design/AI Coding ส่งมอบ — ระบบปุ่มหน้า Home (106), การ์ดฟีดสองคอลัมน์ (107), หัวใจทรง lucide (108), เลือกสัดส่วนรูปตอนโพสต์ (109b–d)
> วิธีตรวจ: อ่าน diff ทุกบรรทัดเทียบ spec ทีละข้อ + รัน `flutter analyze`/`flutter test` เอง + เขียน widget test เพิ่มเองอีก 16 เคสเพื่อพยายาม break + ยกฐานข้อมูล PostgreSQL 16 ขึ้นมาใหม่แล้วรัน migration จริงเทียบกับ schema ก่อนหน้า

---

## 0. ข้อสรุปสำหรับ Founder (อ่านย่อหน้าเดียวพอ)

**WYN-106 ผ่าน · WYN-107 ผ่าน · WYN-108 ไม่ผ่าน · WYN-109b–d ไม่ผ่าน**

งานโครงสร้างการ์ด (107) และปุ่มปิดแบนเนอร์ (106) ทำได้ตรง spec ทุกจุดที่วัดได้ ไม่มี regression กับ 6 จุดที่ห้ามย้อนกลับ และไม่มีการแตะไฟล์ Pop ที่ห้ามแตะ

แต่ **ห้าม merge/deploy ทั้งชุดตอนนี้** เพราะมี 1 ปัญหาระดับ Critical และ 3 ระดับ Major:

1. **Critical** — โค้ด WYN-109 ส่งคอลัมน์ `image_aspect_ratio` ไปกับทุกคำสั่งสร้างโพสต์ **แม้ค่าจะเป็น null** ตอนนี้ production ยังไม่มีคอลัมน์นั้น (Founder ยังไม่ได้รัน SQL) → ถ้า deploy ก่อนรัน SQL **การโพสต์จะพังทั้งหมด** ทั้งโพสต์รูป โพสต์ข้อความ โพลล์ และการเผยแพร่ Draft
2. **Major** — หัวใจข้างคอมเมนต์ในหน้า Drop Detail โตจาก 16px เป็น 24px (ใหญ่กว่าไอคอนถังขยะข้างๆ 50%)
3. **Major** — โพสต์ 16:9 แสดงเป็น 16:9 ในฟีด แต่พอกดเข้าไปดูในหน้าโพสต์กลับโดนครอปกลับเป็น 4:5 เหมือนเดิม
4. **Major** — รูปพรีวิวในหน้าสร้างโพสต์ไม่เปลี่ยนสัดส่วนตามชิปที่กด (ยังเป็นกรอบ 4:5 เท่าเดิม) คนโพสต์จึงไม่เห็นสิ่งที่จะได้จริง ซึ่งเป็นหัวใจของฟีเจอร์นี้

ส่งต่อ AI Debug Engineer แล้ว 4 ใบ (ดู §7)

---

## 1. Environment / ผลรันจริง (ไม่ได้เชื่อตัวเลขที่รายงานมา)

| รายการ | ผล |
|---|---|
| Flutter SDK | `/opt/flutter-sdk/flutter/bin`, `FLUTTER_SUPPRESS_ANALYTICS=true` |
| `flutter analyze` (`app/`) | **No issues found!** (ran in 2.0s) — exit 0 |
| `flutter test` (`app/`) | **1188/1188 All tests passed!** — exit 0 |
| Widget test ที่ QA เขียนเพิ่มเอง | 16 เคส (QA1–QA16) — ผ่าน 14 ล้มเหลว 2 (ทั้ง 2 คือบั๊กจริง ดู §5) |
| PostgreSQL | 16.13 (scratch instance) — โหลด `schema.sql` เวอร์ชัน **ก่อน** งานนี้ แล้ว seed โพสต์เก่า 1 แถว ก่อนรัน migration |

หมายเหตุ: test ที่ QA เขียนเพิ่มเป็น scratch สำหรับตรวจเท่านั้น ลบออกแล้ว ไม่ได้ commit และ **ไม่มีการแก้โค้ดผลิตภัณฑ์แม้แต่บรรทัดเดียว**

---

## 2. กติกาที่ Founder กำหนด — ตรวจครบทุกข้อ

### 2.1 ห้ามแตะไฟล์ Pop นอกเหนือจาก `home_pop_card.dart`

`git diff --name-only 0e23d8a..HEAD -- app/lib/features/pop/` → **ว่างเปล่า** ไม่มีไฟล์ Pop ไฟล์ไหนถูกแตะเลย

`pop_clip_view.dart` / `pop_comment_sheet.dart` / `pop_single_clip_screen.dart` ยังคงใช้ `Icons.favorite` ของ Material เหมือนเดิม — ตรงกับที่ WYN-108 spec บันทึกไว้เป็น known gap **ผ่าน**

### 2.2 หกจุดที่ห้ามย้อนกลับ (wyn-107 spec ข้อ 3)

| จุด | ต้องเป็น | ผลตรวจ |
|---|---|---|
| สีหัวใจถูกใจ | แดง ไม่ใช่ sapphire | `WynColors.iconLikeActive = #F44336` · ยืนยันด้วย widget test ว่าหัวใจที่ถูกใจแล้วเป็นสีนี้จริง ไม่ใช่ `sapphire` (#1B3A6B) **ผ่าน** |
| แถวปุ่ม | 3 ปุ่ม ไม่ใช่ 4 | หน้า Home ส่ง `showViewCount: false` → ถูกใจ/คอมเมนต์/รีโพสต์ = 3 **ผ่าน** |
| แท็บ | 3 อัน | `home_feed_screen.dart` **diff ว่างเปล่า** ไม่ถูกแตะเลย **ผ่าน** |
| ไอคอนขวาบน | แชท | ไฟล์เดียวกัน ไม่ถูกแตะ **ผ่าน** |
| ฟอนต์ | ฟอนต์ระบบ | `app/lib/core/design/` **diff ว่างเปล่า** **ผ่าน** |
| สีพื้น | ขาว `#FFFFFF` | `WynColors.paper = 0xFFFFFFFF` ไม่ถูกแตะ **ผ่าน** |

### 2.3 Security

| รายการ | ผล |
|---|---|
| Secret หลุดใน diff | **ไม่พบ** — grep `api_key/secret/password/token/bearer/service_role/eyJ…/BEGIN` ทั้ง diff เจอแต่คำว่า "token" ในความหมาย design token |
| เปลี่ยน RLS / policy | **ไม่มี** — migration ไม่มี `create/alter/drop policy`, `grant`, `revoke` เลยแม้แต่บรรทัดเดียว · ยืนยันบน DB จริง: `drops.relrowsecurity = t` และจำนวน policy คงเดิมหลัง migration |
| เปลี่ยน security model ของ view | **ไม่มี** — `home_feed` ยังเป็น `{security_invoker=true}` หลังรัน migration (ตรวจจาก `pg_class.reloptions`) |
| Migration additive จริงตามที่อ้าง | **จริง** — ดู §6 |
| แตะไฟล์ auth / permission | **ไม่มี** — ไฟล์ที่เปลี่ยนทั้งหมดอยู่ใน UI/data model/test/docs |

---

## 3. WYN-106 — ปุ่มหน้า Home + touch target — **PASS**

Feature: ขยายพื้นที่กดปุ่ม X ปิด `HomeExplainerBanner` จาก ~19×19 เป็น ≥44×44
ไฟล์: `app/lib/features/home/presentation/widgets/home_explainer_banner.dart:104-134`

### ผ่าน

- **QA4** — วัด hit box จริงบนจอ 360: `Rect.fromLTRB(284, 24, 328, 68)` = **44×44 พอดี** (เดิม ~19×19)
- ไอคอนที่เห็นยังเป็น `Icons.close` ขนาด 15 สี `graphite` เท่าเดิม ตำแหน่งยังชิดขวาบนเหมือนเดิม (`Alignment.topRight`)
- **พื้นที่กดใหม่ไม่ทับข้อความ** — text rect กว้างถึง x=276, hit box เริ่มที่ x=284 ไม่ overlap → ไม่มีการ "แย่งแตะ" จากข้อความในแบนเนอร์
- `Semantics(label: 'ปิดข้อความแนะนำ', button: true)` คงเดิม
- การกดปิด + จำค่าใน `shared_preferences` ยังทำงาน (test เดิมในชุดผ่าน)
- ไม่ overflow ที่ 320 / 360 / 390 / 430 และที่ textScale 1.3

### ข้อสังเกต — Minor 1 รายการ

**M-106-1 (Minor, cosmetic)** — spec เขียนว่า "ไม่กระทบภาพที่เห็น เพิ่มแค่พื้นที่กดโปร่งใสรอบตัวมัน" แต่ `ConstrainedBox` เป็นกล่องจริงใน `Row` ผลคือ:
- คอลัมน์ข้อความในแบนเนอร์แคบลง ~25px ทุกจอ
- แบนเนอร์สูงขึ้น ~10px (hit box สูง 44 > ข้อความสูง ~34)

ไม่ทำให้ล้น ไม่ทำให้อ่านไม่ออก และเป็นราคาที่ pattern เดียวกับ `ActionMetric` จ่ายอยู่แล้ว — **ยอมรับได้ ไม่ block** แต่ควรแก้ถ้อยคำใน spec ให้ตรงความจริง

**Final Status (WYN-106): PASS**

---

## 4. WYN-107 — การ์ดโพสต์สองคอลัมน์ — **PASS**

ไฟล์: `home_drop_card.dart`, `home_pop_card.dart`, `home_card_metrics.dart` (ใหม่), `post_media.dart`, `home_feed_image_peek_carousel.dart`

### ผ่าน (วัดจริงทุกตัวเลข)

| สิ่งที่ spec กำหนด | ค่าที่วัดได้ |
|---|---|
| คอลัมน์เนื้อหาเริ่มที่ 78 บนจอ 390 (24+40+14) | **78.0** — ทั้งชื่อผู้โพสต์และขอบซ้ายของรูป (QA3) |
| แถวรูปหลายใบล้นถึงขอบจอขวา | row = `LTRB(78, 0, 390, …)` → **ชนขอบพอดี** (QA15) |
| การ์ดรูป = 82% ของคอลัมน์ที่หัก right padding แล้ว = 236 | **236.2** (QA15) |
| รูปถัดไปโผล่ 68 | 390 − (78 + 236.2 + 8) = **67.8** |
| ห้ามล้นขอบซ้าย | ขอบซ้ายของทุก section = 78 ไม่มีอันไหนติดลบ (QA3/QA15) |
| รูปเดียวมีมุมโค้ง 16 และไม่กระทบ Drop Detail | `PostImageFrame.borderRadius` เป็นพารามิเตอร์ default `radiusNone` → Drop Detail/Club ไม่เปลี่ยน, ฟีดส่ง `radiusLg` **ตรงตาม handoff ข้อ 3 เป๊ะ** |
| touch target แถวปุ่มยัง 44px | `ActionMetric` ยัง `minHeight: touchTargetMin` |
| ปุ่ม ⋯ | ถูกบีบเป็น 44×44 พอดี (จากเดิม 48 default) — ยัง ≥ 44 ตาม DS-001 §6 |

### Responsive / edge case ที่ลองพัง

- `HomeDropCard` (ชื่อยาว + verified + สถานที่ + ตัวเลขหลักหมื่นทั้ง 4 ปุ่ม) ที่ **360px** และ **360px + textScale 1.3** → ไม่มี overflow exception (QA1, QA2)
- `HomePopCard` ที่ **320 / 360 / 390 / 430** × textScale **1.0 / 1.3** = 8 เคส → ไม่มี overflow สักเคส (QA16)

### ข้อสังเกต — ไม่มีระดับ Major

- **M-107-1 (Minor, ความไม่ตรงกันในตัว spec เอง)** — ผังใน spec เขียนว่าแถวรูป "(ไม่มี right padding) — ล้นถึงขอบจอขวา" แต่หัวข้อ "รูปเดียว" เขียนว่า 78 → 366 (คือมี right inset 24) โค้ดเลือกทำตามข้อหลัง (รูปเดียวหยุดที่ 366, แถวหลายรูปล้นถึง 390) ซึ่งเป็นการตีความที่ถูกต้องกว่า — บันทึกไว้ให้แก้ผัง ไม่ใช่แก้โค้ด

**Final Status (WYN-107): PASS**

---

## 5. WYN-108 — หัวใจทรง lucide — **FAIL**

ไฟล์: `wyn_heart_icon.dart` (ใหม่), `action_metric.dart` (เปลี่ยน API), + 11 จุดที่วาดหัวใจ

### สิ่งที่ตรวจแล้วผ่าน — รวมถึง 3 จุดเสี่ยงที่สุดที่โจทย์สั่งให้เน้น

| จุดเสี่ยง | ผล |
|---|---|
| **animation ตอนกดถูกใจยังทำงาน** | **ผ่าน (QA9)** — เปลี่ยน `likedByMe` false→true แล้ว `ScaleTransition.scale.value` ลดต่ำกว่า 1.0 ระหว่างทางแล้วกลับมา 1.0 ตอนจบ · การเปลี่ยนตัวเทียบจาก `icon` เป็น `iconState` ทำถูกต้อง |
| **หัวใจ double-tap ยังมีเงา** | **ผ่าน (QA10)** — `shadows` ยังไม่ว่าง, สี `paper`, ขนาด 72, `filled: true` · การแปลง `Shadow` เข้าสู่ canvas ที่ถูก scale ก็คำนวณถูก (`offset/scale`, `sigma/scale`) |
| **สีทุกสถานะไม่เปลี่ยน** | **ผ่าน** — ไล่ทีละจุดครบ 11 จุด: `iconLikeActive` (แดง) / `iconIdle` (graphite) / `paper` (ใน image viewer) / `Colors.white` (บน grid tile และ trending tile) — ไม่มีจุดไหนเปลี่ยนสี · จุดเดียวที่ "เปลี่ยน" คือ `club_post_detail_screen.dart` ที่เดิมเป็น `null` แล้วระบุชื่อเป็น `iconIdle` — ตรวจแล้วเป็น no-op จริง เพราะ `ColorScheme.onSurfaceVariant` ใน `wyn_colors.dart:268,307` = `graphite` = `iconIdle` |

เพิ่มเติมที่ผ่าน:
- `pop_clip_view.dart` / `pop_comment_sheet.dart` ไม่ถูกแตะ (known gap ตาม spec)
- `settings_screen.dart` / `notification_settings_screen.dart` ยังเป็น `Icons.favorite_border` ของ Material — ตรวจแล้วเป็นไอคอนหัวข้อเมนู ไม่ใช่ปุ่มถูกใจ **ทำถูกตาม spec ที่สั่งให้ตรวจก่อนแตะ**
- `notification_list_screen` และ `saved_post_row` แปลงเป็น named constructor แยกเคสหัวใจออกจาก `IconData` โดยไอคอนอื่นยังเป็น Material — ตรงกับ Design Rule ข้อ 2

### บั๊กที่พบ

#### B-108-1 — **Major** — หัวใจข้างคอมเมนต์ในหน้า Drop Detail โตจาก 16px เป็น 24px

- ไฟล์/บรรทัด: `app/lib/features/drop/presentation/drop_detail_screen.dart:1239-1247`
- โค้ด:
  ```dart
  IconButton(
    padding: EdgeInsets.zero,
    iconSize: 16,                 // <- ตั้งใจให้ 16 และยังบังคับไอคอนถังขยะข้างๆ อยู่
    icon: WynHeartIcon(
      filled: comment.likedByMe,
      size: 24,                   // <- ของใหม่ hardcode 24 → iconSize ไม่มีผลกับ widget
  ```
- สาเหตุ: `IconButton.iconSize` ส่งค่าผ่าน `IconTheme` ซึ่งมีผลกับ `Icon` เท่านั้น พอเปลี่ยนเป็น widget ที่ระบุ `size` เอง ค่า 16 เดิมจึงถูกเมิน
- **ผิด spec ตรงตัว** — WYN-108 spec กำหนด `size: ขนาดเท่าที่ Icon เดิมใช้อยู่ตรงจุดนั้น`
- Reproduce (ยืนยันแล้วด้วย widget test QA12): เปิด `DropDetailScreen` ของโพสต์คนอื่นที่มีคอมเมนต์ของเราเอง → วัดขนาดที่ render จริง
  ```
  QA12 deleteIcon=16.0  heartSizes=[19.0, 24.0]
  Expected: <16.0>   Actual: <24.0>
  ```
  (19.0 คือหัวใจของแถบ Focused Action Bar ซึ่งถูกต้อง, 24.0 คือหัวใจคอมเมนต์ซึ่งผิด)
- ผลกระทบ: หัวใจในแถวคอมเมนต์ใหญ่กว่าไอคอนถังขยะที่อยู่ติดกัน 50% เห็นชัดด้วยตาเปล่า

### ข้อสังเกตระดับ Minor

- **M-108-1** — ปุ่มรีโพสต์ "ได้ animation ใหม่" โดยไม่ได้ระบุใน spec: เดิม `icon` เป็น `Icons.repeat` คงที่ pop จึงไม่เคยเล่น ตอนนี้ `iconState: item.redroppedByMe` ทำให้เล่นทุกครั้งที่รีโพสต์/เลิกรีโพสต์ — เป็นการปรับปรุงที่สมเหตุสมผลและ comment ในโค้ดก็เขียนรองรับไว้ แต่ spec บอกว่า "ไม่เปลี่ยนพฤติกรรมใด ๆ" ควรให้ Founder รับทราบ
- **M-108-2** — spec สั่งให้ใส่ `ExcludeSemantics` ครอบ `CustomPaint` แต่ไม่ได้ใส่ · ตรวจแล้วไม่มีผลจริง (`CustomPaint` ที่ไม่มี `semanticsBuilder` ไม่ประกาศ node ใด ๆ) และชุดเทส accessibility เดิมผ่านหมด — ไม่ block แต่ควรบันทึกว่าตัดสินใจไม่ทำ
- **M-108-3** — path ของ lucide กินพื้นที่ใน viewBox 24 น้อยกว่า glyph ของ Material เล็กน้อย หัวใจที่ขนาดเท่ากันจึงดูเล็กลงนิดหน่อยทุกจุด — เป็นผลตรงจากการเลือกทรง B ที่ Founder อนุมัติ ไม่ใช่บั๊ก

**Final Status (WYN-108): FAIL** — ติด B-108-1

---

## 6. WYN-109b–d — เลือกสัดส่วนรูปตอนโพสต์ — **FAIL**

ไฟล์: `square_crop.dart`, `create_drop_screen.dart`, `drop_repository.dart`, `drop.dart`, `home_feed_item.dart`, `profile_photo_crop.dart`, `profile_photo_crop_screen.dart`, `post_media.dart`, `home_feed_image_peek_carousel.dart`

### 6.1 flow รูปโปรไฟล์ (WYN-104) — **ไม่กระทบ ยืนยันแล้ว**

โจทย์ข้อ 5 สั่งให้ยืนยันเป็นพิเศษ ตรวจแล้วดังนี้:

| สิ่งที่ตรวจ | ผล |
|---|---|
| ค่า default ของ `ProfilePhotoCropScreen` | `aspectRatio = 1`, `circular = true` — flow avatar ไม่ต้องส่งอะไรเพิ่ม **ผ่าน** |
| ขนาดกรอบครอปที่ render จริง | **260×260** เท่าเดิมเป๊ะ (QA13) |
| ทรงกรอบ | `ClipOval` → `ClipRRect(radius: 260)` บนกล่อง 260×260 = วงกลมเหมือนเดิม (Flutter clamp radius ที่ครึ่งด้าน) **ผ่าน** |
| สูตรคำนวณ scale | `baseCropScaleFactor` เดิม = `V / min(w,h)` · ของใหม่ = `max(V/w, V/h)` — พิสูจน์แล้วว่าเท่ากันทุกกรณีเมื่อ viewport เป็นจัตุรัส ทดสอบด้วย 4 คู่ขนาด (1000×500, 500×1000, 800×800, 37×91) ตรงกันถึง 1e-12 **ผ่าน** |
| `computeCropSourceRect` ยังคืน rect จัตุรัส | ผ่าน (width == height) |
| `cropToCircleSquare` | ยังอยู่ ยังเป็น alias ของ `cropToSourceRect` ที่คืน byte เดิม **ผ่าน** |
| ชุดเทส `profile_photo_crop_screen_test.dart` / `profile_photo_crop_test.dart` เดิม | ผ่านครบใน 1188 |

**สรุปข้อ 5: flow รูปโปรไฟล์ไม่เปลี่ยน**

### 6.2 เมื่อ production ยังไม่มีคอลัมน์ — **ฝั่งอ่านผ่าน ฝั่งเขียนพัง**

**ฝั่งอ่าน (ผ่าน):**
- `HomeFeedItem.fromMap` / `Drop.fromMap` อ่าน `map['image_aspect_ratio'] as String?` ซึ่งได้ `null` เมื่อไม่มีคอลัมน์ → `DropAspectRatio.fromWire(null)` = `portrait` (4:5) **ตรงตามที่ต้องการ (QA7)**
- ค่าขยะ (เช่น `'3:7'`) ก็ fallback เป็น 4:5 ไม่ throw **(QA8)**
- ทุก query ที่เกี่ยวข้องใช้ `select('*, …')` / `select()` ไม่มี query ไหนระบุชื่อคอลัมน์นี้ตรง ๆ → ไม่มี query พังเพราะคอลัมน์หาย

**ฝั่งเขียน (พัง) — ดู B-109-1 ด้านล่าง**

### 6.3 Migration — ตรวจซ้ำบน PostgreSQL 16 จริง

ยกฐานข้อมูลใหม่ โหลด `schema.sql` **เวอร์ชันก่อนงานนี้** (`git show 0e23d8a:supabase/schema.sql`) แล้ว seed โพสต์เก่า 1 แถวก่อน แล้วจึงรัน migration

| การทดสอบ | ผล |
|---|---|
| schema ก่อนหน้าโหลดสะอาด | 0 ERROR |
| ก่อน migration: `insert … (image_aspect_ratio)` | `ERROR: column "image_aspect_ratio" of relation "drops" does not exist` (นี่คือหลักฐานของ B-109-1) |
| รัน migration ครั้งที่ 1 | exit 0 |
| รัน migration ครั้งที่ 2 (idempotency) | exit 0 (`NOTICE: … already exists, skipping`) |
| โพสต์เก่าถูกแตะไหม | `untouched=1 total=1` — `image_aspect_ratio IS NULL`, caption ครบ **ไม่ถูกแตะ** |
| `home_feed` เปิดคอลัมน์ใหม่ | มี |
| CHECK ปฏิเสธค่าผิด | `'3:7'` → `violates check constraint` |
| CHECK รับค่าถูก | `'16:9'` → INSERT 0 1 |
| RLS ยังเปิด | `drops.relrowsecurity = t` |
| policy ของ `drops` | คงเดิม (migration ไม่มีคำสั่งเกี่ยวกับ policy เลย) |
| `home_feed` ยัง security_invoker | `{security_invoker=true}` |
| `schema.sql` เวอร์ชันใหม่โหลดจากศูนย์ | 0 ERROR และรัน migration ทับได้เป็น no-op |
| ไม่มี `drop view` (กับดัก SCHEMA-002) | ยืนยัน — ใช้ `create or replace view` และเพิ่มคอลัมน์ท้าย select list เท่านั้น |
| enum ฝั่ง Dart ตรงกับ CHECK | `['original','1:1','4:5','16:9']` ตรงกันเป๊ะ (QA11) |

**สรุป: migration เป็น additive จริง ปลอดภัย ย้อนกลับได้ ไม่แตะ RLS/permission** — ผ่านทุกข้อ

### 6.4 บั๊กที่พบ

#### B-109-1 — **Critical** — โพสต์ทุกชนิดจะพัง ถ้า deploy โค้ดนี้ก่อนที่ Founder จะรัน SQL

- ไฟล์/บรรทัด: `app/lib/features/drop/data/drop_repository.dart:945`
  ```dart
  .insert({
    …
    'image_aspect_ratio': aspectRatio?.wireValue,   // <- ใส่ key นี้ "เสมอ" แม้ค่าเป็น null
  })
  ```
- `_insertDrop` เป็นทางผ่านของ **ทุกเส้นทางการสร้างโพสต์** (บรรทัด 831 / 859 / 885): โพสต์รูป, โพสต์ข้อความล้วน, โพลล์, เผยแพร่ Draft จากรูปที่อัปโหลดแล้ว
- PostgREST สร้างรายชื่อคอลัมน์ของ `INSERT` จาก key ของ JSON ไม่ได้ดูว่าค่าเป็น null หรือไม่ → เมื่อ production ยังไม่มีคอลัมน์นี้ จะได้ `PGRST204 Could not find the 'image_aspect_ratio' column of 'drops' in the schema cache`
- **ยืนยันแล้วที่ระดับฐานข้อมูลจริง** (ดูตาราง §6.3): `ERROR: column "image_aspect_ratio" of relation "drops" does not exist`
- Reproduce: deploy branch นี้โดยที่ยังไม่รัน `supabase/migrations_wyn109_image_aspect_ratio.sql` → เปิดแอป → กด "โพสต์" อะไรก็ได้ → ล้มเหลวทุกครั้ง
- ความเสี่ยง: นี่คือ **สภาพจริงของ production ตอนนี้** ตามที่โจทย์ระบุ — ถ้า deploy สลับลำดับ ผู้ใช้จะโพสต์ไม่ได้เลยทั้งระบบ
- ทางแก้ที่แนะนำ (เลือกทางใดทางหนึ่ง หรือทำทั้งสอง):
  1. **บังคับลำดับ deploy**: Founder รัน SQL ให้เสร็จและ verify ก่อน แล้วจึง deploy แอป — และเขียนข้อบังคับนี้ลง release note/deploy checklist ให้ชัด
  2. **ทำให้โค้ดทนต่อการที่คอลัมน์ยังไม่มา** (แข็งแรงกว่า): ใส่ key นี้เฉพาะเมื่อ `aspectRatio != null` เท่านั้น ซึ่งจะทำให้เส้นทางโพสต์ข้อความ/โพลล์/Draft ปลอดภัยทันที (เหลือเฉพาะโพสต์รูปที่ต้องพึ่ง migration จริง ๆ)

#### B-109-2 — **Major** — โพสต์ 16:9 โดนครอปกลับเป็น 4:5 ทันทีที่กดเข้าไปดูในหน้าโพสต์

- ไฟล์/บรรทัด: `app/lib/features/drop/presentation/widgets/drop_image_gallery.dart:144-149`
- `DropImageGallery` มี `widget.drop.aspectRatio` อยู่ในมือแต่ไม่ได้ส่งต่อให้ `PostImageCarousel` → ใช้ค่า default `postCardAspectRatio` = 4/5 เหมือนเดิม
- Reproduce (ยืนยันด้วย widget test QA14): สร้างโพสต์หลายรูปที่ `aspectRatio = landscape` แล้วเทียบ `PostImageCarousel.aspectRatio` ระหว่างฟีดกับหน้ารายละเอียด
  ```
  QA14 feed   aspectRatio = 1.7777777777777777   (16:9 ถูกต้อง)
  QA14 detail aspectRatio = 0.8                  (4:5 ผิด)
  ```
- ผลกระทบ: โพสต์ใบเดียวกันมี 2 ทรงในแอปเดียว และเป็นอาการเดียวกับที่ spec เขียนไว้เองว่าเป็นเหตุผลที่ต้องทำงานนี้ ("คนที่เลือก 16:9 จะยังโดนครอปเป็น 4:5 อยู่ดี — ซึ่งแปลว่างานนี้ไม่ได้แก้อะไรเลยสำหรับเขา")
- หมายเหตุ: handoff ข้อ 4 เขียนคำว่า "ฟีด" จึงอาจตีความว่าอยู่นอกสโคป — แต่ `PostImageCarousel` ที่ handoff ระบุชื่อไว้ตรง ๆ ถูกใช้ที่นี่ด้วย จึงเสนอให้ถือเป็นส่วนหนึ่งของงานเดียวกัน (ถ้า Founder เห็นว่าเป็นงานแยก ให้แตกเป็น WYN-109e แทนการปล่อยผ่าน)

#### B-109-3 — **Major** — กดชิปแล้วรูปพรีวิวไม่เปลี่ยนสัดส่วน คนโพสต์ไม่เห็นสิ่งที่จะได้

- ไฟล์/บรรทัด: `app/lib/features/drop/presentation/create_drop_screen.dart:1216-1252`
- กรอบพรีวิวเป็น `SizedBox(width: 128, height: 160)` (= 4:5 ตายตัว) + `Image.memory(fit: BoxFit.cover)` ทุกกรณี · byte ข้างในเปลี่ยนทรงจริงตามชิป แต่กรอบไม่เปลี่ยน `BoxFit.cover` จึงครอปกลับเป็น 4:5 ให้ดู
- ผลจริง: เลือก 16:9 → เห็นเป็นสี่เหลี่ยมตั้ง 4:5 · เลือก 1:1 → ก็ยังเห็น 4:5 · เลือก "ต้นฉบับ" → ก็ยัง 4:5
- **ผิด spec 2 ข้อพร้อมกัน**: "แตะชิป → รูปพรีวิวทุกใบเปลี่ยนสัดส่วนทันที" และ "คนโพสต์เห็นตอนโพสต์ยังไง ในฟีดออกมาแบบนั้นเป๊ะ"
- Reproduce: หน้าสร้างโพสต์ → เลือกรูปแนวนอน → กดชิป 16:9 → รูปพรีวิวไม่เปลี่ยนรูปทรงเลย
- ผลกระทบ: ฟีเจอร์นี้ทั้งฟีเจอร์คือ "ให้คนโพสต์คุมการครอปได้" ถ้าพรีวิวไม่บอกความจริง คนโพสต์ก็ยังคุมไม่ได้อยู่ดี แค่ย้ายความไม่รู้จากตอนอัปโหลดไปเป็นตอนกดแชร์

### 6.5 ข้อสังเกตระดับ Minor

- **M-109-1** — ชิปที่ถูกเลือกไม่มีพื้นหลัง `#F4F7FB` ตามที่ spec Components กำหนด (มีแค่ขอบ+ตัวอักษร sapphire)
- **M-109-2** — เมื่อเลือก "ต้นฉบับ" การแตะรูปเป็น no-op (`_repositionImage` return ทันทีเมื่อ `ratio == null`) แต่ `Semantics(label: 'รูปที่ N กดเพื่อปรับตำแหน่ง', button: true)` ยังประกาศว่ากดได้ → screen reader บอกว่ากดได้แต่ไม่มีอะไรเกิดขึ้น
- **M-109-3** — เมื่อเลือก "ต้นฉบับ" ไฟล์ยังถูกตั้งนามสกุลเป็น `png` (`_imageExtensions.add('png')` ทุกกรณี) ทั้งที่ byte เป็น JPEG จาก picker เพราะ `_applyRatio` คืนค่าเดิมโดยไม่ encode ใหม่ → object ใน Supabase Storage ได้ `Content-Type: image/png` ทั้งที่เป็น JPEG (แอปยัง render ได้เพราะ decoder sniff เอง แต่ header ผิด)
- **M-109-4** — ครอปที่ผู้ใช้ลากเลือกเองจะถูกทิ้งเงียบ ๆ ถ้าเปลี่ยนชิปสัดส่วนภายหลัง (มี comment อธิบายเหตุผลไว้ในโค้ดแล้วและเป็นการตัดสินใจที่สมเหตุสมผล แต่ไม่มีอะไรบอกผู้ใช้)
- **M-109-5** — `PostImageFrame` (รูปเดียว) ยังวาดตามสัดส่วนจริงของไฟล์ ไม่ได้อ่าน `aspectRatio` ของโพสต์ — ในทางปฏิบัติผลเท่ากันเพราะ byte ถูกครอปมาแล้วและมีการบันทึก `image_width/height` แต่ถ้าอนาคตมีโพสต์ที่ค่า 2 อย่างไม่ตรงกัน (เช่น re-cut ล้มเหลวกลางทาง) จะไม่มีอะไรจับได้

**Final Status (WYN-109b–d): FAIL** — ติด B-109-1 (Critical), B-109-2, B-109-3 (Major)

---

## 7. Bug Report ที่ส่งต่อ AI Debug Engineer

| ID | ระดับ | หัวข้อ | ไฟล์ |
|---|---|---|---|
| B-109-1 | **Critical** | insert ส่งคอลัมน์ที่ production ยังไม่มี ทำให้โพสต์ทุกชนิดพัง | `.wyn/tasks/bugs/WYN-109-insert-sends-missing-column.md` |
| B-108-1 | **Major** | หัวใจข้างคอมเมนต์โตจาก 16px เป็น 24px | `.wyn/tasks/bugs/WYN-108-comment-heart-size-regression.md` |
| B-109-2 | **Major** | Drop Detail ยังวาด 4:5 ไม่สนสัดส่วนที่เลือก | `.wyn/tasks/bugs/WYN-109-detail-gallery-ignores-aspect-ratio.md` |
| B-109-3 | **Major** | พรีวิวหน้าสร้างโพสต์ไม่เปลี่ยนตามชิป | `.wyn/tasks/bugs/WYN-109-compose-preview-fixed-aspect.md` |

Minor ทั้งหมด (M-106-1, M-107-1, M-108-1..3, M-109-1..5) ไม่ block การ merge แต่รวมไว้ในใบ bug ที่เกี่ยวข้องเพื่อให้แก้พร้อมกันได้ถ้าคุ้ม

---

## 8. Recommendation

1. **ห้าม merge ทั้งชุดตอนนี้** — WYN-108 และ WYN-109 ยังไม่ผ่าน
2. **ห้าม deploy ก่อน Founder รัน `supabase/migrations_wyn109_image_aspect_ratio.sql` และ verify** ไม่ว่าจะแก้ B-109-1 หรือไม่ก็ตาม (migration ตรวจแล้วปลอดภัย รันได้เลย)
3. ทางเลือกที่แนะนำถ้าอยากได้ของขึ้นเร็ว: **แยก merge เป็น 2 ก้อน** — WYN-106 + WYN-107 ผ่าน QA แล้ว merge ได้ทันที (ไม่พึ่งฐานข้อมูลเลย) · WYN-108 + WYN-109 รอ Debug Engineer แก้ 4 ใบแล้วส่ง QA รอบ 2
   - ข้อควรระวัง: commit ทั้ง 13 ใบเรียงสลับกันอยู่บน branch เดียว การแยกต้อง cherry-pick — ให้ AI Deploy & DevOps ประเมินก่อนว่าคุ้มไหม ถ้าไม่คุ้มก็รอแก้ครบแล้ว merge ทีเดียว
4. หลังแก้ ให้ QA รอบ 2 ตรวจซ้ำอย่างน้อย: ขนาดหัวใจทุกจุดเทียบกับก่อนเปลี่ยน · สัดส่วนที่ฟีด/หน้าโพสต์/พรีวิวต้องตรงกันทั้ง 3 ที่ · เส้นทางสร้างโพสต์ทั้ง 4 แบบเมื่อยังไม่มีคอลัมน์
5. ขอให้ AI Coding เพิ่ม regression test 3 ตัวถาวร (ตอนนี้ยังไม่มี): หัวใจทุกจุดต้องมีขนาดตามตารางที่กำหนด · ฟีดกับหน้าโพสต์ต้องได้ `aspectRatio` เท่ากัน · payload ของ insert ต้องไม่มี key ที่ยังไม่มีคอลัมน์รองรับ

---

## 9. Output Format (ตามแบบบทบาท)

```
Feature:            WYN-106 ปุ่มหน้า Home / WYN-107 การ์ดสองคอลัมน์ /
                    WYN-108 หัวใจ lucide / WYN-109b-d สัดส่วนรูปตอนโพสต์
Environment:        branch claude/home-button-ux-ui-design-cbjkzm (ยังไม่ merge/deploy)
                    Flutter (analyze + test), PostgreSQL 16.13 scratch instance
Test Cases:         1188 (ชุดเดิม) + 16 (QA เขียนเพิ่มเอง) + 13 ข้อตรวจฐานข้อมูล
Passed:             1188 + 14 + 13
Failed:             2 (QA12 = B-108-1, QA14 = B-109-2) และ 1 พิสูจน์ที่ระดับ DB (B-109-1)
                    + 1 พบจากการอ่านโค้ดและยืนยันด้วยการวัดกรอบพรีวิว (B-109-3)
Severity:           Critical 1 · Major 3 · Minor 9
Reproduction Steps: ดู §5 (B-108-1) และ §6.4 (B-109-1/2/3)
Expected:           หัวใจคอมเมนต์ 16px · โพสต์ต้องมีทรงเดียวกันในฟีด/หน้าโพสต์/พรีวิว ·
                    สร้างโพสต์ได้แม้ production ยังไม่มีคอลัมน์ใหม่
Actual:             หัวใจคอมเมนต์ 24px · ฟีด 1.78 vs หน้าโพสต์ 0.8 vs พรีวิว 0.8 ·
                    insert ล้มเหลวทุกครั้งเมื่อยังไม่มีคอลัมน์
Security Findings:  ไม่พบ secret หลุด · ไม่มีการเปลี่ยน RLS/policy/grant ·
                    home_feed ยัง security_invoker=true · migration additive จริง
                    ยืนยันด้วยการรันบน PostgreSQL จริง
Recommendation:     ห้าม merge/deploy ทั้งชุด · ส่ง 4 ใบให้ AI Debug Engineer ·
                    เสนอแยก merge WYN-106+107 ก่อนถ้าต้องการของขึ้นเร็ว ·
                    ต้องรัน SQL ก่อน deploy เสมอไม่ว่ากรณีใด
Final Status:       WYN-106 PASS · WYN-107 PASS · WYN-108 FAIL · WYN-109b-d FAIL
```
