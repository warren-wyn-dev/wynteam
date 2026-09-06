# Product Task — WYN-126

Status: backlog
Owner: AI Product Manager

Feature: แสดงหมายเลขเวอร์ชัน WYNOS ที่ล่างสุดของหน้าการตั้งค่า (Settings) — ต่างกันตามสถานะบัญชี

Goal: ให้ทุกคนเช็คได้จากในแอปเองว่าเครื่องตัวเองกำลังรัน WYNOS เวอร์ชันไหน และให้ทีมภายในเห็นชัดเจนว่าตัวเองอยู่ในโหมด "ทดสอบ build ใหม่" (ตาม policy staged rollout ที่เพิ่งประกาศเป็น default เมื่อ 2026-09-06 — ดู `.wyn/company/WORKFLOW.md` หัวข้อ "Staged Rollout เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่")

Target User: ผู้ใช้ทุกคนเห็น label นี้ (ไม่ gate ตัวมันเองด้วย developer flag — ดู Risks) แต่ข้อความต่างกันตามว่าเป็นบัญชีนักพัฒนาหรือไม่

Problem: ตอนนี้ไม่มีทางเช็ค version ของแอปจากในตัวแอปเองเลย — Founder อยากเห็นเลขเวอร์ชันในหน้า Settings และอยากให้ต่างกันระหว่างบัญชีนักพัฒนา (เห็น build ที่กำลังพัฒนาอยู่) กับผู้ใช้ทั่วไป (เห็น build เสถียรปัจจุบัน) เพื่อให้เห็นภาพตรงกับนโยบาย staged rollout ที่เพิ่งตั้งเป็นค่าเริ่มต้น

Requirements:
1. เพิ่มข้อความเวอร์ชันที่ตำแหน่ง**ล่างสุด**ของหน้า Settings (`app/lib/features/settings/presentation/settings_screen.dart`) — ต่อจากแถว "ออกจากระบบ" ที่เป็นรายการสุดท้ายของ `ListView` ในปัจจุบัน (ดูโค้ดจริง บรรทัด ~250-266)
2. ข้อความขึ้นกับสถานะบัญชี โดยเช็คผ่าน `DeveloperAccessService.isDeveloperAccount()` (WYN-125, deploy แล้วบน production):
   - ผู้ใช้ทั่วไป (`false`, ค่าเริ่มต้นของทุกคนวันนี้): **"V1.0.0 Beta4"**
   - บัญชีนักพัฒนา (`true` — ตอนนี้คือ `@warren`, `@wynos_online`): **"V1.0.0 Beta5 [พัฒนาอยู่]"**
3. ตัวเลขเวอร์ชันทั้งสอง (Beta4/Beta5) ต้องอยู่เป็น constant เดียวที่จุดเดียวในโค้ด (ไม่ hardcode ซ้ำหลายที่) เพื่อให้รอบถัดไปที่ Owner ประกาศ version ใหม่ (ตาม `.wyn/company/VERSION_CONTROL.md`) แก้ที่เดียวจบ
4. Fail-closed: ถ้าเช็ค `isDeveloperAccount()` error/timeout ต้องแสดงเป็นข้อความของผู้ใช้ทั่วไป ("V1.0.0 Beta4") เสมอ ห้ามค้าง/ห้าม error/ห้าม blank

Acceptance Criteria:
- [ ] เปิดหน้า Settings ด้วยบัญชีทั่วไป → เห็น "V1.0.0 Beta4" เป็นบรรทัดสุดท้ายของหน้า ใต้ "ออกจากระบบ"
- [ ] เปิดหน้า Settings ด้วยบัญชี `@warren` หรือ `@wynos_online` → เห็น "V1.0.0 Beta5 [พัฒนาอยู่]" แทน
- [ ] ปิด/พัง RPC เช็ค flag ชั่วคราว (จำลอง error) → ยังเห็น "V1.0.0 Beta4" ไม่ crash ไม่ blank
- [ ] ไม่กระทบ layout/สไตล์ของ Settings เดิมส่วนอื่น (regression: ทุกแถวก่อนหน้ายังทำงานเหมือนเดิม)

Dependencies: WYN-125 (`DeveloperAccessService`, deploy แล้ว) — ไม่มี schema/RLS ใหม่ (เป็น client-side UI ล้วนๆ ใช้ RPC ที่มีอยู่แล้ว)

Priority: Low-medium — ไม่ใช่ P0 แต่ทำได้เร็ว (ไม่มี schema เปลี่ยน ไม่มี flow ใหม่) และมีประโยชน์ทันทีในการ verify staged rollout policy ที่เพิ่งประกาศ

Risks:
- **งานนี้เองไม่ gate ด้วย developer flag** (ตัดสินใจโดย AI Product Manager ไม่ได้ถาม Founder ตรงๆ) เพราะเป็นเครื่องมือ "บอกสถานะ" ไม่ใช่ฟีเจอร์ผลิตภัณฑ์ใหม่ — ถ้า gate ตัวมันเองจะกลายเป็นวนซ้ำ (ต้องเช็ค flag เพื่อรู้ว่าจะโชว์ผลของการเช็ค flag) และขัดจุดประสงค์ที่อยากให้ทุกคนเช็คได้ว่าตัวเองอยู่ build ไหน — ถ้า Founder ไม่เห็นด้วยแจ้งแก้ไขได้
- ถ้า hardcode ข้อความเวอร์ชันหลายจุดแทนที่จะรวมเป็น constant เดียว จะลืมแก้ไม่ครบตอน Owner ประกาศ version ใหม่รอบหน้า — Requirement 3 ป้องกันจุดนี้ไว้แล้ว
- เอกสาร version ที่มีอยู่ (`VERSION_CONTROL.md`, `VERSION.md`, `RELEASE_NOTES.md`) เก่าค้างที่ Beta1 ทั้งที่ production จริงเป็น Beta4 มาตั้งแต่ 2026-09-03 (ดู `.wyn/logs/deployments/2026-09-03-wynos-beta4-real-deploy.md`) — ได้แก้ให้ตรงกับความจริงแล้วเป็นงานเอกสารแยก (ดู DECISIONS.md entry เดียวกันวันที่นี้) ไม่ใช่ scope ของ task coding นี้

Recommendation: งานเล็ก ไม่ต้องผ่าน Design step เต็มรูปแบบ (ไม่มี UX flow ใหม่ ไม่มี state ใหม่ที่ซับซ้อน) — ส่งตรงให้ AI Coding ได้เลย แต่ยังต้องมี design decision สั้นๆ เรื่อง text style (ขนาด/สี/ระยะห่าง) ให้เข้ากับ pattern เดิมของหน้า Settings เพื่อความสม่ำเสมอ ให้ AI Design ทำ spec สั้นๆ ก่อนส่ง Coding

Handoff: ส่งต่อ AI Design ออกแบบ text style + ตำแหน่งที่แน่นอน แล้วส่งต่อ AI Coding implement ตาม Requirement 1-4 → AI QA & Security ตรวจทั้ง 2 state (`true`/`false`) + fail-closed → AI Deploy & DevOps (ไม่มี schema ใหม่ ไม่ต้องมี apply workflow แยก เป็น client-only เหมือนงาน WYN-123 เดิม)
