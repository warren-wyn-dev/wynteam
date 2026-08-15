import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/store/data/store.dart';
import 'package:zoky_seller/features/store/presentation/seller_store_screen.dart';

import 'support/recording_seller_repository.dart';

/// Regression tests for SellerStoreScreen (SELLER-004), per
/// .wyn/docs/design/seller-004-store-management.md, Screen:
/// SellerStoreScreen. Banner/logo pickers aren't tapped -- `ImagePicker`
/// goes through a platform channel this sandbox never mocks, same
/// convention as every other picker in this project (see
/// .wyn/learning/PATTERNS.md); only their presence/pre-fill state is
/// checked here.
void main() {
  final store = Store(
    id: 'store-1',
    ownerId: 'u1',
    name: 'ร้านทดสอบ',
    description: 'คำอธิบายร้าน',
    address: 'ที่อยู่เดิม',
    contactPhone: '0812345678',
    businessHours: 'จันทร์-ศุกร์ 9:00-18:00 น.',
    createdAt: DateTime(2026, 1, 1),
  );

  final bareStore = Store(
    id: 'store-2',
    ownerId: 'u1',
    name: 'ร้านเปล่า',
    createdAt: DateTime(2026, 1, 1),
  );

  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets.
  late RecordingSellerRepository repository;
  late RecordingSellerRepository failingRepository;

  setUp(() {
    repository = RecordingSellerRepository();
    failingRepository =
        RecordingSellerRepository(updateStoreInfoException: Exception('boom'));
  });

  Widget buildScreen(
    Store forStore,
    RecordingSellerRepository forRepository, {
    required ValueChanged<Store> onStoreUpdated,
  }) {
    return MaterialApp(
      home: SellerStoreScreen(
        store: forStore,
        sellerRepository: forRepository,
        onStoreUpdated: onStoreUpdated,
      ),
    );
  }

  testWidgets('pre-fills every field with the current store\'s values',
      (tester) async {
    await tester.pumpWidget(buildScreen(store, repository, onStoreUpdated: (_) {}));

    expect(find.widgetWithText(TextField, 'ร้านทดสอบ'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'คำอธิบายร้าน'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'ที่อยู่เดิม'), findsOneWidget);
    expect(find.widgetWithText(TextField, '0812345678'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'จันทร์-ศุกร์ 9:00-18:00 น.'),
      findsOneWidget,
    );
  });

  testWidgets('leaves optional fields empty when the store has none set',
      (tester) async {
    await tester.pumpWidget(
      buildScreen(bareStore, repository, onStoreUpdated: (_) {}),
    );

    expect(find.widgetWithText(TextField, 'ร้านเปล่า'), findsOneWidget);
    // No crash rendering placeholder icons for a store with no
    // logo/banner at all.
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNWidgets(2));
  });

  testWidgets('save button is disabled only when the store name is empty',
      (tester) async {
    await tester.pumpWidget(buildScreen(store, repository, onStoreUpdated: (_) {}));

    var saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNotNull);

    await tester.enterText(find.widgetWithText(TextField, 'ร้านทดสอบ'), '');
    await tester.pump();

    saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'ร้านทดสอบใหม่');
    await tester.pump();

    saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets(
      'saving calls updateStoreInfo with the edited fields, shows a '
      'success SnackBar, and calls onStoreUpdated without popping',
      (tester) async {
    Store? updatedStoreReceived;

    await tester.pumpWidget(buildScreen(
      store,
      repository,
      onStoreUpdated: (updated) => updatedStoreReceived = updated,
    ));

    await tester.enterText(find.byType(TextField).first, 'ร้านทดสอบ (แก้ไข)');
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(repository.updateStoreInfoCalls, 1);
    expect(repository.lastUpdateStoreInfoStoreId, 'store-1');
    expect(repository.lastUpdateStoreInfoName, 'ร้านทดสอบ (แก้ไข)');
    expect(repository.lastUpdateStoreInfoAddress, 'ที่อยู่เดิม');
    expect(repository.lastUpdateStoreInfoContactPhone, '0812345678');
    expect(
      repository.lastUpdateStoreInfoBusinessHours,
      'จันทร์-ศุกร์ 9:00-18:00 น.',
    );

    expect(find.text('บันทึกข้อมูลร้านสำเร็จ'), findsOneWidget);
    expect(updatedStoreReceived, isNotNull);
    expect(updatedStoreReceived!.name, 'ร้านทดสอบ (แก้ไข)');

    // Still on the same screen -- a tab body must never pop itself.
    expect(find.byType(SellerStoreScreen), findsOneWidget);
  });

  testWidgets(
      'shows an error message and does not call onStoreUpdated when saving '
      'fails', (tester) async {
    var onStoreUpdatedCalls = 0;

    await tester.pumpWidget(buildScreen(
      store,
      failingRepository,
      onStoreUpdated: (_) => onStoreUpdatedCalls++,
    ));

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(onStoreUpdatedCalls, 0);
  });

  testWidgets('every text field respects its DB CHECK constraint maxLength',
      (tester) async {
    await tester.pumpWidget(buildScreen(store, repository, onStoreUpdated: (_) {}));

    final nameField = tester.widget<TextField>(find.byType(TextField).at(0));
    final addressField = tester.widget<TextField>(find.byType(TextField).at(2));
    final contactPhoneField = tester.widget<TextField>(find.byType(TextField).at(3));
    final businessHoursField = tester.widget<TextField>(find.byType(TextField).at(4));

    expect(nameField.maxLength, 100);
    expect(addressField.maxLength, 300);
    expect(contactPhoneField.maxLength, 50);
    expect(businessHoursField.maxLength, 200);
  });
}
