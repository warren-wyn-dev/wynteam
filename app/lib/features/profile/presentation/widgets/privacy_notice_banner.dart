import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/wyn_spacing.dart';

/// A one-time, non-blocking notice pinned above a tab's content -- WYN-064
/// Design, Screen 7. Used on Profile's "Replies"/"Likes" tabs (own
/// profile only) to tell the owner these are now public, the first time
/// they open either tab -- persisted per [prefsKey] via
/// `shared_preferences` (a per-device UI flag, not data that needs to
/// sync across devices, so no schema/RLS involved) so it shows once
/// total, not once per app launch. Never blocks the tab's own content
/// underneath -- that still scrolls normally whether or not this is
/// still visible.
class PrivacyNoticeBanner extends StatefulWidget {
  const PrivacyNoticeBanner({super.key, required this.prefsKey, required this.message});

  final String prefsKey;
  final String message;

  @override
  State<PrivacyNoticeBanner> createState() => _PrivacyNoticeBannerState();
}

class _PrivacyNoticeBannerState extends State<PrivacyNoticeBanner> {
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
      setState(() => _shouldShow = !(prefs.getBool(widget.prefsKey) ?? false));
    } catch (_) {
      if (!mounted) return;
      setState(() => _shouldShow = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _shouldShow = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(widget.prefsKey, true);
    } catch (_) {
      // Worst case it shows again next time -- not worth surfacing an
      // error for a one-time informational banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShow != true) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space2,
        WynSpacing.space4,
        0,
      ),
      padding: const EdgeInsets.all(WynSpacing.space3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: Text(widget.message,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Semantics(
            label: 'ปิดข้อความแจ้งเตือน',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: _dismiss,
              borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
