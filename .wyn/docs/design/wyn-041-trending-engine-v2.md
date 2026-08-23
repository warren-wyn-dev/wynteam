# Design Spec — WYN-041: Trending Engine v2 (View Count + Anti-Manipulation)

อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-041-trending-engine-v2.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (reuse ตรงๆ ตามที่ Product ระบุ): `rankingScore()`/`fetchRankedFeed()` (WYN-018), `fetchTrending()` (WYN-017), `drop_view_count()` (WYN-038), `internal.is_posting_blocked()` (WYN-029/030), `HomeRepository._fetchFollowedAuthorIds()` (candidate-fetch-then-filter pattern เดิม)
Design System: ไม่เกี่ยวข้อง — **task นี้ไม่มี UI/Screen ใหม่แม้แต่จุดเดียว** เป็นการแก้สูตรคำนวณ (pure function) และเพิ่ม RPC ใหม่ 1 ตัวเท่านั้น ผู้ใช้ไม่เห็นความแตกต่างเชิงภาพใดๆ นอกจากลำดับการจัดอันดับที่เปลี่ยนไป

## ภาพรวม — ไม่มีหน้าจอใหม่ แก้สูตร + เพิ่ม RPC กรอง 1 ตัว

Task นี้ไม่มี Screen/Component/User Flow ใหม่ (มิเรอร์ลักษณะเดียวกับ WYN-038 ที่เป็น "เชื่อมสายไฟ" ล้วนๆ) — Output Format ด้านล่างจึงเว้นหัวข้อ UI-specific ไว้เป็น N/A และเน้นหัวข้อที่ Product ส่งต่อมาให้ Design ตัดสินใจจริง: **shape ของ RPC ใหม่** และ **จุด integration ที่แก้ในโค้ดเดิม**

---

## การตัดสินใจที่ 1 — รวมสูตร engagement เป็นจุดเดียว (`engagementScore()`) แทนการ inline ซ้ำ 2 ที่

ยืนยันจากโค้ดจริงตามที่ Product อ้างอิง: `rankingScore()` (WYN-018) inline `item.likeCount * 2 + item.commentCount * 3` และ `fetchTrending()` (WYN-017) inline `b.likeCount + b.commentCount` (น้ำหนัก 1:1 คนละแบบ) แยกกันคนละที่ในคนละไฟล์ — Product ตัดสินใจให้ทั้งสองสูตรใช้น้ำหนัก Like/Comment เดียวกัน (2:3) และเพิ่ม View term เดียวกัน จึงควรมีจุด source-of-truth เดียว ไม่ inline ซ้ำเป็นครั้งที่ 3

**เพิ่มฟังก์ชันใหม่ `engagementScore(HomeFeedItem item)` ใน `app/lib/features/home/data/home_ranking.dart`** (ไฟล์เดียวกับ `rankingScore()` เดิม — ไม่สร้างไฟล์ใหม่ เพราะเป็นแนวคิดเดียวกัน "engagement ของ item หนึ่งเป็นเท่าไหร่"):

```dart
double engagementScore(HomeFeedItem item) {
  final likeCommentScore = item.likeCount * 2 + item.commentCount * 3;
  if (item.contentType != HomeContentType.drop) return likeCommentScore.toDouble();
  return likeCommentScore + (item.viewCount ?? 0) * _viewWeight;
}
```

- `_viewWeight` เป็นค่าคงที่ระดับไฟล์ (`const _viewWeight = 0.1`) พร้อม comment อธิบายเหตุผลตรงจุดประกาศตามที่ Product ระบุไว้ (ค่าที่กำหนดเองชั่วคราว ไม่มีข้อมูล traffic จริง ปรับได้ภายหลัง — มิเรอร์สไตล์ comment ของ WYN-038's rate-limit/velocity-cap ตัวเลข)
- **Gate ด้วย `item.contentType != HomeContentType.drop` ก่อนเสมอ** — Pop content คืน `likeCommentScore` ตรงๆ ไม่บวก view เลยแม้แต่น้อย (Product's Requirement 2 — Pop's view count ไม่ trustworthy พอ) ต้องเป็น early-return ที่อ่านแล้วเห็นทันทีว่า "Pop ไม่แตะ" ไม่ใช่ conditional ซ่อนอยู่กลางสูตรที่พลาดง่าย
- Comment เหนือฟังก์ชันต้องอธิบายเหตุผลของ Pop-exclusion แบบเดียวกับที่ Product ระบุ (ไม่มี unique-viewer dedup/rate-limit/self-view-exclusion เหมือน Drop — รวม view เข้าตรงๆ จะเปิดช่องโหว่ anti-manipulation ที่ task นี้ตั้งใจปิด) กัน AI/Coding รอบถัดไปเข้าใจผิดว่าลืมใส่แล้วไปเพิ่มเองทีหลังโดยไม่เห็นเหตุผล

**Integration points (แก้ 2 จุดในโค้ดเดิม ให้เรียก `engagementScore()` แทนการ inline):**
1. `rankingScore()` (`home_ranking.dart`) — แทนที่ `final engagementScore = item.likeCount * 2 + item.commentCount * 3;` ด้วย `final engagementScore = engagementScore(item);` (ตั้งชื่อตัวแปร local ซ้ำกับชื่อฟังก์ชันได้ในกรณีนี้เพราะ Dart แยก scope ชัดเจน แต่ถ้า Coding เห็นว่าอ่านสับสนให้เปลี่ยนชื่อตัวแปร local เป็น `engagement` แทนได้ ไม่ใช่ประเด็นสำคัญ)
2. `fetchTrending()` (`home_repository.dart`) — แทนที่ `items.sort((a, b) => (b.likeCount + b.commentCount).compareTo(a.likeCount + a.commentCount));` ด้วย `items.sort((a, b) => engagementScore(b).compareTo(engagementScore(a)));` (import `engagementScore` จาก `home_ranking.dart` ซึ่ง `home_repository.dart` import อยู่แล้วสำหรับ `rankingScore()`)

ผลลัพธ์: Discovery's Trending Now (`DiscoveryRepository.fetchTrendingNow()`) และ Trending Hashtags (`fetchTrendingHashtags()`) ได้ผลจากการเปลี่ยนนี้อัตโนมัติทันที **ไม่ต้องแก้ `discovery_repository.dart`/`discovery_view.dart` แม้แต่บรรทัดเดียว** เพราะทั้งคู่ reuse `HomeRepository.fetchTrending()` ตรงๆ อยู่แล้ว (ตามที่ Product คาดหวังไว้ในการเลือก integration point)

---

## การตัดสินใจที่ 2 — RPC กรอง sanctioned author: `authors_posting_blocked(p_author_ids uuid[])`

ตั้งชื่อให้มิเรอร์ `internal.is_posting_blocked(p_user_id)` ที่มันห่อหุ้มอยู่ตรงๆ (ไม่ใช้คำว่า "sanction" ที่ไม่เคยเป็นศัพท์ในระบบนี้มาก่อน — ยึด "posting blocked" เป็นคำเดิมของโปรเจกต์ตาม WYN-029/030 ต่อเนื่อง)

```sql
-- WYN-041: batched wrapper around internal.is_posting_blocked() (WYN-029/
-- 030) for Trending/ranked-feed candidate filtering. moderation_actions
-- has no SELECT policy for ordinary users, and internal.is_posting_
-- blocked() lives in `internal` specifically so it's unreachable as a
-- direct client RPC (same reasoning as internal.is_blocked_either_way,
-- WYN-027) -- this public wrapper is the one sanctioned way a client can
-- ask "which of these candidate authors currently can't post" without
-- ever learning *why* (action_type/reason/reviewer_id/expires_at stay
-- server-side). Returns only the subset that's true -- never a
-- true/false per input id -- so an empty result for an author simply
-- means "not excluded," identical anti-gaming return shape to WYN-040's
-- rising_profiles()/suggested_users() (an ordered/filtered id list only,
-- never the underlying signal).
create or replace function public.authors_posting_blocked(p_author_ids uuid[])
returns table(author_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select id as author_id
  from unnest(p_author_ids) as id
  where internal.is_posting_blocked(id);
$$;

grant execute on function public.authors_posting_blocked(uuid[]) to authenticated;
```

- **Return shape**: `table(author_id uuid)` คอลัมน์เดียว มีแค่ id ที่ "ถูกกันออก" เท่านั้น — ไม่มี `action_type`/`reason`/`reviewer_id`/`expires_at` ใดๆ หลุดออกมาเลย (Product's Risk ข้อ "RPC ใหม่ต้องคืนแค่ id ที่ถูกกันออก") — client เห็นแค่ "id นี้อยู่ในผลลัพธ์ = ไม่นับเข้า ranking รอบนี้" ไม่มีทางรู้ว่าเป็น restrict/suspend/ban หรือเหตุผลอะไร
- **`security definer` จำเป็นจริง** ด้วยเหตุผลเดียวกับที่ WYN-039/040 เคยยืนยันมาแล้วกับ `follows`: `internal.is_posting_blocked()` เองก็เป็น SECURITY DEFINER อยู่แล้ว (เข้าถึง `moderation_actions` ที่ผู้ใช้ทั่วไปไม่มี SELECT policy) — wrapper นี้แค่เปิดช่องให้เรียกจาก client เป็น batch เดียวแทนที่จะเรียกทีละ id (ซึ่งเป็นไปไม่ได้อยู่แล้วเพราะ `internal.*` ไม่ expose เป็น REST endpoint)
- `stable` (ไม่ใช่ `volatile`) เพราะไม่มี side effect ใดๆ แค่อ่านอย่างเดียว มิเรอร์ `is_blocked_either_way`/`is_posting_blocked` ต้นแบบ

---

## การตัดสินใจที่ 3 — จุด integration ของ RPC ใน `home_repository.dart`

เพิ่ม private helper ใหม่ 1 ตัวมิเรอร์ `_fetchFollowedAuthorIds()` ที่มีอยู่แล้ว (รูปแบบ "fetch candidate ก่อน แล้วยิง query/RPC แยกเพื่อกรอง ก่อน sort สุดท้าย" ที่ทั้งไฟล์นี้ใช้อยู่แล้วกับ liked/saved/redropped/followed):

```dart
Future<Set<String>> _fetchPostingBlockedAuthorIds(Set<String> authorIds) async {
  if (authorIds.isEmpty) return {};
  final rows = await _client.rpc(
    'authors_posting_blocked',
    params: {'p_author_ids': authorIds.toList()},
  ) as List<dynamic>;
  return rows.map((row) => row['author_id'] as String).toSet();
}
```

**เรียกใช้ใน 2 จุด ก่อนขั้นตอน sort/take สุดท้าย ทั้งคู่:**

1. **`fetchTrending()`**: หลังจากได้ `items` (แปลงจาก `rows` แล้ว) — เก็บ `authorIds` จาก `rows` (เหมือนที่ `fetchRankedFeed()` เก็บ `authorIds` อยู่แล้วสำหรับ `_fetchFollowedAuthorIds`) → เรียก `_fetchPostingBlockedAuthorIds()` → `items.removeWhere((item) => blockedAuthorIds.contains(item.authorId))` **ก่อน** `items.sort(...)`/`.take(limit)`
2. **`fetchRankedFeed()`**: จุดเดียวกัน — เก็บ `authorIds` (ใช้ set เดิมที่เก็บไว้แล้วสำหรับ `_fetchFollowedAuthorIds` ได้เลย ไม่ต้อง query ซ้ำสอง RPC จาก authorId set เดียวกัน) → `removeWhere` ก่อน `.sort()`

**Non-goal ที่ต้องระบุชัดตาม Product's ขอบเขต**: กรองตาม `item.authorId` (เจ้าของเนื้อหาต้นฉบับ) เท่านั้น — ReDrop ที่ผู้ ReDrop (`redropper_id`) ไม่ได้โดน sanction แต่เนื้อหาต้นฉบับที่ ReDrop มาจากบัญชีที่โดน sanction (หรือกลับกัน) **ไม่อยู่ในสโคปการตัดสินใจของรอบนี้** — Product spec ระบุแค่ "เนื้อหาจากบัญชีที่มี moderation action" ตรงๆ ไม่ได้ขยายไปถึง ReDrop chain ที่ซับซ้อนกว่านั้น ถ้า Founder ต้องการให้ครอบคลุม ReDrop chain ด้วยให้เป็นการตัดสินใจเพิ่มเติมแยกต่างหาก ไม่ใช่สมมติเอาเองในรอบนี้

**ผลลัพธ์ต่อ Discovery (WYN-040)**: `DiscoveryRepository.fetchTrendingNow()`/`fetchTrendingHashtags()` ทั้งคู่ reuse `HomeRepository.fetchTrending()` ตรงๆ — ได้การกรองนี้อัตโนมัติทันที ไม่ต้องแก้ `discovery_repository.dart` เลย ตรงตามที่ Product คาดหวังจากการเลือก integration point ที่จุดเดียว (`fetchTrending()`)

---

## Screen: N/A — ไม่มี UI/Screen ใหม่ในรอบนี้

## Purpose: N/A (ดูภาพรวมด้านบน — เป็นการแก้สูตรคำนวณ/เพิ่ม RPC เท่านั้น)

## User Flow: N/A — ผู้ใช้ไม่เห็น flow ใหม่ใดๆ เห็นแค่ลำดับ "กำลังนิยม"/"สำหรับคุณ"/Discovery Trending ที่เปลี่ยนไปตามสูตรใหม่ และเนื้อหาจากบัญชีที่โดน sanction จะไม่ปรากฏใน 3 จุดนี้อีก (แต่ยังเข้าถึงได้ปกติทางอื่นทั้งหมด)

## Components: N/A — ไม่มี widget/component ใหม่ ไม่แก้ widget ที่มีอยู่แล้วแม้แต่ตัวเดียว (แก้เฉพาะ data layer: `home_ranking.dart`/`home_repository.dart`/`schema.sql`)

## Interactions: N/A

## States: N/A

## Responsive Behavior: N/A

## Accessibility: N/A — ไม่มีองค์ประกอบภาพใหม่ให้ประกาศ

## Design Rules

1. `engagementScore()` ต้อง early-return สำหรับ Pop **ก่อน** คำนวณ view term เสมอ (ดูการตัดสินใจที่ 1) — ห้ามเขียนเป็น `viewWeight = item.contentType == drop ? 0.1 : 0.0` แบบแทรกกลางสูตรเดียว เพราะอ่านแล้วไม่ชัดเท่า early-return ว่า "Pop ไม่แตะเรื่อง view เลย"
2. ค่าคงที่ `_viewWeight` (และตัวเลขอื่นใดที่ Product ระบุว่าเป็นค่าชั่วคราว) ต้องมี comment อธิบายเหตุผล+แหล่งที่มา ("Product กำหนดเองชั่วคราว ไม่มีข้อมูล traffic จริง") ตรงจุดประกาศเสมอ ไม่ hardcode ลอยๆ
3. `authors_posting_blocked()` ต้องคืนแค่คอลัมน์ `author_id` เดียว — ห้าม `select *` หรือ join เพิ่มคอลัมน์อื่นจาก `moderation_actions` ออกมาโดยเด็ดขาด แม้จะดู "สะดวก" สำหรับ debug ก็ตาม (ดู Design Decision 2)
4. ฟังก์ชัน/ตัวแปรใหม่ทั้งหมดเป็นภาษาอังกฤษตาม `AGENTS.md` เดิม — ไม่มีข้อยกเว้น

## Non-goals รอบนี้

- **ไม่รวม Pop's view count เข้าสูตรใดๆ** (Product's Requirement 2 — Pop's view counting ยังไม่ trustworthy พอ)
- **ไม่ครอบคลุม ReDrop chain** สำหรับการกรอง sanctioned-author (ดูการตัดสินใจที่ 3)
- **ไม่มี UI แสดงผลใดๆ ว่า "เนื้อหานี้ถูกกันออกจาก Trending เพราะอะไร"** — ทั้งฝั่งเจ้าของเนื้อหาที่โดน sanction และฝั่งผู้ชมทั่วไป ไม่เห็นข้อความอธิบายใดๆ เพิ่มเติมจากที่ WYN-029/030 มีอยู่แล้ว (เจ้าของเห็นสถานะ moderation ของตัวเองผ่าน `get_my_moderation_status()`/`AccountRestrictedScreen` เดิมอยู่แล้ว ไม่ต้องเพิ่มจุดใหม่)
- **ไม่ปรับ candidate window/limit ใดๆ** (`_trendingCandidateLimit`/`_rankedCandidateLimit`/`_trendingWindow` ทั้งหมดคงเดิม — การ exclude อาจทำให้ผลลัพธ์สุดท้ายน้อยกว่า `limit` ที่ขอไว้ในบางกรณี ยอมรับเหมือนที่ระบบ bounded-window อื่นๆ ยอมรับอยู่แล้ว ไม่ต้องขยาย candidate เพิ่มเพื่อชดเชย)

## Handoff

ส่งต่อ AI Coding (`/code`) เพื่อ implement ตามการตัดสินใจที่ 1–3 ข้างต้น:
1. เพิ่ม `engagementScore(HomeFeedItem item)` ใน `home_ranking.dart` (มี `_viewWeight` constant + comment อธิบาย + early-return สำหรับ Pop) แล้วแก้ `rankingScore()`/`fetchTrending()` ให้เรียกใช้แทนสูตร inline เดิมทั้งคู่
2. เพิ่ม SQL: `public.authors_posting_blocked(p_author_ids uuid[])` (SECURITY DEFINER, ต่อท้าย schema.sql หลังส่วน WYN-040) ตาม SQL ที่ระบุไว้เป๊ะ + เขียน regression test ใหม่ (มิเรอร์ harness เดิม) ครอบ: บัญชี restrict/suspend ที่ยัง active ถูกคืนใน author_id, บัญชี ban ถูกคืน, บัญชีที่หมดอายุ/ถูก overturn ไม่ถูกคืน, บัญชีปกติไม่ถูกคืน, return type มีแค่คอลัมน์ `author_id` เดียว (ยืนยันด้วย `pg_get_function_result`), third-party เรียกได้ผลถูกต้อง (พิสูจน์ SECURITY DEFINER bypass ข้อจำกัดของ `moderation_actions` จริง)
3. เพิ่ม `_fetchPostingBlockedAuthorIds()` ใน `home_repository.dart` แล้วเรียกใช้ก่อน sort ใน `fetchTrending()`/`fetchRankedFeed()` ทั้งคู่ตามที่ระบุ
4. เขียน Flutter regression test ครอบ: `engagementScore()` unit test (Pop ไม่รวม view, Drop รวม view ตามน้ำหนักที่กำหนด — pure function ไม่ต้องพึ่ง Supabase เหมือน `rankingScore`/`rankTrendingHashtags` เดิม), `fetchTrending()`/`fetchRankedFeed()` exclude บัญชีที่โดน posting-block ออกจากผลลัพธ์จริง (ใช้ fake/recording repository เดิม), regression เต็มชุดของ WYN-017/018/040 ต้องผ่านหมดไม่มีจุดไหนพัง
5. ต้อง QA & Security ตรวจสอบก่อนอนุมัติ — เน้นตรวจ (ก) `authors_posting_blocked()` ไม่รั่ว action_type/reason/reviewer/expires_at ออกทางไหนเลย (ข) เนื้อหาบัญชีที่โดน sanction ยังเห็นได้ปกติทาง Home chronological/Search/Following/โปรไฟล์ตัวเอง — ไม่ใช่การซ่อนเนื้อหา (ค) Pop's engagement score ไม่เปลี่ยนแปลงจากเดิมแม้แต่กรณีเดียว (ง) น้ำหนัก `_viewWeight` ไม่ทำให้ WYN-018 test suite เดิมที่ไม่เกี่ยวกับ view พังโดยไม่ได้ตั้งใจ
