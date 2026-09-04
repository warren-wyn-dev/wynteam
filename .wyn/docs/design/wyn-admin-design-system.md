# WYN Admin Design System — Black & White Premium (V1)

Status: APPROVED — Founder อนุมัติแล้ว (2026-09-04) หลังรีวิว mockup ส่งต่อ AI Coding ได้
Owner: AI Design
วันที่: 2026-09-04
ขอบเขต: `admin/` (WYN Admin, Next.js/TypeScript/Tailwind/shadcn) เท่านั้น — **ไม่แตะ** `app/`/`seller_app/` หรือ DS-001/design-principles.md ของ Consumer app เลยแม้แต่บรรทัดเดียว

อ้างอิงคำสั่งของ Founder (verbatim intent, สรุปโดย AI Design):
1. โทนขาว-ดำ ใช้สีน้อยที่สุด — สีปรากฏเฉพาะจุดที่สำคัญที่สุด (destructive action / critical alert-status / ปุ่ม primary action เดียวของหน้า) ไม่ใช่การตกแต่ง
2. หรูหรา พรีเมียม "แบบ Apple" — สงบ นิ่ง มั่นใจในตัวเอง whitespace เยอะ ตัวอักษรเป๊ะ ไม่มี visual noise
3. เข้าใจง่าย ไม่ซับซ้อน — Admin/Moderator ที่ใช้งานทุกวันต้องไม่รู้สึกหลงทาง
4. Feature-complete — ทุกหน้าต้องครอบคลุมสโคปฟังก์ชันเต็มของ WYN-05x spec ที่อนุมัติแล้ว การลดความซับซ้อนคือเรื่อง visual/interaction เท่านั้น ไม่ใช่การตัดฟีเจอร์

เอกสารนี้เป็น **แหล่งความจริงเดียว (single source of truth)** ของ visual language ทั้งหมดของ `admin/` ตั้งแต่นี้ไป — แทนที่ข้อความเรื่อง "shadcn neutral base + WYN Cyan accent" ที่เขียนไว้ในหมายเหตุต้นไฟล์ของ `wyn-049-admin-foundation.md`/`wyn-050-admin-dashboard.md`/`wyn-051-admin-user-management.md`/`wyn-052-admin-content-moderation.md` (ทั้ง 4 ไฟล์นั้นยังเก็บเนื้อหาเดิมไว้ครบเป็นบันทึกประวัติ + เพิ่ม section "Visual Refresh (2026-09-04)" ต่อท้ายแต่ละไฟล์ อ้างอิงกลับมาที่เอกสารนี้ ดูหัวข้อ 10)

---

## 1. หลักการออกแบบ (Design Principles)

1. **ขาว-ดำ-เทา คือฐานทั้งหมด** — ไม่มีสีตกแต่งใดๆ เลยนอกจากสีเดียวที่สงวนไว้สำหรับ "อันตราย/ต้องรีบดู" (ดูข้อ 3.2) ไอคอน, active nav, ปุ่มหลัก, focus ring — ทุกอย่างสื่อสารด้วย **น้ำหนัก (weight) และความเข้ม (contrast) ของสีเทา/ดำ/ขาว** ไม่ใช่ hue
2. **สีคือสัญญาณ ไม่ใช่การตกแต่ง** — ทุกครั้งที่สีปรากฏบนจอ ต้องตอบคำถามได้ว่า "นี่คือ destructive action, critical alert, หรือปุ่ม primary action เดียวของหน้านี้หรือเปล่า" ถ้าตอบไม่ได้ = ห้ามใส่สี
3. **Hierarchy มาจาก whitespace + typography ไม่ใช่กรอบ/เงา/สี** — บรรทัดคั่น (hairline) แทนเงาหนา, ระยะห่างกว้างแทนเส้นแบ่งเยอะ, ตัวหนา/บาง แทนสีเข้ม/อ่อน
4. **ห้ามใช้ Liquid Glass** (สืบทอดกติกาเดียวกับ DS-001 ของ Consumer app — ไม่มี blur/translucent surface พื้นผิวทึบเสมอ) แม้ Admin จะเป็นคนละระบบ แต่กติกา "ไม่ใช้กระจกฝ้า" เป็นมาตรฐานงานฝีมือของทั้งบริษัท ไม่ใช่ทางเลือกทาง gu
5. **ความหนาแน่นของข้อมูลสูง แต่ไม่อึดอัด** — desktop-first, ตารางเป็นเครื่องมือหลัก (ต่างจาก Consumer app's mobile card feed) แต่ยังต้องมี generous padding/line-height ไม่ยัดข้อมูลจนกลายเป็น spreadsheet ดิบ
6. **สม่ำเสมอทุกหน้า** — component เดียวกัน (Table/Badge/Dialog/StatCard) reuse ทุกที่ที่ทำหน้าที่เดียวกัน ไม่มี "หน้านี้ badge กลม หน้านั้น badge เหลี่ยม" — 6 หน้าของ Admin ต้องรู้สึกเป็นเครื่องมือชุดเดียวกัน

---

## 2. ความสัมพันธ์กับ Consumer App Design System (DS-001) — เหมือนกันตรงไหน ต่างตรงไหน

Master Spec section 36 ระบุไว้แล้วว่า "WYN App ≠ WYN Admin — Admin ต้องเป็นระบบแยกโดยสิ้นเชิง" — เอกสารนี้จึง **ไม่ยก DS-001 มาใช้ตรงๆ** (Cyan/Orange, Rainbow accent ring, mobile-first spacing ฯลฯ ผิดบริบทของเครื่องมือภายในที่ staff ใช้ทำงานหนาแน่นบนจอใหญ่) — แต่ borrow เฉพาะสิ่งที่เป็น "หลักการร่วมของบริษัท" ไม่ใช่ "หน้าตาแบรนด์"

| หัวข้อ | Consumer App (DS-001) | WYN Admin (เอกสารนี้) | เหตุผลที่ต่าง/เหมือน |
|---|---|---|---|
| สีแบรนด์หลัก | Cyan `#00C8FF` + Orange `#FF6B35` (ZOKY) — expressive, Gen Z | **ไม่มีสีแบรนด์เลย** — ขาว/ดำ/เทาล้วน | Target user คนละกลุ่ม (staff ภายใน vs ผู้ใช้ทั่วไป), เป้าหมาย UX คือความเร็ว/ความแม่นยำในการทำงาน ไม่ใช่อารมณ์/ความสนุก |
| สีสถานะ destructive/error | `#DC2626` (light) / `#F87171` (dark) | **ค่าเดียวกันเป๊ะ** `#DC2626` / `#F87171` | **จุดเชื่อมเดียวที่ตั้งใจให้เหมือนกัน 100%** — อันตรายควรมีหน้าตาเดียวกันทั่วทั้งบริษัท ไม่ว่าจะเจอในแอปไหน (ต่อยอดกติกา DS-001 ข้อ 4 "สีสถานะไม่ประดิษฐ์ใหม่") |
| สีเทาหลัก (ink) | `ink #0A0A0A` | **ค่าเดียวกันเป๊ะ** `#0A0A0A` (ใช้เป็นตัวหนังสือหลัก + พื้นปุ่ม primary) | จุดเชื่อมที่ 2 — ดำสนิทแต่ไม่แข็งกระด้างเท่า pure `#000000` เหมือนกันทั้งบริษัท |
| Rainbow accent ring (DS-009, trending content) | มี | **ไม่มีเลย** | เป็นกลไกเฉพาะ social feed ไม่เกี่ยวกับเครื่องมือ admin |
| Liquid Glass | ห้าม | ห้าม (เหมือนกัน) | มาตรฐานงานฝีมือร่วมของบริษัท ไม่ใช่เรื่องแบรนด์ |
| Mobile-first | บังคับ | **Desktop-first** (ตาม Product spec ทุกฉบับของ Phase 7) | Target device คนละแบบ |
| Font | System font (San Francisco/Roboto ผ่าน Flutter) | System font (ผ่าน browser, ไม่มี `next/font/google`) | เหตุผลเดียวกัน (เครือข่ายไม่เสถียรตอน build/sandbox) — ค่าที่ได้ต่างกันเพราะคนละ platform runtime แต่หลักการ "ไม่พึ่งฟอนต์ดาวน์โหลด" เหมือนกัน |
| Semantic success (เขียว)/warning (เหลือง) | มี ใช้ตาม convention | **ไม่มีในรอบนี้** — Admin ไม่มีจุดไหนที่ Product spec ต้องการสถานะ "สำเร็จ/เตือนระดับกลาง" ที่ต้องแยกจาก "ปกติ" กับ "อันตราย" | ทุกสถานะใน 6 หน้าของ Admin แบ่งได้แค่ 2 กลุ่มจริงๆ: ปกติ (เทา/ไม่มี badge) กับ ต้องรีบดู (แดง) — การเพิ่มเขียว/เหลืองเข้ามาจะเป็นสีที่ "ไม่มีจุดใช้จริง" (mirror หลักการเดียวกับที่ WYN-050 ไม่ใส่ card ว่างสำหรับ Storage/Errors/Server Health) ถ้าอนาคตมี requirement ใหม่ที่ต้องการสถานะ "สำเร็จ" จริง ให้เพิ่ม token ตอนนั้น ไม่ใช่เผื่อไว้ล่วงหน้า |

สรุป 1 ประโยค: **Consumer app แสดงตัวตนแบรนด์ (Cyan/Orange), Admin แสดงวินัย (ขาว-ดำ-เทา + แดงเดียวสำหรับอันตราย) — สิ่งที่เหมือนกันมีแค่ 2 อย่าง: ค่า hex ของ "ดำ" และค่า hex ของ "อันตราย" เท่านั้น**

---

## 3. Color Tokens

### 3.1 Neutral Scale (ฐาน Zinc — ใกล้เคียง shadcn's neutral base ที่มีอยู่แล้วใน `admin/app/globals.css` ทำให้ implementation cost ต่ำ ไม่ต้องเปลี่ยน base theme ทั้งชุด)

> ตัวเลข contrast อ้างอิงค่าที่เผยแพร่แพร่หลายของ Tailwind's Zinc scale (คำนวณด้วยสูตร WCAG 2.1 relative luminance) — ให้ AI Coding/QA ยืนยันซ้ำด้วยเครื่องมือจริง (Chrome DevTools/axe) ตอน implement ก่อนขึ้น production เหมือนที่ DS-001 ทำ ไม่ใช่เชื่อเลขในเอกสารเฉยๆ

| Token | Hex | Light mode ใช้ที่ไหน | Dark mode ใช้ที่ไหน | Contrast |
|---|---|---|---|---|
| `white` | `#FFFFFF` | พื้นหลังหน้าจอ, ตัวหนังสือ primary button (บนพื้น ink) | ตัวหนังสือหลัก | บน ink: ~19.8:1 ✅ |
| `gray-50` | `#FAFAFA` | พื้นแถวตาราง hover, พื้นรอง section | — | ตกแต่งเท่านั้น |
| `gray-100` | `#F4F4F5` | พื้น header ตาราง, พื้น input, พื้นหลัง active nav item, พื้น skeleton | พื้น badge เทาบน dark (ผสม opacity) | ตกแต่งเท่านั้น |
| `gray-200` | `#E4E4E7` | เส้นแบ่งตกแต่ง (border-subtle, การ์ด/แถว) | — | **ห้ามใช้เป็นขอบของสิ่งที่กดได้** (< 3.0:1 ตาม WCAG 1.4.11) |
| `gray-300` | `#D4D4D8` | ขอบ input/ปุ่ม outline ที่กดได้ (border-strong) | — | บนขาว ~1.6:1 — **ใช้เป็นขอบ UI component เท่านั้น ไม่ใช่ตัวหนังสือ** (ขอบยังนับเป็น non-text ยกเว้นได้ต่ำกว่า text) — ถ้าต้องการขอบที่ผ่าน 3.0:1 จริงให้ใช้ `gray-400` แทนในจุดที่ต้อง contrast เข้มกว่า (เช่น ring ของ input ตอน focus ที่ยังไม่ใช้สี accent) |
| `gray-400` | `#A1A1AA` | ไอคอนตกแต่ง/disabled/placeholder (light), **ตัวหนังสือรอง (dark mode)** | ตัวหนังสือรอง dark ~8.2:1 ✅ (บน `#0A0A0A`) | บนขาว ~2.4:1 ❌ (ห้ามเป็นตัวหนังสือ light) |
| `gray-500` | `#71717A` | ตัวหนังสือรอง/`muted-foreground` (light) | **ห้ามใช้เป็นตัวหนังสือ dark** (มิเรอร์บทเรียนเดียวกับ DS-001's `gray-500`) | บนขาว ~4.6:1 ✅ / บน `#0A0A0A` ~3.9:1 ❌ |
| `gray-600` | `#52525B` | ตัวหนังสือรองที่ต้องเน้นหนักกว่า (light), label ของ section heading | — | บนขาว ~7.3:1 ✅ |
| `gray-700` | `#3F3F46` | — | ขอบ input/ปุ่ม outline ที่กดได้ (dark) | บน `#0A0A0A` ~2.3:1 — ใช้เป็น "border-strong dark" ระดับต่ำสุดที่ยังมองเห็นได้ชัด เทียบง่ายกับพื้นการ์ด `gray-800` |
| `gray-800` | `#27272A` | — | พื้นการ์ด/พื้นรอง (surface) dark | — |
| `gray-900` | `#18181B` | — | พื้นหลังหน้าจอ dark (ทางเลือกแทน pure black ถ้าไม่ต้องการ OLED เต็มที่) | — |
| `ink` | `#0A0A0A` | **ตัวหนังสือหลัก, พื้นปุ่ม primary, active nav text/icon** — ยืมค่าจาก DS-001 ตรงๆ (ดูหัวข้อ 2) | พื้นหลังหน้าจอ dark (ทางเลือกเข้ม), พื้นปุ่ม primary กลับด้าน (ขาว) | บนขาว ~19.8:1 ✅ |

**กติกาการเลือก token**: ห้ามใช้ค่า hex ที่ไม่อยู่ในตารางนี้ (ยกเว้น semantic red ในหัวข้อ 3.2) — ถ้าจุดไหนรู้สึกว่า "ไม่มี token ที่พอดี" ให้กลับมาแก้เอกสารนี้ก่อน ไม่ใช่เผลอ hardcode สีใหม่กระจายในโค้ด (ปัญหาเดียวกับที่ DS-001 พบใน Flutter app ก่อนมี token file)

### 3.2 Semantic — Destructive / Critical (สีเดียวในทั้งระบบ)

| Token | Light | Dark | Contrast |
|---|---|---|---|
| `destructive` | `#DC2626` | `#F87171` | Light บนขาว 4.83:1 ✅ / Dark บน `#111111` 6.83:1 ✅ (ค่าเดียวกับ DS-001's error token เป๊ะ — ดูหัวข้อ 2) |
| `destructive-subtle-bg` (พื้นชิป/badge) | `#FEE2E2` | `#3F0D0D` (โดยประมาณ — ให้ AI Coding ปรับให้ตัวหนังสือ `destructive` ทับแล้วอ่านผ่าน AA) | ใช้กับ Badge เท่านั้น ไม่ใช่พื้นหลังขนาดใหญ่ |

**Admin ไม่มี success (เขียว)/warning (เหลือง) token** — ดูเหตุผลในตารางหัวข้อ 2 (ทุกสถานะแบ่งได้แค่ "ปกติ" กับ "ต้องรีบดู" เท่านั้นตามสโคปจริงของ 6 หน้า)

### 3.3 กติกาการใช้สี (บังคับ — นี่คือหัวใจของ "black-and-white, color sparingly")

สีปรากฏได้ **3 กรณีเท่านั้น** ทั้งระบบ Admin:

1. **Destructive action** — ปุ่ม Ban/Remove Drop/Remove Content เท่านั้น (`variant="destructive"`, พื้นแดง + ตัวหนังสือขาว) — ไม่ใช้กับ Restrict/Suspend/Warn/Unban/Restore (action เหล่านี้กลับสถานะได้หรือไม่รุนแรงเท่า Ban/Remove — ใช้ ink/gray ตามระดับความรุนแรงผ่าน**น้ำหนักตัวอักษร/ความหนาของ border** แทน)
2. **Critical alert/status ที่ active อยู่จริง** — Badge "Restricted/Suspended/Banned"/"ลบแล้ว", ตัวเลข Reports pending เมื่อ > 0, error message (`role="alert"`), ไอคอนเตือนในหัว destructive dialog — **แสดงเมื่อสถานะนั้น active จริงเท่านั้น** (สืบทอดกติกาเดิมจาก WYN-050/051 ทุกจุด: "ไม่ใช้สีแดงตายตัวเสมอ ไม่งั้น Admin จะชินจนไม่รู้สึกว่าต้อง action")
3. **ปุ่ม primary action เดียวของหน้า/ส่วนนั้น** — ไม่ใช่สีใหม่ แต่คือ **พื้น ink เต็ม (`#0A0A0A`) + ตัวหนังสือขาว** (light mode) / พื้นขาวเต็ม + ตัวหนังสือ ink (dark mode) — เช่น ปุ่ม "เข้าสู่ระบบ" (Sign-in), ปุ่มยืนยันใน Dialog ที่ไม่ใช่ destructive, ปุ่ม "ส่งประกาศ" — คือการใช้ **ความเข้มสูงสุดของ neutral scale** ไม่ใช่การเพิ่ม hue ใหม่ ตรงตามคำสั่ง Founder ("black-and-white tone") 100%

**ทุกที่อื่นนอกจาก 3 ข้อนี้ = grayscale ล้วน** โดยเฉพาะจุดที่ implementation ปัจจุบันยังใช้ Cyan (`--primary` เดิม) แบบตกแต่ง ต้องเปลี่ยนทั้งหมด:
- ไอคอนของ StatCard ทุกใบ (ปัจจุบัน `text-primary` = cyan) → `gray-400` (เป็นแค่ decoration ไม่ใช่สัญญาณ)
- Active nav item ใน Sidebar (ปัจจุบัน cyan-50 bg + cyan-700 text) → `gray-100` bg + `ink` text/icon + font-medium→font-semibold (น้ำหนักตัวอักษรสื่อ active state แทนสี)
- Focus ring (ปัจจุบัน `--ring` = cyan) → `ink` (light) / `white` (dark), หนา 2px offset 2px — ยังคง contrast สูงสุดสำหรับ keyboard user โดยไม่ใช้ hue
- ปุ่ม Submit ของ Sign-in (ปัจจุบัน cyan) → ink เต็ม (นี่คือกรณีข้อ 3 ตรงๆ แต่แสดงผลด้วย neutral ไม่ใช่ cyan)

---

## 4. Typography

**ฟอนต์**: System font stack ผ่าน browser เดิม (`font-sans` ของ Tailwind, ไม่มี `next/font/google`) — เหตุผลเดียวกับที่ WYN-049 ตัดสินใจไว้แล้ว (เครือข่าย sandbox ไม่เสถียรตอน build) ไม่เปลี่ยนในรอบนี้

**Scale** (สูงสุด 4 ระดับต่อหน้าจอเดียว — สืบทอดวินัยเดียวกับ DS-001 ข้อ Typography 1 "ระดับตัวอักษรในหน้าเดียวไม่เกิน 4 ระดับ" เพราะเป็นหลักการสากลของ hierarchy ที่ดี ไม่ใช่กติกาเฉพาะ Consumer app):

| Token | ขนาด/line-height | น้ำหนัก | สี (light/dark) | ใช้กับ |
|---|---|---|---|---|
| `page-title` | 24px / 32px | 600 (Semibold) | `ink` / `white` | หัวข้อหน้า (Header — "Dashboard"/"User Management" ฯลฯ), 1 จุดต่อหน้าเท่านั้น |
| `section-label` | 13px / 16px, +0.01em tracking | 600 | `gray-600` / `gray-400` | หัวข้อกลุ่ม (เช่น "ผู้ใช้งาน" เหนือ stat card, หัวตาราง) |
| `body` | 14px / 20px | 400 | `ink` / `white` | เนื้อหาตารางทั่วไป, ป้ายกำกับฟอร์ม |
| `body-emphasis` | 14px / 20px | 600 | `ink` / `white` | username, ค่าที่ต้องเน้น (เช่น ชื่อผู้ใช้ในตาราง) |
| `metric` | 30px / 36px, tabular-nums | 700 (Bold) | `ink` / `white` (แดงเฉพาะ pending>0) | ตัวเลขใหญ่ของ StatCard |
| `caption` | 12px / 16px | 400 | `gray-500` (light) / `gray-400` (dark) | timestamp, disclaimer, helper text ใต้ input |
| `label` (ปุ่ม/badge) | 13px / 16px | 500 | ตามพื้นหลัง | ตัวหนังสือในปุ่ม/Badge |

กติกา: ห้ามมี font-size ที่ไม่อยู่ในตารางนี้ในหน้าใหม่ — ถ้าจำเป็นต้องมีระดับที่ 8 ให้กลับมาแก้เอกสารนี้ก่อน

---

## 5. Spacing / Radius / Elevation

### Spacing (4px grid — คงหลักการเดียวกับ DS-001 แต่ base padding หนาแน่นกว่าเล็กน้อยเพราะ desktop/ตาราง ไม่ใช่มือถือ)

| Token | ค่า | ใช้กับ |
|---|---|---|
| `space-1` | 4px | ช่องไฟ icon–label |
| `space-2` | 8px | gap ภายใน component เล็ก (badge, ปุ่มกลุ่ม) |
| `space-3` | 12px | padding แถวตาราง (แนวตั้ง), gap ระหว่าง form field |
| `space-4` | 16px | padding แถวตาราง (แนวนอน), gap มาตรฐานระหว่าง element |
| `space-6` | 24px | padding ภายใน Card (คงค่าเดิมที่ implement อยู่แล้ว `py-6 px-6`) |
| `space-8` | 32px | ช่องไฟระหว่าง section (เช่น ระหว่างกลุ่ม stat card) |
| `space-10` | 40px | padding ซ้าย-ขวาของ content area หลัก (จอกว้าง ไม่ชนขอบจอ — Apple System Settings ก็ไม่ทำ edge-to-edge) |

### Radius

| Token | ค่า | ใช้กับ |
|---|---|---|
| `radius-sm` | 8px | Input, Button |
| `radius-md` | 12px | Card (ค่าเดิมที่ implement อยู่แล้ว, ไม่เปลี่ยน) |
| `radius-lg` | 16px | Dialog/Modal |
| `radius-full` | 999px | **Badge/Status pill (เปลี่ยนจาก `rounded-md` เดิมเป็น pill เต็ม)**, Avatar |

### Elevation — ลด shadow ให้น้อยที่สุด (แทนด้วยเส้นบาง)

- **Card ที่ระดับพัก (rest state)**: border 1px `gray-200` + **ไม่มี shadow** (เอา `shadow-sm` เดิมออก) — hairline สื่อขอบเขตพอแล้ว ไม่ต้องมีเงา
- **Dialog/Popover (overlay context)**: shadow ชัดเจน (`shadow-lg`) + scrim พื้นหลังทึบสีดำโปร่งแสง (ไม่ใช่ blur — ตรงกับกติกาห้าม Liquid Glass ข้อ 4)
- **Hover row ในตาราง**: พื้น `gray-50` เปลี่ยนทันที ไม่มี shadow/scale animation

---

## 6. Core Components

### 6.1 Button

| Variant | พื้น (light) | ตัวหนังสือ | ใช้เมื่อไหร่ |
|---|---|---|---|
| `primary` (เดิมชื่อ `default`) | `ink #0A0A0A` | `white` | **ปุ่ม primary action เดียวของหน้า/dialog เท่านั้น** (ดูหัวข้อ 3.3 ข้อ 3) |
| `outline` | โปร่งใส, border `gray-300` | `ink` | action รอง/ทางเลือกที่ไม่ใช่ primary ไม่ใช่ destructive (Warn/Restrict/Suspend/Unban/Restore/Cancel) |
| `ghost` | โปร่งใส, ไม่มี border | `gray-600` | action เบาที่สุด (เช่น ปุ่มออกจากระบบใน header) |
| `destructive` | `#DC2626` | `white` | Ban, Remove Drop/Content เท่านั้น |

**ไม่มี `variant="secondary"` สีเดิม (cyan tonal)** — ใช้ `outline` แทนสำหรับทุกจุดที่เคยเป็น secondary

### 6.2 Status Badge (redesign เป็น pill, ไม่มีสี role อีกต่อไป)

Role badge (Admin/Moderator/User) — **เปลี่ยนจากสี purple/blue/gray (WYN-051 เดิม) เป็นน้ำหนัก/ความเข้มของ neutral scale เพื่อสื่อ hierarchy แทนสี**:
- `admin` → pill พื้น `ink` เต็ม + ตัวหนังสือขาว (emphasis สูงสุด)
- `moderator` → pill พื้น `gray-200` + ตัวหนังสือ `ink` (emphasis กลาง)
- `user` → pill โปร่งใส border `gray-300` + ตัวหนังสือ `gray-600` (emphasis ต่ำสุด)

Status badge (Restricted/Suspended/Banned/ลบแล้ว) — พื้น `destructive-subtle-bg` + ตัวหนังสือ `destructive` — **แสดงเฉพาะตอน active เท่านั้น** (กติกาเดิมจาก WYN-050/051 ไม่เปลี่ยน)

Neutral history badge (เช่น "ถูกยกเลิกแล้ว/overturned") — pill `gray-100` + ตัวหนังสือ `gray-600` (ไม่ใช่สีเขียว — กติกาเดิมของ WYN-051 "ไม่ใช้สีเตือน" ยังใช้ได้แต่ตอนนี้ยิ่งชัดเจนขึ้นเพราะไม่มีสีอื่นให้เลือกเลยนอกจาก grayscale)

### 6.3 Table (ใช้กับ User search results, Report Center, Audit Log)

- Header row: พื้น `gray-50`, ตัวหนังสือ `section-label` token, เส้นล่างหนา 1px `gray-200`, ไม่มี sticky ในรอบนี้ยกเว้น Filter Bar (ดู 6.4)
- Body row: สูงขั้นต่ำ 44px, เส้นแบ่ง 1px `gray-100` ระหว่างแถว (hairline เท่านั้น ไม่มี zebra stripe — ลด visual noise), hover → พื้น `gray-50`, cursor `pointer` ถ้าคลิกได้ (ทั้งแถวคลิกได้ ไม่ใช่แค่ link ใน cell — reuse `ClickableRow` pattern ที่มีอยู่แล้วจาก WYN-053)
- ตัวเลข: `tabular-nums` เสมอ, ชิดขวา
- ข้อความยาว (caption/message/reason): truncate + `title` attribute (native tooltip) แทนการขึ้นบรรทัดใหม่จนตารางเสียโครง
- Empty state: ข้อความ `gray-500` กึ่งกลาง, ไม่มี illustration

### 6.4 Filter Bar / Search Bar

แถบเดียวกันทุกหน้าที่มีการค้นหา/กรอง (User Management, Content Moderation, Report Center, Audit Log): วางบนสุดของ content area, ใต้ page title — `Input` (ค้นหา) ชิดซ้าย + `Select`/segmented control (สถานะ/ประเภท) ชิดขวา + เส้นคั่น `gray-200` ด้านล่างแยกจากพื้นที่ผลลัพธ์ — บนหน้าที่ list ยาว (Report Center/Audit Log) แถบนี้ `sticky top-0` (พื้นหลังทึบ ไม่โปร่งแสง) ให้กรองได้ระหว่าง scroll โดยไม่ต้องเลื่อนกลับขึ้นบน

### 6.5 Detail Panel (page template ใช้ร่วมกันทั้ง User Detail / Drop Detail / Report Detail)

โครงเดียวกันทุกหน้า (คงสถาปัตยกรรม routing เดิมเป็นหน้าเต็ม `/users/[id]`, `/moderation/[id]`, `/reports/[id]` — **ไม่เปลี่ยนเป็น slide-over drawer ในรอบนี้** เพราะจะเป็นการเปลี่ยน IA ที่กระทบ back-button/browser-history ของ workflow admin ซึ่งอยู่นอกขอบเขต "re-skin" — เสนอเป็น future enhancement ถ้าต้องการ triage เร็วขึ้นแบบไม่ออกจาก list):

1. **Header block**: identity หลัก (`page-title` — username/caption ย่อ/target type) + role/status badge ติดกัน
2. **Action bar**: ปุ่ม action ทั้งหมดเรียงแนวนอน ระดับความรุนแรงสื่อผ่าน variant (ดู 6.1) ไม่ใช่สีที่ต่างกันไปเรื่อยๆ
3. **Section card ซ้อนกันแนวตั้ง** (แต่ละ section = `Card` มี `section-label` เป็นหัว): "รายงานที่มีต่อ..." → "ประวัติการดำเนินการ" → เนื้อหาเฉพาะของหน้านั้น (รูปภาพ Drop, ฟิลด์ report ดิบ ฯลฯ)

### 6.6 Confirmation Dialog

- **Non-destructive** (Warn/Restrict/Suspend/Unban/Restore/ส่งประกาศ): ปุ่มยืนยัน = `primary` (ink เต็ม) — คงโครงเดิมของ `ActionDialog` component
- **Destructive แบบมาตรฐาน** (Remove Drop/Content — กู้คืนได้ผ่าน Restore): ปุ่มยืนยัน = `destructive`, ไอคอนเตือนเล็ก (`AlertTriangle`, `destructive` สี) ในหัว Dialog — **นี่คือจุดเดียวที่ยอมให้ไอคอนมีสีแดงนอกเหนือปุ่ม** เพราะเป็น "critical alert" ตามคำสั่ง Founder ตรงๆ
- **Destructive แบบรุนแรงสุด — typed-confirmation** (Ban เท่านั้น): คงกลไกเดิม (`BanDialog`, พิมพ์ username ให้ตรงเป๊ะถึงจะกดยืนยันได้) — ไม่ขยาย pattern นี้ไปที่ action อื่น เพราะ Ban เป็น action เดียวที่ "ถาวรจนกว่าจะมีคน unban" จริงๆ (Remove Drop มี Restore, Restrict/Suspend หมดอายุอัตโนมัติ)

### 6.7 Stat Card (Dashboard)

คงโครงเดิมทั้งหมดจาก WYN-050 (ตัวเลขใหญ่ + label + sublabel, การ์ด 2-ค่าสำหรับ Clubs/Reports) — เปลี่ยนแค่สี: ไอคอน `gray-400` (ตกแต่ง ไม่ใช่สัญญาณ), ตัวเลขหลัก `ink`, ตัวเลขรอง `destructive` เฉพาะ Reports-pending>0 (คงเดิมเป๊ะ)

### 6.8 Sidebar / Header (App Shell)

- **Sidebar**: พื้น `white`/`gray-900`(dark), item ปกติ = icon+label `gray-500`, ไม่มี background — item active = พื้น `gray-100`(light)/`gray-800`(dark) รูปสี่เหลี่ยมมุมมน (`radius-sm`), icon+label เปลี่ยนเป็น `ink`/`white` + น้ำหนัก semibold (**ไม่มีสีอีกต่อไป** — ดูหัวข้อ 3.3)
- **Header**: page title ซ้าย (`page-title` token), ขวา = role badge (pill `gray-100`+`gray-700`, เปลี่ยนจากเดิมที่เป็นสีเดียวกันหมดอยู่แล้ว — คงรูปแบบเดิม ไม่ต้องเปลี่ยน เพราะไม่เคยใช้สี), email (`caption`), ปุ่ม "ออกจากระบบ" (`ghost`)

### 6.9 Empty / Loading / Error States

- **Empty**: ไอคอน `gray-300` (ถ้ามี) + ข้อความ `gray-500` กึ่งกลาง คำเดียวกับที่ implement อยู่แล้ว ไม่ต้องเขียนใหม่
- **Loading**: skeleton โครงเดียวกับของจริง พื้น `gray-100` + `animate-pulse` (ไม่มีสี, คงเดิมจาก `DashboardSkeleton`) — ห้ามใช้ spinner เต็มจอสำหรับการโหลดครั้งแรกของหน้า (สงวน spinner ไว้เฉพาะปุ่มที่กำลัง pending)
- **Error**: ข้อความกลางจอ `ink` (หัว) + `gray-500` (รายละเอียด) + ปุ่ม "ลองใหม่" (`outline`) — **ไม่ใช้สีแดงกับ generic fetch/network error** (จงใจแยกจาก destructive: error แบบนี้ไม่ใช่ "อันตราย" แค่ "ระบบขัดข้องชั่วคราว" สงวนแดงไว้สำหรับสถานการณ์ที่ต้องรีบตัดสินใจจริงๆ เท่านั้น)

---

## 7. Accessibility Baseline (สืบทอดจาก DS-001 ทุกข้อ ไม่เปลี่ยน)

- Contrast ผ่าน WCAG AA ขั้นต่ำทุกจุด (ตัวหนังสือ ≥4.5:1, UI component/ขอบ ≥3.0:1) — ดูหมายเหตุเรื่องการยืนยันซ้ำในหัวข้อ 3.1
- ไม่สื่อสารด้วยสีอย่างเดียว — badge ทุกอันมีข้อความกำกับเสมอ (ไม่ใช่แค่จุดสี)
- Focus ring 2px `ink`/`white` เว้นขอบ 2px ทุก interactive element (คงจากเดิม เปลี่ยนแค่สีจาก cyan)
- `Dialog` ใช้ Radix focus-trap มาตรฐานเดิม, `aria-busy` ระหว่าง pending, `role="alert"` สำหรับ error message — ไม่เปลี่ยนจาก implementation เดิม

---

## 8. Dark Mode

Scaffold เดิมมี `.dark` class พร้อม token อยู่แล้วใน `globals.css` (จาก shadcn default) แต่ยังไม่เคยถูกกำหนดอย่างเป็นทางการว่าใช้ค่าไหนตามระบบนี้ — เอกสารนี้ทำให้เป็นทางการ: ทุก token ในหัวข้อ 3.1/3.2 มีคอลัมน์ dark กำกับแล้ว ใช้กลไกเดิม (`prefers-color-scheme`/`.dark` class) — **แนะนำให้ AI Coding เปิดใช้ dark mode จริงในรอบนี้เลย** (ต้นทุนต่ำเพราะ token ถูกกำหนดไว้ครบแล้ว ไม่ใช่ของใหม่ที่ต้องออกแบบเพิ่ม) แต่ไม่ใช่ acceptance criterion บังคับของ Product spec ใดๆ — ถ้า AI Coding ประเมินว่าเวลาไม่พอ ให้ทำ light mode ให้สมบูรณ์ก่อน แล้วเปิด dark mode เป็น fast-follow ได้โดยไม่ต้องขออนุมัติใหม่ (token พร้อมอยู่แล้ว)

---

## 9. Screen Index — Net-new vs Re-skin

| # | Screen | Nav label | Product spec | Design doc เดิม | สถานะงานนี้ |
|---|---|---|---|---|---|
| 1 | Sign-in + Layout Shell | (ไม่อยู่ใน 6 เมนู — เป็น frame ของทุกหน้า) | WYN-049 (approved) | `wyn-049-admin-foundation.md` | **Re-skin** — เปลี่ยนสีปุ่ม/focus ring/active nav เท่านั้น โครงสร้าง/flow เดิมทั้งหมด |
| 2 | Dashboard | Dashboard | WYN-050 (approved) + WYN-077 (completed, เพิ่ม section "การเติบโต") | `wyn-050-admin-dashboard.md` (+ `wyn-077-basic-product-analytics.md`) | **Re-skin** — StatCard/TopSourcesCard เดิมทั้งหมด เปลี่ยนแค่สีไอคอน/ตัวเลข |
| 3 | User Management | User Management | WYN-051 (approved) | `wyn-051-admin-user-management.md` | **Re-skin** — Table/Dialog เดิม, Role badge เปลี่ยนจากสีเป็นน้ำหนัก neutral |
| 4 | Content Moderation | Content Moderation | WYN-052 (approved) | `wyn-052-admin-content-moderation.md` | **Re-skin** — Grid/Detail เดิม, badge "ลบแล้ว" ยังแดงเหมือนเดิม (destructive ที่แท้จริง) |
| 5 | Report Center | Report Center | WYN-053 (approved) | ไม่มี (สร้างใหม่ในงานนี้) | **Net-new design doc** ครอบคลุม UI ที่ implement ไปแล้ว, ในภาษาระบบใหม่ทั้งหมด |
| 6 | Audit Log | Audit Log | WYN-054 (approved) | ไม่มี (สร้างใหม่ในงานนี้) | **Net-new design doc** |
| 7 | Announcements | Announcements | WYN-055 (approved) | ไม่มี (สร้างใหม่ในงานนี้) | **Net-new design doc** |

หมายเหตุ: WYN-053/054/055 มีโค้ด implement จริงอยู่แล้วใน `admin/` (ดู Coding Output ในไฟล์ task ของแต่ละอัน) แต่ไม่เคยมี design doc แยกต่างหากเก็บไว้ — งานนี้เขียน design doc ของ 3 หน้านั้นย้อนหลัง (retroactive) โดยอิง UI ที่มีอยู่จริงเป็นฐาน แล้ว "re-skin ในกระดาษ" ให้ตรงกับระบบใหม่นี้ทันที (ไม่ใช่ design ใหม่ตั้งแต่ศูนย์ เพราะฟังก์ชันเดิมครบและผ่าน QA แล้ว)

---

## 10. Handoff — สิ่งที่ AI Coding ต้องทำ

1. `admin/app/globals.css` — เปลี่ยน `--primary`/`--ring` จาก cyan (`oklch(0.74 0.14 231)`) เป็น ink (`oklch` เทียบเท่า `#0A0A0A`) ทั้ง light/dark, เพิ่ม `--muted-foreground` ให้ตรงกับ `gray-500`/`gray-400` ตามโหมด (ปัจจุบันใช้ oklch เดียวทั้งสองโหมดซึ่งอาจไม่ผ่าน AA ใน dark — ตรวจสอบตามหัวข้อ 3.1)
2. `components/admin/sidebar.tsx` — ลบ hardcode `#E6F9FF`/`#0090C4` (cyan) ออก แทนด้วย `gray-100`/`ink` ตามหัวข้อ 6.8
3. `components/admin/stat-card.tsx` — เปลี่ยน icon จาก `text-primary` เป็น `text-gray-400` (หรือ token เทียบเท่าใน Tailwind config)
4. `components/ui/badge.tsx` — เพิ่ม `rounded-full` (จาก `rounded-md`) ให้เป็น pill ตามหัวข้อ 6.2 — เพิ่ม variant ใหม่สำหรับ role hierarchy (ink-solid/gray-tonal/outline) แทน purple/blue/gray เดิมใน WYN-051's UI
5. `components/ui/card.tsx` — เอา `shadow-sm` ออก เหลือแค่ `border` ตามหัวข้อ 5 (Elevation)
6. ทุกจุดที่มี role badge สี purple/blue (ค้นหาจาก `admin/app/(admin)/users/` และ `results.tsx`) — เปลี่ยนเป็น weight-based ตามหัวข้อ 6.2
7. รัน `next build`/`npm run lint` ให้สะอาดเหมือนเดิม + ตรวจ contrast จริงด้วยเครื่องมือ (axe DevTools หรือเทียบเท่า) อย่างน้อยหน้า Dashboard/User Detail/Login ทั้ง light (และ dark ถ้าเปิดใช้) ก่อนส่ง QA

Handoff ต่อ: AI QA & Security — ตรวจว่าไม่มีจุดไหนหลง cyan/purple/blue/green/yellow เดิมอยู่ (grep `text-primary`, `bg-primary`, hex `#00C8FF`, `purple`, hex เดิมของ role badge) ทั่วทั้ง `admin/` และตรวจ contrast จริงตามที่ระบุในหัวข้อ 3.1
