# Deployment — Real fix: mark-conversation-read RPC was a client-side no-op

วันที่: 2026-09-05 18:26–18:29 UTC
Deploy โดย: AI Deploy & DevOps (session `session_014LEtwe8NjiPLcc9cqJEkuq`)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team

## บริบท

Deploy 2 รอบก่อนหน้า (run #75, #77 — ดู `.wyn/logs/deployments/2026-09-05-club-restyle-invite-badge-deploy.md`
และ `2026-09-05-tab-switch-badge-fix-deploy.md`) แก้เรื่อง**เวลารีเฟรช** badge แต่ Founder
เช็คซ้ำ (แม้ reload หน้าใหม่แล้ว) ก็ยังไม่อัปเดต — แสดงว่าปัญหาไม่ใช่แค่เรื่อง trigger การ
รีเฟรช แต่ลึกกว่านั้น

## Root cause (ตัวจริง)

ตรวจสอบด้วย **read-only diagnostic workflow ที่ query production database ตรงๆ**
(`chat-unread-badge-diagnostic.yml`, PR #253) พบว่า:

1. Function `mark_conversation_read`/`count_unread_conversations` บน production **ตรงกับ
   `schema.sql` เป๊ะ ไม่มี schema drift**
2. แต่ `user_a_last_read_at`/`user_b_last_read_at` ของทุกบทสนทนาของ warren เป็น **null
   ทั้งหมด** แม้จะมีข้อความใหม่เข้ามาไม่กี่นาทีก่อนหน้า — ไม่ใช่แค่ค่าเก่า แต่**ไม่เคยถูก
   บันทึกเลยสักครั้ง**

สาเหตุจริง: `supabase-flutter` (ไลบรารีเชื่อมต่อฐานข้อมูล) มี pattern ที่เรียกว่า **lazy
execution** — object ที่ใช้เรียก RPC (`PostgrestBuilder`) จะยิง HTTP request จริงก็ต่อเมื่อ
ถูก `await`/`.then()`/`.catchError()` เท่านั้น ใน `ConversationScreen` (ทั้งตอนเปิดหน้าจอ
และตอนได้รับข้อความใหม่แบบ realtime) โค้ดเรียก `markConversationRead(...)` แบบลอยๆ
ไม่มี `await`/`.then()`/`.catchError()` เลย ผลคือ **request ไม่เคยถูกส่งไปเซิร์ฟเวอร์จริง
แม้แต่ครั้งเดียว** ไม่ว่าจะอ่านข้อความกี่ครั้งก็ตาม — ไม่ใช่ race condition แต่เป็น no-op
จริงๆ ทุกครั้ง

Fix การรีเฟรช badge 2 รอบก่อนหน้า (app-resume + tab-switch) ยังจำเป็นอยู่ (เพื่อให้ badge
รู้ว่าต้องอัปเดต) แต่รอบนี้แก้ที่ต้นเหตุจริง: ทำให้การ "mark ว่าอ่านแล้ว" เกิดขึ้นจริง

## สิ่งที่ deploy

- Commit: `4456244` (merge commit ของ PR #254 เข้า `main`)
- PR: https://github.com/warren-wyn-dev/wynteam/pull/254
- Workflow run: https://github.com/warren-wyn-dev/wynteam/actions/runs/33984053470 (run #79, `workflow_dispatch`)
- ปลายทาง: Vercel project "web" → `wynos.online` (Flutter Web release build)

## สิ่งที่เปลี่ยน

`conversation_screen.dart` — เพิ่ม `.catchError((_) {})` ต่อท้ายทั้ง 2 จุดที่เรียก
`markConversationRead(...)` (ใน `initState()` และใน handler ของข้อความ realtime ที่เข้ามา
ใหม่) การเพิ่ม `.catchError` ทำให้ builder ถูก "consume" จริง จึงยิง request ออกไปจริง
พร้อมกันนั้นก็จับ error แบบเงียบๆ (ไม่ crash หน้าจอ) เหมือนเดิม

## Database

- ไม่มี migration ใดๆ — เป็นการแก้โค้ด client ล้วนๆ

## ผล verification

| รายการ | ผล |
|---|---|
| Diagnostic เทียบ live function บน production กับ `schema.sql` | **ตรงกันเป๊ะ ไม่มี drift** |
| Diagnostic query ข้อมูลจริงของ warren | ยืนยัน `last_read_at` เป็น null ทุกบทสนทนา (บั๊กจริง) |
| `flutter analyze` (local) | สะอาด |
| `flutter test` เต็มชุด (local) | **1210/1210 ผ่าน** |
| CI บน `main` (run #166, commit `4456244`) | **success** |
| Deploy workflow run #79 | **success** ครบ 9 step รวม "Deploy to Vercel production" |

### Production verification — **ผ่าน (Founder ยืนยัน 2026-09-05)**

Founder ทดสอบตามขั้นตอน (ปิด-เปิดแท็บใหม่ → กดไอคอนข้อความ → เข้า inbox → อ่านบทสนทนา →
ย้อนกลับ 2 ครั้ง → เช็ค badge) แล้วตอบว่า **"เรียบร้อยละ"** — เลข badge อัปเดตถูกต้องจริง
ถือว่า deployment นี้ verified แล้ว ไม่ต้อง rollback สถานะงาน: **COMPLETED**

## วิธี rollback

**AI ห้าม rollback เองโดยเด็ดขาดไม่ว่ากรณีใด** ถ้าพัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments →
   หา deployment ก่อนหน้า (run #77 หรือ #78) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 4456244` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

**ไม่มีคอลัมน์ฐานข้อมูลให้ rollback** — ไม่มี migration ในรอบนี้เลย (การแก้เป็น client-side
ล้วนๆ; ข้อมูล `last_read_at` ที่เป็น null อยู่แล้วจะเริ่มถูกบันทึกถูกต้องทันทีที่ผู้ใช้เปิดอ่าน
บทสนทนาครั้งถัดไปหลัง fix นี้ ใช้งานได้เลยไม่ต้องแก้ข้อมูลเก่า)
