# Bug Report — ZOKY-125 (Store grid card photo is 4:3, Founder decision says food photos are 1:1)

Status: bugs
Severity: **MEDIUM** (Founder decision deviation; needs PM/Design to confirm scope before fixing)
Owner: AI Debug Engineer (after PM/Design confirmation)
Found by: AI QA & Security — Home slice QA round, 2026-10-17, branch `docs/zoky-foundation` @ 895367c

Bug:
DECISIONS.md "[2026-10-17] ZOKY — รูปอาหารทุกจุดเป็น 1:1": menu photos and store photos use 1:1 to match the web (`.wf-menu-image`, `.wf-home-store-photo`) so "ร้านอัปโหลดรูปแบบเดียวใช้ได้ทุกที่". The Home recommended card (1:1) and menu rows (square) follow it, but `ZokyStoreCard._Photo` (`zoky_app/lib/core/widgets/zoky_store_card.dart`) is `AspectRatio(4 / 3)`. This grid is reached from Home ("ค้นหาของอร่อย" and recommended "ดูทั้งหมด"), so the same store's square upload is cropped differently one tap after Home.

Reproduction: Home → "ดูทั้งหมด" (ร้านอาหารแนะนำ) → measure the card photo: width:height = 4:3. Code: `aspectRatio: 4 / 3` in `_Photo.build`.

Expected: 1:1, unless PM/Design rule that the grid card (design 9.4) is not a "food photo" — then record the exception in the design system.

Actual: 4:3.

Root Cause: grid card predates the 1:1 decision (design 9.4 still says 4:3).

Fix (direction): change the ratio to 1 and update design 9.4, or document the exception. Check overlay positions (ad/closed/promo/ETA) after the change.

Files Changed: (for Debug) `zoky_store_card.dart`, `.wyn/docs/design/zoky-design-system.md` §9.4.

Tests: add an aspect-ratio assertion to the grid card tests.

Regression Risk: Low; grid rows get taller.

Handoff to QA: verify grid at 320–430 × 1.0/1.3 with overlays, and the demo label (see ZOKY-123).
