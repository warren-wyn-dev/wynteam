import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../account_switcher/data/account_switcher_repository.dart';
import '../../account_switcher/presentation/account_switcher_sheet.dart';
import '../../block/data/block_repository.dart';
import '../../block/presentation/blocked_list_screen.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/recently_deleted_drops_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../legal/data/platform_document_repository.dart';
import '../../legal/presentation/document_viewer_screen.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/moderation_queue_screen.dart';
import '../../mute/data/mute_repository.dart';
import '../../mute/presentation/muted_list_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../data/data_rights_repository.dart';
import '../data/notification_settings_repository.dart';
import 'delete_account_screen.dart';
import 'notification_settings_screen.dart';

/// 11-settings.tsx -- restyled to the reference's exact 7-row list
/// (บัญชี/ความเป็นส่วนตัว, การแจ้งเตือน/ธีมเข้ม, ช่วยเหลือ/ข้อกำหนดฯ, then a
/// separated ออกจากระบบ row), grouped-list pattern (GroupLabel + Row,
/// same shape as Explore Club's "กำลังนิยม"/"ใหม่ล่าสุด" section labels).
///
/// The mockup's own list is a screenshot simplification, not a real
/// information architecture -- this app's actual Settings has ~20 real,
/// working rows across Privacy/Notifications/Security/Admin
/// tools/Data rights/Legal (WYN-027/028/029/039/044/045/046/047), none of
/// which are reachable from anywhere else in the app. Founder decision
/// 2026-08-29 (asked via AskUserQuestion): keep the top-level page
/// pixel-matched to the mockup's 7 rows, but relocate -- never delete --
/// that real functionality one level deeper, behind the two rows a user
/// would naturally expect it under:
///   - "บัญชี" -> [_AccountManagementScreen] (ความปลอดภัย: blocked/muted/
///     recently-deleted, the conditional "เครื่องมือผู้ดูแล" admin section,
///     and "ข้อมูลของฉัน": export/delete account)
///   - "ความเป็นส่วนตัว" -> [_PrivacyScreen] (Private Account toggle + the
///     3 WYN-045 DM/Mention/Comment permission rows)
///   - "ข้อกำหนดและความเป็นส่วนตัว" -> [_LegalScreen] (all 6 WYN-046 legal
///     documents, unchanged)
///
/// "ธีมเข้ม" and "ช่วยเหลือ" are shown disabled (muted colors, no chevron,
/// no onTap) rather than wired to something real or silently dropped, per
/// the same Founder decision: this app is forced to `ThemeMode.light`
/// always (WYN-071, main.dart's own comment) so a working dark-theme
/// toggle would contradict that decision, and there is no Help/FAQ screen
/// anywhere in the app to point the row at.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.platformRole,
    required this.isPrivate,
    this.dmPermission = InteractionPermission.everyone,
    this.mentionPermission = InteractionPermission.everyone,
    this.commentPermission = InteractionPermission.everyone,
    this.profileRepository,
    this.dataRightsRepository,
  });

  /// Passed in directly from ViewProfileScreen's already-fetched own
  /// profile (WYN-029, Screen 1) -- deliberately not queried again here.
  final PlatformRole platformRole;

  final bool isPrivate;
  final InteractionPermission dmPermission;
  final InteractionPermission mentionPermission;
  final InteractionPermission commentPermission;

  /// Optional/defaulted to Supabase.instance.client when omitted, same
  /// shape as every other repository this app threads through
  /// optionally (see ViewProfileScreen's own comment on the pattern).
  final ProfileRepository? profileRepository;

  /// Same "optional/defaulted" shape as [profileRepository] -- WYN-047's
  /// export/delete RPCs.
  final DataRightsRepository? dataRightsRepository;

  /// WYN-016: best-effort -- deregistering this device's push token must
  /// never block or fail sign-out itself. 05-profile.tsx moves the
  /// standalone header logout icon into this screen instead -- see the
  /// last row below -- so this is the one place that action lives now.
  ///
  /// Multi-account switching: if this device has other accounts added,
  /// logging out of this one lands you straight on the next rather than
  /// WelcomeScreen -- same "logging out never leaves the app with zero
  /// accounts while others are still added" behavior as Instagram/
  /// Twitter. Only removes/switches after the real sign-out above has
  /// already revoked this session -- see AccountSwitcherRepository
  /// .forgetAndSwitchToNextIfAny's own doc comment on why the ordering
  /// matters. Best-effort, same posture as the push-token deregistration
  /// right above it -- a secure-storage hiccup here must never leave the
  /// user stuck mid-sign-out; worst case they just land on WelcomeScreen
  /// instead of another already-added account and can switch manually.
  Future<void> _signOut() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    try {
      await PushNotificationService(PushTokenRepository(client))
          .unregisterCurrentDevice();
    } catch (_) {
      // Intentionally silent -- see comment above.
    }
    await client.auth.signOut();
    if (userId != null) {
      try {
        await AccountSwitcherRepository()
            .forgetAndSwitchToNextIfAny(userId, client);
      } catch (_) {
        // Intentionally silent -- see comment above.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('ตั้งค่า', style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: ListView(
        children: [
          const _GroupLabel('บัญชี'),
          _SettingsRow(
            icon: Icons.person_outline,
            label: 'บัญชี',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _AccountManagementScreen(
                  platformRole: platformRole,
                  dataRightsRepository: dataRightsRepository,
                ),
              ),
            ),
          ),
          _SettingsRow(
            icon: Icons.lock_outline,
            label: 'ความเป็นส่วนตัว',
            isLast: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _PrivacyScreen(
                  isPrivate: isPrivate,
                  dmPermission: dmPermission,
                  mentionPermission: mentionPermission,
                  commentPermission: commentPermission,
                  profileRepository: profileRepository,
                ),
              ),
            ),
          ),
          const _GroupLabel('การตั้งค่าแอป'),
          _SettingsRow(
            icon: Icons.notifications_outlined,
            label: 'การแจ้งเตือน',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationSettingsScreen(
                notificationSettingsRepository:
                    NotificationSettingsRepository(Supabase.instance.client),
              ),
            )),
          ),
          const _SettingsRow(
            icon: Icons.dark_mode_outlined,
            label: 'ธีมเข้ม',
            isLast: true,
          ),
          const _GroupLabel('ช่วยเหลือ'),
          const _SettingsRow(
            icon: Icons.help_outline,
            label: 'ช่วยเหลือ',
          ),
          _SettingsRow(
            icon: Icons.description_outlined,
            label: 'ข้อกำหนดและความเป็นส่วนตัว',
            isLast: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _LegalScreen()),
            ),
          ),
          // ออกจากระบบ -- separated, quieter, extra breathing room above it
          // (11-settings.tsx: "grouped list pattern... logout... separated,
          // muted red-free, extra spacing above it so it doesn't blend
          // into the list above it").
          Padding(
            padding: const EdgeInsets.only(top: WynSpacing.space8, bottom: WynSpacing.space8),
            child: Column(
              children: [
                const Divider(height: 1, color: WynColors.hairline),
                const SizedBox(height: WynSpacing.space2),
                _SettingsRow(
                  icon: Icons.logout,
                  label: 'ออกจากระบบ',
                  isLast: true,
                  contentColor: WynColors.graphite,
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 11-settings.tsx's `GroupLabel` -- same shape as Explore Club's own
/// section-label component (explore_clubs_screen.dart).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space6, WynSpacing.space6, WynSpacing.space2,
      ),
      child: Text(
        label,
        style: _textStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: WynColors.mutedNeutral,
          letterSpacing: 13 * 0.14,
        ),
      ),
    );
  }
}

/// 11-settings.tsx's `Row` -- icon + label + chevron, hairline
/// border-bottom except on the last row of its group. A row with no
/// [onTap] renders disabled (muted [WynColors.faint] throughout, no
/// chevron) -- see this file's own doc comment on "ธีมเข้ม"/"ช่วยเหลือ".
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLast = false,
    this.contentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLast;

  /// Overrides the icon+label color for rows that need a quieter look
  /// than the default ink -- currently only "ออกจากระบบ" (11-settings.tsx's
  /// own doc comment: "muted red-free", still just graphite text).
  final Color? contentColor;

  bool get _enabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final color = _enabled ? (contentColor ?? WynColors.ink) : WynColors.faint;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: WynColors.hairline)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: _textStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color),
              ),
            ),
            if (_enabled)
              const Icon(Icons.chevron_right, size: 15, color: WynColors.faint),
          ],
        ),
      ),
    );
  }
}

/// The real destination behind the "บัญชี" row -- everything account-level
/// that the 11-settings.tsx mockup has no room for: WYN-027/028's
/// Blocked/Muted lists, WYN-037's Recently Deleted, WYN-029's admin-only
/// Moderation Queue, and WYN-047's data export/delete account. See this
/// file's top doc comment for the relocation rationale.
class _AccountManagementScreen extends StatefulWidget {
  const _AccountManagementScreen({
    required this.platformRole,
    this.dataRightsRepository,
  });

  final PlatformRole platformRole;
  final DataRightsRepository? dataRightsRepository;

  @override
  State<_AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<_AccountManagementScreen> {
  late final DataRightsRepository _dataRightsRepository =
      widget.dataRightsRepository ?? DataRightsRepository(Supabase.instance.client);
  bool _isExporting = false;

  /// WYN-047's "ดาวน์โหลดข้อมูลของฉัน" row -- calls export_my_data()
  /// directly from this row's onTap, no separate screen (Design spec:
  /// read-only, no risk, no extra friction needed). Shows a small
  /// spinner in the row's leading icon slot while in flight, then
  /// hands the JSON straight to the OS share sheet as an in-memory
  /// file (`XFile.fromData`) -- no need to write it to device storage
  /// first, so no new storage permission either.
  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final json = await _dataRightsRepository.exportMyData();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: 'wyn-data-export.json',
            ),
          ],
          subject: 'ข้อมูลของฉันจาก WYN',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ดาวน์โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บัญชี')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space1,
            ),
            child: Text(
              'หลายบัญชี',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('สลับบัญชี'),
            subtitle:
                const Text('เพิ่มได้สูงสุด ${AccountSwitcherRepository.maxAccounts} บัญชีต่อเครื่อง'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAccountSwitcherSheet(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space1,
            ),
            child: Text(
              'ความปลอดภัย',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('บัญชีที่ถูกบล็อก'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlockedListScreen(
                    blockRepository: BlockRepository(Supabase.instance.client),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_off),
            title: const Text('บัญชีที่ปิดเสียง'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final client = Supabase.instance.client;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MutedListScreen(
                    muteRepository: MuteRepository(client),
                    profileRepository: ProfileRepository(client),
                    followRepository: FollowRepository(client),
                    dropRepository: DropRepository(client),
                    popRepository: PopRepository(client),
                    savedRepository: SavedRepository(client),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: const Text('รายการที่ลบ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecentlyDeletedDropsScreen(
                    dropRepository: DropRepository(Supabase.instance.client),
                  ),
                ),
              );
            },
          ),
          // Whole section (heading included) hidden for platformRole ==
          // user -- an ordinary user must not see even an empty "เครื่องมือ
          // ผู้ดูแล" heading, per the Product spec's "ไม่ปรากฏในเมนูของ
          // ผู้ใช้ทั่วไป".
          if (widget.platformRole != PlatformRole.user) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WynSpacing.space4,
                WynSpacing.space4,
                WynSpacing.space4,
                WynSpacing.space1,
              ),
              child: Text(
                'เครื่องมือผู้ดูแล',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('คิวตรวจสอบรายงาน'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final client = Supabase.instance.client;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ModerationQueueScreen(
                      moderationRepository: ModerationRepository(client),
                      appealRepository: AppealRepository(client),
                      currentModeratorId: client.auth.currentUser?.id,
                      dropRepository: DropRepository(client),
                      popRepository: PopRepository(client),
                      followRepository: FollowRepository(client),
                      profileRepository: ProfileRepository(client),
                      savedRepository: SavedRepository(client),
                      clubRepository: ClubRepository(client),
                      clubPostRepository: ClubPostRepository(client),
                    ),
                  ),
                );
              },
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space1,
            ),
            child: Text(
              'ข้อมูลของฉัน',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          ListTile(
            leading: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            title: const Text('ดาวน์โหลดข้อมูลของฉัน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isExporting ? null : _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('ลบบัญชี'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeleteAccountScreen(
                    dataRightsRepository: _dataRightsRepository,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The real destination behind the "ความเป็นส่วนตัว" row -- WYN-039's
/// Private Account toggle plus WYN-045's 3 DM/Mention/Comment
/// Interaction Privacy Controls. See this file's top doc comment for the
/// relocation rationale.
class _PrivacyScreen extends StatefulWidget {
  const _PrivacyScreen({
    required this.isPrivate,
    required this.dmPermission,
    required this.mentionPermission,
    required this.commentPermission,
    this.profileRepository,
  });

  final bool isPrivate;
  final InteractionPermission dmPermission;
  final InteractionPermission mentionPermission;
  final InteractionPermission commentPermission;
  final ProfileRepository? profileRepository;

  @override
  State<_PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<_PrivacyScreen> {
  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? ProfileRepository(Supabase.instance.client);
  late bool _isPrivate = widget.isPrivate;
  bool _isTogglingPrivate = false;

  late InteractionPermission _dmPermission = widget.dmPermission;
  late InteractionPermission _mentionPermission = widget.mentionPermission;
  late InteractionPermission _commentPermission = widget.commentPermission;

  Future<void> _setIsPrivate(bool value) async {
    final previous = _isPrivate;
    setState(() {
      _isPrivate = value;
      _isTogglingPrivate = true;
    });
    try {
      await _profileRepository.updateIsPrivate(
        userId: Supabase.instance.client.auth.currentUser!.id,
        isPrivate: value,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPrivate = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isTogglingPrivate = false);
    }
  }

  /// WYN-045's 3 permission rows all funnel through this one helper --
  /// [category] picks both which state field to read/revert and which
  /// ProfileRepository method to call, so the 3 call sites below stay a
  /// one-line `onChanged` each instead of 3 near-duplicate methods.
  /// Optimistic + revert-on-fail, same shape as [_setIsPrivate] -- but
  /// deliberately no in-flight lock (unlike WYN-044's
  /// NotificationSettingsScreen): only 3 independent rows here, each a
  /// single-value upsert, so last-write-wins on a rapid re-tap is an
  /// acceptable tradeoff for not needing a per-row busy flag (Design
  /// spec's Interactions section).
  Future<void> _setPermission(
    String category,
    InteractionPermission value,
    void Function(InteractionPermission) apply,
  ) async {
    final previous = switch (category) {
      'dm_permission' => _dmPermission,
      'mention_permission' => _mentionPermission,
      'comment_permission' => _commentPermission,
      _ => throw ArgumentError('Unknown permission category: $category'),
    };

    setState(() => apply(value));
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      switch (category) {
        case 'dm_permission':
          await _profileRepository.updateDmPermission(
              userId: userId, value: value);
          break;
        case 'mention_permission':
          await _profileRepository.updateMentionPermission(
              userId: userId, value: value);
          break;
        case 'comment_permission':
          await _profileRepository.updateCommentPermission(
              userId: userId, value: value);
          break;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => apply(previous));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ความเป็นส่วนตัว')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('บัญชีส่วนตัว (Private Account)'),
            subtitle: const Text(
                'เฉพาะผู้ติดตามที่คุณอนุมัติเท่านั้นที่จะเห็น Drop ของคุณได้'),
            value: _isPrivate,
            onChanged: _isTogglingPrivate ? null : _setIsPrivate,
          ),
          _PermissionSettingTile(
            icon: Icons.mail_outline,
            title: 'ใครทักข้อความคุณได้',
            subtitle: 'ควบคุมว่าใครเริ่มบทสนทนาใหม่กับคุณได้',
            value: _dmPermission,
            onChanged: (v) =>
                _setPermission('dm_permission', v, (p) => _dmPermission = p),
          ),
          _PermissionSettingTile(
            icon: Icons.alternate_email,
            title: 'ใครกล่าวถึงคุณได้',
            subtitle: 'ควบคุมว่าใครกล่าวถึงคุณใน Drop ได้',
            value: _mentionPermission,
            onChanged: (v) => _setPermission(
                'mention_permission', v, (p) => _mentionPermission = p),
          ),
          _PermissionSettingTile(
            icon: Icons.mode_comment_outlined,
            title: 'ใครคอมเมนต์โพสต์ของคุณได้',
            subtitle: 'ควบคุมว่าใครคอมเมนต์ Drop และ Pop ของคุณได้',
            value: _commentPermission,
            onChanged: (v) => _setPermission(
                'comment_permission', v, (p) => _commentPermission = p),
          ),
        ],
      ),
    );
  }
}

/// The real destination behind the "ข้อกำหนดและความเป็นส่วนตัว" row --
/// WYN-046's 6 legal reference documents, unchanged from before this
/// restyle.
class _LegalScreen extends StatelessWidget {
  const _LegalScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('กฎหมาย')),
      body: ListView(
        children: const [
          _LegalDocumentTile(
            title: 'ข้อกำหนดการใช้งาน',
            documentType: PlatformDocumentType.termsOfService,
          ),
          _LegalDocumentTile(
            title: 'นโยบายความเป็นส่วนตัว',
            documentType: PlatformDocumentType.privacyPolicy,
          ),
          _LegalDocumentTile(
            title: 'แนวทางชุมชน',
            documentType: PlatformDocumentType.communityGuidelines,
          ),
          _LegalDocumentTile(
            title: 'นโยบายลิขสิทธิ์',
            documentType: PlatformDocumentType.copyrightPolicy,
          ),
          _LegalDocumentTile(
            title: 'นโยบายการรายงาน',
            documentType: PlatformDocumentType.reportPolicy,
          ),
          _LegalDocumentTile(
            title: 'นโยบายการอุทธรณ์',
            documentType: PlatformDocumentType.appealPolicy,
          ),
        ],
      ),
    );
  }
}

/// WYN-046 -- one row of the "กฎหมาย" section, opening
/// DocumentViewerScreen for [documentType] directly. All 6 rows share
/// this exact shape (title + chevron, no subtitle -- unlike the rows
/// above, these are plain navigation with nothing to summarize).
class _LegalDocumentTile extends StatelessWidget {
  const _LegalDocumentTile({
    required this.title,
    required this.documentType,
  });

  final String title;
  final PlatformDocumentType documentType;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              documentType: documentType,
              platformDocumentRepository:
                  PlatformDocumentRepository(Supabase.instance.client),
            ),
          ),
        );
      },
    );
  }
}

/// WYN-045 -- Thai label shown for each of the 3 shared permission
/// levels, both in a row's trailing summary and as each option's title
/// inside `_showPermissionPicker`'s bottom sheet.
String _permissionLabel(InteractionPermission value) => switch (value) {
      InteractionPermission.everyone => 'ทุกคน',
      InteractionPermission.peopleIFollow => 'คนที่ฉันติดตาม',
      InteractionPermission.noOne => 'ไม่มีใครเลย',
    };

/// WYN-045 -- the description shown under each option's label inside
/// `_showPermissionPicker`'s bottom sheet only (not in the row's own
/// trailing summary, which just shows [_permissionLabel]).
String _permissionDescription(InteractionPermission value) => switch (value) {
      InteractionPermission.everyone =>
        'ค่าเริ่มต้น — ทุกคนทำได้ ยกเว้นบัญชีที่บล็อกกัน',
      InteractionPermission.peopleIFollow =>
        'เฉพาะบัญชีที่คุณติดตามอยู่เท่านั้น',
      InteractionPermission.noOne => 'ปิดทั้งหมด ไม่มีข้อยกเว้น',
    };

/// WYN-045's one reusable row shape, used 3 times (DM/Mention/Comment)
/// per the Design spec's "widget เดียว reuse 3 ครั้ง" rule -- a `ListTile`
/// (not `SwitchListTile`, since there are 3 values, not 2) whose
/// trailing shows the current value's label + a chevron, and whose tap
/// target opens [_showPermissionPicker].
class _PermissionSettingTile extends StatelessWidget {
  const _PermissionSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final InteractionPermission value;
  final ValueChanged<InteractionPermission> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_permissionLabel(value)),
          const SizedBox(width: WynSpacing.space1),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        final selected = await _showPermissionPicker(
          context,
          title: title,
          currentValue: value,
        );
        if (selected != null) onChanged(selected);
      },
    );
  }
}

/// WYN-045 -- opens the 3-option picker bottom sheet, reusing
/// `ReportSheet`'s exact drag-handle/title/close-button/pseudo-radio
/// structure (`Icons.radio_button_checked`/`radio_button_unchecked`,
/// not `RadioListTile` -- see that file's own comment on why this
/// Flutter version avoids it). Unlike `ReportSheet`, there is no
/// separate "submit" step: tapping an option pops the sheet with that
/// value immediately (Design spec's Interactions -- apply instantly,
/// don't wait for the API call to resolve before closing).
Future<InteractionPermission?> _showPermissionPicker(
  BuildContext context, {
  required String title,
  required InteractionPermission currentValue,
}) {
  return showModalBottomSheet<InteractionPermission>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: WynSpacing.space2),
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: WynSpacing.space4),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                SizedBox(
                  width: WynSpacing.touchTargetMin,
                  height: WynSpacing.touchTargetMin,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close),
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WynSpacing.space2),
            for (final option in InteractionPermission.values)
              Semantics(
                label: _permissionLabel(option),
                selected: option == currentValue,
                excludeSemantics: true,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    option == currentValue
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: option == currentValue
                        ? Theme.of(sheetContext).colorScheme.primary
                        : null,
                  ),
                  title: Text(_permissionLabel(option)),
                  subtitle: Text(_permissionDescription(option)),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              ),
            const SizedBox(height: WynSpacing.space4),
          ],
        ),
      ),
    ),
  );
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
