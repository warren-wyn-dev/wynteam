import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_surface.dart';

import 'support/pump_zoky.dart';

/// Tight bounds of [path] by sampling its outline (Path.getBounds also
/// counts the control points of arcs and curves).
Rect _tight(Path path) {
  double l = double.infinity, t = double.infinity;
  double r = -double.infinity, b = -double.infinity;
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d <= m.length; d += m.length / 400) {
      final p = m.getTangentForOffset(d)!.position;
      l = p.dx < l ? p.dx : l;
      t = p.dy < t ? p.dy : t;
      r = p.dx > r ? p.dx : r;
      b = p.dy > b ? p.dy : b;
    }
  }
  return Rect.fromLTRB(l, t, r, b);
}

void main() {
  for (final glyph in Zoky3DGlyph.values) {
    testWidgets('$glyph renders at 16/24/48px without exceptions', (
      tester,
    ) async {
      await pumpZokyWidget(
        tester,
        Row(
          children: [
            for (final size in [16.0, 24.0, 48.0])
              for (final palette in [Zoky3DPalette.pink, Zoky3DPalette.white])
                Zoky3DIcon(glyph, size: size, palette: palette),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      final icons = find.byType(Zoky3DIcon);
      expect(icons, findsNWidgets(6));
      expect(tester.getSize(icons.first), const Size.square(16));
      expect(tester.getSize(icons.last), const Size.square(48));
    });
  }

  testWidgets('3D icons are decorative unless given a label', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyWidget(
      tester,
      const Column(
        children: [
          Zoky3DIcon(Zoky3DGlyph.sparkle),
          Zoky3DIcon(Zoky3DGlyph.heart, semanticLabel: 'ร้านโปรด'),
        ],
      ),
    );
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Zoky3DIcon && w.glyph == Zoky3DGlyph.sparkle,
        ),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('ร้านโปรด')),
      isSemantics(label: 'ร้านโปรด', isImage: true),
    );
    semantics.dispose();
  });

  test('glyph paths stay inside their unit box', () {
    const s = 48.0;
    final box = Offset.zero & const Size.square(s);
    for (final path in [
      Zoky3DIconPainter.heartPath(s),
      Zoky3DIconPainter.sparklePath(s),
      Zoky3DIconPainter.spherePath(s),
      Zoky3DIconPainter.arrowPath(s),
      Zoky3DIconPainter.homePath(s),
      Zoky3DIconPainter.receiptPath(s),
      Zoky3DIconPainter.receiptLinesPath(s),
      Zoky3DIconPainter.chatPath(s),
      Zoky3DIconPainter.personPath(s),
    ]) {
      final b = _tight(path);
      expect(box.contains(b.topLeft) && box.contains(b.bottomRight), isTrue);
    }
  });

  testWidgets('glossy surface paints with and without a radius', (
    tester,
  ) async {
    await pumpZokyWidget(
      tester,
      const Column(
        children: [
          SizedBox(height: 80, child: ZokyGlossySurface(glossHeight: 40)),
          SizedBox(
            height: 80,
            child: ZokyGlossySurface(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              glossHeight: 500, // taller than the surface: clamped
            ),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    // Square surfaces are not clipped (header sheet overlaps its edge).
    expect(
      find.descendant(
        of: find.byType(ZokyGlossySurface).first,
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
  });

  const navGlyphs = [
    Zoky3DGlyph.home,
    Zoky3DGlyph.receipt,
    Zoky3DGlyph.chat,
    Zoky3DGlyph.person,
  ];

  test('nav glyphs keep the stroke and the scaled 3D body inside the box', () {
    const s = 48.0;
    final half = Zoky3DIconPainter.lineWidth * s / 2;
    for (final glyph in navGlyphs) {
      final b = _tight(Zoky3DIconPainter.bodyPath(glyph, s));
      // Line style: half the stroke sits outside the path.
      expect(b.inflate(half).left, greaterThanOrEqualTo(0), reason: '$glyph');
      expect(b.inflate(half).right, lessThanOrEqualTo(s), reason: '$glyph');
      expect(b.inflate(half).top, greaterThanOrEqualTo(0), reason: '$glyph');
      expect(b.inflate(half).bottom, lessThanOrEqualTo(s), reason: '$glyph');
      // Glossy style: scaled about the center, plus the 0.06s drop shadow.
      const k = Zoky3DIconPainter.glossyTwinScale;
      final scaled = Rect.fromLTRB(
        s / 2 + (b.left - s / 2) * k,
        s / 2 + (b.top - s / 2) * k,
        s / 2 + (b.right - s / 2) * k,
        s / 2 + (b.bottom - s / 2) * k,
      );
      expect(scaled.left, greaterThanOrEqualTo(0), reason: '$glyph');
      expect(scaled.top, greaterThanOrEqualTo(0), reason: '$glyph');
      expect(scaled.right, lessThanOrEqualTo(s), reason: '$glyph');
      expect(scaled.bottom + 0.06 * s, lessThanOrEqualTo(s), reason: '$glyph');
    }
  });

  /// Bounding box of pixels with alpha > 40, or null when nothing painted.
  Future<Rect?> paintedBox(WidgetTester tester, Widget icon) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: RepaintBoundary(key: key, child: icon)),
      ),
    );
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return tester.runAsync<Rect?>(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      image.dispose();
      final bytes = data!.buffer.asUint8List();
      double? l, t, r, b;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (bytes[(y * w + x) * 4 + 3] > 40) {
            l = l == null || x < l ? x.toDouble() : l;
            r = r == null || x > r ? x.toDouble() : r;
            t ??= y.toDouble();
            b = y.toDouble();
          }
        }
      }
      if (l == null) return null;
      return Rect.fromLTRB(l / 2, t! / 2, (r! + 1) / 2, (b! + 1) / 2);
    });
  }

  for (final glyph in navGlyphs) {
    testWidgets('$glyph line and 3D render and align at 20/24/28', (
      tester,
    ) async {
      for (final size in [20.0, 24.0, 28.0]) {
        final line = await paintedBox(
          tester,
          Zoky3DIcon(glyph, size: size, style: Zoky3DIconStyle.line),
        );
        final glossy = await paintedBox(
          tester,
          Zoky3DIcon(glyph, size: size),
        );
        expect(line, isNotNull, reason: '$glyph line $size');
        expect(glossy, isNotNull, reason: '$glyph 3D $size');
        // Inside the icon box, and the two variants share one optical
        // footprint (the glossy one also has a small drop shadow below).
        expect(line!.width, lessThanOrEqualTo(size));
        expect(glossy!.width, lessThanOrEqualTo(size));
        expect(
          (line.center.dx - glossy.center.dx).abs(),
          lessThanOrEqualTo(1.5),
          reason: '$glyph $size',
        );
        expect(
          (line.top - glossy.top).abs(),
          lessThanOrEqualTo(1.5),
          reason: '$glyph $size',
        );
        expect(
          (line.width - glossy.width).abs(),
          lessThanOrEqualTo(0.15 * size),
          reason: '$glyph $size: $line vs $glossy',
        );
      }
    });
  }

  testWidgets('line style and color take part in repaint and render', (tester) async {
    const color = Color(0xFF6B6B76);
    final painter = Zoky3DIconPainter(
      glyph: Zoky3DGlyph.home,
      palette: Zoky3DPalette.pink,
      style: Zoky3DIconStyle.line,
      lineColor: color,
    );
    expect(
      painter.shouldRepaint(
        const Zoky3DIconPainter(
          glyph: Zoky3DGlyph.home,
          palette: Zoky3DPalette.pink,
        ),
      ),
      isTrue,
    );
    await pumpZokyWidget(
      tester,
      const Center(
        child: Zoky3DIcon(
          Zoky3DGlyph.chat,
          style: Zoky3DIconStyle.line,
          lineColor: color,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
