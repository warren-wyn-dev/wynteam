# Design Spec — DS-008 (Responsive + accessibility + known-issue closeout)

> โดย AI Design — 2026-08-16 | เฟสสุดท้ายของ 8-part rollout ที่ DS-001's Recommendation วางไว้

DS-008 ตามที่ DS-001 กำหนดไว้ครอบคลุม 3 เรื่องที่ไม่เกี่ยวกันโดยตรง: (1) touch-target audit ที่ DS-002 เว้นไว้ (R4), (2) การตัดสินใจเรื่อง 70 micro-spacing literal ที่ DS-002 เว้นไว้, (3) known issue ค้าง (StoreScreen overflow) + Responsive ทั่วไป

## 1. Touch-target audit (WCAG 2.5.5, ≥44px)

Grep หา `SizedBox`/`BoxConstraints` ที่ห่อ `IconButton`/`OutlinedButton`/`GestureDetector` ด้วยค่าต่ำกว่า 44px ทั้ง 2 แอป พบ **6 จุดจริงใน `app/`, 0 จุดใน `seller_app/`**:

| ไฟล์ | จุด | ค่าเดิม | แก้เป็น |
|---|---|---|---|
| `club_post_detail_screen.dart` | ปุ่มลบคอมเมนต์ | 32×32 | `WynSpacing.touchTargetMin` (44×44) |
| `drop_detail_screen.dart` | ปุ่มลบคอมเมนต์ | 32×32 | 44×44 |
| `drop_detail_screen.dart` | ปุ่มถูกใจคอมเมนต์ | 32×32 | 44×44 |
| `drop_detail_screen.dart` | ปุ่ม "ติดตาม" (header) | สูง 30 | สูง 44 |
| `club_section.dart` | แถวปุ่ม "สร้าง Club"/"สำรวจ Club" | สูง 36 | สูง 44 |
| `pop_clip_view.dart` | ปุ่ม "ติดตาม" | สูง 28 | **ไม่แก้** (ดูเหตุผลด้านล่าง) |
| `pop_comment_sheet.dart` | ปุ่มลบ/ถูกใจคอมเมนต์ (2 จุด) | 32×32 | **ไม่แก้** (ดูเหตุผลด้านล่าง) |

**เหตุผลที่ไม่แก้ 2 จุดใน Pop**: `.wyn/company/DECISIONS.md` (2026-08-14) ระบุว่า Pop ถูกระงับการพัฒนา และ DS-001's Risk R3 ระบุชัดว่า "ห้ามแก้ไฟล์ Pop โดยตรง" — แม้แต่ DS-001c เองที่แตะไฟล์ Pop แค่ 2 จุด (ค่าสีเดียวกันเป๊ะ ไม่มีผลภาพ) ก็ยังถูก QA บันทึกเป็น Minor finding ที่ต้องอธิบายเหตุผลรองรับ การเพิ่มขนาดปุ่ม 28→44px/32→44px เป็นการเปลี่ยน layout จริง (ไม่ใช่ byte-identical value swap แบบ DS-001c) จึงชัดเจนว่าอยู่นอกขอบเขตที่อนุญาต ปล่อยไว้ตามเดิม บันทึกเป็น known gap ที่รอ Pop ถูกปลดล็อกพัฒนาใหม่ในอนาคต

Regression test เพิ่มใน `drop_detail_screen_test.dart` (2 จุด: ปุ่มติดตาม + ปุ่มลบ/ถูกใจคอมเมนต์) ยืนยันขนาดจริง ≥44px — จุดอื่น (`club_post_detail_screen.dart`, `club_section.dart`) ใช้ pattern เดียวกันเป๊ะ ยืนยันด้วย `flutter analyze`/`flutter test` (ไม่มี regression) แต่ไม่ได้เพิ่ม test วัดพิกเซลแยกทุกจุด (ไม่มี test file แยกสำหรับ 2 widget นี้อยู่แล้วตั้งแต่ต้น การสร้าง harness ใหม่ทั้งชุดสำหรับ 1 บรรทัดต่อจุดเกินสัดส่วน)

## 2. 70 micro-spacing literals (ตัดสินใจแล้ว — DS-002's option ข)

DS-002 เว้น 54 จุดใน `app/` + 16 จุดใน `seller_app/` ไว้ (ส่วนใหญ่คือ `2`/`3`/`6`/`10` px และ `BorderRadius.circular(24)` ของ search bar ทรงแคปซูล) พร้อมถามว่าควร (ก) เพิ่ม token ใหม่รองรับ micro-spacing หรือ (ข) ปัดเข้า scale ที่มีตามดุลพินิจ

**การตัดสินใจ**: **ไม่แก้ทั้ง 70 จุด — ยอมรับเป็นข้อยกเว้นที่ตั้งใจ (intentional exception)** ไม่ใช่ "ค้างงาน" เหตุผล:
- ค่าเหล่านี้ส่วนใหญ่อยู่ใน element ขนาดเล็กมาก (gap ระหว่างไอคอนกับตัวเลขใน badge, padding ภายใน chip) ที่ 4px grid step ถัดไป (4px) จะทำให้ดูหลวมเกินไปเทียบกับองค์ประกอบรอบข้าง — การบังคับเข้า grid จะ**ลดคุณภาพภาพ** ไม่ใช่เพิ่ม
- `BorderRadius.circular(24)` ของ search bar ไม่ใช่ spacing เลย เป็นค่าที่คำนวณจากความสูงแท่งค้นหา (ปัดมุมครึ่งความสูง = ทรงแคปซูล) เอาเข้า `radiusFull` (999) ไม่ได้เพราะจะกลายเป็นวงรีผิดสัดส่วน เอาเข้า scale อื่นก็ไม่มีความหมายเชิงระบบ
- เพิ่ม token ใหม่ (`space0Half` ฯลฯ) โดยไม่มีจุดใช้จริงที่เป็นค่าเดียวกันมากพอ (54+16 จุดกระจายกันหลายค่า ไม่ใช่ค่าเดียว) จะทำให้ scale มี token ที่ใช้ไม่บ่อย ขัดกับเป้าหมาย "ระบบเดียวที่สอดคล้อง" ของ DS-001 เอง
- ทุกจุดยังคง "ค่าคงที่ตรงตามเจตนาเดิม" (ไม่ hardcode สีหรือ logic อะไรใหม่) เป็นแค่ตัวเลข spacing ที่ไม่ตรง 4px grid เป๊ะ ซึ่งเป็นเรื่องปกติในระบบ design จริงหลายระบบ (ไม่ใช่ทุกค่าต้องลง grid เป๊ะ 100%)

ปิด item นี้อย่างเป็นทางการด้วยการบันทึกเป็นการตัดสินใจ ไม่ใช่ปล่อยค้างแบบไม่มีคำตอบ

## 3. Known issue + Responsive

- **StoreScreen overflow**: ปิดไปแล้วตั้งแต่ต้นเซสชันนี้ (`.wyn/tasks/bugs/ZOKY-004-store-header-rating-row-overflow.md`, "แก้แล้ว ผ่าน QA — PASS")
- **Responsive (tablet/desktop)**: audit ยืนยันซ้ำว่ายังเป็นอย่างที่ DS-001 พบไว้ (`MediaQuery` 5 จุด ทั้งคู่เป็นการเช็ค `viewInsets`/`textScale` ไม่ใช่ breakpoint, `LayoutBuilder` 0 จุด) — **ตัดสินใจไม่สร้าง responsive layout ใหม่ในรอบนี้** เพราะ (1) WYN ถูกกำหนดเป็น "Mobile-first" ตั้งแต่ WYN-001 ไม่มีเป้าหมาย tablet/desktop ที่ระบุไว้จริง (2) การออกแบบ breakpoint/layout สำหรับหน้าจอใหญ่ทั้ง 45+ หน้าจอเป็นงานขนาดใหญ่ระดับ feature ใหม่ ไม่ใช่ visual-layer fix เหมือนงานอื่นใน DS-001 ถึง DS-007 (3) ทำแบบเดามาตรฐาน breakpoint เองโดยไม่มี requirement จาก Founder เสี่ยงเสียเวลาทำใหม่ถ้าทิศทางไม่ตรง — เก็บไว้เป็นคำถามเปิดให้ Founder ตัดสินใจถ้าต้องการรองรับ tablet/desktop จริงในอนาคต (แยกเป็น task ใหม่)
