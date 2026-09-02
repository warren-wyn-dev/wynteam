# Feature Request — WYN-102

Status: coded, awaiting QA (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 11/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: ถอดฟีเจอร์ "Pop" ออกจากแอป (ซ่อน ไม่ลบโค้ด)
Goal: เอาฟีเจอร์ Pop ออกจากสายตาผู้ใช้ทั้งหมดชั่วคราว แต่เก็บโค้ดไว้พร้อมกลับมาใช้ในอนาคต
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ตัดฟีเจอร์ Pop ออกก่อนทุกอย่าง หมายถึงเอาออกเฉยๆ พักเก็บไว้"
Requirements:
- ซ่อนทางเข้าถึง Pop ทั้งหมดจาก UI: bottom nav (ถ้ามี), ช่อง placeholder ค้นหา ("ค้นหา username, Drop, Pop, Club" → เอาคำว่า Pop ออก), เมนูต่างๆ
- **ไม่ลบโค้ด/schema/route ของ Pop ออกจากโปรเจกต์** — ปิดการเข้าถึงด้วย feature flag หรือคอมเมนต์ route ออกแทน เพื่อให้เปิดกลับมาได้ง่ายตามที่ Founder สั่ง "พักเก็บไว้"
Acceptance Criteria:
- [x] หาทางเข้าถึงฟีเจอร์ Pop จากหน้า UI ไม่เจอแล้วทุกจุด
- [x] โค้ด Pop ยังอยู่ในโปรเจกต์ครบ ไม่ถูกลบ พร้อมเปิดกลับได้
Dependencies: เกี่ยวข้องกับ WYN-077 (ลบคำว่า Pop ออกจาก placeholder ค้นหาพร้อมกับงาน rename)
Priority: สูง (ทำได้เร็ว Founder ระบุให้ทำก่อนทุกอย่าง)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ซ่อนไม่หมดทุกจุด เหลือ dead-link ที่กดแล้ว error | ต่ำ-กลาง | grep หา route/reference คำว่า Pop ให้ครบก่อนซ่อน — **ปิดแล้ว**: grep ทั้ง `app/lib` หลายรอบ ครอบคลุม nav/query/notification/settings copy |
Recommendation: อนุมัติ ทำได้ทันที
Handoff: AI Coding ทำตรงได้เลย (grep หาทุกจุดให้ครบก่อน)

## Product Full Spec Output (2026-09-02)

เขียน full spec เสร็จแล้วที่ `.wyn/docs/product/wyn-102-hide-pop.md` — ยืนยันว่า Pop ถูกถอดจาก Bottom Nav ไปแล้วตั้งแต่ WYN-024 (ไม่ใช่งานใหม่ทั้งหมด) แต่พบ 4 จุดที่ยังเข้าถึง Pop ได้จริงวันนี้ที่ backlog เดิมไม่ได้ระบุครบ: (1) แท็บ "Pop" เต็มรูปแบบใน Search screen (2) คำว่า "Pop" ใน search placeholder (3) **Pop content ยังปรากฏใน Home feed/Trending/Top100 จริง** เพราะ `home_feed` view ทำ UNION ALL รวม Drop+Pop โดยตรง — จุดนี้ใหญ่และเสี่ยงพลาดที่สุด ต้องกรองที่ query layer (`HomeRepository`) ไม่ใช่แค่ nav (4) `HomePopCard`/routing ที่เกี่ยวข้อง — แนะนำกรองด้วย `.neq('content_type','pop')` ที่ query layer แทนการแก้ schema/view (ปลอดภัยกว่า เพราะ `home_feed` view มีปัญหาสะสมอยู่แล้วตาม DECISIONS.md และย้อนกลับง่ายตอน Pop V3)

ไม่มีจุดที่ต้อง ping Founder เพิ่ม

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-102-hide-pop.md`

Handoff: ส่งต่อ AI Coding (`/code`) โดยตรง ไม่ต้องผ่าน AI Design

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — Pop ถูก unmount จาก Bottom Nav ไปแล้วตั้งแต่ WYN-024 แต่ยังเหลือหลายจุดที่เข้าถึงได้จริง ตามที่ product spec ตรวจพบ + เพิ่มอีก 3 จุดที่ product spec เองก็ยังไม่ครบ (Saved tab, ReDrop ของ Pop, notification tap)

การเปลี่ยนแปลง (ทุกจุด "ซ่อน ไม่ลบ" — ไม่แตะไฟล์ใดใน `app/lib/features/pop/**` เลยแม้แต่บรรทัดเดียว):

1. **`search_screen.dart`**: ลบ Tab "Pop" + `SearchPopResultsTab(...)` ออกจาก TabBarView (`DefaultTabController.length` 4→3), ลบ import `search_pop_results_tab.dart` (ไฟล์ widget เองยังอยู่ครบ), แก้ placeholder `'ค้นหา username, โพสต์, Pop, Club'` → `'ค้นหา username, โพสต์, Club'` — `popRepository` ยังคงเป็น required param เพราะ `DiscoveryView`/tab อื่นยังใช้อยู่
2. **`home_repository.dart`**: เพิ่ม `.neq('content_type', 'pop')` (ค่าคงที่ `_hiddenContentType`) ครบทุก query ที่อ่านจาก `home_feed` view — `fetchFeed`, `fetchTrending`, `fetchTopContent`, `fetchFollowingFeed`, `fetchRedropsByUser` (พบเพิ่มเติมว่า Pop สามารถถูก ReDrop ได้ ไม่ใช่แค่ Drop ตามที่ doc comment เดิมของ method นี้ระบุไว้ — จุดที่ product spec ไม่ได้เอ่ยถึง) — `fetchRankedFeed` (RPC `get_wynos_ranked_feed()`) กรองหลังดึงข้อมูลด้วย `.where()` ใน Dart แทน (ไม่มี query builder ให้ `.neq()` ก่อนเรียก RPC)
3. **`saved_repository.dart`**: เพิ่ม filter เดียวกันให้ `fetchFeed()` (query จาก `saved_feed` view) — **จุดที่ product spec เองพลาดไป** เพราะเป็น view คนละตัวกับ `home_feed` (Saved tab ในโปรไฟล์ตัวเอง)
4. **`notification_list_screen.dart`**: `_openPop()` เขียนใหม่ทั้งหมด — เดิม fetch Pop จริงแล้วเปิด `PopSingleClipScreen` ถ้าเจอ ตอนนี้แสดง SnackBar "เนื้อหานี้ไม่พร้อมใช้งานแล้ว" ทันทีโดยไม่ fetch/navigate เลย (ปิด Edge Case 2 ของ product spec แบบเข้มกว่าที่ระบุไว้ — ไม่ใช่แค่ "ไม่ crash" แต่ปิดทางเข้าถึงจริงๆ ตามหลักการ "ไม่มีทางเข้าถึง Pop แม้แต่จุดเดียว") — ลบ import `pop_single_clip_screen.dart` ที่ไม่ใช้แล้ว
5. **UI copy อื่นที่พูดถึง "Pop" ตรงๆ** (พบจาก grep ข้อความ UI ทั้งแอป, นอกเหนือจาก Requirements เดิมที่ระบุไว้แค่ placeholder): `profile_saved_tab.dart`'s empty state, `follow_list_screen.dart`'s empty state, `settings_screen.dart`'s comment-permission subtitle, `notification_settings_screen.dart`'s likes-notification subtitle — ทั้งหมดลบคำว่า "Pop" ออกจากข้อความที่ผู้ใช้เห็น (การตั้งค่าเบื้องหลังยังคุม Pop เหมือนเดิม แค่ไม่พูดถึงในคำอธิบาย)

**ไม่ได้แตะ** (ตัดสินใจแล้วว่าอยู่นอกสโคป):
- `delete_account_screen.dart`'s bullet "โพสต์, Pop และ Comment ทั้งหมดของคุณ" — เป็นข้อมูลจริงเรื่องสิ่งที่จะถูกลบตอนลบบัญชี ไม่ใช่การชี้ชวนให้ใช้ฟีเจอร์ ควรคงความถูกต้องไว้
- Notification เก่าที่มีข้อความ "ถูกใจ Pop ของคุณ"/"แสดงความคิดเห็นใน Pop ของคุณ" — เป็นข้อความบรรยายเหตุการณ์ที่เกิดขึ้นจริงในอดีต ไม่ใช่การชี้ชวน ตรงตาม Edge Case 2 ของ product spec ที่บอกว่าแจ้งเตือนเก่ายังอยู่ได้ แค่กดแล้วต้องไม่พาไปเจอ Pop จริง (แก้ไปแล้วในข้อ 4)
- `moderation_queue_screen.dart`/`moderation_report_detail_screen.dart` — เครื่องมือแอดมิน ต้องยังตรวจสอบรายงาน Pop เดิมได้ ไม่ใช่ "สายตาผู้ใช้ทั่วไป" ตามที่ Founder ระบุ
- Trigger/backend ฝั่ง DB ที่ยัง insert แถว pop-type notification ต่อไป — ตรงตาม Edge Case 3 ของ product spec ที่บอกให้ปล่อยไว้ตามเดิม

Files Changed:
- `app/lib/features/search/presentation/search_screen.dart`
- `app/lib/features/home/data/home_repository.dart`
- `app/lib/features/saved/data/saved_repository.dart`
- `app/lib/features/notification/presentation/notification_list_screen.dart`
- `app/lib/features/profile/presentation/widgets/profile_saved_tab.dart`
- `app/lib/features/follow/presentation/follow_list_screen.dart`
- `app/lib/features/settings/presentation/settings_screen.dart`
- `app/lib/features/settings/presentation/notification_settings_screen.dart`
- `app/test/search_screen_test.dart` — ลบเทส Pop tab เดิม (ไม่มีความหมายอีกแล้ว), เพิ่มเทสยืนยันแท็บเหลือ 3 อัน ไม่มีคำว่า "Pop"
- `app/test/notification_list_screen_test.dart` — เขียนใหม่ 2 เทสให้ตรงกับพฤติกรรมใหม่ของ `_openPop()`
- `app/test/follow_list_screen_test.dart` — แก้ assertion ข้อความ empty state

Reason: Founder ข้อ 11/28 — "ตัดฟีเจอร์ Pop ออกก่อนทุกอย่าง หมายถึงเอาออกเฉยๆ พักเก็บไว้"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **917/917 ผ่านหมด** (ลบ 1 เทสเดิมที่ไม่มีความหมายแล้ว + เพิ่ม 1 เทสใหม่ = สุทธิเท่าเดิม, แก้เทสเดิม 5 ตัวให้ตรงกับพฤติกรรมใหม่)
- Red→green พิสูจน์จริง: รันเทสก่อนแก้ยืนยัน 5 เทสพังตามคาด (Pop tab หาย, `_openPop` เปลี่ยนพฤติกรรม, empty-state ข้อความเปลี่ยน) แก้โค้ด+เทสแล้วรันซ้ำผ่านหมด

Build: ไม่ได้รัน `flutter build` จริง — ไม่แตะ schema/backend เลย (query-layer filter ล้วน)

Known Issues:
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator) — โดยเฉพาะ Home feed/Trending/Top100 ควรเปิดดูจริงยืนยันไม่มีการ์ด Pop ปนเลย
- `create_pop_screen.dart` เอง (หน้าสร้าง Pop) ยังไม่ได้ตรวจว่า mount จากที่ไหนได้บ้างนอกเหนือจาก Bottom Nav (ที่ถอดไปแล้วตั้งแต่ WYN-024) — grep แล้วไม่พบ nav path อื่นที่ยัง reachable แต่ควรให้ QA ยืนยันอีกชั้นว่าไม่มีทาง deep-link/shortcut อื่นเข้าถึงได้
- Trigger/RPC ฝั่ง backend (WYN-006's `increment_pop_view_count()` ฯลฯ) ยังทำงานได้ปกติถ้ามีคนเรียก API ตรง — ตรงตามที่ product spec ตั้งใจไว้ (ไม่บล็อกระดับ backend) ไม่ใช่บั๊ก

Handoff: ส่งต่อ AI QA & Security — (1) ยืนยัน Home feed/Trending/Top100/Discovery ไม่มีการ์ด Pop ปนเลยบนอุปกรณ์จริง (2) ทดสอบ tap notification เก่าที่อ้างอิง Pop (ถ้ามีในระบบจริง) ว่าไม่ crash และไม่พาไปเจอ Pop (3) ยืนยัน Search screen เหลือ 3 แท็บ ไม่มีทางกด Pop จากที่ไหนเลย (4) confirm การ revert ทำได้ง่ายจริง (ลบ `.neq()`/คืน Tab กลับ ไม่ต้อง migrate)
