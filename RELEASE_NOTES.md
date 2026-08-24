# WYNOS V1.0.0 — Beta 1

เอกสารสรุปสถานะเวอร์ชันปัจจุบันของ **Wynos** (แอปโซเชียล WYN ฝั่งผู้ใช้ทั่วไป — ไม่รวม ZOKY/`seller_app` และ Admin panel ซึ่งมีสถานะแยกต่างหาก ดูหัวข้อ "สิ่งที่ยังไม่รวมใน Beta 1" ด้านล่าง)

อัปเดตไฟล์นี้ทุกครั้งที่ปล่อยเวอร์ชันใหม่ — ไม่ต้องสร้างไฟล์ใหม่ แก้ไขไฟล์นี้ทับแล้วบันทึกลง git ตามปกติ

**อ้างอิงจุดนี้ในโค้ด**: commit `92ce16d` บน branch `claude/pending-tasks-ogs3jb`
(หมายเหตุ: session นี้ push git tag ไม่ได้ — token ที่ใช้ push ได้เฉพาะ branch ที่กำหนดไว้เท่านั้น ใช้ commit hash นี้อ้างอิงแทน หรือถ้าต้องการ tag จริงให้ Founder รัน `git tag v1.0.0-beta1 92ce16d && git push origin v1.0.0-beta1` เองจากเครื่องที่มีสิทธิ์เต็ม)

## ลิงก์ใช้งานจริง

- เว็บ: https://web-neon-sigma-66.vercel.app (Flutter Web build)
- Backend: Supabase project จริง (`kqokpocajhfbidcxpvhh`) — real Postgres, real Auth, real Storage

## เข้าสู่ระบบได้ด้วย

- **Google Sign-In** — ต้องมี Google Cloud OAuth Client ID/Secret ที่ตั้งค่าไว้แล้วใน Supabase
- **อีเมล + รหัสผ่าน** — อีเมลอะไรก็ได้ กี่บัญชีก็ได้ ไม่ต้องยืนยันอีเมล (ปิด email confirmation ไว้เพื่อความสะดวกช่วงทดสอบ)
- ปิดชั่วคราว (โค้ดพร้อมอยู่แล้ว รอแค่ตั้งค่าฝั่งผู้ให้บริการ): Apple Sign-In (ต้อง Apple Developer account), เบอร์โทร/SMS OTP (ต้องมี SMS provider เช่น Twilio ซึ่งมีค่าใช้จ่าย), Guest/Anonymous (เอาออกจาก UI แล้ว แต่โค้ด `signInAnonymously()` ยังอยู่)

## ฟีเจอร์ที่ใช้งานได้ใน Beta 1

- **Home**: ฟีดรวม Drop+Pop, แท็บ สำหรับคุณ/ติดตาม/ล่าสุด/จาก Club, กำลังนิยม, เลื่อนฟีดเต็มจอ (header เลื่อนหายได้, แท็บลอยติดบน)
- **Drop** (โพสต์รูป 1:1) และ **Pop** (คลิปสั้นแนวตั้ง) — Like/Comment/Share/Save/ReDrop/Quote ReDrop/View count
- **Follow system**, **Club** (สร้าง/เข้าร่วม/โพสต์ในกลุ่ม), **Chat** (DM แบบ 1:1)
- **Profile**: แก้ไขข้อมูล, Draft, Recently Deleted, ลบบัญชี, ส่งออกข้อมูล (PDPA)
- **Notification**, **Report + Moderation + Appeal** (ระบบรายงาน/ระงับ/อุทธรณ์เนื้อหา)
- **Poll** ใน Drop, **Hashtag**, **Search**, **Explore**

## สิ่งที่ยังไม่รวมใน Beta 1

- **Admin panel** (`admin/`, จัดการผู้ใช้/เนื้อหา/รายงาน) — โค้ดเสร็จ QA ผ่านแล้ว แต่ยังไม่ deploy ขึ้น hosting จริง (ไม่มี live URL)
- **Push Notification** — โค้ดพร้อม รอ Firebase project จริงจาก Founder
- **ZOKY / seller_app** — คนละ track, ไม่เกี่ยวกับ Beta 1 นี้

## ⚠️ ข้อจำกัดสำคัญที่ต้องรู้ก่อนโปรโมทกว้างขึ้น

**เอกสารกฎหมาย (ข้อกำหนดการใช้งาน/ความเป็นส่วนตัว/แนวทางชุมชน ฯลฯ) ที่ผู้ใช้ต้องกดยอมรับตอนสมัคร ยังเป็น placeholder ที่ยังไม่ผ่านทนายตรวจ ไม่มีผลผูกพันทางกฎหมายจริง** (บันทึกไว้ที่ `.wyn/company/APPROVALS.md`) — ติดป้าย "BETA" ไว้ที่หน้า Welcome แล้วเพื่อบอกผู้ใช้ตรงๆ ว่ายังอยู่ช่วงทดสอบ

## บั๊กที่เจอและแก้แล้วระหว่างทดสอบใช้งานจริงรอบนี้

| ปัญหา | สาเหตุ | แก้แล้ว |
|---|---|---|
| ผู้ใช้ใหม่ทุกคนกดยอมรับเอกสารไม่ได้ (WYN-046) | FK ของ `user_document_acceptances` ชี้ไป `profiles` ที่ยังไม่ถูกสร้าง เพราะ AuthGate ให้ผ่านหน้ารับเอกสารก่อนตั้งชื่อผู้ใช้ | ✅ `acceptMandatoryDocuments()` สร้าง stub profile ก่อน |
| หน้า Home ไถได้แค่ครึ่งจอล่าง | ClubSection/Trending/แท็บ เป็น fixed-height Column ด้านบน กินพื้นที่ตลอด | ✅ เปลี่ยนเป็น CustomScrollView + sticky header |
| Google/Apple Sign-In ใช้กับเว็บไม่ได้ | redirect ตั้งไว้เป็น native URL scheme (`io.wyn.app://`) เท่านั้น | ✅ ใช้ web-appropriate redirect เมื่อ `kIsWeb` |

## วิธี rebuild + deploy เวอร์ชันใหม่ (สำหรับ AI/คนที่ทำงานต่อ)

```bash
# 1. Build Flutter Web ด้วย credentials จริง
cd app
flutter build web --release \
  --dart-define=SUPABASE_URL=https://kqokpocajhfbidcxpvhh.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key จาก Supabase Settings > API>

# 2. Deploy ขึ้น Vercel (project เดิม จะได้ URL เดิม)
cd build/web
vercel deploy --prod --yes --token=<Vercel token จาก vercel.com/account/tokens>
```

**หมายเหตุ**: Vercel free tier limit deploy ได้ 100 ครั้ง/วัน — ถ้าชนลิมิตต้องรอ 24 ชม.

## Credentials ที่ต้องมี (เก็บไว้ที่ Founder ไม่ใช่ในโค้ด)

- Supabase: Project URL, Publishable key, Personal Access Token (สำหรับ apply schema/ตั้งค่า Auth ผ่าน Management API)
- Google Cloud: OAuth Client ID + Secret (ตั้งใน Supabase Auth Providers)
- Vercel: Deploy token
