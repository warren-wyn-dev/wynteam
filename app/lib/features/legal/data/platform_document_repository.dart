import 'package:supabase_flutter/supabase_flutter.dart';

/// The 6 document types Master Spec section 27 defines for WYN
/// (`platform_documents.type`'s CHECK constraint, supabase/schema.sql,
/// WYN-046 section). No "Future Commerce Terms" entry -- see that same
/// schema comment for why (ZOKY/Marketplace parked for V2, nothing to
/// cover yet).
enum PlatformDocumentType {
  termsOfService('terms_of_service'),
  privacyPolicy('privacy_policy'),
  communityGuidelines('community_guidelines'),
  copyrightPolicy('copyright_policy'),
  reportPolicy('report_policy'),
  appealPolicy('appeal_policy');

  const PlatformDocumentType(this.dbValue);

  /// The exact string stored in `platform_documents.type`/
  /// `user_document_acceptances.document_type`.
  final String dbValue;

  static PlatformDocumentType fromDbValue(String value) {
    return PlatformDocumentType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () =>
          throw ArgumentError('Unknown platform document type: $value'),
    );
  }
}

/// One row of `platform_documents` (WYN-046) -- always the version
/// [PlatformDocumentRepository.fetchLatest] loaded, never an older
/// one. **`content` this round is a placeholder that explicitly says
/// so** (see supabase/schema.sql's WYN-046 section and the
/// APPROVAL_REQUIRED entry in .wyn/company/APPROVALS.md, 2026-08-23) --
/// this class just carries whatever text is in the DB, it does not
/// interpret or validate it.
class PlatformDocument {
  const PlatformDocument({
    required this.type,
    required this.version,
    required this.title,
    required this.content,
    required this.effectiveAt,
  });

  factory PlatformDocument.fromMap(Map<String, dynamic> map) {
    return PlatformDocument(
      type: PlatformDocumentType.fromDbValue(map['type'] as String),
      version: map['version'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      effectiveAt: DateTime.parse(map['effective_at'] as String),
    );
  }

  final PlatformDocumentType type;
  final int version;
  final String title;
  final String content;
  final DateTime effectiveAt;
}

/// Reads `platform_documents` and reads/writes the current user's own
/// `user_document_acceptances` rows (WYN-046). No `userId` parameter
/// anywhere the acceptance side is concerned -- RLS already scopes
/// every `user_document_acceptances` query to `auth.uid()`, same
/// "someone else's row isn't a concept the backend allows at all"
/// reasoning as SavedRepository (WYN-013) /
/// NotificationSettingsRepository (WYN-044).
class PlatformDocumentRepository {
  PlatformDocumentRepository(this._client);

  final SupabaseClient _client;

  /// The 3 document types a user must accept before using the app at
  /// all (Product's Requirement 3). Copyright/Report/Appeal Policy are
  /// deliberately excluded -- read-only reference documents, never
  /// part of the Acceptance Gate.
  static const List<PlatformDocumentType> mandatoryTypes = [
    PlatformDocumentType.termsOfService,
    PlatformDocumentType.privacyPolicy,
    PlatformDocumentType.communityGuidelines,
  ];

  /// The latest version of a single document type -- used by
  /// DocumentViewerScreen (any of the 6 types, reused generically) and
  /// by DocumentAcceptanceScreen's 3 "read this document" links.
  Future<PlatformDocument> fetchLatest(PlatformDocumentType type) async {
    final row = await _client
        .from('platform_documents')
        .select()
        .eq('type', type.dbValue)
        .order('version', ascending: false)
        .limit(1)
        .single();
    return PlatformDocument.fromMap(row);
  }

  /// True only when the current user has already accepted the
  /// *current* version of all 3 mandatory documents -- false if any is
  /// missing entirely, or was accepted at an older version than the
  /// document's current one (Product's Requirement 3: the same
  /// mechanism that gates a brand-new user also re-prompts an existing
  /// user after a future document version bump, with no extra code).
  /// Exactly 2 queries total, not N+1 across the 3 mandatory types --
  /// one for their latest versions, one for the user's own acceptance
  /// rows.
  Future<bool> hasAcceptedMandatoryDocuments() async {
    final latestVersions = await _latestMandatoryVersions();

    final userId = _client.auth.currentUser!.id;
    final acceptanceRows = await _client
        .from('user_document_acceptances')
        .select('document_type, version')
        .eq('user_id', userId)
        .inFilter(
          'document_type',
          mandatoryTypes.map((t) => t.dbValue).toList(),
        );

    final acceptedVersions = <String, int>{
      for (final row in acceptanceRows)
        row['document_type'] as String: row['version'] as int,
    };

    return latestVersions.entries.every((entry) {
      final accepted = acceptedVersions[entry.key];
      return accepted != null && accepted >= entry.value;
    });
  }

  /// Inserts/updates all 3 mandatory documents' acceptance rows in a
  /// single upsert call, each pinned to that document's current
  /// version (Product's Requirement 3: "checkbox เดียว ไม่ใช่ 3
  /// checkbox แยก ... insert/update ทั้ง 3 แถวพร้อมกัน").
  ///
  /// `user_document_acceptances.user_id` references `public.profiles`
  /// (id), not `auth.users` -- but AuthGate shows this screen *before*
  /// UsernameSetupScreen (see that file's doc comment), so a brand-new
  /// user reaches here with no `profiles` row yet (that row is only
  /// ever created by [AuthRepository.setUsername]'s own upsert). Ensure
  /// one exists first, matching that same "on conflict do nothing"
  /// shape -- `username` stays null until the user actually sets one,
  /// which is exactly what a not-yet-onboarded user's profile should
  /// look like. A no-op for an existing user (the far more common case
  /// once a document version bump re-prompts them).
  Future<void> acceptMandatoryDocuments() async {
    final latestVersions = await _latestMandatoryVersions();
    final userId = _client.auth.currentUser!.id;

    await _client.from('profiles').upsert({'id': userId});

    await _client.from('user_document_acceptances').upsert(
      [
        for (final entry in latestVersions.entries)
          {
            'user_id': userId,
            'document_type': entry.key,
            'version': entry.value,
          },
      ],
      onConflict: 'user_id,document_type',
    );
  }

  /// The current (highest) version of each of the 3 mandatory document
  /// types, keyed by DB `type` string -- one query, shared by both
  /// [hasAcceptedMandatoryDocuments] and [acceptMandatoryDocuments] so
  /// neither has to re-derive it separately.
  Future<Map<String, int>> _latestMandatoryVersions() async {
    final rows = await _client
        .from('platform_documents')
        .select('type, version')
        .inFilter(
          'type',
          mandatoryTypes.map((t) => t.dbValue).toList(),
        )
        .order('version', ascending: false);

    final latest = <String, int>{};
    for (final row in rows) {
      final type = row['type'] as String;
      final version = row['version'] as int;
      // Rows are ordered by version desc, so the first time a type is
      // seen here is already its highest version -- any later (lower)
      // row for the same type is skipped.
      latest.putIfAbsent(type, () => version);
    }
    return latest;
  }
}
