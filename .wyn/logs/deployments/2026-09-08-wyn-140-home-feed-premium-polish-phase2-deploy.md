# Deployment Log — WYN-140 Phase 2: Home Feed swipe gesture

```
Release: WYN-140 Phase 2 -- swipe gesture between Home feed tabs (สำหรับคุณ/ติดตาม/Club),
  velocity-gated at 200px/s, reuses the existing tab-tap _selectFeedMode() transition
Version: WYNOS v1.0.0 Beta4 (no version bump -- same reasoning as Phase 1: UI/interaction polish
  on an existing, already-shipped screen, not a new capability; Founder already confirmed WYN-125
  staged-rollout gating does not apply to WYN-140 -- see .wyn/company/DECISIONS.md)
QA Status: PASS (AI QA & Security, 2026-09-08) -- see .wyn/tasks/approved/WYN-140-home-feed-premium-polish.md
Build Status:
  - flutter analyze: 0 issues (CI run #329, workflow_dispatch on the feature branch, before PR)
  - flutter test: 1442/1442 passed (same run -- 1437 pre-existing + 5 new swipe-gesture tests)
  - First attempt (CI run #328) caught 2 real test-authoring bugs before this ever reached
    production: tester.drag() not simulating real release velocity, and a repository-fixture
    timer leak from not following this test file's own setUpAll() convention. Both fixed and
    re-verified green on run #329 before opening the PR.
  - PR #315 CI (fresh run #330 on the merge-ready branch): Flutter job success, Admin (Next.js)
    success, schema.sql ordering success, Supabase Edge Functions success -- all green before merge
  - No local Flutter SDK in this session at any stage (Coding/QA/Deploy) -- every build/test
    result above is from real GitHub Actions runs, not local execution or code-reading alone
Deployment Target: Production web (Vercel, wynos.online) via .github/workflows/deploy-web.yml
Changes:
  - app/lib/features/home/presentation/home_feed_screen.dart (GestureDetector + _selectFeedMode
    + _onHorizontalSwipeEnd + _feedModeOrder)
  - app/test/home_feed_screen_test.dart (5 new tests + shared swipeTestHomeRepository fixture)
  No schema/RLS/backend changes. No new dependencies. No new color/spacing/motion tokens.
  Scope explicitly excludes a custom pull-to-refresh animation -- see DECISIONS.md.
Deployment Result:
  - PR #315 merged to main via squash, commit b7cf7a6 (2026-09-08 07:18 UTC)
  - deploy-web.yml run #107 (workflow_dispatch on main) -- SUCCESS
    https://github.com/warren-wyn-dev/wynteam/actions/runs/34198710747
Production Verification:
  - Verified by this session (network egress to wynos.online available): `curl -I https://wynos.online/`
    -> HTTP 200, last-modified timestamp matches the deploy completion time -- fresh build served,
    no stale cache, no error page
  - NOT verified by this session: the actual feel of the swipe gesture on a real touch device (does
    it register cleanly against the existing multi-image carousel's own horizontal scroll, does the
    200px/s threshold feel right, any conflict with system back-swipe gestures on iOS/Android web).
    This is exactly the risk category Founder explicitly accepted before this work started ("ยอมรับ
    ความเสี่ยง -- ให้ลุย Phase 2 ต่อเลย") because it cannot be verified by CI or by this sandbox --
    only by using the real app. Per WORKFLOW.md's Production Verification split: CI result and HTTP
    reachability are what this session can confirm mechanically; whether the gesture feels right on
    production is for Founder to confirm before this task moves from approved/ to completed/.
Rollback Plan:
  - This deploy is additive: a new GestureDetector wrapping the existing CustomScrollView, with no
    change to pagination/_items/_page state. If Founder reports the swipe conflicts with something
    (e.g. the image carousel, or a browser/OS back-gesture), the fix is either a small follow-up
    commit (e.g. narrowing the gesture recognizer, adjusting the velocity threshold) or, if needed,
    reverting commit b7cf7a6 on main and re-running deploy-web.yml. No database rollback, no data
    loss risk, no other system depends on this change. Per VERSION_CONTROL.md, AI does not roll back
    on its own judgment -- if something looks or feels broken, stop, report the specific symptom,
    and wait for Founder's decision.
```

## หมายเหตุ

Task `.wyn/tasks/approved/WYN-140-home-feed-premium-polish.md` ยังไม่ย้ายไป `completed/` — รอ Founder
เปิดแอปจริงแล้วยืนยันทั้ง 2 เรื่องที่ค้างจาก Phase 1 (haptic ปุ่ม Drop) และ Phase 2 (feel ของ swipe gesture,
ไม่ชนกับ carousel เลื่อนรูปหลายรูป/back-gesture ของเบราว์เซอร์)

Custom pull-to-refresh animation เต็มรูปแบบ (อีกครึ่งหนึ่งของ "Phase 2" เดิม) **ไม่ได้ implement โดยตั้งใจ** —
`RefreshIndicator` ใช้สี Sapphire ถูกต้องอยู่แล้วโดยไม่ต้องแก้โค้ด ส่วนการรื้อกลไกทั้งหมดเพื่อทำ animation
แบรนด์เองมีความเสี่ยงไม่คุ้ม (ดูเหตุผลเต็มใน `.wyn/company/DECISIONS.md`) — บันทึกไว้ให้ชัดว่านี่คือ scope ที่
ตัดออกโดยเปิดเผย ไม่ใช่งานที่ยังค้างอยู่
