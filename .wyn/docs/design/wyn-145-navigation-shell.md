# WYN "Flare" — Navigation Shell (V1.0 — PROPOSED)

Status: PROPOSED
Owner: AI Design
อ้างอิง: wyn-142-visual-identity-redesign.md, wyn-143-core-component-library.md

## บริบทจากโค้ดจริง (ก่อนเขียนสเปก)

อ่านโค้ดจริงจาก `app/lib/main.dart`, `app/lib/core/navigation/app_navigator.dart`, `app/lib/core/navigation/deep_link_service.dart`, `app/lib/features/root/presentation/root_shell.dart`, `root_navigation_controller.dart`, `side_menu.dart`, `widgets/wynos_founder_bottom_navigation.dart` และ `app/lib/features/auth/presentation/auth_gate.dart` แล้ว สรุปโครงสร้างจริง ณ ปัจจุบัน:

- **Bottom nav มี 5 ช่องจริงตาม `wyn-v1.0.0-roadmap.md`**: Home, Search, Drop, Notifications, Profile — ตรงกับที่ระบุในโจทย์ ไม่มีส่วนต่างจาก roadmap
- **Drop (ช่องกลาง) ไม่ใช่ tab จริง** — เป็น action ที่ `push` เปิด `CreateDropScreen` แบบ full-screen route (`Navigator.of(context).push`) ไม่เคยเป็น `_tabIndex` และไม่มี selected state ของตัวเอง มี haptic เฉพาะปุ่มนี้ (`WynFeedback.toggle()`) ต่างจาก 4 tab จริงที่ใช้ `WynFeedback.selectionChanged()`
- **มีแค่ 4 tab จริงใน `IndexedStack`** (Home, Search, Notifications, Profile) เพราะ Drop ไม่ mount เป็นหน้า
- **Guest gate**: Drop/Notifications/Profile ต้องผ่าน `requireRealAccount()` ก่อนเสมอ (guest/anonymous เข้าไม่ได้) ส่วน Home/Search guest เข้าได้อิสระ
- **Remount-on-visit**: Profile และ Notifications tab bump key ทุกครั้งที่ถูกเข้าจาก tab อื่น (fetch ใหม่เสมอ, ไม่ cache ค้าง) — Notifications ยังเคลียร์ unread badge ทันทีแบบ optimistic ตอนแตะเข้า tab ด้วย
- **Home มีพฤติกรรม reselect พิเศษ**: แตะ Home ซ้ำตอนอยู่ Home อยู่แล้ว ไม่เปลี่ยน tab แต่ส่ง signal ให้ scroll-to-top/refresh
- **สีที่ใช้ในโค้ดปัจจุบันเป็นของ Sapphire เดิม** ไม่ใช่ Flare: ปุ่ม Drop ใช้ `WynColors.ink` (ไม่ใช่ accent), ไอคอน active ใช้ `WynColors.ink` (ไม่ใช่ accent), badge ใช้ `Theme.of(context).colorScheme.error` (แดงทั่วไป ไม่ใช่ `color.heart`) — ต้องแก้ทั้งหมดให้ตรง wyn-142/143 ตอนถึงมือ AI Coding
- **Side Menu ไม่ได้ mount ที่ RootShell** แต่ mount เป็น `drawer:` ของ `HomeFeedScreen` เอง (เปิดจาก hamburger icon ในหน้า Home/Notifications) — จึงไม่ใช่ shell-level component โดยตรง แต่ยังอยู่ในหมวด "Navigation" ของ wyn-143 §3 จึงพูดถึงไว้สั้น ๆ ในเอกสารนี้เพื่อความครบถ้วน ส่วนสเปกเต็มของเนื้อหาข้างในจะอยู่ในสเปกหน้า Home/Notifications (ไม่ใช่ scope ของ wyn-145)
- **`themeMode` ปัจจุบันถูกล็อกเป็น `ThemeMode.light` เสมอ** ตาม Founder decision 2026-08-24 (`DECISIONS.md`, WYN-071) — ยังไม่ตาม dark mode ของระบบ แม้ wyn-142 จะกำหนด token ไว้ทั้ง light/dark ก็ตาม เอกสารนี้นิยาม token ทั้งสองโหมดตามสเปกที่อนุมัติ แต่ **ไม่เปลี่ยนการล็อก `ThemeMode.light` เอง** เพราะเป็นการเปลี่ยน decision เดิมของ Founder ต้องรอคำสั่งแยกต่างหาก
- **`AuthGate` เป็น router ล้วน ไม่ใช่หน้าจอ UI ถาวร** — มี state ภายในหลายชั้นตามลำดับ: blocked-login (ค่าใน memory, เช็คก่อนอย่างอื่นเสมอ) → session null (เช็ค deep-link ก่อนพา guest sign-in อัตโนมัติ หรือไป WelcomeScreen) → moderation status → mandatory document acceptance → guest(anonymous) ลัดตรง RootShell → onboarding state (error/loading/ไม่จบ/จบแล้ว) → RootShell ลำดับการเช็คนี้ถูกล็อกไว้แล้วตาม WYN-029/WYN-046 **ห้ามเปลี่ยน** งานนี้ปรับเฉพาะหน้าตาของ Loading/Error state เท่านั้น

---

## Screen: Bottom Navigation Shell

Purpose: shell หลักที่ครอบทุกหน้าจอหลัง AuthGate ตัดสินว่าผู้ใช้ (หรือ guest) พร้อมเข้าแอปแล้ว ให้สลับระหว่าง 5 ปลายทางหลักและเข้าถึง action "สร้างโพสต์" ได้จากทุกที่ในแอป

User Flow:
1. AuthGate ส่งต่อมาที่ `RootShell` (สำเร็จ onboarding หรือเป็น guest/anonymous) → เริ่มที่ tab Home เป็นค่าเริ่มต้น (หรือ Profile ถ้าเพิ่งสลับบัญชีผ่าน Account Switcher)
2. ผู้ใช้แตะ tab Home/Search/Notifications/Profile → เนื้อหาสลับทันที (ไม่มี transition ข้ามหน้า เพราะเป็นการสลับ view ภายใน shell เดียว)
3. ผู้ใช้แตะ Drop (ปุ่มกลาง) → เปิด `CreateDropScreen` แบบเต็มจอทับ shell (ไม่ใช่การเปลี่ยน tab) → สร้างโพสต์สำเร็จ → กลับมาที่ shell เดิม → Home tab รีเฟรชเนื้อหาใหม่ให้เห็นโพสต์ล่าสุด
4. ผู้ใช้แตะ Home ซ้ำระหว่างอยู่ Home อยู่แล้ว → ไม่เปลี่ยน tab แต่ scroll กลับขึ้นบนสุด/รีเฟรช
5. Guest (ยังไม่มีบัญชีจริง) แตะ Drop/Notifications/Profile → เจอ guest gate ก่อนเสมอ ให้เลือกสมัคร/เข้าสู่ระบบ หรือยกเลิกกลับมา Home/Search ต่อได้ตามปกติ

Components (อ้างอิง wyn-143 เท่านั้น):
- **Bottom Tab Bar** (§3) — 5 ช่อง: Home / Search / Drop / Notifications / Profile
- **Badge** ตัวเลขแจ้งเตือน (§6) บนไอคอน Notifications
- **ปุ่ม Drop** — วงกลม filled ยกสูงกว่าระดับ tab bar เล็กน้อย ตามสเปก Bottom Tab Bar ใน §3
- **Bottom Sheet/Modal** (§9) — ใช้เป็น guest gate เมื่อ guest แตะ tab ที่ต้องล็อกอินจริง
- **Top App Bar** (§3) — ของแต่ละหน้าจอลูกเอง (นอก scope ของ shell นี้โดยตรง แต่ height/behavior ต้องอ้าง wyn-143 เดียวกัน เพื่อความสม่ำเสมอ)
- **Side Menu** (§3) — mount อยู่ใน Home/Notifications ไม่ใช่ shell ระดับ RootShell แต่ยังต้องตรง spec เดียวกัน (สเปกเนื้อหาเต็มอยู่นอก scope เอกสารนี้)

Interactions:
- แตะ tab Home/Search/Notifications/Profile ที่ไม่ใช่ tab ปัจจุบัน → สลับ content + haptic แบบ selection (เบา) — เป็น haptic เดียวในระบบ navigation ทั้งหมด (push/pop อื่น ๆ ไม่มี haptic)
- แตะ Home ซ้ำขณะอยู่ Home → ไม่มี haptic เพิ่ม, ส่ง signal scroll-to-top/refresh ให้ Home จัดการเอง
- แตะ Drop → haptic แบบหนักกว่า (toggle) แยกจาก selection haptic ของ tab อื่น เพราะเป็น action สร้างเนื้อหา ไม่ใช่ navigation ธรรมดา → เปิด CreateDropScreen เต็มจอ
- เข้า Profile/Notifications tab จาก tab อื่น → บังคับ fetch ใหม่ทุกครั้ง (ไม่ใช้ข้อมูลค้างจากครั้งก่อน)
- เข้า Notifications tab → เคลียร์ unread badge ทันที (optimistic, ไม่รอ round-trip ยืนยันจาก server)
- Guest แตะ Drop/Notifications/Profile → guest gate เปิดก่อนเปลี่ยนอะไรบนจอ ถ้ายกเลิก ไม่มีอะไรเปลี่ยน (ยังอยู่ tab เดิม)
- หน้าจอที่ถูก push ทับ shell (เช่นเปิดจากลิงก์แชร์/push notification) สามารถสั่ง shell ให้เปลี่ยน tab แทนได้ (ผ่านกลไกภายในที่มีอยู่แล้ว) โดยไม่ต้อง pop กลับมาก่อน — พฤติกรรมเดิม ไม่เปลี่ยน

States:
- **Default (signed-in, onboarded)**: ทั้ง 4 tab ใช้งานได้เต็ม + Drop action พร้อมใช้
- **Guest (anonymous session)**: Home/Search ใช้งานได้อิสระ, Drop/Notifications/Profile ถูก gate
- **Badge = 0**: ไม่แสดง badge เลย (ไม่ใช่ badge ว่าง/จุดเปล่า)
- **Badge 1–9**: แสดงตัวเลขจริง; **Badge >9**: แสดง "9+"
- **Tab ที่เลือกอยู่**: ไอคอน filled + สี `color.accent`; tab ที่ไม่ได้เลือก: ไอคอน outline + สี `color.ink.muted`
- Loading/empty/error ของเนื้อหาแต่ละ tab จัดการภายในหน้าจอลูกเอง ไม่ใช่ state ของ shell นี้

Responsive Behavior: มือถือ portrait เป็นหลัก, รองรับ safe-area ด้านล่างเสมอ (notch/gesture bar), ความสูง bottom bar คงที่ไม่ปรับตาม breakpoint, ปุ่ม Drop ต้องไม่ถูก safe-area บัง; เว็บ/หน้าจอกว้างคง layout เดียวกับมือถือ (ไม่ทำ side rail ใหม่ในงานนี้ — นอก scope)

Accessibility:
- ทุก tab ต้องมี Semantics(`button: true`, `selected`, label ภาษาไทยของ tab นั้น) — ปุ่ม Drop มี label แยก "สร้างโพสต์ใหม่" ไม่ปนกับ label tab อื่น
- ปุ่ม Drop excludeSemantics ของ icon ภายในตัวเอง ให้เหลือ semantics เดียวจาก wrapper (กัน screen reader อ่านซ้ำ)
- Badge ต้องมี label เสียงบอกจำนวนจริง (เช่น "การแจ้งเตือน มี 5 รายการที่ยังไม่อ่าน") ไม่ใช่สื่อสารด้วยสี/ตัวเลขที่มองเห็นอย่างเดียว
- Touch target ทุกช่อง (รวม Drop) ต้อง ≥44×44px ตามกติกา wyn-142
- Contrast ของ label/icon ต้องผ่าน AA ทั้ง light/dark

Design Rules (สิ่งที่ต้องแก้จากโค้ดปัจจุบันให้ตรง wyn-142/143):
- ปุ่ม Drop: เปลี่ยนพื้นหลังจาก `color.ink` (ปัจจุบัน) → `color.accent` (Coral Flare) ตาม wyn-143 §3 ไอคอน `+` ยังเป็นสีขาว/`color.paper`
- ไอคอน/label tab ที่ selected: เปลี่ยนจาก `color.ink` (ปัจจุบัน) → `color.accent`
- Badge ตัวเลข: เปลี่ยนจาก `colorScheme.error` (แดงทั่วไปตาม Sapphire theme) → `color.heart` ตาม wyn-143 §6 (คนละโทนจาก accent ตามหลักการแยกสี like/error/accent ของ wyn-142)
- พื้นหลัง tab bar: `color.paper` (light) / `color.surface` (dark) + เส้นบน `color.hairline` หนา (คงโครงเดิม ไม่ใช่ floating pill)
- Label ใช้ `type.caption`/`type.body.s` ตาม type scale ใหม่ (Manrope) แทน hardcoded font ปัจจุบัน
- ห้ามใช้ Liquid Glass, ห้ามลอก layout Bottom Nav ของ Instagram/TikTok โดยตรง (คงกติกาเดิมจาก wyn-142)
- ไม่เปลี่ยน business logic ใด ๆ ของ `RootShell`/`RootNavigationController` (5-tab count, guest gate, remount-on-visit, haptic timing) — งานนี้เป็นการเปลี่ยนหน้าตาเท่านั้น

Handoff: รอ Founder ยืนยัน wyn-142/wyn-143 ก่อน จากนั้น AI Coding แก้เฉพาะ `WynosFounderBottomNavigation` widget (`app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart`) ให้ใช้ token ใหม่ทั้งหมด (สี, ฟอนต์, badge) โดยคง logic ทั้งหมดใน `root_shell.dart`/`root_navigation_controller.dart` ไว้เหมือนเดิมทุกประการ (5 tab, guest gate, remount-on-visit, haptic, reselect-to-refresh) ยืนยันด้วย `flutter analyze`/`flutter test` หลังแก้เสร็จว่าไม่มี regression ต่อพฤติกรรมเดิม

---

## Screen: Auth Gate / Splash

Purpose: จอที่ไม่มี UI ถาวรของตัวเอง แต่เป็น router/gatekeeper ตัดสินสถานะผู้ใช้ทุกครั้งที่แอปเปิดหรือ auth state เปลี่ยน แล้วพาไปหน้าจอที่ถูกต้อง (Welcome / Onboarding / Account Restricted / Document Acceptance / Root Shell) — งานนี้นิยามเฉพาะ "หน้าตา" ของสถานะ Loading และ Error ที่ auth gate แสดงระหว่างตัดสินใจ **ไม่แตะ routing logic**

User Flow:
1. แอปเปิด → `AuthGate` mount → เช็ค blocked-login state ที่ค้างใน memory ก่อนอย่างอื่นเสมอ (มี → ไป Account Restricted ทันที, สเปกแยกต่างหาก)
2. ไม่มี blocked-login → เช็ค session:
   - **session ว่าง** → เช็คว่ามี deep-link content path ไหม → มี → sign-in แบบ anonymous เงียบ ๆ ให้อัตโนมัติ (แสดง Loading ระหว่างนี้) → สำเร็จ → เข้าสู่ flow "signed-in" ด้านล่างในฐานะ guest / ไม่มี deep-link → ไป WelcomeScreen (สเปกแยก)
   - **session มีอยู่** → เช็ค moderation status (Loading ระหว่างรอ) → ถ้าโดน suspend/ban → ไป Account Restricted (สเปกแยก) → เช็คการยอมรับเอกสารบังคับ (Loading ระหว่างรอ) → ยังไม่ยอมรับ → ไป Document Acceptance (สเปกแยก) → ถ้าเป็น guest (anonymous) → ลัดตรงไป Root Shell ทันที (ข้าม onboarding) → ถ้าไม่ใช่ guest เช็ค onboarding state (Loading ระหว่างรอ) → ล้มเหลว → แสดง Error พร้อมปุ่มลองใหม่ → ยังไม่จบ → ไป OnboardingFlow (สเปกแยก) → จบแล้ว → บันทึกเข้า Account Switcher เงียบ ๆ แล้วเข้า Root Shell

Components (อ้างอิง wyn-143):
- **Spinner** เต็มจอ (§8) แทน `CircularProgressIndicator()` เปล่าแบบปัจจุบัน
- **Empty State layout** (§12) นำโครงมาใช้กับหน้า Error (ไอคอน + หัวข้อ + คำอธิบาย + ปุ่ม action) แม้จะไม่ใช่ empty state ความหมายจริง แต่โครง visual เดียวกันเหมาะกับ "ไม่มีอะไรให้ทำนอกจากลองใหม่"
- **Primary/Text Button** (§1) สำหรับปุ่ม "ลองใหม่"

Interactions: ไม่มี interaction จากผู้ใช้ระหว่าง Loading ทุกจุด (เป็นสถานะรอ future/stream resolve เท่านั้น) ยกเว้นจอ Error ที่มีปุ่ม "ลองใหม่" กดแล้ว re-trigger การเช็คใหม่ทันที (ไม่ต้องปิดแอป/เปิดใหม่); ทุกครั้งที่ auth event ที่เกี่ยวข้อง (signed in / signed out / สลับบัญชี) เกิดขึ้น ระบบ pop stack ของ route ที่ถูก push ทับ AuthGate ทั้งหมดกลับมาที่ AuthGate ก่อนเสมอ (คงพฤติกรรมเดิม)

States:
1. **Loading** — เกิดได้หลายจุด (initial, เช็ค moderation, เช็คเอกสาร, เช็ค onboarding, กำลังจัดการ blocked login, กำลัง sign-in guest จาก deep link) ปัจจุบันทุกจุดใช้ UI เดียวกัน (Scaffold + spinner เปล่า) — คงให้ใช้ UI เดียวกันทุกจุดต่อไป เพื่อความเรียบง่าย แค่เปลี่ยนสไตล์ spinner
2. **Error** — เกิดเฉพาะตอนเช็ค onboarding state ล้มเหลว (ไม่มีทางเช็คซ้ำอัตโนมัติได้อย่างปลอดภัย ต้องให้ผู้ใช้กดลองใหม่เอง) — ปัจจุบันเป็น plain text + TextButton ไม่มี token ใด ๆ
3. **Blocked** (Suspended/Banned) → ส่งต่อ Account Restricted (สเปกแยก ไม่ใช่ scope นี้)
4. **Signed out** → Welcome Screen (สเปกแยก)
5. **Onboarding ยังไม่จบ** → Onboarding Flow (สเปกแยก)
6. **เอกสารยังไม่ยอมรับ** → Document Acceptance (สเปกแยก)
7. **สำเร็จ/Guest** → Root Shell (ดูหัวข้อด้านบน)

Responsive Behavior: full-screen centered content ทุก state (Loading/Error) เหมือนกันทุกขนาดจอ ไม่มี layout พิเศษสำหรับจอกว้าง เพราะเป็นสถานะชั่วคราวที่ผู้ใช้ไม่ควรเห็นนาน

Accessibility:
- Spinner ต้องมี semantics label "กำลังโหลด" (ปัจจุบันไม่มีเลย — ต้องเพิ่ม)
- ปุ่ม "ลองใหม่" ต้อง touch target ≥44×44px และมี label ชัดเจนสำหรับ screen reader
- ข้อความ error ต้องอ่านออกเสียงได้ปกติ (เป็น text ธรรมดา), ขนาดตัวอักษรไม่ต่ำกว่า `type.body.m` (14px)
- Contrast ของทุกองค์ประกอบผ่าน AA ทั้ง light/dark

Design Rules:
- เปลี่ยน spinner จาก `CircularProgressIndicator()` สี default ของ Material → สี `color.accent` ตาม wyn-143 §8 บนพื้นหลัง `color.paper` (light) / พื้นหลังมืดตาม dark token (dark) — ไม่ใช่พื้นขาว/ดำ default เฉย ๆ อีกต่อไป
- เปลี่ยนหน้า Error ให้ตรงโครง Empty State (wyn-143 §12): ไอคอนเรียบง่าย + หัวข้อ `type.heading.2` + คำอธิบาย `type.body.m` สี `color.ink.muted` + ปุ่ม Primary/Secondary "ลองใหม่" (แทน bare `TextButton`)
- โทนข้อความปรับให้เป็นมิตรตาม personality "Flare" — เช่น "เชื่อมต่อไม่สำเร็จ ลองอีกครั้งนะ" แทนถ้อยคำทางการเดิม "เชื่อมต่อไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" (ตัดคำ "กรุณา" ที่เป็นทางการเกินไป)
- **ห้ามเปลี่ยนลำดับการเช็ค/routing logic ของ `AuthGate` โดยเด็ดขาด** (blocked → deep-link guest → moderation → document acceptance → guest-skip-onboarding → onboarding → RootShell) เพราะเป็นกติกาที่ล็อกไว้แล้วจาก WYN-029/WYN-046 การเปลี่ยนใด ๆ ต่อ decision logic นี้ถือเป็น authentication/authorization behavior change ต้องขอ Founder อนุมัติแยกต่างหาก ไม่ใช่งาน design ธรรมดา
- ไม่เปลี่ยนการล็อก `themeMode: ThemeMode.light` ที่มีอยู่ (WYN-071, DECISIONS.md 2026-08-24) — token dark mode ของ Flare ถูกนิยามไว้ในเอกสารนี้/wyn-142 เพื่อพร้อมใช้ในอนาคต แต่การเปิดใช้งานจริงต้องรอคำสั่ง Founder แยก

Handoff: รอ Founder ยืนยัน wyn-142/wyn-143 ก่อน จากนั้น AI Coding แก้เฉพาะ widget ภายใน `app/lib/features/auth/presentation/auth_gate.dart` คือ `_LoadingScreen` และ `_ErrorRetryScreen` เท่านั้น ให้ใช้ token ใหม่ตามข้างต้น **ห้ามแตะ `_AuthGateState.build()`/ลำดับ FutureBuilder/StreamBuilder ใด ๆ** เพราะเป็น business logic ไม่ใช่ visual — ยืนยันด้วย `flutter analyze`/`flutter test` ว่า auth flow tests เดิมทั้งหมดยังผ่านหลังแก้
