import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../../core/widgets/zoky_logo.dart';
import '../../core/widgets/zoky_page_header.dart';
import '../catalog/data/demo_store_repository.dart';

/// บัญชี tab placeholder (web AccountPanel): profile card prompt, order
/// history shortcut and a demo-mode notice. Sign-in, addresses,
/// notifications and promotions arrive in ZOKY-105/110/111.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.onOrderHistory});

  final VoidCallback onOrderHistory;

  @override
  Widget build(BuildContext context) {
    final usesDemoData =
        AppDependencies.of(context).storeRepository is DemoStoreRepository;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: ZokyBottomNav.reservedHeight(context)),
        children: [
          const ZokyPageHeader(title: ZokyStrings.navAccount),
          _card(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: ZokyColors.blush,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(ZokyIcons.account, color: ZokyColors.berry),
                ),
                const SizedBox(width: ZokySpacing.s6),
                Expanded(
                  child: Text(
                    ZokyStrings.profileSetupPrompt,
                    style: ZokyTextStyles.weight(
                      ZokyTextStyles.bodyLg,
                      FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _card(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(ZokyIcons.orders),
              title: Text(
                ZokyStrings.orderHistory,
                style: ZokyTextStyles.weight(
                  ZokyTextStyles.bodyMd,
                  FontWeight.w700,
                ),
              ),
              trailing: const Icon(ZokyIcons.chevronRight),
              onTap: onOrderHistory,
            ),
          ),
          if (usesDemoData)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZokySpacing.gutter,
                vertical: ZokySpacing.s4,
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: ZokyColors.infoContainer,
                  borderRadius: ZokyRadius.lg,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(ZokySpacing.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: ZokyColors.info,
                      ),
                      const SizedBox(width: ZokySpacing.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ZokyStrings.demoModeTitle,
                              style: ZokyTextStyles.labelLg.copyWith(
                                color: ZokyColors.info,
                              ),
                            ),
                            const SizedBox(height: ZokySpacing.s1),
                            Text(
                              ZokyStrings.demoModeBody,
                              style: ZokyTextStyles.bodySm.copyWith(
                                color: ZokyColors.info,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: ZokySpacing.s12),
          const Center(child: ZokyLogo(size: 56)),
          const SizedBox(height: ZokySpacing.s4),
          Center(
            child: TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: ZokyStrings.appName,
              ),
              child: const Text(ZokyStrings.openSourceLicenses),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(ZokySpacing.s8),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZokySpacing.gutter,
        vertical: ZokySpacing.s4,
      ),
      // Material (not DecoratedBox) so ListTile ink shows on the card.
      child: Material(
        color: ZokyColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: ZokyRadius.lg,
          side: BorderSide(color: ZokyColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
