# Bug Report — WYN-114

Status: **fixed — ส่งกลับ AI QA & Security แล้ว (2026-09-06)** รอ verify จริงหลัง deploy ตาม checklist ท้ายไฟล์
Owner: AI Debug Engineer
Bug: ทุก URL path บน `wynos.online` ที่ไม่ใช่ `/` เป๊ะๆ ได้ `HTTP 404` จาก Vercel โดยตรง (ไม่ถึง Flutter app เลย) — พบระหว่าง QA ของ WYN-114 (share link domain fix) เมื่อทดสอบว่าลิงก์ที่ generate จาก `dropShareLink()`/`popShareLink()`/`clubShareLink()`/`clubPostShareLink()`/`profileShareLink()` เปิดได้จริงไหมหลังเปลี่ยนโดเมนเป็น `wynos.online`

Reproduction:
```
curl -I https://wynos.online/drop/test123
# HTTP/2 404, x-vercel-error: NOT_FOUND, body: "The page could not be found / NOT_FOUND"

curl -I https://wynos.online/           # ใช้งานได้ปกติ HTTP 200
curl -I https://wynos.online/pop/x      # 404
curl -I https://wynos.online/club/x     # 404
curl -I https://wynos.online/club-post/x  # 404
curl -I https://wynos.online/@testuser  # 404
curl -I https://wynos.online/anything-random  # 404 เช่นกัน — ยืนยันว่าเป็นปัญหาทั่วไป ไม่ใช่แค่ 5 path นี้
```

Root Cause: โปรเจกต์ deploy ด้วย `npx vercel deploy --prod` ตรงๆ (ดู `.github/workflows/deploy-web.yml`) โดย**ไม่มี `vercel.json`** และไม่มี rewrite config ใดๆ Vercel เมื่อ deploy static output (`app/build/web/`) แบบไม่มี framework preset/rewrite จะ serve เฉพาะไฟล์ที่ path ตรงกับไฟล์จริงเท่านั้น (`/` → `index.html`, `/favicon.png` → ไฟล์นั้น) — path ใดๆ ที่ไม่ตรงไฟล์จริงจะได้ platform-level 404 ทันที **ก่อนที่ Flutter Web (ซึ่งเป็น Single Page Application ที่ต้อง serve `index.html` ให้ทุก path แล้วให้ JS ฝั่ง client จัดการ routing เอง) จะมีโอกาส boot ด้วยซ้ำ**

ปัญหานี้**มีอยู่ก่อน WYN-114 แล้ว** ไม่ใช่สิ่งที่ WYN-114 ทำให้เกิดขึ้นใหม่ — แต่ WYN-114 ทำให้ปัญหานี้ "สำคัญขึ้น" เพราะตอนนี้ share link ชี้โดเมนจริงแล้ว การที่ path อื่นนอกจาก `/` ใช้งานไม่ได้เลยจึงกระทบ user จริงโดยตรงเป็นครั้งแรก (ก่อนหน้านี้โดเมนปลอมทำให้ไม่มีใครไปถึงจุดนี้อยู่แล้ว)

Fix: เพิ่มไฟล์ `app/vercel.json` (ยังไม่มีไฟล์นี้ในโปรเจกต์เลย) พร้อม catch-all rewrite มาตรฐานสำหรับ Single Page Application:

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

ต้องวางที่ `app/vercel.json` (ไม่ใช่ root repo) เพราะ `deploy-web.yml` รัน `vercel deploy` จาก `working-directory: app/build/web` — ต้องตรวจสอบว่า Vercel CLI อ่าน `vercel.json` จาก working directory ที่ deploy จริง (`app/build/web/`) ไม่ใช่จาก `app/` เฉยๆ เพราะ `flutter build web` ไม่ copy ไฟล์ config เข้าไปเองเป็นค่าเริ่มต้น — **อาจต้องวางไฟล์ไว้ที่ `app/web/vercel.json` แล้วให้ `flutter build web` copy เข้า `build/web/` ตาม convention เดียวกับ `index.html`/`favicon.png`/`og-image.png` (ผ่าน `.gitignore` allow-list negation แบบเดียวกัน) หรือให้ workflow เขียนไฟล์นี้เข้า `build/web/` โดยตรงหลัง build เสร็จ (แบบเดียวกับที่ step "Bake the Firebase config" เขียนไฟล์เข้า `web/` ก่อน build)** — AI Debug Engineer ควรตรวจ Vercel CLI docs/behavior ให้แน่ชัดก่อนเลือกวิธี ไม่ใช่เดา

Files Changed: (ยังไม่ได้แก้ — รอ AI Debug Engineer)
- คาดว่าเป็น `app/web/vercel.json` (ใหม่) + อาจต้องแก้ `app/.gitignore` เพิ่ม negation ถ้าเลือกวางที่ `web/` + อาจต้องแก้ `.github/workflows/deploy-web.yml` ถ้าเลือกให้ workflow เขียนไฟล์เข้า `build/web/` โดยตรงแทน

Tests: หลังแก้ ต้อง curl ยืนยันจริงว่า `https://wynos.online/drop/anything` (หรือ path อื่นที่ไม่ตรงไฟล์จริง) ได้ `HTTP 200` และ body เป็น Flutter app's `index.html` (ไม่ใช่ 404 จาก Vercel) — เทียบก่อน/หลัง deploy แบบเดียวกับที่ QA ทำไว้ในรายงานนี้

Regression Risk: **ต้องระวัง**: catch-all rewrite แบบ `/(.*)  → /index.html` จะทำให้ static asset path ตรงๆ (เช่น `/og-image.png`, `/favicon.png`, `/icons/Icon-192.png`, `/manifest.json`, `/main.dart.js`) ถูก rewrite ไป `index.html` ด้วยถ้า Vercel ประมวลผล rewrite ก่อนเช็คว่ามีไฟล์จริงอยู่แล้วหรือไม่ — ต้องตรวจสอบพฤติกรรมจริงของ Vercel (โดยทั่วไป Vercel เช็คไฟล์ static ที่มีอยู่จริงก่อน rewrite เสมอเป็นค่าเริ่มต้น แต่ **ต้องยืนยันด้วยการทดสอบจริงหลัง deploy ไม่ใช่เชื่อพฤติกรรม default เฉยๆ** โดยเฉพาะ `/og-image.png` ที่ WYN-113 เพิ่ง deploy ไป — ถ้า rewrite ทำให้ไฟล์นี้เสียหรือ share preview พังไปด้วย จะเป็นการแก้บั๊กหนึ่งแล้วสร้างอีกบั๊กหนึ่งทันที)

Handoff to QA: หลัง AI Debug Engineer แก้แล้ว ต้องทดสอบซ้ำครบทั้ง 2 เซ็ต:
1. Path ที่ควรได้ `index.html` แล้ว (5 path ของ share link + path สุ่มอื่นๆ) — ต้องได้ HTTP 200
2. Path ของ static asset จริงที่มีอยู่ (`/og-image.png`, `/favicon.png`, `/manifest.json`) — **ต้องยังได้ไฟล์จริงเหมือนเดิม ไม่ถูก rewrite ไปเป็น index.html** (regression check สำคัญที่สุดของบั๊กนี้)

## AI Debug Engineer Output (2026-09-06)

Bug: (ตามที่ QA รายงาน — reproduce ซ้ำอิสระแล้วยืนยันตรงกัน) `curl -I https://wynos.online/drop/reproduce-test-xyz` ได้ `HTTP 404` (`x-vercel-error: NOT_FOUND`) แทนที่จะเป็น `index.html`

Reproduction: reproduce ซ้ำเองก่อนแก้ (ไม่เชื่อ QA เฉยๆ) — `curl -sS -D - -o /dev/null "https://wynos.online/drop/reproduce-test-xyz"` ได้ผลตรงกับที่ QA รายงานทุกประการ (`HTTP/2 404`, `x-vercel-error: NOT_FOUND`) — ยืนยันแล้วว่า path อื่นที่ไม่ใช่ `/` เป๊ะ 404 จริงบน production ปัจจุบัน

Root Cause: ยืนยันตรงกับที่ QA สรุปไว้ — ไม่มี `vercel.json`/rewrite config ใดๆ ในโปรเจกต์เลย (`find` ทั้ง repo หา `vercel.json` ไม่เจอสักไฟล์) `deploy-web.yml` รัน `npx vercel deploy --prod` ตรงๆ จาก `app/build/web/` โดยไม่มี config ใดกำกับ Vercel จึงใช้ static-file routing ล้วนๆ (path ต้องตรงไฟล์จริงเป๊ะ ไม่มี catch-all)

Fix: เพิ่ม `app/web/vercel.json` (ไฟล์ใหม่ — ก่อนหน้านี้ไม่มีไฟล์นี้ใน `app/web/` เลย):
```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```
วางที่ `app/web/vercel.json` (ไม่ใช่ `app/build/web/` โดยตรง เพราะ `build/` เป็น gitignored/regenerate ใหม่ทุกครั้ง) — ใช้กลไกเดียวกับที่ `index.html`/`favicon.png`/`og-image.png` ใช้อยู่แล้ว: `flutter build web` copy ไฟล์ทุกไฟล์ใน `web/` เข้า `build/web/` แบบ verbatim (ยกเว้น `index.html` ที่ผ่าน base-href substitution) จึงไม่ต้องแก้ `deploy-web.yml` เพิ่มเลย — เพิ่มแค่ `!/web/vercel.json` ใน `app/.gitignore` ตาม pattern เดิม (ยืนยันด้วย `git add --dry-run app/web/vercel.json` ว่าไม่ถูก block)

**เกี่ยวกับ Regression Risk ที่ QA เตือนไว้** (rewrite อาจทำให้ static asset จริงพัง): Vercel's routing order เอกสารทางการระบุว่า **filesystem check มาก่อน rewrite เสมอเป็นค่าเริ่มต้น** (ถ้ามีไฟล์จริงตรง path นั้น จะ serve ไฟล์นั้นก่อน ไม่ไป rewrite) — เป็น pattern มาตรฐานที่ SPA framework แทบทุกตัว (React/Vue/Angular ที่ deploy บน Vercel) ใช้กันแบบนี้เป๊ะๆ ไม่ใช่สิ่งที่ประดิษฐ์เอง **แต่ยังไม่สามารถพิสูจน์เชิงประจักษ์ได้ในรอบนี้** เพราะต้อง deploy ขึ้น Vercel จริงถึงจะทดสอบพฤติกรรม routing จริงได้ (sandbox นี้ไม่มี Vercel CLI ผูก credential ไว้) — **ระบุไว้ตรงๆ ว่ายังไม่ได้พิสูจน์เอง ไม่ใช่แค่เชื่อเอกสาร** ส่งต่อให้ QA/Deploy ยืนยันจริงหลัง deploy ตาม checklist ด้านล่าง

Files Changed:
- `app/web/vercel.json` (ใหม่)
- `app/.gitignore` — เพิ่ม `!/web/vercel.json` พร้อมคอมเมนต์อธิบาย

Tests: **ไม่มีทางเขียน automated regression test ในสภาพแวดล้อมนี้ได้จริง** — นี่เป็นพฤติกรรมของ Vercel CDN/routing layer ล้วนๆ ไม่มี local Flutter/Supabase test harness ใดจำลองได้ (ไม่ใช่ SQL/widget test) ต้องทดสอบกับ deployment จริงเท่านั้น — เตรียม **manual verification checklist ที่ต้องรันจริงหลัง deploy** ไว้ให้ QA แทน (ดูด้านล่าง) แทนการเขียน automated test ปลอมๆ ที่ไม่ได้พิสูจน์อะไรจริง

Regression Risk: **สูง ถ้าไม่ตรวจตามด้านล่าง** — ต้อง curl ยืนยันทั้ง 2 ชุดหลัง deploy:
```
# ชุด 1 — ต้องได้ 200 + เนื้อหาเป็น index.html (พิสูจน์ว่า bug ที่แก้ได้ผลจริง)
curl -sS -o /dev/null -w "%{http_code}\n" https://wynos.online/drop/xyz
curl -sS -o /dev/null -w "%{http_code}\n" https://wynos.online/pop/xyz
curl -sS -o /dev/null -w "%{http_code}\n" https://wynos.online/club/xyz
curl -sS -o /dev/null -w "%{http_code}\n" https://wynos.online/club-post/xyz
curl -sS -o /dev/null -w "%{http_code}\n" https://wynos.online/@xyz

# ชุด 2 — ต้องยังได้ไฟล์จริงเหมือนเดิม ไม่ถูก rewrite ทับ (regression check สำคัญสุด)
curl -sS -o /dev/null -w "%{http_code} %{content_type}\n" https://wynos.online/og-image.png    # ต้อง 200 + image/png
curl -sS -o /dev/null -w "%{http_code} %{content_type}\n" https://wynos.online/favicon.png     # ต้อง 200 + image/png
curl -sS -o /dev/null -w "%{http_code} %{content_type}\n" https://wynos.online/manifest.json   # ต้อง 200 + application/json
```

Handoff to QA: ส่งกลับ **AI QA & Security** — รัน checklist ทั้ง 2 ชุดข้างบนจริงหลัง deploy (ไม่ใช่แค่เชื่อว่า Vercel default behavior ปลอดภัย) ถ้าชุด 2 จุดใดจุดหนึ่งพัง (ได้ HTML ของ index.html แทนที่จะเป็นไฟล์จริง) ต้องถือว่า FAIL ทันทีและ escalate กลับมาที่ AI Debug Engineer เพราะเป็นการแก้บั๊กหนึ่งแล้วสร้างอีกบั๊กที่ร้ายแรงกว่าเดิม (share preview ของ WYN-113 จะพังไปด้วย)
