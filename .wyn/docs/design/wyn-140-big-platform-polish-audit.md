# Design Audit — WYN-140: "ดูเหมือนแพลตฟอร์มใหญ่ๆ" Polish Gap Analysis

Status: PROPOSED — รอ Founder เลือก priority ก่อนส่งต่อ AI Coding
Owner: AI Design
Requested by: Founder, 2026-09-07 ("ทำเว็บแอปให้ดีสุดๆ เสถียรสุดๆ ฟีเจอครบ ไม่มีบัค ไม่มีปัญหา เหมือนแพลตฟอร์มใหญ่ๆ")

## ก่อนเข้าเนื้อหา — ทำไมเอกสารนี้ไม่ใช่ "ทำให้ครบทุกอย่างที่ขอ"

คำขอของ Founder ("ดีสุดๆ เสถียรสุดๆ ฟีเจอครบ ไม่มีบัค เหมือนแพลตฟอร์มใหญ่ๆ") จริงๆ แล้วครอบคลุม 4 เรื่องที่แยกกันตามโครงสร้างทีม (`.wyn/company/COMPANY.md`) และแต่ละเรื่องมีเจ้าของงานคนละ role — ไม่ใช่ AI Design ทำได้คนเดียวทั้งหมด:

| สิ่งที่ Founder ขอ | เจ้าของจริง | สถานะตอนนี้ |
|---|---|---|
| "ไม่มีบัค" | AI QA & Security + AI Debug Engineer | มี regression test suite และ bug tracker (`.wyn/tasks/bugs/`) อยู่แล้ว เป็นงานต่อเนื่อง ไม่ใช่ Design |
| "เสถียร" | AI Deploy & DevOps | เรื่อง monitoring/uptime/rollback — นอกขอบเขต Design |
| "ฟีเจอร์ครบ" | AI Product Manager | เรื่อง roadmap/priority ฟีเจอร์ใหม่ — นอกขอบเขต Design |
| "ดูเหมือนแพลตฟอร์มใหญ่ๆ" | **AI Design** | **เอกสารนี้** — ขอบเขตที่ Design ทำได้จริงคือ perceived quality ผ่าน UX/UI |

เอกสารนี้โฟกัสเฉพาะช่อง "ดูเหมือนแพลตฟอร์มใหญ่ๆ" ตามหน้าที่ที่ `.wyn/agents/design.md` กำหนดไว้ — **ไม่คิดทิศทาง visual ใหม่** (ใช้ Design System เดิมที่มีอยู่แล้วทั้งหมด: `design-principles.md`, `ds-001` ถึง `ds-010`) ตรวจโค้ดจริงในโปรเจกต์ (ไม่เดา) เพื่อหาว่าอะไรที่ทำให้ WYNOS "รู้สึก" เล็กกว่าแพลตฟอร์มใหญ่ (Instagram/Twitter/Facebook ระดับ) ทั้งที่ฟีเจอร์มีครบเยอะแล้ว

## Methodology

ตรวจโค้ดจริงใน `app/lib/` (ไม่ใช่การประเมินความรู้สึกลอยๆ):

```
grep -rc "CircularProgressIndicator" lib/     → 144 จุด ใน 88 ไฟล์
grep -rl "Skeleton" lib/                       → มีแค่ 2 ฟีเจอร์ (Home Feed, Profile)
grep -rl "AnimatedSwitcher|AnimatedContainer|Hero(" lib/ → 5 ไฟล์
grep -rl "errorMessageFor|networkErrorMessage" lib/     → 4 ไฟล์
grep -rl "โหลด.*ไม่สำเร็จ" lib/ (hardcoded, ไม่แยก offline)  → 45 ไฟล์
grep -n "shimmer" pubspec.yaml                 → ไม่มี dependency นี้เลย
grep -rl "Sentry|Crashlytics|FlutterError.onError" lib/ → ไม่มีเลย (ไม่ใช่ Design scope แต่ควรบันทึกไว้)
```

## Finding 1 — Loading state: มี Skeleton แค่ 2 หน้า ที่เหลือ 86 หน้าเป็น spinner เปล่า

**อาการ**: แพลตฟอร์มใหญ่ (Instagram/Twitter/Facebook) แทบไม่มี "spinner กลางจอเปล่าๆ" อีกแล้ว — ใช้ skeleton (การ์ดเทาๆ รูปร่างเหมือนเนื้อหาจริง) แทบทุกจุดที่โหลดข้อมูล เพราะลดความรู้สึก "ค้าง" และ layout ไม่กระโดดตอนโหลดเสร็จ

WYNOS มี `HomeFeedSkeleton`/`ProfileSkeleton` แล้ว (ทำตั้งแต่ WYN-013/Home polish) แต่หน้าอื่นที่มี traffic สูงพอกัน — **Club Page, Club Posts/Chat/Members tab, Chat Inbox, Conversation, Notification List, Search, Discovery, Settings sub-screens ทุกตัว** — ยังเป็น `Center(child: CircularProgressIndicator())` เปล่าๆ ทั้งหมด

**หมายเหตุสำคัญ**: skeleton ที่มีอยู่ 2 ตัวจงใจทำเป็น **static block ไม่มี shimmer animation** (ดู comment ใน `home_feed_skeleton.dart`) เพราะ animation แบบ indeterminate ทำให้ `flutter test`'s `pumpAndSettle()` ค้างไม่มีวันจบ — เป็น constraint ทางเทคนิคจริงที่ทีมนี้เคยโดนมาแล้ว **ต้องคงหลักการนี้ต่อ** (static skeleton, ไม่ใช่ shimmer) ในทุกจุดที่ทำเพิ่ม ไม่งั้น test suite ทั้งชุดจะพังเป็นลูกโซ่

**Priority**: สูง — เป็นจุดที่ "รู้สึก" ได้ทันทีในการใช้งานทุกวัน กระทบเกือบทุกหน้าจอ

## Finding 2 — ข้อความ error ไม่แยก "เน็ตหลุด" กับ "เซิร์ฟเวอร์พัง" ใน 45 จุดจาก 49 จุด

**อาการ**: มี utility ที่ถูกต้องอยู่แล้ว (`core/network_error.dart` — แยกข้อความ "ไม่มีการเชื่อมต่ออินเทอร์เน็ต" ออกจาก error อื่นๆ อย่างมีเหตุผลชัดเจน ตาม comment ในไฟล์เอง) แต่ **ใช้จริงแค่ 4 จุด** ส่วนอีก 45 จุดยังขึ้นข้อความ generic แบบ "โหลด X ไม่สำเร็จ" ตายตัว ไม่ว่าจะเป็นเพราะเน็ตหลุดหรือเซิร์ฟเวอร์มีปัญหาจริง

แพลตฟอร์มใหญ่แยกสองเคสนี้เสมอ เพราะมันคือ 2 ปัญหาคนละเรื่องที่ผู้ใช้ควรทำต่างกัน (รอสัญญาณ vs. รายงานบั๊ก) — ข้อความ generic ทำให้ผู้ใช้โทษแอปทั้งที่บางทีเป็นที่สัญญาณตัวเอง

**Priority**: กลาง-สูง — ทำได้เร็ว (แทนที่ hardcoded string ด้วย `errorMessageFor()` ที่มีอยู่แล้ว) ความเสี่ยงต่ำมาก เพราะไม่ใช่ฟีเจอร์ใหม่ เป็นการ "เติมของเดิมให้ครบ" ตาม pattern ที่มีอยู่แล้ว

## Finding 3 — แทบไม่มี motion/transition เลย (5 ไฟล์จากทั้งแอป)

**อาการ**: แพลตฟอร์มใหญ่ใช้ motion เล็กๆ น้อยๆ ตลอดเวลาโดยผู้ใช้ไม่รู้ตัว (fade เข้า/ออกตอนเปลี่ยนเนื้อหา, การ์ดขยับตอน insert/remove, ปุ่ม Like เด้งตอนกด) — ทำให้แอปรู้สึก "ลื่น" แทนที่จะ "กระตุก" WYNOS มี haptic feedback ที่ดีอยู่แล้ว (`WynFeedback.like()`/`.save()`/`.commentSent()` ฯลฯ) แต่ฝั่ง visual motion แทบไม่มีเลยนอกจาก default page-route transition ของ Flutter เอง

**ตัวอย่างจุดที่ขาดง่ายและกระทบบ่อย**: list ที่มี insert/remove (comment ใหม่, badge ใหม่, ข้อความใหม่) เปลี่ยนแบบ "โผล่/หาย" ทันที ไม่มี fade/slide เลยสักจุด

**Priority**: กลาง — เห็นผลชัดแต่ effort สูงกว่า Finding 1-2 เพราะต้องทำทีละจุดจริงๆ ไม่ใช่ shared utility เดียวจบ

## นอกขอบเขต Design แต่พบระหว่างตรวจ ควรส่งต่อ

- **ไม่มี crash reporting เลย** (ไม่มี Sentry/Crashlytics/`FlutterError.onError` handler ใดๆ) — แปลว่าถ้าแอปพังจริงในเครื่องผู้ใช้ ทีมจะไม่มีทางรู้เลยนอกจาก Founder รายงานเอง ตรงกับสิ่งที่ Founder ขอเรื่อง "เสถียร" โดยตรง แต่เป็นงาน **AI Deploy & DevOps** ไม่ใช่ Design — แนะนำให้ Founder สั่ง `/deploy` แยกถ้าสนใจเรื่องนี้ต่อ

## คำแนะนำ

ไม่แนะนำให้ทำทั้ง 3 Finding พร้อมกันในทีเดียว (เสี่ยง regression กว้างเกินไปในการ deploy ครั้งเดียว ขัดกับ Change Control ใน `.wyn/company/RULES.md` ข้อ "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น") — เสนอทำเรียงตาม Priority ทีละ task ผ่าน workflow เต็ม (Design → Coding → QA → Deploy) เหมือนงานอื่นทุกครั้ง:

1. **WYN-140a**: ขยาย error-message utility (`errorMessageFor`) ให้ครบทุกจุด — เร็วสุด, เสี่ยงต่ำสุด, เห็นผลจริงทันที
2. **WYN-140b**: เพิ่ม Skeleton loading ให้หน้าที่ traffic สูงสุดก่อน (Club Page, Chat Inbox, Notification List) แล้วค่อยขยายที่เหลือเป็นรอบถัดไป
3. **WYN-140c**: เพิ่ม motion/transition ในจุดที่กระทบบ่อยที่สุดก่อน (list insert/remove) — ทำทีหลังเพราะ effort สูงกว่า

## Handoff

รอ Founder เลือกว่าจะเริ่มจากอันไหนก่อน (เลือกได้มากกว่า 1) — เมื่อเลือกแล้ว AI Design จะเขียน spec แบบละเอียดเต็มรูปแบบ (Screen/Purpose/User Flow/Components/Interactions/States/Responsive Behavior/Accessibility/Design Rules) ให้ทีละ task ตาม template ปกติ ก่อนส่งต่อ AI Coding

---

## Founder เลือกแล้ว (2026-09-07): ทำทั้ง 3 อัน — Spec เต็มรูปแบบด้านล่าง

Founder เลือกทำทั้ง WYN-140a/140b/140c — ยังคง**เรียงตาม priority เดิม** (a → b → c) ส่งต่อ AI Coding ทีละ task ไม่รวมเป็น PR เดียวกัน (ตาม Change Control ใน `.wyn/company/RULES.md`: "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น" — 3 เรื่องนี้ไม่เกี่ยวกันทางโค้ด ไม่มีเหตุผลต้อง deploy พร้อมกัน และแยกกันทำให้ QA/rollback อิสระต่อกันถ้าอันใดอันหนึ่งมีปัญหา)

### WYN-140a — Error message: แยกเน็ตหลุด/เซิร์ฟเวอร์พัง ให้ครบทุกจุด

```
Screen: 44 จุดทั่วแอปที่ยังใช้ข้อความ error แบบ hardcoded (ดูรายชื่อไฟล์ท้าย spec นี้) — ไม่ใช่หน้าเดียว เป็น utility-adoption task
Purpose: ให้ผู้ใช้แยกออกว่า "เน็ตตัวเองหลุด" กับ "WYNOS มีปัญหาจริง" เป็นคนละเรื่อง (utility ที่ถูกต้องมีอยู่แล้ว แค่ยังใช้ไม่ครบ)
User Flow: [request ล้มเหลว] → catch block เดิม → เปลี่ยนจาก return ข้อความ hardcoded เป็น errorMessageFor(error, serverMessage: '<ข้อความเดิมของจุดนั้น>') → แสดงผลด้วย widget เดิมทุกอย่าง (SnackBar/inline text/ปุ่มลองใหม่) ไม่เปลี่ยน flow
Components: ใช้ `core/network_error.dart`'s `errorMessageFor()`/`networkErrorMessage` ที่มีอยู่แล้ว — ไม่สร้าง component/utility ใหม่
Interactions: ไม่เปลี่ยนเลย (ปุ่ม "ลองใหม่", ตำแหน่ง, timing เดิมทั้งหมด) — เปลี่ยนแค่ตัว string ที่เลือกแสดงตอน error
States: Error state เดิมทุกจุดคงรูปแบบเดิม (inline text ใต้ list, SnackBar, หรือ full-screen retry แล้วแต่จุดเดิมใช้แบบไหนอยู่แล้ว) — งานนี้ไม่เปลี่ยน state shape ใดๆ
Responsive Behavior: ไม่เปลี่ยน — `networkErrorMessage` ("ไม่มีการเชื่อมต่ออินเทอร์เน็ต ลองใหม่อีกครั้ง") สั้นกว่าหรือเท่ากับข้อความเดิมทุกจุดที่สำรวจแล้ว ไม่ทำให้ overflow ที่จอเล็กเพิ่มขึ้น
Accessibility: ไม่เปลี่ยน — Semantics label ของ error text เดิมยังใช้ได้ตรงตัว ไม่มีการสื่อความหมายด้วยสีเดี่ยวๆ เพิ่ม
Design Rules: **ห้ามเปลี่ยนคำเดิม (serverMessage)** — มันคือข้อความที่ตั้งใจออกแบบไว้แล้วสำหรับกรณี server ตอบว่า fail จริง งานนี้แค่เพิ่มเงื่อนไข "ถ้าเป็น network error ให้ใช้ข้อความอื่นแทน" เท่านั้น ไม่ใช่เขียนข้อความใหม่
Handoff: ส่งต่อ AI Coding — ไล่ทุกจุดใน 44 ไฟล์ด้านล่าง เปลี่ยน pattern จาก `setState(() => _error = 'ข้อความเดิม')` เป็น `setState(() => _error = errorMessageFor(e, serverMessage: 'ข้อความเดิม'))` (หรือรูปแบบเทียบเท่าตามโครงสร้างแต่ละไฟล์) รันเทสเดิมทุกไฟล์ผ่าน (ไม่ควรมีเทสพังเพราะ non-network error ยังคืนข้อความเดิมทุกตัว) แนะนำ AI QA & Security เพิ่ม regression test อย่างน้อย 1 จุดสำคัญ (Home Feed, Chat Inbox) จำลอง SocketException แล้วยืนยันข้อความเปลี่ยนเป็น networkErrorMessage จริง

รายชื่อ 44 ไฟล์ (จาก grep จริง 2026-09-07):
block/presentation/blocked_list_screen.dart, chat/presentation/chat_inbox_screen.dart,
chat/presentation/message_request_list_screen.dart, chat/presentation/share_to_chat_screen.dart,
club/presentation/club_invite_links_screen.dart, club/presentation/club_page.dart,
club/presentation/club_post_detail_screen.dart, club/presentation/invite_to_club_screen.dart,
club/presentation/my_clubs_screen.dart, club/presentation/widgets/club_chat_tab.dart,
club/presentation/widgets/club_events_tab.dart, club/presentation/widgets/club_insights_tab.dart,
club/presentation/widgets/club_members_tab.dart, club/presentation/widgets/club_posts_tab.dart,
drop/presentation/drop_detail_screen.dart, drop/presentation/recently_deleted_drops_screen.dart,
drop/presentation/widgets/draft_list.dart, follow/presentation/close_friends_screen.dart,
follow/presentation/exclude_friends_screen.dart, follow/presentation/follow_list_screen.dart,
follow/presentation/follow_request_list_screen.dart, hashtag/presentation/hashtag_feed_screen.dart,
home/presentation/home_feed_screen.dart, home/presentation/widgets/from_your_clubs_feed.dart,
legal/presentation/document_viewer_screen.dart, moderation/presentation/moderation_queue_screen.dart,
moderation/presentation/my_moderation_action_screen.dart, mute/presentation/muted_list_screen.dart,
notification/presentation/notification_list_screen.dart, pop/presentation/pop_feed_screen.dart,
pop/presentation/widgets/pop_clip_view.dart, pop/presentation/widgets/pop_comment_sheet.dart,
profile/presentation/view_profile_screen.dart, profile/presentation/widgets/profile_drop_grid_tab.dart,
profile/presentation/widgets/profile_likes_tab.dart, profile/presentation/widgets/profile_pop_grid_tab.dart,
profile/presentation/widgets/profile_redrops_tab.dart, profile/presentation/widgets/profile_replies_tab.dart,
profile/presentation/widgets/profile_saved_tab.dart, report/presentation/report_sheet.dart,
saved/presentation/bookmarks_screen.dart, search/presentation/top_100_screen.dart,
settings/presentation/notification_settings_screen.dart, settings/presentation/settings_screen.dart
```

### WYN-140b — Skeleton loading สำหรับหน้าที่ traffic สูงสุด (รอบแรก 4 หน้า)

```
Screen: Club Page (แท็บโพสต์เป็นหลัก), Chat Inbox, Conversation Screen (ประวัติข้อความ), Notification List — ยืนยันแล้วว่าทั้ง 4 ยังใช้ Center(CircularProgressIndicator()) เปล่าๆ ตอนโหลดครั้งแรก
Purpose: ลดความรู้สึก "ค้าง" ตอนเปิดหน้าที่ใช้บ่อยที่สุดรองจาก Home/Profile (ซึ่งมี Skeleton แล้ว) และกัน layout กระโดดตอนเนื้อหาโหลดเสร็จ ตรงกับ pattern ที่ `HomeFeedSkeleton`/`ProfileSkeleton` วางไว้แล้ว
User Flow: [เปิดหน้า] → initState เรียก fetch → ระหว่างรอ (state ข้อมูล == null) แสดง Skeleton แทน CircularProgressIndicator → ข้อมูลมาแล้ว replace ด้วยเนื้อหาจริง (ไม่มี fade เพิ่มในงานนี้ — fade เป็นของ WYN-140c)
Components: สร้าง Skeleton widget ใหม่ 1 ตัวต่อหน้า (`ClubPageSkeleton`, `ChatInboxSkeleton`, `ConversationSkeleton`, `NotificationListSkeleton`) โดย**ก็อปปี้โครงสร้างของ `HomeFeedSkeleton`ตรงๆ**(Container สีเทาจาก `Theme.of(context).colorScheme.surfaceContainerHighest`, มุมโค้ง `WynSpacing.radiusSm`) แค่ปรับ shape ให้ตรงกับเนื้อหาจริงของแต่ละหน้า:
  - ClubPageSkeleton: banner block เต็มความกว้าง + avatar circle + bar 2 บรรทัด (ชื่อ Club/จำนวนสมาชิก) + tab bar bar 3 อัน
  - ChatInboxSkeleton: แถวซ้ำ 5-6 แถว (avatar circle + bar ชื่อ + bar ข้อความล่าสุดสั้นกว่า)
  - ConversationSkeleton: แถบข้อความสลับซ้าย-ขวา (bar ความกว้างสุ่ม 2 แบบ เลียนแบบ chat bubble) 6-8 แถว
  - NotificationListSkeleton: แถวซ้ำ 5-6 แถว (avatar circle + bar ข้อความยาว 1 บรรทัด)
Interactions: ไม่มี tap/gesture บน Skeleton เอง (เหมือน HomeFeedSkeleton เดิม)
States: แสดงเฉพาะตอน "กำลังโหลดครั้งแรก" (ข้อมูล == null) เท่านั้น — ไม่ใช้กับ pull-to-refresh/load-more ที่มีอยู่แล้ว (จุดนั้นใช้ spinner เล็กที่ท้าย list เหมือนเดิม ไม่เปลี่ยน)
Responsive Behavior: Skeleton ต้องรับ list ยาวไม่เกิน viewport เดียว (ใช้ `cardCount`/แถวจำนวนคงที่แบบ `HomeFeedSkeleton`) ทดสอบที่ 320px ตาม ds-008 เช่นเดิม
Accessibility: **ต้องห่อด้วย `ExcludeSemantics`** เหมือน `HomeFeedSkeleton` เป๊ะๆ — screen reader ไม่ควรอ่านแถบเทาๆ เหล่านี้เป็นเนื้อหา
Design Rules: **ห้ามใช้ shimmer/animation แบบ indeterminate เด็ดขาด** — ต้องเป็น static block เหมือน `HomeFeedSkeleton`/`ProfileSkeleton` เท่านั้น เหตุผล: animation indeterminate ทำให้ `flutter test`'s `pumpAndSettle()` ค้างไม่จบ (บทเรียนที่มีอยู่แล้วในโค้ดคอมเมนต์ของ `HomeFeedSkeleton`) ใช้สี/สเปซจาก design token เดิม (`WynSpacing`, `colorScheme.surfaceContainerHighest`) ไม่ประดิษฐ์สีใหม่
Handoff: ส่งต่อ AI Coding — สร้าง 4 widget ใหม่ตามโครงสร้างข้างต้น แทนที่ `Center(child: CircularProgressIndicator())` ตอน initial-load เท่านั้น (ไม่แตะ load-more/pull-to-refresh spinner ที่มีอยู่แล้ว) AI QA & Security ตรวจ 2 เรื่องหลัก: (1) screen reader ไม่อ่าน skeleton เป็นเนื้อหา (2) `flutter test` ทั้ง 4 หน้าเดิมยังผ่านปกติ ไม่มี `pumpAndSettle()` ค้าง
```

### WYN-140c — Motion/transition ในจุดที่กระทบบ่อยที่สุด

```
Screen: List insert/remove ทั่วแอป (comment ใหม่ในโพสต์/Club post, ข้อความใหม่ในแชท, badge ใหม่/หาย ใน Club Members) — ไม่ใช่ทำใหม่ทั้งระบบ เพราะ DS-010 มี motion infrastructure ที่ใช้งานได้จริงอยู่แล้ว (`WynMotion`, `WynStatePop`, `WynPressable`) แค่ยัง adopt แคบมาก (5 ไฟล์จากทั้งแอป) — งานนี้คือขยายการใช้ ไม่ใช่สร้างใหม่
Purpose: ลดความรู้สึก "กระตุก" ตอนเนื้อหาโผล่/หายทันทีแบบไม่มีการเปลี่ยนผ่าน ให้ตรงกับมาตรฐาน DS-010 ที่วางไว้แล้วแต่ยังไม่ครอบคลุม
User Flow: [comment/message/badge ใหม่เข้า list] → แทนที่จะ insert ทันที ให้ fade+scale เข้าตาม `WynMotion.standard` (220ms) + `WynMotion.popFromScale` เหมือน pattern ที่ `WynStatePop` ใช้อยู่แล้วกับ Like/Save icon — [รายการถูกลบ] → fade out ก่อนหายจาก list แทนที่จะหายทันที
Components: ใช้ `WynMotion` token เดิมทั้งหมด (`.standard`, `.quick`, `.pop` curve) — ถ้าจำเป็นต้องมี wrapper ใหม่สำหรับ list-item enter/exit ให้ตั้งชื่อตาม pattern เดิม (เช่น `WynListItemPop`) วางในโฟลเดอร์เดียวกับ `wyn_state_pop.dart` ไม่ใช่สร้างระบบ motion คู่ขนาน
Interactions: ไม่เปลี่ยน gesture ใดๆ (tap/long-press/swipe เดิมทั้งหมด) เพิ่มแค่ transition ตอนรายการเปลี่ยน
States: เฉพาะตอน state เปลี่ยนจริง (list ยาวขึ้น/สั้นลงจาก insert/remove) — **ห้ามเล่น animation ตอน initial load ของ list** (เหมือนกติกาเดิมของ `WynStatePop`: "Starts settled... ต้อง not animate" ตอน build ครั้งแรก) ไม่งั้นทุกครั้งที่ scroll เข้า list ยาวๆ จะเห็น animation รัวๆ ผิดจุดประสงค์
Responsive Behavior: ไม่เปลี่ยนจาก layout เดิม — animate เฉพาะ opacity/transform (scale) ตามกติกา DS-010 ข้อ 5 ("ไม่ animate padding/width/height ที่บังคับ layout ใหม่ทุกเฟรม") ห้ามฝ่าฝืนกติกานี้เด็ดขาดเพราะจะกระทบ scroll performance บน list ยาว
Accessibility: **ต้องเช็ค `WynMotion.isReduced(context)` ทุกจุดที่เพิ่มใหม่** เหมือน `WynStatePop` ทำอยู่แล้ว — ถ้า reduce motion เปิดอยู่ ให้ state เปลี่ยนทันที (Duration.zero) ไม่ตัดสถานะทิ้ง มีแต่ตัดระยะการเคลื่อนไหว
Design Rules: **ห้ามสร้าง duration/curve/scale ใหม่** — ใช้ token จาก `WynMotion` เดิมทั้งหมด (ตาราง DS-010 ข้อ 5) ถ้าพบว่า token ที่มีไม่พอสำหรับ use case ใหม่จริงๆ ให้กลับมาที่ AI Design ก่อนเพิ่ม ไม่ใช่ AI Coding เลือกค่าเองเวลา implement
Handoff: ส่งต่อ AI Coding — priority เรียงตามจุดที่ traffic สูงสุดก่อน: (1) Conversation Screen ข้อความใหม่จาก realtime, (2) Club Post/Drop comment ใหม่, (3) Club Members badge เปลี่ยน ทำทีละจุด รัน `interaction_guard_test.dart`/`design_system_guard_test.dart` เดิมต้องยังผ่าน (บังคับห้าม import HapticFeedback/สีตรงในฟีเจอร์) เพิ่ม widget test ยืนยันว่า initial build ไม่มี animation เล่น (มีแค่ insert/remove ทีหลังเท่านั้นที่เล่น)
```
