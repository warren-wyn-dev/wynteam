# Deployment Log — WYNOS v1.0.0 Beta2 Audit & Completeness Pass (PR #222) — LIVE

```
Release: WYNOS v1.0.0 Beta2 full product audit + completeness pass. PR #222
  (`claude/wynos-beta2-audit-fevu5g` -> `main`), merged by Founder as `e93327d`
  at 2026-09-03T07:36:03Z. 7 commits, 68 files, +3,803/-316.
  No new feature in any commit -- every change makes an existing feature work
  properly, per the Founder's framing of Beta2.
Version: `main` HEAD `e93327d`.
QA Status: PASS -- flutter analyze clean, flutter test 1,086/1,086,
  flutter build web --release succeeds, supabase/tests/*.sh 27/33 on
  PostgreSQL 16.13 (up from 4/33; the 6 remaining failures are stale
  fixtures, not product defects -- see the final readiness report §4.2).
Build Status: green. CI (`ci.yml`) on the PR head: `Flutter — app`,
  `schema.sql ordering`, `Admin (Next.js)`, `Supabase Edge Functions (Deno)`
  all success. `Flutter — seller_app` failed -- pre-existing design-token
  mirror drift that reproduces identically on `main`, not this PR's (see §4).
Deployment Target:
  (1) Vercel project "web", https://wynos.online -- **LIVE**, `deploy-web.yml`
      runs #43 and #44, both success, both from `e93327d`.
  (2) Supabase project `kqokpocajhfbidcxpvhh` -- migration **reported applied
      by Founder** via SQL Editor; **NOT independently verified** (this session
      has no production credential). See §3.
Reports: `.wyn/docs/qa/wynos-v1.0.0-beta2-full-audit.md` (Phase 1 audit),
  `.wyn/docs/qa/wynos-v1.0.0-beta2-final-readiness.md` (final QA).
```

## 1. Pre-deploy ground truth (checked, not assumed)

Following this repo's own established discipline of not trusting the deployment
log alone, the real state was read from GitHub Actions and the live site before
concluding anything:

- Last deploy before this release: `deploy-web.yml` run **#42** (id
  `33712696655`), `main` @ `023ff0c`, success at 2026-09-03T03:50:54Z.
- `curl https://wynos.online/main.dart.js` -> HTTP 200, **4,236,817 bytes** --
  the true pre-deploy baseline.
- `023ff0c` is the *debug* commit that temporarily surfaced the raw exception on
  ViewProfileScreen. So production was, at that moment, running a build carrying
  a debug artifact that `6f20392` had already reverted on `main`, and was also
  missing two real fixes merged since (`a2ec553` AuthGate hang on a failed
  onboarding-state read, `905641a` profile row with no username crashing every
  screen that read it). This release ships all three.

## 2. Web deploy — verified

| Evidence | Result |
|---|---|
| `deploy-web.yml` run #43 (id `33730004309`), `e93327d` | success, 07:50:59Z |
| `deploy-web.yml` run #44 (id `33730019839`), `e93327d` | success, 07:51:15Z |
| `curl https://wynos.online/main.dart.js` | HTTP 200, **4,247,510 bytes** (was 4,236,817) |
| `curl https://wynos.online` | HTTP 200, 0.60s |

Two runs rather than one: both dispatched by the Founder within ~9 seconds of
each other, both from the same commit, both succeeded. Harmless -- the second
simply redeployed identical output. Worth noting only because it consumes two of
the Vercel Hobby plan's shared 100 deploys/day.

## 3. Database migration — Founder-reported, NOT verified here

The Founder applied `supabase/apply_to_production_beta2.sql` (9 indexes + 2
`drop function`) via the Supabase SQL Editor and reported it complete.

**This log deliberately does not claim it verified.** This session has no
Supabase production credential and never connected to the production database at
any point. The verification queries were supplied to the Founder but their
output was not returned to this session, so the applied state is recorded here
as reported, not as confirmed.

To confirm at any time -- expected result `9 / 1 / 1`:

```sql
select
  (select count(*) from pg_indexes where indexname in (
    'drops_created_at_idx','drops_author_created_idx','drop_likes_user_idx',
    'drop_comments_drop_created_idx','follows_following_idx',
    'follow_requests_target_idx','saves_content_idx',
    'club_posts_club_pinned_created_idx','club_post_comments_post_created_idx'
  )) as indexes_expect_9,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_poll_drop') as overloads_expect_1,
  (select count(*) from pg_views
   where schemaname = 'public' and viewname = 'home_feed') as home_feed_expect_1;
```

### What was deliberately NOT applied

- **SCHEMA-002** (the two `drop view if exists public.home_feed;` lines added to
  `schema.sql`). These exist only so `schema.sql` can load top-to-bottom into an
  *empty* database; each is immediately followed by a `create or replace view`
  that rebuilds it. Run standalone against production they would drop the view
  and nothing would recreate it, taking down Home, Search, Saved, Profile feeds
  and the ranked-feed RPC. An earlier version of the production checklist in this
  session wrongly listed them as a production step; that was caught and corrected
  before anything was run (commit `eb11fdc`), and
  `supabase/apply_to_production_beta2.sql` now carries the warning in-file.
- **`supabase/pending_approval_rls_with_check.sql`** -- NOT APPROVED for Beta2
  (Founder decision, 2026-09-03). The P0 it was written for does not exist:
  PostgreSQL applies an UPDATE policy's `USING` as its `WITH CHECK` when
  `WITH CHECK` is omitted, proven against 16.13 before anything was applied. The
  file is banner-marked and is deliberately not folded into `schema.sql` so it
  cannot be applied by accident during a migration.

## 4. Known red check on `main`: `Flutter — seller_app`

`seller_app/test/design/token_sync_test.dart` fails 2 of 4 checks --
`seller_app/lib/core/design/{wyn_colors,wyn_typography}.dart` no longer match the
canonical copies in `app/lib/core/design/`.

- Not this release's: `git diff` over `app/lib/core/design/` between the PR and
  `main` is empty, and the drift reproduces on `main` itself.
- Latent since **2026-08-30** (`47a176f`), which rewrote `app/`'s tokens without
  copying them to the mirror. Nothing surfaced it until now because `ci.yml`,
  which runs `flutter test` on every PR, only landed **2026-09-03** (`ff51d75`).
  PR #222 is simply the first PR to run it.
- Not fixed here on purpose: the prescribed fix (copy the two files over the
  mirror) would visibly restyle the whole ZOKY seller app -- the 2026-08-30
  rewrite changed the scale throughout (`titleSmall` 14→15, `labelSmall` 12→13,
  `bodySmall` 14→15, `headlineLarge` 28→32, letter-spacing to 0) -- which is a
  product change on a separate track this release was explicitly scoped out of.
  Recorded on the PR as a comment for that track's owner.

**This check will stay red on `main` and on every future PR until it is fixed.**
That is the real cost: a permanently red check trains people to ignore CI, and
will mask a genuine failure later.

## 5. Founder smoke test on production (reported)

Founder confirmed on the live site after deploy:

| # | Check | Result |
|---|---|---|
| 1 | Profile screen — the temporary raw-exception debug text is gone | ✅ |
| 2 | Open a post, go back — scroll position is kept, no jump to top | ✅ |
| 3 | Tap Like — scale-pop animation + haptic | ✅ |
| 4 | Long feed scroll — smoother, no duplicate posts | ✅ |

Overall: "ปกติ" (normal).

## 6. What this release actually changed

Full detail in the two reports; the short version, by category:

- **Correctness** — the "สำหรับคุณ" feed was silently mis-ordered (ranking scores
  read by position out of the unfiltered RPC rows while items came from the
  filtered list); rapid Like taps raced INSERT/DELETE/INSERT concurrently; offset
  pagination could show the same post twice; `searchProfiles` interpolated the
  raw query into a PostgREST `.or()` filter.
- **Scale** — Drop and Club-post comments were fetched unbounded (the more
  popular the post, the more certainly its comment section failed); nine indexes
  for feed and social-graph queries that had none usable.
- **Performance** — images decoded at upload size wherever painted small (a
  1600×1600 photo in a 130px tile is ~10MB of bitmap for 0.07MB of pixels); the
  ranked feed re-ran its 200-candidate scoring RPC on every page; independent
  queries awaited in sequence now issue together.
- **Completeness** — scroll position kept on back-navigation; visible retry on a
  failed load-more; Home skeleton; avatar falls back to the initial when the
  image *fails*, not only when the URL is null; offline distinguished from server
  error; feed tap targets raised from ~25px to the 44px this app's own design
  system defines.
- **Schema** — `schema.sql` can now load into an empty database (SCHEMA-002);
  `create_poll_drop`'s two obsolete SECURITY DEFINER overloads dropped
  (SCHEMA-003).

## 7. Remaining after this deploy

| Item | Status |
|---|---|
| Database migration verification (`9 / 1 / 1`) | Founder-reported applied, **unverified here** |
| `Flutter — seller_app` mirror drift | Open, ZOKY track, §4 |
| `EXPLAIN ANALYZE` on real production data | Not done — local numbers used synthetic data |
| Behavioural QA by AI QA & Security per `WORKFLOW.md` | Not done |
| 6 stale test fixtures (`wyn_038`, +5 reserved-username seeds) | Open, P3, §4.2 of the readiness report |
| `errorMessageFor` wired into only 3 screens | Open, P2 — ~60 other catch blocks still show the generic message |
| Beta3 scope (denormalised counters, cursor pagination, state management, image CDN) | Deferred, not started |
