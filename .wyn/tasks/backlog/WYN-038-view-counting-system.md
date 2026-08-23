# Product Task — WYN-038

Status: backlog
Owner: AI Product Manager

Feature: View Counting System (Unique Viewer / Rate Limit / Bot Detection) — Drop

Goal: ให้ Drop มีระบบนับ View ที่น่าเชื่อถือพอจะใช้เป็นสัญญาณ Trending ในอนาคต — task ที่ห้าของ Phase 3 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 6 "VIEW SYSTEM": "นับ Views อย่างมีระบบ ไม่ใช่ทุก Refresh = 1 View ต้องมี: Unique Viewer logic, Rate limiting, Bot detection, Suspicious traffic detection — เพื่อป้องกันการปั่นยอด" — และเป็น Dependency ตรงของ Phase 4's WYN-041 (Trending Engine v2): "WYN-038 (View system ให้ข้อมูล Trending Score)"

Target User: ทุกผู้ใช้ที่เปิดดู Drop (ผู้ถูกนับ View) และเจ้าของ Drop/ทีม Trending ในอนาคต (ผู้ใช้ข้อมูล View เพื่อวัดความนิยม/จัดอันดับ)

Problem: ตอนนี้ **Drop ไม่มีระบบนับ View เลยแม้แต่จุดเดียว** — `home_feed`/`saved_feed` view (WYN-007/WYN-013) จองคอลัมน์ `view_count` ไว้แล้วแต่ hardcode เป็น `null::bigint` สำหรับแถว Drop ทุกแถว (`supabase/schema.sql` บรรทัด 471, 556) และ `Drop` model/`DropRepository`/`DropDetailScreen`/`HomeDropCard` ไม่มี field/UI ของ view count เลย ทำให้ WYN-041 (Trending Engine v2) ที่ต้องพึ่งข้อมูลนี้ทำต่อไม่ได้ — Pop (WYN-006) มี `pops.view_count` อยู่แล้วแต่เป็น **counter ธรรมดาที่นับซ้ำได้ไม่จำกัด** (`increment_pop_view_count()` แค่ `+1` ทุกครั้งที่เรียก ไม่มี dedup/rate-limit ระดับ DB เลย มีแค่ client-side flag `_viewRecorded` กันเรียกซ้ำ "ภายในเซสชันเดียว" เท่านั้น — เปิดแอปใหม่/เข้าคลิปซ้ำนับเพิ่มได้เรื่อยๆ) ซึ่ง WYN-006's QA เคยพบและบันทึกไว้แล้วว่าเป็น Minor gap ไม่ block ตอนนั้น

Requirements:

**ขอบเขต: Drop เท่านั้น** — Pop ถูกถอดออกจาก Bottom Nav แล้วตั้งแต่ WYN-024 (V1.0.0 ยังไม่เปิด WYN Pop จนกว่าจะถึง V3) โค้ด/DB ของ Pop คงไว้แต่ไม่มีใครเข้าถึงได้จริงผ่าน UI ปกติ — การลงทุนแก้ระบบ View ของ Pop ตอนนี้จะไม่มีผลกับผู้ใช้จริง จึง **ไม่แตะ `pops.view_count`/`increment_pop_view_count()` เลยในรอบนี้** (ตัดสินใจโดย Product เพื่อลดความเสี่ยง/ขอบเขต ตามกติกา "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น") — ถ้า Founder ต้องการเปิด Pop กลับมาในอนาคต ให้ยก pattern เดียวกันของ Drop ไปทำซ้ำเป็น follow-up แยก

**Unique Viewer logic**
- นับ View แบบ **unique ต่อผู้ใช้ต่อ Drop ตลอดกาล (lifetime, นับครั้งเดียวตลอดไป)** ไม่ใช่นับทุกครั้งที่เปิดซ้ำ/refresh — ผู้ใช้คนเดิมเปิด Drop เดิมซ้ำกี่ครั้งก็นับแค่ 1
- **เจ้าของ Drop เปิดดู Drop ตัวเองไม่นับเป็น View** (ป้องกันการปั่นยอดง่ายๆ ด้วยการเปิดดูโพสต์ตัวเองซ้ำๆ)
- จุดที่ถือว่าเป็น "View" จริง = ผู้ใช้เปิด **`DropDetailScreen`** (ไม่ใช่แค่การ์ดเลื่อนผ่านใน Home Feed — scroll ผ่านไม่ใช่การ "ดู" จริงและปลอมง่ายด้วยการเลื่อน feed เร็วๆ) มิเรอร์แนวคิดเดียวกับที่ Pop นับตอนวิดีโอเริ่มเล่นจริง ไม่ใช่ตอนการ์ด thumbnail ปรากฏ

**Rate limiting**
- จำกัดจำนวน View record ใหม่ที่ **1 บัญชีสร้างได้ต่อหน่วยเวลา** (ป้องกันบัญชี/สคริปต์เดียวไล่เปิด Drop จำนวนมากเร็วๆ เพื่อปั่นยอดให้พวกเดียวกัน) — เกินโควตาแล้ว **เงียบๆ ไม่นับเพิ่ม ไม่ error** (การนับ View ไม่ควรทำให้ UI ล่ม/ผู้ใช้ปกติเห็น error)

**Bot detection / Suspicious traffic detection**
- **ขอบเขตที่ทำได้จริงตอนนี้** (ดู Risks): ไม่มี CAPTCHA/device fingerprint/IP tracking ในระบบ ทำ full bot detection ไม่ได้ในรอบนี้ — ใช้ 3 กลไกร่วมกันแทนเป็นแนวป้องกันเชิงพฤติกรรมระดับ V1:
  1. Self-view exclusion (ด้านบน)
  2. Rate limiting ต่อบัญชี (ด้านบน)
  3. **Velocity cap ต่อ Drop**: จำกัดจำนวน View record ใหม่ที่ **1 Drop รับได้ต่อหน่วยเวลาสั้นๆ** (ป้องกัน bot ring หลายบัญชีรุมกด Drop เดียวพร้อมกันเพื่อปั่นให้ดูเหมือนกำลังไวรัล) — เกินโควตาแล้วเงียบๆ ไม่นับเพิ่มเช่นกัน

**แสดงผล**
- เชื่อมค่า `view_count` จริงเข้า `home_feed`/`saved_feed` view แทน `null::bigint` เดิมสำหรับแถว Drop (คอลัมน์นี้ถูกจองไว้ตั้งแต่ WYN-007 แล้ว)
- แสดง View count บน `DropDetailScreen` (มิเรอร์ icon ตาที่ `PopClipView` ใช้อยู่แล้ว) และบน `HomeDropCard` (มิเรอร์ icon+เลขที่ `HomePopCard` ใช้อยู่แล้วกับ Pop — `HomeFeedItem.viewCount` field มีอยู่แล้วแค่ยังไม่ได้ใช้ฝั่ง Drop)

Acceptance Criteria:
- [ ] เปิด `DropDetailScreen` ของ Drop คนอื่นครั้งแรก → View count ของ Drop นั้นเพิ่ม 1
- [ ] เปิด `DropDetailScreen` ของ Drop เดิมซ้ำอีกหลายครั้ง (คนละเซสชัน/เปิดแอปใหม่) โดยผู้ใช้คนเดิม → View count **ไม่เพิ่มอีก** (นับแค่ครั้งแรกครั้งเดียว ตรวจสอบด้วย SQL โดยตรง ไม่ใช่แค่ดู UI)
- [ ] เจ้าของ Drop เปิดดู Drop ตัวเอง → View count **ไม่เพิ่ม**
- [ ] ผู้ใช้คนละคนเปิด Drop เดียวกัน → View count เพิ่มตามจำนวนคนจริง (unique ต่อคน)
- [ ] จำลองบัญชีเดียวเรียก record-view RPC ตรงถี่ๆ เกินโควตา rate-limit ต่อบัญชี → รายการเกินโควตาไม่ถูกนับ (ตรวจด้วย SQL โดยตรง), ไม่มี error กระเด็นกลับไปที่ client
- [ ] จำลองหลายบัญชีเรียก record-view RPC ตรงถี่ๆ กับ Drop เดียวกันเกินโควตา velocity-cap ต่อ Drop → รายการเกินโควตาไม่ถูกนับ, ไม่มี error
- [ ] ผู้ใช้ทั่วไป (ไม่ใช่เจ้าของ) เรียก SELECT ตรงบนตาราง View record **เห็นได้เฉพาะแถวของตัวเอง** (ว่าตัวเองเคยดู Drop ไหนบ้าง) **เห็นไม่ได้ว่าคนอื่นดู Drop ไหนบ้าง** (ป้องกัน privacy leak ว่าใครดูอะไร มิเรอร์บทเรียนจาก WYN-029's actor-identity-leak bug) — แต่ View count ที่แสดงใน Home Feed/Drop Detail ต้องยังถูกต้อง/ตรงกันสำหรับทุกคนที่ดู (ไม่ใช่แค่เจ้าของ/คนที่เคยดูเอง)
- [ ] Home Feed การ์ด Drop และหน้า `DropDetailScreen` แสดง View count จริงตรงกับค่าใน DB
- [ ] Regression: Drop ที่ถูก soft-delete (WYN-037) ไม่ถูกนับ View เพิ่มได้อีก, การนับ View ไม่กระทบ Like/Comment/Save/ReDrop/Poll count เดิม, Pop's view count เดิมยังทำงานแบบเดิมไม่เปลี่ยนแปลง (ไม่ถูกแตะในรอบนี้)

Dependencies: WYN-005 (Drop core), WYN-007 (Home Feed's `home_feed` view — คอลัมน์ `view_count` ถูกจองไว้แล้ว), WYN-013 (`saved_feed` view มิเรอร์ปัญหาเดียวกัน), WYN-037 (soft delete — View ต้องเช็คว่า Drop ยังไม่ถูกลบ) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P1 — task ที่ห้าของ Phase 3 ตามลำดับ Roadmap ต่อจาก WYN-034/035/036/037 และเป็น Dependency ตรงของ WYN-041 (Phase 4)

Risks:
- **ไม่ใช่ bot detection แบบเต็มรูปแบบ** — Master Spec เขียนกว้างว่า "Bot detection" แต่ระบบนี้ไม่มี CAPTCHA/device fingerprint/IP logging/ML ใดๆ (repo เป็น Flutter+Supabase ล้วนๆ ไม่มี backend service แยก) การตรวจจับ bot จริงจังต้องมี infra เพิ่มที่ยังไม่มี — ยอมรับ scope reduction นี้: ใช้ self-view exclusion + rate-limit ต่อบัญชี + velocity-cap ต่อ Drop แทน เป็นแนวป้องกันเชิงพฤติกรรมที่ทำได้จริงด้วย SQL ล้วนๆ ตอนนี้ ถ้า Founder ต้องการมากกว่านี้ต้องคุยเรื่อง infra เพิ่มเติมเป็น follow-up
- **ตัวเลขโควตา rate-limit/velocity-cap เป็นค่าที่ Product กำหนดเองชั่วคราว** ไม่มีข้อมูล traffic จริงมาอ้างอิง (แอปยังไม่ deploy ขึ้น production จริง) — เสนอตัวเลขเริ่มต้นให้ Design/Coding ใน Recommendation แต่ต้องปรับได้ง่ายภายหลังเมื่อมีข้อมูลจริง (เก็บเป็นค่าคงที่ในโค้ด ไม่ hardcode กระจัดกระจาย)
- **View count ที่ Client เพิ่มแบบ optimistic อาจไม่ตรงกับ DB ชั่วคราว** ถ้า RPC เงียบๆ ปฏิเสธ (เกิน rate-limit/velocity-cap หรือเป็นเจ้าของ Drop เอง) — ค่าจะกลับมาตรงเองเมื่อ feed refresh ครั้งถัดไป มิเรอร์ risk เดียวกับที่ Pop (WYN-006) ยอมรับไว้แล้วโดยไม่มีปัญหา
- **ไม่มี physical purge/archival job สำหรับ View record เก่า** — ตารางจะโตเรื่อยๆ ตามจำนวน (Drop × unique viewer) ไม่มี TTL/cron เหมือนหลาย task ก่อนหน้าที่ยอมรับ gap เดียวกัน (ระบบยังไม่มี cron infrastructure จริง) — ยอมรับไว้ก่อน ปรับปรุงเมื่อ scale จริงบังคับ

Recommendation:
1. Schema: ตารางใหม่ `drop_views` (`drop_id references drops(id) on delete cascade`, `viewer_id references profiles(id) on delete cascade`, `created_at timestamptz not null default now()`, **primary key (drop_id, viewer_id)** — ตัว primary key เองคือกลไก unique-viewer dedup ระดับ DB โดยตรง ไม่ต้องเขียน logic แยก)
2. **ไม่มี raw client INSERT policy เลย** — เขียนผ่าน RPC เดียว `record_drop_view(drop_id uuid)` (SECURITY DEFINER) เท่านั้น มิเรอร์ pattern `increment_pop_view_count()`/`edit_drop()` เดิม ภายในฟังก์ชันเช็คตามลำดับแล้ว **no-op เงียบๆ (ไม่ raise exception)** ถ้าข้อใดข้อหนึ่งไม่ผ่าน: (a) Drop ไม่มีอยู่จริงหรือถูก soft-delete แล้ว (เช็คแบบเดียวกับ `internal.is_drop_deleted()` ที่ WYN-037 สร้างไว้แล้ว) (b) `auth.uid()` คือเจ้าของ Drop เอง (c) บัญชีนี้มี insert เข้า `drop_views` เกิน **20 ครั้งในช่วง 60 วินาทีที่ผ่านมา** (rate-limit ต่อบัญชี — นับจาก `count(*) from drop_views where viewer_id = auth.uid() and created_at > now() - interval '60 seconds'`) (d) Drop นี้มี insert เข้า `drop_views` เกิน **50 ครั้งในช่วง 10 วินาทีที่ผ่านมา** (velocity-cap ต่อ Drop) — ถ้าผ่านทุกเงื่อนไข ค่อย `insert into drop_views ... on conflict (drop_id, viewer_id) do nothing` (กัน race condition ซ้อนกับ primary key อีกชั้น)
3. **SELECT policy ของ `drop_views` ต้องจำกัดแค่ `auth.uid() = viewer_id`** (แต่ละคนเห็นได้แค่ว่าตัวเองเคยดู Drop ไหนบ้าง) — **ห้ามเปิด select-all-authenticated แบบที่ `drop_likes`/`drop_comments` ใช้** เพราะ View ต่างจาก Like ตรงที่เป็นข้อมูลที่ผู้ใช้ไม่ได้ตั้งใจเปิดเผยว่า "ใครดูอะไร" (มิเรอร์บทเรียนจาก `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` ที่เคยพบว่า identity รั่วไหลเพราะ SELECT policy กว้างเกินไป) — ปัญหาคือถ้า SELECT ถูกจำกัดแบบนี้ `count(*)` subquery ใน `home_feed`/`saved_feed` (ที่เป็น `security_invoker = true`) จะเห็นแค่แถวของผู้ดู feed คนนั้นเอง ทำให้ View count ที่แต่ละคนเห็นไม่ตรงกัน (ผิด) — **ทางแก้**: สร้างฟังก์ชันแยก `public.drop_view_count(drop_id uuid) returns bigint` (**SECURITY DEFINER**, bypass RLS ของ `drop_views` ตรงๆ เพื่อนับทุกแถวจริง คืนแค่ตัวเลข ไม่คืนแถว/viewer identity ใดๆ ออกมาเลย) แล้วให้ `home_feed`/`saved_feed` เรียก `public.drop_view_count(d.id) as view_count` แทน correlated subquery ตรงๆ — วิธีนี้ทั้งสองอย่างได้พร้อมกัน: เลขถูกต้องสำหรับทุกคน + ไม่มีใครเห็น raw viewer list ของคนอื่นได้เลยไม่ว่าทางไหน
4. Flutter: `Drop` model เพิ่ม `viewCount` (non-null, default 0 จาก DB เสมอเพราะ `drop_view_count()` คืน 0 ไม่ใช่ null) + `withExtraView()` มิเรอร์ `Pop`'s เดิม — `DropRepository` เพิ่ม `recordView(dropId)` เรียก RPC `record_drop_view` (fire-and-forget, `catchError` กลืน error เหมือน Pop เพราะ View count ไม่ควรบล็อก/ทำ error UI) — `DropDetailScreen` เพิ่ม `_viewRecorded` flag เรียกครั้งเดียวตอนเปิดหน้า (มิเรอร์ `PopClipView`'s `_recordView()` ทุกจุด) — `HomeFeedItem.toDrop()` ต้องส่ง `viewCount` ต่อเข้า `Drop` ด้วย (ตอนนี้ยังไม่ส่ง) — `HomeDropCard` เพิ่ม icon+เลข view count มิเรอร์ `HomePopCard` บรรทัดที่ใช้ `Icons.visibility_outlined`
5. ค่าคงที่ rate-limit (20/60s) และ velocity-cap (50/10s) ให้ประกาศเป็นตัวแปร/comment อธิบายเหตุผลไว้ต้นฟังก์ชัน SQL ชัดเจนว่าเป็นค่าที่ Product กำหนดเองชั่วคราว ปรับได้ภายหลัง (มิเรอร์ที่ WYN-037 ทำกับกรอบเวลา 30 นาที/30 วัน)

Handoff: AI Design — ยืนยัน UI ตำแหน่ง/สไตล์ icon view count บน `DropDetailScreen`/`HomeDropCard` (มิเรอร์ Pop ที่มีอยู่แล้วให้มากที่สุดเพื่อความสม่ำเสมอทั้งแอป), ทบทวน schema/RPC/RLS design ข้อ 1-5 ด้านบนก่อนส่งต่อ AI Coding — โดยเฉพาะจุดที่ 3 (privacy ของ `drop_views` SELECT policy + `drop_view_count()` SECURITY DEFINER) ที่เป็นจุดเสี่ยงด้าน security สูงสุดของ task นี้ ต้องตรวจทานให้แน่ใจก่อน
