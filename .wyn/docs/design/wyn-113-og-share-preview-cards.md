# WYN-113 — Open Graph / Twitter Card Share Preview

> วันที่: 2026-09-06
> Product spec: `.wyn/tasks/active/WYN-113-og-share-preview-cards.md`
> Mockup (Artifact, ต้องดูก่อนอนุมัติ): https://claude.ai/code/artifact/5c4b7b86-7dd2-466b-bcf0-7bc382fd1a1e

Screen: `app/web/index.html` `<head>` — ไม่ใช่หน้าจอในแอป Flutter แต่เป็น HTML head ของ Flutter Web build เดียวที่ทุกลิงก์ (`wynos.online`) ใช้ร่วมกัน (ไม่มี server-side rendering ต่อโพสต์ — ขอบเขตของ WYN-113 คือ site-wide card เดียว ไม่ใช่ per-post dynamic OG)

Purpose: ให้ลิงก์ `wynos.online` ที่ถูกแชร์ไปที่ไหนก็ตาม (Facebook/LINE/Discord/X) ขึ้น preview card ที่มีรูป+ชื่อ+คำอธิบายจริง แทนที่จะไม่มี preview เลย — ตรงกับปัญหาที่ตรวจพบจริงจากโค้ด (ไม่มี `og:*`/`twitter:*` meta tag ใดๆ ใน `index.html` ปัจจุบัน)

User Flow: ไม่มี user flow ใหม่ในแอป — ผลกระทบเกิดที่ "นอกแอป" ล้วนๆ (สิ่งที่แพลตฟอร์มโซเชียลอื่นแสดงตอน render ลิงก์) ไม่มีหน้าจอ ปุ่ม หรือ state ใดในแอปเปลี่ยนแปลง

Components:
- 8 meta tags ใหม่ใน `<head>`: `og:title`, `og:description`, `og:image`, `og:url`, `og:type`, `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`
- Asset ใหม่ 1 ไฟล์: preview image ขนาด 1200×630px (`app/web/`) — ไม่ใช่ component ในแอป ไม่ต้องผ่าน Flutter widget tree ใดๆ

**ตัวเลือกภาพ (ดู mockup เต็มในลิงก์ Artifact ด้านบน — ต้องดูก่อนตัดสินใจ ไม่ใช่แค่คำอธิบายนี้)**

| | ตัวเลือก A — Paper | ตัวเลือก B — Ink (แนะนำ) |
|---|---|---|
| พื้นหลัง | `paper` `#FFFFFF` | `ink` `#12120F` |
| Wordmark "WYNOS" | `ink` `#12120F` | `paper` `#FFFFFF` |
| Logomark | `app/assets/images/wynos_logo_mark.png` สีเดิม | เวอร์ชันกลับสี (ดำ→ขาว) ของไฟล์เดียวกัน |
| เส้นคั่น + tagline accent | `sapphire` `#1B3A6B` | `sapphire` `#1B3A6B` |
| เหตุผลที่แนะนำ B | — | ฟีดของ Facebook/LINE ส่วนใหญ่เป็นการ์ดพื้นขาวอยู่แล้ว การ์ดพื้นเข้มสะดุดตากว่าเมื่อเลื่อนผ่าน ช่วยอัตราคลิกได้จริงตามหลัก social-share ทั่วไป โดยไม่ต้องเปลี่ยนสีปุ่ม/พื้นผิวในแอปเลยแม้แต่จุดเดียว (คนละพื้นผิวกับ UI จริงของแอปที่ต้องเป็น paper ตามที่ Founder ยืนยันไว้แล้ว WYN-105) |

ทั้งสองตัวเลือกใช้ **เฉพาะ 5 token ที่มีอยู่จริงใน `wyn_colors.dart`** (ink/paper/sapphire/graphite/hairline) ไม่มีการผสม/สร้าง tint ใหม่ ไม่ผิดกติกา SPEC.md Section 0/1 ("ห้ามใช้สีที่ไม่อยู่ในรายการ" / "ห้ามประดิษฐ์ shade ใหม่")

Interactions: ไม่มี — เป็น static image + static meta text ล้วนๆ ไม่มี interactive element

States: ไม่มี state ใหม่ (ไม่มี loading/error/empty สำหรับ meta tag แบบนี้)

Responsive Behavior: preview card render โดยแพลตฟอร์มปลายทางเอง (Facebook/LINE กำหนด layout เอง) — สิ่งที่ WYN ควบคุมได้คือให้ภาพเป็นสัดส่วน 1200:630 (มาตรฐานที่ทุกแพลตฟอร์มหลักตัดพอดีไม่เพี้ยน) เท่านั้น

Accessibility: ไม่กระทบ accessibility ของแอป (ไม่ใช่ Flutter widget) — รูป social-preview เองไม่ต้องมี alt text ตามสเปก Open Graph มาตรฐาน (แพลตฟอร์มปลายทางไม่อ่าน alt ของ og:image)

Design Rules ที่ยึดในงานนี้:
- ห้ามใช้สีที่ไม่อยู่ใน `wyn_colors.dart` (SPEC.md Section 0) — ทำตามแล้วทั้ง 2 ตัวเลือก
- ห้ามใช้ Liquid Glass/พื้นผิวโปร่งแสง (design-principles.md) — ไม่มีการใช้ blur/translucency ในทั้งสองตัวเลือก เป็นพื้นทึบล้วน
- ฟอนต์: ใช้ system font stack เดียวกับที่ Founder ยืนยันไว้สำหรับแอป (2026-09-03, WYN-107: "ฟอนต์ระบบ ไม่ใช่ Fraunces/Inter") — ไม่แนะนำฟอนต์แบรนด์ใหม่สำหรับ asset นี้ด้วยเหตุผลเดียวกัน
- ตามบทเรียน 2026-09-02 (WYN-095): สีทั้งหมดอ่านจาก `wyn_colors.dart` ไฟล์จริง ไม่ใช้ `ds-001-color-system.md`/`design-principles.md` เก่าที่ยังพูดถึงสีน้ำเงิน `#2D6CDF` ที่ถูก re-brand เป็น Sapphire ไปแล้ว
- ตามคำสั่ง Founder 2026-09-03 ("ต้องเห็นรูปก่อนเขียนโค้ดทุกครั้ง"): ส่ง Artifact มอคอัพให้ดูก่อนแล้ว **ยังไม่ส่งต่อ AI Coding จนกว่า Founder จะเลือก**

Handoff: **ยังไม่ส่งต่อ AI Coding** — รอ Founder ตัดสินใจ 2 เรื่องก่อน (ดูรายละเอียดใน `.wyn/tasks/active/WYN-113-og-share-preview-cards.md`):
1. เลือกโทนสี A (Paper) หรือ B (Ink, แนะนำ)
2. อนุมัติข้อความ `og:title`/`og:description` ที่เสนอ หรือแก้คำ

พอ Founder ตอบแล้ว ส่งต่อ AI Coding ทำตาม Requirements ของ Product spec ได้ทันที (งานเล็ก ไม่มี migration ไม่มี schema เปลี่ยน แก้ไฟล์เดียว + เพิ่ม asset เดียว)
