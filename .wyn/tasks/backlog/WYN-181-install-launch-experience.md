# Product Task — WYN-181

Status: backlog
Owner: AI Product Manager
Feature: WYNOS Web — Install & Launch Experience (Track 3 ของ WYN-174, priority P1)
Goal: ทำให้การติดตั้ง WYNOS Web เป็น PWA และการเปิดจากหน้าจอหลักรู้สึกเหมือนแอปจริงมากขึ้น — ไม่พึ่ง browser native prompt เพียงอย่างเดียว และไม่มีจอขาว/กระพริบตอนเปิดจาก home screen บน iOS

## Current state (ตรวจโค้ดจริงแล้ว 2026-09-20)

ทำไปแล้ว (จาก WYN-158):
- `web/app/manifest.ts` — PWA manifest ครบ (name, icons 192/512/maskable, standalone display, theme color)
- `web/app/layout.tsx` — iOS meta ครบ (`apple-mobile-web-app-capable`, `appleWebApp` metadata, viewport-fit=cover, theme-color per color-scheme)
- ไอคอนพร้อมใช้: `public/icons/apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `icon-512-maskable.png`, `public/wynos_logo_mark.png`

ช่องว่างที่ยืนยันแล้วว่าไม่มีในโค้ด (grep ทั้ง `.tsx`/`.ts` = 0 ผลลัพธ์):
1. **Custom install prompt banner** — ไม่มีการดักจับ `beforeinstallprompt`/`appinstalled` event เลย ผู้ใช้ Android/Desktop Chrome ต้องเจอ native browser prompt เท่านั้น (ถ้าเจอเลย เพราะ Chrome จะไม่ auto-prompt ถ้าไม่ผ่านเกณฑ์ engagement heuristic ของมันเอง) ไม่มีทางชวนผู้ใช้ install เองเลยตอนนี้
2. **iOS splash screen** — ไม่มี `apple-touch-startup-image` link เลยใน `layout.tsx` iOS Safari จะโชว์จอขาวเปล่าช่วง 1-2 วินาทีตอนเปิดจาก home screen ก่อนเนื้อหาโหลด (ต่างจาก native app ที่มี splash ทันที)

## Requirements

### 1. Custom install prompt banner
- ดัก `beforeinstallprompt` event, เก็บไว้, กันไม่ให้ browser แสดง native mini-infobar เอง (`event.preventDefault()`)
- แสดง banner ของเราเอง (bottom sheet/bar สไตล์เดียวกับระบบ squircle ปัจจุบัน) ชวนผู้ใช้ "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" พร้อมปุ่ม "ติดตั้ง"/"ไม่ใช่ตอนนี้"
- กดปุ่ม "ติดตั้ง" → เรียก `event.prompt()` จริง (ใช้ event ที่เก็บไว้ ไม่ได้ปลอมของเราเอง)
- ต้องจำว่าผู้ใช้เคยปิด/ปฏิเสธไปแล้ว (localStorage) ไม่โชว์ซ้ำถี่เกินไป
- ไม่แสดงเลยถ้า `display-mode: standalone` อยู่แล้ว (ติดตั้งไปแล้ว) — เช็คด้วย `window.matchMedia('(display-mode: standalone)')`
- iOS Safari ไม่มี `beforeinstallprompt` เลย (ไม่รองรับ API นี้) — ต้องมี banner แยกสำหรับ iOS ที่สอนวิธี manual "แชร์ → เพิ่มไปยังหน้าจอโฮม" แทน (ตรวจ user agent เพื่อแยก 2 เคส)

### 2. iOS splash screen
- generate static launch image ตามขนาดจอ iOS หลักๆ (iPhone SE/8, iPhone X/11/12/13 mini, iPhone 12/13/14, Plus/Max variants, iPad) จากโลโก้ที่มีอยู่ (`wynos_logo_mark.png`) บนพื้นหลังสีขาว/ดำตาม theme
- เพิ่ม `<link rel="apple-touch-startup-image" media="..." href="...">` ใน `layout.tsx` ครบทุกขนาดตาม media query ของแต่ละรุ่น (มาตรฐานที่รู้จักกันดี ต้องระบุ `(device-width)`/`(device-height)`/`(-webkit-device-pixel-ratio)`/`(orientation)` ให้ตรง)
- รองรับทั้ง light/dark ถ้าทำได้ (`prefers-color-scheme` ใน media query ของ `<link>` เอง ตาม spec ที่ iOS รองรับ)

## Acceptance Criteria

- ต้องมี Design spec + preview ให้ Founder อนุมัติก่อน AI Coding เริ่ม (ตามกติกาถาวร)
- ห้ามเปลี่ยน business logic, Supabase contract หรือ feature เดิม
- Banner ต้องเป็น dismissible จริง ไม่บังคับ ไม่บล็อกการใช้งานแอป
- ไม่กระทบ existing PWA manifest/icons ที่ทำงานอยู่แล้ว
- Regression: lint/typecheck/build ผ่าน, ทดสอบ install flow จริงบน Android Chrome + iOS Safari ก่อนถือว่า done (ข้อจำกัด sandbox: ตรวจ code/logic ได้แค่ผ่าน Playwright mock ของ event, ต้องรอ Founder ทดสอบ install จริงบนอุปกรณ์จริง เหมือนทุก UI task ในเซสชันนี้)

## Dependencies

ไม่มี dependency กับ WYN-176 (Visual Design Rollout) โดยตรง แต่ควรใช้ squircle press-feedback pattern เดียวกันสำหรับปุ่มใน banner เพื่อความสม่ำเสมอ

## Priority

P1 — รองจาก WYN-176 (เสร็จแล้ว) ตามลำดับเดิมที่ WYN-174 วางไว้

## Risks

- iOS splash screen ต้องใช้ static image หลายขนาด (ไม่ใช่ CSS/SVG) — ต้อง generate ภาพจริงด้วยสคริปต์ (มี `sharp` package พร้อมใช้ใน `web/node_modules` อยู่แล้ว) ตรวจสอบผลลัพธ์ด้วยสายตาก่อนส่ง QA
- Android install banner heuristic ของ Chrome เอง (`beforeinstallprompt`) อาจไม่ fire ใน environment ทดสอบทันที (ต้องผ่านเกณฑ์ engagement ของ Chrome เองก่อน) — QA ต้อง mock event แทนการรอ event จริงเกิดขึ้นเอง

## Recommendation

เริ่มจาก custom install prompt banner ก่อน (ผลกระทบเห็นชัดกว่า, ทดสอบง่ายกว่าด้วย mock event) แล้วตามด้วย iOS splash screen (ต้อง generate asset หลายไฟล์)

## Handoff

ส่งต่อ **AI Design** ทำ audit UI/UX ของ banner (wording, ตำแหน่ง, timing ที่จะโชว์) + mockup preview ให้ Founder อนุมัติก่อน AI Coding เริ่ม
