import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_recommendation_section.dart';

import 'support/recording_discovery_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_follow_request_repository.dart';
import 'support/recording_profile_repository.dart';

void main() {
  late RecordingDiscoveryRepository discoveryRepository;
  late RecordingFollowRepository followRepository;
  late RecordingFollowRequestRepository followRequestRepository;
  late RecordingProfileRepository profileRepository;

  setUp(() {
    discoveryRepository = RecordingDiscoveryRepository();
    followRepository = RecordingFollowRepository();
    followRequestRepository = RecordingFollowRequestRepository();
    profileRepository = RecordingProfileRepository();
  });

  Widget buildSubject() => MaterialApp(
        home: Scaffold(
          body: ProfileRecommendationSection(
            discoveryRepository: discoveryRepository,
            followRepository: followRepository,
            followRequestRepository: followRequestRepository,
            profileRepository: profileRepository,
          ),
        ),
      );

  testWidgets('renders nothing while there are no suggestions',
      (tester) async {
    discoveryRepository.suggestedUsers = [];

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('แนะนำสำหรับคุณ'), findsNothing);
  });

  testWidgets('shows each suggested profile as a card', (tester) async {
    discoveryRepository.suggestedUsers = [
      const Profile(id: 'u1', username: 'alice', displayName: 'Alice A'),
      const Profile(id: 'u2', username: 'bob'),
    ];

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('แนะนำสำหรับคุณ'), findsOneWidget);
    expect(find.text('Alice A'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);
    // bob has no displayName -- Profile.nameOrUsername falls back to
    // "@bob" for the name line too (same convention ViewProfileScreen's
    // own header already uses), so "@bob" legitimately renders twice
    // for this one card.
    expect(find.text('@bob'), findsNWidgets(2));
  });

  testWidgets('tapping X removes the card and calls dismissSuggestedUser',
      (tester) async {
    discoveryRepository.suggestedUsers = [
      const Profile(id: 'u1', username: 'alice', displayName: 'Alice A'),
      const Profile(id: 'u2', username: 'bob', displayName: 'Bob B'),
    ];

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('@alice'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('@alice'), findsNothing);
    expect(find.text('@bob'), findsOneWidget);
    expect(discoveryRepository.dismissedProfileIds, ['u1']);
  });

  testWidgets(
      'a failed dismiss restores the card instead of leaving it hidden',
      (tester) async {
    discoveryRepository.suggestedUsers = [
      const Profile(id: 'u1', username: 'alice', displayName: 'Alice A'),
    ];
    discoveryRepository.dismissSuggestedUserError = Exception('network');

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Alice A'), findsOneWidget);
  });
}
