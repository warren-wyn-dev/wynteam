# Product Task — WYN-010

Status: backlog
Owner: AI Product Manager

Feature: Share formalization — extend native Share + Copy Link to ZOKY Product Detail and Store

Goal: Close the one remaining gap in Share coverage across the app. Every other content type (Drop, Pop, Club post) already got Share + Copy Link organically while building WYN-005/006/WYN CLUB, but ZOKY Marketplace (built afterward) never received it — `ProductDetailScreen`/`StoreScreen` have no way to share a product or store at all.

Target User: Any WYN user browsing ZOKY who wants to send a product/store link to a friend, or post it elsewhere (chat apps, social media)

Problem: WYN-010 was originally scoped in the pre-ZOKY roadmap (`.wyn/docs/product/wyn-v0.1-roadmap.md`) as a dedicated "Share formalization" task, but got superseded in priority first by WYN CLUB then by ZOKY Marketplace (see `.wyn/company/DECISIONS.md`, 2026-08-14 entries) before it was ever picked up on its own. By the time ZOKY Marketplace was built, Share had already become an established per-content-type pattern (Drop/Pop/Club post each have it), but ZOKY's Product Detail/Store screens shipped without it — an inconsistency a user would notice immediately switching between tabs.

Requirements:

**ขอบเขตที่ตัดสินใจแล้วก่อนเริ่ม**:
- **ใช้ pattern เดียวกับ Drop/Pop/Club post เป๊ะ** — ไม่ประดิษฐ์ mechanism ใหม่ ไม่ consolidate/refactor โค้ด Share ที่มีอยู่แล้วของ Drop/Pop/Club post (โค้ดเหล่านั้นผ่าน QA และใช้งานจริงอยู่แล้ว การแตะเพื่อ DRY ทำได้แต่เพิ่มความเสี่ยง regression โดยไม่มีประโยชน์ต่อผู้ใช้ — ไม่ทำในรอบนี้) — task นี้เป็นการ**ต่อยอด**เพิ่ม 2 จุดใหม่ ไม่ใช่ refactor ของเดิม
- **ทุกจุดที่มี Share ในโปรเจกต์นี้ใช้ placeholder link เหมือนกันหมด** (`https://wyn.app/<type>/<id>`) เพราะยังไม่มี domain/hosting จริง — `productShareLink(productId)`/`storeShareLink(storeId)` ใหม่ต้องตามรูปแบบเดียวกัน (`https://wyn.app/product/$id`, `https://wyn.app/store/$id`) พร้อม comment เตือนแบบเดียวกับที่ `dropShareLink`/`popShareLink`/`clubPostShareLink` มีอยู่แล้วว่ายังไม่ใช่ URL ที่เปิดได้จริง ต้องรอ domain จริงก่อน deploy
- **ไม่มี deep linking จริง** (แตะลิงก์ที่แชร์แล้วเปิดแอปตรงไปหน้าสินค้า/ร้าน) — ต้องมี Universal Links (iOS)/App Links (Android) + domain จริง ซึ่งเป็นงานคนละขนาด (native platform config + hosting `.well-known` file) ไม่ทำในรอบนี้เหมือนกับ Drop/Pop/Club post เดิม
- **ปุ่ม Share/Copy Link วางเป็น AppBar action** (ไม่ใช่แถว interaction แบบ Drop/Pop/Club post) เพราะ `ProductDetailScreen`/`StoreScreen` เป็นหน้า detail ที่ไม่มี Like/Comment count row อยู่แล้ว (ต่างจาก Drop/Pop/Club post ที่เป็น content แบบ social ที่มีแถวปฏิสัมพันธ์อยู่แล้ว) — ให้ AI Design ตัดสินใจ icon/ตำแหน่งที่แน่นอน

Acceptance Criteria:
- [ ] `ProductDetailScreen`'s AppBar มีปุ่ม Share (เปิด native share sheet ผ่าน `share_plus`) และปุ่ม Copy Link (คัดลอกลิงก์ + SnackBar ยืนยัน) — ข้อความ/พฤติกรรม SnackBar ตรงกับที่ Drop/Pop/Club post ใช้อยู่แล้ว ("คัดลอกลิงก์แล้ว") เพื่อความสม่ำเสมอ
- [ ] `StoreScreen`'s AppBar มีปุ่ม Share/Copy Link เช่นเดียวกัน
- [ ] ลิงก์ที่แชร์/คัดลอกอ้างอิงถึง product id/store id ที่ถูกต้องจริง (ไม่ hard-code)
- [ ] กดปุ่มแล้วไม่ crash แม้ใน environment ที่ share sheet native ใช้งานไม่ได้เต็มรูปแบบ (widget test)
- [ ] Drop/Pop/Club post เดิมทั้งหมดยังทำงานเหมือนเดิมทุกประการ ไม่มี regression (ไม่ถูกแตะเลย)

Dependencies: ZOKY-001 (Marketplace Foundation — Approved, มี `ProductDetailScreen`/`StoreScreen` อยู่แล้ว)

Priority: P2 — ไม่ block งานอื่น เป็นงานเดียวที่ไม่ต้องรอข้อมูลเพิ่มจาก Founder ในขณะที่ Phase 4 (ZOKY Sellers) ยังรอเนื้อหา Seller section อยู่

Risks:
- **ไม่มี** ความเสี่ยงต่อโค้ดเดิม เพราะเป็นการเพิ่มปุ่มใหม่ใน 2 ไฟล์ที่ไม่มี Share มาก่อน ไม่แตะโค้ด Share ที่มีอยู่แล้วของ Drop/Pop/Club post เลย

Recommendation: ทำทันทีตามลำดับที่เสนอ ใช้ pattern เดียวกับ Drop/Pop/Club post เป๊ะเพื่อความสม่ำเสมอของ UX ทั้งแอป

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบตำแหน่ง/icon ของปุ่ม Share/Copy Link บน `ProductDetailScreen`/`StoreScreen`'s AppBar
