import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/web/home_screen_platform.dart';
import 'add_to_home_screen_sheet.dart';
import 'home_explainer_banner.dart';

/// WYN-107 (Add to Home Screen prompt), Screen 1 -- a light, single-line
/// "teaser" banner shown under [HomeExplainerBanner] telling web users
/// there's a way to add WYNOS to their home screen, and opening
/// [showAddToHomeScreenSheet] (Screen 2's full step-by-step instructions)
/// when tapped.
///
/// Mirrors `PrivacyNoticeBanner`'s light `surfaceContainer` treatment,
/// deliberately **not** [HomeExplainerBanner]'s dark `ink` one -- two
/// dark banners stacked on a brand-new user's first Home load would read
/// as a wall of text; see the design doc's "ทิศทางภาพรวม" section for the
/// full reasoning.
///
/// Only ever shown when [isAddToHomeScreenEligible] (kIsWeb + not
/// standalone + iOS Safari/Android Chrome), [HomeExplainerBanner] has
/// already been dismissed (so the two banners never stack on a first
/// load), and it isn't currently snoozed.
///
/// Persistence is a **recurring snooze, not a permanent dismiss** --
/// Founder decision, 2026-09-03 (see the design doc's Open Questions):
/// tapping X writes [snoozedAtPrefsKey] as an epoch-millis `DateTime`
/// (not a boolean `dismissed` flag like [HomeExplainerBanner]/
/// `PrivacyNoticeBanner` use), and the banner reappears once
/// [kSnoozeDuration] has passed since then. The only thing that stops it
/// for good is [isRunningStandalone] actually being true.
///
/// [isWeb]/[isStandalone]/[platformKind]/[now] are all injectable
/// (defaulting to the real `kIsWeb`/[isRunningStandalone]/
/// [detectWebPlatformKind]/`DateTime.now`) purely so widget tests can
/// fake a browser environment and a fake clock without either -- see
/// add_to_home_screen_banner_test.dart.
class AddToHomeScreenBanner extends StatefulWidget {
  const AddToHomeScreenBanner({
    super.key,
    this.isWeb = kIsWeb,
    this.isStandalone = isRunningStandalone,
    this.platformKind = detectWebPlatformKind,
    this.now = DateTime.now,
  });

  final bool isWeb;
  final bool Function() isStandalone;
  final WebPlatformKind Function() platformKind;
  final DateTime Function() now;

  /// The recurring-snooze pref key -- stores an epoch-millis int
  /// (`lastSnoozedAt`), not a boolean. See this class's own doc comment.
  static const snoozedAtPrefsKey = 'add_to_home_screen_banner_last_snoozed_at';

  /// How long a tap on X hides the banner for before it reappears -- a
  /// named constant (not a hardcoded literal at each call site) so the
  /// Founder can retune it later without a data migration, per the
  /// design doc's own rationale for choosing 7 days as the default.
  static const kSnoozeDuration = Duration(days: 7);

  @override
  State<AddToHomeScreenBanner> createState() => _AddToHomeScreenBannerState();
}

class _AddToHomeScreenBannerState extends State<AddToHomeScreenBanner> {
  // Null until every check below resolves -- stays hidden meanwhile
  // rather than flashing visible-then-hidden, same posture as
  // HomeExplainerBanner/PrivacyNoticeBanner's own `_shouldShow`.
  bool? _shouldShow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Platform eligibility is re-checked live on every mount, never
    // cached in shared_preferences -- standalone status can change
    // between sessions the moment a user actually installs (design
    // doc's Platform Detection §3).
    if (!isAddToHomeScreenEligible(
      isWeb: widget.isWeb,
      isStandalone: widget.isStandalone,
      platformKind: widget.platformKind,
    )) {
      if (!mounted) return;
      setState(() => _shouldShow = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      // Never show alongside HomeExplainerBanner's own dark banner on a
      // brand-new user's first load -- see this class's own doc comment.
      final explainerDismissed =
          prefs.getBool(HomeExplainerBanner.prefsKey) ?? false;
      if (!explainerDismissed) {
        setState(() => _shouldShow = false);
        return;
      }

      final snoozedAtMillis =
          prefs.getInt(AddToHomeScreenBanner.snoozedAtPrefsKey);
      if (snoozedAtMillis != null) {
        final snoozedAt = DateTime.fromMillisecondsSinceEpoch(snoozedAtMillis);
        if (widget.now().difference(snoozedAt) <
            AddToHomeScreenBanner.kSnoozeDuration) {
          setState(() => _shouldShow = false);
          return;
        }
      }

      setState(() => _shouldShow = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _shouldShow = false);
    }
  }

  Future<void> _snooze() async {
    setState(() => _shouldShow = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        AddToHomeScreenBanner.snoozedAtPrefsKey,
        widget.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Worst case it shows again next load -- not worth surfacing an
      // error for a one-time informational banner (same posture as
      // HomeExplainerBanner/PrivacyNoticeBanner's own dismiss handler).
    }
  }

  // Tapping the banner body opens Screen 2's sheet -- deliberately does
  // NOT touch snooze state (design doc: "ไม่ snooze banner ทันทีตอนแตะ").
  void _openSheet() {
    showAddToHomeScreenSheet(context, platformKind: widget.platformKind);
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShow != true) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        WynSpacing.space4, WynSpacing.space2, WynSpacing.space4, 0,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The tappable "open sheet" region is scoped to just this
              // icon+text InkWell/Semantics pair -- NOT the whole Row --
              // so it never nests inside (or around) the close button's
              // own Semantics below. An outer Semantics(excludeSemantics:
              // true) wrapping both regions would silently drop the
              // close button's distinct "ปิดข้อความแนะนำ" node from the
              // accessibility tree (excludeSemantics discards ALL
              // descendant semantics, nested Semantics widgets included),
              // making it unreachable for screen readers -- exactly what
              // the design doc's Accessibility line and
              // HomeExplainerBanner's own pattern both require staying
              // separate.
              Expanded(
                child: InkWell(
                  onTap: _openSheet,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                  child: Semantics(
                    label: 'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก แตะเพื่อดูวิธีทำ',
                    button: true,
                    excludeSemantics: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.add_to_home_screen,
                            size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: WynSpacing.space2),
                        Expanded(
                          child: Text(
                            'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก เข้าเร็วขึ้นเหมือนเปิดแอปจริง · แตะเพื่อดูวิธี',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              Semantics(
                label: 'ปิดข้อความแนะนำ',
                button: true,
                excludeSemantics: true,
                child: InkWell(
                  onTap: _snooze,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
