# WYN-219 Phase 2 — Per-system Admin Permissions (Architecture Proposal)

Status: **APPROVAL_REQUIRED — รอ Founder อนุมัติ** (authorization architecture change ตาม `AGENTS.md` Change Control)
Author: Software Architect (AI) · Date: 2026-10-10
Product spec: `.wyn/docs/product/wyn-219-admin-control-center.md`

## 1. Founder requirements (ตัดสินแล้ว 2026-10-10)

- สิทธิ์แยกตามระบบ: **Account, Social, Food, Merchant, Maps**
- แต่ละระบบมี 2 ระดับ: **view** (ดูอย่างเดียว) และ **edit** (แก้ไขได้; edit รวม view)
- **Super admin = Founder คนเดียว** — เข้าได้ทุกระบบ และเป็นคนเดียวที่ให้/ถอนสิทธิ์
- **Moderator เดิม → Social เท่านั้น**

## 2. ระบบสิทธิ์ปัจจุบัน (ตรวจโค้ด 2026-10-10)

- `profiles.platform_role` ∈ `user | moderator | admin`; trigger `profiles_prevent_platform_role_change` กันการแก้จาก client
- Admin app ใช้ session ของผู้ใช้ (ไม่มี service-role key) → **การบังคับสิทธิ์จริงทั้งหมดอยู่ใน database** (RPC/RLS/views)
- มีจุดตรวจสิทธิ์ประมาณ **60 จุด** ใน `schema.sql` และ migrations ใช้ 3 รูปแบบ:
  - `current_platform_role() <> 'admin'` → admin เท่านั้น (เทียบได้กับ **edit**)
  - `not in ('admin','moderator')` หรือ `<> 'user'` → staff ทุกคน (เทียบได้กับ **view** หรือ action ของ moderator)
  - `public.food_is_platform_admin()` (Food storage policy + merchant RPC 3 ตัว)
- `schema.sql` อาจ drift จาก production → ทุก function ที่จะแก้ต้องดึงนิยามจริงจาก production ก่อน (`.wyn/docs/engineering/checklist-db-migration-touching-a-view.md`)

## 3. Proposed design

### 3.1 Data model (additive — ไม่ลบ/ไม่แก้คอลัมน์เดิม)

```sql
-- Not exposed through the API (internal schema); written only by migration/workflow.
create table internal.platform_super_admins (
  user_id uuid primary key references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.admin_permissions (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  system     text not null check (system in ('account','social','food','merchant','maps')),
  level      text not null check (level in ('view','edit')),
  granted_by uuid not null references public.profiles(id),
  granted_at timestamptz not null default now(),
  primary key (user_id, system)
);
-- RLS on, deny by default: a user may read only their own rows; super admin reads all.
-- No insert/update/delete policy: writes only through the RPCs in 3.3.
```

### 3.2 Single check helper (ใช้แทนการเช็ค `platform_role` ทุกจุด)

```sql
internal.has_admin_permission(p_system text, p_level text) returns boolean
-- security definer, stable, search_path = ''
-- true when auth.uid() is a super admin, or has a row for p_system whose level
-- satisfies p_level (edit satisfies view). Unknown system/level -> false (deny by default).
internal.is_super_admin() returns boolean
```

ทุก RPC ที่มีอยู่จะเปลี่ยนจากเช็ค role เป็นเรียก helper ตัวนี้ ตาม mapping ใน 3.4 — **logic อื่นของ function ไม่เปลี่ยน**

### 3.3 Grant/revoke RPCs (super admin เท่านั้น)

- `admin_grant_permission(p_user_id, p_system, p_level)` / `admin_revoke_permission(p_user_id, p_system)` / `admin_list_permissions()`
- ทุกครั้งเขียน `audit_log` ด้วย event ใหม่ `admin_permission_granted` / `admin_permission_revoked` (ต้องขยาย check constraint ของ `audit_log.event_type` — additive)
- **ไม่มี RPC สำหรับเพิ่ม/ลบ super admin** — เปลี่ยนได้ผ่าน migration/workflow ที่ Founder อนุมัติเท่านั้น จึงไม่มีทางที่ใครจะยกระดับตัวเองเป็น super admin หรือทำให้ไม่เหลือ super admin ผ่าน API

### 3.4 Mapping จุดตรวจเดิม → สิทธิ์ใหม่

| ระบบ | RPC/policy (ตัวอย่าง) | เดิม | ใหม่ |
|---|---|---|---|
| Account | `admin_user_directory`, `admin_user_moderation_history` | staff | account:view |
| Account | `admin_count_inactive_users`, `admin_send_inactive_reminder` | admin | account:edit |
| Social | `moderation_queue`, `admin_search_drops`, `admin_get_drop`, `get_message_for_moderation`, appeals | staff | social:view |
| Social | `admin_remove_drop`, `admin_restore_drop`, `decide_appeal`, `admin_apply_user_action`, `admin_unban_user` | staff | social:edit (ดูคำถาม Q2) |
| Social | `admin_send_announcement`, `send_system_notification` | admin | social:edit |
| Social | `admin_feed_algorithm_dashboard` | staff | social:view |
| Food | `admin_food_overview`, `admin_food_stores`, `admin_food_store_detail`, `admin_platform_campaigns`, `admin_food_promo_list` | staff | food:view |
| Food | orders, store suspension, coupons, promo, campaigns, ads, `admin_settle_platform_store`, `admin_platform_owed`, `food-private` storage, `food_is_platform_admin()` | admin | food:edit |
| Merchant | `admin_merchant_applications` | staff | merchant:view |
| Merchant | `admin_review_merchant_application` | admin | merchant:edit |
| Maps | `admin_wynos_places`, `admin_wynos_place_photos`, `admin_wynos_place_suggestions`, `admin_wynos_place_for_store` | staff | maps:view |
| Maps | upsert/import/set-active place, review photo/suggestion, place photo storage policy | admin | maps:edit |
| ส่วนกลาง | `admin_dashboard_metrics`, `admin_dashboard_trends`, `admin_signup_counts` | staff | สิทธิ์ใดก็ได้ ≥ 1 ระบบ |
| ส่วนกลาง | `admin_audit_log` | staff | ดูคำถาม Q3 |

ตัวเลขจริงและรายชื่อครบจะอยู่ใน migration checklist ก่อน implement (ทุกจุดที่ grep `platform_role`/`food_is_platform_admin` เจอ ต้องมีแถวใน checklist)

### 3.5 Seed (migration แรก)

- Founder → `internal.platform_super_admins` (ระบุ user id ผ่าน workflow input ตอน apply — **ไม่ commit ข้อมูลส่วนตัวลง repo**)
- `moderator` ทุกคน → `social: edit` (ดู Q2)
- `admin` อื่นที่ไม่ใช่ Founder → ดู Q1

### 3.6 Admin app

- `requireAdminRole()` → `requireAdminAccess()` คืนสิทธิ์ทั้งหมดของผู้ใช้; layout ปฏิเสธคนที่ไม่มีสิทธิ์ใดเลย
- Sidebar แสดงเฉพาะระบบที่มีสิทธิ์ (ต่อยอดจาก Phase 1 `adminOnly`) ; ปุ่มแก้ไขแสดงเมื่อมี edit
- หน้าใหม่ **"สิทธิ์ทีมงาน"** (super admin เท่านั้น) — ค้นหาผู้ใช้, ให้/ถอนสิทธิ์รายระบบ, ดูประวัติ
- UI เป็นแค่ความสะดวก — server ปฏิเสธเสมอแม้เรียก RPC ตรง

## 4. Rollout (แต่ละขั้นมี QA และ rollback ของตัวเอง)

1. **Foundation:** tables, helpers, grant RPCs, audit events, seed — ยังไม่มี RPC เดิมตัวไหนเปลี่ยน (พฤติกรรมเดิม 100%)
2. **Migrate checks ทีละระบบ** (Maps → Merchant → Food → Social → Account → ส่วนกลาง) แต่ละระบบเป็น migration + PR แยก พร้อม SQL regression test ว่า: super admin, edit, view, ไม่มีสิทธิ์, moderator, user ธรรมดา ได้ผลถูกต้อง
3. **Admin app:** permission-aware layout/sidebar + หน้าสิทธิ์ทีมงาน
4. `platform_role` ยังอยู่ (ใช้กับฝั่ง consumer เช่น Official/announcement audience) — ไม่ลบ

## 5. Security analysis

- **Privilege escalation:** ไม่มี path ให้ผู้ใช้เขียน `admin_permissions` เอง (no write policy; grant RPC ตรวจ super admin); super admin เปลี่ยนได้ผ่าน migration เท่านั้น
- **Deny by default:** helper คืน false สำหรับ system/level ที่ไม่รู้จัก, ผู้ใช้ที่ไม่ล็อกอิน, หรือไม่มีแถว
- **Lockout:** super admin อยู่นอก API จึงไม่ถูกถอนโดยไม่ได้ตั้งใจ; ถ้า seed ผิด แก้ได้ด้วย migration
- **Behavior drift ระหว่างย้าย:** ขั้น 2 แยกระบบละ PR และมี equivalence test ก่อน/หลัง
- **Security definer:** ทุก function ใหม่ `set search_path = ''`, revoke จาก `public, anon`, grant เฉพาะ `authenticated`

## 6. Rollback

- ขั้น 1 additive ล้วน: rollback = ไม่ใช้ (ตารางว่างไม่กระทบอะไร) หรือ drop ตารางใหม่ด้วย approved migration
- ขั้น 2: ทุก migration มีไฟล์ rollback ที่คืนนิยาม function เดิม (ดึงจาก production ก่อนแก้) ; ระหว่างนั้นสามารถให้ `has_admin_permission` fallback เป็น role เดิมได้ในจุดเดียว
- ขั้น 3: revert PR ของ admin app

## 7. Open questions (ต้องให้ Founder ตอบก่อน implement)

- **Q1:** บัญชีที่เป็น `admin` อยู่ตอนนี้ (นอกจาก Founder) จะได้สิทธิ์อะไร
- **Q2:** วันนี้ moderator **แบน/ระงับผู้ใช้** ได้ — การลงโทษผู้ใช้นับเป็นงานของ Social (moderator ทำต่อได้) หรือ Account
- **Q3:** Audit log (รวมทุกระบบ) ให้ใครดู — super admin เท่านั้น หรือทุกคนเห็นเฉพาะระบบที่ตัวเองมีสิทธิ์

## 8. Estimated effort / cost

- ไม่มีค่า infrastructure เพิ่ม
- งานใหญ่ที่สุดคือขั้น 2 (~60 function) — แยกเป็น 6 PR ตามระบบ
