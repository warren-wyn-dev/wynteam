# Bug Report — WYN-110 (QA-WYN-110-001)

Status: bugs
Owner: AI Debug Engineer
Severity: **Medium**
พบโดย: AI QA & Security, 2026-09-05 (branch `claude/home-button-ux-ui-design-cbjkzm`, commit `de4b4b0`,
ยังไม่ merge/deploy)

## Bug

หนึ่งครั้งของการเลื่อนผ่าน "300px จากล่างสุด" (จุดที่ควรโหลดหน้าถัดไป 1 ครั้ง) กลับยิง
`_loadMore()` **หลายครั้งซ้ำกัน** (วัดได้ 5 ครั้งจากการลาก 1 ครั้งในเทสต์ ควรเป็น 1 ครั้ง) ใน
**ทั้ง 3 แท็บ** (`ProfileDropGridTab`, `ProfileRedropsTab`, `ProfileLikesTab`) เพราะโค้ดทั้ง 3 ไฟล์
ก็อปแพทเทิร์นเดียวกันมาเป๊ะ

ผลกระทบจริง: ไม่มี duplicate row บนหน้าจอ (มี `_seenKeys` กันไว้อยู่แล้ว) และไม่ throw/ไม่เกิด
"Build scheduled during frame" — แต่ **ยิง network request ไปหลังบ้านซ้ำโดยไม่จำเป็นหลายเท่าตัว**
ทุกครั้งที่ผู้ใช้เลื่อนผ่านจุด near-bottom หนึ่งครั้ง ซึ่งกระทบทั้งค่าใช้จ่าย Supabase query และความเสี่ยง
โดน rate-limit เมื่อใช้งานจริง

## Root Cause

`_onScrollNotification` เช็ค guard (`_isLoadingMore`) **ณ เวลาที่ notification เข้ามา** แล้วค่อย
`WidgetsBinding.instance.addPostFrameCallback` ไปเรียก `_loadMore()` ในเฟรมถัดไป แต่ `_isLoadingMore`
จะไม่ถูกตั้งเป็น `true` จนกว่า `_loadMore()` เองจะเริ่มทำงานจริง (ซึ่งถูกเลื่อนไปอีก 1 เฟรม) — ถ้ามี
`ScrollNotification` มากกว่า 1 ครั้งเกิดขึ้น**ก่อนที่เฟรมนั้นจะจบ** (เช่น ลากนิ้ว 1 ครั้งที่ภายในสร้าง
`ScrollUpdateNotification` หลายรอบต่อเนื่องกันแบบซิงโครนัส ก่อนจะถึง frame boundary แรก) ทุก notification
เหล่านั้นจะเห็น `_isLoadingMore == false` เหมือนกันหมด แล้วต่างก็ลงทะเบียน `addPostFrameCallback` ของ
ตัวเอง — เมื่อเฟรมจบ ทุก callback ที่ลงทะเบียนไว้จะถูกเรียกเรียงกัน **โดยไม่มีการเช็ค guard ซ้ำ ณ เวลา
execution จริง** ทำให้ `_loadMore()` ถูกเรียกซ้อนกันหลายครั้งโดยทุกครั้งอ่าน `_page` ค่าเดิม (ยังไม่ทัน
อัปเดต) จึงยิง fetch หน้าเดียวกันซ้ำ ๆ

เทียบกับโค้ดเดิมก่อนแก้ (`_scrollController.addListener(_onScroll)` ที่เรียก `_loadMore()` ตรง ๆ แบบ
synchronous) — `setState(() => _isLoadingMore = true)` (บรรทัดแรกของ `_loadMore()`) รันทันทีก่อนที่
listener ตัวถัดไปจะมีโอกาสถูกเรียก จึง guard ทันเวลาเสมอ ปัญหานี้จึงเป็น**ผลข้างเคียงใหม่**จากการย้ายไปใช้
`addPostFrameCallback` เพื่อแก้ "Build scheduled during frame" (แก้ปัญหาหนึ่งได้ แต่เปิดช่องโหว่ใหม่อีกจุด)

## Files

- `app/lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart:92-108` (`_onScrollNotification`)
- `app/lib/features/profile/presentation/widgets/profile_redrops_tab.dart:92-108` (โค้ดเหมือนกันทุกจุด)
- `app/lib/features/profile/presentation/widgets/profile_likes_tab.dart:92-107` (โค้ดเหมือนกันทุกจุด)

```dart
bool _onScrollNotification(ScrollNotification notification) {
  if (_isLoadingMore || !_hasMore) return false;   // <- guard เช็คตอนนี้
  if (notification.metrics.pixels >
      notification.metrics.maxScrollExtent - 300) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();   // <- ไม่เช็ค guard ซ้ำตอนนี้ ก่อนเรียกจริง
    });
  }
  return false;
}
```

## Reproduction

Widget test อิสระ (QA เขียนเอง ไม่ใช่เทสต์ของ coding agent):
`app/test/qa_wyn110_profile_scroll_header_test.dart`, กลุ่ม "4. infinite-scroll pagination past a
real page boundary" — ทั้ง 3 testWidgets (Posts/ReDrops/Likes) ยืนยันตรงกัน:

```
Expected: <2>   // page 0 (initial load) + page 1 (1 ครั้งจากการเลื่อนผ่าน threshold)
  Actual: <5>   // page 0 + page 1 ซ้ำ 4 ครั้ง
```

Repro ขั้นต่ำสุด (เห็นชัดที่สุด): pump `ProfileDropGridTab` ด้วย fake repo ที่มี 21 รายการ (page 0 เต็ม
`DropRepository.pageSize`) แล้วเรียก `tester.drag()` (การลากจำลอง 1 ครั้ง ซึ่งภายในแตกเป็นหลาย
`gesture.moveBy()` เพื่อจำลอง touch-slop) ตามด้วย `tester.pump()` **หนึ่งครั้ง** — นับ
`fetchByAuthorCalls` ได้ 5 ครั้งจากการลาก 1 ครั้ง (ยืนยันแล้วด้วยสคริปต์แยกนอกไฟล์เทสต์หลักระหว่างการ
สืบสวน ก่อนย้ายมาเป็นเทสต์ถาวรในไฟล์ข้างต้น)

## Expected

เลื่อนผ่านจุด near-bottom หนึ่งครั้ง (ไม่ว่าจะประกอบด้วย pointer event ย่อยกี่ครั้งก็ตามก่อนถึง frame
boundary) ต้องเรียก `_loadMore()`/fetch หน้าถัดไปเพียง **1 ครั้ง** ต่อการข้าม threshold หนึ่งรอบ

## Actual

เรียกซ้ำ 4-5 เท่าของที่ควรจะเป็น ในทั้ง 3 แท็บเหมือนกัน (เพราะโค้ดก็อปกันมา)

## Fix ที่เสนอ

ตั้ง guard ให้เป็น `true` แบบ synchronous **ทันทีที่ตัดสินใจจะเลื่อนเรียก** ไม่ใช่รอให้ `_loadMore()`
เองเป็นคนตั้ง เช่น:

```dart
bool _onScrollNotification(ScrollNotification notification) {
  if (_isLoadingMore || !_hasMore) return false;
  if (notification.metrics.pixels >
      notification.metrics.maxScrollExtent - 300) {
    _isLoadingMore = true; // กัน notification อื่นที่มาถึงก่อนเฟรมถัดไป โดยไม่ setState ตรงนี้
                            // (setState จริงเกิดใน _loadMore() เอง ตอน addPostFrameCallback ทำงาน)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();
    });
  }
  return false;
}
```

ต้องระวัง: ถ้าตั้ง `_isLoadingMore = true` ตรงนี้โดยไม่ `setState`, UI ที่ผูกกับ `_isLoadingMore` (ถ้ามี
เช่น loading indicator) จะไม่ rebuild ทันที — ต้องเช็คว่ามีจุดไหนอ่านค่านี้ไปแสดงผลโดยตรงหรือไม่ ถ้ามี
อาจต้องแยก flag ภายใน (เช่น `_loadMoreScheduled`) ออกจาก `_isLoadingMore` ที่ผูก UI แทน เพื่อไม่ให้
กระทบพฤติกรรมการแสดงผลเดิม แล้วให้ QA รอบถัดไปตรวจ CircularProgressIndicator ที่ท้าย list ยังโผล่ปกติ

ต้องแก้ทั้ง 3 ไฟล์เหมือนกัน (โค้ดถูกก็อปกันมา 3 จุด)

## Regression Risk

ต่ำ-กลาง — แก้เฉพาะจุด guard ของ pagination ไม่กระทบ UI/layout ที่เพิ่งแก้ใน WYN-110 แต่ต้องรัน
เทสต์ pagination เดิม (`profile_likes_tab_test.dart` กลุ่ม "Beta3: a second page that overlaps") ซ้ำ
ให้แน่ใจว่ายังผ่าน เพราะทดสอบ dedup logic เดียวกัน

## Tests ที่ต้องเพิ่ม/ปรับ

`app/test/qa_wyn110_profile_scroll_header_test.dart` มีเทสต์ยืนยันบั๊กนี้ไว้แล้วทั้ง 3 แท็บ (กลุ่ม 4)
— ให้ debug engineer แก้จนเทสต์เหล่านี้ผ่าน (`fetchByAuthorCalls`/`fetchRedropsByUserCallsSeen`/
`fetchLikedByAuthorCalls` ต้องเท่ากับ 2 พอดี ไม่ใช่มากกว่า) ก่อนส่งกลับ QA รอบถัดไป

## Handoff to QA

หลังแก้ ให้ยืนยัน: (1) ทั้ง 3 แท็บเรียก fetch หน้าถัดไปครั้งเดียวต่อการข้าม threshold, (2) ไม่มี
duplicate key/exception เหมือนเดิม, (3) CircularProgressIndicator ท้าย list ยังแสดงถูกต้องระหว่างโหลด

## Fix Applied — 2026-09-05

แก้ตาม "Fix ที่เสนอ" ข้างต้นเป๊ะ ทั้ง 3 ไฟล์ (`profile_drop_grid_tab.dart`, `profile_redrops_tab.dart`,
`profile_likes_tab.dart`) — ตั้ง `_isLoadingMore = true;` แบบ synchronous ทันทีที่ตัดสินใจเลื่อนเรียก
`_loadMore()`, ไม่ `setState` ตรงนั้น (ตรวจแล้วว่า `_isLoadingMore` ไม่ได้ถูกอ่านไปแสดงผล UI ที่ไหนเลย
ในทั้ง 3 ไฟล์ — ไม่มี loading indicator ผูกกับ flag นี้โดยตรง มีแต่ `_hasMore` ที่คุม
`CircularProgressIndicator` ท้าย list ซึ่งไม่เกี่ยวกับจุดนี้ จึงไม่กระทบการแสดงผลเดิมตามที่กังวลไว้)

ยืนยันด้วยเทสต์ 2 ชุด:
1. `app/test/qa_wyn110_profile_scroll_header_test.dart` กลุ่ม "4." — ทั้ง 3 testWidgets:
   `expect(...Calls, 2)` **ผ่านแล้วทั้งหมด** (ยืนยันด้วยการรันแยกเฉพาะ assertion นี้ก่อนบรรทัดถัดไป)
2. เทสต์ regression ใหม่ของฝั่ง coding เอง (ไม่แก้ไฟล์ QA) ที่
   `app/test/profile_likes_tab_test.dart` — `'QA-WYN-110-001: one drag past the near-bottom threshold
   fetches the next page exactly once, not several times'` — ใช้ `tester.drag()` ตรง ๆ ครั้งเดียว
   (ไม่ใช่ `scrollUntilVisible`) ให้ตรงกับกลไกที่ QA ใช้ตอนสืบสวนบั๊กนี้ตั้งแต่แรก — ผ่าน

### พบเพิ่มเติมระหว่างยืนยัน — ไม่ใช่บั๊กที่เกิดจากการแก้นี้

หลังแก้ guard แล้ว เทสต์กลุ่ม "4." ของ QA เอง (ทั้ง 3 testWidgets) ยัง **fail** อยู่ แต่คนละจุดกับเดิม:
`expect(pagedXxxRepo.fetchXxxCalls, 2)` (บรรทัดที่พิสูจน์บั๊กนี้โดยตรง) **ผ่านแล้ว** — ความล้มเหลวย้ายไป
เกิดที่บรรทัดถัดมา (`qa_wyn110_profile_scroll_header_test.dart:394,437,477`) ซึ่งเรียก
`tester.scrollUntilVisible(find.text('...'), -300, ...)` แล้วโยน `StateError: Bad state: No element`

Root cause (วิเคราะห์จาก Flutter framework source, `WidgetController.scrollUntilVisible` /
`dragUntilVisible`): สำหรับ scrollable แนวตั้ง (`AxisDirection.down`) สูตรภายในคือ
`moveStep = Offset(0, -delta)` — ค่า `delta` เป็น**บวก**เพื่อเลื่อนต่อไปข้างหน้า/ลง ค่า**ลบ**คือเลื่อน
ถอยหลัง/ขึ้น เทสต์ของ QA เรียกด้วย `delta = -300` ที่จุดนี้ ซึ่งเลื่อน**ถอยหลัง**ไปหา content ที่โหลดมา
แล้วก่อนหน้า ไม่ใช่เลื่อนต่อไปหา row ใหม่ที่เพิ่งถูก append ท้ายลิสต์ — เดิมทีน่าจะ "บังเอิญผ่าน" เพราะ
พฤติกรรม over-fetch เดิม (บั๊กนี้) อาจทำให้ scroll position เลื่อนเกินจุดที่ต้องการไปแล้ว ทำให้การถอยหลัง
กลับมาเจอ element พอดี — พอ fix แล้วไม่มี over-fetch/over-scroll ส่วนเกินนั้นอีก การถอยหลังจึงหา element
ไม่เจอ

**ไม่ได้แก้ไฟล์เทสต์นี้เอง** (`qa_wyn110_profile_scroll_header_test.dart` เป็นไฟล์ของ QA ไม่ใช่ของ
coding/debug agent) — ส่งกลับให้ QA พิจารณาแก้ `delta` เป็นค่าบวก (หรือใช้ `scrollable` เดียวกับที่ scroll
ไปหา `CircularProgressIndicator` ก่อนหน้าแล้วต่อด้วยทิศทางเดิม) ในรอบตรวจถัดไป — core assertion ของบั๊ก
นี้ (`Calls == 2`) ยืนยันผ่านแล้วอย่างอิสระนอกเหนือจากเทสต์นี้ด้วย (ดูข้อ 2 ด้านบน)

`flutter analyze`: 0 issues. `flutter test` เต็มชุด: 1158/1162 ผ่าน (4 ที่เหลือคือ 3 เคสข้างต้น +
QA-WYN-110-002 ที่ทราบอยู่แล้วว่านอกขอบเขต)
