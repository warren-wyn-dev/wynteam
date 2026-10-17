import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_skeleton.dart';
import '../../core/widgets/zoky_state_view.dart';
import 'data/promotion_repository.dart';
import 'deal_sheet.dart';
import 'domain/deal_models.dart';
import 'widgets/zoky_deal_card.dart';

/// "ดูทั้งหมด" from the Home deal row: every deal as a full-width card.
/// Placeholder list until a deals page is specified.
class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key, required this.repository});

  final PromotionRepository repository;

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  List<ZokyDeal>? _deals;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _deals = null;
      _error = null;
    });
    try {
      final deals = await widget.repository.fetchTodayDeals();
      if (!mounted) return;
      setState(() => _deals = deals);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(ZokyIcons.back(context)),
          tooltip: ZokyStrings.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: isCupertino(context),
        title: const Text(ZokyStrings.dealsTitle),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return ZokyStateView.error(
        title: ZokyStrings.loadErrorTitle,
        messages: const [ZokyStrings.offlineBody],
        onAction: _load,
      );
    }
    final deals = _deals;
    final width = MediaQuery.sizeOf(context).width - 2 * ZokySpacing.gutter;
    final bottom = ZokySpacing.s12 + MediaQuery.paddingOf(context).bottom;
    if (deals == null) {
      return ListView(
        padding: const EdgeInsets.all(ZokySpacing.gutter),
        children: [
          for (var i = 0; i < 3; i++) ...[
            const ZokySkeleton(
              height: ZokyDealCard.minHeight,
              borderRadius: ZokyDealCard.radius,
            ),
            const SizedBox(height: ZokySpacing.s6),
          ],
        ],
      );
    }
    if (deals.isEmpty) {
      return const ZokyStateView.empty(
        icon: ZokyIcons.store,
        title: ZokyStrings.dealsTitle,
        messages: [ZokyStrings.comingSoon],
      );
    }
    final anyDemo = deals.any((d) => d.isDemo);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        ZokySpacing.gutter,
        ZokySpacing.s4,
        ZokySpacing.gutter,
        bottom,
      ),
      children: [
        if (anyDemo) ...[
          Text(ZokyStrings.dealsDemoNote, style: ZokyTextStyles.bodySm),
          const SizedBox(height: ZokySpacing.s6),
        ],
        for (final (i, deal) in deals.indexed) ...[
          ZokyDealCard(
            deal: deal,
            width: width,
            tint: ZokyDealTint.forIndex(i),
            onTap: () => showZokyDealSheet(context, deal),
          ),
          const SizedBox(height: ZokySpacing.s7),
        ],
      ],
    );
  }
}
