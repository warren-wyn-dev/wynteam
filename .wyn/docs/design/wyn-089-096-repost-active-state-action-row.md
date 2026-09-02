# Design Spec — WYN-089 (Repost active state) + WYN-096 (Action row redesign)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-089.md`, `.wyn/tasks/backlog/WYN-096.md` (Product spec ทั้งคู่ระบุ Handoff ให้ทำพร้อมกัน — งานนี้จึงรวมเป็นเอกสารเดียว ครอบคลุมทั้ง 2 WYN id)
Design system อ้างอิง: current live tokens ใน `app/lib/core/design/wyn_colors.dart`/`wyn_spacing.dart` (palette หลัง "V1 rebrand" 2026-08-29 — `ink`/`paper`/`graphite`/`faint`/`hairline`/`sapphire` — ไม่ใช่ Cyan/Orange ของ `ds-001-color-system.md` เดิมที่ถูก supersede ไปแล้วเฉพาะ `app/`, ดู `.wyn/company/DECISIONS.md` 2026-08-29)
Pattern ที่มีอยู่แล้ว: `app/lib/features/drop/presentation/drop_detail_screen.dart` (`_buildFocusedActionBar()`/`_buildStatLine()`), `app/lib/features/home/presentation/widgets/home_drop_card.dart` (`ActionMetric` row), `app/lib/core/widgets/action_metric.dart`, `.wyn/docs/design/wyn-034-redrop.md` (Standard/Quote ReDrop toggle behavior — ไม่เปลี่ยนในงานนี้)

> **สำคัญ**: Founder แนบภาพอ้างอิงสำหรับ WYN-096 มากับ PDF ต้นฉบับ (ข้อ 28/28) — **session นี้ไม่มีไฟล์ภาพนั้น** จึงออกแบบ WYN-096's ส่วน "หน้าตาใหม่ทั้งแถว" จากคำพูดของ Founder ("อยากให้เปลี่ยน เอาแบบตามในรูปเลย") + design system ที่มีอยู่แล้ว + pattern ที่ระบบเพิ่งอนุมัติ-โค้ดไปแล้วจริง (`DropDetailScreen`'s Focused Action Bar) เท่านั้น **ไม่ได้เดาค่าสี/พิกัด/ไอคอนที่อ้างว่าตรงกับภาพที่มองไม่เห็น** — ส่วนนี้เป็น **draft รอ Founder ยืนยันเทียบกับภาพต้นฉบับ** ส่วน WYN-089 (สถานะ active สีของปุ่มรีโพสต์) เป็นข้อเท็จจริงเชิงพฤติกรรมล้วนๆ (ไม่ต้องพึ่งภาพ) จึง **พร้อมขึ้นโค้ดได้ทันที**

---

## จุดที่ตรวจโค้ดจริงแล้วเจอ (สำคัญต่อการตัดสินใจทั้งหมดข้างล่าง)

`DropDetailScreen._buildFocusedActionBar()` (ใช้เมื่อเปิดโพสต์เต็มจอ) **มีสถานะ active ของปุ่มรีโพสต์อยู่แล้ว**:
```dart
Icon(Icons.repeat, size: 19,
  color: _drop.redroppedByMe ? WynColors.sapphire : WynColors.graphite)
```
แต่ `HomeDropCard`'s `ActionMetric` (ใช้ในฟีด Home/โปรไฟล์/hashtag feed) **ยังไม่มี** — `color: WynColors.graphite` คงที่เสมอไม่ว่า `item.redroppedByMe` จะเป็นอะไร (ดู `home_drop_card.dart` บรรทัด repost `ActionMetric`) นี่คือช่องว่างเดียวที่ WYN-089 ต้องปิด — ไม่ใช่ฟีเจอร์ใหม่ เป็นการทำให้ 2 จุดที่ควรสอดคล้องกันตรงกันจริง (การ์ดฟีดกับหน้ารายละเอียดต้องบอกสถานะเดียวกัน)

นอกจากนี้ `HomeDropCard`'s action row (icon+count ในกล่องเดียวกัน 4 ตัว: Like/Comment/Repost/View) กับ `DropDetailScreen`'s action row (ไอคอนล้วน 5 ปุ่มคั่นด้วยเส้น hairline บนล่าง + ตัวเลขแยกอยู่ใน stat line ต่างหากด้านบน) **เป็นคนละสไตล์กันอยู่แล้วตอนนี้** — ไม่ใช่สิ่งที่งานนี้สร้างขึ้นใหม่ เป็นความไม่สอดคล้องที่มีอยู่ก่อน ซึ่งเกี่ยวข้องโดยตรงกับสิ่งที่ WYN-096 ถูกขอมา (Founder อยากให้แถวปุ่มปฏิสัมพันธ์ "เปลี่ยน เอาแบบตามในรูป")

---

## Part 1 — WYN-089: Repost active state (พร้อมขึ้นโค้ด ไม่ต้องรอภาพ)

Screen: `HomeDropCard` (ฟีด Home ทุกแท็บ, 3 tab ของโปรไฟล์ที่ reuse widget เดียวกัน, hashtag feed)

Purpose: ให้ไอคอนรีโพสต์ในฟีดบอกสถานะ "ฉันรีโพสต์ไปแล้ว" แบบเดียวกับที่ `DropDetailScreen` ทำอยู่แล้ว — ปิด gap ความไม่สอดคล้องระหว่าง 2 จุด

User Flow: ผู้ใช้กดรีโพสต์ (Standard) จากการ์ดในฟีด → ไอคอน 🔁 เปลี่ยนเป็นสี sapphire ทันที (optimistic, ตาม pattern เดิมของปุ่มนี้ใน `wyn-034-redrop.md`) → เลื่อนออกจากจอแล้วกลับมาเห็นใหม่ ไอคอนยังเป็น sapphire อยู่ (สถานะไม่หายเมื่อ rebuild)

Components: ไม่มี component ใหม่ — แก้ค่า `color` ที่ส่งเข้า `ActionMetric` ตัวที่ 3 (repost) ใน `home_drop_card.dart` เท่านั้น

Interactions: ไม่เปลี่ยนพฤติกรรมการกด (ยังเปิด action sheet "รีโพสต์"/"ยกเลิกรีโพสต์"/"Quote รีโพสต์" เหมือนเดิมทุกประการ ตาม `wyn-034-redrop.md`) — งานนี้แก้แค่ "หน้าตาตอนพัก" (rest state) ของไอคอน ไม่แก้ interaction

States:
- `item.redroppedByMe == false` → ไอคอน `Icons.repeat` สี `WynColors.graphite` (เหมือนเดิมทุกประการ)
- `item.redroppedByMe == true` → ไอคอน `Icons.repeat` สี `WynColors.sapphire` **(ค่าเดียวกันเป๊ะกับที่ `DropDetailScreen._buildFocusedActionBar()` ใช้อยู่แล้วสำหรับสถานะนี้ — ไม่ใช่สีใหม่)**
- ตัวเลขนับ (`item.redropCount`) **ไม่เปลี่ยนสีตามสถานะ** — คงเป็น `WynColors.graphite` เสมอเหมือนไอคอน Comment/View (ตัวเลขนับไม่ใช่ตัว indicator ของสถานะ "ฉันทำแล้วหรือยัง" มันคือยอดรวม; ไอคอนอย่างเดียวพอสื่อสถานะ — ตรงกับที่หัวใจ Like ก็ทำแบบนี้: เฉพาะไอคอนเปลี่ยนสี ตัวเลขไม่เปลี่ยน)

Responsive Behavior: ไม่เปลี่ยน — ยังเป็น `ActionMetric` เดิมทุกมิติ (iconSize 17, gap 6px ระหว่างไอคอน-ตัวเลข)

Accessibility: `semanticsLabel` ของ `ActionMetric` ตัวนี้**มีข้อความสถานะอยู่แล้ว** ("รีโพสต์แล้ว กดเพื่อเลือกดำเนินการ" / "กดเพื่อรีโพสต์" — ดู `home_drop_card.dart` บรรทัด 440-442) ไม่ต้องแก้ — สีเป็นแค่ชั้น visual เสริม ไม่ใช่ช่องทางสื่อสารเดียว (ตรงตามกติกา DS-001 ข้อ "ไม่สื่อสารด้วยสีอย่างเดียว" — screen reader ได้ข้อความสถานะอยู่แล้วไม่ว่าจะเห็นสีหรือไม่)

Design Rules: ใช้ `WynColors.sapphire` (ไม่ใช่สีใหม่ ไม่ใช่ `Colors.red` แบบปุ่ม Like — รีโพสต์ไม่ใช่ universal-red-heart convention ใช้สี accent หลักของแอปแทนเหมือนที่ `DropDetailScreen` ทำอยู่แล้ว) — ห้ามใช้สีอื่นแม้แต่จุดเดียว เพื่อให้ 2 จุด (ฟีด + รายละเอียด) ตรงกัน 100%

Handoff: AI Coding — แก้ 1 บรรทัดใน `home_drop_card.dart` (ActionMetric ตัว repost): `color: item.redroppedByMe ? WynColors.sapphire : WynColors.graphite` (เดิม `color: WynColors.graphite` คงที่) เขียน widget test ยืนยันสี 2 สถานะ (มิเรอร์ pattern เดียวกับเทสที่มีอยู่แล้วสำหรับ Like's สี 2 สถานะ ถ้ามี) — **ทำพร้อมกับ Part 2 ด้านล่างได้ในรอบเดียว เพราะ Part 2 (ถ้า Founder อนุมัติ) ก็ต้องมีสถานะ active นี้อยู่ในดีไซน์ใหม่อยู่ดี**

---

## Part 2 — WYN-096: แถวปุ่มปฏิสัมพันธ์ใหม่ (draft — รอ Founder ยืนยันกับภาพต้นฉบับ)

Screen: `HomeDropCard`'s action row (ฟีด/โปรไฟล์/hashtag) — `DropDetailScreen`'s action row **อยู่นอกสโคปการเปลี่ยน** (เป็นสไตล์เป้าหมายอยู่แล้ว ดูเหตุผลด้านล่าง)

Purpose: Founder อยากให้ไอคอน/ปุ่ม like-comment-repost เปลี่ยนหน้าตาตามภาพอ้างอิงที่แนบมา — session นี้ไม่มีภาพนั้น จึงเสนอทิศทางที่มีหลักฐานรองรับมากที่สุดเท่าที่ทำได้โดยไม่เดาสุ่ม

**ข้อเสนอ (draft)**: ทำให้ `HomeDropCard`'s action row ใช้โครงสร้างเดียวกับ `DropDetailScreen`'s Focused Action Bar ที่มีอยู่แล้วและผ่านการอนุมัติ/ขึ้นโค้ดจริงไปแล้วก่อนหน้านี้ (อ้างอิงจาก `design-reference/07-post-detail.tsx` ตามที่ comment ในโค้ดระบุ) แทนที่จะคงสไตล์ icon+count-ในกล่องเดียวกันแบบปัจจุบันของการ์ดฟีด

เหตุผลที่เลือกทิศทางนี้เป็น draft แรก (ไม่ใช่การเดาสุ่ม):
1. เป็น pattern เดียวในระบบตอนนี้ที่ Founder เคย "อนุมัติภาพอ้างอิง" มาก่อนแล้วจริง (`07-post-detail.tsx`) แม้จะคนละหน้าจอ (Detail ไม่ใช่ Feed) — ความเสี่ยงที่จะผิดทิศทางต่ำกว่าการคิดสไตล์ใหม่ทั้งหมดที่ไม่มีหลักฐานอ้างอิงเลย
2. ทำให้การ์ดฟีดกับหน้ารายละเอียดโพสต์ (ที่เป็นเนื้อหาเดียวกัน) มีหน้าตาแถวปฏิสัมพันธ์ตรงกัน — ลดความไม่สอดคล้องที่มีอยู่ก่อนแล้ว (ดูหัวข้อ "จุดที่ตรวจโค้ดจริง" ด้านบน)
3. ไม่ต้องเพิ่ม token สี/spacing ใหม่เลย — ใช้ `WynColors.hairline`/`sapphire`/`graphite`/`red` (Like) และ `WynSpacing` เดิมทั้งหมด

**สิ่งที่ยังไม่ยืนยัน (เหตุผลที่ต้องเป็น draft)**: ภาพอ้างอิงของ Founder อาจแสดงสไตล์อื่นไปเลยก็ได้ (เช่น ไอคอนแบบ outline/fill ต่างจากปัจจุบัน, ลำดับปุ่มต่างกัน, มีปุ่มเพิ่ม/ลด) — ข้อเสนอนี้จึงเป็นจุดเริ่มต้นให้ Founder เทียบกับภาพจริงว่าตรงหรือไม่ ไม่ใช่ spec สุดท้าย

### รายละเอียด draft ถ้า Founder ยืนยันทิศทางนี้

Components:
- แถบปุ่มไอคอนล้วน (ไม่มีตัวเลขติดไอคอน) คั่นด้วยเส้น `WynColors.hairline` บน-ล่าง (มิเรอร์ `_buildFocusedActionBar()` เป๊ะ) — Like / Comment / Repost / View (**ไม่มี Share/Save** ในแถวนี้ เพราะทั้งสองย้ายเข้าเมนู "..." ไปแล้วตาม WYNOSHomeSpec.md 4.6 ที่การ์ดฟีดใช้อยู่แล้วในปัจจุบัน — DropDetailScreen มี Share/Save ในแถวนี้เพราะเป็นหน้ารายละเอียดที่ไม่มีเมนู "..." แบบเดียวกัน จึงมี 5 ปุ่มไม่ใช่ 4 คนละบริบทกัน ไม่ต้องเหมือนกันเป๊ะจุดนี้)
- ตัวเลขนับ (like/comment/repost/view) ย้ายไปอยู่แยกเป็น "stat line" ข้อความบรรทัดเดียวเหนือแถวปุ่ม (มิเรอร์ `_buildStatLine()`: "12 ถูกใจ · 3 คอมเมนต์ · 1 รีโพสต์ · 340 การเข้าชม") — วางระหว่าง media area (รูป/Poll) กับแถวปุ่ม
- สีไอคอน: Like ใช้ `Colors.red` เมื่อ `likedByMe` (ตาม convention ที่แก้ให้ตรงกันทั้งแอปแล้วเมื่อ 2026-09-02, ดู DECISIONS.md) / Repost ใช้ `WynColors.sapphire` เมื่อ `redroppedByMe` (WYN-089, Part 1 ด้านบน) / Comment/View ใช้ `WynColors.graphite` เสมอ (ไม่มีสถานะ active)

Interactions: แตะไอคอนยังทำงานเหมือนเดิมทุกจุด (Like toggle, Comment เปิด detail/focus, Repost เปิด action sheet, View ไม่ใช่ปุ่มกด) — เปลี่ยนแค่ "หน้าตา" ไม่เปลี่ยน logic

States: เหมือน Part 1 ทุกประการสำหรับ Repost — Like ใช้ pattern เดิมของแอป (filled/outline heart แดง)

Responsive Behavior: แถบปุ่ม 4 ปุ่มแบ่งพื้นที่เท่ากัน (`Expanded` ต่อปุ่ม มิเรอร์ 5-ปุ่มของ Detail แต่เหลือ 4 ปุ่ม) — ต้องทดสอบที่ 360px เหมือนจุดอื่นในระบบ

Accessibility: คง `Semantics(label: ...)` เดิมทุกจุดจาก `ActionMetric`/`_buildFocusedActionBar()` — ไม่มีจุดไหนสื่อสารด้วยสีอย่างเดียว (มีข้อความ semantics ประกาศสถานะเสมอ)

Design Rules: ห้ามเพิ่มสี/ไอคอนใหม่ที่ไม่มีอยู่แล้วในระบบ — ทุกอย่างในหัวข้อนี้ reuse ของเดิม 100%

### Handoff (Part 2)

**อย่าเพิ่งขึ้นโค้ด Part 2** จนกว่า Founder จะยืนยันว่า draft นี้ตรงกับภาพอ้างอิงจริงหรือไม่ (ผ่าน popup เลือก: "ตรงกับที่ต้องการ" / "ไม่ตรง ขอแนบภาพใหม่/อธิบายเพิ่ม") — ถ้าตรง ส่งต่อ AI Coding แก้ `home_drop_card.dart` ให้ย้ายจาก `ActionMetric` แบบ icon+count ไปเป็น structure ใหม่ตาม draft ข้างบน (ต้องเพิ่ม stat-line widget ใหม่ที่ยังไม่มีในไฟล์นี้ — `DropDetailScreen._buildStatLine()` พอ reuse โครงสร้างได้แต่เป็น private method อยู่ในไฟล์อื่น ต้อง extract เป็น shared widget ก่อน) — **Part 1 (WYN-089) ไม่ต้องรอ Part 2** ทำได้อิสระเพราะ 2 สไตล์ (icon+count เดิม หรือ icon-only+stat-line ใหม่) ก็ต้องมีสถานะ active ของ repost เหมือนกันทั้งคู่

## สรุปสถานะ

- **WYN-089**: พร้อมขึ้นโค้ดทันที ไม่มีอะไรบล็อก
- **WYN-096**: draft รอ Founder ยืนยันภาพอ้างอิง — ยังไม่ส่ง AI Coding
