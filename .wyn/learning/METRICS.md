# Team Performance Metrics

> ห้ามสร้างข้อมูลเทียม (fabricate) — ค่าที่ยังไม่มีข้อมูลจริงให้ระบุ UNKNOWN

- Tasks completed: 3 (WYN-001 — Vision & Tech Stack, WYN-002 — Authentication & Onboarding ผ่าน QA รอบ 3, WYN-003 — User Profile ผ่าน QA รอบ 2)
- QA failures: 5 (WYN-002 รอบที่ 1, รอบที่ 2 — FAIL; WYN-003 รอบที่ 1 — FAIL; WYN-004 รอบที่ 1 — FAIL); QA passes: 2 (WYN-002 รอบที่ 3, WYN-003 รอบที่ 2 — PASS)
- Bugs discovered: 7 (WYN-002: 1 Critical + 2 Medium จากรอบ 1, อีก 1 Critical เป็น regression จากรอบ 2 — แก้ครบแล้ว; WYN-003: 1 Critical จากรอบ 1 — แก้แล้ว; WYN-004: 1 Major (2 จุดเกิดจาก root cause เดียวกัน) จากรอบ 1 — รอแก้)
- Repeated bugs: 1 (WYN-002 รอบ 2 คือบั๊ก "ผู้ใช้ค้างหน้าเดิม/นำทางผิด" แบบเดิมที่กลับมาในรูปแบบใหม่ — เกิดจากการแก้บั๊ก Critical รอบ 1 เอง; รอบ 3 ยืนยันว่าแก้ถูกจุดจริงแล้ว)
- Rework rate: WYN-002 ใช้เวลา 3 รอบ QA ถึงจะ PASS (2 FAIL, 1 PASS); WYN-003 ใช้เวลา 2 รอบ QA ถึงจะ PASS (1 FAIL, 1 PASS) — ดีขึ้นกว่า WYN-002; WYN-004 อยู่ระหว่างรอบ 1 (FAIL) — ยังตัดสินไม่ได้ว่ากี่รอบ
- Deployment failures: UNKNOWN (ยังไม่มี deployment จริง)
- Common mistakes:
  - การแก้บั๊ก navigation โดยไม่ trace ผลกระทบต่อ lifecycle ทั้งหมด (WYN-002) — แก้ให้ "ไปถึงหน้าถัดไปได้" แต่ไม่เช็คว่าขั้นตอนถัดจากนั้นยังทำงานถูกต้องหรือไม่
  - Empty string vs NULL mismatch ระหว่าง app กับ DB constraint (WYN-003) — ฟิลด์ optional ที่ผู้ใช้ยังไม่กรอก ต้องส่งเป็น `null` ไม่ใช่ `''` เมื่อ DB constraint กำหนดความยาวขั้นต่ำไว้ — **แก้จบในรอบเดียวและมี automated test คุ้มครองจริง** (ต่างจาก WYN-002 ที่ยังไม่มี test คุ้มครอง fix)
  - Async button handler ที่อ่านค่า state จาก parameter/closure ที่ถูก capture ไว้ตอน build แทนที่จะอ่านสดใหม่จาก field ในตัว method เอง (WYN-004) — เปิดช่องให้กดปุ่มซ้ำเร็ว ๆ ก่อนหน้าจอ rebuild ทำให้เกิด duplicate network call ที่ใช้ค่าเดิมผิด ๆ ซ้ำกัน — จุดที่ถูกต้องอยู่แล้ว (`PostDetailScreen._toggleLike`) กับจุดที่ผิด (`FeedScreen._toggleLike`) อยู่ในไฟล์เดียวกันของงานเดียวกัน แสดงว่า pattern ที่ถูกต้องไม่ได้ถูกยึดเป็นมาตรฐานเดียวกันทั่วทั้ง feature
- Successful patterns:
  - "Callback-to-parent-rebuild" แทน "สร้าง route ใหม่ (Navigator.push/pushReplacement)" เมื่อ child widget ต้องแจ้งให้ auth-state gate (`AuthGate`) เปลี่ยนหน้าจอ — ดู `.wyn/learning/PATTERNS.md`
  - แยก logic ที่เป็นปัญหาออกมาเป็น pure function (`normalizeOptionalText`) เพื่อให้เขียน regression test ได้โดยไม่ต้องพึ่ง Supabase จริง — ทำให้ WYN-003 ใช้รอบ QA น้อยกว่า WYN-002
- Development bottlenecks:
  - การเชื่อม auth state (Supabase `AuthState` stream) เข้ากับ Navigator/route lifecycle เป็นจุดที่พลาดซ้ำได้ง่ายที่สุดใน WYN-002 — เกิดบั๊กที่เกี่ยวข้องกับจุดนี้ 2 รอบติดกันก่อนจะแก้ถูกจุด
  - ความสอดคล้องระหว่าง Dart-side default values (`?? ''`) กับ Postgres CHECK constraint semantics — พบใน WYN-003 แต่แก้ได้เร็วกว่า WYN-002 มาก (1 รอบ vs 2 รอบ) เพราะ bug เป็น pure logic ไม่ใช่ stateful navigation
  - `PostRepository` เป็น concrete class ผูกกับ `SupabaseClient` ตรง ๆ ไม่มี interface ให้ mock/spy — ทำให้ QA รอบ 1 ของ WYN-004 ยืนยันบั๊ก double-tap ได้แค่ระดับ code-trace ไม่สามารถเขียน automated test พิสูจน์ได้แบบ dynamic ในสถาปัตยกรรมปัจจุบัน (ควรพิจารณาเพิ่ม abstraction เบา ๆ ในรอบแก้บั๊ก)

## อัปเดตล่าสุด

2026-08-13 — หลัง QA รอบ 1 ของ WYN-004 (FAIL)
