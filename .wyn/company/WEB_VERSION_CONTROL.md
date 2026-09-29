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
| WYNOS Web Beta2 | **Suspended — หยุดพัฒนา 2026-09-29** | ฟีเจอร์ที่เสร็จแล้วถูกเปิดให้ผู้ใช้ทั่วไปและรวมกลับเข้า WYNOS Web Beta1; ห้ามเริ่มงานใหม่ใน track นี้ |

## Web Beta1 Development Policy / Web Beta2 Suspended

- Owner decision 2026-09-29: **ระงับ WYNOS Web Beta2** และไม่พัฒนาฟีเจอร์ใหม่ใน track นี้อีก
- ฟีเจอร์เดิมจาก Beta2 ที่เปิดให้ผู้ใช้ทั่วไปและนับเป็นส่วนหนึ่งของ **WYNOS Web Beta1**: WYN-159 Threads-style chat, WYN-135 Club chat edit/pin/search และ WYN-137 Club announcements
- งานเว็บใหม่ทั้งหมดพัฒนาภายใต้ **WYNOS Web Beta1** เท่านั้น
- ฟีเจอร์ใหม่ที่ผู้ใช้มองเห็นต้องใช้ staged rollout ตาม WYN-125: **บัญชีนักพัฒนาเห็นก่อน** ผ่าน `is_developer_account()`; ผู้ใช้ทั่วไปเห็น behavior เดิมจนกว่า Owner จะสั่งเปิด
- Per-PR Vercel staging ยังคงใช้เป็น QA gate ก่อน merge; ชื่อเวอร์ชันของงานยังเป็น WYNOS Web Beta1
- Rollback/version change ยังเป็นอำนาจ Owner เท่านั้น

## Owner Authority

Owner เป็นผู้กำหนด version ใหม่, ขอบเขต feature, release และ rollback ของ WYNOS Web เท่านั้น
