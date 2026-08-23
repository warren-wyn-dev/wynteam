# Product Task — WYN-040

Status: backlog
Owner: AI Product Manager

Feature: Discovery Page (Trending Now / Trending Topics & Hashtags / Rising / Suggested Users / Suggested Clubs)

Goal: สร้างหน้า Discovery ใหม่ที่รวบรวมทุกช่องทาง "ค้นพบสิ่งที่กำลังเป็นที่นิยม" ของ WYN ไว้ที่เดียว — task แรกของ Phase 4 (Discovery & Trending Engine, `.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 13 "DISCOVERY": "หน้า Discovery: Trending Now, Trending Topics, Trending Hashtags, WYN Top 100 ..., Rising (บัญชีที่กำลังเติบโต), Suggested Users, Suggested Clubs" — **สโคปนี้ไม่รวม WYN Top 100** (แยกเป็น WYN-042) และ**ไม่รวม anti-manipulation scoring ใหม่** (แยกเป็น WYN-041 ซึ่งต่อยอด scoring ของ WYN-018) งานนี้คือหน้า UI/data-layer ที่ประกอบร่างจาก trending infra ที่มีอยู่แล้ว + เพิ่ม 2 concept ใหม่ (Rising, Suggested Users) ที่ยังไม่เคยมีในระบบเลย

Target User: ผู้ใช้ WYN Social ทุกคน โดยเฉพาะผู้ใช้ใหม่/ผู้ใช้ที่ยัง follow บัญชีอื่นน้อย ต้องการค้นพบเนื้อหา/บัญชี/Club ที่น่าสนใจโดยไม่ต้องรู้จักมาก่อนหรือพิมพ์คำค้นเอง

Problem: ปัจจุบันมีแค่ 2 จุดที่เกี่ยวกับ "ความนิยม" และทั้งคู่จำกัดมาก — (1) Search (WYN-009, `app/lib/features/search/presentation/search_screen.dart`) เป็น 4-tab User/Drop/Pop/Club ที่ต้องพิมพ์คำค้นเองเท่านั้น ไม่มี default/browse state ใดๆ (2) Home feed (WYN-017/018) มี `HomeRepository.fetchTrending()` (`app/lib/features/home/data/home_repository.dart`) เป็นแค่ tile row เล็กๆ 10 รายการ เรียงจาก `likeCount + commentCount` ในหน้าต่าง 48 ชม. — ไม่มีหน้าแยก ไม่มี Topics/Hashtags/Rising/Suggested Users/Suggested Clubs รวมกันที่ไหนเลยในระบบ ทำให้ Master Spec section 13 (Discovery) ยังไม่มีอยู่จริงแม้แต่ส่วนเดียว — ยืนยันแล้ว (grep ทั้ง `app/lib` และ `supabase/schema.sql`): **ไม่มี `hashtags` table, ไม่มี topic taxonomy ใดๆ, ไม่มีแนวคิด "Suggested Users"/"Rising accounts" อยู่ในโค้ดเลยแม้แต่บรรทัดเดียว**

Requirements:

**1. Trending Now — reuse `fetchTrending()` เดิม ขยายเป็นหน้าเต็ม**
- ใช้ formula เดิมของ `HomeRepository.fetchTrending()` ตรงๆ (48h window, `_trendingCandidateLimit` 100 candidate, เรียงจาก `likeCount + commentCount`) — **ไม่ต้องเพิ่ม view_count เข้าสูตรในรอบนี้** (WYN-038 view count ยังไม่เคยถูก wire เข้า ranking formula ไหนเลยในระบบ ยกให้เป็นสโคปของ WYN-041 "Trending Engine v2" ที่ระบุไว้ในชื่อ task อยู่แล้วว่าจะ "ต่อยอดจาก WYN-018")
- ต่างจาก Home tile ตรงที่ Discovery แสดงเต็มหน้า ไม่จำกัด 10 รายการ (ขยาย `_trendingResultLimit` เฉพาะ context ของ Discovery หรือทำ pagination ต่อ — ให้ AI Design/Coding ตัดสินใจ)
- Content ที่ผ่านมา RLS ของ `drops` อยู่แล้ว (การกรอง block/private-account ของ WYN-027/039 ใช้ต่อได้อัตโนมัติเพราะ query ผ่านตารางเดียวกัน) — ไม่ต้องเขียน gating logic ใหม่

**2. Trending Topics + Trending Hashtags — รวมเป็น mechanism เดียว (ตัดสินใจสโคปจาก Product)**
- **ยืนยันแล้วว่าไม่มี topic taxonomy ในระบบเลย** — ตัวอย่าง "Topics" ใน Master Spec section 12 (iPhone/มหาวิทยาลัย/กีฬา) ในทางปฏิบัติคือคำที่ผู้ใช้พิมพ์เป็น hashtag ได้อยู่แล้วทั้งหมด การสร้าง topic classification แยกต่างหาก (NLP/manual category) เป็นงานใหม่ทั้งชุดที่ไม่มีฐานรองรับเลย — **รอบนี้ให้ "Trending Topics" ใช้ข้อมูลชุดเดียวกับ "Trending Hashtags"** (แสดงเป็น section เดียว หรือสอง section ที่ backing data เดียวกันแต่ presentation ต่างกันเล็กน้อยตามที่ Design เห็นสมควร) — ถ้า Founder ต้องการ topic taxonomy แยกจริงในอนาคต (manual category/NLP) ให้เป็น task ใหม่แยกต่างหาก ไม่ใช่สโคปนี้
- **ไม่มี `hashtags` table หรือ index ใดๆ** — Hashtag feed เดิม (WYN-020, `hashtag_feed_screen.dart`) ทำงานแบบ fetch drops แล้ว extract hashtag ด้วย `extractHashtags()` ฝั่ง client ล้วนๆ ไม่มีการนับ/จัดอันดับที่ server เลย
- **แนะนำให้ reuse pattern เดียวกับ `fetchTrending()`**: ดึง candidate window ของ Drop ล่าสุด (ปริมาณ/ช่วงเวลาให้ Design/Coding กำหนดโดยอิงจาก `_trendingWindow`/`_trendingCandidateLimit` เดิม) → รัน `extractHashtags()` กับแต่ละ Drop (reuse function เดิม ไม่เขียนใหม่) → นับความถี่ต่อ hashtag → เรียงจากมากไปน้อย → top N — ไม่ต้องสร้าง SQL table/index ใหม่ในรอบนี้ (ยอมรับข้อจำกัดเรื่อง scale เหมือนที่ `fetchPopularClubs()`/`fetchNewClubs()` ของ WYN-017 เคย document ไว้ชัดเจนแล้วว่า "fetch-all-then-sort, no pagination this round, small catalog")
- กดที่ hashtag chip ใน Discovery → เข้า `HashtagFeedScreen` เดิม (WYN-020) ตรงๆ ไม่สร้างหน้าใหม่ซ้ำ

**3. Rising (บัญชีที่กำลังเติบโต) — concept ใหม่ทั้งหมด**
- นิยาม v1: บัญชีที่มีจำนวน follower ใหม่มากที่สุดในช่วงเวลาล่าสุด (แนะนำ 7 วัน ให้ Design/Coding ปรับตัวเลขได้) — ใช้ `follows.created_at` (มีอยู่แล้วในตาราง `follows`) นับจำนวนแถวที่ `following_id = <profile>` และ `created_at >= now() - interval '7 days'`
- ตั้ง minimum baseline follower ขั้นต่ำ (เช่น 5 ก่อนนับเข้า Rising ได้ ให้ Design/Coding กำหนดตัวเลขจริง) เพื่อกันบัญชีใหม่ที่มี follower หลักเดียวแต่ growth-rate สูงผิดปกติ (เช่น follower แรกของบัญชี 0→1 คน ไม่ควรติด Rising)
- **ข้อควรระวังทางเทคนิคที่สำคัญ**: หลัง WYN-039 นโยบาย SELECT ของ `follows` จำกัดไม่ให้บุคคลที่สามเห็น raw edge ของคนอื่นตรงๆ อีกต่อไป (เห็นได้เฉพาะคู่กรณี/เมื่อทั้งสองฝั่งเปิดให้ดู) — การ query นับ "follower ใหม่ในช่วง 7 วัน" ของบัญชีคนอื่น (ไม่ใช่ตัวเอง) แบบ raw select จะโดน RLS บล็อกเหมือนกัน **ต้องมี SECURITY DEFINER RPC ใหม่สำหรับนับ aggregate เท่านั้น** (มี precedent ตรงจาก WYN-039's `follower_count()`/`following_count()` ที่แก้ปัญหาเดียวกันมาแล้ว — คืนแค่ตัวเลข ไม่ผ่าน raw list) — ชื่อ/รายละเอียด RPC ให้ AI Design ออกแบบ
- Exclude: บัญชีตัวเอง, บัญชีที่ follow อยู่แล้ว, บัญชีที่ block กันอยู่ (`internal.is_blocked_either_way`) — Rising ของบัญชี Private แสดงได้ปกติ (เห็นแค่ identity เหมือนที่ Search User results ทำกับบัญชี Private อยู่แล้ว ตาม WYN-039)

**4. Suggested Users — concept ใหม่ทั้งหมด**
- นิยาม v1 (เรียบง่าย ไม่มี ML/personalization ในรอบนี้): เรียงจาก follower count มาก→น้อย (reuse `follower_count()` RPC ของ WYN-039 ตรงๆ) ในกลุ่มบัญชีที่ยังไม่ได้ follow, ไม่ใช่ตัวเอง, ไม่ได้ block/ถูก block กัน, ไม่ได้ mute กัน (WYN-028)
- Pattern การดึงข้อมูลให้เดินตามแนวเดียวกับ `fetchPopularClubs()`/`fetchNewClubs()` ของ WYN-017 (fetch candidate set แล้วเรียงใน Dart) — ถ้า performance เป็นปัญหาจริงจากจำนวน user มาก ให้ Design/Coding พิจารณาทำ batched RPC แทนการเรียก `follower_count()` ทีละคน (N+1 query) — ตัดสินใจสุดท้ายเป็นของ Design/Coding
- แสดง identity ของบัญชี Private ได้ปกติ (เหมือน Search/Rising) — ปุ่ม action ใช้ 3-state Follow button เดิมจาก WYN-039 ตรงๆ (Follow/ขอติดตามแล้ว/กำลังติดตาม) ไม่สร้างปุ่มใหม่

**5. Suggested Clubs — reuse `fetchPopularClubs()` เดิม**
- ใช้ `ClubRepository.fetchPopularClubs()` (WYN-017) ตรงๆ ไม่ต้องเขียนใหม่ — เงื่อนไข exclude เดิม (ไม่แสดง Club ที่ตัวเองเป็นสมาชิกอยู่แล้ว) ยังใช้ได้ตามเดิม
- ปุ่ม action ใช้ Join/Request-to-join เดิมจาก WYN-014/015 ตรงๆ

**6. Entry Point — ไม่มี Bottom Nav ว่างให้เพิ่ม tab ใหม่**
- WYN-024 (Bottom Nav V1.0.0 Restructure) ล็อก 5 tab แล้ว (Home/Search/Drop/Notifications/Profile) ไม่มีช่องว่างสำหรับ Discovery tab ใหม่ และ Founder เพิ่งยืนยันโครงสร้างนี้เป็น "สูงสุด บล็อก UX ทุกอย่าง" — **ไม่เปิดเผื่อแก้ bottom nav ในรอบนี้**
- **ข้อเสนอแนะ (Product's Recommendation, ให้ Design ตัดสินใจสุดท้าย)**: ให้ Discovery เป็น default/empty-state ของหน้า Search (WYN-009, `search_screen.dart`) — ตอนเปิดหน้า Search แล้วยังไม่พิมพ์อะไร แสดงเนื้อหา Discovery (Trending Now/Topics-Hashtags/Rising/Suggested Users/Suggested Clubs) แทนที่จะเป็นหน้าว่างเปล่าเหมือนปัจจุบัน พอเริ่มพิมพ์คำค้นค่อยสลับเป็น 4-tab ผลลัพธ์การค้นหาเดิม — mirrors pattern มาตรฐานที่ผู้ใช้คุ้นเคย (Instagram Explore ใน tab Search เดียวกัน) และไม่ต้องแตะ Bottom Nav เลย

Acceptance Criteria:
- [ ] เปิดหน้า Search โดยยังไม่พิมพ์คำค้น เห็นเนื้อหา Discovery ครบ 5 ส่วน (Trending Now, Trending Topics/Hashtags, Rising, Suggested Users, Suggested Clubs) แต่ละส่วนมี "ดูเพิ่มเติม"/pagination ถ้าเนื้อหายาว
- [ ] เริ่มพิมพ์คำค้นในหน้า Search: สลับกลับเป็น 4-tab ผลลัพธ์การค้นหาเดิม (WYN-009) ไม่มี regression
- [ ] Trending Now: รายการที่แสดงตรงกับ formula เดิมของ `fetchTrending()` (จำนวน like+comment, หน้าต่าง 48 ชม.) ไม่มีบัญชี Private ที่ไม่ได้ follow/ไม่มี Drop จากบัญชี block หลุดเข้ามา
- [ ] Trending Topics/Hashtags: hashtag ที่แสดงเรียงตามความถี่ในช่วงเวลาที่กำหนดจริง กดแล้วเข้า `HashtagFeedScreen` เดิมถูกต้อง
- [ ] Rising: บัญชีที่แสดงมี follower ใหม่ในช่วง 7 วันจริงตามที่กำหนด ไม่รวมบัญชีที่ follow อยู่แล้ว/block กัน/ต่ำกว่า baseline ขั้นต่ำ — third-party (คนที่ไม่ใช่เจ้าของบัญชี) เห็นตัวเลข Rising ได้โดยไม่ต้องผ่าน raw follows list (ยืนยันด้วย RLS/RPC test)
- [ ] Suggested Users: เรียงจาก follower count มาก→น้อยถูกต้อง ไม่รวมบัญชีที่ follow อยู่แล้ว/ตัวเอง/block/mute กัน ปุ่ม Follow ทำงาน 3-state ถูกต้องตรงกับ WYN-039
- [ ] Suggested Clubs: รายการตรงกับ `fetchPopularClubs()` ไม่รวม Club ที่เป็นสมาชิกอยู่แล้ว ปุ่ม Join ทำงานถูกต้อง
- [ ] Regression เต็มชุด: Search 4-tab เดิม/Home feed+Trending tile เดิม/Hashtag feed เดิม/Club discovery เดิม/Follow 3-state button/Block/Mute/Private Account gating ทำงานเหมือนเดิมทุกอย่าง ไม่มี regression จาก task นี้

Dependencies: WYN-009 (Search screen, entry point), WYN-017 (`fetchPopularClubs()`/`fetchNewClubs()`), WYN-018 (`fetchTrending()`/`rankingScore()` base formula), WYN-019 (feed tab pattern), WYN-020 (`extractHashtags()`, `HashtagFeedScreen`), WYN-024 (Bottom Nav — ห้ามแก้), WYN-027 (Block — `is_blocked_either_way`), WYN-028 (Mute), WYN-039 (Private Account RLS gating, `follower_count()` RPC precedent, 3-state Follow button)

Priority: P1 — task แรกของ Phase 4 (Discovery & Trending Engine) ตาม roadmap, เริ่มต่อทันทีหลัง Phase 3 ปิดจบ (WYN-039 merge เข้า main แล้ว 2026-08-23)

Risks:
- **"Trending Topics" ไม่มี taxonomy รองรับจริง** — ตัดสินใจรวมกับ Hashtags ไว้แล้วข้างบนพร้อมเหตุผล ถ้า Founder ไม่เห็นด้วยกับการตัดสินใจนี้ต้องแจ้งก่อน Design เริ่มงาน
- **Rising ต้องพึ่ง RPC ใหม่ (aggregate follower-growth count) เพราะ WYN-039 จำกัด raw `follows` select ไปแล้ว** — ถ้า Design/Coding มองข้ามจุดนี้จะ query ตรงแล้วโดน RLS บล็อกเงียบๆ (คืนค่าว่างเปล่าแทน error) ทำให้ Rising section ว่างเปล่าโดยไม่รู้สาเหตุ
- **Performance ของ fetch-all-then-sort pattern** (สืบทอดจาก WYN-017) ยิ่งมี section เพิ่มพร้อมกัน 5 ส่วนในหน้าเดียว ยิ่งเสี่ยงช้าถ้าจำนวน user/drop เติบโต — ยอมรับ trade-off นี้ในรอบนี้เหมือนที่ WYN-017 เคยยอมรับมาก่อน แต่ให้ Design/Coding พิจารณา lazy-load ต่อ section (ไม่โหลดทุก section พร้อมกันตอนเปิดหน้า)
- **Discovery ดึงข้อมูลจากตารางเดียวกับ Home/Search/Hashtag/Club ทั้งหมด** — ถ้า query ผิดจุดเดียว (ไม่ผ่าน RLS ปกติ, เช่น ใช้ SECURITY DEFINER function เดิมผิดที่) เสี่ยง privacy leak ซ้ำแบบเดียวกับที่เคยเกิดใน WYN-027/WYN-039 — เน้น QA ให้ตรวจทุก query point ของ Discovery ว่าผ่าน RLS ปกติจริง ไม่ bypass

Recommendation: เริ่มจาก Requirement 5 (Suggested Clubs, reuse ตรงๆ ไม่มีความเสี่ยงใหม่) และ Requirement 1 (Trending Now, reuse เกือบทั้งหมด) ก่อนเป็นฐานให้ทีมคุ้นกับโครง Discovery page ก่อน แล้วค่อยทำ Requirement 2 (Hashtags/Topics, งานใหม่แต่ไม่แตะ RLS) ตามด้วย Requirement 4 (Suggested Users, งานใหม่ + reuse RPC เดิม) และปิดท้ายด้วย Requirement 3 (Rising, งานใหม่ทั้งหมด + ต้องออกแบบ RPC ใหม่ เสี่ยงสุด) — Entry Point (Requirement 6) ต้องตัดสินใจให้จบก่อนเริ่มเขียน UI เพราะกระทบโครง `search_screen.dart` ทั้งไฟล์

Handoff: AI Design — ออกแบบ layout หน้า Discovery ทั้ง 5 section (นับรวม Topics+Hashtags เป็น section เดียวหรือสองก็ได้ตามที่เห็นสมควร), ตำแหน่ง entry point สุดท้าย (แนะนำ default-state ของ `search_screen.dart` ตาม Requirement 6), schema/RPC ใหม่สำหรับ Rising (Requirement 3, ต้องเป็น SECURITY DEFINER ตาม precedent WYN-039), และผังการดึงข้อมูลของแต่ละ section ว่า reuse ของเดิมตรงไหนบ้าง (Trending Now/Suggested Clubs) vs สร้างใหม่ตรงไหน (Hashtags aggregation/Rising/Suggested Users)
