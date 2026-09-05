# QA & Security — รอบ 2 — WYN-106 / 107 / 108 / 109

วันที่: 2026-09-04
Branch: `claude/home-button-ux-ui-design-cbjkzm`
รอบ 1: `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa.md` (106 PASS · 107 PASS · 108 FAIL · 109 FAIL)

## Final Status: **PASS**

| งาน | รอบ 1 | รอบ 2 |
|---|---|---|
| WYN-106 ระบบปุ่มหน้า Home | PASS | **PASS** (ตรวจซ้ำ ไม่ถอยกลับ) |
| WYN-107 การ์ดฟีดสองคอลัมน์ | PASS | **PASS** (ตรวจซ้ำ ไม่ถอยกลับ) |
| WYN-108 หัวใจทรง lucide | FAIL | **PASS** |
| WYN-109 เลือกอัตราส่วนรูป | FAIL | **PASS** |

`flutter analyze` — No issues found
`flutter test` — **1253/1253 ผ่าน** (รอบ 1 อยู่ที่ 1188 · รอบนี้เพิ่ม 65 ตัว)

---

## ข้อจำกัดของรอบนี้ที่ Founder ควรรู้

รอบนี้เริ่มโดย subagent บทบาท AI QA & Security แต่ subagent **ถูกตัดกลางคัน**เพราะชน session
rate limit หลังเขียนเทสต์เสร็จแต่ยังไม่ได้เขียนรายงาน งานที่เหลือ (รันชุดเทสต์เต็ม, สแกน secret,
ตรวจกติกาไฟล์ Pop, เขียนรายงานฉบับนี้) ทำต่อโดย session หลัก — ซึ่งเป็น session เดียวกับที่เขียนโค้ด

นั่นแปลว่า **ความเป็นอิสระของ QA รอบนี้ต่ำกว่ารอบ 1** เทสต์ทั้ง 58 ตัวในหมวด QA-R2 เขียนโดย
subagent ที่ไม่ได้เขียนโค้ด (เป็นอิสระจริง) แต่การตัดสินว่า "ครบพอ" ทำโดยผู้เขียนโค้ดเอง
ถ้าต้องการความมั่นใจสูงสุดก่อนขึ้น production ควรสั่ง QA รอบ 3 ด้วย session ใหม่หลัง rate limit reset

---

## 1. บั๊ก 4 ตัวจากรอบ 1 — ยืนยันว่าแก้จริง

เทสต์เดิมที่แถมมากับการแก้บั๊กหลายตัว **ตรวจด้วยการอ่านข้อความในซอร์ส** (`source.contains(...)`)
ซึ่งจับได้แค่การ revert แบบตรงตัว เปลี่ยนชื่อตัวแปรหรือแก้ค่าให้คงที่ก็ยังผ่าน รอบนี้จึงเพิ่มเทสต์
ที่วัด **สิ่งที่แอปวาดจริง** และ **JSON ที่ออกจากแอปจริง** แทน

| บั๊ก | ระดับ | เทสต์ที่ยืนยัน | ผล |
|---|---|---|---|
| B-109-1 `_insertDrop` ส่ง `image_aspect_ratio` เสมอ | Critical | QA-R2-12/13/14 — อ่าน payload ระดับ HTTP จริง ทั้งโพสต์ข้อความล้วน, Draft ที่ republish จาก URL เดิม, Poll Drop (ผ่าน RPC) | PASS |
| B-108-1 หัวใจในคอมเมนต์ 16→24px | Major | QA-R2-25 — วัดขนาดที่ render จริง เทียบกับไอคอนลบข้าง ๆ | PASS |
| B-109-2 Drop Detail บังคับ 4:5 | Major | QA-R2-15/16/17/18 — ฟีดกับหน้าโพสต์ต้องได้ค่าตรงกันเป๊ะ, `original` ต้องกลับไปใช้สัดส่วนไฟล์จริง, โพสต์เก่าต้องได้ 4:5 พอดี | PASS |
| B-109-3 พรีวิวตอนโพสต์กรอบตายตัว | Major | QA-R2-23/24 — วัดกรอบที่ render จริง + ตรึงสูตร `160 × ratio` (128 / 160 / 284.44) | PASS |

---

## 2. งานใหม่: อ่านอัตราส่วนโดยไม่แตะ view (`_fetchAspectRatios`)

เป็นของที่ยังไม่เคยผ่าน QA มาก่อน ตรวจละเอียดที่สุดในรอบนี้ ด้วย fake REST client ที่ดัก
HTTP request จริงที่ออกจาก `HomeRepository`

**จุดเสี่ยงที่สุด — index shift ใน `Future.wait`** (`aspectRatios` เข้าไปเป็น `results[6]`
ดัน `blockedAuthorIds` ไปเป็น `results[7]` ผ่าน `if` ใน list literal ซึ่งเปลี่ยนความยาว list
ตามเงื่อนไข ถ้าสลับกันจะเป็น cast error ตอน runtime):

- QA-R2-1 `fetchFeed` (ไม่มี `authorIdsForBlockCheck`) → `results[6]` ถูกต้อง PASS
- QA-R2-2/3 `fetchTrending`/`fetchTopContent` (มี `authorIdsForBlockCheck`) → `results[7]` เป็นชุด
  block check จริง และ `[6]` ยังเป็นอัตราส่วน PASS
- QA-R2-4 `fetchItemById` (แถวเดียว) PASS

**fallback ทุกเส้นทาง**:

- QA-R2-5 query ตาราง `drops` ล้ม → ทุกการ์ดได้ 4:5 ฟีดไม่พัง PASS
- QA-R2-6 ฐานข้อมูลยังไม่มีคอลัมน์ → 4:5 PASS
- QA-R2-7 หน้าที่ไม่มีรูปเลย → **ไม่ยิง query ตาราง `drops` เลย** PASS
- QA-R2-8 drop ที่ lookup ไม่ตอบ → 4:5 PASS
- QA-R2-9 ค่าขยะในคอลัมน์ → fallback ไม่ throw PASS
- QA-R2-11 แถว Pop → ไม่ถูกถามบนตาราง `drops` PASS

**ความปลอดภัย / การรั่วข้อมูล** (QA-R2-10):

`_fetchAspectRatios` ยิงตาราง `drops` ตรง ๆ ไม่ผ่าน view ที่กรอง mute — จึงต้องพิสูจน์ว่าไม่มีทางรั่ว

- request ที่ออกไปมีเฉพาะ id ที่ view คืนมาแล้วเท่านั้น ไม่มี id ของผู้ถูกมิวต์ PASS
- select เฉพาะ 2 คอลัมน์ (`id%2Cimage_aspect_ratio`) ไม่มี caption ไม่มีข้อมูลผู้เขียน PASS
- ถ้าเซิร์ฟเวอร์ตอบ id ที่ไม่ได้ถาม แถวส่วนเกิน **สร้างการ์ดไม่ได้** (map เข้ากับแถวจาก view เท่านั้น) PASS
- RLS: query วิ่งด้วยสิทธิ์ผู้ใช้เดิมผ่าน PostgREST เหมือนทุก query ในแอป ไม่ได้ยกสิทธิ์ ไม่แตะ
  service_role

**performance**: อยู่ใน `Future.wait` ชุดเดิม → ขนานกับอีก 6 query ที่หน้านั้นจ่ายอยู่แล้ว
ไม่เพิ่ม round-trip · ไม่ยิง query เมื่อหน้านั้นไม่มี drop ที่มีรูป

---

## 3. `supabase/schema.sql`

commit ก่อนหน้าเผลอเพิ่มคอลัมน์เข้านิยาม view ทั้ง 3 จุดใน `schema.sql` ทั้งที่ตัดสินใจแล้วว่า
**จะไม่แก้ view บน production ตลอดไป** ปล่อยไว้ = ไฟล์ schema บรรยายสิ่งที่ฐานข้อมูลจริงไม่มี
ซึ่งคือโรคเดียวกับ SCHEMA-004

แก้แล้ว: 3 จุดนั้น revert กลับให้ตรง `origin/main` + เพิ่มคอมเมนต์อธิบายว่าทำไมจงใจไม่ใส่
ตอนนี้ `schema.sql` ต่างจาก main แค่ `alter table ... add column` + CHECK constraint
ซึ่งตรงกับสิ่งที่ Founder รันขึ้น production ไปแล้วจริงเป๊ะ

ตรวจแล้วว่าไม่มีที่ไหนในโค้ดพึ่งพา view ที่มีคอลัมน์นี้ (`HomeFeedItem.fromMap` อ่านจาก
พารามิเตอร์ที่ batch มาก่อน แล้วค่อย fallback ไปที่ row ซึ่งจะเป็น null ตลอดไป → ได้ 4:5
เฉพาะกรณีที่ batch ไม่ตอบ)

---

## 4. Regression ของงานเดิม

- QA-R2-19 WYN-106 ปุ่มปิดแบนเนอร์ยัง 44×44 PASS
- QA-R2-20 WYN-108 หัวใจ liked ยัง `#F44336` · idle ยัง graphite · ไม่กลายเป็น sapphire PASS
- QA-R2-21 WYN-107 คอลัมน์เนื้อหายังเริ่มที่ x=78 บนจอ 390 · แถวรูปยังชนขอบขวา PASS
- QA-R2-22 responsive 320/360/390/430 × textScale 1.0/1.3 × 4 อัตราส่วน = **32 เคส ไม่ overflow เลย** PASS
- WYN-104 ครอปรูปโปรไฟล์ — เทสต์เดิมใน `profile_photo_crop_test.dart` ยังผ่านครบ ไม่มีอะไรเปลี่ยน PASS

---

## 5. กติกาบังคับ

| กติกา | ผล |
|---|---|
| ห้ามแตะไฟล์ Pop — `git diff --name-only <base>...HEAD -- app/lib/features/pop/` | **ว่างเปล่า** PASS |
| ห้าม commit secret | สแกน diff ทั้งหมด: ไม่พบ key/token/credential จริง (เจอแต่คำว่า "token" ในคอมเมนต์เรื่อง design token) PASS |
| ไม่มีไฟล์ `dart_define.json` / `.env` เข้า diff | PASS |
| AI ห้ามรัน SQL กับ production เอง | ไม่มีการรันใด ๆ — Founder รันเองทั้งหมด PASS |
| 6 จุดที่ Founder สั่งห้ามย้อนกลับ | PASS (สีหัวใจยืนยันด้วย QA-R2-20 · แท็บ/ไอคอนแชท/ฟอนต์/พื้นขาว: ไฟล์ที่เกี่ยวข้อง diff ว่างเปล่า) |

---

## 6. สิ่งที่ยังไม่ครบ (ไม่ block แต่ต้องบันทึก)

1. ~~หน้า Saved ยังวาด 4:5 ทุกรูป~~ **แก้ไข 2026-09-05: ข้อสังเกตนี้ผิด** ตรวจซ้ำพบว่า Saved
   ไม่เคยแสดงอัตราส่วนรูปเลยในทุกที่ที่มันแสดงเนื้อหา — เป็นแค่ thumbnail สี่เหลี่ยมจัตุรัสตายตัว
   ตรงกับ convention เดียวกันของ Drop/Draft grid และ Founder เคยอนุมัติให้ Saved คงเป็น Grid ไว้แล้ว
   ไม่ใช่ gap ของ WYN-109 — ดู `.wyn/tasks/completed/WYN-109-post-image-aspect-ratio.md`
2. **SCHEMA-004 ยัง open** — view `home_feed` บน production ยังเพี้ยนจาก `schema.sql`
   ตอนนี้ไม่ block งานไหนแล้ว แต่ migration ตัวไหนก็ตามที่ redefine view ในอนาคตจะล้มแบบเดิม
3. **ยังไม่ได้ทดสอบบนเครื่องจริง** — เทสต์ทั้งหมดเป็น widget/unit test ในแซนด์บ็อกซ์
   ยังไม่มีใครเปิดแอปจริงแล้วโพสต์รูป 16:9 ดูด้วยตา ควรทำหลัง deploy
