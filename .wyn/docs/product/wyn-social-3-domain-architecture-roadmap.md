# WYNOS Social Architecture — 3-Domain Gap Analysis & Roadmap (2026-09-07)

Owner: AI Product Manager
บริบท: Founder ขอนิยามสถาปัตยกรรม Social ของ WYNOS ให้แยกเป็น 3 โดเมนชัดเจน — **HOME FEED** (public social) / **CLUB** (community + group communication) / **PRIVATE CHAT** (private communication) — สื่อสารกันได้ตาม Permission แต่ห้ามข้อมูลปะปนกัน สเปกเต็มที่ Founder ส่งมา: 20 หัวข้อ ครอบคลุม feature เกือบทุกมิติของ social platform ระดับ Discord+Instagram+Messenger

**หมายเหตุสำคัญ**: เอกสารนี้คือ **gap analysis + roadmap** ไม่ใช่ full Product Task ของทุกฟีเจอร์ (สเปกที่ Founder ส่งมามีมากกว่า 100 sub-feature ถ้าเขียน Product Task เต็มรูปแบบทุกอันในครั้งเดียวจะไม่ทันตรวจสอบความถูกต้อง และหลายอันมีอยู่แล้วจริง) — ขั้นตอนถัดไปคือให้ Founder ยืนยันลำดับความสำคัญ (ดูท้ายเอกสาร) แล้ว AI PM จะเขียน Product Task แบบเต็ม (`Feature/Goal/Target User/Problem/Requirements/AC/Dependencies/Priority/Risks/Recommendation/Handoff`) ทีละตัวตามลำดับที่เลือก

## 0. ยืนยันสถาปัตยกรรม 3 โดเมน — ตรงกับของจริงอยู่แล้ว ✅

ตรวจโค้ด/task history จริงแล้ว: WYNOS **แยก 3 โดเมนนี้อยู่แล้วในทางสถาปัตยกรรม** ไม่ได้ปะปนกัน —
- **HOME** = ระบบ "Drop" (post) เดิม, public, feed-based
- **CLUB** = domain แยกต่างหาก (`club_*` tables, `club_role()` เป็น authorization primitive ของตัวเอง)
- **CHAT** = domain แยกต่างหาก (`conversations`/`messages` สำหรับ 1:1, และ `club_channel_messages` ใหม่ล่าสุดที่**ตั้งใจแยกตารางจาก DM เดิมโดยเจตนา**เพื่อไม่ให้กระทบกัน — ดู WYN-128 Recommendation)

Shared infrastructure ที่ใช้ร่วมกันอยู่แล้วตรงตามที่ Founder ต้องการ (ข้อ 19): Auth, Profile, Follow/Block/Mute, Report, Notification, Storage — ไม่มี fork ซ้ำซ้อน

**สรุป**: ข้อกำหนดสถาปัตยกรรมหลัก (ข้อ 19) ที่ Founder ขอ **ทำอยู่แล้วถูกต้องตามหลักการที่ระบุมา** ไม่ต้อง refactor ใหญ่

## 1. เช็คของเก่าก่อนเปิดของใหม่ — สถานะจริงต่อหัวข้อ Founder

Legend: ✅ เสร็จ/deploy แล้ว · 🕓 เสร็จ QA แล้ว รอ Founder deploy จริง · 🆕 ยังไม่มี (ของใหม่จริง) · ❓ ต้อง verify กับโค้ดก่อนฟันธง

### HOME FEED (ข้อ 1)
ระบบ "Drop" เดิมของ WYNOS ครอบคลุมเกือบทั้งหมดแล้ว: Text/Image/Multi-image Post ✅, Edit/Delete ✅, Visibility (Public/Followers) ✅, Mention ✅, Poll ✅ (WYN-035), Like/Comment/Reply/Share/Save ✅, Follow/Unfollow/Block/Mute ✅, Following Feed ✅, Infinite Scroll/Pagination/Pull-to-refresh ✅, Report Post/Comment/User ✅, Content Moderation (Restrict/Suspend/Ban) ✅, Notification (Like/Comment/Reply/Follow/Mention) ✅
ที่ต้อง ❓ verify ก่อนเปิด task ใหม่ (ป้องกันสร้างซ้ำของที่มีอยู่แล้ว): **Draft Post, Repost, Trending/Feed Ranking algorithm, Hide Content/Not Interested** — ยังไม่เจอ task ID ที่ตรงตัวในประวัติ อาจมีบางส่วนทำไปแล้วในชื่ออื่น ต้อง audit โค้ดจริงก่อนตั้ง task ใหม่

### CLUB (ข้อ 2, 3, 6, 9, 16)
Core (สร้าง/Public-Private/Join-Request/Page/Posts/Rules/Discovery) ✅, Role 4 ระดับตายตัว (Owner/Admin/Moderator/Member) ✅, Approve/Remove/Ban ✅, Pinned Post ✅, Club Channels 🕓 (WYN-127, พร้อม deploy), เชิญเพื่อนจาก Followers ✅ (WYN-123/124)
🆕 ของใหม่จริง: **Custom Role** (สร้าง role เอง ตั้งชื่อ/สิทธิ์เอง — ตอนนี้มีแค่ 4 role ตายตัว), **Granular Permission ต่อ role ต่อ channel** (View/Send/Manage แยกละเอียด — ตอนนี้สิทธิ์ผูกกับ role คงที่ 4 ระดับ ไม่ปรับแต่งได้), **Invite Link แบบทั่วไป** (generate/revoke/expiration/max-uses — ของเดิมมีแค่ "เชิญ follower เข้า club" ไม่ใช่ shareable link ที่ปรับ config ได้), **Club Announcement แยกประเภทจาก Post** (ตอนนี้ใช้ Pinned Post แทน ยังไม่มี lifecycle/edit/delete แยกเฉพาะ)

### CLUB CHANNELS + TEXT CHAT (ข้อ 3, 4)
🕓 WYN-127 (Channels) + WYN-128 (Group Chat ต่อ channel, real-time, image, reply-quote, moderation, unread badge) — **เสร็จ QA PASS แล้ว รอ Founder รัน deploy จริง** (ดู section 3 ด้านล่าง — นี่คือ action item ที่ทำได้ทันทีไม่ต้องรอ roadmap ใหม่)
🆕 ยังไม่มีใน WYN-128: Edit Message, GIF/Sticker, Mention Role/Everyone, File attachment, Pin/Search Message ภายในห้องแชท, Message Timestamp/Read Status ระดับข้อความ (ตอนนี้มีแค่ unread badge ระดับห้อง)

### CLUB THREAD (ข้อ 5) — 🆕 ใหม่ทั้งหมด ไม่มีอยู่เลย

### CLUB VOICE / VIDEO (ข้อ 7, 8) — 🆕 ใหม่ทั้งหมด และเป็น **Major Architecture** (WebRTC/SFU infra) — เอกสาร `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` (2026-09-06) เคย**แนะนำเลื่อนออกไปก่อนโดยเจตนา** ด้วยเหตุผลนี้พอดี

### CLUB COMMUNITY FEED (ข้อ 9) — ✅ มีอยู่แล้ว (Club Posts ต่อ channel) ส่วน "แชร์ Content ระหว่าง Club และ Home Feed" (cross-post) ❓ ยังไม่ยืนยันว่ามี — ปัจจุบันมีแค่ Share **เข้า Chat** (WYN-033) ไม่ใช่ cross-post ระหว่าง Home↔Club

### PRIVATE CHAT — 1:1 DM (ข้อ 10) ✅ WYN-031/032/033: Text/Image, Reply (1 ชั้น), Delete (soft), Read/Unread ระดับบทสนทนา, Message Request (Accept/Delete/Block/Report), Share เข้า Chat (Drop/Profile/Club), Realtime
🆕 ของใหม่จริงที่ Founder ขอแต่ยังไม่มีเลย: **Edit Message, GIF/Sticker, Voice Message, File, Link Preview unfurl, Pin Message, Search Messages ในบทสนทนา, Typing Indicator, Online/Offline + Last Seen, "New Message" push notification** (ยอมรับเป็น known gap ไว้ตั้งแต่ WYN-032 แล้ว — ดู task note)

### PRIVATE GROUP CHAT (ข้อ 11) — 🆕 **ใหม่ทั้งหมด ไม่มีอยู่เลย** — เป็นคนละเรื่องกับ Club Group Chat (WYN-128) ตามที่ Founder ระบุชัดว่า "ต้องเป็น Private Conversation ไม่ใช่ Club" — schema แชทเดิม (WYN-031) ออกแบบไว้สำหรับคู่สนทนา 2 คนเท่านั้น การเพิ่ม group ต้องขยาย schema (คล้ายที่ WYN-128 ตัดสินใจแยกตารางใหม่เพื่อไม่กระทบ DM เดิม)

### SEARCH (ข้อ 13) — Club/User/Content search ✅ มีอยู่แล้ว (Discovery WYN-015) — 🆕 **unified search ข้าม 3 โดเมน** (ค้นหา message ใน Chat/Club chat) ยังไม่มี

### NOTIFICATION SYSTEM (ข้อ 14) — ครอบคลุมเกือบหมดแล้วทั้ง Home/Club ✅ — gap ที่ทราบอยู่แล้ว: DM "New Message" notification 🆕, Mute Channel/Mute Chat (ระดับ granular กว่า mute conversation ที่มีอยู่) ❓ ต้อง verify

### MODERATION (ข้อ 15) — Report/Block/Mute/Restrict/Suspend/Ban ✅, Admin Dashboard/Report Center/Audit Log ✅ (WYN-049-054), Official Announcement (admin broadcast, คนละเรื่องกับ Club Announcement) ✅ (WYN-055)
🆕 ของใหม่จริง: **Anti-Flood/Rate Limit, Warning action แยกจาก mute/kick/ban** — เป็น Major Architecture ระดับหนึ่ง (ต้องมี infra จำกัดอัตรา ไม่ใช่แค่ business logic ธรรมดา)

### INVITE SYSTEM (ข้อ 16) — 🆕 ดูหัวข้อ Club ด้านบน (invite link ทั่วไปพร้อม expiration/max-uses)

### WYNOS INTEGRATION / Content Sharing (ข้อ 18) — Share เข้า Chat ✅ (WYN-033) — Cross-post Home↔Club ❓ ยังไม่ยืนยัน

## 2. Major Architecture ที่ต้องขออนุมัติ Founder ก่อนเริ่ม scope เต็ม (ตาม `.wyn/company/RULES.md`)

รายการนี้กระทบ "สถาปัตยกรรมหลัก" ของระบบ (ไม่ใช่แค่ต่อยอด CRUD ธรรมดา) — AI PM **วางแผน/ประเมินได้เลยโดยไม่ต้องขออนุมัติ** แต่ **ต้องขออนุมัติก่อนส่งต่อ AI Design/Coding**:

1. **Voice Chat + Video/Screen Share** (ข้อ 7, 8) — ต้องมี WebRTC/SFU server infra ใหม่ทั้งหมด, ค่า bandwidth ต่อเนื่อง, ทีม/vendor เฉพาะทาง — เอกสารก่อนหน้าแนะนำเลื่อนไว้แล้วด้วยเหตุผลนี้
2. **Custom Role + Granular Permission Engine** (ข้อ 2) — เปลี่ยนจาก authorization model แบบ fixed-4-role (`club_role()`) เป็น dynamic permission system — กระทบ authorization primitive หลักของทั้ง Club domain ทุกจุดที่มีอยู่
3. **Private Group Chat** (ข้อ 11) — ต้องขยาย schema แชทเดิม (คล้ายความเสี่ยงที่ WYN-128 เจอตอนต่อยอด DM เดิม — ต้องเลือกว่าจะ modify `conversations`/`messages` เดิม (เสี่ยงกระทบ DM ที่ใช้งานจริงอยู่) หรือแยกตารางใหม่)
4. **Anti-Flood/Rate Limiting infra** (ข้อ 15) — infra ระดับ request-limiting ไม่ใช่ business logic ธรรมดา

## 3. Action ที่ทำได้ทันที ไม่ต้องรอ roadmap ใหม่นี้

**WYN-127 (Club Channels) + WYN-128 (Club Group Chat) + WYN-129 (Role Badge)** — เขียนเสร็จ, QA PASS, ยืนยันซ้ำโดย AI Deploy & DevOps แล้ว (2026-09-07) — **รอ Founder รัน migration SQL ผ่าน Supabase Dashboard + trigger deploy ตามขั้นตอนที่ `.wyn/logs/deployments/2026-09-07-wyn-127-128-129-club-discord-identity-go-live-package.md`** — นี่คือ 3 หัวข้อจากสเปกวันนี้ (Channel, Text Chat, Role) ที่ **ทำเสร็จรอ deploy อยู่แล้ว** ไม่ต้องรอคิว roadmap ใหม่

## 4. ข้อเสนอลำดับ Phase สำหรับของใหม่จริง (🆕 เท่านั้น)

**Phase A — ต้นทุนต่ำ ต่อยอดของเดิม ไม่แตะ Major Architecture** (ทำได้เลยหลัง Founder เลือก):
- Club Invite Link (expiration/max-uses/revoke)
- Club Announcement แยกประเภทจาก Pinned Post
- DM: Edit Message, Pin Message, Typing Indicator, Online/Last Seen (ใช้ Realtime infra เดิมที่มีอยู่แล้วจาก WYN-031)
- DM: "New Message" push notification (ปิด known gap เดิม)
- Club Chat: Edit Message, Pin Message, Search Message ในห้อง

**Phase B — ขนาดกลาง ของใหม่แต่ scope ชัดเจน**:
- Club Thread (sub-conversation จากข้อความ)
- Unified Search ข้าม 3 โดเมน (message search)
- Home↔Club Cross-post (ถ้า verify แล้วว่ายังไม่มีจริง)

**Phase C — Major Architecture ต้องอนุมัติก่อน scope เต็ม** (ดู section 2):
- Private Group Chat
- Custom Role + Granular Permission
- Voice Chat → Video/Screen Share (ตามลำดับ ถ้าอนุมัติ)
- Anti-Flood/Rate Limiting

## Recommendation

1. **Deploy WYN-127/128/129** — งานเสร็จรอ Founder อยู่แล้ว **Founder เลือก "รอก่อน" แล้ว (2026-09-07)** — ยังไม่ deploy จนกว่าจะเห็นภาพรวม roadmap ก่อน
2. Founder ยืนยัน priority ของ Phase A/B/C — **เขียน Product Task เต็มของ Phase A ครบทุกตัวแล้ว** (WYN-136 ถึง WYN-135, ดูตารางด้านล่าง) ตามที่ Founder ขอดูก่อนตัดสินใจ
3. รายการ Phase C ต้องขออนุมัติ Founder อย่างเป็นทางการ (`APPROVAL_REQUIRED`) ก่อนส่งต่อ AI Design แม้ Founder จะเลือกให้เริ่ม scope ก็ตาม

## Phase A — Product Task เต็มพร้อมแล้ว (`.wyn/tasks/backlog/`)

| Task | Feature | Priority | หมายเหตุ |
|---|---|---|---|
| WYN-134 | DM New Message Notification | **P1** | ปิด known gap จาก WYN-032 โดยตรง กระทบ retention — แนะนำทำก่อน |
| WYN-136 | Club Invite Link (expire/max-uses/revoke) | P2 | ต้องยืนยัน Private-Club-join-semantics ก่อน Design |
| WYN-138 | DM Edit + Pin Message | P2 | ต่อยอด schema เดิมตรงๆ ความเสี่ยงต่ำ |
| WYN-139 | DM Typing + Online/Last Seen | P2 | ต้องมี privacy opt-out ในรอบแรกเลย ไม่ใช่ fast-follow |
| WYN-135 | Club Chat Edit + Pin + Search | P2 | **Blocked จนกว่า WYN-128 จะ deploy จริง** |
| WYN-137 | Club Announcement (แยกจาก Pinned Post) | **P3** | คุณค่าเพิ่มแคบ — แนะนำพิจารณาทางเลือกที่เบากว่า (filter บน Pinned Post เดิม) ก่อนสร้างของใหม่ |

## Handoff

รอ Founder อ่าน Product Task ทั้ง 6 ตัว (`.wyn/tasks/backlog/WYN-136` ถึง `WYN-135`) แล้วยืนยันลำดับ/ตัดตัวที่ไม่ต้องการออก → AI PM ส่งต่อ AI Design ตามลำดับที่ยืนยัน (WYN-135 ต้องรอ Founder สั่ง deploy WYN-128 ก่อนแยกต่างหาก)
