import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/legal/data/platform_document_repository.dart';

/// A PlatformDocumentRepository whose network-touching methods are
/// overridden to just return canned data instead of making a real
/// Supabase call. Mirrors RecordingNotificationSettingsRepository --
/// see .wyn/learning/PATTERNS.md.
class RecordingPlatformDocumentRepository extends PlatformDocumentRepository {
  RecordingPlatformDocumentRepository({
    this.hasAcceptedResult = true,
    this.hasAcceptedError,
    this.fetchLatestDocument,
    this.fetchLatestError,
  }) : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [hasAcceptedMandatoryDocuments] unless
  /// [hasAcceptedError] is set. Mutable (not final) so a single shared
  /// instance (this project's setUpAll convention -- see
  /// PATTERNS.md/the WYN-044 timer-leak bug report) can be reused
  /// across testWidgets cases that each need a different canned
  /// result.
  bool hasAcceptedResult;

  /// Thrown by [hasAcceptedMandatoryDocuments] when set, instead of
  /// returning [hasAcceptedResult] -- used to prove AuthGate's fail-open
  /// behavior on a load error (WYN-046 Product spec's Risks).
  Object? hasAcceptedError;

  /// Returned by [fetchLatest] regardless of the type asked for, unless
  /// [fetchLatestError] is set -- DocumentViewerScreen/
  /// DocumentAcceptanceScreen tests reassign this per case.
  PlatformDocument? fetchLatestDocument;
  Object? fetchLatestError;

  /// When set, [fetchLatest] awaits this instead of resolving/throwing
  /// immediately -- lets a test control exactly when the fetch
  /// completes (e.g. via a Completer) to observe DocumentViewerScreen's
  /// loading state, same "resolves immediately by default, unless a
  /// test needs to observe the in-progress state" shape as
  /// NotificationSettingsSettingsScreen's `_ControlledFetchRepository`.
  Future<void> Function()? fetchLatestOverride;

  int acceptMandatoryDocumentsCalls = 0;
  Object? acceptMandatoryDocumentsError;

  @override
  Future<bool> hasAcceptedMandatoryDocuments() async {
    final error = hasAcceptedError;
    if (error != null) throw error;
    return hasAcceptedResult;
  }

  @override
  Future<void> acceptMandatoryDocuments() async {
    acceptMandatoryDocumentsCalls++;
    final error = acceptMandatoryDocumentsError;
    if (error != null) throw error;
  }

  @override
  Future<PlatformDocument> fetchLatest(PlatformDocumentType type) async {
    if (fetchLatestOverride != null) {
      await fetchLatestOverride!();
    }
    final error = fetchLatestError;
    if (error != null) throw error;
    final document = fetchLatestDocument;
    if (document != null) return document;
    return PlatformDocument(
      type: type,
      version: 1,
      title: 'placeholder title',
      content: 'placeholder content',
      effectiveAt: DateTime(2026, 1, 1),
    );
  }
}
