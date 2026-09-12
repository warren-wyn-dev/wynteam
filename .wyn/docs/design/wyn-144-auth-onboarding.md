# WYN "Flare" — Auth / Onboarding (V1.0 — PROPOSED)

Status: PROPOSED
Owner: AI Design
อ้างอิง: wyn-142-visual-identity-redesign.md, wyn-143-core-component-library.md

เอกสารนี้เป็นสเปก UX/UI ของกลุ่มหน้าจอ Auth/Onboarding ทั้ง 7 หน้าจอ ภายใต้ visual identity ใหม่ "Flare" ตามคำสั่ง Founder (2026-09-12) ให้ redesign หน้าตาทั้งระบบ — **เป็นการ restyle หน้าจอที่มีอยู่แล้วเท่านั้น ไม่เปลี่ยน business logic/flow ที่อนุมัติไว้เดิม** (WYN-002, WYN-072, WYN-077, WYN-113, WYN-029/030, WYN-046) อ่านโค้ดจริงของทั้ง 7 หน้าจอก่อนเขียนสเปกนี้ (`app/lib/features/auth/presentation/`) ทุก field อ้างอิงเฉพาะ token จาก wyn-142 และคอมโพเนนต์จาก wyn-143 เท่านั้น

เอกสารนี้แทนที่ visual treatment เดิมของ `wyn-002-authentication-onboarding.md` (สี/ฟอนต์ตาม `design-principles.md` เดิม) — Purpose/User Flow/States ที่เขียนในเอกสารนี้ตรงกับ implementation จริงในโค้ด ณ วันที่เขียน (รวมฟีเจอร์ที่เพิ่มมาทีหลัง WYN-002 เช่น Email Auth, Invite Gate, Account Restricted ซึ่งเอกสาร wyn-002 เดิมไม่ครอบคลุม)

## ภาพรวม Flow รวม

```
Welcome
  └─ กด "เริ่มต้นใช้งาน" → Auth Method Selection
                              ├─ [Invite Gate เปิดอยู่ และยังไม่เคยยืนยันโค้ด] → Redeem Invite Code
                              │     └─ โค้ดถูกต้อง → pop กลับ Auth Method Selection (เผยปุ่ม sign-in จริง)
                              ├─ Google (เปิดใช้งานเสมอ) → สำเร็จ → AuthGate ตัดสินหน้าถัดไป
                              ├─ Apple (ปิดใช้งานชั่วคราวด้วย flag) → เหมือน Google เมื่อเปิดใช้งาน
                              ├─ อีเมล → Email Auth (สมัคร/เข้าสู่ระบบ) → สำเร็จ → AuthGate ตัดสินหน้าถัดไป
                              ├─ เบอร์โทรศัพท์ (ปิดใช้งานชั่วคราวด้วย flag) → Phone Entry → OTP Verification
                              │     └─ ยืนยันสำเร็จ → AuthGate ตัดสินหน้าถัดไป
                              └─ เข้าชมแบบ Guest (ปิดใช้งานชั่วคราวด้วย flag, ไม่มีเมื่อ isAddingAccount=true)
                                    → sign in anonymous → AuthGate ตัดสินหน้าถัดไป

AuthGate (ทุกครั้งที่มี session ที่ valid) ตรวจตามลำดับ:
  1. Suspended/Banned → Account Restricted (บล็อกจนกว่าจะ "ตกลง" ออกจากระบบ)
  2. ยังไม่ยอมรับเอกสารแพลตฟอร์มฉบับล่าสุด → Document Acceptance (นอก scope เอกสารนี้)
  3. Onboarding ยังไม่ครบ → OnboardingFlow (นอก scope เอกสารนี้)
  4. ครบทุกเงื่อนไข → RootShell (Home)
```

หมายเหตุ flag ปัจจุบันในโค้ด (`auth_method_screen.dart`): `_appleLoginEnabled = false`, `_phoneLoginEnabled = false`, `_guestBrowsingEnabled = false` — ทั้งสามเป็น feature ที่ Founder อนุมัติแนวคิดไว้แล้วแต่ปิดชั่วคราวด้วยเหตุผลทางเทคนิค/ต้นทุน (ไม่ใช่ WYN-125 developer-gate) สเปกนี้ยังคงออกแบบหน้าตาของทั้งสาม flag ไว้ครบเผื่อวันที่เปิดใช้งาน แต่ current state ที่ผู้ใช้ทั่วไปเห็นจริงคือ "ไม่มีปุ่มเหล่านี้เลย" ตรงตามหลัก staged-feature ที่มีอยู่แล้ว

---

## Screen: Welcome

Purpose: หน้าแรกที่ผู้ใช้เห็นเมื่อเปิดแอปครั้งแรกและยังไม่มี session (AuthGate ตัดสินว่า signed-out) แสดง wordmark, badge สถานะ BETA, tagline สั้น และปุ่มเดียวเพื่อพาไปเลือกวิธีเข้าสู่ระบบ — ไม่มี form/ไม่มีการเรียก API ในหน้านี้

User Flow: เปิดแอป (ไม่มี session) → AuthGate render WelcomeScreen → กด "เริ่มต้นใช้งาน" → push ไป Auth Method Selection (ส่ง `authRepository` เดียวกันต่อ)

Components:
- Wordmark "WYNOS" — ใช้ `type.display.xl` (Space Grotesk Bold) แต่คงลักษณะพิเศษของโค้ดเดิมไว้ (ขนาด 34, letter-spacing ~3%) เพราะเป็นจุดเดียวในทั้งแอปที่ wordmark มีน้ำหนัก/ระยะห่างเฉพาะของตัวเอง สูงกว่าทุก type token ปกติ
- Badge "BETA" — ใช้ Chip (pill, `radius.pill`) พื้นหลัง `color.surface`, ตัวหนังสือ `type.caption` สี `color.ink.muted`, ไม่ใช้ `color.accent` เป็นพื้น (ไม่ใช่ CTA ไม่ใช่สถานะ error/success)
- Text tagline — `type.body.l` สี `color.ink.muted`, กึ่งกลาง
- Primary Button "เริ่มต้นใช้งาน" — full-width

Interactions: กดปุ่มเดียวเพื่อไปต่อ ไม่มี double-tap protection ที่จำเป็นเพราะเป็นแค่ navigation push (ไม่เรียก API)

States: Default เท่านั้น (ไม่มี Loading/Error เพราะไม่มีการเรียก network ในหน้านี้)

Responsive Behavior: จัดกึ่งกลางแนวตั้งด้วย flexible spacer (เนื้อหาส่วนบน 3 ส่วน, ช่องว่างก่อนปุ่ม 4 ส่วน), ปุ่ม primary anchor ใกล้ขอบล่างจอเสมอ (เว้น safe-area) รองรับทั้งจอเตี้ย/จอสูง โดยไม่ทำให้ wordmark ชิดขอบบนเกินไปบนจอเตี้ย

Accessibility: Wordmark และปุ่มต้องมี label ชัดเจนสำหรับ screen reader, contrast ของ tagline บน `color.paper` ต้องผ่าน AA, badge "BETA" ต้องมี semantic label ที่บอกความหมาย ("สถานะทดสอบเบต้า") ไม่ใช่สื่อด้วยสีเพียงอย่างเดียว

Design Rules: พื้นหลังทั้งหน้าใช้ `color.paper` เท่านั้น (ห้ามใช้ `color.accent` เป็นพื้นเต็มจอ) ปุ่มหลักใช้ `color.accent` เป็นจุดสีเดียวที่โดดเด่นที่สุดในหน้านี้ตามหลัก single-accent + white space 80–90%

Handoff: AI Coding — คง widget เป็น stateless เหมือนเดิม ไม่ต้องเชื่อม Supabase เพิ่ม เปลี่ยนเฉพาะ theme token (สี/ฟอนต์/spacing) ตาม wyn-142/wyn-143 — รอ Founder ยืนยันสเปกนี้ก่อนเริ่ม implement ตามกติกา "ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด"

---

## Screen: Auth Method Selection

Purpose: จุดกลางให้ผู้ใช้เลือกวิธีเข้าสู่ระบบ/สมัครสมาชิก ครอบคลุมทั้งกรณีผู้ใช้ใหม่ (`isAddingAccount = false`, จาก Welcome) และกรณีผู้ใช้ที่ล็อกอินอยู่แล้วต้องการเพิ่มบัญชีที่สอง (`isAddingAccount = true`, จาก Account Switcher) พร้อมรองรับ Invite-Only Access Gate (WYN-113) ที่ Founder เปิด/ปิดได้จากฝั่งระบบ

User Flow:
1. เข้าหน้านี้ครั้งแรก (เฉพาะกรณี `isAddingAccount = false`) → เช็ค invite gate แบบ async ก่อนเสมอ (แสดง Spinner ระหว่างเช็ค)
2. ถ้า invite gate เปิดอยู่และยังไม่เคยยืนยันโค้ดใน session นี้ → แสดงข้อความอธิบาย + ปุ่ม "กรอกโค้ดเชิญ" แทนปุ่ม sign-in จริงทั้งหมด → กดแล้ว push ไป Redeem Invite Code → กลับมาพร้อมผล `true` → เผยปุ่ม sign-in จริงทันที (ไม่ reload หน้า)
3. เมื่อเห็นปุ่ม sign-in จริง (gate ปิด หรือยืนยันโค้ดแล้ว หรือ `isAddingAccount = true`) เลือกได้: Google (เรียก `signInWithGoogle` ทันที) / Apple (ถ้า flag เปิด) / "เข้าสู่ระบบด้วยอีเมล" (push ไป Email Auth) / "ใช้เบอร์โทรศัพท์แทน" (ถ้า flag เปิด, push ไป Phone Entry) / "เข้าชม WYNOS ได้เลย" (ถ้า flag เปิดและไม่ใช่ `isAddingAccount`, sign in anonymous ทันที)
4. เมื่อกด Google/Apple/Guest ที่เรียก API ตรงในหน้านี้ → เข้าสถานะ Loading (ปุ่มทั้งหมด disable) → สำเร็จ AuthGate จัดการ navigate ต่อเอง (ไม่ navigate เองในหน้านี้) / ล้มเหลว → แสดง inline error ใต้กลุ่มปุ่ม

Components:
- Top App Bar — เปล่า (มีแค่ปุ่ม back อัตโนมัติจาก `Navigator`), ไม่มี title ใน bar เอง
- Text heading "เข้าสู่ระบบ WYNOS" / "เพิ่มบัญชี WYNOS" — `type.display.l` ชิดซ้ายตามสเปก Top App Bar/heading ของ Flare (ไม่ centered)
- Spinner — ระหว่างเช็ค invite gate (full-width, centered) และระหว่าง `_isLoading`
- Primary Button — "กรอกโค้ดเชิญ" (เมื่อถูก gate บล็อก) และ Google sign-in (เป็นปุ่มเด่นที่สุดในกลุ่ม sign-in จริง)
- Social Login Button — Apple sign-in ใช้ asset/สเปกทางการของ Apple ตามข้อ 13 ของ wyn-143 (ไม่ปรับสีตาม `color.accent`)
- Secondary Button — "เข้าสู่ระบบด้วยอีเมล"
- Secondary Button — "ใช้เบอร์โทรศัพท์แทน" (เมื่อ flag เปิด)
- Text Button — "เข้าชม WYNOS ได้เลย" (น้ำหนักเบาที่สุดในกลุ่ม ตัวหนังสือ `color.ink.muted` ไม่ใช่ `color.accent` เพราะเป็นทางเลือกรอง ไม่ใช่ CTA เทียบเท่า Google/อีเมล)
- Inline error message — ใต้กลุ่มปุ่มทั้งหมด เมื่อ `_errorMessage != null`
- Text (ข้อความอธิบาย invite gate) — `type.body.m` สี `color.ink.muted`

Interactions: ทุกปุ่มถูก disable พร้อมกันระหว่าง `_isLoading = true` (ป้องกัน double-tap/เรียกซ้อน) ปุ่ม "กรอกโค้ดเชิญ" ไม่ถูก disable ด้วย `_isLoading` (เป็นคนละ flow กัน) การกลับจาก Redeem Invite Code ด้วยผล `true` ต้องเปลี่ยนเนื้อหาหน้าแบบ in-place (ไม่มี page transition ใหม่) ด้วย `motion.base`

States:
- Checking invite gate (spinner เต็มความกว้าง, เฉพาะตอน mount ครั้งแรกและไม่ใช่ `isAddingAccount`)
- Invite gate blocking (ข้อความ + ปุ่ม "กรอกโค้ดเชิญ" แทนปุ่ม sign-in จริงทั้งหมด)
- Normal (ปุ่ม sign-in จริงทั้งหมดตาม flag ที่เปิดอยู่)
- Loading (ปุ่มทั้งหมด disabled + spinner ใต้กลุ่มปุ่ม)
- Error (inline error message สีตาม token error ใต้กลุ่มปุ่ม, ข้อความ "เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง" เป็น generic message เดียวสำหรับทุก error ของ flow นี้)

Responsive Behavior: ปุ่มเรียงแนวตั้งเต็มความกว้าง (minus margin แนวนอน) เว้นระยะระหว่างปุ่มด้วย spacing 12px ใช้ได้ทั้งจอแคบ/กว้าง ไม่ overflow เมื่อ error message ยาว (wrap ได้)

Accessibility: ปุ่ม sign-in ทุกปุ่มต้องมี label เต็ม ("เข้าสู่ระบบด้วย Google") ไม่ใช่แค่ icon สำหรับ screen reader (คงพฤติกรรมเดิมที่ถูกต้องอยู่แล้ว) ปุ่ม guest ต้องมี Semantics label ชัดเจนแยกจาก label ที่แสดงบนจอ (คงพฤติกรรมเดิม) สถานะ loading ต้องประกาศผ่าน live region ให้ screen reader ทราบว่ากำลังดำเนินการอยู่

Design Rules: กลุ่มปุ่ม sign-in เรียงตามลำดับความสำคัญจากเด่นสุดไปเบาสุด (Google → Apple → อีเมล → เบอร์โทร → guest) ตรงตามที่โค้ดปัจจุบันจัดไว้ ห้ามให้ guest button มีน้ำหนักภาพเทียบเท่า Primary/Secondary Button — **ช่องว่าง implementation ที่ต้องแก้ตอน coding**: ปุ่ม Google ปัจจุบันใช้ `Icons.g_mobiledata` (Material icon ทั่วไป) ภายใน `FilledButton.icon` ซึ่งไม่ตรงตาม wyn-143 ข้อ 13 ที่บังคับใช้ asset/สเปกทางการของ Google — ต้องเปลี่ยนเป็น Google "G" logo asset จริงตอน implement

Handoff: AI Coding — logic Supabase Auth (Google/Apple/Email push/Phone push/Anonymous), invite-gate check และ error handling ทั้งหมดคงเดิมทุกประการ งานนี้คือ visual restyle ตาม token ใหม่ + แก้ asset ปุ่ม Google ให้ตรง brand guideline เท่านั้น ห้ามเปลี่ยนเงื่อนไข flag `_appleLoginEnabled`/`_phoneLoginEnabled`/`_guestBrowsingEnabled` เอง (เป็นการตัดสินใจ product/Founder แยกต่างหาก)

---

## Screen: Phone Entry

Purpose: ให้ผู้ใช้กรอกเบอร์โทรศัพท์ไทยเพื่อขอรับรหัส OTP ผ่าน SMS (ปัจจุบันเข้าถึงไม่ได้จริงในโปรดักชันเพราะ `_phoneLoginEnabled = false` ที่ Auth Method Selection — สเปกนี้ยังคงออกแบบไว้ให้ครบเผื่อวันที่ Twilio พร้อม)

User Flow: จาก Auth Method Selection (เมื่อ flag เปิด, กด "ใช้เบอร์โทรศัพท์แทน") → กรอกเบอร์ (auto-normalize เป็นรูปแบบ `+66XXXXXXXXX`) → ปุ่ม "ส่งรหัส OTP" เปิดใช้งานเมื่อรูปแบบถูกต้อง (9 หลักหลัง `+66`) → กดปุ่ม → เรียก `sendPhoneOtp` → สำเร็จ push ไป OTP Verification (ส่งเบอร์ที่ normalize แล้วต่อ) → ล้มเหลว (เช่น rate limit) แสดง error ในหน้าเดิม ไม่ navigate

Components:
- Top App Bar — title "หมายเลขโทรศัพท์"
- Text Input — prefix คงที่ "+66 ", label "หมายเลขโทรศัพท์", keyboard ตัวเลข, error text แสดงในตำแหน่งเดียวกับ error ของ input (ใช้ error slot เดียวทั้ง format-invalid และ API error)
- Primary Button — "ส่งรหัส OTP" (แสดง Spinner แทนข้อความระหว่าง loading)

Interactions: real-time re-check ความถูกต้องของเบอร์ทุกครั้งที่พิมพ์ (`onChanged` trigger rebuild) ปุ่มเปิด/ปิดทันทีตามผล ไม่มี debounce เพราะเป็นแค่ regex ในเครื่อง ไม่เรียก network

States:
- Default
- Invalid format (ปุ่มถูก disable เงียบ ๆ) — **ช่องว่าง implementation**: โค้ดปัจจุบันไม่แสดงข้อความ error ใต้ input ตอนรูปแบบผิด (มีแค่ปุ่ม disabled) ต่างจากที่ wyn-002 เดิมตั้งใจไว้ว่าต้องมี inline error ทันที ควรเพิ่ม helper text (ไม่ใช่ error สี แดง เพราะยังไม่ได้ "พยายามส่ง") บอกรูปแบบที่ถูกต้อง เช่น "กรอกเบอร์ 9 หลัก" ด้วย `color.ink.muted` เพื่อลดความสับสนว่าทำไมปุ่มกดไม่ได้
- Loading (spinner แทนข้อความในปุ่ม, input ยังแก้ไขได้แต่ปุ่มถูก disable)
- Error (API ล้มเหลว) — error text ใต้ input สี `color.error`

Responsive Behavior: Input เต็มความกว้าง คีย์บอร์ดตัวเลขเด้งอัตโนมัติ ปุ่ม primary ไม่ถูกคีย์บอร์ดบัง (Scaffold เลื่อน content ขึ้นตาม inset ปกติ)

Accessibility: label "หมายเลขโทรศัพท์" ผูกกับ input ผ่าน `InputDecoration.labelText` เสมอ ไม่ใช่แค่ placeholder (คงพฤติกรรมเดิมที่ถูกต้องอยู่แล้ว) prefix "+66" ต้องถูกอ่านโดย screen reader ว่าเป็นส่วนหนึ่งของ label ไม่ใช่แค่ตัวอักษรลอย

Design Rules: ใช้ Text Input (`radius.m`, `color.surface`, focus border `color.accent`, error border `color.error` + ไอคอนเตือนตามกติกา wyn-143 ข้อ 2) — **ช่องว่าง implementation**: `InputDecoration.labelText` มาตรฐานของ Material ลอย label ขึ้นเมื่อ focus/มีค่า (floating label) ซึ่งขัดกับ wyn-143 ที่กำหนดให้ Text Input ของ Flare ใช้ label คงที่ด้านบนเสมอเพื่อความเรียบง่ายและลด motion — ต้อง implement เป็น custom Text Input component แทน default Material behavior

Handoff: AI Coding — logic `sendPhoneOtp`/`_normalizedPhone`/regex คงเดิมทุกประการ เพิ่มเฉพาะ helper text ตอนรูปแบบผิด + แก้ label ให้เป็นแบบคงที่ด้านบนตาม Text Input component ใหม่ ยังคงอยู่หลัง flag `_phoneLoginEnabled` เหมือนเดิม ไม่เปิดเอง

---

## Screen: Email Auth

Purpose: สมัครสมาชิก/เข้าสู่ระบบด้วยอีเมล+รหัสผ่าน ไม่ผูกกับบัญชี Google/Apple เดียว รองรับหลายบัญชีต่อผู้ใช้หนึ่งคน (Founder, 2026-08-24) เริ่มต้นในโหมด "สมัครสมาชิก" เสมอเมื่อเข้าหน้านี้ครั้งแรก

User Flow: จาก Auth Method Selection (กด "เข้าสู่ระบบด้วยอีเมล") → กรอกอีเมล + รหัสผ่าน (validate real-time: รูปแบบอีเมล, รหัสผ่าน ≥6 ตัวอักษร) → กดปุ่ม primary (label ตามโหมด) หรือกด Enter ที่ช่องรหัสผ่าน → เรียก API ตามโหมด:
- โหมดสมัครสมาชิก สำเร็จและมี session ทันที (ไม่ต้องยืนยันอีเมล) → AuthGate navigate ต่อเอง
- โหมดสมัครสมาชิก สำเร็จแต่ต้องยืนยันอีเมลก่อน (session เป็น null) → แสดงข้อความแจ้งให้ไปกดลิงก์ในอีเมล + สลับหน้าเป็นโหมด "เข้าสู่ระบบ" อัตโนมัติ (ผู้ใช้ยังอยู่หน้าเดิม)
- อีเมลนี้มีบัญชีอยู่แล้ว (สมัครซ้ำ) → error "อีเมลนี้มีบัญชีอยู่แล้ว ลองเข้าสู่ระบบแทน" + สลับเป็นโหมดเข้าสู่ระบบอัตโนมัติ
- โหมดเข้าสู่ระบบ สำเร็จ → AuthGate navigate ต่อเอง
- โหมดเข้าสู่ระบบ บัญชียังไม่ยืนยันอีเมล → error บอกให้ไปกดลิงก์ยืนยันก่อน
- โหมดเข้าสู่ระบบ ผิดพลาดอื่น → error "อีเมลหรือรหัสผ่านไม่ถูกต้อง"
- ผู้ใช้กดข้อความ toggle ด้านล่างเพื่อสลับโหมดเองได้ทุกเมื่อ (ล้าง error เดิม)

Components:
- Top App Bar — title "สมัครสมาชิก" / "เข้าสู่ระบบ" ตามโหมด
- Text Input — อีเมล (keyboard email, ไม่ autocorrect)
- Text Input — รหัสผ่าน (obscured, helper text "อย่างน้อย 6 ตัวอักษร")
- Primary Button — label ตามโหมด, แสดง Spinner ระหว่างโหลด
- Text Button — toggle โหมด ("มีบัญชีอยู่แล้ว? เข้าสู่ระบบ" / "ยังไม่มีบัญชี? สมัครสมาชิก")
- Inline error/success message — ใต้ปุ่ม toggle

Interactions: ปุ่ม primary enable เมื่ออีเมล valid + รหัสผ่าน ≥6 ตัวอักษร + ไม่ loading เท่านั้น กด Enter ที่ช่องรหัสผ่านเทียบเท่ากดปุ่ม primary (ถ้า valid) toggle โหมดล้าง error ทันที

States:
- Sign-up mode (default เมื่อเข้าหน้าครั้งแรก)
- Sign-in mode (หลัง toggle หรือถูกสลับอัตโนมัติจาก error บางประเภท)
- Loading
- Error — 3 ข้อความต่างกันตามสาเหตุ (บัญชีซ้ำ / ยังไม่ยืนยันอีเมล / ข้อมูลผิด)
- Awaiting email confirmation — ข้อความแจ้งให้ไปกดลิงก์ยืนยัน

Responsive Behavior: layout เดียวกับ Text Input pattern มาตรฐาน คีย์บอร์ดไม่บังปุ่ม primary ปุ่ม toggle และ error message รองรับข้อความยาวได้โดย wrap ไม่ overflow

Accessibility: label "อีเมล"/"รหัสผ่าน" ผูกกับ input เสมอ ควรเพิ่มปุ่ม toggle แสดง/ซ่อนรหัสผ่าน (ไอคอนตา) เพื่อ accessibility ของผู้ใช้ที่พิมพ์ผิดง่าย (ปัจจุบันไม่มี — เพิ่มเป็นส่วนหนึ่งของ Text Input component สำหรับ field ที่ `obscureText`) ข้อความ error/แจ้งเตือนต้องประกาศผ่าน live region เมื่อเปลี่ยนแปลง

Design Rules: ใช้ Text Input, Primary Button, Text Button ตาม wyn-143 — **ช่องว่าง implementation**: ข้อความ "ส่งอีเมลยืนยันไปที่ ... แล้ว กรุณากดลิงก์ในอีเมลก่อนเข้าสู่ระบบ" เป็นข้อมูล/สถานะสำเร็จบางส่วน (ไม่ใช่ความผิดพลาดของผู้ใช้) แต่โค้ดปัจจุบัน render ด้วย `color.error` เดียวกับ error จริงทั้งหมด (ใช้ตัวแปร `_errorMessage` ตัวเดียว) — ต้องแยก render ข้อความนี้ด้วยสี `color.success` หรือ `color.ink` (ไม่ใช้ `color.error`) พร้อมไอคอนกำกับ (เช่น mail/check) เพื่อไม่ให้ผู้ใช้เข้าใจผิดว่าเกิดข้อผิดพลาด

Handoff: AI Coding — logic `signUpWithEmail`/`signInWithEmail`/exception handling ทั้งหมดคงเดิม ต้องแก้เฉพาะ (1) แยก semantic สีของข้อความ "รอยืนยันอีเมล" ออกจาก error จริง (2) เพิ่มปุ่มแสดง/ซ่อนรหัสผ่าน ที่เหลือเป็น visual restyle ตาม token ใหม่

---

## Screen: OTP Verification

Purpose: ให้ผู้ใช้กรอกรหัส OTP 6 หลักที่ได้รับทาง SMS ไปยังเบอร์ที่กรอกไว้ในหน้าก่อนหน้า พร้อมกลไก resend แบบมี cooldown 30 วินาที (เข้าถึงได้เฉพาะเมื่อ Phone Entry เปิดใช้งานอยู่)

User Flow: จาก Phone Entry → เห็นข้อความ "กรอกรหัส 6 หลักที่ส่งไปยัง <เบอร์>" → กรอกทีละหลัก (auto-focus ช่องถัดไป) → ครบ 6 หลัก auto-submit ทันที (ไม่ต้องกดปุ่มแยก) → สำเร็จ: AuthGate navigate ต่อเอง (onboarding หรือ home ตามสถานะ) / ผิดพลาด: ล้างทุกช่องอัตโนมัติ + โฟกัสกลับช่องแรก + แสดง error → ระหว่าง cooldown 30 วิ ปุ่ม "ส่งรหัสอีกครั้ง" แสดงตัวนับถอยหลัง กดไม่ได้จนกว่าจะครบ → ครบแล้วกดขอ OTP ใหม่ได้ (รีเซ็ต cooldown เป็น 30 อีกครั้ง)

Components:
- Top App Bar — title "ยืนยันรหัส OTP"
- Text — คำอธิบาย + เบอร์โทรที่ส่งไป
- OTP Input — 6 ช่องแยก
- Spinner — ระหว่างตรวจสอบ OTP
- Inline error message — ใต้ OTP Input เมื่อรหัสผิด/หมดอายุ
- Text Button — resend, สลับข้อความระหว่าง countdown กับ "ส่งรหัสอีกครั้ง" ตามสถานะ

Interactions: auto-focus ช่องถัดไปเมื่อพิมพ์ครบ 1 หลัก, auto-focus ช่องก่อนหน้าเมื่อลบ, auto-submit ทันทีที่ครบ 6 หลักโดยไม่ต้องกดปุ่ม, รองรับ paste รหัสทั้งชุดตามสเปก OTP Input ของ wyn-143 (ปัจจุบันยังไม่รองรับ — ดู Design Rules)

States:
- Default
- Loading (verifying OTP)
- Error (OTP ผิด/หมดอายุ) → เคลียร์ทุกช่อง + โฟกัสช่องแรก + error message
- Resend on cooldown (นับถอยหลัง 30→0)
- Resend available (หลัง cooldown หมด)

Responsive Behavior: OTP boxes จัดกึ่งกลางแนวนอน ไม่ overflow บนจอแคบ (จอ ≥320px ต้อง fit 6 ช่อง + ระยะห่างได้พอดี)

Accessibility: แต่ละช่องประกาศลำดับ "หลักที่ N จาก 6" ให้ screen reader (มีอยู่แล้วในโค้ด คงไว้) error message ควรอยู่ใน live region เพื่อประกาศทันทีที่เกิด

Design Rules: ตาม wyn-143 ข้อ 2b กำหนดขนาดช่อง OTP เป็น 48×56px ตัวเลขใหญ่ `type.heading.1` และต้องมี shake animation สั้น ๆ (`motion.fast`, เคารพ reduce-motion) เมื่อ error — **ช่องว่าง implementation**: โค้ดปัจจุบันใช้กล่องขนาด 44×56 (`SizedBox(width: 44)`) และ `fontSize: 24` แบบ hardcode ไม่ตรง token ขนาด และไม่มี shake animation เมื่อ error (มีแค่เคลียร์ + ข้อความ) ต้องปรับขนาดเป็น 48×56 ใช้ `type.heading.1` และเพิ่ม shake animation ตอน implement รวมถึงเพิ่มการรองรับ paste ทั้งชุดตามสเปก wyn-143

Handoff: AI Coding — logic `verifyPhoneOtp`/`sendPhoneOtp`/countdown timer คงเดิมทุกประการ งานเพิ่มเติมคือปรับขนาด/ฟอนต์ OTP box ให้ตรง token, เพิ่ม shake animation ตอน error, เพิ่มการรองรับ paste — ยังคงเข้าถึงได้เฉพาะผ่าน flow ที่เปิด `_phoneLoginEnabled` เท่านั้น

---

## Screen: Redeem Invite Code

Purpose: หน้าจอสำหรับกรอกโค้ดเชิญ (WYN-113 Invite-Only Access Gate) แสดงแทนปุ่ม sign-in จริงที่ Auth Method Selection เมื่อ Founder เปิด gate อยู่และผู้ใช้รายนี้ยังไม่เคยยืนยันโค้ดใน session ปัจจุบัน — **ไม่ครอบคลุมปุ่ม guest browsing** ("เข้าชม WYNOS ได้เลย") ซึ่งจงใจอยู่นอก gate นี้เพราะเป็น session ชั่วคราวที่ไม่มี profile จริง

User Flow: จาก Auth Method Selection (เมื่อถูก invite gate บล็อก, กด "กรอกโค้ดเชิญ") → มาหน้านี้ → กรอกโค้ด → กด "ดำเนินการต่อ" (หรือกด Enter) → validate ผ่าน Supabase:
- โค้ดว่างเปล่า → error "กรุณากรอกโค้ดเชิญ" ทันทีในเครื่อง (ไม่เรียก network)
- โค้ดถูกต้อง → เก็บโค้ดไว้ (`PendingReferralCode`, จะถูก redeem จริงทีหลังใน OnboardingFlow) → pop กลับ Auth Method Selection พร้อมผล `true`
- โค้ดผิด → error "โค้ดเชิญไม่ถูกต้อง"
- เชื่อมต่อ Supabase ไม่สำเร็จ → error "เชื่อมต่อไม่สำเร็จ ลองใหม่อีกครั้ง"
- กด back โดยไม่กรอกโค้ด → กลับ Auth Method Selection ซึ่งยังคงถูก gate บล็อกอยู่เหมือนเดิม (ไม่มีทางเลี่ยง)

Components:
- Top App Bar — เปล่า (ปุ่ม back อัตโนมัติ, ไม่มี title ใน bar)
- Text heading — "กรอกโค้ดเชิญ"
- Text — อธิบายเหตุผล ("ตอนนี้ WYNOS เปิดให้เข้าใช้งานเฉพาะผู้ที่มีโค้ดเชิญจากเพื่อนเท่านั้น")
- Text Input — โค้ดเชิญ (auto-capitalize เป็นตัวพิมพ์ใหญ่ตาม keyboard hint)
- Primary Button — "ดำเนินการต่อ" (Spinner ระหว่างโหลด)
- Inline error message — ใต้ปุ่ม

Interactions: error เคลียร์ทันทีเมื่อผู้ใช้เริ่มพิมพ์ใหม่ กด Enter ที่ input เทียบเท่ากดปุ่ม (ถ้าไม่ loading)

States:
- Default
- Empty-submit error (validate ในเครื่อง ไม่เรียก network)
- Loading
- Invalid code error
- Network error
- Success (pop กลับพร้อมผล `true`)

Responsive Behavior: layout เดียวกับ Text Input pattern มาตรฐาน เต็มความกว้าง

Accessibility: field มี key คงที่สำหรับ automated test (`invite_code_field`) คงไว้ label "โค้ดเชิญ" ผูกกับ input เสมอ error message ควรอยู่ใน live region

Design Rules: ใช้ Text Input + Primary Button + Inline error message ตาม wyn-143 ทุกประการ ไม่ต้อง component พิเศษเพิ่ม

Handoff: AI Coding — logic `validateReferralCode`/`PendingReferralCode.set` คงเดิมทุกประการ เป็น visual restyle ตาม token ใหม่เท่านั้น

---

## Screen: Account Restricted

Purpose: หน้าจอที่ AuthGate render แทน RootShell/Welcome เมื่อบัญชีที่ล็อกอินอยู่ถูก Suspend (ชั่วคราว) หรือ Ban (ถาวร) — บล็อกการเข้าใช้งานแอปทั้งหมดจนกว่าจะกด "ตกลง" (ซึ่ง sign out ผู้ใช้ออก) พร้อมช่องทางอุทธรณ์ (WYN-030) เมื่อมี `actionId`

User Flow: ผู้ใช้ล็อกอินสำเร็จ (จากทุก flow ข้างต้น) → AuthGate เช็ค moderation status ก่อนเช็คอื่นใดทั้งหมด → พบว่า Suspended/Banned → render หน้านี้แทนการเข้าแอป → ผู้ใช้อ่านเหตุผลและ (ถ้า suspend) วันครบกำหนด → ถ้ามี `actionId`:
- `appealStatus == none` → เห็นปุ่ม "อุทธรณ์" → กดเปิด AppealFormScreen (นอก scope เอกสารนี้) → ส่งสำเร็จกลับมาหน้านี้ด้วย `appealStatus == pending`
- `appealStatus == pending` → เห็นข้อความสถานะแทนปุ่ม ไม่มีทาง action เพิ่ม
- `appealStatus == rejected` → เห็นข้อความสถานะถูกปฏิเสธ ไม่มีทาง appeal ซ้ำจากหน้านี้
- ไม่มี `actionId` เลย → ไม่มีส่วนอุทธรณ์ใด ๆ แสดง
- ไม่ว่าสถานะไหน กด "ตกลง" คือทางออกเดียวของหน้านี้เสมอ → sign out ผู้ใช้ → AuthGate กลับไป Welcome

Components:
- Icon สถานะ (ขนาดใหญ่ 72px, สี `color.error`) พร้อม Text heading กำกับความหมายชัดเจน ("บัญชีของคุณถูกระงับถาวร" / "...ชั่วคราว") — ข้อความกำกับนี้ทำหน้าที่ตามกติกา "ไม่สื่อความหมายด้วยสีอย่างเดียว"
- Text — เหตุผล (`reason` หรือ "ไม่ระบุ")
- Text — (เฉพาะ suspend ที่มี `expiresAt`) วันครบกำหนด + จำนวนวันที่เหลือ + คำอธิบายว่าจะกลับมาใช้งานได้ปกติเมื่อครบกำหนด
- Primary Button — "ตกลง" (full-width, ทางออกหลักเดียวของหน้านี้)
- (เมื่อมี `actionId` และ `appealStatus == none`) Secondary Button — "อุทธรณ์"
- (เมื่อ `appealStatus == pending`/`rejected`) Text สถานะ — `type.body.s` สี `color.ink.muted`

Interactions: กด "ตกลง" ปิด session ทันที (ไม่มี dialog ยืนยันซ้อน เพราะการอยู่หน้านี้ต่อไม่ทำให้เกิดผลเสียใด ๆ) กด "อุทธรณ์" เปิด flow แยกที่ไม่อยู่ใน scope เอกสารนี้ ส่งอุทธรณ์สำเร็จแล้วกลับมาหน้าเดิมทันที (ไม่ navigate ออกไปที่อื่น)

States:
- Banned (permanent, ไม่มี `expiresAt`, ไม่มีข้อความ "ระงับถึงวันที่")
- Suspended (มี `expiresAt`, แสดงวันครบกำหนด + จำนวนวันเหลือ)
- ไม่มีช่องทางอุทธรณ์ (`actionId == null`)
- มีช่องทางอุทธรณ์, ยังไม่เคยอุทธรณ์ (`appealStatus == none`)
- อุทธรณ์แล้ว รอผล (`appealStatus == pending`)
- อุทธรณ์ถูกปฏิเสธ (`appealStatus == rejected`)
- `appealStatus == approved` — ไม่ reachable ในทางปฏิบัติ (การอนุมัติอุทธรณ์ปลดบล็อกไปแล้ว AuthGate จะไม่ render หน้านี้อีกในการเช็คครั้งถัดไป) ให้ render เป็นค่าว่างไว้เผื่อกรณี edge

Responsive Behavior: เนื้อหาจัดกึ่งกลางแนวตั้งด้วย `mainAxisSize: min` รองรับทุกความสูงจอ (ไม่ scroll เพราะเนื้อหาสั้น) ปุ่ม "ตกลง" full-width เสมอ

Accessibility: icon ต้องมี semantic label ประกอบ ("ไอคอนแจ้งเตือนสถานะบัญชี") ไม่ใช่แค่ไอคอนสีแดงลอย ๆ — heading ข้อความ ("บัญชีถูกระงับ...") ทำหน้าที่สื่อความหมายหลักอยู่แล้วตามกติกา contrast ของ error icon/text ต้องผ่าน AA บนทั้ง light/dark

Design Rules: icon และข้อความสถานะใช้ `color.error` เพราะเป็นสถานะ negative/blocking จริง ปุ่ม "อุทธรณ์" ใช้ Secondary Button (ไม่ใช่สี error) เพราะเป็น action ที่เป็นกลาง/บวกสำหรับผู้ใช้ ไม่ใช่ destructive action ปุ่ม "ตกลง" ใช้ Primary Button ปกติด้วย `color.accent` (ไม่ใช้สี error) เพราะการกดออกจากหน้านี้ไม่ใช่ destructive action ต่อระบบ เป็นแค่การรับทราบและออก

Handoff: AI Coding — logic sign-out on acknowledge, `onAppeal` callback, และการที่ AuthGate render จาก local State (ไม่ derive ตรงจาก auth stream) คงเดิมทุกประการ เป็น visual restyle ตาม token ใหม่เท่านั้น

---

## Handoff รวม

สเปกทั้ง 7 หน้าจอในเอกสารนี้อ้างอิงเฉพาะ token จาก `wyn-142-visual-identity-redesign.md` และคอมโพเนนต์จาก `wyn-143-core-component-library.md` เท่านั้น — ทั้งสองเอกสารยังอยู่สถานะ PROPOSED **ต้องรอ Founder ยืนยันอย่างเป็นทางการก่อน** ตามกติกา "ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด" (เหมือนที่ WYN-141 เคยทำ visual gate ก่อน implementation)

รายการช่องว่างระหว่างสเปกนี้กับ implementation ปัจจุบันที่ AI Coding ต้องแก้ (สรุปจากทุกหน้าจอด้านบน):
1. Auth Method Selection — ปุ่ม Google ต้องเปลี่ยนจาก `Icons.g_mobiledata` เป็น Google "G" logo asset จริง
2. Phone Entry — เพิ่ม helper text บอกรูปแบบเบอร์ที่ถูกต้องเมื่อ format ผิด, เปลี่ยน label จาก floating label (Material default) เป็น label คงที่ด้านบนตาม Text Input component ใหม่
3. Email Auth — แยกสีข้อความ "รอยืนยันอีเมล" ออกจาก error จริง (ใช้ `color.success`/`color.ink` แทน `color.error`), เพิ่มปุ่มแสดง/ซ่อนรหัสผ่าน
4. OTP Verification — ปรับขนาดกล่อง OTP จาก 44×56 เป็น 48×56 ตาม token, ใช้ `type.heading.1`, เพิ่ม shake animation ตอน error, เพิ่มการรองรับ paste ทั้งชุด

ทั้งหมดนี้เป็นการปรับ visual/UX detail เท่านั้น ไม่กระทบ business logic, authentication flow, หรือ flag การเปิด-ปิดฟีเจอร์ที่มีอยู่ (`_appleLoginEnabled`, `_phoneLoginEnabled`, `_guestBrowsingEnabled`) — การเปิดใช้งาน flag เหล่านั้นยังคงต้องรอคำสั่ง Founder แยกต่างหากตามเดิม ไม่เกี่ยวกับงาน redesign นี้
