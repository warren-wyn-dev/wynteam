# Design Spec — WYN-056: Club Discovery Visual Refresh (Founder Visual Brief, 2026-08-24)

> โดย AI Design — 2026-08-24
> Input: Founder ส่งภาพ mockup + text brief เต็มรูปแบบ ("WYNOS" high-fidelity Club UI concept: CLUB hero screen, สร้าง Club, สำรวจ Club, Bottom Nav) ขอ "high-fidelity mobile UI/UX concept" สำหรับหน้า Club
> อ้างอิง Design system ที่อนุมัติแล้ว: `.wyn/docs/design/ds-001-color-system.md` (Cyan `#00C8FF` ดิบ, ห้าม Liquid Glass, ทั้ง Light+Dark ต้อง first-class), `ds-009-rainbow-accent.md` (Rainbow จำกัด 2 จุดเท่านั้น), `wyn-014-club-core.md`/`wyn-015-club-discovery-integration.md`/`wyn-017-home-trending-recommended-clubs.md` (Club ที่มีอยู่แล้ว), `wyn-024-bottom-nav-v1-restructure.md` (Bottom Nav ปัจจุบัน)
> โค้ดที่เกี่ยวข้อง: `app/lib/features/club/presentation/explore_clubs_screen.dart`, `widgets/club_discovery_card.dart`, `widgets/club_mini_card.dart`, `widgets/club_section.dart` (Home), `presentation/create_club_screen.dart`

## กติกาบังคับ: ห้ามคิดทิศทาง visual ใหม่ — งานนี้คือการ "ปรับ" ไม่ใช่ "ประดิษฐ์ใหม่"

Club ผ่าน Design+Coding+QA มาแล้วครบ (WYN-014/015/017, ทุกไฟล์อยู่ใน `.wyn/tasks/approved/`) สี Cyan `#00C8FF` บนพื้นดำก็เป็นทิศทางที่ Founder อนุมัติแล้วตั้งแต่ 2026-08-15 (DS-001 "Option B") — ภาพที่ Founder ส่งมาจึง **ไม่ใช่ทิศทางใหม่** แต่เป็นข้อเสนอให้ยกระดับความสวยงาม/ความหนาแน่นของภาพในหน้า Discovery ให้ตรงกับที่ Founder จินตนาการไว้มากขึ้น งานนี้จึงเป็นการ **redesign เฉพาะ visual layer ของหน้าสำรวจ Club** ต่อยอดจากโครงสร้างข้อมูล/พฤติกรรม/RLS ที่มีอยู่แล้วทั้งหมด ไม่แตะ schema, ไม่แตะ permission logic, ไม่แตะ Home's ClubSection ที่ผ่าน QA แล้ว (WYN-017)

## จุดที่ reconcile กับ Design system ที่อนุมัติแล้ว (สรุปก่อนลงรายละเอียด)

| จากภาพ/brief ของ Founder | เข้ากับ system เดิมได้ไหม | การตัดสินใจ |
|---|---|---|
| พื้นดำ + Cyan `#00C8FF` accent | ✅ ตรงกับ DS-001 Option B เป๊ะ | ใช้ `colorScheme` เดิมทั้งหมด ไม่ hardcode สีใหม่ |
| "glassmorphism", blur, frosted surface | ❌ ขัดกับกติกาตายตัว "ห้ามใช้ Liquid Glass" (DS-001 ข้อ 1) | **ตัดออกทั้งหมด** — ใช้พื้นผิวทึบ + cyan glow เป็น drop-shadow สีเดียว (ไม่ blur/ไม่โปร่งแสง) แทน ยังได้ความรู้สึก "เรืองแสง" แต่ไม่ผิดกติกา |
| Rainbow gradient ring รอบ avatar Club ที่กำลังฮิต (ตีความจากคำว่า "subtle motion/trend graphics") | ❌ DS-009 อนุญาต Rainbow แค่ 2 จุดเท่านั้น (Trending content avatar ของ Home, Feed-mode indicator) ห้ามมีจุดที่ 3 จนกว่า Founder จะอนุมัติเพิ่ม | ใช้ลูกศรขึ้น + ตัวเลขอันดับสี cyan ธรรมดาแทน ไม่ใช้ rainbow |
| หน้าจอเต็มจอที่มี WYNOS logo + search icon + bell icon ที่ AppBar ของ "CLUB" | ⚠️ ขัดกับ WYN-024 ที่เพิ่งลบ top row (logo/search/bell) ออกจาก Home ไปแล้ว (Home เริ่มด้วย ClubSection ทันที) และ Search/Notification เป็น Bottom Nav tab แยกอยู่แล้ว — ใส่ซ้ำจะเป็น navigation ซ้ำซ้อน | **ไม่แตะ Home** เลย — เนื้อหา hero/แนะนำ/กำลังฮิตทั้งหมดของภาพ ย้ายไปอยู่ใน `ExploreClubsScreen` (หน้าที่เปิดจากปุ่ม "สำรวจ Club" เดิม) แทน ใช้ AppBar ปกติแบบหน้าอื่น (back + title) ไม่มี logo/ไอคอนซ้ำ |
| การ์ด 2 คอลัมน์ในหน้า Explore | ⚠️ WYN-015 เดิมออกแบบเป็น list แถวเต็มความกว้าง | เปลี่ยนเป็น grid 2 คอลัมน์จริง (เหตุผลด้านล่าง Screen 1) — เป็นการปรับ layout ของ component เดิม ไม่ใช่ทิศทางสีใหม่ จึงอยู่ในอำนาจ AI Design ตัดสินใจเองได้ |
| Card มีขอบ/เงา/รูปภาพเต็มใบ | DS-005 กำหนด "card-less rows" | ตีความ "card-less" ตรงกับที่ DS-005 เขียนไว้จริง: **ห้าม Material `Card` (เงา elevation)** ไม่ใช่ห้ามมีภาพ/มุมมน — การ์ดใหม่ยังคงทึบ ไร้เงา ใช้แค่ `Container` + `BorderRadius` + `ClipRRect` เหมือน pattern เดิมของแอปทุกจุด |
| ทั้ง 3 หน้าจอในภาพเป็น Dark mode ล้วน | DS-001 ยืนยันซ้ำว่า Light/Dark ต้อง first-class เท่ากัน (`ThemeMode.system`, ไม่ dark-first) | สเปกนี้อธิบายด้วยภาพ dark (จุดที่ palette เปล่งประกายที่สุดตาม DS-009) แต่ทุก component **ต้องใช้ `Theme.of(context).colorScheme` เท่านั้น ห้าม hardcode สีดำ/ขาว** เพื่อให้ Light mode ได้ผลลัพธ์ที่ถูกต้องอัตโนมัติจาก scheme เดิม (ดูตาราง mapping ท้ายเอกสาร) |
| Headline ภาษาอังกฤษ "Find your people." | UI ของ Club ทั้งระบบเป็นภาษาไทยล้วน (ปุ่ม, label, ข้อความทุกจุด) | แปลเป็นไทยให้โทนเดียวกับ headline เดิม พร้อมคง pattern "ไฮไลต์คำท้ายด้วย Cyan" ตามที่ Founder ตั้งใจ |

---

## Screen 1: `ExploreClubsScreen` — redesign เต็มรูปแบบ (แทนที่เวอร์ชัน list ของ WYN-015)

Purpose: จุดค้นพบ Club หลักของแอป ยกระดับจาก list แถวเรียบ ให้รู้สึกพรีเมียม มีชีวิตชีวา ตรงกับ WYNOS identity ที่ Founder ต้องการ โดยพฤติกรรม/สิทธิ์เดิมทั้งหมดจาก WYN-015 ยังอยู่ครบ

Entry: เหมือนเดิม 100% — ปุ่ม "สำรวจ Club" ใน Home's `ClubSection` (`_openExploreClubs`) และ Screen 2 ของ WYN-015 (Club tab ใน `SearchScreen`) **ยังคง reuse `ClubDiscoveryCard`/query เดิมของหน้านี้ ไม่ต้องแก้** (Search tab ใช้ layout list เดิมต่อไป — grid ใหม่นี้เฉพาะหน้า Explore เต็มจอเท่านั้น เพราะ Search tab แชร์พื้นที่กับผลลัพธ์ User/Drop/Pop ที่เป็น list อยู่แล้ว การเปลี่ยนแค่ Club tab เป็น grid จะทำให้ scroll experience ของ Search ไม่สม่ำเสมอ)

### User Flow
1. ผู้ใช้แตะ "สำรวจ Club" จาก Home
2. เห็น hero block สั้นๆ + แถว "Club แนะนำสำหรับคุณ" + แถว "กำลังนิยม" (ranked) ก่อน
3. เลื่อนลงต่อเจอ search bar + filter chip หมวดหมู่ + grid 2 คอลัมน์ของ "กำลังนิยม"/"ใหม่ล่าสุด" (ตัวเดิมจาก WYN-015 เปลี่ยนแค่ layout)
4. แตะการ์ดใดก็ตาม → เปิด `ClubPage` เดิมทุกประการ (ไม่เปลี่ยน)

### Components

**AppBar**: `AppBar(title: Text('สำรวจ Club'))` มาตรฐานเดิม (back arrow อัตโนมัติ) — **ไม่เพิ่มไอคอน search/bell/logo ใดๆ** (เหตุผลในตาราง reconcile ด้านบน)

**1. Hero block** (ใหม่, สูงพอดีเนื้อหา ~150-170px, ไม่ scroll แยก อยู่ในสตรีมเดียวกับส่วนที่เหลือ):
- Eyebrow: `Text('CLUB')` ตัวเล็ก ตัวหนา ตัวพิมพ์ใหญ่ letter-spacing กว้าง สี `colorScheme.primary` (cyan)
- Headline 2 บรรทัด `headlineSmall` ตัวหนา: "เจอคอมมูนิตี้ที่ใช่สำหรับ" บรรทัดแรกสีปกติ (`onSurface`) + "คุณ" บรรทัดสอง/ท้ายประโยคสี `colorScheme.primary` (คง pattern "ไฮไลต์คำท้ายด้วย cyan" ตามภาพต้นฉบับที่ไฮไลต์คำว่า "people.")
- Subtitle: `bodyMedium` สี `onSurfaceVariant` 1-2 บรรทัด: "ร่วมคอมมูนิตี้ที่คุณสนใจ เชื่อมต่อกับคนที่คิดเหมือนกัน"
- กราฟิกประกอบ: **ไม่ใช้ illustration/ภาพ 3 มิติที่ต้องสร้าง asset ใหม่** (นอก scope ของ mobile UI ระบบ icon-based ปัจจุบัน และเสี่ยงเป็น "unnecessary decoration" ที่ brief เองก็บอกให้เลี่ยง) — ใช้ `Icon(Icons.groups_rounded)` ขนาด ~40px วางในวงกลม `radiusFull` พื้น `primaryContainer` มี `BoxShadow` สี cyan โปร่งแสงบางๆ รอบวง (glow ด้วยเงา ไม่ใช่ blur) วางชิดขวาของ headline แทนที่จะเป็น hero image เต็มความกว้าง — สัดส่วนพื้นที่ cyan/glow นี้เล็กมาก ไม่เกินกติกา "≤15% ของจอ" (DS-001 ข้อ 6) แน่นอน

**2. CTA row** (แถวปุ่มลัด, มีอยู่แล้วที่ Home แต่ Explore ไม่มี — เพิ่มเพื่อให้ครบ flow ตามภาพ, วางใต้ hero):
- "**+ สร้าง Club**" (`FilledButton.icon`, พื้น `colorScheme.primary`, ตัวหนังสือ/ไอคอน `colorScheme.onPrimary` — **นี่คือหนึ่งในจุดที่อนุญาตให้ Cyan เป็นพื้นเต็มปุ่มได้ตาม DS-001 ข้อ 6** "ใช้ได้กับ: ปุ่มหลัก") เปิด `CreateClubScreen` เดิมตรงๆ
- ไม่เพิ่มปุ่ม "สำรวจ Club" ซ้ำ (อยู่ในหน้านี้อยู่แล้ว ปุ่มซ้ำจะไม่มีความหมาย)

**3. แถว "Club แนะนำสำหรับคุณ"** (ใหม่, horizontal scroll, สูง ~210px):
- Header: `titleSmall` ตัวหนา "Club แนะนำสำหรับคุณ" (ไม่มี "ดูทั้งหมด" รอบนี้ เหมือน pattern ของแถว Trending ใน WYN-017 ที่ยังไม่มีหน้าเฉพาะ)
- Data: reuse `ClubRepository.fetchPopularClubs()` เดิม (query เดียวกับที่ Home's "Club แนะนำ" ใช้อยู่แล้ว) — ไม่มี query ใหม่
- การ์ด: widget ใหม่ `ClubRecommendedCard` (ดู Screen 2) กว้าง ~168px

**4. แถว "กำลังนิยม" (ranked)** (ใหม่, สูง ~190px):
- Header: `titleSmall` ตัวหนา "กำลังนิยม"
- Data: **reuse ผลลัพธ์เดียวกับแถว "กำลังนิยม" ของ section ด้านล่าง** (`fetchPopularClubs(category: _category)`) แค่ตัด 5 อันดับแรกมาแสดงเป็น ranked list แนวนอน — ไม่มี query ใหม่ ไม่มีนิยาม "trending" ใหม่ (ต่างจาก WYN-017's Home Trending ที่นิยามจาก like+comment 48 ชม. — อันนั้นเป็นเรื่อง content ไม่ใช่ club จึงไม่เกี่ยวกัน) เรียงตามจำนวนสมาชิกมาก→น้อยเหมือนที่ `fetchPopularClubs` ทำอยู่แล้ว
- แถว: widget ใหม่ `ClubRankedRow` (ดู Screen 3)

**5. Search + Category filter + Grid** (ของเดิมจาก WYN-015, เปลี่ยนแค่ layout):
- Search bar: **ใหม่ในรอบนี้** — `TextField` filled พื้น `surfaceContainer` มุมมน `radiusFull` ไอคอนแว่นขยายนำหน้า placeholder "ค้นหา Club หรือหมวดหมู่" กรอง client-side บนผลลัพธ์ที่โหลดมาแล้ว (ไม่เพิ่ม backend query ใหม่ — เหตุผล: หน้านี้โหลด "กำลังนิยม"+"ใหม่ล่าสุด" มาครบอยู่แล้วสูงสุด 20 รายการ/หมวด พอสำหรับ filter ฝั่ง client ไม่จำเป็นต้อง debounce query ใหม่แบบ Search tab ที่ scope กว้างกว่า)
- Category chips: **ของเดิมเป๊ะ** (`ChoiceChip` แถวเดียวกัน 10 ตัวเลือกรวม "ทั้งหมด") ไม่แก้ logic
- Section "กำลังนิยม"/"ใหม่ล่าสุด": โครงเดิม (label หัวข้อ + list) **เปลี่ยนจาก `Column` ของ `ClubDiscoveryCard` เต็มความกว้าง → `GridView` 2 คอลัมน์** ของการ์ดใหม่ (ดู Screen 4) — เหตุผลที่เปลี่ยนเป็น grid: หน้านี้เป็นหน้าเรียกดู (browse) ที่ผู้ใช้ scan เปรียบเทียบ Club จากภาพปกเป็นหลัก การ์ดรูปภาพแบบ grid ให้ความหนาแน่นของภาพต่อจอสูงกว่า list แถวเดียวที่เน้นข้อความ ตรงกับ mental model "เลือกจากภาพ" ที่ภาพของ Founder สื่อ — **Search tab (Screen 2 ของ WYN-015) ไม่เปลี่ยน** ยังใช้ `ClubDiscoveryCard` แถวเดิมตามเหตุผลด้านบน

### Interactions
เหมือน WYN-015 ทุกประการ: แตะการ์ดใดก็ตาม (แนะนำ/กำลังนิยม-ranked/grid) → `ClubPage`, แตะ category chip → กรองทั้งแถว "กำลังนิยม" ranked และ 2 section ด้านล่างพร้อมกัน (ใช้ `_category` state เดียวกัน — แถวแนะนำไม่กรองตาม category เพราะเป็น personalized ไม่ใช่ browse-by-category)

### States
- Loading: `CircularProgressIndicator` กลางจอเหมือนเดิม (รวม fetch ครั้งเดียวทั้งหน้า ไม่แยก loading ต่อ section เพื่อลด layout shift)
- Empty (หลัง filter แล้วไม่เจอ): ข้อความเดิม "ยังไม่มี Club ในหมวดนี้" ต่อ section, แถวแนะนำ/กำลังนิยม (ranked) ถ้าไม่มีข้อมูล → `SizedBox.shrink()` ทั้งแถว (mirror pattern เดิมของ WYN-017 Trending row)
- Search bar ไม่มีผลลัพธ์ตรงคำค้น: ข้อความ "ไม่พบ Club ที่ตรงกับ \"…\"" ใต้ grid

### Responsive Behavior
Grid 2 คอลัมน์คงที่ทุกความกว้างมือถือ (360-430px ตาม DS-008) — การ์ดใช้ `AspectRatio` ไม่ fixed height เพื่อไม่ overflow ตอน textScale ใหญ่ (ดู Accessibility)

### Accessibility
- Hero/CTA/แถวแนะนำ/แถว ranked/grid ทุกจุดต้องผ่าน textScale 130% โดยไม่ overflow (ตาม DS-008) — headline ใช้ `maxLines` + `overflow: ellipsis` ถ้าจำเป็น
- การ์ดทุกแบบ (`ClubRecommendedCard`/`ClubRankedRow`/grid tile) มี `Semantics` label รวมเดียวเหมือน `ClubDiscoveryCard` เดิม: "ชื่อ Club, หมวดหมู่, จำนวนสมาชิก คน"
- Search bar มี `Semantics(label: 'ค้นหา Club')`

### Design Rules
- ทุกสีอ้างอิง `Theme.of(context).colorScheme` เท่านั้น ห้าม hardcode `Colors.black`/`WynColors.bgDark` ตรงๆ ในไฟล์นี้ (ให้ Light mode ทำงานถูกต้องอัตโนมัติ)
- ห้ามใช้ `BackdropFilter`/`ImageFilter.blur`/opacity ต่ำกว่า 1.0 บนพื้นผิวใดๆ (ตรวจสอบตอน code review — นี่คือกติกา "ห้าม Liquid Glass")
- Glow effect ใช้ `BoxShadow(color: colorScheme.primary.withValues(alpha: 0.25...0.4), blurRadius: 16-24, spreadRadius: 0)` เท่านั้น — เป็นเงาสีเรืองแสง ไม่ใช่พื้นผิวโปร่งแสง

---

## Screen 2: `ClubRecommendedCard` (widget ใหม่)

Purpose: การ์ด Club แนะนำ ที่มีรูปภาพนำ ใช้เฉพาะแถว "Club แนะนำสำหรับคุณ" ของ `ExploreClubsScreen`

Components:
- กว้างคงที่ 168px, `ClipRRect(borderRadius: WynSpacing.radiusMd)` ห่อทั้งใบ, พื้นหลัง `colorScheme.surfaceContainer` (ทึบ ไม่มีเงา `Card`)
- Cover: `AspectRatio(16/9)` ใช้ `club.coverUrl` (field มีอยู่แล้วในโมเดล `Club` แต่ยังไม่เคยถูกใช้ในการ์ดไหนเลยตอนนี้ — เพิ่มการใช้งานจริงครั้งแรก) ถ้าไม่มีรูป fallback เป็นพื้น `colorScheme.primaryContainer` + ตัวอักษรแรกของชื่อ Club ตรงกลาง (mirror fallback pattern ของ `CircleAvatar` เดิม)
- Avatar `club.iconUrl` วงกลม 40px ซ้อนขอบล่างซ้ายของ Cover ยื่นออกมาครึ่งหนึ่ง (border 2px สี `surface` กันกลืนพื้นหลัง) — mirror แนวคิด cover+avatar ซ้อนของ `ClubPage` header (WYN-014 Screen 3) ทำในสเกลย่อส่วน
- ไอคอนเมนู `⋮` (`Icons.more_vert`, 20px) มุมขวาบนของ Cover บนพื้น scrim ครึ่งวงกลมโปร่งแสงเข้ม (ใช้ `WynColors.imageScrim` ที่มีอยู่แล้วในระบบ ไม่ใช่ token ใหม่) — **รอบนี้เปิดแค่ตัวเลือก "รายงาน Club" เท่านั้น** (mirror ของ ClubPage's More menu สำหรับคนที่ยังไม่ได้เข้าร่วม)
- ใต้ Cover: ชื่อ Club (`titleSmall` ตัวหนา 1 บรรทัด ellipsis), แถวย่อย category chip เล็ก + "· N สมาชิก" (mirror `ClubDiscoveryCard` เดิมเป๊ะ)
- ปุ่ม Join เต็มความกว้างการ์ด ด้านล่างสุด: **reuse ปุ่ม Join 3 สถานะเดิมจาก `ClubPage`** (เข้าร่วม/เข้าร่วมแล้ว/รออนุมัติ) ย่อสเกลลงเป็น `FilledButton.tonal` ขนาดเล็ก (height 32) — กด Join ตรงจากการ์ดได้เลยไม่ต้องเปิด `ClubPage` ก่อน (เพิ่ม `onJoin` callback ให้ widget, เรียก `ClubRepository.joinClub`/`leaveClub` เดิมตรงๆ ไม่มี logic ใหม่)

Interactions: แตะพื้นที่การ์ด (นอกปุ่ม Join/เมนู) → เปิด `ClubPage`, แตะปุ่ม Join → toggle สถานะเดิม, แตะเมนู `⋮` → bottom sheet "รายงาน Club"

States: Loading ของปุ่ม Join ระหว่างเรียก API → `CircularProgressIndicator` ขนาดเล็กแทนตัวหนังสือปุ่มชั่วคราว (mirror pattern ปุ่ม Join ของ `ClubPage` เดิม)

Accessibility: `Semantics` รวมทั้งใบ + ปุ่ม Join แยก `Semantics` label ตามสถานะ (mirror `ClubPage` เป๊ะ)

Design Rules: ไม่มี `BoxShadow`/elevation บนตัวการ์ด (คง "card-less" ของ DS-005 ในความหมายที่ถูกต้อง — ไร้เงา ไม่ใช่ไร้ภาพ) glow อนุญาตเฉพาะปุ่ม Join ตอน active state เท่านั้น (เงาบางๆ สี primary alpha ต่ำ)

---

## Screen 3: `ClubRankedRow` (widget ใหม่)

Purpose: แถวจัดอันดับ Club ยอดนิยม ใช้ในแถว "กำลังนิยม" (ranked) ของ `ExploreClubsScreen` เท่านั้น

Components: แถวแนวนอน กว้างคงที่ ~230px height 64px, ไม่มีพื้นหลัง/เงา (การ์ดโปร่งอยู่บนพื้นหน้าจอ):
- ตัวเลขอันดับ (1-5) `headlineSmall` ตัวหนา สี `colorScheme.primary` เมื่ออันดับ 1-3 / สี `onSurfaceVariant` เมื่ออันดับ 4-5 (ให้ top 3 เด่นกว่าแบบไม่ต้องใช้สีสถานะ/rainbow ใหม่)
- Avatar วงกลม 40px (`club.iconUrl`)
- ชื่อ Club (`bodyMedium` ตัวหนา 1 บรรทัด) + "N สมาชิก" (`labelSmall`, `onSurfaceVariant`) พร้อมไอคอนเทรนด์เล็ก `Icons.trending_up` สี `colorScheme.primary` ข้างจำนวนสมาชิก (แทนที่ rainbow/motion graphic ตามเหตุผลในตาราง reconcile — เทรนด์สื่อด้วยไอคอนศัพท์สากล ไม่ใช่ gradient ใหม่)
- ปุ่ม Join เล็ก (`OutlinedButton`, height 28) ชิดขวา — reuse สถานะเดิมเหมือน `ClubRecommendedCard`

Interactions/States/Accessibility: เหมือน `ClubRecommendedCard` ทุกประการ (reuse callback/label pattern เดียวกัน)

---

## Screen 4: Grid tile ของ `ClubDiscoveryCard` (ปรับ layout ไม่ใช่ widget ใหม่)

Purpose: ปรับ `ClubDiscoveryCard` เดิมให้มีตัวแปร layout สำหรับ grid (การ์ดแนวตั้ง) เพิ่มจากที่มีอยู่ (แถวแนวนอนเดิม) — **ใช้ widget เดียวกัน เพิ่ม parameter** ไม่สร้างไฟล์ใหม่ เพื่อคง "reuse widget เดิม 100%" ตาม Design Rule ของ WYN-015

Components: เพิ่ม `ClubDiscoveryCard({..., this.layout = ClubDiscoveryCardLayout.row})` — เมื่อ `layout == grid`:
- แนวตั้งแทนแนวนอน: Cover 4:3 ด้านบน (ใช้ `club.coverUrl`, fallback เหมือน `ClubRecommendedCard`) → ชื่อ Club + category chip เล็ก + "N สมาชิก" ด้านล่าง → ปุ่ม Join เต็มความกว้างการ์ดล่างสุด (ตัด description ทิ้งในโหมด grid เพราะพื้นที่แคบกว่า row — grid เน้นภาพ+ตัวเลขให้ scan เร็ว ไม่ใช่โหมดอ่านรายละเอียด)
- โหมด `row` เดิม **ไม่เปลี่ยนอะไรเลย** ยังใช้ในหน้า Search's Club tab เหมือนเดิม

Interactions/States/Accessibility: เหมือนเดิมทุกประการ ไม่ว่าโหมดไหน (`Semantics` label เดียวกัน, tap เปิด `ClubPage` เดียวกัน)

`GridView.builder` ของ `ExploreClubsScreen`'s 2 section: `crossAxisCount: 2`, `childAspectRatio` ~0.72 (ให้พอดีกับ cover 4:3 + text block + ปุ่ม), `mainAxisSpacing`/`crossAxisSpacing`: `WynSpacing.space3`

---

## Screen 5: `CreateClubScreen` — ปรับผิวเล็กน้อย (ไม่แตะโครงสร้าง)

Purpose: ตอบสนอง detail ในภาพของ Founder (ตัวนับตัวอักษร, ผิวมืด) โดยไม่แตะฟิลด์/logic เดิมของ WYN-014 เลย (fields เดิมตรงกับภาพของ Founder อยู่แล้วครบ: Cover, Icon, Name, Description, Category, Privacy, ปุ่ม Create)

Components ที่เพิ่ม:
- Name field: เพิ่ม `maxLength: 30` + `counterText` แสดง "N/30" (Flutter `TextField` มี built-in counter อยู่แล้วเมื่อกำหนด `maxLength` — ไม่ต้องเขียนเอง)
- Description field: เพิ่ม `maxLength: 150` + counter เดียวกัน
- Cover/Icon picker: เมื่อยังไม่เลือกรูป แสดงกรอบเส้นประ (`DashedBorder` หรือ `CustomPaint` ง่ายๆ) + ไอคอนกล้อง + ข้อความ "เพิ่มรูปปก (แนะนำ 16:9)" / "เพิ่มรูปโปรไฟล์" แทน placeholder icon เฉยๆ เดิม — ให้ affordance ชัดเจนขึ้นตามภาพ

Design Rules: ไม่เพิ่ม validation ใหม่นอกจากความยาวตัวอักษร (ปุ่ม "สร้าง Club" ยัง disable ตามเงื่อนไขเดิม: Name+Privacy ครบ)

---

## Screen 6: Bottom Nav "Drop" — ปรับผิวปุ่มให้เด่นขึ้นตามภาพ (ต่อยอด WYN-024)

Purpose: ภาพของ Founder วาดปุ่ม Drop เป็นวงกลม cyan เด่นชัดกว่าปุ่มอื่น ต่างจาก spec เดิมของ WYN-024 ที่เป็นแค่ไอคอน `add_circle_outline` เฉยๆ

Components: ห่อไอคอน Drop action ด้วย `Container` วงกลม 44px พื้น `colorScheme.primary` (cyan เต็มพื้นวงกลม, ไม่ใช่แค่ไอคอนสีเดียว) ไอคอน `Icons.add` สี `colorScheme.onPrimary` ตรงกลาง + `BoxShadow` glow บางๆ รอบวง (สเปกเดียวกับ hero graphic ใน Screen 1) — **ยังคงไม่มี selected state ค้าง** ตาม WYN-024 เดิม (glow/พื้นวงกลมนี้แสดงตลอดเวลา ไม่ใช่ตอน active เท่านั้น เพราะปุ่มนี้ไม่ใช่ tab)

Design Rules: อยู่ในสัดส่วนพื้นที่ cyan เล็กมาก (วงกลม 44px) ไม่ขัดกติกา ≤15% ของจอ — Semantics เดิมของ WYN-024 ("สร้าง Drop ใหม่") คงไว้ทั้งหมด

---

## ตาราง Mapping Light/Dark (ทุก component ข้างบน)

ไม่มี token ใหม่ — ทุกจุดอ้างอิงชื่อ semantic slot ของ `colorScheme` (`primary`/`onPrimary`/`surface`/`surfaceContainer`/`onSurface`/`onSurfaceVariant`/`outline`) Flutter จะ resolve เป็นค่าจริงให้เองตาม `WynColors.socialLightScheme`/`socialDarkScheme` ที่มีอยู่แล้ว — ภาพอ้างอิงของ Founder (พื้นดำ) คือผลลัพธ์ของ `socialDarkScheme` ที่มีอยู่แล้ววันนี้ ไม่ต้องรอ implement อะไรเพิ่มเพื่อให้ dark mode ตรงภาพ

## Handoff: AI Coding —

1. **ไม่แตะ schema/RLS ใดๆ** — `club.coverUrl` เป็น field ที่มีอยู่แล้วในตารางและโมเดล แค่ยังไม่เคยถูกใช้แสดงผลในการ์ดไหนเลย งานนี้เอามาใช้จริงเป็นครั้งแรกเท่านั้น
2. ไฟล์ใหม่: `app/lib/features/club/presentation/widgets/club_recommended_card.dart`, `club_ranked_row.dart`
3. ไฟล์แก้ไข: `explore_clubs_screen.dart` (เพิ่ม hero/CTA/แนะนำ/ranked, เปลี่ยน section ล่างเป็น `GridView`), `club_discovery_card.dart` (เพิ่ม `layout` enum parameter), `create_club_screen.dart` (counter + placeholder ผิว), `root_shell.dart` (ปุ่ม Drop วงกลม cyan)
4. **ไม่แตะ**: `club_section.dart`/`club_mini_card.dart` (Home ทั้งหมดคงเดิม, ผ่าน QA แล้วใน WYN-017), `club_page.dart`, `club_repository.dart` (query เดิมพอสำหรับทุก section ในนี้), Search tab ของ WYN-015
5. เขียน/แก้ widget test ของ `explore_clubs_screen_test.dart` (ถ้ามี) ให้ครอบคลุม: grid แสดงผลถูกต้อง, filter category ยังกรองครบทั้ง 3 ส่วน (แนะนำไม่กรอง), ปุ่ม Join บนการ์ดใหม่เรียก repository ถูกต้องและไม่ double-submit (mirror double-tap-safety pattern ที่ `ClubPage` มีอยู่แล้ว)
6. QA & Security ต้องตรวจ: ไม่มี `BackdropFilter`/blur ใดๆ หลุดเข้ามา (grep `ImageFilter`/`BackdropFilter` ในไฟล์ที่แก้ต้องไม่เจอ), Light mode สกรีนช็อตทุกหน้าที่แก้ต้องอ่านออกและไม่มีสี hardcode ผิดฝั่ง (เหมือนที่ DS-001 กำหนดให้ตรวจทุกงานสี), regression กับ Search tab's Club results (ต้องยังเป็น layout แถวเดิม ไม่ใช่ grid)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-6 ข้างต้น — งานนี้เป็น visual-refresh ล้วน ไม่มี requirement/acceptance criteria ระดับ Product ใหม่ (ไม่ต้องเปิด Product task แยก) เพราะไม่เปลี่ยนพฤติกรรม/สิทธิ์/ข้อมูลใดๆ จาก WYN-014/015/017 ที่อนุมัติแล้ว — อ้างอิง Acceptance Criteria ของงานนี้ที่ `.wyn/tasks/backlog/WYN-056-club-discovery-visual-refresh.md`
