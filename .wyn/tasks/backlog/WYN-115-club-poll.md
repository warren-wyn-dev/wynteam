# Product Task — WYN-115

Status: backlog
Owner: AI Product Manager

Feature: Club Poll — ให้สมาชิกสร้างโพลภายในโพสต์ของ Club ได้

Goal: เพิ่ม engagement ในกลุ่มด้วยวิธีที่ต้นทุนต่ำที่สุด (ถามความเห็น/โหวตกิจกรรม/ตัดสินใจร่วมกันของ Club) โดยต่อยอดระบบ Poll ที่มีอยู่แล้วบน Drop (WYN-035, `create_poll_drop()`) แทนที่จะสร้างระบบโพลใหม่ทั้งหมด

Target User: สมาชิก/Owner/Admin ของ Club ที่ต้องการถามความเห็นหรือให้สมาชิกโหวตเรื่องใดเรื่องหนึ่ง

Problem: ตอนนี้ Club Post รองรับแค่ Text/Image/Link (ตาม Founder Brief เดิม) — ไม่มีวิธีให้สมาชิกโหวต/แสดงความเห็นแบบมีตัวเลือกได้เลย ต้องพิมพ์คอมเมนต์แยกกันเอง ซึ่งนับผลไม่ได้และอ่านยากเมื่อมีคนตอบเยอะ

Requirements:
- เพิ่มตัวเลือก "สร้างโพล" ใน `CreateClubPostScreen` (คู่ขนานกับ text/image ที่มีอยู่ ไม่ใช่แทนที่)
- โครงสร้างข้อมูล/กติกาเดียวกับ Poll ของ Drop ให้มากที่สุด (จำนวนตัวเลือกขั้นต่ำ-สูงสุด, โหวตได้ครั้งเดียว, เปลี่ยนใจได้ก่อนปิดโพล ฯลฯ) — ใช้ pattern เดิมที่ผ่าน QA แล้วจาก WYN-035 ไม่ออกแบบกติกาใหม่โดยไม่มีเหตุผล
- ผลโหวตแสดงเฉพาะสมาชิกที่ approved ของ Club นั้น (ตาม trust model ของ Club ที่มีอยู่แล้ว)
- Pinned Post ที่เป็นโพลได้ตามปกติ (ไม่ต้องมีข้อจำกัดพิเศษ)

Acceptance Criteria:
- สมาชิกที่ approved ของ Club สร้างโพลในโพสต์ Club ได้ พร้อมเห็นผลโหวตแบบเรียลไทม์เหมือน Poll บน Drop
- สมาชิกที่ pending/ไม่ใช่สมาชิกของ Club private เห็น/โหวตโพลไม่ได้ (ตาม RLS เดิมของ Club post)
- โหวตซ้ำ/เปลี่ยนใจทำงานตรงกับกติกาเดียวกับ Poll ของ Drop เป๊ะ (regression test อ้างอิงชุดเดิมของ WYN-035 ปรับมาใช้กับ Club)

Dependencies: ไม่มี — Poll infra (WYN-035) deploy อยู่แล้ว, ทำคู่ขนานกับ WYN-114 ได้ (ไม่เกี่ยวข้องกัน)

Priority: P1 — Founder เลือกให้เริ่มก่อนใน Club Growth Roadmap (effort ต่ำสุดในกลุ่ม 4 ตัว)

Risks: ต่ำ — data model/RLS pattern มีต้นแบบที่ผ่าน QA แล้ว (Drop Poll) ความเสี่ยงหลักคือถ้า Design ตัดสินใจกติกาโพลของ Club ให้ต่างจาก Drop โดยไม่มีเหตุผลรองรับ (เช่น อนุญาต multi-select) จะเพิ่ม scope โดยไม่จำเป็น

Recommendation: เริ่ม Design ได้เลย — ให้ AI Design ตรวจ `create_poll_drop()`/Poll UI ของ Drop ให้ครบก่อนออกแบบ เพื่อ reuse ให้มากที่สุดแทนออกแบบใหม่

Handoff: AI Design → AI Coding → AI QA & Security
