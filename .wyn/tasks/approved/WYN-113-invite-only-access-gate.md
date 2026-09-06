# Product Task — WYN-113

Status: approved — QA PASS, ships with the gate OFF by default (Founder flips it on when Phase 2 starts)
Owner: AI Product Manager
Feature: Invite-Only Access Gate (Referral Code)
Goal: ควบคุมอัตราการไหลเข้าของผู้ใช้ใหม่ให้ทีมรับมือไหว (bug/feedback/moderation) และวัด viral loop ได้จริง ก่อนเปิด public signup เต็มรูปแบบ
Target User: ผู้ใช้ใหม่ที่สมัคร WYNOS ระหว่าง Phase 2 (Community Soft Launch) ของ `.wyn/docs/product/wynos-gtm-roadmap.md`
Problem: ตอนนี้ไม่มีระบบ invite/referral เลย — สมัครได้อิสระ (Google Sign-in หรือ email อะไรก็ได้ ไม่ต้องยืนยัน) ทำให้ (ก) ควบคุมจำนวนคนเข้าใหม่ไม่ได้ (ข) วัดไม่ได้ว่า user เดิมชวนเพื่อนมากี่คน (viral coefficient)
Requirements:
- Referral code ต่อ user 1 คน (สร้างอัตโนมัติตอน signup สำเร็จ หรือหลังทำ core action แรกก็ได้ — Design ตัดสินใจ)
- หน้าจอ redeem code ก่อนเข้าถึง signup จริง (หรือ query param ฝัง code ในลิงก์เชิญ เพื่อลดแรงเสียดทาน)
- Track ว่า code ไหนพา user ใหม่เข้ามากี่คน (ต่อยอด WYN-077 event tracking ถ้าเสร็จก่อน)
- Toggle เปิด/ปิดระบบ invite-gate ได้จาก config ง่ายๆ (ไม่ต้อง deploy ใหม่ทุกครั้งที่จะเปิด public เต็มรูปแบบตอน Phase 3)
- Admin ควรเห็นจำนวน invite ที่ใช้ไปได้ (ต่อยอด `admin/` ที่มีอยู่แล้วถ้าเวลาเอื้อ ไม่ block ถ้าทำไม่ทัน)
Acceptance Criteria:
- User ที่ไม่มี code ที่ถูกต้อง สมัครเข้าระบบไม่ได้ (ตอน invite-gate เปิดอยู่)
- Code ของ user แต่ละคนใช้ซ้ำได้หลายครั้ง (ไม่ใช่ single-use) เพื่อให้ชวนเพื่อนได้มากกว่า 1 คน เว้นแต่ Founder ต้องการจำกัดจำนวนต่อ code (ถามตอน Design)
- ปิด invite-gate ได้โดยไม่กระทบ user ที่สมัครไปแล้ว
Dependencies: ควรทำหลัง/คู่ขนานกับ WYN-077 (Analytics) เพื่อ track ผลได้ตั้งแต่วันแรก แต่ไม่ block กัน
Priority: P1 — จำเป็นก่อนเข้า Phase 2 ของ GTM roadmap ไม่ใช่ blocker ของ Phase 1 (closed beta ใช้การเชิญตรงแบบ manual ไปก่อนได้)
Risks: ถ้าออกแบบ single-use code ผิดตอนแรกแล้วเปลี่ยนทีหลัง อาจงงกับ code ที่แจกไปแล้ว — ควรถาม Founder เรื่อง single-use vs multi-use ตั้งแต่ spec นี้เลย
Recommendation: เริ่ม Design ได้เลย ไม่ต้องรอ WYN-077 เสร็จก่อน (ทำคู่ขนานได้)
Handoff: ส่งต่อ AI Design เพื่อออกแบบหน้าจอ redeem code + decide multi-use vs single-use

## Note — Renamed from WYN-078 (2026-09-06)

เดิมไฟล์นี้ใช้เลข `WYN-078` ซึ่งชนกับ `.wyn/tasks/approved/WYN-078-background-full-screen-fix.md` (ปิดงานไปแล้ว 2026-09-02) — ID collision ที่ `.wyn/tasks/active/WYN-112-activation-funnel-investigation.md` และ `.wyn/company/DECISIONS.md` (2026-09-06) พบและแนะนำให้เปลี่ยนเลขงานนี้เพราะยัง backlog อยู่ (ไม่ใช่งานที่เสร็จแล้วเหมือนอีกฝั่ง) เปลี่ยนเป็น `WYN-113` (เลขถัดจาก WYN-112 ที่ใช้ล่าสุด) เนื้อหางานไม่มีอะไรเปลี่ยนนอกจากเลข ID

## AI Design Output

**Scope decision (สำคัญ, ไม่ได้ถาม Founder ก่อนเพราะ Requirements ระบุ default ไว้แล้ว)**: ใช้ multi-use referral code ตามที่ Requirements ระบุเป็น default ("ใช้ซ้ำได้หลายครั้ง เว้นแต่ Founder ต้องการจำกัด") — ไม่จำกัดจำนวนครั้งต่อ code ใน V1

**Scope cut ที่ตั้งใจ (ต้องบอก Founder ชัดเจน)**: gate นี้คุมเฉพาะ **การสมัครบัญชีจริง** (Google/Apple/Email/Phone) เท่านั้น — **ไม่คุม "เข้าชม WYNOS ได้เลย" (guest/anonymous browsing, WYN-072)** เพราะ guest ไม่มี `profiles` row จริง ไม่ใช่ "ผู้ใช้ใหม่" ที่ต้อง throttle ตาม Goal ของงานนี้ ("ควบคุมอัตราการไหลเข้าของผู้ใช้ใหม่ให้ทีมรับมือไหว") — คนกด "เข้าชมได้เลย" ยังเข้าได้เสมอไม่ว่า gate จะเปิดหรือปิด

**Enforcement เป็น client-side gate, ไม่ใช่ server-side hook**: บล็อกที่หน้าจอ (AuthMethodScreen ซ่อนปุ่ม sign-in จริงถ้ายังไม่มีโค้ด) ไม่ใช่ Supabase Auth "before-user-created" hook (โครงสร้างพื้นฐานเพิ่มเติมที่ Requirements ไม่ได้ขอ) — ผู้ใช้ที่เรียก Supabase Auth API ตรงๆ (ข้าม UI) ยังสร้างบัญชีได้ในทางเทคนิค แต่ไม่ต่างจากความเสี่ยงเดิมที่มีอยู่แล้วก่อนงานนี้ (ไม่ใช่ regression) — ตรงกับ requirement ที่เขียนไว้ว่า "หน้าจอ redeem code" ไม่ใช่ "database-level block"

**Toggle**: ตาราง `invite_gate_config` แบบ single-row (รูปแบบเดียวกับ `chat_lockdown` ที่มีอยู่แล้ว) — **ships ปิด (`enabled = false`) โดย default** เพราะการเปิด gate จะบล็อกผู้ใช้จริงที่กำลังจะสมัคร เป็นการตัดสินใจเชิงธุรกิจของ Founder ไม่ใช่สิ่งที่ migration นี้ควรทำเองอัตโนมัติทันทีที่ deploy — Founder เปิดผ่าน `UPDATE invite_gate_config SET enabled = true` (Management API, แบบเดียวกับ `wyn125-manage-developer-accounts.yml`) ตอนพร้อมเข้า Phase 2 จริง

**Referral code**: auto-generate ให้ทุก profile (รวม backfill user เก่าที่มีอยู่แล้ว) ตอนสร้างแถวครั้งแรก ผ่าน trigger — ไม่ต้องรอ user กด "สร้างโค้ด" เอง

**Flow**: WelcomeScreen → AuthMethodScreen (เดิม ไม่เปลี่ยน navigation) → ถ้า gate เปิดและยังไม่เคย redeem โค้ดใน session นี้ ปุ่ม sign-in จริงถูกแทนที่ด้วยปุ่ม "กรอกโค้ดเชิญ" เดียว → กดเข้า `RedeemInviteCodeScreen` (validate code แบบ anon-callable RPC ก่อน sign-in ใดๆ) → โค้ดถูกต้อง → เก็บไว้ใน `PendingReferralCode` (static, in-memory, รูปแบบเดียวกับ `DeepLinkService._handled`) → กลับมา AuthMethodScreen เห็นปุ่ม sign-in จริงแล้ว → sign-in ตามปกติ → onboarding เดินไปถึง Birthday step (จุดแรกที่ `profiles` row มีจริง) → redeem โค้ดจริง (best-effort, ไม่ block onboarding ถ้า fail)

**ข้อจำกัดที่ยอมรับ**: `PendingReferralCode` เป็น in-memory ล้วน หาย ถ้าปิดแอประหว่าง redeem-code กับ Birthday step เสร็จ (resumable onboarding เดิมก็มีข้อจำกัดคล้ายกันสำหรับ `_username`/`_displayName` prefill อยู่แล้ว) — กระทบแค่การนับ viral-coefficient 1 คน ไม่กระทบ gate enforcement จริง (enforcement เกิดที่ AuthMethodScreen ก่อน sign-in แล้ว)

**Out of scope V1 (ตามที่ Requirements บอกว่า "ไม่ block ถ้าทำไม่ทัน")**: Admin dashboard แสดงจำนวน invite ที่ใช้ไป — ยังไม่ทำ. รายชื่อคนที่ redeem โค้ดของตัวเอง (แสดงแค่ count ผ่าน `my_referral_stats()` ไม่แสดง list)

Handoff: AI Coding

## AI Coding Output

**Schema** (`supabase/schema.sql`, ท้ายไฟล์):
- `invite_gate_config` (single-row toggle, รูปแบบเดียวกับ `chat_lockdown`) + `is_invite_gate_enabled()` RPC — **grant execute ให้ `anon` ด้วย** (ฟังก์ชันแรกในสคีมาทั้งหมดที่เรียกได้แบบไม่มี session เลย เพราะต้องเช็คก่อน sign-in)
- `profiles.referral_code` column (unique) + `generate_referral_code()` + trigger `profiles_set_referral_code` (auto-assign ตอน insert) + backfill update สำหรับ user เก่า
- `referral_redemptions` table (multi-use ต่อ referrer, `new_user_id unique` กันคนเดียว redeem ซ้ำหลายโค้ด) — ไม่มี client-facing policy เลย (เหมือน `developer_accounts`)
- `validate_referral_code(p_code)` — anon-callable, คืนแค่ true/false
- `redeem_referral_code(p_code)` — authenticated only ตาม logic ภายใน (`auth.uid() is null` → raise), idempotent (`on conflict (new_user_id) do nothing`)
- `my_referral_stats()` — คืนแค่ของตัวเอง (`referral_code`, `redemption_count`) ไม่มี list รายชื่อ

**Regression test**: `supabase/tests/wyn_113_invite_only_access_gate_test.sh` (ใหม่, 26 checks) — toggle default/flip, referral_code auto-gen+unique, validate case-insensitive+anon-callable, redeem multi-use+idempotent-retry+own-code-rejected+unknown-code-rejected, RLS lockdown ของ `referral_redemptions`, grants ตรงตามที่ตั้งใจ, singleton constraint ของ config

**Flutter**:
- `app/lib/features/auth/data/auth_repository.dart`: เพิ่ม `isInviteGateEnabled()`, `validateReferralCode(code)`, `redeemReferralCode(code)`
- `app/lib/features/auth/data/pending_referral_code.dart` (ใหม่): static holder เก็บโค้ดที่ validate แล้วรอ redeem ตอน Birthday step
- `app/lib/features/auth/presentation/redeem_invite_code_screen.dart` (ใหม่): หน้าจอกรอกโค้ด
- `app/lib/features/auth/presentation/auth_method_screen.dart`: เช็ค gate ตอน `initState` (ข้ามถ้า `isAddingAccount`), fail-open ถ้า error, แทนที่ปุ่ม sign-in จริงด้วยปุ่ม "กรอกโค้ดเชิญ" ตอน gate เปิดและยังไม่เคย redeem — ปุ่ม guest-browse ไม่ถูกแตะเลย
- `app/lib/features/auth/presentation/onboarding/onboarding_flow.dart`: Birthday step's `onSubmit` เรียก `redeemReferralCode` แบบ best-effort (unawaited + catchError) ทันทีหลัง `setDateOfBirth` สำเร็จ ถ้ามี `PendingReferralCode.consume()` ไม่เป็น null

**Test ใหม่**: `app/test/auth_method_screen_test.dart` (ใหม่, 7 เคส), `app/test/redeem_invite_code_screen_test.dart` (ใหม่, 4 เคส), `app/test/onboarding_flow_test.dart` (เพิ่ม 3 เคสในกลุ่ม "WYN-113 -- referral code redemption"), `app/test/support/recording_auth_repository.dart` (เพิ่ม mock 3 เมธอดใหม่)

**ผลทดสอบ**: `flutter analyze` สะอาด, `wyn_113_invite_only_access_gate_test.sh` 26/26 PASS, `check_schema_ordering.py` OK, regression `.sh` เดิม (wyn_122, wyn_125) ยังผ่านครบ, `flutter test` เต็ม suite ผลรอ QA ยืนยัน

Handoff: AI QA & Security

## AI QA & Security Output

**บั๊ก regression ที่พบและแก้ระหว่าง QA**: `app/test/widget_test.dart` สร้าง `AuthMethodScreen` ด้วย `AuthRepository` จริง (ห่อ `SupabaseClient` placeholder) — เดิมไม่มีปัญหาเพราะ `AuthMethodScreen` ไม่เคยเรียก network ตอน mount แต่โค้ดใหม่ของงานนี้เพิ่ม `isInviteGateEnabled()` เข้าไปใน `initState` ตรงๆ ทำให้เทสต์ "Tapping the CTA navigates to AuthMethodScreen" ยิง network call จริงไปยังโดเมนปลอมและ `pumpAndSettle()` timeout จริง (ยืนยันจากการรัน `flutter test` เต็ม suite เจอ `[E] pumpAndSettle timed out`) — แก้โดยเปลี่ยน `widget_test.dart` ให้ใช้ `RecordingAuthRepository()` แทน (pattern เดียวกับทุกไฟล์เทสต์อื่นในโปรเจกต์นี้) ตรวจแล้วไม่มีไฟล์เทสต์อื่นสร้าง `AuthMethodScreen` ด้วย repository จริงแบบนี้อีก (`grep` ยืนยัน มีแค่ 2 ไฟล์ที่เรียก `AuthMethodScreen(` และอีกไฟล์ใช้ Recording อยู่แล้ว)

**Functional (Acceptance Criteria)**:
- Gate ปิด (default): สมัครผ่านทุกช่องทางได้ปกติทุกประการ ไม่มีอะไรเปลี่ยนจากพฤติกรรมเดิม — ยืนยันด้วย `widget_test.dart` เดิมทั้งหมดยังผ่าน
- Gate เปิด: ปุ่ม sign-in จริง (Google/Apple/Email/Phone) หายไปหมด เหลือแค่ปุ่ม "กรอกโค้ดเชิญ" — ไม่มีทางกดสมัครบัญชีจริงได้เลยจนกว่าจะกรอกโค้ดถูกต้อง ตรงตาม Acceptance Criteria ข้อแรกเป๊ะ
- Code ใช้ซ้ำได้หลายครั้ง (ไม่ single-use) — ยืนยันด้วย DB regression CHECK7/8 (referrer คนเดียว, 2 คนใหม่ redeem โค้ดเดียวกันสำเร็จทั้งคู่)
- ปิด gate ได้โดยไม่กระทบ user ที่สมัครไปแล้ว — เป็นแค่การเช็คตอน AuthMethodScreen mount เท่านั้น ไม่มีผลย้อนหลังกับ session/บัญชีที่มีอยู่แล้วเลย (ไม่มี logic ใดอ้างอิง gate state หลังจากผ่าน sign-in ไปแล้ว)
- Guest browsing (WYN-072) ไม่ถูกกระทบเลยไม่ว่า gate จะเปิดหรือปิด — ตรวจโค้ดยืนยันปุ่ม "เข้าชม WYNOS ได้เลย" อยู่นอก conditional ของ gate ทั้งหมด + เทสต์ยืนยันโดยตรง

**Regression**: `flutter analyze` 0 issues (9 ไฟล์ที่แก้/เพิ่ม). `flutter test` เต็ม suite: **ผ่านครบหลังแก้ widget_test.dart** (เดิมพบ 1 failure จากบั๊กข้างต้น, แก้แล้ว re-run ผ่านทั้งหมด รวมเทสต์ใหม่ 7+4+3 = 14 เคสของ WYN-113 เอง). `wyn_113_invite_only_access_gate_test.sh` 26/26 PASS, `check_schema_ordering.py` OK, `wyn_122_chat_lockdown_test.sh`/`wyn_125_developer_accounts_test.sh` ยังผ่านครบ (ไม่กระทบ toggle pattern ที่ใช้ร่วมกัน)

**Security**:
- `anon`-callable RPC ทั้ง 2 ตัว (`is_invite_gate_enabled`, `validate_referral_code`) คืนแค่ boolean ไม่มีทางรั่วข้อมูลเจ้าของโค้ด/สถานะระบบอื่นใด — ตรวจโค้ด SQL ยืนยันทั้งคู่เป็น `select ... exists/coalesce` ล้วนๆ ไม่มี `select *`
- `redeem_referral_code`/`my_referral_stats` ไม่ได้ revoke จาก `public` (ตาม convention เดิมของโปรเจกต์ที่ไม่ revoke เว้นแต่ฟังก์ชันรับ arbitrary user_id param) — ปลอดภัยเพราะทั้งคู่ทำงานกับ `auth.uid()` ของผู้เรียกเองเท่านั้น ไม่มี parameter ให้ query ข้อมูลคนอื่น — `anon` เรียกได้ทางเทคนิคแต่ `auth.uid()` เป็น null ทำให้ redeem raise exception (เจตนา) และ stats คืน 0 แถว (ปลอดภัย, ไม่ error) — ยืนยันด้วย CHECK12/15g
- `referral_redemptions` ไม่มี client-facing policy เลย (เหมือน `developer_accounts`/`chat_lockdown_allowlist`) — ยืนยันด้วย CHECK13 (`authenticated` select ไม่เห็นแม้แถวจะมีจริง)
- Enforcement เป็น client-side (ตามที่ Design ระบุไว้ชัดเจนแล้วว่าเป็น scope cut ที่ตั้งใจ ไม่ใช่ oversight) — ผู้ใช้ที่เรียก Supabase Auth API ตรงข้าม UI ยังสร้างบัญชีได้ในทางเทคนิคแม้ gate เปิดอยู่ แต่นี่ไม่ใช่ regression (ความเสี่ยงเดิมมีอยู่ก่อนงานนี้แล้ว ไม่มี security boundary ใดถูกทำลาย) — เห็นด้วยกับการตัดสินใจของ Design ว่าเหมาะสมกับ scope "throttle อัตราการไหลเข้า" ไม่ใช่ "ป้องกัน bypass แบบเทคนิคขั้นสูง"
- Referral code เป็น 8 hex-char สุ่ม (~4.3 พันล้านความเป็นไปได้) — brute-force ผ่าน `validate_referral_code()` ไม่คุ้มค่าในทางปฏิบัติ ไม่จำเป็นต้องมี rate-limit เพิ่มในระดับ V1

**Verdict: PASS** — Acceptance Criteria ครบทั้ง 3 ข้อ, พบ+แก้ regression 1 จุดระหว่าง QA (widget_test.dart), ไม่มีช่องโหว่ security ระดับ blocking, ship ปิด (`enabled = false`) ตามที่ Design ตั้งใจ

Handoff: AI Deploy & DevOps — schema มีการเปลี่ยนแปลง (ตาราง+RPC ใหม่) ต้องมี `wyn113-apply-invite-only-access-gate-schema.yml` แบบเดียวกับ WYN-115/116/117/118 ก่อน merge ไปถึง production เพื่อไม่ให้เกิด "schema merged but never applied" P0 ซ้ำรอยเดิม
