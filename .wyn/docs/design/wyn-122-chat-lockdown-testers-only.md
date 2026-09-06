# Design — WYN-122 (Chat Lockdown: เหลือเฉพาะ @warren ↔ @wynos_online)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-122-chat-lockdown-testers-only.md` และ design เดิมของฟีเจอร์แชท `.wyn/docs/design/wyn-031-chat-1to1.md` (Screen 1–8) — อ่านทั้งสองก่อนเริ่ม
> Design system: ใช้ token/component ที่มีอยู่แล้วทั้งหมด **ไม่มีการคิดทิศทาง visual ใหม่** — งานนี้คือการเพิ่ม "state" ใหม่หนึ่งอันเข้าไปใน 3 หน้าจอที่มีอยู่แล้วของฟีเจอร์แชท ไม่ใช่หน้าจอใหม่

## สรุปการตัดสินใจหลัก

1. **Reuse `EmptyStateBlock`** (`core/widgets/empty_state_block.dart`) สำหรับ full-screen replacement — widget เดียวกับที่ `ChatInboxScreen`'s "ยังไม่มีข้อความ" ใช้อยู่แล้ว (icon-in-tint-circle + title + subtitle) ไม่สร้าง component ใหม่
2. **Icon: `Icons.lock_clock_outlined`** — icon เดียวกับที่ `RestrictionBanner` ใช้สื่อ "จำกัดชั่วคราว" อยู่แล้ว (WYN-029/030) เลือกอันนี้แทน `Icons.block` โดยเจตนา เพื่อให้ผู้ใช้อ่านออกทันทีว่านี่คือสถานะ**ชั่วคราว** ไม่ใช่ถูกแบน/บล็อกถาวรแบบเดียวกับที่เจอตอนถูกระงับบัญชี — ต่อเนื่องภาษาสายตาเดิมของแอป ไม่ใช่ของใหม่
3. **State "Locked" มีความสำคัญสูงสุด (สูงกว่า Loading/Error/Empty/Blocked/Restricted ทั้งหมด)** ในทั้ง 3 หน้าจอของฟีเจอร์แชท — เช็คก่อนเสมอ ก่อนจะพยายามโหลด/แสดงเนื้อหาจริงใดๆ
4. **Chat entry points ไม่แตะเลย** (ตามที่ Founder ยืนยัน) — ไอคอนแชทบน Home (Screen 1) และปุ่ม "ส่งข้อความ" บนโปรไฟล์คนอื่น (Screen 4) ยังแสดง/กดได้ปกติทุกประการ ไม่มี badge/disabled state ใหม่ใดๆ เพิ่ม
5. **แยก 2 รูปแบบการแจ้งตาม pattern ที่มีอยู่แล้วในแอป**: หน้าจอที่เป็น "มุมมองต่อเนื่อง" (Inbox/Conversation/New Message) ใช้ full-screen `EmptyStateBlock` (มิเรอร์ empty-state pattern เดิม) ส่วน "การกระทำครั้งเดียวที่ถูกปฏิเสธ" (กดปุ่ม "ส่งข้อความ" จากโปรไฟล์แล้วสร้างบทสนทนาใหม่ไม่ได้) ใช้ SnackBar (มิเรอร์ pattern เดียวกับ WYN-121's delete-failure SnackBar ที่เพิ่งทำไปในเซสชันนี้) — ไม่ใช้ dialog ใหม่ที่ไม่มีที่มา

---

## Screen A — Chat Inbox (`ChatInboxScreen`) — เพิ่ม State ใหม่

**Purpose**: ผู้ใช้ที่ไม่อยู่ใน allowlist เปิด Chat Inbox แล้วต้องไม่เห็นบทสนทนาเก่าของตัวเองเลย (ตามที่ Founder ยืนยัน "ซ่อนทั้งหมดระหว่างปิดระบบ") พร้อมเข้าใจทันทีว่าทำไม

**User Flow**: แตะไอคอนแชท (Screen 1 เดิม ไม่เปลี่ยน) → `ChatInboxScreen` เช็คสถานะ lockdown ของผู้ใช้ปัจจุบันก่อนสิ่งอื่นใด → ถ้าถูก lock แสดง State ใหม่ทันที (ไม่พยายามโหลดรายการบทสนทนาเลย) → ถ้าไม่ถูก lock (คือ @warren/@wynos_online) ทำงานตามปกติทุกประการเหมือน `wyn-031-chat-1to1.md` Screen 2 เดิมไม่มีการเปลี่ยนแปลง

**Components**: `EmptyStateBlock` (reuse ตรงๆ)
```
icon: Icons.lock_clock_outlined
title: "ระบบแชทปิดปรับปรุงชั่วคราว"
subtitle: "จะเปิดให้ใช้งานได้เร็ว ๆ นี้"
```

**States** (ลำดับความสำคัญจากบนลงล่าง — เช็คตามลำดับนี้เป๊ะ):
1. **Locked** (ใหม่) — ผู้ใช้ไม่อยู่ใน allowlist → `EmptyStateBlock` ข้างบน แทนที่เนื้อหาทั้งหมด (รวม tab "ทั้งหมด"/"ยังไม่อ่าน" เดิม — ซ่อน tab bar ไปด้วยเพราะไม่มีอะไรให้กรอง)
2. Loading / Error+Retry / Empty / List+pagination — เหมือนเดิมทุกประการ (`wyn-031-chat-1to1.md` Screen 2) ใช้เฉพาะเมื่อผ่านเช็ค Locked แล้วว่าไม่ถูกล็อก

**Design Rules**: อย่าให้ state "Locked" ปนกับ state "Empty" ("ยังไม่มีข้อความ") เด็ดขาด แม้หน้าตาจะคล้ายกัน (ใช้ widget เดียวกัน) — copy ต้องต่างกันชัดเจนเพื่อไม่ให้ผู้ใช้ทั่วไปที่เคยมีบทสนทนาเก่าสับสนคิดว่าข้อความหายไปถาวร (Locked บอกชัดว่า "ปิดปรับปรุงชั่วคราว" ไม่ใช่ "ไม่มี")

**Accessibility**: เหมือน `EmptyStateBlock`'s การใช้งานเดิมทุกที่ในแอป — icon เป็น decorative (ไม่ต้องมี semantic label แยก) ข้อความ title+subtitle อ่านได้ปกติผ่าน screen reader อยู่แล้วโดยไม่ต้องเพิ่มอะไร

---

## Screen B — Conversation Screen (`ConversationScreen`) — เพิ่ม State ใหม่ (สำคัญที่สุด)

**Purpose**: ครอบคลุมทั้ง 2 ทาง: (1) ผู้ใช้ทั่วไปพยายามเปิดบทสนทนาเก่าที่มีอยู่แล้ว (ต้องซ่อนประวัติข้อความทั้งหมด ไม่ใช่แค่ปิดปุ่มส่ง) (2) ผู้ใช้ทั่วไปเพิ่งกด "ส่งข้อความ" จากโปรไฟล์คนอื่นแล้วเปิดมาที่หน้านี้

**User Flow**: เปิดจาก Chat Inbox (ผ่านได้เฉพาะกรณี @warren/@wynos_online เพราะ Inbox เองบล็อกไปแล้วที่ Screen A) หรือเปิดตรงจากปุ่ม "ส่งข้อความ" (Screen 4 เดิม) หรือเปิดจาก Notification/Push เกี่ยวกับข้อความเก่า → เช็คสถานะ lockdown ของ**คู่สนทนาทั้งสองฝ่าย**ก่อนโหลดข้อความ/แสดง composer ใดๆ → ถ้าคู่นี้ไม่ผ่าน (ฝ่ายใดฝ่ายหนึ่งไม่อยู่ใน allowlist) แสดง State ใหม่แทนเนื้อหาทั้งหมด

**Components**: `EmptyStateBlock` เดียวกันเป๊ะกับ Screen A (icon/title/subtitle เหมือนกันทุกตัวอักษร — ผู้ใช้ต้องเห็น copy เดียวกันไม่ว่าจะเจอ lockdown จากทางไหน) แทนที่ **ทั้ง message list และ composer area** — ต่างจาก state "Blocked"/"Restricted" เดิม (`wyn-031-chat-1to1.md` Screen 3) ที่แค่ซ่อน composer แต่ยังเห็นประวัติข้อความอยู่ — เพราะ Founder ยืนยันชัดว่าต้อง**ซ่อนประวัติเก่าด้วย** ไม่ใช่แค่ปิดการส่งใหม่

**Interactions**: ไม่มี — หน้าจอนี้ใน state Locked ไม่มี action ใดๆ ให้ทำนอกจากกดย้อนกลับ (AppBar's back button ทำงานปกติ, avatar/username ของอีกฝ่ายบน AppBar ยังแตะเปิดโปรไฟล์ได้ตามปกติ ไม่ต้องปิด — การดูโปรไฟล์ไม่ใช่การแชท)

**States** (ลำดับความสำคัญ):
1. **Locked** (ใหม่, สูงสุด) — คู่สนทนาไม่ผ่าน allowlist check → `EmptyStateBlock` แทนที่ body ทั้งหมด (เหนือกว่า Blocked/Restricted/Suspended/PendingRequest ทุก state เดิม — ถ้าเข้าเงื่อนไข Locked ไม่ต้องเช็ค state อื่นต่อเลย)
2. Loading initial / Empty / ส่งข้อความสำเร็จ/error / Blocked / Restricted / Suspended / PendingRequest — เหมือนเดิมทุกประการ (`wyn-031-chat-1to1.md` Screen 3) ใช้เฉพาะเมื่อผ่านเช็ค Locked แล้ว

**Design Rules**: Realtime subscription (Screen 7 เดิม) **ต้องไม่ subscribe เลย** เมื่ออยู่ใน state Locked (ไม่มีอะไรให้ subscribe เพราะส่งข้อความไม่ได้อยู่แล้ว — ป้องกัน resource ที่ไม่จำเป็น ไม่ใช่แค่เรื่อง UI)

**Responsive/Accessibility**: เหมือน Screen A

---

## Screen C — New Message Screen (`NewMessageScreen`) — เพิ่ม State ใหม่

**Purpose**: ผู้ใช้ทั่วไปที่พยายามเริ่มบทสนทนาใหม่ (ค้นหา user เพื่อแชท) ต้องไม่เห็นแม้แต่ช่องค้นหา เพราะยังไงก็สร้างบทสนทนาใหม่ไม่ได้อยู่ดี

**User Flow**: เปิดจากไอคอนดินสอใน Chat Inbox (ปกติมีแค่ @warren/@wynos_online เข้าถึงได้อยู่แล้วเพราะ Screen A บล็อกไปก่อนหน้านี้แล้ว) → เช็คสถานะ lockdown ของผู้ใช้ปัจจุบันก่อน → ถ้าถูกล็อก แสดง State ใหม่แทนช่องค้นหา/รายการ user ทั้งหมด

**Components**: `EmptyStateBlock` เดียวกันเป๊ะกับ Screen A/B

**Design Rules**: ในทางปฏิบัติหน้านี้เข้าถึงได้แค่ผ่าน Chat Inbox ที่บล็อกไว้แล้วที่ Screen A ก็จริง — แต่ต้องมี state นี้ไว้เป็น defense-in-depth เผื่อมี entry point อื่นที่ลืมเช็คไว้ก่อน (deep link ตรง, ปุ่มอื่นในอนาคต) มิฉะนั้นผู้ใช้จะเจอหน้าค้นหาที่ใช้งานได้ปกติแต่กดแล้ว fail ที่ RPC แทน (UX แย่กว่า)

---

## Screen D — ปุ่ม "ส่งข้อความ" บนโปรไฟล์คนอื่น (`ViewProfileScreen`) — ไม่เปลี่ยนปุ่ม เปลี่ยนแค่ผลลัพธ์เมื่อกด

**Purpose**: ปุ่มนี้ต้อง**แสดงและกดได้ปกติเสมอ** (Founder ยืนยันชัด) แม้ตอนแชทถูกปิดอยู่ — ต่างจาก Screen A/B/C ตรงที่นี่ไม่ใช่ "มุมมองต่อเนื่อง" แต่เป็น "การกระทำครั้งเดียว" (กดปุ่ม → เรียก RPC → เปิดหน้าใหม่)

**User Flow**: แตะปุ่ม "ส่งข้อความ" (เหมือน `wyn-031-chat-1to1.md` Screen 4 เป๊ะ ไม่เปลี่ยน) → เรียก `get_or_create_conversation()` → **ถ้า RPC ปฏิเสธเพราะ lockdown** (Coding จะทำให้ RPC raise สำหรับคู่ที่ไม่ผ่าน allowlist ตาม Product spec R1) → **ไม่เปิดหน้า ConversationScreen เลย** แสดง `SnackBar` ข้อความ **"ระบบแชทปิดปรับปรุงชั่วคราว"** แทน (ปุ่มเองยังอยู่ตรงเดิม กดใหม่ได้อีกเสมอ) — มิเรอร์ pattern SnackBar-on-action-failure ที่ `DropDetailScreen`/Club post screens ใช้อยู่แล้ว (WYN-121 เพิ่งวางไว้เป็นตัวอย่างล่าสุดในเซสชันนี้) ไม่ใช้ full-screen state เพราะยังไม่ได้ navigate ไปไหน

**ถ้า RPC สำเร็จ** (คู่ที่ผ่าน allowlist คือ @warren↔@wynos_online เท่านั้น) → เปิด `ConversationScreen` ตามปกติทุกประการ (จะเข้า Screen B's state ปกติ ไม่ใช่ Locked เพราะผ่านการเช็คมาแล้ว)

**Design Rules**: อย่าเปลี่ยน disable/hide ปุ่มนี้เองเด็ดขาด (Founder เน้นย้ำว่าไม่ต้องซ่อน) — ปล่อยให้ RPC เป็นคนตัดสินและ SnackBar เป็นคนบอกผลเสมอ ทำให้พฤติกรรมเหมือนกับตอนแชทเปิดปกติทุกประการจากมุมมองปุ่ม ต่างกันแค่ผลลัพธ์หลังกด

---

## หมายเหตุสำหรับ AI Coding — "Locked" state คำนวณจากอะไร

Design ระดับนี้ไม่ฟันธง mechanism ฝั่ง backend (เป็นเรื่องของ Coding ตาม Product spec's R2 — data-driven toggle) แต่ระบุ **contract ที่ UI ต้องการ** เพื่อ implement 4 หน้าจอข้างบนให้ตรงกัน:

- ต้องมีวิธีให้ client เช็คได้ว่า **คู่ผู้ใช้ 2 คนที่กำหนด (หรือผู้ใช้ปัจจุบันคนเดียว สำหรับ Screen A/C)** อยู่ใน allowlist ที่ได้รับการยกเว้นหรือไม่ — ผลลัพธ์เป็น boolean เดียว (`ผ่าน`/`ไม่ผ่าน`) ไม่ต้องมี reason code ซับซ้อน เพราะ copy ที่แสดงคงที่อยู่แล้วทุกจุด
- Screen A/C เช็คแค่ "ผู้ใช้ปัจจุบันอยู่ใน allowlist ไหม" (ง่ายกว่า เพราะยังไม่รู้จะคุยกับใคร)
- Screen B เช็ค "ทั้งสองฝ่ายของบทสนทนานี้อยู่ใน allowlist ทั้งคู่ไหม" (ตรงตาม Product spec's R1 — "ทั้งสองฝ่ายต้องอยู่ใน allowlist")
- Screen D ไม่ต้องเช็คฝั่ง client เลย — ปล่อยให้ RPC เป็นคนเช็คและ raise ตามปกติ (mirrors ทุก validation อื่นของ `get_or_create_conversation()` ที่มีอยู่แล้ว เช่น self-chat/blocked)
- เช็คนี้ควรทำเร็วที่สุดเท่าที่เป็นไปได้ (ก่อนเรียก query อื่นใดที่หนักกว่า) เพื่อไม่ให้ผู้ใช้ที่ถูกล็อกเห็น spinner นานๆ ก่อนเจอ state Locked

## Handoff

ส่งต่อ **AI Coding** — ลำดับแนะนำ: (1) backend enforcement ตาม Product spec R1/R2/R3 ก่อน (allowlist mechanism + RLS/RPC 3 จุด) (2) `ChatRepository` เพิ่ม method เช็ค lockdown status (ตาม contract ด้านบน) (3) Screen A (`ChatInboxScreen`) เพิ่ม state Locked เป็นลำดับแรกใน `_buildBody()` (4) Screen B (`ConversationScreen`) เพิ่ม state Locked ให้ทำงานก่อน state อื่นทั้งหมดใน body หลัก + ปิด realtime subscription เมื่อ Locked (5) Screen C (`NewMessageScreen`) เพิ่ม state Locked เป็น defense-in-depth (6) Screen D (`ViewProfileScreen`'s "ส่งข้อความ" button) เพิ่ม catch สำหรับ lockdown-rejection แสดง SnackBar แทน error ทั่วไป — ทุกจุด reuse `EmptyStateBlock`/SnackBar ที่มีอยู่แล้ว **ห้ามสร้าง widget ใหม่**
