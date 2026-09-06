# Product Task — WYN-119

> **แก้ไข (2026-09-06, session `session_013hvSGovkwhxpPFbFEKAvAu`)**: ไฟล์นี้เดิมชื่อ `WYN-114-fix-share-links-deep-linking.md` สร้างโดยอีก session หนึ่ง (`session_014LEtwe8NjiPLcc9cqJEkuq`) พร้อมกันกับที่ session นี้กำลังแก้ปัญหาเดียวกันอยู่ภายใต้เลข `WYN-114` เช่นกัน — **ID collision อีกครั้ง** (class เดียวกับ `WYN-078` และ `WYN-077` ที่เคยพบมาก่อน) **เปลี่ยนเลขเป็น `WYN-119`** เพราะ `WYN-114` ตัวที่เสร็จและ deploy แล้ว (`.wyn/tasks/completed/WYN-114-share-link-real-domain.md`) ไม่ควรเปลี่ยนเลขที่ปิดงานไปแล้ว — ตรงกับหลักการเดิมที่เคยแนะนำไว้ตอนแก้ `WYN-078` ("เปลี่ยนเลขงานที่ยัง backlog อยู่ ไม่ใช่งานที่เสร็จแล้ว") — ห้ามใช้ `WYN-115`–`WYN-118` เพราะถูกจองไว้แล้วใน `.wyn/docs/product/wyn-club-growth-roadmap.md` (Club Poll/Re-engagement/Owner Insights/Events)

Status: backlog
Owner: AI Product Manager

Feature: เพิ่ม Deep Linking จริงให้ลิงก์ Share ภายนอก (ต่อจาก WYN-114 ที่แก้แค่โดเมน+SPA fallback เสร็จแล้ว)

Goal: ทำให้ "แชร์ Club/Drop/Pop/Profile ออกนอกแอป" พาไปถึงเนื้อหานั้นจริง ไม่ใช่แค่เปิดเว็บแล้วไปหน้า Home เสมอ

Target User: ทุกคนที่กดปุ่ม "Share" ออกนอกแอป (ไม่ใช่ share-to-chat ในแอป) บน Club/Club Post/Drop/Pop/Profile และเพื่อนที่พวกเขาส่งลิงก์ไปให้ — รวมถึงฟีเจอร์ "เชิญเพื่อนมา Club" ที่อีก session สร้างไว้เมื่อเร็วๆ นี้ ซึ่งต้องพึ่งลิงก์นี้ทำงานถูกต้องเพื่อให้ใช้งานได้จริง

## สิ่งที่เสร็จไปแล้ว — ไม่ใช่ scope ของงานนี้อีกต่อไป

**WYN-114 (`.wyn/tasks/completed/WYN-114-share-link-real-domain.md`) แก้และ deploy ขึ้น production สำเร็จแล้ว** (2026-09-06, PR #271, deploy-web.yml run #89, ยืนยันด้วย curl จริง):
1. ~~เปลี่ยนโดเมนทั้ง 5 จุดจาก `wyn.app` เป็น `wynos.online`~~ **เสร็จแล้ว**
2. ~~ตรวจสอบว่า Vercel serve SPA fallback ถูกต้อง~~ **เสร็จแล้ว** — เพิ่ม `app/web/vercel.json` (catch-all rewrite `/(.*)  → /index.html`) เพราะ Vercel เดิม**ไม่มี**เลย ทำให้ path อื่นนอกจาก `/` ได้ 404 ตรงๆ มาก่อนหน้านี้ — แก้แล้ว ยืนยันด้วย curl production จริงว่า `/drop/x`/`/pop/x`/`/club/x`/`/club-post/x`/`/@x` ได้ HTTP 200 ครบ และ static asset เดิม (`og-image.png`) ไม่ถูกกระทบ

**ผลคือตอนนี้**: เปิด `https://wynos.online/club/<id>` จะได้ HTTP 200 และแอป Flutter boot ขึ้นมาจริงแล้ว (ไม่ 404 อีกต่อไป) **แต่ยัง flake ไม่พาไปหน้า Club นั้นโดยตรง** — จะไปที่ AuthGate/home เสมอ เพราะ `main.dart` ยังไม่มี path-based routing ใดๆ เลย (`home: const AuthGate()` ตายตัว ไม่มี `GoRouter`, ไม่มีจุดไหนอ่าน `Uri.base.path`) — **นี่คือ scope ที่แท้จริงของงานนี้ (WYN-119)**

## Problem (เหลือเฉพาะส่วนที่ยังไม่ได้ทำ)

ไม่มีระบบ deep-linking ฝั่ง client เลย — คนที่คลิกลิงก์แชร์ (Club/Club Post/Drop/Pop/Profile) จะเห็นหน้า AuthGate/Home ของแอปเสมอ ไม่ใช่เนื้อหาที่ถูกแชร์มาโดยเฉพาะ ทำให้ฟีเจอร์ "เชิญเพื่อนมา Club" (และการแชร์ทั่วไปทุกจุด) ยังไม่ทำงานตามที่ตั้งใจ 100% แม้ลิงก์จะ "เปิดได้" แล้วก็ตาม

**เชื่อมกับ WYN-112**: ตอนนี้ที่ WYN-114 (โดเมน+SPA fallback) deploy แล้ว การแชร์ลิงก์รอบใหม่ผ่านปุ่ม Share ในแอปจะเปิดเว็บได้จริงแล้ว (ต่างจากก่อนหน้านี้ที่ 404 ตรงๆ) — ถ้า Founder เคยใช้ปุ่ม Share ในแอปมาก่อนสำหรับลิงก์ที่แชร์ต่อเนื่องในอดีต นั่นคือคำอธิบายของ signup=0 ที่ผ่านมา (ตอบไม่ได้ว่าเคยใช้ปุ่มนี้หรือไม่จนกว่า Founder จะยืนยัน — ดู note ใน WYN-112) แต่ **ไม่ว่าคำตอบจะเป็นอะไร ตอนนี้ปัญหานั้นแก้ไปแล้วสำหรับการแชร์รอบต่อไป**

Requirements:
1. เพิ่ม client-side route handling ให้ Flutter Web อ่าน path จาก URL ตอนโหลดครั้งแรก (`/club/:id`, `/club-post/:id`, `/drop/:id`, `/pop/:id`, `/@:username`) แล้วพาไปหน้าจอที่ถูกต้องแทนที่จะเปิด Home เสมอ — รวมถึงกรณี guest (ยังไม่ login) ต้องเห็น preview เนื้อหาได้ก่อน (ตาม guest-browsing ที่มีอยู่แล้ว WYN-072) แล้วค่อย gate ตอนจะ join/like/comment จริง
2. เพิ่ม UTM parameter มาตรฐานให้ลิงก์ที่ generate จากปุ่ม Share (เผื่อรวมกับสิ่งที่ WYN-112 แนะนำไปแล้วเรื่อง UTM tracking บนลิงก์ที่ Founder แชร์เอง — คนละจุดกัน แต่ target เดียวกันคือวัด attribution ได้)

Acceptance Criteria:
- เปิด `https://wynos.online/club/<id จริง>` จากเบราว์เซอร์ใหม่ (ไม่ login) เห็นหน้า Club นั้นจริง ไม่ใช่ Home
- เปิด `https://wynos.online/drop/<id>`, `/pop/<id>`, `/@<username>`, `/club-post/<id>` ได้ผลเดียวกันตามเนื้อหานั้น
- ปุ่ม Share ที่ generate ลิงก์ใหม่มี UTM parameter ติดมาด้วยเสมอ

Dependencies: ไม่มี dependency กับงานอื่น — WYN-114 (prerequisite ที่แท้จริง) เสร็จแล้ว ทำต่อได้ทันที

Priority: **P1** (ลดจาก P0 เดิม เพราะส่วนที่เร่งด่วนที่สุด — ลิงก์เปิดไม่ได้เลย — แก้ไปแล้วใน WYN-114 ส่วนที่เหลือคือ UX ที่ดีขึ้น ไม่ใช่ตัวบล็อกที่ทำให้ลิงก์ใช้งานไม่ได้เลยอีกต่อไป)

Risks: การเพิ่ม route parsing เข้า Flutter Web อาจกระทบพฤติกรรม guest-browsing เดิม (WYN-072) ต้องให้ Design ตรวจสอบ flow ให้ครบก่อน Coding

Recommendation: รอ Founder ตอบคำถามใน WYN-112 ก่อน (ลิงก์ที่แชร์มาจากปุ่ม Share ในแอปหรือพิมพ์เอง) เพื่อรู้ว่าเร่งด่วนแค่ไหนจริงๆ — แต่ไม่ต้อง block การเริ่มงานนี้เพราะ WYN-114 (prerequisite) เสร็จแล้วไม่ว่าคำตอบจะเป็นอะไร

Handoff: ส่งต่อ **AI Design** (ออกแบบ flow deep-link ฝั่ง guest) → AI Coding → AI QA & Security (ต้องทดสอบเปิดลิงก์จริงจากเบราว์เซอร์ที่ไม่เคย login มาก่อน ไม่ใช่แค่จากใน app)
