import 'package:supabase_flutter/supabase_flutter.dart';

import 'club_event.dart';

const _eventSelect =
    '*, creator:profiles!club_events_creator_id_fkey(username, display_name, avatar_url)';

/// Wraps `club_events`/`club_event_rsvps` reads/writes for WYN-118
/// (Club Events). See supabase/schema.sql for the RLS policies/RPC this
/// relies on.
class ClubEventRepository {
  ClubEventRepository(this._client);

  final SupabaseClient _client;

  Future<
          Map<String,
              ({RsvpStatus? myStatus, int going, int maybe, int notGoing})>>
      _fetchRsvpStates(List<String> eventIds) async {
    if (eventIds.isEmpty) return {};
    final userId = _client.auth.currentUser!.id;

    final myRows = await _client
        .from('club_event_rsvps')
        .select('event_id, status')
        .eq('user_id', userId)
        .inFilter('event_id', eventIds);
    final myStatusByEventId = <String, RsvpStatus>{
      for (final row in myRows)
        row['event_id'] as String:
            _rsvpStatusFromString(row['status'] as String),
    };

    final countRows = await _client
        .rpc('club_event_rsvp_counts', params: {'p_event_ids': eventIds});

    return {
      for (final id in eventIds)
        id: (
          myStatus: myStatusByEventId[id],
          going: 0,
          maybe: 0,
          notGoing: 0,
        ),
      for (final row in countRows as List<dynamic>)
        row['event_id'] as String: (
          myStatus: myStatusByEventId[row['event_id'] as String],
          going: (row['going'] as num).toInt(),
          maybe: (row['maybe'] as num).toInt(),
          notGoing: (row['not_going'] as num).toInt(),
        ),
    };
  }

  Future<List<ClubEvent>> _withRsvpStates(
      List<Map<String, dynamic>> rows) async {
    final ids = rows.map((row) => row['id'] as String).toList();
    final states = await _fetchRsvpStates(ids);
    return rows.map((row) {
      final id = row['id'] as String;
      final state = states[id];
      return ClubEvent.fromMap(
        row,
        myRsvpStatus: state?.myStatus,
        goingCount: state?.going ?? 0,
        maybeCount: state?.maybe ?? 0,
        notGoingCount: state?.notGoing ?? 0,
      );
    }).toList();
  }

  /// Soonest-first -- events whose `starts_at` hasn't passed yet.
  Future<List<ClubEvent>> fetchUpcomingEvents(String clubId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('club_events')
        .select(_eventSelect)
        .eq('club_id', clubId)
        .gte('starts_at', now)
        .order('starts_at', ascending: true);
    return _withRsvpStates(rows);
  }

  /// Most-recently-past-first -- kept visually/structurally separate
  /// from upcoming events per the Product spec's own Acceptance
  /// Criteria ("ไม่ปนกันจนหาไม่เจอ").
  Future<List<ClubEvent>> fetchPastEvents(String clubId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('club_events')
        .select(_eventSelect)
        .eq('club_id', clubId)
        .lt('starts_at', now)
        .order('starts_at', ascending: false);
    return _withRsvpStates(rows);
  }

  Future<void> createEvent({
    required String clubId,
    required String title,
    String? description,
    required DateTime startsAt,
    required ClubEventLocationType locationType,
    required String location,
  }) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('club_events').insert({
      'club_id': clubId,
      'creator_id': userId,
      'title': title.trim(),
      'description':
          description?.trim().isEmpty ?? true ? null : description!.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'location_type': locationType.name,
      'location': location.trim(),
    });
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    String? description,
    required DateTime startsAt,
    required ClubEventLocationType locationType,
    required String location,
  }) {
    return _client.from('club_events').update({
      'title': title.trim(),
      'description':
          description?.trim().isEmpty ?? true ? null : description!.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'location_type': locationType.name,
      'location': location.trim(),
    }).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) {
    return _client.from('club_events').delete().eq('id', eventId);
  }

  /// Upserts on conflict (event_id, user_id) -- changing your mind is
  /// an UPDATE of the same row, not a new one (see
  /// `validate_club_event_rsvp()`'s own comment in supabase/schema.sql).
  Future<void> setRsvp({
    required String eventId,
    required RsvpStatus status,
  }) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('club_event_rsvps').upsert(
      {
        'event_id': eventId,
        'user_id': userId,
        'status': status.value,
      },
      onConflict: 'event_id,user_id',
    );
  }

  /// Every member who responded [status] to [eventId] -- backs the
  /// attendee bottom sheet ("เห็น...รายชื่อคนที่ตอบรับ").
  ///
  /// Goes through the club_event_attendee_profiles() RPC (supabase/
  /// schema.sql, WYN-130) rather than a plain `club_event_rsvps`
  /// select+embed -- see ClubRepository._fetchMemberProfiles' identical
  /// doc comment for why a straight `profiles` embed would include
  /// "ghost" (abandoned-onboarding) accounts as bare "@" / "?"-avatar
  /// rows, and why that exclusion has to happen in a SECURITY DEFINER
  /// RPC rather than client-side.
  Future<List<ClubEventAttendee>> fetchAttendees({
    required String eventId,
    required RsvpStatus status,
  }) async {
    final rows = await _client.rpc('club_event_attendee_profiles', params: {
      'p_event_id': eventId,
      'p_status': status.value,
    }) as List<dynamic>;
    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      return ClubEventAttendee.fromMap({
        ...map,
        'profile': {
          'username': map['username'],
          'display_name': map['display_name'],
          'avatar_url': map['avatar_url'],
        },
      });
    }).toList();
  }
}

RsvpStatus _rsvpStatusFromString(String value) => switch (value) {
      'going' => RsvpStatus.going,
      'maybe' => RsvpStatus.maybe,
      'not_going' => RsvpStatus.notGoing,
      _ => throw ArgumentError('Unknown RSVP status: $value'),
    };
