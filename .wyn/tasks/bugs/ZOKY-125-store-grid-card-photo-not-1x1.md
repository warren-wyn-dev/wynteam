# Bug Report — ZOKY-125 (Store grid card photo is 4:3, Founder decision says food photos are 1:1)

Status: verified — QA re-test PASS (2026-10-17)
Severity: **MEDIUM** (Founder decision deviation; needs PM/Design to confirm scope before fixing)
Owner: AI Debug Engineer (after PM/Design confirmation)
Found by: AI QA & Security — Home slice QA round, 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug:
DECISIONS.md "[2026-10-17] ZOKY — รูปอาหารทุกจุดเป็น 1:1": menu photos and store photos use 1:1 to match the web (`.wf-menu-image`, `.wf-home-store-photo`) so "ร้านอัปโหลดรูปแบบเดียวใช้ได้ทุกที่". The Home recommended card (1:1) and menu rows (square) follow it, but `ZokyStoreCard._Photo` (`zoky_app/lib/core/widgets/zoky_store_card.dart`) is `AspectRatio(4 / 3)`. This grid is reached from Home ("ค้นหาของอร่อย" and recommended "ดูทั้งหมด"), so the same store's square upload is cropped differently one tap after Home.

Reproduction: Home → "ดูทั้งหมด" (ร้านอาหารแนะนำ) → measure the card photo: width:height = 4:3. Code: `aspectRatio: 4 / 3` in `_Photo.build`.

Expected: 1:1, unless PM/Design rule that the grid card (design 9.4) is not a "food photo" — then record the exception in the design system.

Actual: 4:3.

Root Cause (confirmed by Debug, 2026-10-17):
`ZokyStoreCard._Photo` is `AspectRatio(aspectRatio: 4 / 3)` (and `ZokyStoreCardSkeleton` matches it) — the card predates the Founder decision "[2026-10-17] ZOKY — รูปอาหารทุกจุดเป็น 1:1", and design §9.4 still said 4:3. Confirmed by the new ratio test (6/6 fail on the old code: width:height = 4:3). Scope confirmed by the CTO task assignment: the decision covers ALL food photos (store and menu), so grid/search/all-stores cards are in scope; no exception recorded.

Fix:
`_Photo` and `ZokyStoreCardSkeleton` use `aspectRatio: 1`; doc comments updated. `ZokyStoreGrid` rows already size to the tallest card (no fixed cell height), so the taller photo cannot overflow. Overlays are positioned from the photo corners, so ad/closed/promo/ETA and the ZOKY-123 demo badge keep their places. Design system §9.4 updated (1:1 + demo badge + rating-with-reviews rule) and the §skeleton note.

Files Changed:
- `zoky_app/lib/core/widgets/zoky_store_card.dart`
- `zoky_app/lib/core/widgets/zoky_skeleton.dart`
- `.wyn/docs/design/zoky-design-system.md` (§9.4 + loading-skeleton note)
- `zoky_app/test/store_card_photo_ratio_test.dart` (new: 320@1.0, 320@1.3, 390@2.0 (1 column), 430@1.0, 932@1.0 (3 columns) — every card photo square, no FlutterError; skeleton square)

Tests: new tests pass; `store_card_demo_badge_test.dart` (320–430 × 1.0/1.3/2.0, no exception, badge/overlay no overlap), `widgets_layout_test.dart` (worst-case busy store with every overlay), shell/hero suites pass.

Regression Risk: Low. Grid rows are taller (photo height +33%), so fewer cards per screen; at text ≥ 1.5 (1 column) the photo is a full-width square. Network photos use `BoxFit.cover`, so a 4:3 upload is cropped to the centre square (intended by the decision).

Debug Engineer: change limited to the ratio constant + docs; the overlay layout was re-checked by the existing busy-store layout test.

Handoff to QA: verify grid at 320–430 × 1.0/1.3 with overlays, and the demo label (see ZOKY-123).

QA Re-test (AI QA & Security, 2026-10-17): **Verified**
- Environment: branch `docs/zoky-foundation` @ 41ddc95, Flutter widget tests (devicePixelRatio 1, FakeViewPadding, real Anuphan font where noted), suite `zoky_app/test/qa/home_slice_retest_qa_test.dart`, real Anuphan font.
- Same 126-case grid matrix as ZOKY-123: every card photo is square (|w−h| ≤ 0.5pt) in 2 columns (320–430 × 1.0–1.45), 3 columns (932) and 1 column (≥ 1.5); overlays stay inside the photo and do not overlap; no overflow.
- Overlay truncation inside the photo is tracked separately in ZOKY-127 (pre-existing; the 1:1 change did not alter photo width).
