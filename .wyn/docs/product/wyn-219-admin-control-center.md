# Product Spec — WYN-219 WYNOS Admin Control Center (Admin ควบคุมได้ทุกระบบ)

Status: **Phase 1 approved by the Founder** (AskUserQuestion 2026-10-10: "อนุมัติ เริ่มเลย"). Phase 2 ต้องอนุมัติ architecture proposal แยกอีกครั้ง
Source: Founder request (2026-10-10): "จะมี WYNOS Admin / WYNOS Account / WYNOS Food / WYNOS Merchant / WYNOS Maps หัวข้อหลักๆ อยากให้ระบบ Admin ควบคุมได้ทุกระบบ"
Founder scope decisions (AskUserQuestion, 2026-10-10):
- **WYNOS Social แยกเป็นหัวข้อของตัวเอง** ใน Admin (ไม่รวมใต้ Account)
- **สิทธิ์ admin แยกตามระบบ** (least privilege) — super admin เห็นทุกระบบ, admin ของแต่ละระบบเห็นเฉพาะระบบตัวเอง
- **เริ่มจากจัดเมนูเป็นหัวข้อหลักก่อน** แล้วค่อยเติมส่วนที่ขาดทีละระบบ

Product family (Founder, 2026-10-10): **WYNOS Admin** ควบคุม **WYNOS Account**, **WYNOS Social**, **WYNOS Food**, **WYNOS Merchant**, **WYNOS Maps**

---

## Current state (code checked 2026-10-10)

Sidebar ปัจจุบันเป็นรายการเดียวไม่แบ่งกลุ่ม (`admin/lib/admin-nav.ts`): Dashboard, User Management, Merchant Applications, Food Stores & Orders, Content Moderation, Report Center, Audit Log, Announcements

| ระบบ | หน้าที่มีอยู่แล้ว | ช่องว่างที่เห็น |
|---|---|---|
| Account | `/users`, `/users/[id]` (ค้นหา, ดู, แบน/ระงับ) | ไม่เห็นภาพบัญชีกลางข้ามระบบ (บัญชีนี้ใช้ Social/Food/Merchant อะไรบ้าง) |
| Social | `/moderation`, `/reports`, `/announcements` (รวม inactive reminders), feed algorithm observability บน Dashboard | ไม่มีกลุ่มเมนู Social; ไม่มีหน้าดูแล Club |
| Food | `/food`, `/food/stores/[id]`, `/food/orders`, `/food/coupons`, `/food/campaigns`, `/food/ads`, `/food/notifications` | การเงิน/คืนเงินในมุม admin, ตั้งค่าระบบ Food |
| Merchant | `/merchants` (ตรวจใบสมัคร) | จัดการร้านหลังอนุมัติ, Stripe Connect/payout |
| Maps | `/food/places` (จัดการสถานที่ + ตรวจรูป) ซ่อนอยู่ใต้ Food | ไม่มีหัวข้อ Maps |
| ส่วนกลาง | Dashboard, `/audit-log` | ไม่มี feature on/off ต่อระบบ |

Authorization ปัจจุบัน: `platform_role` มีแค่ `admin` และ `moderator` ตรวจฝั่ง server ใน `requireAdminRole()` (`admin/lib/auth.ts`) บางหน้าเช็ค `role === "admin"` เพิ่ม (เช่น Food store suspension, orders)

---

## Phase 1 — จัด Admin เป็นหัวข้อหลักตามระบบ (P0)

Goal: เปิด Admin แล้วเห็นทันทีว่าแต่ละระบบของ WYNOS ควบคุมได้ที่ไหน โดย **ไม่เปลี่ยนสิทธิ์และไม่เปลี่ยนพฤติกรรมของหน้าเดิม**

### Requirements
1. Sidebar แบ่งเป็นกลุ่มตามลำดับนี้ พร้อมหัวกลุ่ม:
   - **ภาพรวม:** Dashboard
   - **WYNOS Account:** User Management
   - **WYNOS Social:** Content Moderation, Report Center, Announcements
   - **WYNOS Food:** Stores, Orders, Coupons, Campaigns, Ads, Promo Notifications
   - **WYNOS Merchant:** Merchant Applications
   - **WYNOS Maps:** Places (หน้าเดียวกับ `/food/places` ปัจจุบัน)
   - **ระบบ:** Audit Log
2. หน้า Places ต้องเข้าได้จากหัวข้อ Maps; URL เดิม `/food/places` ต้องยังใช้ได้ เพื่อไม่ทำลาย bookmark/ลิงก์เดิม (implemented: ย้ายไป `/maps/places` และ `/food/places` redirect แบบ 307 พร้อม query string)
3. เมนูย่อยของ Food ที่ตอนนี้เป็นปุ่มในหน้า `/food` ต้องเข้าถึงได้จาก sidebar โดยตรง
4. รายการที่ moderator เข้าไม่ได้วันนี้ ต้องยังเข้าไม่ได้ (ไม่ขยายสิทธิ์) — ถ้าเมนูนั้น moderator ใช้ไม่ได้ ให้ซ่อนจาก sidebar ของ moderator
5. Mobile-first: บนจอ 390px sidebar ยังใช้งานได้ (drawer/collapse ตาม pattern เดิม), ปุ่มสูงอย่างน้อย 44px, หัวกลุ่มอ่านได้ทั้งธีมสว่าง/เข้ม (ถ้ามี)
6. Active state ถูกต้องสำหรับหน้าลูก (เช่น `/food/orders/123` ไฮไลต์ Stores & Orders) — วันนี้ใช้ `pathname === item.href` ซึ่งไม่ไฮไลต์หน้าลูก
7. ไม่มีการเปลี่ยน database, RLS, RPC หรือ Edge Function ใน Phase 1

### Acceptance criteria
- Admin เห็นครบ 7 กลุ่มตามลำดับ และทุกหน้าที่มีอยู่วันนี้เข้าถึงได้จาก sidebar
- Moderator เห็นเฉพาะเมนูที่วันนี้ใช้ได้ และเปิด URL ของหน้าที่ใช้ไม่ได้ตรง ๆ แล้วยังถูกปฏิเสธจาก server เหมือนเดิม
- `/food/places` เดิมยังพาไปหน้า Places ได้
- หน้าลูกไฮไลต์เมนูแม่ถูกต้อง
- ใช้งานได้บน 390px และ desktop; ผ่าน Admin CI (lint, typecheck)
- ไม่มี schema/RLS diff

---

## Phase 2 — สิทธิ์ admin แยกตามระบบ (P0, ต้องอนุมัติ architecture ก่อน)

Goal: ทีมแต่ละระบบเข้าได้เฉพาะระบบของตัวเอง (least privilege)

> นี่คือ **security/authorization architecture change** ตาม `AGENTS.md` Change Control — Software Architect ต้องเสนอ proposal (benefits, risks, affected files, migration, rollback) ให้ Founder อนุมัติก่อน implement

### Requirements (ระดับ product)
1. มีบทบาท **super admin** ที่เข้าได้ทุกระบบ รวมถึงการให้/ถอนสิทธิ์ admin คนอื่น
2. มีสิทธิ์ต่อระบบ: Account, Social, Food, Merchant, Maps — คนหนึ่งคนถือได้หลายระบบ
3. ผู้ที่ไม่มีสิทธิ์ของระบบใด ต้องไม่เห็นเมนู และ **server/RLS/RPC ต้องปฏิเสธ** การเข้าถึงข้อมูลและ action ของระบบนั้น แม้เรียก URL หรือ API ตรง
4. Moderator เดิมต้องทำงานเดิมได้ต่อ (mapping สิทธิ์เดิม → สิทธิ์ใหม่ต้องไม่ทำให้ใครเสียหรือได้สิทธิ์เกินโดยไม่ตั้งใจ)
5. การให้/ถอนสิทธิ์ทุกครั้งบันทึกลง Audit Log (ใคร, ให้ใคร, ระบบไหน, เมื่อไร)
6. ห้าม admin ถอนสิทธิ์ super admin คนสุดท้าย

### Founder answers (AskUserQuestion, 2026-10-10)
- **Super admin เริ่มต้น: Founder คนเดียว** — ให้สิทธิ์คนอื่นภายหลัง
- **แยกระดับ "ดูอย่างเดียว" กับ "แก้ไขได้"** ในแต่ละระบบ
- **Moderator เดิม → สิทธิ์ WYNOS Social เท่านั้น** (AskUserQuestion รอบสอง 2026-10-10) — เลิกเห็น Food/Maps; Founder ให้สิทธิ์เพิ่มรายคนภายหลังได้

---

## Phase 3+ — เติมส่วนที่ขาดทีละระบบ (P1, ต้องมี PRD ย่อยแยก)

ลำดับและขอบเขตให้ Founder เลือกหลัง Phase 1–2; รายการที่เห็นจากการตรวจโค้ด (ยังไม่ใช่ requirement):
- **Account:** มุมมองบัญชีกลางข้ามระบบ
- **Social:** ดูแล Club
- **Food / Merchant:** การเงิน, การคืนเงิน, Stripe Connect/payout, จัดการร้านหลังอนุมัติ
- **Maps:** ตั้งค่าและคุณภาพข้อมูลสถานที่
- **ส่วนกลาง:** เปิด/ปิดฟีเจอร์ต่อระบบ (ต้องระวังไม่ให้ซ้อนกับ Beta2 gate ที่ต้องมี Founder approval)

---

## Out of scope
- เปลี่ยน UI ฝั่งผู้ใช้ของ WYNOS Web
- เปลี่ยน authentication ของ admin (login flow)
- ฟีเจอร์ใหม่ในแต่ละระบบที่ไม่ได้ระบุไว้ข้างบน

## Risks
- Phase 2 แตะ authorization ของข้อมูลทุกระบบ — ถ้าออกแบบผิดอาจเกิด privilege escalation หรือ admin ถูกล็อกออก → ต้องมี QA & Security เต็มรูปแบบและ rollback plan
- `/food/places` ใช้ร่วมระหว่าง Food และ Maps — การย้ายต้องไม่ทำลายลิงก์เดิม

## Handoff
Founder อนุมัติ PRD → CTO → Software Architect (Phase 1 nav structure; Phase 2 authorization proposal) → UI/UX → Full-Stack → QA & Security → CTO final review → staging → Founder approval → production
