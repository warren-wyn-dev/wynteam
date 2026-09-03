# WYNOS v1.0.0 Beta2 — Final QA & Readiness Report

> วันที่: 2026-09-03 (อัปเดตหลัง Founder Final Decision)
> Branch: `claude/wynos-beta2-audit-fevu5g` — **ยังไม่เปิด PR ยังไม่ merge ยังไม่ deploy**
> เอกสารก่อนหน้า: `wynos-v1.0.0-beta2-full-audit.md` (Phase 1) · `wynos-v1.0.0-beta2-readiness.md`
> Environment: PostgreSQL 16.13 ในเครื่อง · Flutter 3.47.1 (SDK เดียวกับ CI/production)
> **ไม่มี Supabase production credential ใน session นี้** — ทุกข้อความติดป้ายว่าตรวจที่ไหน

---

## 🚦 ระดับความพร้อม: **QA READY** (ยังไม่ Production Ready)

| ระดับ | สถานะ | เหตุผล |
|---|:--:|---|
| Development Ready | ✅ | analyze 0 issues · test 1,086 ผ่าน · build web สำเร็จ |
| **QA Ready** | ✅ **อยู่ตรงนี้** | คำสั่ง Founder ครบทุกข้อ · supabase test **27/33** (จาก 4/33) · ไม่มีบั๊กผลิตภัณฑ์ค้าง |
| Production Ready | ❌ | เหลืออย่างเดียว: **ยังไม่มีอะไรถูก apply กับ production** (ไม่มี credential) + ยังไม่ผ่าน QA เชิงพฤติกรรมโดยมนุษย์ |
| Blocked by Security | ❌ | ไม่มีช่องโหว่ที่ยืนยันได้ — P0 ที่เคยรายงานพิสูจน์แล้วว่าไม่มีจริง (§0) |

### ผลตาม Founder Final Decision (2026-09-03)

| ข้อ | คำสั่ง | สถานะ |
|---|---|---|
| 1 | schema.sql patch — **APPROVED** | ✅ **ทำแล้ว** — เติม `drop view if exists` 2 บรรทัด · test 4/33 → 23/33 |
| 2 | WITH CHECK — **DO NOT APPLY** | ✅ **ไม่ apply** — ติดป้าย `NOT APPROVED FOR BETA2 PRODUCTION` ในไฟล์ + บันทึกใน APPROVALS.md · ไม่แตะ RLS policy อื่นเลย |
| 3 | `create_poll_drop` — **APPROVED** | ✅ **ทำแล้ว** — verify call site ก่อน · drop 2 overload เก่า · test 23/33 → **27/33** |
| 4 | Index 9 ตัว — **APPROVED for production** | ⏸️ **ยังไม่ apply** — session ไม่มี production credential (ดู §8) |

---

## ⚠️ 0. สิ่งที่ต้องแจ้งก่อนอื่น: ผมรายงาน P0 ผิด

**Founder อนุมัติ `WITH CHECK` บนพื้นฐานข้อมูลที่ผมให้ผิด** ต้องแก้ให้ตรงก่อนอย่างอื่น

ผมรายงานว่า UPDATE policy 6 ตัวที่ไม่มี `WITH CHECK` เปิดช่องให้ผู้ใช้ย้ายความเป็นเจ้าของแถวไปให้คนอื่นได้ **ข้อนี้ผิด**

PostgreSQL มีพฤติกรรมที่ผมมองข้าม: **ถ้า UPDATE policy ไม่ระบุ `WITH CHECK` ระบบจะใช้ `USING` เป็น `WITH CHECK` ให้เอง** ช่องโหว่ที่ผมอธิบายจึงไม่เคยมีอยู่จริง

**หลักฐานที่รันจริงบน PostgreSQL 16.13 — ทดสอบ *ก่อน* apply อะไรทั้งสิ้น:**

| การโจมตี | ผลลัพธ์ (ก่อน apply) |
|---|---|
| `update profiles set id = <uuid ของ auth user คนอื่น>` | ❌ `ERROR: new row violates row-level security policy` |
| `update profile_private set id = <uuid คนอื่น>` | ❌ ปฏิเสธ |
| `update cart_items set user_id = <คนอื่น>` | ❌ ปฏิเสธ |
| `update club_posts set club_id = <Club ที่ไม่มีสิทธิ์>` | ❌ ปฏิเสธ |
| `update clubs set owner_id = <คนอื่น>` | ❌ ปฏิเสธ — โดย trigger `clubs_prevent_owner_id_change()` ที่ **มีอยู่แล้ว** (defence in depth ที่ทีมทำไว้ก่อนหน้า) |

และยืนยันพฤติกรรมของ PostgreSQL แยกต่างหากด้วย policy ทดสอบที่มีแต่ `using (owner = 'me')` — การ update ให้ owner เป็นค่าอื่นถูกปฏิเสธด้วย error เดียวกัน

**ผลที่ตามมา:**
- ไม่เคยมีช่องโหว่ ไม่มีข้อมูลผู้ใช้เสี่ยง ไม่ต้องเร่ง
- การเพิ่ม `WITH CHECK` แบบชัดเจนเป็น **no-op ทางความหมาย** — เปลี่ยนพฤติกรรม 0
- **Founder ตัดสินใหม่บนข้อมูลที่ถูกต้องแล้ว (2026-09-03): ไม่ apply ใน Beta2** — ไฟล์ถูกติดป้าย `NOT APPROVED FOR BETA2 PRODUCTION` ไว้ที่หัวไฟล์ และบันทึกเหตุผลไว้ใน `.wyn/company/APPROVALS.md` แล้ว
- ไม่มี RLS policy อื่นถูกแตะหรือ revert ตามคำสั่ง

**คุณค่าที่ยังเหลืออยู่ (เล็กแต่มีจริง):** `WITH CHECK` ที่เขียนชัดเจนกันความผิดพลาดในอนาคต — ถ้าวันหนึ่งมีคนแก้ `using` ให้กว้างขึ้น (เช่นเป็น `using (true)` เพื่อจุดประสงค์การอ่าน) เงื่อนไขฝั่งเขียนจะไม่กว้างตามไปเงียบ ๆ นี่คือ defence in depth ไม่ใช่การอุดช่องโหว่

---

## 1. Changes Implemented

### 1.1 งานที่ทำในรอบนี้ (R-1 → R-5 ตามลำดับที่อนุมัติ)

| # | งาน | สิ่งที่ทำ | ตรวจที่ไหน |
|---|---|---|---|
| R-1 | `club_post_comments` pagination | 50 ต่อหน้า + ปุ่ม "ดูคอมเมนต์เพิ่มเติม" + สถานะ error/retry — pattern เดียวกับที่ทำให้ Drop (B2-10) การแบ่งหน้าตามลำดับเวลาทำให้ reply nesting ถูกต้องเองโดยไม่ต้องทำอะไรเพิ่ม | Locally verified |
| R-2 | thumbnail ที่เหลือ | แปลง 8 จุดเป็น `NetworkThumbnail` (decode ตามขนาดที่วาดจริง): `profile_replies_tab` (44px), `saved_post_row` (56px), `trending_tile` (90px), `club_discovery_card`, `club_recommended_card`, `club_post_card`, `recently_deleted_drops`, `quote_redrop` | Locally verified |
| R-3 | errorBuilder ที่เหลือ | เพิ่ม `networkImageErrorBuilder` ที่ใช้ร่วมกันให้ 9 จุดที่เป็นภาพเต็มจอ/hero (ไม่ downsample เพราะตั้งใจให้ดูเต็มความละเอียด แต่ต้องมี fallback) — **เหลือ 0 จุดใน Wynos ที่ไม่มี error handling** | Locally verified |
| R-4 | แยก network error / server error | `core/network_error.dart` + ต่อเข้า Home / Search / Notifications ผู้ใช้ที่เน็ตหลุดเห็น "ไม่มีการเชื่อมต่ออินเทอร์เน็ต" แทน "โหลดไม่สำเร็จ" | Locally verified + 8 unit test |
| R-5 | `club_members` pagination | 50 ต่อหน้า + ปุ่ม "ดูสมาชิกเพิ่มเติม" **และ** แก้ waterfall ที่พบระหว่างทาง (approved/pending ถูก await เรียงกันทั้งที่ไม่ขึ้นต่อกัน → `Future.wait`) | Locally verified |

**หมายเหตุ R-4:** ตั้งใจไม่ import `dart:io` (ไม่มีบน web จะทำให้ build web พังทันที) และไม่ import `package:http` (เป็น transitive dependency เท่านั้น) จึงตรวจชนิด exception ด้วยชื่อ แลกความแม่นยำเล็กน้อยกับการที่ helper ตัวเดียวทำงานได้ทุก platform

### 1.2 งานจากรอบก่อน (สรุป — รายละเอียดเต็มใน `wynos-v1.0.0-beta2-readiness.md`)

17 รายการ: injection ใน search · ranked feed เรียงผิด · cache ranked window · Future.wait · cacheWidth · dedupe feed · serialize การกดซ้ำ · comment pagination · scroll position · touch target 44px · skeleton · retry ที่มองเห็นได้ · placeholder รูป · mounted guard · cacheControl · error boundary · animation + haptic

### 1.3 สิ่งที่ **ไม่** ได้ทำตามคำสั่ง

- **ZOKY (`features/zoky/`)** — ไม่แตะแม้แต่บรรทัดเดียว ยืนยันด้วย `git diff --stat` (§6) ทั้ง 4 จุด `mounted` และรูปสินค้ายังอยู่เหมือนเดิม
- **`pop_likes` index** — รอจน Pop กลับเข้า active scope ตามที่สั่ง

---

## 2. Security Status

### 2.1 WITH CHECK — ❌ **ไม่ apply** (Founder decision ข้อ 2)

**สถานะสุดท้าย: ไม่เป็นส่วนหนึ่งของ Beta2 production deployment**

- ไฟล์ `supabase/pending_approval_rls_with_check.sql` ยังอยู่ แต่ติดป้าย `❌ NOT APPROVED FOR BETA2 PRODUCTION — DO NOT APPLY` ที่หัวไฟล์ พร้อมเหตุผลเต็ม
- **ไม่ได้ถูกผนวกเข้า `supabase/schema.sql`** จึงไม่มีทางถูก apply โดยบังเอิญตอน migrate
- **ไม่มี RLS policy อื่นถูกแก้หรือ revert**
- บันทึกคำตัดสินไว้ใน `.wyn/company/APPROVALS.md` (สถานะ: ปฏิเสธสำหรับ Beta2)

ข้อมูลการทดลอง apply **ในฐานข้อมูล QA ในเครื่องเท่านั้น** (ทำก่อน Founder ตัดสิน เพื่อพิสูจน์ว่าเป็น no-op) เก็บไว้เป็นหลักฐานประกอบ:

**policy ทั้ง 6 ตัวมี `with_check` ชัดเจนหลัง apply:**

| Policy | with_check ที่อ่านได้จาก `pg_policies` |
|---|---|
| `public.profiles` | `(auth.uid() = id)` |
| `public.profile_private` | `(auth.uid() = id)` |
| `public.cart_items` | `(auth.uid() = user_id)` |
| `public.clubs` | `club_role(id, auth.uid()) = ANY (ARRAY['owner','admin'])` |
| `public.club_posts` | `club_role(club_id, auth.uid()) = ANY (ARRAY['owner','admin','moderator'])` |
| `storage.objects` (avatar) | `bucket_id='avatars' AND (storage.foldername(name))[1] = auth.uid()::text` |

**ทดสอบการโจมตีซ้ำหลัง apply — ปฏิเสธครบทั้ง 4 ข้อที่ทดสอบได้:**
```
ERROR: new row violates row-level security policy for table "profiles"
ERROR: new row violates row-level security policy for table "profile_private"
ERROR: new row violates row-level security policy for table "cart_items"
ERROR: new row violates row-level security policy for table "club_posts"
```

**ทดสอบ flow ปกติของแอปหลัง apply — สำเร็จครบทั้ง 5 ข้อ:**

| flow | ผล |
|---|---|
| แก้ display_name / bio ของตัวเอง | ✅ เขียนลงจริง |
| ตั้ง `onboarding_completed` ของตัวเอง | ✅ |
| แก้จำนวนสินค้าในตะกร้าตัวเอง | ✅ |
| pin / unpin โพสต์ใน Club ที่ตัวเองเป็น staff | ✅ |
| เปลี่ยนชื่อ Club ที่ตัวเองเป็น owner | ✅ |

**สรุปการทดลอง:** ไม่มี flow ไหนพัง ไม่มีพฤติกรรมไหนเปลี่ยน — ยืนยันว่าเป็น no-op ซึ่งเป็นข้อมูลที่ Founder ใช้ตัดสินว่าไม่ต้อง apply ใน Beta2

> ⚠️ `storage.objects` ทดสอบพฤติกรรมจริงไม่ได้ในเครื่อง เพราะเป็นตาราง stub (ไม่มี Supabase Storage platform) — ยืนยันได้แค่ว่า policy ถูกสร้างถูกต้อง → **Not verified** ในเชิงพฤติกรรม

### 2.2 การตรวจความปลอดภัยอื่น ๆ

| หัวข้อ | ผล | ตรวจที่ไหน |
|---|---|---|
| RLS เปิดใช้งานทุกตาราง | ✅ | Locally verified |
| จำนวน policy | 195 (SELECT 77 / INSERT 71 / DELETE 28 / UPDATE 18 / ALL 1) | Locally verified |
| UPDATE policy ที่ไม่มี `with_check` | 0 (หลัง apply) | Locally verified |
| Authorization อยู่ฝั่ง server | ✅ audience / block / private / moderation / soft-delete บังคับใน RLS | Locally verified (23 RLS test ผ่าน — §4.2) |
| ข้อมูลส่วนตัวแยกตาราง | ✅ `profile_private` | Locally verified |
| PostgREST filter injection | ✅ แก้แล้ว + 6 test | Locally verified |
| Secret ใน repo | ✅ ไม่มี (`Env` ใช้ `String.fromEnvironment` ล้วน) | Locally verified |
| **พบใหม่: `create_poll_drop` มี 3 overload ซ้อนกัน** | ⚠️ ดู §3.3 | Locally verified |

---

## 3. Database Status

### 3.1 Index — ✅ อนุมัติแล้ว · ตรวจครบในเครื่อง · ⏸️ **ยังไม่ apply กับ production**

```
apply supabase/migrations_beta2_indexes.sql (ฐานข้อมูลในเครื่อง) → exit 0
verify: 9 / 9 index ถูกสร้าง · รันซ้ำได้ (idempotent: ทุกคำสั่งเป็น if not exists)
```

**Pre-apply checks ที่ Founder สั่งให้ทำก่อน apply production — ทำครบแล้ว:**

| ตรวจ | ผล |
|---|---|
| migration ตรงกับเวอร์ชันที่ review หรือไม่ | ✅ `supabase/migrations_beta2_indexes.sql` เหมือนกับบล็อกท้าย `schema.sql` แบบ byte-identical (ตรวจด้วย diff) |
| มี duplicate/redundant index ใหม่หรือไม่ | ✅ ไม่มี — ตรวจ prefix ของทุก index ใน schema `public` |
| ปลอดภัยที่จะรันหรือไม่ | ✅ additive ล้วน · ไม่แตะตาราง/คอลัมน์/policy/ข้อมูล · ย้อนกลับด้วย `drop index` 9 ตัว |

**ตรวจ duplicate / redundant:** ไม่มี index ใหม่ตัวไหนซ้ำซ้อนกับของเดิม (query เทียบ prefix ของทุก index ใน schema `public`)

พบ **index ซ้ำซ้อนที่มีอยู่เดิม 3 ตัว** (ไม่ใช่ของรอบนี้ ไม่ได้แก้ — ดู §5):
`cart_items_user_id_idx`, `conversations_user_a_idx`, `drop_poll_votes_poll_idx` — แต่ละตัวเป็น prefix ของ unique index ที่ครอบคลุมอยู่แล้ว (`redrops_drop_idx` ดูเหมือนซ้ำแต่ไม่ซ้ำ เพราะตัวที่ครอบคลุมเป็น partial index)

### 3.2 EXPLAIN — พิสูจน์ว่า planner เลือกใช้จริงทั้ง 9 ตัว

รันบนข้อมูลจำลอง 11,000 drops / 15,000 comments / 16,500 follows / 20,000 saves / 5,000 likes

| # | Index | Query plan ที่ได้ |
|---|---|---|
| 1 | `drops_created_at_idx` | `Index Scan using drops_created_at_idx` |
| 2 | `drops_author_created_idx` | `Bitmap Index Scan on drops_author_created_idx` |
| 3 | `drop_likes_user_idx` | `Index Scan using drop_likes_user_idx` (ไม่มี Sort เหลือ) |
| 4 | `drop_comments_drop_created_idx` | `Index Scan using drop_comments_drop_created_idx` |
| 5 | `follows_following_idx` | `Index Scan using follows_following_idx` |
| 6 | `follow_requests_target_idx` | `Index Scan using follow_requests_target_idx` |
| 7 | `saves_content_idx` | `Bitmap Heap Scan` + Recheck บน `content_id` (เดิมเป็น Seq Scan ทั้งตาราง) |
| 8 | `club_posts_club_pinned_created_idx` | `Index Scan` (ตรงกับ ORDER BY `pinned desc, created_at desc` พอดี ไม่มี Sort) |
| 9 | `club_post_comments_post_created_idx` | `Index Scan` |

**ข้อจำกัดที่ต้องพูดตรง ๆ:** ตัวเลขเหล่านี้มาจากข้อมูลจำลอง ไม่ใช่ข้อมูล production จริง การกระจายตัวของข้อมูลจริงต่างออกไปได้ และ planner อาจเลือกต่างไป — **ต้อง `EXPLAIN ANALYZE` ซ้ำหลัง apply จริง**

### 3.3 ✅ แก้แล้ว (SCHEMA-003): `create_poll_drop` เหลือ overload เดียว

`create or replace function` ที่เปลี่ยน **จำนวนพารามิเตอร์** ไม่ได้แทนที่ของเดิม แต่สร้างฟังก์ชันใหม่ ทำให้ตอนนี้มีพร้อมกัน 3 ตัว:

```
create_poll_drop(text,text[],integer,uuid[])                                  -- WYN-035 เดิม
create_poll_drop(text,text[],integer,uuid[],text,uuid[])                      -- + audience
create_poll_drop(text,text[],integer,uuid[],text,uuid[],text,float,float,text) -- + location
```

ทั้ง 3 ตัวเป็น `SECURITY DEFINER` และ `authenticated` เรียกได้ทั้งหมด

- **แอปไม่พัง** — `DropRepository.createPollDrop` ส่งครบทั้ง 10 พารามิเตอร์ จึงจับคู่ตัวล่าสุดได้ชัดเจน (ตรวจแล้วในโค้ด)
- **แต่ทำให้ test 5 ไฟล์ล้ม** เพราะ test เรียกด้วย 4 พารามิเตอร์ → `ERROR: function public.create_poll_drop(...) is not unique`
- **ความเสี่ยงที่เหลือ:** overload เก่า 2 ตัวเป็นโค้ด SECURITY DEFINER ที่ยังเรียกถึงได้และข้าม logic ใหม่ (audience/location) ไม่ใช่การยกระดับสิทธิ์ (ค่า default คือ `everyone` ซึ่งกว้างที่สุดอยู่แล้ว) แต่เป็นทางเข้าที่ไม่ควรเปิดทิ้งไว้

**ทำแล้วตาม Founder decision ข้อ 3** — เพิ่มท้าย `schema.sql` 2 คำสั่ง:
```sql
drop function if exists public.create_poll_drop(text, text[], int, uuid[]);
drop function if exists public.create_poll_drop(text, text[], int, uuid[], text, uuid[]);
```

**Pre-check ที่สั่งให้ทำก่อนลบ — ทำครบแล้ว:**

| ตรวจ | ผล |
|---|---|
| ตรวจ call site ทุกจุด | ✅ มีจุดเดียวในทั้ง repo: `drop_repository.dart:623` (grep ทั้ง `app/`, `admin/`, `seller_app/`) |
| signature ที่เหลือคือตัวที่แอปใช้จริงหรือไม่ | ✅ แอปส่งชื่อพารามิเตอร์ครบ 10 ตัวตรงกับ overload 10 พารามิเตอร์เป๊ะ |
| รัน database/RLS test | ✅ supabase test 23/33 → **27/33** (test 4 ไฟล์ที่เคยล้มเพราะเรียกชนกลับมาผ่าน) |
| พฤติกรรมแอปเปลี่ยนหรือไม่ | ✅ ไม่เปลี่ยน — `flutter test` 1,086 ผ่านเท่าเดิม, ไม่มีโค้ด Dart ถูกแก้ |

---

## 4. Test Results

### 4.1 Flutter (Locally verified)

| | ก่อนเริ่ม audit | ตอนนี้ |
|---|---|---|
| `flutter analyze` | ✅ 0 issues | ✅ **0 issues** |
| `flutter test` | ✅ 1,048 | ✅ **1,086 ผ่าน** (+38) |
| `flutter build web --release` | — | ✅ **สำเร็จ** |
| `check_schema_ordering.py` | ✅ OK | ✅ OK |

### 4.2 Supabase RLS/Database tests (`supabase/tests/*.sh`) — PostgreSQL 16.13

**รันกับ `supabase/schema.sql` จริงใน repo (ไม่ใช่สำเนา patch แล้ว):**

| จุดวัด | ผล |
|---|---|
| ก่อนเริ่มงานรอบนี้ (schema.sql เดิม) | **4 ผ่าน / 29 ล้ม** |
| หลัง SCHEMA-002 (patch 2 บรรทัด) | **23 ผ่าน / 10 ล้ม** |
| **หลัง SCHEMA-003 (drop 2 overload) — สถานะปัจจุบัน** | ✅ **27 ผ่าน / 6 ล้ม** |

**27 ตัวที่ผ่าน** ครอบคลุม RLS/security ของ: club post mentions · block RPC exposure · moderation queue · appeal · chat · message request · share-to-chat · redrop · poll in drop · draft system · edit/delete drop · private account · discovery · privacy controls · notification settings · platform documents · data rights · audit log · admin dashboard · unified home feed · multi-image drop · recommendation dismissal · analytics · feed signals · view count (WYN-083) · image count · image dimensions

**6 ตัวที่ยังล้ม — ตรวจแล้วทุกตัว ไม่มีตัวไหนเป็นบั๊กผลิตภัณฑ์:**

| ไฟล์ | สาเหตุ | ประเภท |
|---|---|---|
| `wyn_041`, `wyn_043`, `wyn_051`, `wyn_052`, `wyn_054_055` | test seed username ที่ constraint `profiles_username_not_reserved` (เพิ่มทีหลังใน WYN-077) ห้าม | **test เก่าไม่ทันกับ schema** |
| `wyn_038_view_counting` | CHECK2/3/3b/4 assert ว่ามี unique-viewer dedup และตัด self-view ออก ซึ่ง **WYN-083 เอาออกโดยตั้งใจ** ("every call counts, including repeats and the Drop's own author" — comment ใน `drop_repository.dart:992`) | **test ถูกแทนที่แล้ว** |

**หลักฐานว่า `wyn_038` เป็น test เก่าไม่ใช่บั๊ก:** `wyn_083_view_count_owner_and_repeat_test.sh` **ผ่าน** โดย assert พฤติกรรมตรงข้ามเป๊ะ — `CHECK1_repeat_views_from_same_viewer_all_count` (ได้ 3/3) และ `CHECK2_authors_own_view_counts` (ได้ 4/4) test สองไฟล์นี้ขัดกันเอง และไฟล์ใหม่คือไฟล์ที่ตรงกับ product decision ปัจจุบัน

> **สรุป: 0 บั๊กผลิตภัณฑ์จาก 33 ไฟล์** ส่วนที่เหลือคืองานทำความสะอาด test fixture (P3 — §6.2)

## 5. Regression Results

| การตรวจ | ผล |
|---|---|
| Flutter test เดิมทั้งหมด | ✅ ไม่มีตัวไหนพัง (1,086 ผ่าน) |
| Supabase test (ค) เทียบ (ข) | ✅ `diff` = ว่าง — เหมือนกันทุกบรรทัด |
| Supabase test สภาพ repo ปัจจุบัน ก่อน/หลังงานรอบนี้ | ✅ `diff` = ว่าง (4 ผ่าน / 29 ล้ม เท่าเดิม) |
| `flutter build web --release` | ✅ สำเร็จ |
| ZOKY ถูกแตะหรือไม่ | ✅ **ไม่ถูกแตะเลย** — `git diff --stat origin/main..HEAD -- app/lib/features/zoky/` ว่างเปล่า |

**ตรวจ regression รายฟีเจอร์ตามที่สั่ง** (ผ่านชุด test อัตโนมัติที่มีอยู่ + test ใหม่ 38 ตัว):

| ฟีเจอร์ | ครอบคลุมโดย | ผล |
|---|---|---|
| Security / RLS | 23 supabase test + attack matrix ที่เขียนใหม่ | ✅ Locally verified |
| Database | index 9 ตัว + EXPLAIN + duplicate check | ✅ Locally verified |
| API | repository test ผ่าน Recording fakes | ✅ Locally verified |
| Authentication | `auth_gate_test`, `email_auth_screen_test`, onboarding tests | ✅ Locally verified |
| Feed | `home_feed_screen_test` (84 test) + `wyn_063_unified_home_feed` | ✅ Locally verified |
| Posts | `create_drop_screen_test`, `drop_detail_screen_test`, `drop_test` | ✅ Locally verified |
| Likes | `drop_comment_like_test`, feed serialization test | ✅ Locally verified |
| Comments | comment pagination test (Drop) + `drop_comment_test` | ✅ Locally verified |
| Profile | `edit_profile_screen_test`, `avatar_circle_test`, profile tab tests | ✅ Locally verified |
| Follow / Social graph | `follow_list_screen_test`, `follow_request_list_screen_test`, `wyn_039_private_account` | ✅ Locally verified |
| Search | `search_screen_test` + `quotePostgrestFilterValue` test | ✅ Locally verified |
| Notifications | `notification_test`, `wyn_044_notification_settings` | ✅ Locally verified |
| Navigation | `root_shell_test` | ✅ Locally verified |
| Loading / Empty / Error / Retry | skeleton test, load-more retry test, network error test | ✅ Locally verified |
| Image performance | `network_thumbnail_test`, `avatar_circle_test` (decode width) | ✅ Locally verified |
| Mobile UX | touch target 44px, safe area, keyboard — **ตรวจจากโค้ดและ widget test เท่านั้น** | ⚠️ Not verified บนอุปกรณ์จริง |

---

## 6. Remaining Issues

### 6.1 Remaining blockers — เหลืออย่างเดียว

| # | เรื่อง | สถานะ | ต้องการอะไร |
|---|---|---|---|
| **1** | **Apply index 9 ตัวกับ production** | อนุมัติแล้ว · ตรวจครบในเครื่อง · **ยังไม่ apply** | Supabase production credential — session นี้ไม่มี |

**ไม่มี blocker อื่นเหลือ** — 3 เรื่องที่เคยค้างในรายงานรอบก่อนปิดครบแล้ว:
- ✅ `schema.sql` โหลดไม่ได้ → แก้แล้ว (SCHEMA-002)
- ✅ `create_poll_drop` overload → แก้แล้ว (SCHEMA-003)
- ✅ `WITH CHECK` → Founder ตัดสินว่าไม่ apply

### 6.2 งานที่รู้ตัวว่ายังไม่ทำ (ไม่ใช่ blocker)

| เรื่อง | เหตุผล | P |
|---|---|---|
| test fixture 6 ไฟล์ล้าสมัย (5 ไฟล์ seed username ต้องห้าม + `wyn_038` ที่ถูก `wyn_083` แทนที่) | ไม่ใช่บั๊กผลิตภัณฑ์ แต่ทำให้ตัวเลข coverage ดูแย่กว่าความจริง | P3 |
| `pop_likes` index | รอ Pop กลับ active scope ตามคำสั่ง | — |
| index ซ้ำซ้อนเดิม 3 ตัว (`cart_items_user_id_idx`, `conversations_user_a_idx`, `drop_poll_votes_poll_idx`) | เปลืองพื้นที่/ต้นทุนเขียนเล็กน้อย ไม่ได้อนุมัติให้แก้ | P3 |
| `errorMessageFor` ต่อแค่ 3 หน้าจอ (Home/Search/Notifications) | อีก ~60 catch block ยังใช้ข้อความเดิม | P2 |
| `home_feed` มี correlated subquery 8 ตัวต่อแถว | ทางแก้จริงคือ denormalized counter → **Beta3** | — |
| ZOKY: 4 จุด `mounted` + รูปสินค้าไม่มี cacheWidth | **ห้ามแตะตามคำสั่ง** — ส่งต่อเจ้าของ track | — |

---

## 7. Known Limitations

### 7.1 ✅ แก้แล้ว: `schema.sql` โหลดลงฐานข้อมูลเปล่าไม่ได้ (SCHEMA-002)

**เดิม:** รัน `schema.sql` กับฐานข้อมูลใหม่จะหยุดกลางคัน
```
ERROR: cannot change name of view column "comment_count" to "liked_by"
```

**สาเหตุ:** `public.home_feed` ถูกนิยามซ้ำ 10 ครั้ง และ 2 ครั้งในนั้นแทรกคอลัมน์กลางลิสต์แทนที่จะต่อท้าย ซึ่ง `create or replace view` ไม่ยอม — บรรทัด 7170 (แทรก `liked_by` ก่อน `comment_count`) และ 10730 (แทรก `author_is_verified` ก่อน `created_at`)

**แก้แล้วด้วยการเปลี่ยนแปลงที่เล็กที่สุด:** เติม `drop view if exists public.home_feed;` 2 บรรทัดก่อน 2 statement นั้น — **insert อย่างเดียว ไม่ลบ ไม่แก้บรรทัดเดิมแม้แต่บรรทัดเดียว** ผลลัพธ์ปลายทางเหมือนเดิมทุกประการ

**ปลอดภัยเพราะ:** จุดแรกไม่มีอะไรพึ่งพา view เลย · จุดที่สองมีแค่ `get_wynos_ranked_feed()` ซึ่งเป็น dollar-quoted `language sql` function ที่ PostgreSQL ไม่บันทึก hard dependency จึง drop ได้โดยไม่ต้อง CASCADE และไม่พาอะไรไปด้วย

**ผลที่วัดได้:** supabase test **4/33 → 23/33** และหลัง SCHEMA-003 เป็น **27/33**

### 7.2 อะไรตรวจที่ไหน — แยกให้ชัดตามที่สั่ง

| ระดับ | ครอบคลุมอะไร |
|---|---|
| ✅ **Locally verified** | ทุกอย่างในรายงานนี้ที่ติดป้าย ✅ — `flutter analyze` (0 issues) · `flutter test` (1,086 ผ่าน) · `flutter build web --release` (สำเร็จ) · PostgreSQL 16.13 ในเครื่อง: โหลด `schema.sql` จริงสะอาด, supabase test 33 ไฟล์ (27 ผ่าน), verify index 9/9, EXPLAIN ทั้ง 9, duplicate-index check, attack matrix, legitimate-flow matrix · `check_schema_ordering.py` OK |
| ❌ **Production verified** | **ไม่มีเลย — ศูนย์รายการ** session นี้ไม่มี Supabase production credential ไม่ได้เชื่อมต่อ production แม้แต่ครั้งเดียว **ไม่มี index ตัวไหนถูกสร้างบน production** และ **ไม่มี schema change ใดถูก apply กับ production** |
| ⚠️ **Not verified** | พฤติกรรม `storage.objects` policy (ตาราง stub ในเครื่อง ไม่มี Supabase Storage จริง) · UX บนอุปกรณ์จริง (iOS/Android/เบราว์เซอร์) · ตัวเลข memory ของรูป (คำนวณจาก `w×h×4` ไม่ได้วัดด้วย DevTools) · performance บนข้อมูล production จริง (EXPLAIN ใช้ข้อมูลจำลอง) · การทดสอบเชิงพฤติกรรมโดยมนุษย์ · push notification (ต้องมี Firebase จริง) · Google Sign-In flow |

---

## 8. Production Readiness

### สรุป: **QA READY — ยังไม่ Production Ready**

**เหลืออุปสรรคเดียว และไม่ใช่เรื่องคุณภาพโค้ด:** ยังไม่มีอะไรถูก apply กับ production เพราะ session นี้ไม่มี Supabase credential

### เงื่อนไขที่เหลือเพื่อเป็น Production Ready

| # | ขั้นตอน | ใครทำ |
|---|---|---|
| 1 | Apply `supabase/migrations_beta2_indexes.sql` กับ production | ผู้มี credential |
| 2 | Apply SCHEMA-002 + SCHEMA-003 กับ production (2 `drop view` + 2 `drop function` ท้าย `schema.sql`) | ผู้มี credential |
| 3 | Verify: index ครบ 9 ตัว · `create_poll_drop` เหลือ overload เดียว | ผู้มี credential |
| 4 | `EXPLAIN ANALYZE` บนข้อมูลจริง แล้วรายงานส่วนต่างจากผลในเครื่อง | ผู้มี credential |
| 5 | AI QA & Security ทดสอบเชิงพฤติกรรมตาม `WORKFLOW.md` | AI QA |
| 6 | Smoke test อุปกรณ์จริง: login → feed → โพสต์ → like → comment → profile → follow → search → notification → logout | Founder/QA |

> ⚠️ **ห้าม apply `pending_approval_rls_with_check.sql`** — ไม่อยู่ใน Beta2 deployment

### SQL สำหรับ verify หลัง apply

```sql
-- 1) index ต้องได้ครบ 9 แถว
select indexname, tablename from pg_indexes
where indexname in (
  'drops_created_at_idx','drops_author_created_idx','drop_likes_user_idx',
  'drop_comments_drop_created_idx','follows_following_idx',
  'follow_requests_target_idx','saves_content_idx',
  'club_posts_club_pinned_created_idx','club_post_comments_post_created_idx'
) order by tablename;

-- 2) create_poll_drop ต้องเหลือแถวเดียว (10 พารามิเตอร์)
select p.oid::regprocedure from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'create_poll_drop';

-- 3) ต้องไม่มี WITH CHECK ถูก apply โดยบังเอิญ -- ควรได้ 6 แถว (สถานะเดิม)
select tablename, policyname from pg_policies
where cmd = 'UPDATE' and with_check is null order by 1;
```

---

## 9. ปิดท้าย

**Beta2 ทำตามเป้าหมายที่ Founder ตั้งไว้:** ไม่มีฟีเจอร์ใหม่ถูกเพิ่มแม้แต่ตัวเดียวตลอดทั้ง audit ทุกการเปลี่ยนแปลงคือการทำของเดิมให้เสร็จ — feed ที่เรียงถูก, รูปที่ไม่กินหน่วยความจำเกินจำเป็น, การกดที่ไม่ race กัน, comment ที่ไม่พังเมื่อโพสต์ดัง, scroll ที่ไม่หาย, error ที่บอกความจริง, ปุ่มที่กดโดนตามมาตรฐานของ design system ตัวเอง และตอนนี้ฐานข้อมูลที่สร้างใหม่จากไฟล์ได้จริงพร้อม test ที่รันได้ 27 จาก 33

**Beta3 ยังไม่เริ่ม** ตามคำสั่ง — งานที่ยกไป Beta3 (denormalized counter, cursor pagination, state management, image CDN) บันทึกไว้ใน `wynos-v1.0.0-beta2-full-audit.md` §11 แล้ว

> **สถานะการหยุด:** ไม่ apply อะไรกับ production · ไม่เปิด PR · ไม่ merge · ไม่ deploy application code · รอ Founder review
