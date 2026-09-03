# Design Spec — WYN-106: Home Screen Button System

Owner: AI Design → Founder review → AI Coding (เฉพาะ 2 gap ที่ระบุ)
Ref: Founder ขอผ่านข้อความตรง (2026-09-03): "ช่วยออกแบบ UX UI ปุ่มต่างๆหน่อย ขอโทนสีเดิม ทั้งหมด เริ่มจากหน้าจอ Home"
Preview: Artifact "Home Button System" (ส่งให้ Founder ดูพร้อม token สีจริง)

> **ไม่มีการคิดทิศทาง visual ใหม่ในเอกสารนี้** — WYN มี design system ที่อนุมัติแล้วครบ
> (`app/lib/core/design/wyn_colors.dart`/`wyn_spacing.dart`, rebrand Cyan→Sapphire 2026-08-29,
> `design-reference/SPEC.md`) งานนี้คือการ **รวบรวมปุ่มทุกแบบที่มีอยู่จริงบนหน้าจอ Home ให้เป็น
> ระบบเดียวที่มองเห็นภาพรวมได้** (ปัจจุบันกระจายอยู่คนละไฟล์ ไม่มีเอกสารรวมสักที่) และชี้ 2 จุดที่
> เบี่ยงจากกติกาที่อนุมัติแล้วจริง — ไม่ใช่การเสนอสี/ทรง/ขนาดใหม่แม้แต่จุดเดียว สีทุกค่าในเอกสารนี้
> คัดลอกตรงจาก `wyn_colors.dart` (โค้ดจริง ไม่ใช่ `.wyn/docs/design/ds-001-color-system.md` ที่ล้าสมัย
> ตามบทเรียนที่บันทึกไว้ใน `.wyn/company/DECISIONS.md` 2026-09-02)

---

## Screen

`HomeFeedScreen` (`app/lib/features/home/presentation/home_feed_screen.dart`) และ widget ลูกทั้งหมดที่ประกอบเป็นหน้า Home: `HomeExplainerBanner`, `NewPostsPill`, `SuggestedFollowList`/`FollowActionButton`, `HomeDropCard`/`HomePopCard` + `ActionMetric`

## Purpose

ให้มี "แหล่งความจริงเดียว" ที่มองเห็นปุ่มทุกแบบบนหน้า Home พร้อมกันในหน้าเดียว เพื่อ (1) ยืนยันว่า
ทุกปุ่มใช้ token สีเดิมชุดเดียวกันจริง ไม่มีปุ่มไหนหลุด (2) เปิดช่องให้เห็น gap ที่ไม่เคยถูกจับมาก่อน
เพราะแต่ละปุ่มอยู่คนละไฟล์คนละงาน (3) เป็นฐานอ้างอิงเดียวกันสำหรับงานปุ่มของหน้าจอถัดไป (Founder ระบุ
"เริ่มจากหน้าจอ Home" แปลว่ามีจอถัดไปตามมา — โครงเอกสารนี้ (1 หน้าจอ = 1 ตารางรวมปุ่ม) ใช้ซ้ำได้)

## User Flow

ไม่มี user flow ใหม่ — ทุกปุ่มทำงานเหมือนเดิมทุกประการ (ดู Interactions ของแต่ละปุ่มด้านล่าง อ้างอิง
ของเดิม 100%) เอกสารนี้เป็นชั้นเอกสาร/การจัดหมวดหมู่ ไม่ใช่การเปลี่ยน behavior

## Components — ปุ่มทั้งหมดบนหน้า Home (6 ประเภท)

### 1. Primary Pill — `NewPostsPill`
- พื้น `sapphire` เต็ม + ตัวอักษร/ไอคอนสี `paper`, ทรง pill (`radiusFull`), shadow `sapphire @ 30%`
- ใช้จุดเดียวบนหน้านี้: ปุ่ม "มีโพสต์ใหม่" ใต้แถบแท็บ — สงวนไว้สำหรับ action สำคัญที่สุดของจอเดียว
  ไม่ reuse ทรงนี้กับปุ่มอื่นที่ความสำคัญรองลงมา

### 2. Secondary Outline (compact) — `FollowActionButton(compact: true)`
- ใช้ใน `SuggestedFollowList` (empty state เมื่อบัญชียังไม่ได้ follow ใคร)
- 3 สถานะ: ยังไม่ติดตาม (`OutlinedButton`, ขอบ+ตัวอักษร `sapphire`) / ส่งคำขอแล้ว (ข้อความเปลี่ยน, รอ
  `_isActionInFlight`) / กำลังติดตาม (ข้อความเปลี่ยน, ยังเป็น `OutlinedButton` ทรงเดิม)
- Widget เดียวใช้ร่วมกับทั้งแอป (Discovery, Profile) — หน้า Home ไม่ได้สร้างปุ่ม Follow ของตัวเอง

### 3. Icon Button (header) — เมนู + แชท
- สี `ink` คงที่ 100% ของเวลา ไม่มี active/selected state (เพราะไม่ใช่ตัวบอกโหมดของจอ เป็นทางเข้า
  ไปหน้าอื่น) — ไอคอนแชทมี badge ตัวเลขพื้น `sapphire` เมื่อมีข้อความยังไม่อ่าน
- ใช้ Material `IconButton` เปล่า → touch target 48×48 ผ่านเกณฑ์ขั้นต่ำ (44px) อยู่แล้วโดยไม่ต้องแก้

### 4. Text Tab — แท็บกรองฟีด (3 แท็บ)
- ไม่มีกรอบ/พื้นหลัง (WYN-073 ยกเลิก `SegmentedButton` แบบมีกรอบไปแล้ว) แยกสถานะด้วย 3 ชั้น: น้ำหนัก
  ตัวอักษร (600 vs 400) + สี (`ink` vs `faint`) + เส้นใต้ `sapphire` หนา 2px เฉพาะแท็บ active
- Design Rule ที่ยังคงอยู่: ห้ามใส่กรอบ/พื้นหลังให้แท็บ active กลับไปเป็นทรง chip

### 5. Icon+Count — `ActionMetric` (ถูกใจ/คอมเมนต์/รีโพสต์/เข้าชม)
- ไอคอน 17px (เข้าชม 16px) stroke 1.4, สี 3 ระดับ: `iconIdle` (graphite, ค่าเริ่มต้น) /
  `iconActive` = `sapphire` (เฉพาะรีโพสต์ตอนเคยรีโพสต์แล้ว — WYN-089) / `iconLikeActive` = แดง
  Material คงที่ (ตัดสินใจ Founder แยกต่างหาก "ใจอยากได้สีแดง" — ไม่ใช่ sapphire)
- Touch target 44px สูง แม้ไอคอน+ตัวเลขที่เห็นจะเล็กกว่านั้นมาก (padding โปร่งใสรอบตัว) — **จุดนี้แก้
  ครบแล้วก่อนหน้านี้** เป็นตัวอย่างที่ถูกต้องของ "ขนาดที่เห็น ≠ ขนาดพื้นที่กด" ที่ปุ่มอื่นควรทำตาม

### 6. Dismiss Icon — ปุ่ม X ปิด `HomeExplainerBanner`
- ไอคอน 15px stroke 1.8 สี `graphite` — สี/ไอคอน **ถูกต้องตามระบบ**
- **พื้นที่กดจริงมีปัญหา** — ดู "gap ที่พบ" ด้านล่าง

---

## Interactions

ไม่เปลี่ยนของทุกปุ่ม — คงพฤติกรรมเดิมทั้งหมด (ดูรายละเอียดต่อปุ่มในเอกสารต้นทางของแต่ละงาน: WYN-089,
WYN-091, WYN-096-alignment, WYN-073, WYN-039)

## States

สรุปรวมจากทุกปุ่มด้านบน — ไม่มีปุ่มไหนสื่อสารสถานะด้วยสีอย่างเดียว (ทุกปุ่มมี `Semantics.label` ที่พูด
สถานะเป็นคำเสมอ ตรงกติกา DS-001 ข้อ 5) รายละเอียด default/pressed/disabled ของแต่ละปุ่มอยู่ใน Artifact
preview ที่แนบ

## Responsive Behavior

ไม่กระทบ — ทุกปุ่มใช้หน่วย px คงที่ตาม `WynSpacing`/spec เดิม ทำงานเหมือนกันทุกขนาดจอมือถือ (ตรงกับที่
DS-008 สรุปไว้แล้วว่า WYN เป็น mobile-first ไม่มี breakpoint tablet/desktop)

## Accessibility

- ยืนยันครบ 6 ประเภท: มี `Semantics(label:..., button:true)` ทุกปุ่มที่ tappable, ปุ่มที่ไม่ tappable
  (เข้าชม) ไม่ประกาศ `button: true`
- **พบ 1 จุดที่ต่ำกว่าเกณฑ์ touch target ของระบบเอง** (≥44×44, DS-001 §6 / ยืนยันซ้ำใน DS-008 §1):
  ปุ่ม X ปิด `HomeExplainerBanner` — `Padding(all: 2)` รอบไอคอน 15px = พื้นที่กดจริง **~19×19px**
  (ต่ำกว่าเกณฑ์ 57%) DS-008 เคยไล่แก้จุดแบบนี้ไปแล้ว 4 จุดใน `app/` แต่ widget นี้ไม่อยู่ในรายการตอนนั้น
  (audit ทำก่อน/คนละรอบกับตอนที่ไฟล์นี้เขียน) — เป็น gap จริงที่หลุดจาก audit เดิม ไม่ใช่ข้อยกเว้นที่
  ตั้งใจแบบ Pop

## Design Rules

1. **ห้ามเพิ่มสี/ทรงปุ่มใหม่ที่ไม่อยู่ใน 6 ประเภทข้างต้น** โดยไม่ทวนกับ Founder ก่อน — ปุ่มใหม่ในอนาคต
   ต้อง map เข้าประเภทใดประเภทหนึ่งใน 6 แบบนี้เสมอ (Primary Pill / Secondary Outline / Icon /
   Text Tab / Icon+Count / Dismiss Icon) ไม่สร้างประเภทที่ 7 พร่ำเพรื่อ
2. ทรงปุ่ม 3 ระดับความสำคัญต้องคงต่างกันชัดเจน: **Pill พื้นทึบ sapphire** (สำคัญที่สุด, 1 จุด/จอ) >
   **Outline sapphire** (action รอง เช่น follow) > **Icon เปล่า** (นำทาง/metric ไม่ใช่ CTA)
3. ทุกปุ่มที่ tappable ต้องมี touch target ≥44×44 แม้ไอคอนที่เห็นจะเล็กกว่านั้น (มาตรฐานเดียวกับที่
   `ActionMetric` ทำอยู่แล้ว — ใช้เป็น reference pattern)

## Handoff

**ส่งให้ Founder ตรวจ Artifact ก่อน** — ยังไม่ส่ง AI Coding จนกว่า Founder ยืนยัน เพราะมี 1 gap จริงที่
ต้องแก้โค้ด (ข้ออื่นเป็นการยืนยัน ไม่มีอะไรต้องแก้):

1. **ต้องแก้** — `home_explainer_banner.dart` บรรทัด ~108-115: ขยายพื้นที่กด `InkWell` ของปุ่ม X จาก
   `Padding(all: 2)` เป็น pattern เดียวกับ `action_metric.dart` (`ConstrainedBox` กำหนด
   `minWidth`/`minHeight: WynSpacing.touchTargetMin`) — ไอคอน 15px สี `graphite` เดิมทุกประการ
   ไม่กระทบภาพที่เห็น เพิ่มแค่พื้นที่กดโปร่งใสรอบตัวมัน
2. **ไม่ต้องแก้ทันที** — ข้อสังเกตเพิ่มเติมที่ไม่ใช่ gap เร่งด่วน: ไอคอน "⋯" (more options) ใน
   `home_drop_card.dart` ใช้ `IconButton(icon: Icon(Icons.more_vert))` โดยไม่ระบุ `size`/`color`
   ชัดเจน (พึ่ง default ของ Flutter) ขณะที่ `design-reference/SPEC.md` §4.6 ระบุไว้ว่าควรเป็น 16px
   สี `faint` — touch target ผ่านเกณฑ์อยู่แล้ว (IconButton default 48×48) จึงไม่ใช่ปัญหาด้าน
   accessibility เป็นแค่ความคลาดเคลื่อนเล็กน้อยจาก spec เอกสาร ที่ไม่กระทบการใช้งานจริง — บันทึกไว้เป็น
   known note รอ Founder ตัดสินใจว่าคุ้มที่จะแก้หรือปล่อยไว้ (ความเสี่ยงต่ำ ไม่กระทบ token สี)
3. เมื่อ Founder อนุมัติ handoff ข้อ 1 แล้ว ส่งต่อ AI Coding: แก้ไฟล์เดียว 1 จุด, เพิ่ม widget test
   ยืนยันขนาด hit-test ≥44px (มิเรอร์ pattern เทสที่ DS-008 เพิ่มให้จุดอื่นไปแล้ว), `flutter analyze`
   + `flutter test` ต้องผ่านครบไม่มี regression
