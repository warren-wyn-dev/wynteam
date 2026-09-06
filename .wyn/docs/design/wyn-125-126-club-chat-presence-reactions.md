# Design — WYN-125 (Presence) + WYN-126 (Chat Reactions)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-125-club-chat-presence.md` และ `.wyn/tasks/backlog/WYN-126-club-chat-reactions.md` — อ่านก่อนเริ่ม
> **สถานะ**: Design เสร็จแล้ว — **AI Coding ห้ามเริ่มจนกว่า WYN-124 (Club Group Chat) จะสร้างเสร็จก่อนเสมอ** (ทั้งสองงานนี้แก้เฉพาะหน้าห้องแชทกลุ่มที่ WYN-124 สร้าง)
> ต่อยอดโดยตรงจาก `.wyn/docs/design/wyn-124-club-group-chat.md` (Screen 2 — Club Chat Room) และกฎ bubble grouping เดิมของ `wyn-031-chat-message-grouping-bubble-spec.md` — ไม่มีจุดใดคิด component ใหม่ทั้งสองงาน ใช้ token เดิม (Sapphire, light-only) ตามที่แก้ไขไว้ใน `wyn-123-club-channels.md`

รวม 2 งานไว้เอกสารเดียวเพราะทั้งคู่แก้ไฟล์เดียวกัน (`club_chat_room_screen.dart` ที่ WYN-124 จะสร้าง) และเล็กพอที่จะไม่ต้องแยกเอกสาร (มิเรอร์ pattern ที่เคยรวม WYN-057/058 ไว้ด้วยกัน)

---

## Screen 1 — Presence (WYN-125)

**Purpose**: บอกว่าสมาชิกคนไหนกำลังเปิดห้องแชทนี้อยู่จริงตอนนี้

**User Flow**: เปิดห้องแชทกลุ่ม → เห็นจุดสีเขียวที่ avatar ของสมาชิกที่ online ในกลุ่มข้อความที่แสดงอยู่ + header เปลี่ยนจาก "N สมาชิก" เป็น "N คนออนไลน์" ทันทีที่มีคน online อย่างน้อย 1 คน → ปิดหน้า/ออกจากห้อง สถานะหายไปให้คนอื่นเห็นภายในไม่กี่วินาที

**Components**:
- **จุดสถานะ (online dot)**: วงกลมเล็ก เส้นผ่านศูนย์กลาง 10px สี `successLight` (`#15803D` — token semantic ที่มีอยู่แล้ว ไม่ใช่สีใหม่) มีขอบ `paper` (`#FFFFFF`) หนา 2px ล้อมรอบ (จำเป็นเพื่อให้จุดแยกจากรูป avatar ที่พื้นหลังไม่แน่นอน — ใช้เทคนิค `Positioned` มุมขวาล่างเดียวกับที่ `RootShell._buildNotificationsIcon` ใช้วาง badge ตัวเลข ไม่ใช่โครงใหม่) แสดงเฉพาะที่ **avatar ของกลุ่มข้อความ** (ตำแหน่งเดิมจาก WYN-124's กฎ "avatar ที่ bubble ล่างสุดของกลุ่ม") ไม่ใช่ทุก bubble
- **Header subtitle**: จุดเดิมที่ WYN-124 ออกแบบเป็น "N สมาชิก" ใต้ชื่อ Club — สลับเป็น "N คนออนไลน์" (ตัวเลขคือจำนวนสมาชิกที่ online จริงตอนนั้น) เมื่อ ≥ 1 คน online, กลับเป็น "N สมาชิก" (ตัวเลขคือจำนวนสมาชิกทั้งหมดเหมือนเดิม) เมื่อไม่มีใคร online เลย — ข้อความเดียว สลับกันเอง ไม่ใช่แสดงคู่กัน

**Interactions**: ไม่มีการแตะ/กดใดๆ กับจุดสถานะ (เป็น indicator อย่างเดียว ไม่ใช่ปุ่ม)

**States**: online ≥1 คน (header = "N คนออนไลน์"), online 0 คน (header = "N สมาชิก" ตามเดิม, ไม่มีจุดเขียวที่ avatar ใดเลย) — ไม่มี state error พิเศษ (presence connect ไม่สำเร็จ = แค่ไม่เห็นจุดเขียว ไม่กระทบการใช้งานอื่นของห้องแชทเลย เป็น graceful degradation ไม่ต้องมี UI แจ้ง error)

**Responsive Behavior**: ไม่มีผลต่อ layout อื่น (จุดวางซ้อนบน avatar เดิม ไม่ดันขนาด/ตำแหน่งอะไรขยับ)

**Accessibility**: `Semantics` ของ avatar ที่มีจุดเขียวต้องรวมคำว่า "ออนไลน์" ต่อท้ายชื่อผู้ส่ง (เช่น "ข้อความจาก แอดมิน (ออนไลน์): ...") ไม่ใช่จุดสีลอยๆ ที่ screen reader มองไม่เห็น

**Design Rules**: ใช้ token semantic เดิม (`successLight`) ไม่ใช่สีแบรนด์ sapphire — จุดออนไลน์ไม่ใช่ brand element เป็นสถานะ ตรงกับกติกาเดิมของระบบที่แยกสี status (แดง/เขียว/เหลือง) ออกจากสีแบรนด์อยู่แล้ว

---

## Screen 2 — Chat Reactions (WYN-126)

**Purpose**: ตอบสนองข้อความเร็วๆ ด้วย emoji ชุดคงที่ โดยไม่ต้องพิมพ์ตอบ

**User Flow (เพิ่ม reaction)**: กดค้างที่ bubble ข้อความ (จุดเดิมที่เปิดเมนู "ตอบกลับ/ลบ/รายงาน" ของ WYN-031 อยู่แล้ว) → **แถบ emoji 6 ตัวโผล่ขึ้นเป็นแถวบนสุดของ sheet เดิม** (เหนือแถวเมนูปกติ ไม่ใช่แทนที่) → แตะ emoji ที่ต้องการ → sheet ปิดทันที, reaction ติดใต้ bubble นั้นทันที (optimistic)

**User Flow (ลบ reaction ของตัวเอง / เพิ่มจาก pill ที่มีอยู่)**: แตะ pill reaction ที่ติดอยู่ใต้ bubble โดยตรง (ไม่ต้องกดค้างซ้ำ) → ถ้า emoji นั้นเป็นของตัวเองอยู่แล้ว = เอาออก, ถ้ายังไม่ใช่ = เพิ่มเข้าไป (toggle เหมือน Like)

**Components**:
- **แถบ Quick-reaction**: 6 ปุ่มวงกลม (❤️ 😂 😮 😢 🔥 👍) เรียงแถวเดียวเต็มความกว้าง sheet เหนือ `SheetDragHandle` ที่ `ActionSheetBody` มีอยู่แล้ว — ปุ่มละ 40px (≥ `touchTargetMin`), ระยะห่างเท่ากันเว้นด้วย `MainAxisAlignment.spaceEvenly`, ไม่มีพื้นหลัง/ขอบ (emoji ลอยเฉยๆ กดแล้วมี ripple ตาม Material ปกติ) — **แถวนี้ไม่ใช่ widget ใหม่ทั้งหมด**: ประกอบจาก `ActionSheetBody` เดิม + แค่เพิ่ม parameter `leading` (widget ก่อนแถว rows ปัจจุบัน) ให้ widget เดิมรับได้ ไม่ต้องสร้างชีตแยก
- **Reaction pill ใต้ bubble**: แถวเล็กอยู่ใต้ bubble ห่าง 3px (ไม่กระทบระยะ 4/16/20px ของกฎ grouping เดิม เพราะเป็น element แทรกในกลุ่มเดียวกัน ไม่ใช่ระยะระหว่างกลุ่ม) — pill ทรงเม็ดยา พื้น `surfaceTint` (#F1EFE9, สีเดียวกับ bubble ขาเข้า) ตัวหนังสือ/ไอคอน `graphite` ปกติ, **เปลี่ยนเป็นพื้น sapphire อ่อน + ตัวหนังสือ sapphire เมื่อผู้ดูเองก็ react ด้วย emoji นั้น** (สถานะ active มิเรอร์กติกาสี "ของฉัน vs คนอื่น" แบบเดียวกับปุ่ม Like ที่ toggle แล้วเปลี่ยนสี) — เนื้อใน pill: emoji + ตัวเลขยอดรวม (เช่น "❤️ 3") ต่อ 1 pill ต่อ 1 ชนิด emoji ที่มีคนกดอย่างน้อย 1 คน — ถ้าไม่มีใคร react เลยไม่มีแถวนี้ (ไม่เผื่อพื้นที่ว่างไว้)
- pill เรียงแนวนอน wrap ได้ถ้าเกิน 1 แถว (เผื่อกรณีมีคน react ครบทั้ง 6 emoji) — ชิดด้านเดียวกับ bubble (ซ้ายสำหรับข้อความเข้า, ขวาสำหรับข้อความออก) ตาม alignment เดิมของ `msg-group`

**Interactions**: แตะ pill = toggle ทันที (optimistic, revert เมื่อ error ตาม pattern เดิมของ `_toggleLike`/`_toggleSave` ทั้งระบบ) — ไม่มี long-press พิเศษที่ pill (long-press ยังคงเปิด context menu ที่ bubble เหมือนเดิม ไม่ใช่ที่ pill)

**States**: bubble ที่ยังไม่มีใคร react (ไม่มี pill แถวใดเลย, หน้าตาเหมือนก่อนมี WYN-126 ทุกประการ — Club ที่ปิดฟีเจอร์นี้ในทางปฏิบัติ [ไม่มีใคร react] จะไม่รู้สึกว่าอะไรเปลี่ยนเลย), bubble ที่มี 1+ reaction (แถว pill ปรากฏ), error ตอน toggle (revert แบบเงียบ ไม่มี SnackBar — เหตุผลเดียวกับ Like/Save ที่ error rate ต่ำมากและ toggle ซ้ำแก้เองได้ทันที)

**Responsive Behavior**: pill wrap ตามความกว้างจอ ไม่ล้นขอบ

**Accessibility**: `Semantics` ของแต่ละ pill ประกาศ "รีแอคชัน [emoji] N คน กดเพื่อ[เพิ่ม/เอาออก]" ตามสถานะ active ปัจจุบัน — ปุ่มใน quick-reaction bar มี `Semantics(label: 'รีแอคชันด้วย [ชื่อ emoji ภาษาไทย]')` เพราะ emoji เดี่ยวๆ ไม่ได้อ่านความหมายชัดเจนสำหรับ screen reader เสมอไป

**Design Rules**: สี/ทรง pill ยืมจาก pattern pill ที่มีอยู่แล้ว (category badge pill ของ ClubPage header, WYN-057/058) ไม่ใช่ของใหม่ — quick-reaction bar ไม่มีพื้นหลัง/เงาใหม่ ใช้พื้นที่ว่างของ sheet เดิม

---

## หมายเหตุถึง Coding (ทั้งสองงาน)

- **WYN-125**: ต้องแยกให้ชัดว่า "online" ผูกกับการเปิดหน้าห้องแชทนี้ค้างอยู่เท่านั้น (ตาม R3 ของ Product spec) — ปิดแอปทิ้งไว้เฉยๆ ที่หน้าอื่นไม่ควรยังนับว่า online ในห้องนี้
- **WYN-126**: การนับ "ยอดรวมต่อ emoji" ต้องคำนวณที่ query/RPC ไม่ใช่ fetch reaction ดิบมานับฝั่ง client (เหตุผลเดียวกับที่ WYN-117 เตือนไว้เรื่อง aggregate query) โดยเฉพาะห้องแชทที่มีข้อความเยอะๆ

## Handoff

ส่งต่อ **AI Coding** — **ห้ามเริ่มจนกว่า WYN-124 จะสร้างเสร็จก่อนเสมอ** เมื่อถึงคิวจริงให้อ่านโค้ด `club_chat_room_screen.dart` ที่ WYN-124 สร้างไว้จริงก่อนเริ่ม (ไม่ใช่แค่เอกสารนี้) เพราะโครงสร้างจริงอาจต่างจากที่ประเมินไว้ตอนออกแบบล่วงหน้านี้เล็กน้อย

หลัง Coding เสร็จ → ส่งต่อ **AI QA & Security** ตามลำดับ workflow ปกติ
