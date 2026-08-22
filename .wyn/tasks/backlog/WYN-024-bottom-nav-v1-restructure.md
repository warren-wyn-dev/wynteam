# Product Task — WYN-024

Status: backlog — พร้อมส่ง AI Design
Owner: AI Product Manager → AI Design → AI Coding

Feature: Bottom Navigation V1.0.0 Restructure — ถอด Pop/ZOKY ออกจาก Bottom Nav, เพิ่ม Search และ Notifications เป็น tab

Goal: ปรับโครงสร้าง Bottom Navigation ของแอป `app/` ให้ตรงกับ WYN V1.0.0 Master Spec (Section 34): 🏠 Home · 🔍 Search · ＋ Drop · 🔔 Notifications · 👤 Profile — เป็นงานแรกของ V1.0.0 เพราะทุกฟีเจอร์ที่จะเพิ่มต่อจากนี้ (Phase 1-8 ตาม `.wyn/docs/product/wyn-v1.0.0-roadmap.md`) อยู่ภายใต้โครง nav นี้

Target User: ผู้ใช้ WYN Social ทุกคน

Problem: Bottom Nav ปัจจุบันมี 5 tab คือ Home/Drop/Pop/ZOKY/Profile — Search เป็นแค่ search bar ใน Home (WYN-009), Notification เป็นไอคอนกระดิ่งข้าง search bar (WYN-012) ไม่ใช่ tab แยก — Founder ยืนยันแล้ว (2026-08-22) ว่า Pop และ ZOKY ไม่อยู่ใน scope V1.0.0 (Pop → V3, Shop/Marketplace → V2) จึงต้องถอดออกจาก Bottom Nav โดยไม่ลบโค้ด/database

Requirements:

R1. Bottom Nav ใหม่ 5 ตำแหน่ง: Home / Search / Drop (ปุ่ม "+" กึ่งกลาง เปิดหน้าสร้าง Drop ตรง ไม่ใช่ tab ที่มี state ค้างไว้) / Notifications / Profile
R2. ถอด Pop ออกจาก Bottom Nav ทั้งหมด — **ห้ามลบ** `app/lib/features/pop/`, ตาราง `pops`/`pop_likes`/`pop_comments`, หรือ storage bucket ที่เกี่ยวข้อง — ยังไม่มีทางเข้าถึง Pop จาก UI ปกติอีกต่อไปจนกว่าจะมีคำสั่ง V3
R3. ถอด ZOKY ออกจาก Bottom Nav ของ `app/` เท่านั้น — **ห้ามแตะ** `seller_app/` เลย (แอปแยก ไม่เกี่ยวกับ Bottom Nav ของ `app/`) — ห้ามลบโค้ด `app/lib/features/zoky/`, ตาราง ZOKY/SELLER ทั้งหมด, หรือ route ที่ deep-link เข้า ZOKY (ถ้ามีจุดอื่นอ้างอิง เช่น จาก Search/Profile ต้องตรวจสอบและปิดทางเข้าให้สอดคล้องกัน ไม่ทิ้ง dead link)
R4. ย้าย Search จาก search bar ใน Home ไปเป็น tab แยก — หน้า `SearchScreen` เดิม (WYN-009) reuse ตรง ๆ ไม่ต้องเขียนใหม่ Home ไม่มี search bar อีกต่อไป
R5. ย้าย Notification จากไอคอนกระดิ่งใน Home ไปเป็น tab แยก — หน้า `NotificationListScreen` เดิม (WYN-012) reuse ตรง ๆ ไม่ต้องเขียนใหม่ badge unread เดิมต้องยังทำงานถูกต้องบน tab icon
R6. ปุ่ม Drop ("+") กึ่งกลาง nav เปิดหน้า `CreateDropScreen` เดิมตรง ๆ (ไม่สร้าง flow ใหม่) ไม่ต้องมี state ค้างเหมือน tab อื่น (คล้ายปุ่มสร้างโพสต์ของแอปโซเชียลทั่วไปที่ไม่ใช่ "หน้าจอ" แต่เป็น action)
R7. ไม่แตะ/ไม่ลบตาราง DB ใด ๆ (Pop, ZOKY, SELLER ทั้งหมดยังอยู่ใน schema.sql) — เป็นแค่ UI-layer change ล้วนๆ

Acceptance Criteria:
- [ ] Bottom Nav แสดง 5 ตำแหน่งตรงตาม R1 เป๊ะ ไม่มี Pop/ZOKY tab เหลืออยู่
- [ ] แตะ Search tab เปิด `SearchScreen` เดิมทำงานปกติทุกฟังก์ชัน (User/Drop/Pop-content-still-searchable-if-existing/Hashtag/Club tab ภายในหน้า Search ไม่ต้องแก้)
- [ ] แตะ Notifications tab เปิด `NotificationListScreen` เดิม unread badge sync ถูกต้อง
- [ ] แตะปุ่ม Drop "+" เปิด `CreateDropScreen` แล้วกลับมา Home tab เดิม (ไม่ค้างอยู่ที่ "Drop tab" เพราะไม่มี tab นั้นแล้ว)
- [ ] ไม่มี dead link เหลือที่ชี้ไป Pop/ZOKY จากหน้าจออื่น (ตรวจ Profile/Search/Home ทุกจุดที่เคย deep-link)
- [ ] Pop/ZOKY โค้ดและ route ยังคอมไพล์ผ่าน ไม่ถูกลบ (สามารถ manual-navigate เข้าถึงได้ถ้าจำเป็นสำหรับ debug แต่ไม่ผ่าน UI ปกติ)
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ Home/Drop/Search/Notification/Follow/Club เดิมทั้งหมด

Dependencies: ไม่มี — เป็นงานลำดับแรกของ V1.0.0 Roadmap (Phase 0)

Priority: สูงสุด — บล็อกงานอื่นทุก Phase เพราะเป็นโครง navigation ที่ทุกฟีเจอร์ใหม่จะต้องอิงตาม

Risks: ต่ำ — reuse หน้าจอเดิมทั้งหมด (Search/Notification/CreateDrop) ไม่มี schema change ความเสี่ยงหลักอยู่ที่จุด deep-link ที่อาจตกหล่น (ต้อง grep ให้ครบทุกจุดที่ reference Pop/ZOKY route)

Recommendation: เริ่มได้ทันที ทำคู่ขนานกับ DS-009 (Design comparison) ได้เพราะเป็นคนละเรื่อง (โครงสร้าง nav vs สี) — แนะนำให้ AI Design ตัดสินใจ icon/layout ของปุ่ม Drop "+" ตรงกลาง (elevated FAB-style vs regular tab icon) และตำแหน่ง badge ของ Notifications tab

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ Bottom Nav ใหม่ตาม R1-R6 ก่อนส่ง AI Coding
