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

## Founder อนุมัติแนวทางแล้ว (2026-08-24) — เข้า Coding ต่อทันที

Founder ยืนยันทั้ง 2 จุดที่ Product เสนอไว้: (1) ขอบเขต V1 = Restore เฉพาะ Drop เท่านั้น ยอมรับได้ (2) แนวทางแก้ `restore_drop()` ด้วยการเพิ่ม `target_content_type`/`target_content_id` บน `moderation_actions` แล้วเช็คก่อนอนุญาต self-restore ตามที่เสนอ

## Coding เสร็จแล้ว (2026-08-24)

SQL (`supabase/schema.sql`): เพิ่ม `moderation_actions.target_content_type`/`target_content_id` (nullable, polymorphic มิเรอร์ `reports.target_type`/`target_id`) + constraint คู่ (type ใน ('drop') เท่านั้นตอนนี้, pairing ต้อง null พร้อมกัน) — **แก้ `restore_drop()`** เพิ่มเงื่อนไขปฏิเสธ self-restore ถ้ามี `moderation_actions` row ที่ `action_type='remove_content'`/`overturned_at is null` ผูกอยู่ (นี่คือ core fix ของ task นี้) — **แก้ `apply_moderation_action()`** ให้ remove_content บน target_type='drop' soft-delete (`deleted_at`) แทน hard DELETE พร้อมบันทึก `target_content_type`/`target_content_id` ด้วย (ทำให้ path เดิมผ่าน Report ก็ restorable เหมือนกับ path ใหม่ ปิดช่องโหว่ให้ครบทั้ง 2 ทาง) — drop_comment/club_post/club_post_comment **ไม่แตะเลย** ยัง hard-delete เหมือนเดิมทุกประการ — RPC ใหม่ 4 ตัว: `admin_remove_drop()`/`admin_restore_drop()` (มิเรอร์ `admin_apply_user_action()`/`admin_unban_user()` ของ WYN-051 พร้อม `coalesce()` role guard ตามบทเรียน WYN-050) และ `admin_search_drops()`/`admin_get_drop()` (SECURITY DEFINER bypass RLS ของ `drops` ทั้ง block/private-account/deleted gating ให้ Admin เห็นทุกโพสต์) — ขยาย `admin_user_moderation_history` VIEW เพิ่ม `target_content_type`/`target_content_id` ต่อท้าย column list เดิม (Postgres `create or replace view` ห้ามแทรกคอลัมน์กลาง เจอ error จริงระหว่าง implement แล้วแก้เป็นต่อท้าย) — ขยาย `audit_log_event_type_check` เพิ่ม `admin_content_removed`/`admin_content_restored`

Web (`admin/`): `lib/admin-moderation.ts` (searchDrops/fetchDrop/fetchReportsAgainstDrop/fetchModerationHistoryForDrop/currentActiveRemoval) + `lib/admin-moderation-actions.ts` (removeDrop/restoreDrop) — Screen 1 (`app/(admin)/moderation/page.tsx` แทนที่ placeholder, grid รูปภาพ 2/4/6 คอลัมน์ตาม breakpoint, badge "ลบแล้ว" มุมการ์ด) — Screen 2 (`app/(admin)/moderation/[id]/page.tsx` ใหม่ทั้งหมด, รูปเต็ม+caption, ปุ่มเดียว Remove หรือ Restore ไม่พร้อมกัน, ข้อความกำกับ "ลบโดยผู้ดูแลระบบ"/"ลบโดยเจ้าของเอง" ใต้ปุ่ม Restore, Reports/History table มิเรอร์ WYN-051) — **ขยาย `ActionDialog` component เดิม** เพิ่ม `"destructive"` เข้า `triggerVariant` union (เดิมมีแค่ `"outline"|"default"`) และให้ปุ่มยืนยันใช้ variant เดียวกับ trigger แทนที่จะ hardcode default เสมอ ตาม Design spec ที่ระบุ Remove ต้อง `variant="destructive"`/Restore ต้อง `variant="default"` ตรงๆ — ตรวจแล้วว่าไม่กระทบ dialog เดิมทั้ง 4 ตัวของ WYN-051 (ทุกตัวยังเป็น `"outline"` เหมือนเดิม ปุ่มยืนยันยังเป็น default เหมือนเดิมทุกประการ) — ใช้ `<img>` ธรรมดาแทน `next/image` สำหรับ Drop thumbnail/full image พร้อม eslint-disable comment (ยังไม่มี Supabase project จริงให้ pin hostname เข้า `next.config`'s `images.remotePatterns`) — `flutter`-equivalent ฝั่งนี้คือ `next build`/`npm run lint`: สะอาดทั้งคู่, ไม่พบ `service_role`/`SUPABASE_SERVICE` ใน client bundle (`grep` `.next/static` เอง)

## Independent QA (2026-08-24)

Feature: WYN-052 WYN Admin Content Moderation — Search Drop (bypass block/private), Remove/Restore Drop โดยตรงหรือผ่าน Report, ปิดช่องโหว่ self-restore-defeats-moderation

Environment: local Postgres 16 (throwaway DB ต่อรอบ, role `authenticated` จริง) + Node.js/Next.js 16.3.2 — สตาร์ท Postgres cluster เองจาก down state (`pg_ctlcluster 16 main start`) ก่อนรันชุดทดสอบ

Test Cases:
1. เขียน `wyn_052_admin_content_moderation_test.sh` ใหม่ (11 กลุ่ม เช็ค 23 จุด) ครอบทุก Acceptance Criteria ของ Product spec แบบตรงตัว รวม **CHECK2 ซึ่งคือ AC ที่สำคัญที่สุดของ task นี้** (เจ้าของ Drop ที่ถูก Admin ลบ พยายาม `restore_drop()` เอง → ต้องถูกปฏิเสธ) — รันแล้ว **23/23 PASS**
2. รันซ้ำครบ 23 สคริปต์เดิม (`wyn_021` ถึง `wyn_051`) — เจอ **regression จริง 1 จุด**: `wyn_029`'s `CHECK20_removed_drop_gone` fail เพราะ assert hard-delete แบบเดิม ซึ่งเป็นพฤติกรรมที่ WYN-052 ตั้งใจเปลี่ยน (Drop remove_content ตอนนี้ soft-delete แล้ว ตาม Requirement 2) — **แก้ test เดิมให้ตรงกับพฤติกรรมใหม่ที่ตั้งใจ** (ไม่ใช่แก้โค้ด แก้ assertion) พร้อมคอมเมนต์อธิบายว่าทำไมเปลี่ยน อ้างอิงไปยัง `wyn_052` suite สำหรับ coverage เต็มของ restore path — รันซ้ำทั้งหมดอีกครั้งหลังแก้: **24/24 PASS** (23 เดิม + 1 ใหม่)
3. `check_schema_ordering.py` — OK
4. `next build`/`npm run lint` — สะอาดทั้งคู่ (0 error/warning)
5. `grep` หา `service_role`/`SUPABASE_SERVICE` ใน `.next/static` (client bundle) เอง — ไม่พบ (เจอเฉพาะใน server-side sourcemap/cache ซึ่งเป็นสตริงภายใน SDK ของ Supabase เอง ไม่ใช่ key จริง และไม่ถูกส่งไปฝั่ง browser)
6. รัน dev server จริงด้วย dummy env vars (รูปแบบถูกต้องแต่ไม่ใช่ project จริง) ยืนยัน guest redirect ทำงานถูกต้องกับ route ใหม่ทั้ง `/moderation` และ `/moderation/[id]` (307 → `/login` เหมือน route เดิมทุกตัว) — ลบ `.env.local` ทิ้งทันทีหลังทดสอบ (ไม่ commit)
7. อ่าน `restore_drop()`/`admin_restore_drop()`/`apply_moderation_action()` แบบ adversarial ยืนยัน: self-deleted Drop (ไม่มี `moderation_actions` row เกี่ยวข้องเลย) ไม่ถูกกระทบจากเงื่อนไขใหม่ (ตรวจสอบด้วย `exists()` query ที่คืน false เสมอถ้าไม่มี row), `admin_restore_drop()` บน self-deleted Drop เป็น no-op ที่ปลอดภัยสำหรับส่วน `moderation_actions` update (0 rows affected ไม่ error), `moderation_actions_target_content_pairing_check` ไม่ทำให้ insert เดิมของ WYN-051 (`admin_apply_user_action`/`admin_unban_user`, ไม่ระบุ 2 คอลัมน์ใหม่เลย) พังเพราะทั้งคู่เป็น NULL พร้อมกัน

Passed: ทุกข้อข้างต้น
Failed: ไม่มี (หลังแก้ `wyn_029` test assertion ให้ตรงกับพฤติกรรมใหม่ที่ตั้งใจ)

Security Findings: ไม่พบช่องโหว่ใหม่ — core fix (self-restore-defeats-moderation) ยืนยันปิดจริงด้วยการทดสอบ ไม่ใช่แค่อ่าน code ทั้ง 2 เส้นทาง (direct `admin_remove_drop()` และ report-driven `apply_moderation_action()`) RPC ใหม่ทั้ง 4 ตัวมี `coalesce()` guard ยืนยันปฏิเสธทั้งบัญชีไม่มี `profiles` row และบัญชี role='user' จริงด้วยการทดสอบ ไม่ใช่แค่อ่าน code — `admin_search_drops()`/`admin_get_drop()` ยืนยัน bypass private-account gating ได้จริงด้วยการทดสอบ (ไม่ใช่แค่ตามที่ตั้งใจออกแบบ)

Recommendation: อนุมัติ WYN-052 — ส่งต่อ AI Deploy & DevOps ต่อทันที

Final Status: **PASS**
