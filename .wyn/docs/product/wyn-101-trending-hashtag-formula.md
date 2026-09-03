# Product Full Spec — WYN-101

Status: full spec complete (2026-09-02) — ready for AI Coding โดยตรง (ไม่ต้องผ่าน Design เต็มรูปแบบ — ดู Handoff)
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` ข้อ 10/28, `.wyn/tasks/backlog/WYN-101.md`, `.wyn/company/DECISIONS.md` (2026-09-02, คำตอบข้อ 4/4)

Feature: เปลี่ยนสูตรจัดอันดับแฮชแท็กกำลังนิยมเป็น engagement-weighted + time-decay และเอาตัวเลขจำนวนโพสต์ออกจาก UI

Goal: อันดับแฮชแท็กสะท้อนความไวรัล/engagement จริง ไม่ใช่แค่จำนวนโพสต์ดิบ

Target User: ผู้ใช้ WYN Social ทุกคนที่ใช้หน้า Discovery/Top 100

## Problem — สถานะปัจจุบันจริง (ตรวจโค้ดแล้ว)

`rankTrendingHashtags()` (`app/lib/features/search/data/discovery_ranking.dart`) เป็น pure function **นับความถี่ดิบ** (`frequency[tag] += 1` ต่อโพสต์ 1 อัน ที่มี tag นั้นใน caption) จาก candidate pool ที่ `HomeRepository.fetchTrending()` ดึงมา (48 ชม./100 โพสต์ล่าสุด) — ไม่มี engagement weighting เลย ตรงตามที่ Founder อธิบายปัญหา ("นับจากจำนวนโพสต์อย่างเดียว")

`HashtagRankRow` (`app/lib/features/search/presentation/widgets/hashtag_rank_row.dart` บรรทัด 69) แสดง **"${item.postCount} โพสต์ · กำลังนิยมใน ไทย"** ใต้ทุกแฮชแท็ก — และมี doc comment ยืนยันว่าการโชว์ตัวเลขนี้เป็น**การตัดสินใจที่ผ่าน Founder อนุมัติมาก่อนแล้ว**เมื่อ 2026-08-29 (design-reference re-brand) ซึ่งพลิกมติเดิมของ `wyn-040-discovery-page.md` ที่ตอนแรกตั้งใจไม่โชว์ตัวเลขนี้อยู่แล้ว — Founder ข้อ 10 ตอนนี้คือการพลิกกลับมติ 2026-08-29 อีกรอบ (กลับไปไม่โชว์ตามที่ตั้งใจไว้ตอนแรกสุด) — บันทึกไว้เพื่อความชัดเจน ไม่ใช่ความขัดแย้งที่ต้องแก้ไข แค่เป็นการพลิกมติครั้งที่ 2

## Data Model Impact
**ไม่ต้องแก้ schema/migration เลย** — ข้อมูลที่จำเป็นทั้งหมด (like/comment/repost count, view count, created_at) **มีอยู่แล้วใน `HomeFeedItem`** ที่ `fetchTrendingHashtags()` ดึงมาอยู่แล้วผ่าน `_homeRepository.fetchTrending()` (ฟิลด์: `likeCount`, `commentCount`, `redropCount`, `viewCount`, `createdAt`) — สูตรใหม่คำนวณฝั่ง Dart ล้วนๆ (pure function เหมือนเดิม ไม่มี I/O เพิ่ม) ไม่ต้องมี RPC ใหม่หรือ RLS ใหม่

## สูตรที่ใช้ (draft แรกตามที่ Founder อนุมัติให้ AI เสนอ, 2026-09-02)

```
trending_score = (likes×1 + comments×2 + reposts×3 + views×0.1) / (hours_since_post + 2)^1.5
```

รวมคะแนนของทุกโพสต์ที่มีแฮชแท็กเดียวกัน (ไม่ใช่แค่นับ 1 ต่อโพสต์เหมือนเดิม) แล้วจัดอันดับตามผลรวม — ยังคงใช้ candidate window เดิม (`HomeRepository.trendingCandidateLimit`, 48 ชม./100 โพสต์ล่าสุด) เป็นแหล่งข้อมูล ไม่เปลี่ยน window

**Implementation**: เขียนใหม่ `rankTrendingHashtags()` ให้รับ `Iterable<HomeFeedItem>` แทน `Iterable<String?>` (captions อย่างเดียวไม่พอแล้ว ต้องใช้ engagement fields ด้วย) — สำหรับแต่ละโพสต์ คำนวณ `trending_score` ครั้งเดียว แล้วบวกสะสมเข้าทุก tag ที่โพสต์นั้นมี (โพสต์ที่มีหลาย hashtag ได้คะแนนเท่ากันไปลงทุก tag ของมัน — เหมือนวิธีนับความถี่แบบเดิมที่นับซ้ำได้เช่นกัน ไม่เปลี่ยนพฤติกรรมนี้)

```dart
class RankedHashtag {
  const RankedHashtag({required this.tag, required this.postCount, required this.score});
  final String tag;
  final int postCount; // เก็บไว้ภายใน (ใช้ sort tie-break / debug) — ไม่โชว์ใน UI อีกต่อไป
  final double score;
}

double _trendingScore(HomeFeedItem item, DateTime now) {
  final hours = now.difference(item.createdAt).inMinutes / 60.0;
  final engagement = item.likeCount * 1
      + item.commentCount * 2
      + item.redropCount * 3
      + (item.viewCount ?? 0) * 0.1;
  return engagement / pow(hours + 2, 1.5);
}
```

**Weight เป็นค่าคงที่ปรับได้** (ไม่ hardcode ฝัง logic กลางฟังก์ชัน) — ประกาศเป็น `static const` ที่หัวไฟล์ (`_likeWeight = 1`, `_commentWeight = 2`, `_repostWeight = 3`, `_viewWeight = 0.1`, `_decayExponent = 1.5`, `_decayOffset = 2`) ตาม Risk R1 เดิมที่ backlog ระบุไว้แล้ว

## Requirements (UI)

**1. เอา "N โพสต์" ออกจาก `HashtagRankRow`** — เปลี่ยนบรรทัด meta จาก `'${item.postCount} โพสต์ · กำลังนิยมใน ไทย'` เหลือแค่ **`'กำลังนิยมใน ไทย'`** (ไม่แทนที่ด้วยตัวเลขอื่นเช่น score ดิบ — Founder สั่งห้ามระบุจำนวนใดๆ ใต้แฮชแท็ก ไม่ใช่แค่ "โพสต์")
- อัปเดต Semantics label ให้เอา `${item.postCount} โพสต์` ออกด้วย (บรรทัด 30 ของไฟล์เดิม) — เหลือ `'อันดับที่ $rank #${item.tag} กดเพื่อดูโพสต์ที่มีแฮชแท็กนี้'`

**2. อันดับเปลี่ยนไปใช้ `score` แทน `postCount`** ทั้ง `DiscoveryView`'s preview list และ `Top100Screen`'s full list (ทั้งคู่ใช้ `HashtagRankRow`/`RankedHashtag` ร่วมกันอยู่แล้ว ไม่ต้องแก้ 2 ที่แยกกัน)

## Edge Cases

1. **แฮชแท็กใหม่เอี่ยม โพสต์เดียว engagement สูง vs แฮชแท็กเก่าสะสมมาหลายโพสต์**: ตาม time-decay `(hours+2)^1.5` โพสต์ใหม่ที่ไวรัลจะได้คะแนนสูงกว่าธรรมชาติ — ตรงตามที่ Founder ต้องการ ("นับจากไวรัลตอนนั้น") ไม่ต้องแก้อะไรเพิ่ม
2. **โพสต์ view_count เป็น null** (Pop ที่ยังไม่มี view หรือ Drop เก่า) — ใช้ `?? 0` (มีอยู่แล้วใน `HomeFeedItem`) ไม่ error
3. **โพสต์เพิ่งสร้างวินาทีนี้ (hours≈0)**: `(0+2)^1.5 ≈ 2.83` ไม่มีปัญหาหาร 0 — offset `+2` ป้องกันตรงนี้อยู่แล้วตามที่ออกแบบไว้
4. **Tie score เท่ากันเป๊ะ (พบยากแต่เป็นไปได้ เช่นแฮชแท็กที่ยังไม่มีโพสต์เลยในหน้าต่างเวลา)**: sort รอง (tie-break) ด้วย `postCount` มากกว่าอยู่ก่อน (deterministic ordering ไม่ random)
5. **แฮชแท็กที่ไม่มีการโพสต์ใหม่เลยในหน้าต่าง 48 ชม.**: หายไปจากลิสต์ทันที (พฤติกรรมเดิมอยู่แล้ว เพราะ candidate window ไม่เปลี่ยน)

## Acceptance Criteria
- [ ] อันดับแฮชแท็กเปลี่ยนตามสูตร engagement+time-decay ไม่ใช่นับโพสต์ดิบอีกต่อไป
- [ ] ใต้ชื่อแฮชแท็กใน Discovery preview และ Top100Screen ไม่มีตัวเลขจำนวนใดๆ อีก (ทั้ง UI และ Semantics label)
- [ ] โพสต์ engagement สูงแต่ใหม่ ขึ้นอันดับสูงกว่าโพสต์เก่าที่มีจำนวนโพสต์เยอะกว่าแต่ engagement ต่ำ (ทดสอบด้วยข้อมูลจำลอง)
- [ ] Weight/decay เป็นค่าคงที่แยกจาก logic หลัก ปรับได้โดยไม่ต้องแก้สูตร

## Dependencies
ไม่มี (ทำงานอิสระ ไม่ผูกกับ WYN-097/099/100)

## Out of Scope (รอบนี้)
- ปรับ weight ให้ optimal จากข้อมูลจริง (Founder ต้องเห็นผลจริงก่อนถึงจะปรับ — รอบนี้ใช้ draft ตามที่เสนอ)
- ย้าย ranking ไปทำฝั่ง server/RPC (คงไว้ที่ Dart client-side เหมือนสถาปัตยกรรมเดิมของ `discovery_ranking.dart` — ข้อมูลที่ใช้มีจำกัดแค่ candidate window อยู่แล้ว ไม่มีประโยชน์ที่จะย้ายไป server รอบนี้)
- ขยาย candidate window เกิน 48 ชม./100 โพสต์ (ไม่ได้ถูกร้องขอ)
- แคช/persist trending score (คำนวณสดทุกครั้งที่เปิดหน้าเหมือนเดิม)

## Risks

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | สูตรที่เสนอเป็น draft แรก อาจต้องปรับ weight หลัง Founder เห็นผลจริง | ต่ำ | Weight เป็นค่าคงที่แยก ปรับได้ไม่ต้องแก้ logic |
| R2 | ลบ `postCount` ออกจาก UI อาจกระทบเทสเดิมที่ assert ข้อความ "N โพสต์" | ต่ำ | grep หา test ที่ assert ข้อความนี้ก่อนแก้ (`hashtag_rank_row_test.dart`/`discovery_view_test.dart`/`top_100_screen_test.dart` ถ้ามี) แก้ให้ตรงกับ UI ใหม่ |

## Recommendation
อนุมัติสูตรที่เสนอเป็นจุดเริ่มต้น งานนี้เสี่ยงต่ำและไม่มี schema impact เลย — ทำได้เร็ว

## Handoff
ส่งต่อ **AI Coding** (`/code`) โดยตรง — ไม่จำเป็นต้องผ่าน AI Design เต็มรูปแบบ (แก้แค่ logic การคำนวณ + ลบ 1 บรรทัดข้อความ ไม่มีหน้าจอใหม่/state ใหม่) → AI QA (ทดสอบด้วยข้อมูลจำลองหลายเคสตาม Edge Cases ข้างบน โดยเฉพาะเคส "ใหม่ไวรัล vs เก่าสะสม")
