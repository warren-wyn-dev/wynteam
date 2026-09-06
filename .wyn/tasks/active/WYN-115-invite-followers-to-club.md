# Product Task — WYN-115

Status: active (Design เสร็จแล้ว 2026-09-06, รอ Founder อนุมัติ mockup ก่อนส่งต่อ AI Coding — ดู "AI Design Output" ท้ายไฟล์นี้)
Owner: AI Product Manager
Feature: Invite Followers to Club (pick-from-followers, not just link sharing)
Goal: ให้สมาชิกคลับชวนคนที่ติดตามตัวเองเข้าคลับได้โดยตรงในแอป ไม่ต้องพึ่งการก็อปลิงก์ไปแปะที่อื่นเพียงอย่างเดียว
Target User: สมาชิกที่ approved แล้วของคลับใดก็ตาม (คนเดียวกับที่เห็นปุ่ม "ชวนเพื่อนเข้ากลุ่ม" อยู่แล้วตอนนี้)
Problem: ตอนนี้ปุ่ม "ชวนเพื่อนเข้ากลุ่ม" ใน `club_members_tab.dart` (ผ่าน `onInvite` ใน `club_page.dart:404`) เปิดแค่ `showShareSheet` ทั่วไป (แชร์ลิงก์ผ่านระบบมือถือ / คัดลอกลิงก์ / แชร์เข้า Chat) — ตัวเลือก "แชร์เข้า Chat" ที่มีอยู่แล้ว (`ShareToChatScreen`) ก็ค้นหาได้แค่จาก **conversation ที่เคยคุยด้วยแล้ว** หรือ **ค้นหาชื่อผู้ใช้ทั่วทั้งระบบ** (`ProfileRepository.searchProfiles`) — ไม่มีทางเลือก "ดูรายชื่อคนที่ติดตามฉัน แล้วเลือกชวนตรงๆ" เลย ต้องรู้ชื่อ username หรือเคยคุยกันมาก่อนเท่านั้น
Requirements:
- เพิ่มตัวเลือกในหน้าจอชวนเข้าคลับ: แสดงรายชื่อ**คนที่ติดตามผู้ใช้ปัจจุบัน + คนที่ผู้ใช้ปัจจุบันติดตาม** (รวมสองทิศทาง, dedupe คนซ้ำ — Founder ตัดสินใจ 2026-09-06 หลังเทียบกับ Instagram Group Chat ที่ใช้ pattern เดียวกัน; ดู "Founder Decision" ท้ายไฟล์) — ใช้ `FollowRepository.fetchFollowers()` + `fetchFollowing()` ที่มีอยู่แล้วทั้งคู่ ไม่ต้องเขียน query ใหม่ แต่ต้อง merge/dedupe ฝั่ง client
- เลือกได้ทีละคนหรือหลายคน (Design ตัดสินใจว่าเหมาะกับแบบไหนมากกว่า)
- กดเชิญแล้วเกิดอะไรขึ้น (Design/Coding ตัดสินใจร่วมกับ Founder ตอน spec นี้ถูกหยิบไปทำจริง — ตัวเลือกที่เป็นไปได้โดยใช้ของที่มีอยู่แล้ว ไม่ต้องสร้าง infra ใหม่):
  - (ก) ส่งเป็นข้อความ "แชร์เข้า Chat" อัตโนมัติพร้อมลิงก์คลับ (ต่อยอด `ChatRepository`/`SharedContentType.club` ที่มีอยู่แล้วจาก WYN-033) หรือ
  - (ข) ส่ง Notification ประเภทใหม่ตรงๆ ("X ชวนคุณเข้าคลับ Y") ผ่านระบบ Notification ที่มีอยู่แล้ว
- ~~คนที่ถูกเลือกไม่จำเป็นต้อง follow กลับ (ทิศทางเดียวพอ)~~ **แก้ไข 2026-09-06**: ไม่เกี่ยวแล้วเพราะรวมทั้งสองทิศทาง (follower หรือ following ก็เชิญได้ทั้งคู่)
- ไม่กระทบตัวเลือกเดิม (แชร์ลิงก์ผ่านระบบมือถือ/แชร์เข้า Chat แบบค้นหาทั่วไป/คัดลอกลิงก์) ยังใช้งานได้เหมือนเดิมทั้งหมด เป็นตัวเลือกเสริม ไม่ใช่แทนที่
Acceptance Criteria:
- สมาชิกคลับกด "ชวนเพื่อนเข้ากลุ่ม" แล้วเห็นตัวเลือกดูรายชื่อ follower ของตัวเองได้ โดยไม่ต้องรู้ username ล่วงหน้า
- เลือกคนจาก follower list แล้ว "เชิญ" สำเร็จ คนที่ถูกเชิญได้รับลิงก์/แจ้งเตือนจริง เปิดแล้วเข้าคลับได้ (ขึ้นกับ WYN-114 deep-link fix ใช้งานได้ก่อน ถ้าใช้ช่องทางลิงก์)
- ทดสอบกับคนที่ไม่มี follower เลย (list ว่าง) ต้องไม่ crash แสดงข้อความที่เหมาะสม
Dependencies: **WYN-114 (Share links ไม่เด้งไปหน้าที่ถูกต้อง)** ถ้าช่องทางเชิญจะพึ่งลิงก์ — แนะนำให้ WYN-114 ผ่าน QA ก่อน ไม่งั้นเชิญไปแล้วคนกดลิงก์ก็ยังไม่เจอหน้าคลับอยู่ดี — ใช้ `FollowRepository.fetchFollowers()`/`fetchFollowing()` ที่มีอยู่แล้วทั้งคู่, ต่อยอด `ShareToChatScreen`/`SharedContentType.club` (WYN-033) ที่มีอยู่แล้วถ้าเลือกทาง (ก) ข้างบน
Priority: P2 — เป็นการปรับปรุง UX ของฟีเจอร์ที่มีอยู่แล้ว (invite ทำได้อยู่แล้วผ่านลิงก์) ไม่ใช่ฟีเจอร์ที่ขาดหายไปเลยทั้งหมด
Risks: ไม่มีความเสี่ยงด้าน data/security ใหม่ (`fetchFollowers` เป็น query ที่มีอยู่แล้ว ผ่าน RLS เดิม) — ความเสี่ยงหลักคือ UX เลือกผิดแบบ (list ยาวเกินไปถ้า follower เยอะ ควรมี search/filter ในตัว list ด้วยถ้า Design เห็นว่าจำเป็น)
Recommendation: **ต้องมี mockup ให้ Founder ดูและอนุมัติก่อนเริ่มเขียนโค้ด** ตามกติกาถาวรที่ Founder ตั้งไว้เอง (`.wyn/company/DECISIONS.md`, [2026-09-03] "ขอดูรูปก่อน เขียนโค้ดนะ" — งาน UI ใดๆ ต้องมี Artifact/mockup ก่อนเสมอ ไม่ว่าจะเปลี่ยนเล็กแค่ไหน) — ยังไม่ได้ทำมาก่อนหน้านี้เพราะเรื่องนี้เพิ่งถูกอธิบายเป็นคำพูดในการสนทนา ยังไม่มีภาพประกอบ
Handoff: ส่งต่อ AI Design เพื่อออกแบบหน้าจอ/bottom sheet เลือก follower ก่อน (ต่อยอดจาก `club_members_tab.dart`'s ปุ่มเชิญเดิม) แล้วค่อยส่ง AI Coding พร้อม mockup ที่ Founder อนุมัติแล้ว

## AI Design Output (2026-09-06)

Design spec เต็มอยู่ที่ `.wyn/docs/design/wyn-115-invite-followers-to-club.md` — สรุปการตัดสินใจหลัก:

- **ตอบ Requirement "เลือกทีละคนหรือหลายคน"**: เลือกทีละคน กดแล้วเชิญทันที ไม่มีขั้นตอน confirm แยก — ทำตาม pattern ที่ `ShareToChatScreen` (WYN-033) ใช้อยู่แล้วเป๊ะ (single-tap-to-send) ไม่ต้องคิด interaction ใหม่ ต่างแค่จุดเดียว: หน้าจอนี้**ไม่ปิดตัวเองหลังเชิญสำเร็จ** (แถวเปลี่ยนเป็น "เชิญแล้ว" ค้างไว้แทน) เพราะธรรมชาติของงานคือเชิญหลายคนต่อเนื่องในครั้งเดียวที่เปิดหน้าจอ ไม่ใช่ "แชร์ 1 ชิ้นให้ 1 คน" แบบเดิม
- **ตอบ Requirement "กดเชิญแล้วเกิดอะไรขึ้น"**: เลือกทาง (ก) — ส่งผ่าน "แชร์เข้า Chat" เดิม (`ChatRepository.getOrCreateConversation` + `sendMessage(sharedContentType: club)`) ไม่สร้าง Notification ประเภทใหม่ (ทาง ข) เพราะทาง (ก) ใช้ของที่มีอยู่แล้ว 100% ไม่ต้องแตะ schema/RLS/Edge Function ใดๆ เลย ความเสี่ยงต่ำกว่ามาก
- Entry point: เพิ่มแถวที่ 4 ("เชิญจากผู้ติดตาม") บนสุดของ `showShareSheet` เดิม เฉพาะตอน `sharedContentType == club` เท่านั้น — ปุ่ม "ชวนเพื่อนเข้ากลุ่ม"/ไอคอนแชร์ header เดิมไม่ต้องเปลี่ยนอะไรเลย
- หน้าจอใหม่ `InviteToClubScreen` reuse โครงแถว/ช่องค้นหา/infinite-scroll จาก `FollowListScreen` ทั้งหมด ต่างแค่ trailing widget (ปุ่ม "เชิญ"/"เชิญแล้ว" แทนปุ่ม Follow)
- **ไม่กรองคนที่เป็นสมาชิกคลับอยู่แล้วออกจาก list** ในรอบแรกนี้ (ตั้งใจตัดสโคป — เหตุผลเต็มอยู่ใน design doc "Known Limitation") ไม่ใช่ bug

**รอ Founder อนุมัติ mockup ก่อนส่งต่อ AI Coding** ตามกติกา "ขอดูรูปก่อน เขียนโค้ดนะ" — ยังไม่มีการเขียนโค้ดใดๆ ในรอบนี้

## Founder Decision (2026-09-06)

Founder ถามเทียบกับ Instagram/X ว่าเชิญจากรายชื่อไหน — AI Design ตอบตามที่รู้จริง: Instagram Close Friends ใช้ follower, X Communities ใช้ following, ไม่มีมาตรฐานเดียวกัน **Founder เลือก: รวมทั้งสองทาง (Followers + Following, dedupe คนซ้ำ)** — ตรงกับ pattern ของ Instagram Group Chat "Add People"

ผลต่อ Design/implementation:
- `InviteToClubScreen` ต้องดึงทั้ง `fetchFollowers()` และ `fetchFollowing()` แล้ว merge + dedupe ด้วย profile id ฝั่ง client (ไม่มี RPC รวมสองทางสำเร็จรูปในระบบตอนนี้ ต่างจาก `fetchMutualFollows()` ที่เป็นค่า intersection ไม่ใช่ union)
- Pagination ซับซ้อนขึ้นเล็กน้อย: ต้อง track ว่าแต่ละ list (`followers`/`following`) ยังมีหน้าถัดไปไหมแยกกัน โหลดต่อจากอันที่ยังมีอยู่จนกว่าจะได้แถวใหม่พอ (คน dedupe ซ้ำออกไปแล้วนับไม่ครบ page ก็ต้องโหลดต่อ) — รายละเอียด algorithm ปล่อยให้ AI Coding ตัดสินใจตอน implement จริง ไม่ specify ตายตัวในนี้
- UI/ตัวอย่างใน mockup ไม่เปลี่ยน (แถวหน้าตาเหมือนเดิมไม่ว่าจะมาจาก follower หรือ following) เปลี่ยนแค่แหล่งข้อมูลเบื้องหลัง
