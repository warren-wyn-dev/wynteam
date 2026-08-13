import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'widgets/avatar_circle.dart';

/// Screen 1 — View Profile (own).
/// See .wyn/docs/design/wyn-003-user-profile.md
class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({
    super.key,
    required this.profileRepository,
    required this.userId,
  });

  final ProfileRepository profileRepository;
  final String userId;

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<Profile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileRepository.fetchProfile(widget.userId);
  }

  void _reload() {
    setState(() {
      _profileFuture = widget.profileRepository.fetchProfile(widget.userId);
    });
  }

  Future<void> _openEdit(Profile profile) async {
    final updated = await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profileRepository: widget.profileRepository,
          profile: profile,
        ),
      ),
    );

    if (updated != null) {
      setState(() => _profileFuture = Future.value(updated));
    } else {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<Profile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลดโปรไฟล์ไม่สำเร็จ'),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _reload, child: const Text('ลองใหม่')),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data!;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  AvatarCircle(
                    imageUrl: profile.avatarUrl,
                    fallbackText: profile.username,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.nameOrUsername,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${profile.username}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(profile.bio!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => _openEdit(profile),
                    child: const Text('แก้ไขโปรไฟล์'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
