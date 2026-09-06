# Product Task — WYN-113

Status: active — AI Design ทำมอคอัพเสร็จแล้ว ส่ง Artifact ให้ Founder ดูแล้ว **รอ Founder เลือก 2 เรื่องก่อนส่งต่อ AI Coding** (ดู "## AI Design Output" ท้ายไฟล์นี้)
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
