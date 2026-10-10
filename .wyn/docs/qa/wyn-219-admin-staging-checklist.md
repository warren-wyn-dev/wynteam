# WYN-219 — Admin Staging QA Checklist

ใช้ทดสอบบน **Admin preview (staging)** ก่อนขออนุมัติ deploy production ครอบคลุม Phase 1 (เมนู, #1076), หน้าสิทธิ์ทีมงาน (#1080) และการค้นหาผู้ใช้ (#1081)
ทดสอบบนมือถือ (กว้าง ~390px) และคอมพิวเตอร์ ทำเครื่องหมาย ✅ / ❌ และจดสิ่งที่ผิดปกติ

## ก่อนเริ่ม

- [ ] Admin preview deploy สำเร็จ (`deploy-admin.yml`, target `preview`) และได้ URL
- [ ] บัญชีทดสอบ: **A** = Founder (admin), **M** = moderator (ถ้ามี)
- [ ] ระบุว่า foundation (#1078) ถูก apply กับฐานข้อมูลแล้วหรือยัง: ☐ ยัง ☐ แล้ว (เปลี่ยนผลที่คาดหวังในหัวข้อ 3)

## 1. เมนูใหม่ — บัญชี A (admin)

- [ ] เห็นหัวข้อตามลำดับ: ภาพรวม · WYNOS Account · WYNOS Social · WYNOS Food · WYNOS Merchant · WYNOS Maps · ระบบ
- [ ] Food มี: Stores, Orders, Coupons, Campaigns, Ads, Promo Notifications — กดแล้วเปิดหน้าถูก
- [ ] Maps → Places เปิด `/maps/places` และข้อมูลสถานที่/รูปขึ้นตามเดิม
- [ ] พิมพ์ `/food/places?category=restaurant` เอง → ไปที่ `/maps/places?category=restaurant`
- [ ] หน้าร้าน (Food → Stores → เลือกร้าน) ปุ่ม "เปิด Places Manager" ไปที่ Maps → Places
- [ ] เปิดออเดอร์รายการหนึ่ง (`/food/orders/<id>`) → เมนู Orders ไฮไลต์ และหัวหน้าจอแสดง "Orders"
- [ ] มือถือ: แถบเมนูล่างเลื่อนซ้าย-ขวาได้ ชื่อเมนูไม่ซ้อนกัน หน้าไม่เลื่อนแนวนอน
- [ ] ทุกหน้าเดิม (Dashboard, Users, Moderation, Reports, Announcements, Merchants, Audit Log) ยังทำงานเหมือนเดิม

## 2. เมนูใหม่ — บัญชี M (moderator)

- [ ] **ไม่เห็น** Orders และ Ads ในเมนู
- [ ] พิมพ์ `/food/orders` และ `/food/ads` เอง → เห็นข้อความ "เฉพาะ Admin" (server ยังปฏิเสธ)
- [ ] เห็นและใช้ Moderation / Reports ได้ตามเดิม

## 3. หน้าสิทธิ์ทีมงาน (`/team`)

**ถ้า foundation ยังไม่ apply:**
- [ ] บัญชี A ไม่เห็นเมนู "Team Permissions"
- [ ] พิมพ์ `/team` เอง → "ระบบสิทธิ์ทีมงานยังไม่ได้ติดตั้งในฐานข้อมูล (WYN-219)" และหน้าอื่นทำงานปกติ

**ถ้า foundation apply แล้ว (A เป็น super admin):**
- [ ] A เห็นเมนู ระบบ → Team Permissions
- [ ] moderator เดิมแสดงในรายชื่อพร้อม WYNOS Social · แก้ไขได้
- [ ] ค้นหาผู้ใช้ทดสอบ → ให้สิทธิ์ WYNOS Maps · ดูอย่างเดียว → ขึ้นในรายชื่อ
- [ ] กด "เปลี่ยนเป็นแก้ไขได้" → ระดับเปลี่ยน
- [ ] กด "ถอนสิทธิ์" → ถามยืนยัน → หายจากรายชื่อ
- [ ] Audit Log มีรายการ admin_permission_granted / admin_permission_revoked ครบ
- [ ] บัญชี M: ไม่เห็นเมนู Team Permissions; พิมพ์ `/team` เอง → "หน้านี้จัดการได้เฉพาะ super admin"

## 4. การค้นหาผู้ใช้ (#1081)

- [ ] User Management: ค้นหาชื่อไทย / username ปกติ → พบตามเดิม
- [ ] ค้นหา `a,platform_role.eq.admin` → ไม่ error และไม่ได้รายชื่อ admin ทั้งหมดออกมา (ค้นเป็นข้อความธรรมดา)
- [ ] ค้นหา `%` หรือช่องว่าง → ไม่มีผลลัพธ์ ไม่ error

## ผล

- ผู้ทดสอบ / วันที่:
- ผล: ☐ PASS ☐ FAIL (แนบรายการที่ ❌)
- CRITICAL/HIGH ที่พบ: block การ deploy production ตาม `AGENTS.md`
