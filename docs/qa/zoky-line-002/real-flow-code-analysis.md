# ZOKY-LINE-002 — วิเคราะห์เส้นทางลูกค้าจริงจากโค้ด (production baseline)

ผู้จัดทำ: Product/QA analyst (อ่านอย่างเดียว) | วันที่: 2026-11-08
ขอบเขต: อ่านโค้ดอย่างเดียว ไม่แก้ source ไม่ commit ไม่อ่าน secrets/env ไม่ต่อ DB หรือ LINE จริง

> หมายเหตุ baseline: worktree ที่อ่านคือ `/tmp/claude-0/-home-user-wynteam/a52997b2-3edd-51fc-a319-07777790a998/scratchpad/prod-wt` ซึ่ง `git rev-parse HEAD` รายงาน `fe619a55b9077fa99340c35aaf35a419dc96ff32` **ไม่ใช่** `a70cbb0` ตามที่สั่ง (ไม่ได้แก้หรือ checkout ใด ๆ) โค้ดใน tree นี้มี `LineLoginGuidance`, `/s/<code>` allowlist, store QR→LIFF และ auto-link ครบ จึงใช้วิเคราะห์ได้ แต่ผู้รับเอกสารควรยืนยัน commit ที่ deploy จริงอีกครั้ง
> ใน tree นี้ **ไม่มี** source ของ Edge Function `line-link` / `line-webhook` (มีเฉพาะใน `/home/user/wynteam`) จึงตรวจฝั่ง server ของการ link ไม่ได้

สัญลักษณ์ความมั่นใจที่ใช้ทั้งเอกสาร
- **[โค้ด]** = อ่านจากโค้ดแล้ว ระบุไฟล์/บรรทัดได้
- **[สมมติฐาน]** = อนุมานจากโค้ดร่วมกับความรู้ภายนอกเรื่องพฤติกรรมของ LINE/Google/iOS ต้องพิสูจน์ด้วยเครื่องจริง

---

## 1. แผนผังเส้นทางลูกค้า และหน้าที่ไปจบ

ค่าคงที่สำคัญ [โค้ด]
- LIFF ID ลูกค้า `2012311758-OEhTuU5V`, endpoint ที่ลงทะเบียนไว้ `https://food.wynos.online/line` (APPROVALS 2026-11-05 บรรทัด 791) ส่วนโดเมนหลักของลูกค้าคือ `zoky.wynos.online` (`web/lib/food-origin.ts`) สองโดเมนนี้ใช้ localStorage/sessionStorage/Supabase session แยกกัน
- OA ลูกค้า `@732igmun` (`CUSTOMER_LINE_ADD_FRIEND_URL`, `web/lib/line-liff.ts:54`)
- `safeLineDestination` (`line-liff.ts:43-50`) อนุญาตปลายทางเพียง `/food`, `/food?order=WF…|ZF-…`, `/s/<6 ตัว>`, `/food?store=<uuid>` นอกนั้น fallback `/food`

### เส้นทาง A — สแกน QR ร้าน (กล้องมือถือ)

`foodStoreQrTarget` (`web/lib/zoky-store-qr.ts:24-27`): ถ้า build มี `NEXT_PUBLIC_LIFF_ID_FOOD` → QR = `https://liff.line.me/<LIFF>?to=%2Fs%2F<code>` ถ้าไม่มี → QR = `https://zoky.wynos.online/s/<code>` (เว็บล้วน) [โค้ด]

```
กล้องมือถือสแกน
  -> liff.line.me/<LIFF>?to=/s/<code>
  -> เปิดแอป LINE (ถ้ามี) หรือเบราว์เซอร์ถ้าไม่มี LINE            [สมมติฐาน: พฤติกรรม universal link]
  -> LINE โหลด endpoint  https://food.wynos.online/line?to=/s/<code>   (หรือ ?liff.state=…)
        ** ผ่าน rule redirect openExternalBrowser ใน next.config.ts เพราะ UA มี " Line/" (ดูข้อ 2.2) **
  -> line-entry.tsx: liff.init
        - มี liff.state  -> return รอ SDK redirect แล้ววนเข้า /line?to=… อีกรอบ  [โค้ด :148]
        - audience=food && isInClient && isLoggedIn:
            requestStoreLineFriendship (ปลายทางเป็นร้านเท่านั้น)
              friend       -> ไปต่อ
              prompted/cancelled -> ไปต่อ
              unavailable  -> ค้างที่จอ "เพิ่มเพื่อน LINE ของ ZOKY" + liff.openWindow(โปรไฟล์ OA, external:false)
                              ปุ่ม "ไปหน้าร้าน" เป็นลิงก์ธรรมดา (ไม่ auto-continue)       [โค้ด :170-179, :233-240]
            แล้วพยายามผูกแจ้งเตือน (race 4 วินาที):
              ยังไม่ login  -> rememberLineAutoLink(dest) เก็บ localStorage 30 นาที
              login แล้ว    -> status -> link ด้วย ID token
  -> window.location.replace("/s/<code>")
  -> route.ts 307 -> "/?store=<uuid>"  (host zoky/food) -> proxy rewrite "/"->"/food"
  -> /food: ไม่มี session => FoodGuestBrowse (ดูร้าน/ใส่ตะกร้าได้)  [โค้ด wynos-food-developer-app.tsx:4324]
  -> กด "เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ" => router.push("/food/login")  [food-guest-browse.tsx:526, :262]
  -> /food/login (+ กล่อง LineLoginGuidance ถ้า UA มี Line/)
```

จบที่: `/food/login` บนโดเมนเดียวกับที่ LIFF endpoint เปิด (น่าจะ `food.wynos.online` ถ้า `ZOKY_LEGACY_FOOD_REDIRECT` ยังปิด) หรือ `zoky.wynos.online` ถ้าเปิด phase 2 ซึ่งยืนยันไม่ได้จากโค้ด/เอกสารที่อ่าน (ค้น APPROVALS ไม่พบสถานะ phase 2)

กรณี build ไม่มี LIFF ID: เป็นลิงก์เว็บล้วน ไม่มี `/line` ไม่มี friendship prompt ไม่มี auto-link [โค้ด]

### เส้นทาง B — กดแอด LINE OA เอง (ค้นหา/ลิงก์ `line.me/R/ti/p/@732igmun`)

- ในโค้ด **ไม่มี** ขั้นตอนใดที่พาผู้ที่เพิ่งเพิ่มเพื่อนไปที่ ZOKY: `line-webhook` ใน `/home/user/wynteam/supabase/functions/line-webhook/index.ts` ใช้ follow/unfollow เพื่ออัปเดต `friend_status` เท่านั้น ไม่มีข้อความต้อนรับ [โค้ด: อ่านเฉพาะส่วนหัวไฟล์/ค้นคำ follow, reply]
- จบที่ห้องแชท OA เท่านั้น สิ่งที่ลูกค้าเห็นต่อจากนั้นขึ้นกับ Greeting message / Rich menu / Auto-reply ที่ตั้งใน LINE Official Account Manager ซึ่งไม่อยู่ใน repo (ค้นคำ richmenu ไม่พบโค้ด) -> **ยืนยันไม่ได้จากโค้ด**
- ดังนั้นสถานการณ์ B ใน usability script ("เพื่อนบอกให้แอด LINE ของ ZOKY") ขึ้นกับค่า OA Manager ล้วน ๆ ต้องให้ Founder ส่งภาพหน้าจอ Rich menu/Greeting ปัจจุบัน

### เส้นทาง C — เปิดจาก Rich menu หรือลิงก์ที่แปะในแชท

| ชนิดลิงก์ | ปลายทางจริง (จากโค้ด) | หมายเหตุ |
|---|---|---|
| ลิงก์ `https://zoky.wynos.online/...` ธรรมดา แตะในแชท/Rich menu (URI action) | LINE เปิดด้วย in-app browser (ไม่ใช่ LIFF) UA มี `Line/` -> ถูก 307 เติม `openExternalBrowser=1` -> LINE (ตามที่เอกสารโค้ดอ้าง) ส่งต่อไป Safari/Chrome ของเครื่อง | ออกจาก LINE, ไม่มี LIFF, ไม่มี friendship prompt, ไม่มี auto-link แต่ Google login ใช้ได้ถ้าลูกค้ามีบัญชี; ตะกร้าเริ่มใหม่ [โค้ด next.config.ts:117-138; พฤติกรรม LINE = สมมติฐาน] |
| `https://liff.line.me/<LIFF>` (ไม่มี `to`) | `/line` -> destination = `/food` -> ไม่มี friendship prompt (ไม่ใช่ path ร้าน `:63`) แต่ยังพยายาม auto-link -> `replace("/food")` -> หน้า guest ไม่ระบุร้าน | ลูกค้าต้องเลือกร้านเอง [โค้ด] |
| ปุ่มในข้อความแจ้งเตือน (ZOKY-LINE-001) | `liff.line.me/<LIFF>?to=/food?order=WF…` -> `/food?order=…` | ต้อง login เพื่อเห็นออเดอร์ |
| ลิงก์ที่ร้านแชร์ `zoky.wynos.online/s/<code>` ในแชทกลุ่ม | เหมือนแถวแรก (ถูกส่งออกเบราว์เซอร์นอก LINE) | |

### เส้นทาง D — LIFF (รวมที่ผ่านมาในเส้นทาง A, C) และ `/line?mode=link`

- `/line?mode=link&oa=food` เป็นหน้าจัดการ "รับแจ้งเตือนทาง LINE" จากหน้าตั้งค่า เปิดในเบราว์เซอร์เดียวกับที่ login อยู่ [โค้ด line-entry.tsx:185-211]
- ถ้ายังไม่ login จะขึ้น "เข้าสู่ระบบ ZOKY ในเบราว์เซอร์นี้ก่อน" + ข้อความ "ในแอป LINE เข้าสู่ระบบด้วย Google ไม่ได้…" + ปุ่ม "เปิดในเบราว์เซอร์" (`liff.openWindow({url: window.location.href, external:true})`) [โค้ด :242-260] เงื่อนไขแสดงคือ `liff.isInClient()` ไม่ใช่ตรวจ UA

---

## 2. จุดที่น่าจะติดจากโค้ด

### 2.1 Google login ถูกปฏิเสธใน LIFF in-app WebView — ผู้ใช้เจออะไร

ลำดับ [โค้ด]
1. `/food/login` แสดงกล่อง "เปิดใน LINE อยู่" (ถ้าเข้าเงื่อนไขข้อ 3) เหนือปุ่ม Google ปุ่ม Google ยังกดได้ (`food-auth.tsx:335-339`)
2. กดแล้ว `google()` -> `startGoogleOAuth` (`google-pwa-oauth.ts:73-86`) เนื่องจากไม่ใช่ iOS Home Screen PWA จึงเรียก `client.auth.signInWithOAuth` แบบ **redirect เต็มหน้า** ไป Supabase -> accounts.google.com
3. `signInWithOAuth` ไม่ throw (เป็นแค่การสั่ง redirect) ดังนั้น `result.started = true` และ `withLineGoogleHint(...)` (`food-auth.tsx:269, 277`) **ไม่ถูกเรียกในกรณีนี้** — ข้อความแนะนำท้ายประโยคแสดงเฉพาะกรณี startGoogleOAuth คืน error/throw (เช่น popup iOS ถูกบล็อก) ไม่ใช่กรณี Google ปฏิเสธ
4. สิ่งที่ผู้ใช้เห็น **[สมมติฐาน]**: หน้าของ Google เอง ("Access blocked … Error 403: disallowed_useragent") ซึ่งไม่ใช่หน้าของ ZOKY ไม่มีปุ่มกลับ ZOKY ผู้ใช้ต้องใช้ปุ่มย้อนกลับ/ปิดของ LINE เอกสาร ZOKY-LINE-002 และคอมเมนต์ใน `in-app-browser.ts` ระบุว่า Google ปฏิเสธ แต่ผม **ไม่ได้พิสูจน์ด้วยเครื่องจริง** และ Google ตัดสินจาก UA/พฤติกรรม webview ซึ่งต่างกันระหว่าง iOS/Android
5. เมื่อกลับมา (back) **[สมมติฐาน]**: ถ้าหน้าถูกกู้จาก bfcache สถานะ `googleLoading=true` อาจค้าง ปุ่มโชว์ "กำลังเชื่อมต่อ Google…" และ disabled; ถ้าโหลดใหม่จะกลับสภาพปกติ โค้ดไม่มี `pageshow` handler ที่รีเซ็ต
6. ไม่มีทางเลือกให้ลูกค้าที่เห็นหน้า Google error เพราะไม่มีการตรวจจับ error จากฝั่ง ZOKY
7. ทางที่เหลือในเครื่อง: (ก) อีเมล+รหัสผ่านในหน้าเดิม (ข) "เปิดในเบราว์เซอร์" (ค) สมัครด้วยอีเมล

ปัญหาต่อเนื่องของทางเลือกเหล่านี้ [โค้ด]
- **(ข) เปิดในเบราว์เซอร์** เปิดเฉพาะ `foodLoginExternalUrl` = `<origin>/food/login` โดยตั้งใจไม่มี query/ร้าน/ตะกร้า (`line-liff.ts:126-129`; ZOKY-LINE-002 F) และ `rememberSharedFoodStore` ใช้ **sessionStorage** (`food-share.ts`) ซึ่งไม่ข้ามเบราว์เซอร์ จึงหลุดทั้ง "ตะกร้า" **และ "ร้าน"** (กล่องเตือนพูดถึงแต่ตะกร้า `line-login-guidance.tsx:91`) หลัง login ใน Safari ระบบ `replace("/food")` (`food-auth.tsx:299`) ลูกค้าไปที่ร้านล่าสุดต่อบัญชี หรือรายการร้าน ต้องหาร้านเองและเลือกเมนูใหม่
- ใน Safari login สำเร็จแล้ว **LINE ยังเป็น guest** (storage แยก) ครั้งถัดไปที่สแกน QR ใน LINE จะเจอปัญหาเดิมวนซ้ำ
- **(ข) ยังมีปัญหาโดเมน**: ปุ่มส่ง `window.location.origin` ของหน้าปัจจุบัน ถ้าเป็น `food.wynos.online` session ใน Safari จะอยู่บน origin นั้น ไม่ใช่ `zoky.wynos.online` ที่ลูกค้าเว็บทั่วไปใช้ (session แยกต่อ origin แม้เป็นบัญชี Supabase เดียวกัน)
- **(ค) สมัครด้วยอีเมล**: `signUpWithEmail` ถ้า Supabase เปิดยืนยันอีเมล จะได้ `awaitingConfirmation` ("ตรวจสอบอีเมลของคุณ") และลิงก์ยืนยันเปิดจากแอปเมล = นอก LINE (`food-auth.tsx:411-413, 435-446`) ทั้ง session และตะกร้าไม่ตามมา ว่าตั้งค่ายืนยันอีเมลไว้หรือไม่ — **ยืนยันไม่ได้จากโค้ด**
- (ก) อีเมล+รหัสผ่านเป็นทางเดียวที่ **ควร** อยู่ใน LINE ได้ครบ แต่ลูกค้าที่เคยสมัครด้วย Google มักไม่มีรหัสผ่าน ต้องกด "ลืมรหัสผ่าน" (`/forgot-password`) ซึ่งส่งลิงก์ทางเมลออกนอก LINE อีกเช่นกัน [โค้ด :344]

### 2.2 การ redirect `openExternalBrowser` เกิดเมื่อไหร่ / ไม่เกิดเมื่อไหร่

กฎใน `web/next.config.ts:125-138` [โค้ด]
- **เกิด**: request หน้า (path ไม่มีจุด และไม่ขึ้นต้น `api`, `_next/`, `auth`) ที่ header `user-agent` ตรงกับ regex `.* Line/.*` (ต้องมี **ช่องว่าง** นำหน้า `Line/`) **และ** ไม่มี query `openExternalBrowser` **และ** ไม่มี query `code` -> 307 ไป `/:path?openExternalBrowser=1` (query เดิมถูกเก็บตามพฤติกรรมของ Next, ไม่ผูกกับ host)
- **ไม่เกิด**: UA ไม่มี ` Line/`; มี `openExternalBrowser` อยู่แล้ว; มี `?code=` (OAuth return); path เป็น `api/…`, `_next/…`, ไฟล์ที่มีจุด (เช่น `.js`, `.png`), หรือ path ขึ้นต้น `auth…`
- ข้อสังเกตจากโค้ด:
  - `/food/auth/callback` **ไม่ได้ถูกยกเว้นด้วย path** (rule ยกเว้นเฉพาะ path ที่ขึ้นต้น `auth` ระดับบนสุด) ถูกยกเว้นเฉพาะตอนมี `?code=` เท่านั้น กรณี Google ส่ง `?error=…` กลับมาโดยไม่มี code อาจถูกเด้งอีกรอบ (กรณีขอบ ผลไม่ชัด)
  - ไม่มีการแยก LIFF ออกจากลิงก์แชทธรรมดา: ทั้งคู่ UA มี `Line/` เหมือนกัน -> **ทุก** navigation ในเว็บ ZOKY ภายใน LINE ที่ไม่มีพารามิเตอร์นี้ ถูกเติมพารามิเตอร์ รวมถึง `/line`, `/s/<code>`, `/?store=…`, `/food`, `/food/login`
  - route handler `/s/[code]` ทำ redirect ใหม่ไป `/?store=<id>` โดยสร้าง URL ใหม่ จึง **ไม่เก็บ** `openExternalBrowser` ไว้ ทำให้ rule ยิงอีกรอบที่ปลายทางใน UA เดียวกัน
- **ที่ยังไม่รู้ (สำคัญที่สุดของเอกสารนี้) [สมมติฐาน]**: LINE ใช้พารามิเตอร์นี้ออกเบราว์เซอร์เฉพาะกับลิงก์ที่ผู้ใช้แตะ หรือรวมถึง HTTP redirect ภายใน WebView/LIFF ด้วย ถ้าโดนด้วย ผลจะมี 3 จุดที่ลูกค้าถูกดีดออกจาก LINE โดยไม่ตั้งใจ:
  1. โหลด endpoint `/line` ตอนเข้า LIFF (ถ้าเกิดตรงนี้ LIFF จะไม่ทำงานเลย ซึ่งขัดกับที่ Founder เคยรายงานว่าสแกนแล้วเห็นการเปิด จึงน่าจะ **ไม่เกิดตรงนี้** แต่ยืนยันไม่ได้)
  2. `window.location.replace("/s/<code>")` หลัง `/line` เสร็จ (`line-entry.tsx:181`) — ผล: ร้านเปิดใน Safari ในสถานะ guest ไม่มี LIFF ไม่มี friendship/auto-link
  3. `window.location.replace("/food")` หลัง login ด้วยอีเมลสำเร็จ (`food-auth.tsx:299`) — ผล: ผู้ใช้ login ใน LINE สำเร็จ แต่ถูกส่งออก Safari ซึ่งไม่มี session
  - หลักฐานเชิงอ้อมว่าผู้ใช้ **อยู่ใน LINE ได้**: ไฟล์ guidance/ข้อความ `need_signin` ถูกเขียนเพราะมีผู้ใช้เจอหน้า login ใน LINE จริง แต่เป็นเพียงข้อสรุปอ้อม ต้องดูคลิป
- ความต่างระหว่างสองที่ตรวจ UA: ฝั่ง server ใช้ `.* Line/.*` (ต้องมีช่องว่างนำหน้า), ฝั่ง client `isLineInAppBrowser` ใช้ `/\bLine\/\d/i` (ไม่ต้องมีช่องว่าง ต้องตามด้วยตัวเลข), `detectInAppBrowser` ใช้ `/ Line\//` ทั้งสามไม่เหมือนกัน แต่กับ UA จริงของ LINE น่าจะให้ผลตรงกัน [สมมติฐาน]
- การนำทางฝั่ง client (`router.push("/food/login")` ใน `food-guest-browse.tsx:262`) ส่ง request RSC ผ่านกฎเดียวกัน (rule ไม่ยกเว้น RSC) ผลต่อ router ของ Next [สมมติฐาน: อาจกลายเป็น hard navigation ไปที่ URL ที่มีพารามิเตอร์]

### 2.3 ตะกร้า guest หายหรือไม่เมื่อข้ามเบราว์เซอร์

[โค้ด `food-guest-browse.tsx:14, 44-80`, `wynos-food-developer-app.tsx:3604-3618, 3771-3775`]
- ตะกร้า guest บันทึกที่ `sessionStorage` เป็นหลัก (`localStorage` ใช้เมื่อ sessionStorage throw เท่านั้น) key `wynos-food-guest-basket-v1`; เก็บ 1 ร้าน (`storeId`) สูงสุด 50 บรรทัด
- **ไม่หาย** ถ้า login ในแท็บ/WebView เดียวกัน (อีเมล): `signInForOrder` บันทึกตะกร้าและ `rememberSharedFoodStore` แล้ว login -> `/food` -> `FoodCustomerInner` อ่าน guest basket และนำเข้าเฉพาะเมื่อ `guestBasket.storeId === opening.storeId`
- **หาย** เมื่อ: (1) กด "เปิดในเบราว์เซอร์" / ไปแอปเมลแล้วเปิดลิงก์ยืนยัน (storage คนละที่ และ URL ที่ส่งไม่มีร้าน), (2) LINE ปิด/ล้าง WebView แล้วเปิดใหม่ (sessionStorage หายตามอายุแท็บ — ตัว fallback localStorage ไม่ถูกใช้ตามปกติ) [สมมติฐานเรื่องอายุ WebView ของ LINE], (3) โดเมนต่างกัน (food.wynos.online vs zoky.wynos.online) เพราะ storage แยก origin
- ถ้านำเข้าได้ ตะกร้า guest **ทับ** ตะกร้าเดิมของบัญชี (`:3609`) ผู้ใช้เก่าที่มีตะกร้าค้างจะเสียของเดิมโดยไม่ถูกถาม [โค้ด]
- ไม่มีตะกร้าฝั่ง server (D-6 ของ ZOKY-LINE-002 ยังไม่ทำ)

### 2.4 Auto-link แจ้งเตือน LINE ทำงานตอนไหน

[โค้ด `line-entry.tsx:143-183`, `line-liff.ts:114-149`, `wynos-food-developer-app.tsx:3623-3629`]
- ทำงานเฉพาะเมื่อผ่าน `/line` (ไม่ใช่ `mode=link`) ใน LINE client (`liff.isInClient()`) + LIFF login แล้ว + audience food
- ถ้า **มี session** อยู่แล้ว: เรียก `line-link` status แล้ว link ด้วย ID token ถ้ายังไม่ผูก ภายใน race 4 วินาที (ถ้าช้ากว่าก็ไปต่อโดยไม่รอ)
- ถ้า **ไม่มี session** (กรณี guest ส่วนใหญ่): เขียน `localStorage` key `zoky.line-autolink.v1` (ปลายทางที่ผ่าน allowlist, อายุ 30 นาที)
- ตอนเสร็จ login ใน LINE browser แล้วเข้า `/food` (`FoodCustomerInner` mount): effect ตรวจ UA `Line/` -> `takeLineAutoLink()` (อ่านแล้วลบ) -> `location.replace("/line?to=…")` เพื่อจบการผูก
- **ไม่ทำงาน**: (1) login ในเบราว์เซอร์นอก LINE (UA ไม่มี `Line/`, storage คนละที่) — ลูกค้ากลุ่มที่ใช้ Google ผ่านทาง "เปิดในเบราว์เซอร์" จึงไม่ได้ผูกอัตโนมัติ (2) LIFF ไม่ได้ตั้งค่า (3) เกิน 30 นาที (4) ผู้ใช้ผ่าน `/line` ในสถานะที่ `isLoggedIn()` เป็น false
- ผลข้างเคียงที่อ่านพบ [โค้ด]: การกลับไป `/line` หลัง login ทำให้ `requestStoreLineFriendship` ถูกเรียก **อีกรอบ** ถ้า destination เป็นร้านและลูกค้ายังไม่เป็นเพื่อน/เคยกดยกเลิก จะเจอ prompt/หน้า "เพิ่มเพื่อน" ซ้ำ และมี full-page reload เพิ่มอีก 1-2 ครั้งหลัง login; ตะกร้าน่าจะยังอยู่เพราะบันทึกใน `wynos-food-cart-v1:<userId>` แล้ว (effect ที่ :3767) แต่ **ไม่ได้พิสูจน์ลำดับ effect กับ navigation** [สมมติฐาน]
- ข้อจำกัดที่เห็นจากโค้ด: ถ้า LIFF ไม่ได้ link bot (`hasLinkedBot:false` ตาม APPROVALS 2026-11-05) `liff.getFriendship()` น่าจะ throw -> ผลลัพธ์ `unavailable` สำหรับ **ทุกคน รวมคนที่เป็นเพื่อนอยู่แล้ว** ทำให้ทุกการสแกน QR เจอจอ "เพิ่มเพื่อน LINE ของ ZOKY" + เปิดหน้าโปรไฟล์ OA และไม่ไปร้านอัตโนมัติ [สมมติฐาน: เงื่อนไขของ SDK + สถานะการตั้งค่า LINE Developers ณ ปัจจุบันซึ่งไม่ทราบ; Founder อาจ link bot แล้วหลัง 2026-11-05]

### 2.5 จุดอื่นที่เห็นจากโค้ด

- ปุ่ม "เข้าสู่ระบบ" ที่หน้า guest (มุมบน และปุ่มสุดท้ายของตะกร้า) ไม่มีคำเตือนเรื่อง LINE/Google ก่อนกด กล่องเตือนอยู่เฉพาะหน้า `/food/login` ซึ่งลูกค้าเห็นหลังกดไปแล้ว [โค้ด food-guest-browse.tsx:311, 381, 526]
- `/food/signup` ไม่มีกล่อง `LineLoginGuidance` (ไม่จำเป็นเพราะเป็นอีเมลล้วน แต่ยังออกนอก LINE ตอนยืนยันอีเมล) [โค้ด]
- LIFF consent ครั้งแรก (LINE ขออนุญาต profile/openid) เกิดตอน `liff.init` ก่อนเห็นหน้าใดของ ZOKY — เป็นอีกหนึ่งขั้นที่ลูกค้าต้องกด [สมมติฐาน ตาม scope `openid profile` ที่ APPROVALS ระบุ]

---

## 3. กล่อง `LineLoginGuidance` โผล่เมื่อไหร่ ไม่โผล่เมื่อไหร่

[โค้ด `web/components/food/line-login-guidance.tsx`, `food-auth.tsx:335`]

**โผล่** เมื่อครบทุกข้อ
1. เป็นหน้า `FoodLoginScreen` (`/food/login`) เท่านั้น และผ่านขั้น "กำลังตรวจสอบบัญชี…" (`checking=false`) โดยไม่ถูกส่งต่อ: ไม่ใช่ legacy installed origin, ไม่ถูก redirect ไป origin canonical, ยังไม่มี session
2. `navigator.userAgent` ตรง `/\bLine\/\d/i` (`isLineInAppBrowser`) — อ่านแบบ synchronous ใน client render แรก (server snapshot = false)
3. ข้อความหลัก "เปิดใน LINE อยู่" แสดงทันทีเมื่อผ่านข้อ 1-2

ส่วนปุ่ม "เปิดในเบราว์เซอร์" แสดงเมื่อ `slot === "ready"` เท่านั้น คือ มี LIFF ID ที่รูปแบบถูกต้องใน build **และ** `liff.init` สำเร็จ **และ** `liff.isInClient() === true` ถ้าอย่างใดอย่างหนึ่งไม่เป็นจริง จะขึ้นข้อความ "เปิดเบราว์เซอร์จากที่นี่ไม่ได้…" แทนปุ่ม

กรณีที่ `liff.init` อาจล้มเหลว [สมมติฐาน]: หน้า login อยู่คนละ origin กับ endpoint ที่ลงทะเบียน (`food.wynos.online`) เช่นถ้า phase 2 ย้ายผู้ใช้ไป `zoky.wynos.online` — พฤติกรรม SDK ในกรณีนี้ไม่ได้พิสูจน์

**ไม่โผล่** ในกรณี
| กรณี | เหตุผล |
|---|---|
| iOS in-app browser ของ LINE ที่ UA ไม่มี `Line/` | เงื่อนไขข้อ 2 ไม่ผ่าน **[สมมติฐาน]** ว่ากรณีนี้มีจริงหรือไม่ ต้องดูจาก UA ของเครื่องจริง (เช่น เปิดหน้าทดสอบที่แสดง `navigator.userAgent`) โค้ดไม่มีทางรู้ UA ล่วงหน้า; เพราะกฎ redirect ฝั่ง server ใช้ UA เดียวกัน ถ้า UA ไม่มี `Line/` กฎ openExternalBrowser ก็ไม่ทำงานด้วย |
| ลูกค้าอยู่ในเบราว์เซอร์อื่นที่ Google บล็อกเช่นกัน (Facebook/Instagram/TikTok) | `LineLoginGuidance` ตรวจ LINE อย่างเดียว; `detectInAppBrowser` ครอบคลุมสี่แอปแต่ใช้เฉพาะ `WelcomeScreen` ของ Social (`components/auth-flow/screens.tsx:213`) ไม่ใช่ `/food/login` |
| `/food/signup`, หน้า guest browse, ตะกร้า, ก่อนกดปุ่มเข้าสู่ระบบ | ไม่ได้ render component นี้ |
| ผู้ใช้ติดตั้ง PWA iOS (Home Screen) | UA ไม่มี `Line/` และไม่ใช่ LINE |
| `/line?mode=link` | ไม่ใช้ component นี้ ใช้ข้อความ `need_signin` ของตัวเองที่เช็ก `liff.isInClient()` (เงื่อนไขต่างกัน อาจแสดงไม่ตรงกับกล่อง) |
| LINE บน desktop / LINE ที่เปิด external browser อยู่แล้ว | UA ไม่มี `Line/` (ตามการคาดเดา) |
| หน้า login ถูกเปิดหลัง redirect โดยพารามิเตอร์ `openExternalBrowser` และ LINE ส่งไป Safari | UA เป็น Safari ปกติ -> ไม่แสดง (ซึ่งถูกต้อง เพราะ Google ใช้ได้) |

ข้อควรระวัง: กล่องนี้ **เตือนก่อน** กดเท่านั้น ถ้าลูกค้าไม่อ่านแล้วกด Google ก็ไปเจอหน้า error ของ Google ตามข้อ 2.1 โดยไม่มีตัวช่วย

---

## 4. ข้อเสนอแก้ที่เล็กที่สุด เรียงตามผลต่อลูกค้า

ทุกข้อเป็นข้อเสนอ ไม่ได้ลงมือ และต้องผ่าน workflow/release gate เดิม (ไม่ข้าม staging และ Founder gate)

| ลำดับ | ข้อเสนอ | ผลต่อลูกค้า | ขนาด | ต้อง Founder approval? |
|---|---|---|---|---|
| 0 | เก็บคลิปเครื่องจริงตามข้อ 5 ก่อน โดยเฉพาะ 3 ข้อ: (ก) ร้านเปิดใน LINE หรือถูกดีดไป Safari หลัง `/line`, (ข) UA จริงของ LINE iOS/Android, (ค) login อีเมลสำเร็จแล้วยังอยู่ใน LINE ไหม | ตัดสินว่าลำดับ 1-2 จำเป็นแค่ไหน | ไม่มีโค้ด | ไม่ (ตามเงื่อนไข D-3 ต้องมี baseline อยู่แล้ว) |
| 1 | ถ้า redirect `openExternalBrowser` ดีดลูกค้าออกจาก LIFF/ทำลาย login อีเมล: ปรับกฎใน `next.config.ts` เช่น ไม่ใช้กับโดเมน ZOKY (`zoky/food.wynos.online`) หรือยกเว้น path/flow ที่ใช้ใน LIFF (`/line`, `/s/`, `/food`, `/food/login`) | ปิดช่องที่ทำให้ "สั่งในไลน์" ไม่ได้ ถ้าสมมติฐานเป็นจริง = กระทบสูงสุด | เล็ก (config) แต่ผลกว้าง | **ใช่** — แก้ routing ของ production ที่เคยอนุมัติไว้ เพื่อให้ลิงก์แชทธรรมดาหยุดถูกส่งออกเบราว์เซอร์ ซึ่งเปลี่ยนจุดตัดสินระหว่าง "Google ใช้ได้" กับ "อยู่ใน LINE"; ควรให้ Founder รับทราบผลสองด้านก่อน (AGENTS.md: change control / ผลต่อ auth surface) |
| 2 | ใส่คำเตือนเรื่อง Google/LINE ที่ปุ่ม "เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ" และปุ่มเข้าสู่ระบบมุมบนใน guest browse เมื่อ UA เป็น LINE (ก่อนไปหน้า login) และจัดให้อีเมล+รหัสผ่านเป็นปุ่มหลักใน LINE | ลดคนที่กด Google แล้วเจอหน้า error ของ Google | เล็ก (UI) | ไม่ (ไม่เปลี่ยน auth) ต้อง UI/UX + QA เท่านั้น |
| 3 | ให้ปุ่ม "เปิดในเบราว์เซอร์" พก store id (UUID สาธารณะ ไม่ใช่ข้อมูลส่วนตัว) ไปด้วย เช่น `/food/login?store=<uuid>` และให้หน้า login เรียก `rememberSharedFoodStore` -> หลัง login กลับมาที่ร้านเดิม; แก้ข้อความเตือนว่า "ร้านและตะกร้าจะไม่ถูกย้าย/จะกลับมาที่ร้านเดิมแต่ต้องเลือกเมนูใหม่" | ลูกค้าไม่ต้องหาร้านใหม่หลัง login ใน Safari | เล็ก | ไม่เกี่ยว auth แต่ **ขัดข้อกำหนด F เดิม** ("ไม่มี query") ต้อง PM/CTO ยืนยัน scope ก่อน และ QA open-redirect/allowlist |
| 4 | จอ "เพิ่มเพื่อน LINE ของ ZOKY": เมื่อ `unavailable` ให้พาเข้าร้านต่อโดยอัตโนมัติ (ไม่บล็อกลูกค้าที่เป็นเพื่อนอยู่แล้ว) และ/หรือยืนยันว่า LIFF link bot แล้ว | ถ้าสมมติฐานข้อ 2.4 เป็นจริง ทุกสแกน QR ติดจอนี้ — แก้แล้วลดหนึ่งขั้นสำหรับลูกค้าทั้งหมด | เล็ก (web) หรือเป็นงานตั้งค่า LINE Developers | ส่วน web: แจ้ง Founder (เปลี่ยนพฤติกรรมที่ Founder อนุมัติ 2026-11-05 ให้ "ไม่ force friendship") ส่วนตั้งค่า LINE Developers เป็น Founder action นอกโค้ด |
| 5 | หลัง auto-link จบ `/line` ไม่ต้อง prompt เพิ่มเพื่อนซ้ำ (ส่งธง/พารามิเตอร์ไม่ให้เรียก `requestStoreLineFriendship` ในรอบที่มาจาก auto-link) | ลดการเด้ง prompt ซ้ำและจอเพิ่มเพื่อนซ้ำหลัง login | เล็ก | ไม่ |
| 6 | ตั้ง `pageshow` ให้รีเซ็ต `googleLoading` เมื่อกลับมาจาก Google error | ปุ่ม Google ไม่ค้างหลังกด back | เล็กมาก | ไม่ |
| 7 | ตรวจดีไซน์ merge: การนำเข้าตะกร้า guest ทับตะกร้าเก่า (`:3609`) ให้ถามหรือรวม | กันตะกร้าเก่าหาย | เล็ก-กลาง | ไม่ |
| 8 | LINE Login (design A ใน `docs/architecture/zoky-line-002-line-login-and-server-cart.md`) | แก้รากเหตุ: ลูกค้าใน LINE มี session ได้โดยไม่ออก LINE | ใหญ่ | **ใช่ — Authentication Architecture Change** Founder อนุมัติแบบมีเงื่อนไขแล้ว (2026-11-07): ต้องวัด baseline และผ่าน CTO/QA review design ก่อน implement |
| 9 | ตะกร้าฝั่ง server (design B) / ปรับ Supabase email confirmation ให้ไม่ต้องออกจาก LINE | แก้ตะกร้าหายข้ามเบราว์เซอร์ / แก้ทางสมัครด้วยอีเมล | กลาง-ใหญ่ | **ใช่** — DB ใหม่/PII (D-6 ยังไม่อนุมัติ design B) และการเปลี่ยน auth policy |

หมายเหตุลำดับ: ถ้าการทดสอบข้อ 0 พบว่ากฎ redirect ไม่กระทบ LIFF ให้ลดความเร่งด่วนของข้อ 1 ลงและยกข้อ 2, 4 ขึ้นก่อน

---

## 5. สิ่งที่ยืนยันไม่ได้จนกว่าจะมีคลิปจากเครื่องจริง

### 5.1 อ่านจากโค้ดแล้ว (มีหลักฐานในไฟล์)
- allowlist ปลายทาง `/line`, รูปแบบ QR (ถ้ามี LIFF ID), ลำดับ `/line` -> friendship -> auto-link -> `replace(destination)`
- กฎ redirect ใน `next.config.ts` และเงื่อนไข UA/query ที่ยกเว้น
- Guest browse + ตะกร้า guest เก็บใน sessionStorage, นำเข้าตอน login เมื่อร้านตรงกัน
- ปุ่ม "เปิดในเบราว์เซอร์" เปิดเฉพาะ `/food/login` ไม่มีร้าน/ตะกร้า
- `withLineGoogleHint` ถูกเรียกเฉพาะเมื่อเริ่ม OAuth ล้มเหลวฝั่ง client ไม่ใช่ตอน Google ปฏิเสธ
- auto-link ใช้ได้เฉพาะ UA ที่มี `Line/` + localStorage ใน WebView นั้น + อายุ 30 นาที
- ไม่มีโค้ด welcome/Rich menu ใน repo

### 5.2 สันนิษฐาน (ต้องเห็นเครื่องจริง)
1. LINE ดีดออกเบราว์เซอร์เมื่อ HTTP redirect ใน LIFF WebView มี `openExternalBrowser=1` หรือไม่ (ที่ `/line`, หลัง `/line`, หลัง login อีเมล)
2. UA จริงของ LINE iOS (in-app browser, LIFF) และ Android มี ` Line/` หรือไม่ (กระทบทั้งกฎ redirect และกล่องเตือน)
3. Google แสดงหน้า error อะไรจริง (ข้อความ, มีปุ่มกลับไหม), และปุ่ม Google ค้าง "กำลังเชื่อมต่อ…" หลัง back หรือไม่
4. LIFF ตอนเปิดครั้งแรกมีหน้า consent หรือไม่ และ `isLoggedIn()` เป็นจริงโดยอัตโนมัติใน client หรือไม่
5. `getFriendship()` ทำงานหรือ throw ณ ตอนนี้ (OA ถูก link กับ LIFF แล้วหรือยัง) ซึ่งกำหนดว่าลูกค้าทุกคนเห็นจอ "เพิ่มเพื่อน" หรือไม่ และ `openWindow` โปรไฟล์ OA แสดงอย่างไร
6. origin จริงที่ลูกค้าอยู่ (`food.wynos.online` หรือ `zoky.wynos.online`) และ `ZOKY_LEGACY_FOOD_REDIRECT` เปิดหรือไม่ รวมถึงผลของ `liff.init` เมื่อ origin ไม่ตรงกับ endpoint
7. Supabase เปิด email confirmation หรือไม่ (กำหนดว่าสมัครด้วยอีเมลในไลน์ต้องออกไปแอปเมลหรือไม่)
8. ตะกร้า guest รอดหรือไม่เมื่อ LINE ปิด/เปิด WebView ใหม่, และตะกร้ารอดหลัง auto-link reload จริงหรือไม่
9. Rich menu / Greeting message / Auto-reply ปัจจุบันของ OA ลูกค้าเป็นอย่างไร (สถานการณ์ B ทั้งหมด)
10. ผลของ RSC navigation (`router.push("/food/login")`) ผ่านกฎ redirect ใน LINE UA
11. ความเสี่ยงที่ commit ใน worktree (fe619a5) ไม่ตรงกับ production จริง (a70cbb0)

### 5.3 สิ่งที่ควรให้เห็นในคลิป/ข้อมูลที่ขอจาก Founder
- คลิปหน้าจอเครื่องจริง iOS และ Android: สแกน QR -> ร้าน -> เพิ่มตะกร้า -> เข้าสู่ระบบ (กด Google และอีเมล) -> กลับมาที่ตะกร้า โดยให้เห็นแถบ URL/ชื่อโดเมนทุกขั้น
- ค่า `navigator.userAgent` จากเครื่องจริง (ส่งเป็นภาพหน้าจอหน้าทดสอบ ไม่ใช้ข้อมูลส่วนตัว)
- ภาพหน้าจอ LINE Developers ของ LIFF (endpoint, Add friend option, linked OA) และ OA Manager (Greeting/Rich menu) โดยไม่มี secret
- ห้ามใช้บัญชีลูกค้าจริง ใช้ staging + OA ทดสอบตามแผน usability เดิม

---

## สรุปสั้น (ไม่เกิน 15 บรรทัด)

1. QR ร้านเปิด LIFF -> `/line` -> (จอเพิ่มเพื่อน) -> ร้านแบบ guest -> `/food/login`; เส้นทางแอด OA เปล่า ๆ ไม่มีโค้ดพาไป ZOKY ต้องดู OA Manager.
2. ลูกค้าใน LINE เป็น guest เสมอ; Google ถูกปฏิเสธด้วยหน้า error ของ Google ที่ ZOKY ไม่มีโอกาสแสดงคำแนะนำหลังกด.
3. ความเสี่ยงสูงสุดที่ยังพิสูจน์ไม่ได้: กฎ `openExternalBrowser` ใน `next.config.ts` ไม่แยก LIFF กับลิงก์แชท ทุก redirect ใน LINE อาจดีดออกไป Safari (รวมหลัง login อีเมลสำเร็จ).
4. ปุ่ม "เปิดในเบราว์เซอร์" พาไปแค่ `/food/login` ทำให้หลุดทั้งตะกร้าและร้าน และ Safari login ไม่ทำให้ LINE มี session (และ auto-link ไม่ทำงาน).
5. กล่อง LineLoginGuidance โผล่เฉพาะ `/food/login` เมื่อ UA ตรง `Line/\d`; ไม่โผล่ใน guest browse/ตะกร้า/signup และไม่โผล่ถ้า UA ไม่มี `Line/` (เป็นสมมติฐานว่า iOS บางรุ่นเป็นเช่นนั้น).
6. ถ้า LIFF ยังไม่ link OA bot จอ "เพิ่มเพื่อน" น่าจะขึ้นกับทุกคน รวมคนที่เป็นเพื่อนแล้ว (สมมติฐาน).
7. ข้อเสนอเรียงตามผล: เก็บคลิปก่อน -> แก้กฎ redirect (ต้อง Founder) -> คำเตือนที่ปุ่ม login ใน guest -> พก store id ไปกับ "เปิดในเบราว์เซอร์" -> ปรับจอเพิ่มเพื่อน -> LINE Login (ต้อง Founder, อนุมัติแบบมีเงื่อนไขแล้ว).
8. worktree HEAD คือ fe619a5 ไม่ใช่ a70cbb0 ที่ระบุ ควรยืนยัน commit ที่ deploy จริง.
9. ไม่มีการแก้ source ไม่ commit ไม่แตะ secrets/DB/LINE จริง.
