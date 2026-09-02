# Design Spec — WYN-091: การ์ดโพสต์ข้อความล้วน (restyle) + Badge "มีโพสต์ใหม่"

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-091.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/home/presentation/widgets/home_drop_card.dart` (caption block), `app/lib/features/home/presentation/widgets/new_posts_pill.dart`, `app/lib/features/home/presentation/home_feed_screen.dart` (`_newPostCount`/`showNewPostsPill`)
Pattern ที่มีอยู่แล้ว: `.wyn/tasks/review/WYN-086-caption-above-image.md` (caption ย้ายมาอยู่เหนือรูป/Poll แล้ว — งานนี้ไม่แตะลำดับนั้นซ้ำ)

> **ส่วนการ์ดข้อความล้วน**: Founder แนบภาพอ้างอิงมากับ PDF ("เรียบๆหรู เหมือนในรูป") — **session นี้ไม่มีไฟล์ภาพนั้น** ออกแบบจากคำพูด + design system ที่มีอยู่แล้วเท่านั้น เป็น **draft รอ Founder ยืนยันเทียบกับภาพต้นฉบับ**
> **ส่วน badge "มีโพสต์ใหม่"**: เป็นคำสั่งข้อความล้วน ไม่ต้องพึ่งภาพ — **พร้อมขึ้นโค้ดทันที**

---

## Part 1 — Badge "มีโพสต์ใหม่ N โพสต์" → "มีโพสต์ใหม่" (พร้อมขึ้นโค้ด)

### สิ่งที่ตรวจโค้ดจริงแล้วพบ — ครึ่งหนึ่งของ requirement นี้ทำอยู่แล้ว

`home_feed_screen.dart` บรรทัด 589-590:
```dart
final showNewPostsPill =
    _feedMode != _HomeFeedMode.fromYourClubs && _newPostCount > 0;
```
**Pill ถูกซ่อนอยู่แล้วเมื่อ `_newPostCount == 0`** — ส่วน "ขึ้นเฉพาะตอนมีโพสต์ใหม่จริง" ของ Acceptance Criteria **ผ่านอยู่แล้วในโค้ดปัจจุบัน ไม่ต้องแก้อะไรเพิ่ม** สิ่งที่ยังไม่ตรงมีแค่ **ข้อความ** — `new_posts_pill.dart` ยังโชว์ตัวเลข ("มีโพสต์ใหม่ $count โพสต์") ที่ Founder บอกให้เอาออก

Screen: `NewPostsPill` widget (ปักหมุดใต้ feed-mode toggle, เหนือ feed body)

Purpose: ตัดตัวเลขออกจาก label ตามคำขอ Founder โดยตรง ("เปลี่ยนเป็น 'มีโพสต์ใหม่'")

Components: แก้ 2 จุดใน `new_posts_pill.dart`:
- Semantics label: `'มีโพสต์ใหม่ $count โพสต์ กดเพื่อโหลด'` → `'มีโพสต์ใหม่ กดเพื่อโหลด'`
- Visible `Text`: `'มีโพสต์ใหม่ $count โพสต์'` → `'มีโพสต์ใหม่'`
- **`count`/`onTap` parameter คงไว้ทั้งคู่** — `onTap` ยังต้องมีอยู่ (behavior เดิม กดแล้วโหลดโพสต์ใหม่) `count` ยังใช้ประโยชน์ได้ภายใน widget แม้ไม่แสดงเป็นตัวเลขแล้ว (เช่นไว้ debug/log หรือเผื่ออนาคต) — ไม่ต้องลบ parameter ออกจาก constructor เพียงแค่เลิกอ้างอิงมันในข้อความที่แสดง

Interactions: ไม่เปลี่ยน — กด pill ยังโหลดโพสต์ใหม่เหมือนเดิมทุกประการ

States: ไม่มี state ใหม่ — เงื่อนไขการแสดง/ซ่อน pill (`_newPostCount > 0`) **ไม่ต้องแก้** เพราะถูกต้องอยู่แล้วตามที่ตรวจพบข้างบน

Responsive Behavior: ความกว้าง pill สั้นลงเล็กน้อยเพราะไม่มีตัวเลข/คำว่า "โพสต์" ต่อท้าย — ไม่มีความเสี่ยง overflow (สั้นลงกว่าเดิมเสมอ)

Accessibility: Semantics label ยังคงบอกว่ากดเพื่อทำอะไร ("กดเพื่อโหลด") — ไม่สูญเสียข้อมูลสำคัญจากการตัดตัวเลขออก (ตัวเลขจำนวนโพสต์ใหม่ไม่ใช่ข้อมูลจำเป็นต่อการตัดสินใจกด)

Design Rules: ไม่เปลี่ยนสี/รูปทรง/ตำแหน่ง pill (`WynColors.sapphire`, stadium shape, ไอคอนลูกศรขึ้น) — งานนี้แก้แค่ข้อความ

Handoff: AI Coding — แก้ `app/lib/features/home/presentation/widgets/new_posts_pill.dart` (2 จุดข้างบน) — อัปเดต widget test ที่ assert ข้อความเดิม (`find.text('มีโพสต์ใหม่ ... โพสต์')` ถ้ามี) ให้ตรงข้อความใหม่ — รัน `flutter analyze`/`flutter test`

---

## Part 2 — การ์ดโพสต์ข้อความล้วน "เรียบ หรู" (draft — รอ Founder ยืนยันกับภาพต้นฉบับ)

Screen: `HomeDropCard` เมื่อ `!item.isPoll && item.imageUrl == null` (โพสต์ข้อความล้วน ไม่มีรูป ไม่ใช่ Poll)

Purpose: ทำให้โพสต์ข้อความล้วนดู "เรียบ หรู" ตามที่ Founder ขอ โดยไม่มีภาพอ้างอิงให้ดูจริง

### สถานะปัจจุบันของโค้ด (จุดเริ่มต้นก่อนแก้)

```dart
if (item.caption != null && item.caption!.isNotEmpty)
  Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: !item.isPoll && item.imageUrl == null
        ? DoubleTapLike(onLike: onToggleLike, alreadyLiked: item.likedByMe, child: HashtagText(item.caption!))
        : HashtagText(item.caption!),
  ),
```
ปัจจุบันโพสต์ข้อความล้วนกับโพสต์ที่มีรูป **ใช้ padding เดียวกันเป๊ะ** (`fromLTRB(12, 8, 12, 8)`) และ typography เดียวกัน (`bodyLarge`, ผ่าน `HashtagText`) — ไม่มีการแยกสไตล์ระหว่าง 2 ประเภทนี้เลยตอนนี้

### ทิศทางที่เสนอ (ไม่มีภาพอ้างอิง — อิงคำพูด Founder + design system ที่มีอยู่)

หลักคิด: "เรียบ หรู" ในภาษาที่ design system นี้ใช้มาตลอด (`wyn-071`, `wyn-073`) แปลว่า **whitespace เยอะ, เส้นน้อย, สีน้อย** — ไม่ใช่การเพิ่มกรอบ/เงา/สีตกแต่ง (design-principles.md ห้าม Liquid Glass, และ `DECISIONS.md` 2026-08-29 ล็อก `WynColors.canvas` ไว้เป็น "กรอบมือถือใน mockup เท่านั้น ไม่ใช้ในแอปจริง" — **ห้ามใช้ `canvas` เป็นพื้นหลังการ์ดข้อความ** ตามที่ตัดสินใจไว้แล้ว) ความหรูจึงมาจาก "การให้พื้นที่หายใจ" ไม่ใช่การเพิ่มองค์ประกอบใหม่:

Components:
- **Padding เพิ่มขึ้นเฉพาะกรณีข้อความล้วน** (แยก branch จากกรณีมีรูป/Poll ที่ยังใช้ padding เดิม): จาก `EdgeInsets.fromLTRB(12, 8, 12, 8)` เป็น `EdgeInsets.fromLTRB(WynSpacing.space4, WynSpacing.space3, WynSpacing.space4, WynSpacing.space4)` (16/12/16/16) — ใช้ token ที่มีอยู่แล้วในระบบ ไม่เพิ่ม spacing ใหม่ แค่เลือกค่าที่ให้ลมหายใจมากขึ้นสำหรับกรณีที่ไม่มีรูปมาช่วย "ตัด" สายตา
- **เส้นคั่นบางๆ ใต้ข้อความ** (`Container(height: 1, color: WynColors.hairline)`) ก่อนถึงแถวปุ่มปฏิสัมพันธ์ — เฉพาะกรณีข้อความล้วนเท่านั้น (โพสต์มีรูปไม่ต้องมี เพราะรูปเองทำหน้าที่ "ปิดท้าย" เนื้อหาให้อยู่แล้วทางสายตา) หลักการเดียวกับเส้น hairline ที่ `DropDetailScreen`'s Focused Action Bar ใช้อยู่แล้ว — reuse token สี ไม่ประดิษฐ์ใหม่
- **Typography ไม่เปลี่ยน** — ยังเป็น `bodyLarge` (16px/400, line-height 1.5) ตาม DS-001 Section 5 เดิม (ไม่เพิ่มระดับตัวอักษรใหม่ ตามกติกา "ระดับตัวอักษรในหน้าเดียวไม่เกิน 4 ระดับ" — ความหรูมาจาก spacing ไม่ใช่ font-size ที่ใหญ่ขึ้น)

Interactions: ไม่เปลี่ยน — `DoubleTapLike` ยังห่อ caption เหมือนเดิม (double-tap ยังไลค์ได้)

States: ไม่มี state ใหม่

Responsive Behavior: padding ที่เพิ่มขึ้น (16px ซ้ายขวาแทน 12px) ต้องทดสอบว่าข้อความยาวยังไม่ overflow บนจอ 360px — เพิ่มความเสี่ยงเล็กน้อยเพราะพื้นที่ข้อความแคบลง 8px รวม (แต่ `HashtagText` มี wrap อยู่แล้วโดยธรรมชาติ ไม่ใช่ single-line)

Accessibility: ไม่เปลี่ยน — เส้นคั่นเป็น decorative hairline (ไม่ต้องมี Semantics label ตามที่กติกา WCAG ยกเว้น decoration ไว้แล้วใน DS-001)

Design Rules:
- **ห้ามใช้ `WynColors.canvas` เป็นพื้นหลังการ์ด** (ล็อกไว้แล้วว่าใช้ได้แค่ในกรอบ mockup เท่านั้น)
- **ห้ามเพิ่มกรอบ/เงา/มุมโค้งรอบข้อความ** — คงพื้นผิวเดียวกับ `paper` ทั่วทั้งฟีด (ไม่ใช่ "การ์ดลอย" แบบมีขอบเขตชัด) ตรงกับที่ระบบยึดมาตลอดตั้งแต่ `wyn-071`/`wyn-073` ("เอาได้แค่ความเรียบ ไม่เอาโครงหน้าจอ")
- นี่คือ**ข้อเสนอเริ่มต้นเท่านั้น** — ถ้าภาพอ้างอิงจริงของ Founder แสดงทิศทางอื่น (เช่น พื้นหลังสีต่าง, จัดกึ่งกลาง, ฟอนต์ใหญ่ขึ้นแบบ pull-quote) ต้องปรับ spec นี้ใหม่หลัง Founder ยืนยัน ไม่ใช่ยึดตามนี้ตายตัว

Handoff: **อย่าเพิ่งขึ้นโค้ด Part 2** — ส่ง popup ถาม Founder ก่อนว่า draft นี้ตรงกับภาพที่แนบมากับ PDF หรือไม่ (ตัวเลือก: "ตรง ไปต่อได้" / "ไม่ตรง ขอแนบภาพ/อธิบายเพิ่ม") ถ้ายืนยันแล้วส่ง AI Coding แก้ `home_drop_card.dart` (แยก branch padding/เส้นคั่นสำหรับกรณีข้อความล้วนตามที่ระบุ) เขียน widget test ยืนยัน padding/เส้นคั่นใหม่เฉพาะกรณีไม่มีรูป

## สรุปสถานะ

- **Part 1 (badge)**: พร้อมขึ้นโค้ดทันที
- **Part 2 (การ์ดข้อความล้วน)**: draft รอ Founder ยืนยันภาพอ้างอิง — ยังไม่ส่ง AI Coding
