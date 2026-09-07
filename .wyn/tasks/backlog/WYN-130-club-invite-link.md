# Product Task — WYN-130

Status: backlog
Owner: AI Product Manager

Feature: Club Invite Link (generate/revoke, expiration, max-uses)

Goal: ให้ Owner/Admin ของ Club สร้างลิงก์เชิญที่แชร์ได้ทั่วไป (นอกแอปก็ได้ — เช่น วางใน bio โซเชียลอื่น, ส่งผ่านแชทนอกแอป) พร้อมกำหนด**วันหมดอายุ**และ**จำนวนครั้งใช้งานสูงสุด**ได้ แทนที่การเชิญแบบเลือกทีละ follower อย่างเดียวที่มีอยู่ตอนนี้ (WYN-123) — ตรงกับสเปกข้อ 16 ที่ Founder ระบุ (Invite Link, Generate, Revoke, Expiration, Maximum Uses, Invite Tracking)

Target User: Owner/Admin ของ Club (สร้าง/จัดการลิงก์), ผู้ใช้ทั่วไปที่ได้รับลิงก์ (ทั้งที่เป็นสมาชิก WYN อยู่แล้วและคนที่ยังไม่เคยใช้แอป — ใช้ deep-link routing ที่ WYN-119 วางไว้)

Problem: ทางเดียวที่มีตอนนี้ในการชวนคนเข้า Club คือเลือกจาก follower list ทีละคนในแอป (WYN-123/124) — ใช้ไม่ได้เลยกับคนที่ยังไม่ follow เรา/ยังไม่ได้ใช้ WYN หรือกรณี Owner อยากแปะลิงก์ประชาสัมพันธ์ Club ไว้ที่อื่น (bio Instagram, group Line ภายนอก ฯลฯ) — deep-link routing ของ Club มีแล้ว (WYN-119) แต่เป็นแค่ "ลิงก์ไปหน้า Club เฉยๆ" ไม่มีแนวคิดเรื่อง "invite code" ที่ track ได้/จำกัดอายุ/จำกัดจำนวนใช้เลยในฐานข้อมูล

Requirements:
- Owner/Admin สร้างลิงก์เชิญได้จากหน้า Club Settings: เลือกวันหมดอายุ (ตัวเลือก: ไม่มีวันหมดอายุ / 1 วัน / 7 วัน / 30 วัน) และจำนวนครั้งใช้งานสูงสุด (ตัวเลือก: ไม่จำกัด / 10 / 50 / 100) — สร้างได้หลายลิงก์พร้อมกัน (เช่น ลิงก์นึงไว้แปะ bio, อีกลิงก์ไว้ให้เพื่อนสนิทเฉพาะกลุ่ม) แต่ละลิงก์มี unique code
- Owner/Admin เห็นรายการลิงก์ที่ยังใช้งานอยู่ทั้งหมดของ Club ตัวเอง พร้อมจำนวนครั้งที่ถูกใช้ไปแล้ว/สร้างเมื่อไหร่/ใครสร้าง — **Revoke** ลิงก์ใดก็ได้ทันที (ใช้ต่อไม่ได้อีกเลยหลัง revoke)
- ลิงก์ที่หมดอายุ/ถูก revoke/ใช้ครบจำนวนแล้ว → เปิดแล้วเจอหน้าแจ้งเตือนสุภาพ (เช่น "ลิงก์เชิญนี้หมดอายุแล้ว") ไม่ crash ไม่เด้ง error ดิบ
- **การตัดสินใจสำคัญที่ต้องยืนยันกับ Founder ก่อน Design ล็อกพฤติกรรม**: สำหรับ Private Club — การกดลิงก์เชิญที่ valid ควรทำให้ **เข้าร่วมได้ทันทีโดยไม่ต้องผ่าน Join Request/Approve** (เพราะตัวลิงก์เชิญคือการอนุมัติล่วงหน้าโดย Owner/Admin อยู่แล้วในตัว ตรงกับ pattern ของ Discord invite link) — เปลี่ยน semantics ของ "Private" เดิมที่ต้องขออนุมัติทุกครั้ง จึงต้องยืนยันแนวทางนี้ชัดเจนก่อนเริ่ม Design
- Track ว่าสมาชิกใหม่แต่ละคน join ผ่านลิงก์ไหน (ต่อยอด Owner Insights, WYN-117, เพิ่มมิติ "ที่มาของสมาชิกใหม่" ได้ในอนาคตถ้า Founder ต้องการ — ไม่บังคับสร้าง UI แสดงผลรอบนี้ แค่เก็บ data ไว้ไม่ให้ต้อง migrate ทีหลัง)

Acceptance Criteria:
- [ ] Owner/Admin สร้างลิงก์เชิญพร้อมกำหนดวันหมดอายุ+จำนวนครั้งใช้งานได้จริง
- [ ] เปิดลิงก์ที่ valid → เข้าเห็นหน้า Club ได้ทันที (Public: join ได้เลย / Private: ตามการตัดสินใจที่ยืนยันแล้วด้านบน)
- [ ] ลิงก์หมดอายุ/revoke/ครบจำนวน → แสดงข้อความแจ้งเตือนสุภาพ ไม่ error ดิบ
- [ ] Owner/Admin revoke ลิงก์ได้ทันที และลิงก์นั้นใช้ไม่ได้อีกเลย
- [ ] Owner/Admin เห็นจำนวนครั้งที่ลิงก์แต่ละอันถูกใช้ไปแล้ว

Dependencies: WYN-119 (Club Deep Linking — ใช้ routing infra เดิม), WYN-014 (Club Core)

Priority: P2 — เป็น growth lever ที่มีคุณค่า แต่ WYN-123 (เชิญ follower ในแอป) ครอบคลุม use case หลักไปแล้วระดับหนึ่ง ไม่ใช่ blocker ของอะไร

Risks: การตัดสินใจ "Private Club + Invite Link = join ทันทีไม่ผ่าน approve" เป็นการเปลี่ยน security semantics ของคำว่า "Private" — ถ้าลิงก์หลุดไปที่สาธารณะ (เช่น ถูก re-share) คนแปลกหน้าเข้า Private Club ได้ทันทีโดย Owner ไม่ทันรู้ตัว ต้องมี UX ที่ชัดเจนเตือน Owner ตอนสร้างลิงก์ (เช่น "ใครก็ตามที่มีลิงก์นี้เข้าร่วมได้ทันที") + ทำให้ revoke ทำได้ง่าย/เร็ว เพื่อบรรเทาความเสี่ยง

Recommendation: อนุมัติ scope ได้ แต่ต้องให้ Founder ยืนยัน "Private Club + Invite Link" semantics ก่อนส่งต่อ AI Design (ไม่ใช่ Major Architecture แต่เป็น security-relevant policy decision ตาม RULES.md)

Handoff: รอ Founder ยืนยัน priority ของ Phase A ทั้งชุดก่อน (ดู `.wyn/docs/product/wyn-social-3-domain-architecture-roadmap.md`) แล้วจึงส่งต่อ AI Design พร้อมคำตอบเรื่อง Private Club semantics
