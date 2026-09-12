# Design Task — WYN-150

Status: backlog
Owner: AI Design
Screen: Search (search, top_100)
Purpose: นิยาม visual ใหม่ (Flare) ของหน้า Search (Discovery + ผลลัพธ์ User/โพสต์/Club) และหน้า Top 100 (อันดับแฮชแท็กกำลังนิยมเต็ม) โดยไม่เปลี่ยน business logic/data-fetching เดิม (submit-only search WYN-080, threshold 2 ตัวอักษร, pagination, Pop tab ที่ยังซ่อนอยู่ WYN-102, ห้ามระบุจำนวนโพสต์ใต้แฮชแท็ก WYN-101)
User Flow: ผู้ใช้เปิดแท็บ Search เห็น Discovery view (แฮชแท็กกำลังนิยม + แนะนำให้ติดตาม) → พิมพ์และ submit คำค้นหา → สลับ Chip Tabs (User/โพสต์/Club) ดูผลลัพธ์แบบ infinite scroll → จาก Discovery กด "ดูอันดับทั้งหมด (Top 100)" เปิด Top 100 Screen → แตะแถวแฮชแท็ก/ผู้ใช้/โพสต์/Club เพื่อไปหน้ารายละเอียด
Components: Search Bar (2c), Segmented Chip Tabs (ดัดแปลงจาก Chip §6), List Item (§10), HashtagRankRow (ดัดแปลงจาก List Item §10), Avatar (§5), ปุ่มติดตาม (compact Primary/Secondary Button §1), Empty State (§12), Loading/Skeleton (§8), Card (§4), Top App Bar (§3)
Interactions: ดูรายละเอียดในเอกสาร
States: ดูรายละเอียดในเอกสาร
Responsive Behavior: ดูรายละเอียดในเอกสาร
Accessibility: ดูรายละเอียดในเอกสาร
Design Rules: ดูรายละเอียดทั้งหมดใน `.wyn/docs/design/wyn-150-search.md`
Handoff: รอ Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding
