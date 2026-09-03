# Product Full Spec — WYN-103

Status: full spec complete (2026-09-02) — ready for AI Coding โดยตรง (ไม่ต้องผ่าน Design เต็มรูปแบบ — ดู Handoff)
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` ข้อ 15/28, `.wyn/tasks/backlog/WYN-103.md`

Feature: จำกัดจำนวนรูปต่อโพสต์สูงสุด 9 รูปทุกจุดที่โพสต์ได้ + ยืนยัน/ปรับระบบบีบอัดรูปภาพให้สอดคล้องกัน

Goal: ป้องกันโพสต์ที่มีรูปเยอะเกินไป และลดพื้นที่จัดเก็บ/แบนด์วิดท์โดยรูปยังคมชัด

Target User: ผู้ใช้ WYN Social ทุกคน

## Problem — สถานะปัจจุบันจริง (ตรวจโค้ดแล้ว): ส่วนใหญ่ทำไปแล้ว เหลือจุดไม่สอดคล้องกัน

**ตรวจโค้ดพบว่า AC ทั้งสองข้อของ backlog เดิม "ทำไปแล้วเกือบสมบูรณ์"** ตั้งแต่ WYN-071 (2026-08-29) — ต่างจากที่ backlog เดิมสมมติว่าเป็นงานสร้างใหม่ทั้งหมด:

1. **จำกัด 9 รูปมีอยู่แล้วใน `CreateDropScreen`**: `_maxImages = 9` (บรรทัด 123 ของ `create_drop_screen.dart`) — ทั้ง `_pickImage`/`_pickMultipleImages` เช็ค `_imagesBytes.length >= _maxImages` ก่อนเปิด picker เสมอ มี counter "N/9" แสดงบน UI (บรรทัด 833)
2. **ระบบบีบอัดรูปมีอยู่แล้วผ่าน `image_picker` เอง**: ทุกจุดที่เลือกรูป (`ImagePicker().pickImage`/`pickMultiImage`) ระบุ `maxWidth: 1600, maxHeight: 1600, imageQuality: 85` ตรงกันหมด — เป็น native resize+JPEG quality compression ของแพลตฟอร์ม ไม่ใช่แค่ resize เฉยๆ

**สิ่งที่ตรวจแล้วว่าไม่สอดคล้องกันจริง (คือ gap ที่แท้จริงของงานนี้)**:
- **`create_club_post_screen.dart` (โพสต์ใน Club) จำกัดไว้ที่ `_maxImages = 10`** (บรรทัด 44) **ไม่ใช่ 9** — ขัดกับคำสั่งของ Founder "สูงสุด 9 รูป ห้ามเกิน" ที่ไม่ได้จำกัดว่าเฉพาะหน้าโพสต์ไหน (Club post ก็ยังนับเป็น "หน้าโพสต์" ในความหมายของ Founder)
- **ไม่มี "ระบบแจ้งเตือนเมื่อครบ" ที่ชัดเจน** — ปัจจุบันแค่ early-`return` เงียบๆ เมื่อถึง limit (ไม่เปิด picker ต่อ) กับ counter "N/9" อยู่แล้วเฉยๆ ไม่มี toast/snackbar/dialog บอกตรงๆ ว่า "ครบแล้ว" ตามที่ AC ของ backlog เดิมระบุไว้ ("ระบบแจ้งเตือนเมื่อครบ")

## Data Model Impact
**ไม่มี** — ไม่แตะ schema (`drops.image_urls`/`club_posts.image_urls` เป็น `text[]` อยู่แล้ว ไม่มี CHECK constraint จำกัดความยาว array ที่ระดับ DB วันนี้ — พิจารณาเพิ่มก็ได้แต่ไม่จำเป็นเพราะ UI บล็อกไว้แน่นอนอยู่แล้วทั้งสองจุดหลังแก้ และไม่มีทาง bypass ผ่าน UI ปกติ — ดู Edge Case 3 สำหรับกรณี defense-in-depth ที่ระดับ DB)

## Requirements

**1. แก้ `create_club_post_screen.dart`**: เปลี่ยน `_maxImages = 10` → `_maxImages = 9` (ให้ตรงกับ `CreateDropScreen` และคำสั่ง Founder เป๊ะๆ)

**2. เพิ่ม explicit feedback เมื่อถึง limit ทั้ง 2 จุด** (`create_drop_screen.dart` + `create_club_post_screen.dart`):
- เมื่อผู้ใช้พยายามเพิ่มรูปรูปที่ 10 (หรือกดปุ่มเพิ่มรูปทั้งที่ครบ 9 แล้ว): แสดง `SnackBar` ข้อความ **"เพิ่มรูปได้สูงสุด 9 รูปต่อโพสต์"**
- ปุ่ม/ไอคอนเพิ่มรูป: เปลี่ยนจาก "ยังกดได้แต่ไม่มีผล" (early return เงียบๆ) เป็น **แสดง SnackBar ทุกครั้งที่กดตอนครบแล้ว** (ไม่ใช่แค่ disable เฉยๆ เพราะ disable ปุ่มอาจทำให้ผู้ใช้งงว่าทำไมกดไม่ได้ — SnackBar สื่อสารชัดกว่า)

**3. ยืนยัน compression settings สอดคล้องกันทั้งแอป**: ตรวจสอบจุดอื่นที่อัปโหลดรูปเดี่ยว (avatar, club cover) ว่าใช้ค่าคุณภาพที่เหมาะสมของแต่ละบริบทอยู่แล้ว (avatar/cover ปัจจุบันก็ใช้ `imageQuality: 85` เหมือนกัน) — เป็น regression confirm ไม่ใช่งานใหม่ ไม่ต้องเปลี่ยนอะไรถ้าค่าที่มีอยู่แล้วเพียงพอ

## Edge Cases

1. **`image_picker`'s `imageQuality`/`maxWidth`/`maxHeight` มีข้อจำกัดจริงบางแพลตฟอร์ม** (เช่น Web ที่ decode/resize ฝั่ง client ผ่าน JS, หรือไฟล์ HEIC จาก iOS ที่บาง path ของปลั๊กอินไม่ resize จริงก่อน hand off): ต้องทดสอบจริงทั้ง 3 platform (iOS/Android/Web ตามที่โปรเจกต์นี้ target) ว่าไฟล์ที่ได้จริงเล็กลงจริง ไม่ใช่แค่เชื่อ parameter เฉยๆ — ถ้าพบว่า platform ใดไม่ compress จริง ต้องเพิ่ม fallback (เช่น package `flutter_image_compress` เพิ่มอีกชั้นหลัง pick) เป็น task ต่อยอด ไม่ใช่ blocker ของรอบนี้เพราะพฤติกรรมปัจจุบันยังไม่เคยถูกรายงานว่ามีปัญหาจริงจาก Founder/QA
2. **ผู้ใช้เลือกรูปพร้อมกันเกิน 9 รูปในครั้งเดียว** (multi-select gallery): `ImagePicker.pickMultiImage(limit: remaining)` มีอยู่แล้ว (ตัด limit ที่ระดับ native picker เอง ไม่ใช่แค่ filter หลัง pick) — ต้องตรวจว่า `limit` parameter ทำงานจริงทุก platform หรือบาง platform (เช่น Web) ไม่รองรับ `limit` แล้วคืนมาเกิน — ถ้าเกิน ต้อง truncate เหลือ `remaining` รูปแรกที่ฝั่ง Dart ก่อนใส่เข้า state เสมอ (defense-in-depth)
3. **API/DB level bypass**: ถ้ามีคน insert `drops`/`club_posts` row ตรงผ่าน REST API พร้อม `image_urls` ยาวเกิน 9 (ข้าม UI ไปเลย) — ปัจจุบันไม่มี CHECK constraint กันไว้ที่ DB — **แนะนำเพิ่ม CHECK constraint เป็น defense-in-depth** (`constraint drops_image_urls_max_9 check (array_length(image_urls, 1) is null or array_length(image_urls, 1) <= 9)` และเทียบเท่าสำหรับ `club_posts`) เนื่องจากเป็นการเปลี่ยนแปลงเล็กและปลอดภัย (ไม่กระทบข้อมูลเดิมที่ทุกแถวมีรูป ≤ 9 อยู่แล้วเพราะ UI บังคับมาตลอด)

## Acceptance Criteria
- [ ] `CreateDropScreen`: เลือกรูปเกิน 9 รูปไม่ได้ (เหมือนเดิม, regression) + เห็น SnackBar แจ้งเตือนเมื่อพยายามเพิ่มรูปตอนครบแล้ว (ของใหม่)
- [ ] `CreateClubPostScreen`: จำกัดที่ 9 รูป (เปลี่ยนจาก 10) + SnackBar แจ้งเตือนเหมือนกัน
- [ ] อัปโหลดรูปความละเอียดสูง (เช่น 4000×3000 จากกล้องมือถือ) แล้วขนาดไฟล์ลดลงอย่างมีนัยสำคัญ โดยดูด้วยตาไม่ต่างจากต้นฉบับในการแสดงผลปกติในแอป (ทดสอบจริงทั้ง 3 platform)
- [ ] Multi-select เกิน 9 รูปในครั้งเดียว → ได้แค่ 9 รูปแรกเสมอ ไม่ crash ไม่เกิน

## Dependencies
เกี่ยวข้องกับ WYN-092/093 (การ์ดรูปภาพ/aspect-fit — ไม่กระทบกันโดยตรง เป็นแค่การแสดงผลปลายทาง)

## Out of Scope (รอบนี้)
- เพิ่ม compression library ใหม่ (`flutter_image_compress` หรืออื่นๆ) เป็นชั้นเสริมหลัง `image_picker` — ทำเฉพาะถ้าทดสอบจริงแล้วพบว่า `image_picker`'s built-in compression ไม่พอ (ดู Edge Case 1) ไม่ใช่ทำล่วงหน้าโดยไม่มีหลักฐานว่าจำเป็น
- ปรับค่า `imageQuality`/`maxWidth`/`maxHeight` ให้สูง/ต่ำกว่าเดิม (85%/1600px) — ค่าปัจจุบันยังไม่เคยถูกร้องเรียนเรื่องคุณภาพ ไม่เปลี่ยนโดยไม่มีเหตุผล
- จำกัดจำนวนรูปของ Story/อื่นๆ ที่ไม่ใช่ Drop/Club post (ไม่มีฟีเจอร์เหล่านี้ในระบบวันนี้)

## Risks

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | บีบอัดแรงเกินจนภาพแตก/เบลอสังเกตได้ | กลาง | ค่าเดิม (85%/1600px) ใช้งานจริงมาตั้งแต่ WYN-071 ไม่เคยมีรายงานปัญหา — ไม่เปลี่ยนค่าโดยไม่มีเหตุผล ทดสอบเทียบภาพก่อน-หลังหลายประเภทถ้าจะปรับ |
| R2 | CHECK constraint ใหม่ (Edge Case 3) ต้องเช็ค production column/data จริงก่อน apply | ต่ำ | apply ผ่าน Supabase Dashboard SQL Editor ตรง ตรวจว่าไม่มีแถวเดิมเกิน 9 รูปอยู่ก่อนเพิ่ม constraint (ควรไม่มีอยู่แล้วเพราะ UI บังคับมาตลอด แต่ต้องยืนยันจริงไม่เดา) |

## Recommendation
อนุมัติ — งานนี้เล็กกว่าที่ backlog เดิมประเมินไว้มาก (ส่วนใหญ่ทำไปแล้วจาก WYN-071) เหลือแค่ความสอดคล้อง (9 vs 10) + UX feedback ที่ชัดเจนขึ้น + CHECK constraint เสริมความปลอดภัย

## Handoff
ส่งต่อ **AI Coding** (`/code`) ทำตรงได้เลย — Design เบามาก (แค่ยืนยัน SnackBar message ตรงตาม copy ที่ระบุไว้) → AI QA (ทดสอบ compression จริงบน iOS/Android/Web ตาม Edge Case 1 เป็นพิเศษ เพราะเป็นจุดเดียวที่ต้องพิสูจน์ด้วยอุปกรณ์จริง ไม่ใช่แค่ code review)
