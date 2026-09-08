# Deployment Log — WYN-140 Phase 1: Home Feed Premium Polish

```
Release: WYN-140 Phase 1 -- Home Feed spacing rhythm, tab label rename, Drop button haptic,
  HomeFeedSkeleton 2-column parity, PostImage fade-in
Version: WYNOS v1.0.0 Beta4 (no version bump -- UI polish to an existing, already-shipped screen,
  not a new capability; Founder confirmed 2026-09-08 that WYN-125 staged-rollout gating does not
  apply here -- see .wyn/company/DECISIONS.md)
QA Status: PASS (AI QA & Security, 2026-09-08) -- see .wyn/tasks/approved/WYN-140-home-feed-premium-polish.md
Build Status:
  - flutter analyze: 0 issues (CI run #323, workflow_dispatch on the feature branch, before PR)
  - flutter test: 1437/1437 passed (same run)
  - PR #313 CI (fresh run on the merge-ready branch): Flutter job success, Admin (Next.js) success,
    schema.sql ordering success, Supabase Edge Functions success -- all green before merge
  - No local Flutter SDK in this session at any stage (Design/Coding/QA/Deploy) -- every build/test
    result above is from real GitHub Actions runs, not local execution or code-reading alone
Deployment Target: Production web (Vercel, wynos.online) via .github/workflows/deploy-web.yml
Changes:
  - app/lib/features/home/presentation/widgets/home_drop_card.dart
  - app/lib/features/home/presentation/widgets/home_pop_card.dart
  - app/lib/features/home/presentation/home_feed_screen.dart
  - app/lib/features/home/presentation/widgets/home_feed_skeleton.dart
  - app/lib/features/root/presentation/root_shell.dart
  - app/lib/core/widgets/post_media.dart
  - app/test/home_feed_screen_test.dart (label string updates only)
  No schema/RLS/backend changes. No new dependencies. No new color/spacing/motion tokens.
Deployment Result:
  - PR #313 merged to main via squash, commit 22ef42e (2026-09-08 06:34 UTC)
  - deploy-web.yml run #106 (workflow_dispatch on main) -- SUCCESS
    https://github.com/warren-wyn-dev/wynteam/actions/runs/34195255077
Production Verification:
  - Verified by this session (network egress to wynos.online available): `curl -I https://wynos.online/`
    -> HTTP 200, HTML head served correctly (OG tags, viewport meta, etc. all intact -- no error page,
    no stale/broken response)
  - NOT verified by this session: the actual visual/interaction result of the changes themselves
    (4px name/time gap, 12px content-to-media rhythm, "Club" tab label rendering, the Drop button's
    haptic buzz, the tab underline's smoother fade, the image fade-in, the skeleton's new shape) --
    these require opening the real app and looking/feeling, which this session cannot do. Per
    WORKFLOW.md's Production Verification split: CI result and HTTP reachability are what this
    session can confirm mechanically; whether the feature *looks and feels* right on production is
    for Founder to confirm before this task moves from approved/ to completed/.
Rollback Plan:
  - This deploy is UI-only, additive spacing/motion-token changes with no schema/migration and no
    feature-flag -- if Founder reports something looks wrong, the fix is either a small follow-up
    commit (most likely, since every change here is a few lines) or, if needed, reverting commit
    22ef42e on main and re-running deploy-web.yml. No database rollback, no data loss risk, no other
    system depends on this change. Per VERSION_CONTROL.md, AI does not roll back on its own judgment
    -- if something looks broken, stop, report the specific symptom, and wait for Founder's decision.
```

## หมายเหตุ

Task `.wyn/tasks/approved/WYN-140-home-feed-premium-polish.md` ยังไม่ย้ายไป `completed/` — รอ Founder
เปิดแอปจริงแล้วยืนยันว่าของที่เห็น/รู้สึกตรงกับที่คุยกันไว้ (โดยเฉพาะ haptic บนปุ่ม Drop ซึ่งต้องลองบนมือถือ
จริงถึงจะรู้สึกได้ เว็บพรีวิวบนคอมพิวเตอร์จะไม่มีแรงสั่น)

Phase 2 (swipe ระหว่างแท็บ, custom pull-to-refresh animation เต็มรูปแบบ) ยังไม่เริ่ม — บันทึกเหตุผลไว้ใน
`.wyn/company/DECISIONS.md` (ความเสี่ยงต่างชนิดจาก Phase 1: "compile พังไหม" ที่ CI ตอบได้ vs "gesture ขัดกัน
กับ carousel เดิม/feel ถูกไหม" ที่ CI ตอบไม่ได้)
