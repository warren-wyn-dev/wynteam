# Product Full Spec — WYN-102

Status: full spec complete (2026-09-02) — ready for AI Coding โดยตรง (ไม่ต้องผ่าน Design เต็มรูปแบบ — ดู Handoff)
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` ข้อ 11/28, `.wyn/tasks/backlog/WYN-102.md`

Feature: ถอดฟีเจอร์ "Pop" ออกจากสายตาผู้ใช้ทั้งหมด (ซ่อน ไม่ลบโค้ด/ข้อมูล)

Goal: ไม่มีทางเข้าถึง Pop จาก UI เลยแม้แต่จุดเดียว แต่โค้ด/schema/route ยังอยู่ครบพร้อมเปิดกลับมาใน V3

Target User: ผู้ใช้ WYN Social ทุกคน

## Problem — สถานะปัจจุบันจริง (ตรวจโค้ดแล้ว): ถอดไปแล้วบางส่วน ยังเหลืออีกหลายจุด

Pop **ถูกถอดออกจาก Bottom Nav ไปแล้วตั้งแต่ WYN-024** (2026-08-14/22, ดู `.wyn/company/DECISIONS.md`) — `root_shell.dart` มี doc comment ยืนยันชัดเจน: "Pop and ZOKY are unmounted here, not deleted...per the V1.0.0 roadmap (Pop -> V3)" — งานนี้**ไม่ใช่งานใหม่ทั้งหมด** เป็นการ "ตามให้ครบ" จุดที่ยังหลงเหลืออยู่ ตรวจแล้วพบ **4 จุดที่ Pop ยังเข้าถึงได้จริงวันนี้**:

1. **Search screen มีแท็บ "Pop" เต็มรูปแบบ**: `search_screen.dart` บรรทัด 228 มี `Tab(icon: Icon(Icons.play_circle_outline), text: 'Pop')` และบรรทัด 263 render `SearchPopResultsTab` จริง — กดเข้าไปดู Pop ได้เต็มๆ ผ่านทางนี้
2. **Search placeholder ข้อความ**: บรรทัด 193 `hintText: 'ค้นหา username, โพสต์, Pop, Club'` — ยังพูดถึง Pop ตรงๆ (Note: ข้อความนี้ผ่าน WYN-077 ไปแล้วเปลี่ยน "Drop"→"โพสต์" แต่คำว่า "Pop" เองยังไม่ถูกลบ เพราะ WYN-077 ทำแค่ rename ไม่ใช่ remove)
3. **Pop content ยังปรากฏใน Home Feed จริง**: `home_feed` view (schema.sql, นิยามล่าสุดบรรทัด ~10538) ทำ `union all` รวม Pop เข้ากับ Drop โดยตรง (`'pop'::text as content_type`) — **นี่คือจุดที่ใหญ่ที่สุดและเสี่ยงพลาดที่สุด** เพราะไม่ใช่แค่ UI แต่เป็นระดับ view/query — ถ้าไม่กรองออก ผู้ใช้จะยังเห็นการ์ด Pop ปนอยู่ใน Home feed ตามปกติทั้งที่ปุ่มเข้าถึง Pop โดยตรงถูกถอดไปหมดแล้ว
4. **`HomePopCard`/`pop_clip_view.dart`/`create_pop_screen.dart` และ routing ที่เกี่ยวข้อง**: widget ยังถูก render จริงถ้ามี Pop content หลุดเข้ามาในฟีด (เชื่อมกับข้อ 3)

## Data Model Impact

**ไม่แก้ schema เลยตามหลักการ "ซ่อน ไม่ลบ" ของ Founder** — วิธีที่ถูกต้องคือกรองที่ **query/view layer** ไม่ใช่ RLS/DROP TABLE:

- แก้ `home_feed` view: เพิ่มเงื่อนไขกรอง Pop ออกจากผลลัพธ์ — วิธีที่ปลอดภัยที่สุดคือ**ไม่แก้ตัว view เลย** (หลีกเลี่ยงแตะ `home_feed` ที่มีปัญหาสะสม 7 จุดอยู่แล้วตาม DECISIONS.md 2026-09-02 เรื่อง `schema.sql` โหลดสดไม่ผ่าน — ยิ่งแตะยิ่งเสี่ยงชนปัญหาเดิม) แทนที่ด้วยการ**กรองฝั่ง Flutter query แทน**: `HomeRepository`'s fetch methods (ที่ query จาก `home_feed` view อยู่แล้ว) เพิ่ม `.neq('content_type', 'pop')` เข้าไปในทุก query ที่ดึงจาก view นี้เพื่อแสดงผลใน Home/Trending/Top100/Search-Drop-tab — เป็นการกรองที่ **application layer** ซึ่งย้อนกลับง่ายที่สุด (ลบ `.neq()` บรรทัดเดียวก็เปิด Pop กลับมาได้ทันทีตอน V3) และไม่แตะ schema/view เลยตามที่ Founder สั่งเป๊ะๆ ("พักเก็บไว้" ไม่ใช่ "ปรับโครงสร้าง")
- **ข้อควรระวัง**: ต้อง grep หา **ทุกจุด** ที่ query จาก `home_feed` view (ไม่ใช่แค่ Home screen เอง — Search's "Trending"/"Top100" ก็ query จาก view เดียวกันผ่าน `HomeRepository.fetchTrending()`/`fetchTopContent()` ตามที่ยืนยันแล้วใน WYN-101's investigation) เพิ่ม filter ให้ครบทุก call site ไม่ใช่แค่ Home feed ตรงๆ

## Requirements

**1. Search screen**: ลบแท็บ "Pop" ทั้งแท็บออก (Tab widget + TabBarView content + `SearchPopResultsTab` reference) — เหลือ User/โพสต์/Club (3 แท็บแทน 4)
**2. Search placeholder**: `'ค้นหา username, โพสต์, Pop, Club'` → **`'ค้นหา username, โพสต์, Club'`**
**3. กรอง Pop ออกจากทุก query ที่อ่านจาก `home_feed` view** (Home feed ปกติ, Trending, Top100/Discovery) ผ่าน `.neq('content_type', 'pop')` ที่ `HomeRepository`
**4. ตรวจ Bottom Nav/เมนูอื่นทั้งหมด**: ยืนยันว่า `RootShell` ไม่ได้ mount `PopRepository`-based screen ใดๆ อยู่แล้ว (ตรวจแล้ว — Pop ไม่อยู่ใน 5 destination ของ Bottom Nav ตั้งแต่ WYN-024) — เป็น regression check ไม่ใช่งานใหม่
**5. `SideMenu`/`Settings`/ที่อื่นๆ**: grep คำว่า "Pop"/`PopRepository`/`pop_` ให้ครบทั้ง `app/lib` เพื่อไม่ให้พลาดจุดที่มองไม่เห็นจาก 4 จุดที่ระบุไว้ข้างบน (เช่น deep link handler, notification type ที่ระบุ "X ถูกใจ Pop ของคุณ" ฯลฯ — ถ้ามี notification เดิมของ Pop ที่ยังส่งอยู่ ต้องตัดสินใจว่าจะยังส่งไหม ดู Edge Case)

## Edge Cases

1. **ผู้ใช้มี Pop เดิมที่เคยโพสต์ไว้**: ยังอยู่ในระบบ ไม่ถูกลบ แค่ไม่แสดงที่ไหนเลย — รวมถึงในโปรไฟล์ตัวเอง (ต้องเช็คว่า Profile grid tab ดึง Pop ของตัวเองมาแสดงไหม ถ้ามีต้องกรองออกเช่นกันเพื่อความสอดคล้อง "ไม่มีทางเข้าถึง Pop จาก UI เลยแม้แต่จุดเดียว")
2. **Notification เดิมที่อ้างอิงถึง Pop** (เช่น "คนถูกใจ Pop ของคุณ" ที่ยิงไปแล้วก่อนซ่อนฟีเจอร์): แจ้งเตือนเก่ายังอยู่ใน list ได้ (ไม่ลบ notification history) แต่กดแล้วต้องไม่ error/crash — ถ้าปลายทาง (Pop detail screen) ไม่ถูก mount ที่ไหนแล้ว ต้องมี fallback ที่ปลอดภัย (เช่นแสดงข้อความ "เนื้อหานี้ไม่พร้อมใช้งานแล้ว" แทนที่จะ throw)
3. **Trigger/notification ใหม่ที่ยังคอย insert แถว 'pop' type ต่อไป** (ฝั่ง DB): ปล่อยให้ยังทำงานตามปกติ (ไม่แตะ trigger — Pop ยังโพสต์/ไลค์กันได้ในระดับ backend ถ้ามีทางเรียก API ตรง แค่ UI ไม่เปิดทางให้สร้างใหม่ผ่านหน้าแอปเท่านั้น เพราะ `create_pop_screen.dart` ไม่ถูก mount แล้ว) — สอดคล้องกับ "ซ่อน ไม่ลบ" ครบทุกชั้น

## Acceptance Criteria
- [ ] หาทางเข้าถึงฟีเจอร์ Pop จากหน้า UI ไม่เจอแล้วทุกจุด (Search tab, placeholder text, Home feed content, Profile grid ของตัวเอง)
- [ ] โค้ด Pop (`app/lib/features/pop/**`), ตาราง `pops`/`pop_likes`/`pop_comments` ใน schema.sql ยังอยู่ครบ ไม่ถูกลบแม้แต่บรรทัดเดียว
- [ ] Home feed/Trending/Top100/Discovery ไม่มีการ์ด Pop ปนอยู่เลย
- [ ] Notification เก่าที่อ้างอิง Pop กดแล้วไม่ crash (มี fallback ที่ปลอดภัย)
- [ ] เปิดกลับมาได้ง่าย: การ revert ทำได้ด้วยการลบ `.neq('content_type','pop')` + คืน Tab/placeholder text กลับ ไม่ต้อง migrate ข้อมูลใดๆ

## Dependencies
เกี่ยวข้องกับ WYN-077 (rename Drop→โพสต์ ทำไปแล้ว — คำว่า "Pop" ใน placeholder ยังไม่ถูกแตะเพราะเป็นคนละงาน)

## Out of Scope (รอบนี้)
- ลบโค้ด/schema/route ของ Pop ทิ้งจริง (ตรงข้ามกับที่ Founder สั่ง "พักเก็บไว้")
- เปลี่ยน/ลบ `PopRepository`, models, RPC ฝั่ง backend
- บล็อกการเรียก Pop-related RPC/table ผ่าน API ตรง (นอกสโคป — Founder ต้องการซ่อนจาก "สายตาผู้ใช้" ในแอป ไม่ใช่ปิดกั้นระดับ backend)

## Risks

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ซ่อนไม่หมดทุกจุด โดยเฉพาะจุดที่ไม่ชัดเจนอย่าง `home_feed` view's UNION ALL (ไม่ใช่แค่ nav/route ที่มองเห็นง่าย) | กลาง-สูง | grep คำว่า `'pop'`/`PopRepository`/`content_type.*pop` ให้ครบทั้ง `app/lib` และทุก query ที่อ่านจาก `home_feed` ก่อนสรุปว่าซ่อนครบ (ระบุไว้แล้วในข้อ 3-5 ของ Requirements) |
| R2 | แก้ query ผิดจุดจนกรอง Drop ปนออกไปด้วย (เผลอกรองผิดเงื่อนไข) | ต่ำ | เทส regression ยืนยัน Drop/Redrop ยังปรากฏครบเหมือนเดิมหลังเพิ่ม filter |

## Recommendation
อนุมัติ ทำได้ทันที — งานนี้เสี่ยงต่ำ (ไม่แตะ schema) แต่ต้องละเอียดเรื่อง "ครบทุกจุด" ให้มากกว่าที่ backlog เดิมประเมินไว้ (เดิมมองว่าเป็นแค่ nav/placeholder แต่จริงๆ กระทบ Home feed content โดยตรงด้วย)

## Handoff
ส่งต่อ **AI Coding** (`/code`) ทำตรงได้เลย — grep หาทุกจุดให้ครบตาม 5 ข้อใน Requirements ก่อนเริ่มแก้ ไม่ต้องผ่าน AI Design (ไม่มีหน้าจอใหม่ มีแต่การซ่อน/ลบ tab+filter query เดิม) → AI QA (เน้นตรวจ Home feed/Trending/Top100 ไม่มี Pop ปนเลย และ notification เก่าไม่ crash)
