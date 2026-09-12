// Custom bootstrap for WYNOS Web.
//
// Flutter's default generated bootstrap registers flutter_service_worker.js,
// which aggressively caches the shell and main.dart.js. WYNOS no longer uses
// that app-shell worker because it can make a fresh production deploy look
// unchanged on an already-installed PWA. Firebase Messaging has its own
// firebase-messaging-sw.js and must remain registered for background push.
{{flutter_js}}
{{flutter_build_config}}

async function retireLegacyFlutterServiceWorker() {
  if (!('serviceWorker' in navigator)) return;

  try {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(
      registrations
        .filter((registration) => {
          const workers = [
            registration.installing,
            registration.waiting,
            registration.active,
          ].filter(Boolean);
          return workers.some((worker) =>
            worker.scriptURL.includes('/flutter_service_worker.js'),
          );
        })
        .map((registration) => registration.unregister()),
    );

    // Delete only the cache names used by Flutter's retired app-shell worker.
    // Do not clear unrelated browser caches or Firebase Messaging state.
    if ('caches' in window) {
      await Promise.all([
        'flutter-app-cache',
        'flutter-temp-cache',
        'flutter-app-manifest',
      ].map((name) => caches.delete(name)));
    }
  } catch (_) {
    // A cleanup failure must never block app startup. The deployed retirement
    // worker also removes old Flutter caches when an existing registration
    // checks for an update.
  }
}

retireLegacyFlutterServiceWorker().finally(() => {
  _flutter.loader.load();
});
