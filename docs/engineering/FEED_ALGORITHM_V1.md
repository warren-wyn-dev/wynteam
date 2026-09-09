# WYNOS Feed Algorithm v1 — Production Candidate

Algorithm version: **1**. This label means repository-level production
candidate, not that migrations, refresh jobs, deployment, or production smoke
tests have completed.

## Authoritative pipeline

Authenticated Home request → Phase 5 maturity → Phase 7 effective experiment
config (production fallback) → bounded latest plus top-50 similarity expansion →
`home_feed` RLS and hard moderation eligibility → seven source scores → Phase 4
personalization → Phase 6 precomputed quality → Phase 1 target allocation and
fallback → session fatigue/diversity → underlying-content dedup → cursor/window
pagination → response → best-effort impression telemetry → trusted interaction
learning and aggregate observability.

Trending and Top100 remain independent precomputed global products. Similarity
only expands Home candidates and adds a bounded Recommended/Exploration signal.
It cannot bypass RLS, hide/not-interested, moderation, quality, dedup, or fatigue.

## Production defaults and bounds

`feed_algorithm_config` is the authoritative backend config for version 1:
200 Home candidates, top 20 similarity neighbors, at most 50 similarity-expanded
candidates, and similarity strength 0.10. Phase 1 source allocation and Phase 6
fatigue defaults remain typed Dart structures because those two deterministic
post-processing passes execute there. Phase 7 overrides are separate and no
experiment is seeded active.

Similarity uses unique-user co-engagement already normalized into Phase 4
affinities, caps each user's dimension evidence at 10, requires support >= 2,
uses cosine-like normalization, and shrinks by `support/(support+5)`. Neighbor
rank is bounded to 20. Impressions and fast skips are absent from positive
similarity inputs. Missing/stale (>48h) similarity is neutral.

## Observability

Successful non-empty Home windows write idempotent impression rows with source,
rank, maturity, content type, topic, candidate origin, experiment IDs, latency,
and algorithm version. `admin_feed_algorithm_dashboard()` is admin/moderator
gated and supports 1h, 24h, 7d, and 30d windows. It returns aggregate source,
maturity, latency percentile, fallback, similarity-origin, Trending/Top100
staleness and overlap, and experiment metrics. Raw telemetry and similarity
edges are not client-readable.

## Failure and feedback-loop invariants

Experiment resolution, exposure writes, and observability writes are optional;
failures preserve the production feed. Missing similarity falls back to the
Phase 1–7 candidate path. Quality and precompute staleness retain their existing
neutral fallback behavior. Feed impressions are distribution telemetry only and
are not inputs to Trending, Top100, affinities, quality, or similarity.

No critical candidate path performs a network query per post. Viewer state,
quality, affinities and similarity are batched; all source pools and neighbor
lists are bounded. Cursor identities remain capped at 200.

## Deployment requirements

Apply WYN-140 through WYN-146 in order in staging, configure scheduled refreshes
for Trending, Top100, quality, similarity and observability, deploy backend and
clients, validate admin authorization and telemetry ingestion, run query plans
and load tests against production-like data, smoke-test all feed surfaces, then
begin a controlled rollout. No automatic winner promotion exists.

The migrations are intentionally not auto-applied by a push. After approval,
run the manual **WYN Feed Algorithm v1 -- apply additive schema** GitHub Action,
enter `APPLY`, approve its `production` environment gate, and confirm its final
RPC verification passes. Then run **Deploy Flutter web to Vercel (production)**
and complete the Home smoke test. Until the schema action succeeds, compatible
clients serve the existing RLS-protected `home_feed` view instead of failing the
entire Home surface.
