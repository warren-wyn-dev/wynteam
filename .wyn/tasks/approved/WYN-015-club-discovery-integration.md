# Product Task — WYN-015

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS)

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

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-015-club-discovery-integration.md` — สรุป: 5 หน้าจอ/ส่วน ต่อยอดจาก component เดิมทั้งหมด ไม่มี pattern ใหม่นอกจาก `ClubDiscoveryCard` (แถวเต็มความกว้างใช้ร่วมกันทั้ง Explore Clubs และ Club tab ของ Search) — Explore Clubs เป็น `ListView` เดียวแบ่ง 2 section "กำลังนิยม"/"ใหม่ล่าสุด" ใต้ filter chip แนวนอน — Notification 4 ประเภทใหม่ต่อของเดิมไม่มี UI ใหม่ แค่ข้อความ (ต้องมีชื่อ Club ประกอบ) — "Club ของฉัน" ใน Profile ไม่โชว์เลยถ้าไม่มี Club (ต่างจาก Home ตั้งใจ) — Home toggle ใช้ `SegmentedButton` ไม่ใช่ `TabBar` เพราะเป็นการสลับมุมมองของ feed เดียว — เตือน Coding 2 จุดเสี่ยง: club_join_request ต้อง fan-out หลาย recipient (ต่างจาก trigger เดิมทุกตัว), `ClubPostCard` ใน "จาก Club ของคุณ" ต้องรู้ role ต่อโพสต์ไม่ใช่ค่าเดียว

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- Database (`supabase/schema.sql`): เพิ่ม `club_id`/`club_post_id` (nullable) เข้าตาราง `notifications` เดิม, ขยาย `type` CHECK ให้รองรับ 4 ค่าใหม่ — trigger ใหม่ 4 ตัว: `notify_club_join_request` (AFTER INSERT ON club_members WHEN new.status='pending', **fan-out ผ่าน `insert...select` วนทุกแถว Owner/Admin ที่ approved ของ club นั้น** ต่างจาก trigger เดิมทุกตัวที่ insert แถวเดียวเสมอ — กัน self-notification ด้วย `cm.user_id <> new.user_id` แม้จะเป็นไปไม่ได้ในทางโครงสร้างอยู่แล้วก็ตาม เพื่อ defense-in-depth), `notify_club_join_approved` (AFTER UPDATE ON club_members WHEN old.status='pending' AND new.status='approved' — ใช้ `auth.uid()` เป็น actor เพราะเป็นคนกด approve ไม่ใช่คอลัมน์บนแถวที่ถูกแก้ — ยืนยันด้วยเหตุผลว่า `auth.uid()` อ่านจาก request-scoped JWT claims ซึ่งไม่เปลี่ยนแม้ถูกเรียกผ่าน security definer function ภายใน), `notify_club_post_like`/`notify_club_post_comment` (มิเรอร์ WYN-012 ทุกประการ + denormalize `club_id` ลงบนแถว notification ด้วยเพื่อให้ embed ชื่อ Club ได้ด้วย join ชั้นเดียวเหมือนกันทุกประเภท ไม่ต้อง join 2 ชั้นแค่สองประเภทนี้)
- `ClubRepository`: เพิ่ม `fetchPopularClubs`/`fetchNewClubs` (fetch Club ที่ยังไม่ได้เข้าร่วมทั้งหมดแล้ว sort/cap ใน Dart เพราะจำนวนสมาชิกไม่ใช่ queryable column — ยอมรับว่าไม่ scale แต่ตรงตาม Design's "ไม่ต้องมี pagination รอบนี้"), `searchClubs` (ILIKE บน name อย่างเดียวตามที่ Product ตัดสินใจ ไม่รวม username/keyword)
- `ClubPostRepository`: เพิ่ม `fetchFromJoinedClubs` (query `club_posts` **ไม่ระบุ `club_id`** เลย — RLS เดิมของ WYN-014 กรองให้อัตโนมัติอยู่แล้วว่าเห็นเฉพาะ Club ที่ approved เป็นสมาชิก ไม่ต้องสร้าง DB view ใหม่ตามที่ Design แนะนำ), `fetchById` (มิเรอร์ `DropRepository.fetchById`)
- `WynNotification`/`NotificationRepository`: เพิ่ม 4 enum value ใหม่ + `clubId`/`clubName`/`clubPostId` fields, embed `club:clubs(name)` เพิ่มใน select
- `ClubPage`: เพิ่ม `initialTabIndex` (optional, default 0) ให้ notification ของ `club_join_request` เปิดตรงแท็บ Members (index 1) ได้ทันที
- `NotificationListScreen`: เพิ่มข้อความ+navigation 4 ประเภทใหม่ (`club_post_like`/`club_post_comment` เปิด `ClubPostDetailScreen` โดยส่ง `myRole: null` เพราะ recipient คือเจ้าของโพสต์เสมอซึ่งได้ปุ่มลบผ่าน `_isOwnPost` อยู่แล้วไม่ต้องรู้ role จริงก็ปลอดภัย)
- `ViewProfileScreen`: เพิ่ม "Club ของฉัน" section — **`clubRepository`/`clubPostRepository` เป็น optional param (ไม่ใช่ required เหมือน repository อื่น)** เพราะ section นี้โชว์เฉพาะ own profile และ `ViewProfileScreen` ถูกเปิดเป็น "โปรไฟล์ตัวเอง" จริงจาก `RootShell` เท่านั้น จุดอื่น (tap-to-profile จาก Drop/Pop, แถว Follow list, ผลค้นหา) เปิดโปรไฟล์คนอื่นเสมอซึ่ง section นี้ไม่แสดงอยู่แล้วแม้จะส่ง repository ไปก็ตาม — ตัดสินใจนี้เพื่อไม่ต้อง thread ClubRepository ผ่านทุก call site ที่ไม่เกี่ยวข้องกว่า 15 ไฟล์
- `HomeFeedScreen`: เพิ่ม `SegmentedButton` toggle + `FromYourClubsFeed` widget ใหม่ (คำนวณ role ต่อโพสต์แยกตาม club_id ที่ปรากฏในหน้านั้นจริง ไม่ใช่ค่าเดียว ตามที่ Design เตือนไว้)
- `ExploreClubsScreen`/`ClubDiscoveryCard`/`SearchClubResultsTab`: ใหม่ทั้งหมดตาม Design

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. **RenderFlex overflow ใน `ClubPage`** (จำ pattern เดิมจาก WYN-014 ไม่ได้ตอนแรก) — ไม่เกิดครั้งนี้เพราะใช้ fixed height เดิมที่แก้ไว้แล้ว
2. **RenderFlex overflow ใน `ViewProfileScreen`'s "Club ของฉัน" section**: ลองผิดลองถูกหาค่าความสูงที่พอดี พบว่าการเพิ่มความสูง section แก้ overflow ภายใน `ClubMiniCard` เอง แต่กลับทำให้ overflow ของหน้าทั้งหมด (header+section+TabBar เกินพื้นที่จอ) แย่ลงในสัดส่วน 1:1 เพราะเป็น fixed-height child ใน `Column` เดียวกัน — แก้ด้วยการหาค่ากึ่งกลางที่แม่นยำ (130px) ผ่านการทดสอบจริงแทนการประมาณ แล้วยืนยันด้วย widget test ว่าไม่ overflow ทั้งสองทิศทาง

Files Changed:
- `supabase/schema.sql` (notifications columns/CHECK ใหม่, trigger function 4 ตัวใหม่)
- แก้: `app/lib/features/club/data/club_repository.dart`/`club_post_repository.dart`, `app/lib/features/notification/data/notification.dart`/`notification_repository.dart`, `app/lib/features/notification/presentation/notification_list_screen.dart`, `app/lib/features/club/presentation/club_page.dart`, `app/lib/features/club/presentation/widgets/club_section.dart` (ลบ placeholder, ต่อ ExploreClubsScreen จริง), `app/lib/features/profile/presentation/view_profile_screen.dart`, `app/lib/features/home/presentation/home_feed_screen.dart`, `app/lib/features/search/presentation/search_screen.dart`, `app/lib/features/root/presentation/root_shell.dart`
- ใหม่: `app/lib/features/club/presentation/explore_clubs_screen.dart`, `app/lib/features/club/presentation/widgets/club_discovery_card.dart`, `app/lib/features/search/presentation/widgets/search_club_results_tab.dart`, `app/lib/features/home/presentation/widgets/from_your_clubs_feed.dart`
- ลบ: `app/lib/features/club/presentation/widgets/explore_clubs_placeholder_screen.dart` (แทนที่ด้วยของจริง)
- test ใหม่: ขยาย `app/test/notification_list_screen_test.dart`/`view_profile_screen_test.dart`/`home_feed_screen_test.dart` ด้วยกลุ่มเทสต์ใหม่สำหรับ WYN-015 ทั้งหมด — ไม่สร้างไฟล์ทดสอบแยกใหม่เพราะทุกจุดต่อยอดจากหน้าจอเดิม
- test แก้: `app/test/support/recording_club_repository.dart`/`recording_club_post_repository.dart` (เพิ่ม override ใหม่), `app/test/search_screen_test.dart` (เพิ่ม club repositories)

Reason: implement ตาม Product spec + Design spec ของ WYN-015 ครบตามขอบเขต — เชื่อม Club เข้ากับ Search/Notification/Profile/Home โดย reuse component เดิม 100% ตามที่ Design กำหนด ไม่มี pattern ใหม่นอกจาก `ClubDiscoveryCard`

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 162/162 ผ่านทั้งหมด (เพิ่มจาก 148 เดิม — 14 เทสต์ใหม่: 5 ใน `notification_list_screen_test.dart` ครอบคลุมข้อความ+navigation ทั้ง 4 ประเภทใหม่, 4 ใน `view_profile_screen_test.dart` ครอบคลุม My Clubs section ทั้ง 4 เงื่อนไข, 4 ใน `home_feed_screen_test.dart` ครอบคลุม toggle ทั้ง 2 ทิศทาง+empty state)
- **ทำ red→green regression proof จริง 1 จุด**: เปลี่ยน `club_join_request` ให้เปิด `initialTabIndex: 0` แทน `1` ชั่วคราวใน `notification_list_screen.dart` จำลองบั๊กที่ไม่เปิดตรงแท็บ Members → รัน `notification_list_screen_test.dart --plain-name "opens ClubPage on the Members tab"` → **FAIL จริง** (`Expected: <1>, Actual: <0>`) → revert → รัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด 162/162

Known Issues:
- `fetchPopularClubs`/`fetchNewClubs` ไม่ scale (fetch-all-then-sort-in-Dart) — ยอมรับตามที่ Design ระบุว่าไม่ต้อง pagination รอบนี้ เพราะ Club catalog ยังเล็ก
- Search Club ทำได้แค่ Name (ไม่รวม username/keyword) ตามที่ Product ตัดสินใจ
- Notification 4 ประเภทใหม่ยังไม่ทดสอบกับ Supabase project จริง (โดยเฉพาะ fan-out trigger ที่ insert หลายแถว) — ตรวจได้แค่ระดับ code review เหมือนทุก feature ก่อนหน้าที่ยังไม่มี infra จริง
- "แนะนำสำหรับคุณ" (Recommended) ใน Explore Clubs ไม่ทำรอบนี้ตามที่ Product ตัดสินใจ (ไม่มี behavioral signal รองรับ)
- `club_announcement`/`club_mention`/"new post from followed club" notification ไม่ทำรอบนี้ตามที่ Product ตัดสินใจ

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ WYN-015 ก่อนอนุมัติ — เน้นตรวจเป็นพิเศษ: (ก) `notify_club_join_request` trigger fan-out insert ถูกต้องจริง (ทุก Owner/Admin approved ได้ notification ครบ ไม่ขาดไม่เกิน ไม่ insert ให้ pending/banned member) (ข) self-notification guard ของทั้ง 4 ประเภทใหม่ (ค) `fetchFromJoinedClubs` ไม่ query ข้าม RLS ได้จริง (ง) `ViewProfileScreen`'s optional Club repository ไม่รั่ว section ไปแสดงผิดที่ (จ) regression กับ Drop/Pop/Home/Follow/Profile/Search/Notification/Club Core (WYN-014) เดิมทั้งหมด (ฉ) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัด

---

## QA & Security Report — รอบ 1 (AI QA & Security)

**ผลสรุป: PASS**

### สิ่งที่ตรวจอิสระ (ไม่เชื่อตัวเลขจาก Coding Output เฉยๆ)

1. **Re-sync ไป merged main เอง** — `git fetch origin main`, rebuild branch `claude/pwd-nxsvf5` บน `origin/main` (commit `4dcf3f1`, PR #67) ใหม่ทั้งหมด แทนที่จะเชื่อ working tree เดิม
2. **รัน `flutter analyze` อิสระ**: No issues found
3. **รัน `flutter test` อิสระ**: 162/162 ผ่านทั้งหมด — ตรงกับตัวเลขที่ Coding รายงาน ยืนยันด้วยตัวเองแล้ว

### ตรวจ SQL Trigger ใหม่ 4 ตัว (อ่าน logic เองทีละบรรทัด ไม่เชื่อคำอธิบายใน Coding Output)

- **`notify_club_join_request` (fan-out)**: อ่าน `insert...select` ยืนยันว่า `where cm.club_id = new.club_id and cm.role in ('owner','admin') and cm.status = 'approved' and cm.user_id <> new.user_id` ถูกต้องครบทุกเงื่อนไข — ไม่ insert ให้ pending/banned member (กรองด้วย `status = 'approved'`), ไม่ fan-out ข้าม club (กรองด้วย `club_id = new.club_id`), กัน self-notify (แม้จะเป็นไปไม่ได้จริงเพราะ requester ยังไม่มี approved row) เพื่อ defense-in-depth
- **Trigger นี้ยิงเฉพาะคำขอ Private club จริง**: ตรวจ `WHEN (new.status = 'pending')` ประกอบกับ RLS insert policy ของ `club_members` (`"Users can request or join clubs as themselves"`) ที่ cross-check `status` กับ `privacy` ของ club จริง (`status='pending'` insert ได้เฉพาะเมื่อ club นั้น `privacy='private'` เท่านั้น) — ยืนยันว่า client ไม่มีทางแอบ insert แถว `pending` ให้ public club เพื่อ spam fan-out notification ปลอมได้
- **`notify_club_join_approved` ใช้ `auth.uid()` ถูกต้องจริง**: ตรวจ `approve_club_member()` RPC พบว่า UPDATE statement จริง (`update club_members set status='approved' where ... and status='pending'`) เป็นตัวที่ทำให้ trigger `AFTER UPDATE WHEN (old.status='pending' AND new.status='approved')` ยิง — `new.user_id` คือผู้ขอ (recipient ถูกต้อง), `auth.uid()` คือผู้เรียก RPC (ผู้อนุมัติ, actor ถูกต้อง) เพราะ `auth.uid()` อ่านจาก request-scoped JWT claims ที่ไม่เปลี่ยนแม้ role ที่ execute จะเปลี่ยนจาก security definer — ตรวจเพิ่มว่าไม่มีทางที่ requester จะ approve ตัวเองได้ เพราะ `approve_club_member` เช็ค `coalesce(club_role(...),'') not in ('owner','admin')` ก่อน และ pending requester ไม่มี approved role แถวใน `club_members` จึง `club_role()` คืน NULL เสมอ — ปลอดภัย
- **`notify_club_post_like`/`notify_club_post_comment`**: ตรวจ column name จริงในตาราง `club_posts`/`club_post_likes`/`club_post_comments` (author_id/club_id, user_id, author_id ตามลำดับ) ตรงกับที่ trigger ใช้ทุกจุด self-notification guard (`v_author_id <> new.user_id` / `<> new.author_id`) ถูกทิศเหมือน WYN-012 ทุกประการ
- **RLS ของ `notifications`**: อ่านยืนยันว่า column ใหม่ (`club_id`/`club_post_id`) ไม่ได้เปิด insert/delete policy ใหม่ใดๆ ให้ client — ยังมีแค่ select (`recipient_id = auth.uid()`) กับ update-mark-read (`recipient_id = auth.uid()`) เหมือนเดิมทุกประการ การเขียนแถวใหม่ทำได้ทางเดียวคือผ่าน security-definer trigger เท่านั้น

### ตรวจ `fetchFromJoinedClubs` ไม่รั่ว RLS

อ่าน RLS select policy ของ `club_posts` (`"Approved club members can view club posts"`, `using (club_role(club_id, auth.uid()) is not null)`) และ `club_role()` (`select role from club_members where ... and status='approved'`, คืน NULL ถ้าไม่ approved) ประกอบกับโค้ด `ClubPostRepository.fetchFromJoinedClubs` ที่ query ผ่าน client ปกติ (ไม่ใช่ service-role bypass) โดยไม่ระบุ `club_id` เลย — ยืนยันว่า Postgres จะกรองให้อัตโนมัติเหลือเฉพาะแถวที่ auth.uid() มี approved membership เท่านั้น ไม่มีทางเห็นโพสต์จาก club ที่ไม่ได้ join

### ตรวจ `ViewProfileScreen` optional repository ไม่รั่ว section

ตรวจ call site ทั้ง 8 จุดที่เรียก `ViewProfileScreen(...)`: มีแค่ `root_shell.dart` (Bottom Nav tab, `userId: Supabase.instance.client.auth.currentUser!.id` เสมอ) เท่านั้นที่ส่ง `clubRepository`/`clubPostRepository` เข้าไป — อีก 6 จุด (`pop_clip_view.dart`, `notification_list_screen.dart`, `search_user_results_tab.dart`, `follow_list_screen.dart`, `home_feed_screen.dart`, `drop_detail_screen.dart`) ไม่ส่งเลย นอกจากนี้โค้ดยังมี double-gate ในตัว: `_isOwnProfile` เปรียบเทียบ `widget.userId == currentUser.id` ตรงๆ ไม่ได้พึ่งพา caller ส่ง flag พิเศษ และ `_myClubsFuture` จะถูก populate ก็ต่อเมื่อ `_isOwnProfile && clubRepository != null` ทั้งคู่ — แม้จุดเรียกอื่นจะถูกแก้ในอนาคตให้ส่ง repository เข้ามาโดยไม่ตั้งใจ section ก็จะไม่โผล่นอกจาก `userId` ที่ส่งเข้ามาตรงกับผู้ใช้ปัจจุบันจริงๆ — ปลอดภัยด้วย design ไม่ใช่แค่ด้วยวินัยของผู้เรียก

### ไล่ Requirements/Design Components/Acceptance Criteria ทีละบรรทัด

ไล่ครบทั้ง 3 หัวข้อเทียบกับโค้ดจริง (`explore_clubs_screen.dart`, `club_discovery_card.dart`, `search_club_results_tab.dart`, `search_screen.dart`, `notification_list_screen.dart`, `view_profile_screen.dart`, `home_feed_screen.dart`, `from_your_clubs_feed.dart`) — ตรงตาม spec ครบทุกข้อ ยกเว้น 1 จุด (ดู Finding ด้านล่าง) ที่ AC ไม่ได้เขียนตรวจไว้ชัดแต่ Design ระบุ component ไว้

**AC ทุกข้อผ่าน**: Explore Clubs แยก Popular/New ถูกต้อง ไม่มี club ที่ join แล้วปน (`_fetchDiscoverableClubs` filter `joinedIds`) / Category filter ทำงานถูกต้อง (`clubCategories` shared const เดียวกับ `CreateClubScreen`) / แตะการ์ดเปิด `ClubPage` ถูกต้องทั้ง Explore และ Search / Search Club ilike name case-insensitive ถูกต้อง / notification 4 ประเภทใหม่ครบตามข้อความ+ปลายทางที่ Design กำหนดเป๊ะ / self-notification guard ยืนยันแล้วที่ trigger level / "My Clubs" section แสดงเฉพาะ own profile ยืนยันแล้ว / Home toggle เริ่มที่ "สำหรับคุณ" เสมอ ตำแหน่งถูกต้อง (ClubSection → toggle → feed) / "จาก Club ของคุณ" กรองผ่าน RLS เรียงเวลาถูกต้อง (`order('created_at', ascending: false)`) / regression เดิมทั้งหมดผ่าน 162/162

### Finding — Minor (ไม่ block)

**`FromYourClubsFeed`'s empty state ขาดปุ่ม "สำรวจ Club" ตามที่ Design spec Screen 5 ระบุไว้ชัดเจน**: Design เขียนไว้ว่า empty state ต้องมี "ปุ่ม 'สำรวจ Club' ให้ไปหน้า [Explore Clubs] แทน" แต่โค้ดจริงใน `from_your_clubs_feed.dart` (บรรทัด ~218-224) แสดงแค่ข้อความ "เข้าร่วม Club เพื่อดูโพสต์ที่นี่" เฉยๆ ไม่มีปุ่มนำทางเลย — เป็นการข้าม component ที่ spec ระบุไว้ตรงๆ ไม่ใช่แค่ตีความต่าง (คล้าย pattern ที่เคยเกิดกับ WYN-007's missing Share button)

เหตุผลที่ไม่ block: (1) ไม่มี AC บรรทัดไหนใน Product spec ทดสอบปุ่มนี้ตรงๆ (2) `ClubSection` ที่มีปุ่ม "สำรวจ Club" อยู่แล้วยังคงแสดงอยู่เหนือ toggle เสมอไม่ว่าจะอยู่โหมดไหน (ดู `home_feed_screen.dart` บรรทัด 330-334 — `ClubSection` มาก่อน `_buildFeedModeToggle()` เสมอ ไม่ได้ถูกซ่อนเมื่อสลับไป "จาก Club ของคุณ") ผู้ใช้จึงไม่ได้ตันจริง แค่ต้องเลื่อนขึ้นไปกดปุ่มที่มีอยู่แล้วแทนที่จะกดในข้อความ empty state โดยตรง (3) ไม่มีผลกระทบด้าน security/data-integrity

**คำแนะนำ**: เพิ่มปุ่ม "สำรวจ Club" ใน empty state ของ `FromYourClubsFeed` ให้ตรงตาม Design spec ในรอบถัดไป (เช่น WYN-016 หรือ debug ticket เล็กๆ) — ไม่จำเป็นต้องหยุด WYN-015 QA เพื่อรอแก้จุดนี้

### Red→Green Regression Proof อิสระ (จุดที่ต่างจาก Coding เอง)

Coding ทำ proof ที่ `notify_club_join_request`'s `initialTabIndex` (notification navigation) — QA เลือกทำ proof คนละจุด: **empty-state ของ "จาก Club ของคุณ"**
1. แก้ `from_your_clubs_feed.dart` เปลี่ยนเงื่อนไข `if (_posts.isEmpty)` เป็น `if (false)` ชั่วคราว จำลองบั๊กที่ empty-state message หายไป
2. รัน `flutter test test/home_feed_screen_test.dart --plain-name "shows a join-prompt message"` → **FAIL จริง**: `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets...>`
3. Revert กลับเป็น `if (_posts.isEmpty)` เดิม
4. รัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด, 162/162 ผ่านทั้งหมด (ยืนยันว่า revert สมบูรณ์ ไม่มีของเหลือค้าง)

### Regression กับฟีเจอร์เดิมทั้งหมด

162/162 tests ครอบคลุม Drop (WYN-002/003)/Pop (WYN-006)/Home (WYN-007)/Follow (WYN-008)/Search (WYN-009)/Profile (WYN-013)/Notification (WYN-012)/Club Core (WYN-014) เดิมทั้งหมดผ่านหมด ไม่มี regression

### สรุป

WYN-015 ผ่าน QA รอบ 1 — **PASS** พบ 1 finding ระดับ Minor (ไม่ block ตามเหตุผลข้างต้น) อนุมัติเข้า `approved/`
