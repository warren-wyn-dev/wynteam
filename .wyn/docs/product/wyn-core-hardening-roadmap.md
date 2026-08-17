# Roadmap — WYN Core 3 Pages Hardening (Home / Drop / Profile)

Owner: AI Product Manager
สถานะ: Phase 0 Audit เสร็จแล้ว — รอ Founder ตัดสินใจลำดับก่อนส่งต่อ AI Design/Coding
วันที่: 2026-08-17

## บริบท

Founder ส่ง master prompt ยาว 67 หัวข้อ ("WYN — ULTIMATE CORE 3 PAGES MASTER PROMPT") สั่งให้ทำ Home/Drop/Profile ให้แข็งแกร่งที่สุด โดยระบุไว้เองว่า **Phase 0 ต้อง Audit ก่อนแก้โค้ดใดๆ** และห้าม Rewrite/ห้ามสร้าง Fake Functionality/Fake Data/Fake Backend เอกสารนี้คือผล Audit + การ reconcile กับ task ที่มีอยู่แล้วในระบบ + roadmap สำหรับส่วนที่ยังขาดจริง

**หมายเหตุสำคัญ**: master prompt ใช้ศัพท์เทคนิคของ web stack (React/TypeScript, `npm run build`, ESLint) แต่ WYN เป็น **Flutter (Dart) mobile app + Supabase backend** (ไม่ใช่ web) — คำสั่ง Phase 7 (`npm run build`) ไม่ตรงกับ stack จริง จะแทนที่ด้วย `flutter analyze` / `flutter test` / `flutter build` ตาม convention เดิมของโปรเจกต์

## PHASE 0 AUDIT — สรุปผล

### Current Architecture
- Monorepo: `app/` (WYN Flutter app หลัก), `seller_app/` (ZOKY Sellers, แยกแอป), `supabase/` (schema.sql + RLS + storage + tests)
- Backend: Supabase จริง (Postgres + RLS ทุกตาราง + Storage buckets + DB trigger/RPC) — **แต่ยังไม่มี Supabase project จริงขึ้น production**, งานทั้งหมดผ่าน QA แค่ระดับโค้ด (`flutter analyze`/`flutter test`) ยังรอ AI Deploy & DevOps เมื่อมี infra จริง
- State/Data flow: Repository pattern ต่อ feature (`XRepository` เรียก Supabase ตรงๆ), ไม่มี state management library ภายนอก (ใช้ `StatefulWidget`/`FutureBuilder` เป็นหลัก), Optimistic UI pattern มีอยู่แล้ว (Like/Save/Follow) — revert เมื่อ request fail
- Feed รวม (`home_feed` view) และ Saved รวม (`saved_feed` view) ใช้ Postgres view UNION ALL แบบ `security_invoker = true` ให้ RLS เดิมยังบังคับใช้จริง — pattern นี้ reusable สำหรับ Content Type ใหม่ในอนาคต

### Existing Features (Home/Drop/Profile ที่เกี่ยวข้อง — ทั้งหมดผ่าน QA โค้ดแล้ว อยู่ใน `.wyn/tasks/approved/`)
- **Home**: Feed รวม Drop+Pop, 3 โหมด (สำหรับคุณ/ล่าสุด/จาก Club ของคุณ) ผ่าน `SegmentedButton`, ranking แบบ rule-based (`recencyScore + engagementScore(like×2+comment×3) + followingBoost(50)`), Trending row ("กำลังนิยม" — engagement 48 ชม.ล่าสุด), Recommended Clubs row, Search (User/Drop/Pop/Club, debounce 400ms), Notification bell+badge, pull-to-refresh + infinite scroll (offset-based)
- **Drop**: โพสต์รูปภาพ **1 รูปต่อโพสต์** (1:1 crop), Like/Comment(+reply 1 ชั้น)/Like Comment/ลบ Comment ตัวเอง/Share/Save/ลบ Drop ตัวเอง/Follow ผู้เขียน, Hashtag+Mention ในแคปชัน, 3 tab (For You/Following/Latest — reuse ranking เดียวกับ Home)
- **Profile**: ดู/แก้โปรไฟล์ตัวเอง (avatar/display name/bio), ดูโปรไฟล์คนอื่น+Follow/Unfollow, tab Drop grid/Pop grid/Saved (Saved เห็นเฉพาะเจ้าของ), Followers/Following list กดเปิดโปรไฟล์ได้จริง

### Existing Components (Reusable)
`DropGridTile`/`PopGridTile`/`SavedGridTile`, `HomeDropCard`/`HomePopCard`, `TrendingTile`, `ClubSection`, `FollowListScreen` (แถว reuse ใน Search/Follow), `MentionInput`, `relativeTimeLabel()`, optimistic-update pattern, `home_feed`/`saved_feed` view pattern, image_picker+square-crop flow

### Existing Backend Capabilities
Auth, Postgres+RLS ทุกตาราง, Storage buckets (`avatars`/`drop-images`/`pop-videos`/`club-media` non-public), DB trigger สำหรับ notification fan-out, RPC สำหรับ permission mutation ที่ซับซ้อน (Club), FCM push infra (WYN-016 ออกแบบแล้วแต่ยังไม่เริ่ม coding)

### Missing Backend Capabilities (ตรงกับ gap ด้านล่าง)
ตาราง multi-image ต่อ Drop, image-derivative pipeline (thumbnail/feed/fullscreen), ตาราง analytics event, ตาราง block/mute/report, Realtime channel (ยังไม่เคยใช้ Supabase Realtime ในแอปเลย), local cache/offline queue (ไม่มี Hive/sqflite/connectivity ใน `pubspec.yaml`)

### Existing Bugs
ไม่มีบั๊กเปิดค้างอยู่ — บั๊กทั้งหมดใน `.wyn/tasks/bugs/` ปิด (resolved+verified) แล้ว

### Technical Debt
- WYN-023 (Home/Drop polish — 3 minor finding เก่าจาก QA รอบก่อน) ออกแบบเสร็จตั้งแต่ 2026-08-16 ยังไม่ถูกส่ง AI Coding
- Pagination เป็น offset-based (`page*pageSize` + `.range()`) ไม่ใช่ cursor-based — ยอมรับได้ตอนนี้ (data น้อย, ยังไม่มี production traffic) แต่จะเป็นปัญหาเมื่อ data โตและมี insert ระหว่างเลื่อน feed (item ซ้ำ/หาย)
- WYN-017/WYN-018 ยังอยู่ใน `approved/` ไม่ใช่ `completed/` ทั้งที่โค้ดขึ้นจริงแล้ว — ไม่กระทบงานนี้ แต่ควรเก็บกวาด lifecycle folder ทีหลัง

### Risks
- ระบบทั้งหมดยัง**ไม่เคย deploy ขึ้น infra จริง** — งานที่เพิ่มในรอบนี้จะเจอชะตากรรมเดียวกัน (ผ่าน QA โค้ดแต่รอ deploy จริง) ไม่ใช่ปัญหาของรอบนี้ แต่ Founder ควรรู้ scope ของ "เสร็จ" คือ "โค้ด+QA พร้อม" ไม่ใช่ "ผู้ใช้จริงใช้ได้"
- Multi-image Drop (gap ใหญ่ที่สุด) ต้องแก้ schema (`drops` table) ที่มีข้อมูลเชื่อมโยงอยู่แล้ว (`drop_likes`/`drop_comments`/`drop_mentions`/`saves`) — ต้อง migration ที่ไม่ทำลายข้อมูลเดิม (additive: เพิ่มตาราง `drop_images` ใหม่ ไม่ลบคอลัมน์ `image_url` เดิมทันที เพื่อความปลอดภัย ดูรายละเอียดใน WYN-024)
- Block/Mute/Report ถ้าทำไม่ครบ (เช่น ลืม filter blocked user ออกจาก Search/Notification) จะเป็นช่องโหว่ privacy/safety จริง ต้องระวังเป็นพิเศษตอน QA

### Reusable Systems
ตามหัวข้อ Existing Components ด้านบน — ทุก task ใหม่ต้อง reuse ก่อนสร้างใหม่ตามกติกา RULES.md

---

## RECONCILE: master prompt เทียบกับของที่มีอยู่แล้ว

| หัวข้อ master prompt | สถานะ |
|---|---|
| Home feed tabs (For You/Following/Trending/Latest) | **มีแล้ว** (WYN-007/017/018/019 — รูปแบบ 3 โหมด+Trending row ไม่ใช่ 4 tab แยก แต่ตอบโจทย์เดียวกัน) |
| Smart Feed Engine (rule-based ranking) | **มีแล้ว** (WYN-018) — แต่สัญญาณน้อยกว่าที่ master prompt ขอ (ไม่มี share/bookmark/view/dwell time/not-interested) |
| Feed diversity (กันซ้ำ author ติดกัน) | **ไม่มี — Gap จริง** |
| Trending Engine | **มีบางส่วน** (WYN-017 — engagement สะสม 48ชม., ไม่ใช่ velocity/growth-rate) |
| WYN Trending Top 1-10 ใน Search | **ไม่มี — Gap จริง** (มี hashtag feed แยกแต่ไม่มี Top 10 list ใน Search) |
| Realtime trending (↑3/↓2) | **ไม่มี infra รองรับ (ไม่เคยใช้ Supabase Realtime)** — ตามกติกาห้ามอ้าง Realtime ถ้าไม่มีจริง จะไม่ทำ |
| Home Search + autocomplete/debounce | **มีแล้ว** (WYN-009) — ขาด recent searches |
| New Content Indicator ("N new Drops") | **ไม่มี — Gap จริง** |
| Infinite Scroll + Pull to Refresh | **มีแล้ว** (offset-based, ใช้ได้แต่ไม่ cursor-based) |
| Optimistic UI (Like/Bookmark/Follow) | **มีแล้ว** |
| Drop สูงสุด 9 รูป + Horizontal Row | **ไม่มี — Gap ใหญ่ที่สุด** (ปัจจุบัน 1 รูป/โพสต์เท่านั้น) |
| Image Viewer (zoom/swipe/counter) | **ไม่มี — Gap จริง** |
| Image Reorder ก่อน publish | **ไม่มี (ไม่มี multi-image ให้ reorder)** |
| Smart/Dynamic Image Compression | **มีบางส่วน** (fixed maxWidth/Height/quality85 — ไม่ dynamic ตามขนาดต้นฉบับจริง) |
| Responsive Image versions (thumb/feed/fullscreen) | **ไม่มี — Gap ใหญ่ (ต้องมี backend/storage เพิ่ม)** |
| Drop Draft | **ไม่มี — Gap จริง** |
| Comment/Reply (nested) | **มีแล้ว** (WYN-022 — 1 ชั้นตามที่ Product ตัดสินใจไว้แล้วด้วยเหตุผลชัดเจน) |
| Post Safety (Report/Block/Mute/Not Interested) | **ไม่มีเลย — Gap จริง สำคัญสำหรับ Gen Z platform** |
| Profile identity (avatar/cover/bio/website/username edit) | **มีบางส่วน** (avatar/display name/bio เท่านั้น — ไม่มี username edit/website/cover) |
| Pinned Post บน Profile | **ไม่มี** (pin มีแต่ใน Club post เท่านั้น) |
| Own/Other profile + Follow/Block/Mute/Report | **มีแค่ Follow** |
| Analytics event foundation | **ไม่มี — Gap จริง (แต่ตาม master prompt เองก็บอกว่าแค่เตรียม event ไม่ต้องทำหน้า Analytics)** |
| Offline/Cache | **ไม่มี infra รองรับ** — จะไม่ทำ fake offline system ตามกติกา |

---

## แผนงานที่เสนอ (WYN-023 ถึง WYN-031) — ขอบเขต Home/Drop/Profile เท่านั้น

เรียงตามลำดับความสำคัญที่แนะนำ (ดูเหตุผลในแต่ละ task ที่ `.wyn/tasks/backlog/`):

1. **WYN-023** (มีอยู่แล้ว, design เสร็จ) — Home/Drop polish 3 จุดเล็ก — **ทำก่อนเพราะ risk ต่ำสุด ของเดิมทั้งหมด**
2. **WYN-024** — Drop Multi-Image Core (สูงสุด 9 รูป, Horizontal Single-Line Row, Composer multi-select+reorder) — **priority สูงสุดของ Gap ใหม่ ตรงกับที่ Founder เน้นว่า "Requirement สำคัญที่สุด"**
3. **WYN-025** — Drop Image Viewer + Smart Compression (fullscreen zoom/swipe/counter, dynamic compression ตามขนาดต้นฉบับ) — ต่อยอด WYN-024
4. **WYN-026** — User Safety: Block / Mute / Report (Drop + Profile) — สำคัญสำหรับ platform Gen Z ตามที่ Vision ระบุไว้ใน CONTEXT.md
5. **WYN-027** — Home Feed Diversity + New Content Indicator
6. **WYN-028** — WYN Trending Top 1-10 (ใน Search) + Recent Searches
7. **WYN-029** — Profile Identity Expansion (username edit+validation, website, cover) + Pinned Drop Post
8. **WYN-030** — Drop Draft + Edit Caption
9. **WYN-031** — Analytics Event Foundation (schema เท่านั้น ไม่มีหน้า Analytics)

**นอกขอบเขตของแผนนี้โดยตั้งใจ** (ตาม Scope Lock ของ master prompt): Responsive image derivative pipeline (thumb/feed/fullscreen versions), Realtime trending, Offline/local cache, AI recommendation model จริง — ทั้งหมดนี้ **BACKEND REQUIRED** และ/หรือขัดกับกติกา "ห้ามสร้าง Fake Functionality" เพราะ infra ที่จำเป็น (Supabase Realtime wiring, image transform service, local DB) ยังไม่มีในโปรเจกต์ — บันทึกไว้เป็น Future Backlog ไม่ implement รอบนี้จนกว่า Founder จะอนุมัติให้เพิ่ม infra

## Recommendation

เสนอให้ AI Design เริ่มจาก WYN-023 (เร็ว, เสี่ยงต่ำ) ควบคู่กับเริ่ม Design ของ WYN-024 (Drop Multi-Image — งานใหญ่ที่สุดและ Founder เน้นมากที่สุด) จากนั้นทำตามลำดับ 025→031 ทีละ task ผ่าน pipeline เดิม (Design → Coding → QA อิสระ → approved) เหมือนทุก task ก่อนหน้า — **ไม่แนะนำทำทุก task พร้อมกันในคราวเดียว** เพราะแต่ละ task แตะ schema/RLS ของ Drop/Profile ซึ่งเป็นแกนกลางที่ Home/Drop/Profile ใช้ร่วมกันทั้งหมด ทำทีละ task + QA อิสระจริงจะลดความเสี่ยง regression ข้ามหน้าได้ดีที่สุด
