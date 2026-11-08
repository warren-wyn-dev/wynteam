# Supabase Storage Cached Egress Review (ZOKY / WYNOS Food)

สถานะ: วิเคราะห์จากโค้ดอย่างเดียว (read-only) ไม่ได้ต่อ Supabase, Vercel หรือ Dashboard จริง และไม่ได้อ่าน secrets/env
ขอบเขตที่อ่าน: worktree production baseline `.../scratchpad/rc-wt/web/` และ `/home/user/wynteam/supabase/`
อาการที่ต้องอธิบาย: Cached Egress (CDN) ของ Supabase Storage ใช้ 2.27 GB ใน 24 วันของรอบนี้ (Free quota 5 GB, รอบก่อนเกิน)

หมายเหตุการอ่านผล: "อ่านจากโค้ดแล้ว" = เห็นในไฟล์โดยตรง, "สันนิษฐาน" = อนุมานจากโค้ด ต้องยืนยันด้วย Dashboard

## 1. จุดที่เสิร์ฟรูปจาก Supabase Storage

### อ่านจากโค้ดแล้ว

| Bucket | ชนิด | เส้นทางเสิร์ฟ | ใช้ที่ไหน |
|---|---|---|---|
| `food-public` | public (migrations_wynos_food_merchant_v1.sql:733) | `getPublicUrl` ผ่าน `foodPublicUrl` (web/lib/food-customer.ts:457, food-merchant.ts:263) แล้วใส่ `<img src>` ตรง | หน้าลูกค้า ZOKY: ปกร้านในรายการร้าน (food-guest-browse.tsx:598-606), หัวร้าน (:287-297), รูปเมนูในรายการ (:338-345, :493-500), รูปเมนูใน modal (:418-420); food-delivery-map-picker.tsx:2197-2198 (ปก/โลโก้ร้านใน map sheet); ฝั่ง merchant/food app: wynos-food-developer-app.tsx (:408, :468, :1111, :1434, :2172, :3295 QR ชำระเงิน), wynos-merchant-app.tsx (:1602, :1880, :2344) |
| `food-public` | public | Flutter merchant: bridge ส่ง `image_url` และ `image_thumbnail_url` (merchant-flutter-bridge.ts:505) | รายการเมนูใน merchant_flutter (merchant_home.dart:3038-3062), ปก/โลโก้ใน store_profile_panel.dart:303-325 |
| `food-public` | public | OG/Twitter image ของลิงก์แชร์ร้าน `/?store=<id>` และ `/s/<code>` (food-share.ts:84-98, food-share-preview.ts:86-97) ชี้ตรงไปที่ `/storage/v1/object/public/food-public/<cover_path หรือ logo_path>` | crawler ของ LINE/Facebook/X ที่ preview ลิงก์ |
| `food-private` | private, signed URL อายุ 900 วินาที (food-customer.ts:460, food-merchant.ts:266) | สลิปชำระเงิน, หลักฐานส่ง | merchant/developer view ตอนเปิดออเดอร์ (wynos-merchant-app.tsx:1955-1956, wynos-food-developer-app.tsx:3181, merchant-flutter-bridge.ts:839) เป็นรายออเดอร์ ปริมาณน้อย |
| `food-banners` | public (20261013190000_admin_food_banners_v1.sql:40, จำกัด 5 MB) | RPC `food_active_home_banners()` คืน `image_path` (จำกัด 8 แถว) | อ่านโค้ดของ production baseline (web/) ไม่พบ consumer ของ banner ในฝั่ง web ลูกค้า (grep ไม่พบ `food-banners`/`food_active_home_banners`) จึงยืนยันไม่ได้ว่าหน้าไหนแสดง (อาจเป็น Android/อื่น ซึ่งอยู่นอกขอบเขตที่อ่าน) |
| `place-photos` | private, signed 3600 วินาที (maps-place-photos.ts:41) | `<img loading="lazy">` | Maps place sheet (ไม่ใช่ Food หลัก) |
| `club-media`, `drop-images`, `avatars`, `chat-media` | club/chat เป็น signed 3600 วินาที; drop-images/avatars เป็น public | Social (WYNOS) ไม่ใช่ Food | feed, profile, chat, club — เป็นโปรเจกต์ Supabase เดียวกัน จึงรวมอยู่ใน quota เดียวกันถ้าใช้โปรเจกต์ร่วม |

ไม่พบ bucket ชื่อ "โปรไฟล์/แบนเนอร์/สลิป/หลักฐานส่ง" แบบไทย ชื่อจริงตามโค้ดคือ `avatars`, `food-banners`, `food-private` (slips/ และ proofs), `food-public`

### สิ่งที่ยืนยันไม่ได้จากโค้ด
- โปรเจกต์ Supabase เดียวหรือหลายโปรเจกต์ (Social + Food + Admin ใช้ร่วมกันหรือไม่) quota 5 GB ถูกนับต่อ organization/project ต้องดูใน Dashboard
- Android app และ zoky-admin (นอกขอบเขตที่อ่าน) อาจโหลดรูปจาก bucket เดียวกัน

## 2. การปรับขนาด/บีบอัดรูป

### อ่านจากโค้ดแล้ว
- `next.config.ts`: `images.remotePatterns` อนุญาตเฉพาะโปรเจกต์ Supabase ที่ตั้งไว้ แต่ในหน้า Food หลัก **ไม่ได้ใช้ `next/image` กับรูป Storage เลย** ทุกจุดข้างบนเป็น `<img>` ตรง (มี `eslint-disable no-img-element` และคอมเมนต์ food-delivery-map-picker.tsx:2240) จึงไม่มี resize/WebP/srcset
- ข้อยกเว้นเดียว: `merchantMenuThumbnailUrl` (web/lib/merchant-menu-image.ts) ส่งรูปเมนู public ผ่าน `/_next/image?w=128&q=75` เฉพาะ Flutter merchant list ซึ่งทำให้ขนาดเล็กลงมาก แต่ปริมาณที่ Supabase เห็นคือ Vercel ดึงต้นฉบับมาครั้งเดียวต่อรูป (ตาม Vercel image cache) ไม่ใช่ทุกคน
- `components/profile-route.tsx` และ `components/club-detail-golden.tsx` ใช้ `next/image` แต่ตั้ง `unoptimized` (ดึงจาก Supabase ตรง)
- ฝั่ง upload: `uploadFoodPublicImage` (food-merchant.ts:660-672) จำกัด **8 MB** และชนิด JPG/PNG/WebP (imageUploadType + bucket limit 8 MiB) ไม่มีการย่อ/บีบอัดฝั่ง client `withoutLocation` (image-location.ts:119) ตัดเฉพาะ GPS/EXIF ของ JPEG ไม่ย่อขนาด PNG/WebP ส่งต้นฉบับ
- ไม่มี thumbnail/หลายขนาดที่สร้างตอน upload ไม่พบการใช้ Supabase Image Transformation (`?width=`, `render/image`) ในโค้ด Food
- สรุป: รูปปกร้าน 1 รูปที่ถ่ายจากมือถือได้ถึงหลาย MB ถูกส่งเต็มขนาดให้ทุกการแสดงผล ในกรอบที่แสดงเพียงราว 56-96 CSS px (รายการร้าน/เมนู)

## 3. แคช

### อ่านจากโค้ดแล้ว
- `food-public` upload ใส่ `cacheControl: "31536000"` (1 ปี) และ path เป็น UUID ไม่ซ้ำ (`upsert:false`) ดังนั้นฝั่ง browser/CDN แคชได้ดี ปัจจัยนี้ **ไม่น่าเป็นสาเหตุ** ของการโหลดซ้ำเกินจำเป็น แต่ตัวเลข "Cached Egress" คือปริมาณที่ CDN ส่งออกรวมทั้ง cache hit ต่อผู้ใช้ใหม่/อุปกรณ์ใหม่/browser cache ว่าง จึงยังโตตามจำนวน unique visitor x ขนาดรูป
- `food-private` ใช้ `cacheControl: "300"` และ signed URL อายุ 900 วินาที (สลิป/หลักฐานส่ง) เปิดดูซ้ำ = URL ใหม่ = โหลดใหม่ แต่ปริมาณน้อย (เฉพาะ merchant/admin เปิดออเดอร์)
- Club/chat: signed URL 3600 วินาที สร้างใหม่ทุกครั้งที่เปิด (phase3-data.ts:409, 454, 934; deep-link-routes.tsx:111) ทำให้ URL ต่างกันทุกครั้ง browser cache ใช้ไม่ได้ (Social ไม่ใช่ Food)
- `drafts.ts:58` ใช้ `cacheControl: "60"` สำหรับ draft image ใน `drop-images` (อายุสั้น) และ `clubs-routes.tsx:158`/`phase3-data.ts:713` (avatars) upload แบบ `upsert:true` โดยไม่ตั้ง cacheControl (ค่า default ของ Supabase = 3600 วินาที) และ path เดิมถูกเขียนทับ
- `public/sw.js` แคชเฉพาะ `/_next/static/` และ `/icons/` ของ origin ตัวเอง **ไม่แตะรูป Supabase** (ไม่มี runtime cache ของ Storage) browser HTTP cache จึงเป็นกลไกเดียว
- Flutter merchant: `_menuImage` ใช้ thumbnail + `cacheWidth` (ดี) แต่ `store_profile_panel.dart:315` และจุดอื่น (order_dialogs.dart, fulfillment_panels.dart, store_settings_panels.dart) ใช้ `Image.network` ไม่กำหนด `cacheWidth` และใช้ URL ต้นฉบับ
- ไม่พบการ prefetch รูป Storage หรือ polling รีเฟรชรูป อย่างไรก็ดีหน้า guest-browse โหลดทุกร้านพร้อมเมนู (entry.menu.length) แล้ว render รูปทั้งหมดด้วย `loading="lazy"` (ลดแต่ไม่ตัด: ผู้ใช้เลื่อนผ่านก็โหลด)
- Workflow/test: `merchant-browser-qa.yml` ใช้ URL fixture `merchant-fixture.example.test` (ไม่ยิงของจริง); `zoky-staging-e2e.yml` ชี้ staging ผ่าน variables ส่วน `web-phase1-public-smoke.yml` ไม่ได้อ่านละเอียดว่าโหลดหน้า Food จริงหรือไม่ จึงยังสรุปไม่ได้ว่า bot/test ยิงรูปจริง (สันนิษฐานว่าน้อย)

## 4. ปัจจัยที่ทำให้พุ่ง (เรียงตามความน่าจะเป็น)

| # | ปัจจัย | หลักฐาน | สถานะ |
|---|---|---|---|
| A | รูปปกร้าน/รูปเมนูส่งเต็มขนาดต้นฉบับ (สูงสุด 8 MB) ให้ `<img>` ที่แสดงเล็ก ไม่มี resize/thumbnail/ย่อก่อน upload | food-guest-browse.tsx, food-merchant.ts:660, bucket 8 MiB | อ่านจากโค้ดแล้ว; ขนาดจริงของรูปที่อัปโหลด = สันนิษฐาน |
| B | หน้ารายการร้านโหลดรูปปกทุกร้านในรายการ (และรูปเมนูเมื่อค้นหา/เปิดร้าน) ทุก session/อุปกรณ์ใหม่ | food-guest-browse.tsx:598, :338, :493 | อ่านจากโค้ดแล้ว; จำนวนผู้เข้าชม = สันนิษฐาน |
| C | Link preview: og:image/twitter:image ชี้ cover ต้นฉบับ (ไม่ใช่ขนาด 1200x630 ที่ย่อไว้) crawler ของ LINE/FB/X และ bot preview ดึงเต็มขนาดทุกครั้งที่มีการแชร์ (และ LINE ตัวอย่างลิงก์ถูกดึงต่อผู้รับ/ห้องแชท) | food-share.ts:90-98, food-share-preview.ts:86-97 | อ่านจากโค้ดแล้ว; สัดส่วนจริง = สันนิษฐาน (ตรวจได้จาก User-Agent ใน Dashboard/Logs) |
| D | Merchant/Flutter (web merchant) แสดงรูปเมนู/ปก/โลโก้ใหญ่โดยไม่ย่อ (มี thumbnail เฉพาะ list เมนู) polling ออเดอร์ทำให้เปิดหน้าซ้ำ | merchant-flutter-bridge.ts, store_profile_panel.dart:315 | อ่านจากโค้ดแล้ว; ปริมาณ = สันนิษฐาน |
| E | Social buckets ในโปรเจกต์เดียวกัน (feed/club/chat/avatars ไม่มี resize, `unoptimized`, signed URL 3600 วินาที สร้างใหม่ทุกครั้ง; รูปโพสต์ได้ถึง 20 MB) | beta1_storage_upload_limits.sql, profile-route.tsx, phase3-data.ts | อ่านจากโค้ดแล้ว; ถ้าโปรเจกต์ใช้ร่วมกันอาจเป็นตัวหลักกว่า Food |
| F | วิดีโอ: มี bucket `pop-videos` (อ้างถึงใน beta1_storage_upload_limits.sql) ไม่ได้ตรวจการเสิร์ฟ | - | สันนิษฐาน ยังไม่ได้ตรวจ |
| G | crawler ทั่วไป: `llms.txt` เป็นไฟล์สั้น (ไม่ใช่สาเหตุ), `/og-image.png` ถูก rewrite ไปไอคอน 512 ในเว็บเอง (ไม่แตะ Supabase) | next.config.ts, public/llms.txt | อ่านจากโค้ดแล้ว: ไม่น่าใช่สาเหตุ |

ข้อสังเกต: เมื่อเทียบ 2.27 GB / 24 วัน ~ 95 MB/วัน เทียบเท่าการโหลดรูปปกขนาด ~2 MB ราว 45-50 ครั้งต่อวัน (CDN miss/hit ต่อ browser ใหม่) ซึ่งสอดคล้องกับ A+B+C จึงน่าจะเกิดจากขนาดรูปต้นฉบับมากกว่าจำนวนครั้งการโหลดซ้ำ (สันนิษฐาน)

## 5. รายการแก้ที่เล็กที่สุด เรียงตามผลต่อ egress

| ลำดับ | การแก้ | ผลคาด | ความเสี่ยง | Founder approval |
|---|---|---|---|---|
| 1 | ย่อ/บีบอัดรูปฝั่ง client ก่อน upload ใน `uploadFoodPublicImage` (เช่น cover/เมนูด้านยาวสูงสุด ~1280-1600 px, WebP/JPEG ~0.8) ใช้ canvas ที่มีอยู่ หรือ re-encode เฉพาะไฟล์ใหม่ | ลดไฟล์ใหม่ลง 5-20 เท่า | ปานกลาง: ต้อง test บน mobile, ต้องคง EXIF strip, อย่าลดคุณภาพ QR ชำระเงิน (ห้ามย่อ `payment_qr_path`) | ไม่ต้อง (เป็น code change ใน scope ของ task ที่มอบหมาย) แต่ต้องผ่าน QA ตาม gate |
| 2 | เปลี่ยน og:image ของลิงก์แชร์ให้ใช้ขนาดเล็ก (เช่น ผ่าน `/_next/image` หรือ route ที่ย่อและ cache ที่ Vercel) แทน URL ต้นฉบับ | ลด egress จาก crawler ทั้งหมด | ต่ำ-ปานกลาง: ต้องเพิ่ม route/ตรวจ remotePatterns ที่เป็น security-sensitive (`/_next/image` public) | ไม่ต้องถ้าใช้ remotePatterns เดิม; ถ้าแก้ remotePatterns/เพิ่ม route สาธารณะใหม่ ควรผ่าน CTO/QA และแจ้ง Founder เพราะเป็น security-adjacent |
| 3 | ใช้ `/_next/image` (หรือ Supabase Image Transformation) สำหรับรูปปก/เมนูใน guest-browse โดยใช้รูปแบบเดียวกับ `merchantMenuThumbnailUrl` (w=128-640) | ลดมากสำหรับ list view ทันที รวมรูปเก่าที่อัปโหลดไว้แล้ว | ปานกลาง: ย้าย egress ไป Vercel Image Optimization (มี quota/ค่าใช้จ่ายแยก ต้องเช็ก); Supabase Image Transformation เป็นฟีเจอร์ plan ที่อาจมีค่าใช้จ่าย | ต้อง Founder approval ถ้ากระทบค่าใช้จ่ายโครงสร้างพื้นฐานหรือ plan |
| 4 | Backfill: สร้างสำเนาขนาดเล็กของรูปเก่า (thumbnail) | แก้ที่รูปเดิม | สูง: แตะข้อมูล production และ path | **ต้อง Founder approval** (data migration/ย้ายรูป) |
| 5 | Flutter: เพิ่ม `cacheWidth`/ใช้ thumbnail ใน `store_profile_panel`, `order_dialogs` ฯลฯ | ลดเล็กน้อย | ต่ำ | ไม่ต้อง (แต่ต้อง build/release Flutter ตาม gate) |
| 6 | ลดการโหลดรูปทั้งรายการ (จำกัดจำนวนร้าน/เมนูที่ render, `content-visibility`, ไม่โหลดรูปเมนูในรายการร้านจนกว่าเปิดร้าน) | ลดปานกลาง | ปานกลาง: เปลี่ยน UX | ขึ้นกับ PM (เปลี่ยน scope ต้องไม่คิดเอง) |
| 7 | ปรับ Social: ใช้ `next/image` optimized หรือ thumbnail, ปรับ signed URL ให้คงที่/แคชได้ | ลดถ้า Social เป็นตัวหลัก | ปานกลาง: signed URL/auth | แจ้ง Founder หากแตะ auth/policy |
| 8 | เปลี่ยนชนิด bucket (public <-> private), policy, ย้าย bucket/ย้ายผู้ให้บริการ (เช่น เพิ่ม CDN ภายนอก) | ขึ้นกับทางเลือก | สูง | **ต้อง Founder approval** (security policy/infrastructure cost/architecture) |
| 9 | อัปเกรด plan Supabase (เพิ่ม quota) | แก้ปลายทางไม่ได้แก้ต้นเหตุ | ค่าใช้จ่าย | **ต้อง Founder approval** (infrastructure spending) |

ข้อควรระวัง: ห้ามลด security policy, ห้ามเปลี่ยน public bucket เป็น private หรือกลับกันโดยไม่มี approval; การแก้ remotePatterns ต้องคงการจำกัดเฉพาะโปรเจกต์เดียวเพื่อกัน open image proxy (ตามคอมเมนต์ใน next.config.ts)

## 6. ข้อมูลที่ต้องดูใน Supabase Dashboard เพื่อยืนยัน (ไม่ได้ตรวจในรอบนี้)

1. Organization -> Usage -> Cached Egress / Egress แยกตามโปรเจกต์ (ยืนยันว่าโปรเจกต์ไหนกิน และมีกี่โปรเจกต์ใน org เดียวกัน) และกราฟรายวันเพื่อหาวันที่พุ่ง
2. Reports -> Storage (และ API Gateway/Edge) ในโปรเจกต์: ดูจำนวน request และ egress ต่อ bucket/path (food-public vs avatars vs club-media vs drop-images vs food-banners)
3. Logs -> Edge/API/Storage logs: Top path ตามจำนวนและขนาด response, Top User-Agent (ตรวจ LINE/facebookexternalhit/Twitterbot/Googlebot/bot อื่น), referrer, สัดส่วน cache HIT/MISS
4. Storage -> bucket `food-public`: ขนาดไฟล์ใหญ่สุด 20 อันดับ (ตรวจว่ารูปปก/เมนูเกิน 1 MB กี่ไฟล์), จำนวนไฟล์รวม
5. ดูว่ามีรูปใหญ่ผิดปกติที่ถูกเรียกซ้ำ (ไฟล์เดียวมี request สูง) เช่น cover ของร้านที่ถูกแชร์บ่อย
6. Vercel: Analytics/Logs ของ `/food` และ `/s/<code>` เพื่อดู traffic จริงและ User-Agent, และ Image Optimization usage (ถ้าจะย้ายไปใช้ `/_next/image`)

## 7. สิ่งที่ยังไม่ได้ตรวจ / ความเสี่ยงคงเหลือ
- ไม่ได้อ่าน Android app, zoky-admin และ main-repo web ที่นอกจาก worktree baseline (ยกเว้นพบ path ผ่าน grep) จึงไม่ทราบว่าหน้า banner ลูกค้าอยู่ที่ไหน
- ไม่ได้ยืนยันตัวเลขจริงใดๆ ทั้งหมดเป็นการอนุมานจากโค้ด ไม่มีการอ้างตัวเลขประหยัดโดยไม่มีหลักฐาน
- ไม่ได้รัน test, ไม่ได้แก้ source, ไม่ได้ commit
