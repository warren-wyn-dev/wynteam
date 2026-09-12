import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// Full-screen media viewer used only by Chat.
///
/// Keeps moderation/evidence viewers untouched while giving chat photos the
/// approved dark, distraction-free media presentation.
class ChatMediaViewer extends StatelessWidget {
  const ChatMediaViewer({
    super.key,
    required this.signedUrl,
    this.title = 'รูปภาพ',
  });

  final String signedUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    signedUrl,
                    fit: BoxFit.contain,
                    errorBuilder: networkImageErrorBuilder,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WynSpacing.space3,
                vertical: WynSpacing.space2,
              ),
              child: Row(
                children: [
                  Material(
                    color: WynColors.imageScrimStrong,
                    shape: const CircleBorder(),
                    child: BrowserSystemTooltip(message: 'ปิด', child: IconButton(
                      key: const Key('chat_media_close_button'),
                      icon: const Icon(Icons.close,
                          color: WynColors.paper, size: 21),
                      tooltip: null,
                      onPressed: () => Navigator.of(context).pop(),
                    )),
                  ),
                  const SizedBox(width: WynSpacing.space3),
                  Expanded(
                    child: BrowserSystemText(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: WynColors.paper,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: WynSpacing.space4),
                child: Center(
                  child: BrowserSystemText(
                    'บีบนิ้วเพื่อซูม',
                    style: TextStyle(fontSize: 12, color: WynColors.faint),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
