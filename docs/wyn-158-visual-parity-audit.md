# WYN-158 — Home Visual Parity Audit

Scope: `web/` Next.js consumer app, Home surface only (header, tabs, feed
cards, media, action row, bottom navigation). Facts only — see the
follow-up commits on this branch for the fix.

## 1. `web/app/layout.tsx` — global CSS imports

24 stylesheets are imported globally, in this cascade order, plus one
runtime DOM-mutation component:

```
globals, phase2, phase2-polish, phase3, phase3-bridge, parity,
parity-auth-email, parity-final, parity-fixes, parity-completion,
parity-closure, post-detail-parity, parity-audit, profile-follow-audit,
club-audit, club-detail-audit, home-golden-final, profile-golden-final,
club-detail-golden, golden-drop-card, club-post-card-web,
founder-parity-lock, system-parity-lock, system-parity-final,
interaction-parity-final, pixel-parity-final, pixel-parity-audit-closure
```

Every route pays the weight and specificity risk of every file, every
time, regardless of which route is rendering. `<body>` also renders
`<PixelParityRuntime />` (see §6).

## 2. CSS file inventory

`web/app/*.css` = 26 files, ~5,760 lines. Naming pattern confirms the
"accumulated override" problem named in the task: `parity*`, `*-final`,
`*-closure`, `*-completion`, `*-fixes`, `*-audit`, `*-golden*`,
`*-lock`. Each new visual-parity attempt appears to have added another
file on top rather than editing the previous one.

## 3. Duplicate/competing selectors touching Home

Grep of Home-relevant class names across `web/app/*.css`:

| Selector | Files defining it |
|---|---|
| `.metric-button` | founder-parity-lock, home-golden-final, parity-audit, parity-final, phase2, pixel-parity-final, system-parity-lock (7) |
| `.audit-feed-post` | founder-parity-lock, home-golden-final, parity-audit, pixel-parity-final, system-parity-lock (5) |
| `.audit-action-row` | founder-parity-lock, home-golden-final, parity-audit, pixel-parity-final, system-parity-lock (5) |
| `.audit-more` | founder-parity-lock, home-golden-final, parity-audit, pixel-parity-final (4) |
| `.route-bottom-nav` / `.route-nav-link` | parity-final, phase3, pixel-parity-final, system-parity-final (4, shared with every other route via `AppChrome`) |
| `.audit-follow-pill` | founder-parity-lock, home-golden-final, pixel-parity-final (3) |
| `.audit-caption` | founder-parity-lock, parity-audit (2, also consumed by the otherwise-generic `rich-post-text.tsx`) |
| `.parity-home-header` / `.parity-home-tabs` | parity-final, pixel-parity-final (2) |

Later-imported files win ties by import order, not by any documented
rule — `pixel-parity-audit-closure.css` (imported last) can silently
override any rule in any of the other 25 files. `!important` appears 22
times across 8 files (`founder-parity-lock.css` alone has 6), which is
a second, independent override channel on top of import order.

## 4. Runtime DOM mutation

`web/components/pixel-parity-runtime.tsx`, mounted in `layout.tsx` on
every page load, runs a `MutationObserver` over `document.body` whose
only job is to rewrite the *already-rendered* chat-badge text from
`99+` down to `9+` to match Flutter's cap. This is a DOM patch working
around a source-level bug (`parity-home-final.tsx` hardcodes `chatBadge
> 99 ? "99+" : chatBadge`) instead of fixing the source. Removed in this
change; the badge cap is now fixed at the source (`chatBadge > 9 ? "9+"
: chatBadge`), matching `home_feed_screen.dart`'s `count > 9 ? '9+' :
'$count'`.

## 5. Dead code found during the audit

- `web/components/parity-home.tsx` (618 lines) is never imported by
  anything (`app/page.tsx` renders `ParityAuthEntry` →
  `ParityHomeFinal`, not this file). Its classes (`.wynos-app`,
  `.wynos-main`, `.top-shell`, `.wordmark-row`, `.primary-tabs`,
  `.mode-strip`, `.post-media`, `.bottom-nav`, `.nav-button`,
  `.create-button`, `.center-state`, …) are the bulk of
  `app/globals.css`'s selectors and are equally dead — nothing renders
  them. Neither the component nor its matching rules in `globals.css`
  were touched by any of the 24 imported "parity" files, i.e. the app
  has carried two entirely independent, unreachable Home
  implementations side by side.
- `web/components/pixel-parity-runtime.tsx` — deleted, see §4.

## 6. Home component/DOM structure (before this change)

`app/page.tsx` → `ParityAuthEntry` → `ParityHomeFinal`
(`components/parity-home-final.tsx`, 951 lines) rendered the header,
tabs, feed list, post card, media carousel, action row, drawer and every
bottom sheet inline in one file, each piece styled by whichever of the
7 `.metric-button` (etc.) definitions happened to win the cascade that
week. Business-logic (data fetching in `lib/feed.ts`,
`lib/home-actions.ts`, `lib/home-feed-sources.ts`,
`lib/home-parity-data.ts`) was already reasonably separated from
rendering; the rendering itself was not separated into components at
all.

Bottom navigation lived inside `AppChrome` (`components/phase3-ui.tsx`),
shared by every route, using hand-drawn Material SVG glyphs (a
reasonable choice — see §8) but styled by the same 4-file
`.route-bottom-nav`/`.route-nav-link` cascade as everything else.

## 7. Flutter Beta4 source of truth (extracted, verbatim values)

Read directly from `app/lib/**` (not inferred from screenshots):

**Colors** (`core/design/wyn_colors.dart`): `ink #12120F`, `paper
#FFFFFF`, `graphite #8A8880`, `faint #C7C4BC`, `hairline #E8E6E0`,
`sapphire #1B3A6B` (the one brand accent — verified badge, mentions,
active ReDrop, avatar ring), `iconLikeActive #F44336` (Material red,
Founder-approved, deliberately not sapphire). Hashtag link color is a
*separate*, Founder-approved exception living in
`core/widgets/hashtag_text.dart`: `#1D9BF0` — not sapphire. (The task
brief's "~#1D9BF0" guess for hashtags is correct; sapphire is a
different, non-hashtag token — this audit confirms both from source
rather than assuming either.)

**Font stack** (`core/typography/browser_system_text_web.dart`, the
actual contract this app's own Flutter Web build uses on Apple mobile
Safari): `-apple-system, BlinkMacSystemFont, "Thonburi", "SF Pro Text",
"Segoe UI", Roboto, "Noto Sans Thai", "Helvetica Neue", Arial, "Apple
Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif`. The
web app's previous `--font-system` was missing `Thonburi`/`SF Pro
Text`/the three emoji fallbacks — real iPhone Safari does have access
to system fonts (unlike Flutter Web's CanvasKit), so matching this
exact stack is how the two get the same Thai (`Thonburi`/`Noto Sans
Thai`) and emoji rendering.

**Home header** (`home_feed_screen.dart` + `wynos_social_chrome.dart`):
height **52px** (Home is intentionally denser than the generic 60px
screen header), no bottom divider, horizontal padding = 8px
(`WynSpacing.space2`), leading/trailing slots 48×48
(`touchTargetRecommended`), hamburger `Icons.menu` size 22, logo mark
height 19 + 8px gap + "WYNOS" 17px/700/letter-spacing 1.2/ink, chat
icon `Icons.chat_bubble_outline`, unread badge positioned
`right:-6,top:-4`, min 16×16, padding 4px/1px, radius 8, text 10px
bold, capped at `9+`.

**Home tabs** (`wynos_social_chrome.dart`): row height 52px, one bottom
hairline on the whole bar (not per-tab), label 14px, weight 700
(selected)/500 (unselected), color ink/graphite, 36×2px pill indicator
under the label, ink when selected else transparent.

**Post card** (`home_drop_card.dart` + `home_card_metrics.dart`):
edge inset 16px, avatar diameter **44px**, avatar→content gap 8px
(content column starts at x=68), vertical rhythm around the whole card
**3px** (top/bottom padding, and the same 3px between actions and the
next divider), author name 17px/700/height 1.15/ink, verified badge
14px sapphire, gap to timestamp 8px, timestamp 15px/400/height
1.15/color = `colorScheme.outline` (**not** graphite), Follow pill
(when shown) is a black filled Stadium pill, height 28px, 12px
horizontal padding, 13px/700 label. Caption 17.5px/400/height 1.32/ink,
visually lifted 3px toward the author row so the trailing gap to
media/actions is effectively **0px** (not a typo — see
`home_card_metrics.dart`'s own comment). Single-image media: aspect
ratio clamped to 0.8–1.91 from true pixel dimensions, capped at 75% of
viewport height, `border-radius: 16px` (Home only — Post Detail/Club
use `0`, "let the image be the hero"), right-inset only (16px), does
not bleed to the screen edge. Multi-image: 82%-width peeking cards,
8px gaps, same 16px radius, right edge deliberately bleeds past the
16px inset. Action row: Like/Comment/ReDrop/Share, icon 24px, 6px
icon→count gap, 16px between metrics, count text 13px/500
(`labelSmall`), Like red `#F44336` when active else graphite, ReDrop
sapphire when active else graphite (hidden entirely, not disabled, when
audience isn't "everyone"), Comment always graphite, Share
(`send_outlined`, no count) always graphite, every tap target ≥44px
tall. View-count (eye icon) is explicitly hidden on Home
(`showViewCount: false`) — it is not part of Home's action row at all.
Divider between posts: 1px hairline, no extra margin (Flutter
`Divider(height: 1)`).

**Bottom navigation** (`wynos_founder_bottom_navigation.dart` +
`wynos_founder_metrics.dart`): total content height **80px** (+ bottom
safe-area inset), icons 28px using **Material-rounded glyphs**
(`home_rounded`/`home_outlined`, `search_rounded`, `person_rounded`/
`person_outline_rounded`), center Post button diameter **56px**, label
11.5px, line-height 1, weight 600 (selected)/400 (unselected), color
ink/graphite, icon→label gap 4px (6px for the center Post action),
notification icon swaps `Icons.notifications`/`notifications_outlined`
via a badge-aware pair of icons rather than a single glyph. This is
distinct from (denser than) the app's generic `labelMedium` (13px) nav
token — the Home/root bottom nav overrides it explicitly.

## 8. What was already correct

- Business-logic separation (`lib/feed.ts`, `lib/home-actions.ts`,
  `lib/home-feed-sources.ts`, `lib/home-parity-data.ts`) was sound and
  is preserved unchanged by this fix.
- `AppChrome`'s bottom nav already used hand-drawn Material SVG glyphs
  instead of Lucide approximations, which is the right call per the
  task brief ("do not use Lucide approximation if Flutter uses a
  visibly different Material glyph") — this fix keeps that approach and
  only corrects sizing/geometry/typography to match §7.
- `rich-post-text.tsx` was already a standalone, reusable component.

## 9. Fix approach (this branch)

1. Delete the runtime DOM patcher and the dead `parity-home.tsx` +
   its matching dead rules in `globals.css`.
2. Extract Home's rendering into dedicated components
   (`HomeHeader`, `HomeTabs`, `HomePostCard`, `PostAuthorRow`,
   `PostMediaCarousel`, `PostActions`, `BottomNavigation`) under
   `web/components/home/`, each styled by a single new stylesheet
   (`web/app/home.css`) using fresh, non-colliding class names — no
   `!important`, no cross-file overrides.
3. Delete the Home-only selector blocks for the old
   `.parity-home-*`/`.audit-*`/`.metric-button`/`.home-*` classes from
   the 9 legacy files that defined them once nothing renders those
   classes any more; delete any of those files that end up empty.
   `.route-bottom-nav`/`.route-nav-link` are consolidated the same way
   since `AppChrome` is shared by every route.
4. Business logic in `parity-home-final.tsx` moves, largely unchanged,
   into the new `HomeScreen` component; data hooks/libs are untouched.
