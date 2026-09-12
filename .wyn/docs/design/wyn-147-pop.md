# WYN "Flare" — Pop (V1.0 — PROPOSED)

Status: PROPOSED
Owner: AI Design
อ้างอิง: wyn-142-visual-identity-redesign.md, wyn-143-core-component-library.md

> ⚠️ Flag สำหรับ PM: `wyn-v1.0.0-master-spec.md` ระบุว่า feature Pop **ถูกตัดออกจากขอบเขต V1.0** (Scope V1.0 = Drop + Club + Chat + Discovery เท่านั้น) แต่ยังพบโค้ด/หน้าจอ Pop อยู่จริงในระบบ สเปกนี้ถูกจัดทำไว้ให้ครบตามคำขอ "ออกแบบทุกหน้าจอ" แต่ **ต้องให้ PM ยืนยัน scope อีกครั้งก่อนส่งต่อ AI Coding implement จริง** — อาจเป็น feature เก่าที่รอถอด หรือรอ reactivate ในเวอร์ชันถัดไป

หมายเหตุเพิ่มเติมจากการตรวจ `.wyn/company/DECISIONS.md`: Founder เคยสั่ง **ระงับ (ไม่ใช่ยกเลิก)** การพัฒนาต่อยอด Pop (2026-08-14, WYN-006) เพื่อหันไปทำ WYN CLUB โดย Pop ที่มีอยู่แล้วยังทำงานปกติทุกจุด (โค้ด/route/DB ไม่ถูกแตะต้อง) — สอดคล้องกับ flag ข้างต้นว่า Pop เป็นของเดิมที่รอการตัดสินใจ ไม่ใช่ฟีเจอร์ใหม่ที่ AI Design เพิ่งคิดขึ้น

## หมายเหตุร่วมทุกหน้าจอ (ก่อนอ่านสเปกรายหน้าจอ)

โค้ดปัจจุบันของทั้ง 3 หน้าจอใช้สีตายตัว (`Colors.black`, `Colors.white`, `WynColors.iconLikeActive`, `WynColors.imageScrimStrong`) ที่มาจากทิศทาง visual เดิม (Sapphire) สเปกนี้กำหนดการแปลงเป็น token ของ "Flare" (wyn-142) ดังนี้ ใช้ร่วมกันทั้ง 3 หน้าจอ:

| ของเดิม (hardcode) | แทนที่ด้วย (Flare token) | เหตุผล |
|---|---|---|
| `Colors.black` (scaffold/letterbox พื้นหลังเต็มจอวิดีโอ) | `#17140F` (ค่าเดียวกับ `color.ink` โหมด Light) — ใช้ค่าคงที่นี้เสมอไม่ว่าแอปอยู่โหมด Light/Dark | พื้นที่วิดีโอเต็มจอเป็น "media chrome" ที่ธีมมืดเสมอตาม convention กล้อง/วิดีโอทั่วไป (เหมือน Home ที่ thumbnail ก็มืดอยู่แล้ว) แต่ต้องไม่ใช่ pure `#000000` ตามกติกา "ไม่ใช้ pure black" ใน wyn-142 (Dark mode strategy) |
| `Colors.white` (ข้อความ/ไอคอนทับวิดีโอ) | `color.paper` (`#FFFDF9`) | คงโทนอุ่นของ Flare แทนขาวจั๊วะ ให้เข้ากับ Coral/warm palette |
| `WynColors.iconLikeActive` (หัวใจ active) | `color.heart` (`#F0294B` Light / `#FF5171` Dark) | ตรงตามความหมาย token ใน wyn-142 ที่กำหนด `color.heart` ไว้เฉพาะ Like |
| `WynColors.imageScrimStrong` (gradient เหนือแถบล่าง) | gradient จาก transparent → `rgba(23,20,15,0.85)` (ฐานจาก `color.ink`) | คงหลักการ "พื้นผิวทึบ ไม่ blur" และให้ contrast ข้อความผ่าน AA บนพื้นวิดีโอหลากสี |
| ปุ่ม "ติดตาม" แบบ `OutlinedButton` ขอบขาว ทำเอง | Secondary Button (wyn-143 §1) แต่ปรับสีขอบ/ตัวหนังสือเป็น `color.paper` เพราะอยู่บนพื้นวิดีโอ | คงโครง component เดียวกันทั้งแอป ไม่ประดิษฐ์ปุ่มใหม่ |
| ปุ่ม/ไอคอนลบ (destructive) | ใช้ `color.error` ตอนอยู่ใน Modal ยืนยันลบ (wyn-143 §9) ส่วนไอคอนถังขยะบนวิดีโอยังคงสี `color.paper` (ไม่ใช่ error) จนกว่าจะเปิด Modal | Modal destructive ต้องเป็น error ตามสเปกคอมโพเนนต์ แต่ไอคอนบนวิดีโอเป็นแค่ trigger ไม่ใช่สถานะอันตรายเอง |
| `CircularProgressIndicator` สีธีม default | Spinner สี `color.accent` (wyn-143 §8) ขนาด 32px (full-screen loading) / 20px (inline ในปุ่ม) | ให้ loading state ทุกจุดในแอปใช้สี accent เดียวกัน |
| Comment sheet / Create Pop screen (พื้นหลังขาวปกติ ไม่ใช่วิดีโอ) | ใช้ token ปกติของแอปตามโหมด Light/Dark จริง (`color.paper`/`color.surface`/`color.ink`) — **ไม่ยกเว้นเหมือนพื้นที่วิดีโอ** | สองส่วนนี้เป็น UI ปกติ (bottom sheet, form) ไม่ใช่ media chrome จึงต้องสลับ Light/Dark ตามระบบตามปกติ |

กติกาที่คงไว้ทุกหน้าจอ (จาก wyn-142/143): ห้าม Liquid Glass, touch target ≥44×44px, ไม่สื่อความหมายด้วยสีอย่างเดียว (ทุกไอคอน action มี Semantics label กำกับอยู่แล้วในโค้ด — ต้องคงไว้), 4px spacing grid, Reduce Motion ต้องถูก respect

---

Screen: Pop Feed (`pop_feed_screen.dart`) — "Screen 1" ตาม comment ในโค้ดเดิม
Purpose: หน้าหลักของฟีเจอร์ Pop เป็นฟีดวิดีโอสั้นแนวตั้งแบบเลื่อนทีละคลิปเต็มจอ ให้ผู้ใช้ดูคลิปต่อเนื่อง โต้ตอบ (ถูกใจ/คอมเมนต์/แชร์/บันทึก) และเข้าถึงหน้าสร้าง Pop ใหม่
User Flow:
1. ผู้ใช้เข้าสู่แท็บ Pop → ระบบโหลดค่า mute preference ที่บันทึกไว้ (persist ข้ามเซสชัน) พร้อมโหลดคลิปหน้าแรก (page 0) พร้อมกัน
2. โหลดเสร็จ → แสดงคลิปแรกแบบเต็มจอ เล่นอัตโนมัติ (ตาม mute preference เดิม)
3. ผู้ใช้ปัดขึ้น/ลง (แนวตั้ง) เพื่อเปลี่ยนคลิป — คลิปที่ active เท่านั้นที่เล่นวิดีโอ คลิปที่เลื่อนพ้นจอถูก dispose controller ทันทีเพื่อประหยัดหน่วยความจำ/แบตเตอรี่
4. เมื่อเลื่อนถึงคลิปที่เหลืออีก 2 คลิปสุดท้ายที่โหลดไว้ ระบบดึงหน้าถัดไปอัตโนมัติแบบเงียบ (ไม่มี indicator แทรกกลางฟีด)
5. แตะที่ตัววิดีโอ → สลับเล่น/หยุดชั่วคราว
6. แตะไอคอนหัวใจ → ถูกใจ/เลิกถูกใจทันที (optimistic update, มี haptic feedback) ถ้า request ล้มเหลวย้อนสถานะกลับเงียบ ๆ
7. แตะไอคอนคอมเมนต์ → เปิด Bottom Sheet รายการคอมเมนต์ (พิมพ์/ตอบกลับ/ลบ/ถูกใจคอมเมนต์ได้ในชีตเดียวกัน)
8. แตะไอคอนแชร์ → เปิด share sheet ของระบบปฏิบัติการ / แตะไอคอนลิงก์ → คัดลอกลิงก์คลิปแล้วแจ้งด้วย Toast
9. แตะไอคอน bookmark → บันทึก/เลิกบันทึกทันที (optimistic)
10. แตะปุ่มลำโพง (มุมขวาบน) → mute/unmute ทั้งฟีด ค่าที่ตั้งไว้ถูกจำไว้ใช้ครั้งถัดไป
11. แตะไอคอน "+" (มุมซ้ายบน) → เปิดหน้าสร้าง Pop ใหม่ กลับมาแล้วรีโหลดฟีดใหม่ทั้งหมดถ้าสร้างสำเร็จ
12. แตะรูป/ชื่อผู้เขียน → เปิดโปรไฟล์ผู้เขียน
13. ถ้าไม่ใช่ Pop ของตัวเอง → มีปุ่ม "ติดตาม"/"กำลังติดตาม" ข้างชื่อ (ซ่อนจนกว่าจะรู้สถานะจริงจาก backend)
14. ถ้าเป็น Pop ของตัวเอง → แสดงไอคอนถังขยะแทนปุ่มติดตาม แตะแล้วต้องผ่าน Modal ยืนยันก่อนลบจริง
Components: Media Viewer/Carousel (fullscreen, ไม่มีมุมโค้ง, wyn-143 §11), Avatar 40px (wyn-143 §5, ไม่มี ring เพราะยังไม่มี story/live feature), Secondary Button ขนาดเล็ก (ปุ่ม "ติดตาม", wyn-143 §1), Primary Button (ปุ่ม "สร้าง Pop" ใน Empty State), Empty State (wyn-143 §12), Spinner สี accent (wyn-143 §8), Bottom Sheet (comment sheet, wyn-143 §9) ที่ภายในประกอบด้วย List Item pattern (แถวคอมเมนต์, wyn-143 §10) + Avatar 24px inline + Text Input (ช่องพิมพ์คอมเมนต์) + Text Button (ส่ง/ตอบกลับ/ยกเลิกตอบกลับ), Modal ยืนยันลบ (wyn-143 §9, ปุ่ม destructive `color.error`), Toast (แจ้ง "คัดลอกลิงก์แล้ว", wyn-143 §7)
Interactions:
- ปัดแนวตั้งเปลี่ยนคลิป: native scroll physics ของ `PageView`, ไม่ต้องเพิ่ม motion เทียม
- แตะวิดีโอ: play/pause ทันที ไม่มี feedback visual เพิ่มเติมนอกจากวิดีโอหยุด/เล่น (คงพฤติกรรมเดิม)
- ปุ่มหัวใจ: กดแล้ว icon เด้งสั้น ๆ ด้วย spring ease-out ที่ `motion.fast` (120ms) พร้อม haptic — เคารพ Reduce Motion (ปิด scale animation แต่ยังเปลี่ยนสี/ไอคอนได้ปกติ)
- ปุ่มลำโพง/บันทึก: เปลี่ยนไอคอนทันที ไม่มี animation พิเศษ
- โหลดหน้าถัดไปอัตโนมัติ: เงียบ ไม่มี loading indicator แทรก, ถ้าล้มเหลวก็แค่หยุดโหลดต่อ (ผู้ใช้ปัดกลับได้ตามปกติ ไม่บล็อก)
States:
- **Initial loading**: full-screen ตรงกลางแสดง Spinner สี `color.accent` บนพื้น `#17140F` (รอทั้ง mute preference และคลิปหน้าแรกโหลดเสร็จพร้อมกัน)
- **Error (โหลดครั้งแรกล้มเหลว)**: ข้อความ "โหลด Pop ไม่สำเร็จ" (สี `color.paper`) + ปุ่ม Text Button "ลองใหม่" กลางจอ
- **Empty (ยังไม่มีคลิปในระบบ)**: Empty State — ข้อความ "ยังไม่มีใครโพสต์คลิปเลย เป็นคนแรกสิ!" + Primary Button "สร้าง Pop"
- **Loaded ปกติ**: คลิป active เล่นอัตโนมัติ, คลิปที่เหลือ dispose ไว้
- **Clip init error รายคลิป**: แสดงไอคอน error + "โหลดคลิปไม่สำเร็จ" เฉพาะคลิปนั้น ไม่กระทบคลิปอื่นในฟีด
- **Muted / Unmuted**: ไอคอนลำโพงสลับ ค่าคงอยู่ข้ามคลิปและข้ามเซสชัน
- **Following / Not-following / Unknown**: ปุ่มติดตามซ่อนจนกว่าจะรู้สถานะจริง (ไม่กะพริบเป็น false ชั่วคราว)
- **Own-pop**: ปุ่มติดตามถูกแทนที่ด้วยไอคอนลบ
- **Deleting**: ระหว่างรอผลลบ ไม่มี loading overlay พิเศษ (ตามโค้ดปัจจุบัน) — ถ้าสำเร็จ คลิปหายจากฟีดทันทีพร้อม haptic, ถ้าล้มเหลวแจ้ง Toast/Snackbar "ลบ Pop ไม่สำเร็จ ลองใหม่อีกครั้ง"
Responsive Behavior: วิดีโอเต็มจอด้วย `BoxFit.cover` ทุกอัตราส่วนหน้าจอ (รองรับ notch/Dynamic Island ด้วยการเว้น safe area เฉพาะแถวไอคอนบนสุดและแถว action ล่างสุด ไม่ใช่ตัววิดีโอ); บนจอกว้างผิดปกติ (แท็บเล็ต) แนะนำจำกัดความกว้างวิดีโอไม่เกิน 480px แล้ววางกลางจอ ขนาบด้วยพื้นหลัง `#17140F` ทั้งสองข้างแทนการยืดเต็มความกว้าง (mobile-first ตาม wyn-142); รองรับเฉพาะแนวตั้ง (portrait) เท่านั้นตาม convention เดิม
Accessibility: ทุกปุ่มไอคอน (หัวใจ/บันทึก/ลำโพง/ติดตาม) ต้องมี Semantics label อธิบายทั้งสถานะปัจจุบันและผลของการกด (มีอยู่แล้วในโค้ด ต้องคงไว้เมื่อ restyle) — ห้ามสื่อสถานะด้วยสีอย่างเดียว (หัวใจใช้ทั้งไอคอน filled/outline ต่างกันด้วย ไม่ใช่แค่สี); contrast ข้อความ/ไอคอนสี `color.paper` บน gradient scrim ต้องผ่าน AA ที่ทุกจุดวางข้อความ (ปรับ opacity scrim ตามจุดที่วาง caption/ชื่อผู้เขียน); รองรับ dynamic type สำหรับแคปชันและตัวเลขนับ โดยไม่ทำให้ layout ล้นจอ (คง `maxLines`+ellipsis ตามเดิม); Reduce Motion ปิด animation หัวใจแบบ spring
Design Rules: ห้ามเปลี่ยนโครง interaction row เป็นแนวตั้งชิดขวาแบบ TikTok — คงแถวแนวนอนด้านล่างตามที่ระบุไว้ในเอกสารเดิมของฟีเจอร์นี้ (หลักการ "ไม่ลอกเลย์เอาต์ TikTok/Instagram" ใน wyn-142 ยังบังคับใช้); คลิปที่ไม่ active ต้อง dispose video controller ทันทีเสมอ (performance/battery); ใช้ token ตาม "หมายเหตุร่วมทุกหน้าจอ" ด้านบนทั้งหมด แทนสี hardcode เดิม; Comment sheet ใช้ธีม Light/Dark ปกติของแอป ไม่ใช่ธีมมืดตายตัวแบบพื้นที่วิดีโอ
Handoff: รอ PM ยืนยัน scope Pop ใน V1.0/V-ถัดไปก่อน แล้วรอ Founder ยืนยันเอกสาร wyn-142/wyn-143 อย่างเป็นทางการ จึงส่งต่อ AI Coding แก้ไข `app/lib/features/pop/presentation/pop_feed_screen.dart`, `app/lib/features/pop/presentation/widgets/pop_clip_view.dart`, `app/lib/features/pop/presentation/widgets/pop_comment_sheet.dart`, `app/lib/features/pop/presentation/widgets/confirm_delete_pop_dialog.dart` ให้ใช้ token/คอมโพเนนต์ใหม่ตามสเปกนี้ — เป็นงาน restyle เท่านั้น ห้ามเปลี่ยน user flow/behavior ที่มีอยู่โดยไม่มีคำสั่งเพิ่มเติม

---

Screen: Create Pop (`create_pop_screen.dart`) — "Screen 2" ตาม comment ในโค้ดเดิม
Purpose: หน้าสร้าง Pop ใหม่ ให้ผู้ใช้เลือกหรือถ่ายวิดีโอสั้น (สูงสุด 60 วินาที) ใส่แคปชันแล้วโพสต์เข้าฟีด Pop
User Flow:
1. เปิดจากไอคอน "+" ใน Pop Feed
2. จอแสดงพื้นที่วิดีโอเปล่า (แนวตั้ง 9:16) พร้อมข้อความ "แตะเพื่อเลือกวิดีโอ"
3. แตะพื้นที่วิดีโอ → เปิด Bottom Sheet ตัวเลือก "ถ่ายวิดีโอใหม่" / "เลือกจากคลังวิดีโอ"
4. เลือกแหล่งวิดีโอ → ระบบเปิด picker ของระบบปฏิบัติการ ระหว่างรอ initialize วิดีโอ แสดง Spinner ทับพื้นที่วิดีโอ
5. ถ้าวิดีโอยาวเกิน 60 วินาที → แสดงข้อความ error ใต้พื้นที่วิดีโอ "วิดีโอยาวเกิน 60 วินาที เลือกคลิปสั้นกว่านี้" และไม่เก็บวิดีโอนั้นไว้ (พื้นที่วิดีโอกลับไปสถานะว่าง)
6. ถ้าเลือกวิดีโอไฟล์เสีย/ไม่รองรับ → error "เลือกวิดีโอไม่สำเร็จ ลองใหม่อีกครั้ง"
7. วิดีโอที่ผ่านเงื่อนไข → แสดง preview เล่นวนลูปอัตโนมัติ พร้อมตัวนับความยาว "m:ss / 1:00" ใต้พื้นที่วิดีโอ แตะที่วิดีโอเพื่อ play/pause ระหว่างพรีวิว
8. พิมพ์แคปชันด้านล่าง (สูงสุด 500 ตัวอักษร, รองรับ #hashtag/@mention แบบ plain text ไม่มี autocomplete)
9. แตะปุ่ม "แชร์" (มุมขวาบนของ App Bar) — ปุ่มถูก disable จนกว่าจะเลือกวิดีโอสำเร็จและไม่อยู่ระหว่างโหลด/แชร์
10. ระหว่างแชร์ ปุ่มเปลี่ยนเป็น Spinner ขนาดเล็ก แคปชันถูก disable ชั่วคราว
11. สำเร็จ → haptic feedback สำเร็จ + ปิดหน้าจอกลับไปฟีด Pop (ฟีดรีโหลดอัตโนมัติ)
12. ล้มเหลว → haptic feedback ล้มเหลว + ข้อความ error ใต้แคปชัน "แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง" ผู้ใช้กดแชร์ซ้ำได้โดยไม่ต้องเลือกวิดีโอใหม่
13. แตะไอคอน X (มุมซ้ายบนของ App Bar) ทุกจุด → ปิดหน้าจอทันที (ไม่มี confirm dialog แม้เลือกวิดีโอ/พิมพ์แคปชันไว้แล้ว — คงพฤติกรรมเดิม)
Components: Top App Bar (wyn-143 §3 — ปรับให้ชื่อหน้าจอ "Pop ใหม่" ชิดซ้ายตามสเปก ไม่ centered แบบ Material default เดิม), Text Button (ปุ่ม "แชร์" ที่ขวา App Bar, สถานะ disabled/loading ตาม wyn-143 §1), Media Viewer แบบฝังอยู่ในการ์ด (aspect ratio 9:16, `radius.m` ตอนยังไม่ fullscreen, wyn-143 §11), Bottom Sheet + List Item (ตัวเลือกแหล่งวิดีโอ 2 แถว, wyn-143 §9/§10), Spinner สี accent (โหลดวิดีโอ, wyn-143 §8), Text Input หลายบรรทัด (แคปชัน, wyn-143 §2), Inline error message (ใต้พื้นที่วิดีโอ/ใต้แคปชัน สี `color.error`, wyn-143 §7)
Interactions:
- แตะพื้นที่วิดีโอว่าง: เปิด Bottom Sheet ทันที (ปิดการแตะระหว่างกำลังโหลดวิดีโออยู่ เพื่อกันเปิดซ้อน)
- แตะวิดีโอที่พรีวิวอยู่แล้ว: สลับ play/pause
- ปุ่ม "แชร์": เปลี่ยนจากข้อความเป็น Spinner ทันทีที่กด ไม่มี double-submit (guard ป้องกันแตะซ้ำระหว่างรอ rebuild อยู่แล้วในโค้ด ต้องคงไว้)
- พิมพ์แคปชัน: แสดงตัวนับตัวอักษรตาม `maxLength` มาตรฐานของ Flutter TextField (ไม่ต้องทำ custom counter)
States: ว่างเปล่า (ยังไม่เลือกวิดีโอ), กำลังโหลดวิดีโอ (spinner ทับพื้นที่วิดีโอ), มีวิดีโอ+พรีวิวเล่น/หยุด, error วิดีโอยาวเกิน, error เลือกวิดีโอไม่สำเร็จ, error แชร์ไม่สำเร็จ (คงวิดีโอ+แคปชันไว้ให้ลองใหม่), กำลังแชร์ (ปุ่ม/แคปชัน disabled), สำเร็จ (ปิดหน้าจอ)
Responsive Behavior: พื้นที่วิดีโอกว้างเท่าจอเสมอ (aspect ratio คงที่ 9:16) ส่วนแคปชันอยู่ใต้ในการ์ด scroll ได้เมื่อคีย์บอร์ดเปิด (`SingleChildScrollView` ที่มีอยู่แล้วต้องคงไว้เพื่อไม่ให้คีย์บอร์ดบัง input); บนจอกว้าง/แท็บเล็ต จำกัดความกว้างเนื้อหาทั้งหน้าไม่เกิน 480px กึ่งกลางจอเช่นเดียวกับหน้าฟอร์มอื่นในแอป
Accessibility: พื้นที่วิดีโอมี Semantics label แยกสถานะ "แตะเพื่อเลือกหรือถ่ายวิดีโอ" กับ "วิดีโอที่เลือก" อยู่แล้ว (คงไว้); error message ควรอยู่ใกล้ element ที่เกี่ยวข้องเพื่อให้ screen reader อ่านต่อเนื่อง (ตำแหน่งปัจจุบันใต้พื้นที่วิดีโอ/ใต้แคปชันถูกต้องอยู่แล้ว); ปุ่ม X และปุ่มแชร์ต้องมี touch target ≥44×44px (ปุ่ม X เป็น IconButton มาตรฐานอยู่แล้ว ผ่าน)
Design Rules: ปุ่ม "แชร์" ใช้สี `color.accent` เมื่อ enabled, opacity 40% เมื่อ disabled ตามกติกาปุ่มทั่วไปใน wyn-143 §1; ห้ามเปลี่ยนลิมิต 60 วินาที/500 ตัวอักษรโดยไม่มีคำสั่งจาก PM (เป็น business rule ไม่ใช่ visual); พื้นหลังพื้นที่วิดีโอตอนว่างเปล่าใช้ `color.surface` แทน `Theme.of(context).colorScheme.surfaceContainerHighest` เดิม
Handoff: รอ PM ยืนยัน scope + Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding แก้ไข `app/lib/features/pop/presentation/create_pop_screen.dart` — เป็นงาน restyle เท่านั้น ห้ามเพิ่ม/ตัด validation หรือ flow ที่มีอยู่

---

Screen: Pop Single Clip (`pop_single_clip_screen.dart`)
Purpose: แสดง Pop คลิปเดียวแบบเต็มจอเมื่อผู้ใช้แตะการ์ด Pop จาก Home Feed โดยเฉพาะ (ไม่ใช่จากแท็บ Pop) — ไม่ให้ปัดไปคลิปอื่นต่อ เพื่อไม่ให้ผู้ใช้ที่ตั้งใจดูคลิปเดียวจาก Home ต้องกระโดดเข้ากลางฟีดที่ paginate อยู่ (ตามเหตุผลที่บันทึกไว้ในโค้ดเดิม)
User Flow:
1. ผู้ใช้แตะการ์ด Pop ใน Home Feed (หรือแตะไอคอนคอมเมนต์บนการ์ดนั้นโดยเฉพาะ) → เปิดหน้านี้
2. ระบบโหลดค่า mute preference ก่อนแสดงผล — ระหว่างนั้นแสดง Spinner เต็มจอ
3. โหลดเสร็จ → แสดง `PopClipView` เต็มจอเหมือน Pop Feed ทุกประการ ยกเว้นมุมซ้ายบนเป็นปุ่มย้อนกลับแทนปุ่ม "+"
4. ถ้าเปิดมาจากไอคอนคอมเมนต์บนการ์ดโดยเฉพาะ (ไม่ใช่แตะการ์ดเฉย ๆ) → Bottom Sheet คอมเมนต์เปิดขึ้นอัตโนมัติทันทีหลังจอ build เสร็จ โดยไม่ต้องให้ผู้ใช้แตะไอคอนคอมเมนต์เอง
5. ผู้ใช้โต้ตอบได้ครบทุกอย่างเหมือน Pop Feed (ถูกใจ/คอมเมนต์/แชร์/คัดลอกลิงก์/บันทึก/mute/ติดตาม/ลบถ้าเป็นเจ้าของ) — ไม่มีการปัดเปลี่ยนไปคลิปอื่น
6. ถ้าผู้ใช้ลบ Pop นี้สำเร็จ (เจ้าของ) → หน้าจอปิดตัวเองกลับไป Home ทันทีโดยอัตโนมัติ
7. แตะปุ่มย้อนกลับ (มุมซ้ายบน) → กลับไป Home
Components: เหมือน Pop Feed ทุกคอมโพเนนต์ (Media Viewer fullscreen, interaction row, Bottom Sheet คอมเมนต์, Modal ยืนยันลบ) ยกเว้นปุ่มมุมซ้ายบนเป็นปุ่มย้อนกลับ (icon-only, touch target ≥44×44px) แทนปุ่ม "+"
Interactions: เหมือน Pop Feed ทุกจุด ยกเว้นไม่มี `PageView` ปัดแนวตั้งเปลี่ยนคลิป (คลิปเดียวค้างอยู่ตลอด); การเปิด comment sheet อัตโนมัติ (`openCommentsOnStart`) ใช้ `motion.slow` (320ms) เดียวกับ Bottom Sheet ทั่วไปตาม wyn-142 แม้เปิดแบบอัตโนมัติไม่ใช่จากการแตะของผู้ใช้เอง
States: loading (รอ mute preference โหลด — Spinner สี accent เต็มจอบนพื้น `#17140F`), deleted (หน้าจอว่างชั่วขณะก่อน `Navigator.pop` อัตโนมัติ — ไม่ต้องมี UI พิเศษเพราะเป็นช่วงเปลี่ยนหน้าสั้นมาก), loaded ปกติ (รวมทุก sub-state ของ `PopClipView` ตามที่ระบุใน Pop Feed ด้านบน: clip init error, muted/unmuted, following/unknown/own-pop)
Responsive Behavior: เหมือน Pop Feed ทุกประการ (fullscreen cover, safe area เฉพาะแถวไอคอนบน/ล่าง, จำกัดความกว้างบนแท็บเล็ต, portrait only)
Accessibility: เหมือน Pop Feed ทุกประการ บวกปุ่มย้อนกลับต้องมี tooltip/Semantics "ย้อนกลับ" (มีอยู่แล้วในโค้ด คงไว้); เมื่อ comment sheet เปิดอัตโนมัติ ต้องส่ง focus ไปที่ sheet ให้ screen reader ประกาศการเปลี่ยนหน้าจอทันที ไม่ปล่อยให้ค้างที่โฟกัสเดิมของปุ่มย้อนกลับ
Design Rules: ห้ามเปลี่ยนหลักการ "single clip เท่านั้น ไม่ paginate" — เป็น design rule ที่ตั้งใจไว้ตั้งแต่ต้น (บันทึกเหตุผลไว้ในโค้ดเดิมแล้วว่าไม่ต้องการให้ผู้ใช้ที่มาจาก Home ต้องกระโดดเข้ากลางฟีด); ใช้ token ตาม "หมายเหตุร่วมทุกหน้าจอ" ด้านบนทั้งหมดเหมือน Pop Feed; หน้านี้เป็น thin host รอบ `PopClipView` เดียวกับ Pop Feed จึงต้อง restyle `PopClipView` แค่ครั้งเดียวแล้วมีผลกับทั้งสองหน้าจอโดยอัตโนมัติ ไม่ต้อง duplicate สไตล์
Handoff: รอ PM ยืนยัน scope + Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding แก้ไข `app/lib/features/home/presentation/pop_single_clip_screen.dart` — งาน restyle หลักจริง ๆ อยู่ที่ `PopClipView` ที่ใช้ร่วมกับ Pop Feed (ดู Handoff ของ Pop Feed ด้านบน) ไฟล์นี้แทบไม่มีสไตล์ของตัวเองนอกจาก Spinner ตอนโหลด mute preference
