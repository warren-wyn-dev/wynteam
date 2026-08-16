# Design — WYN-018: Home Feed Ranking

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-018-home-feed-ranking.md`

**This is the highest-risk task in the "Feed & Club Update" set** — it's the only one that changes the ordering of the main Home feed WYN-007 already shipped and QA'd. Everything below is written to keep that change reversible and inspectable rather than to chase a "smarter" result.

## Scoring formula (R1) — transparent, not ML

```
score = recencyScore + engagementScore + followingBoost

recencyScore    = max(0, 168 - hoursSincePosted)        // linear decay over 7 days, floors at 0
engagementScore = likeCount * 2 + commentCount * 3       // a comment takes more effort than a like
followingBoost   = isFollowingAuthor ? 50 : 0
```

Every term is plain arithmetic over data already on the row (`created_at`, `like_count`, `comment_count`) plus one extra fact (does the viewer follow this author). No hidden state, no historical-behavior model, nothing that can't be recomputed by hand from the same 4 numbers. Implemented as a single pure function (`rankingScore`, `home_ranking.dart`) precisely so it can be unit-tested with fixed inputs, independent of any database call.

Note on scope: `home_feed` (the view this ranks) only ever contains Drop/Pop rows, never Club posts — Club content stays on its own "จาก Club ของคุณ" toggle (WYN-015), unchanged by this task. So the "Content จากคน/Club ที่ผู้ใช้ติดตาม" boost in the original brief only applies to the "คน" (author) half here; there's no Club-membership signal to fold in without merging Club posts into this same query, which is out of scope.

## Query shape (R2) — bounded ranked window, not true infinite ranking

PostgREST can't `order()` by a computed expression (confirmed already for Trending/Popular Clubs — same limitation, same workaround): fetch a bounded candidate set (most recent 200 rows, chronological), score and sort it client-side, then slice by page. This means the ranked feed is a **bounded top-200 window**, not infinite — past that, `hasMore` becomes `false`. Consistent with the exact tradeoff `ClubRepository.fetchPopularClubs` and `HomeRepository.fetchTrending` already accept for the same underlying constraint, and acceptable here for the same reason (this app is still at a scale where "the most recent 200 posts" already covers what most feeds need to rank meaningfully). If usage grows past that being a real limitation, the fix is a computed column on the view — a schema change, not a rethink of the formula.

## UI (R3) — chronological stays reachable, ranking doesn't silently replace it

Home's existing `SegmentedButton` (WYN-015: "สำหรับคุณ" / "จาก Club ของคุณ") gains a third option: **"สำหรับคุณ" (ranked, new default) / "ล่าสุด" (chronological, exactly what "สำหรับคุณ" used to do) / "จาก Club ของคุณ" (unchanged)**. Naming "ล่าสุด" matches the label WYN-019 already uses for Drop's own chronological tab, for consistency across the app. Nothing that currently reads the "จาก Club ของคุณ" path changes.

## Non-goals / explicit follow-ups

- **Drop tab's "For You" tab** (WYN-019) still uses chronological ordering, as that task's own design doc explicitly flagged ("Once WYN-018 ships, For You switches to the shared ranking query"). Wiring it to `rankingScore` is a natural next step but touches an already-shipped, already-tested screen a second time — scoped out of this task to keep this round's blast radius to Home only. Recommended as the very next small follow-up, not a reason to hold this.
- No engagement-metrics dashboard / no way to observe how the formula performs in production yet (flagged as a real gap in the task's own Risks — this app has no analytics layer to add one to right now).
- No per-user personalization beyond the following-boost (no topic modeling, no collaborative filtering) — intentional, matches "ไม่ใช่ black-box ML".
