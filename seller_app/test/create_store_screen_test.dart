import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/store/presentation/create_store_screen.dart';

import 'support/recording_seller_repository.dart';

void main() {
  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets.
  late RecordingSellerRepository repository;
  late RecordingSellerRepository failingRepository;

  setUp(() {
    repository = RecordingSellerRepository();
    failingRepository =
        RecordingSellerRepository(createStoreException: Exception('boom'));
  });

  testWidgets('submit button is disabled until a store name is entered',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateStoreScreen(
        sellerRepository: repository,
        onStoreCreated: () {},
      ),
    ));

    final submitButton =
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submitButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'ร้านของฉัน');
    await tester.pump();

    final enabledButton =
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets(
      'submitting creates a store and calls onStoreCreated exactly once',
      (tester) async {
    var onStoreCreatedCalls = 0;

    await tester.pumpWidget(MaterialApp(
      home: CreateStoreScreen(
        sellerRepository: repository,
        onStoreCreated: () => onStoreCreatedCalls++,
      ),
    ));

    await tester.enterText(find.byType(TextField).first, 'ร้านของฉัน');
    await tester.enterText(find.byType(TextField).last, 'คำอธิบายร้าน');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.createStoreCalls, 1);
    expect(repository.createStoreNameArgs.single, 'ร้านของฉัน');
    expect(repository.createStoreDescriptionArgs.single, 'คำอธิบายร้าน');
    expect(onStoreCreatedCalls, 1);
  });

  testWidgets('shows an error message and does not call onStoreCreated '
      'when creation fails', (tester) async {
    var onStoreCreatedCalls = 0;

    await tester.pumpWidget(MaterialApp(
      home: CreateStoreScreen(
        sellerRepository: failingRepository,
        onStoreCreated: () => onStoreCreatedCalls++,
      ),
    ));

    await tester.enterText(find.byType(TextField).first, 'ร้านของฉัน');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('สร้างร้านค้าไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(onStoreCreatedCalls, 0);
  });
}
