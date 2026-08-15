# Design Spec — SELLER-005: Finance (Gross/Fee/Net/Balance/Transaction History/Payout)

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue seed `0xFF2D6CDF` + White + Soft Gray, ห้าม Liquid Glass, Touch target ≥44px, ห้ามสื่อสารสถานะด้วยสีอย่างเดียว, AA contrast ขั้นต่ำ)
อ้างอิง Product Spec: `.wyn/tasks/backlog/SELLER-005-finance.md`
อ้างอิง Design เดิมที่ reuse pattern: `.wyn/docs/design/seller-001-foundation.md` (`SellerDashboardScreen`'s ยอดขาย card/`_summaryRow`, `SellerHomeShell` tab เดิม), `.wyn/docs/design/seller-003-order-management.md` (`OrderStatusBadge` 8 สถานะ, `SellerOrderListTile`/`SellerOrderListScreen`'s pagination+error pattern, `SellerOrderDetailScreen`'s confirm dialog/`_summaryRow` emphasize pattern)

**หมายเหตุสี**: เอกสารนี้ใช้ Design system ที่ **implement จริงอยู่ตอนนี้เท่านั้น** — Blue seed `0xFF2D6CDF`, Material 3 default color roles. `.wyn/docs/design/ds-001-color-system.md` (Cyan/Orange) เป็นสเปกที่ Founder อนุมัติทิศทางแล้วแต่**ยังไม่ถูก apply เข้าโค้ดจริง** — งานนี้จึงไม่ใช้สีจากเอกสารนั้นเลย เพื่อไม่ให้ SELLER-005 กลายเป็นจุดแรกที่สีไม่สอดคล้องกับหน้าจอ ZOKY Sellers อื่นทั้งหมดที่ผ่าน QA แล้ว (เมื่อ DS-001 rollout จริงในอนาคต หน้านี้จะถูกอัปเดตพร้อมหน้าจออื่นทั้งหมดเป็นชุดเดียวกัน)

## ทิศทางภาพรวม

งานนี้**ไม่มีทิศทาง visual ใหม่เลย** — ประกอบจาก pattern ที่พิสูจน์แล้วครบทุกชิ้น: การ์ดโค้งมน+`_summaryRow` (`SellerDashboardScreen`), infinite-scroll list + pull-to-refresh + error/retry (`SellerOrderListScreen`), `OrderStatusBadge` (`SELLER-003`), confirm/explain dialog (`SellerOrderDetailScreen`) ตามที่ Product spec เน้นย้ำเองว่า **"เน้น Design ให้ความสำคัญกับข้อความกำกับมากกว่าการจัดวาง UI สวยงาม"** เพราะความเสี่ยงหลักของ task นี้คือ**การสื่อสาร ไม่ใช่ layout**

**การตัดสินใจสำคัญที่ Product spec ทิ้งไว้ให้ Design ตัดสินใจ:**

1. **โครงหน้าจอเป็น `ListView` เดียว (ไม่ใช่ `CustomScrollView`/Sliver)** รวม summary cards (Balance/Breakdown/In-transit/Fee rate) กับ Transaction History แบบ pagination ไว้ในสโครลเดียวกัน — การ์ดสรุปเป็น item แรกคงที่ (index 0) ตามด้วยแถวธุรกรรม ใช้ scroll-listener pattern เดียวกับ `SellerOrderListScreen._onScroll` เป๊ะ (เช็ค `pixels > maxScrollExtent - 300` แล้วโหลดหน้าถัดไป) เหตุผล: ทุกตัวเลขในหน้านี้ต้อง "โหลดสดพร้อมกัน/pull-to-refresh พร้อมกัน" (AC ข้อ Balance) การแยกเป็น 2 scroll area อิสระจะทำให้ refresh ไม่พร้อมกันและเพิ่มความซับซ้อนโดยไม่มีประโยชน์ที่ AC ต้องการ
2. **Error state ของทั้งหน้าใช้ explicit "ลองใหม่" (มิเรอร์ `SellerOrderListScreen`) ไม่ใช่ silent-fail แบบ `SellerDashboardScreen` เดิม** — Dashboard เดิมยอมให้ query พังแล้วโชว์แค่ข้อความเฉย ๆ เพราะเป็นข้อมูลเสริม แต่ Finance คือข้อมูลการเงินที่ seller ต้องเชื่อถือได้ 100% การให้ retry ชัดเจนสำคัญกว่าความเรียบง่ายของ Dashboard เดิม (ตรงตามที่ Product spec เตือนเรื่อง trust risk)
3. **ปุ่ม "ถอนเงิน" เป็นปุ่มที่มี*หน้าตา*ปิดใช้งาน แต่*ไม่ใช่*ปุ่ม Flutter `disabled` จริง (`onPressed: null`)** — ปุ่ม `onPressed: null` ของ Flutter จะไม่ตอบสนอง touch/ไม่มี ripple/screen reader ประกาศว่า "ปิดใช้งาน" ทันที ซึ่งขัดกับ AC ที่บังคับว่า "แตะปุ่มที่ disable แล้ว...ต้องแสดงคำอธิบายชัดเจน" — ดังนั้นปุ่มนี้ต้องมี `onPressed` ที่ใช้งานได้จริงเสมอ (เปิด bottom sheet อธิบาย) แต่ใช้ **สไตล์สีเทา/muted + ไอคอนกุญแจ** ให้ *ดู* เหมือนใช้ไม่ได้ (ไม่ใช้สี primary) — ไม่มี flow การถอนเงินจริงใด ๆ ถูก trigger ไม่ว่ากรณีใด ตรงตาม Product spec ("กดไม่ได้จริง ไม่ทำอะไรเลย" หมายถึงไม่มีการถอนเงินเกิดขึ้นจริง ไม่ใช่ตัว widget ต้องเป็น literal-disabled)
4. **คำว่า "ยอดคงเหลือ"/Balance ปรากฏแค่จุดเดียวในหน้าจอ (Balance card เท่านั้น)** พร้อม disclaimer แบบถาวรติดกับตัวเลขเสมอ — การ์ด "สรุปยอดขาย" ช่วง "ทั้งหมด" แม้จะมีค่า Net Revenue เท่ากับ Balance ทางคณิตศาสตร์ แต่**ใช้คำว่า "สุทธิ (Net Revenue)" ไม่ใช่ "ยอดคงเหลือ"** เพื่อไม่ให้ต้องแปะ disclaimer เต็มซ้ำ ๆ หลายจุดจนหน้าจอรก (Product spec ต้องการ "ทุกจุดที่แสดง Balance" มี disclaimer — การลดจำนวนจุดที่เรียกว่า "Balance" เหลือจุดเดียวคือวิธีที่ตรงไปตรงมาที่สุดที่ทำได้ครบ 100% โดยไม่กระทบการอ่านง่ายของการ์ดอื่น) — Balance card ใช้คำว่า "ยอดคงเหลือสะสม" เป็นคำเดียวที่สื่อความหมายนี้ในทั้งหน้าจอ
5. **ตัวเลือกช่วงเวลา (วันนี้/เดือนนี้/ทั้งหมด) ใช้ `SegmentedButton` แทนตาราง 3×3** — 9 ตัวเลข (3 ช่วง × Gross/Fee/Net) ถ้าแสดงพร้อมกันทั้งหมดจะแน่นเกินไปบนจอมือถือและขัดกับหลัก "เน้นข้อความกำกับมากกว่า UI" — ให้เลือกช่วงเวลาก่อนแล้วเห็น breakdown 3 บรรทัดของช่วงนั้น ค่าเริ่มต้นเลือก "วันนี้" (ลำดับเดียวกับที่ Dashboard เดิมแสดงเป็นแถวแรก)
6. **แถวค่าธรรมเนียม (ZOKY Fee) ใช้สีเทากลาง (`colorScheme.onSurfaceVariant`) ไม่ใช่สีแดง/error** — เหตุผลเดียวกับที่ SELLER-003 เลือกให้ปุ่ม "ทำเครื่องหมายคืนเงินแล้ว" เป็นโทนกลาง: ค่าธรรมเนียมเป็นรายการบัญชีปกติ ไม่ใช่ข้อผิดพลาด การใช้สีแดงจะสื่อความหมายผิดว่ามีบางอย่างเสียหาย — ใส่เครื่องหมาย "−" นำหน้าตัวเลขเพื่อสื่อว่าเป็นรายการที่ถูกหักออก (ไม่ใช้สีอย่างเดียวสื่อความหมาย)
7. **`SellerTransactionTile` ไม่มี thumbnail รูปสินค้า** (ต่างจาก `SellerOrderListTile`) และ**ไม่ query `order_items` เลย** — เพราะ Requirements ข้อ 4 ต้องการแค่ระดับ order (วันที่/ผู้ซื้อ/subtotal/fee/net/สถานะ) ไม่ต้องมีรายการสินค้าในแถวนี้ (ดูรายละเอียดสินค้าได้จากการแตะเข้า `SellerOrderDetailScreen` อยู่แล้ว) — การตัดรูปภาพ+การ query ที่ไม่จำเป็นออกทำให้หน้าจอที่เน้น "ตัวเลขต้องแม่นยำ/อ่านง่าย" โฟกัสกับตัวเลขมากขึ้น และลด query ต่อแถว (N+1) ที่ `SellerOrderListScreen` มีอยู่แล้วจากงานนี้ไปได้ทั้งหมด
8. **แต่ละแถว Transaction History แสดงสูตร "ยอดขาย − ค่าธรรมเนียม = สุทธิ" เป็นบรรทัดเดียว** (เช่น `฿1,000.00 − ฿100.00 = ฿900.00`) แทนการแยก 3 บรรทัด — ทั้งประหยัดพื้นที่แนวตั้งของ list และ**ตอกย้ำความโปร่งใสของสูตรคำนวณให้ seller เห็นทุกครั้งที่เลื่อนดูประวัติ** ตรงตามเจตนา Requirements ข้อ 1 ที่ต้องการให้สูตร cross-check ได้ชัดเจน — สำหรับแถว `refunded` ทั้งบรรทัดสูตรถูกขีดทับ (`TextDecoration.lineThrough`) + สีเทา และมีบรรทัดคำอธิบายเพิ่ม "คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ" กำกับเสมอ (ไม่ใช่สีอย่างเดียว มีข้อความชัดเจนด้วย)
9. **`order.id` (UUID) ไม่มีเลข order ที่มนุษย์อ่านง่าย** (schema ไม่มีคอลัมน์ `order_number` และ SELLER-005 ตัดสินใจแล้วว่าไม่เพิ่มคอลัมน์ใหม่) — ใช้ 8 ตัวอักษรแรกของ UUID พิมพ์ใหญ่เป็น reference ย่อ (`#{id.substring(0,8).toUpperCase()}`) ไม่ใช่การเพิ่ม schema ใหม่ แค่การ format ค่าที่มีอยู่แล้วฝั่ง client

---

## ภาพรวม: reuse pattern อะไรจากที่ไหน

| Component ใหม่ | มิเรอร์จาก |
|---|---|
| `SellerFinanceScreen`'s การ์ด "สรุปยอดขาย" (Gross/Fee/Net) | `SellerDashboardScreen`'s ยอดขาย Card + `_summaryRow` — เพิ่ม `SegmentedButton` เลือกช่วงเวลาและ Fee/Net 2 แถวใหม่ |
| `SellerFinanceScreen`'s Balance card + Payout button + explain bottom sheet | โครงการ์ดเดิม + `SellerOrderDetailScreen._confirmDialog`'s `AlertDialog` โครง (ปรับเป็น info-only ไม่มีปุ่ม "ยืนยัน" ที่ trigger อะไร) |
| `SellerFinanceScreen`'s Transaction History list (pagination/error/empty) | `SellerOrderListScreen`'s `_onScroll`/`_loadInitial`/`_loadMore`/error-retry pattern เป๊ะ (ตัด filter chip ออก เพราะมีแค่ 2 สถานะคงที่) |
| `SellerTransactionTile` | `SellerOrderListTile` (ทรง `Semantics`+`InkWell`+`Row`) — ตัด thumbnail ออก, สลับเนื้อหาเป็นสูตรคำนวณ |
| Empty state "ยังไม่มีประวัติรายรับ" | `SearchStateMessage` (ใช้ซ้ำ, ไม่เขียนใหม่) |
| Status badge ในแถว Transaction History | `OrderStatusBadge` เดิม (ไม่แก้ ไม่เพิ่มสถานะใหม่ ใช้แค่ 2 ค่าที่มีอยู่แล้ว: `delivered`/`refunded`) |
| `fetchPlatformFeePercent()` | `ZokyRepository.fetchMarketplaceFeePercent()` (`app/`) — duplicate เข้า `SellerRepository` ตาม pattern เดิม |

---

## Screen: `SellerFinanceScreen` (ใหม่ — แทนที่ tab "การเงิน" index 4 ของ `SellerHomeShell`)

Purpose: ให้ seller เห็นสรุปรายได้/ค่าธรรมเนียม/ยอดสุทธิ แยกตามช่วงเวลา + ยอดคงเหลือสะสม + ประวัติธุรกรรมย้อนหลังทีละคำสั่งซื้อ ตรวจสอบได้ว่าทำไมตัวเลขเปลี่ยน (โดยเฉพาะกรณี refund) — ทั้งหมดเป็น **read-only, คำนวณสดทุกครั้ง**

User Flow:
1. เปิด tab "การเงิน" (ครั้งแรกหรือสลับกลับมา) → โหลดพร้อมกัน: finance breakdown (3 ช่วงเวลา) + รายได้ระหว่างทาง + อัตราค่าธรรมเนียมปัจจุบัน + หน้าแรกของ Transaction History → แสดงผลรวมเป็นหน้าจอเดียว
2. แตะ `SegmentedButton` เปลี่ยนช่วงเวลา (วันนี้/เดือนนี้/ทั้งหมด) ในการ์ด "สรุปยอดขาย" → สลับตัวเลข 3 แถว (Gross/Fee/Net) ทันที (state ฝั่ง client ล้วน ไม่ query ใหม่ เพราะ 3 ช่วงถูกโหลดมาพร้อมกันตั้งแต่ต้นแล้ว)
3. แตะปุ่ม "ถอนเงิน" (มองดูเหมือนปิดใช้งาน) → เปิด bottom sheet อธิบายเหตุผลที่ยังใช้ไม่ได้ → แตะ "เข้าใจแล้ว" ปิด — ไม่มีการถอนเงินเกิดขึ้นจริง
4. เลื่อนลงมาถึง Transaction History → เห็นรายการ `delivered`/`refunded` เรียงใหม่สุดก่อน → เลื่อนใกล้ท้ายลิสต์ → โหลดหน้าถัดไปอัตโนมัติ (infinite scroll)
5. แตะแถว transaction → เปิด `SellerOrderDetailScreen(orderId: ...)` เดิมจาก SELLER-003 ตรง ๆ → กลับมาหน้า Finance (ไม่ reload อัตโนมัติ เพราะหน้านี้เป็น read-only ล้วน ไม่มีทางที่การเปิดดู detail จะเปลี่ยนสถานะ order ได้ — ต่างจาก `SellerOrderListScreen` ที่ reload เสมอเพราะหน้านั้นมีปุ่มเปลี่ยนสถานะ)
6. Pull-to-refresh (ที่จุดใดก็ได้ในลิสต์เดียวกัน) → โหลดใหม่ทั้งหมด (breakdown + in-transit + fee rate + reset Transaction History กลับหน้าแรก)

Components (บนลงล่าง ภายใน `ListView` เดียว):

- `AppBar(title: Text('การเงิน'))` — ไม่มีปุ่มย้อนกลับ (tab ไม่ใช่ pushed route)
- **Balance Card** (เด่นที่สุด, วางบนสุด): `Card` (อาจใช้ `color: colorScheme.primaryContainer` เพื่อให้เด่นกว่าการ์ดอื่น — ยังอยู่ใน role มาตรฐานของ ColorScheme ไม่ใช่สีใหม่)
  - Header row: `Icon(Icons.account_balance_wallet_outlined)` + "ยอดคงเหลือสะสม"
  - ตัวเลขใหญ่: `thaiBahtLabel(balance)` (`headlineMedium`, bold)
  - **ข้อความกำกับถาวร** (bodySmall, แสดงเสมอ ไม่ใช่ tooltip/dismiss ได้): *"ยอดนี้เป็นตัวเลขคำนวณจากคำสั่งซื้อที่ลูกค้าได้รับสินค้าแล้วเท่านั้น ไม่ใช่เงินในบัญชีธนาคารจริง เนื่องจากยังไม่มีระบบชำระเงิน/โอนเงินเชื่อมต่อ"* (คำต่อคำตาม Product spec ข้อ 5 — **ห้ามเปลี่ยนคำ**)
  - ปุ่ม "ถอนเงิน": `OutlinedButton.icon(icon: Icons.lock_outline, label: Text('ถอนเงิน'))` เต็มความกว้างการ์ด, สไตล์ `foregroundColor`/`side` ใช้ `colorScheme.outline` (สีเทากลาง ไม่ใช้ `colorScheme.primary`) ให้ดู "ไม่พร้อมใช้งาน" ด้วยตา — `onPressed` เรียก `_showPayoutInfo()` เสมอ (ไม่ใช่ `null`)
- **การ์ด "สรุปยอดขาย"**:
  - Header: "สรุปยอดขาย" (`titleMedium`)
  - `SegmentedButton<_FinancePeriod>` 3 ตัวเลือก: "วันนี้" / "เดือนนี้" / "ทั้งหมด" (ค่าเริ่มต้น: วันนี้)
  - 3 แถว (มิเรอร์ `_summaryRow` แต่เพิ่ม emphasize ใน Net row ตาม `SellerOrderDetailScreen._summaryRow(..., emphasize: true)`):
    - "ยอดขาย (Gross Sales)" → `thaiBahtLabel(gross)`
    - "ค่าธรรมเนียม ZOKY" → `− ${thaiBahtLabel(fee)}` สีเทา `colorScheme.onSurfaceVariant`
    - "สุทธิ (Net Revenue)" → `thaiBahtLabel(net)` ตัวหนา สี `colorScheme.primary`
  - Caption เล็กท้ายการ์ด: "ยอดขาย (Gross Sales) ตรงกับยอดขายในหน้าแดชบอร์ด" (ตอกย้ำ AC ข้อ "ตัวเลขต้องตรงกับ Dashboard" ให้ seller มั่นใจว่าไม่ใช่ตัวเลขคนละชุด)
- **การ์ด "รายได้ระหว่างทาง"** (สไตล์กลาง ๆ ไม่ tint เหมือน Balance card — ตั้งใจให้ดู "เป็นกลาง ยังไม่นับ" ต่างจาก Balance ที่ "นับแล้ว"):
  - Header: `Icon(Icons.local_shipping_outlined)` + "รายได้ระหว่างทาง (รอผู้ซื้อยืนยันรับสินค้า)"
  - `thaiBahtLabel(inTransitSubtotal)` + " จาก {count} คำสั่งซื้อ"
  - Caption: "ยอดนี้ยังไม่ถูกนับรวมในยอดคงเหลือ จนกว่าลูกค้าจะยืนยันได้รับสินค้า" — ถ้า `count == 0` แสดงข้อความ "ไม่มีคำสั่งซื้อที่กำลังจัดส่งอยู่ในขณะนี้" แทนเลข ฿0 (เพื่อไม่ชวนสับสนกับ 0 ที่มีความหมายว่า "ยังไม่คำนวณ" — ในที่นี้ ฿0 มีความหมายจริง แต่ข้อความบรรยายชัดเจนกว่าตัวเลขเปล่า ๆ เมื่อไม่มีข้อมูลเลย)
- **บรรทัดอัตราค่าธรรมเนียม** (ไม่ใช่การ์ด แค่ข้อความเล็ก ๆ ใต้การ์ดด้านบน): "ค่าธรรมเนียมแพลตฟอร์มปัจจุบัน: {feePercent}%" (`bodySmall`) + บรรทัดถัดไป (`bodySmall`, สีเทา) *"อัตรานี้ใช้กับคำสั่งซื้อใหม่เท่านั้น ไม่กระทบยอดของคำสั่งซื้อเก่าที่บันทึกอัตราไว้แล้วตอนสั่งซื้อ"* (คำต่อคำตาม Product spec ข้อ 7)
- Section header: "ประวัติรายรับ" (`titleMedium`) + `Divider`
- Transaction rows: `SellerTransactionTile` ทีละแถว, `Divider(height: 1)` คั่น, spinner แถวท้ายเมื่อ `_hasMore`

Interactions:
- `SegmentedButton` เปลี่ยนช่วงเวลา: `setState` เปลี่ยน `_selectedPeriod` เท่านั้น ไม่ query ใหม่ (breakdown ทั้ง 3 ช่วงโหลดมาพร้อมกันตั้งแต่ initial load)
- ปุ่ม "ถอนเงิน": เปิด `showModalBottomSheet` (ดู States/Component ย่อยด้านล่าง) — ไม่มี flow ถอนเงินใด ๆ ถูก trigger ไม่ว่ากรณีใดทั้งสิ้น
- แตะแถว transaction: `Navigator.push` เข้า `SellerOrderDetailScreen(sellerRepository: ..., orderId: order.id)` — ไม่ reload หลังกลับมา (เหตุผลตาม User Flow ข้อ 5)
- Pull-to-refresh: `RefreshIndicator` ครอบ `ListView` ทั้งก้อน → reload finance breakdown + in-transit + fee rate ใหม่ทั้งหมด และรีเซ็ต Transaction History กลับหน้าแรก (page 0)

**Component ย่อย: Payout explanation bottom sheet (`_showPayoutInfo`)** — ไม่ใช่ไฟล์แยก (private method ในสกรีนนี้ มิเรอร์วิธีที่ `SellerOrderDetailScreen._confirmDialog` เป็น private method ในไฟล์เดียวกัน เพราะใช้จุดเดียว ไม่ต้องแยกไฟล์ reusable):
```
showModalBottomSheet(
  context: context,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 32),
          SizedBox(height: 12),
          Text('ยังไม่รองรับการถอนเงิน', style: titleMedium),
          SizedBox(height: 8),
          Text(
            'ยังไม่รองรับการถอนเงินในเวอร์ชันนี้ เนื่องจากยังไม่มีระบบชำระเงิน '
            '(Payment Gateway) เชื่อมต่อกับแพลตฟอร์ม ยอดคงเหลือที่แสดงเป็นตัวเลข'
            'คำนวณเพื่อการติดตามเท่านั้น',
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.pop(context), child: Text('เข้าใจแล้ว')),
          ),
        ],
      ),
    ),
  ),
)
```
ข้อความเป็นคำต่อคำจาก Product spec ข้อ 6 — **ห้ามเปลี่ยนคำ** (นี่คือประโยคที่ AC ตรวจสอบตรง ๆ)

States:
- **Loading (ครั้งแรก)**: ทั้งหน้าจอ `CircularProgressIndicator` กึ่งกลาง (รอ finance breakdown + in-transit + fee rate + หน้าแรกของ transaction history เสร็จพร้อมกันก่อน paint — มิเรอร์ `SellerDashboardScreen`'s single-`FutureBuilder` แต่ยกระดับ error handling ตามข้อ 2 ด้านบน)
- **Error (โหลดครั้งแรกล้มเหลว)**: ข้อความ "โหลดข้อมูลการเงินไม่สำเร็จ" กึ่งกลาง + `TextButton` "ลองใหม่" (มิเรอร์ `SellerOrderListScreen`'s error state เป๊ะ)
- **Loading more (pagination)**: spinner แถวท้ายลิสต์ (มิเรอร์ `SellerOrderListScreen`)
- **Empty Transaction History** (ร้านไม่เคยมี order `delivered`/`refunded` เลย): `SearchStateMessage(icon: Icons.receipt_long_outlined, text: 'ยังไม่มีประวัติรายรับ')` แทนที่ส่วน Transaction rows — **ส่วนการ์ดสรุป (Balance/Breakdown/In-transit/Fee rate) ยังคงแสดงตามปกติด้วยค่าที่คำนวณได้จริง (ทุกอย่างเป็น ฿0 อย่างถูกต้อง ไม่ใช่ placeholder "เร็ว ๆ นี้" แบบ Dashboard เดิม)** — ต่างจาก Dashboard เดิมตรงที่ Dashboard ไม่มี "วิธีคำนวณ" อะไรเลยตอนนั้น (ต้องซ่อนเลข 0 ปลอม) ในขณะที่ Finance **มีสูตรคำนวณจริงเสมอ** ดังนั้น ฿0 ในกรณีนี้คือค่าที่ถูกต้อง ไม่ใช่ placeholder
- **Rows pagination**: `SellerRepository.ordersPageSize` เดิม (20) ใช้ร่วมกัน ไม่สร้างค่าคงที่ใหม่

Responsive Behavior: มือถือ portrait คอลัมน์เดียวเต็มความกว้างจอ (ตาม convention เดิมทั้งโปรเจกต์) — `SegmentedButton` ยืดเต็มความกว้างการ์ด (`showSelectedIcon: false` เพื่อประหยัดพื้นที่ label 3 คำในจอแคบ) รองรับ dynamic type ผ่าน `Theme.of(context).textTheme` เดียวกับทุกจุดในโปรเจกต์

Accessibility:
- ปุ่ม "ถอนเงิน": **ต้องกำหนด `Semantics` label ชัดเจนแทนสถานะ default** เพราะ widget ไม่ใช่ literal-disabled แต่ต้อง*สื่อสาร*ว่าเป็นฟีเจอร์ที่ยังใช้ไม่ได้กับ screen reader — `Semantics(label: 'ปุ่มถอนเงิน ยังไม่พร้อมใช้งานในเวอร์ชันนี้ แตะเพื่อดูรายละเอียด', button: true)` ครอบปุ่ม (ป้องกันไม่ให้ screen reader อ่านแค่ "ถอนเงิน ปุ่ม" เฉย ๆ ซึ่งจะทำให้ผู้ใช้ที่มองไม่เห็นเข้าใจผิดว่ากดแล้วถอนเงินได้จริง — ยิ่งสำคัญกว่าปกติเพราะเป็นเรื่องเงิน)
- แถว refunded ใน Transaction History: label รวมต้องพูดชัดว่า "ไม่นับรวม" ไม่ใช่สื่อผ่านสี/ขีดทับอย่างเดียว (ดู Widget: `SellerTransactionTile` ด้านล่าง)
- ทุกสีที่ใช้เป็น role มาตรฐานของ `ColorScheme` ที่ derive จาก seed `0xFF2D6CDF` เดิม (`primary`/`primaryContainer`/`onSurfaceVariant`/`outline`) — ผ่าน AA อยู่แล้วเพราะเป็น role คู่ที่ Material 3 ออกแบบมาให้ผ่านมาตรฐานนี้เสมอ ไม่มีสีใหม่นอกระบบ
- `SegmentedButton`/ปุ่ม/`TextButton` ทั้งหมดเป็น Material widget default ที่ผ่าน touch target ≥44px อยู่แล้ว

Design Rules:
- ข้อความ disclaimer ทั้งหมด (Balance card, Payout bottom sheet, Fee rate line) เป็น**คำต่อคำจาก Product spec** — ห้าม paraphrase เพราะ AC ตรวจสอบความหมายตรง ๆ
- ห้ามมีจุดไหนในหน้าจอใช้คำว่า "พร้อมถอน"/"เงินในบัญชี" โดยไม่มีคำอธิบายกำกับ (ตรวจสอบทุกจุดที่มีคำว่า "เงิน"/"ยอด" ก่อนส่ง Coding)
- ไม่มี Export/CSV/Payout History ใด ๆ ในหน้าจอนี้ (ยืนยัน scope ตามที่ Product spec defer)
- ไม่แตะ `SellerDashboardScreen`/`SellerOrderListScreen`/`SellerOrderDetailScreen`/`OrderStatusBadge` เดิมเลย (read-only feature ใหม่ทั้งหมด ไม่ regression หน้าจอที่ผ่าน QA แล้ว)

Handoff: `SellerRepository` เมธอดใหม่ (รายละเอียดเต็มใน "Data Model & Repository" ท้ายเอกสาร)

---

## Widget: `SellerTransactionTile` (ใหม่)

Purpose: หนึ่งแถวใน Transaction History ของ `SellerFinanceScreen` — แสดงเฉพาะข้อมูลระดับ order (ไม่มี item/thumbnail)

Components: มิเรอร์โครง `SellerOrderListTile` (`Semantics`+`InkWell`+`Padding`+`Row`) แต่ตัด thumbnail ออก:
- แถวบน: "ผู้ซื้อ: {order.recipientName}" (`titleSmall`, ellipsis) ชิดซ้าย — `OrderStatusBadge(status: order.status)` ชิดขวา (ใช้ค่า `delivered`/`refunded` ที่มีอยู่แล้ว ไม่แก้ widget เดิม)
- แถวกลาง: "#{shortId} · {relativeTimeLabel(order.createdAt)}" (`bodySmall`, สี `colorScheme.outline`) — `shortId = order.id.substring(0, 8).toUpperCase()`
- แถวล่าง (สูตรคำนวณ):
  - `delivered`: `'${thaiBahtLabel(order.subtotal)} − ${thaiBahtLabel(order.feeAmount)} = ${thaiBahtLabel(order.subtotal)}'` — ส่วน `=` ท้ายสุด (Net) ใช้ `fontWeight: FontWeight.bold` + สี `colorScheme.primary`, ส่วนอื่นสีปกติ (`bodySmall`)
  - `refunded`: สูตรเดียวกันทั้งบรรทัด แต่ **ทั้งหมด** ใช้ `TextDecoration.lineThrough` + สี `colorScheme.onSurfaceVariant` (ไม่มีตัวหนา/primary) ตามด้วยบรรทัดใหม่ "คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ" (`bodySmall`, สีเดียวกัน, **ไม่ขีดทับ** เพราะเป็นคำอธิบาย ไม่ใช่ตัวเลขที่ถูกยกเลิก)

Interactions: ทั้งแถวเป็น tap target เดียว (`InkWell`) เปิด `SellerOrderDetailScreen(orderId: order.id)`

States: N/A (stateless, รับ `order` เข้ามาแสดงตรง ๆ — สถานะที่รับได้มีแค่ `delivered`/`refunded` เท่านั้นตามที่ repository กรองมาแล้ว)

Accessibility: `Semantics` label รวม — สำหรับ `delivered`: `'ผู้ซื้อ ${recipientName}, ยอดสุทธิ ${net} บาท, นับรวมในยอดคงเหลือ'` — สำหรับ `refunded`: `'ผู้ซื้อ ${recipientName}, คืนเงินแล้ว, ไม่นับรวมในยอดคงเหลือ'` (พูดตรงคำว่า "ไม่นับรวม" เสมอ ไม่ใช่ปล่อยให้ screen reader อนุมานจาก visual styling)

Handoff: `seller_app/lib/features/finance/presentation/widgets/seller_transaction_tile.dart`

---

## Data Model & Repository (สิ่งที่ต้องเพิ่มใน `SellerRepository`)

**ไม่มีการแก้ไข `Order`/`OrderItem`/`OrderStatus` model เลย** — ฟิลด์ที่มีอยู่แล้ว (`subtotal`/`feePercent`/`feeAmount`/`total`/`status`/`createdAt`/`recipientName`/`id`) ครบพอสำหรับทุกการคำนวณของ SELLER-005 แล้ว ตรงตามที่ Product spec ยืนยันไว้ว่า "ไม่ต้องสร้างตาราง/คอลัมน์ใหม่"

เมธอดใหม่ที่เสนอเพิ่มใน `SellerRepository` (**ไม่แก้เมธอดเดิม** `fetchOrderCounts`/`fetchSalesSummary`/`fetchBestSellingProducts`/`fetchStoreOrders` เลยตามที่ Product spec ข้อ 0 บังคับ) — รูปแบบ return value เป็นข้อเสนอ ให้ Coding ปรับได้ตราบใดที่ความหมายตรงกัน:

1. **`Future<SellerFinanceBreakdown> fetchFinanceBreakdown(String storeId)`** — คืนค่า Gross/Fee/Net แยก 3 ช่วงเวลา มิเรอร์โครง query ของ `fetchSalesSummary` เป๊ะ (select `subtotal, fee_amount, total, created_at` where `store_id` + `status = 'delivered'`, aggregate client-side ตามช่วงวันนี้/เดือนนี้/ทั้งหมดด้วยตรรกะเดียวกับ `fetchSalesSummary` — **ใช้ query เดียวกันได้เลย แค่ select เพิ่ม 2 คอลัมน์**) เสนอ shape:
   ```dart
   class FinancePeriodTotals {
     const FinancePeriodTotals({required this.gross, required this.fee, required this.net});
     final double gross; // sum(total)
     final double fee;   // sum(fee_amount)
     final double net;   // sum(subtotal) -- ต้องเท่ากับ gross - fee เป๊ะ
   }

   class SellerFinanceBreakdown {
     const SellerFinanceBreakdown({required this.today, required this.thisMonth, required this.allTime});
     final FinancePeriodTotals today;
     final FinancePeriodTotals thisMonth;
     final FinancePeriodTotals allTime;
   }
   ```
   **`allTime.net` คือค่า Balance โดยตรง** — หน้าจอไม่ต้อง query แยกอีกเมธอดสำหรับ Balance (ลด query ซ้ำซ้อน)
2. **`Future<(double, int)> fetchInTransitSummary(String storeId)`** — `(sum(subtotal), count)` ของ order `status = 'shipped'` ของร้านตัวเอง (มิเรอร์ tuple-return convention เดิมของ `fetchOrderCounts`)
3. **`Future<List<Order>> fetchTransactionHistory({required String storeId, required int page})`** — order `status in ('delivered', 'refunded')` ของร้านตัวเอง เรียง `created_at desc`, page size ใช้ `SellerRepository.ordersPageSize` เดิม (20) — **เมธอดใหม่แยกจาก `fetchStoreOrders` เดิม ไม่แก้ signature เดิม** ตามที่ Product spec แนะนำ (ลดความเสี่ยง regression บน `SellerOrderListScreen` ที่ผ่าน QA แล้ว) — ไม่ต้อง join/fetch `order_items` เลย (ต่างจาก `SellerOrderListScreen`)
4. **`Future<double> fetchPlatformFeePercent()`** — duplicate ตรงจาก `ZokyRepository.fetchMarketplaceFeePercent()` (`app/lib/features/zoky/data/zoky_repository.dart`): select `platform_config` where `key = 'zoky_marketplace_fee_percent'`, fallback `10` ถ้าไม่พบแถว — ไม่ต้องเพิ่ม RLS ใหม่ (`platform_config` มี select policy ให้ authenticated user ทุกคนอ่านได้อยู่แล้ว)

**หมายเหตุประสานงานสำคัญสำหรับ AI Coding**: เมธอดทั้ง 4 ข้างต้นเพิ่มเข้า `seller_app/lib/features/store/data/seller_repository.dart` — ไฟล์นี้กำลังอยู่ระหว่าง QA รอบ 2 ของ SELLER-004 คู่ขนานอยู่ในขณะที่เอกสารนี้ถูกเขียน AI Coding ที่หยิบงานนี้ไปทำต้อง **sync กับ `main` ล่าสุดก่อนเริ่ม** (รอ SELLER-004 merge ก่อน หรือ merge/rebase ให้ไฟล์ตรงกันเอง) — ไม่ใช่ความรับผิดชอบของ Design ที่จะแก้ conflict นี้เอง

---

## SellerHomeShell (แก้ไขจุดเดิม)

Screen: `SellerHomeShell` — เปลี่ยนเฉพาะ tab index 4

Purpose: เปิดใช้งาน `SellerFinanceScreen` จริงแทน placeholder

Handoff: `seller_app/lib/features/shell/presentation/seller_home_shell.dart` — แก้บรรทัดเดียว: `const SellerComingSoonScreen(label: 'การเงิน')` → `SellerFinanceScreen(store: _store, sellerRepository: widget.sellerRepository)` (มิเรอร์วิธีที่ SELLER-002/003/004 แก้ tab index ของตัวเองทุกประการ) — tab index 0-3 (Dashboard/สินค้า/คำสั่งซื้อ/ร้านค้า) **ไม่แตะ**

---

## Responsive Behavior (ภาพรวม)

ทุกหน้าจอ/widget ใหม่ของ SELLER-005 เป็น mobile-first คอลัมน์เดียวเต็มความกว้างจอ ไม่มี layout พิเศษสำหรับแท็บเล็ต/แนวนอนในรอบนี้ (สอดคล้อง convention ทั้งโปรเจกต์)

## Accessibility (ภาพรวม)

- Contrast ratio ตาม design-principles.md เดิม (AA ขั้นต่ำ) — ทุกสีเป็น role มาตรฐานของ `ColorScheme` ที่ derive จาก seed `0xFF2D6CDF` เดิม
- ไม่มีจุดไหนสื่อสารด้วยสีอย่างเดียว: แถว Fee (สีเทา+เครื่องหมาย "−"), แถว refunded (ขีดทับ+สีเทา+ข้อความ "ไม่นับรวม" ชัดเจน), badge สถานะ (icon+ข้อความอยู่แล้วจาก `OrderStatusBadge`)
- ปุ่ม "ถอนเงิน" มี `Semantics` label อธิบายชัดว่า "ยังไม่พร้อมใช้งาน" ไม่ปล่อยให้ default semantics ของปุ่มที่ดูเหมือนใช้งานได้ทำให้ screen reader user เข้าใจผิด
- ปุ่ม/`SegmentedButton`/`TextButton` ทั้งหมด ≥44px touch target (Material default)

## เตือน Coding (จาก Product spec's Risks — ย้ำจุดที่กระทบ UI/UX โดยตรง)

1. **ข้อความ disclaimer ทั้งหมด (Balance card / Payout bottom sheet / Fee rate line) ต้องตรงคำต่อคำกับ Product spec** — QA จะตรวจสอบข้อความเหล่านี้เป็นพิเศษ (ดู Product spec's Recommendation ข้อ 4b)
2. **`Net = Gross - Fee = sum(subtotal)` ต้องตรงกันทุก edge case**: ไม่มี order เลย (ทุกค่า 0), มีแต่ order `refunded` ทั้งหมด (ไม่กระทบ breakdown เพราะ query กรอง `status = 'delivered'` เท่านั้น breakdown จะเป็น 0 ทั้งหมดถูกต้อง), มีทั้ง `delivered`/`refunded` ปนกัน (breakdown นับเฉพาะ `delivered` — `refunded` โผล่แค่ Transaction History ไม่กระทบตัวเลข breakdown) — เขียน unit test ครอบทั้ง 3 เคสนี้ตรง ๆ
3. **`SellerFinanceScreen` ต้องไม่แก้ไข `SellerRepository`'s เมธอดเดิม 4 ตัวที่ SELLER-001/003 ผ่าน QA แล้วเลย** (`fetchOrderCounts`/`fetchSalesSummary`/`fetchBestSellingProducts`/`fetchStoreOrders`) — เพิ่มเมธอดใหม่แยกเท่านั้น (regression = 0 บนโค้ดที่ QA ผ่านแล้ว)
4. **Gross Sales ของ Finance ต้องตรงกับ Sales/Revenue ของ Dashboard เป๊ะในช่วงเวลาเดียวกัน** — เพราะทั้งคู่ query field เดียวกัน (`sum(orders.total) where status='delivered'`) แค่คนละเมธอด ให้เขียน test เปรียบเทียบผลลัพธ์ของ `fetchSalesSummary` กับ `fetchFinanceBreakdown` กับข้อมูลชุดเดียวกันว่าค่า `gross` เท่ากับ `salesSummary` ทุกช่วงเวลา
5. **ปุ่ม "ถอนเงิน" ห้าม trigger flow ถอนเงินใด ๆ แม้ทางอ้อม** — `onPressed` ต้องเรียก `_showPayoutInfo()` เท่านั้น ไม่มี RPC/repository call ใด ๆ ผูกกับปุ่มนี้เลย เขียน test ยืนยันว่าไม่มี network call เกิดขึ้นเมื่อกดปุ่มนี้
6. **แถว `refunded` ใน Transaction History ต้องมีทั้งสไตล์ visual (ขีดทับ+เทา) และข้อความ "ไม่นับรวมในยอดคงเหลือ" เสมอคู่กัน** — เขียน widget test เช็คทั้งสองอย่าง ไม่ใช่แค่เช็ค style
7. เขียน regression test ครอบคลุม: `SellerDashboardScreen`/`SellerOrderListScreen`/`SellerOrderDetailScreen` เดิมไม่ถูกกระทบ, `SellerTransactionTile` ทั้ง `delivered`/`refunded` ไม่ crash, pagination ของ `fetchTransactionHistory` ทำงานถูกต้อง (page size 20, `_hasMore` คำนวณถูก), RLS/ownership: seller ร้าน A มองไม่เห็นข้อมูล/ประวัติของร้าน B แม้พยายาม query ตรง ๆ (ยืนยันด้วย 2 ร้านจำลองแบบเดียวกับ SELLER-002/003 — ทดสอบผ่าน select policy เดิม ไม่มี policy ใหม่)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement:
1. `SellerRepository` เมธอดใหม่ 4 ตัว (`fetchFinanceBreakdown`/`fetchInTransitSummary`/`fetchTransactionHistory`/`fetchPlatformFeePercent`) + class `FinancePeriodTotals`/`SellerFinanceBreakdown` — **sync กับ `main` ล่าสุดก่อนเริ่มเพราะ SELLER-004 กำลัง QA คู่ขนานไฟล์เดียวกัน**
2. `SellerFinanceScreen` ใหม่ทั้งหมด (`seller_app/lib/features/finance/presentation/seller_finance_screen.dart`) ตาม layout/states/interactions ที่ระบุ
3. `SellerTransactionTile` ใหม่ (`seller_app/lib/features/finance/presentation/widgets/seller_transaction_tile.dart`)
4. `SellerHomeShell`'s tab index 4: `SellerComingSoonScreen` → `SellerFinanceScreen`
5. Widget test: `SellerFinanceScreen` ทุก state (loading/error/empty/มีข้อมูล), `SellerTransactionTile` ทั้ง `delivered`/`refunded`, ปุ่มถอนเงิน (ไม่ trigger network call, เปิด bottom sheet ถูกต้อง, ข้อความตรงคำต่อคำ), cross-check Gross/Fee/Net formula, RLS ownership scenario (2 ร้านจำลอง)

ดู Product spec `.wyn/tasks/backlog/SELLER-005-finance.md` สำหรับสูตรคำนวณเต็ม, Acceptance Criteria, และ Risks ฉบับเต็ม (โดยเฉพาะ trust/legal risk เรื่อง Balance ที่เป็นความเสี่ยงหลักของ task นี้) — เมื่อ Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น % — **เมื่อ SELLER-005 ผ่าน QA แล้ว Phase 4 (ZOKY Sellers by WYN) จะเสร็จสมบูรณ์ครบทั้ง 5 task** ตามที่ Product spec's Recommendation ข้อ 3 แนะนำให้แจ้ง Founder รอการตัดสินใจ Phase 5 ต่อ
