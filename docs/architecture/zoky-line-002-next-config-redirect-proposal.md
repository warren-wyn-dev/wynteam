# ข้อเสนอ: แยก LIFF ออกจากกฎ "เด้งออกเบราว์เซอร์" ใน next.config.ts (ร่าง รอ Founder)

สถานะ: **Proposed — ยังไม่แก้โค้ด ยังไม่ deploy** (ต้อง Founder approval: เปลี่ยนพฤติกรรม routing ของทุกโดเมน wynos.online)
ที่มา: `docs/qa/zoky-line-002/real-flow-code-analysis.md` (อ่านจากโค้ด ยังไม่ยืนยันบนเครื่องจริง)

## กฎปัจจุบัน (web/next.config.ts ฐาน production a70cbb0, ฟังก์ชัน redirects)
ทุก request แบบ page navigation ที่ UA ตรง `.* Line/.*` และไม่มี `?openExternalBrowser` หรือ `?code=` จะถูก 307 ไป `?openExternalBrowser=1`
เจตนาเดิม (ตามคอมเมนต์ในไฟล์): ลิงก์ wynos.online ที่กดในแชท LINE เปิดในเบราว์เซอร์ของ LINE ที่ไม่ได้ล็อกอินและ Google login ถูกปฏิเสธ จึงให้ LINE เปิด Safari/Chrome แทน
ข้อยกเว้นปัจจุบัน: `/api`, `/_next`, `/auth`, path ที่มีจุด, และ `?code=`

## ปัญหาที่สงสัย (สมมติฐาน ต้องยืนยันด้วยเครื่องจริง)
กฎแยกไม่ออกระหว่าง "ลิงก์ในแชท" กับ "เว็บวิว LIFF/Mini App" (ทั้งคู่มี `Line/` ใน UA) ลูกค้าที่เข้า Mini App อาจถูกเด้งออกจาก LINE ระหว่างทาง (เช่น หลัง /line replace ไป /s/<code> หรือหลังล็อกอินอีเมลสำเร็จ replace ไป /food) ทำให้เสียบริบท LIFF ร้าน และตะกร้า

## ข้อเสนอ (เล็กที่สุด)
เพิ่มเงื่อนไข `missing` ให้กฎนี้ข้าม request ที่มาจาก LIFF:
```ts
missing: [
  { type: "query", key: "openExternalBrowser" },
  { type: "query", key: "code" },
  { type: "header", key: "user-agent", value: ".*LIFF/.*" }, // เว็บวิว LIFF
],
```
**ต้องยืนยันก่อน:** UA จริงของเว็บวิว LIFF บน iOS/Android มีคำว่า `LIFF/` หรือไม่ (ผมจำได้ว่าเป็นเช่นนั้น แต่ยังไม่ได้พิสูจน์) ขอ `navigator.userAgent` จากเครื่องจริงใน LIFF ก่อนเขียนโค้ด ถ้าไม่มี `LIFF/` ต้องใช้สัญญาณอื่น (เช่น path /line และ query `liff.state` ที่ LINE ใส่ตอนเปิด endpoint)

## ผลที่ตามมา / trade-off
- ลูกค้าใน LIFF จะไม่ถูกเด้งออก แต่ Google login ใน LIFF WebView ยังถูกปฏิเสธ (กฎนี้ไม่ได้แก้เรื่องนี้) จึงต้องพึ่ง LINE Login (อนุมัติหลักการแล้ว) หรือทางอีเมล/รหัสผ่าน
- กล่อง LineLoginGuidance จะโผล่ใน LIFF ที่ /food/login เพราะ UA มี `Line/` (นี่คือที่ที่กล่องมีประโยชน์จริง)
- ลิงก์ในแชท (ไม่ใช่ LIFF) ยังถูกเด้งออกเหมือนเดิม

## Affected files
`web/next.config.ts` (1 จุด) + test ที่ล็อกกฎ redirect (ค้นหา test ที่อ้างถึง openExternalBrowser ก่อนแก้) ไม่แตะ DB/auth

## Rollback
revert commit เดียวหรือ Vercel Instant Rollback ไป deployment ก่อนหน้า (ไม่มี migration)

## ขั้นตอนถ้าอนุมัติ
1. ขอข้อมูล UA จริงจาก LIFF (ผู้ทดสอบเปิด Mini App แล้วแสดง navigator.userAgent หรือส่ง screenshot หน้า debug)
2. implement + unit test กฎ (regex ตรงกับ/ไม่ตรงกับ UA ตัวอย่าง)
3. QA & Security → staging → ทดสอบใน LIFF จริง → Founder อนุมัติ production

## สิ่งที่ Founder ต้องตัดสินใจ
- [ ] อนุมัติหลักการแก้กฎ redirect (ตามเงื่อนไขว่า UA จริงยืนยันแล้ว)
- [ ] ผู้ทดสอบส่ง UA จริงจากเครื่องที่เปิด Mini App
