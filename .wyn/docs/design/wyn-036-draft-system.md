# Design — WYN-036 (Draft System)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-036-draft-system.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `CreateDropScreen` (WYN-005/WYN-035) และ Profile tab pattern ที่ WYN-013 วางไว้ (tab "บันทึก" เห็นเฉพาะเจ้าของโปรไฟล์)
> Design system: Cyan `#00C8FF` เป็น primary ตาม DS-001–008 — ไม่มี Rainbow (DS-009) จุดไหนใน task นี้

## ภาพรวม — 4 การตัดสินใจเชิง scope

1. **`drop_drafts` เป็นตารางแยกเต็มรูปแบบ ไม่แตะ `drops`/`home_feed`/`drop_polls` เลย** — Draft ไม่ใช่ content type ของแอปหลัก ไม่ผ่าน Like/Comment/ReDrop/Search/Notification/Report ระบบไหนเลย จุดเดียวที่ Draft "โผล่ให้เห็น" คือ tab "ร่าง" ของเจ้าของเอง — ทำให้ blast radius ต่อระบบเดิมเป็นศูนย์ (regression risk ต่ำสุดในบรรดา 3 task ของ Phase 3)
2. **ทางเข้าเดียวของ Save Draft คือปุ่ม X (+ระบบ back) ผ่าน `PopScope`** — ไม่มีปุ่ม "บันทึกร่าง" แยกบน AppBar เพื่อไม่ให้แย่งพื้นที่กับ "แชร์" — `PopScope` ครอบคลุมทั้งปุ่ม X ที่มีอยู่แล้ว (ไม่ต้องแก้ onPressed ของมันเลย) และปุ่ม back ระบบไปพร้อมกันด้วยกลไกเดียว
3. **Draft ไม่ผ่าน validate เต็มรูปแบบ** — CHECK ของ `drop_drafts` หลวมกว่า `drop_polls`/`create_poll_drop()` เดิม (โครงสร้างเท่านั้น ไม่บังคับครบ/ไม่ซ้ำ) เพราะจุดประสงค์คือเก็บงานที่ยังไม่เสร็จ — validate เต็มรูปแบบเกิดตอนกด "แชร์" จริงเท่านั้น (ใช้ `createDrop()`/`createPollDrop()` เดิมตรงๆ ไม่มี logic ใหม่)
4. **Publish-from-draft ไม่ atomic** — กด "แชร์" จาก Draft ที่เปิดมา = เรียก `createDrop()`/`createPollDrop()` เดิม (สร้าง Drop จริงสำเร็จ) แล้วค่อยลบ Draft แยกต่างหาก (best-effort, ไม่ block ถ้าลบไม่สำเร็จ) — ต่างจาก WYN-035's `create_poll_drop()` ที่ต้อง atomic เพราะมีหลายตารางเกี่ยวพันกันเป็น "หนึ่ง Drop" เดียว ที่นี่ Draft ที่เหลือค้างถ้าลบไม่สำเร็จไม่ใช่ปัญหา data-integrity (แค่ขยะที่เก็บกวาดทีหลังได้)

---

## Screen 1 — Close-Intercept Dialog (ใน `CreateDropScreen`)

**Purpose**: จุดเดียวที่ทำให้ Save Draft/ทิ้ง/ยกเลิกเกิดขึ้น

**Trigger**: กดปุ่ม X (AppBar leading) หรือปุ่ม back ระบบ **เมื่อมีเนื้อหาที่ยังไม่ได้แชร์** (`_hasUnsavedContent`: โหมดรูป = มีรูปเลือกไว้หรือแคปชันไม่ว่าง, โหมดโพล = คำถามไม่ว่างหรือมีตัวเลือกอย่างน้อย 1 ช่องไม่ว่าง) — ไม่มีเนื้อหาเลย → ปิดทันทีไม่ถาม (พฤติกรรมเดิมก่อน task นี้)

**Components**: `AlertDialog` มาตรฐาน — หัวข้อ "บันทึกเป็นร่างก่อนออกไหม?" ปุ่ม 3 ปุ่มแนวนอน: "ทิ้ง" (`TextButton`, สีเทา/error) / "ยกเลิก" (`TextButton`) / "บันทึกร่าง" (`FilledButton`, เด่นสุดเพราะเป็น action ที่แนะนำ)

**Interactions**:
- "บันทึกร่าง" → เรียก `_saveDraft()` (insert ถ้าเป็น Draft ใหม่ / update ถ้าเปิดมาจาก Draft เดิม) → สำเร็จแล้วปิดหน้าจอ (`pop(false)`) — ระหว่างบันทึกปุ่มโชว์ spinner กันกดซ้ำ, ล้มเหลว → snackbar error ไม่ปิด dialog ให้ลองใหม่ได้
- "ทิ้ง" → ปิดหน้าจอทันที (`pop(false)`) ไม่บันทึกอะไร (Draft เดิมถ้ามีอยู่แล้วไม่ถูกแตะเลย)
- "ยกเลิก" → ปิด dialog เฉยๆ กลับไปหน้า Create Drop เดิมต่อ

**States**: ระหว่างกำลัง "แชร์" อยู่ (`_isSharing == true`) ปุ่ม X ไม่ทำงาน (มิเรอร์พฤติกรรมเดิมที่ปุ่มอื่นๆ ก็ disabled ระหว่าง sharing)

---

## Screen 2 — Create Drop รับ Draft เดิม (Continue Editing)

**Purpose**: เปิดหน้า Create Drop เดิม prefill ด้วยเนื้อหา Draft

**Components**: ไม่มีหน้าจอใหม่ — `CreateDropScreen` รับ optional param `draft` (nullable `DropDraft`) เพิ่ม prefill ตอน `initState`:
- โหมดรูป (ถ้า `draft.imageUrl != null`): พื้นที่รูปแสดง `Image.network(draft.imageUrl)` แทน placeholder เดิม (แตะเพื่อเปลี่ยนรูปได้ปกติ — เปลี่ยนแล้วค่อย upload ใหม่ตอนบันทึก/แชร์จริง)
- โหมดโพล (ถ้า `draft.pollOptions != null`): `_mode = poll`, เติม `_pollOptionControllers` ตาม `draft.pollOptions` (ไม่บังคับครบ 2 — อาจมีแค่ 1 ช่องถ้า Draft ยังไม่ครบ), `_pollDurationDays = draft.pollDurationDays ?? 1`
- แคปชัน/คำถาม: เติมจาก `draft.caption`
- เก็บ `_draftId = draft?.id` ไว้ใน state — ใช้ตัดสินว่าบันทึกร่างซ้ำเป็น insert หรือ update

**Interactions**: กด "แชร์" (ผ่าน validate เต็มรูปแบบเหมือนเดิมทุกจุด ไม่มีทางลัด) → สำเร็จแล้วลบ Draft นี้ทิ้ง (ถ้ามี `_draftId`) ก่อน pop กลับ — ลบไม่สำเร็จไม่ block การ pop (Drop จริงถูกสร้างแล้ว สำคัญกว่า)

---

## Screen 3 — Profile Tab "ร่าง" (`ProfileDraftsTab`)

**Purpose**: รายการ Draft ของเจ้าของโปรไฟล์เอง

**ตำแหน่ง**: Tab ที่ 5 ใน `ViewProfileScreen`'s `TabBar` ต่อจาก "บันทึก" เดิม — **เห็นเฉพาะเจ้าของโปรไฟล์เท่านั้น** (`isOwnProfile`, มิเรอร์เงื่อนไขเดียวกับ tab "บันทึก" เป๊ะ — `TabBar`'s `length` เปลี่ยนจาก `isOwnProfile ? 4 : 3` เป็น `isOwnProfile ? 5 : 3`)

**Components**: Grid 3 คอลัมน์เหมือน tab อื่นๆ ทุกจุด (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3)`) — แต่ละช่อง `DraftGridTile` ใหม่: มีรูป → `Image.network`, ไม่มีรูป (โพล) → reuse `PollPlaceholderTile` ตรงๆ ไม่มี like-count scrim เหมือน `DropGridTile` เดิม (Draft ไม่มี engagement ใดๆ ให้แสดง) — เรียงตาม `updated_at` ใหม่สุดก่อน (แก้ไข Draft ล่าสุดต้องขึ้นบนสุด ไม่ใช่ `created_at`)

**Interactions**: แตะ tile → เปิด `CreateDropScreen(draft: ...)` (Screen 2) — long-press → เมนู "ลบร่าง" (มิเรอร์ pattern long-press ของ `DropGridTile`'s report menu) → ยืนยันก่อนลบจริง (reuse `confirmDeleteDrop`/dialog เดิมของ WYN-005 ที่มีอยู่แล้ว เปลี่ยนแค่ label เป็น "ลบร่าง")

**States**: ว่างเปล่า → "ยังไม่มีร่าง เริ่มเขียน Drop แล้วบันทึกไว้ก่อนได้เลย" (มิเรอร์ empty state ของ tab "บันทึก" เดิม)

---

## Handoff (ไปยัง AI Coding)

**Schema ที่แนะนำ**:
1. ตารางใหม่ `drop_drafts` (`author_id`, `image_url` nullable, `caption` nullable [CHECK ความยาวเดียวกับ `drops.caption` ถ้ามีค่า], `poll_options` nullable text[] [CHECK แค่ `array_length <= 4` และแต่ละช่อง `<= 80` ตัวอักษร — **ไม่บังคับ 2 ช่อง/ไม่บังคับ unique** ต่างจาก `drop_polls`], `poll_duration_days` nullable int [CHECK `in (1,3,7)` ถ้ามีค่า], `updated_at`)
2. RLS 4 policy ทั้งหมดผูกกับ `auth.uid() = author_id` เท่านั้น (select/insert/update/delete) — **ไม่มี policy ให้คนอื่นเห็นเลย** ไม่ต้อง piggyback บนตารางอื่นแบบ `redrops`/`drop_polls` เพราะ Draft ไม่มีใครอื่นเกี่ยวข้องด้วยเลย
3. **ไม่ต้อง posting-blocked guard บน insert/update** ของ `drop_drafts` (Product ตัดสินใจแล้วว่าร่างส่วนตัวไม่ใช่การโพสต์) — guard เดิมของ `createDrop()`/`createPollDrop()` ยังทำงานเหมือนเดิมตอนกด "แชร์" จริง ไม่ต้องแก้อะไร
4. ไม่มี RPC ใหม่ — insert/update/delete ตรงบน `drop_drafts` ธรรมดา (upsert pattern เดียวกับที่ `drop_poll_votes` ใช้อยู่แล้ว สำหรับ "save = insert ถ้าไม่มี id / update ถ้ามี")

**Flutter ที่แนะนำ**: model ใหม่ `DropDraft` (ใน `drop/data/`) + เมธอดใหม่บน `DropRepository` (`fetchDrafts()`, `saveDraft()` [upsert คืน id], `deleteDraft()`) — `CreateDropScreen` เพิ่ม optional `draft` param + prefill logic + `PopScope` wrapping + close-intercept dialog — widget ใหม่ `DraftGridTile` (reuse `PollPlaceholderTile` ตรงๆ) — `ProfileDraftsTab` ใหม่ (มิเรอร์ `ProfileSavedTab` เกือบทั้งหมด) — `ViewProfileScreen`'s `TabBar`/`TabBarView` เพิ่ม tab ที่ 5
