# Design — WYN-123 (Club Channels)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-123-club-channels.md` และ roadmap ที่ `.wyn/docs/product/wyn-club-discord-style-roadmap.md` — อ่านก่อนเริ่ม
> **สถานะ**: Design เสร็จแล้ว (Founder อนุมัติให้ทำตอนนี้ได้) — **AI Coding ห้ามเริ่มจนกว่า WYN-115–118 จะเสร็จครบ** ตามที่ Product ระบุไว้ตรงๆ ใน spec

## แก้ไขข้อมูล design system ที่ใช้อ้างอิง (สำคัญ ก่อนอ่านต่อ)

ระหว่างเตรียมงานนี้ พบว่า `.wyn/docs/design/ds-001-color-system.md` (dark theme + Cyan accent) **ล้าสมัยไปแล้ว** — Founder อนุมัติเปลี่ยนทิศทางสีเป็น **Sapphire `#1B3A6B`** (accent เดียวของทั้งแอป) ตั้งแต่ 2026-08-29 (`.wyn/company/DECISIONS.md`) และแอปเป็น **light-only theme** จริง (`WynApp` บังคับ `ThemeMode.light`, WYN-071) ไม่ใช่ dark+cyan อย่างที่ DS-001 เขียนไว้ — เอกสารนี้เจอปัญหาเดียวกับที่ WYN-095's postmortem เตือนไว้ตรงๆ: "โค้ดจริงคือความจริงสูงสุด ไม่ใช่เอกสารที่เขียนไว้ก่อนหน้า" จึงอ่าน token จริงจาก `app/lib/core/design/wyn_colors.dart`/`wyn_typography.dart`/`wyn_spacing.dart` แทน ไม่ใช้ค่าจาก DS-001

Token ที่ใช้จริงในงานนี้ (คัดลอกจากโค้ด ไม่ใช่เอกสารเก่า):
- **สี**: `sapphire #1B3A6B` (accent เดียว — ปุ่มหลัก/active state/badge), `paper #FFFFFF` (พื้นหลัง), `ink #12120F` (ตัวหนังสือหลัก), `graphite #8A8880` (ตัวหนังสือรอง), `faint #C7C4BC`, `hairline #E8E6E0` (เส้นแบ่ง/ขอบ), `surfaceTint #F1EFE9` (พื้นผิวเรียบสำหรับ element ที่ไม่ต้องเด่น เช่น icon-in-circle ของ empty state), `mutedNeutral #B7B4AC` (label ตัวพิมพ์ใหญ่เล็กๆ)
- **ตัวอักษร**: system font ล้วน (ไม่มี Fraunces/Inter/`google_fonts` แล้ว — ถูก revert 2026-08-30) — ใช้ `WynTypography.textTheme`/`screenTitle()` ตามเดิม
- **Spacing/Radius**: ตาม `WynSpacing` (`space1`=4 ... `space12`=48, `radiusMd`=12, `radiusFull`=999, `touchTargetMin`=44, `touchTargetRecommended`=48) — ไม่เปลี่ยนจาก DS-001 ในส่วนนี้ ยังใช้ได้ตรง

ทุก component ในงานนี้ **reuse widget/pattern ที่มีอยู่แล้วในโค้ด Club ปัจจุบัน** (`ActionSheetRow`/`ActionSheetBody`, `EmptyStateBlock`'s icon-in-tint-circle language, pill chip ที่ header ใช้อยู่แล้ว, `AlertDialog` confirm pattern, optimistic-update-then-revert pattern) — ไม่มีจุดใดที่คิด component ใหม่จากศูนย์

---

## Screen 1 — Club Page, Posts Tab: Channel Switcher

**Purpose**: ให้สมาชิกสลับดู Channel ต่างๆ ภายใน Club เดียว โดยไม่แตะโครงสร้าง navigation หลักของ Club (TabBar บนสุด "โพสต์/สมาชิก/เกี่ยวกับ" ยังมี 3 tab เท่าเดิม — Channel เป็นแนวคิด**ภายใน tab โพสต์เท่านั้น** ตรงกับ R5 ที่บอกว่า Channel ไม่ใช่มุมมองระดับ Club/Home ใหม่)

**User Flow**: เปิด Club → tab "โพสต์" (default) → ถ้า Club มีมากกว่า 1 Channel จะเห็นแถบ chip เลื่อนแนวนอนอยู่ใต้ TabBar ทันที เหนือลิสต์โพสต์ → เลือก channel ที่โหลดมาก่อน (ตัวแรกตาม sort_order เดิม ปกติคือ "ทั่วไป") ถูกเลือกไว้ล่วงหน้า → แตะ chip อื่น → ลิสต์โพสต์รีโหลดใหม่ตาม channel ที่เลือก, ปุ่ม FAB (สร้างโพสต์) ผูกกับ channel ที่เปิดอยู่ตาม, เลื่อนกลับขึ้นบนสุด

**Components**:
- Chip ทรง pill (radiusFull, สูง 36px ในตัว + padding ให้ tap area ถึง 44px) — **ไม่ selected**: พื้น `hairline`, ตัวหนังสือ `graphite` (มิเรอร์ pill ป้าย category ที่ header ของ ClubPage ใช้อยู่แล้วเป๊ะ) — **selected**: พื้น `sapphire` เต็ม, ตัวหนังสือ `paper` (มิเรอร์ FilledButton ปุ่ม "เข้าร่วม" ที่มีอยู่แล้ว)
- Label = ชื่อ channel (+ emoji นำหน้าถ้ามีตั้งไว้), ถ้า channel เป็น announcement-only เพิ่มไอคอนเล็ก `Icons.campaign_outlined` ต่อท้าย label ใน chip ทุกอัน (ไม่ใช่แค่ selected) เพื่อให้เห็นได้ทันทีว่าห้องไหนโพสต์เองไม่ได้ก่อนจะแตะเข้าไป
- ระยะห่างระหว่าง chip = `space2` (8px), padding ซ้ายขวาของแถว = `space4` (16px) เท่ากับ padding มาตรฐานของหน้าจอ
- **Club ที่มี Channel เดียว: ไม่ render แถบนี้เลย** — ไม่ใช่ซ่อนแบบมีความสูง 0 หรือ disable แต่คือไม่มี widget นี้ในทรีเลย ลิสต์โพสต์หน้าตาเหมือนเดิมทุกพิกเซลกับก่อน WYN-123 — นี่คือคำตอบตรงต่อ requirement "Club เล็กที่มี Channel เดียวต้องไม่รู้สึกเทอะทะ"

**Interactions**: แตะ chip = เลือกทันที ไม่มี long-press ในจุดนี้ (การจัดการ channel อยู่ที่ Screen 2 แยกต่างหาก) — โหลดครั้งแรกเลื่อนแถบให้ chip ที่เลือกอยู่มองเห็นเต็ม (`Scrollable.ensureVisible`) ถ้ามันอยู่นอกจอ

**States**: กำลังโหลด (จองความสูง 44px ไว้เงียบๆ จนกว่าจะรู้จำนวน channel จริง กันหน้าจอกระตุก), error (ไม่ต้อง error state แยก — error ของทั้ง tab ครอบคลุมอยู่แล้วจาก state เดิมของ `ClubPostsTab`), edge case "Club ไม่มี Channel เลย" **เป็นไปไม่ได้ตาม R2** (ทุก Club การันตีมีอย่างน้อย 1 channel เสมอ) จึงไม่ต้องออกแบบ state นี้

**Responsive Behavior**: แถวเดียวเลื่อนแนวนอนเสมอ ไม่ wrap หลายบรรทัด (คุมความสูงให้คงที่)

**Accessibility**: แต่ละ chip มี `Semantics(label: '$ชื่อ Channel ช่อง' + (locked ? ', เฉพาะ Owner/Admin โพสต์ได้' : '') + (selected ? ', กำลังเปิดอยู่' : ''))`

**Design Rules**: ใช้แค่ `sapphire`/`hairline`/`paper`/`graphite` (token ที่มีอยู่แล้ว), `radiusFull` เดิม — ไม่มีสีใหม่

---

## Screen 2 — จัดการ Channel (Owner/Admin): List + Reorder

**Purpose**: ศูนย์กลางจัดการ Channel ของ Owner/Admin — เข้าถึงจากเมนู "..." เดิมของ `ClubPage` (`_openMoreMenu`)

**User Flow**: เมนู "..." → เพิ่มแถวใหม่ "จัดการ Channel" (วางกลุ่มเดียวกับแถวที่ gate ด้วย `role.canManageClub` อยู่แล้ว: แก้ไขข้อมูล Club / เปลี่ยนความเป็นส่วนตัว / จัดการสิทธิ์สมาชิก) → เปิดหน้าจอใหม่ `ManageChannelsScreen` → เห็นลิสต์ channel ทั้งหมดเรียงตาม sort order → ลากด้วย drag handle เพื่อจัดเรียงใหม่ (บันทึกทันทีต่อการลากแต่ละครั้ง) → แตะแถวใดก็เปิด Screen 3 โหมดแก้ไข → ปุ่ม "+ เพิ่ม Channel ใหม่" ท้ายลิสต์เปิด Screen 3 โหมดสร้าง

**Components**:
- Header แบบ `AppBar` ปกติ (back chevron + title "จัดการ Channel", `WynTypography.screenTitle(fontSize: 18)`) — มิเรอร์ shell เดียวกับ `EditClubInfoScreen`
- `ReorderableListView.builder` — แต่ละแถว: ไอคอน `Icons.drag_handle` (สี `graphite`) นำหน้า, ชื่อ channel (+ emoji), แคปชันเล็ก `labelSmall`/`graphite` ใต้ชื่อ "🔒 ประกาศเท่านั้น" เมื่อเป็น announcement-only, ป้าย "เริ่มต้น" (pill เล็กสี `hairline`) ต่อท้ายชื่อของ channel ที่เป็น default, chevron ขวาสุด (แตะ = แก้ไข)
- Divider `hairline` ระหว่างแถว (มิเรอร์ `ActionSheetRow.divider`)
- แถวสุดท้าย "+ เพิ่ม Channel ใหม่": ไอคอน `+` วงกลมพื้น tint (มิเรอร์ภาษาภาพเดียวกับ icon-in-circle ของ `EmptyStateBlock`) + label ธรรมดา ไม่ใช่ dashed-border แบบ cover picker (นั่นคือ pattern สำหรับ "อัปโหลดรูป" ไม่ใช่ "เพิ่มรายการ")

**Interactions**: ลาก-วางแล้วปล่อย → อัปเดตลำดับใน state ทันที (optimistic) + เรียก repository บันทึก sort order จริง → error ค่อย revert ลำดับกลับ + SnackBar "จัดเรียง Channel ไม่สำเร็จ ลองใหม่อีกครั้ง" (รูปแบบเดียวกับ `_togglePin`/`_toggleMute` ที่มีอยู่แล้วใน `club_page.dart`/`club_posts_tab.dart`)

**States**: loading (`CircularProgressIndicator` กลางจอ), error+ปุ่มลองใหม่ (มิเรอร์ pattern เดิมทุกจุดในไฟล์นี้)

**Responsive Behavior**: ลิสต์เลื่อนปกติ, drag handle มี tap area ถึง `touchTargetMin` แม้ตัวไอคอนเล็กกว่า

**Accessibility**: แต่ละแถวมี `Semantics` บอกชื่อ+สถานะ default/locked — ใช้ accessibility action "ย้ายขึ้น/ย้ายลง" ที่ `ReorderableListView` มีให้อัตโนมัติอยู่แล้ว ไม่ override

**Design Rules**: ไม่มีสี/component ใหม่

---

## Screen 3 — สร้าง/แก้ไข Channel (Owner/Admin)

**Purpose**: กำหนดชื่อ, emoji (ทางเลือก), และสถานะ announcement-only ของ channel หนึ่งอัน

**User Flow**: เปิดจาก "+ เพิ่ม Channel ใหม่" (โหมดสร้าง, ทุกช่องว่าง) หรือแตะแถว channel เดิม (โหมดแก้ไข, กรอกค่าเดิมไว้ล่วงหน้า) → กรอกชื่อ (บังคับ) → ใส่ emoji ได้ (ไม่บังคับ) → เปิด/ปิด toggle "เฉพาะ Owner/Admin โพสต์ได้" → กด "สร้าง Channel"/"บันทึก" → pop กลับไปหน้า List, รีโหลดลิสต์

**Components** (มิเรอร์ shell ของ `EditClubInfoScreen` เป๊ะ):
- Text field "ชื่อ Channel" — บังคับ, จำกัด **30 ตัวอักษร** (Design กำหนดเอง เพราะ Product spec ไม่ได้ระบุตัวเลข — ตัวเลขนี้แก้ทีหลังได้โดยไม่กระทบโครงสร้าง เหมือนที่ WYN-116 กำหนด threshold แจ้งเตือนเองแล้วบันทึกเหตุผลไว้)
- Text field "Emoji" (ทางเลือก) — **ช่องกรอกข้อความธรรมดา ไม่ทำ emoji picker grid ใหม่** ผู้ใช้พิมพ์ผ่านแป้นพิมพ์ emoji ของอุปกรณ์เอง (เหมือนที่ `MentionInput`/ช่องคอมเมนต์รับ unicode emoji อยู่แล้วโดยไม่ต้องมี picker) — เลือกทางเลือกที่ scope เล็กสุดตาม Product's ข้อเตือนเรื่อง complexity creep
- แถว `Switch` "เฉพาะ Owner/Admin โพสต์ได้" + แคปชันใต้ `labelSmall`/`graphite`: "สมาชิกทั่วไปจะอ่านได้อย่างเดียว" — สี active ของ Switch ใช้ default ของ theme (สรุปแล้วคือ sapphire อัตโนมัติ ไม่ต้องกำหนดสีเอง)
- **Toggle นี้ถูกซ่อนทั้งแถวเมื่อกำลังแก้ไข channel เริ่มต้น (default channel)** — กติกาที่ Design เพิ่มเอง (ดู "ข้อควรระวังที่ Design เพิ่ม" ท้ายเอกสาร): channel เริ่มต้นห้ามล็อกเป็น announcement-only เด็ดขาด กัน Club ทั้งก้อนไม่มีที่ให้สมาชิกทั่วไปโพสต์เลย
- ปุ่ม "ลบ Channel" (เห็นเฉพาะโหมดแก้ไข **และ** ไม่ใช่ default channel — ถ้าเป็น default ไม่แสดงแถวนี้เลย ไม่ใช่โชว์แบบ disabled) สีแดง (`colorScheme.error`) ตาม convention เดิมของปุ่มทำลายล้างในแอป

**Interactions**: ปุ่มบันทึกกดได้เมื่อชื่อไม่ว่าง (trim) — success = pop คืนค่า `true` (มิเรอร์ `EditClubInfoScreen`), fail = ข้อความ error สีแดงแบบ inline ใต้ฟอร์ม (ไม่ใช่ SnackBar — ตาม convention เดิมของหน้าฟอร์มนี้กลุ่มเดียวกัน) — ลบ channel ต้องมี `AlertDialog` ยืนยันก่อนเสมอ (มิเรอร์ `_confirmLeave`/`_changePrivacy`)

**States**: หัวเรื่องเปลี่ยนตามโหมด ("สร้าง Channel ใหม่" / "แก้ไข Channel"), saving = ปุ่มกดซ้ำไม่ได้ (มิเรอร์ `_isSaving` ของ `EditClubInfoScreen`)

> **หมายเหตุถึง Product/Coding (จุดที่ Product spec ไม่ได้ระบุ ต้องยืนยันก่อนเริ่ม Coding จริง)**: เมื่อลบ channel ที่ไม่ใช่ default แล้ว โพสต์เก่าที่อยู่ใน channel นั้นควรไปไหน? Design เสนอ (ยึดหลักการเดียวกับ R2 ที่ว่า "ห้ามมีโพสต์เดิมหายไปหรือไม่มี Channel สังกัด"): **ย้ายโพสต์ทั้งหมดไปที่ channel เริ่มต้นของ Club อัตโนมัติ ไม่ลบโพสต์เด็ดขาด** ข้อความยืนยันตอนลบต้องบอกตรงๆ ว่า "โพสต์ทั้งหมดใน Channel นี้จะถูกย้ายไปที่ '[ชื่อ Channel เริ่มต้น]' แทน ไม่มีโพสต์ใดถูกลบ" — นี่เป็นข้อเสนอ ไม่ใช่มติสุดท้าย เพราะแตะพฤติกรรมข้อมูลที่ Product ควรยืนยันก่อน ตรงกับที่ spec เองบอกไว้ว่าต้องอ่าน/ยืนยัน assumption ใหม่ก่อนเริ่ม Coding

**Responsive Behavior**: ฟอร์มคอลัมน์เดียวมาตรฐาน

**Accessibility**: Switch มี label ตรงกับแคปชัน, text field มี label มาตรฐาน

**Design Rules**: ไม่มี widget ใหม่ — `TextField`/`Switch`/`AlertDialog`/ปุ่ม ล้วนใช้แบบเดียวกับที่ Club screens อื่นใช้อยู่แล้ว

---

## Screen 4 — Create Post: เลือก Channel ปลายทาง

**Purpose**: ให้ผู้โพสต์เลือกว่าโพสต์นี้จะไปลง channel ไหน โดย default = channel ที่กำลังเปิดดูอยู่ตอนกด FAB

**User Flow**: เปิด composer จาก FAB ของ Screen 1 (ผูกกับ channel ที่เปิดอยู่แล้ว) → chip ปลายทางที่หัวฟอร์ม (จุดเดิมที่ตอนนี้เป็น chip "โพสต์ใน [ชื่อ Club]" ที่แตะไม่ได้) **กลายเป็นแตะได้เมื่อ Club มีมากกว่า 1 channel** → แตะ → เปิด bottom sheet (reuse `ActionSheetBody`/`ActionSheetRow` เดิมเป๊ะ) แสดงเฉพาะ channel ที่ผู้โพสต์คนนี้โพสต์ได้จริง (สมาชิกทั่วไปไม่เห็น channel ที่เป็น announcement-only ในลิสต์นี้เลย ตาม R4 — Owner/Admin เห็นครบทุก channel) → เลือก → chip อัปเดตชื่อ channel ที่เลือก → โพสต์ตามปกติ

**Components**:
- Chip ปลายทาง: รูปแบบเดิมทุกอย่างของ chip "โพสต์ใน [ชื่อ Club]" ที่มีอยู่แล้ว **บวก** ไอคอน chevron-down เล็กต่อท้ายเมื่อแตะได้ (multi-channel) — **Club ที่มี channel เดียว: chip เหมือนเดิมทุกประการ ไม่มี chevron ไม่แตะได้** (อีกจุดที่ยืนยันความ "เบา" ของ Club เล็ก)
- Sheet เลือก channel: `ActionSheetRow` ต่อ channel หนึ่งแถว — ไอคอน = emoji ที่ตั้งไว้ (หรือ `Icons.tag` ถ้าไม่มี), label = ชื่อ channel, แถวที่กำลังเลือกอยู่แสดง `Icons.check` แทน chevron ปกติของแถว (behavior เดิมของ `ActionSheetRow` เอื้อให้ override trailing ได้อยู่แล้ว)

**Interactions**: แตะแถวในชีต = เลือกทันที ปิดชีตทันที ไม่มีปุ่มยืนยันแยก (ตาม convention เดิมของ action sheet ทุกจุดในแอป)

**States**: ไม่มี state พิเศษเพิ่มเติม — โครงสร้าง `_canPost` เดิมของ `CreateClubPostScreen` ไม่เปลี่ยน (channel ที่เลือกเป็นแค่ metadata เพิ่มตอน submit ไม่กระทบเงื่อนไข validate เนื้อหา)

**Design Rules**: 100% reuse `ActionSheetBody`/`ActionSheetRow` — ไม่มี widget ใหม่

---

## Screen 5 — มุมมองสมาชิกทั่วไปใน Channel แบบ Announcement-only

**Purpose**: กำหนดสิ่งที่สมาชิกทั่วไป (ไม่ใช่ Owner/Admin) เห็นเมื่อเปิด channel ที่ล็อกไว้

**User Flow**: แตะ chip ที่มีไอคอนล็อก (Screen 1) → ลิสต์โพสต์โหลดปกติ (อ่านได้เสมอ, R4 จำกัดแค่ "โพสต์ใหม่" ไม่ใช่ "อ่าน") → ปุ่ม FAB **หายไปทั้งหมด** สำหรับผู้เปิดที่ไม่ใช่ Owner/Admin (มิเรอร์ logic เดิมที่ `ClubPostsTab` ซ่อน FAB ให้ผู้ที่ `!_isMember` อยู่แล้ว ขยายเงื่อนไขเพิ่มอีกชั้นคือ `isMember && !canPostInThisChannel`) → ถ้า channel นี้ยังไม่มีโพสต์เลย ใช้ข้อความ empty-state ที่ต่างจากเดิม

**Components**: การ์ดโพสต์/ลิสต์เหมือน channel ปกติทุกอย่าง ไม่มี "chrome ล็อก" อยู่ในฟีดเอง (สื่อสารเรื่องล็อกที่ระดับ chip ใน Screen 1 จุดเดียวพอ ไม่ต้องพูดซ้ำในทุกโพสต์)
- Empty state (เมื่อยังไม่มีโพสต์ **และ** ผู้ดูโพสต์ไม่ได้): เปลี่ยนข้อความจาก "ยังไม่มีโพสต์ใน Club นี้ เป็นคนแรกสิ!" (ชวนให้ผู้ดูโพสต์เอง — ผิดบริบทถ้าโพสต์ไม่ได้) เป็น **"ยังไม่มีประกาศ" / "Owner หรือ Admin ของ Club นี้จะโพสต์ประกาศไว้ที่นี่"**

**Interactions**: ไลค์/คอมเมนต์/บันทึกโพสต์ทำงานปกติทุกจุด (R4 จำกัดแค่ "สร้างโพสต์ใหม่" เท่านั้น ไม่แตะการโต้ตอบกับโพสต์ที่มีอยู่)

**States**: FAB แสดง/ซ่อนตาม role+channel คู่กัน (ไม่ใช่แค่ role อย่างเดียวเหมือนเดิม)

**Accessibility**: ไม่มีสิ่งใหม่นอกจาก label ของ chip ที่ Screen 1 ประกาศไว้แล้วว่า "เฉพาะ Owner/Admin โพสต์ได้"

**Design Rules**: diff น้อยที่สุด — reuse โครง list/FAB/empty-state เดิมของ `ClubPostsTab` ทั้งหมด เพิ่มแค่เงื่อนไข boolean ใหม่ 1 ตัว

---

## Screen 6 (ส่วนต่าง ไม่ใช่หน้าจอใหม่) — Pin ต่อ Channel

**Purpose**: ป้าย/การเรียงลำดับ pinned post ต้องผูกกับ (Club, Channel) ไม่ใช่ Club อย่างเดียว

**สิ่งที่เปลี่ยนจริง**: ไม่มี — พฤติกรรม pinned-first + ป้าย 📌 ที่ `ClubPostsTab` มีอยู่แล้ว (โผล่เหนือโพสต์แรกเมื่อ `post.pinned`) ทำงานถูกต้องเองทันทีที่ query โพสต์เบื้องหลังถูก scope ตาม channel ที่เปิดอยู่ (R3: โพสต์แต่ละอันอยู่ channel เดียวเท่านั้น) — "pin เป็นอันดับแรกภายใน channel นี้" จึงได้มาฟรีจากการ scope query เดิม ไม่ต้องออกแบบ UI ใหม่แม้แต่จุดเดียว — นี่คือเหตุผลที่ R6 ไม่มี Screen ของตัวเอง

---

## ข้อควรระวังที่ Design เพิ่มเองนอกเหนือจาก Product spec (ต้องแจ้ง Product/Coding ก่อนเริ่ม)

1. **Channel เริ่มต้น (default) ห้ามตั้งเป็น announcement-only ได้เด็ดขาด** — Product spec R4 ไม่ได้ระบุข้อจำกัดนี้ตรงๆ แต่ถ้าไม่มีกติกานี้ Owner ที่ล็อกทุก channel ที่มีจะทำให้ Club ทั้งก้อนไม่มีที่ให้สมาชิกทั่วไปโพสต์เลย ขัดกับ spirit ของฟีเจอร์ Club เดิมทั้งหมด — implement เป็นทั้ง UI (ซ่อน toggle ตอนแก้ไข default channel, Screen 3) และควรมี DB constraint คู่กันฝั่ง Coding ไม่ใช่พึ่ง UI อย่างเดียว
2. **ลบ channel ที่ไม่ใช่ default → ย้ายโพสต์เข้า default channel อัตโนมัติ ไม่ลบโพสต์** — ข้อเสนอ ไม่ใช่มติสุดท้าย ต้องยืนยันกับ Product ก่อน Coding เริ่มจริง (ดูรายละเอียดที่ Screen 3)

## Handoff

ส่งต่อ **AI Coding** — แต่**ห้ามเริ่มจนกว่า WYN-115–118 จะเสร็จครบตามที่ Product ระบุไว้** เมื่อถึงคิวจริงให้ Coding ทำตามลำดับนี้ก่อนเขียนโค้ด:

1. อ่านโค้ด Club ปัจจุบันใหม่ทั้งหมด (รวม WYN-115/116/117/118 ที่ deploy ไปแล้วตอนนั้น) ไม่ใช่เชื่อ assumption จากตอนเขียนเอกสารนี้ — โดยเฉพาะตรวจ WYN-116/117 ว่า hardcode "1 Club = 1 stream ของโพสต์" ไว้ที่ไหนบ้างตามที่ Product spec's Risk section เตือนไว้
2. ยืนยันกับ Product 2 จุดที่ Design เสนอเองในหัวข้อ "ข้อควรระวังที่ Design เพิ่มเอง" ด้านบน ก่อนเขียน schema/RLS จริง
3. ไฟล์ที่คาดว่าต้องแตะ: `club_page.dart` (เพิ่ม 1 แถวเมนู "..."), `widgets/club_posts_tab.dart` (state channel ที่เลือกอยู่ + chip row + เงื่อนไข FAB ใหม่), `create_club_post_screen.dart` (chip ปลายทางแตะได้ + sheet เลือก channel), ไฟล์ใหม่ `manage_channels_screen.dart` + `create_edit_channel_screen.dart` (Screen 2/3), repository ใหม่ๆ ฝั่ง `ClubRepository`/`ClubPostRepository` สำหรับ CRUD+reorder channel และ query โพสต์แบบ scope ตาม channel
4. Design system ที่ใช้อ้างอิงคือค่าจริงใน `app/lib/core/design/wyn_colors.dart`/`wyn_typography.dart`/`wyn_spacing.dart` (Sapphire, light-only, system font) **ไม่ใช่** `ds-001-color-system.md` ที่ล้าสมัยแล้ว — ดูหัวข้อแก้ไขด้านบนของเอกสารนี้

หลัง Coding เสร็จ → ส่งต่อ **AI QA & Security** ตามลำดับ workflow ปกติ
