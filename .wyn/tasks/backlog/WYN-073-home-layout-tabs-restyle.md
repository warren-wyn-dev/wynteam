# Design Task — WYN-073

Status: backlog
Owner: AI Design
Screen: Home
Purpose: 1) จัดลำดับ component ของ Home ใหม่ให้ตรง mockup (Header → Banner → Tabs → New-posts pill → Feed) 2) เอา ClubSection + Trending section ออกจาก Home (ยังเข้าถึงได้ผ่านแท็บค้นหา ไม่เสีย feature) 3) เปลี่ยนสไตล์แท็บ feed-mode จาก SegmentedButton มีกรอบ → text tabs เปล่า + เส้น underline indicator (สี rainbow ตาม DS-009 เดิม ไม่เปลี่ยนเป็น sapphire) — Header (ไอคอนแชท) ไม่เปลี่ยนแปลง ยืนยันกับ Founder แล้วว่าเก็บไว้ตามเดิม
User Flow / Components / Interactions / States: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-073-home-layout-tabs-restyle.md`
Responsive Behavior: ต้องกัน overflow ที่ 360px width เหมือนเกณฑ์เดิมของ WYN-024
Accessibility: touch target แท็บ ≥44x44, Semantics label เดิมคงไว้
Design Rules: ไม่แตะสี/token อื่นนอกจากที่ระบุ, ห้ามลบไฟล์ widget ที่ยังมี declare อยู่ (ClubSection/TrendingTile) แค่เลิก reference จาก Home
Handoff: ส่งต่อ AI Coding (`/code`) — แก้ไฟล์เดียว `home_feed_screen.dart` ตาม Handoff เต็มในเอกสาร design ต้องผ่าน AI QA & Security ก่อน deploy เสมอ (ห้ามข้าม QA)
