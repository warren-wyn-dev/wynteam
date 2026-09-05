# Deployment — Home chat-badge tab-switch fix

วันที่: 2026-09-05 17:49–17:52 UTC
Deploy โดย: AI Deploy & DevOps (session `session_014LEtwe8NjiPLcc9cqJEkuq`) ตามคำสั่ง Founder ("ใช่ deploy เลย" หลังรายงานว่า item 6 ในรอบ deploy ก่อนหน้ายังไม่อัปเดต)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team

## บริบท

Deploy รอบก่อนหน้า (`.wyn/logs/deployments/2026-09-05-club-restyle-invite-badge-deploy.md`,
run #75, commit `0cfe827`) ขึ้น production สำเร็จ แต่ Founder เช็คแล้วรายงานว่า **ข้อ 6
ยังไม่อัปเดต** — เลข badge ข้อความบน Home ยังค้างอยู่หลังอ่านข้อความจากแท็บ Notifications
แล้วสลับกลับมา Home

## Root cause

Fix รอบก่อน (`didChangeAppLifecycleState` รีเฟรชตอนแอป resume) ใช้ได้เฉพาะตอนแอปจริงถูก
background แล้ว foreground กลับมา (เช่น สลับแอปบนมือถือ) แต่ **WYNOS ที่ deploy บน
wynos.online เป็น Flutter Web build** — การสลับแท็บ bottom-nav (Home ↔ Notifications) ใน
เว็บเป็นแค่การสลับ index ของ `IndexedStack` ไม่เคยทำให้ browser tab ถูก background/
foreground เลย จึงไม่เคย trigger `AppLifecycleState.resumed` ตามที่ fix รอบก่อนพึ่งพา

## สิ่งที่ deploy

- Commit: `b662921` (merge commit ของ PR #248 เข้า `main`)
- PR: https://github.com/warren-wyn-dev/wynteam/pull/248 (merge โดย AI เอง หลัง CI เขียว
  — PR ไม่ auto-merge เหมือนรอบก่อนๆ ภายในเวลาที่รอ)
- Workflow run: https://github.com/warren-wyn-dev/wynteam/actions/runs/33982135531 (run #77, `workflow_dispatch`)
- ปลายทาง: Vercel project "web" → `wynos.online` (Flutter Web release build)

## สิ่งที่เปลี่ยน

เพิ่มสัญญาณที่สอง (`homeTabActivatedSignal`) เลียนแบบกลไก `homeTabReselectSignal` ที่มีอยู่
แล้วเป๊ะๆ: `RootShell._onDestinationSelected` bump สัญญาณนี้ทุกครั้งที่แท็บ Home ถูกเลือก
**จากแท็บอื่น** (ไม่ใช่กดซ้ำตอนอยู่ Home อยู่แล้ว ซึ่งเป็นหน้าที่ของสัญญาณเดิม) —
`HomeFeedScreen` ฟังสัญญาณนี้แล้วรีเฟรชเฉพาะเลข badge ข้อความ ไม่โหลดฟีดใหม่ทั้งหมด

## Database

- ไม่มี migration ใดๆ — เป็น client-side fix ล้วนๆ

## ผล verification

| รายการ | ผล |
|---|---|
| `flutter analyze` (local, Flutter SDK จริง) | สะอาด |
| `flutter test` เต็มชุด (local) | **1205/1205 ผ่าน** (เพิ่ม regression test 2 อันสำหรับสัญญาณใหม่) |
| CI บน `main` (run #156, commit `b662921`) | **success** |
| Deploy workflow run #77 | **success** ครบ 9 step รวม "Deploy to Vercel production" |

### Production verification — **ยังไม่ยืนยัน (ต้องรอ Founder เช็คด้วยตาอีกครั้ง)**

**สภาพแวดล้อมของ session นี้ถูก block ไม่ให้ออกเน็ตไปที่ `wynos.online`** เหมือนทุกรอบที่
ผ่านมา — ยืนยันได้แค่ว่า workflow รายงาน success ทุก step

ขอให้ Founder เช็คเฉพาะ**ข้อ 6 ที่ยังไม่ผ่านรอบก่อน** อีกครั้ง:
1. เข้า Notifications tab แล้วเปิดอ่านข้อความสักบทสนทนาหนึ่ง (หรือกด mark-as-read)
2. สลับกลับมาแท็บ Home
3. เลข badge บนไอคอนข้อความมุมขวาบน Home ต้อง**ลดลง/อัปเดตทันที** ไม่ค้างเลขเดิมอีกต่อไป

(ข้ออื่นๆ ที่เช็คผ่านแล้วในรอบก่อน — สีแดงของ badge, Club feed restyle, composer restyle,
ปุ่มเชิญเพื่อน, side menu — ไม่ต้องเช็คซ้ำ เว้นแต่พบความผิดปกติเพิ่มเติม)

## วิธี rollback

**AI ห้าม rollback เองโดยเด็ดขาดไม่ว่ากรณีใด** ถ้าพัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments →
   หา deployment ก่อนหน้า (run #75, commit `0cfe827`, 2026-09-05 17:16 UTC) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 b662921` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

**ไม่มีคอลัมน์ฐานข้อมูลให้ rollback** — ไม่มี migration ในรอบนี้เลย
