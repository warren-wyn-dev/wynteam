import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../block/data/block_repository.dart';
import '../../block/presentation/blocked_list_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Minimal Settings screen (WYN-027) -- the full Settings (Master Spec
/// section 35: Account/Privacy/Notifications/Security/Safety/Data/
/// Legal) is WYN-045 (Phase 5), not started yet. This round adds only
/// the "ความปลอดภัย" (Safety) section, since Blocked List needs
/// *somewhere* to live per the Product spec ("Unblock ได้จากหน้า
/// Settings → Safety → Blocked List เท่านั้น"). Deliberately not
/// pre-building empty sections for the other 6 categories -- a menu
/// that opens to nothing yet is worse than no menu at all. See
/// .wyn/docs/design/wyn-027-block-system.md, Screen 4.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        ],
      ),
    );
  }
}
