# Design — WYN-038 (View Counting System — Drop)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-038-view-counting-system.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `DropDetailScreen`/`HomeDropCard` (WYN-005/WYN-007) — มิเรอร์ UI pattern เดียวกับที่ `PopClipView`/`HomePopCard` (WYN-006) ใช้แสดง View count ของ Pop อยู่แล้ว ให้มากที่สุดเพื่อความสม่ำเสมอทั้งแอป
> Design system: Cyan `#00C8FF` เป็น primary ตาม DS-001–008 — ไม่มี Rainbow (DS-009) จุดไหนใน task นี้ — ไม่มีการคิดทิศทาง visual ใหม่ (มิเรอร์ icon/สี/ขนาดที่มีอยู่แล้วทั้งหมด)

## ภาพรวม — ไม่มีหน้าจอใหม่ ต่อยอด 2 widget เดิม

Task นี้ไม่มี Screen ใหม่หรือ user flow ใหม่ — เป็นการ "เชื่อมสายไฟ" ค่า View count จริงเข้ากับช่องที่ WYN-007 จองไว้แล้วแต่ยังไม่เคยใช้ (`view_count` ใน `home_feed`/`saved_feed` view, `HomeFeedItem.viewCount` field) และเพิ่มจุดแสดงผล 2 จุด (`HomeDropCard`, `DropDetailScreen`) ให้ตรงกับที่ `HomePopCard`/`PopClipView` ทำอยู่แล้วสำหรับ Pop — ผู้ใช้ไม่เห็นความแตกต่างเชิง flow ใดๆ นอกจากตัวเลข View ปรากฏขึ้นข้าง Like/Comment เดิม

---

## Component 1 — View count บน `DropDetailScreen`

**Purpose**: แสดงยอด View จริงให้เจ้าของ/ผู้ดู Drop เห็น เหมือนที่ `PopClipView` แสดงอยู่แล้ว

**ตำแหน่ง**: ต่อท้าย interaction row เดิม (Like → Comment → ReDrop → Share → Copy Link) **ก่อน** `const Spacer()`/ปุ่ม Save — ดู `drop_detail_screen.dart` แถว 701–765 ปัจจุบัน (Like/Comment/ReDrop มี icon+count คู่กันอยู่แล้ว, Share/Link เป็น icon เดี่ยว, Save ถูกดันไปขวาสุดด้วย Spacer)

**Components**: `Icon(Icons.visibility_outlined)` (ไม่ระบุ size พิเศษ — ใช้ default ให้เท่ากับ icon พี่น้องอื่นๆ ในแถวเดียวกันที่ไม่ได้ระบุ size เช่นกัน) + `SizedBox(width: WynSpacing.space1)` + `Text('${_drop.viewCount}')` — **ไม่ใช่ `IconButton`** (View count เป็นข้อมูลอ่านอย่างเดียว ไม่ใช่ปุ่มกด ไม่ต้องมี tap target 48dp เหมือนปุ่มอื่น) มิเรอร์วิธีที่ `HomePopCard` ทำกับ Pop's view count ทุกจุด

**Interactions**: ไม่มี — เป็น static display ล้วนๆ ไม่ต้อง `onPressed`/`onTap`

**States**: ไม่มี state พิเศษ — อัปเดตตามค่าจาก `_drop` ปกติเหมือน count อื่นๆ ในแถวเดียวกัน (Like/Comment/ReDrop count ก็ไม่มี loading state แยกอยู่แล้ว)

---

## Component 2 — View count บน `HomeDropCard`

**Purpose**: เดียวกับ Component 1 แต่ในบริบทการ์ดใน Home Feed — มิเรอร์ที่ `HomePopCard` ทำอยู่แล้ว (ดู `home_pop_card.dart` แถว 164–166: `Icon(Icons.visibility_outlined, size: 18)` + `Text('${item.viewCount}')`)

**ตำแหน่ง**: ต่อท้าย interaction row เดิมของ `HomeDropCard` (Like → Comment → ReDrop → Share) **ก่อน** `const Spacer()`/ปุ่ม Save — ดู `home_drop_card.dart` แถว 269–333

**Components**: `Icon(Icons.visibility_outlined, size: 20)` (ให้ตรงกับ icon พี่น้องในแถวเดียวกันที่ระบุ `size: 20` ไว้แล้ว เช่น `mode_comment_outlined`/`share_outlined` — **ไม่ใช้ `size: 18`** ที่ `HomePopCard` ใช้ เพราะ card คนละแบบมี icon size convention คนละค่าอยู่แล้วในโค้ดเดิม ให้ยึดตามพี่น้องในไฟล์เดียวกันเป็นหลัก ไม่ใช่ copy ตัวเลขข้ามไฟล์ตรงๆ) + `SizedBox(width: WynSpacing.space1)` + `Text('${item.viewCount}')` — ไม่ใช่ `IconButton` เช่นกัน

**Interactions**: ไม่มี (เหมือน Component 1)

**States**: ไม่มี state พิเศษ

**Accessibility (ปรับปรุงจาก pattern เดิมของ Pop)**: `HomePopCard`'s view count icon+text **ไม่มี `Semantics` label เลย** (gap เดิมที่ไม่เคย block QA ของ WYN-006 มาก่อน แต่เป็น gap จริง) — Component 1/2 ของ Drop ใน task นี้ **ต้องห่อด้วย `Semantics(label: 'เข้าชมแล้ว $viewCount ครั้ง', excludeSemantics: true, ...)`** ทุกจุด ไม่ให้ gap เดิมลามมาที่โค้ดใหม่ ตาม DS-008 (Accessibility) — ไม่ต้องแก้ของ Pop เดิม (นอกขอบเขต task นี้ตามที่ Product ตัดสินใจไว้)

---

## Responsive Behavior

Interaction row ทั้งสองจุด (`DropDetailScreen`/`HomeDropCard`) เป็น `Row` ธรรมดาไม่มี `Wrap`/`Flexible` อยู่แล้วในโค้ดเดิม (ยอมรับความเสี่ยง overflow จากตัวเลข Like/Comment/ReDrop ที่มีหลักเยอะๆ อยู่แล้วโดยไม่มี safety valve — เป็น pattern ที่มีอยู่ก่อน task นี้) — การเพิ่ม View count icon+เลขสั้นๆ อีก 1 คู่เป็นความเสี่ยงระดับเดียวกับที่ระบบยอมรับอยู่แล้ว **ไม่ใช่ความเสี่ยงใหม่** จึงไม่ต้องเพิ่ม `Wrap`/scroll ป้องกันเป็นพิเศษใน task นี้ — ถ้า Founder ต้องการแก้ overflow ทั้งแถวควรทำเป็น task แยก (กระทบทุก count field ไม่ใช่แค่ View)

---

## Design Rules

1. **ห้ามใช้ `IconButton`** สำหรับ View count ทั้งสองจุด — ต้องเป็น `Icon` เปล่าๆ (ไม่มี tap target/ripple) เพราะไม่ใช่การกระทำที่ผู้ใช้ทำได้ ต่างจาก Like/Comment/ReDrop/Save ที่กดได้จริง
2. **ต้องมี `Semantics` label เสมอ** (ดู Accessibility ด้านบน) — ต่างจาก Pop เดิมที่ไม่มี
3. **Icon size ให้ยึดตาม convention ของไฟล์นั้นๆ เอง** ไม่ copy ตัวเลขข้าม `HomePopCard`/`DropDetailScreen`/`HomeDropCard` ตรงๆ (ดูรายละเอียดใน Component 1/2)
4. **ไม่มีสี/ทิศทาง visual ใหม่** — ใช้สี icon default (ไม่ tint), ไม่มี badge/animation ใดๆ เพิ่มเติมเกินสิ่งที่ Pop ทำอยู่แล้ว

---

## ทบทวน Schema/RPC/RLS ตามที่ Product ขอ (จุดที่ 3 ใน Recommendation — `drop_views` privacy)

ยืนยันแนวทางของ Product **ถูกต้องและจำเป็นจากมุม UX/trust ด้วย ไม่ใช่แค่ security**: ผู้ใช้ Gen Z ทั่วไปคาดหวังว่า "ใครดู Story/โพสต์ของฉัน" เป็นข้อมูลส่วนตัวของเจ้าของเนื้อหา (หรือไม่เปิดเผยเลย) ไม่ใช่ข้อมูลสาธารณะแบบ Like — ถ้าเปิด SELECT policy ของ `drop_views` แบบเดียวกับ `drop_likes` (select-all-authenticated) ผู้ใช้ทุกคนจะ query ตรงผ่าน REST API เห็น "ใครดู Drop ไหนบ้าง" ได้ทันทีทั้งที่ไม่มี UI ไหนในแอปตั้งใจเปิดเผยแบบนั้นเลย ขัดกับความคาดหวังของผู้ใช้อย่างชัดเจน — **เห็นด้วยกับ Recommendation ข้อ 3 ของ Product ทั้งหมด**: SELECT policy จำกัดแค่ `auth.uid() = viewer_id` + ฟังก์ชัน `drop_view_count()` แยกสำหรับนับรวมที่ทุกคนเห็นตรงกัน — ไม่มีจุดใดในหน้าจอที่ต้องเปิดเผย raw viewer list ต่อผู้ใช้อื่น (ต่างจาก Like ที่มักมีหน้า "รายชื่อคนกดถูกใจ" ในแพลตฟอร์มอื่น — WYN ยังไม่มีหน้านี้เลยด้วยซ้ำแม้กับ Like เอง จึงยิ่งไม่มีเหตุผลต้องเปิด raw list ของ View)

---

## Handoff (ไปยัง AI Coding)

**Flutter**:
1. `Drop` model เพิ่ม `viewCount` (`int`, non-null, default ตาม DB เสมอ) + `withExtraView()` มิเรอร์ `Pop.withExtraView()`
2. `HomeFeedItem.toDrop()` ต้องส่ง `viewCount: viewCount ?? 0` เข้า `Drop` ด้วย (ตอนนี้ยังไม่ส่งเลย)
3. `DropRepository` เพิ่ม `recordView(dropId)` เรียก RPC `record_drop_view` — fire-and-forget + `catchError` กลืน error เหมือน `PopRepository.recordView()`
4. `DropDetailScreen` เพิ่ม `_viewRecorded` flag เรียก `recordView()` ครั้งเดียวตอนเปิดหน้า (มิเรอร์ `PopClipView`'s `_recordView()`) + optimistic `setState(() => _drop = _drop.withExtraView())` — ยกเว้นกรณี `isOwnDrop` (เจ้าของดู Drop ตัวเอง) **ไม่ต้องเรียก RPC เลยตั้งแต่ต้น** (รู้อยู่แล้วฝั่ง client ว่าเป็นเจ้าของ ไม่ต้องรอ RPC ปฏิเสธเงียบๆ ที่ server ก็ได้ ลด request ที่รู้ผลอยู่แล้ว)
5. เพิ่ม Component 1/Component 2 ตามรายละเอียดด้านบน (ตำแหน่ง/ขนาด icon/Semantics ตามที่ระบุเป๊ะๆ)
6. `HomeDropCard`/`DropDetailScreen` ไม่ต้องมี logic เรียก `recordView()` จาก `HomeDropCard` เอง — การ์ดใน feed แค่ "เห็นผ่าน" ไม่ถือเป็น View จริงตามที่ Product ตัดสินใจ (View นับตอนเปิด `DropDetailScreen` เท่านั้น)

**SQL**: ตามข้อ 1–5 ใน Product's Recommendation ทั้งหมด (`drop_views` ตาราง, `record_drop_view()` RPC, `drop_view_count()` SECURITY DEFINER function, SELECT policy จำกัดเฉพาะ `auth.uid() = viewer_id`, แก้ `home_feed`/`saved_feed` view 2 จุดให้เรียก `public.drop_view_count(d.id)` แทน `null::bigint`) — ไม่มีข้อเพิ่มเติมจาก Design นอกเหนือจากที่ยืนยันไว้ในหัวข้อทบทวนด้านบน

**Tests ที่ต้องมี**: regression test ยืนยัน Semantics label ของ View count ทั้งสองจุดมีจริง (ป้องกันไม่ให้ gap แบบ Pop เกิดซ้ำ), test ยืนยัน `isOwnDrop` ไม่เรียก `recordView()`, SQL regression script ใหม่ (มิเรอร์ `wyn_037_edit_delete_drop_test.sh`) ครอบ unique-viewer dedup/self-view exclusion/rate-limit/velocity-cap/SELECT policy privacy ตาม Acceptance Criteria ทุกข้อของ Product
