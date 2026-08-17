# Product Task — WYN-027

Status: backlog
Owner: AI Product Manager

Feature: Home Feed Diversity + New Content Indicator

Goal: ปิด 2 gap เล็กแต่มีผลต่อ UX ชัดเจนที่ master prompt ระบุไว้ — (1) Ranking ปัจจุบัน (WYN-018) ไม่มีกลไกกันไม่ให้ author เดิมโผล่ติดกันหลายโพสต์รวด (2) ไม่มีทางรู้ว่ามี content ใหม่ระหว่างที่กำลังอ่าน feed อยู่ (ต้อง pull-to-refresh มั่วๆ เอง)

Target User: ผู้ใช้ WYN ทุกคนที่ใช้ Home เป็นประจำ โดยเฉพาะคนที่ follow user ที่โพสต์บ่อย

Problem: ผู้ใช้ที่ follow คนโพสต์ถี่จะเห็น feed ถูกครองโดย author เดียวหลายโพสต์ติดกันเพราะ ranking (WYN-018) ไม่มี anti-repetition term เลย และผู้ใช้ที่ค้าง feed ไว้นานไม่รู้ว่ามี Drop/Pop ใหม่มาแล้วกี่โพสต์

Requirements:

R1. **Feed Diversity**: เพิ่ม repetition-penalty term ให้ `rankingScore()` (`home_ranking.dart`) — ถ้า author เดียวกันปรากฏซ้ำภายในระยะใกล้กันในผลลัพธ์ที่จัดเรียงแล้ว (เช่น ภายใน 3 ตำแหน่งล่าสุด) ให้ลด priority ลง (interleave ใหม่แทนการตัดออก — ไม่ใช่ hide เนื้อหา แค่จัดลำดับใหม่ให้กระจาย) ทำแบบ post-processing pass หลัง sort ตาม score เดิม (ไม่ต้องแก้สูตร score หลักที่ผ่าน QA แล้ว เพิ่มเป็น step ถัดไปแทน เพื่อลดความเสี่ยง regression กับ WYN-018 ที่ lock สูตรไว้แล้ว)
R2. **New Content Indicator**: เมื่อมี Drop/Pop ใหม่ถูกโพสต์ระหว่างที่ผู้ใช้ค้างอยู่ในหน้า Home (ตรวจสอบด้วย polling เป็นระยะ เช่น ทุก 30-60 วินาที เรียก count query เบาๆ เทียบ timestamp ล่าสุดที่ผู้ใช้เห็น — **ไม่ใช่ Realtime จริงเพราะ Supabase Realtime ยังไม่เคยถูกใช้ในโปรเจกต์นี้ ห้ามอ้างว่าเป็น Realtime**) แสดง banner ลอยด้านบน feed เช่น "↑ 12 Drop ใหม่" — แตะแล้วค่อยโหลด/เลื่อนขึ้นไปดู ห้ามบังคับ feed กระโดดเองระหว่างผู้ใช้กำลังอ่าน

Acceptance Criteria:
- [ ] Follow user ที่มีหลายโพสต์ล่าสุด → feed "สำหรับคุณ" ไม่แสดง author เดียวกันติดกันเกิน 2 ตำแหน่งรวด (เมื่อมี content จาก author อื่นเพียงพอให้กระจาย)
- [ ] Diversity pass ไม่ทำให้เนื้อหาหายไป (แค่จัดลำดับใหม่ จำนวนรวมเท่าเดิม)
- [ ] มี Drop/Pop ใหม่ถูกโพสต์ระหว่างอยู่ในหน้า Home → banner "N ใหม่" ปรากฏ ไม่บังคับ scroll
- [ ] แตะ banner → โหลด content ใหม่ ไม่ duplicate กับที่มีอยู่แล้ว
- [ ] Polling ไม่กิน battery/network เกินจำเป็น (interval สมเหตุสมผล, หยุด polling เมื่อออกจากหน้า Home)
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-018 (สูตร ranking หลักต้องไม่เปลี่ยน มีแต่ post-processing step เพิ่ม)

Dependencies: WYN-018 (ranking formula ที่ lock ไว้แล้ว — R1 ต้องไม่แก้สูตรเดิม)

Priority: กลาง — คุณค่าชัดเจน ความเสี่ยงต่ำ (additive ล้วนๆ)

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Diversity pass ทำให้ ranking ที่ QA proof ไว้แล้ว (8 unit test ของ WYN-018) เพี้ยน | ต่ำ | แยกเป็น pass ใหม่หลัง sort ไม่แก้ `rankingScore()` เดิม เขียน test แยกสำหรับ diversity logic โดยเฉพาะ |
| R2 | Polling ถี่เกินไปทำให้ database load เพิ่ม | ต่ำ | ใช้ lightweight count query (ไม่ fetch เนื้อหาเต็ม) interval 30-60 วิ |

Recommendation: ทำได้อิสระ ไม่ต้องรอ WYN-024/025/026

Handoff: ส่งต่อ AI Design เพื่อออกแบบ diversity algorithm (sliding-window ขนาดเท่าไหร่) + banner UI แล้วส่งต่อ AI Coding

## Design Output (AI Design, 2026-08-17)

Design spec เต็มที่ `.wyn/docs/design/wyn-027-home-feed-diversity-new-content.md` สรุปการตัดสินใจหลัก:

**R1 — Feed Diversity**:
- กติกา: ไม่ให้ author เดียวกันอยู่เกิน 2 ตำแหน่งติดกัน (`maxConsecutiveSameAuthor = 2`, เท่ากับ "มอง 3 ตำแหน่งติดกัน ต้องไม่ใช่ author เดียวกันทั้งหมด" ตามตัวอย่างใน product spec)
- Algorithm: greedy single-pass พร้อม lookahead-swap — เดินตามลำดับ score เดิม ถ้าตัวถัดไปจะทำให้ author เดิมครองตำแหน่งที่ 3 ติดกัน ให้ดึงรายการถัดไปที่ author ต่างออกมาสลับขึ้นก่อน (ไม่ตัดออก ไม่เพิ่ม แค่ปรับลำดับ) — พิสูจน์ terminate แน่นอน (O(n²) worst case ที่ scale 200 item ไม่มีปัญหา) พร้อม pseudocode/worked trace/5 unit test case ที่ต้องมีในเอกสารแล้ว
- เรียกใช้เป็น pass ใหม่ (`diversifyFeed()`, ไฟล์ใหม่ `home_diversity.dart`) **หลัง** `items.sort()` เดิมใน `fetchRankedFeed` และ **ก่อน** slice แบ่งหน้า (รันบน candidate window 200 รายการเต็ม ไม่ใช่ทีละหน้า 10 รายการ กัน run ขาดตอนที่รอยต่อหน้า) — ไม่แตะ `rankingScore()`/`home_ranking_test.dart` เดิมเลย
- ใช้เฉพาะโหมด **"สำหรับคุณ"** เท่านั้น — **"ล่าสุด" ไม่ใช้** (ต้องคงเป็น timeline ดิบ 100% ตามที่ WYN-018 ตั้งใจไว้เป็น escape hatch จากทุก algorithm) และ **"กำลังนิยม"/Trending ไม่ใช้** (list สั้น 10 รายการ ผูกกับความหมาย "จัดอันดับตาม engagement ล้วนๆ" ถ้าสลับจะขัดกับชื่อ section)

**R2 — New Content Indicator**:
- Polling: `Timer.periodic` ทุก **45 วินาที** (เป็น periodic timer ตัวแรกของโปรเจกต์ — ย้ำเรื่อง lifecycle cleanup เป็นพิเศษ) เรียก `HomeRepository.countNewSince(DateTime since)` ใหม่ — ใช้ `count(CountOption.exact)` (HEAD request ไม่ fetch แถวจริง) มิเรอร์ pattern เดียวกับ `NotificationRepository.countUnread()` ที่มีอยู่แล้ว เทียบกับ `created_at` ของ `home_feed` view ตรงๆ ไม่ต้องแก้ schema/RLS
- `since` = timestamp ตอน `_loadInitial()` โหลดสำเร็จล่าสุด (ไม่ใช่ createdAt ของ item แรก เพราะโหมด "สำหรับคุณ" ไม่ได้เรียงตามเวลาเป๊ะ)
- **จุดสำคัญที่พบระหว่างออกแบบ**: `RootShell` ใช้ `IndexedStack` เก็บทุกแท็บไว้ (ไม่ dispose ตอนสลับแท็บ) ดังนั้น "หยุด polling เมื่อออกจากหน้า Home" ทำด้วย `dispose()` อย่างเดียวไม่พอ — ออกแบบให้เพิ่ม param ใหม่ `HomeFeedScreen.isVisible` (RootShell ส่ง `_index == 0` เข้ามา มิเรอร์ pattern เดียวกับ `_profileVisitKey` ที่มีอยู่แล้ว) แล้วใช้ `didUpdateWidget` เริ่ม/หยุด timer ตามการมองเห็นจริงของแท็บ ไม่ใช่แค่ mount/dispose
- Banner: pill ลอยกลางจอเหนือ feed (ไม่ full-width) ข้อความ "↑ N โพสต์ใหม่" (ไม่ใช้คำว่า "Drop" เพราะ feed ผสม Drop/Pop) สี `colorScheme.primary` (WYN Blue เดิม ไม่เพิ่มสีใหม่) พร้อม slide+fade animation เข้า/ออก ~200ms
- แตะ banner → เรียก `_loadInitial()` ตัวเดิมที่ `RefreshIndicator` (pull-to-refresh) ใช้อยู่แล้วตรงๆ (full clear-and-repopulate จาก page 0) แทนการเขียน merge/dedup logic ใหม่ — ป้องกัน duplicate โดยธรรมชาติเพราะ list ถูกแทนที่ทั้งหมด แล้ว scroll กลับขึ้นบนสุดให้เห็นของใหม่
- ไม่มี auto-jump ระหว่าง polling ทำงานเบื้องหลัง — feed กระโดดเฉพาะตอนผู้ใช้กดเองเท่านั้น

Handoff ต่อ: ส่งต่อ AI Coding พร้อมรายการไฟล์ที่ต้องแก้/สร้างครบใน design doc's "Handoff" section (ไฟล์ใหม่ `home_diversity.dart`, `home_diversity_test.dart`, `new_content_banner.dart`, แก้ `home_repository.dart`/`home_feed_screen.dart`/`root_shell.dart`)
