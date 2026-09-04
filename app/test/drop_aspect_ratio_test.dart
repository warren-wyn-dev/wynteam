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
}
