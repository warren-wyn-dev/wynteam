# Design — WYN-022: Comment Reply

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-022-comment-reply.md`

## Data

`parent_comment_id` (nullable, self-referencing FK, `on delete cascade`) added to all three comment tables (`drop_comments`, `pop_comments`, `club_post_comments`). Depth is capped at exactly one level by a `before insert` trigger per table (`prevent_nested_*_reply`) that rejects an insert whose `parent_comment_id` itself already has a non-null `parent_comment_id` — simpler and more reliably enforced than trying to encode it as a `CHECK` constraint (which can't run a self-referencing subquery).

Comment count is unaffected: `like_count`/`comment_count` on `drops`/`pops`/`club_posts` are plain `count(*)` over the comments table (see `home_feed`/`fetchPosts` etc.), so a reply is already counted the moment it's inserted — no new counter, no code change needed for R3.

## UI (all three comment surfaces: Drop, Pop, Club post)

- Each top-level comment (`parentCommentId == null`) gets a small "ตอบกลับ" text button next to its existing actions.
- Tapping it sets a `_replyingTo` state (parent id + author name) and focuses the comment composer, which shows a small "ตอบกลับ [name]" chip above the input with an X to cancel.
- Replies (`parentCommentId != null`) render indented (extra left padding, ~40px) directly under their parent, grouped by iterating the flat comment list and inserting each reply right after its parent — no separate fetch, the existing `fetchComments` query already returns every comment for the post in one call.
- Replies get the same Like/Delete affordances as top-level comments (same permission rules: owner can delete their own, anyone can like) but **no "ตอบกลับ" button of their own** — that's what keeps nesting to one level in the UI, backed by the DB trigger as the real enforcement.
- No new empty/loading/error state -- replies are just more items in the same list that already has all three.

## Non-goals

- No "view N replies" collapse/expand -- reply counts are expected to be low; if that changes, collapsing is a narrowly-scoped follow-up to this one screen area, not a reason to hold this round.
- No `@mention`-style auto-fill of "@replying-to-username" in the composer text -- the "ตอบกลับ [name]" chip already shows who's being replied to.
