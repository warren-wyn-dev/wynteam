# Product Task — WYN-127

Status: **QA รอบ 2: PASS (2026-09-07) — พร้อม Deploy** — ยืนยัน staged-rollout gate ปิดช่องจริงด้วย live PostgreSQL 16.13 + `flutter test` (1377/1377) รวม regression test ทั้ง 2 state (`true`/`false`) ผ่านหมด พบเพิ่มเติม (ไม่บล็อก): WYN-127 เปลี่ยน `club_posts.channel_id` เป็น `NOT NULL` + เปลี่ยน signature ของ `create_poll_club_post()` ทำให้ test script เก่า 6 ไฟล์ (`wyn_021`/`wyn_044`/`wyn_045`/`wyn_047`/`wyn_115`/`wyn_117`) ค้าง fixture เดิม รันไม่ผ่าน — ตรวจสอบอิสระแล้วว่าเป็น**แค่ test script ค้างสเปกเดิม ไม่ใช่ regression จริง** (โค้ด Dart จริงส่ง `channel_id`/`p_channel_id` ถูกต้องทุกจุดอยู่แล้ว, เรียก RPC ตรงแบบเดียวกับแอปจริงบน live Postgres สำเร็จ) รายละเอียด: `.wyn/tasks/bugs/WYN-127-stale-test-fixtures-channel-id-not-null.md` (priority ต่ำ ไม่ block deploy)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ, FAIL) → AI Debug Engineer (เสร็จ) → AI QA & Security (เสร็จ, PASS) → AI Deploy & DevOps (ถัดไป)

Feature: Club Channels — แบ่งการพูดคุยภายใน Club เป็นหลายห้อง แทนที่ฟีดเดียวรวมทุกเรื่อง

Goal: ทำให้ Club รู้สึกเหมือน Discord server จริง (มีหลาย # channel แยกหัวข้อ) แทนที่การโยนทุกโพสต์ (คุยเล่น, ประกาศ, ถามตอบ) ลงฟีดเดียวปนกันหมดแบบ Facebook Group — ดู `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` ข้อ 1

Target User: สมาชิกและ Owner/Admin ของทุก Club ที่มีเนื้อหาหลากหลายพอจะแยกหมวดได้ (Club เล็กมากอาจใช้แค่ #general ก็พอ ไม่บังคับสร้างหลาย channel)

Problem: ตอนนี้ `club_posts` ทุกโพสต์อยู่ใน feed เดียวของ Club ไม่ว่าจะเป็นเรื่องประกาศสำคัญ คุยเล่นทั่วไป หรือถามตอบเฉพาะทาง — สมาชิกที่สนใจแค่ประกาศต้องไถผ่านโพสต์คุยเล่นทั้งหมดก่อนเจอ ทำให้ Club ไม่มีความรู้สึก "หลายห้อง" แบบ Discord เลย

Requirements:
1. Owner/Admin สร้าง/แก้ไข/ลบ channel ภายใน Club ได้ (ชื่อ channel, ไอคอน/emoji ประจำ channel ไม่บังคับ) — Club ใหม่ทุกอันมี channel default ชื่อ "ทั่วไป" (#general) ให้อัตโนมัติ ไม่ต้องสร้างเอง
2. โพสต์ใหม่ทุกโพสต์ต้องเลือก channel ที่จะลงเสมอ (default = channel ที่กำลังเปิดดูอยู่ ถ้าเข้ามาจาก channel นั้น)
3. หน้า Posts tab ของ Club แสดงรายการ channel เป็นแถบ/dropdown ให้สลับดู แต่ละ channel มีฟีดของตัวเอง ไม่ปนกัน
4. Pinned Post (ที่มีอยู่แล้ว) ผูกกับ channel ที่มันอยู่ ไม่ใช่ pin ข้าม channel
5. **ไม่จำกัดจำนวน channel ต่อ Club** (Founder ยืนยัน 2026-09-07 — ไม่ต้องมี cap)
6. ลบ channel → **ลบโพสต์ในห้องนั้นทิ้งไปพร้อมกันทันที** ไม่ย้ายไป #ทั่วไป (Founder เลือกเอง "ประหยัดพื้นที่") — ต้องมี confirm dialog ชัดเจนก่อนเสมอว่าโพสต์จะหายไปถาวร

Acceptance Criteria:
- สร้าง Club ใหม่ → มี channel "#ทั่วไป" อัตโนมัติ โพสต์แรกลงในนั้นได้ทันทีไม่ต้องตั้งค่าอะไรเพิ่ม
- Owner สร้าง channel ใหม่ (เช่น "#ประกาศ") → สมาชิกเห็น channel ใหม่ในรายการ สลับไปดูฟีดที่แยกจาก #ทั่วไปได้จริง
- โพสต์ที่สร้างใน channel A ไม่ปรากฏเมื่อเปิดดู channel B
- สมาชิกทั่วไป (ไม่ใช่ Owner/Admin) มองเห็นรายการ channel และสลับดูได้ แต่สร้าง/ลบ channel ไม่ได้
- ลบ channel ที่มีโพสต์ → มี dialog ยืนยันชัดเจนก่อนเสมอ ไม่ลบเงียบๆ

Dependencies: ต่อยอดตาราง `club_posts` เดิม (WYN-014) — ไม่ใช่ระบบใหม่ทั้งหมด แค่เพิ่มมิติ channel เข้าไป ไม่กระทบ Posts/Events/Insights tab ที่มีอยู่แล้ว (Events/Insights ยังคงเป็นข้อมูลระดับ Club ไม่ใช่ระดับ channel)

Priority: **สูง** — ต้นทุนต่ำ (ต่อยอดของเดิม ไม่ใช่ระบบใหม่) แต่แก้ปัญหา "ไม่เหมือน Discord" ที่คนสังเกตเห็นเร็วที่สุด ควรทำก่อน WYN-128 (Club Group Chat) เพื่อพิสูจน์ demand ก่อนลงทุนหนักในแชทสด

Risks:
- Club ที่มีสมาชิกน้อย/โพสต์น้อยอาจรู้สึกว่าแยก channel เป็นภาระเกินจำเป็น (over-engineering สำหรับ Club เล็ก) — บรรเทาด้วย default channel เดียวที่ใช้งานได้ปกติทันทีไม่ต้องตั้งค่าเพิ่ม ใครไม่อยากแยกก็ไม่ต้องสร้าง channel เพิ่มเลย
- ต้อง migrate โพสต์เก่าที่มีอยู่แล้วในทุก Club ปัจจุบันเข้า channel default โดยไม่ทำโพสต์หายหรือเปลี่ยนสิทธิ์การมองเห็น — Coding ต้องระวังเรื่อง data migration เป็นพิเศษ (ไม่ใช่ fresh schema ล้วนๆ เหมือนงานก่อนๆ)

Recommendation: Design เสร็จแล้ว ดูหัวข้อ "AI Design Output" ด้านล่าง

Handoff: ส่งต่อ AI Coding → AI QA & Security (ตรวจ migration ไม่ทำโพสต์เก่าหาย, ตรวจสิทธิ์สร้าง/ลบ channel เฉพาะ Owner/Admin, ตรวจ pinned post ผูก channel ถูกต้อง, ตรวจลบ channel ลบโพสต์จริงไม่ทิ้งขยะ orphan record)

## QA Output (2026-09-07) — FAIL

ทดสอบจริงด้วย PostgreSQL 16.13 local (โหลด `schema.sql` เต็ม + slice ก่อน WYN-127 section เพื่อทดสอบ migration กับข้อมูลเก่าจริง, ใช้ harness แบบเดียวกับ `supabase/tests/wyn_115_club_poll_test.sh` — `set role authenticated` + JWT claim GUC): **ทุก priority-focus item ของ WYN-127 เองผ่านหมด**:
- Migration backfill: โพสต์เก่าทุกโพสต์ (รวมโพสต์ที่ pin ไว้) ได้ `channel_id` ครบ ไม่มีค้าง null, Club เก่าที่ไม่มีโพสต์เลยก็ได้ channel default ด้วย, `channel_id` ถูก constrain `NOT NULL` สำเร็จ
- Owner/Admin เท่านั้นสร้าง/แก้ไข/ลบ channel ได้ (Moderator/Member/non-member ถูกบล็อกทั้ง RLS insert/update/delete) — ทดสอบจริงทั้ง 2 role ที่ควรถูกปฏิเสธ
- ชื่อ channel ซ้ำ (case-insensitive) ถูกปฏิเสธจริง
- โพสต์ข้าม club_id/channel_id ผิดคู่กันถูก FK ปฏิเสธจริง
- ลบ channel cascade ลบโพสต์ในห้องนั้นจริง ไม่ทิ้ง orphan, โพสต์ห้องอื่นไม่กระทบ
- Pin สถานะไม่รั่วข้าม channel
- ไม่มี cap จำนวน channel ที่ไหนเลย (ตรงตาม Founder decision)

**เหตุผลที่ FAIL**: พบว่าฟีเจอร์นี้ (ร่วมกับ WYN-128/WYN-129 บน branch เดียวกัน) ไม่ได้ gate ด้วย `DeveloperAccessService.isDeveloperAccount()` เลย ขัดกับนโยบายบังคับใน `.wyn/company/WORKFLOW.md` ("Staged Rollout เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่ทุกตัว", มีผลตั้งแต่ 2026-09-06) — deploy ตอนนี้จะทำให้ผู้ใช้ทุกคนเห็นแถบ channel ทันที ไม่ใช่แค่บัญชีนักพัฒนา รายละเอียด/reproduction/fix ที่แนะนำ: `.wyn/tasks/bugs/WYN-127-128-129-missing-staged-rollout-gate.md`

Final Status: **FAIL** (ตัวฟีเจอร์เองใช้งานได้ปลอดภัยตามที่ทดสอบ — บล็อกเฉพาะเรื่อง staged-rollout gate ที่ต้องเพิ่มก่อน deploy)

## QA Output รอบ 2 (2026-09-07) — PASS

ตรวจซ้ำหลัง AI Debug Engineer แก้ (commit `1bb6fa4`) ด้วยวิธีเดิม (live PostgreSQL 16.13 + `flutter analyze`/`flutter test`):
- อ่าน diff จริง + รัน `flutter test test/club_posts_tab_test.dart test/club_members_tab_test.dart test/club_page_test.dart` ยืนยัน staged-rollout gate ทำงานถูกต้องทั้ง 2 state: `false` = เหมือน pre-WYN-127/128/129 ทุกประการ (ไม่มีแถบ channel/toggle แชท/badge/ชื่อ channel รั่วใน composer chip), `true` = เห็นของใหม่ครบตามเดิม (regression test ยืนยันทั้งคู่)
- `flutter analyze`: no issues. `flutter test`: 1377/1377 ผ่านทั้งหมด (ตรงกับที่ Debug รายงาน)

**พบเพิ่มเติมระหว่างตรวจซ้ำ (ไม่บล็อก deploy)**: รัน `supabase/tests/*.sh` ทั้ง 43 ไฟล์ตามที่ผู้ประสานงานร้องขอ พบ 8 ไฟล์ fail — สืบสวนอิสระแล้วสรุปได้ดังนี้:
- **6 ไฟล์ (`wyn_021`/`wyn_044`/`wyn_045`/`wyn_047`/`wyn_115`/`wyn_117`)**: fail เพราะ fixture ของ test เองยังไม่อัปเดตตาม schema ใหม่ของ WYN-127 (`club_posts.channel_id` เป็น `NOT NULL` แล้ว, `create_poll_club_post()` มี parameter `p_channel_id` เพิ่มแล้ว) — ยืนยันว่า**ไม่ใช่ regression จริงต่อแอป**: อ่านโค้ด Dart จริง (`ClubPostRepository.createPost`/`createPollClubPost`) ส่ง `channel_id`/`p_channel_id` ถูกต้องครบทุกจุดอยู่แล้ว, `create_club_post_screen_test.dart` (อยู่ใน 1377 ที่ผ่าน) ยืนยัน call shape ถูกต้องอยู่แล้วตั้งแต่รอบ Coding เดิม, และทดสอบเรียก `create_poll_club_post()` ตรงแบบเดียวกับที่แอปเรียกจริง (named params ผ่าน live Postgres) สำเร็จ สร้างโพสต์+poll ได้ถูกต้อง — สรุปว่าเป็นแค่ test script ค้างสเปกเดิม รายละเอียด: `.wyn/tasks/bugs/WYN-127-stale-test-fixtures-channel-id-not-null.md` (priority ต่ำ ไม่ block)
- **1 ไฟล์ (`wyn_038_view_counting_test.sh`)**: ตรวจสอบแล้วว่า fail เหมือนกันทุกประการ (8 checks เดิม) แม้ย้อนกลับไปทดสอบกับ schema.sql ของ commit `5498928` (จุดก่อนเริ่มงาน WYN-127/128/129 เลย) — ยืนยันว่าเป็นปัญหาเดิมที่มีอยู่ก่อนแล้ว ไม่เกี่ยวกับ branch นี้เลยแม้แต่น้อย ต้องแยกไปสืบสวนเป็นเรื่องอื่นต่างหาก ไม่เกี่ยวกับ WYN-127/128/129

Final Status: **PASS — พร้อม Deploy**

## AI Design Output

Screen: Club Page → Posts tab (เพิ่มแถบ channel switcher เหนือฟีด) + Club Page → Group Chat tab ใหม่ (ดู WYN-128, ใช้แถบ channel switcher หน้าตาเดียวกัน)

Purpose: ให้สมาชิกเลือกดูเฉพาะห้องที่สนใจ แทนที่ฟีดเดียวปนกันหมด — mockup เต็ม: https://claude.ai/code/artifact/d08fb9ad-0757-486b-9808-9c65cbe1d9b7 (แท็บ "WYN-127 Channels", Founder อนุมัติ 2026-09-07)

User Flow: เปิด Club Page → แถบ channel อยู่เหนือฟีด (เริ่มที่ #ทั่วไป เสมอ) → แตะห้องอื่นเพื่อสลับฟีด → กด "+ ห้องใหม่" (Owner/Admin เท่านั้น) เปิด dialog ตั้งชื่อห้อง → สร้างโพสต์ใหม่จากภายในห้องใด ห้องนั้นเป็น default channel ของโพสต์

Components:
- Channel chip row: แถบเลื่อนแนวนอน (`ListView` horizontal), chip ทรงเม็ดยา (`radiusFull`) — ห้องที่เลือกอยู่: พื้นหลัง sapphire ตัวอักษรขาว, ห้องอื่น: ขอบ hairline ตัวอักษร graphite
- ปุ่ม "+ ห้องใหม่" เป็น chip ท้ายแถวเสมอ ขอบเส้นประ สี mutedNeutral, มองเห็นได้ทุกคนแต่กดได้เฉพาะ Owner/Admin (สมาชิกทั่วไปกดแล้วไม่มีอะไรเกิดขึ้น หรือซ่อนไปเลย — ให้ Coding เลือกซ่อนไปเลยง่ายกว่า สอดคล้องกับ pattern ของปุ่มจัดการอื่นในระบบ)
- Dialog สร้าง/แก้ไข channel: ช่องกรอกชื่อ (จำกัดความยาว, กันชื่อว่าง/ซ้ำ), ปุ่มยืนยัน/ยกเลิกมาตรฐาน
- Dialog ลบ channel: ข้อความเตือนชัดเจนว่าโพสต์ในห้องนี้จะหายไปถาวร (ไม่ใช่ dialog ยืนยันทั่วไปแบบเบาๆ) ปุ่มลบใช้สี error

Interactions: แตะ chip → สลับฟีดทันที (ไม่ reload ทั้งหน้า), กด "+ ห้องใหม่" → bottom sheet/dialog ตั้งชื่อ, long-press หรือปุ่ม "..." บน chip (Owner/Admin) → แก้ไขชื่อ/ลบห้อง

States: ห้องว่างไม่มีโพสต์ → empty state เดียวกับที่ Posts tab ใช้อยู่แล้ว (ไม่ต้องออกแบบใหม่), กำลังลบห้อง → loading state บน dialog, ห้องเดียว (#ทั่วไป อย่างเดียว ยังไม่สร้างเพิ่ม) → แถบ channel ยังโชว์อยู่ (ไม่ซ่อนทั้งแถบ) เพื่อให้เห็นว่ากดสร้างห้องใหม่ได้ตรงไหน

Responsive Behavior: แถบ channel เลื่อนแนวนอนได้ไม่จำกัดจำนวน (ตามที่ Founder ยืนยันไม่จำกัด) ไม่ wrap หลายบรรทัด

Accessibility: แต่ละ chip เป็น tap target ขั้นต่ำ 44px ตาม `WynSpacing.touchTargetMin`, ห้องที่เลือกอยู่ต้องสื่อสารได้ทั้งสี+ตัวหนา (ไม่ใช่สีอย่างเดียว) กันปัญหา color-blind

Design Rules: ห้ามใช้สีอื่นนอกจาก sapphire เป็น active state (ตาม design system เดิม), ห้ามเปลี่ยน layout ของการ์ดโพสต์เดิมเลย (แค่กรองตาม channel เฉยๆ)

Handoff: AI Coding (schema: เพิ่มตาราง `club_channels` + คอลัมน์ `channel_id` บน `club_posts`, backfill ทุกโพสต์เดิมเข้า channel default "#ทั่วไป" ที่สร้างให้ทุก Club ที่มีอยู่แล้วอัตโนมัติ) → AI QA & Security

## Coding Notes (2026-09-07)

- Migration SQL: `supabase/migrations_wyn127_club_channels.sql` (Founder ต้องรันผ่าน Supabase Dashboard เอง — ยังไม่ได้ apply) + `supabase/schema.sql` อัปเดตให้ตรงกัน (โหลดลง DB เปล่าได้ ตรวจแล้วด้วย `python3 supabase/check_schema_ordering.py` → OK)
- `create_poll_club_post()` (WYN-115) ต้องแก้เพิ่ม `p_channel_id` param ด้วย เพราะ `channel_id` เป็น NOT NULL แล้ว — overload เก่าถูก `drop function` ทิ้งตาม SCHEMA-003 lesson
- Dart: `ClubChannel` model, `ClubRepository.fetchChannels/createChannel/renameChannel/deleteChannel`, `ClubChannelSwitcher` widget (chip row + create/edit/delete dialogs), `ClubPostsTab`/`CreateClubPostScreen` scoped to `channelId`
- Deviation จาก spec: ไม่ได้ทำ emoji/icon ต่อ channel (Requirement 1 บอกว่า "ไม่บังคับ" แต่ AI Design Output's Components section ไม่ได้ระบุ UI สำหรับมันเลย — ตัดสินใจตาม Design ที่ finalize แล้ว ไม่ใช่ Requirement ที่ยังไม่ได้ design), และปุ่ม "+ ห้องใหม่" ใช้ solid border สี mutedNeutral แทน dashed border (ไม่มี dashed-border primitive ในระบบและไม่อยากเพิ่ม dependency ใหม่)
- `flutter analyze`: no issues. `flutter test`: 1347/1347 ผ่านทั้งหมด (รวม test ใหม่สำหรับ channel switching/create channel)
