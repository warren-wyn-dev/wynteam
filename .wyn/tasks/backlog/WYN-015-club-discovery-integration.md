# Product Task — WYN-015

Status: backlog
Owner: AI Product Manager (เสร็จ) → AI Design (ถัดไป)

Feature: Club Discovery & Integration (Explore Clubs, Search integration, Notification integration, Profile "My Clubs", Home "For You"/"From Your Clubs")

Goal: เชื่อม WYN CLUB (WYN-014, Core System ที่ผ่าน QA แล้ว) เข้ากับระบบหลักของแอปให้ครบวงจร — ให้ผู้ใช้ค้นพบ Club ใหม่ที่ยังไม่เคยเข้าร่วม, ค้นหา Club ผ่านระบบค้นหาเดิม, รู้ตัวทันทีเมื่อมีคำขอเข้าร่วม/ได้รับอนุมัติ/มีคนมาปฏิสัมพันธ์กับโพสต์ตัวเองใน Club, เห็นภาพรวม Club ที่ตัวเองเป็นสมาชิกจากหน้าโปรไฟล์ และเห็นโพสต์จาก Club ที่เข้าร่วมปนอยู่ใน Home ได้

Target User: วัยรุ่น / Gen Z ที่เข้าร่วม Club ไปแล้วจาก WYN-014 แต่ตอนนี้ยังต้องเปิด CLUB section ใน Home เพื่อดู Club ของตัวเองเท่านั้น — ยังไม่มีทางค้นพบ Club ใหม่ที่น่าสนใจ, ไม่มีทางค้นหา Club ผ่านช่องค้นหาหลัก, ไม่รู้ตัวเมื่อมีคนขอเข้าร่วม Club ที่ตัวเองดูแลอยู่ หรือเมื่อคำขอของตัวเองได้รับอนุมัติแล้ว

Problem: WYN-014 ส่งมอบเฉพาะ "แกนกลาง" ของ Club ตามที่ Founder สั่งไว้ชัดเจน (ทำ Core ก่อน อย่าใส่ integration ในรอบแรก) — ผลคือ Club ทุกวันนี้เป็นระบบที่แยกตัวออกจากแอปหลัก: ไม่ปรากฏใน Search (WYN-009), ไม่สร้าง notification เข้าตาราง `notifications` (WYN-012) แม้จะมีเหตุการณ์ที่ผู้ใช้ควรรู้ (คำขอเข้าร่วม, การอนุมัติ, Like/Comment บนโพสต์ตัวเอง) เกิดขึ้นจริงในระบบแล้ว, ไม่ปรากฏใน Profile (WYN-013), และ Home Feed (WYN-007) ก็ยังคงแสดงแค่ Drop/Pop เหมือนเดิมโดยไม่รู้จัก Club post เลย

Requirements:

**Explore Clubs**
- หน้า "สำรวจ Club" ใหม่ (แทนที่ `ExploreClubsPlaceholderScreen` ของ WYN-014) เข้าถึงจากปุ่ม "สำรวจ Club" ใน CLUB section ของ Home
- แสดง Club ที่ **ยังไม่ได้เข้าร่วม** เท่านั้น (Club ที่เข้าร่วมแล้วอยู่ใน "Club ของฉัน" อยู่แล้ว ไม่ต้องซ้ำ) แบ่งเป็น 2 ส่วนตามที่ระบุไว้ใน Founder's WYN CLUB brief: **"กำลังนิยม" (Popular — เรียงตามจำนวนสมาชิก)** และ **"ใหม่ล่าสุด" (New — เรียงตามวันที่สร้าง)** — **ไม่ทำ "แนะนำสำหรับคุณ" (Recommended) รอบนี้** เพราะต้องมี recommendation logic (เช่น based on ความสนใจ/เพื่อนที่เข้าร่วม) ที่ไม่มีข้อมูลรองรับเลยในตอนนี้ (ดู Risks)
- ตัวกรอง Category (ปุ่ม chip แนวนอน) ใช้รายการ category คงที่เดียวกับ `CreateClubScreen` ของ WYN-014 บวก "ทั้งหมด" — filter ฝั่ง client/query ไม่ต้องมี category ranking พิเศษ
- แต่ละ Club แสดงเป็น card (icon/ชื่อ/จำนวนสมาชิก/คำอธิบายสั้น) แตะเปิด `ClubPage` เดิมของ WYN-014 ได้ทันที (reuse หน้าเดิมทั้งหมด ไม่สร้างหน้าใหม่)

**Search integration**
- เพิ่ม tab ที่ 4 "Club" ใน `SearchScreen` (WYN-009) ต่อจาก User/Drop/Pop — ค้นหาจาก Club Name เท่านั้นในรอบนี้ (Founder's brief ระบุ "Club Name/Username/Category/Keywords" แต่ Club ไม่มี concept "username" ของตัวเอง และค้นหาจาก Category/Keywords ต้องมีระบบ tag/keyword ที่ยังไม่มีอยู่ — ดู Risks) reuse debounce+query-box เดิมของ `SearchScreen` ทั้งหมด ไม่สร้างช่องค้นหาแยก
- ผลลัพธ์แสดงเป็น card แบบเดียวกับ Explore Clubs (reuse widget เดียวกัน)

**Notification integration**
- เพิ่ม type ใหม่เข้าตาราง `notifications` เดิมของ WYN-012: **`club_join_request`** (แจ้ง Owner/Admin เมื่อมีคนส่งคำขอเข้าร่วม Private club), **`club_join_approved`** (แจ้งผู้ขอเมื่อ Owner/Admin อนุมัติ), **`club_post_like`**, **`club_post_comment`** (แจ้งเจ้าของโพสต์ Club เมื่อมีคน Like/Comment — มิเรอร์ `like_drop`/`comment_drop` ของ WYN-012 ทุกประการ)
- **ไม่ทำ `club_announcement` รอบนี้**: ฟีเจอร์ "ประกาศ" (Announcement broadcast) ถูกระบุไว้ชัดเจนใน Founder's WYN CLUB brief ว่าเป็นฟีเจอร์อนาคตที่ไม่อยู่ใน Core (และ WYN-015 นี้ก็ไม่ได้เพิ่มฟีเจอร์ Announcement เข้ามาด้วย) — ไม่มีฟีเจอร์ต้นทางให้ trigger notification ประเภทนี้จริง จึงยังทำไม่ได้จนกว่าจะมี Announcement feature ก่อน
- **ไม่ทำ `club_mention` รอบนี้**: เหตุผลเดียวกับ hashtag (WYN-009) และ mention (WYN-012) — ยังไม่มี @mention parsing/entity resolution ในระบบเลย เป็นงานคนละก้อน
- ทุก type ใหม่ enforce self-notification guard ที่ trigger level แบบเดียวกับ WYN-012 เป๊ะ (เช่น Owner/Admin เข้าร่วม Club ตัวเองไม่มีทางเกิดเพราะ trigger ผูก owner membership อัตโนมัติอยู่แล้ว แต่ Like/Comment โพสต์ตัวเองต้อง guard เหมือน Drop/Pop)
- ข้อความ notification type-specific ใหม่ 4 แบบใน `NotificationListScreen` เดิม ("ขอเข้าร่วม Club ของคุณ" / "อนุมัติคำขอเข้าร่วม Club ของคุณแล้ว" / "ถูกใจโพสต์ Club ของคุณ" / "แสดงความคิดเห็นในโพสต์ Club ของคุณ") แตะแล้วพาไปหน้าที่เกี่ยวข้อง (`club_join_request`/`club_join_approved` → `ClubPage` ของ Club นั้น เปิดแท็บ Members ถ้าเป็น join_request, `club_post_like`/`club_post_comment` → `ClubPostDetailScreen` ของโพสต์นั้น)

**Profile integration**
- เพิ่ม section "My Clubs" ใน `ViewProfileScreen` (WYN-013) — แสดงเฉพาะตอนดูโปรไฟล์ตัวเอง (เหมือน Saved tab เดิม) แสดง Club ที่เป็นสมาชิก (Owner/Admin/Moderator/Member ทั้งหมด ไม่แยก role) เป็น horizontal card row สั้นๆ ใต้ปุ่มแก้ไขโปรไฟล์ ไม่ใช่ tab เต็มจอใหม่ (มิเรอร์ตำแหน่ง/ขนาดของ CLUB section ใน Home ของ WYN-014 แต่ไม่มีปุ่มลัด "สร้าง/สำรวจ" ซ้ำ — มีอยู่แล้วใน Home) reuse `ClubMiniCard` เดิมของ WYN-014 ตรงๆ

**Home integration**
- Home Feed (WYN-007) เพิ่ม toggle 2 ตัวเลือกเหนือ Feed หลัก: **"สำหรับคุณ"** (For You — ของเดิม Drop+Pop เรียงเวลา ไม่เปลี่ยน) และ **"จาก Club ของคุณ"** (From Your Clubs — โพสต์ Club จากทุก Club ที่เข้าร่วมแล้ว เรียงเวลาเดียวกัน) — **ไม่ผสม Club post ปนเข้า Feed หลักโดยอัตโนมัติ** เพราะ Founder's brief แยกสองคำว่า "For You" กับ "From Your Clubs" ไว้ชัดเจนว่าเป็นคนละมุมมอง ไม่ใช่ feed เดียวผสมกัน — reuse `ClubPostCard` เดิมของ WYN-014 สำหรับแสดงผลใน tab นี้

Acceptance Criteria:
- [ ] เปิด "สำรวจ Club" → เห็น Club ที่ยังไม่ได้เข้าร่วม แบ่ง "กำลังนิยม"/"ใหม่ล่าสุด" ถูกต้อง ไม่มี Club ที่เข้าร่วมแล้วปนอยู่
- [ ] กรอง Category ใน Explore Clubs ได้ถูกต้อง
- [ ] แตะ Club card ใน Explore Clubs → เปิด `ClubPage` ของ Club นั้นถูกต้อง
- [ ] พิมพ์ค้นหาในแท็บ Club ของ Search → เจอ Club ที่ชื่อตรงกับคำค้น (case-insensitive)
- [ ] มีคนส่งคำขอเข้าร่วม Private club ของฉัน (ที่ฉันเป็น Owner/Admin) → มี notification `club_join_request` ปรากฏพร้อม badge เพิ่ม
- [ ] คำขอเข้าร่วมของฉันถูกอนุมัติ → มี notification `club_join_approved` ปรากฏ
- [ ] มีคน Like/Comment โพสต์ Club ของฉัน → มี notification ปรากฏ (เหมือน Drop/Pop เดิม)
- [ ] Like/Comment โพสต์ Club ของตัวเอง → **ไม่มี** notification เกิดขึ้น
- [ ] แตะ notification แต่ละประเภทใหม่ 4 แบบ → พาไปหน้าที่ถูกต้อง
- [ ] เปิดโปรไฟล์ตัวเอง → เห็น section "My Clubs" แสดง Club ที่เป็นสมาชิกครบ ไม่แสดงตอนดูโปรไฟล์คนอื่น
- [ ] สลับ toggle "สำหรับคุณ"/"จาก Club ของคุณ" ใน Home → เนื้อหาเปลี่ยนถูกต้อง ("สำหรับคุณ" ยังเหมือนเดิมทุกประการ ไม่มี regression)
- [ ] "จาก Club ของคุณ" แสดงเฉพาะโพสต์จาก Club ที่เข้าร่วมแล้วเท่านั้น เรียงเวลาถูกต้อง
- [ ] Drop/Pop/Home เดิม/Follow/Profile เดิม/Search เดิม/Notification เดิม/Club Core (WYN-014) เดิมทั้งหมดยังทำงานปกติ ไม่มี regression

Dependencies: WYN-007 (Home — Approved), WYN-009 (Search — Approved), WYN-012 (Notification — Approved), WYN-013 (Profile V2 — Approved), WYN-014 (Club Core — Approved, dependency หลัก)

Priority: P2 — ต่อจาก WYN-014 ตามที่ Product เสนอไว้ใน Recommendation ของ WYN-014 เอง Founder ยืนยันให้ทำต่อทันทีหลัง WYN-014 ผ่าน QA (2026-08-14)

Risks:
- **"แนะนำสำหรับคุณ" (Recommended) ใน Explore Clubs defer รอบนี้**: ต้องมี signal บางอย่าง (ความสนใจที่เคยระบุ, เพื่อนที่เข้าร่วม, ประวัติการค้นหา) ที่ระบบไม่มีเก็บไว้เลยตอนนี้ — ถ้าจะทำแบบ "สุ่ม" หรือ "เรียงตาม category เดียวกับที่เคยเข้าร่วม" ก็ยังนับเป็นการเดา ไม่ใช่ recommendation ที่มีความหมายจริง เสนอ defer ไปจนกว่าจะมีข้อมูลพฤติกรรมผู้ใช้มากพอ
- **Search Club ทำได้แค่ Name รอบนี้**: Founder's brief พูดถึง "Club Name/Username/Category/Keywords" แต่ Club ไม่มี "username" ของตัวเอง (ต่างจาก user profile) และ Category เป็นแค่ dropdown คงที่ที่ filter ผ่าน chip ใน Explore Clubs ได้อยู่แล้ว ไม่จำเป็นต้องรวมเข้า text search — "Keywords" หมายถึงระบบ tag ที่ยังไม่เคยมี ต้องออกแบบ schema ใหม่ (ตาราง tag แยก หรือ column array) ซึ่งเป็นงานคนละขนาดจาก integration รอบนี้ เสนอทำแค่ Name search (ใช้ pattern เดียวกับ `ilike` ของ WYN-009 ตรงๆ) ก่อน แล้วพิจารณา keyword/tag เป็น task แยกถ้า Founder ต้องการ
- **Notification 4 ประเภทใหม่ ไม่ใช่ 6 ประเภทที่ brief พูดถึง**: brief ต้นฉบับพูดถึง "replies/likes/admin announcements/join requests/mentions/new posts from followed clubs" — งานนี้ทำ 4 จาก 6 (join request, join approved [ไม่ได้อยู่ใน brief ตรงๆ แต่จำเป็นเพื่อให้ requester รู้ผล], post like, post comment) ตัด announcement (ไม่มีฟีเจอร์ต้นทาง), mention (ไม่มี parsing), และ "new posts from followed clubs" (จะทำให้ notification ท่วมถ้า Club มีการโพสต์บ่อย — ไม่ใช่ pattern ที่แอปนี้เคยทำมาก่อนเลยแม้แต่กับ Follow ปกติที่ follow คนแล้วก็ไม่มี notification ทุกโพสต์ใหม่ — สอดคล้องกับ decision เดิมของ WYN-012 ที่ไม่ทำ "new post from followed user" notification เช่นกัน)
- **`club_join_request` ต้อง fan-out ไปหาทุก Owner/Admin ของ Club นั้น ไม่ใช่แค่คนเดียว**: ต่างจาก notification เดิมทั้งหมดของ WYN-012 ที่ recipient มีแค่คนเดียวเสมอ (เจ้าของเนื้อหา) — trigger function ของ `club_join_request` ต้อง `insert...select` วนทุกแถวใน `club_members` ที่ `role in ('owner','admin')` ของ Club นั้น ไม่ใช่ insert แถวเดียว เป็นรูปแบบ trigger ใหม่ที่ไม่เคยทำมาก่อนในโปรเจกต์นี้ ต้องระวังเรื่อง performance ถ้า Club มี Admin เยอะ (ไม่น่าเกิดในทางปฏิบัติ) และต้องยืนยันว่า RLS ของ `notifications` เดิม (`recipient_id = auth.uid()`) ยังใช้ได้ตรงๆ ไม่ต้องแก้อะไรเพิ่ม เพราะ insert หลายแถวก็ยังเป็นแถวละ 1 recipient เหมือนเดิม
- **Home "From Your Clubs" ต้อง query ข้าม Club หลายอันพร้อมกัน**: ต่างจาก `ClubPostsTab` เดิมของ WYN-014 ที่ query เฉพาะ `club_id` เดียว — ต้อง join `club_members` (ของฉันเอง, status=approved) กับ `club_posts` แล้วเรียงเวลา ข้าม Club หลายอัน คล้าย pattern `home_feed`/`saved_feed` view เดิม (UNION ALL) แต่รอบนี้ไม่ต้อง UNION กับ Drop/Pop เพราะเป็น tab แยกจาก "สำหรับคุณ" ตามที่ Founder แยกคำไว้ชัดเจน — อาจจะไม่ต้องสร้าง view ใหม่เลยก็ได้ถ้า query ผ่าน PostgREST ธรรมดา join ได้พอ (`club_posts` select ที่ join `club_members` ผ่าน RLS อยู่แล้วโดยธรรมชาติ เพราะ RLS ของ `club_posts` ก็เช็ค `club_role()` อยู่แล้ว — แค่ query ทุก Club ที่ `club_role() is not null` แทนที่จะ filter `club_id` เดียว)
- ยังไม่มี Content Moderation อัตโนมัติ (นอก scope เหมือนทุก feature ก่อนหน้า)

Recommendation:
1. เริ่ม WYN-015 ทันทีตามที่ Product เสนอไว้ใน WYN-014 และ Founder ยืนยันให้ทำต่อ
2. **Explore Clubs ทำแค่ "กำลังนิยม"/"ใหม่ล่าสุด" รอบนี้ ตัด "แนะนำสำหรับคุณ" ออก** — เหตุผลอยู่ใน Risks (ไม่มีข้อมูลพฤติกรรมรองรับ)
3. **Search Club ทำแค่ Name search** — เหตุผลอยู่ใน Risks (username/keyword ไม่มี concept รองรับ)
4. **Notification ทำ 4 ประเภท (join_request/join_approved/post_like/post_comment) ตัด announcement/mention/new-post-broadcast ออก** — เหตุผลอยู่ใน Risks
5. **Home ใช้ toggle "สำหรับคุณ"/"จาก Club ของคุณ" แยกกันชัดเจน ไม่ผสมเข้า feed เดียว** — ตรงตามที่ Founder แยกคำไว้ในต้นฉบับ
6. **My Clubs section ใน Profile เป็น horizontal row สั้นๆ ไม่ใช่ tab เต็มจอใหม่** — Profile มี 3 tab เต็มอยู่แล้ว (Drop/Pop/Saved) การเพิ่ม tab ที่ 4 จะทำให้ TabBar แน่นเกินไปบนจอมือถือ

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) หน้า Explore Clubs (filter chip, 2 section กำลังนิยม/ใหม่ล่าสุด, card layout) (2) Club tab ที่ 4 ใน SearchScreen (3) ข้อความ+icon type-specific 4 แบบใหม่ใน NotificationListScreen (4) ตำแหน่ง/ขนาด "My Clubs" section ใน ViewProfileScreen (5) toggle UI "สำหรับคุณ"/"จาก Club ของคุณ" เหนือ Home Feed — reuse component เดิมให้มากที่สุด (`ClubMiniCard`, `ClubPostCard`, แถวค้นหาเดิม, โครงสร้าง badge เดิม) ห้ามออกแบบ pattern ใหม่ถ้า pattern เดิมครอบคลุมได้อยู่แล้ว
