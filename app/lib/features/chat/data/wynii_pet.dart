import 'package:supabase_flutter/supabase_flutter.dart';

enum WyniiStage { egg, hatching, baby, growing, mature, max }

WyniiStage wyniiStageForAge(int ageDays) {
  if (ageDays <= 0) return WyniiStage.egg;
  if (ageDays <= 6) return WyniiStage.hatching;
  if (ageDays <= 29) return WyniiStage.baby;
  if (ageDays <= 99) return WyniiStage.growing;
  if (ageDays <= 364) return WyniiStage.mature;
  return WyniiStage.max;
}

String wyniiStageLabel(WyniiStage stage) => switch (stage) {
      WyniiStage.egg => 'ไข่',
      WyniiStage.hatching => 'กำลังฟัก',
      WyniiStage.baby => 'วัยเด็ก',
      WyniiStage.growing => 'วัยเติบโต',
      WyniiStage.mature => 'วัยโต',
      WyniiStage.max => 'MAX Form',
    };

int? wyniiNextMilestone(int ageDays) {
  if (ageDays < 1) return 1;
  if (ageDays < 7) return 7;
  if (ageDays < 30) return 30;
  if (ageDays < 100) return 100;
  if (ageDays < 365) return 365;
  return null;
}

double wyniiMilestoneProgress(int ageDays) {
  final next = wyniiNextMilestone(ageDays);
  if (next == null) return 1;
  final previous = switch (next) {
    1 => 0,
    7 => 1,
    30 => 7,
    100 => 30,
    _ => 100,
  };
  final span = next - previous;
  if (span <= 0) return 0;
  return ((ageDays - previous) / span).clamp(0, 1).toDouble();
}

class WyniiPet {
  const WyniiPet({
    required this.conversationId,
    required this.userAId,
    required this.userBId,
    required this.ageDays,
    required this.cycleStartedAt,
    required this.userADone,
    required this.userBDone,
    required this.nextCycleAt,
    required this.lastCompletedAt,
  });

  factory WyniiPet.fromMap(Map<String, dynamic> row) => WyniiPet(
        conversationId: row['conversation_id'] as String,
        userAId: row['user_a_id'] as String,
        userBId: row['user_b_id'] as String,
        ageDays: (row['age_days'] as num?)?.toInt() ?? 0,
        cycleStartedAt: _parseDate(row['cycle_started_at']),
        userADone: row['user_a_done'] as bool? ?? false,
        userBDone: row['user_b_done'] as bool? ?? false,
        nextCycleAt: _parseDate(row['next_cycle_at']) ?? DateTime.now(),
        lastCompletedAt: _parseDate(row['last_completed_at']),
      );

  final String conversationId;
  final String userAId;
  final String userBId;
  final int ageDays;
  final DateTime? cycleStartedAt;
  final bool userADone;
  final bool userBDone;
  final DateTime nextCycleAt;
  final DateTime? lastCompletedAt;

  WyniiStage get stage => wyniiStageForAge(ageDays);

  bool mineDone(String userId) => userId == userAId ? userADone : userBDone;
  bool otherDone(String userId) => userId == userAId ? userBDone : userADone;

  WyniiStatus statusFor(String userId, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final started = cycleStartedAt;
    final mine = mineDone(userId);
    final other = otherDone(userId);

    if (started != null && current.isAfter(started.add(const Duration(hours: 24)))) {
      return const WyniiStatus(
        shortLabel: 'พักอยู่',
        detail: 'รอบก่อนหน้าไม่ครบภายใน 24 ชั่วโมง ข้อความใหม่จะเริ่มรอบถัดไป',
        mineDone: false,
        otherDone: false,
      );
    }

    if (started != null) {
      if (mine && !other) {
        return WyniiStatus(
          shortLabel: 'รออีกฝ่าย',
          detail: 'คุณส่งแล้ว รออีกฝ่ายส่งภายใน 24 ชั่วโมง',
          mineDone: mine,
          otherDone: other,
        );
      }
      if (!mine && other) {
        return WyniiStatus(
          shortLabel: 'ถึงตาคุณ',
          detail: 'อีกฝ่ายส่งแล้ว ส่งอะไรก็ได้ในแชทเพื่อดูแล Wynii',
          mineDone: mine,
          otherDone: other,
        );
      }
      return WyniiStatus(
        shortLabel: '$ageDays วัน',
        detail: 'กำลังดูแล Wynii ในรอบนี้',
        mineDone: mine,
        otherDone: other,
      );
    }

    if (lastCompletedAt != null && current.isBefore(nextCycleAt)) {
      return const WyniiStatus(
        shortLabel: 'วันนี้ครบแล้ว ✓',
        detail: 'ทั้งสองฝ่ายส่งครบแล้ว รอบถัดไปเปิดเมื่อครบ 24 ชั่วโมง',
        mineDone: true,
        otherDone: true,
      );
    }

    return WyniiStatus(
      shortLabel: '$ageDays วัน',
      detail: 'ส่งอะไรก็ได้ในแชทคนละ 1 ครั้งภายใน 24 ชั่วโมง',
      mineDone: false,
      otherDone: false,
    );
  }
}

class WyniiStatus {
  const WyniiStatus({
    required this.shortLabel,
    required this.detail,
    required this.mineDone,
    required this.otherDone,
  });

  final String shortLabel;
  final String detail;
  final bool mineDone;
  final bool otherDone;
}

class WyniiConversationState {
  const WyniiConversationState({required this.pet, required this.isActive});

  final WyniiPet? pet;
  final bool isActive;
}

class WyniiRepository {
  WyniiRepository(this._client);

  final SupabaseClient _client;

  Future<WyniiConversationState> fetchConversationState(
      String conversationId) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('conversation_wynii')
          .select(
              'conversation_id,user_a_id,user_b_id,age_days,cycle_started_at,user_a_done,user_b_done,next_cycle_at,last_completed_at')
          .eq('conversation_id', conversationId)
          .maybeSingle(),
      _client
          .from('conversations')
          .select('status')
          .eq('id', conversationId)
          .maybeSingle(),
    ]);

    final petRow = results[0] as Map<String, dynamic>?;
    final conversationRow = results[1] as Map<String, dynamic>?;
    return WyniiConversationState(
      pet: petRow == null ? null : WyniiPet.fromMap(petRow),
      isActive: conversationRow?['status'] == 'active',
    );
  }

  Future<WyniiPet> start(String conversationId) async {
    await _client.rpc(
      'start_conversation_wynii',
      params: {'p_conversation_id': conversationId},
    );
    final state = await fetchConversationState(conversationId);
    final pet = state.pet;
    if (pet == null) {
      throw StateError('สร้าง Wynii ไม่สำเร็จ');
    }
    return pet;
  }
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw as String);
}
