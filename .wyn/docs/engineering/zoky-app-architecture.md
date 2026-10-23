# ZOKY App Architecture (Flutter iOS + Android) — ZOKY-103

> โดย AI Coding (ทำหน้าที่ Architect สำหรับ slice นี้) | 2026-10-17 | สถานะ: **CTO-reviewed 2026-10-18** (`.wyn/docs/engineering/zoky-home-cto-review.md`)
> - **APPROVED (CTO 2026-10-18)**: §1–7, §9–12, §14
> - **PENDING FOUNDER APPROVAL**: §8 (auth + deep links), §13 (backend blockers R1/R2/R7), §16 (bundle ID / identity)
> - §15 และ §17 ไม่อยู่ในขอบเขตการอนุมัติของ CTO review รอบนี้ (คงสถานะ PROPOSED)
> - ไม่ใช่การอนุมัติ PRD ZOKY-100 (ยังรอ Founder) หรือ staging/production
> PRD: `.wyn/tasks/backlog/ZOKY-100-zoky-customer-app.md` · Parity: `.wyn/docs/product/zoky-feature-parity.md` · Design: `.wyn/docs/design/zoky-design-system.md` + `design-reference/zoky/tokens.json`
> Founder direction: `.wyn/company/DECISIONS.md` entry 2026-10-17
>
> เอกสารนี้อยู่ใน `.wyn/docs/engineering/` เพราะเป็นโฟลเดอร์ architecture ของ repo นี้ (ไม่มี `.wyn/docs/architecture/`; `.wyn/agents/coding.md` ระบุว่า architecture docs อยู่ที่นี่)
>
> **ขอบเขต**: เอกสารออกแบบ + scaffold (`zoky_app/`) เท่านั้น ไม่ได้แก้ backend (`supabase/`), เว็บ (`web/`), แอปเดิม (`app/`) หรือ `admin/` ไม่มี deploy ไม่มี CI/signing ไม่ได้เชื่อมต่อ Supabase จริง

---

## 1. หลักการ

1. **Parity ไม่ใช่ redesign** — พฤติกรรมยึดเว็บ (`web/components/food/*.tsx`, `web/lib/food-*.ts`) เป็น source of truth ทุกการคำนวณเงินยึด server quote (AC 11)
2. **Backend เดิม 100%** — แอปเรียกเฉพาะ RPC/table/edge function ที่เว็บเรียกอยู่ (ข้อ 5) authorization ทั้งหมดอยู่ที่ RLS/RPC ไม่ย้าย logic สิทธิ์มาไว้ที่ client
3. **Simple first** — ใช้ Flutter SDK + pattern เดิมของ `app/` (repository + constructor injection + `setState`) ไม่เพิ่ม state-management/routing framework จนกว่าจะมีเหตุผลที่วัดได้
4. **Brand shared, system adaptive** — ตาม design system ข้อ 11 (shared) / 11.2 (adaptive)
5. **ไม่มี secret ในโค้ด** — config ผ่าน `--dart-define` เท่านั้น ใช้ publishable/anon key อย่างเดียว (AC 12)
6. ZOKY เป็น **โปรเจกต์ใหม่แยกโฟลเดอร์** `zoky_app/` ไม่ import อะไรจาก `app/` (ที่พักไว้ตาม decision 2026-09-19) — คัดลอกเฉพาะ *convention* ไม่คัดลอกโค้ด

---

## 2. Folder layout

```text
zoky_app/
  pubspec.yaml               # deps น้อยที่สุด (ข้อ 3)
  analysis_options.yaml      # flutter_lints + prefer_single_quotes (เหมือน app/)
  assets/
    images/zoky_logo.png     # โลโก้ใหม่ (สว่าง ไม่มีเงา): render 512px จาก zoky-app-icon-1024.png + mask มุมมนตาม zoky-logo.svg (ไม่ใช่ store icon)
    fonts/anuphan/           # Anuphan variable font + OFL.txt (ไม่แก้ไฟล์)
  lib/
    main.dart                # bootstrap: AppConfig → repositories → runApp
    app/
      app_config.dart        # อ่าน --dart-define (SUPABASE_URL, SUPABASE_ANON_KEY, ZOKY_DEMO_MODE)
      app_dependencies.dart  # InheritedWidget ส่ง repositories ลง tree (แทน provider/riverpod)
      zoky_app.dart          # MaterialApp: theme, locale th, localizations, home = ZokyShell
    core/
      design/                # tokens เป็นโค้ด: ZokyColors, ZokyTextStyles, ZokySpacing, ZokyRadius, ZokyShadows, ZokyMotion, ZokySizes, buildZokyTheme()
      adaptive/              # isCupertino(), showZokyAlertDialog/ActionSheet/DatePicker, ZokySwitch, ZokyIcons
      widgets/               # shared widgets ของแบรนด์ (button, chip, store card, menu item card, cart bar, bottom nav, state views, skeleton, logo)
      format/                # formatBaht (เทียบ foodMoney ของเว็บ)
      l10n/                  # ZokyStrings (ภาษาไทย ข้อ 10)
    features/
      catalog/
        domain/              # model ที่ map จาก RPC (FoodDirectoryStore → ZokyStoreSummary, FoodCustomerMenuItem → ZokyMenuItem)
        data/                # abstract StoreRepository + DemoStoreRepository (+ SupabaseStoreRepository ใน ZOKY-105/106)
      shell/                 # ZokyShell: 4 แท็บ + floating bottom nav
      home/ store/ orders/ messages/ account/   # หน้าจอตาม nav ของเว็บ
  test/
    support/                 # fakes/helpers (pumpAtWidth ฯลฯ)
    *_test.dart
```

กติกาการเพิ่ม feature ใหม่ (ZOKY-105..111): `features/<name>/{domain,data,presentation}` เหมือน `app/lib/features/*` เดิม

---

## 3. Dependencies

| Package | สถานะ | เหตุผล |
|---|---|---|
| `flutter`, `flutter_localizations` (SDK) | **เพิ่มแล้ว** | Locale `th` ให้ Material/Cupertino widgets (date picker, dialog, back tooltip) เป็นภาษาไทย ไม่ใช่ third-party |
| `cupertino_icons` | **เพิ่มแล้ว** (มากับ template) | ฟอนต์ของ `CupertinoIcons` ที่ใช้กับไอคอน adaptive (back/share/more) บน iOS ตาม design 11.2 |
| `flutter_lints` (dev) | **เพิ่มแล้ว** | lint มาตรฐานเดียวกับ `app/` |
| ฟอนต์ Anuphan (asset ไม่ใช่ package) | **bundle แล้ว** | variable font ไม่แก้ไข จาก google/fonts `ofl/anuphan` + `OFL.txt` ลง `LicenseRegistry`; น้ำหนักตั้งผ่าน `FontVariation('wght')` (`ZokyTextStyles.weight`) ไม่โหลดฟอนต์จาก network ตอน runtime — QA ยืนยัน license ก่อนส่ง store (design Q9) |
| `supabase_flutter` | **ZOKY-105** | client เดียวกับเว็บ/แอปเดิม: auth, RPC, storage, realtime, functions — ยังไม่เพิ่มใน slice นี้เพราะ scaffold ใช้ demo data ล้วน |
| `flutter_secure_storage` | ZOKY-105 | เก็บ Supabase session ใน Keychain/Keystore (PRD B03) ผ่าน custom `LocalStorage` ของ supabase_flutter แทน shared_preferences |
| `shared_preferences` | ZOKY-106/107 | ตะกร้า/ร้านโปรด/คำค้นล่าสุด/โค้ดที่เก็บ (ข้อมูลไม่ sensitive, เทียบ localStorage ของเว็บ) |
| `url_launcher` | ZOKY-105/108 | เปิด Stripe/forgot-password/LINE/โทรร้านด้วย browser/dialer ของระบบ |
| `share_plus`, `image_picker` | ZOKY-106/108 | share sheet native (D12), PHPicker/Photo Picker (G04) |
| `geolocator` | ZOKY-105 | GPS (J06) |
| Map SDK (เช่น `maplibre_gl`) | **ต้องตัดสินใน ZOKY-105** | J05 ต้องตรวจเงื่อนไข tiles ของ OpenFreeMap บนมือถือก่อน (R7) |
| `firebase_core`, `firebase_messaging` | ZOKY-110 | FCM iOS/Android (K01–K04) ต้องมี Firebase config จาก Founder/DevOps |
| Lucide icons port | **ยังไม่เพิ่ม — คำถามเปิด** | design ข้อ 7 ใช้ Lucide; scaffold ใช้ Material/Cupertino icons ผ่าน `ZokyIcons` ที่เดียว เปลี่ยนชุดไอคอนภายหลังได้โดยแก้ไฟล์เดียว เลือก package เมื่อ CTO review license/ขนาด |
| `go_router` / state libs | **ไม่เพิ่ม** | ดูข้อ 4–5 |

ทุก dependency ใหม่ต้องมีคอมเมนต์ใน `pubspec.yaml` อธิบายเหตุผล (convention ของ `app/pubspec.yaml`)

---

## 4. Routing

- **Shell**: `ZokyShell` ใช้ `IndexedStack` 4 แท็บ (หน้าหลัก / ออเดอร์ / ข้อความ / บัญชี ตาม `wynos-food-developer-app.tsx` บรรทัด ~411) เก็บ state แต่ละแท็บไว้ (A05)
- **หน้าที่ push** (ร้าน, ตะกร้า, checkout, ชำระเงิน, รายละเอียดออเดอร์): `Navigator.push` + `MaterialPageRoute` ซึ่งใช้ transition ตาม `ThemeData.pageTransitionsTheme` (iOS = Cupertino slide + swipe-back, Android = `FadeForwardsPageTransitionsBuilder` + predictive back) ไม่ทำ transition เอง
- **Android back** (A05): จากแท็บอื่นกลับหน้าหลักก่อน แล้วค่อยออกแอป — `PopScope` ใน shell
- **iOS แตะแท็บซ้ำ** เลื่อนขึ้นบนสุด (A05): ทำใน ZOKY-105 ด้วย `ScrollController` ต่อแท็บ
- **Deep link** (ZOKY-110): ไม่ใช้ router framework แต่มีตัวแปลงล้วน ๆ `ZokyLink.parse(Uri)` → intent (`openStore(id|shareCode)`, `openOrder(orderNumber)`, `applyPromo(code)`, `authCallback`) แล้ว shell เป็นผู้จัดการ push หน้า รองรับ path เดียวกับเว็บ: `/s/<code>`, `/?store=<uuid>`, `/?order=WFxxxx[&stripe=success|cancelled]`, `/?promo=CODE`, `/auth/callback` — ทุกค่า validate ก่อนใช้ (uuid, รูปแบบ `WF\d+`, โค้ด `[A-Z0-9]{1,24}`) และยังต้องผ่าน RLS/RPC ตามปกติ
- ถ้าภายหลังจำนวน route/guard โตจนจัดการด้วยมือไม่ไหว ค่อยเสนอ `go_router` เป็น change แยก (ไม่ใช่ตอนนี้)

## 5. State management

- **ตามแบบ `app/`**: `StatefulWidget` + `setState` สำหรับ state ของหน้าจอ, repository ถูก inject ผ่าน constructor (หรือ `AppDependencies.of(context)` ที่ระดับ screen)
- **State ข้ามหน้าจอ** (session, ตะกร้า, จำนวนออเดอร์ active สำหรับ badge): `ChangeNotifier` ธรรมดา + `ListenableBuilder` (SDK) — ไม่มี provider/riverpod/bloc
- เหตุผล: ลด dependency, ทีมคุ้นกับ pattern จาก `app/`, test ง่ายด้วย fake ที่ inject ตรง ๆ
- Async ทุกครั้งต้อง `await` หรือ `.catchError` (บทเรียน PostgrestBuilder ใน `.wyn/learning/PATTERNS.md`: builder ที่ไม่ถูก `.then()` จะไม่ส่ง request เลย)

---

## 6. Data access — RPC/edge function เดียวกับเว็บ

### 6.1 Repository pattern

- `abstract class StoreRepository` (และ Order/Address/Payment/Review/Notification repositories ในรอบถัดไป) — **ต่างจาก `app/` เล็กน้อยโดยตั้งใจ**: `app/` ใช้ concrete class + subclass เป็น test double แต่ ZOKY ต้องมี implementation จริงสองแบบ (Supabase + Demo สำหรับ web preview ที่ไม่มี backend) จึงต้องมี interface
- `SupabaseXRepository(SupabaseClient client)` — constructor-injected client เหมือน `app/`; ไม่มี `Supabase.instance` ในโค้ด feature
- `DemoXRepository` — ข้อมูลสังเคราะห์ภาษาไทย ไม่มีข้อมูลลูกค้าจริง ใช้กับ web preview และ widget tests
- Test doubles สำหรับดักจับ argument: `Recording*Repository` ใน `test/support/` (convention เดิม)

### 6.2 Mapping (เว็บ → Flutter repository)

| Parity | เว็บเรียก | ชนิด | Repository (เสนอ) | Slice |
|---|---|---|---|---|
| A04 | `food_customer_access_enabled`, `is_developer_account` | RPC | `AccessRepository` | 105 |
| B01 | `food_public_catalog` (anon) | RPC | `StoreRepository.publicCatalog` | 106 |
| B03–B07 | Supabase Auth (password, Google OAuth PKCE, signUp, reset, signOut) | Auth | `AuthRepository` | 105 |
| C02/C08/C09/C11 | `food_store_directory(p_query)` | RPC | `StoreRepository.fetchDirectory` | 106 |
| C03 | `food_active_home_banners` + bucket `food-banners` (public) | RPC + Storage | `HomeContentRepository` | 106 |
| C05 | `food_active_featured_stores` (+ `food_store_directory` เพื่อเอาข้อมูลร้าน) | RPC | `StoreRepository.fetchRecommended` (Home เฟส 4 — ย้ายจาก `HomeContentRepository` ที่เสนอเดิม เพราะผลลัพธ์เป็นรายการร้าน; demo มีแล้ว) | 106 |
| C12 | `food_ad_click(p_store_id, p_placement)` | RPC | `StoreRepository.recordAdClick` | 106 |
| C14 | table `food_notifications` (select/update `read_at` ของตัวเอง) | Table | `PromotionRepository` | 111 |
| C15 | table `food_marketing_preferences` (upsert) | Table | `PromotionRepository` | 111 |
| D01–D09 | tables `food_stores`, `food_menu_items`; `food_menu_stock_remaining(p_store_id)`; bucket `food-public` | Table/RPC | `StoreRepository.fetchStore/fetchMenu` | 106 |
| D04 | `food_platform_campaign_badges` | RPC | `StoreRepository` | 106 |
| D11/I01/I02 | `food_store_review_feed`, `food_submit_store_review`, `food_my_store_reviews` | RPC | `ReviewRepository` | 109 |
| D13 | `food_store_id_by_share_code`, `food_record_share_open`, `food_mark_order_from_share` | RPC | `ShareRepository` | 110 |
| E05/F05 | `food_quote_order` / `food_quote_order_v2` (+ coupon) | RPC | `OrderRepository.quote` | 107 |
| E06 | `food_first_order_offer(p_store_id)` | RPC | `OrderRepository` | 107 |
| F08 | `food_create_order` / `food_create_order_v2` (**ไม่ใช้** `food_create_scheduled_order*` — decision 2026-10-10) | RPC | `OrderRepository.create` | 107 |
| G02 | `food-payment-qr` | Edge fn | `PaymentRepository` | 108 |
| G04 | Storage `food-private/<uid>/slips/<order>/…`, `food_submit_payment`, `food-verify-slip` | Storage/RPC/Edge | `PaymentRepository` | 108 |
| G05/G06 | `food-stripe-checkout`, `food-stripe-cancel` | Edge fn | `PaymentRepository` (**blocked R1**) | 108 |
| H01–H04 | table `food_orders` (+ items, proofs), Realtime `postgres_changes` filter `buyer_id` | Table/Realtime | `OrderRepository` | 109 |
| H05 | `food-private` signed URL 15 นาที | Storage | `OrderRepository` | 109 |
| H06 | `food_cancel_order` | RPC | `OrderRepository` | 109 |
| J01/J02 | table `food_customer_addresses`, `food_upsert_customer_address_v3`, `food_delete_customer_address` | Table/RPC | `AddressRepository` (เสนอเรียก **v3 อย่างเดียว** — v2/legacy fallback ของเว็บมีไว้ช่วง rollout ซึ่งผ่านแล้ว; ต้องให้ Database Engineer ยืนยันว่า production มี v3) | 105 |
| J04 | `food_delivery_availability` | RPC | `AddressRepository` | 105 |
| J05/J07 | `wynos_reverse_place`, `wynos_nearby_places`, `wynos_place_details`, `wynos_search_places`, `wynos_search_store_places`/`food_search_store_places`, `wynos-maps-geocode`, `location-search` | RPC/Edge | `PlaceRepository` (**R7**) | 105 |
| J05/J07 | `/api/maps/search`, `/api/maps/reverse` (Next.js route บนเว็บ) | HTTP | **ไม่เรียกจากแอป** ในรอบแรก — ใช้ edge function/RPC แทน (ข้อ 13 R7) | 105 |
| J08 | `submit_wynos_place_suggestion` | RPC | `PlaceRepository` | 111 |
| K01/B07 | table `push_tokens` (upsert/delete) | Table | `PushTokenRepository` (**R2**) | 110 |
| (area) | `food_service_area_check` | RPC | `AccessRepository` | 105 |

ห้ามเรียก RPC/table อื่นนอกตารางนี้โดยไม่มีงานและ review แยก (AC 13)

### 6.3 Model mapping

- ตัวเลขเงินจาก PostgREST อาจเป็น `number | string` (เช่น `delivery_fee: number | string`) — parser ฝั่ง Dart ต้องรับทั้งสองแบบ (`num.tryParse`) และใช้ค่าเป็น "แสดงผล" เท่านั้น ยอดที่ยืนยันมาจาก quote
- **คะแนน/เวลาส่ง (Home เฟส 4, Founder rule: แสดงเฉพาะเมื่อมีข้อมูลจริง)**: `rating_average`/`rating_count` ของ `food_store_directory` (aggregate จากรีวิว เท่ากับ `average`/`count` ของ `food_store_review_feed`) → `ZokyStoreSummary.rating` เป็น null เมื่อ `rating_count = 0`; ETA = `foodEstimateDeliveryRange` (prep_time_min/max + เดินทางจาก `distance_km` ของ `food_delivery_availability` ~22 กม./ชม. + 5 นาที) แต่ **ไม่ใช้ fallback 15/30 ของเว็บ** — ถ้าร้านไม่ได้ตั้ง prep time ให้ `etaMinMinutes/etaMaxMinutes` เป็น null และไม่แสดงเวลา
- ตรรกะ client ที่ต้อง port ให้ผลเหมือนเว็บ (R8): `food-store-availability.ts` (เวลา Asia/Bangkok), `foodCartLineKey`, haversine/ETA, `foodPromoLabel` — ทำเป็น pure Dart + test เทียบ fixture เดียวกับเว็บ

---

## 7. Config injection

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key> \
  --dart-define=ZOKY_DEMO_MODE=false
```

- `AppConfig.fromEnvironment()` อ่านด้วย `String.fromEnvironment`/`bool.fromEnvironment` — **ไม่มีค่า default ที่เป็น key จริง** ใน repo
- `SUPABASE_ANON_KEY` รับได้ทั้ง publishable key (`sb_publishable_…`) และ legacy anon key — `app/` ใช้ชื่อ `SUPABASE_PUBLISHABLE_KEY`; ZOKY ใช้ชื่อตาม task นี้ CI ในอนาคตต้อง map ให้ถูก
- **Demo mode** = ไม่มี config หรือ `ZOKY_DEMO_MODE=true` → ใช้ `Demo*Repository` ทั้งหมด + แถบ "โหมดสาธิต" ในหน้าบัญชี. Slice นี้ยังไม่มี Supabase repositories จึงเป็น demo เสมอ
- **Guard สำหรับ store build** (ทำใน ZOKY-104 CI): build TestFlight/Play ต้องส่ง `ZOKY_DEMO_MODE=false` และ config จริงจาก CI secrets; เพิ่ม check ใน CI ให้ fail ถ้า release build ไม่มี `SUPABASE_URL`
- ห้ามใช้ `.env` ไฟล์ใน Flutter assets (จะถูก bundle เป็น plain text)

---

## 8. Auth + deep links (plan — ต้อง Founder อนุมัติข้อที่เป็น auth architecture)

| เรื่อง | แผน | สถานะ |
|---|---|---|
| Email/password | `supabase.auth.signInWithPassword` + error copy เดียวกับ `food-auth.tsx` ("ยังไม่ยืนยันอีเมล" / "อีเมลหรือรหัสผ่านไม่ถูกต้อง") + `registerCurrentAccount` เทียบเว็บ | ZOKY-105 |
| Google | OAuth PKCE ผ่าน browser ระบบ (`signInWithOAuth` → ASWebAuthenticationSession / Custom Tabs) กลับด้วย redirect `zoky.online/auth/callback` (Universal/App Link) — **ไม่เปลี่ยน provider** แค่เพิ่ม redirect URL ใน Supabase allowlist (external config, ต้องอนุมัติ) | ZOKY-105, ต้องตั้ง Supabase redirect allowlist |
| Native Google Sign-In / Sign in with Apple | **ไม่ทำ** จนกว่า Founder ตอบ Q3 (เป็น auth architecture change) | blocked Q3 |
| Session storage | Keychain/Keystore ผ่าน `flutter_secure_storage` | ZOKY-105 |
| Sign-up / reset password | ลิงก์ในอีเมลกลับ `zoky.online/...` → ถ้ามีแอปเปิดในแอป (Universal Link) ไม่มีก็เปิดเว็บ; ช่วงเปลี่ยนผ่านต้องคง redirect ของ `food.wynos.online` ไว้ใน allowlist | ต้องรอโดเมน + allowlist |
| ลบบัญชีในแอป | **ไม่ทำ** จนกว่า Founder ตอบ Q4 | blocked Q4 |
| Universal Links / App Links | `apple-app-site-association` + `/.well-known/assetlinks.json` บน `zoky.online` ครอบ `/s/*`, `/`(query `store`/`order`/`promo`), `/auth/callback` — ไฟล์อยู่ฝั่งเว็บ (งานแยก ต้องรอโดเมน + bundle ID) | ZOKY-110 |
| Custom scheme fallback | ไม่ใช้ (`zoky://`) เพื่อกัน scheme hijack ยกเว้นกรณีที่ OAuth บังคับ — ถ้าต้องใช้ให้ QA review | — |
| Developer accounts | สะท้อนพฤติกรรมเว็บ (`is_developer_account` ข้ามการตรวจพื้นที่) server เป็นผู้ตัดสินเสมอ | ZOKY-105 |

---

## 9. Platform-adaptive widget strategy (design ข้อ 11.2)

- ตัดสิน platform จาก `Theme.of(context).platform` (เคารพ `debugDefaultTargetPlatformOverride` ใน test และเป็น `iOS` เมื่อเปิด web preview บน iPad Safari) — helper `isCupertino(context)` (iOS/macOS = true)
- Helper ใน `lib/core/adaptive/`:

| Helper | iOS | Android |
|---|---|---|
| `showZokyAlertDialog` | `CupertinoAlertDialog` (+ `isDestructiveAction`) | M3 `AlertDialog` radius 28, `TextButton` สี primary, destructive = `error` |
| `showZokyActionSheet` | `CupertinoActionSheet` + ปุ่มยกเลิก | `showModalBottomSheet` + `ListTile` + drag handle |
| `showZokyDatePicker` | `CupertinoDatePicker` wheel ใน popup + "เสร็จ" | `showDatePicker` |
| `ZokySwitch` | `CupertinoSwitch` track = primary | M3 `Switch` track = primary |
| `ZokyIcons.back/share/more(context)` | `CupertinoIcons.back` / `CupertinoIcons.share` / `CupertinoIcons.ellipsis` | `Icons.arrow_back` / `Icons.share` / `Icons.more_vert` |
| Page transition | `CupertinoPageTransitionsBuilder` | `FadeForwardsPageTransitionsBuilder` |
| Scroll physics | default ของ `MaterialScrollBehavior` (bouncing บน iOS, clamping + stretch บน Android) — ไม่ override | |
| Spinner | `CupertinoActivityIndicator` | `CircularProgressIndicator` สี brand |

- **Shared** (เหมือนกันทุก platform): floating bottom nav (ไม่ใช้ `CupertinoTabBar`/`NavigationBar`), ปุ่ม, chips, การ์ด, cart bar, state views, skeleton
- ใน slice นี้ทำ: dialog, action sheet, date picker, switch, icons, page transitions, spinner. Toast position/haptics/pull-to-refresh/image picker ทำใน slice ของ feature นั้น

---

## 10. i18n

- **ภาษาไทยอย่างเดียว** (เท่าเว็บ; Q13 ยังเปิด) — `MaterialApp(locale: Locale('th'), supportedLocales: [Locale('th')])` + `GlobalMaterialLocalizations`/`GlobalCupertinoLocalizations`/`GlobalWidgetsLocalizations`
- ข้อความ UI รวมไว้ที่ `lib/core/l10n/zoky_strings.dart` (const) เพื่อให้ย้ายไป `gen-l10n` (ARB) ได้ทันทีถ้า Founder อนุมัติภาษาอังกฤษ — ไม่ติดตั้ง gen-l10n ตอนนี้
- iOS: `CFBundleLocalizations = [th]` เพื่อให้ system UI (เช่น back/cancel) เป็นไทย
- Copy ต้องตรงกับเว็บหลัง rebrand (ห้ามคิด copy ใหม่) — จุดที่มีคำว่า "WYNOS Food" ใช้ "ZOKY"

---

## 11. Error mapping

- Port `foodCustomerError()` (`web/lib/food-customer.ts` ~บรรทัด 1006) เป็น `zokyCustomerError(Object error)` pure Dart: จับ substring ของ Postgres error message เดิม → ข้อความไทยเดิมทุกกรณี (store closed, minimum order, stock, options, rate limit, payment submitted, cancel not allowed, service area, delivery location ฯลฯ) + `sessionErrorCopy` (clock skew/JWT expired) ทำพร้อม unit test ต่อกรณีใน ZOKY-107
- Network: `SocketException`/`ClientException`/timeout → "ไม่มีการเชื่อมต่ออินเทอร์เน็ต" + ปุ่มลองใหม่ (A03) ตะกร้าไม่หาย
- `PGRST202`/`42883` (function not found) → ถือเป็น "ฟีเจอร์ยังไม่พร้อม" เหมือนเว็บ ไม่ crash
- ห้าม log payload ที่มีข้อมูลส่วนตัว (ที่อยู่ เบอร์ สลิป) — log แค่ code/ชื่อ RPC

## 12. Local storage

| ข้อมูล | ที่เก็บ | Key (เทียบเว็บ) |
|---|---|---|
| Supabase session | Keychain/Keystore (`flutter_secure_storage`) | — |
| ตะกร้า (ต่อ user, ร้านเดียว) | `shared_preferences` | `zoky-cart-v1:<uid>` (เว็บ `wynos-food-cart-v1:<uid>` — คนละ origin อยู่แล้ว ไม่ sync) |
| ร้านโปรด / โค้ดที่เก็บ / คำค้นล่าสุดต่อร้าน | `shared_preferences` | `zoky-favorite-stores-v1:<uid>`, `zoky-saved-promos-v1:<uid>`, `zoky-menu-search-v1:<storeId>` (Q7 ยังเปิด) |
| โค้ดโปรล่าสุด, share ref 24 ชม., ร้านจาก deep link 1 ชม. | `shared_preferences` | `zoky-promo-code-v1`, `zoky-share-ref-v1`, `zoky-pending-store-v1` |
| รูปสลิปก่อน upload | memory/temp เท่านั้น ลบ EXIF location ก่อน upload | — |

ล้างข้อมูลผูก user ตอน sign-out (B07)

---

## 13. Known backend blockers (ไม่ได้แก้ backend ใน slice นี้)

ตรวจโค้ดแบบอ่านอย่างเดียว ณ 2026-10-17:

| ID | ปัญหา (หลักฐาน) | ผลต่อแอป | ข้อเสนอ (ต้องมีงานแยก + QA & Security review + Founder อนุมัติ + รอ freeze ปลด) |
|---|---|---|---|
| **R1** | `supabase/functions/food-stripe-checkout/index.ts` บรรทัด ~69: live mode ปฏิเสธถ้า `origin !== "https://food.wynos.online"`; บรรทัด ~152–153 hardcode `success_url`/`cancel_url` เป็น `food.wynos.online` (`food-stripe-cancel` ตรวจแบบเดียวกันตาม parity G06) | แอป native ไม่ส่ง `Origin` → 403 `live_stripe_origin_required`; การกลับจาก Stripe ไปเว็บเดิมไม่ใช่แอป | origin เป็นแค่ defense-in-depth (auth จริงคือ JWT + ownership ของออเดอร์): เพิ่ม allowlist `https://zoky.online` และรับ request ที่ไม่มี Origin เมื่อ JWT ถูกต้อง หรือให้ client ส่ง `return_target: "web"|"app"` (enum, ไม่ใช่ URL อิสระ) แล้ว server เลือก success/cancel URL จาก allowlist (`https://zoky.online/?order=…&stripe=…` ซึ่งเป็น Universal Link อยู่แล้ว). G05/G06 ถูก block จนกว่าจะทำ — P0 checkout ยังทำได้ด้วย QR/สลิป |
| **R2** | `send-push-notification` อ่าน `push_tokens(token, platform, app)` และมี policy เฉพาะ `platform === "web"`; parity ระบุว่า `send-food-promotion` (ผ่าน `food_promo_claim_batch`) ส่งเฉพาะ `platform = web` + `app = food` | push ออเดอร์อาจถึง/ไม่ถึง token แอป, push โปรโมชันไม่ถึงแอปแน่นอน | แอปบันทึก `push_tokens` เป็น `platform = 'ios' | 'android'`, `app = 'food'` (คงค่า `food` ไว้เพราะเป็นชื่อภายใน ไม่ใช่แบรนด์) — Database Engineer ตรวจ constraint ของคอลัมน์ `platform`/`app` และแก้ `food_promo_claim_batch` + routing ให้รวม ios/android พร้อม test แบบ `_lib.test.ts` |
| **R7** | `wynos-maps-geocode` มี `ALLOWED_ORIGINS` (wynos.online, food.wynos.online, … , localhost) และปฏิเสธเฉพาะ request ที่ **มี** Origin ไม่อยู่ใน list; `/api/maps/*` เป็น Next.js server route | native (ไม่มี Origin) น่าจะผ่าน edge function ได้; **web preview ของ ZOKY และ `zoky.online` จะโดน 403**; `/api/maps/*` ต้องเรียกด้วย URL เต็มของเว็บ (ข้ามโดเมน + CORS) | แอปใช้ RPC `wynos_*` + edge functions แทน Next route; เพิ่ม `https://zoky.online` ใน allowlist ตอน cutover; ตรวจ usage policy ของ tile provider (OpenFreeMap) และ geocoder บนมือถือก่อนเลือก map SDK |
| R10 | Production freeze (`docs/engineering/WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md`) | apply backend fix ไม่ได้ | เตรียมบน branch แล้วรวมใน coordinated release |

---

## 14. Testing strategy

| ระดับ | อะไร | เครื่องมือ |
|---|---|---|
| Unit | tokens, formatBaht, error mapping, ตรรกะ port จากเว็บ (availability, cart key, haversine) เทียบ fixture | `flutter_test` |
| Widget | shared widgets ที่ความกว้าง 360 และ 430 + text scale 1.3 (ภายหลัง 2.0 บน flow หลักตาม design 10.2) ไม่มี overflow; adaptive helpers ด้วย `debugDefaultTargetPlatformOverride` (iOS vs Android); shell navigation + Android back | `flutter_test`, `tester.view` |
| Repository | `Recording*Repository` / fake `SupabaseClient` (`https://example.supabase.co`, `test-key`) — **ห้ามต่อ Supabase จริง** | convention จาก `app/test/support/` |
| Integration/E2E | flow หลักบน simulator/emulator ใน CI macOS (ZOKY-104 CI, รออนุมัติค่าใช้จ่าย) | `integration_test` |
| Manual | VoiceOver/TalkBack, Dynamic Type 200%, เทียบ screenshot iOS/Android (AC 14–15) | QA |

ข้อจำกัดที่รู้: test env ไม่มี platform channel ของ clipboard/share (ดู PATTERNS.md) → test แค่ presence ของปุ่ม; ฟอนต์ใน test เป็น FlutterTest font (กว้างกว่าจริง) จึงเป็น overflow check แบบ conservative

---

## 15. Versioning / backward compatibility (PRD edge case 12)

- RPC ที่แอปใช้ถือเป็น public contract: การเปลี่ยน signature ต้องเพิ่ม `_vN` ใหม่และคงตัวเก่าไว้จนกว่าแอปเวอร์ชันเก่าจะหมด (เหมือน `food_quote_order` → `_v2` ที่เว็บทำอยู่)
- เสนอ (ZOKY-110+): ตาราง/RPC `zoky_min_app_version` สำหรับบังคับอัปเดต — เป็น backend change ต้องอนุมัติแยก

## 16. Bundle ID / identity

- Scaffold ใช้ placeholder จาก `flutter create --org online.zoky`: Android `online.zoky.zoky_app`, iOS `online.zoky.zokyApp` — **PENDING FOUNDER APPROVAL (Q6)** PRD เสนอ `online.zoky.app`; ต้องเปลี่ยนให้เป็นค่าที่อนุมัติ **ก่อน** สร้าง App ID/Play listing แรก (เปลี่ยนไม่ได้หลังเผยแพร่)
- ชื่อที่แสดง: "ZOKY" (iOS `CFBundleDisplayName`, Android `android:label`)
- App icon production ยังไม่ทำ (design 2.2/2.6 A1–A10 ต้องมี master vector ก่อน) — scaffold ยังใช้ไอคอน default ของ Flutter

## 17. สิ่งที่ยังไม่ทำใน ZOKY-104 (scaffold)

CI (Codemagic/GitHub Actions), signing, Firebase/APNs, Associated Domains/App Links, Supabase client, auth, ข้อมูลจริง, production icons/splash — รออนุมัติค่าใช้จ่าย/บัญชีผู้พัฒนา/bundle ID ตาม `.wyn/company/APPROVALS.md`
