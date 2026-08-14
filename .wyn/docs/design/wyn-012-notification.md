# Design Spec — WYN-012: Notification

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-012-notification.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: แถวของ `FollowListScreen` (WYN-008/013, infinite-scroll list), ไอคอน entry point ข้าง search bar ของ Home (WYN-009), `AvatarCircle`, `SearchStateMessage`-style empty state (WYN-009)

## ทิศทางภาพรวม: ไอคอนกระดิ่งเป็นเพื่อนบ้านของ search bar ไม่ใช่แทนที่มัน

Home แถวบนสุดเดิมมีแค่ search bar เต็มความกว้าง — เปลี่ยนเป็น `Row` สองส่วน: search bar (`Expanded`, เหมือนเดิมทุกประการ) + ไอคอนกระดิ่งอยู่ขวาสุด ไม่ใช่การเพิ่ม `AppBar` ใหม่ทั้งอัน (ยิ่งเพิ่มความสูง/ความซับซ้อนโดยไม่จำเป็น เมื่อวางเป็น Row เดียวก็พอ)

---

## Screen 1: Home — ไอคอนกระดิ่ง + Badge

Components:
- แถวบนสุดของ Home เปลี่ยนจาก `_buildSearchBar` เดี่ยว ๆ เป็น `Row(children: [Expanded(child: search bar เดิม), SizedBox(width: 8), ไอคอนกระดิ่ง])`
- ไอคอนกระดิ่ง: `IconButton(icon: Icons.notifications_outlined)` ขนาดเดียวกับปุ่ม icon อื่นในแอป — **ไม่มีพื้นหลังวงกลม/pill แบบ search bar** (แค่ icon เปล่า ๆ กดได้ ตรงตาม convention ปุ่ม icon เดี่ยวทั่วแอป เช่น ปุ่ม logout ใน `ViewProfileScreen`)
- Badge: วงกลมเล็กสี Primary Blue มุมขวาบนของไอคอน แสดงจำนวนที่ยังไม่อ่าน — **ไม่แสดงเลยถ้าจำนวนเป็น 0** (ไม่ใช่วงกลมว่างเปล่า) แสดงตัวเลขจริงถ้า 1-9 และ **"9+"** ถ้ามากกว่า 9 (ไม่ใช่ "99+" — badge เล็กมาก ตัวเลข 2 หลักขึ้นไปจะล้นวงกลม ตัวเลขหลักเดียว+"+" พอสื่อความหมาย "เยอะจนไม่ต้องนับ" แล้ว)
- Semantics: `Semantics(label: 'การแจ้งเตือน มี $count รายการที่ยังไม่อ่าน', button: true)` เมื่อมี unread, `Semantics(label: 'การแจ้งเตือน', button: true)` เมื่อไม่มี

Interaction: แตะไอคอนกระดิ่ง → เปิด Screen 2

---

## Screen 2: `NotificationListScreen`

Purpose: รายการ notification ทั้งหมด เรียงใหม่สุดก่อน

Components: **โครงสร้างเดียวกับแถวของ `FollowListScreen` ทุกประการ** (avatar 20px ซ้าย + เนื้อหาแบบ Column ขวา + ทั้งแถวเป็น `InkWell`) แต่เปลี่ยนเนื้อหาฝั่งขวาจาก "ชื่อ+@username" เป็น "ข้อความ notification + เวลา":
- บรรทัดบน: ข้อความเต็มประโยคภาษาไทย รวมชื่อผู้กระทำในตัว (ไม่ใช่แยกชื่อเป็นตัวหนา+ข้อความสีเทาแบบ IG) — เช่น "น้ำฝน ถูกใจ Drop ของคุณ"
  - Like Drop: "{ชื่อ} ถูกใจ Drop ของคุณ"
  - Like Pop: "{ชื่อ} ถูกใจ Pop ของคุณ"
  - Comment Drop: "{ชื่อ} แสดงความคิดเห็นใน Drop ของคุณ"
  - Comment Pop: "{ชื่อ} แสดงความคิดเห็นใน Pop ของคุณ"
  - Follow: "{ชื่อ} เริ่มติดตามคุณ"
- บรรทัดล่าง: เวลาแบบ relative time (ดูเหตุผลด้านล่าง) สีเทา (`colorScheme.outline`) ขนาดเล็กกว่า

**Relative time — เริ่มใช้ครั้งแรกในโปรเจกต์นี้ที่ WYN-012** (ต่างจาก Drop/Pop ที่ WYN-005 ตัดสินใจข้ามไปเป็น Minor เพราะไม่กระทบ Acceptance Criteria): เหตุผลที่ต่างกัน — content post (Drop/Pop) ความใหม่ไม่ใช่สาระสำคัญของการดู (ดูรูป/คลิปได้ปกติไม่ว่าโพสต์เมื่อไหร่) แต่ notification ทั้งหมดคือเรื่อง "เพิ่งเกิดอะไรขึ้น" โดยธรรมชาติ — ไม่มี relative time = ต้องคำนวณเองว่า "5:32 PM" คือเมื่อกี้หรือเมื่อวาน ซึ่งขัดกับจุดประสงค์ของหน้าจอนี้โดยตรง — ระดับความละเอียด:
- < 1 นาที: "เมื่อสักครู่"
- < 60 นาที: "X นาทีที่แล้ว"
- < 24 ชั่วโมง: "X ชั่วโมงที่แล้ว"
- < 7 วัน: "X วันที่แล้ว"
- ≥ 7 วัน: วันที่แบบเต็ม (เช่น "14/8/2026")

**Unread vs read — visual distinction**: แถวที่ยังไม่อ่านมีพื้นหลัง tint สี Primary Blue อ่อนมาก (`colorScheme.primaryContainer` หรือเทียบเท่าที่ opacity ต่ำ) แถวที่อ่านแล้วพื้นหลังปกติ (ขาว/พื้นหลัง default) — เป็น convention ทั่วไปของ inbox/notification list (เช่น อีเมล) ไม่ใช่การลอก layout เฉพาะของ IG/TikTok — **ไม่ใช้ตัวหนา/จุดสีที่มุมแบบ IG** เพื่อไม่ให้ซ้ำ pattern เฉพาะของแอปคู่แข่ง พื้นหลัง tint สื่อความหมายได้ชัดเจนพอในตัวเอง

**Mark-as-read timing**: เรียก mark-all-as-read ทันทีที่เปิดหน้าจอสำเร็จ (fetch เสร็จ) ตรงตาม Product Requirement — **แต่ visual unread state ของแต่ละแถวคำนวณจาก snapshot ตอน fetch ครั้งแรกเท่านั้น ไม่ re-render ตาม state ใหม่ที่เพิ่งถูก mark ระหว่างที่ผู้ใช้ยังอยู่ในหน้านี้** (เหตุผล: ถ้า re-render ทันทีที่ mark-as-read สำเร็จ พื้นหลัง tint ของทุกแถวจะหายพร้อมกันทันทีที่เปิดหน้า ทำให้ผู้ใช้ไม่มีโอกาสเห็นเลยว่าอันไหน "ใหม่" ระหว่างที่กำลังดู — เก็บ unread flag ไว้ใน state ของ Flutter widget เอง แยกจาก DB state ที่ถูกอัปเดตไปแล้วเบื้องหลัง) — Badge ที่ไอคอนกระดิ่งบน Home จะเป็น 0 ทันทีที่กลับมาที่ Home (เพราะนับจาก DB สดตอนนั้น) แต่แถวใน `NotificationListScreen` เองยังคง highlight ให้เห็นระหว่างที่อยู่ในหน้านั้น

Empty state: ไอคอน `Icons.notifications_none` (56px, `colorScheme.outline` — มิเรอร์ `SearchStateMessage` ของ WYN-009) + ข้อความ "ยังไม่มีการแจ้งเตือน" + บรรทัดรองสีเทา "เมื่อมีคนถูกใจ แสดงความคิดเห็น หรือติดตามคุณ จะเห็นที่นี่"

Interactions:
- แตะแถว Like/Comment บน Drop → เปิด `DropDetailScreen` ของ Drop นั้น
- แตะแถว Like/Comment บน Pop → เปิด `PopSingleClipScreen` ของ Pop นั้น
- แตะแถว Follow → เปิด `ViewProfileScreen` ของผู้ follow

Accessibility: แต่ละแถวมี `Semantics(label: '<ข้อความเต็ม> <เวลา>${ยังไม่อ่าน ? " ยังไม่ได้อ่าน" : ""}', button: true)`

---

## Design Rules

- ไอคอนกระดิ่งไม่มีพื้นหลัง pill (ต่างจาก search bar) — สื่อว่าเป็นปุ่ม utility เดี่ยว ๆ ไม่ใช่ input field
- Badge ตัวเลขไม่แสดงเมื่อเป็น 0, cap ที่ "9+" ไม่ใช่ "99+"
- Unread indicator เป็นพื้นหลัง tint เท่านั้น ไม่ใช้ bold text/จุดสีมุมแบบ IG
- Relative time เริ่มใช้ที่หน้านี้เป็นจุดแรกในแอป ด้วยเหตุผลเฉพาะของ notification (ไม่ใช่ retroactive เปลี่ยน Drop/Pop เดิม)

Handoff: AI Coding —
1. Database: สร้างตาราง `notifications` (recipient_id, actor_id, type, drop_id nullable, pop_id nullable, is_read, created_at) + trigger บน `drop_likes`/`pop_likes`/`drop_comments`/`pop_comments`/`follows` (`AFTER INSERT`) — self-notification guard ใน trigger function เอง, index บน `(recipient_id, is_read)`
2. `NotificationRepository` ใหม่ — `fetchNotifications({page})`, `countUnread()`, `markAllAsRead()`
3. `NotificationListScreen` ใหม่ (reuse `FollowListScreen` structure) + ไอคอนกระดิ่ง+badge ใน `home_feed_screen.dart`
4. เขียน regression test ครอบคลุม: self-notification guard ทุก content type, mark-as-read ไม่ลบ unread highlight ระหว่างอยู่ในหน้า, badge count ถูกต้อง, tap แต่ละประเภทไปถูกหน้า, relative time แสดงถูกต้องทุกช่วง
5. ต้อง QA & Security ตรวจสอบก่อนอนุมัติ — เน้น trigger ไม่ทำให้ insert เดิม (Like/Comment/Follow) fail/ช้าลง และ self-notification guard ทำงานจริงทุก content type

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-2 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-012-notification.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
