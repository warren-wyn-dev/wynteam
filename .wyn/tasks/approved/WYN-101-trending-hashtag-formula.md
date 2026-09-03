# Feature Request — WYN-101

Status: QA PASS — approved (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 10/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เปลี่ยนสูตรจัดอันดับแฮชแท็กกำลังนิยมเป็นแบบอิง engagement + เอาตัวเลขจำนวนโพสต์ออก
Goal: อันดับแฮชแท็กสะท้อนความไวรัล/การมีส่วนร่วมจริง ไม่ใช่แค่จำนวนโพสต์ดิบ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "แฮชแท็กกำลังนิยม ควรนับจากเอนเกจเม้น ไม่ใช่นับจากจำนวนโพสต์อย่างเดียว นับจากไวรัลตอนนั้น ปล. ใต้แฮชแท็ก ห้ามระบุว่ากี่โพสต์" — Founder ให้ AI เสนอสูตร
Requirements:
- **สูตรที่เสนอ**: trending_score = (likes×1 + comments×2 + reposts×3 + views×0.1) หารด้วย (ชั่วโมงตั้งแต่โพสต์ + 2)^1.5 — ให้น้ำหนักคอมเมนต์/รีโพสต์มากกว่าไลค์ (engagement ที่ "แรง" กว่า) และมี time-decay ให้แฮชแท็กที่ไวรัล "ตอนนี้" ขึ้นก่อนแฮชแท็กเก่าที่สะสมมานาน
- รวมคะแนนทุกโพสต์ที่ติดแฮชแท็กเดียวกันในช่วงเวลาที่กำหนด (เช่น 7 วันล่าสุด) แล้วจัดอันดับ
- เอาข้อความ "N โพสต์" ที่แสดงใต้แฮชแท็กในหน้าค้นหาออกทั้งหมด
Acceptance Criteria:
- [x] อันดับแฮชแท็กเปลี่ยนตามสูตร engagement ไม่ใช่นับโพสต์ดิบ
- [x] ใต้ชื่อแฮชแท็กไม่มีตัวเลขจำนวนโพสต์อีก
Dependencies: ไม่มี
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | สูตรที่เสนอเป็น draft แรก อาจต้องปรับ weight หลัง Founder เห็นผลจริง | ต่ำ | ทำ weight เป็นค่าคอนฟิกปรับได้ ไม่ hardcode ฝัง logic — **ปิดแล้ว**: ประกาศเป็น `static const` แยกหัวไฟล์ |
Recommendation: อนุมัติสูตรที่เสนอเป็นจุดเริ่มต้น — ปรับ weight ได้ภายหลังถ้า Founder เห็นผลแล้วไม่ตรงใจ
Handoff: AI Product Manager ยืนยันสูตร/ช่วงเวลาย้อนหลัง → AI Coding → AI QA (ทดสอบด้วยข้อมูลจำลองหลายเคส)

## Product Full Spec Output (2026-09-02)

เขียน full spec เสร็จแล้วที่ `.wyn/docs/product/wyn-101-trending-hashtag-formula.md` — ยืนยันสูตร draft ตามที่เสนอ (`(likes×1+comments×2+reposts×3+views×0.1)/(ชม.+2)^1.5`) เป็นฐาน ไม่ต้องแก้ schema/migration เลยเพราะ engagement fields ที่ต้องใช้มีอยู่แล้วใน `HomeFeedItem` ที่ `fetchTrendingHashtags()` ดึงมาอยู่แล้ว — คำนวณฝั่ง Dart ล้วนๆ เหมือนสถาปัตยกรรมเดิม ไม่ต้องมี RPC ใหม่ — เอา "N โพสต์" ออกจาก `HashtagRankRow` ตรงตามที่ Founder สั่ง (พบว่านี่คือการพลิกมติครั้งที่ 2 — เคยถูกเพิ่มเข้ามาโดย Founder-approved re-brand เมื่อ 2026-08-29 มาก่อน บันทึกไว้เพื่อความชัดเจน ไม่ใช่ความขัดแย้ง)

ไม่มีจุดที่ต้อง ping Founder เพิ่ม — งานนี้ตรงไปตรงมา เสี่ยงต่ำ

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-101-trending-hashtag-formula.md`

Handoff: ส่งต่อ AI Coding (`/code`) โดยตรง ไม่ต้องผ่าน AI Design เต็มรูปแบบ

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — เขียนสูตรจัดอันดับใหม่ทับของเดิม (นับความถี่ดิบ) ตามที่ product spec ระบุไว้แบบละเอียดพร้อม pseudocode พร้อมใช้เกือบทั้งหมด

การเปลี่ยนแปลง:
1. **`discovery_ranking.dart`**: เขียน `rankTrendingHashtags()` ใหม่ทั้งฟังก์ชัน — รับ `Iterable<HomeFeedItem>` แทน `Iterable<String?>` (captions), คำนวณ `_trendingScore()` ต่อโพสต์แล้วบวกสะสมเข้าทุก tag ที่โพสต์นั้นมี, weight/decay เป็น `static const` แยกหัวไฟล์ตามที่ Risk R1 กำหนด (`_likeWeight=1, _commentWeight=2, _repostWeight=3, _viewWeight=0.1, _decayOffset=2, _decayExponent=1.5`) — `RankedHashtag` เพิ่มฟิลด์ `score` (ใหม่, ใช้จัดอันดับ) เก็บ `postCount` ไว้ (ใช้แค่ tie-break ภายใน ไม่โชว์ UI แล้ว) — เพิ่ม parameter `now` (optional, inject ได้) เพื่อให้เทส time-decay ได้ deterministic
2. **`discovery_repository.dart`**: `fetchTrendingHashtags()` ส่ง `items` (full `HomeFeedItem` list) เข้า `rankTrendingHashtags()` ตรงๆ แทนที่จะ map เอาแค่ `caption` ออกมาก่อน (ต้องใช้ engagement fields ด้วยแล้ว)
3. **`hashtag_rank_row.dart`**: ลบ "${item.postCount} โพสต์ · " ออกจาก meta text เหลือแค่ "กำลังนิยมใน ไทย" — ลบ `${item.postCount} โพสต์` ออกจาก Semantics label ด้วย

**ไม่ได้แตะ**: `HashtagSuggestion`/`hashtag_repository.dart` (ระบบ autocomplete ตอนพิมพ์แฮชแท็กในช่องแคปชัน — คนละฟีเจอร์ ใช้ `postCount` ของตัวเองที่ไม่เกี่ยวกับ trending ranking นี้เลย นอกสโคป), candidate window (ยังคง 48 ชม./100 โพสต์เดิมของ `HomeRepository.fetchTrending()`)

Files Changed:
- `app/lib/features/search/data/discovery_ranking.dart` — เขียนสูตรใหม่ทั้งฟังก์ชัน
- `app/lib/features/search/data/discovery_repository.dart` — ส่ง `items` เต็มแทน `captions`
- `app/lib/features/search/presentation/widgets/hashtag_rank_row.dart` — ลบ post count ออกจาก UI+Semantics
- `app/test/discovery_ranking_test.dart` — เขียนใหม่ทั้งไฟล์ (12 เทส) ให้ตรงกับ signature ใหม่ + เทส engagement weighting/time-decay/tie-break ที่ไม่เคยมีมาก่อน
- `app/test/top_100_screen_test.dart`, `app/test/discovery_view_test.dart` — แก้ `RankedHashtag(...)` ให้มี `score:`, ลบ assertion ข้อความ "N โพสต์ · กำลังนิยมใน ไทย" (ตรงตาม Risk R2 ที่ product spec เตือนไว้ล่วงหน้า)

Reason: Founder ข้อ 10/28 — "แฮชแท็กกำลังนิยม ควรนับจากเอนเกจเม้น ไม่ใช่นับจากจำนวนโพสต์อย่างเดียว นับจากไวรัลตอนนั้น ปล. ใต้แฮชแท็ก ห้ามระบุว่ากี่โพสต์"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **917/917 ผ่านหมด** (910 เดิม + 7 เทสใหม่สุทธิ — เขียนใหม่ 5 เทสเดิม + เพิ่ม 7 เทสใหม่ ลบ 5 assertion เก่าที่ผูกกับ UI เดิม)
- Red→green พิสูจน์จริงผ่านเทสใหม่หลายเคสตาม Acceptance Criteria ของ product spec:
  - "โพสต์ engagement สูงแต่ใหม่ ขึ้นอันดับสูงกว่าโพสต์เก่าที่มี postCount เยอะกว่า" — เทส "a new post going viral right now outranks an older post..." (แฮชแท็ก 1 โพสต์ engagement สูงแต่โพสต์เมื่อ 10 นาทีก่อน ชนะแฮชแท็กที่ engagement สูงกว่ามากแต่โพสต์เมื่อ 30 วันก่อน)
  - "คอมเมนต์/รีโพสต์หนักกว่าไลค์" — เทส "the same interaction count weighs more when it is comments or reposts than when it is plain likes" (10 interactions เท่ากันเป๊ะ แค่ประเภทต่าง ผลจัดอันดับ: reposts > comments > likes)
  - Edge Case 3 (หาร 0): เทส "a post created this instant does not divide by zero"
  - Edge Case 4 (tie-break): เทส "ties on score break deterministically by higher postCount"
  - Edge Case 2 (view_count null): เทส "a null viewCount counts as 0, not a crash"

Build: ไม่ได้รัน `flutter build` จริง — ไม่แตะ backend/schema เลย (pure Dart client-side ranking ตามที่ product spec ยืนยันไว้)

Known Issues:
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator) — UI ที่เปลี่ยน (ลบ "N โพสต์") เป็นการลบข้อความบรรทัดเดียว ความเสี่ยง regression ต่ำมาก แต่ควรดูภาพจริงอีกชั้น
- Weight/decay เป็นค่า draft แรกตามที่ Founder อนุมัติ ยังไม่ได้ปรับจากข้อมูลจริง (ตามที่ระบุไว้ใน Out of Scope ของ product spec ว่ารอบนี้ยังไม่ต้องทำ)

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงที่ Discovery preview และ Top100Screen ว่าไม่มีตัวเลขจำนวนโพสต์อีก (2) ทดสอบด้วยข้อมูลจำลองหลายเคสตาม Edge Cases ของ product spec โดยเฉพาะเคส "ใหม่ไวรัล vs เก่าสะสม" (มีเทส unit test ครอบคลุมแล้ว แต่ควรยืนยันกับข้อมูลจริงเพิ่ม) (3) ยืนยัน pull-to-refresh ยังทำงานถูกต้อง (ไม่แตะ flow นี้แต่เป็นจุดที่เรียก `fetchTrendingHashtags()` ซ้ำ)

## QA Report (2026-09-02)

```
Feature: สูตรจัดอันดับแฮชแท็กกำลังนิยมเปลี่ยนเป็น engagement-weighted + time-decay, ลบ "N โพสต์" ออกจาก UI
Environment: อ่านโค้ดจริง (adversarial) + คำนวณสูตรมือทวนกับเทสจริง + รัน `flutter analyze`/`flutter test` อิสระ
Test Cases:
  1. อ่าน discovery_ranking.dart ยืนยันสูตรตรงกับที่เอกสารระบุเป๊ะ: `(likes×1+comments×2+reposts×3+views×0.1)/(ชม.+2)^1.5`, weight เป็น `static const` แยกหัวไฟล์จริง (ปิด Risk R1)
  2. **คำนวณมือทวนเคส "โพสต์ใหม่ไวรัลชนะโพสต์เก่าสะสมเยอะ"**: เก่า (likes 1000/comments 500/reposts 200, อายุ 30 วัน=720ชม.) → engagement=2600, decay=(722)^1.5≈19,400 → score≈0.134 | ใหม่ (likes 50/comments 30/reposts 20, อายุ 10 นาที≈0.167ชม.) → engagement=170, decay=(2.167)^1.5≈3.19 → score≈53.3 — **53.3 >> 0.134 ยืนยันว่าเทสพิสูจน์ acceptance criteria จริง ไม่ใช่แค่ "มีการจัดอันดับเกิดขึ้น"**
  3. อ่านเทส "comments/reposts หนักกว่า likes ที่จำนวนเท่ากัน" ยืนยัน logic ถูกต้อง (weight 1/2/3 ตามลำดับ)
  4. ตรวจ edge case หาร 0 (`_decayOffset=2` กันไม่ให้ hours+2 เป็น 0), viewCount null→0, tie-break ด้วย postCount — อ่านโค้ดยืนยันตรงกับเทสทั้งหมด
  5. grep `"โพสต์"` ใน hashtag_rank_row.dart ยืนยันลบออกจริงทั้ง UI text และ Semantics label
  6. ยืนยัน discovery_repository.dart/top_100_screen.dart ใช้ HomeRepository ที่ผ่านการ filter Pop ของ WYN-102 อยู่แล้ว (ตรวจร่วมกับ WYN-102 — เห็นความสอดคล้องข้ามงาน)
  7. รัน `flutter analyze` อิสระ: สะอาด
  8. รัน `flutter test` อิสระเต็ม suite: 917/917 ผ่าน
Passed: ทั้ง 8 ข้อข้างต้น
Failed: ไม่มี
Severity: -
Reproduction Steps: -
Expected: -
Actual: -
Security Findings: ไม่พบ — pure Dart client-side ranking ไม่แตะ backend/schema
Recommendation: อนุมัติ — สูตรเป็น draft แรกตามที่ Founder อนุมัติ ยังไม่ปรับจากข้อมูลจริง (ตามที่ระบุไว้แล้วว่าเป็น future work ไม่ block รอบนี้)
Final Status: PASS
```
