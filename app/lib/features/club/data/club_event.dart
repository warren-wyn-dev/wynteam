import '../../../core/text_utils.dart';

/// WYN-118: online (URL) vs offline (free-text address) event location --
/// no map/GPS integration in V1, per the Product spec's own explicit
/// scope cut.
enum ClubEventLocationType { online, offline }

ClubEventLocationType _locationTypeFromString(String value) => switch (value) {
      'online' => ClubEventLocationType.online,
      'offline' => ClubEventLocationType.offline,
      _ => throw ArgumentError('Unknown club event location type: $value'),
    };

/// Deliberately mirrors `club_post_poll_votes`' own vocabulary
/// ('going'/'maybe'/'not_going'), not a generic yes/no -- RSVP is a
/// 3-way choice per the Product spec. Parsed from a raw string only in
/// `ClubEventRepository` (which needs it for the batch RSVP-state
/// fetch) -- [ClubEvent.fromMap] itself takes an already-parsed
/// [RsvpStatus]?, not a raw column, so no `fromString` helper lives here.
enum RsvpStatus { going, maybe, notGoing }

extension RsvpStatusValue on RsvpStatus {
  String get value => switch (this) {
        RsvpStatus.going => 'going',
        RsvpStatus.maybe => 'maybe',
        RsvpStatus.notGoing => 'not_going',
      };
}

/// A WYN Club event row (see `public.club_events` in supabase/schema.sql,
/// WYN-118 section), joined with its creator's profile and RSVP
/// aggregate counts. Unlike Poll votes (WYN-115, private to the voter),
/// RSVPs are visible to every approved club member -- see
/// `club_event_rsvps`' own RLS SELECT policy -- so [goingCount]/
/// [maybeCount]/[notGoingCount] reflect everyone's response, not just
/// the viewer's own.
class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.clubId,
    required this.creatorId,
    required this.creatorUsername,
    this.creatorDisplayName,
    this.creatorAvatarUrl,
    required this.title,
    this.description,
    required this.startsAt,
    required this.locationType,
    required this.location,
    required this.createdAt,
    this.myRsvpStatus,
    required this.goingCount,
    required this.maybeCount,
    required this.notGoingCount,
  });

  final String id;
  final String clubId;
  final String creatorId;
  final String creatorUsername;
  final String? creatorDisplayName;
  final String? creatorAvatarUrl;
  final String title;
  final String? description;
  final DateTime startsAt;
  final ClubEventLocationType locationType;
  final String location;
  final DateTime createdAt;

  /// The current viewer's own RSVP, or null if they haven't responded.
  final RsvpStatus? myRsvpStatus;
  final int goingCount;
  final int maybeCount;
  final int notGoingCount;

  bool get isPast => !startsAt.toUtc().isAfter(DateTime.now().toUtc());

  String get creatorNameOrUsername => displayNameOrUsername(
        displayName: creatorDisplayName,
        username: creatorUsername,
      );

  /// A copy with [status] recorded as the viewer's own RSVP --
  /// optimistic-update role, same shape as `ClubPost.votedPoll`.
  /// Handles changing an existing RSVP too: the old status's count (if
  /// any) is decremented and the new one incremented.
  ClubEvent withRsvp(RsvpStatus status) {
    int going = goingCount;
    int maybe = maybeCount;
    int notGoing = notGoingCount;

    switch (myRsvpStatus) {
      case RsvpStatus.going:
        going -= 1;
      case RsvpStatus.maybe:
        maybe -= 1;
      case RsvpStatus.notGoing:
        notGoing -= 1;
      case null:
        break;
    }
    switch (status) {
      case RsvpStatus.going:
        going += 1;
      case RsvpStatus.maybe:
        maybe += 1;
      case RsvpStatus.notGoing:
        notGoing += 1;
    }

    return ClubEvent(
      id: id,
      clubId: clubId,
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      creatorDisplayName: creatorDisplayName,
      creatorAvatarUrl: creatorAvatarUrl,
      title: title,
      description: description,
      startsAt: startsAt,
      locationType: locationType,
      location: location,
      createdAt: createdAt,
      myRsvpStatus: status,
      goingCount: going,
      maybeCount: maybe,
      notGoingCount: notGoing,
    );
  }

  /// [myRsvpStatus]/[goingCount]/[maybeCount]/[notGoingCount] aren't
  /// embeddable in the same query (RSVP counts come from a separate
  /// batch RPC, `club_event_rsvp_counts()` -- see
  /// ClubEventRepository), so they're always passed in explicitly
  /// rather than read from [map].
  factory ClubEvent.fromMap(
    Map<String, dynamic> map, {
    RsvpStatus? myRsvpStatus,
    required int goingCount,
    required int maybeCount,
    required int notGoingCount,
  }) {
    final creator = map['creator'] as Map<String, dynamic>?;
    return ClubEvent(
      id: map['id'] as String,
      clubId: map['club_id'] as String,
      creatorId: map['creator_id'] as String,
      creatorUsername: creator?['username'] as String? ?? '',
      creatorDisplayName: creator?['display_name'] as String?,
      creatorAvatarUrl: creator?['avatar_url'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      startsAt: DateTime.parse(map['starts_at'] as String),
      locationType: _locationTypeFromString(map['location_type'] as String),
      location: map['location'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      myRsvpStatus: myRsvpStatus,
      goingCount: goingCount,
      maybeCount: maybeCount,
      notGoingCount: notGoingCount,
    );
  }
}

/// One RSVP'd member, for the attendee bottom sheet
/// (`ClubEventRepository.fetchAttendees`).
class ClubEventAttendee {
  const ClubEventAttendee({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);

  factory ClubEventAttendee.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;
    return ClubEventAttendee(
      userId: map['user_id'] as String,
      username: profile?['username'] as String? ?? '',
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
