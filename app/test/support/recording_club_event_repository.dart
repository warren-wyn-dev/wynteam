import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/club/data/club_event.dart';
import 'package:wyn/features/club/data/club_event_repository.dart';

/// A ClubEventRepository whose network-touching methods are overridden
/// to just record what they were called with / return canned data,
/// instead of making a real Supabase call. Mirrors
/// RecordingClubPostRepository -- see .wyn/learning/PATTERNS.md.
class RecordingClubEventRepository extends ClubEventRepository {
  RecordingClubEventRepository({
    List<ClubEvent>? upcomingEvents,
    List<ClubEvent>? pastEvents,
    List<ClubEventAttendee>? attendees,
  })  : upcomingEvents = upcomingEvents ?? [],
        pastEvents = pastEvents ?? [],
        attendees = attendees ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  final List<ClubEvent> upcomingEvents;
  final List<ClubEvent> pastEvents;

  /// Returned by [fetchAttendees] regardless of eventId/status.
  final List<ClubEventAttendee> attendees;

  int fetchUpcomingEventsCalls = 0;
  int fetchPastEventsCalls = 0;

  @override
  Future<List<ClubEvent>> fetchUpcomingEvents(String clubId) async {
    fetchUpcomingEventsCalls++;
    return upcomingEvents;
  }

  @override
  Future<List<ClubEvent>> fetchPastEvents(String clubId) async {
    fetchPastEventsCalls++;
    return pastEvents;
  }

  int createEventCalls = 0;
  Object? createEventError;

  @override
  Future<void> createEvent({
    required String clubId,
    required String title,
    String? description,
    required DateTime startsAt,
    required ClubEventLocationType locationType,
    required String location,
  }) async {
    if (createEventError != null) throw createEventError!;
    createEventCalls++;
  }

  int updateEventCalls = 0;
  Object? updateEventError;

  @override
  Future<void> updateEvent({
    required String eventId,
    required String title,
    String? description,
    required DateTime startsAt,
    required ClubEventLocationType locationType,
    required String location,
  }) async {
    if (updateEventError != null) throw updateEventError!;
    updateEventCalls++;
  }

  int deleteEventCalls = 0;
  final List<String> deleteEventIdArgs = [];
  Object? deleteEventError;

  @override
  Future<void> deleteEvent(String eventId) async {
    if (deleteEventError != null) throw deleteEventError!;
    deleteEventCalls++;
    deleteEventIdArgs.add(eventId);
  }

  /// Each call to [setRsvp]'s (eventId, status), in order.
  final List<(String, RsvpStatus)> setRsvpArgs = [];
  Object? setRsvpError;

  @override
  Future<void> setRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    if (setRsvpError != null) throw setRsvpError!;
    setRsvpArgs.add((eventId, status));
  }

  final List<RsvpStatus> fetchAttendeesStatusArgs = [];

  @override
  Future<List<ClubEventAttendee>> fetchAttendees({
    required String eventId,
    required RsvpStatus status,
  }) async {
    fetchAttendeesStatusArgs.add(status);
    return attendees;
  }
}
