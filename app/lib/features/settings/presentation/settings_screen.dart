import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../block/data/block_repository.dart';
import '../../block/presentation/blocked_list_screen.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/recently_deleted_drops_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/moderation_queue_screen.dart';
import '../../mute/data/mute_repository.dart';
import '../../mute/presentation/muted_list_screen.dart';
import '../../notification/data/notification_settings_repository.dart';
import '../../notification/presentation/notification_settings_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// Minimal Settings screen (WYN-027/028, "เครื่องมือผู้ดูแล" section added
/// by WYN-029, "ความเป็นส่วนตัว" section added by WYN-039, "การแจ้งเตือน"
/// section added by WYN-044) -- the full
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
    this.profileRepository,
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

  /// Optional/defaulted to Supabase.instance.client when omitted, same
  /// shape as every other repository this app threads through
  /// optionally (see ViewProfileScreen's own comment on the pattern).
  final ProfileRepository? profileRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? ProfileRepository(Supabase.instance.client);
  late bool _isPrivate = widget.isPrivate;
  bool _isTogglingPrivate = false;

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
            leading: const Icon(Icons.notifications_none),
            title: const Text('ตั้งค่าการแจ้งเตือน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationSettingsScreen(
                    notificationSettingsRepository:
                        NotificationSettingsRepository(Supabase.instance.client),
                  ),
                ),
              );
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
        ],
      ),
    );
  }
}
