import 'package:flutter/material.dart';
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
}
