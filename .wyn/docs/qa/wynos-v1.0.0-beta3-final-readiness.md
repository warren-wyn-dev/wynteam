# WYNOS v1.0.0 Beta3 — Final Readiness Report

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta3-polish-performance-aes6ld`
> **สถานะ: push ขึ้น feature branch แล้ว (container ของ session เป็น ephemeral ถ้าไม่ push งานหายทั้งหมด) — ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy · ไม่ได้แตะ production database หรือ configuration ใด ๆ** (ตามข้อ 37)
> Environment: Flutter 3.47.1 (SDK เดียวกับ CI/production) · PostgreSQL 16.13 ในเครื่อง
> เอกสารพี่น้อง: `system-map` · `performance` · `ux-audit` · `security-audit` · `future-ideas`

---

## 🚦 ระดับความพร้อม: **QA READY** (ยังไม่ Production Ready)

| ระดับ | สถานะ | เหตุผล |
|---|:--:|---|
| Development Ready | ✅ | analyze 0 issues · test **1,100** ผ่านทั้งหมด · build web สำเร็จ |
| **QA Ready** | ✅ **อยู่ตรงนี้** | คำสั่ง Beta3 ครบทุกข้อที่ทำได้ · ไม่มี regression · supabase suite เท่า baseline เดิม |
| Production Ready | ❌ | ยังไม่มีคนทดสอบด้วยมือบนอุปกรณ์จริง · ยังไม่มีตัวเลข performance จากเครื่องจริง · ยังไม่ได้ push |
| Blocked by Security | ❌ | Confirmed vulnerability = 0 |

---

## ✅ Completed

### แก้ปัญหาจริง 6 เรื่อง

| # | ปัญหา | ข้อของ Founder |
|---|---|---|
| 1 | Post Detail บังคับทุกรูปลงกรอบ 1:1 + crop — รูปตั้ง 4:5 หายหัวหายท้ายทันทีที่เปิดโพสต์ ทั้งที่ Feed แสดงเต็ม | 4, 5 |
| 2 | แถบหัวข้อของ Post Detail ตรึงตลอด กินจอ ~57px ที่ไม่เคยคืน | 5 |
| 3 | Profile 3 แท็บ + hashtag feed โหลดใหม่ทั้งลิสต์ทุกครั้งที่กด Back จาก Detail → scroll หาย, หน้าที่โหลดแล้วถูกทิ้ง | 6, 15 |
| 4 | โพสต์หลายรูปยิง 1 request **ต่อการ์ด** หลังหน้าขึ้นแล้ว + ยิงซ้ำอีกครั้งตอนเปิดโพสต์ | 9, 25 |
| 5 | `DropRepository` ทุก fetch path รอ 4 round trip เรียงกัน ทั้งที่ 4 query ไม่ขึ้นต่อกัน | 9, 25 |
| 6 | 4 ลิสต์ append หน้าใหม่แบบไม่กันซ้ำ ทั้งที่ใส่ `ValueKey` → **key ซ้ำทำให้ ListView throw** ไม่ใช่แค่แสดงซ้ำ | 8 |
| 7 | Post Detail แสดงรูปหลายรูปเป็น `PageView` เต็มความกว้างทีละรูป ไม่ใช่การ์ดเรียงกัน — โพสต์เดียวกันเป็นการ์ดใน Feed แล้วกลายเป็นแผ่นเดียวตอนเปิด (คำสั่ง Founder 2026-09-03) | 3 |
| 8 | แถวการ์ดเลื่อนอิสระ จอดโดยมีการ์ดค้างครึ่งขอบได้ — ตอนนี้ **snap ทีละการ์ด** ทั้ง Feed และ Detail (คำสั่ง Founder 2026-09-03) | 3 |

### งานตามคำสั่งเฉพาะ

| ข้อ | คำสั่ง | สถานะ |
|---|---|---|
| 12 | Club: ลบ Cover Image ให้เหลือ Background Image | ✅ **ทำแล้ว** ตามที่ Founder เลือก — เฉพาะหน้า Club page (cover picker + การ์ดใน Explore ไม่แตะ · ไม่ลบอะไรจาก DB) |
| 10 | Image performance | ✅ รูปในโพสต์ decode ตามขนาดที่วาดจริง — ลด bitmap 33–92% แล้วแต่ DPR |
| 11 | Image display consistency | ✅ aspect ratio / เพดานความสูง / placeholder / error รวมอยู่ที่ไฟล์เดียว |
| 32 | เอกสาร QA 6 ไฟล์ | ✅ ครบ |
| — | ส่งรูปให้ตรวจก่อน (UX/UI) | ✅ ส่ง artifact เปรียบเทียบ ก่อน/หลัง แล้ว |

### ตรวจแล้ว **ไม่พบปัญหา — ไม่แตะ** (มีค่าเท่ากับข้อที่แก้)

โครงสร้าง Post (ข้อ 2) · Horizontal carousel ของโพสต์หลายรูป (ข้อ 3) · Post Detail อยู่ใน scroll เดียวกันอยู่แล้ว ·
Home Back-navigation (แก้ไปแล้วตั้งแต่ Beta2) · Notifications state (ข้อ 17) · Search ไม่ต้อง debounce เพราะเป็น submit-based (ข้อ 16) ·
Optimistic UI + rollback + write serialization (ข้อ 13) · Follow/Block/Mute state (ข้อ 14) · Empty/Error state (ข้อ 19–20) ·
Index ครบทุกตัวที่ต้องใช้ (ข้อ 24) · `schema.sql` โหลดสด 0 ERROR

---

## 📝 Changed

```
21 files changed, 1288 insertions(+), 326 deletions(-)   (เทียบ origin/main)
```

**ไฟล์ใหม่ 2 ไฟล์:** `app/lib/core/widgets/post_media.dart` · `app/test/post_media_test.dart`

| กลุ่ม | ไฟล์ |
|---|---|
| Media (รวมกติกา + แถวการ์ดไว้ที่เดียว) | `core/widgets/post_media.dart` · `home_drop_card.dart` · `home_feed_image_peek_carousel.dart` · `drop_image_gallery.dart` · `club_post_card.dart` |
| Post Detail scroll | `drop_detail_screen.dart` |
| Back navigation | `profile_drop_grid_tab.dart` · `profile_likes_tab.dart` · `profile_redrops_tab.dart` · `hashtag_feed_screen.dart` |
| กันแถวซ้ำ | 3 แท็บข้างบน + `bookmarks_screen.dart` |
| Data / performance | `home_repository.dart` · `drop_repository.dart` · `home_feed_item.dart` · `drop.dart` |
| Club | `club_page.dart` |
| Test | `post_media_test.dart` · `drop_image_gallery_test.dart` · `profile_likes_tab_test.dart` · `club_page_test.dart` · `support/recording_drop_repository.dart` |

**ไม่ได้แตะเลย:** `supabase/schema.sql` · migration · RLS policy · RPC · `seller_app/` · `admin/` · auth flow · production config

**Commits (4, อยู่บน feature branch — ไม่ได้ merge เข้า `main`):**
1. `fix: one post shape everywhere, and stop rebuilding lists on back`
2. `perf: one round trip of viewer state per page, not four`
3. `fix: paginated lists could show (and key) the same row twice`
4. `docs: Beta3 QA set -- system map, performance, UX, security, readiness`

---

## 📊 Performance

รายละเอียดครบใน `wynos-v1.0.0-beta3-performance.md`

| รายการ | BEFORE | AFTER | IMPROVEMENT |
|---|---|---|---|
| Request รูป ต่อ 1 หน้า feed (โพสต์หลายรูป 8 โพสต์) | 8 | 1 | **−87.5%** |
| Request รูป ตอนเปิดโพสต์หลายรูปจาก feed | 1 | 0 | **−100%** |
| งาน DB ของ query รูป ต่อหน้า (วัดใต้ RLS) | 18.35 ms | 2.58 ms | **−86%** |
| Round trip viewer state ต่อ 1 หน้า | 4 (เรียงกัน) | 1 (ขนาน) | **−75%** |
| Bitmap ต่อรูป — DPR 3 / DPR 2 / DPR 1 | 10.2 MB | 6.8 / 3.4 / 0.85 MB | **−33% / −67% / −92%** |
| Index ที่ต้องเพิ่ม | — | **0** | ไม่มี migration |

**ตัวเลขที่ยังไม่มี และไม่ได้ถูกเดาแทน:** API latency จริง · เวลาเปิด Post Detail บนเครื่องจริง · memory profile · frame time
ทั้งหมดต้องรันบนอุปกรณ์จริงพร้อม production credential ซึ่ง session นี้ไม่มี

---

## 🎨 UX

รายละเอียดครบใน `wynos-v1.0.0-beta3-ux-audit.md` — Scenario A–E ของข้อ 29:

| | Scenario | ผล |
|---|---|---|
| A | Feed → เลื่อนลง → เปิด Post → Back | ✅ ถูกต้องอยู่แล้ว (ตรวจซ้ำ) |
| B | Post Detail → เลื่อน ทุกส่วนต่อเนื่องกัน | ✅ **ดีขึ้น** — แถบหัวข้อเลื่อนหายได้แล้ว |
| C | โพสต์ 3 รูป → ปัดซ้ายขวา | ✅ **ดีขึ้น** — ครบทุกรูปตั้งแต่เฟรมแรก |
| D | Profile → เปิด Post → Back | ✅ **แก้แล้ว** — เดิมโหลดใหม่ทั้งลิสต์ |
| E | Infinite scroll → load more | ✅ **ดีขึ้น** — Profile 3 แท็บ + Bookmarks กันซ้ำแล้ว |

**ทดสอบด้วย widget test ไม่ใช่มือจริง** — ยังต้องให้คนกดจริงยืนยันความรู้สึกอีกชั้น

---

## 🔒 Security

รายละเอียดครบใน `wynos-v1.0.0-beta3-security-audit.md`

* **Confirmed vulnerability: 0**
* **Potential hardening: 3** (RLS ของ `drop_images` ตรวจต่อรูปไม่ใช่ต่อโพสต์ · share link ชี้โดเมนที่ไม่มีจริง · ยังไม่มี crash reporter) — ทั้งสามมีอยู่ก่อน Beta3 และ **ไม่ได้แก้ใน Beta3**
* Query เดียวที่ Beta3 เพิ่ม (`drop_images` แบบ batch) **ทดสอบ RLS ตรง ๆ แล้ว**: ผู้ใช้ที่ใส่ id ของโพสต์ `only_me` ของคนอื่นลงในลิสต์ ได้ 0 แถว เจ้าของได้ครบ 3 แถว
* Beta3 ไม่มี schema change / migration / RLS policy ใหม่ / RPC ใหม่ / การเปลี่ยน auth หรือ storage

---

## 🧪 Tests

| ชุด | ผล |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **1,106 ผ่านทั้งหมด** (baseline 1,086 + **20 test ใหม่**) |
| `flutter build web --release` | ✅ **สำเร็จ** |
| `schema.sql` โหลดสดบน PostgreSQL 16.13 | ✅ **0 ERROR** |
| `supabase/tests/*.sh` (33 ไฟล์) | ⚠️ **27 ผ่าน / 6 fail** — **เท่า baseline ของ Beta2 พอดี ไม่มี regression** |

**6 ตัวที่ fail — แยกประเภทตามข้อ 28:**

* **Existing failure ทั้ง 6 ตัว ไม่ใช่ regression และไม่ใช่บั๊กผลิตภัณฑ์**
* 5 ตัว (`wyn_041/043/051/052/054_055`) — fixture สร้าง username `'admin'`/`'moderator'` ซึ่งชน constraint `profiles_username_not_reserved` ที่เพิ่มมาทีหลัง
* 1 ตัว (`wyn_038`) — ความคาดหวังถูกแทนที่โดย WYN-083 แล้ว และ `wyn_083_view_count_owner_and_repeat_test.sh` ที่ครอบพฤติกรรมปัจจุบัน **ผ่าน**
* **Beta3 ไม่แตะ SQL แม้แต่บรรทัดเดียว** ผลจึงเป็นไปไม่ได้ที่จะมาจากงานนี้
* วิธีซ่อมบันทึกไว้ใน `future-ideas` A-1/A-2 — **ไม่ทำใน Beta3** เพราะไม่ใช่ขอบเขตที่ Founder สั่ง

**14 test ใหม่ครอบอะไร:**
กติกา aspect ratio + fallback ทั้งหมด · รูป decode ตามขนาดที่วาดจริง · รูปตั้งไม่ถูกบีบเป็นจัตุรัสบน Detail ·
โพสต์ที่พก image list มาแล้วไม่ยิง request · กลับจาก Detail รีเฟรชแถวเดียวและรับค่าที่เปลี่ยนได้ ·
แถวที่ถูก unlike หลุดจากแท็บถูกใจ · **หน้า 1 ที่ทับหน้า 0 ไม่ทำให้แถวขึ้นซ้ำ** · Club แสดง background เสมอ ·
**รูปหลายรูปบน Detail เป็นการ์ด 82% สัดส่วน 4:5 และรูปที่ 2 โผล่น้อยกว่า 1 ใน 3 ของการ์ด** ·
**แถวการ์ด snap: ลากสั้นกลับที่เดิม · ลากเลยครึ่งจอดพอดี · ปัดแรงเลื่อน 1 การ์ดไม่ใช่ 3 · การ์ดสุดท้ายไม่เลยปลายแถว**

**หมายเหตุเรื่องคุณภาพ test:** test "หน้าซ้อนกัน" ถูก **ยืนยันว่า fail จริงถ้าเอา guard ออก** ไม่ใช่ test ที่ผ่านอยู่แล้วโดยบังเอิญ

---

## 🏗️ Build

`flutter build web --release` สำเร็จ · tree-shake icon ทำงานปกติ (98.8% / 99.4%) · ไม่มี warning ใหม่

---

## ⏳ Remaining — สิ่งที่ยังไม่ได้ทำ และทำไม

| # | เรื่อง | ทำไมยังไม่ทำ |
|---|---|---|
| R-1 | ทดสอบด้วยมือบนอุปกรณ์จริง (iPhone / Android) | ไม่มีอุปกรณ์ใน session นี้ — Scenario B/C/D ควรให้คนกดจริงยืนยันความรู้สึก |
| R-2 | วัด performance บนเครื่องจริง (latency, memory, frame time) | ไม่มีอุปกรณ์และไม่มี production credential — รายการที่ต้องวัดอยู่ใน `performance` §6 |
| R-3 | ซ่อม supabase test fixture 5 ตัว + `wyn_038` | นอกขอบเขต Beta3 — บันทึกไว้ `future-ideas` A-1/A-2 |
| R-4 | Profile header เลื่อนหายไปพร้อม tab content | ข้อ 5 พูดถึง Post Detail เท่านั้น การเปลี่ยนกระทบ 3 แท็บพร้อมกัน — `future-ideas` A-3 **รอคำสั่ง** |
| R-5 | Hardening 3 ข้อ (RLS per-row, share domain, crash reporter) | ทั้งสามมีอยู่ก่อน Beta3 · ข้อ 26 ห้ามแก้ security แบบเดาสุ่ม · RLS ต้องขออนุมัติเสมอ |

---

## ❓ Founder Decisions Required

| # | ต้องตัดสินใจ | ทางเลือก |
|---|---|---|
| **D-1** | **รูปที่ 2 โผล่เท่านี้พอไหม** | การ์ดกว้าง 82% ของแถว → บนจอ 390pt รูปที่ 2 โผล่ราว 62pt ถ้าอยากให้โผล่น้อยกว่านี้ บอกตัวเลขได้ — ปรับที่ `postCardWidthFraction` ค่าเดียว เปลี่ยนพร้อมกันทั้ง Feed และ Detail |
| **D-1b** | **รูปทรงอื่นตาม artifact โอเคไหม** | เพดานความสูงรูป 85% ของจอบน Post Detail (Feed ใช้ 75%) · แถบหัวข้อที่เลื่อนหายได้ |
| **D-2** | **ให้เปิด PR ได้หรือยัง** | ข้อ 37 ห้ามเปิด PR / merge / deploy โดยไม่ได้รับอนุญาต — ยังไม่ทำทั้งสามอย่าง<br>งาน push ขึ้น `claude/wynos-beta3-polish-performance-aes6ld` แล้ว เพราะ container ของ session นี้เป็น ephemeral ถ้าไม่ push งานจะหายทั้งหมดเมื่อ session จบ — branch นี้ไม่ใช่ production และไม่ได้ถูก merge เข้าที่ไหน |
| **D-3** | R-4 — Profile header เลื่อนหายด้วยไหม | ทำ / ไม่ทำ — ไม่ได้อยู่ในคำสั่ง Beta3 และมีความเสี่ยง regression ที่ไม่คุ้มถ้าไม่ได้สั่ง |
| **D-4** | R-3 — ซ่อม test fixture 5+1 ตัวที่ค้างแดง | ทำใน Beta3 / แยกเป็นงานต่างหาก — เป็นงานเล็กแต่ไม่ใช่ขอบเขต Beta3 |
| **D-5** | R-5 — hardening 3 ข้อ | ข้อ RLS ต้องขออนุมัติก่อนแตะเสมอ · ข้อ share domain ต้องรอโดเมนจริง |

---

## หลักที่ยึดตลอดงานนี้ (ข้อ 0 และ 35)

ก่อนแก้ทุกจุดถามคำถามเดียว: *"นี่คือการทำของเดิมให้ดีขึ้น หรือกำลังแอบเพิ่ม Feature ใหม่?"*

**ไม่มีฟีเจอร์ใหม่ · ไม่มีระบบใหม่ · ไม่มี Marketplace / Shop / ZOKY / Chat / Pop / Club feature / Check-in ใหม่ ·
ไม่มี migration · ไม่มี rewrite architecture · ไม่เปลี่ยน Product Direction · ไม่เปลี่ยน Brand Identity**

ไอเดียฟีเจอร์ใหม่ทุกอันที่เจอระหว่างทางถูกบันทึกไว้ที่ `wynos-v1.0.0-beta3-future-ideas.md` และ **ไม่ได้ implement**
