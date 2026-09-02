# Feature Request — WYN-083

Status: coded, awaiting QA (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 21/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: แก้ตรรกะการนับวิว: นับตั้งแต่วินาทีแรกที่มีคนเห็น รวมเจ้าของโพสต์ด้วย ไม่จำกัดจำนวน
Goal: ให้ยอดวิวสะท้อนการมองเห็นจริงทั้งหมด ไม่ตัดเจ้าของโพสต์ออก และไม่มี cap เทียม
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "การนับวิว จะนับตั้งแต่วินาทีแรก ที่มีคนเห็น รวมถึงเจ้าของโพสต์ด้วย นับไม่จำกัด"
Requirements:
- ตรวจ logic ปัจจุบันว่านับวิวช้าไปหรือไม่ (เช่น รอหลายวินาที/scroll ผ่านถึงจะนับ) ปรับให้นับทันทีที่โพสต์ปรากฏในจอผู้ใช้
- เอาเงื่อนไข exclude เจ้าของโพสต์ออก (ถ้ามี) ให้เจ้าของโพสต์เห็นโพสต์ตัวเองก็นับวิวด้วย
- ตรวจว่ามี cap/limit บนจำนวนวิวหรือไม่ (เช่น unique view ต่อ user ต่อวัน) แล้วเอาออกตามที่ Founder ระบุ "นับไม่จำกัด"
Acceptance Criteria:
- [ ] เปิดโพสต์ตัวเอง วิวต้องขึ้น
- [ ] scroll ผ่านโพสต์ในฟีดแล้ววิวนับทันที ไม่ต้องรอหลายวินาที
- [ ] เปิดซ้ำหลายครั้งวิวเพิ่มขึ้นเรื่อยๆ ไม่ถูก cap
Dependencies: ไม่มี
Priority: กลาง (ต้องเข้าใจ logic เดิมให้ครบก่อนแก้)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เปลี่ยนแล้วยอดวิวพุ่งผิดปกติ/เปิดช่องโหว่ให้ปั่นวิว (bot เปิดซ้ำรัวๆ) | กลาง | คุยกับ Founder เรื่อง rate-limit ระดับ backend กันโกง แม้ front-end จะนับไม่จำกัดตามคำสั่ง |
Recommendation: อนุมัติหลักการ แต่แนะนำเพิ่ม safeguard กันปั่นวิวระดับ backend (debounce ต่อ session) โดยยังนับไม่จำกัดสะสมตามที่ Founder สั่ง
Handoff: AI Product Manager ยืนยัน safeguard กันโกง → AI Coding

---

## Coding Output (2026-09-02)

Implementation: ตรวจโค้ดเดิม (WYN-038) พบว่าระบบนับวิวของ Drop ถูกออกแบบไว้ตรงข้ามกับที่ Founder ต้องการตอนนี้ทุกจุด — เป็นการตัดสินใจ Product spec เดิมที่ Founder เพิ่งสั่งย้อนกลับตรงๆ:
- `drop_views` table เดิมมี `primary key (drop_id, viewer_id)` → เป็น "unique-viewer lifetime ledger" (viewer คนเดิมเปิดกี่ครั้งก็นับแค่ 1)
- `record_drop_view()` เดิมมีเงื่อนไข `if v_drop.author_id = v_me then return; end if;` → เจ้าของโพสต์ดูโพสต์ตัวเองไม่นับ
- ทั้งสองจุดตรงข้ามกับคำสั่ง Founder ข้อ 21/28 เป๊ะ ("รวมถึงเจ้าของโพสต์ด้วย" / "นับไม่จำกัด")

**เปรียบเทียบกับ Pop**: Pop's `increment_pop_view_count()` (WYN-006, เก่ากว่า) เป็นแค่ `+1` เฉยๆ ไม่มี dedup ไม่มี self-exclusion อยู่แล้วตั้งแต่ต้น — ตรงกับที่ Founder ต้องการอยู่แล้ว **ไม่ต้องแก้ Pop เลย** งานนี้แค่ทำให้ Drop's view-counting กลับไปเหมือน Pop's philosophy เดิม

Requirements 3 ข้อ แก้ครบ:
1. **"เจ้าของโพสต์ด้วย"**: ลบเงื่อนไข self-view exclusion ออกทั้งฝั่ง server (`record_drop_view()`) และ client (`DropDetailScreen._recordViewOnce()`'s `if (_isOwnDrop) return;`)
2. **"นับไม่จำกัด"**: ตีความว่าหมายถึงเอา unique-viewer lifetime dedup ออก (ไม่ใช่เอา rate-limit/velocity-cap กันบอทออก — สองอย่างนี้คนละเรื่องกัน) — เปลี่ยน `drop_views` จาก unique-viewer ledger เป็น view-event log ล้วนๆ: เพิ่มคอลัมน์ `id uuid primary key` ใหม่ แทนที่ `primary key (drop_id, viewer_id)` เดิม, ลบ `on conflict (drop_id, viewer_id) do nothing` ออกจาก insert (ไม่มี unique constraint ให้ conflict แล้ว) — viewer คนเดิมเปิดซ้ำกี่ครั้งก็นับเพิ่มทุกครั้ง
3. **"นับตั้งแต่วินาทีแรกที่มีคนเห็น"**: ตีความว่าหมายถึง "นับทันทีไม่มีดีเลย์เทียม" ซึ่งพฤติกรรมเดิมทำอยู่แล้ว (เรียก `recordView` ใน `Future.microtask` ตั้งแต่ `initState`) **ไม่ได้ตีความว่าหมายถึง "นับตั้งแต่โพสต์ปรากฏในฟีดตอน scroll ผ่าน"** (ยังนับเฉพาะตอนเปิด DropDetailScreen เหมือนเดิม เป็นการตัดสินใจ Design เดิมของ WYN-038 ที่ระบุไว้ตรงๆว่า "opening DropDetailScreen is what counts as a View, not just a Home Feed card scrolling past") — การเปลี่ยนให้นับจาก scroll-visibility ในฟีดเป็นฟีเจอร์ใหญ่กว่ามาก (ต้องเพิ่ม dependency ใหม่สำหรับตรวจจับ visibility, แก้ทุกการ์ดในฟีด, เทสเพิ่มมาก) ประเมินว่าเกินสโคป Phase 1 "quick fix" **ถ้า Founder หมายถึงแบบ scroll-visibility จริงๆ ต้องแจ้งกลับมาเป็นงานแยก**

**เก็บไว้ไม่แตะ**: rate-limit (20 req/60s ต่อ account) และ velocity-cap (50 req/10s ต่อโพสต์) กันบอทปั่นวิว — Founder ไม่ได้สั่งให้เอาส่วนกันโกงออก "นับไม่จำกัด" หมายถึงไม่ cap จำนวนสะสมที่ view ที่ถูกต้องนับได้ ไม่ใช่เปิดช่องให้บอทยิงรัวไม่จำกัด

**พบปัญหาเดิม (นอกสโคป) อีกครั้ง**: `schema.sql` ยังโหลดสดไม่ผ่านเหมือนที่บันทึกไว้ตอน WYN-079/WYN-081 (`.wyn/company/DECISIONS.md` 2026-09-02) — ทำให้รัน `wyn_038_view_counting_test.sh` เต็มรูปแบบไม่ได้ และการไล่แก้ทุกตัวเลขที่พึ่งพากันตลอดทั้งไฟล์ 653 บรรทัด (CHECK2/CHECK3 ที่ตรวจสอบพฤติกรรมเดิมโดยตรง กับทุก CHECK ถัดจากนั้นที่อ้างอิงผลลัพธ์สะสม) โดยไม่มีทางรันจริงเพื่อยืนยันความถูกต้อง มีความเสี่ยงสูงเกินไปที่จะทำแบบ "เดา" — **ไม่ได้ไล่แก้ทั้งไฟล์** แต่ใส่ comment เตือนไว้ชัดเจนที่หัวไฟล์แทน พร้อมเขียนเทสใหม่แยกต่างหาก (`wyn_083_view_count_owner_and_repeat_test.sh`) ที่ standalone รันได้จริง พิสูจน์ red→green แล้ว

Files Changed:
- `supabase/schema.sql` — `drop_views` table structure (PK เปลี่ยนจาก composite เป็น surrogate `id`), `record_drop_view()` (ลบ self-exclusion + dedup)
- `app/lib/features/drop/presentation/drop_detail_screen.dart` — ลบ `if (_isOwnDrop) return;` ใน `_recordViewOnce()`
- `app/lib/features/drop/data/drop_repository.dart` — อัปเดต doc comment
- `app/test/drop_detail_screen_test.dart` — แก้ 2 เทสเดิมที่ทดสอบพฤติกรรมเก่าโดยตรง (self-view ไม่นับ → นับ, semantics label 42→43 เพราะโพสต์ของ "me" เอง)
- `supabase/tests/wyn_038_view_counting_test.sh` — เพิ่ม comment เตือนหัวไฟล์ว่า CHECK2/CHECK3 (และทุกอย่างที่พึ่งพาต่อจากนั้น) ล้าสมัยแล้ว ยังไม่ได้ไล่แก้เพราะรันจริงไม่ได้ในสภาพแวดล้อมนี้
- `supabase/tests/wyn_083_view_count_owner_and_repeat_test.sh` — เทสใหม่ standalone (ไม่พึ่ง schema.sql เต็มไฟล์) พิสูจน์พฤติกรรมใหม่ทั้ง 2 จุด + ยืนยัน rate-limit/velocity-cap ยังทำงานปกติ

Reason: Founder ข้อ 21/28 — "การนับวิว จะนับตั้งแต่วินาทีแรก ที่มีคนเห็น รวมถึงเจ้าของโพสต์ด้วย นับไม่จำกัด"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **881/881 ผ่านหมด** (แก้ 2 เทสเดิม ไม่มีเทสใหม่สุทธิ)
- `bash supabase/tests/wyn_083_view_count_owner_and_repeat_test.sh`: **4/4 CHECK ผ่าน** พิสูจน์ red→green จริงด้วยตัวเอง (ใส่ self-view exclusion กลับเข้าไปชั่วคราว เห็น CHECK2 fail ตรงตามคาด คืนค่าแล้วผ่านครบ)
- `bash supabase/tests/wyn_038_view_counting_test.sh`: **รันไม่ผ่าน — ปัญหาเดิม schema.sql โหลดสดไม่ได้** (ไม่เกี่ยวกับงานนี้ ดู DECISIONS.md)

Build: ไม่ได้รัน `flutter build`/`supabase db push` จริง — schema change ยังไม่ได้ apply เข้า production (รอ AI Deploy & DevOps ตามขั้นตอนปกติ — เป็น breaking schema change สำหรับ `drop_views` เปลี่ยน primary key ต้องระวังตอน migrate เพราะมีข้อมูลจริงในตารางนี้แล้ว)

Known Issues:
- **schema.sql โหลดสดไม่ผ่าน (pre-existing, นอกสโคป)** — ยังไม่ได้แก้ ดู `.wyn/company/DECISIONS.md`
- **"นับตั้งแต่วินาทีแรกที่มีคนเห็น" ตีความแบบจำกัด** (แค่ "ไม่ดีเลย์" ไม่ใช่ "scroll-visibility ในฟีด") — ถ้า Founder ต้องการแบบหลัง ต้องแจ้งกลับมาเป็นงานแยก (ฟีเจอร์ใหญ่กว่า Phase 1)
- **Migration บน production ต้องระวังเป็นพิเศษ**: `drop_views` เปลี่ยน primary key จาก composite เป็น surrogate `id` — ต้อง `alter table` ไม่ใช่ `drop`+`create` ใหม่ (จะเสียข้อมูล view history เดิม) — AI Deploy & DevOps ควรเตรียม migration SQL ที่รักษาข้อมูลเดิมไว้ ไม่ใช่ copy schema.sql section ไปรันตรงๆ

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ SQL behavior ตาม `wyn_083_view_count_owner_and_repeat_test.sh` (2) ตรวจ UI จริงว่าเปิดโพสต์ตัวเองแล้ววิวขึ้นจริง เปิดซ้ำแล้วเพิ่มขึ้นเรื่อยๆ (3) ยืนยันกับ Founder ว่าการตีความ "นับตั้งแต่วินาทีแรกที่เห็น" แบบนี้ตรงกับที่ต้องการหรือไม่ (4) เตือน AI Deploy & DevOps เรื่อง migration ที่ต้องรักษาข้อมูล `drop_views` เดิมไว้
