# Maps reports implementation evidence — 2026-10-14

Scope: the Maps reports slice of [#1151](https://github.com/warren-wyn-dev/wynteam/issues/1151). This does not complete AI Secretary, shared integration acceptance, staging, UAT or production release. No production writes, migration apply or deployment was performed.

## Contract

- Existing place identity is `wynos_places.id` **text**, formatted `wynos_place_<32 hex>`. Intake requires the current database row to be active. External provider IDs, saved/private snapshots and inactive developer previews are rejected.
- A signed-in developer selects an existing public place by name and submits `wrong_info`, `closed`, `duplicate`, `unsafe` or `other` with 10–500 characters. The flow accepts no uploads, coordinates, movement history or contact fields. Name search reads only existing public place ID/name/address fields through the existing active-place RLS.
- The server masks common email, phone, URL and markup patterns before persistence and before Admin output. This is best-effort minimization, not a guarantee that arbitrary free text contains no personal information. The UI tells users not to include personal data.
- A transaction advisory lock serializes intake per reporter. At most five reports per rolling 24 hours and one active report per reporter/place are allowed. Reports never change place visibility or content and never punish a user or merchant.
- Owner status reads use `auth.uid()` and expose only the owner's report reference, public place name, category, status and timestamps. There is no caller-supplied reporter parameter. Account changes remount report state; older initial reads cannot overwrite a newly submitted report.
- `maps:view` can read a bounded, redacted queue/history without reporter IDs, profiles, contact fields or coordinates. `maps:edit` can move `open → reviewing → resolved/dismissed`. Every transition requires a 5–300 character reason and matching expected version; row locks make simultaneous edits conflict. Closed reports remain closed.
- Report events retain the masked review reason and state/version history. Global audit records only report/place references, before/after status and version. Direct report/event access is revoked from `PUBLIC`, `anon` and `authenticated`; RLS is enabled without broad table policies. RPCs use empty search paths and explicit auth/permission checks.
- Reporter/reviewer profile deletion sets their references to null. Public place deletion sets its reference to null and preserves the public name snapshot and event history.

## Rollout and rollback

The new consumer entry and page remain behind the existing developer rollout rule in [.wyn/company/WORKFLOW.md](../../.wyn/company/WORKFLOW.md#staged-rollout-เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่-เพิ่ม-2026-09-06). Intake/status RPCs also check `is_developer_account()` to prevent direct API bypass. The rule says: “ฟีเจอร์ใหม่ที่ผู้ใช้มองเห็น (user-facing) ทุกตัว ต้อง gate ด้วย developer account allowlist ... เป็นค่าเริ่มต้นเสมอ”. Admin access continues to use existing Maps view/edit permissions.

Forward migration: `supabase/migrations/20261014074023_wynos_maps_reports_v1.sql`, created with `supabase migration new`. Rollback: `supabase/rollbacks/20261014074023_wynos_maps_reports_v1_rollback.sql`, which revokes API execution while retaining reports/events and the harmless audit event allowlist addition. Reapplying the migration restores the API. Production apply/release remains a separate approved operation.

## Verification

```bash
PSQL=/workspace/scratch/admin-db/psql bash supabase/tests/wynos_maps_reports_test.sh
cd web && node --test tests/maps-reports.test.mjs
```

The isolated fixture uses PostgreSQL 17.11 in the existing disposable container with network disabled, synthetic users and a unique test database. It covers actual `authenticated` role execution, developer gates, owner A/B isolation, Maps view/edit/other-system denials, direct table/helper grants, common-contact masking, invalid/null inputs, state/version conflicts, simultaneous intake/admin updates, rate limit, migration rerun, data-preserving rollback/reapply, profile/actor/place deletion and unchanged place visibility. It does not prove deployed Supabase permissions, an authenticated staging flow or platform advisor results.

Focused helper tests cover strict place identity, minimal RPC payloads, invalid/inherited category keys, actionable errors, owner-status inputs and public-field-only name search with escaped LIKE wildcards. Browser evidence is recorded separately by coordinated Admin QA. Full #1151 acceptance still requires shared Maps/AI contracts, read-only AI tool allowlist, tenant evidence, authenticated nonproduction peer/UAT acceptance and explicit human approval before privileged or financial actions.
