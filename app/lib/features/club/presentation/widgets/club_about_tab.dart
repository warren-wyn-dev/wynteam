import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/club.dart';
import '../../data/club_badge_repository.dart';
import '../../data/club_event_repository.dart';
import '../../data/club_member.dart';
import '../../data/club_repository.dart';
import '../../../../core/design/wyn_spacing.dart';
import 'club_events_tab.dart';
import 'club_insights_tab.dart';
import 'club_members_tab.dart';

/// Which section of the composite "เกี่ยวกับ" tab is showing -- see
/// [ClubAboutTab.initialSection].
enum ClubAboutSection { details, members, events, insights }

/// Screen 6-7 — the composite "เกี่ยวกับ" tab: Founder's tab-restructuring
/// decision (2026-09-07) merged what used to be 3 separate top-level Club
/// tabs (สมาชิก/เกี่ยวกับ/Insights) plus กิจกรรม into this one, reached via
/// an internal segmented switcher rather than more top-level tabs (Club
/// is now just 3: โพสต์/แชท/เกี่ยวกับ). Each segment reuses its old
/// standalone widget unmodified -- [ClubMembersTab]/[ClubEventsTab]/
/// [ClubInsightsTab] -- only "รายละเอียด" (the club's own description/
/// category/privacy/rules editor, previously this file's entire content)
/// is inlined here as [_ClubDetailsSection], renamed from "เกี่ยวกับ" to
/// avoid the exact name collision the Founder flagged between this tab
/// and its own content.
///
/// Segment visibility mirrors exactly what ClubPage used to gate at the
/// top-level tab level: "สมาชิก"/"รายละเอียด" always, "กิจกรรม" only for
/// an approved member (`myRole != null`), "Insights" only for Owner/Admin
/// (`myRole?.canManageClub ?? false`).
class ClubAboutTab extends StatefulWidget {
  const ClubAboutTab({
    super.key,
    required this.clubRepository,
    required this.club,
    required this.myRole,
    required this.onChanged,
    required this.onInvite,
    ClubEventRepository? clubEventRepository,
    ClubBadgeRepository? clubBadgeRepository,
    this.initialSection = ClubAboutSection.details,
  })  : _clubEventRepository = clubEventRepository,
        _clubBadgeRepository = clubBadgeRepository;

  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onChanged;

  /// Threaded through to the "สมาชิก" segment (`ClubMembersTab.onInvite`).
  final VoidCallback onInvite;

  final ClubEventRepository? _clubEventRepository;
  final ClubBadgeRepository? _clubBadgeRepository;

  /// WYN-015's club_join_request notification used to jump straight to
  /// the top-level Members tab (index 1) -- now that Members is a
  /// segment inside this composite tab instead, ClubPage passes
  /// [ClubAboutSection.members] here so that notification still lands on
  /// the pending-request list, not whichever segment happens to be
  /// first.
  final ClubAboutSection initialSection;

  @override
  State<ClubAboutTab> createState() => _ClubAboutTabState();
}

class _ClubAboutTabState extends State<ClubAboutTab> {
  late final ClubEventRepository _clubEventRepository =
      widget._clubEventRepository ??
          ClubEventRepository(Supabase.instance.client);
  late final ClubBadgeRepository _clubBadgeRepository =
      widget._clubBadgeRepository ??
          ClubBadgeRepository(Supabase.instance.client);

  late ClubAboutSection _section = widget.initialSection;

  bool get _isMember => widget.myRole != null;
  bool get _canManageClub => widget.myRole?.canManageClub ?? false;

  @override
  Widget build(BuildContext context) {
    final segments = <ButtonSegment<ClubAboutSection>>[
      const ButtonSegment(
          value: ClubAboutSection.details,
          label: BrowserSystemText('รายละเอียด')),
      const ButtonSegment(
          value: ClubAboutSection.members, label: BrowserSystemText('สมาชิก')),
      if (_isMember)
        const ButtonSegment(
            value: ClubAboutSection.events,
            label: BrowserSystemText('กิจกรรม')),
      if (_canManageClub)
        const ButtonSegment(
            value: ClubAboutSection.insights,
            label: BrowserSystemText('Insights')),
    ];
    // A role change (e.g. losing Owner/Admin) could make [_section] no
    // longer valid -- fall back to "รายละเอียด" rather than rendering a
    // segmented control with no segment selected.
    final validSections = segments.map((s) => s.value).toSet();
    final effectiveSection =
        validSections.contains(_section) ? _section : ClubAboutSection.details;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space4,
            WynSpacing.space3,
            WynSpacing.space4,
            WynSpacing.space2,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ClubAboutSection>(
              segments: segments,
              selected: {effectiveSection},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
          ),
        ),
        Expanded(child: _buildSection(effectiveSection)),
      ],
    );
  }

  Widget _buildSection(ClubAboutSection section) {
    switch (section) {
      case ClubAboutSection.details:
        return _ClubDetailsSection(
          clubRepository: widget.clubRepository,
          club: widget.club,
          myRole: widget.myRole,
          onChanged: widget.onChanged,
        );
      case ClubAboutSection.members:
        return ClubMembersTab(
          clubRepository: widget.clubRepository,
          club: widget.club,
          myRole: widget.myRole,
          onChanged: widget.onChanged,
          onInvite: widget.onInvite,
          clubBadgeRepository: _clubBadgeRepository,
        );
      case ClubAboutSection.events:
        return ClubEventsTab(
          clubEventRepository: _clubEventRepository,
          clubId: widget.club.id,
          canManage: widget.myRole?.canModeratePosts ?? false,
        );
      case ClubAboutSection.insights:
        return ClubInsightsTab(
          clubRepository: widget.clubRepository,
          club: widget.club,
        );
    }
  }
}

/// The club's own description/category/privacy/created-date/rules
/// editor -- exactly this file's entire content before the Founder's
/// tab-restructuring decision (2026-09-07) turned "เกี่ยวกับ" into a
/// composite of several sections. Renamed from the public `ClubAboutTab`
/// to this private "รายละเอียด" section to avoid the exact name
/// collision the Founder flagged between a top-level tab and content
/// nested inside it (the same defect as WYN-127/128's "โพสต์ | แชท"
/// toggle living inside a "โพสต์" tab).
class _ClubDetailsSection extends StatefulWidget {
  const _ClubDetailsSection({
    required this.clubRepository,
    required this.club,
    required this.myRole,
    required this.onChanged,
  });

  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onChanged;

  @override
  State<_ClubDetailsSection> createState() => _ClubDetailsSectionState();
}

class _ClubDetailsSectionState extends State<_ClubDetailsSection> {
  bool _isEditingRules = false;
  bool _isSavingRules = false;
  late final TextEditingController _rulesController;

  bool get _canManage => widget.myRole?.canManageClub ?? false;

  @override
  void initState() {
    super.initState();
    _rulesController = TextEditingController(text: widget.club.rules ?? '');
  }

  @override
  void didUpdateWidget(covariant _ClubDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditingRules && oldWidget.club.rules != widget.club.rules) {
      _rulesController.text = widget.club.rules ?? '';
    }
  }

  @override
  void dispose() {
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    setState(() => _isSavingRules = true);
    try {
      await widget.clubRepository.updateRules(
        clubId: widget.club.id,
        rules: _rulesController.text,
      );
      if (!mounted) return;
      setState(() => _isEditingRules = false);
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('บันทึกกฎไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isSavingRules = false);
    }
  }

  // Unlike every other segment in this composite tab (Members/Events/
  // Insights each fetch their own data and can await their own reload),
  // "รายละเอียด" only ever displays `widget.club` -- the exact same
  // `Club` object `ClubPage` already holds, passed straight down. There
  // is nothing for this widget to fetch on its own, so pull-to-refresh
  // here just re-triggers ClubPage's own `_reload()` (the same one
  // "แก้ไขข้อมูล Club"/leave-club/etc. already call after a write) via
  // `widget.onChanged` -- same mechanism `_saveRules` below already
  // uses fire-and-forget. `onChanged` is a plain `VoidCallback`, not an
  // awaitable one, so the spinner can't track the real fetch duration
  // the way club_members_tab.dart's/club_insights_tab.dart's own
  // RefreshIndicators do -- an accepted trade-off for consistency
  // (every segment of this tab now has the same pull-to-refresh
  // gesture) over spinner accuracy on this one segment specifically.
  Future<void> _refresh() async {
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;

    // CustomScrollView (not ListView), same reasoning as
    // club_insights_tab.dart's identical comment -- a "primary"
    // scrollable that participates correctly in ClubPage's
    // NestedScrollView layout's shared header-collapse scroll position.
    // ClubAboutTab's own SegmentedButton row (above this widget) is a
    // fixed, non-scrolling wrapper -- it doesn't intercept the ambient
    // PrimaryScrollController InheritedWidget lookup, so this still
    // correctly binds through it.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(WynSpacing.space4),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection(
                  label: 'คำอธิบาย',
                  child: BrowserSystemText(
                    (club.description != null && club.description!.isNotEmpty)
                        ? club.description!
                        : 'ยังไม่มีคำอธิบาย',
                  ),
                ),
                _buildSection(
                  label: 'หมวดหมู่',
                  child: BrowserSystemText(club.category ?? 'ไม่ระบุ'),
                ),
                _buildSection(
                  label: 'ความเป็นส่วนตัว',
                  child: Row(
                    children: [
                      Icon(
                        club.privacy == ClubPrivacy.private
                            ? Icons.lock_outline
                            : Icons.public,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      BrowserSystemText(club.privacy == ClubPrivacy.private
                          ? 'ส่วนตัว'
                          : 'สาธารณะ'),
                    ],
                  ),
                ),
                _buildSection(
                  label: 'สร้างเมื่อ',
                  child: BrowserSystemText(_formatFullDate(club.createdAt)),
                ),
                _buildSection(
                  label: 'กฎของ Club',
                  child: _isEditingRules
                      ? _buildRulesEditor()
                      : _buildRulesText(club),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesText(Club club) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrowserSystemText(
          (club.rules != null && club.rules!.isNotEmpty)
              ? club.rules!
              : 'Club นี้ยังไม่มีกฎ',
        ),
        if (_canManage) ...[
          const SizedBox(height: WynSpacing.space2),
          OutlinedButton(
            onPressed: () => setState(() => _isEditingRules = true),
            child: const BrowserSystemText('แก้ไขกฎ'),
          ),
        ],
      ],
    );
  }

  Widget _buildRulesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrowserSystemTextField(
          controller: _rulesController,
          maxLines: 6,
          maxLength: 2000,
          enabled: !_isSavingRules,
          decoration:
              const InputDecoration(hint: BrowserSystemText('เขียนกฎของ Club')),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSavingRules
                  ? null
                  : () => setState(() {
                        _isEditingRules = false;
                        _rulesController.text = widget.club.rules ?? '';
                      }),
              child: const BrowserSystemText('ยกเลิก'),
            ),
            FilledButton(
              onPressed: _isSavingRules ? null : _saveRules,
              child: _isSavingRules
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const BrowserSystemText('บันทึก'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WynSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrowserSystemText(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: WynSpacing.space1),
          child,
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
