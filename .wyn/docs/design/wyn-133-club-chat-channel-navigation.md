# Design Doc — WYN-133: Club Chat Channel Navigation

Status: approved
Owner: AI Design
Related: `.wyn/tasks/backlog/WYN-133-club-chat-channel-navigation.md` (Product), `ds-005-club-community-identity.md`, WYN-127/128 (Club Channels / Group Chat, already built)

## Screen

Two screens replace today's single "แชท" tab:

1. **หน้ารายชื่อห้อง (Channel List)** — the new content of the existing "แชท" tab inside `ClubPage`. Replaces `ClubChannelSwitcher` (chip row) + inline `ClubChannelChatView`. No route push to get here — it's still just the Chat tab's body.
2. **หน้าห้องแชท (Channel Room)** — a new, separate full-screen route pushed when a channel row is tapped. Hosts the existing `ClubChannelChatView` unchanged, under its own `AppBar`.

## Purpose

Make opening a Club channel feel like Discord: tapping a room is an act of "entering" it — a distinct full-screen destination with its own header and a real back action — instead of swapping message content under a chip bar that never leaves the screen. This is a navigation/structure change only; no new chat features, no DM involvement.

## User Flow

1. Developer-account member opens a Club → taps the "แชท" tab.
2. Sees **the channel list** for that Club — no channel is auto-opened. Every channel is a row: `#ชื่อห้อง`, unread dot if applicable.
3. Taps a row → screen **pushes** (standard platform transition) to the Channel Room screen for that channel. AppBar shows `#ชื่อห้อง` as the title.
4. Reads/sends messages exactly as today (`ClubChannelChatView`'s existing UI, untouched).
5. Taps the back arrow in the AppBar, or swipes back (iOS) / presses system back (Android) → pops back to the Channel List. That channel's unread state is now cleared; other channels' unread dots continue updating live.
6. Owner/Admin: taps "+" in the Channel List's top row → same existing create-channel dialog (`showClubChannelNameDialog`). Long-presses a row → same existing manage sheet (แก้ไขชื่อห้อง / ลบห้อง, `showDeleteClubChannelDialog`).

## Components

**Channel List (replaces `ClubChannelSwitcher` inside `ClubChatTab`):**
- Header row: `Text('ห้องแชท', ...)` section-label style (reuse whatever label style `ClubPage`'s other section headers already use) on the left; if `canManage`, an `IconButton(Icons.add)` (tooltip "สร้างห้องใหม่") on the right — this is the "+" that used to be the `_NewChannelChip`. Not shown at all for non-managers (same "hide, don't disable" rule as today's chip).
- Below it: a plain vertical list of channel rows — **entity-browse list pattern per `ds-005`** (like `MyClubsScreen`): `ListTile`-based, no `Divider` between rows.
  - Leading: a small circular tag avatar — `WynColors.surfaceTint` background, `radiusFull`, centered bold `#` in `WynColors.sapphire` (a lightweight stand-in "avatar" for a channel, echoing `ClubAvatar`'s circular-leading convention without needing new imagery).
  - Title: `#ชื่อห้อง`, same weight/size as today's chip label style.
  - Trailing: the existing unread indicator — the same 7×7 sapphire dot used on the chip today (`hasUnread` → show, else nothing). No message-preview subtitle and no unread *count* — keep the row exactly as information-dense as the current chip was, per Product's explicit "don't over-spec" note.
  - Row `minHeight: WynSpacing.touchTargetMin`, `onTap` → push Channel Room; `onLongPress` → existing manage sheet, only when `canManage`.
- Empty/loading/error states: identical posture to `ClubChannelSwitcher`'s caller today (a Club always has at least one channel — "#ทั่วไป" is created with the Club — so there is no true empty state to design net-new; loading/error follow the same pattern already used elsewhere in `ClubChatTab`).

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
- **Non-manager member**: no "+" row header action, no "⋮" AppBar action, no long-press sheet — identical gating to today, just relocated.
- **Non-developer account**: unaffected — the whole "แชท" tab remains behind `isDeveloperAccount()` exactly as today; nothing here changes that gate.

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

## Handoff

ส่งต่อ AI Coding เพื่อ implement ตาม spec นี้:

1. รีแฟกเตอร์ `club_chat_tab.dart`: เปลี่ยนจาก `Column[ClubChannelSwitcher, Expanded(ClubChannelChatView)]` เป็น channel-list view ตาม Components ด้านบน (header row มี "+" เฉพาะ canManage + `ListView` ของ `ListTile` แบบไม่มี divider)
2. สร้างไฟล์ใหม่ (แนะนำชื่อ `club_channel_screen.dart`) — `Scaffold(AppBar(title: '#ชื่อห้อง', actions: [ถ้า canManage ใส่ "⋮"]), body: ClubChannelChatView(...))` โดยใช้ `ClubChannelChatView` เดิมไม่ต้องแก้ไข
3. `_selectChannel` เดิม (แค่ setState) เปลี่ยนเป็น `Navigator.push` ไปหน้าใหม่แทน
4. ย้าย/ปรับ unread subscription lifecycle (`_subscribeUnread`/`_unsubscribeUnread`) ให้ทำงานถูกต้องข้าม 2 หน้าจอ ตาม States ด้านบน — รายละเอียด mechanism (เช่น `RouteAware`/refetch on pop) ให้ Coding ตัดสินใจเอง เพราะเป็นเรื่อง implementation ไม่ใช่ design
5. ปรับ `onBanned` ให้ pop กลับไปหน้ารายชื่อห้อง แทนที่จะสลับกลับไป Posts tab แบบเดิม (ยืนยัน behavior นี้กับ Coding ตามที่ระบุใน Components)
6. ห้ามแตะ `ConversationScreen`/`ChatRepository`/ไฟล์ใดๆ ของระบบ DM
7. เขียน/แก้ widget test ที่มีอยู่ (`club_posts_tab_test.dart` หรือไฟล์ที่เกี่ยวข้อง) ให้สะท้อนโครงสร้างใหม่ — จุดที่เคยเทสต์ "เลือกห้องแล้ว setState" ต้องเปลี่ยนเป็นเทสต์ "แตะห้องแล้ว push route ใหม่"
8. QA ควรทดสอบ: gate ยังทำงาน (non-developer ไม่เห็นแท็บแชท), unread badge อัปเดตถูกต้องหลัง pop กลับจากห้อง, สิทธิ์ Owner/Admin ปุ่มจัดการห้องยังทำงานครบ (สร้าง/แก้ไข/ลบ), back gesture ทั้ง iOS/Android ใช้ได้ปกติ
