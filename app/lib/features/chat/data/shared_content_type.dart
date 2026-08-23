/// What kind of thing a shared-content message (WYN-033) points at.
/// Matches the `shared_content_type` check constraint on
/// `public.messages` in supabase/schema.sql.
enum SharedContentType {
  drop,
  profile,
  club,
}

extension SharedContentTypeWire on SharedContentType {
  /// The exact string the `shared_content_type` check constraint expects.
  String get wireValue => switch (this) {
        SharedContentType.drop => 'drop',
        SharedContentType.profile => 'profile',
        SharedContentType.club => 'club',
      };
}

SharedContentType sharedContentTypeFromWireValue(String value) => switch (value) {
      'drop' => SharedContentType.drop,
      'profile' => SharedContentType.profile,
      'club' => SharedContentType.club,
      _ => throw ArgumentError('Unknown shared content type: $value'),
    };
