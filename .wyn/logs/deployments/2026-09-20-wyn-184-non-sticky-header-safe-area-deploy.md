# Deployment Log — WYN-184 (Non-Sticky Header Safe-Area Audit)

**Release**: WYN-184 — P3 follow-up gap-closing round after epic WYN-174 (Web Native App Feel รอบ 2)
**QA Status**: PASS (รอบ 2, หลัง debug fix ของ regression suite) — cascade re-derivation อิสระ + live CDP safe-area verification ตรงกับ spec 100% ไม่มี discrepancy
**Build Status**: `typecheck`/`lint`/`build` สะอาด — regression suite เต็ม 159/159 ผ่าน

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- `.wyn-profile-topbar` (`web/app/profile-golden-final.css`) — เพิ่ม `padding-top: env(safe-area-inset-top)` และปรับ `height` เป็น `calc(52px + env(safe-area-inset-top))` กระทบ 4 route path: `/profile/[id]`, `/profile/me`, `/profile/[id]/followers`, `/profile/[id]/following`
- `.flutter-chat-header` (`web/app/chat-notes.css:537-542`, `/chat`) — แก้ที่ cascade-winning rule จริง ให้มี `padding-top`/`height` รวม `env(safe-area-inset-top)` ปิด gap ที่ `pixel-parity-audit-closure.css` เคยพยายามแก้แต่โดนทับ (dead code, ไม่แตะ)
- `web/tests/browser/parity.spec.ts` — แก้ literal-string assertion เดิม (`"height: 52px"` → `"height: calc(52px + env(safe-area-inset-top))"`) ให้ตรงกับ formula ใหม่ที่ถูกต้อง (พบเป็น regression suite failure ระหว่าง QA รอบแรก แก้โดย AI Debug Engineer แล้ว)

**PR**: [#571](https://github.com/warren-wyn-dev/wynteam/pull/571) (`claude/wynos-online-version-1pqqws` → `main`) — Founder merge เองเวลา 2026-09-20 14:41:35 UTC

**Deployment Result**:
- `WYN-158 Production Deploy` run #158 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35517267170) — **success** ทุก step (preflight / Vercel deploy / verify production routes)
- Post-merge `CI` run #1440 บน `main` — **success**

**Production Verification**: GitHub Actions "Verify production routes" step ผ่าน (sandbox เข้า `wynos.online` ตรงไม่ได้) — รอ Founder ยืนยัน physical device บนอุปกรณ์มี notch/Dynamic Island: (1) Profile topbar (รวม followers/following list) ไม่ชน notch อีกต่อไป (2) Chat inbox header ไม่ชน notch อีกต่อไป — checkbox "Founder on-device confirmation" ใน PR #571 ยังไม่ติ๊ก

**Known follow-up (ไม่ block)**: ไม่มี — diff เป็น pure CSS 2 จุด + test assertion fix 1 บรรทัด ไม่มีข้อจำกัดด้าน environment เพิ่มเติมสำหรับรอบนี้

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff เป็น additive/corrective ล้วนๆ (เพิ่ม safe-area property ให้ 2 selector ที่มีอยู่แล้ว) ไม่แตะ business logic/schema ปลอดภัยที่จะ revert ทันทีถ้าจำเป็น
