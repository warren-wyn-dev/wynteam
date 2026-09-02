# Feature Request — WYN-105

Status: full spec complete, ready for AI Design — scope larger than originally estimated (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 5 (ส่วนธีมสี)/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่มระบบเลือกธีมสีของ WYNOS ได้ 3 แบบ
Goal: ให้ผู้ใช้เลือกธีมที่ชอบได้เอง: ขาวนวล / ขาวบริสุทธิ์ / ดำ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "แล้วอยากให้เลือกสีธีมได้ 3 สี คือ 1.ขาวนวล 2.ขาวบริสุทธิ์ 3.ดำ"
Requirements:
- ออกแบบ 3 theme palette: ขาวนวล (ปัจจุบัน/off-white), ขาวบริสุทธิ์ (pure white), ดำ (dark mode)
- เพิ่มหน้าตั้งค่าให้เลือกธีม บันทึกค่าที่เลือกไว้ (local + sync บัญชีถ้าต้องการข้ามอุปกรณ์)
- ตรวจทุกหน้าจอหลักให้รองรับทั้ง 3 ธีมโดยไม่มีจุดที่ hardcode สีจนอ่านไม่ออกในธีมใดธีมหนึ่ง (โดยเฉพาะธีมดำ)
Acceptance Criteria:
- [ ] เปลี่ยนธีมในตั้งค่าแล้วทั้งแอปเปลี่ยนสีทันที
- [ ] ทุกหน้าจอหลักอ่านง่ายครบทั้ง 3 ธีม ไม่มีข้อความ/ไอคอนที่กลืนกับพื้นหลัง
Dependencies: ควรทำหลัง WYN-078 (แก้ bug พื้นหลังไม่เต็มจอ) เพราะเป็นเรื่อง background/theme เดียวกัน
Priority: กลาง (งานกว้าง กระทบทุกหน้าจอ ต้องทำท้ายๆ เพื่อลดการชนกับงาน UI อื่นที่ยังไม่นิ่ง)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ทำธีมตอนที่ UI อื่นยังเปลี่ยนอยู่ (Phase 2) อาจต้องไล่แก้ซ้ำ | กลาง | ทำเป็นงานสุดท้ายของรอบนี้ หลัง Phase 1-2 นิ่งแล้ว |
Recommendation: อนุมัติ แนะนำทำเป็นลำดับท้ายๆ ของรอบนี้
Handoff: AI Design (กำหนด palette แต่ละธีมให้ครบทุก component) → AI Coding → AI QA (เช็ค contrast/อ่านง่ายทั้ง 3 ธีม)

## Product Full Spec Output (2026-09-02)

เขียน full spec เสร็จแล้วที่ `.wyn/docs/product/wyn-105-theme-system.md` — **พบความเสี่ยงสถาปัตยกรรมที่ backlog เดิมประเมินไว้ต่ำเกินไป**: โค้ดทั้งแอปอ้างอิงสีผ่าน `WynColors.ink`/`.paper`/ฯลฯ เป็น static const literal โดยตรง ไม่ผ่าน `Theme.of(context)` — แม้ `WynTheme.dark`/`themeMode` จะมีโครงอยู่แล้วใน `main.dart` แต่ comment ในโค้ดยืนยันตรงๆ ว่า dark ColorScheme "unused in production today" เพราะสลับ themeMode แล้วหน้าจอส่วนใหญ่จะไม่เปลี่ยนสีเลย — การทำธีมจริงต้องไล่แก้เกือบทุกไฟล์ UI ในโปรเจกต์ (ไม่ใช่แค่ "ชนกับงาน UI อื่น" ตามที่ Risk เดิมระบุ) เพิ่มคอลัมน์ `profiles.theme_preference` (3 ค่า) sync ข้ามอุปกรณ์ตามที่ระบุ

**ต้อง ping Founder**: แจ้งว่างานนี้ใหญ่กว่าที่ backlog เดิมประเมินไว้มาก (รีแฟกเตอร์สถาปัตยกรรมสีทั้งแอป ไม่ใช่แค่เพิ่มหน้าตั้งค่า) แนะนำทำเป็นลำดับท้ายสุดของทั้งรอบ Beta2 (ไม่ใช่แค่ท้าย Phase 3) และแบ่งเป็นหลาย PR ทยอยไล่ทีละ feature folder

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-105-theme-system.md`

Handoff: ส่งต่อ AI Design (`/design`) — ต้องตัดสินใจ Architecture Decision (วิธีทำให้สลับธีมได้จริง) ก่อนเริ่ม Coding
