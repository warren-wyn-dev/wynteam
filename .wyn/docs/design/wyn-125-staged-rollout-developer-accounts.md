# Design — WYN-125 (Requirement 2: Developer Account Allowlist / Feature-Flag System)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-125-staged-rollout-developer-first.md` (Requirement 2)
> **Precedent ที่ใช้เป็นต้นแบบตรงๆ**: `.wyn/docs/design/wyn-122-chat-lockdown-testers-only.md` และ implementation จริงใน `supabase/schema.sql` ("WYN-122: Temporary chat lockdown") + `.github/workflows/wyn122-apply-chat-lockdown-schema.yml`/`wyn122-toggle-chat-lockdown.yml` — WYN-122 พิสูจน์แล้วว่า pattern "allowlist table + SECURITY DEFINER status function + GitHub Actions workflow เป็นสวิตช์" ใช้งานได้จริงบน production ของ WYN ภายใต้สถานะ auth ปัจจุบัน (anonymous sign-in, ไม่มี login จริง) งานนี้คือการนำ pattern เดียวกัน**สรุปให้เป็นระบบทั่วไป (generic)** แทนที่จะผูกกับฟีเจอร์แชทฟีเจอร์เดียว
> Design system: ไม่มีทิศทาง visual ใหม่ — งานนี้แทบไม่มีหน้าจอ UI ใหม่เลย (ตาม Requirement 3: ผู้ใช้ทั่วไปต้องไม่รู้สึกว่าขาดอะไร) เป็น design สำหรับ "กลไก" ที่ฟีเจอร์ในอนาคตจะเอาไปใช้ ไม่ใช่ screen ใหม่

## สรุปการตัดสินใจหลัก

1. **Reuse สถาปัตยกรรมของ WYN-122 เกือบทั้งหมด แค่ทำให้ generic** — ตาราง allowlist + ฟังก์ชัน SECURITY DEFINER เช็คสถานะ + GitHub Actions workflow เป็นเครื่องมือเพิ่ม/ลบ แทนการสร้าง admin UI ใหม่ ตรงตามที่ Product spec ระบุว่า "ไม่ต้องมี admin UI ใหม่ถ้าไม่จำเป็น"
2. **Flag เดียว ระดับ per-user เป็น boolean เดียว `is_developer_account`** ไม่ใช่ matrix ของ flag ต่อฟีเจอร์ — ตามที่ Founder/Product ระบุชัดในโจทย์ข้อ 2 นี่คือจุดที่ทำให้ระบบ "ยืดหยุ่นใช้ซ้ำได้" เพราะฟีเจอร์ใหม่ในอนาคตแค่เช็ค boolean ตัวเดียวนี้แล้วเลือกเองว่าจะ wrap โค้ดส่วนไหนด้วยเงื่อนไขนี้ — ไม่ต้องสร้างตาราง/ฟังก์ชันใหม่ทุกครั้งที่มีฟีเจอร์ใหม่ต้องการ staged rollout
3. **ตาราง allowlist ถูกปิดสนิทจาก client ทุกทาง (ไม่มี SELECT/INSERT/UPDATE/DELETE policy ใดๆ เลย)** เหมือน `chat_lockdown_allowlist` เป๊ะ — เข้าถึงได้เฉพาะผ่าน Supabase Management API (service-role token) เท่านั้น ไม่มีทางให้ authenticated user คนไหนอ่าน/เขียนตารางนี้ตรงๆ ได้แม้แต่แถวของตัวเอง (ป้องกันการรั่วว่าใครเป็น "บัญชีนักพัฒนา" ด้วย)
4. **เข้ากับสถานะ auth ปัจจุบัน (anonymous sign-in, ไม่มี login จริง) ได้ทันทีโดยไม่ต้องแตะ auth architecture** — ใช้กลไกเดียวกับที่ WYN-122 พิสูจน์แล้วว่าใช้งานได้จริงกับ @warren/@wynos_online ภายใต้ anonymous mode: allowlist อ้างอิงด้วย `profiles.id` (uuid) ที่ resolve มาจาก **username** (`profiles.username` มีอยู่แล้วไม่ว่าจะเป็น anonymous session หรือไม่) — ไม่แตะ Google/Apple OAuth หรือ Phone OTP ใดๆ เลย
5. **Fail-closed โดยโครงสร้าง ไม่ใช่แค่โดยธรรมเนียม** — ฟังก์ชันเช็คสถานะ คืนค่า `false` เสมอเมื่อ: ผู้ใช้ไม่อยู่ใน allowlist, `auth.uid()` เป็น null, หรือเกิด error ใดๆ ระหว่างเช็ค → ค่าเริ่มต้นของทุกบัญชี (รวมผู้ใช้ทั่วไป 100% ของวันนี้) คือ "ไม่ใช่บัญชีนักพัฒนา" → เท่ากับ behavior ปัจจุบันเป๊ะ ไม่มีทางที่ error ของระบบนี้จะไปทำให้ผู้ใช้ทั่วไปเห็นอะไรแปลกใหม่
6. **Client-side accessor ต้อง generic แยกจากทุก feature repository ที่มีอยู่** (ต่างจาก WYN-122 ที่ผูกไว้ใน `ChatRepository.isChatAllowed()` เพราะตอนนั้นเป็นฟีเจอร์เดียว) — ต้องอยู่ใน shared/core location ที่ทุก feature ในอนาคตเรียกใช้ร่วมกันได้โดยไม่ต้อง import repository ของฟีเจอร์อื่น

---

## Screen: ไม่มีหน้าจอใหม่ — นี่คือ capability ระดับ infrastructure

**Purpose**: ให้โค้ดของฟีเจอร์ใดก็ตามในอนาคต (ที่ AI Coding จะเขียนต่อ) มีวิธีเช็คได้ว่า "ผู้ใช้ปัจจุบันเป็นบัญชีนักพัฒนา/ทีมภายในหรือไม่" ด้วย call เดียว แล้วเลือกเองว่าจะ render/ทำงานต่างกันตรงไหนบ้าง — โดยที่ผู้ใช้ทั่วไปทุกคนต้องไม่เห็น/ไม่รู้สึกถึงการมีอยู่ของกลไกนี้เลยจนกว่าจะมีฟีเจอร์จริงมาผูกกับมันและ Founder สั่งเปิด

**User Flow** (มุมมองระบบ ไม่ใช่มุมมองผู้ใช้ เพราะไม่มี UI ใหม่):
1. Founder ตัดสินใจว่าใครเป็น "บัญชีนักพัฒนา" (ระบุเป็น username เดียวกับที่ใช้ในแอป)
2. Founder รัน GitHub Actions workflow (ดู Handoff ข้อ 2) เพื่อเพิ่ม/ลบ/list username นั้นเข้า-ออกจากตาราง `developer_accounts` — ขั้นตอนนี้แทนที่ "admin UI" ตามที่ Product spec อนุญาตให้ข้ามได้ในตอนนี้
3. เมื่อ AI Coding เขียนฟีเจอร์ใหม่ในอนาคตที่ต้องการ staged-rollout: โค้ดของฟีเจอร์นั้นเรียก accessor ตัวเดียว (ดู Components) ได้ค่า `true`/`false` แล้วเลือก branch การ render/behavior เอง — Design ของฟีเจอร์นั้นๆ (คนละ task) เป็นคนกำหนดว่า "true" แสดงอะไรต่าง จาก "false"
4. เมื่อ Founder พอใจกับผลทดสอบภายในแล้วต้องการเปิดให้ทุกคน — **ไม่ใช่การ toggle ระบบนี้** แต่เป็นการที่ AI Coding ของฟีเจอร์นั้นๆ ลบเงื่อนไข `if (isDeveloperAccount)` ออกจากโค้ดของฟีเจอร์นั้น (หรือ Founder สั่งให้ทำ) — ระบบ allowlist นี้ยังคงอยู่ถาวรเพื่อใช้ซ้ำกับฟีเจอร์ถัดไป ไม่ได้ถูก "ปิด" เป็นระบบรวม

**Components**:

1. **Supabase table `public.developer_accounts`**
   ```sql
   create table if not exists public.developer_accounts (
     user_id uuid primary key references public.profiles (id) on delete cascade,
     label text,               -- optional เช่น 'Founder', 'QA tester' — ไว้อ่านเข้าใจง่ายเวลา list ผ่าน workflow เท่านั้น ไม่ใช้ในเงื่อนไข logic ใดๆ
     added_at timestamptz not null default now()
   );
   alter table public.developer_accounts enable row level security;
   -- เจตนา: ไม่มี select/insert/update/delete policy แม้แต่ policy เดียว
   -- เหมือน chat_lockdown_allowlist ของ WYN-122 — เข้าถึงได้เฉพาะผ่าน
   -- Supabase Management API (service-role) เท่านั้น ไม่มี authenticated
   -- user คนไหนอ่าน/เขียนตารางนี้ตรงๆ ได้แม้แต่แถวของตัวเอง
   ```

2. **ฟังก์ชันเช็คสถานะ `public.is_developer_account()`** — SECURITY DEFINER, ไม่รับ parameter (เช็คเฉพาะ `auth.uid()` ของผู้เรียกเท่านั้น ไม่มีทางเช็คบัญชีคนอื่น เพื่อไม่เปิดช่องให้ enumerate ว่าใครเป็นนักพัฒนา):
   ```sql
   create or replace function public.is_developer_account()
   returns boolean
   language sql
   security definer
   set search_path = public
   stable
   as $$
     select coalesce(
       exists (
         select 1 from public.developer_accounts where user_id = auth.uid()
       ),
       false
     );
   $$;
   grant execute on function public.is_developer_account() to authenticated;
   ```
   หมายเหตุถึง AI Coding: WYN-122's QA Round 1 เคยพบบั๊ก "ลืม grant execute" บนฟังก์ชัน internal helper ที่เรียกจาก RLS policy โดยตรง (`internal.chat_pair_allowed`) — ฟังก์ชันนี้ต่างออกไปตรงที่ **client เรียกตรง (RPC) ไม่ใช่ถูกเรียกจากภายใน RLS policy** จึงต้อง grant execute ให้ `authenticated` เสมอ (ไม่ใช่พึ่ง PUBLIC default) มิฉะนั้น RPC จะ error สำหรับทุกคนตั้งแต่ต้น — เขียน regression test ยืนยันจุดนี้ตรงๆ (ดู Handoff ข้อ 4)

3. **Client accessor (generic, ไม่ผูกกับฟีเจอร์ใดฟีเจอร์หนึ่ง)** — ไฟล์ใหม่แนะนำ `app/lib/core/developer_access/developer_access_service.dart` (ชื่อ/ที่ตั้งเป็นข้อเสนอแนะ ไม่บังคับเป๊ะ แต่ต้องอยู่ใน `core/` ไม่ใช่ใน `features/<ฟีเจอร์ใดฟีเจอร์หนึ่ง>/` เพราะต้องถูก import ข้ามฟีเจอร์ได้):
   - `Future<bool> isDeveloperAccount()` — เรียก RPC `is_developer_account`, คืน `false` เสมอถ้า error/timeout/ไม่มี session (try/catch ครอบ, ไม่โยน exception ต่อ — ตาม Design Rule fail-closed)
   - Cache ผลลัพธ์ต่อ auth session ปัจจุบัน (ไม่ต้องยิง RPC ซ้ำทุกครั้งที่เช็ค) — invalidate cache เมื่อ auth state เปลี่ยน (`onAuthStateChange`, เช่น anonymous session ใหม่หลัง sign-out/reinstall)
   - ไม่มี UI ผูกกับตัวมันเอง — เป็น pure data accessor เหมือน `ChatRepository` แต่ scope กว้างกว่า (ใช้ข้าม feature ได้)

**Interactions**: ไม่มี — ระบบนี้ไม่มี interaction ของตัวเอง เป็น boolean gate ล้วนๆ ที่ฟีเจอร์อื่นในอนาคตนำไปห่อ interaction ของตัวเอง (การออกแบบ interaction ของฟีเจอร์นั้นเป็นงาน design แยกของฟีเจอร์นั้น)

**States**:
1. **ผู้ใช้ทั่วไป (ค่าเริ่มต้น, 100% ของผู้ใช้ปัจจุบัน)** — `isDeveloperAccount()` คืน `false` เสมอ → ทุกฟีเจอร์ทำงานเหมือนวันนี้ทุกประการ ไม่มีการเปลี่ยนแปลงใดๆ ที่สังเกตได้
2. **บัญชีนักพัฒนาที่ยังไม่มีฟีเจอร์ใดผูกกับ flag นี้ (สถานะตอนที่ deploy งานนี้เสร็จใหม่ๆ)** — `isDeveloperAccount()` คืน `true` แต่ยังไม่มีผลต่อ UI ใดๆ เพราะยังไม่มีโค้ดฟีเจอร์ไหนเช็คมัน — ถูกต้องแล้ว งานนี้ส่งมอบแค่ "กลไก" ไม่ใช่ฟีเจอร์ที่ถูก gate จริง
3. **บัญชีนักพัฒนา + มีฟีเจอร์ X ผูก flag นี้ไว้แล้ว (อนาคต)** — เห็น behavior ของฟีเจอร์ X ตาม design spec ของฟีเจอร์นั้นๆ เอง (นอกขอบเขตงานนี้)
4. **RPC เช็คสถานะล้มเหลว (network error/timeout/session หมดอายุ)** — ต้องปฏิบัติเหมือน state 1 เป๊ะ (`false`) ห้ามแสดง error/spinner ค้าง/retry UI ใดๆ ที่ผู้ใช้ทั่วไปสังเกตเห็นได้ — นี่คือ state ที่สำคัญที่สุดที่ต้องทดสอบ เพราะเป็นจุดเดียวที่ระบบนี้จะ "โผล่" ให้ผู้ใช้ทั่วไปเห็นได้ถ้าเขียนผิด

**Responsive Behavior**: ไม่เกี่ยวข้อง — สถานะนี้กำหนดที่ระดับบัญชีผู้ใช้ (server-side, ผูกกับ `profiles.id`) ไม่ใช่ระดับ device/breakpoint จึงเหมือนกันทุกขนาดหน้าจอ ทุกแพลตฟอร์ม (mobile web/desktop web) โดยอัตโนมัติ

**Accessibility**: ไม่เกี่ยวข้องโดยตรง (ไม่มี UI element ใหม่จากงานนี้) — Design Rule: ฟีเจอร์ใดในอนาคตที่ผูกกับ flag นี้แล้วมี UI ของตัวเอง ต้องผ่านมาตรฐาน accessibility ปกติของ WYN ตาม `.wyn/docs/design/ds-008-responsive-accessibility.md` เหมือนฟีเจอร์อื่นทุกตัว — flag นี้ไม่ใช่ข้อยกเว้น

**Design Rules**:
- ห้าม expose สมาชิกใน `developer_accounts` ให้ client เห็นเป็น list ได้ไม่ว่าทางใด (ไม่มี SELECT policy แม้แต่ของแถวตัวเอง) — เปิดเผยแค่ boolean เดียวของ "ตัวเอง" ผ่าน `is_developer_account()` เท่านั้น
- ห้าม gate ทั้งแอปด้วย flag นี้ — เป็น per-feature/per-code-path เท่านั้น แต่ละฟีเจอร์เลือกเองว่าจะ wrap ส่วนไหน
- ฟีเจอร์ใหม่ที่ wrap เงื่อนไขนี้ **ต้องออกแบบ "false" ให้เท่ากับ behavior ปัจจุบัน 100% ตั้งแต่ release แรกที่มี flag** (ห้ามปล่อยให้ "false" กลายเป็น error/blank/loading ค้าง) — มิเรอร์หลักการเดียวกับที่ WYN-122 ใช้กับ state "Locked" (ต้องแยกจาก error/empty ให้ชัดเจนเสมอ แม้ในทิศทางกลับกัน)
- ชื่อ table/function คงความเป็น generic (`developer_accounts`/`is_developer_account`) ห้ามตั้งชื่อผูกกับฟีเจอร์ใดฟีเจอร์หนึ่ง (ต่างจาก WYN-122 ที่ตั้งใจผูกกับแชทเพราะตอนนั้นเป็น emergency lockdown เฉพาะฟีเจอร์เดียว) — เพื่อให้ใช้ซ้ำได้ตรงตามเจตนาของ Requirement 2 โดยไม่ต้องสร้างตาราง/ฟังก์ชันใหม่ทุกรอบ
- ถ้าในอนาคตมีความต้องการละเอียดกว่านี้ (เช่น เปิดเฉพาะบางฟีเจอร์ให้นักพัฒนาบางคนเท่านั้น ไม่ใช่ทุกคนใน allowlist) **ไม่ใช่ให้แก้ระบบนี้เอง** — ให้กลับมาเปิด task ใหม่ให้ AI Design ออกแบบชั้นเพิ่มเติม (เช่น per-feature flag table) เพราะเกินขอบเขตที่ Founder อนุมัติไว้ในรอบนี้ (boolean เดียว per-user)
- ห้ามเพิ่ม indicator/badge ใดๆ ในหน้า UI ที่บอกว่า "คุณคือบัญชีนักพัฒนา" ในงานนี้ (ไม่ใช่ scope ที่ขอ) — ถ้า Founder ต้องการภายหลังให้ขอเป็น task แยก

---

## ตัวอย่างประกอบ (illustrative เท่านั้น ไม่ใช่ scope ของงานนี้)

เพื่อให้ AI Coding เห็นภาพว่าฟีเจอร์ในอนาคตจะใช้กลไกนี้อย่างไร (ไม่ใช่สิ่งที่ต้อง implement ในรอบนี้):

```dart
final isDev = await developerAccessService.isDeveloperAccount();
if (isDev) {
  // แสดง/ทำงานแบบ build ใหม่ที่กำลังทดสอบ
} else {
  // behavior ปัจจุบันทุกประการ — ต้องเหมือนเดิม 100% กับก่อนมี flag นี้
}
```

งานนี้ (WYN-125 R2) จบแค่การมี `developerAccessService.isDeveloperAccount()` ใช้งานได้จริงเท่านั้น — ยังไม่มีฟีเจอร์ไหนถูก wrap ด้วยมันจริงในรอบนี้

---

## Handoff

ส่งต่อ **AI Coding** ตามลำดับแนะนำ:

1. **Schema** (`supabase/schema.sql`): เพิ่ม `public.developer_accounts` table และ `public.is_developer_account()` function ตาม Components ข้างบน — วางเป็น section ใหม่มี comment อธิบาย "ทำไม" เหมือน convention เดิมของไฟล์ (ดูตัวอย่าง section "WYN-122" เป็นแบบอย่าง) อย่าลืม `grant execute ... to authenticated;` (ดูหมายเหตุ QA-lesson ใน Components ข้อ 2)
2. **Management workflow** (ใหม่ เช่น `.github/workflows/wyn125-manage-developer-accounts.yml`): มิเรอร์โครงสร้าง `wyn122-toggle-chat-lockdown.yml` — `workflow_dispatch` พร้อม input `action` (choice: `list`/`add`/`remove`) และ input `username` (string, required เฉพาะตอน add/remove) — resolve username → `profiles.id` ก่อนเสมอ (ห้าม hardcode UUID), ถ้าหา username ไม่เจอให้ fail ชัดเจนไม่เงียบ, ใช้ Supabase Management API (`SUPABASE_ACCESS_TOKEN`/`SUPABASE_URL` secrets ที่มีอยู่แล้ว) แบบเดียวกับ workflow ต้นแบบ — นี่คือกลไกที่ทำให้ **เฉพาะคนที่ trigger GitHub Actions workflow บน repo นี้ได้ (คือ Founder) เท่านั้นที่เพิ่ม/ลบบัญชีนักพัฒนาได้จริง** ตรงตามที่ Product spec ขอ โดยไม่ต้องสร้าง admin UI ใหม่
3. **Client**: สร้าง `DeveloperAccessService` (หรือชื่อเทียบเท่า) ใน `app/lib/core/` ตาม Components ข้อ 3 — ต้อง fail-closed จริง (try/catch ครอบ RPC call, คืน `false` เมื่อ error) และ cache ต่อ session พร้อม invalidate เมื่อ auth state เปลี่ยน
4. **Tests**: เขียน `supabase/tests/wyn_125_developer_accounts_test.sh` มิเรอร์โครงสร้าง `wyn_122_chat_lockdown_test.sh` ครอบคลุมอย่างน้อย: (a) `authenticated`/`anon` เข้าถึงตาราง `developer_accounts` ตรงๆ ไม่ได้เลยทั้ง select/insert/update/delete, (b) `is_developer_account()` คืน `true` เฉพาะ user ที่อยู่ใน allowlist จริง คืน `false` สำหรับทุกคนอื่น รวม anonymous ใหม่ที่เพิ่งสร้าง, (c) ยืนยัน explicit `grant execute` ให้ `authenticated` ด้วย `has_function_privilege()` ตรงๆ (กัน bug class เดียวกับ WYN-122 Round 1), (d) allowlist ว่างเปล่า → ทุกคนได้ `false` (fail-safe ไม่ใช่ fail-open) — รัน regression suite เดิมทั้งหมดซ้ำเพื่อยืนยันไม่กระทบฟีเจอร์อื่น (ไม่มีฟีเจอร์ไหนถูกแก้ในรอบนี้ ผลควรคือ 0 regression)
5. **คำถามที่ต้องเช็คกับ Founder ก่อน/ระหว่าง implement** (ไม่บล็อก design ให้เริ่มงานได้เลย แต่ต้องยืนยันก่อน merge จริง): รายชื่อ username เริ่มต้นที่จะใส่เป็น "บัญชีนักพัฒนา" ชุดแรก — แนะนำเริ่มจาก `@warren` (Founder) เป็นอย่างน้อย เพิ่ม/ลดคนอื่นได้ตามที่ Founder ระบุภายหลังผ่าน workflow ในข้อ 2 ได้ตลอดเวลาโดยไม่ต้อง deploy ใหม่
6. **ไม่มี UI ใดถูกแก้ในรอบนี้** — ส่งต่อ **AI QA & Security** เมื่อ implement เสร็จ เน้นตรวจ (1) RLS lockdown ของตารางใหม่ตาม Design Rules ข้อแรก (2) fail-closed ของฟังก์ชันในทุก edge case (null auth, ไม่อยู่ใน allowlist, allowlist ว่าง) (3) grant execute ถูกต้อง (4) ไม่มี regression กับฟีเจอร์เดิมใดๆ (คาดว่าไม่มีเพราะไม่แตะโค้ดเดิมเลย) — ก่อนขึ้น production ตาม WORKFLOW.md (ห้ามข้าม QA)
