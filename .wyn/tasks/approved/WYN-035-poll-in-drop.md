# Product Task — WYN-035

Status: approved
Owner: AI Product Manager

Feature: Poll ใน Drop

Goal: ให้ผู้ใช้สร้าง Drop แบบ "โพล" (คำถาม + ตัวเลือกให้โหวต) เพื่อถามความเห็น follower/ชุมชนได้ — task ที่สองของ Phase 3 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 1 ("Drop Card แสดง: ...Poll...") และ section 2 ("สร้าง Drop รองรับ: Text, รูปภาพสูงสุด 9 รูป, Caption, Hashtag, Mention, Link, **Poll**, Location")

Target User: ผู้ใช้ทุกคนที่อยากถามความเห็น/ให้ follower โหวตเลือก แทนที่จะโพสต์รูป/ข้อความเฉยๆ (เช่น "กินอะไรดี", "ชอบแบบไหนมากกว่า")

Problem: ตอนนี้ `CreateDropScreen` บังคับต้องมีรูปภาพเสมอ (`_canShare` เช็ค `_imageBytes != null`) ไม่มีทางสร้าง Drop แบบไม่มีรูปได้เลย ทั้งที่ Master Spec ระบุ Poll เป็นหนึ่งใน content ที่ Drop ต้องรองรับตั้งแต่ section แรก — ผู้ใช้ที่อยากถามความเห็นแบบเร็วๆ ต้องหารูปมาแปะเฉยๆ ไม่มีเหตุผล หรือไม่ก็ทำไม่ได้เลย

Requirements:

**สร้าง Poll**
- ในหน้า Create Drop เพิ่มปุ่ม "เพิ่มโพล" (สลับกับรูปภาพ — **Poll กับรูปภาพใช้แทนกันไม่ได้พร้อมกันในรอบนี้** เพื่อลด scope ไม่แตะระบบ multi-image ที่ยังไม่มี ตัดสินใจโดย Product ดู Risks) เมื่อเปิดโหมด Poll พื้นที่รูปภาพเดิมเปลี่ยนเป็น Poll composer แทน ไม่บังคับมีรูปอีกต่อไปสำหรับ Drop ประเภทนี้
- Caption เดิม (mention/hashtag/link ทำงานเหมือนเดิมทุกอย่าง) ทำหน้าที่เป็น "คำถามโพล" — ไม่เพิ่ม field คำถามแยก เพื่อ reuse ของเดิมทั้งหมด (mention input, hashtag parsing, 500 ตัวอักษรเดิม)
- ตัวเลือกโหวต: 2-4 ตัวเลือก (เริ่มที่ 2, กด "+เพิ่มตัวเลือก" ได้สูงสุด 4, ตัวเลือกที่ 3-4 ลบทิ้งได้ถ้าเพิ่มมาแล้วเปลี่ยนใจ ต้องเหลืออย่างน้อย 2 เสมอ) แต่ละตัวเลือกยาวได้ 1-80 ตัวอักษร ห้ามเป็นค่าว่าง/ซ้ำกันเอง
- ระยะเวลาโหวต: เลือกได้ 3 แบบเท่านั้น (ไม่ custom) — **1 วัน / 3 วัน / 7 วัน** ค่าเริ่มต้น 1 วัน — พ้นเวลาแล้วโหวตต่อไม่ได้ (โพลปิดอัตโนมัติ)
- โหวตได้แบบ**เลือกได้ตัวเดียว**เท่านั้น (single-select) รอบนี้ — ไม่ทำ multi-select (ดู Risks)

**โหวต**
- ผู้ใช้แตะตัวเลือกเพื่อโหวต 1 ครั้งต่อโพล — **เปลี่ยนใจโหวตใหม่ได้** (แตะตัวเลือกอื่น) ตราบใดที่โพลยังไม่ปิด (อัปเดตคะแนนเดิม ไม่ใช่โหวตซ้ำ)
- **เจ้าของโพลโหวตโพลตัวเองไม่ได้** (มาตรฐานเดียวกับแพลตฟอร์มโพลทั่วไป กันเจ้าของปั่นผลตัวเอง)
- ผู้ใช้ที่ถูก Restrict/Suspend/Ban (posting-blocked) หรือ block กันอยู่กับเจ้าของโพล โหวตไม่ได้ — reuse `internal.is_posting_blocked()`/`internal.is_blocked_either_way()` เดิม
- โหวตซ้ำไม่ได้ผ่านการยิง request รัว ๆ (unique ต่อ (โพล, ผู้โหวต) บังคับที่ DB, upsert เวลาเปลี่ยนใจ)

**ผลโหวต (privacy-first)**
- **โหวตเป็นความลับ — ไม่มีใครเห็นได้ว่าใครโหวตอะไร แม้แต่เจ้าของโพลเอง** เห็นได้แค่ผลรวม (จำนวน/เปอร์เซ็นต์ต่อตัวเลือก) เท่านั้น (ตัดสินใจโดย Product เพื่อความเป็นส่วนตัวของผู้ใช้ Gen Z ตรงกับ WYN Mission ที่เน้นความเป็นส่วนตัวมากกว่าแพลตฟอร์มอื่น — ไม่ใช่ Security Architecture change จึงตัดสินใจเองได้ตาม RULES.md)
- ผู้ที่**ยังไม่โหวตและโพลยังไม่ปิด** เห็นแค่ตัวเลือกเฉยๆ (ไม่เห็นผลโหวต) — พอแตะโหวตแล้วเห็นผลทันที (แบบ bar percentage ต่อตัวเลือก ตัวเลือกที่ตัวเองเลือกไฮไลต์)
- ผู้ที่**โหวตแล้ว** หรือ**เจ้าของโพล** หรือ**โพลปิดแล้ว** (หมดเวลา) เห็นผลโหวตได้เสมอไม่ว่าจะโหวตหรือไม่
- แสดงจำนวนโหวตรวมใต้โพล + เวลาที่เหลือ/"โพลปิดแล้ว" เมื่อหมดเวลา

**การมองเห็น/ทำงานร่วมกับของเดิม**
- Poll Drop เป็น `drops` row ปกติทุกอย่าง (Like/Comment/ReDrop/Share/Save/Report/ลบ/Home Feed ranking ทำงานเหมือน Drop ทั่วไปทุกจุดโดยไม่ต้องแก้โค้ดเดิม) — มีแค่การ์ดที่แสดงพื้นที่ Poll แทนรูปภาพ
- ค้นหาเจอ Poll Drop ผ่าน caption (คำถาม) ได้ทันทีเพราะ reuse `caption`/`searchByCaption` เดิม ไม่ต้องแก้ Search
- **ไม่ส่ง notification ต่อการโหวตแต่ละครั้ง** (ตัดสินใจโดย Product — ถ้าโพลไวรัลมีคนโหวตหลักพัน จะถล่ม notification เจ้าของโพลจนใช้งานไม่ได้ ต่างจาก Like/Comment/ReDrop ที่ปริมาณต่ำกว่ามาก และแพลตฟอร์มโพลส่วนใหญ่ก็ไม่แจ้งเตือนต่อโหวตเช่นกัน)
- โพลถูกลบไปพร้อม Drop เดิมเสมอ (cascade มิเรอร์ `drop_likes`/`drop_comments`/`redrops`) ไม่ว่าจะเจ้าของลบเองหรือ Moderation Remove Content

Acceptance Criteria:
- [ ] เปิด Create Drop → กด "เพิ่มโพล" → พื้นที่รูปภาพเปลี่ยนเป็น Poll composer, ไม่บังคับมีรูปอีกต่อไป
- [ ] เพิ่ม/ลบตัวเลือกได้ในช่วง 2-4 ตัวเลือก, ปุ่มแชร์กดไม่ได้ถ้าตัวเลือกว่าง/ซ้ำ/น้อยกว่า 2
- [ ] เลือกระยะเวลา 1/3/7 วันได้ ค่าเริ่มต้น 1 วัน
- [ ] แชร์ Poll Drop สำเร็จ → ปรากฏใน Home Feed/Profile เหมือน Drop ปกติ พร้อมพื้นที่ Poll แทนรูป
- [ ] ผู้ใช้ที่ยังไม่โหวต (ไม่ใช่เจ้าของ, โพลยังไม่ปิด) เห็นแค่ตัวเลือก ไม่เห็นผลโหวต
- [ ] แตะโหวต → เห็นผลโหวต (จำนวน/เปอร์เซ็นต์ต่อตัวเลือก) ทันที ตัวเลือกที่เลือกไฮไลต์
- [ ] แตะตัวเลือกอื่นเพื่อเปลี่ยนใจ → คะแนนอัปเดตถูกต้อง (ตัวเลือกเดิม -1 ตัวเลือกใหม่ +1) ไม่ใช่โหวตซ้ำ
- [ ] เจ้าของโพลกดตัวเลือกไม่ได้ (โหวตตัวเองไม่ได้) แต่เห็นผลโหวตได้เสมอ
- [ ] Restrict/Suspend/Ban แล้วโหวตไม่ได้เลย, block กันอยู่กับเจ้าของโพลโหวตไม่ได้
- [ ] ไม่มีใคร (รวมเจ้าของโพล) สืบได้ว่าใครโหวตอะไร ผ่านทั้ง UI และ query ตรงต่อ DB ด้วย role `authenticated`
- [ ] เวลาหมด (expires_at ผ่านไปแล้ว) → โหวตต่อไม่ได้, ทุกคนเห็นผลโหวตได้แม้ไม่เคยโหวต
- [ ] ลบ Poll Drop → โพล+โหวตทั้งหมด cascade หายจริง ตรวจสอบ DB ได้
- [ ] ไม่มี notification เกิดขึ้นจากการโหวต (ตรวจสอบว่าไม่มี insert เข้า `notifications` เมื่อโหวต)
- [ ] ค้นหาด้วยคำในคำถามโพล (caption) เจอ Poll Drop ได้เหมือน Drop ปกติ
- [ ] Regression: Drop ที่มีรูปภาพเดิมทุกจุด (Like/Comment/ReDrop/Save/Report/Search/Home Feed ranking) ทำงานเหมือนเดิมไม่เปลี่ยนแปลง

Dependencies: WYN-005 (Drop core), WYN-018 (Home Feed ranking — ต้องไม่กระทบ), WYN-027/WYN-029 (Block/Restrict guard เดิม reuse), WYN-034 (ReDrop — Poll Drop ต้อง ReDrop ได้เหมือน Drop ทั่วไปเพราะเป็น `drops` row ปกติ) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P1 — task ที่สองของ Phase 3 ตามลำดับ Roadmap ต่อจาก WYN-034

Risks:
- **Poll กับรูปภาพใช้พร้อมกันไม่ได้ในรอบนี้** — Master Spec เขียน Poll เป็นหนึ่งใน content ที่ "สร้าง Drop รองรับ" เรียงคู่กับรูปภาพ ไม่ได้ระบุชัดว่าต้องใช้ร่วมกันได้ในโพสต์เดียว ตัดสินใจแยกกันเพื่อไม่ต้องแตะระบบรูปภาพเดิม (ปัจจุบันบังคับ 1 รูป ไม่ใช่สูงสุด 9 ตามสเปกใหม่ — เป็น gap ที่ใหญ่กว่าขอบเขต WYN-035 เดียว) มิเรอร์พฤติกรรม Twitter Poll ที่ media กับ poll ก็แยกกันเหมือนกัน ถ้า Founder ต้องการให้แนบรูปคู่กับ Poll ได้ด้วยต้องแจ้งเป็น follow-up
- **Multi-select ไม่ทำรอบนี้** — ตัดเพื่อลด scope ให้เหมือนแพลตฟอร์มโพลส่วนใหญ่ (Twitter/IG) ที่ default เป็น single-select เช่นกัน ถ้า Founder ต้องการ multi-select ต้องแจ้งก่อนเริ่ม Design
- **ผลโหวตเป็นความลับสนิทแม้เจ้าของก็เห็นไม่ได้ว่าใครโหวตอะไร** — เป็นการตัดสินใจ product ที่เข้มกว่า IG Stories Poll (ที่เจ้าของเห็นรายชื่อคนโหวตได้) แต่ตรงกับ Twitter Poll และตรงกับ WYN Mission ("ให้ความสำคัญกับความปลอดภัย/ความเป็นส่วนตัวมากกว่าแพลตฟอร์มเดิม") — ถ้า Founder ต้องการให้เจ้าของโพลเห็นรายชื่อผู้โหวตได้ (เช่นเพื่อทำโพลแบบสำรวจภายใน Club) ต้องแจ้งเป็น follow-up และต้องพิจารณาผลกระทบ privacy ให้รอบคอบก่อน

Recommendation:
1. Schema เพิ่ม 2 ตารางใหม่: `drop_polls` (1:1 กับ `drops` ผ่าน unique `drop_id`, เก็บ `options text[]` 2-4 ตัวเลือก + `expires_at`) และ `drop_poll_votes` (`poll_id`/`voter_id`/`option_index`, unique (`poll_id`,`voter_id`) รองรับเปลี่ยนใจผ่าน upsert) — ไม่แก้ตาราง `drops` เดิมเลย เหมือนแนวทางที่ `redrops` (WYN-034) วางไว้
2. ผลโหวตต้องผ่าน SECURITY DEFINER RPC (`get_poll_results(poll_id)`) เท่านั้น ไม่เปิด raw SELECT บน `drop_poll_votes` ให้ใครนอกจากเจ้าของแถวตัวเอง (มิเรอร์ pattern RPC ของ WYN-014 Club ที่ใช้ SECURITY DEFINER สำหรับ logic ที่ RLS ตรงๆ ทำไม่ได้อย่างปลอดภัย) — RPC บังคับ policy การมองเห็นผล (โหวตแล้ว/เจ้าของ/หมดเวลา) ที่ระดับ DB ไม่ใช่แค่ซ่อนที่ UI
3. Design ควร reuse พื้นที่ที่เดิมเป็นรูปภาพ (`AspectRatio(1)` ใน `CreateDropScreen`/`HomeDropCard`/`DropDetailScreen`) ให้เป็น mode ทางเลือก แทนที่จะสร้างพื้นที่ใหม่แยกต่างหาก ลด diff/regression risk
4. Coding ต้องเขียน regression test เทียบพฤติกรรม Drop ที่มีรูปเดิมก่อน-หลังแก้ (เหมือนที่ WYN-034 ทำกับ ranking) เพราะ `Drop`/`HomeFeedItem` model จะมี field ใหม่ (nullable poll data) เพิ่มเข้าไป

Handoff: AI Design — ออกแบบ Poll composer ใน Create Drop (toggle รูป/โพล, เพิ่ม/ลบตัวเลือก, เลือกระยะเวลา), Poll display widget บน Drop Card/Detail (สถานะ "ยังไม่โหวต" vs "โหวตแล้ว/ปิดแล้ว" พร้อม percentage bar), schema เบื้องต้นที่แนะนำ (`drop_polls`/`drop_poll_votes` + RLS + `get_poll_results()` RPC) ให้ AI Coding ต่อยอดได้ทันที

---

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`): `drops.image_url` เปลี่ยนเป็น nullable (ไม่มี CHECK ข้ามตาราง — Postgres ทำไม่ได้ — invariant "มีรูปหรือมีโพล" การันตีด้วยโครงสร้างโค้ดแทน คือมีทางเดียวที่สร้าง Poll Drop ได้คือผ่าน RPC `create_poll_drop()`) — ตารางใหม่ 2 ตัว: `drop_polls` (1:1 กับ `drops` ผ่าน unique `drop_id`, `options text[]` validate ผ่าน `valid_poll_options()` immutable function [2-4 ตัวเลือก, 1-80 ตัวอักษรต่อตัว, ไม่ซ้ำกัน case-insensitive], `expires_at`) และ `drop_poll_votes` (`poll_id`/`voter_id`/`option_index`, unique (poll_id, voter_id) รองรับเปลี่ยนใจผ่าน upsert, SELECT policy จำกัดแค่แถวตัวเอง — **ไม่มีใครอ่านแถวคนอื่นได้เลยแม้แต่เจ้าของโพล**) — trigger `validate_poll_vote()` (`before insert or update`) บังคับกฎทั้งหมดที่ RLS `using`/`with check` ทำเองไม่ได้: โพลยังไม่ปิด, option_index ในขอบเขต, ไม่ใช่เจ้าของโพลเอง, ไม่ posting-blocked, ไม่ block กันอยู่กับเจ้าของ — RPC `create_poll_drop()` insert `drops`(image_url=null)+`drop_polls`+`drop_mentions` แบบ atomic มิเรอร์ `create_orders()` — RPC `get_poll_results(poll_ids[])` คำนวณผลรวมข้าม RLS (SECURITY DEFINER) แล้วบังคับ visibility rule เอง (โหวตแล้ว/เจ้าของ/หมดเวลา) ก่อนคืนค่า — batched รับ array ของ poll_id ได้ในคอลเดียว (ไม่ใช่ 1 RPC ต่อโพล) — `home_feed`/`saved_feed` เพิ่มคอลัมน์ท้าย 3 ตัว (`poll_id`/`poll_options`/`poll_expires_at`) ทุก branch (pop = null) — **ไม่แตะ `notifications`/`reports` เลย** ตามที่ Product ตัดสินใจไว้ (ไม่แจ้งเตือนต่อโหวต กัน spam, ไม่มี report target ใหม่เพราะรายงาน Drop เดิมครอบคลุมโพลอยู่แล้ว)

**Flutter**: `Drop`/`HomeFeedItem` เพิ่ม field nullable ครบ (`pollId`/`pollOptions`/`pollExpiresAt`/`pollMyVoteIndex`/`pollTotalVotes`/`pollOptionCounts`) + `imageUrl` เปลี่ยนเป็น nullable ทั้งคู่ พร้อม `votedPoll()` optimistic-update method (มิเรอร์ `toggledLike()`) — `DropRepository`/`HomeRepository` เพิ่ม `createPollDrop()`/`votePoll()` + batch fetch helper คู่ (`_fetchPollStates`: query ตรงบน `drop_poll_votes` สำหรับ "โหวตของฉัน" + RPC `get_poll_results()` แบบ batched สำหรับผลรวม) ต่อกับทุก fetch method เดิม (6 จุดใน `DropRepository`, 5 จุดใน `HomeRepository`) เหมือนที่ `_fetchLikedDropIds`/`_fetchRedroppedDropIds` ทำอยู่แล้ว — widget ใหม่ 2 ตัว: `PollCard` (แสดง/โหวต ใช้ร่วม `HomeDropCard`+`DropDetailScreen`) และ `PollPlaceholderTile` (fallback สี่เหลี่ยมสำหรับจุดที่เคยสมมติว่ามีรูปเสมอ — `DropGridTile`/`SavedGridTile`/`QuoteRedropScreen`'s preview/`TrendingTile`) — `CreateDropScreen` เพิ่ม mode toggle รูป/โพล (`SegmentedButton`) พร้อม Poll composer (เพิ่ม/ลบตัวเลือก 2-4, เลือกระยะเวลา 1/3/7 วัน) — caption field เดิม reuse เป็นคำถามโพล (mention/hashtag ทำงานเหมือนเดิมไม่ต้องแก้)

**บั๊กจริงที่พบและแก้ระหว่างเขียนโค้ด/test (เปิดเผยตามธรรมเนียมโปรเจกต์)**:
1. **`get_poll_results()`'s RETURNS TABLE column ชื่อชนกับ table column**: OUT parameter `poll_id` ของฟังก์ชันบดบัง `drop_poll_votes.poll_id` ในทุก subquery ภายในฟังก์ชันเดียวกัน (`where poll_id = dp.id` ตีความเป็นตัวแปร PL/pgSQL แทนที่จะเป็นคอลัมน์ตาราง) — พบทันทีตอนรัน SQL regression script จริงครั้งแรก (Postgres error "column reference is ambiguous" ชัดเจน) ไม่ใช่ QA เจอ — แก้ด้วยการ alias ตารางทุกจุดที่อ้างถึง (`dpv`/`dpv2`)
2. **Widget test gotcha ใหม่ (บันทึกไว้เป็น pattern)**: สร้าง `RecordingDropRepository()`/`RecordingHomeRepository()` ใหม่ตรงๆ ข้างใน `testWidgets` body (แทนที่จะสร้างใน `setUpAll`/`setUp`) ทำให้ `SupabaseClient` ข้างในสร้าง GoTrue auto-refresh `Timer.periodic` ที่ผูกกับ FakeAsync zone ของ test นั้นโดยเฉพาะ → ทดสอบ fail ด้วย "A Timer is still pending even after the widget tree was disposed" ตอน teardown — ทุก Recording repository ในโปรเจกต์นี้ (ที่เขียนไว้ก่อนหน้า) หลีกเลี่ยงปัญหานี้อยู่แล้วเพราะสร้างใน `setUpAll` เสมอ ซึ่งไม่เคยมีใครอธิบายเหตุผลไว้ตรงๆ มาก่อน — แก้โดยย้าย instance ทั้งหมดที่เพิ่มใหม่ไปสร้างใน `setUpAll` ตามธรรมเนียมเดิม
3. **Off-screen hit-test บน `PollCard`'s option**: เหมือนปัญหาเดิมที่ Like/ReDrop button เจอมาก่อน (การ์ดสูงเกิน viewport 600px ของ test) — แก้ด้วยการเรียก `InkWell.onTap` ตรงผ่าน `find.ancestor` แทน `tester.tap()` ตามแบบเดิมที่โปรเจกต์นี้ใช้อยู่แล้ว (ต้องระวังเพิ่มเติมว่า `HomeDropCard` เองก็มี `InkWell` ครอบทั้งการ์ดอยู่แล้ว ทำให้เจอ 2 ตัว ต้องเลือกตัวแรก/ใกล้สุด)

**Tests**: `flutter analyze` สะอาด 0 issues — `flutter test` **553/553 ผ่าน** (เพิ่มจาก 527 เดิม 26 เคสใหม่: `drop_test.dart` +9 [`votedPoll`/`fromMap` poll cases], `home_feed_item_test.dart` +4, `poll_card_test.dart` ใหม่ทั้งไฟล์ 6 เคส, `create_drop_screen_test.dart` +6 [Poll composer group], `drop_detail_screen_test.dart` +2, `home_feed_screen_test.dart` +3 [Poll voting group])

**SQL live verification**: เขียน `supabase/tests/wyn_035_poll_in_drop_test.sh` ใหม่ (22 checks) รันภายใต้ role `authenticated` จริง ครอบ: `create_poll_drop()` สร้าง atomic + mention notification ยังทำงาน, `valid_poll_options()` reject ทุกกรณี (ตัวเลือกเดียว/ยาวเกิน/ซ้ำ), duration นอกช่วง 1/3/7 reject, vote lifecycle (insert/เปลี่ยนใจผ่าน upsert ยังเหลือแถวเดียว/out-of-range reject), เจ้าของโพลโหวตเองไม่ได้, block กันอยู่โหวตไม่ได้, posting-blocked โหวตไม่ได้, **privacy: SELECT ตรงเห็นแค่แถวตัวเอง (พิสูจน์ด้วย count ไม่ใช่แค่เชื่อ policy)**, visibility rule ทั้ง 4 เคส (ไม่โหวต+เปิดอยู่=ซ่อน, โหวตแล้ว=เห็น, เจ้าของไม่โหวตก็เห็น, ปิดแล้ว=ทุกคนเห็น), cascade delete, `home_feed`'s poll columns, regression รูปภาพปกติยังทำงาน — **22/22 PASS** — รันซ้ำ 8 สคริปต์เดิมทั้งหมด (`wyn_021` ถึง `wyn_034`) ผ่านหมดไม่มี cross-task regression

**Acceptance Criteria — ไล่ตรวจครบทั้ง 14 ข้อ**: เปิดโหมดโพลไม่บังคับรูป ✓, เพิ่ม/ลบตัวเลือก 2-4 + validate ✓, เลือกระยะเวลาได้ ✓, แชร์สำเร็จปรากฏใน Home/Profile ✓, ยังไม่โหวตเห็นแค่ตัวเลือก ✓, โหวตแล้วเห็นผลทันที ✓, เปลี่ยนใจโหวตคะแนนอัปเดตถูกต้อง ✓, เจ้าของโหวตไม่ได้แต่เห็นผลเสมอ ✓, Restrict/block โหวตไม่ได้ ✓, ไม่มีใครสืบได้ว่าใครโหวตอะไร (พิสูจน์ด้วย SQL count ตรง) ✓, หมดเวลาโหวตไม่ได้+ทุกคนเห็นผล ✓, ลบ Poll Drop cascade ✓, ไม่มี notification ต่อโหวต (schema ไม่แตะ `notifications` เลย) ✓, ค้นหาเจอผ่าน caption ✓ — **ครบทุกข้อ**

Handoff: AI QA & Security — ทำ independent QA เต็มรูปแบบต่อทันที (session เดียวกัน ตาม workflow ที่โปรเจกต์นี้ใช้มาตลอด)

---

## Independent QA — Round 1 (AI QA & Security, 2026-08-23) — PASS

**บริบท**: ทำ QA อิสระต่อจาก Coding Output ด้านบนทันที ไม่เชื่อตัวเลข/ผลลัพธ์ที่ Coding รายงานเฉยๆ — task นี้มีความเสี่ยงด้าน privacy สูงกว่าปกติ (โหวตต้องเป็นความลับสนิทแม้แต่เจ้าของโพล) และแก้ constraint หลักของ `drops` (`image_url` เปลี่ยนเป็น nullable) ซึ่งกระทบทุก content path ที่มีอยู่แล้วในแอป

**สิ่งที่ทำ**:
1. อ่าน `supabase/schema.sql` diff ของ task นี้ทั้งหมดโดยตรง (ไม่เชื่อสรุปจาก Coding Output) ตรวจ RLS ทั้ง 2 ตาราง + trigger `validate_poll_vote()` + RPC ทั้ง 2 ตัวทีละบรรทัด
2. รัน `flutter analyze`/`flutter test` อิสระเอง (ไม่ใช่แค่เชื่อตัวเลขที่ Coding รายงาน) — ตรงกัน: 0 issues, 553/553
3. รัน SQL regression ทั้ง 9 สคริปต์ (`wyn_021` ถึง `wyn_035`) อิสระเอง — ตรงกัน: 196/196 checks ผ่านหมด
4. ไล่เทียบ Acceptance Criteria ทั้ง 14 ข้อกับโค้ดจริงทีละข้อ (ไม่ใช่แค่เชื่อ checklist ที่ Coding ทำเครื่องหมายไว้)
5. **Grep หาจุด `.imageUrl` ที่ไม่ null-safe ทั้งโปรเจกต์เองอิสระ** (ไม่เชื่อว่า Coding ตรวจครบแล้ว) — ยืนยันว่าทุกจุดที่เคยสมมติว่า Drop มีรูปเสมอ (`HomeDropCard`/`DropDetailScreen`/`DropGridTile`/`SavedGridTile`/`QuoteRedropScreen`/`TrendingTile`) มี null-check ครบจริง ไม่มีจุดตกหล่น — ตรวจว่า `HomeDropCard` ทั้ง 3 จุดที่เรียกใช้ (`home_feed_screen.dart`/`profile_redrops_tab.dart`/`hashtag_feed_screen.dart`) ต่อ `onVotePoll` ครบทั้ง 3 จุดจริง ไม่มีจุดไหนลืม
6. ตรวจ privacy เชิง adversarial โดยเฉพาะ: ยืนยันว่าแม้แต่ query แบบ GROUP BY/aggregate ตรงบน `drop_poll_votes` ก็ไม่มีทางเห็นผลรวมของคนอื่นได้ เพราะ RLS กรองเป็นรายแถวก่อน aggregate เสมอ (Postgres RLS ทำงานก่อน aggregation ไม่ใช่หลัง) — ไม่ใช่แค่เชื่อว่า RPC เป็นทางเดียว
7. ตรวจว่า `get_poll_results()` กรอง block ถูกทิศ (`not internal.is_blocked_either_way(v_me, d.author_id)`) — ยืนยันว่าโพลจากคนที่ block กันอยู่หายไปทั้งแถว ไม่ใช่แค่ผลโหวตถูกซ่อน

**พบ 2 gap จริงระหว่าง QA เอง (ไม่ใช่ QA เจอบั๊กที่ Coding พลาดทั้งหมด — 1 ใน 2 เป็นช่องโหว่ coverage ไม่ใช่บั๊ก แต่ตัดสินใจแก้ทันทีเพราะราคาถูกและสำคัญด้าน security)**:
1. **ไม่มี regression test ยืนยันว่าผู้ใช้ Restricted สร้าง Poll Drop ไม่ได้** — RPC `create_poll_drop()` มีเช็ค `is_posting_blocked()` อยู่แล้วในโค้ด (อ่านโค้ดแล้วดูถูกต้อง) แต่ Coding Output ไม่เคยพิสูจน์ด้วย SQL live test จริง (มีแค่ทดสอบ posting-blocked ตอน**โหวต** ไม่ใช่ตอน**สร้าง**) — เพิ่ม CHECK23 ยืนยันด้วย role `authenticated` จริง **PASS** ทันที (โค้ดถูกต้องอยู่แล้ว แค่ไม่เคยพิสูจน์)
2. **`valid_poll_options()` validate ความยาวตัวเลือกแบบ trim แล้ว แต่ insert ค่าที่ยังไม่ trim ลง DB จริง** — ถ้ามีใครเรียก RPC ตรงๆ (ข้าม Flutter client's `.text.trim()`) ด้วยตัวเลือกที่มี whitespace หัวท้าย ค่าที่เก็บจะมี whitespace ติดไปด้วยทั้งที่ validation "ดูเหมือน" ผ่านความยาวถูกต้อง — ไม่ใช่ security hole (แค่ data quality) แต่แก้ง่ายและราคาถูก จึงแก้ทันทีแทนที่จะปล่อยเป็น Minor: เพิ่ม `select array_agg(trim(o)) into v_options from unnest(p_options) as o;` ใน RPC ก่อน validate/insert ทั้งคำถามและตัวเลือก — รัน SQL regression ทั้ง 9 สคริปต์ซ้ำหลังแก้ **196/196 ยังผ่านหมด**

**Acceptance Criteria — ไล่ตรวจครบทั้ง 14 ข้อซ้ำอิสระ**: ตรงกับที่ Coding รายงานทุกข้อ ไม่พบข้อไหนที่ Coding อ้างผิด

**Regression**: `flutter test` 553/553 (527 เดิม + 26 ใหม่), SQL 196/196 (173 เดิมจาก 7 สคริปต์ + 23 ของ WYN-035 เอง หลังเพิ่ม CHECK23) — ไม่มี cross-task regression

**ผลลัพธ์**: **WYN-035 — PASS** ย้ายเข้า `.wyn/tasks/approved/` แล้ว — task ที่สองของ **Phase 3 (Drop Enhancement)** ที่ผ่าน QA — พร้อมส่ง AI Deploy & DevOps merge เข้า `main` ทันทีตาม merge policy ที่บันทึกไว้แล้ว
