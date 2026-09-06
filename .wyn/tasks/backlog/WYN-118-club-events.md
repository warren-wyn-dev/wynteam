# Product Task — WYN-118

Status: backlog
Owner: AI Product Manager

Feature: Club Events — นัดกิจกรรม/meetup ภายใน Club พร้อม RSVP

Goal: เพิ่มเหตุผลให้สมาชิกกลับมาเปิดแอปและมีปฏิสัมพันธ์กันนอกเหนือจากโพสต์ปกติ — ตรงกับ target user ของ WYNOS (มหาวิทยาลัย/แฟนคลับ/งานอดิเรกเฉพาะทาง ตาม `wynos-gtm-roadmap.md`) มากที่สุดในบรรดา 4 ตัวเลือก

Target User: Owner/Admin ที่ต้องการนัดกิจกรรม และสมาชิกที่ต้องการเข้าร่วม/ดูว่าใครไปบ้าง

Problem: Founder Brief เดิม (ข้อ 19) ระบุ "Community Events" เป็นฟีเจอร์ future ตั้งแต่แรก ยังไม่มีระบบนี้เลยในปัจจุบัน — Club ที่เป็นกลุ่มกิจกรรมจริง (เช่น กลุ่มถ่ายภาพ/กีฬา/มหาวิทยาลัย) ไม่มีทางนัดรวมตัวกันในแอปได้ ต้องออกไปใช้เครื่องมืออื่น (LINE/Facebook Event) ซึ่งลดเหตุผลที่จะอยู่บน WYNOS ต่อ

Requirements:
- Owner/Admin/Moderator สร้าง Event ได้ (ชื่อ, รายละเอียด, วันเวลา, สถานที่ — ออนไลน์ระบุลิงก์ / ออฟไลน์ระบุที่อยู่ข้อความอิสระ ไม่ต้องมี map integration ใน V1)
- สมาชิกกด RSVP ได้ (ไป / ไม่ไป / อาจจะไป) เห็นจำนวน+รายชื่อคนที่ตอบรับ
- Event ที่จะถึงแสดงอยู่ในหน้า Club (เช่น การ์ดด้านบน Posts tab หรือแท็บใหม่ "Events" — ให้ Design ตัดสินใจตำแหน่งที่ไม่ทำให้ Club Page แน่นเกินไป)
- แจ้งเตือนสมาชิกที่ RSVP ไว้ก่อนกิจกรรมเริ่ม (ต่อยอด WYN-116 ถ้าทำเสร็จก่อนแล้ว)

Acceptance Criteria:
- สร้าง Event ในกติกาสิทธิ์เดียวกับ Pinned Post (Owner/Admin/Moderator เท่านั้น)
- สมาชิกทุกคนของ Club (approved) เห็น Event และ RSVP ได้ ไม่ใช่สมาชิกเห็น/RSVP ไม่ได้ (ตาม trust model เดิมของ Club)
- Event ที่ผ่านไปแล้วแยกจาก Event ที่กำลังจะถึง ไม่ปนกันจนหาไม่เจอ

Dependencies: ควรทำหลัง WYN-116 (re-engagement notification) เพื่อให้แจ้งเตือน RSVP reminder ใช้ infra เดียวกันได้เลย ไม่ต้องสร้างระบบแจ้งเตือนแยก

Priority: P2 — Founder เลือกเป็นลำดับ 4 (สุดท้าย) ใน Club Growth Roadmap — scope ใหญ่ที่สุดในกลุ่ม กระทบ data model ใหม่ทั้งหมด (ตาราง Event + RSVP)

Risks: Scope คืบง่ายที่สุดในบรรดา 4 ตัว (เช่น อยากเพิ่ม reminder หลายระดับ, recurring event, check-in ณ สถานที่จริง) — ต้องคุมให้อยู่แค่ "นัด + RSVP" ตามที่ Founder Brief เดิมเตือนไว้เรื่องไม่ใส่ฟีเจอร์อนาคตจนซับซ้อนเกินจำเป็น

Recommendation: ทำเป็นลำดับสุดท้ายตามที่ Founder เลือก — รอดูว่า WYN-115/116/117 ทำให้ Club active ขึ้นจริงหรือไม่ก่อน เพราะ Events มีค่าก็ต่อเมื่อ Club มีสมาชิกที่ active มากพอจะนัดรวมตัวกันได้จริง

Handoff: AI Design (โครงสร้างหน้า Event + RSVP UI) → AI Coding (ตาราง Event/RSVP ใหม่ + RLS ตาม trust model ของ Club เดิม) → AI QA & Security
