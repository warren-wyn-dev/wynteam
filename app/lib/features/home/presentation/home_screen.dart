import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Placeholder Home screen — the real Feed is out of scope for WYN-002
/// and will be designed/implemented as its own feature.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WYN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ยินดีต้อนรับสู่ WYN 🎉\n(Feed จะมาใน feature ถัดไป)',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
