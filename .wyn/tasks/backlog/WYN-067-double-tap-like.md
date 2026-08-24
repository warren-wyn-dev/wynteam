# Product Task — WYN-067

Status: backlog
Owner: AI Product Manager

Feature: Double-tap เพื่อ Like พร้อม Heart Animation

Goal: เพิ่ม interaction แบบ social platform มาตรฐาน — แตะโพสต์ 2 ครั้งเร็วๆ เพื่อ Like พร้อม animation หัวใจ

Target User: ผู้ใช้ทุกคนที่ดู Drop/Pop ใน Home Feed หรือหน้ารายละเอียด

Problem: ตรวจโค้ดปัจจุบันไม่พบ `onDoubleTap` ใดๆ ในการ์ด Home (`home_drop_card.dart`/`home_pop_card.dart`) หรือหน้ารายละเอียด — Like ปัจจุบันทำได้เฉพาะกดปุ่ม Like เท่านั้น ไม่มี double-tap gesture และไม่มี heart animation เลย

Requirements:
- R1. Double-tap บนพื้นที่รูป/วิดีโอของโพสต์ (Home card, Drop/Pop detail) → Like โพสต์นั้น
- R2. แสดง heart animation ขนาดใหญ่กลางโพสต์ตอน double-tap แล้ว fade out เอง (ไม่ต้องกดปิด)
- R3. Like count เพิ่มทันที (optimistic UI เหมือนปุ่ม Like ปกติที่มีอยู่แล้ว)
- R4. **กันการ Like ซ้ำ**: ถ้าโพสต์ถูก Like อยู่แล้ว double-tap ซ้ำต้อง**ไม่ unlike และไม่เพิ่ม count ซ้ำ** (ต่างจาก IG ที่ double-tap ซ้ำไม่ unlike เช่นกัน — ทำตามพฤติกรรมมาตรฐาน) แต่ยังคงแสดง heart animation ทุกครั้งที่ double-tap เพื่อ feedback ว่าระบบรับ input แล้ว
- R5. ปุ่ม Like เดิม (single-tap บนปุ่มหัวใจ) ยังคง toggle Like/Unlike ตามปกติ ไม่เปลี่ยนพฤติกรรม — double-tap เป็นทางลัดเพิ่มเติม ไม่ใช่แทนที่

Acceptance Criteria:
- [ ] Double-tap บนโพสต์ที่ยังไม่ได้ Like → Like ทันที + heart animation + count เพิ่ม 1
- [ ] Double-tap ซ้ำบนโพสต์ที่ Like อยู่แล้ว → ไม่ unlike, count ไม่เปลี่ยน, แต่ยัง fade heart animation ให้เห็น
- [ ] ปุ่ม Like เดิมยัง toggle ได้ปกติ ไม่มี regression
- [ ] ทดสอบทั้ง Home Drop card, Home Pop card, Drop detail, Pop clip view — ครบทุกจุดที่มี Like อยู่แล้ว

Dependencies: ใช้ Like toggle logic เดิม (WYN-005/WYN-006) เป็นฐาน ไม่สร้างระบบ Like ใหม่ — เพิ่มแค่ gesture detector + animation widget ใหม่

Priority: กลาง — เป็น engagement feature ที่ผู้ใช้คาดหวังจาก social platform แต่ไม่ใช่ core flow ที่บล็อกการใช้งานพื้นฐาน

Risks: double-tap อาจชนกับ gesture อื่นที่มีอยู่แล้วบนการ์ด (เช่น tap เดี่ยวเปิดรายละเอียด, tap ที่ avatar เปิดโปรไฟล์ WYN-013) — ต้องออกแบบ hit-testing ให้ไม่ชนกัน โดยเฉพาะ Pop ที่เป็น full-screen vertical swipe (`PopClipView`) ซึ่งมี gesture หลายชั้นอยู่แล้ว (double-tap Like ของ WYN-006 ก่อนหน้าเคยมีบั๊กเรื่องนี้มาก่อน — ดู CONTEXT.md WYN-006)

Recommendation: reuse `GestureDetector` เดียวที่ครอบพื้นที่สื่อ (รูป/วิดีโอ) เท่านั้น ไม่ใช่ทั้งการ์ด เพื่อไม่ชนกับ tap-to-open-detail/tap-to-profile ที่มีอยู่แล้ว

Handoff: AI Design ออกแบบ heart animation (ขนาด/ระยะเวลา fade/easing) ให้ตรง Design Language (WYNOS Cyan อาจไม่เหมาะกับหัวใจ Like — ควรใช้สีแดง/ชมพูมาตรฐานของ Like ตามที่ระบบเดิมใช้อยู่แล้ว) ก่อนส่ง AI Coding — ต้องระบุ hit-test area ชัดเจนในหน้า Pop เพื่อเลี่ยงบั๊กเดิมของ WYN-006
