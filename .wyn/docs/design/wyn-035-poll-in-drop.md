# Design — WYN-035 (Poll ใน Drop)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-035-poll-in-drop.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `home_feed`/`saved_feed` view (WYN-007/013/018/024/028/034) และ RPC pattern ที่ WYN-014 (Club)/ZOKY-003 (`create_orders`) วางไว้สำหรับ multi-table atomic insert
> Design system: Cyan `#00C8FF` เป็น primary ตาม DS-001–008 — ไม่มี Rainbow (DS-009) จุดไหนใน task นี้ ยกเว้น `TrendingTile` ที่มี Rainbow ring อยู่แล้วเป็นค่าคงที่เดิม (ไม่แตะ)

## ภาพรวม — 5 การตัดสินใจเชิง scope

1. **`drops.image_url` เปลี่ยนเป็น nullable** — Poll Drop ไม่มีรูป (ตาม Product's Risk #1 ที่ตัด "รูป+โพลพร้อมกัน" ออกรอบนี้) ไม่มี CHECK ข้ามตาราง (`drops`⇄`drop_polls`) เพราะ Postgres CHECK ทำ cross-table ไม่ได้ — ใช้ **RPC `create_poll_drop()` เป็นทางเดียว** ที่สร้าง Poll Drop ได้ (insert `drops`+`drop_polls`+`drop_mentions` แบบ atomic ในทรานแซกชันเดียว มิเรอร์ `create_orders()`) แทน การันตี invariant "มีรูปหรือมีโพลอย่างใดอย่างหนึ่งเสมอ" ด้วยโครงสร้างโค้ดแทนที่จะเป็น DB constraint
2. **ผลโหวตต้องผ่าน RPC `get_poll_results()` เท่านั้น** — `drop_poll_votes` มี SELECT policy จำกัดแค่แถวของตัวเอง (`auth.uid() = voter_id`) ไม่มีใครอ่านแถวคนอื่นได้ตรงๆ แม้แต่เจ้าของโพล ผลรวม (count/percentage) มาจาก SECURITY DEFINER function ที่คำนวณข้าม RLS แล้วเช็คเงื่อนไขการมองเห็น (โหวตแล้ว/เจ้าของ/หมดเวลา) เองก่อนคืนค่า — ไม่ใช่ตรรกะที่ทำที่ UI layer
3. **caption เดิมทำหน้าที่เป็นคำถามโพล** — ไม่มี field ใหม่ mention/hashtag ทำงานเหมือนเดิมทุกจุด (`HashtagText`/`MentionInput`/`searchByCaption` ไม่ต้องแก้)
4. **พื้นที่ที่เคยบังคับเป็นรูปภาพ (`AspectRatio(1)` ใน `CreateDropScreen`/`HomeDropCard`/`DropDetailScreen`) กลายเป็น "media area" ที่เลือกได้ 2 แบบ** — ภาพหรือ Poll composer/display แทนที่จะมีพื้นที่คู่ขนานใหม่แยกต่างหาก ลด diff/regression risk เหมือนที่ WYN-034 แนะนำ reuse pattern เดิมให้มากที่สุด
5. **โหวตสำเร็จแล้ว = ผลลัพธ์โหลดมาพร้อมกับ feed page เดียวกันเลย** ไม่ fetch แยกต่อการ์ด — `DropRepository`/`HomeRepository` ทุก fetch method เพิ่ม batch call เดียวไปยัง `get_poll_results(poll_ids[])` (มิเรอร์ pattern `_fetchLikedDropIds`/`_fetchRedroppedDropIds` เดิมเป๊ะ) แทนที่จะให้แต่ละ Poll widget ยิง RPC ของตัวเองตอน build (จะยิง request ซ้ำซ้อนทุกครั้งที่ scroll ผ่าน)

---

## Screen 1 — Poll Composer (แทนที่พื้นที่รูปใน `CreateDropScreen`)

**Purpose**: สร้าง Poll Drop

**ตำแหน่ง**: แถบปุ่มเล็กเหนือพื้นที่ media area เดิม 2 ปุ่ม toggle "🖼️ รูปภาพ" / "📊 โพล" (default: รูปภาพ ตามพฤติกรรมเดิม) — สลับแล้วพื้นที่ media area เปลี่ยนเนื้อหาทันที ข้อมูลของโหมดที่ไม่ได้เลือกไม่หายไป (สลับกลับมาใช้ต่อได้ ยกเว้นตอนกด "แชร์" ไปแล้วเท่านั้นที่ commit)

**Components (โหมดโพล)**:
- ตัวเลือก 2 ช่อง `TextField` เริ่มต้น (placeholder "ตัวเลือกที่ 1" / "ตัวเลือกที่ 2") ยาวได้ 1-80 ตัวอักษร
- ปุ่ม "+ เพิ่มตัวเลือก" ใต้ช่องสุดท้าย (ซ่อนเมื่อครบ 4 ช่องแล้ว) กดแล้วเพิ่มช่องว่างใหม่ต่อท้าย
- ไอคอนลบ (✕) ท้ายแต่ละช่องที่ 3-4 เท่านั้น (ช่อง 1-2 ลบไม่ได้ ต้องเหลืออย่างน้อย 2 เสมอ)
- แถวเลือกระยะเวลา: `SegmentedButton<int>` 3 ตัวเลือก "1 วัน" / "3 วัน" / "7 วัน" ค่าเริ่มต้น "1 วัน"

**Interactions**: พิมพ์คำถามในช่อง caption เดิมด้านล่าง (label เปลี่ยนเป็น "ตั้งคำถามโพล...") — ปุ่ม "แชร์" กดได้เมื่อ: คำถามไม่ว่าง + ตัวเลือกทุกช่องไม่ว่างและไม่ซ้ำกัน (trim แล้วเทียบ case-insensitive) + มีอย่างน้อย 2 ตัวเลือก

**States**: ปุ่ม "แชร์" ไม่ต้องรอรูป (`_imageBytes` ไม่ใช่เงื่อนไขในโหมดนี้อีกต่อไป) — error จากการซ้ำ/ว่าง แสดงเป็นข้อความสีแดงใต้ตัวเลือกที่มีปัญหา ไม่ใช่ snackbar (feedback ทันทีตอนพิมพ์ ไม่ต้องรอกดแชร์)

---

## Screen 2 — Poll Display Widget (`PollCard`, ใช้ร่วมกันใน `HomeDropCard` + `DropDetailScreen`)

**Purpose**: แสดงตัวเลือก/รับการโหวต/แสดงผลลัพธ์ — แทนที่พื้นที่ `AspectRatio(1)` รูปเดิมเมื่อ `pollId != null`

**User Flow**: เห็นตัวเลือกเป็นปุ่มแถวยาวเต็มความกว้าง (ไม่ใช่ grid) → แตะเพื่อโหวต → ถ้ามองเห็นผลได้ (โหวตแล้ว/เจ้าของ/หมดเวลา) แปลงเป็น percentage bar ทันที (optimistic update ก่อน call จริงเหมือน Like/Save/ReDrop เดิม)

**Components**:
- แต่ละตัวเลือกเป็นแถบเต็มความกว้าง สูง 44px (`WynSpacing.touchTargetMin`) ขอบมน
  - **ยังไม่เห็นผล** (ไม่ใช่เจ้าของ, ยังไม่โหวต, โพลยังไม่ปิด): พื้นหลังเรียบ + ข้อความตัวเลือกกลาง ไม่มี percentage
  - **เห็นผลแล้ว**: พื้นหลังเป็น percentage bar (fill ตามสัดส่วน, สี primary cyan จางๆ) + ข้อความตัวเลือก + `XX%` ชิดขวา — ตัวเลือกที่ตัวเองเลือก (`myVoteIndex`) มีไอคอน ✓ นำหน้าข้อความ + fill เป็นสี primary เต็ม (เข้มกว่าตัวเลือกอื่น)
- ใต้ตัวเลือกทั้งหมด: แถวเล็ก "X โหวต" (ใช้ `pollTotalVotes`, แสดง "ยังไม่มีใครโหวต" ถ้า 0) + จุดคั่น + "เหลือ Xh/Xd" (คำนวณจาก `pollExpiresAt` ลบเวลาปัจจุบัน) หรือ "โพลปิดแล้ว" ถ้าหมดเวลา

**Interactions**: แตะตัวเลือก (เจ้าของโพลแตะไม่ได้ — ตัวเลือกทั้งหมด `disabled`/ไม่มี `Semantics(button:true)`, โพลปิดแล้วก็แตะไม่ได้เหมือนกัน) → เรียก `onVote(index)` → optimistic update ทันที (ปรับ `myVoteIndex`/`optionCounts`/`totalVotes` local ก่อนเหมือน Like)

**States**: โหวตไม่สำเร็จ (network error/หมดเวลาไปแล้วพอดี) → snackbar "โหวตไม่สำเร็จ ลองใหม่อีกครั้ง" + revert state กลับก่อนโหวต (มิเรอร์ Like/Save/ReDrop's optimistic-then-revert-on-error)

**Accessibility**: แต่ละตัวเลือกมี `Semantics(label: "ตัวเลือก {text}, {percent}% ถ้าเห็นผลแล้ว, กดเพื่อโหวต")` ตัวเลือกที่เลือกแล้วเพิ่ม "เลือกอยู่" ต่อท้าย label

---

## Screen 3 — Grid/Preview Fallback (ไม่มีรูปให้แสดง)

**Purpose**: จุดที่เคยสมมติว่ามีรูปเสมอ (grid tile, quote-redrop preview, saved grid, trending tile) ต้องมี fallback เมื่อ `pollId != null`

**Components** — กล่องสี่เหลี่ยมจัตุรัสเดียวกับพื้นที่รูปเดิม พื้นหลัง `surfaceContainerHighest` (สีเดียวกับ placeholder ที่ `CreateDropScreen` ใช้ตอนยังไม่เลือกรูปอยู่แล้ว) กลางกล่อง: ไอคอน `Icons.poll_outlined` ขนาด 28 + ข้อความ "โพล" ใต้ไอคอน — **ไม่แสดงตัวเลือก/เปอร์เซ็นต์ในจุดเหล่านี้** (ตั้งใจให้เรียบง่าย เพราะจุดเหล่านี้เป็น thumbnail ที่กดแล้วเปิดไปดู Poll เต็มรูปแบบใน `DropDetailScreen`/`QuoteRedropScreen`'s preview ยังไงก็ต้องกดเข้าไปดูอยู่แล้วไม่ใช่จุดที่โหวตได้ตรงๆ) มี scrim ด้านล่างเหมือนเดิม (like-count เดิมของ `DropGridTile`/duration ของ Pop ใน `SavedGridTile` ไม่เปลี่ยน)

**จุดที่ต้องใช้**: `DropGridTile`, `SavedGridTile` (กรณี Drop-typed item), `QuoteRedropScreen`'s `_OriginalDropPreview`, `TrendingTile` (เสริมไอคอนเข้าไปในพื้นที่ placeholder ที่มีอยู่แล้ว)

---

## Screen 4 — Feed Card Label (ไม่มีของใหม่)

ไม่มี label พิเศษเพิ่มเติมบนการ์ด Poll Drop ใน Home/Profile — การ์ดใช้โครงเดิมทุกอย่าง (avatar/username/action row) มีแค่ media area ที่เปลี่ยนเป็น `PollCard` แทนรูป ไม่ต้องมี "🗳️ Poll" badge แยกเพิ่มเพราะตัว `PollCard` เองสื่อสารชัดเจนอยู่แล้วว่าเป็นโพล

---

## Handoff (ไปยัง AI Coding)

**Schema ที่แนะนำ**:
1. `alter table public.drops alter column image_url drop not null;`
2. ตารางใหม่ `drop_polls` (`drop_id` unique FK cascade, `options text[]` 2-4 ช่อง validate ผ่าน `public.valid_poll_options()` immutable function, `expires_at`)
3. ตารางใหม่ `drop_poll_votes` (`poll_id` FK cascade, `voter_id`, `option_index`, unique (poll_id, voter_id) รองรับเปลี่ยนใจผ่าน upsert) — SELECT policy จำกัดแค่แถวตัวเอง ไม่มี raw insert/update policy ที่ข้าม validation (ผ่าน `before insert or update` trigger เช็ค: หมดเวลาหรือยัง/option_index ในขอบเขต/ไม่ใช่เจ้าของโพล/ไม่ posting-blocked/ไม่ block กันอยู่กับเจ้าของ)
4. RPC `create_poll_drop(p_caption, p_options, p_duration_days, p_mentioned_user_ids)` — insert `drops`(image_url=null) + `drop_polls` + `drop_mentions` แบบ atomic มิเรอร์ `create_orders()`
5. RPC `get_poll_results(p_poll_ids uuid[])` — คืน `(poll_id, visible, total_votes, option_counts[])` ต่อโพล บังคับ visibility rule ที่ระดับ DB
6. `home_feed`/`saved_feed` view เพิ่มคอลัมน์ท้าย 3 ตัว (`poll_id`, `poll_options`, `poll_expires_at`) ทุก branch (pop = null ทั้งหมด, drop/redrop = join `drop_polls`)
7. **ไม่ต้องแก้ `notifications`/`reports` เลย** (Product ตัดสินใจไม่แจ้งเตือนต่อโหวต, ไม่มี report target ใหม่แยกสำหรับโพล — รายงาน Drop เดิมครอบคลุมอยู่แล้ว)

**Flutter ที่แนะนำ**: `Drop`/`HomeFeedItem` เพิ่ม field nullable (`pollId`/`pollOptions`/`pollExpiresAt`/`pollMyVoteIndex`/`pollTotalVotes`/`pollOptionCounts`) + `imageUrl` เปลี่ยนเป็น nullable ทั้งคู่ — `DropRepository` เพิ่ม `createPollDrop()`/`votePoll()` + batch fetch helper สองตัว (`_fetchMyPollVotes`/`_fetchPollResults`) เรียกคู่กับ `_fetchLikedDropIds` เดิมทุกจุดที่มีอยู่แล้ว — widget ใหม่ `PollComposer` (ใน `CreateDropScreen`), `PollCard` (Screen 2, ใช้ร่วม Home+Detail), `PollPlaceholderTile` (Screen 3) — จุดที่มี `Image.network(...imageUrl...)` แบบ non-null (`HomeDropCard`, `DropDetailScreen`, `DropGridTile`, `QuoteRedropScreen`, `SavedGridTile`) ทุกจุดต้องเช็ค null ก่อนแล้ว branch ไป Poll widget แทน ไม่ใช่แค่ทำ imageUrl เป็น nullable เฉยๆ (จะ crash runtime ทันทีถ้าลืมจุดใดจุดหนึ่ง)
