import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C4DFF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C4DFF),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
