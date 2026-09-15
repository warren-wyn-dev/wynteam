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
| WYNOS Web Beta1 | **Current** | `854d571b7548f45b1d12cdd2143580dc4e46312d`, Production Deploy #51 |

## Owner Authority

Owner เป็นผู้กำหนด version ใหม่, ขอบเขต feature, release และ rollback ของ WYNOS Web เท่านั้น
