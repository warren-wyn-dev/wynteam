import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design/zoky_colors.dart';
import '../design/zoky_typography.dart';
import '../l10n/zoky_strings.dart';

/// Platform-adaptive system elements (design section 11.2). Brand elements
/// (buttons, cards, nav, cart bar) are shared and live in core/widgets.
///
/// Platform comes from Theme.of(context).platform, which follows
/// defaultTargetPlatform: iOS on an iPhone/iPad (including the web preview
/// opened in iPad Safari), Android on Android, and whatever
/// debugDefaultTargetPlatformOverride says in tests.
bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// One action of [showZokyAlertDialog].
class ZokyDialogAction<T> {
  const ZokyDialogAction({
    required this.label,
    required this.value,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final bool isDefault;
  final bool isDestructive;
}

/// Alert/confirm dialog: CupertinoAlertDialog on iOS, M3 AlertDialog on
/// Android. Returns the chosen action's value, or null when dismissed.
Future<T?> showZokyAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<ZokyDialogAction<T>> actions,
}) {
  if (isCupertino(context)) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          for (final action in actions)
            CupertinoDialogAction(
              isDefaultAction: action.isDefault,
              isDestructiveAction: action.isDestructive,
              onPressed: () => Navigator.of(dialogContext).pop(action.value),
              child: Text(action.label),
            ),
        ],
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        for (final action in actions)
          TextButton(
            style: action.isDestructive
                ? TextButton.styleFrom(foregroundColor: ZokyColors.error)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(action.value),
            child: Text(action.label),
          ),
      ],
    ),
  );
}

/// One option of [showZokyActionSheet].
class ZokySheetAction<T> {
  const ZokySheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final T value;

  /// Shown only on Android (CupertinoActionSheet rows are text-only).
  final IconData? icon;
  final bool isDestructive;
}

/// Action menu: CupertinoActionSheet (+ cancel button) on iOS, modal bottom
/// sheet of ListTiles with a drag handle on Android.
Future<T?> showZokyActionSheet<T>({
  required BuildContext context,
  String? title,
  required List<ZokySheetAction<T>> actions,
}) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: () => Navigator.of(sheetContext).pop(action.value),
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text(ZokyStrings.cancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title, style: ZokyTextStyles.titleSm),
            ),
          for (final action in actions)
            ListTile(
              leading: action.icon == null ? null : Icon(action.icon),
              iconColor: action.isDestructive ? ZokyColors.error : null,
              textColor: action.isDestructive ? ZokyColors.error : null,
              title: Text(action.label),
              onTap: () => Navigator.of(sheetContext).pop(action.value),
            ),
        ],
      ),
    ),
  );
}

/// Content bottom sheet: a white rounded popup with a grabber over a
/// Cupertino modal popup on iOS, M3 modal bottom sheet with a drag handle on
/// Android. Both are dismissible by tapping the scrim or dragging down
/// (Android) and respect the bottom safe area.
Future<T?> showZokySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => Material(
        color: ZokyColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ZokyColors.neutral200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        SafeArea(top: false, child: builder(sheetContext)),
  );
}

/// Date picker: CupertinoDatePicker wheel in a bottom popup with a "เสร็จ"
/// button on iOS, Material calendar dialog on Android.
Future<DateTime?> showZokyDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  if (!isCupertino(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
  var selected = initialDate;
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (popupContext) => Container(
      height: 300,
      color: CupertinoColors.systemBackground.resolveFrom(popupContext),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.of(popupContext).pop(true),
                child: const Text(ZokyStrings.done),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: firstDate,
                maximumDate: lastDate,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed == true ? selected : null;
}

/// Switch: CupertinoSwitch on iOS, M3 Switch on Android; the "on" track is
/// action.primary on both (design 11.2).
class ZokySwitch extends StatelessWidget {
  const ZokySwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: ZokyColors.actionPrimary,
      );
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

/// Inline spinner: CupertinoActivityIndicator on iOS, brand-pink
/// CircularProgressIndicator on Android.
class ZokySpinner extends StatelessWidget {
  const ZokySpinner({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoActivityIndicator(radius: size / 2, color: color);
    }
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: color ?? ZokyColors.brand,
      ),
    );
  }
}
