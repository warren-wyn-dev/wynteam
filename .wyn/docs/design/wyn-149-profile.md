# WYN "Flare" — Profile (V1.0 — PROPOSED)

Status: PROPOSED
Owner: AI Design
อ้างอิง: wyn-142-visual-identity-redesign.md, wyn-143-core-component-library.md

โค้ดจริงที่ตรวจก่อนเขียนสเปกนี้:
- `app/lib/features/profile/presentation/view_profile_screen.dart`
- `app/lib/features/profile/presentation/widgets/wynos_founder_profile_header.dart`
- `app/lib/features/profile/presentation/edit_profile_screen.dart`
- `app/lib/features/profile/presentation/profile_photo_crop_screen.dart`

เอกสารอ้างอิง feature requirement เดิม (layout logic เท่านั้น ไม่ใช้สี/token จากเอกสารเหล่านี้อีกต่อไป): `wyn-095-profile-layout-redesign.md` (โครง avatar+stats แถวเดียวกัน, ชื่อ/username ใต้แถวนั้น, bio, ปุ่มคู่), `wyn-110-profile-scroll-header.md` (`NestedScrollView` + `SliverPersistentHeader(pinned)` ให้หัวโปรไฟล์เลื่อนหายไปได้, `TabBar` ค้างขอบบน)

หมายเหตุสำคัญ: งานนี้เป็นการ **re-skin ทั้งหมดด้วย token ของ Flare** (สี, ฟอนต์, radius, ปุ่ม) — ไม่แตะ business logic ใด ๆ (Follow/Message/Block/Mute/Report/Share/Settings/infinite-scroll/pull-to-refresh) ทุกจุดที่ค่า pixel เดิมต่างจาก token ของ Flare (เช่น ขนาด avatar, radius การ์ด) ถูกปรับให้ตรง token ใหม่ — ระบุไว้ชัดเจนเป็นจุด ๆ ด้านล่างว่าเปลี่ยนอะไรจากโค้ดปัจจุบัน

---

# Screen: ViewProfileScreen — ดูโปรไฟล์ (ของตัวเองและของคนอื่น)

**Purpose:** แสดงตัวตนของผู้ใช้ (รูปปก, avatar, ชื่อ, username, bio, สถิติผู้ติดตาม/กำลังติดตาม) พร้อมปุ่มปฏิบัติการที่เหมาะกับบริบท (ติดตาม/ส่งข้อความ สำหรับโปรไฟล์คนอื่น, แก้ไขโปรไฟล์ สำหรับตัวเอง) และเนื้อหาที่โพสต์ไว้ (สื่อ/รีโพสต์/ถูกใจ) ในโครง scroll เดียวที่หัวโปรไฟล์เลื่อนหายไปได้

**User Flow:**
1. เปิดจาก Bottom Tab "โปรไฟล์" (ตัวเอง) หรือกดจากที่อื่นในแอป เช่น การ์ดโพสต์/รายชื่อผู้ติดตาม (คนอื่น) → เห็น skeleton สั้น ๆ → เห็นโปรไฟล์เต็ม
2. เลื่อนดูโพสต์ → รูปปก+avatar+ชื่อ+bio+ปุ่มเลื่อนหายไปตามปกติ → `TabBar` (สื่อ/รีโพสต์/ถูกใจ) ค้างขอบบนแทน
3. กดตัวเลขผู้ติดตาม/กำลังติดตาม → เปิดรายชื่อ (ถ้าเป็นบัญชีส่วนตัวที่ยังไม่ได้ติดตาม → Toast แจ้งว่าต้องติดตามก่อน)
4. โปรไฟล์คนอื่น: กดปุ่ม "ติดตาม" → เปลี่ยนสถานะทันที (หรือส่งคำขอถ้าเป็นบัญชีส่วนตัว) / กด "ส่งข้อความ" → เปิดห้องแชท
5. โปรไฟล์ตัวเอง: กดปุ่ม "แก้ไขโปรไฟล์" → ไป `EditProfileScreen` / กดชื่อที่แสดง → เปิด Account Switcher
6. ลากลงเพื่อ pull-to-refresh ทั้งหน้า (โปรไฟล์+สถิติ+แท็บที่กำลังเปิดอยู่)

**Components** (อ้างอิง wyn-143 ทุกจุด):
1. **Cover + Top bar overlay** (`SliverToBoxAdapter` แรก): รูปปกเต็มความกว้าง สูงคงที่ (ตามค่าที่มีอยู่ปัจจุบัน) — ไม่มี fallback รูปให้ใช้พื้นไล่สี `color.surface` → `color.hairline` (แทน gradient graphite/inkSoft เดิม) พร้อม scrim ทึบไล่จาก `rgba(23,20,15,0.32)` ด้านบนไปโปร่งใส (ทึบ ไม่ blur — ตรงกติกา). ปุ่มย้อนกลับ/ชื่อหน้าจอ/action ขวา ลอยทับรูปปก เป็นไอคอนสีขาว/`color.paper` เสมอ (คงคอนทราสต์กับรูปปกได้ทุกกรณีเพราะมี scrim) — ปุ่มทั้งหมดใช้ touch target ≥44×44px ตาม Top App Bar spec ของ wyn-143
2. **Avatar** — `Avatar` component ขนาด **64px** (มาตรฐาน "profile header" ของ wyn-143 §5 — **เปลี่ยนจาก ~86px เดิม**) มีขอบขาว `color.paper` หนา 4px คั่นจากรูปปกด้านหลัง, ring สถานะออนไลน์ (เฉพาะโปรไฟล์ตัวเอง) เป็นวงกลมเล็ก `color.success` ขอบ `color.paper`
3. **Stats row** — 2 ช่อง (กำลังติดตาม/ผู้ติดตาม) วางข้าง avatar ตามโครงเดิมจาก wyn-095: ตัวเลข `type.heading.1` สี `color.ink`, label `type.caption` สี `color.ink.muted`, เส้นแบ่งกลาง `color.hairline` — แต่ละช่องคง `Semantics(button: true)` เดิม
4. **ชื่อที่แสดง + username** — ใต้แถว avatar/stats ชิดซ้าย: ชื่อ `type.heading.2` สี `color.ink` + `VerifiedBadge` (ถ้ามี) + ไอคอน chevron-down (เฉพาะตัวเอง, เปิด Account Switcher) / `@username` ใต้ชื่อ `type.body.s` สี `color.ink.muted`
5. **Bio** — `type.body.m` สี `color.ink`, สูงสุด 3 บรรทัด, ยุบพื้นที่ทิ้งถ้าไม่มี (พฤติกรรมเดิม)
6. **Action row**:
   - โปรไฟล์คนอื่น: `Primary Button` "ติดตาม" (พื้น `color.accent`/ตัวหนังสือ `color.paper`) คู่กับ `Secondary Button` ไอคอน+label "ส่งข้อความ" (`Expanded` ทั้งคู่แบ่งครึ่ง ตามโครง wyn-095 Mockup A ที่ Founder อนุมัติแล้ว) — เมื่อสถานะเป็น "กำลังติดตาม" หรือ "ขอติดตามแล้ว" ปุ่มเปลี่ยนเป็น `Secondary Button` (โครงเดิม แค่เปลี่ยนสีจาก `surfaceTint`/`ink` เป็น token `color.surface`/`color.ink`) เพื่อลดน้ำหนักภาพลงจาก primary action เดิมที่ทำไปแล้ว — **ห้ามใช้สีอย่างเดียวสื่อสถานะ** ข้อความปุ่ม ("ติดตาม"/"กำลังติดตาม"/"ขอติดตามแล้ว") ต้องต่างกันชัดเจนเสมอ (มีอยู่แล้ว)
   - โปรไฟล์ตัวเอง: `Secondary Button` เต็มแถวเดียว "แก้ไขโปรไฟล์" (ไอคอนดินสอ+label) + ปุ่มไอคอนสี่เหลี่ยมมุมโค้ง 44×44 สองปุ่ม (แนะนำสำหรับคุณ / บันทึกไว้) พื้น `color.surface` ขอบ `color.hairline` radius `radius.m`
   - `_isFollowing == null` (กำลังโหลด) → ซ่อนทั้งแถว แสดง `Spinner` (`color.accent`, 18px) แทนชั่วคราว (พฤติกรรมเดิม)
7. **Follow-request footer** (เฉพาะเจ้าของโปรไฟล์ที่เป็นบัญชีส่วนตัวและมีคำขอค้าง) — `List Item` แบบย่อ (ไอคอน+ข้อความ "คำขอติดตาม (N)"+chevron), พื้นหลังโปร่งกดแล้วเห็น `color.surface` briefly
8. **Blocked banner** (แทนที่ stats+actions ทั้งหมดเมื่อ block ไม่ว่าทิศทางไหน) — การ์ดแบน เต็มความกว้าง พื้น `color.surface` radius `radius.m` ไอคอน `block` + ข้อความ `type.body.m` สี `color.ink.muted` กึ่งกลาง (แทน `surfaceContainer`/`onSurfaceVariant` ของ Material เดิม)
9. **Recommendation section** (เฉพาะโปรไฟล์คนอื่น) — คงโครงเดิม (การ์ดแนะนำผู้ติดตามแนวนอน), การ์ดแต่ละใบใช้ `Card` component (พื้น `color.surface`, radius `radius.m`)
10. **TabBar (pinned)** — 3 แท็บ "สื่อ/รีโพสต์/ถูกใจ" ไอคอน+label, indicator ขีดล่าง 2px สี `color.accent` (เปลี่ยนจาก `WynColors.ink` เดิม — สอดคล้องกติกา "accent = active state"), label ที่เลือก `color.ink` น้ำหนัก SemiBold, label ที่ไม่ได้เลือก `color.ink.muted`, พื้นหลัง pinned bar ทึบ `color.paper` (light) / `color.surface` (dark) กันเนื้อหาทะลุ (ตรงกับ wyn-143 §3 Bottom Tab Barแต่ใช้กับ tab บนแทน เพราะ component library ไม่มี token tab-bar แยกต่างหาก — คงโครงเดิม เปลี่ยนเฉพาะสี)
11. **แต่ละแท็บ** — การ์ดโพสต์แบบ grid/list ใช้ `Card` component ทุกใบ, Empty state ใช้ token Empty State (ไอคอน+หัวข้อ `type.heading.2`+คำอธิบาย `type.body.m` สี `ink.muted`), Skeleton ใช้ `color.surface` + shimmer ตาม motion token
12. **Loading เต็มจอ** — `ProfileSkeleton` ใช้บล็อกสี `color.surface` shimmer แนวนอนแทนสีเทาเดิม
13. **Error state** — ข้อความ `type.body.m` + `Text Button` "ลองใหม่" สี `color.accent`

**Interactions:**
- ปุ่ม Follow/Message/แก้ไขโปรไฟล์/แนะนำสำหรับคุณ/บันทึกไว้/ตั้งค่า/แชร์/เพิ่มเติม (more menu) ทำงานเหมือนโค้ดปัจจุบันทุกจุด — งานนี้ไม่แตะ logic
- กดปุ่มทุกปุ่ม → feedback ทันที (`motion.fast`, scale 0.97 สำหรับ Primary Button ตาม wyn-143)
- More menu (แชร์/รายงาน/ปิดเสียง/บล็อก) เปิดเป็น **Bottom Sheet** (component 9) มุมบนโค้ง `radius.l` มี drag handle, scrim ทึบ `rgba(23,20,15,0.4)` — แต่ละแถวเป็น `List Item` (icon leading, label, ไม่มี trailing)
- Dialog ยืนยัน "ยกเลิกคำขอติดตาม" และ dialog ยืนยัน "บล็อก" ใช้ **Modal (dialog กลางจอ)** ตาม wyn-143 §9 (เพราะเป็นการตัดสินใจสำคัญที่ผู้ใช้ควร focus) — ปุ่มยืนยันที่เป็นการกระทำเชิงลบ ("ยกเลิกคำขอ"/"บล็อก") ใช้ตัวหนังสือสี `color.error`, ปุ่มปฏิเสธ ("ไม่ยกเลิก"/"ยกเลิก") ใช้ `Text Button` ปกติสี `color.ink`
- Toast (component 7) ใช้กับข้อความชั่วคราวที่ไม่ผูก field เฉพาะ (เช่น "รีเฟรชโปรไฟล์ไม่สำเร็จ", "บล็อก @user แล้ว", "ต้องติดตามก่อนถึงจะดูรายชื่อได้") — แถบมุมโค้ง `radius.m` ลอยเหนือ bottom nav, พื้น `color.ink`, ตัวหนังสือ `color.paper`, auto-dismiss 3 วิ

**States:**
- โหลดครั้งแรก → `ProfileSkeleton` (shimmer)
- โหลดล้มเหลว → ข้อความ + ปุ่ม "ลองใหม่"
- Bio ว่าง → ยุบพื้นที่ทิ้ง (ไม่เหลือช่องว่าง)
- `_isFollowing == null` → ซ่อนแถวปุ่ม แสดง spinner กลาง
- Blocked (ทั้งสองทิศทาง) → banner แทนที่ stats+actions ทั้งหมด (ยังเห็นรูปปก/avatar/ชื่อ)
- Private + ยังไม่ follow → ปุ่ม Follow 3 สถานะเดิม ("ติดตาม"/"กำลังติดตาม"/"ขอติดตามแล้ว"), tab เนื้อหาแสดงข้อความ "บัญชีนี้เป็นส่วนตัว — ติดตามเพื่อดู..." แทน grid ว่าง
- มีคำขอติดตามค้าง (เฉพาะเจ้าของโปรไฟล์) → footer badge "(N)" ปรากฏ
- กำลังเริ่มแชท (`_isStartingChat`) → spinner แทนไอคอนในปุ่ม "ส่งข้อความ"
- Pull-to-refresh กำลังทำงาน → spinner มาตรฐานของระบบ สี `color.accent`

**Responsive Behavior:**
- ทดสอบที่ 320/360/390/430px (คงข้อกำหนดจาก wyn-110)
- Stats row ห้าม overflow ที่ 360px — ตัวเลขเกินหลักพัน/ล้านย่อเป็น "1.2K"/"1.2M" (ใช้ helper เดิมถ้ามี)
- ชื่อ/username ตัดด้วย ellipsis บรรทัดเดียวเสมอ ไม่ห่อบรรทัด
- Tab label ใช้ `FittedBox(fit: BoxFit.scaleDown)` กันล้นที่จอแคบ (พฤติกรรมเดิม คงไว้)
- หัวโปรไฟล์ต้องเลื่อนหายไปได้จริงทุกขนาดจอ, `TabBar` ค้างขอบบนไม่ล้น/overflow (requirement เดิมจาก wyn-110 ยังใช้ได้)

**Accessibility:**
- Stats แต่ละตัวคง `Semantics(button: true, label: '$count $label')`
- ปุ่ม "ส่งข้อความ" มี label ข้อความจริงเสมอ (ไม่ใช่ icon-only) ลดภาระ semantics
- ลำดับการอ่าน screen reader ตาม visual order: cover → avatar+stats → ชื่อ → username → bio → ปุ่ม → footer → tab → เนื้อหา
- Contrast ทุกข้อความ/ปุ่มผ่าน WCAG AA ทั้ง light/dark (ตรวจเฉพาะจุดที่เปลี่ยนสี เช่น indicator ของ TabBar, ปุ่ม following state)
- สถานะปุ่ม (ติดตาม/กำลังติดตาม/ขอติดตามแล้ว) แยกด้วยข้อความเสมอ ไม่ใช่สีอย่างเดียว
- Touch target ทุกปุ่ม (รวมไอคอนบนรูปปก) ≥44×44px

**Design Rules:**
- ห้ามใช้ Liquid Glass — scrim บนรูปปกเป็น gradient ทึบเท่านั้น
- Single-accent: `color.accent` ใช้เฉพาะปุ่ม Follow (สถานะยังไม่ติดตาม), TabBar indicator, spinner/CTA — ไม่ทาสีอื่นในหน้านี้เป็น accent
- Avatar/ปุ่ม/chip ทั้งหมดใช้ `radius.pill`, การ์ด/อินพุตใช้ `radius.m`, bottom sheet ใช้ `radius.l`
- Elevation: การ์ดใน dark mode ไม่มีเงา ใช้ความต่างสี `surface`/`paper` แทน
- ไอคอนทั้งหมด stroke 1.5px ปลายมน ขนาด 24×24px, สถานะ active (TabBar) เป็น filled + `color.accent`

**Handoff:**
- ไฟล์ที่ต้องแก้: `view_profile_screen.dart`, `widgets/wynos_founder_profile_header.dart`, `widgets/profile_skeleton.dart`, `widgets/avatar_circle.dart` (เฉพาะสี fallback ให้ตรง `color.accent` tint 20% ตาม wyn-143 §5), `core/design/wyn_colors.dart`/`wyn_typography.dart`/`wyn_theme.dart` (แปลง token — งานของ AI Coding ไม่ใช่ session นี้)
- **ห้ามแตะ logic**: Follow/Block/Mute/Report/Chat/Share/Settings/Refresh/infinite-scroll ทั้งหมดคงเดิม 100% — งานนี้เป็น re-skin เท่านั้น
- รอ Founder ยืนยัน `wyn-142`/`wyn-143` อย่างเป็นทางการก่อนส่ง AI Coding แปลง token เป็นโค้ดจริง
- เขียน/แก้ widget test ที่มีอยู่ (`view_profile_screen_test.dart` ถ้ามี) ให้ยังผ่านหลัง re-skin เพราะ logic ไม่เปลี่ยน — เทสต์ที่ผูกกับสี/label ต้องอัปเดตให้ตรงค่าใหม่เท่านั้น
- ตาม `WORKFLOW.md` (Staged Rollout): เนื่องจากนี่คือการเปลี่ยน visual identity ทั้งแอป ไม่ใช่ฟีเจอร์ใหม่เชิงความสามารถ ให้ CTO/Founder เป็นผู้ตัดสินใจว่าต้อง gate ด้วย `isDeveloperAccount()` ก่อนหรือไม่ (เช่น เปิดให้บัญชีนักพัฒนาเห็นธีมใหม่ก่อน) — AI Design ไม่ฟันธงเอง แต่ทำเครื่องหมายไว้ให้ Founder ตัดสินใจก่อน AI Coding เริ่ม

---

# Screen: EditProfileScreen — แก้ไขโปรไฟล์

**Purpose:** ให้ผู้ใช้แก้ไขรูปปก, avatar, ชื่อที่แสดง, username, bio และลิงก์โซเชียล (Instagram/Twitter/YouTube) แล้วบันทึกกลับไปที่โปรไฟล์

**User Flow:**
1. เปิดจากปุ่ม "แก้ไขโปรไฟล์" ใน `ViewProfileScreen` (เฉพาะเจ้าของโปรไฟล์)
2. แตะรูปปก → เลือกแหล่งรูป (กล้อง/คลังภาพ) ผ่าน Bottom Sheet → พรีวิวทันที (ยังไม่อัปโหลด)
3. แตะ avatar → เลือกแหล่งรูป → ไป `ProfilePhotoCropScreen` ก่อนเสมอ → ครอปเสร็จ กลับมาพรีวิว avatar ใหม่
4. แก้ไขฟิลด์ข้อความ (ชื่อที่แสดง/username/bio) — username เช็คความว่างพร้อมกันแบบ debounce
5. แตะแถวลิงก์โซเชียล → เปิด Bottom Sheet แก้ไข URL → บันทึก/ยกเลิก
6. ปุ่ม "บันทึก" (มุมขวาบน) enable เมื่อมีการเปลี่ยนแปลงจริงและ username ไม่ error → กด → บันทึก → pop กลับพร้อมข้อมูลใหม่ หรือแสดง error ถ้าล้มเหลว

**Components:**
1. **Top App Bar** — สูง 64px (ตามค่าปัจจุบัน), ปุ่มย้อนกลับซ้าย (44×44), ชื่อหน้าจอ **"แก้ไขโปรไฟล์" ชิดซ้าย** ถัดจากปุ่มย้อนกลับ (`type.display.l` — **เปลี่ยนจาก centered เดิม** ตาม wyn-143 §3 Top App Bar: "ไม่ centered — energetic/informal"), ปุ่ม "บันทึก" ขวา เป็น `Primary Button` แบบย่อขนาด (height ~36px แทน 52px มาตรฐาน — ข้อยกเว้นเดียวที่อนุญาตเพราะอยู่ใน AppBar ที่มีพื้นที่จำกัด, ยังคง `radius.pill`/พื้น `color.accent`/ตัวหนังสือ `color.paper`), เส้นแบ่งล่าง `color.hairline` หนา 1px
2. **Cover image editor** — การ์ดรูปภาพเต็มความกว้าง สูงคงที่ radius `radius.m` (16px — เปลี่ยนจาก 20px เดิม), มุมล่างขวามี chip ทึบสี `color.ink` (คงสีเข้มคงที่เพื่อ contrast บนรูปใด ๆ ก็ตาม ไม่ผูกกับ light/dark) ไอคอนกล้อง+label "เปลี่ยนรูปปก" ตัวหนังสือ `color.paper`
3. **Avatar editor** — `Avatar` ขนาด **96px** (ตรง token "edit profile" ของ wyn-143 §5 พอดี — ไม่ต้องเปลี่ยนจากเดิม), badge กล้องมุมขวาล่าง วงกลมพื้น `color.accent` (เปลี่ยนจาก `color.ink` เดิม เพื่อให้เป็นจุดเน้น accent เดียวของหน้าจอนี้) ขอบ `color.paper` 2px, `Text Button` ใต้ avatar "เปลี่ยนรูปโปรไฟล์" สี `color.accent`
4. **Section label** "ข้อมูลโปรไฟล์" / "ลิงก์" — `type.overline` หรือ `type.heading.2` (เลือก `heading.2` เพราะเป็นหัวข้อ section ตาม wyn-142 type scale ไม่ใช่ label เล็กแบบ "TRENDING")
5. **การ์ดฟิลด์ข้อมูล** — กรอบ `color.hairline` 1px, radius `radius.m`, ภายในมี `Text Input` (component 2) 3 ช่อง: ชื่อที่แสดง / ชื่อผู้ใช้ (prefix "@") / แนะนำตัว (multiline) — แต่ละช่อง label คงที่ด้านบน, helper text `type.caption` สี `color.ink.muted`, ตัวนับตัวอักษรถ้ามี
   - ชื่อผู้ใช้: suffix แสดงสถานะตรวจสอบ — `checking` = Spinner เล็ก, `available` = ไอคอนถูก `color.success`, `taken`/`invalid` = ขอบ input เปลี่ยนเป็น `color.error` 1.5px + ข้อความ error ใต้ input พร้อมไอคอนเตือนเล็ก ๆ (ตาม wyn-143 §2 Error state — **เปลี่ยนจากขอบสีปกติ+ข้อความเฉย ๆ เดิม**)
6. **การ์ดลิงก์โซเชียล** — กรอบ `color.hairline`, radius `radius.m`, แต่ละแถวเป็น `List Item` (label ซ้าย, ค่า/placeholder "เพิ่มลิงก์" ขวา สี `color.ink.muted` เมื่อว่าง, chevron ขวาสุด), คั่นด้วยเส้น `color.hairline` บาง
7. **แก้ไขลิงก์** — เปลี่ยนจาก `AlertDialog` กลางจอเดิม **เป็น Bottom Sheet** (มุมบนโค้ง `radius.l`, drag handle) เพราะ wyn-143 จำกัด Modal กลางจอไว้เฉพาะ "การตัดสินใจสำคัญ" (เช่น ยืนยันลบ) — แก้ไข URL ไม่ใช่กรณีนั้น: ภายในมี `Text Input` (label ชื่อแพลตฟอร์ม, placeholder "https://") + ปุ่ม "ยกเลิก" (`Text Button`) กับ "บันทึก" (`Primary Button`) วางแถวล่าง
8. **Error message** (บันทึกล้มเหลว) — ข้อความ `type.body.m` สี `color.error` กึ่งกลาง ใต้การ์ดลิงก์ (inline error ตาม wyn-143 §7 ไม่ใช้ Toast เพราะผูกกับผลของปุ่ม "บันทึก" โดยตรง)

**Interactions:**
- แตะรูปปก/avatar เปิด Bottom Sheet เลือกแหล่งรูป (กล้อง/คลังภาพ) — Bottom Sheet มาตรฐานตาม component 9
- แตะ avatar ที่เลือกแล้วนำไป `ProfilePhotoCropScreen` เสมอ (ไม่เปลี่ยน flow เดิม)
- พิมพ์ username → debounce 400ms → เรียก availability check (ไม่เปลี่ยน logic)
- ปุ่ม "บันทึก" ปิดใช้งาน (`opacity 40%`) จนกว่าจะมีการเปลี่ยนแปลงจริงและ username ผ่านเงื่อนไข — ระหว่างบันทึกแสดง spinner แทนข้อความในปุ่ม (ตาม Primary Button "Loading" state ของ wyn-143 §1)
- แตะแถวลิงก์ → เปิด Bottom Sheet แก้ไข → "บันทึก" ปิด sheet และอัปเดตค่าในฟอร์ม (ยังไม่บันทึกจริงจนกว่าจะกด "บันทึก" หลักที่ AppBar — พฤติกรรมเดิม)

**States:**
- ฟิลด์ปกติ / focus (ขอบ `color.accent` 1.5px) / error (ขอบ `color.error` + ข้อความ+ไอคอน) — ตาม wyn-143 §2
- username: `unchanged` / `checking` (spinner) / `available` (เครื่องหมายถูก) / `taken` / `invalid` (error + ข้อความ)
- กำลังบันทึก (`_isSaving`) → ฟิลด์/ปุ่มเลือกรูปทั้งหมด disabled, ปุ่ม "บันทึก" แสดง spinner
- บันทึกล้มเหลว → error message ปรากฏใต้การ์ดลิงก์, ฟอร์มกลับมาแก้ไขได้
- รูปที่เลือกแล้ว (ยังไม่อัปโหลด) → พรีวิวจาก local bytes ทันที (avatar/cover)

**Responsive Behavior:**
- ฟอร์มเรียงแนวตั้งทั้งหมด ใช้ `SingleChildScrollView` เดิม รองรับ 320–430px
- รูปปกสูงคงที่ ความกว้างเต็มจอ (คง aspect ratio เดิม)
- คีย์บอร์ดเปิดแล้วต้อง scroll ตามฟิลด์ที่ focus ได้ (ไม่บัง input)

**Accessibility:**
- ทุก `Text Input` มี label ที่มองเห็นได้เสมอ (ไม่ใช้ placeholder แทน label)
- Error ต้องมีทั้งสี + ไอคอน + ข้อความ (ไม่ใช้สีอย่างเดียว)
- ปุ่ม "บันทึก" ที่ disabled ต้องสื่อสารชัดด้วย opacity ที่ยังอ่าน label ได้ ไม่ใช่จางจนมองไม่เห็นว่าเป็นปุ่ม
- Bottom Sheet แก้ไขลิงก์ต้อง trap focus ที่ input เมื่อเปิด และคืน focus ที่แถวเดิมเมื่อปิด
- Touch target ปุ่ม/แถวทั้งหมด ≥44×44px

**Design Rules:**
- `color.accent` ใช้เฉพาะปุ่ม "บันทึก", badge กล้องบน avatar, ขอบ input ตอน focus, ไอคอนสถานะ username ที่ผ่าน (ใช้ `color.success` ไม่ใช่ accent — แก้ไขให้ตรง semantics สี)
- ห้าม Liquid Glass, ห้ามใช้ Modal กลางจอสำหรับการแก้ไขข้อมูลทั่วไป (สงวนไว้เฉพาะการยืนยันสำคัญตาม wyn-143 §9)
- Card ใช้ radius `radius.m`, Bottom Sheet ใช้ radius `radius.l`, ปุ่มใช้ `radius.pill`

**Handoff:**
- ไฟล์ที่ต้องแก้: `edit_profile_screen.dart`, `widgets/labeled_field.dart` (เพิ่ม error icon + โฟกัสสี accent), `widgets/avatar_circle.dart`
- เปลี่ยน `_editSocialLink` จาก `showDialog` (`AlertDialog`) เป็น `showModalBottomSheet` ตาม design rule ข้างต้น — ต้องปรับ widget test ที่ผูกกับ `AlertDialog` ให้ตรง component ใหม่
- ห้ามแตะ logic การตรวจ username, การอัปโหลดรูป, validation `_hasChanges`/`_canSave` — เปลี่ยนเฉพาะ visual

---

# Screen: ProfilePhotoCropScreen — ปรับตำแหน่ง/ครอปรูปโปรไฟล์

**Purpose:** ให้ผู้ใช้ลาก/ซูมรูปที่เพิ่งเลือกมาก่อนนำไปตั้งเป็นรูปโปรไฟล์ (หรือ aspect ratio อื่นสำหรับรูปโพสต์ ผ่าน parameter เดียวกัน) แล้วส่งรูปที่ครอปแล้วกลับไปยังหน้าที่เรียก

**User Flow:**
1. ถูกเปิดอัตโนมัติจาก `EditProfileScreen._pickImage()` ทันทีหลังเลือกรูปจากกล้อง/คลังภาพ
2. ลาก (1 นิ้ว) เพื่อขยับตำแหน่ง / บีบนิ้ว (2 นิ้ว) เพื่อซูม หรือใช้ปุ่ม +/− / แถบเลื่อนสำหรับผู้ที่ใช้ screen reader
3. กด "เสร็จสิ้น" → ประมวลผลครอป → ส่งรูปที่ครอปแล้วกลับ (pop พร้อม bytes)
4. หรือกด "ยกเลิก" → กลับไปหน้าเดิมโดยไม่มีการเปลี่ยนแปลงใด ๆ

**Components:**
1. **Top bar บนพื้นดำ** (ข้อยกเว้นไม่ใช้ Top App Bar มาตรฐานของ wyn-143 — ดู Design Rules) — ปุ่ม "ยกเลิก" ซ้าย (`Text Button` สีขาว/`color.paper`), หัวข้อ "ปรับตำแหน่งรูป" กึ่งกลาง (`type.body.l` สีขาว — คงกึ่งกลางเพราะเป็น convention ของเครื่องมือครอปรูปสากล ไม่ใช่ Top App Bar ปกติของแอป), ปุ่ม "เสร็จสิ้น" ขวา (`Text Button` ตัวหนา สี `color.accent` เพื่อสื่อว่าเป็น primary action แยกจาก "ยกเลิก" — **เปลี่ยนจากสีขาวเดิมที่ทั้งสองปุ่มดูเท่ากัน**)
2. **Crop viewport** — กรอบวงกลม (avatar, `circular: true`) หรือสี่เหลี่ยมมุมโค้ง `radius.m` (aspect ratio อื่น) ขนาดคงที่ 260px (ด้านยาวสุด), ภาพที่เลือกอยู่ด้านใน, mask overlay รอบกรอบทึบสีเทาเข้ม (ไม่ blur), เส้นขอบกรอบสีขาวคงที่ 1.5px (ไม่ผูกกับ `color.accent`/token ธีม — ดู Design Rules)
3. **Zoom bar** — ปุ่มไอคอนลบ/บวก (สีขาว, 44×44 touch target) + `Slider` ตรงกลาง (track ที่ยังไม่ active สีขาว 38% opacity, track/thumb ที่ active สี `color.accent` — เปลี่ยนจากสีขาวล้วนเดิมเพื่อให้เห็น progress ชัดและใช้ accent อย่างมีเหตุผล)
4. **Error message** — ข้อความ `type.body.m` สี error ที่ปรับให้อ่านง่ายบนพื้นดำเสมอ (ใช้ dark-mode variant ของ `color.error` คือ `#FF6369` ไม่ว่าแอปจะอยู่ light หรือ dark mode เพราะพื้นหลังหน้าจอนี้เป็นสีดำคงที่)
5. **Loading spinner** (ระหว่างโหลดขนาดภาพ) — `Spinner` สีขาว กลางจอ

**Interactions:**
- Pan (ลาก 1 นิ้ว) + Pinch-to-zoom (2 นิ้ว) พร้อมกันได้ในท่าเดียว (ตาม component 11 Media Viewer — pinch-to-zoom rule)
- ปุ่ม +/− ปรับซูมทีละ 0.25 หน่วย, ขอบเขตซูม 1.0–3.0 เท่า (ไม่เปลี่ยนจากเดิม)
- Slider เป็นทางเลือกสำหรับผู้ใช้ screen reader/ไม่สามารถ pinch ได้ (`Semantics(label: 'ระดับการซูม', value: '$percent%')`)
- กด "เสร็จสิ้น" → disable ปุ่มระหว่างประมวลผล แสดง spinner แทนข้อความ (Primary/Text Button Loading state)

**States:**
- กำลังโหลดขนาดภาพ → spinner กลางจอ, ปุ่ม "เสร็จสิ้น"/zoom bar disabled
- โหลดภาพล้มเหลว → ข้อความ error กลางจอ แทน viewport
- พร้อมใช้งาน → viewport + zoom bar โต้ตอบได้เต็มที่
- กำลังประมวลผลครอป (`_isProcessing`) → ปุ่ม "เสร็จสิ้น" แสดง spinner, กด "ยกเลิก" ยังกดได้ปกติ
- ครอปล้มเหลว → ข้อความ error ใต้ viewport, กลับมาโต้ตอบได้ตามปกติ

**Responsive Behavior:**
- ทดสอบที่ 320px ขึ้นไป — กรอบครอป 260px (คงที่) + zoom bar ต้องไม่ล้นความกว้างจอที่ 320px (ตรวจ padding ซ้าย-ขวาของ zoom bar ให้พอดี)
- ทำงานเหมือนกันทุกขนาดจอเพราะกรอบเป็นขนาดคงที่ กึ่งกลางเสมอ

**Accessibility:**
- ปุ่ม +/− และ Slider ให้ทางเลือกที่ไม่ต้องพึ่ง multi-touch/pinch เสมอ (ตาม Product spec Edge Case เดิม)
- Slider มี `Semantics(label, value)` ที่อ่านเปอร์เซ็นต์ซูมปัจจุบันได้
- Contrast ของปุ่ม/ข้อความสีขาวและ `color.accent` บนพื้นดำต้องผ่าน AA (ตรวจเฉพาะเมื่อเปลี่ยนสี "เสร็จสิ้น"/slider เป็น accent)
- ปุ่ม "ยกเลิก"/"เสร็จสิ้น" touch target ≥44×44px (คงเดิมด้วย `leadingWidth: 88`/AppBar action ที่มีอยู่)

**Design Rules:**
- **ข้อยกเว้นเจตนา**: หน้าจอนี้ใช้พื้นหลังสีดำคงที่เสมอ ไม่สลับตาม light/dark mode ของแอป และ Top bar ไม่ตามโครง "ชิดซ้าย" ของ wyn-143 §3 — เพราะเป็น convention สากลของเครื่องมือครอปรูป (เหมือน IG/FB/ระบบเลือกรูปของ OS) ที่ผู้ใช้คุ้นเคยอยู่แล้ว การเปลี่ยนพื้นหลัง/เลย์เอาต์ตรงนี้ตาม Flare เต็มรูปแบบจะขัดกับความคุ้นเคยของผู้ใช้โดยไม่มีประโยชน์เพิ่ม — คงไว้เหมือนเดิม เปลี่ยนเฉพาะสี accent ของปุ่ม primary action ("เสร็จสิ้น") และ slider เพื่อให้ยังรู้สึกเป็น "Flare" ในจุดที่ไม่กระทบ usability
- เส้นขอบกรอบครอป (มาสก์) ใช้สีขาวคงที่เสมอ ไม่ผูกกับ `color.accent`/token ธีม เพราะต้องตัดกับพื้นดำและรูปภาพหลากสีได้เสมอ ไม่ใช่ UI แบรนด์ปกติของแอป
- ไม่ใช้ Liquid Glass ที่ mask overlay (ทึบเสมอ ตามกติกาเดิม)

**Handoff:**
- ไฟล์ที่ต้องแก้: `profile_photo_crop_screen.dart` เท่านั้น (เปลี่ยนสีปุ่ม "เสร็จสิ้น" เป็น `color.accent`, สี slider active เป็น `color.accent`, สี error message เป็น `color.error` dark-variant คงที่)
- **ห้ามแตะ**: `profile_photo_crop.dart` (คณิตศาสตร์ pan/zoom/crop) — ไม่มีการเปลี่ยนแปลงใด ๆ ในไฟล์นี้
- เขียน/แก้ widget test ที่ผูกกับสีปุ่ม "เสร็จสิ้น"/slider ให้ตรงค่าใหม่เท่านั้น ไม่แตะเทสต์ gesture/crop math

---

## สรุปจุดที่ต่างจากโค้ดปัจจุบันอย่างมีนัยสำคัญ (สำหรับ Founder ตรวจก่อนอนุมัติ)

1. Avatar หัวโปรไฟล์เล็กลงจาก ~86px → 64px (ตรง token avatar "profile header" ของ wyn-143)
2. Top App Bar ของ `EditProfileScreen` เปลี่ยนชื่อหน้าจอจาก centered → ชิดซ้าย (ตรง wyn-143 §3)
3. แก้ไขลิงก์โซเชียลใน `EditProfileScreen` เปลี่ยนจาก dialog กลางจอ → Bottom Sheet (Modal กลางจอสงวนไว้เฉพาะการยืนยันสำคัญตาม wyn-143 §9)
4. TabBar indicator ของ `ViewProfileScreen` เปลี่ยนสีจาก `WynColors.ink` → `color.accent` (ให้ตรงกติกา "accent = active state")
5. ปุ่ม "เสร็จสิ้น" ในหน้าครอปรูปเปลี่ยนจากสีขาว (เท่ากับปุ่ม "ยกเลิก") → `color.accent` เพื่อแยก primary action ให้ชัด
6. หน้าครอปรูปยังคงพื้นหลังสีดำ + top bar กึ่งกลางเป็นข้อยกเว้นตั้งใจ ไม่ตาม Flare เต็มรูปแบบ (ดูเหตุผลใน Design Rules ของหน้านั้น)

ทั้งหมดนี้เป็นการ re-skin เท่านั้น ไม่มีจุดใดเปลี่ยน business logic, validation, หรือ data flow ที่มีอยู่
