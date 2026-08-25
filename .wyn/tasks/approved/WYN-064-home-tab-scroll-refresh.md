# Product Task — WYN-064

Status: DEPLOYED (2026-08-25) — live ที่ https://web-neon-sigma-66.vercel.app (deploy run 32841558301 -- run 32837045512 ก่อนหน้าลงผิด Vercel project, ดู CORRECTION ใน deploy log) ดูรายละเอียดเต็มที่ `.wyn/logs/deployments/2026-08-25-wyn-071-064-065-real-deploy.md`
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (เสร็จ, PASS)

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

---

## QA & Security Review

Feature: Tap Home Tab to Scroll to Top & Refresh (WYN-064)
Environment: Flutter 3.47.1 (SDK ที่ติดตั้งไว้ในเซสชันก่อนหน้า, re-verified ในรอบนี้) — ไม่มี emulator/device จริงสำหรับ manual UI testing

Test Cases:
- อ่าน diff จริงทุกบรรทัดของ `root_shell.dart`/`home_feed_screen.dart` (ไม่เชื่อ summary ใน Coding Output อย่างเดียว)
- รัน `flutter analyze` อิสระ — ยืนยัน 0 issues
- รัน `flutter test` เต็ม suite อิสระ — ยืนยัน 768/768 PASS ตรงกับตัวเลขที่ Coding รายงาน ไม่มีความคลาดเคลื่อน
- ตรวจ `_onDestinationSelected` ว่า bump signal เฉพาะกรณีแตะ Home ขณะอยู่ Home tab อยู่แล้วเท่านั้น (ไม่ bump ตอนสลับ tab เข้า Home จาก tab อื่น) — อ่านโค้ดแล้วตรงตามที่ตั้งใจ
- ไล่หา race condition ด้วยมือ (adversarial, ไม่มี tool อัตโนมัติช่วย): double-tap รัวขณะ scroll animation ยังไม่จบ, bump signal ก่อน widget mount, `_refreshIndicatorKey.currentState` เป็น null, dispose order ระหว่าง `HomeFeedScreen`/`RootShell` — ไม่พบ crash หรือ behavior ผิดในทุกกรณีที่ไล่ตรวจ (guard `!mounted`/`!hasClients`/`?.` ครบทุกจุดเสี่ยง)
- ตรวจว่า Case 1 (`pixels > 0`) return ก่อนถึงเงื่อนไข `_isLoadingInitial` เสมอ — ยืนยันว่าตรงตาม AC "ไม่ fetch ซ้ำ" แม้ระหว่างมี fetch ค้างอยู่พร้อมกัน
- ยืนยันว่า pull-to-refresh ทั้งจากการลากมือเองและจาก Case 2 ใช้ `_loadInitial` ตัวเดียวกัน (ตั้ง `_isLoadingInitial = true` ทันทีแบบ synchronous ก่อน `await` แรก) → guard R3 ครอบคลุมทั้ง "initial load" และ "refresh ค้างอยู่" ตามที่ AC ระบุจริง ไม่ใช่แค่ initial load อย่างเดียว
- ตรวจ `root_shell_test.dart`'s wiring test — ยืนยันว่าแตะ Home ขณะอยู่ Home ไม่เปลี่ยน tab ไม่ crash ไม่รีเซ็ต visit-key ของ tab อื่น
- Secret scan บน diff ที่เกี่ยวข้อง — ไม่พบ credential/token หลุด

Passed:
- Case 1 (Scroll Position > 0 → Scroll to Top ไม่ fetch ซ้ำ) — ยืนยันด้วย test จริง + อ่านโค้ด
- Case 2 (Scroll Position == 0 → Trigger Pull-to-Refresh) — ยืนยันด้วย test จริง + อ่านโค้ด
- Edge Case (กันเรียก API ซ้ำระหว่าง Loading) — ยืนยันด้วย test ที่ใช้ `_DelayedHomeRepository` ค้าง fetch จริง ไม่ใช่แค่ mock resolve ทันที
- ใช้ได้ทุกโหมด feed-mode selector ตามที่ระบุ (โหมด "จาก Club ของคุณ" scroll-to-top ยังทำงาน, refresh เป็น no-op ตรงตามพฤติกรรมเดิมจาก WYN-024)
- ไม่มี regression กับ Home/RootShell/Profile/Notifications tab เดิม

Failed: ไม่มี

Severity: N/A (ไม่มีรายการ FAIL)

Security Findings:
- ไม่พบ secret/credential หลุดใน diff นี้
- ไม่แตะ schema/RLS/API/repository ใดๆ เป็น UI-layer interaction ล้วนๆ ตามที่ Coding ระบุไว้ — ยืนยันตรงจริงจากการอ่าน diff ทั้งหมด ไม่มี surface ด้านความปลอดภัยใหม่เกิดขึ้น

Recommendation:
- ยังไม่เคยเห็นภาพเคลื่อนไหวจริงบนอุปกรณ์/emulator (สภาพแวดล้อมนี้รันได้แค่ widget test) — แนะนำให้ Founder ทดสอบความรู้สึกของ scroll animation (300ms easeOut) และ RefreshIndicator บนมือถือจริงก่อนถือว่าสมบูรณ์ 100% ด้าน UX-feel (ไม่ใช่ functional correctness ซึ่งยืนยันแล้ว)
- ไม่มี recommendation ด้านอื่นเพิ่มเติม — งานนี้ scope เล็ก ความเสี่ยงต่ำ implement ตรงตาม AC ครบ

Final Status: **PASS**
