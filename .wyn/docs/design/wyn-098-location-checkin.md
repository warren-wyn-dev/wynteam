# Design Spec — WYN-098: ระบบเช็คอินสถานที่ (LocationIQ)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-098.md`, `.wyn/docs/product/wyn-098-location-checkin.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/drop/presentation/create_drop_screen.dart` (toolbar's `_ToolbarIcon` ปุ่มปักหมุด บรรทัด ~1002-1008, ปัจจุบัน `onTap: _showComingSoon`), `app/lib/features/home/presentation/widgets/home_drop_card.dart` (author row: avatar+ชื่อ+เวลา บรรทัด ~278-339), `app/lib/features/drop/presentation/drop_detail_screen.dart` (author row เทียบเท่า บรรทัด ~672-707), `app/lib/features/settings/presentation/settings_screen.dart` (`_showPermissionPicker` เป็นฐาน bottom sheet)
Design system: `WynColors`/`WynSpacing` เดิมทั้งหมด — **สี = Sapphire `#1B3A6B`/paper/ink/graphite/hairline/mutedNeutral ตาม `app/lib/core/design/wyn_colors.dart` ปัจจุบัน (Sapphire era)** ตรวจตรงจากไฟล์นี้แล้ว ไม่มี token สีใหม่

> **Provider เลือกแล้ว**: LocationIQ (Founder ยืนยัน 2026-09-02, `.wyn/company/DECISIONS.md`) — เอกสารนี้ออกแบบเฉพาะ UI/UX เท่านั้น ไม่ยุ่งกับ Edge Function/API key (นอกสโคปของ AI Design) — ดู data model/rate-limit เต็มที่ Product spec

---

## Screen 1 — ปุ่มปักหมุดตอนสร้างโพสต์ (เปิดจากปุ่มที่มีอยู่แล้ว)

**Purpose:** เปลี่ยนปุ่มปักหมุด (`Icons.location_on_outlined`, key `toolbar_location_button`) จาก `onTap: _showComingSoon` (placeholder) ให้เปิด Screen 2 จริง

**User Flow:** ผู้ใช้แตะปุ่มปักหมุดใน toolbar ของ `CreateDropScreen` → เปิด Screen 2 (bottom sheet เต็มความสูง/modal) → เลือกสถานที่ → กลับมาที่ `CreateDropScreen` เห็น chip สถานที่ (Screen 3) เหนือ/ใกล้ช่องแคปชัน

**Components:** ไม่มี component ใหม่ที่ปุ่มนี้เอง — เปลี่ยนแค่ `onTap` callback (`_ToolbarIcon` widget เดิมทุกประการ ไอคอน/ขนาด/ตำแหน่งเดิม)

**Interactions:** แตะ → เปิด Screen 2

**States:** ปุ่มนี้ enabled เสมอ (ไม่มีเงื่อนไข disable ใหม่ — เหมือนโค้ดเดิม `enabled: true`)

**Design Rules:** ไม่เปลี่ยน icon/ตำแหน่ง/สไตล์ของปุ่มเดิมเลย

**Handoff:** AI Coding — เปลี่ยน `onTap: _showComingSoon` → `onTap: _showLocationPicker`

---

## Screen 2 — ค้นหา/เลือกสถานที่ (Bottom Sheet)

**Purpose:** ให้ผู้ใช้ค้นหาสถานที่แบบพิมพ์ (autocomplete ผ่าน LocationIQ) หรือใช้ตำแหน่งปัจจุบัน แล้วเลือกสถานที่หนึ่งรายการ

**User Flow:** เปิดจาก Screen 1 → เห็น sheet: header + ช่องค้นหา + ปุ่ม "ใช้ตำแหน่งปัจจุบันของฉัน" (อยู่บนสุดของผลลัพธ์เสมอ) + list ผลลัพธ์ (ว่างจนกว่าจะพิมพ์หรือกดปุ่มตำแหน่งปัจจุบัน) → แตะสถานที่ที่ต้องการ → sheet ปิด → กลับ `CreateDropScreen` พร้อมสถานที่ที่เลือก

**Components:**
```
[drag handle]
เพิ่มสถานที่                              [X]

┌─────────────────────────────────┐
│ 🔍  ค้นหาสถานที่...                │   ← ช่องค้นหา (TextField, มิเรอร์
└─────────────────────────────────┘        FollowListScreen's _buildSearchBar
                                            เป๊ะ: height 40, พื้น #F1EFE9,
                                            radiusFull, hairline border)

📍  ใช้ตำแหน่งปัจจุบันของฉัน               ← แถวคงที่ อยู่บนสุดของ list เสมอ
─────────────────────────────────         (icon Icons.my_location, สี sapphire)

Starbucks                                  ← ผลลัพธ์ (ListTile)
  สยามพารากอน

Starbucks                                  ← disambiguation: ที่อยู่ย่อยเป็น
  เซ็นทรัลเวิลด์                              subtitle (ตาม Product spec
                                            Edge Case "ผลกำกวม")
```
- Header (drag handle + title "เพิ่มสถานที่" + ปุ่มปิด X มุมขวาบน) — **reuse โครงเดียวกับ `_showPermissionPicker`/WYN-097's Screen 2 เป๊ะ** (ไม่ประดิษฐ์ header ใหม่)
- ช่องค้นหา: reuse `FollowListScreen._buildSearchBar()` เป๊ะ (`height: 40`, พื้น `Color(0xFFF1EFE9)`, `borderRadius: WynSpacing.radiusFull`, `border: hairline`, icon `Icons.search` size 14 สี `mutedNeutral`) เปลี่ยนแค่ `hintText` เป็น "ค้นหาสถานที่..."
- แถว "ใช้ตำแหน่งปัจจุบันของฉัน": `ListTile(leading: Icon(Icons.my_location, color: WynColors.sapphire), title: Text('ใช้ตำแหน่งปัจจุบันของฉัน', style: TextStyle(color: WynColors.sapphire, fontWeight: FontWeight.w600)))` — สีต่างจากแถวผลลัพธ์ปกติ (sapphire ไม่ใช่ ink) เพื่อสื่อว่าเป็น action พิเศษ ไม่ใช่ผลลัพธ์ค้นหาทั่วไป — คั่นด้วย `Divider(height: 1, color: WynColors.hairline)` จาก list ผลลัพธ์ด้านล่าง
- แถวผลลัพธ์: `ListTile(leading: Icon(Icons.place_outlined, color: WynColors.mutedNeutral), title: Text(placeName), subtitle: address != null ? Text(address, style: TextStyle(color: WynColors.graphite, fontSize: 13)) : null)` — ไม่มี subtitle เมื่อ LocationIQ ไม่ส่งที่อยู่ย่อยมา (ไม่ใส่ placeholder ว่างเปล่า)

**Interactions:**
- พิมพ์ในช่องค้นหา → debounce ~400-500ms (ตาม Product spec) → ยิง autocomplete → list ผลลัพธ์อัปเดต แทนที่ผลลัพธ์เก่า (request เก่าที่ยังไม่ตอบถูก ignore เมื่อมี request ใหม่กว่า — race condition guard ตาม Product spec)
- แตะ "ใช้ตำแหน่งปัจจุบันของฉัน" → ขอ GPS permission (ถ้ายังไม่เคยอนุญาต ผ่าน dialog มาตรฐานของ OS) → loading state (ดู States) → ยิง reverse geocoding → **ไม่ auto-select ทันที** แสดงผลลัพธ์แรก (ใกล้ที่สุด) เป็นแถวบนสุดของ list ให้ผู้ใช้กดยืนยันเอง (ตาม Product spec — "reverse geocoding อาจได้ผลลัพธ์ที่ไม่ตรงกับที่ผู้ใช้ตั้งใจ")
- แตะแถวผลลัพธ์ใดก็ตาม → sheet ปิด, ส่งค่ากลับ (`Navigator.pop` พร้อม location object: name/lat/lon/placeId)

**States:**
- ว่างเปล่า (ยังไม่พิมพ์/ยังไม่กดตำแหน่งปัจจุบัน) → list ว่าง มีแค่แถว "ใช้ตำแหน่งปัจจุบันของฉัน" อย่างเดียว ไม่มีข้อความ empty-state เพิ่ม (เป็น initial state ปกติ ไม่ใช่ error/ไม่พบ)
- กำลังค้นหา (debounce ผ่านแล้ว รอผล) → `LinearProgressIndicator` บางๆ ใต้ช่องค้นหา + ข้อความเล็ก "กำลังค้นหาสถานที่..." (สี `mutedNeutral`) แทนที่ list ผลลัพธ์เดิมชั่วคราว (ไม่ล้าง list เก่าทันที ป้องกันจอกระพริบ — โชว์ progress indicator ทับ ไม่ใช่แทนที่)
- กำลังหาตำแหน่งปัจจุบัน (รอ GPS+reverse geocoding) → แถว "ใช้ตำแหน่งปัจจุบันของฉัน" เปลี่ยนเป็น `CircularProgressIndicator` เล็ก (16×16) แทน icon เดิม + label เปลี่ยนเป็น "กำลังค้นหาตำแหน่งของคุณ..." (disabled ระหว่างนี้ กดซ้ำไม่ได้)
- ไม่พบผลลัพธ์ (ค้นหาแล้วว่างเปล่าจริง) → `Center` + `Text('ไม่พบสถานที่ที่ค้นหา ลองพิมพ์คำอื่นดูนะ')` สี `faint` (มิเรอร์ `FollowListScreen`'s "ไม่พบผู้ใช้ที่ตรงกับ..." เป๊ะ)
- ไม่มีสิทธิ์ GPS → `SnackBar`/inline text "WYN ไม่มีสิทธิ์เข้าถึงตำแหน่งของคุณ กรุณาเปิดสิทธิ์ในการตั้งค่าเครื่อง" — **ไม่ block ทั้ง sheet** ผู้ใช้ยังพิมพ์ค้นหาต่อได้ปกติ (ตาม Product spec Edge Case)
- API ล่ม/timeout → `SnackBar` "ค้นหาสถานที่ไม่สำเร็จตอนนี้ ลองอีกครั้งในอีกสักครู่"
- Rate-limited (WYN เอง, HTTP 429 จาก Edge Function) → `SnackBar` "ค้นหาบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่"

**Responsive Behavior:** sheet สูงพอสมควร (ไม่ `MainAxisSize.min` แบบ Screen อื่นที่เนื้อหาสั้น — ใช้ `DraggableScrollableSheet` หรือ fixed สูง ~70-85% ของจอ เพราะ list ผลลัพธ์อาจยาว) ทดสอบที่ 360px กว้าง ไม่ให้ subtitle ที่อยู่ย่อยล้น (`overflow: TextOverflow.ellipsis`)

**Accessibility:** ช่องค้นหามี label "ค้นหาสถานที่", แถว "ใช้ตำแหน่งปัจจุบันของฉัน" มี `Semantics(label: 'ใช้ตำแหน่งปัจจุบันของฉันเป็นสถานที่เช็คอิน', button: true)`, แถวผลลัพธ์มี `Semantics(label: '$placeName, $address')`

**Design Rules:** Header ใช้โครง `_showPermissionPicker` เดิม, search bar ใช้โครง `FollowListScreen._buildSearchBar()` เดิม — ส่วนใหม่จริงมีแค่: แถว "ใช้ตำแหน่งปัจจุบัน" + แถวผลลัพธ์สถานที่ (ยังคงเป็น `ListTile` มาตรฐานของ Material ไม่ประดิษฐ์ widget ใหม่)

**Handoff:** AI Coding — widget ใหม่ `LocationPickerSheet` (หรือ full-screen ถ้า AI Coding เห็นว่า `DraggableScrollableSheet` ไม่พอสำหรับ keyboard-open state — ให้ AI Coding ตัดสินใจ modal vs. full-screen push ตาม UX จริงที่ implement ได้ลื่นไหลกว่า ไม่ใช่จุดตัดสินใจตายตัวของเอกสารนี้ ขอแค่ header/search bar/list ตรงตาม spec ข้างต้น) — ต้องเรียก `supabase.functions.invoke('location-search', ...)` ตาม Product spec ไม่ยิง LocationIQ ตรงจากแอป — เพิ่ม dependency ตรวจสอบ location permission (`geolocator` หรือเทียบเท่า — ตรวจสอบว่า `app/pubspec.yaml` มีอยู่แล้วหรือไม่ก่อนเพิ่มใหม่)

---

## Screen 3 — Chip สถานที่ที่เลือกไว้ (บนหน้าสร้างโพสต์)

**Purpose:** แสดงสถานที่ที่เลือกไว้แล้วบนหน้า `CreateDropScreen` พร้อมทางลบออกได้ก่อนโพสต์จริง

**User Flow:** หลังเลือกสถานที่จาก Screen 2 → กลับมาเห็น chip ปรากฏใกล้ช่องแคปชัน → กด X บน chip → สถานที่ถูกเอาออก (กลับสู่สถานะไม่มีสถานที่) → กดปุ่มปักหมุดใหม่ได้อีกครั้งถ้าต้องการเลือกใหม่

**Components:** วางไว้เหนือ toolbar (ใต้ช่องแคปชัน/พื้นที่รูป) — ไม่ทับ `_AudienceChip` (WYN-097) ที่อยู่ในตำแหน่งอื่น (ตรวจสอบ layout จริงของ `CreateDropScreen` ตอน implement ว่าสองแถบนี้ไม่ชนกัน — ถ้าจำเป็นวางเป็น `Wrap`/`Row` เดียวกันได้ทั้งคู่):
```
📍 สยามพารากอน                    [X]
```
- `Chip`-style container มิเรอร์รูปทรงเดียวกับ `_AudienceChip` เดิม (`Color(0xFFF1EFE9)` พื้น, `hairline` border, `radiusFull`) เพื่อความสม่ำเสมอของ "แถบข้อมูลเสริมตอนโพสต์" ทั้งสองจุด (audience chip + location chip ใช้โครงเดียวกัน แค่เนื้อหาต่างกัน) — icon นำหน้า `Icons.location_on` size 14 สี `WynColors.sapphire`, ข้อความชื่อสถานที่ (`ellipsis` ถ้ายาวเกิน ~24 ตัวอักษร), ปุ่ม X (`Icons.close`, size 14) ท้ายสุด

**Interactions:** แตะ X → เอาสถานที่ออกทันที (ไม่มี confirm dialog — การกระทำ reversible ง่าย กดปุ่มปักหมุดใหม่ได้ทันที ไม่ต้องถามยืนยัน)

**States:** ไม่แสดง chip เลยถ้ายังไม่ได้เลือกสถานที่ (ค่าเริ่มต้นของโพสต์ใหม่ทุกครั้ง)

**Accessibility:** ปุ่ม X มี `Semantics(label: 'นำสถานที่ออก', button: true)` ตาม Product spec copy เป๊ะ

**Design Rules:** ใช้โครง chip เดียวกับ `_AudienceChip` เดิม ไม่ประดิษฐ์ shape ใหม่

**Handoff:** AI Coding — field ใหม่ `_selectedLocation` (name/lat/lon/placeId) ใน `_CreateDropScreenState`, ส่งเข้า `DropRepository.createDrop()` เป็น parameter ใหม่

---

## Screen 4 — แสดงผลสถานที่บนโพสต์ที่โพสต์ไปแล้ว

**Purpose:** แสดงชื่อสถานที่บนการ์ดโพสต์ (`HomeDropCard`) และหน้ารายละเอียด (`DropDetailScreen`) เมื่อโพสต์นั้นมี `location`

**User Flow:** ผู้ใช้เลื่อนดู Home feed/เปิดโพสต์ → เห็นชื่อสถานที่ (ถ้ามี) ใต้ชื่อผู้โพสต์ — เป็น text ธรรมดา ไม่ tappable (ตาม Product spec Out of Scope)

**Components:**
- **ตำแหน่ง**: บรรทัดที่ 2 ของ author-identity column (แทนที่/ต่อจาก `relativeTimeLabel` เดิม) — ทั้ง `HomeDropCard` (บรรทัด ~313-318) และ `DropDetailScreen` (บรรทัด ~704-710) มีโครง `Column(children: [ชื่อ Row, เวลา Text])` เดียวกันอยู่แล้ว **ต่อท้ายบรรทัดเวลาด้วย " · 📍 {ชื่อสถานที่}"** (มิเรอร์ pattern เดียวกับที่ redrop-header ใช้อยู่แล้วสำหรับต่อท้ายเวลาด้วยข้อมูลเสริม บรรทัด 259 ของ `home_drop_card.dart`) แทนที่จะเป็นบรรทัดที่ 3 แยกต่างหาก — **เหตุผล**: ประหยัดพื้นที่แนวตั้งของการ์ด (สอดคล้องหลัก "เรียบ ไม่เทอะทะ" ที่ระบบยึดมาตลอด) และ location เป็น metadata เสริมของ "เมื่อไหร่/ที่ไหน" ระดับเดียวกัน ไม่ใช่เนื้อหาหลักที่ต้องเด่นแยก
- Text เต็ม: `'${relativeTimeLabel(...)} · 📍 ${drop.location}'` — ถ้า `drop.location == null` แสดงแค่เวลาเหมือนเดิมทุกประการ (ไม่มีจุด `·` ค้างเปล่าๆ)
- สไตล์เดิมทั้งหมด (`Theme.of(context).textTheme.bodySmall` สี `colorScheme.outline`/`WynColors.mutedNeutral` ตามที่แต่ละไฟล์ใช้อยู่แล้ว) — ไม่มีสี/font ใหม่สำหรับส่วน location

**Interactions:** ไม่มี (ไม่ tappable ตาม Product spec ชัดเจน) — **ไม่ห่อด้วย `InkWell`/`GestureDetector`** เพื่อไม่ให้ดูเหมือน tappable โดยไม่ตั้งใจ (สำคัญ — ถ้าใส่ hover/ripple effect โดยไม่ได้ตั้งใจจะขัดกับ Out of Scope ของ Product spec)

**States:** โพสต์ไม่มี location → ไม่แสดงส่วนนี้เลย (ทั้งการ์ดและหน้า detail render เหมือนเดิมทุกประการ ไม่มี regression กับโพสต์เก่า/โพสต์ที่ไม่เช็คอิน)

**Responsive Behavior:** ถ้าชื่อสถานที่ยาว + เวลา รวมกันล้นความกว้างการ์ด → `overflow: TextOverflow.ellipsis` (ตัดที่ท้ายบรรทัด ไม่ wrap 2 บรรทัด เพื่อคุมความสูงการ์ดให้คงที่) ทดสอบที่ 360px

**Accessibility:** รวมอยู่ใน `Semantics` ของ author row เดิม (เวลา+สถานที่อ่านต่อกันเป็นประโยคเดียวโดย screen reader อัตโนมัติ ไม่ต้องแยก label)

**Design Rules:** ไม่มี card/section ใหม่ — ต่อท้าย text บรรทัดเวลาที่มีอยู่แล้วเท่านั้น ไอคอนหมุด "📍" ใช้เป็น emoji ตรงตาม Product spec copy (ไม่ใช้ `Icon` widget แยก เพื่อความง่ายในการต่อ string เดียวกับเวลา — สอดคล้องกับที่ Product spec เขียน copy ไว้เป็น "📍 {ชื่อสถานที่}" ตรงๆ)

**Handoff:** AI Coding — แก้ `HomeDropCard`/`DropDetailScreen` ที่จุดแสดงเวลาทั้งสองไฟล์ ต้องเพิ่ม `location`/`locationName` field เข้า `HomeFeedItem`/Drop model ที่มีอยู่แล้ว (คอลัมน์ `drops.location` มีอยู่แล้วในฐานข้อมูลตาม Product spec — งานนี้แค่ต้องให้ query/mapping ฝั่งแอปอ่านค่านี้ขึ้นมาด้วย)

---

## Out of Scope (ตรงตาม Product spec — ไม่ออกแบบเพิ่ม)

- ไม่มีแผนที่ live/interactive ใดๆ
- แตะชื่อสถานที่บนโพสต์ไม่เปิดอะไร (ไม่ tappable)
- ไม่มีหน้ารวม "โพสต์จากสถานที่นี้"/location discovery feed
- ไม่มีการแก้ไข location หลังโพสต์แล้ว (เอาออกได้ก่อนกด "แชร์" เท่านั้น — ดู Screen 3)
- ไม่มี auto-suggest จากประวัติที่เคยเช็คอิน

## Handoff รวม

ส่งต่อ **AI Coding** (`/code`) — ลำดับแนะนำ: Screen 1 (เปลี่ยน `onTap` เดียว, เร็วสุด) → data model (คอลัมน์ `location_lat`/`location_lon`/`location_place_id` ใหม่บน `drops`, Edge Function `location-search`, `location_search_requests` rate-limit table — ตาม Product spec) → Screen 2 (ต้องรอ Edge Function พร้อม แต่ implement UI คู่ขนานด้วย mock data ได้เลยตามที่ Product spec แนะนำ) → Screen 3/4 (ผูกกับ data model, ทำหลัง Screen 2 เสถียร)

**ยังบล็อกด้วย Founder/DevOps action** (ไม่ block การเริ่ม Design/Coding แต่ block การทดสอบ end-to-end จริง): ต้องมี LocationIQ account + API key จริงก่อน — ระหว่างนี้ AI Coding ควร implement ด้วย mock/placeholder response ตาม Recommendation ของ Product spec ข้อ 1
