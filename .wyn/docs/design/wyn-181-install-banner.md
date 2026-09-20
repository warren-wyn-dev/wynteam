# WYN-181 — Custom Install Prompt Banner

**Date**: 2026-09-20
**Status**: Pending Founder approval
**Preview**: https://claude.ai/artifact/3Ktj6GuRtW2oLZBTWkKuJv

## Scope check against real code

ตรวจ `web/app/layout.tsx`, `web/app/manifest.ts` ก่อนออกแบบ — ยืนยันว่าไม่มีการดัก `beforeinstallprompt`/`appinstalled` เลยในโค้ดปัจจุบัน (grep = 0 ผลลัพธ์) ไม่มี custom banner ใดๆ ผู้ใช้พึ่ง native browser prompt เท่านั้น (ซึ่ง Chrome เองก็ไม่ auto-show จนกว่าจะผ่านเกณฑ์ engagement heuristic ของมันเอง — เท่ากับว่าตอนนี้แทบไม่มีทางชวนผู้ใช้ install เลย)

## Design

**2 banner แยกตามแพลตฟอร์ม** (ตรวจ user agent):
1. **Android/Desktop Chrome** — ดัก `beforeinstallprompt` จริง เก็บ event ไว้, กันไม่ให้ browser แสดง native mini-infobar เอง, โชว์ banner ของเรา มีปุ่ม "ติดตั้ง" (เรียก `event.prompt()` จริง) กับ "ไม่ใช่ตอนนี้"
2. **iOS Safari** — ไม่มี `beforeinstallprompt` API เลย (ข้อจำกัดจริงของ iOS ไม่ใช่ทางเลือก) ต้องสอน manual 3 ขั้นตอน (แชร์ → เพิ่มไปยังหน้าจอโฮม → แตะเพิ่ม) แทนปุ่มติดตั้ง

**กติกาการแสดงผล**:
- ไม่โชว์เลยถ้า `display-mode: standalone` อยู่แล้ว (ติดตั้งไปแล้ว)
- กดปิด/ไม่ใช่ตอนนี้ → จำด้วย `localStorage`, ไม่โชว์ซ้ำอย่างน้อย 7 วัน
- โชว์ครั้งแรกหลังผู้ใช้ใช้งานเว็บไปสักพัก (ไม่ใช่ทันทีที่เข้าหน้าแรก) — ลด friction
- ไม่บล็อกการใช้งานแอป วางเป็น sheet ลอยด้านล่างจอ

**Visual**: ใช้ token/motion เดียวกับ WYN-163/176 ทั้งเว็บ — ปุ่ม press feedback `scale(0.96)` spring เดียวกัน, radius 20-24px, ไม่ใช้สีรุ้งเต็มพื้นที่ (แค่ icon tile เป็น gradient accent เล็กๆ ตามทิศทาง "white 80-90% + rainbow accent 10-20%")

## Handoff

→ **AI Coding**: สร้าง client component ใหม่ (`InstallPromptBanner` หรือชื่อใกล้เคียง) mount ใน `layout.tsx`, ดัก event ฝั่ง client เท่านั้น (ต้อง `"use client"`), ใช้ localStorage อย่างปลอดภัย (wrap try/catch), ไม่แตะ manifest/PWA setup ที่ทำงานอยู่แล้ว ตรวจสอบด้วย Playwright mock event ก่อนส่ง QA (ไม่สามารถรอ browser จริง fire `beforeinstallprompt` เองในเซสชันได้)
