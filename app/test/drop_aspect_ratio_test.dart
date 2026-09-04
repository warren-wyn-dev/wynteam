import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/drop/data/square_crop.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';

/// A solid image of the given size, as PNG bytes.
Future<Uint8List> _image(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<(int, int)> _sizeOf(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return (frame.image.width, frame.image.height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // WYN-109. Before this, every photo posted through the app was cut to
  // a square whether or not that suited it, and the poster was never
  // asked. These cover the cutting itself; the picker that chooses the
  // shape is wired in create_drop_screen.dart.
  group('centerCropToRatio', () {
    test('cuts a landscape photo to 4:5 by giving up width, not height',
        () async {
      final cropped = await centerCropToRatio(await _image(1600, 1200), 4 / 5);
      final (width, height) = await _sizeOf(cropped);
      expect(height, 1200, reason: 'the full height is available, so keep it');
      expect(width, 960);
      expect(width / height, closeTo(4 / 5, 0.001));
    });

    test('cuts a tall photo to 16:9 by giving up height', () async {
      final cropped = await centerCropToRatio(await _image(1080, 1920), 16 / 9);
      final (width, height) = await _sizeOf(cropped);
      expect(width, 1080);
      expect(height, 608); // 1080 * 9/16, rounded
      expect(width / height, closeTo(16 / 9, 0.005));
    });

    test('never scales a photo up to reach the shape', () async {
      final source = await _image(400, 400);
      final cropped = await centerCropToRatio(source, 16 / 9);
      final (width, height) = await _sizeOf(cropped);
      expect(width, lessThanOrEqualTo(400));
      expect(height, lessThanOrEqualTo(400));
    });

    test('a square request is what centerCropToSquare already did',
        () async {
      final source = await _image(1600, 1200);
      final viaRatio = await _sizeOf(await centerCropToRatio(source, 1));
      final viaSquare = await _sizeOf(await centerCropToSquare(source));
      expect(viaRatio, viaSquare);
      expect(viaRatio.$1, viaRatio.$2);
    });
  });

  group('DropAspectRatio', () {
    test('every option round-trips through its stored value', () {
      for (final ratio in DropAspectRatio.values) {
        expect(DropAspectRatio.fromWire(ratio.wireValue), ratio);
      }
    });

    test('a post written before the column reads as 4:5', () {
      // Not an arbitrary default: those photos are squares that the feed
      // already drew in a 4:5 card, so 4:5 is what they look like today
      // and what they must keep looking like.
      expect(DropAspectRatio.fromWire(null), DropAspectRatio.portrait);
    });

    test('an unrecognised value falls back instead of throwing', () {
      // A feed that fails to render over one unexpected string would be
      // a worse outcome than a photo at a slightly wrong shape.
      expect(DropAspectRatio.fromWire('7:3'), DropAspectRatio.portrait);
    });

    test('"ต้นฉบับ" has no fixed ratio -- that is the point of it', () {
      expect(DropAspectRatio.original.ratio, isNull);
      expect(DropAspectRatio.portrait.ratio, closeTo(0.8, 0.0001));
      expect(DropAspectRatio.landscape.ratio, closeTo(16 / 9, 0.0001));
    });
  });

  group('HomeFeedItem carries the ratio', () {
    Map<String, dynamic> row(String? ratio) => {
          'id': 'd1',
          'content_type': 'drop',
          'author_id': 'a1',
          'author_username': 'namfah',
          'created_at': DateTime.now().toIso8601String(),
          'image_url': 'https://example.test/a.jpg',
          'image_aspect_ratio': ratio,
          // The feed view always supplies these; the model reads them
          // as non-null.
          'like_count': 0,
          'comment_count': 0,
        };

    test('reads the poster\'s choice off the feed row', () {
      expect(
        HomeFeedItem.fromMap(row('16:9'), likedByMe: false, savedByMe: false)
            .aspectRatio,
        DropAspectRatio.landscape,
      );
    });

    test('an older row with no value still renders at 4:5', () {
      expect(
        HomeFeedItem.fromMap(row(null), likedByMe: false, savedByMe: false)
            .aspectRatio,
        DropAspectRatio.portrait,
      );
    });
  });

  // The four defects QA found on the first pass (2026-09-04). Each one
  // is here so it cannot come back quietly.
  group('WYN-109/108 QA round 1 regressions', () {
    test(
        'a post with no photos does not name the aspect-ratio column '
        '(B-109-1, Critical)', () {
      // The insert used to name `image_aspect_ratio` on every Drop --
      // text, poll, Draft included -- so on a database that had not run
      // the migration yet, PostgREST rejected the insert and posting
      // anything at all failed. The column belongs to the photo
      // feature; nothing else should depend on it existing.
      final source =
          File('lib/features/drop/data/drop_repository.dart').readAsStringSync();
      expect(
        source.contains(
            "if (aspectRatio != null) 'image_aspect_ratio': aspectRatio.wireValue"),
        isTrue,
        reason: 'the column must only be named when there is a ratio to store',
      );
      expect(
        source.contains("'image_aspect_ratio': aspectRatio?.wireValue"),
        isFalse,
        reason: 'naming it unconditionally is what broke every post type',
      );
    });

    test('the comment heart is 16px, the size it replaced (B-108-1)', () {
      // IconButton's `iconSize` reaches an Icon through IconTheme and
      // cannot reach a widget that sizes itself, so the 24 written here
      // silently drew the comment heart half again as large.
      final source = File('lib/features/drop/presentation/drop_detail_screen.dart')
          .readAsStringSync();
      final commentHeart = RegExp(
        r'icon: WynHeartIcon\(\s*filled: comment\.likedByMe,\s*size: (\d+)',
      ).firstMatch(source);
      expect(commentHeart, isNotNull);
      expect(commentHeart!.group(1), '16');
    });

    test('the post-detail gallery draws the chosen ratio (B-109-2)', () {
      // A 16:9 post looked right in the feed and was cropped back to
      // 4:5 the moment you opened it -- the second crop this whole
      // feature exists to remove.
      final source =
          File('lib/features/drop/presentation/widgets/drop_image_gallery.dart')
              .readAsStringSync();
      expect(source.contains('aspectRatio: widget.drop.aspectRatio.ratio'), isTrue);
    });

    test('the compose preview is shaped by the chosen ratio (B-109-3)', () {
      // A fixed 128x160 frame meant every chip looked identical, so the
      // poster could not see what they were choosing.
      final source =
          File('lib/features/drop/presentation/create_drop_screen.dart')
              .readAsStringSync();
      expect(source.contains('double get _previewWidth'), isTrue);
      expect(source.contains('width: _previewWidth'), isTrue);
    });
  });
}
