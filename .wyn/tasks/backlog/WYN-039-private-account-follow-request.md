# Product Task — WYN-039

Status: backlog
Owner: AI Product Manager

Feature: Private Account + Follow Request

Goal: ให้ผู้ใช้เลือกได้ว่าบัญชีของตัวเองเป็น Public (ใครก็ดู Drop ได้ ตามเดิมทุกอย่าง) หรือ Private (ต้องกด Follow Request แล้วรอเจ้าของบัญชี Approve/Reject ก่อนถึงจะเห็นเนื้อหาได้) — task สุดท้ายของ Phase 3 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 10 "PRIVATE ACCOUNT": "เลือก Public หรือ Private — Private: Follow Request → User Approve/Reject" และ section 11 "FOLLOW SYSTEM": "Follow, Unfollow, Follow Request, Accept, Reject, Remove Follower, Following List, Followers List"

Target User: ผู้ใช้ WYN Social ทุกคน โดยเฉพาะกลุ่ม Gen Z ที่กังวลเรื่องความเป็นส่วนตัว (ไม่อยากให้คนแปลกหน้าเห็น Drop ของตัวเองโดยไม่คัดกรองก่อน) — ปัจจุบัน WYN-008 (Follow system) เปิดให้ทุกคนเห็น Drop ของทุกคนเสมอ ไม่มีทางเลือกจำกัดผู้ชมเลย

Problem: บัญชี WYN ทุกบัญชีตอนนี้เป็น Public โดยปริยายและไม่มีทาง opt-out — `follows` table (WYN-008) insert ทันทีที่กด Follow ไม่มี state รอการอนุมัติ, `home_feed`/`saved_feed` view (WYN-007/013, ปรับล่าสุดที่ WYN-035) และ RLS ของตาราง `drops`/`redrops` (`"Drops are viewable by authenticated users, excluding blocked authors"`, ปรับที่ WYN-027) ให้ authenticated user ทุกคนเห็น Drop/ReDrop ของทุกคนเสมอ ยกเว้นแค่ mute/block เท่านั้น — ไม่มีแนวคิด "เนื้อหาที่จำกัดผู้ชมตามสถานะ Follow" อยู่ในระบบเลยแม้แต่จุดเดียว ทำให้ Master Spec section 10 (Private Account) ยังทำไม่ได้จริงในตอนนี้

Requirements:

**1. Account Type: Public / Private (เพิ่มใน Settings)**
- เพิ่ม field ใหม่ในตาราง `profiles` (เช่น `is_private boolean not null default false`) — default เป็น Public เสมอสำหรับบัญชีเดิมและบัญชีใหม่ (ไม่ทำลาย behavior เดิมของผู้ใช้ปัจจุบันโดยไม่ตั้งใจ)
- เพิ่ม section ใหม่ "ความเป็นส่วนตัว" (Privacy) ใน `SettingsScreen` ที่มีอยู่แล้ว (`app/lib/features/settings/presentation/settings_screen.dart`) — มีแค่ toggle เดียว "บัญชีส่วนตัว (Private Account)" พร้อมคำอธิบายสั้นๆ ว่าเปลี่ยนแล้วมีผลอย่างไร — **ทำตาม pattern เดิมของไฟล์นี้ที่ตั้งใจเพิ่มทีละ section ตามงานที่มาถึงจริง** (ดู comment บนสุดของไฟล์: "Deliberately not pre-building empty sections for the other 6 categories") — Privacy settings ย่อยอื่นๆ ที่ Master Spec section 35 ระบุไว้ (DM Permissions, Mention, Comment) **ไม่อยู่ในสโคปนี้** ทำใน WYN-045 (Settings screen เต็มรูปแบบ, Phase 5)
- สลับ Public → Private: ไม่กระทบ follower ที่มีอยู่แล้วเลย (ยังเห็นเนื้อหาได้ตามปกติ) มีผลเฉพาะกับคนที่ยังไม่ได้ follow เท่านั้นนับจากวินาทีที่เปลี่ยน
- สลับ Private → Public: request ที่ค้างอยู่ทั้งหมด (pending) ให้ auto-approve ทันที (กลายเป็น follower จริง) — mirrors พฤติกรรมมาตรฐานที่ผู้ใช้คุ้นเคยจาก Instagram ผู้ใช้ตั้งใจเปิดบัญชีให้ทุกคนเห็นแล้ว ไม่มีเหตุผลให้ค้าง request ต่อ

**2. Follow Request flow (แทนที่ instant-follow เฉพาะกรณี target เป็น Private)**
- กด Follow บัญชี Public: ทำงานเหมือนเดิมทุกประการ (instant follow, ไม่ผ่าน request ใดๆ — ไม่แตะ behavior เดิมของ WYN-008 เลย)
- กด Follow บัญชี Private (ที่ยังไม่ได้ follow อยู่ก่อน): ปุ่มเปลี่ยนข้อความเป็น "ขอติดตามแล้ว" (Requested) และสร้าง pending request แทนการ insert แถว follow ทันที — reuse ปุ่ม/ตำแหน่งเดิมที่ `DropDetailScreen`/`ViewProfileScreen` มีอยู่แล้ว (WYN-008) ไม่สร้างปุ่มใหม่แยก
- ผู้ส่ง request ยกเลิกได้เอง (กด "ขอติดตามแล้ว" ซ้ำ = cancel request) — เหมือนกด Unfollow ปกติ
- **ฝั่งเจ้าของบัญชี (ผู้รับ request)**: มีหน้า "Follow Requests" แยกต่างหาก (list ของคนที่ขอติดตาม พร้อมปุ่ม Accept/Reject ต่อรายการ) — **reuse pattern เดียวกับ Message Request ของ WYN-032** (Accept → กลายเป็น follower จริงทันที, Reject → หายไปจาก list ผู้ส่งไม่ได้รับแจ้งเตือนใดๆ ว่าถูกปฏิเสธ ถ้าจะขอใหม่ก็เริ่ม request ใหม่ได้ปกติ ไม่มี cooldown)
- ทางเข้าหน้า Follow Requests: badge จำนวนคำขอค้างที่ `ViewProfileScreen` ของตัวเอง (จุดเดียวกับที่แสดงจำนวน Followers/Following ของ WYN-008) — เฉพาะเจ้าของบัญชีที่เป็น Private เท่านั้นที่เห็น entry point นี้
- ผู้ใช้ที่ถูก Block (WYN-027, `internal.is_blocked_either_way()`) ส่ง Follow Request ไม่ได้เลย — reuse กลไก block เดิมตรงๆ เหมือนที่ WYN-031/032 ทำกับ Chat

**3. Remove Follower**
- เจ้าของบัญชี (ไม่ว่า Public หรือ Private) เอาผู้ติดตามคนใดคนหนึ่งออกจากรายชื่อ Followers ได้ (ลบความสัมพันธ์ follow ทิ้ง โดยไม่ต้อง Block) — เพิ่มปุ่มนี้ในหน้า Followers list ที่มีอยู่แล้ว (`app/lib/features/follow/presentation/follow_list_screen.dart`, WYN-008) เฉพาะตอนดูรายชื่อ Followers ของตัวเอง
- นี่คือ requirement ใหม่จริง ไม่ใช่แค่ UI: ปัจจุบัน `follows` table มี DELETE policy แค่ `"Users can remove their own follows" using (auth.uid() = follower_id)` — เจ้าของบัญชีที่เป็น `following_id` ยังลบแถว follower ของตัวเองไม่ได้เลยทาง DB ต้องเพิ่มสิทธิ์นี้เข้าไป

**4. Content Visibility Gating (หัวใจของ Private Account — งานยากสุดของ task นี้)**
- บัญชี Private: เฉพาะเจ้าของบัญชีเองและ follower ที่ได้รับ Accept แล้วเท่านั้นที่เห็น Drop/ReDrop/Quote ReDrop (WYN-034), Poll-in-Drop (WYN-035) ของบัญชีนั้นได้ — คนอื่นทุกคน (รวมถึงคนที่ request ค้างอยู่แบบยังไม่ Accept) ต้องเห็นแค่ profile header ทั่วไป (avatar/display name/bio/จำนวน Drops-Followers-Following) พร้อมข้อความ "บัญชีนี้เป็นส่วนตัว" + ปุ่ม Follow Request — ไม่เห็น Drop grid/tab ใดๆ เลย
- **ผลกระทบต้องครอบคลุมทุกทางที่ Drop อาจถูกมองเห็น ไม่ใช่แค่ที่เดียว**: `home_feed`/`saved_feed` view (ต้อง exclude เหมือน pattern mute ที่มีอยู่แล้ว — `where not exists (select 1 from mutes ...)` — เพิ่มเงื่อนไข private-and-not-followed แบบเดียวกัน), RLS ของตาราง `drops`/`redrops` โดยตรง (ป้องกัน deep-link เข้า `DropDetailScreen` ตรงๆ ด้วย ไม่ใช่แค่ซ่อนจาก feed), Search (WYN-009 — ผลลัพธ์ Drop content, ไม่ใช่ผลลัพธ์ User search ซึ่งยังเห็นบัญชี Private ได้ปกติเหมือน Instagram แค่กดเข้าไปแล้วเห็นเนื้อหาไม่ได้), Hashtag feed (WYN-020)
- **กรณี ReDrop ที่ต้องระวังเป็นพิเศษ**: ถ้า A (Private) โพสต์ Drop แล้ว B (follower ของ A) กด ReDrop/Quote ต่อ — Drop ต้นฉบับของ A ต้อง**ยังคงถูกกันไม่ให้ follower ของ B ที่ไม่ได้ follow A เห็นได้** (สิทธิ์การดูอิงตามเจ้าของเนื้อหาต้นฉบับเสมอ ไม่ใช่อิงตามคนที่ ReDrop) — ถ้าไม่กันจุดนี้จะกลายเป็นช่องโหว่ privacy leak ที่ทำให้ Private Account ไร้ความหมาย (ReDrop เป็นทางลัดข้าม private gate ได้ทันที)
- Comment/Like/Save ที่มีอยู่แล้วบน Drop: ถ้าเข้าไม่ถึงตัว Drop ได้อยู่แล้ว (ตาม RLS ข้อบนที่กันไว้) ก็ทำ action พวกนี้ไม่ได้อยู่แล้วโดยธรรมชาติ ไม่ต้องแก้ policy อื่นเพิ่ม — Comment/Mention permission แบบละเอียด (Master Spec section 35 "Mention"/"Comment" เป็น setting แยก) ไม่อยู่ในสโคปนี้
- Club post/Pop ไม่อยู่ในสโคปนี้ (Club มี Public/Private ของตัวเองแยกต่างหากอยู่แล้ว, Pop ถอดออกจาก Bottom Nav ตั้งแต่ WYN-024 ไม่มี user reach จริง)

**5. `follows` table SELECT policy ต้องทบทวนใหม่**
- ปัจจุบัน `"Follows are viewable by authenticated users" using (true)` — ใครก็ query follow graph ของใครก็ได้ทั้งหมด รวมถึง pending request ในอนาคตที่จะเพิ่มเข้ามาด้วยถ้าใช้ตารางเดียวกัน — **ต้องไม่ให้ Follow Request ที่ยัง pending มองเห็นได้จากคนอื่นนอกจากคู่กรณี** (ผู้ส่ง request กับเจ้าของบัญชี) เหมือนหลักการเดียวกับที่ WYN-038 จำกัด SELECT ของ `drop_views` เฉพาะเจ้าของแถว (ไม่ใช่เปิดกว้างแบบ `drop_likes`) — ให้ AI Design/Coding ตัดสินใจเองว่าจะแยกตาราง `follow_requests` ใหม่ หรือเพิ่ม `status` column เข้า `follows` เดิม (มี precedent จาก `conversations.status` ของ WYN-031/032) พร้อมออกแบบ SELECT policy ให้เหมาะกับแต่ละ state — สำหรับ relationship ที่ Accept แล้ว (กลายเป็น follow จริง) จะยังคงเปิดเผยแบบ public เหมือนเดิมได้ (Followers/Following list ของบัญชี Public ยังดูได้ตามปกติ) แต่ถ้าเป็นบัญชี Private ควรพิจารณาว่า Followers/Following list เองก็ควรเห็นได้เฉพาะ follower เท่านั้นเหมือนกัน (มาตรฐาน Instagram) — ให้ AI Design ตัดสินใจ HOW และบันทึกเหตุผลไว้

**6. Notification ใหม่**
- เพิ่ม notification type `follow_request` (เจ้าของบัญชีได้รับแจ้งเมื่อมีคนขอติดตาม) และ `follow_request_accepted` (ผู้ส่ง request ได้รับแจ้งเมื่อถูก Accept) — **มี precedent ชัดเจนจาก WYN-032 ที่เพิ่ม `message_request` เป็น notification type ใหม่ไปแล้วทั้งที่ roadmap ระบุ "Notification type ใหม่" ไว้เป็นงานของ WYN-043/Phase 5** — งานนี้ตามรอยเดิม ไม่ต้องรอ WYN-043 (Reject ไม่ส่ง notification ใดๆ เหมือน Message Request's Delete)
- Follow ปกติ (บัญชี Public, instant) ยังใช้ notification type `follow` เดิมเหมือนเดิมทุกประการ ไม่เปลี่ยน

Acceptance Criteria:
- [ ] เปิด Settings เห็น section "ความเป็นส่วนตัว" มี toggle Public/Private ใช้งานได้ สลับแล้ว persist ใน DB จริง
- [ ] บัญชีใหม่/บัญชีเดิมทั้งหมด default เป็น Public เสมอ (ไม่มีใครถูกเปลี่ยนเป็น Private โดยไม่ตั้งใจ)
- [ ] กด Follow บัญชี Public: instant follow เหมือนเดิมทุกประการ ไม่มี regression ใดๆ กับ WYN-008
- [ ] กด Follow บัญชี Private ที่ยังไม่เคย follow: ปุ่มเปลี่ยนเป็น "ขอติดตามแล้ว" ไม่กลายเป็น follower ทันที
- [ ] เจ้าของบัญชี Private เห็นหน้า Follow Requests แสดงรายชื่อคนที่ขอติดตามถูกต้องครบ พร้อม Accept/Reject
- [ ] กด Accept: ผู้ขอกลายเป็น follower จริงทันที (เห็น Drop ได้แล้ว, นับใน Followers count), ผู้ขอได้รับ notification `follow_request_accepted`
- [ ] กด Reject: request หายจาก list, ไม่มี notification ใดๆ ส่งไปหาผู้ขอ, ผู้ขอ request ใหม่ได้อีกในอนาคต
- [ ] ผู้ใช้ที่ถูก Block ส่ง Follow Request ไปหาคนที่ block ตัวเอง (หรือที่ตัวเองบล็อกไว้) ไม่ได้เลย
- [ ] เจ้าของบัญชีกด Remove Follower ในหน้า Followers list: follower คนนั้นหลุดจากการ follow จริง (ต้องส่ง Follow Request ใหม่ถ้าจะ follow อีกครั้งในกรณีเป็น Private)
- [ ] เปิดโปรไฟล์บัญชี Private ที่ยังไม่ได้ follow (และไม่ใช่เจ้าของ): เห็นแค่ header/bio/สถิติตัวเลข ไม่เห็น Drop grid เลย มีข้อความ "บัญชีนี้เป็นส่วนตัว" ชัดเจน
- [ ] เปิดโปรไฟล์บัญชี Private ที่เป็น follower อยู่แล้ว (Accept แล้ว) หรือเป็นเจ้าของเอง: เห็น Drop grid ปกติทุกอย่าง ไม่มีข้อจำกัด
- [ ] Drop ของบัญชี Private ไม่ปรากฏใน Home feed ของคนที่ไม่ได้ follow เลย (ทดสอบทั้ง 3 branch ของ `home_feed`: Drop ตรง, ReDrop, Quote ReDrop) แต่ยังปรากฏปกติสำหรับ follower/เจ้าของ
- [ ] พยายามเปิด `DropDetailScreen` ของ Drop จากบัญชี Private ตรงๆ (เช่น ผ่าน deep-link/ID ที่รู้อยู่แล้ว) โดยไม่ได้ follow: ต้องเข้าไม่ได้ (RLS ปฏิเสธที่ database เอง ไม่ใช่แค่ UI ซ่อน)
- [ ] Search (WYN-009) ผลลัพธ์ Drop content ไม่โชว์ Drop จากบัญชี Private ที่ไม่ได้ follow แต่ผลลัพธ์ User search ยังเห็นบัญชี Private ได้ตามปกติ (แค่กดเข้าไปแล้วเห็นเนื้อหาไม่ได้)
- [ ] Hashtag feed (WYN-020) ไม่โชว์ Drop จากบัญชี Private ที่ไม่ได้ follow เช่นกัน
- [ ] **Regression test สำคัญ**: A (Private) โพสต์ Drop → B (follower ของ A) ReDrop/Quote-ReDrop ต่อ → C (follower ของ B แต่ไม่ได้ follow A) เปิด Home feed/โปรไฟล์ B ต้อง**ไม่เห็น** ReDrop นั้นเลย (ป้องกัน privacy leak ผ่าน ReDrop)
- [ ] สลับ Public → Private: follower เดิมทั้งหมดยังเห็นเนื้อหาได้ปกติ ไม่มีใครหลุดจากการ follow
- [ ] สลับ Private → Public: pending request ทั้งหมด auto-approve กลายเป็น follower จริงทันที
- [ ] Regression เต็มชุด: Home feed/Saved feed/Search/Hashtag feed/ReDrop/Poll/Draft/Edit-Delete/View-count/Report/Block/Mute/Moderation/Chat/Message-Request ของบัญชี Public ทำงานเหมือนเดิมทุกอย่าง ไม่มี regression จาก task นี้

Dependencies: WYN-008 (Follow system, Approved — ฐานของ `follows` table/`FollowRepository`/`follow_list_screen.dart`), WYN-005/007/013 (Drop/Home/Saved feed), WYN-027 (Block — reuse `internal.is_blocked_either_way()`), WYN-032 (Message Request — reuse pattern Accept/Reject + `status` column precedent), WYN-034 (ReDrop/Quote ReDrop — ต้อง gate ด้วย), WYN-035 (Poll-in-Drop — content_type เดียวกับ Drop ต้อง gate ด้วย), WYN-009 (Search), WYN-020 (Hashtag feed), WYN-012 (Notification)

Priority: P1 — task สุดท้ายของ Phase 3 (Drop Enhancement) ตาม roadmap, Founder สั่งเริ่มต่อทันทีหลัง WYN-038 (2026-08-23)

Risks:
- **นี่คืองาน privacy-gating ที่กระทบหลายจุดพร้อมกัน (feed/search/hashtag/RLS/ReDrop) — ความเสี่ยงสูงสุดคือ "แก้ไม่ครบทุกทาง" แล้วเหลือช่องโหว่ให้เนื้อหา Private หลุดออกไปได้บางเส้นทาง** เหมือนที่เคยเกิดกับ WYN-027 (`is_blocked_either_way` RPC-exposure) และ WYN-029 (moderation actor-identity leak) มาก่อน — ต้องให้ QA ไล่ตรวจทุก entry point ที่ query `drops`/`redrops` ในระบบจริง (`grep` หา call site ทั้งหมด) ไม่ใช่แค่ตาม Acceptance Criteria ที่ระบุไว้ข้างบนเท่านั้น
- **ReDrop เป็นทางลัดข้าม private gate ที่ชัดเจนที่สุด** (ระบุไว้ใน Requirement 4 แล้ว) — ถ้า Design/Coding มองข้ามจุดนี้ Private Account จะไม่มีความหมายจริงในทางปฏิบัติ เพราะใครก็ ReDrop เนื้อหา private แล้วเผยแพร่ต่อได้
- **Scope ใหญ่กว่า task ปกติของ Phase 3 ที่ผ่านมา** (WYN-034-038 แต่ละตัวแตะจุดเดียว/สองจุด) — แนะนำให้ AI Design แตกเป็นหลาย screen/PR ย่อยถ้าจำเป็นเพื่อลดความเสี่ยง แต่ต้อง QA เป็น task เดียวจบ (ไม่ deploy บางส่วนที่ gate content ยังไม่ครบ เพราะจะเป็น partial privacy protection ที่อันตรายกว่าไม่มีเลย — ผู้ใช้เข้าใจผิดว่าปลอดภัยแล้วทั้งที่ยังไม่ครบ)
- **`follows` SELECT policy เดิมเปิดกว้างเกินไปสำหรับ pending request** — ถ้า schema ใหม่ไม่ระวังจุดนี้ คนอื่นจะเห็นได้ว่าใครขอ follow ใครอยู่ (ข้อมูลที่ควรเป็นความลับระหว่างคู่กรณีเท่านั้น เหมือน Message Request)
- Performance: เงื่อนไข private-and-not-followed ต้องเพิ่มเข้า `home_feed`/`saved_feed`/search/hashtag ทุกจุด (subquery ต่อแถวเพิ่มอีกชั้นจากที่มี mute อยู่แล้ว) — ให้ AI Design/Coding พิจารณา index ที่จำเป็นบน `follows`/`profiles.is_private`

Recommendation: ทำ requirement 1-3 (Account type toggle + Follow Request flow + Remove Follower) ก่อนเป็นฐาน แล้วค่อยทำ requirement 4 (Content Visibility Gating) ซึ่งเป็นส่วนเสี่ยงสุด — แนะนำให้ AI Design ออกแบบ schema ของ Follow Request (requirement 5) ให้เสร็จก่อนเริ่ม UI ใดๆ เพราะ UI ทั้งหมด (ปุ่ม Follow, Follow Requests list, badge, profile gating) ต้องอิงกับ state ของ schema นี้โดยตรง — ใช้แนวทางเดียวกับที่ WYN-031 เตรียม `conversations.status` ไว้ล่วงหน้าก่อนที่ WYN-032 จะมาใช้งานจริง (แต่ในกรณีนี้ทำพร้อมกันในรอบเดียวเพราะไม่มี task ถัดไปที่แยกออกมาต่างหากเหมือน Message Request)

Handoff: AI Design — ออกแบบ schema/state ของ Follow Request (ตาราง/status column ใหม่ + SELECT/INSERT/UPDATE/DELETE policy), หน้า Follow Requests screen (reuse pattern จาก `message_request_list_screen.dart` ของ WYN-032), การแสดงผล Private Account บน `ViewProfileScreen` (locked state), section ใหม่ใน `SettingsScreen`, และผังการ gate เนื้อหาใน `home_feed`/`saved_feed`/RLS/Search/Hashtag ทั้งหมดตาม Requirement 4-5 ข้างต้น — ต้องตอบให้ชัดก่อนส่งต่อ AI Coding ว่า schema สุดท้ายเป็นแบบไหน (ตารางแยก vs status column เดิม) และ Followers/Following list ของบัญชี Private ควรเปิดเผยแค่ไหน (ดู Requirement 5)
