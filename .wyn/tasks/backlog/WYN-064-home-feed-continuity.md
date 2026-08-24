# Product Task — WYN-064

Status: backlog
Owner: AI Product Manager

Feature: Home Feed — Continuous Scroll + Instant Update หลังโพสต์สำเร็จ

Goal: ทำให้ Home Feed รู้สึกเหมือน Social Feed จริง — ไถต่อเนื่องไม่มีช่องว่างผิดปกติ และเมื่อโพสต์ Drop สำเร็จ ต้องเห็นโพสต์ใหม่ขึ้นบนสุดทันทีโดยไม่ต้อง refresh เอง

Target User: ผู้ใช้ WYNOS ทุกคนที่เปิด Home เป็นหน้าแรก

Problem: จากการตรวจโค้ดปัจจุบัน (WYN-063 เพิ่งเสร็จและเพิ่งแก้บั๊ก RPC ที่ทำให้ Home โหลดไม่ได้ในวันนี้) `HomeRepository.fetchRankedFeed()` เรียก `get_wynos_ranked_feed()` แล้ว แต่ยังไม่ได้ตรวจยืนยันว่า flow "สร้าง Drop สำเร็จ → ปิด Composer → Feed insert โพสต์ใหม่ไว้บนสุดทันที" ทำงานถูกต้องอยู่หรือไม่ (อาจต้องกลับไป fetch หน้าแรกใหม่ทั้งหมดหลังปิด Composer) — Founder รายงานว่าก่อนหน้านี้เจอปัญหา "โหลด Home ไม่สำเร็จ" ซึ่งแก้ที่ระดับ backend ไปแล้ว (deploy วันนี้) แต่ยังไม่มีใครยืนยัน UX ของการสร้างโพสต์ใหม่ปลายทาง client

Requirements:
- R1. เปิด Home ต้องเห็นหลายโพสต์ต่อเนื่อง ไม่มีพื้นที่ว่างขนาดใหญ่ระหว่างการ์ด ระยะห่างระหว่างการ์ดสม่ำเสมอตาม design system เดิม
- R2. Scroll ลงสุดของหน้าปัจจุบันต้องโหลดหน้าถัดไปอัตโนมัติ (infinite scroll/pagination ต่อจากที่ `get_wynos_ranked_feed()` มีอยู่แล้ว — ตรวจสอบว่า pagination ทำงานจริงกับ RPC ใหม่นี้ ไม่ใช่แค่หน้าแรก)
- R3. เมื่อสร้าง Drop สำเร็จจาก Composer ที่เปิดจาก Home: ปิด Composer → Feed เพิ่มโพสต์ใหม่ไว้บนสุดทันที → ไม่ต้องให้ผู้ใช้ pull-to-refresh เอง (วิธีที่แนะนำ: หลังสร้างสำเร็จ ให้ prepend Drop ที่เพิ่ง insert เข้า local state ของ Home ทันทีแบบ optimistic แทนการ query `get_wynos_ranked_feed()` ใหม่ทั้งหมด เพราะ ranking algorithm อาจไม่จัดให้โพสต์ใหม่ของตัวเองอยู่บนสุดเสมอ — ต้อง "pin" โพสต์ที่เพิ่งสร้างเองไว้บนสุดของ session ปัจจุบันแยกจาก ranking score)
- R4. Feed ต้องแสดงทุกประเภทเนื้อหาที่ `get_wynos_ranked_feed()` คืนมาได้ถูกต้อง (Drop ทุกแบบตาม WYN-065, ไม่ใช่แค่ Drop ที่มีรูป)

Acceptance Criteria:
- [ ] เปิด Home เห็น Feed ไถต่อเนื่อง ไม่มีช่องว่างผิดปกติระหว่างการ์ด
- [ ] Scroll ถึงล่างสุดโหลดหน้าถัดไปได้จริง ไม่ค้าง ไม่ error
- [ ] สร้าง Drop สำเร็จจาก Home → Composer ปิด → เห็นโพสต์ใหม่บนสุดทันทีโดยไม่ refresh มือ
- [ ] Regression: Home feed เดิม (WYN-007/WYN-018/WYN-063) ยังทำงานถูกต้องทุกจุด ไม่มี route/feature เดิมพัง

Dependencies: ต่อยอดจาก WYN-063 (ranked feed RPC เพิ่งแก้บั๊กใน production วันนี้ 2026-08-24) — ต้องตรวจ `HomeRepository`/`HomeFeedScreen` ปัจจุบันก่อนแก้เพื่อไม่ให้ชนกับ ranking algorithm ที่เพิ่งเสร็จ

Priority: สูง — เป็น core UX ของหน้าแรกที่ผู้ใช้ทุกคนเจอ และ Founder เพิ่งเจอบั๊กจริงบนหน้านี้

Risks: ถ้า "pin โพสต์ใหม่ไว้บนสุด" ทำไม่ถูกจุด อาจขัดกับ ranking algorithm ของ WYN-063 (Personalized/Following/Engagement/Trending/Recency/Discovery weights) — ต้องออกแบบให้ pin เป็นแค่ optimistic UI ชั่วคราวจนกว่าจะ refresh รอบถัดไป ไม่ใช่เปลี่ยน ranking score จริงใน DB

Recommendation: ทำ optimistic prepend ที่ client เท่านั้น (ไม่แตะ ranking algorithm/backend) เพื่อความเร็วและไม่เสี่ยงต่อของที่เพิ่ง QA ผ่านและ deploy ไปแล้ว

Handoff: AI Design ออกแบบ pagination/loading state + optimistic prepend behavior ให้ชัดเจน ก่อนส่ง AI Coding
