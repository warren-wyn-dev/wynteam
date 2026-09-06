import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/platform/add_to_home_screen_support.dart';

/// A dismissible banner above the Home feed's sticky tabs, offering to
/// walk a web visitor through adding WYNOS to their home screen (the
/// "smart app banner" pattern most installable web apps use). Hidden
/// outright on native iOS/Android builds and once WYNOS is already
/// running as an installed PWA -- both already *are* an installed app,
/// so there is nothing to offer. Once dismissed it stays hidden for
/// good, same shown-until-dismissed shape as [HomeExplainerBanner]
/// (a per-device UI flag via `shared_preferences`, not something that
/// needs to sync across devices).
class AddToHomeScreenBanner extends StatefulWidget {
  const AddToHomeScreenBanner({super.key});

  static const _prefsKey = 'add_to_home_screen_banner_dismissed';

  @override
  State<AddToHomeScreenBanner> createState() => _AddToHomeScreenBannerState();
}

class _AddToHomeScreenBannerState extends State<AddToHomeScreenBanner> {
  // Null until the pref read resolves -- stays hidden meanwhile rather
  // than flashing visible-then-hidden for a returning user (mirrors
  // HomeExplainerBanner's identical _shouldShow shape).
  bool? _shouldShow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // shouldOfferAddToHomeScreen() is already false on every non-web
    // build (see its own doc comment) -- no separate kIsWeb check needed.
    if (!shouldOfferAddToHomeScreen()) {
      setState(() => _shouldShow = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _shouldShow =
          !(prefs.getBool(AddToHomeScreenBanner._prefsKey) ?? false));
    } catch (_) {
      if (!mounted) return;
      setState(() => _shouldShow = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _shouldShow = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AddToHomeScreenBanner._prefsKey, true);
    } catch (_) {
      // Worst case it shows again next time -- not worth surfacing an
      // error for a one-time informational banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShow != true) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4, WynSpacing.space1, WynSpacing.space4, WynSpacing.space1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space4, vertical: WynSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: WynColors.surfaceTint,
          border: Border.all(color: WynColors.hairline),
          borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.add_to_home_screen, size: 22, color: WynColors.sapphire),
            const SizedBox(width: WynSpacing.space3),
            const Expanded(
              child: Text(
                'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก เปิดแอปได้ไวขึ้น',
                style: TextStyle(fontSize: 13, color: WynColors.ink, height: 1.3),
              ),
            ),
            const SizedBox(width: WynSpacing.space2),
            const TextButton(
              onPressed: openAddToHomeScreenGuide,
              child: Text('ดูวิธี'),
            ),
            Semantics(
              label: 'ปิดข้อความแนะนำ',
              button: true,
              excludeSemantics: true,
              // Same DS-008-style 44x44 tap-target fix as
              // HomeExplainerBanner's identical close button.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: WynSpacing.touchTargetMin,
                  minHeight: WynSpacing.touchTargetMin,
                ),
                child: InkWell(
                  onTap: _dismiss,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                  child: const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.close, size: 17, color: WynColors.graphite),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
