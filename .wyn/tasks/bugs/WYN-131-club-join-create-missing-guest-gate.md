# Bug Report — WYN-131

Status: deployed (PR #300 merged `c576a8d`, `deploy-web.yml` run #98 succeeded) — awaiting Founder's own in-app verification, see `.wyn/logs/deployments/2026-09-07-wyn-130-131-club-ghost-accounts-guest-gate-deploy.md`
Owner: AI Debug Engineer

Bug: Founder reported opening a Club share link (`https://wynos.online/club/b3f010b9-b788-41f8-8e86-c7abb717b6d2`) while not signed in, tapping "เข้าร่วม" (Join), and getting in immediately as what they described as a "ghost account" — and asked that people with no account not be able to tap Join at all.

Reproduction: could not reproduce the literal claim (a guest ending up as a real `club_members` row) against this codebase's actual schema — see Root Cause below, this turned out to be empirically impossible today. What *was* reproducible by code inspection, and is a real, independently-confirmed bug: a guest (WYN-072 Anonymous Sign-In session, or WYN-119's deep-link auto-guest-session — see `AuthGate._startGuestSessionForDeepLink`) that opens a Club page can tap "เข้าร่วม" and the button does nothing to stop them — no sign-in prompt, straight to `ClubRepository.joinClub()`. The same gap exists on "สร้าง Club" (Create Club) from both entry points (Explore Clubs tab, Home's Club section).

Root Cause: `app/lib/features/auth/presentation/widgets/guest_gate.dart` (`requireRealAccount()`) exists specifically to gate write actions a guest shouldn't be able to perform, and its own doc comment explicitly lists **"Club create-join"** as one of the actions it covers — but grepping every call site of `requireRealAccount` found it wired up in `root_shell.dart`, `home_feed_screen.dart`, `auth_gate.dart`, and `analytics_repository.dart` only. `ClubPage._toggleJoin` (the Join/Leave button), `ExploreClubsScreen._openCreateClub`, and `ClubSection._openCreateClub` (Home's own "สร้าง Club" shortcut) never called it — the gate was designed and documented but never actually connected at these 3 call sites.

What actually happens today when an ungated guest taps Join/Create, confirmed both by reading `AuthGate`'s own comment ("A guest's `profiles` row is never created at all") and by an empirical test against this repo's real `schema.sql` (inserted an `auth.users` row with no matching `public.profiles` row, then tried inserting a `club_members` row for it as that user under RLS): the insert is rejected outright —

```
ERROR:  insert or update on table "club_members" violates foreign key constraint "club_members_user_id_fkey"
DETAIL:  Key is not present in table "profiles".
```

`club_members.user_id references public.profiles (id)`, and a guest never has a `profiles` row, so a guest cannot actually become a Club member today — the FK constraint blocks it unconditionally, independent of this bug. So a guest tapping "เข้าร่วม" gets `ClubPage._runJoinAction`'s generic catch-all failure message ("เข้าร่วม Club ไม่สำเร็จ ลองใหม่อีกครั้ง") instead of a real membership row — misleading (it reads like a transient failure worth retrying, when retrying as a guest can never succeed), but not a data-integrity bug: no ghost `club_members` row, and no "ghost account" is created by this path that wasn't already possible before (a genuinely incomplete real signup, WYN-125/WYN-130's subject, is a separate mechanism — see Handoff to QA below).

Fix: wired `requireRealAccount(context)` into all 3 missing call sites, matching the exact pattern already used in `root_shell.dart`/`home_feed_screen.dart` (check first, `if (!mounted) return;` immediately after since it's the first `await` in each method):
- `ClubPage._toggleJoin` (`app/lib/features/club/presentation/club_page.dart`)
- `ExploreClubsScreen._openCreateClub` (`app/lib/features/club/presentation/explore_clubs_screen.dart`)
- `ClubSection._openCreateClub` (`app/lib/features/club/presentation/widgets/club_section.dart`)

A guest now sees the same "เข้าสู่ระบบเพื่อดำเนินการต่อ / ฟีเจอร์นี้ต้องมีบัญชีจริง สมัครใช้เวลาไม่ถึงนาที" prompt every other gated action already shows, instead of a raw insert failure. This is a bug fix restoring already-documented, already-built-elsewhere intended behavior to a guest-facing action real users hit today — not a new feature, so it is not staged-rollout-gated (`.wyn/company/WORKFLOW.md`'s own bug-fix exception).

Files Changed:
- `app/lib/features/club/presentation/club_page.dart`
- `app/lib/features/club/presentation/explore_clubs_screen.dart`
- `app/lib/features/club/presentation/widgets/club_section.dart`

No `supabase/schema.sql` change — this is purely a missing client-side gate, nothing to apply in the Supabase SQL Editor.

Tests: could not run `flutter analyze`/`flutter test` in this session (no Flutter SDK available in this environment). Checked `club_page_test.dart`/`explore_clubs_screen_test.dart` (the two existing widget-test files that exercise these call sites) both call `initFakeSupabaseSession(userId: 'viewer')` with the default `isAnonymous: false` — `requireRealAccount()` returns `true` immediately for a non-anonymous session (no dialog shown, no extra `pump` needed), so these tests should be unaffected; no test in this repo constructs an anonymous fake session against `ClubPage`/`ExploreClubsScreen`/`ClubSection` today, so there is no existing regression coverage proving a guest actually sees the prompt now — flagging for QA/AI Coding to add one (mirrors whatever pattern an existing anonymous-session widget test already uses elsewhere in this repo, if any exists).

Regression Risk: very low for a real (non-anonymous) account — `requireRealAccount()` returns `true` synchronously with no dialog whenever `user != null && !user.isAnonymous`, so every existing Join/Leave/Create-Club flow for a real signed-in user is unchanged. The only behavior change is for an anonymous/guest session, which previously could tap through to a guaranteed-to-fail insert and now sees a sign-in prompt instead.

Handoff to QA: please verify in an actual browser/app session as a guest (via "เข้าชม WYNOS ได้เลย" or a Club deep link while signed out) — confirm tapping "เข้าร่วม"/"สร้าง Club" now shows the sign-in prompt and never reaches `joinClub()`/`createClub()`. Also: **please get exact repro steps from Founder for the original report** (which sign-in method was used — Google, Email, or the guest button — and whether the resulting account could see itself already joined) — this fix closes the "guest can tap Join" gap conclusively, but if Founder's account genuinely ended up joined with a blank profile through some *other* path (e.g. a real signed-in account somehow reaching RootShell before `profile_private.onboarding_completed` was true — which `AuthGate`'s `FutureBuilder<OnboardingState>` branch is designed to prevent, per its own comment, but wasn't independently re-verified end-to-end in this session), that would be a distinct, more serious bug needing its own investigation. Flagging rather than closing that possibility out — per "ห้ามเดา root cause", this session did not have a way to reproduce that specific end-to-end path live against production.
