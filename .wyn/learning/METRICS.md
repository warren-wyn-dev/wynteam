# Team Performance Metrics

> ห้ามสร้างข้อมูลเทียม (fabricate) — ค่าที่ยังไม่มีข้อมูลจริงให้ระบุ UNKNOWN

- Tasks completed: 1 (WYN-001 — Vision & Tech Stack)
- QA failures: 1 (WYN-002 รอบที่ 1 — FAIL)
- Bugs discovered: 3 (WYN-002: 1 Critical, 2 Medium — ดู `.wyn/tasks/bugs/WYN-002-authentication-onboarding.md`)
- Repeated bugs: 0 (ยังไม่มีรอบ regression ให้เทียบ)
- Rework rate: UNKNOWN (ยังไม่มีข้อมูลพอคำนวณ)
- Deployment failures: UNKNOWN (ยังไม่มี deployment จริง)
- Common mistakes: UNKNOWN (มีข้อมูลจุดเดียวยังสรุป pattern ไม่ได้)
- Successful patterns: UNKNOWN
- Development bottlenecks: การเชื่อม auth state (Supabase `AuthState` stream) เข้ากับการเปลี่ยนแปลงข้อมูล profile (Postgres row) เป็นจุดที่พลาดได้ง่าย — ดูบั๊ก Critical ของ WYN-002

## อัปเดตล่าสุด

2026-08-13 — หลัง QA รอบแรกของ WYN-002
