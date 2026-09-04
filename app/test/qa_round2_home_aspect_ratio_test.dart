// QA round 2 (2026-09-04) -- written by AI QA & Security, not by AI Coding.
//
// Covers the work added after QA round 1 that had never been tested:
// HomeRepository._fetchAspectRatios and the index shift it caused in
// _fetchViewerState's Future.wait (results[6]/results[7]).
//
// The interesting risk is that the block-check future is a *conditional*
// element in the list literal, so the two call shapes (with and without
// authorIdsForBlockCheck) produce lists of different lengths and the
// casts that follow are positional. Getting that wrong is a runtime
// type-cast error that no test without a real Supabase client can see --
// so this test brings up a real SupabaseClient pointed at a local
// PostgREST-shaped HTTP server and drives the real public methods.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/drop/data/drop_repository.dart';
import 'package:wyn/features/drop/data/square_crop.dart';
import 'package:wyn/features/home/data/home_repository.dart';

/// A stand-in PostgREST. Answers by path; records every request so the
/// test can assert which queries were and were not issued.
class _FakeRest {
  _FakeRest(this.responses);

  /// path (e.g. 'home_feed', 'rpc/get_poll_results') -> JSON body
  final Map<String, Object?> responses;

  /// Paths that must answer with a 4xx, to exercise failure fallbacks.
  final Set<String> failing = <String>{};

  final List<String> requests = <String>[];

  /// When set, every request body is appended here.
  List<String>? captureBodies;

  late HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      // '/rest/v1/home_feed' -> 'home_feed'
      final path = request.uri.path.replaceFirst('/rest/v1/', '');
      requests.add('${request.method} ${request.uri.path}?${request.uri.query}');
      final body = await utf8.decoder.bind(request).join();
      if (body.isNotEmpty) captureBodies?.add(body);

      request.response.headers.contentType = ContentType.json;
      if (failing.contains(path)) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({
          'code': 'PGRST204',
          'message': 'Could not find the column in the schema cache',
        }));
        await request.response.close();
        return;
      }

      final stub = responses[path];
      if (stub == null) {
        request.response.statusCode = 404;
        request.response
            .write(jsonEncode({'code': '404', 'message': 'no stub for $path'}));
        await request.response.close();
        return;
      }
      request.response.write(jsonEncode(stub));
      await request.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);

  bool asked(String table) =>
      requests.any((r) => r.contains('/rest/v1/$table?') ||
          r.contains('/rest/v1/$table '));
}

Future<SupabaseClient> _signedInClient(String url) async {
  final client = SupabaseClient(url, 'test-anon-key');
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
          1000;
  await client.auth.recoverSession(jsonEncode({
    'access_token': 'fake-access-token',
    'token_type': 'bearer',
    'expires_in': 31536000,
    'expires_at': expiresAt,
    'refresh_token': 'fake-refresh-token',
    'user': {
      'id': 'viewer-1',
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': DateTime.now().toIso8601String(),
    },
  }));
  return client;
}

Map<String, dynamic> _dropRow({
  required String id,
  String? imageUrl = 'https://example.test/a.jpg',
  String contentType = 'drop',
  int? imageCount = 1,
  String authorId = 'author-1',
}) =>
    {
      'id': id,
      'content_type': contentType,
      'author_id': authorId,
      'author_username': 'namfah',
      'author_display_name': 'Namfah',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'caption': 'hello',
      'image_url': imageUrl,
      'image_count': imageCount,
      'like_count': 0,
      'comment_count': 0,
      'redrop_count': 0,
      'view_count': 0,
      'liked_by': <dynamic>[],
    };

void main() {
  // flutter_test's binding installs an HttpOverrides that answers every
  // HTTP request with a bare 400. This test needs real (loopback-only)
  // sockets, so the override is removed for the duration.
  setUpAll(() => HttpOverrides.global = null);

  _FakeRest? rest;
  SupabaseClient? client;
  late HomeRepository repo;

  Future<void> boot(Map<String, Object?> responses) async {
    final server = _FakeRest(responses);
    await server.start();
    rest = server;
    final c = await _signedInClient(server.url);
    client = c;
    repo = HomeRepository(c);
  }

  tearDown(() async {
    await client?.dispose();
    await rest?.stop();
    client = null;
    rest = null;
  });

  // ---------------------------------------------------------------
  // QA-R2-1..4: the Future.wait index shift, both call shapes.
  // ---------------------------------------------------------------

  test(
      'QA-R2-1 fetchFeed (authorIdsForBlockCheck == null) maps results[6] '
      'to the aspect ratios and never reads a 7th slot', () async {
    await boot({
      'home_feed': [
        _dropRow(id: 'd1'),
        _dropRow(id: 'd2'),
      ],
      'drop_likes': [
        {'drop_id': 'd1'},
      ],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
      'drops': [
        {'id': 'd1', 'image_aspect_ratio': '16:9'},
        {'id': 'd2', 'image_aspect_ratio': '1:1'},
      ],
    });

    final items = await repo.fetchFeed(page: 0);

    expect(items, hasLength(2));
    // If results[5]/[6] were transposed this would have thrown a
    // TypeError before reaching here; asserting the values proves the
    // right future landed in the right slot rather than merely that
    // nothing threw.
    expect(items[0].aspectRatio, DropAspectRatio.landscape);
    expect(items[1].aspectRatio, DropAspectRatio.square);
    expect(items[0].likedByMe, isTrue,
        reason: 'results[0] must still be the Drop likes');
    expect(items[1].likedByMe, isFalse);
    expect(rest!.asked('drops'), isTrue);
  });

  test(
      'QA-R2-2 fetchTrending (authorIdsForBlockCheck != null) maps '
      'results[7] to the block check and still gets ratios from [6]',
      () async {
    await boot({
      'home_feed': [
        _dropRow(id: 'd1', authorId: 'author-1'),
        _dropRow(id: 'd2', authorId: 'sanctioned-author'),
      ],
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
      'drops': [
        {'id': 'd1', 'image_aspect_ratio': '16:9'},
        {'id': 'd2', 'image_aspect_ratio': '16:9'},
      ],
      // The block-check RPC removes the second author entirely.
      'rpc/authors_posting_blocked': [
        {'author_id': 'sanctioned-author'},
      ],
    });

    final items = await repo.fetchTrending();

    // The sanctioned author's row is gone -- which can only happen if
    // results[7] really is the block-check set. If the two were swapped
    // the cast would throw; if the guard were still `length > 6` the
    // ratios map would be cast to Set<String> and throw too.
    expect(items.map((e) => e.id), ['d1']);
    expect(items.single.aspectRatio, DropAspectRatio.landscape);
  });

  test(
      'QA-R2-3 a page whose only sanctioned-author list is empty still '
      'lines up (the RPC is skipped by _fetchPostingBlockedAuthorIds, '
      'not by the list literal)', () async {
    await boot({
      // A page of zero rows: authorIds is an empty *set*, which is not
      // null, so the conditional element is still present.
      'home_feed': <dynamic>[],
    });

    final items = await repo.fetchTrending();
    expect(items, isEmpty);
  });

  test('QA-R2-4 fetchItemById carries the batched ratio for one row',
      () async {
    await boot({
      'home_feed': _dropRow(id: 'd9'), // maybeSingle -> object, not list
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
      'drops': [
        {'id': 'd9', 'image_aspect_ratio': '1:1'},
      ],
    });

    final item = await repo.fetchItemById(id: 'd9');
    expect(item, isNotNull);
    expect(item!.aspectRatio, DropAspectRatio.square);
  });

  // ---------------------------------------------------------------
  // QA-R2-5..9: every fallback path.
  // ---------------------------------------------------------------

  test('QA-R2-5 the drops query failing leaves every card at 4:5, feed intact',
      () async {
    await boot({
      'home_feed': [_dropRow(id: 'd1')],
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
      'drops': <dynamic>[],
    });
    rest!.failing.add('drops');

    final items = await repo.fetchFeed(page: 0);
    expect(items, hasLength(1));
    expect(items.single.aspectRatio, DropAspectRatio.portrait);
  });

  test(
      'QA-R2-6 a database without the column (PGRST204) still renders the '
      'feed at 4:5', () async {
    await boot({
      'home_feed': [_dropRow(id: 'd1')],
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
    });
    // No stub for 'drops' at all -> 404 -> the catch(_) fallback.
    final items = await repo.fetchFeed(page: 0);
    expect(items.single.aspectRatio, DropAspectRatio.portrait);
  });

  test('QA-R2-7 a page with no photo at all issues no drops query',
      () async {
    await boot({
      'home_feed': [
        _dropRow(id: 'd1', imageUrl: null, imageCount: null),
        _dropRow(id: 'd2', imageUrl: null, imageCount: null),
      ],
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
    });

    final items = await repo.fetchFeed(page: 0);
    expect(items, hasLength(2));
    expect(items.every((e) => e.aspectRatio == DropAspectRatio.portrait),
        isTrue);
    expect(rest!.asked('drops'), isFalse,
        reason: 'a text-only page must cost no extra round-trip');
  });

  test('QA-R2-8 a drop the lookup did not answer for falls back to 4:5',
      () async {
    await boot({
      'home_feed': [_dropRow(id: 'd1'), _dropRow(id: 'd2')],
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
      // RLS hid d2 from the direct table read (or it simply is not
      // there): only d1 comes back.
      'drops': [
        {'id': 'd1', 'image_aspect_ratio': '16:9'},
      ],
    });

    final items = await repo.fetchFeed(page: 0);
    expect(items[0].aspectRatio, DropAspectRatio.landscape);
    expect(items[1].aspectRatio, DropAspectRatio.portrait);
  });

  test('QA-R2-9 a junk value stored in the column falls back, never throws',
      () async {
    await boot({
      'home_feed': [_dropRow(id: 'd1')],
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
      'drops': [
        {'id': 'd1', 'image_aspect_ratio': '3:7'},
      ],
    });

    final items = await repo.fetchFeed(page: 0);
    expect(items.single.aspectRatio, DropAspectRatio.portrait);
  });

  // ---------------------------------------------------------------
  // QA-R2-10: the security question -- the lookup must never widen
  // what the mute-filtering view already narrowed.
  // ---------------------------------------------------------------

  test(
      'QA-R2-10 the drops query only ever names ids the view already '
      'returned (a muted author cannot be re-introduced)', () async {
    await boot({
      'home_feed': [_dropRow(id: 'd1')],
      'drop_likes': <dynamic>[],
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
      'redrops': <dynamic>[],
      // The server answers with an id the feed never asked about --
      // standing in for a broken/hostile response.
      'drops': [
        {'id': 'd1', 'image_aspect_ratio': '16:9'},
        {'id': 'muted-drop', 'image_aspect_ratio': '16:9'},
      ],
    });

    final items = await repo.fetchFeed(page: 0);

    final dropsRequest =
        rest!.requests.firstWhere((r) => r.contains('/rest/v1/drops?'));
    expect(dropsRequest, contains('d1'));
    expect(dropsRequest, isNot(contains('muted-drop')));
    // Only two columns are ever selected -- no caption, no author.
    expect(dropsRequest, contains('id%2Cimage_aspect_ratio'));
    // And an extra row in the answer cannot create a card.
    expect(items.map((e) => e.id), ['d1']);
  });

  test('QA-R2-11 a Pop row is never asked about on the drops table',
      () async {
    await boot({
      // content_type 'pop' is filtered out of Home by _hiddenContentType,
      // so use fetchItemById, which does not filter, to prove the
      // content_type guard in _fetchAspectRatios itself.
      'home_feed': _dropRow(
        id: 'p1',
        contentType: 'pop',
        imageUrl: null,
        imageCount: null,
      ),
      'pop_likes': <dynamic>[],
      'saves': <dynamic>[],
    });

    final item = await repo.fetchItemById(id: 'p1');
    expect(item, isNotNull);
    expect(rest!.asked('drops'), isFalse);
  });

  // ---------------------------------------------------------------
  // QA-R2-12..14: B-109-1 at the wire level. The permanent regression
  // test that ships with the fix only greps drop_repository.dart for a
  // string; this one reads the JSON that actually leaves the app.
  // ---------------------------------------------------------------

  group('B-109-1 insert payload', () {
    late _FakeRest rest2;
    late SupabaseClient client2;
    late DropRepository drops;
    final bodies = <String>[];

    setUp(() async {
      bodies.clear();
      rest2 = _FakeRest({});
      rest2.captureBodies = bodies;
      rest2.responses['drops'] = {'id': 'new-drop-1'};
      rest2.responses['drop_mentions'] = <dynamic>[];
      rest2.responses['drop_images'] = <dynamic>[];
      await rest2.start();
      client2 = await _signedInClient(rest2.url);
      drops = DropRepository(client2);
    });

    tearDown(() async {
      await client2.dispose();
      await rest2.stop();
    });

    test('QA-R2-12 a text-only Drop never names image_aspect_ratio',
        () async {
      await drops.createTextDrop(caption: 'สวัสดี');
      expect(bodies, isNotEmpty);
      final payload = jsonDecode(bodies.first) as Map<String, dynamic>;
      expect(payload.containsKey('image_aspect_ratio'), isFalse,
          reason: 'naming the column is what broke every post type when '
              'the database did not have it yet');
      expect(payload['caption'], 'สวัสดี');
    });

    test('QA-R2-13 a Draft republished from an existing URL never names it',
        () async {
      await drops.createDropFromExistingImage(
        imageUrl: 'https://example.test/old.jpg',
        caption: 'draft',
      );
      final payload = jsonDecode(bodies.first) as Map<String, dynamic>;
      expect(payload.containsKey('image_aspect_ratio'), isFalse);
      expect(payload['image_url'], 'https://example.test/old.jpg');
    });

    test('QA-R2-14 a Poll Drop goes through an RPC and names no column',
        () async {
      rest2.responses['rpc/create_poll_drop'] = null;
      // The RPC stub is absent on purpose -- what matters is that the
      // request is a poll RPC, not an insert on `drops`.
      try {
        await drops.createPollDrop(
          question: 'q',
          options: const ['a', 'b'],
          durationDays: 1,
        );
      } catch (_) {
        // A 404 from the stub server; irrelevant to what is asserted.
      }
      expect(rest2.requests.any((r) => r.contains('rpc/create_poll_drop')),
          isTrue);
      expect(rest2.asked('drops'), isFalse);
    });
  });
}
