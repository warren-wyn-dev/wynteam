# Design Spec — WYN-028: WYN Trending Top 1-10 (ใน Search) + Recent Searches

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` + `.wyn/docs/design/ds-001-color-system.md` (Cyan primary, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok/Threads)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-028-trending-top10-search.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (ต้อง reuse):
- `HomeRepository.fetchTrending()` (WYN-017, `app/lib/features/home/data/home_repository.dart`) — นิยาม "Trending window" เดียวที่มีอยู่จริงในระบบ (48 ชั่วโมง, bounded candidate limit, sort client-side, take top N) พร้อม fail-safe `FutureBuilder` pattern ("a failed/slow Trending fetch must never block the main feed underneath it")
- `core/text_utils.dart`'s `hashtagPattern`/`extractHashtags()` (WYN-020) — tokenizer เดียวที่ใช้ทั่วทั้งแอป
- `app/lib/features/pop/data/pop_mute_preference.dart` (WYN-006) — pattern การเก็บ local preference ด้วย `shared_preferences` (top-level function, ไม่ใช่ class, const key เดียว)
- `HashtagFeedScreen` (WYN-020) — ปลายทางที่แตะ hashtag แล้วต้องเปิด
- `SearchScreen`/`SearchStateMessage`/`SearchUserResultsTab` ฯลฯ (WYN-009/015) — โครงสร้างหน้า Search ปัจจุบัน

---

## ข้อค้นพบสำคัญก่อนออกแบบ (ต้องอ่านก่อน Handoff ไป Coding)

Product spec R1 เขียนว่า "reuse query เดิมของ Hashtag Feed's Trending tab ตรงๆ ไม่สร้าง logic ใหม่ซ้ำ" — หลังอ่านโค้ดจริงของ `HashtagFeedScreen._sortedEntries` (WYN-020) พบว่า **ไม่มี query "จัดอันดับ hashtag ข้ามทั้งระบบ" อยู่จริงให้ reuse ตรงๆ**:

- `HashtagFeedScreen`'s Trending tab ทำงานแค่: รับ tag ที่รู้อยู่แล้ว (จากการแตะ) → ดึงโพสต์ที่มี tag นั้น (หน้าเดียว, page 0) → เรียง**โพสต์ที่ดึงมาแล้ว**ตาม `likeCount + commentCount` — เป็นการเรียง "โพสต์ภายใน 1 hashtag ที่รู้อยู่แล้ว" ไม่ใช่การนับว่า "hashtag ไหนถูกใช้บ่อยที่สุด" ข้ามทั้งระบบ
- ไม่มี time window ด้วยซ้ำ (WYN-020's R3 ตั้งใจจะอ้างอิง window ของ WYN-017 แต่โค้ดจริงไม่ได้ implement — ยืนยันจาก `.wyn/docs/design/wyn-020-hashtag-system.md`: "Trending = merged results sorted by likeCount + commentCount desc" ไม่มี `since`/window ใดๆ)

**สิ่งที่ reuse ได้จริงและตั้งใจ reuse ในสเปกนี้** (ไม่ใช่คิด logic ใหม่ทั้งหมด แค่ประกอบจากของที่มีอยู่แล้ว):
1. Tokenizer เดียวกันเป๊ะ — `extractHashtags()` (ไม่มี regex ที่สอง)
2. นิยาม "ช่วงเวลาสั้น" เดียวกับ Trending ของทั้งแอป — ยืม `HomeRepository._trendingWindow` (48 ชั่วโมง) เพราะเป็น window เดียวที่มีอยู่จริงในระบบและถูกอ้างชื่อไว้แล้วโดย WYN-020's spec เอง (แม้จะไม่ได้ implement จริง)
3. Pattern "bounded candidate fetch → rank client-side" เดียวกับ `HomeRepository.fetchTrending()`/`DropRepository.fetchRankedFeed()` — เพราะ PostgREST order() ไม่ได้กับ computed expression/aggregate นับ hashtag ข้ามแถว เป็นข้อจำกัดเดียวกับที่ทั้งสองจุดนั้นเจอมาแล้ว ไม่ใช่ข้อจำกัดใหม่
4. RLS-scoped visibility เดียวกับที่ `ClubPostRepository.searchByContent` พึ่งอยู่แล้ว (ไม่ bypass อะไรใหม่)

สิ่งที่**ต้องเขียนใหม่จริง** (แต่เล็กและ additive ล้วนๆ ไม่แก้โค้ดเดิม): repository method ใหม่ที่ดึง caption/content ล่าสุดแบบเบา (ไม่ full row) แล้วนับความถี่ hashtag — ดู "Data & Query Design" ด้านล่าง

บันทึกเหตุผลนี้ไว้ใน Design Rules ด้วย เพื่อไม่ให้ QA ตั้งคำถามว่าทำไมไม่ literally เรียก `HashtagFeedScreen`'s ฟังก์ชันเดิม

---

## Screen: `SearchScreen` — Empty-query state ใหม่ (ต่อยอด WYN-009)

Purpose: ให้ผู้ใช้ที่เปิด Search แต่ยังไม่พิมพ์อะไร มีทางเลือก discover เนื้อหา (Trending hashtag) หรือค้นหาซ้ำเร็วๆ (Recent Searches) แทนที่จะเห็นแค่ prompt ว่างๆ 4 อันซ้ำกันเหมือนตอนนี้ (`SearchStateMessage` ซ้ำใน 4 tab)

### User Flow

1. แตะ search bar จาก Home → เปิด `SearchScreen`, auto-focus, ยังไม่พิมพ์อะไร
2. **แทนที่จะเห็น `TabBar` + 4 tab ว่างเปล่า** ผู้ใช้เห็นหน้าเดียว scroll ได้ ประกอบด้วย (ตามลำดับบนลงล่าง):
   - Recent Searches (แสดงเฉพาะมีประวัติ — chip แถวเดียว/หลายแถวแบบ wrap)
   - WYN TRENDING — hashtag Top 10 (แสดงเสมอ แม้ว่างก็มี empty state ของตัวเอง)
3. ผู้ใช้มี 3 ทางเลือก จากหน้านี้:
   - แตะ hashtag ใน WYN TRENDING → เปิด `HashtagFeedScreen(tag: ...)` ตรงๆ (ไม่บันทึกลง Recent Searches — คนละ concept กับการพิมพ์คำค้น)
   - แตะ chip ใน Recent Searches → เติมคำค้นนั้นลง search box และรันค้นหาทันที (ข้าม debounce เพราะเป็นคำที่สมบูรณ์อยู่แล้ว) → สลับไปแสดง `TabBar`/`TabBarView` ปกติของ WYN-009
   - พิมพ์คำค้นเอง (>=2 ตัวอักษร, รอ debounce 400ms ตามเดิม) → สลับไปแสดง `TabBar`/`TabBarView` ปกติเช่นกัน
4. เมื่อ `_query` ไม่ว่างแล้ว (ไม่ว่าจากพิมพ์เองหรือแตะ Recent Search chip) — พฤติกรรมที่เหลือทั้งหมดเหมือน WYN-009 เดิมทุกประการ (TabBar 4 tab User/Drop/Pop/Club, debounce, empty states เดิม) ไม่แตะของเดิม
5. เมื่อผู้ใช้แตะผลลัพธ์จริงจาก tab ใดก็ตาม (User/Drop/Pop/Club) ระหว่างมี query อยู่ → คำค้นปัจจุบัน (`_query`) ถูกบันทึกลง Recent Searches (dedupe, ล่าสุดขึ้นบนสุด, จำกัด 10) ก่อนเปิดหน้าเป้าหมาย
6. ลบคำค้นจนว่าง (`_clear()` หรือลบทีละตัวจนหมด) → กลับไปหน้า Recent Searches + WYN TRENDING เดิม (ไม่ใช่ prompt ว่างแบบเดิม)

### Components

**A. `SearchScreen`'s `AppBar` (แก้จาก WYN-009 เดิม)**
- `title` ยังเป็น `TextField` เดิมทุกอย่าง (autofocus, ปุ่ม clear, hint เดิม)
- `bottom: TabBar` **แสดงเฉพาะเมื่อ `_query.isNotEmpty`** — เมื่อ query ว่าง ไม่มี `bottom` เลย (AppBar เตี้ยลงเป็นแค่แถบ search) เพื่อไม่ให้ TabBar ที่ยังไม่มีความหมาย (ไม่รู้จะกด tab ไหนเพราะไม่มีคำค้น) ไปแย่งพื้นที่/ความสนใจจาก Recent Searches + Trending

**B. `SearchRecentSearchesSection` (widget ใหม่)**
- Section header: `Row` — "ค้นหาล่าสุด" (`titleSmall`, bold — สไตล์เดียวกับ "กำลังนิยม" ของ Home WYN-017) ชิดซ้าย, ปุ่ม text "ล้างทั้งหมด" (`TextButton`, สี `colorScheme.outline` ไม่ใช่สี error เพราะไม่ใช่การลบเนื้อหาถาวรของคนอื่น) ชิดขวา
- เนื้อหา: `Wrap` ของ `Chip` (ไม่ใช่ `ListView` แนวตั้ง — เพื่อประหยัดพื้นที่แนวตั้ง ตามโจทย์ "ไม่ให้รก") — แต่ละ chip: label = คำค้น, `deleteIcon` มาให้ในตัว (Material `Chip.onDeleted`), แตะตัว chip (ไม่ใช่ delete icon) = รันค้นหาคำนั้นทันที, แตะ delete icon = ลบรายการนั้นออกจากอุปกรณ์ทันที (ไม่มี confirm dialog — เหตุผลดู Design Rules)
- ทั้ง section (header + chips) **ไม่ render เลยถ้าไม่มีประวัติ** (ไม่ใช่แสดง section ว่างๆ)

**C. `SearchTrendingHashtagsSection` (widget ใหม่)**
- Section header: "WYN TRENDING" (`titleSmall`, bold, ตัวพิมพ์ใหญ่ตามชื่อ feature ที่ Founder ตั้งไว้ในทุกเอกสาร — เทียบเท่ากับที่ "ZOKY" เป็นชื่อเฉพาะภาษาอังกฤษไม่แปลไทยในที่อื่นของแอป)
- เนื้อหา: `ListView` แนวตั้ง (ไม่ scroll แนวนอนแบบ Home's `TrendingTile` เพราะ hashtag เป็นข้อความ ไม่ใช่รูป/thumbnail — แนวตั้งอ่านเป็น "ranking list" ได้เป็นธรรมชาติกว่า) สูงสุด 10 แถวเป๊ะ
- แต่ละแถว (`_TrendingHashtagRow`):
  - Leading: วงกลมตัวเลขอันดับ (1-10) พื้นหลัง `colorScheme.primaryContainer`, ตัวเลขสี `colorScheme.onPrimaryContainer`, ขนาด 28x28, `radiusFull` (`WynSpacing.radiusFull`)
  - Title: `#{tag}` (`titleSmall`, ไม่ต้องใช้ `HashtagText` เพราะทั้งแถวเป็น tap target เดียวอยู่แล้ว ไม่ใช่ inline text ผสมกับข้อความอื่น)
  - Trailing (เล็ก, secondary): "{count} โพสต์" (`bodySmall`, สี `colorScheme.outline`) — ให้บริบทว่า "นิยม" แค่ไหน ไม่ใช่แค่อันดับลอยๆ
  - ทั้งแถวเป็น `InkWell`, Semantics label: "อันดับ {n} แฮชแท็ก {tag} มี {count} โพสต์ กดเพื่อดูโพสต์ทั้งหมด"
- คั่นแถวด้วย `Divider(height: 1)` เหมือน `HashtagFeedScreen`'s list เดิม (ความสม่ำเสมอ)

### Interactions

- แตะแถว Trending → `Navigator.push(HashtagFeedScreen(tag: ...))` (ใช้ repository ที่ `SearchScreen` มีอยู่แล้วทั้งหมดส่งต่อเข้าไป ไม่ต้อง build จาก `Supabase.instance.client` ใหม่แบบที่ `HashtagText` ทำ เพราะ `SearchScreen` ถือ repository ครบทุกตัวที่ `HashtagFeedScreen` ต้องการอยู่แล้วเป็น constructor param — reuse DI ที่มีอยู่ ไม่เพิ่ม pattern ที่สอง)
- แตะ Recent Search chip → `_controller.text = query`, ตั้ง `_query = query` **ทันทีไม่รอ debounce** (คำค้นสมบูรณ์อยู่แล้ว ไม่ใช่กำลังพิมพ์), ปิด keyboard (`_focusNode.unfocus()`) — **ไม่**เรียก `addRecentSearch` ซ้ำตอนนี้ (จะถูกบันทึก/เลื่อนขึ้นบนอีกครั้งตามธรรมชาติถ้าแตะผลลัพธ์จริงจากการค้นครั้งนี้)
- แตะ delete icon บน chip → ลบออกจาก `shared_preferences` + ออกจาก UI ทันที (optimistic, ไม่ error-prone เพราะ local storage เขียนเร็วมาก ไม่ต้อง loading state)
- แตะ "ล้างทั้งหมด" → เคลียร์ `shared_preferences` ทั้ง list ทันที ไม่มี confirm dialog (ดู Design Rules)
- แตะผลลัพธ์จริงจาก tab ใดก็ตาม (User/Drop/Pop/Club) → บันทึก `_query.trim()` ลง Recent Searches (ผ่าน callback ใหม่ที่ `SearchScreen` ส่งลงไปยัง 4 tab widget — ดู Handoff) ก่อน `Navigator.push`

### States

| สถานการณ์ | Recent Searches section | WYN TRENDING section |
|---|---|---|
| ไม่มีประวัติค้นหาเลย | ไม่ render (ไม่มี header ว่างๆ) | render ปกติ |
| มีประวัติ 1-10 รายการ | render chip ตามจำนวนจริง | render ปกติ |
| กำลังโหลด Trending (ระหว่างรอ query) | ไม่กระทบ | **ไม่แสดง spinner** — `FutureBuilder` คืน `SizedBox.shrink()` เหมือน Home's Trending row (WYN-017) ทุกประการ — เหตุผลเดียวกัน: ไม่บล็อกส่วนอื่นของหน้าให้รอ |
| โหลด Trending สำเร็จแต่ได้ 0 hashtag (ยังไม่มีใครใช้ hashtag เลยในระบบ) | ไม่กระทบ | Section header ("WYN TRENDING") ยังอยู่ + ข้อความ "ยังไม่มี hashtag ที่กำลังนิยมตอนนี้" กึ่งกลางใต้ header — ตรงตาม AC "แสดง empty state ที่เหมาะสม ไม่ error/พัง" |
| โหลด Trending ล้มเหลว (exception) | ไม่กระทบ | เหมือน "กำลังโหลด" — `SizedBox.shrink()` (fail-safe, เงียบ, ไม่โชว์ error ให้ผู้ใช้เพราะเป็น section รอง ไม่ใช่ core function — pattern เดียวกับ Home's Trending row) |

### Responsive Behavior

- `Wrap` ของ Recent Search chips ปรับจำนวนต่อแถวอัตโนมัติตามความกว้างจอ (ไม่ fix จำนวนคอลัมน์)
- ทั้งหน้า scroll เดียว (`ListView`/`CustomScrollView` ระดับบนสุด) ไม่มี nested scroll ระหว่าง Recent/Trending section (ทั้งสองไม่ scroll อิสระของตัวเอง — Recent wrap ตามความสูงเนื้อหาจริง, Trending list สูงสุด 10 แถวคงที่ ไม่ scroll ภายในตัวเอง)
- จอเล็ก: chip ที่ยาวเกิน (คำค้นยาวมาก) ให้ `Chip` ตัดด้วย ellipsis ตาม default ของ Material `Chip` ไม่ต้อง custom

### Accessibility

- แถว Trending: Semantics label รวมอันดับ+tag+count ตามที่ระบุใน Components (C) ด้านบน — ไม่สื่อสารอันดับด้วยสี/ตำแหน่งอย่างเดียว (ตัวเลขอันดับเป็นข้อความจริงในวงกลม ไม่ใช่แค่สี)
- Chip's delete icon ต้องมี label ("ลบ {คำค้น} ออกจากประวัติค้นหา") — Material `Chip.onDeleted` ให้ default semantics มาระดับหนึ่งแต่ต้องตรวจสอบว่าเพียงพอ ถ้าไม่พอให้ห่อ `Semantics` เพิ่มเหมือนปุ่ม clear ของ search box เดิม (`Semantics(label: 'ล้างคำค้นหา', button: true)`)
- ปุ่ม "ล้างทั้งหมด": Semantics label "ล้างประวัติค้นหาทั้งหมด"
- Touch target: วงกลมอันดับ 28px เล็กกว่า `touchTargetMin` (44px) แต่ทั้งแถว (`InkWell` เต็มความกว้าง, สูงอย่างน้อย 48px ตาม `ListTile` มาตรฐาน) คือ tap target จริง ไม่ใช่แค่วงกลม — ตรงตาม convention เดิมของแอป (แถว User ผลลัพธ์ก็ทำแบบเดียวกัน: avatar 20px เล็ก แต่ทั้งแถวคือ target)

---

## Data & Query Design (R1 — WYN Trending Top 10)

**ตำแหน่งไฟล์ที่แนะนำ**: `app/lib/features/hashtag/data/hashtag_repository.dart` (ใหม่) — ให้ logic การนับ/จัดอันดับ hashtag อยู่รวมกับ domain ของ hashtag (เคียงข้าง `extractHashtags`) แทนที่จะฝังอยู่ใน `DropRepository`/`ClubPostRepository` ซึ่งมีหน้าที่หลักคือ CRUD ของ Drop/ClubPost ไม่ใช่การนับความถี่ hashtag ข้ามตาราง

```
class TrendingHashtag {
  final String tag;   // lowercase, ไม่มี '#' นำหน้า (ตรงกับ extractHashtags's output shape)
  final int count;
}

class HashtagRepository {
  HashtagRepository(this._dropRepository, this._clubPostRepository);

  Future<List<TrendingHashtag>> fetchTopTrendingHashtags({int limit = 10}) async { ... }
}
```

Query design ของ `fetchTopTrendingHashtags`:
1. คำนวณ `since = DateTime.now().toUtc().subtract(Duration(hours: 48))` — ค่าเดียวกับ `HomeRepository._trendingWindow`
2. ดึง caption ล่าสุด 100 รายการจาก `drops` (`created_at >= since`, `order by created_at desc`, `limit 100`) — repository method ใหม่ **เบา** (`DropRepository.fetchRecentCaptions({required DateTime since, required int limit})` คืนแค่ `List<String>` ของ caption ที่ไม่ null เท่านั้น ไม่ join author/like/comment เหมือน `fetchFeed`/`searchByCaption` เพราะไม่ต้องใช้ข้อมูลพวกนั้นเลยสำหรับนับ hashtag)
3. ดึง content ล่าสุด 100 รายการจาก `club_posts` แบบเดียวกัน (`ClubPostRepository.fetchRecentContents({required DateTime since, required int limit})`) — **ไม่ต้องเพิ่ม visibility filter เอง** เพราะ RLS ของ `club_posts` (select) จำกัดแถวที่ query เห็นอยู่แล้วเป็นค่าเริ่มต้น เหมือนที่ `searchByContent`/`fetchFromJoinedClubs` พึ่งอยู่แล้ว — ผลคือ Top 10 ที่แต่ละคนเห็นอาจต่างกันเล็กน้อยตาม Club ที่เขาเป็นสมาชิก ซึ่งเป็นพฤติกรรมเดียวกับที่ `HashtagFeedScreen`'s Trending tab มีอยู่แล้วสำหรับ Club post (ไม่ใช่ inconsistency ใหม่)
4. รวมทั้งสอง list ของ string → เรียก `extractHashtags(text)` ทีละอัน (ทุก tag ที่เจอในแต่ละ caption/content นับเป็น 1 ครั้งของ tag นั้น — ถ้าแคปชันเดียวมี `#WYN` ซ้ำสองครั้งนับเป็น 1 เพราะ `extractHashtags` คืน `Set`)
5. Tally ใน `Map<String, int>` (tag → count)
6. เรียงจากมากไปน้อยตาม count, tie-break ด้วยลำดับตัวอักษร (a-z) เพื่อผลลัพธ์ deterministic เวลา count เท่ากัน (ไม่ผูกกับเวลาล่าสุดเพราะไม่ต้องเก็บ timestamp เพิ่มให้ซับซ้อนเกินจำเป็น)
7. `.take(limit)` — **การันตีไม่เกิน 10 เด็ดขาดที่ชั้นนี้** (ไม่ใช่แค่หวังว่า UI จะไม่ render เกิน — เผื่อ Coding เขียน UI ผิดในอนาคตก็ยังปลอดภัยที่ data layer)

Scope เดียวกับ `HashtagFeedScreen`'s hashtag source: **Drop + Club post เท่านั้น ไม่รวม Pop** (แม้ `PopRepository.searchByCaption` จะมีอยู่แล้ว) — เพื่อให้ "hashtag ที่ใช้ได้จริง" สอดคล้องกันทั้งแอปตาม scope ที่ WYN-020 กำหนดไว้แล้ว (การเพิ่ม Pop เข้ามาเป็นการขยาย scope ของระบบ hashtag ทั้งระบบ ไม่ใช่แค่ของหน้า Trending — ถ้าต้องการควรเป็น task แยกที่แก้ WYN-020's scope ตรงๆ)

---

## Data & Storage Design (R2 — Recent Searches)

**ไฟล์ใหม่**: `app/lib/features/search/data/recent_search_preference.dart` — มิเรอร์ pattern ของ `pop_mute_preference.dart` เป๊ะ (top-level function, ไม่ใช่ class, `shared_preferences` dependency ที่มีอยู่แล้วใน `pubspec.yaml` — ไม่ต้องเพิ่ม dependency ใหม่)

Key: `'recent_searches'` — เก็บเป็น `List<String>` ตรงๆ ผ่าน `SharedPreferences.getStringList`/`setStringList` (ไม่ต้อง JSON encode เพราะเป็นแค่ list ของ string ธรรมดา ไม่มี field อื่นต่อรายการ)

```
const _recentSearchesKey = 'recent_searches';
const _recentSearchesMax = 10;

Future<List<String>> loadRecentSearches() async { ... }

Future<void> addRecentSearch(String query) async {
  // trim, ignore ถ้าว่าง, ลบรายการเดิมที่ตรงกันแบบ case-insensitive ออกก่อน
  // (กันซ้ำ "Namfah" กับ "namfah" เป็นสองรายการ) แล้ว insert คำใหม่ (ตาม
  // casing ล่าสุดที่ผู้ใช้พิมพ์) ไว้บนสุด ตัดท้ายให้เหลือ <= 10 แล้วเซฟ
}

Future<void> removeRecentSearch(String query) async { ... }

Future<void> clearRecentSearches() async { ... }
```

- จำนวนสูงสุด: 10 รายการ (ตามที่ Product ระบุ) — ตัดจากท้าย (เก่าสุด) เมื่อเกิน
- Dedupe: case-insensitive ("Namfah" ที่พิมพ์ซ้ำหลัง "namfah" จะย้ายขึ้นบนสุดแทนที่จะเพิ่มเป็นรายการใหม่)
- Local device only (ตามที่ Product ตัดสินใจแล้ว — ไม่มี backend table, ไม่ sync ข้ามเครื่อง) — ไม่ผูกกับ `user.id` เลยด้วยซ้ำเพราะ `shared_preferences` เป็น per-install storage อยู่แล้ว (ถ้าในอนาคตมีหลาย account บนเครื่องเดียวสลับกัน ประวัติจะปนกัน — ยอมรับเป็น known limitation รอบแรก เหมือนที่ `pop_mute_preference` ก็ไม่ผูก user เช่นกัน)

---

## Design Rules

1. **"WYN TRENDING" เป็นชื่อ section ตรงตัวที่ Founder ใช้ในเอกสารต้นทาง** — ไม่แปลเป็นไทยหรือเปลี่ยนเป็น "กำลังนิยม" (ต่างจาก Home's Trending row ที่ใช้ "กำลังนิยม") เพื่อให้ตรงกับที่ product spec ตั้งชื่อไว้และแยกความแตกต่างชัดเจนจาก Home's Trending (content card, WYN-017) ว่านี่คือ hashtag ranking list คนละ concept
2. **จำกัด 10 รายการเป๊ะที่ data layer** (`.take(limit)` ใน repository) ไม่ใช่แค่ตัด UI — กัน bug ที่ query เปลี่ยนแล้วลืมจำกัดที่ layer ไหนสักที่
3. **ไม่มี confirm dialog สำหรับลบ Recent Search** (ทั้งลบทีละรายการและ "ล้างทั้งหมด") — ต่างจาก `confirm_delete_dialog.dart` ที่ใช้กับการลบ Drop/Pop/Comment ของผู้ใช้ (เนื้อหาถาวรที่มีคนอื่นเห็นด้วย) เพราะ Recent Search เป็นแค่ประวัติส่วนตัวบนอุปกรณ์ ไม่กระทบใครอื่น กู้คืนได้ง่ายด้วยการค้นหาใหม่ ความเสี่ยง/ผลกระทบต่ำกว่ามากจนไม่คุ้มที่จะเพิ่ม friction
4. **Recent Search บันทึกเมื่อ "เลือกผลลัพธ์" เท่านั้น ไม่ใช่ทุกครั้งที่ query เปลี่ยน** — ป้องกันไม่ให้ประวัติเต็มไปด้วยคำพิมพ์ผิด/พิมพ์ไม่จบที่ debounce ยิง query ไปแล้วแต่ผู้ใช้ไม่ได้กดอะไรต่อ ตรงตาม AC ของ Product ("พิมพ์คำค้นและกด/เลือกผลลัพธ์")
5. **Trending hashtag tap ไม่นับเป็น Recent Search** — เป็นคนละ flow (discovery ผ่านการแตะ ไม่ใช่การพิมพ์คำค้นเอง) สอดคล้องกับที่ Recent Search มีไว้จำ "สิ่งที่ฉันพิมพ์" ไม่ใช่ "สิ่งที่ฉันเคยเห็น"
6. **TabBar หายไปตอน query ว่าง แทนที่ด้วย Recent+Trending** — ตัดสินใจนี้เปลี่ยนพฤติกรรมเดิมของ WYN-009 เล็กน้อย (เดิม TabBar โชว์ตลอดแม้ query ว่าง) แต่จำเป็นเพื่อไม่ให้ "รก" ตามที่โจทย์ระบุชัด (โชว์ 4 tab ว่างเปล่าพร้อมกับ Recent+Trending พร้อมกันจะแน่นเกินไปและสับสนว่าใครคือ default view) — ไม่กระทบพฤติกรรมตอนมี query เลยแม้แต่น้อย
7. **WYN Trending ไม่มี realtime rank-change indicator (R3)** — คำนวณสดทุกครั้งที่ `SearchScreen`/`initState` ถูกเรียก (เปิดหน้าใหม่ทุกครั้ง = query ใหม่ทุกครั้ง ไม่ cache ข้ามการเปิดหน้า) ไม่มีลูกศร ↑/↓ ไม่มีตัวเลขอันดับก่อนหน้าเทียบ เพราะไม่มี Supabase Realtime infra ในโปรเจกต์และไม่มีที่เก็บ "อันดับรอบก่อน" ให้เทียบ — ตรงตามที่ Product ระบุไว้แล้วและ core-hardening roadmap (`.wyn/docs/product/wyn-core-hardening-roadmap.md`) ก็ระบุตรงกันว่าเป็นสิ่งที่ตั้งใจไม่ทำ
8. **Trending scope = Drop + Club post เท่านั้น (ไม่รวม Pop)** — ดูเหตุผลที่ "Data & Query Design" ด้านบน (สอดคล้องกับ scope ของระบบ hashtag ทั้งระบบตาม WYN-020 ไม่ใช่การตัดสินใจเฉพาะหน้า)
9. **Fail-safe เงียบเมื่อ Trending fetch ล้มเหลว/กำลังโหลด** (`SizedBox.shrink()`) — มิเรอร์ pattern ของ Home's Trending row (WYN-017) ทุกประการเพื่อความสม่ำเสมอของ "Trending section ทั่วทั้งแอปมีพฤติกรรม fail-safe เดียวกัน"

---

## Handoff (สรุปสำหรับ AI Coding)

**ไฟล์ใหม่:**
1. `app/lib/features/hashtag/data/hashtag_repository.dart` — `TrendingHashtag` model + `HashtagRepository.fetchTopTrendingHashtags({int limit = 10})` ตาม "Data & Query Design" ด้านบน
2. `app/lib/features/search/data/recent_search_preference.dart` — `loadRecentSearches`/`addRecentSearch`/`removeRecentSearch`/`clearRecentSearches` ตาม "Data & Storage Design" ด้านบน (มิเรอร์ `pop_mute_preference.dart`)
3. `app/lib/features/search/presentation/widgets/search_trending_hashtags_section.dart` — widget C ด้านบน (รับ `Future<List<TrendingHashtag>>` หรือ `HashtagRepository` เป็น prop, เลือกเอง — แนะนำ pattern `FutureBuilder` เดียวกับ `home_feed_screen.dart._buildTrendingSection()`)
4. `app/lib/features/search/presentation/widgets/search_recent_searches_section.dart` — widget B ด้านบน

**ไฟล์ที่ต้องแก้:**
1. `app/lib/features/drop/data/drop_repository.dart` — เพิ่ม `fetchRecentCaptions({required DateTime since, required int limit})` (ใหม่, ไม่แก้ method เดิม)
2. `app/lib/features/club/data/club_post_repository.dart` — เพิ่ม `fetchRecentContents({required DateTime since, required int limit})` (ใหม่, ไม่แก้ method เดิม, พึ่ง RLS เดิมเหมือน `searchByContent`)
3. `app/lib/features/search/presentation/search_screen.dart`:
   - `bottom: TabBar` แสดงเฉพาะ `_query.isNotEmpty`
   - `body` เมื่อ `_query.isEmpty` → แสดง `SearchRecentSearchesSection` + `SearchTrendingHashtagsSection` แทน `TabBarView` (โหลด recent searches ใน `initState`/หลัง `_clear()`)
   - เพิ่ม callback ใหม่ (เช่น `Future<void> _onResultSelected() => addRecentSearch(_query)`) แล้ว thread ลงไปยัง 4 tab widget (`SearchUserResultsTab`/`SearchDropResultsTab`/`SearchPopResultsTab`/`SearchClubResultsTab`) เป็น constructor param ใหม่ (เช่น `onResultSelected: VoidCallback`) — เรียกใน `_openXxx()` ของแต่ละ tab ก่อน `Navigator.push` — **แก้ทั้ง 4 ไฟล์ tab widget เพิ่ม param ใหม่นี้**
   - เพิ่ม logic แตะ Recent Search chip → set `_controller.text` + `_query` ทันที (ไม่ผ่าน debounce), `_focusNode.unfocus()`
   - ต้อง refresh recent-searches list ใน UI ทันทีหลัง add/remove/clear (setState หรือ reload จาก `shared_preferences`)

**Test ที่ต้องมี (regression, ไม่ใช่ optional):**
- Trending Top 10: จำกัดไม่เกิน 10 จริงแม้ candidate มีมากกว่า, sort ตาม count ถูกต้อง, tie-break ตัวอักษร, empty state เมื่อไม่มี hashtag เลย, แตะแถว → เปิด `HashtagFeedScreen` ถูก tag
- Recent Searches: เพิ่ม/ลบทีละรายการ/ลบทั้งหมดทำงานถูกต้องกับ `shared_preferences` จริง (ใช้ `SharedPreferences.setMockInitialValues()` ตาม convention เดิมของ `pop_mute_preference` tests ถ้ามี), dedupe case-insensitive, จำกัด 10 รายการ, บันทึกเฉพาะตอนเลือกผลลัพธ์จริงไม่ใช่ทุก keystroke, แตะ chip แล้วรันค้นหาทันทีไม่รอ debounce
- Regression: WYN-009 เดิม (TabBar 4 tab, debounce, empty states เดิมตอนมี query) ต้องผ่านครบเหมือนเดิม ไม่มีอะไรพัง — โดยเฉพาะ `home_feed_screen_test.dart`'s "tapping the Search bar opens SearchScreen" ต้องยังผ่าน

**QA ควรเน้นตรวจ:**
- Top 10 การันตีไม่เกินจริง (edge case: candidate 100 caption มี hashtag รวมกันเกิน 10 ชนิด)
- Club post ที่ private (ผู้ใช้ไม่ได้เป็นสมาชิก) ต้องไม่ถูกนับเข้า Trending ของผู้ใช้คนนั้น (RLS gate ทำงานถูกต้องที่ `fetchRecentContents` เหมือนที่ `searchByContent` เคยผ่าน QA มาแล้ว)
- Recent Search เขียนจริงลง `shared_preferences` และหายจริงหลังลบ (ไม่ใช่แค่หายจาก UI state ชั่วคราว)

ส่งต่อ AI Coding (`/code`) เพื่อ implement ตามข้างต้น — ดู Product spec เต็มที่ `.wyn/tasks/backlog/WYN-028-trending-top10-search.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
