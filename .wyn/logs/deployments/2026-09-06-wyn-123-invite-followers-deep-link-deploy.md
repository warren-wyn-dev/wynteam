# Deployment — WYN-123 (Invite Followers to Club) + WYN-119 partial (deep-link routing, authenticated users)

วันที่: 2026-09-06 15:34–15:42 UTC
Deploy โดย: AI Deploy & DevOps (session `session_01KqqTXyvHuABhBDwC8No3H2`)
อำนาจ: Founder อนุมัติผ่านคำถามแบบ popup ให้ merge เข้า main + deploy จริงทันทีหลัง QA PASS (`.wyn/tasks/approved/WYN-123-invite-followers-to-club.md`)

## Release

- **WYN-123** — เพิ่มตัวเลือก "เชิญจากผู้ติดตาม" ใน share sheet ของ Club (เฉพาะ Club) เปิด `InviteToClubScreen` ใหม่ ที่รวมรายชื่อ Followers + Following ของผู้ใช้ปัจจุบัน (dedupe) แล้วเชิญทีละคนผ่านกลไก "แชร์เข้า Chat" เดิม (WYN-033) ไม่มี schema/RLS เปลี่ยน
- **WYN-119 (partial)** — `DeepLinkService` ใหม่ อ่าน URL ตอนแอปเว็บโหลดครั้งแรก (เฉพาะผู้ใช้ที่ login แล้ว) แล้วเปิดหน้า Drop/Pop/Club/ClubPost/Profile ที่ถูกต้องแทนที่จะเข้า Home เสมอ — **ยังไม่ครอบคลุม guest ที่ไม่เคย login** (ต้องรอ Design pass เพิ่มเติมต่อ AuthGate/WYN-072 ก่อนถึงจะปิด WYN-119 เต็มรูปแบบ)

## Version

- Commit merge: `b3d150f` เข้า `main` ผ่าน PR [#282](https://github.com/warren-wyn-dev/wynteam/pull/282)
- ระหว่างทางเจอ real merge conflict กับ main ที่เดินหน้าไปไกล (WYN-114 ถึง WYN-122 จากหลาย session อื่น) — resolve แล้ว รวมถึงพบและแก้ ID collision 2 รายการ (`WYN-114`/`WYN-115` ของ session นี้ชนกับของ session อื่นที่ merge ไปก่อนแล้ว) — รายละเอียดเต็มใน `.wyn/company/DECISIONS.md` entry เดียวกันวันที่นี้

## QA Status

**PASS** (2026-09-06) — `.wyn/tasks/approved/WYN-123-invite-followers-to-club.md` "QA & Security Report" — `flutter analyze` 0 issues, `flutter test` 1259/1259 ก่อน merge, 1293/1293 หลัง merge เข้า main (CI run [34042740076](https://github.com/warren-wyn-dev/wynteam/actions/runs/34042740076)) — ทั้งสองรอบรันจริงผ่าน GitHub Actions `workflow_dispatch` เพราะ sandbox ไม่มี Flutter SDK

## Build Status

`deploy-web.yml` run #93 ([34043028680](https://github.com/warren-wyn-dev/wynteam/actions/runs/34043028680)): **success** ครบทุก step (`flutter build web --release`, "Deploy to Vercel production")

## Deployment Target

Vercel project "web" → `https://wynos.online`

## Changes

- `app/lib/features/chat/presentation/share_sheet.dart` — เพิ่ม param `followRepository`/`clubName`, แถวใหม่ "เชิญจากผู้ติดตาม" (เฉพาะ Club)
- `app/lib/features/club/presentation/club_page.dart` — เพิ่ม `_followRepository` field ส่งเข้า share sheet
- `app/lib/features/club/presentation/invite_to_club_screen.dart` (ใหม่)
- `app/lib/core/navigation/deep_link_service.dart` (ใหม่)
- `app/lib/features/root/presentation/root_shell.dart` — เรียก `DeepLinkService.handleInitialLink()`
- `app/test/invite_to_club_screen_test.dart`, `app/test/share_sheet_test.dart`, `app/test/deep_link_service_test.dart` (ใหม่)
- **ไม่มี migration ไม่มี schema/RLS เปลี่ยน**

## Deployment Result

**สำเร็จ** — `deploy-web.yml` run #93 status `success` ครบทุก step

## Production Verification

**ยืนยันได้เองจริงด้วย curl ตรงต่อ production**:

| Path | ผล |
|---|---|
| `/` | HTTP 200, `text/html` |
| `/club/test123` | HTTP 200, `text/html` (SPA rewrite ยังทำงานถูกต้อง ไม่ regression ต่อ WYN-114) |
| `/drop/test123` | HTTP 200, `text/html` |
| `/@test` | HTTP 200, `text/html` |
| `/og-image.png` | HTTP 200, `image/png` (ไม่ถูก rewrite ทับ) |
| `/favicon.png` | HTTP 200, `image/png` |
| `/manifest.json` | HTTP 200, `application/json` |
| `/main.dart.js` | HTTP 200, 4,355,983 bytes (build ใหม่ serve จริง) |

**ข้อจำกัดของการยืนยันรอบนี้**: ยืนยันได้แค่ระดับ "เว็บขึ้นจริง ไฟล์ static ไม่พัง" ด้วย curl เท่านั้น — **ยังไม่ได้ยืนยันด้วยตาจริงว่า UI ใหม่ทำงานถูกต้องในเบราว์เซอร์จริง** (กด "ชวนเพื่อนเข้ากลุ่ม" แล้วเห็น "เชิญจากผู้ติดตาม" จริง, กด "เชิญ" แล้วส่งข้อความจริง, เปิดลิงก์ `/club/<id จริง>` ตอน login อยู่แล้วพาไปหน้าคลับจริง) เพราะ sandbox นี้ไม่มี browser automation ที่เชื่อมต่อ production ได้จริง (เจอ `ERR_CONNECTION_RESET` เหมือนทุกครั้งที่ผ่านมา) — **ต้องรอ Founder ทดลองใช้จริงก่อนถือว่างานนี้ "completed" เต็มรูปแบบ** ตามกติกา "Production Verification คือใครยืนยัน ยืนยันอะไร" ใน `.wyn/company/WORKFLOW.md`

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments → หา deployment ก่อนหน้า run #93 → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 b3d150f` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

**ไม่มี migration ให้ rollback** — ไม่มี schema/database เปลี่ยนแปลงในรอบนี้เลย เป็น client-side Dart ล้วนๆ ย้อนกลับได้ปลอดภัย 100%

## สถานะ Task

- `.wyn/tasks/approved/WYN-123-invite-followers-to-club.md` — **ยังไม่ย้ายไป `completed/`** รอ Founder ทดลองใช้จริงก่อน (กด "เชิญจากผู้ติดตาม" จริง เห็นคนถูกเชิญได้รับข้อความจริง) ตามกติกา Production Verification ของ WORKFLOW.md
- `.wyn/tasks/active/WYN-119-club-deep-linking.md` — ยังคง **active** (ไม่ปิด) เพราะ guest-support (Requirement 2) ยังไม่ implement — ส่วนที่ deploy รอบนี้คือ partial (authenticated user เท่านั้น)
