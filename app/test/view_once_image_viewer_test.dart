import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/chat/presentation/widgets/view_once_image_viewer.dart';

/// Covers ViewOnceImageViewer's countdown/auto-pop behavior in isolation,
/// referenced from conversation_screen_test.dart's own comments -- that
/// file only ever pumps this widget forward by a couple hundred
/// milliseconds (well short of the first tick) so it can assert the
/// viewer is still open, then closes it manually. The actual countdown
/// and auto-pop-at-zero behavior is this file's job.
void main() {
  Widget buildViewer({Duration duration = const Duration(seconds: 3)}) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ViewOnceImageViewer(
                      signedUrl: 'https://example.supabase.co/signed/x.jpg',
                      duration: duration,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('shows the starting countdown and the close button',
      (tester) async {
    await tester.pumpWidget(buildViewer(duration: const Duration(seconds: 3)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The fake signed URL 404s -- harmless NetworkImageLoadException
    // noise, same convention as bookmarks_screen_test.dart's own
    // takeException() calls (errorBuilder keeps it from affecting
    // layout, but the exception itself still surfaces here).
    tester.takeException();

    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const Key('view_once_close_button')), findsOneWidget);
  });

  testWidgets('ticks the countdown down by one every second', (tester) async {
    await tester.pumpWidget(buildViewer(duration: const Duration(seconds: 3)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      'auto-pops itself once the countdown reaches zero, with no '
      'timersPending leak', (tester) async {
    await tester.pumpWidget(buildViewer(duration: const Duration(seconds: 2)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.byKey(const Key('view_once_close_button')), findsOneWidget);

    // Advance past the full duration -- the Timer.periodic should pop
    // the route on its own, cancelling itself in the process (verified
    // by flutter_test's own end-of-test timersPending check: leaving it
    // running would fail the test even without an explicit assertion).
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view_once_close_button')), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the close button pops before the countdown finishes',
      (tester) async {
    await tester.pumpWidget(buildViewer(duration: const Duration(seconds: 8)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byKey(const Key('view_once_close_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view_once_close_button')), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
