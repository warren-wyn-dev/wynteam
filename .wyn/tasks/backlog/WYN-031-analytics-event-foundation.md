# Product Task — WYN-031

Status: backlog
Owner: AI Product Manager

Feature: Analytics Event Foundation (Home/Drop/Profile)

Goal: master prompt ขอ "Foundation สำหรับ Recommendation/Trending/Ranking/Analytics ในอนาคต" ผ่านการเตรียม event เท่านั้น — **ไม่สร้างหน้า Analytics ใดๆ ในรอบนี้** ตามที่ master prompt ระบุไว้เองชัดเจน ("ยังไม่ต้องสร้าง Analytics Page")

Target User: ทีม WYN เอง (internal) — เตรียม data foundation สำหรับ Ranking/Trending ที่ดีขึ้นในอนาคต ไม่ใช่ user-facing feature

Problem: ระบบ ranking/trending ปัจจุบัน (WYN-017/018) ใช้แค่ like/comment count เท่านั้น (ไม่มี view/dwell-time/share/bookmark signal) เพราะไม่มีการเก็บ event เหล่านี้เลย ทำให้ ranking ในอนาคตพัฒนาต่อยอดยาก

Requirements:

R1. **ตาราง `analytics_events` ใหม่**: (id, user_id nullable — nullable เพราะบาง event เช่น anonymous view อาจไม่ผูก user เสมอไป, event_type text, target_type text, target_id uuid nullable, metadata jsonb nullable, created_at) — RLS: insert ได้จาก authenticated user สำหรับ event ของตัวเองเท่านั้น (`user_id = auth.uid()` หรือ null), **ห้าม select ให้ client เห็นข้อมูลรวมของคนอื่น** (ป้องกัน privacy leak) — เก็บไว้ใช้ query ฝั่ง Product/analysis ในอนาคตเท่านั้น
R2. **Event types ที่บันทึกจริงรอบนี้** (จำกัดเฉพาะที่ master prompt ระบุและมี trigger จริงในแอปอยู่แล้ว ไม่ประดิษฐ์เพิ่ม): `profile_view`, `post_view` (Drop/Pop), `post_like`, `post_comment`, `post_share`, `post_bookmark` (save), `follow`, `unfollow` — เรียก insert แบบ fire-and-forget (ไม่บล็อก UI, ล้มเหลวได้โดยไม่กระทบ action หลัก) จากจุดที่ action เหล่านี้เกิดขึ้นจริงอยู่แล้วในโค้ด (Like/Comment/Share/Save/Follow repository call sites)
R3. **ไม่ผูกกับ ranking/trending logic ปัจจุบันในรอบนี้** — WYN-018/017 ยัง query จาก like/comment count เดิม ไม่เปลี่ยน เพื่อไม่เพิ่มความเสี่ยงให้ ranking ที่ QA ผ่านแล้ว (การนำ event เหล่านี้มาใช้จริงใน ranking formula เป็นงานแยกในอนาคตที่ต้องมี Design ใหม่)
R4. **`post_view` ต้อง debounce/dedupe ในระดับสมเหตุสมผล** (เช่น ไม่ insert ซ้ำทุกครั้งที่ widget rebuild) — ใช้ mechanism ง่ายๆ (เช่น เรียกครั้งเดียวตอนเปิด detail screen ต่อ session ไม่ใช่ทุก scroll event)

Acceptance Criteria:
- [ ] ทำ action จริง (Like/Comment/Share/Save/Follow/เปิดดู Drop detail/เปิดดู Profile คนอื่น) → มีแถวใน `analytics_events` ตรงกับ event type ที่ถูกต้อง
- [ ] Event insert ล้มเหลว (เช่น network error) → ไม่กระทบ action หลัก (Like ยังสำเร็จปกติแม้ analytics insert fail)
- [ ] ไม่มีหน้า Analytics/Dashboard ใดๆ เพิ่มในรอบนี้
- [ ] RLS ป้องกันไม่ให้ client อ่านข้อมูล analytics ของคนอื่นได้
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression

Dependencies: ไม่มี hard dependency — เป็น additive logging layer ล้วนๆ

Priority: ต่ำสุดในกลุ่ม Gap — เป็น foundation ที่ยังไม่มีอะไรมา "ใช้" ทันที (ไม่มี Analytics page, ไม่ผูกกับ ranking รอบนี้) เหมาะทำท้ายสุดหรือแทรกเมื่อมี capacity ว่าง

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Event insert ถี่เกินไป (โดยเฉพาะ `post_view`) กิน database load โดยไม่จำเป็น | ต่ำ | Debounce ตาม R4, พิจารณา batch insert ถ้าจำเป็นในอนาคต (ไม่ต้อง optimize ล่วงหน้าเกินจำเป็นตอนนี้) |
| R2 | เก็บ event แล้วไม่มีใครใช้จริง กลายเป็น dead weight | ต่ำ | Priority ต่ำสุดโดยตั้งใจ — ทำเมื่อมั่นใจว่าจะต่อยอดจริง ไม่ใช่เก็บไว้เฉยๆ ถ้า Founder ต้องการ deprioritize ทั้ง task นี้ก็ทำได้โดยไม่กระทบอะไรอื่น |

Recommendation: priority ต่ำสุด เหมาะเป็น task สุดท้ายของแผนนี้ หรือข้ามไปก่อนถ้า Founder อยากโฟกัส user-facing gap ก่อน

Handoff: ส่งต่อ AI Design เพื่อยืนยัน event_type list สุดท้าย + metadata shape แล้วส่งต่อ AI Coding
