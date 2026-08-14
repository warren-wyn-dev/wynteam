import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      // Blue + White + Soft Gray -- Founder's Color Direction for WYN V0.1
      // (see .wyn/company/DECISIONS.md 2026-08-14), replacing the old
      // proposed purple/pink seed. See .wyn/docs/design/design-principles.md.
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D6CDF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D6CDF),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
