# ZOKY app (Flutter: iOS + Android)

ZOKY is the rebrand of the WYNOS Food customer app (Founder decision
2026-10-17, `.wyn/company/DECISIONS.md`). This is a **new, separate** Flutter
project; it does not reuse code from `app/`.

Status: **ZOKY-104 scaffold (no CI, no signing, demo data only)**. Not
released, not deployed. Requires QA & Security review before any build is
distributed.

- PRD: `.wyn/tasks/backlog/ZOKY-100-zoky-customer-app.md`
- Feature parity (96 rows): `.wyn/docs/product/zoky-feature-parity.md`
- Design system: `.wyn/docs/design/zoky-design-system.md`, `design-reference/zoky/tokens.json`
- Architecture (ZOKY-103): `.wyn/docs/engineering/zoky-app-architecture.md`

## PENDING FOUNDER APPROVAL

| Item | Current placeholder | Notes |
|---|---|---|
| Bundle / application ID | Android `online.zoky.zoky_app`, iOS `online.zoky.zokyApp` (from `flutter create --org online.zoky`) | PRD Q6 proposes `online.zoky.app`. Must be final **before** the first App ID / Play listing; cannot change after release. |
| App icon / splash | Flutter defaults | Production icons need the master vector (design 2.6 A1-A10). |
| Apple / Google developer accounts, Codemagic | none | Cost approval (PRD Q5). |

## Run

Demo mode (no backend; synthetic Thai sample stores):

```bash
/opt/flutter/bin/flutter run -d chrome
```

With real config (ZOKY-105+, once Supabase repositories exist):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=PUBLISHABLE_OR_ANON_KEY \
  --dart-define=ZOKY_DEMO_MODE=false
```

Only the publishable/anon key may be passed. Never a service-role key, never
an `.env` file in assets.

## Checks

```bash
/opt/flutter/bin/flutter analyze
/opt/flutter/bin/flutter test
/opt/flutter/bin/flutter build web --release   # internal iPad preview only
```

The web build exists only so the Founder can preview on an iPad (where it
renders the iOS/Cupertino variant). It is not the ZOKY website (that stays
Next.js in `web/`). Note: Flutter web loads its CanvasKit renderer from
Google's CDN by default; host the preview internally only.

## Assets and licenses

- `assets/images/zoky_logo.png`: in-app logo (brighter, no-shadow version
  the Founder chose), a 512px PNG rendered from
  `design-reference/zoky/zoky-app-icon-1024.png` masked to the rounded
  geometry of `design-reference/zoky/zoky-logo.svg`. Not a store icon.
- `assets/fonts/anuphan/`: Anuphan (Cadson Demak) variable font, unmodified,
  from github.com/google/fonts `ofl/anuphan`, with its SIL OFL 1.1 `OFL.txt`
  (registered in `LicenseRegistry`, visible from บัญชี > สัญญาอนุญาตโอเพนซอร์ส).
  Design Q9 asks QA to confirm the license before store submission.
