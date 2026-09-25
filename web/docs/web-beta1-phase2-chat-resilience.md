# WYNOS Web Beta 1 — Phase 2 staged Chat resilience

Scope: enhance existing Supabase Realtime chat and private, server-saved post
Drafts; this is **not** a new chat backend, user-facing feature redesign or
an automatic production rollout.

## Included
- Chat inbox and active thread revalidate when returning from a background
  tab, regaining network or focusing the app. The handler coalesces multiple
  wake-up events over three seconds and removes event listeners on unmount.
  Supabase Realtime remains active; resume is an additional loss-recovery path.
- Keep each conversation's unsent **text** in a bounded in-memory, per-account
  composer cache while navigating within the tab. Never write private Chat
  text into localStorage, telemetry or a URL; files are intentionally not
  retained. Clear all transient text on sign-out or account identity change.
- A successful DM send clears its transient composer before navigation. A
  read-receipt RPC error cannot turn a successful send into a false failure or
  invite duplicate resends.
- Existing server-saved post Drafts continue via drop_drafts RLS and are not
  changed by this patch.

## QA before release
Run `npm run test:phase2`, the full Web and Browser QA, and physically
test iOS Home Screen and Android browser: send while switching tabs; return
from offline/reconnect to find missed messages; verify unread indicators and
that user B never sees account A's composer text. Confirm oversized/attachment
sends retain the existing error behavior and stale compose text is never shown
after sign-out. Backend delivery, realtime RLS and networking need real-device
integration tests to claim end-to-end completion.

Rollback requires the WYNOS Owner's explicit approval; stage independently
and do not deploy automatically.
