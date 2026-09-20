# Deployment Log — WYN-184 (Non-sticky Header Safe-area Fix)

**Release**: WYN-184 — follow-up gap-closing task หลัง Track 4 (WYN-182) ของ epic WYN-174
**QA Status**: PASS หลังผ่าน bug/fix/re-verify 1 รอบ — QA รอบแรก FAIL (พบ regression suite เก่าพัง 3/159 จาก literal-string assertion ที่ไม่ทันการเปลี่ยน CSS ไม่ใช่ CSS ผิด) → AI Debug Engineer แก้ test assertion → QA re-verify PASS ยืนยัน 159/159 อิสระ
**Build Status**: `typecheck`/`lint`/`build` สะอาด (0 error, warning 3 จุดเดิม) — รันซ้ำอิสระอีกรอบก่อนเปิด PR

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- `.wyn-profile-topbar` (`web/app/profile-golden-final.css`) — เพิ่ม safe-area-inset-top กระทบ 4 route path (`/profile/[id]`, `/profile/me`, `/profile/[id]/followers`, `/profile/[id]/following`)
- `.flutter-chat-header` cascade fix (Chat inbox, `/chat`) — แก้ที่ rule ที่ชนะ cascade จริง (`web/app/chat-notes.css:537-542`) ยืนยันอิสระ 2 รอบ (AI Coding + QA) ว่าไม่ใช่ dead code ในไฟล์อื่น
- `web/tests/browser/parity.spec.ts:162` — อัปเดต literal-string assertion ให้ตรงกับสูตร CSS ใหม่

**PR**: [#571](https://github.com/warren-wyn-dev/wynteam/pull/571) (`claude/wynos-online-version-1pqqws` → `main`) — branch ไม่ diverge จาก main ก่อนเปิด PR Founder merge เองภายในไม่กี่วินาที

**Deployment Result**:
- `WYN-158 Production Deploy` run #158 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35517267170) — **success**
- Post-merge `CI` run #1440 บน `main` — **success**

**Production Verification**: GitHub Actions "Verify production routes" ผ่าน — รอ Founder ยืนยัน physical device: Profile header (ทั้ง 4 หน้าที่เกี่ยวข้อง) และ Chat inbox header ไม่ชนขอบจอบนอุปกรณ์มี notch/Dynamic Island อีกต่อไป

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff เป็น CSS property เพิ่ม 2 จุด + test assertion update ล้วนๆ ไม่แตะ business logic/schema ปลอดภัยที่จะ revert ทันที
