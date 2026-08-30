import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../profile/data/profile_repository.dart';
import '../data/chat_repository.dart';
import '../data/shared_content_type.dart';
import 'share_to_chat_screen.dart';

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
Future<void> showShareSheet(
  BuildContext context, {
  required ChatRepository chatRepository,
  required ProfileRepository profileRepository,
  required SharedContentType sharedContentType,
  required String sharedContentId,
  required String previewLabel,
  required String nativeShareText,
  String? nativeShareTitle,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('แชร์เข้า Chat'),
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
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('แชร์ผ่านระบบมือถือ'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              SharePlus.instance.share(
                ShareParams(text: nativeShareText, title: nativeShareTitle),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('คัดลอกลิงก์'),
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
    ),
  );
}
