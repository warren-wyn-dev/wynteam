# WYNOS security view rollout — Founder-operated

This is the manual release package for source PRs #689, #690 and #691 and
the integrated combined security release candidate. It is **separate** from
the consumer Web Beta 1 PWA/Feed release PR #687.

## What is and is not approved

All migrations in this package are staged code, not authority to change
production. The 2026-09-07 standing policy in .wyn/company/APPROVALS.md
requires the Founder to initiate production database migrations. A generic
instruction to finish the feature does not amend that decision.

Before running anything live: independently review the final combined PR
and all green exact-commit CI, inspect affected staff/private endpoints in
a disposable environment, approve the precise migrations and record a
production rollback decision-maker. Run the manual workflow from MAIN
only after the reviewed branch is merged.

## Manual workflow

Workflow: .github/workflows/wynos-security-views-manual.yml

1. Run WYN188 with dry_run=true and the exact target project ref.
   Verify the CI summary says preflight passed and no DDL was applied.
   When the Founder separately approves WYN188, rerun with dry_run=false
   and type APPLY-WYN188 exactly. Inspect Moderator/Admin history plus a
   normal signed-in user; check the view has security_invoker=true.
2. Run WYN189 first as dry run. After separate approval, apply with
   APPLY-WYN189. Verify Admin audit view works, ordinary users see none
   and the raw audit_log table still has zero authenticated SELECT policies.
3. Run WYN190 first as dry run. After separate approval, apply with
   APPLY-WYN190. Verify staff see the sanitized moderation queue but
   cannot read others' raw reports or reporter IDs; user A/B see only
   their own bounded affinity projections, with no raw affinity SELECT.
4. Rerun Supabase Security Advisor after each stage. A clean
   security_definer_view ERROR category does not mean the full project
   has no other security findings; separately audit any authorized
   SECURITY DEFINER function-execution warnings.

The workflow requires a matching project ref, exact live confirmation
phrase, serial execution, catalogue-based preflight and postcheck. Dry
run is the default. It neither creates users nor sends notifications.

## Automated verification before release

The integrated PR contains three own disposable PostgreSQL role tests:
supabase/tests/wyn_188_moderation_history_invoker_test.sh,
supabase/tests/wyn_189_staff_audit_projection_test.sh and
supabase/tests/wyn_190_private_views_test.sh. They run with the entire
maintained RLS suite in .github/workflows/ci.yml, loaded against the
combined canonical supabase/schema.sql. Do not skip existing WYN-029,
WYN-142/143, WYN-155/156 or Admin regression checks.

## Rollback

The exact original projection definitions, access restrictions and
helper-drop order are documented in each migration header. Never roll
back blindly: check which stages were applied and whether later stages
still depend on prior views/helpers. The Founder decides each
production rollback after read-only incident inspection.

Production schema is untouched until the Founder runs a reviewed stage.
