# Design Spec — WYN-007: Home (Search bar + Feed รวม Drop/Pop)

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-007-home-feed.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `DropGridTile`/`DropDetailScreen` interaction row (WYN-005), `PopFeedScreen`'s scrim+overlay pattern (WYN-006), infinite-scroll+pull-to-refresh pattern (WYN-004/005/006 ทุกตัว)

## ทิศทางภาพรวม: การ์ด 2 ประเภทในฟีดเดียว ไม่ใช่แค่เอาการ์ดของแอปอื่นมาปน

Home ต้องแสดง Drop กับ Pop ปนกันในฟีดเดียวที่เลื่อนต่อเนื่อง — ความท้าทายเชิงออกแบบคือทำให้ผู้ใช้แยกออกทันทีด้วยสายตาว่าการ์ดไหนเป็นรูป การ์ดไหนเป็นวิดีโอ โดยไม่ทำให้ฟีดดูกระโดดสัดส่วนไปมาจนรก:

- **การ์ด Pop ใน Home ใช้ thumbnail แบบ crop เป็นสี่เหลี่ยมจัตุรัส 1:1 เท่ากับการ์ด Drop** (ไม่ใช่วิดีโอเต็มอัตราส่วน 9:16 แบบใน Pop Feed) เพื่อให้จังหวะการเลื่อนฟีดสม่ำเสมอ (การ์ดสูงใกล้เคียงกันทุกใบ) — ความแตกต่างจาก Drop สื่อสารผ่านไอคอน play เด่นชัดกลางการ์ด + badge ความยาววิดีโอมุมล่างขวา ไม่ใช่ผ่านสัดส่วนการ์ดที่ต่างกัน (การ์ดสัดส่วนต่างกันไปมาทำให้ฟีดดู "รก" และเป็นการยืมโครงสร้าง feed ของ TikTok/IG Reels ที่ผสม preview การ์ดในฟีดหลักโดยตรงเกินไป)
- ทั้งสองการ์ดใช้ **โครงสร้างเดียวกัน** (avatar+ชื่อ+เวลา ด้านบน / สื่อ 1:1 ตรงกลาง / แคปชัน / แถวปฏิสัมพันธ์ด้านล่าง) — สื่อสารว่าเป็น "ตระกูลเดียวกัน" ของ WYN ไม่ใช่แปะสอง component จากดีไซน์คนละชุด
- แถวปฏิสัมพันธ์ของการ์ด Pop ใน Home เพิ่มไอคอน "ตา" (view count) ที่การ์ด Drop ไม่มี — เป็นตัวช่วยแยกแยะเพิ่มเติมนอกจาก play icon

---

## Screen 1: Home (แท็บ Home ใน Bottom Nav, index 0)

Purpose: แสดงเนื้อหาทั้งหมดของ WYN (Drop+Pop) ปนกันเรียงตามเวลา พร้อม Search bar หัวจอ

User Flow: เปิดแอป → เห็น Home ทันที (แท็บแรก) → เลื่อนดูการ์ด Drop/Pop ปนกัน → แตะการ์ด Drop ไป Drop Detail / แตะการ์ด Pop ไปดูคลิปเต็มจอ → กด back กลับมาที่ตำแหน่งเดิมในฟีด → แตะ Search bar → เห็นหน้า "เร็ว ๆ นี้" ชัดเจน

Components:
- AppBar-equivalent ด้านบนสุด: **Search bar เต็มความกว้าง** (ไม่ใช่แค่ไอคอนแว่นขยาย) สไตล์ rounded input field พื้นหลัง Soft Gray ไอคอนแว่นขยาย + placeholder text "ค้นหา (เร็ว ๆ นี้)" — บอกสถานะตรง ๆ ในตัว placeholder เอง ไม่ต้องรอให้แตะก่อนถึงจะรู้ว่ายังใช้ไม่ได้
- Feed แนวตั้งคอลัมน์เดียว (ไม่ใช่ grid) — สลับกันไปมาระหว่างการ์ด Drop และการ์ด Pop ตามลำดับเวลาจริง
- **การ์ด Drop**: `AvatarCircle`+ชื่อ/@username ด้านบน, รูปภาพ 1:1 เต็มความกว้างการ์ด, แคปชัน (ถ้ามี), แถวปฏิสัมพันธ์ (Like หัวใจ+จำนวน / Comment บับเบิล+จำนวน / Share / Save) — mirror โครงสร้างของ `DropGridTile`+`DropDetailScreen` header รวมกัน
- **การ์ด Pop**: `AvatarCircle`+ชื่อ/@username ด้านบน (เหมือน Drop), thumbnail วิดีโอ crop เป็น 1:1 (ใช้ `thumbnail_url` ถ้ามี, fallback เป็น frame แรกของวิดีโอถ้าไม่มี thumbnail), **ไอคอน play วงกลมทึบตรงกลาง** ทับบน thumbnail, **badge ความยาวคลิป** (เช่น "0:45") มุมล่างขวาของ thumbnail, แคปชัน, แถวปฏิสัมพันธ์ (Like/Comment/Share/Save **+ ไอคอนตา/view count**)
- Pull-to-refresh ที่ด้านบนของ feed (ใต้ Search bar)
- Infinite scroll แบบเดียวกับ Drop Feed/Pop Feed

Interactions:
- แตะการ์ด Drop → เปิด `DropDetailScreen` (เหมือนที่ Drop Feed ทำอยู่แล้ว)
- แตะการ์ด Pop → เปิด**หน้าคลิปเดี่ยวเต็มจอ** (ไม่ใช่กระโดดเข้ากลาง Pop Feed ทั้งฟีด) — ดู Design Rules สำหรับเหตุผล
- แตะ Search bar → เปิดหน้า placeholder เต็มจอ "ค้นหา — เร็ว ๆ นี้" (ไอคอนแว่นขยายใหญ่ตรงกลาง + ข้อความ "ฟีเจอร์ค้นหากำลังจะมาเร็ว ๆ นี้" + ปุ่มย้อนกลับ) — ไม่ใช่แค่ SnackBar เฉย ๆ เพราะ Search เป็นฟีเจอร์ที่ผู้ใช้คาดหวังสูง ต้องให้ความรู้สึก "ตั้งใจทำหน้านี้ไว้รอ" ไม่ใช่ "ยังไม่เสร็จ"
- กด Like/Save บนการ์ดใดก็ได้ → toggle ทันที optimistic UI (pattern เดียวกับ Drop/Pop — อ่าน state สดใหม่ทุกครั้ง ไม่ capture ค่าตอน build)
- กด Comment → เปิดหน้า/sheet คอมเมนต์ของเนื้อหานั้นตามประเภท (Drop → comment section ใน `DropDetailScreen`, Pop → comment sheet เดียวกับที่ `PopFeedScreen` ใช้)
- Pull-to-refresh → โหลด feed รวมใหม่ทั้งหมด
- เลื่อนถึงล่างสุด → โหลดหน้าถัดไปอัตโนมัติ (ต่อเนื่องข้าม Drop/Pop ไม่สะดุด)

States:
- Loading (ครั้งแรก) — spinner กลางจอใต้ Search bar
- Loaded — feed ปกติ
- Empty (ยังไม่มี Drop/Pop เลยในระบบ) — ข้อความเชิญชวน "ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!" (จัดกลางจอ ใต้ Search bar ที่ยังคงแสดงอยู่เสมอ)
- Error (โหลดไม่สำเร็จ) — ข้อความ error + ปุ่มลองใหม่
- Loading more — spinner บางท้าย feed

Responsive Behavior: คอลัมน์เดียวเต็มความกว้างจอเสมอ (mobile-first) การ์ดปรับความสูงตามเนื้อหา (แคปชันยาว/สั้น) แต่พื้นที่สื่อ (รูป/thumbnail) คงสัดส่วน 1:1 เสมอไม่ว่าการ์ดประเภทไหน

Accessibility: Search bar มี semantics label "ค้นหา ยังไม่พร้อมใช้งาน" แต่ละการ์ดมี semantics label รวมบอกประเภทเนื้อหาด้วย (เช่น "รูปของ {username}" สำหรับ Drop, "วิดีโอของ {username} ความยาว {N} วินาที" สำหรับ Pop) ปุ่ม Like/Save ประกาศสถานะปัจจุบันเสมอ (เหมือน Drop/Pop)

Design Rules:
- **การ์ด Pop ใน Home ใช้ thumbnail สี่เหลี่ยมจัตุรัส ไม่ใช่วิดีโอเล่นอัตโนมัติเต็มอัตราส่วน** — เหตุผล 3 ข้อ: (1) เล่นวิดีโออัตโนมัติหลายตัวพร้อมกันขณะเลื่อน feed สิ้นเปลือง bandwidth/battery มากกว่าที่จำเป็น ต่างจาก Pop Feed ที่ตั้งใจให้เล่นทีละคลิปอยู่แล้ว (2) การ์ดสัดส่วนสม่ำเสมอ (1:1 ทุกใบ) ทำให้ฟีดเลื่อนลื่นและคาดเดาได้ ไม่กระโดดความสูงไปมา (3) ความแตกต่างจาก Drop สื่อสารผ่าน play icon + badge ความยาว ชัดเจนพอโดยไม่ต้องเล่นจริง
- **แตะการ์ด Pop จาก Home เปิดหน้าคลิปเดี่ยว ไม่ใช่กระโดดเข้ากลาง Pop Feed** — เหตุผล: Pop Feed เป็น infinite paginated list ที่ไม่มีแนวคิดเรื่อง "ตำแหน่งที่ N ของฟีดทั้งหมด" ให้กระโดดไปแบบแม่นยำได้ง่าย (ต้องรู้ page/offset ที่แน่นอนซึ่งซับซ้อนเกินความจำเป็นสำหรับ use case นี้) การเปิดหน้าคลิปเดี่ยวเต็มจอ (reuse UI/interaction เดียวกับที่ `PopFeedScreen` ใช้ต่อคลิปอยู่แล้ว แค่ไม่มี swipe ไปคลิปอื่น) ให้ประสบการณ์ครบถ้วนโดยไม่ต้องแก้ pagination model ที่มีอยู่แล้วให้ซับซ้อนขึ้น
- **ห้ามใช้ Liquid Glass บน play icon overlay ของการ์ด Pop** — ใช้ไอคอนวงกลมทึบสีขาว/ดำโปร่งแสงเล็กน้อยแบบเรียบง่าย ไม่ใช่พื้นผิวเบลอ

Handoff: AI Coding — **แนะนำให้ merge feed ของ `drops`/`pops` ด้วยแนวทาง database-side ตามที่ Product เสนอไว้ใน Risks** (เช่น สร้าง SQL view รวมสองตารางด้วย `UNION ALL` เรียงตาม `created_at` แล้ว paginate บน view เดียวนั้นตรง ๆ) แทนที่จะ fetch สองฝั่งแยกกันแล้ว merge/sort ฝั่ง client ซึ่งจะมีปัญหาเรื่อง pagination correctness เมื่อเลื่อนหลายหน้า — รายละเอียด query/schema ให้ Coding ตัดสินใจเอง แต่ผลลัพธ์ที่ paginate ถูกต้องคือ requirement บังคับ ไม่ใช่ nice-to-have สำหรับหน้าคลิปเดี่ยวของ Pop (เปิดจากการแตะการ์ด Pop ใน Home) แนะนำให้ดึงโค้ดส่วนแสดงผลคลิปเดี่ยว+overlay+interaction จาก `PopFeedScreen`'s `_PopClipView` มาทำเป็น widget ที่ reuse ได้ (เช่น extract ออกมาเป็น public widget แยกไฟล์) แทนที่จะ copy โค้ดซ้ำทั้งหมด

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Home screen ข้างต้น — ต้องลบโค้ด WYN-004 เดิมที่ไม่ใช้แล้วทิ้ง (`app/lib/features/feed/` ทั้งโฟลเดอร์และ test ที่เกี่ยวข้อง) ตามที่ Product ตัดสินใจไว้แล้วใน `.wyn/tasks/backlog/WYN-007-home-feed.md` (**ห้ามลบตาราง `posts`/`likes`/`comments` ออกจาก `supabase/schema.sql`** — เป็น destructive DB change ที่ยังรออนุมัติ Founder อยู่ที่ `.wyn/company/APPROVALS.md`) อัปเดต `RootShell` ให้แท็บ Home ชี้ไปหน้าจอจริงแทน placeholder "เร็ว ๆ นี้" ต้อง QA & Security ตรวจสอบก่อน deploy เสมอ — เน้นตรวจ pagination correctness ของ feed รวม (ไม่มี item ซ้ำ/หายเมื่อเลื่อนหลายหน้า), regression กับ Drop Feed/Pop Feed เดิม (ต้องยังทำงานปกติ), และตรวจว่าไม่มีการลบตาราง DB ใด ๆ โดยไม่ได้รับอนุมัติ
