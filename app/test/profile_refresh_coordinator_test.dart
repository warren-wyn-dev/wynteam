import 'package:flutter_test/flutter_test.dart';
import 'package:wyn_app/features/profile/presentation/widgets/profile_refresh_coordinator.dart';

void main() {
  test('one refresh awaits every registered profile surface', () async {
    final coordinator = ProfileRefreshCoordinator();
    final calls = <String>[];
    final firstOwner = Object();
    final secondOwner = Object();

    coordinator.attach(firstOwner, () async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      calls.add('header-tab-a');
    });
    coordinator.attach(secondOwner, () async {
      calls.add('header-tab-b');
    });

    await coordinator.refreshAll();

    expect(calls, containsAll(<String>['header-tab-a', 'header-tab-b']));
    expect(calls.length, 2);
  });

  test('detached profile surfaces are not refreshed', () async {
    final coordinator = ProfileRefreshCoordinator();
    final owner = Object();
    var calls = 0;

    coordinator.attach(owner, () async {
      calls++;
    });
    coordinator.detach(owner);
    await coordinator.refreshAll();

    expect(calls, 0);
  });
}
