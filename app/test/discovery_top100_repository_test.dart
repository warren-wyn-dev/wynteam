import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/search/data/discovery_repository.dart';

import 'support/recording_home_repository.dart';
import 'support/recording_profile_repository.dart';

void main() {
  test('Discovery and Home consume the same authoritative Top100 ordering',
      () async {
    final ordered = [
      HomeFeedItem(
        id: 'sustained',
        contentType: HomeContentType.drop,
        authorId: 'a',
        authorUsername: 'a',
        createdAt: DateTime(2026),
        likeCount: 10,
        commentCount: 2,
        likedByMe: false,
        savedByMe: false,
      ),
      HomeFeedItem(
        id: 'spike',
        contentType: HomeContentType.drop,
        authorId: 'b',
        authorUsername: 'b',
        createdAt: DateTime(2026),
        likeCount: 1000,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      ),
    ];
    final home = RecordingHomeRepository(topContentItems: ordered);
    final discovery = DiscoveryRepository(
      SupabaseClient('https://example.supabase.co', 'test-key'),
      homeRepository: home,
      profileRepository: RecordingProfileRepository(),
    );

    final result = await discovery.fetchTopContent();

    expect(result.map((item) => item.id), ['sustained', 'spike']);
    expect(home.fetchTopContentCalls, 1);
  });
}
