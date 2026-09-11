import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/wyn_colors.dart';

import '../../club/data/club_repository.dart';
import '../../club/presentation/invite_to_club_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/chat_repository.dart';
import '../data/shared_content_type.dart';
import 'share_to_chat_screen.dart';
import 'widgets/chat_ui.dart';

/// Screen 1 (WYN-033) -- the 3-item sheet a "แชร์" entry point opens:
/// "แชร์เข้า Chat" (new), "แชร์ผ่านระบบมือถือ" (native share, the same
/// `SharePlus.instance.share()` call every "แชร์" button already made
/// before this task), and "คัดลอกลิงก์" (07-post-detail.tsx: Drop
/// Detail's own standalone header copy-link icon folds in here instead
/// -- [nativeShareText] is already the plain shareable link at every
/// call site (dropShareLink/profileShareLink/clubShareLink), so this
/// needs no new parameter to reuse it). Shared across Drop/Club/
/// Profile's entry points rather than duplicated 3 times -- see
/// .wyn/docs/design/wyn-033-share-to-chat.md, Screen 1.
///
/// WYN-123: a 4th, topmost item -- "เชิญจากผู้ติดตาม" -- appears only
/// when [sharedContentType] is [SharedContentType.club] and
/// [followRepository]/[clubRepository]/[clubName] are all supplied
/// (Club's own call site is the only one that passes them; Drop/
/// Profile's sheets are unchanged). Opens [InviteToClubScreen] instead
/// of the generic native share/copy-link flow -- see .wyn/docs/design/
/// wyn-115-invite-followers-to-club.md, Screen 1. WYN-124:
/// [clubRepository] (not [chatRepository]) is what [InviteToClubScreen]
/// actually sends invites through now -- see that screen's own doc
/// comment.
Future<void> showShareSheet(
  BuildContext context, {
  required ChatRepository chatRepository,
  required ProfileRepository profileRepository,
  required SharedContentType sharedContentType,
  required String sharedContentId,
  required String previewLabel,
  required String nativeShareText,
  String? nativeShareTitle,
  FollowRepository? followRepository,
  ClubRepository? clubRepository,
  String? clubName,
}) async {
  final showInviteFromFollowers = sharedContentType == SharedContentType.club &&
      followRepository != null &&
      clubRepository != null &&
      clubName != null;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: WynColors.imageScrim,
    builder: (sheetContext) => ChatActionSheetBody(
      title: 'แชร์',
      subtitle: previewLabel,
      rows: [
        if (showInviteFromFollowers)
          ChatActionSheetRow(
            icon: Icons.person_add_alt_1,
            label: 'เชิญจากผู้ติดตาม',
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InviteToClubScreen(
                    followRepository: followRepository,
                    clubRepository: clubRepository,
                    clubId: sharedContentId,
                    clubName: clubName,
                  ),
                ),
              );
            },
          ),
        ChatActionSheetRow(
          icon: Icons.chat_bubble_outline,
          label: 'แชร์เข้า Chat',
          onTap: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShareToChatScreen(
                  chatRepository: chatRepository,
                  profileRepository: profileRepository,
                  sharedContentType: sharedContentType,
                  sharedContentId: sharedContentId,
                  previewLabel: previewLabel,
                ),
              ),
            );
          },
        ),
        ChatActionSheetRow(
          icon: Icons.ios_share,
          label: 'แชร์ผ่านระบบมือถือ',
          onTap: () {
            Navigator.of(sheetContext).pop();
            SharePlus.instance.share(
              ShareParams(text: nativeShareText, title: nativeShareTitle),
            );
          },
        ),
        ChatActionSheetRow(
          icon: Icons.link,
          label: 'คัดลอกลิงก์',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await Clipboard.setData(ClipboardData(text: nativeShareText));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
            );
          },
        ),
      ],
    ),
  );
}
