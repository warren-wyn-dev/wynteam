# ZOKY Home Slice (Phase 1–5) — CTO Final Review

> โดย WYN CTO | 2026-10-18 | branch `docs/zoky-foundation` @ `58f9bd3` | ขอบเขต: `zoky_app/` Home slice (demo mode ล้วน)
> เป็น read-only review: ไม่แก้ product code, ไม่ push, ไม่ deploy, ไม่ใช้ secrets หรือ backend จริง

## 1. Verdict

**APPROVED WITH CONDITIONS** สำหรับ Home slice ในฐานะ demo-mode UI slice บน branch นี้ ใช้เป็นฐานของ slice ถัดไปได้

- ไม่ใช่ staging/production approval: ยังไม่มี CI, signing, bundle ID ที่อนุมัติ หรือ backend wiring (architecture §16–17) ต้องผ่าน Staging และ Founder Gate ตามปกติ
- ไม่มี finding ระดับ CRITICAL/HIGH ค้าง ZOKY-120..125 และ 127 verified/closed แล้ว ZOKY-124 ปิดเป็น won't-fix (ล็อกแนวตั้ง) ส่วน ZOKY-126 (LOW) ยังเปิดอยู่
- เงื่อนไข (C1–C4 ในข้อ 5) ต้องทำก่อนเริ่ม ZOKY-105/106 (Supabase wiring และ store page จริง)

## 2. หลักฐานที่ตรวจจริง

| ตรวจ | ผล |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` (ทั้งชุด) | 942 passed, 4 skipped, wall time ~151 วินาที |
| `flutter test test/qa` อย่างเดียว | ~128 วินาที (ประมาณ 85% ของเวลาทั้งหมด) |
| Dependencies (`pubspec.yaml`) | `flutter`, `flutter_localizations` (SDK), `cupertino_icons` เท่านั้น ไม่มี third-party runtime package |
| Secrets/env ใน git | ไม่พบไฟล์ env/key/google-services ที่ track ไว้; `AppConfig` รับเฉพาะ anon key ผ่าน `--dart-define` |
| Network ใน demo mode | ไม่มี; มี test "no network in demo mode" ใน `test/qa/home_slice_qa_test.dart` |

สิ่งที่ยังไม่ได้ตรวจ: การรันบนเครื่อง iOS/Android จริง, VoiceOver/TalkBack แบบ manual, frame timing/jank บนเครื่องจริง, network log ของ web preview ในเบราว์เซอร์ (ZOKY-126 ข้อ 1)

## 3. Findings

### 3.1 Architecture และความเรียบง่าย — ผ่าน
- ตรงกับ architecture §3–5: ไม่มี router/state library ใช้ `InheritedWidget` (`lib/app/app_dependencies.dart`) และ constructor injection ส่วน dependency footprint น้อยมาก ถือว่าดี
- `StoreRepository` และ `PromotionRepository` เป็น `abstract interface class` ที่มี Demo impl (`lib/features/catalog/data/`, `lib/features/deals/data/`) ซึ่งสอดคล้องกับ §6.1 ไม่มี `Supabase.instance` ในโค้ด feature

### 3.2 ความพร้อมของ model สำหรับ Supabase (ZOKY-105/106) — พร้อมบางส่วน มีช่องว่าง
เทียบ `ZokyStoreSummary` (`lib/features/catalog/domain/catalog_models.dart`) กับ `FoodDirectoryStore` (`web/lib/food-customer.ts:601`)
- map ได้ตรงตัว: `id`, `name`, `is_open`, `is_ad`, `delivery_fee` (num|string), `categories`, `rating_average`/`rating_count` (num|string), `cover_path` → `coverUrl`
- **ช่องว่าง 1 — ETA/distance:** model ต้องใช้ `distanceKm`/`etaMin/Max` แต่ `fetchDirectory({query})` ไม่มีพารามิเตอร์ location และ model ไม่มี `latitude`/`longitude`/`prep_time_*` ที่ web ใช้คำนวณ `foodEstimateDeliveryRange` จึงต้องตัดสินว่าจะคำนวณใน repository (รับ location) หรือเก็บ raw fields แล้วคำนวณใน pure Dart (R8) ก่อนเริ่ม 106
- **ช่องว่าง 2 — `minimumOrder`:** ไม่อยู่ใน `food_store_directory` (มีใน `food_stores.minimum_order`) demo ใส่ค่าไว้ แต่ Supabase directory ให้ค่านี้ไม่ได้
- **ช่องว่าง 3 — promo ซ้ำสองรูปแบบ:** `ZokyStoreSummary.promoLabel` เป็นข้อความที่ format แล้ว ขณะที่ `ZokyDeal` เก็บ `type/value/minSubtotal` และมี `headline` (foodPromoLabel) จึงควรใช้ formatter ตัวเดียวกันจาก raw `promo_*` ทั้งสองที่
- **ช่องว่าง 4 — error contract:** web คืน `null` เมื่อ RPC ใช้ไม่ได้ ("older database") ส่วน Flutter interface throw แล้ว Home sections ซ่อนตัวเงียบ ๆ (`zoky_recommended_stores_section.dart`, `zoky_today_deals_section.dart`) ไม่มี retry หรือ pull-to-refresh ต้องกำหนด error mapping ตาม §11 ก่อนใช้ข้อมูลจริง
- **กลิ่น demo รั่วเข้า domain:** `demoNameSuffix`/`nameWithoutDemoSuffix` (ตัดสตริงชื่อร้าน) และ `coverArt: ZokyDealArt` (presentation enum) อยู่บน domain model ควรให้ demo repo ใส่ชื่อจริงพร้อม `isDemo` แล้วให้ UI เติม label เอง
- `ZokyDeal` รวมสามแหล่งข้อมูล (directory promo / campaign badges / home banners) ไว้ใน model เดียว ซึ่งยอมรับได้ แต่แหล่งข้อมูลจริงยังเป็นคำถามเปิดตั้งแต่ Phase 3 (ดูข้อ 6)
- ZOKY-126 #8: ยังไม่ validate rating ที่ boundary และ `isNew` ใช้ `ratingAverage <= 0` แทน `ratingCount == 0`

### 3.3 Code quality / duplication — ต้อง cleanup
- **Nav icon alternates เป็นโค้ดตาย (มากที่สุด):** `lib/core/widgets/zoky_nav_icon.dart` (939 บรรทัด) ใน production ใช้แค่ `rounded` + `filled3d` (`lib/features/shell/zoky_shell.dart:82-83`) และ `_RoundedGlyph.forGlyph` ครอบคลุมครบ 4 glyph ดังนั้น branch หลัง `if (rounded != null && !tiled)` ทั้งหมดไม่ถูกเรียกใน production ได้แก่ `classic3d`, `apple`, `appleSoft3d`, `outlinePink`, `tiled`/`_NavTile`/`_TilePainter`, `_Soft3dGlyph`, `_housePath`/`_bubblePath` และ `ZokyAppleNavIcons` 10 ชุด นอกจากนี้ `ZokyNavItem.appleIcons/tiled` ใน `zoky_bottom_nav.dart` รวมถึง `Zoky3DIconStyle.line` และ glyph `home/receipt/chat/person` ใน `lib/core/widgets/zoky_3d_icon.dart` ใช้เฉพาะ `classic3d` ส่วนนี้มีโค้ดราว 500+ บรรทัดและ test ที่ผูกอยู่ (`test/zoky_nav_icon_test.dart`, บางส่วนของ `test/bottom_nav_test.dart`, `test/zoky_3d_icon_test.dart`)
- `Zoky3DGlyph` ถูกใช้เป็นตัวระบุแท็บ nav ทำให้ nav ผูกกับชุดไอคอน 3D หลังตัด alternates แล้วควรให้ nav ใช้ enum/ตัวระบุของตัวเอง
- **Legacy Home body:** `kShowLegacyHomeBody = false` (`lib/features/home/home_screen.dart:41`) ยังเก็บ search/filter chips/grid และ `StoreFilter` (parity C04) ไว้เป็นโค้ดตาย และมี test ที่ยังรันกับ body นี้ (`test/widgets_layout_test.dart`, `test/shell_navigation_test.dart`, `test/qa/*`) ฟิลเตอร์ C04 ตอนนี้ไม่มีที่อยู่ใน UI จริง เพราะ `StoreSearchScreen` ไม่มี filter
- **รูปภาพ 3 implementation:** `ZokyStoreCover` (http/asset + art fallback), `ZokyStoreCard._cover` และ `ZokyMenuItemCard` (`Image.network` ดิบ) ใช้กฎ URL ไม่เหมือนกัน (ZOKY-126 #2) ควรรวมเป็น widget เดียว
- ข้อดี: ไม่พบ abstraction เกินจำเป็นใน feature code; shared widgets (`ZokyGlossySurface`, `ZokyHomeSectionHeader`, `ZokyGlossyHeartButton`) ถูก reuse จริง

### 3.4 Test suite — ผ่าน แต่หนักเกินไป
- เวลา ~151 วินาทีส่วนใหญ่มาจาก QA matrix: `test/qa/home_slice_retest_qa_test.dart` (ZOKY-120 re-test มี config 6×6×4 portrait + 16 landscape + 1 ≈ 161 tests × offset ~40 จุด พร้อมอ่าน pixel) และ `test/qa/zoky127_retest_qa_test.dart`
- landscape cases (ZOKY-120/122 re-test, `_landscapeSizes`) ไม่มีความหมายแล้วหลังล็อกแนวตั้ง (ZOKY-124)
- `FontLoader('Anuphan')` ถูก copy ไว้ใน ≥4 ไฟล์ (`test/qa/*`, `test/store_card_demo_badge_test.dart`) ควรย้ายไป `test/support/`
- `test/theme_tokens_test.dart` อ่าน `../design-reference/zoky/tokens.json` และ skip ถ้าไม่พบไฟล์ ซึ่งจะเงียบใน CI ที่ checkout บางส่วน
- ข้อเสนอ: ใส่ tag `qa-matrix` ให้ชุด matrix/pixel แล้วรันใน pre-merge/nightly ให้ชุดหลักเร็ว (<45 วินาที) และลด matrix เหลือ representative sizes (320/390/430 × insets 0/59+34 × scale 1/2) โดยไม่ลด regression coverage ของบั๊กที่ verified แล้ว

### 3.5 Accessibility และ performance — ผ่าน มีข้อควรแก้ก่อนใช้รูปจริง
- Semantics: ไอคอน/ภาพตกแต่งใช้ `ExcludeSemantics` ปุ่มมี label (62 จุด) ส่วน text scale 2.0 ถูกทดสอบแล้ว เหลือ ZOKY-126 #3/#4 (LOW)
- CustomPainter ทุกตัวมี `shouldRepaint` ที่เหมาะสม แต่ `_RoundedPainter` (nav ที่ใช้จริง) เรียก `canvas.saveLayer(null, …)` แบบไม่จำกัดขอบเขตพร้อม `ImageFilter.blur` ควรส่ง bounds (`Offset.zero & size` ขยายตาม sigma) และ illustrations ใช้ `MaskFilter.blur` หลายจุด ซึ่งรับได้กับจำนวนการ์ดน้อย แต่ควรวัดบนเครื่อง Android ระดับล่างก่อน release
- `Image.network` ไม่มี `cacheWidth/cacheHeight` (`zoky_store_cover.dart`, `zoky_store_card.dart`, `zoky_menu_item_card.dart`) จะ decode เต็มขนาดเมื่อมีรูปจริง แถวร้านแนะนำใช้ `SingleChildScrollView` (ไม่ lazy) ซึ่งรับได้ถ้า server จำกัดจำนวน featured
- logo/wordmark ใช้ `cacheWidth` แล้ว ถือว่าดี

### 3.6 Security posture ของ slice นี้ — ผ่าน
- ไม่มี network, auth หรือ secrets; `AppConfig` เอกสารชัดว่ารับเฉพาะ anon key; ไม่มี cleartext/ATS exception ใน `AndroidManifest.xml`/`Info.plist`
- ความเสี่ยงที่ต้องปิดตอน wiring (ZOKY-126 #2, #6, #8): รับเฉพาะ `https` public-bucket URL ที่ repository boundary, เพิ่ม `INTERNET` permission ใน release manifest และ validate/clamp ตัวเลขจาก RPC
- web preview (`tool/web_preview_main.dart`) ไม่ clamp query params (ZOKY-126 #5) กระทบเฉพาะ preview

### 3.7 Docs ↔ code consistency — ไม่ตรง ต้องแก้
| เอกสาร | สถานะในเอกสาร | ความจริง |
|---|---|---|
| `.wyn/docs/design/zoky-design-system.md` §9.8 (capsule nav, บรรทัด ~525) | PROPOSED — รอ Founder review | APPROVED (DECISIONS 2026-10-17 Phase 5) |
| design §7.1 ข้อ 10 (nav selected 3D, line/glossy) | PROPOSED เฟส 5 | ถูกแทนด้วยชุด `rounded` + `filled3d` แล้ว ข้อความอธิบาย `classic3d` ซึ่งไม่ได้ใช้ |
| design การ์ดร้านแนะนำเฟส 4 (บรรทัด ~425) | PROPOSED | APPROVED (DECISIONS Phase 4) |
| design system หัวเอกสาร | v0.1 PROPOSED | เฉพาะ §7.1, Phase 1–5 อนุมัติแล้ว ควรแยกสถานะรายข้อให้ชัด |
| `.wyn/docs/engineering/zoky-app-architecture.md` | PROPOSED — รอ CTO review | CTO review นี้: **APPROVED สำหรับ §1–7, 9–12, 14** ส่วน §8 (auth), §13 (backend R1/R2/R7) และ §16 (bundle ID) ยังรอ Founder |
| `.wyn/tasks/backlog/ZOKY-100-zoky-customer-app.md` | PENDING FOUNDER APPROVAL | Home ถูกอนุมัติรายเฟสผ่าน DECISIONS แต่ scope รวมของ PRD ยังไม่อนุมัติ (ดูข้อ 6) |
| `ZOKY-126` | `Status: bugs` | ควรใช้สถานะ open + owner ต่อข้อ (มีแล้วในเนื้อหา) |

## 4. Readiness สำหรับ slice ถัดไป

| Slice | พร้อม? | Blocker / สิ่งที่ต้องมีก่อน |
|---|---|---|
| ZOKY-105 Supabase/auth wiring | ยังไม่พร้อม | Founder: auth architecture §8 (Google OAuth redirect allowlist, Sign in with Apple, ลบบัญชี), PRD approval; เพิ่ม `supabase_flutter` + `flutter_secure_storage` (อยู่ในแผน §3); R7 maps origin + map SDK/tile policy |
| ZOKY-106 Store page/catalog จริง | พร้อมหลัง C1–C3 | ช่องว่าง model ข้อ 3.2; deal source decision; error/refresh UX; image widget รวม + https-only + cacheWidth |
| ZOKY-107 Cart/quote/create order | พร้อมเชิงโครงสร้าง | port `foodCartLineKey`/availability (Asia/Bangkok) เป็น pure Dart เทียบ fixture web (R8); cart state ด้วย `ChangeNotifier` ตาม §5; ยอดเงินจริงมาจาก `food_quote_order_v2` เท่านั้น |
| ZOKY-108 Payments | QR/slip ทำได้; Stripe **blocked R1** | R1 = แก้ origin check ของ `food-stripe-checkout/cancel` ซึ่งเป็น security-policy change ต้องได้ Founder approval + Security review; slip upload ต้องตรวจชนิด/ขนาดตาม SECURITY_RULES |
| ZOKY-110 Push | **blocked R2** | Database Engineer ตรวจ constraint `push_tokens.platform/app` และแก้ routing `food_promo_claim_batch`; ต้องมี Firebase/APNs (ค่าใช้จ่าย/บัญชี) |
| Staging (ทุก slice) | ไม่พร้อม | CI macOS (Codemagic) + signing + bundle ID (Q6) รอ Founder อนุมัติค่าใช้จ่าย |

## 5. Tech-debt / cleanup (เรียงตามลำดับความสำคัญ)

| # | รายการ | Owner | ก่อน slice ถัดไป? |
|---|---|---|---|
| **C1** | Sync สถานะเอกสาร: design §9.8, §7.1 ข้อ 10, การ์ดเฟส 4 → APPROVED และอัปเดต architecture header ตามข้อ 3.7 | AI Design + Architect | **ใช่** (เงื่อนไข) |
| **C2** | ตัด nav icon alternates (ข้อ 3.3) ให้เหลือ `rounded`/`filled3d` พร้อมลบ `Zoky3DIconStyle.line` และ nav glyph ใน `Zoky3DIcon` ถ้าไม่มีผู้ใช้ แล้วให้ nav มี tab id ของตัวเอง รวมถึงลบ/ย้าย test ที่เกี่ยวข้อง ย้อนกลับได้จาก git | Full-Stack | **ใช่** (เงื่อนไข) ก่อนโค้ดนี้ฝังลึก |
| **C3** | ลบ legacy Home body + `kShowLegacyHomeBody` + test ที่ใช้ `showLegacyBody: true` และย้าย C04 filter ไปหน้า "ร้านทั้งหมด"/search ตามที่ PM/Founder กำหนด | Full-Stack + PM | **ใช่** (เงื่อนไข) |
| **C4** | ปิดช่องว่าง model (ข้อ 3.2): location/ETA, `minimumOrder`, promo formatter ตัวเดียว, error contract, ย้าย demo suffix/`coverArt` ออกจาก domain, validate rating (ZOKY-126 #8) | Architect + Full-Stack + Database (ยืนยัน RPC shape) | **ใช่** (entry criteria ZOKY-106) |
| 5 | รวม image widget เดียว: https-only, `cacheWidth/Height`, fallback เดียว (ZOKY-126 #2) | Full-Stack | ใช่ พร้อม ZOKY-106 |
| 6 | Test suite: tag `qa-matrix`, ลด matrix, ตัด landscape cases, รวม `FontLoader` เข้า `test/support/`, ทำให้ `tokens.json` skip ดังใน CI | QA & Security + Full-Stack | ควรทำ (ไม่ block) |
| 7 | Home refresh/retry (pull-to-refresh, error state แทนการซ่อนเงียบ) | UI/UX + Full-Stack | ใช่ พร้อมข้อมูลจริง |
| 8 | `INTERNET` permission ใน release manifest (ZOKY-126 #6) | DevOps | ใช่ พร้อม ZOKY-105 |
| 9 | `_RoundedPainter.saveLayer` ใส่ bounds และวัด frame time บน Android ระดับล่าง | Full-Stack | ไม่ block |
| 10 | ZOKY-126 #1 (★ ใน `store_screen.dart:152` → `Zoky3DIcon` star / `fontFallbackBaseUrl`), #3, #4, #5 | Full-Stack | ไม่ block (#1 ควรทำพร้อม store page) |

## 6. เรื่องที่ต้องให้ Founder ตัดสินใจ

1. **ZOKY-100 PRD ยังเป็น PENDING FOUNDER APPROVAL** — Home ผ่านการอนุมัติรายเฟสแล้ว แต่ก่อนเริ่ม ZOKY-105 (auth/backend จริง) ต้องอนุมัติ scope รวม (หรืออย่างน้อย scope ของ 105–108)
2. **Auth architecture (§8)**: Google OAuth redirect `zoky.online`, Sign in with Apple, การลบบัญชีในแอป
3. **R1 Stripe origin**: อนุมัติแนวทางแก้ `food-stripe-checkout/cancel` (เสนอ `return_target` enum + allowlist) ซึ่งเป็น security-policy change; ถ้ายังไม่อนุมัติ P0 checkout ใช้ QR/สลิปไปก่อน
4. **R2 push routing / R7 maps origin + map SDK** และค่าใช้จ่าย Firebase/Codemagic/Apple/Google Play, bundle ID (Q6)
5. **แหล่งข้อมูลจริงของ "ดีลเด็ดวันนี้"** (โปรร้าน / แคมเปญแพลตฟอร์ม / แบนเนอร์) — เปิดค้างตั้งแต่ Phase 3 และ block `SupabasePromotionRepository`
6. **ตำแหน่งของ filter C04** หลังลบ legacy body (เสนอ: หน้า "ร้านทั้งหมด") และยืนยันคำถามเปิด Phase 4 (ซ่อน section เมื่อไม่มี featured, ไม่ใช้ ETA เดา 15/30), นิยาม "ร้านใหม่" = ไม่มีรีวิว
7. **ยืนยันการตัด nav icon alternates** (ชุด `rounded` + ไอคอนทึบชมพู 3D เป็นชุดสุดท้าย) — เป็นการเปลี่ยนทางเทคนิคที่ย้อนกลับได้ แจ้งเพื่อทราบ หาก Founder ยังต้องการเทียบแบบอื่น ให้ย้ายไปไว้ใน preview tool แทน `lib/`

## 7. ความเสี่ยงที่เหลือ

- ยังไม่มีการทดสอบบนเครื่องจริงหรือ manual screen reader; overflow tests ใช้ Anuphan จริงในบางชุดเท่านั้น
- ผลจาก code review นี้ไม่ได้ยืนยันว่าไม่มี regression นอกเหนือจาก test ที่รันผ่าน
- ทุกอย่างอยู่บน branch `docs/zoky-foundation` (64 commits จาก `main`) จึงควรแบ่ง PR/merge ตาม `docs/engineering/GIT_WORKFLOW.md` เมื่อ Founder อนุมัติ
