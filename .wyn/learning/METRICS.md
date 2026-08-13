# Team Performance Metrics

> ห้ามสร้างข้อมูลเทียม (fabricate) — ค่าที่ยังไม่มีข้อมูลจริงให้ระบุ UNKNOWN

- Tasks completed: 2 (WYN-001 — Vision & Tech Stack, WYN-002 — Authentication & Onboarding ผ่าน QA รอบ 3)
- QA failures: 2 (WYN-002 รอบที่ 1 — FAIL, รอบที่ 2 — FAIL); QA passes: 1 (WYN-002 รอบที่ 3 — PASS)
- Bugs discovered: 4 (WYN-002: 1 Critical + 2 Medium จากรอบ 1, อีก 1 Critical เป็น regression จากรอบ 2) — ทั้งหมดแก้แล้วและยืนยันด้วย QA รอบ 3
- Repeated bugs: 1 (รอบ 2 คือบั๊ก "ผู้ใช้ค้างหน้าเดิม/นำทางผิด" แบบเดิมที่กลับมาในรูปแบบใหม่ — เกิดจากการแก้บั๊ก Critical รอบ 1 เอง; รอบ 3 ยืนยันว่าแก้ถูกจุดจริงแล้ว)
- Rework rate: WYN-002 ใช้เวลา 3 รอบ QA ถึงจะ PASS (2 FAIL, 1 PASS) จาก 1 feature
- Deployment failures: UNKNOWN (ยังไม่มี deployment จริง)
- Common mistakes: การแก้บั๊ก navigation โดยไม่ trace ผลกระทบต่อ lifecycle ทั้งหมด (แก้ให้ "ไปถึงหน้าถัดไปได้" แต่ไม่เช็คว่าขั้นตอนถัดจากนั้น เช่น logout ยังทำงานถูกต้องหรือไม่)
- Successful patterns: "Callback-to-parent-rebuild" แทน "สร้าง route ใหม่ (Navigator.push/pushReplacement)" เมื่อ child widget ต้องแจ้งให้ auth-state gate (`AuthGate`) เปลี่ยนหน้าจอ — ดู `.wyn/learning/PATTERNS.md`
- Development bottlenecks: การเชื่อม auth state (Supabase `AuthState` stream) เข้ากับ Navigator/route lifecycle เป็นจุดที่พลาดซ้ำได้ง่ายที่สุดใน WYN-002 — เกิดบั๊กที่เกี่ยวข้องกับจุดนี้ 2 รอบติดกันก่อนจะแก้ถูกจุด

## อัปเดตล่าสุด

2026-08-13 — หลัง QA รอบ 3 ของ WYN-002 (PASS)
