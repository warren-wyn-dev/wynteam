# Deployment Log — WYN-140: rebuild feed-tab swipe on a real PageView

```
Release: WYN-140 -- Home feed tab swipe rebuilt on a real PageView (was: a hand-rolled
  GestureDetector + rubber-band AnimatedContainer). "สำหรับคุณ"/"ติดตาม" each get their own
  independent ModeFeedPage widget (pagination, scroll position, like/save/redrop/poll/
  hide/undo/quote-redrop, new-posts pill) instead of sharing one state that reset on every
  tab switch; Club (FromYourClubsFeed) unchanged in behavior, now hosted the same way.
Version: WYNOS v1.0.0 Beta4 (no version bump -- same reasoning as every other WYN-140 step:
  interaction polish on an existing, already-shipped screen, not a new capability)
QA Status: PASS (AI QA & Security, 2026-09-08) -- see .wyn/tasks/approved/WYN-140-home-feed-premium-polish.md
Build Status:
  - flutter analyze: 0 issues (CI run #345, workflow_dispatch on the merged branch, before PR merge)
  - flutter test: 1443/1443 passed (same run)
  - 3 earlier CI attempts (runs #333, #334, #337) caught real issues before this reached
    production: a lint nit, and two separate test-fixture timer leaks (a fresh
    SupabaseClient-backed repository constructed inside a testWidgets body instead of once
    in setUpAll, and a DoubleTapLike timer not given time to settle) -- both root-caused
    and fixed, none of them bugs in the rewrite itself
  - PR #319 merge conflicted with a concurrent session's own merged PRs (#316/#317/#318,
    unrelated guest-browsing work) -- both touched .wyn/company/DECISIONS.md near the same
    line; resolved by keeping both sessions' entries, no code conflict. Re-verified green
    (CI run #345) on the merged commit before merging the PR.
  - No local Flutter SDK in this session at any stage -- every build/test result above is
    from real GitHub Actions runs, not local execution or code-reading alone
Deployment Target: Production web (Vercel, wynos.online) via .github/workflows/deploy-web.yml
Changes:
  - app/lib/features/home/presentation/home_feed_screen.dart (rewritten -- shell only now)
  - app/lib/features/home/presentation/widgets/mode_feed_page.dart (new)
  - app/lib/features/home/presentation/widgets/from_your_clubs_feed.dart (AutomaticKeepAliveClientMixin added)
  - app/test/home_feed_screen_test.dart (swipe + rubber-band groups replaced; 1 new
    carousel-vs-PageView gesture-arena test)
  No schema/RLS/backend changes. No new dependencies. No new color/spacing/motion tokens.
Deployment Result:
  - PR #319 merged to main via squash, commit e6848ec (2026-09-08 08:36 UTC)
  - deploy-web.yml run #109 (workflow_dispatch on main) -- SUCCESS
    https://github.com/warren-wyn-dev/wynteam/actions/runs/34205374469
Production Verification:
  - Verified by this session: `curl -I https://wynos.online/` -> HTTP 200, last-modified
    timestamp matches the deploy completion time -- fresh build served, no error page
  - NOT verified by this session: the actual feel of the swipe on a real touch device (does
    the destination tab's content genuinely slide in smoothly now, does dragging over a
    post's own multi-image carousel still scroll the carousel and not the tabs, any
    conflict with a system/browser back-swipe gesture). This is the same risk category
    Founder explicitly accepted before this specific rewrite ("ทำเต็มรูปแบบ (Recommended)"
    after being shown the cost) because it cannot be verified by CI or this sandbox -- only
    by using the real app. Per WORKFLOW.md's Production Verification split: CI result and
    HTTP reachability are what this session can confirm mechanically; whether the swipe
    feels right on production is for Founder to confirm before this task moves from
    approved/ to completed/.
Rollback Plan:
  - This is a structural rewrite of the Home feed's tab-switching mechanism (bigger blast
    radius than any earlier WYN-140 step), but additive in the sense that no data/schema is
    touched and every existing interaction (like/save/redrop/poll/hide/undo) kept its exact
    logic, just relocated. If Founder reports something is broken or feels wrong, the fix is
    either a small follow-up commit or, if needed, reverting commit e6848ec on main and
    re-running deploy-web.yml -- reverting drops back to the rubber-band-cue version (PR
    #315/#317's deploy), not further, since this is one squash commit on top of that. No
    database rollback, no data loss risk. Per VERSION_CONTROL.md, AI does not roll back on
    its own judgment -- if something looks or feels broken, stop, report the specific
    symptom, and wait for Founder's decision.
```

## หมายเหตุ

Task `.wyn/tasks/approved/WYN-140-home-feed-premium-polish.md` ยังไม่ย้ายไป `completed/` — รอ Founder เปิด
แอปจริงยืนยัน 2 เรื่องที่ค้างมาตั้งแต่ Phase 1/Phase 2 เดิม (haptic ปุ่ม Drop, ความรู้สึกของ swipe) บวกกับตอนนี้
เพิ่มการยืนยันว่า swipe แบบ PageView จริงลื่นสมจริงตามที่ Founder ขอหรือไม่

ระหว่างเปิด PR พบว่า branch นี้ merge เข้า `main` ไม่ได้ (conflict) เพราะมีอีก session หนึ่งทำงานคู่ขนานอยู่บน
repo เดียวกัน (feature guest browsing, PR #316/#317/#318 merge ไปก่อนหน้าไม่กี่นาที) — conflict อยู่แค่ใน
`DECISIONS.md` (ทั้งสอง session เขียน entry ใหม่ใกล้บรรทัดเดียวกัน) ไม่มี code conflict จริง แก้โดยเก็บ entry
ของทั้งสอง session ไว้ครบ แล้ว trigger CI ใหม่บน merge commit ก่อน merge PR จริง ตามขั้นตอนความปลอดภัยปกติ
