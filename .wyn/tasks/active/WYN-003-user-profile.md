# Product Task — WYN-003

Status: active (Design เสร็จแล้ว รอส่งต่อ AI Coding)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (ถัดไป)

Feature: User Profile (View & Edit)

Goal: ให้ผู้ใช้มีตัวตนที่สมบูรณ์กว่าแค่ username — ใส่รูป ชื่อแสดง และคำอธิบายตัวเองได้ เป็นฐานให้ feature ต่อไป (Feed, Follow) แสดงข้อมูลผู้ใช้ได้ครบถ้วน

Target User: วัยรุ่น / Gen Z ที่ต้องการปรับแต่งตัวตนบนแอปให้เป็นของตัวเอง

Problem: หลัง WYN-002 ผู้ใช้มีแค่ username เท่านั้น ไม่มีทางแสดงตัวตน (รูป, ชื่อเล่น, คำโปรย) ให้คนอื่นเห็น และยังไม่มีหน้าจอให้ผู้ใช้จัดการข้อมูลส่วนตัวของตัวเองเลย

Requirements:
- เพิ่มฟิลด์ใน `profiles` table: **display_name** (ชื่อแสดง), **bio** (คำอธิบายสั้น ๆ), **avatar_url** (รูปโปรไฟล์)
- หน้าจอ **ดูโปรไฟล์ตัวเอง**: แสดงรูปโปรไฟล์, ชื่อแสดง, @username, bio
- หน้าจอ **แก้ไขโปรไฟล์**: เปลี่ยนรูปโปรไฟล์ (เลือกจากคลังภาพ/ถ่ายรูปใหม่), แก้ชื่อแสดง, แก้ bio
- อัปโหลดรูปโปรไฟล์ไปเก็บที่ Supabase Storage (bucket `avatars`) ไม่ใช่ base64 ฝังใน database
- เข้าถึงหน้าโปรไฟล์ได้จาก `HomeScreen` (เพิ่มปุ่ม/ไอคอนไปหน้าโปรไฟล์)
- Username ยังคงแก้ไขไม่ได้ในเฟสนี้
- ออกแบบ data model ให้รองรับการ "ดูโปรไฟล์คนอื่น" ได้ในอนาคต

Acceptance Criteria:
- [ ] ผู้ใช้กดเข้าหน้าโปรไฟล์ตัวเองจาก Home ได้ เห็นรูป/ชื่อแสดง/username/bio ที่บันทึกไว้ (หรือค่าว่าง/placeholder ถ้ายังไม่เคยตั้ง)
- [ ] ผู้ใช้แก้ไขชื่อแสดงได้ (1-50 ตัวอักษร) และบันทึกสำเร็จ
- [ ] ผู้ใช้แก้ไข bio ได้ (สูงสุด 160 ตัวอักษร มีตัวนับตัวอักษรให้เห็น) และบันทึกสำเร็จ
- [ ] ผู้ใช้เลือกรูปจากคลังภาพหรือถ่ายรูปใหม่มาเป็นรูปโปรไฟล์ได้ อัปโหลดสำเร็จและแสดงผลทันที
- [ ] ถ้ายังไม่เคยตั้งรูปโปรไฟล์ ต้องมี placeholder ที่ดูดี (ไม่ใช่ค้างว่างเปล่า/broken image)
- [ ] แก้ไขข้อมูลแล้วปิดแอปเปิดใหม่ ข้อมูลยังอยู่ครบ (persist ผ่าน Supabase จริง)
- [ ] ผู้ใช้อื่นแก้ไขโปรไฟล์ของเราไม่ได้ (RLS บังคับ)

Dependencies: WYN-002 (Authentication & Onboarding — เสร็จแล้ว, มี `profiles` table อยู่แล้วให้ต่อยอด)

Priority: สูง — เป็นฐานให้ Feed/Follow ในอนาคต แต่ไม่ใช่ blocker เท่า WYN-002

Risks:
- การอัปโหลดรูปต้องขอ permission เข้าถึงกล้อง/คลังภาพจากระบบปฏิบัติการ (iOS/Android) — ต้องตั้งค่า permission string ใน `Info.plist`/`AndroidManifest.xml` เพิ่ม
- ไฟล์รูปภาพขนาดใหญ่อาจทำให้ upload ช้า/ใช้พื้นที่ Storage เยอะ — ควร resize/compress ก่อนอัปโหลด
- Bio ที่ไม่มีการกรองเนื้อหา (content moderation) อยู่นอก scope ของ WYN-003 แต่เป็นความเสี่ยงระยะยาวสำหรับตอนที่มี public content

Recommendation: ส่งต่อ AI Coding เพื่อ implement ตาม Design Spec ทันที

Handoff: Design เสร็จแล้ว — ดู Design Spec เต็มที่ `.wyn/docs/design/wyn-003-user-profile.md` งานถัดไปคือ AI Coding (`/code`) implement 2 screens (View Profile, Edit Profile) ด้วย Flutter + Supabase (Database + Storage) ตามที่ออกแบบไว้
