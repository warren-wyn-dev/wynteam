# Product Task — WYN-027

Status: backlog
Owner: AI Product Manager

Feature: Home Feed Diversity + New Content Indicator

Goal: ปิด 2 gap เล็กแต่มีผลต่อ UX ชัดเจนที่ master prompt ระบุไว้ — (1) Ranking ปัจจุบัน (WYN-018) ไม่มีกลไกกันไม่ให้ author เดิมโผล่ติดกันหลายโพสต์รวด (2) ไม่มีทางรู้ว่ามี content ใหม่ระหว่างที่กำลังอ่าน feed อยู่ (ต้อง pull-to-refresh มั่วๆ เอง)

Target User: ผู้ใช้ WYN ทุกคนที่ใช้ Home เป็นประจำ โดยเฉพาะคนที่ follow user ที่โพสต์บ่อย

Problem: ผู้ใช้ที่ follow คนโพสต์ถี่จะเห็น feed ถูกครองโดย author เดียวหลายโพสต์ติดกันเพราะ ranking (WYN-018) ไม่มี anti-repetition term เลย และผู้ใช้ที่ค้าง feed ไว้นานไม่รู้ว่ามี Drop/Pop ใหม่มาแล้วกี่โพสต์

Requirements:

R1. **Feed Diversity**: เพิ่ม repetition-penalty term ให้ `rankingScore()` (`home_ranking.dart`) — ถ้า author เดียวกันปรากฏซ้ำภายในระยะใกล้กันในผลลัพธ์ที่จัดเรียงแล้ว (เช่น ภายใน 3 ตำแหน่งล่าสุด) ให้ลด priority ลง (interleave ใหม่แทนการตัดออก — ไม่ใช่ hide เนื้อหา แค่จัดลำดับใหม่ให้กระจาย) ทำแบบ post-processing pass หลัง sort ตาม score เดิม (ไม่ต้องแก้สูตร score หลักที่ผ่าน QA แล้ว เพิ่มเป็น step ถัดไปแทน เพื่อลดความเสี่ยง regression กับ WYN-018 ที่ lock สูตรไว้แล้ว)
R2. **New Content Indicator**: เมื่อมี Drop/Pop ใหม่ถูกโพสต์ระหว่างที่ผู้ใช้ค้างอยู่ในหน้า Home (ตรวจสอบด้วย polling เป็นระยะ เช่น ทุก 30-60 วินาที เรียก count query เบาๆ เทียบ timestamp ล่าสุดที่ผู้ใช้เห็น — **ไม่ใช่ Realtime จริงเพราะ Supabase Realtime ยังไม่เคยถูกใช้ในโปรเจกต์นี้ ห้ามอ้างว่าเป็น Realtime**) แสดง banner ลอยด้านบน feed เช่น "↑ 12 Drop ใหม่" — แตะแล้วค่อยโหลด/เลื่อนขึ้นไปดู ห้ามบังคับ feed กระโดดเองระหว่างผู้ใช้กำลังอ่าน

Acceptance Criteria:
- [ ] Follow user ที่มีหลายโพสต์ล่าสุด → feed "สำหรับคุณ" ไม่แสดง author เดียวกันติดกันเกิน 2 ตำแหน่งรวด (เมื่อมี content จาก author อื่นเพียงพอให้กระจาย)
- [ ] Diversity pass ไม่ทำให้เนื้อหาหายไป (แค่จัดลำดับใหม่ จำนวนรวมเท่าเดิม)
- [ ] มี Drop/Pop ใหม่ถูกโพสต์ระหว่างอยู่ในหน้า Home → banner "N ใหม่" ปรากฏ ไม่บังคับ scroll
- [ ] แตะ banner → โหลด content ใหม่ ไม่ duplicate กับที่มีอยู่แล้ว
- [ ] Polling ไม่กิน battery/network เกินจำเป็น (interval สมเหตุสมผล, หยุด polling เมื่อออกจากหน้า Home)
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-018 (สูตร ranking หลักต้องไม่เปลี่ยน มีแต่ post-processing step เพิ่ม)

Dependencies: WYN-018 (ranking formula ที่ lock ไว้แล้ว — R1 ต้องไม่แก้สูตรเดิม)

Priority: กลาง — คุณค่าชัดเจน ความเสี่ยงต่ำ (additive ล้วนๆ)

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Diversity pass ทำให้ ranking ที่ QA proof ไว้แล้ว (8 unit test ของ WYN-018) เพี้ยน | ต่ำ | แยกเป็น pass ใหม่หลัง sort ไม่แก้ `rankingScore()` เดิม เขียน test แยกสำหรับ diversity logic โดยเฉพาะ |
| R2 | Polling ถี่เกินไปทำให้ database load เพิ่ม | ต่ำ | ใช้ lightweight count query (ไม่ fetch เนื้อหาเต็ม) interval 30-60 วิ |

Recommendation: ทำได้อิสระ ไม่ต้องรอ WYN-024/025/026

Handoff: ส่งต่อ AI Design เพื่อออกแบบ diversity algorithm (sliding-window ขนาดเท่าไหร่) + banner UI แล้วส่งต่อ AI Coding
