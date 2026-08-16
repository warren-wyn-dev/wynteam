# Bug Report — ZOKY-004 (StoreScreen header rating row)

Status: closed (แก้แล้ว ผ่าน QA — PASS, 2026-08-16). **Discovered by AI QA & Security during SELLER-004 round 2 verification (2026-08-15), was not blocking SELLER-004's approval** (see rationale below).
Owner: AI Debug Engineer (เสร็จ) → AI QA & Security (PASS)
Found by: AI QA & Security, while independently re-measuring `StoreScreen`'s device matrix for SELLER-004's BUG-1 round 2 verification.

Bug: `StoreScreen`'s `_buildHeader` rating row (`app/lib/features/zoky/presentation/store_screen.dart`, inside the `FutureBuilder<(double, int)>` that reads `_ratingFuture`) renders `Row(children: [StarRatingDisplay(...), SizedBox(width: 4), Text('${rating} · 0 ผู้ติดตาม · ${productCount} สินค้า')])` with **no `Expanded`/`Flexible` around the `Text`**. At any real phone width (360–430px logical), the available width for this Row (screen width minus the 16px side padding ×2 minus the 32px+16px logo circle) is only ~278px, which is narrower than the star icons + text combined whenever the store has **at least 1 review** (i.e. `rating.$2 != 0`, the branch that actually shows stars). This produces a `RenderFlex overflowed ... on the right` error.

This is **not caused by SELLER-004** — confirmed via `git log`/`git show` that this exact unwrapped `Row` has existed unchanged since ZOKY-004 introduced the rating display (commit `135af7a`). SELLER-004 (commits `0bf5253`, `f7035c8`) never touched this Row. It was never caught by any prior QA round (ZOKY-004 round 1/2, SELLER-004 round 1/2) because every `StoreScreen` test that exercises a rated store ran at `flutter_test`'s default 800×600 viewport, which is wide enough (688px available) that the overflow never triggers — the exact same blind spot documented in `.wyn/tasks/bugs/SELLER-004-store-screen-header-overflow.md` (BUG-1), just in a different Row of the same header.

Reproduction (widget test, `tester.view.physicalSize` set to a real phone size, `FlutterError.onError` captured directly — not `tester.takeException()`):

1. Build a `Store` with any name/productCount and a `RecordingZokyRepository` whose `storeRating` is any non-zero-count tuple, e.g. `(4.5, 1)`.
2. `pumpWidget(MaterialApp(home: StoreScreen(...)))`, `pumpAndSettle()`.
3. Observe a `FlutterError` containing `overflowed ... on the right` from `RenderFlex#... store_screen.dart:286` (the rating `Row`).

Measured overflow amount across the standard SELLER-004 device matrix (all with a plain, non-rated-by-default store, `storeRating: (4.5, 1)`, no banner/info fields at all — this is the *minimum* trigger, not an edge case):

| Viewport | Overflow |
|---|---|
| 360×640 | 235 px |
| 375×667 | 220 px |
| 390×844 | 205 px |
| 430×932 | 165 px |

The overflow shrinks as the screen widens but does not disappear at any phone size tested. It is independent of `productCount`/description length — the *minimum* rated-store text ("4.5 · 0 ผู้ติดตาม · 1 สินค้า" + 5 star icons) already overflows.

Expected: Any store with reviews shows its aggregate rating on `StoreScreen` without a layout overflow, on any real phone width.

Actual: `RenderFlex` overflow of 165–235px on every phone width tested, for literally any store with ≥1 review. In a debug/profile build this renders the yellow-black overflow stripe over the header; in a release build the affected Text/Row silently clips, likely hiding part of the "X ผู้ติดตาม · Y สินค้า" text from the user.

Root Cause (preliminary, from reading the code — Debug Engineer should confirm independently per project convention): the `Text` sibling of `StarRatingDisplay` inside the `Row` has no `Expanded`/`Flexible` wrapper, so it sizes to its own natural (unwrapped) width instead of being constrained to the remaining space in the Row. The `rating == null || rating.$2 == 0` branch just above it returns a bare `Text` with no `Row` at all, which is why *unrated* stores never hit this (a lone `Text` inside a `Column` wraps normally instead of overflowing).

Suggested Fix direction (not yet implemented — for the assigned Debug Engineer to verify/adjust): wrap the `Text` in `Expanded` (matching how `_buildStoreInfoSection`'s address/business-hours rows already wrap their `Text` in `Expanded`) and add `overflow: TextOverflow.ellipsis` so the text wraps/truncates instead of pushing past the Row's bounds. Re-run the full SELLER-004 BUG-1 device matrix (360×640, 375×667, 390×844+1.3, 430×932+1.3, landscape) with `storeRating` set on every case, since none of BUG-1's own regression tests set a non-zero rating — that's precisely why this second Row's bug slipped through the same fix.

Files likely affected: `app/lib/features/zoky/presentation/store_screen.dart` (`_buildHeader`'s rating `Row`, ~line 286). Possibly `app/test/store_screen_test.dart` (add a device-matrix case with `storeRating` set, mirroring BUG-1's own matrix additions).

Regression Risk: Low — the fix is a single `Expanded` wrap, same shape as the existing (already-correct) `_buildStoreInfoSection` rows right below it in the same file. Should not affect any other behaviour.

Why this does not block SELLER-004's round 2 approval: SELLER-004's own Acceptance Criteria, Requirements, and the specific BUG-1 fix under test (banner + "ข้อมูลร้านค้า" section causing the header to collapse `TabBarView` to 0 height) are all independently verified working correctly (see SELLER-004's QA round 2 output). This finding is in an unrelated, unmodified-by-SELLER-004 code path that predates SELLER-004 by two features (ZOKY-004). Per standard triage, a newly-discovered pre-existing defect outside a task's scope and Acceptance Criteria does not block that task's approval, but must be filed and reported for prompt follow-up given its severity (affects essentially any rated store on any real phone).

Handoff to QA: once fixed, re-verify with the full SELLER-004 BUG-1 device matrix but with `storeRating` set to a non-zero-count value on every case (this is the exact gap that let this bug ship unnoticed through both SELLER-004 QA rounds).

---

## Debug Output (AI Debug Engineer — 2026-08-15)

```
Bug:
`StoreScreen`'s rating `Row` (`app/lib/features/zoky/presentation/store_screen.dart`,
`_buildHeader`, inside the `FutureBuilder<(double, int)>` ที่อ่าน `_ratingFuture`) วาง
`StarRatingDisplay` + `SizedBox(4)` + `Text('${rating} · 0 ผู้ติดตาม · ${productCount} สินค้า')`
ใน Row โดยไม่มี Expanded/Flexible ครอบ Text เลย ทำให้ Text ขยายตามความกว้างธรรมชาติของ
ข้อความแทนที่จะถูกบีบให้พอดีกับพื้นที่ที่เหลือของ Row — เกิด RenderFlex overflow ทุกครั้งที่
ร้านมีรีวิว ≥1 (สาขา `rating.$2 == 0` ที่คืนแค่ Text เปล่าไม่มี Row เลยไม่โดน)

Reproduction (ทำเองก่อนแก้ ไม่ได้เชื่อ bug report เฉย ๆ):
  ขยาย `app/test/store_screen_test.dart` ด้วยชุด `_ratedViewportCases` (360x640, 375x667,
  390x844@1.3, 430x932@1.3 — ตาราง device matrix เดียวกับ BUG-1/SELLER-004) ใช้
  `RecordingZokyRepository` ที่ตั้ง `storeRating: (4.5, 1)` (ร้านไม่มี banner/info field ตาม
  "minimum trigger" ที่ QA ระบุ) แล้ว pump ผ่าน `pumpAtViewport` เดิม (physicalSize จริง,
  devicePixelRatio 1.0) พร้อมดัก FlutterError.onError เก็บ error ทุกตัวเอง (ไม่ใช้
  tester.takeException() ตามบทเรียนจาก SELLER-004)
  ผลวัดเองก่อนแก้ (Flutter 3.47.0) — ยืนยันบั๊กจริงทุกเคส (ตัวเลขต่างจากตารางใน bug report
  เล็กน้อยเพราะ fixture มี description สั้น ๆ ติดมาด้วย แต่อาการ/ทิศทางตรงกันทุกประการ):
    | ขนาดจอ                              | overflow ที่วัดได้ |
    | 360x640                             | 235 px |
    | 375x667                             | 220 px |
    | 390x844 @ textScaler 1.3            | 322 px |
    | 430x932 @ textScaler 1.3            | 282 px |
  ทั้ง 4 เคส FAIL ด้วย `RenderFlex overflowed ... on the right` ตรงตามที่ bug report คาดไว้
  — ยืนยัน root cause ตรงกับที่ QA เสนอไว้ทุกจุด ไม่ต้องปรับสมมติฐาน

Root Cause (ยืนยันเองจากโค้ดจริง ไม่ได้ลอกจาก bug report):
  `Row` ที่บรรทัด ~286 ของ `_buildHeader` มี children สามตัว (`StarRatingDisplay`,
  `SizedBox(width: 4)`, `Text(...)`) — ไม่มีตัวไหนถูกครอบด้วย `Expanded`/`Flexible` เลย
  `Text` จึงพยายามใช้ความกว้างเต็มที่ข้อความต้องการ (ดาว 5 ดวง + ข้อความยาวไม่จำกัดเพราะ
  "X ผู้ติดตาม"/"Y สินค้า" เป็นตัวเลขไม่จำกัดหลัก) ซึ่งเกินพื้นที่ที่เหลือของ Row เสมอบนจอมือถือ
  จริง (พื้นที่ที่เหลือ ≈ ความกว้างจอ − padding 32px − วงกลมโลโก้ 64px+16px) — ต่างจาก
  `_buildStoreInfoSection`'s address/business-hours rows ที่ห่อ Text ด้วย Expanded ไว้แล้ว
  ถูกต้องตั้งแต่ SELLER-004

Fix (เล็กที่สุดที่ถูกต้อง — ไม่แตะโครง Row/FutureBuilder/ข้อมูลที่แสดง):
  ครอบ `Text` ด้วย `Expanded` (มิเรอร์ pattern ของ `_buildStoreInfoSection` ในไฟล์เดียวกัน)
  และเพิ่ม `overflow: TextOverflow.ellipsis` เพื่อให้ตัดข้อความแทนการดันออกนอก Row เมื่อพื้นที่
  แคบมาก (เช่น 360px + textScaler สูง) — ไม่แตะ `StarRatingDisplay`, ไม่แตะ FutureBuilder,
  ไม่เปลี่ยนข้อมูล/ลำดับที่แสดง ไม่แตะ TabBar/NestedScrollView ที่ BUG-1 เพิ่งแก้ไป

Files Changed:
  - app/lib/features/zoky/presentation/store_screen.dart (ครอบ Text ด้วย Expanded +
    overflow: TextOverflow.ellipsis ในสาขา rating.$2 != 0 ของ rating Row, ~5 บรรทัด)
  - app/test/store_screen_test.dart (เพิ่ม `_RatedViewportCase`/`_ratedViewportCases`,
    `ratedViewportRepos`, และ test loop ใหม่ 4 เคสที่ตั้ง storeRating ไม่เป็นศูนย์บน device
    matrix เดียวกับ BUG-1 — เคสเดิมทั้งหมดไม่ถูกแก้ไข)

Tests:
  ผลวัดหลังแก้ (red→green พิสูจน์จริง ไม่ใช่แค่คาดเดา):
    | ขนาดจอ                              | overflow ก่อนแก้ | หลังแก้ |
    | 360x640                             | 235 px            | ไม่มี |
    | 375x667                             | 220 px            | ไม่มี |
    | 390x844 @ textScaler 1.3            | 322 px            | ไม่มี |
    | 430x932 @ textScaler 1.3            | 282 px            | ไม่มี |
  ทั้ง 4 เคสใหม่ยังยืนยันเพิ่มว่าข้อมูล rating ("4.5" / "0 ผู้ติดตาม" / "1 สินค้า") ยังแสดงครบ
  ทุกชิ้นหลังแก้ ไม่ถูกตัดหายไปเงียบ ๆ
  `flutter analyze`: No issues found!
  `flutter test` (ทั้ง `app/`): 280/280 ผ่าน (276 เดิม + 4 เคสใหม่) — ไม่แตะ `seller_app/` เลย
  ตามขอบเขตงาน

Regression Risk:
  ต่ำ — การแก้เป็นการห่อ Expanded รอบ Text ตัวเดียวใน Row ที่มีอยู่แล้ว มิเรอร์ pattern ที่
  ถูกต้องอยู่แล้วในไฟล์เดียวกัน (`_buildStoreInfoSection`) ไม่แตะโครง NestedScrollView/TabBar/
  SliverOverlapAbsorber ที่ BUG-1 (SELLER-004) เพิ่งแก้ไป — regression suite ทั้ง BUG-1's
  device-matrix cases (banner/info section) ยัง PASS ครบทุกเคสหลังแก้ ยืนยันว่าไม่ชนกัน

Handoff to QA:
  ตรวจซ้ำด้วย SELLER-004 BUG-1 device matrix เดิม + เคสใหม่ 4 เคสของบั๊กนี้ (`storeRating`
  ไม่เป็นศูนย์) ครบทุกขนาดจอ (360x640, 375x667, 390x844@1.3, 430x932@1.3) ยืนยันว่า
  (1) ไม่มี RenderFlex overflow ใน rating Row อีก (2) ข้อความ rating ("X.X · Y ผู้ติดตาม ·
  Z สินค้า") ยังแสดงถูกต้องครบ ตัดด้วย ellipsis เฉพาะกรณีพื้นที่แคบมากจริง ๆ (3) BUG-1's
  banner/"ข้อมูลร้านค้า" fix ยังทำงานปกติไม่มี regression (4) `flutter analyze`/`flutter test`
  สะอาดทั้ง `app/` (280/280)
```

---

## QA Verification (AI QA & Security — 2026-08-16)

```
Feature: ZOKY-004 StoreScreen rating row overflow fix (commit 0925061, PR #118)
Environment: Local Flutter 3.47.0 stable SDK (installed fresh this session), synced to current
  main/branch tip -- ran independently rather than trusting Debug's reported numbers.
Test Cases:
  1. Read the current source directly (app/lib/features/zoky/presentation/store_screen.dart,
     _buildHeader ~line 286) and confirm the fix matches what Debug Output claims: the rating
     Text is now wrapped in Expanded with overflow: TextOverflow.ellipsis, mirroring
     _buildStoreInfoSection's existing (correct) address/business-hours Expanded pattern.
     StarRatingDisplay, the FutureBuilder, and the unrated-store branch are untouched.
  2. git log confirms the fix is committed and merged (0925061, "fix(zoky): wrap StoreScreen
     rating row Text in Expanded to stop overflow", PR #118), on top of f7035c8 (BUG-1/
     SELLER-004's separate header fix) -- correct layering, no rebase/history surprises.
  3. Confirm app/test/store_screen_test.dart actually contains the 4 new device-matrix cases
     (_RatedViewportCase/_ratedViewportCases, ratedViewportRepos with storeRating: (4.5, 1))
     Debug Output describes, not just claims to.
  4. Run `flutter analyze` independently (not reusing Debug's reported output).
  5. Run the full `flutter test` suite independently (all of app/, not just store_screen_test.dart)
     to catch any regression outside the file Debug touched.
  6. Specifically verify the 4 rated-viewport overflow cases and all pre-existing BUG-1
     (SELLER-004) device-matrix cases (banner/"ข้อมูลร้านค้า" section, 360x640/375x667/390x844)
     are present in the pass list, not just that the aggregate count matches.
Passed: 6/6
Failed: 0
Severity: N/A (verification of an already-applied fix, not a new finding)
Reproduction Steps: `cd app && flutter analyze && flutter test`, full suite, no filtering.
Expected: 0 analyzer issues; every test passes including the 4 new rated-viewport cases and all
  pre-existing BUG-1 device-matrix cases; no RenderFlex overflow error surfaces via
  FlutterError.onError at any tested viewport for a store with reviews.
Actual:
  - `flutter analyze`: "No issues found!" (15.7s) -- matches Debug Output exactly.
  - `flutter test`: **280/280 passed**, 0 failures -- independently reproduces Debug's reported
    count exactly, not just trusted at face value.
  - Explicitly confirmed present and passing in the run's own output: "rating row does not
    overflow for a store with reviews -- 430x932 (iPhone 15 Pro Max) at textScaler 1.3" (the
    most extreme case in the matrix -- smallest relative margin from combining the largest
    text scaler with review text) plus the 360x640/375x667/390x844 siblings, and all of
    BUG-1's own pre-existing device-matrix cases ("tab content is reachable at full height and
    never overflows", banner/info-section regression cases) -- confirming this fix did not
    regress the unrelated header-collapse bug SELLER-004 fixed one commit earlier.
  - Source read confirms the fix is the minimal, correct shape: only the rating Row's Text
    gained Expanded + ellipsis; StarRatingDisplay, FutureBuilder, and the unrated-store
    (bare Text) branch are byte-for-byte unchanged -- no scope creep beyond the reported bug.
Security Findings: None. Pure layout fix (Expanded/TextOverflow), no data access, RLS, or
  authorization surface touched.
Recommendation: Approve and close. Fix is minimal, correctly scoped, independently verified
  against a fresh `flutter analyze`/`flutter test` run (not just Debug's self-report), and
  causes no regression in the adjacent BUG-1 fix it sits next to in the same file.
Final Status: PASS
```


