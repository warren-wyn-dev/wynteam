# Feature Request — WYN-087

Status: approved — QA PASS (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 26/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: แสดงเวลาบน header รีโพสต์ ("รีโพสต์โดย @sky_blue") เหมือนโพสต์ปกติ
Goal: ให้ผู้ใช้รู้ว่ารีโพสต์เกิดขึ้นเมื่อไหร่ เหมือนที่โพสต์ปกติมีเวลากำกับ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ตรงรีโพสต์ "รีโพสต์โดย @sky_blue" ระบุเวลาเหมือนโพสต์ด้วย"
Requirements:
- เพิ่มเวลา (relative time เช่น "3 ชั่วโมงที่แล้ว") ต่อท้ายหรือใต้ข้อความ "รีโพสต์โดย @username" โดยใช้เวลาที่ผู้ใช้กดรีโพสต์ ไม่ใช่เวลาของโพสต์ต้นฉบับ
Acceptance Criteria:
- [ ] การ์ดที่ถูกรีโพสต์ แสดงเวลาที่รีโพสต์กำกับอยู่ที่ header ส่วน "รีโพสต์โดย @username" เหมือนที่โพสต์ปกติมีเวลากำกับ
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

พบว่าข้อมูลที่ต้องการ (เวลาที่กดรีโพสต์) **มีอยู่แล้วในระบบ** ไม่ต้องแก้ schema/backend เลย: `supabase/schema.sql`'s `home_feed` view, ใน UNION branch ของแถวที่เป็น ReDrop, เลือก `r.created_at` (เวลาของแถว `redrops` เอง ไม่ใช่ `d.created_at` ของ Drop ต้นฉบับ) เข้าคอลัมน์ `created_at` ของ view อยู่แล้ว — ฝั่ง `HomeFeedItem.createdAt` (มาจาก `created_at` คอลัมน์เดียวกัน) จึงเป็น **เวลารีโพสต์จริงอยู่แล้ว** สำหรับการ์ดที่เป็น ReDrop ตรงตามที่ Founder ต้องการเป๊ะ ("ใช้เวลาที่ผู้ใช้กดรีโพสต์ ไม่ใช่เวลาของโพสต์ต้นฉบับ") — งานนี้จึงเป็นแค่ UI: เอาค่าที่มีอยู่แล้วมาแสดงตรง header

แก้ที่ `HomeDropCard` (ใช้ร่วมกันฟีด Home/โปรไฟล์ 3 tab/hashtag feed) จุดเดียว: เดิม header "รีโพสต์โดย @username" เป็น `Text` เดี่ยวไม่มีเวลา — เพิ่ม " · {relativeTimeLabel(item.createdAt)}" ต่อท้ายในบรรทัดเดียวกัน (รูปแบบเดียวกับที่โพสต์ปกติมี "3 ชั่วโมงที่แล้ว" ใต้ชื่อผู้เขียน) ห่อ `Text` ด้วย `Flexible` เพิ่ม เพราะข้อความยาวขึ้น (username ยาว + เวลา) เสี่ยง overflow ในการ์ดแคบ จึงต้อง `overflow: TextOverflow.ellipsis` ด้วย

Files Changed:
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` — เพิ่ม relative time ต่อท้าย "รีโพสต์โดย @username", ห่อ `Flexible`+ellipsis กันล้น
- `app/test/home_feed_screen_test.dart` — เพิ่มเทสใหม่ยืนยันว่า header แสดงเวลาที่ถูกต้อง (ใช้ `item.createdAt` ของ ReDrop ไม่ใช่ของ Drop ต้นฉบับ)

Reason: Founder ข้อ 26/28 — "ตรงรีโพสต์ 'รีโพสต์โดย @sky_blue' ระบุเวลาเหมือนโพสต์ด้วย"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **886/886 ผ่านหมด** (885 เดิม + 1 เทสใหม่)
- Red→green พิสูจน์จริง: เอาส่วนต่อท้ายเวลาออกชั่วคราว รันเทสใหม่ → **fail ตรงตามคาด** คืนค่ากลับเป็นโค้ดที่แก้แล้ว รันซ้ำ → ผ่าน

Build: ไม่ได้รัน `flutter build`/schema migration จริง — ไม่มี schema change เลยในงานนี้ (ข้อมูลมีอยู่แล้ว)

Known Issues:
- **พบเรื่องที่เกี่ยวข้องแต่นอกสโคป**: เวลาใต้ชื่อผู้เขียนต้นฉบับ (author row หลัก ที่อยู่ใต้ avatar/ชื่อของเจ้าของโพสต์จริง) ก็อ่านจาก `item.createdAt` คอลัมน์เดียวกันนี้ — สำหรับการ์ด ReDrop แปลว่าเวลาที่แสดงตรงนั้น **จริงๆแล้วก็คือเวลารีโพสต์เหมือนกัน ไม่ใช่เวลาที่โพสต์ต้นฉบับถูกโพสต์จริง** (เพราะ view ไม่ได้แยกคอลัมน์ `drop_created_at` ออกมาต่างหาก) นี่เป็นพฤติกรรมเดิมของระบบ (ไม่ได้เกิดจากงานนี้) และ Founder ไม่ได้ขอให้แก้จุดนี้ตรงๆ — แต่ถ้าอยากให้ถูกต้องสมบูรณ์ (เวลาใต้ชื่อเจ้าของ = เวลาโพสต์จริง, เวลาที่ "รีโพสต์โดย" = เวลารีโพสต์) ต้องเพิ่มคอลัมน์ใหม่ใน `home_feed` view (schema change) แยกงานต่างหาก ไม่ได้แก้ในนี้เพราะเกินสโคปที่ Founder ระบุและมีความเสี่ยง schema เพิ่ม

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงว่าการ์ดที่ถูกรีโพสต์แสดงเวลากำกับที่ header ถูกต้อง (2) แจ้ง Founder เรื่อง Known Issues ข้างต้น (เวลาใต้ชื่อเจ้าของโพสต์ต้นฉบับบนการ์ด ReDrop จริงๆเป็นเวลารีโพสต์ ไม่ใช่เวลาโพสต์จริง) ถามว่าต้องการให้แก้เป็นงานแยกหรือไม่

---

## QA Report (2026-09-02)

Feature: แสดงเวลาบน header "รีโพสต์โดย @username" (Wynos V1.0.0 Beta2, ข้อ 26/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` จริง

Test Cases:
1. `flutter analyze` สะอาดจริง
2. `flutter test` เต็ม suite ผ่านจริง (917/917)
3. อ่าน `home_drop_card.dart` — ยืนยันบรรทัด "รีโพสต์โดย @${item.redropperUsername} · ${relativeTimeLabel(item.createdAt, ...)}" เพิ่มจริง ห่อด้วย `Flexible`+`TextOverflow.ellipsis` กัน overflow ในการ์ดแคบ
4. ตรวจ `supabase/schema.sql`'s `home_feed` view (UNION branch ของ ReDrop) — ยืนยัน `r.created_at` (เวลาของแถว `redrops` เอง) ถูก select เข้าคอลัมน์ `created_at` ของ view จริง ไม่ใช่ `d.created_at` ของ Drop ต้นฉบับ — สอดคล้องกับที่ `HomeFeedItem.createdAt` ใช้เวลารีโพสต์จริงตามที่ Founder ต้องการ ("ใช้เวลาที่ผู้ใช้กดรีโพสต์ ไม่ใช่เวลาของโพสต์ต้นฉบับ") ไม่ต้องแก้ schema เลยจริงตามที่ Coding Output อ้าง
5. Edge case: username ยาว + relative time label ยาว (เช่น "3 ชั่วโมงที่แล้ว") ในการ์ดแคบ — `Flexible`+ellipsis กัน overflow ตรวจโค้ดแล้วถูกต้อง ไม่มี hardcode width ที่จะพังกับ username ยาวผิดปกติ

Passed: 1, 2, 3, 4, 5

Failed: ไม่มี

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — UI-only, ไม่มี schema change, ไม่เปิดเผยข้อมูลใหม่ (เวลามีอยู่แล้วในระบบ แค่แสดงเพิ่ม)

Recommendation: อนุมัติ PASS — เห็นด้วยกับ Known Issues ที่ Coding Output ยกมาเอง: เวลาใต้ชื่อผู้เขียนต้นฉบับ (author row หลัก) บนการ์ด ReDrop จริงๆ ก็คือเวลารีโพสต์เหมือนกัน (อ่านจาก `item.createdAt` คอลัมน์เดียวกัน) ไม่ใช่เวลาที่โพสต์ต้นฉบับถูกโพสต์จริง — เป็นพฤติกรรมเดิมของระบบก่อนงานนี้ ไม่ใช่ regression จากงานนี้ แต่ Founder ควรได้รับแจ้งและยืนยันว่ายอมรับได้หรือควรแยกเป็นงานใหม่ (ต้องเพิ่มคอลัมน์ `drop_created_at` แยกใน view ถ้าต้องการแก้ให้สมบูรณ์)

Final Status: PASS
