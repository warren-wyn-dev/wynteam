# DS-009 — Rainbow Accent (Option B, Founder-approved 2026-08-22)

> สถานะ: **APPROVED** — Founder เลือก Option B จากหน้าเปรียบเทียบของ AI Design (ดู `.wyn/company/DECISIONS.md`, 2026-08-22)
> เอกสารนี้เป็นส่วนเสริมของ DS-001 (`.wyn/docs/design/ds-001-color-system.md`) **ไม่ใช่การแทนที่** — ทุก token/rule ของ DS-001–008 (Cyan `#00C8FF` เป็น primary, Orange `#FF6B35` เฉพาะ ZOKY) ยังบังคับใช้เหมือนเดิมทุกประการ

## สรุปคำตัดสินใจ

Rainbow **ไม่ใช่สี primary ใหม่** — เป็น accent เสริมที่ผูกกับความหมาย "กำลังนิยม/trending" เท่านั้น ใช้ใน **2 จุดเท่านั้น** ทั้งระบบรอบนี้ ไม่มีจุดที่สาม จนกว่าจะมีคำสั่งเพิ่มเติมจาก Founder

## Token ใหม่

```
wynRainbow = LinearGradient([
  #FF6B6B (coral),
  #FFB347 (amber),
  #4ECDC4 (mint),
  #4A9DE0 (sky),
  #9B6BFF (violet),
])
```

ค่าเดียวกันทั้ง light และ dark mode (gradient ไม่ต้องปรับตามธีม เพราะไม่เคยถูกใช้เป็นพื้นหลังตัวหนังสือ — ดูกติกาข้อ 3)

## จุดที่ใช้ได้ (2 จุดเท่านั้น)

1. **Trending avatar ring** — วงแหวนบางรอบ avatar เฉพาะ content ที่ปรากฏใน "กำลังนิยม" (Trending row ของ Home, WYN-017) เท่านั้น — avatar ปกติในการ์ด feed **ไม่มี** ring นี้ ใช้ `conic-gradient` ของ 5 สีข้างบน หนา 2px เว้นจาก avatar 2px (มิเรอร์แนวคิด "story ring" ที่คุ้นเคย แต่ผูกกับความหมาย trending ไม่ใช่ story feature ที่ไม่มีใน WYNOS)
2. **Active feed-mode indicator** — เส้นบาง (2px, bo-radius เต็ม) ใต้ปุ่มที่ active ใน `SegmentedButton` ของ Home's feed-mode selector (สำหรับคุณ/ติดตาม/ล่าสุด/จาก Club ของคุณ — ดู WYN-024) วางนอก touch target เดิมของปุ่ม ไม่ทับตัวหนังสือ

## ห้ามใช้เด็ดขาด (กติกาต่อยอดจาก DS-001 ข้อ 6-8)

3. **ห้ามใช้ Rainbow เป็นสีตัวหนังสือ/ไอคอนเปล่า หรือพื้นหลังของสิ่งที่มีตัวหนังสือทับ** — เหตุผลด้าน accessibility: gradient ไม่มีค่า contrast เดียวที่นิยามได้ (ปลาย coral ~2.8:1, ปลาย mint ~1.9:1 บนพื้นขาว — ทั้งคู่ตกเกณฑ์ AA) ต่างจาก Cyan ที่อย่างน้อยมี fallback (ใช้เป็นพื้นปุ่ม + ตัวหนังสือดำ) ที่พิสูจน์แล้วว่าอ่านออก
4. **ห้ามแทนที่ Cyan ในจุดใดที่ Cyan ใช้อยู่แล้ว** — ปุ่มหลัก, ไอคอน active ของ Bottom Nav, ลิงก์ ทั้งหมดยังเป็น Cyan เหมือนเดิมทุกประการตาม DS-001
5. **ห้ามใช้กับ ZOKY** — โซน ZOKY (ราคา/ปุ่ม commerce) ยังใช้ Orange ล้วนตาม DS-001 ข้อ 7 ไม่ผสม Rainbow
6. **สัดส่วนพื้นที่**: ทั้งสองจุดรวมกันต้องเป็นเส้น/ขอบบางเท่านั้น ไม่ใช่พื้นที่ทึบขนาดใหญ่ — คงหลักการ "10–20% Rainbow" ของบรีฟในเชิงสายตา (จุดเล็กที่สะดุดตา ไม่ใช่พื้นผิวกว้าง)

## Reference implementation

ดู CSS จริงในหน้าเปรียบเทียบ (`.optB .m-avatar-ring.trending`, `.optB .m-seg span.active::after`) ที่ artifact ของ DS-009 (ลิงก์ใน `.wyn/tasks/backlog/DS-009-v1-rebrand-color-comparison.md`) เป็นต้นแบบภาพที่ Founder เห็นตอนตัดสินใจ — ให้ AI Coding ยึดค่าตัวเลข/ตำแหน่งจากที่นี่เป๊ะ ไม่ตีความใหม่

## Handoff

ส่งต่อ AI Coding พร้อมกับ WYN-024 (จุดที่ 2 อยู่ใน Home's feed-mode selector ซึ่งเป็นไฟล์เดียวกับที่ WYN-024 แก้อยู่แล้ว — ทำพร้อมกันในรอบเดียวได้) จุดที่ 1 (Trending ring) แตะ `TrendingTile` widget (WYN-017) เพิ่ม border แบบ gradient รอบ avatar ที่มีอยู่แล้ว
