# WYN-189 — WYNOS Web: Thai / English (Web Beta2)

Status: implemented; released to every account once its PR is green on staging and merged (Founder approval 2026-09-27: "จัดการให้เสร็จทั้ง2งานเลย อนุมัติทุกอย่าง พร้อมขึ้นเว็บ").
Spec: `.wyn/docs/product/wyn-188-189-web-theme-and-language.md`
Priority: P1.
Summary: Settings → Language (ไทย / English). The first visit follows the device language: English for `en-*`, Thai for every other language. The choice is saved per account (`user_preferences.language_preference`, which is already live, so no new SQL) and cached on the device. All UI text, dates and Push are translated; user content never is.

## Implementation (technical decision)

- **Client-side translation of the Thai-authored UI** (`web/lib/i18n/translator.ts`) replaces wrapping about 2,000 call sites. Every page stays written in Thai, and many source-contract tests assert that Thai. In English, every text node and every `placeholder`/`aria-label`/`title`/`alt` whose whole text is a known UI string is swapped. The original is remembered, so switching back to Thai restores it exactly. A MutationObserver covers later renders. `alert`/`confirm`/`prompt` texts are translated as well.
- Dictionary: `web/lib/i18n/en.ts`, with 948 exact strings and 67 templates (`{0}` values). Thai dates such as `26 ก.ย.` and `26 กันยายน 2569` become English dates.
- **Coverage guard:** `npm run test:i18n`, which CI runs, fails when any Thai UI string in `app/`, `components/` or `lib/` has no English entry. New Thai text must add its English line.
- User content is never translated. Only exact UI strings match, and every element that renders people's words (post and comment text, chat and Club messages, names, bios, Club descriptions, events) carries `data-i18n-skip`. Textarea contents are skipped too, but their placeholders are translated.
- No flash: `LANGUAGE_BOOT_SCRIPT` hides the page before first paint for English until the translator runs, with a 6 s safety timer. Nodes React has not hydrated yet (streamed Suspense) wait until they are hydrated, so there are no hydration errors.
- Push: `send-push-notification` reads the recipient's `language_preference` and sends English templates for `en`. With no row, or on a read failure, it sends Thai, as before.
- Browser QA runs with `locale: th-TH`. `tests/browser/language.spec.ts` covers English-phone first visit, saved choice, live switching, post text left unchanged, and clean hydration.

## Not translated (by design)

- User content: posts, comments, messages, names, Club names and descriptions.
- Legal documents (Terms, Privacy) stored in `platform_documents` exist in Thai only. In English, Settings shows "This document is currently available in Thai only." English legal text needs Founder/legal-approved content.
- Server-rendered share-preview metadata (Open Graph) for link previews in other apps. The preview is fetched by LINE/Facebook/X crawlers, not by the person, so no viewer language is known; it stays Thai. The spec lists link-preview titles, so this needs Founder sign-off (or an English/bilingual preview decision). The browser tab title is translated.
- System announcements (`system` notifications) are admin-written text sent to everyone as written; like user content they are not translated. Bilingual announcements would need an admin/schema change (Founder decision).
- Developer-only pages (`/dev`, WYNOS Food preview).
