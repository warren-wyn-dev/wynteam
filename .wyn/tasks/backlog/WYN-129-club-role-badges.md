# Product Task — WYN-129

Status: coding เสร็จแล้ว (2026-09-07) — schema (`club_member_badges`, แยกจาก `club_role()` โดยสิ้นเชิง) + Dart (badge pill, dialog ตั้ง/แก้/ถอดป้าย, แสดงใน Members tab + ใต้โพสต์/คอมเมนต์) implemented, `flutter analyze`/`flutter test` เขียวทั้งหมด — รอ AI QA & Security
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (ถัดไป)

Feature: Club Role Badge — ป้ายชื่อ/สีที่ Owner ตั้งเองได้ ติดข้าง role ของสมาชิก

Goal: เติมความรู้สึก "ตัวตนในคอมมูนิตี้" แบบ Discord role (สีสัน, ชื่อเฉพาะ เช่น "🎨 Artist", "VIP", "ผู้ก่อตั้งรุ่นแรก") โดย**ไม่แตะระบบสิทธิ์ (permission) เดิมเลย** ดู `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` ข้อ 3

Target User: Owner ที่อยากให้รางวัล/ยกย่องสมาชิกบางคนแบบมองเห็นได้ทันที และสมาชิกที่อยากมี "ตัวตน" ในคอมมูนิตี้มากกว่าแค่ role ตายตัว 4 ระดับ

Problem: Role ของ Club วันนี้มีแค่ 4 ระดับตายตัว (Owner/Admin/Moderator/Member) และเป็น**เรื่องสิทธิ์ล้วนๆ** ไม่มีมิติ "แสดงตัวตน/ยกย่อง" เลย — ต่างจาก Discord ที่ role มีสีสันและ Owner ตั้งชื่อ/สีเองได้ ทำให้เห็นใครเป็นใครในคอมมูนิตี้ได้ทันทีโดยไม่ต้องเดา

Requirements:
1. Owner/Admin ตั้ง "ป้าย" (badge) ให้สมาชิกคนใดก็ได้ในสังกัด Club ตัวเอง — ป้ายมี: ข้อความสั้น (เช่น "VIP", "ผู้ก่อตั้งรุ่นแรก", ไม่เกินความยาวที่ Design กำหนด) + สีพื้นหลัง/ตัวอักษร (เลือกจาก palette ที่กำหนดไว้ ไม่ใช่ color picker อิสระ กันสีที่อ่านไม่ออก/ผิดธีม WYN)
2. **ป้ายเป็นเรื่องคอสเมติกล้วนๆ ไม่มีผลต่อสิทธิ์ใดๆ ทั้งสิ้น** — คนมีป้าย "VIP" ยังทำได้แค่สิ่งที่ role จริง (Owner/Admin/Moderator/Member) อนุญาตเท่านั้น ห้ามมีการเช็ค permission จากป้ายเด็ดขาด (ต้องแยกจาก `club_role()` โดยสิ้นเชิง)
3. ป้ายแสดงข้าง username ของสมาชิกทุกที่ที่เห็นตัวตนใน Club นั้น (Members tab, ใต้โพสต์ที่เขาสร้าง, ใน comment) — แสดงเฉพาะภายใน Club ที่ตั้งป้ายนั้น ไม่ตามไปที่โปรไฟล์ WYN ทั่วไปของเขา
4. สมาชิก 1 คนมีป้ายได้สูงสุด 1 ป้ายต่อ Club (ไม่ซับซ้อนเป็นระบบ multi-role แบบ Discord เต็มรูปแบบ) — ลดความซับซ้อนของ V1
5. Owner/Admin ถอดป้ายออกได้ทุกเมื่อ

Acceptance Criteria:
- Owner ตั้งป้าย "VIP" สีทองให้สมาชิกคนหนึ่ง → เห็นป้ายนั้นข้างชื่อเขาใน Members tab และใต้โพสต์ที่เขาโพสต์ในทันที
- สมาชิกที่มีป้าย "VIP" แต่ role จริงคือ Member ธรรมดา **ยังคงทำสิ่งที่ Member ทำไม่ได้ไม่ได้อยู่ดี** (ลบโพสต์คนอื่น, approve สมาชิกใหม่ ฯลฯ) — ป้ายไม่ปลดล็อกสิทธิ์ใดๆ
- ถอดป้ายออก → ป้ายหายจากทุกจุดที่เคยแสดงทันที
- สมาชิกทั่วไป (ไม่ใช่ Owner/Admin) ตั้ง/ถอดป้ายให้ใครไม่ได้เลย
- เปิดโปรไฟล์ WYN ทั่วไปของสมาชิกคนนั้น (นอก context ของ Club) ไม่เห็นป้ายนี้ — ป้ายผูกกับบริบท Club เดียวเท่านั้น

Dependencies: ไม่มี — เป็น layer คอสเมติกใหม่แยกจาก `club_role()`/authorization เดิมทั้งหมด ไม่กระทบ WYN-014's core permission system, ไม่ต้องรอ WYN-127/128

Priority: กลาง — เร็ว/เสี่ยงต่ำที่สุดในสามอัน ทำแทรกระหว่างหรือหลัง WYN-127 ก็ได้ ไม่ block อะไร

Risks:
- **ความเสี่ยงที่ต้องระวังที่สุด**: อย่าให้ AI Coding เผลอเช็ค permission จากป้ายแทน `club_role()` จริง (เช่น เผลอ query ป้าย "VIP" แล้วให้สิทธิ์พิเศษ) — ต้อง QA เน้นตรวจจุดนี้เป็นพิเศษว่าป้ายไม่มีทางกระทบ permission ได้เลยไม่ว่าทางใด
- ถ้าปล่อยให้ Owner พิมพ์ข้อความป้ายอิสระ อาจมีคนตั้งป้ายไม่เหมาะสม (หยาบคาย/สแปม) — Requirement 1 จำกัดความยาว แต่ยัง**ไม่มี content moderation** สำหรับข้อความป้ายในสเปคนี้ ให้ Design พิจารณาว่าต้องกรองคำหยาบหรือไม่ (อาจ reuse mechanism มาตรฐานที่มีอยู่แล้วถ้ามี)

Recommendation: Design เสร็จแล้ว ดูหัวข้อ "AI Design Output" ด้านล่าง

Handoff: ส่งต่อ AI Coding → AI QA & Security (**เน้นพิเศษ**: ยืนยันว่าป้ายไม่มีทางกระทบ permission check ใดๆ ในระบบ, ตรวจสิทธิ์ตั้ง/ถอดป้ายเฉพาะ Owner/Admin, ตรวจป้ายไม่รั่วไปนอกบริบท Club)

## Coding Notes (2026-09-07)

- Migration SQL: `supabase/migrations_wyn129_club_member_badges.sql` (Founder ต้องรันผ่าน Supabase Dashboard เอง — ยังไม่ได้ apply) + `supabase/schema.sql` อัปเดตให้ตรงกัน
- **Isolation จาก `club_role()`**: สร้าง `ClubBadgeRepository` เป็นไฟล์แยกต่างหาก (`app/lib/features/club/data/club_badge_repository.dart`) ไม่ใช่ method บน `ClubRepository` — ไม่มีจุดใดใน repository นี้เรียก `club_role()` เพื่อให้สิทธิ์อะไร และไม่มีจุดใดที่เช็ค permission จริง (ClubRepository/ClubPostRepository/RLS policies อื่นๆ) query ตาราง `club_member_badges` เลย — ทำให้ QA ตรวจ isolation ได้ง่ายด้วยการอ่านไฟล์เดียว
- RLS: read เปิดให้ authenticated ทุกคน (เหมือน `clubs`/`club_channels`), insert/update/delete จำกัด Owner/Admin ของ Club นั้นเท่านั้น และ insert ต้องเช็คว่าเป้าหมายเป็น approved member จริง (`club_role(club_id, user_id) is not null`)
- UI: `ClubBadgePill` widget แยกจาก role `Chip` เดิมชัดเจน, ปุ่มจัดการป้าย (`local_offer_outlined` icon, key `member-badge-menu-...`) เป็นปุ่มแยกจากเมนู "..." จัดการ role เดิม (ไม่ใช้ปุ่มเดียวกัน) เพื่อไม่ให้กระทบ regression test เดิมที่ยืนยันว่า Owner/self row ไม่มีเมนู role — badge แสดงใน Members tab, ใต้ author ของโพสต์ (ClubPostCard) และคอมเมนต์ (ClubPostDetailScreen)
- สี 3 สีเพิ่มเป็น token ใน `WynColors` (`clubBadgeGoldBg/Fg`, `clubBadgeSageBg/Fg`, `clubBadgePlumBg/Fg`) ตาม pattern เดียวกับ `notificationBadgeComment/Repost` ที่มีอยู่แล้ว
- `flutter analyze`: no issues. `flutter test`: ผ่านทั้งหมด (รวม test ใหม่สำหรับตั้ง/ถอดป้าย และยืนยันว่า badge ไม่เพิ่ม role action ใดๆ)

## AI Design Output

Screen: Club Page → Members tab (เพิ่ม badge ข้าง role chip เดิม) + Posts tab (เพิ่ม badge ข้างชื่อผู้โพสต์/ผู้คอมเมนต์)

Purpose: ให้เห็น "ตัวตน" ของสมาชิกที่ Owner/Admin ยกย่อง โดยไม่ปนกับ role permission เดิม — mockup เต็ม: https://claude.ai/code/artifact/d08fb9ad-0757-486b-9808-9c65cbe1d9b7 (แท็บ "WYN-129 Role Badges", palette สี Founder อนุมัติ 2026-09-07 ตามที่เสนอ ไม่มีแก้ไข)

User Flow: Owner/Admin เปิด Members tab → แตะสมาชิกคนหนึ่ง → "ตั้งป้าย" → กรอกข้อความป้าย (จำกัดไม่เกิน 20 ตัวอักษร) + เลือก 1 ใน 3 สี → บันทึก → ป้ายปรากฏทันทีข้าง role chip ใน Members tab และข้างชื่อผู้โพสต์ในโพสต์/คอมเมนต์ของเขาในเวลาเดียวกัน — ถอดป้ายทำย้อนกลับจากเมนูเดิม

Components:
- Badge pill (`.badge-pill`): ทรงเม็ดยา (`radiusFull`), ขนาดเล็กกว่า role `Chip` เดิมชัดเจน (แยกจากกันด้วยสายตาทันทีว่าอันไหนคือสิทธิ์ อันไหนคือคอสเมติก) วางถัดจาก role chip เสมอ ไม่แทนที่
- Palette 3 สี (Founder อนุมัติ, อิงธีม WYN ไม่ใช่สีอิสระ):
  - Gold: พื้นหลัง `#F7EBD2` / ตัวอักษร `#8A6A1E` (เช่น "VIP")
  - Sage: พื้นหลัง `#E1EAE3` / ตัวอักษร `#3E6B4E` (เช่น "ผู้ก่อตั้งรุ่นแรก")
  - Plum: พื้นหลัง `#EFE1EC` / ตัวอักษร `#7A4C6B` (เช่น "🎨 Artist")
- Dialog ตั้งป้าย: ช่องกรอกข้อความ (max 20 ตัวอักษร, กันข้อความว่าง) + 3 ตัวเลือกสีเป็นวงกลมให้แตะเลือก (ไม่ใช่ color picker อิสระ) + ปุ่มยืนยัน/ยกเลิก
- เมนู "..." บนแถวสมาชิกใน Members tab (Owner/Admin เท่านั้น) → "ตั้งป้าย" / "แก้ไขป้าย" / "ถอดป้าย"

Interactions: แตะ "ตั้งป้าย" → dialog เปิด → เลือกสี+พิมพ์ข้อความ → กดยืนยัน → badge ปรากฏทันทีไม่ต้อง refresh, กด "ถอดป้าย" → บาดจ์หายทันทีทุกจุดที่เคยแสดง

States: สมาชิกไม่มีป้าย → ไม่แสดงอะไรเพิ่ม (เหมือนปัจจุบัน), กำลังบันทึก/ถอดป้าย → loading state บน dialog/เมนู, ข้อความป้ายว่างหรือเกิน 20 ตัวอักษร → ปุ่มยืนยัน disabled พร้อมข้อความแจ้งเตือน

Responsive Behavior: badge วางต่อท้าย role chip แบบ inline, ถ้าพื้นที่ไม่พอ (จอแคบ/ชื่อยาว) ให้ wrap ไปบรรทัดถัดไปได้ ไม่บีบให้ข้อความ badge ถูกตัด (ห้าม clip ข้อความ)

Accessibility: badge ต้องอ่านได้ด้วย screen reader เป็น "ป้าย: [ข้อความ]" แยกจาก role เพื่อไม่ให้สับสนว่าเป็นสิทธิ์, contrast ของทั้ง 3 สี (พื้นหลัง/ตัวอักษร) ผ่านเกณฑ์ WCAG AA ตามที่เลือกไว้แล้วในการออกแบบ

Design Rules: ห้ามใช้ role `Chip` เดิมกับ badge ปนกัน (คนละ component ชัดเจน กันสับสนเรื่องสิทธิ์), ห้ามเพิ่มสีนอกเหนือ 3 สีที่อนุมัติ, badge ต้องไม่ปรากฏในโปรไฟล์ WYN ทั่วไปนอกบริบท Club (ตาม Requirement 3)

Handoff: AI Coding (schema: เพิ่มตาราง `club_member_badges(club_id, user_id, label, color_key, created_by, created_at)` แยกจาก `club_role()` โดยสิ้นเชิง ห้าม query ตารางนี้ในจุดใดที่เช็ค permission เด็ดขาด) → AI QA & Security
