# Product Task — WYN-117

Status: active — Design เสร็จแล้ว, พร้อมเข้าคิว Coding ปกติ (ไม่มี dependency ต้องรอ)
Owner: AI Product Manager → AI Design

Feature: Club Owner Insights — หน้าสรุปสถิติการเติบโต/engagement สำหรับ Owner/Admin ของ Club

Goal: จูงใจให้เจ้าของชุมชน (โดยเฉพาะ micro-influencer/creator ที่ `wynos-gtm-roadmap.md` Phase 3 วางแผนจะไปชักชวน) เห็นคุณค่าของการสร้าง Club บน WYNOS ชัดเจน ผ่านข้อมูลการเติบโตที่จับต้องได้ — เหมือนที่ Facebook Group Insights/Discord Server Insights ให้ Admin เห็น

Target User: Owner และ Admin ของ Club (ไม่ใช่ Moderator ทั่วไป — ตาม permission tier ที่มีอยู่แล้ว `canManageClub`)

Problem: ตอนนี้ Owner/Admin เห็นแค่จำนวนสมาชิกปัจจุบัน (memberCount) ไม่มีทางเห็นว่า Club ตัวเอง "กำลังโต" หรือ "ซบเซา" เลย — ไม่มีข้อมูลช่วยตัดสินใจว่าควรโพสต์บ่อยขึ้น/เปลี่ยนกลยุทธ์ ทำให้เจ้าของ Club ที่ทำคอนเทนต์จริงจัง (target ของ GTM Phase 3) ไม่มีเหตุผลจับต้องได้ว่าจะลงทุนเวลาสร้างชุมชนที่ WYNOS ต่างจาก platform อื่น

Requirements:
- สถิติย้อนหลัง 7/30 วัน (เลือกช่วงได้): สมาชิกใหม่, จำนวนโพสต์, จำนวน Like/Comment รวม, สมาชิกที่ active (โพสต์/Like/Comment อย่างน้อย 1 ครั้งในช่วงที่เลือก)
- เข้าถึงได้จากหน้า Club (ปุ่ม/แท็บใหม่ "Insights" มองเห็นเฉพาะ Owner/Admin ตาม permission ที่มีอยู่แล้ว)
- ไม่ต้องมี export/กราฟซับซ้อนใน V1 — ตัวเลขสรุปพอ (ตาม Founder Brief เดิมข้อ 19 ที่เตือนไม่ให้ over-engineer ฟีเจอร์อนาคต)

Acceptance Criteria:
- Owner/Admin ของ Club เปิด Insights เห็นตัวเลขที่ตรงกับข้อมูลจริงใน `club_members`/`club_posts`/`club_post_likes`/`club_post_comments`
- Moderator/Member ทั่วไปเข้าถึงหน้านี้ไม่ได้ (403 หรือไม่เห็นปุ่มเลย ตาม pattern การซ่อน UI ที่มีอยู่แล้วในแอป)
- Club ที่ยังไม่มีข้อมูล (Club ใหม่) แสดง 0 ทุกช่องอย่างถูกต้อง ไม่ error/crash

Dependencies: ไม่มี dependency ตรงกับ WYN-114/115/116 — ทำคู่ขนานได้ แต่ effort สูงกว่า (ต้อง aggregate query ใหม่หลายตัว)

Priority: P2 — Founder เลือกเป็นลำดับ 3 ใน Club Growth Roadmap

Risks: Query aggregate อาจหนักถ้า Club มีโพสต์/สมาชิกจำนวนมาก — ควรออกแบบให้ query ที่ DB level (RPC/materialized ถ้าจำเป็น) ไม่ใช่ดึงข้อมูลดิบมาคำนวณฝั่ง client เหมือนที่เคยเป็นบั๊กประเภทนี้มาก่อนในระบบ (ดู pattern การใช้ RPC/aggregate ของ Admin Dashboard WYN-050/077 เป็นตัวอย่าง)

Recommendation: ทำหลัง WYN-115/116 เพราะ effort สูงกว่าและยังไม่มี Club ที่ active มากพอจะเห็นคุณค่าของ insight จริงในตอนนี้ (ฐานผู้ใช้ยังเล็กมากตาม WYN-112) — รอจน Phase 1 GTM มี Club ที่มีสมาชิก/โพสต์จริงมากพอก่อนน่าจะเห็นประโยชน์ชัดกว่า

Handoff: AI Design (โครง insights, เลือกช่วงเวลา) → AI Coding (เขียน RPC aggregate ใหม่, อ้าง pattern เดิมของ Admin Dashboard) → AI QA & Security

---

## AI Design — ผลงาน (2026-09-06)

Design เต็มรูปแบบอยู่ที่ `.wyn/docs/design/wyn-117-club-owner-insights.md` — ทางเข้าเป็นแถวใหม่ใน "..." เมนูของ ClubPage (ไม่ทำ tab ใหม่ เพราะเป็น staff-only 100% ต่างจาก 4 tab ที่ทุกสมาชิกเข้าถึงได้), หน้า Insights ใช้ `SegmentedButton` เลือก 7/30 วัน (reuse widget เดียวกับ WYN-115's poll duration) + stat tile ใหม่ 1 ตัว (`_InsightTile`) ที่ยืมแนวคิดจาก Admin Dashboard's `StatCard` (ตัวเลขเปล่า ไม่มีกราฟ ไอคอนเป็นแค่ตกแต่งไม่ใช่สัญญาณ) แต่เขียนใหม่เป็น Flutter widget ด้วย WYNOS token เพราะ Admin เป็นคนละ stack เทคนิค

**Handoff (Design → Coding)**: ไม่มี dependency ต้องรอ ทำได้เมื่อถึงคิวปกติ — RPC aggregate ต้องนับที่ DB level (ตาม Risks ที่ Product เตือนไว้) และ RLS ต้องบังคับ Owner/Admin จริงไม่ใช่แค่ซ่อน UI
