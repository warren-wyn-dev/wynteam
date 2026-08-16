# Product Task — DS-006

Status: approved (QA — PASS, 2026-08-16, audit-only — ไม่มีการแก้โค้ด) — 6th ของ 8 เฟส (DS-001 → ... → DS-005 → **DS-006** → DS-007 → DS-008)
Owner: AI Product Manager → AI Design (audit) → AI QA & Security (PASS)

Feature: Profile + Search

Goal: ตรวจสอบว่า Profile และ Search สอดคล้องกับภาษาภาพที่ DS-001/DS-002/DS-003/DS-005 วางไว้ (card-less, grid spacing สม่ำเสมอ, divider เฉพาะ content feed ไม่ใช่ entity-browse list)

Target User: ผู้ใช้ WYN ทุกกลุ่ม

## Audit ผล

อ่านทั้ง 11 ไฟล์ presentation ของ Profile (`view_profile_screen.dart`, `edit_profile_screen.dart`, 3 grid tabs) และ Search (`search_screen.dart`, 4 result tabs) แล้วพบว่า:

| จุดตรวจ | ผล |
|---|---|
| `Card(`/`elevation`/`BoxShadow` ทั้ง 2 feature | **ศูนย์ผลลัพธ์** — card-less ทั้งหมดตั้งแต่ WYN-003/WYN-009/WYN-013 |
| Grid spacing (Profile's Drop/Pop/Saved tabs) | 3-column, `crossAxisSpacing`/`mainAxisSpacing` = 2px ทั้ง 3 tab — สอดคล้องกับ `DropFeedScreen` (DS-004 ยืนยันไว้) เป๊ะ ไม่มี drift |
| Search's Drop/Pop result tabs | Grid เดียวกัน (SliverGrid + spacing 2px) — สอดคล้อง |
| Search's Club/User result tabs | `ListView.builder` แบบ entity-browse (แถวรายชื่อ/รายการ Club ให้กด) — **ไม่ใช่ chronological content feed** เข้าเกณฑ์เดียวกับที่ DS-005 ตัดสินใจไม่ใส่ divider ให้ My Clubs/Explore Clubs (เหตุผลเดียวกัน: ประเภท UI คนละแบบกับ Home Feed/Club Posts) |

**สรุป**: ไม่มีช่องว่างที่ต้องแก้ — ทั้ง 2 feature สอดคล้องกับทุก token/pattern ที่ DS-001 ถึง DS-005 วางไว้แล้วโดยธรรมชาติ (ใช้ `Theme.of(context)` ทั่วถึง ไม่มี hardcode สี ไม่มี Card หลงเหลือ)

Requirements: ไม่มี (audit-only)

Acceptance Criteria:
- [x] ไม่มี Card/elevation/shadow ใน Profile หรือ Search
- [x] Grid spacing สอดคล้องกับ Drop feed (2px, 3-column) ทุกจุด
- [x] Entity-browse list (Club/User search results) ไม่ต้องมี divider ตามเกณฑ์เดียวกับ DS-005
- [x] ไม่มีการแก้โค้ดใดๆ ในรอบนี้

Dependencies: DS-001 ถึง DS-005

Priority: กลาง

Risks: ไม่มี — ไม่มีการแก้โค้ด

Recommendation: อนุมัติแบบ audit-only ไปต่อ DS-007 (ZOKY commerce identity)

Handoff: ไม่มีการส่งต่อ AI Coding รอบนี้ — ไปต่อ DS-007 โดยตรง

---

## QA Verification (2026-08-16)

```
Feature: DS-006 Profile + Search audit
Environment: Direct code read, no build/test needed (zero code changed)
Test Cases:
  1. grep "Card(|elevation|BoxShadow" across all 11 files -- zero results.
  2. Compare grid spacing constants across Profile's 3 grid tabs + Search's Drop/Pop
     result tabs vs DropFeedScreen (DS-004's confirmed baseline) -- identical (3-column,
     2px/2px).
  3. Classify Search's Club/User result tabs against DS-005's established entity-browse
     vs content-feed distinction -- both are entity-browse, correctly excluded from the
     divider pattern.
Passed: 3/3 -- zero gaps found, zero code changed, zero risk of regression.
Recommendation: Approve as audit-only. Continue to DS-007.
Final Status: PASS
```
