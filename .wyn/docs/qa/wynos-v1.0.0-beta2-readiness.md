# WYNOS v1.0.0 Beta2 — Final Readiness Report

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta2-audit-fevu5g` (ยังไม่เปิด PR ยังไม่ merge ตามคำสั่ง Founder)
> อ้างอิง audit เต็ม: `.wyn/docs/qa/wynos-v1.0.0-beta2-full-audit.md`
> Baseline: `origin/main` @ `e67c4e9`

## 🚦 ระดับความพร้อม: **QA READY**

**ไม่ใช่ Production Ready** และ **ไม่ใช่ Blocked by Security** — เหตุผลตรงไปตรงมา:

| ระดับ | ผ่านหรือไม่ | เหตุผล |
|---|:--:|---|
| Development Ready | ✅ ผ่านมานานแล้ว | analyze สะอาด, test 1,078 ผ่าน, build web สำเร็จ |
| **QA Ready** | ✅ **อยู่ตรงนี้** | โค้ดทั้งหมดพร้อมให้ AI QA & Security ทดสอบเชิงพฤติกรรมบน branch นี้ ไม่มีอะไรค้างครึ่ง ๆ กลาง ๆ ไม่มี build ที่พัง |
| Production Ready | ❌ **ยังไม่** | ติด 2 อย่างที่ **ไม่ใช่เรื่องโค้ด**: (1) ช่องโหว่ P0 `WITH CHECK` ที่ยังรออนุมัติ (2) index ที่ยังไม่ถูก apply เข้า production database |
| Blocked by Security | ❌ ไม่ถึงขั้นนั้น | ช่องโหว่ที่พบต้องอาศัยการเรียก REST API ตรง ๆ ด้วยบัญชีที่ล็อกอินแล้ว ไม่ใช่ remote exploit และไม่ทำให้ข้อมูลรั่วเป็นวงกว้าง — แต่ **ห้าม deploy production จนกว่าจะปิด** |

**เงื่อนไขที่จะเลื่อนขึ้นเป็น Production Ready:** ต้องครบทั้ง 3 ข้อ
1. Founder อนุมัติ + apply `supabase/pending_approval_rls_with_check.sql` แล้ว **verify ว่า policy มี `with check` จริงในฐานข้อมูล**
2. apply `supabase/migrations_beta2_indexes.sql` แล้ว **verify ว่า index ทั้ง 9 ตัวถูกสร้างจริง**
3. AI QA & Security รัน regression ตาม `.wyn/company/WORKFLOW.md` แล้ว PASS

⸻

## 1. FIXED — แก้แล้ว ทดสอบแล้ว อยู่บน branch แล้ว

ทั้งหมด **17 รายการ** commit ไว้ 4 commit บน `claude/wynos-beta2-audit-fevu5g`

### P0
| รายการ | สิ่งที่แก้ | หลักฐาน |
|---|---|---|
| B2-01 | PostgREST filter injection ใน `searchProfiles` — quote ค่าตาม PostgREST grammar | 6 test ใหม่ใน `text_utils_test.dart` |

### P1
| รายการ | สิ่งที่แก้ | หลักฐาน |
|---|---|---|
| B2-03 | ฟีด "สำหรับคุณ" เรียงผิดเงียบ ๆ — คะแนน ranking ติดไปกับแถวของตัวเอง ไม่ใช่ค้นด้วย index | 5 test ใน `home_ranking_test.dart` |
| B2-04 | เลิกยิง RPC 200-candidate ซ้ำทุกหน้า — สร้าง window ครั้งเดียวต่อรอบ scroll | — |
| B2-05 | เลิก await เรียงกัน — profile 4 คำขอ และ home feed 5–6 คำขอ ยิงพร้อมกัน | — |
| B2-06 | รูปใน grid/avatar decode ตามขนาดที่วาดจริง (physical px) ไม่ใช่ขนาดไฟล์ | 12 test (`network_thumbnail_test.dart`, `avatar_circle_test.dart`) |
| B2-07 | dedupe แถวซ้ำจาก offset pagination | 1 test |
| B2-08 | serialize การเขียนต่อแถว (ไม่ทิ้ง tap) + idempotent upsert | 1 test + 2 test เดิมยังผ่าน |
| B2-10 | comment pagination 50/หน้า พร้อมปุ่ม "ดูคอมเมนต์เพิ่มเติม" | 2 test |
| B2-11 | คืน scroll position หลังกลับจาก Detail — refresh เฉพาะการ์ดใบนั้น | 1 test |

### P2 / P3
| รายการ | สิ่งที่แก้ |
|---|---|
| B2-12 | touch target ของ Like/comment/ReDrop จาก ~25px → 44px (ตาม token ของ design system เอง) |
| B2-13 | skeleton แทน spinner บนหน้า Home |
| B2-14 | load-more ที่ล้มเหลวมีปุ่มลองใหม่ ไม่เงียบอีกต่อไป |
| B2-15 | placeholder ตอนโหลด/โหลดล้มเหลว ให้ grid tile + avatar (**ทำบางส่วน — ดู §4**) |
| B2-16 | `mounted` guard 11 จุดฝั่ง Wynos (**เหลือ 4 จุดฝั่ง ZOKY — ดู §5**) |
| B2-17 | `cacheControl` 1 ปี บนไฟล์ที่ path ไม่เปลี่ยน (ไม่แตะ avatar โดยตั้งใจ) |
| B2-19 | error boundary ระดับแอป (release เท่านั้น) |
| B2-20 | animation + haptic ตอนกด Like/ReDrop |

**Regression gate ที่รันจริง:** `flutter analyze` 0 issues · `flutter test` 1,078/1,078 · `flutter build web --release` สำเร็จ · `check_schema_ordering.py` OK

⸻

## 2. APPROVAL REQUIRED — ต้องได้รับอนุมัติจาก Founder ก่อนทำ

### 🔴 P0 — UPDATE policy 6 ตัวไม่มี `WITH CHECK`

**ไฟล์:** `supabase/pending_approval_rls_with_check.sql` (เตรียมไว้แล้ว **ยังไม่ apply**)

#### ช่องโหว่คืออะไร

ใน PostgreSQL RLS สอง clause นี้ตอบคนละคำถาม:

| clause | ตอบคำถาม |
|---|---|
| `USING` | "ผู้ใช้คนนี้**แก้แถวไหนได้บ้าง**" |
| `WITH CHECK` | "แถว**หลังแก้เสร็จ** หน้าตาต้องเป็นอย่างไรถึงจะยอมรับ" |

ทั้ง 6 policy มีแต่ `USING` ผลคือฐานข้อมูลตรวจแค่ว่า "แถวก่อนแก้เป็นของคุณ" แต่**ไม่ตรวจว่าแถวหลังแก้ยังเป็นของคุณอยู่ไหม** ผู้ใช้จึงแก้แถวของตัวเองให้กลายเป็นของคนอื่นได้ — ย้ายแถวออกจากขอบเขตของตัวเองไปอยู่ในขอบเขตคนอื่น

#### SQL ที่เตรียมไว้ (ทั้ง 6 ตัว)

ทุกตัวคือ policy เดิม **เป๊ะ ๆ** + เพิ่ม `with check` ที่มีเงื่อนไขเดียวกับ `using` ของตัวเอง

```sql
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);              -- ← บรรทัดเดียวที่เพิ่ม

drop policy if exists "Users can update their own private profile fields" on public.profile_private;
create policy "Users can update their own private profile fields"
  on public.profile_private for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can update their own cart items" on public.cart_items;
create policy "Users can update their own cart items"
  on public.cart_items for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Club owners and admins can update club info" on public.clubs;
create policy "Club owners and admins can update club info"
  on public.clubs for update to authenticated
  using (public.club_role(id, auth.uid()) in ('owner', 'admin'))
  with check (public.club_role(id, auth.uid()) in ('owner', 'admin'));

drop policy if exists "Club staff can pin or unpin club posts" on public.club_posts;
create policy "Club staff can pin or unpin club posts"
  on public.club_posts for update to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'))
  with check (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'));

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

#### ผลกระทบของช่องโหว่ (ถ้าไม่แก้)

| ตาราง | สิ่งที่ผู้ใช้ที่ล็อกอินแล้วทำได้ | ความรุนแรง |
|---|---|---|
| `profiles` | เปลี่ยน `id` ของโปรไฟล์ตัวเองเป็น uuid ของ auth user ที่ยังไม่มีแถว profile → **ยึดตัวตน** บัญชีนั้น (โพสต์/ผู้ติดตาม/ทุกอย่างที่ผูกกับ id นั้นกลายเป็นของผู้โจมตี) | **สูงสุด** |
| `profile_private` | แบบเดียวกัน กับข้อมูลวันเกิด/สถานะ onboarding | สูง |
| `club_posts` | ย้ายโพสต์ที่ตัวเองมีสิทธิ์ pin ไปอยู่ใน Club อื่นที่ไม่มีสิทธิ์ | กลาง |
| `clubs` | แก้แถว Club ที่ดูแลอยู่ให้กลายเป็นแถวที่ตัวเองไม่มีสิทธิ์ดูแล | กลาง |
| `cart_items` | ย้ายสินค้าจากตะกร้าตัวเองไปใส่ตะกร้าคนอื่น (ZOKY) | ต่ำ–กลาง |
| `storage.objects` | ย้ายไฟล์ออกจากโฟลเดอร์ avatar ของตัวเอง | ต่ำ–กลาง |

**ข้อจำกัดของการโจมตี (เพื่อประเมินความเร่งด่วนให้ตรงความจริง):** ต้องเป็นบัญชีที่ล็อกอินสำเร็จแล้ว และต้องเรียก Supabase REST API เอง — ทำผ่าน UI ของแอปไม่ได้ ไม่ใช่ช่องโหว่ที่ scan เจอจากภายนอกหรือทำได้โดยไม่มีบัญชี **แต่การสมัครบัญชีใน WYNOS เปิดให้ทุกคน** ผู้โจมตีจึงหาเงื่อนไขนี้ได้ง่ายมาก

#### `WITH CHECK` จะเปลี่ยน behavior อะไรบ้าง

**สิ่งที่เปลี่ยน:** UPDATE ที่พยายามเขียนคอลัมน์เจ้าของ (`id` / `user_id` / `club_id` / path ของไฟล์) ให้เป็นค่าที่ไม่ใช่ของตัวเอง จะถูกปฏิเสธด้วย error `new row violates row-level security policy` — จากเดิมที่ **สำเร็จ**

**สิ่งที่ไม่เปลี่ยนเลย:**
- ไม่มีการให้สิทธิ์ใหม่แก่ใคร — เป็นการเพิ่มความเข้มงวดล้วน ๆ
- ไม่แตะ SELECT / INSERT / DELETE policy ใด ๆ
- ไม่แตะตาราง คอลัมน์ constraint หรือข้อมูล
- **flow ที่ถูกต้องของแอปไม่พังแม้แต่จุดเดียว** — ตรวจแล้วว่า `.update(` ทั้ง **25 จุด** ใน `app/lib/` ไม่มีจุดไหนเขียนคอลัมน์เจ้าของ (`id`/`user_id`/`author_id`/`club_id`) เลย

**การย้อนกลับ:** รัน policy เดิม (ไม่มี `with check`) ทับได้ทันที ไม่มีข้อมูลเสียหาย

**ความเสี่ยงของการ apply:** ต่ำที่สุดเท่าที่การแก้ security จะเป็นได้ — เพิ่มเงื่อนไข ไม่ลบเงื่อนไข ทุกคำสั่ง idempotent

> **คำขออนุมัติบันทึกไว้ที่** `.wyn/company/APPROVALS.md` (APPROVAL_REQUIRED 2026-09-03) — สถานะ: **รออนุมัติ**

⸻

## 3. REQUIRES PRODUCTION APPLY — โค้ดเสร็จแล้ว แต่ยังไม่มีผลกับ production

### 🟠 P1 — Database Index (9 ตัว)

**ไฟล์พร้อม apply:** `supabase/migrations_beta2_indexes.sql` (สำเนาเหมือนกันเป๊ะอยู่ท้าย `supabase/schema.sql` ซึ่งเป็น source of truth)

> ⚠️ **สถานะจริง: ยังไม่ถูก apply กับ production** session นี้ไม่มี Supabase credential
> **ห้ามถือว่า production เร็วขึ้นแล้ว** จนกว่าจะรันและ verify ว่า index ถูกสร้างจริง

#### ผลการตรวจซ้ำ (Founder สั่งให้ตรวจ 9 ตัวอีกครั้ง) — พบว่าผมระบุผิด 2 ตัว

ผมตรวจทุก index กับ call site จริงอีกรอบ และ **แก้ข้อผิดพลาดของตัวเอง**:

| การเปลี่ยนแปลง | รายละเอียด |
|---|---|
| ❌ **ตัดออก** `blocks (blocked_id)` | audit รอบแรกผมอ้างว่า "การเช็ค block ทำให้เกิด seq scan" — **ผิด** `internal.is_blocked_either_way()` เขียนว่า `(blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)` ทั้งสองสาขาระบุ `blocker_id` ซึ่งเป็นคอลัมน์นำของ PK อยู่แล้ว → PK ใช้งานได้ทั้งคู่ index นี้ไม่ช่วยอะไรเลย |
| ❌ **ตัดออก** `mutes (muted_id)` | เหตุผลเดียวกัน — ทุก query ทั้งใน schema และใน Dart เป็น `muter_id = auth.uid() and muted_id = ?` ซึ่งเป็นคอลัมน์นำของ PK |
| 🔧 **แก้รูปแบบ** `saves` | เดิม `(content_type, content_id)` — **ผิดรูป** เพราะ query จริงคือ `content_save_count()` = `where content_id = ?` เฉย ๆ ไม่มี content_type และ content_type มีค่าต่างกันแค่ ~3 ค่า (selectivity ต่ำมาก) → เปลี่ยนเป็น `(content_id)` |
| ➕ **เพิ่ม** `club_posts` + `club_post_comments` | ตรวจเจอตอน re-check ว่า `club_posts` **ไม่มี index เลยนอกจาก PK บน `id`** ทั้งที่เป็นฟีดที่ใช้งานจริงใน Beta2 |

จำนวนสุทธิยังเป็น 9 ตัว แต่**ไม่ใช่ 9 ตัวเดิม**

#### รายการสุดท้าย — แต่ละตัวช่วย query ไหน

| # | Index | Query ที่ช่วย | ทำไมของเดิมไม่พอ |
|---|---|---|---|
| 1 | `drops (created_at desc)` | `home_feed` `order by created_at desc` ทุกแท็บ ทุกหน้า | ไม่มี index บน `created_at` เลย → sort ทั้งตารางทุกครั้ง |
| 2 | `drops (author_id, created_at desc)` | Profile grid + `countByAuthor` + Following feed (`author_id in (...)`) | ไม่มี index บน `author_id` |
| 3 | `drop_likes (user_id, created_at desc)` | `fetch_liked_drop_ids()` = `user_id = ? order by created_at desc limit 21` | PK คือ `(drop_id, user_id)` → `user_id` เป็นคอลัมน์ที่สอง ใช้ไม่ได้ทั้ง filter และ sort |
| 4 | `drop_comments (drop_id, created_at)` | comment list + `comment_count`/`top_reply` subquery **ใน `home_feed` ที่รันต่อทุกแถวของฟีด** | ไม่มี index บน `drop_id` |
| 5 | `follows (following_id, created_at desc)` | Follower list, `follower_count()`, ranking ของ suggested users | PK คือ `(follower_id, following_id)` → รองรับแค่ทิศ "ฉันตามใคร" |
| 6 | `follow_requests (target_id, created_at desc)` | คำขอติดตามที่เข้ามา + badge count + trigger ตอนเปลี่ยนบัญชีเป็น public | PK คือ `(requester_id, target_id)` → ทิศเดียวกันปัญหาเดียวกัน |
| 7 | `saves (content_id)` | `content_save_count()` = `count(*) where content_id = ?` | PK นำด้วย `user_id` → scan ทั้งตาราง `saves` ทุกครั้งที่เรียก |
| 8 | `club_posts (club_id, pinned desc, created_at desc)` | ฟีดโพสต์ใน Club — `club_id = ? order by pinned desc, created_at desc` | **ตารางนี้ไม่มี index เลยนอกจาก PK บน `id`** เรียงคอลัมน์ให้ตรงกับ ORDER BY เป๊ะ |
| 9 | `club_post_comments (club_post_id, created_at)` | comment list ของโพสต์ใน Club (คู่ขนานกับข้อ 4) | ไม่มี index บน `club_post_id` |

#### ผลกระทบด้าน Performance

- **ที่ควรได้:** query ทั้ง 9 กลุ่มเปลี่ยนจาก Seq Scan (+ Sort) เป็น Index Scan — เวลาที่ใช้จะไม่โตตามจำนวนแถวทั้งตารางอีกต่อไป
- **ที่เจ็บสุดตอนนี้:** ข้อ 4 — `home_feed` เรียก subquery นับ comment และหา top_reply **ต่อทุกแถวของฟีด** ทุกครั้งที่โหลดหน้า ตอนนี้แต่ละครั้งคือ seq scan `drop_comments`
- **ยังไม่แก้ปัญหารากของ `home_feed`** — subquery 8 ตัวต่อแถวยังอยู่ครบ index ทำให้แต่ละ subquery ถูกลง แต่จำนวนครั้งที่รันเท่าเดิม ทางแก้จริงคือ denormalized counter ซึ่งอยู่ใน OUT OF SCOPE (§5)
- **ยังไม่มีตัวเลขจริง** — วัดไม่ได้จาก session นี้ ต้อง `EXPLAIN ANALYZE` หลัง apply

#### ผลกระทบด้าน Storage และการเขียน

- **พื้นที่:** B-tree index ~ (ขนาดคอลัมน์ + overhead ~16 byte) × จำนวนแถว ที่ข้อมูลระดับ Beta2 คือหลัก **KB ถึง MB ต่อ index** ไม่มีนัยสำคัญ
- **ต้นทุนการเขียน:** ทุก INSERT/UPDATE/DELETE บน 7 ตารางนี้ต้องอัปเดต index เพิ่มด้วย — แลกกับการอ่านที่เร็วขึ้นมาก และแอปนี้อ่านมากกว่าเขียนหลายเท่า **คุ้ม**
- **ตอน apply:** `create index` (ไม่ใช่ `concurrently`) จะ **ล็อกการเขียน** ของตารางนั้นชั่วขณะ ที่ข้อมูลระดับ Beta2 คือเสี้ยววินาที — ถ้าข้อมูลโตมากในอนาคตให้ใช้ `create index concurrently` ทีละคำสั่งแทน (รันใน transaction block ไม่ได้) มีหมายเหตุกำกับไว้ในไฟล์แล้ว
- **การย้อนกลับ:** `drop index <ชื่อ>` ทั้ง 9 ตัว ไม่กระทบข้อมูลใด ๆ

#### วิธี verify หลัง apply (ต้องทำก่อนถือว่าเสร็จ)

```sql
-- ต้องได้ครบ 9 แถว
select indexname, tablename from pg_indexes
where indexname in (
  'drops_created_at_idx','drops_author_created_idx','drop_likes_user_idx',
  'drop_comments_drop_created_idx','follows_following_idx',
  'follow_requests_target_idx','saves_content_idx',
  'club_posts_club_pinned_created_idx','club_post_comments_post_created_idx'
) order by tablename;
```

⸻

## 4. REMAINING BETA2 — อยู่ในขอบเขต Beta2 ควรทำ แต่ยังไม่ได้ทำ

เรียงตามความคุ้มค่าต่อความเสี่ยง **ยังไม่ได้ลงมือ รอ Founder สั่ง**

| # | รายการ | P | ทำไมถึงเป็น Beta2 scope | ขนาดงาน |
|---|---|:--:|---|---|
| R-1 | **`club_post_comments` โหลดทั้งหมดไม่มี pagination** — `club_post_repository.dart:368` | **P1** | เป็นบั๊กตัวเดียวกับที่เพิ่งแก้ให้ Drop comment เป๊ะ ๆ (B2-10) แค่คนละฟีเจอร์ โพสต์ใน Club ที่มีคอมเมนต์หลักพันจะโหลดไม่ขึ้นทั้งหน้า ปล่อยไว้คือรู้ทั้งรู้ว่าพัง | เล็ก — copy pattern จาก B2-10 |
| R-2 | **รูป thumbnail ที่เหลือยังไม่ downsample** — 4 จุดเด่น: `profile_replies_tab` (44px), `saved_post_row` (56px), `trending_tile` (90px), `club_recommended_card` | P1 | เป็นปัญหาเดียวกับ B2-06 ที่ยังไม่ได้แปลง จุด 44px คือ ratio แย่ที่สุดในแอป (1600→44 = เปลือง ~1,300 เท่า) | เล็ก — ใช้ `NetworkThumbnail` ที่มีอยู่แล้ว |
| R-3 | **`Image.network` ที่ไม่มี errorBuilder อีก 16 จุดฝั่ง Wynos** (จาก 25 จุดที่เหลือ, 9 จุดเป็น ZOKY) | P2 | รูปที่โหลดไม่ขึ้นกลายเป็นช่องว่างเปล่า ไม่มีสัญญาณอะไรบอกผู้ใช้ | เล็ก แต่กระจาย |
| R-4 | **B2-18 แยก "เน็ตหลุด" ออกจาก "server error"** | P2 | ผู้ใช้เน็ตหลุดเห็นข้อความเดียวกับตอนระบบล่ม → โทษแอปทั้งที่ไม่ใช่ | กลาง — helper 1 ตัว + แก้ ~63 catch block ที่แสดงข้อความให้ผู้ใช้ |
| R-5 | **`club_members` โหลดทั้งหมดไม่มี pagination** (3 จุดใน `club_repository.dart`) | P2 | Club ที่มีสมาชิกเยอะจะช้าลงเรื่อย ๆ — ยังไม่ถึงขั้นพังเหมือน R-1 | เล็ก–กลาง |
| R-6 | **`pop_likes (user_id, created_at desc)` index** | P3 | เป็นปัญหาแบบเดียวกับ index ข้อ 3 เป๊ะ ๆ แต่ **Pop ถูกพักไว้ (WYN-102)** จึงยังไม่มีใครเจอ — ควรทำพร้อมกับตอนที่ Pop กลับมา ไม่ใช่ตอนนี้ | เล็ก |

⸻

## 5. OUT OF SCOPE — ไม่ควรทำใน Beta2

| # | รายการ | เหตุผลที่ไม่ทำตอนนี้ | ควรไปอยู่ track ไหน |
|---|---|---|---|
| O-1 | **4 จุด `mounted` guard ใน `features/zoky/`** — `zoky_order_detail_screen.dart:117,137`, `review_form_sheet.dart:106`, `zoky_product_results_tab.dart:272` | เป็นบั๊กจริงและแก้ง่ายมาก แต่ **ZOKY เป็นคนละ track** ตาม `RELEASE_NOTES.md` การแก้ข้ามเข้าไปจะทำให้ scope ของ Beta2 พร่า และ regression ของ ZOKY ไม่ได้อยู่ในการทดสอบรอบนี้ | ZOKY track (ส่งต่อพร้อมรายการนี้) |
| O-2 | **รูปสินค้า ZOKY ใน grid 2 คอลัมน์ไม่มี `cacheWidth`** + `Image.network` ไม่มี errorBuilder 9 จุด | เหตุผลเดียวกับ O-1 — `NetworkThumbnail` พร้อมใช้แล้ว หยิบไปใช้ได้ทันที | ZOKY track |
| O-3 | **Denormalized counter (`drops.like_count` + trigger) แทน correlated subquery ใน `home_feed`** | นี่คือทางแก้รากของ `home_feed` (8 subquery ต่อแถว) แต่เปลี่ยนรูปร่าง schema + ต้อง backfill ข้อมูล production → **ต้องขออนุมัติ Founder** และต้องมีแผน migration แยก | Beta3 (เสนอเป็น task แยก) |
| O-4 | **Cursor-based pagination ทั้งแอป** | offset pagination ยังซ้ำ/ข้ามได้เมื่อมีข้อมูลใหม่แทรก (บรรเทาด้วย dedupe ใน B2-07 แล้ว) การย้ายไป cursor กระทบทุก repository + ทุกหน้าจอ = rewrite | Beta3 |
| O-5 | **State management (Riverpod/Bloc) เพื่อ sync state ข้ามหน้าจอ** | Major architecture change ตาม `RULES.md` ต้องอนุมัติ และไม่ควรทำตอนกำลังจะปิด Beta2 | Beta3+ |
| O-6 | **Image CDN transform (resize ฝั่ง server)** | เป็นทางแก้ที่ถูกต้องกว่า `cacheWidth` (ประหยัด bandwidth ด้วย ไม่ใช่แค่ memory) แต่ต้องเปิดฟีเจอร์ที่มีค่าใช้จ่ายฝั่ง Supabase → Founder ตัดสิน | Beta3 / เรื่องงบประมาณ |
| O-7 | **Offline mode / local cache** | ฟีเจอร์ใหม่ ไม่ใช่การทำของเดิมให้สมบูรณ์ | นอก roadmap ปัจจุบัน |
| O-8 | **Rate limiting ฝั่ง server สำหรับ like/comment/follow** | ต้องออกแบบ policy ร่วมกับ Founder ก่อน (`record_drop_view` มี velocity cap แล้ว ที่เหลือยังไม่มี) | Beta3 |
| O-9 | **Pop กลับมา** | Founder สั่งพักไว้ (WYN-102) | รอคำสั่ง Founder |
| O-10 | **เนื้อหาเอกสารกฎหมายจริง** | ต้องใช้ทนายความ — มี APPROVAL_REQUIRED ค้างอยู่แล้วตั้งแต่ 2026-08-23 | ก่อนโปรโมทวงกว้าง |

⸻

## 6. สิ่งที่ยังไม่ได้ทดสอบ และเป็นข้อจำกัดของรายงานนี้

พูดตรง ๆ เพื่อไม่ให้เข้าใจผิดว่าครอบคลุมกว่าความจริง:

1. **ไม่ได้รัน `supabase/tests/*.sh` (30+ ไฟล์)** — ต้องมี PostgreSQL 16 ที่สร้าง database ได้ และยังไม่ได้ต่อเข้า CI (ตาม `CONTRIBUTING.md`) นี่คือ automated coverage เดียวที่ RLS policy กับ view definition มี — **การแก้ index และ policy ในรายงานนี้จึงยังไม่ผ่านชุดทดสอบนั้น**
2. **ไม่ได้ทดสอบบนอุปกรณ์จริง** — ตัวเลข memory ของรูป (10.2 MB/รูป) มาจากการคำนวณ `width × height × 4 bytes` ไม่ใช่จากการวัด DevTools
3. **ไม่มีตัวเลข performance ก่อน/หลัง** — ไม่มี production database ให้ `EXPLAIN ANALYZE`
4. **QA เชิงพฤติกรรมยังไม่ได้ทำ** — CI แทน AI QA & Security ไม่ได้ ตาม `.wyn/company/WORKFLOW.md` ต้องผ่าน QA ก่อน deploy

⸻

## 7. สิ่งที่ต้องการจาก Founder (เรียงตามลำดับ)

1. **อนุมัติ / ไม่อนุมัติ** `supabase/pending_approval_rls_with_check.sql` (P0 security — §2)
2. **สั่ง apply** `supabase/migrations_beta2_indexes.sql` (P1 performance — §3) หรือบอกให้รอ
3. **ตัดสินใจเรื่อง REMAINING BETA2 (§4)** — จะให้ทำ R-1 ถึง R-5 ต่อในรอบนี้ หรือปิด Beta2 เท่านี้แล้วยกไป Beta3
4. **ยืนยันว่าจะให้เปิด PR เมื่อไร** — ตอนนี้หยุดรออยู่ ยังไม่เปิด PR ตามคำสั่ง

> **สถานะการหยุด:** ไม่มีการ apply security/database change ใด ๆ กับ production ไม่มีการเปิด PR ไม่มีการ merge — รอคำสั่ง Founder
