# ZOKY Design System v0.1 (PROPOSED)

> โดย AI Design | 2026-10-17 | สถานะ: **PROPOSED, รอ Founder review**
> ขอบเขต: ZOKY คือการ rebrand แอปสั่งอาหารฝั่งลูกค้าของ WYNOS Food (`food.wynos.online` ย้ายไป `zoky.online`) ครอบคลุม Web (Next.js เดิม) + iOS + Android (Flutter แอปใหม่หนึ่งตัว) feature parity เต็มกับเว็บ
> Tokens แบบ machine-readable: `design-reference/zoky/tokens.json`
> เอกสารนี้เป็นเอกสารออกแบบเท่านั้น ไม่ได้อนุมัติให้แก้ application source, เพิ่ม dependency หรือ deploy

```
Screen: ทั้งระบบ (design system ไม่ใช่ screen เดียว)
Purpose: ให้ Web/iOS/Android มี brand identity ของ ZOKY ชุดเดียวกัน โดยที่ system element ปรับตาม platform
User Flow: ไม่เปลี่ยน ใช้ flow เดิมของ WYNOS Food ทั้งหมด (ดู PRD/parity ของ PM ใน .wyn/docs/product/)
Components: ข้อ 9
Interactions: ข้อ 8 (Motion) และข้อ 11 (Platform matrix)
States: ข้อ 9.12
Responsive Behavior: ข้อ 6.4
Accessibility: ข้อ 10
Design Rules: ข้อ 1, 3, 4
Handoff: ข้อ 13
```

---

## 0. ที่มาและความสัมพันธ์กับเอกสารเดิม

ตรวจสิ่งที่มีอยู่ก่อนออกแบบ:

| แหล่ง | สิ่งที่พบ | ผลต่อเอกสารนี้ |
|---|---|---|
| `web/app/food/food-app.css` (`fx-` design system ที่ Founder อนุมัติ 2026-10) | สีหลัก `--fx-red #E40036`, ฟอนต์ Anuphan, ปุ่มทรง pill, bottom nav แบบลอย, sheet มุม 24, skeleton แบบ shimmer | **ใช้โครงสร้าง component, ขนาด และ spacing เดิมต่อ** เปลี่ยนแค่สีกับ asset ของแบรนด์ ไม่คิด layout ใหม่ |
| `web/app/food/layout.tsx` | ฟอนต์ `Anuphan` (400/500/600/700, thai+latin) ผ่าน `next/font`, theme-color `#E32636`, splash ไล่สีแดงไปชมพู | ใช้ Anuphan ต่อทั้ง 3 platform |
| `web/components/food/*.tsx` | ไอคอน `lucide-react` (stroke 1.9 ตอนปกติ / 2.3 ตอน active), nav 4 แท็บ, tracker 5 ขั้น | ใช้ชุดไอคอนเดิม |
| Dark mode ของ Food บนเว็บ | **ไม่มี** (ไม่มี `prefers-color-scheme` ใน food CSS และ theme-color ของ dark ก็เป็นสีแดงเดียวกัน) | เสนอ dark tokens ไว้เท่านั้น ยังไม่อยู่ใน v1 ดูข้อ 3.6 และคำถามเปิด Q1 |
| `ds-001-color-system.md` / `ds-007-zoky-commerce-identity.md` | "ZOKY Orange `#FF6B35`" เป็นสีของ ZOKY Marketplace เก่าใน Flutter `app/` และ `seller_app/` | **ZOKY Pink ในเอกสารนี้แทนที่ Orange สำหรับแบรนด์ ZOKY ใหม่** (Founder ตัดสิน 2026-10-17) ส่วนจะย้าย `seller_app`'s `ZokyTheme` มาใช้สีชมพูด้วยหรือไม่ เป็นคำถามเปิด Q7 |
| กติกาสีของ WYN (ขาว 80–90%, rainbow 10–20%) | AGENTS.md / ds-009 | สำหรับ ZOKY ใช้ **ZOKY Pink แทน rainbow** ในส่วน 10–20% ตาม Founder ห้ามใช้สีรุ้งใน ZOKY |

**จุดที่ต้องแก้จากของเดิม (พบตอน audit):**

1. เว็บใช้ `--fx-red` ทั้งกับ CTA และกับสถานะ danger (`fx-status.is-danger`, `fx-closed-label`, `fx-soldout-tag`, `.is-error`) ทำให้แยกสีแบรนด์ออกจาก error ไม่ได้ ZOKY ต้องแยก semantic palette (ข้อ 3.4)
2. สีเขียว success เดิม `#1F8A4C` บนขาวได้ **4.38:1** ไม่ผ่าน AA สำหรับตัวหนังสือขนาดเล็ก จึงปรับเป็น `#187A43` (5.38:1)
3. Label ของ nav ตอนไม่ active และ placeholder ใช้ `--fx-muted #8A8A94` ซึ่งได้ **3.42:1** ไม่ผ่าน จึงเปลี่ยนไปใช้ `text.secondary` (5.26:1)
4. `viewport` ของเว็บตั้ง `maximumScale: 1, userScalable: false` ทำให้ผู้ใช้ pinch-zoom ไม่ได้ (ขัด WCAG 1.4.4) ดูคำถามเปิด Q6
5. Element หลายตัวมีพื้นที่กดเล็กกว่า 44px เช่น `fx-plus` 32px, `fx-menu-row-add` 36px, `fx-search-clear` 30px, `fx-stepper--sm` 36px ดูข้อ 10.1

---

## 1. Brand Principles

1. **White first, pink with purpose**: พื้นที่ส่วนใหญ่ (80–90%) เป็นขาว/Cloud White สีชมพู (10–20%) ใช้กับ action หลัก จุดที่ active ส่วนที่เป็นโปรโมชัน และโลโก้เท่านั้น ห้ามทาชมพูเต็มหน้าจอ ยกเว้น splash
2. **Friendly, glossy, hungry**: โลโก้เป็นสามมิติมันวาว แต่ UI ต้องแบน สะอาด อ่านง่าย ความมันวาวอยู่ที่โลโก้, splash และ banner เท่านั้น ห้ามใส่ gloss/gradient ให้ปุ่มหรือการ์ด
3. **Pink never means "wrong"**: สีชมพูหมายถึงแบรนด์, action และโปรโมชันเท่านั้น error ใช้แดงของ semantic palette และต้องมีไอคอนกับข้อความเสมอ
4. **One brand, native feel**: สี โลโก้ ฟอนต์ การ์ด nav และ copy เหมือนกันทุก platform ส่วน dialog, picker, switch, gesture และ transition ใช้แบบ native ของแต่ละ platform (ข้อ 11)
5. **Accessible by default**: ทุกคู่สีที่มีตัวหนังสือต้องผ่าน WCAG 2.2 AA ทุก control มีพื้นที่กดถึงเกณฑ์ platform และรองรับ Dynamic Type/font scaling

---

## 2. Logo

### 2.1 ตัวโลโก้ (ใช้ต้นฉบับ 100%)

- **Primary mark**: สี่เหลี่ยมมุมมนสีชมพูแบบ 3D มันวาว ข้างในมี wordmark "Zoky" สีขาว ตัว "o" เป็นหมุดแผนที่ที่มีจุดสีชมพู และมีเส้นยิ้มอยู่ข้างใต้ ไฟล์ต้นฉบับ: `design-reference/zoky/zoky-logo-source.jpg` (1256×1256 JPG มุมนอกสี่เหลี่ยมเป็นสีขาว)
- **Wordmark-only**: wordmark สีขาว + หมุด + เส้นยิ้ม บนพื้นโปร่งใส ดึงออกมาจากต้นฉบับโดยไม่แก้รูปทรง ใช้บนพื้นชมพูเท่านั้น (splash, Android adaptive foreground)
- Founder เลือกโลโก้ต้นฉบับโดยไม่แก้ไข **ห้ามวาด แต่ง หรือ "ทำให้ทันสมัย" ใหม่** การทำ vector ต้องเป็นการ trace ให้ตรงต้นฉบับ แล้วส่งให้ Founder เทียบก่อนใช้

### 2.2 ปัญหาของไฟล์ draft ที่รู้แล้ว

`design-reference/zoky/zoky-app-icon-1024-draft.png` มีกรอบมุมมนด้านในติดมากับภาพ พอ iOS/Android ตัด mask ทับจะเห็นขอบซ้อนสองชั้น **ไอคอน production ต้องสร้างใหม่โดยไม่มีกรอบติดมา** คือเอาพื้นชมพูมันวาวขยายเต็ม canvas (full-bleed) แล้วให้ OS ตัดมุมเอง ควรทำจาก vector ดู Q3

### 2.3 Clear space และขนาดขั้นต่ำ

- **Clear space**: รอบ mark ทุกด้านต้องเว้นอย่างน้อย **25% ของความกว้าง mark** (mark 96px เว้น 24px) wordmark-only เว้นอย่างน้อย **ความสูงของหมุดแผนที่**
- **ขนาดขั้นต่ำ**

| การใช้งาน | ขั้นต่ำ |
|---|---|
| Mark ในแอป (header, about) | 28pt / 28dp / 28px (ของเว็บเดิม 32px ใช้ต่อได้) |
| Favicon | 32px (ที่ 16px wordmark อ่านไม่ออก แต่ยอมรับได้เพราะห้ามแก้โลโก้ ดู Q4) |
| Wordmark-only | กว้าง 64px |
| สิ่งพิมพ์ | mark 12mm |

### 2.4 กติกาพื้นหลัง

| พื้นหลัง | ใช้แบบไหน |
|---|---|
| ขาว / Cloud White / Blush | Primary mark ตามต้นฉบับ |
| ภาพถ่ายสว่างที่ไม่รก | Primary mark + elevation.2 |
| ภาพถ่ายรกหรือมืด | Primary mark บนพื้นขาวหรือ scrim เท่านั้น |
| ชมพูแบรนด์ (`#F21967` / `#D61256`) | Wordmark-only สีขาว หรือ primary mark + วงขาว 3px รอบนอก (แบบ splash เว็บเดิม) |
| พื้นมืด (dark mode ในอนาคต) | Primary mark ตามต้นฉบับ |

### 2.5 ห้ามทำ

- ห้ามเปลี่ยนสี (รวมถึงทำ wordmark เป็นสีชมพูบนพื้นขาว จนกว่า Founder อนุมัติ ดู Q5), ห้ามยืด, เอียง หรือหมุน
- ห้ามตัด gloss ทิ้ง ห้ามใส่เงา ขอบ หรือ glow เพิ่ม (ยกเว้นวงขาวตามข้อ 2.4)
- ห้ามเอา mark ไปซ้อนในกรอบมุมมนอีกชั้น (จะเกิดปัญหาขอบซ้อนแบบไฟล์ draft)
- ห้ามพิมพ์ "Zoky" ใหม่ด้วยฟอนต์อื่นแทนโลโก้ ในข้อความ UI ให้เขียนชื่อแบรนด์ว่า "ZOKY" ด้วยฟอนต์ระบบตามปกติได้
- ห้ามเปลี่ยนสีจุดในหมุด ห้ามแยกหมุดไปใช้เป็นไอคอน location ของ UI (ไอคอน location ของ UI ใช้ Lucide `MapPin`)
- ห้ามทำ animation ที่บิดรูปโลโก้ ทำได้แค่ scale กับ fade

### 2.6 รายการ asset ที่ต้องผลิต

| # | Asset | Spec | หมายเหตุ |
|---|---|---|---|
| A1 | Master vector | SVG/AI/Figma แยก layer: พื้นชมพูมันวาว, wordmark ขาว, จุดชมพูในหมุด, เส้นยิ้ม | ต้นทางของทุกไฟล์ข้างล่าง (Q3) |
| A2 | iOS App Icon | 1024×1024 PNG, sRGB, **ไม่มี alpha, full-bleed, ไม่ใส่มุมมนหรือกรอบเอง** | Xcode single-size |
| A3 | iOS Dark / Tinted icon | 1024 PNG: Dark = wordmark บนพื้นมืดหรือโปร่ง, Tinted = grayscale | iOS 18+ ไม่บังคับ แต่ถ้าไม่ทำ OS จะ generate ให้เองซึ่งอาจดูไม่ดี (Q8) |
| A4 | Android adaptive: background | 108×108dp (432px @xxxhdpi), พื้นชมพูมันวาว full-bleed (vector drawable หรือ PNG) | |
| A5 | Android adaptive: foreground | 108×108dp โปร่งใส, wordmark+หมุด+ยิ้มอยู่ในวงกลม safe zone เส้นผ่านศูนย์กลาง 66dp | |
| A6 | Android monochrome | 108×108dp สีเดียว (wordmark) โปร่งใส | themed icon ของ Android 13+ |
| A7 | Android legacy mipmap | 48/72/96/144/192px | สำหรับ launcher เก่า |
| A8 | Google Play icon | 512×512 PNG 32-bit, full-bleed | Play ตัดมุมเอง |
| A9 | Android 12+ splash icon | 288×288dp ไม่มี icon background (เนื้อหาอยู่ในวง 192dp) หรือ 240dp ถ้ามี icon background (เนื้อหาในวง 160dp) | ใช้ A5 บนพื้น `#F21967` |
| A10 | iOS launch screen | Storyboard: พื้น `#F21967` + wordmark-only ขาวกึ่งกลาง (vector PDF/SVG) | ต้องเหมือน A9 |
| A11 | Web favicon | `favicon.ico` (16/32/48) + `icon-32.png` | |
| A12 | PWA icons | 192 และ 512 PNG `purpose: any` | |
| A13 | PWA maskable | 512 PNG `purpose: maskable`, full-bleed, เนื้อหาอยู่ในวง 80% | |
| A14 | apple-touch-icon | 180×180 PNG, ไม่มี alpha, full-bleed | ของเดิมใช้ 192 ให้เปลี่ยนเป็น 180 |
| A15 | iOS PWA startup images | ชุดขนาดเดียวกับ `FOOD_IOS_LAUNCH_SIZES` เดิม | ใช้ดีไซน์เดียวกับ A10 |
| A16 | OG / Twitter image | 1200×630 PNG: พื้น Cloud White, mark ด้านซ้าย, ข้อความ "ZOKY • สั่งอาหาร" + `zoky.online` | ของเดิมใช้ไอคอน 512 แบบ `summary` ให้เปลี่ยนเป็น `summary_large_image` |
| A17 | Wordmark-only transparent | SVG + PNG @1x/2x/3x สีขาว | |
| A18 | Mask icon (ไม่บังคับ) | SVG สีเดียว | Safari pinned tab |

Versioning ไฟล์ icon บนเว็บให้ทำแบบเดิม (`-vNN` / `?v=`) เพื่อกัน PWA cache ค้าง

---

## 3. Color

### 3.1 Brand palette (วัดจาก pixel ของโลโก้ Founder ยืนยันแล้ว)

| Token | Hex | ใช้กับ | ห้ามใช้กับ |
|---|---|---|---|
| `brand.pink` (ZOKY Pink) | `#F21967` | ไอคอน, indicator, progress, tracker, ปุ่ม + ที่มีแต่ไอคอน, focus ring, checkbox/radio ที่เลือก, ตัวหนังสือใหญ่ (≥24px หรือ ≥18.66px bold) | พื้นหลังของตัวหนังสือขาวขนาดปกติ (4.11:1) |
| `brand.pinkLight` | `#F4368D` | gradient, highlight | พื้นหลังของตัวหนังสือ (ขาวได้ 3.65:1) |
| `brand.pinkSoft` | `#F880BE` | gloss, จุดเริ่ม gradient ของ banner | พื้นหลังของตัวหนังสือขาว (2.38:1) |
| `brand.pinkDeep` | `#D61256` | **พื้นทุกอย่างที่มีตัวหนังสือขาว**: ปุ่ม primary, cart bar, chip ที่เลือก, badge, promo tag และตัวหนังสือแบรนด์บนขาว | ตัวหนังสือบน Blush (4.21:1) |
| `brand.berry` | `#AF1341` | link/ตัวหนังสือแบรนด์บนขาวหรือ Blush, pressed state ของ pinkDeep | |
| `brand.wine` | `#991636` | เน้นหนักพิเศษ, โทนเงา | |
| `brand.blush` | `#F1E4F5` | container แบรนด์แบบอ่อน: chip, pill ของ nav ที่ active, promo center, การ์ดที่เลือก | ตัวหนังสือ `text.secondary` บนพื้นนี้ (4.30:1) |
| `brand.line` | `#F9C0DE` | เส้นขอบตกแต่งโทนแบรนด์ (pinkSoft 50% บนขาว) | เส้นขอบที่ใช้บอกขอบเขตของ control |
| Cloud White (`neutral.25`) | `#F8FAFE` | พื้นหลังแอป (canvas) | |

**การตัดสินใจหลัก (D1):** ปุ่มและพื้นที่มีตัวหนังสือขาวใช้ **Pink Deep `#D61256`** ไม่ใช่ `#F21967` เพราะ label ปุ่ม 16px bold บน `#F21967` ได้ 4.11:1 ไม่ผ่าน AA (ต้องใหญ่ ≥18.66px bold) ส่วน `#F21967` ยังเห็นได้ทั่วแอปผ่านไอคอน, indicator, ปุ่ม +, tracker, focus ring และโลโก้ ถ้า Founder อยากได้ปุ่มสีสดกว่านี้ ดูทางเลือกใน Q2

### 3.2 Neutral scale

| Token | Hex | บทบาท |
|---|---|---|
| `neutral.0` | `#FFFFFF` | surface (การ์ด, sheet, nav, header) |
| `neutral.25` | `#F8FAFE` | canvas (Cloud White) |
| `neutral.50` | `#F6F6F8` | พื้นจมลง (placeholder รูป, แถวบัญชีธนาคาร, empty line) |
| `neutral.100` | `#F3F3F6` | พื้น chip/search/stepper, ปุ่ม disabled |
| `neutral.150` | `#EBEBEF` | เส้นขอบอ่อน, divider |
| `neutral.200` | `#DCDCE2` | เส้นขอบปกติ (input, ปุ่ม outline-neutral, chip) |
| `neutral.400` | `#8A8A94` | ไอคอนรอง, ขอบ checkbox/radio ที่ไม่ได้เลือก, ตัวหนังสือ disabled **ห้ามใช้กับตัวหนังสือที่ต้องอ่าน** |
| `neutral.600` | `#6B6B76` | ตัวหนังสือรอง, placeholder, label ของ nav ที่ไม่ active |
| `neutral.900` | `#16161A` | ตัวหนังสือหลัก (ink), toast, offline bar |

ค่า neutral ทั้งหมดนำมาจาก `--fx-*` เดิมของเว็บ ไม่ได้คิดใหม่ ยกเว้น Cloud White ที่มาจาก palette ของโลโก้

### 3.3 Role tokens (สิ่งที่ component เรียกใช้จริง)

| Role | ค่า |
|---|---|
| `bg.canvas` | `neutral.25` |
| `bg.surface` | `neutral.0` |
| `bg.sunken` | `neutral.50` |
| `bg.chip` | `neutral.100` |
| `bg.brandSoft` | `brand.blush` |
| `bg.scrim` | ink 45% |
| `bg.inverse` | `neutral.900` |
| `text.primary` | `neutral.900` |
| `text.secondary` | `neutral.600` |
| `text.disabled` | `neutral.400` |
| `text.brand` | `brand.berry` |
| `text.link` | `brand.pinkDeep` |
| `text.onAction` | `#FFFFFF` |
| `action.primary` | `brand.pinkDeep` |
| `action.primaryPressed` | `brand.berry` |
| `action.accent` | `brand.pink` (ใช้เฉพาะพื้นที่มีแต่ไอคอนหรือไม่มีตัวหนังสือ) |
| `action.disabledBg` / `action.disabledText` | `neutral.100` / `neutral.400` |
| `border.subtle` / `border.default` / `border.control` / `border.focus` | `neutral.150` / `neutral.200` / `neutral.400` / `brand.pink` |

### 3.4 Semantic palette (แยกจากแบรนด์)

| Token | Hex | Container | On-container | ใช้กับ |
|---|---|---|---|---|
| `error` | `#B3261E` | `#F9DEDC` | `#410E0B` | ชำระเงินมีปัญหา, validation, ออเดอร์ล้มเหลว, ปุ่ม destructive |
| `success` | `#187A43` | `#E9F7EF` | `#187A43` | ส่งสำเร็จ, ชำระแล้ว, คูปองใช้ได้, ร้านเปิด |
| `warning` | `#9A5800` | `#FFF6E5` | `#9A5800` | สต็อกเหลือน้อย, รอตรวจสลิป, แจ้งเตือนทั่วไป |
| `info` | `#175CD3` | `#EAF2FF` | `#175CD3` | ข้อมูลกลาง ๆ, คำแนะนำ |
| `rating` | `#F5A623` | | | ไอคอนดาวเท่านั้น และต้องมีตัวเลขกำกับเสมอ |

**แยก error ออกจากแบรนด์อย่างไร**
- Hue ต่างกัน: แบรนด์ `#F21967` อยู่ที่ประมาณ 338° (ชมพูอมม่วง) ส่วน error `#B3261E` อยู่ที่ประมาณ 3° (แดงจริง) และ error เข้มกว่า (luminance 0.111 เทียบกับ 0.206)
- ใช้สีอย่างเดียวไม่พอสำหรับคนตาบอดสี error จึงต้องมี **ไอคอน (`CircleAlert`/`TriangleAlert`) + ข้อความ** เสมอ ส่วนแบรนด์ไม่ใช้ไอคอนเตือน
- ห้ามใช้ชมพูแบรนด์กับสถานะลบ ได้แก่ ร้านปิด สินค้าหมด ชำระเงินไม่สำเร็จ และ input ผิด
- `error` เลือกให้ตรงกับค่า `error` ของ Material 3 เพื่อให้ map เข้า Flutter `ColorScheme.error` ได้ตรง

**Map สถานะเดิมของเว็บมาเป็น ZOKY** (`foodOrderTone` เดิม ไม่เปลี่ยน logic เปลี่ยนแค่สี)

| Tone เดิม | สถานการณ์ | ZOKY |
|---|---|---|
| `brand` | ออเดอร์กำลังดำเนินการ | พื้น Blush + ตัวหนังสือ Berry |
| `danger` | ชำระเงิน pending/issue | พื้น `error` + ตัวหนังสือขาว + ไอคอน (เดิมใช้ fx-red ทึบ) |
| `warn` | ส่งสลิปแล้ว รอตรวจ | พื้น warningContainer + ตัวหนังสือ warning |
| `success` | จัดส่งสำเร็จ | พื้น successContainer + ตัวหนังสือ success |
| `muted` | ยกเลิก | พื้น `neutral.100` + ตัวหนังสือ `text.secondary` |
| ป้ายร้านปิด / สินค้าหมด | | พื้น ink 80% + ตัวหนังสือขาว + ไอคอน `Clock3` (ไม่ใช้ชมพูอีก) |
| ส่วนลดในสรุปยอด | | ตัวหนังสือ `text.brand` (Berry) เพราะส่วนลดเป็นเรื่องดี ไม่ใช่ error |

### 3.5 ตาราง contrast (WCAG 2.x relative luminance, คำนวณด้วยมือจากสูตร sRGB)

เกณฑ์: ตัวหนังสือปกติ ≥4.5, ตัวหนังสือใหญ่ (≥24px หรือ ≥18.66px bold) ≥3.0, UI/ไอคอน ≥3.0

| Foreground | Background | Ratio | ผล |
|---|---|---|---|
| White | `#F21967` Pink | 4.11 | ผ่านเฉพาะตัวใหญ่ / ไอคอน |
| White | `#F4368D` Pink Light | 3.65 | ผ่านเฉพาะตัวใหญ่ / ไอคอน (นโยบาย: ห้ามใช้เป็นพื้นของตัวหนังสือ) |
| White | `#F880BE` Pink Soft | 2.38 | **ไม่ผ่าน** |
| Ink `#16161A` | `#F880BE` Pink Soft | 7.58 | AAA |
| White | `#D61256` Pink Deep | 5.15 | AA |
| White | `#AF1341` Berry | 7.02 | AAA |
| White | `#991636` Wine | 8.33 | AAA |
| `#F21967` | White | 4.11 | ผ่านเฉพาะตัวใหญ่ / ไอคอน / focus ring |
| `#F21967` | Cloud White | 3.93 | ผ่านเฉพาะตัวใหญ่ / ไอคอน |
| `#F21967` | Blush | 3.36 | ไอคอนเท่านั้น |
| `#D61256` | White | 5.15 | AA |
| `#D61256` | Cloud White | 4.93 | AA |
| `#D61256` | Blush | 4.21 | ผ่านเฉพาะตัวใหญ่ / ไอคอน |
| `#AF1341` Berry | White | 7.02 | AAA |
| `#AF1341` Berry | Cloud White | 6.72 | AA |
| `#AF1341` Berry | Blush | 5.73 | AA |
| Ink `#16161A` | White | 18.04 | AAA |
| Ink | Cloud White | 17.27 | AAA |
| Ink | Blush | 14.74 | AAA |
| `#6B6B76` secondary | White | 5.26 | AA |
| `#6B6B76` | Cloud White | 5.04 | AA |
| `#6B6B76` | `#F6F6F8` sunken | 4.88 | AA |
| `#6B6B76` | `#F3F3F6` chip | 4.75 | AA |
| `#6B6B76` | Blush | 4.30 | **ไม่ผ่าน** บน Blush ให้ใช้ ink หรือ Berry |
| `#8A8A94` neutral.400 | White | 3.42 | UI/ไอคอนเท่านั้น |
| White | Ink (toast) | 18.04 | AAA |
| `#B3261E` error | White | 6.54 | AA |
| `#B3261E` | Cloud White | 6.26 | AA |
| `#B3261E` | `#F9DEDC` errorContainer | 5.14 | AA |
| `#410E0B` | `#F9DEDC` | 12.77 | AAA |
| White | `#B3261E` | 6.54 | AA |
| `#187A43` success | White | 5.38 | AA |
| `#187A43` | Cloud White | 5.15 | AA |
| `#187A43` | `#E9F7EF` | 4.87 | AA |
| `#1F8A4C` (success เดิมของเว็บ) | White | 4.38 | **ไม่ผ่าน** จึงเปลี่ยน |
| `#9A5800` warning | White | 5.57 | AA |
| `#9A5800` | Cloud White | 5.33 | AA |
| `#9A5800` | `#FFF6E5` | 5.19 | AA |
| `#175CD3` info | White | 5.99 | AA |
| `#175CD3` | Cloud White | 5.73 | AA |
| `#175CD3` | `#EAF2FF` | 5.32 | AA |
| `#F5A623` rating | White | 2.03 | ใช้เป็นตกแต่งเท่านั้น (มีตัวเลขกำกับ) |
| White | ink 72% บนรูป (ป้ายโฆษณา) | ≈7.2 (กรณีรูปขาวล้วน) | AA |

ตัวเลขชุด brand ที่ Founder ส่งมาตรงกับที่คำนวณซ้ำ (4.11 / 3.65 / 5.15 / 7.02 / 8.33) QA ควรตรวจซ้ำด้วยเครื่องมืออัตโนมัติตอน implement

### 3.6 Dark mode (PROPOSED เท่านั้น ไม่อยู่ใน v1 parity)

เว็บ Food ตอนนี้ไม่มี dark mode เพื่อให้ parity ตรงกัน **v1 ของทั้ง 3 platform เป็น light-only** (Flutter ตั้ง `themeMode: ThemeMode.light`) ถ้า Founder อนุมัติ dark mode ภายหลัง ให้เริ่มจากค่านี้:

| Role | Dark | Contrast |
|---|---|---|
| `bg.canvas` | `#141216` | |
| `bg.surface` | `#1E1B21` | |
| `text.primary` | `#F4F2F6` | 16.74 บน canvas / 15.30 บน surface |
| `text.secondary` | `#B9B5BF` | 9.24 / 8.45 |
| `text.brand` | `#F4368D` | 5.11 / 4.67 |
| `brand.pink` (ไอคอน) | `#F21967` | 4.53 บน canvas |
| `action.primary` | `#D61256` (ตัวหนังสือขาว 5.15 เท่าเดิม) | |
| `error` | `#F2B8B5` | 10.90 บน canvas |

ส่วน success/warning/info/container ของ dark ยังไม่ได้กำหนด ต้องคำนวณก่อนเปิดใช้ (Q1)

---

## 4. Color proportion (กติกา 80–90 / 10–20)

- **ขาว/Cloud White/neutral ≥80%** ของพื้นที่ทุกหน้าจอ (ยกเว้น splash)
- **ชมพู ≤20%**: ไม่เกิน 1 element ชมพูทึบขนาดใหญ่ต่อหน้าจอ (CTA หลักหรือ cart bar อย่างใดอย่างหนึ่ง เมื่อ cart bar แสดง CTA อื่นบนจอเดียวกันต้องเป็น outline/soft) ที่เหลือเป็นจุดเล็ก ๆ: ไอคอน, indicator, badge, ราคาโปร
- Blush ใช้เป็นพื้นของ section ที่เน้น ได้ไม่เกิน 1–2 บล็อกต่อหน้าจอ (promo center, profile card, track card)
- Semantic colors ไม่นับรวมใน 20% แต่ใช้เฉพาะตอนมีสถานะจริง

---

## 5. Typography

### 5.1 ฟอนต์

- **Anuphan** (Thai + Latin, loopless) ใช้ต่อจากเว็บ Food เดิมเพื่อไม่ให้ภาพแบรนด์เปลี่ยน น้ำหนักที่ใช้: 400/500/600/700 เผยแพร่บน Google Fonts โดย Cadson Demak ภายใต้ SIL Open Font License 1.1 **ต้องยืนยันไฟล์ license ก่อน bundle** (Q9)
- Fallback: `Noto Sans Thai` → system (`-apple-system`/SF, Roboto)
- **Web**: ใช้ `next/font/google` แบบ self-host ตามเดิม (`--font-anuphan`)
- **Flutter**: bundle ไฟล์ `.ttf` ไว้ใน assets (ไม่โหลดตอน runtime เพื่อความเป็นส่วนตัวและให้ใช้ offline ได้) ใส่ OFL.txt ใน `LicenseRegistry` ตั้ง `ThemeData.fontFamily: 'Anuphan'`
- ทั้ง iOS และ Android ใช้ Anuphan เหมือนกัน (ไม่ใช้ SF/Roboto) เพราะฟอนต์เป็นส่วนหนึ่งของ brand identity ยกเว้น system dialog/picker native ที่ใช้ฟอนต์ระบบ (ข้อ 11)

### 5.2 Scale (สรุปจากขนาดที่เว็บใช้จริง)

| Token | Size / Weight / Line-height | ใช้กับ (`fx-` เดิม) | Flutter |
|---|---|---|---|
| `display` | 28 / 700 / 1.25 | splash name, ยอดชำระ (`fx-pay-amount` 32 ให้ใช้ display + scale) | `displaySmall` |
| `titleLg` | 24 / 700 / 1.25 | หัวหน้าแท็บ (`fx-page-head h1`), ยอดรวมใน bottom bar | `headlineSmall` |
| `titleMd` | 22 / 700 / 1.25 | ชื่อร้าน (23), ชื่อเมนูใน sheet, หัวข้อ state (21) | `titleLarge` |
| `titleSm` | 18 / 700 / 1.3 | หัวข้อ section, หัว sheet, หัวหน้าที่มีปุ่มกลับ (19) | `titleMedium` |
| `bodyLg` | 16 / 400–600 / 1.45 | ชื่อเมนูในแถว, input | `bodyLarge` |
| `bodyMd` | 15 / 400 / 1.45 | ตัวหนังสือหลัก (base ของ `fx-app`) | `bodyMedium` |
| `bodySm` | 13 / 400 / 1.45 | คำอธิบาย, meta (12.5 เดิมปัดเป็น 13) | `bodySmall` |
| `labelLg` | 16 / 700 / 1.25 | ปุ่ม | `labelLarge` |
| `labelMd` | 14 / 600 / 1.3 | chip, text button, segment | `labelMedium` |
| `labelSm` | 12 / 700 / 1.25 | status pill, promo tag, required tag | `labelSmall` |
| `caption` | 11 / 500 / 1.2 | **เฉพาะ** label ของ nav และ badge (ขั้นต่ำ) | `ZokyTextStyles.caption` |
| `price` / `priceLg` | 16 / 24, 700, tabular numbers | ราคา, ยอดรวม, countdown | `ZokyTextStyles.price*` |

กติกา:
- ภาษาไทยมีสระบน/ล่างและวรรณยุกต์ line-height ของ body ต้อง ≥1.45 และ title ≥1.25 ใน Flutter ใช้ `TextLeadingDistribution.even` กันสระโดนตัด
- ห้าม letter-spacing เป็นบวกกับภาษาไทย ค่าติดลบใช้กับ title เท่านั้น (≤ −0.3px)
- ตัวเลขราคา/เวลาใช้ tabular figures (`font-variant-numeric: tabular-nums` / `FontFeature.tabularFigures()`) รูปแบบราคา "฿59" หรือ "59 บาท" ให้ตาม copy เดิมของเว็บ
- ขนาด 12.5/13.5/14.5 ที่เว็บใช้อยู่ ปัดเข้า scale ได้ตอน rebrand ไม่บังคับให้แก้ทันที

---

## 6. Spacing, Radius, Elevation, Layout

### 6.1 Spacing (ฐาน 2/4px)

`2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 32, 48` (tokens `spacing.1`–`spacing.24`) ระยะขอบจอ (gutter) = **16** ระยะห่าง section บน home = 22 ระยะระหว่างการ์ดในกริด = 16 แนวตั้ง / 12 แนวนอน

### 6.2 Radius

| Token | px | ใช้กับ |
|---|---|---|
| `xs` | 6 | tag ของร้าน, checkbox |
| `sm` | 10 | thumb เล็ก (48), skeleton line |
| `md` | 14 | input, รูปเมนู, note, ปุ่มเลือกที่อยู่ (เดิม 12–14) |
| `lg` | 16 | รูปร้าน, banner, การ์ดทั่วไป, state block |
| `xl` | 20 | order card (18), pay card, bottom bar (22), guest hero |
| `2xl` | 24 | มุมบนของ sheet |
| `full` | 9999 | ปุ่ม, chip, search, nav, cart bar, badge, stepper |

### 6.3 Elevation (มาจากเงาของเว็บเดิม เปลี่ยนเงาแดงเป็นเงาชมพู)

| Token | Shadow | ใช้กับ |
|---|---|---|
| `0` | none | แถวในรายการ, การ์ดที่มี border |
| `1` | 0 2 12 ink/8% | deal card, การ์ดลอย |
| `2` | 0 2 14 ink/12% | ปุ่มลอยบนรูป, QR card |
| `3` | 0 6 24 ink/12% | sticky bottom bar, sheet footer (เงาขึ้นด้านบน) |
| `4` | 0 12 32 ink/14% + 0 2 6 ink/6% | bottom nav ลอย |
| `5` | 0 10 28 ink/24% | toast |
| `brand` | 0 8 18 `#D61256`/26% | ปุ่ม primary, cart bar |

Flutter: ใช้ `BoxShadow` ตาม token (ไม่ใช้ `Material.elevation` เป็นหลัก) และตั้ง `surfaceTintColor: Colors.transparent` ทุก surface ไม่ให้ M3 ย้อมการ์ดเป็นชมพู

### 6.4 Layout / responsive

- Mobile-first ความกว้างอ้างอิง 360–430
- กริดร้าน: 2 คอลัมน์ / ≥680px เป็น 3 คอลัมน์ (เหมือนเว็บ) / ≤359px ลดช่องห่าง
- เนื้อหาบน tablet/desktop กว้างไม่เกิน 720 (sheet), nav 560, cart bar 540 วางกึ่งกลาง
- เคารพ safe area ทุกขอบ (notch, home indicator, Android gesture bar)

---

## 7. Iconography

- ชุดไอคอน: **Lucide** (เว็บใช้ `lucide-react` อยู่แล้ว ฝั่ง Flutter ใช้ Lucide port หรือ export SVG ชุดเดียวกัน ให้ Architect เป็นคนเลือก dependency)
- Stroke ปกติ 1.9, active 2.3 (ตามเว็บ) ขนาด 16 / 20 (มาตรฐาน) / 24, illustration ของ empty state 44–46 stroke 1.25–1.6
- Nav: `House` (active ทึบ), `ReceiptText`, `MessageCircle`, `UserRound`
- ไอคอนที่ต่างตาม platform: กลับ, แชร์, more (ข้อ 11)
- สี: ปกติ `text.primary`, รอง `neutral.600`/`neutral.400`, เน้น `brand.pink`, สถานะใช้ semantic
- ไอคอนตกแต่งต้อง `aria-hidden` / `ExcludeSemantics` ไอคอนที่เป็นปุ่มต้องมี label


### 7.1 "ZOKY Glossy 3D" — brand surface + 3D icons (APPROVED by Founder 2026-10-17)

> ที่มา: Founder feedback 2026-10-17 "เฟส1 เฟส2 ทุกอย่างต้องไปในทิศทางเดียวกัน … ไอคอนชอบฟีล 3D" — ยังเป็นข้อเสนอ ไม่ใช่ decision

**Surface recipe** (โค้ดเดียว: `zoky_app/lib/core/widgets/zoky_glossy_surface.dart` → `ZokyGloss`, `ZokyGlossPainter`, `ZokyGlossySurface`)

| ชั้น | ค่า |
|---|---|
| Base | gradient แนวตั้ง `headerTop #F93384` → `headerMid #F72C7E` (35%) → `headerBottom #EE226E` (เท่ากับ header/โลโก้ ห้ามใช้ gradient เข้มกว่านี้แยกต่อการ์ด) |
| Gloss band | ขาว 35% → 0% จากขอบบนลงมา `glossHeight` (px คงที่) inset 4px ขอบล่างโค้งขึ้นไปทางขวาแบบไฮไลต์บนโลโก้ |
| Inner rim | เส้น 1px ด้านใน ขาว 25% (บน) → 8% (ล่าง) เฉพาะการ์ด |
| Shadow | `#EE226E` @25% blur 24 y 10 (การ์ด) / @22% blur 12 y 4 (ปุ่มขาว) |
| White control | gradient `#FFFFFF` → `#FFF1F6` + rim ขาวบน / `#F9C0DE` 40% ล่าง ใช้กับปุ่มหัวใจ, pill, ปุ่มค้นหา |
| Frosted disc | ขาว 34% → 14% + gloss 30% + rim ขาว 45%→12% (วงกลมหลังภาพประกอบ) |

ใช้แล้วกับ: Header เฟส 1 (gloss 7% เพื่อให้ไอคอน status bar ขาวยัง ≥ 3:1, ไม่มี rim/shadow, layout/โค้ง/sheet เดิม), การ์ดเฟส 2 (full recipe), การ์ดดีลเฟส 3 (gloss + rim บนพื้น tint อ่อน ดูด้านล่าง). เฟสถัดไปที่มีพื้นชมพูให้ใช้ `ZokyGlossySurface` ตัวเดียวกัน

**3D icon lighting** (`zoky_app/lib/core/widgets/zoky_3d_icon.dart` → `Zoky3DIcon`, CustomPainter ล้วน ไม่มีรูป/emoji/package)

1. แสงมาจากซ้ายบนเสมอ
2. ตัวไอคอน gradient แนวตั้ง (pink `#FF6BAA` → `#E5135D`)
3. ไฮไลต์ specular รูปวงรีซ้ายบน (halo เบลอ + จุดแกนสว่าง)
4. เงาด้านใน (inner shade) ขวาล่าง `#9E0E3E` 38% เบลอ + ขอบแสงบาง ๆ ซ้ายบน
5. drop shadow เล็กนุ่ม เลื่อนลงล่าง (`#C2185B` 30%)
6. blur ทุกค่าสเกลตามขนาด (ขั้นต่ำ 0.4px) ให้คมที่ 16–48px
7. Glyph ตอนนี้: `heart` (ปุ่มร้านโปรด), `sparkle` (ดาว 4 แฉกใน pill), `arrowRight` (ลูกแก้วชมพู + ลูกศรขาวนูน ท้ายปุ่มค้นหา)
8. Semantics: ค่าเริ่มต้นเป็น decorative (`ExcludeSemantics`) — label อยู่ที่ปุ่มแม่ (เช่น "ร้านโปรด"); ถ้าไอคอนยืนเดี่ยวให้ส่ง `semanticLabel`
9. ไอคอน 3D ใช้เป็น *brand accent* เท่านั้น ไอคอนระบบ/nav ยังเป็น line icon ตามข้อ 7 (ไม่ทำทั้งแอปเป็น 3D)

**Contrast บนพื้นชมพู** (WCAG 2.x)

- ขาวบน `#F93384`/`#F72C7E`/`#EE226E` = 3.60/3.74/4.13:1 → **ขาวบนชมพูได้เฉพาะ large text** (≥ 24px หรือ ≥ 18.66px bold) เช่น title 28/700 และ subtitle 19/700
- gloss band ต้องจบก่อนถึงข้อความขาว (การ์ด: `glossHeight` = padding + 34 อยู่หลัง pill สีขาวเท่านั้น)
- ข้อความเล็กต้องอยู่บน white control สี `brandDeep #D61256`: 5.15:1 บนขาว, 4.70:1 บน `#FFF1F6`
- ค่าวัดจาก pixel จริง (preview 430×932 และ 375×667 @3x): title 3.68:1, subtitle 3.79–3.82:1, pill text 4.76:1, ปุ่มค้นหา 4.76–4.79:1, status bar glyph ≥ 3.09:1
- ห้ามแก้ contrast ด้วยการทำการ์ดให้เข้มขึ้น (ทำให้ไม่เข้ากับ header) — ให้เปลี่ยนขนาด/น้ำหนักตัวอักษร หรือย้ายข้อความไปบน white control แทน

**ภาพประกอบ**: `ZokyBentoIllustration` วาดด้วยโค้ดแบบ 3/4 (ฝากล่องดำเงา, ด้านหน้า/ด้านข้างแดงเคลือบ, ขาเล็ก, ข้าว/แซลมอน/ทามาโกะ/ผัก) แสงเดียวกับไอคอน แยกเป็น widget เดี่ยวเพื่อแทนด้วยรูปจริงภายหลัง

**การ์ดดีลเฟส 3 (พื้นอ่อน)** (`zoky_app/lib/features/deals/widgets/zoky_deal_card.dart` → `ZokyDealCard`, APPROVED 2026-10-17)

- พื้น tint แนวตั้ง: ชมพู `#FFF1F6` → `#FFDCEA`, พีช `#FFF7EF` → `#FFE4D1` (สลับกันตามลำดับ) — พีชเป็นสีใหม่ ยังไม่อยู่ใน tokens.json
- `ZokyGlossPainter` แบบไม่มี base: gloss ขาว 55% สูง 44px + rim ขาว 90% → 25%, เงา `#EE226E` @16% blur 16 y 6, radius `xl` (20)
- หัวข้อโปร 20/800 `brandDeep` = large text (ต้อง ≥ 3:1): token 4.09:1 (ชมพู) / 4.28:1 (พีช) บน stop ล่าง, วัดจาก pixel จริง 430×932@3x 4.40:1 / 4.52:1; คำอธิบายสี ink ≥ 14:1; ป้าย "ตัวอย่าง" เป็น white control (4.76:1)
- ลูกศรท้ายการ์ด `Zoky3DIcon(arrowRight, 24)`, ภาพอาหาร `ZokyDealIllustration` (ชานมไข่มุก ไก่ทอด เบอร์เกอร์ ราเมง) แสงเดียวกับไอคอน 3D
- ข้อมูลตัวอย่างต้องมีป้าย "ตัวอย่าง" ทุกการ์ด + หมายเหตุใต้หัวข้อ section และ sheet บอก "ตัวอย่าง — ยังไม่ใช่โปรโมชันจริง" (Founder rule: ห้ามสร้างโปรจริง/อ้างส่วนลดจริง)

---

## 8. Motion

| Token | ค่า | ใช้กับ |
|---|---|---|
| `press` | 140ms, `standard` (0.2, 0.8, 0.2, 1), scale 0.97 | กดปุ่ม/การ์ด (ปุ่ม + ใช้ 0.9) |
| `base` | 200ms | เปลี่ยนสี/สถานะ, page-in บนเว็บ |
| `sheet` | 240ms `standard` | sheet เลื่อนขึ้น |
| `enter` | 260ms `standard` | cart bar โผล่ขึ้น (rise 24px) |
| `pop` | 500ms (0.2, 0.9, 0.3, 1.2) | โลโก้บน splash |
| `shimmer` | 1200ms loop | skeleton |

- Page transition ของ mobile ใช้แบบ native (ข้อ 11) ไม่ทำ custom
- Haptic: เพิ่มลงตะกร้า, เลือก option, สั่งสำเร็จ (iOS `lightImpact` / Android `selectionClick`) ถ้าผู้ใช้ปิดไว้ในระบบก็ไม่สั่น
- **Reduced motion** (`prefers-reduced-motion` / `MediaQuery.disableAnimations`): ปิด animation ทั้งหมด ยกเว้นการเปลี่ยนแบบ fade ≤100ms skeleton กลายเป็นภาพนิ่ง

---

## 9. Core components

ทุก component ใช้ได้ทั้ง 3 platform (shared) เว้นแต่ข้อ 11 บอกว่าเป็น adaptive ชื่อในวงเล็บคือ class `fx-` ของเว็บเดิม

### 9.1 Buttons (`fx-btn`)

| Variant | พื้น / ตัวหนังสือ / ขอบ | Pressed | Disabled |
|---|---|---|---|
| Primary | `action.primary` / ขาว / – + shadow `brand` | `action.primaryPressed` + scale 0.97 | `neutral.100` / `neutral.400` / ไม่มีเงา |
| Outline brand | ขาว / `action.primary` / 1.5px `action.primary` | พื้น Blush | ขอบ `neutral.200` / `neutral.400` |
| Soft (tonal) | Blush / Berry / 1.5px `brand.line` | scale 0.97 | |
| Outline neutral | ขาว / ink / 1px `neutral.200` | พื้น `neutral.100` | |
| Destructive | ขาว / `error` / 1.5px `error` (หรือทึบ `error` + ขาว ใน dialog ยืนยัน) | พื้น errorContainer | |
| Text | โปร่ง / `text.link` (14/700) | พื้น `neutral.100` | `neutral.400` |
| Icon | 44 (iOS/web) / 48 (Android) วงกลม, ไอคอน ink | พื้น `neutral.100` | |
| Add (+) | วงกลม 32–36 `action.accent` (`#F21967`) + ไอคอนขาว stroke 2.8 | scale 0.9 | ซ่อน (สินค้าหมด) |

ขนาด: sm 40 / md 48 / lg 54 (CTA ของ checkout/payment) ทรง pill padding แนวนอน 22 (sm 16) Loading: spinner ขาวแทน label ความกว้างเท่าเดิม `aria-busy` และกดซ้ำไม่ได้

### 9.2 Inputs (`fx-field`, `fx-search`, `fx-coupon`)

- Text field: สูง 52 (textarea 84), radius `md`, พื้นขาว, ขอบ 1px `neutral.200`, ตัวหนังสือ 16 (กัน iOS ซูม), placeholder `text.secondary`
- ต้องมี **label ที่มองเห็นอยู่ด้านบนเสมอ** (`titleSm`/16 bold) ห้ามใช้ placeholder แทน label (เหตุผลที่ยอมให้ขอบ `neutral.200` ต่ำกว่า 3:1 ได้)
- Focus: ขอบ `action.primary` + ring 3px `brand.pink` 12%
- Error: ขอบ 1.5px `error` + ข้อความใต้ช่องสี `error` พร้อมไอคอน `CircleAlert` + `aria-describedby`/`errorText`
- Search: pill สูง 48 พื้น `neutral.100` ไอคอน `neutral.600` ตอน focus พื้นเป็นขาว + ring 2px `brand.pink` ปุ่มล้างมองเห็น 30 แต่พื้นที่กด 44/48
- Coupon: pill 46 + ปุ่ม sm ข้างกัน ผลลัพธ์ใช้ success/error พร้อมไอคอน

### 9.3 Chips (`fx-chip`)

- Filter chip: สูง 40 (พื้นที่กด 44/48 ด้วย padding แนวตั้ง), pill, ขาว + ขอบ `neutral.200` + ink `labelMd`
- Selected (ทึบ): `action.primary` + ขาว (5.15) ห้ามใช้ `#F21967` ทึบ
- Selected (soft): Blush + Berry + ขอบ 1.5px `brand.pink`
- Tag ของร้าน: `neutral.100` + `text.secondary` 11.5–12, radius `xs`, ไม่กดได้
- Semantics: `aria-pressed` / `Semantics(selected:)`

### 9.4 Store card (`fx-store-card`)

- รูป 4:3 radius `lg` placeholder `neutral.50` + ไอคอน `Store`
- Overlay บนรูป (`labelSm` 11/700 pill):
  - โฆษณา: ink 72% + ขาว มุมบนซ้าย
  - ร้านปิด: ink 80% + ขาว + `Clock3` มุมบนขวา (ไม่ใช้ชมพู)
  - โปรโมชัน: `brand.pinkDeep` + ขาว ชิดซ้ายล่าง (มุมขวามน)
  - ETA: ขาว + ink มุมขวาล่าง
- ชื่อ 15/700 สูงสุด 2 บรรทัด, meta 13 `text.secondary` + ดาว `rating` + ตัวเลข bold ink, tags
- Pressed: รูป scale 1.03
- Screen reader อ่านรวมเป็นก้อนเดียว เช่น "ร้าน{ชื่อ}, คะแนน 4.8, ส่งประมาณ 25 นาที, ร้านปิดอยู่, โปรโมชัน ลด 20%"

### 9.5 Menu item card (`fx-menu-row`, `fx-menu-tile`)

- Row: รูป 104 (≤359px เหลือ 84) radius `md` อยู่ขวา, ชื่อ `bodyLg`/600 2 บรรทัด, คำอธิบาย 13 `text.secondary` 2 บรรทัด, ราคา `price` ink, ปุ่ม + มุมขวาล่าง, divider `neutral.150`
- Tile (แนวนอน): 128×128 radius `lg` ปุ่ม + 32 ซ้อนบนรูป
- สินค้าหมด: ป้าย ink 80% "หมด" บนรูป + รูป saturate 0.7 + ราคา `text.secondary` ไม่มีปุ่ม + ประกาศ "หมด" ใน label
- สต็อกน้อย: tag warningContainer/warning "เหลือ N"
- Label ของปุ่ม: "เพิ่ม {ชื่อเมนู} ลงตะกร้า"

### 9.6 Item sheet + stepper + options

- Sheet radius บน `2xl` แสดงรูปเต็มกว้าง สูง min(64vw, 300) ปุ่มปิดแบบลอย (40 visual / 44–48 hit)
- Option: radio/checkbox ของ ZOKY ขนาด 22 ขอบ `border.control` (3.42) ตอนเลือกเติม `brand.pink` แถวสูง ≥52 tag "จำเป็น" Blush/Berry พอครบแล้วเปลี่ยนเป็น successContainer/success
- Stepper: pill `neutral.100` สูง 52 (sm 40) ปุ่ม 44 (sm 36 visual แต่ hit 44/48) จำนวน 17/700 label "ลด/เพิ่มจำนวน {เมนู}" ค่า "จำนวน 2"
- Footer: stepper + ปุ่ม primary 52 "ใส่ตะกร้า • ฿xxx" เงา `3`

### 9.7 Cart bar (`fx-cart-bar`)

- Pill ลอย สูง 60 กว้าง min(100%−32, 540) อยู่เหนือ nav, พื้น `action.primary` + shadow `brand`
- ซ้าย: วงจำนวน 40 พื้นขาว ตัวหนังสือ `action.primary` 16/700 กลาง: "ดูตะกร้า" 17/700 ขาว ขวา: ยอดรวม 17/700 tabular
- เข้า: animation `enter` (rise 24px) กด: scale 0.98 เมื่อยอดเปลี่ยนให้ประกาศผ่าน live region (polite)
- Label: "ดูตะกร้า {n} รายการ รวม {ยอด} บาท"

### 9.8 Bottom navigation (`fx-nav`), shared ทุก platform

- Pill ลอย สูง 60 กว้าง min(100%−24, 560) พื้นขาว 94% + blur 18 + ขอบ ink 6% + elevation `4` ระยะจากล่าง = max(8, safe-area − 12)
- 4 แท็บ: หน้าหลัก / ออเดอร์ / ข้อความ / บัญชี (ตามเว็บ ห้ามเพิ่มหรือลด)
- ไม่ active: ไอคอน `neutral.600` stroke 1.9, label `caption` สี `text.secondary` (เดิมใช้ muted ซึ่งไม่ผ่าน contrast)
- Active: pill 48×28 พื้น Blush, ไอคอน `action.primary` stroke 2.3 (House ทึบ), label 11/700 `action.primary` (5.15)
- Badge (แท็บออเดอร์): `brand.pinkDeep` + ขาว 11/700 ขอบขาว 2px "9+" label "{n} ออเดอร์ที่กำลังดำเนินการ"
- พื้นที่กดเต็มช่อง (≥60 สูง) `aria-current="page"` / `Semantics(selected: true)`
- **ไม่ใช้** `CupertinoTabBar` หรือ Material `NavigationBar` เพราะ nav เป็นส่วนหนึ่งของแบรนด์ (แต่ใส่ semantics ให้ครบแบบ tab bar)

### 9.9 Order status tracker (`fx-track`)

- 5 ขั้น: รอร้านรับออเดอร์ → กำลังเตรียมอาหาร → พร้อมจัดส่ง → กำลังจัดส่ง → จัดส่งสำเร็จ
- เส้น 3px: ยังไม่ถึง `neutral.150` / ผ่านแล้ว `brand.pink`
- จุด 26: ยังไม่ถึง ขอบ 2px `neutral.200` / ผ่านแล้ว ทึบ `brand.pink` + เช็คขาว / ปัจจุบัน วง 7px `brand.pink` / ขั้นสุดท้ายสำเร็จ ทึบ `success`
- Label 11: ยังไม่ถึง `text.secondary` / ผ่านแล้วหรือปัจจุบัน `text.brand` 700
- ถูกยกเลิก: ไม่แสดง tracker แสดงกล่อง `neutral.100` + ไอคอน + ข้อความแทน
- Track card ด้านบน: Blush + ไอคอนในกล่อง `brand.pinkDeep` + หัวข้อ Berry
- Semantics: อ่านเป็นรายการเดียว "สถานะออเดอร์: กำลังเตรียมอาหาร ขั้นที่ 2 จาก 5" เมื่อสถานะเปลี่ยนแบบ realtime ให้ประกาศ (polite)

### 9.10 Banners และ deals

- Home banner (admin): อัตราส่วน 2.4:1 radius `lg` scroll แนวนอนแบบ snap ใต้ตัวหนังสือมี scrim ดำ 0→74% ตัวหนังสือขาว focus ring 3px `brand.pink` (ของเดิมเป็นฟ้า `#147EFB`)
- Brand banner (ไม่ใช่รูป): gradient 160° `pinkSoft` → `pink` → `pinkDeep` ตัวหนังสือขาว**ต้องวางบนช่วง pinkDeep** หรือใหญ่ ≥18.66px bold บนช่วง pink ห้ามวางบนช่วง pinkSoft/pinkLight
- Deal/คูปอง (`fx-deal`): การ์ดขาว elevation `1` ซ้ายเป็นแถบไอคอน gradient `pinkLight` → `pinkDeep` + เส้นประขาว (มีแต่ไอคอน) หัวข้อเล็ก Berry, ปุ่ม "เก็บ" ทึบ `action.primary` / เก็บแล้วเป็น `neutral.100` + `text.secondary`
- Promo center: กล่อง Blush, ตัวหนังสือ Berry, ตัวนับทึบ `pinkDeep`

### 9.11 Promo badges / status pills

| Badge | Style |
|---|---|
| ลด %, ส่งฟรี, โปรร้าน | ทึบ `brand.pinkDeep` + ขาว `labelSm` |
| โปรแบบเบา (ในรายการ) | Blush + Berry |
| ใหม่ / แนะนำ | ขาว + ขอบ `brand.line` + Berry |
| Status pills | ตามตาราง map ในข้อ 3.4 |

ห้ามใช้ semantic error/warning กับโปรโมชัน และห้ามใช้ชมพูกับสถานะลบ

### 9.12 States: empty, loading, error, offline, toast

- **Empty** (`fx-state`): วงกลม 108 Blush + ไอคอน `brand.pink` 44 (3.36 ผ่านเกณฑ์ไอคอน) + หัวข้อ `titleMd` + ข้อความ 14.5 `text.secondary` (max 320) + ปุ่ม primary ≥200 กว้าง
- **Error**: โครงเหมือน empty แต่วงกลมเป็น errorContainer + ไอคอน `error` + ปุ่ม "ลองอีกครั้ง" (primary) ห้ามใช้วงชมพู
- **Loading**: skeleton ที่รูปทรงตรงกับเนื้อหา (`fx-skel`: line 16, pill 48, banner 140 r20, chip 78×38, card 4:3 r16) gradient `#F1F1F4`→`#F8F8FA` shimmer 1200ms บน mobile ใช้ skeleton เหมือนกัน spinner ใช้เฉพาะ inline (ปุ่ม, pull-to-refresh) ซึ่งเป็นแบบ native
- **Offline**: แถบ ink + ขาว + ไอคอน `WifiOff` ใต้ status bar
- **Toast**: พื้น ink, ขาว 14/500, radius `lg`, elevation `5`, มีปุ่มปิด 36 (hit 44/48) ตำแหน่งดูข้อ 11 `aria-live="polite"` / `SemanticsService.announce`
- **Notes** (`fx-note`): success/warning/error/info ใช้ container + on-color ของ semantic + ไอคอน (`fx-note--danger` เดิมย้ายจากแดงแบรนด์ไปเป็น error)

### 9.13 Sheets และ dialogs

- Content sheet ของ ZOKY (item, cart, รายการร้าน): shared, radius บน `2xl`, scrim ink 45%, สูงสุด 92% ของความสูงจอ, หัว 56 มีปุ่มปิด/กลับ 44 บน mobile มี drag handle 36×4 สี `neutral.200`
- Alert/confirm dialog และ action menu เป็น adaptive (ข้อ 11)

---

## 10. Accessibility

### 10.1 Tap targets

- iOS ≥ **44×44pt**, Android ≥ **48×48dp**, Web ≥ **44×44px** ระยะห่างระหว่างเป้าหมาย ≥8
- Element ที่ภาพเล็กกว่าเกณฑ์ (ปุ่ม + 32/36, ปุ่มล้างช่องค้นหา 30, stepper sm 36, ปุ่มปิด toast 36, float button 40) **ต้องขยายพื้นที่กด** โดยไม่ต้องขยายภาพ (เว็บ: `::after` inset ติดลบ / Flutter: `SizedBox` 48 + `MaterialTapTargetSize.padded`)

### 10.2 Dynamic Type / font scaling

- รองรับ text scale ถึง **200%** บน flow หลัก (หน้าแรก → ร้าน → เมนู → ตะกร้า → checkout → ติดตามออเดอร์) โดยตัวหนังสือไม่โดนตัดและไม่ซ้อนกัน ตัวหนังสือยาวให้ขึ้นบรรทัดใหม่ แถวต่าง ๆ ขยายสูงตาม
- **ห้ามปิด scaling ทั้งแอป** clamp ได้เฉพาะ element ที่แน่นเป็นพิเศษ (label ของ nav, badge, overlay บนรูปร้าน) ไม่เกิน 1.3× ด้วย `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` ส่วนบนเว็บใช้หน่วยที่ scale ตามการตั้งค่าเบราว์เซอร์
- ที่ scale ≥1.5: กริดร้านเปลี่ยนเป็น 1 คอลัมน์, cart bar ซ่อน label "ดูตะกร้า" เหลือจำนวน + ยอด
- เว็บ: pinch-zoom ต้องใช้ได้ (Q6)

### 10.3 Screen readers (VoiceOver / TalkBack / NVDA-VoiceOver web)

- รูปโลโก้: label "ZOKY" ถ้าอยู่ใน header ที่มีชื่อแบรนด์เป็นข้อความอยู่แล้วให้ซ่อน
- การ์ดอ่านรวมเป็นก้อนเดียว (`MergeSemantics` / `<button>` ห่อทั้งการ์ด) ราคาอ่านเป็น "59 บาท"
- ปุ่มที่มีแต่ไอคอนต้องมี label ภาษาไทยเสมอ (กลับ, ปิด, แชร์, ค้นหา, เพิ่ม/ลดจำนวน)
- Badge, tracker, cart bar ใช้ label ตามข้อ 9 การเปลี่ยนแปลงแบบ async (เพิ่มลงตะกร้า, toast, สถานะออเดอร์) ประกาศแบบ polite
- ลำดับ focus ตามลำดับการมองเห็น พอเปิด sheet/dialog ให้ย้าย focus เข้าไป ปิดแล้วคืน focus ที่เดิม Android back / iOS escape gesture (2 นิ้ว Z) ปิด sheet ได้
- ห้ามใช้สีอย่างเดียวในการสื่อสถานะ (มีไอคอน/ข้อความประกอบเสมอ)

### 10.4 อื่น ๆ

- Focus ring ที่มองเห็นได้ (เว็บ/keyboard/switch control): 2px `brand.pink` offset 2
- Reduced motion ตามข้อ 8 ส่วน Bold Text (iOS) / font weight adjustment (Android 12+) ใช้ตามระบบ
- รองรับ landscape ได้ แต่ไม่ต้องออกแบบพิเศษ
- ภาษา: ตั้ง locale `th-TH` (`<html lang="th">`, `Locale('th')`) เพื่อให้ screen reader อ่านไทยถูก

---

## 11. Platform-adaptive matrix

**Shared** = เหมือนกันทุก platform (Web/iOS/Android) **Adaptive** = ใช้แบบ native ของ platform แต่ใส่ token แบรนด์ (สี, ฟอนต์ใน custom UI) เท่าที่ระบบยอม

### 11.1 Shared (brand identity)

สี/tokens, โลโก้และ app icon artwork, ฟอนต์ Anuphan, ชุดไอคอน Lucide (ยกเว้นไอคอนใน 11.2), ปุ่มทุก variant, input/search/coupon, chips, segment ของแท็บออเดอร์, store/menu card, item sheet, stepper, radio/checkbox, cart bar, bottom nav ลอย, header ของแท็บหลัก (หัวข้อใหญ่ชิดซ้าย), tabs ในหน้าร้าน (เส้นใต้ `brand.pink`), order tracker, status pills, promo badges, banners/deals, empty/error/offline states, skeleton, toast styling, copy/ข้อความทั้งหมด, splash artwork

### 11.2 Adaptive (system-level)

| Element | iOS (Cupertino) | Android (Material 3) | Web (เดิม) |
|---|---|---|---|
| Alert / confirm dialog | `CupertinoAlertDialog` ปุ่ม destructive ใช้ `isDestructiveAction` (แดงระบบ) | M3 `AlertDialog` radius 28 พื้นขาว ปุ่ม `TextButton` สี `action.primary` destructive ใช้ `error` | ZOKY sheet/dialog เดิม |
| Action menu (ตัวเลือก, ยกเลิก, เลือกรูป) | `CupertinoActionSheet` | `showModalBottomSheet` + `ListTile` (drag handle) | ZOKY sheet |
| Date/time picker (สั่งล่วงหน้า) | `CupertinoDatePicker` แบบ wheel ใน bottom popup + ปุ่ม "เสร็จ" | `showDatePicker` (calendar) + `showTimePicker` (dial/input) สี primary = `action.primary` | คงแบบเดิม |
| Switch | `CupertinoSwitch` track ตอนเปิด = `action.primary` | M3 `Switch` track ตอนเปิด = `action.primary` thumb ขาว (`Switch.adaptive`) | checkbox/toggle เดิม |
| Back | `chevron_left` (CupertinoIcons.back) + swipe-back จากขอบ | `arrow_back` + system back / predictive back (Android 14+) | Lucide `ArrowLeft` |
| Share icon | Lucide `Share` (กล่อง + ลูกศรขึ้น) | Lucide `Share2` (สามจุด) | ตามเดิม |
| Share sheet | `UIActivityViewController` (native) | Android Sharesheet (native) | Web Share API / copy link |
| More icon | `Ellipsis` (แนวนอน) | `EllipsisVertical` | ตามเดิม |
| Scroll physics | `BouncingScrollPhysics` | `ClampingScrollPhysics` + stretch overscroll | browser |
| Page transition | `CupertinoPageTransitionsBuilder` (slide + parallax) | M3 default (`FadeForwardsPageTransitionsBuilder` / predictive back) | `fx-page-in` 200ms |
| Title ของหน้าที่ push | กึ่งกลาง | ชิดซ้าย | ชิดซ้าย (เดิม) |
| Pull-to-refresh | `CupertinoSliverRefreshControl` | `RefreshIndicator` สี `brand.pink` | ตามเดิม |
| Spinner inline | `CupertinoActivityIndicator` | `CircularProgressIndicator` สี `brand.pink` | ตามเดิม |
| Toast position | บนสุดใต้ status bar (เหมือนเว็บ) | ล่าง เหนือ nav/cart bar (ตำแหน่งแบบ SnackBar) styling ZOKY | บนสุด |
| Clipboard feedback | แสดง toast "คัดลอกแล้ว" | Android 13+ ระบบแสดงเองอยู่แล้ว **ไม่ต้อง** แสดง toast ซ้ำ (≤12 แสดง toast) | toast |
| Text field: cursor/selection/handles/context menu | native (cursor `brand.pink`) | native (cursor/handles `brand.pink`) | browser |
| Keyboard | native, ใส่ `textInputAction` ให้ถูก | native | browser |
| Haptics | `HapticFeedback.lightImpact` | `HapticFeedback.selectionClick` | ไม่มี |
| Permission prompts (location/notification/photos) | system dialog ก่อนขึ้นมีหน้าอธิบายของ ZOKY (shared) | เหมือนกัน | browser prompt |
| Image picker (สลิป, รูปรีวิว) | PHPicker (native) | Android Photo Picker (native) | `<input type=file>` |
| Status bar | ไอคอนเข้มบนหน้าขาว / ไอคอนขาวบน hero รูปร้านและ splash | เหมือนกัน + edge-to-edge | theme-color (Q10) |
| Sheet gesture | ลากลงเพื่อปิด, detents | ลากลงเพื่อปิด + back ปิดได้ | แตะ backdrop |
| App icon | A2/A3 | A4–A8 adaptive + themed | A11–A14 |
| Splash | Launch storyboard (A10) | SplashScreen API (A9) | `fx-splash` (artwork ใหม่) |

กติกา: ถ้า element ไหนไม่อยู่ในตารางนี้ ให้ถือเป็น **shared** และถ้าจะเพิ่ม adaptive ใหม่ต้องให้ Design review ก่อน

---

## 12. Token mapping (design token → Flutter → CSS)

Web: ประกาศ `--zk-*` ไว้บน root ของแอป ZOKY แล้วให้ `--fx-*`/`--wf-*` เดิมอ้างไปที่ `--zk-*` ระหว่างย้าย (ไม่บังคับให้เปลี่ยนชื่อ class `fx-`) Flutter: `ColorScheme.light(...)` + `ThemeExtension<ZokyColors>` + `ZokyTextStyles` (ชื่อ class เป็นข้อเสนอ ให้ Architect ยืนยัน)

### 12.1 Color

| Design token | Hex | Flutter | CSS variable | `fx-` เดิมที่ถูกแทน |
|---|---|---|---|---|
| `action.primary` (pinkDeep) | `#D61256` | `ColorScheme.primary` | `--zk-action-primary` | `--fx-red` (กรณีพื้นที่มีตัวหนังสือ) |
| `text.onAction` | `#FFFFFF` | `ColorScheme.onPrimary` | `--zk-text-on-action` | |
| `bg.brandSoft` (blush) | `#F1E4F5` | `ColorScheme.primaryContainer` | `--zk-surface-brand` | `--fx-red-soft`, `#FFF7F8` |
| `text.brand` (berry) | `#AF1341` | `ColorScheme.onPrimaryContainer` / `secondary` | `--zk-text-brand` | `--fx-red-text` |
| `action.primaryPressed` | `#AF1341` | `ZokyColors.actionPressed` | `--zk-action-primary-pressed` | `--fx-red-dark` |
| `brand.pink` / `action.accent` | `#F21967` | `ZokyColors.brand` | `--zk-brand` | `--fx-red` (กรณีไอคอน/indicator) |
| `brand.pinkLight` | `#F4368D` | `ZokyColors.brandLight` | `--zk-brand-light` | |
| `brand.pinkSoft` | `#F880BE` | `ZokyColors.brandSoft` / `inversePrimary` | `--zk-brand-soft` | splash `#FF7AA6` |
| `brand.wine` | `#991636` | `ColorScheme.tertiary` | `--zk-wine` | |
| `brand.line` | `#F9C0DE` | `ZokyColors.brandLine` | `--zk-brand-line` | `--fx-red-line` |
| `bg.canvas` | `#F8FAFE` | `scaffoldBackgroundColor`, `surfaceContainerLow` | `--zk-bg-canvas` | `background:#fff` ของ `.fx-app` |
| `bg.surface` | `#FFFFFF` | `ColorScheme.surface`, `surfaceContainerLowest` | `--zk-surface` | `#fff` |
| `bg.sunken` | `#F6F6F8` | `surfaceContainer` | `--zk-surface-sunken` | `--fx-surface` |
| `bg.chip` | `#F3F3F6` | `surfaceContainerHigh` | `--zk-surface-chip` | `--fx-chip` |
| `border.subtle` | `#EBEBEF` | `outlineVariant`, `surfaceContainerHighest` | `--zk-border-subtle` | `--fx-line` |
| `border.default` | `#DCDCE2` | `ZokyColors.borderDefault` | `--zk-border-default` | `--fx-line-strong` |
| `border.control` | `#8A8A94` | `ColorScheme.outline` | `--zk-border-control` | `#C9C9D1` (เดิมไม่ผ่าน 3:1) |
| `text.primary` | `#16161A` | `onSurface`, `shadow`, `scrim`, `inverseSurface` | `--zk-text-primary` | `--fx-ink` |
| `text.secondary` | `#6B6B76` | `onSurfaceVariant` | `--zk-text-secondary` | `--fx-sub` |
| `text.disabled` | `#8A8A94` | `onSurface` + disabled opacity | `--zk-text-disabled` | `--fx-muted` |
| `text.inverse` | `#FFFFFF` | `onInverseSurface` | `--zk-text-inverse` | |
| `error` | `#B3261E` | `ColorScheme.error` | `--zk-error` | (เดิมใช้ `--fx-red`) |
| `onError` | `#FFFFFF` | `onError` | `--zk-on-error` | |
| `errorContainer` | `#F9DEDC` | `errorContainer` | `--zk-error-container` | |
| `onErrorContainer` | `#410E0B` | `onErrorContainer` | `--zk-on-error-container` | |
| `success` / container | `#187A43` / `#E9F7EF` | `ZokyColors.success` / `successContainer` | `--zk-success` / `--zk-success-container` | `--fx-green` / `--fx-green-soft` |
| `warning` / container | `#9A5800` / `#FFF6E5` | `ZokyColors.warning` / `warningContainer` | `--zk-warning` / `--zk-warning-container` | `--fx-amber` / `--fx-amber-soft` |
| `info` / container | `#175CD3` / `#EAF2FF` | `ZokyColors.info` / `infoContainer` | `--zk-info` / `--zk-info-container` | |
| `rating` | `#F5A623` | `ZokyColors.rating` | `--zk-rating` | `--fx-star` |
| `border.focus` | `#F21967` | `ThemeData.focusColor` (+ `InputDecorationTheme.focusedBorder` ใช้ primary) | `--zk-focus-ring` | outline `--fx-red` |
| surface tint | transparent | `ColorScheme.surfaceTint = Colors.transparent` | | |

**คำเตือนการย้าย web:** `--fx-red` ปัจจุบันถูกใช้ทั้งกับพื้นที่มีตัวหนังสือ ไอคอน และสถานะ danger AI Coding ต้องไล่ทุกจุดที่ใช้ แล้วแยกเป็น `--zk-action-primary` / `--zk-brand` / `--zk-error` จะ alias ทีเดียวทั้งหมดไม่ได้ เงาที่ hardcode `rgb(228 0 54 / x)` ให้เปลี่ยนเป็น `--zk-shadow-brand` ส่วน `themeColor`/`msapplication-TileColor` `#E32636` และสี splash ต้องเปลี่ยนด้วย

### 12.2 Typography / spacing / radius / elevation

| Design token | Flutter | CSS variable |
|---|---|---|
| `typography.fontFamily.base` | `ThemeData.fontFamily: 'Anuphan'` | `--zk-font` (= `var(--font-anuphan), "Noto Sans Thai", system-ui, sans-serif`) |
| `display` / `titleLg` / `titleMd` / `titleSm` | `displaySmall` / `headlineSmall` / `titleLarge` / `titleMedium` | `--zk-type-display` / `-title-lg` / `-title-md` / `-title-sm` |
| `bodyLg` / `bodyMd` / `bodySm` | `bodyLarge` / `bodyMedium` / `bodySmall` | `--zk-type-body-lg` / `-md` / `-sm` |
| `labelLg` / `labelMd` / `labelSm` | `labelLarge` / `labelMedium` / `labelSmall` | `--zk-type-label-lg` / `-md` / `-sm` |
| `caption`, `price`, `priceLg` | `ZokyTextStyles.caption/price/priceLg` | `--zk-type-caption` / `-price` / `-price-lg` |
| `spacing.N` | `ZokySpacing.sN` (double const) | `--zk-space-N` |
| `radius.xs…full` | `ZokyRadius.xs…full` (`BorderRadius.circular`) | `--zk-radius-xs` … `--zk-radius-full` |
| `elevation.0–5, brand` | `ZokyShadows.e0…e5, brand` (`List<BoxShadow>`) | `--zk-shadow-0` … `--zk-shadow-5`, `--zk-shadow-brand` |
| `motion.duration.*` / `easing.*` | `ZokyMotion.*` (`Duration`, `Cubic`) | `--zk-dur-*`, `--zk-ease-*` |
| `size.tapTarget` | `kMinInteractiveDimension` (48) / iOS 44 | `--zk-tap-min` (44px) |

หมายเหตุ CSS typography: ประกาศแบบ composite ไม่ได้ ให้แยกเป็น `--zk-type-*-size`, `-weight`, `-lh` ตอน implement

---

## 13. Handoff

- **Software Architect**: ยืนยันรูปแบบการ consume `tokens.json` (สร้างโค้ดอัตโนมัติ หรือคัดลอกด้วยมือ), ชื่อ class ฝั่ง Flutter (`ZokyColors`/`ZokyTextStyles`/...), dependency ของไอคอน Lucide และ map ฝั่ง Flutter รวมถึงการ bundle ฟอนต์
- **AI Coding (web)**: เพิ่ม `--zk-*` → ไล่ทุกจุดที่ใช้ `--fx-red` แล้วแยกเป็น 3 บทบาทตาม 12.1 → แก้ success/muted/control border ตามข้อ 0 → เปลี่ยน asset/metadata/splash/theme-color เมื่อ asset A1–A18 พร้อม (ห้ามใช้ไฟล์ draft 1024 ใน production)
- **AI Coding (Flutter)**: `ThemeData` (useMaterial3, light only), `ColorScheme` ตาม 12.1, `surfaceTint` transparent, `pageTransitionsTheme` แยกตาม platform ตามข้อ 11, widget แบบ adaptive ตาม 11.2
- **QA & Security**: ตรวจ contrast ซ้ำด้วยเครื่องมือ, text scale 200% บน flow หลัก, VoiceOver/TalkBack, tap target, reduced motion, ตรวจด้วยตาว่าไอคอนบนเครื่องจริงไม่มีขอบซ้อน
- เอกสารนี้ไม่เปลี่ยน flow, scope หรือ copy ของ product ถ้ามีจุดขัดกับ PRD/parity ของ PM ให้ยึด PRD และแจ้ง Design

---

## 14. คำถามเปิดสำหรับ Founder

| # | คำถาม | ข้อเสนอของ Design |
|---|---|---|
| Q1 | Dark mode: ทำใน v1 หรือไม่ (เว็บ Food ตอนนี้ไม่มี) | **v1 light-only** เพื่อ parity แล้วทำ dark ใน phase ถัดไปตามข้อ 3.6 |
| Q2 | ปุ่ม/cart bar ใช้ Pink Deep `#D61256` (ผ่าน AA) หรืออยากได้ `#F21967` ที่สดกว่า | **A (แนะนำ)**: Pink Deep / B: `#F21967` แต่ label ต้อง ≥19px bold (ปุ่มจะใหญ่ขึ้น) / C: `#F21967` + label 16px (ไม่ผ่าน AA ต้องบันทึกว่า Founder ยอมรับความเสี่ยง) |
| Q3 | ใครทำ master vector ของโลโก้ (A1) และไอคอน production โดยไม่มีกรอบติดมา | จ้าง/ให้ designer trace จากต้นฉบับ แล้ว Founder เทียบกับไฟล์ JPG ก่อนอนุมัติ |
| Q4 | Favicon 16px: ยอมให้ wordmark อ่านไม่ออก หรืออนุญาตให้ทำเวอร์ชันย่อ (เช่น หมุดอย่างเดียว) เฉพาะ ≤16px | ยอมรับไปก่อน (ไม่แก้โลโก้) |
| Q5 | อนุญาตให้มี wordmark สีชมพูบนพื้นขาวไหม (ใช้ใน header/OG) | ยังไม่ทำ ใช้ primary mark แทน |
| Q6 | เว็บตั้ง `userScalable: false` ทำให้ผู้ใช้ซูมไม่ได้ (ขัด WCAG 1.4.4) จะเปิดให้ซูมได้ไหม (input เป็น 16px อยู่แล้ว iOS จึงไม่ auto-zoom) | เปิดให้ซูมได้ |
| Q7 | `seller_app` และ marketplace ใน `app/` ยังใช้ ZOKY Orange (DS-001/DS-007) จะย้ายมาใช้ชมพูด้วยไหม | ตัดสินแยกหลังลูกค้า ZOKY เปิดตัว |
| Q8 | ทำ iOS Dark/Tinted icon (A3) และ Liquid Glass layers ของ iOS 26 ไหม | ทำ Dark/Tinted ใน v1, Liquid Glass ไว้ทีหลัง |
| Q9 | ยืนยัน license ของ Anuphan (OFL 1.1) สำหรับ bundle ในแอป store | ให้ Architect/QA ตรวจไฟล์ license ก่อน |
| Q10 | theme-color/status bar ของเว็บ: เปลี่ยนจากแดงทั้งแถบเป็น Cloud White (ขาวเด่น ตรงกติกา 80/20) โดยให้ชมพูเฉพาะตอน splash | ใช้ Cloud White |
| Q11 | ควรบันทึกการตัดสินใจ "ZOKY Pink แทน rainbow สำหรับ ZOKY" และ "ZOKY Pink แทน ZOKY Orange" ลง `.wyn/company/DECISIONS.md` ไหม (Design ไม่ได้แก้ไฟล์นั้น) | บันทึก |
