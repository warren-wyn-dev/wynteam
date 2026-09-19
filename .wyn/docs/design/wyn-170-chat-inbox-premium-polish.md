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

## ขอบเขตที่เสนอ (WYN-170) — v2 (ขยายตามที่ Founder อนุมัติ)

Founder เห็น demo รอบแรก (แค่ข้อ 1 พื้นที่ว่างโล่ง) แล้วถาม "โอเค แก้แค่นี้หรอ" — AI Design เสนอขยายขอบเขต
ให้ครอบคลุมข้อ 2 (Notes row โดดเดี่ยว) และข้อ 3 (แถวแชทไม่มีความเป็นการ์ด) ด้วย **Founder อนุมัติ "ขยาย —
ทำให้ครบ"**

**Purpose**: แก้จุดบกพร่องที่เป็นรูปธรรม (พื้นที่ว่างท้ายรายการ) + ยกระดับความรู้สึก "พรีเมียม" ของ Notes row
และแถวบทสนทนาให้สอดคล้องกับภาษาการออกแบบเดิม (WYN-163/167) มากขึ้น โดยไม่แตะ IA/user flow เดิม ไม่ใช่การรื้อ
หน้าใหม่ทั้งหมด

### Screen: WYNOS Web Chat Inbox (`/chat`)

**Components**:
1. ใหม่: "ท้ายรายการ" (end-of-list marker) — ไอคอนวงกลมเล็ก + ข้อความสั้นภาษาไทย **"เห็นข้อความล่าสุดแล้ว"**
   ต่อท้าย `.chat-list` เสมอ (ไม่ใช่แค่ตอนรายการสั้น — ใช้ pattern เดียวกับ "จบฟีดแล้ว" ที่แอปแชทส่วนใหญ่ใช้
   ทำให้ไม่ต้องเช็คเงื่อนไข "สั้นแค่ไหนถึงจะโชว์" ซึ่งเปราะบาง) ใช้ icon-in-circle pattern เดียวกับที่มีอยู่แล้ว
   ใน `.route-empty::before` ของหน้า Discovery/hashtag (ไม่ประดิษฐ์ pattern ใหม่) สีและ token ใช้
   `--wyn-text-muted`/`--wyn-surface` ชุดเดิม
2. แก้ไข: `.wyn-chat-inbox .flutter-chat-list .chat-row` — เปลี่ยนจาก "flat list + เส้นคั่นบางๆ" เป็น
   **squircle card**: `background: var(--wyn-surface)`, `border-radius: 18px` (ค่าเดียวกับ input/section
   radius ที่ใช้บ่อยที่สุดในระบบทั้งเว็บ — ยืนยันด้วย grep ว่า `18px` เป็นค่าที่ใช้ซ้ำมากที่สุดอันดับ 2 ทั่ว
   `web/app/*.css` ไม่ใช่ค่าประดิษฐ์ใหม่), เว้นระยะห่างระหว่างการ์ด (margin แนวตั้ง ~8px) แทนเส้นคั่น — ลบ
   `::after` divider เดิมออกเพราะไม่จำเป็นอีกต่อไปเมื่อแต่ละแถวแยกเป็นการ์ดของตัวเอง เพิ่ม `:active { transform:
   scale(0.96) }` + `transition` (สูตรเดียวกับ WYN-163/167/169 เป๊ะ) ให้ทั้งการ์ด
3. แก้ไข: `.wyn-chat-notes` — เพิ่ม modifier class `.is-solo` (ใส่เมื่อ `notes.length === 0` คือมีแค่การ์ด
   "เพิ่มโน้ต" ของตัวเอง ไม่มีโน้ตเพื่อนเลย) ลด `min-height` จาก 136px เหลือขนาดที่พอดีกับการ์ดเดียว (~118px,
   เท่ากับ `min-height` ของตัว `.wyn-chat-note-card` เอง + padding เล็กน้อย) ให้แถบดูเป็น "ช่องที่ตั้งใจให้พอดี
   กับของที่มี" แทนที่จะเป็น "แกลเลอรีที่ว่างเปล่าเกือบหมด" — ไม่เปลี่ยนโครงสร้าง/ตำแหน่งการ์ดใดๆ เปลี่ยนแค่
   ความสูงของ container เมื่ออยู่ในสถานะ solo
- ไม่แตะ: `.wyn-chat-note-card`, `.wyn-chat-note-bubble` เนื้อหาภายในการ์ดโน้ต, note composer, new-message
  modal, requests modal, ปุ่มย้อนกลับ (ประกาศซ้ำ 4 ไฟล์ ตามที่ WYN-169 เคยระบุไว้ — ยังไม่ปลอดภัยจะแตะ)

**Interactions**:
- แถวบทสนทนา (การ์ดใหม่): `:active { transform: scale(0.96) }`, `transition: transform 160ms
  cubic-bezier(0.34, 1.56, 0.64, 1)` — สูตรเดียวกับทุกจุดที่ทำมาแล้ว ไม่ประดิษฐ์ค่าใหม่
- ท้ายรายการ: ไม่ต้อง interactive (เป็นแค่ marker บอกจบรายการ)
- Notes row solo state: ไม่มี interaction ใหม่ เปลี่ยนแค่ขนาด container

**States**: เพิ่ม state ที่ 3 ที่ขาดไปของรายการแชท ("มีข้อความ + จบรายการแล้ว") ให้ชัดเจนแยกจาก "ว่างเปล่า
สนิท" (`EmptyState` เดิม) และ "กำลังโหลด" (`ChatListSkeleton` เดิม) — ครบ 3 state ตามหลักการที่ AGENTS.md ระบุ
ว่า loading/empty/error/interaction states เป็น requirement ไม่ใช่งานเก็บท้ายรอบ; เพิ่ม state ใหม่ของ Notes row
("solo" vs "มีโน้ตเพื่อนด้วย" — ใช้ CSS class ตาม `notes.length`, ไม่กระทบ logic การดึงข้อมูล)

**Responsive Behavior**: ไม่เปลี่ยนจากเดิม ใช้ breakpoint เดิมที่มีอยู่ (`max-width: 430px`) — ปรับ margin ของ
การ์ดแชทให้สอดคล้องกับ padding เดิมที่มีอยู่แล้วในแต่ละ breakpoint เท่านั้น ไม่เพิ่ม breakpoint ใหม่

**Accessibility**: ท้ายรายการใช้ข้อความจริง (ไม่ใช่แค่ไอคอน) มี `aria-hidden` บนไอคอนตกแต่งเหมือน pattern เดิม
ของ `.route-empty`; press-scale ของแถวบทสนทนาต้องอยู่ใต้ `@media (prefers-reduced-motion: reduce)` เดียวกับที่
`chat-notes.css` มีอยู่แล้ว (เพิ่ม selector เข้าไปในบล็อกเดิม ไม่สร้างบล็อกใหม่); touch target ของการ์ดแชทยังคง
≥44px เหมือนเดิม (แค่เปลี่ยน background/radius ไม่เปลี่ยนขนาด)

**Design Rules**:
1. ใช้ token/motion/radius เดิมทั้งหมด (`--wyn-*`, 18px, สูตร press-scale เดิม) ไม่ประดิษฐ์สี/effect/ค่าตัวเลข
   ใหม่ — ทุกค่ายืนยันแล้วว่ามีใช้ซ้ำในระบบจริง
2. ไม่แตะปุ่มย้อนกลับ/`.route-*` ที่ใช้ร่วมหลายหน้าจอ (เหตุผลเดียวกับ WYN-169)
3. ไม่แตะเนื้อหา/ฟังก์ชันของการ์ดโน้ต (note composer, badge, avatar) เปลี่ยนแค่ความสูงของแถบเมื่ออยู่ใน solo
   state
4. ไม่ใช่การรื้อ layout/IA — ยังเป็น polish pass ไม่ใช่ redesign ทั้งหน้า (ไม่เปลี่ยนลำดับ/ตำแหน่งของ
   header → search → notes → chat list)

## Handoff

พร้อมส่ง AI Coding หลัง Founder อนุมัติ — 2 ไฟล์ (`web/components/chat-inbox-parity.tsx` เพิ่ม JSX ท้าย
`.chat-list` + เพิ่ม conditional class บน `.wyn-chat-notes`, `web/app/chat-notes.css` เพิ่ม CSS ของ marker
ใหม่ + squircle card ของแถวแชท + `.is-solo` modifier) ความเสี่ยง regression ต่ำ-กลาง (เปลี่ยน visual ของแถว
แชทมากกว่ารอบแรก แต่ไม่แตะ data flow/logic ใดๆ ยังเป็น presentational ล้วนๆ)

**คำถามสำหรับ Founder**: เห็นด้วยกับขอบเขตที่ขยายแล้วนี้ไหม (เติมท้ายรายการ + การ์ด squircle ให้แถวแชท + ลด
ความสูง Notes row ตอนมีแค่การ์ดเดียว)?
