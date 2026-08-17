# Product Task — WYN-029

Status: backlog
Owner: AI Product Manager

Feature: Profile Identity Expansion (Username edit + Website + Cover) + Pinned Drop Post

Goal: Profile Editor ปัจจุบัน (WYN-003/013) แก้ได้แค่ avatar/display name/bio — master prompt ต้องการ username (แก้ได้+validate uniqueness), website, cover photo เพิ่มเติม และ Pinned Post บน Profile (ตอนนี้ pin มีแค่ใน Club post เท่านั้น ไม่มีบน Drop/Profile เลย)

Target User: ผู้ใช้ WYN ทุกคนที่ต้องการปรับแต่งตัวตนบน Profile ให้ครบ และโชว์ Drop ที่ภูมิใจที่สุดไว้บนสุด

Problem: ผู้ใช้เปลี่ยน username ไม่ได้เลยหลัง sign-up (ต้องตรวจ CONTEXT.md/WYN-002 ว่า username ตั้งตอนไหน — ถ้าตั้งตอน onboarding ครั้งเดียวและแก้ไม่ได้เลย เป็น gap จริง), ไม่มีที่ใส่ลิงก์เว็บไซต์/social อื่น, ไม่มี Cover photo ให้ Profile ดูมีเอกลักษณ์, และไม่มีทาง "ปัก" Drop เด่นไว้บนสุดของ Profile ให้คนเห็นก่อน

Requirements:

R1. **Schema**: เพิ่มคอลัมน์ `website text`, `cover_url text` ให้ตาราง `profiles` (nullable, additive ไม่กระทบข้อมูลเดิม) — `username` มีอยู่แล้วตั้งแต่ WYN-002 ต้องตรวจสอบว่ามี unique constraint แล้วหรือไม่ (ถ้ายังไม่มีต้องเพิ่ม พร้อม validation format เช่น a-z0-9_ ความยาว 3-20 ตัวอักษร)
R2. **Editor**: เพิ่ม field username (แก้ได้ พร้อม uniqueness check ผ่าน DB constraint/query ก่อน submit, แสดง error ชัดเจนถ้าซ้ำ), website (validate เป็น URL format ที่สมเหตุสมผล, ไม่บังคับกรอก https:// ถ้าไม่ได้พิมพ์), cover photo (image_picker คล้าย avatar แต่สัดส่วนกว้าง เช่น 16:9 หรือ 3:1 ให้ Design ตัดสินใจ)
R3. **Pinned Drop Post**: เพิ่มคอลัมน์ `pinned_at timestamptz` (nullable) ให้ตาราง `drops` — เจ้าของ Drop เท่านั้น pin/unpin ได้ (RLS update policy จำกัดด้วย `author_id = auth.uid()`, จำกัด pin ได้ทีละ 1 โพสต์ต่อคน — pin โพสต์ใหม่ต้อง unpin โพสต์เก่าอัตโนมัติ) แสดง Pinned Drop ไว้บนสุดของ Profile's Drop tab พร้อม label "ปักหมุด" — More Menu ของ Drop (ที่จะมาจาก WYN-026) เพิ่มตัวเลือก Pin/Unpin เฉพาะเจ้าของ
R4. User อื่นห้าม Pin/Unpin Drop ของคนอื่นเด็ดขาด — ต้องมี RLS + client-side UI guard สองชั้น (double-gate pattern เดียวกับที่ WYN-015 ใช้กับ Club section)

Acceptance Criteria:
- [ ] แก้ username เป็นค่าที่ไม่ซ้ำใคร → สำเร็จ, แสดงชื่อใหม่ทุกจุดที่เคยอ้างอิง username เดิม (Search, การ์ด, comment mention)
- [ ] แก้ username เป็นค่าที่มีคนใช้แล้ว → error ชัดเจน ไม่ submit สำเร็จ
- [ ] แก้ website ด้วย URL ที่ไม่ถูกต้อง → validation error ก่อน submit
- [ ] อัปโหลด Cover photo สำเร็จ แสดงผลถูกต้องบน Profile ตัวเอง/คนอื่น
- [ ] Pin Drop ของตัวเอง → ขึ้นบนสุดของ Drop tab ใน Profile พร้อม label ปักหมุด
- [ ] Pin โพสต์ใหม่ → โพสต์เก่าที่เคย pin ถูก unpin อัตโนมัติ (pin ได้ทีละ 1 เท่านั้น)
- [ ] พยายาม pin Drop ของคนอื่น (เช่น แก้ request ตรงๆ) → RLS บล็อก ไม่สำเร็จ
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-003/013

Dependencies: WYN-003 (Profile editor เดิม), WYN-013 (Profile V2 tabs), WYN-026 (More Menu ที่จะมี Pin/Unpin — ถ้า WYN-026 ยังไม่เสร็จ ให้ทำปุ่ม Pin แยกเป็นปุ่มเฉพาะบน Drop Detail ของตัวเองไปก่อนได้ ไม่ต้องรอ WYN-026 เพราะ ไม่ใช่ hard dependency)

Priority: กลาง

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Username uniqueness ถ้าไม่มี DB constraint มาก่อนอาจมีข้อมูลซ้ำอยู่แล้ว | กลาง | ตรวจสอบข้อมูลจริงก่อนเพิ่ม constraint (ถ้ามีซ้ำจริงต้องมี migration path แยก ไม่ใช่แค่เพิ่ม constraint เฉยๆ แล้วพัง) |
| R2 | Pin ได้มากกว่า 1 โพสต์พร้อมกันถ้า auto-unpin logic ผิด | ต่ำ | ใช้ DB trigger/transaction เดียวกัน (unpin เก่า+pin ใหม่ในทีเดียว) เขียน test ยืนยันชัดเจน |

Recommendation: ทำหลัง WYN-024 (เพื่อให้แน่ใจว่า Pin ทำงานถูกกับ Drop ที่มีหลายรูปแล้ว) แต่ไม่ต้องรอ WYN-025/026

Handoff: ส่งต่อ AI Design เพื่อออกแบบ Editor layout ใหม่ + ตำแหน่ง Pin control แล้วส่งต่อ AI Coding
