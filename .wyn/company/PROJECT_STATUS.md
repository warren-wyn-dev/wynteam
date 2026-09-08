# WYN Project Status (ผลตรวจสอบ repository)

> ตรวจสอบล่าสุด: 2026-09-08 จาก codebase, manifests, Git history, CI/CD workflows และ deployment logs ใน repository

## 1. Repository

- Repository: `warren-wyn-dev/wynteam`
- โครงการไม่ใช่ blank slate แล้ว: มี consumer app, admin panel, Supabase backend, automated tests และ CI/CD
- Git history และ branch เปลี่ยนต่อเนื่องตาม task/PR; ให้ใช้ `git status`, `git log` และ GitHub เป็นข้อมูลปัจจุบันแทนการตรึงชื่อ branch หรือจำนวน commit ไว้ในเอกสารนี้

## 2. ผลิตภัณฑ์และ Framework

### WYNOS Consumer App (`app/`)

- Flutter/Dart app สำหรับ Web, Android และ iOS
- Dart SDK constraint: `>=3.3.0 <4.0.0`; CI และ production web workflow pin Flutter `3.47.1`
- ใช้ Supabase สำหรับ authentication, database และ storage
- integration สำคัญใน manifest ได้แก่ Firebase Cloud Messaging, secure storage, media/video, location และ sharing
- production web: `https://wynos.online` บน Vercel

### WYN Admin (`admin/`)

- Next.js 16 App Router + React 19 + TypeScript + Tailwind CSS + shadcn/ui primitives
- ใช้ Supabase project เดียวกับ consumer app ผ่าน `@supabase/ssr`
- แยก authentication/authorization สำหรับ `admin` และ `moderator`
- มี manual Vercel deployment workflow แยกจาก consumer app

### Design Reference (`design-reference/`)

- เก็บ prototype, product UI references, design philosophy และ specification
- เป็น reference ไม่ใช่ production runtime package

## 3. Backend และ Database (`supabase/`)

- PostgreSQL schema หลักอยู่ที่ `supabase/schema.sql`
- incremental migrations แยกเป็น `supabase/migrations_*.sql`
- มี RLS, RPC/functions, views, indexes และ schema regression tests
- มี Supabase Edge Functions อย่างน้อย `send-push-notification` และ `location-search`
- `schema.sql` อาจ drift จาก production ได้; migration ที่แตะ view ต้องทำตาม `.wyn/docs/engineering/checklist-db-migration-touching-a-view.md` และตรวจนิยามจริงจาก production ก่อน
- การเปลี่ยน authentication/security architecture หรือ destructive database structure ยังต้องได้รับอนุมัติจาก Founder ตาม `.wyn/company/RULES.md`

## 4. Authentication และ Access Control

- Consumer app รองรับ Supabase Auth; UI ปัจจุบันเปิด Google และ email/password ตาม release notes
- Apple, phone/SMS และ guest entry point ถูกปิด/พักไว้ตาม configuration และ Founder decisions ปัจจุบัน
- Admin ตรวจ `platform_role` ฝั่ง server ก่อนให้เข้าพื้นที่ protected
- ฟีเจอร์ user-facing ใหม่ใช้ developer-account allowlist เป็น staged rollout ตาม WYN-125; ผู้ใช้ทั่วไปต้องไม่เห็นฟีเจอร์จนกว่า Founder จะสั่งเปิด

## 5. Tests และ CI

GitHub Actions workflow `.github/workflows/ci.yml` ทำงานบน pull request และ push เข้า `main` โดยมี 4 jobs:

1. **Flutter** — `flutter analyze` และ `flutter test`
2. **Admin** — ESLint, Next type generation และ TypeScript typecheck
3. **Supabase Edge Functions** — `deno check` และ `deno test`
4. **Schema ordering** — `python3 supabase/check_schema_ordering.py`

ข้อจำกัดที่บันทึกไว้ใน CI:

- Admin CI ยังไม่รัน `next build` เพราะ build-time Supabase environment variables ไม่ควรอยู่ใน CI ทั่วไป
- `supabase/tests/*.sh` ยังไม่รวมใน CI เพราะต้องใช้ local PostgreSQL; ต้องรันแยกเมื่อแก้ schema/RLS ที่เกี่ยวข้อง
- automated tests ไม่แทน QA บนอุปกรณ์จริงและ production verification

## 6. Deployment

- `.github/workflows/deploy-web.yml` — build Flutter Web และ deploy WYNOS ไป Vercel; manual `workflow_dispatch`
- `.github/workflows/deploy-admin.yml` — deploy Next.js admin ไป Vercel; manual `workflow_dispatch`
- `.github/workflows/deploy-edge-functions.yml` — ตรวจและ deploy Supabase Edge Function ที่เลือก; manual `workflow_dispatch`
- schema/migration workflows แยกตาม task และต้องปฏิบัติตาม approval/deployment records
- production deployment ต้องผ่าน QA และได้รับคำสั่ง/อนุมัติตาม `.wyn/company/WORKFLOW.md`; ห้ามถือว่า merge เท่ากับ deploy

## 7. Version ปัจจุบัน

- **Production สำหรับผู้ใช้ทั่วไป:** WYNOS v1.0.0 Beta4
- **กำลังพัฒนา:** WYNOS v1.0.0 Beta5 เฉพาะ developer accounts ผ่าน staged rollout
- Source of truth: `.wyn/company/VERSION_CONTROL.md`
- `RELEASE_NOTES.md` เก็บ current release summary และ historical Beta1 snapshot
- Owner เท่านั้นที่ประกาศ version ใหม่หรือสั่ง rollback; agent ห้ามเปลี่ยน version/rollback เอง

## 8. Task Tracking Snapshot

Snapshot ณ 2026-09-08 จาก `.wyn/tasks/`:

| สถานะ | จำนวนไฟล์ `WYN-*.md` |
|---|---:|
| backlog | 3 |
| active | 1 |
| review | 0 |
| qa | 1 |
| bugs | 25 |
| approved | 102 |
| completed | 30 |

ข้อสังเกต:

- จำนวนไฟล์เป็น inventory ไม่ใช่หลักฐานว่า production state ตรงกับชื่อโฟลเดอร์ทุกไฟล์
- พบ legacy duplicate ID เช่น `WYN-024` มากกว่าหนึ่งไฟล์ใน `bugs/`; ห้าม rename/delete โดยไม่มี audit เพราะอาจมี commit, PR และ log อ้างอิงชื่อเดิม
- ก่อนเลือกงานใหม่ให้เทียบ task file กับ Git history, PR, QA record และ deployment log แล้วค่อยย้ายสถานะ
- security-related bugs (เช่น RLS, role bypass, RPC exposure และ identity leak) ควรถูก triage ก่อน UX backlog แต่การเปลี่ยน security architecture ต้องขอ Founder อนุมัติ

## 9. Known Documentation Drift

- `app/README.md` ยังเป็น snapshot ระยะแรก (กล่าวถึง WYN-002 และจำนวน test เก่า) จึงใช้เป็น setup/history reference เท่านั้น ไม่ใช่ project-wide status
- task folders มีทั้ง historical records และสถานะงานจริง; ห้ามสรุปจากจำนวนไฟล์อย่างเดียว
- production truth ต้องตรวจจาก deployment logs และ production verification ไม่ใช่จาก code merge เพียงอย่างเดียว

## 10. จุดเริ่มต้นสำหรับ Agent รอบถัดไป

1. อ่านเอกสารบังคับทั้งหมดใน `AGENTS.md`
2. ตรวจ `.wyn/company/CONTEXT.md`, `.wyn/company/DECISIONS.md` และ `.wyn/company/VERSION_CONTROL.md`
3. หา Product/Design spec และ task file ที่ตรงกับงาน
4. ตรวจ Git/PR/deployment state จริงก่อนเปลี่ยนสถานะ task
5. ทำ smallest safe change, รัน checks ที่เกี่ยวข้อง และส่ง QA ก่อน production
