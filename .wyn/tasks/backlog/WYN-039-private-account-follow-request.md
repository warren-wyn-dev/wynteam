# Product Task — WYN-039

Status: backlog
Owner: AI Product Manager

Feature: Private Account + Follow Request

Goal: ให้ผู้ใช้เลือกได้ว่าบัญชีตัวเองเป็น Public (ใครก็ตามดูเนื้อหาได้ทันที — พฤติกรรมปัจจุบันของทั้งระบบ) หรือ Private (ต้องส่งคำขอติดตามและรอเจ้าของบัญชีอนุมัติก่อนถึงจะเห็นเนื้อหาได้) — task สุดท้ายของ Phase 3 (Drop Enhancement) ตาม `.wyn/docs/product/wyn-v1.0.0-roadmap.md`, Master Spec section 10 "PRIVATE ACCOUNT": "เลือก Public หรือ Private — Private: Follow Request → User Approve/Reject" และ section 11 "FOLLOW SYSTEM": "Follow, Unfollow, **Follow Request, Accept, Reject**, Remove Follower, Following List, Followers List"

Target User: ผู้ใช้ (โดยเฉพาะ Gen Z ตาม WYN Mission เรื่องความเป็นส่วนตัว) ที่ต้องการควบคุมว่าใครเห็นเนื้อหาของตัวเองได้บ้าง แทนที่จะเปิดเผยต่อผู้ใช้ที่ login ทุกคนแบบตอนนี้

Problem: ตอนนี้ **ทุกบัญชีเป็น Public บังคับ ไม่มีทางเลือกเลย** — `drops`/`pops`' SELECT policy คือ "ใครก็ตามที่ login แล้วดูได้หมด" (ยกเว้นแค่ block/soft-delete) ไม่มีคอลัมน์ privacy ใดๆ บน `profiles` เลย — และระบบ Follow (WYN-008) เป็น **insert ตรงจาก client ทันที ไม่มีขั้นตอนขออนุมัติเลย** (`follows`' INSERT policy อนุญาต `auth.uid() = follower_id` ตรงๆ, `FollowRepository.toggleFollow()` insert/delete ตรง) — กด Follow ปุ๊บติดตามทันทีไม่มี "รออนุมัติ" เกิดขึ้นได้เลยในสถาปัตยกรรมปัจจุบัน

Requirements:

**Account Type (Settings)**
- เพิ่มตัวเลือก "บัญชีส่วนตัว" (Private Account) ใน Settings ภายใต้กลุ่ม Privacy — ค่าเริ่มต้น **Public** (พฤติกรรมเดิมของทุกบัญชีที่มีอยู่แล้ว ไม่กระทบใครโดยไม่ได้ตั้งใจ)
- เปลี่ยนจาก Public → Private: **ไม่กระทบ Follower เดิมที่มีอยู่แล้วเลย** (ยังเห็นเนื้อหาได้ต่อเนื่องเหมือนเดิม) — มีผลแค่กับ Follow ใหม่นับจากนี้เท่านั้น
- เปลี่ยนจาก Private → Public: **คำขอติดตามที่ค้างอยู่ทั้งหมดของบัญชีนี้ถูกอนุมัติอัตโนมัติทันที** (ผู้ใช้เลือกเปิดเป็น Public แปลว่ายินยอมให้ทุกคนเห็นแล้ว ไม่มีเหตุผลให้คำขอเก่าค้างรออนุมัติต่อ)

**Follow Request flow**
- กด Follow บัญชี **Public** → ติดตามทันที เหมือนเดิมทุกจุด (ไม่เปลี่ยนพฤติกรรมเดิมเลย)
- กด Follow บัญชี **Private** → สร้าง "คำขอติดตาม" (ไม่ใช่ Follow จริงทันที) ปุ่มเปลี่ยนข้อความเป็น "ขอแล้ว" (กดซ้ำ = ยกเลิกคำขอ ปุ่มกลับเป็น "ติดตาม")
- เจ้าของบัญชี Private เห็นรายการ "คำขอติดตาม" ใหม่ พร้อมปุ่ม **ยอมรับ**/**ปฏิเสธ** ต่อรายการ (มิเรอร์ Message Request ของ WYN-032 ทุกจุดที่ทำได้ — Accept/Reject ไม่ใช่ Accept/Delete/Block/Report เพราะ Follow Request ไม่มีเนื้อหาข้อความให้ Report/Block แยกจากบัญชีเลย ถ้าอยากบล็อกคนขอ ใช้ระบบ Block เดิม WYN-027 ได้อยู่แล้วโดยไม่ต้องมีทางลัดใหม่)
- ยอมรับ → ผู้ขอกลายเป็น Follower จริง เห็นเนื้อหาได้ทันที — **ไม่ส่ง notification แจ้งผู้ขอว่าได้รับการอนุมัติ** (มิเรอร์การตัดสินใจเดียวกับ WYN-032's `accept_message_request()` ที่ไม่แจ้งผู้ขอเช่นกัน — ผู้ขอจะเห็นเองว่าปุ่ม "ขอแล้ว" เปลี่ยนเป็น "กำลังติดตาม" เมื่อกลับมาดูอีกครั้ง)
- ปฏิเสธ → ลบคำขอทิ้งไปเลย (ไม่มี "dismissed" state ค้างไว้) ผู้ขอไม่ได้รับแจ้งว่าถูกปฏิเสธ (มิเรอร์ UX ที่ผู้ใช้คุ้นเคยจากแพลตฟอร์มอื่น) ขอใหม่ได้อีกในอนาคตถ้าต้องการ

**การมองเห็นเนื้อหา (Content Visibility)**
- บัญชี Private: **เฉพาะเจ้าของบัญชีเองและ Follower ที่ได้รับอนุมัติแล้วเท่านั้น** เห็น Drop/Pop ของบัญชีนั้นได้ — คนอื่นทุกคน (รวมคนที่ส่งคำขอไปแล้วแต่ยังไม่ได้รับอนุมัติ) เห็นไม่ได้ทั้ง Home Feed/Search/Profile grid/ReDrop ของเนื้อหานั้น — เหมือนกฎเดียวกับ Block (WYN-027)/Soft Delete (WYN-037) ที่ทำมาแล้ว
- **Comment ของบัญชี Private ที่ไปคอมเมนต์ในเนื้อหาของคนอื่น (บัญชี Public) ไม่ถูกซ่อน** — Private Account ควบคุมแค่การมองเห็น "เนื้อหาของตัวเอง" ไม่ใช่ "กิจกรรมของตัวเองบนเนื้อหาคนอื่น" (มิเรอร์พฤติกรรมที่ผู้ใช้คุ้นเคยจากแพลตฟอร์มอื่น — คอมเมนต์บนโพสต์ Public ของคนอื่นยังเป็น Public เสมอไม่ว่าคนคอมเมนต์จะเป็น Private หรือไม่)
- **Comment ของคนอื่นที่คอมเมนต์บน Drop/Pop ของบัญชี Private ต้องถูกซ่อนไปด้วยเมื่อ Drop/Pop นั้นถูกซ่อน** (คนที่ไม่ใช่ Follower มองไม่เห็น comment thread ทั้งหมดของ Drop ที่ตัวเองมองไม่เห็นตัว Drop อยู่แล้ว) — เป็นช่องทางอ้อมแบบเดียวกับที่ WYN-037 เคยพบและปิดไปแล้วสำหรับ soft-delete ต้องปิดซ้ำอีกรอบสำหรับ privacy (ดู Recommendation)
- **โปรไฟล์ (username/ชื่อ/avatar/bio/จำนวน Follower-Following) ยังเห็นได้เสมอแม้บัญชีเป็น Private และยังไม่ได้รับอนุมัติ** (ค้นหาเจอ, กด Follow ได้) — สิ่งที่ซ่อนคือ **เนื้อหา** (Drop/Pop grid) และ **รายชื่อ** Follower/Following (ป้องกันไม่ให้คนแปลกหน้าไล่ดูว่าใครติดตามใครของบัญชีที่ตั้งใจปิดตัวเอง) ไม่ใช่ตัวโปรไฟล์เอง — มิเรอร์พฤติกรรมมาตรฐานที่ผู้ใช้คุ้นเคย

Acceptance Criteria:
- [ ] เปิด Settings → เปิด "บัญชีส่วนตัว" → บัญชีกลายเป็น Private ทันที Follower เดิมยังเห็นเนื้อหาได้ปกติไม่กระทบ
- [ ] ผู้ใช้ A (ยังไม่ได้ follow) กด Follow บัญชี Private ของ B → ปุ่มเปลี่ยนเป็น "ขอแล้ว" ทันที ไม่ใช่ "กำลังติดตาม" — ตรวจสอบด้วย SQL ว่า `follows` row สร้างด้วย status pending จริง ไม่ใช่ active
- [ ] A เห็น Drop/Pop grid ของ B ว่างเปล่า/ถูกล็อก จนกว่า B จะอนุมัติ — ตรวจสอบด้วย SQL โดยตรงว่า role ของ A query ตาราง `drops`/`pops` ของ B ไม่เห็นแถวเลย
- [ ] B เปิดหน้า "คำขอติดตาม" เห็นคำขอของ A พร้อมปุ่มยอมรับ/ปฏิเสธ
- [ ] B กดยอมรับ → A กลายเป็น Follower จริง เห็นเนื้อหาของ B ได้ทันที ปุ่มของ A เปลี่ยนเป็น "กำลังติดตาม" เมื่อ refresh — ไม่มี notification ไปหา A ว่าได้รับการอนุมัติ
- [ ] จำลองอีกคำขอใหม่จาก C แล้ว B กดปฏิเสธ → คำขอหายไปจากรายการ, C ยังไม่ใช่ Follower, C ขอใหม่ได้อีกในอนาคต
- [ ] A ยกเลิกคำขอของตัวเอง (กด "ขอแล้ว" ซ้ำ) ก่อน B ตอบ → คำขอหายไป, ปุ่มกลับเป็น "ติดตาม"
- [ ] B เปลี่ยนบัญชีกลับเป็น Public ขณะมีคำขอค้างอยู่ → คำขอทั้งหมดกลายเป็น Follower จริงทันทีอัตโนมัติ (ตรวจด้วย SQL)
- [ ] Follower/Following count และ list ของบัญชี Private **นับ/แสดงเฉพาะ status active เท่านั้น** ไม่รวมคำขอที่ยังไม่ได้รับอนุมัติ
- [ ] คนที่ไม่ใช่ Follower ที่ได้รับอนุมัติ เรียก SELECT ตรงบน `follows`/รายชื่อ Followers-Following ของบัญชี Private **ไม่เห็นรายชื่อ** (แต่ยังเห็นจำนวน/นับได้ตามที่ Product ตัดสินใจให้เห็น — ดู Recommendation ว่า count มาจากไหนถ้าไม่ผ่าน raw SELECT)
- [ ] คอมเมนต์ของบัญชี Private บนเนื้อหา Public ของคนอื่นยังเห็นได้ปกติ (ไม่ถูกซ่อน)
- [ ] คอมเมนต์ของคนอื่นบน Drop/Pop ของบัญชี Private ที่ผู้ดูยังไม่ได้รับอนุมัติ **มองไม่เห็นเลย** (ปิดช่องทางอ้อมมิเรอร์บทเรียน WYN-037)
- [ ] Block (WYN-027) ระหว่าง follower ที่ active/pending อยู่ก่อน → follows row (ทั้ง active/pending) ถูกลบทั้งสองทิศทางเหมือนเดิม (regression ของ `block_user()` เดิมไม่พัง)
- [ ] Regression: Public account (ค่าเริ่มต้น/ส่วนใหญ่ของระบบตอนนี้) ทำงานเหมือนเดิมทุกจุดไม่เปลี่ยนแปลงพฤติกรรมเลย, Drop/Pop/Comment/Like/Save/ReDrop/Poll/View-count เดิมไม่กระทบ, Message Request (WYN-032) เดิมไม่กระทบ (คนละกลไก แต่ทั้งคู่อ้างอิง `follows` — WYN-032's `get_or_create_conversation()` เช็ค `follows` เพื่อ auto-skip message request ต้องเช็คเฉพาะ status='active' เท่านั้น ไม่ใช่ pending)

Dependencies: WYN-008 (Follow system core), WYN-027 (Block — ต้อง compatible กับ pending/active follows ทั้งคู่), WYN-032 (Message Request — ใช้ `follows` เป็นสัญญาณ ต้องอัปเดตให้เช็คเฉพาะ active), WYN-005/006 (Drop/Pop content visibility ต้องขยาย RLS) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P1 — task สุดท้าย (ที่หก) ของ Phase 3 ตามลำดับ Roadmap ต่อจาก WYN-034 ถึง WYN-038 ปิดท้าย Phase 3 ทั้งหมด

Risks:
- **`follows`' INSERT policy ต้องเปลี่ยนจาก raw client insert เป็น RPC-only** เพราะ status (active/pending) ต้องตัดสินใจฝั่ง server จาก `profiles.is_private` ของเป้าหมาย ไม่ใช่ให้ client กำหนดเอง — เป็น breaking change กับ `FollowRepository.toggleFollow()`'s insert path เดิม (delete/unfollow ยังเป็น raw RLS ได้ตามเดิม ไม่มีตรรกะซับซ้อน) ต้องแก้ call site ทั้ง 3 จุดที่ใช้ปุ่ม Follow (`ViewProfileScreen`, `DropDetailScreen`, `PopClipView` — จุดสุดท้ายเป็นโค้ด Pop ที่ไม่มีใครเข้าถึงได้จริงแล้วตั้งแต่ WYN-024 แต่ยัง compile อยู่ ต้องแก้ให้ตรง signature ใหม่ไม่ให้ build พังแม้จะไม่มี UX ใหม่ให้เพิ่มก็ตาม)
- **ไม่มี full Follow-history/audit** (ใครเคยขอ-ถูกปฏิเสธกี่ครั้ง) — เก็บแค่ state ปัจจุบันเหมือน Message Request เดิม ยอมรับ scope เดียวกัน
- **เปลี่ยนบัญชีเป็น Private ไม่ลบ Follower เดิมออกโดยอัตโนมัติ** — ถ้า Founder ต้องการให้ล้าง Follower เดิมด้วยตอนเปลี่ยนเป็น Private (บังคับทุกคนขอใหม่) เป็นพฤติกรรมคนละแบบ ต้องคุยแยกเป็น follow-up เพราะ Master Spec ไม่ได้ระบุชัดและแพลตฟอร์มอื่นที่คุ้นเคยก็ไม่ทำแบบนั้น (คงพฤติกรรมที่ผู้ใช้คาดหวังไว้ก่อน)
- **`profiles.is_private` เป็น column ใหม่ ไม่ใช่ Core Vision/Security Architecture change ที่ต้องขออนุมัติ Founder ก่อน** (เป็น product feature ตรงตาม Master Spec section 10 ที่ Founder ล็อกสเปกไว้แล้ว) — แต่การเปลี่ยน `drops`/`pops`' SELECT policy เป็นการแก้ RLS ของตารางเนื้อหาหลักอีกครั้ง (ครั้งที่ 4 ต่อจาก block/soft-delete/[Pop เดิม]) ยังอยู่ในขอบเขตที่ AI Team ทำได้เองตาม RULES.md (ไม่ใช่ Security Architecture ระดับที่ต้องขออนุมัติ เพราะเป็นการเพิ่ม visibility filter แบบเดียวกับที่ทำมาแล้วซ้ำๆ ไม่ใช่การเปลี่ยนกลไก auth/encryption)

Recommendation:
1. Schema: `profiles` เพิ่ม `is_private boolean not null default false` — RLS ของ `profiles` เอง **ไม่เปลี่ยน** (โปรไฟล์ยังเห็นได้ทุกคนเสมอตามที่ Product ตัดสินใจ)
2. `follows` เพิ่ม `status text not null default 'active' check (status in ('active', 'pending'))` — มิเรอร์ `conversations.status` ของ WYN-031/032 เป๊ะๆ
3. **ลบ INSERT policy ตรงของ `follows` ทิ้ง** แทนที่ด้วย RPC `follow_user(p_following_id uuid)` (SECURITY DEFINER) มิเรอร์ `get_or_create_conversation()`: เช็ค self-follow/block/target มีอยู่จริงเหมือนเดิม (logic เดิมของ INSERT policy ย้ายเข้ามาในนี้) แล้วดู `profiles.is_private` ของเป้าหมาย — `false` → insert `status='active'` + insert notification `'follow'` ทันที (มิเรอร์ trigger เดิม) — `true` → insert `status='pending'` + insert notification `'follow_request'` ใหม่ — ถ้ามี row อยู่แล้ว (ไม่ว่า status ไหน) ให้ raise exception กันเรียกซ้ำ (unfollow ก่อนค่อย follow ใหม่)
4. DELETE policy ของ `follows` **ไม่ต้องเปลี่ยน** (`auth.uid() = follower_id` เดิมพอ ครอบทั้ง unfollow ปกติและ "ยกเลิกคำขอที่ยัง pending" ด้วยปุ่มเดียวกัน ไม่ต้องมี RPC แยก)
5. RPC ใหม่ `accept_follow_request(p_follower_id uuid)`/`reject_follow_request(p_follower_id uuid)` มิเรอร์ `accept_message_request()`/`delete_message_request()` เป๊ะๆ (update status/delete row where `following_id = auth.uid() and follower_id = p_follower_id and status = 'pending'`) — **ไม่ insert notification ใน accept** ตามที่ Product ตัดสินใจไว้
6. `notify_follow()` trigger (AAFTER INSERT บน `follows`) ต้อง branch ตาม `new.status`: `'active'` → insert notification type `'follow'` เหมือนเดิม, `'pending'` → insert type `'follow_request'` ใหม่ — เพิ่ม `'follow_request'` เข้า `notifications_type_check` constraint ด้วยวิธี introspect-แล้ว-drop-แล้ว-recreate แบบเดียวกับที่ WYN-034 เป็นต้นมาใช้อยู่แล้ว (ดู schema.sql บรรทัดใกล้ 5610-5642 เป็นตัวอย่าง)
7. Public → Private ไม่ต้องทำอะไรเพิ่มที่ schema (แค่ `update profiles set is_private = true` ตรงๆ ผ่าน policy update เดิม) — **Private → Public ต้อง auto-accept คำขอค้าง**: เพิ่ม trigger `AFTER UPDATE on profiles` (หรือรวมไว้ใน RPC ถ้า Design/Coding เห็นว่าสะอาดกว่า) ที่ทำงานเมื่อ `is_private` เปลี่ยนจาก true → false: `update follows set status = 'active' where following_id = new.id and status = 'pending'`
8. Content visibility: ขยาย `drops`/`pops`' SELECT policy (drop+recreate แบบเดิม) เพิ่มเงื่อนไข "หรือเจ้าของ Drop/Pop เป็น Public หรือผู้ดูเป็นเจ้าของเอง หรือผู้ดู follow เจ้าของแบบ active" — เขียนเป็นฟังก์ชัน `internal.can_view_content(p_author_id uuid) returns boolean` (SECURITY DEFINER มิเรอร์ `is_blocked_either_way`) กันการเขียน subquery ซ้ำ 4 จุด (drops/pops/drop_comments/pop_comments) ให้สั้นและตรงกันเสมอ — logic ข้างใน: `p_author_id = auth.uid() or not (select is_private from profiles where id = p_author_id) or exists (select 1 from follows where follower_id = auth.uid() and following_id = p_author_id and status = 'active')`
9. `drop_comments`/`pop_comments`' SELECT policy ขยายเพิ่มอีกเงื่อนไข (ต่อจาก soft-delete ของ WYN-037 ที่ `drop_comments` มีอยู่แล้ว) ให้เช็ค `internal.can_view_content()` กับเจ้าของ Drop/Pop แม่ด้วย ปิดช่องทางอ้อมเดียวกับที่ WYN-037 เคยปิดไปแล้วสำหรับ soft-delete
10. `home_feed`/`saved_feed` view **ไม่ต้องแก้เลย** เหมือนเดิมทุกครั้งที่ผ่านมา (RLS table เดียวพอ เพราะทั้งสอง view เป็น `security_invoker = true`)
11. `get_or_create_conversation()` (WYN-032) ที่เช็ค `follows` ตอนนี้ **ต้องเพิ่ม `and status = 'active'`** เข้าไปในเงื่อนไข exists เดิม ไม่งั้นคำขอติดตามที่ยัง pending จะถูกนับผิดๆ ว่า "follow อยู่แล้ว" ทำให้ message request ข้ามขั้นตอนไปเป็น active ทั้งที่ยังไม่ได้ follow จริง
12. Followers/Following count+list (`FollowRepository.countFollowers/countFollowing/fetchFollowers/fetchFollowing`) **ทุกเมธอดต้องเพิ่ม `.eq('status', 'active')`**
13. `FollowRepository.isFollowing()` เปลี่ยนเป็น tri-state (เช่น enum `notFollowing`/`pending`/`following` แทน `bool`) — `toggleFollow()` เปลี่ยน insert-path ไปเรียก RPC `follow_user()` แทน raw insert (delete-path ไม่เปลี่ยน) — กระทบ call site ทั้ง 3 จุด (`ViewProfileScreen`/`DropDetailScreen`/`PopClipView`) ตามที่ระบุใน Risks

Handoff: AI Design — ออกแบบปุ่ม Follow 3 สถานะ (ติดตาม/ขอแล้ว/กำลังติดตาม) ให้ทั้ง 3 จุดที่ใช้ปุ่มนี้อยู่ตอนนี้, หน้าจอ "คำขอติดตาม" ใหม่ (มิเรอร์ Message Requests ของ WYN-032 ให้มากที่สุด) พร้อมตัดสินใจจุดเข้าถึง (badge/entry point), Settings toggle "บัญชีส่วนตัว" ใหม่, สถานะโปรไฟล์ที่ถูกล็อก (grid ว่าง/ข้อความบอกว่าเป็นบัญชีส่วนตัวต้องขอติดตามก่อน) บน `ViewProfileScreen`, ทบทวน schema/RPC/RLS ข้อ 1-13 ด้านบนก่อนส่งต่อ AI Coding — โดยเฉพาะข้อ 8-9 (`internal.can_view_content()` + comment indirect-leak) และข้อ 11 (Message Request's `follows` check ต้องกรอง active) ที่เป็นจุดเสี่ยงด้าน correctness/privacy สูงสุดของ task นี้
