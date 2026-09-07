# Design Task — WYN-140b

Status: active — Design spec เสร็จ, พร้อมส่งต่อ AI Coding (รอ WYN-140a deploy ก่อนตามลำดับ priority)
Owner: AI Design → AI Coding
Priority: 2 ของ 3
Screen: Club Page, Chat Inbox, Conversation Screen, Notification List — ยืนยันแล้วว่ายังใช้ `Center(CircularProgressIndicator())` เปล่าๆ ตอนโหลดครั้งแรก
Purpose: ลดความรู้สึก "ค้าง" ตอนเปิดหน้าที่ใช้บ่อยที่สุดรองจาก Home/Profile (มี Skeleton แล้ว) กัน layout กระโดดตอนเนื้อหาโหลดเสร็จ
User Flow: [เปิดหน้า] → fetch เริ่ม → ระหว่างรอ (ข้อมูล == null) แสดง Skeleton แทน spinner → ข้อมูลมาแล้ว replace ด้วยเนื้อหาจริง (ไม่มี fade เพิ่ม — fade เป็นของ WYN-140c)
Components: สร้าง `ClubPageSkeleton`/`ChatInboxSkeleton`/`ConversationSkeleton`/`NotificationListSkeleton` ก็อปปี้โครงสร้างจาก `HomeFeedSkeleton` ตรงๆ ปรับ shape ตามเนื้อหาจริงแต่ละหน้า (รายละเอียด shape ในสเปกเต็ม)
Interactions: ไม่มี tap/gesture บน Skeleton เอง
States: แสดงเฉพาะตอนโหลดครั้งแรก (ข้อมูล == null) ไม่ใช้กับ pull-to-refresh/load-more ที่มีอยู่แล้ว
Responsive Behavior: รับ list ยาวไม่เกิน viewport เดียว ทดสอบที่ 320px ตาม ds-008
Accessibility: ต้องห่อด้วย `ExcludeSemantics` เหมือน `HomeFeedSkeleton`
Design Rules: ห้ามใช้ shimmer/animation แบบ indeterminate เด็ดขาด — static block เท่านั้น (เหตุผล: `pumpAndSettle()` ค้าง) ใช้สี/สเปซจาก design token เดิม
Handoff: Spec เต็ม (shape รายละเอียดแต่ละหน้า) ที่ `.wyn/docs/design/wyn-140-big-platform-polish-audit.md` (หัวข้อ "WYN-140b") — AI QA & Security ตรวจ screen reader ไม่อ่าน skeleton เป็นเนื้อหา + เทสเดิมทั้ง 4 หน้ายังผ่าน ไม่มี `pumpAndSettle()` ค้าง
