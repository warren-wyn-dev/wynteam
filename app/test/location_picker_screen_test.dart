import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/location_repository.dart';
import 'package:wyn/features/drop/data/location_result.dart';
import 'package:wyn/features/drop/presentation/location_picker_screen.dart';

import 'support/recording_location_repository.dart';

const _starbucks = LocationResult(
  name: 'Starbucks',
  address: 'สยามพารากอน, Bangkok, Thailand',
  lat: 13.7466,
  lon: 100.5347,
  placeId: '1',
);

void main() {
  late RecordingLocationRepository locationRepository;

  setUp(() {
    locationRepository = RecordingLocationRepository();
  });

  Widget buildScreen({Future<(double, double)> Function()? debugPosition}) =>
      MaterialApp(
        home: LocationPickerScreen(
          locationRepository: locationRepository,
          debugResolveCurrentPosition: debugPosition,
        ),
      );

  testWidgets('shows the header and "ใช้ตำแหน่งปัจจุบันของฉัน" row with an '
      'empty result list initially', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('เพิ่มสถานที่'), findsOneWidget);
    expect(find.text('ใช้ตำแหน่งปัจจุบันของฉัน'), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });

  testWidgets('typing debounces, then calls search and shows the results',
      (tester) async {
    locationRepository.searchResultsByQuery = {
      'starbucks': [_starbucks],
    };

    await tester.pumpWidget(buildScreen());
    await tester.enterText(find.byType(TextField), 'starbucks');
    // Before the debounce fires -- no call yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(locationRepository.searchQueryArgs, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(locationRepository.searchQueryArgs, ['starbucks']);
    expect(find.text('Starbucks'), findsOneWidget);
    expect(find.text('สยามพารากอน, Bangkok, Thailand'), findsOneWidget);
  });

  testWidgets('tapping a result row pops with that LocationResult',
      (tester) async {
    locationRepository.searchResultsByQuery = {
      'starbucks': [_starbucks],
    };

    LocationResult? popped;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<LocationResult>(
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                        locationRepository: locationRepository),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'starbucks');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Starbucks'));
    await tester.pumpAndSettle();

    expect(popped, _starbucks);
  });

  testWidgets('no results after a real search shows the "ไม่พบ" message',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.enterText(find.byType(TextField), 'nowhere');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบสถานที่ที่ค้นหา ลองพิมพ์คำอื่นดูนะ'), findsOneWidget);
  });

  testWidgets('a search failure shows the generic error message',
      (tester) async {
    locationRepository.searchError = LocationSearchFailedException();

    await tester.pumpWidget(buildScreen());
    await tester.enterText(find.byType(TextField), 'starbucks');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('ค้นหาสถานที่ไม่สำเร็จตอนนี้ ลองอีกครั้งในอีกสักครู่'),
        findsOneWidget);
  });

  testWidgets('a rate-limited search shows the rate-limit message',
      (tester) async {
    locationRepository.searchError = LocationSearchRateLimitedException();

    await tester.pumpWidget(buildScreen());
    await tester.enterText(find.byType(TextField), 'starbucks');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('ค้นหาบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่'), findsOneWidget);
  });

  testWidgets(
      'tapping "ใช้ตำแหน่งปัจจุบันของฉัน" resolves the device position, '
      'reverse-geocodes, and prepends the result', (tester) async {
    locationRepository.reverseGeocodeResults = [_starbucks];

    await tester.pumpWidget(buildScreen(
      debugPosition: () async => (13.7466, 100.5347),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ใช้ตำแหน่งปัจจุบันของฉัน'));
    await tester.pumpAndSettle();

    expect(locationRepository.reverseGeocodeCalls, 1);
    expect(find.text('Starbucks'), findsOneWidget);
  });

  testWidgets(
      'a denied location permission shows the specific permission-denied '
      'copy, without crashing', (tester) async {
    await tester.pumpWidget(buildScreen(
      debugPosition: () async => throw LocationPermissionDeniedException(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ใช้ตำแหน่งปัจจุบันของฉัน'));
    await tester.pumpAndSettle();

    expect(
      find.text('WYN ไม่มีสิทธิ์เข้าถึงตำแหน่งของคุณ กรุณาเปิดสิทธิ์ในการตั้งค่าเครื่อง'),
      findsOneWidget,
    );
    expect(locationRepository.reverseGeocodeCalls, 0);
  });

  testWidgets('tapping ยกเลิก (back) pops with null', (tester) async {
    LocationResult? popped;
    var hasPopped = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<LocationResult>(
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                        locationRepository: locationRepository),
                  ),
                );
                hasPopped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(hasPopped, isTrue);
    expect(popped, isNull);
  });
}
