import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// WYNOSHomeSpec.md item 1 -- a dark, dismissible banner shown above the
/// Home feed's sticky tabs the first time the account ever opens Home,
/// explaining WYNOS's own "ดู → แชร์ → ค้นพบ → ซื้อ" premise. Same
/// shown-once-total/persist-via-`shared_preferences` shape as
/// [PrivacyNoticeBanner] (a per-device UI flag, not data that needs to
/// sync across devices) -- a dedicated widget rather than reusing that
/// one directly since the visual (dark ink background, two-line white/
/// muted text) is a distinct treatment from that banner's neutral
/// info-notice style, not a parameterization of it.
class HomeExplainerBanner extends StatefulWidget {
  const HomeExplainerBanner({super.key});

  /// WYN-107: public (was `_prefsKey`) so `AddToHomeScreenBanner` can
  /// check whether this banner has already been dismissed without
  /// duplicating the string literal (see that widget's own doc comment
  /// on why it waits for this one to be dismissed first).
  static const prefsKey = 'home_explainer_banner_dismissed';

  @override
  State<HomeExplainerBanner> createState() => _HomeExplainerBannerState();
}

class _HomeExplainerBannerState extends State<HomeExplainerBanner> {
  // Null until the pref read resolves -- stays hidden meanwhile rather
  // than flashing visible-then-hidden for a returning user.
  bool? _shouldShow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() =>
          _shouldShow = !(prefs.getBool(HomeExplainerBanner.prefsKey) ?? false));
    } catch (_) {
      if (!mounted) return;
      setState(() => _shouldShow = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _shouldShow = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(HomeExplainerBanner.prefsKey, true);
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
        WynSpacing.space4, WynSpacing.space3, WynSpacing.space4, WynSpacing.space1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space4, vertical: WynSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: WynColors.ink,
          borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ดู → แชร์ → ค้นพบ → ซื้อ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WynColors.paper,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'WYNOS คือพื้นที่โซเชียลที่ต่อยอดจากสิ่งที่คุณชอบเห็น',
                    style: TextStyle(
                      fontSize: 12,
                      color: WynColors.mutedNeutral,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: WynSpacing.space2),
            Semantics(
              label: 'ปิดข้อความแนะนำ',
              button: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: _dismiss,
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 15, color: WynColors.graphite),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
