# Design Task — WYN-133

Status: completed
Owner: AI Design
Screen: Club Chat — Channel List + Channel Room (Discord-style navigation)
Purpose: แทนที่แถบชิปห้อง+เนื้อหาแชทในหน้าเดียว ด้วย 2 หน้าจอ: หน้ารายชื่อห้อง และหน้าห้องแชทเต็มจอที่ navigate เข้าไป
User Flow: เปิดแท็บแชท → เห็นรายชื่อห้อง → แตะห้อง → push ไปหน้าห้องเต็มจอ (AppBar โชว์ชื่อห้อง) → กดย้อนกลับ → กลับหน้ารายชื่อห้อง
Components: header row (label + "+" เฉพาะ Owner/Admin), ListTile-based channel list (ds-005 entity-browse, ไม่มี divider), Channel Room = Scaffold+AppBar ครอบ ClubChannelChatView เดิม
Interactions: tap row = push route, back/swipe-back/system back = pop, long-press row หรือ "⋮" บน AppBar = manage sheet เดิม, "+" = create-channel dialog เดิม
States: normal / กลับจากห้อง (unread เคลียร์) / loading (เดิม) / banned mid-chat (pop กลับ list แทน switch ไป Posts) / non-manager (ไม่มีปุ่มจัดการ) / non-developer (แท็บทั้งหมดยัง gate เหมือนเดิม)
Responsive Behavior: single-column list/column ปกติ ไม่มีการเปลี่ยนแปลงต่อขนาดจอ
Accessibility: คง Semantics label ของ unread state, touch target ขั้นต่ำ touchTargetMin, back button ใช้ semantics มาตรฐานของ AppBar/Navigator
Design Rules: ห้ามคิด visual ใหม่ — reuse สี/สไตล์/dialog/sheet เดิมทั้งหมดจาก club_channel_switcher.dart, ใช้ ds-005 entity-browse pattern (ไม่มี divider), ไม่แตะ DM system ใดๆ, คง gate isDeveloperAccount() เดิม
Handoff: ส่งต่อ AI Coding — spec เต็มอยู่ที่ .wyn/docs/design/wyn-133-club-chat-channel-navigation.md
