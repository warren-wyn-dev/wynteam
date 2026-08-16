# Product Task — DS-002

Status: backlog
Owner: AI Product Manager

Feature: WYN Design System Refinement — Phase 2: Global UI Style Pass (spacing/radius/card weight)

Goal: นำ token ที่ DS-001 สร้างไว้แล้ว (`WynSpacing` — 4px grid + radius scale) มาใช้จริงทั่วทั้ง 2 แอป แทนที่ literal padding/radius ที่กระจัดกระจายอยู่ในโค้ด และลดน้ำหนักภาพของ Card/border/shadow ให้ตรงกับคอนเซปต์ "Minimal Social Platform" ที่ DS-001 วางฐานไว้ — งานนี้เป็น visual-weight/spacing layer เท่านั้น ไม่แตะ layout โครงสร้างหรือฟีเจอร์ใด ๆ (นั่นเป็นงานของ DS-003 เป็นต้นไป ที่แยกทีละหน้าจอ)

Target User: ผู้ใช้ WYN ทุกกลุ่ม (Gen Z) — งานนี้ไม่เพิ่มฟีเจอร์ใหม่ ยกระดับ perceived quality ต่อจาก DS-001 (สี/ตัวอักษร) ด้วยระยะห่าง/น้ำหนักภาพที่สม่ำเสมอ

Problem: ตรวจแล้วพบว่า `app/lib/core/design/wyn_spacing.dart` (สร้างไว้แล้วใน DS-001a พร้อม 4px grid: `space1`–`space12`, radius scale: `radiusNone`/`radiusSm`/`radiusMd`/`radiusLg`/`radiusFull`, touch target `44`/`48`) **ยังไม่ถูกใช้งานที่ไหนเลยแม้แต่จุดเดียว** (`grep -rl "WynSpacing\." app/lib seller_app/lib | grep -v core/design/` = 0 ผลลัพธ์) — ทุกหน้าจอยังใช้ literal padding (`EdgeInsets.all(16)`, `SizedBox(height: 12)` ฯลฯ) และ radius (`BorderRadius.circular(8)` ฯลฯ) แยกกันไม่มีมาตรฐานเดียว ตรงตามที่ DS-001's audit ระบุไว้ตั้งแต่ต้น ("Spacing ไม่มีระบบ ค่า padding กระจายเป็น literal ทั่วโค้ด") — audit ยังพบ `Card`/`BoxShadow` 29 จุดในโค้ด `app/lib/features/` ที่ยังไม่ผ่านการพิจารณาว่าควรลดน้ำหนัก (ลบ shadow, ใช้ border บางแทน) ตามคอนเซปต์ minimal ที่ DS-001 กำหนดทิศทางไว้

Requirements:

R1. Sweep ทุกจุดที่ใช้ literal `EdgeInsets`/`SizedBox` สำหรับ spacing ในทั้ง 2 แอป แทนที่ด้วยค่าที่ตรงที่สุดจาก `WynSpacing.space{1,2,3,4,5,6,8,10,12}` — ถ้าค่าที่มีอยู่ไม่ตรงกับ token ใดเป๊ะ ให้ปัดเข้าค่าที่ใกล้ที่สุดในสเกล (ห้ามเพิ่ม token ใหม่นอกสเกลที่ DS-001 กำหนดไว้แล้วโดยไม่ขออนุมัติ)

R2. Sweep ทุกจุดที่ใช้ literal `BorderRadius.circular(...)` แทนที่ด้วย `WynSpacing.radius{None,Sm,Md,Lg,Full}` ตามบริบท (ปุ่ม/input/card → `radiusMd`, chip/badge/thumbnail เล็ก → `radiusSm`, bottom sheet/dialog/ZOKY product card → `radiusLg`, avatar/pill → `radiusFull`, รูปเต็มความกว้างใน feed → `radiusNone`)

R3. ตรวจทุกจุดที่ใช้ `Card`/`BoxShadow` (29 จุดที่ audit พบใน `app/lib/features/`, ต้อง sweep `seller_app/lib/features/` เพิ่มด้วย) แล้วตัดสินใจทีละจุดว่าควร: (ก) คงไว้เพราะจำเป็นต้องแยกระดับพื้นผิวจริง ๆ (เช่น bottom sheet, dialog) (ข) ลดเป็น border บางแทน shadow (ตรงกับ "Minimal Social Platform" — ลด elevation, เพิ่มเส้นขอบบาง) ตาม `colorScheme.outlineVariant` ที่ DS-001 นิยามไว้แล้ว

R4. ตรวจ touch target ทุกปุ่ม/tappable element ที่มีอยู่แล้ว ≥ `WynSpacing.touchTargetMin` (44px) — จุดไหนไม่ถึงให้ปรับ padding/ขนาดให้ผ่าน (WCAG 2.5.5)

R5. ห้ามแตะโครง layout/widget tree ที่มีนัยต่อพฤติกรรม (การจัดเรียง element, การนำทาง, logic ใด ๆ) — เปลี่ยนแค่ค่าตัวเลข spacing/radius/shadow เท่านั้น เพื่อจำกัด blast radius ตามที่ DS-001 กำหนดไว้ (แบ่งเป็น task ย่อยเพื่อให้ QA ตรวจได้จริงและ rollback ได้ตรงจุดถ้าพัง)

R6. ห้ามแก้ไฟล์ในโฟลเดอร์ `pop/` เว้นแต่จำเป็นต้องแทนที่ literal spacing/radius ที่ชนกับ R1/R2 ตรง ๆ (มิเรอร์บทเรียนจาก DS-001c ที่ต้องแตะ `pop/` 2 จุดเพื่อ token สี — ถ้าเกิดกรณีเดียวกันอีก ให้บันทึกเหตุผลไว้ใน Coding Output ชัดเจนเหมือนที่ DS-001c ทำ)

R7. Test suite เดิมทั้ง 2 แอป (280 + 91 ปัจจุบัน) ต้องผ่านครบทุกตัวหลัง sweep — งานนี้เป็น visual-only change ไม่ควรทำให้ widget test พังเลยถ้าไม่แตะ layout จริง

Acceptance Criteria:
- [ ] `grep -c "WynSpacing\."` ในโค้ด UI (นอก `core/design/`) มากกว่า 0 อย่างมีนัยสำคัญ (ครอบคลุมทุกหน้าจอหลัก ไม่ใช่แค่ 1-2 จุด)
- [ ] ไม่มี literal `EdgeInsets.all(<number>)`/`BorderRadius.circular(<number>)` เหลือในโค้ด UI ของทั้ง 2 แอป ยกเว้นจุดที่มี comment อธิบายเหตุผลชัดเจนว่าทำไมใช้ค่านอกสเกล
- [ ] ทุกจุดที่เคยมี `BoxShadow`/`Card` elevation ผ่านการพิจารณาแล้วทีละจุด (บันทึกในรายงานว่าคงไว้กี่จุด เหตุผลอะไร ลดกี่จุด)
- [ ] touch target ทุกปุ่ม ≥ 44px (มี regression test อย่างน้อย 1 ชุดยืนยัน)
- [ ] `flutter analyze` สะอาดทั้ง 2 แอป
- [ ] `flutter test` ผ่านครบ (baseline ปัจจุบัน: app/ 280/280, seller_app/ 91/91 — ตัวเลขจริงตอนเริ่ม coding อาจต่างไปเล็กน้อยถ้ามี task อื่น merge คั่นก่อน ให้ยึดค่า ณ ตอนเริ่มเป็นฐาน)
- [ ] ไม่มีไฟล์ใน `data/` layer หรือ `supabase/schema.sql` ถูกแก้ไข (มิเรอร์กติกาเดียวกับ DS-001)
- [ ] Screenshot เปรียบเทียบก่อน/หลังอย่างน้อย 4 หน้าจอหลัก (Home, Drop grid, Profile, ZOKY) ทั้ง light/dark เพื่อให้ Founder เห็นความต่างจริง

Dependencies: DS-001 (approved — token foundation พร้อมใช้แล้ว)

Priority: กลาง — ต่อเนื่องจาก DS-001 ตามลำดับที่ AI Design เสนอไว้เอง (DS-001's Recommendation section) แต่ไม่ใช่ blocker ของ Phase 5/Internal Testing

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Sweep กว้างทั่ว 2 แอป (45+ หน้าจอ) — เสี่ยง regression เงียบ ๆ ถ้าเปลี่ยนค่าที่ปัดเข้าสเกลผิดทิศ (เช่น padding แคบลงจนข้อความชนกัน) | กลาง | ทำทีละ feature folder (Auth → Profile → Drop → Pop-token-only → Home → Club → ZOKY → Seller) รัน test หลังทุกกลุ่ม ไม่ commit รวดเดียวทั้งหมด |
| R2 | ลด Card/shadow อาจทำให้บางหน้าจอ "แบนไป" จนแยกส่วนไม่ออก (เช่น ปุ่มกับพื้นหลังสีเดียวกัน) | กลาง | ใช้ `colorScheme.outlineVariant` เป็น border แทนเสมอเมื่อลด shadow ไม่ใช่ลบตัวแบ่งไปเฉย ๆ |
| R3 | แตะ `pop/` แม้เพียงเพื่อ spacing/radius token อาจถูกมองว่าขัดกติกา "ห้ามพัฒนา Pop เพิ่ม" | ต่ำ | จำกัดเฉพาะ literal spacing/radius เท่านั้น (ไม่แตะ logic/layout) และบันทึกเหตุผลทุกจุดแบบเดียวกับ DS-001c |

Recommendation: ทำ token adoption (R1/R2) และ shadow/card review (R3) เป็น 2 sub-PR แยกกันเพื่อให้ QA ตรวจ/rollback ได้อิสระจากกัน มิเรอร์แนวทาง incremental ของ DS-001a/b/c — แนะนำเริ่มจาก `app/` ก่อน `seller_app/` เพราะแอปลูกค้ามี traffic/ผู้ใช้จริงมากกว่าเมื่อ deploy

Handoff: ส่งต่อ AI Design เพื่อตัดสินใจรายจุดว่า Card/BoxShadow จุดไหนคงไว้/ลด (Requirement R3) ก่อนส่งต่อ AI Coding — ยังไม่ต้องถาม Founder เพิ่มเติมเพราะเป็นการต่อยอดทิศทางที่อนุมัติแล้วใน DS-001 ล้วน ๆ ไม่มีการตัดสินใจระดับสีหรือสถาปัตยกรรมใหม่
