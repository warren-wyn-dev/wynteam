# ZOKY Admin

หลังบ้านของ **ZOKY Food** และ **ZOKY Merchant** แยกจาก WYNOS Admin (`admin/`) ตาม ZOKY-ADMIN-001 — Founder อนุมัติ 2026-10-25 (`.wyn/docs/product/zoky-admin-001-split-proposal.md`, `.wyn/company/APPROVALS.md`)

Stack เดียวกับ `admin/`: Next.js (App Router) + TypeScript + Tailwind CSS + shadcn/ui (เขียนเอง) เชื่อม Supabase project เดิมผ่าน `@supabase/ssr` โดเมนเป้าหมาย `zoky-admin.wynos.online` (Vercel project แยก — ยังไม่ได้สร้าง)

## Access

เข้าได้เฉพาะ super admin หรือบัญชีที่มีสิทธิ์ WYN-219 `food` หรือ `merchant` (`mayEnterZokyAdmin`, `lib/auth.ts`) — ตรวจฝั่ง server ทั้งตอน login และใน layout; ไม่มี fallback ตาม `platform_role` และถ้าอ่านสิทธิ์ไม่ได้จะปิดไว้ (fail closed) ทุกหน้าและ RPC ยังตรวจสิทธิ์ระบบ/ระดับของตัวเองซ้ำ

## Status

PR 1 (scaffold): login, auth gate, sidebar/drawer, หน้าภาพรวม — เมนู Food/Merchant ยังเป็น "เร็วๆ นี้" จนกว่าหน้าจะย้ายมาจาก `admin/` ใน PR ถัดไป

## Shared shell

`components/ui/*`, `lib/supabase/*`, `lib/utils.ts`, `lib/admin-systems.ts`, `lib/admin-permissions.ts`, `components/admin/{sidebar,header,nav-state,no-access}.tsx` copy มาจาก `admin/` (ตัดสินใจไม่ใช้ npm workspaces ในรอบนี้) — แก้ bug ในไฟล์เหล่านี้ให้ตรวจอีกแอปด้วย

## Getting Started

```bash
npm install
cp .env.local.example .env.local   # NEXT_PUBLIC_SUPABASE_URL / _PUBLISHABLE_KEY
npm run dev
```

## Scripts

- `npm run dev` — dev server
- `npm run build` — production build (รวม TypeScript check)
- `npm run lint` — ESLint
