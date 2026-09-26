# WYNOS Web Beta 1 — DS-001 foundation (proposal for Founder review)

Date: 2026-09-26. Scope: Next.js consumer `web/` only. Source of truth: current deployed commit `ac4e103e7125fd08416ded32d0dcc583cc42bc53`. This is a **tokens-and-contract-only** change. No existing component selector, layout, image geometry, icon, or route has been restyled. It is not production approval.

## Visual direction

Premium minimal, approachable, native-like on mobile. White first; almost-black foreground, restrained neutral gray, vivid blue for interactive links, vivid red only for liked hearts, yellow–orange Verified badge with black check. Preserve approved Feed image arrangement, compact caption/action spacing, far-right Bookmark, five-tab dock and existing icon artworks. Dark mode uses the already deployed neutral inversion; do not independently invent a second brand.

## Semantic color roles — do not use arbitrary page-level hexes

| Role | Light | Dark | Token | Release rule |
| --- | --- | --- | --- | --- |
| Background | #FFFFFF | #000000 | `--wyn-bg` | Current production |
| Surface | #F5F5F5 | #111111 | `--wyn-surface` | Current production |
| Text | #171717 | #FFFFFF | `--wyn-text` | Current production |
| Secondary | #737373 | #A3A3A3 | `--wyn-text-secondary` | Current production |
| Muted | #9A9A9A | #666666 | `--wyn-text-muted` | Current production; not small body text |
| Divider | #E5E5E5 | #222222 | `--wyn-border` | Current production |
| Strong border | #D4D4D4 | #666666 | `--wyn-border-strong` | Current production |
| Small clickable blue text | #0969DA | #5EB1FF | `--wyn-color-link` | Proposed accessible shared text link |
| Vivid blue / large links | #1D9BF0 | #5EB1FF | `--wyn-color-link-vivid` | At 3.00:1 on white, not for ordinary small white-background text |
| Selected Like heart | #FF3B30 | #FF3B30 | `--wyn-color-like` → `--wyn-like` | Existing approved red; distinguish with filled heart / aria-pressed, not color alone |
| Error / destructive accent | #E0203D | #E0203D | `--wyn-color-danger` → `--wyn-accent` | Existing accent; error includes text and recovery action |
| Verified badge | existing yellow→orange + black check | unchanged | existing badge component | Do not redraw or flatten gradient |

White-background text contrast (computed): #0969DA 5.19:1; #1D9BF0 3.00:1; #E0203D 4.73:1. Small link text should use the accessible text role; the brighter blue is an optional high-emphasis/decorative role. Before changing live clickable text from its current blue, show the Founder a side-by-side Login/Feed preview. Do not change red Like to the unrelated danger-accent red.

## Type, spacing and control geometry

Existing shared type tokens: caption 12px (time/count), secondary 13px, body 14px, input **at least 16px**, subhead 17px, page title 20px, display/composer 22px. The already approved Home/Profile post body is 15px and may remain a role-specific exception. Respect browser text zoom; never solve overflow by disabling zoom or clipping Thai labels.

Spacing: existing `--wyn-space-1/2/3/4/5/6/8/10/12` = 4/8/12/16/20/24/32/40/48px. Work from semantic roles (post header→caption, caption→media, media→actions, form label→input→error), not indiscriminate global margins.

Heights: primary button 50px; compact button/input 44px; every interactive hit area at least **44×44px** even when the visible SVG is smaller. Current legacy `.route-primary` and `.route-secondary` are 38px, and `.small` are 32px: fix only after per-page viewport and overflow review. Don't enlarge visible icons merely to enlarge tap targets.

Existing icon proportions preserved pending visual approval: default 20px / 1.8 stroke; Feed actions 22px / 2.0 stroke (comment optically 24px); dock 28px / 1.7 stroke. Inactive gray, active black/filled; action state available in accessibility labels and pressed state. Keep Bookmark last.

Radius roles: pill 999px; button/control **currently 12px** (do not silently change to 10px based on an older proposal); input 10px; tile 14px; sheet 20px; bubbles may have special tail geometry. Icons and avatars retain approved shapes.

Motion: existing duration 160ms, spring easing and 0.96 pressed scale are the shared *target*, with existing Feed-action 0.94 and UI exceptions documented for visual review. Respect `prefers-reduced-motion: reduce`; disable nonessential transforms. Avoid success Toast for Like (heart/count already confirm), keep Save Undo and actionable error feedback.

## Reuse / implementation boundary

1. This change **only adds unused, semantic aliases** to `app/design-system.css` and a source/runtime regression. All existing styles remain visually unchanged; no immediate migration of 43 historical CSS imports.
2. On each subsequent approved screen, replace hardcoded literal colors/spacing with semantic tokens in a narrowly scoped PR. Require before/after screenshots at 320, 390 and 430px, light and dark, normal and keyboard-open when relevant.
3. Check loading, offline, empty, error, focus, disabled, tap target, text zoom and scroll/safe-area behavior; test no changed post-media geometry or button action.
4. After gradual adoption, separately audit unused override rules. Deleting old CSS now is prohibited because late parity/Founder locks still enforce active pixel decisions.
5. Do not merge this foundation PR into `main`, change Production, or start page-level appearance rollout without separate Founder approval.

## Founder review item

Approve the **two-role blue contract**: readable #0969DA for small clickable text on white, vivid #1D9BF0 for larger emphasis/decorative icons, and #5EB1FF in dark mode. This resolves the existing scattered #1677E7 / #1780E9 / #1D9BF0 values without choosing an inaccessible small-text color. All other semantic values mirror production or previously approved WYNOS decisions.
