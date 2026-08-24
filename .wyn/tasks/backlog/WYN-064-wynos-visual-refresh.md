# Product Task — WYN-064

Status: backlog
Owner: AI Product Manager

Feature: WYNOS Visual Refresh — Light/Premium Design Direction + Profile/Feed/Drop/Bottom Nav Alignment

Goal: จัดโครงสร้าง UI/UX ของ WYNOS ให้รู้สึกเป็น social platform ระดับใหญ่ (premium, clean, มี identity ของตัวเอง ไม่ใช่ clone) ตาม direction ใหม่ที่ Founder ส่งมา โดยใช้ของเดิมที่มีอยู่แล้วให้มากที่สุดก่อนสร้างใหม่

Target User: ผู้ใช้ WYNOS ทุกคน — เป็นงานปรับ visual/structural ทั้งแอป ไม่ใช่ฟีเจอร์เดียว

Problem: Founder ส่ง spec ยาวมาผ่าน `/product` ระบุว่า "ใช้ภาพอ้างอิงที่แนบมาเป็นแรงบันดาลใจ" — **แต่ตรวจสอบ conversation แล้วไม่พบไฟล์ภาพแนบมาจริงในข้อความนี้ (มีแต่ข้อความ spec ล้วน)** จึงวิเคราะห์และเขียน requirement นี้จากข้อความ spec เท่านั้น ยังไม่เห็นภาพอ้างอิงจริง — **ต้องขอ Founder ยืนยัน/แนบภาพใหม่ก่อน AI Design เริ่มงานจริง** เพราะ "ห้ามลอกดีไซน์แอปต้นแบบโดยตรง" หมายความว่ามีภาพอ้างอิงที่ต้องระวังอยู่จริง แต่ AI ยังไม่เคยเห็น

ตรวจสอบ codebase ปัจจุบันก่อนเขียน spec (ตาม RULES.md "ตรวจสอบก่อนเสมอ") พบว่า**หลายส่วนของ spec นี้ตรงหรือใกล้เคียงกับของที่มีอยู่แล้วมาก**:

- **สี**: `WynColors` (DS-001, Founder อนุมัติแล้ว 2026-08-15) มี Cyan `#00C8FF` เป็น primary ทั้ง light/dark scheme ตรงกับ spec เป๊ะ, `socialLightScheme` มีพื้นหลังขาว (`white`)/ตัวอักษรดำ (`ink` #0A0A0A) อยู่แล้วครบ, การ์ด flat ไม่มีเงา (Threads-style, DS-002) ตรงกับ "clean, minimal" อยู่แล้ว — **ธีมสว่างที่ Founder อยากได้มีอยู่แล้วจริง ไม่ใช่ของใหม่**
- **Theme Mode ปัจจุบัน**: `main.dart` ตั้ง `themeMode: ThemeMode.system` (ตามการตั้งค่าเครื่องผู้ใช้ ไม่ได้ fix เป็น dark) — ถ้า Founder อยากให้แอปแสดงพื้นหลังขาวเป็นค่าเริ่มต้นเสมอ (ไม่ใช่ตามเครื่อง) ต้องเปลี่ยนเป็น `ThemeMode.light` ตรงๆ ซึ่งเป็นการตัดสินใจ Product ที่ต้อง Founder ยืนยันเอง (ผู้ใช้ที่ตั้งเครื่องเป็น dark mode จะเห็น WYNOS เป็น dark ต่อไปถ้าไม่ fix)
- **Bottom Navigation**: ปัจจุบันมีอยู่แล้ว 5 tab — Home / Search / Drop(ปุ่มสร้างโพสต์เด่น) / Notifications / Profile — ใกล้เคียง spec มาก (spec ไม่มี tab Search แยก เพราะย้าย Search ไปเป็นไอคอนบนแถบบนของ Home แทน)
- **Recommendation Algorithm**: WYN-063 (Unified Home Feed Algorithm, เสร็จและ deploy แล้ววันนี้) มี weighted scoring ครบ (Personalized Interest/Following/Engagement/Trending/Recency/Discovery) และมี `feed_diversity.dart` กันไม่ให้ account เดิมโผล่ซ้ำเกินไปอยู่แล้ว — **ตรงกับ requirement ส่วน Recommendation Algorithm ของ spec นี้เกือบทั้งหมด** ขาดแค่สัญญาณ "เปิดดูนาน" (dwell time) ที่ยังไม่มีการเก็บข้อมูลนี้เลยในระบบ
- **Repost**: มีอยู่แล้วในชื่อ "ReDrop" (WYN-034) — เป็น concept เดียวกัน แค่ label ภาษาอังกฤษต่างกัน

**ส่วนที่เป็นของใหม่จริง (gap ที่ไม่มีอยู่ในระบบเลย)**:
1. Drop รองรับหลายรูป (1–9 รูป, grid) — ปัจจุบัน Drop รองรับแค่ 1 รูปต่อโพสต์เท่านั้น (แม้จะมี text-only จาก WYN-062 แล้วก็ตาม)
2. Recommendation Section บน Profile ("แนะนำสำหรับคุณ", horizontal card, ปุ่ม X ซ่อน) — ไม่มีอยู่บน Profile เลยตอนนี้ (มีแค่บน Home)
3. Profile Tabs ใหม่ (Posts/Replies/Media/Likes) — ต่างจาก taxonomy ปัจจุบัน (Drop/ReDrop/Saved/Draft, Pop ซ่อนแล้วจาก WYN-066) โดยเฉพาะ **"Replies" และ "Likes" เป็น tab ที่ไม่เคยมีมาก่อนเลย** (ดู Requirement/Risk ด้านล่าง — มีประเด็น privacy ต้องตัดสินใจ)
4. Micro-interactions บางส่วนที่ยังไม่ยืนยันว่ามี: Follow animation, Tab transition, Haptic feedback — ต้องตรวจเพิ่มเติมทีละจุดตอน Design/Coding

Requirements:
- R1. **ยืนยันภาพอ้างอิงกับ Founder ก่อนเริ่ม Design จริง** (ดู Problem — ยังไม่เห็นภาพในเซสชันนี้)
- R2. ตัดสินใจ ThemeMode: fix เป็น Light เสมอ หรือคง `ThemeMode.system` แต่ปรับปรุงแค่ light scheme ให้ตรง spec มากขึ้น (border color จาก `#E5E7EB`→`#EAEAEA` เป็นต้น ถ้าต้องการเป๊ะตาม spec)
- R3. เพิ่ม multi-image Drop (1–9 รูป) — schema ใหม่ (ตาราง `drop_images` แยกจาก `drops.image_url` เดิม หรือ array column), UI grid ใหม่, full-screen viewer พร้อม swipe ระหว่างรูป, client-side compression ทุกรูปก่อน upload (ต่อยอด pattern การ compress ที่ WYN-005 มีอยู่แล้วสำหรับรูปเดียว)
- R4. เพิ่ม Recommendation Section บน Profile (horizontal scroll, dismiss ได้ด้วยปุ่ม X — ต้องมี state เก็บว่า user dismiss คนไหนไปแล้วเพื่อไม่ให้ suggest ซ้ำ)
- R5. ปรับ Profile Tabs เป็น Posts/Replies/Media/Likes — **ต้อง Founder ตัดสินใจ privacy ก่อน**: "Replies" (ดู Comment ที่ user เคยเขียน)/"Likes" (ดู content ที่ user เคย Like) แสดงให้ใครเห็นได้บ้าง (เจ้าของโปรไฟล์เท่านั้น หรือสาธารณะเหมือน Posts/Media) — เป็นข้อมูลที่ไม่เคยเปิดเผยแบบนี้มาก่อนในระบบ
- R6. เพิ่มสัญญาณ dwell-time ("เปิดดูนาน") เข้า ranking algorithm ของ WYN-063 — ต้องมี schema ใหม่เก็บเวลาที่ผู้ใช้ดูแต่ละโพสต์ (privacy-sensitive ระดับหนึ่ง ต้องพิจารณา)
- R7. เติม micro-interaction ที่ยังไม่ยืนยัน (Follow animation, Tab transition, Haptic feedback) ให้ครบตามจุดที่ยังขาด — ตรวจสอบให้ชัดตอน Design/Coding ว่าจุดไหนมีอยู่แล้วบ้าง
- R8. Profile top bar: เพิ่ม Search/Notifications icon เข้าไปด้วย (ปัจจุบัน Profile มีแค่ Settings/Logout หรือ More menu เท่านั้น ไม่มี Search/Notifications shortcut)

Acceptance Criteria:
- [ ] Founder ยืนยันภาพอ้างอิง หรือยืนยันให้ทำจากข้อความ spec อย่างเดียวได้
- [ ] Light theme (fix หรือ system-follow ตามที่ Founder เลือก) ใช้งานได้ทุกหน้า ไม่มีจุดที่ยังเป็น dark ค้าง (ถ้าเลือก fix light)
- [ ] Drop สร้างได้ 1–9 รูป, แสดง grid ถูกต้อง, เปิด full-screen swipe ดูได้, ทุกรูป compress ก่อน upload
- [ ] Profile มี Recommendation Section, dismiss แล้วไม่ suggest ซ้ำ
- [ ] Profile Tabs ใหม่ตาม privacy ที่ Founder เลือก ทำงานถูกต้อง
- [ ] Regression: ฟีเจอร์เดิมทั้งหมด (Drop เดี่ยวรูป, Poll, text-only จาก WYN-062, ReDrop, Comment, Search, ranking algorithm WYN-063) ยังทำงานถูกต้องทุกจุด

Dependencies: ต่อยอด DS-001 (สี, อนุมัติแล้ว), WYN-062 (text-only Drop), WYN-063 (ranking algorithm), WYN-066 (ซ่อน Pop จาก Profile) — ไม่ต้องสร้าง design system ใหม่ตั้งแต่ต้น ใช้ `WynColors`/`WynTheme`/`WynSpacing`/`WynTypography` เดิมทั้งหมด

Priority: **ต้องรอ Founder ตัดสินใจ 4 จุดก่อน** (ดู R1/R2/R5/R6) ก่อนกำหนด priority ที่แท้จริงของแต่ละ sub-requirement — ส่วนที่ไม่มีคำถามค้าง (R3 multi-image Drop, R4 Recommendation section, R7 micro-interactions, R8 Profile top bar) ทำต่อได้เลยไม่ต้องรอ

Risks: 
- multi-image Drop (R3) เป็น schema change ระดับกลาง (ตารางใหม่/relationship ใหม่) กระทบทุกจุดที่เคยสมมติว่า Drop มีรูปเดียว (เยอะพอสมควรหลัง WYN-062 ทำให้ null-safe ไปแล้วรอบหนึ่ง) — ต้องตรวจซ้ำทุกจุดอีกครั้ง
- Replies/Likes tab แบบสาธารณะ (ถ้า Founder เลือก) เปิดเผยพฤติกรรมผู้ใช้ที่ไม่เคยเปิดเผยมาก่อน อาจกระทบความเป็นส่วนตัวที่ผู้ใช้ไม่คาดคิด (โดยเฉพาะ Gen Z target user ตาม Vision ที่เน้น "ความปลอดภัยและความเป็นส่วนตัว" ใน COMPANY.md) — แนะนำ default เป็น "เจ้าของโปรไฟล์เท่านั้น" เว้นแต่ Founder ยืนยันชัดเจนว่าต้องการสาธารณะ
- Dwell-time tracking (R6) เก็บพฤติกรรมการดูละเอียดขึ้น ต้องพิจารณาประเด็น privacy/data minimization เช่นกันก่อนทำจริง

Recommendation: 
- เริ่มจากส่วนที่ไม่มีคำถามค้าง (R3/R4/R7/R8) ให้ AI Design ทำก่อนได้เลย เพื่อไม่เสียเวลารอ
- Replies/Likes tab แนะนำ default เป็น private (เจ้าของโปรไฟล์เท่านั้น) ตาม WYN Mission เรื่องความเป็นส่วนตัว เว้นแต่ Founder ต้องการสาธารณะจริงๆ
- Dwell-time signal (R6) แนะนำเลื่อนเป็นงานแยกต่างหาก (ไม่ block งานนี้) เพราะเป็น schema ใหม่ที่ต้องคิด privacy ให้รอบคอบกว่านี้ ไม่ควรรีบทำรวมในรอบเดียว

Handoff: AI Design เริ่มจาก R3 (multi-image Drop)/R4 (Recommendation section)/R7/R8 ได้ทันที — R1/R2/R5/R6 รอคำตอบ Founder ก่อน (ถามผ่าน popup ตาม RULES.md)
