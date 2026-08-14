import 'package:flutter/material.dart';

/// Shown when the Home Search bar is tapped. Real Search is WYN-009 --
/// this screen exists so tapping the bar reads as "intentionally not
/// ready yet" instead of doing nothing or a bare SnackBar. See
/// .wyn/docs/design/wyn-007-home.md.
class SearchPlaceholderScreen extends StatelessWidget {
  const SearchPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ค้นหา')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text('ฟีเจอร์ค้นหากำลังจะมาเร็ว ๆ นี้'),
          ],
        ),
      ),
    );
  }
}
