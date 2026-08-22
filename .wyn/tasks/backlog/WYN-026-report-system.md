# Product Task — WYN-026

Status: backlog
Owner: AI Product Manager

Feature: Report System (Universal — User/Drop/Comment/Club/Club Post/Message)

Goal: ให้ผู้ใช้รายงานเนื้อหา/ผู้ใช้ที่ไม่เหมาะสมได้จากทุกจุดในแอปด้วยกลไกเดียวกัน เพื่อสร้างฐานข้อมูล Report ที่ WYN-029 (Moderation Queue) และในอนาคต WYN Admin (Phase 7) ใช้บริหารจัดการต่อได้

Target User: ผู้ใช้ทุกคนของ WYN (โดยเฉพาะกลุ่ม Gen Z ที่เจอเนื้อหา/พฤติกรรมไม่เหมาะสมบ่อยในโซเชียล) และในระยะถัดไปคือทีม Moderation ที่ต้องพึ่งข้อมูลนี้

Problem: WYN ตอนนี้ไม่มีกลไก Report ใด ๆ เลย ผู้ใช้ไม่มีทางแจ้งเนื้อหา/ผู้ใช้ที่ละเมิดกฎได้ด้วยตัวเอง — Master Spec (`.wyn/docs/product/wyn-v1.0.0-master-spec.md` ข้อ 22) ระบุชัดว่า "ทุก User/Drop/Comment/Club/Message ต้องมี Report" พร้อม Report Categories ที่กำหนดไว้แล้ว — เป็น task แรกของ Phase 1 (Safety & Trust Foundation) เพราะ Block (WYN-027)/Moderation (WYN-029) ต้องพึ่งข้อมูลจาก Report เป็นจุดเริ่มต้น

Requirements:

**Entry point การรายงาน (เมนู 3 จุด / More menu ของแต่ละเนื้อหา)**
- **User**: จาก Profile ของคนอื่น (ปุ่ม More ข้าง Follow/Message)
- **Drop**: จาก Drop Detail และจากการ์ดใน Home/Search/Profile grid (เมนู 3 จุด)
- **Comment**: ทั้ง Drop Comment และ Club Post Comment (เมนู 3 จุดข้าง comment แต่ละอัน — ต่อยอด "Report Comment" ที่ระบุไว้ใน spec เดิมของ Comment section)
- **Club**: จาก Club Page (เมนู More ข้าง Join/Share)
- **Club Post**: จากโพสต์ใน Club (เมนู 3 จุดเดียวกับ Delete/Pin ที่มีอยู่แล้ว)
- **Message**: **ไม่ทำ entry point จริงรอบนี้** เพราะ WYN Chat (WYN-031/032, Phase 2) ยังไม่มีอยู่ในระบบ — แต่ schema ต้องออกแบบให้รองรับ `target_type = 'message'` ไว้ล่วงหน้า (extensible) เพื่อไม่ต้อง migrate ใหม่ตอน Phase 2

**ขั้นตอนรายงาน**
- แตะ "Report" → เลือก **Report Category** (ตามที่ Master Spec กำหนดตายตัว): Spam, Scam, Harassment, Hate, Sexual Content, Violence, Privacy, Illegal Content, Copyright, Other
- ถ้าเลือก "Other" ต้องกรอกรายละเอียดเพิ่มเติมเป็นข้อความอิสระ (บังคับกรอก) — Category อื่นกรอกรายละเอียดเพิ่มเติมได้แต่ไม่บังคับ
- กดยืนยัน → แสดง confirmation ว่า "รายงานของคุณถูกส่งแล้ว" (ไม่บอกผลลัพธ์การตัดสินทันที เพราะยังไม่มีคนตรวจ)
- ผู้ใช้รายงานเนื้อหา/ผู้ใช้เดิมซ้ำได้ แต่ **1 target ต่อ 1 reporter ส่งได้ครั้งเดียวจนกว่าจะถูกปิดเคส (resolved/dismissed)** กันสแปมรายงานเดิมซ้ำ ๆ รัว ๆ (ปุ่ม Report เปลี่ยนเป็น "รายงานแล้ว" / disabled จนกว่าเคสจะปิด)
- รายงานตัวเอง/เนื้อหาตัวเองไม่ได้ (ปุ่ม Report ไม่แสดงบนเนื้อหา/โปรไฟล์ของตัวเอง)

**ข้อมูลที่ต้องเก็บต่อ Report**
- Reporter (ผู้รายงาน), Target Type + Target ID (polymorphic: user/drop/drop_comment/club/club_post/club_post_comment/message), Category, รายละเอียดเพิ่มเติม (ถ้ามี), เวลาที่รายงาน, Status (pending/reviewing/actioned/dismissed — ใช้ต่อใน WYN-029)

**ความเป็นส่วนตัวของผู้รายงาน**
- ผู้ถูกรายงานต้อง **ไม่รู้ว่าใครเป็นคนรายงาน** และไม่เห็นว่าตัวเองถูกรายงานเลยในหน้าจอปกติ (ไม่มี notification แจ้งผู้ถูกรายงานว่า "คุณถูกรายงาน" ในรอบนี้ — ป้องกัน retaliation)

Acceptance Criteria:
- [ ] รายงาน User จาก Profile คนอื่นได้ครบทุก Category ที่กำหนด
- [ ] รายงาน Drop จาก Detail และจากการ์ดใน Feed/Search/Profile ได้
- [ ] รายงาน Comment ได้ทั้ง Drop Comment และ Club Post Comment
- [ ] รายงาน Club ได้จาก Club Page
- [ ] รายงาน Club Post ได้จากโพสต์ใน Club
- [ ] เลือก "Other" แล้วไม่กรอกรายละเอียด → ส่งไม่ได้ (validation บังคับ)
- [ ] รายงานเนื้อหา/ผู้ใช้เดิมซ้ำก่อนเคสปิด → บล็อกไม่ให้ส่งซ้ำ, ปุ่มแสดงสถานะ "รายงานแล้ว"
- [ ] เนื้อหา/โปรไฟล์ของตัวเอง → ไม่มีปุ่ม Report ให้กด
- [ ] ผู้ถูกรายงานไม่เห็นข้อมูลใด ๆ ว่ามีคนรายงานตัวเอง (ตรวจ UI/notification ไม่มีการรั่วไหล)
- [ ] Report ทุกอันบันทึกลง DB ครบ target_type/target_id/category/reporter/status=pending ถูกต้อง ตรวจสอบผ่าน DB โดยตรงได้ (ยังไม่มีหน้าจอ Moderation Queue ใน task นี้ — ดู WYN-029)
- [ ] Regression: ทุกฟีเจอร์เดิม (Drop/Pop/Home/Club/Search/Notification/Follow/Profile) ยังทำงานปกติ

Dependencies: WYN-002 (Auth), WYN-003 (Profile), WYN-005 (Drop), WYN-014/015 (Club) — ทั้งหมด Approved แล้ว ไม่ต้องพึ่ง WYN-027/028/029/030 (task อื่นใน Phase 1 พึ่ง task นี้แทน ไม่ใช่ทางกลับกัน)

Priority: P0 — เป็น task แรกของ Phase 1 (Safety & Trust Foundation) ตาม `.wyn/docs/product/wyn-v1.0.0-roadmap.md` Founder ระบุให้เริ่ม Phase 1 ก่อน Phase 2 (Chat) เพราะความเสี่ยงเปิดพื้นที่ social ใหม่โดยไม่มี Report/Block/Mute สูงเกินยอมรับได้สำหรับกลุ่มเป้าหมาย Gen Z

Risks:
- **Polymorphic target (target_type + target_id) ไม่มี FK constraint ตรงเป้าได้จริงในระดับ DB** (ต่างชนิดเป้าหมายอยู่คนละตาราง) — ต้อง validate ที่ RPC/application layer ว่า target_id มีอยู่จริงตาม target_type ก่อน insert ไม่ปล่อยให้ client ส่ง target_id มั่ว ๆ ได้ — แนะนำใช้ security-definer RPC เดียว (`submit_report(...)`) แทน raw insert policy เพื่อ validate ตรงนี้รวมศูนย์จุดเดียว
- **Rate-limit การส่ง Report แบบสแปม** (คนละ target แต่ยิงรัว ๆ จำนวนมาก) — รอบนี้ยังไม่ทำ rate-limit เชิงปริมาณ/เวลา (นอก scope) แค่กัน "target เดิมซ้ำ" เท่านั้น ถ้าพบว่าเป็นปัญหาจริงในอนาคตค่อยเพิ่มเป็น fast-follow
- **Message report type ที่ประกาศไว้ล่วงหน้าแต่ยังไม่มี UI**: ต้องระวังไม่ให้ enum/schema locked แน่นเกินไปจนขยายยากตอน WYN-031/032 (Phase 2) มาถึงจริง — แนะนำ Design ให้ enum เป็น text + check constraint ที่แก้ไขเพิ่มค่าใหม่ได้ง่ายในอนาคต ไม่ใช่ hard enum type ที่ ALTER ยาก
- ยังไม่มีหน้าจอให้ใครตรวจ Report เลยใน task นี้ (Moderation Queue คือ WYN-029 ถัดไป) — Report ที่ส่งเข้ามาจะ "ค้าง" ใน DB จนกว่า WYN-029 จะเสร็จ ซึ่งเป็นความตั้งใจ ไม่ใช่ gap (แบ่ง scope ตาม roadmap)

Recommendation:
1. เริ่ม WYN-026 ก่อนสุดใน Phase 1 ตามลำดับที่ roadmap วางไว้ — เป็นฐานให้ WYN-027 (Block, มักเริ่มจากปุ่ม Report เดียวกัน), WYN-029 (Moderation Queue อ่าน Report), WYN-030 (Appeal อ้างอิงถึง action ที่มาจาก Report) ทำงานต่อได้
2. ให้ AI Design ออกแบบ Report bottom-sheet/modal เดียวที่ reuse ได้ทุกจุด (parameterize ด้วย target_type/target_id) แทนแยกหน้าจอต่อประเภทเนื้อหา ลด UI ซ้ำซ้อน
3. แนะนำเพิ่มปุ่ม "Report" เข้าไปในเมนู 3 จุดที่มีอยู่แล้วของแต่ละเนื้อหา (Drop/Club Post/Comment) แทนสร้างเมนูใหม่ ลด disruption ต่อ UI เดิม
4. ส่งต่อ AI Design (`/design`) เพื่อออกแบบ Report flow/UI ทันทีหลัง Founder ยืนยันขอบเขตนี้

Handoff: AI Design — ออกแบบ Report bottom-sheet (Category list + optional detail text + confirmation), entry point ในแต่ละหน้าจอที่เกี่ยวข้อง, และ state ปุ่ม "รายงานแล้ว" หลังส่งสำเร็จ
