# Feature Request — WYN-088

Status: coded, awaiting QA (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 27/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เอาไอคอนดวงตา (ยอดวิว) ออกจากหน้า Home feed แต่คงไว้ในหน้าโปรไฟล์ตัวเอง
Goal: ลด clutter บนฟีดหลัก แต่เจ้าของโพสต์ยังต้องดูยอดวิวโพสต์ตัวเองได้จากหน้าโปรไฟล์
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "หน้า Home เอาดวงตาที่นับยอดคนดูออกจากหน้า Home feed แต่ดวงตาอยู่ตรงหน้าโปรไฟล์ของเรา ยังมีอยู่ จะได้รู้ว่ามีใครเห็นโพสต์นี้กี่คนดู"
Requirements:
- ซ่อนไอคอนดวงตา/ยอดวิวออกจากการ์ดโพสต์บนหน้า Home feed (ทุก tab: สำหรับคุณ/ติดตาม/จาก Club ของคุณ)
- คงไอคอนดวงตา/ยอดวิวไว้บนหน้าโปรไฟล์ของเจ้าของโพสต์เอง (ดูโพสต์ตัวเองเห็นยอดวิวปกติ)
Acceptance Criteria:
- [ ] หน้า Home feed ไม่มีไอคอนดวงตาอีก
- [ ] หน้าโปรไฟล์ตัวเอง เปิดดูโพสต์ตัวเองยังเห็นยอดวิวตามปกติ
Dependencies: ไม่มี
Priority: สูง (ง่าย เสี่ยงต่ำ)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ไม่มีความเสี่ยงนัย | ต่ำ | - |
Recommendation: อนุมัติ ทำได้ทันที
Handoff: AI Coding ทำตรงได้เลย

---

## Coding Output (2026-09-02)

`HomeDropCard` และ `HomePopCard` (การ์ดโพสต์บน Home feed ทั้ง 2 ชนิด) ถูก reuse ร่วมกันในหลายจุด (Home feed, หน้าโปรไฟล์ 3 tab, hashtag feed — Pop ไม่ได้ reuse ที่โปรไฟล์เพราะถูกถอดออกจากโปรไฟล์ไปแล้วตาม WYNOS V1.0.0 Beta requirement 3) จึงแก้แบบ **เพิ่ม parameter ใหม่** แทนการลบไอคอนทิ้งตรงๆ เพื่อไม่ให้กระทบจุดอื่นที่ยัง reuse widget เดียวกันอยู่:

- เพิ่ม `showViewCount` (bool, default `true`) ให้ทั้ง `HomeDropCard` และ `HomePopCard` — ห่อ ActionMetric ไอคอนดวงตาด้วย `if (showViewCount)`
- `home_feed_screen.dart` (จุดเดียวที่ต้องซ่อน ตาม requirement "ทุก tab: สำหรับคุณ/ติดตาม/จาก Club ของคุณ" — ทั้ง 4 mode ใช้ build method เดียวกัน) ส่ง `showViewCount: false` ให้ทั้ง `HomeDropCard` และ `HomePopCard`
- ทุกจุดอื่นที่ไม่ได้แตะ (`profile_drop_grid_tab.dart`, `profile_redrops_tab.dart`, `profile_likes_tab.dart`, `hashtag_feed_screen.dart`) ไม่ส่ง parameter นี้ → ใช้ default `true` → ยังเห็นไอคอนดวงตาเหมือนเดิม ตรงตาม acceptance criteria "หน้าโปรไฟล์ตัวเอง...ยังเห็นยอดวิวตามปกติ"

Files Changed:
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` — เพิ่ม `showViewCount` param, ห่อ ActionMetric เดิม
- `app/lib/features/home/presentation/widgets/home_pop_card.dart` — เหมือนกัน (Pop ก็อยู่บน Home feed ด้วย ตาม requirement ที่พูดถึง "หน้า Home feed" โดยรวม ไม่ได้แยกเฉพาะ Drop)
- `app/lib/features/home/presentation/home_feed_screen.dart` — ส่ง `showViewCount: false` ให้ทั้ง 2 call site
- `app/test/home_feed_screen_test.dart` — แก้ 2 assertion เดิม (WYN-038 QA fix ที่เคยยืนยันว่าไอคอนโชว์บน Home feed) ให้เป็น `findsNothing` แทน, เพิ่มกลุ่มเทสใหม่ยืนยันว่า default (ไม่ส่ง parameter) ยังโชว์ไอคอนตามปกติ (แทนที่จะ pump ทั้งหน้าโปรไฟล์จริงซึ่งซับซ้อนกว่า ใช้ `HomeDropCard` ตรงๆเหมือนเทส WYN-086/WYN-087)

Reason: Founder ข้อ 27/28 — "หน้า Home เอาดวงตาที่นับยอดคนดูออกจากหน้า Home feed แต่ดวงตาอยู่ตรงหน้าโปรไฟล์ของเรา ยังมีอยู่ จะได้รู้ว่ามีใครเห็นโพสต์นี้กี่คนดู"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **887/887 ผ่านหมด** (886 เดิม + 1 เทสใหม่ + แก้ 2 assertion เดิมให้ตรงพฤติกรรมใหม่)
- Red→green พิสูจน์จริง: บังคับ `showViewCount: true` ชั่วคราวที่ทั้ง 2 call site ใน `home_feed_screen.dart` (จำลองบั๊กกลับมา) รันเทส "renders a mix of Drop and Pop cards" → **fail ตรงตามคาด** (เจอไอคอนดวงตาที่ไม่ควรมี) คืนค่ากลับเป็นโค้ดที่แก้แล้ว รันซ้ำ → ผ่าน

Build: ไม่ได้รัน `flutter build` จริง — เป็น UI-only fix ไม่แตะ backend/schema

Known Issues:
- **Scope ที่ตัดสินใจเอง**: requirement พูดถึงแค่ "หน้า Home feed" กับ "หน้าโปรไฟล์ตัวเอง" ไม่ได้พูดถึง hashtag feed screen หรือหน้าโปรไฟล์ "คนอื่น" (ทั้งสองจุด reuse `HomeDropCard` เหมือนกัน) — **ไม่ได้แตะทั้งสองจุดนี้ ยังคงเห็นไอคอนดวงตาเหมือนเดิม** ตีความว่า requirement มุ่งเฉพาะ Home feed ตามที่ระบุตรงๆ ถ้า Founder อยากให้ซ่อนที่ hashtag feed หรือโปรไฟล์คนอื่นด้วย ต้องแจ้งกลับมา (แก้ง่ายมาก แค่ส่ง parameter เพิ่มอีกจุด เพราะโครงสร้าง toggle นี้เตรียมไว้ให้แล้ว)
- **Pop card**: แก้ให้ด้วยแม้ requirement จะพูดถึง "โพสต์" แบบกว้างๆไม่ได้ระบุเจาะจง Drop — ตีความว่าครอบคลุม Pop ด้วยเพราะเป็นการ์ดบน Home feed เหมือนกัน ถ้า Founder หมายถึงเฉพาะ Drop ต้องแจ้งกลับมา

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงว่าหน้า Home feed (ทั้ง 4 mode) ไม่มีไอคอนดวงตาอีก ทั้ง Drop และ Pop card (2) ยืนยันหน้าโปรไฟล์ตัวเอง (Drop/ReDrops/Likes 3 tab) ยังเห็นไอคอนดวงตาปกติ (3) ยืนยันกับ Founder เรื่อง Known Issues (hashtag feed / โปรไฟล์คนอื่น / Pop card) ว่าตีความสโคปถูกต้องหรือไม่
