# Design Spec — WYN-071: WYNOS Visual Refresh

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-071-wynos-visual-refresh.md` (Product spec, requirements R2–R8 ทั้งหมด confirm แล้ว), `.wyn/docs/design/ds-001-color-system.md` (สี, อนุมัติแล้ว), `.wyn/docs/design/wyn-013-profile-v2.md` (pattern โปรไฟล์เดิม), `.wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md` (Bottom Nav ปัจจุบัน)

> **ใช้ Design system ที่อนุมัติแล้วทั้งหมด (DS-001–009)** — งานนี้ไม่คิดทิศทางสี/token ใหม่ ทุกสีอ้างจาก `WynColors` เดิม
>
> **ภาพอ้างอิงของ Founder** เป็น screenshot หน้า Profile ของแอป Threads (Meta) — ใช้เป็นแรงบันดาลใจ**เชิงตำแหน่ง/โครงสร้าง**เท่านั้น (Recommendation section อยู่ใต้ปุ่ม action, Tab bar อยู่ใต้นั้น) **ไม่ลอก visual style** (Threads ใช้ text-only tab ไม่มีไอคอน, ใช้ font/spacing ของตัวเอง) — WYNOS คงกติกาเดิมของตัวเองที่วางไว้ตั้งแต่ WYN-013: **tab ทุกอันต้องมี icon+label เสมอ ไม่ใช่ text-only หรือ icon-only**

---

## Screen 1 — App Theme: Fix เป็น Light เสมอ (R2)

Purpose: WYNOS แสดงพื้นหลังขาว/พรีเมียมเป็นค่าเริ่มต้นเสมอ ไม่ตาม dark mode ของเครื่อง (Founder ตัดสินใจแล้ว 2026-08-24)

Components: ไม่มี component ใหม่ — `WynColors.socialLightScheme`/`WynTheme.light` มีอยู่แล้วครบ (DS-001, สีตรงกับที่ Founder ระบุในrequirement เป๊ะ: พื้นขาว/ตัวอักษรดำ `#0A0A0A`/Cyan `#00C8FF` accent)

Design Rules:
- `app/lib/main.dart`: `themeMode: ThemeMode.system` → `ThemeMode.light`
- **อย่าลบ `WynTheme.dark`/`darkTheme:`** ออกจากโค้ด — คงไว้เผื่อ Founder เปลี่ยนใจอนาคต (แค่ผู้ใช้จะไม่มีทางเห็นมันตราบใดที่ `themeMode` fix เป็น light) ตรงกับหลักการ "ไม่ลบของเดิมโดยไม่จำเป็น" ที่ใช้กับ Pop มาก่อนแล้ว (WYN-062)

Handoff: AI Coding — บรรทัดเดียวใน `main.dart`, ไม่มี regression risk

---

## Screen 2 — Create Drop: Multi-image Composer (R3)

Purpose: ให้ผู้ใช้แนบรูปได้ 1–9 รูปต่อ Drop แทนที่ข้อจำกัดรูปเดียวเดิม

User Flow: ผู้ใช้แตะ "เลือกรูป" → เลือกได้หลายรูปพร้อมกัน (multi-select ของ `image_picker`/`file_picker`) หรือเพิ่มทีละรูปซ้ำได้จนครบ 9 → เห็น grid preview ทันที → ลบรูปที่ไม่ต้องการออกได้ทีละรูป → ใส่ caption (ตาม WYN-062 ยังคง optional) → แชร์

Components:
- **Image preview grid**: แถวบนสุดของ Composer (เหนือช่อง caption) — grid responsive ตามจำนวนรูป (1 รูป: เต็มความกว้าง, 2–3 รูป: แถวเดียว, 4+ รูป: 3 คอลัมน์) มิเรอร์ spacing เดียวกับ `DropGridTile` (`WynSpacing`) — แต่ละ thumbnail มีปุ่ม X มุมขวาบน (วงกลมพื้นเข้ม/scrim ทึบ `WynColors.imageScrimStrong` ให้เห็นปุ่มชัดบนรูปทุกสี ตาม token ที่มีอยู่แล้ว) สำหรับลบรูปนั้นออก
- **ปุ่ม "เพิ่มรูป"**: อยู่ท้าย grid เสมอ (เหมือน "+" tile) — ซ่อนเองอัตโนมัติเมื่อครบ 9 รูปแล้ว (ไม่ต้อง disabled state ที่กดไม่ได้ค้างตา — ใช้หลักเดียวกับ WYN-013's "ซ่อน tab อย่างเป็นธรรมชาติ")
- ตัวนับ "3/9" แสดงเล็กๆ ข้างปุ่มเพิ่มรูป เมื่อมีรูปตั้งแต่ 1 รูปขึ้นไป

Interactions:
- เลือกรูปเกิน 9 รูปพร้อมกันในคราวเดียว (เช่น multi-select 12 รูปจาก gallery) → ระบบตัดเหลือ 9 รูปแรกอัตโนมัติ พร้อม Snackbar แจ้ง "เลือกได้สูงสุด 9 รูป ระบบเลือกให้ 9 รูปแรก"
- ลากสลับตำแหน่งรูป (reorder): **ไม่ทำรอบนี้** — ลำดับคือลำดับที่เลือก/ถ่ายเข้ามา (เก็บ scope ให้เล็ก ตรงตามหลัก "แก้เฉพาะที่จำเป็น" — ถ้า Founder ต้องการ reorder ทีหลังค่อยเป็นงานแยก)
- แต่ละรูป compress ก่อน upload ด้วย pattern เดียวกับที่ WYN-005/WYN-003 มีอยู่แล้ว (resize/compress client-side ก่อนส่ง) — วนลูปทำกับทุกรูปใน list

States: 0 รูป (ต้องมี caption ถึงจะแชร์ได้ ตาม WYN-062 เดิม) / 1–9 รูป (แชร์ได้เสมอไม่ว่ามี caption หรือไม่) — validation เดิมจาก WYN-062 (`_canShare`) ยังใช้ได้ แค่เปลี่ยนเงื่อนไข "มีรูป" จาก `imageBytes != null` (ตัวเดียว) เป็น `images.isNotEmpty` (list)

Responsive Behavior: grid preview คำนวณจำนวนคอลัมน์ตามจำนวนรูปเหมือนที่ระบุใน Components — ทดสอบทั้ง 1/2/3/4-9 รูป

Accessibility: ปุ่มลบแต่ละรูปมี `Semantics(label: 'ลบรูปที่ N', button: true)`, ปุ่มเพิ่มรูปมี label บอกจำนวนที่เหลือ ("เพิ่มรูป เหลือได้อีก 6 รูป")

Design Rules: ใช้ `WynSpacing`/`WynColors` เดิมทั้งหมด ไม่มี token ใหม่

Handoff: AI Coding — แก้ `CreateDropScreen`/`DropRepository.createDrop()` ให้รับ `List<Uint8List>` แทน `Uint8List?` เดี่ยว (คง overload/parameter เดิมให้ backward-compatible กับ Poll/text-only mode ที่ไม่มีรูปเลย)

---

## Screen 3 — Drop Rendering: Grid Tile / Home Card / Detail รองรับหลายรูป (R3)

Purpose: ทุกจุดที่เคยแสดง Drop รูปเดียว ต้องแสดง Drop หลายรูปได้ถูกต้อง โดยไม่งานพังกับ Drop รูปเดียว/ไม่มีรูปเดิม (WYN-062 ทำ null-safe ไว้แล้วรอบหนึ่ง ต้องคง behavior นั้นไว้ครบ)

Components:
- **`DropGridTile`/`SavedGridTile` (grid 3 คอลัมน์ใน Profile)**: แสดงรูปแรกเป็น thumbnail เหมือนเดิม + ถ้ามีมากกว่า 1 รูป เพิ่ม**ไอคอนเล็กมุมขวาบน** (stacked-photos icon, `Icons.filter_none` หรือเทียบเท่า ไม่ใช้ badge ตัวเลข เพื่อความเรียบ) บอกว่ามีหลายรูป — ไม่แสดงไอคอนนี้เมื่อมีรูปเดียวหรือไม่มีรูป (ตรงกับ `TextDropPlaceholderTile` เดิมของ WYN-062 ที่ยังใช้เหมือนเดิมสำหรับ Drop ไม่มีรูป)
- **`HomeDropCard`**: media area แสดงรูปแรกเหมือนเดิม + ไอคอนเดียวกันกับข้างต้นมุมขวาบนของ media area (ตำแหน่งเดียวกับที่ Pop เดิมเคยมี duration badge — pattern สม่ำเสมอ)
- **`DropDetailScreen`**: **เปลี่ยนจากรูปเดียวเป็น `PageView` แนวนอน** ถ้ามีมากกว่า 1 รูป (รูปเดียว/ไม่มีรูป render เหมือนเดิมทุกประการ ไม่ใส่ `PageView` เปล่าๆ) — จุดไข่ปลา (dot indicator) กึ่งกลางด้านล่างของรูป แสดงตำแหน่งรูปปัจจุบัน, ตัวเลข "2/5" มุมขวาบนของรูป (scrim ทึบเดียวกับ Screen 2)

Interactions: swipe ซ้าย/ขวาเปลี่ยนรูปใน `DropDetailScreen` — ไม่ชนกับ double-tap-to-like ของ WYN-062 (`DoubleTapLike` ครอบ media area เดิมอยู่แล้ว ยังทำงานถูกต้องบน `PageView` เพราะ gesture คนละชนิด: horizontal drag vs. tap)

States: Regression ต้องยืนยัน — Drop รูปเดียว (เก่า/ใหม่), Drop ไม่มีรูป (text-only, WYN-062), Drop 2-9 รูป (ใหม่) ทั้ง 3 กรณีต้อง render ถูกต้องทุกจุดที่ระบุข้างบน

Design Rules: ไม่เพิ่มสี/token ใหม่ — ไอคอน multi-image indicator ใช้สีขาวบน scrim เดียวกับที่ระบบมีอยู่แล้ว

Handoff: AI Coding — ไล่ทุกจุดที่เคยอ่าน `drop.imageUrl` (singular) เปลี่ยนเป็น `drop.imageUrls` (list) แบบเดียวกับที่ WYN-062 เพิ่งไล่ null-safety ทั้ง repo มาแล้วรอบหนึ่ง (`DropGridTile`, `SavedGridTile`, `DraftGridTile`, `HomeDropCard`, `DropDetailScreen`, `quote_redrop_screen`, `recently_deleted_drops_screen`) — เพิ่ม schema ใหม่ (แนะนำตาราง `drop_images(drop_id, image_url, position)` แยกจาก `drops` เดิม ไม่ใช่ array column เพราะ RLS/index จัดการง่ายกว่า) migration ต้อง backfill `drops.image_url` เดิมเข้า `drop_images` เป็นแถวเดียว position 0 ให้ Drop เก่าทุกตัวยังใช้ได้ ไม่มีของหาย

---

## Screen 4 — Full-Screen Image Viewer (ใหม่, R3)

Purpose: เปิดดูรูปแบบเต็มจอ พร้อม swipe เปลี่ยนรูป (Drop หลายรูป) — ยังไม่มี pattern นี้ในระบบเลยตอนนี้

User Flow: แตะรูปใน `DropDetailScreen` → เปิดเต็มจอ (พื้นดำ, ไม่ใช่พื้นขาวของธีมหลัก เพราะเป็นบริบท media viewer ไม่ใช่ผิวธีมทั่วไป — เหมือนที่ Pop clip view ใช้พื้นดำอยู่แล้ว) → swipe ซ้าย/ขวาเปลี่ยนรูป (ถ้ามีหลายรูป) → แตะกลางจอหรือลากลง (swipe-down-to-dismiss) เพื่อปิด

Components: `PageView` เต็มจอ + `InteractiveViewer` ต่อรูป (รองรับ pinch-to-zoom) + dot indicator ด้านล่าง + ปุ่มปิด (X) มุมซ้ายบน

Interactions: pinch-zoom ต่อรูป, double-tap เพื่อ zoom-in/zoom-out เร็ว (มาตรฐาน image viewer ทั่วไป — **ไม่ใช่ Like** ต่างบริบทจาก double-tap-to-like ที่อยู่นอกหน้านี้)

States: รูปเดียว (ไม่มี swipe/indicator) / หลายรูป (swipe+indicator เต็ม)

Accessibility: ปุ่มปิดมี `Semantics(label: 'ปิด', button: true)`, indicator มี `Semantics(label: 'รูปที่ 2 จาก 5')`

Design Rules: พื้นดำเสมอ (ไม่ผูกกับ theme หลักที่ fix เป็น light — media viewer เป็นข้อยกเว้นที่มีอยู่แล้วในระบบ เช่น Pop)

Handoff: AI Coding — widget ใหม่ `DropImageViewer` (reusable), เรียกจาก `DropDetailScreen` เมื่อแตะรูป

---

## Screen 5 — Profile: Recommendation Section (R4)

Purpose: แนะนำบัญชีที่น่าสนใจให้ผู้ใช้ follow ขณะดูโปรไฟล์คนอื่น (ตามภาพอ้างอิง — Threads แสดง section นี้ขณะดูโปรไฟล์ "คนอื่น" ไม่ใช่โปรไฟล์ตัวเอง)

**การตัดสินใจ**: แสดง Recommendation Section **เฉพาะตอนดูโปรไฟล์คนอื่น (`isOwnProfile == false`)** เท่านั้น ไม่แสดงในโปรไฟล์ตัวเอง — เหตุผล: (1) ตรงกับบริบทของภาพอ้างอิงที่ Founder ส่งมาเป๊ะ (2) โปรไฟล์ตัวเองมี "Recommendation" อยู่แล้วใน Home feed (WYN-063's Discovery segment) ไม่จำเป็นต้องซ้ำอีกจุด

Components:
- ตำแหน่ง: ใต้ปุ่ม Follow/ส่งข้อความ, เหนือ Tab bar (ตรงตามภาพอ้างอิง)
- Label: "แนะนำสำหรับคุณ" (`titleSmall`, bold — mirror สไตล์ label ของ `_buildMyClubsSection` เดิมใน `ViewProfileScreen`)
- Card แนวนอน scroll (`ListView.builder(scrollDirection: Axis.horizontal)` — pattern เดียวกับ "Club ของฉัน" section ที่มีอยู่แล้ว): avatar วงกลม, ชื่อ (bold, 1 บรรทัด ellipsis), @username (`onSurfaceVariant`, เล็กกว่า), ปุ่ม Follow ขนาดกะทัดรัด (`OutlinedButton`, สไตล์เดียวกับปุ่ม Follow หลักแต่เล็กลง), ปุ่ม X มุมขวาบนของการ์ด (ซ่อนการ์ดนั้นทันที, ไม่ใช่แค่ opacity ลด)
- ที่มาของรายการแนะนำ: reuse logic ใกล้เคียงกับ Discovery segment ของ WYN-063 (บัญชีที่ follower/following คล้ายกับโปรไฟล์ที่กำลังดูอยู่ — "คนที่คล้ายกับ {ชื่อ}") ไม่ใช่สุ่ม

Interactions: กด X → การ์ดหายไปทันที (optimistic) + บันทึก dismissal ฝั่ง server ไม่ให้ suggest ซ้ำอีก (คนที่ dismiss ไปแล้วจะไม่โผล่ใน recommendation ของ user คนนี้อีกไม่ว่าจะดูโปรไฟล์ไหน) — กด Follow → toggle ทันที (optimistic, mirror `_toggleFollow` เดิม), การ์ดยังอยู่ (ไม่หายไปหลัง follow เผื่อ user เปลี่ยนใจ unfollow จากตรงนี้ได้เลย)

States: ไม่มีรายการแนะนำเลย (ทุกคน dismiss หมดแล้ว หรือไม่มีข้อมูลพอ) → **ไม่แสดง section นี้เลย** (ไม่ใช่ empty state ข้อความ — ตรงกับหลัก "ไม่แสดง section ว่างเปล่าเป็นแถว" ที่ `_buildMyClubsSection` ใช้อยู่แล้ว) / Loading → skeleton การ์ด 3 ใบเรียงกัน (shimmer หรือ solid placeholder ตาม pattern ที่มีอยู่แล้วในระบบ)

Responsive Behavior: การ์ดความกว้างคงที่ (~120-140px) ไม่ยืดตามจอ — scroll แนวนอนรองรับทุกขนาดจอเหมือนกัน

Accessibility: แต่ละการ์ดมี Semantics รวม (ชื่อ+username), ปุ่ม X มี label "ซ่อนคำแนะนำนี้"

Design Rules: การ์ดใช้ `_lightCardTheme` เดิม (flat, border บาง ไม่มีเงา) ตาม DS-001/002

Handoff: AI Coding — schema ใหม่: RPC แนะนำบัญชี (reuse logic เดียวกับ WYN-063 Discovery segment ถ้าเป็นไปได้) + ตาราง `profile_recommendation_dismissals(user_id, dismissed_profile_id)` ใหม่

---

## Screen 6 — Profile: โครงสร้าง Tab ใหม่ (R5)

Purpose: จัดกลุ่มเนื้อหาโปรไฟล์ใหม่เป็น Posts/Replies/Media/Likes (สาธารณะทั้งหมด ตาม Founder ตัดสินใจ) โดยไม่ทิ้งความสามารถเดิม (ReDrop/Saved/Draft)

**การจับคู่กับของเดิม (สำคัญ — ป้องกันการลบ feature โดยไม่ตั้งใจ)**:

| Tab ใหม่ | มาจากอะไร | หมายเหตุ |
|---|---|---|
| **Posts** | Drop tab เดิม (WYN-013) **+ ReDrop tab เดิมรวมเข้าด้วยกัน** | เรียงตามเวลาปนกัน (Drop ของตัวเอง + ReDrop ที่ทำ) มิเรอร์วิธีที่ Threads/X เอง treat repost เป็นส่วนหนึ่งของ timeline หลัก ไม่ใช่ tab แยก — **ไม่ได้ลบ ReDrop capability** แค่ย้ายที่แสดงผล |
| **Replies** | **ใหม่ทั้งหมด** — Comment ที่ user เขียนไว้ (ทุก Drop ที่เคย comment) | ไม่เคยมีมุมมองนี้มาก่อนในระบบ |
| **Media** | subset ของ Drop ที่มีรูป (`imageUrls.isNotEmpty`) | derived view ของข้อมูลเดียวกับ Posts ไม่ใช่ตารางใหม่ |
| **Likes** | **ใหม่ทั้งหมด** — Drop ที่ user เคย Like (สาธารณะ ตาม Founder ตัดสินใจ) | ต่างจาก "บันทึก" (Saved) ที่ยังเป็น private — คนละความหมายกัน |

**Saved (บันทึก) และ Draft (ร่าง) ที่ไม่อยู่ใน 4 tab ใหม่**: ทั้งสองยังคง**ต้องมีอยู่ (ห้ามลบ)** แต่เป็น private/own-only ไม่เข้ากับโมเดล "4 tab สาธารณะเหมือนกันทุกคนเห็น" ของ spec ใหม่ — ย้ายออกจากแถว tab หลัก ไปเป็น**แถวปุ่มไอคอนกะทัดรัดเหนือ tab bar** (แสดงเฉพาะ `isOwnProfile == true`) วางถัดจากปุ่ม "แก้ไขโปรไฟล์" — 2 ไอคอนเท่านั้น (`Icons.bookmark_border` บันทึก, `Icons.edit_note_outlined` ร่าง) แตะแล้วเปิดหน้าเดิม (`ProfileSavedTab`/`ProfileDraftsTab` เนื้อหาเดิมทุกประการ แค่เปลี่ยนทางเข้า)

Components:
- Tab bar 4 อัน เหมือนกันทุกคน (ไม่ conditional ตาม persona อีกต่อไป ต่างจาก WYN-013 เดิมที่ Saved/Draft ทำให้จำนวน tab ต่างกัน) — icon+label ตาม design rule เดิม: Posts (`Icons.grid_view_outlined`), Replies (`Icons.chat_bubble_outline`), Media (`Icons.image_outlined`), Likes (`Icons.favorite_border`)
- `DefaultTabController(length: 4)` คงที่เสมอ ไม่ conditional อีกต่อไป (ง่ายขึ้นกว่าเดิมด้วยซ้ำ)

Interactions: แตะ tab สลับเนื้อหา (mirror `AutomaticKeepAliveClientMixin` เดิม), แตะไอคอนบันทึก/ร่าง (เฉพาะเจ้าของโปรไฟล์) เปิดหน้าเดิม

States: Empty state แต่ละ tab ต้องแยกข้อความชัดเจน (Posts/Replies/Media/Likes มี wording ต่างกัน ตาม pattern `_gridEmptyText` เดิมที่รองรับ 2 persona อยู่แล้ว — ขยายให้ครอบ 4 tab ใหม่)

Responsive Behavior: 4 tab ในความกว้างจอมือถือมาตรฐาน (360-430px) ต้องไม่ตัดคำ — ทดสอบแบบเดียวกับที่ WYN-024 เจอปัญหากับ SegmentedButton มาก่อน (ดู `wyn-024-segmented-feed-mode-scrollable.md`) เพื่อไม่ให้เจอบั๊กซ้ำ ถ้าคับให้ทำ `TabBar(isScrollable: true)` แทนการยุบ label

Accessibility: Semantics label เต็มทุก tab แม้ label ที่แสดงจะสั้น

Design Rules: icon+label เสมอ (ห้าม text-only แบบ Threads หรือ icon-only แบบ Instagram) ตาม Design Rule เดิมจาก WYN-013

Handoff: AI Coding — `ViewProfileScreen`: TabBar/TabBarView ใหม่ 4 อันเสมอ, ย้าย Saved/Draft entry point เป็นไอคอนแถวบน — Backend: RPC/view ใหม่สำหรับ Replies (comments ของ user + join Drop ต้นทาง), Likes (Drop ที่ user like, public — ต่างจาก `saves` ที่ RLS private, ต้องออกแบบ RLS ใหม่ให้ likes อ่านได้แบบ public แต่เขียนได้เฉพาะเจ้าของ), Media (filter ฝั่ง client ก็พอ ไม่ต้อง query แยกถ้า Posts โหลดมาแล้วกรองซ้ำได้ในกรณีข้อมูลไม่เยอะ — ให้ AI Coding ตัดสินใจตาม performance จริง)

---

## Screen 7 — Replies/Likes: Privacy Notice (R5, ใหม่)

Purpose: แจ้งเจ้าของโปรไฟล์อย่างชัดเจนว่า Comment/Like ของตัวเองตอนนี้เป็นข้อมูลสาธารณะ (เพราะเป็นการเปิดเผยพฤติกรรมที่ไม่เคยมีมาก่อนในระบบ — ต้องไม่ให้ผู้ใช้ประหลาดใจภายหลัง ตาม WYN Mission เรื่องความเป็นส่วนตัว)

User Flow: ผู้ใช้เปิด tab "Replies" หรือ "Likes" **บนโปรไฟล์ของตัวเอง** เป็นครั้งแรก (นับแยกกันทั้งสอง tab) → เห็น banner แจ้งเตือนแบบไม่บล็อกการใช้งาน ปักหมุดด้านบนของเนื้อหา tab นั้น → กดปิด (X) หรือกด "เข้าใจแล้ว" → ไม่แสดงอีกตลอดไป (persisted, ไม่ใช่แค่ session เดียว)

Components: Banner แถบเดียว (ไม่ใช่ modal/dialog ที่บล็อก flow) พื้นหลัง `surfaceContainer`, ไอคอนข้อมูล (`Icons.info_outline`), ข้อความ "คนอื่นเห็นแท็บนี้ได้เหมือนกัน" (Replies) / "คนอื่นเห็นสิ่งที่คุณกด Like ได้เหมือนกัน" (Likes), ปุ่ม X ปิด

States: แสดง (ครั้งแรก) / ซ่อนถาวร (หลังปิดครั้งแรก หรือหลังเปิด tab นั้นครบ N ครั้งถ้า Coding เห็นว่าเหมาะกว่า — ไม่ block เป็น requirement เข้มงวด)

Accessibility: Banner ต้องอ่านได้ด้วย screen reader ทันทีที่ tab เปิด (ไม่ใช่แค่ visual)

Design Rules: ไม่ใช้ modal/dialog บล็อก — เนื้อหาเดิมของ tab (list โพสต์/comment) ยังเลื่อนดูได้ตามปกติแม้ banner ยังไม่ปิด

Handoff: AI Coding — เก็บสถานะ "เคยเห็น banner นี้แล้ว" ด้วย local storage (`shared_preferences`, key แยก `seen_replies_privacy_notice`/`seen_likes_privacy_notice`) ไม่ต้องใช้ schema ฝั่ง server (เป็นแค่ UI state ต่อเครื่อง ไม่ใช่ข้อมูลที่ต้อง sync ข้ามอุปกรณ์)

---

## Screen 8 — Profile Top Bar: Search/Notifications (R8)

Purpose: เพิ่มทางลัด Search/Notifications บนหน้าโปรไฟล์ตามภาพอ้างอิง

**การตัดสินใจ — ไม่ทำเหมือน spec ตรงตัวทุกจุด (มีเหตุผลบันทึกไว้ให้ Founder เห็น)**: Bottom Nav ของ WYNOS ปัจจุบัน (WYN-024) มี Search และ Notifications เป็น tab หลักอยู่แล้ว 1 แตะถึง — การเพิ่มไอคอนซ้ำบน**โปรไฟล์ตัวเอง** (ซึ่งเป็นหน้า root ของ Bottom Nav อยู่แล้ว) จะซ้ำซ้อนไม่มีประโยชน์จริง จึง**เพิ่มเฉพาะตอนดูโปรไฟล์คนอื่น** (หน้าที่ถูก push, มองไม่เห็น Bottom Nav ระหว่างอยู่หน้านั้น) ซึ่งตรงกับบริบทภาพอ้างอิงที่ Founder ส่งมาพอดี (ภาพนั้นคือกำลังดูโปรไฟล์คนอื่น "novemboy" ไม่ใช่โปรไฟล์ตัวเอง)

Components: AppBar ของโปรไฟล์คนอื่น เพิ่ม `IconButton` Search + Notifications (icon เดิมจากระบบ, `Icons.search`/`Icons.notifications_outlined`) วางก่อนปุ่ม More (⋮) เดิม — โปรไฟล์ตัวเองไม่เปลี่ยนอะไร (Settings/Logout เดิม)

Interactions: แตะ Search → เปิด `SearchScreen` (push ทับ), แตะ Notifications → เปิด `NotificationListScreen` (push ทับ) — ทั้งสองกลับมาที่โปรไฟล์เดิมเมื่อกด back (ไม่ pop กลับไป Bottom Nav แล้วต้อง navigate ใหม่)

Accessibility: Semantics label มาตรฐานเดิมของทั้งสองไอคอน (มีอยู่แล้วจาก WYN-024/WYN-012)

Design Rules: ใช้ icon เดิมจากระบบ ไม่สร้างใหม่

Handoff: AI Coding — แก้ AppBar actions ของ `ViewProfileScreen` เฉพาะ branch `isOwnProfile == false`

---

## Screen 9 — Micro-interactions (R7)

Purpose: เติมจุดที่ยังขาดให้ WYNOS รู้สึกลื่นไหลแบบ social platform ใหญ่ — **ตรวจสอบของเดิมก่อนเพิ่มใหม่** (ตามกติกาไม่รื้อของที่ทำงานอยู่แล้ว)

**ยืนยันแล้วว่ามีอยู่จริง (ไม่ต้องแก้)**: Like animation (double-tap heart, WYN-062), Pull-to-refresh (Home/feed ใช้ `RefreshIndicator` มาตรฐานอยู่แล้วตั้งแต่ WYN-007), Smooth scrolling (ค่าเริ่มต้นของ Flutter scroll physics)

**ต้องให้ AI Coding ยืนยันสถานะจริงก่อนแก้ (ไม่ fix จาก Design ตรงๆ เพราะยังไม่ตรวจโค้ดละเอียดระดับนี้)**: Skeleton loading / Image loading placeholder — ถ้ามีอยู่แล้วบางจุดไม่ต้องแก้ ถ้าขาดให้เติมแบบเดียวกับจุดที่มีอยู่แล้ว ไม่ต้องคิด pattern ใหม่

**ยืนยันแล้วว่าไม่มีเลยในระบบ (ต้องเพิ่มใหม่)**:
- **Haptic feedback**: ไม่มี `HapticFeedback` call ใดๆ ในโค้ดทั้งหมดตอนนี้ — เพิ่ม `HapticFeedback.lightImpact()` ที่ 3 จุด: (1) double-tap Like สำเร็จ (2) กด Follow/Unfollow (3) Drop/Comment โพสต์สำเร็จ — ใช้ `lightImpact()` เท่านั้นทุกจุด (ไม่ผสมระดับความแรง เพื่อความสม่ำเสมอ, ไม่ใช้กับทุก tap เพราะจะกวนใจเกินไป — เฉพาะ action ที่มีความหมาย/เปลี่ยนสถานะจริงเท่านั้น)
- **Follow button animation**: ปัจจุบันเปลี่ยนข้อความ/สีทันทีไม่มี transition — เพิ่ม `AnimatedContainer`/`AnimatedSwitcher` สั้นๆ (150-200ms) ตอนสลับสถานะ "ติดตาม"/"กำลังติดตาม" ให้รู้สึกนุ่มนวลขึ้น ไม่ใช่กระตุกเปลี่ยนทันที

Design Rules: haptic ใช้เท่าที่จำเป็นจริง ("ไม่ใส่ animation เยอะจนทำให้แอปช้า" ตาม spec เดิมของ Founder) — ไม่ใส่ haptic กับการเลื่อน scroll/สลับ tab (เฉพาะ action ที่มีผลจริงเท่านั้น)

Handoff: AI Coding — เพิ่ม `import 'package:flutter/services.dart'` + เรียก `HapticFeedback.lightImpact()` ใน 3 จุดที่ระบุ, เพิ่ม `AnimatedSwitcher` ที่ปุ่ม Follow (ใช้ widget เดิม แค่ห่อด้วย animation)

---

## Non-goals รอบนี้

- Dwell-time ranking signal (R6 ของ Product spec) — เลื่อนออกตามที่ Product ระบุไว้แล้ว
- Drag-to-reorder รูปใน Composer — เก็บ scope เล็ก ทำทีหลังถ้า Founder ต้องการ
- ไม่แตะ Bottom Nav โครงสร้างเดิม (WYN-024) เลย
- ไม่แตะ ranking algorithm ของ WYN-063 เลย (Recommendation Section ของ Profile reuse *logic* คล้ายกันเท่านั้น ไม่ใช่แก้ตัวมันเอง)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1–9 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-071-wynos-visual-refresh.md` สำหรับ Requirements/Acceptance Criteria ฉบับเต็ม แนะนำลำดับ implement: Screen 1 (theme fix, เร็วสุด) → Screen 8/9 (เล็ก, ไม่มี schema change) → Screen 5 (Recommendation, schema เล็ก) → Screen 2-4 (multi-image Drop, schema+UI ใหญ่สุด) → Screen 6-7 (Profile tab restructure, ผูกกับหลายจุดที่สุด ควรทำหลังของอื่นเสถียรแล้ว)
