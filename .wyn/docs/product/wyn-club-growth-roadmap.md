# WYN Club — Growth & Differentiation Roadmap

Owner: AI Product Manager
Created: 2026-09-06
Status: PROPOSED — รอ Founder เลือกลำดับก่อนเริ่ม Design/Coding

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

## ⚠️ พบระหว่างตรวจโค้ด — บั๊กที่กระทบ Growth Loop ของ Club โดยตรง

ดูรายละเอียดเต็มที่ `.wyn/tasks/backlog/WYN-114-fix-share-links-deep-linking.md` — **ปุ่ม Share ออกนอกแอปของ Club (และ Drop/Pop/Profile) ทั้งหมดสร้างลิงก์โดเมนผิด (`wyn.app` แทน `wynos.online`) และไม่มี deep-link รองรับเลย** ผลคือฟีเจอร์ "เชิญเพื่อนมา Club" ที่เพิ่งทำเสร็จวันนี้ ถ้ากด Share ออกนอกแอป (ไม่ใช่ share-to-chat ในแอป) จะได้ลิงก์ที่ใช้งานไม่ได้จริง — **แนะนำแก้ก่อนเริ่มฟีเจอร์ใหม่ด้านล่างทั้งหมด** เพราะฟีเจอร์ growth ใหม่ที่พึ่งการแชร์ออกนอกแอปจะไม่มีความหมายถ้าลิงก์ยังพังอยู่ (และอาจเชื่อมกับปัญหา signup=0 ที่ WYN-112 กำลังสืบอยู่ตอนนี้ด้วย)

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

1. **แก้ WYN-114 (ลิงก์ Share พัง) ก่อนอย่างอื่นทั้งหมด** — ไม่งั้นฟีเจอร์ growth ใหม่ที่พึ่งการแชร์จะไม่มีความหมาย
2. เริ่ม **WYN-115 (Club Poll)** เป็นฟีเจอร์ใหม่ตัวแรก เพราะ effort ต่ำที่สุด ต่อยอดของเดิมได้เลย เห็นผลไว
3. **WYN-116/117/118** รอ Founder เลือกลำดับ — ไม่แนะนำทำพร้อมกันทั้งหมดเพราะทีมมีแค่ AI + Founder คนเดียว ตาม `wynos-gtm-roadmap.md` เอง

Handoff: รอ Founder เลือกลำดับ (ถามแยกไปพร้อมกันผ่าน popup) → เขียน Product Task เต็มรูปแบบ (Requirements/Acceptance Criteria ละเอียด) เฉพาะตัวที่เลือกก่อน → AI Design → AI Coding → AI QA & Security
