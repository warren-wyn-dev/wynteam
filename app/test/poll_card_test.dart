import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/presentation/widgets/poll_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final options = ['Pizza', 'Sushi', 'Burger'];
  final future = DateTime.now().toUtc().add(const Duration(days: 1));
  final past = DateTime.now().toUtc().subtract(const Duration(minutes: 1));

  testWidgets('results hidden (not voted, not author, still open) shows '
      'plain options with no percentages', (tester) async {
    await tester.pumpWidget(_wrap(PollCard(
      options: options,
      expiresAt: future,
      myVoteIndex: null,
      totalVotes: null,
      optionCounts: null,
      isOwnPoll: false,
      onVote: (_) {},
    )));

    expect(find.text('Pizza'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('ยังไม่มีใครโหวต'), findsNothing);
    expect(find.textContaining('เหลืออีก'), findsOneWidget);
  });

  testWidgets('results visible shows percentages and highlights my vote',
      (tester) async {
    await tester.pumpWidget(_wrap(PollCard(
      options: options,
      expiresAt: future,
      myVoteIndex: 1,
      totalVotes: 4,
      optionCounts: const [1, 3, 0],
      isOwnPoll: false,
      onVote: (_) {},
    )));

    expect(find.text('25%'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.textContaining('4 โหวต'), findsOneWidget);
  });

  testWidgets('tapping an option calls onVote with its index',
      (tester) async {
    int? votedIndex;
    await tester.pumpWidget(_wrap(PollCard(
      options: options,
      expiresAt: future,
      myVoteIndex: null,
      totalVotes: null,
      optionCounts: null,
      isOwnPoll: false,
      onVote: (index) => votedIndex = index,
    )));

    await tester.tap(find.text('Sushi'));
    await tester.pump();

    expect(votedIndex, 1);
  });

  testWidgets('the poll author cannot tap any option', (tester) async {
    int voteCalls = 0;
    await tester.pumpWidget(_wrap(PollCard(
      options: options,
      expiresAt: future,
      myVoteIndex: null,
      totalVotes: 2,
      optionCounts: const [1, 1, 0],
      isOwnPoll: true,
      onVote: (_) => voteCalls++,
    )));

    await tester.tap(find.text('Pizza'), warnIfMissed: false);
    await tester.pump();

    expect(voteCalls, 0);
  });

  testWidgets('a closed poll shows "โพลปิดแล้ว" and cannot be voted on',
      (tester) async {
    int voteCalls = 0;
    await tester.pumpWidget(_wrap(PollCard(
      options: options,
      expiresAt: past,
      myVoteIndex: null,
      totalVotes: 0,
      optionCounts: const [0, 0, 0],
      isOwnPoll: false,
      onVote: (_) => voteCalls++,
    )));

    expect(find.textContaining('โพลปิดแล้ว'), findsOneWidget);

    await tester.tap(find.text('Pizza'), warnIfMissed: false);
    await tester.pump();

    expect(voteCalls, 0);
  });

  testWidgets('zero votes shows "ยังไม่มีใครโหวต" once visible',
      (tester) async {
    await tester.pumpWidget(_wrap(PollCard(
      options: options,
      expiresAt: past,
      myVoteIndex: null,
      totalVotes: 0,
      optionCounts: const [0, 0, 0],
      isOwnPoll: false,
      onVote: (_) {},
    )));

    expect(find.textContaining('ยังไม่มีใครโหวต'), findsOneWidget);
  });
}
