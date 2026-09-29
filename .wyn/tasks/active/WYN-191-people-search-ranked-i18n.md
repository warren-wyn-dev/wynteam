# WYN-191 — People Search Ranking + Thai/English

Status: Active
Date: 2026-09-29
Owner: WYN Engineering
Platform: WYNOS Web

## Founder direction

เริ่มพัฒนา Search + Discover โดยทำ People Search ก่อน และให้ UI รองรับภาษาไทย/อังกฤษตั้งแต่รอบแรก.

## Scope

- ค้นหาด้วย username และ display name.
- รองรับการพิมพ์ `@username`.
- Ranking: exact username → username prefix → exact display name → display-name prefix → substring similarity.
- ใช้ `pg_trgm` indexes สำหรับ username/display name.
- ซ่อนบัญชีที่ block กันทั้งสองทิศทางจากผลค้นหา.
- RPC เป็น SECURITY INVOKER และเปิดให้เฉพาะ authenticated.
- Pagination 30 รายการต่อหน้า.
- หน้าไทยใช้คำว่า “ผู้ใช้”; English translator แสดง “People”.
- คง Follow/Follow Request, Verified badge, default avatar และ Profile navigation เดิม.

## Verification

- Production DB migration `web_people_search_ranked` applied.
- Exact username และ `@username` rank อันดับแรกผ่าน production probe.
- `authenticated` execute ได้; `anon` execute ไม่ได้.
- Block relationship production transaction probe ซ่อน target ได้จริงและ rollback แล้ว.
- Web regression test: `web/tests/people-search.test.mjs`.
