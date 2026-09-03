# Design Spec — WYN-106: Native In-Feed Ads (Home Feed, AdMob Native Advanced)

Owner: AI Design → AI Coding
สถานะ numbering: **ไม่พบ WYN-106 ที่ไหนในระบบมาก่อน** (ตรวจด้วย `grep -r "WYN-106"` ทั้ง repo แล้ว — ไม่เจอ) และ WYN สูงสุดที่มีอยู่ตอนนี้คือ WYN-105 (`.wyn/tasks/approved/WYN-105-white-background.md`) จึงใช้ **WYN-106** — **flag ความไม่แน่นอน**: งานนี้ข้าม AI Product Manager มาที่ Design ตรงๆ ตามคำสั่ง Founder (ระบุไว้ชัดในบรีฟที่ได้รับ) จึงยังไม่มี `.wyn/tasks/backlog/WYN-106-*.md` คู่กัน — แนะนำให้สร้าง task file ย้อนหลังเพื่อ tracking ตาม `WORKFLOW.md` (Task Lifecycle) แต่ไม่ใช่สิ่งที่ AI Design ควรตัดสินใจเอง

Ref: Founder อนุมัติ "native, Facebook-style in-feed ads บน Home feed ผ่าน Google AdMob Native Advanced Ads" (2026-09-03) — **กลับคำสั่งเดิม** (`.wyn/company/DECISIONS.md`, 2026-08-14: "ห้ามทำ ... Ads ... จนกว่าจะได้รับคำสั่งใหม่") คำสั่งใหม่นี้คือคำสั่งใหม่นั้น ไม่เกี่ยวกับ AdSense บน `wynos.online` (เว็บ static page คนละงาน คนละ SDK)

โค้ดที่ตรวจแล้วก่อนออกแบบ:
- `app/lib/features/home/presentation/home_feed_screen.dart` (`_buildBodySlivers()`, `_fetchPage()`, `_loadInitial()`/`_loadMore()`, `_hideItem()`/`_undoHideItem()`)
- `app/lib/features/home/data/home_feed_item.dart`
- `app/lib/features/home/data/feed_diversity.dart` (`applyFeedDiversity`, `FeedDiversityCandidate`)
- `app/lib/features/home/data/home_repository.dart` (`pageSize = 10`)
- `app/lib/features/home/presentation/widgets/home_feed_skeleton.dart`
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` (การ์ดต้นแบบที่ต้อง "เนียน" ไปด้วย)
- `app/lib/core/widgets/post_media.dart` (`PostImageFrame`, aspect-ratio clamp/0.75-viewport height cap, WYN-093)
- `app/lib/features/follow/presentation/widgets/follow_action_button.dart` (ตัวอย่างปุ่ม `FilledButton`/`OutlinedButton` ที่มีอยู่แล้วในระบบ)
- `app/lib/core/design/wyn_colors.dart` / `wyn_spacing.dart` / `wyn_typography.dart`
- `.wyn/docs/design/ds-003-home-feed.md` (hairline divider, card-less continuous feed)
- `.wyn/docs/design/wyn-007-home.md`, `wyn-073-...`, `wyn-090-...`, `wyn-096-...` (โครงสร้าง/สไตล์การ์ดปัจจุบัน)
- `design-reference/01-home.tsx` (ทิศทาง visual ปัจจุบันของ Home)

## Audit ก่อนออกแบบ

Home feed **ไม่มี concept ของ "row ที่ไม่ใช่โพสต์จริง" อยู่เลยในปัจจุบัน** นอกจาก hairline `Divider` ที่แทรกด้วย index-parity trick ใน `_buildBodySlivers()` (`i.isOdd` → divider, `i~/2` → item index) — `_items` (`List<HomeFeedItem>`) เป็นแหล่งความจริงเดียวที่ทุก mutation (`_toggleLike(index)`, `_toggleSave(index)`, `_hideItem(index)`, `_deleteRedrop(index)`, ฯลฯ) index เข้าไปตรงๆ และ `feed_diversity.dart`'s `applyFeedDiversity()` เป็น pure function ที่ทำงานกับ `FeedDiversityCandidate` (ไม่รู้จัก widget/UI เลย) ก่อนที่ผลลัพธ์จะกลายเป็น `HomeFeedItem` ใน `_items`

**ข้อสรุปสำคัญที่กำหนดทิศทางการออกแบบทั้งหมด**: โฆษณาต้อง**ไม่มีวันเข้าไปอยู่ใน `_items`/`HomeFeedItem`/`FeedDiversityCandidate` เลย** — ถ้าทำแบบนั้น ทุก method ข้างบนที่ index เข้า `_items[index]` ตรงๆ จะต้องรู้จักและข้าม ad-row ทั้งหมด (เสี่ยง bug คลาสเดียวกับที่ WYN-034 เคยเจอตอนเพิ่ม ReDrop ให้ id ซ้ำได้) — นี่คือสิ่งที่ requirement 4 ("ต้องไม่ทำลาย ranking/diversity logic ... treat เป็น interleaving pass แยกต่างหาก") สั่งไว้ตรงๆ วิธีที่ปลอดภัยคือให้โฆษณาเป็น **presentation-layer insertion ที่คำนวณสดตอน build** เหมือนที่ `Divider` ทำอยู่แล้ววันนี้ ไม่ใช่ data ที่ persist ไว้ใน state

---

Screen: **Home Feed — โฆษณาแทรกในฟีด (Native In-Feed Ad Card)**

Purpose: แทรกโฆษณา AdMob Native Advanced Ads ระหว่างโพสต์จริงใน Home feed แท็บ "สำหรับคุณ" ให้หน้าตากลมกลืนกับการ์ด Drop/Pop ที่มีอยู่แล้ว (ตระกูลเดียวกันตามที่ `wyn-007-home.md` วางไว้) โดยยังคงมีป้าย "โฆษณา" ที่มองเห็นชัดเจนตามนโยบาย AdMob เสมอ — ไม่กระทบ ranking/diversity logic เดิมแม้แต่นิดเดียว

User Flow: เปิด Home (แท็บ "สำหรับคุณ") → เลื่อนดูฟีดปกติ (Drop/Pop ปนกันตามเดิม) → หลังผ่านโพสต์จริงมาครบตามช่วงที่กำหนด เห็นการ์ดโฆษณาคั่นแทรกมา 1 ใบ (มีป้าย "โฆษณา" ชัดเจน + ปุ่ม CTA) → แตะที่ใดก็ได้บนการ์ด (หรือปุ่ม CTA) → ออกจากแอปไปยังปลายทางของผู้ลงโฆษณา (เบราว์เซอร์/App Store ฯลฯ ผ่าน AdMob SDK เอง ไม่ใช่หน้าจอ WYNOS) → กลับมาที่แอปแล้วฟีดยังอยู่ตำแหน่งเดิม (เหมือนที่ทุกวันนี้ทำกับการเปิด Drop Detail แล้วกลับมา) → เลื่อนต่อไปอีก N โพสต์จริง → เจอโฆษณาใบถัดไป

---

## 1) Placement / Frequency Rule (requirement 3)

**กติกา**: นับเฉพาะ "โพสต์จริง" ที่ render สำเร็จ (Drop หรือ Pop ทุกแบบ รวม ReDrop/Quote ReDrop/Poll — นับเป็น 1 เท่ากันหมด ไม่แยกประเภท) เป็นตัวนับ ทุกๆ **N โพสต์จริงติดต่อกัน** แทรกการ์ดโฆษณา 1 ใบคั่นตามหลังโพสต์ที่ N พอดี ตัวนับเป็น**ตัวนับสะสมของทั้ง session การเลื่อนฟีด** (ไม่รีเซ็ตทุกครั้งที่ `_loadMore()` โหลดหน้าใหม่ — รีเซ็ตเฉพาะตอน `_loadInitial()` ทำงานใหม่จริงๆ เช่น pull-to-refresh/สลับแท็บ/เปิดแอปใหม่) เพื่อไม่ให้เกิดจังหวะแปลกๆ ที่ขอบหน้า pagination (`pageSize = 10`)

**ข้อบังคับที่ห้ามฝ่าฝืน**:
- ห้ามมีโฆษณา 2 ใบติดกัน (ไม่มีทางเป็นไปได้อยู่แล้วถ้านับจากโพสต์จริงเท่านั้น ไม่นับโฆษณาเป็นตัวนับของตัวเอง)
- ห้ามโฆษณาเป็น row แรกสุดของฟีด (ธรรมชาติของการนับ N≥5 ก็ทำให้เป็นแบบนี้อยู่แล้วโดยไม่ต้องมีกติกาพิเศษเพิ่ม)
- โฆษณาไม่ปรากฏเลยถ้าฟีดยังมีโพสต์จริงไม่ถึง N โพสต์ (หน้าแรกสุด/บัญชีใหม่ที่มีคนโพสต์น้อย) — ไม่ต้อง "ยัด" ให้ครบ

**ค่า N = 8** (✅ ยืนยันโดย Founder 2026-09-03 — ดู Open Questions) เหตุผล:
- Facebook มือถือ: ราว 1 โฆษณาใน organic post ทุก ~5 โพสต์ (อ้างอิงพฤติกรรมที่รู้จักกันทั่วไปของแพลตฟอร์ม ไม่ใช่ตัวเลขทางการจาก Meta)
- Instagram: เบาบางกว่า Facebook ในฟีดหลัก มักอยู่ราว 1:8-1:12
- WYNOS เป็นแอปใหม่ที่กำลังสร้างความน่าเชื่อถือกับผู้ใช้กลุ่ม Gen Z (ตาม GTM roadmap ที่ยังอยู่ระยะ Closed Beta — ดู `.wyn/docs/product/wynos-gtm-roadmap.md`) — เริ่มแบบ "อนุรักษ์นิยม" กว่า Facebook (เบาบางกว่า) ปลอดภัยกว่าในการปกป้องความประทับใจแรก แล้วค่อยปรับความถี่ขึ้นทีหลังจากข้อมูลจริง ดีกว่าเริ่มถี่แล้วต้องลดลงหลังโดนฟีดแบ็กลบ
- N=8 กับ `pageSize=10` ทำให้โดยเฉลี่ยมีโฆษณา ~1 ใบต่อ 1.25 หน้าที่โหลด — ไม่ใช่ทุกหน้าที่โหลดมีโฆษณาแน่นอน แต่ก็ไม่ห่างจนไม่มีนัยสำคัญเชิงธุรกิจ

**สโคป V1 — เฉพาะแท็บ "สำหรับคุณ" (`_HomeFeedMode.forYou`) เท่านั้น**:
- "ติดตาม" (`following`): **ไม่ใส่โฆษณาในรอบนี้** — เป็นฟีดที่ผู้ใช้เลือกเองว่าจะดูใคร ความคาดหวังต่างจาก "สำหรับคุณ" ที่เป็นฟีด "แนะนำ" อยู่แล้วโดยธรรมชาติ (มี Discovery items แทรกอยู่แล้วตาม `feed_diversity.dart`) — แทรกโฆษณาที่นี่เสี่ยงรู้สึกล่วงล้ำกว่า เก็บไว้เป็นคำถามเปิดสำหรับเฟสถัดไป
- "จาก Club ของคุณ" (`fromYourClubs`): **นอกสโคปเชิงโครงสร้าง** — เป็น widget แยกต่างหากทั้งหมด (`FromYourClubsFeed`, ไม่ใช้ `_items`/pagination เดียวกันเลย) การใส่โฆษณาที่นี่ต้องเป็นงานออกแบบ+develop แยกต่างหากถ้า Founder ต้องการในอนาคต ไม่ใช่ส่วนหนึ่งของงานนี้
- Guest (ยังไม่ login, WYN-072 Guest Browsing): เห็นฟีด "สำหรับคุณ" ได้อยู่แล้ววันนี้ → **เห็นโฆษณาด้วยเช่นกัน** ไม่มีเหตุผลให้ยกเว้น (AdMob ไม่ต้องพึ่ง login) — ถือเป็นค่าเริ่มต้นที่ไม่ก่อให้เกิดความเสี่ยงใดๆ ไม่ใช่คำถามเปิด

## 2) ปฏิสัมพันธ์กับ Ranking/Diversity Logic เดิม (requirement 4)

`applyFeedDiversity()` และ `FeedDiversityCandidate` **ไม่ถูกแตะเลยแม้แต่บรรทัดเดียว** — โฆษณาไม่เคยเข้าสู่ pipeline การจัดอันดับ (`get_wynos_ranked_feed()` → `FeedDiversityCandidate` → `applyFeedDiversity()` → `HomeFeedItem` → `_items`) เลยสักขั้นตอน ไม่มี `wynosScore`, ไม่นับรวมใน `maxConsecutiveSameAuthor`/`discoveryEveryNSlots`

การแทรกโฆษณาเป็น **pass ที่ 3 แยกต่างหาก อยู่ที่ชั้น presentation (render-time) เท่านั้น**, ต่อยอดจากรูปแบบที่ `_buildBodySlivers()`'s `SliverChildBuilderDelegate` ทำอยู่แล้ววันนี้กับ `Divider` (คำนวณ "row ประเภทไหนอยู่ที่ index นี้" สดจาก index แทนที่จะ persist ไว้ใน state):

- แนะนำให้ Coding เพิ่ม pure function แยกไฟล์ใหม่ (เช่น `app/lib/features/home/data/feed_ad_slots.dart`) mirror รูปแบบเดียวกับ `feed_diversity.dart` เป๊ะ — pure, deterministic, unit-testable, **ไม่แตะ database**: รับ "จำนวนโพสต์จริงที่ผ่านมาแล้วสะสม" คืนค่าว่า index ถัดไปที่ควรเป็น ad-slot คือ index ไหน — เหตุผลที่แยกไฟล์เหมือน `feed_diversity.dart` (ไม่ยัดลงใน `home_feed_screen.dart` ตรงๆ): เป็น business rule ที่มี logic พอจะ unit test ได้ (เหมือนที่ `feed_diversity.dart`'s doc comment อธิบายเหตุผลของตัวเองไว้)
- ตำแหน่งของแต่ละโฆษณาต้องเป็น **ฟังก์ชันล้วนของ "โพสต์จริงที่ผ่านมาแล้วกี่โพสต์" ไม่ใช่ผูกกับ id ของโพสต์เฉพาะ** — ผลคือถ้าผู้ใช้ hide โพสต์ใดโพสต์หนึ่ง (`_hideItem`) แล้ว index ของทุกอย่างด้านล่างขยับ ตำแหน่งโฆษณาจะขยับตามธรรมชาติไปด้วย (อาจคลาดเคลื่อนไป 1 slot) — **ถือว่าไม่ใช่บั๊ก** เพราะโฆษณาไม่มีความหมายเชิง "อยู่หลังโพสต์นี้เจาะจง" อยู่แล้ว ต่างจาก hide/undo ที่ต้อง preserve ตำแหน่งของ*โพสต์จริง*เป๊ะ (ซึ่งยังคงถูกต้อง 100% เพราะ `_items` เองไม่เคยมีโฆษณาปนอยู่)
- `_toggleLike(index)`/`_toggleSave(index)`/`_hideItem(index)`/ทุก method ที่ index เข้า `_items[index]` **ไม่ต้องแก้แม้แต่บรรทัดเดียว** เพราะ index เหล่านั้นยังคง index เข้า `_items` (ข้อมูลจริง) เหมือนเดิมทุกประการ — ตัว "แปลง index ของ `_items` เป็น index ของ list ที่ render จริง (ที่มีทั้ง divider และ ad-slot ปนอยู่)" เป็นงานของ itemBuilder เท่านั้น เหมือนที่ divider ทำอยู่แล้ววันนี้ด้วย `i.isOdd`/`i~/2`

## 3) Loading / Error / Empty States (requirement 5)

**กติกาแม่บทเดียว: โฆษณาที่ไม่พร้อม = ไม่มีอยู่ ไม่ใช่กล่องว่าง ไม่ใช่ spinner ไม่ใช่ placeholder ที่ดูพัง**

- **ห้ามมี ad-shaped skeleton ใหม่** — `HomeFeedSkeleton` (loading state ตอนเปิดฟีดครั้งแรก) **ไม่ต้องแก้เลย** เพราะ skeleton นั้นมีไว้สำหรับ "ยังไม่รู้ว่าโพสต์จริงมีอะไรบ้าง" ส่วนโฆษณาไม่มี concept แบบนั้น (ถ้าไม่มี fill ก็คือไม่มีโฆษณาเลย ไม่ใช่ "โฆษณากำลังโหลด")
- **Prefetch ล่วงหน้า**: ให้ AdMob SDK เริ่มโหลดโฆษณาสำหรับ ad-slot ถัดไป **ตั้งแต่โพสต์จริงก่อนหน้ามันโหลดเสร็จ** (ให้เวลา SDK นำหน้าก่อนผู้ใช้เลื่อนมาถึงจริง) — ใช้จังหวะเดียวกับที่ `_onScroll()` เรียก `_loadMore()` ล่วงหน้า 300px ก่อนถึงล่างสุดอยู่แล้ววันนี้ เป็น pattern เดียวกัน ("เตรียมของล่วงหน้าก่อนถึงจะต้องใช้จริง")
- **ถ้าผู้ใช้เลื่อนมาถึงตำแหน่ง ad-slot ก่อนที่โฆษณาจะโหลดเสร็จ**: slot นั้น **ไม่ render อะไรเลย** (ความสูง 0, ไม่ใช่ placeholder เตี้ยๆ) — ห้าม retroactive แทรกโฆษณาเข้าไปทีหลังในตำแหน่งที่ผู้ใช้เลื่อนผ่านไปแล้วหรือกำลังมองอยู่ (จะทำให้เนื้อหาที่กำลังมองอยู่ขยับกะทันหัน ประสบการณ์แย่กว่าการไม่มีโฆษณาเลย) — ถือว่า slot นั้น "พลาด" ไปเลยสำหรับรอบการเลื่อนนี้ ไม่มี retry ทันที รอ interval ถัดไป (อีก N โพสต์) แทน
- **ถ้าโหลดพัง/ไม่มี fill (no-fill)**: เหมือนกรณีด้านบนทุกประการ — เงียบ ไม่มี error UI ไม่มีปุ่ม retry (ต่างจาก organic's "โหลดเพิ่มไม่สำเร็จ แตะเพื่อลองใหม่" ที่มี retry เพราะเนื้อหาโพสต์เป็นสิ่งที่ผู้ใช้ตั้งใจมาดู แต่โฆษณาที่หายไป 1 ใบไม่ใช่สิ่งที่ผู้ใช้ต้องรับรู้หรือต้องกดอะไรเลย)
- ผลลัพธ์สุทธิ: **ถ้า AdMob ไม่มี inventory เลย (เช่น ตอน dev/QA ที่ยังไม่ผูก AdMob App ID จริง) ฟีดทั้งหน้าต้องมองแล้วรู้สึกเหมือนไม่มีโฆษณาอยู่เลย 100%** — ไม่มี dead space ไม่มีอะไรดูค้าง
- **Empty/Error ของฟีดทั้งหน้า** (`_items.isEmpty`, `_error != null`, ทั้ง 2 error state ที่มีอยู่แล้วใน `_buildBodySlivers()`) — **ไม่มีโฆษณาเลย** ไม่มีอะไรให้แทรก เพราะไม่มีโพสต์จริงให้นับ

## 4) ป้าย "Sponsored"/"โฆษณา" (requirement 2)

**นี่คือข้อกำหนดของนโยบาย Google AdMob ไม่ใช่ทางเลือกด้านสไตล์ — ห้ามลดขนาดจนอ่านไม่ออก ห้ามซ่อน ห้ามใช้สีที่กลืนกับพื้นหลังจนแยกไม่ออก**

ตำแหน่ง: อยู่ใน**ตำแหน่งเดียวกับที่เวลาโพสต์จริง (relative timestamp) อยู่บนการ์ดปกติ** ใต้ชื่อผู้ลงโฆษณาในแถวหัวการ์ด (โฆษณาไม่มี "เวลาที่โพสต์" ให้แสดงอยู่แล้ว จึงไม่มีอะไรถูกแทนที่ ไม่เสียพื้นที่เพิ่ม)

รูปแบบ: ข้อความ **"โฆษณา"** ในกล่อง pill เล็ก — พื้นหลัง `WynColors.surfaceTint`, ตัวอักษร `WynColors.graphite`, ขนาดใกล้เคียง `WynTypography.textTheme.labelSmall` (13px) แต่ไม่เล็กกว่านี้, padding แนวนอน/ตั้ง เท่ากับ pill อื่นๆ ที่มีอยู่แล้วในระบบ (`WynSpacing.radiusSm` มุมโค้ง) — ใช้ pill ไม่ใช่ plain text ธรรมดา เพื่อให้ "แยกออกจากตา" ชัดกว่าข้อความทั่วไปแม้จะสแกนเร็วๆ ตรงตาม "มองเห็นชัดเจน" ของ requirement 2 (plain graphite text ระดับเดียวกับ metadata อื่นเสี่ยงเนียนเกินไปจนถูกมองว่าเป็นการซ่อน)

**ห้าม**: เปลี่ยนคำ ("Sponsored"/"โฆษณา" เท่านั้น ไม่ใช้คำอ้อมอย่าง "แนะนำ"/"พาร์ทเนอร์"), ลดขนาดต่ำกว่า 11px, ใช้สีที่ contrast กับพื้นหลังต่ำกว่ามาตรฐาน WCAG ของ metadata text อื่นในระบบ, วางไว้ตำแหน่งที่ถูกคอนเทนต์อื่นบัง (เช่น ใต้รูปภาพที่อาจโดน crop)

**AdChoices icon**: SDK ของ Google (native `NativeAdView`/`GADNativeAdView` ที่ AI Coding จะ implement ในงาน implementation แยกต่างหาก) มักต้องการพื้นที่มุมขวาบนของ asset ใดๆ (โดยทั่วไปคือมุมขวาบนของทั้งการ์ดหรือของ media block) สำหรับ AdChoices overlay ที่ SDK render เอง — **จองพื้นที่มุมขวาบนของแถวหัวการ์ดไว้ให้ SDK** (ตำแหน่งเดียวกับที่ปุ่ม "..." (`more_vert`) อยู่บนการ์ดปกติวันนี้ — ขนาดพอๆ กับ touch target 44x44) **ห้ามวาง UI ของ WYNOS เอง (เช่นไอคอน "...") ทับตำแหน่งนี้** เพราะการ์ดโฆษณาไม่มีปุ่ม "..." อยู่แล้ว (ดูหัวข้อ Interactions) จึงไม่มีอะไรชนกัน

## 5) Interactions / Tap Behavior (requirement 6)

- **แตะที่ใดก็ได้บนการ์ด** (headline, media, ชื่อผู้ลงโฆษณา, ไอคอน, body text) **หรือปุ่ม CTA** → ออกจากแอปไปยังปลายทางของผู้ลงโฆษณา ผ่านกลไก `registerViewForInteraction` ของ AdMob SDK เอง (เป็นเรื่อง SDK integration ล้วนๆ ที่ AI Coding ต้องผูก ไม่ใช่ `Navigator.push` ของ WYNOS) — **ห้ามเขียน custom `onTap` ที่เปิดหน้าจอ WYNOS ใดๆ ให้การ์ดโฆษณา** (ต่างจาก `HomeDropCard`/`HomePopCard` ที่ `onTap` เปิด `DropDetailScreen`/คลิปเดี่ยวเสมอ) — ทั้งการ์ดเป็น 1 clickable surface เดียวที่ SDK เป็นเจ้าของ ไม่ใช่ WYNOS
- **ปุ่ม CTA** (`NativeAd.callToAction`, ข้อความควบคุมโดยผู้ลงโฆษณา เช่น "ติดตั้งเลย"/"ดูเพิ่มเติม"/"ซื้อเลย" — WYNOS ไม่ hardcode ข้อความเอง) เป็นหนึ่งใน asset view ที่ลงทะเบียนกับ SDK เหมือนกัน ปลายทางเดียวกับการแตะจุดอื่นของการ์ด — ต่างกันแค่ที่ analytics ฝั่ง AdMob เอง (SDK แยกแยะเองว่าเป็นการแตะ asset ไหน) ไม่ใช่สิ่งที่ WYNOS UI ต้องแยกความแตกต่างในเชิงพฤติกรรม
- **ไม่มี**: like/comment/repost/save/share/hide/report/"..." เมนู, double-tap-to-like, LikedByRow, TopReplyPreview — ทุกอย่างที่บ่งบอกว่ามี engagement จริงจากผู้ใช้คนอื่นถูกตัดออกทั้งหมด (การใส่ like count/comment count ปลอมๆ หรือเปิดให้กด like การ์ดโฆษณาเป็นการหลอกลวงผู้ใช้ตรงๆ — ต้องไม่มี)
- นี่คือกลไกหลักที่ทำให้การ์ดโฆษณา "เนียน" กับฟีดในเชิง visual แต่ยัง**ไม่หลอกลวง**ในเชิง interaction ตาม requirement 6: หน้าตาโครงสร้างเดียวกัน (avatar+ชื่อ+ป้าย, เนื้อหา, media, ปุ่มปฏิบัติการ) แต่ป้าย "โฆษณา" + ไม่มีแถบ like/comment/repost + ปุ่ม CTA เต็มความกว้างแทนไอคอนเรียงกัน 4 อัน ทำให้ผู้ใช้แยกออกได้จริงเมื่อมองแบบตั้งใจ โดยไม่ต้องทำให้พื้นหลัง/mặt โครงสร้างต่างจนดูเป็น banner แปลกแยก (ตรง requirement 1)

## Components — โครงสร้างการ์ดโฆษณา (mirror `HomeDropCard`)

อ้างอิงลำดับ/padding ของ `home_drop_card.dart` (บรรทัด 219-515) เป๊ะ เว้นจุดที่ระบุว่าต่าง:

1. **แถวหัวการ์ด** (padding เดียวกับ organic: `EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space1)`):
   - วงกลมไอคอนผู้ลงโฆษณา (`NativeAd.icon`) ขนาด/ตำแหน่งเดียวกับ `AvatarCircle(radius: 16)` — ถ้าไม่มี icon asset (บางเครือข่ายโฆษณาไม่ส่งมา) ใช้ fallback แบบเดียวกับ `AvatarCircle`'s `fallbackText` (ตัวอักษรแรกของชื่อผู้ลงโฆษณา) ไม่ปล่อยเป็นวงกลมว่างเปล่า/broken image
   - บรรทัด 1: ชื่อผู้ลงโฆษณา (`NativeAd.advertiser`) สไตล์เดียวกับ `titleSmall` (username) — **ไม่มี verified badge** (โฆษณาไม่ใช่บัญชี WYNOS)
   - บรรทัด 2: ป้าย "โฆษณา" (ดูหัวข้อ 4 ข้างบน) แทนที่ตำแหน่งเวลาโพสต์
   - ขวาสุด: พื้นที่ว่างสำหรับ AdChoices ของ SDK (ดูหัวข้อ 4) — **ไม่มีปุ่ม "..." ของ WYNOS**
2. **Headline** (`NativeAd.headline`, บังคับมีเสมอทุก native ad): ตำแหน่ง/padding เดียวกับ caption องค์กร (`Padding.fromLTRB(12,8,12,8)`, ตาม WYN-086 "แคปชันอยู่บนรูป") — สไตล์ `bodyLarge` (16px) **น้ำหนัก 600** (หนากว่า caption ปกติที่เป็น 400 — ให้ความรู้สึก "หัวข้อ" ของโฆษณา ไม่ใช่ข้อความเล่าเรื่องแบบโพสต์ทั่วไป)
3. **Body** (`NativeAd.body`, optional — บาง network ไม่ส่งมา): ถ้ามี แสดงบรรทัดถัดจาก headline สไตล์ `bodyMedium`/`graphite`, สูงสุด 2 บรรทัดตัดด้วย ellipsis ถ้าไม่มีก็ไม่ render อะไรเลย (เหมือน caption-only Drop ที่ไม่มีรูปวันนี้)
4. **Media** (`NativeAd.mediaContent`, ผ่าน `MediaView` ของ SDK — optional, บาง native ad format เป็น icon+text ล้วนไม่มี media): full-bleed เต็มความกว้าง ตำแหน่งเดียวกับ `PostImageFrame` (`radiusNone`) **แต่ต่างจาก organic ตรงที่ห้ามบังคับ aspect ratio หรือ crop เนื้อหา** — ให้แสดงตามอัตราส่วนจริงที่ `mediaContent.aspectRatio` รายงาน (รูป/วิดีโอโฆษณามีสัดส่วนหลากหลาย 1:1 ถึง 16:9 และบางครีเอทีฟฝัง disclosure text ไว้ในภาพเอง ครอปทิ้งเสี่ยงผิดนโยบาย) — ใช้ cap ความสูงสูงสุดเดียวกับ `PostImageFrame` (`maxHeightFraction = 0.75` ของความสูงจอ) เพื่อความรู้สึกสม่ำเสมอของจังหวะเลื่อนฟีด แต่ fit แบบ "contain ภายใน cap" ไม่ใช่ "cover ครอบตัด" — **นี่คือ deviation ที่ตั้งใจจาก organic photo (ที่ crop ได้ตาม `postImageAspectRatio` clamp)**, ระบุไว้ตรงๆ ใน Design Rules ด้านล่างกันสับสนว่าลืมทำตาม pattern เดิม
5. **แถว rating/store/price** (optional, มักมีเฉพาะโฆษณาประเภทติดตั้งแอป): บรรทัดเดียว เล็ก (`labelSmall`/graphite) ใต้ media เหนือปุ่ม CTA — ไม่มีก็ไม่ render
6. **ปุ่ม CTA** (`NativeAd.callToAction`, บังคับมีเสมอ): แทนที่แถว like/comment/repost/eye ทั้งแถว — `FilledButton` เต็มความกว้าง (ใช้สไตล์ default ของแอปที่มีอยู่แล้ว, `colorScheme.primary` = sapphire พื้น, ตัวอักษรขาว — ธีมเดียวกับปุ่มหลักที่ใช้ทั่วแอปอยู่แล้ว เช่นปุ่มโพสต์ใน `CreateDropScreen`) padding แนวนอนเท่ากับแถว action bar เดิม (`WynSpacing.space3` ตาม WYN-096) — ข้อความบนปุ่มคือข้อความที่ผู้ลงโฆษณากำหนด แสดงตรงๆ ไม่ตัดทอน/แปล

**ไม่มี**: LikedByRow, TopReplyPreview, ปุ่ม "..."/more menu, ป้าย ReDrop/Quote

## States

- **Loading (ad slot ยังไม่ resolve)**: ไม่ render อะไรเลย (สูง 0) — ดูหัวข้อ 3 ข้างบน
- **Loaded**: การ์ดเต็มรูปแบบตามหัวข้อ Components
- **No-fill / Error**: เหมือน Loading — ไม่ render อะไรเลย ไม่มี error UI ใดๆ
- **หลังโฆษณาที่เคย render สำเร็จแล้วในตำแหน่งหนึ่ง ผู้ใช้ pull-to-refresh**: ฟีดโหลดใหม่ทั้งหมด (`_loadInitial()`) ตัวนับ interval รีเซ็ตเป็น 0 ใหม่ — โฆษณาที่เคยเห็นอาจไม่ปรากฏที่ตำแหน่งเดิมอีก (ธรรมชาติเดียวกับที่โพสต์จริงเองก็สลับตำแหน่งได้ทุกครั้งที่ ranking คำนวณใหม่) — **ไม่แคชโฆษณาข้ามการโหลดใหม่**
- **ฟีดว่าง/error ทั้งหน้า** (`_items.isEmpty`, `_error != null`): ไม่มีโฆษณา (ดูหัวข้อ 3)

## Responsive Behavior

คอลัมน์เดียวเต็มความกว้างจอเสมอ เหมือนทุกการ์ดใน Home feed — ความสูง media ปรับตาม aspect ratio จริงของครีเอทีฟ + cap 0.75 ของความสูงจอ (เหมือน `PostImageFrame`) ปุ่ม CTA เต็มความกว้างเสมอไม่ว่าจอขนาดใด (ไม่ wrap ข้อความเป็นหลายบรรทัดถ้าเลี่ยงได้ — ถ้าข้อความ CTA จากผู้ลงโฆษณายาวผิดปกติ ให้ ellipsis ไม่ยอมให้ปุ่มสูงขึ้นเกิน 1 บรรทัด)

## Accessibility

- Semantics label ของทั้งการ์ดต้อง**ขึ้นต้นด้วยการประกาศว่าเป็นโฆษณาก่อนเนื้อหา** เช่น `"โฆษณา จาก {ชื่อผู้ลงโฆษณา}: {headline}"` — ผู้ใช้ screen reader ต้องรู้ว่าเป็นโฆษณา*ก่อน*ที่จะเริ่มฟังเนื้อหา เหมือนหลักการเดียวกับที่การ์ดจริงขึ้นต้นด้วยประเภทเนื้อหา (`"รูปของ {username}"`)
- ปุ่ม CTA ต้องมี Semantics/button label แยกเป็นของตัวเอง (ข้อความ CTA จริง) ไม่ถูกกลืนไปกับ label รวมของทั้งการ์ด — เพื่อให้ยังกด "ปุ่ม" นั้นได้ตรงๆ ผ่าน screen reader
- ปุ่ม CTA สูงไม่ต่ำกว่า `WynSpacing.touchTargetMin` (44px) — ค่า default ของ `FilledButton` ในระบบนี้ทำได้อยู่แล้วโดยไม่ต้องปรับเพิ่ม
- พื้นที่ AdChoices (SDK-rendered) ต้อง**ไม่ถูก `ExcludeSemantics` ครอบ** (ต่างจาก `HomeFeedSkeleton` ที่ตั้งใจ `ExcludeSemantics` ทั้งก้อนเพราะเป็นแค่ placeholder) — เป็น control จริงที่ผู้ใช้ต้อง reach ได้ด้วย screen reader ตามข้อบังคับของ Google

## Design Rules

- **ห้าม**เอาโฆษณาเข้า `_items`/`HomeFeedItem`/`FeedDiversityCandidate` เด็ดขาด — ต้องเป็น presentation-layer insertion ที่คำนวณสดตอน build เท่านั้น (หัวข้อ 2)
- **ห้าม**แก้ `feed_diversity.dart`/`applyFeedDiversity()`/`FeedDiversityCandidate` เพื่อรองรับโฆษณา
- **ห้าม**สร้าง ad-shaped skeleton หรือแก้ `HomeFeedSkeleton`
- **ห้าม**ให้การ์ดโฆษณามี custom `onTap` ที่เปิดหน้าจอ WYNOS เอง — ปล่อยให้ AdMob SDK's `registerViewForInteraction` เป็นเจ้าของ tap ทั้งหมด
- **ห้าม**ลดขนาด/ซ่อน/เปลี่ยนคำป้าย "โฆษณา" ไม่ว่ากรณีใด (นโยบาย Google, ไม่ใช่ทางเลือก)
- **ห้าม**ใส่ like/comment/repost/share/save/LikedByRow/TopReplyPreview บนการ์ดโฆษณา
- **ห้าม**บังคับ aspect ratio/ครอปสื่อของโฆษณาให้ตรงกับ clamp ของ organic photo (4:5..1.91:1) — media โฆษณาต้อง fit ตามสัดส่วนจริงของมันภายใน cap ความสูงเดียวกันเท่านั้น (deviation ที่ตั้งใจ ดูหัวข้อ Components #4)
- โฆษณาแทรกเฉพาะแท็บ "สำหรับคุณ" ใน V1 — ห้ามเปิดใช้ในแท็บ "ติดตาม"/"จาก Club ของคุณ" โดยไม่ได้รับคำสั่งเพิ่มจาก Founder ก่อน
- ต้องผ่าน `Divider(height: 1)` คั่นก่อน/หลังการ์ดโฆษณาเหมือนโพสต์จริงทุกใบ (ตาม DS-003) — ไม่มี divider พิเศษ ไม่มีพื้นหลังสีต่างจากพื้นฟีด (ตรง requirement 1 "ต้องเนียนไปกับการ์ด Drop/Post")

---

## Open Questions — ตัดสินใจแล้วโดย Founder (2026-09-03)

1. **ค่า N = 8** — ✅ ยืนยันตามคำแนะนำ
2. **ขยายไปแท็บ "ติดตาม"** — ✅ **ไม่ทำในรอบนี้** เฉพาะแท็บ "สำหรับคุณ" ก่อนตามคำแนะนำ
3. **N เป็นค่าคงที่ในแอปหรือ server config** — ✅ **Hardcode ในแอป** (เร็วกว่าในการ ship V1, ไม่ต้องเพิ่ม schema/RPC ใหม่) — ถ้าต้องปรับความถี่ในอนาคตต้อง release แอปใหม่ ยอมรับ trade-off นี้แล้ว
4. **ปุ่ม custom "ไม่สนใจ/รายงานโฆษณา" เพิ่มจาก AdChoices** — ไม่มีข้อคัดค้าน ใช้ค่า default ตามคำแนะนำ: **ไม่ต้องใน V1**
5. **การนับ "มีโพสต์ใหม่" กับโฆษณา** — ไม่มีข้อคัดค้าน ยืนยัน: **ไม่นับรวม** ตามข้อจำกัดเชิงโครงสร้างที่ระบุไว้

---

## สรุปตรงตาม Hard Requirements (checklist สำหรับ Founder/QA)

1. Native Advanced Ads ผ่าน custom `NativeAdView` เนียนกับการ์ด Drop/Post — ✅ หัวข้อ Components (mirror `HomeDropCard` เป๊ะ ยกเว้นจุดที่ระบุเหตุผลไว้)
2. ป้าย "โฆษณา" บังคับ มองเห็นชัดเจนทุกใบ แก้ไม่ได้ — ✅ หัวข้อ 4
3. Frequency capping ชัดเจน (N=8, ยืนยันโดย Founder) ไม่คลัสเตอร์ — ✅ หัวข้อ 1
4. ไม่กระทบ `feed_diversity.dart` — เป็น interleaving pass แยก — ✅ หัวข้อ 2 (Audit + Design Rules)
5. Loading/error = collapse เงียบๆ ไม่มี placeholder พัง — ✅ หัวข้อ 3
6. Tap behavior + แยกแยะจากโพสต์จริงชัดเจนไม่หลอกลวง — ✅ หัวข้อ 5

## Handoff

**Open Questions ข้อ 1-5 ตัดสินใจครบแล้วโดย Founder (2026-09-03) — ส่งต่อ AI Coding ได้:**

1. งาน AdMob SDK integration (App ID, `MobileAds.instance.initialize()`, `NativeAd` load/dispose lifecycle, platform-specific `NativeAdView`/`GADNativeAdView` factory) เป็นงาน implementation แยกทั้งหมด ไม่อยู่ในสโคปเอกสารนี้
2. เพิ่มไฟล์ใหม่ (แนะนำ `app/lib/features/home/data/feed_ad_slots.dart`) pure function กำหนดตำแหน่ง ad-slot จากตัวนับโพสต์จริงสะสม — ใช้ **ค่าคงที่ `kFeedAdInterval = 8` hardcode ในแอป** (ไม่ใช่ server config ตามที่ Founder ยืนยัน) — unit test ได้แบบเดียวกับ `feed_diversity_test.dart` ที่มีอยู่แล้ว (ไม่ต้อง mock AdMob SDK เลยสำหรับ logic ส่วนนี้)
3. แก้ `_buildBodySlivers()`'s `SliverChildBuilderDelegate` เพิ่ม row-kind ที่ 3 (organic/divider/ad) ต่อยอดจาก index-parity math ที่มีอยู่แล้ว — ไม่แตะ `_items`/`_toggleLike`/`_toggleSave`/`_hideItem`/ทุก method ที่ index เข้า `_items[index]` เลย
4. `HomeFeedSkeleton` ไม่ต้องแก้
5. Widget ใหม่ (เช่น `HomeNativeAdCard`) ตามหัวข้อ Components ข้างบน — reuse `WynColors`/`WynSpacing`/`WynTypography` เดิมทั้งหมด ไม่สร้าง token ใหม่
6. ต้องมี toggle/flag ปิดโฆษณาทั้งหมดได้ง่ายๆ (เช่น remote config หรือ build flag) สำหรับ QA/dev environment ที่ยังไม่มี AdMob App ID จริง — ป้องกันไม่ให้ CI/dev build พังเพราะพยายามยิง request หา AdMob จริง
7. `flutter analyze`/`flutter test` เต็ม suite ต้องผ่าน ไม่มี regression กับ `home_feed_screen_test.dart`/`feed_diversity_test.dart` เดิม — ต้องมี test ใหม่ยืนยันว่า `applyFeedDiversity()`'s output ไม่เปลี่ยนแปลงเลยเมื่อมีโฆษณามาเกี่ยวข้อง (ตัดสินโฆษณาออกจาก assertion ของ diversity test เดิมได้ทั้งหมด)
8. QA ต้องตรวจเพิ่มเติมเฉพาะงานนี้: ป้าย "โฆษณา" อ่านออกจริงที่ขนาดจอเล็กสุดที่รองรับ (360px), ไม่มี ad-slot ค้างเป็นช่องว่างเมื่อไม่มี fill, tap บนการ์ดโฆษณาไม่เปิดหน้าจอ WYNOS ใดๆ, `feed_diversity_test.dart` เดิมเขียวสนิท
