import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
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
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../../saved/data/saved_repository.dart';
import '../data/data_rights_repository.dart';
import '../data/notification_settings_repository.dart';
import 'delete_account_screen.dart';
import 'notification_settings_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Minimal Settings screen (WYN-027/028, "เครื่องมือผู้ดูแล" section added
/// by WYN-029, "ความเป็นส่วนตัว" section added by WYN-039) -- the full
/// Settings (Master Spec section 35: Account/Privacy/Notifications/
/// Security/Safety/Data/Legal) is WYN-045 (Phase 5), not started yet.
/// Each round adds only the one section it actually needs, since Blocked
/// List/Muted List/the Private Account toggle all need *somewhere* to
/// live per their own Product specs. Deliberately not pre-building empty
/// sections for the other categories -- a menu that opens to nothing yet
/// is worse than no menu at all. See
/// .wyn/docs/design/wyn-027-block-system.md, Screen 4,
/// .wyn/docs/design/wyn-028-mute-system.md, Screen 3,
/// .wyn/docs/design/wyn-029-moderation-queue.md, Screen 1, and
/// .wyn/docs/design/wyn-039-private-account-follow-request.md, Screen 1.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.platformRole,
    required this.isPrivate,
    this.dmPermission = InteractionPermission.everyone,
    this.mentionPermission = InteractionPermission.everyone,
    this.commentPermission = InteractionPermission.everyone,
    this.profileRepository,
    this.dataRightsRepository,
    this.authRepository,
  });

  /// Passed in directly from ViewProfileScreen's already-fetched own
  /// profile (WYN-029, Screen 1) -- deliberately not queried again here.
  /// Besides saving a query, this is a real security-in-depth property:
  /// the value driving "should this section render at all" comes from a
  /// row RLS already confirmed belongs to `auth.uid()` itself, with no
  /// way for this widget to be handed some *other* user's role from the
  /// UI layer.
  final PlatformRole platformRole;

  /// Same "passed in from ViewProfileScreen's already-fetched profile,
  /// not re-queried" reasoning as [platformRole] -- WYN-039's Privacy
  /// toggle's initial value.
  final bool isPrivate;

  /// WYN-045's 3 Interaction Privacy Controls -- same "passed in from
  /// ViewProfileScreen's already-fetched profile" reasoning as
  /// [isPrivate], but defaulted to InteractionPermission.everyone
  /// (rather than required like [isPrivate]/[platformRole]) since that
  /// is genuinely the correct value for any caller that doesn't have a
  /// freshly-fetched Profile at hand -- it's these columns' own DB
  /// default (supabase/schema.sql) for every account that has never
  /// touched this section, so there is no meaningfully-different
  /// fallback to force every call site to spell out.
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

  /// Same "optional/defaulted" shape again -- WYN-073's "ออกจากระบบ" row
  /// (see [_SettingsScreenState._signOut]), same pattern
  /// DeleteAccountScreen already uses for its own real sign-out.
  final AuthRepository? authRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? ProfileRepository(Supabase.instance.client);
  late final DataRightsRepository _dataRightsRepository =
      widget.dataRightsRepository ??
          DataRightsRepository(Supabase.instance.client);
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository(Supabase.instance.client);
  late bool _isPrivate = widget.isPrivate;
  bool _isTogglingPrivate = false;
  bool _isExporting = false;
  bool _isSigningOut = false;

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

  /// WYN-073: "ออกจากระบบ" row, moved here from the standalone header
  /// icon `ViewProfileScreen` used to have on the viewer's own profile
  /// -- an infrequent, higher-consequence action that belongs inside
  /// Settings rather than sitting in the profile header with equal
  /// visual weight to the gear icon itself. Confirms first (plain
  /// `AlertDialog`, no red styling -- same `confirmBlock`/
  /// `confirmUnblock` shape as block_dialogs.dart, sign-out being far
  /// less severe/irreversible than DeleteAccountScreen's own red
  /// "ลบบัญชีถาวร" confirm), then runs the exact same 2-step sequence
  /// `ViewProfileScreen._signOut`/`DeleteAccountScreen._startDeletion`
  /// already use: best-effort push-token deregistration first (must
  /// never block/fail sign-out itself), then a real sign-out via
  /// [AuthRepository] -- no navigation call here; AuthGate's own
  /// auth-state listener pops back to WelcomeScreen once the session
  /// clears.
  Future<void> _signOut() async {
    if (_isSigningOut) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('ออกจากระบบ?'),
            content: const Text('คุณจะต้องเข้าสู่ระบบใหม่อีกครั้งในครั้งถัดไป'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('ออกจากระบบ'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await PushNotificationService(
              PushTokenRepository(Supabase.instance.client))
          .unregisterCurrentDevice();
    } catch (_) {
      // Intentionally silent -- see ViewProfileScreen._signOut's own
      // doc comment (moved here verbatim, same reasoning).
    }
    await _authRepository.signOut();
    // No further setState after signOut() -- same posture as
    // DeleteAccountScreen._startDeletion's own success path.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
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
              'ความเป็นส่วนตัว',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('บัญชีส่วนตัว (Private Account)'),
            subtitle: const Text(
                'เฉพาะผู้ติดตามที่คุณอนุมัติเท่านั้นที่จะเห็น Drop ของคุณได้'),
            value: _isPrivate,
            onChanged: _isTogglingPrivate ? null : _setIsPrivate,
          ),
          // WYN-045 -- 3 more rows in this same "ความเป็นส่วนตัว" section,
          // right after Private Account (Design spec: DM -> Mention ->
          // Comment, ordered most- to least- likely to reach a stranger
          // first).
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
          // WYN-044 -- unconditional for every platformRole (unlike
          // "เครื่องมือผู้ดูแล" below), since notification preferences
          // belong to every user regardless of role.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space1,
            ),
            child: Text(
              'การแจ้งเตือน',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('การแจ้งเตือน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationSettingsScreen(
                  notificationSettingsRepository:
                      NotificationSettingsRepository(Supabase.instance.client),
                ),
              ));
            },
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
          // WYN-047 -- right before "กฎหมาย" (still one of the last
          // sections, but not the very last one -- "ข้อมูลของฉัน" is an
          // action a user actually needs occasionally, unlike the legal
          // reference documents below that almost nobody ever opens).
          // See .wyn/docs/design/wyn-047-data-rights.md.
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
          // WYN-046 -- always the very last section on the page,
          // regardless of platformRole (unlike "เครื่องมือผู้ดูแล" above,
          // which is conditional) -- these are read-only reference
          // documents nobody taps often, so they belong last rather than
          // mixed in with the higher-traffic sections above. See
          // .wyn/docs/design/wyn-046-platform-documents-acceptance.md.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space4,
              WynSpacing.space1,
            ),
            child: Text(
              'กฎหมาย',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const _LegalDocumentTile(
            title: 'ข้อกำหนดการใช้งาน',
            documentType: PlatformDocumentType.termsOfService,
          ),
          const _LegalDocumentTile(
            title: 'นโยบายความเป็นส่วนตัว',
            documentType: PlatformDocumentType.privacyPolicy,
          ),
          const _LegalDocumentTile(
            title: 'แนวทางชุมชน',
            documentType: PlatformDocumentType.communityGuidelines,
          ),
          const _LegalDocumentTile(
            title: 'นโยบายลิขสิทธิ์',
            documentType: PlatformDocumentType.copyrightPolicy,
          ),
          const _LegalDocumentTile(
            title: 'นโยบายการรายงาน',
            documentType: PlatformDocumentType.reportPolicy,
          ),
          const _LegalDocumentTile(
            title: 'นโยบายการอุทธรณ์',
            documentType: PlatformDocumentType.appealPolicy,
          ),
          // WYN-073 -- always the very last thing on the page, separated
          // from "กฎหมาย" above with extra breathing room + a divider
          // rather than sitting flush against it, per `/11-settings.tsx`'s
          // own convention ("logout ... separated, muted red-free (still
          // just graphite text), with extra spacing above it so it
          // doesn't blend into the list above it") -- borrowed for this
          // row's placement/tone only; the rest of this screen keeps its
          // existing Material/WynTheme styling, `/11-settings.tsx` itself
          // being a full restyle that's a separate, not-yet-started
          // screen in the WYNOS design-reference rollout.
          const SizedBox(height: WynSpacing.space4),
          const Divider(height: 1),
          const SizedBox(height: WynSpacing.space2),
          ListTile(
            leading: _isSigningOut
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.logout,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
            title: Text(
              'ออกจากระบบ',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onTap: _isSigningOut ? null : _signOut,
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
/// levels, both in a `SettingsScreen` row's trailing summary and as
/// each option's title inside `_showPermissionPicker`'s bottom sheet.
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
