import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/typography/browser_system_text.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

void main() {
  testWidgets('browser system text shrink-wraps loose bounded labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: const BrowserSystemText(
            'WYNOS',
            key: Key('label'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final size = tester.getSize(find.byKey(const Key('label')));
    expect(size.width, lessThan(120));
    expect(size.height, lessThan(30));
    expect(tester.takeException(), isNull);
  }, skip: !usesBrowserSystemTextDom);

  testWidgets('intrinsic brand label stays on one browser line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 19),
            SizedBox(width: 8),
            BrowserSystemText(
              'WYNOS',
              key: Key('brand'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final size = tester.getSize(find.byKey(const Key('brand')));
    expect(size.height, lessThan(30));
    expect(size.width, greaterThan(45));
    expect(tester.takeException(), isNull);
  }, skip: !usesBrowserSystemTextDom);

  testWidgets('browser text exposes an alphabetic baseline to Flutter rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            BrowserSystemText(
              'หาเพื่อนคุย',
              key: Key('author'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            BrowserSystemText(
              '4 วันที่แล้ว',
              key: Key('time'),
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final authorRect = tester.getRect(find.byKey(const Key('author')));
    final timeRect = tester.getRect(find.byKey(const Key('time')));
    // RenderFlex consumes computeDryBaseline during layout. A smaller
    // timestamp should therefore sit only slightly lower than the
    // larger author label, rather than falling onto a different row.
    expect(tester.takeException(), isNull);
    expect(authorRect.height, greaterThan(timeRect.height));
    expect(timeRect.top, greaterThanOrEqualTo(authorRect.top));
    expect(timeRect.top - authorRect.top, lessThanOrEqualTo(5));
    expect((timeRect.bottom - authorRect.bottom).abs(), lessThanOrEqualTo(5));
  }, skip: !usesBrowserSystemTextDom);
}
