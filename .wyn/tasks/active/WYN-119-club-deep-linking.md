# Product Task — WYN-119

Status: active
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
