# WYN-182 — Platform Integration Polish: Safe-area + Overscroll/Pull-to-refresh Audit

**Date**: 2026-09-20
**Status**: Pending Founder approval (audit + spec only — ไม่มีโค้ดถูกแก้ในรอบนี้)
**Epic**: WYN-174 (Web Native App Feel รอบ 2) — Track 4/P2, track สุดท้าย

## หมายเหตุก่อนเริ่ม

งานนี้เป็น audit เต็มรูปแบบ ไม่ใช่ sampling — ทุกแถวในตารางด้านล่างมาจากการ `grep`/อ่าน source จริง ไม่มีจุดไหนสรุปจากการเดา รายการ selector ที่ตรวจคือ **ทุกไฟล์** ใน `web/app/*.css` (36 ไฟล์) และ `web/components/**/*.module.css` (2 ไฟล์) — ตรงตาม scope ที่ task ระบุ ไม่ใช่แค่ไฟล์ที่ preliminary findings เคยพูดถึง

**ข้อจำกัดของ session นี้**: เครื่องมือที่มีคือ Read/Grep/Glob เท่านั้น ไม่มี Bash/browser tool จึงไม่สามารถรัน `next dev` หรือเปิด browser จริงเพื่อทดสอบ physical rubber-band ได้ — ส่วนที่ต้อง "ทดสอบจริง" (โดยเฉพาะ Audit 2 ข้อ 1) ใช้การไล่โค้ดพฤติกรรมจริงแทน (มี native browser behavior ที่มีเอกสารรองรับชัดเจน) และระบุจุดที่ต้องให้ QA ยืนยันซ้ำบนอุปกรณ์จริงไว้ชัดเจน

---

## Audit 1: Safe-area inset coverage

### Route enumeration

`web/app/**/page.tsx` มีทั้งหมด 36 ไฟล์ — ในจำนวนนี้ **9 ไฟล์ไม่ใช่หน้าจอที่ผู้ใช้จริงเห็น** (ตรวจยืนยันจาก source จริง ไม่ใช่สมมติฐาน):

- `web/app/home/page.tsx`, `web/app/compose-post/page.tsx`, `web/app/followers/page.tsx`, `web/app/post/[postId]/page.tsx`, `web/app/profile/edit/page.tsx`, `web/app/clubs/new/invite/page.tsx`, `web/app/club/wynos-community/invite/page.tsx` — ทุกไฟล์มี `if (process.env.NODE_ENV === "production") redirect(...)` เรนเดอร์ `content-reference` fixture (mock data, ไม่มี auth) เฉพาะตอน `next dev` สำหรับ `tests/browser/content-reference-flow.spec.ts` เท่านั้น ผู้ใช้จริงไปไม่ถึง
- `web/app/dev/wyn-175-skeleton-fixture/page.tsx`, `web/app/dev/home-fixture/page.tsx` — dev fixture ตรงไปตรงมา ไม่มี guard แต่ไม่มี entry point ในแอปจริงชี้มาที่นี่

เหลือ **27 route ที่ผู้ใช้จริงเข้าถึงได้**: `/`, `/search`, `/settings`, `/notifications`, `/clubs`, `/clubs/new`, `/chat`, `/chat/[id]`, `/bookmarks`, `/drafts`, `/account/add`, `/[profileSlug]`, `/profile/[id]`, `/profile/[id]/followers`, `/profile/[id]/following`, `/profile/me`, `/pop/[id]`, `/drop/[id]`, `/club/[id]`, `/club-post/[id]`, `/club-invite/[code]`, `/(auth-flow)/signup/step-1`, `/(auth-flow)/signup/step-2`, `/(auth-flow)/welcome`, `/(auth-flow)/onboarding/profile`, `/(auth-flow)/forgot-password`, `/(auth-flow)/login`

Route ส่วนใหญ่ใช้ shared chrome (`AppChrome` ใน `web/components/phase3-ui.tsx`) ซึ่ง render `.route-header`/`.route-main`/`.route-app` และ bottom nav แยกผ่าน `AppBottomNavHost` (`.route-bottom-nav`) — กลุ่มนี้ตรวจครั้งเดียวที่ระดับ shared component ก็ครอบคลุมทุก route ที่ใช้ แต่มีหลายหน้าที่ใช้ `headerMode="hidden"` (Home, Profile, Notifications, Search, Chat inbox, Chat conversation, Club detail, Post detail, Profile follow list) — หน้ากลุ่มนี้ **ประกอบ header เองทั้งหมด ไม่ได้พึ่ง `.route-header`** จึงต้องตรวจแยกทีละหน้า (ทำครบแล้วด้านล่าง)

### Selector table (position: fixed / position: sticky ทั้งหมด — 31 จุดประกาศ, ยุบเหลือ ~24 selector จริงหลังนับ cascade)

| Selector | File:line | Position | ขอบที่แตะ | มี safe-area inset? | Verdict |
|---|---|---|---|---|---|
| `.wyn-home` | `home.css:12` | sticky top:0 | top | ใช่ (`padding-top: min(env(safe-area-inset-top),20px)`) | OK |
| `.route-header` | `phase3.css:15` | sticky top:0 | top | ใช่ (`padding-top: env(safe-area-inset-top)`) | OK (cascade-confirmed, ดูหมายเหตุ) |
| `.route-bottom-nav` | `bottom-nav.css:31` | fixed bottom:0 | bottom | ใช่ (`--wyn-nav-safe-bottom: min(env(safe-area-inset-bottom),20px)`) | OK |
| `.sheet-backdrop` | `phase2.css:30` | fixed inset:0 | overlay เต็มจอ | N/A (ไม่มี interactive content ชิดขอบเอง) | OK — เนื้อหาจริงอยู่ใน `.sheet` ลูก ซึ่งมี `padding-bottom: env(safe-area-inset-bottom)` (`phase2.css:46`) |
| `.toast` | `phase2.css:283` | fixed bottom | bottom | ใช่ (`bottom: calc(82px + env(safe-area-inset-bottom))`) | OK |
| `.flutter-search-header` | `parity-completion.css:7` | sticky top:0 | top | ใช่ | OK (cascade-confirmed, ดูหมายเหตุ) |
| `.flutter-search-tabs` | `parity-completion.css:17` | sticky top:calc(64px+inset) | ไม่แตะขอบจริง (offset ใต้ header) | N/A | OK — offset รวม inset ของ header ไว้แล้ว |
| `.notification-root-header` | `parity-completion.css:47` | sticky top:0 | top | ใช่ | OK (cascade-confirmed, ดูหมายเหตุ) |
| `.flutter-notification-tabs` | `parity-completion.css:50` | sticky top:calc(60px+inset) | ไม่แตะขอบจริง | N/A | OK |
| `.wyn-note-screen` | `chat-notes.css:266` | fixed inset:0 | top+bottom | ตัวเองมี `overflow-y:auto; overscroll-behavior:contain`; ลูก `.wyn-note-composer` มี padding ทั้ง top และ bottom | OK |
| `.route-modal-backdrop` | `phase3.css:357` | fixed inset:0 | overlay เต็มจอ | N/A | OK — ลูก `.route-modal` มี `padding-bottom: env(safe-area-inset-bottom)` (`phase3.css:358`) |
| `.message-composer` | `phase3.css:385` | fixed bottom | bottom | ใช่ (`bottom: env(safe-area-inset-bottom)`) | OK |
| `.conversation-request-bar` | `phase3.css:401` | sticky bottom | bottom | ใช่ | OK |
| `.detail-comment-form` | `phase3.css:446` | fixed bottom | bottom | ใช่ (`bottom: calc(62px + env(safe-area-inset-bottom))`) | OK |
| `.detail-composer-shell` | `post-detail-parity.css:49` + ถูกเขียนทับที่ `system-parity-final.css:230` | fixed bottom | bottom | ใช่ทั้งคู่ | OK (cascade-confirmed, ดูหมายเหตุ) |
| `.conversation-modern-header` | `conversation-modern.css:9` | sticky top:0 | top | ใช่ (`padding: calc(env(safe-area-inset-top)+8px)...`) | OK |
| `.conversation-modern .conversation-request-bar` | `conversation-modern.css:295` | fixed bottom (override) | bottom | ใช่ (`bottom: calc(70px + env(safe-area-inset-bottom))`) | OK |
| `.home-drawer-backdrop` | `parity-final.css:137` | fixed inset:0 | overlay เต็มจอ | N/A | OK — ลูก `.home-drawer` มี `padding-top: env(safe-area-inset-top)` |
| `.home-drawer` (ลูกของข้อบน) | `parity-final.css:143` | ไม่ fixed/sticky เอง (อยู่ใน fixed overlay) | top OK, **bottom ไม่มี** | top ใช่ / bottom ไม่มี | **GAP (defensive)** — ดูด้านล่าง |
| `.detail-floating-header` | `system-parity-final.css:158` | sticky top:0 | top | ใช่ (`padding-top: env(safe-area-inset-top)`) | OK |
| `.wyn-bottom-nav` | `design-system.css:318` | sticky bottom:0 | bottom | ใช่ | **N/A — dead code ในโปรดักชัน** ใช้จริงเฉพาะใน `components/content-reference/*.tsx` ซึ่ง route ที่ mount มัน (`/home`, `/compose-post` ฯลฯ) ทุกตัว `redirect()` ทิ้งใน production (ดูหัวข้อ Route enumeration) — ไม่กระทบผู้ใช้จริง ไม่ต้องแก้ |
| `.wyn-profile-tabs` (class จริงคือ `route-tabs wyn-profile-tabs`) | `profile-golden-final.css:201` | sticky top:0 | top | **ไม่มี** | **GAP** |
| `.golden-club-tabs` | `club-detail-golden.css:31` | sticky top:0 | top | **ไม่มี** | **GAP** |
| `.golden-club-composer` | `club-detail-golden.css:84` | sticky bottom:0 | bottom | ใช่ (`padding: 8px 10px calc(8px + env(safe-area-inset-bottom))`) | OK |
| `.wyn-toast` | `skeleton.css:168` | fixed bottom | bottom | ใช่ | OK |
| `.install-prompt-banner` | `install-prompt.css:3` | fixed bottom | bottom | ใช่ | OK |
| `.audit-undo-toast` | `parity-audit.css:131` | fixed bottom | bottom | ใช่ | OK |
| `.menuBackdrop` (`wynii-chat.module.css`) | `wynii-chat.module.css:73` | fixed inset:0 | overlay โปร่งใส (click-catcher) | N/A — dropdown ลูก (`.menu`) วางแบบ absolute ใกล้ปุ่มกด ไม่ชิดขอบจอ | OK |
| `.sheetBackdrop` (`wynii-chat.module.css`) | `wynii-chat.module.css:121` | fixed inset:0 | overlay เต็มจอ | N/A | OK — ลูก `.sheet` มี `padding: 16px 18px calc(24px + env(safe-area-inset-bottom))` |

### Cascade verification (สิ่งที่ session นี้ตรวจเพิ่มตามบทเรียน WYN-175)

`.notification-root-header`, `.flutter-notification-tabs`, `.flutter-search-header` ถูกประกาศซ้ำถึง **4 ไฟล์** (`parity-completion.css`, `system-parity-lock.css`, `pixel-parity-audit-closure.css`, `notifications-clean.css`) — ไล่ลำดับ import ใน `layout.tsx` (บรรทัด 8-44) แล้วพบว่า `notifications-clean.css` ถูก import **หลังสุด** ในกลุ่มนี้ (ลำดับที่ 33 จาก 37 ไฟล์) จึงเป็นตัวที่ชนะจริงสำหรับ property ที่มันแตะ (`notifications-clean.css:2-10`) — ตรวจแล้วยืนยันว่าตัวที่ชนะยังคง `env(safe-area-inset-top)` ไว้ (`height: calc(68px + env(safe-area-inset-top)) !important; padding: calc(env(safe-area-inset-top) + 5px) 14px 0 !important;`) **ไม่ใช่ gap** แต่เป็นจุดที่เสี่ยงสูงและควรมีคนตรวจซ้ำทุกครั้งที่มีคนแก้ 1 ใน 4 ไฟล์นี้โดยไม่เช็คอีก 3 ไฟล์

`.detail-composer-shell` ถูกประกาศ 2 จุด (`post-detail-parity.css:49`, `system-parity-final.css:230`) — `system-parity-final.css` import ทีหลังและ property `padding` ถูกประกาศซ้ำเต็ม จึงชนะทั้งอัน — ยืนยันว่าตัวที่ชนะยังมี `max(9px, env(safe-area-inset-bottom))` OK

`.route-main:has(.settings-page) > .route-header` ถูกประกาศ 2 จุด (`system-parity-lock.css:329` ไม่มี inset, `pixel-parity-audit-closure.css:241` มี `padding-top: env(safe-area-inset-top)`) — specificity เท่ากัน, `pixel-parity-audit-closure.css` import ทีหลัง ชนะ และเป็นตัวที่มี inset จึงใช้งานได้จริง OK

**พบ cascade regression จริง 1 จุด** (นอก scope ของ audit นี้ตามนิยาม fixed/sticky แต่เป็นปัญหาประเภทเดียวกัน) — ดูหัวข้อ "ข้อสังเกตเพิ่มเติม" ด้านล่าง

### GAP ที่ยืนยันแล้ว (Audit 1)

**GAP 1 — `.wyn-profile-tabs`** (`web/app/profile-golden-final.css:200-212`)
ใช้ในหน้า `/profile/[id]` และ `/profile/me` (ผ่าน `web/components/profile-route.tsx:294`, class จริงคือ `route-tabs wyn-profile-tabs`) หน้า Profile ใช้ `headerMode="hidden"` (ไม่มี `.route-header` มาช่วย) แท็บ สื่อ/รีโพสต์/ถูกใจ เป็น `position: sticky; top: 0` — เมื่อผู้ใช้ scroll ผ่าน header/avatar/stats ไปแล้ว แท็บนี้จะไปติดที่ขอบบนสุดจริงของจอ (`top:0`) โดยไม่มี padding ชดเชย notch/Dynamic Island เลย
**Fix ที่เสนอ**: เพิ่ม `padding-top: env(safe-area-inset-top);` ใน rule เดิม และปรับ `height`/`min-height` เป็น `calc(56px + env(safe-area-inset-top))` (ตามรูปแบบเดียวกับ `.golden-club-composer`/`.notification-root-header` ที่ทำอยู่แล้ว) — **เปลี่ยน spacing ที่มองเห็นได้** บนอุปกรณ์มี notch เท่านั้น (แท็บจะขยับลงจากตำแหน่งเดิมตอน sticky ~1 status-bar height) อุปกรณ์ไม่มี notch (เช่น Android ส่วนใหญ่ที่ inset-top=0) จะไม่เห็นความต่าง

**GAP 2 — `.golden-club-tabs`** (`web/app/club-detail-golden.css:31`)
ใช้ในหน้า `/club/[id]` (Club detail) แท็บ โพสต์/แชท/เกี่ยวกับ เป็น `position: sticky; top: 0` เหมือนกรณีข้างต้นเป๊ะ — หน้านี้ไม่มี `.route-header` เช่นกัน (`headerMode="hidden"`, ใช้ banner + back button ของตัวเองแทน ซึ่ง back button มี inset ถูกต้องอยู่แล้วที่ `club-detail-golden.css:13`) เมื่อ scroll ผ่าน banner (140px) ไป แท็บจะไปติดขอบบนจริงโดยไม่มี inset
**Fix ที่เสนอ**: เพิ่ม `padding-top: env(safe-area-inset-top);` และปรับ `height` เป็น `calc(54px + env(safe-area-inset-top))` — **เปลี่ยน spacing ที่มองเห็นได้** เฉพาะอุปกรณ์มี notch เช่นเดียวกับ GAP 1

**GAP 3 (defensive) — `.home-drawer`** (`web/app/parity-final.css:143-149`)
Drawer เมนูข้าง (`web/components/home/home-drawer.tsx`) มี `padding-top: env(safe-area-inset-top)` แต่ไม่มี bottom padding เลย เมนูมีสูงสุด 6 แถว (~500-550px รวม header/identity/divider) — บนจอสูง (iPhone 12 ขึ้นไป) ไม่ชนขอบล่างแน่นอน แต่บนจอเตี้ย (iPhone SE, 568-667px) มีโอกาสที่แถวสุดท้าย ("เพิ่ม WYNOS ไว้ที่หน้าจอหลัก") จะอยู่ชิด/ใกล้ home indicator มากเกินไป — เป็น GAP เชิง defensive ไม่ยืนยันว่าพังจริงบนทุกอุปกรณ์ แต่แก้ได้แบบ additive ล้วนๆ
**Fix ที่เสนอ**: เพิ่ม `padding-bottom: env(safe-area-inset-bottom);` ที่ `.drawer-menu-list` (`parity-final.css:219`) — **ไม่กระทบ spacing ที่มองเห็นบนอุปกรณ์ไม่มี home indicator** (env()=0) เพิ่มที่ว่างเฉพาะอุปกรณ์มี home indicator เท่านั้น

### ข้อสังเกตเพิ่มเติม (นอก scope ทางเทคนิคของ audit นี้ แต่เป็นปัญหาประเภทเดียวกัน — รายงานให้ Founder ตัดสินใจว่าจะรวมไว้ในรอบแก้นี้หรือแยกเป็นงานถัดไป)

Task นี้กำหนด scope ไว้ชัดเจนว่า "ทุก selector ที่ใช้ `position: fixed`/`position: sticky`" — สองจุดนี้ **ไม่ใช่** fixed/sticky (เป็น header แบบอยู่กับที่ในเนื้อหาปกติ) จึงไม่นับเป็น GAP อย่างเป็นทางการของ audit นี้ แต่ตรวจพบระหว่างไล่ cascade แล้วเข้าข่ายปัญหาเดียวกัน (ชนขอบบนจอ notch) จึงบันทึกไว้:

1. **`.wyn-profile-topbar`** (`profile-golden-final.css:10-18`) — header (ปุ่มย้อนกลับ/username/ตั้งค่า) ของหน้า Profile ไม่ใช่ sticky ไม่มี `padding-top` สำหรับ safe-area เลย ใช้ทั้งใน `/profile/[id]`, `/profile/me` เพราะ `headerMode="hidden"` ทำให้ AppChrome ไม่ใส่ `.route-header` ให้ — ปุ่มย้อนกลับ/ชื่อจะเรนเดอร์ใต้ status bar/notch พอดีตั้งแต่โหลดหน้าครั้งแรก (ไม่ต้อง scroll ก่อน)
2. **`.flutter-chat-header`** (Chat inbox, `/chat`) — พบ **cascade regression จริง**: `pixel-parity-audit-closure.css:9-11` เคยใส่ `padding: env(safe-area-inset-top) 12px 0 0;` ไว้แล้ว แต่ selector ที่ specificity สูงกว่า (`.wyn-chat-inbox .flutter-chat-header`, 2 class) ถูกประกาศทับใน `chat-notes.css` ถึง 2 รอบ (บรรทัด 11 และ 537 — รอบหลังชนะ) ด้วย `padding: 6px 18px 0 14px !important;` **ไม่มี safe-area เลย** ผลคือ header ของ Chat inbox ในโปรดักชันจริงไม่มี top inset ทั้งที่เคยมีคนพยายามแก้ไว้แล้วในไฟล์อื่น — นี่คือตัวอย่าง cascade bug แบบเดียวกับที่ WYN-175 เจอเป๊ะ (แก้ถูกที่ไฟล์หนึ่ง แต่ไฟล์ specificity สูงกว่า/import ทีหลังทับซ้ำ)

ถ้า Founder ต้องการให้แก้ 2 จุดนี้พร้อมกันในรอบเดียว แจ้งได้ — ไม่อยู่ใน fix proposal หลักด้านล่างเพราะเกินนิยาม scope ที่ task กำหนด (fixed/sticky only)

---

## Audit 2: Overscroll-behavior + Pull-to-refresh coverage

### 1. `html`/`body` ไม่มี base `overscroll-behavior` — ยืนยันว่าเป็นบั๊กจริง ไม่ใช่แค่ทฤษฎี

`web/app/globals.css` (อ่านทั้งไฟล์แล้ว) ไม่มี `overscroll-behavior` บน `html`/`body` เลย — ยืนยันตรงกับ preliminary finding และตรวจเพิ่มว่า **ไม่มีไฟล์ไหนใน 36 ไฟล์ตั้งค่านี้ที่ `html`/`body` เลยแม้แต่ไฟล์เดียว** (grep `overscroll-behavior` ทั้ง repo เจอ 7 จุด ไม่มีจุดไหนเป็น `html`/`body`)

เหตุผลที่นี่เป็นบั๊กจริง ไม่ใช่ theoretical:
- Home feed (`/`), Club detail ทุกแท็บ (`/club/[id]`), Chat conversation (`/chat/[id]`), Profile feed (`/profile/[id]`) **ไม่มี** nested `overflow-y` container ของตัวเอง (ตรวจแล้วจาก `home.css`, `conversation-modern.css`, `club-detail-golden.css` — มีแค่ `overflow-x` สำหรับ media rail แนวนอน) หมายความว่าทุกหน้าเหล่านี้ scroll ผ่าน **document/body โดยตรง** — จุดเดียวที่ป้องกัน overscroll ได้คือ `html`/`body` เท่านั้น ไม่มี fallback อื่น
- Home มี custom pull-to-refresh ที่ implement ด้วย React touch handler ล้วนๆ (`onTouchStart`/`onTouchMove`/`onTouchEnd`, `web/components/home/home-screen.tsx:715-796`) **ไม่มีการเรียก `preventDefault()` ที่จุดไหนเลย** — บน Android Chrome (ไม่ได้ install เป็น PWA/เปิดใน browser tab ปกติ) ที่ scrollY=0 การลากลงจะ trigger **native pull-to-refresh ของ Chrome เอง** (reload หน้าทั้งหน้า) **พร้อมกัน**กับ custom refresh ของแอป — เป็น known browser behavior ที่มีเอกสารรองรับ (`overscroll-behavior-y: contain` คือ fix มาตรฐานที่ MDN/web.dev แนะนำสำหรับ conflict แบบนี้โดยเฉพาะ) ผลคือถ้าผู้ใช้ลากลงแรงพอบน Android Chrome มีโอกาสสูงที่ทั้งแอปจะ reload ทั้งหน้า (เสีย React state, ต้อง auth ใหม่ตาม cache) แทนที่จะได้แค่ refresh feed แบบเบาที่ตั้งใจไว้
- **ข้อจำกัดที่ต้องแจ้ง**: session นี้ไม่มี Bash/browser tool จึงไม่สามารถเปิด Chrome/Playwright จริงมายืนยัน reload ที่เกิดขึ้นจริงได้ — เหตุผลข้างต้นอิงจาก (ก) พฤติกรรม native ของ Chrome ที่มีเอกสารรองรับ (ข) การอ่านโค้ด touch handler จริงยืนยันว่าไม่มี `preventDefault` ที่จุดไหนเลย **ต้องให้ QA ยืนยันซ้ำบน Android Chrome จริง (ไม่ใช่ desktop emulation)** ก่อนปิด task นี้ เพราะ mobile-chrome-native-pull-to-refresh เป็นพฤติกรรมระดับ browser chrome ที่ Playwright/Chromium headless ปกติไม่ reproduce ให้เห็น

**Fix ที่เสนอ**: เพิ่มใน `web/app/globals.css` ต่อจาก rule `body {}` ที่มีอยู่แล้ว (บรรทัด 79-87):
```css
html,
body {
  overscroll-behavior-y: contain;
}
```
เลือก `contain` (ไม่ใช่ `none`) เพราะ `contain` แก้ปัญหา native-PTR-ชนกับ custom-PTR ได้ตรงจุด โดยไม่ลบ rubber-band bounce แบบ native ของ iOS Safari ที่ทีมนี้ตั้งใจรักษาไว้ทั่วแอป (เห็นได้จากอีก 7 จุดที่มีอยู่แล้วก็เลือก `contain` เหมือนกันทั้งหมด ไม่มีจุดไหนใช้ `none`) — **นี่คือการเปลี่ยนพฤติกรรมการ scroll ที่มองเห็น/สัมผัสได้** (ไม่ใช่ spacing) เฉพาะตอนผู้ใช้ลากเกินขอบบนสุด/ล่างสุดของหน้า ต้องแจ้ง Founder รับทราบก่อนแก้ แม้จะเป็น fix บรรทัดเดียวก็ตาม

### 2. Scroll container อื่นๆ ที่ขาด `overscroll-behavior`

ตารางนี้คือทุก selector ที่มี `overflow-y: auto|scroll` หรือ `overflow: auto|scroll` ใน `web/app/*.css` + `web/components/**/*.module.css` (grep ครบ ไม่ sample):

| Selector | File:line | Verdict | หมายเหตุ |
|---|---|---|---|
| `.sheet-scroll` | `phase2.css:78-81` | OK | มี `overscroll-behavior: contain` อยู่แล้ว |
| `.wyn-note-screen` | `chat-notes.css:265-273` | OK | มีอยู่แล้ว |
| `.profile-account-list` | `profile-golden-final.css:318-321` | OK | มีอยู่แล้ว (สลับบัญชี) |
| `.beta4-composer-scroll` | `system-parity-final.css:263` (เลื่อนเนื้อหา composer) | OK สำหรับมือถือ | มี `overscroll-behavior:contain` แต่ scope อยู่ใน `@media (max-width:680px)` เท่านั้น (`interaction-parity-final.css:32-33`) — จอ >680px (desktop/tablet) ไม่มี แต่กลุ่มเป้าหมายของ audit นี้ (notch phone) อยู่ในช่วง ≤680px เสมอ ไม่ใช่ gap เร่งด่วน บันทึกไว้เป็นความไม่สมมาตรเล็กน้อย |
| `.message-composer textarea` | `phase3.css:391` | ไม่นับเป็น gap | เป็น native `<textarea>` scroll ภายในกล่องข้อความเล็กๆ ไม่ใช่ scroll surface ระดับหน้าจอ risk ของ rubber-band เผยพื้นหลังผิดที่แทบไม่มี (พื้นหลัง textarea กับพื้นหลังหน้าเป็นสีเดียวกันอยู่แล้ว) |
| `.route-modal` | `phase3.css:358` | **GAP** | Action sheet/dialog กลาง ใช้ใน Profile (สลับบัญชี/เมนูเพิ่มเติม), Home, Settings, Chat, Drafts (ยืนยันลบ), Composer, Quote-redrop — reuse กว้างมาก |
| `.requests-modal` | `parity-completion.css:44` | **GAP** | Modal คำขอข้อความใน Chat inbox |
| `.detail-activity-content` | `post-detail-parity.css:65` | **GAP** | รายชื่อคนไลก์/กิจกรรมใน bottom sheet ของ Post detail — scroll container แยกจาก sheet แม่ (`.detail-activity-sheet` เอง `overflow:hidden`) |
| `.golden-drop-sheet` | `golden-drop-card.css:32` | **GAP** | Sheet แชร์/รายงานโพสต์ ใช้ร่วมกันทั้ง Home/Profile/Search/Saved (ตามคอมเมนต์ในไฟล์เอง) — reuse กว้างที่สุดในกลุ่มนี้ |
| `.golden-club-sheet` | `club-detail-golden.css:117` | **GAP** | Sheet เมนู Club detail (แชร์/รายงาน/ออกจาก Club) |
| `.audit-action-sheet` | `parity-audit.css:5` | **GAP** | Sheet "เพิ่มเติม" ของ Home และของ Profile (`profile-parity-route.tsx`) |

ตรวจ cascade ของทั้ง 6 selector ที่เป็น GAP แล้ว — **ทุกตัวประกาศครั้งเดียวในทั้ง repo** (มีแค่ media-query เสริมเรื่อง border ที่ไม่แตะ `overflow`/`overscroll-behavior`) จึงไม่มีความเสี่ยงเรื่อง cascade override เพิ่ม `overscroll-behavior: contain;` เข้า rule เดิมได้ตรงๆ ปลอดภัย

**Fix ที่เสนอ**: เพิ่ม `overscroll-behavior: contain;` ในแต่ละ rule ที่ระบุ (ค่าเดียวกับ 7 จุดที่มีอยู่แล้วในระบบ เพื่อความสม่ำเสมอ) — **เป็น fix เชิง defensive ล้วนๆ ไม่มีผลต่อ spacing/layout ที่มองเห็น** ผลที่มองเห็นได้มีแค่ตอนผู้ใช้ scroll เกินขอบบน/ล่างของ sheet เท่านั้น (ไม่ให้ scroll ทะลุไปกระทบพื้นหลังหลังบ้าน)

ไฟล์ `chat-reference.css` (`.content-ref-viewport .chat-list-scroll`, `.chat-conversation-scroll`) มี `overflow-y:auto` เช่นกันแต่เป็น class เฉพาะของ `content-reference/screens.tsx` — dev-only fixture ตามที่ยืนยันไว้ใน Audit 1 (route ที่ mount มันถูก redirect ทิ้งใน production ทั้งหมด) **ไม่นับเป็น gap**

### 3. กลไก Pull-to-refresh ของ Home — วิเคราะห์เพื่อวางแผน reuse

`web/components/home/home-screen.tsx` implement เป็น **custom touch-handler ล้วนๆ ฝังอยู่ในคอมโพเนนต์เดียว** ไม่ใช่ library และไม่ใช่ hook แยก (grep ทั้ง repo หา `usePullToRefresh`/`PullToRefresh` เจอแค่ไฟล์นี้ไฟล์เดียว — ยังไม่เคย extract ออกมาเป็น reusable hook เลย):

- `onTouchStart` (บรรทัด 715-723): บันทึกจุดเริ่มลาก + `canPull: window.scrollY <= 2 && !refreshing && mode === visibleModeRef.current`
- `onTouchMove` (บรรทัด 724-757): **ผูกรวมกับ gesture อื่นในตัวเดียวกัน** — ถ้าลากแนวนอนเด่นชัด (`|deltaX| > 8 && |deltaX| > |deltaY|`) จะเป็นการสไลด์สลับแท็บ (สำหรับคุณ/กำลังติดตาม/คลับของฉัน) ไม่เกี่ยวกับ pull-to-refresh; ถ้าลากแนวตั้งและ `canPull` เป็นจริง จะ dampen ระยะทาง (`Math.min(88, deltaY * 0.48)`) เก็บใน `pullDistance` state
- `onTouchEnd` (บรรทัด 758-791): ถ้า `canPull && releasedPullDistance >= 54 && deltaY > |deltaX|` → เรียก `haptic()` แล้ว `refreshVisibleMode()`
- `onTouchCancel` (บรรทัด 792-796): reset ทั้งหมด
- UI spinner: `<div className="route-system-spinner tiny">` วาง absolute ปรับ opacity/scale ตามสัดส่วน `pullDistance/54` (บรรทัด 829-846)
- ไม่มีการเรียก `event.preventDefault()` ที่จุดไหนเลยในทั้ง 4 handler

**ผลต่อการ reuse**: เนื้อ pull-gesture (canPull/damping/threshold/haptic/spinner) แยกออกจาก horizontal-tab-swipe ได้ชัดเจนอยู่แล้วในโค้ด (คนละ branch ใน `onTouchMove`/`onTouchEnd`) — AI Coding ควร **extract เฉพาะส่วน pull-gesture ออกเป็น hook กลาง** (เช่น `usePullToRefresh({ enabled, onRefresh })` คืนค่า `pullDistance`, `refreshing`, และ handler ทั้ง 4 ตัว) แล้วให้ Home เรียก hook นี้ + ต่อยอด horizontal-swipe ของตัวเองทับ ส่วนหน้าจอใหม่ (list เดียว ไม่มี tab-swipe) เรียก hook ตรงๆ **ห้าม copy โค้ด touch handler ทั้งชุดไปวางซ้ำ** — ตรงตาม acceptance criteria ข้อ 3 ของ task นี้

### 4. หน้าจอที่ควร/ไม่ควรมี Pull-to-refresh — ตรวจทีละหน้าจริง ไม่ใช่แค่ชื่อที่ preliminary findings เดาไว้

| หน้าจอ | Component | Pattern จริง | Realtime auto-update อยู่แล้วไหม | คำแนะนำ | เหตุผล |
|---|---|---|---|---|---|
| Home feed (`/`) | `home-screen.tsx` | List การ์ดโพสต์ document-scroll, ไม่มี realtime | ไม่มี | (มีอยู่แล้ว — baseline) | — |
| **Club detail — แท็บ "โพสต์"** (`/club/[id]`) | `club-detail-golden.tsx` | List การ์ดโพสต์ document-scroll, จำกัด 100 รายการ, ไม่มี realtime (`grep` ยืนยัน realtime มีแค่สำหรับแชทของ Club เท่านั้น ที่ `club-detail-golden.tsx:387`) | ไม่มี (เฉพาะแท็บโพสต์) | **แนะนำเพิ่ม** | รูปแบบเดียวกับ Home เป๊ะ (การ์ดโพสต์, ไม่มี auto-refresh, เนื้อหาเปลี่ยนเมื่อสมาชิกคนอื่นโพสต์) — ต้อง scope ให้ pull ทำงานเฉพาะตอนแท็บ "โพสต์" active เท่านั้น (แท็บ แชท/เกี่ยวกับ ไม่ใช่ pattern นี้ — ดูแถวถัดไป) |
| Club detail — แท็บ "แชท" | เดียวกัน | Message list | มี realtime (`club-detail-golden.tsx:387-389`) | **ไม่แนะนำ** | แชทควร auto-update ไม่ใช่ pull-refresh — ลากดึงข้อความบนแชทเป็น pattern ที่ผิด (ตรงกับที่ task เตือนไว้ว่า chat/detail view ไม่ควรมี) |
| Club detail — แท็บ "เกี่ยวกับ" | เดียวกัน | ข้อมูลนิ่ง (รายละเอียด/สมาชิก/insights) | N/A | **ไม่แนะนำ** | ไม่ใช่ feed ที่มีเนื้อหาใหม่ไหลเข้า |
| **Notifications** (`/notifications`) | `notifications-route.tsx` | List การแจ้งเตือน, pagination แบบปุ่ม "ดูเพิ่มเติม", ไม่มี realtime | ไม่มี | **แนะนำเพิ่ม** | ตรง pattern เป๊ะ — รายการเปลี่ยนเมื่อมีคนอื่น like/comment/follow ผู้ใช้คาดหวังว่าลากแล้วเห็นของใหม่ได้ |
| **Bookmarks** (`/bookmarks`) | `bookmarks-route.tsx` | List การ์ดโพสต์ที่บันทึกไว้, ไม่มี realtime | ไม่มี | **แนะนำเพิ่ม** | ตรง pattern — ถ้าบันทึกโพสต์จากอุปกรณ์/session อื่น หน้านี้ควร pull แล้วเห็นได้ |
| Search results (แท็บ User/โพสต์/Club) | `search-route.tsx` | List ผลลัพธ์ผูกกับ query เดียว | ไม่มี | **ไม่แนะนำ** | ผลค้นหาผูกกับคำค้นที่ผู้ใช้พิมพ์ ไม่ใช่ feed ที่มีเนื้อหาใหม่ไหลเข้าต่อเนื่องแบบ Home — pull-to-refresh ไม่มีความหมายชัดเจนในบริบทนี้ (ตรงกับที่ preliminary findings ตั้งชื่อไว้ว่า "Search results" เป็น candidate แต่ตรวจโค้ดจริงแล้วไม่เข้าเกณฑ์) |
| Chat inbox (`/chat`) | `chat-inbox-parity.tsx` | List การสนทนา | **มี realtime อยู่แล้ว** (`subscribeMyMessages`, `chat-inbox-parity.tsx:155`) | **ไม่แนะนำ** | มี auto-refresh ผ่าน Supabase realtime อยู่แล้ว — เพิ่ม pull-to-refresh จะซ้ำซ้อนไม่มีประโยชน์เพิ่ม |
| Explore Club / Club ของฉัน (`/clubs`) | `clubs-routes.tsx` | List Club แบบ directory, โหลดใหม่ทุกครั้งที่เข้าเพจอยู่แล้ว | ไม่มี realtime แต่ reload ทุก mount | **ไม่แนะนำ** | เป็นหน้า directory/browse ไม่ใช่ feed ส่วนตัวที่อัปเดตต่อเนื่องแบบ Home — และข้อมูลสดใหม่ทุกครั้งที่เข้าเพจอยู่แล้ว |
| Drafts (`/drafts`) | `drafts-route.tsx` | List ร่างของตัวเอง | ไม่มี realtime | **ไม่แนะนำ** | เนื้อหาเปลี่ยนเฉพาะตอนผู้ใช้คนเดียวกันแก้ร่างเอง ไม่มีกรณี "คนอื่นเพิ่มเนื้อหาใหม่" ที่ pull-to-refresh มีไว้แก้ |
| Profile feed (แท็บ สื่อ/รีโพสต์/ถูกใจ, `/profile/[id]`) | `profile-route.tsx` (`ProfileFeed`) | List การ์ดโพสต์, pagination แบบปุ่ม, ไม่มี realtime | ไม่มี | **พบเพิ่มเติมนอกเหนือ 4 รายชื่อที่ preliminary findings ระบุ — เข้าเกณฑ์เดียวกับ Home แต่ scope กว้างกว่าที่ถามไว้เดิม** | รูปแบบเดียวกับ Home/Club posts/Notifications เป๊ะ (การ์ดโพสต์, ไม่มี auto-refresh) — ไม่ใส่ไว้ในคำแนะนำหลักเพราะ task บอกชัดว่า "ไม่ใช่ทุก scroll surface" และ 4 ชื่อที่ระบุไว้ไม่มี Profile — เสนอเป็น**ตัวเลือกเสริมให้ Founder ตัดสินใจแยก** ไม่รวมใน default scope ของรอบแก้นี้ |

---

## สรุป Fix proposal ทั้งหมด (เรียงตามไฟล์)

| # | ไฟล์ | Selector | การเปลี่ยนแปลง | ผลที่มองเห็นได้? |
|---|---|---|---|---|
| 1 | `web/app/globals.css` | `html, body` (rule ใหม่) | เพิ่ม `overscroll-behavior-y: contain;` | เปลี่ยนพฤติกรรม scroll ที่ขอบบน/ล่างสุด (ไม่ใช่ spacing) — **ต้องแจ้ง Founder** |
| 2 | `web/app/profile-golden-final.css:200-212` | `.wyn-profile-tabs` | เพิ่ม `padding-top: env(safe-area-inset-top);` ปรับ `height`/`min-height` เป็น `calc(56px + env(safe-area-inset-top))` | **เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch** — ต้องแจ้ง Founder |
| 3 | `web/app/club-detail-golden.css:31` | `.golden-club-tabs` | เพิ่ม `padding-top: env(safe-area-inset-top);` ปรับ `height` เป็น `calc(54px + env(safe-area-inset-top))` | **เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch** — ต้องแจ้ง Founder |
| 4 | `web/app/parity-final.css:219` | `.drawer-menu-list` | เพิ่ม `padding-bottom: env(safe-area-inset-bottom);` | Defensive ล้วนๆ — ไม่มีผลบนอุปกรณ์ไม่มี home indicator |
| 5 | `web/app/phase3.css:358` | `.route-modal` | เพิ่ม `overscroll-behavior: contain;` | Defensive ล้วนๆ |
| 6 | `web/app/parity-completion.css:44` | `.requests-modal` | เพิ่ม `overscroll-behavior: contain;` | Defensive ล้วนๆ |
| 7 | `web/app/post-detail-parity.css:65` | `.detail-activity-content` | เพิ่ม `overscroll-behavior: contain;` | Defensive ล้วนๆ |
| 8 | `web/app/golden-drop-card.css:32` | `.golden-drop-sheet` | เพิ่ม `overscroll-behavior: contain;` | Defensive ล้วนๆ |
| 9 | `web/app/club-detail-golden.css:117` | `.golden-club-sheet` | เพิ่ม `overscroll-behavior: contain;` | Defensive ล้วนๆ |
| 10 | `web/app/parity-audit.css:5` | `.audit-action-sheet` | เพิ่ม `overscroll-behavior: contain;` | Defensive ล้วนๆ |
| 11 | ไฟล์ hook ใหม่ (เช่น `web/lib/use-pull-to-refresh.ts`) + `notifications-route.tsx`, `bookmarks-route.tsx`, `club-detail-golden.tsx` (เฉพาะแท็บโพสต์) | — | Extract pull-gesture จาก `home-screen.tsx` เป็น hook กลาง แล้วเรียกใช้ใน 3 หน้าที่แนะนำเพิ่ม | **เพิ่มฟีเจอร์ใหม่ที่มองเห็น/สัมผัสได้ (ลากแล้วมี spinner)** — ต้องแจ้ง Founder และต้องผ่าน staged-rollout gate ตาม `DECISIONS.md` (2026-09-06) เนื่องจากเป็น user-facing feature ใหม่ — ดูหมายเหตุด้านล่าง |

**หมายเหตุ staged rollout**: ตาม `.wyn/company/WORKFLOW.md` กติกา "Staged rollout เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่ทุกตัว" (WYN-125) — fix ข้อ 11 (pull-to-refresh บนหน้าจอใหม่) เป็น user-facing feature ใหม่ ต้อง gate ด้วย `isDeveloperAccount()` เป็นค่าเริ่มต้น ส่วน fix ข้อ 1-10 เป็น invisible/defensive fix หรือ bug fix ของพฤติกรรมเดิม (ไม่ใช่ฟีเจอร์ใหม่) เข้าข้อยกเว้น "bug fix ที่แก้ของเดิมให้กลับมาใช้งานได้ปกติ" ไม่ต้อง gate — Founder โปรดยืนยันการตีความนี้ก่อน AI Coding เริ่ม

---

## Final Recommendation

1. **Audit 1 (Safe-area)**: พบ GAP จริง 3 จุด (2 จุดเปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch, 1 จุด defensive) จาก 24 selector ที่ตรวจครบ coverage เดิมจากงานที่ผ่านมา (WYN-158/163/175/176/181) ถือว่ากว้างและถูกต้องเกือบทั้งหมดแล้ว จุดที่ขาดมีเหตุผลชัดเจน (หน้า headerMode="hidden" ที่ไม่ได้พึ่ง shared `.route-header`)
2. **Audit 2 (Overscroll)**: พบ GAP จริง 7 จุด (1 จุดระดับ document/body ที่กระทบทุกหน้า document-scroll ทั้งแอป — **สำคัญที่สุด**, 6 จุดเป็น action sheet/modal reusable ที่กระทบหลายหน้า) จาก 10 scroll container ที่ตรวจครบ
3. **Pull-to-refresh**: แนะนำเพิ่ม 3 จุด (Club posts tab, Notifications, Bookmarks) โดย reuse mechanism เดิมผ่านการ extract เป็น hook กลาง — ไม่ implement ซ้ำ ตรงตาม acceptance criteria พบเพิ่มอีก 1 จุด (Profile feed) ที่เข้าเกณฑ์เดียวกันแต่อยู่นอกรายชื่อเดิมที่ task ระบุ เสนอเป็นตัวเลือกแยกให้ Founder ตัดสินใจ ไม่รวม default
4. พบข้อสังเกตเพิ่มเติม 2 จุด (`.wyn-profile-topbar`, `.flutter-chat-header` cascade regression) ที่เป็นปัญหาประเภทเดียวกับ Audit 1 แต่อยู่นอกนิยาม fixed/sticky ของ task นี้ — รายงานไว้ให้ Founder ตัดสินใจ ไม่รวมใน fix proposal หลัก
5. ไม่มี GAP ไหนกระทบ business logic, Supabase contract หรือฟีเจอร์เดิมที่ใช้งานอยู่ — ทุก fix เป็น CSS เพิ่ม property หรือ hook ใหม่แยกต่างหาก ไม่แตะ logic เดิม ตรงตาม requirement ข้อ 4 ของ task

## Handoff

→ **Founder**: โปรดอนุมัติ/ปรับ 3 ประเด็นที่ต้องตัดสินใจก่อน AI Coding เริ่ม:
   (ก) fix ข้อ 2-3 (safe-area tabs) เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch — อนุมัติหรือไม่
   (ข) fix ข้อ 1 (`overscroll-behavior-y: contain` ที่ html/body) เปลี่ยนพฤติกรรม scroll ที่ขอบจอทั้งแอป — อนุมัติหรือไม่
   (ค) fix ข้อ 11 (pull-to-refresh เพิ่ม 3 หน้า) นับเป็น user-facing feature ใหม่ต้อง gate ด้วย developer account ก่อนหรือไม่ และรวม Profile feed (ตัวเลือกที่ 4) ด้วยหรือไม่
→ **AI Coding** (หลัง Founder อนุมัติ): implement ตาม fix proposal ตารางด้านบนเป๊ะๆ ไม่ขยาย scope เกินนี้ ตรวจ cascade ก่อนแก้ทุกจุดตามวินัยเดิม (แม้ audit นี้ยืนยันแล้วว่าแต่ละ selector ประกาศครั้งเดียว แต่ให้ re-verify ตอนแก้จริงอีกครั้งเผื่อมี branch คู่ขนานแก้ไฟล์เดียวกัน) สำหรับ pull-to-refresh ให้ extract hook จาก `home-screen.tsx` ตามที่อธิบายไว้ในหัวข้อ "กลไก Pull-to-refresh" ห้าม copy โค้ดซ้ำ ยืนยันด้วย Playwright harness ก่อนส่ง QA
→ **AI QA & Security**: นอกจาก regression ปกติ ต้องทดสอบ (1) safe-area บน iPhone จริงที่มี notch/Dynamic Island สำหรับ Profile tabs และ Club tabs (2) **ต้องทดสอบ overscroll-behavior บน Android Chrome จริง** (ไม่ใช่ desktop) ว่า native pull-to-refresh ของ browser ไม่ trigger ซ้อนกับของแอปอีกต่อไป — นี่คือจุดที่ session นี้ยืนยันเองไม่ได้เพราะไม่มี browser tool (3) pull-to-refresh ใหม่ทั้ง 3 หน้า ทำงานถูกต้อง ไม่ชนกับ realtime/pagination ที่มีอยู่เดิม (โดยเฉพาะ Club — ต้องไม่ทำงานตอนอยู่แท็บแชท/เกี่ยวกับ)
