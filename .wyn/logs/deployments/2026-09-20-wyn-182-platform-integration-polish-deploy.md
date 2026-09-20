# Deployment Log — WYN-182 (Platform Integration Polish)

**Release**: WYN-182 — Track 4 of epic WYN-174 (Web Native App Feel รอบ 2), **track สุดท้าย**
**QA Status**: PASS อิสระ 0 บั๊ก (CRITICAL/HIGH/MEDIUM/LOW) — regression suite เต็ม 159/159 ผ่าน
**Build Status**: `typecheck`/`lint`/`build` สะอาด (0 error, warning 3 จุดเดิมยืนยัน pre-existing) — รันซ้ำอิสระอีกรอบหลัง merge `main` ล่าสุดก่อนเปิด PR

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- Safe-area inset fix 3 จุด: `.wyn-profile-tabs`, `.golden-club-tabs` (sticky tab bars เลี่ยง notch/Dynamic Island), `.drawer-menu-list` (defensive bottom inset)
- Overscroll-behavior fix 7 จุด: `html`/`body` (`overscroll-behavior-y: contain`) + 6 action sheet/modal ที่ reuse กว้าง
- `web/lib/use-pull-to-refresh.ts` + `web/lib/use-is-developer-account.ts` (ใหม่) — extract pull-gesture logic จาก `home-screen.tsx` เดิม
- Wire pull-to-refresh เข้า 4 หน้าใหม่ (Club detail แท็บโพสต์, Notifications, Bookmarks, Profile feed) gate ด้วย staged-rollout (`isDeveloperAccount`) ตาม WYN-125 — Home's ของเดิมไม่ gate (GA อยู่แล้ว)

**PR**: [#570](https://github.com/warren-wyn-dev/wynteam/pull/570) (`claude/wynos-online-version-1pqqws` → `main`) — merge `main` เข้า branch ก่อนเปิด PR (19 commits behind, auto-merge สำเร็จไม่มี conflict) Founder merge เองภายในไม่กี่วินาที

**Deployment Result**:
- `WYN-158 Production Deploy` run #157 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35511620273) — **success** ทุก step
- Post-merge `CI` run #1438 บน `main` — **success**

**Production Verification**: GitHub Actions "Verify production routes" step ผ่าน (sandbox เข้า `wynos.online` ตรงไม่ได้) — รอ Founder ยืนยัน physical device: (1) Profile/Club tabs ไม่ชน notch บนอุปกรณ์มี Dynamic Island (2) pull-to-refresh 4 หน้าใหม่ทำงานถูกต้องสำหรับบัญชี developer (gate ปิดสำหรับบัญชีทั่วไปตามที่ตั้งใจ) (3) ไม่มี native Android Chrome pull-to-refresh ชนซ้อนกับของแอปอีกต่อไป

**Known follow-up (ไม่ block, ตั้งใจไว้ตั้งแต่แรก)**: sandbox ทั้ง AI Coding และ QA ไม่มี Supabase backend จริง จึงยังไม่เคยทดสอบ staged-rollout gate กับบัญชีจริงและ native Android Chrome PTR — ต้องยืนยันบน production/staging จริงก่อนขยายให้ non-dev เห็น (เป็น path การตรวจสอบที่ออกแบบไว้แต่แรก ไม่ใช่ finding ใหม่)

**Rollback Plan**: Revert merge commit หรือ commit ย่อยผ่าน PR แยก — diff เป็น additive ล้วนๆ (CSS property เพิ่ม + hook ใหม่ + gate ด้วย developer-account) ไม่แตะ business logic/schema เดิม ปลอดภัยที่จะ revert ทันทีถ้าจำเป็น
