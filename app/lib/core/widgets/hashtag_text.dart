import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/club/data/club_post_repository.dart';
import '../../features/club/data/club_repository.dart';
import '../../features/drop/data/drop_repository.dart';
import '../../features/follow/data/follow_repository.dart';
import '../../features/hashtag/presentation/hashtag_feed_screen.dart';
import '../../features/pop/data/pop_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/saved/data/saved_repository.dart';
import '../text_utils.dart';

/// Drop-in replacement for `Text(caption)` wherever a Drop/Pop/Club post
/// caption is rendered -- renders `#hashtag` tokens as tappable spans
/// that open [HashtagFeedScreen]. WYN-020.
///
/// Builds its own repositories from `Supabase.instance.client` on tap
/// rather than taking them as constructor params -- the same
/// self-contained-navigation shortcut `PushNotificationService.
/// _openFromPushData` already uses, so none of this widget's 6 call
/// sites (HomeDropCard, HomePopCard, DropDetailScreen, PopClipView,
/// ClubPostCard, ClubPostDetailScreen) need a new required parameter.
/// See .wyn/docs/design/wyn-020-hashtag-system.md.
class HashtagText extends StatefulWidget {
  const HashtagText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<HashtagText> createState() => _HashtagTextState();
}

class _HashtagTextState extends State<HashtagText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _openHashtagFeed(String tag) {
    final client = Supabase.instance.client;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagFeedScreen(
          tag: tag,
          dropRepository: DropRepository(client),
          clubPostRepository: ClubPostRepository(client),
          clubRepository: ClubRepository(client),
          followRepository: FollowRepository(client),
          profileRepository: ProfileRepository(client),
          popRepository: PopRepository(client),
          savedRepository: SavedRepository(client),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final hashtagStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in hashtagPattern.allMatches(widget.text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: widget.text.substring(lastEnd, match.start)));
      }
      final tag = match.group(1)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _openHashtagFeed(tag);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: match.group(0), style: hashtagStyle, recognizer: recognizer));
      lastEnd = match.end;
    }
    if (lastEnd < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
