import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../hashtag/presentation/hashtag_feed_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../data/discovery_ranking.dart';
import '../data/discovery_repository.dart';
import 'widgets/hashtag_rank_row.dart';

/// "ดูอันดับทั้งหมด (Top 100)" -- the full ranked hashtag list
/// `DiscoveryView`'s own preview links out to. Redefined 2026-08-29
/// (Founder-approved `03-search.tsx` re-brand -- see
/// .wyn/company/DECISIONS.md) from WYN-042's original *content*
/// leaderboard (Drop/Pop ranked by engagement) to a *hashtag* leaderboard,
/// matching the reference's own "Top 100, redesigned after the X
/// (Twitter) 'กำลังได้รับความนิยม' reference" direction. Same
/// [HashtagRankRow] as the preview, just [DiscoveryRepository.
/// top100FullLimit] deep instead of [DiscoveryRepository.
/// top100PreviewLimit].
class Top100Screen extends StatefulWidget {
  const Top100Screen({
    super.key,
    required this.discoveryRepository,
    required this.dropRepository,
    required this.clubPostRepository,
    required this.clubRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final DiscoveryRepository discoveryRepository;
  final DropRepository dropRepository;
  final ClubPostRepository clubPostRepository;
  final ClubRepository clubRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<Top100Screen> createState() => _Top100ScreenState();
}

class _Top100ScreenState extends State<Top100Screen> {
  List<RankedHashtag>? _items;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _hasError = false;
      _items = null;
    });
    try {
      final items = await widget.discoveryRepository.fetchTrendingHashtags(
        limit: DiscoveryRepository.top100FullLimit,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _openHashtagFeed(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagFeedScreen(
          tag: tag,
          dropRepository: widget.dropRepository,
          clubPostRepository: widget.clubPostRepository,
          clubRepository: widget.clubRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Top 100', style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลด Top 100 ไม่สำเร็จ'),
                  const SizedBox(height: WynSpacing.space3),
                  TextButton(onPressed: _load, child: const Text('ลองใหม่')),
                ],
              ),
            )
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const Center(
                      child: Text('ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) => HashtagRankRow(
                          rank: index + 1,
                          item: items[index],
                          showDivider: index < items.length - 1,
                          onTap: () => _openHashtagFeed(items[index].tag),
                        ),
                      ),
                    ),
    );
  }
}
