# WYNOS Version Control Policy

> บันทึกโดย Founder เมื่อ 2026-09-01 — กติกานี้มีผลผูกพันกับทีม AI ทุกบทบาททันที ดู `AGENTS.md` หัวข้อ "อ่านก่อนเริ่มงานทุกครั้ง"

## Current Version

**WYNOS v1.0.0 Beta1** คือ Baseline ปัจจุบันของโปรเจกต์

โค้ด ฟีเจอร์ ระบบ UI/UX โครงสร้างฐานข้อมูล API และการตั้งค่าทั้งหมดที่มีอยู่ ณ ตอนนี้ ให้ถือว่าเป็นส่วนหนึ่งของ **WYNOS v1.0.0 Beta1**

ห้ามถือว่าโค้ดปัจจุบันเป็นเวอร์ชันอื่นจนกว่าจะได้รับคำสั่งจาก Owner

รายละเอียดของ v1.0.0 Beta1 (ฟีเจอร์ที่ใช้งานได้, ลิงก์ใช้งานจริง, สิ่งที่ยังไม่รวม) ดูที่ `RELEASE_NOTES.md`

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

Current baseline: **WYNOS v1.0.0 Beta1**

เมื่อ Owner กำหนด Version ใหม่ ให้บันทึก Version ใหม่อย่างชัดเจนในไฟล์นี้ (อัปเดตหัวข้อ "Current Version" ด้านบน) และรักษาประวัติ Version ก่อนหน้าไว้ในหัวข้อ "Version History" ด้านล่าง

ห้ามเขียนทับหรือทำลาย Version history โดยไม่จำเป็น

## Version History

| Version | สถานะ | หมายเหตุ |
|---|---|---|
| v1.0.0 Beta1 | **Current** | Baseline ปัจจุบัน — ดู `RELEASE_NOTES.md` |

## Owner Authority

Owner เป็นผู้มีอำนาจตัดสินใจเรื่อง: Version, Feature, Major changes, Architecture changes, Rollback, Release, Production deployment

Claude Code มีหน้าที่: วิเคราะห์ → พัฒนา → ทดสอบ → รายงานผล — ไม่ใช่ตัดสินใจเปลี่ยน Version หรือ Rollback เอง

## Current State

- Project: WYNOS
- Current Version: v1.0.0 Beta1
- Status: Beta
- Baseline: Current codebase
- Rollback: Manual / Owner approval required
