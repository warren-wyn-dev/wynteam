# Product Full Spec — WYN-105

Status: full spec complete (2026-09-02) — ready for AI Design (งานนี้ใหญ่กว่าที่ backlog เดิมประเมินไว้มาก — อ่าน Architecture Risk ก่อน)
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` ข้อ 5 (ส่วนธีมสี)/28, `.wyn/tasks/backlog/WYN-105.md`

Feature: ระบบเลือกธีมสีของ WYNOS ได้ 3 แบบ (ขาวนวล / ขาวบริสุทธิ์ / ดำ)

Goal: ให้ผู้ใช้เลือกธีมที่ชอบได้เอง เปลี่ยนแล้วทั้งแอปเปลี่ยนสีจริง ไม่ใช่แค่บางหน้า

Target User: ผู้ใช้ WYN Social ทุกคน

## Problem — สถานะปัจจุบันจริง (ตรวจโค้ดแล้ว): มี "ธีมเข้ม" เป็น placeholder ที่ไม่ทำงาน + สถาปัตยกรรมสีทั้งแอปยังไม่รองรับการสลับธีมจริง

**Settings มีแถว "ธีมเข้ม" อยู่แล้ว** (`settings_screen.dart` บรรทัด 193-197, ใต้กลุ่ม "การตั้งค่าแอป") แต่เป็น `const _SettingsRow` **ไม่มี `onTap` เลย** — กดแล้วไม่มีอะไรเกิดขึ้น เป็น placeholder ที่ค้างมาตั้งแต่ก่อนหน้านี้

**`main.dart` มี `theme: WynTheme.light` / `darkTheme: WynTheme.dark` อยู่แล้ว แต่ `themeMode: ThemeMode.light` ถูก hardcode ไว้ตายตัว** — `WynColors` (`app/lib/core/design/wyn_colors.dart` บรรทัด 95-108) มี comment ยืนยันตรงๆ ว่า dark ColorScheme "**unused in production today**" เพราะ **"WynApp forces ThemeMode.light (WYN-071)"**

**ปัญหาที่ใหญ่กว่านั้นและเป็นความเสี่ยงหลักของงานนี้**: โค้ดทั้งแอป (ตรวจยืนยันจากทุกไฟล์ที่อ่านระหว่างทำสเปกชุดนี้ เช่น `create_club_screen.dart`, `side_menu.dart`, `hashtag_rank_row.dart` ฯลฯ) **อ้างอิงสีผ่าน `WynColors.ink`/`WynColors.paper`/`WynColors.graphite` ฯลฯ เป็น static const literal โดยตรง ไม่ผ่าน `Theme.of(context).colorScheme`** — แปลว่าแม้จะเปลี่ยน `themeMode` เป็น dark จริง หน้าจอส่วนใหญ่ก็ **จะไม่เปลี่ยนสีเลย** เพราะ widget ไม่ได้ผูกกับ `Theme` ของ context ตั้งแต่ต้น การสลับธีมจริงต้องมีชั้นให้ `WynColors.ink`/`.paper`/ฯลฯ **อ่านค่าปัจจุบันแบบ dynamic ตาม theme ที่เลือกไว้** (ไม่ใช่ static const อีกต่อไป) ซึ่งกระทบเกือบทุกไฟล์ UI ในโปรเจกต์ — นี่คือของจริงที่ backlog เดิม (Risk R1: "ทำธีมตอนที่ UI อื่นยังเปลี่ยนอยู่ อาจต้องไล่แก้ซ้ำ") มองข้ามความลึกไป — ปัญหาไม่ใช่แค่ "ชนกับงาน UI อื่นที่ยังไม่นิ่ง" แต่คือ **สถาปัตยกรรมสีปัจจุบันทั้งระบบไม่ได้ถูกออกแบบมาให้สลับธีมได้ตั้งแต่ต้น**

## Data Model Impact

**คอลัมน์ใหม่ (sync ข้ามอุปกรณ์ ตามที่ backlog เดิมระบุว่า "ต้องการ")**:
```sql
alter table public.profiles
  add column if not exists theme_preference text not null default 'soft_white'
  check (theme_preference in ('soft_white', 'pure_white', 'dark'));
```
- `soft_white` = ขาวนวล (ธีมปัจจุบัน/off-white, ค่า default ไม่เปลี่ยนพฤติกรรมเดิม), `pure_white` = ขาวบริสุทธิ์, `dark` = ดำ
- Local-first: เก็บใน `SharedPreferences` ก่อนเสมอ (ใช้ได้ทันทีไม่ต้องรอ network) แล้ว sync ขึ้น `profiles.theme_preference` แบบ best-effort เบื้องหลัง (เหมือน pattern การตั้งค่าอื่นๆ ที่มีอยู่แล้วในแอป เช่น notification settings)

## Architecture Decision: วิธีทำให้สลับธีมได้จริง (ประเด็นสำคัญที่สุดของสเปกนี้)

**ต้องเลือกแนวทางหนึ่งก่อนเริ่ม Design จริง — เป็นการตัดสินใจเชิงสถาปัตยกรรมของ Design/Coding ไม่ใช่แค่การเพิ่มหน้าตั้งค่า**:

**แนวทางที่แนะนำ**: เปลี่ยน `WynColors` จาก class ที่มีแต่ `static const Color` ล้วนๆ ให้มี **`WynColors.of(BuildContext context)`** (หรือ `InheritedWidget`/`ChangeNotifier` ที่ห่อทั้งแอปไว้ระดับบนสุด เก็บ `WynThemePreference` ปัจจุบัน) ที่คืนชุดสีตามธีมที่เลือกอยู่ — จากนั้น**ไล่แก้ทุกจุดที่อ้างอิง `WynColors.ink`/`.paper`/ฯลฯ แบบ static ให้เปลี่ยนมาเรียกผ่าน context แทน** ทีละไฟล์ (งานใหญ่ ไม่ใช่ 1 commit เดียว) — นี่คือเหตุผลที่ backlog เดิมแนะนำ "ทำเป็นงานสุดท้ายของรอบนี้ หลัง Phase 1-2 นิ่งแล้ว" ถูกต้องแล้ว แต่ **เหตุผลควรเป็น "รอให้ UI ที่ต้องแก้ทุกไฟล์นิ่งก่อน" ไม่ใช่แค่ "ลดการชนกับงาน UI อื่น"**

**ทางเลือกที่ไม่แนะนำแต่ต้องบันทึกไว้**: คง static const ไว้เหมือนเดิมทั้งหมด แล้วสร้าง `WynColors` เวอร์ชันใหม่ 3 ชุดแยกกัน (`WynColorsSoftWhite`/`WynColorsPureWhite`/`WynColorsDark`) แล้วให้แต่ละไฟล์เลือก class ที่ถูกต้องตาม global state เอง — วิธีนี้ยังต้องไล่แก้ทุกไฟล์อยู่ดี (ไม่ประหยัดงานกว่าทางแรก) แต่เพิ่มความเสี่ยง human error สูงกว่า (ลืมเปลี่ยนบางไฟล์ทำให้บางหน้าจอค้างธีมเดิม) — **ไม่แนะนำ**

**ขอบเขตของงาน "ไล่แก้ทุกจุด" นี้ใหญ่แค่ไหน**: ตรวจคร่าวๆ พบว่า `WynColors.` ถูกอ้างอิงกระจายอยู่ในเกือบทุก screen/widget ของ `app/lib/features/**` และ `app/lib/core/widgets/**` — ไม่สามารถประเมินเป็นตัวเลขไฟล์ที่แน่นอนได้ในรอบสเปกนี้ (ต้อง grep นับจริงตอน Design/Coding) แต่จากที่อ่านโค้ดหลายสิบไฟล์ระหว่างทำสเปกชุดนี้ ยืนยันว่า**ทุกไฟล์ UI ที่เปิดอ่านมาอ้างอิงมันโดยตรงหมด ไม่มีข้อยกเว้น**

## Requirements (UI/UX)

**1. Settings**: แถว "ธีมเข้ม" เดิมเปลี่ยนเป็น **"ธีม"** (ไม่ใช่แค่ dark toggle อีกต่อไป เพราะมี 3 ตัวเลือก ไม่ใช่ 2) กดแล้วเปิดหน้า/bottom sheet เลือกธีม 3 แบบพร้อม preview เล็กๆ ต่อธีม (swatch สีตัวอย่าง)
- Label 3 ตัวเลือก: "ขาวนวล" (มี checkmark เป็นค่าเริ่มต้น), "ขาวบริสุทธิ์", "ดำ"

**2. เปลี่ยนธีมแล้วทั้งแอปเปลี่ยนทันที** (real-time, ไม่ต้อง restart แอป) — ผ่าน `ChangeNotifier`/state management ที่มีอยู่แล้วในระดับ root ของแอป (ตรวจสอบว่าโปรเจกต์นี้ใช้ pattern ใดอยู่แล้วสำหรับ global app state ก่อนเริ่ม Coding — ถ้ายังไม่มีเลยต้องเพิ่มเป็นของใหม่)

**3. Palette 3 ธีม** — AI Design ต้องกำหนดค่าจริงให้ครบทุก token ที่ `WynColors` มีอยู่ปัจจุบัน (`ink`/`paper`/`graphite`/`faint`/`hairline`/`sapphire`/`sapphireRing`/`mutedNeutral` เป็นอย่างน้อย) ทั้ง 3 ธีม:
- **ขาวนวล**: ใช้ค่าปัจจุบันทั้งหมดเป็นฐาน (`paper = #FAF9F6` ตามที่มีอยู่แล้ว) — ไม่เปลี่ยนอะไร นี่คือธีม default
- **ขาวบริสุทธิ์**: `paper` เปลี่ยนเป็นขาวแท้ (`#FFFFFF`, ตรงกับ `WynColors.white` ที่มีอยู่แล้วในไฟล์) ส่วนอื่นปรับให้ contrast ยังผ่านมาตรฐาน accessibility (WCAG AA เป็นอย่างน้อย)
- **ดำ**: ใช้ token `bgDark`/`surfaceDark`/`surfaceMutedDark`/`borderSubtleDark`/`borderStrongDark` ที่มีอยู่แล้วในไฟล์เป็นฐาน (สร้างไว้ล่วงหน้าแล้วแต่ "unused in production" ตามที่ตรวจพบ) — **ต้องยืนยันว่าค่าที่มีอยู่แล้วเหล่านี้ยัง valid/เพียงพอ หรือควรออกแบบใหม่** เพราะไม่รู้ว่าถูกออกแบบมาสอดคล้องกับ Sapphire re-brand (2026-08-29) หรือเป็นของเก่าก่อน re-brand — ต้องตรวจสอบใน Design

## Edge Cases

1. **Component ที่ hardcode สี literal ตรงๆ แทนที่จะเรียก `WynColors`** (เช่น `Color(0xFFF1EFE9)` ที่เห็นใน `create_drop_screen.dart` บรรทัด 1024 ระหว่างทำสเปกชุดนี้) — จุดเหล่านี้จะไม่เปลี่ยนสีเลยไม่ว่าจะแก้ `WynColors` ให้ dynamic แค่ไหน ต้อง grep หา `Color(0x` literal ทั้งโปรเจกต์แยกต่างหากจากการไล่แก้ `WynColors.` เพื่อไม่ให้มีจุดตกหล่นที่ "กลืนกับพื้นหลัง" ในธีมดำตาม AC ที่ Founder ระบุ
2. **Rainbow accent gradient** (`DS-009`, ใช้ใน Trending tile ring/feed-mode segment) — มี comment ยืนยันชัดเจนอยู่แล้วว่า "Same value in both light and dark mode -- do not theme-split this" — คงค่าเดิมไว้ไม่ต้องทำ 3 เวอร์ชัน
3. **ธีมดำกับรูปภาพ/avatar ที่มีพื้นหลังโปร่งใส**: ต้องตรวจว่ารูป PNG โปร่งใสที่ออกแบบมาสำหรับพื้นขาว (เช่น logo/icon บางจุด) ยังมองเห็นชัดบนพื้นดำหรือไม่
4. **System-level dark mode ของอุปกรณ์**: ธีมนี้เป็นการเลือกเอง 3 แบบโดยผู้ใช้ ไม่ผูกกับ system dark mode setting ของ OS อัตโนมัติ (ต่างจาก `ThemeMode.system` ทั่วไป) — ตาม Founder's ask ที่ให้ "เลือกสีธีมได้ 3 สี" เอง ไม่ใช่ auto-detect

## Acceptance Criteria
- [ ] เปลี่ยนธีมในตั้งค่าแล้วทั้งแอปเปลี่ยนสีทันที ไม่ต้อง restart
- [ ] ทุกหน้าจอหลัก (Home/Search/Notification/Profile/Club/Settings/Chat) อ่านง่ายครบทั้ง 3 ธีม ไม่มีข้อความ/ไอคอนกลืนกับพื้นหลัง (โดยเฉพาะธีมดำ)
- [ ] ไม่มีจุด hardcode สี literal (`Color(0x...)`) ที่หลงเหลือไม่ตอบสนองต่อธีมที่เลือก (ตรวจสอบด้วย grep อย่างเป็นระบบ ไม่ใช่แค่ตรวจตา)
- [ ] ค่าที่เลือกไว้ sync ข้ามอุปกรณ์ได้จริงผ่าน `profiles.theme_preference`
- [ ] Rainbow accent gradient คงค่าเดิมทุกธีม (ตามที่ตั้งใจไว้แต่แรก)

## Dependencies
ควรทำหลัง WYN-078 (แก้ bug พื้นหลังไม่เต็มจอ, ทำเสร็จแล้วใน Phase 1) และควรทำหลัง Phase 2 (WYN-089–096, รีดีไซน์ UI) นิ่งแล้ว ตามที่ backlog เดิมระบุไว้ถูกต้องแล้ว — ยิ่งยืนยันหนักแน่นขึ้นหลังพบ Architecture Decision ข้างบน เพราะการไล่แก้ไฟล์ UI จำนวนมากจะชนกับ Phase 2 ที่ยังเปลี่ยนแปลง UI เดิมอยู่แน่นอน

## Out of Scope (รอบนี้)
- Auto-detect ธีมตาม system dark mode ของ OS (ดู Edge Case 4)
- ปรับ palette ของ `seller_app/`/ZOKY sub-theme (ไฟล์ comment ยืนยันชัดว่า `wyn_colors.dart` เป็น canonical source แต่ `seller_app/`'s ZOKY Orange accent "untouched" — คนละสโคป)
- Custom/user-defined theme นอกเหนือจาก 3 แบบที่ Founder ระบุ
- Rainbow accent gradient แยกตามธีม (คงเดิมตามที่ระบุไว้แล้ว)

## Risks

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | **สถาปัตยกรรมสีปัจจุบันทั้งระบบใช้ static const ไม่ใช่ Theme-driven — การสลับธีมจริงต้องไล่แก้แทบทุกไฟล์ UI ในโปรเจกต์ ใหญ่กว่าที่ "เพิ่มหน้าตั้งค่า+3 palette" ฟังดู** | สูง | AI Design ต้องเลือก/ยืนยันแนวทางสถาปัตยกรรม (ดู Architecture Decision) ก่อนเริ่ม Coding จริง ไม่ใช่ปล่อยให้ Coding เจอเองหน้างาน — แนะนำทำเป็น incremental (ไล่แก้ทีละ feature folder พร้อม regression test ทุกรอบ) ไม่ใช่ 1 commit ใหญ่ |
| R2 | ทำธีมตอนที่ UI อื่นยังเปลี่ยนอยู่ (Phase 2) อาจต้องไล่แก้ซ้ำ | กลาง | ทำเป็นงานสุดท้ายของรอบนี้ หลัง Phase 1-2 นิ่งแล้ว (ตามที่ backlog เดิมแนะนำไว้ถูกต้อง) |
| R3 | ธีมดำ ("dark" tokens) ที่มีอยู่แล้วในโค้ดอาจเป็นของเก่าก่อน Sapphire re-brand (2026-08-29) ไม่ตรงกับ design language ปัจจุบัน | ต่ำ-กลาง | AI Design ตรวจสอบ/ออกแบบใหม่ให้สอดคล้อง Sapphire ไม่ใช้ค่าเดิมโดยไม่ตรวจก่อน |
| R4 | Migration เพิ่มคอลัมน์ `theme_preference` ต้องเช็ค production schema จริงก่อน apply | ต่ำ | apply ผ่าน Supabase Dashboard SQL Editor ตรง เหมือนวิธีที่ใช้แก้ WYN-071/072 |

## Recommendation
อนุมัติแนวคิด แต่**ต้องแจ้ง Founder ว่างานนี้ใหญ่กว่าที่ backlog เดิมประเมินไว้อย่างมีนัยสำคัญ** (ไม่ใช่แค่ "เพิ่มหน้าตั้งค่า" แต่เป็นการรีแฟกเตอร์สถาปัตยกรรมสีทั้งแอป) — แนะนำทำเป็นลำดับท้ายสุดของรอบ Beta2 ทั้งหมด (ไม่ใช่แค่ท้ายๆ Phase 3) เพื่อลดการชนกับงานอื่นให้มากที่สุด และควรแบ่งเป็นหลาย PR/commit ทยอยไล่ทีละ feature folder แทนที่จะทำทีเดียวทั้งแอป

## Handoff
ส่งต่อ **AI Design** (`/design`) — งานนี้จำเป็นต้องผ่าน Design เต็มรูปแบบมากที่สุดในกลุ่ม Phase 3 ทั้งหมด: ต้องกำหนด palette 3 ธีมให้ครบทุก token, ตัดสินใจ Architecture Decision (แนวทางสลับธีม), และวางแผนลำดับการไล่แก้ไฟล์ UI ที่ปลอดภัย (ทีละ feature folder + regression test) ก่อนส่งต่อ AI Coding → AI QA (เช็ค contrast/อ่านง่ายทั้ง 3 ธีม + grep หา hardcoded color literal ที่หลงเหลือ เป็นงานตรวจสอบเชิงระบบ ไม่ใช่แค่ตรวจตา)
