# WYNOS Web Beta 1 — Thai / English localization

Status: **source package prepared, not applied to this repository, not ready for production**. This file is a release handoff, not proof of deployment.

## Verified local package
- Archive: `wynos-i18n-release-source.zip`, SHA-256 `0625eabcabe823e4e25824d68f501409d3eae22c617a89a1105f57e4d2116806`.
- Includes curated interface translation pairs, contextual templates, language provider, Settings selector, scoped TSX codemod, static PWA and root-error localization, and fail-closed release-gate tests.
- Isolated localization unit tests: 21 passed, 0 failed. This does **not** mean full project tests passed.

## Apply in this dedicated branch
Obtain the source ZIP from the Founder’s ChatGPT delivery, verify its SHA-256, and extract it at the repository root. The archive contains `web/i18n-dev/apply.py`, its required companion files, and draft branch CI workflows.

```bash
git switch feat/web-beta1-bilingual-i18n
unzip wynos-i18n-release-source.zip -d .
cd web && npm ci && cd ..
python3 web/i18n-dev/apply.py .
cd web
node --test tests/i18n.test.mjs tests/ui-literals.test.mjs tests/ui-dynamic.test.mjs tests/pwa-locale.test.mjs tests/i18n-release-check.test.mjs
npm run check
node scripts/i18n-release-check.mjs --automated-only
npm run qa:browser
```

## Release blockers
1. Apply the patch to the **complete** repository and inspect `web/docs/i18n-static-coverage.json`; untranslated UI literals and contextual templates must be resolved rather than ignored.
2. Pass full lint, typecheck, build, existing regression suites and authenticated mobile/desktop browser tests; inspect UX, accessibility and language persistence.
3. Obtain separate Thai/English human editorial review and English legal document versions where required.
4. Verify staging and production rollback. Keep user posts, usernames, Club names, DM messages and moderation reasons untranslated.
5. Deploy only after objective release gates pass. Founder approval has been granted, but that does not substitute for testing or infrastructure access.

Do not merge this branch while it contains only this handoff document. No production deployment or data migration was performed.
