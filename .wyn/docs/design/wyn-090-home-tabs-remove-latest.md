# Design Spec — WYN-090: Home Feed-mode Tabs — ตัด "ล่าสุด" ออก

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-090.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/home/presentation/home_feed_screen.dart` (`_HomeFeedMode` enum, `_buildFeedModeToggle()`, `_fetchPage()`)
Pattern ที่มีอยู่แล้ว: `.wyn/docs/design/wyn-073-home-layout-tabs-restyle.md` (สไตล์แท็บปัจจุบัน — text tab, rainbow underline indicator, ไม่มีกรอบ) — งานนี้ไม่แตะสไตล์เลย แค่ลด jumlah แท็บจาก 4 เหลือ 3

## Audit ก่อนออกแบบ (ปิด Risk R1 ของ Product spec)

Grep `_HomeFeedMode.latest` ทั้ง repo เจอ **3 จุดเท่านั้น ทั้งหมดอยู่ในไฟล์เดียว** (`home_feed_screen.dart` บรรทัด 254, 779, 785) — ไม่มี route/deep-link/argument จากที่อื่นในแอปที่ระบุแท็บ "ล่าสุด" ตรงๆ เลย (ไม่มี `initialFeedMode`/parameter ที่ caller ไหนส่งเข้ามา) — **สรุป: ไม่มี deep-link ค้างที่จะพังจากการตัดแท็บนี้ออก** ยืนยันตาม Risk R1 ที่ Product task ขอให้เช็คก่อน

`HomeRepository.fetchFeed()` (chronological, method ที่ `latest` case เรียกอยู่) **ไม่ต้องลบ** — เป็น method ที่มีประโยชน์ทั่วไป อาจถูกใช้ที่อื่นในอนาคต/เป็น fallback การลบเฉพาะ UI path ที่เรียกมันจากแท็บพอ ไม่ต้องแตะ repository layer

---

Screen: Home — Feed-mode toggle (แถบแท็บใต้ Header, เหนือ `NewPostsPill`)

Purpose: ลดจาก 4 แท็บเหลือ 3 แท็บตามที่ Founder ระบุ ("สำหรับคุณ,ติดตาม,Club ของคุณ" อยากให้มีแค่นี้)

User Flow: เปิด Home → เห็น 3 แท็บ (สำหรับคุณ / ติดตาม / จาก Club ของคุณ) → ค่าเริ่มต้นยังเป็น "สำหรับคุณ" เหมือนเดิม (ไม่เปลี่ยน default) → สลับแท็บทำงานเหมือนเดิมทุกประการ

Components:
- ลบ `_HomeFeedMode.latest` ออกจาก enum (`app/lib/features/home/presentation/home_feed_screen.dart:32`) — เหลือ `forYou`, `following`, `fromYourClubs`
- ลบ entry `_HomeFeedMode.latest` ออกจาก tabs list (บรรทัด ~779) และออกจาก `labels` map (บรรทัด ~785, `'ล่าสุด'`)
- ลบ `case _HomeFeedMode.latest:` ออกจาก `_fetchPage()`'s switch (บรรทัด ~254)
- **ลำดับแท็บที่เหลือคงเดิมเป๊ะ** (ไม่สลับตำแหน่ง): สำหรับคุณ → ติดตาม → จาก Club ของคุณ — ตรงกับข้อความที่ Founder เรียงไว้เอง ("สำหรับคุณ,ติดตาม,Club ของคุณ")

Interactions: แตะแท็บใดก็ตามยังคง `setState(_feedMode = ...)` เหมือนเดิมทุกประการ (ไม่แตะ logic การโหลด/pagination ของ 2 แท็บที่เหลือ) — Underline indicator (rainbow gradient, `wyn-073`) เลื่อนไปหาแท็บที่กดเหมือนเดิม ไม่มีการเปลี่ยน animation

States: ไม่มี state ใหม่ — Default tab ที่เลือกตอนเข้าหน้ายังเป็น `_HomeFeedMode.forYou` เหมือนเดิม (ไม่เปลี่ยนค่าเริ่มต้น เพราะ Founder ไม่ได้ขอให้เปลี่ยน แค่ขอตัดแท็บ)

Responsive Behavior: 3 แท็บกว้างน้อยกว่า 4 แท็บเดิม จึงมีพื้นที่เหลือมากขึ้นใน `SingleChildScrollView` แนวนอนที่ห่ออยู่แล้ว (ยิ่งไม่มีปัญหา overflow กว่าเดิม ไม่ใช่ความเสี่ยงใหม่) — ไม่ต้องทดสอบ 360px ซ้ำเพราะเป็นการลด element ไม่ใช่เพิ่ม

Accessibility: ไม่มีการเปลี่ยนแปลง Semantics pattern ของแท็บที่เหลือ — Semantics label เดิม (ชื่อโหมด + สถานะ selected) คงอยู่ครบสำหรับ 3 แท็บที่เหลือ

Design Rules: ห้ามเปลี่ยนสไตล์ของแท็บที่เหลือ (ยังเป็น text tab ไม่มีกรอบ, rainbow underline indicator ตาม `wyn-073`/DS-009) — งานนี้คือการลบ element เดียว ไม่ใช่ visual redesign

Handoff: AI Coding — แก้ไฟล์เดียว `app/lib/features/home/presentation/home_feed_screen.dart` (3 จุดที่ระบุข้างบน) — เขียน/แก้ widget test ยืนยันว่า `find.text('ล่าสุด')` เป็น `findsNothing` และแท็บที่เหลือ 3 อันยังทำงานถูกต้อง (สลับแท็บ/โหลดข้อมูลของ "สำหรับคุณ"/"ติดตาม"/"จาก Club ของคุณ") — รัน `flutter analyze`/`flutter test` เต็ม suite ยืนยันไม่มี regression กับ `home_feed_screen_test.dart`/`root_shell_test.dart`

**สถานะ: พร้อมขึ้นโค้ดทันที** — ไม่มีภาพอ้างอิงที่ขาด ไม่มี dependency ที่บล็อก
