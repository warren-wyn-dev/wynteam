# Contributing to WYN

Repository นี้พัฒนาโดยทีม **WYN AI Company** ภายใต้การกำกับดูแลของ Founder โปรดอ่าน [`AGENTS.md`](./AGENTS.md) และเอกสารใน `.wyn/company/` ก่อนเริ่มงานทุกครั้ง

## Workflow

```
Founder → Product → Design → Coding → QA & Security → PASS → Deploy
                                          │
                                         FAIL → Debug → Coding → QA → PASS → Deploy
```

รายละเอียดเต็มที่ `.wyn/company/WORKFLOW.md`

## กติกาภาษา

- สื่อสาร/รายงาน: ภาษาไทยเป็นหลัก
- โค้ด (ตัวแปร, ฟังก์ชัน, class, component, API, database field, file name, git branch): ภาษาอังกฤษ

## Commit Convention

ใช้ conventional commits ภาษาอังกฤษ:

```
feat: add profile system
fix: resolve login issue
test: add profile regression tests
docs: update product requirements
```

## Continuous Integration (CI)

`.github/workflows/ci.yml` รันอัตโนมัติทุก pull request และทุก push เข้า `main` — ไม่ต้องกดเอง

Workflow ที่เป็น manual (`workflow_dispatch`) มี 2 ตัว:

| Workflow | ทำอะไร | ทำไมต้องกดเอง |
|---|---|---|
| `deploy-web.yml` | build Flutter web → Vercel production (`wynos.online`) | โควตา deploy ของ Vercel free tier ใช้ร่วมกันทั้งบัญชี |
| `deploy-edge-functions.yml` | deploy Supabase Edge Function 1 ตัวที่เลือก | การปล่อยโค้ดฝั่ง server เป็นการตัดสินใจ ไม่ควรติดไปกับทุก merge |

**`deploy-edge-functions.yml` ต้องมี secret `SUPABASE_ACCESS_TOKEN`** (personal access token จาก https://supabase.com/dashboard/account/tokens) — project ref ถูกดึงมาจาก `SUPABASE_URL` ที่มีอยู่แล้ว จึงไม่ต้องเพิ่ม secret ตัวที่สอง

**ข้อควรระวัง:** ก่อน Beta4 Edge Function ถูก deploy ด้วยมือจากเครื่องใครสักคน ผลคือ Beta4 แก้ `send-push-notification` แล้ว merge และ deploy web ไปแล้ว แต่ function ที่รันจริงบน production ยังเป็นตัวเก่า — **แก้ไฟล์ใน `supabase/functions/` เมื่อไหร่ ต้อง deploy แยกเสมอ `deploy-web.yml` ไม่ได้ deploy ให้**

| Job | รันอะไร |
|---|---|
| Flutter — `app` / `seller_app` | `flutter analyze` + `flutter test` (matrix, แยกผลกันคนละ job) |
| Admin (Next.js) | `npm run lint` + `next typegen` + `tsc --noEmit` |
| Supabase Edge Functions | `deno check` (index.ts) + `deno test` |
| schema.sql ordering | `python3 supabase/check_schema_ordering.py` (regression test ของ SCHEMA-001) |

**สิ่งที่ CI ยังไม่ครอบคลุม — ยังต้องตรวจเอง:**

- `supabase/tests/*.sh` (30+ ไฟล์) ต้องมี PostgreSQL 16 ที่สร้าง database ได้ ยังไม่ได้ต่อเข้า CI — นี่คือ automated coverage เดียวที่ RLS policy กับ view definition มี
- `next build` ของ admin (ต้องใช้ credential จริงตอน prerender)
- QA เชิงพฤติกรรม/ความปลอดภัยทั้งหมด — CI แทน AI QA & Security ไม่ได้ ดู `.wyn/company/WORKFLOW.md`

**ข้อควรระวัง:** `flutter-version` ใน `ci.yml` ถูก pin ให้ตรงกับ `deploy-web.yml` เป๊ะๆ ถ้าแก้ไฟล์ไหนต้องแก้อีกไฟล์ด้วยเสมอ — ไม่งั้น CI เขียวด้วย SDK คนละตัวกับที่ build ขึ้น production ซึ่งทำให้ CI ที่เขียวไม่มีความหมาย

## Change Control

- เปลี่ยนแปลงเท่าที่จำเป็น หลีกเลี่ยง refactor ที่ไม่เกี่ยวข้อง
- อธิบายเหตุผลของการเปลี่ยนแปลงเสมอ
- รัน test/lint/build ที่มีอยู่ก่อน commit
- การเปลี่ยนแปลงสถาปัตยกรรมหลัก/ความปลอดภัย/production ต้องขออนุมัติ Founder ก่อน (ดู `.wyn/company/RULES.md`)

## ความปลอดภัย

ห้าม commit secrets, credentials, หรือ environment files ที่มีข้อมูลอ่อนไหวเด็ดขาด ดู `.wyn/company/RULES.md`
