# Design Audit — WYN-140: "ดูเหมือนแพลตฟอร์มใหญ่ๆ" Polish Gap Analysis

Status: PROPOSED — รอ Founder เลือก priority ก่อนส่งต่อ AI Coding
Owner: AI Design
Requested by: Founder, 2026-09-07 ("ทำเว็บแอปให้ดีสุดๆ เสถียรสุดๆ ฟีเจอครบ ไม่มีบัค ไม่มีปัญหา เหมือนแพลตฟอร์มใหญ่ๆ")

## ก่อนเข้าเนื้อหา — ทำไมเอกสารนี้ไม่ใช่ "ทำให้ครบทุกอย่างที่ขอ"

คำขอของ Founder ("ดีสุดๆ เสถียรสุดๆ ฟีเจอครบ ไม่มีบัค เหมือนแพลตฟอร์มใหญ่ๆ") จริงๆ แล้วครอบคลุม 4 เรื่องที่แยกกันตามโครงสร้างทีม (`.wyn/company/COMPANY.md`) และแต่ละเรื่องมีเจ้าของงานคนละ role — ไม่ใช่ AI Design ทำได้คนเดียวทั้งหมด:

| สิ่งที่ Founder ขอ | เจ้าของจริง | สถานะตอนนี้ |
|---|---|---|
| "ไม่มีบัค" | AI QA & Security + AI Debug Engineer | มี regression test suite และ bug tracker (`.wyn/tasks/bugs/`) อยู่แล้ว เป็นงานต่อเนื่อง ไม่ใช่ Design |
| "เสถียร" | AI Deploy & DevOps | เรื่อง monitoring/uptime/rollback — นอกขอบเขต Design |
| "ฟีเจอร์ครบ" | AI Product Manager | เรื่อง roadmap/priority ฟีเจอร์ใหม่ — นอกขอบเขต Design |
| "ดูเหมือนแพลตฟอร์มใหญ่ๆ" | **AI Design** | **เอกสารนี้** — ขอบเขตที่ Design ทำได้จริงคือ perceived quality ผ่าน UX/UI |

เอกสารนี้โฟกัสเฉพาะช่อง "ดูเหมือนแพลตฟอร์มใหญ่ๆ" ตามหน้าที่ที่ `.wyn/agents/design.md` กำหนดไว้ — **ไม่คิดทิศทาง visual ใหม่** (ใช้ Design System เดิมที่มีอยู่แล้วทั้งหมด: `design-principles.md`, `ds-001` ถึง `ds-010`) ตรวจโค้ดจริงในโปรเจกต์ (ไม่เดา) เพื่อหาว่าอะไรที่ทำให้ WYNOS "รู้สึก" เล็กกว่าแพลตฟอร์มใหญ่ (Instagram/Twitter/Facebook ระดับ) ทั้งที่ฟีเจอร์มีครบเยอะแล้ว

## Methodology

ตรวจโค้ดจริงใน `app/lib/` (ไม่ใช่การประเมินความรู้สึกลอยๆ):

```
grep -rc "CircularProgressIndicator" lib/     → 144 จุด ใน 88 ไฟล์
grep -rl "Skeleton" lib/                       → มีแค่ 2 ฟีเจอร์ (Home Feed, Profile)
grep -rl "AnimatedSwitcher|AnimatedContainer|Hero(" lib/ → 5 ไฟล์
grep -rl "errorMessageFor|networkErrorMessage" lib/     → 4 ไฟล์
grep -rl "โหลด.*ไม่สำเร็จ" lib/ (hardcoded, ไม่แยก offline)  → 45 ไฟล์
grep -n "shimmer" pubspec.yaml                 → ไม่มี dependency นี้เลย
grep -rl "Sentry|Crashlytics|FlutterError.onError" lib/ → ไม่มีเลย (ไม่ใช่ Design scope แต่ควรบันทึกไว้)
```

## Finding 1 — Loading state: มี Skeleton แค่ 2 หน้า ที่เหลือ 86 หน้าเป็น spinner เปล่า

**อาการ**: แพลตฟอร์มใหญ่ (Instagram/Twitter/Facebook) แทบไม่มี "spinner กลางจอเปล่าๆ" อีกแล้ว — ใช้ skeleton (การ์ดเทาๆ รูปร่างเหมือนเนื้อหาจริง) แทบทุกจุดที่โหลดข้อมูล เพราะลดความรู้สึก "ค้าง" และ layout ไม่กระโดดตอนโหลดเสร็จ

WYNOS มี `HomeFeedSkeleton`/`ProfileSkeleton` แล้ว (ทำตั้งแต่ WYN-013/Home polish) แต่หน้าอื่นที่มี traffic สูงพอกัน — **Club Page, Club Posts/Chat/Members tab, Chat Inbox, Conversation, Notification List, Search, Discovery, Settings sub-screens ทุกตัว** — ยังเป็น `Center(child: CircularProgressIndicator())` เปล่าๆ ทั้งหมด

**หมายเหตุสำคัญ**: skeleton ที่มีอยู่ 2 ตัวจงใจทำเป็น **static block ไม่มี shimmer animation** (ดู comment ใน `home_feed_skeleton.dart`) เพราะ animation แบบ indeterminate ทำให้ `flutter test`'s `pumpAndSettle()` ค้างไม่มีวันจบ — เป็น constraint ทางเทคนิคจริงที่ทีมนี้เคยโดนมาแล้ว **ต้องคงหลักการนี้ต่อ** (static skeleton, ไม่ใช่ shimmer) ในทุกจุดที่ทำเพิ่ม ไม่งั้น test suite ทั้งชุดจะพังเป็นลูกโซ่

**Priority**: สูง — เป็นจุดที่ "รู้สึก" ได้ทันทีในการใช้งานทุกวัน กระทบเกือบทุกหน้าจอ

## Finding 2 — ข้อความ error ไม่แยก "เน็ตหลุด" กับ "เซิร์ฟเวอร์พัง" ใน 45 จุดจาก 49 จุด

**อาการ**: มี utility ที่ถูกต้องอยู่แล้ว (`core/network_error.dart` — แยกข้อความ "ไม่มีการเชื่อมต่ออินเทอร์เน็ต" ออกจาก error อื่นๆ อย่างมีเหตุผลชัดเจน ตาม comment ในไฟล์เอง) แต่ **ใช้จริงแค่ 4 จุด** ส่วนอีก 45 จุดยังขึ้นข้อความ generic แบบ "โหลด X ไม่สำเร็จ" ตายตัว ไม่ว่าจะเป็นเพราะเน็ตหลุดหรือเซิร์ฟเวอร์มีปัญหาจริง

แพลตฟอร์มใหญ่แยกสองเคสนี้เสมอ เพราะมันคือ 2 ปัญหาคนละเรื่องที่ผู้ใช้ควรทำต่างกัน (รอสัญญาณ vs. รายงานบั๊ก) — ข้อความ generic ทำให้ผู้ใช้โทษแอปทั้งที่บางทีเป็นที่สัญญาณตัวเอง

**Priority**: กลาง-สูง — ทำได้เร็ว (แทนที่ hardcoded string ด้วย `errorMessageFor()` ที่มีอยู่แล้ว) ความเสี่ยงต่ำมาก เพราะไม่ใช่ฟีเจอร์ใหม่ เป็นการ "เติมของเดิมให้ครบ" ตาม pattern ที่มีอยู่แล้ว

## Finding 3 — แทบไม่มี motion/transition เลย (5 ไฟล์จากทั้งแอป)

**อาการ**: แพลตฟอร์มใหญ่ใช้ motion เล็กๆ น้อยๆ ตลอดเวลาโดยผู้ใช้ไม่รู้ตัว (fade เข้า/ออกตอนเปลี่ยนเนื้อหา, การ์ดขยับตอน insert/remove, ปุ่ม Like เด้งตอนกด) — ทำให้แอปรู้สึก "ลื่น" แทนที่จะ "กระตุก" WYNOS มี haptic feedback ที่ดีอยู่แล้ว (`WynFeedback.like()`/`.save()`/`.commentSent()` ฯลฯ) แต่ฝั่ง visual motion แทบไม่มีเลยนอกจาก default page-route transition ของ Flutter เอง

**ตัวอย่างจุดที่ขาดง่ายและกระทบบ่อย**: list ที่มี insert/remove (comment ใหม่, badge ใหม่, ข้อความใหม่) เปลี่ยนแบบ "โผล่/หาย" ทันที ไม่มี fade/slide เลยสักจุด

**Priority**: กลาง — เห็นผลชัดแต่ effort สูงกว่า Finding 1-2 เพราะต้องทำทีละจุดจริงๆ ไม่ใช่ shared utility เดียวจบ

## นอกขอบเขต Design แต่พบระหว่างตรวจ ควรส่งต่อ

- **ไม่มี crash reporting เลย** (ไม่มี Sentry/Crashlytics/`FlutterError.onError` handler ใดๆ) — แปลว่าถ้าแอปพังจริงในเครื่องผู้ใช้ ทีมจะไม่มีทางรู้เลยนอกจาก Founder รายงานเอง ตรงกับสิ่งที่ Founder ขอเรื่อง "เสถียร" โดยตรง แต่เป็นงาน **AI Deploy & DevOps** ไม่ใช่ Design — แนะนำให้ Founder สั่ง `/deploy` แยกถ้าสนใจเรื่องนี้ต่อ

## คำแนะนำ

ไม่แนะนำให้ทำทั้ง 3 Finding พร้อมกันในทีเดียว (เสี่ยง regression กว้างเกินไปในการ deploy ครั้งเดียว ขัดกับ Change Control ใน `.wyn/company/RULES.md` ข้อ "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น") — เสนอทำเรียงตาม Priority ทีละ task ผ่าน workflow เต็ม (Design → Coding → QA → Deploy) เหมือนงานอื่นทุกครั้ง:

1. **WYN-140a**: ขยาย error-message utility (`errorMessageFor`) ให้ครบทุกจุด — เร็วสุด, เสี่ยงต่ำสุด, เห็นผลจริงทันที
2. **WYN-140b**: เพิ่ม Skeleton loading ให้หน้าที่ traffic สูงสุดก่อน (Club Page, Chat Inbox, Notification List) แล้วค่อยขยายที่เหลือเป็นรอบถัดไป
3. **WYN-140c**: เพิ่ม motion/transition ในจุดที่กระทบบ่อยที่สุดก่อน (list insert/remove) — ทำทีหลังเพราะ effort สูงกว่า

## Handoff

รอ Founder เลือกว่าจะเริ่มจากอันไหนก่อน (เลือกได้มากกว่า 1) — เมื่อเลือกแล้ว AI Design จะเขียน spec แบบละเอียดเต็มรูปแบบ (Screen/Purpose/User Flow/Components/Interactions/States/Responsive Behavior/Accessibility/Design Rules) ให้ทีละ task ตาม template ปกติ ก่อนส่งต่อ AI Coding
