# ZOKY — Feature Parity Matrix (Web เดิม → Flutter iOS/Android)

> สถานะ: **DRAFT — PENDING FOUNDER APPROVAL** · เจ้าของ: AI Product Manager · วันที่: 2026-10-17
> งานแม่: `.wyn/tasks/backlog/ZOKY-100-zoky-customer-app.md` · Roadmap: `.wyn/docs/product/zoky-roadmap.md`
> ข้อเสนอการตัดสินใจ: `.wyn/docs/product/zoky-decision-proposal.md`
>
> **ZOKY ในเอกสารนี้คือผลิตภัณฑ์ใหม่** (WYNOS Food ฝั่งลูกค้าที่เปลี่ยนชื่อเป็น ZOKY) **ไม่ใช่ ZOKY Marketplace เดิม**
> (ZOKY-001..005 / SELLER-001..005 และ `.wyn/docs/product/zoky-platform-roadmap.md` เป็นของเก่าที่โค้ดถูกลบไปแล้ว ใช้อ้างอิงประวัติเท่านั้น)

## วิธีทำ inventory

AI PM อ่านโค้ดจริงของ WYNOS Food ฝั่งลูกค้า ณ 2026-10-17:

- `web/components/food/wynos-food-developer-app.tsx` (แอปหลักหลังล็อกอิน, ~3,700 บรรทัด)
- `web/components/food/food-guest-browse.tsx`, `food-auth.tsx`, `food-delivery-map-picker.tsx`, `food-promotion-center.tsx`
- `web/lib/food-customer.ts`, `food-share.ts`, `food-share-preview.ts`, `food-home-banners.ts`, `food-featured-stores.ts`,
  `food-store-availability.ts`, `food-splash.ts`, `food-area-memory.ts`, `food-delivery-proof.ts`
- `web/app/food/**` (layout, manifest, login, signup, auth/callback, `s/[code]`), `web/proxy.ts`, `web/public/sw.js`
- Edge functions ที่ลูกค้าเรียก: `food-stripe-checkout`, `food-stripe-cancel`, `food-payment-qr`, `food-verify-slip`,
  `wynos-maps-geocode`, `location-search`, `send-push-notification`, `send-food-promotion`

ไม่ได้อ่านหรือแสดง secrets/env files ใด ๆ

## นิยามคอลัมน์และ Priority

- **Web**: สถานะบนเว็บปัจจุบัน ทุกแถวในตารางหลัก = "มีแล้ว" (ไม่มีการคิดฟีเจอร์ใหม่)
- **Flutter (iOS/Android)**: สิ่งที่แอป Flutter ต้องทำให้ได้พฤติกรรมเท่าเว็บ
- **Adaptive**: ส่วนที่ต้องปรับตามแพลตฟอร์ม (ตาม Founder direction ข้อ 7: แบรนด์เหมือนกัน แต่ระบบปฏิบัติการเป็นของแต่ละแพลตฟอร์ม)
- **Priority** (ใช้กำหนดลำดับการสร้าง ไม่ใช่ตัดสิทธิ์ parity):
  - **P0** = ต้องมีใน internal test build แรก (สั่งอาหารได้ครบจบตั้งแต่ล็อกอินจนได้รับอาหาร)
  - **P1** = ต้องครบก่อนส่ง App Store/Play แบบ public (parity)
  - **P2** = parity ที่ผลกระทบต่ำหรือรอคำตอบ Founder — ปล่อยหลัง public launch ได้เฉพาะเมื่อ Founder ยอมรับ

ค่าเริ่มต้นของแพลตฟอร์มที่ใช้ทุกแถว (ไม่เขียนซ้ำ): iOS ใช้ swipe-back จากขอบจอ, page transition แบบ Cupertino, bounce scroll;
Android ใช้ system back/predictive back, transition แบบ Material, glow/stretch scroll; dialog/action sheet/switch/date picker
ใช้แบบ native ของแต่ละแพลตฟอร์ม; สี โลโก้ ฟอนต์ การ์ด nav และ copy เป็นของ ZOKY เหมือนกันทั้งสองแพลตฟอร์ม

---

## A. Shell และสถานะพื้นฐาน (8)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| A01 | Launch splash | โลโก้ + wordmark แสดงครั้งเดียวต่อ session รอข้อมูลหน้าแรกพร้อม (≥1 วินาที, ≤~4 วินาที) | — | มีแล้ว | Native splash แล้วค้างจนข้อมูลหน้าแรกพร้อม (≤~4 วินาที) | iOS LaunchScreen storyboard / Android 12+ SplashScreen API | P1 |
| A02 | Loading skeleton | skeleton ของ brand, search, banner, chips, การ์ด | — | มีแล้ว | skeleton เทียบเท่า | — | P0 |
| A03 | Load error / ออฟไลน์ | จอ error + ปุ่ม "ลองอีกครั้ง", แถบไม่มีเน็ต, ข้อความ "ตะกร้าของคุณยังอยู่" | — | มีแล้ว | ตรวจ connectivity ได้จริง, retry, ตะกร้าไม่หาย | — | P0 |
| A04 | จอเข้าใช้ไม่ได้ | บัญชีไม่ผ่านเงื่อนไข → จอแจ้ง + ปุ่มเข้าสู่ระบบ | `food_customer_access_enabled`, `is_developer_account` | มีแล้ว | เรียก RPC เดียวกัน, จอเดียวกัน | — | P0 |
| A05 | Bottom navigation 4 แท็บ | หน้าหลัก / ออเดอร์ (badge จำนวนออเดอร์ที่กำลังทำ) / ข้อความ / บัญชี; ตะกร้าเข้าจาก header/แถบตะกร้า | — | มีแล้ว | nav 4 แท็บ + badge, เก็บ state แต่ละแท็บ | iOS: แตะแท็บซ้ำเลื่อนขึ้นบนสุด; Android: back จากแท็บอื่นกลับหน้าหลักก่อนออกแอป | P0 |
| A06 | Toast / ข้อความสถานะ | toast ปิดได้ (เช่น "บันทึกที่อยู่แล้ว", สถานะออเดอร์เปลี่ยน) | — | มีแล้ว | ข้อความสถานะ, อ่านได้ด้วย screen reader | iOS: in-app banner ด้านบน / Android: SnackBar | P0 |
| A07 | Pull-to-refresh | หน้าหลักและออเดอร์ ดึงลงเพื่อโหลดใหม่ | `fetchFoodCustomerSnapshot` | มีแล้ว | เทียบเท่า | iOS: Cupertino refresh / Android: RefreshIndicator | P1 |
| A08 | ลิงก์ข้ามไป WYNOS Social | การ์ด "WYNOS Social" บนหน้าหลัก + แถว "เปิด WYNOS Social" ในบัญชี | — | มีแล้ว | **รอ Founder ตัดสิน** ว่า ZOKY ยังลิงก์ไป WYNOS Social หรือไม่ (Q1) | เปิดเบราว์เซอร์ภายนอก | P2 |

## B. บัญชีและการยืนยันตัวตน (7)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| B01 | Guest browse | ไม่ล็อกอินก็ดูร้าน/เมนู/แบนเนอร์/ร้านแนะนำ/ค้นหาร้านหรือชื่ออาหารได้ ไม่ขอ GPS ไม่สั่งแบบ anonymous | `food_public_catalog` (anon), `food_active_home_banners`, `food_active_featured_stores` | มีแล้ว | เทียบเท่า, ห้ามเรียก RPC ส่วนตัวด้วย anon | — | P1 |
| B02 | ตะกร้า guest → ตะกร้าหลังล็อกอิน | ตะกร้า guest (≤50 บรรทัด, qty ≤99) ถูกนำเข้าตะกร้าจริงหลังล็อกอินเฉพาะร้านที่เลือก ราคาตรวจใหม่ฝั่ง server | — (validate ตอน quote/order) | มีแล้ว | เทียบเท่า (เก็บในเครื่อง) | — | P1 |
| B03 | ล็อกอินอีเมล/รหัสผ่าน | ข้อความ error แยก "ยังไม่ยืนยันอีเมล" / "อีเมลหรือรหัสผ่านไม่ถูกต้อง", ลงทะเบียนบัญชีในเครื่อง | Supabase Auth, `registerCurrentAccount` | มีแล้ว | เทียบเท่า, เก็บ session ใน secure storage | iOS/Android autofill รหัสผ่าน | P0 |
| B04 | ล็อกอินด้วย Google | OAuth PKCE → `/food/auth/callback` (มี workaround popup สำหรับ iOS PWA) | Supabase Auth (Google provider) | มีแล้ว | Google sign-in บนมือถือ (native หรือ OAuth + deep link — Architect ตัดสิน) | iOS: ASWebAuthenticationSession / Android: Custom Tabs หรือ Credential Manager | P0 |
| B05 | สมัครด้วยอีเมล | อีเมล + รหัสผ่าน (ขั้นต่ำตาม `MIN_SIGNUP_PASSWORD_LENGTH`) + ยืนยันรหัส, จอ "ตรวจสอบอีเมลของคุณ", ข้อความ "ไม่ต้องตั้ง @username" | Supabase Auth signUp | มีแล้ว | เทียบเท่า; ลิงก์ยืนยันในอีเมลต้องพากลับแอปหรือเว็บได้ถูก (ต้องตั้ง redirect URL ใหม่) | — | P0 |
| B06 | ลืมรหัสผ่าน | ไปหน้า `/forgot-password?returnTo=/food/login` ซึ่งเป็นหน้ากลางของ WYNOS | Supabase Auth reset | มีแล้ว | เปิด flow reset (เว็บหรือในแอป — Architect เสนอ) แล้วกลับเข้าแอปได้ | — | P0 |
| B07 | ออกจากระบบ | ออกจากระบบ + ยกเลิก push ของเครื่องนี้ + ล้าง cache session | Supabase Auth, ลบ `push_tokens` ของเครื่อง | มีแล้ว | เทียบเท่า (ลบ token ของเครื่องนี้) | — | P0 |

## C. หน้าหลักและการค้นหาร้าน (16)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| C01 | Header "ส่งถึง" | แสดงชื่อสถานที่/ป้ายของที่อยู่หลัก แตะแล้วไปแท็บบัญชี; ปุ่มร้านโปรดและตะกร้า (badge) | `food_customer_addresses` | มีแล้ว | เทียบเท่า | — | P0 |
| C02 | ค้นหาร้านหรือเมนู | ช่องค้นหา debounce ~280ms, ผลลัพธ์จาก server | `food_store_directory(p_query)` | มีแล้ว | เทียบเท่า | ปุ่ม search บนคีย์บอร์ด | P0 |
| C03 | แบนเนอร์หน้าหลัก | แบนเนอร์จาก Admin; แตะแล้วเปิดร้านปลายทางถ้ามี | `food_active_home_banners`, bucket `food-banners` | มีแล้ว | เทียบเท่า | — | P1 |
| C04 | ตัวกรอง | ทั้งหมด / ส่งฟรี / มีโปรฯ / ใกล้ฉัน (≤3 กม.) / เรตติ้ง 4.5+ | client-side จาก directory | มีแล้ว | เทียบเท่า | — | P1 |
| C05 | ร้านแนะนำ | ร้านที่ Admin ตั้งเป็น featured (เฉพาะตัวกรอง "ทั้งหมด") | `food_active_featured_stores` | มีแล้ว | เทียบเท่า | — | P1 |
| C06 | รวมโค้ดลดเพิ่ม + "เก็บโค้ด" | การ์ดโปรร้าน; ปุ่มเก็บโค้ดจำ**ในเครื่องเท่านั้น** (localStorage ต่อผู้ใช้) ไม่มีผลฝั่ง server | ข้อมูลโปรจาก `food_store_directory` | มีแล้ว | เทียบเท่า (เก็บในเครื่อง) — **รอ Founder ยืนยันว่าเก็บในเครื่องแบบเดิม (Q7)** | — | P2 |
| C07 | สั่งอีกครั้ง | แถบร้านที่เคยสั่ง (ไม่นับออเดอร์ยกเลิก) | จากรายการออเดอร์ | มีแล้ว | เทียบเท่า | — | P1 |
| C08 | ร้านใกล้คุณ | เรียงร้านเปิดก่อน แล้วตามระยะ (haversine จากหมุดที่อยู่หลัก) | `food_store_directory` | มีแล้ว | เทียบเท่า (สูตรเดียวกับเว็บ) | — | P0 |
| C09 | ร้านยอดนิยม | เรียงตามจำนวนออเดอร์ส่งสำเร็จ แล้วเรตติ้ง | `food_store_directory` | มีแล้ว | เทียบเท่า | — | P1 |
| C10 | "ดูทั้งหมด" | เปิดรายการเต็มของโปร/สั่งอีกครั้ง/ใกล้คุณ/ยอดนิยม | — | มีแล้ว | เทียบเท่า | iOS: push page / Android: full-screen route | P1 |
| C11 | การ์ดร้าน | รูปปก, ป้าย "โฆษณา", "ปิดอยู่", ป้ายโปร, ETA, เรตติ้งหรือ "ร้านใหม่", ระยะ, หมวด, ค่าส่ง | `food_store_directory` | มีแล้ว | เทียบเท่า | — | P0 |
| C12 | บันทึกคลิกโฆษณา | แตะร้านที่เป็นโฆษณา → แจ้ง server (server ตัดสินเองว่าคิดเงินไหม) | `food_ad_click` | มีแล้ว | เทียบเท่า (สำคัญต่อความถูกต้องของการคิดเงินร้าน) | — | P1 |
| C13 | ร้านโปรด | กดหัวใจในหน้าร้าน; รายการร้านโปรดจาก header; เก็บ**ในเครื่องเท่านั้น** | `food_store_directory` | มีแล้ว | เทียบเท่า (เก็บในเครื่อง) — **รอ Founder ยืนยัน (Q7)** | — | P2 |
| C14 | ศูนย์โปรโมชันและข่าวสาร | inbox 30 รายการล่าสุด, จำนวนยังไม่อ่าน, แตะ = อ่านแล้ว, ปุ่ม "ใช้โค้ดนี้" (บันทึก + คัดลอกโค้ด) | `food_notifications` (select/update ของตัวเอง) | มีแล้ว | เทียบเท่า | การคัดลอกใช้ clipboard ของระบบ | P1 |
| C15 | ตั้งค่าการรับโปรโมชัน | สวิตช์ข่าวสารในแอป / Push โปรโมชัน (เปิด push จะขอสิทธิ์เครื่อง); ไม่กระทบแจ้งเตือนออเดอร์ | `food_marketing_preferences` (upsert) | มีแล้ว | เทียบเท่า | iOS: CupertinoSwitch / Android: Material Switch | P1 |
| C16 | Empty states | ไม่มีร้านในพื้นที่ → "เปลี่ยนที่อยู่จัดส่ง"; ค้นหาไม่พบ | — | มีแล้ว | เทียบเท่า | — | P0 |

## D. หน้าร้าน (13)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| D01 | Store hero | รูปปก, ปุ่มกลับ/ค้นหาเมนู/หัวใจ/แชร์, ป้ายร้านปิด; จอ "ยังไม่มีร้าน" | `food_stores` | มีแล้ว | เทียบเท่า | ไอคอนกลับ/แชร์ตามแพลตฟอร์ม | P0 |
| D02 | ข้อมูลร้าน + สถานะเปิด/ปิด | เรตติ้ง, ระยะ, ETA, ค่าส่ง; เปิด/ปิดตามตารางรายสัปดาห์, วันหยุดพิเศษ, ปิดชั่วคราว (เวลา Asia/Bangkok) | `food_stores`, `food_store_review_feed` (limit 1); ตรรกะใน `food-store-availability.ts` | มีแล้ว | ต้อง port ตรรกะเวลาเปิด/ปิดให้ผลเหมือนเว็บทุกกรณี (server ยังตรวจซ้ำตอนสั่ง) | — | P0 |
| D03 | ยอดสั่งขั้นต่ำ | แสดง "สั่งขั้นต่ำ ฿X" | `food_stores.minimum_order` | มีแล้ว | เทียบเท่า | — | P0 |
| D04 | ป้ายแคมเปญของแพลตฟอร์ม | แคมเปญที่ร้านเข้าร่วมและกำลังทำงาน | `food_platform_campaign_badges` | มีแล้ว | เทียบเท่า (copy "แคมเปญ WYNOS" ต้องเปลี่ยน — ดู rebrand checklist) | — | P1 |
| D05 | แท็บ เมนู / รีวิว / ข้อมูลร้าน | สลับ 3 ส่วน | — | มีแล้ว | เทียบเท่า | iOS: segmented style / Android: TabBar (ใช้สีแบรนด์เดียวกัน) | P0 |
| D06 | แท็บข้อมูลร้าน | คำอธิบาย, ที่อยู่, เบอร์ (แตะโทร), เวลาเปิด, เวลาเตรียม, พื้นที่จัดส่ง | `food_stores` | มีแล้ว | เทียบเท่า | การโทรผ่าน dialer ของระบบ | P1 |
| D07 | หมวดเมนู | chips เรียงตาม `menu_category_order` ของร้าน | `food_stores`, `food_menu_items` | มีแล้ว | เทียบเท่า | — | P0 |
| D08 | เมนูแนะนำ | tile 6 รายการแรกที่สั่งได้ (แสดงเมื่อ ≥3) | `food_menu_items` | มีแล้ว | เทียบเท่า | — | P1 |
| D09 | รายการเมนู + สต็อก | จัดกลุ่มตามหมวด, ของหมดอยู่ท้าย (รูปจริง), ป้าย "เหลือ N ชิ้นวันนี้"/"ขายหมดวันนี้"/"จำกัด N ชิ้น/วัน" | `food_menu_items`, `food_menu_stock_remaining` | มีแล้ว | เทียบเท่า | — | P0 |
| D10 | ค้นหาเมนูในร้าน | เมนูยอดนิยม, คำค้นล่าสุด 5 คำ (เก็บในเครื่องต่อร้าน), ผลลัพธ์ ≤30 | client-side | มีแล้ว | เทียบเท่า | — | P1 |
| D11 | รีวิวร้าน | ค่าเฉลี่ย, จำนวน, รีวิว 20 ล่าสุด, tags, ร้านตอบกลับ, ดูเพิ่ม/ย่อ | `food_store_review_feed` | มีแล้ว | เทียบเท่า | — | P1 |
| D12 | แชร์ลิงก์ร้าน | ลิงก์สั้น `/s/<code>` (ไม่มี code ใช้ `?store=<id>`), share sheet หรือคัดลอก | `food_stores.share_code` | มีแล้ว | เทียบเท่า โดยลิงก์เป็นโดเมนใหม่ (`zoky.online`) | iOS: share sheet + ไอคอน square-arrow-up / Android: Sharesheet + ไอคอน share | P1 |
| D13 | เปิดจากลิงก์ที่แชร์ | `?store=`/`/s/<code>` เปิดร้านนั้น, จำข้ามการล็อกอิน (1 ชม.), แจ้งถ้าตะกร้าเดิมถูกล้าง, จำว่ามาจากลิงก์ 24 ชม. แล้ว mark ออเดอร์ | `food_store_id_by_share_code`, `food_record_share_open`, `food_mark_order_from_share` | มีแล้ว | Universal Links (iOS) / App Links (Android) ของ `zoky.online/s/*` และ `/?store=`; ถ้าไม่มีแอปให้เปิดเว็บ | ไฟล์ AASA / assetlinks.json บนโดเมน | P1 |

## E. รายละเอียดเมนูและตะกร้า (9)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| E01 | หน้ารายละเอียดเมนู | รูป, คำอธิบาย, ป้ายสต็อก, ราคารวมตัวเลือก, กลุ่มตัวเลือก (บังคับ/เลือกได้สูงสุด 1–20, radio/checkbox), หมายเหตุ ≤200 ตัวอักษร, stepper จำกัดตามสต็อก, ปุ่มบอกเหตุผลเมื่อสั่งไม่ได้ | `food_menu_items.options` | มีแล้ว | เทียบเท่า | iOS: modal sheet ลากปิดได้ / Android: full-screen sheet + back ปิด | P0 |
| E02 | ใส่ตะกร้า/รวมบรรทัด | รวมบรรทัดที่ key เดียวกัน (เมนู+ตัวเลือก+หมายเหตุ), แก้บรรทัดเดิม (เมนูไม่มีตัวเลือก), เคารพสต็อกรวม | — | มีแล้ว | เทียบเท่า (ตรรกะ `foodCartLineKey` เดียวกัน) | — | P0 |
| E03 | ตะกร้าร้านเดียว | ตะกร้าเก็บในเครื่องต่อผู้ใช้; เปลี่ยนร้านต้องยืนยันและล้างตะกร้า | — | มีแล้ว | เทียบเท่า (เก็บในเครื่อง ไม่ sync กับเว็บ) | dialog ยืนยันแบบ native | P0 |
| E04 | หน้าตะกร้า | หัวร้าน + ETA, บรรทัดพร้อมตัวเลือก/หมายเหตุ, stepper, ลบ, ล้างตะกร้า (ยืนยัน), "เพิ่มเมนูอื่นจากร้านนี้" | — | มีแล้ว | เทียบเท่า | dialog ยืนยันแบบ destructive ของแต่ละแพลตฟอร์ม | P0 |
| E05 | ราคาจาก server (quote) | คำนวณใหม่ทุกครั้งที่ตะกร้าเปลี่ยน (debounce ~180ms) | `food_quote_order` | มีแล้ว | เทียบเท่า; ยอดที่แสดงยึด server | — | P0 |
| E06 | สิทธิ์ลูกค้าใหม่ | แบนเนอร์ "ค่าอาหารครบ ฿100 ลดทันที ฿40" + บอกยอดที่ขาด | `food_first_order_offer` | มีแล้ว | เทียบเท่า | — | P1 |
| E07 | แคมเปญที่ระบบเลือกให้ | แสดงชื่อแคมเปญจาก quote + ส่วนลด | `food_quote_order` | มีแล้ว | เทียบเท่า | — | P1 |
| E08 | ตรวจตะกร้าก่อนชำระ | บล็อกเมื่อมีเมนูหมด/ตัวเลือกเปลี่ยน/เกินสต็อก/ไม่ถึงขั้นต่ำ/ร้านปิด พร้อมข้อความ | client + server | มีแล้ว | เทียบเท่า | — | P0 |
| E09 | แถบตะกร้าลอย | บนหน้าร้าน แสดงจำนวนและยอด แตะไปตะกร้า | — | มีแล้ว | เทียบเท่า (เคารพ safe area/home indicator) | — | P0 |

## F. Checkout (8)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| F01 | เลือกที่อยู่ | เลือกที่อยู่หลักที่ข้อมูลครบก่อน, เปลี่ยน/แก้ไข/เพิ่ม | `food_customer_addresses` | มีแล้ว | เทียบเท่า | iOS: action sheet / Android: bottom sheet | P0 |
| F02 | ตรวจปัญหาที่อยู่ | ที่อยู่เก่าไม่ครบ, ยังไม่ปักหมุด (ร้านมีโซนส่ง), quote แจ้งปัญหาพื้นที่ → ปุ่ม "เลือกที่อยู่อื่น" | `food_quote_order` | มีแล้ว | เทียบเท่า | — | P0 |
| F03 | หมายเหตุถึงผู้จัดส่ง | ช่องข้อความ | — | มีแล้ว | เทียบเท่า | — | P0 |
| F04 | โค้ดส่วนลด | พิมพ์ (ตัวพิมพ์ใหญ่ ≤24), ใช้/ลบ, จำโค้ดในเครื่อง, เติมจากลิงก์ `?promo=`, error เมื่อใช้ไม่ได้ | `food_quote_order_v2`, `food_create_order_v2` | มีแล้ว | เทียบเท่า (รับ `promo` จาก deep link) | คีย์บอร์ดตัวพิมพ์ใหญ่ | P1 |
| F05 | Quote ตามที่อยู่ | คำนวณค่าส่งตามระยะ (กม.) เมื่อมีหมุด, สถานะ "กำลังคำนวณค่าส่ง…" | `food_quote_order(_v2)` พร้อม `p_latitude/p_longitude` | มีแล้ว | เทียบเท่า | — | P0 |
| F06 | สรุปคำสั่งซื้อ | รายการ, ค่าอาหาร, ค่าส่ง + ระยะ, ส่วนลด, เวลาถึงโดยประมาณ | quote | มีแล้ว | เทียบเท่า | — | P0 |
| F07 | แจ้งวิธีชำระ + 10 นาที | แสดงช่องทาง (QR พร้อมเพย์/โอนแนบสลิป/บัตร) และ "ชำระภายใน 10 นาที ไม่งั้นยกเลิกอัตโนมัติ" | `food_stores` | มีแล้ว | เทียบเท่า | — | P0 |
| F08 | สร้างออเดอร์ | จัดส่งอย่างเดียว (`scheduledFor = null`, decision 2026-10-10), รวมหมายเหตุอาคาร/ชั้น/ห้อง/จุดสังเกต, ส่งหมุดเมื่อร้านมีโซน, mark ลิงก์แชร์, แปลง error เป็นข้อความไทย (`foodCustomerError`) แล้วเปิดหน้าชำระเงิน | `food_create_order` / `food_create_order_v2`, `food_mark_order_from_share` | มีแล้ว | เทียบเท่า รวมข้อความ error ทุกกรณี | — | P0 |

## G. การชำระเงิน (7)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| G01 | นับถอยหลัง | นับถึง `payment_due_at` ทุกวินาที | `food_orders.payment_due_at` | มีแล้ว | เทียบเท่า (คำนวณใหม่เมื่อกลับมาจาก background) | — | P0 |
| G02 | QR พร้อมเพย์ | QR ตั้งยอดอัตโนมัติจาก server; fallback รูป QR ของร้าน; แสดงเฉพาะร้านเจ้าของออเดอร์ | `food-payment-qr` (edge), `food_stores.payment_qr_path` | มีแล้ว | เทียบเท่า | — | P0 |
| G03 | ข้อมูลบัญชี + คัดลอก | พร้อมเพย์/บัญชีธนาคาร + ปุ่มคัดลอก | `food_stores` | มีแล้ว | เทียบเท่า | feedback การคัดลอกตามแพลตฟอร์ม | P0 |
| G04 | แนบสลิป | เลือกรูป JPG/PNG/WebP ≤8MB, ดูตัวอย่าง, เปลี่ยน/ลบ, ลบ location ออกจากรูป, upload `food-private/<uid>/slips/<order>/…`, ส่ง แล้วตรวจสลิปอัตโนมัติ (ผ่าน/รอร้านตรวจ/ไม่ผ่าน) | Storage `food-private`, `food_submit_payment`, `food-verify-slip` (edge), webhook `validate-upload` | มีแล้ว | เทียบเท่า รวมการลบ EXIF location | iOS: PHPicker / Android: Photo Picker | P0 |
| G05 | จ่ายด้วยบัตร (Stripe) | ขอ URL checkout แล้วเปิดหน้า Stripe; กลับมาที่ `?order=…&stripe=success|cancelled`; สถานะจ่ายยึด webhook ไม่ยึดพารามิเตอร์ | `food-stripe-checkout` (edge), `stripe-webhook` | มีแล้ว | เปิด Stripe ในเบราว์เซอร์ระบบแล้วกลับแอปด้วย deep link — **ติด blocker: edge function ตรวจ `Origin === https://food.wynos.online` ใน live mode และ success/cancel URL hardcode** (R1) | iOS: SFSafariViewController/ASWebAuthenticationSession / Android: Custom Tabs | P1 |
| G06 | เปลี่ยนจาก Stripe เป็นสลิป | ยกเลิก Stripe session ก่อนอัปโหลดสลิป | `food-stripe-cancel` (edge) | มีแล้ว | เทียบเท่า — **ติด origin check เดียวกับ G05** | — | P1 |
| G07 | สถานะการชำระ | กำลังตรวจสลิป, หมดเวลาชำระ, ยกเลิกเพราะหมดเวลา, `payment_note`, ร้านยังไม่ตั้งช่องทางรับเงิน | `food_orders` | มีแล้ว | เทียบเท่า | — | P0 |

## H. ออเดอร์และการติดตาม (10)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| H01 | รายการออเดอร์ | segment "กำลังดำเนินการ (N)" / "ประวัติ", สถานะ+สี, ปุ่ม ชำระเงิน/ติดตาม/ดูรายละเอียด/ให้คะแนน/สั่งอีกครั้ง | `food_orders` + `food_order_items` + `food_delivery_proofs` | มีแล้ว | เทียบเท่า | iOS: segmented control / Android: segmented button (สีแบรนด์) | P0 |
| H02 | โหลดประวัติเพิ่ม | หน้าละ 100 รายการ | `food_orders` (range) | มีแล้ว | เทียบเท่า | — | P1 |
| H03 | Realtime + แจ้งในแอป | subscribe การเปลี่ยนแปลง `food_orders` ของตัวเอง แล้ว toast "ออเดอร์ #N · สถานะ" | Supabase Realtime (`postgres_changes`, filter `buyer_id`) | มีแล้ว | เทียบเท่า + subscribe ใหม่เมื่อกลับจาก background | — | P0 |
| H04 | ติดตามสถานะ | stepper 5 ขั้น + การ์ดรายละเอียด (ETA ตอนเตรียมอาหาร) | `food_orders` | มีแล้ว | เทียบเท่า | — | P0 |
| H05 | หลักฐานการจัดส่ง | รูปจาก signed URL 15 นาที, "ส่งให้ผู้รับโดยตรง"/"วางไว้: …", แตะดูรูปเต็ม | Storage `food-private` signed URL | มีแล้ว | เทียบเท่า | image viewer ที่ pinch-zoom ได้ตามแพลตฟอร์ม | P1 |
| H06 | ยกเลิกออเดอร์ | ได้เฉพาะ `pending_acceptance` และยังไม่จ่าย, ต้องยืนยัน | `food_cancel_order` | มีแล้ว | เทียบเท่า | dialog แบบ destructive ตามแพลตฟอร์ม | P0 |
| H07 | สั่งอีกครั้ง | สร้างตะกร้าจากออเดอร์เก่า (ยืนยันถ้าจะแทนตะกร้าเดิม), สลับร้านถ้าจำเป็น | — | มีแล้ว | เทียบเท่า | — | P1 |
| H08 | ติดต่อร้าน | ปุ่มโทรหาร้านของออเดอร์ | `food_stores.phone` | มีแล้ว | เทียบเท่า | dialer ของระบบ | P1 |
| H09 | ออเดอร์ล่วงหน้าเดิม | แสดง `scheduled_for` ของออเดอร์เก่าที่ยังมี (สร้างใหม่ไม่ได้แล้ว) | `food_orders.scheduled_for` | มีแล้ว | แสดงอย่างเดียว | — | P2 |
| H10 | เปิดออเดอร์จากลิงก์ | `?order=WFxxxx` (จากแจ้งเตือน/การกลับจาก Stripe) เปิดออเดอร์นั้นหลังโหลด | — | มีแล้ว | deep link ไปหน้าออเดอร์ (จำเป็นสำหรับ push และ Stripe) | — | P0 |

## I. รีวิว (2)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| I01 | เขียนรีวิว | 1–5 ดาว + คำบรรยาย, tags ≤5 จาก `FOOD_REVIEW_TAGS`, ข้อความ ≤500, ไม่ระบุชื่อ (แสดงชื่อแบบ mask ให้ดูก่อน) | `food_submit_store_review` | มีแล้ว | เทียบเท่า | — | P1 |
| I02 | ชวนรีวิว + รีวิวของฉัน | ปุ่ม "ให้คะแนน" บนออเดอร์ส่งสำเร็จที่ยังไม่รีวิว, "ขอบคุณที่รีวิว" เมื่อรีวิวแล้ว | `food_my_store_reviews` | มีแล้ว | เทียบเท่า | — | P1 |

## J. ที่อยู่และตำแหน่ง (8)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| J01 | รายการที่อยู่ | ป้ายที่อยู่หลัก, สถานะปักหมุด/ข้อมูลไม่ครบ, แก้ไข, ลบ (ยืนยัน) | `food_customer_addresses`, `food_delete_customer_address` | มีแล้ว | เทียบเท่า | iOS: swipe action ได้แต่ต้องมีปุ่มด้วย / Android: ปุ่ม | P0 |
| J02 | ฟอร์มที่อยู่แบบโครงสร้างไทย | ชื่อ, ผู้รับ, เบอร์, บ้านเลขที่, อาคาร, หมู่/ชั้น/ห้อง, ซอย/ถนน, จังหวัด/อำเภอ/ตำบล, รหัสไปรษณีย์ 5 หลัก, จุดสังเกต, หมายเหตุ, ที่อยู่หลัก; ต้องปักหมุดก่อนบันทึก | `food_upsert_customer_address_v3` (เว็บมี fallback v2/legacy) | มีแล้ว | เทียบเท่า (Architect ตัดสินว่าแอปเรียก v3 อย่างเดียวได้หรือไม่) | autofill ที่อยู่/เบอร์ของระบบ, keyboard ตัวเลข | P0 |
| J03 | เติมจังหวัด/อำเภอ/ตำบลจากสถานที่ | parse ชื่อ/ที่อยู่ของ place ที่เลือก | client-side | มีแล้ว | เทียบเท่า | — | P1 |
| J04 | ตรวจว่าร้านส่งถึงไหม | ในฟอร์มแสดง "ร้านนี้ส่งถึง · X กม. · ค่าส่ง" หรือเหตุผลที่ส่งไม่ได้ | `food_delivery_availability` | มีแล้ว | เทียบเท่า | — | P1 |
| J05 | แผนที่ปักหมุด | แผนที่ (MapLibre + OpenFreeMap), หมุดกลางจอเลื่อนแผนที่, ชื่อสถานที่จาก reverse geocode, สถานที่ใกล้เคียงของ WYNOS, รายละเอียดสถานที่/จุดทางเข้า | `wynos_reverse_place`, `wynos_nearby_places`, `wynos_place_details`, `/api/maps/reverse` (Next route), `wynos-maps-geocode`, `location-search` | มีแล้ว | เทียบเท่า (เลือก map SDK โดย Architect; ตรวจเงื่อนไขการใช้ tiles บนมือถือ) | gesture แผนที่ตามแพลตฟอร์ม | P0 |
| J06 | ตำแหน่งปัจจุบัน (GPS) | ปุ่มหาตำแหน่ง, ข้อความเมื่อไม่ได้รับอนุญาต | Geolocation | มีแล้ว | เทียบเท่า + ข้อความขอสิทธิ์ | iOS: `NSLocationWhenInUseUsageDescription` / Android: permission rationale | P0 |
| J07 | ค้นหาสถานที่ | ลำดับ: สถานที่ของร้าน → WYNOS Places → `/api/maps/search` → `wynos-maps-geocode` → `location-search` | `wynos_search_store_places`/`food_search_store_places`, `wynos_search_places`, Next route, edge functions | มีแล้ว | เทียบเท่า (Next route ต้องเรียกด้วย URL เต็ม; edge function ตรวจ Origin allowlist — R7) | — | P0 |
| J08 | เสนอสถานที่ที่หายไป | ฟอร์มชื่อ/หมวด/ที่อยู่/หมายเหตุ ใช้หมุดปัจจุบัน, จำกัดต่อวัน, กันซ้ำ | `submit_wynos_place_suggestion` | มีแล้ว | เทียบเท่า | ตัวเลือกหมวดเป็น picker ของแพลตฟอร์ม | P2 |

## K. การแจ้งเตือน (4)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| K01 | เปิดแจ้งเตือนบนเครื่อง | บัญชี → การแจ้งเตือน: ขอสิทธิ์ + บันทึก token (`app = food`), แสดง "เปิดแล้วสำหรับอุปกรณ์นี้" | `push_tokens` | มีแล้ว (Web Push ผ่าน FCM) | FCM บน iOS/Android, บันทึก token พร้อม platform และ app ที่ถูกต้อง | iOS: ขอสิทธิ์ตามจังหวะที่ Apple แนะนำ / Android 13+: `POST_NOTIFICATIONS` | P0 |
| K02 | Push สถานะออเดอร์ | ร้านรับ (พร้อม ETA), กำลังส่ง, ส่งถึง, ร้านยกเลิก (พร้อมข้อความคืนเงิน) | trigger `food_orders_status_notify` → `send-push-notification` | มีแล้ว | ได้รับบนมือถือ — **ต้องยืนยันว่า routing ของ `send-push-notification` ส่งให้ token ของแอปใหม่ (R2)** | — | P0 |
| K03 | Push โปรโมชัน | ส่งตาม consent, งดช่วง 22:00–08:00 | `send-food-promotion` | มีแล้ว | ได้รับบนมือถือ — **ปัจจุบัน query เฉพาะ `platform = web` และ `app = food` ต้องแก้ backend (R2)** | — | P1 |
| K04 | แตะแจ้งเตือน | แจ้งเตือนออเดอร์เปิด `?order=`; โปรโมชันเปิดหน้าแรกพร้อมเติมโค้ด | `web/public/sw.js` | มีแล้ว | เทียบเท่า (handler ของ FCM ทั้งตอน foreground/background/terminated) | — | P1 |

## L. ข้อความ (1)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| L01 | แท็บข้อความ | **เป็น placeholder เท่านั้น** ("ยังไม่มีข้อความ", "แชทแยกจากแชท WYNOS") ไม่มีแชทจริง | — | มีแล้ว (placeholder) | ทำ placeholder เท่าเว็บ — **รอ Founder ยืนยันว่าจะแสดงแท็บนี้บนแอปไหม (Q8)** | — | P2 |

## M. บัญชีอื่น ๆ (3)

| ID | ฟีเจอร์ | พฤติกรรมเว็บปัจจุบัน | Backend | Web | Flutter (iOS/Android) | Adaptive | P |
|---|---|---|---|---|---|---|---|
| M01 | การ์ดโปรไฟล์ | ชื่อ/เบอร์จากที่อยู่หลัก หรือชวน "ตั้งค่าโปรไฟล์ก่อนสั่งอาหาร" | `food_customer_addresses` | มีแล้ว | เทียบเท่า | — | P0 |
| M02 | ทางลัดประวัติการสั่ง | เปิดแท็บออเดอร์ | — | มีแล้ว | เทียบเท่า | — | P1 |
| M03 | "ขายอาหารบน WYNOS Food" | ลิงก์ LINE OA ของทีม | — | มีแล้ว | เทียบเท่า (copy เป็น ZOKY) | เปิดแอป LINE/เบราว์เซอร์ | P2 |

---

## สรุปจำนวน

| หมวด | จำนวน | P0 | P1 | P2 |
|---|---|---|---|---|
| A. Shell | 8 | 5 | 2 | 1 |
| B. บัญชี/Auth | 7 | 5 | 2 | 0 |
| C. หน้าหลัก/ค้นหาร้าน | 16 | 5 | 9 | 2 |
| D. หน้าร้าน | 13 | 6 | 7 | 0 |
| E. เมนู/ตะกร้า | 9 | 7 | 2 | 0 |
| F. Checkout | 8 | 7 | 1 | 0 |
| G. ชำระเงิน | 7 | 5 | 2 | 0 |
| H. ออเดอร์/ติดตาม | 10 | 5 | 4 | 1 |
| I. รีวิว | 2 | 0 | 2 | 0 |
| J. ที่อยู่/ตำแหน่ง | 8 | 5 | 2 | 1 |
| K. แจ้งเตือน | 4 | 2 | 2 | 0 |
| L. ข้อความ | 1 | 0 | 0 | 1 |
| M. บัญชีอื่น ๆ | 3 | 1 | 1 | 1 |
| **รวม** | **96** | **53** | **36** | **7** |

---

## ส่วนที่เป็นของเว็บเท่านั้น (ไม่ port ไปแอป — แต่ต้อง rebrand บนเว็บ)

| ID | รายการ | ที่อยู่ในโค้ด | หมายเหตุ |
|---|---|---|---|
| W01 | ปุ่ม "ติดตั้ง WYNOS Food" (PWA install prompt) | `AccountPanel`, `beforeinstallprompt` | แอปมือถือไม่ต้องใช้ |
| W02 | PWA manifest, icons, iOS launch images, theme color | `web/app/food/manifest.ts`, `layout.tsx`, `public/icons/food/*` | rebrand บนเว็บ |
| W03 | SEO metadata, JSON-LD WebSite, canonical | `web/app/food/layout.tsx` | rebrand + ย้าย canonical |
| W04 | Link preview (OG/Twitter) ของร้านที่แชร์ | `web/app/food/page.tsx`, `lib/food-share-preview.ts` (`food_store_share_preview`) | rebrand siteName/รูป fallback |
| W05 | Route ลิงก์สั้น `/s/[code]` + นับการเปิด | `web/app/food/s/[code]/route.ts` | ต้องทำงานทั้งบน `zoky.online` และหลัง redirect จาก `food.wynos.online` |
| W06 | Host routing / redirect `/login`, `/signup` บนโดเมน Food | `web/proxy.ts` | ต้องเพิ่ม host ใหม่ + redirect โดเมนเดิม |
| W07 | จอ "ต้องเปิด WYNOS Food เวอร์ชันใหม่" สำหรับ PWA ที่ติดตั้งจาก wynos.online รุ่นเก่า | `food-auth.tsx` | จะเกิดเหตุการณ์คล้ายกันอีกตอนย้ายไป `zoky.online` (R4) |
| W08 | Workaround Google OAuth popup ของ iOS PWA | `food-auth.tsx`, `app/food/auth/callback/page.tsx` | เฉพาะ PWA |
| W09 | เติมหมุดจาก WYNOS Maps (localStorage `wynos:maps:last-pin` 30 นาที) | `draftWithLastWynosMapsPin` | อาศัย storage ร่วมโดเมน — บนแอปไม่มีแหล่งข้อมูลนี้ และจะหายบนเว็บเมื่อย้ายโดเมน |
| W10 | Service worker แสดงแจ้งเตือนและ route การแตะ | `web/public/sw.js` | rebrand ไอคอน; แอปใช้ handler ของ FCM แทน |

## Merchant-only / developer-only / ฝั่ง Social (นอก scope ZOKY — บันทึกไว้)

- `is_developer_account`: บัญชีนักพัฒนาข้ามการตรวจพื้นที่มหาสารคามได้ (ฝั่ง client สะท้อนพฤติกรรม server) — แอปต้องคงพฤติกรรมนี้ไว้เพื่อให้ทีมทดสอบได้ แต่ไม่ใช่ฟีเจอร์ลูกค้า
- `DeveloperRouteGate`: ชื่อเก่า ปัจจุบันเป็นแค่ gate "ล็อกอินแล้ว" (ไม่มี allowlist)
- โหมด `standalone` ของ `food-delivery-map-picker.tsx` = **WYNOS Maps** (เส้นทาง/นำทาง, สถานที่ที่บันทึก, รูปสถานที่, เลเยอร์) ไม่ใช่ของ Food
- `parseFoodLocation`, `checkFoodServiceArea`, `web/lib/food-merchant.ts` ใช้ใน WYNOS Merchant
- `food_create_scheduled_order(_v2)` และฝั่ง pickup: server ยังมี แต่ UI ลูกค้าถูกถอดตาม decision 2026-10-10 — **ห้ามนำกลับมาในแอป**
- `web/lib/food-area-memory.ts` + ทางลัด Food ในหน้า Social (WYN-195/211/212) เป็นจุดที่ **WYNOS Social พาคนเข้า Food** — ต้องตัดสินว่าหลัง rebrand ชี้ไป ZOKY อย่างไร (Q1)
- `web/app/food/icon-v7`, `icon-v10`: route ไอคอนรุ่นเก่า
- Merchant ใช้ `foodStoreShareUrl` ทำ QR poster ให้ร้านพิมพ์ — ลิงก์ `food.wynos.online/s/<code>` บนกระดาษจะอยู่ไปอีกนาน (R5)

## ข้อกำหนดของ App Store / Play ที่เว็บยังไม่มี (ไม่นับเป็น parity — ต้องให้ Founder ตัดสิน)

ห้าม AI ทีมเพิ่มเอง เพราะบางข้อเป็นการเปลี่ยน authentication architecture:

1. **Sign in with Apple** — App Store Review Guideline 4.8 กำหนดว่าแอปที่ใช้ login ของบุคคลที่สาม (Google) ต้องมีตัวเลือก login ที่เคารพความเป็นส่วนตัวเทียบเท่า (Sign in with Apple เข้าเกณฑ์) → ถ้าไม่ทำ มีความเสี่ยงถูก reject (Q3)
2. **ลบบัญชีในแอป** — Guideline 5.1.1(v) กำหนดว่าแอปที่สร้างบัญชีได้ต้องลบบัญชีในแอปได้; เว็บ Food ไม่มี (มีใน Settings ของ Social) (Q4)
3. **Privacy policy / support URL / Privacy Nutrition Label (iOS) / Data safety (Play)** ในชื่อ ZOKY
4. **Permission usage strings** (ตำแหน่ง, รูปภาพ, แจ้งเตือน) เป็นภาษาไทยที่ชัดเจน
