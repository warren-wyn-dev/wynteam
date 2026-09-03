# Feature Request — WYN-098

Status: design complete, ready for AI Coding (2026-09-02) — UI/data-model implementable now; end-to-end testing still blocked on Founder/DevOps providing a real LocationIQ API key
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 3/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: ทำระบบเช็คอินสถานที่ให้ใช้งานได้จริง
Goal: ปุ่มปักหมุดสถานที่ตอนโพสต์ใช้งานได้จริง ค้นหา/เลือกสถานที่แล้วแนบเข้าโพสต์
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ปุ่มวงสีแดง คือจุดเช็คอินสถานที่ยังใช้งานไม่ได้" — เรื่อง provider แผนที่ Founder ถามว่า Google API ฟรีไหม
Requirements:
- **ตอบคำถาม Founder**: Google Places/Geocoding API ไม่ฟรี 100% — Google ให้เครดิตฟรี $200/เดือนอัตโนมัติ (พอใช้ได้ระดับพันคำค้นต่อเดือน) แต่ต้องผูกบัตรเครดิตกับ Google Cloud project เสมอ ถ้าใช้เกินเครดิตจะเรียกเก็บเงินจริง
- **แนะนำ**: เริ่มด้วยผู้ให้บริการที่ฟรีจริงไม่ต้องผูกบัตร เช่น LocationIQ หรือ Geoapify (free tier ~5,000 คำค้น/วัน) หรือ OpenStreetMap Nominatim (ฟรีไม่จำกัดแต่ rate-limit ต่ำ เหมาะ self-host) เพื่อลดความเสี่ยงค่าใช้จ่ายไม่คาดคิดช่วง Beta — ค่อยพิจารณา Google ทีหลังถ้าปริมาณผู้ใช้โตและต้องการความแม่นยำ/ครอบคลุมสถานที่ในไทยที่ดีกว่า
- ทำ UI ค้นหา/เลือกสถานที่จริง (autocomplete) ตอนกดปุ่มปักหมุด แล้วแนบสถานที่ที่เลือกเข้ากับโพสต์ แสดงชื่อสถานที่บนโพสต์
Acceptance Criteria:
- [ ] กดปุ่มปักหมุดแล้วค้นหาสถานที่จริงได้ เลือกแล้วแนบเข้าโพสต์สำเร็จ
- [ ] โพสต์ที่เช็คอินแสดงชื่อสถานที่ในการ์ดโพสต์
Dependencies: ไม่มี — แต่ **บล็อกด้วย Founder action**: ต้องเลือก/สมัคร provider (LocationIQ/Geoapify/Google) และให้ API key ก่อนต่อจริงได้ เหมือนแพทเทิร์น Firebase ใน WYN-016
Priority: กลาง — งานเขียนโค้ดทำได้ทันที แต่ทดสอบจริงต้องรอ Founder ยืนยัน provider + API key
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ใช้ provider ฟรีที่ rate-limit ต่ำเกินไปสำหรับ production จริง | กลาง | เลือก provider ที่มี free tier พอสมควร (LocationIQ/Geoapify) ไม่ใช่ Nominatim ตรงๆ ที่เจตนาไว้สำหรับ low-volume |
Recommendation: รอ Founder ยืนยันเลือก provider (แนะนำ LocationIQ/Geoapify แบบฟรีไม่ผูกบัตรก่อน) แล้วเริ่ม Design/Coding ทันที
Handoff: AI Product Manager สรุป provider ให้ Founder ยืนยัน → AI Design → AI Coding

---

## Product Full Spec Output (2026-09-02)

Founder ถูกถามตรงๆ ผ่าน popup ระหว่างเซสชันนี้ว่าจะเลือก LocationIQ หรือ Geoapify (ทั้งคู่ฟรีไม่ต้องผูกบัตร ต่างจาก Google Maps Platform) — **Founder เลือก LocationIQ** ถือเป็นมติที่ตัดสินใจแล้ว (บันทึกที่ `.wyn/company/DECISIONS.md` 2026-09-02) ไม่ใช่คำถามเปิดอีกต่อไป

เขียน Product spec เต็มแล้วที่ `.wyn/docs/product/wyn-098-location-checkin.md` ครอบคลุม: data model (reuse คอลัมน์ `drops.location` ที่เตรียมไว้ตั้งแต่ WYN-019 + เพิ่ม `location_lat`/`location_lon`/`location_place_id` ใหม่), LocationIQ integration ผ่าน Supabase Edge Function ใหม่ (`location-search`) เก็บ API key เป็น secret ฝั่ง server เท่านั้น (มิเรอร์ pattern `send-push-notification` ของ WYN-016), rate-limiting 2 ชั้น (debounce ฝั่ง client + hard limit ฝั่ง server ผ่านตาราง `location_search_requests` ใหม่ที่ไม่มี client policy เลย) กัน quota รวมของแอปถูกใช้หมดโดยผู้ใช้คนเดียว, privacy (แสดงผลเฉพาะชื่อสถานที่ ไม่โชว์พิกัด GPS ดิบ, inherit visibility ของโพสต์เดิมอัตโนมัติเพราะเป็นคอลัมน์เดียวกับ `drops`), UI flow+Thai copy ครบ, out-of-scope ชัดเจน (ไม่มี live map, ไม่ tappable, ไม่มี location discovery feed), edge cases, และ risk เรื่อง migration ต้องตรวจ production schema จริงก่อน apply (ไม่เชื่อ `schema.sql` ตรงๆ เพราะมีปัญหารู้อยู่แล้ว)

Handoff: ส่งต่อ AI Design ก่อน AI Coding (ฟีเจอร์ใหม่ที่ผู้ใช้เห็น/ใช้งานโดยตรง) — ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-098-location-checkin.md`

## Design Output (2026-09-02)

เขียน design spec เสร็จแล้วที่ `.wyn/docs/design/wyn-098-location-checkin.md` — ครอบคลุม 4 หน้าจอ: (1) เปลี่ยน `onTap` ของปุ่มปักหมุดที่มีอยู่แล้วใน toolbar ของ `CreateDropScreen` จาก `_showComingSoon` (placeholder) ให้เปิดหน้าค้นหาจริง (2) Bottom sheet ค้นหาสถานที่ (search bar reuse โครงเดียวกับ `FollowListScreen`, แถว "ใช้ตำแหน่งปัจจุบันของฉัน" อยู่บนสุดเสมอ, header reuse โครง `_showPermissionPicker`) (3) Chip สถานที่ที่เลือกไว้บนหน้าสร้างโพสต์ (reuse รูปทรงเดียวกับ `_AudienceChip` ของ WYN-097) (4) แสดงชื่อสถานที่ต่อท้ายบรรทัดเวลาใน `HomeDropCard`/`DropDetailScreen` — สีทั้งหมดตรวจจาก `app/lib/core/design/wyn_colors.dart` (Sapphire era) แล้ว ไม่มี token ใหม่ ไม่แตะ Edge Function/API key (นอกสโคป AI Design)

**ยังบล็อกด้วย Founder/DevOps action**: ต้องมี LocationIQ API key จริงก่อนทดสอบ end-to-end ได้ (ไม่ block การเริ่ม Coding — implement ด้วย mock/placeholder response ระหว่างรอ ตามที่ Product spec แนะนำ)

Handoff: ส่งต่อ AI Coding (`/code`)

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — ฟีเจอร์ใหม่ทั้งหมดตรงตามสโคปที่ Design ยืนยันไว้ implement ด้วย LocationIQ จริง (ไม่ใช่ mock) แต่ยังไม่ได้ทดสอบ end-to-end จริงเพราะยังไม่มี `LOCATIONIQ_API_KEY` (บล็อกด้วย Founder/DevOps action ตามที่ backlog เดิมระบุไว้แล้ว)

การเปลี่ยนแปลง (Backend):
1. `supabase/schema.sql`: คอลัมน์ใหม่ `drops.location_lat`/`location_lon`/`location_place_id` (reuse `drops.location` เดิมตั้งแต่ WYN-019 เป็นชื่อสถานที่) + constraint คู่ (lat/lon null พร้อมกันเท่านั้น, place_id ต้องมี location คู่กัน) + ตาราง `location_search_requests` ใหม่ (RLS เปิดแต่ไม่มี policy ให้ client เลย — service-role only) สำหรับ rate-limit + `create_poll_drop()` เพิ่ม 4 param location ใหม่ (default null, ไม่กระทบ call เดิม) + `home_feed` view เพิ่ม `location` ต่อท้าย (append เต็มรูปแบบทั้ง 3 branch ตาม convention เดิม)
2. **`supabase/functions/location-search/`** (Edge Function ใหม่ตัวที่ 2 ของโปรเจกต์ ต่อจาก `send-push-notification`): `_lib.ts` (pure logic: parse LocationIQ response, build request URL, rate-limit check, decode JWT — ตรวจสอบด้วย `deno test` จริง 13 เทสผ่านหมด + `deno check` ผ่าน) + `index.ts` (thin orchestrator: verify auth จาก JWT ที่ platform verify_jwt เช็คให้แล้ว, เช็ค rate limit จาก `location_search_requests` ก่อนเรียก LocationIQ เสมอ, timeout 7 วินาที, fail gracefully) — API key (`LOCATIONIQ_API_KEY`) อยู่ฝั่ง server เท่านั้น ไม่เคยส่งให้ client เห็น ตามที่ Product spec เน้นย้ำ (ความเสี่ยงร้ายแรงถ้าหลุด)

Frontend:
- `Drop.location`/`HomeFeedItem.location` field ใหม่ (reuse คอลัมน์ `location` เดิม)
- `LocationResult` model + `LocationRepository` ใหม่ (เรียก Edge Function ผ่าน `supabase.functions.invoke`, แยก `LocationSearchRateLimitedException`/`LocationSearchFailedException`)
- `LocationPickerScreen` ใหม่ (full-screen push แทน bottom sheet — Design spec อนุญาตให้ AI Coding ตัดสินใจได้ เลือก full-screen เพราะ keyboard handling ง่ายกว่า เหมือน `FollowListScreen`/`ExcludeFriendsScreen`): ค้นหาแบบ debounce 450ms + race-condition guard, ปุ่ม "ใช้ตำแหน่งปัจจุบันของฉัน" ผ่าน `package:geolocator` ใหม่ (เพิ่ม dependency + permission declaration ใน `AndroidManifest.xml`/`Info.plist`)
- `CreateDropScreen`: ปุ่มปักหมุด toolbar เปลี่ยนจาก `_showComingSoon` เป็น `_showLocationPicker`, เพิ่ม `_LocationChip` (มิเรอร์ทรง `_AudienceChip`) แสดง/ลบสถานที่ที่เลือก
- `DropRepository`: `createDrop`/`createTextDrop`/`createDropFromExistingImage`/`createPollDrop` ทุกตัวรับ `location` param ใหม่ เขียนลง `drops.location`/`location_lat`/`location_lon`/`location_place_id`
- `HomeDropCard`/`DropDetailScreen`: ต่อท้าย " · 📍 {location}" ในบรรทัดเวลา (ไม่สร้างแถวใหม่) เมื่อมี location เท่านั้น ไม่ tappable ตาม Product spec

Files Changed:
- `supabase/schema.sql` (migration ต่อท้าย)
- `supabase/functions/location-search/_lib.ts`, `index.ts`, `_lib.test.ts` (ใหม่ทั้ง 3)
- `app/pubspec.yaml`/`pubspec.lock` (เพิ่ม `geolocator: ^13.0.2`)
- `app/android/app/src/main/AndroidManifest.xml`, `app/ios/Runner/Info.plist` (location permission declarations)
- `app/lib/features/drop/data/drop.dart`, `drop_repository.dart`, `location_result.dart` (ใหม่), `location_repository.dart` (ใหม่)
- `app/lib/features/drop/presentation/create_drop_screen.dart`, `location_picker_screen.dart` (ใหม่)
- `app/lib/features/home/data/home_feed_item.dart`
- `app/lib/features/home/presentation/widgets/home_drop_card.dart`
- `app/lib/features/drop/presentation/drop_detail_screen.dart`
- Tests: `app/test/drop_test.dart`, `home_feed_item_test.dart`, `create_drop_screen_test.dart`, `home_feed_screen_test.dart`, `drop_detail_screen_test.dart`, `location_result_test.dart` (ใหม่), `location_picker_screen_test.dart` (ใหม่) + fake `support/recording_drop_repository.dart`/`recording_location_repository.dart` (ใหม่) อัปเดต

Reason: Wynos V1.0.0 Beta2.pdf ข้อ 3/28 — Founder: "ปุ่มวงสีแดง คือจุดเช็คอินสถานที่ยังใช้งานไม่ได้" + Founder เลือก LocationIQ เป็น provider แล้ว (DECISIONS.md 2026-09-02)

Tests:
- `flutter analyze`: สะอาด (No issues found!)
- `flutter test`: 981/981 ผ่านหมด (รวมกับ WYN-097/099 ในรอบนี้)
- `deno test` (location-search): 13/13 ผ่านหมด, `deno check`: สะอาด

Build: ไม่ได้รัน `flutter build`/deploy Edge Function จริง (ไม่มี Android SDK/Supabase CLI access ใน session นี้)

Known Issues:
- **บล็อกด้วย Founder/DevOps action ตามที่ backlog เดิมระบุไว้แล้ว**: ยังไม่มี `LOCATIONIQ_API_KEY` จริง ทดสอบ end-to-end (ค้นหาสถานที่จริง, reverse geocoding จริง) ไม่ได้จนกว่าจะมี — โค้ดพร้อมใช้งานจริงทันทีที่มี key (fail gracefully ระหว่างรอ ไม่ block การโพสต์)
- ยังไม่ได้ apply migration จริงกับ production + ยังไม่ได้ deploy Edge Function จริง
- Geolocator permission flow (ขอสิทธิ์ GPS จริงบนอุปกรณ์) ยังไม่ได้ทดสอบบนอุปกรณ์จริง (ไม่มี simulator/emulator ใน sandbox) — ทดสอบผ่าน `@visibleForTesting debugResolveCurrentPosition` seam แทน (เหมือน pattern อื่นๆ ที่บันทึกไว้ใน DECISIONS.md)
- Rate-limit เพดาน (20 req/นาที) เป็นตัวเลขเริ่มต้นจาก AI Product Manager ยังไม่ได้ยืนยันกับหน้า pricing จริงของ LocationIQ ตามที่ Product spec เตือนไว้แล้ว
- Android `minSdkVersion` ใช้ค่า default ของ Flutter (`flutter.minSdkVersion`) ไม่ได้ระบุขั้นต่ำเองแยก — ควรเพียงพอสำหรับ `geolocator_android` แต่ยังไม่ได้ build APK จริงเพื่อยืนยัน

Handoff: ส่งต่อ AI QA & Security — (1) ทดสอบ end-to-end จริงทันทีที่ Founder/DevOps ให้ `LOCATIONIQ_API_KEY` มา (ค้นหา, reverse geocoding, rate-limit จริงที่เกิน 20 req/นาที) (2) ยืนยัน API key ไม่หลุดออกมาที่ client build ใดๆ (ตรวจ build artifact ตรงตาม Acceptance Criterion) (3) ทดสอบสิทธิ์ GPS จริงบนอุปกรณ์ (ปฏิเสธสิทธิ์ต้องไม่ทำให้แอป crash) (4) ยืนยัน migration/Edge Function deploy กับ production ตามวินัย WYN-071/072/083 (5) Regression เต็มรูปแบบตามที่ backlog เดิมระบุ

## QA Report (2026-09-03)

```
Feature: WYN-098 — Location Check-in (LocationIQ search + reverse geocoding)
Environment: Static/adversarial code review ของ commit 40cafac บน claude/wynos-beta2-phase2-handoff-w4mi5m (worktree ยืนยันตรง base แล้ว) — อ่าน `supabase/schema.sql` migration (บรรทัด ~11405-11545), `supabase/functions/location-search/{index.ts,_lib.ts}` เต็มไฟล์, `app/lib/features/drop/data/location_repository.dart`/`location_result.dart`, `app/lib/features/drop/presentation/location_picker_screen.dart` + รัน `flutter analyze`/`flutter test`/`deno test`/`deno check` อิสระทั้งหมด **ยืนยันแล้วว่า `LOCATIONIQ_API_KEY` ไม่ได้ตั้งค่าไว้ในsandbox นี้จริง (ตามที่ Coding Output ระบุ) — ทดสอบ end-to-end กับ LocationIQ จริงทำไม่ได้ในรอบนี้เช่นกัน** เน้นตรวจโครงสร้างโค้ด/error handling/graceful degradation แทน
Test Cases:
  1. ยืนยัน API key (`LOCATIONIQ_API_KEY`) ไม่ปรากฏในโค้ดฝั่ง client เลย (grep `app/lib` ทั้งหมด) — อยู่เฉพาะ `Deno.env.get()` ฝั่ง Edge Function เท่านั้น ไม่เคยถูกส่งกลับใน response body ใดๆ (`index.ts` คืนแค่ `{results: [...]}`หรือ `{error: "..."}`)
  2. ยืนยัน `index.ts` เช็ค `Authorization` header ก่อนเสมอ (401 ถ้าไม่มี), เช็ค rate limit (`countRecentRequests`) **ก่อน**เรียก LocationIQ เสมอ (429 ถ้าเกิน, ไม่แตะ quota จริง), เช็ค method POST เท่านั้น
  3. ยืนยัน graceful degradation เมื่อไม่มี API key: คืน 503 "LocationIQ not configured" ทันที ไม่ throw/crash — ฝั่ง client (`LocationRepository._invoke`) catch `FunctionException` แปลงเป็น `LocationSearchFailedException`/`LocationSearchRateLimitedException` ที่ typed ชัดเจน ไม่ปล่อย exception ดิบขึ้นไปหา UI
  4. ยืนยัน `fetchLocationIq()` มี timeout 7 วินาที (`AbortController`) ตรงตาม Product spec's "5-8 วินาที" — timeout/network error ถูก catch ที่ระดับบนสุดของ `Deno.serve` คืน 502 "Location search failed" เสมอ ไม่ทำให้ Edge Function ค้าง
  5. ยืนยัน `_lib.ts`'s pure functions (`parseSearchResults`/`parseReverseGeocodeResult`/`buildSearchUrl`/`buildReverseUrl`/`isRateLimited`/`userIdFromAuthHeader`) ครอบ edge case ที่สำคัญ: response ไม่ใช่ array, lat/lon ไม่ใช่ตัวเลข, display_name segment เดียว (ไม่มี comma), place_id ขาดหาย (fallback เป็น osm_type:osm_id), JWT header ผิดรูปแบบ — รัน `deno test` อิสระ: **13/13 ผ่าน**, `deno check`: สะอาด
  6. ยืนยัน `location_search_requests` table RLS enabled แต่**ไม่มี policy ให้ client เลย** (service-role only ผ่าน Edge Function) — ป้องกัน client เขียน/อ่านตรงเพื่อปลอมแปลง rate limit ของตัวเอง
  7. ยืนยัน constraint คู่ (`drops_location_lat_lon_together`, `drops_location_place_id_needs_name`) ถูกต้องตาม logic ที่ตั้งใจ (lat/lon ต้อง null คู่กันเท่านั้น, place_id ต้องมี location name คู่กันเสมอ) — ใช้ `drop constraint if exists` ก่อน `add constraint` ทำให้ migration รันซ้ำได้ปลอดภัย (ไม่มี `add constraint if not exists` ใน PostgreSQL จริง ตรงตามคอมเมนต์)
  8. ยืนยันไม่มี RLS change ที่ `drops` เอง สำหรับ location fields — สืบทอด audience/visibility เดิมของ WYN-097 อัตโนมัติ (ไม่มี privacy gap ใหม่)
  9. ยืนยัน `LocationPickerScreen` มี error state ที่แยกชัดเจน (rate-limited vs generic failure vs permission denied) ผ่านการรัน `flutter test test/location_picker_screen_test.dart` อิสระ: 12/12 ผ่าน รวมเทส "a denied location permission shows the specific permission-denied copy, without crashing" — ยืนยันว่าปฏิเสธสิทธิ์ GPS ไม่ทำให้แอป crash ตามที่ Handoff ข้อ (3) ขอ (ผ่าน `@visibleForTesting debugResolveCurrentPosition` seam ไม่ใช่ gesture/permission จริงบนอุปกรณ์ — ยังต้องทดสอบจริงบนอุปกรณ์ตามที่ Known Issues ระบุไว้แล้ว)
  10. รัน `flutter analyze`: สะอาด, `flutter test` เต็ม suite: 1011/1011 ผ่าน
Passed: ข้อ 1-10
Failed: ไม่มี
Severity: N/A (PASS)
Reproduction Steps: N/A
Expected: N/A
Actual: N/A
Security Findings: ไม่พบช่องโหว่ — API key อยู่ฝั่ง server เท่านั้นจริง, rate-limit บังคับที่ server ก่อนเรียก LocationIQ เสมอ (ไม่ใช่แค่ debounce ฝั่ง client), JWT auth ถูกต้อง (พึ่ง platform-level verify_jwt ของ Supabase ก่อนโค้ดรัน ไม่ re-verify เองซึ่งถูกต้องตามสถาปัตยกรรม Edge Function ของ Supabase) — **ยังไม่ได้ทดสอบ end-to-end กับ LocationIQ จริง** (ไม่มี API key ใน sandbox นี้) ตามที่ Coding Output ระบุไว้เอง เป็นข้อจำกัดที่ยอมรับได้ ไม่ใช่จุดที่ QA ควร FAIL เพราะโค้ดถูกออกแบบให้ fail gracefully ระหว่างรอ (verify ได้แล้วว่า "โพสต์ยังโพสต์ได้ตามปกติโดยไม่มีสถานที่แนบ" เมื่อค้นหาล้มเหลว)
Recommendation: อนุมัติเข้า approved — แต่ยังมี pre-deploy blocker ที่ AI Deploy & DevOps/Founder ต้องทำ: (1) Founder/DevOps ต้องสมัคร LocationIQ และตั้งค่า `LOCATIONIQ_API_KEY` secret จริงก่อน feature ใช้งานได้จริง (2) หลังมี key แล้วต้องทดสอบ end-to-end จริงอีกรอบ (ค้นหา, reverse geocoding, rate-limit ที่ >20 req/นาทีจริง) ก่อนประกาศพร้อมใช้งาน (3) apply migration + deploy Edge Function กับ production ตามวินัย WYN-071/072/083 (4) ทดสอบสิทธิ์ GPS จริงบนอุปกรณ์จริง (ไม่ใช่ seam) ก่อน sign off ขั้นสุดท้าย
Final Status: PASS
```
