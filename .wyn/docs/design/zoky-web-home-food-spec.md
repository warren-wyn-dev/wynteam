# ZOKY Web — Home + หน้าสั่งอาหาร (Food) Adaptation Spec

> โดย AI Design | 2026-10-19 | สถานะ: **PROPOSED — รอ Founder ดู preview และอนุมัติทีละหน้า** (DECISIONS 2026-10-19 "ZOKY web — ทำหน้าตาเว็บให้เหมือนแอป (ก)")
> ขอบเขต: เว็บลูกค้า Next.js `zoky.wynos.online` (ฐาน `release/zoky-web-20261018`) — หน้า Home และหน้าสั่งอาหารเท่านั้น หน้าร้าน / ตะกร้า / checkout / ออเดอร์ / บัญชี ยังไม่เปลี่ยนในรอบนี้
> เอกสารนี้เป็นเอกสารออกแบบเท่านั้น ไม่ได้อนุมัติให้แก้ application source, เพิ่ม dependency หรือ deploy — งาน implement ต้องผ่าน CTO → Full-Stack → QA → staging → Founder Gate ตามเดิม

**แหล่งอ้างอิง (source of truth)**
- ดีไซน์: Flutter `zoky_app/lib/features/home/**`, `features/food/**`, `core/design/**`, `core/widgets/**` บน `docs/zoky-foundation` และ `.wyn/docs/design/zoky-design-system.md` (ข้อ 7.1 Glossy 3D, 9.8 nav)
- พฤติกรรม/ข้อมูลจริง: `web/components/food/wynos-food-developer-app.tsx`, `food-guest-browse.tsx`, `food-promotion-center.tsx`, `web/app/food/{layout.tsx,food-app.css}`, `web/lib/food-customer.ts`, `web/lib/food-store-availability.ts` บน `release/zoky-web-20261018` (อ่านจาก local worktree `/home/user/wynteam-release` — ไม่ได้ตรวจว่าตรงกับ `origin` ล่าสุด; Full-Stack ต้องตรวจซ้ำก่อนเริ่ม)
- กติกา Founder: ข้อมูลจริงเท่านั้นบน production, ห้ามคะแนน/เวลา/โปรปลอม, ป้าย "ตัวอย่าง" ใช้เฉพาะข้อมูลตัวอย่าง (ซึ่งจะไม่มีบนเว็บ), ปุ่ม "รับเองที่ร้าน" **ซ่อน** บนเว็บข้อมูลจริง (CTO P3: backend ยังไม่มี pickup), รูปอาหาร/ร้าน 1:1, ไม่มีหัวใจบนรูปร้าน, คง pinch-zoom/ขนาดปุ่มเดิมของเว็บ (DECISIONS 2026-10-17 ข้อ 3)

```
Screen: Web Home (หน้าหลัก) และ Web Food (หน้าสั่งอาหาร) ของ ZOKY
Purpose: ให้เว็บหน้าตาเหมือนแอป ZOKY ที่ Founder อนุมัติ โดยฟังก์ชันเดิมของเว็บทำงานครบและใช้ข้อมูลจริงเท่านั้น
User Flow: ข้อ 3
Components: ข้อ 4, 5, 6
Interactions: ข้อ 3, 5, 6
States: ข้อ 9
Responsive Behavior: ข้อ 8
Accessibility: ข้อ 10
Design Rules: ข้อ 1, 2, 11
Handoff: ข้อ 13
```

---

## 1. การตัดสินใจหลัก (Design decisions)

| # | ตัดสินใจ | เหตุผล |
|---|---|---|
| W1 | เว็บมี 2 หน้า: **Home** (Home v1 Phase 1–5) และ **Food** (FoodHomeScreen) — กดการ์ด "อยากกินอะไรวันนี้?" หรือปุ่ม "ค้นหาของอร่อย" เพื่อเปิด Food | ตรงกับแอป (DECISIONS 2026-10-18 "Home v1 คงเดิม, เลย์เอาต์ LINE MAN คือหน้า Food") |
| W2 | ไดเรกทอรีร้านเดิมของเว็บ (ค้นหา, ตัวกรอง, โค้ดลด, สั่งอีกครั้ง, ร้านใกล้คุณ) **ย้ายไปอยู่หน้า Food** ทั้งหมด ใช้ logic/ข้อมูลเดิม เปลี่ยนแค่หน้าตา | หน้า Food ของแอปคือหน้าไดเรกทอรี |
| W3 | ส่วนที่ยังไม่มีข้อมูลจริงบน production **ซ่อน** (ไม่ใส่ข้อมูลตัวอย่าง): ดีลเด็ดวันนี้, ร้านอาหารแนะนำ (featured — งาน #1135 ยังไม่ขึ้น production), หมวดอาหาร 4 วง, แบนเนอร์, ปุ่มจัดส่ง/รับเองที่ร้าน — ดูคำถาม Founder ข้อ 14 | กติกาข้อมูลจริงเท่านั้น; แอปเองก็ซ่อน section เมื่อไม่มีข้อมูล |
| W4 | Bottom nav ใช้ **capsule ลอยแบบแอป** (Phase 5) แทน `fx-nav` เดิม แสดงบน Home/ออเดอร์/ข้อความ/บัญชี และ **ไม่แสดงบนหน้า Food** | เว็บมี nav 4 แท็บลำดับเดียวกันอยู่แล้ว เปลี่ยนแค่หน้าตา; หน้า Food ในแอปเป็นหน้าเต็มจอไม่มี nav (DECISIONS 2026-10-18) และพื้นที่ล่างเป็นของปุ่มตะกร้าลอย |
| W5 | ไอคอน 3D / ไอคอน nav / ผิวมันวาว ทำเป็น **inline SVG + CSS** (React component เล็ก ๆ) แปลงจาก painter ของ Flutter ตรงตัวเลข — ไม่เพิ่ม dependency | เบา, คมทุกขนาด, ไม่ต้องโหลดรูป |
| W6 | เวลาจัดส่ง (ETA) แสดง **เฉพาะเมื่อร้านตั้งเวลาเตรียมอาหารจริง** (`prep_time_min_minutes` และ `prep_time_max_minutes` ไม่ใช่ null) — เลิกใช้ค่าเดา 15/30 ของเว็บในหน้า Home/Food | กติกา "ห้าม ETA ปลอม" และตรงกับแอป (`ZokyStoreSummary.hasEta`) |
| W7 | Layout ล็อกเป็นคอลัมน์กลาง `max-width: 480px` บนจอกว้าง (iPad/desktop) พื้นหลัง header ยาวเต็มจอ | ไม่ยืด layout; ตรงกับรูปแบบแอป (Founder ใช้ iPad) |
| W8 | ผู้ใช้ที่ยังไม่ล็อกอิน (guest) ใช้ visual ชุดเดียวกัน แต่ข้อมูลเท่าที่ public catalog ให้ (ข้อ 7.3) | ไม่ทำ 2 หน้าตา; ไม่เปิดข้อมูลที่ต้องล็อกอิน |

---

## 2. Tokens (คัดลอกจาก `zoky_app/lib/core/design/*` — ห้ามเปลี่ยนค่า)

ประกาศเป็น CSS custom properties บน `.fx-app` (prefix `--zk-` ตาม design system ข้อ 12) ค่า `--fx-*` เดิมยังอยู่ ไม่ต้องรื้อหน้าที่ยังไม่ redesign

### 2.1 สี

| Token | Hex | ใช้กับ |
|---|---|---|
| `--zk-brand` | `#F21967` | ไอคอน, indicator, focus ring (ห้ามเป็นพื้นของตัวหนังสือขาวขนาดปกติ) |
| `--zk-brand-light` | `#F4368D` | gradient ไอคอน nav ที่เลือก (บน) |
| `--zk-brand-deep` | `#D61256` | พื้นทุกอย่างที่มีตัวหนังสือขาว, ลิงก์/ตัวหนังสือแบรนด์บนขาว, ไอคอนเส้นแบรนด์ |
| `--zk-berry` | `#AF1341` | pressed ของ brand-deep |
| `--zk-brand-line` | `#F9C0DE` | ขอบปุ่ม "เก็บแล้ว", rim ล่างของ white control (40%) |
| `--zk-header-top` / `-mid` / `-bottom` | `#F93384` / `#F72C7E` / `#EE226E` | ผิวชมพูมันวาว Home header + การ์ด hero (stops 0 / 35% / 100%) |
| `--zk-header-pale` / `-pale-mid` | `#FFEFF5` / `#FFF7FA` | header หน้า Food (ชมพูอ่อนสุด → ขาว) |
| `--zk-gloss-white-bottom` | `#FFF1F6` | ปลาย gradient ของ white glossy control |
| `--zk-soft-pink` | `#FDEEF3` | พื้นการ์ดโค้ดลด, วงกลมรูปร้าน "สั่งอีกครั้ง" |
| `--zk-nav-selected` | `#FFEDF4` | capsule ไฮไลต์ของแท็บที่เลือก |
| `--zk-surface` | `#FFFFFF` | พื้นหน้า, การ์ด, nav |
| `--zk-canvas` | `#F8FAFE` | (สำรอง) |
| `--zk-sunken` | `#F6F6F8` | placeholder รูป |
| `--zk-chip` | `#F3F3F6` | พื้นชิปที่ไม่เลือก (filled) |
| `--zk-border-subtle` | `#EBEBEF` | hairline ช่องค้นหา, เส้นใต้แถบชิปตอน sticky |
| `--zk-border-default` | `#DCDCE2` | เส้นคั่น ★ │ เวลา |
| `--zk-ink` | `#16161A` | ตัวหนังสือหลัก |
| `--zk-text-secondary` | `#6B6B76` | ตัวหนังสือรอง/placeholder/label nav ที่ไม่เลือก |
| `--zk-error` / `-container` | `#B3261E` / `#F9DEDC` | error state, badge แจ้งเตือนบน nav |
| `--zk-success` / `-container` | `#187A43` / `#E9F7EF` | (ไม่ใช้ในสองหน้านี้ ยกเว้น note) |
| `--zk-skeleton-base` / `-highlight` | `#F1F1F4` / `#F8F8FA` | shimmer |

### 2.2 Typography — Anuphan

- ฟอนต์: `var(--font-anuphan), "Noto Sans Thai", system-ui, sans-serif` (มีอยู่แล้วใน `web/app/food/layout.tsx` น้ำหนัก 400/500/600/700) — **ไม่ต้องเพิ่ม** ถ้าใช้ 800 (หัวการ์ดดีลในแอป) ให้ใช้ 700 แทน เพราะดีลซ่อนอยู่ (W3) จึงไม่ต้องโหลดน้ำหนักเพิ่ม
- line-height ขั้นต่ำ: body 1.45, title 1.25 (สระ/วรรณยุกต์ไทย) ห้าม letter-spacing บวกกับภาษาไทย (ยกเว้น "FOOD DELIVERY" ภาษาอังกฤษ 1.4px)
- ตัวเลขราคา/จำนวน: `font-variant-numeric: tabular-nums`

| ชื่อ | size / weight / line-height | ใช้ที่ |
|---|---|---|
| display | 28 / 700 / 1.25, ls −0.3px | หัวการ์ด hero "อยากกินอะไร⏎วันนี้?" (ขาว) |
| heroSubtitle | 19 / 700 / 1.35 | "ของอร่อยใกล้คุณ เริ่มที่นี่" (ขาว — large text) |
| sectionTitle | 20 / 700 / 1.3, ls −0.2px | หัว section ทุกอัน |
| storeName (Food row) | 18 / 700 / 1.3 | ชื่อร้านในแถว |
| couponLabel | 18 / 700 / 1.3 | "ลด 20%", "ส่งฟรี" |
| addressName | 17 / 700 / 1.3 | ชื่อที่อยู่ใน header Food |
| labelLg | 16 / 700 / 1.25 | ปุ่ม, "ค้นหาของอร่อย", "เก็บโค้ด", "ตัวกรอง"(600), "ดูเมนู"(600) |
| bodyLg | 16 / 400 / 1.45 | placeholder ช่องค้นหา |
| bodyMd | 15 / 400 / 1.45 | meta แถวร้าน (lh 1.35), เงื่อนไขโค้ด, ชื่อร้านการ์ด (700, lh 1.3), label วงกลม |
| labelMd | 14 / 700 | "ดูทั้งหมด", ชิปตัวกรอง (600) |
| bodySm | 13 / 400 / 1.45 | เวลาในการ์ด, "จัดส่งที่" (600, lh 1.3), คะแนน (700) |
| navLabel | 13 / 500 (เลือก 700) | label nav |
| labelSm | 12 / 700 / 1.25 | ป้ายในแถวร้าน (ปิดอยู่/โปร/โฆษณา), "FOOD DELIVERY" |
| caption | 11 / 700 | ตัวเลข badge |

### 2.3 Spacing / radius / shadow

- Spacing scale: `2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 32, 48` — gutter 16
- Radius: xs 6, sm 10, md 14, lg 16, xl 20, 2xl 24, full 9999; แผ่นขาวใต้ header Home = **28**
- Shadow:
  - `--zk-shadow-brand-surface`: `0 10px 24px rgb(238 34 110 / 25%)` (การ์ด hero)
  - `--zk-shadow-control`: `0 4px 12px rgb(238 34 110 / 22%)` (white glossy control บนพื้นชมพู)
  - `--zk-shadow-control-pale`: `0 1px 3px rgb(214 18 86 / 16%)` (white glossy control บน header ชมพูอ่อน — เงาแน่นไม่ให้ล้นกรอบ 44)
  - `--zk-shadow-card`: `0 6px 16px rgb(238 34 110 / 16%)` (การ์ดร้านแนวนอน)
  - `--zk-shadow-search`: `0 2px 10px rgb(22 22 26 / 8%)`
  - `--zk-shadow-brand`: `0 8px 18px rgb(214 18 86 / 26%)` (ปุ่มตะกร้าลอย, ปุ่ม primary)
  - `--zk-shadow-nav`: `0 10px 36px rgb(59 26 41 / 14%), 0 1px 4px rgb(22 22 26 / 6%)` + hairline `0 0 0 0.5px rgb(22 22 26 / 8%)`
- Motion: press 140ms `cubic-bezier(.2,.8,.2,1)` scale .97; base 200ms; nav highlight 220ms; shimmer 1200ms; `prefers-reduced-motion` = ไม่มี animation (เว็บมี rule นี้อยู่แล้ว)

---

## 3. User flow

```
เปิด zoky.wynos.online (ล็อกอินแล้ว)
  → Home  ──[แตะการ์ด hero / "ค้นหาของอร่อย"]──→ Food
  │  ├ หัวใจ → sheet "ร้านโปรด" (FavoriteStoresSheet เดิม)
  │  ├ ตะกร้า (แสดงเมื่อมีของ) → แท็บตะกร้าเดิม
  │  ├ "ร้านยอดนิยม/แนะนำ" (ถ้า Founder เลือก ก ในข้อ 14) → หน้าร้าน
  │  └ nav: หน้าหลัก / ออเดอร์ / ข้อความ / บัญชี (แท็บเดิม)
  Food
  │  ├ ← กลับ → Home
  │  ├ "จัดส่งที่ ▾" → แท็บบัญชี (จัดการที่อยู่ — พฤติกรรมเดิมของเว็บ)
  │  ├ หัวใจ → "ร้านโปรด" | ตั๋วคูปอง → sheet "รวมโค้ดลดเพิ่ม"
  │  ├ พิมพ์ค้นหา → ผลการค้นหาแทนเนื้อหาด้านล่าง (debounce 280ms เดิม)
  │  ├ แตะร้าน → หน้าร้านเดิม (บันทึก ad click เดิม) → ปุ่มกลับของหน้าร้านกลับมาที่ Food
  │  └ ปุ่มตะกร้าลอย → แท็บตะกร้าเดิม
```

- สถานะหน้า: เพิ่ม view ในแท็บ home เป็น `home | food` (คู่กับ `storefrontOpen` เดิม) — แนะนำให้ push history (`?view=food`) เพื่อให้ปุ่ม back ของเบราว์เซอร์/swipe-back ของ iPad กลับ Home ได้ และ refresh แล้วอยู่หน้าเดิม (Architect/CTO ยืนยันวิธี; ห้ามชน `?store=` และ `?order=` ที่ใช้อยู่)
- หน้าร้านจำว่าเปิดมาจากไหน: จาก Food → กลับ Food; จาก Home → กลับ Home; จากลิงก์แชร์ `?store=` → กลับ Food
- แตะแท็บ "หน้าหลัก" ใน nav: กลับ Home (และเลื่อนขึ้นบนสุดถ้าอยู่ Home อยู่แล้ว)

---

## 4. หน้า Home (mobile 390/430)

ลำดับจากบนลงล่าง (ตรงกับ `home_screen.dart`):

### 4.1 Header ชมพูมันวาว (Phase 1) — `ZokyHomeHeader`
- ผิว: brand glossy surface (ข้อ 6.2) เต็มความกว้างจอ ใต้ status bar; gloss band สูง `safe-area-top + 28px` ความทึบ **7%** (ไม่ใช่ 35%), ไม่มี rim, ไม่มีเงา
- คลื่นแสง: SVG overlay `preserveAspectRatio="none"` viewBox `0 0 100 100`
  - `M52 0 C62 38 80 58 100 50 L100 0Z` fill `#fff` opacity .10
  - `M0 58 C30 40 62 86 100 66 L100 100 L0 100Z` fill `#fff` opacity .08
- แถวโลโก้: padding `calc(env(safe-area-inset-top) + 6px) 18px calc(10px + 28px) 20px`; สูง `max(logoW / 1.807, 74px)`
  - ซ้าย: wordmark ขาว `/icons/zoky/wordmark-white-v1.png` (มีอยู่แล้ว) กว้าง `clamp(124px, 36vw, 164px)` (ภายในคอลัมน์ 480 ใช้ 36% ของความกว้างคอลัมน์) — อยู่ใน `<h1>` ด้วย `alt="ZOKY"`
  - ขวา: ปุ่ม "ร้านโปรด" white glossy วงกลม 44 (กดได้ 48) + หัวใจ 3D 26 → เปิด FavoriteStoresSheet เดิม (ข้อมูลจริงจาก localStorage — **ไม่ใช่** "เร็ว ๆ นี้" แบบแอป)
  - ขวา (เพิ่มสำหรับเว็บ): เมื่อ `cartCount > 0` แสดงปุ่ม "ตะกร้า" white glossy วงกลมเดียวกัน ก่อนหัวใจ, ไอคอน Lucide `ShoppingBag` 22 stroke 2 สี `--zk-brand-deep` + badge จำนวน (พื้น `--zk-brand-deep` ตัวขาว 11/700, ขอบขาว 2px, เกิน 99 = "99+") — ถ้าตะกร้าว่างไม่แสดง (Home ของแอปมีแค่หัวใจ)
- แผ่นขาวมุมโค้ง 28 ทับขอบล่างของสีชมพู (เลยลงไป 1px กันเส้น)
- `theme-color` ของ Home = `#F93384` (ค่าปัจจุบัน) — status bar ตัวขาว
- Overscroll (iOS rubber-band): พื้นหลังส่วนบนของ scroll container เป็นชมพู `#F93384` ไม่ให้เห็นแถบขาวเมื่อดึงลง

### 4.2 การ์ด "อยากกินอะไรวันนี้?" (Phase 2) — `ZokyFoodHeroCard`
- ยกขึ้นทับแผ่นขาว `-16px` (28 − 12), ระยะข้าง 16
- ผิว: brand glossy surface เต็มสูตร (gloss 35% สูง 54px, rim, เงา `--zk-shadow-brand-surface`), radius 24, padding 20
- คอลัมน์ซ้าย: pill white glossy (padding 2 12 2 8, radius full) = sparkle 3D 16 + "FOOD DELIVERY" 12/700 ls 1.4 `--zk-brand-deep` → เว้น 14 → title display ขาว 2 บรรทัด (screen reader อ่าน "อยากกินอะไรวันนี้?" บรรทัดเดียว, เป็น heading) → เว้น 6 → subtitle 19/700 ขาว ห้ามตัดคำกลางวลี (แยกที่ช่องว่าง: "ของอร่อยใกล้คุณ " / "เริ่มที่นี่")
- คอลัมน์ขวา (เว้น 8): วงกลม frosted ขนาด `clamp(76px, 34% ของความกว้างด้านใน, 124px)` (ลด ×0.82 เมื่อผู้ใช้ขยายตัวหนังสือ) + ภาพกล่องเบนโตะ — ตกแต่ง `aria-hidden`
- เว้น 20 → ปุ่ม "ค้นหาของอร่อย": white glossy, radius 14, สูงขั้นต่ำ 48, padding 6 8 6 16, ตัวหนังสือ 16/700 `--zk-brand-deep`, ท้ายปุ่มลูกแก้วลูกศร 3D 32
- แตะที่ใดก็ได้บนการ์ด = เปิด Food; สำหรับ keyboard/screen reader มี **ปุ่มเดียว** คือ "ค้นหาของอร่อย" (การ์ดทั้งใบเป็น click target แบบ `onClick` บน wrapper ที่ไม่ focus ได้)
- ภาพเบนโตะบนเว็บ: export จาก `ZokyBentoIllustration` เป็น **SVG ไฟล์เดียว** (แนะนำ) หรือ WebP @2x/@3x ที่ ≤ 20 KB ไว้ใน `web/public/icons/zoky/` แบบ versioned (`-v1`) — เป็นภาพประกอบ ไม่ใช่รูปอาหารจริงจึงไม่ขัดกติกาข้อมูลจริง

### 4.3 ดีลเด็ดวันนี้ (Phase 3) — **ซ่อน** บนเว็บข้อมูลจริง
- แอปใช้ข้อมูลตัวอย่าง ยังไม่มีแหล่งข้อมูลจริง (DECISIONS 2026-10-17 "ยังเปิดอยู่: แหล่งข้อมูลจริงของดีลเด็ด") → ไม่ render อะไรเลย (ไม่มีหัวข้อ, ไม่มี skeleton) จนกว่า Founder ตอบข้อ 14-Q1
- ถ้า Founder เลือกให้ใช้โปรร้านจริง: ใช้สเปกการ์ด `ZokyDealCard` (ข้อ 5.6) แทนภาพประกอบด้วยรูปปกร้านจริง 1:1 และไม่มีป้าย "ตัวอย่าง"

### 4.4 ร้านอาหารแนะนำ (Phase 4) — ขึ้นกับคำถาม 14-Q2
- ข้อมูล featured (`food_active_featured_stores`, งาน #1135) ยังไม่อยู่บน production → ตามแอป: **ไม่มีข้อมูล = ซ่อน section**
- ถ้า Founder เลือก ก: แสดงแถวแนวนอนหัวข้อ **"ร้านยอดนิยม"** ใช้ลำดับ `popularStores` เดิมของเว็บ (ยอดส่งสำเร็จจริง `delivered_order_count` → คะแนน → ชื่อ) แสดงเมื่อมี ≥ 2 ร้าน (เงื่อนไขเดิม) "ดูทั้งหมด" เปิด sheet รายการร้าน (เดิม `browse === "popular"`)
- การ์ด: สเปก `ZokyRecommendedStoreCard` (ข้อ 5.5)

### 4.5 ฟีเจอร์เว็บเดิมที่อยู่บน Home (ไม่มีในดีไซน์แอป)
- **โปรโมชันและข่าวสาร** (`FoodPromotionCenter`, ข้อมูลจริง `food_notifications` + การตั้งค่า marketing): วางใต้การ์ด hero (เว้นบน 16) เป็นการ์ดพื้น `--zk-soft-pink` radius 16 padding 14 16; ไอคอน Bell/BellRing 22 `--zk-brand-deep`; ข้อความ 16/700 ink; ตัวเลขยังไม่อ่าน = badge `--zk-brand-deep` ตัวขาว; "ดูทั้งหมด/ปิด" 14/700 `--zk-brand-deep`; ปุ่มทั้งแถบสูง ≥ 48; เนื้อหาที่ขยายใช้ markup เดิม — logic ไม่เปลี่ยน
- **ลิงก์ WYNOS Social** (`fx-social-promo`): ไว้ล่างสุดของ Home เป็นแถวขาว ขอบ `--zk-border-subtle` radius 16 ไม่ใช้สีชมพูทึบ (ไม่แย่ง CTA หลัก)
- พื้นที่ว่างท้ายหน้า = ความสูง nav + bottom offset + 8 (แถวสุดท้ายไม่โดน nav บัง)

---

## 5. หน้า Food (mobile 390/430) — `FoodHomeScreen`

หน้าเต็มจอ **ไม่มี bottom nav** (W4) ลำดับ:

### 5.1 Header ชมพูอ่อน — `ZokyFoodHeader`
- พื้น gradient แนวตั้ง: `#FFEFF5` ตั้งแต่บนสุด (ใต้ status bar) ถึงใต้แถวที่อยู่ → `#FFF7FA` → `#FFFFFF` ที่กึ่งกลางช่องค้นหา; ไม่มีรอยต่อ/แผ่นขาว; `theme-color` ของหน้า Food = `#FFEFF5` (status bar ตัวเข้ม) — คืนค่าเมื่อออกจากหน้า
- **แถวบน** สูงขั้นต่ำ 48 padding ข้าง 4 (`padding-top: calc(env(safe-area-inset-top) + 4px)`):
  1. ปุ่มกลับ 44×44 ไอคอน Lucide `ArrowLeft` 24 ink (เว็บใช้ ArrowLeft ตาม design system 11.2) `aria-label="กลับ"`
  2. บล็อกที่อยู่ชิดซ้าย (ยืดเต็มที่เหลือ) ปุ่มเดียว สูง ≥ 44: บรรทัดบน "จัดส่งที่" 13/600 `--zk-text-secondary`; บรรทัดล่าง ชื่อที่อยู่ 17/700 ink ตัดด้วย `…` + caret ▾ 20 `--zk-brand-deep` — ชื่อใช้ `place_name || label` ของที่อยู่หลัก (เดิม) ไม่มีที่อยู่ = "เลือกที่อยู่จัดส่ง"; แตะ = ไปแท็บบัญชี (เดิม); `aria-label="จัดส่งที่ {ชื่อ}"`
  3. ปุ่ม "ร้านโปรด" white glossy วงกลม **38** (กด 44) + หัวใจ 3D 22, เงา `--zk-shadow-control-pale`
  4. ปุ่ม "คูปองส่วนลด" white glossy วงกลม 38 (กด 44) + ตั๋ว 3D 26 → sheet "รวมโค้ดลดเพิ่ม" (เดิม `browse === "promos"`; ไม่มีโค้ด = "ยังไม่มีโค้ดส่วนลด")
- **ชิป จัดส่ง | รับเองที่ร้าน: ไม่ render บนเว็บ** (W3, CTO P3) — ไม่เว้นที่ว่างแทน; ป้าย "รับเองได้", ข้อความ "รับเองที่ร้าน ▾" และการซ่อน "ส่งฟรี" ในโหมดรับเองก็ไม่มีบนเว็บ
- **ช่องค้นหา** (ระยะข้าง 16, เว้นบน 2 จากแถวบน, ล่าง 12 + 4): `<input type="search">` จริง (ไม่ใช่ปุ่มแบบแอป เพราะเว็บค้นหาในหน้าเดิม) สูง 48 radius 20 พื้นขาว ขอบ 1px `--zk-border-subtle` เงา `--zk-shadow-search` padding 0 8 0 16; ไอคอน Lucide `Search` 24 `--zk-brand-deep` + เว้น 10; placeholder "ค้นหาร้านอาหารหรือเมนู" 16 `--zk-text-secondary`; ตัวหนังสือ 16 (กัน iOS ซูม); ปุ่มล้าง (มีเมื่อพิมพ์) มองเห็น 30 กดได้ 44 `aria-label="ล้างการค้นหา"`; focus: ring 2px `--zk-brand`; `enterKeyHint="search"`, `autoComplete="off"`, `aria-label` = placeholder
- **Sticky ตอนเลื่อน**: แถวบนเลื่อนหายไปตามปกติ ส่วนช่องค้นหา `position: sticky; top: 0` บนพื้น `#FFF7FA → #FFFFFF` padding `calc(env(safe-area-inset-top) + 6px) 16px 10px` (CSS ล้วน ไม่ต้องใช้ JS — แทน fold animation ของแอปที่ขับด้วย scroll offset)

### 5.2 หมวดอาหาร 4 วง — **ซ่อน** (ยังไม่มีข้อมูลจริง ดู 14-Q3)
- ถ้า Founder อนุมัติให้ใช้หมวดจริงภายหลัง: วงกลม `clamp(52px, 62% ของ (ความกว้างคอลัมน์−32)/4, 68px)` พื้น `#FDEEF3` + label 15 ink บรรทัดเดียว, 4 วงเต็มความกว้างแล้วเลื่อนแนวนอน

### 5.3 สั่งอีกครั้ง (ฟีเจอร์เว็บเดิม ไม่มีในแอป)
- ตำแหน่ง: ใต้ header (ที่เดิมของหมวดอาหาร) แสดงเมื่อ `filter === "all"`, ไม่ได้ค้นหา และมีร้านจากออเดอร์จริง (เงื่อนไขเดิม)
- หน้าตาใช้ภาษาเดียวกับหมวดอาหาร 4 วงของแอป: หัวข้อ section (ข้อ 5.7) "สั่งอีกครั้ง" + "ดูทั้งหมด" (sheet เดิม) → แถวเลื่อนแนวนอน padding 8 16, ช่องละ `(ความกว้างคอลัมน์ − 32) / 4`; วงกลม `clamp(52px, 62%, 68px)` พื้น `#FDEEF3` ใส่รูปปกร้านจริง `object-fit: cover` (ไม่มีรูป = Lucide `UtensilsCrossed` 24 `--zk-text-secondary`); ชื่อร้าน 13/600 ink ไม่เกิน 2 บรรทัด กึ่งกลาง; สูงสุด 6 ร้าน (เดิม)

### 5.4 โค้ดลดเพิ่มสำหรับคุณ — `ZokyFoodCouponSection`
- ข้อมูล: `promoStores` เดิม (ร้านในไดเรกทอรีที่มี `promo_name`) — ไม่มี = ไม่มี section; โหลดอยู่ = skeleton (หัวข้อ 55%×20 + การ์ด สูง 76 radius 16); ไดเรกทอรีโหลดไม่ได้ = ซ่อน (error อยู่ที่รายการร้าน)
- หัวข้อ "โค้ดลดเพิ่มสำหรับคุณ" + "ดูทั้งหมด" → sheet "รวมโค้ดลดเพิ่ม" (การ์ดเรียงลง)
- แถวเลื่อนแนวนอน แสดงสูงสุด 4 ใบ กว้าง 88% ของ (คอลัมน์ − 32) (ใบเดียว = 100%) ระยะห่าง 12
- การ์ด: พื้น `#FDEEF3` radius 16 padding 14 12 14 16; ซ้าย ไอคอนเส้น 30 `--zk-brand-deep` (Lucide `Bike` ถ้า `promo_type === "free_delivery"` ไม่งั้น `Ticket`) เว้น 12; กลาง: ป้ายโปร 18/700 ink (`foodPromoLabel` เดิม: "ส่งฟรี" / "ลด 20%" / "ลด ฿30" / ชื่อโปร) + บรรทัดรอง 15 `--zk-text-secondary` = "{ชื่อร้าน} · เมื่อสั่งครบ ฿X" (ถ้ามีขั้นต่ำ) หรือ "{ชื่อร้าน} · {promo_name}" — ขึ้นบรรทัดใหม่ได้ ห้ามตัด; ขวา: ปุ่ม "เก็บโค้ด"
- ปุ่ม "เก็บโค้ด"/"เก็บแล้ว": pill สูง ≥ 44 padding 0 16, 16/700; ยังไม่เก็บ = พื้น `--zk-brand-deep` ตัวขาว; เก็บแล้ว = พื้นขาว ขอบ 1.5px `--zk-brand-line` ไอคอน `Check` 18 + ตัว `--zk-brand-deep`; `aria-pressed` (เดิม) — logic localStorage `wynos-food-collected-promos-v1:{userId}` เดิม
- การ์ดแคบหรือขยายตัวหนังสือ (กว้าง < 300px × text scale): ปุ่มย้ายลงใต้ข้อความ ชิดซ้าย (ไม่ให้ปุ่มตะกร้าลอยด้านขวาบัง)

### 5.5 ร้านอาหารทั้งหมด + ตัวกรอง
- หัวข้อ "ร้านอาหารทั้งหมด" (ข้อ 5.7) ขวาเป็นปุ่ม "ตัวกรอง" (ไอคอน Lucide `SlidersHorizontal` 22 + 16/600 `--zk-brand-deep`, กด ≥ 44) → sheet "ตัวกรอง" รายการเลือกได้ 1 (แถวสูง ≥ 48, ที่เลือก = ตัวหนา `--zk-brand-deep` + `Check`)
- แถบชิป **sticky** (ติดใต้ช่องค้นหาเมื่อเลื่อนถึง; พื้นขาว เส้นล่าง `--zk-border-subtle` เมื่อมีเนื้อหาเลื่อนอยู่ใต้) ลำดับตามแอป: **ทั้งหมด · ใกล้ฉัน · ส่งฟรี · มีโปรฯ** (+ "เรตติ้ง 4.5+" แสดงเป็นชิปเฉพาะตอนถูกเลือกจาก sheet) — เงื่อนไขกรองใช้ของเว็บเดิมทุกตัว (`free` = `promo_type === "free_delivery"`, `near` ≤ 3 กม., `rating` ≥ 4.5) ไม่เปลี่ยน logic
  - ชิปไม่เลือก: พื้น `--zk-chip` ตัว ink 14/600 สูง 40 (กด 44); เลือก: พื้น `--zk-brand-deep` ตัวขาว; `aria-pressed`; กลุ่ม `role="group" aria-label="ตัวกรองร้านอาหาร"`
- ชิปกรองเฉพาะรายการร้าน (ไม่ซ่อนโค้ดลด/สั่งอีกครั้งอีกต่อไป ยกเว้นตามเงื่อนไข 5.3)
- เรียงรายการ: ร้านเปิดก่อน แล้วตามระยะใกล้ (`nearbyStores` เดิม) — "ร้านใกล้คุณ" เดิมรวมเข้ามาเป็นรายการนี้ (แสดงครบทุกร้าน ไม่ตัดที่ 4)
- **แถวร้าน** (`ZokyFoodStoreRow`) — ทั้งแถวเป็นปุ่มเดียว padding 8 16:
  - ซ้าย: รูปปก **1:1** ขนาด `min(110px, 28vw)` radius 16 `object-fit: cover`, `loading="lazy"`; ไม่มีรูป = พื้น `--zk-sunken` + Lucide `UtensilsCrossed` 30 `--zk-text-secondary` (ไม่ใช้ภาพอาหาร 3D ของแอปเพื่อไม่ให้ดูเหมือนเมนูจริงของร้าน); **ไม่มีหัวใจบนรูป**
  - เว้น 14 → ขวา:
    - ชื่อร้าน 18/700 ink ขึ้นบรรทัดได้ (ไม่ตัด)
    - meta 15 `--zk-text-secondary` lh 1.35: `{หมวดแรก หรือ "อาหาร"} · ★3D16 {คะแนน 1 ตำแหน่ง}` (เฉพาะเมื่อ `rating_count > 0` และ `rating_average > 0`; ถ้าคะแนน ≤ 0 = "ร้านใหม่" ตามเว็บเดิม) `· {ETA}` (เฉพาะ W6) `· {ระยะ}` (`foodDistanceLabel` เดิม เมื่อมีพิกัด) `· ค่าส่ง ฿X` (ข้อมูลเดิมของเว็บที่แอปไม่มี — คงไว้) ใช้ no-break space ใน "20–30 นาที", "1.9 กม."
    - ป้าย (เว้นบน 6, ห่างกัน 4, ขึ้นบรรทัดได้) pill padding 2 8 ตัว 12/700: ปิดอยู่ = พื้น ink 80% ตัวขาว + `Clock3` 13; โปร = พื้น `--zk-brand-deep` ตัวขาว (`foodPromoLabel`); โฆษณา = พื้น ink 72% ตัวขาว
    - เว้น 6 → "ดูเมนู" 16/600 `--zk-brand-deep` + ลูกแก้วลูกศร 3D 22 (ตกแต่ง)
  - `aria-label` รวม เช่น "ร้านส้มตำป้าแดง, อีสาน, คะแนน 4.6, ส่งประมาณ 25–35 นาที, ระยะ 1.9 กม., ค่าส่ง 15 บาท, ร้านปิดอยู่, โปรโมชัน ลด 20%, โฆษณา, ดูเมนู" (อ่านเฉพาะสิ่งที่แสดง)
  - กด: พื้นแถว `--zk-chip` ชั่วคราว / scale .97 ตาม motion; แตะ = `onPick(store, "home")` เดิม (บันทึก ad click)
- ผลการค้นหา (พิมพ์แล้ว): ซ่อน 5.3–5.5 แสดงหัวข้อ `ผลการค้นหา “{คำ}”` + แถวร้านแบบเดียวกัน (`onPick(store, "search")`); ไม่พบ = empty state "ไม่พบ “{คำ}” ใกล้คุณ" / "ลองค้นด้วยชื่อร้าน ชื่อเมนู หรือคำที่สั้นลง" (copy เดิม)

### 5.6 ปุ่มตะกร้าลอย — `ZokyFoodCartButton`
- `position: fixed` มุมขวาล่างของคอลัมน์: `right: 16px` (ภายในคอลัมน์), `bottom: calc(env(safe-area-inset-bottom) + 16px)`
- ตะกร้าว่าง: วงกลม 56 พื้น `--zk-brand-deep` ไอคอน `ShoppingBag` 26 ขาว; มีของ: pill สูง 56 padding 0 20 = ไอคอน + "{จำนวน} · ฿{ยอด}" 16/700 ขาว tabular (เกิน 99 = "99+"); เงา `--zk-shadow-brand`; กด = pressed `--zk-berry`
- แตะ = แท็บตะกร้าเดิม (มี empty state อยู่แล้ว); `aria-label` = "ตะกร้า" หรือ "ตะกร้า {n} รายการ รวม {ยอด} บาท"; การเปลี่ยนยอดประกาศผ่าน live region แยก (visually hidden, `aria-live="polite"`) ไม่ใส่ live บนปุ่มเอง
- หน้าเว้นพื้นที่ท้าย = 56 + 32 + safe-area ไม่ให้ปุ่มบังแถวสุดท้าย
- ยอดใช้ `cartSubtotal` เดิม (ราคาจริงฝั่ง client; ราคา/สิทธิ์จริงยัง validate ฝั่ง server ตอนสั่ง)

### 5.7 หัวข้อ section (ใช้ร่วม Home/Food) — `ZokyHomeSectionHeader`
- padding ซ้าย 16 ขวา 8; หัวข้อ `<h2>` 20/700 ink; "ดูทั้งหมด" 14/700 `--zk-brand-deep` + chevron 18 (Lucide `ChevronRight` stroke 2.4) พื้นที่กด ≥ 44×44 padding 0 8; `aria-label` = "ดูทั้งหมด {หัวข้อ}"

---

## 6. ไอคอน 3D, ไอคอน nav และผิวมันวาวบนเว็บ (inline SVG / CSS)

ทำเป็น component เล็ก ๆ (`Zoky3DIcon`, `ZokyNavIcon`) render `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">` ขนาดตาม prop — ตัวเลขข้างล่างแปลงจาก painter ของ Flutter ที่ s = 24 แล้ว (ค่า blur ของ Flutter `MaskFilter.blur` เป็น sigma = `stdDeviation` ของ SVG) **id ใน `<defs>` ต้อง unique ต่อ instance** (ใช้ `useId()`)

### 6.1 `Zoky3DIcon` — สูตรแสงเดียว (แสงจากซ้ายบน)

ชั้นต่อ glyph (palette pink: top `#FF6BAA` bottom `#E5135D` shade `#9E0E3E` shadow `#C2185B`; gold: `#FFD45C` / `#F59E0B` / `#B45309` / `#C2700A`):
1. เงาตก: path เดียวกัน `transform="translate(0.48 1.44)"` fill shadow opacity .30 + `feGaussianBlur stdDeviation=0.96`
2. ตัว: fill `linearGradient` แนวตั้ง (`x1=0 y1=0 x2=0 y2=1`, objectBoundingBox) top → bottom
3. เงาในขวาล่าง + ขอบแสงซ้ายบน: ใช้ filter บนตัว
   ```xml
   <filter id="inner" x="-20%" y="-20%" width="140%" height="140%">
     <feOffset in="SourceAlpha" dx="-1.68" dy="-1.92" result="up"/>
     <feComposite in="SourceAlpha" in2="up" operator="out" result="cres"/>
     <feGaussianBlur in="cres" stdDeviation="1.08" result="cresB"/>
     <feFlood flood-color="{shade}" flood-opacity=".38"/>
     <feComposite in2="cresB" operator="in"/>
     <feComposite in2="SourceAlpha" operator="in" result="shade"/>
     <feOffset in="SourceAlpha" dx="0.72" dy="0.96" result="dn"/>
     <feComposite in="SourceAlpha" in2="dn" operator="out" result="rim"/>
     <feGaussianBlur in="rim" stdDeviation="0.48" result="rimB"/>
     <feFlood flood-color="#fff" flood-opacity=".55"/>
     <feComposite in2="rimB" operator="in"/>
     <feComposite in2="SourceAlpha" operator="in" result="light"/>
     <feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="shade"/><feMergeNode in="light"/></feMerge>
   </filter>
   ```
4. ไฮไลต์ (clip ด้วยรูป glyph): วงรีขาว opacity .70 blur `stdDeviation=0.6` + แกนวงรีขาว .90 (กว้าง/สูง 45%, เลื่อนซ้าย 12%) ไม่ blur

Glyph (s = 24):

| Glyph | path | ไฮไลต์ (cx, cy, w, h, หมุน) | ใช้ที่ |
|---|---|---|---|
| heart | `M12 20.88 C4.8 16.08 1.2 12 1.68 7.92 C2.16 4.08 5.28 2.4 7.92 2.64 C10.08 2.88 11.28 4.08 12 5.52 C12.72 4.08 13.92 2.88 16.08 2.64 C18.72 2.4 21.84 4.08 22.32 7.92 C22.8 12 19.2 16.08 12 20.88Z` | 6.96, 6.48, 5.76, 3.12, −25.8° | ปุ่มร้านโปรด |
| sparkle | `M12 1.2 Q14.4 9.6 22.8 12 Q14.4 14.4 12 22.8 Q9.6 14.4 1.2 12 Q9.6 9.6 12 1.2Z` | 10.32, 9.12, 2.88, 4.8, +28.6° | pill "FOOD DELIVERY" |
| star (gold) | polygon 10 จุด: `12,0.96 14.96,7.92 22.5,8.59 16.79,13.56 18.49,20.93 12,17.04 5.51,20.93 7.21,13.56 1.5,8.59 9.04,7.92` มุมมน (ใช้ `stroke` สีเดียวกับ gradient 1.2 + `stroke-linejoin="round"` แทน quadratic rounding ได้) | 9.6, 8.64, 4.8, 2.88, −25.8° | คะแนนร้าน |
| ticket | ทั้งกลุ่ม `transform="rotate(-14.9 12 12)"`: `M4.32 6.48 H19.68 A1.92 1.92 0 0 1 21.6 8.4 V9.96 A2.04 2.04 0 0 0 21.6 14.04 V15.6 A1.92 1.92 0 0 1 19.68 17.52 H4.32 A1.92 1.92 0 0 1 2.4 15.6 V14.04 A2.04 2.04 0 0 0 2.4 9.96 V8.4 A1.92 1.92 0 0 1 4.32 6.48Z` + รอยปรุ `M15.36 8.16v1.44 M15.36 11.28v1.44 M15.36 14.4v1.44` (stroke ขาวนูน กว้าง 1.8) | 7.2, 9.12, 6.24, 2.4, −14.9° | ปุ่มคูปองส่วนลด |
| arrowRight | ลูกแก้ว `circle cx=12 cy=11.52 r=10.56` + ลูกศร `M7.44 11.52H16.08 M12.48 7.92L16.08 11.52L12.48 15.12` stroke 2.64 round cap/join ไล่ขาว `#FFFFFF → #FFE0EC`, ใต้ลูกศรมีสำเนาเลื่อนลง 0.84 สี `#8E0F38` .35 blur .29 (นูน) | 8.16, 5.28, 8.64, 3.84, −25.8° | ท้ายปุ่ม "ค้นหาของอร่อย", "ดูเมนู" |

Fallback: ถ้า browser ไม่รองรับ filter (หายาก) ตัวไอคอนยังเป็น gradient ทึบที่อ่านรูปได้ — ยอมรับได้

### 6.2 ผิวมันวาว (CSS)

- **Brand glossy surface** (header Home, การ์ด hero): `background: linear-gradient(180deg, #F93384 0%, #F72C7E 35%, #EE226E 100%)`
  - gloss band: overlay `<svg preserveAspectRatio="none">` ด้านบน สูง = glossHeight (px คงที่: header `safe-top + 28`, hero 54) inset 4px (header 0) path ตาม `ZokyGlossPainter.glossPath`: ขอบบนตามมุมโค้ง ขอบล่างโค้งขึ้นไปทางขวา (`…L{w−i} {h·0.72} Q{w·0.55} {h·0.5} {i} {h}Z`) fill `linearGradient` ขาว opacity glossOpacity → 0 (header .07, hero .35)
  - rim (hero เท่านั้น): `box-shadow: inset 0 1px 0 rgb(255 255 255 / 25%), inset 0 -1px 0 rgb(255 255 255 / 8%)`
  - เงา hero `--zk-shadow-brand-surface`
- **White glossy control** (ปุ่มหัวใจ/คูปอง/ตะกร้า, pill, ปุ่มค้นหาของอร่อย): `background: linear-gradient(180deg, #FFFFFF, #FFF1F6)`; rim `box-shadow: inset 0 1px 0 #fff, inset 0 -1px 0 rgb(249 192 222 / 40%)` + เงาตามพื้น (`--zk-shadow-control` บนชมพู / `--zk-shadow-control-pale` บน header ชมพูอ่อน); วงกลมปุ่มมี gloss `::before` inset 3px สูง 50% ขาว .9 → 0
- **Frosted disc** (หลังภาพเบนโตะ): `linear-gradient(135deg, rgb(255 255 255 / 34%), rgb(255 255 255 / 14%))` + gloss .30 สูง 46% + rim `inset 0 1px 0 rgb(255 255 255 / 45%)`
- ห้ามใส่ gloss/gradient ให้ปุ่ม primary, ชิป, การ์ดโค้ด, แถวร้าน (แบน)

### 6.3 `ZokyNavIcon` (4 แท็บ, grid 24, เส้น 1.632 = 6.8%, round cap/join)

| แท็บ | outline (ไม่เลือก, stroke `#6B6B76`) |
|---|---|
| หน้าหลัก | `M9.791 3.315 Q12 1 14.209 3.315 L21.779 11.249 Q22.4 11.9 21.5 11.9 L20.6 11.9 Q20.1 11.9 20.1 12.4 L20.1 19 Q20.1 21.4 17.7 21.4 L15 21.4 Q14.1 21.4 14.1 20.5 L14.1 16.8 Q14.1 14.7 12 14.7 Q9.9 14.7 9.9 16.8 L9.9 20.5 Q9.9 21.4 9 21.4 L6.3 21.4 Q3.9 21.4 3.9 19 L3.9 12.4 Q3.9 11.9 3.4 11.9 L2.5 11.9 Q1.6 11.9 2.221 11.249Z` |
| ออเดอร์ | กระดาน `M9.3 3.4H6.7A3 3 0 0 0 3.7 6.4V19.2A3 3 0 0 0 6.7 22.2H17.3A3 3 0 0 0 20.3 19.2V6.4A3 3 0 0 0 17.3 3.4H14.7` + ตัวหนีบ `rect x=9.3 y=2 w=5.4 h=3.4 rx=1.4` + เส้น `M8.4 10H12.6M8.4 13.4H15.6M8.4 16.8H13.9` |
| ข้อความ | `M8.204 19.965A10.1 9.25 0 1 0 4.413 17.396L2.421 20.619Q2 21.3 2.782 21.132Z` + จุด fill r 1.35 ที่ (7.45, 11.45) (12.15, 11.45) (16.85, 11.45) |
| บัญชี | หัว `circle 12,6.75 r4.35` + ตัว `M9.2 13.5H14.8A5.2 5.6 0 0 1 20 19.1V19.65A2.6 2.6 0 0 1 17.4 22.25H6.6A2.6 2.6 0 0 1 4 19.65V19.1A5.2 5.6 0 0 1 9.2 13.5Z` |

**ที่เลือก (ทึบชมพู 3D)**: รูปเดียวกัน fill + stroke 1.632 แล้ว
- body `linearGradient` แนวตั้ง `#F4368D → #D61256`
- เงาใน: ทับด้วย fill `linearGradient` (จาก 40% 40% ไป 100% 100%) `#AF1341` 0 → `#991636` .40
- ไฮไลต์: `radialGradient cx=.29 cy=.21 r=.55` ขาว .80 (0) / .25 (35%) / 0 (100%)
- เงาตก `#C2185B` .32 เลื่อนลง 1.44 blur `stdDeviation≈1.85`
- ช่องเจาะ (ใช้ `<mask>`): บ้าน = ประตูเปิดอยู่แล้วในรูป; ออเดอร์ = ช่องว่างรอบตัวหนีบ (`rect x=7.634 y=0.334 w=8.732 h=6.732 rx=3.066` สีดำใน mask) + ช่องในตัวหนีบ (`rect 10.7,3.15 w2.6 h1.1 rx .55`) + เส้น 3 เส้น แล้ววาดช่องในตัวหนีบและเส้นเป็นสีขาวทับ; ข้อความ = จุด 3 จุดเจาะแล้ววาดจุดขาวทับ; บัญชี = ทึบล้วน
- สลับ outline ↔ ทึบ: fade + scale .85→1 200ms (ไม่มีเมื่อ reduced motion)

### 6.4 ไอคอนเส้นทั่วไป
ใช้ `lucide-react` ที่มีอยู่แล้ว (ArrowLeft, Search, X, SlidersHorizontal, ChevronRight, Check, Ticket, Bike, Clock3, ShoppingBag, UtensilsCrossed, WifiOff, CircleAlert, RefreshCw, Bell/BellRing) stroke 1.9–2.4 — ไม่ต้องวาดใหม่

---

## 7. Bottom nav, ผู้ใช้ guest และสิ่งที่ซ่อน

### 7.1 Bottom nav (แทน `fx-nav`) — `ZokyBottomNav`
- เหตุผลที่คงไว้: เว็บมี nav 4 แท็บ (หน้าหลัก/ออเดอร์/ข้อความ/บัญชี) อยู่แล้วและเป็นทางเดียวไปแท็บอื่น; แอปอนุมัติ capsule นี้แล้ว (Phase 5) → เปลี่ยนแค่หน้าตา logic `FoodNav` เดิม (`onTab`, `aria-current`, badge ออเดอร์) คงเดิม
- capsule ขาว สูง 64 radius 32, padding ใน 6, กว้าง = คอลัมน์ − 32 (สูงสุด 448), กึ่งกลางคอลัมน์, ห่างขอบล่าง `max(env(safe-area-inset-bottom), 12px)`, เงา `--zk-shadow-nav`
- ช่องกว้างเท่ากัน; ไม่เลือก: ไอคอน outline 26 + label 13/500 `#6B6B76`; เลือก: capsule `#FFEDF4` เต็มช่อง (ห่างขอบบน/ล่าง 6) เลื่อนระหว่างแท็บ 220ms + ไอคอนทึบ 3D + label 13/700 `#D61256` (4.58:1)
- badge ออเดอร์ที่กำลังดำเนินการ (ข้อมูลจริง `activeCount` เดิม): วงกลมพื้น `#B3261E` ตัวขาว 11/700 ขอบขาว 2px ยึดมุมขวาบนของไอคอน (left = 18px, top = −5px) เกิน 99 = "99+" (เดิม 9+ — ตามสเปก 9.8 PROPOSED; ถ้า Founder ไม่อยากเปลี่ยนให้คง 9+ ได้) `aria-label="{n} ออเดอร์ที่กำลังดำเนินการ"` อ่านต่อท้ายชื่อแท็บ
- แสดงบน: Home, ออเดอร์, ข้อความ, บัญชี, ตะกร้า (เหมือนเดิม) | **ไม่แสดงบน: หน้า Food** | หน้าร้าน: คงพฤติกรรมเดิม (ยังไม่ redesign)
- ทุกหน้าที่มี nav เว้นพื้นที่ท้าย `64 + bottomOffset + 8`

### 7.2 สิ่งที่ซ่อนบนเว็บข้อมูลจริง (ไม่มีของตัวอย่างบน production)

| ของในแอป | บนเว็บ | หมายเหตุ |
|---|---|---|
| ชิป จัดส่ง / รับเองที่ร้าน, "รับเองที่ร้าน ▾", ป้าย "รับเองได้" | ซ่อน (ไม่ render) | CTO P3 — backend ไม่มี pickup; เปิดเมื่องาน pickup จริงผ่าน workflow |
| ดีลเด็ดวันนี้ (การ์ดตัวอย่าง + "ข้อมูลตัวอย่าง ยังไม่ใช่โปรโมชันจริง") | ซ่อน | 14-Q1 |
| ร้านอาหารแนะนำ (featured) | ซ่อน / แทนด้วย "ร้านยอดนิยม" | 14-Q2 |
| หมวดอาหาร 4 วง | ซ่อน | 14-Q3 |
| แบนเนอร์ | ไม่มี (งาน #1133 ยังไม่ผ่าน acceptance) | ไม่อยู่ในหน้า Food ที่อนุมัติอยู่แล้ว |
| ป้าย "ตัวอย่าง", ชื่อ "(ร้านตัวอย่าง)", ที่อยู่ตัวอย่าง, "โหมดสาธิต", ภาพอาหาร 3D แทนรูปร้าน | ไม่มี | ข้อมูลจริงเท่านั้น; ถ้าโค้ดเว็บเผลอได้ `isDemo` ให้ถือเป็น bug |
| ETA เมื่อร้านไม่ได้ตั้งเวลาเตรียม | ไม่แสดง | W6 |
| คะแนนเมื่อไม่มีรีวิว | ไม่แสดงดาว (แสดง "ร้านใหม่" ตามเดิมเมื่อคะแนน ≤ 0) | |
| sheet "ร้านโปรด — เร็ว ๆ นี้" ของแอป | ใช้ sheet ร้านโปรดจริงของเว็บ | ข้อมูลจริงมีอยู่แล้ว |

### 7.3 ผู้ใช้ที่ยังไม่ล็อกอิน (`FoodGuestBrowse`)
- ใช้ Home + Food หน้าตาเดียวกัน ข้อมูลจาก `food_public_catalog` เท่านั้น (ห้ามเรียก endpoint ที่ต้องล็อกอิน)
- Home: ปุ่มหัวใจ → แทนด้วยปุ่ม white glossy pill "เข้าสู่ระบบ" (16/700 `--zk-brand-deep`, สูง ≥ 44) → `/food/login`; ไม่มีโปรโมชันและข่าวสาร; ไม่มีร้านยอดนิยม (ไม่มี `delivered_order_count` ใน public catalog); ข้อความพื้นที่ให้บริการเดิม "ให้บริการในพื้นที่มหาสารคาม" วางใต้การ์ด hero เป็นบรรทัด 13 `--zk-text-secondary` + `MapPin`
- Food: แถวบนมี ← กลับ + ข้อความ "ให้บริการในพื้นที่มหาสารคาม" แทนบล็อกที่อยู่ ไม่มีหัวใจ/คูปอง; ช่องค้นหา (กรองฝั่ง client เดิม); ไม่มีโค้ดลด/สั่งอีกครั้ง/ตัวกรองที่ใช้ข้อมูลที่ guest ไม่มี (แสดงเฉพาะรายการ); แถวร้านแสดงชื่อ, "{n} เมนู · ค่าส่ง ฿X", ป้ายปิดอยู่; ปุ่มตะกร้าลอยเปิดตะกร้า guest เดิม ("เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ")
- ไม่มี bottom nav (เหมือนเดิม)
- CTO ตัดสินว่าทำพร้อมหน้า signed-in หรือรอบถัดไป

---

## 8. Responsive

- อ้างอิง 390 และ 430 (ทดสอบเพิ่ม 375 และ 320)
- **คอลัมน์กลาง**: เนื้อหาทั้งหมด `max-width: 480px; margin-inline: auto` บนทุกความกว้าง; ≥ 481px พื้นหลัง header (ชมพู/ชมพูอ่อน) และแผ่นขาวยาวเต็มจอ ส่วนโลโก้/ปุ่ม/ช่องค้นหา/การ์ด อยู่ในคอลัมน์; พื้นหน้าขาวเต็มจอ ไม่มีกรอบ/เงาคอลัมน์
- ความกว้างที่คิดจาก "จอ" ในแอป (wordmark 36%, การ์ดแนวนอน 40–56%, ขนาดวงกลม, รูปแถวร้าน 28%) ให้คิดจากความกว้างคอลัมน์ `min(100vw, 480px)` (ใช้ container query `cqw` หรือ CSS var `--zk-col` — ห้ามใช้ `vw` ตรง ๆ บน iPad)
- แถวเลื่อนแนวนอนตัดที่ขอบคอลัมน์ มี padding 16 ทั้งสองข้าง, ซ่อน scrollbar, รองรับ scroll ด้วย trackpad/ลูกศร
- nav, ปุ่มตะกร้าลอย, toast จัดตามคอลัมน์ (ไม่ชิดขอบจอ iPad)
- iPad แนวนอน/desktop: layout เดิม (คอลัมน์ 480) — ไม่ทำ 2–3 คอลัมน์ (กริด 3 คอลัมน์ที่ ≥ 680px ของเว็บเดิมไม่ใช้ในสองหน้านี้)
- ≤ 359px: รูปแถวร้านใช้ `28vw` (~90), ช่องห่างชิป 6
- ข้อเสนอ: ใช้คอลัมน์ 480 ที่ shell (`.fx-app`) ทั้งแอป เพื่อไม่ให้ความกว้างกระโดดเมื่อสลับแท็บ — CTO ตัดสิน (ไม่เปลี่ยนฟังก์ชัน)

---

## 9. States

| สถานการณ์ | Home | Food |
|---|---|---|
| โหลดครั้งแรก (snapshot ยังไม่มา) | `FoodLoading` ใหม่: header ชมพู + wordmark จริง + skeleton การ์ด hero (radius 24 สูง ~200) + skeleton แถวการ์ด 3 ใบ; `aria-busy` + `aria-label="กำลังโหลด ZOKY"` | — |
| ไดเรกทอรีกำลังโหลด | (ร้านยอดนิยม ถ้ามี) skeleton การ์ด 3 ใบ กว้างตามการ์ด สูง = กว้าง + 64 | skeleton: วงกลมสั่งอีกครั้ง 4 วง, การ์ดโค้ด 1 ใบ, แถวร้าน 3 แถว (สี่เหลี่ยม 110 r16 + เส้น 18 / 14 (70%) / 14 (35%)) |
| ไดเรกทอรีโหลดไม่ได้ | ซ่อน section ที่พึ่งไดเรกทอรี | error state ในตำแหน่งรายการร้าน: วงกลม 108 `--zk-error-container` + `WifiOff` (offline) หรือ `CircleAlert` 44 `--zk-error` + หัวข้อ 22/700 "เชื่อมต่อไม่ได้" + "ตรวจสอบ Wi-Fi หรือเน็ตมือถือ แล้วลองอีกครั้ง ตะกร้าของคุณยังอยู่" + ปุ่ม primary "ลองอีกครั้ง" (กลับไปแสดง skeleton); `role="alert"` — **หมายเหตุ implement**: `fetchFoodStoreDirectory` คืน `null` ทั้งตอนโหลดและตอน error ทำให้เว็บเดิมค้าง skeleton; ต้องแยกสถานะ error |
| ดึงรีเฟรชล้มเหลว (มีข้อมูลอยู่แล้ว) | คงเนื้อหาเดิม + toast "เชื่อมต่อไม่ได้" | เหมือนกัน |
| ไม่มีร้านเลย | — | empty: วงกลม 108 `#FDEEF3` + `Store` 44 `--zk-brand` + "ยังไม่มีร้านในพื้นที่นี้" + "ZOKY กำลังขยายพื้นที่ให้บริการ ลองเปลี่ยนที่อยู่จัดส่ง หรือกลับมาใหม่เร็วๆ นี้" + ปุ่ม primary "เปลี่ยนที่อยู่จัดส่ง" (เดิม → แท็บบัญชี) |
| ตัวกรองไม่มีผล | — | empty: "ไม่มีร้านที่ตรงกับตัวกรองนี้" + ปุ่ม "ล้างตัวกรอง" |
| ค้นหาไม่พบ | — | empty ตาม 5.5 |
| ไม่มีโค้ดลด / ไม่มีประวัติสั่ง | ไม่แสดง section | ไม่แสดง section |
| ออฟไลน์ | แถบ ink ตัวขาว + `WifiOff` "ไม่มีการเชื่อมต่ออินเทอร์เน็ต" ใต้ status bar (`role="status"`) เมื่อ `navigator.onLine === false` | เหมือนกัน |
| โหลดทั้งแอปไม่ได้ / ไม่มีสิทธิ์ | `FoodLoadError` / `FoodDenied` เดิม เปลี่ยนวงกลมเป็นสี error/blush ตาม 9.12 | — |
| ดึงลงเพื่อรีเฟรช | `PullToRefreshIndicator` เดิม (spinner สี `--zk-brand-deep`) | เหมือนกัน — รีเฟรช snapshot + ไดเรกทอรี |
| toast | `fx-toast` เดิม: พื้น ink ตัวขาว 14/500 radius 16 ปุ่มปิด 36 (กด 44) อยู่บนสุดของคอลัมน์ | เหมือนกัน |
| skeleton | gradient `#F1F1F4 → #F8F8FA` shimmer 1200ms; reduced motion = ภาพนิ่ง | |

---

## 10. Accessibility

- **Contrast** (WCAG 2.x, ค่าจากแอปที่วัดแล้ว): ขาวบนชมพู header/hero 3.6–4.1:1 → ใช้ได้เฉพาะ title 28/700 และ subtitle 19/700; ตัวหนังสือเล็กบน white control `#D61256` 5.15:1 (บน `#FFF1F6` 4.70:1); บน `#FFEFF5`: ink 16.25, secondary 4.74, brand-deep 4.64 (ไอคอน ▾); secondary บน `#FDEEF3` ≈ 4.69; ขาวบน brand-deep 5.15; label nav ที่เลือกบน `#FFEDF4` 4.58; ไอคอน nav ทึบ stop ล่าง 4.07 (มี label กำกับ); badge ขาวบน `#B3261E` 6.54; ดาวทองเป็นตกแต่ง มีตัวเลขกำกับเสมอ — QA ตรวจซ้ำด้วยเครื่องมือบน render จริง
- **Focus**: `:focus-visible` outline 2px `#F21967` offset 2 บนพื้นขาว/ชมพูอ่อน; บนพื้นชมพู (header Home, การ์ด hero) ใช้ outline 3px `#FFFFFF` offset 2; ห้าม `outline: none` โดยไม่มีตัวแทน; ลำดับ tab = ลำดับที่มองเห็น; เปิด sheet ย้าย focus เข้า, ปิดคืน focus เดิม, `Esc` ปิดได้
- **ลำดับ screen reader**
  - Home: `<h1>` ZOKY (โลโก้) → ปุ่มตะกร้า (ถ้ามี) → "ร้านโปรด" → heading "อยากกินอะไรวันนี้?" → "ของอร่อยใกล้คุณ เริ่มที่นี่" → ปุ่ม "ค้นหาของอร่อย" → โปรโมชันและข่าวสาร → (ร้านยอดนิยม: h2 + ดูทั้งหมด + การ์ด) → ลิงก์ WYNOS Social → `<nav aria-label="เมนูหลัก">`
  - Food: `<h1 class="sr-only">สั่งอาหาร</h1>` → กลับ → "จัดส่งที่ {ชื่อ}" → ร้านโปรด → คูปองส่วนลด → ช่องค้นหา → สั่งอีกครั้ง → โค้ดลดเพิ่ม → h2 ร้านอาหารทั้งหมด → ตัวกรอง → กลุ่มชิป → รายการ (`<ul>`/`<li>` ปุ่มต่อร้าน) → ปุ่มตะกร้าลอย (อยู่ท้าย DOM)
  - การ์ด/แถวร้านอ่านเป็นก้อนเดียว (`aria-label` รวม) ภาพปก `alt=""`; ไอคอน 3D/ภาพประกอบ/คลื่น `aria-hidden`; ปุ่มที่มีแต่ไอคอนมี label ไทยเสมอ (กลับ, ร้านโปรด, คูปองส่วนลด, ตะกร้า, ล้างการค้นหา)
- **Tap target ≥ 44×44** ทุกตัว: ปุ่ม glossy 38/44 มองเห็นแต่กด 44/48, ปุ่มล้าง 30 → กด 44 (`::after` inset ติดลบ), ชิป 40 → กด 44, "ดูทั้งหมด"/"ตัวกรอง" ≥ 44, ช่อง nav ≥ 69×64; ระยะห่างระหว่างเป้าหมาย ≥ 8
- `<html lang="th">`; ราคาอ่าน "59 บาท"; การเปลี่ยนตะกร้า/toast ประกาศ polite
- ข้อจำกัดที่รู้: viewport `userScalable: false` คงไว้ตาม Founder (2026-10-17 ข้อ 3) จึง pinch-zoom ไม่ได้ — layout ต้องไม่พังเมื่อผู้ใช้ตั้งขนาดตัวหนังสือเบราว์เซอร์ใหญ่ (ตัวหนังสือขึ้นบรรทัด ไม่ตัด ไม่ซ้อน; label nav/badge ล็อกที่ 1.2×)

---

## 11. Map component เว็บเดิม → ใช้ต่อ / แทนที่

| เว็บเดิม (`release/zoky-web-20261018`) | สถานะ | ไปเป็น |
|---|---|---|
| `FoodHeader` (`fx-header`: โลโก้ + หัวใจ + ถุง + "ส่งถึง") | แทนที่ | Home: `ZokyHomeHeader` (4.1); "ส่งถึง" ย้ายไป header Food (5.1); ถุงตะกร้า → ปุ่มตะกร้า glossy เมื่อมีของ (4.1) + ปุ่มลอยในหน้า Food (5.6) |
| `FoodNav` (`fx-nav`) | restyle (logic เดิม) | `ZokyBottomNav` (7.1) |
| `StoreDirectory` | แยกเป็นเนื้อหาหน้า Food — **คง state/fetch/filter/collected promos/browse sheets เดิม** | 5.1–5.5 |
| `FoodDirectoryStoreCard` (กริด 4:3) | แทนที่ | แถวร้าน `ZokyFoodStoreRow` (Food, sheet "ดูทั้งหมด", ผลค้นหา) / การ์ด `ZokyRecommendedStoreCard` (แถวแนวนอน Home) — รูป 1:1 ทั้งคู่ |
| `FoodRecentStoreTile` | restyle | วงกลมแบบหมวดอาหาร (5.3) |
| `FoodHomeSectionHeader` (18/700) | restyle | 20/700 + เป้ากด 44 (5.7) |
| `promoCard` (`fx-deal` แถบไอคอนแดง) | แทนที่ | การ์ดโค้ด `#FDEEF3` (5.4) |
| `fx-search` (pill เทา) | restyle | ช่องค้นหาขาว radius 20 ใน header Food (5.1) |
| `fx-chips` / `fx-chip` | restyle + sticky | 5.5 |
| `FavoriteStoresSheet`, `Sheet` | ใช้ต่อ | เปิดจากหัวใจทั้ง Home และ Food |
| `FoodPromotionCenter` | ใช้ต่อ (restyle กรอบ) | Home ใต้ hero (4.5) |
| `fx-social-promo` | ใช้ต่อ (restyle) | ท้าย Home (4.5) |
| `FoodLoading`, `FoodLoadError`, `FoodDenied`, `FoodStateScreen` | ใช้ต่อ (restyle) | ข้อ 9 |
| `PullToRefreshIndicator`, `usePullToRefresh`, `fx-toast` | ใช้ต่อ | |
| `fx-cart-bar` (หน้าร้าน), `HomePanel` ส่วนหน้าร้าน, `CartPanel`, `CheckoutSheet`, `OrdersPanel`, `AccountPanel`, `MessagesPanel` | ไม่เปลี่ยนรอบนี้ | หน้าร้าน = หน้าถัดไป |
| `FoodGuestBrowse` | restyle หน้า list (7.3) | หน้าร้าน/ตะกร้า guest ไม่เปลี่ยนรอบนี้ |
| ใหม่ (presentational ล้วน) | เพิ่ม | `Zoky3DIcon`, `ZokyNavIcon`, ผิว glossy (CSS + SVG gloss), การ์ด hero, ภาพเบนโตะ (asset), ปุ่ม glossy วงกลม, ปุ่มตะกร้าลอย — ตำแหน่งไฟล์/ชื่อให้ Architect ยืนยัน (เสนอ `web/components/food/zoky-*.tsx` + CSS prefix `zk-` ใน `food-app.css`) |

Data ที่ใช้ (มีอยู่แล้วทั้งหมด ไม่ต้องเพิ่ม API/migration): `fetchFoodCustomerSnapshot` (orders, addresses, store, menu), `fetchFoodStoreDirectory` (ร้าน, promo_*, rating_*, delivered_order_count, cover_path, categories, delivery_fee, is_ad, is_open, พิกัด, prep_time_*), `recordFoodAdClick`, localStorage ร้านโปรด/โค้ดที่เก็บ/ตะกร้า, `food_notifications` + `food_marketing_preferences` (promotion center), `food_public_catalog` (guest)

---

## 12. ไม่อยู่ในขอบเขต / ไม่ทำ

- ไม่เพิ่มฟีเจอร์ใหม่ (ไม่มี pickup, ดีล, แบนเนอร์, หมวด, ร้านแนะนำของแอดมิน บนเว็บรอบนี้)
- ไม่เปลี่ยน logic ตัวกรอง, การคำนวณราคา, auth, การเรียก RPC, การบันทึก ad click
- ไม่แตะ production freeze / release workflow — ต้องผ่าน gate เดิม และ Founder ดู preview ก่อน

---

## 13. Handoff

- **CTO**: ยืนยัน W1–W8, วิธีทำ view `food` + history, คอลัมน์ 480 ระดับ shell, ทำ guest พร้อมกันหรือไม่; branch ตัดจาก `release/zoky-web-20261018` (DECISIONS 2026-10-19)
- **Architect**: ตำแหน่ง component, การ map token `--zk-*` คู่กับ `--fx-*`, การแยกสถานะ error ของไดเรกทอรี, ETA ตาม W6 (เรียก `foodEstimateDeliveryRange` เฉพาะเมื่อมี prep time ทั้งสองค่า)
- **Full-Stack**: implement ตามข้อ 2–11, ไม่เพิ่ม dependency, export ภาพเบนโตะจาก Flutter (SVG/WebP versioned), ตรวจด้วยภาพเทียบแอปที่ 390×844 และ 430×932 (Home: commit `ff8cb3d` ของแอป)
- **QA & Security**: functional ของทุกฟีเจอร์เดิม (ค้นหา, ตัวกรอง 5 แบบ, เก็บโค้ด, ร้านโปรด, สั่งอีกครั้ง, ad click, ตะกร้า, ที่อยู่, ลิงก์แชร์ `?store=`, `?order=`, guest → login → ตะกร้าเดิม), ยืนยันไม่มีข้อมูลตัวอย่าง/pickup บน production, contrast ด้วยเครื่องมือ, VoiceOver บน iPad, tap target, reduced motion, offline/error/empty, iPad portrait/landscape
- **Founder**: ดู preview บน iPad และตอบคำถามข้อ 14

---

## 14. คำถามถึง Founder (ตอบสั้น ๆ ได้)

**Q1 — "ดีลเด็ดวันนี้" บนหน้าแรกของเว็บ**
ตอนนี้ยังไม่มีดีลจริงในระบบ (ในแอปเป็นตัวอย่าง)
- ก (แนะนำ): ซ่อนไว้ก่อน จนกว่าจะมีดีลจริง
- ข: เอาโปรที่ร้านตั้งไว้จริง (เช่น ลด 20%, ส่งฟรี) มาแสดงเป็นการ์ดดีล

**Q2 — "ร้านอาหารแนะนำ" บนหน้าแรกของเว็บ**
ระบบให้แอดมินเลือกร้านแนะนำยังไม่ขึ้นเว็บจริง
- ก (แนะนำ): แสดง "ร้านยอดนิยม" แทนไปก่อน (เรียงจากยอดสั่งจริง เหมือนที่เว็บมีอยู่แล้ว)
- ข: ซ่อนไว้ก่อน จนกว่าระบบร้านแนะนำผ่านการตรวจ

**Q3 — "หมวดอาหาร 4 วง" ในหน้าสั่งอาหาร**
ยังไม่มีรายการหมวดอาหารจริงในระบบ
- ก (แนะนำ): ซ่อนไว้ก่อน แล้วค่อยทำเป็นงานแยกเมื่อ Founder เลือกหมวดที่ต้องการ
- ข: ใช้หมวดที่ร้านกรอกไว้เองมาทำเป็นวงกลม (ชื่ออาจไม่สม่ำเสมอ)

## Storefront header update (Founder, 2026-10-22, after staging review)
- Header: `ชื่อร้าน · ที่อยู่ร้าน` on one line (address ellipsised).
- Removed: menu count, delivery fee, "เปิดรับออเดอร์"/"เปิดอยู่" line. The closed badge and closed box remain.
- Meta: `⭐ rating (count)` (real reviews only; "ร้านใหม่" when none) · ZOKY scooter icon + distance (customer default address → store pin, straight line) · delivery minutes = store prep time + ride time (~22 km/h + 5 min). Minutes are shown only when the store set prep times and a distance is known.
- Signed-out storefront: name · address only, because the public catalog has no ratings, prep times or customer location. Adding them would need a DB change and a separate approval.
- Scooter icon: inline SVG `ZokyScooterIcon` (pink body, gold box), with no network request.
