# WYN Mandatory Security Rules

## Baseline

1. Security first และ privacy by design ตั้งแต่ requirements ถึง operations
2. Deny by default และ least privilege สำหรับ user, service, database และ infrastructure access
3. Treat every client, file, webhook และ third-party payload as untrusted
4. ห้าม expose secrets หรือ sensitive/private user data ผ่าน git, logs, errors, telemetry, screenshots หรือ reports
5. Authentication และ security-policy architecture changes ต้องได้รับ Founder approval

## Authentication and Authorization

- protected endpoint/action ต้อง authenticate ตาม approved architecture
- enforce object-, action- และ role-level authorization server-side ทุกครั้ง; query/filter ฝั่ง client ไม่ใช่ control
- ownership checks ต้องยึด authenticated identity ไม่ใช่ user ID ที่ client ส่งมา
- sensitive actions ต้อง resist replay/session misuse ตาม threat model และ revoke access เมื่อ state เปลี่ยน
- permission model ต้องป้องกัน privilege escalation และ default เป็น no access เมื่อข้อมูลไม่ครบ

## Data and Privacy

- collect, retain และ expose เฉพาะข้อมูลที่จำเป็นต่อ approved purpose
- classify sensitive data และจำกัด access/logging/export ตาม need-to-know
- ใช้ transport/storage protections ตาม environment policy และไม่สร้าง custom cryptography
- deletion/export/backup behavior ต้องเคารพ authorization, retention และ recovery constraints
- production data ห้ามนำไปใช้ใน development/test โดยไม่มี approved sanitization และ authorization

## Input, APIs, and Abuse

- validate schema, type, length, range, encoding และ allowed values ฝั่ง trusted boundary
- ป้องกัน injection, unsafe deserialization, path traversal, SSRF และ mass-assignment ตาม attack surface
- errors ห้าม leak stack traces, credentials, internal paths หรือ cross-user existence ที่ sensitive
- rate limits/abuse controls ต้องอยู่บน sensitive/high-cost operations และ fail safely
- engagement-changing action ต้องมี authorization, integrity controls และ anti-automation consideration

## File Uploads

- จำกัดขนาด จำนวน และ allowed types; ตรวจ content/signature ไม่เชื่อ filename/extension/client MIME อย่างเดียว
- สร้าง safe server-side name/path, ป้องกัน traversal/overwrite และเก็บนอก executable context
- scan/quarantine ตามความเสี่ยง และ authorize upload/read/delete แยกกัน
- รูป/metadata ต้องไม่ leak private information โดยไม่ตั้งใจ

## Required Adversarial Cases

QA ต้องทดสอบอย่างน้อยเมื่อ applicable:

- User A edit/delete content ของ User B
- unauthenticated/unauthorized access ต่อ private resources
- direct API bypass ของ frontend restrictions
- engagement manipulation, replay และ rate-limit bypass
- malicious/polyglot/oversized files และ misleading MIME/extensions
- horizontal/vertical permission escalation
- block/privacy bypass ผ่าน search, cache, notifications, URLs หรือ indirect APIs
- sensitive data leakage ใน logs, errors, analytics และ client bundles

## Findings and Release Policy

- **CRITICAL:** compromise กว้าง, auth bypass, secret/private-data exposure ร้ายแรง หรือ destructive impact; block release เสมอ
- **HIGH:** exploitation ที่มีผลกระทบสูงหรือ permission/privacy failure สำคัญ; ต้องแก้ก่อน release หรือมี explicit documented Founder risk acceptance
- **MEDIUM:** meaningful weakness ที่มี constraints/impact จำกัด; ต้องมี owner และ remediation plan
- **LOW:** hardening/defense-in-depth issue; track และ prioritize ตาม risk

Finding ต้องมี affected surface, prerequisites, reproduction, impact, evidence, severity rationale, mitigation และ retest result ห้ามลด severity เพื่อผ่าน gate

## Operational Security

- secrets ใช้ approved store และ rotation; ห้ามพิมพ์ secret ใน command/history/report
- logs ต้อง useful แต่ไม่เก็บ tokens, passwords หรือ unnecessary PII
- CI/CD ใช้ least privilege, pinned/reviewed sources ตามความเหมาะสม และ protected production credentials
- backup ต้องมี access controls และ restore test; destructive production action ต้องมี Founder approval
- incident ให้ preserve evidence, contain safely, report promptly และไม่ rollback/change policy เอง
