# Product Task — WYN-119

Status: approved — QA PASS, Requirement 2 (guest deep-link) เสร็จสมบูรณ์แล้ว
Owner: AI Product Manager

Feature: Real Deep Linking (Tier 2) — เปิดลิงก์ Share แล้วพาไปหน้าเนื้อหานั้นจริง

Goal: ทำให้ลิงก์ `wynos.online/club/<id>`, `/drop/<id>`, `/pop/<id>`, `/@<username>`, `/club-post/<id>` เมื่อเปิดจากเบราว์เซอร์ พาไปหน้าจอเนื้อหานั้นจริง ไม่ใช่แค่เปิดแอปแล้วเข้า Home/AuthGate เหมือนเปิดเว็บเปล่าๆ

Target User: ทุกคนที่กดลิงก์ Share ของ Club/Drop/Pop/Profile ที่ส่งมาจากผู้ใช้อื่น (โดยเฉพาะเพื่อนที่ถูกชวนเข้า Club — เป้าหมายเดิมของ session นี้)

Problem: **ID collision ที่แก้แล้ว**: งานนี้เดิมถูกบันทึกเป็น `WYN-114` โดย session นี้เอง แต่ระหว่างทำพบว่าอีก session หนึ่ง (`session_013hvSGovkwhxpPFbFEKAvAu`) ใช้เลข `WYN-114` ไปแล้วสำหรับงานเดียวกันบางส่วน และ**ทำเสร็จ+ผ่าน QA+deploy จริงไปแล้ว**: เปลี่ยนโดเมนลิงก์ Share ทั้ง 5 จุดจาก `wyn.app` (ไม่มี DNS จริง) เป็น `wynos.online` จริง (`.wyn/tasks/completed/WYN-114-share-link-real-domain.md`) และเพิ่ม `app/web/vercel.json` แก้ปัญหา Vercel 404 ทุก path ที่ไม่ใช่ `/` เพราะไม่เคยมี config นี้เลย (`.wyn/tasks/bugs/WYN-114-vercel-404-no-spa-rewrite.md`, QA PASS) — เรียกงานนี้ว่า **"Tier 1"** — **deploy จริงแล้ว** (`deploy-web.yml` run #89, production-verified ด้วย curl จริงต่อ `wynos.online` — ดู `.wyn/logs/deployments/2026-09-06-wyn-114-share-link-vercel-rewrite-deploy.md`)

Session นั้นระบุไว้ชัดเจนในโค้ดของตัวเองแล้วว่า "Tier 2" (path-based routing จริงในแอป) **ยังไม่ทำ ไม่ approved** — `main.dart` ยังคง `home: const AuthGate()` ตายตัว ไม่มี `GoRouter`/ไม่มีการอ่าน `Uri.base.path` เลย ต่อให้ Tier 1 deploy แล้ว การเปิด `wynos.online/club/<id>` จะไม่ 404 อีกต่อไป แต่จะเปิด Home/AuthGate เหมือนเปิดเว็บเปล่าๆ ไม่ใช่หน้า Club ที่ตั้งใจแชร์ — **นี่คือ scope ที่เหลือจริงของงานนี้ (Tier 2)**

Requirements:
1. อ่าน path จาก URL ตอนแอปโหลดครั้งแรกบนเว็บ (`Uri.base.path`) แล้ว map เป็นปลายทางที่ถูกต้อง: `/club/:id` → ClubPage, `/club-post/:id` → ClubPostDetailScreen, `/drop/:id` → DropDetailScreen, `/pop/:id` → PopSingleClipScreen/PopClipView, `/@:username` → ViewProfileScreen
2. รองรับ guest (ยังไม่ login) ให้เห็น preview เนื้อหาได้ก่อนตาม guest-browsing ที่มีอยู่แล้ว (WYN-072) แล้วค่อย gate ตอนจะ join/like/comment จริง — ไม่ใช่บังคับ login ก่อนเห็นอะไรเลย
3. Path ที่ไม่ตรงกับ pattern ใดเลย (หรือ id ไม่มีอยู่จริง) ต้อง fallback เข้า Home ปกติ ไม่ error/หน้าขาว
4. ไม่แตะ Tier 1 (`app/web/vercel.json`, โดเมนใน 5 share-link function) ที่ approved แล้ว — งานนี้ต่อยอดเท่านั้น

Acceptance Criteria:
- เปิด `https://wynos.online/club/<id จริง>` จากเบราว์เซอร์ใหม่ (ไม่เคย login) เห็นหน้า Club นั้นจริง ไม่ใช่ Home/AuthGate
- เปิด `/drop/<id>`, `/pop/<id>`, `/@<username>`, `/club-post/<id>` ได้ผลเดียวกันตามเนื้อหานั้น
- Path แปลกปลอม/id ที่ลบไปแล้ว fallback เข้า Home อย่างนุ่มนวล ไม่ crash

Dependencies: ไม่มีแล้ว — Tier 1 (WYN-114) deploy จริงและ production-verified แล้ว (2026-09-06) เริ่ม Tier 2 นี้ได้ทันที ทดสอบบน production จริงได้เลย

Priority: P1 — Tier 1 (WYN-114) แก้ "ลิงก์เปิดได้ไหม" ซึ่งสำคัญกว่าและสงสัยว่าเป็นสาเหตุของ WYN-112 โดยตรง (Founder ยืนยันแล้ว) ส่วน Tier 2 นี้แก้ "เปิดแล้วเห็นเนื้อหาที่ถูกต้องไหม" ซึ่งจำเป็นสำหรับ growth loop ให้สมบูรณ์แต่ไม่ block การวัดผล WYN-112 รอบต่อไป (แค่เปิดได้ก็พอเห็น "signup กลับมาไหม" ได้แล้ว)

Risks: การเพิ่ม route parsing อาจกระทบพฤติกรรม guest-browsing เดิม (WYN-072) และ initial-route ของ `main.dart` ที่ AuthGate ทำงานอยู่ในปัจจุบัน — ต้องให้ Design ตรวจ flow ทั้งหมดก่อน Coding ไม่ใช่แค่ต่อ route ทับเข้าไปเฉยๆ

Recommendation: ส่งต่อ AI Design ได้เลย ไม่ต้องรอ Founder อนุมัติเพิ่มเติม (เป็นการต่อยอดฟีเจอร์ share ที่มีอยู่แล้ว ไม่ใช่ major architecture change) — Tier 1 deploy แล้ว ทดสอบ end-to-end บน production จริงได้ทันทีที่ Coding เสร็จ

Handoff: AI Design (ออกแบบ flow deep-link ฝั่ง guest + initial-route parsing) → AI Coding (รอ Tier 1 deploy ก่อน) → AI QA & Security (ทดสอบเปิดลิงก์จริงจากเบราว์เซอร์ที่ไม่เคย login มาก่อน ไม่ใช่แค่จากใน app)

## Note — ID Collision (2026-09-06)

เดิมงานนี้ถูกบันทึกเป็น `WYN-114` โดย session นี้เอง (ก่อนพบว่าอีก session ใช้เลขเดียวกันไปแล้วและทำเสร็จ+QA PASS ก่อน) — เปลี่ยนเป็น `WYN-119` ตามนี้เพื่อไม่ให้ชนกับ `WYN-114` ที่ approved แล้วจริงของอีก session เป็น ID collision class เดียวกับที่เคยพบมาแล้ว 2 ครั้งก่อนหน้า (`WYN-078`, และที่บันทึกไว้ 2026-08-25) — ยังไม่มีกลไกป้องกันไม่ให้เกิดซ้ำเมื่อมีหลาย session ทำงานพร้อมกัน ควรพิจารณาแก้ที่ระดับ process (เช่น ล็อกไฟล์ "next-id" กลาง หรือ pattern อื่น) แยกต่างหากจากงานนี้

## Partial Coding Output จาก session คู่ขนานอีกตัว (2026-09-06, ก่อนเจอไฟล์นี้)

Session คู่ขนานอีกตัวหนึ่ง (คนละ session กับที่เขียนไฟล์นี้ขึ้นมา) เจอปัญหาเดียวกันเป๊ะโดยไม่รู้จักไฟล์นี้มาก่อน (ตั้งชื่องานตัวเองว่า `WYN-114` เหมือนกัน ก่อนจะพบ ID collision กับทั้งไฟล์นี้และกับ `WYN-114-share-link-real-domain.md` ระหว่าง merge) และ implement ไปแล้วบางส่วน — merge เข้า main พร้อมงานนี้เลย ไม่ต้องรอรอบถัดไป:

**สิ่งที่ทำสำเร็จแล้ว (Requirement 1, 3)**: `app/lib/core/navigation/deep_link_service.dart` (`DeepLinkService`) อ่าน `Uri.base.path` (เว็บเท่านั้น, `kIsWeb`) ตอน `RootShell.initState()` ครั้งแรกของแต่ละ sign-in แล้ว map ไปหน้าที่ถูกต้องครบทั้ง 5 ประเภท (`/drop/:id` → `DropDetailScreen`, `/club/:id` → `ClubPage`, `/club-post/:id` → `ClubPostDetailScreen`, `/@:username` → `ViewProfileScreen` ผ่าน `fetchProfileByUsername`, `/pop/:id` → SnackBar "ไม่พร้อมใช้งาน" ตาม WYN-102) — path ที่ไม่ตรง pattern/id ไม่มีจริง fallback เงียบๆ เข้า Home ปกติ ไม่ crash (มี regression test ยืนยันครบใน `app/test/deep_link_service_test.dart`)

**สิ่งที่ยังไม่ได้ทำ (Requirement 2 — gap สำคัญที่สุดของ Acceptance Criteria)**: **ไม่รองรับ guest ที่ยังไม่เคย login เลย** — `DeepLinkService.handleInitialLink()` ถูกเรียกจาก `RootShell.initState()` เท่านั้น ซึ่ง mount ได้ก็ต่อเมื่อผ่าน `AuthGate` ครบ (login + onboard เสร็จ) แล้วเท่านั้น คนที่ไม่เคย sign-in มาก่อนกดลิงก์จะเห็น `WelcomeScreen` ตามปกติ ไม่มีทางไปถึง `DeepLinkService` เลย ไม่ตรงกับ Acceptance Criteria ข้อแรกของงานนี้ ("เปิดจากเบราว์เซอร์ใหม่ (ไม่เคย login) เห็นหน้า Club นั้นจริง") — **ยังไม่ implement ส่วนนี้โดยตั้งใจ** เพราะ Risk ที่ระบุไว้ข้างบนแล้วว่าต้องให้ Design ตรวจ flow guest-browsing (WYN-072)/AuthGate ก่อน Coding ไม่ใช่แค่ต่อ route ทับเข้าไป — session ที่ implement ส่วน authenticated-user ไม่ได้ทำ Design pass นี้ก่อน (ไม่รู้จักไฟล์นี้มาก่อน) จึงจงใจไม่แตะ AuthGate เพื่อไม่เสี่ยง regression ตามที่ Risk เตือนไว้

**สถานะ**: งานนี้ยัง**ไม่ปิด** — ยังต้องมี Design pass สำหรับ guest-browsing flow ก่อน แล้วส่งต่อ Coding ทำ Requirement 2 ให้ครบ ถึงจะผ่าน Acceptance Criteria เต็มรูปแบบ ส่วน authenticated-user path (Requirement 1, 3) ใช้งานได้จริงแล้ววันนี้ ผ่าน QA + deploy พร้อมกับ session ที่เขียนส่วนนี้ (ดู `.wyn/tasks/approved/WYN-123-invite-followers-to-club.md` ที่พึ่งพา deep-link นี้บางส่วน)

## AI Design Output (Requirement 2 — guest deep-link flow)

**Flow ที่เลือก**: ไม่สร้างกลไก "preview" ใหม่แยกต่างหาก — ใช้ WYN-072's Anonymous Sign-In (ปุ่ม "เข้าชม WYNOS ได้เลย") ที่มีอยู่แล้วทั้งระบบ เป็นทางเข้าเดียวกัน:

1. `AuthGate.build()` เมื่อ `session == null` (ยังไม่เคย login เลย): เช็ค `DeepLinkService.hasContentPath()` (เมธอดใหม่ อ่าน `Uri.base.path` แบบเดียวกับที่ `_handle()` ทำอยู่แล้ว แต่แค่เช็ครูปแบบ ไม่ navigate) — ถ้า URL ปัจจุบันตรงกับ pattern เนื้อหา (`/drop`, `/pop`, `/club`, `/club-post`, `/@username`) ให้เรียก `AuthRepository.signInAnonymously()` แบบเงียบๆ (ไม่ต้องกดปุ่มอะไรเอง) แทนที่จะโชว์ `WelcomeScreen` ทันที
2. เมื่อ sign-in anonymous สำเร็จ → auth stream ยิง `signedIn` → widget rebuild เจอ `session` ที่ `isAnonymous == true` → โค้ดเดิมของ AuthGate (บรรทัดที่มีอยู่แล้วสำหรับ WYN-072) ส่งตรงไป `RootShell` ทันที ข้าม onboarding/username setup ทั้งหมด (เหมือน guest ทั่วไปทุกประการ)
3. `RootShell.initState()` เรียก `DeepLinkService.handleInitialLink()` ตามเดิม (โค้ดเดิมจาก partial-coding ของ session คู่ขนาน) → เปิดเนื้อหาจริงตาม path ทับ RootShell

**ทำไมไม่แตะ AuthGate ก่อนจุดนี้ (moderation/document-acceptance gate)**: เพราะ anonymous session ที่สร้างใหม่ไม่มีทางถูก suspend/ban มาก่อน (เพิ่งสร้าง) และ WYN-072 เดิมก็ให้ anonymous ข้าม document acceptance ไปแล้วตามโค้ดเดิม (`session.user.isAnonymous` check อยู่หลัง 2 gate นั้นพอดี) — ไม่ต้องเปลี่ยน ordering ใดๆ ของ gate ที่มีอยู่

**Gate จุด join/like/comment**: ไม่ต้องทำอะไรเพิ่ม — `guest_gate.dart`'s `requireRealAccount()` ที่มีอยู่แล้วทั้งแอปทำหน้าที่นี้อยู่แล้วสำหรับ anonymous user ทุกคนไม่ว่าจะมาจากปุ่ม "เข้าชมได้เลย" หรือมาจาก deep-link แบบใหม่นี้ — เป็น session ชนิดเดียวกันเป๊ะ

**Fallback ถ้า sign-in anonymous fail** (เช่น toggle "Allow anonymous sign-ins" ถูกปิดใน Supabase, หรือ network error): แสดง `WelcomeScreen` ตามปกติ ไม่ค้างที่ loading spinner ตลอดไป

**Risk ที่ระบุไว้ก่อนหน้า** ("การเพิ่ม route parsing อาจกระทบ guest-browsing เดิม/initial-route ของ AuthGate"): ไม่กระทบ เพราะไม่ได้แก้ ordering หรือ logic ของ gate ใดๆ ที่มีอยู่ก่อนหน้า `session == null` branch เลย — เพิ่มแค่ branch ใหม่ *ก่อน* จุดที่เดิมคืน `WelcomeScreen` ตรงๆ เท่านั้น โค้ด/เทสต์เดิมทั้งหมดของ AuthGate ไม่เปลี่ยนพฤติกรรม (ยืนยันด้วย full regression suite)

Handoff: AI Coding (implement ตาม flow ด้านบน) → AI QA & Security

## AI Coding Output (Requirement 2)

**ไฟล์ที่แก้**:
- `app/lib/core/navigation/deep_link_service.dart`: เพิ่ม `DeepLinkService.hasContentPath()` (static, `kIsWeb`-guarded, อ่าน `Uri.base.path` เช็ครูปแบบเดียวกับที่ `_handle()` ใช้ตัดสินใจ navigate แต่ไม่ navigate เอง) + test-only seam `debugForceHasContentPath` (เพราะ `kIsWeb`/`Uri.base` บังคับไม่ได้จาก widget test ที่ target ไม่ใช่ web — ข้อจำกัดเดียวกับที่ `debugHandlePath` มีอยู่แล้วสำหรับ `handleInitialLink()`)
- `app/lib/features/auth/presentation/auth_gate.dart`: เพิ่ม branch ใน `session == null` — ถ้า `DeepLinkService.hasContentPath()` เป็น true และยังไม่เคยลองมาก่อน เรียก `_startGuestSessionForDeepLink()` (เรียก `_authRepository.signInAnonymously()`, catch error แล้ว fallback `WelcomeScreen`) แทนที่จะ return `WelcomeScreen` ทันที
- `app/test/support/recording_auth_repository.dart`: เพิ่ม `signInAnonymously()` override (emit `signedIn` ด้วย anonymous session ปลอม) + `signInAnonymouslyCalls`/`signInAnonymouslyError` สำหรับเทสต์
- `app/test/auth_gate_test.dart`: เพิ่ม group "WYN-119 -- guest deep-link Anonymous Sign-In fallback" (3 เคส: content path → anonymous sign-in → RootShell, non-content path → WelcomeScreen ตามเดิมไม่แตะ signInAnonymously, sign-in fail → fallback WelcomeScreen ไม่ค้าง spinner)
- `app/test/deep_link_service_test.dart`: เพิ่ม 2 เคสสำหรับ `hasContentPath()`/`debugForceHasContentPath` เอง

**ไม่แตะ**: `RootShell`, `DeepLinkService._handle()`/`handleInitialLink()` เดิม (ของ session คู่ขนานที่ทำ Requirement 1,3 ไว้แล้ว), `guest_gate.dart`, Tier 1 (`vercel.json`/โดเมน share-link)

**ผลทดสอบ**: `flutter analyze` สะอาด (0 issues, 5 ไฟล์ที่แก้) — ผล `flutter test` เต็ม suite รอ QA ยืนยันในหัวข้อถัดไป

Handoff: AI QA & Security

## AI QA & Security Output

**Functional (Acceptance Criteria)**:
- เปิด `/club/<id>`, `/drop/<id>`, `/club-post/<id>`, `/@username` จากเบราว์เซอร์ที่ไม่เคย login เลย (`session == null`): ตรวจโค้ดยืนยันแล้วว่า flow ใหม่เข้าทางเดียวกับปุ่ม "เข้าชม WYNOS ได้เลย" (WYN-072) ทุกจุด ไม่มี branch ใหม่ที่ bypass gate ใดๆ ที่มีอยู่ — session ที่ได้เป็น anonymous เดียวกันเป๊ะ ผ่าน `session.user.isAnonymous` check เดิมที่มีอยู่แล้วก่อนงานนี้ (ไม่ได้แก้ ordering ของ moderation/document-acceptance gate เลย ตามที่ Design ระบุ)
- Path ที่ไม่ตรง pattern (`/`, path แปลกปลอม) — `hasContentPath()` return false, ไม่เรียก `signInAnonymously()` เลย, พฤติกรรมเดิม (`WelcomeScreen`) ไม่เปลี่ยน — ยืนยันด้วยเทสต์ "a signed-out visitor on an ordinary URL"
- Sign-in anonymous ล้มเหลว (เช่น toggle ปิดใน Supabase, network error) — fallback `WelcomeScreen` ไม่ค้าง spinner ตลอดไป — ยืนยันด้วยเทสต์ "a failed Anonymous Sign-In"
- Id ไม่มีอยู่จริง (drop/club-post ถูกลบไปแล้ว) — ใช้ `DeepLinkService._handle()` เดิมที่ทำไว้แล้วจาก Requirement 1 (fallback เงียบๆ ไม่ crash) ไม่ถูกแตะจากงานนี้เลย ยังทำงานเหมือนเดิมสำหรับทั้ง guest และ authenticated user

**Regression**: `flutter analyze` 0 issues (5 ไฟล์ที่แก้). `flutter test` เต็ม suite: **1326/1326 ผ่าน** (รวม 3 เคสใหม่ในกลุ่ม "WYN-119 -- guest deep-link Anonymous Sign-In fallback" + 2 เคสใหม่ใน `deep_link_service_test.dart` สำหรับ `hasContentPath()`) ไม่มี regression ในเทสต์เดิมทั้ง 22 เคสของ `auth_gate_test.dart` เอง (moderation gate ordering, document-acceptance gate, account-switcher fix, RootShell keying ฯลฯ ยังผ่านครบ)

**Security**:
- ไม่มี RLS/permission surface ใหม่ — anonymous session ที่สร้างจาก deep-link เป็น session ชนิดเดียวกับที่ WYN-072 อนุมัติไปแล้วทุกประการ (`auth.uid()` จริง, RLS บังคับใช้ปกติทุกจุด, `guest_gate.dart`'s `requireRealAccount()` ยังกัน join/like/comment เหมือนเดิมทั้งหมด) — ตรวจโค้ดยืนยันว่าไม่มีจุดใดข้าม gate นี้
- **ข้อสังเกต (ไม่ block)**: การ auto-trigger anonymous sign-in โดยไม่ต้องกดปุ่มเอง ทำให้ bot/crawler ที่เข้าถึง URL รูปแบบ `/club/<id>` จำนวนมากสร้าง anonymous session ได้ง่ายกว่าเดิมเล็กน้อย (เดิมต้องกดปุ่มก่อน) — ความเสี่ยงเดียวกับที่ WYN-072 เดิมยอมรับไปแล้ว (ปุ่มเปิดสาธารณะไม่มี CAPTCHA) เพิ่มแค่ friction ที่ลดลง ไม่ใช่ capability ใหม่ ไม่มี PII/ข้อมูลใดถูกเปิดเผยเพิ่มจากที่ RLS อนุญาตอยู่แล้ว — Supabase's own Auth rate-limiting เป็นชั้นป้องกันที่มีอยู่แล้วนอกเหนือจากโค้ดนี้ ถือว่ายอมรับความเสี่ยงนี้ได้เหมือนที่ WYN-072 เคยอนุมัติไว้ ไม่ใช่ประเด็นใหม่ที่ต้อง block งานนี้

**Verdict: PASS** — Acceptance Criteria ครบทั้ง 3 ข้อ, ไม่มี regression, ไม่มีช่องโหว่ security ใหม่ ระดับ blocking

Handoff: AI Deploy & DevOps (ไม่มี schema เปลี่ยนแปลง ไม่ต้อง apply DB ใดๆ — เป็น client-side Dart ล้วน พร้อม deploy ผ่าน `deploy-web.yml` ตามปกติ)
