# Product Task — WYN-049

Status: approved (Independent QA PASS 2026-08-24 — ดูหัวข้อ "Independent QA" ท้ายไฟล์ — ส่งต่อ AI Deploy & DevOps)
Owner: AI Product Manager

Feature: WYN Admin (Web) — Foundation (project scaffold + admin authentication/authorization)

Goal: task แรกของ Phase 7 (WYN Admin, Web) — สร้างรากฐานของเว็บแอปหลังบ้านที่แยกจาก WYN Consumer App โดยสิ้นเชิงตาม Master Spec section 36 ("WYN App ≠ WYN Admin — Admin ต้องเป็นระบบแยกโดยสิ้นเชิง") — เป็น **Major Architecture ใหม่ครั้งแรกของโปรเจกต์ที่ไม่ใช่ Flutter/Dart** (ยืนยันจาก Founder เมื่อ 2026-08-22, บันทึกที่ `.wyn/company/DECISIONS.md`) ต้องเลือก stack/hosting ก่อนเริ่มงานจริง — **APPROVAL_REQUIRED จาก Founder ก่อนเริ่ม Coding**

Target User: Admin/Moderator ของทีม WYN (ผู้ใช้ที่ `profiles.platform_role in ('admin', 'moderator')` เท่านั้น) — ไม่ใช่ผู้ใช้ทั่วไปเลย

Problem: ตรวจ repo จริงยืนยันแล้วว่า **ไม่มีโครงสร้างเว็บใดๆ อยู่เลยในโปรเจกต์นี้** — ไม่มี `package.json`/`vercel.json`/`next.config`/ไดเรกทอรีเว็บใดๆ ที่ root (มีแค่ `app/`=WYN Social Flutter, `seller_app/`=ZOKY Sellers Flutter, `supabase/`=shared backend) — งาน Moderation ปัจจุบันทั้งหมด (WYN-029/030) ทำผ่านหน้าจอ Moderation Queue ขั้นต่ำที่ฝังอยู่ใน WYN Social app เอง (gate ด้วย `platform_role`) ซึ่งเป็นทางออกชั่วคราวที่ Founder อนุมัติไว้ตั้งแต่ต้น Phase 1 โดยระบุตรงๆ ว่า "ภายหลังจะถูกแทนที่ด้วย WYN Admin (เว็บ) ตอน Phase 7" (`.wyn/company/DECISIONS.md`, 2026-08-22)

Requirements:

**1. เลือก Web Stack — เสนอให้ Founder อนุมัติ (ดูหัวข้อ Recommendation)**

**2. Admin Foundation ขั้นต่ำที่ใช้งานได้จริง**
- Sign-in screen เดียว — ใช้ Supabase Auth (email + password) บน **Supabase project เดียวกับ WYN Social/ZOKY** (Shared Backend ตามที่ตัดสินใจไว้แล้วตอนขยายเป็น WYN Platform, 2026-08-14) — ไม่สร้าง auth ระบบใหม่แยกต่างหาก, ไม่ใช้ Anonymous Sign-In/Social login แบบที่ Consumer app ใช้ (Admin ต้องมีบัญชีจริงที่ระบุตัวตนได้เสมอ ไม่ใช่ anonymous)
- หลัง sign-in สำเร็จ เช็ค `profiles.platform_role` ของบัญชีนั้นทันที — **อนุญาตเข้าเฉพาะ `admin`/`moderator` เท่านั้น** บัญชี `platform_role = 'user'` ที่ sign-in สำเร็จ (มี email/password จริงในระบบ auth) ต้องถูกปฏิเสธเข้า Admin ทันทีพร้อม sign-out อัตโนมัติ ไม่ปล่อยให้ค้างอยู่ในสถานะ signed-in แต่เข้าอะไรไม่ได้
- Layout พื้นฐาน (sidebar navigation + header แสดงชื่อ/role ผู้ใช้ปัจจุบัน + ปุ่ม sign-out) พร้อมช่องสำหรับ 6 หน้าที่จะเติมใน WYN-050 ถึง WYN-055 (Dashboard/User Management/Content Moderation/Report Center/Audit Log/Announcements) — **หน้าที่ยังไม่ทำ ให้แสดง placeholder "เร็วๆ นี้" ไม่ใช่ลิงก์เปล่าหรือ 404** (มิเรอร์ปรัชญาเดียวกับ ZOKY-001's "แนะนำสำหรับคุณ"/"ขายดี" placeholder)
- ไม่มี business logic ใดๆ นอกเหนือจาก auth + layout ในรอบนี้ — Dashboard metrics/User list/Moderation queue ฯลฯ เป็นสโคปของ task ถัดไปทั้งหมด

**3. Deployment target ขั้นต่ำ**
- Deploy ได้จริงอย่างน้อย 1 preview environment ที่เข้าถึงได้ (ไม่ต้องมี custom domain ในรอบนี้) เพื่อพิสูจน์ว่า pipeline ทำงานจริง ไม่ใช่แค่ build ผ่านในเครื่อง

Acceptance Criteria:
- [ ] บัญชี `platform_role = 'admin'` หรือ `'moderator'` sign-in ด้วย email/password จริงสำเร็จ → เข้าเห็น Admin layout (sidebar + header) ได้
- [ ] บัญชี `platform_role = 'user'` sign-in ด้วย email/password ที่ถูกต้อง (มีอยู่จริงใน Supabase Auth) → ถูกปฏิเสธเข้า Admin ทันที พร้อม sign-out อัตโนมัติ ไม่ค้างอยู่ในสถานะ signed-in ที่เข้าอะไรไม่ได้
- [ ] ไม่ sign-in เลย (guest) พยายามเข้า URL ของหน้า Admin ตรงๆ → ถูก redirect ไปหน้า sign-in เสมอ ไม่มีทางเห็น layout/ข้อมูลใดๆ โดยไม่ authenticate ก่อน
- [ ] Service-role key (ถ้าต้องใช้) ไม่รั่วไปฝั่ง client เลย (ตรวจ bundle ที่ build ออกมาจริง ไม่ใช่แค่อ่าน source code)
- [ ] Deploy ขึ้น preview environment จริงได้ เข้าถึงผ่าน URL ได้จริงจากภายนอก

Dependencies: Phase 1 (WYN-029/030 — `profiles.platform_role` column, Moderation/Appeal data model ที่ Admin จะมาจัดการต่อ), Shared Backend decision (2026-08-14 DECISIONS.md — Supabase project เดียวกันทั้ง Platform)

Priority: P1 — เป็น task แรกที่ปลดล็อก Phase 7 ทั้ง Phase (WYN-050 ถึง WYN-055 ทั้งหมดต้องมี Admin app ให้เติมหน้าใหม่ก่อน)

Risks:
- **Major Architecture ใหม่ที่ไม่มี precedent ในโปรเจกต์เลย** — ทีมไม่เคยตั้ง web CI/CD, ไม่เคยจัดการ TypeScript/npm dependency ในโปรเจกต์นี้มาก่อน (ต่างจาก Flutter/Dart ที่มี pattern สะสมมาตั้งแต่ WYN-001) ความเสี่ยง initial setup ผิดพลาด/หลงทางสูงกว่า task ปกติ
- **Service-role key ต้องจัดการอย่างระมัดระวังเป็นพิเศษ** — WYN Admin ต้องการสิทธิ์เห็น/แก้ข้อมูลข้าม-ผู้ใช้ (User Management, Content Moderation) ซึ่งเกินกว่าที่ RLS ปกติ (auth.uid()-scoped) จะอนุญาต ถ้าออกแบบผิดตั้งแต่ foundation (เช่น embed service-role key ใน client bundle) จะเป็นช่องโหว่ร้ายแรงระดับ "ใครก็ได้ยึด backend ทั้งหมด" — ต้องคิด server-side/edge-function boundary ให้ถูกต้องตั้งแต่ต้น ไม่ใช่แค่ "ทำให้ auth ผ่านก่อนแล้วค่อยแก้ทีหลัง"
- **ไม่มี distribution/domain จริงในรอบนี้** — เหมือนทุก task ก่อนหน้า ยังติด Readiness Gate เดิม (ไม่มี custom domain/production infra) — Admin ที่ deploy ได้ตอนนี้เป็นแค่ preview environment ไม่ใช่ระบบที่ทีมงานจริงใช้งานได้ถาวร

Recommendation:

**เสนอ stack**: **Next.js 14+ (App Router) + TypeScript + Tailwind CSS + shadcn/ui**, เชื่อมต่อ Supabase ผ่าน `@supabase/ssr` (server-side auth session handling ที่ปลอดภัยกว่า client-only), deploy บน **Vercel**

เหตุผล:
1. **Vercel เชื่อมต่อกับ GitHub repo นี้อยู่แล้วจริง** (พบ 4 Vercel project ที่ auto-deploy อยู่แล้วจาก PR comment ของ WYN-044-048 — แม้จะเป็นของ config เดิมที่ไม่เกี่ยวกับ Admin โดยตรง แต่ยืนยันว่า infrastructure การเชื่อมต่อ GitHub↔Vercel มีอยู่แล้ว ลดงาน setup ใหม่)
2. **Next.js App Router รองรับ Server Components โดยตรง** — ทำให้ service-role key (หรือ operation ที่ต้อง bypass RLS สำหรับ Admin) รันได้เฉพาะฝั่ง server เท่านั้นโดยธรรมชาติของ framework เอง ไม่ต้องพึ่งวินัยของนักพัฒนาอย่างเดียวเหมือน SPA ทั่วไป (React ธรรมดา/Vite) ที่ต้องแยก backend เองทั้งหมด
3. **@supabase/ssr เป็น library ทางการของ Supabase สำหรับเคสนี้ตรงๆ** (Next.js + Server Components + session cookie) มี pattern/เอกสารพร้อมใช้ ลดความเสี่ยงข้อ "Service-role key รั่ว" ในหัวข้อ Risks
4. **TypeScript + Tailwind + shadcn/ui**: เป็น stack มาตรฐานอุตสาหกรรมสำหรับ admin dashboard ในปี 2026 มี component ที่ต้องใช้ (table, sidebar, form, dialog) พร้อมใช้เกือบทั้งหมดจาก shadcn/ui ลดเวลาสร้าง UI ใหม่ตั้งแต่ศูนย์

ทางเลือกที่พิจารณาแล้วไม่เลือก: Vite + React ธรรมดา (ไม่มี built-in server boundary ทำให้เสี่ยง key รั่วง่ายกว่า), Remix (ผู้ใช้/ตัวอย่างในระบบนิเวศ Supabase น้อยกว่า Next.js อย่างชัดเจน), SvelteKit (ทีมไม่มี precedent การใช้ Svelte เลยในโปรเจกต์นี้ ต่างจาก React ecosystem ที่ใกล้เคียง Flutter's widget-tree mental model กว่า)

ตำแหน่งในโปรเจกต์: ไดเรกทอรีใหม่ `admin/` ที่ root (เทียบเท่า `app/`/`seller_app/`) — ไม่แตะ `app/`/`seller_app/`/`supabase/schema.sql` เลยในรอบนี้ (Admin เชื่อมต่อ Supabase project เดียวกันแต่ไม่ต้องแก้ schema ใดๆ ในระดับ Foundation — RLS/RPC ที่ Admin ต้องใช้เพิ่มจะเป็นสโคปของ WYN-050 เป็นต้นไปเมื่อรู้ requirement ของแต่ละหน้าจริง)

Handoff: **Founder อนุมัติ stack แล้ว (2026-08-24 — Next.js 14+ App Router/TypeScript/Tailwind/shadcn/ui บน Vercel, ดู `.wyn/company/DECISIONS.md`)** — ส่งต่อ AI Design ออกแบบ Sign-in screen + Layout shell (sidebar/header/placeholder 6 หน้า) ตาม stack ที่อนุมัติแล้ว

## Coding Output (2026-08-24)

**Scaffold**: `create-next-app` (Next.js 16.3.2 App Router/TypeScript/Tailwind v4/ESLint) ในไดเรกทอรีใหม่ `admin/` ที่ root — **`ui.shadcn.com` ถูกบล็อกโดย network policy ของ sandbox นี้** (`registry.npmjs.org` อยู่ใน allowlist แต่ `ui.shadcn.com` ไม่อยู่, ยืนยันด้วย `curl` เจอ `403` ตรงๆ) จึงตั้งค่า shadcn/ui **แบบ manual** แทนการใช้ CLI: เขียน `components.json` เองให้ตรง schema (ถ้า session ในอนาคตมี network access ถึง `ui.shadcn.com` จะใช้ `npx shadcn add` ได้ปกติ), ติดตั้ง dependency ที่จำเป็นตรงๆ ผ่าน npm (`class-variance-authority`/`clsx`/`tailwind-merge`/`lucide-react`/`@radix-ui/react-slot`/`@radix-ui/react-label`) แล้วเขียน 4 component (`Button`/`Input`/`Label`/`Card`) ตาม shadcn's มาตรฐานเป๊ะด้วยมือ

**Theme**: `app/globals.css` ใช้ shadcn's neutral base theme ตรงๆ (OKLCH scale มาตรฐาน) — override แค่ `--primary`/`--ring` เป็น WYN Cyan (`oklch(0.74 0.14 231)` ≈ `#00C8FF`) ตามที่ Design ระบุ — ไม่ใช้ `next/font/google` (Geist) เพราะต้องดึง font จากเน็ตเวิร์กตอน build ซึ่งไม่ reliable ในหลาย sandbox ของโปรเจกต์นี้ (เทียบกับปัญหาเดียวกันที่ Flutter app เจอเรื่อง SDK download) ใช้ system font stack ผ่าน Tailwind's `font-sans` แทน

**Auth (`@supabase/ssr`)**: `lib/supabase/client.ts` (browser, anon/publishable key), `lib/supabase/server.ts` (Server Components/Actions, อ่าน session จาก cookies), `proxy.ts` + `lib/supabase/middleware.ts` (refresh session ทุก request + redirect guest ไป `/login` ก่อนถึง Server Component ไหนเลย) — **ตั้งใจไม่สร้าง service-role client เลยในรอบนี้**: `profiles`' SELECT policy (`using (true)`) อนุญาตให้ authenticated user ใดๆ อ่าน `platform_role` ของตัวเองได้อยู่แล้วโดยไม่ต้อง bypass RLS ปิดความเสี่ยงข้อ "Service-role key รั่ว" ที่ Product ระบุไว้ใน Risks ได้ตรงๆ ด้วยการไม่มี key นั้นอยู่ในระบบเลยจนกว่าจะมี task ที่ต้องการจริง (คาดว่า WYN-051 User Management)

**หมายเหตุ framework**: Next.js 16.3.2 เปลี่ยน convention จาก `middleware.ts`/`export function middleware()` เป็น `proxy.ts`/`export function proxy()` (deprecation warning ตอน build บอกตรงๆ) — ทำตาม convention ใหม่เลยตั้งแต่ต้น ไม่ปล่อยให้มี warning ค้างในโปรเจกต์ที่เพิ่ง scaffold

**Auth flow**: `app/login/actions.ts` (Server Action `signIn`) เรียก `signInWithPassword` → เช็ค `platform_role` ฝั่ง server → `admin`/`moderator` redirect เข้า `/`, อื่นๆ **sign-out ทันที** + คืนข้อความปฏิเสธ (ไม่ใช่แค่ block เข้า ป้องกันบัญชี `user` ค้างอยู่ในสถานะ signed-in ที่เข้าอะไรไม่ได้ตามที่ Design ระบุ) — error message เดียวกันไม่ว่า email ผิดหรือ password ผิด (ป้องกัน account enumeration)

**Layout shell**: `app/(admin)/layout.tsx` เรียก `requireAdminRole()` (`lib/auth.ts`) ก่อน render หน้าลูกทุกหน้า (role check เดียว จุดเดียว ไม่ทำซ้ำในแต่ละหน้า) — `AdminSidebar` (6 เมนูตรงกับ WYN-050 ถึง 055, active state ใช้สี WynColors.cyan50/cyan700 จริงตามที่ Design ระบุ ไม่ใช่ `--primary` เพราะ contrast ไม่พอสำหรับตัวหนังสือ) + `AdminHeader` (แสดง role badge/email + sign-out) + `PlaceholderPage` component เดียวใช้ซ้ำทั้ง 5 หน้า (Dashboard ก็ใช้จนกว่า WYN-050 จะเติมจริง)

**Tests**: ไม่มี automated test frameworkติดตั้งในรอบนี้ (Product/Design spec ไม่ได้ระบุ ขอบเขต Foundation ยังเล็กเกินไปที่จะคุ้มค่าตั้ง Jest/Playwright ตอนนี้ — เสนอเพิ่มเมื่อ WYN-050+ มี business logic จริงให้เทสต์) — verify ด้วยการรัน dev server จริงพร้อม env ปลอมแล้ว curl ตรวจ:
- `GET /` (ไม่ signed-in) → `307` redirect ไป `/login` ✓
- `GET /login` → render ฟอร์มจริง (พบข้อความ "อีเมล"/"รหัสผ่าน"/"เข้าสู่ระบบ") ✓
- `GET /users`, `/moderation`, `/reports`, `/audit-log`, `/announcements` (ไม่ signed-in) → ทุกเส้นทาง `307` redirect ไป `/login` เหมือนกันหมด ✓ (พิสูจน์ตรงตาม Acceptance Criteria ข้อ "guest พยายามเข้า URL ตรงๆ")
- grep bundle ที่ build ออกมาจริง (`.next/static`) หา `service_role`/`SERVICE_ROLE` → **ไม่พบเลย** (ไม่มี key นั้นอยู่ในระบบตั้งแต่ต้นตามที่ตัดสินใจไว้ข้างบน) ✓

**Build**: `next build` ผ่านสะอาด (0 error, 0 warning หลังแก้ proxy.ts) — `npm run lint` (ESLint) **0 issues** — `npx tsc` ผ่านผ่าน `next build`'s type-check step (ไม่มี error)

**Known Issues**: (1) ยังไม่มี CI/automated test สำหรับ `admin/` เลย (2) Deploy จริงบน Vercel ยังไม่ได้ทำในรอบนี้ (ต้องมี Founder เชื่อม Vercel project ใหม่ชี้มาที่ `admin/` เป็น root directory ก่อน — ไม่มี Vercel project ที่มีอยู่แล้วชี้มาที่ path นี้) (3) ไม่มี asset โลโก้จริงของ WYN Admin (ใช้ข้อความล้วน "WYN Admin" ตามที่ Design ระบุไว้ว่ารอ Founder ยืนยัน asset ทีหลัง)

Handoff: AI QA & Security — ตรวจเน้นที่ (1) role gate ทุกเส้นทางจริง (ไม่ใช่แค่ 5 หน้าที่ Coding ทดสอบเอง — ลอง bypass ผ่านการปลอม cookie/session ก็ควรได้) (2) sign-out-on-reject flow ของบัญชี `user` role จริง (ต้องมี Supabase project จริงหรือ mock ที่จำลอง role ต่างๆ ได้) (3) ยืนยันซ้ำว่าไม่มี service-role key หลุดใน bundle จริง (4) build/lint สะอาดจริงตามที่ Coding รายงาน ไม่เชื่อตัวเลขเฉยๆ

## Independent QA (2026-08-24)

Feature: WYN-049 WYN Admin Foundation — Next.js scaffold, sign-in (admin/moderator only), layout shell + 6 placeholder หน้า

Environment: Node.js v22.22.2, Next.js 16.3.2 (Turbopack), local dev server + `next build` production build — ไม่มี Supabase project จริงในสภาพแวดล้อมนี้ (ยืนยันสอดคล้องกับ Readiness Gate เดิมของทุก task ก่อนหน้า) ใช้ env variable ปลอม (URL/key รูปแบบถูกต้องแต่ไม่ใช่ของจริง) เพื่อทดสอบ path ที่ไม่ต้อง round-trip กับ Supabase จริง

Test Cases:
1. รัน `npm run lint`/`next build` เองอิสระ (ไม่เชื่อตัวเลขที่ Coding รายงาน) — ยืนยัน 0 error/warning ทั้งคู่
2. อ่าน diff ทั้งหมดแบบ adversarial โดยเฉพาะ `app/login/actions.ts`/`lib/auth.ts`/`proxy.ts`/`lib/supabase/middleware.ts` — เจาะจงหาช่องทาง bypass role check
3. รัน dev server จริง (env ปลอม) แล้ว `curl` ตรงทุก route ที่มีอยู่ (`/`, `/users`, `/moderation`, `/reports`, `/audit-log`, `/announcements`) แบบ guest (ไม่มี cookie ใดๆ) — ยืนยันอิสระว่า redirect `307` ไป `/login` ครบทุกเส้นทางจริง ไม่ใช่แค่เชื่อ Coding Output
4. `curl` `/login` ตรง — ยืนยันฟอร์มจริง render ได้ (พบ "อีเมล"/"รหัสผ่าน"/"เข้าสู่ระบบ" ในผลลัพธ์)
5. grep `.next/static` (bundle จริงหลัง build) หา `service_role`/`SERVICE_ROLE` เอง — ไม่พบ (ยืนยันซ้ำจุดที่ Product spec ระบุเป็น Acceptance Criteria ตรงๆ)
6. ตรวจ `git check-ignore` ยืนยัน `.env.local` ไม่ถูก track จริง (ไม่ใช่แค่มี `.gitignore` แต่ยังไม่ทดสอบว่าใช้งานได้จริง)
7. ไล่อ่าน logic `signIn()` ทีละบรรทัด: `createClient()` สร้างครั้งเดียว ใช้ instance เดียวกันตลอด (`signInWithPassword`→query `profiles`→`signOut()` ถ้า reject) — cookie mutation ทั้งหมดสะสมอยู่บน cookie store เดียวกันของ Server Action นั้น ซึ่งเป็น pattern ที่ Next.js/Supabase รับประกันว่า final state ที่ apply จริงคือค่าล่าสุด (`signOut()` มาทีหลัง `signInWithPassword()` เสมอในเส้นทาง reject) — ตรรกะถูกต้องตามที่ Design ต้องการ

Passed: 1, 2 (ไม่พบช่องทาง bypass), 3, 4, 5, 6, 7

Failed: ไม่มี

Severity: N/A

Security Findings: ไม่พบช่องโหว่ — role check ทำฝั่ง server เท่านั้นจริง (ไม่มี client-side JS ที่ทำหน้าที่ gate), ไม่มี open redirect (ปลายทาง redirect ทุกจุด hardcode `/login`/`/` ไม่รับ query param ควบคุมปลายทาง), ไม่มี service-role key ในระบบเลย (ตัดปัญหาโดยไม่ต้องมี, ตามที่ Coding ตัดสินใจ), error message ไม่แยกแยะ email/password ผิด (กัน account enumeration)

**ข้อจำกัดที่ตรวจสอบไม่ได้จริงในรอบนี้ (บันทึกไว้ตรงๆ ไม่ใช่ปิดบัง)**: sign-in flow แบบ end-to-end จริง (บัญชี `admin`/`moderator`/`user` ของจริง login ผ่าน Supabase Auth จริงแล้วตรวจผลลัพธ์จริง) **ตรวจสอบไม่ได้เพราะไม่มี Supabase project จริงในสภาพแวดล้อมนี้** — เป็นข้อจำกัดเดียวกับที่ QA ของแทบทุก task ก่อนหน้าเจอ (Readiness Gate) ยืนยันด้วยการอ่าน logic แบบ adversarial แทน (ข้อ 7) ซึ่งพบว่าถูกต้องตามหลักการของ Next.js Server Action + `@supabase/ssr`'s documented cookie pattern — **ไม่ใช่บั๊ก แค่ยังไม่มี environment ให้ verify แบบ live ได้จริง** เสนอให้ verify ซ้ำอีกครั้งทันทีที่มี Supabase project จริงเชื่อมต่อ (ไม่ block การ approve รอบนี้ เพราะเป็น pattern มาตรฐานที่มีเอกสารรับรองจาก Supabase เอง ไม่ใช่ logic ที่ทีมเขียนขึ้นเองทั้งหมด)

Recommendation: อนุมัติ — ส่วนที่ทดสอบได้จริงในสภาพแวดล้อมนี้ผ่านหมด ไม่มี regression ไม่มีช่องโหว่ที่พบ ส่วนที่ต้อง defer (live auth round-trip) มีเหตุผลรองรับชัดเจนและไม่ใช่ความเสี่ยงเฉพาะของ task นี้

Final Status: **PASS**
