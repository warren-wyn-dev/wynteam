import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/pwa/pwa_install_hint.dart';

/// A one-time, dismissible card at the top of Home nudging a *browser*
/// visitor (this only ever matters for the Flutter Web build) to add
/// WYNOS to their home screen -- Founder feedback: users didn't know
/// WYNOS could be installed like a real app icon at all.
///
/// Renders nothing on a native build ([kIsWeb] false), nothing once the
/// visitor already opened the installed copy
/// ([PwaInstallHint.isRunningAsInstalledApp] -- there is no "add to
/// home screen" left to ask for), and nothing on a desktop browser or
/// anything [PwaInstallHint.guidance] can't place on iOS/Android (same
/// "don't render an ask the visitor can't act on" posture as
/// [PushPermissionCard]). Otherwise shown once total, persisted via
/// `shared_preferences` -- same shape as [HomeExplainerBanner]/
/// [PrivacyNoticeBanner] (a per-device UI flag, not data that needs to
/// sync across devices).
class AddToHomeScreenBanner extends StatefulWidget {
  const AddToHomeScreenBanner({
    super.key,
    bool? isWeb,
    AddToHomeScreenGuidance? guidance,
    bool? isRunningAsInstalledApp,
  })  : _isWeb = isWeb,
        _guidance = guidance,
        _isRunningAsInstalledApp = isRunningAsInstalledApp;

  static const _prefsKey = 'add_to_home_screen_banner_dismissed';

  // All 3 optional/defaulted to the real [kIsWeb]/[PwaInstallHint]
  // reads below -- same "optional param, real default" convention every
  // other repository/service param in this app follows (see
  // .wyn/learning/PATTERNS.md). `flutter test` always runs on the VM
  // target, where `kIsWeb` is compile-time false and `PwaInstallHint`
  // therefore always resolves to "hide" -- without these overrides,
  // every branch of this widget's own logic (which platform's
  // instructions render, "already installed" hiding it) would be
  // permanently unreachable from a widget test.
  final bool? _isWeb;
  final AddToHomeScreenGuidance? _guidance;
  final bool? _isRunningAsInstalledApp;

  @override
  State<AddToHomeScreenBanner> createState() => _AddToHomeScreenBannerState();
}

class _AddToHomeScreenBannerState extends State<AddToHomeScreenBanner> {
  // Null until the pref read resolves -- stays hidden meanwhile rather
  // than flashing visible-then-hidden for a returning user.
  bool? _shouldShow;

  bool get _isWeb => widget._isWeb ?? kIsWeb;
  AddToHomeScreenGuidance get _guidance =>
      widget._guidance ?? PwaInstallHint.guidance;
  bool get _isRunningAsInstalledApp =>
      widget._isRunningAsInstalledApp ?? PwaInstallHint.isRunningAsInstalledApp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isWeb ||
        _guidance == AddToHomeScreenGuidance.unsupported ||
        _isRunningAsInstalledApp) {
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

    final (icon, body) = switch (_guidance) {
      AddToHomeScreenGuidance.ios => (
          Icons.ios_share,
          'แตะปุ่มแชร์ (ไอคอนสี่เหลี่ยมมีลูกศรชี้ขึ้น) ที่แถบด้านล่างของ Safari '
              'แล้วเลือก "เพิ่มไปยังหน้าจอโฮม"',
        ),
      AddToHomeScreenGuidance.android => (
          Icons.install_mobile,
          'แตะเมนู ⋮ มุมขวาบนของเบราว์เซอร์ แล้วเลือก "เพิ่มไปยังหน้าจอโฮม" '
              'หรือ "ติดตั้งแอป"',
        ),
      // _load() never leaves _shouldShow true for `unsupported` --
      // exhaustive switch still needs a case, never actually built.
      AddToHomeScreenGuidance.unsupported => (Icons.install_mobile, ''),
    };

    return Container(
      key: const Key('add_to_home_screen_banner'),
      margin: const EdgeInsets.fromLTRB(WynSpacing.space4, WynSpacing.space3,
          WynSpacing.space4, WynSpacing.space1),
      padding: const EdgeInsets.all(WynSpacing.space4),
      decoration: BoxDecoration(
        border: Border.all(color: WynColors.hairline),
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: WynColors.sapphire),
          const SizedBox(width: WynSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('เพิ่ม WYNOS ไปหน้าจอโฮม', style: _titleStyle),
                const SizedBox(height: WynSpacing.space1),
                Text(body, style: _bodyStyle),
              ],
            ),
          ),
          const SizedBox(width: WynSpacing.space2),
          Semantics(
            label: 'ปิดคำแนะนำเพิ่มไปหน้าจอโฮม',
            button: true,
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: WynSpacing.touchTargetMin,
                minHeight: WynSpacing.touchTargetMin,
              ),
              child: InkWell(
                key: const Key('add_to_home_screen_dismiss_button'),
                onTap: _dismiss,
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 18, color: WynColors.graphite),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: WynColors.ink,
);

const _bodyStyle = TextStyle(
  fontSize: 13,
  color: WynColors.graphite,
  height: 1.45,
);
