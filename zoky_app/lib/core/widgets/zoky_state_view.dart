import 'package:flutter/material.dart';

import '../adaptive/zoky_icons.dart';
import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';
import '../l10n/zoky_strings.dart';
import 'zoky_button.dart';

enum _StateKind { empty, error }

/// Empty / error state block (design 9.12, web `FoodStateScreen`).
///
/// Empty: Blush circle + brand-pink icon. Error: errorContainer circle +
/// error icon + "ลองอีกครั้ง" (never a pink circle for errors).
class ZokyStateView extends StatelessWidget {
  const ZokyStateView.empty({
    super.key,
    required this.icon,
    required this.title,
    this.messages = const [],
    this.actionLabel,
    this.onAction,
  }) : _kind = _StateKind.empty;

  const ZokyStateView.error({
    super.key,
    required this.title,
    this.messages = const [],
    required VoidCallback this.onAction,
    this.icon = ZokyIcons.error,
  }) : actionLabel = ZokyStrings.retry,
       _kind = _StateKind.error;

  final IconData icon;
  final String title;
  final List<String> messages;
  final String? actionLabel;
  final VoidCallback? onAction;
  final _StateKind _kind;

  @override
  Widget build(BuildContext context) {
    final isError = _kind == _StateKind.error;
    return Semantics(
      liveRegion: isError,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZokySpacing.s12,
          vertical: ZokySpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: isError ? ZokyColors.errorContainer : ZokyColors.blush,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: isError ? ZokyColors.error : ZokyColors.brand,
                ),
              ),
            ),
            const SizedBox(height: ZokySpacing.s8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ZokyTextStyles.titleMd,
            ),
            for (final message in messages) ...[
              const SizedBox(height: ZokySpacing.s3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: ZokyTextStyles.bodyMd.copyWith(
                    fontSize: 14.5,
                    color: ZokyColors.textSecondary,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: ZokySpacing.s10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: ZokyButton.primary(
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
