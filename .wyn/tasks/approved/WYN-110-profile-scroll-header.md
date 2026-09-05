# Design Task — WYN-110

Status: approved (QA รอบ 2 ผ่าน 2026-09-05 — ดู `.wyn/docs/qa/wyn-110-111-round2-qa.md` — ส่งต่อ AI
Deploy & DevOps)
Owner: AI Design → AI Coding
Screen: `ViewProfileScreen` (ทั้งโปรไฟล์ตัวเองและโปรไฟล์คนอื่น)
Purpose: แก้บั๊กที่ Founder รายงาน — หัวโปรไฟล์ไม่เลื่อนหายไปตามการเลื่อนโพสต์ กินพื้นที่จอค้างไว้
ตลอด ทำให้เห็นโพสต์ได้แค่ครึ่งจอ ให้เลื่อนหายไปได้เหมือนหน้า Home + Instagram/Threads
User Flow: ไม่เปลี่ยน — ทุก interaction ทำงานเหมือนเดิม เปลี่ยนเฉพาะกลไกการเลื่อน
Components: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-110-profile-scroll-header.md`
Interactions: ไม่เปลี่ยน
States: ไม่มี state ใหม่
Responsive Behavior: ต้องทดสอบ 320/360/390/430
Accessibility: ไม่กระทบ
Design Rules: ห้ามแตะสี/ตำแหน่งใน header หรือการ์ดโพสต์ ห้ามแตะ ProfileSavedTab/ProfilePopGridTab/
ProfileRepliesTab (นอกขอบเขต ไม่ได้ใช้งานจริง)
Handoff:
1. `view_profile_screen.dart` — Column → NestedScrollView + SliverPersistentHeader(pinned) สำหรับ TabBar
2. 3 แท็บ (ProfileDropGridTab/ProfileRedropsTab/ProfileLikesTab) — ListView.separated →
   CustomScrollView + SliverOverlapInjector + SliverList.separated, ถอด ScrollController ส่วนตัว
3. เทสต์คุม: header เลื่อนหายได้จริง, TabBar sticky, infinite-scroll, pull-to-refresh,
   ตำแหน่งเลื่อนต่อแท็บไม่รีเซ็ตตอนสลับแท็บ
4. flutter analyze + flutter test ผ่านครบ
