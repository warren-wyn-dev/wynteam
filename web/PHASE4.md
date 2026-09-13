# Phase 4 QA checklist

Phase 4 validates UX/UI parity and browser stability before any production cutover.

- Mobile safe-area and viewport coverage: iPhone-size and Android-size.
- Desktop responsive layout and no unintended horizontal overflow.
- Internal Next.js navigation without full document reloads.
- Home, Search, Profile, Notifications, Chat, Settings and deep-link route smoke coverage.
- Browser-native system fonts only; no bundled Apple/SF Pro assets.
- Auth/RLS/storage/realtime behavior remains on the existing Supabase contracts.
- Automated browser QA does not replace physical iPhone confirmation.
