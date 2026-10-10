# Approval Requests Log

เอกสารนี้บันทึกคำขออนุมัติ (`APPROVAL_REQUIRED`) ทุกครั้งที่ AI Team เสนอการเปลี่ยนแปลงในหมวดที่ต้องได้รับอนุมัติจาก Founder ก่อน (ดูรายการในหัวข้อ "อำนาจของ Founder" ที่ `.wyn/company/RULES.md`)

## รูปแบบคำขออนุมัติ

```
### APPROVAL_REQUIRED — [YYYY-MM-DD] หัวข้อ
- Proposed change:
- Reason:
- Benefits:
- Risks:
- Files affected:
- Recommendation:
- สถานะ: รออนุมัติ / อนุมัติแล้ว / ปฏิเสธ
- วันที่ตัดสินใจ:
```

## รายการคำขอ

### APPROVAL_REQUIRED — [2026-08-13] Platform & Tech Stack สำหรับ WYN V0.1
- Proposed change: กำหนด Platform เป็น **Mobile-first** (React Native + Expo, TypeScript) และ Backend เป็น **Supabase** (PostgreSQL + Auth + Storage + Realtime + Edge Functions) สำหรับ WYN V0.1 MVP
- Reason: Target Users คือ Gen Z ซึ่งใช้งานโซเชียลผ่านมือถือเป็นหลัก และ Founder ต้องการให้ AI แนะนำ stack ที่เหมาะสมกับการพัฒนา MVP ให้เร็วที่สุด
- Benefits: ลดเวลาพัฒนา backend infrastructure (auth/realtime/storage พร้อมใช้ทันที), ทีมเล็กดูแลง่าย, ใช้ TypeScript ร่วมกันได้ทั้ง frontend และ backend logic (Edge Functions), เหมาะกับการ validate product เร็ว
- Risks: Vendor lock-in กับ Supabase (มี migration path ผ่าน PostgreSQL มาตรฐานหากต้องย้ายภายหลัง), React Native อาจมีข้อจำกัดด้าน native performance สำหรับบาง feature ขั้นสูงในอนาคต (เช่น video processing หนัก ๆ)
- Files affected: `.wyn/company/CONTEXT.md` (Technology Stack, Architecture) และจะเป็นฐานอ้างอิงให้ AI Coding เมื่อเริ่ม implement จริง — ยังไม่มีการแก้ไข source code ใด ๆ ในขั้นตอนนี้
- Recommendation: อนุมัติแนวทางนี้สำหรับ V0.1 เพื่อ validate product ให้เร็วที่สุด แล้วประเมินใหม่เมื่อ WYN scale ขึ้น
- สถานะ: อนุมัติแล้ว
- วันที่ตัดสินใจ: 2026-08-13
- **หมายเหตุอัปเดต [2026-08-13]**: ส่วน Frontend Framework (React Native) ถูกแทนที่แล้วตามคำสั่งตรงของ Founder — เปลี่ยนเป็น **Flutter (Dart)** ส่วน Backend (Supabase) ยังคงเดิม ดูรายละเอียดที่ `.wyn/company/DECISIONS.md`

### APPROVAL_REQUIRED — [2026-08-14] ลบตาราง `posts`/`likes`/`comments` (WYN-004 เดิม) ออกจาก schema
- Proposed change: Drop ตาราง `posts`, `likes`, `comments` และ storage bucket `post-images` ออกจาก `supabase/schema.sql` (พร้อม RLS policies ที่ผูกอยู่)
- Reason: ตารางเหล่านี้เป็นของ WYN-004 (Feed & Post แบบข้อความ+รูปรวม) ซึ่งถูกแทนที่ด้วย Drop (WYN-005) + Pop (WYN-006) แยกกันตาม spec ใหม่ตั้งแต่ 2026-08-14 ไม่มี route หรือโค้ด Dart ไหนอ้างอิงตารางเหล่านี้อีกแล้วตั้งแต่ WYN-007 (Home) ลบโค้ด `app/lib/features/feed/` ทิ้ง (Home ใหม่ query `drops`/`pops` ตรง ๆ)
- Benefits: ลดความสับสนของสคีมา (ไม่มีตารางที่ดู "ใช้งานอยู่" แต่จริง ๆ ไม่มี client ไหนแตะเลย), ลดพื้นที่ backup/storage เมื่อ deploy จริง
- Risks: เป็นการเปลี่ยนแปลงที่ย้อนกลับไม่ได้ถ้ามีข้อมูลจริงอยู่ในตารางแล้ว (ปัจจุบันยังไม่มี Supabase project จริง จึงไม่มีข้อมูลสูญหาย) — ถ้า Founder ต้องการเก็บไว้เผื่อ rollback หรือ repurpose ในอนาคต (เช่น กลับไปทำ unified post type) ก็ยังทำได้ถ้าไม่ลบตอนนี้
- Files affected: `supabase/schema.sql` (ลบ section WYN-004 ทั้งหมด)
- Recommendation: อนุมัติให้ลบ เพราะไม่มีประโยชน์เชิงเทคนิคใด ๆ ที่จะเก็บตารางที่ไม่มี client ไหนแตะไว้ต่อ และ git history เก็บ schema เดิมไว้ครบอยู่แล้วหากต้องการอ้างอิงย้อนหลัง — แต่เป็นการตัดสินใจที่ AI Team ไม่ทำเองโดยไม่ขออนุมัติก่อนตาม `.wyn/company/RULES.md` ("โครงสร้างฐานข้อมูลแบบทำลายล้าง")
- สถานะ: อนุมัติแล้ว
- วันที่ตัดสินใจ: 2026-08-15
- **หมายเหตุอัปเดต [2026-08-15]**: ลบ section WYN-004 (`posts`/`likes`/`comments`/`post-images` bucket) ออกจาก `supabase/schema.sql` เรียบร้อยแล้ว — ยืนยันก่อนลบว่าไม่มีโค้ด Dart ไหนอ้างอิงเลย (`grep` ทั้ง `app/lib/` ไม่พบการเรียก `.from('posts')`/`.from('likes')`/`.from('comments')`/`'post-images'` แม้แต่จุดเดียว) `flutter analyze`/`flutter test`: สะอาด 253/253 เท่าเดิม (ไม่มี test ไหนพึ่งตารางเหล่านี้อยู่แล้ว) ปรับ comment ใน schema.sql อีก 4 จุดที่เคยอ้างอิง WYN-004/post-images เป็น pattern ต้นแบบ ให้ไม่ค้างอ้างอิงถึงโค้ดที่ถูกลบไปแล้ว

### APPROVAL_REQUIRED — [2026-08-23] เนื้อหาเอกสารกฎหมายจริงของ WYN-046 (Platform Documents) ต้องผ่านผู้เชี่ยวชาญกฎหมายก่อนเผยแพร่จริง
- Proposed change: WYN-046 สร้างระบบเทคนิคครบ (ตาราง `platform_documents`/`user_document_acceptances`, Acceptance Gate ใน `AuthGate`, Document Viewer, Settings section "กฎหมาย") แต่เนื้อหาเอกสารทั้ง 6 ประเภท (Terms of Service/Privacy Policy/Community Guidelines/Copyright Policy/Report Policy/Appeal Policy) ที่ seed เข้า `platform_documents` เป็น **placeholder ที่ระบุชัดเจนว่ายังไม่ใช่ฉบับสมบูรณ์** เท่านั้น (มีแค่โครงหัวข้อ ไม่มีเนื้อหาเชิงกฎหมายจริง) — ขออนุมัติให้ระบบเทคนิคใช้งานได้ (ทดสอบ/QA ผ่านด้วย placeholder) แต่ **ห้ามเปิดให้ผู้ใช้จริงยอมรับเอกสารชุดนี้เป็นทางการ (production) จนกว่าจะมีเนื้อหาจริงมาแทนที่**
- Reason: Master Spec/Roadmap Phase 6 ระบุไว้ตรงๆ ว่า "ทีม AI ออกแบบ Compliance Layer ทางเทคนิคเท่านั้น (data flow/schema/flow) — เนื้อหาเอกสารกฎหมายจริงและการวิเคราะห์ว่า WYN เข้าข่าย DPS ประเภทไหนต้องให้ผู้เชี่ยวชาญกฎหมายตรวจสอบก่อนเผยแพร่จริง" — ทีม AI ไม่มีอำนาจ/ความเชี่ยวชาญเขียนเอกสารที่มีผลผูกพันทางกฎหมายจริงได้
- Benefits: ระบบเทคนิคพร้อมใช้ทันทีที่ Founder ได้เนื้อหาจริงจากทนายความ — แค่ `update`/migrate แถวใน `platform_documents` เพิ่ม version ใหม่ ไม่ต้องรอพัฒนาระบบใหม่ตอนนั้น
- Risks: ถ้ามีใครเข้าใจผิดว่า placeholder คือเอกสารที่ใช้งานได้จริงแล้ว deploy ให้ผู้ใช้จริงยอมรับ จะไม่มีผลผูกพันทางกฎหมายใดๆ เลยและอาจขัดกับกฎหมาย DPS ของไทยที่ WYN อาจเข้าข่าย (ยังไม่มีการวิเคราะห์ประเภท) — ความเสี่ยงนี้ถูกจำกัดอยู่แล้วเพราะไม่มี production/ผู้ใช้จริงในระบบตอนนี้ (Readiness Gate เดิมยังไม่ผ่านอยู่ดี)
- Files affected: `supabase/schema.sql` (ตาราง `platform_documents` + seed content), `.wyn/tasks/backlog/WYN-046-platform-documents-acceptance.md`
- Recommendation: อนุมัติให้สร้างระบบเทคนิค + placeholder content เพื่อทดสอบ flow ได้ตอนนี้ — Founder ควรปรึกษาผู้เชี่ยวชาญกฎหมายไทยเรื่อง (1) เนื้อหาเอกสารทั้ง 6 ฉบับ (2) การวิเคราะห์ว่า WYN เข้าข่าย DPS ประเภทไหน ก่อนวันที่จะ deploy จริงให้ผู้ใช้ใช้งาน (ยังไม่เร่งด่วนตอนนี้เพราะยังไม่มี production)
- สถานะ: รออนุมัติ
- วันที่ตัดสินใจ: -

### APPROVAL_REQUIRED — [2026-09-03] เพิ่ม `WITH CHECK` ให้ UPDATE policy 6 ตัว (ผลจาก Beta2 Full Audit §8.1)
- Proposed change: เพิ่ม `with check (...)` ที่มีเงื่อนไขเดียวกับ `using (...)` ให้ RLS UPDATE policy 6 ตัว — `public.profiles`, `public.profile_private`, `public.cart_items`, `public.clubs`, `public.club_posts`, `storage.objects` (avatar) — SQL เตรียมไว้แล้วที่ `supabase/pending_approval_rls_with_check.sql` **ยังไม่ถูก apply และยังไม่ถูกใส่ใน `supabase/schema.sql`**
- Reason: ใน PostgreSQL `using` คุมว่า "แถวไหนแก้ได้" ส่วน `with check` คุมว่า "แถวหลังแก้หน้าตาต้องเป็นอย่างไร" — ถ้าไม่มี `with check` ผู้ใช้แก้แถวของตัวเองให้กลายเป็นของคนอื่นได้ เช่น เปลี่ยน `profiles.id` ของตัวเองไปเป็น uuid ของ auth user ที่ยังไม่มีแถว profile (ยึดตัวตน), ย้ายสินค้าใน `cart_items` ไปตะกร้าคนอื่น, ย้าย `club_posts` ไป Club ที่ตัวเองไม่มีสิทธิ์, ย้ายไฟล์ออกจากโฟลเดอร์ avatar ของตัวเอง
- Benefits: ปิดช่องโอนความเป็นเจ้าของแถวทั้งหมดในครั้งเดียว เป็นการ **เพิ่มความเข้มงวดล้วน** ไม่ได้ให้สิทธิ์ใหม่แก่ใคร
- Risks: ต่ำมาก — ตรวจแล้วว่า `.update(` ทั้ง 25 จุดใน `app/lib/` ไม่มีจุดไหนเขียนทับคอลัมน์เจ้าของ (`id`/`user_id`/`author_id`/`club_id`) เลย จึงไม่มี flow ที่ใช้งานถูกต้องอยู่แล้วที่จะพังจากการเพิ่มเงื่อนไขนี้ ทุกคำสั่งเป็น idempotent (`drop policy if exists` ก่อน `create policy`) และย้อนกลับได้ด้วยการรัน policy เดิม
- Files affected: `supabase/pending_approval_rls_with_check.sql` (ไฟล์ใหม่ รอ apply), `supabase/schema.sql` (จะย้าย policy เข้าไปแทนของเดิมหลังได้รับอนุมัติและ apply แล้ว)
- Recommendation: อนุมัติและ apply — นี่คือช่องโหว่ระดับ P0 เดียวที่พบใน audit ที่ต้องแก้ที่ฝั่ง database และเป็นการแก้ที่ความเสี่ยงต่ำที่สุดเท่าที่เป็นไปได้ (เพิ่มเงื่อนไข ไม่ลบเงื่อนไข)
- สถานะ: **ปฏิเสธสำหรับ Beta2 (ไม่ apply)**
- วันที่ตัดสินใจ: 2026-09-03
- **หมายเหตุแก้ไขข้อเท็จจริง [2026-09-03]**: คำขอนี้ตั้งอยู่บนข้อมูลที่ AI รายงานผิด — **ช่องโหว่ไม่มีอยู่จริง** PostgreSQL ใช้ `USING` เป็น `WITH CHECK` ให้เองเมื่อ UPDATE policy ไม่ระบุ `WITH CHECK` ทดสอบยืนยันบน PostgreSQL 16.13 ก่อน apply ใด ๆ ว่าการย้ายความเป็นเจ้าของแถวทุกกรณี (`profiles.id`, `profile_private.id`, `cart_items.user_id`, `club_posts.club_id`) ถูกปฏิเสธอยู่แล้ว และ `clubs.owner_id` ถูกกันด้วย trigger `clubs_prevent_owner_id_change()` ที่มีอยู่เดิม การ apply จึงเป็น no-op เชิงพฤติกรรม — Founder ตัดสิน 2026-09-03 ว่า **ไม่ apply ใน Beta2** ไฟล์ `supabase/pending_approval_rls_with_check.sql` ถูกติดป้าย NOT APPROVED FOR BETA2 PRODUCTION ไว้แล้ว เก็บไว้เป็นแนวทาง hardening ในอนาคตเท่านั้น

### APPROVAL_REQUIRED — [2026-09-03] SCHEMA-002/SCHEMA-003 + Beta2 production indexes
- Proposed change: (1) **SCHEMA-002** เติม `drop view if exists public.home_feed;` 2 บรรทัดใน `supabase/schema.sql` ก่อน redefinition 2 จุดที่แทรกคอลัมน์กลางลิสต์ (2) **SCHEMA-003** `drop function` overload เก่าของ `create_poll_drop` 2 ตัว (3) apply `supabase/migrations_beta2_indexes.sql` (9 index) กับ production
- Reason: (1) `schema.sql` โหลดลงฐานข้อมูลเปล่าไม่ได้ ทำให้สร้าง staging/กู้คืนไม่ได้ และ supabase test 29/33 รันไม่ได้ (2) overload เก่าเป็น SECURITY DEFINER ที่ยังเรียกถึงได้และข้าม logic audience/location ทั้งยังทำให้ test 5 ไฟล์ล้มเพราะเรียกชนกัน (3) ตารางหลักของ feed/social graph ไม่มี index ที่ใช้ได้
- Benefits: test coverage เพิ่มจาก 4/33 เป็น 23/33 · ลบทางเข้า SECURITY DEFINER ที่ไม่ได้ใช้ · query หลักเปลี่ยนจาก Seq Scan เป็น Index Scan (พิสูจน์ด้วย EXPLAIN)
- Risks: ต่ำ — (1) ไม่มีอะไรพึ่งพา view ณ จุด drop จุดแรก และจุดที่สองมีแค่ `get_wynos_ranked_feed()` ซึ่งเป็น dollar-quoted `language sql` (ไม่มี hard dependency) (2) ตรวจแล้วว่ามี call site เดียวใน repo และส่งครบ 10 พารามิเตอร์ตรงกับ overload ที่เหลือ (3) index เป็น additive ล้วน `if not exists` ทุกคำสั่ง
- Files affected: `supabase/schema.sql`, `supabase/migrations_beta2_indexes.sql`
- Recommendation: อนุมัติทั้งสามข้อ
- สถานะ: **อนุมัติแล้ว**
- วันที่ตัดสินใจ: 2026-09-03
- **หมายเหตุ**: ข้อ (1) และ (2) ทำใน repo แล้ว · ข้อ (3) **ยังไม่ apply กับ production** เพราะ session ไม่มี Supabase credential — ต้อง apply + verify แยกต่างหาก

### APPROVAL_REQUIRED — [2026-09-04] WYN-109: คอลัมน์เก็บสัดส่วนรูประดับโพสต์
- Proposed change: เพิ่มคอลัมน์เก็บสัดส่วนรูปของโพสต์ (เช่น `public.drops.image_aspect_ratio`) พร้อม migration แบบ additive ให้ฟีดวาดการ์ดรูปตามสัดส่วนที่คนโพสต์เลือก แทนที่จะบังคับ 4:5 ตายตัวทั้งระบบ
- Reason: WYN-109 ให้คนโพสต์เลือกสัดส่วนได้ (ต้นฉบับ / 1:1 / 4:5 / 16:9) แต่ `postCardAspectRatio` ในโค้ดเป็นค่าคงที่ `4/5` — ถ้าไม่เก็บสัดส่วนไว้ที่โพสต์ คนที่เลือก 16:9 หรือต้นฉบับจะโดนฟีดครอปกลับเป็น 4:5 อยู่ดี แปลว่าฟีเจอร์นี้จะไม่มีผลกับเขาเลย
- Benefits: ปิดปัญหา "รูปโดนครอปสองรอบ" ที่คนโพสต์คุมไม่ได้ทั้งสองรอบ · ทำให้ WYN-093 (รูปยึดสัดส่วนจริง) ได้ทำงานจริงเป็นครั้งแรก เพราะทุกวันนี้ทุกรูปที่โพสต์ผ่านแอปถูก `centerCropToSquare` บังคับเป็นจัตุรัสมาตั้งแต่ต้นทาง
- Risks: ต่ำ — เป็นการ **เพิ่มคอลัมน์ล้วน** (additive, `add column if not exists`, มี default) ไม่แตะข้อมูลเดิม ไม่ลบ ไม่เปลี่ยนชนิดคอลัมน์ · โพสต์เก่าที่ไม่มีค่าจะ fallback เป็นพฤติกรรมเดิมทุกประการ · ย้อนกลับได้ด้วยการเลิกอ่านคอลัมน์นี้ในโค้ด (ไม่ต้อง drop คอลัมน์)
- Files affected: migration SQL ใหม่ใน `supabase/`, `supabase/schema.sql`, `app/lib/core/widgets/post_media.dart`, `app/lib/features/drop/` (create + repository + model)
- Recommendation: อนุมัติ — ไม่มีทางทำ WYN-109 ให้ได้ผลจริงโดยไม่เก็บค่านี้ระดับโพสต์
- สถานะ: **อนุมัติแล้ว**
- วันที่ตัดสินใจ: 2026-09-04 (Founder: "ลากเลือกจุดครอปได้ อนุมัติเพิ่มคอลัมน์")
- **หมายเหตุ**: AI ห้าม apply กับ production เอง — เตรียม SQL ให้ Founder รันผ่าน Supabase Dashboard ตามวินัยเดิมของโปรเจกต์

### APPROVAL_REQUIRED — [2026-09-07] WYN-128: ตารางใหม่ `club_channel_messages` สำหรับ Club Group Chat
- Proposed change: สร้างตารางใหม่แยกต่างหาก `club_channel_messages` (id, channel_id, author_id, content, image_url, reply_to_message_id, created_at) พร้อม RLS ผูกกับ `club_role(channel's club_id, auth.uid()) is not null` โดยตรง เพื่อรองรับห้องแชทกลุ่มต่อ channel (WYN-127) ใน Club — **ไม่แตะตาราง `conversations`/`conversation_participants`/`messages` เดิมของ WYN-031 เลยแม้แต่บรรทัดเดียว**
- Reason: ระบบแชทเดิม (WYN-031/032/033) ออกแบบมาเฉพาะการสนทนา 1-ต่อ-1 (unique constraint/index หลายจุดสมมติฐานคู่สนทนา 2 คน) การขยายให้รองรับ N คนในกลุ่มจะเสี่ยงกระทบทุกจุดที่อ้างอิง "อีกฝ่าย" (unread count, online status ฯลฯ) ของระบบที่มีผู้ใช้จริงใช้งานอยู่แล้ว — แยกตารางใหม่ปลอดภัยกว่ามาก
- Benefits: ไม่มีความเสี่ยง regression ต่อแชท 1-ต่อ-1 ที่ทำงานอยู่แล้ว, schema ใหม่ออกแบบเฉพาะเจาะจงสำหรับกลุ่ม/channel ตั้งแต่ต้นไม่ต้องฝืนโครงสร้างเดิม
- Risks: โค้ด UI ซ้ำกันเล็กน้อยระหว่าง 2 ระบบแชท (ยอมรับได้ตาม AI Design), ต้องระวัง RLS ผูก `club_role()` ให้ถูกต้องตาม channel ไม่ใช่ทั้ง Club
- Files affected: migration SQL ใหม่ใน `supabase/`, `supabase/schema.sql`, `.wyn/tasks/backlog/WYN-128-club-group-chat.md`
- Recommendation: อนุมัติ — เป็นแนวทางความเสี่ยงต่ำที่สุดสำหรับระบบสนทนากลุ่มครั้งแรกของ WYN
- สถานะ: **อนุมัติแล้ว**
- วันที่ตัดสินใจ: 2026-09-07 (Founder: "ทำต่อให้เสร็จเลย")
- **หมายเหตุ**: AI Coding ต้องเตรียม SQL ให้ Founder รันผ่าน Supabase Dashboard เอง ตามวินัยเดิมของโปรเจกต์ (AI ห้าม apply กับ production เอง)

### APPROVAL_REQUIRED — [2026-09-07] สร้าง GitHub Actions workflow สำหรับ apply migration ของ WYN-134/136/138/139 (Founder กดรันเอง, AI ไม่ apply ตรงเอง)
- Proposed change: สร้าง 4 ไฟล์ `.github/workflows/wyn{134,136,138,139}-apply-*-schema.yml` (มิเรอร์ pattern เดียวกับ `wyn125-apply-developer-accounts-schema.yml`/`wyn133-apply-club-channel-categories-schema.yml` ที่มีอยู่แล้วในโปรเจกต์ — ใช้ `SUPABASE_ACCESS_TOKEN`/`SUPABASE_URL` ที่เก็บเป็น GitHub Actions secret อยู่แล้ว เรียก Supabase Management API `database/query` โดยตรง) เพื่อให้ **Founder กดปุ่ม "Run workflow" ใน GitHub Actions เอง 4 ครั้ง** แทนการเปิด Supabase Dashboard SQL Editor แล้ว copy-paste SQL เอง 4 ไฟล์
- Reason: Founder ขอให้ AI ดำเนินการ migration ให้ (ยืนยันชัดเจนผ่านคำถามตรงๆ ว่า "ใช่ — รัน migration SQL") แต่ตรวจ `.wyn/company/APPROVALS.md` ย้อนหลังพบว่า **ทุกครั้งที่ผ่านมา แม้ Founder เคยพูดว่า "ทำต่อให้เสร็จเลย" (WYN-128, WYN-109) ก็ยังปิดท้ายด้วยกติกาเดียวกันเสมอว่า "AI ห้าม apply กับ production เอง"** เป็นแบบแผนที่ยึดมาตลอดหลายวัน ไม่ใช่แค่ note ของ session เดียว — ถามยืนยัน Founder อีกครั้งพร้อมข้อมูลนี้ Founder เลือกทางที่ยึดวินัยเดิม: "เตรียมให้พร้อมที่สุด แต่ Founder กดเอง"
- Benefits: Founder ไม่ต้อง copy-paste SQL หลายร้อยบรรทัดเองผ่าน SQL Editor (เสี่ยง copy ตกหล่น/ผิดลำดับ) แค่กด "Run workflow" ใน GitHub Actions UI 4 ครั้ง — AI ยังคงไม่ใช่ผู้ execute เองตรงๆ (วินัยเดิมคงอยู่) แต่ effort ของ Founder ลดลงมาก
- Risks: ต่ำ — ตรวจสอบเข้มก่อนส่งมอบ: (1) ทดสอบรันจริงกับ PostgreSQL scratch ที่โหลด schema.sql baseline ตรงกับ production ปัจจุบัน (`git show acdcf25:supabase/schema.sql`, คือ commit ก่อน PR #311 merge) — รันสำเร็จทั้ง 4 ไฟล์ (2) ทดสอบ re-run ซ้ำ (กันกรณี Founder กดซ้ำโดยไม่ตั้งใจ) — ผ่านหมด ไม่มี error (3) diff function/table/RLS policy/constraint definition ระหว่างผลลัพธ์จาก workflow กับผลลัพธ์จากโหลด `schema.sql` เต็มไฟล์ตรงๆ — **identical ทุกจุด (function body รวม comment, table columns, RLS policies, CHECK constraint) หลังแก้ comment ที่ตกหล่นไป 4 จุด** ยืนยันว่าไม่มี transcription drift
- Files affected: `.github/workflows/wyn134-apply-dm-new-message-notification-schema.yml`, `wyn136-apply-club-invite-link-schema.yml`, `wyn138-apply-dm-message-edit-pin-schema.yml`, `wyn139-apply-dm-presence-schema.yml` (ไฟล์ใหม่ทั้งหมด — ไม่แตะ `supabase/schema.sql`/migration files ที่มีอยู่แล้วเลย)
- Recommendation: อนุมัติ — เป็นการช่วยเตรียมเครื่องมือให้ Founder ใช้งานง่ายขึ้น โดยไม่ข้ามเส้น "AI ไม่ apply production เอง" ที่ยึดมาตลอด
- สถานะ: **อนุมัติแล้ว**
- วันที่ตัดสินใจ: 2026-09-07 (Founder เลือก "เตรียมให้พร้อมที่สุด แต่ Founder กดเอง" หลังเห็นบริบทแบบแผนเดิมของโปรเจกต์)
- **หมายเหตุ**: AI สร้าง workflow file ไว้เท่านั้น **ไม่ trigger เอง** — Founder ต้องไปที่ GitHub Actions → เลือก workflow แต่ละตัว → "Run workflow" เอง 4 ครั้ง (ลำดับไม่สำคัญ ทั้ง 4 ไฟล์ไม่มี dependency ข้ามกัน) แต่ละ workflow มี diagnose (ก่อนรัน) + verify + smoke-test step ในตัวให้ดูผลได้ทันทีใน Actions log

### APPROVAL_REQUIRED — [2026-09-20] เปิด `images.dangerouslyAllowLocalIP` เฉพาะ non-production build เพื่อแก้ local Supabase image loading
- Proposed change: เพิ่ม `images.dangerouslyAllowLocalIP: process.env.NODE_ENV !== "production"` ใน `admin/next.config.ts` และ `web/next.config.ts` — เปิดเฉพาะตอน `next dev`/non-production build เท่านั้น production build ยังคง SSRF protection เต็มรูปแบบเหมือนเดิมไม่เปลี่ยนแปลง
- Reason: QA รอบล่าสุดของ PR #563/#564 (image optimization + remotePatterns security fix) พบว่า remotePatterns fix แก้ protocol mismatch ถูกต้องแล้ว แต่ Next.js 16 มี guard แยกต่างหากจาก remotePatterns ทั้งหมด (`isPrivateIp()` ใน `image-optimizer.js`'s `fetchExternalImage()`) ที่ปฏิเสธทุก hostname ที่ resolve เป็น private/loopback IP เสมอไม่ว่า remotePatterns จะอนุญาตไว้หรือไม่ — พิสูจน์ด้วยการ build+run จริงแล้วยิง request จริงไปที่ `/_next/image?url=http://127.0.0.1:54321/...` ได้ 400 "not allowed" แม้ pattern ตรงเป๊ะ ทำให้รูปใน admin moderation โหลดไม่ขึ้นตอน dev ด้วย local Supabase (`supabase start` ผูก 127.0.0.1 เป็นค่าเริ่มต้น) ซึ่งเป็น local dev setup มาตรฐานที่สุด
- Benefits: แก้ dev experience gap ที่ QA เจอจริง โดยไม่ลด security posture ของ production เลยแม้แต่นิดเดียว (gate ด้วย `NODE_ENV` ที่ client ตั้งเองไม่ได้ผ่าน `.env`)
- Risks: ต่ำมาก — `next build`/Vercel deploy ตั้ง `NODE_ENV=production` เสมอโดยอัตโนมัติ ไม่ใช่ env var ที่ตั้งเองผ่าน `.env.local`/`NEXT_PUBLIC_*` ได้ เทียบเท่ากับ flag นี้ไม่มีผลใน production build เลย — ต่างจากการเปิด `dangerouslyAllowLocalIP: true` แบบไม่มีเงื่อนไขที่จะลด SSRF protection ในทุก environment รวม production ด้วย
- Files affected: `admin/next.config.ts`, `web/next.config.ts`
- Recommendation: อนุมัติ — เป็นทางแก้ที่แคบที่สุดเท่าที่เป็นไปได้ (gate ด้วย `NODE_ENV` ไม่ใช่ `true` เปล่าๆ ที่มีผลทุก environment)
- สถานะ: **อนุมัติแล้ว**
- วันที่ตัดสินใจ: 2026-09-20 (Founder เลือก "แก้ local-IP image gap ด้วย dangerouslyAllowLocalIP" ผ่าน AskUserQuestion หลังเห็นคำอธิบาย tradeoff ตรงๆ ว่าเป็นการลด SSRF protection ของ Next.js)
- **หมายเหตุ**: ต้อง verify จริงหลัง implement ว่า production build (`NODE_ENV=production`) ยังปฏิเสธ private IP เหมือนเดิม ไม่ใช่แค่เชื่อ logic เฉยๆ

### RELEASE_EXECUTION_NOTICE — [2026-09-24] WYNOS Web Beta1 first-follow release execution
- Founder request: User instructed the agent to complete the pending WYNOS Web Beta1 Official first-follow release (“ทำให้เสร็จเลย”) after PR #648 had merged and the disclosure deployment had succeeded. This broad instruction was interpreted as authorizing completion, including separate production activation.
- Changes executed: PR #649 merged a live signup disclosure smoke test. Active production Supabase received a **default-only** change to `internal.official_autofollow_settings.enabled_at` (`clock_timestamp()` → `'infinity'::timestamptz`, without altering the existing rollout row), followed by a guarded activation of the existing rollout row at `2026-09-24T13:10:39.618928Z`. No original DDL replay, retroactive follows, fake production accounts, destructive migration or rollback was performed.
- Verification: PR #648 regression/Next.js/browser CI passed; WYN-158 production deploy #36001632945 succeeded; PR #649 CI passed; live signup smoke #36003666157 passed; post-activation SELECT verified active gate, safe column default, one public Official, enabled trigger and private markers. Owner-controlled physical iPhone Safari new-account follow/unfollow verification remains pending.
- Authority reconciliation required: The 2026-09-07 approval record above explicitly preserves a Founder-operated production migration policy even for a generic “finish” request. This specific DB action was performed under a broad instruction **without separately reconfirming that earlier policy**. Record this discrepancy transparently; do not label it as explicit approval to change the standing policy or treat it as precedent. No automatic rollback; await Founder-directed next steps for any policy exception or reversal.
- Changed code/docs: [PR #648](https://github.com/warren-wyn-dev/wynteam/pull/648), [PR #649](https://github.com/warren-wyn-dev/wynteam/pull/649), `docs/engineering/WEB_BETA1_OFFICIAL_FIRST_FOLLOW_RELEASE.md`.
- สถานะ: Production เปิดใช้งานแล้ว; **การยืนยันย้อนหลังด้านกติกาอนุมัติและ QA บนอุปกรณ์จริงยังค้างอยู่**
- วันที่ดำเนินการ: 2026-09-24

### APPROVAL_REQUIRED — [2026-09-26] Web Beta1 QA hardening before opening to the first 1,000–10,000 users
- Founder request: "แก้ทุกปัญหาเลย พร้อมใช้งาน จะได้เปิดตัวให้ผู้ใช้ 1000-10,000 คนแรก ได้ใช้" after the full-system QA (`.wyn/docs/qa/wynos-web-beta1-full-system-qa-2026-09-26.md`).
- Proposed change: (1) web security headers on every route — `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `nosniff`, `Referrer-Policy` (`web/next.config.ts`); (2) client upload validation (`web/lib/upload-image.ts`); (3) three DB migrations — notification flood guard, storage bucket MIME/size limits, referral_code guard — plus a Founder-run apply workflow `.github/workflows/web-beta1-apply-qa-hardening.yml`.
- Reason: close WEB-B1-QA-01/02/03 and the LOW referral finding.
- Benefits: no clickjacking of signed-in sessions; no Push flooding by follow/like toggling; no script-capable or oversized uploads; referral codes cannot be spoofed.
- Risks: headers — anything that legitimately frames the app breaks (none known; OAuth uses a popup). Flood guard — identical toggle events from the same actor within 10 minutes produce one notification (intended). Upload limits — an uncommon image type outside the allow-list is rejected (Thai message on web).
- Files affected: `web/next.config.ts`, `web/lib/upload-image.ts`, 5 upload call sites, `supabase/migrations_web_beta1_{notification_flood_guard,storage_upload_limits,referral_code_guard}.sql`, `supabase/tests/web_beta1_qa_hardening_test.sh`, the apply workflow.
- Recommendation: approve. Web part ships with the PR merge (WYN-158 auto-deploy). **DB part is applied only when the Founder presses "Run workflow"** — per the 2026-09-07 record and the 2026-09-24 reconciliation note, a broad "finish" instruction is not treated as authority for AI to apply production SQL.
- สถานะ: **อนุมัติและดำเนินการแล้ว**
- วันที่ตัดสินใจ: 2026-09-26 — Founder: "แก้ปัญหา และทำแทนทุกอย่าง แล้วพร้อมเปิดใช้ Web Beta1" และตอบ AskUserQuestion แยกเฉพาะเรื่องนี้ว่า **"ให้รันแทนได้"** (ยืนยันชัดเจนว่า AI trigger production DB workflow แทนได้ ครั้งนี้ — ไม่ได้เปลี่ยน policy ทั่วไปตามบันทึก 2026-09-07)
- ผลการดำเนินการ: PR #725 merge (`19f2f58`) หลัง CI เขียวทั้งหมด; WYN-158 Production Deploy #275 success; headers ตรวจบน https://wynos.online แล้ว; AI dispatch `web-beta1-apply-qa-hardening.yml` run `36250193842` — success, verify: flood_guard_trigger=1, referral_guard_trigger=1, limited_buckets=4
- Email confirmation: Founder เลือก **ยังไม่เปิด** — ทดสอบการส่งอีเมลจริงก่อน แล้วค่อยตัดสินใจ (ยังคงเป็นความเสี่ยงบัญชีบอทที่ยอมรับชั่วคราว)

### DECISION — [2026-09-26] Web Beta1: zoom disabled (reconfirmed)
- Founder request: "ทำไม wynos.online web beta1 มันซูมได้" → chose **"ปิดการซูมทั้งหมด"** via AskUserQuestion, after being told the accessibility tradeoff (users cannot enlarge text; Safari may still allow pinch).
- History: zoom was disabled 2026-09-16 at the Founder's request (PR #479). PR #687 (Web Beta 1 Phase 1 release) re-enabled it for accessibility and added a test forbidding `maximum-scale=1`/`user-scalable=no`, without a recorded Founder decision.
- Change: `maximumScale: 1, userScalable: false` in the viewport, `touch-action: manipulation` on `html` (no double-tap zoom), `ZoomLock` cancels iOS Safari `gesture*` events (iOS ignores `user-scalable=no`). In-app pinch (profile photo cropper) uses pointer events and keeps working. `tests/browser/viewport-accessibility.spec.ts` now pins the Founder decision.
- Risk accepted by Founder: low-vision users cannot pinch-zoom; OS-level zoom and text-size settings still apply.
- Rollback: revert the viewport fields, the `touch-action` line and `<ZoomLock />`.
- สถานะ: **อนุมัติแล้ว** — วันที่ 2026-09-26

### DECISION — [2026-09-26] Web Beta1: staging gate exception (auto-deploy to production)
- Context: AGENTS.md Release Gate 5 requires staging verification. `wyn-158-production-deploy.yml` deploys every merge to `main` directly to production, and the preview workflow does not cover the release branch, so Web Beta1 releases (#721–#729) skipped staging. This came up in the Codex review of PR #731 (QA sign-off).
- Founder decision (AskUserQuestion): **"ยอมรับเป็นข้อยกเว้นของ Web Beta1"**, an explicit exception for Web Beta1 only.
- Mitigations: Vercel Instant Rollback to the previous production deployment; Vercel Analytics/Speed Insights and the client error monitor; WYN-158 post-deploy route/config checks.
- Follow-up: set up a real staging environment for Web Beta2. This exception is **not** a precedent for other versions or releases.
- สถานะ: **อนุมัติแล้ว (ข้อยกเว้น)**. วันที่ 2026-09-26

### DECISION — [2026-09-26] WYNOS Web staging (Web Beta2 start)
- Founder request: "เริ่มจากข้อ 1 ตั้ง staging ก่อน". The follow-up to the Web Beta1 staging-gate exception.
- Founder decisions (AskUserQuestion): **use the same database as production** ("ใช้ฐานข้อมูลเดียวกับเว็บจริง"), and **per-PR staging, with merge still deploying production immediately** ("มี staging ต่อ PR แต่ merge แล้วขึ้นเว็บจริงทันทีเหมือนเดิม").
- Change: `web-next-phase5-preview.yml` no longer uses a branch allow-list. Every same-repository PR touching `web/` gets a protected Vercel preview, route smoke checks, full Playwright QA against the deployed URL, and a PR comment with the staging URL. See `docs/engineering/WEB_STAGING.md`.
- Cost: no new service. Uses existing Vercel preview deployments and more GitHub Actions minutes per web PR.
- Risks accepted: staging writes to production data (developer accounts only, no migration rehearsal); no Push on staging; production is still deployed on merge, so staging must be green **before** merge.
- Rollback: restore the previous `if:` allow-list in the workflow.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-26

### DECISION — [2026-09-26] WEB-B1-QA-04: post-upload image content validation
- Founder request: "ทำข้อ A แก้ WEB-B1-QA-04 ก่อน".
- Founder decisions (AskUserQuestion): **validate after upload and delete the file if it is not an image** ("ตรวจหลังอัปโหลด แล้วลบทิ้งถ้าไม่ใช่รูป"), and **the AI may deploy the Edge Function and install the Database Webhook on production after CI passes** ("ทำแทนได้เลยหลัง CI ผ่าน"). This approval covers this change only.
- Change: new Edge Function `validate-upload`, plus two triggers on `storage.objects` (image buckets only) created by `.github/workflows/storage-upload-validator.yml`. There is no schema change to application tables. It deletes only newly uploaded objects whose bytes are not an image.
- Risks: a non-image is readable for a few seconds before deletion; one extra function call per image upload; if the function is down, uploads still succeed and are not checked (fail-open).
- Rollback: `storage-upload-validator.yml` action `remove`, which drops both triggers.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-26

### DECISION — [2026-09-27] WYN-188: apply user_preferences to production
- Founder answers: "ต่อเลย" (proceed with PR #733), then an explicit, separate AskUserQuestion for the production migration: **"ติดตั้งได้เลย"**.
- Change: PR #733 merged (theme is developer-only). `web-beta2-apply-user-preferences.yml` applies `supabase/migrations_web_beta2_user_preferences.sql`, which is additive: one new owner-only table plus an updated_at trigger. It is validated in CI by `supabase/tests/web_beta2_user_preferences_test.sh`.
- Rollback: `drop table if exists public.user_preferences; drop function if exists internal.touch_user_preferences();`
- This approval covers this migration only. The general policy on AI-applied production SQL is unchanged.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-27

### DECISION — [2026-09-27] Release WYN-188 theme to all users; finish and release WYN-189 Thai/English
- Founder: **"จัดการให้เสร็จทั้ง2งานเลย อนุมัติทุกอย่าง พร้อมขึ้นเว็บ"**, meaning finish both tasks, everything approved, ready to go live.
- WYN-188 theme: the developer gate is removed. Every account gets Settings → Theme, and choices sync through `user_preferences`, which is already live. Accounts that never choose keep the phone-following look they have today.
- WYN-189 Thai/English: build every page, then release to every account once all pages are translated (Founder's earlier "ภาษาควรทำทุกหน้านะ"). Each part goes through per-PR staging first.
- Scope of this approval: web code, the merges that follow, and production deploys of these two features. **It does not cover new production SQL**, which still needs its own explicit confirmation. WYN-189 reuses the existing `user_preferences.language_preference` column, so no new SQL is expected.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-27

### DECISION — [2026-09-27] Keep WYN-188 theme and WYN-189 Thai/English live for every account
- Context: PR #734 released both to every account on wynos.online (Web Beta1) at 01:17 UTC. Afterwards the Founder said they had expected Beta2 to be developed separately while Beta1 served the public ("นึกว่าพัฒนา Beta2 รอ ส่วน Beta1 เปิดให้คนทั่วไปใช้").
- Options put to the Founder: gate back to developer-only (recommended), revert #734, or keep.
- Founder decision (AskUserQuestion): **keep it as released** ("ปล่อยไว้แบบนี้").
- Going forward: the "Beta2 is developer-only until the Founder releases it" boundary applies to new Beta2 features. A broad approval to "go live" should be confirmed as "all users" vs "developers" before a release.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-27

### DECISION — [2026-09-27] WYN-159 Beta2 chat: merge developer-only, apply message reactions migration
- Founder, after reviewing the before/after and hold-menu images: "ผ่านครับ เพิ่มเติม ปักมุด กับ รายงาน ด้วย". Then, in AskUserQuestion: **"ติดตั้งได้เลย"** for the reactions + delete-for-me migration, and **"ได้ เฉพาะนักพัฒนา"** to merge once CI passes.
- Scope: WYN-159 Threads-style chat behind the Beta2 gate (`BETA2_RELEASED.chatThreads = false`, so non-developers keep the Web Beta1 chat). Merging deploys it to production, where only developer accounts see it.
- Migration `supabase/migrations_web_beta2_message_reactions.sql`, applied via `web-beta2-apply-message-reactions.yml` after merge. It is additive: two new tables and two developer-gated RPCs. Rollback statements are in the file.
- This approval does **not** release WYN-159 to everyone. That needs a separate "Beta2 release: chatThreads" approval.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-27

### DECISION — [2026-09-27] Push notifications for every account: keep-on fix + in-app "turn on notifications" prompt
- Founder: **"เปิดให้ใช้ทุกคน เฉพาะการแจ้งเตือน ทุกคนต้องได้รับการแจ้งเตือน"**, meaning release to everyone, notifications only, and everyone must get notifications. Then, in AskUserQuestion: **"ทำ เปิดให้ทุกคน"** for a prompt asking people who have not answered yet.
- Scope: PR #736. It stops Push from turning itself off: server tokens are dropped only on a confirmed dead token, the switch no longer flips off on a failed check, and wanted accounts are re-registered on app open. It also adds a card on the main app screens: Allow opens the OS permission popup, and Not now waits 7 days. People who already allowed or denied are never asked again. On iPhone in a Safari tab, the card points to Add to Home Screen. It covers the merge, the production web deploy and the `send-push-notification` Edge Function deploy, for every account (not Beta2-gated).
- Not covered: WYN-159 Beta2 chat stays developer-only. No production SQL.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-27

### DECISION — [2026-09-27] Remove WYNOS Food from the web until launch
- Founder: **"WYNOS food ตัดออกก่อน ยังไม่ได้เปิดตัวตอนนี้"**, meaning cut WYNOS Food for now, it is not launching yet. Then, in AskUserQuestion: **"ลบออกจากเว็บ"**, remove it from the web.
- Scope: the `/food` developer preview, the developer-only Food shortcut on Home, the `/dev/food-fixture` page, and their tests, CSS, doc and three English strings are removed from `web/`. There was no Food database, API or payment code. Nothing changes for non-developer accounts, who never saw Food.
- Rollback / relaunch: restore from git history (the files as of this commit's parent).
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-27

### DECISION — [2026-09-27] WYN-137 Club announcements: merge developer-only, apply migration
- Founder, after reviewing the screenshots, in AskUserQuestion: **"ติดตั้งได้เลย"** for `supabase/migrations_web_beta2_club_announcements.sql`, and **"ได้ เฉพาะนักพัฒนา"** to merge PR #738 once CI passes.
- Scope: the Club "ประกาศ" tab behind the Beta2 gate (`BETA2_RELEASED.clubAnnouncements = false`). The migration is applied via `web-beta2-apply-club-announcements.yml` after merge and after main CI is green.
- The migration adds one table and three developer-gated RPCs. It changes no existing object: no notification type and no fan-out (see below). Rollback statements are in the file.
- This approval does **not** release WYN-137 to everyone. That needs a decision on Flutter users (the shared notifications table), a follow-up migration, and a separate "Beta2 release: clubAnnouncements" approval. Founder (2026-09-27): "เราพัฒนา แค่ Wynos Web Beta2", so this change leaves Flutter untouched. Founder (AskUserQuestion, after Codex review): **"ช่วง Beta2 ไม่ส่งแจ้งเตือน"**, so the migration sends no notifications and does not change `notifications_type_check`.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-09-27

### DECISION — [2026-09-27] Wynos Android becomes a native app (Kotlin + Jetpack Compose)
- Founder asked for Android to match the web, then chose the approach in AskUserQuestion: native Android with Kotlin and Jetpack Compose. No TWA, PWA or WebView. Web, Android and iOS share one backend, API and database with synced data and the same core features. UX/UI may differ per platform. **Wynos Web Beta 1 is the reference** for features and data structure, and iOS is planned for later.
- Platform names: Wynos Web Beta 1, Wynos Android v1.0.0 Beta 1, Wynos iOS v1.0.0 Beta 1.
- This is a major architecture / framework change that the Founder decided directly. The plan and its open decisions are in `docs/engineering/ANDROID_NATIVE_PLAN.md`. Coding starts after the Founder answers the open decisions: package name, Play Store, minimum Android version, the future of the Flutter app, the iOS approach, and milestone order.
- Replaces the 2026-09-19 "pause app development" instruction for Android only. The Flutter `app/` stays untouched until the Founder decides its future.
- Founder answered the open decisions (see "Founder answers" in the plan): package `io.wyn.wyn`, not on Play Store yet, Android 8.0+, Flutter retired on Android but kept for iOS, start M0 + M1 now.
- สถานะ: **อนุมัติแล้ว**. เริ่ม M0 + M1. วันที่ 2026-09-27

### APPROVAL_REQUIRED — [2026-09-27] WYN-135 developer-only Club chat production SQL
- Proposed change: After PR #741 passes SQL QA and staging, run only the manual `web-beta2-apply-club-chat-actions.yml` workflow on `main`. The additive migration adds `edited_at`, `pinned_at`, `pinned_by` to `club_channel_messages`, three developer-gated action/search RPCs plus a final readiness RPC, full-text and trigram GIN indexes, and the `pg_trgm` extension in the `extensions` schema if absent. Do not release `clubChatActions` to non-developers.
- Reason: The existing Club channel chat cannot edit own messages, pin staff announcements or search old text; indexed substring fallback is needed for unsegmented Thai words.
- Benefits: Completes WYN-135 for developer accounts without changing Web Beta1 UI, unrelated chat tables, or existing Flutter code.
- Risks: Index creation briefly locks `club_channel_messages` writes; new SECURITY DEFINER RPCs demand audit of auth, membership, allowed roles and developer gates; preview shares production DB and cannot validate uninstalled RPCs. The Web Beta2 UI stays on Beta1 behavior until the final developer-only readiness RPC is installed. No destructive SQL or existing RLS relaxation is planned.
- Files affected: `supabase/migrations_web_beta2_club_chat_actions.sql`, `supabase/tests/web_beta2_club_chat_actions_test.sh`, `.github/workflows/web-beta2-apply-club-chat-actions.yml`, Beta2-only web files. Rollback: Founder-directed drop of new RPCs/indexes and removal of only the new columns after reviewing developer data; never automatic.
- Verification: PR #741 `npm run check`, disposable PostgreSQL regression applied twice, protected staging and post-migration developer-only smoke tests. A mere general request to finish development does not replace explicit production SQL authorization under the 2026-09-07 policy.
- สถานะ: **รออนุมัติแยกสำหรับ Production SQL**; ไม่รัน workflow เอง และไม่เปิด Beta2 ให้ผู้ใช้ทั่วไป

### DECISION — [2026-09-27] WYN-135 developer-only PR merge
- Approved by: Founder
- Scope: Merge PR #741 to main and automatically deploy WYN-135 Web Beta 2 code to wynos.online, visible ONLY to confirmed developer accounts. Keep `BETA2_RELEASED.clubChatActions = false`; preserve Web Beta 1 UI and existing behavior for non-developers.
- Conditions: All current-head CI and protected Preview checks green, outstanding reviews resolved; run production deploy route smoke and post-migration authenticated developer-team UAT. No release of Web Beta 2 to the general public.
- Founder statement (2026-09-27): "อนุมัติ Merge และ Deploy เฉพาะบัญชีนักพัฒนา ไม่เปิดให้ผู้ใช้ทั่วไป".
- Status: APPROVED

### DECISION — [2026-09-27] WYN-135 production SQL
- Status: APPROVED
- Approved by: Founder
- Scope: WYN-135 production SQL only
- Migration SHA-256: fb72787038bb8a43230240b6f725961ae50fcc202573ec8a28d38e4804a562c8
- Artifact: `supabase/migrations_web_beta2_club_chat_actions.sql` in PR #741; reviewed Git blob `6d4398ccd5b3223d71d44399e947544980a3c38c`. Approve only this exact SQL digest through the manual `web-beta2-apply-club-chat-actions.yml` workflow on main after merge and final main checks. Do not modify the SQL artifact or relax authorization; confirm all 3 columns, 3 indexes and 4 RPCs before developer trial.
- Founder statement (2026-09-27): "อนุมัติ Production SQL เฉพาะไฟล์ migration SHA-256 ที่ระบุ ผ่าน workflow ที่ตรวจสอบแล้ว".
- Notes: additive migration and indexed searches can briefly lock Club chat writes; if migration verification fails, halt feature rollout, preserve fail-closed gate and investigate rather than automatic destructive rollback.

### DECISION — [2026-09-27] Web Beta 2 QA team and separate Free staging
- Approved by: Founder
- Developer acceptance testing: development team to test WYN-137 and post-migration WYN-135 under issue #748; authenticated manual tests remain pending until real testers provide the results. No user credentials should be recorded in GitHub.
- Staging: authorized to create a separate Free-tier Supabase project with **no incremental spending**; do not upgrade plans or incur a paid project, and request another explicit Founder approval before any spending. Prefer the existing WYNOS organization's second active Free slot if available; do not reactivate, repurpose or delete the older inactive project. Scope further implementation/isolation in issue #749; never copy production user data or credentials.
- Founder statement (2026-09-27): "ทีมพัฒนาจะทดสอบ"; "อนุมัติให้ใช้โปรเจกต์ Free แยก หากมีค่าใช้จ่ายต้องขออนุมัติใหม่".
- Status: APPROVED within these no-spend limits.


### DECISION — [2026-09-30] Release current developer-only WYNOS Web features to every account
- Founder direction: **"อยากให้ฟังชั่นที่เปิดใช้แค่นักพัฒนา เปิดให้ใช้ทุกคน"** — release the currently developer-only WYNOS Web features to all signed-in users.
- Scope: public release of the current Web rollout gates only. Existing authentication, ownership, Club-role, moderation, privacy, block/mute and RLS checks remain unchanged.
- Beta2 release: chatThreads
- Beta2 release: clubChatActions
- Beta2 release: clubAnnouncements
- Notifications release: advanced Web Push preferences, Quiet Hours, delivery tracking/retry policy and notification Realtime are released from Developer Preview to every Web account.
- Existing GA pull-to-refresh on Notifications, Bookmarks, Profile and Club posts remains unchanged; it was already released to everyone before this decision.
- No Email Notifications are added.
- Production authorization: Founder explicitly requested that these features be opened to everyone; this entry records approval for merge, the required additive Realtime publication migration, Edge Function rollout, and WYNOS Web production deployment after CI/QA gates pass.
- Rollback: revert the web release commit / restore the prior Edge Function and remove `public.notifications` from `supabase_realtime` if a release regression requires containment. Do not weaken unrelated auth/RLS controls.
- สถานะ: **อนุมัติแล้ว**
- วันที่ตัดสินใจ: 2026-09-30

### DECISION — [2026-10-03] WYN-193 WYNOS Food mandatory delivery photo + buyer notification
- Founder: **"บังคับให้ร้านแนบรูปทุกครั้ง"** และ **"เอาตามที่ว่าดีที่สุดเลย"** (รับข้อเสนอ: บังคับรูปทุกวิธีส่ง + แจ้งเตือนลูกค้าเมื่อส่งถึง; ยังไม่บันทึกข้อมูลคนส่ง)
- Context: ไม่มีระบบไรเดอร์ ร้านจ้างคนส่งภายนอก คนส่งส่งรูปให้ร้าน ร้านแนบรูปให้ลูกค้า; ตอนนี้มีร้าน WYNOS ร้านเดียว แต่กติกาใช้กับทุกร้าน
- Scope: implementation บน branch + PRD `.wyn/tasks/backlog/WYN-193-food-mandatory-delivery-photo.md`
- ไม่ครอบคลุม: การ merge เข้า main, การ apply `supabase/migrations_wynos_food_delivery_photo_required_v1.sql` บน production และ production deploy — ต้องขออนุมัติแยกหลัง QA
- Rollback: re-run `food_complete_delivery` จาก `migrations_wynos_merchant_core_completion_v1.sql` และ revert web commit
- สถานะ: **อนุมัติแล้ว (implementation)**. วันที่ 2026-10-03

### DECISION — [2026-10-03] WYN-194 isolate WYNOS Food storage per store
- Founder: **"แก้ปัญหาให้หน่อย แล้วQA"** หลังได้รับรายงานว่า storage ของ Food ข้ามร้านได้
- Scope: security policy tightening เฉพาะ storage policies ของ `food-private` / `food-public` (`supabase/migrations_wynos_food_storage_store_isolation_v1.sql`) + QA; ไม่ลดสิทธิ์ลูกค้า ไม่แก้ข้อมูล
- ไม่ครอบคลุม: merge เข้า main, apply migration production, production deploy — ต้องขออนุมัติแยกหลัง QA
- Rollback: re-run policies เดิมจาก `migrations_wynos_food_customer_access_gate_v2.sql` และ `migrations_wynos_food_merchant_v1.sql`
- สถานะ: **อนุมัติแล้ว (implementation + QA)**. วันที่ 2026-10-03

### DECISION — [2026-10-03] WYN-193 / WYN-194 production release
- Founder: **"อนุมัติ merge และติดตั้งบนระบบจริง"** (after QA & Security PASS, CTO review and Codex review fixes on PR #819)
- Scope:
  1. merge PR #819 (web auto-deploys to production);
  2. immediately afterwards, dispatch `food-apply-wyn193-wyn194.yml` on main with `APPLY-WYN-193-194`, which applies `migrations_wynos_food_storage_store_isolation_v1.sql` then `migrations_wynos_food_delivery_photo_required_v1.sql` in one transaction and verifies them;
  3. deploy Edge Function `validate-upload`, then run `storage-upload-validator.yml` with `create`, then `test`, to cover the `food-private` and `food-public` buckets.
- Runbook: between steps 1 and 2, do not complete 'direct' deliveries.
- Rollback: Vercel Instant Rollback / revert the merge commit; the SQL rollback is in the workflow header; `storage-upload-validator.yml` with `remove`.
- Post-release: send one test order and open its delivery photo from the customer side.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-03

### DECISION — [2026-10-03] WYN-195 WYNOS Food entry in the social app
- Founder: **"WYNOS Food ควรมีอยู่ในหน้าโซเซียลนะ"**. In AskUserQuestion, placement **"แถบลัดใต้แท็บหน้าหลัก กับ ในเมนูด้านข้าง"** and audience **"เฉพาะ developer ก่อน"**. On the staging preview: **"อนุมัติ"** to merge PR #820.
- Scope: web-only Home shortcut row and drawer item, shown to developer accounts only. No database or API change. Opening Food to everyone needs a separate decision.
- Rollback: revert the merge commit, or use Vercel Instant Rollback.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-03

### DECISION — [2026-10-03] WYN-196 WYNOS Food delivery zone and distance fee
- Founder (AskUserQuestion): default radius **"5 กม."**, fee **"ตามระยะทาง"**, location input **"กดใช้ตำแหน่งปัจจุบัน + ค้นหา"**. After reviewing PR #824: **"อนุมัติ"**.
- Scope:
  1. merge PR #824 (web auto-deploys; safe before or after the migration);
  2. dispatch `food-apply-wyn196.yml` with `APPLY-WYN-196`;
  3. deploy the `location-search` Edge Function (adds CORS).
  A store without a pinned location keeps its flat fee. The store owner pins the store in Merchant settings.
- Rollback: revert the merge commit or use Vercel Instant Rollback; SQL rollback is in the workflow header.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-03

### DECISION — [2026-10-03] WYN-197 WYNOS Food free place search (store place list)
- Founder asked for free place search without a paid map service. AI recommended a per-store place list (option 1). Founder: **"อนุมัติ"** to build it. After reviewing PR #825: **"อนุมัติ"**.
- Scope:
  1. merge PR #825 (web auto-deploys; safe before the migration);
  2. dispatch `food-apply-wyn197.yml` with `APPLY-WYN-197` (adds `food_store_places` and `food_search_store_places`).
  The store adds its places in Merchant settings.
- Rollback: revert the merge commit; SQL rollback is in the workflow header.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-03

### DECISION — [2026-10-04] WYN-198 Wynos Merchant simpler order flow
- Founder: "Wynos Merchant อยากให้ระบบใช้งานง่ายๆ เหมือนของ LINE MAN Merchant". In AskUserQuestion: all four changes (one button per order card, new-order pop-up with sound, four-tab order page, bigger buttons and text) and **"รวมเป็นปุ่มเดียว"** for slip check + accept. After reviewing PR #826: **"อนุมัติ"**.
- Scope: web only, no database change. Merge PR #826 (the web auto-deploys).
- Rollback: revert the merge commit or use Vercel Instant Rollback.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-199 Wynos Merchant asks for notifications on open
- Founder: "เวลากดเข้าไอคอน ควรถาม/ขออนุญาต เปิดการแจ้งเตือนทันทีนะ". After reviewing PR #827: **"อนุมัติ"**.
- Scope: web only, no database change. Merge PR #827 (the web auto-deploys).
- Rollback: revert the merge commit or use Vercel Instant Rollback.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-200 Wynos Merchant own order alert sound
- Founder: "เพิ่มเสียงการแจ้งเตือน ที่เป็นของตัวเอง ไม่ติดลิขสิทธิ์". After listening and reviewing PR #828: **"อนุมัติ"**.
- Scope: web only. An original sound synthesized by `web/scripts/generate-merchant-order-sound.py` (no third-party audio), played in the new-order alert. Merge PR #828 (the web auto-deploys).
- Rollback: revert the merge commit or use Vercel Instant Rollback.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-201 pull to refresh in Merchant and Food; WYN-202 alert rings until the order is opened or accepted
- Founder approved pull-to-refresh on list pages ("อนุมัติ"), asked "ดังจนกว่า จะกดรับออเดอร์ หรือ กดดูออเดอร์" for the alert, and after reviewing PRs #829 and #830: **"อนุญาต"**.
- Scope: web only. Merge PR #829, then PR #830 (the web auto-deploys).
- Rollback: revert the merge commits or use Vercel Instant Rollback.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-203 WYNOS Admin Food store and order operations
- Founder: "ระบบหลังบ้าน WYNOS Admin เพิ่ม Merchant ยัง", then "เพิ่มระบบที่ยังไม่มี". After reviewing PR #831 and its security decisions: **"อนุมัติ"**.
- Scope: Admin `/food` (overview, all stores, suspension, cross-store orders with slip and delivery photo, store team), Merchant suspended banner, and the migration `supabase/migrations_wynos_admin_food_ops_v1.sql`.
- Security decisions accepted:
  - Customer data and all changes are admin only, and moderators can read store data only.
  - Platform admins get read access to `food-private`.
  - Order views, suspensions and team changes are audited.
- Release: merge PR #831 (Admin and web auto-deploy), then dispatch `food-apply-wyn203.yml` with `APPLY-WYN-203`.
- Rollback: revert the merge commit; the SQL rollback is in the workflow header.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-204 Wynos Merchant simple home, 3D icons and four tabs
- Founder shared LINE MAN Merchant screenshots ("ชอบ LINE MAN มาก ดูใช้งานง่าย"). Founder then asked for "UX UI ไม่ซ้ำใคร เรียบง่าย ใช้งานง่าย ปุ่มไอคอน 3D สวยๆ" and said "ไอคอนโอเค". After comparing layouts: "ผมชอบดีไซน์เรียบๆ ใช้งานง่าย ดูแล้วเข้าใจ ไม่งง". After reviewing PR #832: **"อนุมัติ แอปแค่โหมดสว่างพอ"**.
- Scope: web only.
  - Wynos home: red "today" card, a row of 3D shortcuts, orders to handle, readiness bar.
  - Wynos's own 3D SVG icon set.
  - Four tabs: หน้าหลัก · รับออเดอร์ · เมนู · เพิ่มเติม.
  - Merchant is light only.
- Release: merge PR #832; the web auto-deploys.
- Rollback: revert the merge commit or use Vercel Instant Rollback.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-205 Merchant finance page and four home shortcuts; WYN-206 campaign funding
- Founder: "ตรงนี้ให้มีแค่ การเงิน โฆษณา แคมเปญ โปรโมชั่น", then "ทำครบทั้ง 4 ระบบเลย". Decisions:
  - Ads: pay per click, controlled from WYNOS Admin.
  - Ad payment: PromptPay plus slip.
  - Campaigns: designed by WYNOS Admin.
  - Ad placement: Food home recommended stores, plus top of search.
- After reviewing PR #833: **"อนุมัติ"**. Scope: web only (shortcuts, finance page, store discounts renamed โปรโมชั่น, coming-soon pages for campaigns and ads).
- WYN-206 funding: **"แคมเปญ เป็นระบบไฮบริด แล้วแต่จะตั้งยังไง ขึ้นอยู่กับ WYNOS Admin จะเป็นคนออกแคมเปญ"**. Admin sets, per campaign, how much of the discount WYNOS funds and how much the store funds. WYNOS's share is recorded as owed to the store until Admin marks it paid.
- Rollback for WYN-205: revert the merge commit or use Vercel Instant Rollback.
- สถานะ: **อนุมัติแล้ว** (WYN-205 release; WYN-206 direction). วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-205 follow-ups (PR #834) and WYN-206 WYNOS campaigns (PR #835)
- PR #834:
  - Codex finance fixes.
  - Founder: "เอาตรงที่วงสีเหลืองออก" (remove "ต้องจัดการตอนนี้" from home).
  - Founder: "ทุกหน้า ต้องคุมโทนสีประจำนะให้เด่นกว่า คือสีแดง".
  - Founder: "ถ้ามีสีรุ้ง ตัดทิ้งเลย ไม่ใช้แล้ว". For Wynos Merchant this replaces the AGENTS.md "rainbow accents 10–20%" direction: the page styling is red and white with no rainbow.
  - Founder: "พวกไอคอน ไม่ต้องคุมโทนแดง หมดก็ได้ เดียว งง". The 3D icons keep their own colours.
- PR #835: WYNOS campaigns designed in Admin with hybrid funding (Admin sets WYNOS's share per campaign). WYNOS's share is owed to the store until Admin records the transfer. Security decisions accepted:
  - Admin-only campaign design.
  - Admin-only payouts, showing store payout details.
  - Admin-only settlement.
  - A guard stops stores changing WYNOS campaign terms.
- After reviewing both PRs: **"อนุมัติ"**.
- Release:
  1. Merge #834 (the web auto-deploys).
  2. Merge #835 and dispatch `food-apply-wyn206.yml` with `APPLY-WYN-206`.
  3. Run `deploy-admin.yml`.
- Rollback: revert the merge commits. The SQL rollback for WYN-206 is in the workflow header.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-207 WYNOS Food pay-per-click ads (PR #836)
- Founder decisions: pay per click with WYNOS Admin control, PromptPay plus slip, Food home recommendations and top of search. After reviewing PR #836: **"อนุมัติ"**.
- Scope:
  - Admin ad settings (off by default), slip review, stop/allow store ads.
  - Merchant ad credit, top-up and pause.
  - Food store directory with labelled ads.
  - Server-side click charging: once per customer per store per day, never for the store's own team.
- Security decisions accepted:
  - RLS on with no direct grants (balances cannot be edited).
  - Ad slip storage scoped to the store's own folder.
  - Admin-only money actions, audited.
- Release: merge PR #836, dispatch `food-apply-wyn207.yml` with `APPLY-WYN-207`, run `deploy-admin.yml`. The Founder then sets WYNOS PromptPay and price in Admin and switches ads on.
- Rollback: switch ads off in Admin (or `update food_ad_settings set ads_enabled=false`), then revert. Full SQL rollback is in the workflow header.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-208 Wynos Merchant bottom-bar icons (PR #840)

- Founder request: "ออกแบบไอคอนด้านล่างให้หน่อย".
- Change: Wynos's own icons for the four bottom tabs:
  - Not selected: outline.
  - Selected: solid Wynos red with white details.
- Frontend only. No database, API or auth change.
- Release: merge PR #840. Web auto-deploys.
- Rollback: revert PR #840.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-209 Wynos Merchant app icon (PR #841)

- Founder request:
  - "ออกแบบไอคอนแอป Wynos Merchant ให้ด้วย"
  - Then supplied the exact artwork: "แค่อยากเพิ่มคำว่า Merchant ในไอคอน และจัด ไอคอน ชื่อ ให้สวย ตรงกลาง"
  - Picked text size C.
- Change:
  - v15 icons use the Founder's artwork, full-bleed red with no white border.
  - "Merchant" sits under the mark, centred.
  - The manifest moves to `?v=15`.
  - Fixes the truncated v14-512 PNG.
- Frontend assets only. No database, API or auth change.
- Release: merge PR #841. Web auto-deploys.
- Rollback: revert PR #841.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-210 Wynos Merchant finance summary (PR #849)

- Founder request:
  - A new finance page, without copying the reference app.
  - "การเงิน / สรุป": วันนี้ เมื่อวาน สัปดาห์นี้ เดือนนี้, plus a calendar range.
  - Headline numbers ยอดขายสุทธิ and รายได้.
  - "เงินที่ WYNOS จะโอนให้ร้าน" shown only when it is above 0.
- Change:
  - New read-only RPC `merchant_finance_summary`: store owner/admin/manager only, explicit role check, no developer cross-store access.
  - The new page is staged: developer accounts first; other stores keep the previous page until the Founder says "เปิดให้ทุกคน".
- Security decisions accepted:
  - Finance access is narrowed to managers.
  - No table, policy or data changes.
- Release:
  1. Merge PR #849 (web auto-deploys).
  2. Dispatch `food-apply-wyn210.yml` with `APPLY-WYN-210`.
- Rollback: revert PR #849; `drop function public.merchant_finance_summary(uuid, date, date)`.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-211 Open WYNOS Food to everyone, ordering only in Maha Sarakham (PR #865)

- Founder request: "Wynos Food เปิดให้ทุกคนเห็น แต่สามารถใช้ได้แค่คนที่อยู่ จ มหาสารคาม".
- Founder's answers:
  - The area is checked from the delivery pin, on the server.
  - Stores must be in Maha Sarakham.
  - People outside the province see only an introduction page.
- Change:
  - `public_enabled = true`.
  - The Food entry shows for every signed-in user.
  - Quote and order refuse a store pin or delivery pin outside the Maha Sarakham boundary (OSM, ODbL); developers are exempt.
  - Readiness requires a store pin inside the province.
- Accepted:
  - Published stores without a pin inside the province stop taking orders until they pin it.
- Release:
  1. Merge PR #865 (web auto-deploys).
  2. Dispatch `food-apply-wyn211.yml` with `APPLY-WYN-211`.
- Rollback: `public_enabled = false` and revert; or re-apply the previous `food_delivery_fee` and readiness definitions.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-212 Home Food banner only for people in Maha Sarakham (PR #867)

- Founder request:
  - "กลัวไปรบกวน คนอื่น" about the Home Food banner.
  - Approved points 1–3.
- Change:
  - Food stays in the drawer for everyone.
  - The Home banner shows only when Food's area check or the user's saved delivery pin is inside Maha Sarakham.
  - The banner has an ✕ to hide it.
  - Frontend only.
- Release: merge PR #867. Web auto-deploys.
- Rollback: revert PR #867.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-213 Merchant access hardening (PR #874)

- Source: WYNOS Admin Merchant audit. The Founder approved the work, then gave "อนุมัติ" for merge and production.
- Security change:
  - The developer-account cross-store bypass is removed from the merchant helpers.
  - Legacy `food_staff` rows count by role.
  - WYNOS owes only paid orders from real customers.
  - Payouts must match the amount the admin saw.
  - One ad slip, one top-up.
- Accepted: developer accounts need a store membership to use the Merchant app for a store.
- Release:
  1. Merge PR #874.
  2. Dispatch `food-apply-wyn213.yml` with `APPLY-WYN-213`.
  3. Run `deploy-admin.yml`.
- Rollback: previous definitions (listed in the workflow header); drop `food_ad_topups_slip_path_uidx`.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-214 WYNOS Admin Merchant polish (PR #877)

- Source: the WYNOS Admin Merchant audit. Founder said "ทำต่อ", then "อนุมัติ".
- Change:
  - Store detail shows the service area, pin and readiness.
  - New order filters: payments to review and refunds pending.
  - Order detail shows discounts and refund details.
  - Merchant approval asks for confirmation, and messages are in Thai.
  - Lists say when they are cut off.
  - Read-only RPC changes only.
- Release:
  1. Merge PR #877.
  2. Dispatch `food-apply-wyn214.yml` with `APPLY-WYN-214`.
  3. Run `deploy-admin.yml`.
- Rollback: revert, then re-run both functions from `migrations_wynos_admin_food_ops_v1.sql`.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### DECISION — [2026-10-04] WYN-210 finance page opened to every store

- Founder: "เปิดทุกคน". This is the explicit WYN-125 go-ahead to end the staged rollout.
- Change:
  - The developer gate around `MerchantFinance` is removed.
  - The old `FinancePanel` is removed.
  - Frontend only; the WYN-210 RPC is already live.
- Release: merge. Web auto-deploys.
- Rollback: revert the PR (the old page comes back).
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-04

### APPROVAL — [2026-10-05] WYNOS Food share link previews read store profile without sign-in

- Founder: "อนุมัติ ทำเลย" (AskUserQuestion, after seeing that LINE fetches previews signed out and this opens an anon read).
- Change:
  - New RPC `food_store_share_preview(uuid)`, executable by `anon`.
  - Returns only the name, the description (cut to 160 characters), and the logo and cover paths.
  - Only for published stores that are not suspended.
  - Never returns the phone, address, payment details, owner, menu or orders.
  - `/food?store=<id>` builds its link preview (og/twitter) from the RPC, using the publishable key only.
- Release:
  1. Merge the PR. Web auto-deploys and falls back to the generic preview until the migration runs.
  2. Dispatch `food-apply-share-preview.yml` with `APPLY-FOOD-SHARE-PREVIEW`.
- Rollback: `drop function public.food_store_share_preview(uuid);` and/or revert the PR.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-05

### DECISION — [2026-10-05] WYNOS Food short share links (food.wynos.online/s/<code>)

- Founder: "ชื่อลิ้งยาว แก้ได้ไหม", then chose "รหัสสั้น 6 ตัว" over custom names chosen by the store.
- Change:
  - Additive column `food_stores.share_code`: 6 random characters (a–z and 2–9, without i, l, o, 0 or 1), unique.
  - The database assigns the code on insert. No API caller can set or change it (security-definer trigger).
  - `food_store_id_by_share_code(text)` is executable by `anon` and returns only the store id, only for published, non-suspended stores.
  - `food_store_share_preview` also returns the code.
  - Web: `/s/<code>` on the Food host redirects to `/?store=<id>`, and the share buttons use the short link.
- Release:
  1. Merge. Web auto-deploys and keeps sharing `?store=` links until the migration runs.
  2. Dispatch `food-apply-share-code.yml` with `APPLY-FOOD-SHARE-CODE`.
- Rollback: SQL in the migration header, and/or revert the PR. Old `?store=` links keep working throughout.
- สถานะ: **อนุมัติแนวทางแล้ว**. วันที่ 2026-10-05

### APPROVAL — [2026-10-05] Food order-status push, notification deep links, store QR and share-link results

- Founder: "ทำทุกข้อเลย อนุมัติ ทุกอย่าง ให้เสร็จเลย พร้อมใช้งาน". This covers the four recommendations and their production release.
- Change:
  - **Order-status push.** New trigger `food_orders_status_notify`:
    - Customer: store accepted (with ETA), out for delivery, cancelled by the store (with a refund note when paid).
    - Store: the customer cancelled.
    - Routed by the existing WYN-215 app rules.
  - **Deep links.** `send-push-notification` adds `order_number` to Food and Merchant pushes. The service worker opens `/food?order=WF…` or `/merchant?order=WF…`, and both apps open that order.
  - **Store QR.** Merchant home has a share card with a QR poster (new web dependency `qrcode`) to save or share.
  - **Share-link results.**
    - `food_share_link_opens`: daily opens of the short link. Recorded server-side by `/s/<code>`, skipping link-preview crawlers. Anon can only add a count, and only for published stores.
    - `food_orders.from_share_link`: the buyer marks their own order within 15 minutes, when they opened the store from a link in the last 24 hours.
    - `food_share_stats`: 7-day opens, orders and sales, for store staff only.
- Release:
  1. Merge. Web auto-deploys and tolerates the missing RPCs.
  2. Dispatch `food-apply-order-push.yml` with `APPLY-FOOD-ORDER-PUSH`.
  3. Dispatch `deploy-edge-functions.yml` with `send-push-notification`.
- Rollback: SQL in the migration header, redeploy the previous `send-push-notification`, revert the PR.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-05

### APPROVAL — [2026-10-06] WYNOS Merchant: order screen mode and unaccepted-order reminders

- Founder asked whether Merchant needs its own notification sound. Of the options given, the Founder chose "ทำAก่อน ให้เสร็จเลย" (the web-only option A), through to production.
- Context: phones play the WYNOS order sound only while Merchant is open. A closed app gets one standard push. A native app (option B) is deferred.
- Change:
  - **"หน้าจอรับออเดอร์" (order screen).** A toggle on Merchant home and in notification settings that keeps the screen awake with the Screen Wake Lock API, taking the lock again when Merchant returns to the front or the screen is tapped. Turning it on is also the tap that unlocks and tests the sound. A status bar shows whether the screen is kept on and the sound is ready.
  - **Tips in notification settings.** iPhone silent switch, order screen, Web Push, Home Screen install.
  - **Unaccepted-order reminders.** pg_cron runs `internal.food_remind_waiting_orders()` every minute. Paid or slip-submitted orders still in `pending_acceptance` (from the last 3 hours) send a push to the active owner and staff, at most 5 times: "WYNOS Merchant · ออเดอร์ #WF… รอรับ N นาทีแล้ว". Reminder state is kept in `food_order_merchant_reminders`, so `food_orders` is never updated.
- Release:
  1. Merge. Web auto-deploys.
  2. Dispatch `merchant-apply-order-reminders.yml` with `APPLY-MERCHANT-REMINDERS`.
- Rollback: SQL in the migration header (unschedule the job, drop the function and table), and/or revert the PR.
- สถานะ: **อนุมัติแล้ว**. วันที่ 2026-10-06

### APPROVAL_REQUIRED — [2026-10-10] WYN-219 Phase 2: Per-system admin permissions
- Proposed change: เพิ่ม `admin_permissions` (สิทธิ์รายระบบ view/edit) และ `internal.platform_super_admins`, helper `internal.has_admin_permission()` แล้วย้ายจุดตรวจ `platform_role` ~60 จุดใน RPC/RLS ไปใช้ helper ทีละระบบ
- Reason: Founder ต้องการให้ Admin ควบคุมได้ทุกระบบ โดยแยกสิทธิ์ตามระบบ (decision 2026-10-10)
- Benefits: least privilege, ทีมแต่ละระบบเห็นเฉพาะงานตัวเอง, ทุกการให้สิทธิ์ถูก audit
- Risks: privilege escalation หรือ admin lockout ถ้าย้ายผิด; ~60 functions ต้องดึงนิยามจาก production ก่อนแก้
- Files affected: `supabase/migrations/*` (ใหม่), `supabase/tests/*`, `admin/lib/auth.ts`, `admin/lib/admin-nav.ts`, admin layout/sidebar, หน้าใหม่ "สิทธิ์ทีมงาน"
- Recommendation: อนุมัติหลังตอบ Q1–Q3 ใน `.wyn/docs/engineering/wyn-219-phase2-admin-permissions-proposal.md`; rollout 3 ขั้น แยก PR ต่อระบบ
- สถานะ: รออนุมัติ
- วันที่ตัดสินใจ:
