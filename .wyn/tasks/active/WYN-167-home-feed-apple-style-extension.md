# Design Task — WYN-167

Status: active (รอ Founder อนุมัติ scope ก่อนส่ง AI Coding)
Owner: AI Design → รอ Founder → AI Coding → AI QA & Security → AI Deploy & DevOps
Screen: WYNOS Web Home Feed (`/home`, `web/components/home/*.tsx`, `web/app/home.css`)
Purpose: ขยายภาษา interaction motion จาก WYN-163 (Apple-style press-scale) มาที่ Home feed ตามแผน rollout
เดิมของ WYN-160 (ลำดับที่ 3: Home/Bottom Nav ต่อจาก Auth) — ขอบเขตแคบมาก: เพิ่ม press feedback ให้ปุ่ม
"ติดตาม" + ไอคอน header 3 ปุ่ม และทำเส้นใต้แท็บให้ animate แทนสลับทันที ไม่แตะขนาด/สี/spacing/layout ใดๆ
User Flow: ไม่เปลี่ยน
Components: `.wyn-post-follow-pill`, `.wyn-home-header-action`, `.wyn-home-tab-indicator` (ทั้งหมดประกาศใน
`web/app/home.css` เท่านั้น ไม่ใช้ร่วมกับหน้าอื่น — ยืนยันด้วย grep แล้ว)
Interactions: press-scale `transform: scale(0.96)` (สูตรเดียวกับ WYN-163) บน 2 ปุ่มแรก, animate transition
บนเส้นใต้แท็บ
States: เพิ่ม pressed state ใหม่ 2 จุด
Responsive Behavior: ไม่เปลี่ยน
Accessibility: เพิ่ม `prefers-reduced-motion` fallback ทั้ง 3 จุด (ปัจจุบัน `home.css` ไม่มีเลย)
Design Rules: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-167-home-feed-apple-style-extension.md` — **ไม่แตะ**
`.route-primary`/`.route-secondary` (ใช้ร่วม 13 ไฟล์ทั่วแอป, นอกขอบเขต), **ไม่แตะ** action row (มี press
feedback ดีอยู่แล้ว), **ไม่แตะ** ขนาด/radius/สี ของ Home (คง compact/conversation-first ไว้ตามเจตนาเดิม)
Handoff: พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติ scope — ไฟล์เดียว (`web/app/home.css`), ความเสี่ยง
regression ต่ำมาก (เพิ่ม CSS transition/`:active` ล้วนๆ)

## คำถามรอ Founder ตอบ

1. เห็นด้วยกับขอบเขตนี้ไหม (แค่ motion 3 จุด ไม่แตะขนาด/สี/spacing)?
2. อยากขยาย `.route-primary`/`.route-secondary` (ใช้ทั่วแอป 13 หน้าจอ) เป็นงานถัดไปด้วยไหม หรือเก็บไว้ทีหลัง?
