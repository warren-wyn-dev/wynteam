# Design Spec — WYN-009: Search

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-009-search.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `TabBar` icon+label ของ `ViewProfileScreen` (WYN-013), แถวของ `FollowListScreen` (WYN-008/013), `DropGridTile` (WYN-005) / `PopGridTile` (WYN-013), `AutomaticKeepAliveClientMixin` tab pattern (WYN-013)

## ทิศทางภาพรวม: คำค้นเดียว ใช้ร่วมกันทั้ง 3 tab

ช่องพิมพ์คำค้นมีจุดเดียว อยู่เหนือ `TabBar` — **ไม่ใช่คำค้นแยกต่อ tab** เพราะโมเดลที่ผู้ใช้คาดหวังคือ "พิมพ์ชื่อ/คำนี้ครั้งเดียว แล้วสลับดูว่าใครมีเนื้อหาตรงกันบ้าง" ไม่ใช่ต้องพิมพ์ซ้ำ 3 รอบ — เมื่อคำค้นเปลี่ยน (หลัง debounce) ทั้ง 3 tab จะถูก reset และค้นหาใหม่ด้วยคำค้นเดียวกัน แต่แต่ละ tab ยังคง paginate/fetch อิสระของตัวเอง (คนละ repository คนละ query)

Search bar ใน `AppBar` เป็น `TextField` ตรง ๆ ไม่ใช่กล่องแยกใต้ AppBar — เป็น pattern ทั่วไปที่ไม่ผูกกับ Instagram/TikTok โดยเฉพาะ (Gmail, Play Store, ฯลฯ ก็ใช้) ไม่ขัดกติกา "ห้ามลอก Layout IG/TikTok"

---

## Screen 1: `SearchScreen` (แทนที่ `SearchPlaceholderScreen`)

Purpose: หน้าเดียวครบ — ช่องค้นหา + ผลลัพธ์ 3 ประเภท

Components:
- **AppBar**: `leading` เป็นปุ่มย้อนกลับมาตรฐาน (ไม่ใช่ปุ่ม "ยกเลิก" แบบ text-button ของ iOS/บาง app ที่กะเทาะจาก IG) — `title` แทนที่ด้วย `TextField` เต็มความกว้าง (hint: "ค้นหา username, Drop, Pop") **auto-focus ทันทีที่เปิดหน้า** (ผู้ใช้แตะ search bar มาเพื่อพิมพ์ทันที ไม่ใช่มาดูอย่างอื่นก่อน) มีปุ่ม clear (ไอคอน X) ปรากฏใน `TextField` เฉพาะตอนมีข้อความอยู่ — กดแล้วล้างคำค้นกลับไปที่ empty state ทันที
- **TabBar** ใต้ AppBar: 3 tab icon+label เหมือนกันทุกจุดในแอป — "User" (`Icons.person_outline`), "Drop" (`Icons.grid_view_outlined`), "Pop" (`Icons.play_circle_outline`)
- **TabBarView**: เนื้อหาแต่ละ tab ตาม Screen 2/3/4 ด้านล่าง — ใช้ `AutomaticKeepAliveClientMixin` เหมือน Profile tabs (WYN-013) เพื่อไม่ให้สลับ tab แล้วโหลดใหม่ทุกครั้งถ้าคำค้นไม่เปลี่ยน แต่ต้อง reset+refetch เมื่อคำค้น (prop จาก parent) เปลี่ยนจริง

Interaction — Debounce:
- พิมพ์ทุกตัวอักษรจะ reset debounce timer (400ms) ใหม่ — ไม่ยิง query จนกว่าจะหยุดพิมพ์ครบ 400ms
- คำค้นสั้นกว่า 2 ตัวอักษร (นับหลัง trim ช่องว่าง) → ไม่ยิง query เลย ไม่ว่าจะหยุดพิมพ์นานแค่ไหน — แสดง prompt state (Screen 2/3/4)
- ลบคำค้นจนว่าง → ทุก tab กลับไป prompt state ทันที (ไม่ต้องรอ debounce เพราะเป็นการ "ยกเลิก" ไม่ใช่ "ค้นหาใหม่")

Loading:
- **ไม่แสดง spinner ระหว่างรอ debounce** (ผู้ใช้กำลังพิมพ์อยู่ เห็นตัวอักษรตัวเองอยู่แล้ว ไม่ต้อง feedback เพิ่ม — โชว์/ซ่อน spinner ทุกตัวอักษรจะกระพริบรำคาญ)
- แสดง `CircularProgressIndicator` กึ่งกลางใต้ TabBar **เฉพาะตอนที่ query จริงกำลังยิงอยู่** (หลัง debounce ผ่านแล้ว) แทนที่ผลลัพธ์เก่า/prompt ชั่วคราว

Accessibility: `TextField` มี `hintText` ทำหน้าที่ label อยู่แล้ว (ตาม convention เดิมของแอปที่ใช้ hint แทน floating label) ปุ่ม clear มี `Semantics(label: 'ล้างคำค้นหา', button: true)`

---

## Screen 2: User results tab

Components: **reuse โครงสร้างแถวของ `FollowListScreen` ตรง ๆ** (avatar 20px + ชื่อ/@username สองบรรทัด + ทั้งแถวเป็น `InkWell`) — ต่างแค่แหล่งข้อมูล (ค้นหาแทนดึงรายชื่อ follow) และ Semantics label ("ผู้ใช้ {ชื่อ} ยูสเซอร์เนม {username} กดเพื่อดูโปรไฟล์" เหมือนกันเป๊ะ)

Empty states:
- Prompt (ยังไม่พิมพ์/พิมพ์สั้นกว่า 2 ตัวอักษร): ไอคอน `Icons.person_search_outlined` + ข้อความ "พิมพ์ username หรือชื่อเพื่อค้นหาคน"
- ไม่พบผลลัพธ์: "ไม่พบผู้ใช้สำหรับ \"{คำค้น}\""

Interaction: แตะแถว → เปิด `ViewProfileScreen(userId: ...)`

---

## Screen 3: Drop results tab

Components: **grid 3 คอลัมน์ reuse `DropGridTile` ตรง ๆ** เหมือน `ProfileDropGridTab` (WYN-013) ทุกประการ

Empty states:
- Prompt: ไอคอน `Icons.grid_view_outlined` + "พิมพ์คำในแคปชันเพื่อค้นหา Drop"
- ไม่พบผลลัพธ์: "ไม่พบ Drop สำหรับ \"{คำค้น}\""

Interaction: แตะ tile → เปิด `DropDetailScreen`

---

## Screen 4: Pop results tab

Components: **grid 3 คอลัมน์ reuse `PopGridTile` ตรง ๆ** (WYN-013) เหมือน `ProfilePopGridTab` ทุกประการ

Empty states:
- Prompt: ไอคอน `Icons.play_circle_outline` + "พิมพ์คำในแคปชันเพื่อค้นหา Pop"
- ไม่พบผลลัพธ์: "ไม่พบ Pop สำหรับ \"{คำค้น}\""

Interaction: แตะ tile → เปิด `PopSingleClipScreen`

---

## Design Rules

- ปุ่มย้อนกลับมาตรฐาน ไม่ใช่ text-button "ยกเลิก" — สม่ำเสมอกับปุ่มย้อนกลับที่ทุกหน้าจอในแอปใช้อยู่แล้ว
- คำค้นเดียวใช้ร่วมทั้ง 3 tab ไม่ใช่แยกคนละคำค้น (เหตุผลด้านบน)
- Empty state ข้อความต่างกันตามประเภท (User/Drop/Pop) ไม่ใช้คำกลาง ๆ แบบเดียวกันหมด — ให้ผู้ใช้เข้าใจทันทีว่ากำลังดู tab ไหนอยู่แม้ไม่ได้มองที่ TabBar

Handoff: AI Coding —
1. แทนที่ `SearchPlaceholderScreen` ด้วย `SearchScreen` ใหม่ (ลบไฟล์เดิมทิ้ง route เดิมใน `home_feed_screen.dart` ยังคง push ไปที่หน้าค้นหาเหมือนเดิม)
2. เพิ่ม `ProfileRepository.searchProfiles({query, page})`, `DropRepository.searchByCaption({query, page})`, `PopRepository.searchByCaption({query, page})` ใหม่ (ไม่แก้ method เดิม)
3. Debounce ด้วย `Timer`/`Timer.cancel()` จริง ไม่ใช่ `Future.delayed` เดี่ยว ๆ (ดู Risks ใน Product spec)
4. เขียน regression test ครอบคลุม: debounce ไม่ยิง query ซ้อน (call-count assertion), คำค้นสั้นกว่า 2 ตัวอักษรไม่ยิง query, ลบคำค้นกลับ prompt state, ผลลัพธ์ทั้ง 3 ประเภทแตะแล้วไปถูกหน้า, empty state ข้อความถูก tab
5. ต้อง QA & Security ตรวจสอบก่อนอนุมัติ

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-4 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/WYN-009-search.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
