# Design — WYN-021: Mention System

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-021-mention-system.md`

## Compose-time: `MentionInput`

- New widget `MentionInput` (`core/widgets/mention_input.dart`) wraps a `TextField`: watches text changes, and when the caret sits right after an `@` (optionally followed by partial letters with no space yet), shows a dropdown of matching users below the field (reuses `ProfileRepository.searchProfiles`, WYN-009, debounced 400ms — same debounce-cancel discipline `SearchScreen` already established). Selecting a result inserts `@username ` at the caret and **records the selected user's id** in a `Set<String>` the widget exposes via `onMentionedUsersChanged` — this resolved-id set is what actually gets sent to the repository on submit, not a re-parse of the text.
- Wired into `CreateDropScreen` and `CreateClubPostScreen`, replacing their plain caption/content `TextField` (or `TextFormField`) with `MentionInput`. Both screens thread the resolved id set through to `DropRepository.createDrop`/`ClubPostRepository.createPost`, which gain an optional `mentionedUserIds` parameter.

## Render-time: extend `HashtagText`, don't fork it

WYN-021's own R2 asks for one shared render helper rather than a second regex parser — `HashtagText` (WYN-020) already owns caption rendering everywhere, so its regex grows an `@username` alternative rather than a new widget existing alongside it. A `@username` span renders the same tappable style as `#hashtag` (primary color, semibold) and, resolving username → user id via `ProfileRepository.fetchProfileByUsername` (new lookup, mirrors the existing fetch-by-id shape) on tap, opens `ViewProfileScreen`. An unresolvable mention (typo, deleted account) fails silently — same "swallow and no-op" posture `HashtagText`'s own repositories-built-from-Supabase.instance.client pattern already has for any other tap-time failure.

## Data: why a real entity table, unlike hashtags

WYN-020 stayed ILIKE-only because a false-positive hashtag match is harmless (worst case, an unrelated post shows up in a discovery feed). A false-positive *mention* would misfire a notification at the wrong person, which is a real, visible mistake — so this needs to know, with certainty, exactly which user was mentioned, not "a substring that looks like a mention." New tables:

```sql
drop_mentions (drop_id, mentioned_user_id)
club_post_mentions (club_post_id, mentioned_user_id)
```

Populated by the client at post-creation time (immediately after the `drops`/`club_posts` insert succeeds) from `MentionInput`'s already-resolved id set — not derived by re-parsing the caption server-side, since the resolution already happened correctly on the client and re-parsing would just reintroduce the same ambiguity hashtags accept but mentions can't.

## Notifications

- Two new types, `mention_drop`/`mention_club_post`, added to `notifications.type`'s check constraint (dynamic-constraint-name-lookup ALTER pattern, same as every prior type addition in `schema.sql`).
- `notify_drop_mention()`/`notify_club_post_mention()` triggers on `drop_mentions`/`club_post_mentions` insert, mirroring `notify_drop_like()`'s exact shape: actor = the post's author, recipient = `mentioned_user_id`, self-mention guarded the same way every other trigger guards self-notification (recipient = actor is a no-op, not an error).
- Thai message text added to `NotificationListScreen`/`SellerNotificationListScreen`'s `_messageFor` (app only has Drop/Club mentions, not Seller) and to the push Edge Function's `_lib.ts messageFor` — WYN-016 committed that function to mirroring the Dart client word-for-word, so it can't drift out of sync here either.

## Non-goals this round

- No mention-autocomplete keyboard navigation polish (arrow keys) beyond tap-to-select — matches `SearchScreen`'s own scope precedent.
- No editing captions after posting (doesn't exist yet for Drop/Club post at all), so no "mentions changed after the fact" case to handle.
