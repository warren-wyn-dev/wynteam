# Bug Report — WYN-108 (B-108-1)

Status: bugs
Owner: AI Debug Engineer
Severity: **Major**
พบโดย: AI QA & Security, 2026-09-04 (branch `claude/home-button-ux-ui-design-cbjkzm`, ยังไม่ merge/deploy)

## Bug

หัวใจถูกใจข้างคอมเมนต์ในหน้า Drop Detail ถูกวาดที่ **24px** ทั้งที่ของเดิมวาดที่ **16px**
ทำให้ใหญ่กว่าไอคอนถังขยะที่อยู่แถวเดียวกัน 50% เห็นชัดด้วยตาเปล่า

## Files

- `app/lib/features/drop/presentation/drop_detail_screen.dart:1239-1247`

```dart
IconButton(
  padding: EdgeInsets.zero,
  iconSize: 16,                 // ยังบังคับไอคอนถังขยะข้าง ๆ อยู่ (16px)
  icon: WynHeartIcon(
    filled: comment.likedByMe,
    size: 24,                   // <- hardcode 24 -> iconSize ไม่มีผลกับ widget
    color: …,
  ),
  onPressed: () => _toggleCommentLike(comment.id),
),
```

## Root Cause

`IconButton.iconSize` ส่งค่าลงไปผ่าน `IconTheme` ซึ่งมีผลกับ widget `Icon` เท่านั้น
โค้ดเดิมเป็น `Icon(...)` โดยไม่ระบุ `size` จึงรับ 16 มาจาก `iconSize`
พอเปลี่ยนเป็น `WynHeartIcon` ที่บังคับ `size` ของตัวเอง ค่า 16 เดิมจึงถูกเมิน และคนแก้เลือกใส่ 24 (ค่า default ของ Material) แทน

ผิด WYN-108 spec ตรงตัว: `size: ขนาดเท่าที่ Icon เดิมใช้อยู่ตรงจุดนั้น`

## Reproduction

1. เปิด `DropDetailScreen` ของโพสต์คนอื่น ที่มีคอมเมนต์ของผู้ใช้ปัจจุบัน 1 รายการ
2. วัดขนาดที่ render จริงของหัวใจในแถวคอมเมนต์ เทียบกับไอคอนถังขยะข้าง ๆ

ยืนยันด้วย widget test (QA12):
```
QA12 deleteIcon=16.0  heartSizes=[19.0, 24.0]
Expected: <16.0>   Actual: <24.0>
```
(19.0 = หัวใจของ Focused Action Bar ซึ่งถูกต้อง · 24.0 = หัวใจคอมเมนต์ซึ่งผิด)

## Expected

หัวใจคอมเมนต์ = 16px เท่าไอคอนถังขยะในแถวเดียวกัน (เท่าของเดิมก่อน WYN-108)

## Actual

24px

## Fix ที่เสนอ

เปลี่ยน `size: 24` เป็น `size: 16` (และพิจารณาลบ `iconSize: 16` ที่ตอนนี้ไม่มีผลกับหัวใจแล้ว
เพื่อไม่ให้เข้าใจผิดว่ายังคุมอยู่ — แต่ต้องเช็คก่อนว่ามันยังคุมไอคอนอื่นใน `IconButton` เดียวกันหรือไม่)

## Regression Risk

ต่ำ — ตัวเลขเดียว · ปุ่มยังอยู่ในกล่อง 44×44 เหมือนเดิม touch target ไม่เปลี่ยน

## หมายเหตุ: ทบทวนขนาดหัวใจทุกจุดพร้อมกัน

QA ไล่ตรวจ 11 จุดแล้ว จุดอื่นตรงกับของเดิมหมด (17/17/18/19/22/13/13/16/10/72)
เหลือจุดนี้จุดเดียวที่หลุด — แต่เพราะมันเป็นจุดเดียวที่ **ไม่เคยระบุ `size` ตรง ๆ** ในโค้ดเดิม
ควรตรวจซ้ำว่าไม่มีที่อื่นในอนาคตพึ่ง `IconButton.iconSize` แบบเดียวกัน

## Minor ที่ควรจัดการพร้อมกัน (ไม่ block)

- **M-108-1** — ปุ่มรีโพสต์ได้ pop animation ที่เดิมไม่เคยมี (เพราะ `iconState: item.redroppedByMe`)
  เป็นการปรับปรุงที่ดี แต่ spec เขียนว่า "ไม่เปลี่ยนพฤติกรรมใด ๆ" → ควรแจ้ง Founder ให้รับทราบ/อนุมัติ
- **M-108-2** — spec สั่งใส่ `ExcludeSemantics` ครอบ `CustomPaint` แต่ไม่ได้ใส่
  ตรวจแล้วไม่มีผลจริง (`CustomPaint` ที่ไม่มี `semanticsBuilder` ไม่ประกาศ semantics node)
  → แก้ spec หรือใส่เพื่อความชัดเจน อย่างใดอย่างหนึ่ง

## Tests ที่ต้องเพิ่ม

regression test ถาวร: หัวใจทุกจุดในแอปต้องมีขนาดตรงตามตารางที่กำหนด (กันไม่ให้ drift ซ้ำแบบ WYN-076)

## Handoff to QA

หลังแก้ ให้ QA วัดขนาดหัวใจที่ render จริงทุกจุด (11 จุด) เทียบกับค่าก่อน WYN-108

---

**ปิดแล้ว 2026-09-04** — แก้ใน commit `ea6f33f` และ QA รอบ 2 ยืนยันแล้วด้วย QA-R2-25 (วัดขนาดที่ render จริง เทียบกับไอคอนลบข้าง ๆ)
เทสต์ที่แถมมากับการแก้ครั้งแรกตรวจด้วยการอ่านข้อความในซอร์ส ซึ่งจับได้แค่การ revert แบบตรงตัว
รอบ 2 จึงเพิ่มเทสต์ที่วัดสิ่งที่แอปวาด/ส่งออกจริงมาคุมทับอีกชั้น
รายงาน: `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa-round2.md`
