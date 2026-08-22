# Design Spec — WYN-026: Report System

อ้างอิง Design System ที่อนุมัติแล้ว (ไม่คิดทิศทาง visual ใหม่): `.wyn/docs/design/ds-001-color-system.md` (Cyan `#00C8FF` primary, Orange เฉพาะ ZOKY), `.wyn/docs/design/ds-008-responsive-accessibility.md` (touch target 44×44, ไม่ทำ responsive breakpoint ใหม่), `.wyn/docs/design/ds-009-rainbow-accent.md` (ไม่เกี่ยวข้องกับงานนี้)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-026-report-system.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `ClubPage`'s More menu (WYN-014, มีปุ่ม "รายงาน Club" เป็น placeholder อยู่แล้ว — งานนี้ทำให้ทำงานจริง), `ClubPostCard`'s More menu (WYN-014), Drop Detail's ปุ่มลบ (WYN-005), Comment row ของ Drop/Club Post (WYN-005/014/022), `ViewProfileScreen` (WYN-013), Bottom Sheet pattern ของ avatar action sheet (WYN-003)

## ภาพรวมแนวทาง: 1 component ใช้ซ้ำทุกจุด ไม่ใช่สร้างหน้าจอแยกต่อประเภทเนื้อหา

`ReportSheet` เป็น bottom sheet เดียวที่ parameterize ด้วย `targetType`/`targetId`/`targetLabel` (ข้อความสั้นบอกว่ากำลังรายงานอะไร เช่น "รายงานโพสต์ของ @username") — ทุก entry point ทั่วแอปเรียกเปิด sheet เดียวกันนี้ ไม่สร้าง UI ใหม่ต่อประเภทเนื้อหา ตรงตามกติกา "ห้ามคิดทิศทาง visual ใหม่" และลดงาน Coding/QA ซ้ำซ้อน

**Pop ไม่อยู่ใน scope นี้** (ตรงกับ Product Spec ที่ไม่รวม Pop) — ไม่แตะไฟล์ใดใน `pop_*`/`PopClipView`/`HomePopCard` เลย ตามกติกาที่ DS-008 วางไว้ (Pop ถูกระงับการพัฒนา, `.wyn/company/DECISIONS.md` 2026-08-14)

---

## Screen 1: `ReportSheet` — Bottom Sheet หลัก (reusable component)

Purpose: ให้ผู้ใช้เลือก Category + กรอกรายละเอียดเพิ่มเติม แล้วส่ง Report สำหรับ target ใดก็ได้ในแอปด้วย UI เดียวกัน

User Flow:
1. ผู้ใช้แตะ "รายงาน" จาก entry point ใดก็ได้ (ดู Screen 2-6) → `ReportSheet` เปิดขึ้นจากด้านล่างจอ (`showModalBottomSheet`, ไม่ใช่ dialog กลางจอ — ตรงกับ pattern bottom sheet ที่ใช้อยู่แล้วทั้งแอปสำหรับ action list)
2. หัวข้อ sheet แสดง `targetLabel` ที่ส่งมา (เช่น "รายงานโพสต์นี้" / "รายงาน @username")
3. รายการ Category แบบ radio list (เลือกได้ 1 อัน): Spam, Scam, Harassment, Hate, Sexual Content, Violence, Privacy, Illegal Content, Copyright, Other — ข้อความไทยกำกับทุกอัน (ดู Components ด้านล่างสำหรับคำแปล)
4. เลือก "Other" → ช่องข้อความ (multiline, บังคับกรอก) เลื่อนปรากฏใต้รายการทันที — Category อื่นมีช่องข้อความเดียวกันแต่เป็น optional พร้อม label "รายละเอียดเพิ่มเติม (ถ้ามี)"
5. ปุ่ม "ส่งรายงาน" (เต็มความกว้าง, `Primary Button`) — disabled จนกว่าจะเลือก Category (และกรอกข้อความถ้าเป็น Other)
6. กดส่ง → แสดง loading บนปุ่ม (spinner แทนข้อความชั่วคราว, sheet ไม่ปิดจนกว่าจะได้ผลลัพธ์) → สำเร็จ → sheet ปิด + Snackbar "ส่งรายงานแล้ว ทีมงานจะตรวจสอบเร็วๆ นี้" (ที่ด้านล่างจอ, auto-dismiss)

Components:
- `DraggableScrollableSheet`/`showModalBottomSheet` พื้นผิวทึบ (`surfaceContainer`, ห้าม blur ตามกติกา Liquid Glass) มุมบนโค้ง `radiusLg` (16)
- Handle bar บาง ๆ กลางด้านบน sheet (มาตรฐาน bottom sheet ที่แอปใช้อยู่แล้ว)
- หัวข้อ (`titleMedium`) + ปุ่มปิด (`Icons.close`, มุมขวาบน, 44×44 touch target)
- Category list: แต่ละแถวเป็น `RadioListTile` หรือเทียบเท่า — ไอคอนวงกลม radio ซ้าย, ข้อความ Category กลาง (`bodyLarge`), ทั้งแถวกดได้ (ไม่ใช่แค่วงกลม) สูงไม่ต่ำกว่า 44px
- คำแปลไทยของแต่ละ Category (คงคำอังกฤษกำกับเล็กๆ ไว้ในวงเล็บเพื่อความชัดเจนกับทีม moderation ที่จะอ่านใน WYN-029): "สแปม (Spam)", "หลอกลวง (Scam)", "คุกคาม/กลั่นแกล้ง (Harassment)", "ความเกลียดชัง (Hate)", "เนื้อหาทางเพศ (Sexual Content)", "ความรุนแรง (Violence)", "ละเมิดความเป็นส่วนตัว (Privacy)", "ผิดกฎหมาย (Illegal Content)", "ละเมิดลิขสิทธิ์ (Copyright)", "อื่น ๆ (Other)"
- ช่องข้อความรายละเอียด: `TextField` multiline (3 บรรทัดเริ่มต้น, ขยายได้), placeholder ต่างกันตามบังคับ/ไม่บังคับ ("อธิบายเพิ่มเติม (จำเป็น)" ตัวหนา สี error ถ้าเป็น Other / "อธิบายเพิ่มเติม (ถ้ามี)" ปกติ)
- ปุ่ม "ส่งรายงาน" (`Primary Button` เต็มความกว้าง, `radiusMd`) วางเหนือ safe-area ด้านล่าง

Interactions:
- เลือก Category ใดๆ → ปุ่มส่งเปิดใช้งานทันที (ยกเว้น Other ที่ต้องรอข้อความไม่ว่างด้วย)
- Sheet ปิดได้ด้วยปุ่ม X, ปัดลง, หรือแตะพื้นหลังนอก sheet (ยกเลิกไม่ส่ง ไม่มี draft ค้าง)

States:
- **Default**: ยังไม่เลือก Category, ปุ่มส่ง disabled
- **Loading**: หลังกดส่ง — ปุ่มแสดง spinner, Category list/ช่องข้อความ disabled ชั่วคราว (กันกดซ้ำ)
- **Error**: ส่งไม่สำเร็จ (เช่น network) → sheet ไม่ปิด, แสดง inline error สีแดงเหนือปุ่ม "ส่งไม่สำเร็จ ลองอีกครั้ง" ปุ่มกลับมากดได้
- **Duplicate**: ถ้า entry point เปิด sheet ทั้งที่ target นี้เคยถูกรายงานไปแล้ว (edge case ปุ่มควรถูกซ่อนไปแล้วตาม Screen 2-6 แต่กันไว้สองชั้น) → sheet แสดงข้อความแทนฟอร์ม "คุณรายงานสิ่งนี้ไปแล้ว ทีมงานกำลังตรวจสอบ" พร้อมปุ่มปิดอย่างเดียว
- **Success**: sheet ปิด + Snackbar ยืนยัน (ดู User Flow ข้อ 6)

Responsive Behavior: sheet สูงตาม content จริง (ไม่ fix ความสูง) มี max-height ที่ scroll ได้ถ้าจอเตี้ย/มี soft keyboard เปิดอยู่ (ช่องข้อความ Other) — ทดสอบที่ textScale 130% ตามกติกา DS-008 ต้องไม่ overflow

Accessibility:
- ทุก Category row มี `Semantics` label อ่านครบ (ชื่อ Category + สถานะเลือก/ไม่เลือก)
- ปุ่มส่งมี `Semantics` label เปลี่ยนตามสถานะ ("ส่งรายงาน ปิดใช้งานจนกว่าจะเลือกหมวดหมู่" ตอน disabled)
- Contrast ทุกข้อความผ่าน AA ตาม DS-001 (ใช้ `onSurface`/`onSurfaceVariant` token ปกติ ไม่มีข้อความ Cyan/Orange เปล่าในหน้านี้)

Design Rules:
- ห้ามใช้ Cyan เป็นพื้นหลังของ sheet หรือพื้นที่กว้าง (ตาม DS-001 ข้อ 6) — sheet เป็น `surface`/`surfaceContainer` ปกติ, radio ที่ selected ใช้ Cyan เป็นแค่จุดวงกลมเล็ก
- ปุ่ม "ส่งรายงาน" ใช้สี Primary (Cyan พื้น + ตัวหนังสือดำ ตาม DS-001 3.1/3.2) ไม่ใช่สีแดง (การส่งรายงานไม่ใช่ destructive action ต่อตัวผู้ใช้เอง ต่างจากปุ่มลบ)
- ไม่แสดงตัวตนผู้รายงานที่ใดในหน้าจอนี้เลย (ไม่มีช่องกรอกชื่อ/แสดงชื่อ) ตรงตาม Product Requirement เรื่อง privacy

---

## Screen 2: Entry Point — `ViewProfileScreen` (โปรไฟล์ผู้ใช้อื่น)

Purpose: เพิ่มทางเข้ารายงาน User เข้า Profile ของคนอื่น ซึ่งปัจจุบัน (WYN-013) AppBar ของโปรไฟล์คนอื่นไม่มี action ใดๆ เลย

User Flow: เปิดโปรไฟล์คนอื่น → แตะไอคอน More ที่ AppBar → เมนูเปิดขึ้น → แตะ "รายงาน" → `ReportSheet` เปิด (`targetType: user`, `targetLabel: "รายงาน @username"`)

Components:
- เพิ่ม `IconButton` (`Icons.more_vert`) เข้า AppBar actions ของ `ViewProfileScreen` **เฉพาะเมื่อ `isOwnProfile == false`** (แทนที่ "ไม่มี action ใดๆ" เดิมของ WYN-013 — เดิมไม่มีเพราะตอนนั้นยังไม่มีฟีเจอร์ใดต้องใช้ ตอนนี้ Report ทำให้ต้องมี)
- เมนู More (bottom sheet action list แบบเดียวกับที่ `ClubPage` ใช้อยู่แล้ว WYN-014): รอบนี้มีแค่ 1 รายการ "รายงาน" — ออกแบบเผื่อพื้นที่ให้ WYN-027 (Block)/WYN-028 (Mute) เพิ่มรายการ "บล็อก"/"ปิดเสียง" เข้ามาต่อในเมนูเดียวกันภายหลัง โดยไม่ต้องรื้อโครงสร้างใหม่

Interactions: แตะ "รายงาน" ในเมนู → ปิดเมนู More ก่อน แล้วค่อยเปิด `ReportSheet` (ไม่ซ้อน sheet สองชั้นพร้อมกัน)

States: ถ้าเคยรายงาน user นี้ไปแล้วและยังไม่ปิดเคส → รายการเมนูแสดง "รายงานแล้ว" (สีเทา `onSurfaceVariant`, กดไม่ได้)

Responsive Behavior: เหมือน Screen 1

Accessibility: ปุ่ม More มี `Semantics` label "ตัวเลือกเพิ่มเติมสำหรับโปรไฟล์นี้" ขนาด 44×44

Design Rules: ไม่เพิ่ม action ใดในโปรไฟล์ตัวเอง (ยังคงมีแค่ปุ่ม logout ตามเดิมของ WYN-013 — คนไม่รายงาน/บล็อก/ปิดเสียงตัวเองได้)

---

## Screen 3: Entry Point — `DropDetailScreen`

Purpose: เพิ่มทางเข้ารายงาน Drop จากหน้ารายละเอียด

User Flow: เปิด Drop Detail → แตะไอคอน More ข้างปุ่มลบ (หรือแทนตำแหน่งเดิมถ้าไม่ใช่ Drop ของตัวเอง) → เมนู → "รายงานโพสต์" → `ReportSheet` (`targetType: drop`)

Components:
- **Drop ของตัวเอง**: แถวผู้โพสต์ยังคงมีแค่ปุ่มลบ (ถังขยะ) เหมือนเดิมทุกประการตาม WYN-005 — **ไม่เพิ่มปุ่ม More** (รายงานเนื้อหาตัวเองไม่ได้อยู่แล้ว)
- **Drop ของคนอื่น**: เพิ่ม `IconButton` (`Icons.more_vert`) ที่ตำแหน่งเดียวกับที่ปุ่มลบเคยอยู่ (มุมขวาของแถวผู้โพสต์) เปิดเมนู More ที่มีแค่ "รายงานโพสต์"

Interactions/States: เหมือน Screen 2 (duplicate-state, ปิดเมนูก่อนเปิด sheet)

Responsive/Accessibility: เหมือน Screen 1-2

Design Rules: ตำแหน่งไอคอนต้องไม่ทำให้แถวผู้โพสต์ล้น (`overflow`) — ทดสอบร่วมกับชื่อผู้ใช้ยาว ตามกติกา DS-008 (ปุ่มติดตามที่เคยแก้ overflow ในแถวเดียวกันมาแล้ว)

---

## Screen 4: Entry Point — Drop card ใน Home Feed / Search / Profile Grid

Purpose: ให้รายงาน Drop ได้โดยไม่ต้องเปิด Detail ก่อนเสมอไป ตาม Product Requirement

Components:
- **Home Feed card** (มี header เต็ม avatar+ชื่อ+เวลา ตาม WYN-007): เพิ่ม `IconButton` (`Icons.more_vert`) ที่ท้ายแถว header (ข้างเวลาโพสต์) — เฉพาะการ์ดที่ไม่ใช่ของตัวเอง — เปิดเมนู More เหมือน Screen 3
- **Grid tile แน่น** (Profile Drop grid ของ WYN-013, Search Drop tab ของ WYN-009 — ไม่มี header/avatar แสดงในตัว tile ตาม WYN-013): ไม่เพิ่มไอคอนถาวรบน tile (จะแน่นเกินไปและบัง thumbnail) — ใช้ **long-press** เปิด `ContextMenu`/bottom sheet เดียวกัน (pattern มาตรฐานของ mobile สำหรับ dense grid ไม่ใช่การลอก IG/TikTok เพราะเป็น interaction convention ทั่วไปของ OS ทั้ง iOS/Android)

Interactions:
- Home card: แตะ More → เมนู → "รายงานโพสต์"
- Grid tile: long-press (ค้างไว้) → haptic feedback สั้น (ถ้า platform รองรับ) → เมนูเด้งขึ้นจากตำแหน่งที่กด → "รายงานโพสต์"

States: เหมือน Screen 2 (duplicate-state ในเมนู)

Responsive Behavior: long-press ต้องไม่ชนกับ scroll gesture ของ grid (ใช้ threshold มาตรฐานของ `GestureDetector.onLongPress`ซึ่งแยกจาก scroll/tap อยู่แล้วโดย framework)

Accessibility: grid tile เพิ่ม `Semantics` action "รายงาน" เข้าไปใน `CustomSemanticsAction` เพื่อให้ผู้ใช้ screen reader (ที่ long-press ทำไม่ได้ในบาง context) เข้าถึง Report ได้ผ่านเมนู action ของ screen reader เอง (VoiceOver/TalkBack รองรับ custom action โดยไม่ต้อง gesture จริง)

Design Rules: ต้องไม่เพิ่ม visual clutter บน grid tile (ตามที่ WYN-013 ตั้งใจให้ tile โล่งเพื่อ scan ได้เร็ว) — long-press คือทางออกที่ไม่ขัดกับเจตนาเดิม

---

## Screen 5: Entry Point — Comment (Drop Comment / Club Post Comment)

Purpose: รายงาน Comment ได้ทั้งสองระบบด้วยรูปแบบเดียวกัน

Components: ทั้งสองระบบ (Drop comment ของ WYN-005, Club Post comment ของ WYN-014) ใช้แถว comment โครงสร้างเดียวกัน (avatar+ชื่อ+ข้อความ+เวลา+Like) — ไม่เพิ่มไอคอนใหม่ในแถว (แถวคอมเมนต์แน่นอยู่แล้วตามที่ DS-008 เพิ่งขยาย touch target ปุ่ม Like/Delete เป็น 44×44 ไปแล้ว เพิ่มไอคอนที่ 3 จะแน่นเกินไป)

Interactions: **long-press ที่ตัวแถวคอมเมนต์** (ไม่ใช่ที่ปุ่ม Like) → เปิดเมนู:
- คอมเมนต์ของตัวเอง → "ลบคอมเมนต์" (เหมือนเดิมทุกประการ ปุ่มถังขยะเดิมยังอยู่คู่กัน เมนูนี้เป็นทางลัดเสริมไม่ใช่แทนที่)
- คอมเมนต์ของคนอื่น → "รายงานคอมเมนต์" (`targetType: drop_comment` หรือ `club_post_comment` ตามบริบท)

States: เหมือน Screen 2

Accessibility: เพิ่ม `CustomSemanticsAction` "รายงานคอมเมนต์" ที่ระดับแถว เหมือน Screen 4 (กัน long-press เป็น gesture เดียวที่เข้าถึงได้)

Design Rules: ไม่แตะปุ่ม Like/Delete เดิมของคอมเมนต์เลย (ทั้งขนาดและตำแหน่ง) — เพิ่มแค่ gesture ใหม่ที่ตัวแถว

---

## Screen 6: Entry Point — Club / Club Post (ต่อยอดเมนู More ที่มีอยู่แล้ว)

Purpose: เปลี่ยนปุ่ม "รายงาน Club" ที่เป็น placeholder (WYN-014) ให้ทำงานจริง และเพิ่ม Report เข้าเมนู More ของ Club Post ที่เดิมซ่อนสำหรับคนไม่มีสิทธิ์

Components:
- **`ClubPage` เมนู More**: รายการ "รายงาน Club" (มีอยู่แล้วทุก persona ตาม WYN-014 line 51) — เปลี่ยนจาก placeholder เป็นเปิด `ReportSheet` จริง (`targetType: club`) ไม่ต้องแก้ position/label ใดๆ
- **`ClubPostCard` เมนู More**: เดิม "คนอื่นที่ไม่มีสิทธิ์ → เมนูว่างหรือไม่แสดงปุ่ม More เลย" (WYN-014) — **เปลี่ยนเป็น**: ทุกคนที่ไม่ใช่เจ้าของโพสต์เห็นปุ่ม More เสมอ อย่างน้อยมี "รายงานโพสต์" เป็นรายการเดียว (คนมีสิทธิ์ยังเห็น "ลบโพสต์"/"ปักหมุด" เพิ่มเข้ามาเหมือนเดิมตาม WYN-014 ไม่เปลี่ยน) เจ้าของโพสต์เองยังเห็นแค่ "ลบโพสต์" เหมือนเดิม (ไม่มีตัวเองในตัวเลือก Report)
- **Club Post Comment**: ใช้ pattern เดียวกับ Screen 5 เป๊ะ (long-press)

Interactions/States/Accessibility: เหมือน Screen 2/5

Design Rules: ไม่เปลี่ยนลำดับ/label ของรายการเดิมใน Club menu ทั้งสอง (Pin/Remove ของผู้มีสิทธิ์) — เพิ่ม "รายงาน" ต่อท้ายรายการเสมอ (อยู่ล่างสุดของเมนู ให้รายการที่มีผลกระทบสูงกว่าเช่นลบ/แบนอยู่ด้านบนตามที่ผู้มีสิทธิ์คุ้นเคยอยู่แล้ว)

---

## Handoff

ส่งต่อ AI Coding ตามลำดับที่แนะนำ (ลดความเสี่ยง regression):
1. `ReportSheet` component เดี่ยว ๆ ก่อน (Screen 1) — ยังไม่ต้อง wire เข้าจุดไหน ทดสอบแยกได้
2. Backend: ตาราง `reports` + RPC `submit_report(target_type, target_id, category, detail)` (validate target มีอยู่จริงตาม Requirement/Risk ของ Product Spec) + query เช็ค duplicate (`has_reported(target_type, target_id)`) ให้ทุก entry point เรียกใช้ก่อนแสดงปุ่ม/สถานะเมนู
3. Entry point เรียงตามความเสี่ยง regression จากต่ำไปสูง: `ClubPage` More menu (แค่เปลี่ยน placeholder → real, Screen 6) → `ViewProfileScreen` (เพิ่ม AppBar action ใหม่, Screen 2) → `DropDetailScreen` (Screen 3) → Comment long-press ทั้งสองระบบ (Screen 5) → Club Post More menu (Screen 6) → Home/Grid card (Screen 4, พื้นที่กว้างสุด เสี่ยง overflow มากสุด ทำท้ายสุด)
4. เก็บ regression test เดิมของทุกไฟล์ที่แตะ (โดยเฉพาะ `drop_detail_screen_test.dart`, `club_post_detail_screen_test.dart`, comment widget tests) ให้ผ่านหมดก่อนส่ง QA — ไม่แตะไฟล์ `pop_*`/`PopClipView`/`HomePopCard` เลยตามที่ระบุไว้ข้างต้น
