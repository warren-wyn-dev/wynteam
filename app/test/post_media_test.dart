import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/post_media.dart';

void main() {
  group('postImageAspectRatio', () {
    test('returns a photo\'s own ratio when it is inside the bounds', () {
      // A plain 3:2 landscape and a 4:5 portrait both render whole.
      expect(postImageAspectRatio(3000, 2000), closeTo(1.5, 0.0001));
      expect(postImageAspectRatio(1080, 1350), closeTo(0.8, 0.0001));
    });

    test('clamps a photo more portrait than 4:5 to 4:5', () {
      // A 9:16 phone-screenshot shape (0.5625) would otherwise be tall
      // enough to fill a whole viewport on its own.
      expect(postImageAspectRatio(1080, 1920), minPostImageAspectRatio);
    });

    test('clamps a photo more landscape than 1.91:1 to 1.91:1', () {
      expect(postImageAspectRatio(3000, 500), maxPostImageAspectRatio);
    });

    test('falls back to a square when the dimensions are not known', () {
      // Every Drop uploaded before WYN-093 added these columns.
      expect(postImageAspectRatio(null, null), 1);
      expect(postImageAspectRatio(1080, null), 1);
      expect(postImageAspectRatio(null, 1080), 1);
    });

    test('falls back to a square rather than dividing by a bad dimension', () {
      expect(postImageAspectRatio(1080, 0), 1);
      expect(postImageAspectRatio(1080, -5), 1);
      expect(postImageAspectRatio(0, 1080), 1);
    });
  });

  group('PostImageFrame', () {
    testWidgets('lays a portrait photo out at its own ratio, not a square',
        (tester) async {
      // The Beta3 defect this exists to catch: Drop Detail used to
      // render every photo into AspectRatio(1) with BoxFit.cover, so a
      // 4:5 portrait lost its top and bottom on the one screen whose
      // job is showing it.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostImageFrame(
            imageUrl: 'https://example.supabase.co/drops/portrait.jpg',
            imageWidth: 1080,
            imageHeight: 1350,
          ),
        ),
      ));
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;
      expect(aspectRatio, closeTo(0.8, 0.0001));
    });

    testWidgets('never lets a photo grow past its share of the viewport',
        (tester) async {
      // 600 logical pixels tall by default in flutter_test; a 4:5
      // portrait at the full 800 width would want 1000.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostImageFrame(
            imageUrl: 'https://example.supabase.co/drops/portrait.jpg',
            imageWidth: 1080,
            imageHeight: 1350,
            maxHeightFraction: 0.75,
          ),
        ),
      ));
      tester.takeException();

      expect(
        tester.getSize(find.byType(AspectRatio)).height,
        lessThanOrEqualTo(0.75 * 600),
      );
    });
  });

  group('PostImage', () {
    testWidgets(
        'decodes to the size it is painted at, not the size it was '
        'uploaded at', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 390,
            child: PostImage(
              imageUrl: 'https://example.supabase.co/drops/d1.jpg',
            ),
          ),
        ),
      ));
      tester.takeException();

      // 390 logical pixels at the test environment's DPR of 3 -- a
      // memory bound, never a sharpness tradeoff: the photo is still
      // decoded at full physical resolution for the box it lands in.
      // Without it a 1600x1600 upload decodes in full regardless,
      // ~10MB of bitmap per photo, several photos alive at once in a
      // feed.
      final devicePixelRatio = tester.view.devicePixelRatio;
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as ResizeImage).width,
        (390 * devicePixelRatio).round(),
      );
    });
  });
  group('PostImageCarousel', () {
    const urls = [
      'https://example.supabase.co/drops/d1_0.jpg',
      'https://example.supabase.co/drops/d1_1.jpg',
      'https://example.supabase.co/drops/d1_2.jpg',
    ];

    Future<ScrollableState> pumpRow(
      WidgetTester tester, {
      ValueChanged<int>? onIndexChanged,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: PostImageCarousel(
              imageUrls: urls,
              onIndexChanged: onIndexChanged,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();
      return tester.state<ScrollableState>(find.byType(Scrollable));
    }

    testWidgets('lays cards out at 82% of the row, so the next one peeks',
        (tester) async {
      await pumpRow(tester);

      final firstCard = tester.getRect(find.byType(ClipRRect).first);
      expect(firstCard.width, closeTo(400 * postCardWidthFraction, 0.5));
      expect(
        firstCard.width / firstCard.height,
        closeTo(postCardAspectRatio, 0.01),
      );
    });

    testWidgets('a drag settles on a card boundary, never between two',
        (tester) async {
      // Founder, 2026-09-03: "ให้ snap ทีละการ์ดเลย". Before this the
      // row scrolled freely and could come to rest with a card parked
      // half off the edge.
      final scrollable = await pumpRow(tester);
      const stride = 400 * postCardWidthFraction + 8;
      // WYN-111 fix: card 1 (and every card but the first) now rests
      // this much short of a clean stride multiple, on purpose -- see
      // post_media.dart's own _leadingPeekFor doc comment -- so a
      // sliver of card 0 stays peeking on the left instead of being
      // scrolled fully out of view.
      const halfPeek = (400 - 400 * postCardWidthFraction) / 2;

      // A short, slow drag -- less than half a card, so it should
      // settle back where it started rather than creep.
      await tester.drag(find.byType(PostImageCarousel), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, closeTo(0, 0.5));

      // Past the halfway point, it settles on card two.
      await tester.drag(find.byType(PostImageCarousel), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, closeTo(stride - halfPeek, 0.5));
    });

    testWidgets('a flick advances exactly one card, however hard',
        (tester) async {
      final scrollable = await pumpRow(tester);
      const stride = 400 * postCardWidthFraction + 8;
      // See the identical drag test above for why this is short of a
      // clean stride multiple now.
      const halfPeek = (400 - 400 * postCardWidthFraction) / 2;

      await tester.fling(
        find.byType(PostImageCarousel),
        const Offset(-100, 0),
        6000,
      );
      await tester.pumpAndSettle();

      // One card, not three -- a 9-photo post stays a sequence of
      // photos instead of a blur that ends somewhere arbitrary.
      expect(scrollable.position.pixels, closeTo(stride - halfPeek, 0.5));
    });

    testWidgets('reports the card in front as it changes', (tester) async {
      final reported = <int>[];
      await pumpRow(tester, onIndexChanged: reported.add);

      await tester.drag(find.byType(PostImageCarousel), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(reported.last, 1);

      await tester.drag(find.byType(PostImageCarousel), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(reported.last, 0);
    });

    testWidgets('the last card stops at the end of the row, not past it',
        (tester) async {
      final scrollable = await pumpRow(tester);

      await tester.fling(
        find.byType(PostImageCarousel),
        const Offset(-1200, 0),
        8000,
      );
      await tester.pumpAndSettle();

      expect(
        scrollable.position.pixels,
        lessThanOrEqualTo(scrollable.position.maxScrollExtent + 0.5),
      );
    });

    // WYN-111: Founder, 2026-09-05, after a Threads recording --
    // "สังเกตการเลื่อนดูรูปดีๆ มันต่างจาก WYNOS ยังไง อยากได้แบบในคลิป". The
    // card in front should read larger than the ones receding on either
    // side, continuously as a drag moves rather than jumping straight
    // from one size to the other. These measure the rendered size
    // (what the reader actually sees), not the Transform.scale value
    // that produces it -- the same "measure what's rendered" discipline
    // WYN-106-109's own regression tests already established, since a
    // source-only assertion would pass right through a revert that kept
    // the constant but stopped applying it.
    group('WYN-111: the card in front reads larger', () {
      // getRect, not getSize: Transform.scale leaves the ClipRRect's own
      // RenderBox.size (what getSize reads) untouched -- a transform is
      // a paint-time operation, not a layout one -- and only shows up
      // once the transform chain up to the root is applied, which is
      // what getRect's localToGlobal walk does. The original 82% test
      // above already relies on this same fact.
      Size cardSize(WidgetTester tester, int index) =>
          tester.getRect(find.byType(ClipRRect).at(index)).size;

      testWidgets(
          'before any drag, the front card is full size and the next '
          'one already reads smaller', (tester) async {
        await pumpRow(tester);

        final front = cardSize(tester, 0);
        final next = cardSize(tester, 1);

        expect(front.width, closeTo(400 * postCardWidthFraction, 0.5));
        // Not exactly postCardPeekScale: WYN-111 fix's left-peek
        // reservation (post_media.dart's _leadingPeekFor) moves card
        // 1's own resting position closer to card 0's than a clean
        // stride multiple would be, so at rest on card 0 it hasn't
        // receded all the way to the peek floor yet -- mirroring that
        // same formula here rather than asserting a magic number.
        const stride = 400 * postCardWidthFraction + 8;
        const halfPeek = (400 - 400 * postCardWidthFraction) / 2;
        const distance = (stride - halfPeek) / stride;
        const expectedScale = 1 + (postCardPeekScale - 1) * distance;
        expect(next.width, closeTo(front.width * expectedScale, 0.5));
        expect(next.height, closeTo(front.height * expectedScale, 0.5));
      });

      testWidgets(
          'mid-drag, the outgoing and incoming cards are between full '
          'size and peek size, not one or the other', (tester) async {
        await pumpRow(tester);
        final frontAtRest = cardSize(tester, 0).width;
        final nextAtRest = cardSize(tester, 1).width;

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PostImageCarousel)),
        );
        // Half of the 400*0.82+8 stride -- partway through the swap,
        // nowhere near either resting point.
        await gesture.moveBy(const Offset(-164, 0));
        await tester.pump();

        final frontMidDrag = cardSize(tester, 0).width;
        final nextMidDrag = cardSize(tester, 1).width;

        // The outgoing card (0) has shrunk from its full size, but
        // hasn't reached peek size yet.
        expect(frontMidDrag, lessThan(frontAtRest));
        expect(frontMidDrag, greaterThan(frontAtRest * postCardPeekScale));
        // The incoming card (1) has grown from peek size, but hasn't
        // reached full size yet.
        expect(nextMidDrag, greaterThan(nextAtRest));
        expect(nextMidDrag, lessThan(nextAtRest / postCardPeekScale));

        await gesture.up();
        await tester.pumpAndSettle();
      });

      // Both tests below read every card ListView still has built,
      // indexed into *that* set rather than into [urls]: once card 0 is
      // scrolled far enough past the viewport (plus ListView's own
      // cache extent), it is disposed outright rather than merely
      // shrunk, so "the second built ClipRRect" is not reliably "index
      // 1" once earlier cards start dropping out of the tree.
      List<double> builtWidths(WidgetTester tester) {
        final count = find.byType(ClipRRect).evaluate().length;
        return [for (var i = 0; i < count; i++) cardSize(tester, i).width];
      }

      testWidgets(
          'after settling on the next card, exactly one built card is '
          'full size and the rest have receded', (tester) async {
        await pumpRow(tester);

        await tester.drag(
          find.byType(PostImageCarousel),
          const Offset(-220, 0),
        );
        await tester.pumpAndSettle();

        const fullSize = 400 * postCardWidthFraction;
        final widths = builtWidths(tester);
        expect(widths.where((w) => (w - fullSize).abs() < 0.5).length, 1);
        // Not necessarily the flat peek floor for every one of them:
        // WYN-111 fix's left-peek reservation means the card already
        // scrolled past can sit at a different distance-from-front than
        // one still ahead (see post_media.dart's _leadingPeekFor) --
        // what must still hold is that every other built card has
        // receded at least some, and never past the peek floor.
        for (final w in widths.where((w) => (w - fullSize).abs() >= 0.5)) {
          expect(w, lessThan(fullSize));
          expect(w, greaterThanOrEqualTo(fullSize * postCardPeekScale - 0.5));
        }
      });

      testWidgets(
          'a flick past several cards leaves one card clearly larger '
          'than the rest', (tester) async {
        await pumpRow(tester);

        await tester.fling(
          find.byType(PostImageCarousel),
          const Offset(-1200, 0),
          8000,
        );
        await tester.pumpAndSettle();

        // Not "exactly 82%": the *last* card's rest position is
        // wherever BouncingScrollPhysics settles back to after the
        // fling's overscroll (there is no further card to peek at, so
        // the row doesn't reserve that trailing space) -- not
        // necessarily a clean multiple of [stride], so its
        // distance-from-front is a little short of 0 and its scale a
        // little short of 1. What must still hold: it reads clearly
        // bigger than whatever else is still built, the same "one
        // card, not a wall of identical photos" result a reader
        // actually sees.
        final widths = builtWidths(tester)..sort();
        expect(widths.length, greaterThanOrEqualTo(2));
        expect(widths.last, greaterThan(widths[widths.length - 2] + 5));
      });
    });

    // Founder, 2026-09-05, watching this play back live: "เห็นสีขาว ตรง
    // รูปแรกไหม" -- a gap of bare white opened up between the front card
    // and the one peeking in next. Transform.scale's default alignment
    // (center) shrinks a card in from *both* edges, so a peeking card
    // -- laid out flush against its neighbour -- visibly pulled away
    // from it as it receded, instead of hugging up against it the way
    // Threads' cards do.
    group('WYN-111 fix: a peeking card hugs the front card', () {
      testWidgets(
          'at rest, the gap between the front card and the one peeking '
          'in next is only the row\'s own small gap -- not that plus '
          'half the shrink', (tester) async {
        await pumpRow(tester);

        final front = tester.getRect(find.byType(ClipRRect).at(0));
        final peek = tester.getRect(find.byType(ClipRRect).at(1));

        // WynSpacing.space2 (8) is the Padding this row already puts
        // between cards -- the defect added roughly half of the
        // peeking card's own shrink (cardWidth * (1 - 0.86) / 2, tens
        // of pixels) on top of that.
        expect(peek.left - front.right, closeTo(8, 0.5));
      });

      testWidgets(
          'after settling on the middle card, every still-built pair of '
          'neighbouring cards hugs with no extra gap between them',
          (tester) async {
        await pumpRow(tester);
        await tester.drag(
            find.byType(PostImageCarousel), const Offset(-336, 0));
        await tester.pumpAndSettle();

        // Index-agnostic, same discipline as builtWidths() above: a
        // card scrolled far enough behind the viewport (further back
        // than ListView's own cache extent) is disposed outright, not
        // just shrunk, so this checks whatever pairs of cards are
        // still built rather than assuming specific indices survive.
        final rects = [
          for (final e in find.byType(ClipRRect).evaluate())
            tester.getRect(find.byWidget(e.widget)),
        ]..sort((a, b) => a.left.compareTo(b.left));

        expect(rects.length, greaterThanOrEqualTo(2));
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].left - rects[i - 1].right, closeTo(8, 0.5));
        }
      });
    });

    // Founder, 2026-09-05: "รูปสุดท้าย ควรเลื่อน จนสุดเป็นสีขาว" -- dragging
    // past the last (or before the first) card should rubber-band and
    // reveal plain white, the way Threads does, instead of stopping
    // dead. ClampingScrollPhysics (Android-style hard stop) was the
    // parent physics on every platform, silencing that everywhere.
    group('WYN-111 fix: the row rubber-bands past either end', () {
      testWidgets(
          'dragging past the last card overscrolls instead of '
          'stopping dead at it', (tester) async {
        final scrollable = await pumpRow(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PostImageCarousel)),
        );
        // Past the last card's own resting position (2 * stride = 672)
        // by a further 200 -- ClampingScrollPhysics would hold pixels
        // at maxScrollExtent exactly; BouncingScrollPhysics lets it
        // overscroll past that, further with every extra pixel dragged.
        await gesture.moveBy(const Offset(-900, 0));
        await tester.pump();

        expect(
          scrollable.position.pixels,
          greaterThan(scrollable.position.maxScrollExtent + 5),
        );

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets(
          'dragging before the first card overscrolls instead of '
          'stopping dead at it', (tester) async {
        final scrollable = await pumpRow(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PostImageCarousel)),
        );
        await gesture.moveBy(const Offset(200, 0));
        await tester.pump();

        expect(scrollable.position.pixels, lessThan(-5));

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    // Founder, 2026-09-05, on the deployed carousel: "ในรูป คือรูปที่2
    // ทำไมรูปแรกที่เลื่อนผ่าน ไม่ให้เห็นรูปแรกด้วย แบบโผล่มา" -- centered on
    // the 2nd photo, the 1st (already scrolled past) showed nothing at
    // all, not even a sliver, unlike the next photo which always peeked
    // in on the right. A plain ListView shows nothing before the
    // current scroll offset by definition, and the row used to settle
    // exactly on a card's own flush position -- leaving zero pixels of
    // the previous card inside the visible window. post_media.dart's
    // _leadingPeekFor fixes this by resting short of that flush
    // position instead, on purpose, for every card but the first.
    group(
        'WYN-111 fix: a card already scrolled past keeps peeking on '
        'the left, not just the one still ahead', () {
      testWidgets(
          'settled on the middle card of a longer row, both the '
          'previous and the next card are visible, not just the next',
          (tester) async {
        await pumpWidget4(tester);

        await tester.drag(
          find.byType(PostImageCarousel),
          const Offset(-336, 0),
        );
        await tester.pumpAndSettle();

        // Card 0 must still be a real, built, visibly-sized widget --
        // not absent (findsNothing) and not a zero/near-zero sliver
        // that happens to technically satisfy "some rect exists". Not
        // asserted equal to card 2's own peek width: card 0 is the one
        // card this fix never shifts the *scale* reference for (see
        // post_media.dart's _leadingPeekFor -- it keeps giving its full
        // slack to the one card ahead of it, same as before this fix),
        // so the two peeks are not necessarily the same size, only both
        // visible.
        expect(find.byType(ClipRRect), findsNWidgets(3));
        final prev = tester.getRect(find.byType(ClipRRect).at(0));
        const fullSize = 400 * postCardWidthFraction;

        expect(prev.width, greaterThan(10));
        expect(prev.width, lessThan(fullSize));
      });
    });
  });
}

Future<void> pumpWidget4(WidgetTester tester) async {
  const urls = [
    'https://example.supabase.co/drops/d1_0.jpg',
    'https://example.supabase.co/drops/d1_1.jpg',
    'https://example.supabase.co/drops/d1_2.jpg',
    'https://example.supabase.co/drops/d1_3.jpg',
  ];
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 400, child: PostImageCarousel(imageUrls: urls)),
    ),
  ));
  await tester.pumpAndSettle();
  tester.takeException();
}
