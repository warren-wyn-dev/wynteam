# Design — WYN-115 (Club Poll)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-115-club-poll.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `.wyn/docs/design/wyn-035-poll-in-drop.md` (Poll ใน Drop) — **reuse โครงสร้าง/กติกาเดียวกันแทบทั้งหมด** ตามที่ Product spec สั่งไว้ชัดเจน ต่างกันที่ 3 จุด: (1) Club Post เป็น multi-image (`image_urls text[]`) ไม่ใช่ single image เหมือน Drop (2) Club Post มี `link_url` แยกที่ Drop ไม่มี (3) ไม่มี grid/thumbnail ใดๆ แสดง Club post เลยในระบบ (ตรวจแล้ว — ไม่ปรากฏใน Saved/Bookmarks, ไม่มี grid view) จึงไม่ต้องมี Screen 3 (Grid Fallback) แบบ WYN-035
> Design system: Sapphire `#1B3A6B` เป็น accent เดียวของ Club UI (ตาม `wyn-057-058-club-create-and-page-visual-polish.md`) — ใช้แทน Cyan ของ Drop ทุกจุดที่ WYN-035 ระบุเป็นสี primary

## ภาพรวม — decisions ที่ reuse ตรงจาก WYN-035 (ไม่ต้องคิดใหม่)

1. **`club_posts.image_urls`/`link_url` ต้อง nullable ทั้งคู่อยู่แล้ว** (ตรวจ schema แล้ว — ทั้งสองคอลัมน์ nullable เดิม) — Poll Club Post ไม่มีรูป/ลิงก์ ใช้ **RPC `create_poll_club_post()` เป็นทางเดียว** ที่สร้าง Poll Club Post ได้ (insert `club_posts`+`club_post_polls`+`club_post_mentions` แบบ atomic เดียว มิเรอร์ `create_poll_drop()`) — การันตี "มีรูป/ลิงก์ หรือมีโพลอย่างใดอย่างหนึ่ง" ด้วยโครงสร้างโค้ด ไม่ใช่ DB constraint (เหตุผลเดียวกับ WYN-035: cross-table CHECK ทำไม่ได้)
2. **ผลโหวตผ่าน RPC `get_club_poll_results()` เท่านั้น** — mirror `get_poll_results()` เป๊ะ แต่เพิ่มเงื่อนไข visibility อีกชั้น: ต้องเป็นสมาชิกที่ `status = 'approved'` ของ Club นั้นด้วย (ไม่ใช่แค่โหวตแล้ว/เจ้าของ/หมดเวลาเหมือน Drop) — ตรงกับ trust model เดิมของ Club post ทุกอย่าง (Club private ต้องเป็นสมาชิกก่อนถึงจะเห็นโพสต์ได้อยู่แล้ว)
3. **content เดิมทำหน้าที่เป็นคำถามโพล** เหมือน WYN-035 เป๊ะ — `MentionInput`/hashtag ทำงานเหมือนเดิมทุกจุด
4. **พื้นที่ media area เดิม (image strip) กลายเป็น "media area" เลือกได้ 2 แบบ**: รูปภาพ (multi, สูงสุด 9 เหมือนเดิม) หรือ Poll composer/display — reuse แนวคิดเดียวกับ WYN-035 ข้อ 4
5. **ผลโหวตโหลดมาพร้อม fetch เดียวกับ list/detail** ไม่ fetch แยกต่อการ์ด — `ClubPostRepository.fetchPosts`/`fetchFromJoinedClubs`/`searchByContent`/`fetchById` ทุกตัวเพิ่ม batch call เดียวไปยัง `get_club_poll_results(poll_ids[])` มิเรอร์ pattern เดิมที่ WYN-035 วางไว้กับ Drop เป๊ะ

## จุดที่ต่างจาก WYN-035 จริง (ต้องตัดสินใจใหม่)

**Link field ระหว่างโหมด Poll**: Club Post มี `_linkController` ที่ Drop ไม่มี — **ตัดสินใจ: ซ่อนช่องลิงก์ตอนอยู่โหมดโพล** (ไม่ใช่ปล่อยให้กรอกคู่กันได้) เหตุผล: Founder Brief เดิม (ข้อ 19) เตือนไม่ให้ใส่ฟีเจอร์อนาคตจนซับซ้อนเกินจำเป็น — โพล+ลิงก์พร้อมกันเป็น edge case ที่ไม่มีใครขอ เพิ่ม scope โดยไม่มีประโยชน์ชัดเจน ตรงกับที่ WYN-035 เองก็ตัดกรณี "รูป+โพลพร้อมกัน" ออกด้วยเหตุผลเดียวกัน (Product Risk #1 เดิม)

## Screen 1 — Poll Composer (แทนที่พื้นที่รูปใน `CreateClubPostScreen`)

**Purpose**: สร้าง Poll Club Post

**ตำแหน่ง**: แถบปุ่มเล็กเหนือปุ่ม "แนบรูป" เดิม 2 ปุ่ม toggle "🖼️ รูปภาพ" / "📊 โพล" (default: รูปภาพ) — สลับแล้วพื้นที่เปลี่ยนทันที: โหมดรูปภาพ = ปุ่ม "แนบรูป" + image strip + ช่องลิงก์เหมือนเดิมทุกอย่าง, โหมดโพล = ซ่อนปุ่ม "แนบรูป"/image strip/ช่องลิงก์ทั้งหมด แสดง Poll Composer แทน ข้อมูลของโหมดที่ไม่ได้เลือกไม่หายไปจนกว่าจะกด "โพสต์" จริง (สลับกลับไปกลับมาได้)

**Components (โหมดโพล)** — เหมือน WYN-035 Screen 1 เป๊ะ:
- ตัวเลือก 2 ช่อง `TextField` เริ่มต้น (placeholder "ตัวเลือกที่ 1" / "ตัวเลือกที่ 2") ยาวได้ 1-80 ตัวอักษร
- ปุ่ม "+ เพิ่มตัวเลือก" ใต้ช่องสุดท้าย (ซ่อนเมื่อครบ 4 ช่องแล้ว)
- ไอคอนลบ (✕) ท้ายช่องที่ 3-4 เท่านั้น (ช่อง 1-2 ลบไม่ได้)
- แถวเลือกระยะเวลา: `SegmentedButton<int>` 3 ตัวเลือก "1 วัน" / "3 วัน" / "7 วัน" ค่าเริ่มต้น "1 วัน"

**Interactions**: พิมพ์คำถามในช่อง content เดิม (label เปลี่ยนเป็น "ตั้งคำถามโพล...") — ปุ่ม "โพสต์" กดได้เมื่อ: คำถามไม่ว่าง + ตัวเลือกทุกช่องไม่ว่างและไม่ซ้ำกัน (trim, case-insensitive) + มีอย่างน้อย 2 ตัวเลือก (แทนที่เงื่อนไข `_canPost` เดิมทั้งหมดในโหมดนี้ — ไม่ใช่ OR กับเงื่อนไขเดิม)

**States**: error จากการซ้ำ/ว่าง แสดงเป็นข้อความสีแดงใต้ตัวเลือกที่มีปัญหาทันทีตอนพิมพ์ (ไม่ใช่ snackbar ตอนกดโพสต์) — เหมือน WYN-035 เป๊ะ

## Screen 2 — Poll Display Widget (`ClubPollCard`, ใช้ร่วมกันใน `ClubPostCard` + `ClubPostDetailScreen`)

**Purpose**: แสดงตัวเลือก/รับการโหวต/แสดงผลลัพธ์ — แทนที่พื้นที่ `ClubPostImages`/link preview เดิมเมื่อ `pollId != null`

**User Flow**: เหมือน WYN-035 Screen 2 เป๊ะ — เห็นตัวเลือกเป็นปุ่มแถวยาวเต็มความกว้าง → แตะโหวต → เห็นผลได้ (โหวตแล้ว/เจ้าของ/หมดเวลา) แปลงเป็น percentage bar ทันที (optimistic update เหมือน Like/Save เดิมของ Club post)

**Components**: เหมือน WYN-035 Screen 2 เป๊ะทุกประการ (แถบเต็มความกว้าง 44px, percentage bar, ✓ ที่ตัวเลือกของตัวเอง, แถว "X โหวต · เหลือ Xh/Xd") **แทนที่สี primary cyan ด้วย Sapphire** (ตาม Club's design system เดิม) — ตัวเลือกที่ตัวเองเลือก fill สี Sapphire เต็ม ตัวเลือกอื่นที่เห็นผลแล้ว fill สี Sapphire จางๆ (10-15% opacity ตาม pattern เดิมของ Club UI)

**Interactions/States/Accessibility**: เหมือน WYN-035 เป๊ะ (เจ้าของโพลแตะไม่ได้, โพลปิดแล้วแตะไม่ได้, optimistic-then-revert-on-error, `Semantics(label: ...)` เดียวกัน) — **เพิ่มเงื่อนไขเดียว**: สมาชิกที่ `status` ยังไม่ `approved` ของ Club private เห็น `ClubPollCard` ไม่ได้เลย (ตรงกับ Club post ทั้งโพสต์ที่มองไม่เห็นอยู่แล้วในสถานการณ์นี้ — ไม่ใช่กติกาใหม่ของ Poll โดยเฉพาะ)

## Screen 3 — Feed/Detail Integration (ไม่มีของใหม่)

ไม่มี label พิเศษเพิ่มบนการ์ด Poll Club Post ทั้งใน `club_posts_tab`/`ClubPostCard` และ `ClubPostDetailScreen` — โครงเดิมทุกอย่าง (avatar/username/action row Like+Comment) มีแค่ media area เปลี่ยนเป็น `ClubPollCard` แทนรูป/ลิงก์ Pinned Post ที่เป็นโพลได้ตามปกติไม่มีข้อจำกัดพิเศษ (ตาม Product's Acceptance Criteria)

## Handoff (ไปยัง AI Coding)

**Schema ที่แนะนำ** (มิเรอร์ WYN-035 เป๊ะ เปลี่ยนแค่ prefix `drop`→`club_post`):
1. ตารางใหม่ `club_post_polls` (`club_post_id` unique FK cascade, `options text[]` 2-4 ช่อง validate ผ่าน `public.valid_poll_options()` — **function เดิมของ WYN-035 reuse ได้ตรงๆ ไม่ต้องสร้างใหม่** เพราะ validate แค่ array ไม่ผูกกับตารางใด, `expires_at`)
2. ตารางใหม่ `club_post_poll_votes` (`poll_id` FK cascade, `voter_id`, `option_index`, unique (poll_id, voter_id) รองรับเปลี่ยนใจผ่าน upsert) — SELECT policy จำกัดแค่แถวตัวเอง, `before insert or update` trigger เช็ค: หมดเวลาหรือยัง/option_index ในขอบเขต/ไม่ใช่เจ้าของโพล/**เป็นสมาชิกที่ approved ของ Club นั้นจริง** (เงื่อนไขเพิ่มจาก WYN-035 — ใช้ `club_role()` helper function ที่มีอยู่แล้วจาก WYN-014)
3. RPC `create_poll_club_post(p_club_id, p_content, p_options, p_duration_days, p_mentioned_user_ids)` — insert `club_posts`(image_urls=null, link_url=null) + `club_post_polls` + `club_post_mentions` แบบ atomic มิเรอร์ `create_poll_drop()` — **ต้องเช็คว่าผู้เรียกเป็นสมาชิก approved ของ club_id ก่อน insert เสมอ** (ตาม RLS/trust model เดิมของ `club_posts` insert policy)
4. RPC `get_club_poll_results(p_poll_ids uuid[])` — คืน `(poll_id, visible, total_votes, option_counts[])` ต่อโพล — `visible` เพิ่มเงื่อนไข "เป็นสมาชิก approved" นอกเหนือจาก (โหวตแล้ว/เจ้าของ/หมดเวลา) ที่ WYN-035 มี
5. Query ของ `ClubPostRepository.fetchPosts`/`fetchFromJoinedClubs`/`searchByContent`/`fetchById` เพิ่มคอลัมน์ join `club_post_polls` (`poll_id`, `poll_options`, `poll_expires_at`) ทุก query — มิเรอร์ที่ `home_feed` view ทำกับ `drop_polls`
6. **ไม่ต้องแก้ `notifications`/`reports`** เหมือน WYN-035 (เหตุผลเดียวกัน — ไม่แจ้งเตือนต่อโหวต, รายงาน Club post เดิมครอบคลุมโพลอยู่แล้ว)

**Flutter ที่แนะนำ**:
- `ClubPost` เพิ่ม field nullable: `pollId`/`pollOptions`/`pollExpiresAt`/`pollMyVoteIndex`/`pollTotalVotes`/`pollOptionCounts` (มิเรอร์ `HomeFeedItem`'s poll fields เป๊ะ) — `imageUrls`/`linkUrl` เป็น nullable อยู่แล้ว ไม่ต้องแก้
- `ClubPostRepository` เพิ่ม `createPollClubPost()`/`votePoll()` + batch fetch helper (`_fetchMyClubPollVotes`/`_fetchClubPollResults`) เรียกคู่กับ `_fetchLikedPostIds`/`_fetchSavedPostIds` ที่มีอยู่แล้วทุกจุด (`fetchPosts`, `fetchFromJoinedClubs`, `searchByContent`, `fetchById`)
- Widget ใหม่ 2 ตัว: `ClubPollComposer` (ใน `CreateClubPostScreen`, มิเรอร์ `PollComposer` ของ Drop แต่สี Sapphire), `ClubPollCard` (Screen 2, ใช้ร่วม `ClubPostCard`+`ClubPostDetailScreen`, มิเรอร์ `PollCard`)
- **ไม่มี widget "Grid Fallback" ต้องทำ** (ต่างจาก WYN-035 ที่ต้องทำ Screen 3 เพราะ Drop โผล่ใน grid หลายที่ — Club post ตรวจแล้วไม่ปรากฏใน grid ใดเลยในระบบ)
- `CreateClubPostScreen._canPost` ต้อง branch ตามโหมด (ปกติ = เงื่อนไขเดิม, โพล = คำถาม+ตัวเลือกครบ) — ไม่ใช่ OR รวมกัน
- ทุกจุดที่มี `post.imageUrls!`/`post.linkUrl!` แบบ non-null-assert (`ClubPostCard`, `ClubPostDetailScreen`) ต้องเช็ค `pollId != null` ก่อน branch ไป `ClubPollCard` แทน ไม่ใช่แค่เพิ่ม null check เฉยๆ (จะ crash runtime ถ้าลืมจุดใดจุดหนึ่ง — บทเรียนเดียวกับที่ WYN-035 เตือนไว้)
