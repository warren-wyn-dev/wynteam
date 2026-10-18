# Bug Report — ZOKY-128 (Home + Food: icons still drawn from icon fonts — blank on a stale/tree-shaken font)

Status: **fixed — awaiting QA re-test**
Severity: **MEDIUM** (Founder-reported iPad bug class: icons render as empty space when the icon font is stale; the food back arrow and the search magnifier are primary navigation cues). Not HIGH: native iOS/Android builds bundle a matching font; the failure needs a web preview refreshed by copying only `main.dart.js`, which is exactly how the Founder previews today. Controls keep their tap targets and screen-reader labels.
Owner: AI Debug Engineer
Found by: AI QA & Security — Food page round, 2026-10-18, branch `docs/zoky-foundation` @ 46a8f0c

Bug:
Commit 5d4d6cf ("paint food page icons that a stale icon font left blank") moved only 7 glyphs to `ZokyLineIcon`. The approved design note says the Food page uses painted, font-independent icons, but these `Icon(IconData)` (MaterialIcons / CupertinoIcons font) remain on the Home + Food flow:

| Where | Icon | File |
|---|---|---|
| Food header back | `CupertinoIcons.back` (iOS) / `Icons.arrow_back` | `lib/features/food/widgets/zoky_food_header.dart:252` (`ZokyIcons.back`) |
| Food search field | `ZokyIcons.search` | `lib/features/food/widgets/zoky_food_search_field.dart:69` |
| "ดูทั้งหมด >" (Food coupons + Home sections) | `ZokyIcons.chevronRight` | `lib/features/home/widgets/zoky_home_section_header.dart:66` |
| Store row "ปิดอยู่" label | `ZokyIcons.clock` | `lib/features/food/widgets/zoky_food_store_row.dart:108/286` |
| Address sheet selected address | `Icons.check_circle_rounded` (only visual marker of the selection) | `lib/features/address/address_sheet.dart:214` |
| Address sheet pin / demo note / add | `ZokyIcons.location`, `info`, `add` | `address_sheet.dart:123,180,255` |
| Favorites sheet | `ZokyIcons.favorite` | `lib/features/home/home_screen.dart:106` (ZokyStateView) |
| Food offline / empty states, category offline line | `ZokyIcons.wifiOff`, `ZokyIcons.store` | `food_home_screen.dart:540,561,567`, `zoky_food_category_row.dart:70` |
| Cover placeholder (no art) | `ZokyIcons.food` | `lib/features/home/widgets/zoky_store_cover.dart:95` |

Reproduction:
1. `flutter test test/qa/food_page_qa_test.dart --run-skipped --plain-name "icon robustness"` → fails and prints `QA-FONT-ICONS` (the list above, iOS variant).
2. Manual (as the Founder's iPad): build web, copy only the new `main.dart.js` over an older build whose tree-shaken `MaterialIcons`/`CupertinoIcons` fonts lack these code points → empty space at the food back button, search field, "ดูทั้งหมด", address check.

Expected: Every icon on Home + Food (incl. their sheets and loading/empty/error states) renders without depending on an icon font (as the 3D/line glyphs do), or the deploy process guarantees fonts and JS ship together (DevOps decision).

Actual: 11 font glyphs remain (list above).

Root Cause (preliminary, QA): the 5d4d6cf fix covered only the glyphs that were seen blank on the iPad, not the whole icon vocabulary of the flow.

Fix (direction, Debug/Design decide): add the missing glyphs to `ZokyLineIcon` (back chevron, search, chevron-right, clock, check-circle, pin, info, plus, wifi-off, store, heart outline) and use them in the files above; and/or fix the preview deploy to always replace `assets/fonts/` with `main.dart.js`. Keep labels/tooltips unchanged.

Files Changed:
Tests: `zoky_app/test/qa/food_page_qa_test.dart` — "icon robustness" (skipped repro, ZOKY-128).
Regression Risk: Low (visual only); re-run `food_header_icons_test.dart` (non-empty pixel checks) for new glyphs.
Handoff to QA: un-skip the repro; check pixels non-empty for each new glyph; check iOS/Android back glyph still adaptive.

## Debug Engineer — 2026-10-18 (commit b91a5cb)

Reproduction: `food_page_qa_test.dart --run-skipped --plain-name "icon robustness"` printed 21 font-icon hits (back, search, chevronRight, check_circle, location, info, add, favorite, wifiOff, store) across food / address sheet / favorites sheet / error / empty / Home.

Root Cause (confirmed): 5d4d6cf moved only the 7 glyphs seen blank on the iPad to `ZokyLineIcon`; the rest of the Home + Food icon vocabulary still used `Icon(IconData)` from the MaterialIcons/CupertinoIcons fonts, which go blank when only `main.dart.js` is replaced over an older tree-shaken font.

Fix: new painted `ZokyLineGlyph`s (`chevronLeft`, `arrowLeft`, `chevronRight`, `search`, `clock`, `checkCircle`, `pin`, `info`, `plus`, `wifiOff`, `store`, `heart`, `utensils`) used on: food header back (adaptive: iOS chevron / Android arrow, label/tooltip unchanged), search field, "ดูทั้งหมด ›" (Home + Food), "ปิดอยู่" label, address sheet (check, pin, demo note, add), favorites sheet, food offline/empty states, category offline line, cover placeholder. `ZokyStateView` takes an optional `glyph`. Every icon keeps its old box size.

Home: only the "ดูทั้งหมด ›" chevron changed. It reuses the Material `chevron_right_rounded` centre line with the same ink weight, same 18pt box and position. Pixel diff against the pre-change build (Anuphan + MaterialIcons fonts loaded, 390/320/430pt, text 1.0/1.3/2.0, iOS + Android): everything identical except 25–74 anti-aliasing pixels inside each chevron's 6×10px area (ink centroid shift <= 0.5px, because the font glyph snaps to the pixel grid and a path does not).

Files Changed: `lib/core/widgets/zoky_line_icon.dart`, `lib/core/widgets/zoky_state_view.dart`, `lib/core/adaptive/zoky_icons.dart` (doc), `lib/features/food/widgets/{zoky_food_header,zoky_food_search_field,zoky_food_store_row,zoky_food_category_row}.dart`, `lib/features/food/food_home_screen.dart`, `lib/features/address/address_sheet.dart`, `lib/features/home/home_screen.dart`, `lib/features/home/widgets/{zoky_home_section_header,zoky_store_cover}.dart`.

Tests: QA "icon robustness" un-skipped and passing (0 font icons). `food_header_icons_test.dart`: every glyph draws pixels (generic sheet), plus new in-place pixel checks for back (iOS + Android), search, "ดูทั้งหมด", address sheet, favorites heart and the Home chevron. `food_home_screen_test.dart` "back button is adaptive" now checks the painted glyphs.

Regression Risk: Low (visual only). Other screens (store, search, deals, orders, account) still use font icons; out of scope for this bug.

Handoff to QA: re-run the audit; spot-check glyphs on iOS/Android; web preview with only `main.dart.js` replaced.
