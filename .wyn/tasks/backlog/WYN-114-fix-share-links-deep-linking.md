# Product Task — WYN-114

Status: backlog
Owner: AI Product Manager

Feature: แก้ลิงก์ Share ภายนอกที่ผิดทั้งระบบ + เพิ่ม Deep Linking จริง

Goal: ทำให้ "แชร์ Club/Drop/Pop/Profile ออกนอกแอป" ใช้งานได้จริง — คนกดลิงก์แล้วต้องไปถึง WYNOS และเห็นเนื้อหานั้นจริง ไม่ใช่ไปที่ไหนก็ไม่รู้หรือหน้า 404

Target User: ทุกคนที่กดปุ่ม "Share" ออกนอกแอป (ไม่ใช่ share-to-chat ในแอป) บน Club/Club Post/Drop/Profile และเพื่อนที่พวกเขาส่งลิงก์ไปให้

Problem: ตรวจโค้ดพบว่า **ทุกจุดที่สร้างลิงก์แชร์ภายนอกในทั้งแอปใช้โดเมน `https://wyn.app/...`** ซึ่งไม่ใช่โดเมน production จริง (`wynos.online`) เลย — พบ 5 จุด:
- `clubShareLink()` → `club_page.dart` (`https://wyn.app/club/$clubId`)
- `clubPostShareLink()` → `club_post_detail_screen.dart` (`https://wyn.app/club-post/$postId`)
- `dropShareLink()` → `drop_detail_screen.dart` (`https://wyn.app/drop/$dropId`)
- `popShareLink()` → `pop_clip_view.dart` (`https://wyn.app/pop/$popId`)
- `profileShareLink()` → `view_profile_screen.dart` (`https://wyn.app/@$username`)

นอกจากโดเมนผิดแล้ว **ตรวจ `main.dart` ไม่พบการทำ route/deep-link ใดๆ เลย** — ต่อให้แก้โดเมนเป็น `wynos.online` เฉยๆ การเปิดลิงก์ `wynos.online/club/<id>` ก็จะแค่โหลดแอปแล้วไปหน้า Home เหมือนเปิดเว็บเปล่าๆ ไม่พาไปที่ Club/Drop/Pop/Profile ที่ตั้งใจแชร์เลย — **ฟีเจอร์ "เชิญเพื่อนมา Club" ที่เพิ่งทำเสร็จวันนี้ (ปุ่มแชร์นอกแอป ไม่ใช่ share-to-chat) จึงใช้งานจริงไม่ได้เลยตั้งแต่แรก**

**เชื่อมกับ WYN-112 (Activation Funnel Investigation, กำลัง active อยู่ตอนนี้)**: WYN-112 กำลังหาสาเหตุที่ signup เป็น 0 ทั้งที่ Founder ยืนยันว่ายังแชร์ลิงก์ต่อเนื่อง — **ถ้าลิงก์ที่ Founder แชร์มาจากปุ่ม Share ในแอป (ไม่ใช่พิมพ์ `wynos.online` ตรงๆ เอง) บั๊กนี้คือคำตอบที่เป็นไปได้โดยตรง**: คนกดลิงก์ `wyn.app/...` แล้วไปไม่ถึง WYNOS เลยสักคน จึง signup = 0 ไม่ว่าจะมีคนคลิกกี่ครั้งก็ตาม — ต้องถาม Founder ยืนยันก่อนว่าลิงก์ที่แชร์มาจากไหน (ดูคำถามที่ส่งแยกไปพร้อมกัน)

Requirements:
1. เปลี่ยนโดเมนทั้ง 5 จุดจาก `wyn.app` เป็น `wynos.online` จริง
2. เพิ่ม client-side route handling ให้ Flutter Web อ่าน path จาก URL ตอนโหลดครั้งแรก (`/club/:id`, `/club-post/:id`, `/drop/:id`, `/pop/:id`, `/@:username`) แล้วพาไปหน้าจอที่ถูกต้องแทนที่จะเปิด Home เสมอ — รวมถึงกรณี guest (ยังไม่ login) ต้องเห็น preview เนื้อหาได้ก่อน (ตาม guest-browsing ที่มีอยู่แล้ว WYN-072) แล้วค่อย gate ตอนจะ join/like/comment จริง
3. ตรวจสอบว่า Vercel serve SPA fallback ถูกต้อง (deep path ต้อง fallback มาที่ `index.html` ไม่ใช่ 404 ตรงๆ จาก edge — ต้องตรวจ config จริงเพราะ repo ไม่มี `vercel.json` ที่เห็น)
4. เพิ่ม UTM parameter มาตรฐานให้ลิงก์ที่ generate จากปุ่ม Share (เผื่อรวมกับสิ่งที่ WYN-112 แนะนำไปแล้วเรื่อง UTM tracking)

Acceptance Criteria:
- เปิด `https://wynos.online/club/<id จริง>` จากเบราว์เซอร์ใหม่ (ไม่ login) เห็นหน้า Club นั้นจริง ไม่ใช่ Home
- เปิด `https://wynos.online/drop/<id>`, `/pop/<id>`, `/@<username>`, `/club-post/<id>` ได้ผลเดียวกันตามเนื้อหานั้น
- ปุ่ม Share ทุกจุดใน UI สร้างลิงก์โดเมน `wynos.online` เท่านั้น ไม่มี `wyn.app` เหลืออยู่เลย (grep ยืนยันได้)
- ลิงก์เก่าที่เคยแชร์ไปแล้วด้วยโดเมน `wyn.app` จะยังใช้ไม่ได้ (คนละโดเมน แก้ย้อนหลังให้ไม่ได้) — ต้องแจ้ง Founder ให้แชร์ใหม่หลัง fix นี้ deploy

Dependencies: ไม่มี dependency กับงานอื่น ทำได้ทันที — แต่ผลกระทบเชื่อมกับ WYN-112 โดยตรง (ดูด้านบน)

Priority: **P0 — สงสัยว่าอาจเป็น blocker ตัวจริงของ growth loop ทั้งหมดตอนนี้** (ทั้ง Club invite ที่เพิ่งทำ และการแชร์ทั่วไปที่ WYN-112 กำลังสืบอยู่)

Risks:
- ถ้า Founder ยืนยันว่าลิงก์ที่แชร์เป็น `wynos.online` ตรงๆ มาตลอด (ไม่ได้ผ่านปุ่ม Share ในแอป) บั๊กนี้จะไม่ใช่สาเหตุของ WYN-112 โดยตรง — แต่ยังคงเป็นบั๊กจริงที่ต้องแก้อยู่ดี เพราะกระทบทุกครั้งที่มีคนใช้ปุ่ม Share ในแอปต่อจากนี้ (รวมถึง Club invite ที่เป็นเป้าหมายของ session นี้)
- การเพิ่ม route parsing เข้า Flutter Web อาจกระทบพฤติกรรม guest-browsing เดิม (WYN-072) ต้องให้ Design ตรวจสอบ flow ให้ครบก่อน Coding

Recommendation: ถามยืนยัน Founder ก่อนว่าลิงก์ที่แชร์มาจากไหน (คำถามแยกที่ส่งไปพร้อมกัน) — ถ้าตรงกับสมมติฐาน ให้ยกระดับเป็น P0 เร่งด่วนที่สุดของทั้งบริษัทตอนนี้ (สำคัญกว่า roadmap Club ฉบับใหม่ด้านล่างทั้งหมด) เพราะเป็นตัวบล็อก measurement/growth ทุกช่องทางพร้อมกัน ไม่ใช่แค่ Club

Handoff: รอ Founder ยืนยันก่อน → AI Design (ออกแบบ flow deep-link ฝั่ง guest + SPA fallback config) → AI Coding → AI QA & Security (ต้องทดสอบเปิดลิงก์จริงจากเบราว์เซอร์ที่ไม่เคย login มาก่อน ไม่ใช่แค่จากใน app)
