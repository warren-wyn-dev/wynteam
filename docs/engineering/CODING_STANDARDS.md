# WYN Coding Standards

เอกสารนี้กำหนด quality baseline แต่ไม่เลือก language, framework หรือ application architecture

## Design and Scope

- implement เฉพาะ approved requirements และ acceptance criteria
- ทำ smallest safe change; preserve working behavior และหลีกเลี่ยง unrelated refactor
- prefer simple, explicit code และ existing patterns ก่อน abstraction/dependency ใหม่
- maintain clear module boundaries; dependencies ต้องมีทิศทางและเหตุผลที่ review ได้
- major framework/dependency replacement ต้องได้รับ Founder approval

## Types, Contracts, and Validation

- ใช้ strong typing ที่ ecosystem รองรับ และหลีกเลี่ยง unsafe escape hatch โดยไม่มีเหตุผล
- validate/normalize untrusted input ที่ server/API boundary รวมถึง identifiers, pagination, filenames และ metadata
- API/contracts ต้องระบุ success, validation errors, authorization failures และ recoverable/unrecoverable failures
- ห้ามใช้ client-side restriction เป็น authorization control

## Security and Privacy

- secrets อยู่ใน approved secret management/environment mechanism และห้ามอยู่ใน source, fixtures, screenshots หรือ logs
- minimize sensitive-data collection/access/retention และ redact logs
- use least privilege, safe defaults และ explicit authorization checks
- dependency ใหม่ต้องมี owner, purpose, maintenance/security review และ removal impact

## Maintainability

- naming เป็นภาษาอังกฤษและสื่อ intent; function/module มี responsibility ที่ชัดเจน
- reuse before duplication แต่ไม่สร้าง abstraction จาก hypothetical reuse
- comments อธิบาย “why” และ constraints ไม่ทำซ้ำ “what” ที่ code แสดงอยู่แล้ว
- error handling ต้อง deterministic, user-safe และ observable โดยไม่ leak internals/secrets
- feature behavior ที่เสี่ยงควร reversible และมี migration/compatibility strategy เมื่อเกี่ยวข้อง

## Testing

- tests ต้องครอบคลุม happy path, meaningful failures, boundaries และ authorization/privacy rules
- bug fix ต้องมี regression test เมื่อทำได้ทางเทคนิค
- tests ต้อง deterministic, isolated และไม่พึ่ง production data/services
- mock เฉพาะ boundary ที่เหมาะสม; critical integration contracts ต้องมี integration evidence
- ห้ามลด/ลบ test เพื่อทำให้ pipeline ผ่านโดยไม่แก้ root cause และบันทึกเหตุผล

## Review and Documentation

- author ต้อง self-review diff, generated files, secrets และ scope ก่อน handoff
- reviewer ตรวจ correctness, security, privacy, accessibility, performance, tests, operability และ simplicity ตามความเสี่ยง
- update relevant docs/ADRs/runbooks เมื่อ behavior, contract หรือ operational expectation เปลี่ยน
- TODO ต้องมี context/owner หรือ tracking reference; ห้ามใช้ TODO ซ่อน release blocker

## Tooling Quality Gates

ใช้ formatter, linter, type checker, tests และ build ที่ repository กำหนด ทุก failure ต้องแก้หรือรายงานเป็น known, justified environment limitation; ห้าม claim PASS หากไม่ได้รันจริง
