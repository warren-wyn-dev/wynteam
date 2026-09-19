# Task — WYN-166: Signup Step 1 birth date → native date picker

Status: implemented (AI Coding) — waiting for AI QA & Security
Owner: AI QA & Security
Scope: `web/components/auth-flow/screens.tsx` (`SignupStep1Screen`, `parseBirthDate`), regression test

## Request

Founder: "ตอนเลือกวันเกิดได้ไหม อยากให้เลือกวันเกิดง่ายๆ มีแนะนำไหม" — the birth date field on Signup Step 1
was a hand-typed text field ("วว / ดด / ปปปป", auto-inserting slashes as digits are typed), error-prone to
fill correctly. Asked for a recommendation on making it easier.

## Decision

AI offered 2 options: (1) native `<input type="date">` — uses the OS's own date picker (iOS wheel / Android
calendar), minimal effort, but the picker's own visual styling can't be customized; (2) a custom Apple-style
wheel picker matching WYN-163's design language exactly, but needs a full Design → Coding → QA pass.
**Founder chose option 1.** Full decision recorded in `.wyn/company/DECISIONS.md` (2026-09-19, WYN-166).

## Implementation

`web/components/auth-flow/screens.tsx`:
- `SignupStep1Screen`'s birth date field: `<Input bare inputMode="numeric" placeholder="วว / ดด / ปปปป" onChange={updateBirthDate}>`
  → `<Input bare type="date" onChange={update("birthDate")} min="1900-01-01" max={maxOnboardingBirthDate()}>`.
  Dropped the dedicated `updateBirthDate` handler (formatting is no longer needed — native date inputs
  always hold a valid ISO value) in favor of the same generic `update(key)` handler every other field uses.
- Removed `formatBirthDateInput()` (the "auto-insert /" helper — no longer needed).
- `parseBirthDate(raw)`: was parsing an 8-digit "DDMMYYYY" string (from the old text field's stripped
  digits); now validates a native date input's `"YYYY-MM-DD"` value directly via regex + calendar
  round-trip check. Same age (`MIN_ONBOARDING_AGE = 13`) and not-in-the-future validation logic, unchanged.
- Added `maxOnboardingBirthDate()`: computes the latest birth date that satisfies the minimum age, passed as
  the input's `max` attribute so the OS picker itself doesn't offer an underage date. `min="1900-01-01"` caps
  how far back the picker scrolls. Both are supplementary UX — `parseBirthDate`'s own JS validation still
  runs on submit regardless, since `min`/`max` are not authoritative (older browsers may ignore them, and a
  value can be set programmatically past them).
- `SignupStep2Screen`'s existing `parseBirthDate(draft.birthDate)` call is unaffected — same function
  signature and return type (ISO string or null).

`web/tests/browser/auth-reference-flow.spec.ts`:
- Updated 2 existing assertions in "signup step 1 state survives step 2 and the in-flow back button" that
  filled/expected the old `"01 / 01 / 2000"` text format — now `"2000-01-01"`.
- Added a new test, "signup step 1 birth date is a native date picker gated to the minimum onboarding age":
  asserts `type="date"`, asserts the `max` attribute equals the computed 13-years-ago cutoff, and asserts
  that filling an underage date (10 years old) and submitting stays on step 1 with the existing age-error
  message visible.

## Verification (AI Coding, before handoff)

- `npm run typecheck` / `npm run lint` / `npm run build` — all clean (0 errors, same 3 pre-existing
  unrelated warnings)
- Manual Playwright verification (`playwright-core` + `/opt/pw-browsers/chromium` against a live dev
  server — this sandbox's `@playwright/test`-managed browser binaries are still not installed, same
  pre-existing gap as WYN-163/164/165):
  - Screenshot at 390×844: field renders as a complete, clean squircle box (`56px` height, `18px` radius),
    consistent with the other two fields — native calendar icon on the right, `mm/dd/yyyy` placeholder in
    this Chromium build's locale
  - `type="date"`, `min="1900-01-01"`, `max="2013-09-19"` (run date 2026-09-19 minus 13 years) — confirmed
    via `getAttribute`
  - Box geometry re-checked at 320/360/390/430px — `56px` tall at every width, no overflow, no clipped
    border (this is the same class of bug as WYN-165 — re-checked specifically to make sure this change
    doesn't reintroduce it; native date inputs have no extra wrapper here, unlike the WYN-165 username field)
  - Full flow: fill username/displayName/birthDate → "หน้าถัดไป" → lands on step 2 → "ย้อนกลับ" → step 1 →
    all 3 field values persisted correctly, including birthDate as `"2000-01-01"`
  - Underage (10 years old) fill + submit → stays on `/signup/step-1`, shows
    "กรุณากรอกวันเกิดให้ถูกต้อง (อายุอย่างน้อย 13 ปี)" — same error message as before, confirming
    `parseBirthDate`'s validation logic is unchanged in effect
  - New regression test's exact assertions re-run by hand against the live app (type/max attribute values,
    underage-submit-blocked behavior) — all passed
- The project's own Playwright test runner still can't execute in this sandbox (missing
  `chromium_headless_shell` binary) — needs a real CI/dev-machine run to execute the `.spec.ts` file itself;
  the `browser-qa` CI check on the next PR will do this.

## Files Changed

- `web/components/auth-flow/screens.tsx`
- `web/tests/browser/auth-reference-flow.spec.ts`

## Regression Risk

Low — contained to `SignupStep1Screen`'s birth date field and the `parseBirthDate`/`formatBirthDateInput`
helper functions. `parseBirthDate`'s age/future-date validation logic is unchanged (only its input format
changed, from 8-digit-string to ISO). `SignupStep2Screen` calls the same function with the same contract, so
it needs no changes. No backend/RPC/schema changes — `setDateOfBirth()` already expected an ISO date string.

## Handoff to QA

Ready for AI QA & Security: verify the native date field on `/signup/step-1` at 320/360/390/430px (box
geometry, no WYN-165-style border clipping), full step 1 → step 2 → back persistence, underage rejection,
and that the rest of WYN-163/164/165's scope is unaffected.
