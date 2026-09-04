import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/widgets/wyn_heart_icon.dart';

/// Finds the Like heart in whichever state it is drawn -- WYN-108.
///
/// The heart used to be `Icons.favorite`/`Icons.favorite_border`, so
/// tests reached for it with `find.byIcon`. It is WYN's own shape now
/// ([WynHeartIcon]), and its state is a `filled` flag rather than two
/// different glyphs, so this is the finder that replaces those.
Finder findHeart({required bool filled}) => find.byWidgetPredicate(
      (widget) => widget is WynHeartIcon && widget.filled == filled,
      description: filled ? 'a filled heart' : 'an outline heart',
    );

/// The tappable [T] that a heart in the given state sits inside -- an
/// [IconButton] on the detail screens, an `ActionMetric` in the feed.
Finder findHeartButton<T extends Widget>({required bool filled}) =>
    find.ancestor(of: findHeart(filled: filled), matching: find.byType(T));
