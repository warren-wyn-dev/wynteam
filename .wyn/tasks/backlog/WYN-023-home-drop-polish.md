# Product Task — WYN-023

Status: design เสร็จแล้ว รอ AI Coding
Owner: AI Product Manager → AI Design

Feature: Home/Drop Polish — แก้ 3 Minor finding ที่ค้างจาก QA รอบก่อนหน้า (ไม่เคยถูกหยิบมาทำต่อ)

Goal: ปิด gap เล็กๆ 3 จุดที่ QA เจอและบันทึกไว้ว่า "ไม่ block แต่ควรทำในรอบถัดไป" ตั้งแต่ WYN-005/WYN-007/WYN-015 — ตอนนี้ผ่านมาหลายรอบ feature ใหญ่แล้ว (WYN-017 ถึง WYN-022) แต่ยังไม่มีใครหยิบ 3 จุดนี้กลับมาทำ ทั้งที่เป็นของเล็ก ความเสี่ยงต่ำ ใช้ของที่มีอยู่แล้วในระบบทั้งหมด ไม่ต้องสร้างอะไรใหม่

Target User: ผู้ใช้ WYN Social ทุกคนที่ใช้ Home/Drop tab

Problem:
1. การ์ด Drop ใน Home และ Drop feed (`HomeDropCard`) ไม่แสดงเวลาที่โพสต์เลย (ไม่มีทั้ง relative time และ absolute time) — QA รอบ 3 ของ WYN-005 (2026-08-14) เจอแล้วบันทึกเป็น Minor ไม่ block แต่ยังไม่เคยถูกแก้ ทั้งที่ตอนนี้โปรเจกต์มี `relativeTimeLabel()` ใช้งานจริงอยู่แล้วใน 4 จุด (Notification, Club post, ZOKY order/review) — Drop/Home เป็นจุดเดียวที่ยังขาด
2. แตะไอคอน Comment บนการ์ด Pop ใน Home เปิดหน้าคลิปเดี่ยวก่อนเสมอ แทนที่จะเปิด comment sheet ตรงๆ ทันที — QA รอบ 2 ของ WYN-007 (2026-08-14) เจอแล้วเสนอ fast-follow ด้วย `openCommentsOnStart` flag ไว้ ยังไม่เคยทำ
3. Empty state ของโหมด "จาก Club ของคุณ" ใน Home (เมื่อยังไม่ได้ join Club ไหนเลย) ไม่มีปุ่ม "สำรวจ Club" ตามที่ Design spec เดิมของ WYN-015 ระบุไว้ตรงๆ — QA รอบ 1 ของ WYN-015 (2026-08-14) เจอแล้วไม่ block เพราะปุ่มเดิมของ `ClubSection` เหนือ toggle ยังกดได้อยู่ แต่ก็ยังไม่เคยแก้ให้ตรงตาม spec

Requirements:

R1. เพิ่ม relative timestamp บน `HomeDropCard` (แสดงในทั้ง Home feed และ Drop feed ที่ reuse การ์ดเดียวกันตาม WYN-019) โดยเรียก `relativeTimeLabel()` เดิมจาก `app/lib/core/text_utils.dart` ตรงๆ ไม่เขียนฟังก์ชันใหม่ — ตำแหน่งวางให้ AI Design ตัดสินใจ (ข้าง username เหมือนที่ Notification/Club post ทำอยู่แล้วน่าจะ consistent ที่สุด)
R2. เพิ่ม `openCommentsOnStart` flag (หรือเทียบเท่า) ให้ `PopSingleClipScreen`/`PopClipView` เพื่อให้แตะ Comment บนการ์ด Pop ของ Home เปิด comment sheet ทันทีแทนที่จะรอผู้ใช้เปิดเองหลังจอคลิปโหลด — ตาม fast-follow ที่ WYN-007 QA รอบ 2 เสนอไว้แล้ว
R3. เพิ่มปุ่ม "สำรวจ Club" ใน empty state ของโหมด "จาก Club ของคุณ" (`FromYourClubsFeed`'s empty state) ให้ตรงตาม Design spec เดิมของ WYN-015 — ไม่ต้องสร้าง flow ใหม่ พาไปหน้า `ExploreClubsScreen` ที่มีอยู่แล้ว

Acceptance Criteria:
- [ ] การ์ด Drop ใน Home และ Drop feed ทั้ง 3 tab (For You/Following/Latest) แสดงเวลาที่โพสต์แบบ relative (เช่น "5 นาทีที่แล้ว") ตรงกับ format เดียวกับที่ Notification/Club post ใช้อยู่แล้ว
- [ ] แตะ Comment บนการ์ด Pop ใน Home เปิด comment sheet ทันทีโดยไม่ต้องกดซ้ำหลังคลิปโหลด
- [ ] Empty state ของ "จาก Club ของคุณ" มีปุ่ม "สำรวจ Club" ที่กดแล้วพาไป `ExploreClubsScreen` จริง
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-005/WYN-007/WYN-014/WYN-015/WYN-019

Dependencies: ไม่มี hard dependency ใหม่ — ต่อยอด WYN-005/WYN-007/WYN-012/WYN-014/WYN-015/WYN-019 ที่ผ่าน QA แล้วทั้งหมด (R1 พึ่ง `relativeTimeLabel()` จาก WYN-012, R2 พึ่ง `PopSingleClipScreen` จาก WYN-007, R3 พึ่ง `ExploreClubsScreen` จาก WYN-015)

Priority: กลาง — คุณค่าชัดเจนและความเสี่ยงต่ำมาก (ของเดิมที่มีอยู่แล้วทั้งหมด ไม่มี schema change) แต่ไม่ใช่ blocker ของอะไร เหมาะเป็นงาน "เก็บกวาด" ก่อนเริ่ม feature ใหญ่ชิ้นถัดไป

Risks: แทบไม่มี — เป็นการเรียกใช้ของเดิมที่ผ่าน QA แล้วทั้ง 3 จุด (`relativeTimeLabel`, comment-sheet flag pattern ที่มีอยู่แล้วในโค้ด, `ExploreClubsScreen` ที่มีอยู่แล้ว) ไม่แตะ schema/RLS/ranking logic เลย

Recommendation: ทำได้ทันทีคู่ขนานกับการส่ง WYN-017–022 เข้า QA จริง (ดู DECISIONS.md 2026-08-17 — 6 task ก่อนหน้านี้ยัง "self-verified" เท่านั้น ยังไม่ผ่าน AI QA & Security อิสระจริง) — แนะนำให้ QA อิสระของ WYN-017–022 เป็นลำดับความสำคัญอันดับ 1 ก่อนเริ่ม WYN-023 เพราะเป็นของที่ deploy ค้างอยู่แล้วและมี risk สูงกว่า (แตะ Home feed ranking) — WYN-023 เป็นงานเสริมที่ทำเมื่อไหร่ก็ได้ไม่บล็อกอะไร

Handoff: **AI Design เสร็จแล้ว (2026-08-16)** — Design spec เต็มที่ `.wyn/docs/design/wyn-023-home-drop-polish.md`:
- R1: ตำแหน่ง timestamp บน `HomeDropCard` = บรรทัดที่สองใต้ชื่อผู้เขียนในบล็อก header เดิม (`bodySmall` + `colorScheme.outline`) มิเรอร์โครงสร้าง header ของ `ClubPostCard`/Notification/ZOKY order-review เป๊ะทั้ง 4 จุด — แก้ไฟล์เดียว มีผลอัตโนมัติทั้ง Home feed และ Drop feed 3 tab ตาม WYN-019 ระบุ Non-goal ชัดเจนว่า `HomePopCard` ไม่อยู่ในขอบเขตรอบนี้ (เสนอเป็น fast-follow แยกให้ Product พิจารณา)
- R2: ยืนยันไม่ต้องมี Design เพิ่ม (behavior fix ล้วนๆ) — ส่งตรง AI Coding พร้อม reference พิกัดโค้ดที่เกี่ยวข้องไว้ในเอกสาร
- R3: ปุ่ม "สำรวจ Club" ใน empty state ของ `FromYourClubsFeed` = ใช้ config เดียวกับปุ่มต้นแบบใน `ClubSection` เป๊ะ (`OutlinedButton.icon(icon: Icons.explore_outlined, size: 18, label: 'สำรวจ Club')`) กดแล้วเปิด `ExploreClubsScreen` แล้ว reload feed เมื่อกลับมา มิเรอร์ pattern `ClubSection._openExploreClubs()` ทุกประการ

ส่งต่อ AI Coding (`/code`) เพื่อ implement ทั้ง 3 requirement ตาม Design spec ข้างต้น — ดู Handoff section ในเอกสาร design สำหรับรายละเอียด implementation/regression-test ที่ต้องทำครบ
