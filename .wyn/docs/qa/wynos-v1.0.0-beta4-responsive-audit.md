# WYNOS v1.0.0 Beta4 — Responsive Audit

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta4-master-implementation-j5lke8` — **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ขอบเขต: Beta4 §14 (Responsive Profile & Beta4 UI), §20 (Responsive QA)
> วิธีตรวจ: widget test ที่ตั้ง `tester.view.physicalSize` จริงและวัดพิกัด/ขนาดจริง ไม่ใช่การอ่านโค้ดแล้วเดา

---

## 0. บริบทที่ต้องตั้งให้ตรงก่อน

**WYNOS ไม่มี breakpoint และ Beta4 ไม่ได้เพิ่ม** — นี่เป็นการตัดสินใจที่บันทึกไว้แล้ว ไม่ใช่งานค้าง

DS-008 (2026-08-16) audit แล้วพบว่า `MediaQuery` ถูกใช้ 5 จุด (ทั้งหมดเป็น `viewInsets`/`textScale` ไม่ใช่ breakpoint) และ `LayoutBuilder` 0 จุด แล้ว **ตัดสินใจอย่างเป็นทางการว่าจะไม่สร้าง responsive layout สำหรับ tablet/desktop** ด้วยเหตุผล 3 ข้อ:

1. WYN ถูกกำหนดเป็น Mobile-first ตั้งแต่ WYN-001 ไม่มีเป้าหมาย tablet/desktop ที่ระบุไว้จริง
2. การออกแบบ breakpoint สำหรับ 45+ หน้าจอเป็นงานระดับ feature ใหม่
3. การเดามาตรฐาน breakpoint เองโดยไม่มี requirement จาก Founder เสี่ยงต้องทำใหม่

**Beta4 เคารพการตัดสินใจนั้น** (§0 ห้าม "เปลี่ยน Product Direction") ดังนั้น "responsive" ในเอกสารนี้จึงหมายถึงสิ่งที่มันหมายถึงมาตลอดสำหรับแอปนี้:

> **layout เดียวที่มีอยู่ ต้องรอดทุกความกว้างและความสูงที่ได้รับ โดยไม่ล้น ไม่ทับกัน ไม่ถูกตัด**

ซึ่งตรงกับรายการห้ามใน §14 พอดี: Overflow / Overlap / Text Collision / Broken Layout / Button Clipping

---

## 1. ขนาดที่ทดสอบ

| ชื่อ | logical px | อุปกรณ์อ้างอิง |
|---|---|---|
| Small Mobile | 320 × 568 | iPhone SE (gen 1) |
| Mobile | 390 × 844 | iPhone 14 / 15 |
| Large Mobile | 430 × 932 | iPhone Pro Max |
| Tablet | 834 × 1112 | iPad Air (portrait) |
| Web | — | ดู §5 |

**ทำไม 320 เป็นตัวชี้ขาด:** เป็นความกว้างที่แคบที่สุดที่ยังต้องรองรับจริง และเป็นที่ที่ layout แนวนอนทุกอันแตกก่อน ส่วน 568 เป็นความสูงที่บีบ layout แนวตั้ง

---

## 2. บั๊กจริงที่พบ — ทั้งหมดถูกพบโดย test ไม่ใช่โดยการอ่านโค้ด

นี่คือประเด็นสำคัญของเอกสารนี้: การเขียน test ตาม §14 หา bug เจอ 3 ตัวที่การ inspect โค้ดไม่เจอ

### R-1 — Profile stats row ล้น 200px ที่ 320px

```
A RenderFlex overflowed by 200 pixels on the right.
Row  view_profile_screen.dart:1098
constraints: BoxConstraints(0.0<=w<=170.0, ...)
```

* **เงื่อนไข:** จอ 320px + ตัวเลข 6 หลัก (123,456 ผู้ติดตาม)
* **สาเหตุ:** stat ทั้งสองใช้ความกว้างตามเนื้อหา + divider margin ข้างละ 16px คอลัมน์ตัวตนข้าง avatar กว้างจริงแค่ 170px
* **แก้:** `Expanded` ทั้งสอง stat · divider margin 16→12 · `FittedBox(scaleDown)` ที่ตัวเลขและป้าย
* **ผลข้างเคียง 0:** `FittedBox(scaleDown)` ย่อเฉพาะเมื่อไม่มีทางพอจริงๆ — ตั้งแต่ 360px ขึ้นไปเป็น no-op และ type ยังเป็นขนาดที่ design system กำหนดเป๊ะ
* **หมายเหตุ:** layout เดิม (3 stat) ก็ล้นเหมือนกันที่ 320px — Beta4 ทำให้แคบลงอีกโดยย้าย stats เข้าคอลัมน์ จึงถือเป็นความรับผิดชอบของ Beta4 ที่จะปิด

### R-2 — Profile header ล้นความสูง 102px ที่ 568px

```
A RenderFlex overflowed by 102 pixels on the bottom.
Column  view_profile_screen.dart:998
```

* **เงื่อนไข:** จอสูง 568px + bio ยาว
* **สาเหตุ:** body คือ `Column([header, TabBar, Expanded(TabBarView)])` — **header ไม่ scroll** สูงเกิน viewport ก็ล้น
* **แก้:** bio จำกัด 4 บรรทัด + ellipsis (bio เพดาน 160 ตัวอักษรอยู่แล้ว จึงพอในเกือบทุกความกว้าง)
* **ทางเลือกที่ไม่เลือก:** `NestedScrollView` ให้ header เลื่อนไปกับเนื้อหา — เปลี่ยนโครงทั้งหน้าจอ §0 ห้าม "Rewrite Architecture โดยไม่มีเหตุผล"

### R-3 — ชื่อ Club ล้น banner ที่ 320px

* **เงื่อนไข:** ชื่อ 50 ตัวอักษร (เพดานของคอลัมน์ `clubs_name_length`) ที่ 22px ในแถบสูง 140px
* **สาเหตุ:** `Text` บรรทัดเดียว ไม่มี `maxLines` ไม่มี `overflow`
* **แก้:** `maxLines: 2` + ellipsis

### R-4 (นอกหมวด responsive แต่พบพร้อมกัน) — touch target 40px

ปุ่ม "ร่าง" ในหัว composer ตั้ง `minimumSize: Size(0, 44)` แต่มี `visualDensity: VisualDensity.compact` ซึ่งลบ 8px ออก → เหลือ 40px ต่ำกว่ามาตรฐานของ design system เอง

**บทเรียน:** `minimumSize` ไม่รับประกันอะไรถ้ามี `visualDensity` อยู่ด้วย — ต้องวัด ไม่ใช่ประกาศ

---

## 3. ผลการทดสอบ

### Profile (§14)

| องค์ประกอบ | 320×568 | ผล |
|---|---|---|
| Profile Header | ✅ | ไม่มี exception หลังแก้ R-1/R-2 |
| Avatar | ✅ | ขนาดคงที่ 80px ไม่ยืดหด |
| Display Name | ✅ | `Flexible` + ellipsis ในตัวสลับบัญชี |
| Username | ✅ | |
| Bio | ✅ | 4 บรรทัด + ellipsis |
| Following / Followers | ✅ | `Expanded` + `FittedBox` |
| Buttons | ✅ | ปุ่มแก้ไขโปรไฟล์อยู่ในขอบจอทั้งซ้ายและขวา (วัดจริง) |
| Posts (แท็บ) | ✅ | 3 แท็บพอดี |
| Navigation | ✅ | bottom nav 5 ปุ่มไม่เปลี่ยน |

**Test:** `view_profile_screen_test.dart` — "Beta4 §14 -- profile header at small-mobile width: no overflow at 320x568, with a long display name and bio" ใช้ display name ยาว + bio 2 บรรทัด + ตัวเลข 6 หลัก พร้อมกัน

### Club (§14)

| หน้า | 320 | 390 | 430 | 834 |
|---|---|---|---|---|
| Club Page | ✅ | ✅ | ✅ | ✅ |
| Create Club | ✅ | ✅ | — | ✅ |

**Test:** `beta4_responsive_test.dart` — 9 test ใช้ชื่อ Club 50 ตัวอักษร + สมาชิก 123,456 คน ในทุกขนาด

รวมถึง test เฉพาะว่า "review summary พอดีที่ 320px พร้อมชื่อ Club ยาว" — วัดว่ากล่องสรุปอยู่ในขอบจอทั้งสองด้าน

### Notifications (§14)

| จุด | ผล |
|---|---|
| Push permission card | ✅ ทดสอบใน `push_permission_card_test.dart` ที่ viewport มาตรฐาน — ปุ่ม 2 อันใน `Row` เดียว มีความกว้างตามเนื้อหา ไม่มี fixed width |
| Notification list | ✅ ไม่เปลี่ยนใน Beta4 |
| ตั้งค่า → การแจ้งเตือน | ⚠️ ดู R-5 |

### R-5 — รายการตั้งค่ายาวขึ้นจนแถวสุดท้ายพ้นจอ 600px

* **อาการ:** `notification_settings_screen_test` ที่มีอยู่เดิม fail — แถว "ระบบ" (สวิตช์ตัวที่ 7) ตกใต้ viewport 800×600 ของ test เพราะ Beta4 เพิ่มแถวสถานะอุปกรณ์ + หัวข้อกลุ่มไว้ด้านบน
* **นี่เป็นบั๊กหรือไม่:** **ไม่** — `ListView` เลื่อนได้ และในแอปจริงคนก็เลื่อนลงไปได้ตามปกติ test เดิมสมมติว่าทุกแถวอยู่บนจอพร้อมกัน ซึ่งไม่จริงตั้งแต่แรกบนโทรศัพท์จริงที่เตี้ยกว่านั้น
* **แก้ที่ test:** `tester.ensureVisible(...)` ก่อนแตะ — ยืนยันพฤติกรรมจริง ไม่ใช่ยืนยันความสูง viewport ที่ไม่มีโทรศัพท์เครื่องไหนมี

---

## 4. Portrait / Landscape

§20 ถามถึง portrait/landscape "หากระบบรองรับ"

**WYNOS ล็อก portrait อยู่แล้ว** — `web/manifest.json` ระบุ `"orientation": "portrait-primary"` และแอปไม่มี landscape layout ใดๆ

Beta4 ไม่เปลี่ยนเรื่องนี้ และไม่ทดสอบ landscape เพราะการรองรับ landscape จะเป็น product direction ใหม่ที่ §0 ห้าม

---

## 5. Web / Tablet — สิ่งที่ต้องพูดตรงๆ

Test ผ่านที่ 834px (tablet portrait) แปลว่า **ไม่มีอะไรพัง ล้น หรือถูกตัด** ที่ความกว้างนั้น

แต่มันไม่ได้แปลว่า *ดูดี* — ที่ 834px และกว้างกว่านั้น layout mobile จะยืดเต็มความกว้าง: การ์ดในฟีดกว้าง 834px, คอลัมน์ตัวตนบนโปรไฟล์กว้างมาก, บรรทัดข้อความยาวเกินระยะที่อ่านสบาย

**Beta4 ไม่แก้เรื่องนี้โดยเจตนา** การใส่ `max-width` กลางจอสำหรับหน้าจอกว้างเป็นการตัดสินใจด้าน product direction (DS-008 เก็บไว้เป็น "คำถามเปิดให้ Founder ตัดสินใจ") ไม่ใช่การแก้บั๊ก

**บันทึกเป็นคำถามเปิด Q-1 ด้านล่าง**

---

## 6. Known Issues / คำถามเปิดถึง Founder

| # | เรื่อง | ความรุนแรง | รายละเอียด |
|---|---|---|---|
| Q-1 | **layout ยืดเต็มความกว้างบน tablet/web** | — (คำถาม product) | ไม่มีอะไรพัง แต่บรรทัดยาวเกินระยะอ่านสบายและการ์ดกว้างผิดสัดส่วน การใส่ `max-width` เป็นการตัดสินใจ product direction ที่ต้องให้ Founder เลือก DS-008 เปิดคำถามนี้ค้างไว้ตั้งแต่ 2026-08-16 และ Beta4 ไม่ตอบแทน |
| K-1 | Profile header ยังไม่ scroll ไปกับเนื้อหา | ต่ำ | ปิดอาการล้นแล้วด้วยการจำกัด bio — แต่บนจอเตี้ยมากพร้อม bio เต็ม 4 บรรทัด แท็บจะถูกดันชิดขอบล่าง `NestedScrollView` เป็น task แยก |
| K-2 | ไม่ได้ทดสอบ text scale ใหญ่ (accessibility font size) | กลาง | §14 ไม่ได้ระบุ แต่เป็นสาเหตุ overflow ที่พบบ่อยพอๆ กับจอแคบ ไม่มีใน scope Beta4 — ควรเป็น audit แยก |
| K-3 | ยังไม่ทดสอบบนอุปกรณ์จริง | — | ทุกผลมาจาก Flutter test binding ที่ตั้ง `physicalSize`/`devicePixelRatio` จริงและวัดพิกัดจริง ซึ่งเป็นกลไก layout ตัวเดียวกับที่รันบนอุปกรณ์ แต่ไม่ครอบคลุมเรื่องที่ต้องดูด้วยตา (ความคมของภาพ, safe area จริงของแต่ละรุ่น, notch) |
| K-4 | หน้าจออื่นนอก Beta4 scope ไม่ได้ตรวจซ้ำ | ต่ำ | Beta4 ตรวจ Profile / Club / Create Club / Notification settings ที่ตัวเองแตะ หน้าที่ไม่ได้แตะ (Search, Chat, ZOKY, Admin) อยู่ในสถานะเดิมของมัน |
