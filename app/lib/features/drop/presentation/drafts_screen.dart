import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_typography.dart';
import '../../profile/data/profile_repository.dart';
import '../data/drop_repository.dart';
import 'widgets/draft_list.dart';

/// "ร่าง" -- the saved-drafts screen, reached from the post composer's
/// own header (see [CreateDropScreen]).
///
/// Beta4 §5: "Draft ไม่อยู่ใน Profile ... สร้างโพสต์ → ร่าง". Before
/// this, the only way to a Draft was an unlabelled `edit_note` icon on
/// your own profile, next to "แก้ไขโปรไฟล์" -- two taps away from the
/// composer, on the screen a draft is by definition *not* on yet. The
/// destination is now one tap from the place a draft is written and the
/// place it is resumed, which is the same place.
///
/// A thin screen on purpose: the list itself is [DraftList], unchanged
/// from when it was a profile tab, so no Draft behaviour moved with the
/// entry point. This exists to give it an AppBar styled like the rest
/// of the composer flow instead of the bare `AppBar(title: Text('ร่าง'))`
/// the profile's own `_openDrafts` used to build inline.
class DraftsScreen extends StatelessWidget {
  const DraftsScreen({
    super.key,
    required this.dropRepository,
    this.profileRepository,
  });

  final DropRepository dropRepository;

  /// Optional/defaulted, same shape as [CreateDropScreen]'s own -- this
  /// screen needs one only to hand on to the composer it opens when a
  /// draft is tapped.
  final ProfileRepository? profileRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          tooltip: 'ย้อนกลับ',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'ร่าง',
          style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: DraftList(
        dropRepository: dropRepository,
        profileRepository:
            profileRepository ?? ProfileRepository(Supabase.instance.client),
      ),
    );
  }
}
