# Product Task — WYN-184

Status: active
Owner: AI Product Manager
Parent Epic: WYN-174 (Web Native App Feel รอบ 2) — follow-up หลัง Track 4 (WYN-182)
Feature: Safe-area inset audit รอบ 2 — ครอบคลุม header ที่ไม่ใช่ sticky/fixed
Goal: WYN-182 audit เฉพาะ selector ที่เป็น `position: fixed`/`sticky` เท่านั้น (ตาม scope ที่ Founder อนุมัติไว้ตอนนั้น) — ระหว่างทางเจอ 2 จุดจริงที่นอก scope นั้นแต่เป็นปัญหาเดียวกัน (`.wyn-profile-topbar`, `.flutter-chat-header`) งานนี้ขยาย audit ให้ครอบคลุม **header ทุกแบบที่ไม่ใช่ shared `.route-header`** ไม่ว่าจะ sticky/fixed หรือ static-in-flow ก็ตาม เพื่อปิดช่องว่างให้ครบจริง

## Known findings จาก WYN-182 (ยืนยันแล้ว ไม่ต้องตรวจซ้ำ แต่ยังไม่ได้แก้)

1. **`.wyn-profile-topbar`** (`web/app/profile-golden-final.css:10-18`) — header หน้า Profile (ปุ่มย้อนกลับ/username/ตั้งค่า) ใช้ใน `/profile/[id]`, `/profile/me` — ไม่ใช่ sticky/fixed (อยู่ในเนื้อหาปกติ) ไม่มี `padding-top` safe-area เลย เพราะ `headerMode="hidden"` ทำให้ AppChrome ไม่ใส่ `.route-header` ให้ ปุ่มย้อนกลับ/ชื่อเรนเดอร์ใต้ notch พอดีตั้งแต่โหลดหน้าครั้งแรก
2. **`.flutter-chat-header`** (Chat inbox, `/chat`) — cascade regression จริง: `pixel-parity-audit-closure.css:9-11` เคยใส่ `padding: env(safe-area-inset-top) 12px 0 0;` ไว้ แต่ `chat-notes.css` (บรรทัด 11 และ 537, ตัวหลังชนะ) ประกาศทับด้วย selector specificity สูงกว่า + `!important` โดยไม่มี safe-area เลย — เหมือน cascade bug ที่ WYN-175 เคยเจอ

## Scope (Founder อนุมัติ — เปิด audit ใหม่เต็มรูปแบบ ไม่ใช่แค่ 2 จุดข้างต้น)

1. หา route ทั้งหมดที่ใช้ `headerMode="hidden"` (จาก WYN-182's audit ทราบแล้วว่ามี: Home, Profile, Notifications, Search, Chat inbox, Chat conversation, Club detail, Post detail, Profile follow list) — ตรวจแต่ละหน้าว่า header ที่ประกอบเองมี safe-area-inset-top ครบหรือไม่ (ไม่ใช่แค่ 2 จุดที่รู้แล้ว — ต้องตรวจครบทุกหน้าในลิสต์นี้จริง)
2. สำหรับหน้าที่พบว่ามี safe-area declaration อยู่แล้ว (เช่น `.wyn-home`, `.flutter-search-header`, `.conversation-modern-header` ที่ WYN-182 เคยตรวจว่า OK ไปแล้วในฐานะ sticky element) — ไม่ต้องตรวจซ้ำ เว้นแต่มี cascade risk ใหม่ที่ยังไม่เคยตรวจ
3. เจาะเฉพาะ**header ที่ไม่ใช่ sticky/fixed** (static-in-flow) ที่ WYN-182 ไม่ได้ครอบคลุม — นี่คือช่องว่างที่แท้จริงของรอบนี้
4. ตรวจ cascade ทุกจุดที่พบว่าขาด (ตามวินัยเดิมของ epic — grep ทั้ง repo ก่อนสรุปว่า "ขาด" จริง เผื่อมีการแก้ไว้ที่อื่นแล้วแต่โดนทับ เหมือนกรณี `.flutter-chat-header`)

## Requirements

- ตรวจให้ครบทุก route ที่ใช้ `headerMode="hidden"` ไม่ sample
- เสนอ fix เฉพาะจุดที่ขาดจริง พร้อม evidence file:line
- ห้ามเปลี่ยน business logic/Supabase contract
- Regression: lint/typecheck/build ผ่าน + QA อิสระตรวจซ้ำก่อน Deploy ตามมาตรฐานเดิม

## Priority

P3 (follow-up หลัง Track 4 ของ epic WYN-174 — epic หลักปิดแล้ว งานนี้เป็น gap-closing รอบเสริม)

## Handoff

→ **AI Design** ทำ audit เต็มรูปแบบตาม scope ข้างต้น เขียน spec พร้อมตาราง evidence + fix proposal ให้ Founder อนุมัติก่อน AI Coding เริ่ม (ตามกติกาเดิมของ epic)

## Design Audit — ผลสรุป

**Spec เต็ม**: `.wyn/docs/design/wyn-184-non-sticky-header-safe-area-audit.md` (audit + spec only, ยังไม่แก้โค้ด)

ยืนยัน route enumeration ของ WYN-182 ซ้ำด้วย grep จริง (`headerMode="hidden"` เจอ 9 จุด ตรงกับลิสต์เดิมทุกตัว: Home, Profile, Notifications, Search, Chat inbox, Chat conversation, Club detail, Post detail, Profile follow list) ตรวจ header จริงของทั้ง 9 route ครบ ไม่ sample พบว่า header จริงที่เป็น **static-in-flow** (ไม่ใช่ sticky/fixed) มี 4 กรณี: Home, Profile, Chat inbox, Club detail (ส่วนอีก 5 route path header จริงเป็น sticky อยู่แล้ว หรือ reuse selector เดียวกับ Profile — นอก scope ของ WYN-184 ตามนิยาม trust WYN-182)

**พบ GAP จริง 2 จุด CSS** (กระทบ 5 route path รวมกัน เพราะ 1 selector reuse กัน 2 route):

1. **`.wyn-profile-topbar`** (`web/app/profile-golden-final.css:10-18`) — ไม่มี safe-area เลย ไม่เคยมีใครแก้มาก่อน (ประกาศไฟล์เดียว ไม่มี cascade risk) กระทบ **4 route path**: `/profile/[id]`, `/profile/me`, `/profile/[id]/followers`, `/profile/[id]/following` (Profile follow list ใช้ selector เดียวกันซ้ำ — เพิ่งพบระหว่าง audit นี้ ไม่เคยถูกเอ่ยถึงใน known finding เดิม)
2. **`.flutter-chat-header`** (Chat inbox, `/chat`) — ยืนยัน cascade regression ซ้ำด้วยหลักฐานเต็ม พบว่าจริงๆ มี **5 ไฟล์** ประกาศ selector นี้ (ไม่ใช่ 2 ไฟล์อย่างที่ known finding เดิมระบุ) ไล่ specificity + `!important` + import order แล้วสรุปชัดว่า rule ที่ชนะจริงคือ `web/app/chat-notes.css:537-542` (ไม่มี safe-area) ไม่ใช่ `pixel-parity-audit-closure.css:9-11` ที่เคยพยายามแก้ไว้แต่โดนทับ — **fix ต้องแก้ที่ rule ผู้ชนะเท่านั้น**

**ตรวจแล้วยืนยันว่า OK ไม่ใช่ GAP**: Home (`.wyn-home-header` เป็น static แต่ parent `.wyn-home` เป็น sticky+safe-area อยู่แล้ว) และ Club detail (`.golden-club-back` ปุ่มย้อนกลับมี `top: calc(env(safe-area-inset-top) + 8px)` ถูกต้องอยู่แล้ว)

ทั้ง 2 fix proposal เป็นการเปลี่ยน spacing ที่มองเห็นได้จริงบนอุปกรณ์มี notch/Dynamic Island เท่านั้น (ไม่มีจุดไหนเป็น defensive-only ในรอบนี้) ไม่แตะ business logic/Supabase contract — รอ Founder อนุมัติก่อน AI Coding เริ่ม

**ข้อจำกัด**: session นี้ไม่มี Bash/browser tool จึงตรวจได้แค่จากการอ่าน source + cascade evidence เท่านั้น ยังไม่ได้ยืนยัน computed style บนอุปกรณ์จริง ต้องให้ QA ยืนยันซ้ำบน iPhone ที่มี notch ก่อนปิด task

## Founder Decision (2026-09-20)

ตอบผ่าน AskUserQuestion — **อนุมัติทั้ง 2 จุด**:
1. `.wyn-profile-topbar` เพิ่ม `padding-top: env(safe-area-inset-top)` (หรือเทียบเท่าตามที่ spec เสนอ)
2. `.flutter-chat-header` แก้ที่ rule ผู้ชนะจริง (`web/app/chat-notes.css:537-542`) ให้มี safe-area — **ห้ามแก้ที่ `pixel-parity-audit-closure.css` เพราะเป็น dead code ที่โดนทับอยู่แล้ว**

→ ส่งต่อ **AI Coding** implement ตาม fix proposal ในสเปกเต็ม
