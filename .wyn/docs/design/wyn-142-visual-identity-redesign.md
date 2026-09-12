# WYN "Flare" — Visual Identity Redesign (V1.0 — PROPOSED)

Status: **PROPOSED** — เอกสารนี้เป็นทิศทาง visual ใหม่ทั้งหมด สร้างขึ้นตามคำสั่งตรงจาก Founder (2026-09-12) ให้ AI Design ออกแบบ UX/UI ของแอป WYNOS ใหม่ทั้งระบบด้วย visual identity ใหม่ — **ไม่ใช่การต่อยอดของเดิม**

Owner: AI Design
Scope: แอปมือถือ WYNOS (Flutter, `app/lib/features/`) เท่านั้น — ไม่รวม Admin panel

## เอกสารที่ถูกแทนที่ (Superseded)

เอกสารนี้เข้ามาแทนที่ทิศทาง visual ที่มีอยู่เดิมทั้งสองชุด ซึ่งขัดแย้งกันเอง:

1. `.wyn/docs/design/design-principles.md` (V0.1 — สี Blue + White + Soft Gray)
2. `design-reference/SPEC.md` + `design-reference/*.jsx` (สี Sapphire + Ink + Paper, ฟอนต์ Fraunces + Inter)

> **กติกาปกติของ AI Design คือห้ามคิดทิศทาง visual ใหม่หากมี design system ที่อนุมัติแล้ว** (`.wyn/agents/design.md`) — เอกสารนี้เป็นข้อยกเว้น เพราะเป็นคำสั่งตรงจาก Founder ให้เปลี่ยนทิศทางทั้งระบบ ไม่ใช่ AI Design ตัดสินใจเอง **ต้องให้ Founder ยืนยันเอกสารนี้อย่างเป็นทางการก่อนนำไปใช้แทนที่ของเดิมถาวร** (เช่นเดียวกับที่ design-principles.md เดิมก็ยังอยู่ในสถานะ PROPOSED)

## กติกาที่ยังคงล็อกไว้เหมือนเดิม (ไม่ถูกยกเลิกโดยงานนี้)

Founder ไม่ได้สั่งเปลี่ยนกติกาต่อไปนี้ จึงยังบังคับใช้เหมือนเดิมกับ identity ใหม่:

- ห้ามใช้ **Liquid Glass** (ไม่มีพื้นผิวโปร่งแสง/เบลอแบบกระจกฝ้า) — พื้นผิวทึบเสมอ
- ห้ามลอก layout ของ Instagram/TikTok โดยตรง
- Mobile-first (Flutter), ออกแบบเพื่อกลุ่ม Gen Z
- รองรับทั้ง **Light mode และ Dark mode** ตั้งแต่เริ่มต้น (ไม่ใช่ทำ dark mode ทีหลัง)
- Contrast ต้องผ่าน **WCAG AA** ขั้นต่ำทุกโหมด
- Spacing บนระบบ **4px grid**
- Touch target ขั้นต่ำ **44×44px** ทุก element ที่กดได้
- ไม่สื่อสารข้อมูลด้วยสีอย่างเดียว (ต้องมี icon/ข้อความประกอบเสมอ)

## Brand Personality

**Flare** = พลังงาน, ความจริงใจ, ความอบอุ่นแบบเพื่อนสนิท — ต่างจากทิศทางเดิมทั้งสองที่เป็นโทนเย็น/หรูแบบ premium-minimal (น้ำเงิน/sapphire) เรามาทางโทนอุ่น พลังงานสูง สนุก แต่ยังคง readable และไม่ loud จนดูเด็ก

- Energetic แต่ไม่ neon/ฉูดฉาด
- อบอุ่น เป็นกันเอง เหมือนคุยกับเพื่อน ไม่ใช่ทางการ
- Confident, ตรงไปตรงมา — ข้อความสั้น กระชับ อ่านจบในสายตาแรก
- Micro-copy ไม่ใช้ศัพท์เทคนิค เช่น "ยินดีต้อนรับสู่ WYN 👋" ไม่ใช่ "กรุณาดำเนินการลงทะเบียน"

## Color System

Single-accent system (คงหลักการเดียวกับทิศทางเดิม: ใช้สี accent หลักสีเดียว ไม่ผสมหลายสีให้ดูรก) แต่เปลี่ยนจากโทนน้ำเงิน/สี cool มาเป็นโทนอุ่น **Coral Flare** เพื่อสร้างความแตกต่างชัดเจนจากทั้งสองทิศทางเดิม และให้ความรู้สึกอบอุ่น มีชีวิตชีวากว่า

### Core Palette

| Token | Light mode | Dark mode | ใช้กับ |
|---|---|---|---|
| `color.accent` | `#FF5A36` (Flare Coral) | `#FF8161` | ปุ่มหลัก, active state, ลิงก์, indicator ของ live/new content |
| `color.accent.pressed` | `#E0431F` | `#FF6A46` | สถานะกดของปุ่ม/element ที่ใช้ accent |
| `color.ink` | `#17140F` | `#F5F1EA` | ข้อความหลัก (high-emphasis) |
| `color.ink.muted` | `#6B6357` | `#A39C8E` | ข้อความรอง (timestamp, hint, placeholder) |
| `color.paper` | `#FFFDF9` | `#121110` | พื้นหลังหลักของแอป |
| `color.surface` | `#FFF7EF` | `#1E1B17` | พื้นผิวการ์ด/แผง ที่ต้องแยกจากพื้นหลัง |
| `color.hairline` | `#ECE4D6` | `#2C2822` | เส้นแบ่ง/border บาง |
| `color.success` | `#1FAA59` | `#34C77A` | สถานะสำเร็จ |
| `color.error` | `#E5484D` | `#FF6369` | สถานะผิดพลาด/destructive |
| `color.warning` | `#DE9A1F` | `#FFC24B` | สถานะเตือน |
| `color.heart` | `#F0294B` | `#FF5171` | Like/หัวใจเท่านั้น (universal convention, แยกจาก `accent` และ `error` เพื่อไม่ให้สับสนกับปุ่มหลักหรือ error) |

หมายเหตุสำคัญ: `accent` (ส้ม-แดง) และ `heart`/`error` (แดง-ชมพู) เป็นคนละโทนที่แยกแยะได้ด้วยตาจริง (ไม่ใช่แค่เฉดใกล้กัน) และทุกจุดที่ใช้สีสถานะต้องมี icon/ข้อความกำกับเสมอตามกติกา accessibility — ห้ามใช้สีอย่างเดียวสื่อความหมาย

### Dark mode strategy
ไม่ใช้ pure black (`#000000`) เพื่อลดความแข็งกระด้างและช่วยแยกระดับ elevation — ใช้ `paper` เป็นน้ำตาลเข้มอมดำ (`#121110`) และ `surface` สว่างกว่าเล็กน้อย (`#1E1B17`) แทนการใช้เงา (shadow แทบมองไม่เห็นบนพื้นมืด) — ยกระดับ elevation ด้วยการทำให้พื้นผิวสว่างขึ้นทีละสเต็ป (surface tint) แทน

## Typography

เปลี่ยนจาก Fraunces+Inter (design-reference เดิม) เป็นคู่ฟอนต์ใหม่ที่ energetic กว่าและยังอ่านง่ายบนจอมือถือ:

- **Display/Heading**: `Space Grotesk` — geometric, ตัวหนา มีคาแรกเตอร์ชัด ใช้กับหัวข้อใหญ่, ตัวเลขสถิติ (follower count, like count), ชื่อหน้าจอหลัก
- **Body/UI**: `Manrope` — humanist sans, อ่านง่ายทุกขนาด ใช้กับเนื้อหา, ปุ่ม, label, input
- **ภาษาไทย**: `Noto Sans Thai Looped` ทั้ง Display และ Body (คงไว้จากของเดิมเพราะให้ความรู้สึกเป็นมิตร เข้ากับ personality "Flare") — ไม่ใช้ Noto Sans Thai แบบไม่ looped เพื่อความสม่ำเสมอของโทนเสียงแบรนด์

### Type Scale

| Token | ขนาด/Line-height | ฟอนต์ | ใช้กับ |
|---|---|---|---|
| `type.display.xl` | 34/40 | Space Grotesk Bold | Onboarding hero, empty state hero |
| `type.display.l` | 28/34 | Space Grotesk Bold | ชื่อหน้าจอหลัก (screen title) |
| `type.heading.1` | 22/28 | Space Grotesk SemiBold | หัวข้อ section |
| `type.heading.2` | 18/24 | Space Grotesk SemiBold | หัวข้อย่อย, ชื่อ Club/ชื่อผู้ใช้ในการ์ด |
| `type.body.l` | 16/24 | Manrope Regular | เนื้อหา Drop, caption |
| `type.body.m` | 14/20 | Manrope Regular | UI ทั่วไป, ปุ่ม, label (ขั้นต่ำตาม accessibility) |
| `type.body.s` | 13/18 | Manrope Medium | metadata, timestamp |
| `type.caption` | 12/16 | Manrope Medium | hint text, badge label |
| `type.overline` | 11/14, letter-spacing 0.4px, UPPERCASE | Manrope SemiBold | section label เล็ก ๆ (เช่น "TRENDING") |

ขนาดตัวอักษรขั้นต่ำ 12px (caption เท่านั้น), body ทั่วไปขั้นต่ำ 14px ตามกติกา accessibility เดิม รองรับ dynamic type ของระบบ

## Spacing & Grid

คงระบบเดิม (locked): 4px-based grid — `4, 8, 12, 16, 24, 32, 40, 48, 64`
Touch target ขั้นต่ำ 44×44px ทุกปุ่ม/element ที่กดได้
Bottom-anchored primary action บนหน้าจอที่มีปุ่มหลักเดียว

## Radius

Identity ใหม่ใช้มุมโค้งมนมากกว่าทิศทางเดิม (Sapphire เดิมใช้มุมค่อนข้างเหลี่ยม/premium) เพื่อสื่อความรู้สึก friendly/energetic:

| Token | ค่า | ใช้กับ |
|---|---|---|
| `radius.s` | 8px | Chip เล็ก, badge |
| `radius.m` | 16px | การ์ด, input field |
| `radius.l` | 24px | Bottom sheet (มุมบน), modal |
| `radius.pill` | 999px | ปุ่มหลัก, chip แบบ tag, avatar (circle) |

## Elevation & Shadow

ห้ามใช้ Liquid Glass/blur — ใช้เงาแบบทึบ, สีอุ่น (ไม่ใช้เงาสีดำล้วน):

- Light mode: `box-shadow: 0 2px 8px rgba(23,20,15,0.06)` (ระดับ 1), `0 8px 24px rgba(23,20,15,0.10)` (ระดับ 2 — modal/sheet)
- Dark mode: ไม่ใช้เงา (มองไม่เห็นผลบนพื้นมืด) — ใช้การไล่ความสว่างของ `surface` แทนตามระดับ elevation (elevation overlay แบบ Material dark theme)

## Iconography

- เส้น (stroke) หนา 1.5px, ปลายมน (round cap/join) — เซ็ตไอคอนแบบ outline เป็นค่าเริ่มต้น
- สถานะ active/selected (เช่น bottom nav) เปลี่ยนเป็นไอคอนแบบ filled พร้อมสี `accent`
- ขนาดมาตรฐาน 24×24px (แตะได้ต้องมี padding ให้ครบ touch target 44×44px)

## Motion

- Easing แบบ spring/ease-out (ไม่ใช้ linear) ให้ความรู้สึกเด้ง กระฉับกระเฉงตาม personality
- Duration scale: `motion.fast` 120ms (micro-interaction เช่น กดปุ่ม, like), `motion.base` 200ms (transition ทั่วไป), `motion.slow` 320ms (เปิด modal/bottom sheet, page transition)
- ต้อง respect ระบบ "Reduce Motion" ของ OS — ปิด animation ที่ไม่จำเป็นเมื่อผู้ใช้เปิด setting นี้

## Social Login Buttons

ปุ่ม Google/Apple ใช้ asset/สเปกทางการของแต่ละแพลตฟอร์มตรงตาม brand guideline (ไม่ปรับสีตาม accent ของเรา) เหมือนกติกาเดิม

## Handoff

- Token ทั้งหมดในเอกสารนี้จะถูกอ้างอิงต่อใน `wyn-143-core-component-library.md` และสเปกรายหน้าจอ `wyn-144` ถึง `wyn-157`
- เมื่อ Founder ยืนยันเอกสารนี้แล้ว ให้ AI Coding แปลง token เป็นไฟล์ theme จริงใน `app/lib/core/design/` (จะมาแทนที่ `wyn_colors.dart`, `wyn_typography.dart`, `wyn_theme.dart` เดิมที่เป็นโทน Sapphire) — งานแปลง token เป็นโค้ดไม่ได้อยู่ใน scope ของ session นี้ (session นี้ทำเฉพาะ design spec)
- อัปเดต `.wyn/company/CONTEXT.md` (หัวข้อ Design Principles) ให้ชี้มาที่เอกสารนี้แทนหลัง Founder ยืนยัน
