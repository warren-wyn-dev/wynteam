# WYNOS Web Beta 1 — Phase 2 chat continuity QA

Scope: reuse existing Realtime chat and post-draft autosave. This incremental phase does not change table schemas, chat permissions, message delivery, or the PWA worker.

- Conversation text drafts live in same-tab `sessionStorage`, keyed by authenticated user and conversation (new-message drafts are additionally scoped by recipient), and expire after 24 hours. Files and message tokens are never stored.
- Text is retained while send is in progress, removed only after server send succeeds, restored after a failed send. Session logout clears that user's temporary chat text drafts.
- Chat inbox and opened conversations revalidate on browser reconnect and when returning to a visible tab. Hidden or offline tabs don't issue speculative network requests; the existing realtime subscriptions remain active while mounted.
- Run `npm run test:chat-resilience`, `npm run check` and browser QA. Verify a real device on weak network, a failed send/retry, refresh, account A to B isolation, image-attachment caveat (attachments are not restored), and background-to-foreground delivery before release.
- WYNOS Web Beta1 production remains unchanged until the Phase 1 release has passed physical-device QA and the Founder authorizes its release. No message should be created by merely opening `/chat/new`.
