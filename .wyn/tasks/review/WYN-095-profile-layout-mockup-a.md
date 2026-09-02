# Feature Request — WYN-095

Status: coded, awaiting QA (2026-09-02)
Phase: Phase 2 — UI redesign
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 24/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: รีดีไซน์ layout หน้าโปรไฟล์ใหม่ทั้งหมด
Goal: จัดวางองค์ประกอบหน้าโปรไฟล์ใหม่ตามที่ Founder ระบุ ให้ดูเป็นระเบียบและอ่านง่ายขึ้น
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "อยากปรับหน้าโปรไฟล์ใหม่ วงสีแดง คือรูปโปรไฟล์ ใต้รูปโปรไฟล์ คือชื่อที่แสดง วงสีเขียวข้างๆ โปรไฟล์ จะเป็น ผู้ติดตาม กำลังติดตาม โพสต์ วงสีเหลือง คือชื่อผู้ใช้ ปล ส่วนปุ่มกดติดตาม ส่งข้อความ Bio นึกไม่ออก" (Founder ยังไม่มีไอเดียตำแหน่งปุ่มติดตาม/ส่งข้อความ/bio ชัดเจน — ให้ AI Design เสนอ)
Requirements:
- จัดวางใหม่: รูปโปรไฟล์ + สถิติ (ผู้ติดตาม/กำลังติดตาม/โพสต์) อยู่แถวเดียวกันข้างรูป, ชื่อที่แสดงอยู่ใต้รูปโปรไฟล์, username (@handle) อยู่ถัดไป ตามผังสีที่ Founder วง
- AI Design เสนอตำแหน่งปุ่มติดตาม/ส่งข้อความ และ bio ให้ Founder เลือก/อนุมัติ ก่อนส่งเข้า coding (Founder ระบุว่ายังไม่มีไอเดียส่วนนี้)
Acceptance Criteria:
- [x] Layout หน้าโปรไฟล์ตรงตามผังสีที่ Founder วงไว้ (แดง=รูปโปรไฟล์ใต้ชื่อที่แสดง, เขียว=สถิติ 3 ตัว, เหลือง=username)
- [x] Founder อนุมัติตำแหน่งปุ่มติดตาม/ส่งข้อความ/bio ก่อนขึ้นโค้ดจริง
Dependencies: เกี่ยวข้องกับ WYN-096 (ปุ่มถูกใจ/คอมเมนต์/รีโพสต์ อาจอยู่ใกล้กัน) — ยังไม่ทำ (บล็อกด้วยภาพอ้างอิงที่ยังไม่มี)
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Founder ยังไม่ยืนยันตำแหน่งปุ่มติดตาม/ส่งข้อความ/bio | กลาง | AI Design ทำ mockup 3 แบบเสนอเลือกก่อนเริ่ม coding จริง — **ปิดแล้ว**: Founder เลือก Mockup A |
Recommendation: อนุมัติหลักการ layout ตามผังสี — ส่วนปุ่ม/bio ให้ AI Design เสนอตัวเลือกกลับมาให้ Founder เลือกก่อน
Handoff: AI Design ทำ mockup (รวมข้อเสนอปุ่มติดตาม/ส่งข้อความ/bio) → ยืนยันกับ Founder → AI Coding

---

## Design Output (2026-09-02)

เสนอ 3 mockup ตามผังสีที่ Founder วง (avatar ซ้าย+สถิติขวาแนวเดียวกัน, ชื่อ+username ใต้แถวนั้นชิดซ้าย) ต่างกันแค่ตำแหน่ง bio/ปุ่มติดตาม-ส่งข้อความ: **A กะทัดรัด** (bio เต็มก่อน ปุ่มคู่แบ่งครึ่งเต็มแถว), **B ปุ่มเล็กชิดซ้าย** (ปุ่มก่อน bio, ต้นทุน implement ต่ำสุดเพราะ reuse ปุ่มเดิมตรงๆ), **C Editorial** (bio ก่อน ปุ่มซ้อน 2 บรรทัดเต็มแถว ลำดับความสำคัญชัดสุด) พร้อมตารางเทียบข้อดี-ข้อเสียแต่ละแบบ

Design doc เต็ม: `.wyn/docs/design/wyn-095-profile-layout-redesign.md`

## Founder Decision (2026-09-02)

Founder ดู mockup ภาพจริง (ส่ง HTML artifact ไปให้ดูหลังตอบ "ขอดูตัวอย่าง") แล้ว**เลือก Mockup A** (กะทัดรัด, ปุ่มคู่เต็มแถว) — พรีวิวรอบแรกใช้สี Cyan ผิดพลาด (DS-001 เดิม, ถูก re-brand ทับไปแล้ว) Founder ทักท้วงเรื่องโทนสีไม่ตรงของเดิม แก้เป็น Sapphire (`WynColors.sapphire #1B3A6B`) ให้ตรงกับแอปจริงแล้วก่อนอนุมัติ — Design doc มี Final Spec เต็มสำหรับ Mockup A แล้ว

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — เป็นการจัดวาง header ใหม่ทั้งก้อนตาม Final Spec ของ Mockup A ใน `wyn-095-profile-layout-redesign.md` แทนที่โครงเดิมของ `wyn-071-wynos-visual-refresh.md` (ทุกอย่างจัดกึ่งกลาง, avatar/ชื่อ/username/bio เรียงแนวตั้งเดี่ยว, สถิติอยู่ใต้ bio)

การเปลี่ยนแปลงหลักใน `ViewProfileScreen`'s header `Column` (`app/lib/features/profile/presentation/view_profile_screen.dart`):
1. **แถวบนสุดใหม่**: `Row` รวม `AvatarCircle(radius: 40, ring: true)` ชิดซ้าย + `Expanded` ครอบ `Row` สถิติ 3 ช่อง (ผู้ติดตาม/กำลังติดตาม/โพสต์, `mainAxisAlignment: spaceEvenly`) — เดิม avatar อยู่บนสุดเดี่ยวๆ กึ่งกลาง สถิติอยู่คนละที่ (ใต้ปุ่ม Follow/Edit)
2. **ชื่อ/username**: ย้ายมาอยู่ใต้แถว avatar+สถิติ, เปลี่ยนจาก `TextAlign.center` เป็นชิดซ้าย (ลบ `textAlign: TextAlign.center` ออก, เพิ่ม `crossAxisAlignment: CrossAxisAlignment.start` ให้ Column แม่)
3. **Bio**: ยังคงอยู่ใต้ username เหมือนเดิม แค่ไม่ centered แล้ว (ชิดซ้ายตาม Column ใหม่)
4. **ปุ่ม Follow/Message (โปรไฟล์คนอื่น)**: จาก pill ธรรมชาติ+ไอคอนวงกลม 40×40 วางกึ่งกลาง → `Row` เต็มความกว้างแบ่งครึ่งเท่ากันด้วย `Expanded` ทั้งคู่ — ปุ่ม Message เปลี่ยนจาก `OutlinedButton` ทรงกลม icon-only เป็น `OutlinedButton.icon` ทรง `StadiumBorder` มี label "ส่งข้อความ" (สี/เส้น/`WynColors.hairline` เดิมทุกประการ ไม่มีสีใหม่)
5. **ปุ่ม "แก้ไขโปรไฟล์" (โปรไฟล์ตัวเอง)**: คงความกว้างเดิม (ไม่ทำเป็น `Expanded`) ตามที่ spec ระบุว่าปุ่มเดี่ยวไม่ต้องแบ่งครึ่ง
6. **จำนวนตัวเลขสถิติ**: เพิ่ม helper ใหม่ `compactCountLabel()` ใน `app/lib/core/text_utils.dart` ("1,200" → "1.2K", "1,000,000" → "1M") ใช้กับ `_StatBlockContent`'s ตัวเลขที่แสดงผล (visual text เท่านั้น — `Semantics` label ยังอ่านตัวเลขเต็มเหมือนเดิม) ป้องกัน overflow ที่จอแคบ 360px ตามที่ design doc ระบุให้ AI Coding ตัดสินใจ format เอง

**ไม่ได้แตะ**: logic ของปุ่ม Follow ทั้ง 3 สถานะ (WYN-039), Blocked banner (WYN-027), Saved/Draft icons, Tab bar (Posts/ReDrops/Likes) — ทุกจุดยังทำงานเหมือนเดิมทุกประการ เปลี่ยนแค่ตำแหน่ง/ทรง ไม่เปลี่ยนพฤติกรรม

Files Changed:
- `app/lib/features/profile/presentation/view_profile_screen.dart` — จัดโครง header ใหม่ทั้งก้อนตาม Mockup A
- `app/lib/core/text_utils.dart` — เพิ่ม `compactCountLabel()`
- `app/test/text_utils_test.dart` — เทสใหม่ 4 เคสสำหรับ `compactCountLabel()`
- `app/test/view_profile_screen_test.dart` — เพิ่ม 2 เทสใหม่ยืนยัน layout (avatar+สถิติแถวเดียวกัน ชิดซ้าย, ปุ่ม Follow/Message แบ่งครึ่งเต็มแถว) + แก้ 1 เทสเดิมที่ตั้งใจเช็คพฤติกรรมเก่า (ปุ่ม Message เคยต้องเป็น icon-only ไม่มี label — ตอนนี้ต้องมี label ตาม Mockup A จึงสลับ assertion)

Reason: Founder ข้อ 24/28 — จัดหน้าโปรไฟล์ใหม่ตามผังสีที่วงไว้ พร้อมเลือก Mockup A จาก 3 ตัวเลือกที่ AI Design เสนอ

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **905/905 ผ่านหมด**
- Red→green พิสูจน์จริง:
  - `compactCountLabel()`: เขียนเทสก่อนมี implementation จริง (TDD) — เทสยืนยัน 1000→"1K", 1200→"1.2K", 1,260→"1.3K" (ปัดเศษ ไม่ปัดเศษทิ้ง) ฯลฯ ผ่านทันทีหลัง implement
  - Layout ใหม่: รันเทสเดิมของไฟล์ทั้งหมดก่อนแก้ (ยืนยัน 1 เทสพัง: "the message button is a circular icon, not a labeled ส่งข้อความ button" — ล้มเหลวจริงตามคาด เพราะโค้ดเก่ายังไม่มี label) แก้โค้ด+เทสแล้วรันซ้ำ ผ่านหมด
  - เทสใหม่ 2 ตัว (avatar+สถิติแถวเดียวกัน, ปุ่มแบ่งครึ่งเต็มแถว): ยืนยันด้วยการรันกับโค้ดจริงหลัง implement แล้ว — พบว่าสมมติฐานแรกของเทส ("avatar กับสถิติมี top edge ตรงกันเป๊ะ") ผิดจริง (Row's default `crossAxisAlignment.center` ทำให้ avatar ที่สูงกว่า centered กับสถิติที่เตี้ยกว่า ไม่ใช่ top-aligned) แก้เทสให้ตรงกับพฤติกรรม Flutter จริงแทนการเปลี่ยนโค้ด (เทสผิด ไม่ใช่โค้ดผิด — ยืนยันด้วย `tester.getRect`/`getCenter` เทียบตำแหน่งจริง)

Build: ไม่ได้รัน `flutter build` จริง — เป็น UI-only fix ไม่แตะ backend/schema

Known Issues:
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator ในสภาพแวดล้อมนี้ — เฉพาะ widget test ตรวจตำแหน่ง/ขนาดเท่านั้น) — ขอให้ AI QA & Security เปิดหน้าโปรไฟล์จริง (ทั้งโปรไฟล์ตัวเองและคนอื่น, follower count ที่มีเลขหลักพัน/ล้านจริงถ้าเป็นไปได้) ดูภาพหน้าจอจริงอีกชั้น โดยเฉพาะที่จอแคบ 360px ตามที่ design doc กำหนด
- `compactCountLabel()` ยังไม่ได้ใช้ที่จุดอื่นในแอปที่แสดงตัวเลขนับคล้ายกัน (เช่น like count) — อยู่นอกสโคปของ WYN-095 ตั้งใจไม่แตะจุดอื่น เผื่ออนาคตอยากทำให้สม่ำเสมอทั้งแอปควรเป็น task แยก

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงที่หน้าโปรไฟล์ทั้งของตัวเองและคนอื่น ยืนยัน layout ตรงผังสีของ Founder (2) ทดสอบที่ 360px ยืนยันไม่ overflow (3) ยืนยัน follower count หลักพัน/ล้านแสดงเป็น "1.2K"/"1M" ถูกต้อง (4) ทดสอบปุ่ม Follow ทั้ง 3 สถานะ + ปุ่ม Message ยังทำงานถูกต้องในตำแหน่งใหม่
