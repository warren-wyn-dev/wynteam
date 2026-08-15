# Design — SELLER-004 (ZOKY Sellers by WYN: Store Management)

อ้างอิง Product spec: `.wyn/tasks/backlog/SELLER-004-store-management.md` — แทนที่ tab "ร้านค้า" (`SellerHomeShell` index 3) ที่ยังเป็น `SellerComingSoonScreen` ด้วยฟอร์มแก้ไขข้อมูลร้านจริง (โลโก้/แบนเนอร์/ชื่อ/คำอธิบาย/ที่อยู่/เบอร์ติดต่อ/เวลาทำการ), sync ข้อมูลใหม่ไปยัง tab อื่นในเซสชันเดียวกันผ่าน `onStoreUpdated` callback, และแสดง banner + "ข้อมูลร้านค้า" section บน `StoreScreen` ฝั่งลูกค้า

Design system เดิมทั้งหมด (Blue+White+Soft Gray seed `0xFF2D6CDF`, Material 3, Rounded Cards, ห้าม Liquid Glass) — ไม่มีจุดไหนใน SELLER-004 เป็น visual language ใหม่ ทุก component มิเรอร์จาก `app/`'s `EditClubInfoScreen` (banner 16:9 + logo circle picker) และ pattern ที่มีอยู่แล้วใน `seller_app/` จาก SELLER-001/002

## ภาพรวม: reuse pattern อะไรจากที่ไหน

| Component ใหม่ | มิเรอร์จาก |
|---|---|
| `SellerStoreScreen`'s banner picker (16:9) | `EditClubInfoScreen._buildCoverPicker()` เป๊ะ (`GestureDetector`+`AspectRatio`+`ClipRRect`+placeholder icon) |
| `SellerStoreScreen`'s logo picker (circle) | `EditClubInfoScreen._buildIconPicker()` เป๊ะ (`CircleAvatar`+camera badge มุมขวาล่าง) |
| `SellerStoreScreen`'s ฟอร์มฟิลด์ข้อความ | `EditClubInfoScreen`'s `TextField` styling (labelText ผ่าน `InputDecoration`, `maxLength`) + `CreateStoreScreen`'s ปุ่มบันทึก disable-on-empty-name/submitting pattern |
| ค่าว่าง → `null` ก่อนบันทึก | `normalizeOptionalText` เดิม (`seller_app/lib/core/text_utils.dart`) — pattern เดียวกับ SELLER-002 |
| Upload รูปก่อน insert/update แถว | `SellerRepository.createProduct`/`updateProduct`'s "upload first" (SELLER-002) — ดูเหตุผลที่เลือก pattern นี้แทน `ClubRepository`'s สองการเรียกแยกใน "การตัดสินใจ Design" ด้านล่าง |
| `onStoreUpdated`/`onStoreCreated` callback-to-parent-rebuild | `CreateStoreScreen.onStoreCreated`/`UsernameSetupScreen.onUsernameSet` (SELLER-001, `.wyn/learning/PATTERNS.md`) |
| StoreScreen banner display (ลูกค้า) | Full-width edge-to-edge image ธรรมดา (ตัดสินใจไม่ใช้ `club_page.dart`'s Stack+Positioned overlap pattern — ดูเหตุผลใน Design Rules ของ Screen: StoreScreen ด้านล่าง) |
| Info row ("ข้อมูลร้านค้า" section) | icon+text row เรียบง่าย มิเรอร์หลักการ "icon กำกับข้อความเสมอ ไม่สื่อสารด้วยข้อความอย่างเดียว" ที่ใช้ทั่วโปรเจกต์ (เช่น `OrderStatusBadge`/`ProductActiveBadge`) |

---

## Screen: `SellerStoreScreen` (ใหม่ — แทนที่ tab "ร้านค้า" ของ `SellerHomeShell`, index 3)

Purpose: ให้ seller แก้ไขข้อมูลร้านของตัวเองได้ครบทุกฟิลด์ในหน้าเดียว ไม่มีโหมด view แยกจาก edit — เปิด tab มาก็เห็นฟอร์ม pre-fill พร้อมแก้ไขได้ทันที

User Flow:
1. เปิด tab "ร้านค้า" → ฟอร์ม pre-fill ด้วยข้อมูลร้านปัจจุบันทุกฟิลด์ (จาก `store` ที่ `SellerHomeShell` ส่งเข้ามา ไม่ fetch ซ้ำ — ข้อมูลสดอยู่แล้วเพราะมาจาก state ของ shell)
2. แตะ banner/โลโก้ → `ImagePicker` เปิด gallery → เลือกรูป → preview ในพิกเกอร์ทันที (ยังไม่อัปโหลดจนกว่าจะกด "บันทึก")
3. แก้ไขฟิลด์ข้อความใด ๆ (ชื่อร้าน/คำอธิบาย/ที่อยู่/เบอร์ติดต่อ/เวลาทำการ)
4. กด "บันทึก" → อัปโหลดรูปที่เปลี่ยน (ถ้ามี) → update `stores` row → สำเร็จ: `SnackBar` "บันทึกข้อมูลร้านสำเร็จ" + เรียก `widget.onStoreUpdated(updatedStore)` — **อยู่หน้าเดิมต่อ ไม่ pop** (ต่างจาก `EditClubInfoScreen` ที่ `Navigator.pop()` เพราะเป็น pushed route — `SellerStoreScreen` เป็น tab body ใน `IndexedStack` ไม่มี route ให้ pop)
5. สลับไป tab อื่น (เช่น Dashboard) โดยไม่ปิดแอป → เห็นข้อมูลร้านใหม่ทันที (ดู Screen: SellerHomeShell ด้านล่างสำหรับกลไก sync)

Components (บนลงล่าง, ภายใน `SingleChildScrollView` + `Column(crossAxisAlignment: stretch)` มิเรอร์ `EditClubInfoScreen`/`CreateStoreScreen` เป๊ะ):
- `AppBar(title: Text('ร้านค้า'))` — ไม่มีปุ่มย้อนกลับ (เป็น tab ไม่ใช่ pushed route, มิเรอร์ `SellerProductListScreen`)
- **Banner picker**: `GestureDetector` + `AspectRatio(aspectRatio: 16/9)` + `ClipRRect(borderRadius: 12)` — แสดงรูปที่เพิ่งเลือก (`Image.memory`) > รูปเดิมจาก `store.bannerUrl` (`Image.network`) > placeholder `Icon(Icons.add_photo_alternate_outlined, size: 32)` กึ่งกลาง พื้นหลัง `surfaceContainerHighest` — โครง**เดียวกับ** `EditClubInfoScreen._buildCoverPicker()` ทุกจุด เปลี่ยนแค่ตัวแปรอ้างอิง (`club.coverUrl` → `store.bannerUrl`)
- **Logo picker**: `Center` + `GestureDetector` + `Stack([CircleAvatar(radius: 36, ...), Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 12, child: Icon(Icons.camera_alt, size: 14)))])` — โครง**เดียวกับ** `EditClubInfoScreen._buildIconPicker()` ทุกจุด (`club.iconUrl` → `store.logoUrl`) — placeholder เมื่อไม่มีรูปคือ `Icon(Icons.add_photo_alternate_outlined)` (ไอคอนเดียวกับ banner picker's placeholder, **ไม่ใช่** initials fallback ที่ `StoreScreen` ฝั่งลูกค้าใช้ — จุดนั้นเป็นคนละที่คนละเจตนา: หน้าแก้ไขต้องสื่อสาร "แตะเพื่อเพิ่มรูป" ชัดเจน ส่วนหน้าลูกค้าไม่มี interaction แตะเพื่ออัปโหลด initials จึงเหมาะสมกว่า)
- `TextField` ชื่อร้าน (label "ชื่อร้าน", `maxLength: 100` — ตรงกับ `stores_name_length` constraint เดิม, บังคับ, `onChanged: (_) => setState(() {})` เพื่อ re-evaluate ปุ่มบันทึก มิเรอร์ `EditClubInfoScreen`)
- `TextField` คำอธิบาย (label "คำอธิบาย", multiline `maxLines: 4`, `maxLength: 500` — ไม่บังคับ, ค่า `maxLength` เป็น client-side UX guard เท่านั้นเพราะ `stores.description` ไม่มี DB length constraint อยู่ตอนนี้ — ใช้ตัวเลขเดียวกับ `EditClubInfoScreen`'s description field เพื่อความสม่ำเสมอ ไม่ใช่ requirement ใหม่)
- `TextField` ที่อยู่ (label "ที่อยู่ (ไม่บังคับ)", multiline `maxLines: 3`, `maxLength: 300` — ตรงกับ `stores_address_length`)
- `TextField` เบอร์ติดต่อ (label "เบอร์ติดต่อ (ไม่บังคับ)", `keyboardType: TextInputType.text` — **ไม่ใช่** `phone` เพราะ Product spec ตั้งใจให้เป็น free text รองรับ LINE ID/ช่องทางอื่น ไม่ validate รูปแบบ, `maxLength: 50` — ตรงกับ `stores_contact_phone_length`)
- `TextField` เวลาทำการ (label "เวลาทำการ (ไม่บังคับ)", hintText ตัวอย่างชัดเจนกันความสับสน: "เช่น จันทร์-ศุกร์ 9:00-18:00 น.", multiline `maxLines: 2`, `maxLength: 200` — ตรงกับ `stores_business_hours_length`)
- ถ้ามี error: ข้อความสีแดงกึ่งกลาง (มิเรอร์ `EditClubInfoScreen`/`CreateStoreScreen` เป๊ะ)
- `FilledButton` เต็มความกว้าง "บันทึก" — spinner 20x20 ระหว่างบันทึก (มิเรอร์ `EditClubInfoScreen`)

Interactions:
- ปุ่ม "บันทึก" `enabled` เมื่อ `!_isSaving && _nameController.text.trim().isNotEmpty` เท่านั้น (มิเรอร์ `EditClubInfoScreen`'s `canSave` — ฟิลด์อื่นทั้งหมดไม่บังคับ ไม่ต้องเช็ค)
- ทุกฟิลด์ `enabled: !_isSaving` ระหว่างกำลังบันทึก (มิเรอร์ `EditClubInfoScreen`)
- แตะ banner/โลโก้ระหว่างกำลังบันทึกไม่ทำอะไร (`onTap: _isSaving ? null : _pickBanner/_pickLogo`)

States:
- Loading: ไม่มี (ฟอร์ม pre-fill จาก `widget.store` ที่มีอยู่แล้วทันที ไม่ต้อง fetch เพิ่ม — ต่างจากหลาย screen อื่นที่ต้อง `FutureBuilder`)
- Submitting: ปุ่มบันทึก disable + spinner แทนข้อความ (มิเรอร์ `EditClubInfoScreen`)
- สำเร็จ: `SnackBar` "บันทึกข้อมูลร้านสำเร็จ" + `onStoreUpdated` callback (ไม่ pop, ไม่ reset ฟอร์ม — ฟอร์มยังโชว์ค่าที่เพิ่งบันทึกไปเป๊ะ เพราะ controller ยังถือค่าที่ผู้ใช้พิมพ์อยู่แล้ว ไม่ต้อง re-populate จาก response)
- Error (บันทึกไม่สำเร็จ ไม่ว่าจะจากการอัปโหลดรูปหรือ update แถวล้มเหลว, รวมถึง DB CHECK constraint ที่ปฏิเสธความยาวเกินกำหนด — เป็น safety-net เพราะ `maxLength` ที่ชั้น client กันการพิมพ์เกินไว้แล้วในสภาวะปกติ): ข้อความ "บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง" (generic เดียวกับ `EditClubInfoScreen`/`CreateStoreScreen` — ไม่ parse ข้อความ Postgres error ดิบเป็น field-specific เพราะไม่มี AC ไหนต้องการความเจาะจงระดับนั้น ต่างจาก `InsufficientStockException` ของ SELLER-002 ที่ต้องแยกเพราะเป็น expected business flow ปกติ ไม่ใช่ edge case ป้องกันชั้นที่สอง)

Responsive Behavior: `SingleChildScrollView` มือถือ portrait คอลัมน์เดียวเต็มความกว้างจอ (ตาม convention ทั้งโปรเจกต์) — `MediaQuery.viewInsets.bottom` padding กันคีย์บอร์ดบังฟิลด์ท้าย ๆ (มิเรอร์ `ReviewFormSheet`/`SellerProductFormScreen`)

Accessibility: banner/logo picker มี `Semantics` label ชัดเจน ("แตะเพื่อเปลี่ยนรูปแบนเนอร์ร้าน", "แตะเพื่อเปลี่ยนโลโก้ร้าน" — จุดนี้ `EditClubInfoScreen` เดิม**ไม่มี** Semantics label ให้ picker ทั้งสอง เป็นช่องว่างสืบทอดมา แนะนำ Coding เพิ่มให้ครบในจุดใหม่นี้เหมือนที่ SELLER-002 แนะนำไว้กับปุ่ม X ลบรูป — mirror "หน้าตา/พฤติกรรม" ไม่ควร mirror gap ที่ไม่ตั้งใจ) — ทุก `TextField` มี label ผ่าน `InputDecoration.labelText` อัตโนมัติอยู่แล้ว

Design Rules:
- ไม่มีสีใหม่ ไม่มี layout ใหม่ — ทุก `TextField` ใช้ Material 3 outlined style ค่าเริ่มต้นของธีมเดิม
- **การตัดสินใจ Design — ทำไม `updateStoreInfo` เป็น 1 เมธอดรวม ไม่ใช่ 3 เมธอดแยกแบบ `ClubRepository`**: `EditClubInfoScreen` เรียก `uploadClubCover`/`uploadClubIcon`/`updateClubInfo` แยกกัน 3 ครั้งเพราะ `club-media` เป็น **private bucket** ต้อง fetch signed URL กลับมาใหม่ทุกครั้งหลัง upload (`_signedUrl()`) — `store-media` เป็น **public bucket** (เหมือน `product-images`) ได้ URL ทันทีจาก `getPublicUrl()` หลัง upload โดยไม่ต้อง round-trip เพิ่ม จึงออกแบบ `SellerRepository.updateStoreInfo` เป็นเมธอดเดียวที่ upload รูปที่เปลี่ยน (ถ้ามี) ก่อน แล้ว update ทุกฟิลด์ (ข้อความ+URL รูปใหม่ถ้ามี) ในคำสั่ง `update()` เดียว — ลด round-trip จาก 3 เหลือ 1-3 ครั้งตามจริง (ไม่ upload รูปที่ไม่ได้เปลี่ยน) มิเรอร์หลักการ "upload first" เดียวกับ `createProduct`/`updateProduct` ของ SELLER-002 ตรงกว่า `ClubRepository` ในบริบทนี้ — เป็นการเลือก pattern ที่เหมาะกับ public bucket ไม่ใช่การประดิษฐ์ approach ใหม่
- **ห้าม pop หลังบันทึกสำเร็จ** (ย้ำจากด้านบน) — เป็นจุดที่ต่างจาก `EditClubInfoScreen` ที่สุด เพราะบริบทการ mount ต่างกัน (tab vs pushed route) ต้องระวังไม่ copy พฤติกรรม pop มาด้วย
- ชื่อไฟล์: `seller_app/lib/features/store/presentation/seller_store_screen.dart`

Handoff: `SellerRepository` เมธอดใหม่ —
```
Future<Store> updateStoreInfo({
  required String storeId,
  required String name,
  String? description,
  String? address,
  String? contactPhone,
  String? businessHours,
  Uint8List? newLogoBytes,
  String? newLogoExtension,
  Uint8List? newBannerBytes,
  String? newBannerExtension,
})
```
— upload `newLogoBytes`/`newBannerBytes` (ถ้าไม่ null) เข้า `store-media` bucket ก่อนเสมอ (path `{storeId}/logo-{timestamp}.{ext}` / `{storeId}/banner-{timestamp}.{ext}` ตาม Product spec ข้อ 6) ได้ public URL กลับมาทันที แล้ว update `stores` row ครั้งเดียว (`name`/`description`/`address`/`contact_phone`/`business_hours` ผ่าน `normalizeOptionalText` ทุกฟิลด์ที่ไม่บังคับ + `logo_url`/`banner_url` เฉพาะเมื่อมีรูปใหม่จริง) คืน `Store` แถวล่าสุดจาก `.select().single()` — ใช้ผลลัพธ์นี้ตรง ๆ เป็น argument ของ `onStoreUpdated` (ไม่ query ซ้ำ)

---

## Screen: `SellerHomeShell` (แก้ไข — mutable store state เพื่อ sync ข้ามแท็บ)

Purpose: ทำให้ทุก tab เห็นข้อมูลร้านล่าสุดในเซสชันเดียวกัน โดยไม่ต้อง re-fetch/sign-in ใหม่ — แก้ปัญหาที่ Product spec ระบุไว้ตรง ๆ ใน Requirements #3 และ Risks

การเปลี่ยนแปลง (เทียบกับ `seller_home_shell.dart` ปัจจุบัน):
- เพิ่ม field ใหม่ `late Store _store = widget.store;` ใน `_SellerHomeShellState` (แทนการอ้าง `widget.store` ตรง ๆ ในทุกจุดของ `build()`)
- `tabs` list ทั้ง 5 รายการอ้างอิง `_store` แทน `widget.store` ทุกจุด (`SellerDashboardScreen`, `SellerProductListScreen`, `SellerOrderListScreen` — ทั้งสามใช้ `store:` parameter อยู่แล้ว เปลี่ยนแค่ตัวแปรต้นทาง)
- tab index 3 เปลี่ยนจาก `const SellerComingSoonScreen(label: 'ร้านค้า')` เป็น:
  ```
  SellerStoreScreen(
    store: _store,
    sellerRepository: widget.sellerRepository,
    onStoreUpdated: (updated) => setState(() => _store = updated),
  )
  ```
- tab index 4 ("การเงิน") **ไม่แตะ** — ยังเป็น `SellerComingSoonScreen(label: 'การเงิน')` เหมือนเดิมจนกว่า SELLER-005

States: ไม่มี state ใหม่ (แค่เปลี่ยนแหล่งข้อมูลจาก `widget.store` เป็น `_store` ในการ render)

Design Rules: **จุดเสี่ยงที่ Product spec เตือนไว้ตรง ๆ ใน Risks** — ถ้า Coding ลืมเปลี่ยน field ใดใน `tabs` list จาก `widget.store` เป็น `_store` (โดยเฉพาะ `SellerDashboardScreen` ที่แสดง `store.name` ตรง ๆ) tab นั้นจะค้างชื่อร้านเก่าแม้ callback ทำงานถูกต้อง — ต้องเปลี่ยนทั้ง 4 จุดที่อ้าง store ให้ครบ (Dashboard/Product/Order/Store เอง) ไม่ใช่แค่จุดที่ส่ง callback

Handoff: ส่งต่อ AI Coding

---

## Screen: `StoreScreen` (แก้ไข — `app/lib/features/zoky/presentation/store_screen.dart`, ฝั่งลูกค้า, ผ่าน QA แล้วจาก ZOKY-001)

Purpose: แสดง banner ร้าน (ถ้ามี) + ข้อมูลที่อยู่/เบอร์ติดต่อ/เวลาทำการ (ถ้ามีอย่างน้อย 1 ฟิลด์) ให้ลูกค้าเห็น — **regression-safe 100%** สำหรับร้านเดิมที่ไม่มีข้อมูลใหม่เหล่านี้เลย

การเปลี่ยนแปลง (2 จุด แทรกเข้าโครงเดิม ไม่ปรับโครงสร้างใหม่):

**1) Banner — แทรกก่อน `_buildHeader(context, store)` ใน `build()`'s success-path `Column`:**
```
children: [
  if (store.bannerUrl != null) _buildBanner(context, store),
  _buildHeader(context, store),
  const TabBar(...),
  ...
],
```
`_buildBanner` เป็น widget ใหม่: `AspectRatio(aspectRatio: 16/9, child: Image.network(store.bannerUrl!, fit: BoxFit.cover))` เต็มความกว้างจอ (edge-to-edge, **นอก** `Padding(16)` ที่ครอบ `_buildHeader` — ต่างจากรูปแบบ Stack+Positioned ของ `club_page.dart`'s cover ที่ให้ avatar ลอยทับขอบล่าง เพราะ Product spec ระบุตรงว่า "เพิ่มรูป banner ... **เหนือ** Row(โลโก้+ชื่อร้าน) เดิม" ไม่ใช่ overlap — การไม่ overlap ทำให้ diff เล็กที่สุดและไม่กระทบ `_buildHeader`'s เดิมแม้แต่บรรทัดเดียว) — เมื่อ `bannerUrl == null` ไม่ render อะไรเลย (ใช้ `if` ใน children list ไม่ใช่ `Visibility`/`SizedBox.shrink()` ที่ยังกิน element tree เปล่า ๆ — ผลลัพธ์เหมือนเดิมเป๊ะสำหรับร้านที่ไม่มี banner)

**2) "ข้อมูลร้านค้า" section — แทรกใน `_buildHeader()`, หลัง description block เดิม, ก่อนปุ่ม "ติดตามร้าน":**
```
if (store.description != null && store.description!.isNotEmpty) ...[
  const SizedBox(height: 12),
  Text(store.description!),
],
if (_hasStoreInfo(store)) ...[
  const SizedBox(height: 12),
  _buildStoreInfoSection(context, store),
],
const SizedBox(height: 12),
Semantics(... 'ติดตามร้าน' button ...),
```
`_hasStoreInfo(Store store) => store.address != null || store.contactPhone != null || store.businessHours != null;` — ถ้า `false` ไม่ render section เลย (ตรง AC เป๊ะ: ไม่ใช่ section ว่างเปล่า)

`_buildStoreInfoSection` components: `Card` (rounded, มิเรอร์สไตล์การ์ดเดิมของโปรเจกต์) ครอบ `Column` ของแถว info — แต่ละแถว render **เฉพาะฟิลด์ที่ไม่ null**:
- ที่อยู่: `Row([Icon(Icons.location_on_outlined, size: 18), SizedBox(width: 8), Expanded(child: Text(store.address!))])`
- เบอร์ติดต่อ: `Row([Icon(Icons.call_outlined, size: 18), SizedBox(width: 8), Text(store.contactPhone!)])`
- เวลาทำการ: `Row([Icon(Icons.access_time_outlined, size: 18), SizedBox(width: 8), Expanded(child: Text(store.businessHours!))])`

ทั้ง 3 แถว spacing `SizedBox(height: 8)` คั่นระหว่างแถวที่ render จริงเท่านั้น (ไม่เผื่อ spacing ให้แถวที่ null)

Interactions: ไม่มี tap action ใหม่ (ทั้ง banner และ info section เป็น display-only รอบนี้ — ตรงตาม Product spec ที่ไม่ระบุ interaction เพิ่มเติม)

States: ไม่มี state ใหม่ — ใช้ `_storeFuture` เดิมที่ fetch สดทุกครั้งที่ `initState()` (Product spec ยืนยันแล้วว่าเพียงพอ ไม่ต้องเพิ่ม realtime subscription)

Responsive Behavior: banner `AspectRatio(16/9)` ปรับตามความกว้างจอเสมอ (เหมือนทุก `AspectRatio` ในโปรเจกต์) — ไม่มี layout พิเศษสำหรับจอกว้าง

Accessibility: `_buildStoreInfoSection` ครอบด้วย `Semantics` label รวม (เช่น "ข้อมูลร้านค้า: ที่อยู่ ..., เบอร์ติดต่อ ..., เวลาทำการ ...") ต่อ field ที่มีจริงเท่านั้น — banner image ไม่ใช่ข้อมูลเชิงความหมาย (decorative) จึงไม่ต้องมี label แยก (เหมือน `club_page.dart`'s cover image ที่ไม่มี label เช่นกัน)

Design Rules: **ห้ามแก้ `_buildProductsTab`/`_buildReviewsTab`/`TabBar`/AppBar actions ใด ๆ เลย** — ขอบเขต SELLER-004 จำกัดเฉพาะ 2 จุดแทรกที่ระบุไว้ข้างต้นเท่านั้น เพื่อลดความเสี่ยง regression ต่อ test suite เดิมของ ZOKY-001 ให้น้อยที่สุด

Handoff: แก้ `app/lib/features/zoky/data/store.dart`'s `Store`/`Store.fromMap` เพิ่ม 3 ฟิลด์ (`address`/`contactPhone`/`businessHours`, ทั้งหมด `String?`, parse จาก `map['address']`/`map['contact_phone']`/`map['business_hours']`) — **ไม่ต้องแก้ query ใด ๆ ใน `ZokyRepository`** (ทุกจุด `.select()` แบบ wildcard อยู่แล้วตาม Product spec ข้อ 7)

---

## Data Model (แก้ไข — 2 ไฟล์)

- `app/lib/features/zoky/data/store.dart` — เพิ่ม `final String? address;`, `final String? contactPhone;`, `final String? businessHours;` เข้า `Store` class + `Store.fromMap` (ไม่กระทบ `productCount`/`Store.fromMap`'s named-parameter signature เดิม — เป็นการเพิ่มฟิลด์เท่านั้น)
- `seller_app/lib/features/store/data/store.dart` — เพิ่ม 3 ฟิลด์เดียวกัน (ไม่มี `productCount` เหมือนเดิม ตาม SELLER-001's การตัดสินใจเดิม) — ใช้สำหรับ pre-fill `SellerStoreScreen`'s ฟอร์มและเป็น return type ของ `updateStoreInfo`/`onStoreUpdated`

---

## Responsive Behavior (ภาพรวม)

ทุกหน้าจอ/การแก้ไขของ SELLER-004 เป็น mobile-first คอลัมน์เดียวเต็มความกว้างจอ ไม่มี layout พิเศษสำหรับแท็บเล็ต/แนวนอนในรอบนี้ (สอดคล้องกับทุก task ก่อนหน้า) รองรับ dynamic type ผ่าน `Theme.of(context).textTheme` ที่ใช้อยู่แล้วทั้งโปรเจกต์

## Accessibility (ภาพรวม)

- Contrast ratio ตาม design-principles.md เดิม (AA ขั้นต่ำ)
- เพิ่ม `Semantics` label ให้ banner/logo picker ใน `SellerStoreScreen` (ช่องว่างที่สืบทอดจาก `EditClubInfoScreen` เดิม — แนะนำให้ปิดในจุดใหม่นี้ ไม่ mirror gap)
- `_buildStoreInfoSection` มี `Semantics` label รวมต่อ field ที่ render จริง ไม่สื่อสารข้อมูลด้วย icon เปล่า ๆ (icon+text คู่กันเสมอ)

## เตือน Coding (จาก Product spec's Risks — ย้ำจุดที่กระทบ UI/UX โดยตรง)

1. **`onStoreUpdated` ต้องต่อสายให้ `_store` ใน `SellerHomeShell` เป็น mutable state จริง และทุก tab ต้องอ้าง `_store` ไม่ใช่ `widget.store`** — เตือนซ้ำจาก Product spec's Risks เพราะเป็น interaction pattern ใหม่ที่ SELLER-001/002/003 ไม่เคยมี (ไม่เคยมี tab ไหนแก้ข้อมูลที่ tab อื่นแสดงผลมาก่อน) — QA ต้องทดสอบ "แก้ชื่อร้านแล้วสลับไป Dashboard โดยไม่ปิดแอป" เป็นเคสเฉพาะ
2. **`SellerStoreScreen` ห้าม `Navigator.pop()` หลังบันทึกสำเร็จ** — ต่างจาก `EditClubInfoScreen` ที่ pop เพราะเป็น pushed route คนละบริบท mount กัน
3. **`StoreScreen` ฝั่งลูกค้า: banner ต้องไม่กิน element tree ว่างเปล่าเมื่อ `bannerUrl == null`** — ใช้ `if` ใน children list ไม่ใช่ `SizedBox.shrink()`/`Visibility` เพื่อให้ผลลัพธ์เหมือนเดิมเป๊ะกับ regression suite เดิมของ ZOKY-001 (ร้าน seed เดิมทั้งหมดไม่มี banner)
4. **`store-media` bucket ต้องเป็น public + storage policy join กลับ `stores.owner_id`** เหมือน `product-images` เป๊ะ (ไม่ใช่ private+signed-URL แบบ `club-media`) — ตรงตามที่ Product spec ข้อ 6 ระบุไว้ และเป็นเหตุผลที่ Design เลือก `updateStoreInfo` เป็นเมธอดเดียวแทนสามเมธอดแยก
5. **ไม่มีการเพิ่ม RLS policy ใหม่ให้ `stores`** — policy update เดิมจาก SELLER-001 ครอบคลุมคอลัมน์ใหม่ทั้งหมดโดยอัตโนมัติแล้ว (ดู Product spec ข้อ 5) — Design ไม่ต้องออกแบบ UI ใด ๆ เพิ่มเติมสำหรับเรื่องนี้ แต่เตือน Coding ไว้เผื่อ over-engineer โดยไม่จำเป็น
6. เขียน/รัน regression test ครอบคลุม: `StoreScreen`'s test suite เดิมของ ZOKY-001 ครบทุกเคส (โดยเฉพาะเคสร้านไม่มี banner/address/contact/hours), 4 tab อื่นของ `SellerHomeShell` ยังทำงานปกติหลังเปลี่ยน `widget.store` → `_store`, seller A แก้ข้อมูลร้าน B ไม่ได้ (RLS เดิม + storage policy ใหม่)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement: (1) `SellerStoreScreen` ใหม่ (banner/logo picker มิเรอร์ `EditClubInfoScreen` เป๊ะ + ฟอร์ม 7 ฟิลด์ + ปุ่มบันทึกไม่ pop) (2) `SellerHomeShell` แก้เป็น mutable `_store` state + ต่อสาย `onStoreUpdated` ให้ทุก tab (3) `StoreScreen` ฝั่งลูกค้า แทรก banner (edge-to-edge, conditional) + "ข้อมูลร้านค้า" section (conditional ต่อฟิลด์) ตามตำแหน่งที่ระบุไว้แม่นยำข้างต้น (4) `Store` model ทั้ง 2 ไฟล์เพิ่ม 3 ฟิลด์ (5) `SellerRepository.updateStoreInfo` เมธอดใหม่ตาม signature ที่ระบุไว้ — ดู Product spec `.wyn/tasks/backlog/SELLER-004-store-management.md` สำหรับ Database (`address`/`contact_phone`/`business_hours` columns + `store-media` bucket/storage policy)/Acceptance Criteria/Risks ฉบับเต็ม — เมื่อ Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น %
