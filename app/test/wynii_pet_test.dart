import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/chat/data/wynii_pet.dart';

void main() {
  group('Wynii lifecycle', () {
    test('maps milestone ages to the agreed stages', () {
      expect(wyniiStageForAge(0), WyniiStage.egg);
      expect(wyniiStageForAge(1), WyniiStage.hatching);
      expect(wyniiStageForAge(6), WyniiStage.hatching);
      expect(wyniiStageForAge(7), WyniiStage.baby);
      expect(wyniiStageForAge(29), WyniiStage.baby);
      expect(wyniiStageForAge(30), WyniiStage.growing);
      expect(wyniiStageForAge(99), WyniiStage.growing);
      expect(wyniiStageForAge(100), WyniiStage.mature);
      expect(wyniiStageForAge(364), WyniiStage.mature);
      expect(wyniiStageForAge(365), WyniiStage.max);
      expect(wyniiStageForAge(999), WyniiStage.max);
    });

    test('max form keeps age while milestone progress stays complete', () {
      expect(wyniiNextMilestone(365), isNull);
      expect(wyniiMilestoneProgress(365), 1);
      expect(wyniiMilestoneProgress(900), 1);
    });
  });

  group('Wynii care status', () {
    final started = DateTime.utc(2026, 9, 17, 10);

    WyniiPet pet({
      bool aDone = false,
      bool bDone = false,
      DateTime? cycleStartedAt,
      DateTime? lastCompletedAt,
      DateTime? nextCycleAt,
    }) =>
        WyniiPet(
          conversationId: 'conversation',
          userAId: 'a',
          userBId: 'b',
          ageDays: 32,
          cycleStartedAt: cycleStartedAt,
          userADone: aDone,
          userBDone: bDone,
          nextCycleAt: nextCycleAt ?? started,
          lastCompletedAt: lastCompletedAt,
        );

    test('one side done waits for the other side', () {
      final status = pet(aDone: true, cycleStartedAt: started).statusFor(
        'a',
        now: started.add(const Duration(hours: 2)),
      );
      expect(status.shortLabel, 'รออีกฝ่าย');
      expect(status.mineDone, isTrue);
      expect(status.otherDone, isFalse);
    });

    test('expired incomplete cycle rests without reducing age', () {
      final model = pet(aDone: true, cycleStartedAt: started);
      final status = model.statusFor(
        'a',
        now: started.add(const Duration(hours: 25)),
      );
      expect(model.ageDays, 32);
      expect(status.shortLabel, 'พักอยู่');
      expect(status.mineDone, isFalse);
      expect(status.otherDone, isFalse);
    });

    test('completed cycle reports complete during the lock window', () {
      final completedAt = started;
      final model = pet(
        lastCompletedAt: completedAt,
        nextCycleAt: completedAt.add(const Duration(hours: 24)),
      );
      final status = model.statusFor(
        'a',
        now: completedAt.add(const Duration(hours: 1)),
      );
      expect(status.shortLabel, 'วันนี้ครบแล้ว ✓');
      expect(status.mineDone, isTrue);
      expect(status.otherDone, isTrue);
    });
  });
}
