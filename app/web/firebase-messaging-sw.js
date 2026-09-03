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
// of the Flutter bundle and cannot read `--dart-define` values. So the
// config is read from the query string Firebase appends when the app
// registers the worker, which is how `PushEnv`'s single source of truth
// reaches this file without a second copy of the values living here.
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

const firebaseConfig = {
  apiKey: params.get('apiKey'),
  appId: params.get('appId'),
  messagingSenderId: params.get('messagingSenderId'),
  projectId: params.get('projectId'),
  authDomain: params.get('authDomain'),
  storageBucket: params.get('storageBucket'),
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
