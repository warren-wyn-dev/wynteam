# Product Task — WYN-018

Status: backlog
Owner: AI Product Manager

Feature: Home Feed Ranking ("For You" algorithm — จัดลำดับ Feed ตามความเหมาะสม)

Goal: แทนที่ Home feed หลัก (ปัจจุบัน chronological ล้วนๆ จาก WYN-007's `home_feed` view) ด้วยการจัดลำดับที่ผสมสัญญาณตามที่ Founder ระบุใน "WYN — Feed & Club Update" spec ข้อ 1: ล่าสุด + กำลังได้รับความนิยม + Content ที่ผู้ใช้มีส่วนร่วม + Content จากคน/Club ที่ผู้ใช้ติดตาม

Target User: ผู้ใช้ WYN Social ทุกคน โดยเฉพาะผู้ใช้ที่ follow คนเยอะ/join Club เยอะ ที่ chronological ล้วนๆ ทำให้ content ที่สนใจจริงจมหายไปเร็ว

Problem: `home_feed` view ปัจจุบัน `ORDER BY created_at DESC` เท่านั้น ไม่มีการถ่วงน้ำหนักด้วย engagement หรือ following/club-membership เลย — Founder ต้องการ Feed ที่ "ฉลาดขึ้น" แต่ระบุชัดว่าห้ามลอก algorithm ของแพลตฟอร์มอื่นตรงๆ (implicit จาก DS-001's "ห้ามลอก Layout" — เช่นเดียวกันควรไม่ลอก logic แบบ black-box)

Requirements:

R1. นิยาม scoring formula แบบโปร่งใส ตรวจสอบได้ ไม่ใช่ black-box ML — เสนอ weighted score จาก: recency decay + engagement rate (like+comment ต่อเวลาที่โพสต์) + following/club-membership boost (เนื้อหาจากคน/Club ที่ follow/join ได้คะแนนเพิ่ม) — ต้องผ่าน Design review ก่อน lock สูตรจริง เพราะมีผลต่อพฤติกรรมผู้ใช้ทั้งแอป
R2. Ranking ต้องคำนวณได้แบบ query-time (ไม่ใช่ batch job แยก) เพื่อคง pagination pattern เดิมของ `home_feed` (infinite scroll, page-based) — ประเมิน SQL window function/computed column แทน materialized view ก่อน เพราะ engagement เปลี่ยนตลอดเวลา
R3. **ต้องเก็บ chronological mode เดิมไว้เป็นทางเลือก** ไม่ลบทิ้ง — เสนอ toggle คล้าย ClubSection's "สำหรับคุณ"/"จาก Club ของคุณ" (WYN-015) หรือรวมเข้าเป็นส่วนหนึ่งของ tab structure เดียวกับ WYN-019 (Drop's For You/Following/Latest) เพื่อความสม่ำเสมอของ UX ทั้งแอป — Design ตัดสินใจ
R4. ห้ามแก้ RLS ของ `drops`/`pops`/`clubs`/`club_posts` เดิม — เป็นแค่การเรียงลำดับผลลัพธ์ที่ RLS อนุญาตให้เห็นอยู่แล้ว ไม่ใช่การเปลี่ยน visibility

Acceptance Criteria:
- [ ] Home feed จัดลำดับผสม recency+engagement+following/club-boost ตาม formula ที่ Design ล็อกไว้ (มีเอกสารสูตรชัดเจน ตรวจสอบได้)
- [ ] Pagination (infinite scroll) ยังทำงานถูกต้อง ไม่มี item ซ้ำ/หายเมื่อเลื่อนต่อเนื่อง (regression risk สูงสุดของงานนี้)
- [ ] มีทางกลับไปดู chronological ("ล่าสุด") ได้เสมอ
- [ ] Performance: query ranking ต้องไม่ทำให้ Home โหลดช้าลงอย่างมีนัยสำคัญเทียบกับ chronological เดิม (ตั้ง benchmark ก่อน/หลัง)
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับ WYN-007/WYN-015

Dependencies: แนะนำทำหลัง WYN-017 (Trending/Recommended sections) เพราะทั้งสองงานแตะ "การจัดลำดับ/คัดสรร content ใน Home" คล้ายกัน ทำ WYN-017 ก่อนจะได้ engagement-query ที่ reuse ต่อยอดเป็นส่วนหนึ่งของ ranking formula ได้เลย

Priority: กลาง — คุณค่าสูงแต่ความซับซ้อน/ความเสี่ยงสูงสุดในกลุ่มนี้ (แตะ feed หลักที่ผ่าน QA แล้ว, ต้อง benchmark performance, ต้อง lock formula ที่กระทบ UX ทั้งแอป)

Risks: Ranking formula ที่ออกแบบผิดอาจทำให้ feed รู้สึก "สุ่ม"/ไม่ตรงความคาดหวังผู้ใช้ ต้องมี fallback (chronological) เสมอ และควรวัดผลหลัง deploy จริง (ยังไม่มี infra วัด engagement metrics เชิงลึกในโปรเจกต์นี้ — เป็น UNKNOWN ที่ต้องคุยกับ Founder ว่าจะวัดผลยังไง)

Recommendation: ทำหลัง WYN-017 และ WYN-019 (Drop tabs) เพราะทั้งสองงานนั้นเสี่ยงต่ำกว่าและให้คุณค่าเร็วกว่า ส่วนงานนี้ควรมี Design spec แยกเป็นเอกสารเฉพาะก่อนเริ่ม Coding เพราะกระทบ UX หลักของทั้งแอป

Handoff: AI Design ต้อง lock scoring formula เป็นเอกสารก่อน (`.wyn/docs/design/wyn-018-home-feed-ranking.md`) แล้วให้ Founder เห็นตัวอย่างผลลัพธ์ก่อนส่งต่อ AI Coding — งานนี้มีผลต่อพฤติกรรมผู้ใช้ทั้งแอป จึงควรให้ Founder approve สูตรก่อนแม้จะไม่ใช่ Major Architecture change ตาม RULES.md เป๊ะๆ
