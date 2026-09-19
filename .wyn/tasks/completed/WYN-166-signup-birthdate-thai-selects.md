# Task — WYN-166: Signup Step 1 birth date → Thai วัน/เดือน/ปี selects

Status: approved (AI QA & Security ยืนยัน PASS แล้ว 2026-09-19 — ดูรายละเอียดที่ท้ายไฟล์)
Owner: AI Deploy & DevOps
Scope: `web/components/auth-flow/screens.tsx` (`SignupStep1Screen`, `parseBirthDate`), `web/app/auth-reference.css`, regression test

## Request

Founder: "ตอนเลือกวันเกิดได้ไหม อยากให้เลือกวันเกิดง่ายๆ มีแนะนำไหม" — the birth date field on Signup Step 1
was a hand-typed text field ("วว / ดด / ปปปป", auto-inserting slashes as digits are typed), error-prone to
fill correctly. Asked for a recommendation on making it easier.

Same day, follow-up: "วันเกิด ไม่เอา mm/dd/yyyy สิ เอาภาษาไทย" — after seeing the first implementation
(native `<input type="date">`), rejected it because the picker displayed in English ("mm/dd/yyyy").

## Decision

**Round 1**: AI offered 2 options — (1) native `<input type="date">`, OS-provided picker, minimal effort,
but its visual styling can't be customized; (2) a custom Apple-style wheel picker matching WYN-163's design
exactly, needing a full Design → Coding → QA pass. **Founder chose option 1**, implemented, verified working
— but superseded the same day by round 2 below before ever reaching QA.

**Round 2 (final)**: a native date input's displayed text follows the visiting browser/OS's own language
setting, not the page's `lang` — so it can show English on a device that isn't set to Thai, even though the
rest of the app is Thai. That's not something a page can force. To guarantee Thai text for every visitor
regardless of device settings, switched to **3 plain `<select>` boxes** (วัน / เดือน / ปี) with spelled-out
Thai month names. Asked the Founder one clarifying question — Buddhist Era (พ.ศ.) or Gregorian (ค.ศ.) for
the year dropdown's visible label — since Thai users near-universally think of their own birth year in พ.ศ.,
and guessing wrong on a real product-facing string was worth one question. **Founder chose พ.ศ.** Full
decision history: `.wyn/company/DECISIONS.md` (2026-09-19, WYN-166 and its follow-up entry).

## Implementation (final, round 2)

`web/components/auth-flow/screens.tsx`:
- Birth date field is now 3 `<select className="wyn-select">` elements in a flex row inside the existing
  `.field` box (`วัน` 1–31, `เดือน` spelled-out Thai month names, `ปี` Buddhist-era-labeled years) — no
  shared wrapper styling, each `<select>` fully owns its own visible box (border/radius/height/background),
  deliberately avoiding the nested double-box-model collision that caused WYN-165 (the wrapper `<div>` here
  is layout-only: `display:flex; gap:8px`, no border/height/padding of its own).
- `draft.birthDate` (the `SignupDraft` field everything else in the app already reads/writes) stays the
  single source of truth, still shaped as `"YYYY-MM-DD"` — but now also transiently holds incomplete
  joins like `"-05-"` or `"2000-05-"` while the user hasn't finished picking all 3 parts. `parseBirthDate`'s
  `\d{4}-\d{2}-\d{2}` format check already rejects any incomplete join as invalid, so this needs no special
  handling elsewhere — a half-filled selection simply behaves like "no valid date yet" everywhere it's read.
- The 3 selects' current values are derived directly from `draft.birthDate.split("-")` on every render — no
  separate local `useState` — so they stay correct after a route remount (e.g. "ย้อนกลับ" from step 2) and
  after `signup-draft-context`'s async sessionStorage-resume effect populates `draft.birthDate` post-mount,
  the same way the plain `username`/`displayName` inputs already behave (this was checked deliberately: an
  earlier draft of this change used local `useState` initialized once from `draft.birthDate` at mount, which
  would have silently shown blank selects after a full-page-reload resume, since `draft.birthDate` isn't
  synchronously available at mount — that draft was caught and reworked before implementation, not shipped).
- Year select's option `value` stays the Gregorian year (unchanged storage/validation format); only its
  visible label is `year + 543` (Buddhist era).
- `parseBirthDate`'s age/future-date validation logic is unchanged — same `MIN_ONBOARDING_AGE = 13` check.
  Added `eligibleBirthYears()`: the year dropdown itself only offers years where *some* birthday within that
  year would satisfy the minimum age (newest-eligible-year first, descending to 1900) — but a day/month
  later in the calendar than today within that newest eligible year is still genuinely underage, so
  `parseBirthDate`'s submit-time check remains load-bearing, not just defensive: it is reachable through
  entirely normal UI use, not only a bypass.
- Removed the round-1 native `<input type="date">` markup and its `maxOnboardingBirthDate()` helper
  (superseded, no longer referenced anywhere).

`web/app/auth-reference.css`: added `.auth-ref-viewport .field select.wyn-select` as its own dedicated rule
(border/radius/padding/height/background matching the other fields' visual weight) — deliberately not
folded into the existing `.field .wyn-input, .field textarea` rule, to keep this new class's regression
surface isolated to itself.

`web/tests/browser/auth-reference-flow.spec.ts`:
- Updated "signup step 1 state survives step 2 and the in-flow back button" to select from the 3 dropdowns
  instead of filling one text/date input.
- Replaced the round-1 native-date-picker test with "signup step 1 birth date is 3 Thai วัน/เดือน/ปี selects
  gated to the minimum onboarding age": asserts Thai month labels are present and contain no digits, asserts
  the year dropdown's newest option matches the expected Buddhist-era year, and asserts the December-31 /
  newest-eligible-year edge case (see above) is still correctly rejected by the age check on submit.

## Verification (AI Coding, before handoff)

- `npm run typecheck` / `npm run lint` / `npm run build` — all clean (0 errors, same 3 pre-existing
  unrelated warnings)
- Manual Playwright verification (`playwright-core` + `/opt/pw-browsers/chromium` against a live dev
  server — this sandbox's `@playwright/test`-managed browser binaries are still not installed, same
  pre-existing gap as WYN-163/164/165):
  - Screenshot at 390×844 (empty and filled): 3 clean squircle boxes, Thai placeholders ("วัน"/"เดือน"/"ปี")
    when empty, spelled-out Thai month + Buddhist-era year once filled (e.g. "15 พฤศจิกายน 2543")
  - Month option labels confirmed: all 12 Thai names present, no digits leak into any label text
  - Year option labels confirmed: first real option is the expected newest-eligible Buddhist-era year
    (`2556` on the 2026-09-19 run date, i.e. `2026 - 13 + 543`)
  - Box geometry re-checked at 320/360/390/430px — all 3 selects `56px` tall at every width, no overflow, no
    clipped border (re-checked specifically against the WYN-165 class of bug; this wrapper carries no box
    styling of its own, so the same collision cannot occur here)
  - Full flow: fill username/displayName + all 3 selects → "หน้าถัดไป" → lands on step 2 (confirms the
    picked date, converted to Gregorian ISO internally, passed the age check) → "ย้อนกลับ" → step 1 → all 5
    field values persisted correctly, including วัน/เดือน/ปี showing the same previously-picked date
  - Underage edge case (newest eligible year + December 31, still under 13 today) → stays on
    `/signup/step-1`, shows the existing "กรุณากรอกวันเกิดให้ถูกต้อง (อายุอย่างน้อย 13 ปี)" error — confirms
    the day/month-level age check still runs even though the year dropdown is pre-filtered
  - Both updated regression tests' exact assertions re-run by hand against the live app — all passed

## Files Changed

- `web/components/auth-flow/screens.tsx`
- `web/app/auth-reference.css`
- `web/tests/browser/auth-reference-flow.spec.ts`

## Regression Risk

Low — contained to `SignupStep1Screen`'s birth date field, its helper functions, and one new CSS rule scoped
to a new class name. `parseBirthDate`'s age/future-date validation logic is unchanged in effect.
`SignupStep2Screen` calls the same function with the same contract, so it needs no changes. No backend/RPC/
schema changes — `setDateOfBirth()` already expected a Gregorian ISO date string, still does.

## Handoff to QA

Ready for AI QA & Security: verify the 3 Thai selects on `/signup/step-1` at 320/360/390/430px (box
geometry, no WYN-165-style border clipping), all Thai text renders correctly with no English/digit leakage,
full step 1 → step 2 → back persistence, underage rejection (including the newest-eligible-year edge case),
and that the rest of WYN-163/164/165's scope is unaffected.

---

## QA Verification (2026-09-19, AI QA & Security)

**Independent re-test** on `claude/ux-ui-button-design-ult3lz` at commit `4c885033` — re-ran `typecheck`/
`lint`/`build` fresh (all clean), then adversarial functional testing against a live dev server with a fresh
Playwright script (`playwright-core` + `/opt/pw-browsers/chromium`, since the project's own
`@playwright/test` runner still can't launch in this sandbox — same pre-existing gap as every prior QA round
on this branch; the `browser-qa` CI check will run the actual `.spec.ts` file on the next PR).

**Functional / regression**:
- All 12 Thai month names present in the เดือน dropdown, zero digits leak into any month label
- ปี dropdown bounds correct: newest option `2556` BE (`= 2026 − 13 + 543`), oldest option `2443` BE
  (`= 1900 + 543`) — matches `eligibleBirthYears()`'s intended range exactly
- All 3 selects render at a consistent `56px` height at 320/360/390/430px, no overflow
- Full flow (fill 3 selects → "หน้าถัดไป" → step 2 → "ย้อนกลับ" → step 1) — all 5 fields persist correctly
- **sessionStorage resume simulated as a genuine fresh page load** (not just a client-side route
  transition): wrote a saved draft directly into `sessionStorage` then did a hard `page.reload()` — the 3
  selects correctly resumed the previously-saved date (`1995-06-20` → วัน=20, เดือน=06, ปี=1995). This
  specifically re-tests the hydration-timing concern the task file's Implementation section says was caught
  and rewritten before shipping (an earlier draft using local `useState` would have shown blank selects
  here) — confirmed the shipped version does NOT have that regression

**Edge cases / adversarial (trying to break it, not just confirm the happy path)**:
- Invalid calendar date (30 กุมภาพันธ์ 2543) → correctly rejected, stays on step 1, shows the existing
  "กรุณากรอกวันเกิดให้ถูกต้อง" error — `parseBirthDate`'s calendar round-trip check catches it even though
  the day dropdown doesn't adapt options to the selected month (by design, per the task file)
  - Confirms the flip side too: valid leap-year date (29 กุมภาพันธ์ 2543, 2000 being a leap year) →
    correctly **accepted**, advances to step 2 — the day-31-static-options design choice doesn't
    accidentally reject a valid Feb 29
- Newest-eligible-year + 31 ธันวาคม (still genuinely underage today) → correctly rejected — confirms the
  day/month-level age check is load-bearing, not just the year dropdown's pre-filtering, exactly as the
  Coding/Decision notes claimed
- **DOM-injected out-of-range value** (`day="99"`, injected via `page.evaluate` bypassing the actual
  `<option>` list, simulating a manipulated/malicious client) → still correctly rejected by `parseBirthDate`
  on submit, confirms the validation doesn't trust that only in-list values can ever reach it
- Confirmed server-side defense in depth exists independent of this change: `supabase/schema.sql` has
  `profile_private_date_of_birth_min_age` and `profile_private_date_of_birth_not_future` CHECK constraints
  on `profile_private.date_of_birth` — so even a fully client-bypassed submission (e.g. calling the Supabase
  client directly, skipping the UI/JS validation entirely) would still be rejected at the database layer.
  Pre-existing, unrelated to WYN-166, noted here as a positive finding, not a gap.

**Cross-cutting with WYN-165** (tested together since both changes are in the same field/screen):
- Username field box (WYN-165 fix) re-verified independently at 320/360/390/430/768px via
  `wrapper.clientHeight` vs. input height comparison (not just outer `boundingBox()`, which the original bug
  report already established doesn't catch this class of bug) — all pass
- Long username (40 chars) doesn't cause horizontal overflow of its wrapper box
- **Dark mode** (not explicitly re-checked by the Debug Engineer's own WYN-165 verification): both the
  username field border and the new วัน/เดือน/ปี selects render with correct light-on-dark contrast
  (`background: rgb(0,0,0)`, `color: rgb(255,255,255)`, visible gray border) — screenshot confirms all 3
  date-select boxes and the username box render as complete, uncut rounded rectangles in dark mode too
- Swept all 7 auth-flow screens (`/welcome`, `/signup/step-1`, `/signup/step-2`, `/onboarding/profile`,
  `/login`, `/forgot-password`, `/account/add`) for browser console errors — 0 errors on any screen,
  confirming WYN-163/164's scope is unaffected

**Security**: scanned the full diff for hardcoded secrets/keys/tokens/credentials — none found. No new
client-server trust boundary introduced (birth date was already client-collected and server-validated via
DB constraint before this change; this change only alters how the client collects it).

**Result: PASS.** No CRITICAL/HIGH/MEDIUM findings. Both WYN-165 and WYN-166 approved together — moving this
file to `.wyn/tasks/approved/` and handing off to **AI Deploy & DevOps**.

---

## Deployment (2026-09-19, AI Deploy & DevOps)

Merged via PR #546 by the Founder at 2026-09-19T08:52:07Z (merge commit `f841aabf`), which triggered
`wyn-158-production-deploy.yml` [run #133](https://github.com/warren-wyn-dev/wynteam/actions/runs/35433161442) —
**success** end-to-end (preflight, Vercel deploy, route verification). Full log:
`.wyn/logs/deployments/2026-09-19-wyn-165-166-username-border-birthdate-thai-selects-deploy.md`.

One CI check (`browser-qa`) failed on first run on an unrelated pre-existing test
(`reference buttons connect the auth routes`, webkit-iphone only) — investigated, confirmed a flake (passed
on re-run, passed on the prior PR before this change, and this PR's diff never touches the code path that
test exercises). Not a regression from this change.

**Still needed**: Founder to confirm on a real device that `wynos.online/signup/step-1` now shows (1) a
complete username field border, (2) 3 Thai วัน/เดือน/ปี dropdowns. This file moves to `.wyn/tasks/completed/`
only after that confirmation, per the standing WORKFLOW.md rule that deploy-workflow success alone isn't
sufficient.

## Founder Confirmation (2026-09-19)

Founder confirmed on real production ("เสร็จแล้ว") — moved to `.wyn/tasks/completed/`.
