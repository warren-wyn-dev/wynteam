# Team Performance Metrics

> ห้ามสร้างข้อมูลเทียม (fabricate) — ค่าที่ยังไม่มีข้อมูลจริงให้ระบุ UNKNOWN

- Tasks completed: 1 (WYN-001 — Vision & Tech Stack)
- QA failures: 2 (WYN-002 รอบที่ 1 — FAIL, รอบที่ 2 — FAIL)
- Bugs discovered: 4 (WYN-002: 1 Critical + 2 Medium จากรอบ 1, อีก 1 Critical เป็น regression ใหม่จากรอบ 2 — ดู `.wyn/tasks/bugs/WYN-002-authentication-onboarding.md`)
- Repeated bugs: 1 (รอบ 2 คือบั๊ก "ผู้ใช้ค้างหน้าเดิม/นำทางผิด" แบบเดิมที่กลับมาในรูปแบบใหม่ — เกิดจากการแก้บั๊ก Critical รอบ 1 เอง)
- Rework rate: WYN-002 ผ่าน QA ไปแล้ว 2 รอบยังไม่ PASS (2/2 รอบ FAIL)
- Deployment failures: UNKNOWN (ยังไม่มี deployment จริง)
- Common mistakes: การแก้บั๊ก navigation โดยไม่ trace ผลกระทบต่อ lifecycle ทั้งหมด (แก้ให้ "ไปถึงหน้าถัดไปได้" แต่ไม่เช็คว่าขั้นตอนถัดจากนั้น เช่น logout ยังทำงานถูกต้องหรือไม่)
- Successful patterns: UNKNOWN
- Development bottlenecks: การเชื่อม auth state (Supabase `AuthState` stream) เข้ากับ Navigator/route lifecycle เป็นจุดที่พลาดซ้ำได้ง่ายที่สุดใน WYN-002 — เกิดบั๊กที่เกี่ยวข้องกับจุดนี้แล้ว 2 รอบติดกัน

## อัปเดตล่าสุด

2026-08-13 — หลัง QA รอบ 2 ของ WYN-002
