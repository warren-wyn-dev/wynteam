# กติกาการทำงานของ WYN AI Company

## อำนาจของ Founder

Founder เป็นผู้มีอำนาจตัดสินใจสูงสุด (final authority) เหนือ:

- วิสัยทัศน์หลักของ WYN (Core Vision)
- โมเดลธุรกิจหลัก (Core Business Model)
- สถาปัตยกรรมหลัก (Major Architecture)
- สถาปัตยกรรมความปลอดภัย (Security Architecture)
- สถาปัตยกรรมการยืนยันตัวตน (Authentication Architecture)
- โครงสร้างฐานข้อมูลแบบทำลายล้าง (Destructive Database Structure)
- โครงสร้างพื้นฐาน production
- การกำกับดูแลทีม AI (AI Team Governance)
- กติกาการอนุมัติ (Approval Rules)

การเปลี่ยนแปลงในหัวข้อเหล่านี้ **ต้องได้รับอนุมัติจาก Founder ก่อนเสมอ** และต้องบันทึกไว้ที่ `.wyn/company/APPROVALS.md`

## สิ่งที่ AI Team ทำได้โดยไม่ต้องขออนุมัติล่วงหน้า

- วิเคราะห์ (Analyze)
- แนะนำ (Recommend)
- วางแผน (Plan)
- ออกแบบ (Design)
- เขียนโค้ด (Code)
- ทดสอบ (Test)
- Debug
- Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว
- ปรับปรุงเอกสาร
- ปรับปรุงกระบวนการภายใน

## สิ่งที่ AI Team ห้ามเปลี่ยนแปลงเองโดยเด็ดขาด

เหมือนรายการ "อำนาจของ Founder" ด้านบน หากมีความจำเป็นต้องเปลี่ยน ให้เขียนคำขออนุมัติ (`APPROVAL_REQUIRED`) บันทึกไว้ที่ `.wyn/company/APPROVALS.md` พร้อม:

1. Proposed change
2. Reason
3. Benefits
4. Risks
5. Files affected
6. Recommendation

จากนั้นรอการอนุมัติจาก Founder ก่อนดำเนินการ

## ความปลอดภัย (Security)

ทีมต้องปกป้องสิ่งต่อไปนี้เสมอ: API keys, Passwords, Tokens, Authentication credentials, ข้อมูลผู้ใช้ (User data), Database credentials, Environment variables, Production credentials

กติกา:

- ห้าม commit secret ใด ๆ ลง git
- ตรวจสอบว่าไม่มี secret หลุดก่อน commit ทุกครั้งที่ทำได้จริง
- ห้ามแสดงข้อมูลส่วนตัวของผู้ใช้ใน log หรือ report
- การเปลี่ยนแปลงสถาปัตยกรรมความปลอดภัยต้องได้รับอนุมัติจาก Founder

## GitHub Safety

ห้ามทำสิ่งต่อไปนี้เด็ดขาด:

- ลบ repository
- ลบ branch สำคัญ
- Rewrite git history
- Force push โดยไม่ได้รับอนุมัติชัดเจน
- Commit secrets หรือ environment files ที่มีข้อมูลอ่อนไหว
- ทำลายข้อมูล production
- ทำการเปลี่ยนแปลงที่ย้อนกลับไม่ได้โดยไม่ขออนุมัติ

Commit message ต้องชัดเจนและใช้ convention (ดู `AGENTS.md`)

## Change Control

สำหรับทุกการเปลี่ยนแปลงโค้ดที่มีนัยสำคัญ:

1. ระบุไฟล์ที่ได้รับผลกระทบ
2. อธิบายเหตุผลของการเปลี่ยนแปลง
3. รัน test ที่เกี่ยวข้อง
4. บันทึกการตัดสินใจเชิงสถาปัตยกรรมที่สำคัญ
5. เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น หลีกเลี่ยง refactor ที่ไม่เกี่ยวข้อง

## Founder Feedback

เมื่อ Founder พูดสิ่งที่บ่งบอกถึงการตัดสินใจถาวร เช่น "จำไว้", "ต่อไปให้ทำแบบนี้", "ไม่เอาแบบนี้", "เปลี่ยนวิธีทำ", "อยากให้ WYN เป็นแบบนี้" ต้องบันทึกไว้ใน `.wyn/company/DECISIONS.md` ทันที และห้ามเพิกเฉยหรือ override คำตัดสินใจของ Founder โดยไม่แจ้ง
