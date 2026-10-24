# ZOKY Merchant auth palette — 2026-10-24

Founder explicitly requested the same shade family as ZOKY after the official logo integration. Align the existing Merchant login/signup/application shell with the live consumer/Flutter palette: action/link/focus `#d61256`, hover `#af1341`, soft pink `#ffeff5`, pink border `#f9c0de`, header glow `#f93384`, ink `#16161a` and secondary text `#6b6b76`. Official logo bytes remain unchanged (opaque source pink `#f21967`). The darker action shade keeps white button text readable. Loading indicators inherit the same auth accent. Error/success/status colors retain their semantic meaning.

Changes are scoped to `.wm-auth-shell`/auth selectors, preserving legacy Merchant and shared Food styling. No auth behavior, layout, backend or production change.

Chromium mobile/desktop login checks passed 2/2: actual official PNG load, primary button background, forgot-password link color and email focus border. Captures wait for entrance opacity to settle: [mobile](auth-palette/mobile.png), [desktop](auth-palette/desktop.png).
