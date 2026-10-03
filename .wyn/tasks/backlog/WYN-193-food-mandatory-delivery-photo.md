# Product Task — WYN-193 — WYNOS Food: บังคับแนบรูปทุกครั้งที่ส่งสำเร็จ

Status: review — QA & Security PASS (round 2), รอ CTO final review; migration ยังไม่ apply production
Owner: AI Product Manager
Date: 2026-10-03

## Founder direction

- ยังไม่มีระบบไรเดอร์ ร้านจ้างคนส่งภายนอกเอง คนส่งไม่มีบัญชี WYNOS
- เมื่อส่งเสร็จ คนส่งส่งรูปให้ร้าน (ช่องทางนอกระบบ เช่น LINE) แล้วร้านแนบรูปในแอป Merchant ให้ลูกค้าเห็น
- ตอนนี้มีร้านเดียว (ร้าน WYNOS) แต่ทุกอย่างต้องใช้ได้กับร้านอื่นในอนาคตด้วยกติกาเดียวกัน
- Founder (2026-10-03): **"บังคับให้ร้านแนบรูปทุกครั้ง"**
- Founder (2026-10-03): **"เอาตามที่ว่าดีที่สุดเลย"** → อนุมัติ WYN-193 + แจ้งเตือนลูกค้าเมื่อส่งถึง (ตามที่ AI แนะนำ); ยังไม่ทำการบันทึกข้อมูลคนส่ง

## Feature

ร้านต้องแนบรูปหลักฐานการจัดส่งทุกครั้งก่อนกด "ส่งแล้ว" ทั้งแบบ "ส่งถึงมือ" (`direct`) และ "วางไว้" (`dropoff`)

## Goal

ลูกค้าทุกคนเห็นรูปยืนยันว่าอาหารถึงแล้ว และร้านมีหลักฐานเมื่อเกิดข้อโต้แย้ง

## Target User

- ร้านค้า (owner / admin / manager / orders / delivery) ใน WYNOS Merchant
- ลูกค้า WYNOS Food

## Problem

ปัจจุบัน `food_complete_delivery` บังคับรูปเฉพาะ `dropoff` ถ้าเลือก `direct` ระบบไม่รับรูปเลย (`image_path` ถูกตั้งเป็น null) ลูกค้าจึงไม่เห็นหลักฐาน

## Requirements

1. Server (`food_complete_delivery`) ปฏิเสธการปิดงานส่งที่ไม่มีรูป ทั้ง `direct` และ `dropoff`; path ต้องอยู่ใต้ `delivery/<order_id>/` ของออเดอร์นั้น
2. `direct` เก็บรูปด้วย (ไม่ทิ้ง `image_path` แล้ว)
3. `dropoff` ยังต้องระบุจุดวางเหมือนเดิม; `direct` ไม่ต้อง
4. หน้า Merchant: ช่องแนบรูปแสดงทุกวิธีส่ง ปุ่ม "ส่งแล้ว" กดไม่ได้จนกว่าจะเลือกรูป ข้อความบอกชัดว่า "แนบรูปจากคนส่ง"
5. รูปตรวจชนิด/ขนาดตามกติกา upload ที่มีอยู่ (`uploadFoodPrivateImage` + storage policy); เห็นได้เฉพาะลูกค้าเจ้าของออเดอร์และร้าน
6. หน้าลูกค้า: แสดงรูปทั้งแบบ `direct` และ `dropoff` (ปัจจุบันรองรับแล้ว ตรวจยืนยัน)
7. ออเดอร์ที่ส่งสำเร็จไปแล้วก่อนหน้านี้ไม่ถูกแก้ไข (ไม่ backfill, ไม่เปลี่ยน constraint ที่ทำให้ข้อมูลเก่าผิด)
8. ใช้กับทุกร้านเหมือนกัน ไม่มี setting รายร้าน
9. แจ้งเตือนลูกค้า (in-app + push ผ่าน `public.notifications` เดิม, type `system`) เมื่อออเดอร์ส่งถึง
10. Server ตรวจว่ารูปถูก upload จริงใน bucket `food-private` และ path ไม่มี `..`

## Acceptance Criteria

1. เรียก RPC `direct` โดยไม่มีรูป → error; มีรูปถูก path → `delivered` และเก็บ `image_path`
2. เรียก RPC `dropoff` ไม่มีรูปหรือไม่มีจุดวาง → error (เหมือนเดิม)
3. path รูปของออเดอร์อื่น → error
4. ผู้ใช้ที่ไม่มีบทบาทในร้าน → error (เหมือนเดิม)
5. UI Merchant ไม่ให้กด "ส่งแล้ว" ถ้ายังไม่แนบรูป ทั้งสองวิธี
6. ลูกค้าเห็นรูปในหน้าออเดอร์ทั้งสองวิธี; ลูกค้าคนอื่นเปิดรูปไม่ได้
7. ข้อมูลออเดอร์เก่าไม่เปลี่ยน
8. ลูกค้าได้รับแจ้งเตือน "ออเดอร์ #N ส่งถึงแล้ว" หนึ่งครั้งต่อออเดอร์
9. Supabase test (`supabase/tests/`) + browser tests ของ merchant/food ผ่าน

## Dependencies

- Migration ใหม่ที่ `create or replace` `food_complete_delivery` (ไม่ destructive, rollback = นิยามเดิมใน `migrations_wynos_merchant_core_completion_v1.sql`)
- การ apply migration production ต้องได้ Founder approval แยก

## Priority

P0 (ก่อนเปิด Food ให้ลูกค้าทั่วไป)

## Risks

- คนส่งลืมส่งรูป → ร้านปิดงานไม่ได้; ยอมรับได้เพราะเป็นกติกาที่ Founder ต้องการ (ร้านต้องตามรูปจากคนส่ง)
- รูปใหญ่จากมือถือ → ใช้ limit upload เดิม

## Out of scope (คุยแยก)

- บันทึกชื่อ/เบอร์/ค่าจ้างคนส่ง
- พื้นที่จัดส่ง
- ระบบไรเดอร์กลาง

## Handoff

Founder อนุมัติ PRD → Full-Stack (migration + UI + tests) → QA & Security → CTO review → merge → apply migration หลัง Founder อนุมัติ

## Implementation (2026-10-03)

- `supabase/migrations_wynos_food_delivery_photo_required_v1.sql` — replace `food_complete_delivery` เท่านั้น
- `web/components/merchant/wynos-merchant-app.tsx` — ช่องแนบรูปทุกวิธีส่ง (เลือกจากคลังรูปได้ เพราะรูปมาจากคนส่ง), ปุ่มยืนยันปิดจนกว่าจะมีรูป, ข้อความ "ร้านจ้างคนส่ง"
- `web/tests/browser/wynos-merchant.spec.ts` — contract test WYN-193 (และแก้ label "วางสินค้าไว้ที่ไหน?" ที่ test เดิม fail อยู่แล้ว)

## Verification

- Local PostgreSQL 16 + stubs: outsider, ไม่มีรูป, รูปของออเดอร์อื่น, รูปไม่มีจริง, `..`, dropoff ไม่มีจุดวาง → ปฏิเสธทั้งหมด; direct/dropoff มีรูป → delivered, เก็บรูป, แจ้งเตือนผู้ซื้อ 1 ครั้ง; ซ้ำ → ปฏิเสธ
- `wynos-merchant.spec.ts` ผ่านทั้ง 3 projects; `npm run typecheck` ผ่าน; `npm run lint` 0 errors
- `wynos-food-developer-preview.spec.ts` test แรก fail ก่อนแก้อยู่แล้ว (คาดหวัง `is_developer_account`) — ไม่เกี่ยวกับ WYN-193

## Found during review (separate task)

- WYN-194: food-private storage อ่าน/อัปโหลดข้ามร้านได้ เมื่อมีร้านที่ 2

## QA round 1 (2026-10-03) — FAIL → fixed

- H1: PostgREST embeds `food_delivery_proofs` one-to-one (unique `order_id`) as an object, so `?.[0]` hid the photo from customer and Merchant (pre-existing on main). Fixed with `orderDeliveryProof()` in `web/lib/food-merchant.ts` / `web/lib/food-customer.ts` + regression test.
- M1: behaviour test `supabase/tests/wynos_food_delivery_storage_test.sh` (local PostgreSQL; `PSQL="sudo -u postgres psql"`), mutation-checked.
- L1: `p_method is null` rejected. L2: location note trimmed of tabs/newlines.
- L3 (open, product): delivered notification ignores the in-app 'system' preference, same as the other Food transactional notifications (paid, refund).
- L4 (open, follow-up): wrong photo cannot be replaced; orphan upload if the RPC fails after upload.

## QA round 2 (2026-10-03) — PASS

- Fixes for H1, M1, M2, L1 and L2 were verified. 9 of 11 mutants were caught; the 2 that slipped through (L1 rollback, legacy slip branch) are now caught as well, because `expect_fail` checks the error message and the test includes a legacy slip case.
- Remaining: on staging, open one real delivery photo (PostgREST response shape); L3 product decision; L4 follow-up; the stub does not enable RLS on `food_orders`/`food_stores` (QA verified that case separately).
