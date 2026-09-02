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

  // Block body, not `() => _loadFuture = ...` -- see
  // ViewProfileScreen._reload's identical fix/comment (WYN-081) for why
  // an arrow body here trips setState()'s "returned a Future" assertion.
  void _reload() => setState(() {
        _loadFuture = widget.clubRepository.fetchMyClubs();
      });

  // WYN-081 (Wynos V1.0.0 Beta2, item 16): RefreshIndicator needs an
  // awaitable Future to know when to stop spinning -- _reload() itself
  // is fire-and-forget (just triggers a setState), so this wraps it.
  Future<void> _onRefresh() async {
    final future = widget.clubRepository.fetchMyClubs();
    setState(() {
      _loadFuture = future;
    });
    // A failure still surfaces normally -- the FutureBuilder below reads
    // this same future and shows its existing error state/"ลองใหม่"
    // button. Swallowed here only so RefreshIndicator itself doesn't
    // propagate it as an unhandled async error.
    try {
      await future;
    } catch (_) {}
  }

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

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
              itemCount: clubs.length,
              itemBuilder: (context, index) {
                final club = clubs[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: club.iconUrl != null
                        ? NetworkImage(club.iconUrl!)
                        : null,
                    child: club.iconUrl == null
                        ? Text(
                            club.name.isNotEmpty
                                ? club.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary),
                          )
                        : null,
                  ),
                  title: Text(club.name),
                  subtitle: Text('${club.memberCount} สมาชิก'),
                  onTap: () => _openClub(club),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
