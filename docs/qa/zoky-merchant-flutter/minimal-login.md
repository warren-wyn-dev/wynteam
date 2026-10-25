# Minimal ZOKY Merchant login — 2026-10-24

Founder selected a simple white Merchant login reference and requested a working view. The login now uses the official logo, one concise heading, email/password fields, a gray forgot-password link, a solid ZOKY pink action and an understated registration link. Remove login card borders/shadows, hero store icon, background glow and lengthy explanatory copy. Keep a short existing-account note.

Scope: login presentation and translations only. A login modifier scopes the flat layout; signup/application pages retain their existing layout. Email/password authentication, existing session/return-path logic, loading/errors, password visibility and navigation remain unchanged. Hidden input labels preserve accessible names. No unsupported phone/OTP/language controls are added.

Validation: lint and TypeScript passed; i18n/account suite46/46 passed. Chromium mobile/desktop public-auth interactions2/2 passed (email/password, visibility toggle, enabled action, signup navigation). Signed-out/login screenshot and official PNG/color/focus checks2/2 passed. No real credentials or database writes used. Production unchanged.

Screenshots: [mobile](minimal-login/mobile.png), [desktop](minimal-login/desktop.png).
