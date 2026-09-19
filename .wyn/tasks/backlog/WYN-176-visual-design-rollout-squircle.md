# Product Task — WYN-176

Status: approved — Founder ยืนยันทั้ง 2 จุดแล้ว (2026-09-19), ส่งต่อ AI Design ทำ batch 1
Owner: AI Product Manager → AI Design
Feature: WYNOS Web Beta1 — Visual Design Rollout (WYN-174 Track 2) — extend WYN-163's Apple-style squircle direction system-wide
Goal: Make the rest of WYNOS Web (Home, Composer, Chat, Profile/Settings, Search/Notifications/Club) visually consistent with the Auth screens' Apple-style redesign (WYN-163), instead of the app looking like two different products depending on which screen you're on
Target User: All WYNOS Web users — the whole app, not just onboarding
Problem: this is a continuation/reconciliation of two prior efforts, not a fresh redesign:

1. **WYN-160** (2026-09-17) set out to consolidate ~20 stray font-size/border-radius values into a 7/5-value scale across the whole web app, in 8 sequenced batches. Batches 1-6 (tokens, Auth, Home/Nav, Composer, Chat, Profile/Settings) shipped. Batch 7 (Search/Notifications/Club) and batch 8 (dead CSS cleanup) never happened — the task file is still sitting in `.wyn/tasks/backlog/`.
2. **WYN-163** (2026-09-19, two days after WYN-160 batch 6) redesigned Auth specifically, and picked *different, bigger* values than WYN-160's original targets after the Founder rejected the first attempt as "เหมือนแอปอื่นเลย": buttons `24px radius / 58px height / 16px-700 text` (not WYN-160's `999px pill`), inputs `18px radius / 56px height` (not WYN-160's `10px`), screen headlines `32px/800` (not WYN-160's `20px title`), plus a new spring-ish press-feedback (`scale(0.96)`, 160ms cubic-bezier). WYN-163's own design doc flagged this exact gap in advance (Design Rule #9): "ถ้าจะขยายทั้งเว็บต้องเป็นงานแยก" (extending this everywhere would need to be its own task) — that task is this one.

**Net effect right now**: Auth screens (`/welcome`, `/login`, `/signup/*`, `/onboarding/profile`, `/forgot-password`) look meaningfully bigger/bolder than every other screen in the app, which still carries WYN-160's older, more conservative values. Search/Notifications/Club never got *either* pass and still have the original ~20-value drift WYN-160 was written to fix.

## Requirements

Two things need Founder confirmation before AI Design starts (see Recommendation): whether WYN-163's values become the new system-wide target (superseding WYN-160's original numbers for buttons/inputs/headlines), and which batch to do first.

Assuming WYN-163 tokens become the system-wide target, the remaining work is:

- **Re-apply with new values**: Home/Bottom Nav, Composer, Chat, Profile/Settings — already consolidated once under WYN-160's older numbers, now need the WYN-163 button/input/headline values applied on top (colors/spacing/other radii from WYN-160 stay — only the squircle-specific numbers change)
- **First-time consolidation with new values**: Search, Notifications, Club — never got either pass, go straight to WYN-163's numbers, skip WYN-160's superseded intermediate values entirely
- **Known parity exception** (from WYN-160 batch 3): Home's post card already mirrors Flutter's `home_drop_card.dart` 1:1 for cross-platform visual parity and has its own locked tests — do not force the 7-value font scale or squircle radii onto it; this was correctly left alone before and should stay that way unless Founder explicitly asks to break Flutter parity
- **Batch 8 (dead CSS cleanup)** from WYN-160's original plan still applies once everything above lands

## Acceptance Criteria

- Every batch gets a before/after visual preview approved by Founder before AI Coding touches it (per the standing rule from WYN-141/WYN-160: "roll out in batches, never a single sweeping refactor," and the general "UI ใหม่ต้องมีภาพให้ Founder ดูก่อนเขียนโค้ด" rule)
- No batch changes business logic, Supabase contracts, or existing feature behavior — visual/token layer only
- Home's Flutter-parity-locked post card is not touched unless Founder explicitly says to break parity
- Each batch passes QA (functional + visual regression, screen-reader/contrast spot check) before moving to the next
- `prefers-reduced-motion` respected wherever the new press-feedback spring is applied (same pattern as WYN-163/WYN-175)

## Dependencies

- WYN-160 (`.wyn/docs/design/wyn-160-web-design-system-consolidation.md`, `.wyn/tasks/backlog/WYN-160-web-design-system-consolidation.md`) — this task effectively completes and supersedes it; WYN-160's task file should close into this one once Founder confirms
- WYN-163 (`.wyn/docs/design/wyn-163-onboarding-button-redesign.md`) — source of the token values being extended
- WYN-175 (`.wyn/tasks/completed/WYN-175-web-perceived-speed-motion.md`) — the press-feedback/motion utility pattern this can reuse for the spring-press interaction

## Priority

Founder-selected P0 (WYN-174 Track 2) — was blocked on WYN-163 finalizing, which it now has (deployed and Founder-confirmed 2026-09-19)

## Risks

- **Largest-scope track in WYN-174** — touches nearly every screen in the app across several batches; the batch-by-batch + visual-preview discipline exists specifically to keep this from becoming one risky sweeping change
- Token conflict between WYN-160 and WYN-163 could cause confusion if not explicitly reconciled with Founder first — doing so before any code avoids re-doing a batch twice
- Home's post card has a real, tested Flutter-parity lock — accidentally touching it would break cross-platform visual consistency and locked regression tests

## Recommendation

Two decisions before AI Design starts:
1. **Confirm WYN-163's tokens (24px/58px button, 18px/56px input, 32px/800 headline, scale(0.96) press) become the system-wide standard**, replacing WYN-160's original (never-shipped-everywhere) numbers for those same properties
2. **Confirm batch order** — recommend continuing WYN-160's original sequence (Home/Nav next, since Auth is done), but Search/Notifications/Club could go first instead since those screens never got any consolidation pass at all and are the rawest gap

## Handoff

**[2026-09-19] Founder ยืนยันแล้วทั้ง 2 จุด**: (1) ใช้ค่า WYN-163 เป็นมาตรฐานทั้งเว็บ แทนค่าเดิมของ WYN-160 (2) เริ่ม batch **Home/Bottom Nav** ก่อน (ต่อลำดับเดิมของ WYN-160)

→ **AI Design**: ทำ batch 1 (Home/Bottom Nav) — audit CSS จริงของหน้า Home/Nav (เทียบ cascade เต็มเหมือนที่ WYN-175 ทำ ไม่ใช่แค่ rule แรกที่เจอ), แยกให้ชัดว่าจุดไหนเป็น Bottom Nav (แก้ได้) vs การ์ดโพสต์ที่ล็อก Flutter parity (ห้ามแตะ), ทำภาพก่อน-หลังด้วย token ใหม่จาก WYN-163 (ปุ่ม 24px/58px/16px-700, input 18px/56px, หัวข้อ 32px/800, press scale 0.96) ให้ Founder อนุมัติก่อนส่ง AI Coding
