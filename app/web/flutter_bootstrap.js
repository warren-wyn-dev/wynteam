// Custom bootstrap for the GitHub Pages preview deploy.
//
// The default generated bootstrap registers a service worker that caches
// main.dart.js/assets aggressively client-side. That's the right call for
// an installable PWA, but it's actively harmful for this use case: it's an
// internal preview site the Founder re-checks after every push, and the
// service worker's own update dance (new SW installs in the background,
// only takes over after a *second* reload) makes every redeploy look like
// it silently failed unless the tab is force-reloaded or reopened in
// Private Browsing. Omitting `serviceWorker`/`serviceWorkerSettings` here
// skips that registration entirely, so the browser falls back to plain
// HTTP caching -- a normal reload always sees the latest deploy.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
