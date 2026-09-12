import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../../core/widgets/action_sheet_row.dart';
import '../data/club.dart';
import '../data/club_invite_link.dart';
import '../data/club_repository.dart';

/// The shareable URL for a Club invite [code] -- same top-level-function
/// convention as `clubShareLink`/`clubPostShareLink`/`dropShareLink`
/// (each defined right next to the screen that most needs it).
String clubInviteShareLink(String code) => 'https://wynos.online/club-invite/$code';

/// WYN-136 -- Owner/Admin only, reached from `ClubPage`'s More menu
/// ("ลิงก์เชิญ" row, gated the same `role.canManageClub` way the other
/// management rows already are). Lists every not-yet-revoked invite
/// link for [club], lets the Owner/Admin create new ones (with an
/// expiration/max-uses choice) and revoke existing ones. See
/// .wyn/docs/design/wyn-136-club-invite-link.md.
class ClubInviteLinksScreen extends StatefulWidget {
  const ClubInviteLinksScreen({
    super.key,
    required this.club,
    required this.clubRepository,
  });

  final Club club;
  final ClubRepository clubRepository;

  @override
  State<ClubInviteLinksScreen> createState() => _ClubInviteLinksScreenState();
}

class _ClubInviteLinksScreenState extends State<ClubInviteLinksScreen> {
  List<ClubInviteLink> _links = [];
  bool _isLoading = true;
  String? _error;
  bool _isCreating = false;
  final Set<String> _revokingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final links = await widget.clubRepository.fetchInviteLinks(widget.club.id);
      if (!mounted) return;
      setState(() => _links = links);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดรายการลิงก์เชิญไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyLink(String code) async {
    await Clipboard.setData(ClipboardData(text: clubInviteShareLink(code)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: BrowserSystemText('คัดลอกลิงก์แล้ว')),
    );
  }

  Future<void> _createLink() async {
    final choice = await _showCreateLinkSheet(context);
    if (choice == null || !mounted) return;
    setState(() => _isCreating = true);
    try {
      final link = await widget.clubRepository.createInviteLink(
        clubId: widget.club.id,
        expiresInDays: choice.expiresInDays,
        maxUses: choice.maxUses,
      );
      if (!mounted) return;
      setState(() => _links = [link, ..._links]);
      await _copyLink(link.code);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('สร้างลิงก์เชิญไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _revoke(ClubInviteLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const BrowserSystemText('เพิกถอนลิงก์นี้?'),
        content: const BrowserSystemText('ใครก็ตามที่ถือลิงก์นี้อยู่จะใช้ไม่ได้อีกทันที'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const BrowserSystemText('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const BrowserSystemText('เพิกถอนลิงก์'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revokingIds.add(link.id));
    try {
      await widget.clubRepository.revokeInviteLink(link.id);
      if (!mounted) return;
      setState(() {
        _links = _links.where((l) => l.id != link.id).toList();
        _revokingIds.remove(link.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _revokingIds.remove(link.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('เพิกถอนลิงก์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  void _showLinkMenu(ClubInviteLink link) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.delete_outline,
          label: 'เพิกถอนลิงก์นี้',
          color: Theme.of(sheetContext).colorScheme.error,
          onTap: () {
            Navigator.of(sheetContext).pop();
            _revoke(link);
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrowserSystemText('ลิงก์เชิญ')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createLink,
        icon: _isCreating
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: const BrowserSystemText('สร้างลิงก์เชิญใหม่'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrowserSystemText(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _load, child: const BrowserSystemText('ลองใหม่')),
          ],
        ),
      );
    }

    // Requirement/Design doc: for a Private Club (invite link = join
    // immediately, Founder's ทางเลือก A), a fresh reminder belongs at
    // the top of this whole screen -- not just once at link-creation
    // time -- since it's the risk every link on this list already
    // carries, not something specific to the newest one.
    final showPrivacyWarning = widget.club.privacy == ClubPrivacy.private;

    if (_links.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (showPrivacyWarning) _buildPrivacyWarningBanner(context),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: WynSpacing.space8, horizontal: WynSpacing.space6),
            child: BrowserSystemText(
              'ยังไม่มีลิงก์เชิญ — สร้างลิงก์แรกเพื่อแชร์ Club นี้ไปที่อื่นได้เลย',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: WynSpacing.space8 * 2),
      itemCount: _links.length + (showPrivacyWarning ? 1 : 0),
      itemBuilder: (context, index) {
        if (showPrivacyWarning) {
          if (index == 0) return _buildPrivacyWarningBanner(context);
          return _buildLinkRow(context, _links[index - 1]);
        }
        return _buildLinkRow(context, _links[index]);
      },
    );
  }

  Widget _buildPrivacyWarningBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space3,
        WynSpacing.space4,
        WynSpacing.space2,
      ),
      padding: const EdgeInsets.all(WynSpacing.space3),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: BrowserSystemText(
              'ใครก็ตามที่มีลิงก์นี้จะเข้าร่วม Club ส่วนตัวนี้ได้ทันที '
              'โดยไม่ต้องรออนุมัติ — ระวังอย่าแชร์ต่อไปยังคนที่ไม่ต้องการให้เข้าร่วม',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  String _usageLabel(ClubInviteLink link) =>
      link.maxUses == null ? 'ใช้ไปแล้ว ${link.useCount} ครั้ง' : 'ใช้ไปแล้ว ${link.useCount}/${link.maxUses} ครั้ง';

  String _expiryLabel(ClubInviteLink link) {
    final expiresAt = link.expiresAt;
    if (expiresAt == null) return 'ไม่มีวันหมดอายุ';
    if (link.isExpired) return 'หมดอายุแล้ว';
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;
    return daysLeft <= 0 ? 'หมดอายุวันนี้' : 'หมดอายุใน $daysLeft วัน';
  }

  Widget _buildLinkRow(BuildContext context, ClubInviteLink link) {
    final isRevoking = _revokingIds.contains(link.id);
    final statusSuffix = link.isExpired
        ? ' · หมดอายุแล้ว'
        : (link.isExhausted ? ' · ใช้ครบแล้ว' : '');
    return Opacity(
      opacity: link.isActive ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrowserSystemText(
                    clubInviteShareLink(link.code).replaceFirst('https://', ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  BrowserSystemText(
                    '${_usageLabel(link)} · ${_expiryLabel(link)} · สร้างเมื่อ ${dateLabel(link.createdAt)}'
                    '$statusSuffix',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            BrowserSystemTooltip(message: 'คัดลอกลิงก์', child: IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              tooltip: null,
              onPressed: () => _copyLink(link.code),
            )),
            isRevoking
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : BrowserSystemTooltip(message: 'ตัวเลือกเพิ่มเติม', child: IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: null,
                    onPressed: () => _showLinkMenu(link),
                  )),
          ],
        ),
      ),
    );
  }
}

/// A [_CreateInviteLinkSheet]'s own result -- both fields null means
/// "ไม่มีวันหมดอายุ" + "ไม่จำกัด".
typedef _CreateLinkChoice = ({int? expiresInDays, int? maxUses});

Future<_CreateLinkChoice?> _showCreateLinkSheet(BuildContext context) {
  return showModalBottomSheet<_CreateLinkChoice>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _CreateInviteLinkSheet(),
  );
}

class _CreateInviteLinkSheet extends StatefulWidget {
  const _CreateInviteLinkSheet();

  @override
  State<_CreateInviteLinkSheet> createState() => _CreateInviteLinkSheetState();
}

class _CreateInviteLinkSheetState extends State<_CreateInviteLinkSheet> {
  // Design spec: 4 choices each, null = "ไม่มีวันหมดอายุ"/"ไม่จำกัด".
  static const _expiryChoices = <int?>[null, 1, 7, 30];
  static const _maxUsesChoices = <int?>[null, 10, 50, 100];

  int? _expiresInDays;
  int? _maxUses;

  String _expiryLabel(int? days) => switch (days) {
        null => 'ไม่มีวันหมดอายุ',
        1 => '1 วัน',
        _ => '$days วัน',
      };

  String _maxUsesLabel(int? uses) => switch (uses) {
        null => 'ไม่จำกัด',
        _ => '$uses ครั้ง',
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: WynSpacing.space4,
          right: WynSpacing.space4,
          bottom: MediaQuery.of(context).viewInsets.bottom + WynSpacing.space4,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: WynSpacing.space2),
              const SheetDragHandle(),
              BrowserSystemText('สร้างลิงก์เชิญใหม่', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: WynSpacing.space4),
              BrowserSystemText('วันหมดอายุ', style: Theme.of(context).textTheme.labelLarge),
              for (final choice in _expiryChoices)
                _RadioRow(
                  label: _expiryLabel(choice),
                  selected: choice == _expiresInDays,
                  onTap: () => setState(() => _expiresInDays = choice),
                ),
              const SizedBox(height: WynSpacing.space2),
              BrowserSystemText('จำนวนครั้งใช้งานสูงสุด', style: Theme.of(context).textTheme.labelLarge),
              for (final choice in _maxUsesChoices)
                _RadioRow(
                  label: _maxUsesLabel(choice),
                  selected: choice == _maxUses,
                  onTap: () => setState(() => _maxUses = choice),
                ),
              const SizedBox(height: WynSpacing.space4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop((
                    expiresInDays: _expiresInDays,
                    maxUses: _maxUses,
                  )),
                  child: const BrowserSystemText('สร้างลิงก์'),
                ),
              ),
              const SizedBox(height: WynSpacing.space2),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same pseudo-radio shape `settings_screen.dart`'s
/// `_showPermissionPicker`/`_showLikesVisibilityPicker` already use
/// (`Icons.radio_button_checked`/`radio_button_unchecked`, not
/// `RadioListTile` -- deprecated as of the Flutter version this app
/// targets).
class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: selected,
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: BrowserSystemText(label),
        onTap: onTap,
      ),
    );
  }
}
