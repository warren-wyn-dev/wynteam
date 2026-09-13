import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';

void main() {
  testWidgets('shows the first letter of fallbackText when imageUrl is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AvatarCircle(imageUrl: null, fallbackText: 'namfah'),
      ),
    ));

    expect(find.text('N'), findsOneWidget);
    expect(find.bySemanticsLabel('รูปโปรไฟล์ของ namfah'), findsOneWidget);
  });

  testWidgets('shows "?" when fallbackText is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AvatarCircle(imageUrl: null, fallbackText: '')),
    ));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('uses Image.network instead of the letter when imageUrl is set',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AvatarCircle(
          imageUrl: 'https://example.supabase.co/avatars/u1/avatar.jpg',
          fallbackText: 'namfah',
        ),
      ),
    ));
    tester.takeException();

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image)).image;
    // Image.network still applies cacheWidth as a ResizeImage on the normal
    // engine-backed path; iOS Web uses the HTML strategy instead.
    expect(image, isA<ResizeImage>());
    expect((image as ResizeImage).imageProvider, isA<NetworkImage>());
    expect(find.text('N'), findsNothing);
  });

  testWidgets(
      'decodes at the avatar\'s own size in physical pixels, not the '
      'source image size', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(devicePixelRatio: 3),
      child: MaterialApp(
        home: Scaffold(
          body: AvatarCircle(
            imageUrl: 'https://example.supabase.co/avatars/u1/avatar.jpg',
            fallbackText: 'namfah',
            radius: 20,
          ),
        ),
      ),
    ));
    tester.takeException();

    final image = tester.widget<Image>(find.byType(Image)).image;
    // 20 radius -> 40 logical px across, x3 device pixel ratio.
    expect((image as ResizeImage).width, 120);
  });

  testWidgets(
      'falls back to the initial when the image fails to load, rather than '
      'painting an empty circle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AvatarCircle(
          imageUrl: 'https://example.supabase.co/avatars/u1/missing.jpg',
          fallbackText: 'namfah',
        ),
      ),
    ));

    // No network in the test environment, so the load genuinely fails --
    // which is exactly the case under test. Let the error propagate to
    // the widget's own handler, then rebuild.
    await tester.pump();
    tester.takeException();
    await tester.pumpAndSettle();

    expect(find.text('N'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
