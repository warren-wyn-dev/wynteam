# Product Spec — WYN-188 Theme (Light/Dark/System) · WYN-189 Thai/English — WYNOS Web Beta2

Status: **draft for Founder approval** (2026-09-26)
Source: Founder request (2026-09-26): "อยากให้ระบบ รองรับ 2ภาษา คือ ไทย กับ อังกฤษ แล้วก็โหมด ธีมเข้ม สว่าง เลือกปรับได้ หรือจะปรับตามระบบโทรศัพท์ก็ได้"
Founder scope decisions (AskUserQuestion, 2026-09-26):
- **Web first** (wynos.online, Web Beta2). The Flutter app is a separate, later task.
- First-time language **follows the phone/browser language** (English device → English, anything else → Thai).
- Choices are **saved per account** (and cached on the device so the page never flashes the wrong theme or language).
- Release order: **theme first, then language** in page groups. Everything is **developer-only** (`is_developer_account()`) until the Founder says to release.

Related: WYN-105 (Flutter 3-theme spec, not built). This spec is web-only and does not change WYN-105.

---

## Current state (code checked 2026-09-26)

- **Theme:** `web/app/globals.css` already has dark tokens under `@media (prefers-color-scheme: dark)`, derived from the Flutter golden palette (DECISIONS.md 2026-09-16). Only about 5 of roughly 60 stylesheets define dark values, so many pages are partly dark or still light. Settings shows a "ธีมเข้ม" row (`components/settings-route.tsx`) that **does nothing**.
- **Language:** no i18n at all. About **2,000 hard-coded Thai strings in 113 files** (`app/`, `components/`, `lib/`). Dates, relative times ("5 นาทีที่แล้ว") and numbers are formatted in Thai. Push notification text is built in Thai by `supabase/functions/send-push-notification`.

---

## WYN-188 — Theme: Light / Dark / System (Phase 1)

Goal: users choose how WYNOS looks, and every screen looks correct in both themes.

### Requirements
1. **Settings → "ธีม" / "Theme"** replaces the dead "ธีมเข้ม" row. It opens a picker with 3 options and a check mark:
   - **ตามระบบ / System** (default): follows the phone's light or dark setting and switches live when the phone switches.
   - **สว่าง / Light**
   - **เข้ม / Dark**
2. The change applies **instantly** to the whole app, with no reload.
3. **No flash:** the correct theme is applied before first paint, including on reload, deep links, installed PWA launch and the signed-out Welcome, Login and Signup screens.
4. **Saved per account:** stored on the profile and restored after login on any device. It is also cached on the device and used before login and while offline. On logout, the device keeps the last choice.
5. **Complete coverage:** every page, sheet, dialog, menu, toast, skeleton, empty/error state, composer, chat, notifications, profile, clubs, settings and auth screen is readable in both themes. This includes icons, borders, dividers, inputs, focus rings and image placeholders. Rainbow accents keep their brand colors. Text contrast meets **WCAG AA**.
6. The browser/PWA **status bar and theme-color** match the chosen theme.
7. **Developer-only until release:** non-developer accounts keep today's behavior and do not see the new setting.

### Acceptance criteria
- Choosing Light, Dark or System in Settings changes the whole app immediately. The choice survives reload, logout/login and a second device.
- With System selected, switching the phone between light and dark updates the open app without a reload.
- There is no light→dark (or dark→light) flash on cold load, deep link or PWA launch, in both themes.
- An automated check renders every main route in light and dark and fails on unreadable contrast, e.g. white text on a white background.
- A non-developer account sees no change.

### Data
- `profiles.theme_preference text not null default 'system' check (theme_preference in ('system','light','dark'))`. The owner updates it through the existing profile update path. **This is a production migration and needs separate Founder approval.** It is additive and has a safe default.

---

## WYN-189 — Thai / English (Phase 2, released in page groups)

Goal: English-speaking users can use WYNOS fully in English. Thai stays the primary language.

### Requirements
1. **Settings → "ภาษา" / "Language":** ไทย or English. It applies instantly, with no reload.
2. **First visit:** the language follows the browser or phone language. If it is English (`en-*`), show English; otherwise show Thai. Once the user picks a language, the pick always wins.
3. **Saved per account:** stored on the profile, restored after login, and cached on the device (same pattern as theme). `<html lang>` is updated to match.
4. **All UI text is translated:** buttons, labels, placeholders, errors, toasts, empty states, dialogs, auth and signup, settings, accessibility labels (`aria-label`), page titles and link-preview titles. **User content is never translated:** posts, comments, names, bios and chat messages.
5. **Dates, times, relative times** ("5 minutes ago") and numbers follow the chosen language.
6. **Push notifications** arrive in the recipient's saved language. This needs a change to the `send-push-notification` Edge Function.
7. **Released in page groups**, each behind the developer gate until the Founder releases it:
   1. Auth, signup and settings
   2. Home feed, post detail and composer
   3. Profile and search
   4. Notifications and chat
   5. Clubs and the rest
8. A missing English string falls back to Thai, never to a raw key. A check fails CI if an English string is missing for a released group.

### Acceptance criteria
- A developer account set to English sees no Thai UI text on any released page. User content stays as written.
- An English-language browser opening wynos.online for the first time sees English. After switching to Thai, the choice sticks across reload and devices.
- Dates, relative times and Push notifications appear in the chosen language.
- Automated tests pass in both languages. Layouts do not overflow with longer English text on a 360 px wide phone.

### Data
- `profiles.language_preference text null check (language_preference in ('th','en'))`. `null` means "not chosen yet, follow the device". This is a production migration and needs separate Founder approval.

---

## Out of scope (for now)
- The Flutter app (a separate task after the web is done).
- Languages other than Thai and English.
- Translating user-generated content.
- The extra "off-white / pure-white" themes from WYN-105.

## Dependencies
- Staging per PR (PR #732) is used to check every group before merge.
- Developer gate: `web/lib/use-is-developer-account.ts` and `public.is_developer_account()`.
- Founder approval for the two additive `profiles` migrations.
- Design (UI/UX): the dark palette for all tokens (from the existing Flutter dark palette), picker UI, and English copy tone.

## Priority
- WYN-188 Theme: **P1**, first, smaller.
- WYN-189 Language: **P1**, large, released in 5 groups.

## Risks
- **Size:** about 2,000 strings. Translation quality and layout overflow need review page by page. The Founder or a fluent reviewer should approve the English copy for each group.
- **Regressions:** moving every Thai string into a dictionary touches almost every UI file. This is mitigated by per-group PRs, staging, and existing browser tests running in both languages.
- **Dark-mode gaps:** the current CSS is spread over about 60 files, so each needs dark values. Contrast checks guard this.
- **Push in English** depends on the Edge Function reading the recipient's language.

## Recommendation
Approve this spec. Build WYN-188 first, with Design and then Coding. Then build WYN-189 group by group, all developer-only until the Founder releases each.

## Handoff
Founder approval → UI/UX (dark tokens, picker, English copy) → Architect (i18n approach: a small built-in dictionary with a React provider and no new heavy dependency unless justified; theme via a `data-theme` attribute plus a pre-paint script) → Database (2 migrations, Founder-applied or Founder-approved) → Full-Stack → QA (both themes and both languages) → staging → Founder release.
