# WYN-176 Batch 4 — Profile / Settings press feedback

**Date**: 2026-09-20
**Status**: Approved by Founder (เลือกทางเลือก A — คงทรง pill เดิม)
**Preview**: https://claude.ai/artifact/8LyHCBKh1AaX3zyLZH56yh

## Scope check against real code

ตรวจ `web/components/profile-route.tsx` และ `web/components/settings-route.tsx` ก่อนออกแบบ พบว่าไม่มีจุดไหนใน Profile/Settings มี press feedback เลย (grep `:active` ทับกับ `profile|settings|account` ใน `web/app/*.css` ทั้งหมด = 0 ผลลัพธ์)

**คำถามเดียวที่ต้องตัดสินใจ**: ปุ่ม `.wyn-profile-action-primary`/`.wyn-profile-action-secondary` (แก้ไขโปรไฟล์/ติดตาม/ส่งข้อความ) ยังเป็นทรง pill 999px radius / 44px สูง แบบเก่า — ไม่เคยถูกปรับเป็น squircle ของ WYN-163 ในทุก batch ก่อนหน้า (ต่างจาก Composer/Chat ที่ WYN-160 batch 4/5 ปรับ scale ไว้ก่อนแล้ว) ทำ preview เทียบ 2 ทาง → **Founder เลือกทางเลือก A: คงทรง pill เดิม ไม่แก้ขนาด แค่เพิ่ม press feedback**

จุดอื่นทั้งหมดเป็น list row / utility button ไม่ใช่ CTA pill จึงไม่มีประเด็น scale — เพิ่ม press feedback อย่างเดียวเหมือน batch 1-3

## Targets (10 selectors, ไม่แก้ radius/ขนาดใดๆ ทั้งหมด)

1. `.wyn-profile-account-switcher` — ปุ่มสลับบัญชีใน topbar (`web/app/profile-golden-final.css`)
2. `.wyn-profile-action-primary` / `.wyn-profile-action-secondary` — ปุ่มแก้ไขโปรไฟล์/แชร์/ติดตาม/ส่งข้อความ (ทั้ง base และ `.is-own` variant) (`web/app/profile-golden-final.css`)
3. `.wyn-profile-edit-avatar-remove` — ลิงก์ "ลบรูปโปรไฟล์" (`web/app/profile-golden-final.css`)
4. `.profile-account-select` — แถวเลือกบัญชีใน account switcher sheet (`web/app/profile-golden-final.css`)
5. `.profile-account-remove` — ปุ่ม "นำออก" ในแถวบัญชี (`web/app/profile-golden-final.css`)
6. `.profile-account-use-other` — ปุ่ม "เข้าสู่ระบบบัญชีอื่น" (`web/app/profile-golden-final.css`)
7. `.profile-account-manage` — ปุ่ม "จัดการบัญชี/เสร็จ" (`web/app/profile-golden-final.css`)
8. `.profile-more-sheet > button` — แถวใน sheet ตัวเลือกโปรไฟล์ (แชร์/ปิดเสียง/บล็อก) (`web/app/profile-golden-final.css`)
9. `.settings-row.enabled` — แถว settings ที่กดนำทางได้จริง (สโคปเฉพาะ `.enabled` เพื่อไม่ให้แถว toggle ที่เป็น `<div>` ได้ผลกระทบ) (`web/app/phase3.css`)

Motion token เดียวกับทุก batch: `transform: scale(0.96)` บน `:active`, `transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1)`, ปิดใน `prefers-reduced-motion: reduce`

## Handoff

→ **AI Coding**: ตรวจ cascade จริงก่อนแก้ทุกจุด (grep ทุกไฟล์ CSS หา selector ซ้ำ + เช็คลำดับ import ใน `layout.tsx`) แก้ที่ตำแหน่งที่ชนะ cascade จริงเท่านั้น ไม่แตะ radius/ขนาด/สี ยืนยันด้วย harness Playwright จริงก่อนส่ง QA
