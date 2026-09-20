# WYN-184 — Non-sticky Header Safe-area Audit (รอบ 2)

**Date**: 2026-09-20
**Status**: Pending Founder approval (audit + spec only — ไม่มีโค้ดถูกแก้ในรอบนี้)
**Epic**: WYN-174 (Web Native App Feel รอบ 2) — follow-up หลัง Track 4 (WYN-182)

## หมายเหตุก่อนเริ่ม / ข้อจำกัดของ session นี้

Session นี้มีเครื่องมือ Read/Grep/Glob/Write/Edit เท่านั้น **ไม่มี Bash/browser/Playwright tool** จึงไม่สามารถรัน `next dev` หรือเปิด CDP เพื่อ emulate `safe-area-inset-*` จริงได้ (ต่างจากที่ task ขอให้ "build Playwright harness ถ้ามีเครื่องมือ" — รอบนี้ไม่มี) หลักฐานทั้งหมดด้านล่างมาจาก **อ่าน source + ไล่ cascade ด้วย grep ทั้ง repo จริง** ไม่มีจุดไหนสรุปจากการเดา แต่ **ยังไม่มีการยืนยัน computed style บนอุปกรณ์/เบราว์เซอร์จริง** — ต้องให้ QA ยืนยันซ้ำบน iPhone ที่มี notch/Dynamic Island ก่อนปิด task เหมือนข้อจำกัดเดียวกับที่ WYN-182 เจอ

หมายเหตุเพิ่มเติม: จาก `.wyn/company/DECISIONS.md` (entry 2026-09-20) ยืนยันว่า **WYN-182 implement เสร็จ, QA PASS, deploy ขึ้น production แล้วจริง** ไม่ใช่แค่ audit ค้างอยู่ — ตรวจสอบแล้วว่า fix ของ WYN-182 (เช่น `.golden-club-tabs` มี `padding-top: env(safe-area-inset-top)` จริงที่ `club-detail-golden.css:31` ในปัจจุบัน) ถูก apply แล้วจริงในโค้ดปัจจุบัน — คำว่า "trust WYN-182" ในรายงานนี้จึงหมายถึง trust สถานะปัจจุบันของ codebase ไม่ใช่แค่ proposal เก่า

---

## Route enumeration — ยืนยันซ้ำ (ไม่ใช่แค่เชื่อ WYN-182)

Grep `headerMode="hidden"` ทั้ง repo (`web/`) เจอ 9 จุดจริง ตรงกับลิสต์ที่ WYN-182 ระบุไว้ทุกตัว ไม่มากไม่น้อยกว่า:

| # | Route (URL) | Component | `headerMode="hidden"` ที่ |
|---|---|---|---|
| 1 | `/` (Home) | `web/components/home/home-screen.tsx` | บรรทัด 818 |
| 2 | `/profile/[id]`, `/profile/me` (redirect ไป `/profile/[id]`) | `web/components/profile-route.tsx` (ผ่าน `profile-parity-route.tsx`) | บรรทัด 300 |
| 3 | `/notifications` | `web/components/notifications-route.tsx` | บรรทัด 196 |
| 4 | `/search` | `web/components/search-route.tsx` | บรรทัด 307 |
| 5 | `/chat` (Chat inbox) | `web/components/chat-inbox-parity.tsx` | บรรทัด 238 |
| 6 | `/chat/[id]` (Chat conversation) | `web/components/chat-routes.tsx` | บรรทัด 334 |
| 7 | `/club/[id]` (Club detail) | `web/components/club-detail-golden.tsx` | บรรทัด 564, 565, 601 |
| 8 | `/drop/[id]` (Post detail) | `web/components/post-detail-route.tsx` | บรรทัด 375 |
| 9 | `/profile/[id]/followers`, `/profile/[id]/following` (Profile follow list) | `web/components/profile-follow-list-route.tsx` | บรรทัด 73 |

ยืนยันเพิ่มว่า `AppChrome` (`web/components/phase3-ui.tsx:91-93`) **ไม่ render `.route-header` เลย** เมื่อ `headerMode === "hidden"` (`{headerMode !== "hidden" ? <header className="route-header ...">...</header> : null}`) และ grep หา class `route-app-header-hidden`/`header-hidden` ทั้ง repo **ไม่พบ CSS rule ใดๆ เลยที่ target class นี้** — ยืนยันว่าไม่มี safe-area ชดเชยที่ระดับ shared chrome สำหรับ 9 route นี้เลยแม้แต่จุดเดียว ทุกหน้าต้องพึ่ง header ที่ตัวเองสร้างขึ้นมาเอง 100%

---

## Audit: หา header จริงของแต่ละ route แล้วจำแนก static vs sticky/fixed

สำหรับแต่ละ route ด้านล่าง ตรวจ (ก) markup จริงว่า header element แรกที่เจอคืออะไร (ข) CSS `position` ของมัน (ค) ถ้าเป็น sticky/fixed ให้ cite WYN-182 (เพราะ session นั้นตรวจ + WYN-182 deploy แล้วจริง) (ง) ถ้าเป็น static-in-flow ให้ตรวจ safe-area + cascade เองใหม่ทั้งหมด (จุดที่ WYN-182 ไม่ครอบคลุม — นี่คือ scope จริงของ WYN-184)

| Route | Header selector (จริง ตาม markup) | File:line | Static หรือ Sticky/Fixed | มี safe-area-inset-top ครอบคลุมจริงไหม | Verdict |
|---|---|---|---|---|---|
| Home (`/`) | `.wyn-home-header` (ลูกของ `.wyn-home`) | `web/components/home/home-header.tsx:21` / CSS: `web/app/home.css:22` | **Static-in-flow** (ตัวมันเอง) แต่ parent `.wyn-home` เป็น `sticky; top:0` | ใช่ — ผ่าน parent `.wyn-home` (`padding-top: min(env(safe-area-inset-top),20px)`, `home.css:11-18`, ประกาศครั้งเดียวในทั้ง repo) | **OK** (เหมือน pattern `.route-modal-backdrop`→`.route-modal` ที่ WYN-182 ใช้ — parent รับ inset แทนลูก) |
| Profile (`/profile/[id]`, `/profile/me`) | `.wyn-profile-topbar` | `web/app/profile-golden-final.css:10-18` / render: `web/components/profile-route.tsx:301` | **Static-in-flow** (ไม่มี `position` เลยในทั้ง block → default `static`) | **ไม่มี** — `padding: 0 4px;` ไม่มี top เลย | **GAP** |
| Notifications (`/notifications`) | `.notification-root-header` | `web/app/parity-completion.css:47` | Sticky top:0 | ใช่ (cascade-confirmed แล้วโดย WYN-182 — ตัวที่ชนะจริงคือ `notifications-clean.css:2-10`) | OK — **trust WYN-182 (sticky, นอก scope WYN-184)** |
| Search (`/search`) | `.flutter-search-header` | `web/app/parity-completion.css:7` | Sticky top:0 | ใช่ (cascade-confirmed โดย WYN-182) | OK — **trust WYN-182 (sticky, นอก scope WYN-184)** |
| Chat inbox (`/chat`) | `.flutter-chat-header` | ดูหัวข้อ cascade ด้านล่าง (ประกาศใน 5 ไฟล์) / render: `web/components/chat-inbox-parity.tsx:240` | **Static-in-flow** (ไม่มี `position` ในทุก 5 block ที่ประกาศ selector นี้ → default `static`) | **ไม่จริง** — มีคนพยายามใส่ไว้ (`pixel-parity-audit-closure.css:9-11`) แต่ถูกทับด้วย rule specificity สูงกว่า+`!important` ที่ไม่มี safe-area | **GAP (cascade regression)** |
| Chat conversation (`/chat/[id]`) | `.conversation-modern-header` | `web/app/conversation-modern.css:9` | Sticky top:0 | ใช่ (WYN-182 ยืนยัน) | OK — **trust WYN-182 (sticky, นอก scope WYN-184)** |
| Club detail (`/club/[id]`) | `.golden-club-banner` (คอนเทนเนอร์) + `.golden-club-back` (ปุ่มย้อนกลับ ซึ่งเป็น interactive element เดียวที่ชิดขอบบนจริง) | `web/app/club-detail-golden.css:10` (banner), `:13` (back button) | **Static-in-flow** ทั้งคู่ (`.golden-club-banner` เป็น `position: relative` เฉยๆ ไม่ sticky/fixed, `.golden-club-back` เป็น `position: absolute` เทียบกับ banner) | ใช่ — `.golden-club-back { top: calc(env(safe-area-inset-top) + 8px); ... }` | **OK** |
| Post detail (`/drop/[id]`) | `.detail-floating-header` | `web/app/system-parity-final.css:158` | Sticky top:0 | ใช่ (WYN-182 ยืนยัน) | OK — **trust WYN-182 (sticky, นอก scope WYN-184)** |
| Profile follow list (`/profile/[id]/followers`, `/profile/[id]/following`) | `.wyn-profile-topbar` (**เดียวกับ Profile เป๊ะ** — reuse selector เดียวกัน) | `web/app/profile-golden-final.css:10-18` / render: `web/components/profile-follow-list-route.tsx:74` | **Static-in-flow** | **ไม่มี** (rule เดียวกับ GAP ข้างบน) | **GAP** |

**สรุป**: จาก 9 route มี header จริงที่เป็น static-in-flow 4 กรณี (Home, Profile, Chat inbox, Club detail — Profile follow list ใช้ selector เดียวกับ Profile) ตรวจแล้ว **2 กรณีเป็น GAP จริง** (Profile/Profile follow list ผ่าน `.wyn-profile-topbar`, Chat inbox ผ่าน `.flutter-chat-header`) อีก 2 กรณี (Home, Club detail) **OK** เพราะมี parent/sibling element ที่รับ safe-area แทนอยู่แล้ว ส่วนอีก 4 route (Notifications, Search, Chat conversation, Post detail) header จริงเป็น sticky อยู่แล้ว ซึ่งอยู่นอก scope ของ WYN-184 ตามที่ task ระบุไว้ชัดเจน (WYN-182 ตรวจ+ยืนยัน+deploy แล้ว)

---

## GAP 1 — `.wyn-profile-topbar` (Profile + Profile follow list)

**ไฟล์**: `web/app/profile-golden-final.css:10-18`
**ใช้ใน**: `/profile/[id]`, `/profile/me` (`web/components/profile-route.tsx:300-311`) และ `/profile/[id]/followers`, `/profile/[id]/following` (`web/components/profile-follow-list-route.tsx:73-78`) — **รวม 4 route path ที่กระทบจริง** ไม่ใช่แค่ 2 อย่างที่ known finding เดิมระบุไว้ (known finding พูดถึงแค่ `/profile/[id]`, `/profile/me` — Profile follow list ใช้ selector เดียวกันซ้ำ ยังไม่เคยถูกเอ่ยถึงมาก่อน)

**หลักฐาน CSS ปัจจุบัน**:
```css
.wyn-profile-topbar {
  height: 52px;
  padding: 0 4px;
  display: grid;
  grid-template-columns: 48px minmax(0, 1fr) 48px;
  align-items: center;
  border-bottom: 0;
  background: var(--wyn-bg);
}
```
ไม่มี `position` (default `static`) ไม่มี `padding-top`/`env(safe-area-inset-top)` เลยแม้แต่จุดเดียวในทั้ง 4 block ของ selector นี้ (`:10`, `:20`, `:31`, `:41`)

**Cascade check**: grep `wyn-profile-topbar` ทั้ง `web/` เจอ **เฉพาะไฟล์เดียว** (`profile-golden-final.css`) — ไม่มีไฟล์อื่นแก้ทับ ไม่มี cascade risk ไม่มีใครเคยพยายามแก้จุดนี้มาก่อนเลย (ต่างจาก GAP 2 ที่เคยมีคนพยายามแก้แต่โดนทับ)

**ผลกระทบจริง**: ปุ่มย้อนกลับ/username/ปุ่มตั้งค่า (หรือ "ผู้ติดตาม"/"กำลังติดตาม" ในกรณี follow list) เรนเดอร์ชิดขอบบนสุดจริงของจอทันทีที่โหลดหน้า (ไม่ต้อง scroll) — บนอุปกรณ์ notch/Dynamic Island จะซ้อนใต้ status bar/กล้องหน้าเลย

**Fix ที่เสนอ** (แก้ที่เดียว ใช้ผลกับทั้ง 4 route path เพราะ reuse selector เดียวกัน):
```css
.wyn-profile-topbar {
  height: calc(52px + env(safe-area-inset-top));
  padding: env(safe-area-inset-top) 4px 0;
  display: grid;
  grid-template-columns: 48px minmax(0, 1fr) 48px;
  align-items: center;
  border-bottom: 0;
  background: var(--wyn-bg);
}
```
รูปแบบเดียวกับ `.wyn-profile-tabs` ที่ WYN-182 แก้ไปแล้ว (`height: calc(56px + env(safe-area-inset-top))`) — ใช้ pattern เดิมของโค้ดเบส ไม่ใช่ pattern ใหม่

**ผลที่มองเห็นได้**: **เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch/Dynamic Island** (header ขยับลงจากตำแหน่งเดิมเท่ากับความสูง safe-area-inset-top, ~44–59px) อุปกรณ์ไม่มี notch (`env()=0`) **ไม่เห็นความต่าง** — เหมือนกับ GAP 1/GAP 2 ของ WYN-182 ที่ deploy ไปแล้วเป๊ะ

---

## GAP 2 — `.flutter-chat-header` (Chat inbox, `/chat`) — cascade regression ยืนยันซ้ำด้วยหลักฐานเต็ม (กว้างกว่าที่ known finding ระบุ)

**Known finding เดิม** ระบุว่ามีแค่ 2 ไฟล์เกี่ยวข้อง (`pixel-parity-audit-closure.css` vs `chat-notes.css` บรรทัด 11/537) — **ตรวจซ้ำพบว่าจริงๆ มี 5 ไฟล์ที่ประกาศ selector `.flutter-chat-header` (หรือ scoped เป็น `.wyn-chat-inbox .flutter-chat-header`)**:

| # | ไฟล์:บรรทัด | Selector | Specificity | `!important`? | Import order (`layout.tsx`) | padding-top ที่ประกาศ |
|---|---|---|---|---|---|---|
| A | `system-parity-lock.css:209-217` | `.flutter-chat-header` | (0,1,0) | ไม่ | บรรทัด 25 | `0` (จาก `padding: 0 12px 0 4px`) |
| B | `pixel-parity-audit-closure.css:9-13` | `.flutter-chat-header` | (0,1,0) | ไม่ | บรรทัด 29 | `env(safe-area-inset-top)` ✅ (คนเคยพยายามแก้) |
| C | `notifications-clean.css:206-213` | `.flutter-chat-header` | (0,1,0) | **ใช่** | บรรทัด 40 | `8px` (จาก `padding: 8px 32px 0 24px !important`) |
| D | `chat-notes.css:11-16` | `.wyn-chat-inbox .flutter-chat-header` | **(0,2,0)** | **ใช่** | บรรทัด 41 | `8px` |
| E | `chat-notes.css:537-542` | `.wyn-chat-inbox .flutter-chat-header` | **(0,2,0)** | **ใช่** | บรรทัด 41 (บรรทัดหลัง D ในไฟล์เดียวกัน) | `6px` ← **ตัวที่ชนะจริง** |

**เหตุผลที่ E ชนะ**:
1. CSS cascade ให้ `!important` ทั้งหมดชนะ non-`!important` ก่อนเสมอ (ไม่สนใจ specificity/order ข้ามชั้นนี้) → ตัดตัวเลือก A, B ออกทันที (ไม่มี `!important`)
2. ในกลุ่ม `!important` ที่เหลือ (C, D, E) — D และ E มี specificity สูงกว่า C (2 class vs 1 class) → C ถูกตัดออก
3. เหลือ D กับ E ซึ่ง specificity เท่ากัน (0,2,0) ทั้งคู่อยู่ใน**ไฟล์เดียวกัน** (`chat-notes.css`) — กติกา CSS cascade คือ "ประกาศทีหลังชนะ" เมื่อ specificity/importance เท่ากัน E อยู่ที่บรรทัด 537 ซึ่งมาหลัง D ที่บรรทัด 11 ในไฟล์เดียวกัน → **E ชนะ**

**ผลลัพธ์จริงที่เรนเดอร์**: `padding: 6px 18px 0 14px !important;` (จาก E) → `padding-top: 6px` คงที่ **ไม่มี `env(safe-area-inset-top)` เลย** — ตรงกับ known finding แต่ตอนนี้มีหลักฐานครบ 5 ไฟล์ ไม่ใช่แค่ 2

หมายเหตุ: มี media query เสริมอีก 2 จุด (`chat-notes.css:497-500` และ `:744-747`, ทั้งคู่ `@media (max-width:430px)`) แต่ทั้งสองแก้แค่ `padding-left`/`padding-right` (longhand แยก) ไม่แตะ `padding-top` เลย จึงไม่เปลี่ยนผลสรุปข้างต้น

**ผลกระทบจริง**: header "ข้อความ" (ปุ่มย้อนกลับ/หัวข้อ/ปุ่มคำขอ) ของ Chat inbox เรนเดอร์ชิดขอบบนสุดจริงตั้งแต่โหลดหน้าครั้งแรก แม้จะมีคนพยายามแก้ไว้แล้วที่ B

**Fix ที่เสนอ** (ต้องแก้ที่ **rule E** เท่านั้น เพราะเป็นตัวที่ชนะจริง แก้ที่ B อย่างเดียวจะไม่มีผลอะไรเลยเหมือนที่เป็นอยู่ตอนนี้):
```css
/* web/app/chat-notes.css:537-542 */
.wyn-chat-inbox .flutter-chat-header {
  height: calc(68px + env(safe-area-inset-top)) !important;
  padding: calc(env(safe-area-inset-top) + 6px) 18px 0 14px !important;
  grid-template-columns: 40px minmax(0, 1fr) auto !important;
  align-items: center !important;
}
```
(คง `!important` ไว้ทุกตัวเหมือนเดิม เพราะยังต้องชนะ rule C/D ที่ไม่เกี่ยวกับ fix นี้ — ไม่แตะ specificity/importance ของระบบเดิม)

**ทางเลือกเสริม (ไม่บังคับ)**: rule B (`pixel-parity-audit-closure.css:9-11`) ตอนนี้เป็น dead code ที่ไม่มีผลอะไรเลย (โดน E ทับอยู่ตลอด) — จะลบ/comment ทิ้งเพื่อลดความสับสนของคนแก้ในอนาคตก็ได้ แต่ไม่จำเป็นต่อการแก้บั๊กนี้ (functional fix อยู่ที่ rule E เท่านั้น) เสนอเป็นตัวเลือกให้ Founder/AI Coding ตัดสินใจเอง ไม่ใช่ required scope

**ผลที่มองเห็นได้**: **เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch/Dynamic Island** — header จะขยับลงจากตำแหน่งปัจจุบัน (currently ล้ำเข้าไปใต้ status bar/notch อยู่) มาอยู่ใต้ notch แทน อุปกรณ์ไม่มี notch ไม่เห็นความต่าง — เหมือนกับ GAP อื่นๆ ในชุดนี้ ไม่ใช่ defensive fix แต่เป็นการแก้บั๊กที่เห็นผลจริงบนอุปกรณ์เป้าหมาย

---

## จุดที่ตรวจแล้วยืนยันว่า OK (ไม่ใช่ GAP) — Home, Club detail

**Home (`/`)**: header จริง `.wyn-home-header` (`web/components/home/home-header.tsx:21`, CSS ที่ `web/app/home.css:22-28`) เป็น static-in-flow เอง ไม่มี safe-area ของตัวเอง — แต่ parent ที่ wrap มันโดยตรงคือ `.wyn-home` (`web/app/home.css:11-18`) เป็น `position: sticky; top: 0; padding-top: min(env(safe-area-inset-top), 20px);` grep ยืนยันว่า `.wyn-home` ประกาศ**ครั้งเดียว**ในทั้ง repo ไม่มี cascade risk — inset ถูกใส่ที่ parent แล้วไหลลงมาครอบคลุม header ลูกโดยอัตโนมัติ (เหมือน pattern `.route-modal-backdrop`→`.route-modal` ที่ WYN-182 ใช้เป็นบรรทัดฐานไว้แล้ว) **ไม่ใช่ GAP**

**Club detail (`/club/[id]`)**: header จริงคือ banner (`.golden-club-header`/`.golden-club-banner`, `web/app/club-detail-golden.css:9-10`) เป็น static-in-flow (`position: relative` เฉยๆ) แต่องค์ประกอบ interactive เดียวที่ชิดขอบบนจริงคือปุ่มย้อนกลับ `.golden-club-back` ซึ่งเป็น `position: absolute; top: calc(env(safe-area-inset-top) + 8px);` (`club-detail-golden.css:13`) grep ยืนยันว่า selector นี้ประกาศเพียงครั้งเดียวสำหรับ `top`/`position` (บรรทัดอื่นที่ซ้ำ คือ `:133`, `:152`, `:172` แก้แค่ `transform`/`transition` สำหรับ press-feedback ไม่แตะ `top`/`padding`) — inset ถูกต้องและไม่มีอะไรทับ **ไม่ใช่ GAP** (ชื่อ Club/แบนเนอร์รูปภาพเองไม่ได้ชิดขอบในเชิง interactive content เป็นการออกแบบตั้งใจแบบเดียวกับ cover photo ของแอปโซเชียลทั่วไป)

---

## สรุป Fix proposal ทั้งหมด

| # | ไฟล์ | Selector | การเปลี่ยนแปลง | ผลที่มองเห็นได้? |
|---|---|---|---|---|
| 1 | `web/app/profile-golden-final.css:10-18` | `.wyn-profile-topbar` | เพิ่ม `padding-top: env(safe-area-inset-top)` (ในรูป `padding: env(safe-area-inset-top) 4px 0;`) ปรับ `height` เป็น `calc(52px + env(safe-area-inset-top))` | **เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch** (กระทบ Profile + Profile follow list รวม 4 route path) — ต้องแจ้ง Founder |
| 2 | `web/app/chat-notes.css:537-542` | `.wyn-chat-inbox .flutter-chat-header` (rule ที่ชนะจริงในปัจจุบัน) | เปลี่ยน `padding-top` คงที่ 6px เป็น `calc(env(safe-area-inset-top) + 6px)` และ `height` เป็น `calc(68px + env(safe-area-inset-top))` (คง `!important` ทุกตัวไว้เหมือนเดิม) | **เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch** — ต้องแจ้ง Founder |

ไม่มี fix ไหนในรอบนี้เป็น "defensive ล้วนๆ" — ทั้ง 2 จุดเป็นบั๊กจริงที่ยืนยันแล้วว่าเนื้อหาเรนเดอร์ใต้ notch/status bar ตั้งแต่โหลดหน้าครั้งแรก (ต่างจาก WYN-182 ที่มี 3 จุด defensive ปนอยู่)

ไม่มี fix ไหนแตะ business logic หรือ Supabase contract — เป็นการเพิ่ม CSS property ล้วนๆ ในสอง rule ที่มีอยู่แล้ว ไม่มีการสร้าง selector ใหม่ ไม่มี JS/component เปลี่ยนแปลง

---

## Final Recommendation

1. ยืนยัน route enumeration ของ WYN-182 ถูกต้องครบถ้วน (9 route ที่ใช้ `headerMode="hidden"`) — grep ซ้ำแล้วตรงกันทุกตัว
2. ตรวจ header จริงของทั้ง 9 route ครบ ไม่ sample — พบ static-in-flow header จริง 4 กรณี (Home, Profile, Chat inbox, Club detail) ส่วนอีก 5 route path (Notifications, Search, Chat conversation, Post detail, และ Profile follow list ที่ reuse selector เดียวกับ Profile) header จริงเป็น sticky (นอก scope, trust WYN-182 ซึ่ง deploy แล้วจริง) หรือ reuse GAP เดิม
3. พบ GAP จริง **2 จุด CSS** (กระทบ 5 route path เพราะ Profile topbar reuse กันระหว่าง Profile + Profile follow list): `.wyn-profile-topbar` (ไม่เคยมีใครแก้มาก่อน) และ `.flutter-chat-header` (cascade regression ที่มีคนพยายามแก้แล้วแต่โดนทับ — ยืนยันด้วยหลักฐาน 5 ไฟล์ ไม่ใช่ 2 ไฟล์แบบที่ known finding เดิมระบุไว้)
4. พบ 2 จุดที่ดูเหมือนจะเป็น GAP แต่ตรวจแล้ว **ไม่ใช่** (Home, Club detail) เพราะมี parent/sibling element ที่รับ inset แทนอยู่แล้วตามสถาปัตยกรรมเดิมของโค้ดเบส — บันทึกไว้เป็นหลักฐานว่าตรวจแล้วจริง ไม่ใช่ข้ามไปเฉยๆ
5. **ข้อจำกัดสำคัญ**: รายงานนี้มาจากการอ่าน source + cascade evidence 100% — ยังไม่มีการยืนยัน computed style บนอุปกรณ์จริง (session ไม่มี Bash/browser tool) ต้องให้ QA ยืนยันซ้ำบน iPhone ที่มี notch/Dynamic Island จริงก่อนปิด task

## Handoff

→ **Founder**: โปรดอนุมัติ/ปรับ fix ทั้ง 2 จุดข้างบน (ทั้งคู่เปลี่ยน spacing ที่มองเห็นได้บนอุปกรณ์มี notch — เหมือน precedent ที่ WYN-182 เคยขออนุมัติและ deploy ไปแล้ว)
→ **AI Coding** (หลัง Founder อนุมัติ): แก้เฉพาะ 2 จุดตามตารางด้านบนเป๊ะๆ **สำคัญมาก**: fix #2 ต้องแก้ที่ `chat-notes.css:537-542` (rule ที่ชนะจริง) ไม่ใช่ `pixel-parity-audit-closure.css:9-11` (rule ที่แพ้อยู่แล้ว ถ้าแก้ผิดจุดจะไม่มีผลอะไรเลยเหมือนสถานะปัจจุบัน) — re-verify cascade อีกครั้งตอนแก้จริงเผื่อมี branch คู่ขนานแตะไฟล์เดียวกัน ยืนยันด้วย build/typecheck/lint ก่อนส่ง QA
→ **AI QA & Security**: ทดสอบ safe-area บน iPhone จริงที่มี notch/Dynamic Island สำหรับทั้ง 2 จุด (Profile topbar ทั้งใน Profile และ Profile follow list, Chat inbox header) โดยเฉพาะยืนยันว่า header ไม่ชิดขอบบนอีกต่อไป และไม่กระทบ layout ของ tabs/content ที่อยู่ใต้ header เหล่านี้ (`.wyn-profile-tabs`, chat search bar) ซึ่งแก้ไปแล้วใน WYN-182
