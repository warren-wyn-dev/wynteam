import 'package:flutter/material.dart';

import '../../data/club_channel_chat_repository.dart';
import '../../data/club_member.dart';
import '../../data/club_repository.dart';
import 'club_channel_chat_view.dart';

/// WYN-133 -- the dedicated, full-screen "room" a Club Chat channel opens
/// into when its row is tapped in the Channel List (`ClubChatTab`),
/// Discord-style: a real pushed route with its own `AppBar` and back
/// button, instead of swapping content under a chip bar that never left
/// the screen (see .wyn/docs/design/wyn-133-club-chat-channel-navigation.md
/// -- "Channel Room screen"). `ClubChannelChatView` (WYN-128) is reused
/// completely unchanged as this screen's body; this file only supplies
/// the AppBar chrome around it.
class ClubChannelScreen extends StatelessWidget {
  const ClubChannelScreen({
    super.key,
    required this.repository,
    required this.clubRepository,
    required this.clubId,
    required this.channelId,
    required this.channelName,
    required this.myRole,
    this.onManage,
    this.onBanned,
  });

  final ClubChannelChatRepository repository;
  final ClubRepository clubRepository;
  final String clubId;
  final String channelId;
  final String channelName;
  final ClubMemberRole? myRole;

  /// Owner/Admin only -- opens the same manage sheet (แก้ไข/ย้าย/ลบ) the
  /// Channel List's long-press already offers, now as an explicit "⋮"
  /// AppBar action since there's no chip left to long-press on this
  /// screen. `null` (a plain Member) hides the action entirely.
  final Future<void> Function(BuildContext context)? onManage;

  /// See [ClubChannelChatView.onBanned]'s own doc comment. Design's
  /// States: being banned mid-chat pops this route back to the Channel
  /// List (the natural "you're not in this room anymore" reaction) and
  /// then still bubbles up to the Club page's own gate, same as before
  /// WYN-133 -- being banned means removed from the whole Club, not just
  /// this one room, so the higher-level member-gate must still run.
  final VoidCallback? onBanned;

  void _handleBanned(BuildContext context) {
    if (Navigator.canPop(context)) Navigator.of(context).pop();
    onBanned?.call();
  }

  @override
  Widget build(BuildContext context) {
    final manage = onManage;
    return Scaffold(
      appBar: AppBar(
        title: Text('#$channelName'),
        actions: [
          if (manage != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'จัดการห้อง',
              onPressed: () => manage(context),
            ),
        ],
      ),
      body: ClubChannelChatView(
        key: ValueKey('club-chat-$channelId'),
        repository: repository,
        clubRepository: clubRepository,
        clubId: clubId,
        channelId: channelId,
        channelName: channelName,
        myRole: myRole,
        onBanned: () => _handleBanned(context),
      ),
    );
  }
}
