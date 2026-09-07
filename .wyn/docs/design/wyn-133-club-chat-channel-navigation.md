# Design Doc — WYN-133: Club Chat Channel Navigation

Status: approved
Owner: AI Design
Related: `.wyn/tasks/backlog/WYN-133-club-chat-channel-navigation.md` (Product), `ds-005-club-community-identity.md`, WYN-127/128 (Club Channels / Group Chat, already built)

**Revision 2026-09-07**: Founder ส่ง screenshot Discord วงไว้ที่หัวข้อกลุ่มห้อง ("Charlot Media", "Chat Charlot") และยืนยันว่าต้องการ **channel category** (กลุ่มห้องแชท) แบบเดียวกัน รวมเข้า WYN-133 นี้เลย (ดู Product doc requirement 7) — Channel List ด้านล่างอัปเดตให้รองรับหัวข้อกลุ่มแล้ว Channel Room ไม่เปลี่ยนแปลง

## Screen

Two screens replace today's single "แชท" tab:

1. **หน้ารายชื่อห้อง (Channel List)** — the new content of the existing "แชท" tab inside `ClubPage`. Replaces `ClubChannelSwitcher` (chip row) + inline `ClubChannelChatView`. No route push to get here — it's still just the Chat tab's body.
2. **หน้าห้องแชท (Channel Room)** — a new, separate full-screen route pushed when a channel row is tapped. Hosts the existing `ClubChannelChatView` unchanged, under its own `AppBar`.

## Purpose

Make opening a Club channel feel like Discord: tapping a room is an act of "entering" it — a distinct full-screen destination with its own header and a real back action — instead of swapping message content under a chip bar that never leaves the screen. This is a navigation/structure change only; no new chat features, no DM involvement.

## User Flow

1. Developer-account member opens a Club → taps the "แชท" tab.
2. Sees **the channel list** for that Club — no channel is auto-opened. Channels appear **grouped under category headers** (if any categories exist), plus one final ungrouped section for channels with no category. Every channel is a row: `#ชื่อห้อง`, unread dot if applicable.
3. Taps a row → screen **pushes** (standard platform transition) to the Channel Room screen for that channel. AppBar shows `#ชื่อห้อง` as the title.
4. Reads/sends messages exactly as today (`ClubChannelChatView`'s existing UI, untouched).
5. Taps the back arrow in the AppBar, or swipes back (iOS) / presses system back (Android) → pops back to the Channel List. That channel's unread state is now cleared; other channels' unread dots continue updating live.
6. Owner/Admin: taps "+" in the Channel List's top row → a small action sheet (reusing `ActionSheetBody`/`ActionSheetRow`, same shape as the existing manage sheets) with two rows: "ห้องใหม่" (existing `showClubChannelNameDialog` flow, now with an added category picker) and "กลุ่มใหม่" (new, same dialog shape as `showClubChannelNameDialog` but for a category name). Long-presses a channel row → existing manage sheet (แก้ไขชื่อห้อง / ลบห้อง, `showDeleteClubChannelDialog`) — now with an added "ย้ายไปกลุ่มอื่น" row. Long-presses a category header → new manage sheet (แก้ไขชื่อกลุ่ม / ลบกลุ่ม), same visual shape as the channel one.

## Components

**Channel List (replaces `ClubChannelSwitcher` inside `ClubChatTab`):**
- Header row: `Text('ห้องแชท', ...)` section-label style (reuse whatever label style `ClubPage`'s other section headers already use) on the left; if `canManage`, an `IconButton(Icons.add)` (tooltip "เพิ่ม") on the right, opening the "ห้องใหม่ / กลุ่มใหม่" action sheet described in User Flow — this is the "+" that used to be the `_NewChannelChip`. Not shown at all for non-managers (same "hide, don't disable" rule as today's chip).
- Below it: channels grouped under **category header rows**, followed by a plain vertical list of channel rows per group — **entity-browse list pattern per `ds-005`** (like `MyClubsScreen`): `ListTile`-based, no `Divider` between rows, within or between groups.
  - **Category header row** (new): `Padding` + `Text('ชื่อกลุ่ม'.toUpperCase(), ...)` styled as a quiet uppercase eyebrow label — `WynColors.graphite`, 12px, `letterSpacing` a touch wide, `fontWeight.w600` — i.e. the same "small caps section label" treatment already used elsewhere in the app for group labels (not a new type style). Sits directly above its channels, no background fill, no border, no chip/pill shape — a label, not a button. `onLongPress` (canManage only) → category manage sheet (แก้ไขชื่อกลุ่ม / ลบกลุ่ม).
  - Categories render in `created_at` order. **Ungrouped channels** (`category_id == null`) render as their own trailing section — **with no header label at all** when a Club has no categories yet (the common/default case for every existing Club today, since all of today's channels start out ungrouped) — only gaining a quiet "ไม่มีกลุ่ม" header once at least one real category exists elsewhere in the list, so a Club that never adopts grouping sees the exact same flat list as before.
  - Channel row, unchanged from the original spec: leading a small circular tag avatar (`WynColors.surfaceTint` background, `radiusFull`, centered bold `#` in `WynColors.sapphire`); title `#ชื่อห้อง`; trailing the existing 7×7 sapphire unread dot (`hasUnread` → show, else nothing). No message-preview subtitle, no unread *count* — keep the row exactly as information-dense as the current chip was, per Product's explicit "don't over-spec" note.
  - Row `minHeight: WynSpacing.touchTargetMin`, `onTap` → push Channel Room; `onLongPress` → existing channel manage sheet (now +"ย้ายไปกลุ่มอื่น"), only when `canManage`.
- No collapse/expand affordance on category headers — Product's requirement 7 explicitly excludes this from scope; a header is a static label, not a `ExpansionTile`.
- Empty/loading/error states: identical posture to `ClubChannelSwitcher`'s caller today (a Club always has at least one channel — "#ทั่วไป" is created with the Club — so there is no true empty state to design net-new; loading/error follow the same pattern already used elsewhere in `ClubChatTab`). A Club with zero categories (the default) never shows an empty "ยังไม่มีกลุ่ม" state either — categories are opt-in, so their absence is just the ordinary flat list, not a state that needs its own empty-state treatment.

**Category & channel management dialogs (new, alongside the existing channel ones):**
- "กลุ่มใหม่" / แก้ไขชื่อกลุ่ม: same shape as `showClubChannelNameDialog` (single text field, 50-char limit, blocks empty/duplicate case-insensitive name within the Club) — a new sibling function, e.g. `showClubCategoryNameDialog`, not a parameter added to the channel one (different entity, keep them distinct).
- ลบกลุ่ม: same shape as `showDeleteClubChannelDialog` (confirm dialog, loading state on the destructive action, error-colored delete button) but the warning copy must say the channels move to "ไม่มีกลุ่ม" rather than today's "ข้อความจะหายถาวร" — the two dialogs must not share copy, since deleting a category is non-destructive to messages while deleting a channel is.
- ห้องใหม่ / แก้ไขชื่อห้อง (`showClubChannelNameDialog`, extended): gains one additional field below the name field — a simple dropdown/segmented picker of "ไม่มีกลุ่ม" + every existing category name, defaulting to "ไม่มีกลุ่ม". Everything else about this dialog (validation, buttons, loading state) stays exactly as today.
- "ย้ายไปกลุ่มอื่น" (new row in the existing channel manage sheet): opens the same category picker as above, alone, without the name field — a lighter-weight variant for the common case of only changing a channel's group.

**Channel Room screen (new, e.g. `club_channel_screen.dart`):**
- `Scaffold`:
  - `AppBar`: `title: Text('#$channelName')`, standard back button (automatic from `Navigator.push`, no custom back handling needed). If `canManage`, one `IconButton(Icons.more_vert)` action on the right opening the same manage sheet (edit/delete) — this is the one relocation of the old long-press-on-chip gesture into an explicit visible affordance now that the trigger (a chip) no longer exists on this screen.
  - `body: ClubChannelChatView(...)` — passed through unchanged (`repository`, `clubRepository`, `clubId`, `channelId`, `channelName`, `myRole`, `onBanned`). `ClubChannelChatView`'s own internal header (online-count row, `_buildHeader()`) stays exactly as-is underneath the new AppBar — it shows presence, not the channel name, so there is no duplication with the AppBar title.
  - `onBanned`: today this callback tells the *embedding* `ClubChatTab` to bounce back to Posts. In the new structure the natural behavior is simpler — pop this route back to the Channel List (which itself already re-derives non-member state the normal way Club screens do). Confirm this specific wiring with Coding; it's a one-line behavior change, not a new UI.

## Interactions

- Tap channel row → push Channel Room (`Navigator.of(context).push(MaterialPageRoute(...))`) — standard forward navigation, no custom transition.
- Back arrow / swipe-back / system back on Channel Room → pop, return to Channel List.
- Tap "+" on Channel List (Owner/Admin only) → `showClubChannelNameDialog` (unchanged dialog, unchanged validation copy).
- Long-press a row on Channel List, or tap "⋮" on Channel Room's AppBar (Owner/Admin only) → same manage sheet (แก้ไขชื่อห้อง / ลบห้อง) already implemented — reuse verbatim, don't restyle.
- No pull-to-refresh needed on the Channel List — channel membership/unread state already updates live via the existing realtime subscription; adding manual refresh would be new scope not asked for.

## States

- **Channel List, normal**: rows for every channel, unread dots reflecting live state.
- **Channel List, returning from a room**: the channel just visited shows no unread dot (it was just read); this must hold true even though the realtime unread subscription was, until now, only ever "on" for the *non-open* channel — Coding needs to re-derive that lifecycle for two separate screens instead of one shared state object (flagged already in the Product doc's Risks; Design's requirement is just the observable outcome above, not the mechanism).
- **Channel Room, loading**: unchanged — `ClubChannelChatView`'s own `_isLoadingInitial` spinner.
- **Channel Room, banned mid-chat**: pops back to Channel List instead of today's "switch back to Posts" (see Components note above).
- **Non-manager member**: no "+" row header action, no "⋮" AppBar action, no long-press sheet on channel rows or category headers — identical gating to today, just relocated.
- **Non-developer account**: unaffected — the whole "แชท" tab remains behind `isDeveloperAccount()` exactly as today; nothing here changes that gate.
- **Club with no categories yet (default for every existing Club)**: flat list, no category headers at all, no "ไม่มีกลุ่ม" label either — identical in appearance to the pre-requirement-7 Channel List.
- **Category just deleted**: its channels reappear immediately under the (now-labelled, if other categories still exist) ungrouped section — no channel or message data lost.

## Responsive Behavior

Both screens are plain single-column `ListView`/`Column` layouts — no layout changes needed across phone screen sizes. Channel Room reuses `ClubChannelChatView` exactly as it already handles keyboard-safe composer behavior today; nothing about that changes.

## Accessibility

- Preserve the existing `Semantics(label: hasUnread ? '$label มีข้อความใหม่' : label, button: true)` pattern from `_ChannelChip` on the new list rows — unread state must still be announced, not conveyed by color/dot alone.
- Channel Room's AppBar back button gets standard automatic semantics ("Back") from `Navigator`/`AppBar` — no custom label needed.
- Row and AppBar-action tap targets stay at `WynSpacing.touchTargetMin` minimum, matching every other list/action-icon in the app (`ds-008`).

## Design Rules

- No new visual language: colors, chip-derived dot styling, dialog/sheet components are all reused verbatim from `club_channel_switcher.dart` — this task is a *structural* (navigation) change, not a restyle. Per `.wyn/agents/design.md`'s standing rule, nothing here invents new visual direction.
- Channel List follows `ds-005`'s "entity-browse list" treatment (no dividers, `ListTile`-based) — it is a list of destinations (rooms), not a chronological content feed, so it must **not** take `ds-003`'s Home-Feed divider treatment.
- Do not add a message-preview subtitle or unread count badge — out of scope; keep the row as lean as the chip it replaces.
- Keep the DM system (`ConversationScreen`, `ChatRepository`) completely untouched — no shared code paths between it and these two screens beyond what already exists today (there are none).
- Stay behind `isDeveloperAccount()` — this is a UX change to an already-gated feature, not a rollout to general users.
- Category headers are labels, not chips/pills/buttons — no fill, no border, no touch-target box around the text itself (only the whole row area participates in `onLongPress`). Do not reuse the sapphire-chip styling from `club_channel_switcher.dart` here; that styling stays scoped to what it always meant (a selectable filter), which a category header is not.
- No collapse/expand on categories — explicitly out of scope per Product requirement 7, do not add it "for free."
- Default (no-categories) Club must render pixel-identical to the original (pre-revision) flat Channel List — categories are additive, never a forced restructuring of every existing Club's chat tab.

## Handoff

ส่งต่อ AI Coding เพื่อ implement ตาม spec นี้ (**ต้องทำ backend/schema งานนี้ก่อน UI** เพราะ Flutter ฝั่ง client ต้องมี `category_id`/`club_channel_categories` ให้เรียกใช้จริง):

0. **Backend ก่อน (requirement 7)**: เตรียม migration สำหรับ Founder รันเองผ่าน Supabase SQL Editor (ห้าม AI รันเอง) — ตารางใหม่ `club_channel_categories` (`id`, `club_id`, `name`, `created_by`, `created_at`) + RLS เหมือน `club_channels` ทุกประการ (select: authenticated / insert-update-delete: owner-admin ผ่าน `club_role()`), unique index case-insensitive ต่อ Club เหมือน `club_channels_club_id_lower_name_key`, และคอลัมน์ใหม่ `club_channels.category_id uuid null references club_channel_categories(id) on delete set null`. เพิ่ม RPC/repository methods ฝั่ง `ClubRepository` สำหรับ fetch/create/rename/delete category + update ห้องให้มี category_id ตามต้องการ (`renameChannel`/similar ขยาย หรือเพิ่ม method ใหม่)
1. รีแฟกเตอร์ `club_chat_tab.dart`: เปลี่ยนจาก `Column[ClubChannelSwitcher, Expanded(ClubChannelChatView)]` เป็น channel-list view ตาม Components ด้านบน (header row มี "+" เฉพาะ canManage เปิด action sheet "ห้องใหม่/กลุ่มใหม่" + list ที่จัดกลุ่มตาม category header ตามที่ระบุ)
2. สร้างไฟล์ใหม่ (แนะนำชื่อ `club_channel_screen.dart`) — `Scaffold(AppBar(title: '#ชื่อห้อง', actions: [ถ้า canManage ใส่ "⋮"]), body: ClubChannelChatView(...))` โดยใช้ `ClubChannelChatView` เดิมไม่ต้องแก้ไข
3. `_selectChannel` เดิม (แค่ setState) เปลี่ยนเป็น `Navigator.push` ไปหน้าใหม่แทน
4. ย้าย/ปรับ unread subscription lifecycle (`_subscribeUnread`/`_unsubscribeUnread`) ให้ทำงานถูกต้องข้าม 2 หน้าจอ ตาม States ด้านบน — รายละเอียด mechanism (เช่น `RouteAware`/refetch on pop) ให้ Coding ตัดสินใจเอง เพราะเป็นเรื่อง implementation ไม่ใช่ design
5. ปรับ `onBanned` ให้ pop กลับไปหน้ารายชื่อห้อง แทนที่จะสลับกลับไป Posts tab แบบเดิม (ยืนยัน behavior นี้กับ Coding ตามที่ระบุใน Components)
6. เพิ่ม `showClubCategoryNameDialog` (สร้าง/แก้ไขชื่อกลุ่ม) + category-delete confirm dialog (คนละ copy กับ `showDeleteClubChannelDialog`) ตาม Components ด้านบน, ขยาย `showClubChannelNameDialog` ให้มี category picker, เพิ่ม "ย้ายไปกลุ่มอื่น" ในเมนูจัดการห้องเดิม
7. ห้ามแตะ `ConversationScreen`/`ChatRepository`/ไฟล์ใดๆ ของระบบ DM
8. เขียน/แก้ widget test ที่มีอยู่ (`club_posts_tab_test.dart` หรือไฟล์ที่เกี่ยวข้อง) ให้สะท้อนโครงสร้างใหม่ — จุดที่เคยเทสต์ "เลือกห้องแล้ว setState" ต้องเปลี่ยนเป็นเทสต์ "แตะห้องแล้ว push route ใหม่" + testเพิ่มสำหรับสร้าง/ลบกลุ่ม, ย้ายห้องข้ามกลุ่ม, Club ที่ไม่มีกลุ่มยัง render เหมือนเดิม
9. QA ควรทดสอบ: gate ยังทำงาน (non-developer ไม่เห็นแท็บแชท), unread badge อัปเดตถูกต้องหลัง pop กลับจากห้อง, สิทธิ์ Owner/Admin ปุ่มจัดการห้อง/กลุ่มยังทำงานครบ (สร้าง/แก้ไข/ลบ/ย้าย), back gesture ทั้ง iOS/Android ใช้ได้ปกติ, **ตรวจ RLS ของตารางใหม่โดยเฉพาะ** — member ทั่วไปต้องแก้ไข/ลบกลุ่มไม่ได้แม้ยิง request ตรงๆ, ลบกลุ่มแล้วห้อง/ข้อความต้องไม่หาย
