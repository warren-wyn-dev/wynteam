import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/screens/merchant_home.dart';
import 'package:zoky_merchant/widgets/merchant_tool_icon.dart';

import 'support/fake_repository.dart';

class _HeldRepository extends FakeRepository {
  final pendingStores = Completer<List<Json>>();
  final pendingReport = Completer<Json>();

  @override
  Future<List<Json>> stores() => pendingStores.future;

  @override
  Future<Json> report(String id) => pendingReport.future;
}

class _HeldAtlasBundle extends CachingAssetBundle {
  final atlas = Completer<ByteData>();
  int atlasLoads = 0;

  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/brand/merchant-tools-3d.webp') {
      atlasLoads++;
      return atlas.future;
    }
    return rootBundle.load(key);
  }
}

class _ImageClient implements HttpClient {
  final requested = <Uri>[];
  final responses = <String, Completer<HttpClientResponse>>{};

  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    requested.add(uri);
    return _ImageRequest(
      responses.putIfAbsent(uri.toString(), Completer.new).future,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.response);
  final Future<HttpClientResponse> response;

  @override
  Future<HttpClientResponse> close() => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes, {this.statusCode = HttpStatus.ok});
  final List<int> bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(
  MerchantRepository repository,
  VoidCallback onReady, {
  AssetBundle? bundle,
}) {
  final app = ZokyApp(
    home: MerchantHome(
      repository: repository,
      onSignOut: () async {},
      onInitialContentReady: onReady,
    ),
  );
  return bundle == null ? app : DefaultAssetBundle(bundle: bundle, child: app);
}

void main() {
  testWidgets(
    'initial readiness waits for critical content, not secondary reports',
    (tester) async {
      final repository = _HeldRepository();
      var ready = 0;
      await tester.pumpWidget(_app(repository, () => ready++));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('merchant-store-loading')),
        findsOneWidget,
      );
      expect(find.text('ออกจากระบบ'), findsNothing);
      expect(ready, 0);

      repository.pendingStores.complete(repository.storeRows);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('merchant-store-loading')),
        findsNothing,
      );
      expect(find.text('ร้านทดสอบ'), findsOneWidget);
      expect(find.text('กำลังโหลดยอดขาย'), findsOneWidget);
      expect(repository.pendingReport.isCompleted, isFalse);
      expect(ready, 1);

      await tester.pump(const Duration(milliseconds: 100));
      expect(ready, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      repository.pendingReport.complete({});
    },
  );

  for (final fail in [false, true]) {
    testWidgets('terminal ${fail ? 'error' : 'no-store'} can leave startup', (
      tester,
    ) async {
      final repository = _HeldRepository();
      var ready = 0;
      await tester.pumpWidget(_app(repository, () => ready++));
      expect(ready, 0);
      if (fail) {
        repository.pendingStores.completeError(Exception('offline'));
      } else {
        repository.pendingStores.complete([]);
      }
      await tester.pumpAndSettle();
      expect(ready, 1);
      expect(
        find.byKey(const ValueKey('merchant-store-loading')),
        findsNothing,
      );
      expect(find.text('ออกจากระบบ'), findsOneWidget);
      if (!fail) {
        expect(find.text('ไม่พบร้านที่บัญชีนี้มีสิทธิ์จัดการ'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('old repository completion cannot signal a new account ready', (
    tester,
  ) async {
    final before = _HeldRepository();
    final after = _HeldRepository();
    var ready = 0;
    await tester.pumpWidget(_app(before, () => ready++));
    await tester.pumpWidget(_app(after, () => ready++));
    before.pendingStores.complete(before.storeRows);
    await tester.pump();
    expect(ready, 0);
    expect(
      find.byKey(const ValueKey('merchant-store-loading')),
      findsOneWidget,
    );
    after.pendingStores.complete([]);
    await tester.pumpAndSettle();
    expect(ready, 1);
    expect(find.text('ร้านทดสอบ'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('atlas warms while store is pending and failure stays usable', (
    tester,
  ) async {
    final bundle = _HeldAtlasBundle();
    final repository = _HeldRepository();
    var ready = 0;
    await tester.pumpWidget(_app(repository, () => ready++, bundle: bundle));
    await tester.pump();
    expect(bundle.atlasLoads, 1);
    expect(find.byType(MerchantToolIcon), findsNothing);

    repository.pendingStores.complete(repository.storeRows);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ready, 1);
    expect(bundle.atlasLoads, 1);
    final pending = find.byKey(const ValueKey('merchant-tool-placeholder'));
    expect(pending, findsWidgets);
    expect(
      find.descendant(of: pending, matching: find.byType(Icon)),
      findsNothing,
    );

    bundle.atlas.completeError(Exception('image unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final fallback = tester.widget<Icon>(
      find.descendant(of: pending, matching: find.byType(Icon)).first,
    );
    expect(fallback.color, const Color(0xFFD61256));
    expect(ready, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.pendingReport.complete({});
  });

  testWidgets('menu keeps its placeholder and row position through fallback', (
    tester,
  ) async {
    final client = _ImageClient();
    final previous = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => client;
    addTearDown(() => debugNetworkImageHttpClientProvider = previous);
    try {
      final repository = FakeRepository();
      repository.menuRows.first.addAll({
        'image_url': 'https://example.invalid/food-original.png',
        'image_thumbnail_url': 'https://example.invalid/food-thumbnail.png',
      });
      await tester.pumpWidget(_app(repository, () {}));
      await tester.pumpAndSettle();
      expect(client.requested, isEmpty);
      final dynamic state = tester.state(find.byType(MerchantHome));
      state.navigate(2);
      await tester.pumpAndSettle();
      final before = tester.getRect(find.text('ข้าวกะเพรา'));
      final placeholder = find.byKey(
        const ValueKey('merchant-menu-image-placeholder'),
      );
      expect(placeholder, findsOneWidget);
      expect(tester.getSize(placeholder), const Size(64, 64));
      expect(client.requested.map((uri) => uri.path), ['/food-thumbnail.png']);

      client.responses.values.first.complete(
        _ImageResponse([], statusCode: HttpStatus.notFound),
      );
      await tester.pumpAndSettle();
      expect(placeholder, findsOneWidget);
      expect(tester.getRect(find.text('ข้าวกะเพรา')), before);
      expect(client.requested.map((uri) => uri.path), [
        '/food-thumbnail.png',
        '/food-original.png',
      ]);

      final bytes = await tester.runAsync(
        () => rootBundle.load('assets/brand/zoky-logo-pink-transparent.png'),
      );
      client.responses.values.last.complete(
        _ImageResponse(bytes!.buffer.asUint8List()),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(placeholder, findsNothing);
      expect(tester.getRect(find.text('ข้าวกะเพรา')), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugNetworkImageHttpClientProvider = previous;
    }
  });
}
