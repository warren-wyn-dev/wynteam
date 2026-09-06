# Design — WYN-124 (Club Group Chat)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-124-club-group-chat.md` — อ่านก่อนเริ่ม
> **สถานะ**: Design เสร็จแล้ว (Founder สั่งให้ทำต่อทันที) — **AI Coding ห้ามเริ่มจนกว่า WYN-115–118 จะเสร็จครบ** เหมือนกับ WYN-123
> Design system: ใช้ token จริงชุดเดียวกับที่แก้ไขไว้แล้วใน `.wyn/docs/design/wyn-123-club-channels.md` (Sapphire `#1B3A6B`, light-only, system font — **ไม่ใช่** `ds-001-color-system.md` ที่ล้าสมัย) ไม่ต้องอธิบายซ้ำที่นี่

ทุก component reuse ของเดิมในโค้ด Chat/Club ปัจจุบัน: bubble grouping/spacing/radius ของ `wyn-031-chat-message-grouping-bubble-spec.md`, header shell ของ `ConversationScreen`, action-row pattern ของ `_toggleMute` ใน `club_page.dart` (WYN-116), unread badge shape ของ `RootShell._buildNotificationsIcon`, และ `EmptyStateBlock`/join-prompt placeholder ของ `ClubPostsTab` — ไม่มีจุดใดคิด component ใหม่

---

## Screen 1 — Club Page: ทางเข้าห้องแชท (Tab ใหม่ "แชท")

**Purpose**: ให้สมาชิกเข้าห้องแชทกลุ่มของ Club จากที่เดียวกับที่เข้า Posts/Members/About อยู่แล้ว

**การตัดสินใจ (สำคัญ ต้องอ่านก่อน Coding)**: เพิ่ม tab ที่ 4 ชื่อ "แชท" **ต่อท้ายลำดับเดิม** (โพสต์=0, สมาชิก=1, เกี่ยวกับ=2, **แชท=3**) — **ห้ามแทรกก่อน "สมาชิก"** เพราะ `ClubPage.initialTabIndex` ปัจจุบันถูก hardcode เป็น `1` จากการแจ้งเตือน `club_join_request` (WYN-015) เพื่อเปิดตรงไป tab สมาชิก — ถ้าแทรก tab ใหม่ก่อนตำแหน่งนี้ ดัชนีจะเลื่อนและแจ้งเตือนเดิมจะเปิดผิด tab ทันทีโดยไม่มีใครตั้งใจแก้ ต่อท้ายคือทางเลือกเดียวที่ไม่กระทบของเดิม

**User Flow**: เปิด Club → แตะ tab "แชท" → ถ้าเป็นสมาชิก approved อยู่แล้ว เข้าห้องแชทได้ทันที (ไม่มีการขอสิทธิ์ใดๆ เพิ่ม ตาม R2) → ถ้ายังไม่ได้เข้าร่วม Club เห็น placeholder ชวนเข้าร่วมแทนเนื้อหาแชท (มิเรอร์ `ClubPostsTab`'s placeholder ของ Posts tab เป๊ะ)

**Components**:
- Tab ใหม่: ไอคอน `Icons.forum_outlined` ขนาด 16 (ให้เข้าชุดกับ 3 ไอคอนเดิม: `article_outlined`/`people_outline`/`info_outline`), label "แชท" — สไตล์ active/inactive เหมือน tab อื่นทุกประการ (indicator สี sapphire, label ink/mutedNeutral)
- Unread badge บนไอคอน tab: จุดตัวเลขสีแดง (`colorScheme.error`) มุมขวาบนของไอคอน — **reuse โครงเดียวกับ `RootShell._buildNotificationsIcon` เป๊ะ** (`Positioned(right:-6, top:-4)`, `radiusSm`, ตัวเลขตัด "9+" เมื่อเกิน 9, `onError` สีตัวหนังสือ) ไม่ใช่จุดกลมเปล่าแบบที่ `ChatInboxScreen`'s แถวใช้ — ที่นี่ต้องมีตัวเลข เพราะเป็นตำแหน่งเดียวที่บอกจำนวนข้อความที่ยังไม่อ่านของห้องนี้
- Placeholder สำหรับผู้ยังไม่เข้าร่วม: ข้อความ "เข้าร่วม Club เพื่อดูแชท" + ปุ่ม `OutlinedButton` "เข้าร่วม" — มิเรอร์โครงสร้าง/สไตล์ของ `ClubPostsTab`'s placeholder ที่มีอยู่แล้ว 100%

**Interactions**: แตะ tab = สลับปกติเหมือน tab อื่น ไม่มี long-press พิเศษ

**States**: unread badge หายไปเองเมื่อ mark-as-read (เข้าห้องแล้วเลื่อนถึงข้อความล่าสุด — พฤติกรรมเดียวกับ `mark_conversation_read()` ของ DM เดิม)

**Accessibility**: `Semantics` ของ badge ต้องพูดจำนวนจริง (มิเรอร์ pattern ของ `_buildNotificationsIcon`: "แชท Club มี N ข้อความที่ยังไม่อ่าน")

**Design Rules**: ไม่มีสี/component ใหม่ — ทุกอย่าง reuse ของเดิมที่ระบุไว้ข้างต้น

---

## Screen 2 — Club Chat Room (ห้องแชทกลุ่ม)

**Purpose**: พื้นที่คุยสดของสมาชิก Club ทั้งหมด — ต่างจาก `ConversationScreen` (DM 1-ต่อ-1) ที่จุดเดียวจริงๆ คือ "ผู้ส่งมีได้มากกว่า 1 คน" ทุกอย่างอื่นที่ทำได้ใน DM ทำได้ที่นี่เหมือนกัน (R3)

**User Flow**: เปิดจาก Tab "แชท" (Screen 1) → เห็นประวัติข้อความเรียงเวลา เลื่อนขึ้นเพื่อดูข้อความเก่า → พิมพ์/แนบรูป/ตอบกลับข้อความ/แชร์เนื้อหาส่งเข้าห้องเหมือน DM ทุกประการ → แตะ header (รูป Club+ชื่อ) เพื่อกลับไปหน้า Club (tab โพสต์)

**สิ่งที่เหมือน `ConversationScreen` เป๊ะ (reuse ตรงๆ ไม่ต้องคิดใหม่)**:
- Composer ด้านล่าง (แนบรูป, ช่องพิมพ์, ปุ่มส่ง, แถบ reply-preview เมื่อกำลังตอบกลับข้อความ) — ทั้งหมดตาม R3
- Bubble ของตัวเอง (ขวา, พื้น sapphire เต็ม), bubble ของคนอื่น (ซ้าย, พื้น `surfaceTint` #F1EFE9) — สีเดิมเป๊ะ
- กฎ grouping/spacing/corner-radius ทั้งหมดจาก `wyn-031-chat-message-grouping-bubble-spec.md` (ช่วง 60 วินาที = กลุ่มเดียวกัน, ระยะห่าง 4/16/20px, มุมบุบ 18→4px ด้านที่ชนกัน) — **ไม่เปลี่ยนกฎเดิมแม้แต่ข้อเดียว** แค่เพิ่มกฎใหม่ 1 ข้อ (ดูหัวข้อถัดไป)
- Date separator กลางจอ (พิลล์ "4 กันยายน") เมื่อข้ามวัน — เหมือนเดิม
- เผยเวลาแตะ bubble ~2 วินาที — เหมือนเดิม

**สิ่งที่ต้องเพิ่ม/ตัดจาก DM (เพราะห้องนี้มีคนมากกว่า 2 คน)**:

1. **ชื่อผู้ส่งเหนือกลุ่มข้อความขาเข้า (กฎใหม่ ข้อ 11 ต่อจาก WYN-031's กฎ 10 ข้อเดิม)** — DM ไม่ต้องมีเพราะรู้อยู่แล้วว่า "อีกฝั่ง" คือใครคนเดียว แต่ห้องกลุ่มมีผู้ส่งได้หลายคน จึงต้องแสดงชื่อ **เหนือ bubble แรก (บนสุด) ของทุกกลุ่มข้อความขาเข้า** ทุกกลุ่ม (ไม่ใช่แค่ตอนเปลี่ยนคนส่ง — กฎ grouping เดิมเองก็ตัดกลุ่มใหม่ทุกครั้งที่ห่างกันเกิน 60 วิอยู่แล้ว ดังนั้น "แสดงชื่อทุกกลุ่ม" จึงสมเหตุสมผลโดยไม่ต้องเช็คเงื่อนไขเพิ่ม) — สไตล์ตัวหนังสือ: 12px/600/สี `ink` มิเรอร์ font ของ post-author-name ใน `ClubPostCard` เป๊ะ ไม่ใช่ font ใหม่ — ตำแหน่งเยื้องขวาจาก avatar column เท่ากับ padding ของ bubble ข้างใน (จัดชิดซ้ายเดียวกับ bubble ไม่ใช่ชิดกับ avatar)
2. **Avatar ต่อกลุ่มยังอยู่ที่เดิม** (bubble ล่างสุดของกลุ่ม ตามกฎเดิมข้อ 4 ของ WYN-031) — ไม่เปลี่ยน แค่เพิ่มชื่อไว้บนสุดของกลุ่มเสริมเข้ามา
3. **ตัด Delivery/Read-receipt ทั้งหมดออกจากรอบนี้ (ตัดสินใจของ Design)** — กฎเดิมข้อ 7 ของ WYN-031 ("ติ๊กถูกใต้ bubble สุดท้าย, เทาตอนส่งแล้ว/sapphire ตอนอ่านแล้ว") ใช้ได้เฉพาะกรณี 2 คนที่ตอบ "อ่านแล้วหรือยัง" ได้แบบ binary — กับห้อง N คน คำถาม "อ่านแล้ว" ควรหมายถึง "ทุกคนอ่านหรือยัง" หรือ "กี่คนอ่านแล้ว" ซึ่ง Product spec ไม่ได้กำหนดไว้ (ตาราง read-state ต่อสมาชิกใน R4 มีไว้เพื่อคำนวณ unread badge ของแต่ละคนเท่านั้น ไม่ใช่เพื่อโชว์ "seen by" ให้คนอื่นเห็น) — **ตัดสินใจ: ไม่มี read-receipt UI ใดๆ ในห้องแชทกลุ่มรอบนี้** เหลือแค่สถานะ "กำลังส่ง" (optimistic bubble จางๆ เหมือนเดิม) → "ส่งแล้ว" เฉยๆ ไม่ยกระดับเป็น "อ่านแล้ว" อีกต่อไป — ตรงกับหลัก "คุม complexity" ที่ R7/R8 วางไว้แล้ว
4. **Header ต่างจาก DM**: ไม่ใช่ avatar+ชื่อคน 1 คนที่แตะแล้วไปหน้าโปรไฟล์ แต่เป็น **`ClubAvatar` (widget เดิมจาก Club) + ชื่อ Club + "N สมาชิก" ตัวเล็กใต้ชื่อ** แตะแล้วพา**กลับไปหน้า Club** (tab โพสต์) แทนหน้าโปรไฟล์ — โครง `AppBar` (back chevron ซ้าย, เนื้อหาตรงกลาง, "..." ขวา) เหมือนเดิมทุกจุด เปลี่ยนแค่เนื้อหาตรงกลาง
5. **เมนู "..." ต่างจาก DM**: DM มี mute/block/report/ดูโปรไฟล์ (4 อย่าง เพราะเป็นความสัมพันธ์ 2 คน) — ห้องกลุ่มมีแค่ **1 แถว: "ปิด/เปิดการแจ้งเตือนห้องแชทนี้"** (mute เฉพาะห้องแชท ตาม R6, **แยกอิสระ**จาก mute โพสต์ของ Club เดียวกันที่มีอยู่แล้วในเมนู "..." ของ `ClubPage` เอง จาก WYN-116) — ใช้ `ActionSheetRow` ไอคอน `notifications_off_outlined`/`notifications_outlined` แบบเดียวกับ `_toggleMute` ของ `club_page.dart` เป๊ะ (โค้ดคนละจุดกัน แต่หน้าตา/พฤติกรรมเหมือนกัน) — **ไม่มี block/report ในเมนูนี้** (ดูหมายเหตุท้ายเอกสาร)

**States**: ห้องยังไม่มีข้อความเลย (Club ใหม่/ยังไม่มีใครคุย) → ใช้ `EmptyStateBlock` มาตรฐาน: ไอคอน `Icons.forum_outlined` ในวงกลม tint, หัวข้อ "เริ่มบทสนทนาของ [ชื่อ Club]", คำอธิบาย "ส่งข้อความแรกให้เพื่อนสมาชิกในคลับ"

**Responsive Behavior**: เหมือน `ConversationScreen` ทุกประการ (list เลื่อน, composer ติดล่าง, คีย์บอร์ดดันขึ้นปกติ)

**Accessibility**: ชื่อผู้ส่งเหนือกลุ่ม (ข้อ 1) ต้องรวมอยู่ใน `Semantics` label ของ bubble แรกของกลุ่มนั้น (เช่น "ข้อความจาก [ชื่อ]: ...") ไม่ใช่ประกาศแยกลอยๆ — มิเรอร์วิธีที่ `ClubPostCard` รวม author name เข้ากับ semantics ของการ์ดโพสต์

**Design Rules**: ทุกสี/spacing/radius มาจาก token เดิม ไม่มีจุดใหม่

---

## หมายเหตุถึง Product/Coding (จุดที่ Design เจอแล้วต้องยืนยันก่อน Coding เริ่มจริง)

1. **WYN-122's chat lockdown (ปิดแชท 1-ต่อ-1 ชั่วคราว เหลือ @warren↔@wynos_online) กินขอบเขตถึง Club Group Chat หรือไม่?** — production ตอนนี้ยัง `enabled: true` อยู่จริง กลไกเดิม (`chat_pair_allowed(a,b)`) ผูกกับคู่ 2 คน ใช้กับห้องกลุ่มไม่ได้โดยโครงสร้าง (ตาม R8 ที่ตั้งใจแยกตารางไว้แล้ว) — **ยังไม่มีคำตอบว่า Founder ต้องการให้ Group Chat เปิดให้ทุกคนใช้ทันทีตอน deploy หรือควรถูกจำกัดแบบเดียวกับ DM ตอนนี้ด้วย** ต้องถาม Founder ก่อน Coding จริง ไม่ใช่เดาเอาเอง
2. **การรายงาน/ควบคุมเนื้อหาในห้องแชทกลุ่ม (moderation)** — DM เดิมมี report/block ต่อคู่สนทนา แต่ห้องกลุ่มไม่มีกลไกเทียบเท่าในดีไซน์นี้ (ตัด block ออกเพราะไม่เข้ากับโครง "สมาชิก Club" — จะ block ใครสักคนแต่ยังอยู่ใน Club เดียวกันไม่สมเหตุสมผล) — การรายงานข้อความที่ไม่เหมาะสมในห้องแชทยังไม่มีทางเข้าในรอบนี้ (Club ทั้งก้อน report ได้อยู่แล้วจากเมนูเดิมของ `ClubPage` แต่ไม่ใช่ระดับข้อความ) — ถ้า Founder ต้องการ per-message report/moderation ต้องเปิดเป็นงานเพิ่มแยกต่างหาก ไม่ใช่ implicit scope ของ WYN-124 นี้

## Handoff

ส่งต่อ **AI Coding** — **ห้ามเริ่มจนกว่า WYN-115–118 จะเสร็จครบ** เหมือนกับ WYN-123 เมื่อถึงคิวจริง:
1. ยืนยัน 2 จุดใน "หมายเหตุถึง Product/Coding" ข้างต้นกับ Founder ก่อนเขียน schema/RLS จริง
2. อ่านโค้ด Chat (`conversation_screen.dart`/`chat_repository.dart`) และ Club (`club_page.dart`) ปัจจุบันใหม่อีกรอบตอนถึงคิว ไม่ใช่เชื่อโครงสร้างจากตอนเขียนเอกสารนี้เพียงอย่างเดียว
3. ไฟล์ใหม่ที่คาดว่าต้องมี: `club_chat_room_screen.dart` (มิเรอร์ `conversation_screen.dart`), repository ใหม่ (`ClubChatRepository` หรือขยาย `ClubRepository`) สำหรับห้อง/ข้อความ/read-state/mute ของ group chat — **ไม่แก้ `chat_repository.dart`/`conversation_screen.dart` เดิมแม้แต่บรรทัดเดียว** ตาม R8
4. `club_page.dart`: เพิ่ม tab "แชท" เป็น**ลำดับที่ 4 ต่อท้ายเท่านั้น** (ห้ามแทรกก่อน "สมาชิก" — ดูเหตุผลที่ Screen 1)

หลัง Coding เสร็จ → ส่งต่อ **AI QA & Security** ตามลำดับ workflow ปกติ
