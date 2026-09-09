# WYN-147 Home Feed Repetition Control

## Problem

Production observability showed that Home `For You` could repeatedly return the same high-ranked posts across refreshes. The WYN-146 telemetry call also submitted the full ranked candidate window, which is useful for ranking observability but is too broad to treat as evidence that the viewer actually received every candidate.

## Design

WYN-147 keeps the existing WYN-146 ranking model and source allocation intact. It adds a post-ranking repetition layer using only deliveries recorded after the WYN-147 migration starts.

The default cooldown policy is:

- delivered within 1 hour: score factor `0.05`
- delivered within 6 hours: score factor `0.40`
- delivered within 24 hours: score factor `0.75`
- older/unseen: score factor `1.00`
- deterministic 15-minute near-tie jitter: max magnitude `1.25` score points

The same factor is applied to all `feed_source_scores` for a content item so client-side source allocation cannot accidentally restore a recently delivered post to the top. The jitter is deliberately small and does not replace personalization with random ordering.

## Telemetry correction

`record_feed_impressions()` now accepts the existing payload but persists only rank positions 1-10. Current clients submit the whole ranked window when page 0 is built, so limiting persistence to the first page is a conservative proxy for content actually delivered to the viewer. Rows created before WYN-147 are ignored by repetition control through `feed_repetition_config.started_at`.

A future client iteration may move impression recording to page/visibility events for more exact delivery/view telemetry. WYN-147 does not require that follow-up to reduce refresh repetition safely.

## Security and privacy

The public `get_wynos_ranked_feed()` wrapper remains `SECURITY INVOKER`; existing viewer RLS continues to control visible content. Private impression history is read only through `internal.my_recent_feed_deliveries()`, a narrow `SECURITY DEFINER` helper constrained to `auth.uid()`.

## Rollout / rollback

This migration is additive and non-destructive. It does not activate experiments, alter feed source target weights, change the WYNOS product version, or delete user data. Production deployment still requires Founder approval. Rollback is never automatic; follow the repository rollback policy.
