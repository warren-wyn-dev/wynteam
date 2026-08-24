# Product Task — WYN-064

Status: coded, self-verified (flutter analyze 0 issues, flutter test 768/768) — รอ AI QA & Security อิสระ
Owner: AI Product Manager → AI Design → AI Coding (เสร็จ) → AI QA & Security (รอ)

Feature: Tap Home Tab to Scroll to Top & Refresh

Goal: ในฐานะผู้ใช้งาน เมื่อฉันกดปุ่ม Home บน Bottom Nav ฉันต้องการให้ฟีดเลื่อนขึ้นบนสุดหรือรีเฟรชข้อมูล เพื่อให้ดูโพสต์ใหม่ๆ ได้สะดวก — พฤติกรรมมาตรฐานเดียวกับแอปโซเชียลทั่วไป (Instagram/Twitter/TikTok) เมื่อแตะ tab ที่เลือกอยู่แล้วซ้ำ

Target User: ผู้ใช้ WYN Social ทุกคนที่ใช้ Home tab

Problem: แตะปุ่ม Home บน Bottom Nav ซ้ำขณะที่อยู่ Home tab อยู่แล้วไม่ทำอะไรเลย — ผู้ใช้ที่เลื่อนฟีดลงไปไกลต้องเลื่อนกลับขึ้นเองด้วยมือ ไม่มีทางลัดกลับไปดูโพสต์ล่าสุดเร็วๆ

Requirements:

R1. Case 1 — Scroll Position > 0: แตะ Home tab ขณะอยู่ Home tab อยู่แล้วและเลื่อนฟีดลงมาแล้ว (scroll position > 0) → เลื่อนกลับขึ้นบนสุดแบบ animate เท่านั้น ไม่ต้อง fetch ข้อมูลใหม่
R2. Case 2 — Scroll Position == 0: แตะ Home tab ขณะอยู่บนสุดอยู่แล้ว (scroll position == 0) → trigger pull-to-refresh (แสดง RefreshIndicator เดียวกับที่ลากรีเฟรชเอง แล้วโหลดฟีดใหม่)
R3. Edge case — ป้องกันการเรียก API ซ้ำเมื่ออยู่ระหว่าง Loading: ถ้ากำลังโหลดข้อมูลอยู่แล้ว (initial load หรือ refresh ค้างอยู่) การแตะ Home tab ซ้ำต้องไม่ trigger การเรียก API ซ้อนอีกครั้ง
R4. ใช้ได้กับทุกโหมดของ feed-mode selector (สำหรับคุณ/ติดตาม/ล่าสุด) — โหมด "จาก Club ของคุณ" ไม่มี refresh อยู่แล้วเดิม (RefreshIndicator.onRefresh เป็น no-op สำหรับโหมดนี้มาตั้งแต่ WYN-024) จึงไม่อยู่ใน scope การ fetch ใหม่ แต่ scroll-to-top (Case 1) ยังทำงานเหมือนกันทุกโหมดเพราะเป็นแค่ scroll position ของ CustomScrollView เดียวกัน ไม่ผูกกับโหมด

Acceptance Criteria:
- [x] Case 1: Scroll Position > 0 → Scroll to Top (ไม่ fetch ซ้ำ)
- [x] Case 2: Scroll Position == 0 → Trigger Pull-to-Refresh
- [x] Edge Case: ป้องกันการเรียก API ซ้ำเมื่ออยู่ระหว่าง Loading
- [x] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression

Dependencies: ไม่มี — ต่อยอด RootShell (WYN-024) และ HomeFeedScreen (WYN-007/017/018/023/024) ที่ผ่าน QA แล้วทั้งคู่ ไม่แตะ schema/RLS

Priority: กลาง — UX quality-of-life ที่คุ้นเคยจากแอปโซเชียลทั่วไป ความเสี่ยงต่ำ ไม่บล็อกอะไร

Risks: ต่ำ — ไม่มี schema change, ไม่แตะ repository/API ใดๆ เป็นแค่ UI-layer interaction ใหม่ ความเสี่ยงหลักคือ nested-scroll edge case ในโหมด "จาก Club ของคุณ" (`FromYourClubsFeed` มี scrollable ของตัวเองซ้อนอยู่ใน `SliverFillRemaining(hasScrollBody: true)`) — scoped ไว้แล้วว่า scroll-to-top ยังทำงาน (เลื่อน CustomScrollView หลักกลับขึ้นบน) แต่ refresh ไม่ทำอะไรในโหมดนี้ ตรงกับพฤติกรรม RefreshIndicator เดิมที่มีอยู่แล้ว

Recommendation: ไม่ต้องมี Design spec แยก — เป็น interaction fix ล้วนๆ ที่ reuse RefreshIndicator/ScrollController ที่มีอยู่แล้วทั้งคู่ ส่งตรง AI Coding ได้เลย

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบอิสระตาม Acceptance Criteria ทั้งหมด รวมถึงยืนยัน `flutter analyze`/`flutter test` ด้วยตัวเอง ไม่เชื่อตัวเลขที่ Coding รายงานเพียงอย่างเดียว

---

## Coding Output (2026-08-24)

**Implementation**:
- `app/lib/features/home/presentation/home_feed_screen.dart`: เพิ่ม `homeTabReselectSignal` (`ValueNotifier<int>`, required param) — `HomeFeedScreen` listen ผ่าน `initState`/`dispose` มาตรฐาน เมื่อค่าถูก bump: ถ้า `_scrollController.position.pixels > 0` → `animateTo(0, duration: 300ms, curve: easeOut)` (Case 1, ไม่ fetch ซ้ำ) ไม่งั้นถ้า `_isLoadingInitial` เป็น false → `_refreshIndicatorKey.currentState?.show()` (Case 2 — trigger UI ของ RefreshIndicator จริงเหมือนลากมือเอง ไม่ใช่เรียก `_loadInitial()` ตรงๆ เฉยๆ) ถ้า `_isLoadingInitial` เป็น true → ไม่ทำอะไรเลย (R3 guard)
- `app/lib/features/root/presentation/root_shell.dart`: เพิ่ม `_homeTabReselectSignal` (`ValueNotifier<int>`, สร้างครั้งเดียวใน State, dispose ใน `dispose()` ใหม่ที่เพิ่มเข้ามา) — `_onDestinationSelected` เช็คก่อน logic เดิมทั้งหมดว่าแตะ Home destination ขณะที่ `_tabIndex` เป็น Home tab อยู่แล้วหรือไม่ ถ้าใช่ bump signal แล้ว `return` ทันที (ไม่ `setState`เพราะ `_tabIndex` ไม่เปลี่ยน) ส่ง signal เข้า `HomeFeedScreen` ผ่าน constructor

**Files Changed**:
- `app/lib/features/home/presentation/home_feed_screen.dart`
- `app/lib/features/root/presentation/root_shell.dart`
- `app/test/home_feed_screen_test.dart` (เพิ่ม group "Tap Home Tab to Scroll to Top & Refresh (WYN-064)" 3 เทส + `_DelayedHomeRepository` helper + `hasImage` param บน `_dropItem`)
- `app/test/root_shell_test.dart` (เพิ่ม 1 เทสยืนยันการ wiring ไม่ crash และไม่เปลี่ยน tab)

**Reason**: ตรงตาม Requirements R1-R4 ทุกข้อ — `ValueNotifier` แทน `GlobalKey<State>` เพราะ `_HomeFeedScreenState` เป็น private และ `RootShell` อยู่คนละไฟล์ (ดู doc comment บน `homeTabReselectSignal` field) — `RefreshIndicatorState.show()` แทนการเรียก `_loadInitial()` ตรงๆ เพื่อให้ผู้ใช้เห็น spinner ของ pull-to-refresh จริงเหมือนลากเอง ไม่ใช่แค่ข้อมูลเปลี่ยนเงียบๆ

**Tests**: `flutter analyze` — 0 issues. `flutter test` (ทั้ง suite) — **768/768 PASS** (เพิ่มจาก 766 เดิม ก่อนรวม WYN-065's +2 อีก 2 เทส) ไม่มี regression กับ Home/RootShell เดิมทั้งหมด — 3 เทสใหม่ครอบคลุมทั้ง 2 Case + Edge Case ตรงตาม Acceptance Criteria ทุกข้อ (เทส Edge Case ใช้ `_DelayedHomeRepository` ที่มี `Completer` ค้างไม่ resolve แทนการพึ่ง microtask-timing ของ repository ที่ resolve ทันที — เจอปัญหา `pumpAndSettle` ค้างกับ `CircularProgressIndicator` ที่ animate ไม่สิ้นสุดระหว่างพัฒนา แก้ด้วยการไม่ resolve completer เลยแล้วจบเทสด้วย `pump()` ธรรมดา ตรงกับ pattern ที่มีอยู่แล้วใน `settings_screen_test.dart`/`zoky_checkout_summary_screen_test.dart`)

**Known Issues**: ไม่มี — ยังไม่เคยทดสอบกับ Supabase project จริง (เหมือนทุก feature ก่อนหน้าที่รอ infra จาก Founder)

**Handoff**: ส่งต่อ AI QA & Security — เน้นตรวจ: (1) ทดสอบจริงบนอุปกรณ์/emulator ว่า scroll animation และ RefreshIndicator แสดงผลถูกต้อง (widget test พิสูจน์ scroll position/call count ได้ แต่ไม่เห็นภาพจริง) (2) โหมด "จาก Club ของคุณ" — ยืนยันว่า scroll-to-top ยังทำงาน (ไม่ error) แม้มี nested scrollable ซ้อนอยู่
