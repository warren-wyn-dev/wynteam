# Deployment — Club feed/composer restyle, invite button, unread-badge fixes

วันที่: 2026-09-05 17:16–17:19 UTC
Deploy โดย: AI Deploy & DevOps (session `session_014LEtwe8NjiPLcc9cqJEkuq`) ตามคำสั่ง Founder "ใช่ deploy เลย" หลัง QA PASS
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team

## สิ่งที่ deploy

- Commit: `0cfe827` (merge commit ของ PR #247 เข้า `main`, รวมงานจาก PR #244–#247 ทั้งหมด)
- PRs:
  - #244 — สำรวจ Club แทนที่ "โปรไฟล์" ใน side menu
  - #245 — Club feed/composer restyle ให้เหมือน Home + ปุ่มเชิญเพื่อน
  - #246 — Badge สีแดง + แก้บั๊ก badge ข้อความค้าง
  - #247 — แก้ CI แดงบน main (flutter analyze + บั๊ก crash จริงใน ClubPostCard)
- Workflow run: https://github.com/warren-wyn-dev/wynteam/actions/runs/33980436661 (run #75, `workflow_dispatch` manual)
- ปลายทาง: Vercel project "web" → `wynos.online` (Flutter Web release build)

## สิ่งที่เปลี่ยน

| งาน | สาระ |
|---|---|
| Side menu | ลบแถว "โปรไฟล์" (ซ้ำกับบล็อกโปรไฟล์ด้านบนอยู่แล้ว) แทนที่ด้วย "สำรวจ Club" เปิด `ExploreClubsScreen` |
| Club feed | `ClubPostCard` restyle ให้ใช้ layout สองคอลัมน์ + แถว Like/Comment แบบเดียวกับ `HomeDropCard` (Share/Save ย้ายไปเมนู "...") |
| Club composer | `CreateClubPostScreen` restyle ให้ใช้ header/เลย์เอาต์แบบเดียวกับ `CreateDropScreen` (หัว "ยกเลิก"/"โพสต์" แบบ pill, avatar, กล่องข้อความใหญ่) พร้อมชิปล็อกปลายทาง "โพสต์ใน [ชื่อ Club]" |
| เชิญเพื่อน | ปุ่ม "เชิญเพื่อน" ใหม่ในแท็บ Members (เฉพาะสมาชิกที่ approved แล้ว) ใช้ flow แชร์ไปแชทเดิมที่มีอยู่แล้ว |
| Unread badge | ไอคอนข้อความบน Home + กระดิ่ง Notifications เปลี่ยนจากสีน้ำเงิน (`colorScheme.primary`) เป็นสีแดง (`colorScheme.error`) |
| Badge ค้าง | เพิ่มการรีเฟรชเลข unread ของไอคอนข้อความบน Home ตอนแอป resume (`AppLifecycleState.resumed`) เหมือนที่กระดิ่ง Notifications มีอยู่แล้ว แก้ปัญหาเลขค้างหลังอ่านข้อความจากที่อื่น |

## Database

- **ไม่มี migration ใดๆ ในงานชุดนี้** — ทุกการเปลี่ยนแปลงเป็น UI restyle + client-side lifecycle fix + เชื่อมปุ่มใหม่เข้ากับ flow/schema ที่มีอยู่แล้วเดิม ไม่แตะ schema/RLS/RPC ใดๆ เลย

## ผล verification

| รายการ | ผล |
|---|---|
| `flutter analyze` (local, ยืนยันด้วย Flutter SDK จริงที่ clone มาไว้ใน session นี้) | สะอาด |
| `flutter test` เต็มชุด (local, บน `origin/main` ที่ merge แล้วจริง ผ่าน git worktree แยก) | **1199/1199 ผ่าน** |
| Ad-hoc QA probe เพิ่ม (320px overflow, security/authorization review) | ผ่านทั้งหมด — ดูรายละเอียดที่ `.wyn/docs/qa/2026-09-05-club-restyle-invite-badge-qa.md` |
| AI QA & Security formal review | **PASS** |
| CI บน `main` (run #150, commit `0cfe827`) | **success** — Flutter, Admin (Next.js), Supabase Edge Functions, schema.sql ordering ผ่านครบ |
| Deploy workflow run #75 | **success** ครบ 9 step รวม "Deploy to Vercel production" |

### Production verification — **ยังไม่ยืนยัน (ต้องรอ Founder เช็คด้วยตา)**

### สิ่งที่ AI verify เองไม่ได้ จึงต้องให้ Founder ดู

**สภาพแวดล้อมของ session นี้ถูก block ไม่ให้ออกเน็ตไปที่ `wynos.online`** (egress proxy) จึง
**ไม่สามารถยืนยันด้วยตัวเองได้ว่าเว็บจริงเปิดขึ้นและใช้งานได้** ยืนยันได้แค่ว่า workflow รายงาน
success ทุก step ซึ่ง**ไม่เท่ากับ**การพิสูจน์ว่า production ใช้งานได้จริง (บทเรียนจากเหตุการณ์
Vercel 2026-09-02 — ดู `.wyn/company/WORKFLOW.md` หัวข้อ "Production Verification คือใครยืนยัน").

สิ่งที่ Founder ควรเช็คด้วยตาที่ `https://wynos.online`:
1. เปิดเว็บได้ปกติ ไม่ขึ้น `NOT_FOUND` / `DEPLOYMENT_NOT_FOUND`
2. เข้า Club ที่เป็นสมาชิกอยู่ → แท็บ "โพสต์" ต้องมีหน้าตาเหมือนฟีด Home (avatar ซ้าย เนื้อหาขวา แถว Like/Comment แบบเดียวกัน)
3. กดปุ่ม "+" สร้างโพสต์ในคลับ → หน้าโพสต์ต้องมีหัว "ยกเลิก"/"โพสต์" แบบเดียวกับหน้าโพสต์ปกติ ไม่ใช่ AppBar เดิม
4. แท็บ "สมาชิก" ของ Club ต้องมีปุ่ม "เชิญเพื่อน" (ถ้าเป็นสมาชิกที่ approved แล้ว) กดแล้วเปิดหน้าแชร์ไปแชทได้
5. **ไอคอนข้อความมุมขวาบน Home + กระดิ่ง Notifications ที่ bottom nav**: badge ตัวเลขต้องเป็น**สีแดง** ไม่ใช่สีน้ำเงินเหมือนก่อนหน้า
6. ลองอ่านข้อความผ่านทางอื่น (เช่น กดเข้าจาก Notifications หรือ push notification) แล้วกลับมาที่ Home — เลข badge บนไอคอนข้อความต้องอัปเดต ไม่ค้างเลขเดิม (อาจต้องปิด-เปิดแอปใหม่ หรือสลับแอปไปพักแล้วกลับมาเพื่อ trigger resume)
7. เมนูแฮมเบอร์เกอร์ (side menu): ต้องเห็น "สำรวจ Club" แทนที่ "โปรไฟล์" เดิม
8. หมวดหมู่เดิมของแอปที่ไม่เกี่ยวข้อง (ฟีด Home ปกติ, โพสต์ปกติ) ต้องยังทำงานเหมือนเดิมทุกอย่าง ไม่มีอะไรเพี้ยน

## วิธี rollback

**AI ห้าม rollback เองโดยเด็ดขาดไม่ว่ากรณีใด** (`.wyn/company/RULES.md`) ถ้าพัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments →
   หา deployment ก่อนหน้า (run #74, commit `a8be64f`, 2026-09-05 15:29 UTC) → `⋯` → **Promote to Production**
   ใช้เวลาไม่กี่วินาที ไม่ต้อง build ใหม่
2. **ผ่าน CI**: `git revert -m 1 0cfe827` บน `main` แล้ว push → รัน `deploy-web.yml` (`workflow_dispatch`) ใหม่ (ช้ากว่า)

**ไม่มีคอลัมน์ฐานข้อมูลให้ rollback** — งานชุดนี้ไม่มี migration ใดๆ เลย

## หมายเหตุ

- ระหว่างเตรียม deploy พบและแก้ CI แดงจริง 2 รอบบน `main` ก่อน deploy รอบนี้จะเริ่ม (PR #247)
  รวมถึงบั๊ก crash จริงจาก `Flexible` ที่ใช้ผิดที่ใน `ClubPostCard` — ดูรายละเอียดเต็มที่
  `.wyn/docs/qa/2026-09-05-club-restyle-invite-badge-qa.md`
- แนะนำให้ทีม Coding clone Flutter SDK (`git clone --depth 1 -b stable https://github.com/flutter/flutter.git`)
  ไว้ใน sandbox ทุกครั้งที่เริ่มงาน เพื่อรัน `flutter analyze`/`flutter test` ได้จริงก่อน push แทนที่จะพึ่ง CI ของ GitHub อย่างเดียว
