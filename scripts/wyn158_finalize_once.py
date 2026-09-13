from pathlib import Path

approval_marker = 'WYN-158 — Next.js Consumer Web Architecture'
approval_entry = '''

## APPROVED — WYN-158 — Next.js Consumer Web Architecture (2026-09-13)

**Founder decision:** อนุมัติให้ย้าย consumer web frontend ของ WYNOS จาก Flutter Web ไปเป็น **Next.js/React** แบบทยอยย้าย โดย **ใช้ Supabase project/backend, Auth, RLS และ RPC contracts เดิมต่อ**, รักษา UX/UI ของ WYNOS ให้ใกล้เดิม และให้ browser ใช้ **system font ของแต่ละ OS** ผ่าน CSS system-font stack โดย **ห้าม bundle/redistribute SF Pro หรือ Apple font files** ในเว็บ

**Reason:** Flutter Web canvas ไม่สามารถใช้ browser-installed system fonts ได้ตรง ๆ และการใช้ HTML platform views จำนวนมากใน scrolling feed มี WebKit stability cost. DOM-native React/Next.js แก้ข้อจำกัดนี้โดยไม่ต้องแจกไฟล์ฟอนต์ Apple

**Scope approved now:** architecture, implementation, tests, branch/PR และ internal/developer-gated preview/staging เท่านั้น

**Not approved by this entry:** public production cutover ที่ `wynos.online`, การลบ Flutter app, destructive database migration, auth/security weakening หรือการเปลี่ยน WYNOS version — ทุกอย่างดังกล่าวยังต้องผ่าน release/change-control gate แยกต่างหาก

**Security:** browser ใช้เฉพาะ Supabase publishable key; ห้าม service-role/management secrets ฝั่ง client; authorization ยังคง enforce ด้วย backend RLS/RPC และ preview ใหม่ fail-closed ผ่าน `is_developer_account()`

**Rollback/recovery:** ระหว่าง migration Flutter production เดิมไม่ถูกแทนที่ จึงสามารถหยุด/ทิ้ง migration branch ได้โดยไม่ rollback production version
'''

decision_marker = 'Next.js/React เป็น Consumer Web Architecture ของ WYNOS'
decision_entry = '''

## [2026-09-13] Next.js/React เป็น Consumer Web Architecture ของ WYNOS (WYN-158)

Founder เลือกทิศทาง consumer web ใหม่: **Next.js/React + DOM/CSS native + system font ของ OS + Supabase backend เดิม** แทนการพยายามทำให้ Flutter Web canvas ใช้ฟอนต์ในเครื่องของ browser

กติกาถาวรของทิศทางนี้:
- UX/UI และ product behavior เดิมต้องถูก preserve ระหว่าง migration
- ย้ายแบบ incremental; Flutter production เดิมอยู่ต่อจนกว่า Founder จะอนุมัติ cutover
- ใช้ Supabase project/Auth/RLS/RPC เดิมเป็น backend contract
- ใช้ CSS system-font stack ให้ browser เลือกฟอนต์ของ OS เอง
- ห้ามฝัง แจก หรือ self-host ไฟล์ SF Pro/Apple fonts ใน consumer web
- ฟีเจอร์/หน้าใหม่ระหว่าง migration ต้อง developer-gated ตาม staged rollout จน Founder สั่งเปิด
- production cutover เป็น approval แยก ไม่อนุมานจาก approval ให้เริ่มพัฒนา
'''

approval_path = Path('.wyn/company/APPROVALS.md')
approvals = approval_path.read_text(encoding='utf-8')
if approval_marker not in approvals:
    approval_path.write_text(approvals.rstrip() + approval_entry + '\n', encoding='utf-8')

# This legacy file contains pre-existing invalid UTF-8 bytes. surrogateescape
# gives us a byte-for-byte round trip so recording this decision cannot rewrite
# or normalize any historical content.
decision_path = Path('.wyn/company/DECISIONS.md')
decision_raw = decision_path.read_bytes()
decisions = decision_raw.decode('utf-8', errors='surrogateescape')
if decision_marker not in decisions:
    updated = decisions.rstrip() + decision_entry + '\n'
    decision_path.write_bytes(updated.encode('utf-8', errors='surrogateescape'))

ci_path = Path('.github/workflows/web-next-ci.yml')
ci = ci_path.read_text(encoding='utf-8')
ci = ci.replace('run: npm install --no-audit --no-fund', 'run: npm ci --no-audit --no-fund')
ci = ci.replace('cache-dependency-path: web/package.json', 'cache-dependency-path: web/package-lock.json')
ci_path.write_text(ci, encoding='utf-8')
