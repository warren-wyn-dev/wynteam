# WYN V1.0.0 — Complete Product Specification (Founder Master Brief)

> **Naming note (2026-08-22)**: Founder เปลี่ยนชื่อแบรนด์ที่ผู้ใช้เห็นจาก **WYN → WYNOS** หลังบันทึกเอกสารนี้ (ดู `.wyn/company/DECISIONS.md`, 2026-08-22 "เปลี่ยนชื่อแบรนด์") — ทุกจุดในไฟล์นี้ที่เขียนว่า "WYN"/"WYN App"/"WYN Admin"/"WYN Chat"/"WYN Top 100" ฯลฯ ให้อ่านเป็น **WYNOS** ในทุกจุดที่ผู้ใช้เห็นจริง (UI/marketing/store listing) — เนื้อหาด้านล่างนี้**คงไว้แบบ verbatim ตามที่ Founder ส่งมาต้นฉบับ ไม่แก้ย้อนหลัง** เพื่อรักษาความถูกต้องของบันทึกประวัติศาสตร์ ส่วน technical identifier (bundle ID, folder name, Supabase project, task ID prefix `WYN-XXX`) ไม่เปลี่ยนตามการรีแบรนด์นี้
>
> บันทึกต้นฉบับเต็มจาก Founder (2026-08-22) แบบไม่ตัดทอน — เป็น **Product Specification หลัก** ของ WYN V1.0.0 ตั้งแต่นี้ไป แทนที่ทิศทางเดิมทั้งหมด (WYN V0.1 CORE APP FEATURE PROMPT ของ 2026-08-14, WYN CLUB brief, WYN PLATFORM MASTER DEVELOPMENT PROMPT ของ ZOKY/SELLER) ในส่วนที่ขัดแย้งกัน — ดูการกระทบต่องานเดิมที่ `.wyn/docs/product/wyn-v1.0.0-roadmap.md` และการตัดสินใจที่เกี่ยวข้องที่ `.wyn/company/DECISIONS.md` (2026-08-22)
>
> อ้างอิงกฎหมายที่ Founder แนบมา: WYN ต้องออกแบบรองรับกฎหมายไทยตั้งแต่แรก โดยเฉพาะ PDPA, กฎหมายธุรกรรมอิเล็กทรอนิกส์, กฎหมายคอมพิวเตอร์ และกรอบ Digital Platform Services (DPS) — การเข้าข่าย/หน้าที่เฉพาะของ WYN ต้องให้ผู้เชี่ยวชาญกฎหมายตรวจจากรูปแบบธุรกิจจริงอีกครั้ง (DPS ครอบคลุมทั้ง Online Communication และ Online Marketplace และ ETDA อัปเดตกฎต่อเนื่อง) — ทีม AI ไม่ใช่ที่ปรึกษากฎหมาย ออกแบบ Compliance Layer ไว้ล่วงหน้าเท่านั้น

## 0. แนวคิดหลัก

WYN = Social + Community

**V1.0 เน้น 4 แกน**: Drop + Club + Chat + Discovery

**ยังไม่เปิดเต็มรูปแบบใน V1.0**:
- ❌ WYN Shop
- ❌ WYN Pop
- ❌ WYN AI เต็มรูปแบบ
- ❌ Marketplace
- ❌ Payment
- ❌ Live
- ❌ Video Call

แต่ Architecture ต้องเตรียมไว้รองรับอนาคต

---

## 1. 🏠 HOME

**Feed** — สองโหมด: For You / Following

**Drop Card แสดง**: Avatar, Display Name, @Username, Verified Badge ถ้ามี, เวลาโพสต์, ข้อความ, รูปสูงสุด 9 รูป, Caption, Hashtag, Mention, External Link, Poll, Location

**Actions**: ❤️ Like · 💬 Comment · 🔄 ReDrop · ↗️ Share · 🔖 Save · ⋯ More

**Statistics**: 👁️ Views · ❤️ Likes · 💬 Comments · 🔄 ReDrops

**User Actions**: Follow · Unfollow · Mute · Block · Report

---

## 2. 📸 DROP

Drop คือ Content หลักของ WYN

**สร้าง Drop รองรับ**: Text, รูปภาพสูงสุด 9 รูป, Caption, Hashtag, Mention, Link, Poll, Location

**Image System** ต้องมี pipeline: Upload → Validate → Compress → Resize → WebP/AVIF → Storage → CDN

รองรับ format: JPG, PNG, HEIC, WebP

สร้างภาพหลายขนาด: Thumbnail, Feed, Full Screen

รูปต้องมี: Preview, Drag/Reorder, Delete, Crop, Compression, Upload Progress, Retry

---

## 3. 📝 DRAFT

ผู้ใช้ทำได้: Save Draft, Edit Draft, Delete Draft, Continue Editing — Draft ต้องเป็น Private

---

## 4. ✏️ EDIT / DELETE DROP

ผู้ใช้แก้ไข Drop ของตัวเองได้ ตั้งกฎได้ เช่น "แก้ไขภายใน 30 นาที" และ: Delete, Soft Delete, Restore ในช่วงเวลาที่กำหนด — Admin ตรวจสอบประวัติได้

---

## 5. ❤️ ENGAGEMENT

**Like**: Like/Unlike, ป้องกัน Like ซ้ำ, นับจำนวน

**Comment**: Comment, Reply, Nested Reply, Like Comment, Delete Comment, Report Comment

**ReDrop** มี 2 แบบ:
- **Standard ReDrop**: แชร์ Drop ไป Feed ตัวเอง
- **Quote ReDrop**: แชร์ + แสดงความคิดเห็น

เครดิตเจ้าของเดิมต้องยังอยู่

---

## 6. 👁️ VIEW SYSTEM

นับ Views อย่างมีระบบ ไม่ใช่ทุก Refresh = 1 View ต้องมี: Unique Viewer logic, Rate limiting, Bot detection, Suspicious traffic detection — เพื่อป้องกันการปั่นยอด

---

## 7. 🔖 SAVE

ผู้ใช้ Save Drop ได้ หน้า Profile → Saved — Private โดยค่าเริ่มต้น

---

## 8. ↗️ SHARE

แชร์ไป: Chat, Copy Link, Share ผ่านระบบมือถือ, Share Profile, Share Drop

---

## 9. 👤 PROFILE

**Header**: Avatar, Cover, Display Name, @Username, Bio, Website, Location, Verified Badge

**Statistics**: Drops, Followers, Following

**Tabs**: Drops, ReDrops, Media, Likes

**Actions**: Follow, Message, Edit Profile

---

## 10. 🔐 PRIVATE ACCOUNT

เลือก Public หรือ Private — Private: Follow Request → User Approve/Reject

---

## 11. 👥 FOLLOW SYSTEM

Follow, Unfollow, Follow Request, Accept, Reject, Remove Follower, Following List, Followers List

---

## 12. 🔍 SEARCH

ค้นหา: Users (ชื่อ/Username), Drops (ข้อความ/Keyword), Hashtags (#มมส), Topics (เช่น iPhone/มหาวิทยาลัย/กีฬา), Clubs

---

## 13. 🔥 DISCOVERY

หน้า Discovery: Trending Now, Trending Topics, Trending Hashtags, WYN Top 100 (จัดอันดับ Content/Creator ตาม Algorithm), Rising (บัญชีที่กำลังเติบโต), Suggested Users, Suggested Clubs

---

## 14. 🔥 TRENDING ENGINE

ต้องไม่ใช้ Like อย่างเดียว

**Trending Score พิจารณา**: Engagement, Engagement Rate, Growth Velocity, Views, Unique Users, Recency, Comments, ReDrops, Saves, Spam Risk

**ต้องลดคะแนนจาก**: Bot, Fake Engagement, Spam, Manipulation

---

## 15. 👥 CLUB

Club = Community ไม่ใช่แค่ Group Chat

**Club Types**: Public, Private

**Club Profile**: Cover, Icon, Name, @ClubUsername, Description, Category, Rules, Members

**Club Tabs**: Latest, Popular, About

---

## 16. Club Roles

Owner, Admin, Moderator, Member

**Admin สามารถ**: Pin Post, Remove Post, Ban Member, Remove Member, Manage Rules, Manage Moderator

---

## 17. Club Posts

สมาชิกสร้าง Drop ใน Club ได้ รองรับ: Text, สูงสุด 9 รูป, Hashtag, Mention, Poll, Location

**สำคัญ**: Club Post ไม่ถูกนับรวม Global Trending โดยตรง — มี 🔥 Club Trending แยกจาก 🌎 WYN Trending — ถ้าผู้ใช้ ReDrop ไปยัง Public Feed จึงเข้าสู่ Global ecosystem ตาม Engagement ที่เกิดใน Public Feed ได้

---

## 18. 💬 WYN CHAT

Founder แนะนำให้มีใน V1.0 แต่เป็น Basic DM

**1:1 Chat**: Text, Image, Reply, Delete Message, Read/Unread, Mute, Block, Report

**Message Request**: คนที่ไม่รู้จักส่งข้อความ → Accept/Delete/Block/Report

**Share เข้า Chat ได้**: Drop, Profile, Club

---

## 19. 🔥 WYN STREAK

ไม่ใช่ P0 — เตรียมเป็น V1.1 แต่ Architecture ต้องรองรับ (เช่น 🔥7 Days 🔥30 Days) — Social Gamification — ไม่ควรบังคับให้ผู้ใช้ต้องคุยเพื่อรักษา Streak

---

## 20. 🔔 NOTIFICATIONS

**Social**: Like, Comment, Reply, ReDrop, Quote ReDrop, Follow, Follow Request, Mention

**Chat**: New Message, Message Request

**Club**: Club Post, Club Mention, Club Announcement, Join Request

**Discovery**: Trending, Top 100

**System**: Security, Policy, Announcement

---

## 21. Notification Settings

ผู้ใช้เปิด/ปิดได้เป็นรายประเภท เช่น Likes, Comments, Follows, Messages, Club, Trending, System

---

## 22. 🛡️ SAFETY

ทุก User/Drop/Comment/Club/Message ต้องมี Report

**Report Categories**: Spam, Scam, Harassment, Hate, Sexual Content, Violence, Privacy, Illegal Content, Copyright, Other

---

## 23. 🚫 BLOCK

Block ทำให้: ไม่เห็น Content กันตามกฎที่กำหนด, ส่ง DM ไม่ได้, Follow ไม่ได้, Mention ไม่ได้, Interaction ถูกจำกัด

---

## 24. 🔇 MUTE

Mute แตกต่างจาก Block — ผู้ใช้ "ไม่อยากเห็นโพสต์ของคนนี้ แต่ไม่อยากให้เขารู้"

---

## 25. 🏛️ MODERATION

Workflow: Report → Moderation Queue → Review → Action (No Action / Warning / Remove Content / Restrict / Suspend / Ban) → Appeal

---

## 26. ⚖️ APPEAL

ผู้ใช้อุทธรณ์การตัดสินบางประเภทได้ ต้องมี: Reason, Evidence, Status, Reviewer, Decision

---

## 27. 📜 PLATFORM RULES

WYN ต้องมี: Terms of Service, Community Guidelines, Privacy Policy, Copyright Policy, Report Policy, Appeal Policy, Future Commerce Terms (สำหรับ WYN Shop ในอนาคต)

---

## 28. 🇹🇭 LEGAL / COMPLIANCE

ตั้งแต่ V1 ควรมีระบบรองรับ: Privacy, Data Access, Data Correction, Data Deletion, Account Deletion, Data Export, Consent Management, Security Incident Workflow, Legal Request Workflow, Audit Log

สำหรับแพลตฟอร์มไทย DPS มีข้อกำหนดเรื่องข้อมูลธุรกิจ เงื่อนไขบริการ เรื่องร้องเรียน และกระบวนการต่าง ๆ ตามประเภท/ขนาดของแพลตฟอร์ม — WYN ควรออกแบบ Compliance Layer ตั้งแต่แรก ไม่รอให้โตแล้วค่อยรื้อระบบ

---

## 29. 🔒 ACCOUNT SECURITY

Email/Phone Login, OTP, Password Reset, Session Management, Logout All Devices, Suspicious Login, Account Recovery, Rate Limit, Brute Force Protection

---

## 30. 📊 USER ANALYTICS

ผู้ใช้เห็นข้อมูลตัวเอง: Views, Likes, Comments, Followers, Growth — ไม่ควรเปิดข้อมูลส่วนตัวของผู้ใช้อื่นเกินความจำเป็น

---

## 31. 📈 CREATOR ANALYTICS

V1 อาจทำ Basic: Views, Engagement, Followers, Best Performing Drop — Advanced Analytics ค่อย V1.1+

---

## 32. 🏆 WYN TOP 100

Top Drops, Top Creators, Rising Creators, Top Clubs — Club Ranking ต้องแยกจาก Global Ranking

---

## 33. 🎨 DESIGN SYSTEM

WYN Brand: 80–90% White / 10–20% Rainbow

Rainbow ใช้กับ: Accent, Highlight, Gradient บางจุด, Active state, Branding — ไม่ใช้ Rainbow ทุกพื้นที่

> **หมายเหตุ**: ต่างจาก Cyan `#00C8FF` + Orange `#FF6B35` ที่ Founder อนุมัติและ implement ไปแล้วครบ 45 หน้าจอ (DS-001–008, 2026-08-15) — Founder ขอให้ AI Design เสนอทางเลือกเปรียบเทียบก่อนตัดสินใจจริง (ดู DECISIONS.md 2026-08-22) ยังไม่ lock

---

## 34. 📱 BOTTOM NAVIGATION

🏠 Home · 🔍 Search · ＋ Drop · 🔔 Notifications · 👤 Profile

Chat ไม่ต้องเป็น Bottom Tab — เข้าผ่าน 💬 Chat icon

---

## 35. ⚙️ SETTINGS

**Account**: Username, Email, Phone, Password, Account Type
**Privacy**: Private Account, DM Permissions, Mention, Comment, Follow
**Notifications**: จัดการทั้งหมด
**Security**: Sessions, Devices, Login History
**Safety**: Blocked, Muted
**Data**: Download Data, Delete Account
**Legal**: Terms, Privacy, Community Guidelines, Copyright

---

## 36. 📊 ADMIN — แยก Application

WYN App ≠ WYN Admin — Admin ต้องเป็นระบบแยกโดยสิ้นเชิง

```
WYN
├── Consumer App
└── WYN Admin
```

---

## 37. 🏢 WYN ADMIN DASHBOARD

DAU, MAU, New Users, Drops, Views, Likes, Comments, ReDrops, Clubs, Messages, Reports, Storage, Errors, Server Health

---

## 38. 👤 ADMIN USER MANAGEMENT

ค้นหา User → ดู Profile/Account status/Reports/Moderation history/Login-security events (ตามสิทธิ์)

**Action**: Warn, Restrict, Suspend, Ban, Unban, Force Logout

---

## 39. 📸 ADMIN CONTENT

Admin ทำได้: Search Drop, Review, Remove, Restore (ตามสิทธิ์), ตรวจ Report, ดู Moderation History

---

## 40. 👥 ADMIN CLUB

Search Club, Review, Suspend, Review Reports, ตรวจ Owner/Admin, ตรวจ Moderation

---

## 41. 🚨 ADMIN REPORT CENTER

Reports → Priority → Risk Classification → Reviewer → Action → Appeal

---

## 42. 📜 AUDIT LOG

ทุก Admin Action สำคัญต้องบันทึก: Admin, Action, Target, Time, Reason, Previous State, New State — ห้าม Admin ปกติลบ Audit Log

---

## 43. 📢 WYN OFFICIAL ANNOUNCEMENT

Admin สร้างประกาศ: System Update, Policy Update, Maintenance, Important Announcement — กำหนดกลุ่มผู้รับได้

---

## 44. 📊 BUSINESS / REVENUE INFRASTRUCTURE

แม้ V1 ยังไม่เปิด Shop เต็มรูปแบบ ให้เตรียม:

**Ad Infrastructure**: Ad Placement, Campaign, Impression, Click, Budget, Reporting

**Promoted Drop**: Architecture รองรับ Campaign/Budget/Duration/Audience/Analytics — ยังไม่ต้องเปิดทั้งหมดทันที

---

## 45. 💰 WYN REVENUE (ระยะยาว)

Ads, Promoted Drop, Creator Support, Business Account, WYN Shop, Seller Services — V1 เน้น User Growth ก่อน

---

## 46. 🛍️ WYN SHOP — FUTURE READY

V1 ยังไม่เปิด Marketplace แต่ Database/API ควรไม่ขัดกับอนาคต:

```
User → Business → Product → Drop → Chat → Order → Payment → Delivery → Review
```

เมื่อเปิด Shop ต้องเพิ่ม Compliance สำหรับ Marketplace/Social Commerce ตามกฎที่ใช้บังคับในเวลานั้น (ETDA กำกับ Online Marketplace และขยายแนวทางไปยัง Social Commerce)

---

## 47. 🖼️ IMAGE INFRASTRUCTURE

ผู้ใช้เลือกไฟล์ (สูงสุด 5 MB) → Client Compression → Server Validation → Resize → WebP/AVIF → Thumbnail → CDN — ไม่ต้องเก็บรูป Original ขนาดใหญ่ทุกครั้ง

---

## 48. ⚡ PERFORMANCE

Lazy Loading, Pagination, Infinite Scroll, Cursor Pagination, CDN, Image Optimization, Database Index, Cache, Rate Limit, Queue — ไม่โหลดทุก Drop พร้อมกัน

---

## 49. 🧠 RECOMMENDATION ENGINE

V1 เริ่มแบบ Rule-based + Ranking พิจารณา: Follow, Interests, Hashtags, Topics, Clubs, Engagement, Recency — ภายหลังค่อยใช้ ML/AI

---

## 50. 🔥 WYN DAILY HABIT LOOP

Trending → Club Activity → New Drops → Comments/Follow → Chat → Notification → กลับ WYN

**ตัวชี้วัด**: DAU, WAU, MAU, D1/D7/D30 Retention, Sessions/User, Time/User, Drops/User, Messages/User

---

## 51. 🧪 QA

ทุก Feature ต้องมี: Unit Test, Integration Test, E2E Test, Security Test, Permission Test, Mobile Test, Error Test

**ต้องทดสอบกรณี**:
- User A พยายามแก้ Drop ของ User B → ต้องไม่สำเร็จ
- Member พยายาม Ban Member → ต้องไม่สำเร็จ
- Admin ไม่มี Permission → ต้องไม่สำเร็จ

---

## 52. 🏗️ ARCHITECTURE

```
WYN
├── Web / Mobile UI
├── Authentication
├── User
├── Profile
├── Drop
├── Engagement
├── Feed
├── Search
├── Trending
├── Club
├── Chat
├── Notification
├── Safety
├── Moderation
├── Analytics
├── Revenue Infrastructure
├── Legal / Compliance
└── Admin
```

---

## 53. 🔮 V1.1 / V2 / V3

**V1.1**: WYN Streak 🔥, Advanced Creator Analytics, Better Recommendation, More Chat features, Creator Support, Promoted Drop

**V2**: WYN Shop 🛍️, Business Account, Seller, Product, Order, Payment, Delivery, Reviews

**V3**: WYN Pop, WYN AI / ZEN, Advanced Creator Economy, Global expansion

---

## 🧭 สรุป WYN V1.0.0

**Core 8 ระบบ** เป็นหัวใจ: 🏠 Home · 📸 Drop · 👥 Club · 💬 Chat · 🔍 Search & Discovery · 🔥 Trending / Top 100 · 🔔 Notification · 🛡️ Safety

**4 ระบบเบื้องหลัง** ที่ห้ามลืม: 🏢 WYN Admin · ⚖️ Legal & Compliance · 📊 Analytics · 💰 Revenue Infrastructure

WYN V1.0.0 ไม่ใช่แค่ "แอปโพสต์รูป" แต่เป็น Social Platform ที่มี Community, Messaging, Moderation และโครงสร้างธุรกิจพร้อมต่อยอด WYN Shop โดยไม่ต้องรื้อระบบหลักภายหลัง

**คำแนะนำของ Founder**: ถือสเปกนี้เป็น Product Specification หลัก ก่อนให้ Claude Code ลงมือเขียนจริง — แบ่งงานเป็น Phase ไม่สร้างทุกระบบรวดเดียว เพื่อให้แต่ละส่วนทดสอบได้และควบคุมต้นทุนได้
