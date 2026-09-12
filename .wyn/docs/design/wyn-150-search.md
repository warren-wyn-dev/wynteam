# WYN "Flare" — Search (V1.0 — PROPOSED)

Status: PROPOSED
Owner: AI Design
อ้างอิง: wyn-142-visual-identity-redesign.md, wyn-143-core-component-library.md

หมายเหตุขอบเขต: เอกสารนี้เป็นสเปกภาพลักษณ์/ปฏิสัมพันธ์ใหม่ (visual re-skin) ของหน้าจอกลุ่ม Search ที่มีอยู่แล้ว
(`app/lib/features/search/presentation/search_screen.dart`,
`app/lib/features/search/presentation/top_100_screen.dart` และ widgets ย่อยใน
`app/lib/features/search/presentation/widgets/`) **ไม่เปลี่ยน business logic/data-fetching เดิม** —
ดีบาวน์ซ์แบบ submit-only (WYN-080), threshold คำค้นหาขั้นต่ำ 2 ตัวอักษร, pagination/infinite scroll,
Pop tab ที่ถูกซ่อนไว้ (WYN-102), และกติกา "ห้ามระบุจำนวนโพสต์ใต้แฮชแท็ก" (WYN-101) ต้องคงไว้ทุกประการ
มีเปลี่ยนเฉพาะสี/ฟอนต์/ระยะ/รัศมี/สถานะภาพ ตาม wyn-142/wyn-143 เท่านั้น

---

## Screen 1 — Search (หน้าค้นหา, `search_screen.dart`)

Screen: Search — root tab ของ Bottom Nav (ช่องที่ 2 จาก 5 ตาม wyn-143 §3 Bottom Tab Bar) ครอบคลุมทั้ง
Discovery view (ค่าเริ่มต้นเมื่อยังไม่ submit คำค้นหา) และ Result view (User/โพสต์/Club หลัง submit)

Purpose: ให้ผู้ใช้ค้นหา user/โพสต์(Drop)/Club ด้วยคำเดียวแล้วสลับดูผลลัพธ์แต่ละประเภทได้ โดยไม่ต้องพิมพ์ซ้ำ
และให้มีพื้นที่ค้นพบ (discover) แฮชแท็กกำลังนิยม + บัญชีแนะนำให้ติดตาม เมื่อยังไม่ได้พิมพ์ค้นหา

User Flow:
1. ผู้ใช้แตะแท็บ Search จาก Bottom Nav → เห็น Search Bar ว่าง + Discovery view (ส่วน "แฮชแท็กกำลังนิยม" และ
   "แนะนำให้ติดตาม") — ไม่ auto-focus คีย์บอร์ดเพราะเป็นการสลับแท็บปกติ ไม่ใช่ความตั้งใจค้นหาโดยตรง
2. ผู้ใช้แตะที่ Search Bar → คีย์บอร์ดเปิด, พิมพ์คำค้นหา (พิมพ์อย่างเดียวยังไม่ยิงผลลัพธ์ — Discovery view
   ยังคงแสดงอยู่จนกว่าจะ submit)
3. ผู้ใช้กดปุ่มแว่นขยายในแถบค้นหา หรือกด "ค้นหา" บนคีย์บอร์ด → submit คำค้นหา, คีย์บอร์ดปิด, เปลี่ยนเป็น
   Result view: Chip Tabs 3 ช่อง (User / โพสต์ / Club, เริ่มที่ User เป็นค่าเริ่มต้น)
4. ผู้ใช้แตะสลับ Chip Tab เพื่อดูผลลัพธ์ประเภทอื่นด้วยคำค้นหาเดียวกัน, เลื่อนดูผลลัพธ์แบบ infinite scroll
5. ผู้ใช้แตะปุ่ม × ในแถบค้นหา → ล้างคำค้นหา, กลับไป Discovery view
6. จาก Discovery view แตะ "ดูอันดับทั้งหมด (Top 100)" → เปิด Top 100 Screen (Screen 2)
7. แตะแฮชแท็ก (ใน Discovery preview หรือผลลัพธ์) → เปิดหน้าฟีดของแฮชแท็กนั้น (นอกขอบเขตเอกสารนี้)
8. แตะแถวผู้ใช้แนะนำ/ผลลัพธ์ผู้ใช้ → เปิดโปรไฟล์ หรือแตะปุ่มติดตามเพื่อติดตาม/ยกเลิกทันทีในหน้าเดิม
9. แตะการ์ดโพสต์/Club ในผลลัพธ์ → เปิดหน้ารายละเอียดของโพสต์/Club นั้น

Components (จาก wyn-143 เท่านั้น เว้นแต่ระบุเป็น "ส่วนขยายเฉพาะหน้าจอ" อย่างชัดเจน):
- **Search Bar** (wyn-143 §2c) — pill, พื้นหลัง `color.surface`, ไอคอนแว่นขยายซ้าย (แตะเพื่อ submit ได้ด้วย),
  ปุ่ม clear (×) ขวาเมื่อมีข้อความ, sticky ด้านบนตลอดเวลา (ทั้ง Discovery และ Result view) แทนที่กล่องค้นหา
  เดิมสูง 64px (โครงเดิม `WynosSearchSurface` ยังใช้ได้ แค่เปลี่ยน token สี/ฟอนต์/รัศมีเป็นของ Flare)
- **Segmented Chip Tabs (ส่วนขยายเฉพาะหน้าจอนี้)** — ใช้โครง Chip (wyn-143 §6): unselected = pill,
  พื้นหลัง `color.surface`, ขอบ `color.hairline`, ตัวหนังสือ `color.ink`; selected = พื้นหลัง `color.accent`,
  ตัวหนังสือ `color.paper` (ขาว) — เหตุผลที่ต้องขยาย: wyn-143 ยังไม่มีคอมโพเนนต์ "ตัวสลับประเภทผลลัพธ์" โดยตรง
  แต่ state ของ Chip ที่มีอยู่แล้ว (selected/unselected) ตรงกับความต้องการพอดี ไม่มี token/สี/ปฏิสัมพันธ์ใหม่
  แทนที่ `WynosSocialTabBar` (underline tab เดิม)
- **List Item** (wyn-143 §10) — ใช้กับแถวผู้ใช้แนะนำ (Discovery) และแถวผลลัพธ์ User: [Leading: Avatar 40px]
  — [Title `type.body.l` ชื่อ + Subtitle `type.body.s` สี `ink.muted` @username] — [Trailing: ปุ่มติดตาม]
- **HashtagRankRow (ส่วนขยายเฉพาะหน้าจอนี้ ดัดแปลงจาก List Item §10)** — [Leading: เลขอันดับ ชิดขวาในกรอบ
  คงที่ ~22–24dp, `type.heading.2`, สี `color.ink.muted`] — [Title: `#แฮชแท็ก` ตัวหนา `type.body.l`,
  สี `color.ink`, บรรทัดที่สอง `type.body.s` สี `color.ink.muted` เช่น "กำลังนิยมใน ไทย" — **ห้ามใส่จำนวนโพสต์**
  ตาม WYN-101] — [Trailing: ไอคอน more (⋯) `color.ink.muted`] คั่นแถวด้วยเส้น `color.hairline` (ไม่มีเส้นหลัง
  แถวสุดท้าย) ใช้ร่วมกันระหว่าง Discovery preview และ Top 100 Screen
- **Avatar** (wyn-143 §5) — ขนาด 40px แถวรายการ, ไม่มี ring (ยังไม่มี story/live feature)
- **ปุ่มติดตาม (compact variant ของ Primary/Secondary Button wyn-143 §1)** — สถานะ "ติดตาม" ใช้โครง Primary
  Button ย่อส่วน (พื้นหลัง `color.accent`, ตัวหนังสือ `color.paper`), สถานะ "กำลังติดตาม"/"ขอแล้ว" ใช้โครง
  Secondary Button (ขอบ `color.hairline`, ตัวหนังสือ `color.ink`) — เหตุผลที่ต้องย่อจาก 52px: ใช้ในแถวรายการ
  หนาแน่น ความสูงปุ่มจริงลดได้ (~36px) แต่ต้องคง hit-area ผ่าน padding ให้ครบ 44×44px ตามกติกา touch target
- **Empty State** (wyn-143 §12) — ใช้แทน `SearchStateMessage` เดิม: ไอคอน outline + หัวข้อ/คำอธิบายมิตร ๆ
  (เช่น "พิมพ์ username หรือชื่อเพื่อค้นหาคน", "ยังไม่มีบัญชีแนะนำให้ติดตามตอนนี้")
- **Loading / Skeleton** (wyn-143 §8) — Skeleton shimmer สำหรับส่วน Discovery ระหว่างโหลด, Spinner
  `color.accent` สำหรับผลลัพธ์หน้าแรกและ trailing spinner ตอน pagination
- **Card** (wyn-143 §4, "Search result card") — การ์ดโพสต์ (Drop) และ Club ในผลลัพธ์ ใช้พื้นหลัง `color.surface`,
  radius `radius.m` (รายละเอียดภายในการ์ดโพสต์/Club แต่ละแบบ ให้เป็นไปตามสเปก Home/Club ที่จะออกในเอกสารอื่น
  — ที่นี่กำหนดเฉพาะกรอบการ์ดและระยะห่างของรายการผลลัพธ์)

Interactions:
- แตะพื้นผิว Search Bar ตรงไหนก็ได้ (ไม่ใช่แค่ไอคอนแว่นขยาย) → โฟกัส TextField เปิดคีย์บอร์ด
- พิมพ์ตัวอักษร → ไม่ยิงค้นหาใด ๆ (คงพฤติกรรม WYN-080), ปุ่ม clear (×) ปรากฏ/หายตามว่ามีข้อความหรือไม่
- Submit (กดไอคอนแว่นขยาย หรือปุ่ม "ค้นหา" บนคีย์บอร์ด) → คอมมิทคำค้นหา, ปิดคีย์บอร์ด, สลับจาก Divider (ใต้
  Search Bar ตอน Discovery) เป็น Chip Tabs (ตอน Result) ด้วย `motion.base` (200ms)
- แตะ Chip Tab → สลับ `TabBarView` แบบ fade/slide สั้น ๆ (`motion.base`), Tab ที่เคยโหลดแล้วคง state ไว้
  (AutomaticKeepAlive ของเดิม)
- เลื่อนถึงใกล้ท้ายลิสต์ (~300px ก่อนสุด) → โหลดหน้าถัดไปอัตโนมัติ แสดง Spinner 24px ที่ท้ายลิสต์ระหว่างโหลด
- แตะปุ่มติดตาม → เปลี่ยนสถานะปุ่มทันที (optimistic update) ด้วย `motion.fast` (120ms), หากยิง API ไม่สำเร็จ
  ปุ่มคืนสถานะเดิมทันทีโดยไม่มี toast รบกวน (parity กับโค้ดปัจจุบัน)
- แตะปุ่ม clear (×) → เคลียร์ข้อความและคำค้นหาที่ submit แล้ว, กลับสู่ Discovery view ทันที
- Pull-to-refresh: **ไม่มี** ในหน้านี้ (คงพฤติกรรมเดิม — เฉพาะ Top 100 Screen เท่านั้นที่มี)

States:
- **Discovery — Loading**: ส่วน "แฮชแท็กกำลังนิยม" และ "แนะนำให้ติดตาม" แสดง Skeleton shimmer ระหว่างรอข้อมูล
- **Discovery — Loaded**: รายการแฮชแท็ก (สูงสุด preview limit) + ลิงก์ "ดูอันดับทั้งหมด (Top 100)" กึ่งกลาง,
  รายการผู้ใช้แนะนำพร้อมปุ่มติดตาม
- **Discovery — Empty**: ข้อความมิตร ๆ ต่อ section ("ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้" / "ยังไม่มีบัญชีแนะนำให้
  ติดตามตอนนี้") แทนที่ section นั้น ไม่ซ่อนทั้งหน้า
- **กำลังพิมพ์ (ยังไม่ submit)**: เหมือน Discovery ทุกประการ (ตาม logic เดิมที่ยังโชว์ Discovery จนกว่าจะ submit)
- **Result — Loading (หน้าแรก)**: Spinner กลางจอในแท็บที่ active
- **Result — Loaded**: ลิสต์ผลลัพธ์ของแท็บนั้น (List Item สำหรับ User, Card สำหรับ โพสต์/Club)
- **Result — Empty**: Empty State พร้อมข้อความเจาะจงคำค้นหา เช่น 'ไม่พบผู้ใช้สำหรับ "คำค้นหา"'
- **Result — Error**: ข้อความ error กลางจอ + ปุ่ม "ลองใหม่" (Text Button) กดแล้ว retry หน้าแรกของแท็บนั้น
- **Result — Loading more (pagination)**: Spinner 24px แถวท้ายลิสต์ ระหว่างลิสต์เดิมยังแสดงอยู่
- **คำค้นหาสั้นกว่า 2 ตัวอักษร (per-tab guard)**: Empty State พร้อม hint เฉพาะประเภท เช่น "พิมพ์ชื่อ Club
  เพื่อค้นหา" — เกิดได้ในทางเทคนิคแม้ submit แล้ว เพราะ threshold ตรวจซ้ำในแต่ละแท็บ

Responsive Behavior:
- Mobile-first, คอลัมน์เดียว; ความกว้างเนื้อหาถูกจำกัดด้วย content rail ของแอป (โครงเดิม) บนหน้าจอกว้าง
  (แท็บเล็ต/พับได้) เพื่อไม่ให้แถวผลลัพธ์ยืดเต็มจอจนอ่านยาก
- แนวนอน (landscape): Search Bar sticky บนยังคงอยู่, ลิสต์เลื่อนแนวตั้งตามปกติ
- จอเล็ก (<360dp): Chip Tabs ลด padding ภายในได้ แต่ต้องคง touch target ≥44×44px ต่อช่อง; label สั้นอยู่แล้ว
  (User/โพสต์/Club) ไม่ต้อง ellipsis
- Dynamic type / system font scaling: ความสูงแถว List Item/HashtagRankRow ยืดตามขนาดตัวอักษร, Avatar/ไอคอน
  คงขนาดเดิม, ข้อความยาวใน title ตัด ellipsis 1 บรรทัดตามเดิม

Accessibility:
- Search Bar มี semantic label "ช่องค้นหา", ปุ่มแว่นขยาย label "ค้นหา", ปุ่ม clear label "ล้างคำค้นหา"
  (คง tooltip เดิม)
- Chip Tabs ประกาศสถานะ selected/unselected ผ่าน Semantics (role tab, selected: true/false)
- ทุกแถวผลลัพธ์คง Semantics label แบบเดิมทุกคำ (เช่น "ผู้ใช้ {ชื่อ} ยูสเซอร์เนม {username} กดเพื่อดูโปรไฟล์",
  "อันดับที่ {n} #{tag} กดเพื่อดูโพสต์ที่มีแฮชแท็กนี้") — ห้ามเปลี่ยนถ้อยคำ semantics ระหว่าง re-skin เพราะจะ
  ทำ widget test เดิมพัง
- ปุ่มติดตามประกาศสถานะปัจจุบัน (ติดตาม/กำลังติดตาม/ขอแล้ว) ให้ screen reader อ่านตรงกับ label ที่แสดง
- ทุก error/empty state มี icon + ข้อความคู่กันเสมอ ไม่ใช้สีสื่อความหมายอย่างเดียว
- Contrast ทุกคู่สี (ink/paper, ink.muted/surface, accent/paper) ต้องผ่าน WCAG AA ทั้ง light/dark ตาม wyn-142
- Touch target ≥44×44px: ไอคอนแว่นขยาย/clear, ปุ่มติดตาม (ผ่าน padding แม้ตัวปุ่มภาพสูงกว่า ~36px), Chip Tab

Design Rules:
- อ้างอิงเฉพาะ token/คอมโพเนนต์จาก wyn-142 และ wyn-143 — ห้ามใช้สี/ฟอนต์/รัศมีนอกเอกสารทั้งสอง
- Search Bar ใช้สเปก wyn-143 §2c ตรงตัว (pill, `color.surface`, sticky) ไม่ปรับแก้เพิ่ม
- Segmented Chip Tabs และ HashtagRankRow เป็น "ส่วนขยายเฉพาะหน้าจอนี้" ตามข้อยกเว้นที่ระบุใน wyn-143 Handoff
  (ไม่มีคอมโพเนนต์ตรงในไลบรารี แต่ดัดแปลงจาก Chip §6 / List Item §10 โดยไม่เพิ่ม token ใหม่)
- ห้ามใช้ Liquid Glass ที่พื้นผิว Search Bar หรือ Card ใด ๆ — พื้นผิวทึบเสมอ (`color.surface`)
- ต้องรองรับ Light/Dark mode ตั้งแต่เริ่มต้น ไม่ทำ dark mode ทีหลัง
- คง business logic เดิมทั้งหมด: debounce/submit-only search (WYN-080), threshold 2 ตัวอักษร, pagination
  300px-before-bottom, Pop tab ที่ยังถูกซ่อนไว้ (WYN-102, ไม่ต้อง re-skin เพราะยังไม่เปิดใช้งาน), กติกา
  ห้ามระบุจำนวนโพสต์ใต้แฮชแท็ก (WYN-101)
- **Staged rollout บังคับ**: การเปลี่ยน visual identity ทั้งหมดถือเป็น user-facing behavior change ต้อง gate
  ด้วย `DeveloperAccessService.isDeveloperAccount()` ตาม `.wyn/company/WORKFLOW.md`/WYN-125 — ผู้ใช้ทั่วไป
  ต้องเห็นหน้าจอ Search แบบเดิม (Sapphire/ของปัจจุบัน) จนกว่า Founder จะสั่งเปิดให้ทุกคนเห็นของใหม่โดยชัดเจน

Handoff:
- ต้องรอ Founder ยืนยัน wyn-142/wyn-143 อย่างเป็นทางการก่อนส่งต่อ AI Coding implement จริง (ปัจจุบันทั้งคู่
  สถานะ PROPOSED)
- ไฟล์โค้ดที่เกี่ยวข้อง: `app/lib/features/search/presentation/search_screen.dart`,
  `app/lib/features/search/presentation/widgets/discovery_view.dart`,
  `app/lib/features/search/presentation/widgets/hashtag_rank_row.dart`,
  `app/lib/features/search/presentation/widgets/search_state_message.dart`,
  `app/lib/features/search/presentation/widgets/search_user_results_tab.dart`,
  `app/lib/features/search/presentation/widgets/search_drop_results_tab.dart`,
  `app/lib/features/search/presentation/widgets/search_club_results_tab.dart`,
  `app/lib/features/search/presentation/widgets/search_pop_results_tab.dart` (ถูกซ่อนอยู่ ไม่ต้อง re-skin
  จนกว่าจะเปิดใช้), `app/lib/core/widgets/wynos_social_chrome.dart` (โครง `WynosContentRail`/
  `WynosSearchSurface`/`WynosSocialTabBar` เดิมที่จะถูกแทน token หรือแทนที่บางส่วนด้วย Chip Tabs)
- AI Coding ต้อง wrap การเปลี่ยนแปลง visual ด้วย `isDeveloperAccount()` ตาม WYN-125 เป็นค่าเริ่มต้น และรัน
  `flutter analyze`/`flutter test` เทียบกับ widget test เดิมของ Search ก่อนส่งต่อ QA

---

## Screen 2 — Top 100 (`top_100_screen.dart`)

Screen: Top 100 — หน้ารายชื่ออันดับแฮชแท็กกำลังนิยมแบบเต็ม (เปิดจากลิงก์ในหน้า Search)

Purpose: แสดงอันดับแฮชแท็กกำลังนิยมทั้งหมด (เต็ม limit) ให้ผู้ใช้ไล่ดูและกดเข้าไปดูโพสต์ของแฮชแท็กนั้นได้

User Flow:
1. เข้าจากลิงก์ "ดูอันดับทั้งหมด (Top 100)" ใน Discovery view ของหน้า Search
2. หน้าจอโหลดรายการเต็ม (Spinner กลางจอระหว่างรอ)
3. ผู้ใช้เลื่อนดูรายการที่เรียงอันดับ, ดึงลง (pull-to-refresh) เพื่อโหลดใหม่
4. แตะแถวแฮชแท็ก → เปิดหน้าฟีดของแฮชแท็กนั้น (นอกขอบเขตเอกสารนี้)
5. แตะปุ่มย้อนกลับ (chevron ซ้ายบน) → กลับไปหน้า Search

Components:
- **Top App Bar** (wyn-143 §3) — สูง 56px, ปุ่มย้อนกลับ (chevron) ซ้าย ขนาด touch target 44×44px, ชื่อหน้าจอ
  "Top 100" ใช้ `type.display.l` **ชิดซ้าย** ตามสเปกใหม่ (เปลี่ยนจากของเดิมที่จัดกึ่งกลาง — เป็นการเปลี่ยน
  ตั้งใจตาม identity ใหม่ ไม่ใช่ regression), เส้นคั่นบาง `color.hairline` ใต้ app bar
- **HashtagRankRow** — คอมโพเนนต์เดียวกับที่ใช้ใน Discovery preview ของ Screen 1 ทุกประการ (ห้ามมีสไตล์
  เพี้ยนกันระหว่างสองที่) — [เลขอันดับ] — [`#แฮชแท็ก` + เมตาไลน์ "กำลังนิยมใน ไทย" ไม่มีจำนวนโพสต์] —
  [ไอคอน more (⋯)] คั่นด้วย `color.hairline` (ไม่มีเส้นหลังแถวสุดท้าย)
- **Loading / Skeleton** (wyn-143 §8) — Spinner ขนาด 32px กลางจอระหว่างโหลดครั้งแรก, spinner ของ
  pull-to-refresh สี `color.accent`
- **Empty State** (wyn-143 §12) — ข้อความ "ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้" เมื่อผลลัพธ์ว่าง
- **Inline error + Text Button** — ข้อความ "โหลด Top 100 ไม่สำเร็จ" กลางจอ + ปุ่ม "ลองใหม่" (wyn-143 §1
  Text Button, ตัวหนังสือ `color.accent`)

Interactions:
- ดึงลิสต์ลง (pull-to-refresh) → รีโหลดข้อมูลทั้งหมด, แสดง spinner สี `color.accent` ระหว่างรอ, ลิสต์เดิม
  ยังแสดงอยู่จนกว่าข้อมูลใหม่มาแทน
- แตะแถวแฮชแท็ก → push ไปหน้าฟีดแฮชแท็กด้วย motion เปลี่ยนหน้าแบบมาตรฐาน (`motion.slow`, 320ms)
- แตะปุ่มย้อนกลับ → pop กลับหน้า Search ทันที (ไม่มี confirmation)
- แตะปุ่ม "ลองใหม่" ตอน error → เรียกโหลดข้อมูลใหม่ทั้งหมด (เหมือน retry logic เดิม)

States:
- **Loading (ครั้งแรก)**: Spinner กลางจอ, ไม่มี app bar action อื่นนอกจากปุ่มย้อนกลับ
- **Loaded**: ลิสต์อันดับเต็ม เลื่อนได้, รองรับ pull-to-refresh
- **Empty**: Empty State กลางจอแทนลิสต์
- **Error**: ข้อความ error + ปุ่ม "ลองใหม่" กลางจอ แทนลิสต์ทั้งหมด (parity กับโค้ดปัจจุบัน — ไม่ใช่ inline
  banner เพราะทั้งหน้าคือลิสต์เดียว)
- **Refreshing**: overlay pull-to-refresh spinner ด้านบนลิสต์เดิม (ลิสต์เดิมไม่หายระหว่างรีเฟรช)

Responsive Behavior:
- คอลัมน์เดียวเต็มความกว้าง จำกัดด้วย content rail เดิมบนจอกว้าง (แท็บเล็ต/พับได้) เหมือน Screen 1
- แนวนอน (landscape): App bar คงสูง 56px, ลิสต์เลื่อนแนวตั้งตามปกติ
- ข้อความแฮชแท็กยาวตัด ellipsis 1 บรรทัดเสมอ (คงพฤติกรรมเดิม) แม้ในจอแคบ
- Dynamic type: ความสูงแถวยืดตามขนาดตัวอักษรของระบบ, กรอบเลขอันดับกว้างพอสำหรับสูงสุด 3 หลัก ("100")

Accessibility:
- ปุ่มย้อนกลับมี semantic label "ย้อนกลับ"
- ชื่อหน้าจอ "Top 100" ประกาศเป็น heading ให้ screen reader
- แต่ละแถวคง Semantics label เดิม: "อันดับที่ {n} #{tag} กดเพื่อดูโพสต์ที่มีแฮชแท็กนี้"
- Empty/Error state มี icon หรือข้อความชัดเจนคู่กัน ไม่ใช้เพียงสีบอกสถานะ
- Contrast เลขอันดับ (`color.ink.muted`) กับพื้นหลัง `color.paper` ต้องผ่าน WCAG AA
- ความสูงแถวขั้นต่ำ 56px ผ่าน touch target 44×44px อยู่แล้วโดยไม่ต้องปรับ

Design Rules:
- อ้างอิงเฉพาะ token/คอมโพเนนต์จาก wyn-142 และ wyn-143
- Top App Bar ต้องเปลี่ยนชื่อหน้าจอจาก centered เป็น **ชิดซ้าย** ตามสเปก wyn-143 §3 ตรงตัว — เป็น
  intentional change ของ identity ใหม่
- HashtagRankRow ต้องเหมือนกับใน Screen 1 (Discovery preview) เป๊ะ — ห้าม divergent style ระหว่างสองที่
  ที่ใช้คอมโพเนนต์เดียวกันในโค้ดจริง (`HashtagRankRow` widget ใช้ร่วมกันอยู่แล้ว)
- ห้ามใส่จำนวนโพสต์ใต้แฮชแท็กตาม WYN-101 (กติกาถาวรของ Founder ยังผูกพันอยู่ไม่ว่าจะเปลี่ยน visual ใด)
- ห้ามใช้ Liquid Glass, ต้องรองรับ Light/Dark mode ตั้งแต่ต้น เหมือน Screen 1
- Pull-to-refresh, retry-on-error, empty-state logic ต้องคงพฤติกรรมเดิมทั้งหมด เปลี่ยนเฉพาะสี/ฟอนต์/ระยะ/
  รัศมีตามระบบ Flare
- **Staged rollout บังคับ** เหมือน Screen 1 — gate ด้วย `isDeveloperAccount()` ตาม WYN-125

Handoff:
- ต้องรอ Founder ยืนยัน wyn-142/wyn-143 อย่างเป็นทางการก่อนส่งต่อ AI Coding implement จริง
- ไฟล์โค้ดที่เกี่ยวข้อง: `app/lib/features/search/presentation/top_100_screen.dart`,
  `app/lib/features/search/presentation/widgets/hashtag_rank_row.dart` (ใช้ร่วมกับ Screen 1)
- AI Coding ต้อง wrap ด้วย `isDeveloperAccount()` ตาม WYN-125 และรัน `flutter analyze`/`flutter test`
  เทียบกับ widget test เดิมของ Top100Screen ก่อนส่งต่อ QA
