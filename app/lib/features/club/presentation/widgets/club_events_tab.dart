import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../data/club_event.dart';
import '../../data/club_event_repository.dart';
import '../create_club_event_screen.dart';
import 'club_event_card.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// WYN-118, Screen 2 -- one scrolling list, split into "กำลังจะถึง"
/// (soonest first) then "ที่ผ่านมาแล้ว" (most-recent-past first) by a
/// plain section header, not a nested sub-tab (Design's own anti-
/// over-engineering call for V1). Only reached at all when the viewer
/// is an approved member -- see ClubPage's own `myRole != null` gate on
/// this tab's very existence, matching how ClubPostsTab hides its own
/// content from a non-member.
class ClubEventsTab extends StatefulWidget {
  const ClubEventsTab({
    super.key,
    required this.clubEventRepository,
    required this.clubId,
    required this.canManage,
  });

  final ClubEventRepository clubEventRepository;
  final String clubId;

  /// Same tier as pin/unpin (`canModeratePosts`) -- gates the "+"
  /// create button and each card's edit/delete menu.
  final bool canManage;

  @override
  State<ClubEventsTab> createState() => _ClubEventsTabState();
}

class _ClubEventsTabState extends State<ClubEventsTab> {
  List<ClubEvent>? _upcoming;
  List<ClubEvent>? _past;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _upcoming = null;
      _past = null;
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        widget.clubEventRepository.fetchUpcomingEvents(widget.clubId),
        widget.clubEventRepository.fetchPastEvents(widget.clubId),
      ]);
      if (!mounted) return;
      setState(() {
        _upcoming = results[0];
        _past = results[1];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  // Same optimistic-then-revert-on-error shape as ClubPost.votedPoll's
  // callers -- [list]/[setter] let this one method serve both the
  // upcoming and past sections without duplicating the try/catch.
  Future<void> _rsvp(
    ClubEvent event,
    RsvpStatus status,
    List<ClubEvent> list,
    void Function(List<ClubEvent>) setter,
  ) async {
    final index = list.indexWhere((e) => e.id == event.id);
    if (index == -1) return;
    final previous = list[index];
    final updated = [...list];
    updated[index] = previous.withRsvp(status);
    setState(() => setter(updated));
    try {
      await widget.clubEventRepository
          .setRsvp(eventId: event.id, status: status);
    } catch (_) {
      if (!mounted) return;
      final reverted = [...list];
      reverted[index] = previous;
      setState(() => setter(reverted));
    }
  }

  Future<void> _showAttendees(ClubEvent event, RsvpStatus status) async {
    final label = switch (status) {
      RsvpStatus.going => 'คนที่ไป (${event.goingCount})',
      RsvpStatus.maybe => 'คนที่อาจจะไป (${event.maybeCount})',
      RsvpStatus.notGoing => 'คนที่ไม่ไป (${event.notGoingCount})',
    };
    List<ClubEventAttendee> attendees;
    try {
      attendees = await widget.clubEventRepository.fetchAttendees(
        eventId: event.id,
        status: status,
      );
    } catch (_) {
      attendees = const [];
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) =>
          ClubEventAttendeesSheet(title: label, attendees: attendees),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateClubEventScreen(
          clubEventRepository: widget.clubEventRepository,
          clubId: widget.clubId,
        ),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openEdit(ClubEvent event) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateClubEventScreen(
          clubEventRepository: widget.clubEventRepository,
          clubId: widget.clubId,
          existingEvent: event,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ClubEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const BrowserSystemText('ลบกิจกรรมนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const BrowserSystemText('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const BrowserSystemText('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.clubEventRepository.deleteEvent(event.id);
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('ลบกิจกรรมไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: widget.canManage
          ? BrowserSystemTooltip(
              message: 'สร้างกิจกรรม',
              child: FloatingActionButton(
                backgroundColor: WynColors.sapphire,
                foregroundColor: WynColors.paper,
                onPressed: _openCreate,
                tooltip: null,
                child: const Icon(Icons.add),
              ))
          : null,
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      // Same RefreshIndicator/AlwaysScrollableScrollPhysics fix as
      // club_posts_tab.dart's empty/error states.
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: WynSpacing.space8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrowserSystemText('โหลดกิจกรรมไม่สำเร็จ'),
                    const SizedBox(height: WynSpacing.space3),
                    TextButton(
                        onPressed: _load,
                        child: const BrowserSystemText('ลองใหม่')),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final upcoming = _upcoming;
    final past = _past;
    if (upcoming == null || past == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (upcoming.isEmpty && past.isEmpty) {
      // Same fix -- an empty Club with no events at all still needs a
      // working pull-to-refresh.
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: WynSpacing.space8),
              child: Center(
                  child: BrowserSystemText('ยังไม่มีกิจกรรมใน Club นี้')),
            ),
          ],
        ),
      );
    }

    // CustomScrollView (not ListView), same reasoning as
    // club_insights_tab.dart's identical comment -- participates
    // correctly in ClubPage's staged-rollout NestedScrollView layout's
    // shared header-collapse scroll position, unchanged behavior in the
    // legacy Column layout.
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (upcoming.isNotEmpty) ...[
                  const _SectionHeader('กำลังจะถึง'),
                  for (final event in upcoming)
                    ClubEventCard(
                      event: event,
                      canManage: widget.canManage,
                      onRsvp: (status) => _rsvp(
                        event,
                        status,
                        upcoming,
                        (list) => _upcoming = list,
                      ),
                      onShowAttendees: (status) =>
                          _showAttendees(event, status),
                      onEdit: () => _openEdit(event),
                      onDelete: () => _delete(event),
                    ),
                ],
                if (past.isNotEmpty) ...[
                  const _SectionHeader('ที่ผ่านมาแล้ว'),
                  for (final event in past)
                    ClubEventCard(
                      event: event,
                      canManage: widget.canManage,
                      onRsvp: (status) => _rsvp(
                        event,
                        status,
                        past,
                        (list) => _past = list,
                      ),
                      onShowAttendees: (status) =>
                          _showAttendees(event, status),
                      onEdit: () => _openEdit(event),
                      onDelete: () => _delete(event),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space4,
        WynSpacing.space4,
        WynSpacing.space1,
      ),
      child: BrowserSystemText(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}
