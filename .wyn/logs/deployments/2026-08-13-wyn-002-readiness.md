# Deployment Log — WYN-002 Readiness Assessment

Date: 2026-08-13
Release: WYN V0.1 — WYN-002 (Authentication & Onboarding)
Result: **ไม่ deploy** — readiness assessment เท่านั้น ยัง blocked อยู่

## สรุป

WYN-002 ผ่าน QA รอบ 3 (code/static level) แล้ว แต่ยังไม่มีโครงสร้างพื้นฐานจริงให้ deploy ไปลง:
- ไม่มี Supabase project จริง
- ไม่มี native OAuth config (URL scheme, Apple Sign-In capability)
- ไม่เคย `flutter build` สำเร็จเลยแม้แต่ครั้งเดียว (ไม่มี Android SDK/Xcode ในทุก environment ที่ใช้ทำงานมา)
- ไม่มี distribution channel (TestFlight/Firebase App Distribution/Play Internal Testing) ตั้งค่าไว้

## Deployment Target ที่ Founder อนุมัติ

**Internal Testing** (ทีมภายในเท่านั้น) — TestFlight (iOS) + Firebase App Distribution หรือ Google Play Internal Testing Track (Android) — ไม่ใช่ public store release ในตอนนี้

## รายการที่ต้องทำก่อน deploy จริงได้ (ดูรายละเอียดเต็มใน `.wyn/tasks/approved/WYN-002-authentication-onboarding.md`)

ขั้นตอนที่ต้องการ Founder โดยตรง (AI ทำแทนไม่ได้ — ต้องสร้าง account/ผูกบัตรเครดิต/organization จริง):
- สร้าง Supabase project จริง
- สร้าง Google Cloud OAuth Client ID
- ผูก Apple Developer account
- อนุมัติงบประมาณ SMS OTP provider (เช่น Twilio)

ขั้นตอนที่ AI Deploy & DevOps ทำต่อได้เมื่อมี account/project ข้างต้นแล้ว:
- ตั้งค่า native URL scheme + Apple Sign-In capability
- Build จริง (`flutter build apk --release`, `flutter build ipa`)
- ตั้งค่า distribution channel
- จัดการ CI secrets อย่างปลอดภัย

## Rollback Plan

- Code: git revert บน `main`
- Database: versioned SQL migration files (เริ่มจาก `supabase/schema.sql`)
- Distribution: TestFlight/Firebase App Distribution รองรับ rollback เวอร์ชันในตัว
