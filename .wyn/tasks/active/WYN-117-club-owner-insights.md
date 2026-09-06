# Product Task — WYN-117

Status: active
Owner: AI Product Manager

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

## AI Design Output

ดู `.wyn/docs/design/wyn-117-club-owner-insights.md` — RPC เดียว `club_insights(p_club_id, p_days)` มิเรอร์ `admin_dashboard_metrics()` เป๊ะ (single-row aggregate, `security definer`, เช็คสิทธิ์เป็น statement แรกด้วย `coalesce(...)` กัน null-role-bypass), จำกัดช่วงเวลาแค่ 7/30 วัน (ไม่ใช่ date range อิสระ), Like/Comment รวมเป็นเลขเดียว, ปัญหา engineering หลักคือ `ClubPage`'s `TabController` length ต้องเปลี่ยนตาม role หลังโหลดข้อมูลเสร็จ — แก้ด้วยการทำ controller เป็น nullable/lazy-recreate แทน `late final`

## AI Coding Output

**Files Changed**:
- `supabase/schema.sql` — RPC `public.club_insights(p_club_id uuid, p_days int)` (owner/admin only, validate p_days in (7,30), aggregate new_members/new_posts/likes_and_comments/active_members จาก `club_members`/`club_posts`/`club_post_likes`/`club_post_comments`)
- `supabase/tests/wyn_117_club_owner_insights_test.sh` — regression 15 checks (real Postgres, RLS ผ่าน `set role authenticated`, ครอบคลุม 7d vs 30d boundary, authorization ทั้ง 3 role ที่ไม่ควรผ่าน, invalid p_days, Club ใหม่ที่ยังไม่มีกิจกรรม)
- `app/lib/features/club/data/club_insights.dart` (ใหม่) — `ClubInsights` model + `fromMap` (bigint → `(value as num).toInt()` ตาม convention เดิมของ `get_club_poll_results()`)
- `app/lib/features/club/data/club_repository.dart` — `fetchClubInsights(clubId, days)`
- `app/lib/features/club/presentation/widgets/club_insights_tab.dart` (ใหม่) — 7/30 วัน `SegmentedButton` + stat tile 2x2 grid (ไม่มีกราฟ/export ตาม scope V1)
- `app/lib/features/club/presentation/club_page.dart` — เปลี่ยน `_tabController` จาก `late final` (length คงที่ 3) เป็น nullable + `_tabControllerFor(length)` (สร้างใหม่เฉพาะตอน length เปลี่ยนจริง คง index เดิมไว้กัน `_reload()` รีเซ็ตแท็บที่ดูอยู่) เพิ่มแท็บ "Insights" ต่อท้ายเฉพาะ `myRole?.canManageClub == true` (ซ่อนทั้งแท็บ ไม่ใช่แค่ disable มิเรอร์ pattern เดิมของ `settings_screen.dart`)
- Tests ใหม่/แก้: `club_insights_tab_test.dart` (ใหม่), `club_page_test.dart` (กลุ่ม "Insights tab (WYN-117)"), `recording_club_repository.dart` fake override

**Tests**: `flutter analyze` clean, `flutter test` เต็มชุด 1281/1281 PASS, `wyn_117_club_owner_insights_test.sh` 15/15 PASS, `wyn_116`/`wyn_115`/`wyn_021` re-run ยืนยันไม่มี regression, `check_schema_ordering.py` OK

**Handoff**: ส่งต่อ AI QA & Security
