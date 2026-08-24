# Product Task — WYN-052

Status: backlog
Owner: AI Product Manager

Feature: WYN Admin Content Moderation — ค้นหา Drop, Review, Remove, **Restore** (เฉพาะ Drop ในรอบนี้), ตรวจ Report, ดู Moderation History

Goal: task ที่สี่ของ Phase 7 — เติมเนื้อหาจริงแทน placeholder "Content Moderation" (Master Spec section 39: "Admin ทำได้: Search Drop, Review, Remove, Restore (ตามสิทธิ์), ตรวจ Report, ดู Moderation History")

Target User: Admin/Moderator ที่ต้องการค้นหา/ตรวจสอบเนื้อหาที่มีปัญหาโดยตรง (ไม่ต้องรอ Report เข้าคิวเสมอไป เหมือนที่ WYN-051 ทำสำเร็จกับ User Management) รวมถึงกู้คืนเนื้อหาที่ลบผิดพลาด/ตัดสินใจผิด

Problem (สำคัญ — พบช่องโหว่สถาปัตยกรรมจริงระหว่างร่าง spec นี้ ไม่ใช่แค่ "งานใหม่ธรรมดา"):

**1. "Remove Content" ของ WYN-029 เป็น hard DELETE ถาวร ไม่มีทาง Restore ได้เลยในตอนนี้** — ยืนยันจากโค้ดจริง: `apply_moderation_action()`'s remove_content branch เรียก `delete from drops/drop_comments/club_posts/club_post_comments where id = ...` ตรงๆ ไม่มี soft-delete ใดๆ เกี่ยวข้อง — เคยถูกบันทึกไว้แล้วใน `.wyn/company/DECISIONS.md` (WYN-030's Recommendation ข้อ 5) ว่า "เมื่อ WYN Admin เริ่มพัฒนาจริง ให้พิจารณา task แยกปรับปรุง WYN-029 ให้ Remove Content เป็น soft-delete จริง" — **task นั้นคือ WYN-052 นี้เอง**

**2. ถ้าแค่เอา `drops.deleted_at` (soft-delete ที่มีอยู่แล้วจาก WYN-037) มาใช้ตรงๆ กับ Remove Content จะเปิดช่องโหว่ร้ายแรง**: `restore_drop()` (WYN-037, self-service) เช็คแค่ `author_id = auth.uid()` และ `deleted_at is not null` **ไม่เคยแยกแยะว่า "ใครเป็นคนลบ"** — ถ้า Admin ใช้ mechanism เดียวกับ self-delete (`deleted_at`) เพื่อ Remove Content เจ้าของ Drop จะกด "กู้คืน" ผ่านหน้า "รายการที่ลบ" ของตัวเองใน Settings **คืนเนื้อหาที่ถูก Admin ลบเพราะผิดกติกากลับมาได้ทันทีเอง** — นี่คือ privilege bypass ที่แท้จริง ไม่ใช่แค่ edge case เล็กน้อย ต้องแก้ก่อนจะปล่อย Remove Content ผ่าน soft-delete ได้จริง

**3. เนื้อหาประเภทอื่นไม่มี soft-delete โครงสร้างพื้นฐานเลย** — `drop_comments`/`club_posts`/`club_post_comments` ไม่มีคอลัมน์ `deleted_at`/กลไก restore ใดๆ ทั้งสิ้น (ตรวจสอบยืนยันจาก schema จริงแล้ว) การเพิ่ม soft-delete+restore ให้ครบทั้ง 3 ประเภทเป็นงานคนละขนาดกับแค่ Drop ที่มีโครงพื้นฐานอยู่แล้ว

Requirements:

**1. ขอบเขต V1 — Restore เฉพาะ Drop เท่านั้น เนื้อหาอื่นยังเป็น hard-delete ถาวรเหมือนเดิมทุกประการ**
- Comment (Drop/Club Post)/Club Post: พฤติกรรม "Remove Content" **ไม่เปลี่ยนจากเดิมเลย** (ยังคง hard delete ถาวรผ่าน `apply_moderation_action()` เดิม ไม่แตะ) — เหตุผล: ไม่มี soft-delete infra ให้ reuse เหมือน Drop เพิ่ม scope งานคนละขนาด เสนอเป็น task แยกในอนาคตถ้า Founder ต้องการ Restore ให้ครบทุกประเภท
- Drop เท่านั้นที่ได้ Remove-as-soft-delete + Restore ผ่าน Admin

**2. แก้ช่องโหว่ self-restore-defeats-moderation ก่อนเปิดใช้งาน (บังคับ ไม่ใช่ optional)**
- `restore_drop()` (self-service เดิมของ WYN-037) ต้อง**ปฏิเสธการกู้คืนถ้า Drop นั้นถูก Admin/Moderator ลบผ่าน moderation** (ไม่ใช่ self-delete) — ต้องมีวิธีแยกแยะ "ใครสั่งลบ" ที่เชื่อถือได้ ไม่ใช่แค่เช็ค `deleted_at is not null` เฉยๆ — เสนอสถาปัตยกรรม: `moderation_actions` เพิ่มคอลัมน์ใหม่ nullable `target_content_type`/`target_content_id` (มิเรอร์ pattern polymorphic เดียวกับ `reports.target_type`/`target_id` ที่มีอยู่แล้ว) บันทึกไว้ทุกครั้งที่ remove_content เกิดขึ้นกับ Drop (ทั้งทาง Report เดิมและทาง direct action ใหม่ของ Admin) — `restore_drop()` เพิ่มเงื่อนไข: ถ้ามีแถว `moderation_actions` ที่ `action_type = 'remove_content'`, `target_content_type = 'drop'`, `target_content_id = <drop นี้>`, และ `overturned_at is null` อยู่ → self-restore ต้องถูกปฏิเสธ (raise exception ชัดเจนว่า "เนื้อหานี้ถูกลบโดยผู้ดูแลระบบ ติดต่อผ่านการอุทธรณ์เท่านั้น") — มีแค่ Admin/Moderator เท่านั้นที่กู้คืนได้ต่อจากนี้ (ผ่าน RPC ใหม่ข้อ 4)

**3. ค้นหาและ Review Drop — reuse โครงสร้างเดิมให้มากที่สุด**
- ค้นหา Drop: โดย caption หรือ username ผู้เขียน — ต่างจาก User Management (WYN-051) ตรงที่ `drops` ไม่มี SELECT policy แบบเปิดกว้าง `using (true)` เหมือน `profiles` (มี block-aware/private-account-aware policy จาก WYN-027/039) — Admin/Moderator ต้อง**เห็น Drop ทุกโพสต์แม้ของบัญชี Private/ที่ Block กันอยู่** เพื่อทำหน้าที่ตรวจสอบได้ครบ (ตามที่ Master Spec section 39 ระบุ "Search Drop" ไม่จำกัดเงื่อนไข) — ต้องมี RPC/VIEW ใหม่ที่ bypass RLS ปกติของ `drops` เฉพาะสำหรับ Admin/Moderator เท่านั้น (มิเรอร์ pattern `moderation_queue`/`admin_user_moderation_history` ที่ทำมาแล้ว 2 รอบ)
- Reports ที่มีต่อ Drop นี้: reuse `moderation_queue` VIEW เดิม กรอง `target_type = 'drop'` (เหมือนที่ WYN-051 ทำกับ user)
- Moderation history ของ Drop นี้: ขยาย `admin_user_moderation_history` (หรือ VIEW คู่ขนานใหม่) ให้กรองด้วย `target_content_id` ได้ด้วย ไม่ใช่แค่ `target_user_id`

**4. Action ใหม่**
- `admin_remove_drop(p_drop_id, p_reason)` — soft-delete ผ่าน `deleted_at` เดิม (reuse คอลัมน์เดิมของ WYN-037 ตรงๆ ไม่เพิ่มคอลัมน์ใหม่ใน `drops`) + insert `moderation_actions` row ใหม่ (`target_content_type='drop'`, `target_content_id=<id>`, `report_id` null ได้เหมือน WYN-051's direct actions) — **ไม่ผูกกับ Report เสมอไป** มิเรอร์ pattern เดียวกับ `admin_apply_user_action()` ของ WYN-051 เป๊ะ
- `admin_restore_drop(p_drop_id, p_reason)` — Admin/Moderator เท่านั้น ตั้ง `deleted_at = null` + `overturned_at = now()` บน moderation_actions row ที่เกี่ยวข้อง (คนละ RPC จาก self-service `restore_drop()` เดิม เพราะสิทธิ์/เงื่อนไขต่างกันโดยสิ้นเชิง)
- **ทุก RPC ใหม่ต้องใช้ `coalesce(internal.current_platform_role(), '')` ครอบการเช็ค role เสมอ** ตามบทเรียนที่เจอซ้ำ 2 ครั้งแล้ว (WYN-050, ยืนยันซ้ำใน `send_system_notification()` ระหว่าง QA ของ WYN-051)

Acceptance Criteria:
- [ ] Admin ค้นหา Drop เจอแม้เป็นของบัญชี Private/บัญชีที่ตัวเอง (สมมติ) ถูก Block อยู่
- [ ] Admin สั่ง Remove Drop โดยตรง (ไม่มี Report) → Drop หายจากทุกที่ที่ผู้ใช้ทั่วไปเห็น (Home Feed/Search/Profile) ทันที เหมือน self-delete เดิมทุกประการ
- [ ] **เจ้าของ Drop ที่ถูก Admin ลบ พยายามกด "กู้คืน" เองผ่าน `restore_drop()` เดิม → ต้องถูกปฏิเสธ** (นี่คือ acceptance criterion ที่สำคัญที่สุดของ task นี้ — พิสูจน์ว่าช่องโหว่ข้อ 2 ถูกปิดจริง)
- [ ] Admin สั่ง Restore Drop ที่ตัวเอง (หรือ Admin คนอื่น) เพิ่งลบ → Drop กลับมาเห็นได้ปกติทันที
- [ ] Drop ที่เจ้าของ self-delete เอง (ไม่เกี่ยวกับ moderation เลย) ยัง self-restore ได้ปกติทุกประการเหมือนก่อน task นี้ (regression check สำคัญ — ต้องไม่กระทบ WYN-037's ของเดิม)
- [ ] บัญชี `platform_role = 'user'` หรือบัญชีที่ไม่มีแถว `profiles` เลย เรียก RPC ใหม่ทั้ง 2 ตัว → ถูกปฏิเสธ

Dependencies: WYN-029 (Moderation Queue, `apply_moderation_action()`, `moderation_actions`), WYN-037 (`drops.deleted_at`/`soft_delete_drop()`/`restore_drop()`), WYN-051 (direct-action pattern ไม่ผูก Report, `coalesce()` lesson)

Priority: P1

Risks:
- **นี่คือการแก้ security-critical logic ของฟีเจอร์ที่ deploy ไปแล้ว (WYN-037's restore_drop) ไม่ใช่แค่เพิ่มของใหม่** — ต้องระวังเป็นพิเศษไม่ให้กระทบ self-delete/self-restore ปกติของผู้ใช้ทั่วไปเลยแม้แต่กรณีเดียว ต้องมี regression test ครอบทั้งเคสเดิมและเคสใหม่คู่กันชัดเจน
- **Comment/Club Post ยังลบถาวรเหมือนเดิม** — ถ้า Founder ต้องการ Restore ครบทุกประเภทต้องเป็น task แยกที่ออกแบบ soft-delete ให้ 3 ตารางนั้นตั้งแต่ต้น (ไม่มีโครงสร้างให้ reuse เหมือน Drop)
- **Search Drop ข้าม Private/Block ได้ทั้งหมดสำหรับ Admin** — ต้องมั่นใจว่า RPC/VIEW ใหม่ไม่รั่วไปให้ non-admin เห็นได้ (gate เดียวกับที่ `moderation_queue`/`admin_user_moderation_history` ใช้มาแล้ว 2 รอบ ควรปลอดภัยถ้าทำตาม pattern เป๊ะ)

Recommendation: **นี่คือจุดที่ Founder ควรอนุมัติแนวทางก่อน Coding เริ่ม** เพราะเป็นการแก้ security logic ของฟีเจอร์ที่ deploy แล้ว (`restore_drop`) ไม่ใช่แค่งานใหม่ล้วนๆ แบบ WYN-049/050/051 ที่ผ่านมา — เสนอให้ Founder ยืนยัน 2 จุด: (1) ขอบเขต "Restore เฉพาะ Drop เท่านั้นในรอบนี้" ยอมรับได้ไหม (2) แนวทางแก้ `restore_drop()` ด้วยการเช็ค `moderation_actions` ตามที่เสนอไว้ในข้อ 2

Handoff: AI Design — ออกแบบหน้า Content Moderation (search bar + result grid ของ Drop + detail panel: Reports/History/Remove-Restore button) บน layout shell เดิม — ตัดสินใจว่าจะแสดง Drop preview (รูปภาพ) อย่างไรในหน้า search ให้ Admin เห็นเนื้อหาจริงก่อนตัดสินใจ ไม่ใช่แค่ caption ข้อความ
