# WYNOS Web Beta1 — Baseline Snapshot

Date: 2026-09-16

## Release

- Version: **WYNOS Web Beta1**
- Baseline code commit: `854d571b7548f45b1d12cdd2143580dc4e46312d`
- Production deploy: WYN-158 Production Deploy #51 (`35008507512`)
- Deploy result: success
- Production route verification: success

## Scope

Snapshot นี้ครอบคลุมงานเว็บทั้งหมดที่ merge และ deploy แล้วถึง baseline commit ข้างต้น รวมถึงการปรับ UI/UX และ behavior ล่าสุดของ Home, post actions, profile, quote ReDrop composer, notification screen, client-side navigation/performance, account switching สูงสุด 9 บัญชี และการปรับหน้าเว็บให้ใกล้ native app มากขึ้น

รายละเอียด implementation จริงให้ยึด source code ณ baseline commit เป็น source of truth

## Version Policy

ตั้งแต่ snapshot นี้เป็นต้นไป ให้ถือว่าเว็บ Production ณ จุดนี้คือ **WYNOS Web Beta1** จนกว่า Owner จะประกาศ version ใหม่ ห้าม rollback อัตโนมัติและห้ามเปลี่ยนชื่อ version เอง
