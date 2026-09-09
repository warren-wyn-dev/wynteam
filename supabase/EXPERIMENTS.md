# WYNOS feed experiments

Phase 7 experiments are database-managed and authenticated-Home-only. The
migration creates no experiment rows. Production Phase 1–6 behavior is used
unless an experiment is active, in its server-time window, valid, eligible, and
the user is inside its deterministic rollout.

## Lifecycle

Use an owner/service-role transaction. Never expose these writes to app users.

1. Insert `feed_experiments` with `status = 'draft'`, a new immutable version,
   server-time boundaries, rollout basis points (`0..10000`), and non-sensitive
   maturity eligibility.
2. Insert two or more (or, for a smoke test, one) `feed_experiment_variants`.
   Variant weights must total exactly `10000`.
3. Validate with
   `internal.feed_experiment_is_valid(experiment_key, version)`.
4. Set `status = 'active'`. The activation trigger rejects invalid payloads and
   overlapping ownership of an active config key.
5. Set `status = 'paused'` for an immediate kill switch, or `completed` when
   analysis is finished. Neither state changes historical telemetry.
6. Create a new version for changed allocation, eligibility, dates, weights, or
   payload after exposure. Never mutate an exposed version.

## Allowlisted overrides

- `home.source_mix`: an object containing all seven source names with integer
  percentages in `0..100`, totaling exactly `100`.
- `fatigue.creator_factor`
- `fatigue.topic_factor`
- `fatigue.content_type_factor`
- `fatigue.repetition_factor`
- `similarity.enabled`
- `similarity.strength` (`0..0.25`)

Fatigue factors must be finite numbers in `0.1..1.0`. Safety, RLS, moderation,
blocks, hard eligibility, Trending, and Top100 are intentionally not
experimentable.

Example payloads belong in tests or an operator-reviewed draft transaction;
do not seed an active example through migrations.

## Measurement

`internal.feed_experiment_variant_metrics` provides aggregate exposure and
outcome counts/rates. Assignment resolution is read-only. Home records a daily
unique exposure only after it successfully builds the affected feed; repeated
serves increment `request_count`, while unique participant counts remain
stable. Server-side triggers attribute supported organic outcomes only after a
valid exposure. The framework never chooses a winner or promotes treatment
configuration automatically.
