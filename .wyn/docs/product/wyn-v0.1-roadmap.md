# WYN V0.1 Roadmap — หลัง Product Direction เปลี่ยน (2026-08-14)

> อ้างอิงคำตัดสินใจของ Founder ที่ `.wyn/company/DECISIONS.md` (2026-08-14) — แทนที่ทิศทาง Product เดิมทั้งหมดด้วย "WYN V0.1 — CORE APP FEATURE PROMPT" (Home / Drop / Pop / Profile)

## สถานะปัจจุบัน

| Task | Feature | สถานะ | หมายเหตุ |
|---|---|---|---|
| WYN-002 | Authentication & Onboarding | ✅ Approved | ตรงกับ spec ใหม่ (Register/Login/Logout) — **ใช้เป็นฐานต่อได้เลย ไม่ต้องทำใหม่** |
| WYN-003 | User Profile (view/edit) | ✅ Approved | ตรงกับ spec ใหม่บางส่วน (Edit Profile, Bio, Profile Picture) — **ต้องขยายเพิ่ม** (Followers/Following, Drop grid, Pop list, Saved tab) ดู WYN-013 ด้านล่าง |
| WYN-004 | Feed & Post (รวมข้อความ+รูปในโพสต์เดียว) | ✅ Approved (แต่ถูกแทนที่) | **ไม่ตรงกับ spec ใหม่** — spec ใหม่แยก Drop (รูปภาพ) กับ Pop (คลิปสั้น) เป็นคนละระบบ ไม่ใช่โพสต์แบบผสม โค้ดที่มีอยู่ (Feed/PostRepository/PostCard) จะถูกใช้เป็นจุดอ้างอิงด้าน pattern (RLS, pagination, optimistic update) แต่ตัว Feed screen เองจะถูกแทนที่ |

## Task ใหม่ทั้งหมด (จาก spec "WYN V0.1 — CORE APP FEATURE PROMPT")

| Task | Feature | Priority Tier | Depends on |
|---|---|---|---|
| WYN-005 | Drop (โพสต์รูปภาพ) — Create Drop, Upload Image, Caption, Hashtag, Mention, Like, Comment | **P0 — เริ่มก่อน** | WYN-002, WYN-003 |
| WYN-006 | Pop (คลิปสั้นแนวตั้ง) — Create Pop, Upload Video, Caption, Hashtag, Mention, vertical swipe feed, Like, Comment, Views | P0 | WYN-002, WYN-003 |
| WYN-007 | Home — Search bar บนสุด + Feed รวม Drop/Pop | P1 | WYN-005, WYN-006 |
| WYN-008 | Follow system — Follow/Unfollow, Followers/Following list | P1 | WYN-002, WYN-003 |
| WYN-009 | Search — Users, Drop, Pop, Hashtag | P2 | WYN-005, WYN-006, WYN-007 |
| WYN-010 | Share — Share Content, Copy Link | P2 | WYN-005, WYN-006 |
| WYN-011 | Save — Save Drop/Pop, ดู Saved ใน Profile | P2 | WYN-005, WYN-006 |
| WYN-012 | Notification — Like/Comment/Follow/Mention | P2 | WYN-005, WYN-006, WYN-008 |
| WYN-013 | Profile V2 — Followers/Following, Drop grid, Pop list, Saved tab | P1 | WYN-008, WYN-011 |

Priority tier มาจากการวิเคราะห์ dependency graph ล้วน ๆ (ไม่ใช่ business priority ที่ Founder ยังไม่ได้ยืนยัน):
- **P0**: ต้องมีก่อน เพราะไม่มีเนื้อหา (content) ให้ฟีเจอร์อื่นอ้างอิงเลยถ้ายังไม่มี
- **P1**: ต้องมี Drop/Pop อยู่แล้วถึงจะมีความหมาย (Home ไม่มีอะไรให้แสดงถ้ายังไม่มี Drop/Pop, Profile V2 ไม่มีอะไรให้ grid/list ถ้ายังไม่มี Follow/Save)
- **P2**: เสริมประสบการณ์ ไม่ block การใช้งานหลัก (Search/Share/Save/Notification ทำทีหลังได้โดยไม่กระทบ Drop/Pop/Home ที่ใช้งานได้แล้ว)

## คำแนะนำจาก AI Product Manager

เริ่มที่ **WYN-005 (Drop)** ก่อน ด้วยเหตุผล:
1. ตรงกับ "การโพสต์รูปภาพ" ซึ่งเป็นรูปแบบเนื้อหาพื้นฐานที่สุดของ WYN — ไม่มี Drop ก็ไม่มีอะไรให้ Home/Search/Save/Share/Notification ทำงานด้วยเลย
2. ใกล้เคียงกับสิ่งที่ทีมเพิ่งพัฒนาสำเร็จใน WYN-004 มากที่สุด (RLS pattern, pagination, optimistic like, Storage bucket) — ความเสี่ยงต่ำกว่า Pop ซึ่งต้องเริ่มทำ video handling ใหม่ทั้งหมด (ยังไม่เคยทำในโปรเจกต์นี้เลย)
3. ทำให้เห็นผลเร็ว (Founder เห็นแอปที่ "โพสต์รูปได้จริง" ก่อน) และเก็บบทเรียนเรื่อง video-specific ปัญหา (ขนาดไฟล์ใหญ่, compression, thumbnail) ไว้ทำตอน Pop ทีหลังเมื่อพร้อมกว่า

ดู task spec เต็มที่ `.wyn/tasks/backlog/WYN-005-drop-post-image.md`

## คำถามเปิดที่ต้องให้ Founder ยืนยัน

1. **Hashtag/Mention**: spec ระบุว่า Drop/Pop ต้อง "เพิ่ม Hashtag" และ "Mention ผู้ใช้" ได้ตอนสร้างโพสต์ แต่ยังไม่ได้ระบุว่าต้อง**คลิกแตะ hashtag/mention แล้วไปหน้าไหน**ทันที (เช่น หน้ารวมโพสต์ที่ติด hashtag นั้น หรือหน้าโปรไฟล์ของคนที่ถูก mention) — เสนอให้ขอบเขต WYN-005 รอบแรกทำแค่ "พิมพ์ hashtag/mention ในแคปชันได้ ระบบรู้จำและบันทึกไว้" ส่วน "แตะแล้วไปที่ไหน" ผูกกับ WYN-009 (Search) แทน เพราะเป็นเรื่องเดียวกับการค้นหา hashtag
2. **Follow ปรากฏใน Drop ด้วยหรือไม่**: spec section 3 (Drop) ไม่ได้ระบุ Follow ไว้ในรายการปฏิสัมพันธ์ของ Drop โดยตรง (มีแค่ Like/Comment/Share/Save) แต่ section 4 (Pop) ระบุ Follow ไว้ชัดเจน และ section 7 ก็นิยาม Follow เป็นระบบพื้นฐานทั่วทั้งแอป — เสนอให้ Follow ใช้ได้จากทั้ง Drop และ Pop (กดที่ profile ของผู้โพสต์) ผ่าน WYN-008 ตัวเดียว ไม่ต้องแยกทำสองรอบ
3. **Home มีการกรองตาม Follow หรือไม่**: spec ไม่ได้ระบุชัดว่า Home แสดงเฉพาะคนที่ Follow หรือแสดงทุกคน (global) เหมือน WYN-004 เดิม — เสนอให้ทำแบบ Global ก่อน (เหมือน WYN-004) เพราะ Follow ยังไม่มีในระบบตอนที่ WYN-007 เริ่มทำ

Handoff: รอ Founder ยืนยันคำถามเปิดข้างต้น + อนุมัติให้เริ่ม WYN-005 ก่อน แล้วส่งต่อ AI Design (`/design`)
