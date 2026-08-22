# Design Task — WYN-024 follow-up

Status: **APPROVED — QA รอบ 5 PASS (2026-08-22)** — `flutter analyze` 0 error, `flutter test` 365/365 ผ่าน ยืนยันอิสระโดย QA ทั้ง 4 segment × 6 ความกว้างจอ (320-430px) + real interaction ผ่าน scroll — ย้ายเข้า `approved/` ส่งต่อ AI Deploy & DevOps
Owner: AI Design → AI Coding → AI QA & Security (PASS) → AI Deploy & DevOps
Screen: Home — feed-mode `SegmentedButton` (Screen 2 of `.wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md`)
Purpose: close the label-legibility bug that survived 2 Debug rounds (`.wyn/tasks/bugs/WYN-024-segmented-button-active-label-illegible-all-segments.md`) by fixing the actual root cause — a fixed-width-per-segment layout model — instead of continuing to trim padding
User Flow: unchanged from the original WYN-024 spec — tap a segment to switch Home's feed mode
Components: `SegmentedButton<_HomeFeedMode>` wrapped so segments size to their natural content width and the row scrolls horizontally when that exceeds the screen, instead of the current equal 4-way width split; DS-009's Rainbow indicator strip updated to track each segment's real on-screen geometry instead of an assumed equal split
Interactions: identical tap-to-select behavior; no new gestures beyond the scroll itself
States: no new state, no persistence of scroll position
Responsive Behavior: full behavior spec at `.wyn/docs/design/wyn-024-segmented-feed-mode-scrollable.md` — replaces the original spec's "icon+tooltip fallback below 360px" idea, which real-device measurement across 4 QA/Debug rounds proved was both the wrong threshold (issue exists at every real phone width, not just <360px) and the wrong fix shape (icons can't represent 4 abstract feed-mode concepts clearly)
Accessibility: all 4 segments keep full untruncated Semantics labels; horizontal scroll must remain reachable via standard screen-reader scroll gestures
Design Rules: no Design System token/color changes — DS-001–009 unaffected
Handoff: AI Coding — see `.wyn/docs/design/wyn-024-segmented-feed-mode-scrollable.md` for the full design rationale and requirements
