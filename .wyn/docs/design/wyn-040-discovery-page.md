# Design Spec — WYN-040: Discovery Page

อ้างอิง Design System: `.wyn/docs/design/ds-001-color-system.md` (Cyan accent เท่านั้น ≤15% พื้นที่หน้าจอ, ห้าม Liquid Glass, ห้ามลอก Layout IG/TikTok/Threads), `.wyn/docs/design/ds-009-rainbow-accent.md` (Rainbow ใช้ได้แค่ 2 จุดเท่านั้นทั้งระบบ — ดูหัวข้อ "ความสอดคล้องกับ DS-009" ด้านล่าง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-040-discovery-page.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (reuse ตรงๆ ตามที่ Product ระบุ): `SearchScreen`/`TabBar` (WYN-009), `TrendingTile` (WYN-017), `HashtagText`/`HashtagFeedScreen`/`extractHashtags()` (WYN-020), `ClubMiniCard`/`fetchPopularClubs()` (WYN-017), 3-state Follow button + locked-persona pattern (WYN-039), `FollowListScreen` row layout (WYN-008/013)

## ทิศทางภาพรวม: Discovery = default state ของหน้า Search (ไม่แตะ Bottom Nav)

ตาม Product's Requirement 6 — `search_screen.dart` (WYN-009) ตอนนี้แสดง "Prompt" empty-state แยกต่อ tab (User/Drop/Pop) เมื่อยังไม่พิมพ์คำค้น เปลี่ยนเป็น: **เมื่อคำค้น (หลัง trim) สั้นกว่า 2 ตัวอักษร — เกณฑ์เดียวกับที่ debounce logic เดิมใช้ตัดสินใจไม่ยิง query อยู่แล้ว — ให้แสดง `DiscoveryView` แทน `TabBar`+`TabBarView` ทั้งชุด** ไม่ใช่แค่แทนที่ empty-state ข้างในแต่ละ tab เพราะ Discovery ไม่ได้จัดกลุ่มตาม User/Drop/Pop จึงไม่มีเหตุผลให้ TabBar ค้างอยู่ตอนนั้น — พอพิมพ์ครบ 2 ตัวอักษรขึ้นไป สลับกลับเป็น TabBar+TabBarView เดิมทันที (behavior การค้นหาเดิมของ WYN-009 ไม่เปลี่ยนแม้แต่บรรทัดเดียว)

`AppBar`/`TextField`/ปุ่ม clear ด้านบนคงเดิมทั้งหมดไม่ว่าจะอยู่ state ไหน — สลับเฉพาะเนื้อหาด้านล่าง TabBar

---

## Screen 1: `DiscoveryView` (widget ใหม่ แสดงใน `SearchScreen` เมื่อคำค้นว่าง/สั้นกว่า 2 ตัวอักษร)

Purpose: รวม 5 ส่วนของ "สิ่งที่กำลังเป็นที่นิยม" ไว้หน้าเดียว ให้ผู้ใช้เลื่อนดูได้โดยไม่ต้องพิมพ์คำค้น

User Flow: เปิดหน้า Search (auto-focus ช่องพิมพ์ตาม WYN-009 เดิม) → ยังไม่พิมพ์อะไร → เห็น `DiscoveryView` ทันที → เลื่อนดู 5 ส่วนตามลำดับ → แตะรายการใดๆ → เปิดหน้าปลายทางตามประเภท (Drop/Hashtag feed/Profile/Club) → กลับมาหน้า Search ยังอยู่ที่ Discovery เดิม (ไม่ reset scroll position ถ้าทำได้)

Components (บนลงล่าง, ทุก section เป็น `SliverToBoxAdapter`/`Column` ต่อกันใน `ListView` เดียว — ไม่ paginate ข้ามส่วน):

### 1. Trending Now
- Header: `Text('กำลังนิยม')` style เดียวกับ `ClubSection`'s "CLUB" header (WYN-017) — **ไม่มีปุ่ม "ดูเพิ่มเติม"** (ดู Non-goals ด้านล่าง)
- Grid 3 คอลัมน์ reuse `TrendingTile` ตรงๆ (WYN-017, widget เดิม 100% ไม่แก้ไข) — data: `HomeRepository.fetchTrending()` เดิม แต่ Coding ต้องเพิ่ม parameter `limit` ให้ปรับได้ (ปัจจุบัน hardcode top 10 ผ่าน `_trendingResultLimit`) แล้วเรียกด้วย limit ~30 ในบริบทนี้ (ยังคง `_trendingCandidateLimit`/`_trendingWindow` เดิมไว้ทั้งหมด แก้แค่ตัวเลขผลลัพธ์สุดท้าย)
- Tap → เหมือนเดิมทุกประการ (`_openDrop`/`_openPop` pattern)

### 2. Trending Hashtags (รวม "Trending Topics" ตามที่ Product ตัดสินใจไว้แล้ว — ไม่มี taxonomy แยก)
- Header: `Text('แฮชแท็กกำลังนิยม')`
- `Wrap` ของ `Chip`/`ActionChip` แสดง `#tag` (ไม่ต้องมีตัวเลขนับกำกับในรอบนี้ — ความถี่ใช้แค่จัดอันดับ ไม่ต้องโชว์ตัวเลขให้ผู้ใช้เห็น เพื่อลดความซับซ้อนของ UI) เรียงจากความถี่มาก→น้อย top 20
- สี Chip: neutral (soft gray พื้น, ตัวหนังสือปกติ) **ไม่ใช้ Cyan เป็นพื้น chip** (ผิดกติกา DS-001 ข้อ 6 "ห้ามพื้นหลังขนาดใหญ่ต่อเนื่อง" ถ้ามี 20 chip ติดกันเป็น Cyan ทั้งหมดจะเกิน 15% พื้นที่จริง) — ใช้ตัวหนังสือ `#tag` เป็น Cyan (ตาม `HashtagText` widget เดิมของ WYN-020 ที่ style `#tag` เป็น `colorScheme.primary` อยู่แล้ว) บนพื้น chip เทาอ่อนเป็น container เฉยๆ
- Data: fetch candidate window เดียวกับ `fetchTrending()` (reuse `_trendingWindow`/`_trendingCandidateLimit` เดิม ผ่าน method ใหม่ใน `HomeRepository` หรือ repo ใหม่เล็กๆ ให้ Coding ตัดสินใจ) → รัน `extractHashtags()` (WYN-020, function เดิม) ต่อ Drop → นับความถี่ → เรียง → top 20
- Tap chip → `HashtagFeedScreen(tag: ...)` (WYN-020 เดิม ไม่สร้างหน้าใหม่)

### 3. Rising (บัญชีที่กำลังเติบโต)
- Header: `Text('กำลังเติบโต')`
- Horizontal `ListView` การ์ดแนวตั้งเล็ก (avatar 56px + display name 1 บรรทัด truncate + @username 1 บรรทัด truncate) reuse ขนาด avatar เดียวกับ `TrendingTile`'s thumbnail footprint เพื่อความสม่ำเสมอทางสายตากับ section ด้านบน — **ไม่มี rainbow ring** (ดูหัวข้อ "ความสอดคล้องกับ DS-009")
- Indicator การเติบโต: ไอคอน `Icons.trending_up` เล็ก (16px, สีเขียว success ตาม DS-001 ข้อ 4 "สีสถานะไม่ประดิษฐ์ใหม่") วางข้าง username **ไม่มีตัวเลขกำกับ** (ไม่โชว์ "+N ผู้ติดตามใหม่" ตรงๆ เพราะเป็นข้อมูลที่ RPC คืนมาเพื่อจัดอันดับเท่านั้น ไม่ใช่ metric สาธารณะที่ต้อง expose — ป้องกันไม่ให้กลายเป็น metric ให้คนพยายาม gaming ตัวเลขที่โชว์ผ่าน UI ตรงๆ)
- ปุ่ม Follow ใต้การ์ด reuse 3-state button เดิมจาก WYN-039 ตรงๆ (ติดตาม/ขอติดตามแล้ว/กำลังติดตาม) ขนาดเล็กลง (compact `OutlinedButton`) ให้พอดีความกว้างการ์ด
- Tap การ์ด (นอกปุ่ม Follow) → `ViewProfileScreen(userId: ...)`

### 4. Suggested Users
- Header: `Text('แนะนำให้ติดตาม')`
- **reuse โครงสร้างแถวของ `FollowListScreen` ตรงๆ** เหมือนที่ WYN-009's User results tab ทำ (avatar 20px + ชื่อ/@username สองบรรทัด + ทั้งแถวเป็น `InkWell`) — ต่างแค่ปุ่ม Follow 3-state ต่อท้ายแถว (WYN-009's User results tab ไม่มีปุ่ม follow ในแถว ต้องกดเข้าไปก่อน — Discovery นี้เพิ่มปุ่มเข้าไปในแถวเพื่อลด friction เพราะ intent ของผู้ใช้ตรงนี้คือ "อยากติดตามคนใหม่" อยู่แล้ว)
- แสดงเป็น `Column` แนวตั้ง (ไม่ horizontal scroll เหมือน section อื่น) สูงสุด 10 แถว
- Tap แถว (นอกปุ่ม Follow) → `ViewProfileScreen(userId: ...)`

### 5. Suggested Clubs
- Header: `Text('Club แนะนำ')` (label เดียวกับที่ WYN-017 ใช้ใน Home's Recommended Clubs row เป๊ะ เพื่อความสม่ำเสมอ)
- Horizontal `ListView` reuse `ClubMiniCard` ตรงๆ (WYN-017, widget เดิม 100%) — data: `ClubRepository.fetchPopularClubs()` เดิมตรงๆ ไม่มี logic ใหม่
- Tap → `ClubPage` (เหมือน WYN-017 เดิม)

Loading/Empty/Error ต่อ section: **ทุก section ใช้ fail-safe pattern เดียวกับ `ClubSection` ของ WYN-017** — `FutureBuilder` อิสระต่อ section, โหลด/error → section นั้นยุบเหลือ `SizedBox.shrink()` (ไม่บล็อก section อื่น), ผลลัพธ์ว่างจริง → ข้อความเล็ก "ยังไม่มี{ชื่อ section}ตอนนี้" แทนที่จะซ่อนทั้ง section ไปเลย (ให้ผู้ใช้รู้ว่า section นี้มีอยู่ ไม่ใช่ bug)

---

## Interactions

- ทุก section ยิง fetch พร้อมกันตอนเปิด `DiscoveryView` (ไม่ lazy-load ตาม scroll ในรอบนี้ — ดู Non-goals)
- ปุ่ม Follow ใน Rising/Suggested Users เป็น optimistic update เหมือน WYN-039 เดิมทุกประการ (เปลี่ยน label ทันที, revert ถ้า error)
- ไม่มี pull-to-refresh ในรอบนี้ (สอดคล้องกับ non-goal เดิมของ Hashtag Feed ที่เป็น bounded fetch เดียวกัน — ปิดหน้าแล้วเปิดใหม่คือวิธี refresh)

## States

- Query ว่าง/สั้นกว่า 2 ตัวอักษร: `DiscoveryView`
- Query ≥2 ตัวอักษร: `TabBar`+`TabBarView` เดิมของ WYN-009 (ไม่เปลี่ยน)
- Discovery แต่ละ section: Loading (skeleton/shrink ระหว่างรอ) → Data / Empty ("ยังไม่มี...ตอนนี้") / Error (shrink เงียบๆ เหมือน `ClubSection`)

## Responsive Behavior

- Grid 3 คอลัมน์ของ Trending Now ปรับตาม `_gridEmptyText`/`DropGridTile` breakpoint เดิมที่มีอยู่แล้วทั้งระบบ (ไม่มี breakpoint ใหม่)
- Horizontal `ListView` ของ Rising/Suggested Clubs ใช้ physics เดียวกับ `ClubSection`'s club row เดิม

## Accessibility

- ทุกแถว/การ์ดที่กดได้มี `Semantics(label: ..., button: true)` ระบุชื่อผู้ใช้/Club/hashtag ตามเนื้อหาจริง (mirror pattern เดิมของ `FollowListScreen`/`ClubMiniCard`)
- Header แต่ละ section เป็น `Semantics(header: true)` ให้ screen reader ประกาศเปลี่ยน section ชัดเจน
- ไอคอน `trending_up` ของ Rising มี `Semantics(label: 'บัญชีนี้กำลังเติบโต')` ประกอบ (ไม่สื่อความหมายด้วย icon อย่างเดียว ตาม DS-001 ข้อ 5)

## ความสอดคล้องกับ DS-009 (Rainbow Accent — ล็อกไว้แค่ 2 จุดทั้งระบบ)

DS-009 ระบุชัดว่า Rainbow gradient ใช้ได้เฉพาะ (1) Trending avatar ring ใน `TrendingTile` และ (2) active feed-mode indicator ใน Home **"ไม่มีจุดที่สาม จนกว่าจะมีคำสั่งเพิ่มเติมจาก Founder"** — Discovery page นี้:
- **Trending Now section**: reuse `TrendingTile` widget เดิม 100% (ไม่ fork/copy โค้ด) ซึ่งมี ring อยู่แล้วในตัว widget เอง — ถือเป็นการใช้ "จุดที่ 1" เดิมซ้ำในตำแหน่งที่สอง ไม่ใช่จุดใหม่ เพราะเป็น component เดียวกันที่ผูกความหมาย "trending" เดิมทุกประการ ไม่ได้ตีความใหม่
- **Rising/Suggested Users/Suggested Clubs**: **ห้ามใส่ rainbow ring หรือ gradient ใดๆ** แม้จะรู้สึกว่า "น่าจะเข้าธีมกัน" — นี่คือ concept ใหม่ (การเติบโตของบัญชี ไม่ใช่ trending content) การใส่ rainbow ที่นี่จะกลายเป็นจุดที่ 3 ทันที ซึ่งต้องขออนุมัติ Founder ก่อน — ถ้า Founder ต้องการ visual accent แยกสำหรับ Rising ในอนาคต ให้เสนอเป็น design proposal ใหม่แยกต่างหาก ไม่ใช่ทำเงียบๆ ในรอบนี้

## Design Rules

- Section header ทั้งหมดใช้ style เดียวกับ `ClubSection`'s "CLUB" header (WYN-017) เพื่อความสม่ำเสมอ ไม่ประดิษฐ์ typography ใหม่
- Cyan ใช้เฉพาะ: ตัวหนังสือ `#tag` (ผ่าน `HashtagText`/pattern เดิม), ปุ่ม Follow ที่ active state (ตาม WYN-039/DS-001 เดิม) — ไม่ใช้เป็นพื้น chip/การ์ดขนาดใหญ่
- ไม่มี Liquid Glass/blur ใดๆ ในทุก section (พื้นผิวทึบทั้งหมดตาม DS-001)

## Non-goals รอบนี้

- **ไม่มี "ดูเพิ่มเติม"/pagination แยกต่อ section** — ทุก section เป็น bounded single fetch (Trending Now top ~30, Hashtags top 20, Rising/Suggested Users/Suggested Clubs top 10) เหมือน precedent ของ WYN-017 ("ไม่มีหน้า Trending แยกรอบนี้")/WYN-020 ("single bounded fetch, ไม่มี infinite scroll") — ถ้าต้องขยายเป็นหน้าเต็มแยกต่อ section ในอนาคต ให้เป็น task ใหม่
- **ไม่มี personalization/ML ใดๆ** ใน Suggested Users/Clubs (ตาม Product's v1 scope — เรียงจาก follower/member count เท่านั้น)
- **ไม่มี pull-to-refresh** (ดู Interactions ด้านบน)
- **ไม่แตะ Bottom Nav** (WYN-024 ล็อกแล้ว)

---

## Data Layer — สิ่งที่ต้องสร้างใหม่ (สำหรับ AI Coding)

**SQL (SECURITY DEFINER RPC ใหม่ 2 ตัว — ต้องเป็น bulk-ranking function เดียวจบ ไม่ใช่ N+1 query ต่อ profile เพราะต้องจัดอันดับ candidate จำนวนมาก)**:

1. `rising_profiles(p_limit int default 10, p_days int default 7, p_min_followers int default 5)` — คำนวณจำนวน follower ใหม่ต่อ `following_id` จาก `follows` ที่ `created_at >= now() - (p_days || ' days')::interval` จัดกลุ่ม/นับ/เรียงจากมาก→น้อยทั้งหมดในฟังก์ชันเดียว (ไม่ query แยกทีละ candidate), exclude: `auth.uid()` เอง, บัญชีที่ `auth.uid()` follow อยู่แล้ว (`not exists` บน `follows` ที่ตัวเองเป็น follower), คู่ที่ `internal.is_blocked_either_way(auth.uid(), following_id)`, และ filter `p_min_followers` ด้วย `follower_count()` (RPC เดิมจาก WYN-039) หรือ subquery `count(*)` เทียบเท่า — คืน `table(profile_id uuid)` เท่านั้น (ไม่คืนตัวเลข follower ใหม่ให้ client เห็น ตามที่ระบุไว้ใน Screen 1 ส่วน Rising ด้านบน — เหตุผล anti-gaming) — **ต้องเป็น SECURITY DEFINER** (มิเรอร์เหตุผลเดียวกับ `follower_count()`/`internal.can_view_author_content()` ของ WYN-039 — ถ้าไม่ใช่ SECURITY DEFINER จะโดน RLS ของ `follows` บล็อกไม่ให้เห็น edge ของบุคคลที่สาม คืนผลว่างเปล่าเงียบๆ)
2. `suggested_users(p_limit int default 10)` — เรียง candidate ทั้งหมด (exclude self/already-followed/blocked/muted — reuse `internal.is_blocked_either_way`, mute check ตาม WYN-028 เดิม) ด้วย follower count มาก→น้อย คำนวณในฟังก์ชันเดียว (ไม่เรียก `follower_count()` แยกทีละคนจาก client) คืน `table(profile_id uuid)` — SECURITY DEFINER ด้วยเหตุผลเดียวกัน (ต้องอ่านข้าม `follows`/`mutes` ของคนอื่น)

ทั้งสอง RPC คืนแค่ `profile_id` (ไม่คืน field อื่น) — ฝั่ง Flutter join กับ `ProfileRepository` เดิมเพื่อดึง avatar/display name/username/is_private ตามปกติ (ไม่ duplicate logic การแปลง Profile)

**Flutter**:
- `DiscoveryRepository` ใหม่ (`app/lib/features/search/data/discovery_repository.dart` หรือตำแหน่งเทียบเท่า) รวม method: `fetchTrendingNow({limit})` (wrap `HomeRepository.fetchTrending` เดิมหรือย้าย logic มาไว้ที่นี่แล้วให้ `HomeRepository` เรียกใช้แทน — ให้ Coding เลือกทางที่ diff เล็กสุด), `fetchTrendingHashtags({limit})`, `fetchRisingProfiles({limit})` (เรียก RPC `rising_profiles` แล้ว join `ProfileRepository`), `fetchSuggestedUsers({limit})` (เรียก RPC `suggested_users` แล้ว join `ProfileRepository`)
- `DiscoveryView` widget ใหม่ ใช้ 5 section ตาม Screen 1 — วาง import ที่ `SearchScreen` เรียกใช้แทน tab content เมื่อ query สั้นกว่า 2 ตัวอักษร

Handoff: AI Coding —
1. แก้ `SearchScreen` (WYN-009): แทรก state ใหม่ (query สั้นกว่า 2 ตัวอักษร → `DiscoveryView`) — เกณฑ์ความยาวใช้ค่าเดียวกับ debounce logic เดิม (`>= 2` หลัง trim) ไม่สร้าง threshold ใหม่แยก
2. สร้าง SQL migration ต่อท้ายส่วนล่าสุดของ `supabase/schema.sql`: RPC `rising_profiles()`/`suggested_users()` ตามสเปกข้างบน (SECURITY DEFINER ทั้งคู่) — เขียน SQL regression test ใหม่ (`supabase/tests/wyn_040_discovery_test.sh` มิเรอร์ harness เดิม) ครอบ: exclude self/followed/blocked/muted ถูกต้อง, third-party เห็นผลลัพธ์ได้แม้ `follows` RLS จำกัดอยู่ (พิสูจน์ SECURITY DEFINER ทำงานถูกจุด), `p_min_followers` กรองถูกต้อง, ไม่มี raw follower-growth number รั่วออกมาทาง RPC อื่นใด
3. เพิ่ม `HomeRepository.fetchTrending()` parameter `limit` (แก้ signature เดิม เพิ่ม optional param มี default เท่าเดิม — ไม่กระทบ caller เดิมใน Home)
4. สร้าง `DiscoveryRepository`/`DiscoveryView` ตามสเปกข้างบน — reuse `TrendingTile`/`ClubMiniCard`/`HashtagText`/`extractHashtags()`/3-state Follow button/`FollowListScreen` row widget ตรงๆ ตามที่ระบุ ไม่ fork โค้ดใหม่ถ้า widget เดิม parameterize พออยู่แล้ว
5. เขียน regression test ครอบ: query สั้นกว่า 2 ตัวอักษรแสดง Discovery/≥2 ตัวอักษรสลับกลับ TabBar เดิมถูกต้อง, แต่ละ section fail-safe ไม่บล็อกกัน, ปุ่ม Follow 3-state ทำงานถูกต้องใน Rising/Suggested Users, tap แต่ละ section นำทางถูกหน้า
6. ต้อง QA & Security ตรวจสอบก่อนอนุมัติ — เน้นตรวจ RPC ใหม่ 2 ตัวว่าไม่รั่ว raw follow-edge/follower-growth number ออกมาทางไหน (ตรงกับ Risk ที่ Product ระบุไว้)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1 + Data Layer ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-040-discovery-page.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
