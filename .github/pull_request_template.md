## Summary

<!-- What changed and why? Keep scope narrow and link the WYN task/issue. -->

## Risk

- [ ] No user-facing behavior changes
- [ ] User-facing behavior changes are documented and approved
- [ ] Authentication / authorization / privacy behavior changed
- [ ] Database schema or data migration changed
- [ ] Infrastructure / dependency / build behavior changed

## Verification

- [ ] `flutter analyze` passes when Flutter code changed
- [ ] `flutter test` passes when Flutter code changed
- [ ] Flutter release build gate passes
- [ ] Admin lint/typecheck/build passes when Admin code changed
- [ ] Edge Function check/tests pass when Edge Functions changed
- [ ] Maintained PostgreSQL/RLS regression tests pass when backend/schema changed
- [ ] New or changed behavior has regression coverage
- [ ] Loading / empty / error / offline or retry states were considered where relevant
- [ ] Accessibility impact was checked for UI changes

## Security & privacy

- [ ] No secrets, credentials, private user data, or sensitive logs were added
- [ ] Server-side authorization still protects every changed protected action/resource
- [ ] Client input / uploads / third-party responses are validated at trust boundaries
- [ ] Rate-limit / abuse impact was considered for new public write paths
- [ ] Logging/analytics changes avoid unnecessary PII

## Database changes

- [ ] No destructive SQL was added
- [ ] Destructive SQL is explicitly Founder-approved and carries the required `WYNOS-DESTRUCTIVE-MIGRATION-APPROVED` marker
- [ ] Migration has a forward/rollback or recovery plan where applicable
- [ ] Production migration is **not** performed by merging this PR

## Release gate

- [ ] Change is reversible or has a documented recovery path
- [ ] Monitoring/diagnostics are sufficient to detect failure after release
- [ ] No unresolved CRITICAL security issue exists
- [ ] Any unresolved HIGH security risk has explicit documented Founder acceptance
- [ ] Production deployment remains a separate Founder-approved action

## Evidence / notes

<!-- Test output, screenshots, relevant logs, migration notes, or known limitations. -->
