# Phase 0 Audit — WYN Core 3 Pages Hardening (Home / Drop / Profile)

Owner: AI Product Manager
Date: 2026-08-17
Trigger: Founder ส่ง "WYN — ULTIMATE CORE 3 PAGES MASTER PROMPT" (CORE PRODUCT HARDENING)
Scope of this document: **Phase 0 — Audit เท่านั้น ไม่มีการแก้โค้ดใดๆ ระหว่างทำเอกสารนี้** ตามที่ master prompt ระบุไว้ตรงๆ ("ห้ามแก้โค้ดระหว่าง Audit")

---

## หมายเหตุสำคัญก่อนเริ่ม: Tech Stack Mismatch ใน Master Prompt

Master prompt ที่ได้รับเขียนด้วยสมมติฐานว่าโปรเจกต์เป็น **React/TypeScript web app** (อ้างถึง `npm run build`, `npm run lint`, TypeScript errors, ESLint, React hydration error, Console/Browser DevTools, responsive breakpoint Desktop/Tablet)

**ความจริงของโปรเจกต์**: WYN เป็น **Flutter (Dart) mobile app** (`app/` — iOS/Android) เรียก **Supabase** (Postgres + Auth + Storage) ตรงๆ ผ่าน `supabase_flutter` — ไม่มี Next.js/React, ไม่มี `npm run build`, ไม่มี TypeScript/ESLint, ไม่มี Browser Console/Hydration error เพราะไม่ใช่เว็บแอป (ตัดสินใจนี้ยืนยันโดย Founder ตรงๆ ตั้งแต่ 2026-08-13 — ดู DECISIONS.md)

**การตีความของ AI Product Manager** (ไม่ใช่ Major Architecture change เพียงแค่แปล intent ของ prompt ให้ตรงกับ stack จริง เหมือนที่เคยทำกับ ZOKY Platform master prompt วันที่ 2026-08-14):

| สิ่งที่ Prompt ขอ (web/React) | เทียบเท่าจริงในโปรเจกต์ (Flutter) |
|---|---|
| `npm run build` | `flutter build apk`/`flutter build ios` (ยังไม่เคยรันสำเร็จในรอบก่อนๆ เพราะ sandbox ไม่มี Android SDK/Xcode — ต้องทำในเครื่อง dev/CI จริง) |
| `npm run lint` | `flutter analyze` |
| TypeScript errors | Dart compile errors (`flutter analyze` ครอบคลุมเทียบเท่า) |
| Console errors/warnings, Hydration error | ไม่มีแนวคิดนี้ใน Flutter — เทียบเท่าที่ใกล้ที่สุดคือ runtime exception ระหว่าง `flutter test`/manual testing และ Dart's `debugPrint`/`FlutterError.onError` |
| Desktop/Tablet responsive | WYN เป็น mobile-first ตามที่ Founder ยืนยันไว้แต่ต้น (2026-08-13) — ยังไม่มี target สำหรับ Desktop/Web build เลยในสถาปัตยกรรมปัจจุบัน — จะถือว่าข้อนี้ยังไม่เกี่ยวข้องจนกว่า Founder จะสั่งเพิ่ม platform |

ส่วนที่เหลือของ prompt (Home/Drop/Profile requirements, Data Integrity, No Fake Functionality, Backend Dependency Rule ฯลฯ) แปลได้ตรงๆ ไม่มีปัญหา เพราะเป็นหลักการที่ไม่ผูกกับ framework

---

## 1. CURRENT ARCHITECTURE

- **Frontend**: Flutter (Dart) 3.47.0 stable, Material 3, `ThemeMode.system` (light/dark ตามเครื่อง) — 2 แอปแยกกันในโมโนรีโป้เดียวกัน ไม่มี monorepo tooling (ไม่มี Melos): `app/` (WYN Social + ZOKY Marketplace + WYN Club ทั้งหมดเป็น feature module เดียว) และ `seller_app/` (แอปแยกสำหรับร้านค้า ใช้ backend เดียวกัน)
- **Backend**: Supabase project จริง (`akawuzukstmbztyajxsr`) — Postgres + Auth + Storage ใช้งานอยู่ ผ่าน `supabase_flutter` เรียกตรงจาก client ไม่มี custom backend server เลย — Edge Functions มีใช้แค่จุดเดียว (`send-push-notification`, Deno)
- **Security model**: Row Level Security (RLS) เป็น security boundary หลักของทุกตาราง + `security definer` RPC function สำหรับ permission graph ที่ซับซ้อนเกินกว่า RLS policy ตรงๆ จะปลอดภัย (เช่น Club role management, Pop view-count)
- **State management**: StatefulWidget ธรรมดา + Repository pattern ต่อ feature (ไม่มี Provider/Riverpod/Bloc/GetX) — แต่ละ feature มี `XxxRepository` class ห่อ Supabase call ของตัวเอง
- **Routing**: `Navigator.push`/`MaterialPageRoute` + `IndexedStack` สำหรับ Bottom Nav 5 แท็บ (`RootShell`) — ไม่มี named routes/go_router/deep linking จริง (ลิงก์ share เป็น placeholder `https://wyn.app/<type>/<id>` ที่ยังเปิดไม่ได้จริง เพราะยังไม่มี domain จริง)
- **Auth**: Supabase Auth — Google OAuth + Apple OAuth + Phone OTP (อนุมัติโดย Founder 2026-08-13) **บวก Anonymous Sign-In ชั่วคราว** (เพิ่มเข้ามา 2026-08-16 เพื่อให้ทดสอบแอปได้ก่อน Founder จะสมัคร Google/Apple/Twilio account จริง — ต้อง revert เป็นบังคับ Google/Apple/Phone ก่อน public launch)
- **Design System**: Cyan `#00C8FF` (accent เท่านั้น) + Black/White/Gray, ZOKY layer แยก identity เป็น Orange `#FF6B35` — ตัดสินใจ 2026-08-15 (DS-001 ถึง DS-008) แทนที่ direction เดิม (Blue+White+Soft Gray)
- **Testing**: 362 automated `flutter test` ผ่านทั้งหมด (ไม่มี failing test ค้าง), `flutter analyze` สะอาด — **ไม่มี CI ที่รัน test อัตโนมัติบน PR เลย** (ทุกรอบ QA ต้องรันเองด้วยมือ ยืนยันด้วยตัวเองทุกครั้ง)
- **Deploy status**: **ยังไม่เคย deploy ขึ้น TestFlight/Play Store จริงแม้แต่ครั้งเดียว** — เป้าหมายแรกคือ Internal Testing (อนุมัติโดย Founder 2026-08-13) ไม่ใช่ public release — `flutter build apk`/`flutter build ios` ยังไม่เคยรันสำเร็จเพราะ sandbox ที่พัฒนาไม่มี Android SDK/Xcode ให้ build จริง

---

## 2. EXISTING FEATURES (เฉพาะ Home / Drop / Profile)

### Home
- Search bar จริง (ไม่ใช่ placeholder) — User/Drop/Pop/Club 4 tab, debounce 400ms
- กระดิ่ง Notification พร้อม badge นับ unread (cap "9+")
- ClubSection: แถว "Club ของฉัน" + แถว "Club แนะนำ" (โผล่เมื่อ join Club น้อยกว่า 3 อัน)
- แถว Trending: Drop/Pop engagement สูงในช่วง 48 ชม.ล่าสุด (คำนวณจาก `like_count + comment_count`, client-side sort ของ candidate window)
- Feed หลัก: รวม Drop+Pop, สลับโหมดได้ 3 แบบ — "สำหรับคุณ" (ranked), "จาก Club ของคุณ", "ล่าสุด" (chronological)
- Card มี Like/Comment/Share/Save + แตะเปิดรายละเอียดตามประเภท, แตะ avatar/ชื่อไปโปรไฟล์คนโพสต์

### Drop
- โพสต์รูปภาพ **1 รูปต่อโพสต์เท่านั้น** (ดูหัวข้อ Existing Bugs/Technical Debt — นี่คือ gap สำคัญที่สุดของ audit นี้) 1:1 crop + caption + hashtag/mention (พิมพ์แล้วบันทึกได้ แตะแล้วไปหน้าค้นหา/โปรไฟล์ได้จริง)
- Drop tab: For You/Following/Latest (3 tab, reuse การ์ดเดียวกับ Home), grid view ย้ายไปอยู่ที่ Profile เท่านั้น
- Like/Comment (+ Reply 1 ชั้น)/Share (placeholder link)/Save/Follow ผู้เขียน/ลบ Drop ของตัวเอง
- **ไม่มี**: edit caption หลังโพสต์, multi-image, image zoom/fullscreen viewer, draft persistence

### Profile
- Avatar (upload/edit ได้), Display Name, Bio (160 ตัวอักษร), Follower/Following count (กดดูรายชื่อได้)
- Tab: Drop grid / Pop grid / Saved (เห็นเฉพาะ profile ตัวเอง) — **ไม่มี Liked tab**
- Own profile: ปุ่ม Edit Profile + Logout / Other profile: ปุ่ม Follow-Following toggle
- Username ตั้งครั้งเดียวตอน onboarding เท่านั้น — **ไม่มีหน้าจอแก้ username ภายหลัง**

---

## 3. EXISTING COMPONENTS (Reusable ที่เกี่ยวข้องกับ Home/Drop/Profile)

- `HomeDropCard` — การ์ด Drop มาตรฐาน reuse ทั้ง Home feed และ Drop feed 3 tab (WYN-007/WYN-019)
- `DropGridTile` / `PopGridTile` — grid tile มาตรฐาน reuse ทั้ง Profile และ Search results
- `FollowListScreen` row layout — reuse เป็นฐานให้ `NotificationListScreen`, `SearchScreen`'s User tab
- `HashtagText` — render+เปิด hashtag/mention ที่กดได้ ใช้ร่วมกันทุก content type
- `relativeTimeLabel()` (`core/text_utils.dart`) — ใช้แล้วใน Notification/Club post/ZOKY order-review (Drop/Home **ยังไม่ใช้** — ค้างเป็น WYN-023 R1)
- `home_ranking.dart`'s `rankingScore()` — pure function แยกไฟล์ มี unit test 8 ตัว, reuse ทั้ง Home's "สำหรับคุณ" และ Drop's "For You" (WYN-018 follow-up)
- `WynTheme` (light/dark) + Design tokens ใน `core/design/` — ใช้ร่วมกันทั้งแอป

---

## 4. EXISTING DATA FLOW

Client (Flutter) → `XxxRepository` → `supabase_flutter` client → Supabase (Postgres RLS / Storage / Auth) โดยตรง ไม่มี middleware/backend-for-frontend คั่นกลาง

Pattern การอ่าน Feed: fetch bounded candidate window (เช่น `pageSize * 10` = 210 แถวล่าสุด) → sort/rank ฝั่ง client (เพราะ PostgREST สั่ง `order()` ด้วย computed expression ไม่ได้) → ไม่ใช่ true full-corpus ranking query ระดับ database

Pattern การเขียน: ส่วนใหญ่เป็น direct insert/update ผ่าน RLS policy ธรรมดา ยกเว้นจุดที่ permission ซับซ้อน (Club role, Pop view count) ใช้ `security definer` RPC แทน

**ไม่มี Realtime subscription ที่ไหนในแอปเลย** — ทุกอย่างเป็น fetch-then-display + manual refresh/optimistic update ล้วนๆ (grep `.channel(`/`realtime` ทั่วทั้ง `app/lib` ไม่เจอเลยสักจุด)

---

## 5. EXISTING BACKEND CAPABILITIES

- **Storage buckets**: `avatars` (public), `drop-images` (public), `pop-videos` (public), `club-media` (**private** — ใช้ signed URL เพราะโพสต์ Club ต้องเห็นเฉพาะสมาชิก), `product-images` (public), `store-media` (public)
- **`saves` table** รองรับ bookmark หลาย content type อยู่แล้ว: `check (content_type in ('drop','pop','club_post'))` — โครงสร้างพร้อม reuse
- **Pop มี `view_count`** ผ่าน `security definer` RPC (`increment_pop_view_count`) — Drop **ไม่มี** view/impression tracking เลย
- RLS ครอบคลุมทุกตารางที่ตรวจสอบแล้ว (ผ่าน QA หลายรอบ รวม Club permission graph ที่เพิ่งแก้ security gap ไปเมื่อกี้ — WYN-021)
- Push Notification infra พร้อมแล้ว (FCM v1 + Database Webhook) แต่ยังบล็อกด้วย Founder ต้องสร้าง Firebase project เอง

---

## 6. MISSING BACKEND CAPABILITIES

ตาม "BACKEND DEPENDENCY RULE" ของ master prompt — รายการนี้คือ **BACKEND REQUIRED** สำหรับ requirement ที่ prompt ขอมา:

| Requirement ที่ Prompt ขอ | สถานะ Backend วันนี้ | ต้องเพิ่มอะไร |
|---|---|---|
| Drop สูงสุด 9 รูป | `drops.image_url` เป็น `text` เดี่ยว | ต้องเปลี่ยนเป็นตารางลูก `drop_images` (1-to-many) หรือ `text[]` + migration ของข้อมูลเดิม, เปลี่ยน Storage path convention |
| Draft persistence | ไม่มี local storage layer สำหรับ Drop composer เลย | Frontend-only ได้ (SharedPreferences/Hive) — **ไม่ต้องรอ Backend** แต่ต้องเพิ่ม dependency ใหม่ ถ้าต้องการ sync draft ข้ามอุปกรณ์ถึงจะต้องมี backend |
| Cover image / Website บน Profile | ไม่มี column ใน `profiles` เลย | เพิ่ม column ใหม่ (ไม่ destructive, เพิ่มอย่างเดียว) |
| Pinned Post | ไม่มี column/flag ใดๆ | เพิ่ม `is_pinned`/`pinned_at` ใน `drops` (และ/หรือ `pops`) + RLS ที่ตรวจสิทธิ์เจ้าของโพสต์เท่านั้น |
| Block / Mute / Report | ไม่มีตาราง ไม่มี UI เลยแม้แต่จุดเดียว | ต้องสร้างตารางใหม่ทั้งหมด (`blocks`, `mutes`, `reports`) + RLS ที่ต้องกรอง feed/search/notification ตาม block list — **นี่คือ scope ใหญ่สุดจุดหนึ่งของ prompt ทั้งฉบับ** กระทบเกือบทุก query ที่ query content |
| Analytics events (profile_view, post_view, ฯลฯ) | ไม่มี event table เลย มีแค่ Pop's view_count เดี่ยวๆ | ต้องออกแบบ event table ใหม่ (volume สูง ต้องคิดเรื่อง partitioning/retention ตั้งแต่ต้น) |
| Trending Engine แบบ velocity-based | มีแค่ 48h engagement sum ธรรมดา (WYN-017) ไม่มี growth-rate/velocity | ต้องมี time-series ของ engagement (ไม่ใช่แค่ snapshot ปัจจุบัน) ถึงจะคำนวณ velocity/growth ได้จริง |
| Realtime feed indicator ("↑ 12 new Drops") | ไม่มี Realtime subscription ใช้งานเลย | เปิดใช้ Supabase Realtime (มีอยู่แล้วในแผน Supabase ไม่ต้องซื้อเพิ่ม) แต่ต้องออกแบบ client-side listener ใหม่ทั้งหมด |
| Username edit หลัง onboarding | Repository มี `isUsernameAvailable` อยู่แล้ว (reuse ได้) | ไม่ต้องเพิ่ม backend ใหม่ แค่เปิด UI ให้แก้ได้ — เป็น Frontend-only งานเล็ก |
| Responsive Image Versions (Thumbnail/Feed/Fullscreen) | Storage เก็บไฟล์เดียวต่อรูป ไม่มี multi-resolution | ต้องมี image-processing pipeline (Edge Function หรือ Storage transform) — Supabase Storage มี image transformation API ในตัวสำหรับบาง plan ต้องตรวจสอบ plan ปัจจุบันก่อน |

---

## 7. EXISTING BUGS

- **ยังไม่พบ regression/known bug ที่เปิดค้างอยู่ในขอบเขต Home/Drop/Profile ตอนนี้** — WYN-021 (ช่องโหว่ RLS ของ `club_post_mentions`) เพิ่งแก้และผ่าน QA รอบ 2 ไปหมาดๆ (อยู่ใน `.wyn/tasks/approved/` แล้ว ไม่ใช่ open bug อีกต่อไป)
- Drop image "compression" ปัจจุบันจบด้วยการ re-encode เป็น **PNG** หลัง crop (`square_crop.dart`) ซึ่งมักได้ไฟล์ใหญ่กว่า JPEG คุณภาพเทียบเท่า — ไม่ใช่ bug ที่ทำให้พัง แต่ขัดกับเป้าหมาย "Smart/Dynamic Image Compression" ของ prompt ตรงๆ ควรถือเป็นสิ่งที่ต้องแก้ในรอบ Drop hardening

---

## 8. TECHNICAL DEBT

1. **WYN-023 ค้างอยู่ใน backlog** (self-contained, design เสร็จแล้ว รอ AI Coding) — 3 จุดเล็กที่ QA เจอมาหลายวันแล้วไม่เคยถูกหยิบมาแก้: ไม่มี timestamp บนการ์ด Drop, กด Comment บนการ์ด Pop ของ Home ต้องผ่านหน้าคลิปก่อน, empty state ของ "จาก Club ของคุณ" ไม่มีปุ่ม "สำรวจ Club" — ควรทำคู่ขนานกับ initiative นี้เพราะเสี่ยงต่ำและใช้ของเดิมทั้งหมด
2. **Push Notification (WYN-016)** ยังไม่ได้ verify ส่งจริง เพราะรอ Founder สร้าง Firebase project — ไม่กระทบ Home/Drop/Profile โดยตรง แต่เกี่ยวโยงกับ engagement loop ที่ prompt เน้น
3. **ไม่มี CI test suite รันอัตโนมัติบน PR** — ทุกรอบ QA ต้องรันเองด้วยมือทุกครั้ง (verified ตลอดหลาย task ที่ผ่านมา) — ยิ่ง scope ใหญ่ขึ้นเท่า initiative นี้ ความเสี่ยงที่จะไม่ตรวจพบ regression ก็ยิ่งสูงขึ้นถ้าไม่มี automation
4. **Auth ปัจจุบันพึ่ง Anonymous Sign-In ชั่วคราว** — ถ้า initiative นี้ต้องทดสอบ flow จริงจัง (โดยเฉพาะ Block/Mute/Report ที่ผูกกับตัวตนผู้ใช้) ต้องคำนึงว่า user จริงยังไม่ผ่าน OAuth/Phone verification เต็มรูปแบบ
5. **ไม่มี deep linking จริง** — Share link เป็น placeholder `https://wyn.app/...` เปิดไม่ได้จริง กระทบ engagement loop ที่ prompt ต้องการ (เช่น แชร์โพสต์แล้วให้เพื่อนเปิดตรงเข้าโพสต์นั้น)

---

## 9. RISKS

- **Drop multi-image (สูงสุด 9 รูป) คือ Breaking Schema Change** ของตารางที่มีข้อมูลอยู่แล้ว (`drops.image_url` เดี่ยว) — ทุก Drop เก่าที่มีอยู่ต้อง backward-compatible กับโครงสร้างใหม่ (migrate เป็น 1-image-array หรือคง column เดิมไว้เป็น fallback) กระทบไฟล์ที่ผ่าน QA แล้วจำนวนมาก: `HomeDropCard`, `DropDetailScreen`, `DropGridTile`, `ProfileDropGridTab`, ทุก repository ที่ query `drops` — ความเสี่ยง regression สูงสุดของ initiative นี้ทั้งฉบับ
- **Block/Mute/Report กระทบทุก query ที่ดึง content** (Home feed, Drop feed, Search, Notification, Profile) เพราะต้อง filter คนที่ถูก block ออกทุกจุด — เป็นงาน cross-cutting ขนาดใหญ่ ไม่ใช่ feature เดี่ยวๆ
- **Ranking/Trending Engine ที่ซับซ้อนขึ้น** (Interest Score, Quality Score, Spam Score, Repetition Penalty, Velocity) เสี่ยงต่อ Home feed หลักที่เพิ่งผ่าน QA ไปหมาดๆ (WYN-018) — ต้อง lock สูตรกับ Founder ก่อนเหมือนที่ทำมาแล้วครั้งก่อน ไม่ควร rewrite ranking ทั้งระบบรวดเดียว
- **Analytics event table ใหม่มี volume สูง** — ถ้าออกแบบผิดตั้งแต่ต้น (ไม่คิดเรื่อง partitioning/index) จะกระทบ performance ของทั้งระบบภายหลัง
- **ไม่มี CI** หมายความว่ายิ่งงานใหญ่เท่า initiative นี้ (หลาย task ต่อเนื่องกันหลายสัปดาห์) ยิ่งต้องพึ่งวินัยของแต่ละ QA round ในการรัน test เองทุกครั้ง ไม่มี safety net อัตโนมัติ

---

## 10. REUSABLE SYSTEMS

- Multi-image upload pattern **มีต้นแบบอยู่แล้ว** ใน `club_post_repository.dart` (loop upload หลายรูปต่อโพสต์) — ใช้เป็นฐานให้ Drop's 9-image feature ได้เลย ไม่ต้องคิดใหม่จากศูนย์
- `HomeDropCard`/`rankingScore()`/`relativeTimeLabel()`/`HashtagText` — ของเดิมทั้งหมดพร้อม reuse ตรงตามหลัก "Reuse Existing Architecture" ของ prompt
- `saves` table's multi-content-type design พร้อมขยาย (แค่เพิ่มใน CHECK constraint)
- Signed-URL pattern ของ `club-media` bucket — พร้อมเป็นต้นแบบถ้า Block/Report ต้องการเก็บหลักฐาน private
- `security definer` RPC pattern (Club role, Pop view-count) — พร้อมเป็นต้นแบบให้ Pin/Block/Report ที่ permission ซับซ้อนกว่า RLS ตรงๆ จะรองรับได้ปลอดภัย

---

## 11. RECOMMENDED IMPLEMENTATION ORDER

เรียงตาม risk/value ratio (ของเสี่ยงต่ำ-คุณค่าชัดเจนก่อน ของเสี่ยงสูง-กระทบกว้างทำท้ายและต้องผ่าน design/lock formula กับ Founder ก่อนเริ่ม):

1. **WYN-023 (ของที่ค้างอยู่แล้ว)** — ทำให้เสร็จก่อนเริ่มของใหม่ ความเสี่ยงต่ำสุด ใช้ของเดิมทั้งหมด
2. **Profile hardening ที่ไม่กระทบ schema กว้าง**: Cover image, Website field, Username edit — additive columns ล้วนๆ ความเสี่ยงต่ำ
3. **Drop composer polish ที่ไม่ต้องเปลี่ยน schema**: PNG→JPEG compression fix, Draft persistence (local-only), Image zoom/fullscreen viewer — คุณค่าสูง ความเสี่ยงต่ำ ไม่แตะ `drops` table
4. **Drop multi-image (สูงสุด 9 รูป) + Horizontal Row rendering** — งานใหญ่สุดของ Drop ต้องออกแบบ schema migration ให้รอบคอบก่อน แนะนำแยก sub-phase: (ก) schema+repository ก่อน (ข) composer UI (ค) feed/detail rendering แยกกันเพื่อลด blast radius ต่อ PR
5. **Pinned Post** — ต่อยอดจาก multi-image ได้เลยเพราะกระทบ `drops`/`pops` table ชุดเดียวกัน ทำพร้อมกันประหยัดรอบ QA
6. **Block / Mute / Report** — งาน cross-cutting ใหญ่สุด ควรทำแยกเป็นชุดของตัวเองหลังจากอย่างอื่นเสถียรแล้ว เพราะกระทบทุก query ของระบบ
7. **Home Feed Diversity + Trending Engine แบบ velocity-based + Analytics Event Foundation** — ต้อง design event schema ให้ดีก่อน ทำท้ายสุดเพราะเป็นฐานให้ Ranking ที่ซับซ้อนขึ้นในอนาคต ไม่ใช่ blocker ของอะไรตอนนี้
8. **Realtime feed indicator + Realtime Trending** — รอจนกว่า Analytics/Trending Engine ข้อ 7 นิ่งก่อน เพราะต้องมีข้อมูลที่ realtime ไปแสดงอยู่แล้ว

**Non-goals ของรอบนี้ตาม prompt เอง**: Club/Pop/Chat/Marketplace ไม่ถูกแตะเลย (ถูกต้องตามที่ scope lock ระบุ — โปรเจกต์นี้เพิ่งลงทุนกับ Club ไปมากใน WYN-014/015/017/020/021 จึงไม่ใช่การ "ลืม" แต่เป็นการเลือกโฟกัสตามคำสั่ง)
