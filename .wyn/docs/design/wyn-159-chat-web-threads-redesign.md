# Design — WYN-159 (Chat Web Redesign — "Threads-like" restraint)

> คำขอ Founder: "ออกแบบหน้าแชทให้ใหม่หน่อย อยากได้เหมือนเธรด" (ผ่าน `/design`)
> Scope: `web/` (Next.js consumer web, ใต้ WYN-158 migration) — `components/chat-inbox-parity.tsx` (Inbox) + `components/chat-routes.tsx` (Conversation) + `app/phase3.css`
> **ไม่แตะ Flutter app** — คนละ surface, คนละ task

## หมายเหตุก่อนเริ่ม — ทำไมไม่ใช่การ "ก็อปปี้ Threads"

กติกาถาวรจาก `.wyn/docs/design/design-principles.md`: **ห้ามลอก Layout ของ Instagram/TikTok โดยตรง** และ
DS-001 (`.wyn/company/DECISIONS.md` 2026-08-15) ยืนยันสีแบรนด์ WYN คือ **Cyan `#00C8FF` + ดำ/ขาว/เทา**
ไม่ใช่โทนน้ำเงิน/สีอื่นของ Meta apps ผมตีความคำว่า "เหมือนเธรด" เป็น**ความรู้สึกที่ต้องการ** (restrained,
monochrome-first, ช่องว่างเยอะ, ไม่มี chrome รก, ข้อความเป็นตัวเอก) — **ไม่ใช่การก็อปปี้สี/โลโก้/โครง component
ของ Threads ตรงๆ** ทิศทางนี้เข้ากับ design system ของ WYN เดิมอยู่แล้ว (Cyan ≤15%, ห้ามเป็นพื้นหลังใหญ่ —
DS-001 ข้อ 6) ไม่ต้องคิดทิศทาง visual ใหม่ ใช้ของเดิมที่อนุมัติแล้วเป๊ะ

**สิ่งที่ยังใช้ของเดิม 100%**: token สี (`--wyn-bg`/`--wyn-text`/`--wyn-surface`/`--wyn-border`/
`--wyn-text-secondary`), dark mode (อนุมัติเฉพาะฝั่งเว็บ 2026-09-16), bottom nav ที่มี Chat tab อยู่แล้ว
(ยืนยันถาวร 2026-09-16 — **ไม่ย้าย entry point**), gate `DeveloperRouteGate` ที่ครอบทั้งหน้าแชทอยู่แล้ว
(WYN-122 chat-lockdown-testers-only — ฟีเจอร์นี้ผ่าน staged rollout ไปแล้วตั้งแต่ต้น ไม่ต้องเพิ่ม gate ใหม่
ตาม WYN-125 เพราะนี่คือการปรับ UX ของฟีเจอร์ที่ live+gated อยู่แล้ว ไม่ใช่ฟีเจอร์ใหม่)

**สิ่งที่ "เหมือนเธรด" จริงๆ ที่จะทำ**: เอา spec การจัดกลุ่มข้อความที่ Founder อนุมัติไปแล้วสำหรับ Flutter
(`.wyn/docs/design/wyn-031-chat-message-grouping-bubble-spec.md`, status "Ready for implementation") แต่
**ยังไม่เคยถูกทำในฝั่งเว็บ** มาทำให้ครบในเว็บ — นี่คือช่องว่างจริงที่ทำให้เว็บแชทตอนนี้ดู "แชทธรรมดา" (bubble
เท่ากันหมด เว้นระยะเท่ากันหมด ไม่มี timestamp/read receipt) ในขณะที่ Threads/แชทสมัยใหม่รู้สึกลื่นเพราะจังหวะ
การจัดกลุ่มข้อความ ไม่ใช่เพราะสีหรือโลโก้

---

## Screen 1 — Chat Inbox (`components/chat-inbox-parity.tsx`, route `/chat`)

**Purpose**: รายชื่อบทสนทนา ปรับให้โล่งขึ้น อ่านไว ตัดความรกของแถบ header

**User Flow**: ไม่เปลี่ยนจากเดิม — เข้าจาก bottom nav Chat tab → เห็นแท็บ "ทั้งหมด/ยังไม่อ่าน" → แตะแถว →
เปิดบทสนทนา (`ConversationRoute`) แตะ "คำขอ" หรือปุ่มเขียนข้อความใหม่ → modal เดิม (ไม่แก้ flow)

**Components** (คงโครง DOM เดิม `flutter-chat-inbox`/`flutter-chat-header`/`flutter-chat-pill-tabs`/
`chat-list`/`chat-row`, ปรับเฉพาะสไตล์):
- Header (`flutter-chat-header`): ลด border-bottom ให้จางลง (`var(--wyn-border)` แต่บางลงเป็น `0.5px` หรือ
  ใช้ `color-mix` ให้จางกว่าเดิม ~50%) — หัวเรื่อง "ข้อความ" ใช้ font-weight หนักขึ้น (700→800) ให้เด่นแบบ
  ชื่อหน้าของ Threads โดยไม่ต้องเพิ่มสี
- แถวรายการ (`.chat-row`): เพิ่มช่องไฟแนวตั้งจาก `min-height: 70px` เป็น `76px` ให้หายใจมากขึ้น, ตัด
  `border-bottom` ระหว่างแถวออก (ใช้ spacing แทนเส้นแบ่งทุกแถว — เหลือเส้นแบ่งจางๆ ทุก section เท่านั้น เช่น
  ก่อนวันที่เปลี่ยน ถ้าจะทำ grouping-by-date ในอนาคต — รอบนี้ไม่ทำ grouping ที่ inbox แค่ตัดเส้นให้โล่งขึ้น)
- unread state (`.chat-row.unread`): เดิม `background: color-mix(4%)` ยังคงไว้ แต่เปลี่ยนตัวบอก unread จาก
  พื้นหลังแถวทั้งแถว (สังเกตยาก, contrast ต่ำ) เป็น**จุดกลมเล็ก 8px สี `var(--wyn-text)` มุมขวาบนของ avatar**
  (มิเรอร์ pattern จุด unread ที่ Flutter's `ChatInboxScreen` ออกแบบไว้แล้วใน
  `wyn-031-chat-1to1.md` Screen 2 — "จุดกลม...ขนาดเล็กมุมขวาบนของ avatar") — **ไม่ใช้ Cyan สำหรับจุดนี้**
  เพราะ DS-001 ข้อ 6 ห้าม Cyan เป็นตัวบอกสถานะทั่วไปนอกเหนือ 2 จุดที่ DS-009 ล็อกไว้ ใช้สีดำ/ขาวตาม theme พอ

**Interactions**: ไม่เปลี่ยน (แตะแถว/long-press ยังไม่มีใน parity เวอร์ชันเว็บ — ถ้าจะเพิ่ม mute-toggle
long-press ให้ตรงกับ Flutter ต้องเป็น task แยก ไม่รวมในรอบนี้เพื่อไม่ขยาย scope)

**States**: Loading/Empty/Error เดิมคงไว้ (ไม่ได้อยู่ใน screenshot ที่ Founder ส่งมา ไม่แก้โดยไม่มีเหตุ)

**Responsive Behavior**: ไม่เปลี่ยน breakpoint เดิม ทดสอบที่ mobile width เดิม (Playwright `webkit-iphone`)

**Accessibility**: จุด unread ใหม่ต้องมี `aria-hidden` (เพราะ semantics บอก unread อยู่แล้วผ่าน `strong`
font-weight + text ของแถว — จุดกลมเป็น visual cue เสริม ไม่ใช่ข้อมูลใหม่ที่ screen reader ต้องอ่านซ้ำ)

**Design Rules**: ห้ามเพิ่มสีใหม่ ห้ามใช้ Cyan/Rainbow ในจุดนี้ ใช้ token เดิมเท่านั้น

---

## Screen 2 — Conversation (`components/chat-routes.tsx` → `ConversationInner`, route `/chat/[id]`)

**Purpose**: พอร์ต spec การจัดกลุ่มข้อความที่ Founder อนุมัติแล้ว (`wyn-031-chat-message-grouping-bubble-spec.md`)
จาก Flutter มาเว็บ — นี่คือส่วนที่ทำให้หน้าแชทรู้สึก "ทันสมัยแบบเธรด" จริงๆ ไม่ใช่การเปลี่ยนสี

**User Flow**: ไม่เปลี่ยนจากเดิม (เปิดจาก inbox → เห็นข้อความ → พิมพ์/แนบรูป → ส่ง) การจัดกลุ่มเป็นการ
**เปลี่ยนวิธีแสดงผล ไม่เปลี่ยนวิธีใช้งาน**

**Components**:
1. **Grouping logic** (ใหม่ในเว็บ, มีอยู่แล้วใน Flutter): ข้อความอยู่กลุ่มเดียวกันถ้า sender เดียวกัน + ห่างกัน
   ≤60 วินาที + ไม่ข้ามวัน — ระยะห่างระหว่าง bubble ในกลุ่มเดียวกัน 4px, ระหว่างกลุ่มเดียวกัน (คนละช่วงเวลา)
   16px, ระหว่างกลุ่มคนละคน 20px (ตาม spec เดิมทุกตัวเลข — เว็บใช้ `gap` แทน margin ต่อ row ปัจจุบันที่เป็น
   `gap: 7px` คงที่ทุกคู่ ปรับ `.message-list` ให้ใช้ margin แบบ dynamic ต่อ row-pair ตาม §3 ของ spec)
2. **Bubble corner "tail"**: ลด radius จาก 18px เป็น 4px เฉพาะมุมที่ชนกับ bubble ข้างในกลุ่มเดียวกัน (ตาม §5
   ของ spec เป๊ะ ทั้งฝั่ง mine/theirs) — bubble เดี่ยว (ไม่มีกลุ่ม) ยังคง 18px รอบเดิมเหมือนที่ CSS มีอยู่แล้ว
3. **Date separator**: pill กลางจอ (เช่น "4 กันยายน") ทุกครั้งที่ข้ามวัน — ใช้ `var(--wyn-surface)` เป็นพื้น
   `var(--wyn-text-secondary)` เป็นตัวหนังสือ ขนาดเล็ก ไม่ใช้สีใหม่
4. **Timestamp บน tap**: เอา `<time>` ที่ปัจจุบันแสดงถาวรใต้ทุก bubble (`.message-bubble time`, opacity .65)
   ออกจาก default state — ย้ายไปแสดงตอนแตะ bubble แทน (2 วินาทีแล้วหาย ตาม §6) **นี่คือจุดที่ตัดความรกที่สุด
   ในภาพที่ Founder ส่งมา** — ปัจจุบัน timestamp ขนาดเล็กใต้ทุกบับเบิลทำให้ดูรกเมื่อมีข้อความเยอะ
   **ข้อควรระวัง**: bubble ของตัวเอง (`.message-row.mine .message-bubble`) ตอนนี้มี `onClick` ทำหน้าที่
   toggle ปุ่มลบอยู่แล้ว (PR #498, deploy แล้ว) — ต้องรวม 2 พฤติกรรมนี้ในแฮนเดลเลอร์เดียว: แตะ bubble ของ
   ตัวเอง = แสดงทั้งปุ่มลบ**และ**timestamp พร้อมกัน (ไม่ใช่ 2 ระบบแยกที่แย่งกัน) ส่วน bubble ของอีกฝ่าย (ที่
   ไม่มี delete) แตะแล้วโชว์แค่ timestamp เฉยๆ
5. **Read receipt**: ไอคอนเล็กใต้ bubble ข้อความ**ส่งออกล่าสุดเท่านั้น** (ไม่ใช่ทุก bubble) — ส่ง/อ่านแล้ว
   ใช้ checkmark ตาม §7 ของ spec — เว็บมี `mark_conversation_read` RPC + `conversations` ใน
   `supabase_realtime` publication อยู่แล้ว (พอร์ตมาจาก Flutter, `wyn-031-chat-message-grouping-bubble-spec.md`
   §10) เว็บแค่ต้อง subscribe realtime ต่อแถว conversation ของอีกฝ่ายเพื่ออัปเดต receipt แบบ live (ปัจจุบัน
   `ConversationInner` มี `refresh()` callback อยู่แล้ว เพิ่มแค่ subscription ใหม่)

**Interactions**: คงพฤติกรรมเดิมทั้งหมด (tap bubble ตัวเอง → toggle ลบ, composer เดิม, image picker เดิม) —
เพิ่มแค่ tap → timestamp reveal (ข้อ 4) ตามด้านบน

**States**: เพิ่ม 1 state ใหม่ที่ยังไม่มี — "sending" ต้องมี optimistic bubble ที่แยกแยะได้จาก "sent" (ปัจจุบัน
มี `message.pending` class อยู่แล้ว `is-pending` — ใช้ต่อได้เลย ไม่ต้องสร้างใหม่ แค่เพิ่ม icon สถานะเล็กๆ ตาม
§7 ของ spec ใต้ bubble สุดท้ายที่ pending)

**Responsive Behavior**: ไม่เปลี่ยน `.message-composer`/`safe-area-inset-bottom` ที่แก้ไปแล้วใน PR #498 — คง
ตำแหน่ง fixed เดิม ทดสอบ 3 project เดิม (`webkit-iphone`/`chromium-android`/`chromium-desktop`)

**Accessibility**: แต่ละ bubble ต้องมี label รวม (ผู้ส่ง+เวลา+เนื้อหา) แม้ timestamp จะไม่โชว์ถาวรบนจอ — ใช้
`aria-label` ซ่อนไว้บน `.message-bubble` เดิม (มิเรอร์ Flutter's `Semantics` ตาม spec เดิม) touch target ของ
bubble ที่กดได้ (mine) ต้องยัง ≥44px แนวตั้ง (DS-008) — bubble เดี่ยวสั้นๆ (เช่น "ok") ต้องมี min-height
บังคับแม้ padding เดิมจะทำให้เล็กกว่า 44px ได้ในทางทฤษฎี

**Design Rules**: ห้ามใช้ Cyan/Rainbow ในหน้าแชท (ยืนยันซ้ำจาก `wyn-031-chat-1to1.md`: "ห้ามใช้ใน Chat แม้แต่
จุดเดียว ไม่มีข้อยกเว้น") ทุก token ใหม่ที่อ้างในเอกสารนี้ต้องมาจาก `--wyn-*` ที่มีอยู่แล้วเท่านั้น ไม่ประดิษฐ์สี
ใหม่ ไม่เพิ่มเงา/gradient/liquid-glass (ต้องห้ามตาม design-principles.md แม้เอกสารนั้นจะ superseded เรื่องสี
ไปแล้ว แต่กติกา liquid-glass ไม่เคยถูกยกเลิก)

---

## Handoff

**ลำดับให้ AI Coding**:
1. `app/phase3.css` — ปรับ `.chat-row`/`.chat-inbox` (Screen 1: spacing, unread dot, header weight)
2. `app/phase3.css` — เพิ่ม dynamic grouping spacing + tail radius ให้ `.message-row`/`.message-bubble`
   (Screen 2 ข้อ 1-2) — ต้องคำนวณ "กลุ่มเดียวกันหรือไม่" ใน `chat-routes.tsx` (JS logic ใหม่ ไม่ใช่ CSS ล้วน
   เพราะต้องรู้ sender+timestamp ของ message ก่อน-หลัง) แล้วส่ง class เพิ่ม (เช่น `is-grouped-top`/
   `is-grouped-middle`/`is-grouped-bottom`) ให้ CSS จับ
3. `chat-routes.tsx` — date separator component (Screen 2 ข้อ 3), รวม logic timestamp-reveal เข้ากับ
   `revealedMessageId` ที่มีอยู่แล้ว (ข้อ 4 — **ต้องระวังไม่ทำให้ PR #498 regression**, มี Playwright spec
   `zzz-chat-visual-check` แบบเดียวกับที่ใช้ตรวจ PR #498 เป็นตัวอย่างวิธีตรวจก่อนอยู่แล้ว)
4. `chat-routes.tsx` + schema — read-receipt subscription (Screen 2 ข้อ 5) ใช้ RPC/realtime ที่ Flutter มีอยู่
   แล้ว ไม่ต้องสร้างใหม่ฝั่ง backend
5. รัน regression suite เดิมครบ (`parity`, `pixel-parity-pass-2`, `system-visual-parity`,
   `home-visual-parity`, `content-reference-flow`) + เพิ่ม snapshot ใหม่เฉพาะหน้าแชท (ยังไม่มี
   `chat-visual-parity.spec.ts` แบบถาวรในโปรเจกต์ — แนะนำให้สร้างเป็น regression ถาวรรอบนี้ เพราะหน้าแชทเพิ่ง
   ผ่านการแก้ 2 รอบแล้ว (PR #498) แต่ยังไม่มี snapshot กันการถอยหลังเหมือน `home-visual-parity.spec.ts`)

**ก่อน AI Coding เริ่ม**: ตามกติกาถาวรที่ยืนยันไว้ตอน WYN-141 ("UI ใหม่ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด")
งานนี้เปลี่ยน visual rhythm ของหน้าแชทพอสมควร (grouping/tail/timestamp reveal) แม้จะไม่เปลี่ยนสี — แนะนำให้
AI Design ทำภาพเปรียบเทียบ **ก่อน-หลัง** (static HTML mockup เหมือนที่ WYN-141 ทำ
`design-reference/23-ux-ui-system-preview.svg`) ให้ Founder ดูก่อนอนุมัติ แล้วค่อยส่งต่อ AI Coding — ยังไม่ทำ
ในรอบนี้ รอ Founder ยืนยันว่าต้องการเห็นภาพก่อนหรือให้ AI Coding เริ่มได้เลย

**Task**: `.wyn/tasks/backlog/WYN-159-chat-web-threads-redesign.md` (สร้างพร้อมเอกสารนี้)
