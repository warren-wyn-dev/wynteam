# Deployment Log — Messages/Chat Redesign v2 (Notes removed)

**Release**: Founder-supplied static HTML/CSS mockup (`wynos-messages-web.zip`)
of both the messages list and the conversation screen — a second `/chat`
redesign pass, separate from the earlier same-day PR that reversed 3
WYN-170 decisions.

**Scope confirmed before implementing** (4 questions, since several mockup
elements implied features the app doesn't have):
1. Call/video buttons — omitted entirely (no WebRTC/signaling infra).
2. Notes feature (real, currently shipped) — removed completely, confirmed
   explicitly rather than silently dropped.
3. Typing indicator — skipped for this pass.
4. Accent color — kept WYNOS's existing red (`--wyn-accent`), did not adopt
   the mockup's green.

**Changes**:
- Notes feature removed completely from `chat-inbox-parity.tsx` (state,
  handlers, DB read/write, JSX) and `chat-notes.css`.
- Search moved from an always-visible bar to a header icon toggle.
- `chat-notes.css` rewritten as a single consolidated file, collapsing two
  superseding eras of rules for the same selectors that had caused
  confusion earlier the same day.
- Conversation bubbles: outgoing messages now fill with the accent color
  (was plain black), both sides get a real asymmetric "tail" corner — found
  and fixed a pre-existing bug where the corner-radius override matched the
  base rule and never actually did anything.
- Live online-status (green dot + "ออนไลน์" text) added to the conversation
  header, wired to the Presence channel built earlier the same day.

**Verification**: Throwaway visual fixture (not committed) confirmed accent
bubble color (`#e0203d`), asymmetric corners (6px), search toggle, and
online-status dot via the real dev server + computed styles. `npm run check`
PASS. Updated `system-visual-parity.spec.ts`'s stale Notes-era assertions.
Full `npx playwright test` across all 3 CI browser projects: 267/267 PASS.

**PR**: [#589](https://github.com/warren-wyn-dev/wynteam/pull/589)
(`claude/messages-redesign-v2` → `main`), merged by the Founder directly.

**Rollback Plan**: Standard PR revert — no migrations, no schema changes.

**Deployment Result**:
- `WYN-158 Production Deploy` run #175
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35629415937) —
  **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35629415940) —
  **success**.
- Deployed to `wynos.online`.
