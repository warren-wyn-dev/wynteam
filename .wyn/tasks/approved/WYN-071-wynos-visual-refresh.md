# Product Task — WYN-071

Status: DEPLOYED (2026-08-25) — live ที่ https://web-neon-sigma-66.vercel.app (deploy run 32841558301 -- run 32837045512 ก่อนหน้าลงผิด Vercel project, ดู CORRECTION ใน deploy log) ดูรายละเอียดเต็มที่ `.wyn/logs/deployments/2026-08-25-wyn-071-064-065-real-deploy.md`
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security → (รอ AI Deploy & DevOps)

Feature: WYNOS Visual Refresh — Light/Premium Design Direction + Profile/Feed/Drop/Bottom Nav Alignment

Goal: จัดโครงสร้าง UI/UX ของ WYNOS ให้รู้สึกเป็น social platform ระดับใหญ่ (premium, clean, มี identity ของตัวเอง ไม่ใช่ clone) ตาม direction ใหม่ที่ Founder ส่งมา โดยใช้ของเดิมที่มีอยู่แล้วให้มากที่สุดก่อนสร้างใหม่

Target User: ผู้ใช้ WYNOS ทุกคน — เป็นงานปรับ visual/structural ทั้งแอป ไม่ใช่ฟีเจอร์เดียว

Problem: Founder ส่ง spec ยาวมาผ่าน `/product` ระบุว่า "ใช้ภาพอ้างอิงที่แนบมาเป็นแรงบันดาลใจ" — **แต่ตรวจสอบ conversation แล้วไม่พบไฟล์ภาพแนบมาจริงในข้อความนี้ (มีแต่ข้อความ spec ล้วน)** จึงวิเคราะห์และเขียน requirement นี้จากข้อความ spec เท่านั้น ยังไม่เห็นภาพอ้างอิงจริง — **ต้องขอ Founder ยืนยัน/แนบภาพใหม่ก่อน AI Design เริ่มงานจริง** เพราะ "ห้ามลอกดีไซน์แอปต้นแบบโดยตรง" หมายความว่ามีภาพอ้างอิงที่ต้องระวังอยู่จริง แต่ AI ยังไม่เคยเห็น

ตรวจสอบ codebase ปัจจุบันก่อนเขียน spec (ตาม RULES.md "ตรวจสอบก่อนเสมอ") พบว่า**หลายส่วนของ spec นี้ตรงหรือใกล้เคียงกับของที่มีอยู่แล้วมาก**:

- **สี**: `WynColors` (DS-001, Founder อนุมัติแล้ว 2026-08-15) มี Cyan `#00C8FF` เป็น primary ทั้ง light/dark scheme ตรงกับ spec เป๊ะ, `socialLightScheme` มีพื้นหลังขาว (`white`)/ตัวอักษรดำ (`ink` #0A0A0A) อยู่แล้วครบ, การ์ด flat ไม่มีเงา (Threads-style, DS-002) ตรงกับ "clean, minimal" อยู่แล้ว — **ธีมสว่างที่ Founder อยากได้มีอยู่แล้วจริง ไม่ใช่ของใหม่**
- **Theme Mode ปัจจุบัน**: `main.dart` ตั้ง `themeMode: ThemeMode.system` (ตามการตั้งค่าเครื่องผู้ใช้ ไม่ได้ fix เป็น dark) — ถ้า Founder อยากให้แอปแสดงพื้นหลังขาวเป็นค่าเริ่มต้นเสมอ (ไม่ใช่ตามเครื่อง) ต้องเปลี่ยนเป็น `ThemeMode.light` ตรงๆ ซึ่งเป็นการตัดสินใจ Product ที่ต้อง Founder ยืนยันเอง (ผู้ใช้ที่ตั้งเครื่องเป็น dark mode จะเห็น WYNOS เป็น dark ต่อไปถ้าไม่ fix)
- **Bottom Navigation**: ปัจจุบันมีอยู่แล้ว 5 tab — Home / Search / Drop(ปุ่มสร้างโพสต์เด่น) / Notifications / Profile — ใกล้เคียง spec มาก (spec ไม่มี tab Search แยก เพราะย้าย Search ไปเป็นไอคอนบนแถบบนของ Home แทน)
- **Recommendation Algorithm**: WYN-063 (Unified Home Feed Algorithm, เสร็จและ deploy แล้ววันนี้) มี weighted scoring ครบ (Personalized Interest/Following/Engagement/Trending/Recency/Discovery) และมี `feed_diversity.dart` กันไม่ให้ account เดิมโผล่ซ้ำเกินไปอยู่แล้ว — **ตรงกับ requirement ส่วน Recommendation Algorithm ของ spec นี้เกือบทั้งหมด** ขาดแค่สัญญาณ "เปิดดูนาน" (dwell time) ที่ยังไม่มีการเก็บข้อมูลนี้เลยในระบบ
- **Repost**: มีอยู่แล้วในชื่อ "ReDrop" (WYN-034) — เป็น concept เดียวกัน แค่ label ภาษาอังกฤษต่างกัน

**ส่วนที่เป็นของใหม่จริง (gap ที่ไม่มีอยู่ในระบบเลย)**:
1. Drop รองรับหลายรูป (1–9 รูป, grid) — ปัจจุบัน Drop รองรับแค่ 1 รูปต่อโพสต์เท่านั้น (แม้จะมี text-only จาก WYN-062 แล้วก็ตาม)
2. Recommendation Section บน Profile ("แนะนำสำหรับคุณ", horizontal card, ปุ่ม X ซ่อน) — ไม่มีอยู่บน Profile เลยตอนนี้ (มีแค่บน Home)
3. Profile Tabs ใหม่ (Posts/Replies/Media/Likes) — ต่างจาก taxonomy ปัจจุบัน (Drop/ReDrop/Saved/Draft, Pop ซ่อนแล้วจาก WYN-066) โดยเฉพาะ **"Replies" และ "Likes" เป็น tab ที่ไม่เคยมีมาก่อนเลย** (ดู Requirement/Risk ด้านล่าง — มีประเด็น privacy ต้องตัดสินใจ)
4. Micro-interactions บางส่วนที่ยังไม่ยืนยันว่ามี: Follow animation, Tab transition, Haptic feedback — ต้องตรวจเพิ่มเติมทีละจุดตอน Design/Coding

**Founder ตัดสินใจแล้ว (2026-08-24, บันทึกใน DECISIONS.md)**: (1) ThemeMode fix เป็น Light เสมอ (2) Multi-image Drop ทำเป็นส่วนหนึ่งของงานนี้เลย (3) Replies/Likes tab เปิดสาธารณะเหมือน Twitter/X (4) **ได้ภาพอ้างอิงแล้ว (2026-08-24) — R1 ปลดล็อกแล้ว ไม่มีคำถามค้างอีกต่อไป**

**ภาพอ้างอิงที่ได้รับ**: screenshot หน้า Profile ของแอป **Threads (Meta)** วงสีแดงชี้ 2 จุด — (1) ส่วน "แนะนำสำหรับคุณ" horizontal card ใต้ปุ่ม Follow/ส่งข้อความ ตรงกับ R4 เป๊ะ (2) แถบ Tab (เธรด/การตอบกลับ/สื่อ/วีดีโอสด) + รายการโพสต์ใต้ tab ตรงกับ R5 (Posts/Replies/Media/...) — **ข้อสังเกต**: ภาพใช้ tab ที่ 4 เป็น "วีดีโอสด" (Live) ไม่ใช่ "Likes" แต่ spec ข้อความของ Founder ระบุ "Likes" ชัดเจน — ยึดตาม**ข้อความ spec เป็นหลัก** (Likes) เพราะภาพอ้างอิงเป็นแค่แรงบันดาลใจเชิงโครงสร้าง ไม่ใช่รายการที่ต้องลอกทุกจุด (ตรงกับกติกา "ห้ามลอกองค์ประกอบเฉพาะของแอปต้นแบบโดยตรง" ที่ Founder เขียนไว้เอง) — **AI Design ต้องออกแบบ visual ของ WYNOS เอง ไม่ใช้ icon/ font/ layout spacing ของ Threads ตรงๆ** ใช้แค่ตำแหน่ง/โครงสร้างเป็นแนวทาง (บนสุด: Back/Search/Notification/More, ใต้ header: Recommendation cards, ใต้นั้น: Tab bar + content list)

Requirements:
- R1. ~~ยืนยันภาพอ้างอิงกับ Founder~~ **เสร็จแล้ว** — ได้ภาพแล้ว (ดูรายละเอียดด้านบน)
- R2. **[ตัดสินใจแล้ว: Fix Light]** เปลี่ยน `app/lib/main.dart`: `themeMode: ThemeMode.system` → `ThemeMode.light` — ลบ/ปรับ `darkTheme:` ตามความเหมาะสม (คง `WynTheme.dark` ไว้ในโค้ดเผื่ออนาคตหรือลบไปเลยก็ได้ แล้วแต่ AI Design/Coding ตัดสินใจ ไม่ใช่ decision ที่ต้องถาม Founder ซ้ำ)
- R3. **[ตัดสินใจแล้ว: ทำเลย]** เพิ่ม multi-image Drop (1–9 รูป) — schema ใหม่ (ตาราง `drop_images` แยกจาก `drops.image_url` เดิม หรือ array column), UI grid ใหม่, full-screen viewer พร้อม swipe ระหว่างรูป, client-side compression ทุกรูปก่อน upload (ต่อยอด pattern การ compress ที่ WYN-005 มีอยู่แล้วสำหรับรูปเดียว) — **ต้องคง backward-compat กับ Drop รูปเดียว/ไม่มีรูปเดิมทั้งหมด (WYN-062) ไม่ทำลายของเดิม**
- R4. เพิ่ม Recommendation Section บน Profile (horizontal scroll, dismiss ได้ด้วยปุ่ม X — ต้องมี state เก็บว่า user dismiss คนไหนไปแล้วเพื่อไม่ให้ suggest ซ้ำ)
- R5. **[ตัดสินใจแล้ว: สาธารณะ]** ปรับ Profile Tabs เป็น Posts/Replies/Media/Likes — "Replies"/"Likes" เปิดให้ทุกคนเห็นได้เหมือน Posts/Media (ไม่จำกัดแค่เจ้าของโปรไฟล์) — **AI Design ต้องออกแบบการสื่อสารให้ผู้ใช้รู้ตัวชัดเจนว่า Like/Reply ของตัวเองเป็นสาธารณะ** (เช่น first-time notice ตอนเปิดใช้ฟีเจอร์ครั้งแรก) ตาม WYN Mission เรื่องความเป็นส่วนตัวที่ไม่ควรให้ผู้ใช้ประหลาดใจภายหลัง
- R6. **[เลื่อนออก ตาม Recommendation เดิม]** สัญญาณ dwell-time ("เปิดดูนาน") เข้า ranking algorithm — ทำเป็นงานแยกในอนาคต ไม่รวมในรอบนี้
- R7. เติม micro-interaction ที่ยังไม่ยืนยัน (Follow animation, Tab transition, Haptic feedback) ให้ครบตามจุดที่ยังขาด — ตรวจสอบให้ชัดตอน Design/Coding ว่าจุดไหนมีอยู่แล้วบ้าง
- R8. Profile top bar: เพิ่ม Search/Notifications icon เข้าไปด้วย (ปัจจุบัน Profile มีแค่ Settings/Logout หรือ More menu เท่านั้น ไม่มี Search/Notifications shortcut)

Acceptance Criteria:
- [ ] Founder ยืนยันภาพอ้างอิง หรือยืนยันให้ทำจากข้อความ spec อย่างเดียวได้
- [ ] Light theme (fix หรือ system-follow ตามที่ Founder เลือก) ใช้งานได้ทุกหน้า ไม่มีจุดที่ยังเป็น dark ค้าง (ถ้าเลือก fix light)
- [ ] Drop สร้างได้ 1–9 รูป, แสดง grid ถูกต้อง, เปิด full-screen swipe ดูได้, ทุกรูป compress ก่อน upload
- [ ] Profile มี Recommendation Section, dismiss แล้วไม่ suggest ซ้ำ
- [ ] Profile Tabs ใหม่ตาม privacy ที่ Founder เลือก ทำงานถูกต้อง
- [ ] Regression: ฟีเจอร์เดิมทั้งหมด (Drop เดี่ยวรูป, Poll, text-only จาก WYN-062, ReDrop, Comment, Search, ranking algorithm WYN-063) ยังทำงานถูกต้องทุกจุด

Dependencies: ต่อยอด DS-001 (สี, อนุมัติแล้ว), WYN-062 (text-only Drop), WYN-063 (ranking algorithm), WYN-066 (ซ่อน Pop จาก Profile) — ไม่ต้องสร้าง design system ใหม่ตั้งแต่ต้น ใช้ `WynColors`/`WynTheme`/`WynSpacing`/`WynTypography` เดิมทั้งหมด

Priority: **ไม่มีคำถามค้างแล้ว** (2026-08-24) — R1/R2/R3/R5 ตัดสินใจ/ยืนยันครบ พร้อมส่งต่อ AI Design ทำทุก requirement ได้ทันที

Risks: 
- multi-image Drop (R3) เป็น schema change ระดับกลาง (ตารางใหม่/relationship ใหม่) กระทบทุกจุดที่เคยสมมติว่า Drop มีรูปเดียว (เยอะพอสมควรหลัง WYN-062 ทำให้ null-safe ไปแล้วรอบหนึ่ง) — ต้องตรวจซ้ำทุกจุดอีกครั้ง
- Replies/Likes tab แบบสาธารณะ (ถ้า Founder เลือก) เปิดเผยพฤติกรรมผู้ใช้ที่ไม่เคยเปิดเผยมาก่อน อาจกระทบความเป็นส่วนตัวที่ผู้ใช้ไม่คาดคิด (โดยเฉพาะ Gen Z target user ตาม Vision ที่เน้น "ความปลอดภัยและความเป็นส่วนตัว" ใน COMPANY.md) — แนะนำ default เป็น "เจ้าของโปรไฟล์เท่านั้น" เว้นแต่ Founder ยืนยันชัดเจนว่าต้องการสาธารณะ
- Dwell-time tracking (R6) เก็บพฤติกรรมการดูละเอียดขึ้น ต้องพิจารณาประเด็น privacy/data minimization เช่นกันก่อนทำจริง

Recommendation: 
- เริ่มจากส่วนที่ไม่มีคำถามค้าง (R3/R4/R7/R8) ให้ AI Design ทำก่อนได้เลย เพื่อไม่เสียเวลารอ
- Replies/Likes tab แนะนำ default เป็น private (เจ้าของโปรไฟล์เท่านั้น) ตาม WYN Mission เรื่องความเป็นส่วนตัว เว้นแต่ Founder ต้องการสาธารณะจริงๆ
- Dwell-time signal (R6) แนะนำเลื่อนเป็นงานแยกต่างหาก (ไม่ block งานนี้) เพราะเป็น schema ใหม่ที่ต้องคิด privacy ให้รอบคอบกว่านี้ ไม่ควรรีบทำรวมในรอบเดียว

Handoff: **พร้อมส่งต่อ AI Design ทำทุก requirement (R2–R8) ได้ทันที** — ไม่มีคำถามค้างแล้ว (ได้ภาพอ้างอิงและ Founder ตัดสินใจครบทุกจุดแล้ว 2026-08-24)

---

## Implementation (AI Coding, 2026-08-24)

ทำตาม Design spec `.wyn/docs/design/wyn-064-wynos-visual-refresh.md` ครบทั้ง 9 Screen เรียงลำดับตามที่ Design แนะนำ (เล็ก/เสี่ยงต่ำก่อน ใหญ่/เสี่ยงสูงสุดท้าย) แบ่งเป็น 3 commit หลักที่แต่ละอันผ่าน `flutter analyze`/`flutter test` เต็มชุดก่อน commit ถัดไปเสมอ:

**Commit 1 — Screen 1/8/9** (theme fix, top-bar icons, haptic/animation)
- `main.dart`: `themeMode: ThemeMode.system` → `ThemeMode.light` (คง `WynTheme.dark` ไว้ในโค้ด)
- `ViewProfileScreen`: เพิ่มไอคอน Search/Notifications บน AppBar เฉพาะโปรไฟล์คนอื่น (สร้าง repository ใหม่ในจุดเรียกใช้ ไม่ threaded ผ่าน constructor — มิเรอร์ pattern `_reportRepository` เดิม)
- `DoubleTapLike`/`FollowActionButton`: เพิ่ม `HapticFeedback.lightImpact()`, `FollowActionButton` เพิ่ม `AnimatedSwitcher` ที่ label

**Commit 2 — Screen 5** (Recommendation Section)
- Schema ใหม่: `profile_recommendation_dismissals` table (RLS: own rows only, กัน self-dismissal), แก้ `suggested_users()` (WYN-040) เพิ่ม exclusion — reuse ฟังก์ชันเดิมแทนสร้างใหม่ ("similar to profile" ที่แท้จริงเลื่อนไว้ตาม Design doc)
- `ProfileRecommendationSection`/`_RecommendationCard` widget ใหม่ (reuse `FollowActionButton` compact mode) แสดงเฉพาะดูโปรไฟล์คนอื่น
- SQL regression test ใหม่: `wyn_071_recommendation_dismissal_test.sh` (7 checks)

**Commit 3 — Screen 2-4** (multi-image Drop)
- Schema ใหม่: `drop_images` table (`drops.image_url` เดิมไม่แตะเลย ยังเป็นรูปแรกเสมอ — ทุกจุดเดิมที่อ่านมันตรงๆ เช่น `home_feed`/`get_wynos_ranked_feed`/admin web ยังทำงานถูกต้อง 100% โดยไม่ต้องแก้อะไร) + backfill migration + RLS (`exists()` เช็คผ่าน `drops` เอง ไม่ duplicate policy)
- `DropRepository.createDrop` รับ `List<Uint8List>`/`List<String>` แทนตัวเดียว, เพิ่ม `fetchDropImages()` (fetch เต็มลิสต์แบบ on-demand เท่านั้น ไม่ eager load ทุก feed fetch), `_dropSelect` เพิ่ม `drop_images(count)`
- `CreateDropScreen`: grid preview ใหม่ (1-9 รูป, ลบทีละรูปได้), gallery ใช้ `pickMultiImage` (จำกัดด้วย `limit` param ของ picker เองแทนการ trim ทีหลัง)
- `DropImageGallery`/`DropImageViewer` widget ใหม่ (PageView+dot indicator+full-screen pinch-zoom)
- **พบและแก้บั๊กจริงระหว่างเขียน**: `DoubleTapLike` (double-tap) + `GestureDetector` แยกอัน (single-tap เปิด fullscreen) ซ้อนกันทำให้ single-tap ไม่ทำงาน (gesture arena ที่ tap recognizer ถูก double-tap recognizer แย่งไป) — พิสูจน์ด้วย test จริงที่ fail ก่อนแก้ แก้โดยรวม `onTap` เข้า `DoubleTapLike`'s GestureDetector ตัวเดียวกันแทน (เพิ่ม optional `onTap` param ใหม่)
- SQL regression test ใหม่: `wyn_071_multi_image_drop_test.sh` (7 checks)

**Commit 4 — Screen 6-7** (Profile tab restructure)
- Tab ใหม่ 5 อันเท่ากันทุกคน: Posts/ReDrops/Replies/Media/Likes (แทน Drop/ReDrops + conditional Saved/Draft เดิม)
- **ไม่มี schema ใหม่เลย** — `drop_likes`/`drop_comments` เปิด public read (`using (true)`) อยู่แล้วตั้งแต่ก่อนงานนี้ จึงแค่เพิ่ม query ใหม่ (`fetchLikedByAuthor`/`fetchRepliesByAuthor`) ไม่ต้องแก้ RLS
- `ProfileDropGridTab` เพิ่ม `onlyWithImages` flag reuse เป็น Media tab, widget ใหม่ `ProfileLikesTab`/`ProfileRepliesTab`/`PrivacyNoticeBanner`
- Saved/Draft ย้ายเป็นไอคอนข้าง "แก้ไขโปรไฟล์" (push เป็นหน้าแยกแทนที่จะเป็น tab — widget เดิมไม่แตะเลย)

Files Changed: ดู commit message ของทั้ง 4 commit ใน git log (`b18d719`, `82582a9`, `f1fb432`, `838626a`) — สรุปคร่าวๆ: `app/lib/main.dart`, `app/lib/core/widgets/double_tap_like.dart`, `app/lib/features/follow/presentation/widgets/follow_action_button.dart`, `app/lib/features/profile/presentation/view_profile_screen.dart` (แก้เยอะสุด), widget ใหม่ 7 ตัว, `DropRepository`/`Drop` model/`DropComment` ขยาย, `supabase/schema.sql` (+2 table ใหม่), test ใหม่ 20+ ไฟล์/เคส

Reason: ดูรายละเอียดเหตุผลแต่ละจุดในแต่ละ commit message — หลักการที่ยึดตลอด: reuse ของเดิมให้มากที่สุด (`suggested_users()`, `drop_likes`/`drop_comments` RLS ที่มีอยู่แล้ว, `FollowActionButton`, `ProfileDropGridTab`), ไม่แตะ `drops.image_url`/ranking algorithm ที่เพิ่ง fix บั๊ก production วันเดียวกัน, แก้เฉพาะจุดที่จำเป็นจริง

**Known Issues / สโคปที่ปรับจาก Design doc (บันทึกตรงๆ ไม่ใช่ซ่อน)**:
1. Posts/ReDrops **ไม่ได้รวมเป็น tab เดียว** ตามที่ Design doc เขียนไว้ — คงเป็น 2 tab แยก เพราะ layout ขัดกันจริง (Posts เป็น grid หนาแน่น, ReDrops เป็น list การ์ดเต็ม) การรวมต้องใช้ backend UNION query หรือ client merge-sort ใหม่ทั้งหมด ประเมินแล้วเสี่ยงเกินไปสำหรับรอบนี้ — capability ครบทุกอย่างตามที่ Founder ขอ (Replies/Media/Likes มีจริงหมด) เพียงแค่ ReDrop ยังอยู่ tab ของตัวเอง ไม่ได้ปนกับ Posts
2. Multi-image ใน Draft (WYN-036) ยังเป็นรูปเดียวเท่านั้น (non-goal ตาม Design doc เอง) — resume draft ที่เคยมีหลายรูปจะเหลือแค่รูปแรก
3. Dwell-time signal (R6 เดิมจาก Product spec) ไม่ได้ทำ — ตามที่ Product ระบุไว้แล้วว่าเลื่อนออก
4. Skeleton loading/Image placeholder ในบางจุด — Design doc ขอให้ Coding ยืนยันสถานะจริงก่อนแก้ ตรวจแล้วพบว่าจุดที่ต้องใช้ (loading spinner ระหว่างโหลด) มีอยู่แล้วทุกจุดในรูปแบบ `CircularProgressIndicator` เดิม ไม่ต้องเพิ่ม skeleton ใหม่

Tests: `flutter test` เต็ม suite **784/784 ผ่าน** (baseline ก่อนแก้ 762/762 — เพิ่ม 22 test case ใหม่ตลอดทั้ง 4 commit, แก้ 3 เคสเดิมที่ assert โครงสร้าง tab เก่า) — SQL regression 2 สคริปต์ใหม่ (`wyn_071_recommendation_dismissal_test.sh` 7 checks, `wyn_071_multi_image_drop_test.sh` 7 checks) ผ่านหมด, รันซ้ำ `wyn_040_discovery_test.sh` เดิมยืนยันไม่มี regression จากการแก้ `suggested_users()`

Build: `flutter analyze`: สะอาดทุก commit (0 issues)

Handoff: ส่งต่อ AI QA & Security (`/qa`) — จุดที่ควรตรวจเข้มเป็นพิเศษ: (1) RLS ใหม่ของ `drop_images`/`profile_recommendation_dismissals` (2) `drops.image_url` ยังคง backward-compatible จริงกับทุก consumer เดิม (3) การ merge single-tap/double-tap ใน `DoubleTapLike.onTap` ไม่ชนกับจุดอื่นที่ใช้ widget นี้อยู่ (4) Privacy notice banner แสดงถูกจังหวะจริง (เจ้าของโปรไฟล์เท่านั้น, ครั้งแรกเท่านั้น) (5) Regression กับ WYN-062 (text-only Drop)/WYN-063 (ranking algorithm ที่เพิ่ง fix บั๊ก production วันนี้) — ยังไม่ deploy จนกว่า QA จะอนุมัติ

---

## QA & Security Output (2026-08-25)

Feature: WYNOS Visual Refresh (WYN-071) — Theme fix, Multi-image Drop, Profile Recommendation Section, Profile tab restructure (Posts/ReDrops/Replies/Media/Likes), Search/Notification icons บนโปรไฟล์คนอื่น, Haptic feedback + Follow animation

Environment: Local (ไม่มี Supabase project จริงในสภาพแวดล้อมนี้) — `flutter analyze`/`flutter test` เต็ม suite ต่อ codebase จริง, SQL regression test ต่อ throwaway local Postgres database (สร้าง/ทำลายทิ้งหลังทดสอบ ไม่แตะ dev/prod data), ad-hoc RLS probe ต่อ local Postgres แยกอีกชุดสำหรับ `drop_images` cascade กับ Drop ที่ soft-delete แล้ว

Test Cases:
1. `flutter test` เต็ม suite (ตรวจซ้ำอิสระ ไม่เชื่อตัวเลขที่ Coding รายงานเฉยๆ)
2. `flutter analyze` เต็ม repo
3. SQL regression: `wyn_071_recommendation_dismissal_test.sh` (7 checks)
4. SQL regression: `wyn_071_multi_image_drop_test.sh` (7 checks)
5. Re-run SQL regression เดิมที่เสี่ยง regression: `wyn_040_discovery_test.sh` (แก้ `suggested_users()`), `wyn_063_unified_home_feed_test.sh` (ranking algorithm ที่เพิ่ง fix บั๊ก production วันเดียวกัน)
6. Ad-hoc RLS probe: `drop_images` ของ Drop ที่ soft-delete แล้ว ต้องไม่เห็นจากคนแปลกหน้า
7. Backward-compat trace: `drops.image_url` ยังใช้ได้กับ `admin_search_drops()`/`admin_get_drop()` (Admin web) จริงหรือไม่
8. Gesture-arena stress test: widget test พิสูจน์ tap/double-tap conflict จริงใน `DoubleTapLike`/`DropImageGallery` (จุดที่ Coding เองรายงานว่าเจอบั๊กและแก้ระหว่างทำ) — สร้าง regression test เพิ่มเพื่อยืนยัน fix ใช้ได้จริง ไม่ใช่แค่เชื่อคำอธิบาย
9. Extended probe: โครงสร้างเดียวกัน (outer `InkWell` + inner `DoubleTapLike` แยก detector) มีอยู่ใน `HomeDropCard`/`HomePopCard` ด้วยหรือไม่ (โค้ดเดิม ไม่ถูกแตะใน WYN-071) — พิสูจน์ด้วย widget test จริงว่ายังทำงานถูกต้องหรือไม่ ไม่ใช่แค่อ่านโค้ดเดา

Passed: 1, 2, 3, 4, 5, 6, 7, 8, 9 (784/784 flutter test; analyze 0 issues; ทั้ง 2 SQL script ใหม่ 7/7 checks ผ่าน; SQL เดิมทั้งคู่ผ่านไม่มี regression; RLS probe คนแปลกหน้าเห็น drop_images ของ Drop ที่ลบแล้ว = 0 แถวถูกต้อง; `admin_search_drops`/`admin_get_drop` ไม่ถูกแตะเลยใน 4 commit ยัง backward-compatible; DoubleTapLike fix ยืนยันด้วย test จริงว่าใช้ได้; HomeDropCard/HomePopCard onTap ยังทำงาน แค่ช้ากว่าปกติ ~300ms เมื่อแตะตรงรูปภาพ — ดู Security Findings)

Failed: ไม่มี (0)

Severity: Low (สำหรับประเด็นที่พบใน Test Case 9 เท่านั้น — ดูรายละเอียดด้านล่าง)

Reproduction Steps (ประเด็น Test Case 9 — HomeDropCard tap delay):
1. เปิด Home feed, เจอการ์ด Drop ที่มีรูปภาพ
2. แตะตรงตัวรูปภาพของการ์ด (ไม่ใช่ส่วนอื่นของการ์ด เช่น caption/username แถว)
3. สังเกตเวลาที่ `DropDetailScreen` เปิดขึ้น เทียบกับแตะจุดอื่นของการ์ดเดียวกัน

Expected: เปิด `DropDetailScreen` ทันทีเหมือนกันไม่ว่าจะแตะจุดไหนของการ์ด

Actual: แตะตรงรูปภาพ เปิดช้ากว่าจุดอื่นประมาณ 300ms (`kDoubleTapTimeout`) เพราะ gesture arena ต้องรอแยกแยะ tap เดี่ยว/คู่ระหว่าง outer `InkWell`'s Tap recognizer กับ inner `DoubleTapLike`'s DoubleTap recognizer (คนละ `GestureDetector` ซ้อนกัน) — พิสูจน์ด้วย widget test จริง (`tester.tap` แล้ว pump ครั้งเดียว = ยังไม่เปิด, pump ผ่าน `kDoubleTapTimeout` = เปิดแล้ว) — **onTap ยังทำงานถูกต้องเสมอ ไม่ใช่บั๊กที่ใช้งานไม่ได้เลย** ต่างจากบั๊กที่ Coding เจอและแก้ใน `DropImageGallery` (ซึ่งกรณีนั้น onTap ไม่ทำงานเลยไม่ว่าจะรอนานแค่ไหน) — โค้ดจุดนี้ (`HomeDropCard`/`HomePopCard`) เป็นของเดิมตั้งแต่ WYN-034/035, แก้ล่าสุดใน WYN-063 (`58e4c43`) ไม่ถูกแตะในทั้ง 4 commit ของ WYN-071 เลย จึงไม่ใช่บั๊กที่งานนี้สร้างขึ้นใหม่ ไม่กระทบขอบเขต/acceptance criteria ของ WYN-071

Security Findings: ไม่พบช่องโหว่ — RLS ของทั้ง `drop_images`/`profile_recommendation_dismissals` ตรวจสอบสิทธิ์ถูกต้อง (select ผ่าน parent `drops`' visibility, insert เฉพาะเจ้าของ), ไม่มี privilege escalation, ไม่มี secret รั่วไหลในโค้ดที่เพิ่ม (`git diff` ตรวจแล้ว), self-dismissal CHECK constraint ของ `profile_recommendation_dismissals` ป้องกัน user ยกเลิกคำแนะนำแทนคนอื่นได้ถูกต้อง

Recommendation: (1) **Fast-follow (non-blocking)**: รวม `onTap` เข้า `DoubleTapLike`'s เดียวกันใน `HomeDropCard`/`HomePopCard` (pattern เดียวกับที่แก้ใน `DropImageGallery` แล้ว) เพื่อให้ทั้งการ์ดตอบสนองเร็วเท่ากัน — ไม่ต้องรีบ ไม่ block WYN-071 (2) สโคปที่ปรับจาก Design doc (Posts/ReDrops ไม่รวม tab, Recommendation Section/Search-Notification icon ไม่ใส่บนโปรไฟล์ตัวเอง) ตรวจแล้วสมเหตุสมผลและมีเหตุผลบันทึกไว้ชัดเจนทุกจุด เห็นด้วยกับการตัดสินใจของ Coding

Final Status: PASS
