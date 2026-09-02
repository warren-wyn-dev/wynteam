# Design Spec — WYN-094: Progress Indicator ระหว่างโพสต์

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-094.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/drop/presentation/create_drop_screen.dart` (`_isSharing`, `_share()`, ปุ่ม "โพสต์"/"แชร์" ที่มี `CircularProgressIndicator` เล็กในตัวปุ่มอยู่แล้วตอนนี้, การวนลูป compress+upload หลายรูปที่มีอยู่แล้วจาก WYN-071)

ไม่มีภาพอ้างอิงที่ขาด — Product task ระบุเองว่า "Design เบา — แค่ยืนยันสไตล์ progress indicator" — **พร้อมขึ้นโค้ดได้ทันที**

---

Screen: `CreateDropScreen` — ระหว่างกดปุ่ม "โพสต์"/"แชร์" จนกว่าจะสำเร็จ/ผิดพลาด

Purpose: ให้ผู้ใช้เห็นความคืบหน้าจริงระหว่างอัปโหลด แทนที่ spinner นิ่งๆ ในปุ่มอย่างเดียว

User Flow: กด "โพสต์" → ปุ่ม disable + spinner เล็กในปุ่ม (เหมือนเดิม) **เพิ่ม**: แถบ progress บาง + ข้อความ % ปรากฏใต้ AppBar → อัปโหลดรูปทีละใบ (ถ้ามี) แถบขยับตามจำนวนรูปที่เสร็จ → อัปโหลดรูปครบ เข้าสู่ขั้นตอนบันทึกโพสต์ (สั้น) → สำเร็จ ปิดหน้าจอกลับฟีด เห็นโพสต์ใหม่ทันที (ไม่เปลี่ยนจาก flow เดิม)

## Components

- **แถบ progress**: `LinearProgressIndicator` บาง (สูง 3px) เต็มความกว้างจอ วางทันทีใต้ `AppBar` (เหนือเนื้อหาฟอร์ม) — track สี `WynColors.hairline`, fill สี `WynColors.sapphire` (สีเดียวกับปุ่ม "โพสต์"/Follow ที่ active — ใช้ accent เดิมของแอป ไม่เพิ่มสีใหม่)
- **ข้อความ %**: บรรทัดเล็กเหนือ/ข้างแถบ ("กำลังอัปโหลด 2/4 รูป... 50%") — `labelSmall` (13px), สี `WynColors.graphite`
- **Spinner ในปุ่มเดิม**: **คงไว้ไม่เปลี่ยน** (ยัง disable ปุ่ม + แสดง `CircularProgressIndicator` เล็กเหมือนปัจจุบัน) — แถบ progress เป็นของเสริม ไม่ใช่ตัวแทน

## เงื่อนไขการแสดงแถบ (สำคัญ — ไม่ใช่ทุกกรณีต้องมี)

- **โพสต์ที่มีรูปตั้งแต่ 1 รูปขึ้นไป**: แสดงแถบ progress + ข้อความ %
- **โพสต์ข้อความล้วน/Poll (ไม่มีรูป)**: **ไม่แสดงแถบ** — คงแค่ spinner ในปุ่มเดิม (การสร้าง Drop แบบไม่มีรูปเร็วมาก การใส่แถบ progress หลอกๆ ไม่มีความหมายจริง และเสี่ยงขัดกับ requirement's ของ Founder ในงานอื่นเรื่อง "ไม่ใส่ animation เยอะจนทำให้แอปช้า" — ใส่เฉพาะจุดที่มีของจริงให้วัด)

## การคำนวณ % (ปิด Risk R1 ของ Product task)

Supabase Storage client (`supabase_flutter`) เวอร์ชันที่ใช้อยู่ **ไม่มี byte-level upload progress callback ให้ใช้ตรงๆ** (ยืนยันจาก `Risk` ของ Product task เองที่เตือนไว้ล่วงหน้าแล้ว) — ใช้ทางเลือกที่แม่นยำกว่า "indeterminate เฉยๆ" แต่ไม่ต้องพึ่ง SDK ที่ไม่มี:

**สูตร**: `percent = (จำนวนรูปที่ upload เสร็จแล้ว / จำนวนรูปทั้งหมด) × 100` — คำนวณจาก loop ที่มีอยู่แล้วจริงในโค้ด (`create_drop_screen.dart`'s "แต่ละรูป compress ก่อน upload... วนลูปทำกับทุกรูปใน list") อัปเดต state หลังแต่ละรูป upload เสร็จ 1 ใบ (ไม่ใช่ estimate เดา — เป็นความคืบหน้าจริงระดับ "รูปไหนเสร็จแล้วบ้าง" แม้จะไม่ละเอียดถึงระดับ byte)

- ขั้นตอนสุดท้ายหลัง upload รูปครบ (insert แถว `drops`/`drop_images` เข้า DB): เร็ว ไม่มี sub-progress ที่มีความหมาย → ข้อความเปลี่ยนเป็น "กำลังบันทึกโพสต์..." พร้อมแถบค้างที่ 100% หรือสลับเป็น indeterminate สั้นๆ (ปล่อยให้ AI Coding เลือกแบบที่ implement ง่ายกว่า ไม่ใช่จุดตัดสินใจสำคัญ)
- โพสต์รูปเดียว (กรณีทั่วไปที่สุด): แถบกระโดดจาก 0% → 100% ทันทีที่รูปเดียวนั้น upload เสร็จ (ไม่มี step กลาง — ยอมรับได้ ตรงกับ "ขั้นตอนคร่าวๆ" ที่ Risk mitigation ของ Product task เสนอไว้)

## Interactions

- ปุ่ม "โพสต์"/"แชร์" ยังคง disable ระหว่าง `_isSharing == true` เหมือนเดิม (ไม่มีปุ่มยกเลิกกลางทาง — นอกสโคป, ไม่ใช่ requirement)
- แถบ progress ไม่ใช่ element ที่กดได้ (ไม่มี interaction ของตัวเอง)

## States

- **Default**: ไม่แสดงแถบ (ก่อนกดโพสต์)
- **Uploading (มีรูป)**: แถบ + % ตามสูตรข้างบน
- **Uploading (ไม่มีรูป)**: ไม่มีแถบ, มีแค่ spinner ปุ่มเดิม
- **Success**: หน้าจอปิด กลับฟีดทันที (ไม่มี state "100% ค้าง" ให้เห็นนาน — flow ปัจจุบัน `Navigator.pop(true)` ทันทีที่สำเร็จอยู่แล้ว ไม่ต้องเปลี่ยน)
- **Error**: **reuse `_errorMessage` ที่มีอยู่แล้ว** ("แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง" inline เหนือปุ่ม) — แถบ progress หายไป (ไม่ค้างที่เปอร์เซ็นต์เดิม เพราะไม่สื่อความจริงอีกต่อไปหลัง error) — **ไม่ต้องเพิ่มปุ่ม "ลองใหม่" ใหม่** เพราะปุ่ม "โพสต์"/"แชร์" กลับมา enable เองอยู่แล้วหลัง `_isSharing = false` (ดู `finally` block ที่มีอยู่แล้วในโค้ด) กดซ้ำ = retry ในตัว รูป/ข้อความที่พิมพ์ไว้ไม่หาย (พฤติกรรมเดิมที่ถูกต้องอยู่แล้ว)

## Responsive Behavior

แถบเต็มความกว้างจอเสมอ ไม่ผูกกับขนาดจอ — ข้อความ % ไม่ยาวเกิน 1 บรรทัดเสมอ (format สั้นตายตัว)

## Accessibility

- `Semantics(label: 'กำลังอัปโหลด $done จาก $total รูป, $percent เปอร์เซ็นต์')` ครอบแถบ progress ทั้งก้อน (ไม่ใช่แค่ visual bar เฉยๆ — ผู้ใช้ screen reader ต้องรู้ความคืบหน้าเหมือนกัน)
- `LinearProgressIndicator` ของ Flutter มี `value` (0.0-1.0) ที่ประกาศ progress ให้ accessibility service อัตโนมัติอยู่แล้วเมื่อไม่ใช่ indeterminate (`value: null`)

## Design Rules

- ใช้ `WynColors.sapphire`/`hairline`/`graphite` เดิมทั้งหมด ไม่มี token สีใหม่
- ห้ามใส่ animation ที่ไม่มีข้อมูลจริงรองรับ (เช่น fake-smooth progress ที่ขยับเองโดยไม่ตรงกับสถานะจริง) — ทุกการขยับของแถบต้องผูกกับ event จริง (รูปอัปโหลดเสร็จ 1 ใบ)

## Handoff

AI Coding — เพิ่ม state ใหม่ใน `CreateDropScreen`: `int _uploadedImageCount`, `int _totalImageCount` (derive จาก `_imagesBytes.length` ที่มีอยู่แล้ว) อัปเดต `_uploadedImageCount++` หลัง upload แต่ละรูปสำเร็จภายใน loop ที่มีอยู่แล้ว — เพิ่ม widget แถบ progress ใต้ `AppBar` แสดงเฉพาะเมื่อ `_isSharing && _totalImageCount > 0` — เขียน widget test ยืนยัน: (1) โพสต์มีรูป → แถบปรากฏและ % เพิ่มขึ้นตามจำนวนรูปที่ mock ให้ resolve ทีละใบ (2) โพสต์ไม่มีรูป → ไม่มีแถบเลย (3) error → แถบหายไป ปุ่มกลับมา enable

**สถานะ: พร้อมขึ้นโค้ดทันที**
