# WYN Design Principles (V0.1 — Proposed by AI Design)

> สถานะ: PROPOSED — ร่างเบื้องต้นโดย AI Design เนื่องจากยังไม่มี brand guideline เต็มรูปแบบจาก Founder (มีแค่ Color Direction ที่ Founder กำหนดไว้ชัดแล้ว — ดูด้านล่าง) ปรับแก้ได้ทุกเมื่อ ไม่ใช่กติกาตายตัวเหมือน Major Architecture

## กติกาที่ Founder กำหนดไว้ตายตัว (ไม่ใช่ AI Design เลือกเอง)

มาจาก "WYN V0.1 — CORE APP FEATURE PROMPT" (ดู `.wyn/company/DECISIONS.md` 2026-08-14):

- **Color Direction: Blue + White + Soft Gray** (แทนที่สี Primary เดิมที่เป็น PROPOSED ม่วง/ชมพู — ดูหัวข้อสีด้านล่าง)
- **ห้ามใช้ Liquid Glass** (ไม่ใช้พื้นผิวโปร่งแสง/เบลอแบบกระจกฝ้า — ใช้พื้นผิวทึบ/เรียบแทน)
- **ห้ามลอก Layout ของ Instagram หรือ TikTok โดยตรง** — ต้องออกแบบ UI เป็นของ WYN เอง ไม่ใช่ก็อปปี้โครงสร้างหน้าจอของแอปคู่แข่ง

## เป้าหมายการออกแบบ
ออกแบบเพื่อกลุ่ม **Gen Z** บนแอป **มือถือ (Flutter, mobile-first)** เน้น: เร็ว, เรียบง่าย, สนุก, ไม่เป็นทางการเกินไป และลด friction ในทุกขั้นตอนสำคัญ (โดยเฉพาะ onboarding)

## โทนและบุคลิก (Tone)
- Friendly, energetic, ไม่เป็นทางการ (ใช้ภาษาพูดกับผู้ใช้ในระดับที่เหมาะสม เช่น "ยินดีต้อนรับสู่ WYN 👋" มากกว่า "กรุณาดำเนินการลงทะเบียน")
- ข้อความสั้น กระชับ อ่านจบในสายตาแรก
- Micro-copy เป็นมิตร ไม่ใช้ศัพท์เทคนิค

## สี (Color — Blue + White + Soft Gray ตามที่ Founder กำหนด 2026-08-14)
- Primary: **Blue** — เสนอ shade ที่ชัดเจน ทันสมัย ไม่ neon จนล้าไว (เช่น `#2D6CDF` เป็นจุดเริ่มต้น — Founder ปรับเฉด/ยืนยันจริงได้ภายหลัง แต่ทิศทาง "น้ำเงิน" เป็นกติกาตายตัวแล้ว)
- Neutral: White + Soft Gray (พื้นหลัง/การ์ด) — เทาที่เลือกควรมี hue bias เข้าทางฟ้าเล็กน้อยให้เข้ากับ Primary (ไม่ใช่เทากลาง pure grey)
- **ห้ามใช้ Liquid Glass** (ไม่ใช้ blur/translucent surface) — การ์ด/แถบต่าง ๆ ใช้พื้นผิวทึบเสมอ
- ต้องรองรับทั้ง Light mode และ Dark mode ตั้งแต่เริ่มต้น (Gen Z ใช้ dark mode เป็นค่าเริ่มต้นจำนวนมาก) — โทนน้ำเงินต้อง contrast ผ่าน AA ทั้งสองโหมด
- สีสถานะ: เขียว (success), แดง (error/destructive), เหลือง/ส้ม (warning) — ใช้ตาม convention มาตรฐาน ไม่ประดิษฐ์ใหม่ (หัวใจ Like ยังใช้แดงตาม universal convention เหมือนเดิม ไม่ใช่ primary blue)

## Typography
- ฟอนต์ sans-serif ที่รองรับภาษาไทย + อังกฤษ ชัดเจนบนจอมือถือขนาดเล็ก (เช่นตระกูล Inter/Noto Sans Thai หรือเทียบเท่า — เลือกจริงตอน implement)
- Scale: Heading (ชื่อหน้า/หัวข้อสำคัญ), Body (เนื้อหาอ่านทั่วไป), Caption (label เล็ก/hint)
- ขนาดตัวอักษรขั้นต่ำ 14px สำหรับ body เพื่อ accessibility

## Spacing & Layout
- ใช้ระบบ spacing 4px-based grid (4, 8, 12, 16, 24, 32...)
- Touch target ขั้นต่ำ 44x44px ทุกปุ่ม/element ที่กดได้ (มาตรฐาน mobile accessibility)
- Bottom-anchored primary action บนหน้าจอที่มีปุ่มหลักเดียว (เอื้อมนิ้วโป้งถึงง่ายบนมือถือจอใหญ่)

## Components พื้นฐานที่ต้องมีตั้งแต่ V0.1
- Primary Button / Secondary Button / Text Button
- Text Input (พร้อม error state)
- OTP Input (6 ช่องแยก)
- Loading indicator / Skeleton state
- Toast / Inline error message
- Social Login Button (Google, Apple — ต้องตรงตาม brand guideline ของ Google/Apple เอง เช่น Apple บังคับปุ่ม "Sign in with Apple" ต้องใช้ asset ทางการ)

## Accessibility (ค่าเริ่มต้นบังคับทุกหน้า)
- Contrast ratio ผ่านมาตรฐาน WCAG AA ขั้นต่ำ
- รองรับ screen reader (label ทุก interactive element)
- รองรับการขยายขนาดตัวอักษรของระบบ (dynamic type)
- ไม่สื่อสารข้อมูลด้วยสีอย่างเดียว (ต้องมี icon/ข้อความประกอบ)

## หมายเหตุ
เมื่อ Founder มี brand guideline จริง (โลโก้, สีแบรนด์, ฟอนต์ที่เลือก) ให้ AI Design ปรับเอกสารนี้ทันที และปรับ `.wyn/company/CONTEXT.md` (Design Principles) ให้ตรงกัน
