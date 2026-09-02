# Design Spec — WYN-095: รีดีไซน์ Layout หน้าโปรไฟล์ (Founder เลือก Mockup A — READY FOR CODING)

Owner: AI Design (เสร็จ) → AI Coding
Ref: `.wyn/tasks/backlog/WYN-095.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/profile/presentation/view_profile_screen.dart` (header ปัจจุบันทั้งหมด, ปุ่ม Follow/Message ที่มีอยู่แล้ว, `_StatBlock`/`_FollowCountTarget`/`_buildStatDivider`), `app/lib/features/profile/presentation/widgets/avatar_circle.dart` (default radius 40)
Design system: `WynColors`/`WynSpacing` เดิมทั้งหมด (ไม่มี token ใหม่ในเอกสารนี้) — **สี = Sapphire `#1B3A6B`/paper/ink/graphite/hairline ตาม `app/lib/core/design/wyn_colors.dart` ปัจจุบัน (re-brand จาก Cyan→Sapphire, 2026-08-29) ไม่ใช่ Cyan ของ DS-001 (2026-08-15) ที่ถูกแทนที่ไปแล้ว**

> **อัปเดต 2026-09-02**: Founder เลือก **Mockup A** (กะทัดรัด, ปุ่มคู่เต็มแถว) จาก 3 ตัวเลือกด้านล่าง หลังดู mockup ภาพจริงที่ `https://claude.ai/code/artifact/ec69fff6-4555-44a4-82b8-ade23c49d709` (พรีวิวรอบแรกใช้สี Cyan ผิดพลาด — Founder ทักท้วง แก้เป็น Sapphire ให้ตรงกับแอปจริงแล้วก่อนอนุมัติรอบนี้) — เอกสารนี้พร้อมส่ง AI Coding แล้ว ส่วน Mockup B/C ด้านล่างเก็บไว้เป็นบันทึกการตัดสินใจเท่านั้น ไม่ใช่ทางเลือกที่ใช้งานจริงอีกต่อไป

---

## Final Spec — Mockup A (Founder อนุมัติแล้ว)

**Screen:** `ViewProfileScreen` header (`app/lib/features/profile/presentation/view_profile_screen.dart`) — ทั้งโปรไฟล์ตัวเอง (`isOwnProfile == true`) และโปรไฟล์คนอื่น

**Purpose:** จัดวาง avatar/สถิติ/ชื่อ/username/bio/ปุ่ม ใหม่ตามผังสีที่ Founder วงไว้ (avatar+สถิติแถวเดียวกัน → ชื่อ+username ชิดซ้ายใต้แถวนั้น → bio เต็มความกว้าง → ปุ่ม Follow/Message คู่เต็มแถวแบ่งครึ่ง)

**User Flow:** ไม่เปลี่ยนจากปัจจุบัน — ผู้ใช้เปิดโปรไฟล์คนอื่น → เห็น header ใหม่ → กดปุ่ม "ติดตาม"/"ส่งข้อความ" ทำงานเหมือนเดิมทุกประการ (แค่ตำแหน่ง/ทรงปุ่มเปลี่ยน ไม่ใช่ logic)

**Components** (บนลงล่าง แทนที่ header `Column` เดิมทั้งก้อน):
1. `Row` บนสุด: `AvatarCircle(radius: 40, ring: true)` ชิดซ้าย + `Expanded` ครอบ `Row` สถิติ 3 ช่อง (ผู้ติดตาม/กำลังติดตาม/โพสต์) ชิดขวา — คงปุ่ม `Semantics(button: true)` ของแต่ละสถิติไว้เหมือนเดิม
2. ชื่อที่แสดง — `titleLarge`-ish (bold ~20px), ชิดซ้ายเริ่มจากขอบเดียวกับ avatar, `padding-top: WynSpacing.space3`
3. `@username` — `graphite`, ใต้ชื่อทันที, ไม่มีช่องไฟเพิ่ม
4. Bio (ถ้ามี) — เต็มความกว้าง, `padding-top: WynSpacing.space2`, ยุบพื้นที่ทิ้งถ้า `bio == null || bio.isEmpty` (พฤติกรรมเดิม)
5. แถวปุ่ม — `Row` เต็มความกว้าง แบ่งครึ่งเท่ากันด้วย `Expanded` ทั้งคู่, ช่องไฟระหว่างปุ่ม `WynSpacing.space2` (8px), `padding-top: WynSpacing.space4`

**สีที่ใช้จริง** (คัดลอกตรงจาก `view_profile_screen.dart` บรรทัด 1155-1210 ปัจจุบัน — ไม่มีสีใหม่):
- ปุ่ม Follow — ยังไม่ติดตาม: `FilledButton`, `StadiumBorder`, พื้น `WynColors.sapphire` (`#1B3A6B`), ตัวหนังสือ `WynColors.paper`
- ปุ่ม Follow — ติดตามแล้ว: พื้น `Color(0xFFF1EFE9)`, ตัวหนังสือ `WynColors.graphite`
- ปุ่ม Follow — สถานะที่ 3 "ขอติดตามแล้ว" (WYN-039, Private account): คงทรง/สีเดิมของสถานะนี้ทุกประการ แค่ย้ายตำแหน่ง
- ปุ่ม Message — **เปลี่ยนจาก icon-only วงกลม (`CircleBorder`, 40×40) เป็นเต็มกล่องมี label "ส่งข้อความ"**: `OutlinedButton.icon`, สี/เส้นเดิมทุกประการ (`side: BorderSide(color: WynColors.hairline)`, `foregroundColor: WynColors.ink`) — เปลี่ยนแค่ `shape`/`padding`/เพิ่ม label ไม่เปลี่ยนสี
- `isOwnProfile == true`: ปุ่ม "แก้ไขโปรไฟล์" เดี่ยวแทนที่ตำแหน่งปุ่มคู่นี้ — สไตล์เดิมเป๊ะ (`OutlinedButton`, `StadiumBorder`, `hairline` border, `ink` text) ไม่ทำเป็น `Expanded` คู่ (ปุ่มเดียวไม่ต้องแบ่งครึ่ง — เต็มความกว้างปุ่มเดียว หรือคงความกว้างเดิมตามโค้ดปัจจุบัน ถ้าเดิม fixed-width ให้คงไว้)

**Interactions:** ปุ่ม Follow/Message กด-แล้ว-ทำงานทันที เหมือนโค้ดปัจจุบันทุกจุด (`_toggleFollow`/`_sendFollowRequest`/`_cancelFollowRequest`/`_openChat`) — งานนี้ไม่แตะ logic เลย

**States:**
- Bio ว่าง → ยุบพื้นที่ (ไม่เหลือช่องว่าง)
- `_isFollowing == null` (กำลังโหลดสถานะ) → ปุ่ม Follow/Message ทั้งแถวซ่อนไว้ก่อนเหมือนพฤติกรรมเดิม
- Blocked persona (WYN-027) → `_buildBlockedBanner()` แทนที่ stats+ปุ่มทั้งหมดเหมือนเดิม ไม่เปลี่ยน
- Private + ยังไม่ follow (WYN-039) → ปุ่ม Follow 3 สถานะเดิมทั้งหมด แค่อยู่ในตำแหน่งใหม่

**Responsive Behavior:** ที่ 360px ห้าม stats row overflow — เลข follower สูงต้องย่อ (เช่น "1.2K"/"1.2M") ถ้ามี helper อยู่แล้วในระบบให้ใช้ ถ้าไม่มีให้ AI Coding ตัดสินใจ format ตอน implement — ทดสอบที่ 360px ก่อนถือว่าเสร็จ

**Accessibility:**
- Stats แต่ละตัวคง `Semantics(button: true, label: '$count $label')` เดิม
- ปุ่ม Message ตอนนี้มี label ข้อความจริงแล้ว ("ส่งข้อความ") — ลด dependency บน semantics label เดี่ยวที่ Mockup B เคยต้องพึ่ง
- ลำดับการอ่านของ screen reader ต้องตาม visual order ใหม่ (avatar+stats → ชื่อ → username → bio → ปุ่ม) — ทดสอบ TalkBack/VoiceOver order ใหม่หลัง implement

**Design Rules:** ไม่แนะนำ token สีใหม่ใดๆ — ใช้ `WynColors`/`WynSpacing` เดิมทั้งหมด ตรงตามกติกา "ห้ามคิดทิศทาง visual ใหม่หากมี design system ที่อนุมัติแล้ว"

**Handoff:** ส่ง AI Coding ได้ทันที — งานจริงจะแตะ `app/lib/features/profile/presentation/view_profile_screen.dart` (`_ProfileHeaderData`/header `Column` ทั้งก้อน) เท่านั้น ไม่กระทบ Tab bar/tab content ที่เหลือ (`wyn-071` Screen 6-7 ยังใช้ได้ตามเดิม) — เขียน/แก้ widget test ยืนยันตำแหน่งใหม่ (avatar+stats row บนสุด, ชื่อ/username ใต้แถวนั้นชิดซ้าย, ปุ่มคู่เต็มแถวใต้ bio) ก่อนถือว่าเสร็จ

---

## สิ่งที่ Founder ยืนยันแน่นอนแล้ว (ทุก mockup ต้องตรงตามนี้เหมือนกันหมด)

จากผังสีที่ Founder วงไว้:
- 🔴 แดง = รูปโปรไฟล์
- ใต้รูปโปรไฟล์ (ไม่ใช่ข้างๆ) = ชื่อที่แสดง (display name)
- 🟢 เขียว = แถวสถิติ (ผู้ติดตาม / กำลังติดตาม / โพสต์) **อยู่ข้างๆ รูปโปรไฟล์** (ไม่ใช่อยู่ใต้ชื่อแบบที่โค้ดปัจจุบันทำ)
- 🟡 เหลือง = @username

**การตีความโครงสร้างร่วม** (มาตรฐานเดียวกันทั้ง 3 mockup): แถวบนสุดเป็น `Row` — รูปโปรไฟล์ชิดซ้าย + แถวสถิติ 3 ตัวอยู่ทางขวาในแถวเดียวกัน จากนั้น**ใต้แถวนั้น** (ไม่ใช่อยู่ในแถวเดียวกันอีกต่อไป) คือชื่อที่แสดง แล้วต่อด้วย @username — จัดชิดซ้ายเริ่มจากขอบเดียวกับรูปโปรไฟล์ (ไม่ใช่กึ่งกลางจอแบบโค้ดปัจจุบัน)

**หมายเหตุสำคัญเรื่องทิศทาง visual**: โครงสร้างนี้ (รูปซ้าย + สถิติข้างๆ, ชื่อ/username ใต้แถวนั้นแบบชิดซ้าย) **ต่างจากโค้ดปัจจุบัน** (`view_profile_screen.dart`) ที่เพิ่งทำตาม `wyn-071-wynos-visual-refresh.md` (แรงบันดาลใจจาก Threads: ทุกอย่างจัดกึ่งกลาง, สถิติอยู่ใต้ bio) — และใกล้เคียงโครงสร้างที่คุ้นเคยจากแอปโซเชียลหลายแอปที่มี avatar-ซ้าย-stats-ขวา **การเปลี่ยนทิศทางนี้มาจากคำสั่งของ Founder เองโดยตรงผ่านผังสีที่วาดมา ไม่ใช่ AI Design เลือกลอก layout เอง** (design-principles.md ห้าม AI Design เลือกลอก IG/TikTok เอง — แต่ไม่ได้ห้าม Founder สั่งเปลี่ยนทิศทางที่บังเอิญคล้ายกันบางส่วน เพราะเป็นคำตัดสินใจของ Founder ไม่ใช่ AI ริเริ่มเอง) — ระบุไว้ตรงๆ ให้ Founder เห็นก่อนอนุมัติ

**คงเดิมสำหรับทั้ง 3 mockup** (ไม่ใช่จุดที่ต้องเลือก): `AvatarCircle(radius: 40, ring: true)`, สี/รูปทรงปุ่ม Follow (`FilledButton`, `StadiumBorder`, sapphire/tinted) และปุ่ม Message (`OutlinedButton`, `CircleBorder`, 40×40, hairline border) ที่มีอยู่แล้วในโค้ดปัจจุบัน — งานนี้จัดตำแหน่งใหม่ ไม่ออกแบบปุ่มใหม่ (ลดความเสี่ยง/งานซ้ำ), Tab bar (Posts/Replies/Media/Likes จาก `wyn-071`) อยู่ล่างสุดเหมือนเดิมทุก mockup, persona `isOwnProfile` ยังต้องรองรับทั้ง 2 แบบ (ปุ่ม "แก้ไขโปรไฟล์" แทนที่ Follow+Message เมื่อดูโปรไฟล์ตัวเอง — ตำแหน่งเดียวกับที่ Follow+Message อยู่ในแต่ละ mockup)

---

## Mockup A — "กะทัดรัด" (Bio เต็มความกว้าง ก่อนปุ่ม, ปุ่มคู่เต็มแถว)

```
┌─────────────────────────────────────┐
│  ⬤ Avatar     ผู้ติดตาม กำลังติดตาม โพสต์  │   ← แถวบน: avatar ซ้าย + stats ขวา (แนวราบ)
│  (80px)         120      45      312   │
│                                       │
│  ชื่อที่แสดง (bold, 20px)                │   ← ใต้แถว avatar+stats, ชิดซ้าย
│  @username (graphite, 13px)          │
│                                       │
│  Bio ข้อความยาวได้สูงสุด 3 บรรทัด...     │   ← เต็มความกว้าง ก่อนปุ่ม
│                                       │
│  [   ติดตาม   ] [  ส่งข้อความ  ]        │   ← ปุ่มคู่ full-width แบ่งครึ่ง (flex เท่ากัน)
│                                       │
├─────────────────────────────────────┤
│  Posts | Replies | Media | Likes     │
```

Components: `Row` บนสุด (avatar 80px + `Expanded(stats Row)`) → `Column` ชิดซ้าย (ชื่อ, username, bio) → `Row` ปุ่ม 2 ปุ่ม **เต็มความกว้างแบ่งครึ่งเท่ากัน** (`Expanded` ทั้งคู่, ปุ่ม Follow เป็น `FilledButton` เต็มกล่อง, ปุ่ม Message เปลี่ยนจาก icon-only 40×40 เดิมเป็น `OutlinedButton.icon` เต็มกล่องมี label "ส่งข้อความ" — **ต่างจากโค้ดปัจจุบันที่เป็น icon-only วงกลม**)

**ข้อดี**: คุ้นเคยที่สุด (pattern ปุ่มคู่เต็มแถวที่ผู้ใช้ social app ส่วนใหญ่คุ้นเคย) tap target ใหญ่ที่สุดในทั้ง 3 แบบ, อ่าน bio ก่อนตัดสินใจกดปุ่มได้ (ลำดับการอ่านเป็นธรรมชาติ: identity → bio → action)

**ข้อเสีย**: ปุ่มเต็มแถวสองปุ่มกินพื้นที่แนวตั้งมากกว่าแบบอื่น (ดันเนื้อหาโพสต์ลงล่างมากที่สุด), ต้องเปลี่ยนปุ่ม Message จาก icon-only เป็นมี label (เพิ่มงาน implement เล็กน้อยเทียบกับ mockup อื่นที่ reuse ปุ่มเดิมได้ตรงๆ), "เรียบหรู" น้อยกว่า 2 แบบถัดไปเพราะปุ่มมีน้ำหนักภาพเยอะ

---

## Mockup B — "ปุ่มกะทัดรัดชิดซ้าย" (ต่อยอดปุ่มเดิมของโค้ดปัจจุบันตรงๆ)

```
┌─────────────────────────────────────┐
│  ⬤ Avatar     ผู้ติดตาม กำลังติดตาม โพสต์  │
│  (80px)         120      45      312   │
│                                       │
│  ชื่อที่แสดง (bold, 20px)                │
│  @username (graphite, 13px)          │
│                                       │
│  [ติดตาม] (⊙)                        │   ← ปุ่มเล็กชิดซ้าย: Follow pill + Message icon-only (ของเดิม)
│                                       │
│  Bio ข้อความ...                        │   ← bio อยู่ "ใต้" แถวปุ่ม
│                                       │
├─────────────────────────────────────┤
│  Posts | Replies | Media | Likes     │
```

Components: เหมือน Mockup A จนถึงชื่อ/username แต่แถวปุ่มถัดมาเป็น **ปุ่มขนาดกะทัดรัด ไม่เต็มแถว ชิดซ้าย** — Follow pill (`FilledButton`, sapphire, padding เดิมจากโค้ดปัจจุบันเป๊ะ) + Message icon-only วงกลม 40×40 (`OutlinedButton`, hairline border — **ใช้โค้ดเดิมตรงๆ ไม่ต้องแก้ style เลย** เพราะทั้งคู่มีอยู่แล้วในไฟล์ปัจจุบัน แค่ย้ายตำแหน่งจาก "ใต้ bio จัดกึ่งกลาง" มาเป็น "เหนือ bio จัดชิดซ้าย") จากนั้น bio ตามมาด้านล่าง

**ข้อดี**: ความเสี่ยง/ต้นทุน implement ต่ำที่สุดในทั้ง 3 แบบ (reuse widget ปุ่มทั้งสองตัวจากโค้ดปัจจุบันแบบ byte-identical แค่ย้ายตำแหน่งใน widget tree) พื้นที่แนวตั้งที่ปุ่มใช้น้อยที่สุด (ตรงกับความรู้สึก "เรียบ" ที่ระบบเน้นมาตลอด) เนื้อหาโพสต์ขึ้นมาเร็วที่สุดเมื่อ scroll

**ข้อเสีย**: ลำดับการอ่าน "เห็นปุ่มก่อนอ่าน bio" อาจรู้สึกเร่งรีบกว่าธรรมชาติ (ต้องตัดสินใจกด follow ก่อนรู้จักคนนั้นจาก bio) ปุ่ม Message icon-only ไม่มี label ต้องพึ่ง `Semantics`/tooltip ให้ผู้ใช้ใหม่เข้าใจว่ากดแล้วทำอะไร (accessibility ต้องเข้มงวดกว่า mockup A ที่มี label ตรงตัว)

---

## Mockup C — "Editorial" (Bio ก่อนปุ่ม, ปุ่มเรียงซ้อนแนวตั้งเต็มความกว้างทั้งคู่)

```
┌─────────────────────────────────────┐
│  ⬤ Avatar     ผู้ติดตาม กำลังติดตาม โพสต์  │
│  (80px)         120      45      312   │
│                                       │
│  ชื่อที่แสดง (bold, 20px)                │
│  @username (graphite, 13px)          │
│                                       │
│  Bio ข้อความยาวได้สูงสุด 3 บรรทัด...     │
│                                       │
│  [        ติดตาม        ]             │   ← ปุ่ม Follow เต็มแถว บรรทัดแรก
│  [      ส่งข้อความ      ]              │   ← ปุ่ม Message เต็มแถว บรรทัดถัดมา (outline, รอง)
│                                       │
├─────────────────────────────────────┤
│  Posts | Replies | Media | Likes     │
```

Components: เหมือน Mockup A จนถึง bio แต่ปุ่มเรียง **ซ้อนแนวตั้ง 2 บรรทัดแทนที่จะแบ่งครึ่งแนวนอน** — Follow (`FilledButton` เต็มแถว, sapphire, primary) บรรทัดบน, Message (`OutlinedButton.icon` เต็มแถว, hairline border, secondary) บรรทัดล่างติดกัน — ลำดับความสำคัญชัดที่สุด (Follow ใหญ่/เด่นกว่า อยู่บนสุด)

**ข้อดี**: ลำดับชั้นความสำคัญของปุ่มชัดเจนที่สุด (Follow เป็น primary action เห็นชัด ไม่แข่งน้ำหนักกับ Message เหมือน Mockup A ที่แบ่งครึ่งเท่ากัน) tap target ใหญ่ทั้งคู่ (accessibility ดีสุด ไม่ต้องพึ่ง label ผ่าน semantics อย่างเดียวเหมือน B) ลำดับการอ่าน identity→bio→action เป็นธรรมชาติเหมือน A

**ข้อเสีย**: ใช้พื้นที่แนวตั้งมากที่สุดในทั้ง 3 แบบ (2 บรรทัดปุ่มเต็มความกว้าง ต่อจาก bio ที่อาจยาวถึง 3 บรรทัดอยู่แล้ว) ดันเนื้อหาโพสต์ลงล่างสุด — เสี่ยงรู้สึก "เทอะทะ" ขัดกับคำว่า "เรียบหรู" ที่ระบบเน้นมาตลอดมากที่สุดในทั้ง 3 ตัวเลือก โดยเฉพาะบนโปรไฟล์ตัวเอง (ที่ต้องแทนที่ด้วยปุ่ม "แก้ไขโปรไฟล์" เดี่ยว — ช่องว่างที่เหลือจะดูโหว่กว่า mockup อื่น)

---

## ตารางเทียบสั้น

| | A กะทัดรัด | B ปุ่มเล็กชิดซ้าย | C Editorial |
|---|---|---|---|
| ต้นทุน implement | กลาง (ต้องเปลี่ยนปุ่ม Message เป็นมี label) | **ต่ำสุด** (reuse ปุ่มเดิม 100%) | กลาง (reuse ปุ่มเดิมแต่เปลี่ยน layout เป็นแนวตั้ง) |
| พื้นที่แนวตั้งที่ใช้ | กลาง | **น้อยสุด** | มากสุด |
| ลำดับอ่าน bio ก่อนปุ่ม | ✅ | ❌ (ปุ่มมาก่อน) | ✅ |
| ความชัดของ primary/secondary action | ปานกลาง (แบ่งครึ่งเท่ากัน) | ปานกลาง | **ชัดสุด** |
| ต่อเนื่องกับโค้ดปัจจุบันมากสุด | ปานกลาง | **สูงสุด** | ปานกลาง |

---

## จุดร่วมที่ต้อง handle เหมือนกันทุก mockup (นอกเหนือขอบเขตการเลือก)

- **`isOwnProfile == true`**: แทนที่ตำแหน่งปุ่ม Follow+Message ด้วยปุ่ม "แก้ไขโปรไฟล์" เดี่ยว (style เดิมจากโค้ดปัจจุบัน — `OutlinedButton`, `StadiumBorder`, hairline) + ไอคอน "บันทึก"/"ร่าง" ข้างๆ ตามโค้ดปัจจุบัน (`wyn-071` Screen 6) — ไม่มีปุ่ม Message ให้แสดงเมื่อดูโปรไฟล์ตัวเอง (behavior เดิม)
- **Bio ว่างเปล่า**: ทุก mockup ต้องยุบพื้นที่ bio ไปเลย (ไม่เหลือช่องว่าง) — ตรงกับพฤติกรรมปัจจุบัน (`if (profile.bio != null && profile.bio!.isNotEmpty)`)
- **Blocked persona (WYN-027)**: ยังคง `_buildBlockedBanner()` แทนที่ stats+ปุ่มเหมือนเดิมทุก mockup (ไม่อยู่ในสโคปที่ต้องออกแบบใหม่)
- **Private + ยังไม่ได้ follow (WYN-039)**: Follow button 3 สถานะเดิม ("ติดตาม"/"กำลังติดตาม"/"ขอติดตามแล้ว") ยังใช้ logic เดิมทั้งหมด ไม่เปลี่ยนไม่ว่าจะเลือก mockup ไหน

## Accessibility (ร่วมทุก mockup)

- Stats แต่ละตัวยังเป็น `Semantics(button: true, label: '$count $label')` เหมือนโค้ดปัจจุบัน (ไม่เปลี่ยน — แค่ย้ายตำแหน่งในหน้าจอ)
- ปุ่ม Message ถ้าเป็น icon-only (mockup B) ต้องมี `Semantics(label: 'ส่งข้อความถึง {ชื่อ}')` ชัดเจน (มีอยู่แล้วในโค้ดปัจจุบัน — คงไว้)
- ลำดับการอ่านของ screen reader (`Semantics` traversal order) ต้องตาม visual order ของ mockup ที่เลือก ไม่ใช่ลำดับเดิมของโค้ด (ต้องทดสอบ TalkBack/VoiceOver order ใหม่หลัง implement ไม่ว่าเลือกแบบไหน)

## Responsive Behavior (ร่วมทุก mockup)

Stats row ข้างๆ avatar ต้องไม่ overflow บนจอแคบ 360px — ถ้าชื่อ/ตัวเลขยาว (เช่น follower เกินล้าน) ให้ตัวเลขย่อรูปแบบ (เช่น "1.2K"/"1.2M" ถ้ามี helper อยู่แล้วในระบบ, ถ้าไม่มีให้ AI Coding ตัดสินใจ format ตอน implement — ไม่ใช่จุดตัดสินใจของเอกสารนี้) — ทดสอบทั้ง 3 mockup ที่ 360px ก่อนถือว่าเสร็จ

## Handoff (เดิม — เก็บไว้เป็นบันทึกกระบวนการ)

~~ไม่ส่ง AI Coding จนกว่า Founder จะเลือก~~ — **แก้แล้ว 2026-09-02**: ถามผ่าน popup จริงพร้อมสรุปตารางเทียบ Founder ตอบ "ขอดูตัวอย่าง" ก่อน → ทำ HTML mockup จริงส่งไปให้ดู (รอบแรกสีผิดเป็น Cyan, Founder ทักท้วง → แก้เป็น Sapphire ให้ตรงแอปจริง) → Founder เลือก **Mockup A** ยืนยันแล้ว → เขียน Final Spec เต็มไว้ด้านบนสุดของเอกสารนี้แล้ว (ดู "Final Spec — Mockup A")

## สรุปสถานะ

**READY FOR CODING — Founder อนุมัติ Mockup A แล้ว (2026-09-02)** ดู Final Spec ด้านบนสุดของเอกสารนี้สำหรับรายละเอียดที่ AI Coding ต้อง implement จริง (Mockup B/C ด้านล่างนี้เป็นบันทึกทางเลือกที่ไม่ได้ใช้เท่านั้น)
