# Product Task — WYN-193 — WYNOS Food: บังคับแนบรูปทุกครั้งที่ส่งสำเร็จ

Status: backlog — รอ Founder อนุมัติ PRD
Owner: AI Product Manager
Date: 2026-10-03

## Founder direction

- ยังไม่มีระบบไรเดอร์ ร้านจ้างคนส่งภายนอกเอง คนส่งไม่มีบัญชี WYNOS
- เมื่อส่งเสร็จ คนส่งส่งรูปให้ร้าน (ช่องทางนอกระบบ เช่น LINE) แล้วร้านแนบรูปในแอป Merchant ให้ลูกค้าเห็น
- ตอนนี้มีร้านเดียว (ร้าน WYNOS) แต่ทุกอย่างต้องใช้ได้กับร้านอื่นในอนาคตด้วยกติกาเดียวกัน
- Founder (2026-10-03): **"บังคับให้ร้านแนบรูปทุกครั้ง"**

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

## Acceptance Criteria

1. เรียก RPC `direct` โดยไม่มีรูป → error; มีรูปถูก path → `delivered` และเก็บ `image_path`
2. เรียก RPC `dropoff` ไม่มีรูปหรือไม่มีจุดวาง → error (เหมือนเดิม)
3. path รูปของออเดอร์อื่น → error
4. ผู้ใช้ที่ไม่มีบทบาทในร้าน → error (เหมือนเดิม)
5. UI Merchant ไม่ให้กด "ส่งแล้ว" ถ้ายังไม่แนบรูป ทั้งสองวิธี
6. ลูกค้าเห็นรูปในหน้าออเดอร์ทั้งสองวิธี; ลูกค้าคนอื่นเปิดรูปไม่ได้
7. ข้อมูลออเดอร์เก่าไม่เปลี่ยน
8. Supabase test (`supabase/tests/`) + browser tests ของ merchant/food ผ่าน

## Dependencies

- Migration ใหม่ที่ `create or replace` `food_complete_delivery` (ไม่ destructive, rollback = นิยามเดิมใน `migrations_wynos_merchant_core_completion_v1.sql`)
- การ apply migration production ต้องได้ Founder approval แยก

## Priority

P0 (ก่อนเปิด Food ให้ลูกค้าทั่วไป)

## Risks

- คนส่งลืมส่งรูป → ร้านปิดงานไม่ได้; ยอมรับได้เพราะเป็นกติกาที่ Founder ต้องการ (ร้านต้องตามรูปจากคนส่ง)
- รูปใหญ่จากมือถือ → ใช้ limit upload เดิม

## Out of scope (คุยแยก)

- แจ้งเตือนลูกค้าเมื่อส่งสำเร็จ
- บันทึกชื่อ/เบอร์/ค่าจ้างคนส่ง
- พื้นที่จัดส่ง
- ระบบไรเดอร์กลาง

## Handoff

Founder อนุมัติ PRD → Full-Stack (migration + UI + tests) → QA & Security → CTO review → merge → apply migration หลัง Founder อนุมัติ
