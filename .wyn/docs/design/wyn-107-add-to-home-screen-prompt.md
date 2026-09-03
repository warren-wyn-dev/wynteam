# Design Spec — WYN-107: "เพิ่มไปที่หน้าจอหลัก" (Add to Home Screen) Prompt

Owner: AI Design → AI Coding
สถานะ numbering: ตรวจแล้วด้วย `grep -r "WYN-107"`/`wyn-107` ทั้ง repo และไล่ `.wyn/docs/design/wyn-*.md` — เลขสูงสุดที่มีอยู่ตอนนี้คือ WYN-106 (`.wyn/docs/design/wyn-106-feed-native-ads.md`) ไม่พบ WYN-107 ที่ไหนมาก่อน จึงใช้ **WYN-107** — งานนี้ได้รับมอบหมายจาก Founder ตรงมาที่ Design (ไม่มี `.wyn/tasks/backlog/WYN-107-*.md` คู่กัน) เหมือน WYN-106 ก่อนหน้า แนะนำสร้าง task file ย้อนหลังเพื่อ tracking ตาม `WORKFLOW.md` แต่ไม่ใช่สิ่งที่ AI Design ตัดสินใจเอง

Ref: Founder ต้องการทำให้ "Add to Home Screen" เป็นช่องทางกระจายแอปหลักของ WYNOS ตอนนี้ (ยังไม่มี native iOS/Android app จริง — มีแค่ Flutter web build ที่ `wynos.online` ผ่าน Vercel) งานนี้เป็น **design only** ไม่แก้โค้ดใดๆ

โค้ด/เอกสารที่ตรวจแล้วก่อนออกแบบ:
- `app/lib/features/home/presentation/widgets/home_explainer_banner.dart` — banner แบบพื้นเข้ม (`WynColors.ink`) 2 บรรทัด, dismiss-once-total ผ่าน `shared_preferences`, ฝังใน `SliverToBoxAdapter` แถวแรกสุดของ Home feed
- `app/lib/features/profile/presentation/widgets/privacy_notice_banner.dart` — banner แบบพื้นเบา (`colorScheme.surfaceContainer`) บรรทัดเดียว + ไอคอน info + ปิด, parameterized ด้วย `prefsKey`/`message`, dismiss-once-total เช่นกัน คนละ visual treatment จาก `HomeExplainerBanner` โดยตั้งใจ (ดูเหตุผลในหัวข้อ "ทิศทางภาพรวม" ด้านล่าง)
- `app/lib/features/home/presentation/home_feed_screen.dart` (บรรทัด 766-785) — ตำแหน่งจริงที่ `HomeExplainerBanner` ถูก mount เป็น sliver แรกสุดเหนือ Feed Mode Toggle
- `app/web/index.html` — มี `mobile-web-app-capable`, `apple-mobile-web-app-title` ("WYNOS Beta"), `apple-touch-icon` ครบแล้ว (ยืนยันจาก screenshot ของ Founder ว่า iOS Safari's Add to Home Screen อ่านชื่อ/ไอคอนถูกต้องแล้ว)
- `app/web/manifest.json` — `"display": "standalone"`, icon set ครบ 4 ขนาด (192/512 ปกติ+maskable) — Android/Chrome ใช้งานได้แล้ว
- `.wyn/company/DECISIONS.md` (2026-08-30, Apple Developer Program): "WYNOS ยังอยู่ในรูปแบบ Web App (PWA) บน iOS Safari เท่านั้น" — ยืนยันกรอบเดียวกับที่บรีฟนี้ตั้งไว้
- `app/lib/main.dart:66` — precedent เดียวที่มีอยู่จริงของ `kIsWeb` (ไม่ใช่ `settings_screen.dart` ตามที่บรีฟอ้างถึง — ตรวจแล้วไฟล์นั้นไม่มี `kIsWeb`/`defaultTargetPlatform` เลย ระบุไว้ตรงๆ กันสับสน) — ไม่มี `defaultTargetPlatform`/UA-sniffing precedent ใดๆ ในโค้ดเบสนี้เลย นี่คือพื้นที่ใหม่ทั้งหมด (ดู Handoff ข้อ 1)
- `.wyn/docs/design/wyn-046-platform-documents-acceptance.md` — precedent ของ full-screen **blocking** gate (ใช้เมื่อจำเป็นทางกฎหมายเท่านั้น) และ `.wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md` — precedent ของ `AlertDialog` สำหรับ "ขัดจังหวะสั้นๆ ให้ตัดสินใจ" ทั้งสองเป็นตัวอย่างของสิ่งที่งานนี้ **ไม่ควรเป็น** (ดูเหตุผลด้านล่าง)
- `app/lib/features/account_switcher/presentation/account_switcher_sheet.dart` — รูปแบบ `showModalBottomSheet` มาตรฐานของแอปนี้ (`isScrollControlled: true`, `backgroundColor: WynColors.paper`, มุมบนโค้ง `WynSpacing.radiusLg`) ใช้เป็นต้นแบบของ sheet ในงานนี้
- `app/lib/features/settings/presentation/settings_screen.dart` (บรรทัด 184-245) — โครงสร้าง `_GroupLabel`/`_SettingsRow` ของหน้า "ตั้งค่า" หลัก มี group "การตั้งค่าแอป" และ "ช่วยเหลือ" อยู่แล้ว
- `app/lib/core/design/wyn_colors.dart` / `wyn_spacing.dart` / `wyn_typography.dart` — reuse token เดิมทั้งหมด ไม่มีทิศทาง visual ใหม่

---

## ทิศทางภาพรวม: 2 ส่วนประกอบ ไม่ใช่ banner เดียว — เหตุผลที่ banner 2 บรรทัดไม่พอ

`HomeExplainerBanner` เป็น banner 2 บรรทัดสั้นๆ ที่พอสำหรับสื่อ concept เดียว ("ดู → แชร์ → ค้นพบ → ซื้อ") แต่งานนี้ต้องสอนขั้นตอนจริงที่ต่างกันตามแพลตฟอร์ม (iOS Safari 3 ขั้นตอน / Android Chrome 3 ขั้นตอน) — ยัดเข้า banner 2 บรรทัดจะอ่านไม่ทันหรือถูกตัดทอนจนไม่มีประโยชน์ ดังนั้นงานนี้แบ่งเป็น **banner (ทางเข้า/teaser) + bottom sheet (เนื้อหาขั้นตอนเต็ม)**:

1. **Banner** — บรรทัดเดียว, มิเรอร์ `PrivacyNoticeBanner` (พื้นเบา `surfaceContainer` + ไอคอน + ปิด) **ไม่ใช่** `HomeExplainerBanner` (พื้นเข้ม `ink`) — เหตุผล 2 ข้อ: (a) `HomeExplainerBanner` เป็น banner เข้มที่สื่อ "แก่นของผลิตภัณฑ์" ตั้งใจให้เด่นที่สุดในฟีด ส่วนนี้เป็นแค่ tip เชิง utility ระดับเดียวกับ privacy notice ไม่ควรแย่งความสนใจเท่ากัน (b) ถ้าใช้พื้นเข้มซ้ำกันสองอันติดกันบนสุดของ Home ผู้ใช้ใหม่จะเจอ "กำแพงข้อความ" สีเข้ม 2 ก้อนตั้งแต่เปิดแอปครั้งแรก ขัดกับหลัก "ลด friction" ของแอปนี้
2. **Bottom Sheet** — เปิดจากการแตะ banner เท่านั้น มีพื้นที่พอสำหรับขั้นตอนแบบมีไอคอนประกอบครบ ปิดได้ตลอดเวลา (swipe ลง/แตะพื้นหลัง/ปุ่มปิด) — **ไม่ใช่ modal ที่บล็อกอะไร** ต่างจาก `DocumentAcceptanceScreen` (บังคับกฎหมาย) และไม่ใช่ `AlertDialog` แบบ WYN-072's Guest Gate (ขัดจังหวะให้ตัดสินใจ 2 ทาง) — ที่นี่ไม่มี "ทางเลือกที่ต้องตัดสินใจ" เลย ผู้ใช้แค่มาอ่านวิธีทำแล้วปิดเอง เหมือนที่ `AccountSwitcherSheet`/`RedropSheet` เป็นอยู่แล้วทุกวันนี้

**ไม่มีทิศทาง visual ใหม่ในงานนี้เลย** — สี/spacing/typography ทุกจุด reuse token เดิมจาก `WynColors`/`WynSpacing`/`WynTypography` ตามกติกา AI Design (ห้ามคิด direction ใหม่เมื่อมี design system อนุมัติแล้ว)

---

## Screen 1: Home Feed — Add-to-Home-Screen Banner (ทางเข้า)

Purpose: บอกผู้ใช้แบบเบาๆ ว่ามีวิธีเพิ่ม WYNOS ไว้ที่หน้าจอหลักได้ พร้อมทางเข้าไปดูวิธีทำแบบเต็ม

User Flow: เปิด Home (บนเบราว์เซอร์ web ที่รองรับและยังไม่ได้ติดตั้ง) → เห็น banner บางๆ ใต้ `HomeExplainerBanner` (หรือแทนที่ตำแหน่งนั้นถ้า `HomeExplainerBanner` ถูกปิดไปแล้ว — ดู Design Rules) → แตะที่ตัว banner (ไม่ใช่ปุ่มปิด) → เปิด Bottom Sheet (Screen 2) → หรือแตะปุ่มปิด (X) → banner หายไปถาวร ไม่กลับมาอีก (เหมือน `HomeExplainerBanner`/`PrivacyNoticeBanner` ทุกจุด)

Components:
- Container พื้นหลัง `Theme.of(context).colorScheme.surfaceContainer` (มิเรอร์ `PrivacyNoticeBanner` เป๊ะ) มุมโค้ง `WynSpacing.radiusMd` margin `EdgeInsets.fromLTRB(space4, space2, space4, 0)` padding `EdgeInsets.all(space3)`
- ไอคอนนำหน้า: `Icons.add_to_home_screen` ขนาด 18px สี `colorScheme.onSurfaceVariant` (แทนที่ `Icons.info_outline` ของต้นแบบ — สื่อความหมายเฉพาะของ action นี้ตรงกว่า generic info icon)
- ข้อความบรรทัดเดียว (ตัด ellipsis ถ้าจอแคบมาก): **"เพิ่ม WYNOS ไว้ที่หน้าจอหลัก เข้าเร็วขึ้นเหมือนเปิดแอปจริง · แตะเพื่อดูวิธี"** สไตล์ `textTheme.bodySmall`
- ปุ่มปิด (X) ขนาด 16px มุมขวา — แตะเพื่อ dismiss เท่านั้น ไม่เปิด sheet (ต้องเป็นพื้นที่แตะแยกจากตัว banner ที่เหลือ ไม่ให้แตะ X แล้วเผลอเปิด sheet)

Interactions:
- แตะพื้นที่ banner (ยกเว้นปุ่ม X) → `showModalBottomSheet` เปิด Screen 2 — **ไม่ snooze banner ทันทีตอนแตะ**
- แตะ X → **Founder ยืนยันแล้ว (2026-09-03, Open Question ข้อ 2): ไม่ใช่ dismiss ถาวร** — เขียนค่า `shared_preferences` เป็น `lastSnoozedAt = DateTime.now()` (ไม่ใช่ boolean `dismissed`) banner หายจากจอด้วย `setState` ทันที แล้ว**กลับมาแสดงใหม่อัตโนมัติหลังจากผ่านไป `kSnoozeDuration` (แนะนำ 7 วัน — ค่าคงที่ปรับได้ทีหลังโดยไม่ต้อง migrate schema)** นับจากครั้งล่าสุดที่ปิด — เหตุผลที่เลือก 7 วัน: ยาวพอไม่ให้รู้สึกโดนรบกวนถี่เกินไป (ต่างจาก tip ทั่วไป นี่คือช่องทางกระจายแอปหลัก) แต่สั้นพอที่จะเจอผู้ใช้อีกครั้งในสัปดาห์ถัดไปที่ยังไม่ได้ติดตั้งจริง — Founder ปรับตัวเลขนี้ได้ทีหลังหาก 7 วันถี่/ห่างเกินไปจากข้อมูลจริง โดยไม่กระทบโครงสร้าง
- **จุดหยุดแสดงถาวรจริงมีทางเดียวเท่านั้น: ตรวจพบ standalone mode แล้ว** (ติดตั้งสำเร็จจริง) — ไม่มี "ปิดไม่ต้องถามอีก" แบบถาวรที่ผู้ใช้กดเลือกเองได้ เพราะนี่คือช่องทางกระจายแอปหลักตอนนี้ ไม่ใช่ tip ทั่วไปแบบ `HomeExplainerBanner`/`PrivacyNoticeBanner`

States:
- Hidden (default จนกว่า platform-check + pref-check จะ resolve ครบ — ไม่กระพริบ visible-then-hidden เหมือน `HomeExplainerBanner`/`PrivacyNoticeBanner`)
- Visible (เงื่อนไขครบตาม Design Rules)
- Snoozed (ซ่อนชั่วคราวจนครบ `kSnoozeDuration` นับจาก `lastSnoozedAt` — **ไม่ใช่สถานะถาวร** ต่างจาก `HomeExplainerBanner`/`PrivacyNoticeBanner` โดยตั้งใจ ตาม Founder's decision)

Responsive Behavior: เต็มความกว้างจอเสมอ (มือถือเท่านั้นในทางปฏิบัติ เพราะ desktop ไม่แสดงเลย — ดู Design Rules) ข้อความตัด ellipsis ไม่ wrap 2 บรรทัด (คงความเป็น "แถบบาง" ไว้)

Accessibility: `Semantics(label: 'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก แตะเพื่อดูวิธีทำ', button: true)` ครอบพื้นที่ banner หลัก, ปุ่ม X มี `Semantics(label: 'ปิดข้อความแนะนำ', button: true)` แยกจากกันชัดเจน (เหมือน `HomeExplainerBanner` ทำอยู่แล้ว)

Design Rules:
- **แสดงเฉพาะเมื่อครบทุกเงื่อนไข**: (1) `kIsWeb == true` (2) ตรวจแล้วว่า**ไม่ได้รันอยู่ในโหมด standalone** (ดู Handoff ข้อ 1 — เป็น hard requirement, ไม่ใช่ nice-to-have) (3) ตรวจแพลตฟอร์มแล้วได้ iOS Safari หรือ Android Chrome เท่านั้น (ไม่ใช่ desktop/ตรวจไม่ได้ — ดู Screen 2's "ขอบเขต Desktop") (4) ยังไม่เคยถูก snooze มาก่อน **หรือ** `DateTime.now().difference(lastSnoozedAt) >= kSnoozeDuration` (7 วัน)
- **แสดงหลังจาก `HomeExplainerBanner` ถูกปิดไปแล้วเท่านั้น** — เช็คค่า `shared_preferences` ของ `HomeExplainerBanner` ก่อนตัดสินใจแสดง banner นี้ เพื่อไม่ให้ผู้ใช้ใหม่เจอ banner พื้นเข้ม + พื้นเบาพร้อมกันตั้งแต่เปิดแอปครั้งแรก (ดู Handoff ข้อ 2 สำหรับวิธี implement โดยไม่ต้อง hardcode string key ซ้ำ)
- ตำแหน่ง: sliver ถัดจาก `HomeExplainerBanner` เดิม (ก่อน `_FeedModeToggleHeaderDelegate`) — ไม่ pin, เลื่อนหายไปพร้อมเนื้อหาด้านบนเหมือน `HomeExplainerBanner`
- **ไม่แสดงซ้ำใน session เดียวกันถ้าปิด sheet ไปแล้วโดยไม่กด X** — banner ยังอยู่ (ผู้ใช้เห็นได้ถ้าเลื่อนกลับขึ้นมาบนสุด) แต่ **ไม่ auto-reopen sheet เอง** ไม่ว่ากรณีใด

---

## Screen 2: "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" — Bottom Sheet (ขั้นตอนเต็ม)

Purpose: สอนขั้นตอนจริงตามแพลตฟอร์มที่ตรวจพบ ให้ผู้ใช้ทำตามได้จริงโดยไม่ต้องเดา

User Flow: แตะ banner (Screen 1) → sheet เลื่อนขึ้นจากด้านล่าง แสดงหัวข้อ + ขั้นตอนของแพลตฟอร์มที่ตรวจพบ (iOS Safari **หรือ** Android Chrome — แสดงชุดเดียวตามที่ตรวจจับได้จริง ไม่ใช่ทั้งสองชุดพร้อมกัน) → อ่านจบ → ปิดผ่าน swipe ลง/แตะพื้นหลัง/ปุ่มปิด → กลับสู่ Home ปกติ ไม่มีอะไรเปลี่ยนแปลง

Components:
- `showModalBottomSheet(isScrollControlled: true, backgroundColor: WynColors.paper, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WynSpacing.radiusLg))))` — มิเรอร์ `AccountSwitcherSheet`'s wrapper เป๊ะ
- Drag handle บางๆ กลางบนสุด (แถบเทา `WynColors.hairline` กว้าง ~36px สูง 4px, มุมโค้งเต็ม) — สื่อว่า swipe ลงเพื่อปิดได้ (ไม่มี precedent เป๊ะในแอปนี้ที่ตรวจแล้ว แต่เป็น Material bottom-sheet convention มาตรฐานที่ไม่ขัดกับ design-principles ใดๆ — ทางเลือกแทนคือไม่มี handle เลยแล้วพึ่งพฤติกรรม default ของ `showModalBottomSheet` เอง ให้ Coding เลือกได้ ไม่ใช่จุดตัดสินใจสำคัญ)
- หัวข้อ: **"เพิ่ม WYNOS ไว้ที่หน้าจอหลัก"** สไตล์ `WynTypography.screenTitle(fontSize: 18)` สี `WynColors.ink`
- คำอธิบายรอง 1 บรรทัด ใต้หัวข้อ สี `WynColors.graphite` `bodyMedium`: **"เปิดใช้งานได้เร็วเหมือนแอปจริง ไม่ต้องเปิดเบราว์เซอร์ใหม่ทุกครั้ง"**
- รายการขั้นตอน (`Column` แนวตั้ง, เว้นระยะ `WynSpacing.space4` ระหว่างขั้นตอน) — แต่ละขั้นตอนเป็น `Row`: เลขที่ขั้นตอนในวงกลม (พื้น `WynColors.surfaceTint`, ตัวเลข `WynColors.ink` `labelLarge`) + ไอคอนประกอบ (18-20px, `WynColors.graphite`) + ข้อความอธิบาย (`bodyMedium`, `WynColors.ink`)
- ปุ่มปิดด้านล่างสุด: `TextButton` เต็มความกว้าง ข้อความ **"เข้าใจแล้ว"** สี `WynColors.graphite` (ไม่ใช่ `FilledButton` สี sapphire เพราะไม่มี "การกระทำ" ให้ทำต่อ แค่ปิดการอ่าน เหมือนปุ่มปิดของ dialog ข้อมูลทั่วไป)

**เนื้อหาขั้นตอน — iOS Safari:**
1. ไอคอน `Icons.ios_share` — "แตะไอคอน **แชร์** (กล่องมีลูกศรชี้ขึ้น) ที่แถบด้านล่างของ Safari"
2. ไอคอน `Icons.add_to_home_screen` — "เลื่อนหาแล้วแตะ **เพิ่มไปยังหน้าจอโฮม** (Add to Home Screen)"
3. ไอคอน `Icons.check_circle_outline` — "แตะ **เพิ่ม** ที่มุมขวาบน เป็นอันเสร็จ"

**เนื้อหาขั้นตอน — Android Chrome:**
1. ไอคอน `Icons.more_vert` — "แตะไอคอนจุดสามจุด (⋮) มุมขวาบนของ Chrome"
2. ไอคอน `Icons.install_mobile` — "แตะ **ติดตั้งแอป** หรือ **เพิ่มไปยังหน้าจอหลัก** (ข้อความอาจต่างกันเล็กน้อยตามเวอร์ชัน Chrome)"
3. ไอคอน `Icons.check_circle_outline` — "แตะ **ติดตั้ง**/**เพิ่ม** เพื่อยืนยัน เป็นอันเสร็จ"

States:
- Loaded เดียว — ไม่มี loading/error state (เนื้อหาเป็น static copy ล้วน ไม่มีการเรียก network/API ใดๆ)
- ถ้าตรวจแพลตฟอร์มไม่ได้ชัดเจน (UA sniffing ล้มเหลว/ไม่ match ทั้ง iOS/Android) → **sheet นี้จะไม่ถูกเปิดเลยตั้งแต่ต้น** เพราะ Screen 1's banner ก็ไม่แสดงในกรณีนั้นอยู่แล้ว (fail-closed ทั้งระบบ — ดู Design Rules ของ Screen 1 และ Handoff ข้อ 1)

Responsive Behavior: `isScrollControlled: true` ทำให้ sheet ขยายสูงตามเนื้อหาได้โดยไม่ถูกจอเตี้ยบีบ, เนื้อหาอยู่ใน `SingleChildScrollView` กันกรณีจอเตี้ยผิดปกติ/font scale ใหญ่ทำให้ล้น

Accessibility: หัวข้อ sheet ต้องเป็น focus แรกที่ screen reader อ่านเมื่อ sheet เปิด (default behavior ของ `showModalBottomSheet`), แต่ละขั้นตอนมี Semantics รวมเป็นประโยคเดียว (เช่น `"ขั้นตอนที่ 1: แตะไอคอนแชร์ที่แถบด้านล่างของ Safari"`) ไม่แยกอ่านเลขวงกลม/ไอคอน/ข้อความเป็น 3 ส่วน, ปุ่ม "เข้าใจแล้ว" สูงไม่ต่ำกว่า `WynSpacing.touchTargetMin`

Design Rules:
- **แสดงชุดขั้นตอนเดียวตามแพลตฟอร์มที่ตรวจพบจริง ไม่ใช่ทั้งสองชุด/ให้ผู้ใช้เลือกเอง** — ผู้ใช้ไม่รู้ว่าตัวเอง "อยู่บนแพลตฟอร์มไหน" ในเชิงเทคนิค การให้เลือกเองเพิ่ม friction โดยไม่จำเป็นในเมื่อตรวจอัตโนมัติได้แม่นยำพออยู่แล้ว (ดู Handoff ข้อ 1 เรื่องความแม่นยำของการตรวจ)
- **ขอบเขต Desktop — ไม่แสดง banner/sheet นี้เลยบน desktop browser** (คำแนะนำจาก AI Design ไม่ใช่คำสั่งที่ยืนยันแล้ว — ดู Open Questions ข้อ 3): เหตุผล (a) WYNOS ประกาศตัวเป็น mobile-first app อยู่แล้ว (`app/web/index.html`'s meta description: "mobile social app for Gen Z") คุณค่าของ "เพิ่มไปที่หน้าจอหลัก" อ่อนกว่ามากบน desktop ที่มี bookmark/tab อยู่แล้วเป็นทางเลือกที่สะดวกพอๆ กัน (b) UI การติดตั้งบน desktop ต่างกันมากระหว่าง Chrome (ไอคอนติดตั้งใน address bar)/Edge/Firefox (ไม่รองรับ PWA install ที่ดีเท่า) — เพิ่ม branch ที่ 3 เพิ่มความซับซ้อนและความเสี่ยงบอกขั้นตอนผิดสำหรับกลุ่มผู้ใช้ที่ไม่ใช่กลุ่มเป้าหมายหลักของ WYNOS
- **ห้ามใช้ Liquid Glass/พื้นผิวโปร่งแสง** บน sheet นี้ (กติกาตายตัวของทั้งแอป) — พื้นหลังทึบ `WynColors.paper` เสมอ
- ห้ามเพิ่ม CTA ปิด sheet แบบ "ปิดถาวร ไม่ต้องถามอีก" ใดๆ ทั้งสิ้น (ไม่ใช่แค่ในนี้ — ทั่วทั้งฟีเจอร์นี้ไม่มีปุ่ม "ไม่อยากเห็นอีก" แบบถาวรเลย ตาม Founder's decision ข้อ Persistence: จุดหยุดแสดงถาวรมีทางเดียวคือตรวจพบ standalone mode จริง) sheet ปิดได้ปกติ (swipe/แตะพื้นหลัง/ปุ่มปิด) แต่ไม่ส่งผลต่อ snooze ของ banner

---

## Component เสริม: Settings — แถวทางเข้าถาวร ("ช่วยเหลือ" group)

Purpose: ให้ผู้ใช้ที่กด X ปิด banner ไปแล้ว (อยู่ระหว่างช่วง snooze 7 วัน) หรือพลาดเห็นตอนแรก ยังหาวิธีติดตั้งได้ทันทีโดยไม่ต้องรอ banner กลับมาเอง

Components: เพิ่ม `_SettingsRow` ใหม่ 1 แถวใน `SettingsScreen.build()` (`app/lib/features/settings/presentation/settings_screen.dart`) ภายใต้ group **"ช่วยเหลือ"** (บรรทัด 233-245 ปัจจุบัน) วางไว้**ก่อน**แถว "ช่วยเหลือ" เดิม (เป็นเรื่อง how-to เฉพาะเจาะจงกว่า generic help):
```
_SettingsRow(
  icon: Icons.add_to_home_screen,
  label: 'เพิ่มไปที่หน้าจอหลัก',
  onTap: () => <เปิด Bottom Sheet เดียวกับ Screen 2>,
)
```

Interactions: แตะ → เปิด sheet เดียวกับ Screen 2 ทุกประการ (reuse widget เดียวกัน ไม่สร้างสำเนา)

Design Rules:
- **แถวนี้แสดงเงื่อนไขเดียวกับ banner** (kIsWeb + ไม่ standalone + ตรวจแพลตฟอร์มได้ iOS/Android) — **ไม่ผูกกับสถานะ dismissed ของ banner** (ผู้ใช้ที่ปิด banner ไปแล้วต้องยังเห็นแถวนี้ได้เสมอ ไม่งั้นจะหาทางกลับมาดูขั้นตอนไม่ได้เลย ขัดกับ Purpose ของ component นี้)
- ถ้าเข้าเงื่อนไข standalone แล้ว (ติดตั้งไปแล้วจริง) → **ซ่อนแถวนี้ทั้งแถวไปเลย** ไม่ใช่แสดงแล้ว disable (ไม่มีอะไรให้ทำต่อสำหรับคนที่ติดตั้งแล้ว)

---

## Platform Detection — ข้อกำหนดทางเทคนิคที่ต้องส่งต่อ AI Coding

**นี่คือ hard requirement ของทั้งงาน ไม่ใช่ nice-to-have — Screen 1/2/Settings row ทั้งหมดพึ่งพาผลลัพธ์นี้เป็นเงื่อนไขแสดงผล**

1. **Standalone-mode detection (ต้องตรวจถูกต้อง 100% ก่อนแสดงอะไรเลย)**: เช็คว่าแอปกำลังรันจากไอคอนที่ผู้ใช้เพิ่มไว้แล้วหรือไม่ ผ่าน `window.matchMedia('(display-mode: standalone)').matches` (มาตรฐาน, ใช้ได้ทั้ง Android Chrome และ iOS Safari รุ่นใหม่) **และ** iOS-specific `navigator.standalone` (iOS Safari เก่ากว่ายังต้องพึ่งค่านี้ ไม่รับประกันว่า `matchMedia` ครอบคลุมเสมอ) — **ทั้งสอง API เป็น browser JS API ล้วนๆ ไม่มี Flutter/Dart equivalent ให้เรียกตรงๆ** ต้องเขียน **platform-interop shim ใหม่** (ไม่มี precedent เดิมในโค้ดเบสนี้เลย — ตรวจแล้วไม่มี `dart:html`/`dart:js_interop`/`package:web` ใช้อยู่ที่ไหนในแอปนี้มาก่อน)
2. **Browser/platform detection (iOS Safari / Android Chrome / อื่นๆ)**: **ห้ามพึ่ง `defaultTargetPlatform` เพียงอย่างเดียว** — Flutter Web's `defaultTargetPlatform` ใช้ heuristic ตรวจ user agent ที่ไม่แม่นยำพอสำหรับ use case นี้ (รู้กันในหมู่ Flutter web ว่า desktop browser ที่ไม่ใช่ iOS/macOS มักถูกจัดเป็น `TargetPlatform.android` โดย fallback ของ engine เอง ซึ่งจะทำให้ desktop Chrome ถูกเข้าใจผิดว่าเป็น Android Chrome และเห็น banner/สอนขั้นตอนผิดทันที) — Coding ต้อง**ตรวจ `navigator.userAgent` ตรงๆ ผ่าน JS interop เดียวกันกับข้อ 1** (bundle รวมเป็น shim เดียวกัน คืนค่า enum เช่น `{iosSafari, androidChrome, desktopOrOther}`) ก่อนตัดสินใจแสดง banner/เนื้อหาไหน
3. **ตรวจสอบ platform ก่อน render ทุกครั้งที่ widget mount** (ไม่ cache ข้าม session ผ่าน `shared_preferences` — standalone status เปลี่ยนได้ทุกครั้งที่ผู้ใช้ติดตั้งจริงระหว่างเซสชัน ต้องเช็คสดเสมอ ต่างจาก dismissed-flag ที่ persist ได้)
4. **Fail-closed เสมอ**: ถ้า JS interop เรียกไม่สำเร็จ/ตรวจแพลตฟอร์มไม่ได้ (เช่น environment แปลกๆ, headless test) → **ไม่แสดงอะไรเลยทั้ง banner และ settings row** — ปลอดภัยกว่าการเดาแล้วโชว์ผิด (สอดคล้องกับหลัก "โฆษณาที่ไม่พร้อม = ไม่มีอยู่" ของ WYN-106 — ที่นี่คือ "ตรวจแพลตฟอร์มไม่ได้ = เหมือนไม่มีฟีเจอร์นี้อยู่")

---

## Open Questions — ตัดสินใจแล้วโดย Founder (2026-09-03)

1. **Timing/audience**: ✅ **ให้ guest เห็นด้วย** ยืนยันตามคำแนะนำ
2. **Persistence model**: ✅ **โผล่ซ้ำเป็นระยะจนกว่าจะติดตั้งจริง** (ไม่ใช่ dismiss-once-forever ตามที่ AI Design แนะนำไว้เดิม) — แก้ไขทั้งฉบับด้านบนแล้วให้สอดคล้อง: ปุ่ม X = snooze `kSnoozeDuration` (ตั้งเป็น **7 วัน** เป็นค่าเริ่มต้น ปรับได้ทีหลังโดยไม่กระทบโครงสร้าง) ไม่ใช่ dismiss ถาวร จุดหยุดแสดงถาวรจริงมีทางเดียวคือตรวจพบ standalone mode
3. **ขอบเขต Desktop**: ✅ **ไม่แสดงเลยบน desktop** ยืนยันตามคำแนะนำ

---

## Handoff

**Open Questions ข้อ 1-3 ตัดสินใจครบแล้วโดย Founder (2026-09-03) — ส่งต่อ AI Coding ได้:**

1. **Platform-interop shim ใหม่** (แนะนำ `app/lib/core/web/home_screen_platform.dart` + conditional import คู่ `_home_screen_platform_web.dart`/`_home_screen_platform_stub.dart` ตามแบบ pattern มาตรฐานของ Dart conditional-import สำหรับโค้ดที่ต้องแยก web/non-web — ไม่มี precedent เดิมในแอปนี้ ต้องสร้างใหม่ทั้งหมด): expose อย่างน้อย `bool isRunningStandalone()` และ enum detection เช่น `WebPlatformKind detectWebPlatformKind()` ({iosSafari, androidChrome, desktopOrOther}) ผ่าน `package:web`/`dart:js_interop` (แนะนำมากกว่า `dart:html` ที่เป็น legacy API) — ดูรายละเอียดข้อกำหนดเต็มในหัวข้อ "Platform Detection" ด้านบน ต้อง fail-closed เสมอเมื่อเรียกไม่สำเร็จ
2. **`HomeExplainerBanner`'s prefs key ต้อง public** — เปลี่ยน `HomeExplainerBanner._prefsKey` (private) เป็น `HomeExplainerBanner.prefsKey` (public static const) เพื่อให้ widget ใหม่ใน Screen 1 อ่านค่านี้ได้โดยไม่ hardcode string literal ซ้ำ (ป้องกัน key สอง copy ที่อาจ drift กันในอนาคต)
3. Widget ใหม่ (แนะนำ `AddToHomeScreenBanner`, ที่ `app/lib/features/home/presentation/widgets/`) ตาม Screen 1 — mount เป็น sliver ถัดจาก `HomeExplainerBanner` ใน `home_feed_screen.dart` (บรรทัด ~774 ปัจจุบัน)
4. Widget/ฟังก์ชันใหม่เปิด sheet (แนะนำ `showAddToHomeScreenSheet(context)` ที่ `app/lib/features/home/presentation/widgets/add_to_home_screen_sheet.dart` มิเรอร์ `showAccountSwitcherSheet` เป๊ะ) ตาม Screen 2 — เนื้อหา 2 ชุด (iOS/Android) ตามที่ระบุไว้ข้างบน คำต่อคำ **ห้ามแก้คำแปล/ลำดับขั้นตอนเอง** ถ้าต้องปรับ ให้กลับมาที่ AI Design ก่อน
5. `settings_screen.dart`: เพิ่ม `_SettingsRow` ใหม่ตาม Component เสริมด้านบน เรียก `showAddToHomeScreenSheet` เดียวกับข้อ 4 (**ห้าม copy เนื้อหา sheet ซ้ำ**)
6. Unit test ของ platform-interop shim (ข้อ 1): ต้อง fake/mock ผลลัพธ์ของ `matchMedia`/`navigator.standalone`/`userAgent` ได้ (แนะนำ inject เป็น parameter/interface แทนเรียก global โดยตรง เพื่อให้ test ได้โดยไม่ต้องพึ่ง browser จริง) — เขียน regression test อย่างน้อย: (a) standalone == true → banner/settings row ไม่แสดง (b) UA ตรวจไม่ได้ → fail-closed ไม่แสดง (c) iOS UA → เนื้อหาชุด iOS เท่านั้น (d) Android UA → เนื้อหาชุด Android เท่านั้น
7. Widget test: banner ไม่แสดงก่อนที่ `HomeExplainerBanner` ถูกปิด (ข้อ 2 ของ Screen 1's Design Rules), banner หายทันทีหลังแตะ X แล้ว**กลับมาแสดงใหม่เมื่อ `lastSnoozedAt` เก่ากว่า `kSnoozeDuration`** (ใช้ fake/injectable clock ใน test ไม่ใช่ `DateTime.now()` จริง เพื่อไม่ต้องรอ 7 วันจริงตอนรัน test), banner **ยังไม่กลับมาถ้ายังไม่ครบ 7 วัน**, แตะ banner (ไม่ใช่ X) เปิด sheet ได้จริงโดยไม่ยุ่งกับ snooze, settings row แสดง/ซ่อนตามเงื่อนไข standalone อิสระจากสถานะ snooze ของ banner (เห็นได้เสมอไม่ว่า banner จะ snooze อยู่หรือไม่)
8. `flutter analyze`/`flutter test` เต็ม suite ต้องผ่าน ไม่มี regression กับ `home_feed_screen_test.dart`/`settings_screen_test.dart` เดิม (ถ้ามี)
9. QA ต้องตรวจเพิ่มเติมเฉพาะงานนี้: ทดสอบจริงบน iOS Safari (banner ขึ้น → sheet ขึ้นขั้นตอน iOS → ทำตามจริงแล้วติดตั้งสำเร็จ → เปิดจากไอคอนหน้าจอหลัก → banner/settings row ต้องหายไปเพราะตรวจ standalone ได้ถูกต้อง), ทดสอบเดียวกันบน Android Chrome, ทดสอบว่า desktop Chrome/Safari ไม่เห็น banner เลย (ถ้า Founder ยืนยัน Open Question ข้อ 3 ตามคำแนะนำ), ทดสอบ contrast/ขนาดตัวอักษรของ banner/sheet ที่ 360px viewport

ต้องผ่าน QA & Security ก่อน deploy เสมอ — งานนี้ไม่แตะ database/RLS/auth ใดๆ เลย (เป็น client-side UI + JS interop ล้วนๆ) จึงไม่มีความเสี่ยงด้าน data security แต่ยังต้องผ่านการตรวจสอบมาตรฐานตาม `WORKFLOW.md`
