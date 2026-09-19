# Design — WYN-170: Chat Inbox Premium Polish Pass

Owner: AI Design → รอ Founder อนุมัติ scope → AI Coding
Ref: ภาพหน้าจอจริงที่ Founder ส่งมา (`/root/.claude/uploads/4836b08a-a769-50e2-bfc1-05b0bb39a8cf/45bbd2cf-image.png`),
`web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css`, ภาษาการออกแบบเดิมจาก
`.wyn/docs/design/wyn-163-onboarding-button-redesign.md` (squircle, press-scale motion),
`.wyn/docs/design/wyn-167-home-feed-apple-style-extension.md` (motion extension pattern)

## Feedback ต้นทาง

Founder: "ออกแบบหน้าใหม่ได้ไหม มันไม่สวย" (ไม่ได้ระบุจุดเฉพาะ) พร้อมภาพหน้าจอ Chat Inbox จริงที่มีแค่ 1
บทสนทนา (WARREN)

## สิ่งที่ตรวจพบจากการเทียบภาพจริงกับโค้ดจริง

ไล่โค้ด `chat-inbox-parity.tsx` และ `chat-notes.css` เทียบกับภาพที่ Founder ส่งมาแล้ว พบ **จุดบกพร่องที่ชัดเจน
และเป็นรูปธรรม** (ไม่ใช่แค่รสนิยม) อยู่ 1 จุดหลัก และจุดเสริมทางสไตล์อีก 2 จุด:

1. **(หลัก) พื้นที่ว่างเปล่าขนาดใหญ่ท้ายรายการแชท — ไม่มี state ไหนออกแบบไว้เลย** — โค้ดปัจจุบันมีแค่ 2 state
   สำหรับรายการแชท: (ก) `visibleRows.length === 0` → แสดง `EmptyState` ("ยังไม่มีข้อความ") และ (ข)
   `visibleRows.length > 0` → แสดงรายการเฉยๆ แล้วจบ ไม่มี state ที่ 3 สำหรับ "มีข้อความบ้างแต่ไม่พอเต็มจอ"
   เลย — เป็นช่องโหว่ในการออกแบบเดิมของ WYN-162 ที่ไม่เคยถูกคิดถึง เพราะตอนออกแบบน่าจะคิดแค่ภาพ mockup ที่มี
   รายการเต็มจอเสมอ ผลคือพอผู้ใช้จริงมีข้อความน้อย (เช่น Founder มี 1 ข้อความ) จอจะเหลือพื้นที่ขาวโล่งขนาดใหญ่
   (~60-70% ของความสูงจอ) ที่ไม่มีอะไรเลย — ดูเหมือนหน้าโหลดไม่เสร็จ/แอปพัง มากกว่าดีไซน์ตั้งใจ **นี่คือจุดที่
   น่าจะเป็นสาเหตุหลักที่ทำให้ Founder รู้สึกว่า "ไม่สวย"**
2. **(เสริม) แถว Notes รู้สึกโดดเดี่ยว** — ตอนนี้ Founder มีแค่การ์ด "เพิ่มโน้ต" ของตัวเองใบเดียว (ยังไม่มีเพื่อน
   คนไหนมีโน้ตค้างอยู่) ซึ่งเป็นพฤติกรรมที่ตั้งใจ (Instagram-style) แต่ยังไม่มี fallback ใดๆ ที่ทำให้แถวนี้ดู
   ตั้งใจเวลามีแค่ 1 การ์ด — ยังไม่ใช่บั๊ก แต่เป็นจุดที่ทำให้หน้าดูโล่งเสริมกับปัญหาข้อ 1
3. **(เสริม) แถวบทสนทนายังเป็น list แบบพื้นฐาน ไม่มี motion/press feedback เลย** — ต่างจากปุ่ม header 2 จุดที่
   เพิ่งได้ press-scale ไปใน WYN-169 แถวบทสนทนาทั้งแถว (ที่กดบ่อยที่สุดในหน้านี้) ยังไม่มี feedback ตอนกดเลย
   สัมผัสจึงรู้สึก "เรียบเป็นทางการ" (bare list) มากกว่า "พรีเมียม" แบบที่ WYN-163/167 วางแนวไว้

## ขอบเขตที่เสนอ (WYN-170)

**Purpose**: แก้จุดบกพร่องที่เป็นรูปธรรม (พื้นที่ว่างท้ายรายการ) และเติม polish ที่สอดคล้องกับภาษาการออกแบบ
เดิม (ไม่ใช่คิดทิศทางใหม่) ให้หน้า Chat Inbox รู้สึกตั้งใจ/พรีเมียมขึ้น โดยไม่แตะ IA/user flow เดิม

### Screen: WYNOS Web Chat Inbox (`/chat`)

**Components**:
- ใหม่: "ท้ายรายการ" (end-of-list marker) — ไอคอนวงกลมเล็ก + ข้อความสั้นภาษาไทย (เช่น "เห็นข้อความล่าสุดแล้ว")
  ต่อท้าย `.chat-list` เสมอ (ไม่ใช่แค่ตอนรายการสั้น — ใช้ pattern เดียวกับ "จบฟีดแล้ว" ที่แอปแชทส่วนใหญ่ใช้ ทำให้
  ไม่ต้องเช็คเงื่อนไข "สั้นแค่ไหนถึงจะโชว์" ซึ่งเปราะบาง) ใช้ icon-in-circle pattern เดียวกับที่มีอยู่แล้วใน
  `.route-empty::before` ของหน้า Discovery/hashtag (ไม่ประดิษฐ์ pattern ใหม่) สีและ token ใช้ `--wyn-text-muted`/
  `--wyn-surface` ชุดเดิม
- แก้ไข: `.wyn-chat-inbox .flutter-chat-list .chat-row` — เพิ่ม `:active { transform: scale(0.96) }` +
  `transition` (สูตรเดียวกับ WYN-163/167/169 เป๊ะ) ให้ทั้งแถว ไม่ใช่แค่ปุ่ม header
- ไม่แตะ: Notes row structure เดิม (ข้อ 2 ด้านบน เป็นแค่ observation ไม่ใช่ scope ที่เสนอแก้รอบนี้ — ถ้าจะแก้ควร
  รอดูว่าหลังแก้ข้อ 1 แล้วยังรู้สึกโล่งอยู่ไหมก่อน ไม่อยากแก้เกินจำเป็นในรอบเดียว)
- ไม่แตะ: `.wyn-chat-note-card`, `.wyn-chat-note-bubble`, note composer, new-message modal, requests modal,
  ปุ่มย้อนกลับ (ประกาศซ้ำ 4 ไฟล์ ตามที่ WYN-169 เคยระบุไว้ — ยังไม่ปลอดภัยจะแตะ)

**Interactions**:
- แถวบทสนทนา: `:active { transform: scale(0.96) }`, `transition: transform 160ms
  cubic-bezier(0.34, 1.56, 0.64, 1)` — สูตรเดียวกับทุกจุดที่ทำมาแล้ว ไม่ประดิษฐ์ค่าใหม่
- ท้ายรายการ: ไม่ต้อง interactive (เป็นแค่ marker บอกจบรายการ)

**States**: เพิ่ม state ที่ 3 ที่ขาดไปของรายการแชท ("มีข้อความ + จบรายการแล้ว") ให้ชัดเจนแยกจาก "ว่างเปล่า
สนิท" (`EmptyState` เดิม) และ "กำลังโหลด" (`ChatListSkeleton` เดิม) — ครบ 3 state ตามหลักการที่ AGENTS.md ระบุ
ว่า loading/empty/error/interaction states เป็น requirement ไม่ใช่งานเก็บท้ายรอบ

**Responsive Behavior**: ไม่เปลี่ยนจากเดิม ใช้ breakpoint เดิมที่มีอยู่ (`max-width: 430px`)

**Accessibility**: ท้ายรายการใช้ข้อความจริง (ไม่ใช่แค่ไอคอน) มี `aria-hidden` บนไอคอนตกแต่งเหมือน pattern เดิม
ของ `.route-empty`; press-scale ของแถวบทสนทนาต้องอยู่ใต้ `@media (prefers-reduced-motion: reduce)` เดียวกับที่
`chat-notes.css` มีอยู่แล้ว (เพิ่ม selector เข้าไปในบล็อกเดิม ไม่สร้างบล็อกใหม่)

**Design Rules**:
1. ใช้ token/motion เดิมทั้งหมด (`--wyn-*`, สูตร press-scale เดิม) ไม่ประดิษฐ์สี/effect ใหม่
2. ไม่ทำ Notes row ใหม่ในรอบนี้ (ข้อ 2 จากการวิเคราะห์ — เก็บไว้ดูผลหลังแก้ข้อ 1 ก่อน)
3. ไม่แตะปุ่มย้อนกลับ/`.route-*` ที่ใช้ร่วมหลายหน้าจอ (เหตุผลเดียวกับ WYN-169)
4. ไม่ใช่การรื้อ layout/IA — เป็น polish pass ไม่ใช่ redesign ทั้งหน้า

## Handoff

พร้อมส่ง AI Coding หลัง Founder อนุมัติ — 2 ไฟล์ (`web/components/chat-inbox-parity.tsx` เพิ่ม JSX ท้าย
`.chat-list`, `web/app/chat-notes.css` เพิ่ม CSS ของ marker ใหม่ + press-scale ของแถว) ความเสี่ยง regression
ต่ำ (ไม่แตะ data flow/logic ใดๆ เป็น presentational เพิ่มเติมล้วนๆ)

**คำถามสำหรับ Founder**:
1. เห็นด้วยกับขอบเขตนี้ไหม (เติม "ท้ายรายการ" กันพื้นที่ว่างโล่ง + เพิ่ม press feedback ให้แถวบทสนทนา ไม่รื้อ
   layout/Notes row ทั้งหมด)?
2. ข้อความ "ท้ายรายการ" อยากให้เขียนว่าอะไร (เสนอ: "เห็นข้อความล่าสุดแล้ว") หรือให้ AI Design เลือกเอง?
