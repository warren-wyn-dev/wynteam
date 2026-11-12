import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/widgets/retained_page.dart';

class _Work {
  int builds = 0;
  int layouts = 0;
  int paints = 0;
}

class _Probe extends SingleChildRenderObjectWidget {
  const _Probe(this.work, {super.key, required super.child});
  final _Work work;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe(work);
}

class _RenderProbe extends RenderProxyBox {
  _RenderProbe(this.work);
  final _Work work;

  @override
  void performLayout() {
    work.layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    work.paints++;
    super.paint(context, offset);
  }
}

void main() {
  testWidgets('hidden snapshots skip unrelated rebuild and paint work', (
    tester,
  ) async {
    final work = _Work();
    final probe = GlobalKey();
    Widget app(bool active, double width, String value) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          height: 300,
          child: RetainedMerchantPage(
            active: active,
            builder: (_) {
              work.builds++;
              return _Probe(
                work,
                key: probe,
                child: Text(value, textDirection: TextDirection.ltr),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(true, 300, 'original'));
    expect(find.text('original'), findsOneWidget);
    await tester.pumpWidget(app(false, 300, 'hidden update'));
    final oldBuilds = work.builds;
    final oldLayouts = work.layouts;
    final oldPaints = work.paints;
    await tester.pumpWidget(app(false, 300, 'latest value'));
    expect(work.builds, oldBuilds);
    expect(work.layouts, oldLayouts);
    expect(work.paints, oldPaints);
    expect(find.text('original'), findsNothing);
    expect(find.text('original', skipOffstage: false), findsOneWidget);

    // Viewport changes and independently dirty descendants still follow the
    // framework layout contract, including while the page is offstage.
    probe.currentContext!.findRenderObject()!.markNeedsLayout();
    await tester.pumpWidget(app(false, 420, 'latest value'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(true, 420, 'latest value'));
    expect(find.text('latest value'), findsOneWidget);
    expect(work.layouts, greaterThan(oldLayouts));
    expect(tester.getSize(find.byKey(probe)).width, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden page retains draft, excludes focus and semantics', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final semantics = tester.ensureSemantics();
    Widget app(bool active) => MaterialApp(
      home: Scaffold(
        body: RetainedMerchantPage(
          active: active,
          builder: (_) => Column(
            children: [
              Semantics(
                container: true,
                excludeSemantics: true,
                label: 'private form',
                child: const Text('draft page'),
              ),
              TextField(focusNode: focus),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(true));
    expect(find.bySemanticsLabel('private form'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unsent draft');
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(focus.hasFocus, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(find.bySemanticsLabel('private form'), findsNothing);
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(find.text('unsent draft'), findsOneWidget);
    expect(find.bySemanticsLabel('private form'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retained pages support finite intrinsic and dry layout', (
    tester,
  ) async {
    Widget app(bool active) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: RetainedMerchantPage(
              active: active,
              builder: (_) => const SizedBox(width: 140, height: 80),
            ),
          ),
        ),
      ),
    );
    for (final active in [true, false, true]) {
      await tester.pumpWidget(app(active));
      final render = tester.renderObject<RenderBox>(
        find.byType(RetainedMerchantPage),
      );
      final dry = render.getDryLayout(const BoxConstraints(maxWidth: 400));
      expect(dry.isFinite, isTrue);
      expect(tester.takeException(), isNull);
    }
  });
}
