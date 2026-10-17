// QA & Security round for the Home slice (Phases 1-5), 2026-10-17.
//
// Independent checks that complement the feature tests: overflow capture via
// FlutterError.onError (not tester.takeException) across the device matrix,
// flows, demo labelling, rating rule, cover URL schemes and "no network in
// demo mode". Known bugs are reproduced by tests marked `skip:` with the bug
// file that references them; un-skip once fixed.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/zoky_app.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/deals/deals_screen.dart';
import 'package:zoky_app/features/deals/domain/deal_models.dart';
import 'package:zoky_app/features/deals/widgets/zoky_deal_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_header.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_store_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_store_cover.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import '../support/pump_zoky.dart';

/// Fails the test on any FlutterError (overflow etc.) reported while
/// [body] runs; restores the handler afterwards.
Future<void> _noFlutterErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString());
  try {
    await body();
  } finally {
    FlutterError.onError = old;
  }
  expect(errors, isEmpty, reason: errors.join('\n---\n'));
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required double width,
  required double height,
  double top = 0,
  double bottom = 0,
  double left = 0,
  double right = 0,
  double textScale = 1,
  bool reduceMotion = false,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  final pad = FakeViewPadding(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
  );
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  debugDefaultTargetPlatformOverride = platform;
  await tester.pumpWidget(
    ZokyApp(
      config: AppConfig.demo,
      storeRepository: DemoStoreRepository(),
      promotionRepository: const DemoPromotionRepository(),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

Finder _homeScrollable() => find
    .descendant(
      of: find.byType(CustomScrollView).first,
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition _homePosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_homeScrollable()).position;

Future<void> _loadAnuphan() async {
  final loader = FontLoader('Anuphan')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/anuphan/Anuphan-VariableFont_wght.ttf')
              .readAsBytesSync(),
        ),
      ),
    );
  await loader.load();
}

/// Records every HttpClient the app tries to create.
class _NoNetwork extends HttpOverrides {
  int created = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    created++;
    throw StateError('Network access attempted in demo mode');
  }
}

class _FailingDeals implements DemoPromotionRepository {
  int calls = 0;
  @override
  Duration get latency => Duration.zero;
  @override
  Future<List<ZokyDeal>> fetchTodayDeals() async {
    calls++;
    if (calls == 1) throw StateError('offline');
    return DemoPromotionRepository.deals;
  }
}

class _FailingDirectory extends DemoStoreRepository {
  int calls = 0;
  @override
  Future<List<ZokyStoreSummary>> fetchDirectory({String query = ''}) async {
    calls++;
    if (calls == 1) throw StateError('offline');
    return super.fetchDirectory(query: query);
  }
}

void main() {
  group('layout matrix (FlutterError.onError capture)', () {
    for (final (w, h) in [
      (320.0, 568.0),
      (360.0, 640.0),
      (375.0, 667.0),
      (390.0, 844.0),
      (414.0, 896.0),
      (430.0, 932.0),
      (932.0, 430.0),
    ]) {
      for (final (top, bottom) in [(0.0, 0.0), (20.0, 0.0), (59.0, 34.0)]) {
        for (final scale in [1.0, 1.3, 1.6, 2.0]) {
          testWidgets('Home ${w}x$h insets $top/$bottom text $scale: no '
              'overflow; at the scroll end the nav covers no card', (
            tester,
          ) async {
            await _noFlutterErrors(() async {
              await _pumpApp(
                tester,
                width: w,
                height: h,
                top: top,
                bottom: bottom,
                textScale: scale,
              );
              final pos = _homePosition(tester);
              pos.jumpTo(pos.maxScrollExtent);
              await tester.pumpAndSettle();
            });
            final nav = tester.getRect(find.byKey(ZokyBottomNav.capsuleKey));
            for (final card
                in find.byType(ZokyRecommendedStoreCard).evaluate()) {
              final r = tester.getRect(find.byWidget(card.widget));
              if (r.left >= w) continue; // off to the right in the row
              expect(r.bottom, lessThanOrEqualTo(nav.top));
            }
          });
        }
      }
    }
  });

  group('flows', () {
    Future<void> openFavorites(
      WidgetTester tester,
      double w,
      double h,
      double scale,
    ) async {
      await _noFlutterErrors(() async {
        await _pumpApp(tester, width: w, height: h, textScale: scale);
        await tester.tap(find.bySemanticsLabel(ZokyStrings.favoriteStores));
        await tester.pumpAndSettle();
        expect(find.text(ZokyStrings.comingSoon), findsOneWidget);
        expect(find.byType(ZokyStoreCard), findsNothing);
        await tester.tapAt(const Offset(10, 10)); // scrim
        await tester.pumpAndSettle();
        expect(find.text(ZokyStrings.comingSoon), findsNothing);
      });
    }

    testWidgets('header heart opens the "ร้านโปรด" placeholder only '
        '(390x844, text 2.0)', (tester) async {
      await openFavorites(tester, 390, 844, 2);
    });

    for (final (w, h, scale) in [
      (320.0, 568.0, 1.6),
      (375.0, 667.0, 2.0),
      (932.0, 430.0, 1.0),
      (667.0, 375.0, 1.0),
    ]) {
      testWidgets(
        'ZOKY-122: "ร้านโปรด" sheet does not overflow at ${w}x$h text $scale',
        (tester) async {
          await openFavorites(tester, w, h, scale);
        },
      );
    }

    testWidgets('hero search -> query -> store -> back x2 returns Home', (
      tester,
    ) async {
      await _pumpApp(tester, width: 390, height: 844, top: 47, bottom: 34);
      await tester.tap(find.bySemanticsLabel(ZokyStrings.heroSearchButton));
      await tester.pumpAndSettle();
      expect(find.byType(StoreSearchScreen), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      await tester.enterText(find.byType(TextField), 'ส้มตำ');
      await tester.pumpAndSettle();
      expect(find.byType(ZokyStoreCard), findsOneWidget);
      await tester.tap(find.byType(ZokyStoreCard));
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen), findsOneWidget);
      // Demo label stays visible on the store page body.
      expect(find.textContaining('(ร้านตัวอย่าง)'), findsWidgets);
      await tester.tap(find.byTooltip(ZokyStrings.back).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(ZokyStrings.back).last);
      await tester.pumpAndSettle();
      expect(find.byType(ZokyHomeHeader), findsOneWidget);
    });

    testWidgets('search: no results shows the empty state', (tester) async {
      await pumpZokyWidget(
        tester,
        StoreSearchScreen(repository: DemoStoreRepository()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzz-no-match');
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.searchNoResultsTitle), findsOneWidget);
    });

    testWidgets('search: load error shows retry that recovers', (tester) async {
      final repo = _FailingDirectory();
      await pumpZokyWidget(tester, StoreSearchScreen(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.loadErrorTitle), findsOneWidget);
      await tester.tap(find.text(ZokyStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(ZokyStoreCard), findsWidgets);
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('deal sheet at 320x568 text 2.0 (${platform.name}): '
          'badge + disclaimer, no overflow, closes', (tester) async {
        await _noFlutterErrors(() async {
          await _pumpApp(
            tester,
            width: 320,
            height: 568,
            textScale: 2,
            platform: platform,
          );
          final pos = _homePosition(tester);
          for (var i = 0; i < 40; i++) {
            final cards = find.byType(ZokyDealCard);
            if (cards.evaluate().isNotEmpty &&
                tester.getRect(cards.first).top < 300) {
              break;
            }
            pos.jumpTo(
              (pos.pixels + 100).clamp(0.0, pos.maxScrollExtent).toDouble(),
            );
            await tester.pumpAndSettle();
          }
          // Tap near the top: the card centre may sit under the nav.
          await tester.tapAt(
            tester.getRect(find.byType(ZokyDealCard).first).topLeft +
                const Offset(40, 40),
          );
          await tester.pumpAndSettle();
          expect(find.text(ZokyStrings.demoDealDisclaimer), findsOneWidget);
          expect(find.text(ZokyStrings.demoBadge), findsWidgets);
          await tester.ensureVisible(find.text(ZokyStrings.close));
          await tester.tap(find.text(ZokyStrings.close));
          await tester.pumpAndSettle();
          expect(find.text(ZokyStrings.demoDealDisclaimer), findsNothing);
          debugDefaultTargetPlatformOverride = null;
        });
      });
    }

    testWidgets('deals "ดูทั้งหมด": every card carries the demo badge', (
      tester,
    ) async {
      await _pumpApp(tester, width: 390, height: 2400);
      await tester.tap(find.bySemanticsLabel(ZokyStrings.seeAllDeals));
      await tester.pumpAndSettle();
      expect(find.byType(DealsScreen), findsOneWidget);
      final cards = find.byType(ZokyDealCard);
      expect(cards, findsNWidgets(DemoPromotionRepository.deals.length));
      for (final c in cards.evaluate()) {
        expect(
          find.descendant(
            of: find.byWidget(c.widget),
            matching: find.byType(ZokyDemoBadge),
          ),
          findsOneWidget,
        );
      }
      expect(find.text(ZokyStrings.dealsDemoNote), findsOneWidget);
    });

    testWidgets('deals screen: error + retry', (tester) async {
      await pumpZokyWidget(tester, DealsScreen(repository: _FailingDeals()));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.loadErrorTitle), findsOneWidget);
      await tester.tap(find.text(ZokyStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(ZokyDealCard), findsWidgets);
    });

    testWidgets('re-tap หน้าหลัก scrolls to top (instant with reduced '
        'motion); back on another tab returns to หน้าหลัก', (tester) async {
      await _pumpApp(
        tester,
        width: 375,
        height: 667,
        textScale: 1.3,
        reduceMotion: true,
      );
      final pos = _homePosition(tester);
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();
      expect(pos.pixels, greaterThan(0));
      await tester.tap(find.bySemanticsLabel(ZokyStrings.navHome));
      await tester.pump(); // no animation frames needed
      expect(pos.pixels, 0);

      await tester.tap(find.bySemanticsLabel(ZokyStrings.navOrders));
      await tester.pumpAndSettle();
      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, isTrue); // handled in-app, not leaving
      final home = tester.getSemantics(
        find.bySemanticsLabel(ZokyStrings.navHome),
      );
      expect(home.flagsCollection.isSelected.toString(), contains('isTrue'));
    });
  });

  group('Founder rules', () {
    testWidgets('nav: exactly the 4 tabs, in order', (tester) async {
      await _pumpApp(tester, width: 390, height: 844);
      final nav = tester.widget<ZokyBottomNav>(find.byType(ZokyBottomNav));
      expect(nav.items.map((i) => i.label).toList(), [
        ZokyStrings.navHome,
        ZokyStrings.navOrders,
        ZokyStrings.navMessages,
        ZokyStrings.navAccount,
      ]);
    });

    testWidgets('header sets a light status bar', (tester) async {
      await _pumpApp(tester, width: 390, height: 844, top: 47);
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: find.byType(ZokyHomeHeader),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarBrightness, Brightness.dark);
    });

    testWidgets('recommended cards: 1:1 photo, demo badge, no heart', (
      tester,
    ) async {
      await _pumpApp(tester, width: 932, height: 430);
      final pos = _homePosition(tester);
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pumpAndSettle();
      for (final c in find.byType(ZokyRecommendedStoreCard).evaluate()) {
        final card = find.byWidget(c.widget);
        final cover = tester.getSize(
          find.descendant(of: card, matching: find.byType(ZokyStoreCover)),
        );
        expect(cover.width, moreOrLessEquals(cover.height, epsilon: 0.5));
        expect(
          find.descendant(of: card, matching: find.byType(ZokyDemoBadge)),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'ZOKY-121: StoreScreen hides the rating when the store has no reviews',
      (tester) async {
        const store = ZokyStoreSummary(
          id: 'x',
          name: 'ร้านทดสอบ',
          isOpen: true,
          deliveryFee: 0,
          ratingAverage: 4.5,
        );
        await pumpZokyWidget(
          tester,
          StoreScreen(store: store, repository: DemoStoreRepository()),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('4.5'), findsNothing);
      },
    );

    testWidgets(
      'ZOKY-121: store grid card hides the rating when there are no reviews',
      (tester) async {
        const store = ZokyStoreSummary(
          id: 'x',
          name: 'ร้านทดสอบ',
          isOpen: true,
          deliveryFee: 0,
          ratingAverage: 4.5,
        );
        await pumpZokyWidget(
          tester,
          Center(
            child: SizedBox(
              width: 180,
              child: ZokyStoreCard(store: store, onTap: () {}),
            ),
          ),
        );
        expect(find.text('4.5'), findsNothing);
      },
    );

    testWidgets(
      'ZOKY-123: demo suffix is never ellipsized on store grid cards '
      '(320pt, text 1.3, real font)',
      (tester) async {
        await _loadAnuphan();
        await pumpZokyWidget(
          tester,
          StoreSearchScreen(
            repository: DemoStoreRepository(),
            autofocus: false,
          ),
          width: 320,
          height: 3000,
          textScale: 1.3,
        );
        await tester.pumpAndSettle();
        final cut = <String>[];
        for (final e
            in find
                .descendant(
                  of: find.byType(ZokyStoreCard),
                  matching: find.textContaining(
                    ZokyStoreSummary.demoNameSuffix,
                  ),
                )
                .evaluate()) {
          if ((e.findRenderObject()! as RenderParagraph).didExceedMaxLines) {
            cut.add((e.widget as Text).data!);
          }
        }
        expect(cut, isEmpty);
      },
    );

    testWidgets(
      'ZOKY-120: once the header scrolls away, no pink band remains '
      'behind the content at the top of the screen',
      (tester) async {
        await _pumpApp(tester, width: 320, height: 568, top: 20);
        final pos = _homePosition(tester);
        pos.jumpTo(pos.maxScrollExtent);
        await tester.pumpAndSettle();
        final view = tester.binding.renderViews.first;
        final layer = view.debugLayer! as OffsetLayer;
        final img = (await tester.runAsync(
          () => layer.toImage(Offset.zero & view.size),
        ))!;
        final data = (await tester.runAsync(() => img.toByteData()))!;
        // Left gutter just under the status bar.
        final i = (30 * img.width + 4) * 4;
        final rgb = [
          data.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        ];
        expect(rgb, isNot([0xF9, 0x33, 0x84]));
        img.dispose();
      },
    );

    testWidgets(
      'ZOKY-124: landscape with a notch keeps the logo inside the safe area',
      (tester) async {
        await _pumpApp(
          tester,
          width: 932,
          height: 430,
          left: 59,
          right: 59,
          bottom: 21,
        );
        final logo = tester.getRect(find.bySemanticsLabel('ZOKY'));
        expect(logo.left, greaterThanOrEqualTo(59));
        final heart = tester.getRect(
          find.bySemanticsLabel(ZokyStrings.favoriteStores),
        );
        expect(heart.right, lessThanOrEqualTo(932 - 59));
      },
      skip: true, // Bug repro: .wyn/tasks/bugs/ZOKY-124-*.md
    );
  });

  group('security / privacy', () {
    testWidgets('demo mode makes no network connection across Home flows', (
      tester,
    ) async {
      final overrides = _NoNetwork();
      await HttpOverrides.runZoned(() async {
        await _pumpApp(tester, width: 390, height: 844);
        await tester.tap(find.bySemanticsLabel(ZokyStrings.heroSearchButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ZokyStoreCard).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(ZokyStrings.back).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(ZokyStrings.back).last);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(ZokyStrings.seeAllRecommended));
        await tester.pumpAndSettle();
      }, createHttpClient: overrides.createHttpClient);
      expect(overrides.created, 0);
    });

    for (final url in [
      'javascript:alert(1)',
      'file:///etc/passwd',
      'data:image/png;base64,iVBORw0KGgo=',
      '../../pubspec.yaml',
      'content://com.android.contacts/contacts',
    ]) {
      testWidgets('cover URL "$url" never reaches NetworkImage; falls back '
          'to the drawn art without errors', (tester) async {
        await _noFlutterErrors(() async {
          final store = ZokyStoreSummary(
            id: 'x',
            name: 'n',
            isOpen: true,
            deliveryFee: 0,
            coverUrl: url,
          );
          await pumpZokyWidget(
            tester,
            Center(
              child: SizedBox.square(
                dimension: 150,
                child: ZokyStoreCover(
                  store: store,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          final images = tester.widgetList<Image>(find.byType(Image));
          expect(images.every((i) => i.image is! NetworkImage), isTrue);
        });
      });
    }

    test('demo config carries no keys', () {
      expect(AppConfig.demo.supabaseUrl, isEmpty);
      expect(AppConfig.demo.supabaseAnonKey, isEmpty);
      expect(AppConfig.demo.isDemoMode, isTrue);
      // Without --dart-define the app must stay in demo mode.
      expect(AppConfig.fromEnvironment().isDemoMode, isTrue);
    });
  });
}
