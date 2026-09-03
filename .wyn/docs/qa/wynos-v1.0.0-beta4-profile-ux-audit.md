# WYNOS v1.0.0 Beta4 — Profile UX/UI Audit

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta4-master-implementation-j5lke8` — push ขึ้น feature branch แล้ว · **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ขอบเขต: Beta4 §1 (Profile UX/UI), §2 (Account Switching entry point), §3 (Other User Profile), §4 (Saved), §5 (Draft), §12 (Profile Navigation)
> Environment: Flutter 3.47.1 — SDK ตัวเดียวกับที่ `ci.yml` และ `deploy-web.yml` pin ไว้ · Deno 2.x สำหรับ Edge Function
> **ไม่มี Supabase production credential ใน session นี้** — ทุกข้อความในเอกสารชุด Beta4 ติดป้ายว่าตรวจที่ไหน

---

## 0. สรุปสั้น

| | จำนวน |
|---|---|
| ข้อที่ Beta4 §1-§5, §12 ขอ | 6 หัวข้อ |
| ทำครบ | 6 |
| บั๊กที่เจอระหว่างทำ (ไม่ได้อยู่ในโจทย์) | 3 — overflow 2 จุดที่ 320px, touch target 40px 1 จุด |
| ไฟล์ที่แก้ในกลุ่มนี้ | `view_profile_screen.dart`, `create_drop_screen.dart`, `drafts_screen.dart` (ใหม่), `draft_list.dart` (ย้ายมาจาก `profile/`) |

---

## 1. Profile Header — สิ่งที่เปลี่ยน และทำไม

### สภาพก่อน Beta4 (WYN-095 "Mockup A", Beta2)

```
┌────────────────────────────────┐
│ 👤   ผู้ติดตาม │ กำลังติดตาม │ โพสต์   │   ← avatar + 3 stats อยู่แถวเดียวกัน
│                                │
│ ชื่อที่แสดง                      │   ← ชื่ออยู่ "ใต้" ทั้งสองอย่าง
│ @username                      │
│ Bio                            │
│                                │
│ [แก้ไขโปรไฟล์] 🔖 📝            │   ← ปุ่ม + ไอคอน Saved/Draft ที่ไม่มีป้ายกำกับ
└────────────────────────────────┘
```

ปัญหาที่พบจากการอ่านโครงสร้างจริง (ไม่ได้เดา):

1. **ตัวตนถูกแยกเป็นสองโซน** — รูปหน้าคุณอยู่ข้างตัวเลขสองตัว ส่วนชื่อคุณอยู่ใต้ตัวเลขนั้น โดยไม่มีอะไรยึดโยงกัน คนอ่านต้องกวาดสายตาเป็นตัว Z เพื่อประกอบว่า "รูปนี้ + ชื่อนี้ = คนเดียวกัน"
2. **`_load()` ยิง 4 query** — `fetchProfile` + `countFollowers` + `countFollowing` + `countByAuthor` ขนานกันด้วย `Future.wait` (ดีอยู่แล้ว) แต่ query ที่ 4 มีไว้แสดงเลข "โพสต์" ซึ่ง Beta4 §1 บอกให้เอาออก
3. **Saved / Draft เป็นไอคอนเปล่า** — `Icons.bookmark_border` และ `Icons.edit_note_outlined` ข้างปุ่มแก้ไขโปรไฟล์ ไม่มีข้อความบอกว่าคืออะไร มีแค่ `Semantics(label:)` สำหรับ screen reader

### สภาพหลัง Beta4

```
┌────────────────────────────────┐
│ 👤   ชื่อที่แสดง ⌄               │   ← ชื่ออยู่ "ข้าง" รูป และเป็นปุ่มสลับบัญชี
│      @username                 │
│                                │
│      Bio                       │
│                                │
│      กำลังติดตาม │ ผู้ติดตาม     │   ← 2 stat เท่านั้น
│                                │
│      [   แก้ไขโปรไฟล์   ]       │   ← เต็มความกว้างคอลัมน์
├────────────────────────────────┤
│  โพสต์  │  รีโพสต์  │  ถูกใจ    │
└────────────────────────────────┘
```

ทุกอย่างที่บอกว่า "นี่คือใคร" อยู่ในคอลัมน์เดียวข้างรูป เรียงจากบนลงล่างตามลำดับที่คนอ่านจริง: ชื่อ → @ → bio → คนติดตาม → ปุ่ม

**หลักฐาน:** `test/view_profile_screen_test.dart` — "Beta4 §1: avatar on the left, and the whole identity column (name, username, stats, action) to its right, in that order" วัดพิกัดจริงของทุกองค์ประกอบ

### Profile Stats — เอา "โพสต์" ออก

Beta4 §1: "แสดงเฉพาะ Following / Followers. ไม่เพิ่ม: จำนวนโพสต์"

| | ก่อน | หลัง |
|---|---|---|
| stat ที่แสดง | ผู้ติดตาม / กำลังติดตาม / โพสต์ | กำลังติดตาม / ผู้ติดตาม |
| ลำดับ | Followers ก่อน | **Following ก่อน** (ตามภาพร่างของ Founder) |
| query ต่อการเปิดโปรไฟล์ 1 ครั้ง | 4 | **3** |

`DropRepository.countByAuthor` ไม่ได้ถูกลบ — ยังมีที่เรียกใช้อื่น เพียงแต่หน้านี้เลิกเรียก

**หมายเหตุที่ตรงไปตรงมา:** ตัวเลข "โพสต์" ไม่ได้ผิด มันแค่ซ้ำกับสิ่งที่แท็บ "โพสต์" ด้านล่างบอกอยู่แล้วด้วยการมีหรือไม่มีเนื้อหา และเบียดพื้นที่ stat ที่เหลืออีกสองตัวจนล้นจอเล็ก (ดู §5 ของเอกสารนี้)

---

## 2. Account Switching (§2) — "ชื่อที่แสดง ⌄"

### ระบบเดิมที่มีอยู่ (ไม่ได้สร้างใหม่)

ตรวจก่อนแตะ — `AccountSwitcherRepository` + `AccountSwitcherSheet` มีอยู่ครบตั้งแต่ Beta2:

* เก็บได้สูงสุด 5 บัญชี/เครื่อง
* refresh token เก็บใน platform Keychain/Keystore (`flutter_secure_storage`) ไม่ใช่ `shared_preferences`
* `switchTo()` ไม่เรียก `signOut()` โดยตั้งใจ — แม้แต่ `SignOutScope.local` ก็ revoke refresh token ฝั่ง server ซึ่งจะทำลายสิ่งที่ quick-switch อาศัยอยู่
* `startSyncingActiveSession` ใน `main.dart` คอย sync token ที่หมุนอัตโนมัติ

**Beta4 ไม่แตะ logic นี้เลยแม้แต่บรรทัดเดียว** สิ่งที่เปลี่ยนคือ *ทางเข้า*

### ทางเข้า: ก่อน → หลัง

| | ก่อน | หลัง |
|---|---|---|
| เส้นทาง | Profile → ⚙️ ตั้งค่า → บัญชี → สลับบัญชี | Profile → แตะชื่อตัวเอง |
| จำนวนแตะ | 3 | 1 |
| เห็นได้จากหน้าโปรไฟล์ไหม | ไม่ | เห็น (⌄ ข้างชื่อ) |

เหตุผลที่ย้าย: สิ่งที่ถูกสลับคือ *ตัวตนที่เขียนอยู่บนหัวหน้าจอนี้* การซ่อนมันไว้ในหน้า "ค่าที่ตั้งได้" ทำให้คนหาไม่เจอ

### รายละเอียดที่ตรวจแล้ว

| ข้อกำหนด §2 | สถานะ | หลักฐาน |
|---|---|---|
| แสดงเฉพาะ Own Profile | ✅ | `isOwnProfile` gate ที่ call site — test: "someone else's profile has no account switcher" |
| Profile คนอื่นไม่มีปุ่มนี้ | ✅ | test เดียวกัน ยืนยันทั้ง key และ `Icons.keyboard_arrow_down` ไม่มี |
| สื่อชัดว่าใช้เปลี่ยนบัญชี | ✅ | Semantics label = `"$name, แตะเพื่อสลับบัญชี"` — test: "the semantics say what it does, not just the name" |
| Switching เปลี่ยน Account Context ถูกต้อง | ✅ | ดูเอกสาร account-switching-audit §2 (RootShell key) |
| ห้ามข้อมูลบัญชีเดิมค้างใน UI | ✅ | **นี่คือบั๊กจริงที่เจอและแก้** — ดูเอกสาร account-switching-audit §1 |

### Touch target

ชื่อ + chevron เป็น tap target เดียว สูง ≥ 44px (`WynSpacing.touchTargetMin`) ไม่ใช่แค่ตัว chevron 22px — chevron เดี่ยวๆ จะต่ำกว่ามาตรฐานของ design system เอง 50% และคนที่จะสลับบัญชีเล็งไปที่ *ชื่อ* ไม่ใช่ลูกศร

**หลักฐาน:** test "the whole name+chevron is one tap target, at least touchTargetMin tall"

---

## 3. Other User Profile (§3)

| ข้อกำหนด | สถานะ | หมายเหตุ |
|---|---|---|
| `[ ติดตาม ] [ ส่งข้อความ ]` | ✅ ไม่เปลี่ยน | มีมาตั้งแต่ WYN-095 แล้ว — Beta4 แค่ย้ายเข้าไปอยู่ในคอลัมน์ตัวตนเหมือนองค์ประกอบอื่น |
| ใช้ Messaging System เดิม | ✅ | `ChatRepository.getOrCreateConversation` (WYN-031) — **ไม่ได้สร้างระบบ chat ใหม่** ตามที่ §3 ห้ามไว้ |
| ไม่มี Account Switcher | ✅ | ดู §2 ข้างบน |
| Follow State ถูกต้อง | ✅ ไม่เปลี่ยน | `_isFollowing` 3 สถานะ (ติดตาม / กำลังติดตาม / ขอติดตามแล้ว) ยังทำงานเหมือนเดิม รวม optimistic toggle + rollback |

**Persona ที่ตรวจครบ** (ไม่ได้เปลี่ยนพฤติกรรม แค่ย้ายตำแหน่งใน layout):

* Own profile → แก้ไขโปรไฟล์ (+ คำขอติดตาม ถ้าเป็นบัญชีส่วนตัวและมีคำขอค้าง)
* Other, public → ติดตาม + ส่งข้อความ
* Other, private, ยังไม่ติดตาม (Locked) → ปุ่มเดิม + grid ว่างพร้อมข้อความอธิบาย
* Blocked (ทางใดทางหนึ่ง) → banner แทน stats และปุ่มทั้งหมด

---

## 4. Saved (§4) และ Draft (§5) — ย้ายออกจาก Profile

### Saved

**ระบบเดิม:** `SavedRepository` + `BookmarksScreen` (15-bookmarks.tsx)
**Beta4 เปลี่ยนอะไร:** ไม่มีอะไรในระบบเลย — แค่เอาไอคอน `bookmark_border` ออกจากหน้าโปรไฟล์

**ข้อสังเกตที่สำคัญ:** ทางเข้าที่ §4 ขอ (`Home → ☰ → บันทึกไว้`) **มีอยู่แล้วตั้งแต่ WYN-100** ใน `SideMenu` — และมันเปิด `BookmarksScreen` ตัวเดียวกันกับที่ไอคอนบนโปรไฟล์เคยเปิด งานที่เหลือจึงเป็นแค่การเอาทางเข้าที่ซ้ำและไม่มีป้ายกำกับออก ไม่ใช่การสร้างทางเข้าใหม่

`ProfileSavedTab` (grid 3 คอลัมน์ คนละตัวกับ `BookmarksScreen`) ถูกทิ้งไว้ในโค้ดโดยไม่มีใครเรียก — posture เดียวกับ `ProfilePopGridTab`/`ProfileRepliesTab` ที่ unmount แต่ไม่ลบ

### Draft

**ระบบเดิม:** `DropDraft` + `DropRepository.fetchDrafts/deleteDraft` + `DraftGridTile` + prefill flow ใน `CreateDropScreen` (WYN-036)

**Beta4 เปลี่ยนอะไร:**

| | ก่อน | หลัง |
|---|---|---|
| ทางเข้า | Profile → ไอคอน `edit_note` (ไม่มีป้าย) | สร้างโพสต์ → ปุ่ม **"ร่าง"** (มีทั้งไอคอนและคำ) |
| ไฟล์อยู่ที่ไหน | `features/profile/presentation/widgets/profile_drafts_tab.dart` | `features/drop/presentation/widgets/draft_list.dart` |
| หน้าที่ห่อ | `Scaffold(appBar: AppBar(title: Text('ร่าง')))` สร้าง inline ในโปรไฟล์ | `DraftsScreen` — AppBar แบบเดียวกับหน้าอื่นใน composer flow |
| Empty state | ประโยคเปล่ากลางจอ | `EmptyStateBlock` ตัวเดียวกับ Notifications / Chat Inbox / Bookmarks |

เหตุผลของตำแหน่งใหม่: ร่างคือโพสต์ที่ยังไม่เสร็จ มันไม่เคยเป็นของหน้าที่มีหน้าที่แสดง "สิ่งที่คุณโพสต์ไปแล้ว" — และที่ที่คนกลับมาเขียนร่างต่อ กับที่ที่คนเขียนร่างครั้งแรก คือที่เดียวกัน

**Behaviour ที่ตรวจแล้วว่าไม่เปลี่ยน:** Create / Save / Open / Edit / Continue — `draft_list_test.dart` (เดิมชื่อ `profile_drafts_tab_test.dart`) ผ่านครบโดยแก้แค่ชื่อ class

**รายละเอียดที่คิดเผื่อ:** ปุ่ม "ร่าง" ซ่อนตัวเองเมื่อ composer นั้น *เป็น* ร่างที่เปิดมาอยู่แล้ว (`_draftId != null`) — ไม่งั้นจะซ้อนหน้าเดิมทับตัวเอง และซ่อนเมื่อบัญชีถูก Restrict ด้วยเหตุผลเดียวกับที่ปุ่มโพสต์ถูก disable

---

## 5. บั๊กที่เจอระหว่างทำ (ไม่ได้อยู่ในโจทย์)

ทั้งสามข้อนี้ **test ที่เขียนตาม §14 เป็นคนเจอ ไม่ใช่การอ่านโค้ด** — บันทึกไว้เพราะนี่คือเหตุผลที่ §14 ขอให้ตรวจ responsive

### B4-P1 — stats row ล้นจอ 200px ที่ 320px

* **อาการ:** `A RenderFlex overflowed by 200 pixels on the right` — แถบเหลือง-ดำพาดทับ stats
* **เงื่อนไข:** จอกว้าง 320px (iPhone SE gen 1) + ตัวเลขหลักแสน
* **สาเหตุ:** stat ทั้งสองใช้ความกว้างตามเนื้อหา (natural width) + divider ที่มี margin ข้างละ 16px รวมแล้วต้องการ ~370px แต่คอลัมน์ตัวตนข้าง avatar กว้างจริงแค่ ~170px
* **แก้:** `Expanded` ทั้งสอง stat, divider margin 16→12, และ `FittedBox(scaleDown)` ที่ตัวเลขและป้าย (เป็น no-op ตั้งแต่ 360px ขึ้นไป — ย่อเฉพาะตอนที่ไม่มีทางพอจริงๆ)
* **หมายเหตุ:** layout เดิม (3 stat) ก็มีปัญหานี้อยู่แล้ว Beta4 ทำให้มันแคบลงอีกเพราะย้าย stats เข้าไปในคอลัมน์ — จึงถือว่าเป็นความรับผิดชอบของ Beta4 ที่จะแก้

### B4-P2 — header ล้นความสูงจอ 102px เมื่อ bio ยาว

* **อาการ:** `A RenderFlex overflowed by 102 pixels on the bottom`
* **เงื่อนไข:** จอสูง 568px + bio ยาว
* **สาเหตุ:** body ของหน้านี้คือ `Column([header, TabBar, Expanded(TabBarView)])` — header **ไม่ scroll** ถ้ามันสูงเกิน viewport ก็ล้น
* **แก้:** จำกัด bio ที่ 4 บรรทัด + ellipsis
* **ทางเลือกที่ *ไม่* เลือก:** ทำ header ให้ scroll ไปพร้อมเนื้อหา (`NestedScrollView`) — เป็นการเปลี่ยนโครงหน้าจอทั้งหน้า ซึ่ง §0 ห้าม "Rewrite Architecture โดยไม่มีเหตุผล" การจำกัดบรรทัด bio เป็นพฤติกรรมปกติของ social app และปิดปัญหาได้จริง

### B4-P3 — ปุ่ม "ร่าง" มี touch target 40px

* **สาเหตุ:** `visualDensity: VisualDensity.compact` ลบ 8px ออกจาก `minimumSize` ที่ตั้งไว้ 44 → เหลือ 40
* **แก้:** เอา `visualDensity` ออก
* **บทเรียน:** `minimumSize: Size(0, 44)` ไม่รับประกัน 44 ถ้ามี `visualDensity` อยู่ด้วย — ต้องวัด ไม่ใช่ประกาศ

---

## 6. Profile Navigation (§12)

ตรวจเส้นทาง `Profile → Followers/Following → User Profile → Back`:

| ข้อกำหนด | ผล | หมายเหตุ |
|---|---|---|
| Navigation เป็นธรรมชาติ | ✅ | `_openFollowList` push `FollowListScreen` ด้วย mode ที่ถูก — test เดิมยังผ่าน |
| Context ไม่หาย | ✅ | Navigator เดียว push ทับ — โปรไฟล์เดิมยังอยู่ใน stack |
| Back ถูกต้อง | ✅ | `Navigator.pop` ปกติ |
| ไม่โหลดซ้ำโดยไม่จำเป็น | ✅ **ตรวจแล้วไม่พบปัญหา** | กลับจาก FollowListScreen ไม่ทำอะไรเลย — `_openFollowList` เป็น `await push` เปล่าๆ ไม่มี `_reload()` ต่อท้าย |
| State/Scroll รักษาไว้ | ✅ | ไม่มีการ rebuild หน้าโปรไฟล์ตอน pop |

**Locked private:** กด Followers/Following บนโปรไฟล์ส่วนตัวที่ยังไม่ได้ติดตาม → SnackBar "ต้องติดตามก่อนถึงจะดูรายชื่อได้" แทนที่จะเปิดลิสต์เปล่า (พฤติกรรมเดิม WYN-039 ไม่เปลี่ยน)

**สิ่งเดียวที่ทำ `_reload()` ตอน pop:** กลับจาก Edit Profile, Settings, Follow Requests — ทั้งสามอย่างเปลี่ยนข้อมูลที่ header แสดงจริง จึงสมเหตุสมผล

---

## 7. สิ่งที่ตรวจแล้ว **ไม่พบปัญหา** — ไม่แตะ

บันทึกไว้เพราะ "ตรวจแล้วไม่มีอะไร" มีค่าเท่ากับ "เจอแล้วแก้" ในงาน audit

| จุด | ผลการตรวจ |
|---|---|
| Follow toggle (optimistic + rollback) | ถูกต้องอยู่แล้ว รวม `_isFollowActionInFlight` กันกดซ้ำ |
| Blocked / Muted / Report menu | ครบและถูกต้อง — ย้ายตำแหน่ง banner เท่านั้น |
| Private account + Follow Request badge | ถูกต้อง — เงื่อนไข `isPrivate && _pendingRequestCount > 0` ไม่เปลี่ยน |
| Profile Visit signal (`recordProfileVisit`) | ยิงเฉพาะโปรไฟล์คนอื่น ถูกต้องอยู่แล้ว |
| Likes tab privacy banner (WYN-099) | ข้อความตรงกับ `likesVisibility` จริง 3 ค่า ไม่เปลี่ยน |
| Skeleton / error state | `ProfileSkeleton` + ปุ่มลองใหม่ ยังทำงาน |
| Avatar decode bound | `AvatarCircle` bound ตาม radius × DPR อยู่แล้วตั้งแต่ Beta3 |
| แท็บ 3 อัน (โพสต์/รีโพสต์/ถูกใจ) | ไม่เปลี่ยน — Pop/Replies ยัง unmount ตามเดิม |

---

## 8. Known Issues / ที่ยังไม่ได้ทำ

| # | เรื่อง | ความรุนแรง | เหตุผลที่ยังไม่ทำ |
|---|---|---|---|
| K-1 | Profile header ไม่ scroll ไปกับเนื้อหา — ถ้า bio ยาวมากบนจอเตี้ย จะเห็นแท็บถูกดันชิดขอบล่าง | ต่ำ | ปิดอาการล้นด้วยการจำกัด bio 4 บรรทัดแล้ว การทำ `NestedScrollView` คือการเปลี่ยนโครงหน้าจอ ควรเป็น task แยกที่ Founder อนุมัติ |
| K-2 | `ProfileSavedTab` / `ProfilePopGridTab` / `ProfileRepliesTab` อยู่ในโค้ดโดยไม่มีใครเรียก | ต่ำ (dead code) | posture ของโปรเจกต์คือ unmount ไม่ลบ (ดู DECISIONS.md) — การลบต้องขออนุมัติ |
| K-3 | ยังไม่ได้ทดสอบบนอุปกรณ์จริง | — | ไม่มี device/production credential ใน session นี้ ทุกผลข้างบนมาจาก widget test ที่วัดพิกัดและขนาดจริงใน Flutter test binding |
