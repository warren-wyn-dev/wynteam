import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../follow/data/follow_request_repository.dart';
import '../../../follow/presentation/widgets/follow_action_button.dart';
import '../../../search/data/discovery_repository.dart';
import '../../data/profile.dart';
import 'avatar_circle.dart';

Future<void> showSuggestedFollowSheet(
  BuildContext context, {
  required DiscoveryRepository discoveryRepository,
  required FollowRepository followRepository,
  required FollowRequestRepository followRequestRepository,
  required String excludeUserId,
  required VoidCallback onShowAll,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (sheetContext) => _SuggestedFollowSheet(
      discoveryRepository: discoveryRepository,
      followRepository: followRepository,
      followRequestRepository: followRequestRepository,
      excludeUserId: excludeUserId,
      onShowAll: onShowAll,
    ),
  );
}

class _SuggestedFollowSheet extends StatefulWidget {
  const _SuggestedFollowSheet({
    required this.discoveryRepository,
    required this.followRepository,
    required this.followRequestRepository,
    required this.excludeUserId,
    required this.onShowAll,
  });

  final DiscoveryRepository discoveryRepository;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;
  final String excludeUserId;
  final VoidCallback onShowAll;

  @override
  State<_SuggestedFollowSheet> createState() => _SuggestedFollowSheetState();
}

class _SuggestedFollowSheetState extends State<_SuggestedFollowSheet> {
  List<Profile>? _profiles;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _failed = false;
        _profiles = null;
      });
    }
    try {
      final profiles = await widget.discoveryRepository.fetchSuggestedUsers();
      if (!mounted) return;
      setState(() {
        _profiles = profiles
            .where((profile) => profile.id != widget.excludeUserId)
            .take(5)
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _showAll() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onShowAll());
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.66;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: WynColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: WynColors.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BrowserSystemText(
                            'แนะนำสำหรับคุณ',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: WynColors.ink,
                            ),
                          ),
                          SizedBox(height: 5),
                          BrowserSystemText(
                            'คนที่คุณอาจสนใจ',
                            style: TextStyle(
                              fontSize: 14,
                              color: WynColors.graphite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BrowserSystemTooltip(
                        message: 'ปิด',
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 28,
                            color: WynColors.ink,
                          ),
                        )),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
              const Divider(height: 1, color: WynColors.hairline),
              InkWell(
                onTap: _showAll,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 15, 16, 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: BrowserSystemText(
                          'ดูคำแนะนำทั้งหมด',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: WynColors.ink,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: WynColors.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrowserSystemText(
              'โหลดคำแนะนำไม่สำเร็จ',
              style: TextStyle(color: WynColors.graphite),
            ),
            const SizedBox(height: WynSpacing.space2),
            TextButton(
                onPressed: _load, child: const BrowserSystemText('ลองใหม่')),
          ],
        ),
      );
    }

    final profiles = _profiles;
    if (profiles == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profiles.isEmpty) {
      return const Center(
        child: BrowserSystemText(
          'ยังไม่มีคำแนะนำใหม่ในตอนนี้',
          style: TextStyle(color: WynColors.graphite),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      itemCount: profiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return Row(
          children: [
            AvatarCircle(
              imageUrl: profile.avatarUrl,
              fallbackText: profile.username,
              radius: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrowserSystemText(
                    profile.nameOrUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  BrowserSystemText(
                    '@${profile.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: WynColors.graphite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FollowActionButton(
              profile: profile,
              followRepository: widget.followRepository,
              followRequestRepository: widget.followRequestRepository,
              compact: true,
              filled: true,
            ),
          ],
        );
      },
    );
  }
}
