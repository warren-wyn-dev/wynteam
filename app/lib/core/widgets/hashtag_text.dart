import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/club/data/club_post_repository.dart';
import '../../features/club/data/club_repository.dart';
import '../../features/drop/data/drop_repository.dart';
import '../../features/follow/data/follow_repository.dart';
import '../../features/hashtag/presentation/hashtag_feed_screen.dart';
import '../../features/pop/data/pop_repository.dart';
import '../../features/profile/data/profile.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/view_profile_screen.dart';
import '../../features/saved/data/saved_repository.dart';
import '../text_utils.dart';

/// Drop-in replacement for `Text(caption)` wherever a Drop/Pop/Club post
/// caption is rendered -- renders `#hashtag` tokens as tappable spans
/// that open [HashtagFeedScreen] (WYN-020), and `@username` mention
/// tokens as tappable spans that open that user's [ViewProfileScreen]
/// (WYN-021). One shared widget/regex pass for both, per WYN-021's own
/// spec ("ใช้ widget/helper ร่วมกันตัวเดียว ไม่แยกสอง regex parser").
///
/// Builds its own repositories from `Supabase.instance.client` on tap
/// rather than taking them as constructor params -- the same
/// self-contained-navigation shortcut `PushNotificationService.
/// _openFromPushData` already uses, so none of this widget's 6 call
/// sites (HomeDropCard, HomePopCard, DropDetailScreen, PopClipView,
/// ClubPostCard, ClubPostDetailScreen) need a new required parameter.
/// See .wyn/docs/design/wyn-020-hashtag-system.md and
/// .wyn/docs/design/wyn-021-mention-system.md.
class HashtagText extends StatefulWidget {
  const HashtagText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<HashtagText> createState() => _HashtagTextState();
}

enum _SpanKind { hashtag, mention }

class _TokenMatch {
  const _TokenMatch({required this.kind, required this.start, required this.end, required this.value});

  final _SpanKind kind;
  final int start;
  final int end;

  /// The hashtag (without `#`) or username (without `@`).
  final String value;
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

  Future<void> _openMentionedProfile(String username) async {
    final client = Supabase.instance.client;
    final profileRepository = ProfileRepository(client);
    // An unresolvable mention (typo, deleted account) -- or any other
    // fetch failure, e.g. a transient network error -- fails silently:
    // no snackbar/dialog, same posture every other tap-time failure in
    // this widget has.
    Profile? profile;
    try {
      profile = await profileRepository.fetchProfileByUsername(username);
    } catch (_) {
      return;
    }
    if (profile == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: profileRepository,
          followRepository: FollowRepository(client),
          dropRepository: DropRepository(client),
          popRepository: PopRepository(client),
          savedRepository: SavedRepository(client),
          userId: profile!.id,
        ),
      ),
    );
  }

  List<_TokenMatch> _findTokens(String text) {
    final tokens = [
      for (final m in hashtagPattern.allMatches(text))
        _TokenMatch(kind: _SpanKind.hashtag, start: m.start, end: m.end, value: m.group(1)!),
      for (final m in mentionPattern.allMatches(text))
        _TokenMatch(kind: _SpanKind.mention, start: m.start, end: m.end, value: m.group(1)!),
    ];
    tokens.sort((a, b) => a.start.compareTo(b.start));
    return tokens;
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final tappableStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final token in _findTokens(widget.text)) {
      // hashtagPattern/mentionPattern never overlap (different prefix
      // characters), but a token could still start before lastEnd if
      // sorting alone let a shorter earlier overlap through -- skip
      // defensively rather than emit a negative-length substring.
      if (token.start < lastEnd) continue;

      if (token.start > lastEnd) {
        spans.add(TextSpan(text: widget.text.substring(lastEnd, token.start)));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = token.kind == _SpanKind.hashtag
            ? () => _openHashtagFeed(token.value)
            : () => _openMentionedProfile(token.value);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: widget.text.substring(token.start, token.end),
        style: tappableStyle,
        recognizer: recognizer,
      ));
      lastEnd = token.end;
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
