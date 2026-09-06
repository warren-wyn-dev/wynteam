# Product Task — WYN-113

Status: active — Founder ตัดสินใจแล้ว (เลือกโทนสี A + แก้ข้อความ) **พร้อมส่งต่อ AI Coding** (ดู "## AI Design Output" ท้ายไฟล์นี้)
Owner: AI Product Manager → AI Design
Feature: Open Graph / Twitter Card Preview สำหรับลิงก์ wynos.online
Goal: ทำให้ลิงก์ wynos.online ที่ถูกแชร์ไปที่ไหนก็ตาม (Facebook/LINE/Discord/X ฯลฯ) ขึ้น preview card ที่มีรูป+ชื่อ+คำอธิบาย แทนที่จะไม่มี preview เลยหรือขึ้นแบบว่างเปล่า
Target User: N/A (ผลกระทบคือทุกคนที่เห็นลิงก์ WYN ถูกแชร์ ไม่ใช่ผู้ใช้ที่ล็อกอินอยู่แล้ว) — เป้าหมายจริงคือเพิ่มอัตราคนกดลิงก์ (click-through) ของคนที่ยังไม่เคยเห็น WYN มาก่อน
Problem: ตรวจ `app/web/index.html` แล้วพบว่า**ไม่มี Open Graph (`og:title`/`og:image`/`og:description`) หรือ Twitter Card meta tag ใดๆ เลย** มีแค่ `<meta name="description">` ธรรมดากับ `<title>WYNOS Beta</title>` เท่านั้น — เวลา Founder แชร์ลิงก์ wynos.online เข้ากลุ่ม/โซเชียลตามที่ทำอยู่ตอนนี้ (บริบท WYN-112) แพลตฟอร์มปลายทางจะไม่มีอะไรให้ดึงไปทำ preview card ที่สวยงามได้เลย ซึ่งเป็นสาเหตุที่รู้จักกันดีว่าทำให้อัตราคนกดลิงก์ต่ำกว่าลิงก์ที่มี preview การ์ดจริง — เป็นปัจจัยหนึ่งที่อาจกระทบ traffic ที่ WYN-112 กำลังสืบอยู่ (ยังไม่ใช่ข้อสรุป แค่เป็น gap ที่ตรวจพบจริงจากโค้ด ไม่ใช่การเดา)
Requirements:
- เพิ่ม meta tags มาตรฐานใน `app/web/index.html` ให้ครบ: `og:title`, `og:description`, `og:image`, `og:url`, `og:type` (`website`), `twitter:card` (`summary_large_image`), `twitter:title`, `twitter:description`, `twitter:image`
- ต้องมีรูป preview image ขนาดมาตรฐาน **1200×630px** (อัตราส่วนที่ Facebook/LINE/X ใช้ตัดพอดี ไม่ครอปเพี้ยน) — เป็น static asset ใหม่ 1 ไฟล์ ไม่ใช่การ generate แบบ dynamic ต่อหน้า (ข้อจำกัดของ Flutter Web SPA build เดียวที่ serve เป็น `index.html` คงที่ — ทำ dynamic OG per-post ได้ในอนาคตถ้าจะทำ server-side rendering/edge function แยกต่างหาก แต่ไม่ใช่ scope ของงานนี้)
- เนื้อหา title/description ต้องสื่อว่า WYN คืออะไรและชวนคลิกจริง ไม่ใช่แค่ copy คำเดิมจาก `<meta name="description">` ที่มีอยู่ตรงๆ (ข้อความปัจจุบัน "WYNOS — mobile social app for Gen Z" เป็นภาษาอังกฤษเทคนิคเกินไปสำหรับคนทั่วไปที่เจอลิงก์ในกลุ่มโซเชียลไทย — ให้ AI Design เสนอ copy ภาษาไทยที่เข้าใจง่ายและชวนคลิกกว่านี้)
- รูป preview ต้องใช้โทนสี/แบรนด์จริงจาก `app/lib/core/design/wyn_colors.dart` (Sapphire/Ink/Paper) ตามบทเรียน 2026-09-02 (ห้ามใช้ Cyan เก่าที่ re-brand ทับไปแล้ว) — ถ้ายังไม่มี asset ออกแบบใหม่พร้อมใช้ทันที อนุโลมใช้ `app/web/icons/Icon-512.png` (app icon ที่มีอยู่แล้ว) เป็น `og:image` ชั่วคราวได้ เพื่อไม่ให้ต้องรอ asset ใหม่ก่อนจะได้ผลลัพธ์อะไรเลย — แต่ recommend ให้ Founder อนุมัติ asset เฉพาะทางในรอบถัดไปเพราะ 1200×630 กับ 512×512 ให้ผลลัพธ์ไม่เท่ากันตอนถูกครอป
Acceptance Criteria:
- วางลิงก์ `wynos.online` ในตัวตรวจสอบ preview จริง (เช่น Facebook Sharing Debugger, Twitter Card Validator, หรือแปะทดสอบในแชทที่ render link preview เช่น LINE/Discord) แล้วเห็นรูป+ชื่อ+คำอธิบายที่ตั้งใจไว้ ไม่ใช่ card ว่างเปล่า
- ไม่กระทบพฤติกรรมแอปเดิมแม้แต่จุดเดียว (เป็นการเพิ่ม static HTML head เท่านั้น ไม่แตะ Flutter widget/state ใดๆ)
- `flutter build web --release` ยังสำเร็จตามปกติ (ไฟล์ `web/index.html` เป็น input ของ build อยู่แล้ว ไม่ใช่ output ที่ build เขียนทับ)
Dependencies: ไม่มี — ไม่ต้องรอ WYN-112 (คนละงานกัน แก้คู่ขนานได้), ไม่ต้องรอ dev/deploy อื่น
Priority: P1 — ไม่บล็อกอะไร แต่คุ้มทำเร็วเพราะต้นทุนต่ำมากและอาจช่วยปัญหา click-through ที่กำลังสืบอยู่ได้ทันทีในการแชร์รอบถัดไป
Risks: ต่ำมาก — เพิ่ม static meta tag ไม่มี logic ใหม่ ความเสี่ยงเดียวคือถ้า `og:image` ชี้ path ผิดจะไม่มี preview รูปขึ้น (แก้ได้ทันทีถ้าเจอ ไม่กระทบ production อื่น) — ต้อง cache-bust ด้วยถ้าเปลี่ยนรูปซ้ำ เพราะ Facebook/LINE cache preview เดิมไว้หลายวัน (ใช้ Sharing Debugger กด "Scrape Again" ถ้าต้อง force refresh หลัง deploy)
Recommendation: ทำคู่ขนานไปกับที่ Founder เตรียมแชร์ลิงก์รอบถัดไปพร้อม UTM parameter (ตามที่ WYN-112 แนะนำ) — จะได้เห็นผลทั้งสองอย่างพร้อมกันในรอบเดียว: มีคนคลิกเพิ่มขึ้นไหม (จาก OG card) และคลิกมาจากช่องทางไหน (จาก UTM)
Handoff: ส่งต่อ AI Design ออกแบบ preview image 1200×630 (โทนสีจริงจาก `wyn_colors.dart`) + เสนอ copy title/description ภาษาไทย → AI Coding เพิ่ม meta tags ใน `app/web/index.html` + วาง asset ที่ `app/web/` → AI QA ตรวจด้วย Facebook Sharing Debugger/Twitter Card Validator จริงก่อนถือว่าเสร็จ (เป็นสิ่งที่ตรวจได้แค่ด้วยเครื่องมือภายนอกจริง ไม่ใช่ unit test)

## AI Design Output (2026-09-06)

Design doc เต็ม: `.wyn/docs/design/wyn-113-og-share-preview-cards.md`
Mockup (Artifact — ดูก่อนตัดสินใจ): https://claude.ai/code/artifact/5c4b7b86-7dd2-466b-bcf0-7bc382fd1a1e

เสนอ 2 ตัวเลือกโทนสี (ใช้ token จริงจาก `wyn_colors.dart` เท่านั้น ไม่มีสีใหม่):
- **A — Paper**: พื้นขาวเหมือนแอปทุกหน้าจอ ปลอดภัยที่สุด
- **B — Ink (แนะนำ)**: พื้นเข้ม สะดุดตากว่าในฟีดที่ส่วนใหญ่เป็นการ์ดขาว ช่วยอัตราคลิกได้จริง โดยไม่กระทบ UI จริงของแอปเลย (คนละพื้นผิว)

เสนอข้อความ:
- `og:title`: "WYNOS — สร้างชุมชนของคุณเอง"
- `og:description`: "แชร์ Drop โพสต์ Pop คลิปสั้น ตั้ง Club กับคนที่ชอบเหมือนกัน ทั้งหมดในที่เดียว"

**ยังไม่ส่งต่อ AI Coding** ตามกติกา Founder 2026-09-03 ("ต้องเห็นรูปก่อนเขียนโค้ดทุกครั้ง") — รอ Founder ตอบ 2 ข้อ: เลือกโทนสี + อนุมัติ/แก้ข้อความ

## Final Decision (2026-09-06)

Founder เลือก **โทนสี A (Paper)** — ไม่ใช่ B ที่ AI Design แนะนำ และแก้ข้อความ:
- ตัด "Pop คลิปสั้น" ออกทั้งหมด (Pop ถูกซ่อนจากผู้ใช้ทุกจุดแล้วตั้งแต่ WYN-102 — ตรงมติเดิม)
- "Drop" → "โพสต์รูป" (ศัพท์ในแอปที่คนนอกไม่รู้จัก)

**ข้อความฉบับสุดท้าย**:
- `og:title`: `WYNOS — สร้างชุมชนของคุณเอง`
- `og:description`: `โพสต์รูป แชร์เรื่องราว และตั้ง Club กับคนที่ชอบเหมือนกัน ทั้งหมดในที่เดียว`

Mockup อัปเดตแล้ว: https://claude.ai/code/artifact/5c4b7b86-7dd2-466b-bcf0-7bc382fd1a1e — **พร้อมส่งต่อ AI Coding**

## AI Coding Output (2026-09-06)

Implementation: เพิ่ม Open Graph + Twitter Card meta tags ใน `app/web/index.html` (ตัวเลือกสี A-Paper ตามที่ Founder เลือก) และเพิ่ม asset รูป `app/web/og-image.png` (1200×630, render จาก HTML จริงด้วย headless Chromium ที่มีอยู่ใน sandbox — ใช้โลโก้จริง `app/assets/images/wynos_logo_mark.png` และสี token จริงจาก `wyn_colors.dart` เท่านั้น ไม่มีสีใหม่)

Files Changed:
- `app/web/index.html` — เพิ่ม 9 meta tags (`og:type`, `og:url`, `og:title`, `og:description`, `og:image`, `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`) หลัง `<meta name="description">` เดิม พร้อมคอมเมนต์อธิบายที่มา — ไม่แก้ไข/ลบบรรทัดเดิมแม้แต่บรรทัดเดียว
- `app/web/og-image.png` (ใหม่) — รูป preview 1200×630
- `app/.gitignore` — เพิ่ม `!/web/og-image.png` เข้า allow-list ของ `/web/*` (ตรวจพบว่า `web/*` ถูก ignore เป็นค่าเริ่มต้นและต้องเพิ่ม negation ทีละไฟล์ตาม pattern เดิมของ index.html/favicon.png/icons — ถ้าไม่เพิ่มไฟล์รูปจะหายไปในเครื่องอื่น/CI ทันที เป็นบั๊กคลาสเดียวกับที่เคยพบกับ `firebase-messaging-sw.js` มาก่อน) พร้อมคอมเมนต์อธิบายเหตุผลตาม convention เดิมของไฟล์

Reason: ตาม Product spec (`.wyn/tasks/active/WYN-113-og-share-preview-cards.md`) และ Design spec (`.wyn/docs/design/wyn-113-og-share-preview-cards.md`) — เนื้อหา/สี/ข้อความทั้งหมดตรงกับที่ Founder อนุมัติไว้ 100% (โทนสี A, ตัด Pop ออก, "Drop" → "โพสต์รูป")

Tests: **ไม่มี test อัตโนมัติที่เกี่ยวข้อง** — เป็นการเปลี่ยน static HTML/asset ล้วนๆ ไม่แตะ Dart code ใดๆ จึงไม่กระทบ `flutter test` suite ที่มีอยู่ (ยืนยันด้วยการอ่าน diff: ไม่มีบรรทัดใดอยู่นอกช่วง `app/web/` และ `app/.gitignore`) — ตรวจ well-formedness ของ `index.html` ด้วย Python `html.parser` แล้ว parse ผ่านไม่มี error

Build: **ยืนยันเองไม่ได้เต็มรูปแบบ** — sandbox ของ session นี้ไม่มี Flutter SDK ติดตั้งอยู่ (ต่างจากบาง session ก่อนหน้าที่เคยมีที่ `/home/user/flutter`) จึงรัน `flutter analyze`/`flutter build web` จริงไม่ได้ในรอบนี้ — ความเสี่ยงต่ำมากเพราะ `index.html` เป็น input ของ `flutter build web` (ถูกคัดลอกเข้า `build/web/` แทนที่แค่ `$FLUTTER_BASE_HREF`เท่านั้น ไม่ผ่าน parser ใดของ Flutter) ไม่ใช่ output ที่ build เขียนทับ, meta tag ที่เพิ่มเป็น syntax มาตรฐานทั่วไป — **AI QA & Security ควรรัน `flutter build web --release` จริงอย่างน้อย 1 ครั้งก่อน PASS** เพื่อยืนยันตามวินัยเดิมของโปรเจกต์ (แยก "AI ยืนยันได้เอง" กับ "ต้องรอคนอื่นยืนยัน" ตาม WORKFLOW.md)

Known Issues:
- รูป preview render ด้วย headless Chromium ในเครื่อง sandbox นี้ ยังไม่เคยเห็นผลจริงบน Facebook Sharing Debugger/Twitter Card Validator/LINE — ต้องให้ AI QA หรือ Founder ทดสอบด้วยเครื่องมือจริงหลัง deploy ตาม Acceptance Criteria ของ Product spec
- `og:url`/`og:image` ใช้ URL เต็ม `https://wynos.online/...` ตรงตัว (hardcode โดเมน production) — ถูกต้องตามจุดประสงค์ของ meta tag เหล่านี้ (ต้องเป็น absolute URL เสมอตามสเปก Open Graph) ไม่ใช่บั๊ก แต่ถ้าโดเมนเปลี่ยนในอนาคตต้องแก้จุดนี้ด้วย
- Facebook/LINE cache preview การ์ดเดิมไว้หลายวัน — ถ้า Founder เคยแชร์ลิงก์ไปแล้วก่อนหน้านี้ อาจต้องกด "Scrape Again" ใน Facebook Sharing Debugger เพื่อบังคับ refresh (บันทึกไว้ใน Risk ของ Product spec แล้ว)

Handoff: ส่งต่อ **AI QA & Security** — ตรวจ (1) `flutter analyze`/`flutter build web --release` ผ่านจริง (2) วางลิงก์ที่ build ได้ในตัวตรวจสอบ preview จริงอย่างน้อย 1 ตัว (Facebook Sharing Debugger/Twitter Card Validator) เห็นรูป+ข้อความตามที่ตั้งใจ (3) ยืนยันว่าไม่มีบรรทัดโค้ด Dart ใดถูกแตะ — ห้าม deploy ขึ้น production ก่อน QA ผ่านตาม WORKFLOW.md

## Copy — ปิดจบสุดท้าย (2026-09-06)

Founder ลองร่าง copy เองอีกเวอร์ชัน ("แชร์รูป ความทรงจำดีๆ สร้างคลับ-คอมมูนิตี้") ระหว่างทางแล้วดูมอคอัพอีกครั้ง สุดท้าย**ยืนยันกลับมาที่ข้อความที่ implement ไปแล้ว** ("โพสต์รูป แชร์เรื่องราว และตั้ง Club กับคนที่ชอบเหมือนกัน ทั้งหมดในที่เดียว") — **ไม่ต้องแก้โค้ดเพิ่ม** เพราะตรงกับที่อยู่ใน `app/web/index.html` อยู่แล้ว 100%

ระหว่างตรวจ mockup รอบนี้ พบบั๊กเล็กในตัว Artifact review เอง (ไม่ใช่ production asset): การ์ดตัวอย่างใช้ font-size หน่วย px ตายตัว พอแสดงบนจอมือถือแคบ ตัวอักษร tagline ล้นกรอบ `.og-image` (aspect-ratio box + overflow:hidden) จนถูกตัด — แก้แล้วด้วย CSS container query units (`cqw`) ให้ขนาดตัวอักษร/โลโก้/เส้นคั่นสเกลตามความกว้างจริงของกล่องเสมอ ไม่กระทบไฟล์ `app/web/og-image.png` ที่ deploy จริงเลย (ไฟล์นั้น render แยกที่ 1200×630 คงที่ตั้งแต่แรกอยู่แล้ว ไม่เคยมีปัญหานี้)

**สถานะสุดท้าย**: WYN-113 ปิด copy/design ครบแล้ว โค้ดพร้อม 100% — รอ AI QA & Security ตรวจตามที่ระบุไว้ใน "AI Coding Output" ด้านบน (`flutter build web` จริง + ทดสอบด้วย Facebook Sharing Debugger)
