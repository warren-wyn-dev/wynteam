# Product Task — WYN-130

Status: coding-complete รอ QA (2026-09-07)
Owner: AI Design → AI Coding

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

## AI Design Output (2026-09-07)

Design spec เต็มที่ `.wyn/docs/design/wyn-130-club-invite-link.md` — ตรวจ schema จริงของ `clubs`/`club_members`/`club_role()`/deep-linking (WYN-119)/`guest_gate.dart` แล้ว ยืนยันว่า **ทั้งสองทางเลือก (A/B) implement ได้โดยไม่กระทบ RLS/schema เดิมเลย** เพราะ RPC ใหม่ทั้งหมด (security definer) bypass `club_members`'s INSERT policy เดิมอยู่แล้ว ต่างกันแค่ 1 บรรทัดในฟังก์ชัน `redeem_club_invite_link()` — **นี่คือ product/security policy decision ล้วนๆ ไม่ใช่ทาง technical**

### ⚠️ คำถามที่ต้องการคำตอบ Founder ก่อน lock — Private Club + Invite Link

เมื่อกดลิงก์เชิญที่ valid สำหรับ **Private Club** ควรเกิดอะไรขึ้น:

- **ทางเลือก A** — เข้าร่วมทันที ข้าม Join Request/Approve เลย (pattern Discord invite link, ตรงกับที่ Product Task แนะนำไว้) — เร็ว/ลื่นกว่า แต่เปลี่ยน security semantics ของ "Private" เดิม (ถ้าลิงก์หลุดไปสาธารณะ คนแปลกหน้าเข้าได้ทันทีก่อน Owner ทันรู้ตัว)
- **ทางเลือก B** — ยังคงต้องผ่าน Join Request/Approve เหมือนเดิมทุกประการ (ลิงก์แค่พาไปหน้า preview + ให้ข้อมูล "มาจากลิงก์ไหน" ช่วย Owner ตัดสินใจไวขึ้นในคิวอนุมัติ) — ไม่เปลี่ยน semantics เดิมเลย ปลอดภัยกว่า แต่ growth loop ช้ากว่า/ไม่ตรง mental model ที่คนคุ้นเคยจาก Discord

รายละเอียดข้อดี/ข้อเสียเต็มอยู่ในเอกสาร design — **AI Design ไม่มี tool ยิง popup คำถามแบบเลือกตอบ (AskUserQuestion) ในสภาพแวดล้อมนี้ จึงเขียนคำถามนี้ไว้ในเอกสารและแจ้ง Founder ตรงๆ แทน** ตาม RULES.md

หมายเหตุ: Public Club ไม่มีคำถามนี้เลย (join ทันทีเหมือนเดิมทั้งสองทาง) — กระทบเฉพาะ Private Club เท่านั้น ถ้าเลือกทางเลือก A ยังมีคำถามรอง (edge case "ลิงก์ควรอัปเกรด pending request เดิมเป็น approved ทันทีไหม") ระบุไว้ในเอกสารด้วย

### สรุป schema/UI ที่พร้อมแล้ว (ไม่ต้องรอคำตอบข้างบนเพื่อเริ่มเข้าใจ scope)

- ตารางใหม่ `club_invite_links` (code/expires_at/max_uses/use_count/revoked_at) + `club_invite_link_uses` (attribution tracking, ยังไม่มี UI แสดงผลตาม Requirement)
- RPC: `create_club_invite_link()`, `revoke_club_invite_link()` (Owner/Admin เท่านั้น, ผ่าน `club_role()` เดิม), `preview_club_invite_link()` (public, ใช้ตอนเปิดหน้า preview รวม guest), `redeem_club_invite_link()` (จุดที่ต้องรอคำตอบ A/B, มี `for update` กัน race บน max-uses)
- UI: แถวใหม่ "ลิงก์เชิญ" ใน More menu ของ Club (gate `role.canManageClub` เดิม) → `ClubInviteLinksScreen` (สร้าง/ดูรายการ/revoke) + หน้าใหม่ `ClubInvitePreviewScreen` (เปิดจากลิงก์ผ่าน deep-link pattern ใหม่ `/club-invite/:code`) — reuse `requireRealAccount()`/Anonymous Sign-In เดิมสำหรับ guest ทั้งหมด ไม่สร้างกลไกใหม่
- มี UI ใหม่จริง 2 หน้า → ต้องมี visual mockup ตามกติกา "ขอดูรูปก่อนเขียนโค้ด" — session นี้ไม่มีเครื่องมือสร้างภาพ ทำได้แค่ wireframe ข้อความในเอกสาร
- แนะนำ gate ด้วย Staged Rollout (WYN-125)

Handoff: **ห้าม AI Coding เริ่มจนกว่า Founder จะตอบคำถาม A/B ข้างบน** + ยืนยันเรื่อง visual mockup เหมือน 3 task อื่นใน Phase A นี้

Founder ยืนยันแล้ว 2026-09-07 (ทางเลือก A + wireframe ข้อความ, ดู `.wyn/company/DECISIONS.md` entry "[2026-09-07] Social 3-Domain Roadmap") — ไม่มีจุดค้าง ส่งต่อ AI Coding

## AI Coding Output (2026-09-07)

Implementation ครบตาม design spec — ใช้ SQL จากเอกสาร design ตรงๆ ตามที่ระบุไว้ (ไม่มีจุดกำกวมด้าน technical):

- **Schema**: `public.club_invite_links` + `public.club_invite_link_uses` + RPC 4 ตัว (`create_club_invite_link`/`revoke_club_invite_link`/`preview_club_invite_link`/`redeem_club_invite_link`) ใน `supabase/schema.sql` + `supabase/migrations_wyn130_club_invite_link.sql` (standalone migration ใหม่ตาม convention) — `redeem_club_invite_link()` lock เป็นทางเลือก A ตามที่ Founder ยืนยัน (join ทันทีแม้ Private Club, auto-upgrade pending เดิมเป็น approved)
- **Flutter data layer**: `ClubInviteLink`/`ClubInvitePreview` model ใหม่ (`club_invite_link.dart`), `ClubRepository` เพิ่ม `createInviteLink()`/`revokeInviteLink()`/`fetchInviteLinks()`/`previewInviteLink()` (sign icon URL เองก่อนคืนค่า)/`redeemInviteLink()`
- **Flutter UI**: `ClubInviteLinksScreen` ใหม่ (สร้าง/ดูรายการ/revoke, banner เตือนสีเหลือง/ส้มอ่อนสำหรับ Private Club, radio-picker sheet สำหรับวันหมดอายุ/จำนวนครั้งใช้งาน — ใช้ pseudo-radio pattern เดิมของ `settings_screen.dart` ไม่ใช้ `RadioListTile` เพราะ deprecated ใน Flutter version นี้), `ClubInvitePreviewScreen` ใหม่ (preview + ปุ่มเข้าร่วม + 5 สถานะ error state) — `club_page.dart`'s More menu เพิ่มแถว "ลิงก์เชิญ" (gate ด้วย `role.canManageClub` เดิม + `isDeveloperAccount()` ใหม่)
- **Deep Link**: `DeepLinkService` เพิ่ม pattern `/club-invite/:code` → `ClubInvitePreviewScreen` (รวมอยู่ใน `hasContentPath()` เพื่อให้ guest auto-sign-in แบบ anonymous ตามกลไกเดิมของ WYN-119 ด้วย)
- **Staged Rollout**: `isDeveloperAccount() == false` ทำให้ (1) ไม่เห็นแถว "ลิงก์เชิญ" ใน More menu เลย (2) เปิดลิงก์ `/club-invite/:code` fallback เงียบๆ เหมือน path ที่ไม่รู้จัก ไม่พาไปหน้า preview จริง — ตามที่ Design ระบุ
- **แก้บั๊กใน SQL ต้นฉบับ**: ไม่พบ — ใช้ SQL จาก design doc ตรงๆ ทั้งหมดโดยไม่ต้องแก้ไข (verify แล้วตรงกับ schema จริงของ `clubs`/`club_members`/`club_role()` ที่ตรวจสอบก่อนเริ่ม)
- **Test ใหม่**: `club_invite_links_screen_test.dart` (8 tests: empty state, list rendering, privacy banner, expired/dimmed display, create flow, revoke flow + confirm dialog, revoke failure, copy-to-clipboard), `club_invite_preview_screen_test.dart` (9 tests: valid link render, private badge, join success → navigate to ClubPage, join failure, ทั้ง 4 invalid status + preview fetch failure fallback), `club_invite_link_test.dart` (10 tests: model fromMap/computed getters), `club_page_test.dart` +3 tests (gate on/off, tap navigation) — เพิ่ม invite-link overrides ใน `RecordingClubRepository`
  - **พบและแก้บั๊กใน test ของตัวเอง**: `Clipboard.setData` ไม่มี default mock handler ใน flutter_test แบบ implicit ทำให้ await ค้างตลอดไป (indeterminate `CircularProgressIndicator` วนไม่หยุด → `pumpAndSettle()` timeout) — แก้ด้วยการ register `SystemChannels.platform` mock handler ใน `setUp()`/`tearDown()` ของ `club_invite_links_screen_test.dart` ทั้งไฟล์ (มิเรอร์ `interaction_feedback_test.dart`'s ท่าเดิมสำหรับ `HapticFeedback`) — ไม่ใช่บั๊กใน production code เป็นแค่ gap ของ test setup
- **flutter analyze**: 0 issues (ทั้งโปรเจกต์)
- **flutter test**: **1433/1433 PASS** (ทั้งโปรเจกต์ รวม 30 test ใหม่ของ WYN-130)

Known Issues: ไม่มี — schema/RPC/UI/deep-link/RLS ตรงตาม design spec ครบ ไม่มี known gap ที่ต้องรายงาน Founder เพิ่ม (attribution tracking ผ่าน `club_invite_link_uses` เก็บ data ไว้แล้วตาม Requirement แต่ยังไม่มี UI แสดงผล ตามที่ระบุไว้ตั้งแต่ Product/Design spec ว่าไม่ scope รอบนี้)

Handoff: ส่งต่อ AI QA & Security
