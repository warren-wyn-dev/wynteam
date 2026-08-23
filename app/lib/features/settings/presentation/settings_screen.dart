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
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// Minimal Settings screen (WYN-027/028, "เครื่องมือผู้ดูแล" section added
/// by WYN-029) -- the full Settings (Master Spec section 35: Account/
/// Privacy/Notifications/Security/Safety/Data/Legal) is WYN-045
/// (Phase 5), not started yet. This round adds only the "ความปลอดภัย"
/// (Safety) section, since Blocked List/Muted List need *somewhere* to
/// live per the Product specs ("Unblock ได้จากหน้า Settings → Safety →
/// Blocked List เท่านั้น" / "Unmute ได้จาก Settings → Safety → Muted
/// List"), plus a hidden entry point into the Moderation Queue for
/// moderator/admin accounts only. Deliberately not pre-building empty
/// sections for the other 6 categories -- a menu that opens to nothing
/// yet is worse than no menu at all. See
/// .wyn/docs/design/wyn-027-block-system.md, Screen 4,
/// .wyn/docs/design/wyn-028-mute-system.md, Screen 3, and
/// .wyn/docs/design/wyn-029-moderation-queue.md, Screen 1.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.platformRole});

  /// Passed in directly from ViewProfileScreen's already-fetched own
  /// profile (WYN-029, Screen 1) -- deliberately not queried again here.
  /// Besides saving a query, this is a real security-in-depth property:
  /// the value driving "should this section render at all" comes from a
  /// row RLS already confirmed belongs to `auth.uid()` itself, with no
  /// way for this widget to be handed some *other* user's role from the
  /// UI layer.
  final PlatformRole platformRole;

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
          if (platformRole != PlatformRole.user) ...[
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
