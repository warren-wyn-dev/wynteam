# Bug Report — WYN-110 (QA-WYN-110-002, pre-existing/out-of-scope)

Status: bugs
Owner: AI Debug Engineer (แนะนำให้แยกเป็น task ของตัวเอง เช่น WYN-096e/WYN-107e ไม่ใช่ WYN-110)
Severity: **Low** (เป็น visual overflow เล็กน้อย 3px ไม่ crash แอป)
พบโดย: AI QA & Security, 2026-09-05 (branch `claude/home-button-ux-ui-design-cbjkzm`) — พบระหว่าง
ทดสอบ responsive ของ WYN-110 ที่ 320px แต่ **ไม่ได้เกิดจากการเปลี่ยนแปลงของ WYN-110**

## สรุปสั้น: นี่ไม่ใช่บั๊กของ WYN-110

`git diff a75c24c de4b4b0 -- app/lib/features/home/presentation/widgets/home_drop_card.dart` **ไม่มี
การเปลี่ยนแปลงเลย** — ไฟล์นี้ไม่ได้ถูกแตะในงาน WYN-110 เลยแม้แต่บรรทัดเดียว บั๊กนี้มีอยู่ก่อนแล้วใน
`HomeDropCard` (ใช้ร่วมกันทั้ง Home feed และ 3 แท็บของโปรไฟล์) เพียงแต่ QA รอบนี้บังเอิญเจอมันระหว่าง
ทดสอบการเลื่อนที่ความกว้าง 320px ตามที่ WYN-110 กำหนดให้ต้องทดสอบ

**ไม่ควรบล็อกการอนุมัติ WYN-110** ด้วยบั๊กนี้ (WYN-110's design rules ก็ห้ามแตะการ์ดโพสต์อยู่แล้ว) —
แต่ต้องบันทึกไว้ไม่ให้หลุดลอยหายไป เพราะเป็นบั๊กจริงที่กระทบผู้ใช้จอเล็ก (320px, เช่น iPhone SE)

## Bug

Action row (หัวใจ/คอมเมนต์/รีโพสต์/ยอดวิว) ใน `HomeDropCard` ล้นขวา 3px ที่ความกว้างจอ 320px แม้กับ
โพสต์ที่ทุกยอด (like/comment) เป็น 0 (ไม่ใช่เพราะตัวเลขยาว)

## Files

- `app/lib/features/home/presentation/widgets/home_drop_card.dart:534` (`Row` ของ action bar)

```dart
Padding(
  padding: const EdgeInsets.only(right: homeCardEdgeInset),
  child: Row(
    children: [
      ActionMetric(icon: WynHeartIcon(...), ...),
      const SizedBox(width: WynSpacing.space5),
      ActionMetric(icon: const Icon(Icons.mode_comment_outlined), ...),
      // ... ต่อด้วย repost/eye
    ],
  ),
),
```

## Reproduction

Widget test แบบ minimal (ไม่ต้องเกี่ยวกับ scroll/NestedScrollView เลย) — pump `HomeDropCard` ตัวเดียว
ในจอกว้าง 320px ด้วยโพสต์ที่ `likeCount: 0, commentCount: 0`:

```
FlutterError: A RenderFlex overflowed by 3.0 pixels on the right.
  creator: Row ← Padding ← Column ← Expanded ← Row ← Column ← Padding ← ...
    home_drop_card.dart:534:34
  constraints: BoxConstraints(0.0<=w<=218.0, 0.0<=h<=Infinity)
  size: Size(218.0, 44.0)
```

ยืนยันซ้ำอีกทางหนึ่งใน `app/test/qa_wyn110_profile_scroll_header_test.dart` กลุ่ม "6. no overflow
while actively dragging at small widths" — เฉพาะเคส **320px** เท่านั้นที่ FlutterError ยิงระหว่างลาก
ผ่านโพสต์ที่เพิ่งเลื่อนเข้ามาในจอ (360/390/430px ผ่านสะอาดทั้งหมด ไม่มี overflow เลย) ยืนยันว่าเป็น
ปัญหาเฉพาะความกว้าง 320px จริง ไม่ใช่ปัญหาจากกลไกเลื่อนของ WYN-110

## Expected

Action row ต้องพอดีภายใน 320px เหมือนความกว้างอื่น ๆ ไม่มี overflow

## Actual

ล้นขวา 3.0 pixels ที่ 320px เท่านั้น

## Fix ที่เสนอ (ให้ Debug Engineer ตัดสินใจอีกที)

4 `ActionMetric` + `SizedBox(width: WynSpacing.space5)` คั่นระหว่างแต่ละตัว น่าจะรวมความกว้างธรรมชาติ
เกิน 218px ที่ 320px จอ (คอลัมน์เนื้อหาที่เหลือหลังหัก avatar ซ้าย) ลองแนวทาง:
- ลด spacing ระหว่างไอคอนที่ 320px โดยเฉพาะ (breakpoint-aware) หรือ
- ห่อ `Row` ด้วย `Flexible`/`FittedBox` ป้องกัน overflow ที่จอแคบสุด โดยไม่กระทบความกว้าง spacing ที่จอ
  ใหญ่กว่า (360px ขึ้นไปผ่านอยู่แล้ว ห้ามกระทบ)

## Regression Risk

ต่ำ — เป็นการปรับ spacing/overflow-guard เฉพาะจอ 320px เท่านั้น แต่ **ต้องแยกเป็น task/commit ของ
ตัวเอง** ไม่ควรรวมเข้ากับ WYN-110 (ขอบเขตของ WYN-110 คือกลไกเลื่อนเท่านั้น ห้ามแตะการ์ดโพสต์ตาม
design spec ของมันเอง)

## Tests ที่ต้องเพิ่ม

Widget test แยกสำหรับ `HomeDropCard` เอง (ไม่ต้องพ่วง Profile/NestedScrollView) ที่ยืนยันไม่ overflow
ที่ 320/360/390/430 กับโพสต์ที่ยอด like/comment เป็น 0 และเป็นตัวเลขจริง (เช่น 4-5 หลัก) ทั้งสองแบบ

## Handoff to QA

รอ PM/Founder ตัดสินว่าจะเปิด task ใหม่ (แนะนำ WYN-096e หรือเลขใหม่) หรือรวมกับงานถัดไปที่แตะ
`home_drop_card.dart` — เมื่อแก้แล้วให้ QA ตรวจ 320/360/390/430 ซ้ำทั้ง Home feed และ 3 แท็บโปรไฟล์
