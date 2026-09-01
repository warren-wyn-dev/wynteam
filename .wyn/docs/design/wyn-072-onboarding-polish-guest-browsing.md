# Design Spec — WYN-072: Onboarding Polish + Guest Browsing

Owner: AI Design → AI Coding
อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md`, `design-reference/SPEC.md` (Sapphire, System font ตามมติ 2026-08-30 — **ไม่ใช้ Fraunces**)
อ้างอิง ของเดิม: `.wyn/docs/design/wyn-002-authentication-onboarding.md` (Screen 1-2), `app/lib/features/auth/presentation/welcome_screen.dart`, `auth_method_screen.dart`, `auth_gate.dart`, `app/lib/features/auth/data/auth_repository.dart`
อ้างอิง Founder request: ภาพหน้าจอ 2 รูป (Welcome + Auth Method) พร้อมวงมาร์กไว้ 3 จุด, ยืนยันเพิ่มเติมผ่าน popup 2 รอบวันนี้ (ขอบเขตงาน + guest depth)

## Audit ก่อนออกแบบ — สาเหตุที่ต้องแก้แต่ละจุด

1. **Wordmark "WYN" ควรเป็น "WYNOS"**: `welcome_screen.dart:37` ยังเป็น `Text('WYN', ...)` ตัวอักษรล้วน — ค้างมาจากตอนที่ยังไม่แตะ (บันทึกไว้ชัดเจนใน DECISIONS.md 2026-08-30 "ยังไม่ได้แตะ: wordmark ตัวอักษร WYN ในหน้า Onboarding ... ถ้าต้องการเปลี่ยนด้วยต้องสั่งแยก") ตอนนี้ Founder สั่งแยกแล้วผ่านภาพวงกลมแดง — เปลี่ยนข้อความให้ตรงกับ brand copy convention ที่ใช้ทั้งแอปอยู่แล้ว (wyn-024: "ทุกข้อความ UI ใหม่ใช้ WYNOS")
2. **ปุ่ม "เข้าสู่ระบบด้วย Apple" ควรพักไว้ก่อน**: สอดคล้องกับ known constraint ที่มีอยู่แล้ว (DECISIONS.md 2026-08-30, "Apple Developer Program — ยังไม่สมัคร งบไม่พอตอนนี้") — ปุ่มนี้ยังกดได้อยู่ในแอปจริงแต่เรียก `signInWithApple()` ที่ไม่มีทางสำเร็จจริง (ไม่มี Apple provider/JWT ที่ตั้งค่าไว้) เป็นปุ่มที่หลอกผู้ใช้ว่าใช้ได้ทั้งที่ใช้ไม่ได้ — Founder ยืนยันให้ซ่อนออกก่อน ไม่ใช่ลบทิ้งถาวร (ใช้ pattern เดียวกับที่ `_phoneLoginEnabled = false` ทำไว้กับปุ่มเบอร์โทรศัพท์อยู่แล้วในไฟล์เดียวกัน)
3. **เพิ่มทางเข้า "เข้าชม WYNOS ได้เลย ไม่ต้องล็อกอิน"**: ตรวจ RLS ใน `supabase/schema.sql` แล้วพบว่าตารางหลักทุกตัว (`drops` เป็นต้น) บังคับ role `authenticated` เท่านั้นถึงจะ SELECT ได้ — ไม่มีทาง "ไม่มี session เลย" อ่าน feed ได้จริงในสถาปัตยกรรมปัจจุบัน โดยไม่แก้ RLS (ซึ่งเป็น Security/Auth Architecture ต้องขออนุมัติแยก ไม่ใช่ขอบเขตงานนี้) วิธีเดียวที่ทำได้ทันทีคือใช้ **Anonymous Sign-In ที่มีอยู่แล้ว** (`AuthRepository.signInAnonymously()`, อนุมัติแล้วโดย Founder 2026-08-16 สำหรับทีมทดสอบภายใน แต่ยังไม่เคยต่อเข้า UI จริง) — session ที่ได้เป็น session จริงที่ `auth.uid()`/RLS ทำงานปกติทุกจุด ไม่ใช่ mock

## ทิศทางภาพรวม: ไม่มีการตัดสินใจ visual ใหม่ ใช้ token/component เดิมทั้งหมด

งานนี้ไม่แตะสี/ฟอนต์/spacing ใดๆ ใน `design-principles.md` เลย — เป็นการแก้ copy 1 คำ, ซ่อนปุ่ม 1 ปุ่ม, เพิ่มปุ่ม 1 ปุ่ม (component เดิม `OutlinedButton`/`TextButton`), และเพิ่ม gate 1 pattern ใหม่ (dialog ธรรมดา ไม่ใช่ screen ใหม่)

---

## Screen 1: Welcome (`welcome_screen.dart`)

Purpose: แก้ wordmark ให้ตรง brand copy convention ที่ใช้ทั้งแอปอยู่แล้ว

User Flow: ไม่เปลี่ยน — เปิดแอป → เห็น Welcome → กด "เริ่มต้นใช้งาน" → Auth Method Selection

Components: `Text('WYN', ...)` (บรรทัด 37) → เปลี่ยนเป็น `Text('WYNOS', ...)` เท่านั้น — ขนาด/น้ำหนัก/tracking/สี (`WynTypography.screenTitle(fontSize: 34, ...)`) คงเดิมทุกค่า ไม่ปรับ เพราะยังไม่มีเหตุผลใหม่ให้ปรับ scale ("WYNOS" ยาวกว่า "WYN" 3 ตัวอักษร แต่พื้นที่ `Row` เดิมเป็น `mainAxisSize: MainAxisSize.min` อยู่แล้ว ไม่ fixed width จึงไม่ overflow) badge "BETA" ข้างๆ คงเดิมทั้งหมด ไม่แตะ

Interactions: ไม่เปลี่ยน

States: ไม่เปลี่ยน (Default เท่านั้น)

Responsive Behavior: ไม่เปลี่ยน — ยืนยันด้วยตาว่า "WYNOS" + badge "BETA" ยังไม่ล้นความกว้างจอที่แคบที่สุดที่ทดสอบอยู่แล้ว (ถ้าล้นจริงบนจอที่แคบผิดปกติ ให้ `Flexible`/`FittedBox` ห่อ `Row` แทนการลด font size ของ wordmark เอง)

Accessibility: ไม่เปลี่ยน (เป็น decorative wordmark ไม่ใช่ interactive element)

Design Rules: ข้อความ "WYN" ที่เหลืออยู่ในโค้ด (table/class/variable ชื่อ `wyn`/`Wyn*`) **ไม่แตะ** — เปลี่ยนเฉพาะ UI copy ที่ผู้ใช้เห็นจริงตามมติ wyn-024 เดิม

Handoff: AI Coding — แก้บรรทัดเดียวใน `welcome_screen.dart`, อัปเดต test ที่ค้นหาข้อความ `'WYN'` แบบ exact-match ให้เป็น `'WYNOS'` (เช็ค `welcome_screen_test.dart`/`auth_gate_test.dart` ถ้ามี golden text นี้ค้างอยู่)

---

## Screen 2: Auth Method Selection (`auth_method_screen.dart`)

Purpose: ซ่อนปุ่ม Apple ที่ใช้งานไม่ได้จริงออกก่อน + เพิ่มทางเข้าชมแบบไม่ล็อกอิน

User Flow: จาก Welcome → เห็นปุ่ม **Google / อีเมล** (Apple หายไปชั่วคราว) + ปุ่มรอง "เข้าชม WYNOS ได้เลย" ด้านล่างสุด → กด Google/อีเมล ไป flow เดิม, กดปุ่ม "เข้าชม WYNOS ได้เลย" → เข้า Home ทันทีแบบ guest (ไม่ต้องกรอกอะไรเลย)

Components:
- ปุ่ม `FilledButton.icon` "เข้าสู่ระบบด้วย Google" — คงเดิม
- ปุ่ม `FilledButton.icon` "เข้าสู่ระบบด้วย Apple" — **ห่อด้วย `if (_appleLoginEnabled)` แล้วตั้ง `const _appleLoginEnabled = false`** (pattern เดียวกับ `_phoneLoginEnabled` ในไฟล์เดียวกันเป๊ะ ไม่ประดิษฐ์ pattern ใหม่) — comment อ้าง DECISIONS.md 2026-08-30 (Apple Developer Program ยังไม่สมัคร) เป็นเหตุผล ไม่ใช่ลบโค้ด `signInWithApple()` ทิ้งจาก `AuthRepository`
- ปุ่ม `OutlinedButton` "เข้าสู่ระบบด้วยอีเมล" — คงเดิม ตำแหน่งขยับขึ้นมาแทนที่ Apple
- **ใหม่**: `TextButton` "เข้าชม WYNOS ได้เลย" วางท้ายสุดของ Column (ใต้ปุ่มอีเมล, เว้นระยะเพิ่ม `WynSpacing.space6` ให้รู้สึกเป็นทางเลือกรอง ไม่ใช่ CTA หลักคู่กับ Google/อีเมล) — สไตล์ `TextButton` เปล่า (ไม่มีพื้นหลัง/กรอบ) สีข้อความ `WynColors.graphite` ไม่ใช่ primary/sapphire เพื่อสื่อว่าเป็นทางเลือกที่ "เบา" กว่าการสมัคร/ล็อกอินจริง — ไม่ใช้คำว่า "ข้าม" (skip) เพราะไม่ใช่การข้ามขั้นตอนใน flow เดียวกัน แต่เป็นเส้นทางคู่ขนานที่แยกออกไปเลย

Interactions:
- กด "เข้าชม WYNOS ได้เลย" → เรียก `authRepository.signInAnonymously()` ทันที (ผ่าน `_handle()` wrapper เดิมที่มีอยู่แล้ว เพื่อได้ loading/error state แบบเดียวกับปุ่มอื่นฟรีๆ) → สำเร็จแล้ว `AuthGate`'s auth-state listener จะ pop กลับไปที่ root เอง (mechanism เดิมที่มีอยู่แล้ว ไม่ต้อง navigate มือ)
- ปุ่ม Google/อีเมล/guest ถูก disable พร้อมกันระหว่าง `_isLoading` เหมือนเดิมทุกปุ่ม (prevent double-tap, pattern เดิม)

States: เพิ่ม case เดียวเข้า state เดิม — `_isLoading`/`_errorMessage` ที่มีอยู่แล้วครอบคลุมปุ่มใหม่นี้ได้เลยผ่าน `_handle()` wrapper เดิม ไม่ต้องเพิ่ม state ใหม่

Responsive Behavior: ไม่เปลี่ยน (`Column` เดิม เต็มความกว้างจอ)

Accessibility: `Semantics(label: 'เข้าชม WYNOS โดยไม่ต้องเข้าสู่ระบบ')` บนปุ่มใหม่ — ต้องสื่อชัดว่าไม่ใช่การล็อกอิน เพื่อไม่ให้ screen reader ผู้ใช้สับสนกับปุ่ม Google/อีเมลข้างบน

Design Rules: หัวข้อจอ "เข้าสู่ระบบ WYN" (บรรทัด 59) ก็เป็น "WYN" literal เหมือนกัน — **แก้เป็น "เข้าสู่ระบบ WYNOS" พร้อมกันในงานนี้** (จุดเดียวกับ Welcome, gap เดิมที่ยังไม่เคยสั่งแก้)

Handoff: AI Coding — แก้ `auth_method_screen.dart` 3 จุดตามข้างบน (ซ่อน Apple + เพิ่มปุ่ม guest + แก้ headline "WYN"→"WYNOS") ต่อกับ `AuthRepository.signInAnonymously()` ที่มีอยู่แล้ว ไม่ต้องแก้ `auth_repository.dart` เลย

---

## Screen 3 (concept ใหม่): Guest Mode — เข้า Home ได้ทันที, gate หน้า/action ที่ต้องมีตัวตนจริง

Purpose: ตอบคำตอบของ Founder ตรงๆ — "อยากให้มีปุ่มกดเยี่ยมชมได้เลย ดูโพสต์ได้ แต่หน้าสำคัญเช่นโปรไฟล์ ควรล็อกอิน" คือ guest ต้องเห็น Home ทันทีไม่ต้องผ่าน Username Setup แต่หน้า/action ที่ผูกกับตัวตน (ไม่ใช่แค่โปรไฟล์อย่างเดียว) ต้องกันไว้

User Flow:
```
Auth Method → กด "เข้าชม WYNOS ได้เลย" → signInAnonymously() สำเร็จ
  → AuthGate เจอ session ที่ is_anonymous == true และไม่มี username
    → ข้าม Username Setup ไปเลย (guest ไม่ต้องตั้งชื่อ) → RootShell (Home)
  → guest เลื่อนดู Home/Search/Club/Drop detail ได้ตามปกติ (read เท่านั้นที่ RLS อนุญาตอยู่แล้ว)
  → guest แตะจุดที่ gate ไว้ (ดูรายการด้านล่าง) → เห็น "ต้องเข้าสู่ระบบก่อน" dialog
    → กด "สมัคร/เข้าสู่ระบบ" → signOut() ออกจาก anonymous session ก่อน → เปิด AuthMethodScreen จริง
    → กด "ไว้ทีหลัง" → ปิด dialog กลับไปเดิม ไม่มีอะไรเกิดขึ้น
```

Components:
- **`AuthGate` เพิ่มเงื่อนไขใหม่ 1 จุด**: ก่อนเช็ค `hasUsername` (บรรทัด 291-313 เดิม) เพิ่มเช็ค `session.user.isAnonymous == true` → ถ้าใช่ ข้ามตรงไป `RootShell` เลย ไม่เรียก `hasUsername`/`UsernameSetupScreen` เลย (guest ไม่มี username แถวใน `profiles` เลยด้วยซ้ำ — ไม่ใช่แค่ null)
- **`GuestGate` widget/helper ใหม่** (ชื่อเรียกให้ AI Coding ตัดสินใจเอง, แนวคิดคือฟังก์ชันเดียวที่ทุกจุด gate เรียกใช้ซ้ำ): เช็ค `Supabase.instance.client.auth.currentUser?.isAnonymous == true` → ถ้าใช่ แสดง dialog ต่อไปนี้แทนการทำงานปกติ, ถ้าไม่ใช่ (ล็อกอินจริงแล้ว) ทำงานปกติทุกอย่างเหมือนเดิมไม่มีอะไรเปลี่ยน
- **Dialog "ต้องเข้าสู่ระบบก่อน"**: `AlertDialog` มาตรฐาน (ไม่ใช่ full-screen ใหม่ ไม่ใช่ bottom sheet — เพราะเป็นการขัดจังหวะสั้นๆ ให้ตัดสินใจ ไม่ใช่ flow ที่ต้องมีพื้นที่เยอะ) หัวข้อ "เข้าสู่ระบบเพื่อดำเนินการต่อ" เนื้อหา 1 บรรทัด อธิบายสั้นๆ ว่าฟีเจอร์นี้ต้องมีบัญชีจริง ปุ่ม primary "สมัคร/เข้าสู่ระบบ" (สี sapphire ตามปุ่ม primary ทั่วแอป) + ปุ่ม text "ไว้ทีหลัง"

Interactions: ดู User Flow ข้างบน — จุดสำคัญคือกด "สมัคร/เข้าสู่ระบบ" จาก dialog ต้อง `signOut()` anonymous session ทิ้งก่อนเปิด `AuthMethodScreen` เสมอ (ไม่ปล่อยให้มี 2 session ซ้อนกัน หรือ Google OAuth ไปพยายาม link เข้า anonymous user เดิมโดยไม่ได้ตั้งใจ) — **ไม่ทำ identity-linking upgrade** (`linkIdentity`) ในงานนี้ เพราะยังไม่มี use case จริงที่ guest สร้างข้อมูลอะไรไว้ก่อน (ทุกจุดที่ gate ไว้คือ action ที่ยังไม่เกิดขึ้นเลยจนกว่าจะล็อกอินจริง) — ถ้าอนาคตมี use case ที่ guest ทำอะไรไว้ก่อนแล้วอยาก "อัปเกรด" โดยไม่เสียของ ต้องแยกงานใหม่เพื่อเชื่อม `linkIdentity` เข้า UI (มีอยู่แล้วใน `AuthRepository` แค่ยังไม่ต่อ ตาม comment เดิมในไฟล์)

States: Dialog มี default state เดียว ไม่มี loading (แค่ navigate/signOut ธรรมดา ไม่เรียก API ที่ใช้เวลานาน)

Responsive Behavior: `AlertDialog` มาตรฐาน Material ปรับความกว้างตามจอเองอยู่แล้ว

Accessibility: Dialog ต้อง trap focus ตาม `AlertDialog` default ของ Flutter (มีอยู่แล้วในตัว), ปุ่ม primary มี label เต็ม ไม่ใช่แค่ไอคอน

Design Rules — **ขอบเขตจุดที่ gate ไว้ในรอบนี้** (Founder พูด "เช่นโปรไฟล์" เป็นตัวอย่าง ไม่ใช่รายการปิด — งานนี้ตีความเป็นชุดที่ตรรกะเดียวกัน "action/หน้าที่ผูกกับตัวตนของผู้ใช้เอง" ทั้งหมด ไม่ใช่ profile อย่างเดียว):
1. **Bottom Nav → แท็บ "โปรไฟล์"** (ตัวอย่างที่ Founder ระบุตรงๆ)
2. **Bottom Nav → ปุ่ม "+" (สร้าง Drop)** — โพสต์ต้องมีตัวตนจริงเสมอ
3. **Bottom Nav → แท็บ "การแจ้งเตือน"** — เป็นข้อมูลส่วนตัวของบัญชี ไม่มีความหมายสำหรับ guest ที่ไม่มีตัวตนถาวร
4. **Home header → ปุ่มแชท** — Chat ผูกกับตัวตนผู้สนทนาโดยตรง
5. **Action ทุกตัวที่เขียนข้อมูลผูกกับผู้ใช้บนโพสต์** (Like/Comment/Save/ReDrop/Quote ReDrop/Poll vote/Report/Hide) ไม่ว่าจะอยู่ใน Home feed, Search, Club, Drop/Pop detail จุดไหนก็ตาม — ใช้ `GuestGate` เดียวกันครอบทุกจุด (reuse ไม่ประดิษฐ์ซ้ำ)
6. **ปุ่ม "ติดตาม" (Follow)** ทุกจุดที่มี (Profile คนอื่น, Suggested Follow List, Club member list ฯลฯ)
7. **Club: สร้าง Club / เข้าร่วม Club**

**สิ่งที่ guest ทำได้โดยไม่ต้องเจอ dialog** (read-only): เลื่อนดู Home feed ทุกโหมด (สำหรับคุณ/ติดตาม — แม้ "ติดตาม" จะว่างเปล่าเสมอสำหรับ guest ก็ยังเปิดดูได้ ไม่ error), เปิดดู Drop/Pop detail แบบเต็ม (รวมอ่านคอมเมนต์คนอื่น แค่พิมพ์เองไม่ได้), ใช้แท็บ "ค้นหา"/Discovery, เปิดดูหน้า Club (ไม่ join), เปิดดูโปรไฟล์คนอื่น (ไม่ follow) — ตรงกับคำว่า "ดูโพสต์ได้" ที่ Founder ระบุ

Handoff: AI Coding — 3 ส่วนที่ต้องแก้:
1. `auth_gate.dart`: เพิ่มเงื่อนไข `session.user.isAnonymous` ข้าม Username Setup (ตำแหน่งแทรกก่อน `FutureBuilder<bool>(future: _authRepository.hasUsername(...))` บรรทัด ~291)
2. Widget/helper ใหม่ (ชื่อให้ Coding เลือก เช่น `requireRealAccount(context)` คืน `Future<bool>` — `true` = ทำต่อได้, `false` = ถูก gate ไว้) ใช้ตรวจ `isAnonymous` + โชว์ dialog ตามสเปคข้างบน แล้วครอบทุกจุดในรายการ Design Rules 7 ข้อ — **ห้ามเขียน dialog ซ้ำมือทีละจุด** ต้อง reuse widget/helper เดียว
3. ปุ่ม "สมัคร/เข้าสู่ระบบ" ใน dialog: `await authRepository.signOut()` แล้ว push `AuthMethodScreen` ใหม่ (ไม่ผ่าน `AuthGate` เพราะตอนนี้ปิด dialog นี้อยู่คนละ route context กับตอน AuthGate ครั้งแรก — เช็ค navigator context ให้ถูกก่อน implement จริง)

ต้อง QA & Security ตรวจสอบก่อน deploy เสมอ — เน้นตรวจ: (a) guest เข้า Home ได้จริงไม่ผ่าน Username Setup, (b) ทั้ง 7 จุดใน Design Rules ถูก gate จริงไม่มีจุดหลุด, (c) กด "สมัคร/เข้าสู่ระบบ" จาก dialog แล้ว anonymous session ถูก signOut จริงก่อนเปิดหน้าล็อกอิน ไม่ค้าง session ซ้อน, (d) ปุ่ม Apple ที่ซ่อนไว้ต้องไม่ปรากฏใน UI แต่ `signInWithApple()` ใน `AuthRepository` ต้องยังอยู่ในโค้ด (พร้อมเปิดกลับทันทีที่ Apple Developer Program พร้อม)

---

## Handoff รวม

ส่งต่อ AI Coding (`/code`) implement 3 ส่วนข้างต้น (Welcome wordmark, Auth Method screen 3 จุด, Guest Mode flow + 7-point gate) — งานนี้ทั้งหมดไม่แตะ token สี/ฟอนต์/spacing ใดๆ ตาม design-principles.md เดิม ไม่ต้องขออนุมัติ Founder เพิ่มสำหรับตัว UI (Design/Code ปกติ) แต่ **ควรแจ้ง Founder เมื่อ implement เสร็จให้ยืนยันรายการ gate 7 ข้อตรงกับที่ต้องการจริงก่อน deploy** เพราะ Founder ระบุแค่ "เช่นโปรไฟล์" เป็นตัวอย่างเดียว รายการที่เหลือ (Drop/Notifications/Chat/Like-Comment-Save-ReDrop-Poll/Follow/Club) เป็นการตีความของ AI Design ต่อยอดจากหลักการเดียวกัน ไม่ใช่คำสั่งตรงจาก Founder ทีละจุด
