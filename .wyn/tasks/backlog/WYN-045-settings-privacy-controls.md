# Product Task — WYN-045

Status: coded, awaiting QA
Owner: AI Product Manager

Feature: Settings — Interaction Privacy Controls (DM Permission, Mention Permission, Comment Permission)

Goal: task ที่สามและสุดท้ายของ Phase 5 (Notification & Settings Expansion) ต่อจาก WYN-043/WYN-044 — ปิดหนี้ที่ค้างไว้ตั้งแต่ WYN-039 ตรงๆ: `.wyn/tasks/approved/WYN-039-private-account-follow-request.md`'s Requirement บันทึกไว้ชัดเจนว่า "Privacy settings ย่อยอื่นๆ ที่ Master Spec section 35 ระบุไว้ (DM Permissions, Mention, Comment) ไม่อยู่ในสโคปนี้ ทำใน WYN-045" — งานนี้ทำ 3 อย่างนั้นให้ครบ

Target User: ผู้ใช้ที่ต้องการควบคุมว่าใครมีสิทธิ์ทัก DM / กล่าวถึง (@mention) / คอมเมนต์ตนเองได้บ้าง มากกว่าแค่ Public/Private ของทั้งบัญชี (WYN-039) หรือ Block/Mute รายบุคคล (WYN-027/028)

Problem: ยืนยันจากการอ่านโค้ดจริง — วันนี้ทั้ง 3 ช่องทางมี permission model แบบ all-or-nothing เท่านั้น (เปิดให้ "ทุกคนที่ไม่ได้ Block กัน" เสมอ ไม่มีระดับกลาง):
- **DM**: `get_or_create_conversation()` (WYN-031/032) อนุญาตให้ใครก็ได้เปิดบทสนทนาใหม่กับใครก็ได้ (ที่ไม่ได้ Block กัน) เสมอ — แค่ตัดสินว่าเข้ากล่องข้อความหลักทันที (`active`) หรือเป็นคำขอ (`pending`) จากการเช็คทิศทางเดียวว่า "ผู้ส่งติดตามผู้รับอยู่ไหม" ไม่มีทางปิดรับข้อความจากคนแปลกหน้าทั้งหมดเลย
- **Mention**: `drop_mentions`/`club_post_mentions`'s INSERT policy (WYN-021, ขยายโดย WYN-027) กรองแค่ความสัมพันธ์ Block เท่านั้น (`not internal.is_blocked_either_way(...)`) — ใครก็กล่าวถึงใครก็ได้ถ้าไม่ได้ Block กัน
- **Comment**: `drop_comments`/`pop_comments`'s INSERT policy (WYN-005/006, ขยายหลายรอบล่าสุดโดย WYN-027/029/037) กรองแค่ Block + moderation-block + Drop ที่ถูกลบเท่านั้น เช่นเดียวกัน ไม่มีระดับควบคุมที่ผู้ใช้ตั้งเองได้เลย

Requirements:

**1. 3 การตั้งค่าใหม่ ใน section "ความเป็นส่วนตัว" เดิมของ `SettingsScreen`** — ระดับเดียวกันทั้ง 3 (reuse ตัวเลือกชุดเดียว ลดความซับซ้อนที่ผู้ใช้ต้องเรียนรู้):
- **ทุกคน** (Everyone) — ค่า default เดิม พฤติกรรมเหมือนวันนี้ทุกประการ ไม่มีอะไรเปลี่ยนสำหรับผู้ใช้ที่ไม่เคยแตะการตั้งค่านี้เลย
- **คนที่ฉันติดตาม** (People I Follow) — เฉพาะบัญชีที่ **เจ้าของการตั้งค่าเป็นฝ่ายติดตามอยู่** เท่านั้นที่ทำ action นั้นกับเจ้าของได้ (ทิศทางเดียวกับที่ Product ตัดสินใจไว้แล้วสำหรับทุกฟีเจอร์ trust-based ในโปรเจกต์นี้ — ตรงกับเงื่อนไข `active` เดิมของ DM พอดี ไม่ใช่ทิศตรงข้าม)
- **ไม่มีใครเลย** (No One) — ปิดทั้งหมด ไม่มีข้อยกเว้น

**2. DM Permission — gate ที่ `get_or_create_conversation()`**
- คอลัมน์ใหม่ `profiles.dm_permission text not null default 'everyone' check (in ('everyone', 'people_i_follow', 'no_one'))`
- เช็คก่อนเข้า logic active/pending เดิมทั้งหมด: ถ้า `p_other_user_id`'s `dm_permission = 'no_one'` → `raise exception` เสมอ (แม้จะเป็นคนที่ผู้รับติดตามอยู่ก็ตาม — "ไม่มีใครเลย" ต้องหมายถึงไม่มีใครจริงๆ ไม่มีข้อยกเว้นที่ทำให้ผู้ใช้สับสน); ถ้า `= 'people_i_follow'` → อนุญาตเฉพาะกรณีที่ตรงกับเงื่อนไข `active` เดิม (ผู้รับติดตามผู้ส่งอยู่) เท่านั้น — กรณีที่เดิมจะกลายเป็น `pending` (ผู้รับไม่ได้ติดตามผู้ส่ง) เปลี่ยนเป็น `raise exception` แทน (ไม่สร้าง pending request อีกต่อไปสำหรับผู้ใช้ที่ตั้งค่านี้); ถ้า `= 'everyone'` (default) → พฤติกรรมเดิมทุกประการ ไม่เปลี่ยนอะไร — **ไม่กระทบบทสนทนาที่มีอยู่แล้ว** (ฟังก์ชันคืนค่า `id` ทันทีถ้ามีแถวอยู่แล้วก่อนเช็ค permission ใดๆ — โค้ดเดิมอยู่แล้ว ไม่ต้องแก้จุดนี้)

**3. Mention Permission — ขยาย `drop_mentions`/`club_post_mentions`'s INSERT policy + `create_poll_drop()`'s WHERE clause**
- คอลัมน์ใหม่ `profiles.mention_permission text not null default 'everyone' check (...)` (ชุดค่าเดียวกับข้อ 2)
- เพิ่มเงื่อนไขใหม่ (helper function ใหม่ `internal.mention_allowed(p_owner uuid, p_actor uuid)`) ต่อจาก `not internal.is_blocked_either_way(...)` เดิมในทั้ง 2 policy — **ไม่ error ทั้งโพสต์เมื่อกล่าวถึงคนที่ปิดรับ** (มิเรอร์ pattern Block เดิมเป๊ะ ตามที่ comment ในสคีมาอธิบายไว้แล้วว่า "ข้อความ @username ยังอยู่ในแคปชันได้ แค่ไม่สร้างแถว mention/ไม่ยิง notification" — คงพฤติกรรมนี้ไว้ ไม่เปลี่ยนเป็น error เพราะจะทำให้ผู้ใช้โพสต์ไม่ได้ทั้งโพสต์เพราะกล่าวถึงคนคนเดียวที่ปิดรับ) — ต้องแก้ `create_poll_drop()`'s (WYN-035) `insert into drop_mentions ... where not internal.is_blocked_either_way(...)` ให้เพิ่มเงื่อนไขเดียวกัน เพราะ RPC นี้เป็น `security definer` ที่ bypass RLS policy ของ `drop_mentions` โดยสมบูรณ์ (ถ้าไม่แก้จุดนี้ด้วย mention permission จะถูกเลี่ยงได้ผ่านเส้นทาง Poll Drop)

**4. Comment Permission — ขยาย `drop_comments`/`pop_comments`'s INSERT policy ล่าสุด (WYN-037's version)**
- คอลัมน์ใหม่ `profiles.comment_permission text not null default 'everyone' check (...)` (ชุดค่าเดียวกัน)
- helper function ใหม่ `internal.comment_allowed(p_owner uuid, p_actor uuid)` (logic เดียวกับ `internal.mention_allowed` แต่แยกฟังก์ชันเพราะเช็คคนละคอลัมน์ — ไม่รวมเป็นฟังก์ชันเดียวรับ parameter ประเภทเพื่อความชัดเจนของ error message และ SQL ที่อ่านง่ายกว่า มิเรอร์แนวทางที่ `internal.drop_author_id`/`internal.pop_author_id` แยกกันแม้ logic คล้ายกัน)
- เพิ่มเงื่อนไขต่อจาก policy ล่าสุดของแต่ละตาราง (ต้อง `drop`+`create` ทับ policy เวอร์ชันล่าสุดที่ WYN-037 ทิ้งไว้ ตามธรรมเนียมเดิมของไฟล์นี้ทุกครั้งที่มีเงื่อนไขใหม่)
- **ขอบเขตเฉพาะ Drop/Pop เท่านั้น ไม่รวม Club Post comment**: การเป็นสมาชิก Club ที่ approved แล้วคือ trust model ของตัวเองอยู่แล้ว (WYN-014/015) การเพิ่ม personal comment permission ทับซ้อนจะขัดกับสิทธิ์สมาชิกที่ Club owner ให้ไว้ ไม่ทำในรอบนี้

Acceptance Criteria:
- [ ] ผู้ใช้ตั้ง DM Permission = "คนที่ฉันติดตาม" → บัญชีที่ตนเองไม่ได้ติดตาม พยายามเปิดบทสนทนาใหม่ → ถูกปฏิเสธ (ไม่มีแถว `conversations`/`pending` ใหม่เกิดขึ้น)
- [ ] ผู้ใช้ตั้ง DM Permission = "คนที่ฉันติดตาม" → บัญชีที่ตนเองติดตามอยู่ เปิดบทสนทนาใหม่ได้สำเร็จ (status `active` เหมือนเดิม)
- [ ] ผู้ใช้ตั้ง DM Permission = "ไม่มีใครเลย" → แม้แต่บัญชีที่ตนเองติดตามอยู่ก็เปิดบทสนทนาใหม่ไม่ได้
- [ ] บทสนทนาที่มีอยู่แล้วก่อนตั้งค่า ยังใช้งานได้ปกติไม่ถูกปิดกั้นย้อนหลัง
- [ ] ผู้ใช้ตั้ง Mention Permission = "ไม่มีใครเลย" → คนอื่นพิมพ์แคปชันมีข้อความ "@username" ของผู้ใช้ → โพสต์สำเร็จปกติ (ไม่ error ทั้งโพสต์) แต่ไม่มีแถว `drop_mentions` เกิดขึ้นสำหรับผู้ใช้ และไม่มี notification `mention_drop`
- [ ] ทดสอบ Mention Permission ผ่านทั้ง 2 เส้นทาง: Drop ปกติ (RLS policy) และ Poll Drop (`create_poll_drop()` RPC) — ยืนยันทั้งคู่ถูก gate เหมือนกัน ไม่มีเส้นทางไหนเลี่ยงได้
- [ ] ผู้ใช้ตั้ง Comment Permission = "คนที่ฉันติดตาม" → บัญชีที่ตนไม่ได้ติดตาม คอมเมนต์ Drop/Pop ของผู้ใช้ไม่ได้ (insert ถูกปฏิเสธด้วย RLS)
- [ ] Comment Permission ไม่กระทบการคอมเมนต์ใน Club Post เลย (ยืนยัน regression — สมาชิก Club ที่ approved ยัง comment ได้ปกติไม่ว่า post author จะตั้ง comment_permission เป็นอะไร เพราะ policy คนละตัวกัน)
- [ ] Regression เต็มชุด: ผู้ใช้ที่ไม่เคยแตะการตั้งค่าทั้ง 3 (ค่า default `everyone` ทั้งหมด) ใช้งาน DM/Mention/Comment เหมือนก่อน task นี้ทุกประการ ไม่มีอะไรเปลี่ยน
- [ ] Block relationship (WYN-027) ยังทำงานแยกอิสระจาก permission ใหม่นี้เสมอ (คนที่ Block กันไม่มีทาง DM/Mention/Comment กันได้เลยไม่ว่า permission จะตั้งเป็นอะไร)

**Requirements ที่ตัดสินใจไม่ทำในรอบนี้ (Product decision, ไม่ใช่ backlog ที่ลืม)**:

**Account section** (Master Spec section 35: Username/Email/Phone/Password/Account Type) — **ไม่ทำ**: WYN V1.0.0 ไม่มีระบบ Password เลย (Auth ใช้ Social Login + Phone OTP เท่านั้นตาม DECISIONS.md 2026-08-13) ไม่มี field ให้ตั้งค่า "Password" จริง — Email/Phone edit ต้องพึ่ง Google OAuth/Apple Developer/Twilio ที่ Founder ยังไม่ได้ตั้งค่าจริง (ยืนยันจาก roadmap's ส่วน E "งานที่ Founder ยังต้องทำเอง") ทำ UI ไปตอนนี้จะเป็นปุ่มที่กดแล้วไม่มีอะไรทำงานจริง — Username edit ทับซ้อนกับ Edit Profile ที่มีอยู่แล้วจาก WYN-003/013 ถ้าต้องการจริงควรต่อยอดหน้าเดิมไม่ใช่สร้างใหม่ใน Settings — "Account Type" ตีความแล้วซ้ำกับ Private Account toggle ที่มีอยู่แล้ว (WYN-039) ไม่มี concept อื่นที่ต่างออกไปในสเปกทั้งฉบับ

**Security section** (Master Spec section 29/35: Sessions/Devices/Login History) — **ไม่ทำ**: ต้องมี session-tracking infrastructure ใหม่ทั้งชุด (device fingerprint, per-session revoke) ที่ไม่มีอยู่เลยในระบบตอนนี้ เป็นงานสถาปัตยกรรมคนละขนาดจากงาน Settings ทั่วไป — เสนอเป็น task แยกในอนาคตถ้า Founder ต้องการ (ไม่ผูกกับ Phase 5)

**Data section** (Master Spec section 35/47: Download Data, Delete Account) — **ไม่ทำ**: ทับซ้อนตรงกับ WYN-047 ("Data rights (Access/Correction/Deletion/Export, Account Deletion) — PDPA") ที่วางไว้ใน roadmap Phase 6 อยู่แล้ว ทำตอนนี้จะซ้ำงานและอาจขัดกับการออกแบบ PDPA-compliant flow ที่ WYN-047 ต้องทำอย่างละเอียด

**Legal section** (Master Spec section 35/28: Terms/Privacy/Community Guidelines/Copyright) — **ไม่ทำ**: ทับซ้อนกับ WYN-046 ("Platform documents...") Phase 6 — ไม่มีเนื้อหาเอกสารกฎหมายจริงให้ลิงก์ไปหาด้วย (ต้องผ่านผู้เชี่ยวชาญกฎหมายตรวจสอบก่อนตามที่ roadmap ระบุไว้เอง)

**ไม่สร้าง section header ว่างสำหรับ 4 หมวดข้างต้น** — ตาม pattern เดิมของ `settings_screen.dart`'s comment ต้นไฟล์ ("Deliberately not pre-building empty sections... a menu that opens to nothing yet is worse than no menu at all") เมื่อ WYN-046/047 หรือ Security/Account task ในอนาคตทำจริง ค่อยเพิ่ม section ตอนนั้น

**ไม่แตะ/เปลี่ยนชื่อ section "ความปลอดภัย" เดิม** (Blocked/Muted/รายการที่ลบ, WYN-027/028/037) — ทำงานถูกต้องอยู่แล้ว ไม่มีความจำเป็นต้อง refactor เพื่อความเรียบร้อยของ taxonomy เฉยๆ (RULES.md's Change Control: "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น หลีกเลี่ยง refactor ที่ไม่เกี่ยวข้อง")

Dependencies: WYN-008/013 (`follows`), WYN-027 (`internal.is_blocked_either_way`, block-hides-mention pattern), WYN-031/032 (`get_or_create_conversation`), WYN-021 (`drop_mentions`/`club_post_mentions`), WYN-035 (`create_poll_drop()`), WYN-037 (`drop_comments`/`pop_comments`'s ล่าสุด INSERT policy ที่ต้องต่อยอด), WYN-039 (Privacy section ใน `SettingsScreen` ที่ต้องเพิ่มเข้าไป — ต้นตอของ deferred scope นี้)

Priority: P2 — ปิด explicit deferred debt จาก WYN-039 ไม่ใช่บั๊ก แต่เป็นงานที่ค้างไว้ชัดเจนแล้วรอทำต่อตาม roadmap Phase 5

Risks:
- **DM "คนที่ฉันติดตาม" เปลี่ยนพฤติกรรมจาก "เข้าคิว pending request" เป็น "ปฏิเสธทันที"** สำหรับผู้ใช้ที่เลือกระดับนี้ — ต่างจาก Instagram ที่ยังให้ส่ง request ได้เสมอแค่ซ่อนไว้ในโฟลเดอร์ request แยก แต่ Product ตัดสินใจให้ "คนที่ฉันติดตาม" หมายถึงบล็อกจริงไม่ใช่แค่ซ่อน เพื่อให้ 3 ระดับมีความหมายต่างกันชัดเจน (ถ้าอนุญาตให้ยังส่ง pending request ได้เสมอไม่ว่า permission จะตั้งเป็นอะไร ระดับ "คนที่ฉันติดตาม" กับ "ทุกคน" จะแทบไม่ต่างกันเลยจากมุมมองผู้ส่ง) — ถ้า Founder ต้องการพฤติกรรมแบบ Instagram (ยังส่งได้เสมอแค่ซ่อน) ต้องแจ้งเพื่อปรับก่อน Design เริ่ม
- **Mention/Comment Permission ไม่ทำงานย้อนหลัง** — เนื้อหาที่ mention/comment ไปแล้วก่อนตั้งค่าไม่ถูกลบ/ซ่อนย้อนหลัง (เหมือนที่ Private Account/Block เดิมก็ไม่ย้อนหลังเช่นกัน สอดคล้อง pattern เดิมทั้งโปรเจกต์)

Recommendation: ทำต่อเนื่องตาม roadmap Phase 5 ทันที (ปิด Phase 5 ให้ครบทั้ง 3 task) — ส่งต่อ AI Design ออกแบบ UI ตัวเลือก 3 ระดับ (แนะนำ radio-button bottom sheet หรือหน้าย่อยแยก ไม่ใช่ toggle แบบ Private Account เพราะมี 3 ค่าไม่ใช่ 2) สำหรับทั้ง 3 การตั้งค่าในหน้า `SettingsScreen`'s "ความเป็นส่วนตัว" section เดิม

Handoff: AI Design — ออกแบบวิธีเลือก 3 ระดับต่อการตั้งค่า (3 การตั้งค่า × 3 ตัวเลือก) ในหน้า `SettingsScreen` ที่มีอยู่แล้ว ตำแหน่งต่อจาก Private Account toggle เดิมในหัวข้อเดียวกัน "ความเป็นส่วนตัว" — เลือกรูปแบบ UI ที่ชัดเจนว่าเป็นการตั้งค่าแยกจาก DM/Mention/Comment ปกติของแอปอื่น ไม่ทับศัพท์ Layout ตรงๆ

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-044 ท้ายไฟล์): 3 คอลัมน์ใหม่บน `profiles` (`dm_permission`/`mention_permission`/`comment_permission`, `text not null default 'everyone'`, check 3 ค่า) + helper 2 ตัวใหม่ `internal.mention_allowed`/`internal.comment_allowed` (มิเรอร์กันเป๊ะ แยกฟังก์ชันตาม Design's เหตุผล) — gate ที่ 3 กลุ่มจุดตาม Design spec: (1) `get_or_create_conversation()` แก้ inline ในสาขา "ไม่มีบทสนทนาเดิม" เท่านั้น (บทสนทนาเดิมไม่กระทบ) (2) `drop_mentions`/`club_post_mentions`'s INSERT policy ล่าสุด + `create_poll_drop()`'s `where` clause (ครบทั้ง 2 เส้นทางตามที่ Design เตือนไว้ชัดเจนว่าห้ามพลาดเหมือนที่เกือบเกิดกับ WYN-044) (3) `drop_comments`/`pop_comments`'s INSERT policy ล่าสุด (WYN-037) เท่านั้น — **ไม่แตะ** `club_post_comments` ตามที่ Product ล็อกไว้

**SQL test ใหม่** (`supabase/tests/wyn_045_privacy_controls_test.sh`) — 20 checks ครอบ DM (people_i_follow/no_one/existing-conversation-immunity), Mention (ทั้ง RLS ปกติและ `create_poll_drop()` RPC), Comment (people_i_follow บล็อกจริง + Club independence) — **20/20 PASS** (รันซ้ำเองอิสระ) — รันซ้ำ SQL regression ทั้ง 19 สคริปต์ (รวม `wyn_044` เวอร์ชันหลัง debug fix) **ผ่านหมดไม่มี cross-task regression** (รันซ้ำเองอิสระ) — `check_schema_ordering.py` ผ่าน (รันซ้ำเองอิสระ)

**Flutter**: `Profile` model เพิ่ม `InteractionPermission` enum + 3 field ใหม่ (default `everyone` ทุก call site เดิมคอมไพล์ผ่านไม่ต้องแก้), `ProfileRepository` เพิ่ม 3 update method มิเรอร์ `updateIsPrivate`, `SettingsScreen` เพิ่ม 3 แถวใหม่ + `_PermissionSettingTile`/`_showPermissionPicker` (pseudo-radio bottom sheet มิเรอร์ `report_sheet.dart` เป๊ะ ไม่ใช้ `RadioListTile`), `ViewProfileScreen` thread ค่าใหม่เข้า `SettingsScreen` เหมือน `isPrivate` — เทสต์ใหม่ครอบ default/picker-checkmark/update-success/revert-on-fail

**Merge note (orchestrator)**: Coding agent เริ่มงานจาก commit ก่อน WYN-044's debug fix (`81d11b6`) เพราะรันคู่ขนานกับ Debug Engineer — ตอน merge กลับ `schema.sql` มี conflict จริงที่บรรทัดเดียวกับที่ debug fix แก้ (`internal.notification_enabled`'s grant/revoke) เพราะ WYN-045 ต่อท้ายส่วนนั้นพอดี แก้ด้วยมือ (เก็บ `revoke` ของ debug fix ไว้ ตามด้วยส่วน WYN-045 ทั้งหมด) แล้วรัน regression ทั้งหมดซ้ำอิสระยืนยันไม่มีอะไรพัง

**Build/Tests (ยืนยันโดย orchestrator หลัง merge, ไม่ใช่แค่เชื่อ Coding Output)**: `flutter analyze` **0 issues**, `flutter test` **678/678 PASS** (รวมทั้ง WYN-044's `notification_settings_screen_test.dart` ที่กลับมาเขียวหลัง debug fix และเทสต์ใหม่ของ WYN-045), SQL 19/19 สคริปต์ผ่านหมด, `check_schema_ordering.py` ผ่าน — Flutter SDK มีอยู่แล้วใน sandbox นี้ (ติดตั้งไว้ก่อนหน้าโดย QA agent ของ WYN-044) ไม่ใช่ gap เหมือนที่ Coding คาดไว้ตอนแรก

**Known Issue/Gap (ตั้งใจ ไม่ใช่บั๊ก)**: DM Permission ระดับ "คนที่ฉันติดตาม" เปลี่ยนพฤติกรรมจาก "เข้าคิว pending request" เป็น "ปฏิเสธทันที" ตามที่ Product ตัดสินใจไว้แล้วใน Risks (ไม่ใช่ Instagram-style ที่ยังส่งได้เสมอแค่ซ่อน)

Handoff: AI QA & Security — เน้นตรวจ: **(ก) Mention Permission ทั้ง 2 เส้นทาง** (RLS ปกติ + `create_poll_drop()` RPC) ว่า gate จริงทั้งคู่ไม่มีเส้นทางเลี่ยงได้, **(ข) DM existing-conversation immunity** (บทสนทนาเดิมก่อนตั้งค่าไม่ถูกกระทบย้อนหลัง), **(ค) Club Post comment ไม่ถูกกระทบเลย** จาก Comment Permission แม้แต่นิดเดียว, **(ง) regression เต็มชุดของ WYN-044** (โดยเฉพาะจุดที่เพิ่ง fix จาก QA รอบก่อน) ยังผ่านหลัง merge
