# Design Task — WYN-140c

Status: active — Design spec เสร็จ, พร้อมส่งต่อ AI Coding (รอ WYN-140a/140b deploy ก่อนตามลำดับ priority)
Owner: AI Design → AI Coding
Priority: 3 ของ 3 (effort สูงสุด ทำหลังสุด)
Screen: List insert/remove ทั่วแอป — ข้อความใหม่ในแชท (priority แรก), comment ใหม่ใน Drop/Club post, badge เปลี่ยนใน Club Members
Purpose: ลดความรู้สึก "กระตุก" ตอนเนื้อหาโผล่/หายทันที — DS-010 มี motion infrastructure ใช้งานได้จริงอยู่แล้ว (`WynMotion`, `WynStatePop`, `WynPressable`) แค่ยัง adopt แคบมาก (5 ไฟล์จากทั้งแอป) — งานนี้คือขยายการใช้ ไม่ใช่สร้างระบบใหม่
User Flow: [รายการใหม่เข้า list] → fade+scale เข้าตาม `WynMotion.standard` (220ms) + `WynMotion.popFromScale` เหมือน pattern ที่ `WynStatePop` ใช้กับ Like/Save icon อยู่แล้ว — [รายการถูกลบ] → fade out ก่อนหายจาก list
Components: ใช้ `WynMotion` token เดิมทั้งหมด — ถ้าต้องมี wrapper ใหม่สำหรับ list-item enter/exit ตั้งชื่อตาม pattern เดิม (เช่น `WynListItemPop`) วางในโฟลเดอร์เดียวกับ `wyn_state_pop.dart`
Interactions: ไม่เปลี่ยน gesture ใดๆ เพิ่มแค่ transition ตอนรายการเปลี่ยน
States: เฉพาะตอน state เปลี่ยนจริง — **ห้ามเล่น animation ตอน initial load ของ list** เหมือนกติกาเดิมของ `WynStatePop` ("Starts settled")
Responsive Behavior: animate เฉพาะ opacity/transform (scale) ตาม DS-010 ข้อ 5 ห้าม animate padding/width/height
Accessibility: ต้องเช็ค `WynMotion.isReduced(context)` ทุกจุดที่เพิ่มใหม่ เหมือน `WynStatePop`
Design Rules: ห้ามสร้าง duration/curve/scale ใหม่ — ใช้ token จาก `WynMotion` เดิมทั้งหมด ถ้า token ไม่พอสำหรับ use case ใหม่ ให้กลับมาหา AI Design ก่อน ไม่ใช่ AI Coding เลือกเอง
Handoff: Spec เต็มที่ `.wyn/docs/design/wyn-140-big-platform-polish-audit.md` (หัวข้อ "WYN-140c") — priority ภายในงานนี้เอง: (1) Conversation Screen ข้อความใหม่จาก realtime, (2) comment ใหม่, (3) Club Members badge — รัน `interaction_guard_test.dart`/`design_system_guard_test.dart` เดิมต้องผ่าน เพิ่ม widget test ยืนยัน initial build ไม่มี animation เล่น
