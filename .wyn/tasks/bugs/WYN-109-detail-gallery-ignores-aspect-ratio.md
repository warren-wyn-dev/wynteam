# Bug Report — WYN-109 (B-109-2)

Status: bugs
Owner: AI Debug Engineer
Severity: **Major**
พบโดย: AI QA & Security, 2026-09-04 (branch `claude/home-button-ux-ui-design-cbjkzm`, ยังไม่ merge/deploy)

## Bug

โพสต์หลายรูปที่คนโพสต์เลือกสัดส่วน 16:9 (หรือ 1:1 หรือต้นฉบับ) จะแสดง **ถูกต้องในฟีด**
แต่พอกดเข้าไปดูในหน้าโพสต์ (Drop Detail) กลับ **โดนครอปกลับเป็น 4:5** เหมือนก่อนมี WYN-109

`DropImageGallery` มี `widget.drop.aspectRatio` อยู่ในมือแล้ว แต่ไม่ได้ส่งต่อให้ `PostImageCarousel`
จึงตกไปใช้ค่า default `postCardAspectRatio` = 4/5

## Files

- `app/lib/features/drop/presentation/widgets/drop_image_gallery.dart:144-149`

```dart
PostImageCarousel(
  imageUrls: imageUrls,
  // ไม่มี aspectRatio: widget.drop.aspectRatio.ratio ?? …
  onIndexChanged: (index) => setState(() => _currentIndex = index),
  semanticLabelBuilder: (index, total) => 'รูปที่ ${index + 1} จาก $total',
),
```

เทียบกับฝั่งฟีดที่ทำถูกแล้วใน `home_feed_image_peek_carousel.dart:141-146`

## Reproduction

1. สร้าง Drop หลายรูปที่ `aspectRatio = DropAspectRatio.landscape` (16:9)
2. ดูในฟีด Home → การ์ดรูปเป็น 16:9 ถูกต้อง
3. กดเข้าไปดูในหน้าโพสต์ → การ์ดรูปกลับเป็น 4:5 ครอปบน-ล่าง

ยืนยันด้วย widget test (QA14) เทียบ `PostImageCarousel.aspectRatio` ของทั้งสองที่:
```
QA14 feed   aspectRatio = 1.7777777777777777   (16:9 ถูกต้อง)
QA14 detail aspectRatio = 0.8                  (4:5 ผิด)
```

## Expected

โพสต์ใบเดียวกันมีทรงเดียวกันทุกที่ในแอป — ตามที่ spec เขียนไว้เองว่า
"คนที่เลือก 16:9 จะยังโดนครอปเป็น 4:5 อยู่ดี — ซึ่งแปลว่างานนี้ไม่ได้แก้อะไรเลยสำหรับเขา"

## Actual

ฟีด 1.78 · หน้าโพสต์ 0.8 — สองทรงในแอปเดียว

## Fix ที่เสนอ

ส่ง `aspectRatio` ให้ `PostImageCarousel` ใน `DropImageGallery` ด้วยสูตรเดียวกับที่ฟีดใช้:
```dart
aspectRatio: widget.drop.aspectRatio.ratio ??
    postImageAspectRatio(widget.drop.imageWidth, widget.drop.imageHeight),
```

**ตรวจก่อนแก้**: `club_post_card.dart:319` ก็ใช้ `PostImageCarousel` เหมือนกัน แต่ Club post ไม่มีคอลัมน์สัดส่วน
→ **ห้ามแตะ** ปล่อยให้ใช้ default 4:5 ต่อไป

## ประเด็นขอบเขต (ต้องให้ Founder/PM ตัดสิน)

handoff ข้อ 4 ของ spec เขียนคำว่า "ฟีด" จึงอาจตีความว่าหน้าโพสต์อยู่นอกสโคป
แต่ `PostImageCarousel` ที่ handoff ระบุชื่อไว้ตรง ๆ ถูกใช้ที่นี่ด้วย
QA เสนอให้ถือเป็นส่วนหนึ่งของงานเดียวกัน — ถ้า Founder เห็นว่าเป็นงานแยก ให้แตกเป็น **WYN-109e**
แต่ **ห้ามปล่อยผ่านเงียบ ๆ** เพราะเป็นอาการเดียวกับที่ WYN-109 ตั้งใจแก้ตั้งแต่ต้น

## Regression Risk

ต่ำ — เพิ่มพารามิเตอร์เดียวให้ widget ที่รองรับอยู่แล้ว · โพสต์เก่า (`aspectRatio` = portrait) ได้ 0.8 เท่าเดิม ไม่เปลี่ยน

## Tests ที่ต้องเพิ่ม

regression test: ฟีดกับหน้าโพสต์ต้องได้ `PostImageCarousel.aspectRatio` ค่าเดียวกันเสมอสำหรับ Drop ใบเดียวกัน

## Handoff to QA

หลังแก้ ให้ QA ตรวจทั้ง 4 สัดส่วน × (ฟีด / หน้าโพสต์ / พรีวิวตอนโพสต์) และตรวจว่า Club post ยังไม่เปลี่ยน

---

**ปิดแล้ว 2026-09-04** — แก้ใน commit `ea6f33f` และ QA รอบ 2 ยืนยันแล้วด้วย QA-R2-15/16/17/18 (ฟีดกับหน้าโพสต์ต้องได้ค่าตรงกันเป๊ะ)
เทสต์ที่แถมมากับการแก้ครั้งแรกตรวจด้วยการอ่านข้อความในซอร์ส ซึ่งจับได้แค่การ revert แบบตรงตัว
รอบ 2 จึงเพิ่มเทสต์ที่วัดสิ่งที่แอปวาด/ส่งออกจริงมาคุมทับอีกชั้น
รายงาน: `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa-round2.md`
