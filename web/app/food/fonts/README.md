# Anuphan (ZOKY)

Self-hosted so the build never depends on Google Fonts (CI/deploy failed when the download was unreachable, 2026-11-13).

- Font: Anuphan, designed by Cadson Demak. Source: https://github.com/google/fonts/tree/main/ofl/anuphan (SIL Open Font License 1.1, see OFL.txt). Copyright 2019 The Anuphan Project Authors.
- File: `Anuphan-thai-latin.woff2` is the unmodified outlines of the official `Anuphan[wght].ttf`, limited to weights 400-700 and subset to Basic Latin, Latin-1, Thai, General Punctuation and a few symbols (fonttools instancer + pyftsubset, layout features kept, hinting removed). SHA-256 is pinned in `scripts/check-web-fonts.mjs`.
- Founder approved this single exception to the system-fonts policy (2026-11-14). Any other text font still fails the guard.
