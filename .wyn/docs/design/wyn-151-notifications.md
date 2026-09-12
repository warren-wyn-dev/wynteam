# WYN "Flare" — Notifications (V1.0 — PROPOSED)

Status: PROPOSED
Owner: AI Design
อ้างอิง: wyn-142-visual-identity-redesign.md, wyn-143-core-component-library.md

> เอกสารนี้เป็นการ **reskin หน้าจอ Notifications ที่มีอยู่แล้ว** (`app/lib/features/notification/presentation/notification_list_screen.dart`) ให้ใช้ token/คอมโพเนนต์ของ Flare (wyn-142/wyn-143) เท่านั้น **ไม่เปลี่ยน business logic** — การนำทาง (tap destination), การ group แถว, การ mark-as-read timing, จำนวน type การแจ้งเตือน, เนื้อหาข้อความ (`_messageFor`) และ pagination/tab behavior ทั้งหมดคงเดิมตามที่อ่านได้จากโค้ดจริง เว้นแต่จุดที่ระบุชัดว่าเป็น "ข้อเสนอเพิ่มเติม (แนะนำ)" ซึ่งเป็นการปรับปรุงด้าน visual clarity/accessibility เท่านั้น ไม่ใช่ feature ใหม่ และรอ Founder ตัดสินใจว่าจะรับหรือไม่

## Screen:

Notification List — หน้าจอที่ 4 ของ Bottom Tab Bar ("Notifications" ตาม wyn-143 §3 Bottom Tab Bar)

## Purpose:

แสดงการแจ้งเตือนทั้งหมดของผู้ใช้ (social engagement, Club activity, ระบบ/moderation, message/follow request) ในลิสต์เดียว ให้ผู้ใช้สแกนเห็นความเคลื่อนไหวที่เกี่ยวกับตัวเองอย่างรวดเร็ว แยกแยะ "ประเภท" ของแต่ละแจ้งเตือนได้ด้วยสายตาโดยไม่ต้องอ่านข้อความเต็ม และแตะเพื่อไปยังปลายทางที่ถูกต้องของแจ้งเตือนแต่ละประเภท

## User Flow:

1. ผู้ใช้แตะ tab "Notifications" บน Bottom Tab Bar → เข้าหน้านี้
2. ระบบโหลดหน้าแรก (page 0) → แสดง Skeleton loading → เติมลิสต์ →ยิง mark-all-as-read แบบ fire-and-forget เบื้องหลัง (ไม่รอผล ไม่บล็อก UI)
3. ผู้ใช้เห็น: การ์ดขอสิทธิ์แจ้งเตือน (ถ้ายังไม่ได้ตอบ/ยังมีเหตุผลให้ถาม) → Tab "ทั้งหมด"/"การกล่าวถึง" → ลิสต์แบ่งกลุ่มตามวัน (วันนี้/เมื่อวานนี้/เก่ากว่านี้)
4. ผู้ใช้เลื่อนลง → โหลดหน้าถัดไปอัตโนมัติเมื่อใกล้ถึงจุดสิ้นสุด (infinite scroll)
5. ผู้ใช้แตะแถวแจ้งเตือน → นำทางไปปลายทางตามประเภท (Drop detail, Pop unavailable, Profile, Club, Club post detail, Moderation action screen, Conversation, Follow request list, หรือไม่มีปลายทาง)
6. ผู้ใช้ pull-to-refresh → โหลดหน้าแรกใหม่ทั้งหมด (reset pagination)
7. ผู้ใช้สลับ tab "การกล่าวถึง" → กรอง client-side จากลิสต์ที่โหลดมาแล้ว (ไม่ fetch ใหม่ ไม่มี pagination ของตัวเอง)

## Components:

อ้างอิงจาก wyn-143 เท่านั้น ยกเว้นจุดที่ระบุว่าเป็น screen-specific component ใหม่ (มีเหตุผลระบุชัดตามกติกา Handoff ของ wyn-143)

- **Top App Bar** (wyn-143 §3): height 56px, leading = ปุ่ม hamburger (เปิด Side Menu), title "การแจ้งเตือน" ชิดซ้าย `type.display.l` (ไม่ centered ตามกติกาใหม่ — เปลี่ยนจากของเดิมที่ centered), trailing = ปุ่มค้นหา 44×44px เปิด Search screen พื้นหลัง `color.paper` + เส้น `color.hairline` ด้านล่าง
- **Card** (wyn-143 §4) — ใช้กับการ์ดขอสิทธิ์แจ้งเตือน (Push permission card): พื้นหลัง `color.surface`, radius `radius.m`, มีไอคอน + ข้อความสั้น + ปุ่ม Text Button "เปิดการแจ้งเตือน" (accent) และปุ่มปิด (×) มุมขวาบน ขนาดแตะ 44×44px แสดงเฉพาะเมื่อมีเหตุผลให้ถามจริง (ตาม logic เดิมของ `PushPermissionCard`) ไม่แสดงเปล่า/ค้าง
- **Segmented Tab (screen-specific, ใหม่)** — wyn-143 ไม่มีคอมโพเนนต์ tab สำเร็จรูป จึงนิยามที่นี่โดยใช้ token เดิม: 2 ช่อง "ทั้งหมด" / "การกล่าวถึง" ความสูง 46px, label `type.body.m`, tab active = `color.ink` + FontWeight SemiBold + แถบ indicator ด้านล่างกว้าง 34px สูง 3px `radius.pill` สี **`color.accent`** (เปลี่ยนจากของเดิมที่ใช้สี ink — active indicator ควรใช้ accent ให้สอดคล้องกับหลักการ "accent = active state" ที่ wyn-143 §3 ใช้กับ Bottom Tab Bar), tab inactive = `color.ink.muted`, พื้นหลัง `color.paper` + เส้นล่าง `color.hairline` — แนะนำเสนอ promote ขึ้นเป็น core component ถ้ามีอีกหน้าจอใช้ pattern นี้ซ้ำ
- **List Item (ขยายจาก wyn-143 §10)** — โครงสร้างแถวแจ้งเตือน สูงขั้นต่ำ 56px แต่ยืดหยุ่นได้ตามจำนวนบรรทัด (มี content preview เพิ่มได้): [Leading: Avatar/Icon + Type Badge] — [Title/Message + Content Preview (ถ้ามี) + Timestamp] — [Trailing: Unread indicator]
- **Avatar** (wyn-143 §5) — ขนาด 40px (list item standard) ทุกแถวที่มี actor จริง **ไม่ใช้ ring** อีกต่อไป (ของเดิมใช้ ring sapphire กับทุกแถว — wyn-143 สงวน ring ไว้เฉพาะ story/live indicator ในอนาคตเท่านั้น "ปัจจุบันเว้นไว้" จึงต้องเอาออกจาก Notifications)
- **Badge/Chip (wyn-143 §6, ส่วน type-badge overlay)** — วงกลม 18px มุมล่างขวาของ avatar, ขอบ `color.paper` หนา 1.5px กันภาพซ้อน, ไอคอน filled 10px สีขาว/`color.paper` — ดูการ mapping สีและไอคอนแยกตามประเภทใน "Notification Type Matrix" ด้านล่าง
- **Icon-in-circle (fallback avatar สำหรับ hidden-identity types)** — แทนที่ Avatar เมื่อไม่ต้องเปิดเผยตัวตนผู้กระทำ (moderation/appeal/system) วงกลม 40px พื้นหลัง tint สีสถานะ 15–20%, ไอคอน outline 1.5px สีเดียวกับ tint แบบเข้ม — ดู matrix ด้านล่าง (ปรับปรุงจากของเดิมที่ใช้วงกลมเทาเดียวกันทั้ง 4 ประเภท ทำให้แยกความรุนแรงไม่ออก)
- **Unread indicator** — จุดกลม 8px สี `color.accent` มุมขวาบนของฝั่งข้อความ (เปลี่ยนจาก sapphire) **ร่วมกับพื้นหลังแถบสีอ่อน** `color.accent` tint 6% ทับพื้นหลังทั้งแถวที่ยังไม่ได้อ่าน (ของใหม่ — เพิ่มเพื่อสแกนง่ายขึ้น ไม่ใช่แค่จุดเล็ก ๆ) ดู Accessibility ว่าทำไมยังผ่านกติกา "ห้ามสื่อสารด้วยสีอย่างเดียว"
- **Group label** (section header ของแต่ละวัน) — `type.overline` สี `color.ink.muted`, padding ตาม 4px-grid
- **Loading — Skeleton** (wyn-143 §8) — แทนที่ full-screen spinner เดิมด้วย skeleton rows (avatar circle blob + 2 เส้นข้อความ) 5–6 แถว ระหว่าง `_isLoadingInitial`
- **Loading — Spinner** (wyn-143 §8) — ใช้เฉพาะตอน load-more ที่ท้ายลิสต์ (inline, 24px, สี `color.accent`)
- **Empty State** (wyn-143 §12) — สองแบบ: "ยังไม่มีการแจ้งเตือน" (tab ทั้งหมด) และ "ยังไม่มีใครกล่าวถึงคุณ" (tab การกล่าวถึง)
- **Secondary Button** (wyn-143 §1) — ปุ่ม "ลองใหม่" ใน Error state
- **Side Menu** (wyn-143 §3) — เปิดจาก hamburger ซ้าย overlay ทึบ 80% ของจอ

### Notification Type Matrix — แสดงผลต่างกันอย่างไรในลิสต์เดียวกัน

| กลุ่มประเภท (NotificationType) | Avatar/Icon | Badge overlay | สี badge | Group ในวันเดียวกัน? | ปลายทางเมื่อแตะ |
|---|---|---|---|---|---|
| `likeDrop`, `likePop`, `clubPostLike` | Avatar ผู้กระทำ 40px | หัวใจ (WYN heart, filled) | `color.heart` | `likeDrop`/`likePop` รวมกันได้ ("และอีก N คน") — `clubPostLike` ไม่รวม (หนึ่งแถวต่อเหตุการณ์) | Drop/Club post detail |
| `commentDrop`, `commentPop`, `clubPostComment` | Avatar ผู้กระทำ 40px | ไอคอนบับเบิลแชท (filled) | `color.accent` (เดิมมีสี exception เฉพาะ — ยกเลิกตาม single-accent system ของ wyn-142) | `commentDrop`/`commentPop` รวมได้ — `clubPostComment` ไม่รวม | Drop/Club post detail |
| `redrop` | Avatar ผู้กระทำ 40px | ไอคอน repeat (filled) | `color.accent` (เดิม exception color — ยกเลิกเช่นกัน) | รวมได้ | Drop เดิม |
| `follow`, `followRequestAccepted` | Avatar ผู้กระทำ 40px | ไอคอน person-add (filled) | `color.accent` (เดิม sapphire) | เฉพาะ `follow` รวมได้ (ไม่มี target แยก) — `followRequestAccepted` ไม่รวม | Profile ของผู้กระทำ |
| `mentionDrop`, `mentionClubPost` | Avatar ผู้กระทำ 40px | **[แนะนำเพิ่ม]** ไอคอน "@" filled | `color.accent` | ไม่รวม | Drop/Club post detail |
| `clubJoinRequest`, `clubJoinApproved`, `clubInvite`, `clubPostNew` | Avatar ผู้กระทำ 40px | ไม่มี badge (ชื่อ Club อยู่ในข้อความ) | — | ไม่รวม | Club (สมาชิก/โพสต์ ตามชนิด), Club post detail |
| `clubPostPinned` | Avatar ผู้กระทำ 40px | ไอคอน pin (filled) | `color.accent` | ไม่รวม | Club post detail |
| `messageRequest`, `newMessage`, `followRequest` | Avatar ผู้กระทำ 40px | ไม่มี badge | — | ไม่รวม | Conversation screen / Follow request list |
| `moderationWarning` | Icon-in-circle: shield-warning | — (ไม่มี avatar, ไม่เปิดเผยตัวตนผู้ตรวจสอบ) | วง tint `color.warning` 20% | ไม่รวม | Moderation action screen |
| `moderationContentRemoved` | Icon-in-circle: shield-removed | — | วง tint `color.error` 20% | ไม่รวม | Moderation action screen |
| `appealApproved` | Icon-in-circle: shield-check | — | วง tint `color.success` 20% | ไม่รวม | Moderation action screen |
| `appealRejected` | Icon-in-circle: shield-x | — | วง tint `color.ink.muted` 15% | ไม่รวม | Moderation action screen |
| `system` | Icon-in-circle: campaign/megaphone | — | วง tint `color.accent` 15% | ไม่รวม | ไม่มีปลายทาง (ข้อความเต็มอยู่ในลิสต์แล้ว) |

หมายเหตุ: การรวมแถว (grouping) — ใครรวมกับใครได้ — เป็น business logic เดิมที่ **ห้ามเปลี่ยน** (`_groupableTypes`) เอกสารนี้เพียงบันทึกผลลัพธ์ที่มีอยู่จริงเพื่อให้เห็นภาพรวมในตารางเดียว

## Interactions:

- **แตะแถว**: นำทางตามตาราง Notification Type Matrix ด้านบน — `Pop` เปิดไม่ได้อีกต่อไป (แสดง snackbar "เนื้อหานี้ไม่พร้อมใช้งานแล้ว"), Drop/Club post ที่ถูกลบแสดง snackbar "โพสต์นี้ถูกลบไปแล้ว", `system` ไม่มี action เมื่อแตะ (ข้อความเต็มอยู่ในแถวแล้ว)
- **Pull-to-refresh**: รีโหลด page 0 ใหม่ทั้งหมด, reset `_page`/`_hasMore`
- **Infinite scroll**: โหลดหน้าถัดไปเมื่อ scroll ห่างจากจุดสิ้นสุดน้อยกว่า 300px — ถ้า fail เงียบ (ไม่มี error state บล็อก แค่ให้ scroll ต่อเพื่อ retry เอง)
- **สลับ Tab**: instant client-side filter ไม่มี loading state, ไม่ persist ข้าม session (reset เป็น "ทั้งหมด" ทุกครั้งที่เปิดหน้าใหม่)
- **ปิดการ์ดขอสิทธิ์แจ้งเตือน**: กดปุ่ม × ปิดการ์ด (session-level หรือ persist ตาม logic เดิมของ `PushPermissionCard` — ไม่เปลี่ยน)
- **แตะไอคอนค้นหา**: เปิด Search screen
- **แตะ hamburger**: เปิด Side Menu (drawer)
- **Mark-as-read timing (ห้ามเปลี่ยน)**: unread highlight คำนวณจาก snapshot ตอนโหลดครั้งแรกของ session การเปิดหน้านี้เท่านั้น (`_unreadSnapshot`) แม้ backend จะ mark-all-as-read สำเร็จแล้วระหว่างที่ผู้ใช้ยังดูหน้านี้อยู่ แถบ unread ก็ต้องยังค้างอยู่จนกว่าจะออกจากหน้าแล้วกลับเข้ามาใหม่ — เพื่อไม่ให้ highlight หายวับต่อหน้าผู้ใช้ก่อนที่จะทันสังเกตว่ามีอะไรใหม่

## States:

- **Loading (initial)**: Skeleton rows 5–6 แถว (avatar blob + 2 เส้นข้อความ) แทน spinner กลางจอเดิม
- **Loading (more)**: Spinner 24px `color.accent` แถวสุดท้ายของลิสต์ ระหว่างโหลดหน้าถัดไป
- **Error (initial load fail)**: ข้อความ error (`errorMessageFor`) กึ่งกลางจอ + Secondary Button "ลองใหม่" — คงข้อความเดิม โหลดใหม่เมื่อกด
- **Error (load-more fail)**: เงียบ ไม่มี UI แสดง — scroll ต่อเพื่อ retry เอง (ตาม logic เดิม)
- **Empty — ทั้งหมด**: Empty State icon `notifications_outlined`, headline "ยังไม่มีการแจ้งเตือน", subtext "เมื่อมีคนถูกใจ แสดงความคิดเห็น ติดตามคุณ หรือมีความเคลื่อนไหวใน Club จะเห็นที่นี่"
- **Empty — การกล่าวถึง**: headline "ยังไม่มีใครกล่าวถึงคุณ", subtext "เวลามีคนพูดถึงคุณในโพสต์ จะขึ้นตรงนี้"
- **มีข้อมูล, ยังโหลดเพิ่มได้ (`_hasMore == true`)**: แสดง spinner load-more ท้ายลิสต์
- **มีข้อมูล, โหลดหมดแล้ว (`_hasMore == false`)**: แสดงข้อความปิดท้าย "ไม่มีการแจ้งเตือนเพิ่มเติมแล้ว" (`type.caption`, `color.ink.muted`)
- **Unread row**: พื้นหลังแถบ `color.accent` tint 6% + จุด `color.accent` 8px ทางขวา
- **Read row**: พื้นหลังโปร่งใส (ปกติ)
- **Grouped row (multi-actor)**: ข้อความต่อท้ายด้วย "และอีก N คน" สี `color.ink.muted`
- **Push permission card แสดง/ไม่แสดง**: ตาม logic เดิมของ `PushPermissionCard` — ไม่แสดงอะไรเลยเมื่อไม่มีเหตุผลให้ถาม (ไม่ error/blank/loading ค้าง)

## Responsive Behavior:

- Mobile-first, portrait เป็นหลัก (Flutter, `app/lib/features/`)
- ความกว้างจอแคบสุด (320–375px): ข้อความ content preview ต้อง truncate 1 บรรทัดด้วย ellipsis เสมอ (ไม่ wrap), เวลา relative time ย่อรูปแบบสั้นตามที่มีอยู่ (`relativeTimeLabel`)
- ความกว้างจอกว้างขึ้น (400px+): padding แนวนอนคงที่ 16px ตาม 4px-grid ไม่ขยาย padding ตามความกว้างจอ — เน้นเนื้อหาให้ความกว้าง scan ได้เร็ว ไม่ยืดจนบรรทัดยาวเกินอ่านสบาย
- Dynamic type / ผู้ใช้ปรับขนาดตัวอักษรระบบใหญ่ขึ้น: List Item ต้องขยายความสูงตามเนื้อหาได้ (ห้าม fix height แข็ง) เพื่อไม่ให้ข้อความถูกตัด, avatar/badge ขนาดคงที่ไม่ scale ตาม dynamic type
- แนวนอน (landscape)/แท็บเล็ต/foldable ในอนาคต: จำกัดความกว้างเนื้อหาสูงสุดไว้ที่ประมาณ 600px จัดกึ่งกลางจอ เพื่อไม่ให้บรรทัดข้อความยาวเกินอ่านสบาย (ยังไม่ใช่ scope ปัจจุบันของแอป แต่บันทึกไว้เป็นแนวทาง)

## Accessibility:

- ทุก row ใช้ `Semantics` แบบ flatten label เดียว (`excludeSemantics: true`) รวม: ข้อความเต็ม + เวลา + " ยังไม่ได้อ่าน" ต่อท้ายเมื่อ unread — คงรูปแบบเดิม, badge icon เป็น decorative ไม่ต้องมี label แยก เพราะข้อความหลักสื่อความหมายประเภทแจ้งเตือนอยู่แล้ว (เช่น "ถูกใจ", "แสดงความคิดเห็น")
- **เรื่อง "ห้ามสื่อสารด้วยสีอย่างเดียว" (wyn-142)**: unread ใช้ทั้ง (1) การมี/ไม่มีจุดกลม (shape/presence ไม่ใช่การเทียบสี), (2) พื้นหลัง tint, (3) ข้อความ " ยังไม่ได้อ่าน" ใน screen reader label — ผ่านกติกาเพราะไม่ได้ใช้ "สี A กับสี B" แทนความหมายต่างกัน แต่ใช้ presence + text
- Badge สีสถานะ (moderation/appeal icon-in-circle) แต่ละประเภทต้องมี **ไอคอนต่างกันจริง** ไม่ใช่สีต่างกันอย่างเดียว (ดู matrix — shield-warning/shield-removed/shield-check/shield-x/campaign ต่างกันทุกแบบ)
- Contrast: ไอคอน filled สีขาวบนพื้น `color.accent`/`color.heart` ต้องผ่าน AA อย่างน้อยระดับ non-text (≥3:1) ทั้ง light/dark mode — ตรวจตาม wyn-142 palette ที่กำหนดไว้แล้ว
- Touch target: ปุ่ม hamburger, search, close (การ์ดขอสิทธิ์), และทั้งแถว List Item ต้อง ≥44×44px ทุกจุด
- Reduce Motion: Skeleton shimmer ต้องเป็น static (ไม่ shimmer) เมื่อผู้ใช้เปิด Reduce Motion ของ OS (ตาม wyn-143 §8)
- แถว hidden-identity (moderation/appeal/system) ต้องไม่มี label ใด ๆ ที่พาดพิงถึงตัวตนผู้ตรวจสอบ (คงพฤติกรรมเดิมของ `_hidesActorIdentity` ทุกประการ)

## Design Rules:

1. ห้ามเปลี่ยน business logic ที่มีอยู่: การนำทางต่อประเภท, การ group แถว (`_groupableTypes`/`_groupKeyFor`), การ bucket ตามวัน, mark-as-read timing, เนื้อหาข้อความ (`_messageFor`), pagination, tab filter — งานนี้คือ reskin เท่านั้น
2. ใช้ token จาก wyn-142 และคอมโพเนนต์จาก wyn-143 เท่านั้น ห้ามเพิ่มสี/ฟอนต์/radius นอกชุดที่กำหนด
3. เอา ring รอบ avatar ออกทั้งหมดในหน้านี้ (wyn-143 สงวน ring ไว้เฉพาะ story/live indicator ในอนาคต)
4. รวม badge สีทุกประเภท (ยกเว้น heart) เป็น `color.accent` สีเดียว ตามหลัก single-accent system ของ wyn-142 — ยกเลิกสี exception เดิม (sapphire/notificationBadgeComment/notificationBadgeRepost)
5. Icon-in-circle ของ moderation/appeal/system ต้องใช้ไอคอน+สี tint ต่างกันครบ 5 แบบตาม matrix (ปรับปรุงจากเดิมที่ใช้วงกลมเทาเดียวกันหมดยกเว้น system)
6. Badge ขนาด 10px ใน overlay 18px ใช้ไอคอน filled ได้แม้ระบบ default เป็น outline 1.5px — ข้อยกเว้นเฉพาะจุดเพื่อความชัดในขนาดเล็กมาก (สอดคล้องกับ Bottom Tab Bar active state ที่ใช้ filled เช่นกัน)
7. Segmented Tab เป็น component ใหม่เฉพาะหน้าจอนี้ (wyn-143 ยังไม่มี) ถ้ามีหน้าจออื่นต้องใช้ pattern เดียวกันซ้ำ ให้เสนอ promote เข้า wyn-143 แยกต่างหาก
8. งานนี้เป็นการ reskin หน้าจอที่ผู้ใช้ทั่วไปใช้งานอยู่แล้ว ไม่ใช่ฟีเจอร์ใหม่ที่ user-facing เพิ่มขึ้น — ตาม `.wyn/company/WORKFLOW.md` เรื่อง staged rollout (WYN-125) จึง **ไม่จำเป็นต้อง gate ด้วย developer account allowlist** เว้นแต่ Founder ต้องการทยอยเปิดทีละกลุ่มผู้ใช้เอง (ถ้าใช่ ให้แจ้งใน handoff ของ AI Coding ชัดเจน)
9. จุดที่ทำเครื่องหมาย "[แนะนำเพิ่ม]" (badge "@" สำหรับ mention) เป็นข้อเสนอปรับปรุงเท่านั้น ไม่ใช่ requirement บังคับ — รอ Founder ตัดสินใจรับ/ไม่รับก่อนส่งต่อ AI Coding

## Handoff:

- รอ Founder ยืนยัน wyn-142 (Visual Identity) และ wyn-143 (Component Library) อย่างเป็นทางการก่อน เนื่องจากทั้งสองยังเป็นสถานะ PROPOSED — สเปกหน้านี้อ้างอิง token จากทั้งสองไฟล์ทั้งหมด หากมีการแก้ไข token ใน wyn-142/143 ภายหลัง ต้องย้อนกลับมาปรับ mapping ในตาราง Notification Type Matrix ให้ตรงกัน
- เมื่อ Founder ยืนยันแล้ว ส่งต่อให้ AI Coding implement โดยอ้างอิง 3 ไฟล์: `wyn-142-visual-identity-redesign.md`, `wyn-143-core-component-library.md`, และเอกสารนี้ (`wyn-151-notifications.md`)
- AI Coding ต้องรัน `flutter analyze` + `flutter test` เต็มชุดหลังแก้ และรายงาน regression ก่อนทำต่อ ตามกติกา WYN-141
- ไฟล์โค้ดที่เกี่ยวข้องโดยตรง: `app/lib/features/notification/presentation/notification_list_screen.dart`, `app/lib/features/push/presentation/push_permission_card.dart`, `app/lib/core/design/wyn_colors.dart`, `app/lib/core/design/wyn_typography.dart`, `app/lib/core/design/wyn_spacing.dart`, `app/lib/core/widgets/empty_state_block.dart`, `app/lib/core/widgets/wyn_heart_icon.dart`
- Design Task tracking: `.wyn/tasks/backlog/WYN-151-notifications.md`
