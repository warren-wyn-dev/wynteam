# Chat Screen — Message Grouping & Bubble Behavior Spec

**Scope:** WYNOS chat screen (1:1 conversation view)
**Status:** Ready for implementation
**Note for implementer:** This describes visual/behavioral intent only. Do not port any React/TSX syntax — translate to native Flutter widgets (e.g. `ListView.builder`, custom `BubbleWidget`, `Column` with conditional spacing).

---

## 1. Problem

Currently every message bubble is rendered independently with identical spacing, identical avatar visibility, and identical corner radius — regardless of whether it belongs to a burst of consecutive messages from the same sender. This makes a single "thought" sent as 3–4 quick messages look like 3–4 separate conversational turns, and adds visual noise (repeated avatars, floating timestamps nowhere).

## 2. Grouping Rule

A message belongs to the **same group** as the previous message if ALL of the following are true:
- Same sender (same `senderId`)
- Time gap since the previous message ≤ **60 seconds**
- No date boundary crossed (see §6)

If any condition fails, start a **new group**.

## 3. Spacing

| Relationship | Vertical gap |
|---|---|
| Between bubbles **within** the same group | 4px |
| Between the **last bubble of one group** and the **first bubble of the next group** | 16px |
| Between groups from **different senders** | 20px |

Do not use a flat uniform gap between all bubbles — this is the single biggest fix.

## 4. Avatar Visibility (incoming messages only; outgoing/right-aligned bubbles never show an avatar)

- Show the sender's avatar **only once per group**, aligned to the **bottom-most bubble** of that group.
- All other bubbles in the group render with an empty spacer the same width as the avatar (so text still aligns), avatar itself hidden.

## 5. Bubble Corner Radius ("tail" behavior)

Base radius: 18px on all corners.

Within a group, reduce radius to **4px** on the corner that touches the adjacent bubble in the group, to visually stitch the group together:

- **Outgoing (right-aligned) bubbles:**
  - First bubble in group: full 18px, except bottom-right → 4px if another bubble follows
  - Middle bubble(s): top-right and bottom-right → 4px
  - Last bubble in group: top-right → 4px, bottom-right stays 18px (this is the "tail" corner)
- **Incoming (left-aligned) bubbles:** mirror the above on the left side.
- Single-message groups: full 18px on all corners, no tail treatment needed.

## 6. Timestamps & Date Separators

- **Date separator:** a centered pill/label (e.g. "4 กันยายน") whenever a message's date differs from the previous message's date. Always shown once per day, not per group.
- **Time label:** not shown by default. Reveal on tap of any bubble — show a small timestamp (e.g. "18:44") for ~2 seconds below that specific bubble, dismiss on next tap elsewhere or after timeout.
- Do not show a timestamp permanently on every bubble — too noisy for the restrained aesthetic.

## 7. Delivery / Read Status

- Applies only to the **last outgoing bubble in the entire conversation** (not every bubble, not every group).
- States, small icon under the bubble, right-aligned, muted gray → sapphire on read:
  - Sending: single faint clock/dot icon (no spinner overlapping the bubble)
  - Sent: single checkmark
  - Read: single checkmark, tinted sapphire (`#1B3A6B`)
- Remove the current spinner-over-bubble treatment entirely — it overlaps text and reads as a loading bug rather than a status indicator.

## 8. Whitespace Discipline

Do not apply the group/inter-group spacing values above uniformly as "more space = safer." The intent is rhythm: tight within a thought, open between thoughts. Test on a real conversation with mixed burst-lengths (1 message, 4 messages, 2 messages) to confirm the visual rhythm reads correctly before shipping.

## 9. Out of Scope (unchanged)

- Header (back button, avatar, name, overflow menu) — no changes needed, current implementation is correct.
- Input bar (image attach, text field, send button) — no changes needed.
- Message content rendering (text, media, reactions) — not covered by this spec.

## 10. Implementation notes (added post-implementation)

Implemented in `app/lib/features/chat/presentation/conversation_screen.dart` (`_ConversationScreenState`/`_MessageBubble`) and `app/lib/features/chat/data/chat_repository.dart` (read-receipt data plumbing). A few decisions the spec left to the implementer:

- **"Sending" needed an optimistic bubble.** The composer previously wasn't optimistic — a bubble only appeared after the server round-trip returned. Section 7's "sending" state requires *something* on screen to attach that state to, so `_send()` now inserts a placeholder bubble (temp id) immediately, replaced by the real row on success or removed on failure. The composer itself isn't cleared until the send actually succeeds, so a failure leaves the typed text/image/reply exactly as-is (unaffected by this being optimistic).
- **"Read" needed a live data source.** There was no client-visible signal for "has the other participant read this conversation." `ConversationMeta` now also carries `otherUserLastReadAt` (the *other* participant's own `user_a_last_read_at`/`user_b_last_read_at`), and `conversations` was added to the `supabase_realtime` publication (schema.sql) so a `mark_conversation_read()` call on the other side flips the receipt from "sent" to "read" live, not just on next reload.
- **Date label format:** section 6's own example ("4 กันยายน") was taken literally — `D <Thai month name>`, no year, matching "today"/"yesterday" for those 2 cases.
