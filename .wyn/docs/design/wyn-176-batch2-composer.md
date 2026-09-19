# WYN-176 Batch 2 — Composer Chrome

Status: DESIGN — preview ready, waiting on Founder approval before AI Coding
Preview: (published as an Artifact — see chat)

## Scope check against real code (same discipline as batch 1)

Read `components/beta4-composer.tsx` + `components/beta4-composer-refresh.module.css` +
`app/system-parity-final.css` before designing. Findings:

- WYN-160 batch 4 (2026-09-17) already fixed Composer's stray Sapphire-blue tokens and moved its radii to
  the *old* WYN-160 target scale (pill `999px` for the "โพสต์" button, tile `14px` for image preview, control
  `10px` for poll inputs) — those numbers already match the current target scale, so **no radius changes
  needed in this batch**, unlike batch 1's drawer which still had stale small radii.
- The "โพสต์" submit button (`.beta4-post`/`.headerPost`) is a **compact header pill** (42px height, same
  visual role as X/Twitter's post button), not a full-width Auth-style CTA — Auth's literal `24px/58px`
  numbers don't apply here for the same reason they didn't apply to batch 1's chrome.
- The draft-discard confirm dialog's "บันทึกร่าง" button (`.wynos-confirm-dialog footer button`) is a
  **generic shared dialog component**, not Composer-specific — out of scope for this batch (would need its
  own audit of every other place that reuses it); flagging as a candidate for a later "shared dialogs" batch.
- **Zero elements in Composer have any press feedback today** — confirmed via grep, no `:active` rule
  anywhere in the relevant CSS/module files.

## What this batch does

Universal spring press-feedback only (`scale(0.96)`, 160ms `cubic-bezier(0.34, 1.56, 0.64, 1)`, same as
batch 1 and WYN-163), no sizing/radius changes, on:

1. `.beta4-cancel` — header "ยกเลิก" text link
2. `.beta4-post` / `.headerPost` — header "โพสต์" pill button
3. `.quickAction` (×4: audience / add photo / camera / poll toggle)
4. `.ratio-chip` (aspect-ratio selector chips)
5. `.beta4-add-option` — "เพิ่มตัวเลือก" poll link
6. `.audienceOption` (×N) — rows in the audience-picker sheet
7. `.sheetHeader button` — audience sheet's close (X) button
8. Image-preview delete (X) buttons

## Interactions

```css
.beta4-cancel, .beta4-post, .quickAction, .ratio-chip, .beta4-add-option,
.audienceOption, .sheetHeader button, .beta4-image-preview button {
  transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
/* :active scale(0.96) on each, :disabled excluded where the element has that state */
@media (prefers-reduced-motion: reduce) { /* same selector list */ { transition: none; } }
```

## States / Responsive / Accessibility

No new states, no layout/breakpoint change, no size change — nothing here affects the 420px/350px
responsive rules already in the module CSS. `prefers-reduced-motion` handled per above.

## Design Rules

1. No radius changes this batch — Composer's radii already match the target scale from WYN-160 batch 4
2. `.wynos-confirm-dialog` (shared, not Composer-specific) is out of scope here
3. Press-feedback spring is universal, same curve as batch 1 and WYN-163

## Handoff

→ **AI Coding**: apply the CSS above to `web/app/system-parity-final.css` (`.beta4-cancel`, `.beta4-post`,
`.ratio-chip`, `.beta4-add-option`, image-preview delete buttons) and
`web/components/beta4-composer-refresh.module.css` (`.quickAction`, `.audienceOption`, `.sheetHeader
button`) — verify each selector's real winning cascade rule first, confirm no regression on the
composer-locked Flutter-parity dimensions (22px compose text, 70px row height, etc. — do not touch those).
