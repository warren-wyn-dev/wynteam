# Team Performance Metrics

> ห้ามสร้างข้อมูลเทียม (fabricate) — ค่าที่ยังไม่มีข้อมูลจริงให้ระบุ UNKNOWN

- Tasks completed: 2 (WYN-001 — Vision & Tech Stack, WYN-002 — Authentication & Onboarding ผ่าน QA รอบ 3)
- QA failures: 3 (WYN-002 รอบที่ 1, รอบที่ 2 — FAIL; WYN-003 รอบที่ 1 — FAIL); QA passes: 1 (WYN-002 รอบที่ 3 — PASS)
- Bugs discovered: 5 (WYN-002: 1 Critical + 2 Medium จากรอบ 1, อีก 1 Critical เป็น regression จากรอบ 2 — แก้ครบแล้ว; WYN-003: 1 Critical จากรอบ 1 — รอแก้)
- Repeated bugs: 1 (WYN-002 รอบ 2 คือบั๊ก "ผู้ใช้ค้างหน้าเดิม/นำทางผิด" แบบเดิมที่กลับมาในรูปแบบใหม่ — เกิดจากการแก้บั๊ก Critical รอบ 1 เอง; รอบ 3 ยืนยันว่าแก้ถูกจุดจริงแล้ว)
- Rework rate: WYN-002 ใช้เวลา 3 รอบ QA ถึงจะ PASS (2 FAIL, 1 PASS); WYN-003 อยู่ระหว่างรอบ 1 FAIL
- Deployment failures: UNKNOWN (ยังไม่มี deployment จริง)
- Common mistakes:
  - การแก้บั๊ก navigation โดยไม่ trace ผลกระทบต่อ lifecycle ทั้งหมด (WYN-002) — แก้ให้ "ไปถึงหน้าถัดไปได้" แต่ไม่เช็คว่าขั้นตอนถัดจากนั้นยังทำงานถูกต้องหรือไม่
  - **Empty string vs NULL mismatch ระหว่าง app กับ DB constraint** (WYN-003) — ฟิลด์ optional ที่ผู้ใช้ยังไม่กรอก ต้องส่งเป็น `null` ไม่ใช่ `''` เมื่อ DB constraint กำหนดความยาวขั้นต่ำไว้ (เช่น `between 1 and 50`) มิเช่นนั้นจะ violate constraint ทุกครั้งที่ฟิลด์นั้นว่าง
- Successful patterns: "Callback-to-parent-rebuild" แทน "สร้าง route ใหม่ (Navigator.push/pushReplacement)" เมื่อ child widget ต้องแจ้งให้ auth-state gate (`AuthGate`) เปลี่ยนหน้าจอ — ดู `.wyn/learning/PATTERNS.md`
- Development bottlenecks:
  - การเชื่อม auth state (Supabase `AuthState` stream) เข้ากับ Navigator/route lifecycle เป็นจุดที่พลาดซ้ำได้ง่ายที่สุดใน WYN-002 — เกิดบั๊กที่เกี่ยวข้องกับจุดนี้ 2 รอบติดกันก่อนจะแก้ถูกจุด
  - ความสอดคล้องระหว่าง Dart-side default values (`?? ''`) กับ Postgres CHECK constraint semantics เป็นจุดพลาดใหม่ที่พบใน WYN-003 — AI Coding ควรตรวจสอบทุกครั้งที่เขียน field ที่มี DB constraint ว่า "ค่าว่าง" ฝั่ง Dart จะแปลงเป็นอะไรก่อนส่งไป DB

## อัปเดตล่าสุด

2026-08-13 — หลัง QA รอบ 1 ของ WYN-003 (FAIL)
