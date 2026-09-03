# Feature Request — WYN-099

Status: design complete, ready for AI Coding (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 4/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่มการตั้งค่าความเป็นส่วนตัวของแท็บ "ถูกใจ" บนโปรไฟล์
Goal: ให้ผู้ใช้ควบคุมได้ว่าใครเห็นรายการโพสต์ที่ตัวเองกดถูกใจได้บ้าง
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "โปรไฟล์ ปุ่มถูกใจ เป็นปุ่มที่เราถูกใจคนอื่น ควรสามารถเปิด/ปิดความเป็นส่วนตัวได้ ว่าใครสามารถเห็นตรงนี้ได้บ้าง"
Requirements:
- เพิ่มการตั้งค่าใน Settings (หรือใกล้แท็บถูกใจในหน้าโปรไฟล์) ให้เลือกระดับการมองเห็นแท็บ "ถูกใจ": เช่น ทุกคน / เพื่อน / เฉพาะฉัน (reuse แนวคิด privacy level เดียวกับ WYN-097)
- Enforce สิทธิ์จริงตอนคนอื่นเปิดดูแท็บถูกใจของเรา
Acceptance Criteria:
- [ ] ตั้งค่าเป็น "เฉพาะฉัน" แล้วคนอื่นเปิดโปรไฟล์เราจะไม่เห็น/เข้าไม่ถึงแท็บถูกใจ
Dependencies: ควรทำหลัง/คู่กับ WYN-097 (ใช้ privacy level เดียวกัน)
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ลืม enforce ฝั่ง backend แล้วข้อมูลรั่วผ่าน API ตรง | สูง | ทดสอบเรียก API ตรงๆ (ไม่ผ่าน UI) ด้วย user ที่ไม่มีสิทธิ์ ต้องถูกบล็อก |
Recommendation: อนุมัติ ทำคู่กับ WYN-097
Handoff: AI Product Manager (รวม spec กับ WYN-097) → AI Design → AI Coding → AI QA

## Product Full Spec Output (2026-09-02)

เขียน full spec เสร็จแล้วที่ `.wyn/docs/product/wyn-099-likes-privacy.md` — สรุปแนวทาง: เพิ่ม `profiles.likes_visibility` (everyone/friends/only_me, แยกจาก `InteractionPermission` เดิมของ WYN-045 เพราะความหมายคนละแบบ — "people_i_follow" ≠ "mutual friend") **ไม่แตะ RLS ของ `drop_likes`/`pop_likes` เลย** เพราะจะพัง like_count/liked_by ของทุกโพสต์ทั่วแอป (ตารางเดียวกันถูกใช้ร่วมกัน) — แทนที่ด้วย RPC ใหม่ `fetch_liked_drops`/`fetch_liked_pops` (security definer) ที่เช็คสิทธิ์ในตัวเอง และเชื่อมกับ audience check ของ WYN-097 ด้วย (เพื่อนไลค์โพสต์ "เฉพาะฉัน" ของคนอื่น ต้องไม่โผล่ในแท็บถูกใจที่เราเห็น)

**ข้อจำกัดที่ยอมรับและบันทึกไว้ตรงไปตรงมา**: `drop_likes`/`pop_likes` table เองยังเปิด SELECT ให้ authenticated ทุกคนเหมือนเดิม (ปิดสนิทต้องรีไรท์ like_count/liked_by ทั้งแอปผ่าน security-definer แทน ใหญ่กว่าสโคปนี้มาก) — ต้องแจ้ง AI QA & Security ให้รับทราบ residual risk นี้ตรงๆ ก่อนอนุมัติ deploy ไม่ใช่ถือว่าปิดสนิทแล้ว

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-099-likes-privacy.md`

Handoff: ส่งต่อ AI Design (`/design`) พร้อมกับ WYN-097 (แนะนำทำเป็น addendum สั้นๆ ต่อท้าย ไม่ต้องแยกเอกสารใหญ่ เพราะ data model ผูกกันโดยตรง)

## Design Output (2026-09-02)

เขียนเป็น addendum ต่อท้าย design spec ของ WYN-097 แล้วตามที่ขอ (ไม่แยกเอกสารใหญ่) — ที่ `.wyn/docs/design/wyn-097-099-audience-friends-and-likes-privacy.md` หัวข้อ "WYN-099 Addendum — Likes Tab Privacy Setting" ครอบคลุม 2 จุด: (A) แถวใหม่ "ใครเห็นสิ่งที่คุณถูกใจได้" ใน Settings > ความเป็นส่วนตัว (reuse โครง `_PermissionSettingTile`/`_showPermissionPicker` เดิม แต่แยก enum ใหม่ `LikesVisibility` ไม่ปนกับ `InteractionPermission`/`AudienceOption` ตามเหตุผลที่ Product spec อธิบายไว้) (B) Empty state ใหม่ "บัญชีนี้ซ่อนรายการที่ถูกใจไว้" บนแท็บถูกใจของโปรไฟล์คนอื่น เมื่อไม่มีสิทธิ์ดู + อัปเดตข้อความ `PrivacyNoticeBanner` ให้ตรงกับ `likes_visibility` ปัจจุบัน — ไม่มี UI ใหม่ที่ซับซ้อน reuse pattern ที่มีอยู่แล้วทั้งหมด

Handoff: ส่งต่อ AI Coding (`/code`) พร้อมกับ WYN-097 (data-model/RPC ผูกกันโดยตรงตามที่ Product spec แนะนำให้ทำต่อเนื่องกัน)

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — ทำพร้อมกับ WYN-097 ในรอบเดียวกัน (commit เดียวกัน) ตามที่ Design/Product spec แนะนำ เพราะใช้ `internal.is_mutual_follow()` ร่วมกันโดยตรง

การเปลี่ยนแปลง (Backend, `supabase/schema.sql`, ต่อท้ายไฟล์เดียวกับ WYN-097):
1. `profiles.likes_visibility` คอลัมน์ใหม่ (3 ค่า, default `'everyone'`) — **ไม่แตะ RLS ของ `drop_likes`/`pop_likes` เลย** ตามที่ Architecture Decision ของ Product spec ระบุไว้ (ป้องกัน `like_count`/`liked_by` ของทุกโพสต์พังทั้งแอป)
2. `internal.can_view_likes(viewer, target)` — security definer
3. `public.can_view_likes(target)` RPC ใหม่ (wrapper สาธารณะ, ไม่ได้ระบุไว้ตรงๆ ใน Product spec แต่จำเป็นทางเทคนิค — ดูเหตุผลด้านล่าง) — ให้ Flutter client เรียกแยกเพื่อรู้ว่าควรแสดง empty state แบบไหน (`internal.*` functions ไม่ถูก expose ผ่าน PostgREST เลย ต้องมี wrapper `public.*`)
4. `public.fetch_liked_drop_ids(target, page)`/`fetch_liked_pop_ids(target, page)` RPC ใหม่ — เช็ค `can_view_likes` + (สำหรับ Drop) `can_view_drop_audience` ซ้อน (Edge Case 3 ของ spec — กัน "เพื่อนไลค์โพสต์เฉพาะฉันของคนอื่นรั่วผ่านแท็บถูกใจ")

Frontend:
- `LikesVisibility` enum ใหม่ (`app/lib/features/profile/data/profile.dart`) + field `Profile.likesVisibility`
- `ProfileRepository.updateLikesVisibility`/`canViewLikes` ใหม่
- `DropRepository.fetchLikedByAuthor` เปลี่ยนจาก query `drop_likes` ตรง เป็น 2 ขั้น: เรียก `fetch_liked_drop_ids` RPC ก่อน (บังคับใช้ likes_visibility) แล้วค่อย select rich card shape ตาม id ที่ได้ (ยังผ่าน RLS ของ `drops` ซ้ำอีกชั้นแบบ defense-in-depth)
- Settings > ความเป็นส่วนตัว: แถวใหม่ "ใครเห็นสิ่งที่คุณถูกใจได้" (`_LikesVisibilitySettingTile`/`_showLikesVisibilityPicker`)
- `ProfileLikesTab`: แยก empty state ใหม่ "บัญชีนี้ซ่อนรายการที่ถูกใจไว้" ออกจาก "ยังไม่เคยกด Like" เดิม — เรียก `canViewLikes` แค่ตอน list ว่างเปล่าเท่านั้น (ไม่เสีย extra query ตอน list ไม่ว่าง)
- `ViewProfileScreen`: `PrivacyNoticeBanner`'s ข้อความอัปเดตตาม `likesVisibility` ปัจจุบัน (3 ข้อความตาม 3 ค่า)

Files Changed:
- `supabase/schema.sql` (migration เดียวกับ WYN-097)
- `app/lib/features/profile/data/profile.dart`, `profile_repository.dart`
- `app/lib/features/drop/data/drop_repository.dart` (`fetchLikedByAuthor`)
- `app/lib/features/settings/presentation/settings_screen.dart`
- `app/lib/features/profile/presentation/widgets/profile_likes_tab.dart`
- `app/lib/features/profile/presentation/view_profile_screen.dart`
- Tests: `app/test/settings_screen_test.dart`, `profile_likes_tab_test.dart` + fake `support/recording_profile_repository.dart` อัปเดต

Reason: Wynos V1.0.0 Beta2.pdf ข้อ 4/28 — Founder: "โปรไฟล์ ปุ่มถูกใจ... ควรสามารถเปิด/ปิดความเป็นส่วนตัวได้ ว่าใครสามารถเห็นตรงนี้ได้บ้าง"

Tests:
- `flutter analyze`: สะอาด (No issues found!)
- `flutter test`: 977/978 ผ่าน (1 ล้มเหลวไม่เกี่ยวข้อง — ดูรายละเอียดที่ WYN-097's Coding Output ในรอบนี้ เป็น commit เดียวกัน)

Build: ไม่ได้ apply migration จริงกับ production (เหตุผลเดียวกับ WYN-097)

Known Issues:
- **ข้อจำกัดที่ยอมรับแล้วตาม Product spec**: `drop_likes`/`pop_likes` table ยังเปิด SELECT ให้ authenticated ทุกคนเหมือนเดิม (residual risk ที่บันทึกไว้แล้วใน Product spec — การยิง query ตรงข้าม RPC ยังเห็น raw like rows ได้) ต้องแจ้ง QA/Founder รับทราบตรงๆ ไม่ใช่ปิดบัง
- ยังไม่ได้ apply migration จริง + ยังไม่ได้ทดสอบ RLS/RPC กับ Supabase จริง (เหมือน WYN-097)
- `public.can_view_likes` RPC ไม่ได้ระบุชื่อ/ลายเซ็นชัดเจนใน Product/Design spec (spec พูดถึงแค่ RPC `fetch_liked_drops`/`fetch_liked_pops` สำหรับดึงข้อมูล) — เพิ่มเองเพราะจำเป็นทางเทคนิคสำหรับแยก 2 empty state ตาม UI requirement ข้อ 2 ของ spec เอง ("ต้องแยกแยะ 'ว่างเพราะไม่มีสิทธิ์' กับ 'ว่างเพราะยังไม่เคยกด Like เลย'... วิธีแยกสองเคสนี้ให้ AI Coding ตัดสินใจตามความเหมาะสมทางเทคนิค")

Handoff: ส่งต่อ AI QA & Security — (1) ทดสอบว่า `like_count`/`liked_by` ของทุกโพสต์ **ไม่เปลี่ยน** ไม่ว่า `likes_visibility` ของใครจะตั้งเป็นอะไร (จุดพิสูจน์ architecture ถูกต้องตาม spec) (2) ยิง `fetch_liked_drop_ids` RPC ตรงๆ ด้วย user ที่ไม่มีสิทธิ์ → ต้องว่างเปล่า (3) ทดสอบ Edge Case 3 จริง (เพื่อนไลค์โพสต์ "เฉพาะฉัน" ของคนอื่น ต้องไม่โผล่ในแท็บถูกใจ) (4) รับทราบ residual risk ของ raw table query ตามที่ Product spec ระบุไว้ชัดเจนแล้ว ไม่ใช่ปิดสนิท 100%

## QA Report (2026-09-03)

```
Feature: WYN-099 — Likes Tab Privacy (ทุกคน/เพื่อน/เฉพาะฉัน ควบคุมว่าใครเห็นรายการที่เรากดถูกใจ)
Environment: Static/adversarial code review ของ commit 40cafac บน claude/wynos-beta2-phase2-handoff-w4mi5m (worktree ยืนยันตรง base แล้ว) — อ่าน `supabase/schema.sql` migration บล็อกของ WYN-099 (บรรทัด ~11045-11159) + โค้ด Flutter (`profile.dart`, `profile_repository.dart`, `drop_repository.dart`'s `fetchLikedByAuthor`, `settings_screen.dart`, `profile_likes_tab.dart`, `view_profile_screen.dart`) + รัน `flutter analyze`/`flutter test` เต็ม suite อิสระ ไม่โหลด schema.sql เต็มไฟล์เข้า Postgres จริงตาม DECISIONS.md
Test Cases:
  1. ยืนยัน `profiles.likes_visibility` มี CHECK constraint 3 ค่า ('everyone'/'friends'/'only_me') default 'everyone' — backward compatible ไม่กระทบ user เดิม
  2. ยืนยัน `internal.can_view_likes(viewer, target)`: เจ้าของเห็นตัวเองเสมอ, everyone เห็นทุกคน, friends ต้อง `is_mutual_follow` จริง, only_me ไม่มี branch จับ (fallthrough false)
  3. ยืนยัน **สถาปัตยกรรมสำคัญที่สุดของงานนี้**: `drop_likes`/`pop_likes`' RLS policy ("...are viewable by authenticated users") ยังเป็น `using (true)` เหมือนเดิมทุกตัวอักษร — grep ยืนยันตรง ไม่ถูกแก้เลย ตามที่ Product spec ตั้งใจ (ป้องกัน like_count/liked_by ของทุกโพสต์ทั่วแอปพังจากการเปลี่ยน RLS ของตารางที่ใช้ร่วมกัน)
  4. ยืนยัน `fetch_liked_drop_ids`/`fetch_liked_pop_ids` (SECURITY DEFINER, PostgREST-exposed ผ่าน public wrapper) เช็ค `can_view_likes` ก่อนคืนผลทุกครั้ง — user ไม่มีสิทธิ์ยิง RPC ตรงจะได้ list ว่างเปล่า
  5. ยืนยัน Edge Case 3 (เพื่อนไลค์โพสต์ "เฉพาะฉัน"/"เพื่อน" ของคนอื่น ต้องไม่รั่วผ่านแท็บถูกใจ): `fetch_liked_drop_ids` join `drops` แล้วเช็ค `can_view_drop_audience` ซ้อนอีกชั้น (เชื่อมกับ WYN-097 โดยตรงตามที่ spec ต้องการ) — `fetch_liked_pop_ids` ไม่มีเช็คนี้ เพราะ Pop ไม่มีแนวคิด audience (ตามคอมเมนต์ในโค้ด ถูกต้องตาม scope WYN-097 ที่ไม่รวม Pop)
  6. ยืนยัน residual risk ที่ Coding Output ประกาศไว้ตรงๆ ("drop_likes/pop_likes table เองยังเปิด SELECT ให้ authenticated ทุกคน") **เป็นความจริงที่ตรวจสอบได้จาก SQL จริง ไม่ใช่การพูดเกินจริงหรือปิดบัง** — สอดคล้องกับ Product spec's Architecture Decision ที่บันทึกเหตุผลไว้ชัดเจนทั้งใน Product spec และ comment ในตัว schema.sql เอง (บรรทัด 11060-11068) ถือเป็น **accepted scope ตาม Product spec จริง ไม่ใช่จุดที่ QA ควร FAIL** — แต่ต้องแจ้ง Founder รับทราบก่อน deploy ตามที่ Coding Output ขอ
  7. ยืนยัน Frontend: `ProfileLikesTab` เรียก `canViewLikes` เฉพาะตอน list ว่างเปล่าเท่านั้น (ไม่เสีย extra query ตอน list ไม่ว่าง) แยก 2 empty state ถูกต้อง ("ยังไม่เคยกด Like" vs "บัญชีนี้ซ่อนรายการที่ถูกใจไว้")
  8. รัน `flutter analyze`: สะอาด, `flutter test` เต็ม suite: 1011/1011 ผ่าน (รวมกับ WYN-097 commit เดียวกัน)
Passed: ข้อ 1-8
Failed: ไม่มี
Severity: N/A (PASS)
Reproduction Steps: N/A
Expected: N/A
Actual: N/A
Security Findings: Residual risk 1 จุดที่ **รับทราบและยอมรับแล้วตาม Product spec** (ไม่ใช่ FAIL): การยิง query ตรงเข้า `drop_likes`/`pop_likes` table (bypass RPC) ยังเห็น raw like rows ได้ไม่ว่า `likes_visibility` จะตั้งเป็นอะไร — เป็นข้อจำกัดทางสถาปัตยกรรมที่ตั้งใจ (ปิดสนิทต้องรีไรท์ RLS ทั้งแอปซึ่งใหญ่กว่าสโคปนี้มาก) ไม่ใช่บั๊กที่พลาดไป ต้องแจ้ง Founder รับทราบก่อน deploy จริงตามที่ Product/Coding ระบุไว้แล้ว — ไม่มีช่องโหว่อื่นที่ตรวจพบเพิ่มเติมจาก static review
Recommendation: อนุมัติเข้า approved — AI Deploy & DevOps ต้อง apply migration กับ production schema จริงก่อน (ร่วมกับ WYN-097 migration เดียวกัน) แล้วทดสอบ RPC จริงกับ Supabase project จริง (ยิง `fetch_liked_drop_ids` ด้วย user ไม่มีสิทธิ์ต้องว่างเปล่าจริง) — แจ้ง Founder รับทราบ residual risk ของ raw table query ก่อนประกาศ feature ว่า "ปิดสนิท 100%"
Final Status: PASS
```
