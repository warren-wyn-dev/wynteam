/// Compile-time Firebase Web configuration, read the same way
/// [Env] reads Supabase's -- `--dart-define`, never a checked-in file.
///
/// Beta4 §11.2 (Web Push). On Android and iOS, `Firebase.initializeApp()`
/// finds its configuration in the native `google-services.json` /
/// `GoogleService-Info.plist` the Founder drops into the platform
/// folders. **The web has no such file**: a Flutter Web build must pass
/// [FirebaseOptions] explicitly or `initializeApp()` throws, which is
/// why -- before Beta4 -- Web Push in WYNOS was not "partly wired", it
/// was structurally impossible: `main.dart` called
/// `Firebase.initializeApp()` with no options inside a `try/catch`, so
/// on web it threw every single launch, `Firebase.apps` stayed empty,
/// and every `PushNotificationService` method took its no-op path.
/// (`web/` had no `firebase-messaging-sw.js` either, so even a
/// successful init would have had nowhere to deliver a background
/// message.)
///
/// These six values are **not secrets**. A Firebase Web config is
/// public by design -- it ships inside every web bundle that uses it,
/// and Google's own docs say so. They live behind `--dart-define`
/// anyway, for the same two reasons `Env` does: the repository stays
/// free of environment-specific values, and an unconfigured build
/// (every CI run, every `flutter test`) gets empty strings and
/// therefore [isConfigured] == false, so nothing here can half-start.
///
/// `vapidKey` is separate from the other five: it is the public half of
/// the Web Push VAPID key pair (Firebase Console → Project Settings →
/// Cloud Messaging → Web Push certificates). `getToken()` on web will
/// not return a token without it. The *private* half never leaves the
/// Firebase Console and is never needed by this app.
class PushEnv {
  const PushEnv._();

  static const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// Public Web Push (VAPID) key. Web-only; ignored on Android/iOS.
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  /// Whether this build carries enough configuration for
  /// `Firebase.initializeApp()` on web to succeed.
  ///
  /// Only the four values Firebase actually requires are checked --
  /// `authDomain`/`storageBucket` are optional for Cloud Messaging, and
  /// demanding them would turn a working push setup into a silent
  /// no-op over two values it never reads.
  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  /// Whether a web build can actually obtain a push token. Web Push
  /// needs the VAPID key on top of [isConfigured]; without it
  /// `getToken()` fails rather than returning null, so this is checked
  /// before asking for one at all.
  static bool get isWebPushConfigured => isConfigured && vapidKey.isNotEmpty;
}
