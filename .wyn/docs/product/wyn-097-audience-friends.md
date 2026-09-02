# Product Full Spec — WYN-097

Status: full spec complete (2026-09-02) — ready for AI Design
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` ข้อ 2/28, `.wyn/tasks/backlog/WYN-097.md`, `.wyn/company/DECISIONS.md` (2026-09-02, คำตอบข้อ 1/4)

Feature: ตัวเลือกกลุ่มผู้ชมโพสต์ (Audience selector) + ระบบ "เพื่อน" (mutual follow) + "เพื่อนที่สนิท" (Close Friends)

Goal: ให้ผู้ใช้เลือกได้ตอนโพสต์ว่าใครเห็นโพสต์นั้นได้บ้าง จาก 5 ตัวเลือก: ทุกคน / เพื่อน / ซ่อนเพื่อนบางคน / เพื่อนที่สนิท / เฉพาะฉัน — และให้ระบบ enforce สิทธิ์นี้จริงทุกจุดที่อ่านโพสต์ ไม่ใช่แค่กรองที่ UI

Target User: ผู้ใช้ WYN Social ทุกคนที่โพสต์ (Drop) — ไม่รวม Pop (กำลังถูกซ่อนทั้งฟีเจอร์ตาม WYN-102) และไม่รวม Club post (มีระบบ visibility ของตัวเองอยู่แล้วจาก WYN-014 คนละแนวคิดกัน)

## Problem

Founder ระบุใน PDF ข้อ 2 (ปุ่มสีแดงที่วง "ทุกคน" ในหน้าโพสต์) ว่าต้องมีตัวเลือกผู้ชม 5 แบบ ระบบตอนนี้ **ไม่มีแนวคิด "เพื่อน" เลย** มีแค่ follow ทางเดียว (`public.follows`) — ตรวจโค้ดจริงยืนยัน `app/lib/features/drop/presentation/create_drop_screen.dart` มี audience chip "ทุกคน ⌄" อยู่แล้วแต่เป็น **static, ไม่ทำงานจริง** (ดู doc comment บรรทัด 48-51 ของไฟล์นั้น: "The reference's audience chip has no real per-post audience feature either -- kept as a static, non-interactive"), และ `drops` table ไม่มีคอลัมน์ audience/visibility ใดๆ เลย — select policy ปัจจุบันคือ `internal.can_view_author_content(auth.uid(), author_id)` (ดู schema.sql บรรทัด 7445-7458, 7627) ซึ่งเช็คแค่ private-account + follow เท่านั้น ไม่มีแนวคิด per-post audience

## นิยาม "เพื่อน" (ตามที่ Founder อนุมัติให้ AI ตัดสินใจ 2026-09-02)

- **เพื่อน = mutual follow** (follow กันทั้งสองทาง) ไม่มีระบบส่งคำขอเป็นเพื่อนแยกต่างหาก — ใช้ตาราง `public.follows` ที่มีอยู่แล้วตรวจสองทิศทาง ไม่สร้างตารางใหม่
- **หมายเหตุสำคัญที่ต้องแจ้ง Founder**: นี่เป็นข้อเสนอของ AI ที่ Founder บอกให้ "ตัดสินใจแทน" ไม่ใช่คำยืนยันแบบตรงๆ อีกครั้ง — สเปกนี้เดินหน้าตามแนวทางนี้ทั้งหมด แต่ควรมี popup ยืนยันสั้นๆ ก่อนเข้า Design/Coding เพื่อความชัวร์ (ดู Handoff)

## Data Model Impact (ตรวจ `supabase/schema.sql` จริงแล้ว)

**ตารางที่มีอยู่แล้วและจะใช้ต่อ (ไม่แก้โครงสร้าง):**
- `public.follows(follower_id, following_id)` — ใช้ตรวจ mutual follow โดยไม่แก้อะไร
- `public.profiles.is_private` + `internal.can_view_author_content()` (WYN-039) — เป็นชั้น gate แรกที่ต้องผ่านก่อนเสมอ (บัญชีล็อกส่วนตัว), audience เป็นชั้น gate ที่สองซ้อนทับ ไม่ใช่แทนที่กัน

**คอลัมน์ใหม่:**
- `alter table public.drops add column if not exists audience text not null default 'everyone' check (audience in ('everyone', 'friends', 'friends_except', 'close_friends', 'only_me'));`
  - Default `'everyone'` — โพสต์เก่าทุกโพสต์ก่อน migration นี้ยังเห็นได้เหมือนเดิมทุกคน (backward compatible, ไม่กระทบข้อมูลเดิม)
  - 5 ค่าตรงกับ 5 ตัวเลือกของ Founder เป๊ะ (`friends_except` = "ซ่อนเพื่อนบางคน")

**ตารางใหม่ 2 ตาราง:**
```sql
create table if not exists public.close_friends (
  owner_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, friend_id),
  constraint close_friends_no_self check (owner_id <> friend_id)
);

create table if not exists public.drop_audience_exclusions (
  drop_id uuid not null references public.drops (id) on delete cascade,
  excluded_user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (drop_id, excluded_user_id)
);
```
- `close_friends`: รายชื่อที่ผู้ใช้เลือกเอง เก็บถาวรข้ามโพสต์ (เหมือน IG Close Friends — ตั้งครั้งเดียว ใช้ได้กับทุกโพสต์ที่เลือก audience นี้)
- `drop_audience_exclusions`: เก็บเฉพาะตอน audience = `friends_except` เป็นรายโพสต์ (คนละชุดกับ close_friends)
- **ไม่ลบ entry ทิ้งอัตโนมัติเมื่อเลิก mutual follow** — เพราะ enforcement เช็คสถานะ mutual follow **สดทุกครั้งที่อ่าน** ไม่ใช่ snapshot ตอนเพิ่มเข้าลิสต์ (ดู Edge Cases) รายการที่ค้างแบบไม่ mutual แล้วจะไม่มีผลอะไรจนกว่าจะกลับมา mutual follow กันใหม่ — ไม่จำเป็นต้อง cleanup job

## RLS / Security Definer Functions ใหม่

```sql
-- Security definer เพื่อเรียกจากใน RLS policy ของ follows/drops เองได้
-- โดยไม่ recurse เข้า RLS ของ follows ซ้ำ (pattern เดียวกับ
-- internal.can_view_author_content, WYN-039)
create or replace function internal.is_mutual_follow(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.follows where follower_id = a and following_id = b)
     and exists (select 1 from public.follows where follower_id = b and following_id = a);
$$;

create or replace function internal.can_view_drop_audience(p_viewer uuid, p_drop public.drops)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    p_drop.author_id = p_viewer
    or p_drop.audience = 'everyone'
    or (p_drop.audience = 'friends' and internal.is_mutual_follow(p_viewer, p_drop.author_id))
    or (p_drop.audience = 'friends_except'
        and internal.is_mutual_follow(p_viewer, p_drop.author_id)
        and not exists (
          select 1 from public.drop_audience_exclusions
          where drop_id = p_drop.id and excluded_user_id = p_viewer
        ))
    or (p_drop.audience = 'close_friends'
        and exists (
          select 1 from public.close_friends
          where owner_id = p_drop.author_id and friend_id = p_viewer
        ))
    -- 'only_me': ไม่มี branch อื่นให้ผ่าน = false เสมอ ยกเว้นเจ้าของ (เช็คไว้บรรทัดแรก)
$$;
```

**แก้ SELECT policy ของ `drops`** (ปัจจุบันเรียก `can_view_author_content` เพียงอย่างเดียว ที่ schema.sql บรรทัด ~7627): เปลี่ยนเป็นเช็คทั้งสองชั้น — `internal.can_view_author_content(auth.uid(), author_id) and internal.can_view_drop_audience(auth.uid(), drops.*)` — **ทั้งสองเงื่อนไขต้องผ่านพร้อมกัน** (private-account gate เดิม ไม่ถูกแทนที่ ถูกซ้อนทับ)

**ทำไมแก้ที่ RLS ของ `drops` table โดยตรง ไม่ใช่กรองในแต่ละ view/query**: `home_feed` view เป็น `security_invoker = true` (ยืนยันจาก schema.sql) แปลว่ามันสืบทอด RLS ของ `drops` โดยอัตโนมัติ — แก้จุดเดียวที่ RLS ของ `drops` ครอบคลุมทุก entry point ทันที (Home feed, Profile grid, Drop detail โดยตรง, Search, Redrop ที่ join กลับไปยัง drop เดิม) ตรงกับ Risk R1 ที่ backlog เดิมระบุไว้แล้วว่าต้อง enforce ทุกจุดที่ backend ไม่ใช่แค่ UI — วิธีนี้ทำได้ในจุดเดียวจริง ไม่ต้องไล่แก้ทีละ view/repository method

**`close_friends` RLS**: insert ต้อง `auth.uid() = owner_id and internal.is_mutual_follow(owner_id, friend_id)` (เลือกได้เฉพาะคนที่ mutual follow กันจริงเท่านั้น), select/delete จำกัดแค่ `auth.uid() = owner_id` (รายชื่อ close friends เป็นความลับของเจ้าของคนเดียว ไม่มีใครอื่นเห็นได้แม้แต่ตัวคนที่ถูกเลือกก็ไม่รู้ว่าตัวเองอยู่ในลิสต์ — เหมือน IG Close Friends จริง)

**`drop_audience_exclusions` RLS**: insert/select/delete จำกัดที่เจ้าของโพสต์เท่านั้น (`auth.uid() = (select author_id from drops where id = drop_id)`)

## Requirements (UI/UX)

**1. Audience selector ตอนโพสต์ (`CreateDropScreen`)** — แทนที่ static chip "ทุกคน ⌄" ด้วยตัวเลือกจริง เปิด bottom sheet เมื่อกด:
- หัวข้อ: "ใครเห็นโพสต์นี้ได้บ้าง"
- 5 แถว พร้อมคำอธิบายใต้แต่ละตัวเลือก (icon + label + subtitle):
  - "ทุกคน" — "ทุกคนเห็นโพสต์นี้ได้"
  - "เพื่อน" — "เฉพาะเพื่อนของคุณเท่านั้นที่เห็นได้"
  - "ซ่อนเพื่อนบางคน" — "เพื่อนทุกคนเห็นได้ ยกเว้นคนที่คุณเลือกซ่อน"
  - "เพื่อนที่สนิท" — "เฉพาะเพื่อนที่สนิทที่คุณเลือกไว้เท่านั้น"
  - "เฉพาะฉัน" — "เห็นเฉพาะคุณคนเดียว"
- เลือก "ซ่อนเพื่อนบางคน" → เปิดหน้าเลือกเพื่อน (multi-select จากลิสต์ mutual-follow) หัวข้อ "เลือกเพื่อนที่จะซ่อนโพสต์นี้" ปุ่มยืนยัน "เสร็จสิ้น (N คน)"
- เลือก "เพื่อนที่สนิท" ครั้งแรก (ยังไม่เคยตั้งลิสต์เลย) → พาไปหน้าจัดการเพื่อนที่สนิทก่อน พร้อมข้อความ "คุณยังไม่มีเพื่อนที่สนิท เลือกจากรายชื่อเพื่อนของคุณได้เลย"
- Chip บนหน้าโพสต์อัปเดต label ตามที่เลือก (เช่น "เพื่อน ⌄", "เฉพาะฉัน ⌄")

**2. หน้าจัดการ "เพื่อนที่สนิท"** (เข้าถึงได้ 2 ทาง: จาก audience selector และจาก Settings > ความเป็นส่วนตัว แถวใหม่ "เพื่อนที่สนิท")
- List เพื่อน (mutual-follow ทั้งหมด) พร้อม toggle/checkbox เพิ่ม-ลบออกจากลิสต์ทีละคน ค้นหาได้ (reuse UI pattern จาก `follow_list_screen.dart`)
- Empty state (ยังไม่มีเพื่อนเลย ไม่ใช่แค่ยังไม่เลือก): "คุณยังไม่มีเพื่อน (mutual follow) ให้เลือก"

**3. Enforcement**: RLS ตามที่ระบุข้างบน ครอบคลุมทุก entry point อัตโนมัติเพราะแก้ที่ `drops` table โดยตรง

## Edge Cases

1. **เลิก mutual follow หลังโพสต์แบบ "เพื่อน"/"เพื่อนที่สนิท" ไปแล้ว**: การมองเห็นเช็คสดทุกครั้งที่อ่าน (ไม่ใช่ snapshot ตอนโพสต์) — เลิกติดตามกันปุ๊บ มองไม่เห็นโพสต์เก่าที่เคยเห็นได้ทันที นี่คือพฤติกรรมที่ตั้งใจ (สอดคล้องกับนิยาม "เพื่อน" ที่อิงสถานะปัจจุบัน ไม่ใช่ประวัติ)
2. **Redrop ของโพสต์ที่ไม่ใช่ "ทุกคน"**: เนื่องจาก `redrops.drop_id` join กลับไปที่ `drops` เดิมเสมอ และ RLS อยู่ที่ `drops` โดยตรง คนที่ไม่มีสิทธิ์เห็นโพสต์ต้นฉบับจะไม่เห็น redrop ของมันเลยแม้จะ follow คนที่ redrop อยู่ก็ตาม (ถูกต้องตามหลัก privacy) — **แต่ต้องตัดสินใจเพิ่ม: ควรให้กด "รีโพสต์" ปุ่มนี้ได้เลยไหมถ้าโพสต์ต้นฉบับไม่ใช่ "ทุกคน"?** สเปกนี้กำหนดให้ **ซ่อนปุ่มรีโพสต์ทั้งหมดเมื่อ audience ≠ 'everyone'** เป็นค่าเริ่มต้นที่ปลอดภัยที่สุด (ป้องกันความสับสน "รีโพสต์ได้แต่คนอื่นเห็นแค่บางคน") — ถือเป็นการเพิ่ม requirement ใหม่นอกเหนือจาก backlog เดิม ต้องแจ้ง Founder
3. **@mention คนที่ไม่ใช่เพื่อน ในโพสต์แบบ "เพื่อน"**: ปล่อยให้ mention ได้ตามปกติ (ไม่ block ตอนพิมพ์ — ซับซ้อนเกินจำเป็นสำหรับรอบนี้) แต่คนที่ถูก mention แล้วไม่มีสิทธิ์ดู จะเปิดโพสต์จาก notification ไม่ได้ (โดน RLS บล็อกเหมือนกรณีอื่น) — ใช้ empty/error state ทั่วไปที่มีอยู่แล้วในแอป ("ไม่พบโพสต์นี้") ไม่ต้องสร้างใหม่
4. **Draft ที่บันทึกไว้ก่อนมีฟีเจอร์นี้**: default เป็น 'everyone' อัตโนมัติเมื่อโพสต์จริง (เหมือนโพสต์เก่า)
5. **Club post / Pop**: ไม่ได้รับผลกระทบ อยู่นอกสโคปตามที่ระบุด้านล่าง

## Acceptance Criteria

- [ ] เลือก "ทุกคน" → ทุกคนเห็นเหมือนเดิมทุกประการ (ค่า default, ไม่มี regression)
- [ ] เลือก "เพื่อน" → เฉพาะ mutual-follow เห็น รวมถึงผ่าน Home feed/Profile grid/Drop detail โดยตรง/Search ทุกจุด
- [ ] เลือก "ซ่อนเพื่อนบางคน" + เลือกคน X → เพื่อนทุกคนเห็นได้ยกเว้น X
- [ ] เลือก "เพื่อนที่สนิท" → เฉพาะคนในลิสต์ close_friends เห็น (ไม่ต้อง mutual follow ก็เห็นไม่ได้ถ้าไม่ได้อยู่ในลิสต์ — แต่ในทางปฏิบัติจะเพิ่มเข้าลิสต์ได้เฉพาะ mutual follow อยู่แล้ว)
- [ ] เลือก "เฉพาะฉัน" → มีแค่เจ้าของเห็น แม้แต่ผ่าน API ตรงก็เห็นไม่ได้
- [ ] หน้าจัดการเพื่อนที่สนิท เพิ่ม/ลบรายชื่อได้จริง เฉพาะจาก mutual-follow list
- [ ] เลิก mutual follow → มองไม่เห็นโพสต์แบบ "เพื่อน"/"เพื่อนที่สนิท" ของคนนั้นทันที
- [ ] ทดสอบเรียก Supabase REST/RPC ตรงๆ (ไม่ผ่าน UI) ด้วย user ที่ไม่มีสิทธิ์ ต้องไม่เห็นแถวที่ถูกจำกัดเลย

## Dependencies
- ทำคู่กับ/ก่อน WYN-099 (ใช้ `internal.is_mutual_follow` ร่วมกัน — ดู `.wyn/docs/product/wyn-099-likes-privacy.md`)
- WYN-039 (Private Account, มีอยู่แล้ว) — เป็นชั้น gate แรกที่ audience ต้องซ้อนทับ ไม่ใช่แทนที่

## Out of Scope (รอบนี้)
- ระบบคำขอเป็นเพื่อนแยกจาก follow (ตามที่ Founder ให้ AI ตัดสินใจ)
- Audience selector บน Pop (Pop กำลังถูกซ่อนทั้งฟีเจอร์ตาม WYN-102) และ Club post (มีระบบ visibility ของตัวเองแล้ว)
- แก้ audience ของโพสต์ที่โพสต์ไปแล้ว (เปลี่ยนทีหลัง) — รอบนี้เลือกได้แค่ตอนสร้างโพสต์เท่านั้น เหมือน caption ที่แก้ไม่ได้หลังโพสต์ในระบบปัจจุบัน
- Block mention คนที่ไม่มีสิทธิ์ดูตอนพิมพ์ (ดู Edge Case 3)
- แจ้งเตือน "X เพิ่มคุณเป็นเพื่อนที่สนิท" (IG มีฟีเจอร์นี้ แต่ Founder ไม่ได้ระบุ ไม่เพิ่มเอง)

## Risks

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เพิ่ม visibility rule ผิดจุดจนโพสต์รั่วไหล | สูง | RLS ที่ระดับ `drops` table โดยตรง (single source of truth ผ่าน security_invoker view) ไม่กรองแค่ query/UI — ดู Data Model section |
| R2 | นิยาม "เพื่อน"=mutual follow ยังไม่ผ่าน Founder ยืนยันตรงๆ รอบสุดท้าย | กลาง | ถาม popup สั้นๆ ก่อนเข้า Coding จริง (ดู Handoff) |
| R3 | Migration เพิ่มคอลัมน์/ตารางใหม่ต้องเช็ค production schema จริงก่อน apply (schema.sql มีปัญหา load ไม่ผ่านจากปัญหา home_feed view สะสม 7 จุดที่รู้แล้ว, ดู DECISIONS.md 2026-09-02) | กลาง | apply ผ่าน Supabase Dashboard SQL Editor ตรง เช็ค column/policy จริงก่อนเหมือนวิธีที่ใช้แก้ WYN-071/072 ไม่พึ่ง schema.sql load สดทั้งไฟล์ |
| R4 | ซ่อนปุ่มรีโพสต์เมื่อ audience≠everyone เป็น requirement ใหม่ที่ AI เพิ่มเอง ไม่ได้มาจาก Founder ตรงๆ | ต่ำ-กลาง | ระบุชัดใน Edge Case 2 ว่าเป็นข้อเสนอ ให้ AI Design ยืนยัน UX อีกครั้ง |

## Recommendation
เดินหน้า spec นี้เป็นฐานสำหรับ Design/Coding — โครงสร้างข้อมูลใหม่ที่เสนอ (audience column + close_friends + drop_audience_exclusions + 2 security-definer functions) กระทบเฉพาะ `drops` table และของใหม่ล้วนๆ ไม่แตะ RLS ของตารางอื่นที่ผ่าน QA แล้ว (นอกจาก select policy เดิมของ `drops` เอง) ความเสี่ยงหลักคือความถูกต้องของ RLS ไม่ใช่ scope

## Handoff
ส่งต่อ **AI Design** (`/design`) — งานนี้ใหญ่พอที่ต้องผ่าน Design ก่อน Coding จริง (ไม่ใช่ straight-to-coding): ต้องออกแบบ bottom sheet 5 ตัวเลือก, หน้าเลือกเพื่อนที่จะซ่อน, หน้าจัดการเพื่อนที่สนิท, และตำแหน่งแถวใหม่ใน Settings > ความเป็นส่วนตัว

**ก่อนเริ่ม Design/Coding จริง ควรมี popup ถาม Founder ยืนยันสั้นๆ 1 ข้อ** (ไม่ใช่คำถามใหม่ แค่ปิดจ๊อบที่ค้างจาก 2026-09-02): "ยืนยันนิยาม 'เพื่อน' = mutual follow ตามที่ AI เสนอไหม (ใช่ตามที่เสนอ / อยากให้มีระบบคำขอเป็นเพื่อนแยกจาก follow)" — ถ้าไม่ตอบภายในเวลาที่เหมาะสม ให้เดินหน้าตาม spec นี้ต่อได้เลยตามที่ Founder บอกไว้แล้วว่าให้ AI ตัดสินใจแทน
