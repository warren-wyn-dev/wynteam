# Design Spec — WYN-030: Appeal System

อ้างอิง Design System ที่อนุมัติแล้ว (ไม่คิดทิศทาง visual ใหม่): `.wyn/docs/design/ds-001-color-system.md` (Cyan เป็น accent ≤15% ของจอเท่านั้น, ห้ามใช้สีแดงกับปุ่มยืนยัน แม้แต่ action รุนแรง), `.wyn/docs/design/ds-008-responsive-accessibility.md` (touch target ≥44×44, textScale 130%, ห้ามแตะไฟล์ `pop_*.dart`)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-030-appeal-system.md` (รวม revision 2026-08-22 ที่ปรับ scope ของ Remove Content appeal)
อ้างอิง Design/โค้ดที่มีอยู่แล้วและต้องต่อยอด (ไม่ประดิษฐ์ของใหม่): `.wyn/docs/design/wyn-029-moderation-queue.md` และโค้ดจริงทั้งหมดใน `app/lib/features/moderation/`, `ReportSheet`/`showReportSheet` (WYN-026), `CreateClubPostScreen`'s multi-image picker (`_pickImages`/`_buildImageRow`, WYN-014 — ต้นแบบของ Evidence upload), `ClubRepository`'s private-bucket signed-URL pattern (WYN-014, `club-media`), `AccountRestrictedScreen`/`AuthGate`/`RestrictionBanner` (WYN-029), `NotificationListScreen`/`WynNotification` (WYN-012/015/029), และ `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` (บทเรียนที่ต้องไม่พลาดซ้ำเป็นครั้งที่ 3)

---

## ภาพรวมแนวทาง: ต่อยอด Moderation Queue เดิม ไม่สร้างระบบคู่ขนาน

Product spec สั่งตรงๆ ว่า "เพิ่ม tab/filter 'Appeals' ในหน้าจอ Moderation Queue เดิม (ไม่สร้างหน้าจอแยกใหม่ทั้งหมด)" — งานออกแบบรอบนี้จึงเป็นการ **ประกอบ 3 สิ่งเข้าด้วยกัน**: (1) จุดเข้าใช้งาน "อุทธรณ์" ที่กระจายอยู่ 3 ตำแหน่งเดิม (Notification/RestrictionBanner/AccountRestrictedScreen) (2) ฟอร์มอุทธรณ์ใหม่ 1 ฟอร์ม ใช้ร่วมกันทั้ง 5 action type (3) tab ใหม่ใน `ModerationQueueScreen` ที่ reuse โครง list/detail/action-sheet เดิมของ WYN-029 แทบทั้งหมด

**สิ่งที่เป็น UI จริงมี 4 กลุ่ม**: (A) จุดเข้าอุทธรณ์ 3 ตำแหน่ง (ต่อยอด widget เดิม ไม่สร้างใหม่ 2 ใน 3), (B) `AppealFormScreen` ใหม่ 1 หน้า (C) `MyModerationActionScreen` ใหม่ 1 หน้า (ปลายทางของ notification 4 ประเภทที่เกี่ยวกับ moderation/appeal) (D) tab "อุทธรณ์" ใน Moderation Queue + `AppealDetailScreen`/`AppealDecisionSheet` ใหม่ (ฝั่ง moderator)

---

## ตัดสินใจเชิง scope ที่สำคัญ 6 ข้อ (บันทึกไว้ตรงๆ เพราะ Product spec ไม่ได้ระบุละเอียดถึงระดับนี้ — เป็นการตีความ HOW ภายใน WHAT ที่อนุมัติแล้ว)

1. **กลไก "ล้างผลทางวินัย" เดียวใช้ร่วมกันทั้ง 5 action type**: เพิ่มคอลัมน์ `moderation_actions.overturned_at timestamptz null` — `decide_appeal()` set ค่านี้เมื่ออนุมัติ ไม่ว่า action type ใดก็ตาม แล้วให้ `internal.is_posting_blocked()`/`get_my_moderation_status()`'s existence check ทุกจุด (ของ restrict/suspend/ban) เพิ่มเงื่อนไข `and overturned_at is null` เข้าไปในของเดิม **ไม่แตะ `expires_at` เลย** (ไม่ใช้กลไกผสมสองแบบ) — ผลคือ Restrict/Suspend/Ban ที่ถูก overturn จะ "หายไปจากสถานะ active" โดยอัตโนมัติผ่านฟังก์ชันเดิมที่มีอยู่แล้ว ไม่ต้องเพิ่ม field ใหม่ต่อ action type และ Warning/Remove Content ก็ใช้ column เดียวกันนี้เป็นสัญลักษณ์ "ไม่นับเป็นประวัติ" ได้ทันที (แม้ตอนนี้ยังไม่มีฟีเจอร์ "นับ strike" ที่ต้องอ่านค่านี้จริงก็ตาม — เตรียมไว้ให้ฟีเจอร์ในอนาคตอ่านได้ถูกต้องโดยไม่ต้อง migrate ซ้ำ)
2. **1 หน้าจอเดียว (`MyModerationActionScreen`) รับทุก entry point ที่มาจาก notification** แทนที่จะแยกหน้า "รายละเอียด action" กับหน้า "ผลอุทธรณ์" — เพราะทั้ง 4 notification type ที่เกี่ยวข้อง (`moderation_warning`/`moderation_content_removed`/`appeal_approved`/`appeal_rejected`) ชี้กลับไปที่ `moderation_actions` row เดียวกันเสมอ และสิ่งที่ผู้ใช้อยากเห็นก็เหมือนกันทุกครั้ง (action เดิมคืออะไร + สถานะอุทธรณ์ปัจจุบัน) การแยกหน้าจะซ้ำซ้อนโดยไม่มีประโยชน์ต่อผู้ใช้
3. **Ban/Suspend อุทธรณ์ได้โดยไม่ต้อง "login สำเร็จ" ในความหมายที่ผู้ใช้เข้าใจ แต่ session ของ Supabase Auth ต้องยังไม่ถูก sign-out จนกว่าจะออกจากหน้านี้** — ดูรายละเอียดที่ Screen 3 (นี่คือจุดที่ต้องแก้ไขลำดับเวลาของ `AuthGate` ที่ WYN-029 shipped ไปแล้ว ไม่ใช่แค่เพิ่มโค้ดใหม่ล้วนๆ — อธิบายเหตุผลและความเสี่ยงละเอียดที่ Screen 3)
4. **Self-review: บล็อกทั้ง Approve และ Reject** (ไม่ใช่แค่ Approve ตามที่ Requirement เขียนไว้เป็นขั้นต่ำ "ห้ามอย่างน้อยไม่ให้ approve") — เหตุผล: ไม่มีเหตุผลด้าน UX ที่ควรอนุญาตให้ moderator "ปฏิเสธอุทธรณ์ของตัวเอง" ได้ในเมื่อห้าม "อนุมัติอุทธรณ์ของตัวเอง" ไปแล้ว กฎเดียวที่ง่ายกว่า ปลอดภัยกว่า และตรงกับเจตนาที่แท้จริงของ conflict-of-interest guard มากกว่า — ดู Screen 6
5. **Evidence bucket ใช้ pattern เดียวกับ `club-media` เป๊ะ** (private bucket, ไม่ public) แต่ **scope ตาม "เจ้าของไฟล์" แบบเดียวกับ avatar/drop-images** ไม่ใช่ตาม "club membership" แบบ club-media (เพราะ evidence เป็นของส่วนตัวผู้อุทธรณ์ ไม่ใช่ของกลุ่ม) — path convention จึงเป็น `{appellant_id}/{timestamp}-{n}.ext` ไม่ใช่ `{club_id}/...`
6. **Reuse คอลัมน์ `notifications.reason` เดิมสำหรับข้อความปฏิเสธของ moderator** (แทนที่จะเพิ่มคอลัมน์ใหม่) — คอลัมน์นี้มีความหมายเสมอมาคือ "ข้อความที่ผู้รับควรอ่าน" (เดิมคือเหตุผลของ action แรก ตอนนี้คือเหตุผลของการปฏิเสธอุทธรณ์) ความหมายไม่ขัดกันเพราะเป็นคนละ `notifications.type` ไม่เคยอยู่แถวเดียวกัน

---

## Screen 1: `AppealFormScreen` — ฟอร์มอุทธรณ์เดียว ใช้ร่วมกันทั้ง 5 action type

Purpose: เก็บ Reason (บังคับ) + Evidence สูงสุด 3 รูป (ไม่บังคับ) แล้วส่ง `submit_appeal()` — เป็นหน้าจอเต็ม (ไม่ใช่ bottom sheet แบบ `ModerationActionSheet`) เพราะมีองค์ประกอบมากกว่า (ข้อความยาว + รูปภาพหลายรูป) ใกล้เคียงความซับซ้อนของ `CreateClubPostScreen` มากกว่า `ReportSheet`/`ModerationActionSheet`

User Flow: เปิดจากปุ่ม "อุทธรณ์" ที่ entry point ใดก็ได้ (Screen 2/3/4) พร้อม `actionId` + label สั้นๆ ของ action ที่จะอุทธรณ์ (เช่น "คำเตือน (Warning)") → กรอก Reason → แนบ Evidence (ไม่บังคับ) → กด "ส่งอุทธรณ์" → อัปโหลดรูปเข้า `appeal-evidence` bucket ก่อน (ถ้ามี) → เรียก `submit_appeal(actionId, reason, evidencePaths)` → สำเร็จ → ปิดหน้าจอกลับไป entry point เดิม พร้อม SnackBar "ส่งอุทธรณ์แล้ว ทีมงานจะตรวจสอบเร็วๆ นี้" (คำเดียวกับ `ReportSheet`'s SnackBar เป๊ะ เพื่อความคุ้นเคย) → entry point เดิม refresh สถานะเป็น "รอตรวจสอบ"

Components:
- `Scaffold` + `AppBar` (title: "อุทธรณ์: {actionLabel}", `leading` เป็นปุ่มปิด `Icons.close` — ปิดโดยไม่ส่ง เหมือน `CreateClubPostScreen`'s `pop(false)`)
- Context banner อ่านอย่างเดียวด้านบนฟอร์ม: action type + เหตุผลเดิมของ moderator (ดึงจาก `get_my_moderation_action(actionId)` ที่หน้า caller โหลดมาให้แล้ว ส่งเป็น param ไม่ query ซ้ำ) — `Container` พื้น `surfaceContainer` (`radiusMd`) เดียวกับ Report Detail's link card
- ช่อง Reason: `TextField` multiline (`minLines: 4, maxLines: 8`), label "เหตุผลที่คุณคิดว่าคำตัดสินนี้ไม่ถูกต้อง (จำเป็น)" ตัวหนา — เหมือนโครง `ModerationActionSheet`'s reason field เป๊ะ
- Evidence: **reuse `CreateClubPostScreen`'s `_pickImages`/`_buildImageRow` ทั้งโครงสร้าง** แค่เปลี่ยน `_maxImages = 3` และปุ่ม label เป็น "แนบรูปหลักฐาน (ไม่บังคับ, สูงสุด 3 รูป)" — แถวรูป thumbnail 80×80 + ปุ่มลบมุมขวาบนต่อรูป เหมือนกันทุกประการ
- ปุ่ม "ส่งอุทธรณ์" เต็มความกว้าง — disabled จนกว่า Reason ไม่ว่าง (เหมือนกฎ "reason จำเป็นเสมอ" ของ `ModerationActionSheet`)

Interactions: submit → loading + form disabled (เหมือน `ReportSheet._submit`/`ModerationActionSheet._submit`) → error inline สีแดง (สี error token, ไม่ใช่ปุ่ม) → สำเร็จ → `Navigator.pop(true)`

States:
- Loading ตอนโหลด context banner (ถ้า caller ยังไม่มีข้อมูล action พร้อม) — `CircularProgressIndicator`
- Error ตอนอัปโหลดรูปล้มเหลว: แสดง error รวมเดียวกับ error ตอน submit ไม่แยก state ("ส่งอุทธรณ์ไม่สำเร็จ ลองอีกครั้ง") — ให้ผู้ใช้กดส่งใหม่ทั้งชุด (ไม่ทำ partial-retry ซับซ้อนสำหรับ evidence 3 รูป เกินสัดส่วนของฟีเจอร์นี้)

Responsive Behavior: `SingleChildScrollView` เต็มความกว้าง, ทดสอบ textScale 130% ไม่ overflow (multiline reason field ยืดหยุ่นอยู่แล้ว)

Accessibility: touch target ปุ่มลบรูป/ปุ่มปิด ≥44×44 (ปุ่มลบรูปใน `CreateClubPostScreen` ปัจจุบันเป็น `GestureDetector` ขนาด 18px ไม่ผ่าน DS-008 — **ต้องแก้ให้ผ่าน 44×44 ในไฟล์ใหม่นี้ตั้งแต่ต้น ไม่ copy ข้อบกพร่องเดิมมาด้วย** แม้จะ reuse layout ก็ตาม — ห่อ `GestureDetector` ด้วย `SizedBox(width: 44, height: 44)` แล้ววาง icon เล็กไว้ตรงกลางแทนการใช้ hit-box 18px ตรงๆ)

Design Rules: ไม่มีปุ่มสีแดง (มาตรฐานเดิมของทั้งแอป) — ปุ่ม "ส่งอุทธรณ์" เป็น `FilledButton` ธรรมดา

---

## Screen 2: Entry Point — Restrict (`RestrictionBanner` ต่อยอด)

Purpose: ให้ผู้ใช้ที่ถูก Restrict อุทธรณ์ได้จากจุดเดิมที่เห็นเหตุผล (banner ที่มีอยู่แล้วใน 4 จุด: `CreateDropScreen`, comment composer ของ `DropDetailScreen`/`ClubPostDetailScreen`, `CreateClubScreen`)

Components — ต่อยอด `RestrictionBanner` (`app/lib/core/widgets/restriction_banner.dart`), **เพิ่ม param ใหม่แบบ optional ทั้งหมด** (ค่า default `null` ทำให้ banner render เหมือนเดิมทุกประการถ้า caller ยังไม่ส่งมา — ไม่ทำลาย call site เดิม):
- `String? actionId` — มาจาก `ModerationStatus.restrictActionId` ใหม่ (ดู Screen 8)
- `AppealStatus? appealStatus` — มาจาก `ModerationStatus.restrictAppealStatus` ใหม่ (`none`/`pending`/`rejected` — `approved` ไม่มีทางเกิดขึ้นจริงเพราะ banner หยุด render ทันทีที่ overturn สำเร็จ เนื่องจาก `isRestricted` จะกลาย false — ดู ตัดสินใจ scope ข้อ 1)
- โครง visual เปลี่ยนจาก `Row` เดี่ยวเป็น `Column`: แถวเดิม (icon+ข้อความ) ไม่เปลี่ยน ตามด้วยแถวที่ 2 เฉพาะเมื่อ `actionId != null`:
  - `appealStatus == none` → `TextButton` เล็กตรงกลาง "อุทธรณ์" (สไตล์เดียวกับ `TextButton` ที่ใช้ทั่วแอป ไม่ใช่ Cyan เพราะไม่ใช่ primary action ของหน้าที่มันอยู่)
  - `appealStatus == pending` → ข้อความ `labelSmall` สี `onSurfaceVariant`: "อยู่ระหว่างพิจารณาอุทธรณ์"
  - `appealStatus == rejected` → ข้อความเดียวกันแต่ว่า: "อุทธรณ์ถูกปฏิเสธแล้ว"

Interactions: กด "อุทธรณ์" → เปิด `AppealFormScreen(actionId: actionId, actionLabel: 'จำกัดสิทธิ์ (Restrict)', ...)` → กลับมาสำเร็จ → caller (`CreateDropScreen` ฯลฯ) reload `ModerationStatus` เพื่ออัปเดต banner เป็น `pending` (เรียก `_loadModerationStatus()` เดิมซ้ำ ไม่ต้อง logic ใหม่)

States: เหมือนเดิมทุกประการถ้า `actionId == null` (backward-compatible)

Accessibility: `TextButton` "อุทธรณ์" ต้องมี touch target ≥44×44 สูง (ไม่ใช่แค่ตัวหนังสือเล็กแปะ) — ใช้ `TextButton` มาตรฐานของ Flutter ที่มี `MaterialTapTargetSize.padded` อยู่แล้ว ไม่ลด

Design Rules: **ไม่ re-poll สถานะ appeal ระหว่างอยู่ในหน้าเดิม** — เช็คตอน `initState` ครั้งเดียวเหมือนเดิม (trade-off เดียวกับที่ WYN-029 Screen 7 ยอมรับไว้แล้วสำหรับ Restrict expiry เอง — ไม่ใช่ของใหม่)

---

## Screen 3: Entry Point — Suspend/Ban (`AccountRestrictedScreen` + `AuthGate` ต่อยอด) — รวมเส้นทาง "อุทธรณ์ได้แม้ Login ไม่ได้"

Purpose: ให้ Suspend และ Ban ทั้งคู่มีปุ่ม "อุทธรณ์" จริง (แทนที่บรรทัด "การอุทธรณ์ยังไม่เปิดให้ใช้งานในแอปขณะนี้" ของ Ban ที่ WYN-029 เขียนไว้ตอนที่ WYN-030 ยังไม่มีอยู่จริง)

**กลไกที่ทำให้ "อุทธรณ์ได้แม้ Login ไม่ได้" เป็นจริง (นี่คือจุดตัดสินใจที่สำคัญที่สุดของทั้งงานนี้ อธิบายละเอียด)**:

WYN-029's `AuthGate` flow ปัจจุบัน (Screen 6 เดิม): กรอก OTP/OAuth สำเร็จ → Supabase ออก session จริง → ตรวจพบ suspended/banned → **sign out ทันที (background)** → แสดง `AccountRestrictedScreen` จาก local state — ปัญหาคือถ้า sign-out เกิดขึ้นไปแล้วก่อนผู้ใช้กดปุ่มอุทธรณ์ `auth.uid()` จะเป็น null ตอนเรียก `submit_appeal()` ทำให้ RPC ปฏิเสธ (ผู้ใช้ที่ไม่มีตัวตนที่ยืนยันแล้วไม่ควรอุทธรณ์แทนใครก็ได้)

**การแก้ไข**: เลื่อนจังหวะ `signOut()` ออกไป จาก "ทันทีที่ตรวจพบ" เป็น **"หลังผู้ใช้ออกจากหน้า `AccountRestrictedScreen` แล้วเท่านั้น"** (ไม่ว่าจะกดปุ่ม "ตกลง" เฉยๆ หรือส่งอุทธรณ์สำเร็จแล้วก็ตาม) — session ของ Supabase (JWT) ยังคง valid อยู่ตลอดเวลาที่ผู้ใช้ค้างอยู่บนหน้านี้ **แต่ session นี้ใช้ทำอะไรไม่ได้เลยนอกจาก 3 อย่าง**: (ก) เรียก `get_my_moderation_status()`/`get_my_moderation_action()` เพื่อโหลดข้อมูลของตัวเองมาแสดง (ข) เรียก `submit_appeal()` (ค) sign out ตอนออกจากหน้า — **ไม่มีทางเข้าถึง `RootShell`/หน้าจอปกติของแอปได้เลยตราบใดที่ `_blockedInfo` (local state ของ `_AuthGateState`) ยังไม่ null**, กลไก local-state-gates-build() ที่ WYN-029 Screen 6 วางไว้แล้วยังคงทำงานเหมือนเดิมทุกประการ (ไม่แตะ) มีแค่จังหวะเรียก `signOut()` ที่ย้ายออกไปเท่านั้น

**ความเสี่ยงที่ต้องระบุตรงๆ (ไม่ใช่ปิดบัง)**: ระหว่างที่ session ยัง valid อยู่ (นานกว่าเดิมจากมิลลิวินาทีเป็นนาทีถ้าผู้ใช้ใช้เวลากรอกฟอร์ม) ผู้ใช้ที่มี technical knowledge สามารถเรียก Supabase API อื่นๆ ตรงๆ ด้วย token เดิมได้ (เช่น อ่าน feed) เพราะ RLS การอ่านเนื้อหา (Drop/Pop feed) ไม่ได้ถูกจำกัดตามสถานะ moderation อยู่แล้ว (Suspend/Ban บังคับใช้ที่ระดับ **INSERT** เท่านั้น ตาม WYN-029 Screen 8 — "READ" ไม่เคยถูกบล็อกโดยการออกแบบตั้งแต่ต้น) จึงไม่ใช่ช่องโหว่ใหม่ที่เกิดจากงานนี้ (ผู้ใช้ที่ถือ token ที่ยัง valid อยู่แล้วเข้าถึงสิ่งเดียวกันได้อยู่ก่อนแล้วไม่ว่า Flutter client จะ sign-out เร็วแค่ไหนก็ตาม — เพราะการ revoke ฝั่ง server จริงคนละกลไกกัน ดู WYN-029 Screen 6's "แนะนำ Supabase Admin API `auth.admin.signOut(userId, scope:'others')`") แค่หน้าต่างเวลานานขึ้นเท่านั้น **นี่ไม่ใช่การเปลี่ยนสถาปัตยกรรมความปลอดภัย/การยืนยันตัวตน** (ไม่แตะวิธี auth/session/RLS model) เป็นแค่การเลื่อนจังหวะเรียก function ที่มีอยู่แล้วหนึ่งจุด — แนะนำให้ AI Coding ยืนยันสั้นๆ กับ Founder ก่อนเริ่ม (เหมือนที่ WYN-029 เคยแนะนำ 3 จุดของตัวเอง) แต่ไม่ block งาน เพราะ Product spec เองบังคับ requirement นี้ไว้ชัดเจนอยู่แล้ว ("Ban: อุทธรณ์ได้แม้ Login ไม่ได้")

Components — `AccountRestrictedScreen` เพิ่ม param ใหม่ (optional, default null = พฤติกรรมเดิมทุกประการ):
- `String? actionId`
- `AppealStatus? appealStatus`
- `Future<void> Function()? onAppeal` — callback เปิด `AppealFormScreen` (caller/`AuthGate` เป็นคนสร้าง เพราะต้องรู้ repository instance)
- แทนที่บรรทัด Ban-only เดิม ("การอุทธรณ์ยังไม่เปิดให้ใช้งานในแอปขณะนี้") ด้วย logic เดียวกันทั้ง Suspend และ Ban (ลบเงื่อนไข `if (isBanned)` ของบรรทัดนั้นทิ้ง — ทั้งคู่มีสิทธิ์อุทธรณ์เท่ากันตาม Requirement):
  - `appealStatus == none` → `OutlinedButton` "อุทธรณ์" ใต้ปุ่ม "ตกลง" (ไม่ใช่ปุ่มหลัก — ปุ่ม "ตกลง" ยังเป็น `FilledButton` หลักเหมือนเดิม เพราะการออกจากหน้านี้คือ flow หลักที่คาดหวัง การอุทธรณ์เป็นทางเลือกรอง)
  - `appealStatus == pending` → ข้อความแทนปุ่ม: "คุณได้ส่งอุทธรณ์แล้ว อยู่ระหว่างการตรวจสอบ"
  - `appealStatus == rejected` → "อุทธรณ์ของคุณถูกปฏิเสธแล้ว"

Interactions: กดปุ่ม "อุทธรณ์" → เรียก `onAppeal` (เปิด `AppealFormScreen` แบบ push เหนือ `AccountRestrictedScreen`) → ส่งสำเร็จ → กลับมาหน้านี้พร้อม state เปลี่ยนเป็น `pending` (ไม่ auto sign-out ทันที ให้ผู้ใช้อ่านผลก่อน) → ผู้ใช้กด "ตกลง" เอง (เหมือนเดิม) → **ตอนนี้ค่อยเรียก `signOut()`** แล้วกลับ `WelcomeScreen`

States: เหมือนเดิมทุกประการเมื่อ `actionId == null` (กรณี defensive/ข้อมูลโหลดไม่ครบ — ไม่ควรเกิดขึ้นจริงเพราะ `get_my_moderation_status()` ต้อง populate เสมอเมื่อ `isSuspended`/`isBanned` เป็น true)

Design Rules: หน้านี้ยังคงไม่มีทาง "ย้อนกลับ"/"ปิด" อื่นนอกจากปุ่ม "ตกลง" เหมือนเดิม — ปุ่ม "อุทธรณ์" ไม่ใช่ทางออกจากหน้านี้ (แค่ push หน้าใหม่ทับ แล้วกลับมาหน้าเดิม)

---

## Screen 4: Entry Point — Warning / Remove Content + ปลายทางผลอุทธรณ์ทุก action type: `MyModerationActionScreen` (ใหม่)

Purpose: หน้าจอเดียวที่รวมทุกอย่างเกี่ยวกับ "1 moderation action ที่กระทำต่อฉัน" — action เดิมคืออะไร + เหตุผล + สถานะอุทธรณ์ปัจจุบัน (หรือปุ่มยื่นอุทธรณ์ถ้ายังไม่เคยยื่น) เปิดจากการแตะ notification 4 ประเภท: `moderation_warning`, `moderation_content_removed`, `appeal_approved`, `appeal_rejected`

User Flow: แตะ notification row ที่มี `moderationActionId != null` → เปิดหน้านี้พร้อม `actionId` → โหลด `get_my_moderation_action(actionId)` (action เดิม) + query `appeals` ของตัวเอง scoped ด้วย `actionId` (สถานะอุทธรณ์) พร้อมกัน → render ตามสถานะ

Components:
1. **การ์ด action เดิม** (พื้น `surfaceContainer`, `radiusMd` — โครงเดียวกับ Report Detail's link card): action type label + เหตุผลของ moderator (เต็ม ไม่ตัด) + เวลา — **ไม่มีลิงก์ไปเนื้อหา ไม่มีชื่อ moderator ที่ตัดสิน** (ไม่เหมือนการ์ดของ Screen 3 WYN-029 ที่ moderator เห็น เพราะหน้านี้เป็นฝั่งผู้ถูกกระทำ)
2. **ส่วนสถานะอุทธรณ์** (เปลี่ยนตามสถานะ):
   - ไม่เคยอุทธรณ์ (`action_type != no_action` เท่านั้นที่มีสิทธิ์ — แต่ในทางปฏิบัติหน้านี้เปิดได้แค่จาก 4 notification type ที่ไม่มี `no_action` อยู่แล้ว) → ปุ่ม "อุทธรณ์" (`FilledButton`)
   - `pending` → การ์ดสรุป Reason/Evidence ที่ผู้ใช้กรอกไปเอง + ข้อความ "อยู่ระหว่างการตรวจสอบ"
   - `approved` → การ์ดเดิม + ข้อความผลลัพธ์ตามประเภท action (ดูถ้อยคำแยกที่ Screen 7) — **สำหรับ Remove Content โดยเฉพาะ**: แสดง Reason ที่ผู้ใช้กรอกตอนยื่นอุทธรณ์ (จาก `appeals.reason` — ข้อมูลที่มีอยู่แล้วตาม RLS เดิม ไม่ต้องเพิ่มกลไกใหม่) ประกอบเพื่อให้บริบทครบ ตามที่ Handoff ของ Product spec แนะนำไว้ **แต่ไม่มีทางแสดงเนื้อหา Drop/Comment/Club Post ที่ถูกลบจริงได้เลย เพราะไม่เคยถูกเก็บสำรองไว้ที่ไหน (ตามขอบเขตที่ Product ตัดสินใจแล้ว ไม่เพิ่ม snapshot)**
   - `rejected` → การ์ดเดิม + ข้อความ "อุทธรณ์ถูกปฏิเสธ — เหตุผล: {decision_reason}"

Interactions: ไม่มี tap-to-navigate เพิ่มเติมภายในหน้านี้ (read-mostly เหมือน Report Detail ของ WYN-029) ยกเว้นรูป Evidence (ถ้ามี) ที่แตะแล้วเปิด full-screen viewer เดียวกับ Screen 6

States:
- Loading: `CircularProgressIndicator` กลางจอ
- Error (โหลดไม่สำเร็จ, เช่น `actionId` เก่าที่ target_user_id ไม่ตรงกับ auth.uid() อีกต่อไป — เคสนี้ไม่ควรเกิดจริงเพราะ action ผูกกับเจ้าของถาวร แต่ยังต้องมี fallback): "โหลดข้อมูลไม่สำเร็จ" + ปุ่มลองใหม่
- **Backward-compat**: notification เก่าที่ถูกสร้างก่อน migration นี้ (ยังไม่มี `moderation_action_id`) — แถวใน `NotificationListScreen` ไม่ navigate ไปไหนเลย (คงพฤติกรรม no-op เดิมของ WYN-029 Screen 5 ไว้เฉพาะกรณีนี้) แทนที่จะพยายามเปิดหน้าด้วย `actionId = null` แล้ว error

Accessibility: `Semantics` label รวมทุกส่วนสำคัญ (action type + เหตุผล + สถานะอุทธรณ์)

Design Rules: **ไม่แสดงตัวตนผู้ตัดสินใจ (ทั้ง action เดิมและ appeal) ที่ใดในหน้านี้เลย** — สืบทอดกฎเดียวกับ WYN-029 Screen 5 ตรงๆ (ดูรายละเอียดเต็มที่ Screen 7)

---

## Screen 5: `ModerationQueueScreen` — เพิ่ม Tab "อุทธรณ์"

Purpose: ให้ moderator/admin ทบทวน Appeal ที่ pending ได้จากหน้าจอเดียวกับที่ทบทวน Report อยู่แล้ว

Components:
- `ModerationQueueScreen` เปลี่ยนจาก single-list เป็น `DefaultTabController(length: 2, ...)` + `TabBar` ใต้ `AppBar` (2 tab: "รายงาน" / "อุทธรณ์") + `TabBarView`
- Tab 1 ("รายงาน") = โครงเดิมทั้งหมดของ Screen 2 (WYN-029) **ไม่เปลี่ยนอะไรเลย** ย้ายเข้า widget ย่อย `_ReportsTab` ตรงๆ (เป็น refactor เชิงโครงสร้างล้วนๆ ไม่ใช่ behavioral change — ต้องมี regression test ยืนยัน)
- Tab 2 ("อุทธรณ์") = `_AppealsTab` (ใหม่) — **โครงแถว/pagination/RefreshIndicator เดียวกับ Tab 1 เป๊ะ** (มิเรอร์ `_ModerationQueueRow` แต่ query `appeals` ที่ `status = 'pending'` แทน `moderation_queue` view) แต่ละแถวแสดง:
  1. **Action type label** (`titleSmall`) เช่น "อุทธรณ์: คำเตือน (Warning)" — ใช้ `ModerationActionType.label` เดิมตรงๆ ไม่ต้องเพิ่ม label ใหม่
  2. **target summary แบบย่อ** (`bodyMedium`, ellipsis) — **reuse `ModerationRepository.fetchTargetSummary()` เดิมได้ตรงๆ** โดยไปหา `target_type`/`target_id` ผ่าน `moderation_actions.report_id` → `moderation_queue` view (moderator มีสิทธิ์อ่านอยู่แล้ว ไม่ filter status) — ไม่มีการเพิ่มคอลัมน์ target ซ้ำใน `appeals` table เลย (ตัดสินใจ scope: หลีกเลี่ยง duplicate data)
  3. **excerpt ของ Appeal's Reason** (`bodySmall`, สี `onSurfaceVariant`, ellipsis) + จำนวน evidence ถ้ามี (ไอคอนเล็ก `Icons.attach_file` + ตัวเลข) + เวลาที่อุทธรณ์ (`relativeTimeLabel` เดิม)
- **ไม่แสดงตัวตนผู้อุทธรณ์ในแถวนี้** — ตรงกันข้ามกับ Report ที่ไม่แสดงตัวตนผู้รายงาน (WYN-026) นี่คือทิศทางตรงข้าม: **ผู้อุทธรณ์คือ target ของ action เดิมอยู่แล้ว (รู้ตัวตนได้จาก action) การไม่แสดงชื่อในแถว list เป็นการลดข้อมูลรบกวนสายตา ไม่ใช่ privacy guarantee แบบ Report** — ชื่อ/username ผู้อุทธรณ์ **แสดงได้เต็มที่ใน `AppealDetailScreen`** (Screen 6) เพราะ moderator จำเป็นต้องรู้ว่ากำลังพิจารณาอุทธรณ์ของใคร (คนละเคสกับ reviewer identity ที่ต้องปิดบังจากผู้ใช้)

Interactions: แตะแถว → เปิด `AppealDetailScreen` (Screen 6)

States: Loading/Empty ("ไม่มีอุทธรณ์ที่รอตรวจสอบ")/Error — โครงเดียวกับ Tab 1 เป๊ะ

Responsive/Accessibility: เหมือน Screen 2 (WYN-029) ทุกประการ

Design Rules: **ไม่ทำ badge นับจำนวน appeal ค้างบน tab label** รอบนี้ (เหมือนที่ Report list ก็ไม่มี badge สถานะ pending/reviewing แยก ตาม WYN-029's scope decision #3) — ความสม่ำเสมอของ scope ระหว่าง 2 tab

---

## Screen 6: `AppealDetailScreen` + `AppealDecisionSheet` (ใหม่ ฝั่ง moderator)

Purpose: ให้ moderator เห็นบริบทเต็มของอุทธรณ์ก่อนตัดสินใจ + ตัดสินใจ Approve/Reject

Components (`AppealDetailScreen`, บนลงล่าง):
1. **การ์ด action เดิม** — action type + เหตุผลเดิมของ moderator ที่ตัดสิน action นั้น + เวลา + **(เสริม, ไม่บังคับ) ชื่อผู้ตัดสินใจเดิม** ("ผู้ตัดสินใจเดิม: @username") — แสดงได้เพราะ moderator ปัจจุบันมีสิทธิ์อ่าน `moderation_actions.reviewer_id` อยู่แล้วตาม RLS เดิม (policy "Moderators can view moderation action history" ไม่จำกัดเฉพาะ action ของตัวเอง) การแสดงตรงนี้ช่วยให้ moderator สังเกตได้เองว่าอุทธรณ์นี้เป็น action ที่ตัวเองเคยตัดสินหรือไม่ (สนับสนุน "Reviewer ควรเป็นคนละคนถ้าเป็นไปได้" ตาม Requirement แม้จะไม่บังคับ) — **ไม่มีทางให้ appellant เห็นข้อมูลนี้ได้เลย** (หน้านี้ gate ด้วย `platform_role != user` ทั้งหน้า)
2. **ลิงก์ไปเนื้อหา/โปรไฟล์ที่เกี่ยวข้อง** — โครงเดียวกับ Report Detail's link card (Screen 3, WYN-029) เป๊ะ รวมถึง SnackBar "ถูกลบไปแล้ว" กรณีเนื้อหาไม่มีอยู่แล้ว (โดยเฉพาะ Remove Content ที่ **เนื้อหาถูกลบไปแล้วเสมอ** — การ์ดนี้จะ SnackBar ทุกครั้งสำหรับ action type นี้ ซึ่งถูกต้องตามความเป็นจริง ไม่ใช่บั๊ก)
3. **Appellant's Reason** (เต็ม ไม่ตัด, `bodyMedium`) — พร้อม username ผู้อุทธรณ์กำกับหัวข้อ ("เหตุผลจาก @username")
4. **Evidence** (ถ้ามี) — แถว thumbnail แนวนอนเดียวกับ `AppealFormScreen`'s แต่ read-only (ไม่มีปุ่มลบ) แตะรูปใดรูปหนึ่ง → เปิด **`EvidenceImageViewer`** (ใหม่ เล็กมาก) — `Scaffold` พื้นดำเต็มจอ, `Image.network(signedUrl)` กลางจอ, ปุ่มปิด `Icons.close` มุมซ้ายบน — **ไม่ทำ pinch-zoom/`InteractiveViewer`** (เครื่องมือภายในขั้นต่ำตามที่ WYN-029's ภาพรวมกำหนดไว้ทั้งโปรเจกต์นี้ — ไม่ over-engineer)
5. **ปุ่ม Approve/Reject** — 2 `OutlinedButton` เต็มความกว้างเรียงกัน ("อนุมัติอุทธรณ์" / "ปฏิเสธอุทธรณ์") **ไม่มีสีแดงแม้แต่ Reject** (กฎเดิมของทั้งแอป) — **ซ่อนทั้ง 2 ปุ่มและแสดงข้อความแทนเมื่อ `currentModeratorId == appeal.targetUserId`** (self-review guard, ดูรายละเอียดที่ Screen 8): "คุณไม่มีสิทธิ์ตัดสินอุทธรณ์นี้เพราะเป็น action ที่มีผลต่อบัญชีของคุณเอง"

`AppealDecisionSheet` (bottom sheet ใหม่ — **reuse โครง `ModerationActionSheet` ทั้งดุ้น** เหตุผลเดียวกับที่ `ModerationActionSheet` เองก็ reuse โครง `ReportSheet`):
- header: "ยืนยัน: อนุมัติอุทธรณ์" / "ยืนยัน: ปฏิเสธอุทธรณ์"
- **Approve**: ไม่มีช่อง reason บังคับ (Product spec ไม่ได้เรียกร้อง — outcome message เป็น template คงที่ตาม action type) มีแค่ปุ่ม "ยืนยัน" ตรงๆ (sheet นี้จึงสั้นมากสำหรับ Approve — แทบไม่มีฟอร์ม แค่ confirm)
- **Reject**: ช่อง Reason **บังคับกรอก** (Product spec ยืนยันชัด "ปฏิเสธ (ต้องกรอกเหตุผล)") label "เหตุผลที่ปฏิเสธ (จำเป็น)" — ผู้ใช้จะเห็นข้อความนี้โดยตรง (helper text เตือนแบบเดียวกับ `ModerationActionSheet`)
- ปุ่ม "ยืนยัน" → เรียก `decide_appeal(appealId, approve, decisionReason)` → สำเร็จ → `Navigator.pop(true)` → `AppealDetailScreen` ปิดตัวเอง กลับ Tab "อุทธรณ์" พร้อม SnackBar "ดำเนินการแล้ว" + เอาแถวออกจาก list (optimistic, เหมือน Screen 3 ของ WYN-029)
- Error กรณี "อุทธรณ์นี้ถูกตัดสินไปแล้วโดยคนอื่น" (race, `for update` guard) → sheet ปิดเอง พร้อม pop ค่าพิเศษให้ Detail screen กลับ list ทันที — เหมือน `ModerationActionSheetOutcome.alreadyActionedByOthers` เป๊ะ

States: โหลด appeal detail ล้มเหลว (ถูกตัดสินไปแล้วระหว่างเปิดหน้าค้าง) → "อุทธรณ์นี้ถูกดำเนินการไปแล้ว" + ปุ่ม "กลับไปที่คิว" — เหมือน Screen 3 ของ WYN-029 เป๊ะ

Accessibility: ปุ่ม Approve/Reject มี `Semantics` label ชัดเจน, การ์ดลิงก์เนื้อหามี label เต็ม

Design Rules: หน้านี้เป็น read-mostly เหมือน Report Detail — การเปลี่ยนแปลงทั้งหมดผ่าน `AppealDecisionSheet` เท่านั้น

---

## Screen 7: ข้อความผลลัพธ์ + การปกป้องตัวตนผู้ตัดสินใจ (ผ่าน Notification เดิม — ไม่สร้างระบบแจ้งเตือนใหม่)

Purpose: ทำให้ Requirement "ผู้ใช้เห็นผลอุทธรณ์" เป็นจริง พร้อม **ป้องกันการรั่วไหลตัวตนผู้ตัดสินใจอุทธรณ์ ซึ่งเป็นความเสี่ยงคลาสเดียวกับที่เกิดมาแล้ว 2 ครั้งในโปรเจกต์นี้** (WYN-027's `is_blocked_either_way` RPC exposure, และ WYN-029's `notifications.actor_id` leak ที่เพิ่งแก้ไป — ดู `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md`) **นี่คือครั้งที่ 3 ที่ต้องระวังไม่ให้เกิดซ้ำ**

Components:
- เพิ่ม `NotificationType` ใหม่ 2 ค่า: `appealApproved` (`appeal_approved`), `appealRejected` (`appeal_rejected`)
- **`actor_id` ต้องเป็น `null` เสมอสำหรับทั้ง 2 type ใหม่นี้** ทันทีตั้งแต่การ insert ครั้งแรก (ไม่ใช่แก้ทีหลังแบบที่ WYN-029 ต้องทำ) — `decide_appeal()` เขียน `insert into notifications (recipient_id, actor_id, type, ...) values (v_target_user, null, ...)` ตรงๆ **ไม่มีจังหวะใดที่ `reviewer_id`/`auth.uid()` ของผู้ตัดสินอุทธรณ์ถูกเขียนลงคอลัมน์ที่ target อ่านได้เลย** — ตัวตนที่แท้จริงถูกบันทึกไว้ที่ `appeals.reviewer_id` เท่านั้น (คอลัมน์ที่ target ไม่มีสิทธิ์ SELECT เห็น — ดู Screen 8)
- `notifications.actor_id` ต้อง nullable อยู่แล้ว (WYN-029's fix ทำไว้แล้ว — ไม่ต้องแก้ constraint ซ้ำ)
- `NotificationListScreen._hidesActorIdentity()` **ต้องขยายให้ครอบคลุม 2 type ใหม่นี้ด้วย** (`moderationWarning`/`moderationContentRemoved`/`appealApproved`/`appealRejected` ทั้ง 4 ตัว) — render ไอคอน shield กลาง `surfaceContainerHigh` เหมือนกันทุกประการ ไม่ใช้ `AvatarCircle`
- `_messageFor()` เพิ่ม case ใหม่ (ต้องแยกข้อความตาม `moderation_action_type` ที่ denormalize มาบนแถว notification — ดู Screen 8):
  - `appeal_approved` + `action_type = warning` → "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว คำเตือนนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว"
  - `appeal_approved` + `action_type = restrict` → "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว สิทธิ์การโพสต์ของคุณกลับมาใช้งานได้ตามปกติแล้ว"
  - `appeal_approved` + `action_type = suspend` → "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว"
  - `appeal_approved` + `action_type = ban` → "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว คุณสามารถเข้าสู่ระบบได้ทันที"
  - `appeal_approved` + `action_type = remove_content` → **ถ้อยคำตรงตามที่ Product spec's Handoff บังคับไว้เป๊ะ**: "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว การละเมิดนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว" — **ห้ามเติมคำใดๆ ที่สื่อว่าเนื้อหากลับมา** (เช่น "โพสต์ของคุณถูกกู้คืนแล้ว") ทั้งในข้อความ list-row นี้และในรายละเอียดที่ `MyModerationActionScreen` (Screen 4)
  - `appeal_rejected` (ทุก action type ใช้ข้อความเดียวกัน — reject ไม่มีผลจับต้องได้ต่างกันตาม type) → "อุทธรณ์ของคุณถูกปฏิเสธ — เหตุผล: {reason}" (reuse คอลัมน์ `reason` เดิมที่ `decide_appeal()` เขียนไว้ตอน reject)
- แตะแถว 2 type นี้ → เปิด `MyModerationActionScreen(actionId: notification.moderationActionId!)` (Screen 4) — **ต่างจาก `moderation_warning`/`moderation_content_removed` เดิมที่เป็น no-op** — ตอนนี้ทั้ง 4 type navigate ไปที่เดียวกันหมด (เหตุผลใน "ตัดสินใจเชิง scope" ข้อ 2)

Design Rules: **กฎนี้ non-negotiable — ต้องเขียน regression test ยืนยันแบบเดียวกับที่ WYN-029's bug fix ทำ (red→green พิสูจน์ผ่าน real Postgres ว่า target query ตรงๆ ไม่ได้ `actor_id`/`reviewer_id` กลับมาเลย ไม่ใช่แค่เชื่อว่า UI ซ่อนไว้)** — บันทึกไว้ที่ Handoff ให้ AI Coding อ่านบทเรียนจาก `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` ก่อนเขียนโค้ดส่วนนี้

---

## Screen 8: บันทึกเรื่อง Enforcement/Data layer (ไม่ใช่ UI ใหม่ — บันทึกไว้กันเข้าใจผิด เหมือน WYN-029 Screen 8)

**Self-review guard (ตอบคำถามข้อ 3 ของโจทย์งานนี้โดยตรง)**: ต้องเป็น **ทั้ง UI-level และ DB-level พร้อมกัน** ไม่ใช่อย่างใดอย่างหนึ่ง —
- UI (Screen 6): ซ่อนปุ่ม Approve/Reject ทั้งคู่เมื่อ `currentModeratorId == appeal.targetUserId` — เหตุผลด้าน UX (ป้องกันไม่ให้ moderator เผลอพยายามกด แล้วเจอ error ที่งง)
- DB (`decide_appeal()` RPC): **ต้อง raise exception ถ้า `auth.uid() = (select target_user_id from moderation_actions where id = v_action_id)`** ก่อนดำเนินการใดๆ ทั้งสิ้น (ก่อนแม้แต่เช็ค reason ของ reject) — **นี่คือ boundary จริง ไม่ใช่ UI ที่ซ่อนปุ่ม** สืบเนื่องจากบทเรียนที่โปรเจกต์นี้เจอซ้ำแล้วซ้ำอีก (WYN-027/WYN-029 bug reports ทั้งคู่สรุปตรงกันว่า "UI/client-side omission is not a data-access boundary") — ถ้าไม่มี guard ชั้นนี้ moderator ที่ถูก moderate เองแล้วเปิด API ตรงๆ ยังกด approve/reject อุทธรณ์ของตัวเองได้อยู่ดี แม้ปุ่มในแอปจะถูกซ่อนไปแล้วก็ตาม

**`overturned_at` mechanism**: `moderation_actions.overturned_at timestamptz null`, set โดย `decide_appeal()` เท่านั้น (ไม่มี client เขียนตรงได้) — `internal.is_posting_blocked(p_user_id)` และ `get_my_moderation_status()`'s ทุก existence-check ของ restrict/suspend/ban ต้องเพิ่ม `and overturned_at is null` ต่อท้ายเงื่อนไขเดิม (ไม่แตะ `expires_at` logic ที่มีอยู่แล้วเลย)

**RLS ของ `appeals`**:
- ไม่มี INSERT/UPDATE/DELETE policy ให้ client เลยแม้แต่ policy เดียว — เขียนได้ผ่าน `submit_appeal()`/`decide_appeal()` (security definer) เท่านั้น (RPC-over-raw-write pattern เดิมของทั้งโปรเจกต์)
- SELECT: 2 policy คู่กัน — `auth.uid() = appellant_id` (ผู้อุทธรณ์เห็นของตัวเอง) และ `internal.current_platform_role() <> 'user'` (moderator/admin เห็นทั้งหมด) — โครงเดียวกับที่ `reports`/`moderation_actions` ใช้อยู่แล้ว
- **`submit_appeal()` ต้อง validate `target_user_id = auth.uid()`** ของ action ที่กำลังอุทธรณ์ (ป้องกันคนอื่นยื่นอุทธรณ์แทน target ที่ไม่ใช่ตัวเอง) + `action_type <> 'no_action'` + reason ไม่ว่าง + evidence array ยาวไม่เกิน 3 + **validate ทุก path ใน evidence array ขึ้นต้นด้วย `auth.uid()::text || '/'`** (ป้องกัน client ส่ง path ของคนอื่นเข้ามาแอบอ้างเป็นหลักฐานตัวเอง แม้ storage RLS จะกันการ*อัปโหลด*เข้าโฟลเดอร์คนอื่นได้อยู่แล้ว แต่ RPC parameter เป็น string ธรรมดาไม่มีอะไรบังคับว่าต้องมาจากการอัปโหลดจริง — defense-in-depth ชั้นที่ 2)
- **`appeals.moderation_action_id` ต้องเป็น `unique`** (DB-level backstop ของ "1 อุทธรณ์ต่อ 1 action" — ไม่พึ่ง client-side "ปุ่มหายไปหลังส่ง" อย่างเดียว)

**`appeal-evidence` storage bucket**: `insert into storage.buckets (id, name, public) values ('appeal-evidence', 'appeal-evidence', false)` — 2 policy (มิเรอร์ `club-media` แต่ scope ด้วยเจ้าของไฟล์แทน club membership):
- SELECT: `bucket_id = 'appeal-evidence' and (((storage.foldername(name))[1]) = auth.uid()::text or internal.current_platform_role() <> 'user')`
- INSERT: `bucket_id = 'appeal-evidence' and ((storage.foldername(name))[1]) = auth.uid()::text`
- ไม่มี UPDATE/DELETE policy (evidence ไม่แก้ไข/ลบได้หลังส่ง — สอดคล้องกับความเป็น audit-immutable ของทั้งระบบ moderation)

**`get_my_moderation_status()` ต้องขยาย 6 คอลัมน์ใหม่**: `restrict_action_id`, `restrict_appeal_status`, `suspend_action_id`, `suspend_appeal_status`, `ban_action_id`, `ban_appeal_status` (`text`: `none`/`pending`/`approved`/`rejected` — resolve จาก `appeals.status` ของ action_id นั้นๆ ถ้ามี, ไม่มีก็ `none`) — ยังคง "single source of truth ที่ AuthGate และ RestrictionBanner เรียกร่วมกัน" ตามที่ WYN-029 Screen 8 วางไว้ ไม่สร้าง RPC คู่ขนาน

**`get_my_moderation_action(p_action_id uuid)` RPC ใหม่** (security definer, คืนเฉพาะ `action_type`/`reason`/`duration_days`/`expires_at`/`created_at` — **ไม่มี `reviewer_id`**) validate `target_user_id = auth.uid()` ก่อนคืนค่าเสมอ — **นี่คือทางเดียวที่ ordinary user จะอ่านข้อมูล `moderation_actions` ของตัวเองได้** (คอลัมน์ที่ปลอดภัยเท่านั้น) ห้ามเพิ่ม raw SELECT policy บน `moderation_actions` ให้ target โดยเด็ดขาด เพราะ RLS เป็น row-level ไม่ใช่ column-level — เพิ่ม policy แบบนั้นจะเปิดเผย `reviewer_id` ทันที (ย้อนกลับไปเป็นบั๊กเดียวกับที่ WYN-029 เพิ่งแก้)

**`notifications` เพิ่ม 2 คอลัมน์**: `moderation_action_id uuid null references moderation_actions(id)`, `moderation_action_type text null` — set ทั้งคู่ที่ 4 insert site (`moderation_warning`/`moderation_content_removed` ใน `apply_moderation_action()` ที่มีอยู่แล้ว ต้องแก้เพิ่ม 1 บรรทัดต่อจุด, `appeal_approved`/`appeal_rejected` ใน `decide_appeal()` ใหม่)

---

## Handoff

ส่งต่อ AI Coding ตามลำดับที่แนะนำ (data layer + security ก่อนเสมอ ตาม pattern ที่ทุก task ก่อนหน้านี้ในโปรเจกต์ใช้):

1. **`moderation_actions.overturned_at`** column + แก้ `internal.is_posting_blocked()`/`get_my_moderation_status()`'s existence-check ทุกจุดของ restrict/suspend/ban ให้เพิ่ม `and overturned_at is null` (ตัดสินใจ scope ข้อ 1 — อ่านให้เข้าใจก่อนแก้ เพราะเป็นการแก้ฟังก์ชันที่ shipped แล้ว)
2. **`notifications` เพิ่ม 2 คอลัมน์** (`moderation_action_id`, `moderation_action_type`) + แก้ `apply_moderation_action()`'s 2 insert site เดิมให้ populate `moderation_action_id` ด้วย (จุดเดียวกับที่ WYN-029's actor-identity fix เพิ่งแก้ไป — ต้องระวังไม่ทำ regression กับ fix นั้น)
3. **`appeals` table** (id, moderation_action_id uuid not null unique references moderation_actions(id), appellant_id uuid not null references profiles(id), reason text not null, evidence_paths text[] check ยาวไม่เกิน 3, status text check in ('pending','approved','rejected') default 'pending', reviewer_id uuid null references profiles(id), decision_reason text null, created_at timestamptz default now(), decided_at timestamptz null) + RLS (2 SELECT policy, ไม่มี INSERT/UPDATE/DELETE policy ใดๆ) — ดู Screen 8
4. **`appeal-evidence` storage bucket** + 2 policy (ดู Screen 8)
5. **`submit_appeal(p_action_id, p_reason, p_evidence_paths)` RPC** (security definer) — validate ครบตาม Screen 8 (target_user_id ตรงกับผู้เรียก, action_type ไม่ใช่ no_action, reason ไม่ว่าง, evidence ≤3 และ path ตรงเจ้าของ, ยังไม่เคยอุทธรณ์ action นี้)
6. **`decide_appeal(p_appeal_id, p_approve, p_decision_reason)` RPC** (security definer) — `for update` กัน race, self-review guard (raise exception, ไม่ใช่แค่ UI), reject ต้องมี decision_reason, approve set `overturned_at`, insert notification ด้วย `actor_id = null` เสมอ (Screen 7 — non-negotiable) + `moderation_action_id`/`moderation_action_type` denormalized
7. **`get_my_moderation_status()` ขยาย 6 คอลัมน์ใหม่** (action_id + appeal_status ต่อ restrict/suspend/ban) — อ่าน Screen 8 ก่อนแก้เพราะเป็นฟังก์ชันที่ 2 หน้าจอ (AuthGate + RestrictionBanner) พึ่งพาร่วมกันอยู่แล้ว
8. **`get_my_moderation_action(p_action_id)` RPC ใหม่** (security definer, คืนเฉพาะคอลัมน์ปลอดภัย ไม่มี `reviewer_id`)
9. **`NotificationType` เพิ่ม 2 ค่า** (`appeal_approved`/`appeal_rejected`) + `WynNotification` เพิ่ม field `moderationActionId`/`moderationActionType` + `_hidesActorIdentity()`/`_messageFor()`/`_openNotification()` ขยายครบ 4 type (2 เดิม + 2 ใหม่) — **อ่าน `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` ก่อนเริ่มเขียนส่วนนี้** (Screen 7)
10. UI: `AppealFormScreen` (Screen 1) → 3 entry point (`RestrictionBanner` ต่อยอด Screen 2, `AccountRestrictedScreen`+`AuthGate` ต่อยอด Screen 3 — **จุดที่ต้องระวังที่สุดคือการเลื่อนจังหวะ `signOut()`**, `MyModerationActionScreen` ใหม่ Screen 4) → `ModerationQueueScreen` เพิ่ม tab (Screen 5) → `AppealDetailScreen`+`AppealDecisionSheet`+`EvidenceImageViewer` ใหม่ (Screen 6)

เก็บ regression test ให้ครบ โดยเฉพาะ: **actor_id/reviewer_id ต้องไม่รั่วไปยัง target ผ่าน notification (ทดสอบ query ตรงๆ ด้วย role `authenticated` เป็น target จริง เหมือนที่ WYN-029's bug fix ทำ ไม่ใช่แค่อ่าน UI code)**, self-review guard ต้องบล็อกที่ RPC จริง (ไม่ใช่แค่ UI ซ่อนปุ่ม — ทดสอบเรียก `decide_appeal()` ตรงๆ ในฐานะ moderator ที่เป็น target ของ action นั้นเอง), `overturned_at` ทำให้ `is_posting_blocked()`/`get_my_moderation_status()` คืนค่าถูกต้องทั้ง 2 ทิศ (ก่อน/หลัง overturn), 1 อุทธรณ์ต่อ 1 action บังคับได้จริงที่ unique constraint (ไม่ใช่แค่ปุ่มหาย), Remove Content's approved-appeal message ต้องไม่มีคำใดสื่อว่าเนื้อหากลับมา (grep ข้อความจริงเทียบกับคำต้องห้ามที่ Product spec ระบุ), Suspend/Ban ที่ session ยัง valid อยู่ระหว่าง `AccountRestrictedScreen` ต้องเรียก `submit_appeal()` สำเร็จจริง (ทดสอบ end-to-end จำลอง flow: authenticate → detect ban → **ไม่ sign out** → เรียก RPC → sign out) และ **Pop ต้องไม่ถูกแตะไฟล์ใดเลยแม้แต่บรรทัดเดียว** (กติกาเดิมของทั้งโปรเจกต์)

**สิ่งที่ควรพิจารณายืนยันกับ Founder ก่อนเริ่ม (ไม่ใช่ Founder-authority ตาม RULES.md — ดูเหตุผลด้านล่าง — แต่เป็นจุดตีความที่ Design ตัดสินใจเองแล้วอาจผิดเจตนา ควรยืนยันสั้นๆ)**:
- การเลื่อนจังหวะ `signOut()` ของ `AuthGate` สำหรับ Suspend/Ban (Screen 3) — ขยายหน้าต่างเวลาที่ session ยัง valid อยู่จากมิลลิวินาทีเป็นนาที เพื่อให้อุทธรณ์ได้ตามที่ Product spec สั่ง
- Self-review guard บล็อกทั้ง Approve และ Reject (เกินกว่าขั้นต่ำที่ Requirement เขียนไว้ "อย่างน้อยไม่ให้ approve")
- การแสดง "ผู้ตัดสินใจเดิม" ให้ moderator ที่กำลังพิจารณาอุทธรณ์เห็น (Screen 6, ข้อ 1) — เสริมจาก requirement ที่ไม่ได้บังคับไว้

ทั้ง 3 ข้อเป็นการตีความ HOW ภายใน WHAT ที่ Founder อนุมัติแล้ว **ไม่แตะวิสัยทัศน์/สถาปัตยกรรมหลัก/สถาปัตยกรรมความปลอดภัย/สถาปัตยกรรมการยืนยันตัวตน/โครงสร้างฐานข้อมูลแบบทำลายล้าง ตามนิยามใน RULES.md เลยแม้แต่ข้อเดียว** (ไม่เปลี่ยนวิธี auth/session mechanism, ไม่เปลี่ยน RLS model, ไม่ลบ/ทำลายข้อมูลใดๆ) จึงไม่ใช่ `APPROVAL_REQUIRED` — แนะนำให้ AI Coding ยืนยันสั้นๆ กับ Founder ก่อนเริ่ม (หรือดำเนินการตามที่ Design ตัดสินใจไว้นี้ได้เลยถ้า Founder ไม่ทักท้วง เพราะเป็นค่าเริ่มต้นที่สมเหตุสมผลและย้อนกลับแก้ได้ในอนาคตโดยไม่กระทบโครงสร้างหลัก — แนวทางเดียวกับที่ WYN-029 Design เคยใช้กับ 3 จุดของตัวเองมาแล้ว)

Handoff: AI Coding — เริ่มจาก data layer (ข้อ 1-9 ด้านบน) ตามลำดับที่แนะนำ แล้วค่อยเข้า UI (ข้อ 10)
