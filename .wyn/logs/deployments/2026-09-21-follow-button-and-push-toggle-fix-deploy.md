# Deployment Log — Follow Button Repair + Push Toggle Hide-When-Unconfigured

**Release**: แก้ 2 บั๊กที่ Founder รายงานจากมือถือ — ปุ่ม "ติดตาม" กดไม่ได้ และ push notification toggle เปิดไม่สำเร็จ
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Root Cause 1 — ปุ่มติดตามกดไม่ได้ (ทุกที่ที่ใช้ "แนะนำให้ติดตาม")**:
`loadHomeViewerState()` (`lib/home-actions.ts`) query ตาราง `drop_likes`/`saves`/`redrops`
ซึ่งคอลัมน์ `drop_id`/`content_id` เป็น `uuid` — `fakeRows()` ใน `search-route.tsx` และ
`profile-recommendations.tsx` สร้าง id ปลอมแบบ `"profile:<uuid>"`/`"suggested:<uuid>"` เพื่อ
reuse ฟังก์ชันนี้กับ profile list ธรรมดา ทำให้ query ตาราง uuid พังด้วย
`invalid input syntax for type uuid` แล้ว throw จน `viewer` state ค้าง `null` ตลอดไป
(ปุ่มอ่าน `disabled={!viewer}`)

**Root Cause 2 — Push toggle โชว์ใช้ได้ทั้งที่ใช้ไม่ได้**:
`pushSupported()` เช็คแค่ browser capability ไม่เช็ค server-side Firebase config
(`NEXT_PUBLIC_FIREBASE_*` ยังไม่ตั้งใน Vercel — บล็อกอยู่ที่ WYN-016) ทำให้ทุกคนเห็น toggle
เป็นใช้งานได้ แต่กดแล้ว fail ทุกครั้งด้วย error ทั่วไป

**Verification**:
- Root-cause บั๊กปุ่มติดตาม ยืนยันด้วย throwaway fixture เรียก `loadHomeViewerState()` จริงผ่าน
  mock client จำลอง Postgres uuid validation (ลบก่อน commit) — id เก่า throw ตรงตามคาด, id ใหม่ผ่าน
- `npx playwright test --project=chromium-desktop --project=chromium-android` — 106/106 ผ่าน

**Changes**:
- `web/components/search-route.tsx` — `fakeRows()`: id ปลอม → `""`
- `web/components/profile-recommendations.tsx` — `fakeRows()`: id ปลอม → `""`
- `web/lib/push-notifications.ts` — `pushSupported()` เช็ค `/api/push-config` ด้วย ไม่ใช่แค่ browser support

**PR**: [#582](https://github.com/warren-wyn-dev/wynteam/pull/582) (`claude/web-beta1-readiness-7hysen` → `main`)

**Rollback Plan**: Revert PR — ทั้ง 3 ไฟล์เป็น diff เล็ก ไม่กระทบ schema/migration ปลอดภัยที่จะ revert ทันที
ถ้าจำเป็น (push toggle จะกลับไปโชว์แบบเดิม, ปุ่มติดตามจะกลับไปพังแบบเดิม — ไม่มีความเสี่ยง data loss)
