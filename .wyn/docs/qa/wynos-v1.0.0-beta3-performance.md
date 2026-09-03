# WYNOS v1.0.0 Beta3 — Performance

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta3-polish-performance-aes6ld` — **ยังไม่ push · ยังไม่ deploy**
> Environment: PostgreSQL 16.13 ในเครื่อง (เวอร์ชันเดียวกับที่ Beta2 ใช้ตรวจ) · Flutter 3.47.1

---

## 0. ตัวเลขไหนจริง ตัวเลขไหนไม่มี — อ่านก่อน

ข้อ 30 ของ Founder เขียนไว้ว่า *"ถ้าไม่มีตัวเลขจริง อย่าสร้างตัวเลขขึ้นมาเอง"* เอกสารนี้เคารพข้อนั้นตรง ๆ

| ประเภท | มีหรือไม่ | ที่มา |
|---|:--:|---|
| จำนวน request / round trip | ✅ มี | นับจากโค้ดตรง ๆ ก่อน/หลัง |
| DB query plan + เวลา execute | ✅ มี | `EXPLAIN (ANALYZE, BUFFERS)` บน PostgreSQL 16.13 ในเครื่อง 20,000 drops / 12,000 drop_images |
| หน่วยความจำที่ decode รูป | ✅ คำนวณได้ | สูตร `width × height × 4 bytes` + ค่าที่ยืนยันด้วย test จริง |
| API latency จริง | ❌ **ไม่มี** | ไม่มี Supabase production credential ใน session นี้ |
| เวลาเปิด Post Detail บนเครื่องจริง | ❌ **ไม่มี** | ไม่มีอุปกรณ์ ไม่มี profile run |
| memory profile / frame time | ❌ **ไม่มี** | ต้องรัน DevTools บนเครื่องจริง |
| RLS performance บน production data | ❌ **ไม่มี** | ข้อมูลในเครื่องเป็นข้อมูล seed ไม่ใช่ของจริง |

สิ่งที่ยังวัดไม่ได้ **ไม่ได้ถูกเดาแทน** — ถูกยกไปเป็นงานที่ต้องทำบนเครื่องจริง (§6)

---

## 1. รูปในโพสต์หลายรูป — N+1 ต่อการ์ด

### ก่อน

`HomeFeedImagePeekCarousel` เรียก `fetchDropImages(item.id)` จาก `initState` ของตัวเอง
การ์ดหนึ่งใบ = หนึ่ง request และยิง **หลังจาก** หน้าขึ้นแล้ว

```
โหลดหน้า feed (1 request)  →  หน้าขึ้น  →  การ์ดที่มีหลายรูป mount
                                            → 8 request ทยอยกลับมา
                                            → รูปเดี่ยวสลับเป็น carousel ใต้นิ้วทีละอัน
```

เปิดโพสต์นั้นต่อ → `DropImageGallery` ยิง `fetchDropImages` **ซ้ำอีกครั้ง** สำหรับ URL ชุดเดิม

### หลัง

`HomeRepository._fetchImageUrls(rows)` ดึงรูปของทั้งหน้าใน query เดียว รวมอยู่ใน `Future.wait`
ชุดเดิมที่ดึง viewer state อยู่แล้ว → **ไม่เพิ่ม latency แม้แต่รอบเดียว** แล้วส่งรายการรูปลงไปกับ
`HomeFeedItem.imageUrls` → `Drop.imageUrls` → `DropImageGallery`

| | ก่อน | หลัง |
|---|---|---|
| Feed 1 หน้า (10 โพสต์ มีหลายรูป 8) | **8 request** ยิงหลังหน้าขึ้น | **1 request** ขนานไปกับ viewer state |
| เปิดโพสต์หลายรูปจาก feed | 1 request | **0 request** |
| หน้าที่ไม่มีโพสต์หลายรูปเลย | 0 | **0** (มี early-return ก่อนยิง query) |
| เฟรมแรกของ carousel | รูปเดียว แล้วค่อยสลับ | ครบทุกรูปตั้งแต่เฟรมแรก |

Path ที่ไม่ได้พก list มาด้วย (Profile 3 แท็บ, hashtag feed ที่สร้างการ์ดจาก `Drop` ตรง ๆ)
ยัง fallback ไป `fetchDropImages` เหมือนเดิมทุกประการ — ไม่มี path ไหนเสียความสามารถไป

---

## 2. Query plan ของ batch query — วัดจริง

รันบน PostgreSQL 16.13 ในเครื่อง, 20,000 `drops` / 12,000 `drop_images` (4,000 โพสต์ × 3 รูป), `analyze` แล้ว
ทั้งสองเคสรันใต้ `set role authenticated` พร้อม `request.jwt.claim.sub` จริง **เพื่อให้ RLS ทำงานเหมือนของจริง**

### ก่อน — query ที่การ์ดหนึ่งใบยิง (แอปยิง 8 ครั้ง)

```
Sort (actual rows=3 loops=1)
  -> Bitmap Heap Scan on drop_images (actual rows=3 loops=1)
       -> Bitmap Index Scan on drop_images_drop_id_position_key (actual rows=3)
          SubPlan 1 (RLS re-check)
            -> Index Scan using drops_pkey on drops d (actual rows=1 loops=3)
Planning Time: 0.519 ms
Execution Time: 1.775 ms
```

### หลัง — query เดียวสำหรับทั้งหน้า (8 โพสต์, id อยู่ในมือแล้ว)

```
Sort (actual rows=24 loops=1)
  -> Bitmap Heap Scan on drop_images (actual rows=24 loops=1)
       Recheck Cond: (drop_id = ANY ('{...8 uuid...}'::uuid[]))
       -> Bitmap Index Scan on drop_images_drop_id_position_key (actual rows=24)
          SubPlan 1 (RLS re-check)
            -> Index Scan using drops_pkey on drops d (actual rows=1 loops=24)
Planning Time: 0.458 ms
Execution Time: 2.119 ms
```

| | BEFORE (×8) | AFTER (×1) | ผล |
|---|---:|---:|---|
| Round trip | 8 | **1** | −87.5% |
| Planning time รวม | 4.15 ms | **0.46 ms** | −89% |
| Execution time รวม | 14.20 ms | **2.12 ms** | −85% |
| งาน DB รวม | 18.35 ms | **2.58 ms** | **−86%** |
| RLS subplan loops | 24 (3×8) | 24 | เท่าเดิม — ไม่ได้แย่ลง |

* ตัวเลข "×8" คือค่าเดี่ยวคูณ 8 ตรง ๆ (แอปยิง 8 query จริง) ไม่ใช่ค่าที่วัดรวมทีเดียว
* Execution time เป็นเวลา **ฝั่ง database ล้วน** ไม่รวมเวลาเดินทางบนเครือข่าย — ซึ่งเป็นส่วนที่ผู้ใช้รู้สึกมากที่สุด และเป็นส่วนที่ลดจาก 8 รอบเหลือ 1 รอบ
* จำนวน RLS subplan loop เท่าเดิมเพราะ policy ของ `drop_images` re-check ผ่าน `drops` **ต่อ 1 แถวรูป** ไม่ใช่ต่อ 1 โพสต์ — เป็นพฤติกรรมเดิม ไม่ใช่ของใหม่ที่ Beta3 สร้าง (บันทึกเป็น hardening ที่ยังไม่ทำใน security audit)

---

## 3. Viewer state — 4 round trip เรียงกัน เหลือ 1 ชุดขนาน

`DropRepository` ทุก fetch path ทำแบบนี้:

```dart
final likedIds     = await _fetchLikedDropIds(...);      // รอ
final savedIds     = await _fetchSavedDropIds(...);      // รอ
final redroppedIds = await _fetchRedroppedDropIds(...);  // รอ
final pollStates   = await _fetchPollStates(...);        // รอ
```

4 query ที่ **ไม่ขึ้นต่อกันเลย** แต่รอกันเป็นทอด ๆ ก่อนการ์ดแรกจะขึ้นได้
`HomeRepository` แก้ปัญหาเดียวกันนี้ไปแล้วและเขียนเหตุผลไว้ใน doc comment ของตัวเอง — `DropRepository` ไม่เคยได้รับการแก้แบบเดียวกัน

รวมเป็น `_fetchViewerState()` ตัวเดียวที่ยิงพร้อมกันด้วย `Future.wait`

| Path ที่ได้ผล | ก่อน | หลัง |
|---|---:|---:|
| `fetchFeed` | 4 | **1** |
| `searchByCaption` (แท็บโพสต์ในหน้า Search) | 4 | **1** |
| `fetchByAuthor` (Profile แท็บโพสต์) | 4 | **1** |
| `fetchLikedByAuthor` (Profile แท็บถูกใจ) | 4 | **1** |
| `fetchDrafts` | 4 | **1** |
| `fetchRankedFeed` | 5 | **1** |
| `fetchById` (ทุกครั้งที่กลับจาก Detail) | 4 | **1** |

**ไม่มีตัวเลข ms ให้** — ผลจริงขึ้นกับ round-trip latency ของเครือข่ายผู้ใช้ ซึ่ง session นี้วัดไม่ได้
สิ่งที่พูดได้อย่างซื่อสัตย์: **จำนวนรอบที่ต้องรอกันลดจาก 4 เหลือ 1** ผลเป็น ms คือ 3 × round-trip latency ต่อการโหลดหนึ่งหน้า

---

## 4. Index — ไม่เพิ่มแม้แต่ตัวเดียว

ข้อ 24 ห้ามสร้าง index แบบสุ่ม ตรวจแล้วว่า query ทุกตัวที่ Beta3 แตะมี index รองรับอยู่แล้ว

| Query | Index ที่รับงาน | ยืนยันด้วย |
|---|---|---|
| `drop_images where drop_id in (...) order by position` | `drop_images_drop_id_position_key` (unique constraint เดิม) | `EXPLAIN` §2 — Bitmap Index Scan |
| `drop_likes where user_id = ? and drop_id in (...)` | `drop_likes_pkey (drop_id, user_id)` | `pg_indexes` |
| `saves where user_id = ? and content_id in (...)` | `saves_pkey (user_id, content_type, content_id)` | `pg_indexes` |
| `redrops where redropper_id = ? and drop_id in (...)` | `redrops_standard_unique (drop_id, redropper_id)` | `pg_indexes` |
| `drops where id = ?` | `drops_pkey` | `EXPLAIN` §2 |

**Beta3 ไม่มี migration ไม่มี schema change ไม่มี index ใหม่** — ทั้งหมดเป็นการเปลี่ยนวิธีที่ฝั่ง Dart ถามคำถามเดิม

---

## 5. หน่วยความจำรูป

WYNOS บีบรูปที่อัปโหลดเป็น 1600×1600 (WYN-103) `Image.network` ดิบ decode เต็มขนาดนั้นเสมอ
ไม่ว่ากล่องที่วาดจริงจะเล็กแค่ไหน — bitmap ที่ค้างใน memory คือ `w × h × 4 bytes`

| จอ | ก่อน (decode เต็ม) | หลัง (decode เท่าที่วาด) | ลดลง |
|---|---:|---:|---:|
| iPhone 390pt กว้าง, DPR 3 | 1600×1600 = **10.2 MB** | 1170×1463 = **6.8 MB** | −33% |
| Android 412pt กว้าง, DPR 2 | 1600×1600 = **10.2 MB** | 824×1030 = **3.4 MB** | −67% |
| Web / DPR 1 | 1600×1600 = **10.2 MB** | 412×515 = **0.85 MB** | −92% |
| Peek carousel (การ์ดกว้าง 82%) | 10.2 MB/รูป | ตามสัดส่วนข้างบน × 0.82² | เท่ากันโดยประมาณ |

Feed ที่มีรูปมีชีวิตอยู่พร้อมกัน 5–6 รูปจึงลดจากราว **60 MB เหลือราว 20 MB** บนเครื่อง DPR 2

**นี่ไม่ใช่การแลกความคมชัด** — `cacheWidth` ถูกคำนวณเป็น *physical pixel* (`logicalWidth × devicePixelRatio`)
รูปจึง decode ที่ความละเอียดเต็มของกล่องที่มันวาดจริงเสมอ ตรรกะเดียวกับที่ `NetworkThumbnail` (WYN-103)
ใช้กับ grid tile อยู่แล้ว แค่ไม่เคยถูกนำมาใช้กับรูปหลักในโพสต์

**ยืนยันด้วย test:** `post_media_test.dart` — `PostImage` ในกล่อง 390pt ให้ `ResizeImage.width == 390 × DPR`

Path ที่แก้: Home feed (รูปเดียว), Peek carousel, Post Detail (รูปเดียว + gallery), Club post carousel
Path ที่ **ไม่แก้โดยตั้งใจ**: `DropImageViewer` (full screen pinch-to-zoom — ต้องได้ความละเอียดเต็ม), `AvatarCircle` (มี `ResizeImage` ของตัวเองอยู่แล้ว), `NetworkThumbnail` (bounded อยู่แล้ว)

---

## 6. ที่ยังวัดไม่ได้ — งานที่ต้องทำบนเครื่องจริง

รายการนี้คือสิ่งที่ต้องวัดก่อนจะบอกได้ว่า Beta3 "เร็วขึ้นจริง" ในสายตาผู้ใช้ ไม่ใช่แค่ "ยิง request น้อยลง"

1. **Feed initial load** — เวลาจากกด tab จนการ์ดแรกวาดเสร็จ (ก่อน/หลัง)
2. **Post Detail open** — เวลาจากแตะการ์ดจนรูปวาดเสร็จ คาดว่าดีขึ้นชัดสำหรับโพสต์หลายรูป (ตัด 1 request ออก) แต่ยังไม่ได้วัด
3. **memory profile** — DevTools บนอุปกรณ์จริง เลื่อน feed 100 โพสต์ ดู peak ของ image cache เทียบตัวเลขคำนวณใน §5
4. **frame time / jank** — `SliverAppBar` แบบ floating+snap เพิ่ม work ต่อเฟรมเล็กน้อยตอนเลื่อน ต้องยืนยันว่าไม่มี dropped frame
5. **API latency จริงบน Supabase** — เพื่อแปลง "ลด 3 round trip" ใน §3 ให้เป็น ms จริง
6. **RLS บนข้อมูลจริง** — plan ใน §2 มาจากข้อมูล seed ที่กระจายตัวสม่ำเสมอ ข้อมูลจริงไม่เป็นแบบนั้น

---

## 7. สรุปแบบ BEFORE / AFTER / IMPROVEMENT

| รายการ | BEFORE | AFTER | IMPROVEMENT | วัดที่ไหน |
|---|---|---|---|---|
| Request รูป ต่อ 1 หน้า feed (หลายรูป 8 โพสต์) | 8 | 1 | −87.5% | นับจากโค้ด |
| Request รูป ตอนเปิดโพสต์หลายรูปจาก feed | 1 | 0 | −100% | นับจากโค้ด + test |
| งาน DB ของ query รูป ต่อ 1 หน้า | 18.35 ms | 2.58 ms | −86% | `EXPLAIN ANALYZE` ใต้ RLS |
| Round trip viewer state ต่อ 1 หน้า | 4 (เรียงกัน) | 1 (ขนาน) | −75% | นับจากโค้ด |
| Bitmap ต่อรูป (DPR 2) | 10.2 MB | 3.4 MB | −67% | คำนวณ + ยืนยันด้วย test |
| Index ที่เพิ่ม | — | 0 | ไม่มี migration | `pg_indexes` |
| การโหลดใหม่ตอนกด Back (4 จอ) | ทั้งลิสต์ จากหน้า 0 | 1 แถว | ตำแหน่ง scroll ไม่หาย | test + โค้ด |
| API latency จริง | ไม่มีข้อมูล | ไม่มีข้อมูล | — | **ยังไม่ได้วัด** |
| Memory profile จริง | ไม่มีข้อมูล | ไม่มีข้อมูล | — | **ยังไม่ได้วัด** |
