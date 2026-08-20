import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/fullscreen_image_viewer.dart';

void main() {
  const imageUrl = 'https://example.supabase.co/drops/fullscreen-test.jpg';

  testWidgets(
      'wires up an InteractiveViewer configured for 1.0x-4.0x pinch-zoom '
      '(WYN-025 R3)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FullscreenImageViewer(imageUrl: imageUrl)),
    );
    await tester.pump();
    // No real network in the test env -- the image itself failing to
    // load is expected and unrelated to what this test checks.
    tester.takeException();

    final interactiveViewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(interactiveViewer.minScale, 1.0);
    expect(interactiveViewer.maxScale, 4.0);
  });

  testWidgets('has a solid black background and no AppBar (fills the screen)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FullscreenImageViewer(imageUrl: imageUrl)),
    );
    await tester.pump();
    tester.takeException();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('the back button pops back to the previous screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) =>
                        const FullscreenImageViewer(imageUrl: imageUrl),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(FullscreenImageViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(FullscreenImageViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
      'double-tap zooms in, and a second double-tap zooms back out to 1.0x',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FullscreenImageViewer(imageUrl: imageUrl)),
    );
    await tester.pump();
    tester.takeException();

    InteractiveViewer viewer() =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));

    expect(viewer().transformationController!.value, Matrix4.identity());

    await tester.tap(find.byType(FullscreenImageViewer));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byType(FullscreenImageViewer));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(
      viewer().transformationController!.value,
      isNot(equals(Matrix4.identity())),
    );

    await tester.tap(find.byType(FullscreenImageViewer));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byType(FullscreenImageViewer));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(viewer().transformationController!.value, Matrix4.identity());
  });
}
