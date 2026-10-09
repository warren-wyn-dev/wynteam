# WYNOS Admin Security Center — Phase 3 release gates

**Status:** Draft implementation slice; not authorization to modify authentication policy.

## What this branch implements
- Read-only status for the **currently authenticated** Admin/Moderator using Supabase Auth MFA factor metadata and Authenticator Assurance Level.
- Counts only **verified** TOTP/phone factors, never displays factor IDs, QR codes, OTP secrets, backup codes, tokens, passwords, IP/device metadata.
- Reads are protected by `requireAdminRole()` server-side; errors display **unknown/unavailable**, not "no MFA".
- The protected `/security-center` route and Central workspace menu are **disabled by default** by `NEXT_PUBLIC_ADMIN_SECURITY_CENTER_ENABLED`.
- No account writes, enroll/unenroll/challenge/verify, role changes, forced MFA, new permissions, migrations, provider changes or payments.

## Architecture decisions required before completing feature
1. Founder and Security approve whether MFA is optional or **required** for Admin/Moderator; if required, design a server-verified step-up gate without locking out valid existing staff.
2. Review the Supabase Auth factor lifecycle, TOTP enrollment confirmation, factor verification, lost-device recovery, rate limits and step-up for sensitive actions.
3. Determine whether multi-device session inventories or individual revocation are actually available from the provider. Never promise capabilities unsupported by Supabase Auth.
4. Design owner-only security event data and retention before exposing sign-in history or IP/device details.
5. Reauthentication, CSRF, stale-session handling, token/session rotation and direct-API bypass tests must pass on isolated synthetic accounts.

## Staging QA checklist
- [ ] Guest/user blocked at `/security-center`.
- [ ] Default flag OFF -> route returns not found for authorized staff; no Central menu link.
- [ ] With flag ON in **isolated Staging only**, Admin/Moderator see own read-only factor status.
- [ ] No factor / verified factor / unverified factor / MFA provider error map to accurate statuses.
- [ ] AAL1/AAL2 reflects actual provider state (never trust UI-side storage).
- [ ] No secrets/PII in rendered output, logs, URL or cached response.
- [ ] Mobile/desktop keyboard accessibility and page refresh work.
- [ ] No enrollment, disable action, policy change or device revocation occurs from this read-only route.

## Release boundaries
PR #1053 Workspace must land independently first. This feature's Draft PR is stacked on it, with no Production release and no changes to Food/Merchant or shared databases. Full MFA enrollment/enforcement requires **separate explicit security architecture approval**, new implementation and role-based E2E QA.
