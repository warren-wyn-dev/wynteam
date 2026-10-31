# ZOKY-LINE-001 — แจ้งเตือนผ่าน LINE OA และเปิด ZOKY/Merchant ใน LINE (LIFF)

Status: **Proposal — รอ Founder อนุมัติ decisions D1–D6 ก่อน implementation**
Requested: Founder, 2026-10-31 ("เชื่อมไลน์ zoky ผู้ใช้ กับ merchant") — เลือก "แจ้งเตือนผ่าน LINE OA" + "เปิดใน LINE (LIFF)" และยืนยันว่ามี LINE Developers / LINE Official Account แล้ว
Scope note: ไม่รวม "เข้าสู่ระบบด้วย LINE" (LINE Login เป็น auth method) และไม่รวมปุ่มแชท LINE ของร้าน — Founder ไม่ได้เลือก

## 1. Current state (ตรวจจาก repo 2026-10-31)

- ไม่มีโค้ด LINE ใดๆ ใน repo (ไม่มี LIFF, Messaging API, LINE Login)
- Login: shared Supabase session (Google OAuth + email/password) ผ่าน WYNOS account gate — Merchant Flutter ไม่ถือ token เอง
- แจ้งเตือน: DB triggers เขียน `public.notifications` (`type='system'`) → Database Webhook → `supabase/functions/send-push-notification` → FCM/Web Push
  - `pushAppForNotification()` แยกปลายทางจากข้อความ `reason` แล้ว: `food` (ลูกค้า: `ออเดอร์ #WF…`, `ชำระเงินออเดอร์`, `สลิปออเดอร์`, `คืนเงินออเดอร์`) และ `merchant` (`WYNOS Merchant · …`)
- Domains: `zoky.wynos.online` / `food.wynos.online` (ลูกค้า), `merchant.wynos.online` (ร้าน) — Vercel project `web` เดียวกัน

## 2. Goal

1. ลูกค้า ZOKY ได้รับแจ้งสถานะออเดอร์/ชำระเงิน/คืนเงินทาง LINE
2. ร้าน (Merchant) ได้รับแจ้งออเดอร์ใหม่ ยกเลิก เงินเข้า คืนเงิน ทาง LINE
3. กดข้อความใน LINE แล้วเปิดหน้าที่เกี่ยวข้องของ ZOKY / Merchant ภายใน LINE (LIFF) ได้

Web Push เดิมต้องทำงานเหมือนเดิม — LINE เป็นช่องทาง **เพิ่ม** ไม่ใช่แทนที่

## 3. User stories & acceptance criteria (P0)

**US-1 เชื่อมบัญชี** — ในฐานะลูกค้า/ร้านที่ login ZOKY อยู่ ฉันกด "รับแจ้งเตือนทาง LINE" แล้วเชื่อม LINE ของฉันได้
- AC1 การเชื่อมเกิดเฉพาะเมื่อ server พิสูจน์ได้ทั้ง (a) Supabase user จาก JWT และ (b) LINE userId จาก LINE ID token ที่ verify กับ LINE ฝั่ง server (`aud` = channel ID ของเรา, ไม่หมดอายุ, nonce ตรง) — ห้ามเชื่อ `userId` ที่ client ส่งมา
- AC2 1 LINE userId ผูกได้กับ 1 ZOKY account ต่อครั้ง; เชื่อมซ้ำไปบัญชีอื่นต้องยืนยันและตัดของเดิม
- AC3 ผู้ใช้เห็นสถานะ "เชื่อมแล้ว / ยังไม่ได้เพิ่มเพื่อน OA / บล็อก OA" และกดยกเลิกการเชื่อมได้เอง (ลบข้อมูลทันที)
- AC4 ถ้ายังไม่ได้เป็นเพื่อนกับ OA ให้พาไปเพิ่มเพื่อน (LINE ส่ง push ไม่ได้ถ้าไม่ได้เป็นเพื่อน/ถูกบล็อก)

**US-2 แจ้งเตือนลูกค้า** — AC: ทุก notification ที่ `pushAppForNotification()` จัดเป็น `food` ส่งถึง LINE ของผู้รับที่เชื่อมแล้ว ภายใน ~10 วินาที, ข้อความเป็นภาษาของผู้ใช้, มีปุ่มเปิดออเดอร์นั้น

**US-3 แจ้งเตือนร้าน** — AC: ทุก notification `merchant` ส่งถึง LINE ของ **ผู้รับใน notifications row** (owner/staff ที่ระบบเดิมเลือกไว้แล้ว — ไม่คำนวณสิทธิ์ใหม่) พร้อมปุ่มเปิดหน้าออเดอร์ใน Merchant

**US-4 เปิดใน LINE (LIFF)** — AC: ปุ่มในข้อความเปิด LIFF → redirect ไป path ที่ allowlist ไว้เท่านั้น (ห้าม open redirect) บน `zoky.wynos.online` / `merchant.wynos.online`; authorization ยังบังคับฝั่ง server เหมือนเดิม ข้อความ LINE ห้ามมีข้อมูลส่วนตัวเกินจำเป็น (ไม่ใส่ที่อยู่/เบอร์โทร/ชื่อเต็มลูกค้า)

**Non-functional**
- LINE ล่มหรือ quota หมด ต้องไม่ทำให้ Web Push หรือ flow ออเดอร์ล้ม (best-effort, log แบบไม่มี PII/token)
- Respect notification preferences / quiet hours เดิมของ push (ใช้ helper เดิม)
- ไม่ log LINE userId เต็ม, ID token, channel secret/access token

## 4. Technical design (เสนอ — แนวทางเรียบง่าย ใช้ของเดิม)

```text
ZOKY/Merchant web (logged in) ──► LIFF (liff.init + liff.getIDToken)
        │ Supabase JWT + LINE ID token + nonce
        ▼
Edge Function line-link  ──verify──► https://api.line.me/oauth2/v2.1/verify
        │ service role
        ▼
public.line_links (user_id ↔ line_user_id, status)
        ▲ follow/unfollow
Edge Function line-webhook  ◄── LINE platform (X-Line-Signature HMAC verified)

notifications INSERT ─► send-push-notification (เดิม) ─► FCM/Web Push (เดิม)
                                   └─► (ใหม่) LINE Messaging API push ถ้า app ∈ {food, merchant} และมี link active
```

- **DB (migration ใหม่, additive เท่านั้น):** `public.line_links(user_id uuid pk → auth.users on delete cascade, line_user_id text unique not null, friend_status text check in ('unknown','friend','blocked'), linked_at, updated_at)`; RLS: owner `select`/`delete` เท่านั้น, ไม่มี insert/update จาก client (เขียนผ่าน service role ใน Edge Function), deny by default. ตาราง nonce ชั่วคราวสำหรับกัน replay (หมดอายุ 10 นาที)
- **Edge Functions ใหม่:** `line-link` (link/unlink/status), `line-webhook` (verify signature ด้วย constant-time compare; ตอบ 200 เร็ว; อัปเดต friend_status)
- **แก้ของเดิม:** `send-push-notification` เพิ่ม branch ส่ง LINE หลัง Web Push โดยใช้ `pushAppForNotification`/`pushMessageForApp`/preferences เดิม — ไม่เปลี่ยน contract เดิม พร้อม unit tests
- **Frontend:** หน้า `/line` (LIFF endpoint) บน `web` + ปุ่มเชื่อม/ยกเลิกในหน้าตั้งค่าแจ้งเตือนของ ZOKY และ Merchant (Flutter bridge เพิ่ม method `lineLinkStatus/link/unlink` ผ่าน bridge เดิม ไม่ส่ง token เข้า Dart)
- **Secrets (Supabase Edge Function secrets เท่านั้น, ไม่ commit):** `LINE_CHANNEL_ACCESS_TOKEN`, `LINE_CHANNEL_SECRET`, `LINE_LOGIN_CHANNEL_ID`; public env: `NEXT_PUBLIC_LIFF_ID_ZOKY`, `NEXT_PUBLIC_LIFF_ID_MERCHANT`
- **Dependency:** `@line/liff` (official SDK) ใน `web` — ต้องได้รับอนุมัติตาม change control

## 5. Decisions ที่ต้องให้ Founder อนุมัติ

| # | เรื่อง | ข้อเสนอ |
|---|---|---|
| D1 | **Login ภายใน LINE** — Google ปฏิเสธ OAuth ใน in-app browser/webview (`disallowed_useragent`) ผู้ใช้ Google เปิด LIFF แล้วจะ login ไม่ได้ | P0: LIFF ใช้สำหรับ **เชื่อมบัญชี + เปิดหน้า**; ถ้ายังไม่มี session ใน LINE ให้ปุ่ม "เปิดในเบราว์เซอร์" (`liff.openWindow({external:true})`) + email/password ใช้ได้ตามปกติ. การเพิ่ม LINE Login เป็นวิธี login เป็น auth architecture change แยก task |
| D2 | OA เดียว หรือแยก OA ลูกค้า/ร้าน | แนะนำ **2 OA** (ZOKY สำหรับลูกค้า, ZOKY Merchant สำหรับร้าน) ไม่ปนข้อความ/quota/แบรนด์ — ถ้ามี OA เดียวก็ทำได้ แต่ร้านจะเห็นข้อความแบบเดียวกับลูกค้า |
| D3 | ค่าใช้จ่าย — push message ของ LINE OA ไทยมีโควตาฟรีจำกัดต่อเดือน เกินต้องจ่ายแพ็กเกจรายเดือน | ต้องยืนยันแพ็กเกจปัจจุบันใน LINE OA Manager; ระบบจะหยุดส่ง LINE (Web Push ยังทำงาน) เมื่อโควตาหมด. เป็น infrastructure cost → Founder ตัดสิน |
| D4 | เหตุการณ์ที่ส่งทาง LINE | P0: ทุก `food` และ `merchant` system notification ตาม classifier เดิม; P1: ให้ผู้ใช้เลือกปิดบางประเภท |
| D5 | ข้อมูลในข้อความ | เลขออเดอร์ + สถานะ + ชื่อร้าน + ยอดเงิน (สำหรับร้าน) — ไม่ใส่ที่อยู่/เบอร์/ชื่อลูกค้า. LINE userId ถือเป็น personal data ต้องอยู่ใน privacy policy (ซึ่งยังเป็น placeholder) |
| D6 | Release | staging ก่อน, จากนั้น scoped release แบบเดียวกับ Merchant (production review เดิม); migration ใช้ apply workflow ที่มี review |

## 6. สิ่งที่ Founder ต้องเตรียม (ทำใน LINE Developers Console — ผมทำแทนไม่ได้)

1. Messaging API channel ของ OA (ต่อ OA ตาม D2): Channel secret, long-lived Channel access token, เปิด Webhook, ตั้ง Webhook URL เป็น `https://<supabase-project>.supabase.co/functions/v1/line-webhook` (จะให้ URL จริงตอน implement)
2. LINE Login channel (provider เดียวกับ Messaging API channel เพื่อให้ userId ตรงกัน) + สร้าง LIFF app: endpoint `https://zoky.wynos.online/line` และ `https://merchant.wynos.online/line`, scope `openid profile`, size Full
3. ตั้ง "Add friend option" ให้ link กับ OA (bot link feature = aggressive/normal)
4. ใส่ secrets ผ่าน Supabase Dashboard → Edge Functions → Secrets เอง **ห้ามส่ง secret ในแชทหรือ commit**

## 7. Test plan (QA & Security)

- Unit: ID token verify (aud ผิด/หมดอายุ/nonce ซ้ำ/ปลอม), signature webhook (ถูก/ผิด/ไม่มี header), classifier → LINE routing, quota/429/5xx ไม่กระทบ Web Push
- AuthZ: user A เชื่อม/ยกเลิก/อ่าน link ของ user B ไม่ได้ (RLS + direct API), staff ที่ถูกถอดสิทธิ์ไม่ได้รับแจ้งร้านต่อ (ตามผู้รับเดิมใน notifications)
- LIFF: redirect allowlist, ไม่มี session ใน LINE, Google sign-in ใน LINE แสดงทางออกที่ถูก
- E2E ด้วย mock LINE API เท่านั้น — ไม่ใช้บัญชีจริงหรือฐานข้อมูลจริง; การทดสอบส่งจริงทำบน staging กับ OA ทดสอบ

## 8. Rollback

Feature flag ปิดการส่ง LINE ได้ทันทีใน `send-push-notification`; migration เป็น additive (drop table ได้ด้วย migration ที่อนุมัติ); ลบ LIFF endpoint ไม่กระทบหน้าอื่น

## Handoff

Founder อนุมัติ D1–D6 → Architect/CTO review design → Database (migration) + UI/UX (ปุ่มเชื่อม, หน้า `/line`) → Full-Stack → QA & Security → staging → Founder approval → scoped production release
