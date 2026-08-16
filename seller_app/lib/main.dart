import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/design/wyn_zoky_theme.dart';
import 'core/env.dart';
import 'core/navigation/app_navigator.dart';
import 'features/auth/presentation/seller_auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  // WYN-016 (Push Notification): see app/main.dart's identical comment
  // -- throws until the Founder adds real config files, caught so the
  // app boots exactly as it did before this feature existed.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Intentionally silent -- see comment above.
  }

  runApp(const ZokySellerApp());
}

class ZokySellerApp extends StatelessWidget {
  const ZokySellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'ZOKY Sellers by WYN',
      debugShowCheckedModeBanner: false,
      // WYN Design System (Cyan/Orange, Option B) -- ZOKY sub-theme, see
      // .wyn/docs/design/ds-001-color-system.md (Section 3.4) and
      // .wyn/company/DECISIONS.md 2026-08-15 ("เปลี่ยน Color Direction
      // ของ WYN: Blue → Cyan"), replacing the earlier Blue + White + Soft
      // Gray seed color (2026-08-15).
      theme: ZokyTheme.light,
      darkTheme: ZokyTheme.dark,
      themeMode: ThemeMode.system,
      home: const SellerAuthGate(),
    );
  }
}
