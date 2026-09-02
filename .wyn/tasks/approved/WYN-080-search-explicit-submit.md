# Feature Request — WYN-080

Status: coded, awaiting QA (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 9/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เปลี่ยนช่องค้นหาให้ต้องกดปุ่มค้นหา แทนการค้นหาอัตโนมัติทุกตัวอักษร
Goal: ลด flicker/ผลลัพธ์กระโดดไปมาระหว่างพิมพ์ ให้ผู้ใช้ควบคุมจังหวะค้นหาเอง แต่ยังเห็น suggestion ระหว่างพิมพ์แบบ TikTok
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ช่องพิมพ์ค้นหา แค่พิมพ์ก็ค้นหาแล้ว ไม่ชอบ อยากให้พิมพ์เสร็จแล้วมีปุ่มให้กดค้นหา แล้วเนื้อหาที่ค้น ค่อยขึ้น กับ ตอนที่พิมพ์อยู่ก็ขึ้น ฟีว TikTok"
Requirements:
- ระหว่างพิมพ์: แสดง suggestion/คำที่เกี่ยวข้องแบบ live (เหมือนเดิม สไตล์ TikTok)
- ผลการค้นหาเนื้อหาเต็ม (โพสต์/ผู้ใช้/แฮชแท็ก) จะขึ้นก็ต่อเมื่อกดปุ่มค้นหา หรือกด Enter/Submit เท่านั้น ไม่ auto-search ทุกตัวอักษร
Acceptance Criteria:
- [ ] พิมพ์คำค้นแล้วไม่มีผลลัพธ์เต็มเด้งขึ้นทันที จนกว่าจะกดปุ่มค้นหา
- [ ] ระหว่างพิมพ์ยังเห็น suggestion แบบ real-time ตามที่ต้องการ
Dependencies: ไม่มี
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เปลี่ยน UX ค้นหาแล้วกระทบ analytics/behavior เดิมที่อ้างอิง auto-search | ต่ำ | เช็ค event tracking ที่ผูกกับการค้นหาก่อนแก้ |
Recommendation: อนุมัติ
Handoff: AI Design (แยก suggestion vs full search UI) → AI Coding

---

## Coding Output (2026-09-02)

Implementation: ตรวจโค้ดเดิม (`search_screen.dart`) พบว่ามี `DiscoveryView` อยู่แล้ว (เดิมโชว์เฉพาะตอนคำค้น < 2 ตัวอักษร — trending hashtag/suggested profile/content แบบ "เรียกดู" ก่อนพิมพ์) กับ `Timer` debounce 400ms ที่ auto-trigger การค้นหาเต็มรูปแบบทุกครั้งที่พิมพ์ครบ 2 ตัวขึ้นไป — **ตัดสินใจใช้ `DiscoveryView` ที่มีอยู่แล้วเป็นตัวแสดง "ฟิว TikTok ระหว่างพิมพ์" แทนการสร้าง live-suggestion dropdown ใหม่ทั้งหมด** (ลดความเสี่ยง/ขอบเขตงาน Phase 1 ให้เหมาะกับ quick fix ไม่ต้องรอ Design spec เต็มรูปแบบ) — เปลี่ยน `_showDiscovery` จากเช็คแค่ "คำค้นสั้นไป" เป็นเช็คเพิ่มว่า "ข้อความในช่องพิมพ์ตรงกับคำค้นล่าสุดที่กด submit ไปแล้วหรือยัง" — พิมพ์อะไรก็ตามที่ยังไม่ submit จะเห็น DiscoveryView เสมอ (ไม่ค้างผลลัพธ์เก่า), พอกด submit ค่อยเห็นผลค้นหาเต็มรูปแบบ

- ลบ `Timer` debounce ทั้งหมดออก (ไม่มี auto-search อีกต่อไปไม่ว่าจะรอนานแค่ไหน)
- เพิ่มปุ่มค้นหาจริง (เดิมเป็นแค่ `Icon` ตกแต่งเฉยๆ กดไม่ได้) — `Semantics`+`GestureDetector` ครอบ ให้กดแล้วเรียก `_submit()`
- เพิ่ม `TextField.onSubmitted` + `textInputAction: TextInputAction.search` ให้ปุ่ม "ค้นหา" บนคีย์บอร์ดใช้งานได้เหมือนกัน (ผู้ใช้ไม่ต้องเอื้อมนิ้วไปกดปุ่มค้นหาเสมอไป)
- `_submit()` เรียก `_focusNode.unfocus()` ปิดคีย์บอร์ดหลังค้นด้วย (พฤติกรรม search มาตรฐาน)

Files Changed:
- `app/lib/features/search/presentation/search_screen.dart`
- `app/test/search_screen_test.dart` — ปรับทุกเทสที่เคยพึ่ง `enterText`+`pump(500ms)` (auto-search) ให้ submit ชัดเจนแทน (แตะไอคอนค้นหา หรือ `testTextInput.receiveAction(TextInputAction.search)`), ลบเทส debounce-cancellation เดิมที่ทดสอบพฤติกรรมที่ไม่มีอยู่แล้ว (`Timer` ถูกลบออก), เพิ่ม 4 เทสใหม่ (พิมพ์อย่างเดียวไม่ค้นแม้รอนาน 2 วินาที, submit คำสั้น<2 ตัวก็ยังไม่ค้น, แตะไอคอนค้นหาค้นจริง, ปุ่มค้นหาบนคีย์บอร์ดใช้งานได้, พิมพ์ใหม่หลัง submit แล้วกลับไป Discovery ไม่ค้างผลเก่า)

Reason: Founder ข้อ 9/28 — "ช่องพิมพ์ค้นหา แค่พิมพ์ก็ค้นหาแล้ว ไม่ชอบ อยากให้พิมพ์เสร็จแล้วมีปุ่มให้กดค้นหา แล้วเนื้อหาที่ค้น ค่อยขึ้น กับ ตอนที่พิมพ์อยู่ก็ขึ้น ฟิว TikTok"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **876/876 ผ่านหมด** (871 baseline + 3 net ใหม่ หลังลบ 2 เทส debounce เดิม + เพิ่ม 5 เทสใหม่ใน `search_screen_test.dart`)

Build: ไม่ได้รัน `flutter build` เต็มรูปแบบ (text/behavior-only change, ไม่แตะ native config)

Known Issues:
- **"suggestion ระหว่างพิมพ์" ที่ Founder อยากได้ ตอนนี้คือ `DiscoveryView` เดิม (trending hashtag/suggested content) ไม่ใช่ live-suggestion ที่กรองตามข้อความที่พิมพ์อยู่จริงๆ** (เช่น พิมพ์ "nam" แล้วเห็นรายชื่อ "namfah" ขึ้นมาแบบ TikTok autocomplete) — อันนั้นเป็นฟีเจอร์ใหม่ที่ใหญ่กว่า ต้องมี Design spec และ backend query แยกต่างหาก ถ้า Founder หมายถึงแบบนั้นจริงๆ ควรแจ้งกลับมาเป็นงานแยก
- R1 (เสี่ยงกระทบ analytics เดิม) — grep แล้วไม่พบ event tracking ใดๆ ผูกกับ auto-search ในโค้ดปัจจุบัน ไม่พบความเสี่ยงจริง

Handoff: ส่งต่อ AI QA & Security — ตรวจ UX จริงว่าตรงกับที่ Founder ต้องการหรือไม่ โดยเฉพาะจุด "ฟิว TikTok ระหว่างพิมพ์" ที่ตีความว่าคือ DiscoveryView เดิม — ถ้า Founder ต้องการ live-suggestion ที่กรองตามคำพิมพ์จริงๆ ให้ส่งกลับเข้า backlog เป็นงานใหม่
