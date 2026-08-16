import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/design/wyn_theme.dart';
import 'core/env.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const WynApp());
}

class WynApp extends StatelessWidget {
  const WynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WYN',
      debugShowCheckedModeBanner: false,
      // WYN Design System (Cyan/Orange, Option B) -- see
      // .wyn/docs/design/ds-001-color-system.md and
      // .wyn/company/DECISIONS.md 2026-08-15 ("เปลี่ยน Color Direction
      // ของ WYN: Blue → Cyan"), replacing the earlier Blue + White + Soft
      // Gray direction (2026-08-14).
      theme: WynTheme.light,
      darkTheme: WynTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
