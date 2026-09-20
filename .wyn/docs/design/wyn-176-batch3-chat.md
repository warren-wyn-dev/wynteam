# WYN-176 Batch 3 — Chat (Conversation View)

Status: DESIGN — preview ready, waiting on Founder approval before AI Coding
Preview: (published as an Artifact — see chat)

## Scope check against real code

Chat inbox (list view) already went through its own redesign rounds (WYN-159/169/170) and already has
press-scale motion per those tasks — not touched again here. WYN-160 batch 5 (2026-09-17) already fixed
Chat's stray color tokens and rebuilt the message composer into today's pill input group (22px radius) with
a circular send button — those shapes already match the target scale, same story as Composer's batch 2.

The real gap, confirmed by reading `chat-routes.tsx` + `conversation-modern.css` + `phase3.css`, is the
**conversation view's** interactive chrome having zero press feedback anywhere:

1. `.conversation-modern-back` / `.conversation-modern-more` — header back and overflow-menu buttons
2. `.conversation-profile-button` (×2: "ดูโปรไฟล์" / follow toggle) — the profile-hero action pills
3. `.message-image-picker` — attach-image button
4. `.message-input-group > button[type="submit"]` — the send button
5. `.message-delete` — the delete-message icon that appears on long-press-reveal
6. `.message-clear-file` — cancel-attached-image button
7. `.route-icon-button` / `.route-icon-link` — shared circular icon button, also used by Chat's "new message"
   compose button and its modal's close button (and, being shared, also used on Post detail/Profile/Settings
   — fixing it here benefits those future batches too)

No radius/sizing changes anywhere — profile-hero buttons are already pill (999px), the send/attach/delete
buttons are already circles, the input group is already 22px. Purely additive, same as batch 2.

## Interactions

```css
.conversation-modern-back, .conversation-modern-more, .conversation-profile-button,
.message-image-picker, .message-input-group > button[type="submit"],
.message-delete, .message-clear-file, .route-icon-button, .route-icon-link {
  transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
/* :active scale(0.96) on each (:disabled excluded where relevant) */
@media (prefers-reduced-motion: reduce) { /* same selector list */ { transition: none; } }
```

## States / Responsive / Accessibility

No new states, no layout/breakpoint change, no size change. `prefers-reduced-motion` handled per above.

## Design Rules

1. No radius changes this batch — all shapes already match target scale (WYN-160 batch 5)
2. `.route-icon-button`/`.route-icon-link` is shared beyond Chat — fixing it here is a bonus for
   Post-detail/Profile/Settings, not scope creep, since it's the same universal press-feedback pass
3. Chat inbox (list view) already has its own press-scale from WYN-169/170 — not touched

## Handoff

→ **AI Coding**: apply the CSS above to `web/app/conversation-modern.css` (items 1-6) and `web/app/phase3.css`
(item 7, `.route-icon-button`/`.route-icon-link`) — verify each selector's real winning cascade rule first,
confirm no regression on Chat's existing regression suite (16 tests per WYN-160 batch 5's own verification).
