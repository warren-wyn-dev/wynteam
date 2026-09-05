# DS-010 — WYNOS Interaction Feedback System

> สถานะ: IMPLEMENTED (2026-09-05) — ระบบกลางสำหรับ haptic + micro-interaction ของ WYNOS
> โค้ด: `app/lib/core/interaction/`
> Guard: `app/test/interaction_guard_test.dart`, `app/test/interaction_feedback_test.dart`

## 1. ทำไมต้องมีระบบนี้

ก่อนหน้านี้ WYNOS มี `HapticFeedback.lightImpact()` กระจายอยู่ 4 จุด (ActionMetric,
DoubleTapLike, FollowActionButton, ViewProfileScreen) — ตอนมี 4 จุดยังไม่เป็นปัญหา
แต่พอถึง 40 จุดจะไม่มีที่วาง device check, ไม่มีที่กัน haptic ซ้ำจาก re-render และ
ไม่มีอะไรหยุดจุดที่ 5 จากการเลือก `mediumImpact` ให้ Like เพราะไม่รู้ว่าอีก 4 จุด
ตกลงกันว่าใช้ light

ระบบนี้ไม่ได้เพิ่ม dependency ใด ๆ และไม่ได้เปลี่ยน business logic, API contract,
database schema, สี หรือ layout ของเดิม

## 2. โครงสร้าง

```
app/lib/core/interaction/
  wyn_haptic_type.dart   — enum ของ "เจตนา" 7 แบบ (vocabulary)
  wyn_haptics.dart       — ไฟล์เดียวในโปรเจกต์ที่แตะ HapticFeedback ได้
  wyn_feedback.dart      — API ที่ feature เรียกใช้ (ตั้งชื่อตาม action ของผู้ใช้)
  wyn_motion.dart        — duration / curve / scale token + reduced-motion gate
  wyn_press_scale.dart   — WynPressScale (press feedback) + WynPressable
```

ทิศทางการเรียกใช้เป็นทางเดียวเสมอ:

```
feature → WynFeedback (semantic) → WynHaptics (intent) → platform
```

Feature **ห้าม** ข้ามไปเรียก `HapticFeedback` หรือ `WynHaptics` โดยตรง —
`interaction_guard_test.dart` บังคับข้อนี้จากซอร์สจริง (แนวเดียวกับ
`design_system_guard_test.dart` ที่บังคับ color token)

## 3. กติกา Haptic (ตัดสินใจครั้งเดียว ใช้ทั้งระบบ)

| น้ำหนัก | ใช้กับ | API |
|---|---|---|
| **light** | Like/Unlike, Save/Unsave, Follow/Unfollow, ส่ง comment สำเร็จ, toggle สำคัญอื่น ๆ | `WynFeedback.like()` `.save()` `.follow()` `.commentSent()` `.toggle()` |
| **selection** | เปลี่ยน Tab (Bottom Nav), segmented control, filter | `WynFeedback.selectionChanged()` |
| **medium** | Delete สำเร็จ, confirm action ที่ระบบถามซ้ำแล้ว | `WynFeedback.deleted()` `.confirmed()` |
| **success** | Drop/Pop/Club Post โพสต์สำเร็จ, บันทึกข้อมูลสำเร็จ | `WynFeedback.completed()` |
| **error** | Action ที่ผู้ใช้สั่งแล้วไม่สำเร็จจริง ๆ | `WynFeedback.failed()` |
| **heavy / warning** | ยังไม่ใช้ — สงวนไว้ ไม่ให้ action ใหม่ไปหยิบ `error` มาใช้แค่เพราะอยากได้แรงกว่า | — |

**Create Post อยู่ทั้งกลุ่ม medium และ success ในโจทย์** — ตัดสินให้เป็น
`success` เพราะสิ่งที่กำลังบอกผู้ใช้คือ "มันสำเร็จแล้ว" และการโพสต์เป็น action
เดียวใน WYNOS ที่มีการรอจริง ๆ ส่วน medium สงวนไว้ให้ confirm/delete ที่ประเด็นอยู่
ที่ "น้ำหนักของการตัดสินใจ" ไม่ใช่ผลลัพธ์

### สิ่งที่ตั้งใจ "ไม่" ใส่ haptic

- **Navigation ทุกครั้ง** — push/pop ทั้งแอปไม่มี haptic เลย มีแค่การเปลี่ยน tab
  ใน Bottom Nav เท่านั้น (haptic ทุกครั้งที่เปลี่ยนหน้าจะหมดความหมายและกินแบตเตอรี่)
- **การกด "+" (สร้าง Drop) ใน Bottom Nav** — เป็น action ไม่ใช่ tab
- **กด Home ซ้ำเพื่อ scroll to top** — ไม่ได้เปลี่ยน selection
- **Scroll / pull-to-refresh / โหลดหน้าถัดไป** — ผู้ใช้ไม่ได้สั่งอะไรที่ต้อง confirm
- **Form validation ที่ยังกรอกไม่เสร็จ** — `failed()` ใช้เฉพาะตอนที่ action ไม่สำเร็จจริง
- **การกด tap-to-open โพสต์ / เปิดโปรไฟล์** — เป็น navigation

## 4. Feature detection และ Fallback

`WynHaptics.isSupported` เป็น true เฉพาะ Android และ iOS

- **Web** (WYNOS มี web build จริง — `.github/workflows/deploy-web.yml`) → เงียบสนิท
- **Desktop / embedder อื่น** → เงียบสนิท
- ทุก platform-channel error ถูก swallow ใน `WynHaptics.fire` → haptic ที่ล้มเหลว
  ต้องไม่ทำให้ Like ล้มเหลว และต้องไม่ถูกเข้าใจผิดว่าเป็น error ของ action เอง
- UI ทำงานครบเหมือนเดิมทุกกรณี — haptic เป็นส่วนเสริมบน UI ที่บอกผลอยู่แล้ว

### กัน haptic ซ้ำจาก re-render

`WynHaptics` ทิ้ง intent ซ้ำชนิดเดียวกันที่ห่างกัน < 80ms (double-tap ที่คนกดจริงเร็วสุด
ประมาณ 150ms) — เทียบจาก timestamp ไม่ใช้ `Timer` เพราะ pending timer ตอนจบ widget test
จะทำให้เทสต์ fail และแอปนี้มี test file 150+ ไฟล์ที่ต้องผ่านต่อไป

## 5. Motion token

| Token | ค่า | ใช้กับ |
|---|---|---|
| `WynMotion.press` | 90ms | ปุ่มตอบสนองนิ้ว |
| `WynMotion.quick` | 160ms | icon เปลี่ยนสถานะ, label cross-fade |
| `WynMotion.standard` | 220ms | ค่า default ของ element ที่เปลี่ยนขนาด/ตำแหน่ง/opacity |
| `WynMotion.emphasized` | 300ms | element เข้า/ออกจากจอเอง |
| `WynMotion.pressedScale` | 0.94 | ขนาดตอนกดค้าง |
| `WynMotion.popFromScale` | 0.75 | จุดเริ่มของ pop ตอน state เปลี่ยน |

Animation ทั้งหมดใช้ `transform` (scale) และ `opacity` เท่านั้น — ไม่ animate
padding/width/height ที่บังคับ layout ใหม่ทุกเฟรมบนการ์ดที่ผู้ใช้กำลัง scroll อยู่

## 6. Reduced motion

`WynMotion.isReduced(context)` อ่าน `MediaQuery.disableAnimations` ซึ่ง Flutter map
มาจาก iOS "Reduce Motion", Android "Remove animations" และ `prefers-reduced-motion`
ของเบราว์เซอร์ (web build) ทั้งสามทางเป็น flag เดียวกัน

หลักการ: **ตัดการเดินทาง ไม่ตัดสถานะ** — `WynMotion.duration()` คืน `Duration.zero`
แปลว่า widget ยัง "ถึง" ค่าปลายทางทันที สถานะจึงไม่หายไป มีแต่ระยะทางระหว่างสถานะที่หายไป
ข้อนี้คือข้อกำหนด accessibility: animation ต้องไม่ใช่สิ่งเดียวที่สื่อความหมาย

## 7. จุดที่ระบบถูกนำไปใช้แล้ว

Like (feed action row + double-tap + Pop rail + Club post), Save (Home feed, Drop
detail, Pop, Club post), Follow (FollowActionButton + ViewProfileScreen + ส่ง/ยกเลิก
follow request), ส่ง comment (Drop / Pop / Club post), Delete (Drop, Pop, Club post,
comment), Create (Drop, Pop, Club post), เปลี่ยน tab ใน Bottom Nav

## 8. วิธีเพิ่ม action ใหม่

1. เลือกน้ำหนักจากตารางข้อ 3
2. ถ้ามี method ใน `WynFeedback` อยู่แล้ว → เรียกอันนั้น
3. ถ้ายังไม่มี → เพิ่ม method ใหม่ใน `wyn_feedback.dart` ตั้งชื่อตาม *สิ่งที่ผู้ใช้ทำ*
   ไม่ใช่ตามน้ำหนักคลื่น แล้วอัปเดตตารางข้อ 3 ในเอกสารนี้
4. ห้ามเพิ่ม `import 'package:flutter/services.dart'` เพื่อเรียก HapticFeedback
   ใน feature — guard test จะ fail
