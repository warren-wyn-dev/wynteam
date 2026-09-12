# Design Task — WYN-151

Status: backlog
Owner: AI Design
Screen: Notification List
Purpose: Reskin หน้าจอ Notification List ที่มีอยู่แล้วให้ใช้ Flare design system (wyn-142/wyn-143) แทนของเดิม (Sapphire) โดยไม่เปลี่ยน business logic (navigation, grouping, mark-as-read timing, pagination, tab filter)
User Flow: เปิดหน้าจากแถบ Notifications → เห็นการ์ดขอสิทธิ์แจ้งเตือน (ถ้ามี) → Tab ทั้งหมด/การกล่าวถึง → ลิสต์แบ่งกลุ่มตามวัน → แตะแถวเพื่อไปปลายทางตามประเภทแจ้งเตือน → เลื่อนลงโหลดเพิ่ม/pull-to-refresh
Components: Top App Bar, Card (push permission), Segmented Tab (screen-specific ใหม่), List Item (ขยาย), Avatar, Badge/Chip overlay, Icon-in-circle (hidden-identity types), Loading/Skeleton, Empty State, Secondary Button
Interactions: ดูรายละเอียดในเอกสาร
States: ดูรายละเอียดในเอกสาร
Responsive Behavior: ดูรายละเอียดในเอกสาร
Accessibility: ดูรายละเอียดในเอกสาร
Design Rules: ดูรายละเอียดทั้งหมดใน `.wyn/docs/design/wyn-151-notifications.md`
Handoff: รอ Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding
