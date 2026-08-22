import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/moderation/data/appeal.dart';
import 'package:wyn/features/moderation/data/appeal_repository.dart';
import 'package:wyn/features/moderation/data/my_appeal.dart';
import 'package:wyn/features/moderation/data/my_moderation_action.dart';

/// An AppealRepository whose network-touching methods are overridden to
/// just record what they were called with, instead of making a real
/// Supabase call. Mirrors RecordingModerationRepository (WYN-029) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingAppealRepository extends AppealRepository {
  RecordingAppealRepository({
    this.myModerationActionResult,
    this.myModerationActionError,
    this.myAppealResult,
    this.myAppealError,
    this.submitAppealError,
    this.pendingAppealsPages = const [],
    this.fetchPendingAppealsError,
    this.appealResult,
    this.fetchAppealError,
    this.decideAppealError,
    this.evidenceSignedUrlResult,
  }) : super(
          // autoRefreshToken: false -- see RecordingModerationRepository's
          // identical comment on why a default SupabaseClient's
          // auto-refresh Timer is a problem when this is constructed
          // fresh inside a `testWidgets` body rather than once in
          // `setUp`/`setUpAll`.
          SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  MyModerationAction? myModerationActionResult;
  Object? myModerationActionError;

  MyAppeal? myAppealResult;
  Object? myAppealError;

  Object? submitAppealError;
  int submitAppealCalls = 0;
  String? lastSubmitAppealActionId;
  String? lastSubmitAppealReason;

  List<List<Appeal>> pendingAppealsPages;
  Object? fetchPendingAppealsError;

  Appeal? appealResult;
  Object? fetchAppealError;

  Object? decideAppealError;
  int decideAppealCalls = 0;
  String? lastDecideAppealId;
  bool? lastDecideAppealApprove;
  String? lastDecideAppealReason;

  String? evidenceSignedUrlResult;

  @override
  Future<MyModerationAction> fetchMyModerationAction(String actionId) async {
    final error = myModerationActionError;
    if (error != null) throw error;
    return myModerationActionResult!;
  }

  @override
  Future<MyAppeal?> fetchMyAppeal(String actionId) async {
    final error = myAppealError;
    if (error != null) throw error;
    return myAppealResult;
  }

  @override
  Future<void> submitAppeal({
    required String actionId,
    required String reason,
    List<Uint8List>? evidenceImages,
    List<String>? evidenceExtensions,
  }) async {
    submitAppealCalls++;
    lastSubmitAppealActionId = actionId;
    lastSubmitAppealReason = reason;
    final error = submitAppealError;
    if (error != null) throw error;
  }

  @override
  Future<String?> evidenceSignedUrl(String path) async => evidenceSignedUrlResult;

  @override
  Future<List<Appeal>> fetchPendingAppeals({required int page}) async {
    final error = fetchPendingAppealsError;
    if (error != null) throw error;
    if (page < 0 || page >= pendingAppealsPages.length) return [];
    return pendingAppealsPages[page];
  }

  @override
  Future<Appeal?> fetchAppeal(String appealId) async {
    final error = fetchAppealError;
    if (error != null) throw error;
    return appealResult;
  }

  @override
  Future<void> decideAppeal({
    required String appealId,
    required bool approve,
    String? decisionReason,
  }) async {
    decideAppealCalls++;
    lastDecideAppealId = appealId;
    lastDecideAppealApprove = approve;
    lastDecideAppealReason = decisionReason;
    final error = decideAppealError;
    if (error != null) throw error;
  }
}
