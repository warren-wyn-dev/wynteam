# Design — WYN-160 (รวม Design System ของเว็บให้เป็นทิศทางเดียว)

> คำขอ Founder: "เราออกแบบ UX/UI ปุ่ม อื่นๆใหม่ทั้งระบบใหม่ พวกขนาดตัวหนังสือ ทั้งหมดเลย ตั้งแต่หน้าล็อกอิน"
> (ต่อจาก "รู้สึกว่า UX UI ทั้งระบบ ไม่ไปในทิศทางเดียวกัน")
> Scope: `web/` (Next.js consumer web, WYN-158) เท่านั้น — ไม่แตะ Flutter app (คนละ design system ที่อนุมัติแยกกัน)

## ทำไมไม่ใช่การคิดทิศทางใหม่

ตรวจ `.wyn/docs/design/wynos-web-base-design-system.md` (Founder direction, 2026-08-15) ก่อนแล้ว —
เว็บมี base design system ที่อนุมัติแล้วอยู่ก่อน: สีขาว/ดำ/เทา + แดง `#E0203D` เป็น accent เดียว, Button/Input/
Avatar/PostCard/BottomNav/TopBar เป็น primitive หลัก **งานนี้ไม่ใช่การเปลี่ยนสีหรือคิดทิศทางใหม่ — เป็นการ
"บังคับใช้ให้ตรงกัน" สิ่งที่อนุมัติไปแล้ว** เพราะตรวจโค้ดจริงพบว่าหลุดจากสเปกเดิมไปมากแล้ว (ดู evidence ด้านล่าง)

## Evidence — ทำไมรู้สึกว่า "ไม่ไปในทิศทางเดียวกัน" จริง (ไม่ใช่ความรู้สึกเฉยๆ)

ไล่ grep ทุกไฟล์ CSS ของเว็บ (37 ไฟล์ import ซ้อนกันใน `layout.tsx`, ชื่อแบบ `-final`/`-lock`/`-audit-closure`/
`-golden` — ร่องรอยของการแก้ทีละจุดหลายรอบเวลาโดยไม่ได้ยึด token เดียว):

| ค่า | จำนวนค่าที่ต่างกันที่เจอจริง | ตัวอย่าง |
|---|---|---|
| `font-size` | **~20 ค่า** ต่างกันแค่ 0.5-1px | 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 15.5, 16, 17, 17.5, 18, 20, 22, 24px |
| `border-radius` | **~20 ค่า** | 2, 9, 10, 12, 13, 14, 15, 16, 18, 20, 22, 24, 26, 28, 30, 999px |
| สีเทา/พื้นหลังใน `conversation-modern.css` (redesign หน้าแชทล่าสุด) | **ไม่ใช้ `var(--wyn-*)` เลยแม้แต่จุดเดียว** | สร้างชุดสีเทาใหม่ของตัวเอง `#111`/`#8c8c8c`/`#8d8d8d`/`#929292`/`#949494`/`#aaa`/`#e4e4e4`/`#ececec`/`#f1f1f1`/`#f4f4f4`/`#f5f5f5` ที่ใกล้เคียงแต่ไม่ตรงกับ token จริง (`--wyn-text-secondary:#6b6b6b`, `--wyn-border:#e7e7e7`) |
| Touch target (44/48px) | **สม่ำเสมอดี** — จุดเดียวที่ตาม DS-008 ได้ตรง | ไม่ต้องแก้ |

สรุป: ปุ่ม/ช่องกรอกข้อมูลขนาดใหญ่ๆ (accessibility) ยังโอเคเพราะมี base doc คุมไว้ชัด แต่**ตัวหนังสือ/มุมโค้ง/สี
รายละเอียดหลุดจากสเปกไปเรื่อยๆทีละหน้า** — ตรงกับที่ Founder สังเกต

## Design Rules — ชุด token ที่ต้องบังคับใช้ทุกหน้าจากนี้ (ไม่ใช่ของใหม่ ต่อยอดจาก base doc เดิม)

**สี** — คงเดิม 100% จาก `wynos-web-base-design-system.md`: `--wyn-bg:#FFFFFF`, `--wyn-surface:#FAFAFA`,
`--wyn-text:#0A0A0A`, `--wyn-text-secondary:#6B6B6B`, `--wyn-text-muted:#9A9A9A`, `--wyn-border:#E7E7E7`,
`--wyn-border-strong:#D0D0D0`, `--wyn-accent:#E0203D` (สงวนไว้ like/error/warning เท่านั้น ไม่ใช่สีตกแต่งทั่วไป)
**ห้ามมีไฟล์ CSS ไหน hardcode สีเทา/ขาว/ดำเป็น hex ตรงๆอีก — ต้องอ้าง `var(--wyn-*)` เท่านั้น**

**ตัวหนังสือ (ยุบจาก ~20 ค่าเหลือ 7 ค่า ตาม role)**:
| Role | ขนาด | ใช้กับ |
|---|---|---|
| caption | 12px | timestamp, label เล็ก, ตัวนับ |
| secondary | 13px | ข้อความรอง, preview, meta |
| body | 14px | เนื้อหาทั่วไป, ปุ่ม, ป้ายกำกับ |
| input | 16px | ตัวหนังสือในช่องกรอกข้อมูล (ต้อง ≥16px เสมอ ตามที่ WYN-141 ก็ล็อกไว้เหมือนกัน) |
| subhead | 17px | ชื่อผู้ใช้, หัวข้อรอง |
| title | 20px | หัวข้อหน้า |
| display | 22px | ช่องพิมพ์ตอนสร้างโพสต์ (จุดเดียวที่ตัวใหญ่พิเศษ) |

**มุมโค้ง (ยุบจาก ~20 ค่าเหลือ 5 ค่า ตามบทบาท ไม่ใช่ตามหน้า)**:
| Role | ค่า | ใช้กับ |
|---|---|---|
| pill | 999px | ปุ่ม, chip, ช่องค้นหา |
| sheet | 20px | bottom sheet, modal, การ์ดใหญ่ |
| tile | 14px | รูปภาพ preview, list tile ที่เป็นการ์ด |
| control | 10px | ช่องกรอกข้อมูล, ปุ่มไอคอนสี่เหลี่ยม |
| tail | 2-4px | มุม bubble แชทที่ต่อกับข้อความก่อนหน้า (ตาม WYN-031 grouping spec) |

**Spacing**: ยึด 4px-based scale เดิม (4/8/12/16/20/24/32) ที่ `wyn_spacing.dart` มีอยู่แล้วและเว็บก็เริ่ม
ประกาศเป็น CSS variable ไว้บ้างแล้วตั้งแต่ dark-mode pass (2026-09-16) — แค่ต้องบังคับใช้ให้ทั่วถึงกว่านี้

## User Flow

ไม่เปลี่ยน flow การใช้งานของหน้าไหนเลย — งานนี้คือ "ทำความสะอาด" ตัวเลขที่ใช้ ไม่ใช่ออกแบบ flow ใหม่

## Components / Responsive Behavior / Accessibility

ใช้ของเดิมจาก `wynos-web-base-design-system.md` (Button/Input/Avatar/PostCard/BottomNav/TopBar/WynosIcon)
เป็นฐาน — งานนี้เพิ่ม 3 primitive ที่ base doc เดิมยังไม่ครอบ (เพราะตอนนั้นทำแค่ auth flow): **Card** (border 1px
`--wyn-border`, radius `sheet`=20px), **Modal/Sheet** (radius `sheet`, safe-area-aware แบบที่ WYN-141 กำหนดไว้
ให้ Flutter — ใช้หลักการเดียวกัน), **Tab/Pill** (radius `pill`, active = พื้น `--wyn-text` ตัวหนังสือ
`--wyn-bg`) — ทั้งหมด mobile-first เดิม ไม่เปลี่ยน breakpoint

Accessibility: คงมาตรฐานเดิม (touch target 44px ขั้นต่ำ, contrast ผ่าน AA, ไม่สื่อความหมายด้วยสีอย่างเดียว) —
จุดนี้เว็บทำได้ดีอยู่แล้วจากการตรวจ ไม่ต้องแก้

## States

ไม่มี state ใหม่ — เป็นงาน token-level เท่านั้น

## Handoff

**ลำดับ rollout (ตามที่ Founder ขอเริ่มจากหน้าล็อกอิน + มิเรอร์ลำดับที่ WYN-141 ใช้กับ Flutter ตอนงานแบบ
เดียวกันนี้)**:
1. ประกาศ token ตัวหนังสือ/มุมโค้งด้านบนเป็น CSS variable กลาง (`--wyn-font-*`, `--wyn-radius-*`) ใน
   `design-system.css` — ยังไม่แก้หน้าไหน แค่มีตัวแปรให้ใช้
2. หน้า Auth/Login/Signup/Onboarding (`auth-reference.css` + `components/auth-flow/`) — เริ่มตามที่ Founder
   สั่ง
3. Home/Bottom Nav
4. หน้าสร้างโพสต์ (composer) — เพิ่งแก้ไปหลายรอบ ต้องรื้อให้ใช้ token ใหม่ด้วย
5. แชท (inbox + conversation) — **โดยเฉพาะ `conversation-modern.css` ที่ไม่ใช้ token เลยตอนนี้ ต้องแก้ก่อนสุด
   ในกลุ่มนี้**
6. โปรไฟล์/Settings
7. ค้นหา/แจ้งเตือน/Club
8. รอบสุดท้าย: ไล่ลบ CSS rule ที่ไม่มีใครอ้างอิงแล้ว (dead code จากการ patch ทีละจุดที่สะสมมา)

**ก่อน AI Coding เริ่มทำจริง**: ตามกติกาถาวรจาก WYN-141 ("UI ใหม่ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด") แม้งาน
นี้จะไม่เปลี่ยนสี/ทิศทาง แต่เปลี่ยนขนาดตัวหนังสือ/มุมโค้งทั่วทั้งแอปจริง ควรทำภาพเปรียบเทียบก่อน-หลังของหน้า
ล็อกอิน (หน้าแรกที่จะแก้) ให้ Founder ดูก่อน แล้วค่อยขยายไปหน้าอื่นตามลำดับด้านบนทีละหน้า ไม่ทำรวดเดียวทั้งระบบ
(เสี่ยงพังกว้างเกินไปในรอบเดียว ตรงกับที่ WYN-141 เขียนไว้เป๊ะ: "roll out in batches, never a single sweeping
refactor")

อ้างอิง: `.wyn/docs/design/wynos-web-base-design-system.md`, `.wyn/docs/design/wyn-141-frontend-ux-ui-system.md`,
`.wyn/docs/design/wyn-141-frontend-ux-ui-audit.md`, `web/app/conversation-modern.css`,
`web/app/design-system.css`
