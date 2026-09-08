# WYN Git Workflow

## Authority and Safety

- AI inspect/modify ได้เมื่อ task อนุญาตอย่างชัดเจน
- default คือไม่ commit, push, merge หรือ deploy อัตโนมัติ; ต้องมี explicit Founder authorization เว้นแต่ higher-priority execution instruction ระบุให้ทำ
- ห้าม force push, rewrite shared history, delete protected branches/tags, bypass branch protection หรือ commit secrets
- production deployment approval แยกจาก code review/merge approval เสมอ

## Branches

- ทำงานบน dedicated short-lived branch ไม่ทำ feature work โดยตรงบน protected production branch
- ตั้งชื่อเป็นภาษาอังกฤษและสื่อ scope เช่น `docs/engineering-os`, `feat/profile-edit`, `fix/private-resource-auth`
- sync ด้วย non-destructive approach; หาก conflict มีผลต่อ scope/security ให้หยุดและ escalate
- หนึ่ง branch/PR ควรมีหนึ่ง coherent objective และหลีกเลี่ยง unrelated formatting/refactor

## Commits

- review `git status` และ staged diff ก่อน commit; stage เฉพาะไฟล์ของ task
- ใช้ English conventional commits เช่น `docs: establish engineering operating system`
- commit ต้อง atomic, buildable/testable เท่าที่ applicable และห้ามรวม generated/secrets/local environment files โดยไม่ตั้งใจ
- ห้าม amend/rebase commit ที่ผู้อื่นอาจใช้ร่วมกันโดยไม่มี coordination/approval

## Pull Requests and Review

PR ต้องระบุ:

- problem/scope และ explicit out-of-scope
- changed files/behavior และ decision/approval references
- test commands กับผลจริง
- security/privacy/data/operations impact
- screenshots เมื่อมี perceptible web UI change
- risks, migration และ rollback/recovery plan เมื่อ applicable

Author ห้ามเป็นผู้อนุมัติ release gate เพียงคนเดียว งานต้องผ่านเจ้าของ review ที่ workflow กำหนด Findings ต้อง resolve หรือ document acceptance ตาม severity policy

## Merge Rules

- merge เมื่อ required reviews/checks ผ่าน, conversation resolved, approval records ครบ และ branch ไม่มี unintended change
- ห้าม merge อัตโนมัติหาก Founder ยังไม่ได้ authorize การ merge ตาม governance ปัจจุบัน
- merge method ต้องรักษา auditability ตาม repository policy; ห้าม force push เพื่อหลบ conflict/check
- หลัง merge ให้ตรวจ target state และเก็บ release/deployment เป็นขั้นตอนแยก

## Sensitive or Destructive Changes

Production database deletion, destructive migration, major architecture/auth/security policy/framework/cloud/cost changes ต้องแนบ explicit Founder approval ก่อน merge/execution ตาม gate ที่เกี่ยวข้อง ห้ามเก็บ credentials หรือ production data ใน diff/PR artifact

## Recovery

เมื่อพบ bad change ให้หยุดการขยายผล, preserve evidence, report impact และเสนอ revert/fix-forward/rollback options ห้าม rollback production หรือ rewrite history เอง; Founder เป็นผู้ตัดสินใจตาม version-control policy
