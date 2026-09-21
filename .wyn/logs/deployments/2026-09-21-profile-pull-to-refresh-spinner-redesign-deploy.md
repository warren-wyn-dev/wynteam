# Deployment Log — Profile pull-to-refresh spinner redesign

**Release**: Visual redesign of the pull-to-refresh indicator (follow-up to PR #574's gesture fix)
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Deployment Target**: Production (`wynos.online`, Vercel)

**Feedback**: Founder ทดสอบ PR #574 แล้ว gesture ทำงานถูกต้อง แต่ "ตอนมันหมุน ไม่สวย"

**Root Cause**: spinner เดิมเป็นวงแหวนหมุนเปล่าๆ ไม่มีพื้นหลัง + ตำแหน่งอยู่ตรง safe-area edge ชนกับแถว topbar (ปุ่มย้อนกลับ/username/settings)

**Changes**:
- `web/components/profile-route.tsx` — เปลี่ยน spinner เป็น badge วงกลม (พื้นหลัง `--wyn-surface` + เงานุ่ม) ขยับตำแหน่งจากติด safe-area edge มาอยู่ใต้ topbar แทน (`calc(52px + env(safe-area-inset-top))`) — peek เข้ามาจากหลัง topbar ตอนลาก แล้วนิ่งใต้ topbar ตอนกำลังรีเฟรช

**PR**: [#575](https://github.com/warren-wyn-dev/wynteam/pull/575) (`claude/web-beta1-readiness-7hysen` → `main`) — Founder merge เอง

**Deployment Result**:
- `WYN-158 Production Deploy` run #161 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35550934623) — **success** ทุก step

**Production Verification**: รอ Founder ยืนยัน physical device ว่า spinner ดูดีขึ้นจริง ไม่ชน topbar

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff เป็น pure CSS/inline-style เปลี่ยนแค่ 1 ไฟล์ ปลอดภัยที่จะ revert ทันที
