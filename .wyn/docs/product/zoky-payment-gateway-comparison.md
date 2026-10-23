# ZOKY — เปรียบเทียบ Payment Gateway สำหรับ Marketplace ในไทย

- วันที่ค้นคว้า: 2026-10-22 ถึง 2026-10-23 (ค้นจากเว็บเท่านั้น ไม่ได้แตะ code, secrets หรือบัญชีใดๆ)
- สถานะ: เอกสาร research สำหรับประกอบการตัดสินใจของ Founder ยังไม่ใช่ข้อตัดสินใจด้าน architecture
- กติกาตัวเลข: ทุกตัวเลขมี URL อ้างอิง ถ้าหาจากแหล่งสาธารณะไม่เจอจะเขียนว่า "ต้องสอบถาม" อัตราส่วนใหญ่ยังไม่รวม VAT 7% ถ้าแหล่งระบุไว้
- ข้อจำกัด: หน้าเว็บส่วนใหญ่ไม่ระบุวันที่ จึงบันทึกเป็น "เข้าถึงเมื่อ 2026-10-22/23" ส่วนเรื่องใบอนุญาต ธปท. ยังไม่ได้ตรวจกับทะเบียนของ ธปท. โดยตรง

## 1) ตารางเปรียบเทียบ

| ผู้ให้บริการ | ค่าธรรมเนียม PromptPay | ค่าธรรมเนียมบัตร | TrueMoney | Marketplace split + จ่ายเงินร้านรายวัน | ความง่ายในการเปิดบัญชีร้าน | Refund PromptPay | หมายเหตุ |
|---|---|---|---|---|---|---|---|
| **Stripe Connect** (ระบบที่ใช้อยู่) | 1.65% [S1] | บัตรไทย 3.65% + ฿10 / บัตรต่างประเทศ 4.75% + ฿10 / ถ้าต้องแปลงสกุลเงิน +2% [S1] | ไม่มีในหน้าราคา [S1] | **มี**: direct charge + `application_fee` (TH→TH รองรับทั้งบัตรและ PromptPay) [S3] ใช้ separate charges & transfers และ top-up ไม่ได้ [S3] ค่าเริ่มต้นจ่ายอัตโนมัติรายวัน แต่ settlement ใช้เวลา 7 วันทำการ [S5][S6] บัญชี Standard ("Stripe handles pricing") ไม่มีค่า Connect เพิ่ม [S2] | ปานกลาง: ร้านต้องผ่าน KYC ของ Stripe เอง (selfie ต้องทำผ่าน Connect onboarding ไม่ใช่ API) [S3] ประเภทธุรกิจบางแบบอาจถูกขอใบอนุญาตเพิ่ม [S7] | **ได้ผ่าน API** แต่ Stripe จะอีเมลขอเลขบัญชีจากลูกค้า และต้องเป็นบัญชีที่ใช้จ่ายเงิน มีค่าธรรมเนียม ฿10 ต่อครั้ง [S1][S4] refund บัตรไม่มีค่าธรรมเนียม แต่ไม่คืนค่า processing fee เดิม [S1] | implement แล้ว เงินเข้าบัญชี Stripe ของร้านโดยตรง แพลตฟอร์มไม่ได้ถือเงินลูกค้า ค่า ฿10 คงที่ต่อรายการบัตรหนักมากกับออร์เดอร์เล็ก |
| **Omise** (เดิม Opn Payments) | 1.65% [O1] | 3.65% ทุกแบรนด์ ไม่แยกบัตรไทย/ต่างประเทศ [O1] | 2.65% [O1] | **ไม่มี split อัตโนมัติ**: มีแค่ Recipients + Transfers จากยอดของแพลตฟอร์ม [O2] สร้าง transfer schedule ไปยัง recipient ได้ และมี `percentage_of_balance` [O4] ค่าโอน ฿20/ครั้ง (≤2 ล้านบาท) ตามหน้าราคาปัจจุบัน [O1] แต่หน้า FAQ ยังเขียน ฿30 [O6] | ง่ายที่ตัว recipient: ชื่อ + บัญชีธนาคาร (`tax_id` ไม่บังคับ) ตรวจสอบภายใน ~2 วันทำการ [O2] แต่**แพลตฟอร์มจะเป็นผู้ถือเงิน** | **ทำไม่ได้**: "PromptPay charges cannot be voided or refunded through Omise" [O3] | รีแบรนด์กลับเป็น "Omise" มี.ค. 2025 [O7][O8] ปี 2025–26 มีข่าว Omise MCP (พ.ย. 2025), Visa tokenisation (ม.ค. 2026), OneCharge (เม.ย. 2026) [O9] ไม่พบข่าวเปลี่ยนเจ้าของ (บริษัทแม่คือ OPN Holdings) [O10] |
| **2C2P** | ต้องสอบถาม (ไม่มีหน้าราคาสาธารณะ) [C1][C2] | ต้องสอบถาม [C1] | ต้องสอบถาม | ต้องสอบถาม (ไม่พบเอกสาร split/sub-merchant สาธารณะ) [C2] | ต้องสอบถาม มีแอป SME "qwik" ที่สมัครแบบดิจิทัลได้ [C3] | ต้องสอบถาม | เน้นลูกค้า enterprise ใช้การติดต่อฝ่ายขาย [C2] |
| **GB Prime Pay → Xendit** | ต้องสอบถาม (หน้าราคา Xendit TH ตอบ 403) | ต้องสอบถาม | ต้องสอบถาม | **มี (xenPlatform)**: sub-accounts + Split Rules รองรับ THB [X3][X4] แต่ใน TH ต้องขอเปิดใช้ [X3] PromptPay settle T+1 วันทำการ [X5] | ต้องสอบถาม (เอกสารไม่ได้ระบุ KYC ของ sub-account ใน TH) [X6] | ไม่ชัดเจน: ตารางเอกสารเป็น "-" แต่ระบุ refund validity 30 วัน [X5] → ต้องสอบถาม | gbprimepay.com redirect 301 ไป xendit.co/en-th (2026-10-23) [X1] ประกาศรับสมัครงานของ Xendit ระบุว่า GB Prime เป็นส่วนหนึ่งของ Xendit Group [X2] |
| **KSher** | ต้องสอบถาม [K1] | ต้องสอบถาม | ต้องสอบถาม | อ้างถึง "marketplace collections" แต่ไม่มีรายละเอียด [K1] | ต้องสอบถาม | ต้องสอบถาม | ระบุว่ามี "supervised payment service licence" ในไทย [K1] เน้นการค้าข้ามพรมแดน/นำเข้า |
| **ChillPay** | ไม่แยกตามช่องทาง: แผน Chill Pro 3.25% ทุกรายการ [H1] | 3.25% (แผน Pro) [H1] | ไม่ได้ระบุชื่อ [H2] | ไม่พบเรื่อง split/sub-merchant มีแต่ ChillPayOut สำหรับ mass payout [H2] settlement T+1 [H1] | บทความไทยระบุว่าร้านยืนยันตัวตนออนไลน์ได้โดยไม่ต้องส่งเอกสาร [H3] | หน้าเว็บอ้าง "same-day PromptPay refunds" และรองรับ partial refund [H1][H2] | อ้างว่า "licensed by BOT" [H2] (ยังไม่ได้ตรวจกับทะเบียน ธปท.) |
| **Beam** (beamcheckout) | **ฟรี** [B1] | บัตรไทยแบบไม่ใช่ premium 1.80% / premium 2.75% / ต่างประเทศ 3.25% / Amex 3.50% [B1] | 2.20% (รวม e-wallet) [B1] | **ไม่มี** (เอกสารไม่มีหน้า platform/sub-merchant) [B2] จ่ายเงินรายวัน: PromptPay T+1, บัตร T+3 [B1] | ต้องสอบถาม ("Pricing may differ for merchants signing up through a partner/platform") [B1] | มี Refund API แต่ไม่ระบุว่าครอบคลุม PromptPay [B3] FAQ ของบุคคลที่สามบอกว่า refund QR ต้องทำเอง [B4] → ต้องสอบถาม | ถูกที่สุดในกลุ่มที่ประกาศราคา แต่ไม่มีฟีเจอร์ marketplace |
| **Bank API (KBank/SCB)** แบบ DIY | ต้องสอบถาม (ผ่าน RM ของธนาคาร) | ต้องสอบถาม | ไม่มี | ไม่มีให้สำเร็จรูป แพลตฟอร์มต้องรับเงินเข้าบัญชีตัวเองแล้วโอนต่อ | ยาก | ต้องสอบถาม (Antom ระบุว่า KBank ไม่รองรับ refund) [D1] | พอร์ทัลนักพัฒนาต้องลงทะเบียน [D2] รูปแบบนี้แพลตฟอร์มถือเงินลูกค้า มีความเสี่ยงเรื่องใบอนุญาตตาม พ.ร.บ.ระบบการชำระเงิน 2560 [L1] |

## 2) คำแนะนำสำหรับ ZOKY

**ข้อสรุป: อยู่กับ Stripe Connect ต่อ (อันดับ 1) และเปิดคุยกับ Xendit/GB Prime Pay (xenPlatform) เป็นทางเลือกสำรอง (อันดับ 2)**

1. **Stripe Connect (Standard, direct charges + application_fee)** — ระบบนี้ implement แล้วและตอบ requirement หลักได้ครบที่สุด:
   - เงินลูกค้าเข้าบัญชี Stripe ของร้านโดยตรง แพลตฟอร์มได้ GP ผ่าน application fee จึงไม่ต้องถือเงินลูกค้าเอง ซึ่งตรงกับข้อกังวลเรื่องใบอนุญาต ธปท. [S3]
   - PromptPay ยืนยันอัตโนมัติ [S4] refund ทำผ่าน API ได้ทั้งบัตรและ PromptPay [S4]
   - **ข้อเสียที่ต้องรู้:** (ก) ค่า ฿10 ต่อรายการบัตรหนักมากกับออร์เดอร์อาหารราคาต่ำ เช่น ออร์เดอร์ 150 บาทจ่ายค่าธรรมเนียมประมาณ 15.5 บาท หรือราว 10% [S1] ควรเชียร์ให้ลูกค้าใช้ PromptPay (1.65%) (ข) ไม่มี TrueMoney (ค) เงินร้าน "จ่ายรายวัน" ได้ แต่ settlement ใช้ 7 วันทำการ [S5][S6] ร้านจะไม่ได้เงินของวันนี้ภายในพรุ่งนี้ (ง) refund PromptPay ลูกค้าต้องกรอกเลขบัญชีผ่านอีเมลของ Stripe และมีค่า ฿10 [S1][S4] (จ) ร้านต้องผ่าน KYC ของ Stripe เอง ไม่ใช่แค่ "ชื่อ + บัญชีธนาคาร" [S3]
2. **Xendit (GB Prime Pay) xenPlatform** — ในบรรดาผู้ให้บริการในไทยที่หาข้อมูลได้ เป็นรายเดียวนอกจาก Stripe ที่มี sub-account + split rule อัตโนมัติเป็น THB [X3][X4] และ PromptPay settle T+1 [X5] แต่ราคา, KYC ของร้าน และ refund PromptPay ยังต้องสอบถามทั้งหมด จึงควรขอใบเสนอราคาเพื่อเทียบกับ Stripe เท่านั้น ยังไม่ควรย้าย
- **ทำไมไม่เลือก Omise:** ค่า PromptPay เท่ากับ Stripe และค่าบัตรถูกกว่าเพราะไม่มี +฿10 [O1] มี TrueMoney ด้วย แต่ refund PromptPay ไม่ได้ [O3] และไม่มี split อัตโนมัติ แพลตฟอร์มจึงต้องรับเงินแล้วโอนต่อ ซึ่งคือการถือเงินลูกค้า และอาจเข้าข่ายธุรกิจรับชำระเงินแทนที่ต้องมีใบอนุญาต [O2][L1]
- **ทำไมไม่เลือก Beam:** ราคาดีที่สุด (PromptPay ฟรี, บัตร 1.80%) [B1] แต่ไม่มีฟีเจอร์ marketplace [B2] ถ้าใช้จะต้องให้ทุกร้านมีบัญชี Beam ของตัวเอง แล้วเก็บ GP จากร้านทีหลัง ซึ่งไม่ตรงกับ requirement เรื่อง split อัตโนมัติ
- **การย้ายระบบ:** ย้ายไปผู้ให้บริการอื่นเท่ากับต้องเขียน checkout, webhook, refund, onboarding และ payout ใหม่เกือบทั้งหมด ยกเว้น Xendit ที่แนวคิด sub-account/split ใกล้กับ Connect ที่สุด เมื่อ ZOKY ยังมี 1 ร้านและออร์เดอร์น้อย ต้นทุนการย้ายสูงกว่าค่าธรรมเนียมที่จะประหยัดได้
- **ประเด็นที่ต้องให้ Founder ตัดสิน:** (1) ยอมรับ settlement 7 วันทำการและการไม่มี TrueMoney หรือไม่ (2) จะลดผลของค่า ฿10 ต่อรายการบัตรอย่างไร เช่น ตั้งยอดขั้นต่ำสำหรับจ่ายด้วยบัตร หรือแนะนำ PromptPay เป็นค่าเริ่มต้น (การเปลี่ยน UX แบบนี้ต้องผ่าน PM ก่อน) (3) ควรให้ที่ปรึกษากฎหมายยืนยันโมเดลใบอนุญาตอีกครั้ง เพราะเอกสารนี้ไม่ได้ตรวจกับทะเบียน ธปท.

## 3) คำถามสำหรับผู้ให้บริการที่อยู่ใน shortlist

**Stripe (Thailand)**
1. บัญชีร้านใน TH ลด settlement จาก 7 วันทำการเหลือ T+1/T+2 ได้ไหม มีเงื่อนไขอะไร
2. บัญชี Thai ใช้ Express/Custom connected account ได้ไหม (ต้องผ่านฝ่ายขาย [S8]) เพื่อให้ onboarding ร้านง่ายขึ้น มีค่า Connect เพิ่มเท่าไร [S2]
3. มีราคาพิเศษสำหรับบัตรไทย (ตัดหรือลด ฿10) สำหรับ marketplace อาหารที่ออร์เดอร์เฉลี่ยราคาต่ำไหม
4. มีแผนรองรับ TrueMoney ไหม
5. refund PromptPay ทำแบบไม่ต้องให้ลูกค้ากรอกเลขบัญชีผ่านอีเมลได้ไหม ถ้าลูกค้าไม่ตอบจะเกิดอะไรขึ้น
6. เมื่อ refund คืน application fee ให้ร้านได้ไหม (`refund_application_fee`) และประเภทธุรกิจร้านอาหาร/delivery ต้องมีใบอนุญาตเพิ่มไหม [S7]
7. เอกสาร KYC ที่ร้านบุคคลธรรมดาต้องใช้มีอะไรบ้าง เทียบกับนิติบุคคล

**Xendit / GB Prime Pay**
1. ใบเสนอราคา TH: PromptPay, บัตรไทย, บัตรต่างประเทศ, TrueMoney, ค่า payout/disbursement, ค่า refund, ค่า xenPlatform
2. xenPlatform + Split Rules ใช้ใน TH ได้แล้วใช่ไหม ต้องเปิดใช้อย่างไร ใช้เวลานานแค่ไหน [X3]
3. ใครทำ KYC ของ sub-account และร้านบุคคลธรรมดาต้องใช้เอกสารอะไร
4. ตั้ง payout อัตโนมัติรายวันไปบัญชีธนาคารของ sub-account ได้ไหม มีค่าธรรมเนียมเท่าไร
5. refund PromptPay ทำผ่าน API ได้ไหม ต้องใช้เลขบัญชีลูกค้าไหม (เอกสารยังขัดกันเอง [X5])
6. ใบอนุญาต ธปท. ของนิติบุคคลที่ให้บริการในไทยคืออะไร และเงินถูกพักไว้ในนามใคร
7. GB Prime Pay กับ Xendit TH ใช้ API ชุดเดียวกันหรือไม่

**(ถ้ายังพิจารณา) Omise**
1. มีโปรดักต์ marketplace/sub-merchant ที่ split อัตโนมัติโดยแพลตฟอร์มไม่ต้องถือเงินไหม
2. มีทางเลือกอื่นในการ refund PromptPay ไหม
3. ค่าโอนที่ใช้จริงคือ ฿20 หรือ ฿30 [O1][O6]

## 4) แหล่งอ้างอิง (เข้าถึงเมื่อ 2026-10-22/23 เว้นแต่ระบุไว้)

- [S1] Stripe Thailand pricing — https://stripe.com/en-th/pricing
- [S2] Stripe Connect pricing (TH) — https://stripe.com/en-th/connect/pricing
- [S3] Stripe Thailand support for marketplaces — https://support.stripe.com/questions/stripe-thailand-support-for-marketplaces
- [S4] Stripe PromptPay docs — https://docs.stripe.com/payments/promptpay
- [S5] Stripe payout schedule Thailand — https://support.stripe.com/questions/payout-schedule-and-currency-for-stripe-accounts-in-thailand
- [S6] Stripe payouts docs (TH: 7 business days; default daily automatic; min 0.01 THB) — https://docs.stripe.com/payouts
- [S7] Stripe Thailand FAQ (มีหัวข้อ "additional license" แต่ยังไม่ได้อ่านคำตอบ) — https://support.stripe.com/questions/thailand-faq
- [S8] Stripe Express accounts (TH ต้องติดต่อฝ่ายขาย) — https://docs.stripe.com/connect/express-accounts
- [S9] Stripe launches in Thailand (newsroom) — https://stripe.com/en-in/newsroom/news/thailand
- [O1] Omise pricing Thailand — https://www.omise.co/pricing/thailand
- [O2] Omise Transferring funds / Recipients — https://docs.omise.co/transferring-funds
- [O3] Omise PromptPay docs — https://docs.omise.co/promptpay
- [O4] Omise Transfer Schedules API — https://docs.omise.co/transfer-schedules-api
- [O5] Omise Refunds API — https://docs.omise.co/refunds-api
- [O6] Omise/Opn FAQ pricing (฿30 transfer) — https://www.opn.ooo/th-en/faq/pricing/how-much-does-omise-cost/
- [O7] ไทยรัฐ: OPN รีแบรนด์กลับเป็น Omise — https://www.thairath.co.th/money/tech_innovation/tech_companies/2847848
- [O8] Omise newsroom (rebrand 18 มี.ค. 2025) — https://omise.co/en/news-room
- [O9] Omise newsroom / OneCharge (22 เม.ย. 2026) — https://omise.co/en/newsroom , https://omise.co/en/post/omise-onecharge
- [O10] Opn news (OPN Holdings, 2023) — https://www.opn.ooo/th-en/news
- [C1] 2C2P Thailand — https://2c2p.com/countries/thailand/
- [C2] InfoQuest 2025: 2C2P ลงทุน 1.5 พันล้านบาท / qwik — https://www.infoquest.co.th/2025/541269
- [C3] PostToday: qwik by 2C2P — https://www.posttoday.com/smart-sme/732934
- [X1] gbprimepay.com → 301 → https://xendit.co/en-th (ตรวจเมื่อ 2026-10-23)
- [X2] Xendit job posting ("GB Prime … part of the Xendit Group") — https://jobs.coatue.com/companies/xendit/jobs/37690996-senior-sales
- [X3] Xendit help: Split Payment (TH ต้องขอเปิดใช้) — https://help.xendit.co/hc/en-us/articles/10390264065561-How-Do-I-Use-Split-Payment-Feature-to-Charge-Splits-Commission-Fee
- [X4] Xendit Split Payments docs — https://docs.xendit.co/docs/split-payments
- [X5] Xendit QR PromptPay docs — https://docs.xendit.co/docs/qr-promptpay
- [X6] Xendit xenPlatform overview — https://docs.xendit.co/xenplatform
- [X7] Xendit expands to Thailand (เม.ย. 2024) — https://www.xendit.co/en/newsroom/press-release/driving-growth-xendit-expands-reach-to-thailand-revolutionizing-payment-processes/
- [K1] KSher Thailand — https://www.ksher.com/th
- [H1] ChillPay pricing — https://www.chillpay.co/en/payment-channel/pricing/
- [H2] ChillPay home — https://www.chillpay.co/
- [H3] Brand Inside: รู้จัก ChillPay — https://brandinside.asia/?p=97968
- [B1] Beam pricing — https://beamcheckout.com/pricing
- [B2] Beam docs index — https://docs.beamcheckout.com/llms.txt
- [B3] Beam Refunds API — https://docs.beamcheckout.com/refunds/refunds-api
- [B4] Qashier: Beam QR FAQ (บุคคลที่สาม) — https://support.qashier.com/en/articles/9900685-th-beam-qr-faq
- [D1] Antom: KBank — https://docs.antom.com/ac/antomop/kbank
- [D2] kapi-sdk (unofficial KBank SDK) — https://root.packagist.org/packages/farzai/kapi-sdk
- [L1] Tilleke & Gibbins: Thailand tightens qualifications for payment service operators — https://www.tilleke.com/insights/thailand-tightens-qualifications-for-payment-service-operators
