# Design Spec — WYN-008: Follow system

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-008-follow-system.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: ปุ่ม Follow UI-only ใน `PopClipView` (WYN-006, `.wyn/docs/design/wyn-006-pop.md`), header ของ `DropDetailScreen` (WYN-005), `ViewProfileScreen` (WYN-003)

## ทิศทางภาพรวม: Follow เป็นส่วนขยายของ header ที่มีอยู่แล้ว ไม่ใช่ component ใหม่แยกต่างหาก

Follow ไม่ใช่หน้าจอใหม่ทั้งหมด — เป็นการเติมปุ่มเข้าไปใน header ที่มีอยู่แล้วของ Drop/Pop (ข้าง avatar+ชื่อผู้เขียน) บวกกับหน้าจอใหม่เล็ก ๆ 2 อย่าง (Followers list, Following list) ที่ใช้โครงสร้างเดียวกัน หลักการคือ **reuse ตำแหน่ง/สไตล์ปุ่ม Follow ที่มีอยู่แล้วใน `PopClipView` ให้ตรงกันทั้ง Drop และ Pop** — ผู้ใช้ต้องรู้สึกว่าเป็นปุ่มเดียวกันไม่ว่าจะเจอที่ไหนในแอป

---

## Screen 1: ปุ่ม Follow ใน `DropDetailScreen` header (เพิ่มใหม่)

Purpose: ให้ผู้ใช้ Follow/Unfollow เจ้าของ Drop ได้ตรงจากหน้ารายละเอียด เหมือนที่ทำได้ใน Pop อยู่แล้ว

Components:
- ในแถว header เดิม (`AvatarCircle` + ชื่อผู้เขียน) เพิ่มปุ่ม Follow ระหว่าง `Expanded(ชื่อ)` กับตำแหน่งปุ่มลบเดิม — **mirror ตำแหน่ง/สไตล์ของปุ่ม Follow ใน `PopClipView` เป๊ะ**: `OutlinedButton` ทรงเดียวกัน สูง ~28-32px, padding แนวนอนกระชับ, ข้อความ "ติดตาม" (ยังไม่ได้ follow) / "กำลังติดตาม" (follow อยู่แล้ว) — ต่างจาก Pop แค่สีเท่านั้น (Pop ใช้สีขาวบนพื้นวิดีโอมืด, Drop ใช้สี Primary Blue บนพื้นขาวเพราะ `DropDetailScreen` เป็น background สว่างตามปกติ ไม่มี scrim มืดแบบ Pop)
- `if (isOwnDrop)`: แสดงปุ่มลบเดิมเหมือนก่อนหน้า **ไม่แสดงปุ่ม Follow**
- `if (!isOwnDrop)`: แสดงปุ่ม Follow **ไม่แสดงปุ่มลบ** (ปุ่มลบมีความหมายเฉพาะเจ้าของเท่านั้นอยู่แล้ว — สอง state นี้ไม่มีทางซ้อนกัน mutually exclusive เหมือนที่ `PopClipView` ทำอยู่แล้ว)

Interactions:
- กด Follow → optimistic UI เปลี่ยนเป็น "กำลังติดตาม" ทันที เรียก backend ตามหลัง (pattern เดียวกับ Like/Save — ถ้า backend fail ให้ revert กลับพร้อม fail แบบเงียบเหมือน Like/Save ที่มีอยู่แล้ว ไม่ต้องมี error dialog พิเศษ)
- โหลดหน้าครั้งแรก → ต้องรู้สถานะ Follow จริงจาก DB ก่อนแสดงปุ่ม (ไม่ default เป็น "ติดตาม" เสมอเหมือนที่ `PopClipView` เดิมทำ — นี่คือจุดที่ Product ระบุไว้ชัดว่าต้องแก้จากของเดิม)

Accessibility: ปุ่ม Follow มี semantics label ประกาศสถานะปัจจุบันเสมอ (เช่น "กำลังติดตาม กดเพื่อเลิกติดตาม" / "กดเพื่อติดตาม") — ตาม pattern เดียวกับ Like/Save ทุกปุ่มในแอป (นี่คือจุดที่ QA รอบ 1 ของ WYN-006 เคยพบว่าปุ่ม Follow เดิมขาด Semantics label ไปเป็น Minor finding — รอบนี้ต้องมีตั้งแต่แรก ไม่ให้พลาดซ้ำ)

---

## Screen 2: ปุ่ม Follow ใน `PopClipView` (แก้จาก UI-only เป็นของจริง)

ไม่มีการเปลี่ยน visual/ตำแหน่งใด ๆ จาก WYN-006 เดิม — เปลี่ยนแค่ behavior (ผูก backend จริง, โหลดสถานะจริงตอนเปิดคลิปแทนที่จะ default เป็น false เสมอ) ตาม Interactions/Accessibility เดียวกับ Screen 1 ด้านบน

---

## Screen 3: Followers / Following List (หน้าจอใหม่)

Purpose: แสดงรายชื่อผู้ติดตาม/กำลังติดตาม แบบเรียบง่ายตามที่ Product ตัดสินใจไว้ (ไม่มี routing ไปโปรไฟล์คนอื่นในรอบนี้)

User Flow: เปิด `ViewProfileScreen` ของตัวเอง → แตะจำนวน "ผู้ติดตาม" หรือ "กำลังติดตาม" → เปิดหน้า list เต็มจอ → เลื่อนดูรายชื่อ → กด back กลับมาที่โปรไฟล์

Components:
- `AppBar` มี title แยกตามโหมด: "ผู้ติดตาม" (Followers) หรือ "กำลังติดตาม" (Following) — **ใช้หน้าจอเดียวกัน สลับ mode ผ่าน parameter** ไม่ใช่สองไฟล์แยกกัน (โครงสร้าง/state เหมือนกันทุกอย่าง ต่างกันแค่ query ไหนถูกเรียกและ title ไหนถูกแสดง)
- แต่ละแถวใน list: `AvatarCircle` (ใช้ component เดิม) + display name (หรือ username ถ้าไม่มี display name — ใช้ getter `nameOrUsername`/`authorNameOrUsername` เดิมที่มีอยู่แล้วทั่วแอป) + `@username` เป็น subtitle เล็กจางกว่า — โครงสร้างแถวเดียวกับ `ListTile` มาตรฐาน ไม่ต้อง custom widget ใหม่
- **แถวไม่มี ripple/InkWell ที่ตอบสนองการแตะเลย** (ไม่ใช่แตะแล้วไม่มีอะไรเกิดขึ้นแบบเงียบ ๆ — ถ้าไม่มี tap target ให้ user คาดหวัง ก็ไม่ควรมี visual affordance ของปุ่มที่กดได้ นี่คือความต่างสำคัญจาก Search bar placeholder ของ WYN-007 ที่ตั้งใจให้แตะได้แล้วพาไปหน้า "เร็ว ๆ นี้" — Followers/Following list ไม่มีหน้าปลายทางให้ไปเลยในรอบนี้ ดังนั้นควรสื่อสารด้วยการ "ไม่ทำให้แถวดูเหมือนกดได้" แทนที่จะมี tap ที่ไม่ทำอะไร)
- Loading state: spinner กลางจอ
- Empty state: ข้อความเชิญชวนแยกตาม mode — Followers ว่าง: "ยังไม่มีใครติดตามคุณเลย" / Following ว่าง: "คุณยังไม่ได้ติดตามใครเลย ลองกดติดตามจาก Drop หรือ Pop ที่ชอบดูสิ"
- Error state: ข้อความ error + ปุ่มลองใหม่ (pattern เดียวกับทุกหน้าที่มีอยู่แล้ว)
- Infinite scroll ถ้ารายชื่อยาว (pattern เดียวกับ feed อื่น ๆ — `pageSize` เดียวกับที่ใช้ทั่วแอป)

Accessibility: แต่ละแถวมี semantics label รวม เช่น "ผู้ใช้ {display name} ยูสเซอร์เนม {username}" (ไม่ประกาศว่าเป็นปุ่ม เพราะไม่ใช่ — ตรงตามหลักการข้างต้นว่าไม่ทำให้ดูเหมือนกดได้)

---

## Screen 4: จำนวน Followers/Following ใน `ViewProfileScreen` (แก้ไขหน้าเดิม)

Components:
- เพิ่ม `Row` ใหม่ใต้ `@username` เดิม เหนือปุ่ม "แก้ไขโปรไฟล์" — สอง tap target วางคู่กันกลางจอ: **"{จำนวน} ผู้ติดตาม"** และ **"{จำนวน} กำลังติดตาม"** คั่นด้วยช่องว่าง (ไม่ต้องมีเส้นแบ่ง/divider — สไตล์เรียบตาม design principles) ตัวเลขหนา (`fontWeight: bold` หรือ `titleMedium`) ข้อความกำกับ (ผู้ติดตาม/กำลังติดตาม) น้ำหนักปกติ สีรอง (`colorScheme.outline`) — mirror สไตล์ตัวเลขที่ Drop/Pop interaction row ใช้แสดง like/comment count อยู่แล้ว (ตัวเลขนำหน้า ข้อความคำอธิบายตามหลัง)
- ทั้งสอง tap target ห่อด้วย `InkWell`/`Semantics(button: true)` ต่างจาก Screen 3 เพราะจุดนี้**มี**ปลายทางจริง (เปิด Screen 3) — แตะ "ผู้ติดตาม" เปิด Followers list, แตะ "กำลังติดตาม" เปิด Following list

Interactions:
- Follow/Unfollow คนใหม่จากที่ไหนก็ตามในแอป (Drop/Pop detail) แล้วกลับมาที่ `ViewProfileScreen` → ตัวเลข Following ต้อง sync ทันที (reload เมื่อกลับมาที่หน้านี้ pattern เดียวกับที่ `HomeFeedScreen._openDrop`/`_openPop` reload หลัง pop กลับมา — ไม่ต้อง real-time subscription ในรอบนี้)

States: Loading/Loaded/Error ใช้ pattern เดียวกับที่ `ViewProfileScreen` มีอยู่แล้ว (ตัวเลข Followers/Following โหลดพร้อมกับ profile fetch เดิม ไม่ใช่ query แยกที่ทำให้เกิด loading state ซ้อนกันหลายจุด)

Responsive Behavior: เหมือนเดิมทั้งหมด (mobile-first, คอลัมน์เดียว)

Design Rules:
- **ห้าม Liquid Glass บนปุ่ม Follow** — ใช้ `OutlinedButton` เรียบตาม design system ที่มีอยู่แล้ว ไม่มีพื้นผิวเบลอ (สอดคล้องกับกติกาเดียวกับที่ WYN-006 ใช้กับ play icon overlay)
- **ปุ่ม Follow ต้องมีสไตล์เดียวกันทุกที่ที่ปรากฏ** (Drop/Pop) ต่างกันได้แค่สี (ให้เข้ากับพื้นหลังมืด/สว่างของแต่ละบริบท) — ไม่ใช่ redesign ใหม่ทุกจุดที่ใช้

Handoff: AI Coding — เพิ่มตาราง `follows` ใหม่ใน `supabase/schema.sql` (`follower_id`, `following_id`, `created_at`, `CHECK (follower_id <> following_id)` ป้องกัน self-follow ระดับ DB, RLS ตาม pattern เดียวกับตารางอื่น ๆ ที่ผ่าน QA มาแล้ว — select เปิดให้ authenticated ทุกคนอ่านได้ [เพื่อนับ follower/following ของใครก็ได้], insert/delete จำกัดเฉพาะเจ้าของ `follower_id` เท่านั้น) สร้าง `FollowRepository` ใหม่ (ใช้ร่วมกันทั้ง Drop/Pop ตามที่ Product ระบุ ไม่ duplicate logic), เพิ่มปุ่ม Follow เข้า `DropDetailScreen`, เชื่อมปุ่มเดิมใน `PopClipView` ให้ทำงานจริง, สร้างหน้าจอ Followers/Following list ใหม่ (mode พารามิเตอร์เดียว ไม่แยกไฟล์), แก้ `ViewProfileScreen` เพิ่มจำนวน+tap target ต้อง QA & Security ตรวจสอบก่อนอนุมัติ — เน้นตรวจ self-follow ถูกกันทั้ง UI และ DB, double-tap safety ของปุ่ม Follow, regression กับ Drop/Pop/Profile เดิม (ต้องยังทำงานปกติ)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement ตาม Screen 1-4 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-008-follow-system.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
