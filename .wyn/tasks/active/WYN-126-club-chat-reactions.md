# Feature Request — WYN-126

Status: active — Design เสร็จแล้ว, **Coding ห้ามเริ่มจนกว่า WYN-124 สร้างเสร็จก่อนเสมอ**
Owner: AI Product Manager → AI Design

Feature: Reaction ด่วนบนข้อความแชท (❤️😂😮😢🔥👍) ในห้องแชทกลุ่มของ Club (ต่อยอด WYN-124)

Goal: ให้การตอบสนองต่อข้อความในห้องแชทกลุ่มทำได้เร็ว/สนุกแบบ Discord โดยไม่ต้องพิมพ์ตอบทุกครั้ง — ต่างจาก Like บนโพสต์ (มีอยู่แล้ว ใช้กับ post ไม่ใช่ chat message) ตรงที่นี่คือ reaction บนข้อความสด ใส่ได้หลาย emoji ต่อข้อความ ไม่ใช่ toggle เดียวแบบ Like

Target User: สมาชิกในห้องแชทกลุ่มที่อยากตอบรับข้อความเร็วๆ โดยไม่ขัดจังหวะบทสนทนาด้วยข้อความใหม่

Problem: ระบบ interaction บนข้อความแชทตอนนี้ (WYN-031 DM และ WYN-124's design ของ Group Chat) ไม่มีกลไกตอบสนองต่อข้อความเลยนอกจาก reply เต็มรูปแบบ — ในห้องกลุ่มที่มีคนคุยพร้อมกันหลายคน การต้องพิมพ์ตอบทุกครั้งทำให้บทสนทนายาวและอ่านยาก ทั้งที่บางทีแค่อยากส่งสัญญาณสั้นๆ

## Requirements

### R1 — ขอบเขตเฉพาะข้อความในห้องแชทกลุ่ม (WYN-124) เท่านั้น ไม่แตะ DM เดิม
Reaction ผูกกับตารางข้อความของ WYN-124 (`club_chat_messages` หรือชื่อจริงที่ Coding กำหนดตอนนั้น) เท่านั้น **ไม่เพิ่ม column/ตารางใน `public.messages` (DM เดิม)** ตามหลักการเดียวกับที่ WYN-124 เองแยกตารางออกจาก DM ทั้งชุด (WYN-124's R8)

### R2 — ชุด emoji คงที่ ไม่ใช่ emoji picker เต็มรูปแบบ
จำกัดไว้ 5-6 ตัวคงที่ (เช่น ❤️ 😂 😮 😢 🔥 👍) — เหตุผลเดียวกับที่ WYN-123's design ตัดสินใจกับช่อง emoji ของ Channel (ช่องพิมพ์ธรรมดา ไม่ใช่ picker เต็มรูปแบบ) เพื่อคุม complexity ไม่ให้บานปลาย ไม่ใช่ให้พิมพ์/เลือก emoji อิสระ

### R3 — 1 คนใส่ได้หลาย reaction ต่อข้อความ แต่ 1 emoji ต่อข้อความต่อคนแค่ครั้งเดียว
กดซ้ำ = เอาออก (toggle เหมือน Like) — แสดงยอดรวมแยกตาม emoji ใต้ข้อความ (เช่น ❤️ 3  🔥 1) ไม่ใช่ยอดรวมทุก emoji ปนกัน

### R4 — ไม่มีแจ้งเตือนแยกสำหรับ reaction ในรอบนี้ (ตัด scope)
ตรงกับที่ WYN-124 เองตัด mention/read-receipt ออกด้วยเหตุผลคุม complexity เดียวกัน — react ไม่ trigger notification ใหม่ (ต่างจาก `club_post_like` ที่มี notification เพราะเป็นคนละบริบทกับข้อความสดในห้องแชท)

## Acceptance Criteria

1. แตะปุ่ม reaction ที่ข้อความ เลือก emoji จากชุดคงที่ได้ ขึ้นทันที (optimistic update)
2. กด reaction เดิมซ้ำที่ตัวเอง react ไว้แล้ว = เอาออก
3. ยอดรวมต่อ emoji แสดงถูกต้อง อัปเดตเรียลไทม์เมื่อสมาชิกคนอื่น react โดยไม่ต้อง refresh
4. ข้อความใน DM (1-ต่อ-1) ไม่มีปุ่ม reaction นี้เลย ไม่ถูกกระทบแม้แต่จุดเดียว

## Dependencies

- **WYN-124 (Club Group Chat) ต้องสร้างเสร็จก่อนเสมอ** — ผูกกับตารางข้อความของ WYN-124 โดยตรง สร้างก่อนไม่ได้

## Priority

P3 — ต่อท้าย WYN-124 เช่นเดียวกับ WYN-125 (Presence) ลำดับก่อน-หลังระหว่างสองงานนี้ไม่ผูกกัน เลือกทำอันไหนก่อนก็ได้

## Risks

- Realtime fan-out ของ reaction ในห้องที่สมาชิกเยอะ อาจสร้าง event ถี่กว่าข้อความใหม่เฉยๆ (1 ข้อความอาจมี reaction ทยอยเข้ามาหลายสิบครั้ง) — ต้องออกแบบ query/subscription ให้อัปเดตเฉพาะยอดที่เปลี่ยน ไม่ fetch ใหม่ทั้งลิสต์ทุกครั้งที่มี reaction เกิดขึ้น

## Recommendation

ทำพร้อมหรือหลัง WYN-125 (Presence) ก็ได้ ไม่มี dependency ระหว่างกันโดยตรง ทั้งคู่ขึ้นกับ WYN-124 เท่านั้น — ถ้าต้องเลือกลำดับ แนะนำทำ **หลัง WYN-125** เพราะ Presence ใช้ Supabase Realtime Presence ที่มีอยู่แล้ว (effort ต่ำกว่า) ส่วนงานนี้ต้องมีตาราง+RLS ใหม่จริง

## Handoff (Product → Design)

ส่งต่อ **AI Design** ออกแบบ UX ตอนถึงคิว (ตำแหน่งปุ่ม reaction บน bubble, sheet เลือก emoji, การแสดงยอดรวม) — **AI Coding ต้องรอ WYN-124 สร้างเสร็จก่อนเสมอ**

---

## AI Design — ผลงาน (2026-09-06)

Design เต็มรูปแบบอยู่ที่ `.wyn/docs/design/wyn-125-126-club-chat-presence-reactions.md` (รวมกับ WYN-125 ไว้เอกสารเดียว) — quick-reaction bar (6 emoji) โผล่เป็นแถวบนสุดของ sheet เดิม (long-press เดียวกับเมนู ตอบกลับ/ลบ/รายงาน ของ WYN-031) ไม่ใช่ gesture ใหม่, reaction pill ใต้ bubble ใช้ pill style เดิมจาก header ClubPage, tap-pill-to-toggle มิเรอร์ pattern Like/Save เดิมทั้งระบบ, bubble ที่ไม่มีใคร react หน้าตาเหมือนก่อนมีงานนี้ทุกประการ

**Handoff (Design → Coding)**: **ห้ามเริ่มจนกว่า WYN-124 จะสร้างเสร็จก่อนเสมอ** — ยอดรวมต่อ emoji ต้องคำนวณที่ query/RPC ไม่ใช่นับดิบฝั่ง client
