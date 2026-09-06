# WYN Club — Growth & Differentiation Roadmap

Owner: AI Product Manager
Created: 2026-09-06
Status: **Founder เลือกแล้ว (2026-09-06)** — ทำทั้ง 4 ตัวตามลำดับ WYN-115 → 116 → 117 → 118, หลัง WYN-114 (deploy แล้ว)

## บริบท

Founder ต้องการพัฒนาฟีเจอร์ Club ต่อ เพราะจะใช้เป็นจุดขายของ WYNOS ช่วงแรก — ตรงกับที่ `.wyn/docs/product/wynos-gtm-roadmap.md` (Phase 3) ระบุไว้แล้วว่า **"จุดขาย 'สร้างชุมชนของตัวเองได้' ตรงกับ WYN Mission"** คือช่องทางที่วางแผนจะใช้ดึง micro-influencer/creator เข้ามาสร้างฐานผู้ใช้กลุ่มแรก

## สถานะปัจจุบันของ Club (ตรวจโค้ดจริง ไม่ใช่เดา)

Club V1 Core ตาม `.wyn/docs/product/wyn-club-founder-brief.md` (2026-08-14) **ทำเสร็จเกือบครบทุกข้อแล้ว**:

| หมวดจาก Brief | สถานะ |
|---|---|
| สร้าง Club (ชื่อ/คำอธิบาย/รูป/Category/Privacy) | ✅ เสร็จ (WYN-014) |
| Public/Private + คำขอเข้าร่วมต้องอนุมัติ | ✅ เสร็จ |
| Club Page (Posts / Members / About) | ✅ เสร็จ |
| Role 4 ระดับ (Owner/Admin/Moderator/Member) + สิทธิ์ | ✅ เสร็จ |
| Approve/Remove/Ban สมาชิก, ตั้ง Role | ✅ เสร็จ |
| Pinned Post | ✅ เสร็จ |
| Club Rules (Owner ตั้ง, สมาชิกอ่านได้) | ✅ เสร็จ |
| Explore/Discovery (Search, Category, Popular, New, Recommended) | ✅ เสร็จ (WYN-015/017/056) |
| Home Integration ("จาก Club ของคุณ" feed tab) | ✅ เสร็จ |
| Report Club/Post/Comment | ✅ เสร็จ |
| Club Post หน้าตาแบบเดียวกับ Home feed + ปุ่มเชิญเพื่อน | ✅ เสร็จวันนี้ |

**สรุป**: ไม่มี "core feature" ตาม spec เดิมที่ขาดหายแล้ว — งานต่อจากนี้คือ**ฟีเจอร์ใหม่ที่ทำให้ Club เป็นแรงดึงดูด/แรงหมุนเวียนคนเข้าใหม่โดยเฉพาะ** ไม่ใช่แค่ปิด checklist เดิม

## ⚠️ พบระหว่างตรวจโค้ด — บั๊กที่กระทบ Growth Loop ของ Club โดยตรง (Founder ยืนยันเป็นสาเหตุของ WYN-112 แล้ว)

**ปุ่ม Share ออกนอกแอปของ Club (และ Drop/Pop/Profile) ทั้งหมดสร้างลิงก์โดเมนผิด (`wyn.app` แทน `wynos.online`) และไม่มี deep-link รองรับเลย** ผลคือฟีเจอร์ "เชิญเพื่อนมา Club" ที่เพิ่งทำเสร็จวันนี้ ถ้ากด Share ออกนอกแอป (ไม่ใช่ share-to-chat ในแอป) จะได้ลิงก์ที่ใช้งานไม่ได้จริง — Founder ยืนยันแล้วว่านี่คือสาเหตุจริงของปัญหา signup=0 ที่ WYN-112 สืบมา

**อัปเดตสถานะ**: ระหว่างเตรียมส่งงานแก้ พบว่าอีก session หนึ่งเจอบั๊กเดียวกันพร้อมกันและ**แก้+deploy จริงไปแล้ว** ภายใต้เลข `WYN-114` — แก้โดเมนครบ 5 จุด + เพิ่ม `app/web/vercel.json` (Vercel ไม่เคย config SPA rewrite เลย ทำให้ 404 ทุก path ที่ไม่ใช่ `/`) ผ่าน QA PASS และ deploy จริงแล้ว (`deploy-web.yml` run #89, production-verified ด้วย curl ตรง — `.wyn/logs/deployments/2026-09-06-wyn-114-share-link-vercel-rewrite-deploy.md`) — ส่วนงานที่เหลือ (path-based routing จริงในแอป ให้ลิงก์พาไปหน้าเนื้อหาที่ถูกต้อง ไม่ใช่แค่ไม่ 404) ย้ายไปเป็น `WYN-119` (เดิมชื่อ WYN-114 ในเอกสารนี้ฉบับก่อนหน้า — เปลี่ยนเลขแล้วเพื่อไม่ชนกัน) ดูรายละเอียดที่ `.wyn/tasks/active/WYN-119-club-deep-linking.md`

## ตัวเลือกฟีเจอร์ใหม่ — เรียงตาม "ทำอะไรได้เร็ว/ถูกสุด" ไม่ใช่ลำดับความสำคัญตายตัว (ให้ Founder เลือก)

### WYN-115 — Club Poll
**Goal**: ให้ Owner/สมาชิกสร้างโพลภายใน Club Post ได้ — วิธีง่ายที่สุดที่จะเพิ่ม engagement ในกลุ่ม (ถามความเห็น/โหวตกิจกรรม/ตัดสินใจร่วมกัน)
**ทำไมเร็ว**: Drop มีระบบ Poll เต็มรูปแบบอยู่แล้ว (`create_poll_drop()`, WYN-035) — งานนี้คือ "เอาของที่มีอยู่แล้วมาต่อกับ Club Post" ไม่ใช่สร้างใหม่ทั้งหมด
**Priority แนะนำ**: P1 — effort ต่ำ, ผลตอบแทนชัดเจน, ไม่กระทบ data model เดิม

### WYN-116 — Club Re-engagement Notification
**Goal**: แจ้งเตือนสมาชิกเมื่อ Club ที่เข้าร่วมมีโพสต์ใหม่/ประกาศ Pin ใหม่ (ไม่ใช่แค่ reply/like ที่มีแจ้งเตือนอยู่แล้ว)
**ทำไมสำคัญกับ "จุดขายช่วงแรก"**: คนกลุ่มแรกที่ Founder ชวนมาจะหายไปถ้าเข้า Club แล้วไม่มีอะไรดึงกลับมาเปิดแอปอีก — ตรงกับปัญหา "engagement เป็นศูนย์" ที่ WYN-112 กำลังสืบอยู่พอดี
**Priority แนะนำ**: P1 — ต้องรอ Push Notification (Firebase) infra ที่มีโค้ดพร้อมแล้วแต่รอ config จริงตาม `wynos-gtm-roadmap.md` ข้อจำกัดที่ 5

### WYN-117 — Club Owner Insights
**Goal**: หน้าสรุปสถิติสำหรับ Owner/Admin ของ Club (จำนวนสมาชิกใหม่/โพสต์/engagement ย้อนหลัง 7-30 วัน)
**ทำไมสำคัญกับ "จุดขายช่วงแรก"**: ตรงกับแผน GTM Phase 3 ที่จะไปชวน micro-influencer/เจ้าของชุมชนมาสร้าง Club บน WYNOS — คนกลุ่มนี้ตัดสินใจ "ลงทุน" สร้างชุมชนที่นี่มากขึ้นถ้าเห็นข้อมูลการเติบโตชัดเจน เหมือนที่ Facebook Group/Discord ให้ Admin เห็น
**Priority แนะนำ**: P2 — มีคุณค่าจริงแต่ effort ปานกลาง-สูง (ต้อง aggregate query ใหม่), ไม่ block การเปิดตัว Club เป็นจุดขายทันที

### WYN-118 — Club Events
**Goal**: ให้ Club นัดกิจกรรม/meetup ได้ (วันเวลา, สถานที่/ลิงก์ออนไลน์, RSVP)
**ทำไมตรง target user**: Brief เดิม (ข้อ 19) ระบุไว้เป็น "future" ตั้งแต่แรก แต่ตรงกับ target user Gen Z ไทยที่สุด (กลุ่มมหาวิทยาลัย, แฟนคลับ, งานอดิเรกเฉพาะทาง — ตัวอย่างที่ `wynos-gtm-roadmap.md` เองก็ระบุไว้)
**Priority แนะนำ**: P2 — scope ใหญ่กว่าอันอื่นทั้งหมด กระทบ data model ใหม่ (ตาราง Event + RSVP) ควรทำหลังฟีเจอร์เล็กกว่าพิสูจน์ตัวเองก่อน

## คำแนะนำโดยรวม

1. ~~Deploy WYN-114~~ — **เสร็จแล้ว** (2026-09-06, production-verified)
2. **WYN-115 (Club Poll)** — เริ่มก่อน (Founder เลือก + effort ต่ำสุด, ต่อยอดของเดิมได้เลย)
3. **WYN-116 → WYN-117 → WYN-118** ตามลำดับที่ Founder เลือก

Handoff: **Founder เลือกลำดับแล้ว** (2026-09-06) — Product Task เต็มรูปแบบของทั้ง 4 ตัวเขียนไว้ครบแล้วที่ `.wyn/tasks/backlog/WYN-115...118-*.md` → ส่งต่อ AI Design เริ่มจาก WYN-115 → AI Coding → AI QA & Security
