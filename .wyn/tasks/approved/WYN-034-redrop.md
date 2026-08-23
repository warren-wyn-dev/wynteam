# Product Task — WYN-034

Status: backlog
Owner: AI Product Manager

Feature: ReDrop (Standard + Quote)

Goal: ให้ผู้ใช้แชร์ Drop ของคนอื่นเข้าฟีดตัวเองได้ 2 แบบ — task แรกของ Phase 3 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 5 ("ReDrop มี 2 แบบ: Standard ReDrop/Quote ReDrop — เครดิตเจ้าของเดิมต้องยังอยู่") และ section 9 ("Tabs: Drops, ReDrops, Media, Likes")

Target User: ผู้ใช้ทุกคนที่อยากแชร์ Drop ที่เจอให้ follower ตัวเองเห็น โดยไม่ต้อง copy เนื้อหามาโพสต์ใหม่เอง

Problem: ตอนนี้ปุ่ม "🔄 ReDrop" บน Drop Card ยังไม่มีอยู่จริงเลย (Master Spec ระบุไว้เป็น action หลักคู่กับ Like/Comment/Share/Save แต่ยังไม่เคย implement) — ไม่มีทางขยายการมองเห็นของ Drop ที่ดีผ่าน follower ของคนอื่น นอกจาก native share (WYN-033) ซึ่งออกจากแอปไปเลย ไม่กลับเข้าฟีด WYN

Requirements:

**Standard ReDrop**
- แชร์ Drop เดิมไปฟีดตัวเอง โดยไม่แก้ไขเนื้อหาใดๆ — เป็น toggle เหมือนปุ่ม Like (กดครั้งแรก = ReDrop, กดซ้ำ = Un-ReDrop/ยกเลิก) ผู้ใช้ 1 คน ReDrop แบบ Standard ต่อ Drop เดิมได้แค่ 1 ครั้งเท่านั้น (กด toggle ไม่ใช่สร้างซ้ำ)
- การ์ดที่เห็นในฟีดของ follower คือการ์ด Drop เดิมทุกประการ (รูป/ข้อความ/สถิติ/เจ้าของเดิม) เพิ่มแค่ label เล็กๆ ด้านบน "🔄 ReDrop โดย @username" — เครดิตเจ้าของเดิม (avatar/ชื่อ/@username บนตัวการ์ด) ไม่เปลี่ยนเลย

**Quote ReDrop**
- แชร์ Drop เดิม + ใส่ความคิดเห็นของตัวเอง (ข้อความสั้นๆ ความยาวเท่า caption ปกติ 1-500 ตัวอักษร) — เป็นเนื้อหาใหม่ที่ตัวเอง "เขียน" ขึ้นมา ไม่ใช่ toggle ผู้ใช้ Quote ReDrop Drop เดิมซ้ำได้หลายครั้ง (คนละความคิดเห็นคนละครั้ง — ไม่บังคับ unique เหมือน Standard)
- การ์ดที่เห็นในฟีดคือการ์ดใหม่ (ผู้เขียน = คนที่ Quote, ข้อความ = ความคิดเห็นของเขา) โดยมี Drop เดิมแสดงเป็น preview card ฝังอยู่ด้านล่าง (คล้าย reply preview ใน WYN Chat ที่มีอยู่แล้ว) แตะ preview card แล้วเปิด Drop เดิมเต็มจอ
- ลบ Quote ReDrop ของตัวเองได้ (ลบตรงๆ ไม่ต้อง soft-delete — Quote ReDrop ยังไม่ผูกกับ reply chain แบบ message)

**สถิติและการมองเห็น**
- Drop เดิมมี counter "🔄 ReDrops" นับรวมทั้ง Standard + Quote ที่ชี้มาที่ตัวมันเอง (ตาม Master Spec's Statistics: "👁️ Views · ❤️ Likes · 💬 Comments · 🔄 ReDrops")
- ทั้ง Standard และ Quote ReDrop ปรากฏในฟีดของ follower ของผู้ ReDrop (ไม่ใช่แค่ follower ของเจ้าของ Drop เดิม) — เป็นกลไกขยายการมองเห็นตามเจตนาของฟีเจอร์
- Profile ของผู้ใช้แต่ละคนมี tab "ReDrops" แยกจาก tab "Drop" เดิม (ตาม Master Spec section 9) แสดงทั้ง Standard + Quote ที่ตัวเอง ReDrop ไป

**ความปลอดภัย/ความเป็นส่วนตัว**
- ถ้า Drop เดิมถูกลบ (ทั้งจากเจ้าของเองหรือ Moderation Remove Content) ReDrop ที่ชี้ไปหา (ทั้ง Standard และ Quote) หายไปด้วยอัตโนมัติ (cascade) — มิเรอร์กติกาเดิมของ `drop_likes`/`drop_comments`/`saved_drops` ทุกตัวที่ cascade ตาม Drop เดิมอยู่แล้ว ไม่ใช่กติกาใหม่ (ต่างจาก WYN-033's shared-content-in-chat ที่จงใจไม่ cascade เพราะข้อความแชทเป็นบันทึกการสนทนาที่ต้องคงอยู่ — ReDrop เป็นการ "ขยายเสียง" เนื้อหาคนอื่นล้วนๆ ไม่มีเหตุผลให้คงอยู่ต่อถ้าต้นทางหายไปแล้ว)
- คนที่ block กันอยู่กับ**ผู้ ReDrop** ต้องไม่เห็น ReDrop นั้นเลย (มิเรอร์ policy เดิมของ `drops`) — คนที่ block กันอยู่กับ**เจ้าของ Drop เดิม** ก็ต้องไม่เห็น ReDrop ที่ชี้ไปหา Drop นั้นเช่นกัน แม้ผู้ ReDrop จะไม่ได้ถูก block ก็ตาม (ไม่งั้นจะเป็นช่องทางเลี่ยง block เดิมของ `drops` ได้ผ่านการ ReDrop)
- ReDrop คนที่ block กันอยู่ไม่ได้ (ทั้งสองทิศทาง) — เหมือนที่ Like/Comment/Follow เดิมกันไว้อยู่แล้วทุกจุดในระบบ
- ข้อความของ Quote ReDrop รายงานได้แยกจาก Drop เดิม (ข้อความตัวเองอาจไม่เหมาะสมได้แม้ Drop เดิมไม่มีปัญหา) — reuse `submit_report()`/`target_type` เดิม เพิ่มแค่ประเภทใหม่ `'redrop'`
- ผู้ใช้ที่ถูก Restrict/Suspend/Ban (posting-blocked) ReDrop ไม่ได้เลยทั้งสองแบบ — reuse `internal.is_posting_blocked()` เดิม

**Notification**
- เจ้าของ Drop เดิมได้รับ notification เมื่อมีคน ReDrop (ทั้ง Standard/Quote) — reuse `notifications.drop_id` เดิม (ที่ใช้กับ like_drop/comment_drop อยู่แล้ว) เพิ่ม type ใหม่ `redrop`

Acceptance Criteria:
- [ ] กด 🔄 บน Drop คนอื่น → ปรากฏในฟีดของ follower ตัวเอง เป็นการ์ดเดิมทุกประการ+label "ReDrop โดย @ตัวเอง" เครดิตเจ้าของเดิมยังอยู่ครบ
- [ ] กด 🔄 ซ้ำ (Un-ReDrop) → หายจากฟีดของ follower ตัวเอง, ReDrop count ของ Drop เดิมลดลง 1
- [ ] Quote ReDrop ใส่ข้อความได้ (1-500 ตัวอักษร) → ปรากฏเป็นการ์ดใหม่พร้อม preview ของ Drop เดิม แตะ preview เปิด Drop เดิมเต็มจอได้จริง
- [ ] Quote ReDrop ซ้ำ Drop เดิมได้หลายครั้งคนละข้อความ (ไม่ถูกบล็อกเหมือน Standard)
- [ ] ลบ Quote ReDrop ของตัวเองได้ → หายจากฟีดจริง
- [ ] Drop เดิมถูกลบ → ReDrop (ทั้ง Standard/Quote) ที่ชี้ไปหาย cascade จริง ตรวจสอบ DB ได้
- [ ] ReDrop คนที่ block กันอยู่ไม่ได้ (ทั้งสองทิศทาง)
- [ ] คนที่ block กันอยู่กับผู้ ReDrop ไม่เห็น ReDrop นั้น + คนที่ block กันอยู่กับเจ้าของ Drop เดิมก็ไม่เห็นเช่นกัน
- [ ] Restrict/Suspend/Ban แล้ว ReDrop ไม่ได้เลย
- [ ] รายงานข้อความ Quote ReDrop ได้แยกจาก Drop เดิม เข้า Moderation Queue จริง
- [ ] เจ้าของ Drop เดิมได้ notification เมื่อมีคน ReDrop
- [ ] Profile tab "ReDrops" แสดง Standard+Quote ที่ตัวเอง ReDrop ไปจริง
- [ ] Regression: Home Feed/Drop เดิมทุกจุด (ranking, mute, block, view Drop เดี่ยว) ทำงานเหมือนเดิม

Dependencies: WYN-026 (Report — `target_type` ขยาย), WYN-027 (Block — `is_blocked_either_way` reuse), WYN-029 (Moderation — `is_posting_blocked`/Remove Content cascade), WYN-033 (Share to Chat — วาง pattern "resolve เนื้อหาผ่าน repository เดิม ไม่ denormalize" ที่ Quote ReDrop's preview card นำมาใช้ต่อ) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P0 — task แรกของ Phase 3 ตาม Roadmap ("เริ่ม Phase 3 เลย")

Risks:
- **ไม่รองรับ ReDrop ของ ReDrop (nesting)** — `drop_id` ที่ redrops ชี้ไปต้องเป็น Drop จริงเท่านั้น ไม่ใช่ redrop อื่น — ตั้งใจตัดเพื่อความเรียบง่ายรอบนี้ (ตรงกับพฤติกรรมจริงของแพลตฟอร์มส่วนใหญ่ที่ไม่ให้ retweet ซ้อน retweet ได้ไม่จำกัดชั้น) ถ้า Founder ต้องการ nesting ต้องแจ้งก่อนเริ่ม Design
- **Home Feed ranking (WYN-018) ต้องขยายให้รู้จัก content type ใหม่** — ranking เดิมทำงานบน `home_feed` view (union ของ drops/pops) คำนวณ client-side จาก candidate rows — ReDrop เพิ่ม branch ที่ 3 (หรือ logic แยกสำหรับ Standard vs Quote) เป็นงานที่มีความเสี่ยง regression สูงสุดของ task นี้ ต้องทดสอบ ranking เดิม (drops/pops) ไม่เปลี่ยนพฤติกรรมหลังแก้
- **Quote ReDrop ไม่มี Like/Comment/ReDrop ของตัวเอง รอบนี้** — Master Spec ไม่ได้ระบุชัดว่า Quote ReDrop เป็น "โพสต์เต็มรูปแบบ" ที่มี engagement ของตัวเองหรือไม่ ตัดสินใจ**ไม่ใส่**รอบนี้เพื่อลด scope (Quote ReDrop นับรวมเข้า "🔄 ReDrops" ของ Drop เดิมเท่านั้น ไม่มี like/comment แยกของตัวเอง) — ถ้า Founder ต้องการให้ Quote ReDrop เป็นโพสต์เต็มรูปแบบเหมือน Twitter Quote Tweet (มี like/comment/redrop ของตัวเองแยกออกไปอีกชั้น) ต้องแจ้งเป็น follow-up

Recommendation:
1. Schema เพิ่ม 1 ตารางใหม่ `redrops` (`drop_id` FK cascade ไปยัง `drops`, `redropper_id`, `quote_text` nullable [null=Standard, ไม่ null=Quote], partial unique index กัน Standard ซ้ำ) — ไม่แก้ตาราง `drops` เดิมเลย (นอกจาก schema เดิมไม่มีอะไรต้องแก้)
2. Design ควรใช้ pattern preview-card ที่ WYN-033 วางไว้แล้วสำหรับ Quote ReDrop's embedded original (resolve ผ่าน `DropRepository.fetchById()` เดิม ไม่ denormalize) — ลด risk/scope ให้มากที่สุด
3. `home_feed` view ต้องขยายอย่างระมัดระวัง เทียบ ranking เดิม (drops/pops) ต้องไม่เปลี่ยนพฤติกรรม — แนะนำให้ Coding เขียน regression test เทียบ `rankingScore()`/ranking output ก่อน-หลังแก้โดยเฉพาะ
4. RLS ของ `redrops` reuse `internal.is_blocked_either_way()` เดิม 2 ทิศทาง (ทั้งกับ redropper และกับเจ้าของ Drop เดิมผ่าน `exists (select 1 from drops ...)` ซึ่ง piggyback บน `drops`' SELECT policy ที่ block-aware อยู่แล้ว — ไม่ต้องเขียน block-check ซ้ำเอง)

Handoff: AI Design — ออกแบบปุ่ม/interaction ของ 🔄 ReDrop บน Drop Card (toggle ปกติ vs เปิด menu เลือก Standard/Quote), Quote ReDrop composer screen (reuse pattern ของ Create Drop เดิมเท่าที่ทำได้), preview card ของ Drop เดิมที่ฝังใน Quote ReDrop (reuse WYN-033's shared-content-preview pattern), Profile "ReDrops" tab ใหม่, Home Feed integration ของทั้ง Standard/Quote เข้ากับ ranking เดิม, schema เบื้องต้นที่แนะนำ (`redrops` table + RLS + partial unique index + notification type ใหม่ + report target_type ใหม่) ให้ AI Coding ต่อยอดได้ทันที

---

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`): ตาราง `redrops` ใหม่ (`drop_id` FK cascade ไปยัง `drops`, `redropper_id`, `quote_text` nullable [null=Standard, ไม่ null=Quote], `redrops_quote_text_length` CHECK 1-500 ตัวอักษร) — partial unique index `redrops_standard_unique` กัน Standard ซ้ำ (`where quote_text is null`) ไม่กัน Quote ซ้ำ — RLS 3 policy (SELECT กรอง block ของ redropper + piggyback บน `drops`' SELECT policy สำหรับ block ของเจ้าของเดิม, INSERT กัน posting-blocked/block เจ้าของเดิม, DELETE จำกัดเจ้าของแถวเอง) — `home_feed` view ขยายเป็น 3 branch (`content_type` ยังเป็น `'drop'` เสมอ ไม่เพิ่มค่าใหม่ — `id`/`author_id`/`image_url`/`caption`/`like_count`/`comment_count` ของ branch ที่มาจาก ReDrop ยังชี้ Drop ต้นทางเสมอ ทำให้ Like/Comment/Save และ `rankingScore()` [WYN-018] ทำงานถูกต้องอัตโนมัติไม่ต้องแก้เลย มีแค่ `created_at` ที่เปลี่ยนความหมายเป็นเวลา ReDrop) — คอลัมน์ใหม่ `redrop_count`/`redrop_id`/`redropper_*`/`quote_text` เติมท้ายลิสต์เดิมเพื่อให้ `create or replace view` ยังใช้ได้ — `reports.target_type`/`notifications.type` CHECK ขยายเพิ่ม `'redrop'` (ใช้ dynamic drop-and-recreate constraint pattern เดียวกับที่ `message_request` เคยทำ) — `submit_report()` เพิ่ม branch `'redrop'` มิเรอร์ `'club_post_comment'` — **`notify_redrop()` trigger ใหม่** (`after insert on redrops`) มิเรอร์ `notify_drop_like()` เป๊ะ แจ้งเตือนเจ้าของ Drop เดิมทุกครั้งที่มีคน ReDrop ยกเว้น self-ReDrop

**Flutter**: `Drop`/`HomeFeedItem` เพิ่ม `redropCount`/`redroppedByMe` (+ `HomeFeedItem` เพิ่ม `redropId`/`redropper*`/`quoteText`) พร้อม `toggledRedrop()`/`withExtraRedrop()` และ `HomeFeedItem.copyWith()` ใหม่ (แก้บั๊กเดิมที่ `home_feed_screen.dart`'s toggle helper เคยรีบิลด์ field ทีละตัวมือ ซึ่งจะรีเซ็ต field ใหม่ที่ลืมใส่กลับเป็นค่า default ทุกครั้งที่ Like/Save) — `DropRepository`/`HomeRepository` เพิ่ม `toggleRedrop()`/`quoteRedrop()`/`deleteRedrop()`/`fetchRedropsByUser()` + ขยาย fetch เดิมทุกจุดให้ดึง `redroppedByMe` คู่กับ `likedByMe`/`savedByMe` — `HomeRepository.fetchFollowingFeed()` เปลี่ยนจาก `.inFilter('author_id', ...)` เป็น `.or('author_id.in.(...),redropper_id.in.(...)')` (ไม่งั้น ReDrop ของคนที่ follow จะไม่โผล่ในแท็บ "ติดตาม" เลยถ้าไม่ได้ follow เจ้าของ Drop เดิมด้วย ขัดเจตนาหลักของฟีเจอร์) — ปุ่ม 🔄 ใหม่บน `HomeDropCard`/`DropDetailScreen` เปิด action sheet 2 ตัวเลือก (Standard toggle / Quote ReDrop) — `QuoteRedropScreen` ใหม่ (Screen 2) — feed card label "🔄 ReDrop โดย @username" + quote text ใน `HomeDropCard` (Screen 3) — `ProfileRedropsTab` ใหม่ (Screen 4, list ไม่ใช่ grid ตามที่ Design แนะนำ) reuse `HomeDropCard`/`HomeRepository.fetchRedropsByUser()` ตรงๆ — `ViewProfileScreen`'s TabBar เพิ่ม "ReDrops" ระหว่าง Drop/Pop

**บั๊กจริงที่พบและแก้ระหว่างเขียนโค้ด/test (เปิดเผยตามธรรมเนียมโปรเจกต์)**:
1. **ลืม implement notification trigger**: Design spec ระบุชัดว่าเจ้าของ Drop เดิมต้องได้ notification เมื่อมีคน ReDrop แต่ระหว่าง Coding ลืมเขียน trigger จริง (มีแค่คอมเมนต์ SQL sketch ใน Design doc ที่ไม่เคยถูกแปลงเป็นโค้ดจริง) — พบตอนเขียน SQL regression script เอง (ก่อนส่งถึง QA) เพราะพยายามเขียน check ยืนยัน notification แล้วพบว่าไม่มี trigger ให้ทดสอบ — **แก้แล้ว** เพิ่ม `notify_redrop()` + `redrops_notify` trigger มิเรอร์ `notify_drop_like()` เป๊ะ พร้อม CHECK15/16 ในสคริปต์ยืนยันทั้งกรณีแจ้งเตือนจริงและกรณีไม่แจ้งเตือนตัวเอง
2. **ลืม wire ปุ่มลบ Quote ReDrop**: Product spec ("ลบ Quote ReDrop ของตัวเองได้") และ `DropRepository.deleteRedrop()` มีอยู่แล้ว แต่ไม่มี UI entry point ใดๆ เรียกใช้เลย — พบระหว่างทวนงานตัวเองก่อนส่ง QA (ไล่เทียบ Acceptance Criteria กับโค้ดจริงทีละข้อ) — **แก้แล้ว** ขยาย `HomeDropCard`'s more-menu ให้โผล่เพิ่มเมื่อการ์ดเป็น ReDrop ของตัวเอง (ไม่ว่าจะเป็นเจ้าของ Drop เดิมหรือไม่) พร้อมตัวเลือก "ลบ ReDrop" แยกจาก "รายงานโพสต์" เดิม ต่อสายเข้าทั้ง `HomeFeedScreen` และ `ProfileRedropsTab` พร้อม test ใหม่ยืนยัน
3. **`_items` key collision risk**: Standard ReDrop ทำให้ Drop เดิมโผล่ซ้ำได้ 2 แถวในหน้าเดียวกัน (แถวจริง + แถว ReDrop) ที่มี `id` เดียวกัน — `ListView`'s key เดิม (`ValueKey(item.id)`) และ toggle method เดิม (`indexWhere` ด้วย id) จะชนกัน/สลับแถวผิดได้ — พบระหว่างออกแบบ ไม่ใช่ QA เจอทีหลัง — แก้เชิงป้องกันตั้งแต่แรกด้วย composite key (`'$id:${redropId ?? ''}'`) และเปลี่ยน toggle method ทั้งหมดให้รับ index แทน id โดยตรง

**Tests**: `flutter analyze` สะอาด 0 issues ทั้งโปรเจกต์ — `flutter test` **527/527 ผ่าน** (ของใหม่/แก้: `drop_test.dart` เพิ่ม `toggledRedrop`/`withExtraRedrop`/`fromMap` redrop cases 6 เคส, `home_feed_item_test.dart` เพิ่ม `fromMap`/`copyWith` redrop cases 4 เคส, `home_feed_screen_test.dart` เพิ่มกลุ่ม "ReDrop action sheet" 5 เคส [เปิด sheet, toggle standard, cancel standard, quote navigate, ลบ ReDrop ของตัวเอง], `quote_redrop_screen_test.dart` ใหม่ 4 เคส, `view_profile_screen_test.dart` เพิ่ม ReDrops tab 1 เคส + แก้ tab-count assertion เดิม 2 เคสที่คาดหวังได้ตรงตามที่ควรเปลี่ยน)

**SQL live verification**: เขียน `supabase/tests/wyn_034_redrop_test.sh` ใหม่ (21 checks) รันภายใต้ role `authenticated` จริงตาม convention เดิม ครอบ: Standard toggle lifecycle (insert/reject ซ้ำ/un-redrop/re-redrop), Quote ไม่จำกัดจำนวน+length constraint, INSERT policy ปฏิเสธ blocked-author/posting-blocked, SELECT policy แยกกรอง redropper-side vs author-side block ถูกต้อง (พิสูจน์ทั้ง 2 ทิศทางแยกกัน ไม่ใช่แค่ยืนยันว่า "ถูกซ่อน" เฉยๆ), `home_feed`'s redrop branch คงเครดิตเจ้าของเดิมจริง + `redrop_count` รวมถูกต้อง, `notify_redrop()` trigger แจ้งเตือนจริง+ไม่แจ้งเตือนตัวเอง, `submit_report()`'s redrop branch, cascade delete — **21/21 PASS** — รันซ้ำ `wyn_021`/`wyn_027`/`wyn_029`/`wyn_030`/`wyn_031`/`wyn_032`/`wyn_033` ทั้ง 7 สคริปต์เดิมอิสระ ทั้งหมดผ่าน ไม่มี cross-task regression

**Acceptance Criteria — ไล่ตรวจครบทั้ง 12 ข้อ**: กด 🔄 → โผล่ในฟีด follower พร้อม label เครดิตเจ้าของเดิมครบ ✓, กด 🔄 ซ้ำ (Un-ReDrop) → หายจริง + count ลด ✓, Quote ReDrop ใส่ข้อความได้+preview เปิด Drop เดิมได้จริง ✓, Quote ซ้ำ Drop เดิมได้หลายครั้ง ✓, ลบ Quote ReDrop ของตัวเองได้ (แก้ gap ที่พบเองแล้ว) ✓, Drop เดิมถูกลบ → cascade จริง (พิสูจน์ด้วย SQL test) ✓, ReDrop คนที่ block กันไม่ได้ทั้ง 2 ทิศทาง ✓, บล็อกฝั่งผู้ ReDrop/เจ้าของเดิมกรองแยกกันถูกต้อง ✓, Restrict/Suspend/Ban แล้ว ReDrop ไม่ได้ ✓, รายงาน Quote ReDrop แยกจาก Drop เดิมได้ ✓, เจ้าของ Drop เดิมได้ notification (แก้ gap ที่พบเองแล้ว) ✓, Profile tab "ReDrops" แสดงถูกต้อง ✓, Regression Home Feed/ranking/mute/block เดิมทำงานเหมือนเดิม (527/527 + 7 SQL scripts เดิมผ่านหมด) ✓ — **ครบทุกข้อ**

Handoff: AI QA & Security — ทำ independent QA เต็มรูปแบบต่อทันที (session เดียวกัน ตาม workflow ที่โปรเจกต์นี้ใช้มาตลอด)

---

## Independent QA — Round 1 (AI QA & Security, 2026-08-23) — PASS

**บริบท**: ทำ QA อิสระต่อจาก Coding Output ด้านบนทันที ไม่เชื่อตัวเลข/ผลลัพธ์ที่ Coding รายงานเฉยๆ — task นี้มีความเสี่ยงสูงกว่าปกติเพราะแก้ `home_feed` view ที่ WYN-007/017/018/024/028 พึ่งพาอยู่ร่วมกันหลายจุด และเพิ่ม RLS policy ใหม่ที่ต้องกรอง block 2 ทิศทางพร้อมกัน (redropper + เจ้าของเดิม) ซึ่งเป็นจุดที่ผิดพลาดได้ง่ายที่สุดของ task นี้

**สิ่งที่ทำ**:
1. อ่าน diff เต็มของ `supabase/schema.sql` ส่วน WYN-034 ทั้งหมดด้วยตัวเอง ยืนยันว่า `home_feed`'s 2 branch เดิม (drop/pop) เปลี่ยนแค่เติมคอลัมน์ต่อท้ายจริง ไม่มีการแก้เงื่อนไข WHERE/JOIN เดิมเลยแม้แต่บรรทัดเดียว — ตรวจ `rankingScore()` (`home_ranking.dart`) ด้วยตาเอง ยืนยันว่าไฟล์นี้ไม่ได้ถูกแตะเลยทั้ง session (ไม่อยู่ใน diff) สอดคล้องกับที่ Coding อ้างว่าไม่ต้องแก้
2. **ตรวจสอบ RLS block-filtering อย่างจริงจังด้วยตัวเอง ไม่เชื่อ SQL test เฉยๆ**: อ่าน `redrops`' SELECT/INSERT policy เอง ยืนยัน logic ว่า `exists (select 1 from drops d where d.id = drop_id)` piggyback บน `drops`' SELECT policy จริง (ไม่ใช่แค่คอมเมนต์ที่อ้างไว้) — สร้าง throwaway DB แยกเองนอกเหนือจาก `wyn_034_redrop_test.sh` ทดสอบ edge case ที่สคริปต์เดิมยังไม่ครอบ: block เกิดขึ้น**หลัง**ReDrop มีอยู่แล้ว (ไม่ใช่แค่ก่อน) — **รอบแรกออกแบบ scenario ผิดเอง** (ให้ bob บล็อก alice แล้วเช็คมุมมองของ viewer บุคคลที่ 3 ที่ไม่เกี่ยวข้องกับ block เลย ผลลัพธ์จึงยังเห็นอยู่ถูกต้องแล้ว แต่ไม่ได้พิสูจน์อะไรเกี่ยวกับ dynamic re-evaluation จริง) — จับได้เองจากผลลัพธ์ SQL จริงที่ขัดกับที่คาดไว้ ไม่ใช่แค่เขียน assertion ให้ผ่านเฉยๆ — แก้ scenario ให้ถูกต้อง (viewer เองเป็นคน block alice ทีหลัง จากที่เห็น redrop ของ alice อยู่ก่อนแล้ว) แล้วยืนยันว่า SELECT policy เป็น dynamic เช็คทุกครั้งจริง ไม่ใช่ snapshot ตอน insert — มองไม่เห็นทันทีหลัง block โดยไม่ต้องมีอะไรพิเศษเพิ่ม เพราะ RLS ประเมินทุก query อยู่แล้ว
3. ตรวจ `notify_redrop()` trigger ที่ Coding พบว่าลืมทำแล้วแก้เอง — อ่านโค้ดยืนยันว่า `security definer`/`search_path` ตั้งถูกต้องเหมือน `notify_drop_like()` เป๊ะ ไม่มีช่องโหว่ privilege escalation ใหม่
4. ตรวจ `HomeDropCard`'s more-menu ที่ Coding แก้เพิ่ม "ลบ ReDrop" — ยืนยันว่า `onDeleteRedrop` ผูกกับ `_isOwnRedrop` เท่านั้น (เช็คจาก `item.redropperId == current user id` ฝั่ง client) **และ** ยืนยันว่าฝั่ง DB เองก็กันซ้ำอีกชั้นด้วย DELETE policy (`auth.uid() = redropper_id`) ไม่ได้พึ่ง client-side check เป็นกลไกความปลอดภัยเดียว — ทดสอบด้วย SQL มือจริง (ไม่ใช่แค่อ่านโค้ด): จำลอง client ที่พยายาม `delete from redrops where id = <redrop ของคนอื่น>` ตรงๆ ยืนยันว่าแถวยังอยู่ครบหลังจากนั้น (RLS filter การ DELETE แบบเงียบ ไม่ error แต่ affected rows = 0 เพราะแถวเป้าหมายไม่ผ่าน `using` ของ policy เลย ไม่ใช่การโยน exception — ต่างจากบาง policy ที่ throw ในโปรเจกต์นี้ ตรงนี้เป็น silent no-op ตามธรรมชาติของ RLS DELETE)
5. ยืนยันซ้ำเรื่อง `_items` key-collision bug ที่ Coding พบและแก้เชิงป้องกันไว้ตั้งแต่แรก — เขียน manual scenario เพิ่มเอง (Standard-ReDrop Drop ของตัวเอง ให้ id ซ้ำกันแน่ๆ ในหน้าเดียว) ยืนยันว่า Like ที่การ์ดหนึ่งไม่กระทบอีกการ์ดจริงด้วย composite key + index-based toggle
6. รัน `flutter analyze`/`flutter test` อิสระเองทั้งโปรเจกต์ — 0 issues, 527/527 ผ่าน ตรงกับที่ Coding รายงาน
7. รัน `wyn_021`(5/5)/`wyn_027`(9/9)/`wyn_029`(36/36)/`wyn_030`(31/31)/`wyn_031`(29/29)/`wyn_032`(30/30)/`wyn_033`(12/12)/`wyn_034`(21/21) ทั้ง 8 สคริปต์อิสระเองอีกครั้ง — **173/173 checks ผ่านหมด** ไม่มี cross-task regression
8. ตรวจ `fetchFollowingFeed()`'s `.or()` filter fix ด้วยตา ยืนยันว่า syntax ที่ใช้ (`'author_id.in.($followingList),redropper_id.in.($followingList)'`) ถูกต้องตาม PostgREST's `or()` filter grammar จริง (ไม่ใช่แค่ compile ผ่านเฉยๆ) — ยืนยันด้วย SQL มือว่า query เทียบเท่า `or()` string นี้ให้ผลลัพธ์ตรงตามที่ควรจะเป็นเมื่อรันตรงกับ Postgres

**Regression**: ไม่มี regression ใดๆ นอกจากช่องโหว่/gap 3 จุดที่ Coding พบและแก้เองในข้อ Coding Output ด้านบนก่อนส่งถึง QA รอบนี้แล้ว — ทุก script/test เดิมผ่านหมด

**ผลลัพธ์: WYN-034 — PASS** ย้ายเข้า `.wyn/tasks/approved/` แล้ว — task แรกของ **Phase 3 (Drop Enhancement)** ที่ผ่าน QA — พร้อมส่ง AI Deploy & DevOps merge เข้า `main` ทันทีตาม merge policy ที่บันทึกไว้แล้ว
