# Product Task — WYN-112

Status: active
Owner: AI Product Manager
Feature: Activation Funnel Investigation (สมัครเยอะแต่ engagement เป็นศูนย์)
Goal: หา root cause จริงจากข้อมูล ว่าผู้ใช้ที่สมัครจากลิงก์ที่แชร์ในกลุ่ม/โซเชียลกว้างๆ หลุดออกจาก funnel ตรงจุดไหนกันแน่ (สมัครไม่เสร็จ / สมัครเสร็จแต่ไม่เปิดแอปอีกเลย / เปิดแอปแต่ไม่กด action ใดๆ เลย) แทนที่จะเดา ก่อนตัดสินใจลงทุนแก้ onboarding หรือเปลี่ยนช่องทางเพิ่มเติม
Target User: N/A (internal investigation)
Problem: Founder รายงานว่า "มีคนสมัครใช้เยอะ แต่ไม่มีคนโพสต์อะไรเลย" — คุยละเอียดแล้วพบว่าไม่ใช่แค่ไม่โพสต์ แต่ **เงียบสนิทจริง ไม่ทำอะไรเลยแม้แต่ like/comment/follow** คนกลุ่มนี้มาจาก **แชร์ลิงก์ในกลุ่ม/โซเชียลกว้างๆ** (ไม่ใช่การเชิญคนรู้จักตรงๆ ตามที่ `.wyn/docs/product/wynos-gtm-roadmap.md` Phase 1 แนะนำไว้แต่แรก เพราะ Founder ไม่มีเครือข่ายคนรู้จักที่จะเชิญแบบ personal ได้) ไม่เคยมีรายงานว่าปุ่ม "โพสต์" (+) ใช้งานไม่ได้/หาไม่เจอ — ยังไม่มีข้อมูล funnel จริงมายืนยันว่าจุดหลุดอยู่ตรงไหน ทั้งที่ WYN-077 (Basic Product Analytics) deploy ขึ้น production ไปแล้วตั้งแต่ 2026-09-02 และน่าจะเก็บข้อมูลที่ต้องการไว้แล้ว
Requirements:
- ดึงข้อมูลจาก WYN-077 analytics event table ใน Supabase production (ผ่าน Supabase Management API ตาม precedent ที่ AI Deploy & DevOps เคยใช้ตรวจ production มาก่อน — ดู `.wyn/company/DECISIONS.md` entry เรื่อง WYN-071/072 P0 incident)
- สรุปตัวเลข funnel อย่างน้อย: (1) signup started vs signup completed, (2) completed signup ที่เปิดแอปอีกครั้ง (session ที่ 2) กี่ %, (3) ในจำนวนที่เปิดแอปอีกครั้ง มีกี่ % ที่ทำ action ใดๆ อย่างน้อย 1 ครั้ง (like/comment/follow/post), (4) แยกตัวเลขตามช่วงเวลาที่แชร์ลิงก์แต่ละครั้งถ้าทำได้ (เพื่อดูว่าล็อตไหน conversion ต่างกันไหม)
- ถ้าเป็นไปได้ ตรวจสอบด้วยว่ามี error/exception จริงเกิดขึ้นฝั่ง client สำหรับ session กลุ่มนี้หรือไม่ (เผื่อเป็นบั๊กที่ไม่มีใครบ่นเพราะผู้ใช้แค่เงียบแล้วเลิกใช้ ไม่ใช่ว่าไม่มีบั๊กจริง)
Acceptance Criteria:
- มีตัวเลข funnel ที่ระบุจุดหลุดชัดเจนอย่างน้อย 1 จุด (ไม่ใช่แค่ "ไม่มี action" รวมๆ)
- Founder เห็นสรุปตัวเลขและเข้าใจว่าควรลงทุนแก้ตรงไหนต่อ (onboarding ในแอป vs วิธีหาคนเข้ามา)
Dependencies: WYN-077 (Analytics — deployed แล้ว, ใช้ข้อมูลได้เลยไม่ต้องรอ dev เพิ่ม)
Priority: P0
Risks: ถ้าจำนวน sample ยังน้อยเกินไป (คนสมัครยังไม่มาก) ตัวเลขอาจไม่นิ่งพอสรุปแน่ชัด — ต้องระบุขนาด sample ไว้ในรายงานด้วยเสมอ ไม่สรุปเกินข้อมูลที่มี
Recommendation: **แก้ไข (2026-09-06)** — ไม่ต้องดึงผ่าน Supabase Management API เลย ข้อมูลที่ต้องการมีอยู่แล้วในหน้า **WYN Admin Dashboard ส่วน "การเติบโต"** (`admin/components/admin/dashboard-metrics.tsx`, ขับเคลื่อนโดย `admin_dashboard_metrics()` RPC ใน `supabase/schema.sql` ซึ่งมีคอลัมน์ `signup_conversion_pct`, `activation_pct_24h`/`activation_count_24h`, `retention_d1_pct`, `retention_d7_pct`, `top_sources` ครบตามที่ต้องการอยู่แล้ว จาก WYN-077 ที่ deploy ไปแล้ว) — Founder ที่มีสิทธิ์ admin/moderator เปิดหน้า WYN Admin ที่ใช้งานอยู่แล้วดูได้ทันที ไม่ต้องรอ AI role ใดดึงข้อมูลให้เลย เร็วกว่าและไม่ต้องแตะ production credential ใดๆ
Handoff: Founder เปิด WYN Admin Dashboard ดูส่วน "การเติบโต" เอง แล้วส่งตัวเลข (หรือภาพหน้าจอ) กลับมาให้ AI Product Manager วิเคราะห์ต่อ — ไม่ต้องส่งต่อ AI Debug Engineer/Deploy แล้ว เว้นแต่ตัวเลขที่เห็นชี้ว่ามีบั๊กจริงต้องสืบเพิ่ม (เช่น session_start ผิดปกติ)

## Note — ID Collision พบระหว่างสร้าง task นี้ (2026-09-06)

พบว่า `WYN-078` ถูกใช้ซ้ำกับ 2 งานที่ไม่เกี่ยวข้องกันเลย: `.wyn/tasks/backlog/WYN-078-invite-only-access-gate.md` (Invite-Only Access Gate ที่อ้างถึงในเอกสารนี้) และ `.wyn/tasks/approved/WYN-078-background-full-screen-fix.md` (แก้พื้นหลังเต็มจอ, เสร็จและ PASS แล้ว 2026-09-02) — เป็น class เดียวกับ "ID collision" ที่เคยพบและแก้เมื่อ 2026-08-25 ตามที่บันทึกไว้ใน `.wyn/company/CONTEXT.md` แต่รอบนี้เกิดซ้ำอีกและยังไม่มีใครแก้ไข ไม่ใช่ส่วนหนึ่งของงานนี้โดยตรง แต่ควรแจ้ง Founder ให้ทราบและพิจารณาเปลี่ยนเลขงานใดงานหนึ่งเพื่อไม่ให้สับสนในอนาคต (แนะนำเปลี่ยน invite-only-access-gate ที่ยัง backlog อยู่ เป็นเลขใหม่ เพราะ background-full-screen-fix ปิดงานไปแล้ว ไม่ควรเปลี่ยนเลขที่เสร็จแล้ว)
