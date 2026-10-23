// ZOKY-121 regression: every store surface uses ZokyStoreSummary.rating
// (a score only with real reviews), like the Home recommended card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/adaptive/zoky_icons.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import 'support/pump_zoky.dart';

const _avgNoReviews = ZokyStoreSummary(
  id: 'a',
  name: 'ร้านทดสอบ',
  isOpen: true,
  deliveryFee: 0,
  ratingAverage: 4.5,
);

const _rated = ZokyStoreSummary(
  id: 'b',
  name: 'ร้านมีรีวิว',
  isOpen: true,
  deliveryFee: 0,
  ratingAverage: 4.5,
  ratingCount: 12,
);

const _new = ZokyStoreSummary(
  id: 'c',
  name: 'ร้านใหม่ทดสอบ',
  isOpen: true,
  deliveryFee: 0,
);

Future<void> _card(WidgetTester tester, ZokyStoreSummary store) =>
    pumpZokyWidget(
      tester,
      Center(
        child: SizedBox(
          width: 180,
          child: ZokyStoreCard(store: store, onTap: () {}),
        ),
      ),
    );

String _cardLabel(WidgetTester tester) =>
    tester.getSemantics(find.byType(ZokyStoreCard)).label;

void main() {
  testWidgets('grid card: average without reviews -> no score, no star, '
      'not announced', (tester) async {
    final semantics = tester.ensureSemantics();
    await _card(tester, _avgNoReviews);
    expect(find.textContaining('4.5'), findsNothing);
    expect(find.byIcon(ZokyIcons.star), findsNothing);
    expect(_cardLabel(tester), isNot(contains('คะแนน')));
    semantics.dispose();
  });

  testWidgets('grid card: rated store shows star, score and count', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _card(tester, _rated);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('(12)'), findsOneWidget);
    expect(find.byIcon(ZokyIcons.star), findsOneWidget);
    expect(_cardLabel(tester), contains('คะแนน 4.5'));
    semantics.dispose();
  });

  testWidgets('grid card: new store keeps "ร้านใหม่" without a star', (
    tester,
  ) async {
    await _card(tester, _new);
    expect(find.text(ZokyStrings.newStore), findsOneWidget);
    expect(find.byIcon(ZokyIcons.star), findsNothing);
  });

  testWidgets('StoreScreen: rated store shows the score', (tester) async {
    await pumpZokyWidget(
      tester,
      StoreScreen(store: _rated, repository: DemoStoreRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('★ 4.5'), findsOneWidget);
  });

  testWidgets('StoreScreen: new store keeps "ร้านใหม่"', (tester) async {
    await pumpZokyWidget(
      tester,
      StoreScreen(store: _new, repository: DemoStoreRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.newStore), findsOneWidget);
  });
}
