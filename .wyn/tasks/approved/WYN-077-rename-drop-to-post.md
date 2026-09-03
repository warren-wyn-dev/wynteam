# Feature Request — WYN-077

Status: approved — QA PASS (2026-09-02)
Phase: Phase 0 — Global rename
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 1/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เปลี่ยนคำว่า "Drop" เป็น "โพสต์" และ "ReDrop" เป็น "รีโพสต์" ทั้งแอป
Goal: ให้ศัพท์ที่ผู้ใช้เห็นเป็นภาษาไทยที่เข้าใจง่าย สอดคล้องกับ brand ปัจจุบัน
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "เปลี่ยนจากคำว่า Drop เป็น โพสต์ หรือ รีดรอป เป็น รีโพสต์"
Requirements:
- ไล่หาทุกจุดที่ขึ้นคำว่า "Drop"/"ReDrop" ใน UI string ทั้ง `app/` (bottom nav, ปุ่มโพสต์, ช่อง search placeholder, ปุ่ม tab บนโปรไฟล์ ฯลฯ) แล้วเปลี่ยนเป็น "โพสต์"/"รีโพสต์"
- ตรวจว่ามีคำว่า Drop/ReDrop หลุดไปใน error message, notification text, deep-link label ด้วยหรือไม่
- **ไม่แตะ** ชื่อตัวแปร/class/table/column ในโค้ด (`drop_id`, `DropCard` ฯลฯ) — เปลี่ยนเฉพาะข้อความที่ผู้ใช้เห็น เพื่อลดความเสี่ยง regression
Acceptance Criteria:
- [ ] grep หาคำว่า "Drop"/"ReDrop" ที่เหลืออยู่ใน UI string ทั้งแอปแล้วต้องไม่มีเหลือ (ยกเว้นชื่อโค้ดภายใน)
- [ ] หน้าที่เคยมีคำว่า Drop/ReDrop (bottom nav, post composer, search placeholder, profile tab, repost header) แสดง "โพสต์"/"รีโพสต์" ถูกต้อง
Dependencies: ไม่มี — งานอิสระ ควรทำก่อนงานอื่นเพราะหลายข้อ (7, 9, 26) อ้างอิงหน้าจอเดียวกัน
Priority: สูง (ทำก่อนสุด กระทบทุกหน้าจอ เสี่ยงต่ำ)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เผลอเปลี่ยนชื่อ field/table ในโค้ดจนพัง | ต่ำ | จำกัดการเปลี่ยนเฉพาะ UI string เท่านั้น |
Recommendation: อนุมัติ ทำได้ทันทีเป็นงานแรก
Handoff: AI Coding ทำตรงได้เลย (ไม่ต้องผ่าน Design เพราะเป็นแค่เปลี่ยนข้อความ)

---

## Coding Output (2026-09-02)

Implementation: grep ทุก UI string literal ที่มีคำว่า "Drop"/"ReDrop" ใน `app/lib` (แยกจาก code comment และชื่อ class/type เช่น `Drop`/`DropRepository` ที่ไม่แตะ) แล้วเปลี่ยนเป็น "โพสต์"/"รีโพสต์" ทุกจุด รวม 23 ไฟล์ใน `app/lib` — ครอบคลุม bottom nav label, ปุ่ม "สร้างโพสต์ใหม่" (semantics), search hint/tab, profile tab (โพสต์/รีโพสต์), dialog ลบโพสต์, notification message ทั้ง in-app และ push (ดูด้านล่าง), settings, delete-account bullet list, moderation label ฯลฯ — **พบและแก้เพิ่มเติมนอกสโคปเดิมของ requirement**: ข้อความ push notification ใน `supabase/functions/send-push-notification/_lib.ts` (`like_drop`/`comment_drop`/`mention_drop`/`redrop` message templates) ต้องแก้คู่กันเพราะโค้ด/เทสเดิมมีกติกาบังคับว่าต้องตรงกับ `notification_list_screen.dart`'s `_messageFor` เป๊ะทุกตัวอักษร (ดู WYN-016) — ถ้าไม่แก้คู่กันจะเกิดข้อความ push ไม่ตรงกับ in-app

Files Changed (35 ไฟล์):
- `app/lib/` 23 ไฟล์ (UI string rename เท่านั้น ไม่แตะชื่อ class/field/table)
- `app/test/` 9 ไฟล์ (`drop_detail_screen_test.dart`, `follow_list_screen_test.dart`, `home_feed_screen_test.dart`, `notification_list_screen_test.dart`, `recently_deleted_drops_screen_test.dart`, `root_shell_guest_gate_test.dart`, `root_shell_test.dart`, `search_screen_test.dart`, `view_profile_screen_test.dart`) — อัปเดต assertion string ให้ตรงกับข้อความใหม่
- `supabase/functions/send-push-notification/_lib.ts` + `_lib.test.ts` — mirror การเปลี่ยนข้อความเดียวกัน กัน push/in-app message ไม่ตรงกัน

Reason: Founder สั่งตรง (ข้อ 1/28, `Wynos_V1.0.0_Beta2.pdf`) — "เปลี่ยนจากคำว่า Drop เป็น โพสต์ หรือ รีดรอป เป็น รีโพสต์"

Tests:
- `flutter analyze` (app/): สะอาด ไม่มี issue
- `flutter test` (app/): **871/871 ผ่านหมด** (แก้ 16 test string assertion ที่ยังอ้างอิงคำเดิมก่อนหน้านั้นจนครบ)
- `deno check` + `deno lint` (send-push-notification): สะอาดทั้ง 3 ไฟล์
- `deno test`: **รันไม่ได้ในสภาพแวดล้อมนี้** — `jsr.io` (แหล่งของ `@std/assert` ที่เทสไฟล์ import) ตอบ HTTP 403 ทั้งทางตรงและผ่าน proxy ไม่ใช่ปัญหาโค้ด เป็นข้อจำกัด network policy ของ sandbox นี้เท่านั้น — การแก้ข้อความใน `_lib.ts`/`_lib.test.ts` เป็น string literal ล้วนๆ ไม่มี logic เปลี่ยน และ `deno check` ยืนยัน type-safe แล้ว ความเสี่ยงต่ำ แต่ **QA ควรรัน `deno test` จริงอีกครั้งในสภาพแวดล้อมที่เข้าถึง jsr.io ได้ก่อนอนุมัติเต็มรูปแบบ**

Build: ไม่ได้รัน `flutter build` เต็มรูปแบบรอบนี้ (เป็น text-only change, `flutter analyze` สะอาดเพียงพอสำหรับความเสี่ยงระดับนี้)

Known Issues:
- คำว่า "Pop"/"Club" ยังคงเป็นภาษาอังกฤษปนอยู่ (เช่น search hint "ค้นหา username, โพสต์, Pop, Club") — ตรงตามสโคปที่ Founder สั่งเฉพาะ Drop/ReDrop เท่านั้น ไม่ได้แตะ Pop/Club
- `ArgumentError('A text-only Drop needs a non-empty caption')` ใน `drop_repository.dart` ไม่ได้แก้ — เป็น internal error message (developer-facing, ไม่โผล่ใน UI ที่ผู้ใช้เห็น) ไม่ใช่ UI string ตามสโคป requirement

Handoff: ส่งต่อ AI QA & Security — ตรวจ (1) grep ยืนยันไม่มี "Drop"/"ReDrop" หลุดเหลือใน UI string จุดใดอีก (2) รัน `deno test` จริงถ้าสภาพแวดล้อม QA เข้าถึง jsr.io ได้ (3) สุ่มตรวจหน้าจอที่แก้ไขจริงว่าข้อความไทยอ่านลื่น ไม่มีจุดไหนคำซ้ำ/ประโยคแปลก (โดยเฉพาะ "รีโพสต์โพสต์ของคุณ" ที่ตั้งใจให้อ่านแบบนี้เพราะ "รีโพสต์" เป็นคำกริยาคำเดียวไม่ใช่ "รี"+"โพสต์" แยกกัน)

---

## QA Report (2026-09-02)

Feature: เปลี่ยนคำว่า "Drop"/"ReDrop" เป็น "โพสต์"/"รีโพสต์" ในทุก UI string (Wynos V1.0.0 Beta2, ข้อ 1/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` (Flutter 3.47.2, `app/`) จริงในเครื่อง sandbox — ไม่มี `deno`/network เข้าถึง jsr.io ในสภาพแวดล้อมนี้เช่นกัน (ยืนยันด้วยตัวเอง: `deno: command not found`) จึงตรวจความสอดคล้องของ `_lib.ts`/`_lib.test.ts` แบบ static (เทียบ string เป๊ะทีละบรรทัด) แทนการรัน `deno test` จริง

Test Cases:
1. `flutter analyze` สะอาดจริง ("No issues found!")
2. `flutter test` เต็ม suite ผ่านจริง (917/917 ในสถานะ branch ปัจจุบัน)
3. `grep -rn` หาคำว่า "Drop"/"ReDrop" ที่เป็น UI string literal (กรองชื่อ class/field/table ออก) ทั่ว `app/lib` — เจอเหลือ 2 จุดเท่านั้น: (a) `conversation_screen.dart:1345` เป็นแค่ type-cast `content as Drop` ไม่ใช่ข้อความที่ผู้ใช้เห็น (b) `drop_repository.dart:694`'s `ArgumentError` เป็น developer-facing exception message ไม่โผล่ใน UI — ตรงกับ Known Issues ที่ Coding Output ระบุไว้แล้วว่าตั้งใจไม่แก้เพราะนอกสโคป (ไม่ใช่ UI string)
4. `grep` หา "ReDrop" ที่เหลือ — ไม่พบเลย
5. เปรียบเทียบ `notification_list_screen.dart`'s `_messageFor` กับ `supabase/functions/send-push-notification/_lib.ts`'s `messageFor` — ข้อความ "รีโพสต์โพสต์ของคุณ" ตรงกันเป๊ะทั้ง 2 ฝั่ง (WYN-016's กติกาบังคับ push=in-app) และเทียบ `_lib.test.ts`'s assertion strings กับ `_lib.ts`'s actual strings — ตรงกันทุกบรรทัดที่ตรวจ (static verification, ไม่ได้รัน deno test จริง)
6. อ่านข้อความ "รีโพสต์โดย @sky_blue" ใน `home_drop_card.dart` — อ่านลื่น ไม่มีคำซ้ำ/ประโยคแปลก

Passed: 1, 2, 3, 4, 5, 6

Failed: ไม่มี

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — เป็น UI string rename ล้วน ไม่แตะ auth/RLS/schema/secret ใดๆ

Recommendation: อนุมัติ PASS แต่มี residual ที่ QA รอบนี้ยืนยันไม่ได้เต็มร้อย: (1) `deno test` จริง — ไม่มี `deno` ในสภาพแวดล้อมนี้ ต้องรันจริงในสภาพแวดล้อมที่เข้าถึง jsr.io ได้ก่อนปิดงานสมบูรณ์ (ตรวจ static แล้วว่า string ตรงกันทุกจุด ความเสี่ยงต่ำ) (2) สุ่มดูภาพหน้าจอจริงว่าคำไทยไม่ล้น/ตัดคำแปลกบนอุปกรณ์จริง — ไม่มี emulator ในสภาพแวดล้อมนี้ ต้องให้คนตรวจบนอุปกรณ์จริงอีกชั้นตามที่ Coding Output เองระบุไว้แล้ว

Final Status: PASS
