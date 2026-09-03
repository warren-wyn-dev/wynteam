# Design Spec — WYN-097 (Audience Selector + เพื่อน + เพื่อนที่สนิท) + WYN-099 Addendum (Likes Privacy)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-097.md`, `.wyn/tasks/backlog/WYN-099.md`, `.wyn/docs/product/wyn-097-audience-friends.md`, `.wyn/docs/product/wyn-099-likes-privacy.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/drop/presentation/create_drop_screen.dart` (`_AudienceChip` static widget บรรทัด ~1016-1039, toolbar), `app/lib/features/follow/presentation/follow_list_screen.dart` (pattern list+search+row ที่ reuse), `app/lib/features/settings/presentation/settings_screen.dart` (`_PermissionSettingTile`/`_showPermissionPicker` บรรทัด ~783-900, `_PrivacyScreen`), `app/lib/features/profile/presentation/widgets/privacy_notice_banner.dart`, `app/lib/features/home/presentation/widgets/home_drop_card.dart` (author row + more-menu)
Design system: `WynColors`/`WynSpacing`/`WynTypography` เดิมทั้งหมด — **สี = Sapphire `#1B3A6B` (`WynColors.sapphire`, เทียบเท่า `Theme.of(context).colorScheme.primary`) / paper `#FAF9F6` / ink `#12120F` / graphite `#8A8880` / hairline `#E8E6E0` / mutedNeutral `#B7B4AC` ตาม `app/lib/core/design/wyn_colors.dart` ปัจจุบัน (Sapphire era, re-brand 2026-08-29)** — ตรวจตรงจากไฟล์นี้แล้ว ไม่ใช้ค่าจาก `ds-001-color-system.md` (Cyan, เอกสารเก่าที่ถูกแทนที่แล้ว) ไม่มี token สีใหม่ในเอกสารนี้ทั้งหมด

> **สถานะการตัดสินใจของ Founder**: นิยาม "เพื่อน" = mutual follow **เป็นมติสุดท้ายแล้ว** (`.wyn/company/DECISIONS.md`, 2026-09-02, "Phase 3 AI PM full-spec pass เสร็จ — Founder ยืนยัน 2 จุดที่ scope เปลี่ยน") — ไม่ใช่ข้อเสนอที่รอยืนยันอีกต่อไปตามที่ backlog เดิม/product spec เดิมเคยเขียนไว้ก่อนหน้า เอกสารนี้เดินหน้าออกแบบตามนิยามนี้โดยไม่ต้องถาม popup ซ้ำ

---

## Screen 1 — Create Drop: Audience Selector Trigger (แทนที่ `_AudienceChip` เดิม)

**Purpose:** เปลี่ยน chip "ทุกคน ⌄" จาก static label (ไม่ทำงาน) ให้เป็นปุ่มที่กดแล้วเปิด Audience Selector Sheet จริง และอัปเดต label ตามค่าที่เลือกไว้

**User Flow:** ผู้ใช้เปิด `CreateDropScreen` → เห็น chip แสดงค่าปัจจุบัน (ค่าเริ่มต้น "ทุกคน") → แตะ chip → เปิด Screen 2 (bottom sheet) → เลือกตัวเลือก → sheet ปิด → chip อัปเดต label ทันที → กด "แชร์" ตามปกติ ค่า audience ที่เลือกถูกส่งไปพร้อม `DropRepository.createDrop()`

**Components:**
- แทนที่ `_AudienceChip` (StatelessWidget, ไม่มี state) ด้วย widget ใหม่ที่รับ `AudienceOption value`/`VoidCallback onTap` — รูปทรง/สี/ระยะห่างเดิมทุกประการ (`Container` พื้น `Color(0xFFF1EFE9)`, `border: Border.all(color: WynColors.hairline)`, `borderRadius: BorderRadius.circular(WynSpacing.radiusFull)`, `Row` ข้อความ+`Icons.keyboard_arrow_down`) — **เปลี่ยนแค่ text ให้ตรงกับ label ของตัวเลือกที่เลือกไว้** (ทุกคน/เพื่อน/ซ่อนเพื่อนบางคน/เพื่อนที่สนิท/เฉพาะฉัน) ไม่เพิ่มไอคอนใหม่ในตัว chip เอง (คงความเรียบ ไอคอนอยู่แค่ในตัว sheet)
- ห่อด้วย `InkWell`/`GestureDetector` แทน `Container` เปล่า เพื่อรับ `onTap`

**Interactions:** แตะ chip → เปิด Screen 2 (`showModalBottomSheet`) → เลือกตัวเลือกใน sheet ปิดทันที (ไม่ต้องกด "ยืนยัน" แยก ยกเว้นตัวเลือกที่พาไปหน้าอื่นต่อ — ดู Screen 2)

**States:** ค่าเริ่มต้นของโพสต์ใหม่ทุกครั้งคือ "ทุกคน" (ตรงกับ default ของ DB คอลัมน์ `audience`) — ไม่จำโพสต์ก่อนหน้า (แต่ละโพสต์เลือกใหม่เสมอ ตาม Out of Scope ของ product spec ที่ไม่มี "จำค่าเดิม")

**Responsive Behavior:** chip ความกว้างตาม content (`MainAxisSize.min` เดิม) ไม่ยืด ไม่ตัดคำที่ label ยาวสุด ("ซ่อนเพื่อนบางคน" ยาวที่สุด — ทดสอบว่า toolbar row ไม่ overflow ที่ 360px)

**Accessibility:** `Semantics(label: 'เลือกกลุ่มผู้ชมโพสต์ ตอนนี้เลือก $currentLabel', button: true)`

**Design Rules:** ไม่เพิ่ม token สีใหม่ — คง container/border/radius เดิมของ `_AudienceChip` เป๊ะ

**Handoff:** AI Coding — เปลี่ยน `_AudienceChip` เป็น stateful field ใน `_CreateDropScreenState` (`AudienceOption _audience = AudienceOption.everyone`), ส่งเข้า `DropRepository.createDrop()` เป็น parameter ใหม่ (`audience`, `excludedFriendIds` เมื่อเป็น `friendsExcept`) — ดู data model เต็มที่ Product spec

---

## Screen 2 — Audience Selector Bottom Sheet (5 ตัวเลือก)

**Purpose:** ให้ผู้ใช้เลือกว่าใครเห็นโพสต์นี้ได้ จาก 5 ตัวเลือกตามที่ Founder ระบุ

**User Flow:** เปิดจาก Screen 1 → เห็น sheet 5 แถว → แตะแถวหนึ่ง:
- "ทุกคน"/"เพื่อน"/"เฉพาะฉัน" → เลือกทันที, sheet ปิด, กลับไป Screen 1 ที่มี chip อัปเดตแล้ว
- "ซ่อนเพื่อนบางคน" → sheet ปิด → push Screen 3 (เลือกเพื่อนที่จะซ่อน) ทันที
- "เพื่อนที่สนิท" (ยังไม่เคยตั้งลิสต์เลย) → sheet ปิด → push Screen 4 (จัดการเพื่อนที่สนิท) พร้อมข้อความต้อนรับ; (เคยตั้งลิสต์แล้ว) → เลือกทันทีเหมือน "ทุกคน"/"เพื่อน" ไม่ต้องพาไปหน้าจัดการซ้ำทุกครั้ง

**Components:** ใช้โครงสร้างเดียวกับ `_showPermissionPicker` ของ `settings_screen.dart` เป๊ะ (drag handle 32×4 สีเทา + หัวข้อ + ปุ่มปิด (X) มุมขวาบน + list แถว) **ต่างจาก permission picker ตรงที่แต่ละแถวมี icon+subtitle เพิ่ม** (ตาม product spec's UI requirement):
```
[drag handle]
ใครเห็นโพสต์นี้ได้บ้าง                    [X]

(●) 🌐 ทุกคน
     ทุกคนเห็นโพสต์นี้ได้

( ) 👥 เพื่อน
     เฉพาะเพื่อนของคุณเท่านั้นที่เห็นได้

( ) 🚫 ซ่อนเพื่อนบางคน                    ›
     เพื่อนทุกคนเห็นได้ ยกเว้นคนที่คุณเลือกซ่อน

( ) ⭐ เพื่อนที่สนิท                       ›
     เฉพาะเพื่อนที่สนิทที่คุณเลือกไว้เท่านั้น

( ) 🔒 เฉพาะฉัน
     เห็นเฉพาะคุณคนเดียว
```
- แต่ละแถว: `ListTile(contentPadding: EdgeInsets.zero, leading: Icon(...), title: Text(label), subtitle: Text(description), trailing: ...)` — leading icon ใช้ set เดียวกับที่แอปใช้ทั่วระบบ (`_outlined` variant ทุกตัว): ทุกคน = `Icons.public`, เพื่อน = `Icons.people_outline`, ซ่อนเพื่อนบางคน = `Icons.person_off_outlined`, เพื่อนที่สนิท = `Icons.star_outline`, เฉพาะฉัน = `Icons.lock_outline`
- ตัวบอกสถานะเลือก: มิเรอร์ `_showPermissionPicker` เป๊ะ — `Icons.radio_button_checked`/`radio_button_unchecked` วางเป็น trailing ตัวแรกสำหรับ "ทุกคน"/"เพื่อน"/"เฉพาะฉัน" สี `Theme.of(context).colorScheme.primary` เมื่อ selected (**ไม่ใช้ `RadioListTile`** — เหตุผลเดียวกับที่ `_showPermissionPicker` มีบันทึกไว้แล้วเรื่อง Flutter version)
- "ซ่อนเพื่อนบางคน"/"เพื่อนที่สนิท": trailing เป็น `Icons.chevron_right` แทน radio (สื่อว่าพาไปหน้าอื่นต่อ ไม่ใช่เลือกจบในสเต็ปเดียว) — ถ้าตัวเลือกนี้ถูกเลือกอยู่แล้ว (audience ปัจจุบัน = ค่านี้) ให้โชว์ทั้ง radio (checked, สี primary) และ chevron คู่กัน (บอกทั้งสถานะ "เลือกอยู่" และ "แตะเพื่อแก้ไขรายชื่อ")

**Interactions:** แตะแถวใดก็ตาม → sheet ปิดทันที (ไม่มีปุ่ม "ยืนยัน" แยกสำหรับ 3 ตัวเลือกแรก — ตรงกับ pattern เดิมของ `_showPermissionPicker`) ยกเว้น 2 ตัวเลือกที่ต่อ flow ไปหน้าอื่น (ดู User Flow)

**States:** ตัวเลือก "เพื่อนที่สนิท" แถวย่อย subtitle เปลี่ยนเป็น "คุณมี N คนในลิสต์" แทน description เดิม เมื่อเคยตั้งลิสต์ไว้แล้ว (N > 0) — ช่วยให้ผู้ใช้รู้สถานะโดยไม่ต้องกดเข้าไปดู

**Responsive Behavior:** sheet ความสูงยืดตาม content (`mainAxisSize: MainAxisSize.min` เหมือน `_showPermissionPicker`) — 5 แถว+subtitle ยาวกว่า 3 แถวเดิมของ permission picker ทดสอบว่าไม่ล้นจอที่ความสูงจอเตี้ยสุด (เช่น SE) ถ้าล้นให้ `SingleChildScrollView` ครอบ list ส่วน (ไม่ครอบ header)

**Accessibility:** แต่ละแถว `Semantics(label: '$label — $description', selected: option == currentValue, excludeSemantics: true)` มิเรอร์ `_showPermissionPicker` เป๊ะ

**Design Rules:** โครงสร้าง sheet (drag handle/title/close button) **ต้อง reuse ตรงจาก `_showPermissionPicker` ไม่ประดิษฐ์ใหม่** — ส่วนที่ต่างคือ icon+subtitle ต่อแถวเท่านั้น

**Handoff:** AI Coding — เพิ่ม `AudienceOption` enum ใหม่ (`everyone`/`friends`/`friendsExcept`/`closeFriends`/`onlyMe`) มิเรอร์ shape ของ `InteractionPermission` เดิม (WYN-045) แต่แยก type คนละตัว (ความหมายคนละเรื่อง เหมือนที่ WYN-099's product spec อธิบายไว้แล้วว่าทำไมไม่ reuse `InteractionPermission`) — เขียน `_showAudiencePicker()` ใหม่คู่กับ `_showPermissionPicker` เดิม (ไม่แก้ของเดิม)

---

## Screen 3 — เลือกเพื่อนที่จะซ่อน ("ซ่อนเพื่อนบางคน", multi-select)

**Purpose:** ให้ผู้ใช้เลือกรายชื่อเพื่อน (mutual-follow) ที่จะ**ไม่เห็น**โพสต์นี้ เป็นรายโพสต์ (ไม่ persist ข้ามโพสต์ — คนละเรื่องกับ Close Friends list ที่ persist)

**User Flow:** เปิดจาก Screen 2 → เห็น list เพื่อนทั้งหมด (mutual-follow) พร้อม checkbox → ค้นหา/เลือกได้หลายคน → กด "เสร็จสิ้น (N คน)" ที่มุมขวาบน/ปุ่มล่างสุด → กลับไป Screen 1 พร้อม audience = "ซ่อนเพื่อนบางคน" และ chip แสดง label นั้น

**Components:** reuse โครงหน้าเดียวกับ `FollowListScreen` (AppBar back+title + search bar + `ListView.builder` แถว avatar/ชื่อ/username) **ตัดส่วน tab (ผู้ติดตาม/กำลังติดตาม) ออก** เพราะมีแค่ลิสต์เดียว (เพื่อน mutual-follow ทั้งหมด) — โครงสร้างแถว:
```
[Avatar 21] ชื่อที่แสดง              [ ] Checkbox
             @username
```
- AppBar title: "เลือกเพื่อนที่จะซ่อนโพสต์นี้"
- ปุ่มยืนยันมุมขวาบน AppBar (แทน trailing icon ปกติ): `TextButton` ข้อความ "เสร็จสิ้น (N)" — N = จำนวนที่เลือกไว้ ณ ขณะนั้น (0 = ข้อความ "เสร็จสิ้น" เฉยๆ ไม่มีวงเล็บ) — แตะแล้ว pop กลับพร้อม `Set<String>` รายชื่อที่เลือก
- แต่ละแถวใช้ `CheckboxListTile`-เทียบเท่า (native `Checkbox` เป็น trailing, มิเรอร์ precedent ที่มีอยู่แล้วใน `document_acceptance_screen.dart`'s `CheckboxListTile` — **ไม่ใช่ custom icon toggle** เพราะนี่คือ multi-select จริง ไม่ใช่ single-select แบบที่ `_showPermissionPicker` หลีกเลี่ยง `RadioListTile`) — ทั้งแถวแตะได้ (ไม่ต้องเล็งตรง checkbox พอดี)

**Interactions:** แตะแถว (ที่ไหนก็ได้ในแถว ไม่ใช่แค่ checkbox) → toggle checked/unchecked ทันที — ไม่มี auto-save ทีละคน (ต่างจาก Close Friends ที่ save ทันที — เพราะรายชื่อนี้ยังไม่ commit จนกว่าจะกด "เสร็จสิ้น" และตัวโพสต์เองก็ยังไม่ถูกสร้างจนกว่าจะกด "แชร์" ใน Screen 1)

**States:**
- Loading รายชื่อเพื่อน → skeleton/spinner กลางจอ (มิเรอร์ `FollowListScreen`'s `CircularProgressIndicator` state)
- ไม่มีเพื่อนเลย (mutual-follow ว่าง) → empty state ข้อความ "คุณยังไม่มีเพื่อน (ติดตามกันทั้งสองทาง) ให้เลือก" + ปุ่ม "เสร็จสิ้น" ยังกดได้ (0 คนถูก exclude เท่ากับเลือก "เพื่อน" ธรรมดาไม่มีใครถูกซ่อน — ให้ AI Coding ตัดสินใจว่าจะ block ปุ่มแชร์ต่อในกรณีนี้ไหม ไม่ใช่จุดตัดสินใจของเอกสารนี้ แต่แนะนำไม่ block เพราะไม่ใช่ error state จริง)
- กลับมาจาก Screen 3 ครั้งที่ 2 (เคยเลือกไว้แล้วในเซสชันเดียวกัน ยังไม่กด "แชร์") → checkbox ต้องแสดงสถานะที่เลือกไว้ก่อนหน้า (ไม่รีเซ็ต) — state เก็บไว้ใน `_CreateDropScreenState` (parent) ไม่ใช่ local state ของ Screen 3 เอง

**Responsive Behavior:** search bar+list มิเรอร์ `FollowListScreen` เป๊ะ รองรับ 360-430px เหมือนกัน

**Accessibility:** แต่ละแถว `Semantics(label: '$name, ยูสเซอร์เนม $username, ${checked ? "เลือกซ่อนแล้ว" : "ยังไม่ถูกซ่อน"}', button: true)` ปุ่ม "เสร็จสิ้น" มี label เต็ม "ยืนยัน ซ่อนโพสต์จาก N คน"

**Design Rules:** ใช้โครง `FollowListScreen` เป็นฐาน ไม่ประดิษฐ์ list/search/row ใหม่

**Handoff:** AI Coding — widget ใหม่ `ExcludeFriendsScreen`, ต้องมี repository method ใหม่ `FollowRepository.fetchMutualFollows({page})` (reuse `internal.is_mutual_follow` ฝั่ง backend ผ่าน RPC ใหม่ — ดู Product spec Data Model) — คืนค่า `Set<String>` กลับไปให้ Screen 1 ผ่าน `Navigator.pop<Set<String>>(...)`

---

## Screen 4 — จัดการ "เพื่อนที่สนิท" (Close Friends)

**Purpose:** ให้ผู้ใช้เพิ่ม/ลบรายชื่อ Close Friends แบบถาวร (persist ข้ามโพสต์ เหมือน IG Close Friends) — เข้าถึงได้ 2 ทาง: (1) จาก Screen 2 เมื่อเลือก "เพื่อนที่สนิท" ครั้งแรก (2) จาก Settings > ความเป็นส่วนตัว (Screen 5)

**User Flow:** เปิดหน้านี้ → เห็น list เพื่อนทั้งหมด (mutual-follow) พร้อม toggle → แตะ toggle คนไหน → บันทึกทันที (optimistic, insert/delete แถวใน `close_friends` ทันทีไม่ต้องกด "บันทึก" แยก) → กด back กลับไปที่มา (Screen 2 ต่อ flow โพสต์ หรือ Settings)

**Components:** โครงเดียวกับ Screen 3 (search bar + list avatar/ชื่อ/username) แต่:
- AppBar title: "เพื่อนที่สนิท"
- ไม่มีปุ่ม "เสร็จสิ้น (N)" ที่ AppBar (เพราะบันทึกทันทีทีละคน ไม่ใช่ batch-confirm แบบ Screen 3)
- trailing ต่อแถวเป็น `Switch.adaptive` แทน `Checkbox` (สื่อความหมาย "เปิด/ปิดสถานะถาวร" ต่างจาก "เลือกสำหรับโพสต์นี้ครั้งเดียว" ของ Screen 3 — มิเรอร์ precedent `SwitchListTile` ที่ `_PrivacyScreen`'s "บัญชีส่วนตัว" ใช้อยู่แล้ว) สี ON = `WynColors.sapphire`/`colorScheme.primary` (ค่าเริ่มต้นของ Material `Switch` เมื่อ theme ตั้ง `primary` ไว้แล้วอยู่แล้ว ไม่ต้อง override เพิ่ม)
- เมื่อเปิดจาก Screen 2 เป็นครั้งแรก (ยังไม่เคยมีใครในลิสต์เลย): แสดง banner เล็กด้านบนสุดของ list (ก่อนแถวแรก, ไม่ blocking) ข้อความ **"คุณยังไม่มีเพื่อนที่สนิท เลือกจากรายชื่อเพื่อนของคุณได้เลย"** — สไตล์เดียวกับ `PrivacyNoticeBanner` ที่มีอยู่แล้ว (พื้น `colorScheme.surfaceContainer`, ไอคอน `Icons.info_outline`, ไม่มีปุ่มปิด X เพราะข้อความนี้หายไปเองเมื่อมีคนอยู่ในลิสต์แล้ว ไม่ใช่ dismiss ด้วยมือ)

**Interactions:** แตะ Switch → toggle ทันที (optimistic UI, cancel/revert ถ้า API fail พร้อม Snackbar "ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง" — มิเรอร์ pattern error handling ของ `_removeFollower` ใน `FollowListScreen`)

**States:**
- Empty (ไม่มีเพื่อนเลย, mutual-follow ว่าง) → "คุณยังไม่มีเพื่อน (mutual follow) ให้เลือก" ตรงตาม product spec เป๊ะ
- Loading → spinner กลางจอ
- ค้นหาไม่พบ → "ไม่พบผู้ใช้ที่ตรงกับ \"...\"" (มิเรอร์ `FollowListScreen` เป๊ะ)

**Responsive Behavior:** เหมือน Screen 3

**Accessibility:** แต่ละแถว `Semantics(label: '$name, ${isOn ? "อยู่ในรายชื่อเพื่อนที่สนิท" : "ไม่อยู่ในรายชื่อเพื่อนที่สนิท"}', toggled: isOn)`

**Design Rules:** โครง list/search เดียวกับ Screen 3 เพื่อความสม่ำเสมอ ต่างแค่ trailing widget (Switch แทน Checkbox) ตามเหตุผล semantic ข้างต้น

**Handoff:** AI Coding — widget ใหม่ `CloseFriendsScreen`, repository method ใหม่ `addCloseFriend`/`removeCloseFriend`/`fetchCloseFriends` ผูกกับตาราง `close_friends` (RLS ตาม Product spec: insert ต้องเป็น mutual-follow เท่านั้น, select/delete จำกัดเจ้าของ)

---

## Screen 5 — Settings > ความเป็นส่วนตัว: แถวใหม่ "เพื่อนที่สนิท"

**Purpose:** ทางเข้าที่สองสู่ Screen 4 (นอกจากผ่าน Audience Selector ตอนโพสต์)

**Components:** เพิ่มแถวใหม่ใน `_PrivacyScreen`'s `ListView` — **วางไว้ทันทีหลังแถว "บัญชีส่วนตัว (Private Account)" ก่อนกลุ่ม 3 แถว dm/mention/comment permission** (จัดกลุ่มตามความหมาย: "ใครเห็นอะไรของคุณ" อยู่ด้วยกัน ก่อน "ใครโต้ตอบกับคุณได้") — รูปแบบ `ListTile` ธรรมดา (ไม่ใช่ `_PermissionSettingTile` เพราะไม่ใช่ 3-way picker แต่เป็นทางเข้าไปอีกหน้า) มิเรอร์ `_LegalDocumentTile`'s shape (icon+title+chevron, ไม่มี trailing summary):
```
⭐  เพื่อนที่สนิท                    ›
    จัดการรายชื่อเพื่อนที่สนิทของคุณ
```
- `leading: Icon(Icons.star_outline)`, `title: Text('เพื่อนที่สนิท')`, `subtitle: Text('จัดการรายชื่อเพื่อนที่สนิทของคุณ')`, `trailing: Icon(Icons.chevron_right)`

**Interactions:** แตะแถว → push `CloseFriendsScreen` (Screen 4) ตรง ไม่มี banner ต้อนรับ (banner แสดงเฉพาะทางเข้าจาก Audience Selector ตอนยังไม่เคยตั้งลิสต์ — ทางเข้านี้ผู้ใช้ตั้งใจเข้ามาจัดการเอง ไม่ต้องมีข้อความต้อนรับซ้ำ)

**States/Responsive/Accessibility:** เหมือนแถวอื่นใน `_PrivacyScreen` ทุกประการ (ไม่มีอะไรพิเศษ)

**Design Rules:** ใช้รูปแบบ `ListTile` เดียวกับ `_LegalDocumentTile` เป๊ะ ไม่ประดิษฐ์ใหม่

**Handoff:** AI Coding — เพิ่ม 1 `ListTile` ใน `_PrivacyScreen.build()`'s `ListView`

---

## Screen 6 — ปุ่ม "รีโพสต์" ถูกซ่อนเมื่อ audience ≠ "ทุกคน" (ไม่ใช่หน้าจอใหม่ — Design note สำหรับจุดที่มีอยู่แล้ว)

**Purpose:** ตาม Product spec's Edge Case 2 (requirement ใหม่ที่ AI PM เพิ่มเอง ยังไม่ผ่าน Founder ยืนยันตรงๆ — ดู Handoff รวมท้ายเอกสาร): ซ่อนปุ่มรีโพสต์ทั้งหมดเมื่อโพสต์ต้นฉบับมี `audience != 'everyone'` เพื่อกันความสับสนเรื่อง privacy ตอน reshare

**Components:** จุดที่ต้องแก้คือปุ่ม/เมนู "รีโพสต์" ที่มีอยู่แล้วใน `HomeDropCard`'s action row และ more-menu (`_openMoreMenu`) และจุดเทียบเท่าใน `DropDetailScreen` — **ไม่สร้าง UI ใหม่ แค่เพิ่มเงื่อนไข `if (item.audience == AudienceOption.everyone)` ครอบปุ่ม/แถวเมนูที่มีอยู่แล้ว** (เหมือน pattern ที่ `_isOwnFollowersList` ใช้ครอบปุ่ม "ลบ" ใน `FollowListScreen` — conditional render ปุ่มที่มีอยู่แล้ว ไม่ใช่ widget ใหม่)

**Interactions/States:** ปุ่มหายไปเลย (ไม่ใช่ disabled/เทา) — ตรงกับหลัก "ซ่อนเองอัตโนมัติ" ที่ระบบใช้อยู่แล้วกับปุ่ม "เพิ่มรูป" ครบ 9 รูป (WYN-071 Screen 2)

**Design Rules:** ไม่มี UI ใหม่ในหัวข้อนี้ — เป็นแค่เงื่อนไข render

**Handoff:** AI Coding — เพิ่มเงื่อนไขที่ทุกจุดที่แสดงปุ่ม/action "รีโพสต์" (ทั้ง action row หลักและใน more-menu ถ้ามีซ้ำ 2 จุด) — **หมายเหตุสำคัญ**: requirement นี้เป็นข้อเสนอของ AI Product Manager เอง ยังไม่ผ่าน Founder ยืนยันตรงๆ (ดู Product spec R4) — AI Design เห็นด้วยกับแนวทางนี้ในแง่ UX (ปลอดภัยที่สุด ป้องกันความสับสน) แต่ไม่ใช่อำนาจของ AI Design ที่จะปิดเรื่องนี้เอง — แนะนำให้ AI Coding/Founder ยืนยันอีกครั้งก่อน deploy จริง (ไม่ block การเริ่ม implement เพราะเป็น safe-default ที่ revert ง่ายถ้า Founder ไม่เห็นด้วยภายหลัง)

---

## WYN-099 Addendum — Likes Tab Privacy Setting

Data model/RPC เต็มอยู่ใน `.wyn/docs/product/wyn-099-likes-privacy.md` — ส่วนนี้ออกแบบเฉพาะ UI 2 จุดตามที่ product spec ระบุ (ขอบเขตเล็กกว่า WYN-097 มาก ใช้ `internal.is_mutual_follow()` เดียวกันจาก Screen ด้านบน)

### Addendum Screen A — Settings > ความเป็นส่วนตัว: แถวใหม่ "ใครเห็นสิ่งที่คุณถูกใจได้"

**Purpose:** ให้ผู้ใช้ตั้งค่าการมองเห็นแท็บ "ถูกใจ" บนโปรไฟล์ตัวเอง (ทุกคน/เพื่อน/เฉพาะฉัน)

**Components:** แถวใหม่ **ที่ 4 ต่อท้าย 3 แถว `_PermissionSettingTile` เดิม** (dm/mention/comment) ใน `_PrivacyScreen` — reuse โครง `_PermissionSettingTile` เป๊ะ (icon+title+subtitle, trailing = label ปัจจุบัน+chevron):
```
❤️  ใครเห็นสิ่งที่คุณถูกใจได้        ทุกคน  ›
    ควบคุมว่าใครเห็นแท็บถูกใจบนโปรไฟล์ของคุณ
```
- `leading: Icon(Icons.favorite_border)` (ไอคอนเดียวกับ tab "ถูกใจ" ที่ `wyn-071` ใช้อยู่แล้ว — ความสม่ำเสมอ), `title`/`subtitle` ตรงตาม product spec copy เป๊ะ
- เปิด picker แยกใหม่ (คนละ type จาก `InteractionPermission`/`AudienceOption` — ดู Design Rules) โครงเดียวกับ `_showPermissionPicker`/Screen 2 ของเอกสารนี้: drag handle + title "ใครเห็นสิ่งที่คุณถูกใจได้" + close (X) + 3 แถว (ทุกคน/เพื่อน/เฉพาะฉัน) พร้อม icon+description ต่อแถว (`Icons.public`/`Icons.people_outline`/`Icons.lock_outline` — ใช้ icon set เดียวกับ Screen 2 ของ audience selector เพื่อความสม่ำเสมอของความหมาย "ทุกคน/เพื่อน/เฉพาะฉัน" ทั่วทั้งแอป)

**Interactions:** แตะแถว → เปิด picker → แตะตัวเลือก → บันทึกทันที (optimistic, มิเรอร์ `_setPermission` เดิม) → sheet ปิด → trailing label อัปเดต

**States:** ค่าเริ่มต้น "ทุกคน" (ตรงกับ default ของ `profiles.likes_visibility` ใน DB — ไม่มี regression กับผู้ใช้เดิมทุกคน)

**Responsive/Accessibility:** เหมือน `_PermissionSettingTile`/`_showPermissionPicker` เดิมทุกประการ

**Design Rules:** **ไม่ reuse `InteractionPermission` enum เดิม** (ความหมายคนละแบบตามที่ product spec อธิบายไว้ — `people_i_follow` ≠ mutual friend) ต้องมี enum ใหม่ `LikesVisibility` (`everyone`/`friends`/`onlyMe`) แยกจาก `AudienceOption` ของ WYN-097 เอง ด้วย (คนละบริบท แม้ค่าจะดูคล้ายกัน — `AudienceOption` มี 5 ค่า `LikesVisibility` มีแค่ 3)

**Handoff:** AI Coding — เพิ่ม `LikesVisibility` enum ใหม่, `_LikesVisibilitySettingTile` (มิเรอร์ `_PermissionSettingTile` แต่ type ต่างกัน), `_showLikesVisibilityPicker()` ใหม่ (มิเรอร์ `_showPermissionPicker` แต่ type/label ต่างกัน), เพิ่มแถวในตำแหน่งที่ 4 ของ `_PrivacyScreen`'s ListView

### Addendum Screen B — โปรไฟล์: แท็บ "ถูกใจ" — Empty State เมื่อไม่มีสิทธิ์ดู + อัปเดตข้อความ Banner

**Purpose:** เมื่อคนอื่นเปิดโปรไฟล์เราแล้วไม่มีสิทธิ์ดูแท็บถูกใจ (ตาม `likes_visibility` ที่ตั้งไว้) ให้เห็น empty state แทนเนื้อหาจริง — และ banner แจ้งเตือนเดิม (`PrivacyNoticeBanner`) ต้องอัปเดตข้อความให้ตรงกับสถานะจริง

**Components:**
- Empty state ใหม่ (แสดงแทนที่ list โพสต์ที่ถูกใจ เมื่อ `internal.can_view_likes()` = false): `Center` + `Padding` + `Text('บัญชีนี้ซ่อนรายการที่ถูกใจไว้')` — มิเรอร์ shape เดียวกับ empty state อื่นๆ ของแอป (`FollowListScreen`'s empty text pattern) ไม่ใช่ error banner สีแดง (นี่ไม่ใช่ error เป็นพฤติกรรมที่ตั้งใจ)
- `PrivacyNoticeBanner` เดิม (แสดงเฉพาะเจ้าของโปรไฟล์ตัวเอง ตาม WYN-071 Screen 7 เดิม) — ข้อความเปลี่ยนตาม `likes_visibility` ปัจจุบัน:
  - `everyone` (เดิม) → คงข้อความเดิม "คนอื่นเห็นสิ่งที่คุณกด Like ได้เหมือนกัน"
  - `friends` → "เฉพาะเพื่อนของคุณเท่านั้นที่เห็นแท็บนี้ได้"
  - `onlyMe` → "เฉพาะคุณเท่านั้นที่เห็นแท็บนี้"

**Interactions:** ไม่มี action ใน empty state (ไม่ใช่ error ที่ retry ได้ — เป็นสถานะที่ตั้งใจแบบถาวรจนกว่าเจ้าของจะเปลี่ยนตั้งค่าเอง)

**States:** เจ้าของโปรไฟล์เปิดดูของตัวเองเสมอเห็นเนื้อหาจริง (ไม่ว่าตั้งค่าอะไร — `p_viewer = p_target` check ก่อนเสมอตาม Product spec)

**Accessibility:** empty state text อ่านได้ปกติด้วย screen reader (ไม่ต้อง label พิเศษเพิ่ม เป็น plain text)

**Design Rules:** ไม่มี UI ใหม่ที่ซับซ้อน — reuse pattern empty state ที่มีอยู่แล้วทั่วแอป

**Handoff:** AI Coding — `ProfileLikesTab` เช็คผลจาก `fetch_liked_drops`/`fetch_liked_pops` RPC ใหม่ (คืนค่าว่างเปล่าเมื่อไม่มีสิทธิ์ — ตาม Product spec, RPC เองเป็นคนกรองไม่ใช่ client) แต่ **ต้องแยกแยะ "ว่างเพราะไม่มีสิทธิ์" กับ "ว่างเพราะยังไม่เคยกด Like เลย"** สอง empty state นี้ข้อความต่างกัน (เดิม "ยังไม่เคยกด Like" ของ RPC เปล่าจริงๆ ยังคงข้อความเดิมของระบบ — เพิ่มแค่ empty state ใหม่สำหรับกรณี privacy-blocked) — วิธีแยกสองเคสนี้ (เช่น เรียก `internal.can_view_likes` แยกก่อน หรือ flag พิเศษจาก RPC) ให้ AI Coding ตัดสินใจตามความเหมาะสมทางเทคนิค ไม่ใช่จุดตัดสินใจของเอกสารนี้

---

## Handoff รวม (WYN-097 + WYN-099)

ส่งต่อ **AI Coding** (`/code`) — Screen 1-6 (WYN-097) + Addendum A-B (WYN-099) พร้อม implement ได้ทันที ลำดับแนะนำ: Screen 2 (sheet, ไม่มี schema dependency ของ Screen 3/4) → data model/RLS ของ Product spec (audience column, close_friends, drop_audience_exclusions, `is_mutual_follow`/`can_view_drop_audience`) → Screen 1/3/4/5 (ผูกกับ data model) → Screen 6 (เล็ก, ไม่มี schema) → WYN-099 Addendum A/B (ใช้ `is_mutual_follow` ร่วมกับ WYN-097 อยู่แล้ว ทำต่อเนื่องกันได้เลยตามที่ Product spec แนะนำ)

**สิ่งที่ยังไม่ปิดจ๊อบ (ไม่ block การเริ่ม Coding แต่ต้องแจ้ง Founder ตามที่ Product spec ระบุไว้):**
- Screen 6 (ซ่อนปุ่มรีโพสต์เมื่อ audience ≠ 'everyone') เป็น requirement ใหม่ที่ AI PM เสนอเอง ยังไม่ผ่าน Founder ยืนยันตรงๆ — เดินหน้า implement ได้เลยในฐานะ safe-default แต่ต้อง flag ให้ Founder เห็นอีกครั้งก่อน deploy จริง

**นิยาม "เพื่อน" = mutual follow ปิดจ๊อบแล้ว** (Founder ยืนยันมติสุดท้ายใน DECISIONS.md 2026-09-02) — ไม่มีจุดค้างอื่นที่ต้องถาม Founder ก่อนเริ่ม Design/Coding ตามที่ตรวจสอบแล้ว
