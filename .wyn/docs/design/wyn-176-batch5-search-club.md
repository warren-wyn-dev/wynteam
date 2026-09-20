# WYN-176 Batch 5 — Search / Club press feedback

**Date**: 2026-09-20
**Status**: Approved by Founder (scope corrected mid-audit, see below)

## Scope check against real code — important correction

ตรวจ `search-route.tsx`, `notifications-route.tsx`, `clubs-routes.tsx`, `club-detail-golden.tsx`, `club-invite-route.tsx` ก่อนออกแบบ:

- **Notifications**: `.notification-row` มี press feedback อยู่แล้ว (WYN-169/170) — ไม่มีจุดใหม่
- **Search**: มีจุดเดียวที่ขาด — `.search-back-button`; ที่เหลือ (`.route-club-row`, `.route-person-main` ผ่าน `ProfileRowView`) มี press feedback อยู่แล้ว; `.hashtag-row`/`.top100-link` ไม่มี `onClick` เลย (dead interaction เดิม ไม่ใช่ scope นี้)
- **Club**: ระหว่างตรวจเจอว่า `.club-detail-*` (สี `--sapphire`/`--ink`/`--graphite` เก่า, จาก `club-detail-route.tsx`/`club-detail-audit.css`) กับ `club-post-card-web.tsx`/`club-post-card-web.css` **เป็น dead code ทั้งคู่** — grep ยืนยันไม่มีที่ไหน import ใช้งานจริง หน้า Club detail จริง (`/club/[id]`) ใช้ `ClubDetailGoldenRoute` จาก `club-detail-golden.tsx` + `club-detail-golden.css` ซึ่งใช้ `--wyn-*` token ถูกต้องอยู่แล้วทั้งหมด — **แก้รายงานเดิมที่บอกว่า Club ใช้สีเก่า** (เจอ match จากไฟล์ dead code โดยไม่ได้ตรวจ routing ก่อน) เท่ากับว่าไม่มีงาน token migration ให้ทำจริง — บันทึกไฟล์ dead code 2 ชุดนี้ไว้ให้ batch cleanup ท้ายสุด (WYN-160 เดิมเรียก "batch 8")

**สรุป**: Batch 5 กลับมาเป็น press-feedback-only เหมือน batch 1-4 ปกติ ไม่มีประเด็น resize/สี

## Targets (21 selectors, ไม่แก้ radius/ขนาด/สีใดๆ ทั้งหมด)

### Search (1 จุด — `web/app/notifications-clean.css`)
1. `.search-back-button`

### Club — list/create (5 จุด — `web/app/club-audit.css`, ไฟล์ที่ใช้จริงใน `clubs-routes.tsx`)
2. `.audit-club-main` — แถวคลับ (Link นำทาง)
3. `.audit-club-join` — ปุ่มเข้าร่วม
4. `.audit-my-club-row` — แถว "Club ของฉัน" (Link)
5. `.audit-club-image-picker` — label เลือกรูป Club ตอนสร้าง
6. `.audit-club-privacy button` — ปุ่มเลือกสาธารณะ/ส่วนตัว

### Club — detail (15 จุด — `web/app/club-detail-golden.css`, ไฟล์ที่ใช้จริงใน `club-detail-golden.tsx`)
7. `.golden-club-back` — ปุ่มย้อนกลับบน banner
8. `.golden-club-meta-main > button` — ปุ่มแชร์/เพิ่มเติม (2 ปุ่ม ไม่มี className แยก ใช้ parent selector)
9. `.golden-club-inline-join` — ปุ่มสถานะเข้าร่วมแบบเล็ก
10. `.golden-club-primary-join` — ปุ่มเข้าร่วมหลัก
11. `.golden-club-sheet-row` — แถวใน sheet เมนู Club/โพสต์ (แชร์/รายงาน/ออกจาก Club ฯลฯ)
12. `.golden-club-post-body > header > button` — ปุ่ม "เพิ่มเติม" ของแต่ละโพสต์
13. `.golden-club-tabs button` — แท็บ โพสต์/แชท/เกี่ยวกับ
14. `.golden-club-channels button` — chip เลือกห้องแชท
15. `.golden-club-poll > button` — ปุ่มโหวตโพล
16. `.golden-club-actions button`, `.golden-club-actions a` — แถวไลก์/คอมเมนต์ใต้โพสต์
17. `.golden-club-about-tabs button` — แท็บย่อย รายละเอียด/สมาชิก/กิจกรรม/insights
18. `.golden-club-members > a` — แถวสมาชิก (Link)
19. `.golden-club-composer label`, `.golden-club-composer button` — ปุ่มแนบรูป/ส่งข้อความในแชท Club
20. `.golden-club-message-head button` — ปุ่มตัวเลือกข้อความแชท

Motion token เดียวกับทุก batch: `transform: scale(0.96)` บน `:active`, `transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1)`, ปิดใน `prefers-reduced-motion: reduce`

ไม่ทำ preview artifact รอบนี้ — ไม่มีประเด็นตัดสินใจด้าน visual (ทุกจุดใช้ motion token เดิมที่อนุมัติแล้วตั้งแต่ WYN-163, ไม่มีทางเลือกด้าน scale/สีให้เลือกเหมือน batch 4)

## Handoff

→ **AI Coding**: ตรวจ cascade จริงก่อนแก้ทุกจุด (grep ทุกไฟล์ CSS หา selector ซ้ำ + เช็คลำดับ import ใน `layout.tsx`) แก้เฉพาะไฟล์ที่ component จริงใช้ (`club-detail-golden.css`, ไม่ใช่ `club-detail-audit.css`) ยืนยันด้วย harness Playwright จริงก่อนส่ง QA
