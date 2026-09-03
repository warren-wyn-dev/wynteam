# WYNOS v1.0.0 Beta2 — Final QA & Readiness Report

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta2-audit-fevu5g` — **ยังไม่เปิด PR ยังไม่ merge** ตามคำสั่ง Founder
> เอกสารก่อนหน้า: `wynos-v1.0.0-beta2-full-audit.md` (Phase 1) · `wynos-v1.0.0-beta2-readiness.md` (รอบก่อน)
> Environment: PostgreSQL 16.13 ในเครื่อง (ติดตั้งใน session นี้) · Flutter 3.47.1 (SDK เดียวกับ CI/production)
> **ไม่มี Supabase production credential ใน session นี้** — ทุกข้อความในรายงานติดป้ายกำกับว่าตรวจที่ไหน

---

## 🚦 ระดับความพร้อม: **QA READY** (ยังไม่ใช่ Production Ready)

| ระดับ | สถานะ | เหตุผล |
|---|:--:|---|
| Development Ready | ✅ | analyze 0 issues · test 1,086 ผ่าน · build web สำเร็จ |
| **QA Ready** | ✅ **อยู่ตรงนี้** | ทุกงานที่อนุมัติทำเสร็จและตรวจแล้วในเครื่อง ไม่มีอะไรค้างครึ่ง ๆ กลาง ๆ |
| Production Ready | ❌ | ยังไม่มีอะไรถูก apply กับ production เลย และมี **ข้อบกพร่องระดับ release-engineering 1 ข้อที่ต้องตัดสินใจก่อน** (§7 — `schema.sql` โหลดลงฐานข้อมูลเปล่าไม่ได้) |
| Blocked by Security | ❌ | ไม่มีช่องโหว่ที่ยืนยันได้ — **รวมถึงข้อที่ผมเคยรายงานว่าเป็น P0 ซึ่งกลายเป็นว่าไม่ใช่ ดู §2** |

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
- ผมยัง apply ให้ในเครื่องตามที่อนุมัติ และยืนยันว่าไม่พังอะไร (§2) แต่ **Founder ควรตัดสินใจใหม่บนข้อมูลที่ถูกต้อง** ว่าจะ apply กับ production หรือไม่ เพราะเหตุผลที่ให้อนุมัติไปนั้นไม่เป็นความจริง

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

### 2.1 WITH CHECK — apply และตรวจแล้ว (Locally verified)

```
apply supabase/pending_approval_rls_with_check.sql → exit 0
```

**ยืนยันหลัง apply ว่า policy ทั้ง 6 ตัวมี `with_check` ชัดเจน:**

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

**สรุป:** ไม่มี flow ไหนพัง ไม่มีพฤติกรรมไหนเปลี่ยน — ตรงกับที่คาดไว้ว่าเป็น no-op (§0)

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

### 3.1 Index — apply และตรวจครบ (Locally verified)

```
apply supabase/migrations_beta2_indexes.sql → exit 0 (idempotent: รันซ้ำได้)
verify: 9 / 9 index ถูกสร้าง
```

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

### 3.3 พบใหม่ระหว่าง QA: `create_poll_drop` มี 3 overload ที่เรียกชนกัน

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

**ข้อเสนอ (ต้องอนุมัติ ยังไม่ทำ):** `drop function public.create_poll_drop(text,text[],integer,uuid[]);` และตัว 6 พารามิเตอร์ แล้วเก็บเฉพาะตัวล่าสุด

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

**นี่คือส่วนที่รอบก่อนยังทำไม่ได้ และตอนนี้ทำได้แล้ว**

| การรัน | ผล |
|---|---|
| **(ก) `schema.sql` ตามที่อยู่ใน repo ตอนนี้** | **4 ผ่าน / 29 ล้ม** |
| **(ข) `schema.sql` + patch 2 บรรทัด (สำเนาในเครื่อง)** | **23 ผ่าน / 10 ล้ม** |
| **(ค) แบบ (ข) + `WITH CHECK` + index ที่อนุมัติ** | **23 ผ่าน / 10 ล้ม — เหมือน (ข) ทุกตัว** |

**สิ่งที่ตัวเลขนี้บอก:**

1. **(ก) → (ข):** 29 ตัวที่ล้มในสภาพปัจจุบัน **ไม่ได้ล้มเพราะโค้ดผิด** แต่ล้มเพราะ `schema.sql` โหลดลงฐานข้อมูลเปล่าไม่ได้ (§7) ทั้ง 29 ล้มที่บรรทัดเดียวกันเป๊ะ
2. **(ข) → (ค):** การเปลี่ยนแปลงที่ Founder อนุมัติ **ไม่ทำให้ test ตัวไหนเปลี่ยนสถานะเลยแม้แต่ตัวเดียว** — นี่คือหลักฐาน regression ที่ตรงที่สุด
3. **23 ตัวที่ผ่าน** ครอบคลุม RLS/security ของ: club post mentions, block RPC exposure, moderation queue, appeal, chat, message request, share-to-chat, redrop, private account, discovery, notification settings, platform documents, data rights, audit log, admin dashboard, unified home feed, multi-image drop, recommendation dismissal, analytics, feed signals, view count, image count/dimensions

**10 ตัวที่ยังล้ม — ทั้งหมดเป็นของเดิม ไม่มีตัวไหนเกิดจากงานรอบนี้:**

| สาเหตุ | ไฟล์ | ประเภท |
|---|---|---|
| `create_poll_drop` เรียกชนกัน (§3.3) | 035, 036, 037, 038, 045 | ข้อบกพร่อง schema จริง |
| test seed username ที่ constraint `profiles_username_not_reserved` (เพิ่มทีหลังใน WYN-077) ห้าม | 041, 043, 051, 052, 054_055 | test เก่าไม่ทันกับ schema — ไม่ใช่บั๊กของผลิตภัณฑ์ |

---

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

### 6.1 ต้องตัดสินใจก่อน Production (เรียงตามความสำคัญ)

| # | เรื่อง | ทำไมสำคัญ | ต้องการอะไร |
|---|---|---|---|
| **1** | **`schema.sql` โหลดลงฐานข้อมูลเปล่าไม่ได้** (§7) | สร้าง environment ใหม่ / กู้คืน / staging ไม่ได้ และทำให้ automated RLS coverage ตายไป 29/33 | อนุมัติ patch 2 บรรทัด |
| 2 | `create_poll_drop` 3 overload (§3.3) | โค้ด SECURITY DEFINER เก่าที่ยังเรียกถึงได้ + ทำให้ test 5 ไฟล์ล้ม | อนุมัติ `drop function` 2 ตัวเก่า |
| 3 | `WITH CHECK` — **ตัดสินใจใหม่** (§0) | อนุมัติไปบนข้อมูลที่ผมให้ผิด ไม่ใช่การอุดช่องโหว่ | ยืนยันว่ายังจะ apply หรือไม่ |
| 4 | Apply index กับ production | โค้ดพร้อม ยืนยันในเครื่องแล้ว แต่ production ยังไม่ได้อะไร | สั่ง apply + verify |
| 5 | test 5 ไฟล์ seed username ต้องห้าม | ไม่ใช่บั๊กผลิตภัณฑ์ แต่ทำให้ตัวเลข coverage ดูแย่กว่าความจริง | แก้ fixture (งานเล็ก) |

### 6.2 งานที่รู้ตัวว่ายังไม่ทำ (ไม่ได้อยู่ในคำสั่งรอบนี้)

| เรื่อง | สถานะ |
|---|---|
| `pop_likes` index | รอ Pop กลับ active scope ตามคำสั่ง |
| index ซ้ำซ้อนเดิม 3 ตัว | เปลืองพื้นที่/ต้นทุนเขียนเล็กน้อย ไม่ได้แก้ (ไม่ได้อนุมัติ) |
| `errorMessageFor` ยังต่อแค่ 3 หน้าจอ | Home / Search / Notifications — หน้าจอที่เหลือ (~60 catch block) ยังใช้ข้อความเดิม |
| `home_feed` มี correlated subquery 8 ตัวต่อแถว | ทางแก้จริงคือ denormalized counter → Beta3 |
| ZOKY: 4 จุด `mounted` + รูปสินค้าไม่มี cacheWidth | **ห้ามแตะตามคำสั่ง** — ส่งต่อเจ้าของ track |

---

## 7. Known Limitations

### 7.1 ⚠️ ข้อจำกัดที่ใหญ่ที่สุด: `schema.sql` โหลดลงฐานข้อมูลเปล่าไม่ได้

**อาการ:** รัน `schema.sql` กับฐานข้อมูลใหม่จะหยุดกลางคันที่บรรทัด 7379
```
ERROR: cannot change name of view column "comment_count" to "liked_by"
```

**สาเหตุ (หาเจอในรอบนี้):** `public.home_feed` ถูกนิยามซ้ำ 10 ครั้งในไฟล์ และ 2 ครั้งในนั้น **แทรกคอลัมน์กลางลิสต์แทนที่จะต่อท้าย** ซึ่ง `create or replace view` ของ PostgreSQL ไม่ยอม:
- บรรทัด 7170 — แทรก `liked_by` ก่อน `comment_count` (ตำแหน่งที่ 14)
- บรรทัด 10730 — แทรก `author_is_verified` ก่อน `created_at` (ตำแหน่งที่ 6)

**ยืนยันว่านี่คือสาเหตุเดียว:** เติม `drop view if exists public.home_feed;` ก่อน 2 statement นั้น (แค่ 2 บรรทัด) แล้ว schema โหลดสะอาดทันที และ test ที่รันได้เพิ่มจาก 4 → 23

**ผลกระทบ:** สร้าง staging / กู้คืน / เปิดเครื่อง dev ใหม่จาก `schema.sql` ไม่ได้ · automated RLS coverage 29/33 รันไม่ได้ · production ไม่ได้รับผลกระทบเพราะสร้างมาแบบสะสมทีละ statement

**สิ่งที่ผมทำ:** patch **เฉพาะสำเนาในเครื่อง** เพื่อทำ QA — **ไม่แตะ `supabase/schema.sql` ใน repo** เพราะเป็นการเปลี่ยนโครงสร้าง database ที่ยังไม่ได้รับอนุมัติ

**ข้อเสนอ (รออนุมัติ):** เติม 2 บรรทัดนั้นลง `schema.sql` — ปลอดภัยเพราะไม่มีอะไรพึ่งพา view ณ จุดแรก และจุดที่สองมีแค่ `get_wynos_ranked_feed()` ซึ่งเป็น `language sql` แบบ dollar-quoted (PostgreSQL ไม่สร้าง hard dependency) ผลลัพธ์ปลายทางเหมือนเดิมทุกประการ

### 7.2 อะไรตรวจที่ไหน — แยกให้ชัดตามที่สั่ง

| ระดับ | ครอบคลุมอะไร |
|---|---|
| ✅ **Locally verified** | ทุกอย่างในรายงานนี้ที่ติดป้าย ✅ — Flutter analyze/test/build, PostgreSQL 16.13 ในเครื่อง (โหลด schema, apply ทั้ง 2 ไฟล์, verify policy/index, EXPLAIN, attack matrix, supabase test 33 ไฟล์) |
| ❌ **Production verified** | **ไม่มีเลย — ศูนย์รายการ** session นี้ไม่มี Supabase production credential ไม่มีอะไรถูก apply กับ production และผมไม่ได้เชื่อมต่อ production แม้แต่ครั้งเดียว |
| ⚠️ **Not verified** | พฤติกรรม `storage.objects` policy (ตาราง stub) · UX บนอุปกรณ์จริง (iOS/Android/เบราว์เซอร์) · ตัวเลข memory ของรูป (คำนวณจาก `w×h×4` ไม่ได้วัดด้วย DevTools) · performance บนข้อมูล production จริง · การทดสอบเชิงพฤติกรรมโดยมนุษย์ · push notification (ต้องมี Firebase จริง) · Google Sign-In flow |

---

## 8. Production Readiness

### สรุป: **QA READY — ยังไม่ Production Ready**

**เหตุผลที่ยังไม่ใช่ Production Ready ไม่ใช่เรื่องคุณภาพโค้ด:**

1. **ยังไม่มีอะไรถูก apply กับ production เลย** — index และ policy ยังอยู่แค่ในไฟล์
2. **มี 3 เรื่องที่ต้องให้ Founder ตัดสินก่อน** — §7.1 (schema โหลดไม่ได้), §3.3 (overload), §0 (WITH CHECK ที่อนุมัติบนข้อมูลผิด)
3. **ยังไม่มีการทดสอบโดยมนุษย์บนอุปกรณ์จริง** — CI และ 1,086 test แทน AI QA & Security เชิงพฤติกรรมไม่ได้ ตาม `.wyn/company/WORKFLOW.md`

**เงื่อนไขที่จะเป็น Production Ready:**

1. ตัดสิน §7.1 / §3.3 / §0
2. apply index กับ production แล้ว verify ว่าครบ 9 ตัว (SQL สำหรับ verify อยู่ในรายงานรอบก่อน §3)
3. `EXPLAIN ANALYZE` ซ้ำบนข้อมูลจริง
4. AI QA & Security ทดสอบเชิงพฤติกรรมตาม `WORKFLOW.md` แล้ว PASS
5. Smoke test บนอุปกรณ์จริงอย่างน้อย: login → feed → โพสต์ → like → comment → profile → follow → search → notification → logout

**สิ่งที่ Beta2 บรรลุแล้ว ตรงกับเป้าหมายที่ Founder ตั้งไว้:** ไม่มีฟีเจอร์ใหม่ถูกเพิ่มแม้แต่ตัวเดียวในรอบนี้ ทุกการเปลี่ยนแปลงคือการทำของเดิมให้เสร็จ — feed ที่เรียงถูก รูปที่ไม่กินหน่วยความจำเกินจำเป็น การกดที่ไม่ race กัน comment ที่ไม่พังเมื่อโพสต์ดัง scroll ที่ไม่หาย error ที่บอกความจริง และปุ่มที่กดโดนตามมาตรฐานของ design system ตัวเอง

> **สถานะการหยุด:** ไม่ apply อะไรกับ production · ไม่เปิด PR · ไม่ merge · รอ Founder review
