# WYNOS Web Version Control

> ประกาศโดย Owner เมื่อ 2026-09-16

## Current Web Version

**WYNOS Web Beta1** คือ baseline ปัจจุบันของเว็บแอป WYNOS สำหรับงานทั้งหมดที่พัฒนาและขึ้น Production แล้วจนถึงจุดนี้

- Product track: WYNOS Web App
- Version: **WYNOS Web Beta1**
- Baseline code commit: `854d571b7548f45b1d12cdd2143580dc4e46312d`
- Baseline production deploy: WYN-158 Production Deploy **#51** (`35008507512`) — success
- Baseline date: 2026-09-16
- Production: `wynos.online`

โค้ด UI/UX, navigation, feed, profile, notification, club, chat, account switching และพฤติกรรมเว็บทั้งหมดที่อยู่ใน `main` ณ baseline commit ข้างต้น ให้ถือว่าเป็นส่วนหนึ่งของ **WYNOS Web Beta1**

## Relationship to WYNOS App Version

WYNOS Web Beta1 เป็น version track ของ **Web App** แยกจาก version หลักของแอปที่บันทึกใน `.wyn/company/VERSION_CONTROL.md` ดังนั้นการบันทึก WYNOS Web Beta1 นี้ **ไม่เปลี่ยน** WYNOS v1.0.0 Beta4/Beta5 ของ app track

## Baseline / Rollback Rule

- การพัฒนาเว็บครั้งถัดไปต้องต่อยอดจาก **WYNOS Web Beta1** จนกว่า Owner จะกำหนด version ใหม่
- หากงานใหม่มีปัญหา ห้าม rollback กลับ baseline นี้เองโดยอัตโนมัติ
- การ rollback หรือเปลี่ยน version ทำได้เมื่อ Owner สั่งอย่างชัดเจนเท่านั้น
- ห้ามลบหรือเปลี่ยนฟังก์ชันเดิมของ WYNOS Web Beta1 โดยพลการ

## Version History

| Version | สถานะ | Baseline |
|---|---|---|
| WYNOS Web Beta1 | **Current — ผู้ใช้ทั่วไป (Public)** | Launch baseline `19f2f5830740ba1cc3d3a23c16ac94bc9185388c` (PR #725), WYN-158 Production Deploy **#275** (`36250184330`) — success, 2026-09-26. เดิม: `854d571b7548f45b1d12cdd2143580dc4e46312d`, Production Deploy #51 |
| WYNOS Web Beta2 | **In development — เฉพาะบัญชีนักพัฒนา (Developer-only)** | ต่อยอดจาก Web Beta1 launch baseline ข้างบน; ยังไม่มี production release |

## Web Beta1 Launch / Web Beta2 (Owner decision, 2026-09-26)

- Owner ตัดสินใจ (AskUserQuestion, 2026-09-26): **WYNOS Web Beta1 = เวอร์ชันผู้ใช้**, **WYNOS Web Beta2 = เฉพาะนักพัฒนา** — รูปแบบเดียวกับ Beta4 (ผู้ใช้) / Beta5 (นักพัฒนา) ของแอปใน `VERSION_CONTROL.md`
- Launch baseline ของ Web Beta1 รวม: Push ตอนปิดแอป (#721), `recipient_id` ใน Push (#722, Edge Function deployed), ตัดโค้ด foreground Push (#723), ตัวเลข unread บนกระดิ่ง/แชท (#724), QA hardening (#725) และ production DB migration `web-beta1-apply-qa-hardening.yml` run `36250193842` (verified)
- งานใหม่ทั้งหมดของ Web Beta2 ต้องอยู่หลัง developer gate (เช่น `is_developer_account`) จนกว่า Owner จะสั่ง release; ห้ามเปลี่ยนพฤติกรรมของ Web Beta1 ที่ผู้ใช้เห็นโดยไม่ได้รับอนุมัติ
- Rollback/version change ยังเป็นอำนาจ Owner เท่านั้น

## Owner Authority

Owner เป็นผู้กำหนด version ใหม่, ขอบเขต feature, release และ rollback ของ WYNOS Web เท่านั้น
