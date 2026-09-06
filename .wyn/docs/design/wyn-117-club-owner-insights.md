# Design — WYN-117 (Club Owner Insights)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-117-club-owner-insights.md` — อ่านก่อนเริ่ม
> Product สั่งให้ reuse pattern ของ Admin Dashboard (WYN-050/077, `admin_dashboard_metrics()`) — RPC เดียว aggregate ที่ DB layer ไม่ดึงข้อมูลดิบมาคำนวณฝั่ง client

## สรุปการสำรวจของเดิม (ไม่ต้องคิดใหม่)

1. **`admin_dashboard_metrics()`** (`supabase/schema.sql`) เป็นต้นแบบเป๊ะ: `returns table(...)` แถวเดียว, `security definer`, เช็คสิทธิ์เป็น statement แรกในตัวฟังก์ชันด้วย `coalesce(role, '') not in (...)` (ป้องกัน NULL-role-bypass แบบเดียวกับที่ WYN-050 เคยเจอ), นับด้วย `count(*)` เฉยๆ ซึ่ง return `0` โดยอัตโนมัติเมื่อไม่มีข้อมูล (ไม่ต้อง coalesce แยก)
2. **`canManageClub` = owner+admin เท่านั้น** (`ClubMemberRole` extension, `club_member.dart`) — ไม่รวม moderator ตรงกับ Target User ของ Product spec เป๊ะ — DB-side ใช้ idiom เดียวกับ `approve_club_member()`: `coalesce(public.club_role(p_club_id, auth.uid()), '') not in ('owner', 'admin')`
3. **`club_post_likes`/`club_post_comments` มี `created_at` อยู่แล้วทั้งคู่** — ไม่ต้องแก้ schema เพิ่ม กรอง "ในช่วง N วัน" ได้ตรงๆ
4. **ไม่มี Dart model สำหรับ aggregate stats แบบนี้มาก่อน** (Admin Dashboard เป็น Next.js แยกต่างหาก ไม่ใช่ Flutter) — WYN-117 เป็นจุดแรกที่นำ pattern นี้เข้า Flutter จริง ใช้ shape เดียวกับ `ClubMember.fromMap`/`Club.fromMap` ที่มีอยู่แล้ว (const constructor + `factory fromMap`)

## จุดที่ต้องตัดสินใจใหม่

### 1. ขอบเขต Metric (4 ตัวตาม Requirements เป๊ะ ไม่เพิ่ม)
`new_members` (สมาชิกใหม่ที่ `status='approved'` ในช่วง — สมาชิกที่ pending/banned ไม่นับ ตรงกับที่ `countMembers()` เดิมกรองอยู่แล้ว), `new_posts`, `likes_and_comments` (ผลรวมเดียว ไม่แยก 2 ตัวเลข ตาม wording ของ Requirements "จำนวน Like/Comment รวม"), `active_members` (distinct ผู้ที่โพสต์/Like/Comment อย่างน้อย 1 ครั้ง — union 3 แหล่งเดียวกับที่ `admin_dashboard_metrics()`'s `actions` CTE ทำ)

### 2. ช่วงเวลา: 7 หรือ 30 วันเท่านั้น (ไม่ใช่ arbitrary range)
Requirements บอก "เลือกช่วงได้" — ตัดสินใจจำกัดแค่ 2 ค่า (`p_days in (7, 30)`, validate ใน RPC เหมือนที่ `create_poll_club_post()` validate duration เป็น 1/3/7 เท่านั้น) ไม่ใช่ date picker อิสระ ตรงกับ Founder Brief เดิม (ห้าม over-engineer) และตรงกับคำเดิมของ Requirements ที่พูดถึงแค่ "7/30 วัน" ไม่ใช่ range เลือกเอง

### 3. Club ใหม่ที่ยังไม่มีกิจกรรม
`count(*)` ธรรมชาติ return 0 อยู่แล้วเมื่อไม่มีข้อมูล ไม่ต้องมี fallback พิเศษ — ข้อยกเว้นเดียวคือ `new_members`: Club ที่เพิ่งสร้างจะมี owner เป็นสมาชิกที่ `created_at` อยู่ในช่วงเสมอ ดังนั้น `new_members` จะเป็น 1 ไม่ใช่ 0 สำหรับ Club ใหม่จริงๆ ที่เพิ่งสร้าง — **ถูกต้องตามข้อมูลจริง ไม่ใช่บั๊ก** (เจ้าของ Club เองก็นับเป็นสมาชิกใหม่ในช่วงนั้นจริง) AC ที่บอก "แสดง 0 ทุกช่อง" หมายถึงไม่ crash/error เมื่อไม่มีกิจกรรม ไม่ได้แปลว่าทุกเลขต้องเป็น 0 เป๊ะเสมอสำหรับ Club ที่เพิ่งสร้าง

### 4. TabController length เปลี่ยนตาม role (ปัญหา engineering เดียวที่ Design ต้องตัดสินใจ)
`ClubPage._tabController` เป็น `late final TabController(length: 3, ...)` สร้างใน `initState()` — แต่ myRole รู้หลัง `_loadFuture` resolve เท่านั้น จึงกำหนด length ตอน `initState()` ไม่ได้ **ตัดสินใจ**: เปลี่ยนเป็น nullable field ที่สร้าง/สร้างใหม่แบบ lazy ใน `build()` เมื่อรู้ length ที่ถูกต้องแล้ว (คง index เดิมไว้ถ้า length ไม่เปลี่ยน กัน `_reload()` รีเซ็ต tab ที่ผู้ใช้กำลังดูอยู่) — Insights tab ต่อท้ายเป็น index สุดท้ายเสมอ (ไม่แทรกกลาง) ดังนั้น index ของ Posts/Members/About (0/1/2) ไม่เปลี่ยนไม่ว่าจะมี Insights tab หรือไม่ — ปุ่ม "จัดการสิทธิ์สมาชิก" ที่ `_tabController.animateTo(1)` ยังทำงานถูกต้องเหมือนเดิม

## Screen — Insights Tab (แท็บที่ 4 ใน `ClubPage`, มองเห็นเฉพาะ Owner/Admin)

**ตำแหน่ง**: ต่อท้าย Posts/สมาชิก/เกี่ยวกับ เสมอ (`if (myRole?.canManageClub ?? false) ...` ทั้งใน `TabBar.tabs`/`TabBarView.children` — มิเรอร์ pattern "ซ่อนทั้งส่วนไม่ใช่แค่ disable" ที่ `settings_screen.dart` ใช้กับ "เครื่องมือผู้ดูแล" อยู่แล้ว)

**Components**:
- แถบ toggle "7 วัน" / "30 วัน" (`SegmentedButton<int>`, default 7 วัน)
- 4 stat tile เรียงเป็น grid 2x2: "สมาชิกใหม่", "โพสต์ใหม่", "Like/Comment รวม", "สมาชิก Active" — ตัวเลขใหญ่ + label เล็ก ไม่มีกราฟ/export ตาม scope V1

**Interactions**: สลับ 7/30 วัน โหลดใหม่ทันที (RPC call ใหม่ พร้อม loading state สั้นๆ)

## Handoff

AI Coding → AI QA & Security
