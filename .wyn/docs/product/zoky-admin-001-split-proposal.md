# ZOKY-ADMIN-001 — แยก ZOKY Admin ออกจาก WYNOS Admin (PRD + Architecture Proposal)

Status: **DRAFT — รอ Founder อนุมัติ** (Change Control: major architecture change, authorization change, infrastructure ใหม่)
Date: 2026-10-25
Source: Founder request "WYNOS Admin แยกฟังชั่น ของ ZOKY Admin ออกจากกันได้มั้ย"

Founder scope decisions (AskUserQuestion, 2026-10-25):
- **ระดับการแยก:** แอปหลังบ้านใหม่ "ZOKY Admin" (ไม่ใช่แค่ย้าย URL/สิทธิ์ภายใน WYNOS Admin)
- **ขอบเขต:** ทั้งหมวด WYNOS Food และ WYNOS Merchant
- **WYNOS Admin เดิม:** ลบหน้าเหล่านั้นออก + ลิงก์/redirect ไป ZOKY Admin (โค้ดชุดเดียว)
- **สิทธิ์:** ทีม ZOKY แยกต่างหาก
- **โดเมน:** `zoky-admin.wynos.online`

เอกสารนี้ไม่ใช่การอนุมัติให้ implement, migrate หรือ deploy — ทุกข้อในหัวข้อ "ต้องอนุมัติ" ต้องได้ explicit approval ก่อน

---

## 1. สถานะปัจจุบัน (ตรวจโค้ด 2026-10-25)

- `admin/` เป็น Next.js app เดียว (Vercel project แยก, `admin.wynos.online`) มีหมวด Account / Social / Food / Merchant / Maps / ส่วนกลาง (`admin/lib/admin-nav.ts`)
- Decision 2026-10-11: ย้าย Stores, Coupons, Campaigns, Ads, Promo Notifications ไปใต้เมนู Merchant แต่ **URL `/food/*` และสิทธิ์ `food` คงเดิม** — Food/Merchant จึงปนกันทั้ง URL และสิทธิ์
- สิทธิ์ WYN-219: `public.admin_permissions (user_id, system, level)` + `internal.platform_super_admins`; DB ตรวจด้วย `internal.has_admin_permission(system, level)` (ประมาณ 32 จุดใช้ `'food'`) — มีเพียง super admin ที่ grant/revoke ได้
- โค้ดที่เป็นของ Food/Merchant: `app/(admin)/food/**`, `app/(admin)/merchant/**`, `app/(admin)/merchants/`, `dashboard/[system]` (food, merchant), `lib/admin-food*.ts`, `lib/admin-merchant*.ts`, `lib/admin-ads.ts`, `lib/admin-gp*.ts`, `lib/admin-platform-campaigns.ts`, `lib/admin-control-catalog.ts`, components `food-*`, `merchant-*`, `ad-actions`, `gp-rate-dialog`, `platform-campaign-actions`, `delivery-policy-preview`, `control-center`
- `maps/places` เคยอยู่ใต้ Food แต่ปัจจุบันเป็นหมวด WYNOS Maps → **คงอยู่ใน WYNOS Admin**

## 2. Requirements

### P0
1. แอปใหม่ `zoky-admin/` (Next.js App Router + TypeScript + Tailwind + shadcn/ui แบบเดียวกับ `admin/`) เชื่อม Supabase project เดิม ใช้ RPC/table/view เดิม
2. ย้ายทุกหน้า/ฟังก์ชันของหมวด Food และ Merchant ไป ZOKY Admin โดย**พฤติกรรมและผลลัพธ์เหมือนเดิม** (ไม่เพิ่มฟีเจอร์ในรอบนี้)
3. ZOKY Admin มี Sidebar 2 หมวด: **ZOKY Food** (ลูกค้า/ออเดอร์/รีวิว/แบนเนอร์/ร้านแนะนำ) และ **ZOKY Merchant** (ร้าน/ตรวจสอบร้าน/เมนู/คูปอง/แคมเปญ/โฆษณา/แจ้งเตือน/การเงิน/ค่าส่ง/เวลาเปิด-ปิด) — URL จัดใหม่ให้ตรงหมวด (`/food/*`, `/merchant/*`)
4. WYNOS Admin: ลบหน้าที่ย้ายออก, URL เดิมทั้งหมด redirect (308) ไป path ที่ตรงกันบน `zoky-admin.wynos.online`, Sidebar แสดงลิงก์ "ZOKY Admin ↗" แทนหมวด Food/Merchant
5. Login แยก: ZOKY Admin มีหน้า login ของตัวเอง เข้าได้เฉพาะบัญชีที่มีสิทธิ์ `food` หรือ `merchant` (หรือ super admin); ตรวจฝั่ง server ทุก layout/page/RPC เหมือนเดิม
6. **ทีม ZOKY แยกต่างหาก:** ZOKY Admin มีหน้า "ทีม ZOKY" ให้ **ZOKY Team Lead** เพิ่ม/ถอนสิทธิ์ `food`/`merchant` (view/edit) ให้สมาชิกได้เอง โดยไม่ต้องผ่าน super admin และ**ให้สิทธิ์ระบบอื่นไม่ได้**; ทุกการเปลี่ยนบันทึก audit log
7. Founder/super admin เป็นผู้แต่งตั้ง/ถอด ZOKY Team Lead (จากหน้า Roles & Permissions ใน WYNOS Admin)

### P1
- ลิงก์ข้ามแอปจากหน้าที่เหลือใน WYNOS Admin (เช่น User detail → ออเดอร์ของผู้ใช้) เปิดไป ZOKY Admin
- Dashboard รวมของ WYNOS Admin แสดงสรุป Food/Merchant แบบอ่านอย่างเดียว + ลิงก์ไป ZOKY Admin (ถ้าผู้ดูมีสิทธิ์)

### Out of scope
- SSO ข้าม subdomain (login แยกสองแอปในรอบนี้)
- ฟีเจอร์ "เร็วๆ นี้" (Customers, Payments & Refunds, Customer Support ฯลฯ)
- แยก Supabase project / database / backend service
- npm workspaces / shared package

### Acceptance criteria
- ทุกหน้าที่ย้ายทำงานเหมือนเดิมบน ZOKY Admin (regression ตาม QA matrix ของ WYN-203/205/206/207/213/214/219)
- บัญชีที่มีแค่ `social`/`account`/`maps` เข้า ZOKY Admin ไม่ได้ และเรียก RPC Food/Merchant ไม่ได้ (direct-API)
- ZOKY Team Lead grant ได้เฉพาะ `food`/`merchant`; พยายาม grant `account`/`social`/`maps` หรือแต่งตั้ง lead คนอื่น → DB ปฏิเสธ
- ZOKY Team Lead ถอดสิทธิ์ super admin หรือตัวเองเป็น super admin ไม่ได้
- URL เดิมบน `admin.wynos.online` redirect ไปหน้าที่ถูกต้อง; ไม่มีลิงก์ 404 ใน WYNOS Admin

## 3. Architecture

```text
admin.wynos.online (admin/)            zoky-admin.wynos.online (zoky-admin/)
  Account / Social / Maps / ส่วนกลาง       ZOKY Food / ZOKY Merchant / ทีม ZOKY
  /food/*, /merchant/* → 308 redirect ──►
              \                          /
               └──── Supabase project เดิม (RPC/RLS เดิม + RPC ทีม ZOKY ใหม่) ────┘
```

- **ย้ายโค้ด ไม่ copy:** ไฟล์ Food/Merchant ย้ายจาก `admin/` ไป `zoky-admin/` (git mv) เพื่อให้มีโค้ดชุดเดียว
- **โค้ด shell ที่ทั้งสองแอปต้องใช้** (`components/ui/*`, `lib/supabase/*`, `lib/utils.ts`, `lib/auth.ts`, `lib/admin-systems.ts`, `lib/admin-permissions.ts`, sidebar/header/nav-state): copy เข้า `zoky-admin/` — ยอมรับ duplication เล็กน้อยแทนการเพิ่ม workspace tooling (Principle: simple architecture); ถ้าภายหลัง drift มาก ค่อยเสนอ shared package แยก
- **Auth:** แต่ละ subdomain มี Supabase session cookie ของตัวเอง; `requireZokyAdmin()` ตรวจ `food`/`merchant`/super admin ฝั่ง server
- **Deploy:** Vercel project ใหม่ root `zoky-admin/` (แพลน Hobby เหมือน Admin), workflow `deploy-zoky-admin.yml` และ `zoky-admin-attach-domain.yml` ตามแบบ `deploy-admin.yml`/`admin-attach-domain.yml`; CI เพิ่ม lint/build ของ `zoky-admin/`
- **Release:** อยู่ใน coordinated release เดียวกับ `docs/engineering/WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md` — เปิด ZOKY Admin และ redirect ใน WYNOS Admin **พร้อมกัน** เพื่อไม่ให้มีช่วงที่หน้าหายหรือซ้ำ

### Database (ทีม ZOKY) — ต้องอนุมัติ
Additive migration เท่านั้น ไม่แก้ RPC Food/Merchant เดิม (ยังตรวจ `has_admin_permission('food'|'merchant', …)` เหมือนเดิม):
- `internal.zoky_team_leads (user_id pk → auth.users, appointed_by, appointed_at)` — RLS deny by default
- `internal.is_zoky_team_lead()` security definer
- RPC `admin_zoky_list_team()`, `admin_zoky_grant_permission(user_id, system, level)`, `admin_zoky_revoke_permission(user_id, system)` — อนุญาตเฉพาะ super admin หรือ ZOKY Team Lead, `system` ต้องเป็น `food`/`merchant` เท่านั้น, ห้ามแก้แถวของ super admin/lead
- RPC `admin_set_zoky_team_lead(user_id, enabled)` — super admin เท่านั้น
- audit event types ใหม่ (additive): `zoky_team_lead_appointed`, `zoky_team_lead_removed`; grant/revoke ใช้ event `admin_permission_granted/revoked` เดิม
- พร้อม `supabase/tests/zoky_admin_team_test.sh`, rollback SQL, apply workflow

## 4. Plan (แต่ละข้อเป็น PR แยก)

1. **Scaffold `zoky-admin/`** — shell, login, auth gate, sidebar ว่าง, CI build (ยังไม่มี Vercel project)
2. **ย้ายหน้า Food** → `zoky-admin/` + test
3. **ย้ายหน้า Merchant** (รวม `/food/coupons|campaigns|ads|notifications` และ `/food` Stores → `/merchant/*`) + test
4. **DB ทีม ZOKY** — migration + test + rollback (ยังไม่ apply production)
5. **หน้า "ทีม ZOKY"** ใน ZOKY Admin + แต่งตั้ง Lead ใน WYNOS Admin
6. **WYNOS Admin cleanup** — ลบหน้าที่ย้าย, redirect, ลิงก์ข้ามแอป (merge แต่ไม่ deploy จนถึง release)
7. **Infra** — Vercel project + domain + deploy workflow (ต้องอนุมัติ)
8. QA & Security → CTO review → Staging → Founder approval → coordinated production release

## 5. Benefits / Risks / Rollback

**Benefits:** แยกทีมและสิทธิ์ ZOKY ชัดเจน (least privilege), ทีม ZOKY จัดการสมาชิกเองได้, deploy ZOKY Admin ได้โดยไม่กระทบ WYNOS Admin, ลดความสับสน URL/สิทธิ์ที่ปนกันตอนนี้

**Risks:**
- HIGH — การมอบสิทธิ์ grant ให้ Team Lead เป็น privilege-delegation ใหม่: ต้อง test privilege escalation (grant ระบบอื่น, แตะแถว super admin, แต่งตั้ง lead เอง) ก่อน release
- MEDIUM — ทำให้ coordinated release ใหญ่ขึ้น/ช้าลง; ระหว่างทำต้อง freeze การเปลี่ยนหน้า Food/Merchant ใน `admin/` เพื่อเลี่ยง conflict
- MEDIUM — โค้ด shell ซ้ำสองแอป อาจ drift
- LOW — staff ที่มีสิทธิ์หลายระบบต้อง login สองที่
- Vercel Hobby: โควตา deploy ใช้ร่วมกันมากขึ้น; ไม่มีค่าใช้จ่ายเพิ่มถ้ายังอยู่ Hobby

**Rollback:** ก่อน release ไม่มีผลกับ production; หลัง release — revert PR cleanup ของ WYNOS Admin แล้ว redeploy release SHA เดิม (หน้ากลับมา, redirect หาย), ปลดโดเมน `zoky-admin` ได้; migration เป็น additive มี rollback SQL ที่ drop table/RPC ใหม่โดยไม่แตะ `admin_permissions` เดิม

## 6. ต้องอนุมัติ (Founder)

- [ ] Major architecture: แอปที่สอง `zoky-admin/` และย้าย Food/Merchant ออกจาก `admin/`
- [ ] Authorization change: ZOKY Team Lead + DB migration ตามหัวข้อ 3
- [ ] Infrastructure: Vercel project ใหม่ + โดเมน `zoky-admin.wynos.online` + deploy workflow
- [ ] รวมงานนี้ใน coordinated release ของ WYNOS Admin/Food/Merchant (หรือแยก release รอบถัดไป)

### คำถามที่ยังเปิด
1. ZOKY Team Lead ควรเพิ่ม/ถอด Lead คนอื่นได้ไหม (ข้อเสนอ: ไม่ได้ — Founder/super admin เท่านั้น)
2. "Merchant Verification" (`/merchants`) ตรวจร้านทุกประเภท (food/retail/service) — ย้ายไป ZOKY Admin ทั้งหมดใช่ไหม (ข้อเสนอ: ใช่)
3. ชื่อหมวดใน ZOKY Admin ใช้ "ZOKY Food / ZOKY Merchant" หรือคง "WYNOS Food / WYNOS Merchant"
