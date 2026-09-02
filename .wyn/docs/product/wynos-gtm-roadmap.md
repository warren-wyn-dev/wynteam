# WYNOS Go-To-Market Roadmap (Beta1 → Public Launch)

Owner: AI Product Manager
Created: 2026-09-02
Status: PROPOSED — รอ Founder ยืนยัน/ปรับก่อนเริ่ม Phase 1

## บริบท (ทำไมต้องมี Roadmap นี้)

Founder แจ้งว่า `https://wynos.online` ใช้งานได้จริงแล้วแต่ "ไม่มีคนรู้จัก" เอกสารนี้วางลำดับขั้นตอนเพื่อสร้างฐานผู้ใช้กลุ่มแรกอย่างปลอดภัยและวัดผลได้ ก่อนขยายวงกว้าง

**ข้อจำกัดจริงที่ต้องคำนึงถึงตอนนี้** (ตรวจสอบจาก `.wyn/company/CONTEXT.md`/`RELEASE_NOTES.md` แล้ว ไม่ใช่การเดา):

1. **เอกสารกฎหมาย (ข้อกำหนดการใช้งาน/ความเป็นส่วนตัว) ยังเป็น placeholder ที่ทนายยังไม่ตรวจ** — แปะ "BETA" ไว้ที่หน้า Welcome แล้ว แต่ยังไม่ควรดันคนแปลกหน้าจำนวนมากเข้าระบบจนกว่าจะผ่านทนาย
2. **ไม่มีระบบ analytics/session tracking เลยในระบบ** (ยืนยันจาก scope ของ WYN-050 Admin Dashboard ที่ต้องเลื่อน DAU/WAU/MAU ให้เป็น proxy จาก action แทน) — ตอนนี้เราวัด "ช่องทางไหนได้ผล" ไม่ได้เลยถ้าไม่เพิ่มอะไรก่อน
3. **มีแค่ Flutter Web (`wynos.online`) — ยังไม่มี native mobile app** (ไม่มี TestFlight/Play Store, ไม่มี google-services.json/GoogleService-Info.plist, ไม่มี Android SDK/Xcode ใน environment นี้) — ผลคือแจกผ่าน App Store/Play Store ไม่ได้ในตอนนี้
4. **ยังไม่มีระบบ invite/referral** — วัด viral loop หรือควบคุมอัตราการไหลเข้าของผู้ใช้ใหม่ไม่ได้
5. **Push Notification code พร้อมแต่รอ Firebase project จริง** — re-engagement หลัง user เข้ามาแล้วยังทำไม่ได้เต็มที่
6. ทีมตอนนี้คือ Founder + AI team เท่านั้น ไม่มีข้อมูลงบการตลาด (UNKNOWN — ต้องถาม Founder)

ข้อ 1-2 คือ **blocker จริง** ที่ต้องแก้ก่อนโปรโมทวงกว้าง ข้อ 3-5 เป็นข้อจำกัดที่กำหนดว่า Phase ไหนทำอะไรได้บ้าง

---

## Phase 0 — Readiness Gate (ก่อนเริ่มดึงคนนอกเข้ามาเลย)

Feature: Go-To-Market Readiness (Legal + Measurement)
Goal: ปิดความเสี่ยงทางกฎหมายและทำให้วัดผล GTM ได้ ก่อนใช้แรง/เงินโปรโมท
Target User: N/A (internal readiness)
Problem: ถ้าเริ่มโปรโมทตอนนี้ (ก) เสี่ยงปัญหาข้อพิพาท/ข้อมูลผู้ใช้เพราะเอกสารกฎหมายไม่ผูกพันจริง (ข) ไม่รู้เลยว่าใครมาจากช่องทางไหน ใคร retain ใคร churn — เสียโอกาสเรียนรู้จากรอบแรกที่ทำไปแล้ว
Requirements:
- เอกสารกฎหมาย (ToS/Privacy/Community Guidelines) ผ่านทนายจริง — **Founder action, ทีม AI ทำแทนไม่ได้**
- Baseline product analytics ขั้นต่ำ: page/screen view, signup started/completed, core action แรก (Drop/Pop/Club post แรก), retention cohort พื้นฐาน (ดู WYN-077 ด้านล่าง)
- ตัดสินใจ: จะใช้ third-party analytics (เช่น PostHog/Mixpanel/Firebase Analytics) หรือ event log เองใน Supabase — ต้องขออนุมัติ Founder เพราะเป็นการเพิ่ม dependency/data ที่ user data ไหลไป (เข้าข่าย "ความปลอดภัย" ใน RULES.md)
Acceptance Criteria:
- ทนายยืนยันเอกสารกฎหมายใช้งานได้จริงแล้ว (หรือ Founder ตัดสินใจรับความเสี่ยงต่อโดยรู้ตัว — ต้องบันทึกใน `.wyn/company/APPROVALS.md`)
- มี dashboard/ทาง track ได้อย่างน้อย: จำนวน signup ต่อวัน, D1/D7 retention, core action rate
Dependencies: WYN-077 (Analytics baseline, backlog)
Priority: **P0 — Blocking** (Phase 1 เริ่มได้โดยไม่ต้องรอ analytics 100% แต่ห้ามเข้า Phase 3 Public Launch จนกว่าทั้งสองข้อจะผ่าน)
Risks: เลื่อนตารางโปรโมท เพราะรอทนาย — ยอมรับได้ ดีกว่าความเสี่ยงทางกฎหมาย/ข้อมูลผู้ใช้
Recommendation: เริ่ม Phase 1 (closed beta วงเล็กมาก คนที่ Founder รู้จักโดยตรง) ได้ทันทีคู่ขนานกับการรอทนาย เพราะความเสี่ยงต่ำ (คนรู้จัก ไม่ใช่ public) แต่ **ห้ามเข้า Phase 2/3 จนกว่า Phase 0 จะผ่านทั้งสองข้อ**
Handoff: WYN-077 → AI Design → AI Coding → AI QA & Security ตาม workflow ปกติ

---

## Phase 1 — Closed Seed Beta (คนรู้จักโดยตรง, เป้าหมาย 50-300 คน)

Feature: Invite-Only Closed Beta
Goal: หา bug จริงจากการใช้งานจริงนอก dev, เก็บ feedback เชิงคุณภาพ, สร้าง content เริ่มต้นให้แอปไม่ว่างเปล่าตอนคนกลุ่มถัดไปเข้ามา
Target User: เครือข่ายส่วนตัวของ Founder/ทีม + ชุมชน niche เดียวที่ตรงกับ target user (Gen Z) มากที่สุด (Founder เลือก — ตัวอย่าง: กลุ่มเพื่อนมหาวิทยาลัย, กลุ่มแฟนคลับ/fandom, กลุ่มงานอดิเรกเฉพาะทาง)
Problem: เปิด public ตรงๆ ตอนนี้เสี่ยงทั้งกฎหมาย (Phase 0) และเสี่ยง "empty app" — คนใหม่เข้ามาเจอ feed ว่าง ไม่มีใครโพสต์ ไม่กลับมาอีก
Requirements:
- Content seeding: ก่อนเชิญคนกลุ่มแรกเข้า ให้ Founder+ทีมโพสต์ Drop/Pop/สร้าง Club อย่างน้อย 1 Club active ก่อน เพื่อให้มี "ชีวิต" ในแอปตั้งแต่วันแรก
- Onboarding message ตรงไปตรงมาว่านี่คือ Beta ต้องการ feedback (ตั้งความคาดหวังถูกตั้งแต่ต้น)
- ช่องทางเก็บ feedback ที่ทำได้จริงตอนนี้โดยไม่ต้องรอโค้ดใหม่: ฟีเจอร์ Report ที่มีอยู่แล้ว + ถามตรงๆ ผ่าน Chat/กลุ่มปิด (Discord/LINE) คู่ขนาน
Acceptance Criteria:
- มีผู้ใช้จริงอย่างน้อย 50 คนใช้งาน 7 วันติดต่อกัน
- เก็บ feedback ได้จากอย่างน้อย 20 คน (เชิงคุณภาพพอ ไม่ต้องรอ analytics เต็มระบบ)
- ไม่มีบั๊ก Critical/Major ที่ block การใช้งานหลัก (Drop/Pop/Club/Chat/Follow) ค้างเกิน 48 ชม.
Dependencies: Phase 0 (เฉพาะส่วน "เริ่มคู่ขนานได้" — วงเล็กพอที่ไม่ต้องรอทนาย 100%)
Priority: P0 (ทำได้เลย)
Risks: กลุ่มเล็กเกินไปอาจไม่สะท้อน behavior จริงของ mass user — ยอมรับได้เพราะเป้าหมาย Phase นี้คือ bug/feedback ไม่ใช่ growth
Recommendation: เริ่มทันที ไม่ต้องรอ WYN-077/078 เสร็จ เพราะกลุ่มเล็กและปิด ควบคุมความเสี่ยงได้ด้วยจำนวนคนเอง
Handoff: Founder ดำเนินการเชิญเอง (ไม่ใช่งาน AI Coding) — AI Product Manager ติดตาม feedback แล้วแปลงเป็น task บั๊ก/ฟีเจอร์เข้า backlog ตามปกติ

---

## Phase 2 — Community Soft Launch (ขยายใน niche community เฉพาะกลุ่ม)

Feature: Single-Community Soft Launch
Goal: ทดสอบว่าแอปรับคนที่ "ไม่รู้จัก Founder โดยตรง" ได้ไหม ก่อนเปิด public เต็มรูปแบบ
Target User: ชุมชน Gen Z ไทย 1 กลุ่มที่ตรง niche ที่สุด (เลือกจาก Phase 1 feedback ว่ากลุ่มไหน engage ดีที่สุด) เช่น Facebook Group/Discord/LINE OpenChat/X (Twitter) fandom เฉพาะทาง — **เลือกทีละกลุ่ม อย่าเปิดหลายกลุ่มพร้อมกัน** เพื่อแยกผลแต่ละช่องทางออกจากกันได้
Problem: Phase 1 กลุ่มเล็กเกินไปจะไม่เห็น pattern การ churn/retention จริงของคนแปลกหน้า
Requirements:
- WYN-078 (Invite/Referral system) ควรเสร็จก่อน Phase นี้ เพื่อควบคุมอัตราคนเข้าใหม่และวัด viral coefficient ได้
- WYN-077 (Analytics baseline) ต้องเสร็จแล้วเพื่อวัดผลจริง
- ยังคง invite-gated ไว้ (จำกัดจำนวน ไม่เปิด signup อิสระ)
Acceptance Criteria:
- Retention D7 ของกลุ่มนี้ไม่ต่ำกว่ากลุ่ม Phase 1 อย่างมีนัยสำคัญ (สัญญาณว่า product ยืนได้ด้วยตัวเองไม่ใช่แค่เพราะรู้จัก Founder)
- Viral coefficient วัดได้จริง (กี่ % ของ user เชิญเพื่อนต่ออย่างน้อย 1 คน)
Dependencies: Phase 0 ต้องผ่านครบ (เอกสารกฎหมาย + analytics) เพราะเริ่มมีคนแปลกหน้าเข้าระบบจริง, WYN-077, WYN-078
Priority: P1
Risks: ถ้า Phase 0 (เอกสารกฎหมาย) ยังไม่ผ่าน ไม่ควรเข้า Phase นี้ต่อให้ product พร้อม
Recommendation: รอผลจาก Phase 1 ก่อนเลือกกลุ่มเป้าหมาย อย่าตัดสินใจล่วงหน้า
Handoff: WYN-078 → AI Design → AI Coding → AI QA & Security; ส่วน channel/community selection เป็นการตัดสินใจของ Founder

---

## Phase 3 — Public Launch

Feature: Public Signup + Multi-Channel Test
Goal: เปิดกว้างจริง วัดว่าช่องทางไหน CAC ต่ำสุด/retention ดีสุด เพื่อตัดสินใจลงทุนต่อ
Target User: Gen Z ไทยทั่วไป (ตาม WYN Vision เดิม)
Problem: ยังไม่มีข้อมูลว่าช่องทางไหนคุ้มค่าที่สุดสำหรับ WYNOS โดยเฉพาะ — ต้องทดลองแบบควบคุมงบ ไม่เดา
Requirements:
- ปิด invite-gate เมื่อ Phase 0+2 ผ่านหมดแล้ว
- ทดลองช่องทางแบบงบต่ำ วัดผลแยกกันชัดเจน (UNKNOWN: งบจริงที่ Founder จัดสรรได้ — ต้องถาม): 
  - Organic: SEO พื้นฐานสำหรับ `wynos.online` (title/meta/OG image ให้แชร์ลิงก์แล้วดูดี), เนื้อหาจาก Club ที่ดังใน Phase 1-2 เอามาทำ social proof
  - Micro-influencer/creator seeding ในกลุ่ม niche ที่ตรงกับ Club feature (จุดขาย "สร้างชุมชนของตัวเองได้" ตรงกับ WYN Mission)
  - Paid test เล็กๆ บน TikTok/Instagram (ช่องทางที่ Gen Z ไทยอยู่) — เริ่มงบทดลองต่ำสุดที่วัดผลได้ ก่อนขยาย
- ตัดสินใจเรื่อง native mobile app: ถ้ายังเป็น web-only ตอน Phase 3 ต้องสื่อสารชัดว่า "เข้าผ่านเบราว์เซอร์" ในทุก creative/caption ไม่ให้คนสับสนหา App Store แล้วไม่เจอ
Acceptance Criteria:
- มี CAC ต่อช่องทางที่วัดได้จริงจาก analytics (WYN-077)
- Retention D7 ของ user จาก public launch ไม่ต่ำกว่าเกณฑ์ที่ตั้งจาก Phase 2
Dependencies: Phase 0 ผ่านครบ, Phase 2 เสร็จและมีข้อมูลพอสรุปได้ว่ากลุ่มเป้าหมายไหนดีสุด
Priority: P1 (รอ Phase 0/2 ก่อน)
Risks: ถ้าเปิด public โดยยังไม่มี native app คนที่คาดหวัง app จริงอาจ bounce — ต้อง set expectation ให้ตรง; ถ้าเปิดโดยไม่มี analytics จะเสียเงินโดยไม่รู้ว่าช่องทางไหนได้ผล
Recommendation: **ตัดสินใจเรื่อง native mobile app ให้ชัดก่อนเข้า Phase 3** (ดูคำถามท้ายเอกสาร) เพราะกระทบ message/channel เลือกทั้งหมด
Handoff: Founder ตัดสินใจงบ/channel priority → AI Product Manager ปรับ roadmap ตามข้อมูลจริง

---

## Phase 4 — Scale

Feature: Scale Best-Performing Channel(s)
Goal: ทุ่มทรัพยากรไปช่องทางที่พิสูจน์แล้วจาก Phase 3 แทนการเดา
Target User: ขยายจากกลุ่มที่ retention/CAC ดีที่สุดใน Phase 3
Requirements: ข้อมูลจริงจาก Phase 3 เท่านั้น (ห้ามตัดสินใจล่วงหน้าตอนนี้)
Priority: P2 (ยังไกลเกินจะวางแผนละเอียดตอนนี้)
Recommendation: ยังไม่ต้องวางแผนละเอียดตอนนี้ — กลับมาทำ Phase 4 spec ใหม่เมื่อมีข้อมูล Phase 3 จริง

---

## สรุป — งานที่ทำได้ทันที vs ที่ต้องรอ Founder ตัดสินใจ

**ทำได้ทันที (ไม่ block):**
- Phase 1 closed beta — Founder เริ่มเชิญคนรู้จักได้เลยวันนี้ พร้อม content seeding
- WYN-077 (Analytics baseline) — ส่งเข้า AI Design ต่อได้เลยถ้า Founder อนุมัติแนวทาง (ดูคำถามด้านล่าง)
- WYN-078 (Invite/Referral) — เช่นเดียวกัน

**ต้องรอ Founder ตัดสินใจ/ดำเนินการ (AI ทำแทนไม่ได้):**
1. ส่งเอกสารกฎหมายให้ทนายตรวจ (Phase 0 blocker)
2. เลือกแนวทาง analytics (third-party เช่น PostHog/Firebase Analytics vs เก็บเองใน Supabase) — กระทบเรื่อง user data ไหลไปที่ไหน ต้องขออนุมัติตาม RULES.md
3. ตัดสินใจ native mobile app: จะเร่งทำตอนนี้ (เปิดโอกาส App Store/Play Store) หรือเน้น web-first ต่อไปก่อน
4. งบการตลาดที่มีจริงสำหรับ Phase 3 (ถ้ามี) — ตอนนี้ UNKNOWN
