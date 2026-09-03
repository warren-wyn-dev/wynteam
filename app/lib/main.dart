import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/design/wyn_colors.dart';
import 'core/design/wyn_theme.dart';
import 'core/env.dart';
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
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Intentionally silent -- see comment above.
  }

  runApp(const WynApp());
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
