# Product Task — WYN-128

Status: active — Design เสร็จแล้ว (mockup Founder อนุมัติ 2026-09-07: "แยกตามห้อง เหมือนดิส"), รอ Founder รับทราบแนวทาง schema ก่อนส่ง Coding (ดู Recommendation)
Owner: AI Product Manager → AI Design (เสร็จ) → รอ Founder รับทราบสถาปัตยกรรม → AI Coding

Feature: Club Group Chat — ห้องแชทสด (real-time) **ต่อห้อง (channel)** แยกจากฟีดโพสต์ของห้องนั้น

Goal: เติมแกนที่สำคัญที่สุดของความเป็น Discord ให้ WYN Club — การพูดคุยสดต่อเนื่อง ไม่ใช่แค่โพสต์แล้วรอคนมา like/comment ทีหลัง ดู `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` ข้อ 2 (ระบุไว้ตั้งแต่ founder brief ต้นฉบับ WYN-014 แล้วว่า "Club Chat" เป็นทิศทางที่ตั้งใจต่อยอด)

Target User: สมาชิกที่ approved แล้วของ Club ทุกคน (สิทธิ์เดียวกับการเห็นโพสต์ใน Club)

Problem: WYN มีระบบแชทอยู่แล้ว (WYN-031/032/033) แต่เป็น**การสนทนา 1-ต่อ-1 เท่านั้น** — ไม่มีทางให้สมาชิก Club หลายคนคุยกันสดๆ พร้อมกันในที่เดียวเลย ทำให้ Club รู้สึกเป็น "บอร์ดประกาศ" มากกว่า "ห้องพูดคุยที่มีชีวิต" แบบ Discord

Requirements:
1. **Founder ยืนยันแล้ว (2026-09-07, "แยกตามห้อง เหมือนดิส")**: แชทผูกกับแต่ละ **channel** (WYN-127) ไม่ใช่ผูกกับ Club ทั้งก้อน — ทุก channel ที่มีอยู่มีห้องแชทของตัวเอง สลับ channel = สลับห้องแชทไปด้วยในตัว (ใช้แถบ channel switcher เดียวกับ WYN-127 เป๊ะ ไม่ต้องออกแบบ navigation ใหม่แยก) — สมาชิก approved ของ Club เห็นและพิมพ์ในทุกห้องแชทของทุก channel ได้ (สิทธิ์เดียวกับสิทธิ์เข้าดู Club)
2. ข้อความในห้องแชทเรียงตามเวลาจริง อัปเดตแบบ real-time (เห็นข้อความใหม่ทันทีไม่ต้อง refresh) — ใช้ Supabase Realtime เหมือนที่ 1-ต่อ-1 chat ใช้อยู่แล้ว
3. รองรับ: ข้อความตัวอักษร, รูปภาพ (ระดับเดียวกับที่ 1-ต่อ-1 chat รองรับวันนี้), reply-quote ข้อความก่อนหน้า
4. Owner/Admin/Moderator ลบข้อความของคนอื่นได้ (moderation — สอดคล้องกับสิทธิ์ที่มีอยู่แล้วสำหรับลบโพสต์)
5. คนที่ถูก ban/remove ออกจาก Club ต้องไม่เห็น/พิมพ์ในห้องแชทได้อีกทันที
6. Badge แจ้งเตือนข้อความใหม่ที่ยังไม่อ่าน (unread) บนปุ่ม/แท็บเข้าห้องแชทของ Club — เหมือน unread badge ที่ระบบแชท 1-ต่อ-1 มีอยู่แล้ว

Acceptance Criteria:
- สมาชิก 2 คนขึ้นไปที่ approved ใน Club เดียวกัน พิมพ์ข้อความในห้องแชทเห็นกันแบบ real-time โดยไม่ต้อง refresh
- คนที่ยังไม่ join หรือถูก ban ออกจาก Club เข้าห้องแชทไม่ได้เลย (ทั้ง read และ write)
- Owner ลบข้อความของสมาชิกคนอื่นได้ สมาชิกทั่วไปลบได้แค่ข้อความตัวเอง
- ออกจาก Club แล้วกลับเข้ามาใหม่ (ถ้า Public) ยังอ่านประวัติแชทเก่าได้ (ไม่ลบประวัติตอนออก)
- unread badge อัปเดตถูกต้องเมื่อมีข้อความใหม่ระหว่างที่ไม่ได้เปิดหน้าแชทอยู่

Dependencies: **ต้อง WYN-127 (Club Channels) merge/deploy ก่อนเสมอ** — เพราะแชทผูกกับ `channel_id` ของ WYN-127 โดยตรง ไม่มี channel ก็ไม่มีที่ให้แชทผูกกับ — schema แชทเดิม (`conversations`/`messages` จาก WYN-031) ออกแบบไว้สำหรับคู่สนทนา 2 คนเท่านั้น (`conversation_participants` แบบ 1-1) ดู Recommendation ด้านล่างสำหรับแนวทาง schema ที่ AI Design เลือก

Priority: **สูง (คุณค่าที่สุด) แต่ทำทีหลัง WYN-127/WYN-129** — เป็นงานใหญ่ที่สุดในสามอัน ต้องแตะ schema แชทเดิมที่ sensitive (ระบบ 1-ต่อ-1 ที่ใช้งานจริงอยู่แล้วต้องไม่พัง) ควรพิสูจน์ demand จาก Channels ก่อนลงทุนหนัก

Risks:
- **ความเสี่ยงสูงสุด**: ถ้าออกแบบ schema ผิดพลาดจนกระทบระบบแชท 1-ต่อ-1 ที่มีอยู่แล้วและมีผู้ใช้จริงใช้งานอยู่ (regression ต่อฟีเจอร์ที่ทำงานดีอยู่แล้ว) — Design ต้องเลือกแนวทางที่แยกความเสี่ยงจากระบบเดิมให้ชัดเจน (แนะนำเบื้องต้น: ตารางใหม่แยกต่างหากสำหรับ Club chat แทนที่จะ modify ตารางเดิม จนกว่า Design จะยืนยันแนวทางที่ปลอดภัยกว่า)
- Club ขนาดใหญ่ (สมาชิกหลักพันคน) ในห้องแชทเดียวอาจข้อความไหลเร็วเกินจะติดตามได้ — ต้องพิจารณา pagination/loading เก่า-ใหม่ตั้งแต่ Design ไม่ใช่แก้ทีหลัง
- Moderation (WYN-026/027/028/029) ต้องขยายมาครอบคลุมข้อความในห้องแชท Club ด้วย ไม่ใช่แค่โพสต์ — ต้องเช็คกับระบบ report/block ที่มีอยู่แล้วว่าครอบคลุมหรือไม่

Recommendation: **APPROVAL_REQUIRED ก่อนส่ง Coding** — แนวทาง schema ที่ AI Design เลือก (ดูหัวข้อ "AI Design Output") คือสร้างตารางใหม่แยกต่างหากสำหรับ Club chat โดยเฉพาะ (`club_channel_messages` + ใช้ RLS ผูกกับ `club_role()`โดยตรง) **ไม่แตะตาราง `conversations`/`messages`เดิมของ WYN-031 เลยแม้แต่บรรทัดเดียว** เพื่อไม่ให้มีความเสี่ยงต่อระบบแชท 1-ต่อ-1 ที่ใช้งานจริงอยู่แล้ว — เป็นสถาปัตยกรรมใหม่ (ระบบสนทนากลุ่มครั้งแรกของ WYN) ตาม RULES.md ต้องให้ Founder รับทราบแนวทางก่อนเริ่ม Coding แม้ scope การใช้งาน (แยกตามห้อง) จะอนุมัติแล้วก็ตาม

Handoff: รอ Founder รับทราบ/อนุมัติแนวทาง schema ("ตารางใหม่แยกต่างหาก ไม่แตะแชทเดิม") → AI Coding → AI QA & Security (เน้นตรวจว่าไม่มีจุดใดแตะ/เปลี่ยนพฤติกรรม `conversations`/`messages` เดิมเลย, ตรวจ RLS ผูกกับ `club_role()` ถูกต้องตาม channel, ตรวจคนถูก ban เข้าห้องแชทไม่ได้ทันที)

## AI Design Output

Screen: Club Page → Group Chat (เข้าถึงผ่านแถบ channel switcher เดียวกับ WYN-127 — ไม่มีแท็บ "แชท" แยกต่างหากในระดับ Club อีกต่อไป เพราะแชทอยู่ *ภายใน* แต่ละ channel)

Purpose: ให้สมาชิกในแต่ละห้องคุยกันสดๆ ได้ ไม่ใช่แค่โพสต์รอคนมาคอมเมนต์ทีหลัง — mockup เต็ม: https://claude.ai/code/artifact/d08fb9ad-0757-486b-9808-9c65cbe1d9b7 (แท็บ "WYN-128 Group Chat", Founder อนุมัติ 2026-09-07)

User Flow: เปิด Club Page → เลือก channel จากแถบด้านบน (เหมือน WYN-127) → เห็นห้องแชทของ channel นั้นทันที (ไม่ใช่ฟีดโพสต์ — ให้ Design ตัดสินใจว่า Posts กับ Chat ของ channel เดียวกันสลับด้วย toggle ย่อยภายใน หรือแยกเป็นคนละหน้าที่กดเข้าจาก channel — **แนะนำ**: toggle เล็กๆ "โพสต์ | แชท" ใต้แถบ channel เพื่อให้ channel หนึ่งมีทั้งสองแบบในที่เดียว ไม่ต้องสร้าง navigation ชั้นใหม่) → พิมพ์ข้อความ ส่งแบบ real-time

Components: ใช้ widget ชุดเดียวกับ conversation_screen.dart (WYN-031) ทุกจุดที่ไม่เกี่ยวกับ 1-1 โดยเฉพาะ — chat bubble (sent=sapphire, received=surfaceTint), input pill + ปุ่มส่งวงกลม, ต่างจากเดิมแค่ 2 จุด: (1) ชื่อผู้ส่งกำกับเหนือ bubble ที่ไม่ใช่ตัวเอง (จำเป็นเพราะเป็นกลุ่ม) (2) หัวห้องโชว์จำนวนสมาชิกออนไลน์แทนสถานะ "ออนไลน์/ออฟไลน์" ของคู่สนทนาคนเดียว

Interactions: พิมพ์+กดส่ง เหมือน 1-1 chat เป๊ะ, Owner/Admin/Moderator กด "..." บนข้อความคนอื่น → เมนู "ลบข้อความ" (เทียบเท่าสิทธิ์ลบโพสต์ที่มีอยู่แล้ว)

States: ห้องแชทว่าง (ยังไม่มีใครพิมพ์เลย) → empty state ข้อความสั้นๆ เชิญชวนเริ่มคุย, ถูก ban ระหว่างเปิดหน้าแชทอยู่ → เด้งออกจากหน้าทันที (เหมือน pattern ที่ AccountRestrictedScreen ใช้ตรวจ moderation status)

Responsive Behavior: รายการข้อความ scroll ได้ไม่จำกัด (pagination โหลดข้อความเก่าเมื่อเลื่อนขึ้นสุด เหมือน 1-1 chat)

Accessibility: เหมือน conversation_screen.dart เดิมทุกประการ (ผ่าน accessibility review มาแล้วในงานเดิม)

Design Rules: ห้ามสร้าง UI chat ใหม่ตั้งแต่ศูนย์ — reuse component จาก WYN-031 ให้มากที่สุด ต่างเฉพาะจุดที่จำเป็นจริงๆ (ชื่อผู้ส่ง, จำนวนออนไลน์)

**ข้อเสนอสถาปัตยกรรม schema (APPROVAL_REQUIRED)**: สร้างตารางใหม่ `club_channel_messages` (คอลัมน์คล้าย `messages` เดิม: id, channel_id, author_id, content, image_url, reply_to_message_id, created_at) + RLS policy อ่าน/เขียนผ่าน `club_role(channel's club_id, auth.uid()) is not null` โดยตรง — **ไม่แตะ `conversations`/`conversation_participants`/`messages` ของ WYN-031 เลย** เหตุผล: ระบบ 1-1 ออกแบบมาเฉพาะคู่สนทนา 2 คน (unique constraint/index หลายจุดสมมติฐานนี้) การบังคับให้รองรับ N คนจะเสี่ยงกระทบทุกจุดที่อ้างอิง "อีกฝ่าย" (เช่น unread count, online status ของคู่สนทนา) — แยกตารางใหม่ปลอดภัยกว่ามาก แลกกับโค้ด UI ซ้ำกันเล็กน้อยระหว่าง 2 ระบบ ซึ่งยอมรับได้

Handoff: รอ Founder รับทราบข้อเสนอสถาปัตยกรรมข้างต้น (ตารางใหม่แยก ไม่แตะแชทเดิม) แล้วส่งต่อ AI Coding
