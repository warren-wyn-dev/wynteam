# Product Task — DS-001

Status: backlog (PHASE 1 AUDIT เสร็จ — รอ Founder ตัดสินใจ 3 ข้อก่อนเข้า Design)
Owner: AI Product Manager

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
