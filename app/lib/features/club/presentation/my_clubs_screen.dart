import 'package:flutter/material.dart';

import '../data/club.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import 'club_page.dart';
import '../../../core/design/wyn_spacing.dart';

/// "Club ของฉัน" -- the full-list destination behind the Home CLUB
/// section's "ดูทั้งหมด" link (Screen 1). No pagination: ClubRepository.
/// fetchMyClubs already returns every club the user has joined in one
/// call (a user's own joined-club count is small), so a simple list is
/// enough without inventing a separate paginated endpoint.
class MyClubsScreen extends StatefulWidget {
  const MyClubsScreen({
    super.key,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<MyClubsScreen> createState() => _MyClubsScreenState();
}

class _MyClubsScreenState extends State<MyClubsScreen> {
  late Future<List<Club>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.clubRepository.fetchMyClubs();
  }

  void _reload() => setState(() => _loadFuture = widget.clubRepository.fetchMyClubs());

  void _openClub(Club club) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
          clubId: club.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Club ของฉัน')),
      body: FutureBuilder<List<Club>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลดรายชื่อ Club ไม่สำเร็จ'),
                  const SizedBox(height: WynSpacing.space3),
                  TextButton(onPressed: _reload, child: const Text('ลองใหม่')),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final clubs = snapshot.data!;
          if (clubs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: WynSpacing.space8),
                child: Text(
                  'ยังไม่ได้เข้าร่วม Club ไหนเลย ลองสร้างหรือค้นหาดูสิ',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage:
                      club.iconUrl != null ? NetworkImage(club.iconUrl!) : null,
                  child: club.iconUrl == null
                      ? Text(
                          club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                        )
                      : null,
                ),
                title: Text(club.name),
                subtitle: Text('${club.memberCount} สมาชิก'),
                onTap: () => _openClub(club),
              );
            },
          );
        },
      ),
    );
  }
}
