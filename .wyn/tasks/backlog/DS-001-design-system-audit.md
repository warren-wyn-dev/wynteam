# Product Task — DS-001

Status: backlog (PHASE 1 AUDIT เสร็จ + DESIGN SPEC เสร็จ — รอ Founder เลือก palette A/B/C ก่อนส่งต่อ AI Coding)
Owner: AI Product Manager → AI Design (design spec เสร็จแล้ว ดูหัวข้อ "Design Output" ท้ายไฟล์)

Feature: WYN Design System Refinement — Phase 1 Audit + Token Foundation

Goal: ปรับ UI/UX ของ WYN ให้เป็น Minimal Social Platform ระดับ production (Black + White + Cyan) และแยก identity ของ ZOKY เป็น commerce layer (Black + White + Orange) โดยไม่ rebuild ไม่ลบฟีเจอร์ และไม่ทำลายระบบที่ผ่าน QA แล้ว

Target User: ผู้ใช้ WYN ทุกกลุ่ม (Gen Z) — งานนี้ไม่เพิ่มฟีเจอร์ใหม่ แต่ยกระดับคุณภาพการรับรู้ (perceived quality) ของทุกหน้าจอที่มีอยู่

Problem: ปัจจุบัน WYN ใช้ Material 3 default theme ผ่าน `colorSchemeSeed: 0xFF2D6CDF` เพียงบรรทัดเดียว ไม่มี design token กลาง ไม่มีการแยก identity ระหว่าง Social กับ Commerce และหน้าตายังเป็น "Material default" มากกว่าจะเป็น brand ของตัวเอง

---

## PHASE 1 — AUDIT (เสร็จแล้ว)

### 1. Tech Stack จริง (ต่างจากที่ brief สันนิษฐาน)

| หัวข้อ | ความจริง |
|---|---|
| Framework | **Flutter / Dart** (ไม่ใช่ React/Next.js) |
| แอป | 2 แอปแยก: `app/` (Customer) + `seller_app/` (Seller) |
| Backend | Supabase (Postgres + Auth + Storage + RLS + RPC) |
| State management | **ไม่มี library** — ใช้ `StatefulWidget` + `setState` + constructor injection ล้วน |
| Routing | `Navigator.push` + `MaterialPageRoute` (ไม่มี declarative router) |
| Styling | Material 3 `ThemeData` + `colorSchemeSeed` เดียว |
| Type safety | Dart sound null safety (**ไม่มี TypeScript** — ข้อกำหนด "Keep TypeScript types safe" ใน brief ไม่ applicable) |

### 2. ฟีเจอร์ที่มีอยู่จริงและทำงานได้ (ต้องรักษาไว้ทั้งหมด)

**`app/` — 33 screens, 42 widgets, 265 tests ผ่าน**

| ระบบ | สถานะ | หมายเหตุ |
|---|---|---|
| Auth | ผ่าน QA | Google/Apple OAuth + Phone OTP, `AuthGate` |
| Home Feed | ผ่าน QA | For You / From Your Clubs toggle |
| Drop (รูปภาพ) | ผ่าน QA | upload/like/comment/share/save/delete |
| Pop (คลิปสั้น) | ผ่าน QA | **ถูกระงับการพัฒนา** (DECISIONS.md 2026-08-14) |
| Club | ผ่าน QA | สร้าง/เข้าร่วม/โพสต์/discovery/admin controls |
| Profile | ผ่าน QA | avatar/bio/followers/following/grid |
| Follow | ผ่าน QA | |
| Search | ผ่าน QA | Users/Clubs/Drops/Pops + ZOKY แยก |
| Notification | ผ่าน QA | 9 types รวม club events |
| Saved (Bookmark) | ผ่าน QA | มีอยู่แล้วจริง |
| ZOKY Marketplace | ผ่าน QA | browse/search/cart/checkout/order/review |

**`seller_app/` — 12 screens, 67 tests ผ่าน**
Dashboard / Product Management / Order Management (8 สถานะ) / Store Management / Finance (placeholder)

### 3. ประเด็นที่ brief สันนิษฐานไม่ตรงกับความจริง (สำคัญมาก)

1. **Chat ไม่มีอยู่ในระบบเลย** — brief มีทั้ง section เรื่อง Chat (1-to-1, read status, online status, block, report) แต่ค้นทั้ง codebase แล้วพบคำว่า "chat" แค่ใน comment เดียวที่ `store_screen.dart` ที่ระบุว่า "Chat Seller ถูก defer ไว้" → **ไม่มีอะไรให้ "รักษาฟังก์ชันเดิม" ถ้าจะมี Chat ต้องสร้างใหม่ทั้งหมด = เป็นฟีเจอร์ใหม่ ไม่ใช่งาน design refinement**

2. **ระบบ Payment/Order/Cart มีอยู่แล้วและผ่าน QA แล้ว** — brief เขียนว่า "ห้ามสร้างระบบ payment/delivery/order ใหม่ ถ้ายังไม่มีอยู่แล้ว" แต่ความจริง ZOKY-003 (Cart/Checkout/Order) และ SELLER-003 (8-state order lifecycle + 5 RPC) สร้างเสร็จและผ่าน QA แล้ว → **ตีความว่า "ไม่ต้องสร้างเพิ่ม" ไม่ใช่ "ต้องถอดออก"**

3. **Image compression ทำครบแล้วทุกจุด** — brief สั่งให้ implement แต่ตรวจแล้วพบว่า `pickImage`/`pickMultiImage` **ทุกจุดในทั้ง 2 แอป** (9 จุด) มี `maxWidth`/`maxHeight`/`imageQuality: 85` ครบแล้ว และไม่มี base64 ใน DB เลย — ทุกภาพขึ้น Supabase Storage แล้วเก็บแค่ URL (buckets: `avatars`, `drop-images`, `club-media`, `pop-videos`, `product-images`, `store-media`) → **หัวข้อนี้ compliant อยู่แล้ว เหลือแค่ verify ไม่ต้อง implement**

4. **`imageQuality: 85` เป็น fixed quality ไม่ใช่ adaptive** — brief ขอ "adaptive compression ตามภาพ" ซึ่งของเดิมยังไม่ใช่ แต่ `image_picker` ไม่รองรับ adaptive โดยตรง ต้องเพิ่ม dependency ใหม่ (เช่น `flutter_image_compress`) → **เป็นงานเสริมที่ควรแยก task และประเมิน cost/benefit ก่อน ไม่ใช่ blocker ของ design system**

### 4. ไฟล์ที่เกี่ยวข้องกับ UI (จุดที่งานนี้จะแตะ)

- `app/lib/main.dart` + `seller_app/lib/main.dart` — theme setup (จุดเดียวที่นิยามสี ปัจจุบัน duplicate กัน)
- `app/lib/features/*/presentation/**` — 33 screens + 42 widgets
- `seller_app/lib/features/*/presentation/**` — 12 screens
- **ไม่มี design token file กลาง** — นี่คือช่องว่างหลักที่ DS-001 ต้องปิด

### 5. ไฟล์ที่เกี่ยวกับ backend (ห้ามแตะในงาน design)

- `supabase/schema.sql` (2,800+ บรรทัด — tables/RLS/RPC/triggers/storage)
- `app/lib/features/*/data/**` + `seller_app/lib/features/*/data/**` (repositories + models)
- `app/lib/core/env.dart` (Supabase config)

### 6. สิ่งที่ทำได้ดีอยู่แล้ว (ห้ามเขียนใหม่)

- **Accessibility พื้นฐานดีเกินคาด**: `Semantics` 62 จุด, `tooltip` 33 จุด, `SafeArea` 28 จุด
- **สีไม่ hardcode**: มี `Color(0x...)` แค่ 8 จุดในทั้ง app (ส่วนใหญ่เป็น overlay บน grid tile) ที่เหลือใช้ `Theme.of(context).colorScheme` ทั้งหมด → **การเปลี่ยน seed color จะไหลไปทุกหน้าจอโดยอัตโนมัติ = ต้นทุนต่ำกว่าที่คิดมาก**
- **Test coverage แข็งแรง**: 332 tests (265 + 67) ผ่านหมด — เป็นตาข่ายกันพลาดที่ดีมากสำหรับงานที่มี blast radius กว้าง

### 7. สิ่งที่ควรปรับ (ช่องว่างจริงที่ audit พบ)

| ประเด็น | หลักฐาน | ผลกระทบ |
|---|---|---|
| ไม่มี design token กลาง | seed color duplicate ใน 2 `main.dart` | เปลี่ยนสีต้องแก้ 2 ที่ เสี่ยงหลุด |
| Typography ไม่ได้นิยาม | ไม่มี `textTheme` custom เลย — ใช้ Material default ล้วน | hierarchy ไม่ใช่ของ WYN |
| Spacing ไม่มีระบบ | ค่า padding กระจายเป็น literal ทั่วโค้ด | ไม่สม่ำเสมอ |
| Responsive อ่อน | `MediaQuery` แค่ 2 จุด, `LayoutBuilder` **0 จุด** | tablet/desktop ยังไม่ได้ออกแบบจริง |
| ZOKY ไม่มี identity แยก | ใช้สีเดียวกับ Social ทั้งหมด | commerce ไม่โดดเด่น |
| Known issue ค้าง | `StoreScreen` overflow ~288px บนจอเล็ก (SELLER-004) | ต้องแก้ในงานนี้ |

### 8. ความเสี่ยง

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เปลี่ยน seed color กระทบ **ทุกหน้าจอทั้ง 45 หน้า** — blast radius กว้างที่สุดเท่าที่เคยทำในโปรเจกต์นี้ | **สูง** | ทำ token layer ก่อน + รัน 332 tests ทุกขั้น + แบ่ง task ย่อย ไม่ทำรวดเดียว |
| R2 | Test ที่ assert สีอาจพัง | กลาง | grep หา color assertion ก่อนเริ่ม |
| R3 | Pop ถูกระงับ แต่เป็นส่วนหนึ่งของ design system | กลาง | Pop ได้รับ token ใหม่แบบ passive (ผ่าน theme) เท่านั้น **ห้ามแก้ไฟล์ Pop โดยตรง** |
| R4 | Contrast ของ Cyan `#00C8FF` บนพื้นขาวต่ำ (ratio ~1.9:1) | **สูง** | ห้ามใช้เป็นสีข้อความบนพื้นขาว ต้องมี shade เข้มสำหรับ text/ปุ่ม — ต้องให้ AI Design กำหนด scale ก่อน |
| R5 | งานนี้ทับซ้อนกับ SELLER-005 (Finance) ที่ยังไม่ทำ | ต่ำ | ทำ design system ให้จบก่อน แล้ว SELLER-005 จะได้ใช้ token ใหม่ตั้งแต่ต้น |

---

## คำถามที่ต้องให้ Founder ตัดสินใจก่อนเข้า Phase 2

### Q1. ยืนยันเปลี่ยน Color Direction หรือไม่
`.wyn/company/DECISIONS.md` (2026-08-14) บันทึกไว้ว่า **"Color Direction: Blue + White + Soft Gray"** เป็นกติกาตายตัวจาก Founder และทั้งโปรเจกต์สร้างมาบนสีน้ำเงิน `#2D6CDF`
brief ใหม่กำหนด **Cyan `#00C8FF`** → เป็นการ **แทนที่คำตัดสินใจเดิม** ต้องยืนยันชัดเจนเพื่อบันทึกเป็น decision ใหม่ที่ supersede ของเดิม

### Q2. Chat — จะเอาอย่างไร
ไม่มีอยู่จริงในระบบ ถ้าต้องการต้องสร้างใหม่ทั้งหมด (DB schema + realtime + RLS + UI) = งานใหญ่ระดับ WYN-014 ไม่ใช่งาน design refinement

### Q3. ขอบเขตรอบนี้
ทำ design system ให้จบก่อน แล้วค่อยกลับไป SELLER-005 (Finance) หรือทำคู่ขนาน

---

## Requirements (ร่าง — รอ Q1-Q3 ยืนยันก่อน finalize)

R1. สร้าง design token กลางที่ใช้ร่วมกันทั้ง 2 แอป (สี/typography/spacing/radius) — ต้องเป็นแหล่งความจริงเดียว ไม่ duplicate
R2. WYN palette: Cyan `#00C8FF` เป็น **accent เท่านั้น** + Black `#0A0A0A` + White `#FFFFFF` + Gray `#6B7280` + Border `#E5E7EB` + Dark (`#000000`/`#111111`/`#222222`)
R3. ZOKY sub-theme: Orange `#FF6B35` ใช้เฉพาะ price/CTA/seller badge/commerce state — **ห้ามเปลี่ยนทั้งหน้าจอเป็นส้ม**
R4. Typography scale ที่นิยามชัด (headline/body/caption/metadata) รองรับไทย+อังกฤษ ขั้นต่ำ body 14px
R5. Spacing scale 4px grid + touch target ขั้นต่ำ 44x44
R6. ทุกหน้าจอต้องผ่าน WCAG AA contrast ทั้ง light + dark
R7. ห้ามลบ/เปลี่ยนพฤติกรรมฟีเจอร์ใดๆ — งานนี้เป็น visual layer เท่านั้น
R8. Test 332 ตัวต้องผ่านครบทุกขั้นตอน

## Acceptance Criteria (ร่าง)

- [ ] มีไฟล์ token กลาง ทั้ง 2 แอปอ้างอิงแหล่งเดียวกัน ไม่มี seed color duplicate
- [ ] `grep "Color(0x"` ในโค้ด UI เหลือเฉพาะจุดที่จำเป็นจริง (overlay) และมี comment อธิบาย
- [ ] Cyan ไม่ถูกใช้เป็นพื้นหลังขนาดใหญ่ที่ไหนเลย
- [ ] ZOKY แสดง Orange เฉพาะจุดที่ระบุใน R3 เท่านั้น
- [ ] `flutter analyze` สะอาดทั้ง 2 แอป
- [ ] `flutter test` ผ่าน 265/265 (app) + 67/67 (seller)
- [ ] ไม่มีไฟล์ในโฟลเดอร์ `pop/` ถูกแก้ไขเลย (Pop ถูกระงับ)
- [ ] ไม่มีไฟล์ใน `data/` layer หรือ `supabase/schema.sql` ถูกแก้ไข

Dependencies: SELLER-004 QA (กำลังรัน) — ควรจบก่อนเริ่มแก้โค้ดเพื่อลดการชนไฟล์

Priority: สูง (Founder ร้องขอโดยตรง) — แต่ต้องผ่าน Q1 ก่อน

Risks: ดูตาราง R1-R5 ด้านบน

Recommendation:
แบ่งเป็น 8 task ย่อยแทนการทำรวดเดียว (ตามกติกา incremental ที่ Founder ระบุเอง):
- **DS-001** Token foundation (สี/typography/spacing) + ZOKY sub-theme — *task นี้*
- **DS-002** Global UI style pass (ลด card/border/shadow, whitespace, radius)
- **DS-003** Home Feed — card-less continuous feed
- **DS-004** Drop — image-first
- **DS-005** Club — community identity
- **DS-006** Profile + Search
- **DS-007** ZOKY commerce identity (orange accent)
- **DS-008** Responsive + accessibility + known issue (StoreScreen overflow)

เหตุผล: R1 ระบุว่า blast radius กว้างที่สุดในโปรเจกต์ — การแบ่งย่อยทำให้ QA ตรวจได้จริงและ rollback ได้ตรงจุดถ้าพัง

Handoff: **รอ Founder ตอบ Q1-Q3 ก่อน** จากนั้นส่งต่อ AI Design (`/design`) เพื่อกำหนด color scale + typography scale ที่ผ่าน WCAG AA จริง

---

## Design Output

> โดย AI Design — 2026-08-15 | spec เต็ม: `.wyn/docs/design/ds-001-color-system.md` | หน้าเปรียบเทียบให้ Founder ดู: `palette_compare.html`
> สถานะ: **PROPOSED — ยังไม่แตะ application source code ใด ๆ** งานนี้เป็น design spec ล้วน รอ Founder ตอบ Q1 ก่อนถึงจะส่งต่อ AI Coding

### ข้อค้นพบหลัก (คำตอบต่อความเสี่ยง R4 ใน audit)

R4 ที่ audit ตั้งไว้ว่า "Cyan บนพื้นขาว contrast ต่ำ" **ยืนยันแล้วว่าจริง และหนักกว่าที่คิด — เพราะไม่ได้เกิดกับ Cyan ตัวเดียว**

| สี | บนพื้นขาว | บนพื้นดำ `#0A0A0A` |
|---|---|---|
| Cyan `#00C8FF` | **1.96:1 ไม่ผ่าน** | 10.09:1 ผ่าน |
| Orange `#FF6B35` | **2.84:1 ไม่ผ่าน** | 6.98:1 ผ่าน |
| Blue `#2D6CDF` (เดิม) | 4.86:1 ผ่าน | 4.07:1 |

ทั้ง Cyan และ Orange ที่ Founder เสนอ **ตกเกณฑ์ AA บนพื้นขาว แต่ได้ค่าดีมากบนพื้นดำ** → palette ชุดนี้เรียกร้อง identity แบบ **dark-first** โดยธรรมชาติ ซึ่งสอดคล้องกับคอนเซปต์ "Black + White + Cyan" ที่ Founder เขียนไว้เอง

เพิ่มเติมจาก audit: ค่า border ที่ระบุมา (`#E5E7EB` = 1.2:1 และ `#222222` = 1.32:1) **ใช้เป็นขอบของสิ่งที่กดได้ไม่ได้** (WCAG 1.4.11 บังคับ 3.0:1) จึงต้องเพิ่มชั้น `border-strong` (`#8B929C` light = 3.14:1 / `#666666` dark = 3.66:1) — ค่าที่ Founder ให้มายังใช้ได้ แต่ใช้กับ **เส้นแบ่งตกแต่ง (divider)** เท่านั้น

### 3 ทางเลือกที่เสนอให้ Founder

| | A — Blue เดิม `#2D6CDF` | B — Cyan `#00C8FF` ตามที่เสนอ | **C — Cyan ฉบับผ่าน AA (แนะนำ)** |
|---|---|---|---|
| แนวคิด | ไม่เปลี่ยนอะไร | ใส่ค่าสีที่เสนอตรง ๆ ทั้งสองโหมด | สีแบรนด์เดียวกัน คนละระดับความเข้มต่อโหมด |
| Light mode | ปุ่มน้ำเงิน 4.86:1 ผ่าน | **ปุ่ม 1.96:1 / ราคา 2.84:1 ไม่ผ่าน** | ปุ่มดำ 19.8:1, accent Cyan `#00739E` 5.32:1, ราคา `#CC4A16` 4.61:1 — ผ่านหมด |
| Dark mode | ฟ้าพาสเทลที่ Material generate เอง | Cyan `#00C8FF` 10.09:1 สวยที่สุด | **เหมือน B ทุกประการ** (Cyan สด + Orange สด) |
| ZOKY identity | ไม่มี (ใช้สีเดียวกับ Social) | มี แต่ราคาอ่านยากใน light | มี และอ่านออกทั้งสองโหมด |
| ต้นทุน / ความเสี่ยง | ศูนย์ | ปานกลาง + **เสี่ยงตกรีวิว accessibility ตอนส่งสโตร์** | ปานกลาง (เท่ากับ B — blast radius เดียวกัน) |
| ตอบโจทย์ "Minimal Social Platform" | ไม่ | บางส่วน (เฉพาะ dark) | ใช่ ทั้งสองโหมด |

**Trade-off ที่ Founder ต้องยอมรับถ้าเลือก C**: light mode จะไม่มี Cyan สด `#00C8FF` ปรากฏเลย และปุ่มหลักใน light จะเป็นสีดำไม่ใช่สีแบรนด์ — แลกกับการที่ทุกอย่างอ่านออกจริงและ dark mode ได้ Cyan เต็ม 100%

### คำแนะนำ

**เลือก C** — เหตุผล:
1. ได้ Cyan ที่ Founder ต้องการเต็มที่ในโหมดที่มันสวยที่สุด (dark) โดยไม่ต้องประนีประนอม
2. light mode ยังใช้งานได้จริง ผ่าน AA และไม่เสี่ยงถูกตีกลับตอนรีวิวขึ้นสโตร์
3. ปุ่ม neutral (ดำ/ขาว) ทำให้หน้าจอเงียบและ minimal จริงตามบรีฟ แล้ว Cyan กลายเป็น "จุดที่แบรนด์ปรากฏ" ที่มีน้ำหนัก แทนที่จะถูกเจือจางเป็นน้ำเงินเข้มธรรมดา
4. ต้นทุน/ความเสี่ยงเท่ากับ B ทุกประการ (แตะ theme layer เหมือนกัน) แต่ได้คุณภาพสูงกว่าชัดเจน — ไม่มีเหตุผลเชิงวิศวกรรมที่จะเลือก B แทน C

**ทางเลือกเสริม (ต้องให้ Founder ตัดสิน)**: ตั้ง WYN เป็น **dark-first** (ค่าเริ่มต้น = ธีมมืด สลับเองได้) ซึ่งจะทำให้ palette นี้เปล่งประกายที่สุดและสร้างภาพจำที่ต่างจากโซเชียลอื่น

### สิ่งที่ spec นิยามครบแล้ว (พร้อมส่ง AI Coding ทันทีที่ Founder ยืนยัน)

- Color scale เต็ม: Cyan 9 เฉด / Orange 5 เฉด / Neutral 12 ค่า / Semantic 4 คู่ — ทุกค่าที่ใช้กับตัวหนังสือมี contrast ratio กำกับ
- Flutter `ColorScheme` mapping ครบทุก slot ทั้ง light + dark (**เลิกใช้ `colorSchemeSeed`** เพราะเป็นสาเหตุที่หน้าตายังเป็น Material default)
- ZOKY sub-theme: ใช้ช่อง `tertiary` ช่องเดียว → ระบุ 5 จุดที่ใช้ส้มได้ (ราคา / commerce CTA / seller badge / commerce state / จุด entry ของ ZOKY) และรายการห้ามใช้ + เพดานสัดส่วนพื้นที่สี
- Typography scale 13 ระดับ (body ขั้นต่ำ 14px, line-height ≥1.43 รองรับสระไทย, metadata 12px เป็นขนาดเล็กสุด) — **ไม่เพิ่ม dependency ฟอนต์ในรอบนี้** (ตรวจแล้ว `app/pubspec.yaml` ไม่มี `google_fonts` และไม่มี `fonts:`)
- Spacing 4px grid + radius scale + touch target ≥44 (แนะนำ 48) + focus ring
- ยืนยันกติกาเดิม: ห้าม Liquid Glass, ห้ามลอก layout Instagram/TikTok — **เพิ่ม Threads เข้าไปในรายการห้ามลอกด้วย** (เอาได้แค่ "ความเรียบ" ไม่เอาโครงหน้าจอ)

### การแก้ข้อขัดแย้งเรื่อง token file (สำคัญ — เกี่ยวกับ Acceptance Criteria ข้อแรกของ task นี้)

Acceptance Criteria เขียนว่า "ทั้ง 2 แอปอ้างอิงแหล่งเดียวกัน ไม่มี seed color duplicate" แต่ `.wyn/company/DECISIONS.md` (2026-08-15) ตัดสินไว้แล้วว่า **ไม่ใช้ monorepo tooling และไม่สร้าง shared package** ให้ duplicate seed color เข้า `seller_app/` ตรง ๆ — **สองข้อนี้ขัดกัน**

วิธีแก้ที่เสนอ (เคารพคำตัดสินใจของ Founder และยังได้ผลลัพธ์ตาม AC):
- `app/lib/core/design/` = **CANONICAL** (`wyn_colors.dart`, `wyn_typography.dart`, `wyn_spacing.dart`, `wyn_theme.dart`)
- `seller_app/lib/core/design/` = **MIRROR** สำเนาตรงตัวอักษร + header comment ชี้ไปที่ต้นทาง
- เพิ่ม test `seller_app/test/design/token_sync_test.dart` อ่านไฟล์ทั้งสองฝั่งด้วย `dart:io` แล้วเทียบเนื้อหา — drift แล้ว test แดงทันที
- `main.dart` ทั้งสองแอปเหลือแค่ `theme: WynTheme.light` — ไม่มีค่าสีดิบอีกต่อไป (แก้ข้อ "duplicate seed color ใน 2 main.dart" ได้ตรงจุด)
- ทางเลือกอนาคต (ต้องขออนุมัติ Founder): Flutter รองรับ path dependency ได้โดยไม่ต้องใช้ Melos — ค่อยพิจารณาเมื่อมีแอปที่ 3 (WYN Admin, Phase 6)

### Handoff ต่อ AI Coding (หลัง Founder ยืนยัน)

แบ่งเป็น 3 PR ย่อยภายใน DS-001 (แต่ละ PR รัน 332 tests):
1. **DS-001a** สร้าง 4 ไฟล์ token ใน `app/lib/core/design/` + สลับ `app/lib/main.dart` มาใช้ `WynTheme` — **ยังไม่แตะหน้าจอใด ๆ** (audit ยืนยันแล้วว่ามี `Color(0x...)` แค่ 8 จุด สีจะไหลไปทุกหน้าเอง)
2. **DS-001b** mirror เข้า `seller_app/` + test กัน drift + ZOKY sub-theme
3. **DS-001c** แทนที่ 8 จุดที่ hardcode สี (เช่น `Color(0x99000000)` ใน `product_grid_tile.dart`) ด้วย token + เปลี่ยนราคาเป็น `colorScheme.tertiary`

QA ต้องตรวจเพิ่ม: screenshot ทุกหน้าหลักทั้ง light/dark, ทดสอบที่ textScale 130%, และไล่เช็คว่า Orange ไม่หลุดไปฝั่ง Social / Cyan ไม่หลุดเข้า `seller_app/`
