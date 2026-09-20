# Product Task — WYN-182

Status: active
Owner: AI Product Manager
Parent Epic: WYN-174 (Web Native App Feel รอบ 2) — Track 4, P2
Feature: Platform Integration Polish — safe-area inset coverage + pull-to-refresh/overscroll coverage ทั้งแอป
Goal: ปิดช่องว่างสุดท้ายของ epic WYN-174 ให้ทุกหน้าจอ/ทุก scroll surface ของ `wynos.online` จัดการ notch, home indicator และพฤติกรรม scroll ให้เหมือนแอปมือถือจริงสม่ำเสมอทั้งระบบ ไม่ใช่แค่บางจุดที่เคยทำไปแล้ว
Target User: ผู้ใช้ WYNOS บนมือถือที่มี notch/home indicator (iPhone X ขึ้นไป) และผู้ใช้ทั่วไปที่ scroll list ต่างๆ ในแอป

## Scope (จาก epic WYN-174 requirement P2)

แบ่งเป็น 2 sub-audit:

1. **Safe-area inset audit** — ตรวจทุกหน้า/ทุก fixed หรือ sticky element (bottom nav, header, composer/input bar, action sheet, modal, install banner ฯลฯ) ว่ามี `env(safe-area-inset-*)` ครอบคลุมจริงหรือไม่ จุดไหนขาดให้เพิ่ม
2. **Pull-to-refresh / overscroll audit** — ตรวจทุก scroll surface ว่ามี `overscroll-behavior` กัน rubber-band bounce โผล่พื้นหลังขาว/ผิดที่ และตรวจว่า pull-to-refresh ควรมีอยู่ที่ไหนบ้าง (ปัจจุบันมีแค่ home feed) จุดไหนควรมีแต่ยังไม่มี

## Preliminary findings (ตรวจโค้ดจริงเบื้องต้นแล้ว 2026-09-20)

- `env(safe-area-inset-*)` มีใช้อยู่แล้ว 81 จุดกระจายใน 26 ไฟล์ CSS — coverage กว้างพอสมควรจากงานที่ผ่านมา (WYN-158/163/175/176/181) แต่ยังไม่เคยมีการ audit อย่างเป็นระบบว่าครบทุกจุดจริงหรือไม่
- `overscroll-behavior` มีใช้แค่ 7 จุดใน 6 ไฟล์ (`profile-golden-final.css`, `parity-closure.css`, `interaction-parity-final.css`, `chat-notes.css`, `phase2.css`, `home.css`) — **`html`/`body` ระดับ global ใน `globals.css` ไม่มี base rule เลย** ต้องตรวจว่าเป็นปัญหาจริงหรือไม่ (rubber-band ที่ตัว document เอง ไม่ใช่แค่ scroll container ย่อย)
- Pull-to-refresh พบ implementation จริงแค่ใน `components/home/home-screen.tsx` จุดเดียว — ต้องตรวจว่าหน้าอื่นที่เป็น list/feed แบบเดียวกัน (Club, Notifications, Search results, Bookmarks) ควรมีด้วยหรือไม่ (ไม่ใช่ทุก scroll surface ควรมี เช่น Chat/detail view ไม่ใช่ pattern ที่ควร pull-to-refresh)

## Requirements

1. Design/Coding ทำ audit เต็มรูปแบบ (ไม่ใช่สุ่มตรวจ) ทุก route ใน `web/app/*/page.tsx` + ทุก fixed/sticky selector ใน CSS — สรุปเป็นตารางจุดที่ผ่าน/จุดที่ขาด พร้อมอ้าง grep evidence จริง (ตามวินัยของ session นี้ — ห้ามเดา ห้ามสรุปจากการ sample)
2. เสนอ fix เฉพาะจุดที่ขาดจริง — ห้ามเปลี่ยน layout/behavior ของจุดที่ทำถูกอยู่แล้ว
3. Pull-to-refresh: เสนอเฉพาะจุดที่เป็น feed/list pattern เดียวกับ home ชัดเจน ไม่ใช่ทุก scroll surface (ตามที่ epic เขียนไว้ว่า "ตรวจให้ครบ" ไม่ใช่ "เพิ่มทุกที่")
4. ห้ามเปลี่ยน business logic, Supabase contract หรือ feature ที่ใช้งานอยู่ (ตาม acceptance criteria เดิมของ epic)
5. Regression: lint/typecheck/build ต้องผ่าน + QA อิสระต้องตรวจซ้ำก่อนเข้า Deploy gate ตามมาตรฐานเดิมของ epic นี้ทุก track ที่ผ่านมา

## Acceptance Criteria

- มี audit report ที่ระบุจุดขาดจริงทุกจุดพร้อม evidence (grep/ตรวจ source) ไม่ใช่ assumption
- ทุกจุดที่ระบุว่า "ขาด" ต้องได้รับการแก้ไขจริงและ verify ซ้ำ (ไม่ implement เกิน scope ที่ audit พบ)
- Pull-to-refresh ใหม่ (ถ้ามี) ต้อง reuse mechanism เดิมจาก home feed ไม่ implement ซ้ำใหม่จากศูนย์
- QA ยืนยัน PASS ก่อน Deploy — ตามมาตรฐาน "never trust self-report" ของ epic นี้ทุก track

## Priority

P2 (ตามลำดับเดิมของ epic — เริ่มหลัง Track 2/3 เสร็จ)

## Handoff

→ **AI Design** ทำ audit เต็มรูปแบบทั้ง 2 หัวข้อ (safe-area + overscroll/pull-to-refresh) แล้วเขียน spec พร้อมตารางจุดขาด/ข้อเสนอแก้ ให้ Founder อนุมัติก่อน AI Coding เริ่ม (ตามกติกาถาวรของ epic — audit/technical polish ก็ยังต้องผ่าน spec review แม้ไม่ใช่ UI ใหม่ เพราะบางจุดอาจกระทบ spacing ที่มองเห็นได้)

## Design Audit — ผลสรุป (AI Design, 2026-09-20)

Spec เต็ม: `.wyn/docs/design/wyn-182-platform-integration-polish.md`

**Audit 1 (Safe-area)**: ตรวจ position:fixed/sticky ครบทุก selector ใน `web/app/*.css` (36 ไฟล์) + module CSS (2 ไฟล์) — พบ GAP จริง 3 จุด: `.wyn-profile-tabs`, `.golden-club-tabs` (ทั้งคู่เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch) + `.home-drawer` (defensive ล้วนๆ) ตรวจ cascade ตามบทเรียน WYN-175 ด้วย พบ cascade regression จริงนอก scope ทางการ 2 จุด (`.wyn-profile-topbar`, `.flutter-chat-header`) รายงานแยกให้ Founder ตัดสินใจ

**Audit 2 (Overscroll/PTR)**: ยืนยัน `html`/`body` ไม่มี base `overscroll-behavior` จริง — เสี่ยงสูงเพราะ Home/Club/Chat/Profile scroll ผ่าน document ตรงๆ ไม่มี nested container และ Home's PTR ไม่เรียก `preventDefault()` เลย (เสี่ยง native Android pull-to-refresh ชนซ้อน) พบ scroll container ขาด `overscroll-behavior` อีก 6 จุด (action sheet/modal ที่ reuse กว้าง) วิเคราะห์กลไก PTR ของ Home ละเอียดสำหรับ extract เป็น hook กลาง ตรวจทีละหน้าจริงแล้วแนะนำเพิ่ม PTR ที่ Club posts tab, Notifications, Bookmarks (Profile feed เข้าเกณฑ์เดียวกันแต่เสนอแยกเป็นตัวเลือก ไม่รวม default)

**รอ Founder ตัดสินใจ 3 ประเด็นก่อน AI Coding เริ่ม**: (ก) safe-area tabs 2 จุดที่เปลี่ยน spacing บนอุปกรณ์มี notch (ข) `overscroll-behavior-y: contain` ที่ html/body ที่เปลี่ยนพฤติกรรม scroll ทั้งแอป (ค) PTR ใหม่ 3 หน้า (+Profile เป็นตัวเลือกเสริม) ต้อง gate ด้วย staged-rollout (`isDeveloperAccount()`) หรือไม่

## Founder Decision (2026-09-20)

ตอบผ่าน AskUserQuestion ครบ 3 ข้อ:
1. **Safe-area tabs (`.wyn-profile-tabs`, `.golden-club-tabs`)** — **อนุมัติ** ให้แก้ตามที่เสนอ
2. **`overscroll-behavior-y: contain` ที่ `html`/`body`** — **อนุมัติ** ให้แก้ตามที่เสนอ
3. **Pull-to-refresh scope** — **อนุมัติให้รวม Profile feed เข้าไปด้วย เป็น 4 หน้ารวม**: Club detail (แท็บโพสต์), Notifications, Bookmarks, Profile feed — Founder ไม่ได้เลือกตัวเลือก "ไม่ต้อง gate" จึงยึดตาม default ที่ spec เสนอไว้: **gate ทั้ง 4 หน้าด้วย staged-rollout (`isDeveloperAccount()`)** ตาม WYN-125 เนื่องจากเป็น user-facing feature ใหม่

**Scope สุดท้ายสำหรับ AI Coding**: fix proposal ข้อ 1-10 ทั้งหมดตาม spec (safe-area 3 จุด + overscroll 7 จุด รวม html/body) + extract pull-to-refresh hook จาก `home-screen.tsx` ไปใช้ใน 4 หน้า (Club posts tab, Notifications, Bookmarks, Profile feed) โดย gate ด้วย `isDeveloperAccount()` เป็นค่าเริ่มต้น

→ ส่งต่อ **AI Coding** implement ตาม scope นี้
