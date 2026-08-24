# Product Task — WYN-069

Status: backlog
Owner: AI Product Manager

Feature: Profile Post Grid — แก้ปัญหา Scroll ได้แค่บางส่วนของพื้นที่หน้าจอ

Goal: ให้ grid โพสต์ใน Profile ใช้พื้นที่และ scroll ได้เต็มที่ ไม่ถูกจำกัดความสูง

Target User: ผู้ใช้ทุกคนที่ดู Profile (ตัวเองหรือคนอื่น) ที่มีโพสต์จำนวนมาก

Problem: Founder รายงานว่า Post section ใน Profile แสดงได้แค่ประมาณครึ่งหน้าจอเหมือนเวอร์ชันก่อนหน้า — จากการตรวจโค้ดปัจจุบัน (`view_profile_screen.dart`, `profile_drop_grid_tab.dart`) โครงสร้างเป็น `Column` → `Expanded(TabBarView(...))` → แต่ละแท็บมี `ScrollController`/`GridView` ของตัวเอง ซึ่งดูเหมือนถูกต้องตามหลัก Flutter ทั่วไป (ไม่พบ SliverGrid ที่ nested scroll ผิดจุดหรือ fixed-height Container ที่ตัด scroll ชัดเจนในระดับผิวเผิน) — **จำเป็นต้องมี AI Design/AI Coding ตรวจสอบเชิงลึกและทดสอบจริงบนอุปกรณ์/ขนาดจอต่างๆ** เพราะอาจเป็นปัญหาที่เกิดเฉพาะบางเงื่อนไข (เช่น จำนวนโพสต์น้อยที่ทำให้ grid สั้นกว่าพื้นที่ที่มี แล้วดู "ไม่เต็ม", หรือ physics/scroll conflict ที่เกิดเฉพาะบางแพลตฟอร์ม/ขนาดจอ)

Requirements:
- R1. Post section ใช้พื้นที่หน้าจอทั้งหมดที่มีอย่างเหมาะสม (หลัง Header/Info/TabBar) ไม่ถูกจำกัดความสูงตายตัว
- R2. Scroll ดูโพสต์ได้ต่อเนื่องจนสุด รองรับจำนวนโพสต์มาก (ทดสอบกับ mock data 100+ โพสต์)
- R3. Bottom Navigation ต้องไม่บัง content ส่วนล่างสุดของ grid (เพิ่ม bottom padding ให้พอดี ถ้ายังไม่มี)
- R4. ไม่มี nested scroll ที่ใช้งานยาก (เช่น scroll ข้างในไม่ลื่นไถลต่อกับ scroll ข้างนอก) — ถ้าโครงสร้างปัจจุบัน (per-tab independent scroll ใน `TabBarView`) เป็นสาเหตุจริง ให้พิจารณาออกแบบใหม่เป็น `NestedScrollView`/`CustomScrollView` แบบเดียวที่ scroll ทั้ง Header+Tab+Grid ต่อเนื่องกัน (ต้องตัดสินใจโดย AI Design เพราะกระทบโครงสร้างทั้งหน้า)

Acceptance Criteria:
- [ ] ทดสอบด้วยโปรไฟล์ที่มีโพสต์จำนวนมาก (50+) — scroll ได้ต่อเนื่องจนสุด ไม่ค้างครึ่งจอ
- [ ] ทดสอบบนขนาดจอเล็ก/ใหญ่หลายแบบ (มือถือจอเล็กสุดที่รองรับ ถึง tablet ถ้ามี) — ไม่มี layout ที่ถูกตัด
- [ ] Bottom Navigation ไม่บังโพสต์แถวสุดท้าย
- [ ] Regression: TabBar (Drop/ReDrops/Pop เดิม ก่อน WYN-066 ซ่อน Pop/บันทึก/ร่าง) ยัง scroll/สลับแท็บได้ปกติทุกจุด

Dependencies: ควรทำหลัง WYN-066 (ซ่อน Pop tab) เสร็จ เพราะจำนวนแท็บจะเปลี่ยน — แก้ไฟล์เดียวกัน (`view_profile_screen.dart`) เสี่ยง conflict ถ้าทำพร้อมกัน

Priority: สูง — ถ้าปัญหาจริง (ผู้ใช้ดูโพสต์คนอื่นไม่ครบ) กระทบ core UX ของ Profile โดยตรง แต่ priority ที่แท้จริงขึ้นกับผล investigation ของ AI Design/Coding รอบแรกว่าเป็นบั๊กจริงหรือ Founder เห็นจากข้อมูลทดสอบที่มีโพสต์น้อย (ต้องยืนยันก่อนแก้)

Risks: ถ้าแก้โดยเปลี่ยนโครงสร้างเป็น `CustomScrollView` ใหญ่ อาจกระทบ `AutomaticKeepAliveClientMixin` ที่แต่ละ tab ใช้อยู่ (เก็บ scroll position ตอนสลับแท็บ) ต้องทดสอบ regression ให้ครบ

Recommendation: ขั้นแรกให้ AI Design/Coding reproduce ปัญหาก่อนแก้ (ตาม engineering rule ของ spec นี้ข้อ "ตรวจสอบก่อนแก้") — ถ้า reproduce ไม่ได้กับโครงสร้างปัจจุบัน ให้รายงานกลับ Founder พร้อมหลักฐาน (screenshot/สภาพแวดล้อมที่ทดสอบ) แทนการแก้สิ่งที่ยังไม่ยืนยันว่าพัง

Handoff: AI Design ตรวจสอบ/reproduce ปัญหาจริงก่อน แล้วเสนอแนวทาง (คง per-tab scroll เดิมแต่แก้ height constraint ที่พบ vs. เปลี่ยนเป็น NestedScrollView ใหญ่) ให้ Founder เลือกถ้ากระทบโครงสร้างมาก ก่อนส่ง AI Coding
