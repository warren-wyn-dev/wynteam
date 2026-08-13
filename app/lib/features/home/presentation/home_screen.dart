import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';

/// Placeholder Home screen — the real Feed is out of scope for WYN-002/
/// WYN-003 and will be designed/implemented as its own feature.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WYN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'โปรไฟล์ของฉัน',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ViewProfileScreen(
                  profileRepository:
                      ProfileRepository(Supabase.instance.client),
                  userId: userId,
                ),
              ),
            ),
          ),
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
