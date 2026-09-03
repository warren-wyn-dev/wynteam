import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/ad_env.dart';
import 'core/design/wyn_colors.dart';
import 'core/design/wyn_spacing.dart';
import 'core/design/wyn_theme.dart';
import 'core/env.dart';
import 'core/push_env.dart';
import 'core/navigation/app_navigator.dart';
import 'features/account_switcher/data/account_switcher_repository.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WYN-078 (Wynos V1.0.0 Beta2, item 5): without this, the OS draws its
  // own default status bar/nav bar scrim (often white or black depending
  // on platform/Android version) on top of the app instead of letting
  // WynColors.paper show through -- visible as a mismatched blank strip
  // at the top (and bottom, on Android) of every screen, since nothing
  // in this app ever called SystemChrome before. Dark icons/text because
  // paper (#FFFFFF, WYN-105) is a light background.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: WynColors.paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  // Multi-account switching: keeps whichever account is currently active
  // fresh in the on-device switcher every time its access/refresh token
  // auto-rotates, for the whole lifetime of the app -- see
  // AccountSwitcherRepository.startSyncingActiveSession's own doc
  // comment. A no-op until an account is first captured (AuthGate, once
  // it reaches RootShell), so this is safe to start unconditionally here
  // even before any user has signed in.
  AccountSwitcherRepository().startSyncingActiveSession(Supabase.instance.client);

  // WYN-016 (Push Notification): throws until the Founder adds real
  // `google-services.json`/`GoogleService-Info.plist` -- caught here so
  // the app boots exactly as it did before this feature existed.
  // PushNotificationService's own methods check Firebase.apps and no-op
  // the same way, so nothing downstream needs to know this failed.
  //
  // Beta4 §11.2: web takes the explicit-options path. A Flutter Web
  // build has no native config file to read, so the no-argument call
  // below threw on *every* web launch regardless of how well Firebase
  // was set up -- see PushEnv's doc comment. When the build carries no
  // `--dart-define` config either, this is skipped entirely and the
  // behaviour is exactly what it was before: Firebase.apps stays empty
  // and every push path no-ops.
  try {
    if (kIsWeb) {
      if (PushEnv.isConfigured) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: PushEnv.apiKey,
            appId: PushEnv.appId,
            messagingSenderId: PushEnv.messagingSenderId,
            projectId: PushEnv.projectId,
            authDomain: PushEnv.authDomain,
            storageBucket: PushEnv.storageBucket,
          ),
        );
      }
    } else {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Intentionally silent -- see comment above.
  }

  // WYN-106 (Native In-Feed Ads, Home feed "สำหรับคุณ") -- only attempted
  // once Founder supplies a real AdMob App ID + native ad unit id
  // (AdEnv.isConfigured); every other build (every CI run, every dev
  // machine today) skips this entirely, so HomeNativeAdCard's own
  // load-time isConfigured guard is backed up by never even
  // initializing the SDK in the first place. Same "wrap in try/catch,
  // no-op until real config lands" posture as Firebase.initializeApp()
  // above.
  if (AdEnv.isConfigured) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // Intentionally silent -- HomeNativeAdCard's own load already
      // treats a failed/absent ad the same as "no ad-slot at all".
    }
  }

  // A build-time exception used to paint Flutter's raw grey/red error
  // box straight into the user's screen -- a stack trace where a card or
  // a whole tab should be. This replaces it with something a person can
  // act on, in release only: in debug the standard box is far more
  // useful to whoever is looking at it, so it stays.
  //
  // Not a crash reporter, and not a substitute for one -- monitoring is
  // still unwired (see the audit's "Monitoring readiness"). This is the
  // last line of defence between a bug and the person holding the phone.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _AppErrorBox();
  }

  runApp(const WynApp());
}

/// What a widget that failed to build shows in release. Deliberately
/// tiny and self-contained: it may be rendered in a broken tree, at any
/// size, with no Material ancestor to inherit from.
class _AppErrorBox extends StatelessWidget {
  const _AppErrorBox();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: WynColors.paper,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(WynSpacing.space4),
          child: Text(
            'ส่วนนี้แสดงผลไม่สำเร็จ ลองรีเฟรชหรือกลับมาใหม่อีกครั้ง',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 13, color: WynColors.graphite),
          ),
        ),
      ),
    );
  }
}

class WynApp extends StatelessWidget {
  const WynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: 'WYNOS Beta',
      debugShowCheckedModeBanner: false,
      // WYN Design System (Cyan/Orange, Option B) -- see
      // .wyn/docs/design/ds-001-color-system.md and
      // .wyn/company/DECISIONS.md 2026-08-15 ("เปลี่ยน Color Direction
      // ของ WYN: Blue → Cyan"), replacing the earlier Blue + White + Soft
      // Gray direction (2026-08-14).
      //
      // WYN-071: forced to light always (not following system dark mode
      // anymore) per Founder decision 2026-08-24 -- see DECISIONS.md.
      // `darkTheme`/`WynTheme.dark` are kept, not deleted, so this can be
      // reverted by changing `themeMode` alone if the Founder decides
      // otherwise later.
      theme: WynTheme.light,
      darkTheme: WynTheme.dark,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}
