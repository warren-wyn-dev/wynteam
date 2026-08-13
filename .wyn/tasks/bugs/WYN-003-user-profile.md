# Product Task — WYN-003

Status: bugs (QA รอบ 1 — FAIL)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — FAIL) → AI Debug Engineer (ถัดไป)

Feature: User Profile (View & Edit)

---

## QA & Security Report (AI QA & Security)

Feature: WYN-003 — User Profile

Environment: Code review + static analysis บน `main` หลัง merge PR #14 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับ WYN-002 (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. View Profile แสดงข้อมูลถูกต้องตาม design spec (code review)
4. **Edit Profile → บันทึกชื่อแสดง/bio → เทียบกับ DB constraint ใน `supabase/schema.sql` ทีละบรรทัด**
5. Edit Profile → อัปโหลดรูปใหม่ → เทียบ path/RLS policy
6. RLS policies (table + storage) ตรวจสอบว่าครอบคลุมถูกต้อง
7. Accessibility: `AvatarCircle` semantics (เคยพังแล้วแก้ไปในรอบ implement — ตรวจซ้ำว่าแก้จริง)
8. Regression check: WYN-002 (Auth/Onboarding) ไม่ได้รับผลกระทบจากการแก้ `home_screen.dart`

Passed: 7/8 (#1, #2, #3, #5, #6, #7, #8)

Failed: 1/8 (#4)

Severity: #4 — **Critical**

### Failed Case #4 — Critical: บันทึกโปรไฟล์ล้มเหลวทุกครั้งถ้าไม่ได้กรอกชื่อแสดง (ซึ่งเป็นค่าเริ่มต้นของผู้ใช้ทุกคน)

Reproduction Steps (เทียบโค้ดจริงกับ DB constraint ทีละบรรทัด ไม่ได้เดา):
1. ผู้ใช้คนไหนก็ได้ (ทุกคน เพราะ WYN-002 ไม่เคยตั้ง `display_name` ให้ตอนสมัคร) เปิด Edit Profile ครั้งแรก — `_displayNameController` ถูก init ด้วย `widget.profile.displayName ?? ''` = ช่องว่างเปล่า (`''`) เพราะ `displayName` เป็น `null` อยู่
2. ผู้ใช้พิมพ์ bio อย่างเดียว (ไม่แตะช่องชื่อแสดงเลย — เป็นพฤติกรรมที่คาดว่าจะเกิดบ่อยมาก) แล้วกด "บันทึก"
3. `_save()` เรียก `updateProfile(displayName: _displayNameController.text.trim(), ...)` → ส่ง `displayName = ''` (string ว่าง ไม่ใช่ null)
4. `ProfileRepository.updateProfile()` (`profile_repository.dart:24-33`) ส่ง `{'display_name': ''}` ตรง ๆ ไปที่ Supabase ไม่มีการแปลง `''` เป็น `null`
5. ที่ database ฝั่ง Supabase: `supabase/schema.sql:44-45` มี constraint `check (display_name is null or char_length(display_name) between 1 and 50)` — ค่า `''` **ไม่ใช่ null และมี char_length = 0** ซึ่ง**ไม่อยู่ในช่วง 1-50** → constraint violation → UPDATE statement ถูกปฏิเสธจาก database

Expected: ผู้ใช้ที่ยังไม่ตั้งชื่อแสดง ควรบันทึก bio/รูปได้ตามปกติ (ชื่อแสดงเป็น optional ตาม Product spec — "ถ้ายังไม่ตั้งให้ fallback แสดง `@username` แทน" ตาม Design Spec Screen 1)

Actual: **บันทึกไม่สำเร็จทุกครั้ง** ที่ช่องชื่อแสดงว่างอยู่ (ซึ่งคือค่าเริ่มต้นของผู้ใช้ทุกคนที่ยังไม่เคยตั้งชื่อแสดง) — `_save()`'s catch-all `catch (_)` (`edit_profile_screen.dart:139-141`) จับ error ทั่วไปแล้วโชว์แค่ "บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง" ผู้ใช้กดลองใหม่ก็ยังพังซ้ำเหมือนเดิม (เพราะช่องชื่อแสดงยังว่างเหมือนเดิม) — ไม่มีทางรู้เลยว่าต้องพิมพ์อะไรลงช่องชื่อแสดงถึงจะบันทึกผ่าน

**นี่คือ blocker ที่กระทบผู้ใช้เกือบทุกคนตั้งแต่ครั้งแรกที่ใช้ฟีเจอร์นี้** เพราะ default state ของทุก user คือช่องชื่อแสดงว่างเปล่า

Security Findings:
- ไม่พบ secret/credential hardcode
- RLS policies (table + storage) ตรวจสอบแล้วถูกต้องตามเจตนา ทั้ง insert/update policy ของ `storage.objects` ครอบคลุม `uploadBinary(..., upsert: true)` ทั้งกรณีอัปโหลดครั้งแรกและอัปโหลดซ้ำ
- **[Low] ไม่มีการลบไฟล์รูปเก่าเมื่อผู้ใช้เปลี่ยนรูปด้วยไฟล์นามสกุลอื่น** — path เป็น `{userId}/avatar.{extension}` ถ้าเปลี่ยนจาก `.png` เป็น `.jpg` จะได้ path ใหม่ ไฟล์เก่าค้างอยู่ใน Storage เปลืองพื้นที่สะสมไปเรื่อย ๆ (ไม่ใช่ security bug แต่เป็น storage-cost risk ระยะยาว)

Recommendation: ส่งกลับ AI Debug Engineer แก้ #4 (Critical) — แนวทางที่แนะนำ: ที่ `ProfileRepository.updateProfile()` แปลง `displayName` ที่เป็น empty string ให้เป็น `null` ก่อนส่งไป Supabase (`'display_name': displayName.isEmpty ? null : displayName`) เพื่อให้สอดคล้องกับความหมายที่ตั้งใจไว้ (ค่าว่าง = "ยังไม่ได้ตั้งชื่อแสดง" = null = fallback ไปที่ `@username` ตาม `Profile.nameOrUsername`) แทนที่จะฝ่าฝืน DB constraint

Final Status: **FAIL**
