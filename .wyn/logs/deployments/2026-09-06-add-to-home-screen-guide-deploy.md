# Deployment — "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" guide + side menu link

วันที่: 2026-09-06 06:24–06:55 UTC
Deploy โดย: AI Deploy & DevOps (session `session_014LEtwe8NjiPLcc9cqJEkuq`)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team — Founder สั่ง "deploy เลย" ตรงๆ หลัง PR merge และ CI เขียว

## Release

Founder ขอหน้าคู่มือสอนเพิ่ม WYNOS (Flutter Web PWA) ไว้ที่หน้าจอหลัก ตามแบบ banner ของ ShopeeFood ที่ส่งมาเป็นตัวอย่าง แล้วให้ทำ Home banner + ลิงก์เมนูข้างจริง

## Version

Commit: `d11633c` (feature branch tip, merge commit ของ `origin/main` เข้ามาแก้ conflict) → merge commit `1170538` เข้า `main` ผ่าน PR #269
PR: https://github.com/warren-wyn-dev/wynteam/pull/269 (เปิดและ merge โดย AI Deploy & DevOps เอง — CI เขียวครบ, mergeable_state: clean, ไม่มี review comment ค้าง)

## เหตุการณ์สำคัญระหว่างทาง — Merge conflict กับ PR #268

ระหว่างที่ PR #269 เปิดอยู่ อีก session หนึ่งได้ merge PR #268 เข้า `main` ไปก่อน ซึ่งทำฟีเจอร์เดียวกันเป๊ะ (Founder feedback เดียวกัน เรื่อง "add to home screen") แบบคนละวิธี:
- PR #268: `AddToHomeScreenBanner` แบบการ์ดคำแนะนำ inline บน Home แยก iOS/Android ในตัว ไม่มีหน้าคู่มือแยก ไม่มีลิงก์เมนู
- PR #269 (นี้): หน้าคู่มือ step-by-step แยกต่างหาก (`add-to-home.html`) + ลิงก์เมนูถาวร

แจ้ง Founder ผ่าน popup ให้เลือกวิธีรวม — Founder เลือก **"เก็บไว้ทั้งคู่แบบคนละจุด"**: เก็บ banner ของ PR #268 ไว้ตามเดิม แล้วเพิ่มลิงก์ "ดูวิธีแบบละเอียด" บน banner นั้นให้เปิดหน้าคู่มือของ PR #269 แทน พร้อมทั้งให้ลิงก์เมนูข้างใช้ logic ตรวจสอบแพลตฟอร์ม (`PwaInstallHint`) ของ PR #268 ร่วมกัน ไม่สร้างซ้ำ ดูรายละเอียดเต็มใน PR #269's description

## QA Status

ไม่มี QA formal แยก — เป็นงาน UI/static page ล้วนๆ ไม่แตะ auth/data/security, ยืนยันด้วย `flutter analyze` (clean) + `flutter test` เต็มชุด (1242/1242 ผ่าน หลัง merge conflict resolve) แทน ตามระดับความเสี่ยงของงาน

## Build Status

- CI บน PR #269 หลัง merge conflict resolve (run #195, commit `d11633c`): **success ทั้งหมด** รวม `Flutter` (analyze+test), `Admin (Next.js)`, `Supabase Edge Functions`, `schema.sql ordering`
- `deploy-web.yml` run #88 (https://github.com/warren-wyn-dev/wynteam/actions/runs/34017627886): **success** ครบทั้ง 9 step รวม `flutter build web --release` และ "Deploy to Vercel production"

## Deployment Target

Vercel project "web" → `https://wynos.online` (Flutter Web release build)

## Changes

- `app/web/add-to-home.html` (ใหม่) — หน้าคู่มือ static เต็มหน้า สอนเพิ่ม WYNOS ที่หน้าจอหลัก: ขั้นตอน iOS Safari 3 ขั้นตอนหลัก (แตะไอคอนแชร์ → เพิ่มที่หน้าจอโฮม → ยืนยัน) + กล่องคำแนะนำ Android/Chrome แบบย่อ ใช้ไอคอนแอปจริง (`icons/Icon-512.png`) ไม่ได้ embed base64
- `app/.gitignore` — เพิ่ม `!/web/add-to-home.html` กันไฟล์หายตอน `flutter create . --platforms web` regenerate
- `app/lib/features/root/presentation/side_menu.dart` — เพิ่มแถวเมนู "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" เปิดหน้าคู่มือแท็บใหม่ แสดงเฉพาะเว็บและยังไม่ได้ติดตั้ง (`PwaInstallHint.shouldOfferInstall` — getter ใหม่ที่เพิ่มเข้าไปให้ใช้ร่วมกับ banner ของ PR #268)
- `app/lib/features/home/presentation/widgets/add_to_home_screen_banner.dart` — เพิ่มลิงก์ "ดูวิธีแบบละเอียด" บน banner เดิมของ PR #268 เปิดหน้าคู่มือข้างต้น
- `app/lib/core/pwa/open_in_new_tab.dart` + `_stub.dart` + `_web.dart` (ใหม่) — helper เปิด URL แท็บใหม่บนเว็บ, no-op บน native build (conditional import ตาม `dart.library.js_interop` แบบเดียวกับของ PR #268)
- **ไม่มี migration, ไม่มี schema/RLS เปลี่ยน**

## Deployment Result

**สำเร็จ** — `deploy-web.yml` run #88 (`workflow_dispatch`, trigger โดย AI Deploy & DevOps ตามคำสั่ง Founder "deploy เลย") status `success` ครบทุก step

## Production Verification

**ยังไม่ยืนยัน** — session นี้ไม่มี network egress ไปหา `wynos.online` (ลอง curl แล้วโดน gateway ตอบ 403 policy denial ตาม `$HTTPS_PROXY/__agentproxy/status`) ต่างจากงาน WYN-113 ก่อนหน้าที่ session นั้นมี egress จริง จึงยืนยันได้แค่ว่า workflow report `success` ครบทุก step เท่านั้น ยังไม่ได้เห็นผลจริงบนเบราว์เซอร์

**Founder ควรตรวจด้วยตัวเองว่า**:
1. เข้า `https://wynos.online/add-to-home.html` เห็นหน้าคู่มือแสดงถูกต้อง (โหมดสว่าง/มืด)
2. เปิดเมนูข้าง (☰) บนเว็บ เห็นแถว "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" (ถ้ายังไม่ได้ติดตั้งเป็น PWA)
3. บน Home feed เห็น banner คำแนะนำเดิม (จาก PR #268) พร้อมลิงก์ใหม่ "ดูวิธีแบบละเอียด" กดแล้วเปิดหน้าคู่มือในแท็บใหม่

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหา ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments → หา deployment ก่อนหน้า run #88 (run #87, commit `d4ef866` — WYN-113) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 1170538` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

**ไม่มี migration ให้ rollback** — ไม่มี schema/database เปลี่ยนแปลงในรอบนี้เลย เป็น client-side/static asset ล้วนๆ ย้อนกลับได้ปลอดภัย 100%
