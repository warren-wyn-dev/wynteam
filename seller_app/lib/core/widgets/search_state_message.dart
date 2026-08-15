import 'package:flutter/material.dart';

/// The centered icon+text message for `SellerProductListScreen`'s empty
/// states. Duplicated from
/// `app/lib/features/search/presentation/widgets/search_state_message.dart`
/// (WYN-009) -- same shape, separate Flutter binary. See
/// .wyn/docs/design/seller-002-product-management.md, Screen:
/// SellerProductListScreen, States.
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
