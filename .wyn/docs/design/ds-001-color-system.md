# DS-001 — WYN Design System: Color / Typography / Spacing Foundation

> สถานะ: **PROPOSED — รอ Founder ตัดสินใจ Q1 (ยืนยันเปลี่ยนสีหรือไม่)**
> ผู้จัดทำ: AI Design | วันที่: 2026-08-15 | อ้างอิง task: `.wyn/tasks/backlog/DS-001-design-system-audit.md`
> เอกสารนี้ **ยังไม่ใช่กติกาที่อนุมัติแล้ว** — `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray) ยังเป็นของจริงอยู่จนกว่า Founder จะยืนยันเปลี่ยน
> หน้าเปรียบเทียบให้ดูตัดสินใจ: `palette_compare.html` (ไฟล์ HTML ที่ AI Design ทำคู่กับเอกสารนี้)

---

## 0. สรุปข้อค้นพบที่ Founder ต้องรู้ก่อนตัดสินใจ

Palette ที่ Founder เสนอ (Cyan `#00C8FF` + Orange `#FF6B35`) **สวยมากบนพื้นดำ แต่ตกเกณฑ์ WCAG AA บนพื้นขาว**

| สี | บนพื้นขาว `#FFFFFF` | บนพื้นดำ `#0A0A0A` | สรุป |
|---|---|---|---|
| Cyan `#00C8FF` | **1.96:1** ❌ | 10.09:1 ✅ | ใช้เป็นตัวหนังสือ/ปุ่มบนพื้นขาวไม่ได้เลย |
| Orange `#FF6B35` | **2.84:1** ❌ | 6.98:1 ✅ | ราคาสินค้าบนพื้นขาวอ่านไม่ผ่านเกณฑ์ |
| Blue `#2D6CDF` (ของเดิม) | 4.86:1 ✅ | 4.07:1 | ผ่านทั้งคู่ แต่เป็นน้ำเงิน Material ทั่วไป |

เกณฑ์ WCAG AA: ตัวหนังสือปกติ ≥ 4.5:1 / ตัวหนังสือใหญ่ (≥24px หรือ ≥19px ตัวหนา) และ UI component/ขอบปุ่ม ≥ 3.0:1

**นี่ไม่ใช่ปัญหา — มันคือคำใบ้ของแบรนด์**
Cyan + Orange บนพื้นดำได้ 10.09:1 และ 6.98:1 ซึ่งเป็นค่าที่ดีมาก แปลว่า palette ที่ Founder เลือกมาเอง **เรียกร้อง identity แบบ dark-first โดยธรรมชาติ** ตรงกับคอนเซปต์ "Black + White + Cyan" ที่ Founder เขียนไว้เอง

ทางออกที่เอกสารนี้เสนอ: **สีแบรนด์ตัวเดียวกัน แต่คนละ "ระดับความเข้ม" ในแต่ละโหมด** — dark mode ใช้ Cyan สดเต็มที่ (นี่คือหน้าตาหลักของ WYN), light mode ใช้ Cyan เข้มขึ้นเป็น accent + ปุ่มหลักเป็นสีดำ ผลลัพธ์คือผ่าน AA ทั้งสองโหมดโดยไม่ต้องทิ้งความเป็น Cyan

---

## 1. Design Rules ที่ยังบังคับใช้เหมือนเดิม (ยืนยัน ไม่เปลี่ยน)

มาจาก Founder (`.wyn/company/DECISIONS.md` 2026-08-14) — งานนี้ **ไม่แตะ** กติกาเหล่านี้:

1. **ห้ามใช้ Liquid Glass** — ไม่มี blur / translucent surface / frosted glass ทุกพื้นผิวทึบเสมอ (การ์ด, AppBar, BottomNav, Sheet, Dialog)
2. **ห้ามลอก Layout ของ Instagram / TikTok** — และเพิ่มข้อใหม่ตามบรีฟรอบนี้: **ห้ามลอก Threads** ด้วย เอาได้แค่ "ความเรียบ" (whitespace เยอะ, เส้นน้อย, สีน้อย) ไม่เอาโครงหน้าจอ/ลำดับ element/ท่า interaction ของเขา
3. **รองรับ Light + Dark ตั้งแต่ต้น** — ทั้งสองโหมดต้องผ่าน AA ไม่ใช่ทำ dark แล้ว light พัง
4. **สีสถานะไม่ประดิษฐ์ใหม่** — เขียว success / แดง error / เหลือง warning / **หัวใจ Like ยังเป็นแดง** (universal convention) ไม่ใช่สี primary
5. **ไม่สื่อสารด้วยสีอย่างเดียว** — สถานะออเดอร์/ป้ายต่าง ๆ ต้องมีข้อความหรือไอคอนกำกับเสมอ (คนตาบอดสีต้องใช้งานได้)

### กติกาใหม่เฉพาะ palette นี้

6. **Cyan เป็น accent เท่านั้น** — ห้ามเป็นพื้นหลังขนาดใหญ่ นิยามเชิงปฏิบัติ: พื้นที่สี Cyan ต่อเนื่องต้อง **ไม่เกิน ~15% ของหน้าจอ** และ **ห้ามใช้กับ**: พื้นหลังหน้าจอ, AppBar เต็มความกว้าง, BottomNav bar, hero/banner เต็มจอ, พื้นหลังการ์ด — **ใช้ได้กับ**: ปุ่มหลัก (dark mode), ไอคอน/แท็บที่ active, ลิงก์, badge, focus ring, เส้น indicator, progress
7. **Orange เป็นของ ZOKY เท่านั้น** — ห้ามโผล่ในหน้า Social (Home/Drop/Pop/Club/Profile/Search/Notification) และห้ามเปลี่ยนทั้งหน้าจอ ZOKY เป็นส้ม (ดูข้อ 5)
8. **Cyan กับ Orange ห้ามอยู่ติดกันเป็นคู่สี** — ห้ามใช้ Cyan เป็นพื้นแล้ววาง Orange ทับ (หรือกลับกัน) เพราะ contrast ระหว่างกันต่ำมากและตีกันทางสายตา ให้ใช้ neutral (ดำ/ขาว/เทา) คั่นเสมอ

---

## 2. Color Scale (ค่าเต็ม พร้อม contrast ที่คำนวณแล้ว)

> ตัวเลข contrast ทุกตัวคำนวณตามสูตร WCAG 2.1 relative luminance
> ✅ = ใช้เป็นตัวหนังสือปกติได้ (≥4.5) | ⚠️ = ใช้ได้เฉพาะตัวใหญ่/ไอคอน/ขอบ (≥3.0) | ❌ = ห้ามใช้กับตัวหนังสือ

### 2.1 WYN Cyan (สีแบรนด์หลัก)

| Token | HEX | vs White | vs `#0A0A0A` | ใช้ตรงไหน |
|---|---|---|---|---|
| `cyan-50` | `#E6F9FF` | — | — | พื้นชิป/สถานะ selected ขนาดเล็ก (light) เท่านั้น |
| `cyan-100` | `#CCF2FF` | — | — | ตัวหนังสือบน `cyan-950` (dark container) |
| `cyan-300` | `#66DDFF` | 1.53 ❌ | 15.0 ✅ | **ลิงก์/ตัวหนังสือเน้นใน dark mode** |
| `cyan-500` | `#00C8FF` | **1.96 ❌** | **10.09 ✅** | **สีแบรนด์แกนกลาง — ปุ่มหลัก/ไอคอน active ใน dark mode** |
| `cyan-600` | `#00A3D9` | 2.90 ❌ | 7.0 | สถานะ hover/pressed ของ `cyan-500` (dark) — ห้ามใช้กับตัวหนังสือบนขาว |
| `cyan-700` | `#0090C4` | **3.63 ⚠️** | — | ขอบปุ่ม/ไอคอน/ตัวใหญ่ ≥24px บน light |
| `cyan-800` | `#00739E` | **5.32 ✅** | — | **primary ของ light mode** — ตัวหนังสือ/ไอคอน/พื้นปุ่มคู่กับตัวอักษรขาว (ขาวบนพื้นนี้ = 5.32 ✅) |
| `cyan-900` | `#00658A` | **6.50 ✅** | — | ลิงก์/ตัวหนังสือเน้นหนักบน light, สถานะ pressed ของปุ่ม |
| `cyan-950` | `#003D54` | 12.0 ✅ | — | พื้น container ใน dark mode (คู่กับ `cyan-100` = 9.86 ✅) |

หมายเหตุ: `#0082B3` (4.34:1) อยู่ระหว่าง 700 กับ 800 — **ไม่รับเข้า scale** เพราะเป็นค่าที่ "เกือบผ่าน" ซึ่งอันตรายที่สุด (นักพัฒนาจะเผลอใช้เป็นตัวหนังสือ)

### 2.2 ZOKY Orange (commerce layer)

| Token | HEX | vs White | vs `#0A0A0A` | ใช้ตรงไหน |
|---|---|---|---|---|
| `orange-50` | `#FFF1EC` | — | — | พื้นชิป "ลดราคา"/แท็กเล็ก (light) |
| `orange-500` | `#FF6B35` | **2.84 ❌** | **6.98 ✅** | **สีแบรนด์ ZOKY แกนกลาง — ราคา/ปุ่มใน dark mode** |
| `orange-600` | `#E85A24` | 3.55 ⚠️ | — | ขอบ/ไอคอน/ตัวใหญ่บน light, hover ของ 500 |
| `orange-700` | `#CC4A16` | **4.61 ✅** | — | **ราคา + ปุ่ม CTA ของ ZOKY ใน light mode** (ตัวอักษรขาวบนพื้นนี้ = 4.61 ✅) |
| `orange-800` | `#A63A10` | **6.49 ✅** | — | ราคาที่ต้องเน้นหนัก/สถานะ pressed |

### 2.3 Neutral (โครงหลักของทั้งระบบ)

| Token | HEX | หมายเหตุ contrast |
|---|---|---|
| `ink` | `#0A0A0A` | บนขาว **19.8 ✅** — ตัวหนังสือหลัก light mode + พื้นปุ่มหลัก light mode |
| `white` | `#FFFFFF` | ตัวหนังสือหลัก dark mode (บน `#111111` = 18.9 ✅) |
| `gray-500` | `#6B7280` | บนขาว **4.83 ✅** — ตัวหนังสือรอง light mode / **บน `#111111` = 3.91 ❌ ห้ามใช้เป็นตัวหนังสือใน dark** |
| `gray-400` | `#9CA3AF` | บนขาว **2.54 ❌** (ไอคอนตกแต่ง/placeholder เท่านั้น) / บน `#111111` = **7.44 ✅** ตัวหนังสือรอง dark mode |
| `border-subtle-light` | `#E5E7EB` | เส้นแบ่ง/hairline (ตกแต่ง — WCAG ยกเว้น) |
| `border-strong-light` | `#8B929C` | บนขาว **3.14 ✅ (UI ≥3.0)** — ขอบ input/ปุ่ม secondary/focus ring ใน light |
| `surface-muted-light` | `#F7F8FA` | พื้นรอง (search bar, chip, skeleton) |
| `bg-dark` | `#000000` | พื้นหลังหน้าจอ dark |
| `surface-dark` | `#111111` | การ์ด/sheet/AppBar dark |
| `surface-muted-dark` | `#1A1A1A` | พื้นรอง dark (search bar, chip) |
| `border-subtle-dark` | `#222222` | เส้นแบ่ง dark (ตกแต่ง — **1.32:1 ห้ามใช้เป็นขอบของสิ่งที่กดได้**) |
| `border-strong-dark` | `#666666` | บน `#000000` = **3.66 ✅** / บน `#111111` = **3.29 ✅** — ขอบ input/ปุ่ม secondary/focus ring ใน dark |

> **จุดที่คนพลาดบ่อยที่สุด**: `#E5E7EB` (1.2:1) และ `#222222` (1.32:1) ที่ Founder ระบุมา **ใช้เป็นขอบของ input/ปุ่มที่กดได้ไม่ได้** เพราะ WCAG 1.4.11 บังคับ 3.0:1 สำหรับ UI component — เอกสารนี้จึงเพิ่ม `border-strong` ขึ้นมาอีกชั้น ใช้ `border-subtle` กับเส้นแบ่งตกแต่ง (divider ระหว่างการ์ด) เท่านั้น

### 2.4 สีสถานะ (Semantic)

| ความหมาย | Light | vs White | Dark | vs `#111111` |
|---|---|---|---|---|
| Success | `#15803D` | 5.02 ✅ | `#4ADE80` | 10.8 ✅ |
| Error / Destructive | `#DC2626` | 4.83 ✅ | `#F87171` | 6.83 ✅ |
| Warning | `#B45309` | 5.02 ✅ | `#FBBF24` | 11.3 ✅ |
| Like (หัวใจ) | `#E11D48` | 4.70 ✅ | `#FB7185` | 7.02 ✅ |

หมายเหตุ Like: ปัจจุบันโค้ดใช้ `Colors.red` (`#F44336` = 3.68:1 บนขาว) ซึ่งผ่านสำหรับ **ไอคอน** แต่ไม่ผ่านถ้าเอาไปทำตัวหนังสือ — เปลี่ยนเป็น `#E11D48` แล้วผ่านทั้งสองกรณี และเข้ากับโทน neutral ใหม่ดีกว่าแดงส้มของ Material

---

## 3. Flutter `ColorScheme` Mapping (Material 3)

ทั้งสองแอปตั้ง `ThemeData(useMaterial3: true, colorScheme: ...)` แบบระบุค่าตรง ๆ **เลิกใช้ `colorSchemeSeed`** เพราะ seed จะ generate โทนของ Material เอง ทำให้คุมสีแบรนด์ไม่ได้ (นี่คือสาเหตุที่ตอนนี้หน้าตาเป็น "Material default")

### 3.1 WYN Social — Light

| ColorScheme slot | ค่า | เหตุผล / contrast |
|---|---|---|
| `brightness` | `light` | |
| `primary` | `cyan-800 #00739E` | สีแบรนด์ที่ปลอดภัยบนพื้นขาว |
| `onPrimary` | `#FFFFFF` | ขาวบน `#00739E` = **5.32 ✅** |
| `primaryContainer` | `cyan-50 #E6F9FF` | ชิป/สถานะ selected เล็ก ๆ |
| `onPrimaryContainer` | `cyan-900 #00658A` | **5.99 ✅** |
| `secondary` | `ink #0A0A0A` | **ปุ่มหลักของหน้า (hero CTA) เป็นสีดำ** ไม่ใช่สี Cyan — ดูเหตุผลข้อ 3.3 |
| `onSecondary` | `#FFFFFF` | **19.8 ✅** |
| `secondaryContainer` | `#F2F4F7` | ปุ่ม tonal / chip |
| `onSecondaryContainer` | `ink #0A0A0A` | ✅ |
| `tertiary` | `cyan-900 #00658A` | ลิงก์/ข้อความเน้น (**6.50 ✅**) |
| `onTertiary` | `#FFFFFF` | ✅ |
| `error` | `#DC2626` | 4.83 ✅ |
| `onError` | `#FFFFFF` | 4.83 ✅ |
| `errorContainer` | `#FEE2E2` | |
| `onErrorContainer` | `#7F1D1D` | ✅ |
| `surface` | `#FFFFFF` | พื้นหลังหลัก (Flutter 3.22+ ใช้ `surface` แทน `background`) |
| `onSurface` | `ink #0A0A0A` | **19.8 ✅** |
| `onSurfaceVariant` | `gray-500 #6B7280` | ตัวหนังสือรอง **4.83 ✅** |
| `surfaceContainerLowest` | `#FFFFFF` | |
| `surfaceContainerLow` | `#FAFBFC` | |
| `surfaceContainer` | `#F7F8FA` | search bar / input พื้นเทาอ่อน |
| `surfaceContainerHigh` | `#F2F4F7` | |
| `surfaceContainerHighest` | `#EDEFF3` | |
| `outlineVariant` | `#E5E7EB` | เส้นแบ่งเท่านั้น |
| `outline` | `#8B929C` | ขอบของสิ่งที่กดได้ **3.14 ✅** |
| `inverseSurface` | `ink #0A0A0A` | Snackbar |
| `onInverseSurface` | `#FFFFFF` | |
| `inversePrimary` | `cyan-500 #00C8FF` | Cyan สดบน Snackbar สีดำ **10.09 ✅** |
| `shadow` / `scrim` | `#000000` | |

### 3.2 WYN Social — Dark (โหมดหลักของแบรนด์)

| ColorScheme slot | ค่า | เหตุผล / contrast |
|---|---|---|
| `brightness` | `dark` | |
| `primary` | `cyan-500 #00C8FF` | **สีแบรนด์เต็มความสด — นี่คือหน้าตาที่ Founder อยากได้** |
| `onPrimary` | `ink #0A0A0A` | ดำบน Cyan = **10.09 ✅** (ห้ามใช้ตัวอักษรขาวบน Cyan เด็ดขาด = 1.96 ❌) |
| `primaryContainer` | `cyan-950 #003D54` | |
| `onPrimaryContainer` | `cyan-100 #CCF2FF` | **9.86 ✅** |
| `secondary` | `#FFFFFF` | hero CTA ใน dark = ปุ่มขาวตัวอักษรดำ (คู่ตรงข้ามของ light) |
| `onSecondary` | `ink #0A0A0A` | ✅ |
| `secondaryContainer` | `#1A1A1A` | |
| `onSecondaryContainer` | `#FFFFFF` | ✅ |
| `tertiary` | `cyan-300 #66DDFF` | ลิงก์บนพื้นดำ **~12 ✅** |
| `onTertiary` | `ink #0A0A0A` | ✅ |
| `error` | `#F87171` | 6.83 ✅ |
| `onError` | `ink #0A0A0A` | 7.16 ✅ |
| `surface` | `#000000` | พื้นหลัง OLED ดำสนิท |
| `onSurface` | `#FFFFFF` | **21 ✅** |
| `onSurfaceVariant` | `gray-400 #9CA3AF` | **8.27 ✅** (ห้ามใช้ `#6B7280` ที่นี่ = 3.91 ❌) |
| `surfaceContainerLowest` | `#000000` | |
| `surfaceContainerLow` | `#0A0A0A` | |
| `surfaceContainer` | `#111111` | การ์ด / AppBar / BottomNav |
| `surfaceContainerHigh` | `#1A1A1A` | |
| `surfaceContainerHighest` | `#222222` | |
| `outlineVariant` | `#222222` | เส้นแบ่งเท่านั้น |
| `outline` | `#666666` | ขอบของสิ่งที่กดได้ **3.66 ✅** |
| `inverseSurface` | `#FFFFFF` | |
| `onInverseSurface` | `ink #0A0A0A` | |
| `inversePrimary` | `cyan-800 #00739E` | |

### 3.3 ทำไมปุ่มหลักถึงเป็นสีดำ/ขาว ไม่ใช่ Cyan

ใน light mode ถ้าจะให้ปุ่มเป็น Cyan และอ่านออกจริง ต้องใช้ `#00739E` ซึ่งเข้มจนคนทั่วไปอ่านว่า "น้ำเงินเข้ม" ไม่ใช่ Cyan อยู่ดี — เท่ากับได้สีที่ไม่สวยและไม่ตรงแบรนด์พร้อมกัน
ทางที่ได้ทั้งสองอย่างคือ **ให้ปุ่มหลักเป็น neutral (ดำใน light / ขาวใน dark) แล้วปล่อยให้ Cyan ทำหน้าที่เป็น "จุดที่แบรนด์ปรากฏ"** ได้แก่ ไอคอนแท็บที่ active, ลิงก์, badge, focus ring, indicator, ปุ่มหลักใน dark mode
ผลลัพธ์: หน้าจอเงียบ สะอาด แบบ minimal social platform และ Cyan ได้เป็น "เสียง" ของแบรนด์จริง ๆ แทนที่จะถูกเจือจางจนกลายเป็นน้ำเงินธรรมดา

> นี่ไม่ใช่การลอก Threads — ปุ่ม neutral เป็น pattern สากล (ระบบ design ของ Apple, Vercel, Linear ก็ใช้) สิ่งที่ห้ามลอกคือ **โครงหน้าจอ/ลำดับ element** ซึ่งเราไม่ได้แตะเลย (Home ของ WYN ยังคงมี Search + Club section + toggle "สำหรับคุณ / จาก Club ของคุณ" + BottomNav 5 แท็บ ซึ่งไม่มีแอปไหนเหมือน)

### 3.4 ZOKY sub-theme (สร้างจาก base เดิม เปลี่ยนเฉพาะ accent)

```
ZokyTheme = WynTheme.copyWith(colorScheme:
  light: tertiary: orange-700 #CC4A16, onTertiary: #FFFFFF,
         tertiaryContainer: orange-50 #FFF1EC, onTertiaryContainer: orange-800 #A63A10
  dark:  tertiary: orange-500 #FF6B35, onTertiary: ink #0A0A0A,
         tertiaryContainer: #3A1608,      onTertiaryContainer: #FFD9C9
)
```

`primary`/`surface`/`outline`/typography **เหมือน WYN ทุกประการ** — สิ่งเดียวที่เปลี่ยนคือช่อง `tertiary` ทำให้โค้ด ZOKY เรียก `colorScheme.tertiary` ได้ที่เดียวแล้วได้ส้มอัตโนมัติ ส่วนแอป Social เรียกช่องเดียวกันแล้วได้ Cyan เข้ม (ไม่มีทางหลุดข้ามฝั่ง)

---

## 4. ZOKY Orange — ใช้ตรงไหนได้ / ห้ามใช้ตรงไหน

### ✅ ใช้ได้ (5 กรณีเท่านั้น)

| # | จุด | รายละเอียด | ไฟล์ที่เกี่ยวข้อง |
|---|---|---|---|
| 1 | **ราคา** | ตัวเลขราคาสินค้าทุกที่ (grid tile, product detail, cart, checkout summary, order detail) — light `#CC4A16`, dark `#FF6B35` | `product_grid_tile.dart`, `product_detail_screen`, `cart`, `order` |
| 2 | **ปุ่ม commerce CTA** | "เพิ่มลงตะกร้า", "ซื้อเลย", "สั่งซื้อ", "ชำระเงิน" — พื้นส้ม + ตัวอักษร (ขาวใน light / ดำใน dark) | ZOKY checkout flow |
| 3 | **Seller badge / ป้ายร้าน** | ป้าย "ร้านค้า", "ZOKY Verified", ชื่อร้านที่กดได้ | `store_screen`, ป้ายบนการ์ดสินค้า |
| 4 | **Commerce state ที่เป็นบวก** | "จัดส่งแล้ว"/"กำลังจัดส่ง"/แถบ progress ของออเดอร์ (ยกเว้นสถานะ error/cancel ที่ต้องใช้สีแดง semantic) | `OrderStatusBadge` |
| 5 | **จุด entry ของ ZOKY** | ไอคอนแท็บ ZOKY ตอน active ใน BottomNav, badge จำนวนของในตะกร้า | `root_shell.dart` |

### ❌ ห้ามใช้เด็ดขาด

- พื้นหลังหน้าจอ / AppBar / BottomNav bar / hero banner เต็มความกว้าง
- พื้นการ์ดสินค้า (การ์ดยังเป็น surface ขาว/ดำ ส้มอยู่แค่ตัวเลขราคาและปุ่ม)
- ทุกหน้าจอฝั่ง Social (Home, Drop, Pop, Club, Profile, Search, Notification) — รวมถึงตอนที่ผลการค้นหา ZOKY โผล่ในหน้า Search รวม: ราคายังเป็นส้มได้ (ข้อ 1) แต่ปุ่ม/แท็บ/หัวข้อยังเป็น neutral
- สีสถานะ error/warning (ต้องใช้ `#DC2626`/`#B45309` เพราะส้มกับแดงแยกกันไม่ออกสำหรับคนตาบอดสี)
- วางทับ/ติดกับ Cyan โดยตรง
- สัดส่วนพื้นที่ส้มบนหน้าจอ ZOKY ต้อง **ไม่เกิน ~20%**

### `seller_app/` (ZOKY Sellers by WYN)

แอปนี้ **คือ commerce layer ทั้งแอป** จึงใช้ ZOKY sub-theme เป็น theme หลัก และผ่อนข้อจำกัดได้ 1 ข้อ: ส้มเป็นสี accent หลักของแอป (แท็บ active, ปุ่มหลัก, ตัวเลขยอดขาย) — แต่กติกา "ห้ามเป็นพื้นหลังขนาดใหญ่" ยังบังคับเหมือนเดิม และ Cyan **ห้ามปรากฏใน seller_app เลย** (คนละ identity ชัดเจน: ลูกค้าเห็น Cyan, ร้านค้าเห็น Orange)

---

## 5. Typography Scale

**ฟอนต์**: ใช้ฟอนต์ระบบ (San Francisco บน iOS / Roboto บน Android) — ทั้งคู่มี glyph ภาษาไทยครบและ hint ดีบนจอเล็ก **ไม่เพิ่ม dependency ฟอนต์ในรอบนี้** (ตรวจแล้ว `app/pubspec.yaml` ไม่มี `google_fonts` และไม่มี `fonts:` section) DS-001 ปรับเฉพาะ **ขนาด/น้ำหนัก/line-height/letter-spacing** ผ่าน `TextTheme` ซึ่งได้ผลลัพธ์ทางสายตา ~80% ของการเปลี่ยนฟอนต์ โดยไม่เพิ่มขนาด binary และไม่เสี่ยงเรื่อง license
ถ้าจะเปลี่ยนฟอนต์จริงในอนาคต ตัวเลือกที่รองรับไทย+อังกฤษดี: **IBM Plex Sans Thai**, **Noto Sans Thai**, **Anuphan** — ต้องเป็นงานแยก task เพราะกระทบ layout ทุกหน้า

| Token (`TextTheme`) | ขนาด | น้ำหนัก | line-height | Letter-spacing | ใช้กับ |
|---|---|---|---|---|---|
| `headlineLarge` | 28 | 700 | 1.25 (35) | -0.4 | หัวข้อ hero (หน้า onboarding/empty state) |
| `headlineMedium` | 24 | 700 | 1.29 (31) | -0.3 | ชื่อหน้าจอใหญ่, ชื่อโปรไฟล์ |
| `headlineSmall` | 20 | 600 | 1.30 (26) | -0.2 | หัวข้อ section, หัวข้อ dialog |
| `titleLarge` | 18 | 600 | 1.33 (24) | -0.1 | AppBar title, ชื่อ Club |
| `titleMedium` | 16 | 600 | 1.38 (22) | 0 | ชื่อสินค้า, หัวการ์ด |
| `titleSmall` | 14 | 600 | 1.43 (20) | 0 | **ชื่อผู้เขียนบนการ์ด feed** (ตรงกับที่ `home_drop_card.dart` ใช้อยู่แล้ว) |
| `bodyLarge` | 16 | 400 | 1.50 (24) | 0 | ข้อความอ่านหลัก (แคปชัน Drop, โพสต์ Club, รายละเอียดสินค้า) |
| `bodyMedium` | 14 | 400 | 1.50 (21) | 0 | body ค่าเริ่มต้นของทั้งแอป (**ขั้นต่ำตามกติกา 14px ✅**) |
| `bodySmall` | 14 | 400 | 1.43 (20) | 0 | ข้อความรอง (สี `onSurfaceVariant`) — ขนาดเท่า bodyMedium แต่ต่างที่สี **ไม่ลดต่ำกว่า 14** |
| `labelLarge` | 15 | 600 | 1.33 (20) | 0.1 | ตัวหนังสือบนปุ่ม |
| `labelMedium` | 13 | 600 | 1.23 (16) | 0.1 | ชิป, แท็บ, ป้ายสถานะ |
| `labelSmall` | 12 | 500 | 1.33 (16) | 0.2 | **metadata เท่านั้น** — เวลา ("2 ชม."), ตัวนับ, ป้ายเล็ก **ห้ามใช้กับเนื้อหาที่ผู้ใช้ต้องอ่าน** |

### กติกา Typography

1. **ระดับตัวอักษรในหน้าเดียวไม่เกิน 4 ระดับ** — บังคับให้ hierarchy มาจากน้ำหนัก/สี ไม่ใช่การไล่ขนาดถี่ ๆ (นี่คือสิ่งที่ทำให้หน้าจอดู "เรียบ" จริง ไม่ใช่การเอาเส้นออก)
2. **ภาษาไทยต้องการ line-height สูงกว่าอังกฤษ** เพราะมีสระบน/ล่าง — line-height ทุก body ต้อง ≥ 1.43 (ตารางด้านบนทำครบแล้ว) และ**ห้ามใส่ `maxLines` โดยไม่ตั้ง `height`** ไม่งั้นสระบนจะโดนตัด
3. **รองรับ dynamic type** — ห้ามใส่ `textScaler: TextScaler.noScaling` ทุกหน้าจอต้องไม่พังที่ 130% (ทดสอบด้วย `MediaQuery` override ใน widget test)
4. `labelSmall` (12px) เป็นขนาดเล็กสุดในระบบ **ห้ามมีอะไรต่ำกว่านี้**
5. ตัวเลขราคา ZOKY ใช้ `titleMedium` + `FontWeight.w700` + สี tertiary (ไม่ต้องมี token ราคาแยก)

---

## 6. Spacing / Radius / Touch Target

### Spacing (4px grid)

| Token | ค่า | ใช้กับ |
|---|---|---|
| `space1` | 4 | ช่องไฟระหว่างไอคอนกับตัวเลขนับ |
| `space2` | 8 | ช่องไฟภายใน component |
| `space3` | 12 | padding ด้านข้างของ list item |
| `space4` | 16 | **padding ขอบจอมาตรฐาน** และช่องไฟระหว่าง element ในกลุ่มเดียวกัน |
| `space5` | 20 | |
| `space6` | 24 | ช่องไฟระหว่างกลุ่ม/section |
| `space8` | 32 | ช่องไฟระหว่าง block ใหญ่ |
| `space10` | 40 | |
| `space12` | 48 | ช่องว่างบน/ล่างของ empty state |

กติกา: **ห้ามใส่ค่า padding/margin ที่ไม่ได้อยู่ในตารางนี้** (ยกเว้นการชดเชยเชิงแสงของไอคอน ต้องมี comment กำกับ)
ปัจจุบันโค้ดใช้ 4/8/12/16 อยู่แล้วเป็นส่วนใหญ่ (ดู `home_drop_card.dart`) → migration cost ต่ำ

### Radius

| Token | ค่า | ใช้กับ |
|---|---|---|
| `radiusNone` | 0 | รูปภาพเต็มความกว้างใน feed (ให้ภาพเป็นพระเอก) |
| `radiusSm` | 8 | ชิป, badge, thumbnail เล็ก |
| `radiusMd` | 12 | **ค่าเริ่มต้น** — ปุ่ม, input, การ์ด |
| `radiusLg` | 16 | bottom sheet, dialog, การ์ดสินค้า ZOKY |
| `radiusFull` | 999 | avatar, ปุ่มกลม, pill |

### Touch Target

- ขั้นต่ำ **44×44** ทุกสิ่งที่กดได้ (แนะนำ 48×48 = ค่า default ของ Flutter `MaterialTapTargetSize.padded`)
- **ห้ามลด** `visualDensity` หรือใช้ `MaterialTapTargetSize.shrinkWrap` เพื่อให้ layout สวยขึ้น — ให้ลดขนาดไอคอนแทน (ไอคอน 20px ในกล่องกด 44px ได้)
- ระยะห่างระหว่าง target ที่กดได้ ≥ 8px
- Focus ring: เส้น 2px สี `outline` (`#8B929C` light / `#666666` dark) เว้นจากขอบ 2px — จำเป็นสำหรับผู้ใช้คีย์บอร์ด/switch control

---

## 7. Token file ควรอยู่ที่ไหน (โครงสร้างโค้ดจริง)

### ข้อจำกัดที่ต้องเคารพ

`.wyn/company/DECISIONS.md` (2026-08-15) ตัดสินไว้แล้วว่า: **ไม่ใช้ Melos/monorepo tooling** และ **ไม่สร้าง shared package** — ให้ duplicate seed color เข้า `seller_app/main.dart` ตรง ๆ
ขณะที่ DS-001 Acceptance Criteria เขียนว่า "ทั้ง 2 แอปอ้างอิงแหล่งเดียวกัน ไม่มี seed color duplicate" → **สองข้อนี้ขัดกัน** เอกสารนี้แก้ด้วยการนิยาม "แหล่งความจริงเดียว" ใหม่ให้เป็นเชิงกระบวนการแทนเชิง package

### โครงสร้างที่เสนอ

```
app/lib/core/design/            <-- CANONICAL (แหล่งความจริง)
  wyn_colors.dart               ค่าสีทั้งหมด + ColorScheme light/dark
  wyn_typography.dart           TextTheme
  wyn_spacing.dart              spacing / radius / touch target constants
  wyn_theme.dart                ประกอบเป็น ThemeData + zokyTheme sub-theme

seller_app/lib/core/design/     <-- MIRROR (สำเนาตรงตัวอักษร)
  wyn_colors.dart
  wyn_typography.dart
  wyn_spacing.dart
  wyn_theme.dart
```

- ทั้ง 4 ไฟล์ขึ้นต้นด้วย header comment:
  `// CANONICAL SOURCE: app/lib/core/design/<file> — DO NOT EDIT THE MIRROR IN seller_app/ DIRECTLY.`
- `app/lib/main.dart` และ `seller_app/lib/main.dart` เหลือแค่ `theme: WynTheme.light, darkTheme: WynTheme.dark` (seller ใช้ `WynTheme.zokyLight/zokyDark`) — ไม่มีค่าสีดิบใน `main.dart` อีกต่อไป

### วิธีกัน drift (ทำให้ "แหล่งความจริงเดียว" เป็นจริงโดยไม่ต้องมี package)

เพิ่ม test 1 ตัวใน `seller_app/test/design/token_sync_test.dart` ที่อ่านไฟล์ทั้งสองฝั่งด้วย `dart:io` แล้วเทียบเนื้อหา — ถ้าไม่ตรงกัน test แดงทันที:

```dart
// pseudo
for (final f in ['wyn_colors.dart', 'wyn_typography.dart', 'wyn_spacing.dart', 'wyn_theme.dart']) {
  expect(File('../app/lib/core/design/$f').readAsStringSync(),
         File('lib/core/design/$f').readAsStringSync(),
         reason: 'Design token drift: คัดลอกไฟล์จาก app/ มาทับ seller_app/');
}
```

ได้ผลลัพธ์เดียวกับ shared package (แก้ที่เดียว, drift ไม่หลุดผ่าน CI) โดยไม่ขัดคำตัดสินใจของ Founder และไม่ต้องลงทุนโครงสร้าง repo ใหม่

**ทางเลือกในอนาคต (ต้องขออนุมัติ Founder ก่อน)**: Flutter รองรับ path dependency (`wyn_design: {path: ../packages/wyn_design}`) โดย **ไม่ต้องใช้ Melos** ถ้าวันหนึ่งมีแอปที่ 3 (WYN Admin — Phase 6) หรือมี shared widget เยอะกว่า ~10 ไฟล์ ค่อยเสนออัปเกรด ตอนนี้ยังไม่คุ้ม

---

## 8. Handoff — ลำดับงานที่แนะนำให้ AI Coding

รอ Founder ยืนยัน palette ก่อน แล้วจึงทำตามลำดับนี้ (แต่ละข้อ = 1 PR, รัน 332 tests ทุกครั้ง):

1. **DS-001a** สร้าง 4 ไฟล์ token ใน `app/lib/core/design/` + เปลี่ยน `app/lib/main.dart` มาใช้ `WynTheme` (**ยังไม่แตะหน้าจอใด ๆ** — สีจะไหลไปทุกหน้าเองเพราะ audit ยืนยันแล้วว่ามี `Color(0x...)` แค่ 8 จุด)
2. **DS-001b** mirror เข้า `seller_app/` + test กัน drift + ZOKY sub-theme
3. **DS-001c** เปลี่ยน 8 จุดที่ hardcode สี (`Color(0x99000000)` ใน `product_grid_tile.dart` ฯลฯ) มาใช้ token + ราคาเป็น `colorScheme.tertiary`
4. จากนั้นค่อยเข้า DS-002 ถึง DS-008 ตาม breakdown ของ AI Product Manager

**สิ่งที่ QA ต้องตรวจเพิ่มในงานนี้**: screenshot ทุกหน้าหลักทั้ง light/dark, ทดสอบที่ textScale 130%, ยืนยันว่า `flutter test` ผ่าน 265+67, และไล่เช็คว่าไม่มี Cyan/Orange โผล่ผิดฝั่งตามข้อ 4

---

## 9. คำแนะนำสุดท้ายของ AI Design

**เลือกทางเลือก C (Cyan ฉบับผ่าน AA)** — ได้ identity Cyan ที่ Founder ต้องการ, dark mode สวยเต็มที่ตามที่ palette นี้เกิดมาเพื่อ, light mode ยังใช้งานได้จริงและผ่านมาตรฐาน โดยไม่ต้องเลือกระหว่าง "สวย" กับ "อ่านออก"
ถ้า Founder อยากได้ Cyan สดที่สุดจริง ๆ ทางเลือกเสริมคือ **ตั้ง WYN เป็นแอป dark-first** (default = dark, light เป็นทางเลือก) ซึ่ง palette นี้จะเปล่งประกายที่สุด — แต่ต้องเป็นคำตัดสินใจของ Founder เพราะกระทบภาพจำของแบรนด์ทั้งหมด
