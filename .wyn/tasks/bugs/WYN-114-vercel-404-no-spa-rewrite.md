# Bug Report — WYN-114

Status: bugs
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
