import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/data/home_feed_item.dart';
import '../../home/presentation/pop_single_clip_screen.dart';
import '../../home/presentation/widgets/trending_tile.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../data/discovery_repository.dart';

/// WYN-042 — "WYN Top 100": a weekly (7-day) leaderboard of Drop+Pop
/// content ranked by [engagementScore] (WYN-041), reached from
/// Discovery's "Trending Now" section (WYN-040). Deliberately a plain
/// vertical list, not a grid -- the rank number is the point of this
/// screen, and a grid would reduce it to a small corner badge. See
/// .wyn/docs/design/wyn-042-top-100.md.
class Top100Screen extends StatefulWidget {
  const Top100Screen({
    super.key,
    required this.discoveryRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
  });

  final DiscoveryRepository discoveryRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;

  @override
  State<Top100Screen> createState() => _Top100ScreenState();
}

class _Top100ScreenState extends State<Top100Screen> {
  List<HomeFeedItem>? _items;
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
      final items = await widget.discoveryRepository.fetchTopContent();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  Future<void> _openDrop(HomeFeedItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: item.toDrop(),
        ),
      ),
    );
  }

  Future<void> _openPop(HomeFeedItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: item.toPop(),
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: const Text('WYN Top 100')),
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
                      child: Text('ยังไม่มีเนื้อหาติด Top 100 ตอนนี้'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => _Top100Row(
                        rank: index + 1,
                        item: items[index],
                        onTap: () =>
                            items[index].contentType == HomeContentType.drop
                                ? _openDrop(items[index])
                                : _openPop(items[index]),
                      ),
                    ),
    );
  }
}

class _Top100Row extends StatelessWidget {
  const _Top100Row({
    required this.rank,
    required this.item,
    required this.onTap,
  });

  final int rank;
  final HomeFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPop = item.contentType == HomeContentType.pop;

    return Semantics(
      label: 'อันดับที่ $rank, ${item.authorNameOrUsername}, '
          'กดเพื่อดู${isPop ? "วิดีโอ" : "รูป"}',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '#$rank',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              TrendingTile(item: item, onTap: onTap, showRainbowRing: false),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Text(
                  item.authorNameOrUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
