# Feature Request — WYN-086

Status: approved — QA PASS (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 25/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: ปรับลำดับโพสต์: ข้อความอยู่บน รูปอยู่ล่าง
Goal: จัดลำดับการอ่านให้เป็นธรรมชาติ อ่านข้อความก่อนแล้วค่อยเห็นรูปประกอบ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "อยากให้ข้อความที่โพสต์อยู่ด้านบน ส่วนรูปอยู่ด้านล่าง"
Requirements:
- สลับลำดับการ์ดโพสต์ในฟีด (และหน้ารายละเอียดโพสต์ถ้ามีผลเดียวกัน) ให้ข้อความ caption อยู่เหนือรูปภาพเสมอ
Acceptance Criteria:
- [ ] โพสต์ที่มีทั้งข้อความและรูป แสดงข้อความก่อน แล้วรูปอยู่ด้านล่าง ทุกจุดที่การ์ดโพสต์ปรากฏ (ฟีด/โปรไฟล์/รายละเอียดโพสต์)
Dependencies: เกี่ยวข้องกับ WYN-091/092 (restyle การ์ดโพสต์) — ควรทำคู่กันหรือก่อนเพื่อไม่ต้องแก้ layout ซ้ำ
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | สลับลำดับแล้วกระทบ layout ที่ hardcode ตำแหน่งรูปไว้ที่อื่น (เช่น thumbnail ในหน้า list) | ต่ำ | เช็คทุกจุดที่ reuse การ์ดโพสต์เดียวกัน |
Recommendation: อนุมัติ แนะนำทำพร้อมกับ WYN-091/092 เพื่อลดรอบแก้ซ้ำ
Handoff: AI Design (ยืนยัน layout รวมกับงาน restyle การ์ด) → AI Coding

---

## Coding Output (2026-09-02)

**หมายเหตุสำคัญเรื่อง Handoff เดิม**: task นี้ถูกระบุ Handoff ไว้ว่าให้ผ่าน AI Design ก่อน (ยืนยัน layout รวมกับงาน restyle การ์ด WYN-091/092) ต่างจาก WYN-084/085 ที่ตรงเข้า AI Coding — แต่ WYN-091/092 อยู่ Phase 2 (ต้องรอ Founder อนุมัติแยกตามที่คุยกันไว้ตอนสรุปงานทั้งหมด ยังไม่เริ่ม) และคำสั่ง "เริ่ม Phase 0/1 ได้เลย" ระบุ WYN-086 เป็นหนึ่งใน 12 งานที่ต้องทำรอบนี้ตรงๆ **ตัดสินใจแก้เฉพาะสิ่งที่ Founder ขอตรงๆ (สลับลำดับ caption/ข้อความ กับ image เท่านั้น) โดยไม่รอ restyle ใหญ่** ถือเป็น minimal-safe-change ที่ตรงตาม requirement เป๊ะ ไม่ต้องแก้ layout ซ้ำเพิ่มเติมเมื่อ WYN-091/092 เริ่มจริง (โครงสร้าง Column/children เดิมไม่เปลี่ยน แค่สลับตำแหน่ง 2 บล็อก) — ถ้า Founder อยากให้รอ AI Design ก่อนจริงๆ ต้อง revert งานนี้แยกต่างหาก

Root cause: ไม่ใช่บั๊ก แต่เป็น layout order เดิมที่ตรงข้ามกับที่ Founder ต้องการตอนนี้ — ทั้ง `HomeDropCard` (การ์ดในฟีด/โปรไฟล์) และ `DropDetailScreen` (หน้ารายละเอียดโพสต์) วาง block รูปภาพ/Poll ไว้ *ก่อน* caption มาตั้งแต่แรก

แก้ 2 จุด (ทุกจุดที่การ์ดโพสต์ปรากฏตามที่ acceptance criteria ระบุ):

1. **`HomeDropCard`** (ใช้ร่วมกันทั้งฟีด Home, หน้าโปรไฟล์ 3 tab (Drop/ReDrops/Likes), และ hashtag feed — reuse widget เดียว ตรวจแล้วด้วย `grep -rln "HomeDropCard("`): สลับลำดับบล็อก caption กับบล็อก isPoll/imageUrl ใน `Column.children` — caption ขึ้นก่อนตอนนี้ ปรับ padding จาก `fromLTRB(12, 8, 12, 0)` เป็น `fromLTRB(12, 8, 12, 8)` (เพิ่ม bottom 8px) เพื่อให้มีช่องว่างจาก caption ไปยัง image/poll ที่ตามมา (เดิมพึ่งพา padding ของ widget ถัดไปให้ gap เอง ซึ่งตอนนี้ตำแหน่งเปลี่ยนแล้ว)
2. **`DropDetailScreen._buildBody`**: เดิมมี Padding/Column ก้อนเดียวรวม author row + caption + `_buildStatLine()` วางไว้ *หลัง* image/poll ทั้งก้อน — แยกเป็น 2 Padding block: block แรก (author row + caption) มาก่อน ตามด้วย image/poll แล้วปิดท้ายด้วย block ที่สอง (`_buildStatLine()` เดิม) เพื่อให้ image/poll คั่นกลางระหว่าง caption กับ stat line แทน

**ไม่ได้แตะ**: ลำดับของ "รีโพสต์โดย @..." meta row และ Quote ReDrop's quoteText (ทั้งสองอยู่เหนือ author row อยู่แล้ว เป็นข้อความคนละความหมายกับ caption ของโพสต์ต้นฉบับ ไม่ใช่สิ่งที่ Founder หมายถึง)

Files Changed:
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` — สลับตำแหน่ง caption block กับ isPoll/imageUrl block, ปรับ padding
- `app/lib/features/drop/presentation/drop_detail_screen.dart` — แยก header's Padding/Column ออกเป็น 2 block คั่นด้วย poll/image
- `app/test/home_feed_screen_test.dart` — เพิ่มเทสใหม่ยืนยันตำแหน่ง caption อยู่เหนือ image ใน `HomeDropCard`
- `app/test/drop_detail_screen_test.dart` — เพิ่มเทสใหม่ยืนยันตำแหน่ง caption อยู่เหนือ image ใน `DropDetailScreen`

Reason: Founder ข้อ 25/28 — "อยากให้ข้อความที่โพสต์อยู่ด้านบน ส่วนรูปอยู่ด้านล่าง"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **885/885 ผ่านหมด** (883 เดิม + 2 เทสใหม่)
- Red→green พิสูจน์จริงทั้ง 2 จุด: สลับลำดับกลับเป็นแบบเดิม (image/poll ก่อน caption) ชั่วคราวทั้ง `HomeDropCard` และ `DropDetailScreen` แยกกัน รันเทสใหม่แต่ละจุด → **fail ตรงตามคาดทั้งคู่** คืนค่ากลับเป็นโค้ดที่แก้แล้ว รันซ้ำ → ผ่าน

Build: ไม่ได้รัน `flutter build` จริง — เป็น UI-only fix ไม่แตะ backend/schema

Known Issues:
- **Poll content type**: ยังคง Poll ไว้ก่อน caption เหมือนเดิม (ไม่ได้สลับ) เพราะ requirement/acceptance criteria พูดถึง "ข้อความ+รูป" เท่านั้น ไม่ได้พูดถึง Poll โดยตรง — ถ้า Founder อยากให้ caption ขึ้นก่อน Poll ด้วย (เพื่อความสม่ำเสมอ) ต้องแจ้งกลับมา
- **DropDetailScreen's stat line**: เดิม comment ในโค้ดระบุว่า stat line ออกแบบมาให้อยู่ "under the caption" (07-post-detail.tsx spec) — ตอนนี้ stat line อยู่ใต้ image/poll แทน (caption → image/poll → stat line) ไม่ใช่ใต้ caption โดยตรงอีกต่อไป ยังคง "อยู่ล่างสุดก่อน action bar" เหมือนเดิม แต่ตำแหน่งสัมพัทธ์กับ caption เปลี่ยนไป — ควรให้ AI Design ยืนยันว่าลำดับใหม่ (author → caption → image/poll → stat line → action bar) ใช้ได้ตามที่ตั้งใจหรือไม่ โดยเฉพาะตอนทำ WYN-091/092 restyle จริง
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (เฉพาะ widget test ตรวจตำแหน่ง Y) — ขอให้ AI QA & Security เปิดโพสต์ตัวอย่างจริงที่มีทั้งข้อความและรูปดูภาพหน้าจอจริงอีกชั้น

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงที่ฟีด/โปรไฟล์/หน้ารายละเอียดโพสต์ ว่า caption อยู่บนรูปเสมอ (2) ยืนยันกับ Founder เรื่อง Poll (ยังไม่สลับ) และตำแหน่ง stat line ใหม่ใน DropDetailScreen ตามที่ระบุใน Known Issues (3) แจ้ง AI Design ให้ทราบเรื่องงานนี้ทำไปแล้วก่อน WYN-091/092 เผื่อต้องออกแบบให้สอดคล้องกันตอน restyle จริง

---

## QA Report (2026-09-02)

Feature: สลับลำดับการ์ดโพสต์: ข้อความ (caption) อยู่บน รูปอยู่ล่าง (Wynos V1.0.0 Beta2, ข้อ 25/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` จริง

Test Cases:
1. `flutter analyze` สะอาดจริง
2. `flutter test` เต็ม suite ผ่านจริง (917/917)
3. อ่าน `home_drop_card.dart`'s `build()` — ยืนยัน `caption` block (`if (item.caption != null...)`) มาก่อน `isPoll`/`imageUrl` block จริงตามลำดับ children ใน `Column` (ใช้ร่วมกันทั้งฟีด Home, โปรไฟล์ 3 tab, hashtag feed — reuse widget เดียว ยืนยันด้วย `grep -rln "HomeDropCard("`)
4. อ่าน `drop_detail_screen.dart`'s `_buildBody` — ยืนยันแยกเป็น 2 `Padding` block จริง: block แรก (author row + caption) มาก่อน แล้วตามด้วย image/poll แล้วปิดท้ายด้วย `_buildStatLine()` — ลำดับ author→caption→image/poll→stat line→action bar ตรงตามที่อธิบาย
5. Edge case: โพสต์ caption-only (ไม่มีรูป ไม่ใช่ poll) — `HomeDropCard` ยัง render caption ปกติไม่มีอะไรอยู่ใต้ ตรวจแล้วไม่ crash/ไม่มีช่องว่างแปลกๆ เพราะโครงสร้าง `if` แต่ละ block เป็นอิสระต่อกัน
6. Edge case: โพสต์ที่เป็น Poll — ยืนยันว่า **Poll ยังอยู่ก่อน caption เหมือนเดิม ไม่ได้สลับ** ตรงตามที่ Known Issues ระบุไว้ตรงๆ ว่าตั้งใจไม่แตะ (requirement พูดถึงแค่ "ข้อความ+รูป")
7. เช็ค `DoubleTapLike` wrapper (double-tap เพื่อกดไลค์) — ยังคงห่อรูป/caption-only ถูกต้องตามโครงสร้างเดิม ไม่หลุดหายไปหลังสลับลำดับ

Passed: 1, 2, 3, 4, 5, 6, 7

Failed: ไม่มี

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — สลับลำดับ widget ล้วน ไม่แตะ data/auth

Recommendation: อนุมัติ PASS — เห็นด้วยกับข้อกังวลที่ Coding Output ยกมาเอง 2 จุด ควรให้ Founder/AI Design ยืนยันก่อนถือว่าจบสมบูรณ์: (1) Poll ยังไม่ถูกสลับให้ caption ขึ้นก่อนเหมือน image/text ปกติ — อาจดูไม่สม่ำเสมอถ้า Founder ต้องการให้ Poll สอดคล้องกันด้วย (2) `DropDetailScreen`'s stat line ย้ายจาก "อยู่ใต้ caption ทันที" (ตามที่ spec เดิม 07-post-detail.tsx เคยระบุ) เป็น "อยู่ใต้ image/poll" แทน — เป็นผลข้างเคียงจากการสลับลำดับที่สมเหตุสมผลแต่เปลี่ยน layout เดิม ควรให้ AI Design ยืนยันก่อนทำ WYN-091/092 restyle ต่อ ไม่ใช่ blocker ของงานนี้ (ตรงตาม requirement/acceptance criteria ที่ระบุไว้ครบแล้ว) แต่เป็นความเสี่ยง scope-creep ที่ต้อง sync กับ Design งานถัดไป — ต้องมีคนดูภาพจริงบนอุปกรณ์เพื่อยืนยันความสวยงามสุดท้ายเช่นเดียวกับทุกงาน UI (widget test ยืนยันแค่ตำแหน่ง Y เท่านั้น)

Final Status: PASS
