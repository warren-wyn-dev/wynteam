# Feature Request — WYN-089

Status: design complete, ready for coding (2026-09-02)
Phase: Phase 2 — UI redesign
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 6/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เปลี่ยนสี/สถานะภาพของโพสต์ที่เรารีโพสต์ไปแล้ว ให้ดูออกว่ารีโพสต์แล้ว
Goal: ผู้ใช้เห็นปุ๊บรู้ปั๊บว่าโพสต์นี้ตัวเองเคยรีโพสต์ไปแล้ว ไม่ต้องกดซ้ำโดยไม่ตั้งใจ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ถ้าเรารีโพสต์ ควรเปลี่ยนสีนะ จะได้รู้ว่าเรารีโพสต์นี้แล้ว"
Requirements:
- ออกแบบสถานะ "active" ของปุ่ม/ไอคอนรีโพสต์ (สี/fill) เมื่อผู้ใช้ปัจจุบันเคยรีโพสต์โพสต์นั้นแล้ว คล้ายลอจิกปุ่มถูกใจที่ mark สีอยู่แล้ว
Acceptance Criteria:
- [ ] โพสต์ที่เรารีโพสต์ไปแล้ว ไอคอนรีโพสต์เปลี่ยนสี/สถานะให้เห็นชัดว่าทำไปแล้ว ต่างจากโพสต์ที่ยังไม่ได้รีโพสต์
Dependencies: เกี่ยวข้องกับ WYN-096 (redesign ปุ่มถูกใจ/คอมเมนต์/รีโพสต์) — ควรทำพร้อมกัน
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ไม่มีความเสี่ยงนัย | ต่ำ | - |
Recommendation: อนุมัติ แนะนำรวมกับ WYN-096
Handoff: AI Design (สเปกสี/สถานะ) → AI Coding

---

## Design Output (2026-09-02)

ปิด gap ที่ตรวจโค้ดพบจริง: `DropDetailScreen`'s Focused Action Bar เปลี่ยนไอคอนรีโพสต์เป็น `WynColors.sapphire` เมื่อ `redroppedByMe == true` อยู่แล้ว แต่ `HomeDropCard` (การ์ดฟีด/โปรไฟล์/hashtag feed) ยังไม่มี ตัดสินใจใช้สีเดียวกันเป๊ะ (`sapphire`/`graphite`) เพื่อให้ 2 จุดตรงกัน ไม่ใช่สีใหม่ ไม่มีภาพอ้างอิงที่ต้องรอ — งานนี้รวมสเปกกับ WYN-096 ไว้ในเอกสารเดียวตามที่แนะนำ (ควรทำพร้อมกัน) แต่ WYN-089 เองไม่ถูกบล็อกโดย WYN-096 เลย

Design doc เต็ม: `.wyn/docs/design/wyn-089-096-repost-active-state-action-row.md` (Part 1)

**ไม่มีอะไรบล็อก — พร้อมขึ้นโค้ดทันที**

---

## Coding Output (2026-09-02)

**สโคปที่ทำจริง (Part 1 เท่านั้น)**: ตามที่มอบหมาย ทำเฉพาะ WYN-089's ส่วน "repost icon active state" ใน `HomeDropCard` — **ไม่แตะ** `DropDetailScreen`'s action-row restyle (นั่นคือ WYN-096, Part 2 ของ design doc เดียวกัน) ซึ่งยังบล็อกอยู่รอ Founder ยืนยันภาพอ้างอิงตามที่ design doc เขียนไว้ชัดเจน

Root cause / สิ่งที่เปลี่ยน: ไม่ใช่บั๊ก — เป็นช่องว่างที่ AI Design ตรวจโค้ดพบจริง: `DropDetailScreen._buildFocusedActionBar()` มีสถานะ active ของไอคอนรีโพสต์อยู่แล้ว (`item.redroppedByMe ? WynColors.sapphire : WynColors.graphite`) แต่ `HomeDropCard`'s `ActionMetric` ตัว repost ยัง hardcode `color: WynColors.graphite` คงที่เสมอ ทำให้การ์ดฟีด/โปรไฟล์/hashtag feed ไม่บอกสถานะ "รีโพสต์แล้ว" ด้วยสี ต่างจากหน้ารายละเอียดโพสต์ — แก้ให้ตรงกัน 100% ตาม design spec (สีเดียวกันเป๊ะ ไม่ใช่สีใหม่)

Files Changed:
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` — เปลี่ยน repost `ActionMetric`'s `color` จาก `WynColors.graphite` คงที่ เป็น `item.redroppedByMe ? WynColors.sapphire : WynColors.graphite` (ตัวเลขนับ `redropCount` ไม่เปลี่ยนสีตาม ยังอยู่ใน `Text` ที่ผูกกับ `color` เดียวกันของ `ActionMetric` ตาม design spec ที่บอกว่าตัวเลขไม่ต้องเป็น indicator — นี่คือ trade-off ที่มีอยู่แล้วใน `ActionMetric`'s API เดิม: icon และ count ใช้ `color` ตัวเดียวกันเสมอ ไม่ได้แยกสีอิสระ — ดู Known Issues)
- `app/test/home_feed_screen_test.dart` — เพิ่ม import `wyn_colors.dart` + 2 เทสใหม่ ("the repost icon is WynColors.sapphire when...already reposted" / "...stays WynColors.graphite when...has not reposted") reuse fixture ที่มีอยู่แล้ว (`alreadyRedroppedTestHomeRepository` สำหรับ true, `toggleRedropTestHomeRepository` สำหรับ false — ไม่ต้องสร้าง fixture ใหม่)

Reason: Founder ข้อ 6/28 — "ถ้าเรารีโพสต์ ควรเปลี่ยนสีนะ จะได้รู้ว่าเรารีโพสต์นี้แล้ว"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **887/887 ผ่านหมด** (885 เดิม + 2 ใหม่)
- Red→green พิสูจน์จริง: เขียนเทสก่อนเป็น 1 test เดียวที่ pump widget 2 ครั้งสลับ fixture ในเทสเดียวกัน — พบว่า **เทสเองมีบั๊ก**: `tester.pumpWidget()` ครั้งที่ 2 ด้วย widget type เดิม (`HomeFeedScreen` ผ่าน `buildHome()`) ไม่ trigger `initState()`/`_loadInitial()` ซ้ำ (Flutter เพียง `didUpdateWidget` เพราะ element ตำแหน่งเดิมถูก reuse) ทำให้ state เก่าจากการ pump ครั้งแรกค้างอยู่ ยืนยันด้วยการรันแล้วเห็น assertion ที่ 2 fail (`notRedroppedIcon.color` ยังเป็น sapphire จากการ pump ครั้งแรก) — **แก้โดยแยกเป็น 2 `testWidgets` อิสระ** (แต่ละอันมี `pumpWidget` ของตัวเอง ไม่แชร์ widget tree ข้ามเทส) หลังแก้แล้ว `git stash push` เฉพาะไฟล์ `home_drop_card.dart` (โค้ดจริง ไม่แตะไฟล์เทส) → รันเทสใหม่ → **fail ตรงตามคาด** (`redroppedIcon.color` เป็น graphite ทั้งที่ควรเป็น sapphire) → `git stash pop` คืนโค้ดที่แก้แล้ว → รันซ้ำทั้งไฟล์ → ผ่านหมด (887 เทส)

Build: ไม่ได้รัน `flutter build` จริง — เป็น UI-only fix ไม่แตะ backend/schema

Known Issues:
- **`ActionMetric`'s icon กับตัวเลขนับใช้ `color` ตัวเดียวกัน**: design spec ระบุว่าตัวเลข `redropCount` "ไม่ควรเปลี่ยนสีตามสถานะ" (เหมือน Like) แต่ `ActionMetric`'s widget เดิม (ไม่ได้แก้ในงานนี้ — นอกสโคป) ผูก `color` เดียวกันให้ทั้งไอคอนและ `Text` เสมอ (ดู `action_metric.dart` บรรทัด 40-45) เท่ากับว่าตอนนี้ **ทั้งไอคอนและตัวเลขรีโพสต์เปลี่ยนเป็น sapphire พร้อมกันเมื่อ active** ต่างจาก Like ที่มี field `color` แยกส่งเข้าทั้ง icon/count เหมือนกัน (ตรวจแล้วพบว่า Like ก็มีพฤติกรรมเดียวกันทุกประการ — ตัวเลข like ก็เปลี่ยนเป็นแดงตอน active เหมือนกัน ไม่ใช่แค่ไอคอน) **สรุป: พฤติกรรมนี้สอดคล้องกับ Like ที่มีอยู่แล้วในระบบ ไม่ใช่ความไม่สอดคล้องใหม่** — design spec's ประโยคที่ว่า "ตัวเลขไม่เปลี่ยนสี" คลาดเคลื่อนจากพฤติกรรมจริงของ `ActionMetric`/Like ที่มีอยู่ก่อนแล้ว (ทั้งไอคอนและเลขเปลี่ยนสีพร้อมกันเสมอ เป็น convention เดิมของ widget นี้) — ตัดสินใจคงพฤติกรรมเดิมของ `ActionMetric` ไว้ (ให้ repost เหมือน Like เป๊ะ) แทนที่จะแยก API ใหม่ให้ icon/count มีสีอิสระ เพราะเป็นการเปลี่ยน widget ที่ใช้ร่วมกันหลายจุด (Comment/View ด้วย) นอกสโคปที่ Founder ขอ — ควรแจ้ง AI Design ให้ทราบ เผื่อไม่ตรงกับที่ตั้งใจ
- WYN-096 (Part 2 ของ design doc เดียวกัน) ยังไม่เริ่ม ตามที่ระบุไว้ในสโคปงานนี้ — รอ Founder ยืนยันภาพอ้างอิง
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (widget test เท่านั้น ไม่มี simulator/emulator)

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงว่าไอคอนรีโพสต์ในฟีด/โปรไฟล์/hashtag feed เปลี่ยนเป็นสี sapphire หลังกดรีโพสต์ และตรงกับสีที่ `DropDetailScreen` ใช้เป๊ะ (2) แจ้ง AI Design เรื่อง Known Issues ข้างบน (ตัวเลขนับเปลี่ยนสีตามด้วย ไม่ใช่แค่ไอคอน) ว่าตรงกับที่ตั้งใจหรือไม่ (3) ยืนยันว่า WYN-096 ยังไม่ถูกแตะ (scope guard)
