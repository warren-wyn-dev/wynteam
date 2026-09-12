# WYN "Flare" — Core Component Library (V1.0 — PROPOSED)

Status: **PROPOSED** — คู่กับ `wyn-142-visual-identity-redesign.md` เป็นฐานอ้างอิงร่วมของสเปกรายหน้าจอทั้งหมด (`wyn-144` ถึง `wyn-157`)
Owner: AI Design
อ้างอิง token ทั้งหมดจาก `wyn-142-visual-identity-redesign.md`

ทุกคอมโพเนนต์ในเอกสารนี้ต้องผ่าน: touch target ≥44×44px, contrast AA ทั้ง light/dark, ไม่ใช้ Liquid Glass, ไม่สื่อความหมายด้วยสีอย่างเดียว

---

## 1. Button

### Primary Button
- Shape: pill (`radius.pill`), height 52px, full-width หรือ auto ตามบริบท
- พื้นหลัง: `color.accent` / ตัวหนังสือ: `color.paper` (ขาว/paper บนพื้น accent) / font: `type.body.m` SemiBold
- States: Default → Pressed (`color.accent.pressed`, scale 0.97 ด้วย `motion.fast`) → Disabled (opacity 40%, ไม่ตอบสนอง touch) → Loading (แสดง spinner แทนข้อความ, ปุ่มถูก disable ระหว่างโหลด)

### Secondary Button
- โครงเดียวกับ Primary แต่พื้นหลังโปร่ง มีเส้นขอบ `color.hairline` หนา 1.5px, ตัวหนังสือ `color.ink`
- Pressed: พื้นหลังเปลี่ยนเป็น `color.surface`

### Text Button
- ไม่มีพื้นหลัง/ขอบ, ตัวหนังสือ `color.accent`, ใช้กับ action รอง (เช่น "ข้าม", "ยกเลิก")
- Pressed: opacity 70%

### ทุกปุ่ม
- Disabled state ต้องสื่อสารชัดด้วย opacity + ไม่ใช่แค่สีจาง (คงคอนทราสต์ label พอมองเห็นได้ว่าเป็นปุ่ม)

---

## 2. Text Input

- Height ขั้นต่ำ 52px, radius `radius.m`, พื้นหลัง `color.surface`, ไม่มีขอบ default
- Focus: ขอบ 1.5px สี `color.accent`
- Error: ขอบ 1.5px สี `color.error` + ข้อความ error ใต้ input (สี `color.error` + ไอคอน warning เล็ก ๆ ประกอบ ไม่ใช้สีอย่างเดียว)
- Placeholder: `color.ink.muted`
- Label ลอยด้านบนเมื่อ focus/มีค่า (floating label) หรือ label คงที่ด้านบน — เลือกแบบคงที่ด้านบนเพื่อความเรียบง่ายและลด motion ที่ไม่จำเป็น

## 2b. OTP Input
- 6 ช่องแยก, แต่ละช่องสี่เหลี่ยมมุมโค้ง `radius.s`, ขนาด 48×56px, ตัวเลขใหญ่ `type.heading.1`
- Auto-focus ช่องถัดไปเมื่อกรอกครบ 1 หลัก, รองรับ paste ทั้งชุด
- Error: ทุกช่องขอบแดง + shake animation สั้น ๆ (`motion.fast`, เคารพ reduce-motion)

## 2c. Search Bar
- Pill shape, พื้นหลัง `color.surface`, ไอคอนแว่นขยายซ้าย, ปุ่ม clear (×) ขวาเมื่อมีข้อความ
- Sticky ที่ด้านบนเมื่อ scroll (หน้า Search, Top100)

---

## 3. Navigation

### Bottom Tab Bar
- 5 ช่อง (Home, Search, Drop [ปุ่มกลางเด่น], Notifications, Profile) — คงโครง 5-tab ตาม `wyn-v1.0.0-roadmap.md`
- ไอคอน outline (inactive) / filled + สี `color.accent` (active) — ปุ่ม Drop ตรงกลางเป็นปุ่มวงกลมยกสูงกว่าระดับ tab bar เล็กน้อย พื้นหลัง `color.accent`, ไอคอน `+` สีขาว
- พื้นหลัง tab bar: `color.paper` (light) / `color.surface` (dark) + เส้นบาง `color.hairline` ด้านบน (ไม่ใช้เงาลอยแบบ floating pill เพื่อความเรียบง่ายและ contrast ที่แน่นอน)
- Badge ตัวเลข (notification count) มุมขวาบนไอคอน: วงกลมพื้น `color.heart`, ตัวเลขขาว, ขนาดขั้นต่ำ 16px

### Top App Bar
- Height 56px, ชื่อหน้าจอ `type.display.l` ชิดซ้าย (ไม่ centered — energetic/informal), ปุ่ม action ขวา (ถ้ามี) ขนาด touch target 44×44px

### Side Menu / Sheet Navigation
- เปิดจากซ้าย เป็น overlay ทึบ (ไม่ blur พื้นหลัง) กว้าง 80% ของจอ

---

## 4. Card

- พื้นหลัง `color.surface`, radius `radius.m`, padding 16px
- Elevation ระดับ 1 (ดู wyn-142) — ใน dark mode ไม่มีเงา ใช้ความต่างของสี surface/paper แทน
- ใช้กับ: Drop card, Club card, Search result card

## 5. Avatar

- วงกลม (`radius.pill`), ขนาดมาตรฐาน: 24px (inline/comment), 40px (list item), 64px (profile header), 96px (edit profile)
- Ring สี `color.accent` หนา 2px รอบ avatar เมื่อมี story/live indicator (ถ้ามี feature นี้ในอนาคต — ปัจจุบันเว้นไว้)
- Fallback: ตัวอักษรแรกของชื่อบนพื้นสี `color.accent` โทนอ่อน (tint 20%) เมื่อไม่มีรูป

## 6. Badge / Chip

- Badge ตัวเลข: วงกลมพื้น `color.heart`, ข้อความขาว `type.caption`
- Chip (tag/hashtag/filter): pill shape, พื้นหลัง `color.surface`, ขอบ `color.hairline`, selected state เปลี่ยนพื้นหลังเป็น `color.accent` + ตัวหนังสือขาว

## 7. Toast / Inline Message

- Toast: แถบมุมโค้ง `radius.m` ลอยเหนือ bottom tab bar, พื้นหลัง `color.ink` (dark surface เสมอไม่ว่าโหมดไหน เพื่อ contrast), ตัวหนังสือ `color.paper`, auto-dismiss 3 วินาที, รองรับปัดเพื่อปิดก่อนเวลา
- Inline error/success message: อยู่ในบริบท (เช่นใต้ input) ไม่ใช้ toast สำหรับ error ที่ผูกกับ field เฉพาะ

## 8. Loading / Skeleton

- Skeleton: บล็อกสี `color.surface` พร้อม shimmer animation แนวนอน (`motion.base` loop, เคารพ reduce-motion — ถ้า reduce motion เปิดใช้ static skeleton ไม่ shimmer)
- Spinner: ใช้สี `color.accent`, ขนาด 20/24/32px ตามบริบท (inline/ปุ่ม/full-screen)

## 9. Modal / Bottom Sheet

- Bottom Sheet: มุมบนโค้ง `radius.l`, มี drag handle บาง ๆ ตรงกลางด้านบน, พื้นหลัง scrim ทึบ `rgba(23,20,15,0.4)` (ไม่ blur)
- Modal (dialog กลางจอ): ใช้เมื่อต้องการ focus การตัดสินใจสำคัญ (เช่น ยืนยันลบ) เท่านั้น — ปุ่ม destructive ใช้ `color.error`

## 10. List Item

- Height ขั้นต่ำ 56px (รองรับ touch target), padding แนวนอน 16px
- โครง: [Leading: avatar/icon] — [Title `type.body.l` + Subtitle `type.body.s` สี `ink.muted`] — [Trailing: action/chevron]
- Pressed state: พื้นหลัง `color.surface` briefly

## 11. Media Viewer / Carousel

- รูปภาพ/วิดีโอเต็มความกว้าง, มุมโค้ง `radius.m` เมื่ออยู่ในการ์ด, เต็มจอ (ไม่มีมุมโค้ง) เมื่อเปิดดูแบบ fullscreen
- ตัวบอกตำแหน่ง carousel: จุดกลม (dots), จุด active สี `color.accent`
- รองรับ pinch-to-zoom ในโหมด fullscreen viewer

## 12. Empty State

- ไอคอน/ภาพประกอบเรียบง่าย (line-art สไตล์เดียวกับ iconography) + หัวข้อ `type.heading.2` + คำอธิบายสั้น `type.body.m` สี `ink.muted` + ปุ่ม action (ถ้ามี)
- โทนข้อความเป็นมิตร ไม่ใช้ภาษาทางการ เช่น "ยังไม่มีอะไรตรงนี้เลย" แทน "ไม่พบข้อมูล"

## 13. Social Login Button

- ใช้ asset/สเปกทางการของ Google/Apple ตรงตาม brand guideline ของแต่ละเจ้า ไม่ปรับสีตาม `color.accent`
- จัดวางแบบ full-width, height เท่ากับ Primary Button (52px) เพื่อความสม่ำเสมอของ layout

---

## Handoff
สเปกรายหน้าจอทั้งหมด (`wyn-144` – `wyn-157`) ต้องอ้างอิงชื่อคอมโพเนนต์และ token จากเอกสารนี้และ `wyn-142` เท่านั้น ห้ามประดิษฐ์คอมโพเนนต์ใหม่นอกเอกสารนี้โดยไม่มีเหตุผลเฉพาะหน้าจอที่ระบุไว้ชัดเจนในสเปกนั้น ๆ
