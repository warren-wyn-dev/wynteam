# Feature Request — WYN-123

Status: active — Design เสร็จแล้ว, **Coding ห้ามเริ่มจนกว่า WYN-115–118 เสร็จครบ**
Owner: AI Product Manager → AI Design

Feature: Club Channels — แบ่ง Club เป็นหลายห้อง/หัวข้อ แทนฟีดโพสต์รวมห้องเดียว (เฟส 1 ของ ".wyn/docs/product/wyn-club-discord-style-roadmap.md")

Goal: ทำให้ Club "รู้สึกมีชีวิต แบบ Discord" ตามที่ Founder ต้องการ — สมาชิกเห็นการสนทนาถูกจัดหมวดหมู่ชัดเจน (ประกาศ/พูดคุยทั่วไป/หัวข้อเฉพาะทาง) แทนที่จะปนกันในฟีดเดียวที่ไหลเร็วจนของสำคัญ (เช่นประกาศ Owner) จมหายไป — โดยไม่กลายเป็น "ฟีดซ้ำ" กับ Home Feed (Founder เน้นย้ำจุดนี้ตรงๆ)

Target User: สมาชิก/Owner/Admin ของ Club ที่มีเนื้อหาหลายประเภทปนกัน (เช่น Club มหาวิทยาลัยที่มีทั้งประกาศทางการ + พูดคุยเล่น + ซื้อขายของมือสอง) และ Founder เองที่ต้องการให้ Club เป็นจุดขายที่แตกต่างจาก Facebook Groups จริงจัง ไม่ใช่แค่หน้าตาคล้ายกัน

Problem: Club ปัจจุบัน (`public.club_posts`) เป็นตารางเดียวไม่มีการแบ่งหมวดหมู่ภายใน — ทุกโพสต์ (ประกาศสำคัญจาก Owner, พูดคุยเล่น, ถามซื้อขาย) ไหลรวมกันในฟีดเดียวเรียงตามเวลา ตรงกับปัญหาที่ WYN-116 (Club Re-engagement Notification) กำลังพยายามแก้อยู่แล้วบางส่วน (แจ้งเตือนโพสต์ใหม่/ประกาศ Pin) แต่ปัญหาการจัดหมวดหมู่ตัวฟีดเองยังไม่ถูกแตะ — Pinned Post (มีอยู่แล้ว) ช่วยได้แค่ 1-2 โพสต์ ไม่ใช่ทางออกสำหรับเนื้อหาที่มีหลายประเภทต่อเนื่อง

## Requirements

### R1 — Channel เป็นของ Club แต่ละอัน ไม่ใช่ระดับ global
Owner/Admin สร้าง/แก้ไข/ลบ/จัดเรียง Channel ภายใน Club ของตัวเองได้ — Channel มีอย่างน้อย: ชื่อ (เช่น "ประกาศ", "พูดคุยทั่วไป"), ไอคอน/emoji (ทางเลือก), ลำดับการแสดงผล

### R2 — ทุก Club ต้องมี Channel เริ่มต้นเสมอ (migration-safe)
Club ที่มีอยู่แล้วทั้งหมด (สร้างก่อน WYN-123) ต้องมี Channel เริ่มต้น 1 อัน (เช่น "ทั่วไป") ที่โพสต์เดิมทั้งหมดถูกย้ายเข้าไปอัตโนมัติ — **ห้ามมีโพสต์เดิมหายไปหรือไม่มี Channel สังกัด** Club ใหม่ที่สร้างหลัง WYN-123 ต้องมี Channel เริ่มต้นให้อัตโนมัติตอนสร้าง (ไม่บังคับให้ Owner ต้องมาสร้างเองก่อนโพสต์ได้)

### R3 — โพสต์ผูกกับ Channel เดียวเสมอ (ไม่ multi-channel)
โพสต์ใหม่ในหน้า Club ต้องเลือก Channel ที่จะโพสต์ (ค่าเริ่มต้น = channel ที่กำลังเปิดดูอยู่) — โพสต์ 1 อันอยู่ได้แค่ 1 Channel เดียว ไม่ต้องรองรับ cross-post ข้าม Channel ในรอบนี้ (เก็บ scope ให้เล็ก)

### R4 — Owner/Admin ล็อก Channel ได้ (read-only สำหรับสมาชิกทั่วไป)
Channel บางประเภท (เช่น "ประกาศ") ควรตั้งเป็น "เฉพาะ Owner/Admin โพสต์ได้ สมาชิกอ่านได้อย่างเดียว" ได้ — ตรงกับ pattern การใช้งานจริงของ Discord's announcement channel และตอบโจทย์ "ประกาศสำคัญจมหาย" ที่เป็น pain point หลัก

### R5 — ไม่กระทบ Home Feed / "จาก Club ของคุณ" tab
Home Feed's "From Your Clubs" ยังคงรวมโพสต์จากทุก Channel ของทุก Club ที่เข้าร่วมเหมือนเดิม (แค่เพิ่ม label/badge บอกว่าโพสต์นี้มาจาก Channel ไหนของ Club ไหน) — **Home Feed ไม่ต้องมีแนวคิด Channel เป็นของตัวเอง** นี่คือจุดที่ตอบ concern ของ Founder โดยตรง ("อย่าให้ Club กลายเป็นฟีดซ้ำกับ Home") — Channel คือการจัดระเบียบ**ภายใน**ประสบการณ์ Club เท่านั้น ไม่ใช่มุมมองใหม่ใน Home

### R6 — Notification/Pin ทำงานต่อ Channel
Pinned Post (มีอยู่แล้ว) ต้อง pin ต่อ Channel ไม่ใช่ทั้ง Club (ประกาศที่ pin ใน #ประกาศ ไม่ควรไปทับ pin ของ #ซื้อขาย) — WYN-116 (Re-engagement Notification, ถ้ายังไม่ deploy ตอนเริ่มงานนี้) ต้องตรวจสอบว่ายังทำงานถูกต้องเมื่อโพสต์มาจาก Channel ใดก็ได้ ไม่ผูกกับ assumption "1 Club = 1 stream"

## Acceptance Criteria

1. Owner เปิด Club ที่มีอยู่แล้ว (สร้างก่อน WYN-123) → เห็นโพสต์เดิมทั้งหมดอยู่ใน Channel เริ่มต้น "ทั่วไป" ครบไม่มีหาย
2. Owner สร้าง Channel ใหม่ชื่อ "ประกาศ" ตั้งเป็น Owner/Admin-only → สมาชิกทั่วไปเห็น Channel นี้ในรายการแต่กดโพสต์ไม่ได้ (ปุ่มโพสต์หาย/disable), Owner/Admin โพสต์ได้ปกติ
3. สมาชิกทั่วไปสลับไปมาระหว่าง Channel ต่างๆ ภายใน Club เดียว เห็นโพสต์แยกกันถูกต้องตาม Channel
4. โพสต์ใหม่ที่สร้างจาก Channel "ซื้อขาย" ไม่ไปปรากฏใน Channel "ประกาศ"
5. Home Feed's "จาก Club ของคุณ" ยังรวมโพสต์จากทุก Channel ของทุก Club เหมือนเดิม ไม่มีอะไรหายไปจาก Home
6. Pin โพสต์ใน Channel หนึ่งไม่กระทบ pin ของอีก Channel ใน Club เดียวกัน
7. ผู้ใช้ที่ยังไม่เข้าร่วม Club (กรณี Public) เข้าดู Channel สาธารณะได้ตามสิทธิ์เดิมของ Club privacy (ไม่มี permission model ใหม่ระดับ Channel นอกเหนือจาก "ใครโพสต์ได้" ตาม R4)

## Dependencies

- WYN-014 (Club Core) — ตาราง `club_posts`/`club_members`/`club_role()` ที่มีอยู่แล้วทั้งหมด
- WYN-116 (Re-engagement Notification) — ควรเสร็จ deploy ก่อนเริ่ม เพื่อไม่ต้องแก้ trigger/notification logic 2 รอบซ้อนกัน
- ต้อง migration ข้อมูลเดิม (`club_posts` ทุกแถวต้องได้ `channel_id` ที่ชี้ไป Channel เริ่มต้นของ Club ตัวเอง) — งานนี้มีความเสี่ยงต้องระวังตาม `.wyn/docs/engineering/checklist-db-migration-touching-a-view.md` ถ้ามี view ที่ query `club_posts` โดยตรง (ต้องตรวจสอบก่อนเริ่ม Coding)

## Priority

**P2** — Founder ยืนยันชัดเจนว่าให้ทำ**หลัง** WYN-115–118 เสร็จครบ ไม่ใช่แทรกกลางคัน (ดู roadmap doc)

## Risks

- **Migration ข้อมูลเดิม**: ทุกแถวใน `club_posts` ที่มีอยู่แล้วต้อง backfill `channel_id` — ถ้าพลาดจะมีโพสต์ "ลอย" ไม่มี Channel ปรากฏ กระทบ Club ที่มีอยู่จริงทันที ต้องทดสอบ migration กับข้อมูลจำลองที่มีโพสต์อยู่ก่อนเสมอ (ไม่ใช่แค่ Club ว่างเปล่า) ตาม pattern บทเรียน WYN-103 (`.wyn/learning/MISTAKES.md`)
- **Complexity เพิ่มขึ้นจริง**: Founder brief ต้นฉบับ (`wyn-club-founder-brief.md` ข้อ 19) เตือนไว้ตรงๆ ว่า "อย่าใส่ฟีเจอร์อนาคตจนทำให้ระบบซับซ้อนเกินไป" — Channel เพิ่ม concept ใหม่ที่ทุกหน้าจอ Club (Create Post, Pin, Notification, Search) ต้องรู้จัก ต้องรอบคอบไม่ให้ UI รกเกินไปสำหรับ Club เล็กๆ ที่ไม่ต้องการหลาย Channel เลย (ควรออกแบบให้ default ใช้ Channel เดียวได้แนบเนียนโดยไม่รู้สึกเทอะทะ)
- **ทับซ้อนกับ WYN-116/117**: ต้องตรวจสอบให้ดีว่า Re-engagement Notification (WYN-116) และ Owner Insights (WYN-117) ที่อาจกำลังทำ/เสร็จไปแล้วตอนถึงคิวนี้ ไม่ได้ hardcode สมมติฐาน "1 Club = 1 stream ของโพสต์" ไว้ในโค้ด ต้องอ่านโค้ดจริงตอนเริ่มงาน ไม่ใช่เดาจากตอนที่เขียนเอกสารนี้

## Recommendation

เริ่ม AI Design วางแผน UX/UI ของ Channel switcher (จะวางไว้ตรงไหนในหน้า Club — แถบ tab ด้านบน/side drawer แบบ Discord/dropdown) ได้ตอนนี้เลยตามที่ Founder อนุมัติ แต่**ระบุใน design doc ให้ชัดว่า AI Coding ต้องรอ WYN-115–118 เสร็จก่อนเริ่ม** และก่อนเริ่ม Coding จริงต้องอ่านโค้ด Club ปัจจุบัน (รวม WYN-115/116/117/118 ที่ deploy ไปแล้ว) ใหม่อีกรอบ ไม่ใช่เชื่อ assumption จากตอนวางแผนนี้เพียงอย่างเดียว

## Handoff (Product → Design)

ส่งต่อ **AI Design** — ออกแบบ UX/UI เต็มรูปแบบของ Club Channels ได้ทันที (Coding รอคิวตามที่ระบุไว้)

---

## AI Design — ผลงาน (2026-09-06)

Design เต็มรูปแบบอยู่ที่ `.wyn/docs/design/wyn-123-club-channels.md` (6 Screen: Channel Switcher ในหน้า Club / จัดการ Channel แบบ List+Reorder / สร้าง-แก้ไข Channel / เลือก Channel ปลายทางตอนโพสต์ / มุมมองสมาชิกใน Channel แบบ announcement-only / Pin ต่อ Channel ที่ได้มาฟรีจาก R3)

**สรุปสำคัญ**:
- ทุก component reuse ของเดิมในโค้ด Club ปัจจุบัน 100% (`ActionSheetRow`/`ActionSheetBody`, pill chip แบบเดียวกับ header เดิม, `EmptyStateBlock` language, optimistic-update pattern เดิม) — ไม่มี component ใหม่
- Club ที่มี Channel เดียว: ไม่ render Channel switcher เลย (ไม่ใช่ซ่อน) — หน้าตาเหมือนก่อน WYN-123 ทุกพิกเซล ตอบโจทย์ที่ Product เตือนเรื่องความเทอะทะโดยตรง
- **แก้ไขข้อมูลสำคัญ**: `ds-001-color-system.md` (dark+Cyan) ล้าสมัยแล้ว — แอปจริงเป็น **Sapphire `#1B3A6B`** accent เดียว, light-only theme, system font (ดูรายละเอียด/ที่มาในหัวเอกสาร design doc) — Coding ต้องอ้างอิงโค้ดจริงใน `app/lib/core/design/` ไม่ใช่ DS-001
- **ข้อควรระวังที่ Design เพิ่มเอง นอกเหนือจาก Requirements เดิม** (ต้องยืนยันกับ Product ก่อน Coding เริ่มจริง): (1) Channel เริ่มต้นห้ามตั้งเป็น announcement-only เด็ดขาด กัน Club ไม่มีที่ให้สมาชิกทั่วไปโพสต์เลย (2) ลบ channel ที่ไม่ใช่ default ควรย้ายโพสต์เข้า default channel อัตโนมัติ ไม่ลบโพสต์ — เป็นข้อเสนอ ไม่ใช่มติสุดท้าย

**Handoff (Design → Coding)**: **ห้ามเริ่มจนกว่า WYN-115–118 จะเสร็จครบ** ตามที่ Product ระบุไว้ — เมื่อถึงคิวจริง อ่านโค้ด Club ปัจจุบันใหม่ทั้งหมดก่อน (รวม WYN-115/116/117/118 ที่ deploy แล้วตอนนั้น) ไม่ใช่เชื่อ assumption จากตอนเขียนเอกสารนี้ ตรวจ WYN-116/117 ว่า hardcode "1 Club = 1 stream" ไว้ที่ไหนบ้าง แล้วยืนยัน 2 จุดที่ Design เสนอเองกับ Product ก่อนเขียน schema จริง
