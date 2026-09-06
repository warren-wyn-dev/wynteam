# WYNOS Version Control Policy

> บันทึกโดย Founder เมื่อ 2026-09-01 — กติกานี้มีผลผูกพันกับทีม AI ทุกบทบาททันที ดู `AGENTS.md` หัวข้อ "อ่านก่อนเริ่มงานทุกครั้ง"

## Current Version

**WYNOS v1.0.0 Beta4** คือ Baseline ปัจจุบันที่ผู้ใช้ทั่วไปใช้งานอยู่ (production, deploy จริงตั้งแต่ 2026-09-03 — ดู `.wyn/logs/deployments/2026-09-03-wynos-beta4-real-deploy.md`)

> **แก้ไข 2026-09-06**: ไฟล์นี้ค้างที่ "Beta1" มานาน ทั้งที่ production จริง deploy ไป Beta2 (2026-09-03) แล้วต่อด้วย Beta4 (2026-09-03 เช่นกัน) ไปแล้ว — ไม่มีใครอัปเดตไฟล์นี้ตามตอน deploy จริง Founder ยืนยันในแชทวันนี้ว่าปัจจุบันคือ Beta4 จึงแก้ไฟล์นี้ให้ตรงกับความจริง ณ ตอนนี้ (ไม่ใช่การประกาศ version ใหม่ — เป็นการแก้เอกสารให้ตรงกับสิ่งที่ deploy ไปแล้วจริง) ดู Version History ด้านล่างสำหรับรายละเอียดที่กู้คืนมาได้

โค้ด ฟีเจอร์ ระบบ UI/UX โครงสร้างฐานข้อมูล API และการตั้งค่าทั้งหมดที่มีอยู่ ณ ตอนนี้ ให้ถือว่าเป็นส่วนหนึ่งของ **WYNOS v1.0.0 Beta4**

**WYNOS v1.0.0 Beta5 กำลังพัฒนาอยู่** (ประกาศโดย Founder 2026-09-06) — เปิดให้เฉพาะบัญชีนักพัฒนาเห็น/ทดสอบก่อน ผ่านกลไก staged rollout (WYN-125, `.wyn/company/WORKFLOW.md` หัวข้อ "Staged Rollout เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่") — **ยังไม่ปล่อยให้ผู้ใช้ทั่วไป** จนกว่า Founder จะสั่งเปิดชัดเจน เมื่อเปิดแล้ว Beta5 จะกลายเป็น Current Version แทน Beta4

ห้ามถือว่าโค้ดปัจจุบันเป็นเวอร์ชันอื่นจากที่ระบุไว้นี้จนกว่าจะได้รับคำสั่งจาก Owner

รายละเอียดของ v1.0.0 Beta1 (ฟีเจอร์ที่ใช้งานได้ตอนนั้น, ลิงก์ใช้งานจริง, สิ่งที่ยังไม่รวม) ดูที่ `RELEASE_NOTES.md` — **หมายเหตุ: RELEASE_NOTES.md เองก็ยังค้างที่ Beta1 เช่นกัน ยังไม่ได้อัปเดตเป็น Beta4 ณ เวลาที่แก้ไฟล์นี้**

## Version Update Rules

เมื่อ Owner สั่งให้อัปเดต WYNOS:

1. Owner จะเป็นผู้กำหนดว่าเพิ่ม Feature อะไร
2. Owner จะเป็นผู้กำหนด Version ใหม่ เช่น v1.0.0 Beta2 / v1.0.0 Beta3 / v1.1.0 Beta1 / v1.1.0 หรือ Version อื่นตามที่ Owner ระบุ
3. ห้ามเปลี่ยน Version เอง
4. ห้ามเพิ่ม Feature ใหญ่ที่ไม่ได้รับคำสั่ง
5. ห้ามลบ Feature เดิมโดยไม่ได้รับคำสั่ง
6. ต้องรักษาความสามารถเดิมของ WYNOS เว้นแต่ Owner สั่งให้เปลี่ยน

## Rollback Policy

หาก Version ใหม่เกิดปัญหา เช่น Build ไม่ผ่าน, Runtime Error, Feature พัง, UI/UX พัง, Database Migration มีปัญหา, API มีปัญหา, Security Regression, Performance Regression, ระบบใช้งานไม่ได้:

**ห้าม Rollback เอง**

Claude Code ต้อง:

1. หยุดการเปลี่ยนแปลงที่ไม่จำเป็น
2. วิเคราะห์ปัญหา
3. รายงานสาเหตุและผลกระทบ
4. เสนอแนวทางแก้ไข
5. รอคำสั่งจาก Owner หากจำเป็นต้อง Rollback

### STRICT RULE

ห้าม Rollback ไปยัง Version ก่อนหน้าโดยอัตโนมัติ ไม่ว่าในกรณีใดก็ตาม การ Rollback จะทำได้ต่อเมื่อ Owner สั่งอย่างชัดเจนเท่านั้น

ตัวอย่างคำสั่งที่อนุญาต: "Rollback WYNOS กลับไป v1.0.0 Beta1"

หากไม่มีคำสั่งดังกล่าว: **DO NOT ROLLBACK**

## Version Integrity

ก่อนเริ่มงานทุกครั้ง ให้ตรวจสอบ Version ปัจจุบันของ WYNOS (ไฟล์นี้ + `RELEASE_NOTES.md`)

Current baseline: **WYNOS v1.0.0 Beta4** (Beta5 กำลังพัฒนา อยู่หลัง developer allowlist — ดูด้านบน)

เมื่อ Owner กำหนด Version ใหม่ ให้บันทึก Version ใหม่อย่างชัดเจนในไฟล์นี้ (อัปเดตหัวข้อ "Current Version" ด้านบน) และรักษาประวัติ Version ก่อนหน้าไว้ในหัวข้อ "Version History" ด้านล่าง

ห้ามเขียนทับหรือทำลาย Version history โดยไม่จำเป็น

## Version History

| Version | สถานะ | หมายเหตุ |
|---|---|---|
| v1.0.0 Beta1 | ปิดแล้ว | Baseline แรก (2026-09-01) — ดู `RELEASE_NOTES.md` |
| v1.0.0 Beta2 | ปิดแล้ว | Deploy จริง 2026-09-03 (29 งาน, WYN-077 ถึง WYN-105) — ดู `.wyn/logs/deployments/2026-09-03-wyn-077-105-beta2-real-deploy.md` |
| v1.0.0 Beta3 | ไม่ชัดเจน | เตรียมไว้เป็น branch แยก ("Deep Polish") แต่ไม่พบบันทึกยืนยันว่า merge/deploy ขึ้น production แยกเป็นเวอร์ชันของตัวเอง — อาจถูกรวมเข้ากับรอบ Beta4 แทน (ยังไม่ได้ไล่ตรวจให้ชัดเจน ณ เวลาที่แก้ไฟล์นี้) |
| v1.0.0 Beta4 | **Current (ผู้ใช้ทั่วไป)** | Deploy จริง 2026-09-03 — Profile UX/Account Experience/Club Community/Notification & Web Push — ดู `.wyn/logs/deployments/2026-09-03-wynos-beta4-real-deploy.md` |
| v1.0.0 Beta5 | **กำลังพัฒนา (เฉพาะบัญชีนักพัฒนา)** | ประกาศโดย Founder 2026-09-06 ผ่านกลไก staged rollout (WYN-125) — ยังไม่มีขอบเขตฟีเจอร์ที่แน่นอน ยังไม่ปล่อยให้ผู้ใช้ทั่วไป |

## Owner Authority

Owner เป็นผู้มีอำนาจตัดสินใจเรื่อง: Version, Feature, Major changes, Architecture changes, Rollback, Release, Production deployment

Claude Code มีหน้าที่: วิเคราะห์ → พัฒนา → ทดสอบ → รายงานผล — ไม่ใช่ตัดสินใจเปลี่ยน Version หรือ Rollback เอง

## Current State

- Project: WYNOS
- Current Version (ผู้ใช้ทั่วไป): v1.0.0 Beta4
- In Development (บัญชีนักพัฒนาเท่านั้น): v1.0.0 Beta5
- Status: Beta
- Baseline: Current codebase
- Rollback: Manual / Owner approval required
