# Design Spec — WYN-140: Home Feed Premium Polish

Owner: AI Design → Founder review → AI Coding
Ref: Founder brief (2026-09-08, ข้อความตรง "ปรับปรุง UX/UI ของหน้า WYNOS Home Feed ให้มีคุณภาพระดับ
Production และ Premium Social Media"), `.wyn/docs/design/wyn-106-home-button-system.md` (button taxonomy,
อนุมัติแล้ว), `.wyn/docs/design/wyn-107-home-feed-two-column-layout.md` (โครงการ์ดปัจจุบัน, อนุมัติแล้ว),
`.wyn/docs/design/ds-010-interaction-feedback.md` (haptic/motion system, implement แล้ว)

> **ไม่มีการคิดทิศทาง visual ใหม่ในเอกสารนี้** — ทุกสี/spacing/type scale อ้างจากโค้ดจริง
> (`app/lib/core/design/wyn_colors.dart`, `wyn_spacing.dart`, `wyn_typography.dart`) งานนี้คือการ
> **ปรับรายละเอียด (spacing/typography/interaction/animation) โดยล็อกโครงสร้างโพสต์เดิมของ WYN-107
> ไว้ทั้งหมด** ตามที่ Founder สั่งชัดเจน ("ห้ามเปลี่ยน Post Layout เดิม")

## Scope Guardrails (จากบรีฟ Founder — ยึดตามนี้ทั้งหมด)

- ห้าม redesign ทั้งหน้า, ห้ามเปลี่ยนลำดับ avatar → ชื่อ/badge/เวลา → เนื้อหา → hashtag → รูป, ห้ามเปลี่ยนเป็น
  Card/Floating Card/Instagram-style/Facebook-boxed — Feed ต้องดูต่อเนื่องแบบ Threads/X เหมือนเดิม
- ใช้ spacing/whitespace เพิ่มความพรีเมียม แทนกล่อง/เส้นขอบ
- ใช้ Design System เดิม (สี/token) ทั้งหมด — งานนี้ปรับ "รายละเอียด" ไม่ใช่ "ทิศทาง"

## 2 จุดที่บรีฟอ้างข้อมูลเก่ากว่าโค้ดจริง — แจ้ง Founder ก่อนเริ่ม ไม่เดาเอง

1. **สี**: บรีฟระบุ Primary `#00C8FF` (Cyan), Ink `#0A0A0A` — นี่คือค่า **เก่าก่อน 2026-08-29** (ตอนนั้น
   DS-001 ยังเป็น Cyan) โค้ดจริงตอนนี้คือ **Sapphire `#1B3A6B`**, Ink `#12120F` (rebrand 2026-08-29,
   `wyn_colors.dart`) — ซึ่ง Founder เพิ่งยืนยันอีกครั้งเมื่อครู่นี้เองในเซสชันนี้ ("ชอบแบบเดิม" หลังดู
   ทางเลือกสีอื่น) **เอกสารนี้ใช้ Sapphire ของจริงในโค้ด ไม่ใช้ Cyan ตามบรีฟ** — ถ้า Founder ตั้งใจจะกลับไป
   Cyan จริงๆ ต้องบอกแยกต่างหาก เพราะเป็นการเปลี่ยนทิศทางสีทั้งระบบ ไม่ใช่แค่หน้า Home เดียว (`Success
   #15803D`/`Danger #DC2626` ที่บรีฟระบุ ตรงกับโค้ดจริงอยู่แล้ว ไม่มีปัญหา)
2. **Hashtag**: ภาพ ASCII ในบรีฟวาด Hashtag เป็นบรรทัดแยกระหว่างเนื้อหากับรูป แต่โค้ดจริง (`HashtagText`)
   render `#hashtag` เป็น **span สีในเนื้อหาเดียวกัน** ไม่ใช่บรรทัดแยก — เอกสารนี้ยึดพฤติกรรมปัจจุบัน (inline)
   เพราะ (ก) ไม่ขัดกับกติกา "ลำดับ Text → Hashtag → Image" จริงๆ (hashtag ต่อท้ายข้อความอยู่แล้วก่อนถึงรูป)
   (ข) การแยกเป็นบรรทัดต่างหากคือการเปลี่ยนโครงสร้างจริง ขัดกับ "ห้ามเปลี่ยน Post Layout" ของบรีฟเอง — ถ้า
   Founder ต้องการ hashtag แยกบรรทัดจริงๆ ต้องยืนยันแยก เพราะเป็นคนละงานจาก "ปรับรายละเอียด"

## Phased Handoff (สแกนความเสี่ยงของแต่ละหัวข้อก่อนส่ง AI Coding)

| Phase | เนื้อหา | เหตุผลที่แยก |
|---|---|---|
| **Phase 1 — ปลอดภัย ทำได้ทันที** | Screen 1-2, 4 (ยกเว้น swipe), 5 (ยกเว้น custom pull animation), 6, 7 (ยกเว้น custom pull), 8 checklist | ปรับ token/ตัวเลขที่มีอยู่แล้ว ไม่เพิ่ม gesture/state ใหม่ ความเสี่ยง regression ต่ำ |
| **Phase 2 — เพิ่ม scope จริง ต้องอนุมัติแยก** | Feed tab **swipe gesture** (Screen 3), Pull-to-refresh **custom brand animation** (Screen 7) | ทั้งสองไม่ใช่ "ปรับรายละเอียด" แต่เป็น **ฟีเจอร์ใหม่**: swipe ต้องคุม 3 pagination state พร้อมกันใน PageView (ตอนนี้เป็น tap-to-switch ธรรมดา), custom pull animation ต้องเขียน `RefreshIndicator` ทดแทนของ Flutter เอง — ทั้งคู่เพิ่ม surface ที่ต้องเทสและมีความเสี่ยง regression สูงกว่า Phase 1 มาก ควรทำแยกหลัง Phase 1 เสถียรแล้ว |

ด้านล่างนี้คือสเปกเต็มของทั้ง 8 Screen block ตาม output format ของ AI Design — Phase 2 items ถูกทำเครื่องหมาย
`[PHASE 2]` ไว้ในเนื้อหาเพื่อให้ AI Coding แยก PR ได้ชัดเจน

---

## Screen 1 — Post Card: Typography Hierarchy & Spacing Rhythm

Purpose: ให้การ์ดโพสต์ (`HomeDropCard`/`HomePopCard`) มี hierarchy ที่ชัดเจนขึ้นและจังหวะ spacing ที่
สม่ำเสมอทั้งการ์ด โดยไม่ย้าย element ใดเลยจากตำแหน่งเดิมของ WYN-107

User Flow: ไม่มี flow ใหม่ — นี่คือการปรับค่าตัวเลข ไม่ใช่พฤติกรรม

Components (ของเดิมทั้งหมด แค่ตรวจ/ปรับค่า):
- **Username** (`titleSmall`, 15/600) — เด่นสุดของ header row อยู่แล้ว ไม่ต้องแก้
- **Verified badge** (`VerifiedBadge`) — ต้องอยู่แนวเดียวกับ baseline ของชื่อ ไม่ใหญ่กว่าความสูงตัวอักษร —
  **ตรวจโค้ดจริงก่อนแก้**: ปัจจุบันวางด้วย `Row` ธรรมดาข้าง `Text(item.authorNameOrUsername)` แล้ว
  (ไม่ใช่ `Stack`/`Positioned`) — ถ้าวัดจริงแล้วขนาด/แนวไม่ตรง ค่อยปรับ ไม่ใช่ redesign
- **Timestamp** (`bodySmall`, 13/400, สี `colorScheme.outline` = `#8B929C`) — รองจาก username อยู่แล้วตาม
  token สีที่ต่างชั้นชัดเจน ไม่ต้องแก้สี แค่ยืนยัน spacing ด้านล่าง (ดู Spacing Table)
- **Post Content** (`bodyLarge`, 16/400, line-height 1.5) — ตรงตาม "ขนาดอ่านง่าย, line-height โปร่ง"
  ของบรีฟอยู่แล้ว (2026-08-30 typography pass) — ไม่ต้องแก้ตัวเลข
- **Hashtag** (inline span ใน `HashtagText`, สี `colorScheme.primary` = sapphire, weight 600) — เข้มกว่า
  เนื้อหาปกติแล้วเล็กน้อยตามที่บรีฟขอ ("มีน้ำหนักมากกว่า Text ปกติเล็กน้อย") — ไม่ต้องแก้

Interactions: ไม่เปลี่ยน — tap หัวใจ/ชื่อ/รูปทำงานเหมือนเดิมทุกจุด

States: ไม่เปลี่ยน (ReDrop/Quote header row, Poll, ข้อความอย่างเดียว, มีรูป — ทุก state เดิมของ WYN-107)

Responsive Behavior: ทดสอบ 320/375/390/430px เหมือนที่ WYN-107/Beta4 §14 เคยทำ — ตัวเลข spacing
ด้านล่างเป็นค่าคงที่ ไม่ผูกกับความกว้างจอ (WYNOS mobile-first ไม่มี breakpoint)

Accessibility: ไม่เปลี่ยน Semantics ที่มีอยู่แล้ว — ตรวจว่า spacing ใหม่ไม่ทำให้ touch target ของปุ่ม "..."
(44×44 เดิม) เล็กลง

Design Rules — **Spacing Table (ยึดสเกล 4/8/12/16/20/24/32 ของบรีฟ ตรงกับ `WynSpacing` เดิมเป๊ะ)**:

| คู่ Element | ปัจจุบันในโค้ด | Spec (บรีฟ) | ผล |
|---|---|---|---|
| Avatar ↔ ชื่อ (คอลัมน์ซ้าย-ขวา) | `homeCardAvatarGap` = 14px | 12-16px | **ตรงเกณฑ์อยู่แล้ว ไม่ต้องแก้** |
| ชื่อ ↔ เวลา (แนวตั้ง) | 0 (สองบรรทัดชิดกันใน `Column`) | 4px (micro) | **เพิ่ม `SizedBox(height: WynSpacing.space1)` ระหว่างสองบรรทัด** — ตอนนี้ไม่มีช่องว่างเลย อ่านเป็นก้อนเดียวกันเกินไป |
| เวลา ↔ เนื้อหาโพสต์ | `WynSpacing.space2` (8px) บน caption padding | 8-12px | **ตรงเกณฑ์อยู่แล้ว ไม่ต้องแก้** |
| เนื้อหา ↔ รูป/Poll | `WynSpacing.space2` (8px, จาก caption padding bottom) | 12-16px | **เพิ่มเป็น `WynSpacing.space3` (12px)** — ให้รูปรู้สึกเป็น "ส่วนต่อ" ที่แยกจังหวะจากข้อความชัดขึ้นเล็กน้อย ตามที่บรีฟขอ ("รูปภาพเป็นส่วนต่อจากเนื้อหา") |
| รูป ↔ Action Bar | `WynSpacing.space2 + 2` (10px, จาก liked-by row) หรือตรงจากรูปถ้าไม่มี liked-by | 12-16px | **เพิ่มเป็น `WynSpacing.space3` (12px) คงที่** ไม่ว่าจะมี liked-by row หรือไม่ |
| ระหว่างโพสต์ (โพสต์ต่อโพสต์) | `WynSpacing.space4` (16px) บน+ล่าง = 32px รวม ไม่มีเส้นคั่น | **คงเดิม** | Founder เคยดูตัวเลือกเส้นคั่น hairline แล้วตอบ "ไม่ต่างเลย" (บันทึกไว้ใน DECISIONS.md 2026-09-07) — **ไม่แตะจุดนี้อีก** |

Handoff: AI Coding — แก้ 2 จุดใน `home_drop_card.dart`/`home_pop_card.dart`: (1) เพิ่ม 4px ระหว่างชื่อกับเวลา
(2) เปลี่ยน caption-bottom-padding และ media-bottom-padding จาก `space2` เป็น `space3` — ไม่แตะ token ใหม่
ใดๆ ทั้งสองจุดมีอยู่ใน `WynSpacing` แล้ว

---

## Screen 2 — Header: Static Top Bar (ไม่ต้องใช้ Blur)

Purpose: ยืนยันว่า Header ปัจจุบันตรงเจตนาของบรีฟอยู่แล้ว ("Clean, Premium, ไม่ใหญ่เกินไป, ห้าม Glass
หนักเกินไป") — และอธิบายว่าทำไม "Sticky + Blur ตอน scroll" ตามบรีฟ **ไม่จำเป็นเลยกับโครงสร้างปัจจุบัน**

User Flow: ไม่มี flow ใหม่

Components: `_buildHeader()` เดิม — hamburger (☰) → wordmark WYNOS → ปุ่มแชท (มี badge แดงเมื่อมีข้อความ
ยังไม่อ่าน) ตรงกับ `[Menu] [WYNOS Logo + WYNOS] [Message]` ของบรีฟเป๊ะ ไม่ต้องแก้โครงสร้าง

Interactions: ไม่เปลี่ยน

States: ไม่เปลี่ยน (badge แชทมี/ไม่มีตัวเลข)

Responsive Behavior: ไม่เปลี่ยน

Accessibility: ไม่เปลี่ยน

Design Rules — **ทำไมไม่ต้องมี blur**: Header ปัจจุบันอยู่ใน `Column` **นอก** `CustomScrollView` (ดู
`home_feed_screen.dart` บรรทัด ~800-804) ไม่ใช่ `SliverAppBar`/overlay ลอยทับเนื้อหา — แปลว่ามันไม่เคยมี
เนื้อหาเลื่อนผ่านด้านหลังให้ต้อง blur เลยตั้งแต่แรก (ต่างจาก IG/X ที่ header ลอยทับฟีด) กลไกนี้**ตรงกับกติกา
ของบรีฟเองพอดี** ("ห้ามใช้ Glass Effect หนักเกินไป ต้องดูเป็น Native Social App") — การเพิ่ม blur จะเป็นการ
เพิ่มความซับซ้อนโดยไม่จำเป็นและเสี่ยงขัดกติกา "ไม่ Overdesign" ของบรีฟเองด้วย **แนะนำไม่ทำ**

ส่วนที่ยังไม่มีคือ Feed-mode toggle ด้านล่าง header ซึ่ง**ปักหมุด (pinned) อยู่แล้ว** ผ่าน
`SliverPersistentHeader(pinned: true)` — ตรงกับ "Sticky Filter Bar" ที่บรีฟขอแล้วเช่นกัน (ดู Screen 3)

Handoff: **ไม่มีโค้ดต้องแก้ในหัวข้อนี้** — บันทึกไว้เป็นการยืนยัน ป้องกันไม่ให้ AI Coding เพิ่ม
`BackdropFilter`/blur ที่ไม่จำเป็นตามตัวอักษรของบรีฟโดยไม่เห็นบริบทโค้ดจริง

---

## Screen 3 — Feed Tabs: Label, Indicator Animation, Swipe [PHASE 1 + PHASE 2]

Purpose: ปรับ label ("จาก Club ของคุณ" → "Club" ตามที่ Founder ขอ) และทำ indicator ให้เลื่อนแบบ animate
แทนการสลับทันที — ส่วน swipe gesture แยกเป็น Phase 2

User Flow (Phase 1): แตะแท็บ → indicator เลื่อนไปตำแหน่งใหม่แบบ animate (ไม่ใช่กระโดด) → เนื้อหาโหลดใหม่
เหมือนเดิมทุกประการ

User Flow (Phase 2 — ต้องอนุมัติแยก): ผู้ใช้ swipe ซ้าย/ขวาบนพื้นที่ฟีด → สลับ mode พร้อม indicator เลื่อน
ตามนิ้วแบบ real-time (ไม่ใช่แค่ animate หลัง release)

Components:
- Label 3 อัน: **"สำหรับคุณ" / "ติดตาม" / "Club"** (เปลี่ยนจาก "จาก Club ของคุณ") — enum เดิม
  `_HomeFeedMode.fromYourClubs` **ไม่ต้องเปลี่ยนชื่อ** (เป็นแค่ label ที่แสดงผล ไม่ใช่ id ภายใน)
- Indicator ใต้แท็บ active: หนา 2px, `borderRadius` เต็ม (pill), สี sapphire — **ตรงกับที่บรีฟขอเป๊ะอยู่แล้ว
  ด้าน spec ตัวเลข** จุดที่ขาดคือ**การ animate** — ปัจจุบัน indicator เป็นเส้น underline ที่มาจาก
  `DecoratedBox` แบบ static ต่อ tab (สลับทันทีตาม `selected` boolean ไม่มี transition)

Interactions:
- Phase 1: ห่อ indicator ด้วย `AnimatedContainer`/`AnimatedPositioned` (`WynMotion.standard`, 220ms ตาม
  DS-010 token เดิม) ให้เลื่อนจากตำแหน่งเก่าไปตำแหน่งใหม่แทนการสลับทันที — ใช้ motion token ที่มีอยู่แล้ว
  ไม่เพิ่ม duration/curve ใหม่
- Phase 2 [ต้องอนุมัติแยก]: ห่อ 3 มุมมองด้วย `PageView` + sync กับ `_feedMode` — ความซับซ้อนจริง: ตอนนี้
  `_items`/`_page`/`_seenKeys` เป็น state ก้อนเดียวใช้ร่วมกันของ forYou/following (reset ทุกครั้งที่สลับ
  mode ผ่าน `_loadInitial()`) ส่วน fromYourClubs เป็น widget แยกทั้งหมด (`FromYourClubsFeed`) — การทำ swipe
  จริงต้องแยก state ทั้ง 3 mode ให้อยู่รอดพร้อมกัน (คนละ scroll position/pagination) ไม่ใช่แค่เปลี่ยน UI
  ชั้นบน **นี่คือเหตุผลที่แยก Phase**

States: active/inactive เหมือนเดิม, เพิ่ม transitioning state ระหว่าง animate (Phase 1)

Responsive Behavior: label "Club" สั้นกว่า "จาก Club ของคุณ" เดิม → ลดความเสี่ยง overflow ที่เคยเจอใน
WYN-024 (`wyn-024-segmented-feed-mode-scrollable.md`) ไม่เพิ่มความเสี่ยงใหม่

Accessibility: Semantics label เต็มคงเดิม แม้ label ที่แสดงจะสั้นลง — ประกาศ mode ที่เลือกอยู่เหมือนเดิม

Design Rules: indicator ต้องไม่ทับตัวหนังสือ (นอก touch target เดิมของแต่ละแท็บ) ตามกติกา DS-009 เดิม

Handoff: AI Coding — **Phase 1**: เปลี่ยน label string 1 จุด + ห่อ indicator ด้วย `AnimatedContainer`
(`home_feed_screen.dart:_buildFeedModeTab`) — งานเล็ก ไม่กระทบ state/pagination เลย ทำพร้อม Screen 1 ได้
**Phase 2**: แยกเป็น task ใหม่หลังยืนยันกับ Founder ว่าคุ้มความซับซ้อนที่เพิ่ม (แนะนำ AI Product Manager
ประเมิน scope ก่อน เพราะเป็นฟีเจอร์ใหม่ ไม่ใช่ดีไซน์ล้วนๆ)

---

## Screen 4 — Post Action Bar: Touch Target & Feedback (ยืนยันของเดิม)

Purpose: ยืนยันว่า Action Bar (`ActionMetric`) ตรงกับเกณฑ์ทุกข้อของบรีฟอยู่แล้ว — ป้องกันไม่ให้ AI Coding
สร้างซ้ำโดยไม่รู้ว่ามีอยู่แล้ว

User Flow: ไม่เปลี่ยน

Components: Like (`WynHeartIcon`) / Comment / ReDrop / (View count เฉพาะนอก Home) — ผ่าน `ActionMetric`
widget เดียวกันทั้งหมด

Interactions — เทียบกับเกณฑ์บรีฟทีละข้อ:

| เกณฑ์บรีฟ | สถานะจริงในโค้ด |
|---|---|
| Tap area ≥44×44px | ✅ `ConstrainedBox(minHeight: WynSpacing.touchTargetMin)` ใน `action_metric.dart` |
| Animation ตอนกด | ✅ `WynPressScale` (press) + `WynStatePop` (state change, 220ms) จาก DS-010 |
| ตอบสนองทันที (Optimistic UI) | ✅ toggle state ก่อน await เสมอ (pattern เดิมทั้งแอป) |
| Haptic Feedback | ✅ `WynFeedback.toggle()`/`.like()` ตาม DS-010 §3 |
| Animation 150-250ms | ✅ `WynMotion.standard` = 220ms ตรงช่วงที่บรีฟขอเป๊ะ |
| Comment → Sheet/หน้าแบบ Smooth | ✅ เปิด `DropDetailScreen` (push, ไม่ใช่ sheet — ของเดิมตั้งแต่ WYN-004 ไม่เปลี่ยน) |
| Share → Native Share | ✅ `SharePlus.instance.share()` ใน `_openMoreMenu` (ย้ายเข้าเมนู "..." ตาม WYNOSHomeSpec 4.6) |
| ไม่ Animation เยอะเกินไป | ✅ เฉพาะ action ที่มีความหมายเท่านั้น (DS-010 §3 "สิ่งที่ตั้งใจไม่ใส่ haptic") |

States: ไม่เปลี่ยน

Responsive Behavior: ไม่เปลี่ยน (`FittedBox(scaleDown)` กันล้นที่ 320px อยู่แล้ว ตาม QA-WYN-110-002)

Accessibility: ไม่เปลี่ยน — Semantics label ครบทุกปุ่มอยู่แล้ว

Design Rules: ไม่มีจุดต้องแก้

Handoff: **ไม่มีโค้ดต้องแก้ในหัวข้อนี้** — ระบบตรงเกณฑ์ของบรีฟครบทุกข้อโดยไม่ต้องทำอะไรเพิ่ม (DS-010 ทำไว้
ล่วงหน้าแล้วตั้งแต่ 2026-09-05)

---

## Screen 5 — Media: Loading States [PHASE 1]

Purpose: เพิ่ม progressive/lazy loading feel ให้รูปในฟีด โดยไม่แตะตำแหน่ง/สัดส่วนที่ WYN-093/107 วางไว้แล้ว

User Flow: ไม่เปลี่ยน

Components: `PostImageFrame`/`NetworkThumbnail` เดิม — **ต้องตรวจโค้ดจริงก่อนบอกว่าขาดอะไร**: ทั้งสอง widget
มีอยู่แล้วและมี error/placeholder fallback (Beta4 §7 ใช้แทน `Image.network` ดิบไปแล้วหลายจุด) — สิ่งที่ต้อง
ยืนยันคือมี **blur-up/fade-in ตอนรูปโหลดเสร็จ** หรือยัง (ถ้ายังไม่มี ให้เพิ่ม `AnimatedOpacity` ช่วง
`WynMotion.quick` 160ms ตอน frame แรกโหลดเสร็จ — ไม่ใช่ effect ใหม่ ใช้ motion token เดิม)

Interactions: swipe ระหว่างรูปหลายรูป (`HomeFeedImagePeekCarousel`) — **มีอยู่แล้วตั้งแต่ WYN-092** พร้อม dot
indicator — ตรงกับที่บรีฟขอแล้ว ไม่ต้องสร้างใหม่

States: loading (fade-in ใหม่) / loaded / error (fallback เดิม)

Responsive Behavior: ไม่เปลี่ยน

Accessibility: ไม่เปลี่ยน

Design Rules: ไม่ใส่ shadow หนัก/การ์ดซ้อนบนรูปตามที่บรีฟขอ — ของเดิมไม่มีอยู่แล้ว (flat ตาม DS-001/002)

Handoff: AI Coding — ตรวจ `PostImageFrame`/`NetworkThumbnail` จริงว่ามี fade-in หรือยัง **ก่อน** เขียนโค้ด
เพิ่ม (อาจมีอยู่แล้วบางส่วนผ่าน `Image.network`'s `frameBuilder` — ถ้าไม่มีค่อยเพิ่ม `AnimatedOpacity`
160ms) — งานเล็ก ความเสี่ยงต่ำ

---

## Screen 6 — Bottom Navigation & Drop Button (ยืนยันของเดิม + ปรับเล็กน้อย)

Purpose: ยืนยันโครง Bottom Nav ตรงกับบรีฟแล้ว (Home/Search/Drop/Notifications/Profile) และตรวจ Drop
button ตามเกณฑ์ "Premium ไม่ใช่ Android FAB ทั่วไป"

Components — เทียบเกณฑ์บรีฟ:

| เกณฑ์บรีฟ (Drop Button) | สถานะจริง (`root_shell.dart:_buildDropAction`) |
|---|---|
| ปุ่ม + ตรงกลาง เด่นกว่า nav ปกติ | ✅ วงกลม sapphire เต็ม 40×40 พร้อม soft shadow glow (`BoxShadow(color: primary@35%, blur: 16)`) |
| ไม่เหมือน Android FAB ทั่วไป | ✅ วงกลมแบนฝัง**อยู่ในแถว** NavigationBar ปกติ ไม่ใช่ FAB ลอยแยก — ต่างจาก Material FAB ตามมาตรฐานอยู่แล้ว |
| Scale Animation ตอนกด | ⚠️ **ยังไม่มี** — `NavigationDestination` ของ Material ไม่มี press-scale ในตัว |
| Haptic ตอนกด | ✅ ผ่าน guest-gate แล้วค่อยเปิด `CreateDropScreen` — ยังไม่มี haptic แยกสำหรับปุ่มนี้เอง (การเปิดหน้าใหม่ปกติไม่ใส่ haptic ตาม DS-010 แต่ปุ่มนี้เป็น action ไม่ใช่ navigation ล้วนๆ ควรมี) |
| Composer เปิดแบบ Smooth | ✅ `Navigator.push` มาตรฐาน (`MaterialPageRoute`) — Flutter default transition อยู่แล้ว ไม่ต้องแก้ |

Interactions: **เพิ่ม 2 จุดเล็ก**: (1) `WynFeedback.toggle()` เมื่อกด Drop button (มันคือ action ไม่ใช่
navigation ธรรมดา ตรงกับเกณฑ์ DS-010 ที่ยกเว้นเฉพาะ "กด + ใน Bottom Nav" ไว้ก่อนหน้านี้ — **ต้องกลับไปถาม
Founder** ว่าจะย้อนกติกาเดิมนี้หรือไม่ เพราะ DS-010 เขียนไว้ชัดเจนว่า "การกด '+' ใน Bottom Nav" คือสิ่งที่
ตั้งใจไม่ใส่ haptic — เปลี่ยนตรงนี้คือการย้อนกติกาที่อนุมัติไปแล้ว ไม่ใช่ default ที่ทำได้เอง) (2)
press-scale เบาๆ (`WynPressScale`, มี widget อยู่แล้วจาก `action_metric.dart`, reuse ได้ทันที)

States: ไม่เปลี่ยน

Responsive Behavior: ไม่เปลี่ยน (40px คงที่ ไม่ผูกจอ)

Accessibility: ไม่เปลี่ยน (Semantics label "สร้างโพสต์ใหม่" มีอยู่แล้ว)

Design Rules: Bottom Nav ปกติ 4 รายการ (Home/Search/Notifications/Profile) ใช้ Material `NavigationBar`
default อยู่แล้ว ตรงกับ "Simple, Symmetrical, Thumb-friendly" ของบรีฟ — ไม่ต้องแก้

Handoff: AI Coding — เพิ่ม `WynPressScale` รอบ `_buildDropAction()` (reuse widget เดิม) — **เรื่อง haptic
ต้องได้คำตอบ Founder ก่อน** เพราะขัดกับ DS-010 rule ที่ล็อกไว้แล้ว (ดู popup คำถามท้ายเอกสาร)

---

## Screen 7 — Loading & Refresh [PHASE 1 บางส่วน + PHASE 2 บางส่วน]

Purpose: ยืนยัน Skeleton ตรงเกณฑ์ + ประเมิน custom pull-to-refresh animation

Components:
- `HomeFeedSkeleton` — **มีอยู่แล้ว ตรงกับ layout จริง** (avatar+name row, image block 1:1, action row
  3 metric) ตรงกับที่บรีฟขอ ("Skeleton ต้องตรงกับ Layout จริง") **จุดเดียวที่ต่างจากการ์ดจริงตอนนี้**: การ์ด
  จริงหลัง WYN-107 เป็น 2 คอลัมน์ (avatar แยกคอลัมน์ซ้าย) — skeleton ปัจจุบันยังเป็น `Row` แบบเก่า (avatar +
  Column ข้างกัน) ไม่ใช่ปัญหาใหญ่ (รูปทรงใกล้เคียงพอ) แต่ควรปรับให้ตรง 100% เพื่อไม่ให้ layout "ขยับ" ตอนสลับ
  จาก skeleton เป็นของจริง ตามกติกา "ห้ามทำหน้าจอกระโดดเมื่อโหลดเสร็จ" ของบรีฟเป๊ะ
- Pull-to-refresh — ปัจจุบันใช้ `RefreshIndicator` มาตรฐานของ Flutter (สีอ่านจาก `colorScheme.primary` =
  sapphire โดย default ของ Material 3 อยู่แล้ว — **ต้องดูภาพจริงยืนยัน** ก่อนสรุปว่าไม่ต้องแก้อะไร)

Interactions [PHASE 2]: custom brand pull animation (โลโก้/ไอคอน WYNOS แทน spinner ธรรมดา) — ต้องเขียน
`CustomScrollView` + `NotificationListener<ScrollNotification>` ทดแทน `RefreshIndicator` ทั้งกลไก
(Flutter ไม่มีทางแทรก custom child เข้า `RefreshIndicator` เดิมได้ตรงๆ) **เพิ่ม surface ที่ต้องเทส
(gesture คำนวณระยะดึงเอง) และความเสี่ยง regression กับ pull-to-refresh ที่ทำงานถูกอยู่แล้วทุกจุด — แยก Phase**

States: ไม่เปลี่ยนนอกจาก skeleton shape (Phase 1)

Responsive Behavior: ไม่เปลี่ยน

Accessibility: ไม่เปลี่ยน (skeleton มี `ExcludeSemantics` อยู่แล้ว)

Design Rules: static block ไม่ shimmer (กันปัญหา `pumpAndSettle` ไม่ settle ตามที่คอมเมนต์ในโค้ดระบุไว้แล้ว
— **ห้ามเปลี่ยนเป็น shimmer animation** แม้บรีฟจะพูดถึง "Loading ใช้ Skeleton" เฉยๆ ไม่ได้ขอ shimmer ชัดเจน)

Handoff: **Phase 1** — ปรับ `HomeFeedSkeleton` ให้เป็น 2 คอลัมน์ตรงกับการ์ดจริง 100% (งานเล็ก, ไฟล์เดียว)
**Phase 2** — custom pull animation แยกเป็น task ใหม่ ต้องมี Artifact ให้ Founder ดูก่อนเขียนโค้ดเสมอ (ตาม
กติกา 2026-09-03) เพราะเป็นแอนิเมชันแบรนด์ที่ต้องเห็นภาพเคลื่อนไหวก่อนตัดสินใจ ไม่ใช่แค่ token ตัวเลข

---

## Screen 8 — Mobile UX & Performance Checklist (ตรวจสอบ ไม่ใช่ Screen ใหม่)

Purpose: เช็กลิสต์เกณฑ์ข้อ 12-13 ของบรีฟ เทียบกับสถานะจริงในโค้ด/QA ที่มีอยู่แล้ว

Design Rules — ตาราง Mobile UX:

| เกณฑ์ | สถานะ |
|---|---|
| Safe Area | ✅ `SafeArea` ครอบ body ของ `HomeFeedScreen` อยู่แล้ว |
| Touch target ≥44×44 | ✅ ทุกปุ่มใน action bar/dismiss icon (WYN-106 ไล่แก้ครบแล้ว) |
| Content ไม่ถูก Bottom Nav บัง | ✅ `Scaffold.bottomNavigationBar` จัดการให้อัตโนมัติ (Flutter ไม่ต้องเพิ่ม padding เอง) |
| Layout ไม่กระโดดตอน keyboard เปิด | ⚠️ **ยังไม่เคยตรวจเฉพาะจุดนี้บน Home** (K-10 ของ Beta4 พูดถึง text scale ไม่ใช่ keyboard) — Home ไม่มี text input ยกเว้น comment sheet ที่แยกหน้าอยู่แล้ว ความเสี่ยงต่ำ แต่ยังไม่มีเทสยืนยันตรงๆ |

Design Rules — ตาราง Performance:

| เกณฑ์ | สถานะ |
|---|---|
| ไม่โหลด feed ใหม่ทั้งหมดเมื่อ Like/Follow | ✅ Optimistic update ในที่ (setState เปลี่ยน item เดียวใน `_items` list, ไม่ reload) |
| Preserve scroll position | ✅ `_scrollController` เดียวคงอยู่ตลอด, ไม่ rebuild list ทิ้ง |
| Cache feed | ⚠️ ไม่มี local cache ข้าม session (reload ทุกครั้งที่เปิดแอปใหม่) — **นอกขอบเขตงานนี้** เป็นเรื่อง data layer ไม่ใช่ UI/UX ถ้า Founder ต้องการควรเป็นงานแยกกับ AI Product Manager ประเมิน trade-off (offline-first เพิ่ม complexity เยอะ) |

Handoff: รายการ ⚠️ ทั้งหมดเป็น "รู้แล้วว่ายังไม่ครบ" ไม่ใช่ "ต้องแก้ในรอบนี้" — เสนอให้ Founder ตัดสินใจว่า
จุดไหนอยากทำต่อ ผ่านคำถามท้ายเอกสาร

---

## สรุป Handoff รวม

**Phase 1 (พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติภาพ mockup)**: Screen 1 (spacing table), Screen 3
(label เปลี่ยน + indicator animate, ไม่รวม swipe), Screen 5 (image fade-in), Screen 6 (press-scale, ไม่รวม
haptic ที่ต้องถาม), Screen 7 (skeleton 2-คอลัมน์) — รวม 6 ไฟล์ ไม่มี schema/backend change ความเสี่ยง
regression ต่ำ ทุกจุดใช้ token/motion ที่มีอยู่แล้วในระบบ

**Phase 2 (แยก task ใหม่ ต้องอนุมัติ scope เพิ่มก่อน)**: Feed tab swipe gesture, Custom pull-to-refresh
brand animation — ทั้งสองเป็นฟีเจอร์ใหม่จริง ไม่ใช่ "รายละเอียด" ตามที่บรีฟตั้งใจไว้เอง
