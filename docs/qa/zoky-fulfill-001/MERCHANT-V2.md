# Merchant contract v2.1 integration

Candidate is based on integration 7dd20c6d and includes customer PR #1267
(b4300ade) for combined verification. Target is `feat/zoky-fulfill-001`, not
main or a production branch. Customer changes remain subject to that PR's checks.

Merchant now uses `ready_for_delivery` and `delivered` for pickup, completing
collection through `food_complete_pickup`. Refund evidence uses the private
`food-private` bucket under `refunds/<order>/`. Store prep reads
`pickup_prep_minutes`. Flutter and the legacy Merchant entry share this contract.

The additional migration adds an authorized direct merchant cancellation RPC:
explicit refund decision, reason required, row lock, terminal-state protection,
and audit event. It preserves the documented temporary legacy refund risk.
Apply it after the existing fulfillment and Admin migrations. Roll it back first;
rollback retains all recorded decisions and refund evidence.

## Local verification

- Web Node regression suite: 437 passed.
- TypeScript typecheck: passed.
- ESLint: no errors (17 existing warnings).
- Flutter analyzer: no issues. Full 35-test suite passed; added no-show dialog
  regression also passed (4 dialog tests).
- Production Flutter build and font policy: passed.
- PostgreSQL 17 canonical integration suite, including the new cancellation
  authorization/decision/audit cases, repeated migrations and rollback: passed.
- Browser suite: pending; recorded after completion below.

These use synthetic accounts and an isolated local database. No production
migration or deployment has been performed. Production requires the repository's
review, QA, staging and protected environment gates. The older independent
alternative backend branches must not be used: their statuses and storage paths
are incompatible with contract v2.1.
