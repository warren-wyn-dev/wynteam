# Active Tasks Audit — 2026-10-10

ตรวจไฟล์ทั้งหมดใน `.wyn/tasks/active/` (27 งาน + README) เทียบกับ GitHub PR, workflow runs ของ migration และหลักฐานในไฟล์งานเอง
**ยังไม่ได้ย้ายไฟล์ใด ๆ** — รอ Founder ตัดสินตามข้อเสนอด้านล่าง

หมายเหตุ: "merge แล้ว" ≠ "deploy แล้ว" — สำหรับงานเว็บ หลักฐาน merge + migration apply สำเร็จบ่งชี้ว่าโค้ดพร้อม แต่ไม่ได้ตรวจ production deploy run ของแต่ละงานแยก (ตาม `.wyn/company/PROJECT_STATUS.md` ส่วน deployment log ช่วงตุลาคมยังไม่ครบ)

## A. เสนอย้ายไป `completed/` — หลักฐานครบ (22 งาน)

| งาน | หลักฐาน |
|---|---|
| WYN-190 Notifications developer preview | ไฟล์ระบุ Completed — released to all Web accounts 2026-09-30 |
| WYN-195 Food entry in Social | PR #820 merged 2026-10-03 |
| WYN-196 Food delivery zone | PR #824 merged 2026-10-03 |
| WYN-197 Food store places | PR #825 merged 2026-10-03 |
| WYN-198 Merchant simple order flow | PR #826 merged 2026-10-04 |
| WYN-199 Merchant notification prompt | PR #827 merged 2026-10-04 |
| WYN-200 Merchant order sound | PR #828 merged 2026-10-04 |
| WYN-201 Pull to refresh (Merchant/Food) | PR #829 merged 2026-10-04 |
| WYN-202 Merchant alert until viewed | PR #830 merged 2026-10-04 |
| WYN-203 Admin Food ops | PR #831 merged 2026-10-04, `food-apply-wyn203` success 2026-10-04 |
| WYN-204 Merchant home (LINE MAN style) | PR #832 merged 2026-10-04 |
| WYN-205 Merchant finance shortcuts | PR #833 merged 2026-10-04 |
| WYN-206 Platform campaigns | PR #835 merged 2026-10-04, `food-apply-wyn206` success 2026-10-04 |
| WYN-207 Food ads | PR #836 merged 2026-10-04, `food-apply-wyn207` success 2026-10-04 |
| WYN-208 Merchant nav icons | PR #840 merged 2026-10-04 |
| WYN-209 Merchant app icon | PR #841 merged 2026-10-04 |
| WYN-210 Merchant finance | PR #849 merged 2026-10-04, `food-apply-wyn210` success 2026-10-04 |
| WYN-211 Food Maha Sarakham | PR #865 merged 2026-10-04, `food-apply-wyn211` success 2026-10-04 |
| WYN-212 Food home banner | PR #867 merged 2026-10-04 |
| WYN-213 Merchant access hardening | ไฟล์ระบุ released + production state verified; `food-apply-wyn213` success 2026-10-04 |
| WYN-214 Admin merchant polish | PR #877 merged 2026-10-04, `food-apply-wyn214` success 2026-10-04 |
| WYN-215 Push per app | ไฟล์ระบุ production rollout verified live 2026-10-05; `push-apply-wyn215` success |

## B. น่าจะเสร็จ แต่ต้อง Founder ยืนยัน (3 งาน)

| งาน | สถานะจริง | ต้องการ |
|---|---|---|
| WYN-191 People search ranked + TH/EN | Production migration applied, production probes ผ่าน (ไฟล์งาน) | ยืนยันว่าใช้งานได้ → completed |
| WYN-192 Post search ranked + TH/EN | Production migration applied (ไฟล์งาน) | ยืนยันว่าใช้งานได้ → completed |
| WYN-211 Product subdomains | ไฟล์มีแต่ production trigger retries 2026-10-04 ยังไม่มีบันทึกว่า domain verified | ยืนยันว่า food./merchant. subdomain ใช้งานได้จริง |

## C. ยังเปิดไว้หรือรอตัดสิน (3 งาน + README)

| งาน | เหตุผล | ข้อเสนอ |
|---|---|---|
| WYN-112 Activation funnel | แก้ root cause และ deploy แล้ว (WYN-114) รอ Founder แชร์ลิงก์ใหม่แล้วดูผล signup | Founder ตัดสินว่าดูผลแล้วหรือยัง ถ้าแล้ว → completed |
| WYN-141 Frontend UX/UI system | Admin batch เสร็จ; Flutter batches 2–6 ค้าง แต่ Flutter **พักการพัฒนา** (2026-09-19) | เปลี่ยนเป็น paused/backlog ตามการพัก Flutter |
| WYN-219 Admin Control Center | กำลังทำ (Phase 1 + step 1 merged; step 3 #1080 เปิดอยู่) | คง active |
| README.md | ไม่ใช่งาน | — |

## Legacy note

ID ซ้ำ: `WYN-211` ถูกใช้ 2 งาน (Food Maha Sarakham และ Product subdomains) — ห้าม rename โดยไม่ audit commit/PR ที่อ้างถึง (กติกาเดียวกับ WYN-024 ใน PROJECT_STATUS)
