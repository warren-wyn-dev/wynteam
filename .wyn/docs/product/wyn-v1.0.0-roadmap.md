# WYN V1.0.0 Roadmap — หลัง Founder ล็อกสเปกฉบับสมบูรณ์ (2026-08-22)

> **Naming note (2026-08-22)**: ชื่อแบรนด์ที่ผู้ใช้เห็นเปลี่ยนจาก WYN → **WYNOS** (ดู DECISIONS.md "เปลี่ยนชื่อแบรนด์") — task/feature ใหม่ที่เขียนขึ้นจากนี้ไปให้ใช้ "WYNOS" ในชื่อฟีเจอร์ที่ผู้ใช้เห็น (เช่น WYNOS Admin, WYNOS Chat, WYNOS Top 100) ส่วน task ID prefix (`WYN-XXX`, `DS-XXX`) และ technical identifier ทั้งหมดยังใช้ `wyn`/`WYN` เหมือนเดิมไม่เปลี่ยน — ZOKY/ZOKY Sellers by WYN ยังไม่เปลี่ยนชื่อ รอตัดสินตอน V2
>
> อ้างอิงสเปกเต็มที่ `.wyn/docs/product/wyn-v1.0.0-master-spec.md` และคำตัดสินใจที่ `.wyn/company/DECISIONS.md` (2026-08-22) — เอกสารนี้แทนที่ `.wyn/docs/product/wyn-v0.1-roadmap.md` และ `.wyn/docs/product/zoky-platform-roadmap.md` ในฐานะ roadmap หลักที่ใช้งานอยู่ (สองไฟล์เดิมยังเก็บไว้เป็น audit trail ไม่ลบ)
>
> กติกาการ reuse ตามที่ Founder ยืนยัน: **"อันไหนใช้ได้ ใช้ ถ้าใช้ไม่ได้ก็ทิ้งเลย"** — งานที่ผ่าน QA แล้วและตรงกับสเปกใหม่ใช้ต่อได้ทันทีไม่ต้องทำซ้ำ งานที่ไม่ตรง (Pop, ZOKY tab ใน WYN App) ถอด/พักไว้ ไม่ลบโค้ด/DB จนกว่าจะขอ approval แยกต่างหาก (destructive change)

## ส่วน A — สถานะของงานเดิมเทียบกับสเปก V1.0.0

| งานเดิม | สถานะ QA | ตรงกับ V1.0.0 ไหม | การจัดการ |
|---|---|---|---|
| WYN-002 (Auth), WYN-003 (Profile) | Approved | ✅ ตรง (Register/Login/Profile) | ใช้ต่อเป็นฐาน |
| WYN-005 (Drop core), WYN-007 (Home), WYN-008 (Follow), WYN-009 (Search), WYN-012 (Notification), WYN-013 (Profile V2) | Approved | ✅ ตรงกับ Core 8 (Drop/Home/Notification) | ใช้ต่อเป็นฐาน ต้องต่อยอดเพิ่ม (ดูส่วน B) |
| WYN-014 (Club Core), WYN-015 (Club Discovery/Integration) | Approved | ✅ ตรงกับ Core 8 (Club) เกือบสมบูรณ์ | ใช้ต่อเป็นฐาน |
| WYN-016 (Push Notifications) | Coded + self-verified PASS, บล็อกด้วย Firebase setup | ✅ ยังจำเป็น (Notification เป็น Core 8) | คงในแผนเดิม รอ Founder ทำ Firebase 4 ขั้นตอน |
| WYN-017 (Trending+Recommended Clubs), WYN-018 (Ranking), WYN-019 (Drop feed tabs), WYN-020 (Hashtag), WYN-021 (Mention), WYN-022 (Reply Comment) | Approved, QA อิสระ PASS | ✅ ตรงกับ Core 8 (Drop/Trending) เกือบสมบูรณ์ | ใช้ต่อเป็นฐาน เป็นฐานของ Discovery/Trending Engine ใน V1.0.0 |
| WYN-023 (Home/Drop polish) | Backlog, design เสร็จ รอ Coding | ✅ ยังตรง (เป็นของเล็กเก็บกวาด) | ทำต่อได้ทันที ไม่กระทบสเปกใหม่ |
| **WYN-006 (Pop)** | Approved, ใช้งานอยู่จริงใน Bottom Nav | ❌ V1.0.0 ระบุ "ยังไม่เปิด WYN Pop" (ย้ายไป V3) | **ถอดออกจาก Bottom Nav** (WYN-024) — โค้ด/DB/route คงไว้ ไม่ลบ |
| **ZOKY-001–005 (Marketplace Customer), SELLER-001–005 (ZOKY Sellers)** | Approved ครบทุก task | ❌ V1.0.0 ระบุ "ยังไม่เปิด WYN Shop/Marketplace/Payment" (ย้ายไป V2) | **ถอด ZOKY tab ออกจาก WYN App** (WYN-024) — พัก `seller_app/` ไว้เฉย ๆ ไม่พัฒนาต่อ ไม่ลบ |
| DS-001–008 (Cyan `#00C8FF` + Orange `#FF6B35`) | Approved, implement ครบ 45 หน้าจอ | ⚠️ ขัดกับ "80–90% White + 10–20% Rainbow" ของสเปกใหม่ | **รอ AI Design เสนอเปรียบเทียบ** (DS-009) — Founder ยังไม่ล็อก ห้ามเปลี่ยนเองจนกว่าจะมีคำตอบ |

**Gap ที่ยังไม่มีเลยในระบบ** (ต้องสร้างใหม่ทั้งหมด): WYN Chat, Safety system ทั้งชุด (Report/Block/Mute/Moderation/Appeal), Discovery page, ReDrop, Poll, Draft, Edit/Delete-with-window, View-count anti-fraud system, Private Account, WYN Admin (web), Legal/Compliance documents + data-rights flows, Account Security ขั้นสูง (session mgmt, force logout, brute-force protection)

## ส่วน B — Bottom Navigation ใหม่ (บังคับตาม Section 34)

**เดิม**: Home / Drop / Pop / ZOKY / Profile (5 tab, Search+Notification อยู่ในหน้า Home)

**ใหม่ (V1.0.0)**: 🏠 Home · 🔍 Search · ＋ Drop · 🔔 Notifications · 👤 Profile — Chat เข้าผ่านไอคอนแยก ไม่ใช่ bottom tab

ผลกระทบไฟล์หลัก: `RootShell`/bottom nav widget ในทั้งสองแอปเฉพาะ `app/` (ไม่กระทบ `seller_app/`)

## ส่วน C — Phase Breakdown

งานแบ่งเป็น Phase ตามที่ Founder สั่งชัดเจนว่า "ไม่สร้างทุกระบบรวดเดียว" — แต่ละ Phase ทดสอบและ deploy แยกได้ ไม่บล็อกกัน (ยกเว้นระบุ Dependency)

### Phase 0 — Realignment (เริ่มทันที ความเสี่ยงต่ำสุด)
| Task | Feature | Priority |
|---|---|---|
| WYN-024 | Bottom Nav V1.0.0 Restructure — ถอด Pop/ZOKY, เพิ่ม Search+Notifications เป็น tab | สูงสุด (บล็อก UX ทุกอย่างที่เหลือ เพราะ nav คือโครงหลัก) |
| DS-009 | Design comparison: White+Rainbow vs Cyan+Orange เดิม | สูงสุด (บล็อก UI งานถัดไปทั้งหมดถ้าจะเปลี่ยนสี) |
| WYN-023 | Home/Drop polish (ค้างจาก backlog เดิม) | กลาง — ทำคู่ขนานได้ |

### Phase 1 — Safety & Trust Foundation
เหตุผลที่ทำก่อน Chat/Discovery: เปิดพื้นที่ social ใหม่ (Chat) โดยไม่มี Report/Block/Mute เสี่ยงสูงกว่าฟีเจอร์อื่นทั้งหมด — WYN Admin's Report Center/Moderation ก็ต้องพึ่งฐานนี้ด้วย
| Task | Feature |
|---|---|
| WYN-026 | Report system (Drop/Comment/Club/User/Message แบบ universal) |
| WYN-027 | Block system |
| WYN-028 | Mute system |
| WYN-029 | Moderation queue + action (No Action/Warning/Remove/Restrict/Suspend/Ban) |
| WYN-030 | Appeal system |

### Phase 2 — WYN Chat (Basic DM)
| Task | Feature |
|---|---|
| WYN-031 | 1:1 Chat (text/image/reply/delete/read-unread) |
| WYN-032 | Message Request flow (Accept/Delete/Block/Report) |
| WYN-033 | Share เข้า Chat (Drop/Profile/Club) |

Dependency: WYN-027/028 (Block/Mute ใช้ร่วมใน Chat), WYN-026 (Report message)

### Phase 3 — Drop Enhancement
| Task | Feature |
|---|---|
| WYN-034 | ReDrop (Standard + Quote) |
| WYN-035 | Poll ใน Drop |
| WYN-036 | Draft system |
| WYN-037 | Edit/Delete Drop (time window + soft delete/restore) |
| WYN-038 | View counting system (unique viewer/rate-limit/bot detection) |
| WYN-039 | Private Account + Follow Request |

### Phase 4 — Discovery & Trending Engine
| Task | Feature |
|---|---|
| WYN-040 | Discovery page (Trending Now/Topics/Hashtags/Rising/Suggested Users/Suggested Clubs) |
| WYN-041 | Trending Engine v2 (anti-manipulation scoring ต่อยอดจาก WYN-018) |
| WYN-042 | WYN Top 100 |

Dependency: WYN-038 (View system ให้ข้อมูล Trending Score), WYN-026 (Spam Risk ต้องพึ่งข้อมูล Report)

### Phase 5 — Notification & Settings Expansion
| Task | Feature |
|---|---|
| WYN-043 | Notification type ใหม่ (ReDrop/Quote/FollowRequest/MessageRequest/Trending/Top100/System) |
| WYN-044 | Notification Settings (เปิด/ปิดรายประเภท) |
| WYN-045 | Settings screen เต็มรูปแบบ (Account/Privacy/Security/Safety/Data/Legal) |

### Phase 6 — Legal & Compliance Layer
| Task | Feature |
|---|---|
| WYN-046 | Platform documents (ToS/Privacy/Community Guidelines/Copyright/Report/Appeal Policy) + acceptance flow |
| WYN-047 | Data rights (Access/Correction/Deletion/Export, Account Deletion) — PDPA |
| WYN-048 | Consent management, Audit log foundation, Security incident workflow |

**หมายเหตุกฎหมาย**: Phase นี้ทีม AI ออกแบบ Compliance Layer ทางเทคนิคเท่านั้น (data flow/schema/flow) — เนื้อหาเอกสารกฎหมายจริงและการวิเคราะห์ว่า WYN เข้าข่าย DPS ประเภทไหนต้องให้ผู้เชี่ยวชาญกฎหมายตรวจสอบก่อนเผยแพร่จริง (ตามที่ Founder ระบุไว้เอง)

### Phase 7 — WYN Admin (Web) — แยก track เพราะเป็น tech stack ใหม่
สถาปัตยกรรม: **Web-based admin panel** (Founder ยืนยัน 2026-08-22 — เป็น Major Architecture ใหม่ครั้งแรกของโปรเจกต์ที่ไม่ใช่ Flutter, ต้องเลือก stack/hosting ก่อนเริ่ม, บันทึกที่ DECISIONS.md)
| Task | Feature |
|---|---|
| WYN-049 | Admin foundation (web scaffold, admin auth/role) |
| WYN-050 | Admin Dashboard (DAU/MAU/content/report metrics) |
| WYN-051 | Admin User Management |
| WYN-052 | Admin Content Moderation (Drop/Club) |
| WYN-053 | Admin Report Center |
| WYN-054 | Audit Log |
| WYN-055 | Official Announcements |

Dependency: Phase 1 (Report/Moderation data model ต้องมีก่อน Admin จะมีอะไรให้จัดการ)

### Phase 8 — Analytics & Revenue Infrastructure (future-ready scaffolding เท่านั้น)
> **แก้ไขเลข task 2026-08-24**: ร่างเดิมของหัวข้อนี้ใช้ WYN-056/057/058 — แต่ WYN-056 ถูกใช้ไปแล้วกับงานนอก roadmap ที่ Founder ขอเพิ่มระหว่างทาง (Club Discovery Visual Refresh, ดู `.wyn/tasks/approved/WYN-056-club-discovery-visual-refresh.md`) เลื่อนเลขของ Phase 8 ทั้งหมดขึ้นไป 1 เพื่อไม่ให้ชนกัน

| Task | Feature |
|---|---|
| WYN-057 | User Analytics (self) |
| WYN-058 | Creator Analytics (basic) |
| WYN-059 | Ad/Revenue infrastructure schema (ไม่เปิดใช้งานจริง) |

## ส่วน D — ลำดับความสำคัญที่ AI Product Manager แนะนำ

1. **Phase 0 ก่อนเสมอ** — nav/DS เป็นโครงที่ทุกหน้าจอใหม่ต้องอิงตาม เริ่มงานอื่นก่อนจะเสี่ยงต้อง rework
2. **Phase 1 (Safety) ก่อน Phase 2 (Chat)** — เปิด DM ให้คนแปลกหน้าคุยกันโดยไม่มี Block/Report/Mute เป็นความเสี่ยงต่อผู้ใช้ Gen Z (กลุ่มเป้าหมายหลักของ WYN) สูงเกินยอมรับได้
3. Phase 3/4/5 ทำคู่ขนานกันได้ (ไม่ชนกันมาก) หลัง Phase 1-2 เสร็จ
4. Phase 6 (Legal) แนะนำเริ่มคู่ขนานตั้งแต่ Phase 1 ได้เลยในส่วนเอกสาร (ไม่ต้องรอ Phase อื่น) เพราะเป็นความเสี่ยงด้านกฎหมายที่ไม่ควรดองไว้ท้ายสุด
5. Phase 7 (Admin) เริ่มได้เมื่อ Phase 1 มีข้อมูล Report/Moderation ให้บริหารจัดการจริงแล้ว
6. Phase 8 ทำท้ายสุด เป็น scaffolding ไม่เร่งด่วน

## ส่วน E — งานที่ Founder ยังต้องทำเอง (ไม่เปลี่ยนจากเดิม)

- Firebase project + 4 ขั้นตอน (WYN-016 Push) — บล็อกเฉพาะการทดสอบส่งจริง ไม่บล็อก Phase อื่น
- Google OAuth / Apple Developer / Twilio — ยังไม่ได้ทำ (ใช้ Anonymous Sign-In แทนชั่วคราวอยู่)
