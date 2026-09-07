import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../data/club_insights.dart';
import '../../data/club_repository.dart';
import '../../../../core/design/wyn_spacing.dart';

/// WYN-117 — Insights tab, the 4th tab on `ClubPage`, visible only to an
/// Owner/Admin (see `ClubPage`'s own `myRole?.canManageClub` gate on
/// both the `Tab` entry and this widget -- a Moderator/Member never
/// even sees the tab exists, and `public.club_insights()` itself
/// independently rejects the RPC call for anyone else regardless).
///
/// Deliberately no charts/export in V1, per the Product spec's own
/// anti-over-engineering note -- 4 plain numbers plus a 7/30-day
/// toggle.
class ClubInsightsTab extends StatefulWidget {
  const ClubInsightsTab({
    super.key,
    required this.clubRepository,
    required this.club,
  });

  final ClubRepository clubRepository;
  final Club club;

  @override
  State<ClubInsightsTab> createState() => _ClubInsightsTabState();
}

class _ClubInsightsTabState extends State<ClubInsightsTab> {
  int _days = 7;
  late Future<ClubInsights> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ClubInsights> _load() {
    return widget.clubRepository.fetchClubInsights(
      clubId: widget.club.id,
      days: _days,
    );
  }

  void _selectDays(int days) {
    if (days == _days) return;
    setState(() {
      _days = days;
      _future = _load();
    });
  }

  // Errors are swallowed here (not rethrown) -- the FutureBuilder below
  // reads the same `_future` and already renders its own error state
  // with a "ลองใหม่" retry, so a pull-to-refresh failure doesn't also
  // need to surface as an unhandled RefreshIndicator error.
  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // CustomScrollView (not ListView) -- a "primary" (no explicit
    // controller) scrollable either way, so this behaves exactly like
    // the ListView it replaces when ClubPage renders its own legacy
    // Column-based layout (no ambient PrimaryScrollController to bind
    // to), but also correctly participates in ClubPage's staged-rollout
    // NestedScrollView layout's shared/coordinated scroll position --
    // the header-collapse mechanism only works when every tab body is a
    // sliver-based scrollable like this one, same shape
    // ProfileDropGridTab (WYN-110) already uses for the identical reason.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        // Required for RefreshIndicator to be draggable at all when this
        // tab's content (the loading/error states especially) is
        // shorter than the viewport -- same reasoning as
        // club_posts_tab.dart's identical fix.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(WynSpacing.space4),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 วัน')),
                      ButtonSegment(value: 30, label: Text('30 วัน')),
                    ],
                    selected: {_days},
                    onSelectionChanged: (selection) => _selectDays(selection.first),
                  ),
                ),
                const SizedBox(height: WynSpacing.space5),
                FutureBuilder<ClubInsights>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: WynSpacing.space8),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('โหลดข้อมูลไม่สำเร็จ'),
                              const SizedBox(height: WynSpacing.space3),
                              TextButton(
                                onPressed: () => setState(() => _future = _load()),
                                child: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: WynSpacing.space8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final insights = snapshot.data!;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: WynSpacing.space3,
                      crossAxisSpacing: WynSpacing.space3,
                      childAspectRatio: 1.4,
                      children: [
                        _StatTile(label: 'สมาชิกใหม่', value: insights.newMembers),
                        _StatTile(label: 'โพสต์ใหม่', value: insights.newPosts),
                        _StatTile(
                            label: 'Like/Comment รวม', value: insights.likesAndComments),
                        _StatTile(label: 'สมาชิก Active', value: insights.activeMembers),
                      ],
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WynSpacing.space3),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: WynSpacing.space1),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
