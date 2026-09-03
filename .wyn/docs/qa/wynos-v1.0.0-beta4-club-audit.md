# WYNOS v1.0.0 Beta4 — Club & Create Club Audit

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta4-master-implementation-j5lke8` — **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ขอบเขต: Beta4 §8 ทั้งหมด (8.1 Identity Image, 8.2 Create Flow, 8.3 Club Page, 8.4 Club QA), §7 (Image UI) ในส่วน Club
> **ไม่มี Supabase production credential** — RLS/schema ตรวจจากการอ่าน `supabase/schema.sql`

---

## 0. สิ่งที่พบตอน inspect — ต้นเหตุจริงของทุกอย่างในหมวดนี้

`clubs` มีคอลัมน์รูป **2 คอลัมน์** มาตั้งแต่ WYN-014: `icon_url` และ `cover_url`

แต่ UI แยกกันใช้แบบไม่มีใครสังเกต:

| ใครเขียน | เขียนคอลัมน์ไหน |
|---|---|
| Create Club (ตัวเลือกรูปเดียวที่มี) | `cover_url` |
| Edit Club (ตัวเลือกรูปเดียวที่มี) | `cover_url` |
| **ไม่มีใครเลย** | `icon_url` |

| ใครอ่าน | อ่านคอลัมน์ไหน |
|---|---|
| Club page header (avatar) | `icon_url` |
| "Club ของฉัน" | `icon_url` |
| Explore Clubs (avatar) | `icon_url` |
| Club ranked row | `icon_url` |
| Club mini card | `icon_url` |
| Club discovery card (avatar) | `icon_url` |
| Club discovery card (ภาพใหญ่) | `cover_url` |
| Club recommended card (ภาพใหญ่) | `cover_url` |
| Club recommended card (avatar ซ้อนมุม) | `icon_url` |

**ผลที่ผู้ใช้เห็นจริง:** เจ้าของ Club อัปโหลดรูป 1 รูป → รูปนั้นขึ้นบนการ์ดใน Explore เท่านั้น ส่วน**ที่อื่นทั้งหมด**ขึ้นเป็นวงกลมสีเทาที่มีตัวอักษรแรกของชื่อ Club เพราะ `icon_url` เป็น null เสมอ

นี่คือสาเหตุที่ §8.1 บอกว่า "Club ใช้รูปเพียง 1 รูป" — ไม่ใช่การลดฟีเจอร์ แต่เป็นการทำให้รูปที่อัปไป *มีผลจริงทุกที่*

---

## 1. §8.1 — Club Identity Image

### วิธีแก้

`Club.identityImageUrl` เป็น **read path เดียว**:

```dart
String? get identityImageUrl => iconUrl ?? coverUrl;
```

* **`icon_url` มาก่อน** — Beta4 เขียนรูปเดียวที่ผู้ใช้เลือกลงคอลัมน์นี้ (คอลัมน์ที่ surface ส่วนใหญ่อ่านอยู่แล้ว)
* **`cover_url` เป็น fallback** — Club ทุกอันที่สร้างก่อน Beta4 มีรูปอยู่ที่นั่น **ถ้าไม่มี fallback นี้ Club เดิมทุกอันจะกลายเป็นไม่มีรูปในวันที่ Beta4 ขึ้น**

### สิ่งที่ **ไม่** ทำ และทำไม

**ไม่ทำ DB migration ลบ `cover_url`** — §0 ห้าม "ทำ Database Migration ที่ไม่เกี่ยวข้อง" และการลบคอลัมน์นี้จะลบรูปของ Club ที่มีอยู่จริงทั้งหมด คอลัมน์คงอยู่ ไม่มีใครเขียนอีกแล้ว และมีคนอ่านที่เดียวคือ fallback ข้างบน

### API ที่เปลี่ยน

| ก่อน | หลัง |
|---|---|
| `createClub(..., coverBytes, coverExtension, iconBytes, iconExtension)` | `createClub(..., imageBytes, imageExtension)` |
| `uploadClubCover(...)` + `uploadClubIcon(...)` | `uploadClubIdentityImage(...)` |

ทั้งสองที่เดิมมี caller เดียว และเรียกด้วย cover pair เท่านั้น — การยุบจึงไม่เปลี่ยนพฤติกรรมของ caller ไหนเลย มันแค่ทำให้ "Club ที่มี 2 รูป" **เป็นไปไม่ได้ในเชิง type**

`uploadClubIdentityImage` เคลียร์ `cover_url` เป็น null ด้วย — รูปเข้าหนึ่ง รูปเก็บหนึ่ง

### หลักฐาน

* `test/club_identity_image_test.dart` — 5 test ครอบลำดับการ resolve ทุกกรณี รวม Club ก่อน Beta4
* `test/design_system_guard_test.dart` — fail ถ้ามีใครกลับไปอ่าน `club.iconUrl` / `club.coverUrl` ตรงๆ

---

## 2. §8.2 — Create Club Flow

### ก่อน

```
┌──────────────────────────┐
│ [ รูปปก 110px เต็มความกว้าง ] │  ← ขอรูปของสิ่งที่ยังไม่มีชื่อ
├──────────────────────────┤
│ ชื่อ Club                 │
│ คำอธิบาย                  │
│ หมวดหมู่                  │
│ ความเป็นส่วนตัว            │
└──────────────────────────┘
     [ สร้าง Club ]
```

**ปัญหา:** หน้าจอเปิดมาด้วยแผ่นสีเทา 110px ที่ขอรูปภาพ — ก่อนช่องชื่อ ไม่มีใครเลือกรูป Club ก่อนตัดสินใจว่า Club คืออะไร และมันเป็นองค์ประกอบที่ใหญ่และเด่นที่สุดบนฟอร์มที่มีคำตอบบังคับแค่ 2 ข้อ สำหรับฟิลด์ที่ไม่บังคับ

### หลัง — ตามลำดับที่ §8.2 ระบุ

```
┌──────────────────────────┐
│ ชื่อ Club            (1)  │
│ คำอธิบาย             (2)  │
├──────────────────────────┤
│ [🖼] รูป Club        (3)  │  ← แถวมีป้ายกำกับ + ตัวอย่าง 56px สี่เหลี่ยม
├──────────────────────────┤
│ หมวดหมู่             (4)  │
│ ความเป็นส่วนตัว       (4)  │
└──────────────────────────┘
┌──────────────────────────┐
│ ตรวจสอบข้อมูล        (5)  │  ← สรุปสิ่งที่กำลังจะสร้าง
│ 🏷 ชื่อที่พิมพ์            │
│ 🌐 สาธารณะ / 🔒 ส่วนตัว    │
│ 🖼 มีรูป / ยังไม่ได้เลือกรูป  │
└──────────────────────────┘
     [ สร้าง Club ]     (6)
```

| การเปลี่ยน | เหตุผล |
|---|---|
| ชื่อ/คำอธิบาย ขึ้นก่อนรูป | §8.2 step 1-2-3 ตามลำดับ และตรงกับลำดับที่คนคิดจริง |
| picker: banner 110px → แถว 56px สี่เหลี่ยม | รูปนี้ไม่ใช่ "ปก" อีกแล้ว มันคือ identity image ที่ถูกแสดงเป็น **วงกลม** ในที่ส่วนใหญ่ — preview 16:9 สัญญาการจัดวางที่ product ไม่เคยใช้ · และเลิกครองหน้าจอในฐานะฟิลด์ที่ไม่บังคับ |
| `maxHeight` 900 → 1600 (สี่เหลี่ยมจัตุรัส) | ต้นฉบับ 16:9 รับประกันว่าทุกการ render เป็นวงกลมจะตัดข้างทิ้ง |
| copy "รูปปก" → "รูป Club" | §8.1 — ไม่มี "ปก" อีกแล้ว |
| เพิ่ม "ตรวจสอบข้อมูล" | §8.2 step 5 · ฟิลด์กระจายอยู่ในการ์ดที่ต้องเลื่อน พอปุ่มโผล่มาบนจอ ชื่อที่พิมพ์มักไม่อยู่แล้ว · โผล่เฉพาะเมื่อคำตอบบังคับครบ จึงเป็น "ยืนยัน" ไม่ใช่ "รายการที่ยังขาด" (ปุ่มที่ disabled บอกเรื่องนั้นอยู่แล้ว) |

### ทำไม **ไม่** ทำเป็น wizard 6 หน้า

§8.2 เขียนว่า "**จัด Flow ให้ใกล้เคียงแนวคิด**" — คือจัดลำดับให้ใกล้เคียง ไม่ใช่แบ่งหน้า

Club มีคำตอบที่บังคับจริง 2 ข้อ (ชื่อ, ความเป็นส่วนตัว) การแบ่ง 2 ฟิลด์ออกเป็น 6 หน้าจะทำให้งาน 30 วินาทีรู้สึกเหมือนกรอกใบสมัคร และเป็น "Rewrite Architecture" แบบที่ §0 ห้าม สิ่งที่ §8.2 พูดถึงคือ *ลำดับ* และลำดับถูกแล้ว

**หลักฐาน:** `test/create_club_screen_test.dart` — "the form asks for the name before the image, and ends with a review summary above the create button" (วัดพิกัด y จริง)

---

## 3. §8.3 — Club Page

### banner — การกลับคำที่มีเหตุผล

**Beta3 (Founder, 2026-09-03) เอารูปออกจาก banner** เหตุผลที่บันทึกไว้เป็นเหตุผลที่ดีจริง:

> banner *สลับ* ระหว่างสองดีไซน์ที่ไม่เกี่ยวกันขึ้นกับว่าเจ้าของเผอิญอัปรูปไว้ไหม **และชื่อ Club หายไปจาก banner ในกรณีที่อัป** — ชื่อถูกวาดเฉพาะบนแบบ generated

**Beta4 §8.3 ขอรูปกลับมาบนหน้านี้** จึงเอากลับมาพร้อม *แก้ข้อบกพร่องนั้น* ไม่ใช่พามันกลับมาด้วย:

```
Layer 1  พื้นหลัง ink + วง gradient sapphire   ← วาดเสมอ (เป็นทั้งกรณีไม่มีรูป และ placeholder ระหว่างโหลด)
Layer 2  รูป identity                          ← เฉพาะเมื่อมี
Layer 3  scrim ไล่ระดับซ้าย→ขวา                 ← เฉพาะเมื่อมีรูป
Layer 4  "CLUB" + ชื่อ Club                     ← วาดเสมอ ทั้งสองกรณี
```

**มี banner ดีไซน์เดียว ไม่ใช่สอง** — ความสูงเท่ากัน ตัวอักษรเท่ากัน ตำแหน่งเท่ากัน ทั้งสองกรณี รูปเปลี่ยนแค่ *สิ่งที่อยู่ข้างหลังชื่อ* ไม่เคยแทนที่ชื่อ

scrim ไล่ระดับซ้าย→ขวา (ไม่ใช่ทาทึบทั้งแผ่น) เพราะข้อความชิดซ้าย — ฝั่งขวาของรูปจึงถูกบังน้อยที่สุดเท่าที่ยังอ่านออก

### ส่วนอื่นของหน้า Club

| องค์ประกอบ (§8.3) | สถานะ |
|---|---|
| Club Identity Image | ✅ ทั้ง banner และ avatar ในหัวเรื่อง (`ClubAvatar` ring: true) |
| Club Name | ✅ ทั้งใน banner และในหัวเรื่อง |
| Description | ✅ ไม่เปลี่ยน (แท็บ "เกี่ยวกับ") |
| Member Information | ✅ ไม่เปลี่ยน — "N สมาชิก" + chip หมวดหมู่ |
| Join / Leave | ✅ ไม่เปลี่ยน — 3 สถานะ (เข้าร่วม / รออนุมัติ / เป็นสมาชิก) |
| Posts / Community Content | ✅ ไม่เปลี่ยน + ดู §4 (รูปในโพสต์) |

### `ClubAvatar` — ลบสำเนา 5 ชุด (§7/§22)

พบ 5 widget เขียน `CircleAvatar(backgroundColor: primary, backgroundImage: NetworkImage(club.iconUrl!), child: Text(club.name[0]...))` แยกกันคนละชุด — และทั้ง 5 ชุดมีข้อบกพร่องเดียวกัน 3 ข้อ:

1. **ไม่ bound decode** — `NetworkImage` ดิบ decode รูป 1600×1600 (~10MB bitmap) ลงในวงกลม 36px และ Explore แสดงพร้อมกันเต็มจอ
2. **ไม่มี fallback ตอนโหลดพัง** — `backgroundImage` ไม่ render อะไรเลยเมื่อล้มเหลว Club ที่ signed URL หมดอายุ (club-media เป็น private bucket, signed URL อายุ 1 ชม.) จึงเป็นวงกลมสีเปล่าๆ ไม่ใช่ตัวอักษร
3. **guard `name[0]` แยกกัน 5 ชุด** — ถูกทั้ง 5 ชุด แต่แยกกัน

`ClubAvatar` ห่อ `AvatarCircle` (ซึ่งแก้ทั้ง 3 ข้อไปแล้วสำหรับ profile) และอ่าน `identityImageUrl` เท่านั้น — ทำให้ §8.1 เป็นจริงพร้อมกันทั้ง 5 จุด

### Club recommended card — เอา avatar ซ้อนมุมออก

การ์ดนี้เคยแสดงภาพใหญ่ (`cover_url`) + วงกลมเล็กซ้อนมุมล่างซ้าย (`icon_url`) = ออกแบบมาให้แสดงรูป **2 รูป** ของ Club หนึ่ง ซึ่งหนึ่งในนั้นไม่มีทางถูกตั้งค่า ในทางปฏิบัติทุกการ์ดจึงเป็น "รูปถ่าย + วงกลมเทาติดมุม"

พอเหลือรูปเดียว วงกลมนั้นจะกลายเป็นสำเนาย่อของรูปที่อยู่ข้างหลังมันพอดี — จึงเอาออก และคืน padding 8px ที่เผื่อไว้ให้ส่วนที่ยื่นออกมา

---

## 4. §7 — Image UI ในบริบท Club

### รูปในโพสต์ของ Club

| | ก่อน | หลัง |
|---|---|---|
| หลายรูป | `PageView` เต็มความกว้าง ทีละรูป | `PostImageCarousel` — แถวการ์ด รูปถัดไปโผล่ที่ขอบ |
| รูปเดียว | `AspectRatio(1) + NetworkThumbnail` | `PostImageFrame` |
| สัดส่วน | 1:1 | **1:1 เหมือนเดิม** |

**ทำไมสัดส่วนไม่เปลี่ยน:** `club_posts` ไม่มีคอลัมน์ `image_width`/`image_height` เลย (ต่างจาก `drops` ที่ได้มาตอน WYN-093) จึงไม่มีอะไรให้คำนวณสัดส่วนจริง — `PostImageFrame` fallback เป็น 1:1 เมื่อไม่รู้ขนาด ซึ่งคือรูปทรงที่ widget นี้ hardcode ไว้แต่เดิมพอดี

**สิ่งที่เปลี่ยนคือ *การจัดเรียง*** — §7 บอกว่า "ห้ามบังคับทุกหน้าต้องใช้ Layout รูปเดียวกัน" และนี่ไม่ใช่การบังคับ: สัดส่วนยังต่างเพราะมันต้องต่าง แต่รูปของคนคนเดียวกันเคยเป็นแถวการ์ดในที่หนึ่งและแผ่นเดี่ยวในอีกที่หนึ่งโดยไม่มีเหตุผลที่คนอ่านมองเห็น ตอนนี้เป็นแถวการ์ดเหมือนกันทุกที่ พร้อม snap, decode bound, และ loading/error state ชุดเดียวกัน

### รูปอื่นของ Club

| จุด | ก่อน | หลัง |
|---|---|---|
| Edit Club preview | `Image.network` ดิบ (ไม่ bound decode) 16:9 เต็มความกว้าง | `NetworkThumbnail` 96px สี่เหลี่ยม จัดกลาง |
| Club banner | ไม่มีรูป | `NetworkThumbnail` (bound ตามความสูง 140px ที่วาดจริง) |
| Discovery card ภาพใหญ่ | `NetworkThumbnail` + `cover_url` | `NetworkThumbnail` + `identityImageUrl` |
| Avatar ทุกจุด | `NetworkImage` ดิบ | `ClubAvatar` → `AvatarCircle` (bound + fallback) |

---

## 5. §8.4 — Club QA

| รายการ | ผล | ตรวจที่ไหน |
|---|---|---|
| Create Club | ✅ | `create_club_screen_test.dart` — 4 test (ปุ่ม disabled จนครบ, picker เดียว, ลำดับฟอร์ม + review, สร้างโดยไม่ใส่รูปได้) |
| Edit Club | ✅ | `flutter analyze` + การอ่านโค้ด — ไม่มี test file เดิมสำหรับหน้านี้ ดู K-2 |
| Club Identity Image | ✅ | `club_identity_image_test.dart` (5) + `club_page_test.dart` (3) + guard test |
| View Club | ✅ | `club_page_test.dart` — 9 test |
| Join / Leave | ✅ ไม่เปลี่ยน | `club_page_test.dart` — 3 สถานะปุ่ม + More menu ตาม role |
| Posts | ✅ | `club_posts_tab` ไม่เปลี่ยน · รูปในโพสต์ผ่าน `flutter analyze` + test เดิม |
| Members | ✅ ไม่เปลี่ยน | `club_members_tab_test.dart` |
| Responsive | ✅ | `beta4_responsive_test.dart` — Club page ที่ 320/390/430/834, Create Club ที่ 320/390/834 |
| Loading | ✅ ไม่เปลี่ยน | spinner + `NetworkThumbnail` placeholder |
| Empty | ✅ ไม่เปลี่ยน | |
| Error | ✅ | `_signedUrl` catch → null → fallback ตัวอักษร (ตอนนี้ทำงานจริงแล้วผ่าน `AvatarCircle`) |
| Regression | ✅ | 1164/1164 |

### Responsive — ที่ตรวจจริง

| ขนาด | Club page | Create Club |
|---|---|---|
| 320×568 (small mobile) | ✅ | ✅ |
| 390×844 (mobile) | ✅ | ✅ |
| 430×932 (large mobile) | ✅ | — |
| 834×1112 (tablet) | ✅ | ✅ |

ทดสอบด้วยชื่อ Club ยาว 50 ตัวอักษร (เพดานของคอลัมน์) + สมาชิก 6 หลัก — `tester.takeException()` ต้องคืน null (RenderFlex overflow รายงานผ่าน error framework)

**บั๊กที่แก้ระหว่างทาง:** ชื่อ Club ใน banner เดิมเป็น `Text` บรรทัดเดียวไม่มีอะไรกันล้น ชื่อ 50 ตัวอักษรที่ 22px ล้นแถบ 140px ที่จอเล็ก → ใส่ `maxLines: 2` + ellipsis

---

## 6. ตรวจแล้ว **ไม่พบปัญหา** — ไม่แตะ

| จุด | ผล |
|---|---|
| RLS ของ `clubs` / `club_members` / `club_posts` | `club_role()` primitive เดียวใช้ทุก policy — ไม่แตะ |
| `clubs_prevent_owner_id_change` trigger | ยังทำงาน — ป้องกัน Owner/Admin แอบโอนความเป็นเจ้าของผ่าน update ปกติ |
| `club-media` เป็น private bucket + signed URL 1 ชม. | ถูกต้อง Beta4 ไม่เปลี่ยน |
| `countMembers` นับเฉพาะ `approved` | ถูกต้อง |
| หมวดหมู่ 9 ค่าคงที่ | ไม่เปลี่ยน (§8.2 ห้ามเพิ่มฟีเจอร์ community ใหม่) |
| Privacy toggle (สาธารณะ/ส่วนตัว) | ไม่เปลี่ยน — restyle ไปแล้วตั้งแต่ 08-club.tsx |
| Restriction banner + appeal | ไม่เปลี่ยน |

---

## 7. Known Issues

| # | เรื่อง | ความรุนแรง | รายละเอียด |
|---|---|---|---|
| K-1 | `cover_url` ยังอยู่ใน DB โดยไม่มีใครเขียน | ต่ำ | ตั้งใจ — ลบแล้ว Club เดิมทุกอันจะไม่มีรูป การ migrate ข้อมูลจาก `cover_url` → `icon_url` แล้วค่อยลบคอลัมน์ เป็น task ที่ต้องให้ Founder อนุมัติ ไม่ใช่ผลข้างเคียงของงาน UI |
| K-2 | `edit_club_info_screen.dart` ไม่มี test file ของตัวเอง | กลาง | มีมาก่อน Beta4 — Beta4 แก้ picker ในหน้านี้แล้วยืนยันด้วย `flutter analyze` + การอ่านโค้ดเท่านั้น ควรเพิ่ม test ใน round หน้า |
| K-3 | Club post ไม่มี dimension ใน DB | ต่ำ | จึงยังเป็น 1:1 ตลอด การเพิ่มคอลัมน์คือ migration ที่ §0 ห้ามทำโดยไม่เกี่ยวข้อง — บันทึกไว้เป็น future idea |
| K-4 | ยังไม่ได้อัปโหลดรูป Club จริงผ่าน storage | — | ไม่มี Supabase credential ใน session นี้ path การอัปโหลด (`_uploadClubImage` → signed URL) ไม่ได้เปลี่ยนตรรกะ เปลี่ยนแค่ชื่อไฟล์ปลายทางและคอลัมน์ที่เขียน |
