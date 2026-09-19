# Design — WYN-167: ขยายภาษา Apple-style (WYN-163) มาที่ WYNOS Web Home Feed

Owner: AI Design → รอ Founder อนุมัติ → AI Coding
Ref: `.wyn/docs/design/wyn-163-onboarding-button-redesign.md` (ต้นทางภาษา visual), `.wyn/docs/design/
wyn-160-web-design-system-consolidation.md` (แผน rollout เดิมที่ระบุ "Home/Bottom Nav" เป็นลำดับที่ 3 ต่อจาก
Auth), `web/app/home.css`, `web/components/home/*.tsx`

## ทำไมไม่ใช่การคิดทิศทางใหม่

ตรวจ `.wyn/docs/design/` ก่อนแล้วพบว่ามี 2 เอกสารที่เกี่ยวข้องแต่ **ใช้ตรงๆ ไม่ได้**:
- `.wyn/docs/design/wyn-140-home-feed-premium-polish.md` และ `ds-003-home-feed.md` เป็นงาน **Flutter ล้วน**
  (แก้ `.dart` files) — Founder สั่งพัก Flutter ยาวแล้ว (DECISIONS.md 2026-09-19) ใช้เป็นข้อมูลอ้างอิงไม่ได้
- `wyn-160-web-design-system-consolidation.md` วาง rollout ไว้ชัดว่า Home คือลำดับที่ 3 ต่อจาก Auth (ที่เพิ่ง
  ทำเสร็จเป็น WYN-163) — **งานนี้คือการทำตามแผนเดิมที่อนุมัติไปแล้ว ไม่ใช่ทิศทางใหม่**

## สิ่งที่พบจากการตรวจโค้ดจริง (สำคัญ — กำหนดขอบเขตงานนี้)

`web/app/home.css` มีคอมเมนต์บอกไว้ตรงๆ ว่า Home ใช้ทิศทาง **"clean, compact, conversation-first"** (แบบ
Threads/X) โดยตั้งใจ — ต่างจาก Auth flow ที่เป็นหน้า hero/onboarding ที่เว้นระยะเยอะได้ ดังนั้น **การย้าย
ตัวเลขขนาด 58px/24px ของปุ่ม Auth มาใส่ตรงๆ ในปุ่มเล็กๆ ของ feed ที่หนาแน่นจะดูผิดสัดส่วนทันที** — สิ่งที่
ควรย้ายมาจริงๆ คือ **ภาษาการเคลื่อนไหว (press-scale motion)** ที่ WYN-163 เพิ่งอนุมัติ ไม่ใช่ตัวเลขเรขาคณิต
ตรงๆ

ไล่ grep หา component/CSS ปุ่มจริงบน Home แล้วพบสิ่งสำคัญที่ต้องรู้ก่อนแก้ (บทเรียนจาก WYN-164):
**ปุ่ม `.route-primary`/`.route-secondary` ที่ปรากฏใน `home-screen.tsx` (ปุ่ม "ลองใหม่"/ปุ่มรายงาน) ไม่ใช่
ปุ่มเฉพาะของ Home — ประกาศอยู่ใน `app/phase3.css` และถูกใช้ร่วมกับอีก 12 ไฟล์ทั่วแอป** (Profile, Chat, Clubs,
Bookmarks, Drafts ฯลฯ) **ถ้าแก้ปุ่มนี้ = แก้ทั้งแอปพร้อมกัน ไม่ใช่แค่ Home feed ตามที่ Founder ขอ** — งานนี้จึง
**ไม่แตะ `.route-primary`/`.route-secondary`** เก็บไว้เป็นงานแยกในอนาคตถ้า Founder อยากขยายต่อทั้งแอป (ต้องมี
QA รอบใหญ่กว่านี้มาก เพราะกระทบ 13 หน้าจอพร้อมกัน)

องค์ประกอบที่เป็น "ปุ่ม" จริงๆ และ **อยู่ในขอบเขต Home feed เท่านั้น** (class ประกาศเฉพาะใน `home.css`,
ไม่มีที่อื่นใช้ร่วม — ยืนยันด้วย grep แล้ว):
1. `.wyn-post-follow-pill` (ปุ่ม "ติดตาม" บนแต่ละโพสต์)
2. `.wyn-home-header-action` (ไอคอน ☰ / 🔍 / 🔔 บน header)
3. `.wyn-home-tab-indicator` (เส้นใต้แท็บที่ active)

ส่วน action row (หัวใจ/คอมเมนต์/รีโพสต์/แชร์/บันทึก) **มี press feedback ที่ดีอยู่แล้ว**
(`transform: scale(0.86)` + keyframe animation สำหรับหัวใจ) — ตรงเกณฑ์เดียวกับที่ WYN-140 ยืนยันไว้ฝั่ง
Flutter (Screen 4: "ไม่มีจุดต้องแก้") **ไม่ต้องแตะ**

## Screen: WYNOS Web Home Feed (`/home`, `web/components/home/*`)

Purpose: เติมช่องว่างเดียวที่ขาดจริง — ปุ่ม 3 จุดข้างต้นยังไม่มี press feedback เลย (ต่างจาก action row ที่มี
แล้ว) และเส้นใต้แท็บยัง**สลับตำแหน่งทันทีไม่มี animation** (`transition` ไม่มีอยู่เลยใน CSS ปัจจุบัน) — ทั้งสอง
เป็น "รายละเอียดที่ขาด" ไม่ใช่ "ทิศทางใหม่" ใช้ motion token เดียวกับที่ WYN-163 อนุมัติแล้ว
(`transform: scale(0.96)`, `prefers-reduced-motion` fallback) ไม่ประดิษฐ์ค่าใหม่

User Flow: ไม่เปลี่ยน flow ไหนเลย ไม่เปลี่ยนตำแหน่ง/ลำดับ element ใดๆ บนหน้าจอ — เป็นแค่ interaction feedback
เพิ่มเข้าไปในของเดิม

Components (ของเดิมทั้งหมด แค่เพิ่ม motion):
- `.wyn-post-follow-pill` — คงขนาด/รูปทรงเดิม (26px, pill 999px ตรงกับ "pill" role ของ WYN-160 อยู่แล้ว ไม่ใช่
  squircle เพราะเป็นชิปเล็กในบริบทหนาแน่น ไม่ใช่ CTA หลักแบบปุ่ม Auth) — **เพิ่ม `:active` press-scale**
- `.wyn-home-header-action` — คงขนาด 40×40/radius 12px เดิม — **เพิ่ม `:active` press-scale**
- `.wyn-home-tab-indicator` — คงความหนา/สีเดิม — **เพิ่ม `transition` ให้เลื่อนแบบ animate แทนการสลับทันที**

Interactions:
- `.wyn-post-follow-pill:active`, `.wyn-home-header-action:active` → `transform: scale(0.96)`,
  `transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1)` — **สูตรเดียวกับ WYN-163's
  `.btn-primary`/`.btn-outline` เป๊ะ** (ไม่ใช้ 0.86 แบบ heart-burst ของ action row เพราะนั่นคือ "like burst"
  effect เฉพาะทาง ไม่ใช่ press feedback ทั่วไป)
- `.wyn-home-tab-indicator` → เพิ่ม `transition: transform 220ms cubic-bezier(0.34, 1.56, 0.64, 1), width
  220ms cubic-bezier(0.34, 1.56, 0.64, 1)` (หรือ implementation ที่เทียบเท่าตามโครงสร้าง flex ปัจจุบัน) ให้
  เลื่อนจากตำแหน่งแท็บเก่าไปแท็บใหม่แบบ animate — **แนวคิดเดียวกับที่ WYN-140 เสนอไว้ฝั่ง Flutter (Screen 3)
  แต่ implement เป็น CSS transition แทน `AnimatedContainer`**

States: เพิ่ม "pressed" state ใหม่ให้ 2 ปุ่มข้างต้น (เดิมไม่มีการเปลี่ยนภาพตอนกดเลย) — state อื่นไม่เปลี่ยน

Responsive Behavior: ไม่เปลี่ยน (ตัวเลข fixed ไม่ผูกความกว้างจอ เหมือนเดิม)

Accessibility: เพิ่ม `@media (prefers-reduced-motion: reduce)` ปิด transition ทั้ง 3 จุด (ตรงกับที่ WYN-163
ทำไว้ทุกจุด — `home.css` ปัจจุบัน**ไม่มี** reduced-motion handling เลยแม้แต่จุดเดียว เป็นช่องว่างที่ควรอุดพร้อม
กันในรอบนี้) ไม่กระทบ touch target/contrast ที่มีอยู่แล้ว

Design Rules:
1. ใช้ motion token เดิมจาก WYN-163 เป๊ะ (`scale(0.96)`, `cubic-bezier(0.34, 1.56, 0.64, 1)`) ไม่ประดิษฐ์ค่า
   ใหม่ — สร้างความรู้สึกต่อเนื่องกับ onboarding ที่เพิ่งทำเสร็จ
2. **ไม่แตะ** ขนาด/radius/สี/spacing ของ element ใดๆ — คง "compact, conversation-first" ของ Home ไว้ 100%
   ตามที่ CSS comment เดิมระบุเจตนาไว้ชัด
3. **ไม่แตะ** `.route-primary`/`.route-secondary` (ใช้ร่วม 13 ไฟล์ทั่วแอป) — นอกขอบเขตงานนี้
4. **ไม่แตะ** action row (หัวใจ/คอมเมนต์/รีโพสต์/แชร์/บันทึก) — มี press feedback ที่ดีอยู่แล้ว

## Handoff

พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติ — **3 จุด ไฟล์เดียว** (`web/app/home.css`, เพิ่ม CSS rule ล้วนๆ
ไม่ต้องแก้ `.tsx` ไฟล์ไหนเลยเพราะ class name ครบอยู่แล้ว):
1. Press-scale บน `.wyn-post-follow-pill`
2. Press-scale บน `.wyn-home-header-action`
3. Animate transition บน `.wyn-home-tab-indicator`
4. เพิ่ม `@media (prefers-reduced-motion: reduce)` ครอบทั้ง 3 จุด

ความเสี่ยง regression ต่ำมาก — เป็นการเพิ่ม CSS transition/`:active` state ล้วนๆ ไม่แตะ layout/business logic/
class ที่ใช้ร่วมกับหน้าอื่น ไม่ต้องมี Artifact เปรียบเทียบภาพนิ่งก่อน-หลัง (ไม่มีอะไรเปลี่ยนในภาพนิ่ง — เปลี่ยน
แค่ความรู้สึกตอนกด) แต่ยินดีทำ prototype จริงให้กดทดสอบผ่าน dev server ก่อนได้ถ้า Founder อยากลองสัมผัสก่อน
อนุมัติ

**คำถามสำหรับ Founder** (ขอบเขตที่ตั้งใจแคบไว้ก่อน ตามกติกา "ทำทีละหน้า"):
- เห็นด้วยกับขอบเขตนี้ไหม (แค่เพิ่ม motion 3 จุด ไม่แตะขนาด/สี/spacing ของ Home)?
- อยากให้ขยาย `.route-primary`/`.route-secondary` (ใช้ทั่วแอป 13 หน้าจอ) เป็นงานถัดไปด้วยไหม หรือเก็บไว้ทีหลัง?
