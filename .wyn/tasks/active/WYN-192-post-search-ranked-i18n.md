# WYN-192 — Ranked bilingual Post Search

Status: Active
Date: 2026-09-29
Owner: WYN Engineering
Platform: WYNOS Web

## Founder direction

ทำ Search ต่อจาก People Search โดยพัฒนา Post Search และรองรับภาษาไทย + อังกฤษตั้งแต่รอบแรก.

## Scope

- ค้นหาโพสต์จาก caption.
- ภาษาไทยใช้ direct substring + trigram similarity.
- ภาษาอังกฤษรองรับ token search ด้วย PostgreSQL simple full-text search.
- Ranking: exact caption → prefix → direct substring → full-text token match → fuzzy similarity.
- ใช้ SECURITY INVOKER เพื่อให้ Drops RLS เดิมคุม block/private/audience ต่อไป.
- ซ่อน deleted posts เสมอ แม้เจ้าของโพสต์ยังอ่านแถว deleted ของตัวเองได้ตาม RLS.
- RPC คืนเฉพาะ ranked IDs แล้ว frontend โหลด card data ด้วย query เดิมและเรียงกลับตาม relevance.
- Pagination 21 โพสต์ต่อหน้า.
- UI ไทยใช้ “โพสต์”; English translator ใช้ “Posts”.
- ไม่มีการเปลี่ยน Bottom Navigation หรือ Feed layout.

## Verification

- Production migration `20260929140657_web_post_search_ranked_i18n` applied.
- Transaction probe ผ่าน: exact-first, Thai substring, English multi-word, deleted hidden, blocked hidden, authenticated-only.
- Web regression test: `web/tests/post-search.test.mjs`.
