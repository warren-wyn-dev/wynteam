# Design Spec — WYN-096: Home Feed Action Bar (Like/Comment/Repost/View) Alignment

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/active/WYN-096-home-feed-action-bar-alignment.md`
อ้างอิงภาพต้นฉบับจาก Founder (Beta2 Phase 2 PDF revision list, item 28 — ที่ตั้ง
`/root/.claude/uploads/874e2b82-2d79-56e1-bb55-bece689d658d/a279a127-image.jpg`, เป็นภาพ crop
+ วงสีแดงล้อมของ item 13 เดิม)
อ้างอิง Design System ปัจจุบัน (Sapphire era): `app/lib/core/design/wyn_colors.dart`,
`app/lib/core/design/wyn_spacing.dart`, `design-reference/SPEC.md` Section 3
("Spacing & layout constants") และ Section 4.9 ("Action bar") — **ไม่ใช้**
`.wyn/docs/design/ds-001-color-system.md` (Cyan เดิม, ถูกแทนที่แล้วตาม
`.wyn/company/DECISIONS.md` "เปลี่ยน Color Direction ของ WYN: Cyan → Sapphire", 2026-08-29)

## ภาพอ้างอิงคืออะไรจริง ๆ

ภาพ item 28 (`a279a127-image.jpg`) เป็น **crop ของภาพ item 13 เดิม** (`c2a85036-image.jpg`,
โพสต์ "ZEN") เฉพาะแถว "ถูกใจโดย ... คน" กับแถวไอคอน หัวใจ/คอมเมนต์/รีโพสต์/ตา โดยมีวงสีแดงเขียน
มือล้อมรอบแถวไอคอนไว้ทั้งแถว คำกำกับ: "28 ปุ่ม กดใจ กดคอมเม้น กดรีโพสต์ อยากให้เปลี่ยน เอาแบบ
ตามในรูปเลย" — วงสีแดงล้อมรอบ **แถวเดียวกับที่ item 13 ใช้เป็นภาพอ้างอิงของการ์ดข้อความล้วน
อยู่แล้ว** (`design-reference/01-home.tsx`'s `posts[1]`, ตรงกับ `ActionBar` component ในไฟล์
เดียวกัน) ความหมายคือ: **นี่คือภาพเป้าหมายที่ต้องการ (target) ไม่ใช่ภาพของปัญหาปัจจุบัน** —
Founder ใช้ screenshot ของ mockup ที่อนุมัติแล้วมาวงเน้นว่า "action bar ต้องออกมาหน้าตาแบบนี้"

## เทียบกับโค้ดปัจจุบันจริง — ตรวจ `ActionMetric`/`HomeDropCard`/`HomePopCard` ทั้งหมด

`ActionMetric` (`app/lib/core/widgets/action_metric.dart`) เป็น widget กลางที่ทั้ง
`HomeDropCard` (หัวใจ/คอมเมนต์/รีโพสต์/ตา — 4 อัน) และ `HomePopCard` (หัวใจ/คอมเมนต์/ตา — 3 อัน,
ไม่มี ReDrop concept) ใช้ร่วมกัน — เทียบกับ SPEC.md Section 4.9 ทีละแถว:

| SPEC.md 4.9 | โค้ดปัจจุบัน (`home_drop_card.dart` บรรทัด 386-424, `home_pop_card.dart` 241-268) | ตรงกันหรือไม่ |
|---|---|---|
| หัวใจ 17px stroke 1.4, outline→graphite/filled→liked-color, tappable | `iconSize: 17`, `Icons.favorite_border`/`Icons.favorite`, `WynColors.graphite`/liked-color, `onTap: onToggleLike` | ตรง (สีตอนถูกใจ ดูหมายเหตุด้านล่าง) |
| คอมเมนต์ 17px stroke 1.4, graphite เสมอ, tappable ไปหน้าคอมเมนต์ | `iconSize: 17`, `Icons.mode_comment_outlined`, `WynColors.graphite`, `onTap: onTap`/`onTapComment` | ตรง |
| รีโพสต์ 17px stroke 1.4, graphite เสมอ, tappable เปิดตัวเลือก repost | `iconSize: 17`, `Icons.repeat`, `WynColors.graphite`, `onTap: () => _openRedropSheet(...)` | ตรง |
| ตา (เข้าชม) 16px stroke 1.4, **ไม่ tappable**, สี `faint` (อ่อนกว่า 3 อันแรก 1 ระดับ) | `iconSize: 16`, `Icons.visibility_outlined`, `WynColors.faint`, `onTap: null` | ตรง |
| ระยะห่างระหว่าง 4 อัน: `gap-5` (20px) | `SizedBox(width: WynSpacing.space5)` = 20px คั่นทุกคู่ | ตรง |
| ระยะห่างไอคอน↔ตัวเลขในแต่ละอัน: `gap-1.5` (6px) | `ActionMetric` บรรทัด 41: `SizedBox(width: 6)` | ตรง |

**สรุป: โครงสร้าง/ไอคอน/ขนาด/สี/ระยะห่างภายในแถว ตรงกับภาพอ้างอิงและ SPEC.md 4.9 อยู่แล้วครบ
ทุกจุด ไม่มี gap ด้าน visual ของตัวไอคอนเอง** — และ `HomePopCard` ก็ mirror `HomeDropCard`
เป๊ะตามที่คอมเมนต์ในโค้ดตั้งใจไว้ (`action_metric.dart` บรรทัด 9-11: "Shared by HomeDropCard...
and HomePopCard") ไม่มี inconsistency ระหว่าง 2 การ์ด

**ข้อยกเว้นที่ตรวจแล้วไม่ใช่ gap**: สีหัวใจตอนถูกใจใช้ `Colors.red` (Material red) ไม่ใช่
`WynColors.sapphire` ตามที่ SPEC.md 4.9 เขียนไว้เดิม (`"When liked: icon fills solid sapphire"`)
— **นี่คือการตัดสินใจของ Founder ที่ override SPEC.md ไปแล้วจริง** ผ่าน WYN-076 (bug report,
deployed 2026-09-01): Founder ขอให้หัวใจถูกใจเป็นสีแดงโดยตรง ("ใจอยากได้สีแดง") และแก้ครบทุกจุด
ในระบบแล้ว 7 ไฟล์รวมถึง `home_drop_card.dart`/`home_pop_card.dart` — เป็นตัวอย่างเดียวกับที่
Founder เตือนไว้ในงานรอบนี้เรื่องภาพ Cyan เก่า: **ต้องเช็คโค้ดจริง/`DECISIONS.md`/`APPROVALS.md`
ก่อนเชื่อ SPEC.md เดิมเป๊ะ ๆ เสมอ เพราะมี override เฉพาะจุดเกิดขึ้นจริงหลัง SPEC.md เขียนไว้** —
สรุป: **ไม่แก้สีหัวใจกลับเป็น sapphire** คงไว้ตาม WYN-076

## gap ของจริงที่พบ — การจัดวางแนวนอนของแถวไอคอนไม่ตรงกับส่วนอื่นของการ์ดตัวเอง

ตรวจ padding ทุกส่วนของ `HomeDropCard` (และ `HomePopCard` เหมือนกันทุกจุด) เทียบกันเอง:

- Header (avatar+ชื่อ+เวลา): `Padding(horizontal: WynSpacing.space3)` = **12px**
  (`home_drop_card.dart` บรรทัด 254)
- ข้อความโพสต์ (`HashtagText`): `Padding.fromLTRB(12, 8, 12, 0)` = **12px** ซ้าย/ขวา
  (บรรทัด 361)
- `LikedByRow`: `Padding.fromLTRB(12, 10, 12, 0)` = **12px** ซ้าย/ขวา (บรรทัด 372)
- **แถว `ActionMetric` ×4**: `Padding(horizontal: WynSpacing.space1)` = **4px เท่านั้น**
  (บรรทัด 379) — บวกกับ `ActionMetric` เองมี padding ภายในอีก `WynSpacing.space1` = 4px รอบตัว
  มันเอง (`action_metric.dart` บรรทัด 64-68) เฉพาะตัวที่ tappable (หัวใจ/คอมเมนต์/รีโพสต์)

ผลคือ **ไอคอนหัวใจตัวแรกของแถว action bar เยื้องซ้ายจากขอบซ้ายของข้อความโพสต์/`LikedByRow`/
ชื่อผู้โพสต์ที่อยู่เหนือมันประมาณ 4-8px** — มองด้วยตาจะเห็นว่าแถวไอคอนไม่ได้อยู่แนวเดียวกับ
เนื้อหาข้างบนเป๊ะ ๆ ต่างจากภาพอ้างอิงและ `01-home.tsx`'s `Post` component ที่ทุกส่วน (ชื่อ,
เนื้อหา, `LikedByRow`, `ActionBar`) ใช้ padding แนวนอนเดียวกันหมดทั้งการ์ด (`px-6` คงที่ทั้ง
component เดียว ไม่มีจุดไหนขยับ) — **นี่คือ gap จริงที่ต้องแก้**, เป็นเหตุผลที่สมเหตุสมผลว่าทำไม
Founder ถึงวงเน้นแถวนี้เป็นพิเศษ (ความเยื้องแนวนี้สังเกตเห็นได้จริงเวลาเทียบ 2 แถวติดกัน แม้จะ
เล็กน้อย)

---

Screen: `HomeDropCard` และ `HomePopCard` — เฉพาะ `Padding` ที่ห่อแถว `ActionMetric` ทั้งแถวใน
ทั้งสองไฟล์ (Home feed, `HomeFeedScreen`) — `ActionMetric` widget เองไม่ต้องแก้อะไร (ระยะห่าง
ภายในถูกต้องอยู่แล้วตาม SPEC.md 4.9)

Purpose: ยืนยัน (ไม่ใช่คิดใหม่) ว่าไอคอน/สี/ขนาด/ระยะห่างของแถว action bar ตรงกับภาพอ้างอิงของ
Founder อยู่แล้วครบทุกจุด และปิด gap เดียวที่พบจริง — แนวซ้ายของแถวไอคอนต้องตรงกับแนวซ้ายของ
เนื้อหาส่วนอื่นทั้งหมดในการ์ดเดียวกัน

User Flow: ไม่เปลี่ยนแปลง — ผู้ใช้แตะหัวใจ/คอมเมนต์/รีโพสต์เพื่อทำ action เดิมทุกจุด การเปลี่ยน
ครั้งนี้เป็นแค่ตำแหน่งแนวนอนของทั้งแถว ไม่ใช่ behavior

Components:
- `HomeDropCard` บรรทัด 378-379: เปลี่ยน
  `Padding(padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1), ...)` เป็น
  `Padding(padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3), ...)` (4px →
  12px ให้ตรงกับ header/ข้อความ/`LikedByRow` ในไฟล์เดียวกัน)
- `HomePopCard` บรรทัด 232-233: แก้จุดเดียวกันแบบเดียวกันทุกประการ (mirror ของ
  `HomeDropCard`, พบ padding `WynSpacing.space1` เดียวกันที่ต้องแก้)
- `ActionMetric` (`action_metric.dart`): **ไม่ต้องแก้อะไรเลย** — ไอคอน/สี/ขนาด/`gap-1.5`
  ภายในถูกต้องตาม SPEC.md 4.9 อยู่แล้วทุกจุด (ดูตารางเทียบด้านบน)

Interactions: ไม่เปลี่ยน — `onTap` ของหัวใจ/คอมเมนต์/รีโพสต์/parent `InkWell` ของทั้งการ์ดทำงาน
เหมือนเดิมทุกประการ การขยับ padding ไม่กระทบ tap target หรือ hit-test ใด ๆ (ยังคง `InkWell`
ของแต่ละ `ActionMetric` เหมือนเดิม แค่ตำแหน่งขยับตามแถวทั้งหมด)

States: ไม่มี state ใหม่ — สีหัวใจถูกใจ/ยังไม่ถูกใจยังทำงานตามเดิม (`Colors.red`/
`WynColors.graphite` ตาม WYN-076, ไม่แก้)

Responsive Behavior: ไม่กระทบ — เป็นแค่การขยับ padding แนวนอนคงที่ ทำงานเหมือนกันทุกขนาดจอ

Accessibility: ไม่กระทบ — `Semantics.label`/`button: true` ของแต่ละ `ActionMetric` เดิมทั้งหมด
ไม่แตะ

Design Rules:
- ห้ามแก้สีหัวใจถูกใจกลับเป็น `WynColors.sapphire` — คงไว้ตาม WYN-076 (Founder-approved
  override, deployed แล้ว) แม้ SPEC.md 4.9's ข้อความเดิมจะเขียนว่า sapphire ก็ตาม
- ห้ามแก้ไอคอน/ขนาด/สี/ระยะห่างภายในของ `ActionMetric` — ตรงกับภาพอ้างอิง/SPEC.md 4.9 ครบทุกจุด
  อยู่แล้ว มีแค่ padding ห่อรอบแถวทั้งแถวที่ต้องแก้
- padding ใหม่ (`WynSpacing.space3` = 12px) ต้องตรงกับ padding แนวนอนของทุกส่วนอื่นใน
  `HomeDropCard`/`HomePopCard` เดียวกัน (header/ข้อความ/`LikedByRow`) เสมอ — ถ้าในอนาคตมีการแก้
  padding ของส่วนใดส่วนหนึ่งในการ์ด ต้องแก้ทุกส่วนให้ตรงกันเป็นค่าเดียวกันทั้งการ์ด (กติกา
  ความสม่ำเสมอภายในการ์ดเดียวกัน)

Handoff: ส่งต่อ AI Coding —
1. `app/lib/features/home/presentation/widgets/home_drop_card.dart` บรรทัด ~379: เปลี่ยน
   `WynSpacing.space1` → `WynSpacing.space3` ใน `Padding` ที่ห่อ `Row` ของ `ActionMetric` ×4
2. `app/lib/features/home/presentation/widgets/home_pop_card.dart` บรรทัด ~233: จุดเดียวกัน
   ทุกประการ (`WynSpacing.space1` → `WynSpacing.space3`)
3. อัปเดต golden/widget test ที่อาจ assert ตำแหน่ง/ระยะ pixel ของแถวนี้ (ตรวจ
   `app/test/home_feed_screen_test.dart` และเทสของทั้งสอง widget โดยตรงถ้ามี) — ถ้าไม่มีเทสที่
   ผูกกับตำแหน่ง pixel ตรงนี้อยู่แล้ว ไม่ต้องเพิ่มใหม่ (การเปลี่ยนนี้เป็น visual polish เล็กน้อย
   ไม่ใช่ฟีเจอร์ใหม่ที่ต้องมี regression test เฉพาะ)
4. `flutter analyze` + `flutter test` ต้องผ่านครบ ไม่มี regression กับ WYN-023/WYN-034/WYN-076
