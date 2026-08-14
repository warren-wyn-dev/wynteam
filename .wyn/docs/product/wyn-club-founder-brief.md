# WYN CLUB — Founder Brief (ต้นฉบับเต็ม, 2026-08-14)

> เอกสารนี้เก็บ spec ต้นฉบับที่ Founder ส่งมาแบบเต็มคำต่อคำ ไว้ให้ AI Product Manager/Design/Coding อ้างอิงได้ครบถ้วนเวลาตัดสินใจแบ่ง scope เป็น task ย่อย — ดูการตัดสินใจสรุปที่ `.wyn/company/DECISIONS.md` (2026-08-14, "เพิ่มฟีเจอร์ใหม่ WYN CLUB")

WYN CLUB — Community Feature

เพิ่มฟีเจอร์ CLUB เข้าไปในหน้า HOME ของแอป WYN

## 1. CLUB คืออะไร

CLUB คือพื้นที่สำหรับสร้างและเข้าร่วม Community / กลุ่มคอมมูนิตี้ ภายใน WYN

ผู้ใช้สามารถสร้าง Club ตามความสนใจ เช่น เกม, เทคโนโลยี, มหาวิทยาลัย, การเรียน, กีฬา, เพลง, ถ่ายภาพ, ซื้อขายสินค้า, อาหาร, พูดคุยทั่วไป

แนวคิดคล้าย Facebook Groups แต่ต้องออกแบบ UI/UX ให้เป็นเอกลักษณ์ของ WYN

## 2. HOME

หน้า Home ยังคงเป็นหน้า Feed หลักของ WYN ด้านบนของ Home เพิ่มส่วน CLUB แสดง Club ที่ผู้ใช้เข้าร่วมและ Club ที่กำลังได้รับความนิยม มีปุ่ม "+ สร้าง Club", "Club ของฉัน", "สำรวจ Club" แสดงรายการ Club แบบ Card ขนาดกะทัดรัด แต่ละ Card แสดง: รูป Club, ชื่อ Club, จำนวนสมาชิก, คำอธิบายสั้น ๆ, ปุ่ม Join / Joined

## 3. CREATE CLUB

กด "+ สร้าง Club" เปิดหน้า Create Club ข้อมูลที่ต้องกรอก: Club Name, Club Description, Club Cover, Club Icon, Category, Privacy

Privacy มี 2 แบบ: Public (ทุกคนค้นหาและเข้าร่วมได้) / Private (ต้องส่งคำขอเข้าร่วม Admin ต้องอนุมัติ)

มีปุ่ม Create Club

## 4. CLUB PAGE

ส่วนบน: Cover Image, Club Icon, Club Name, Description, จำนวนสมาชิก, Join/Joined, Share, More
ด้านล่างมี Navigation: Posts | Members | About

## 5. CLUB POSTS

สมาชิกสร้างโพสต์ภายใน Club ได้ รองรับ: Text, Image, Multiple Images, Link
แต่ละโพสต์มี: Like, Comment, Share, Bookmark, More
โพสต์แสดงเฉพาะสมาชิก Club ตามสิทธิ์ของ Club

## 6. CREATE POST IN CLUB

ภายใน Club มีปุ่ม "+ Create Post" เมื่อสร้างโพสต์เลือกได้ว่าโพสต์ใน "My Profile" หรือ "Club" — ถ้าเข้ามาจาก Club อยู่แล้ว ให้เลือก Club นั้นเป็นค่าเริ่มต้น

## 7. MEMBERS

หน้า Members แสดงสมาชิกทั้งหมด: Profile, Name, Username, Role
Role: Owner, Admin, Moderator, Member — Owner แต่งตั้ง Admin/Moderator ได้

## 8. CLUB ADMIN SYSTEM

Owner/Admin จัดการ Club ได้: Approve Members, Remove Members, Ban Members, Delete Posts, Pin Posts, Edit Club Information, Change Club Privacy, Manage Moderators
Moderator ช่วยดูแลโพสต์/สมาชิกได้ แต่ไม่มีสิทธิ์ระดับ Owner

## 9. PINNED POST

Club มี Pinned Post ได้ — โพสต์สำคัญปักหมุดด้านบน เช่น กฎของ Club, ประกาศ, กิจกรรม, ข่าวสาร

## 10. CLUB RULES

Owner สร้างกฎของ Club ได้ (เช่น ห้ามโฆษณา, ห้ามใช้คำหยาบ, เคารพสมาชิก, ห้าม Spam) สมาชิกอ่านกฎก่อนเข้าร่วม Club ได้

## 11. DISCOVERY

หน้า "Explore Clubs" ให้ค้นหา Club ได้ มี: Search, Categories, Popular Clubs, New Clubs, Recommended Clubs
ตัวอย่าง Category: All, Technology, Gaming, Education, Lifestyle, Food, Sports, Entertainment, Business, Marketplace

## 12. CLUB SEARCH

ระบบ Search ของ WYN ต้องค้นหาได้: Club Name, Username, Category, Keywords

## 13. CLUB NOTIFICATIONS

สมาชิกได้รับ Notification เมื่อ: มีคนตอบโพสต์, มีคนกด Like, มีประกาศจาก Admin, มีคำขอเข้าร่วม, ถูก Mention, มีโพสต์ใหม่จาก Club ที่ติดตาม

## 14. CLUB PROFILE

หน้า Profile เพิ่มส่วน "My Clubs" แสดง Club ที่ผู้ใช้เป็น Owner/Admin/สมาชิก

## 15. HOME INTEGRATION

Club เชื่อมกับ Feed — Home แบ่งเป็น "For You" (โพสต์ทั่วไป) กับ "From Your Clubs" (โพสต์จาก Club ที่เข้าร่วม) กดเข้า Club จากโพสต์ได้ทันที

## 16. UI / UX

ใช้ดีไซน์หลักของ WYN: Mobile First, Clean, Modern, Blue WYN Theme, Rounded Cards, Smooth Animation, Minimal UI, ใช้งานง่ายด้วยมือเดียว, ไม่เลียนแบบ Facebook — Club ต้องรู้สึกเหมือนเป็น Community Space ของ WYN

## 17. BOTTOM NAVIGATION

คง Navigation หลักของ WYN: Home | Drop | Pop | ZOKY | Profile — ไม่สร้าง Club เป็น Bottom Navigation ใหม่ Club จะอยู่ภายใน Home

## 18. DATA STRUCTURE

**Club**: id, name, description, icon, cover, category, privacy, ownerId, createdAt, memberCount
**ClubMember**: id, clubId, userId, role, status, joinedAt
**ClubPost**: id, clubId, userId, content, images, likes, comments, createdAt, pinned

## 19. IMPORTANT

อย่าเปลี่ยนโครงสร้าง WYN เดิมที่ทำไว้แล้วโดยไม่จำเป็น ให้เพิ่ม CLUB เป็น Feature ใหม่ที่เชื่อมกับระบบเดิมได้ ต้องรักษา Existing Home/Drop/Pop/ZOKY/Profile/Post/Like/Comment/Navigation ให้ทำงานเหมือนเดิม

เป้าหมายของ WYN CLUB: สร้างพื้นที่ Community ที่ผู้ใช้ไม่ได้แค่ติดตามคน แต่รวมตัวกันตามความสนใจ ความรู้ มหาวิทยาลัย เกม ธุรกิจ งานอดิเรก และการซื้อขาย ได้ภายใน WYN

ต่อยอดในอนาคตไปสู่: Community Events, Club Marketplace, Club Live, Club Chat, Poll, Announcement, Membership, Creator Community, Business Community — **แต่ใน Version แรกทำเฉพาะ Core Club System ก่อน อย่าใส่ฟีเจอร์อนาคตจนทำให้ระบบซับซ้อนเกินไป**
