import 'package:flutter/material.dart';

/// The centered icon+text message shown for both of Search's empty
/// states (not-yet-searched prompt, and no-results) across all three
/// result tabs -- structurally identical every time (only the icon/text
/// differ), unlike e.g. the per-content-type duration formatting that's
/// intentionally left duplicated elsewhere in the app. Mirrors the visual
/// weight of the old SearchPlaceholderScreen (WYN-007) it replaces (56px
/// icon, outline color).
class SearchStateMessage extends StatelessWidget {
  const SearchStateMessage({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
