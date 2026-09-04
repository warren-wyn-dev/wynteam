// WYNOS Web Push service worker (Beta4 §11.2).
//
// The browser half of Web Push. Firebase Messaging looks for this file
// at exactly this path -- `/firebase-messaging-sw.js`, at the origin
// root -- and registers it automatically when `getToken()` is called.
// The name and location are fixed by the SDK; do not rename or move it.
//
// Before Beta4 this file did not exist, which is why Web Push was not
// merely unconfigured but structurally impossible on web: with no
// service worker there is nowhere for a push to be delivered while the
// tab is closed or in the background, which is the only case that
// distinguishes a push notification from an in-app one.
//
// ---------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------
// A service worker is a static file served by the host -- it is NOT part
// of the Flutter bundle and cannot read `--dart-define` values. The
// values below are therefore substituted into this file at build time
// by .github/workflows/deploy-web.yml, from the same secrets it passes
// to `--dart-define`, so `PushEnv` stays the single source of truth and
// no environment value is committed here.
//
// This file previously read them from the query string, on the belief
// that Firebase appends the config when it registers the worker. It
// does not: the JS SDK registers `/firebase-messaging-sw.js` at a fixed
// path with no parameters. Nothing failed loudly -- a token was still
// issued, because the *page* creates the push subscription, and FCM and
// Apple both accepted and delivered every message. They arrived here,
// at a worker whose `initializeApp` guard had never passed, so
// `onBackgroundMessage` was never registered and nothing was ever
// shown. Every push WYNOS has sent to a browser died in this file.
//
// The query string is still read as a fallback, for a worker registered
// by hand with parameters during debugging; the baked values win.
//
// These are public values by design (a Firebase Web config ships in
// every web bundle that uses it, and Google documents it as such), so
// carrying them in a URL is not a disclosure. No secret ever reaches
// this file: the VAPID *private* key stays in the Firebase Console, and
// the FCM service account stays in the Edge Function's secrets.
//
// When the app is built with no Firebase config, `getToken()` is never
// called, so this worker is never registered and never runs.

/* eslint-env serviceworker */
/* global importScripts, firebase, clients */

importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
);

const params = new URL(self.location).searchParams;

// Replaced by the deploy workflow. A build that does not replace them
// leaves the placeholders, and `baked` reads those as absent -- which
// is correct: such a build has no Firebase config anywhere else either,
// so the guard below should fail and this worker should do nothing.
const BAKED = {
  apiKey: '__FIREBASE_WEB_API_KEY__',
  appId: '__FIREBASE_WEB_APP_ID__',
  messagingSenderId: '__FIREBASE_MESSAGING_SENDER_ID__',
  projectId: '__FIREBASE_PROJECT_ID__',
  authDomain: '__FIREBASE_AUTH_DOMAIN__',
  storageBucket: '__FIREBASE_STORAGE_BUCKET__',
};

const baked = (key) => {
  const value = BAKED[key];
  return value && !value.startsWith('__FIREBASE_') ? value : null;
};

const firebaseConfig = {
  apiKey: baked('apiKey') || params.get('apiKey'),
  appId: baked('appId') || params.get('appId'),
  messagingSenderId: baked('messagingSenderId') || params.get('messagingSenderId'),
  projectId: baked('projectId') || params.get('projectId'),
  authDomain: baked('authDomain') || params.get('authDomain'),
  storageBucket: baked('storageBucket') || params.get('storageBucket'),
};

// Guard: without the four required values there is nothing to
// initialize, and calling initializeApp with nulls throws inside the
// worker where nobody would ever see the error.
if (
  firebaseConfig.apiKey &&
  firebaseConfig.appId &&
  firebaseConfig.messagingSenderId &&
  firebaseConfig.projectId
) {
  firebase.initializeApp(firebaseConfig);

  const messaging = firebase.messaging();

  // Background delivery (tab closed, or another tab focused).
  //
  // Beta4 §11.6 (Duplicate Protection): `tag` is set to the
  // notification's own row id. A tag makes the browser *replace* any
  // notification already showing with the same tag rather than stacking
  // a second one -- so a webhook retry, a reconnect, or the same row
  // arriving twice shows one notification, not two. The id comes from
  // the `data` payload the Edge Function builds straight from the
  // `notifications` row (see supabase/functions/send-push-notification),
  // so it is stable per notification and unique across them.
  messaging.onBackgroundMessage((payload) => {
    const data = payload.data || {};
    const notification = payload.notification || {};
    self.registration.showNotification(notification.title || 'WYN', {
      body: notification.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: data.notification_id || undefined,
      data,
    });
  });
}

// Beta4 §11.3 (Deep Link): tapping a background notification focuses an
// already-open WYNOS tab where possible, rather than opening a second
// one -- a person with the app open in a tab expects that tab, and a
// duplicate tab loses whatever they were doing in the first.
//
// The in-app routing itself is deliberately NOT duplicated here. The
// destination for every notification type is decided in one place,
// `PushNotificationService._openFromPushData`, which the SDK invokes
// with this same `data` payload once the page has focus. Re-deriving
// URLs in JavaScript would be a second, silently-diverging copy of that
// switch -- and WYNOS has no URL routing to derive them into: it is a
// single-route Flutter app that navigates with `Navigator.push`.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        for (const client of windowClients) {
          if ('focus' in client) return client.focus();
        }
        if (clients.openWindow) return clients.openWindow('/');
        return undefined;
      }),
  );
});
