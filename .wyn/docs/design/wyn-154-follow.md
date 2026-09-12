# WYN "Flare" — Follow (V1.0 — PROPOSED)

Status: PROPOSED
Owner: AI Design
อ้างอิง: wyn-142-visual-identity-redesign.md, wyn-143-core-component-library.md

## หมายเหตุก่อนเริ่ม

- สเปกนี้ครอบคลุม 4 หน้าจอที่มีอยู่แล้วในโค้ด (`app/lib/features/follow/presentation/`): `follow_list_screen.dart` (ผู้ติดตาม/กำลังติดตาม), `follow_request_list_screen.dart` (คำขอติดตาม), `close_friends_screen.dart` (เพื่อนที่สนิท), `exclude_friends_screen.dart` (เลือกเพื่อนที่จะซ่อน) — **นี่คือการรีสกินด้วย Flare identity เท่านั้น ไม่เปลี่ยน functional requirement เดิม** (requirement ของ audience/privacy อ้างอิงจาก `wyn-097-099-audience-friests-and-likes-privacy.md` — คงเดิมทุกประการ)
- เพราะเป็นการปรับ visual ของฟีเจอร์เดิมที่ผู้ใช้ทั่วไปใช้งานอยู่แล้ว (ไม่ใช่ฟีเจอร์ใหม่) จึง **ไม่ต้อง gate ด้วย `DeveloperAccessService.isDeveloperAccount()`** ตามข้อยกเว้นใน WORKFLOW.md — ถ้า AI Coding เห็นว่าการเปลี่ยน visual ทั้งระบบพร้อมกันมีความเสี่ยงจนอยากขอ staged rollout เป็นกรณีพิเศษ ให้ถาม Founder ก่อน ไม่ใช่ตัดสินใจเอง
- ทุก token/คอมโพเนนต์ที่อ้างถึงด้านล่างมาจาก `wyn-142` และ `wyn-143` เท่านั้น จุดไหนที่ library เดิมยังไม่มี component ที่ตรงเป๊ะ (เช่น Switch, Checkbox, Segmented Tab, Notice Banner) จะระบุไว้ชัดเจนว่า "ประกอบจาก token ที่มีอยู่" ไม่ใช่ประดิษฐ์ component ใหม่ทั้งชิ้น
- Error feedback ที่โค้ดเดิมใช้ `ScaffoldMessenger`/`SnackBar` ทั้งหมด (remove follower ล้มเหลว, accept/reject ล้มเหลว, toggle close friend ล้มเหลว) ให้เปลี่ยนมาใช้ **Toast component (wyn-143 §7)** แทนเพื่อความสม่ำเสมอทั้งระบบ — ระบุไว้ครั้งเดียวที่นี่ ใช้กับทั้ง 4 หน้าจอ

---

## Screen: Follow List — ผู้ติดตาม / กำลังติดตาม (`follow_list_screen.dart`)

**Purpose:** ให้ผู้ใช้ดูรายชื่อผู้ติดตาม (Followers) และรายชื่อที่ตัวเองติดตาม (Following) ของโปรไฟล์ใดก็ได้ (ตัวเองหรือคนอื่น) ในหน้าจอเดียว สลับดูได้ด้วยแท็บ พร้อมค้นหาและกดติดตาม/เลิกติดตามได้ทันทีจากแถวรายชื่อ

**User Flow:**
1. เปิดจากโปรไฟล์ใดก็ได้ (ตัวเอง/คนอื่น) → เห็นแท็บ "ผู้ติดตาม"/"กำลังติดตาม" ตามที่มาจาก, โหลดหน้าแรกของแท็บนั้นทันที
2. แตะสลับแท็บ → โหลดครั้งแรกของแท็บนั้นถ้ายังไม่เคยโหลด (แท็บที่เคยโหลดแล้วคง scroll position/ข้อมูลเดิมไว้ ไม่ fetch ซ้ำ)
3. พิมพ์ในช่องค้นหา → กรองเฉพาะรายชื่อที่โหลดมาแล้วในแท็บปัจจุบัน (client-side, ไม่เรียก API ใหม่)
4. เลื่อนลงสุดรายการ → auto-load หน้าถัดไป (infinite scroll)
5. แตะแถว → ไปหน้าโปรไฟล์ของคนนั้น
6. แตะปุ่ม Follow บนแถว → toggle ติดตาม/เลิกติดตามทันที (optimistic)
7. (เฉพาะแท็บ "ผู้ติดตาม" ของโปรไฟล์ตัวเอง) แตะ "ลบ" → ยืนยันใน Modal → เอาออกจากรายชื่อผู้ติดตามทันทีเมื่อสำเร็จ

**Components:**
- Top App Bar (wyn-143 §3): back chevron ซ้าย (touch target 44×44), title = ชื่อโปรไฟล์เจ้าของลิสต์ (`type.display.l`, ชิดซ้ายตามสเปก — **เปลี่ยนจากของเดิมที่ centerTitle:true** ให้ตรงกับ wyn-143), `maxLines: 1` + ellipsis กันชื่อยาวล้น, เส้นคั่นล่าง `color.hairline` 1px
- Segmented Tab (ประกอบจาก token, ไม่มี component สำเร็จรูปใน wyn-143): แถวสองช่องเท่ากันใต้ App Bar, label `type.body.m`, active = สี `color.ink` + underline หนา 2px สี `color.accent`, inactive = สี `color.ink.muted` + underline โปร่งใส, พื้นหลังทั้งแถบไม่มีสี (เป็น `color.paper`), เส้นคั่นล่างทั้งแถบ `color.hairline`
- Search Bar (wyn-143 §2c): pill, พื้นหลัง `color.surface`, ไอคอนแว่นขยายซ้าย, **เพิ่มปุ่ม clear (×) ขวาเมื่อมีข้อความ** ตามสเปก (ของเดิมไม่มี — เพิ่มให้ครบตาม wyn-143)
- List Item (wyn-143 §10): leading Avatar 40px (wyn-143 §5), title = ชื่อที่แสดง (`type.body.l` SemiBold, `color.ink`), subtitle = `@username` (`type.body.s`, `color.ink.muted`), trailing = ปุ่ม Follow แบบ compact หรือปุ่ม "ลบ"
- Follow action (แถวปกติ): Secondary Button ขนาด compact (border `color.accent` 1.5px, label `color.accent`, `type.caption`/`type.body.s`) แสดง 3 สถานะ "ติดตาม"/"กำลังติดตาม"/"ขอติดตามแล้ว" — label เปลี่ยนด้วย fade-switch `motion.fast`
- ปุ่ม "ลบ" (เฉพาะแท็บผู้ติดตามของตัวเอง): Secondary Button compact เดียวกัน แต่ label `color.ink` (ไม่ใช่ error — เป็น action ที่ยืนยันผ่าน Modal อยู่แล้ว ไม่ต้องเน้นสีเตือนซ้ำที่ปุ่ม)
- Modal ยืนยันลบผู้ติดตาม (wyn-143 §9): "เอา [ชื่อ] ออกจากผู้ติดตาม?", ปุ่มยืนยัน "เอาออก" ใช้ `color.error`, ปุ่ม "ยกเลิก" เป็น Text Button
- Loading/Skeleton (wyn-143 §8): โหลดหน้าแรก → แสดง skeleton แถว List Item 6 แถว (ไม่ใช่ spinner เต็มจอแบบเดิม เพื่อ perceived performance ที่ดีกว่า) โหลดหน้าถัดไป → Spinner `color.accent` 24px ท้ายลิสต์
- Empty State (wyn-143 §12): แยกข้อความตามแท็บ — "ผู้ติดตาม": "ยังไม่มีใครติดตามคุณเลย"; "กำลังติดตาม": "คุณยังไม่ได้ติดตามใครเลย ลองกดติดตามจากโพสต์ที่ชอบดูสิ" — ไอคอน line-art + `type.heading.2` + `type.body.m` สี `color.ink.muted`
- ผลค้นหาไม่พบ: ข้อความกลางจอ `type.body.s` สี `color.ink.muted` (ไม่ใช้ full Empty State illustration เพราะเป็น transient state)
- Toast (wyn-143 §7): แสดงเมื่อ "ลบ" ล้มเหลว ("ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง")

**Interactions:**
- แตะแท็บ → สลับ list ทันที ไม่มี animation ข้ามหน้า (แค่ underline เลื่อนด้วย `motion.fast`)
- Pull-to-refresh → reload แท็บปัจจุบันจากหน้าแรก
- แตะปุ่ม Follow → optimistic toggle + haptic feedback (ของเดิมมี `WynFeedback.follow()` อยู่แล้ว คงไว้), เด้งกลับ state เดิมถ้า API fail (ไม่มี toast แจ้ง error ตรงนี้เพราะเป็นการ toggle เร็ว ๆ ที่ error ไม่บ่อย — คงพฤติกรรมเดิม)
- แตะ "ลบ" → เปิด Modal ยืนยัน → ถ้ายืนยัน แสดง spinner แทนปุ่มระหว่างรอ → ลบแถวออกจากลิสต์เมื่อสำเร็จ, แสดง Toast เมื่อล้มเหลว (ปุ่มกลับมาเหมือนเดิม)
- พิมพ์ค้นหา → กรองทันทีทุกครั้งที่พิมพ์ (debounce ไม่จำเป็นเพราะเป็น client-side filter)

**States:** loading initial (skeleton), loading more (spinner), error โหลดไม่สำเร็จ (ข้อความ + Text Button "ลองใหม่"), empty ต่อแท็บ, search-no-result, populated, row-pending (ปุ่ม "ลบ" กำลังทำรายการ)

**Responsive Behavior:** List เต็มความกว้างจอ, row สูงขั้นต่ำ 56px, ชื่อ/username ตัดด้วย ellipsis บรรทัดเดียวเมื่อยาวเกิน, title ของ App Bar ตัดด้วย ellipsis เดียวกัน; รองรับ dynamic type ของระบบ (แถวยืดความสูงได้เมื่อ font ใหญ่ขึ้น ไม่ fix สูงตายตัวเกิน 56px)

**Accessibility:** แต่ละแถวมี `Semantics(label: "ผู้ใช้ ... กดเพื่อดูโปรไฟล์", button: true)` (คงพฤติกรรมเดิม), ปุ่ม Follow มี semantics label อธิบายสถานะและ action ถัดไป (คงพฤติกรรมเดิมจาก `FollowActionButton`), ปุ่ม Follow แบบ compact ต้องมี padding แตะได้ครบ 44×44px แม้ขนาดภาพจะเล็กกว่า (ตามกติกา touch target ของ wyn-142 ซึ่งอยู่เหนือความ compact ทาง visual), contrast ของ underline tab/ปุ่ม Follow ผ่าน AA ทั้ง 2 โหมด

**Design Rules:** ใช้ `color.accent` เฉพาะ underline ของแท็บ active และปุ่ม Follow เท่านั้น ห้ามใช้ accent กับพื้นหลังทั้งแถบ; ห้ามลอก layout list ของ IG โดยตรง (คงโครง list item ตามที่มีอยู่); Top App Bar เปลี่ยนจาก center-title เป็น left-title ตาม wyn-143 ให้ตรงกันทุกหน้าจอในกลุ่มนี้

**Handoff:** AI Coding ปรับ `follow_list_screen.dart` ให้ใช้ token ใหม่จาก `app/lib/core/design/` (หลัง Founder ยืนยัน wyn-142/143), เพิ่มปุ่ม clear ในช่องค้นหา, เปลี่ยน error SnackBar เป็น Toast component, เปลี่ยน full-screen spinner ตอนโหลดครั้งแรกเป็น skeleton list — ไม่เปลี่ยน business logic/repository เดิม

---

## Screen: Follow Request List — คำขอติดตาม (`follow_request_list_screen.dart`)

**Purpose:** ให้ผู้ใช้ที่ตั้งบัญชีเป็น Private ดูและจัดการ (ยอมรับ/ปฏิเสธ) คำขอติดตามที่ยังไม่ตอบทั้งหมด

**User Flow:**
1. เข้าจากโปรไฟล์ตัวเอง (มีคำขอค้างอย่างน้อย 1 รายการ) → โหลดรายชื่อผู้ขอหน้าแรกทันที
2. เลื่อนลงสุด → auto-load หน้าถัดไป
3. แตะ "ยอมรับ" → เพิ่มเป็นผู้ติดตามทันที, แถวหายไปจากลิสต์
4. แตะ "ปฏิเสธ" → ยืนยันใน Modal → แถวหายไปจากลิสต์เมื่อยืนยัน

**Components:**
- Top App Bar (wyn-143 §3): title "คำขอติดตาม" (`type.display.l` ชิดซ้าย — เปลี่ยนจาก default `AppBar(title:)` เดิมที่ไม่ได้ระบุ style ให้ตรง token), back chevron 44×44
- List Item (wyn-143 §10): leading Avatar 40px, title ชื่อ (`type.body.l` SemiBold `color.ink`), subtitle `@username` (`type.body.s` `color.ink.muted`), trailing = ปุ่มคู่ "ปฏิเสธ"/"ยอมรับ"
- Secondary Button ("ปฏิเสธ") + Primary Button ("ยอมรับ") (wyn-143 §1) ขนาด compact ให้พอดีแถวสูง 56px, เว้นระยะระหว่างปุ่ม `space2` (8px)
- Modal ยืนยันปฏิเสธ (wyn-143 §9): title "ปฏิเสธคำขอติดตามจาก [ชื่อ]?", content "ผู้ขอจะไม่ได้รับแจ้งเตือน", ปุ่มยืนยัน "ปฏิเสธ" สี `color.error` (destructive-style เพราะเป็น action เชิงลบต่อคำขอของอีกฝ่าย), ปุ่ม "ยกเลิก" เป็น Text Button
- Loading/Skeleton (wyn-143 §8): skeleton List Item ระหว่างโหลดหน้าแรก, spinner `color.accent` ท้ายลิสต์ระหว่างโหลดหน้าถัดไป
- Empty State (wyn-143 §12): "ยังไม่มีคำขอติดตาม" + ไอคอน line-art + `type.body.m` `color.ink.muted`
- Toast (wyn-143 §7): แสดงเมื่อ "ยอมรับ"/"ปฏิเสธ" ล้มเหลว

**Interactions:**
- แตะ "ยอมรับ" → แสดง spinner แทนปุ่มคู่ระหว่างรอ → ลบแถวออกเมื่อสำเร็จ, คืนปุ่มกลับ + Toast เมื่อล้มเหลว
- แตะ "ปฏิเสธ" → เปิด Modal → ยืนยันแล้วทำเหมือนข้างต้น
- Pull-to-refresh → reload หน้าแรก

**States:** loading initial (skeleton), loading more (spinner), error (ข้อความ + Text Button "ลองใหม่"), empty, populated, row-pending (ปุ่มคู่ถูกแทนที่ด้วย spinner)

**Responsive Behavior:** แถวสูงขั้นต่ำ 56px, ปุ่มคู่ไม่ overflow ที่จอกว้าง 360px (ชื่อ/username ยาวถูก ellipsis ก่อนที่จะดันปุ่มออกนอกจอ — คง `Expanded` เดิมของ text column)

**Accessibility:** แต่ละแถวควรมี semantics รวมชื่อ+username เหมือนแถวอื่นในกลุ่มนี้ (ของเดิมยังไม่มี `Semantics` wrapper ชัดเจนบนแถวนี้ — เพิ่มให้ตรงกับ pattern ของ `follow_list_screen.dart`/`close_friends_screen.dart`), ปุ่ม "ยอมรับ"/"ปฏิเสธ" มี touch target ≥44×44 แม้ compact, contrast ปุ่ม error ใน Modal ผ่าน AA ทั้ง 2 โหมด

**Design Rules:** "ยอมรับ" ใช้ Primary Button (`color.accent` พื้นหลัง) เพราะเป็น action หลักที่พึงประสงค์ของหน้านี้, "ปฏิเสธ" ใช้ Secondary Button เพื่อไม่แข่งความสำคัญกับปุ่มหลัก — ตรงตามหลัก single-accent ของ wyn-142

**Handoff:** AI Coding ปรับ AppBar title ให้ตรง token, เพิ่ม `Semantics` wrapper รายแถว, แปลง error SnackBar เป็น Toast, ปรับปุ่มเป็น Primary/Secondary Button ทางการจาก theme ใหม่ — ไม่เปลี่ยน business logic เดิม

---

## Screen: Close Friends — เพื่อนที่สนิท (`close_friends_screen.dart`)

**Purpose:** ให้ผู้ใช้จัดการรายชื่อ "เพื่อนที่สนิท" แบบถาวร (persist ข้ามโพสต์) สำหรับใช้เป็นตัวเลือก audience ตอนโพสต์ Drop — อ้างอิง requirement เต็มที่ `wyn-097-099-audience-friends-and-likes-privacy.md` Screen 4

**User Flow:**
1. เข้าได้ 2 ทาง: (ก) จาก Audience Selector ตอนเลือก "เพื่อนที่สนิท" ครั้งแรก (มี welcome banner) (ข) จาก Settings > ความเป็นส่วนตัว (ไม่มี banner)
2. เห็นรายชื่อเพื่อน (mutual-follow) ทั้งหมด พร้อม Switch บอกสถานะอยู่ในลิสต์หรือไม่
3. ค้นหาชื่อ/username เพื่อกรองรายชื่อ
4. แตะแถวหรือ Switch → toggle เพิ่ม/ลบออกจากลิสต์ทันที (บันทึกจริงทันที ไม่ต้องกดยืนยัน/เสร็จสิ้น)

**Components:**
- Top App Bar (wyn-143 §3): title "เพื่อนที่สนิท" (`type.display.l` ชิดซ้าย), back chevron 44×44, ไม่มีปุ่ม action ขวา
- Search Bar (wyn-143 §2c): เหมือน Follow List (พื้นหลัง `color.surface`, เพิ่มปุ่ม clear ให้ครบตามสเปก)
- Notice Card (ประกอบจาก Card wyn-143 §4 + ไอคอน — ไม่มี component "Banner" แยกใน wyn-143): พื้นหลัง `color.surface`, radius `radius.m`, padding 16px, ไอคอน `info_outline` สี `color.ink.muted`, ข้อความ "คุณยังไม่มีเพื่อนที่สนิท เลือกจากรายชื่อเพื่อนของคุณได้เลย" (`type.body.s`, `color.ink.muted`) — แสดงเฉพาะทางเข้า (ก) และเฉพาะตอนลิสต์ยังว่าง ไม่มีปุ่มปิด (หายเองเมื่อมีคนอยู่ในลิสต์แล้ว)
- List Item (wyn-143 §10): leading Avatar 40px, title (`type.body.l` SemiBold), subtitle `@username` (`type.body.s` `color.ink.muted`), trailing = Switch
- Switch (ไม่มี component นี้ใน wyn-143 โดยตรง — ใช้ platform-adaptive switch ปรับสี ON เป็น `color.accent` ตาม theme, OFF track เป็น `color.hairline`): ON = `color.accent`, ระหว่างรอผลบันทึกแสดง spinner `color.accent` 20px แทนตำแหน่ง Switch ชั่วคราว
- Empty State (wyn-143 §12): "คุณยังไม่มีเพื่อน (mutual follow) ให้เลือก"
- Loading/Skeleton (wyn-143 §8): skeleton List Item ระหว่างโหลดครั้งแรก
- Toast (wyn-143 §7): แสดงเมื่อ toggle ล้มเหลว ("ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง")

**Interactions:**
- แตะแถว (ที่ไหนก็ได้) หรือ Switch → optimistic toggle ทันที + เรียก API บันทึกจริงทันที (ต่างจาก Exclude Friends ที่รอกด "เสร็จสิ้น")
- ถ้า API ล้มเหลว → เด้งกลับสถานะเดิม + Toast แจ้ง error
- ค้นหา → กรองทันที (client-side)

**States:** loading initial (skeleton), error โหลดไม่สำเร็จ (ข้อความ + Text Button "ลองใหม่"), empty (ไม่มีเพื่อน mutual-follow เลย), search-no-result, populated (มี/ไม่มี welcome banner ตาม entry point), row-pending (spinner แทน Switch)

**Responsive Behavior:** เหมือน Follow List — row สูงขั้นต่ำ 56px, ข้อความยาวตัด ellipsis, Notice Card ยืดเต็มความกว้าง minus margin `space6` ซ้ายขวา

**Accessibility:** แต่ละแถว `Semantics(label: "[ชื่อ], อยู่ในรายชื่อเพื่อนที่สนิท/ไม่อยู่ในรายชื่อเพื่อนที่สนิท", toggled: isOn)` (คงพฤติกรรมเดิม — ถูกต้องแล้ว), Switch ต้องมี touch target ครบ 44×44 ผ่านทั้งแถว (ทั้งแถวแตะได้ ไม่ใช่แค่ตัว Switch), contrast ของ track ON/OFF ผ่าน AA ทั้ง 2 โหมด

**Design Rules:** เพราะเป็น setting ถาวร (persist) จึงใช้ Switch (สื่อ "เปิด/ปิดสถานะค้าง") ไม่ใช่ Checkbox (สื่อ "เลือกสำหรับครั้งนี้ครั้งเดียว" อย่างใน Exclude Friends) — คงหลัก semantic เดิมจาก wyn-097 ไว้ตรงตามเดิม เพียงเปลี่ยนสีอ้างอิงจาก `sapphire`/`colorScheme.primary` เดิมเป็น `color.accent` ของ Flare

**Handoff:** AI Coding เปลี่ยน `Switch.adaptive` ให้ผูกสี ON กับ `color.accent` ของ theme ใหม่แทน `colorScheme.primary` เดิม, แปลง Notice Card/Toast ตามสเปกนี้, เพิ่มปุ่ม clear ในช่องค้นหา — ไม่เปลี่ยน business logic/repository เดิม

---

## Screen: Exclude Friends — เลือกเพื่อนที่จะซ่อน (`exclude_friends_screen.dart`)

**Purpose:** ให้ผู้ใช้เลือกรายชื่อเพื่อน (mutual-follow) ที่จะไม่เห็น Drop ที่กำลังโพสต์อยู่นี้ เป็นการเลือกรายโพสต์ (ไม่ persist ข้ามโพสต์ — คนละเรื่องกับ Close Friends) — อ้างอิง requirement เต็มที่ `wyn-097-099-audience-friends-and-likes-privacy.md` Screen 3

**User Flow:**
1. เปิดจาก Audience Selector ตอนเลือก "ซ่อนเพื่อนบางคน" ระหว่างกำลังคอมโพส Drop
2. เห็นรายชื่อเพื่อน (mutual-follow) พร้อม checkbox, ค้นหาได้
3. แตะแถวเพื่อ toggle เลือก/ไม่เลือก (ยังไม่บันทึกจริง แค่ state ชั่วคราวใน parent)
4. แตะ "เสร็จสิ้น (N)" มุมขวาบน → ปิดหน้าจอ กลับไปหน้าคอมโพส Drop พร้อมชุดรายชื่อที่เลือก
5. ถ้ากลับมาเปิดหน้านี้อีกครั้งในเซสชันเดียวกัน (ยังไม่กด "แชร์") → เห็น checkbox ตามที่เลือกไว้ก่อนหน้า ไม่รีเซ็ต

**Components:**
- Top App Bar (wyn-143 §3): back chevron ซ้าย (pop พร้อมค่าที่เลือกไว้ ไม่ใช่ "ยกเลิก"), title "เลือกเพื่อนที่จะซ่อนโพสต์นี้" — **ข้อยกเว้นขนาด:** ใช้ `type.heading.2` (18/24) แทน `type.display.l` เพราะข้อความยาวกว่าหน้าจออื่นในกลุ่มนี้มาก เสี่ยง overflow ที่จอกว้าง 360px, `maxLines: 2` + ellipsis หากยังไม่พอ, action ขวา = Text Button "เสร็จสิ้น"/"เสร็จสิ้น (N)" สี `color.accent`
- Search Bar (wyn-143 §2c): เหมือนหน้าอื่นในกลุ่มนี้
- List Item (wyn-143 §10) + Checkbox: leading Avatar 40px, title/subtitle เหมือนหน้าอื่น, trailing = Checkbox (ไม่มี component นี้ใน wyn-143 โดยตรง — กำหนดรูปแบบ: unchecked = กรอบ 1.5px `color.hairline` radius `radius.s` ขนาด 22×22px, checked = พื้นเต็ม `color.accent` + ไอคอนถูกสีขาว)
- Empty State (wyn-143 §12): "คุณยังไม่มีเพื่อน (ติดตามกันทั้งสองทาง) ให้เลือก"
- Loading/Skeleton (wyn-143 §8): skeleton List Item ระหว่างโหลด
- Toast (wyn-143 §7): แสดงเมื่อโหลดรายชื่อล้มเหลว ("ลองใหม่") — ปุ่ม retry เป็น Text Button ตามของเดิม ไม่ใช้ Toast แทน error state เต็มหน้า (คงรูปแบบ inline error message เดิมตาม wyn-143 §7 ที่ระบุว่า error ที่ผูกกับ field/หน้าเฉพาะใช้ inline ไม่ใช้ toast)

**Interactions:**
- แตะที่ไหนก็ได้ในแถว → toggle checked/unchecked ทันที ไม่มี auto-save เครือข่าย (state อยู่ใน parent `CreateDropScreen`)
- แตะ "เสร็จสิ้น" → ปิดหน้าพร้อมส่งค่าที่เลือกกลับ (ไม่มี "ยกเลิก" แยก — ปุ่มกลับ/gesture ก็ pop พร้อมค่าที่เลือกไว้เหมือนกัน ตามที่ระบุใน requirement เดิม)
- ค้นหา → กรองทันที (client-side)

**States:** loading initial (skeleton), error โหลดไม่สำเร็จ (ข้อความ + Text Button "ลองใหม่"), empty (ไม่มีเพื่อน mutual-follow), search-no-result, populated (checkbox แสดงสถานะจาก `initiallySelected` ที่รับมาจาก parent)

**Responsive Behavior:** เหมือนหน้าอื่นในกลุ่มนี้ — row สูงขั้นต่ำ 56px, title 2 บรรทัดสูงสุดไม่ดัน layout อื่นเพี้ยน, ปุ่ม "เสร็จสิ้น (N)" ความกว้างไม่คงที่ (ขยายตามตัวเลข) ต้องไม่ชนขอบจอที่ font ใหญ่/ตัวเลขหลักเดียวไปหลายหลัก

**Accessibility:** แต่ละแถว `Semantics(label: "[ชื่อ], ยูสเซอร์เนม [username], เลือกซ่อนแล้ว/ยังไม่ถูกซ่อน", button: true)` (คงพฤติกรรมเดิม — ถูกต้องแล้ว), ปุ่ม "เสร็จสิ้น" มี semantics label บอกจำนวนคนที่เลือก (คงพฤติกรรมเดิม), Checkbox ทั้งแถวแตะได้ครบ 44×44

**Design Rules:** ใช้ Checkbox (ไม่ใช่ Switch) เพราะเป็นการเลือกชั่วคราวต่อโพสต์เดียว ไม่ persist — คงหลัก semantic distinction เดิมจาก wyn-097 ระหว่างหน้านี้กับ Close Friends ไว้ตรงตามเดิม; สีเดียวที่ใช้เน้นคือ `color.accent` (checkbox checked + ปุ่ม "เสร็จสิ้น")

**Handoff:** AI Coding เปลี่ยน title เป็น `type.heading.2` ตามข้อยกเว้นที่ระบุ, แปลง `CheckboxListTile` ให้ตรงรูปแบบ checked/unchecked ที่กำหนด, เพิ่มปุ่ม clear ในช่องค้นหา — ไม่เปลี่ยน business logic/return-value contract เดิม (`Navigator.pop<Set<String>>`)

---

## Handoff รวม (ทั้ง 4 หน้าจอ)

- รอ Founder ยืนยัน `wyn-142`/`wyn-143` อย่างเป็นทางการก่อนส่งต่อ AI Coding แปลง token เป็นโค้ดจริง
- AI Coding ต้อง reuse `FollowActionButton`, `AvatarCircle`, `FollowRepository`, `FollowRequestRepository` เดิมทั้งหมด — งานนี้เป็น visual-only redesign ไม่แตะ business logic/API contract
- ทุกจุดที่เปลี่ยนสีจาก `WynColors.sapphire`/`colorScheme.primary` เดิม ให้เปลี่ยนเป็น `color.accent` (Flare Coral) ของ theme ใหม่ทั้งหมดให้สอดคล้องกัน ไม่ผสมสีเก่ากับใหม่ในหน้าเดียวกัน
