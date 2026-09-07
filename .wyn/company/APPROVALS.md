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
