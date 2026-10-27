import 'dart:async';
import 'package:flutter/material.dart';
import '../data/merchant_repository.dart';

const _periods = {
  'today': 'วันนี้',
  'yesterday': 'เมื่อวาน',
  'week': 'สัปดาห์นี้',
  'month': 'เดือนนี้',
};

String _baht(dynamic value) =>
    '฿${(num.tryParse('$value') ?? 0).toStringAsFixed(2)}';

/// Store finance (merchant_finance_summary) for owner/admin/manager. Every
/// figure comes from the server; this widget only formats it.
class FinancePanel extends StatefulWidget {
  const FinancePanel({
    super.key,
    required this.repository,
    required this.storeId,
    this.refreshedAt,
  });
  final MerchantRepository repository;
  final String storeId;

  /// The page's last refresh (pull, realtime or timer); a new value reloads.
  final DateTime? refreshedAt;
  @override
  State<FinancePanel> createState() => _FinancePanelState();
}

class _FinancePanelState extends State<FinancePanel> {
  String period = 'today';
  Json? data;
  String? error;
  bool loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void didUpdateWidget(covariant FinancePanel old) {
    super.didUpdateWidget(old);
    if (old.storeId != widget.storeId ||
        old.refreshedAt != widget.refreshedAt) {
      unawaited(load(quiet: old.storeId == widget.storeId));
    }
  }

  /// [quiet]: a background refresh keeps the current figures until the new
  /// ones arrive; a new period or store clears them first.
  Future<void> load({bool quiet = false}) async {
    // A slower answer for an older period or store never replaces a newer one.
    final g = ++_generation;
    setState(() {
      loading = true;
      error = null;
      if (!quiet) data = null;
    });
    try {
      final result = await widget.repository.finance(widget.storeId, period);
      if (!mounted || g != _generation) return;
      setState(() => data = result);
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        data = null;
        error = errorMessage(e);
      });
    } finally {
      if (mounted && g == _generation) setState(() => loading = false);
    }
  }

  Widget line(
    String label,
    dynamic value, {
    bool strong = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (hint != null)
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B76),
                  ),
                ),
            ],
          ),
        ),
        Text(
          _baht(value),
          style: TextStyle(
            fontWeight: strong ? FontWeight.bold : FontWeight.w600,
            fontSize: strong ? 18 : 14,
          ),
        ),
      ],
    ),
  );

  String? change() {
    final now = num.tryParse('${data?['sales_net']}') ?? 0;
    final before = num.tryParse('${data?['prev_sales_net']}') ?? 0;
    if (before == 0) return null;
    final pct = ((now - before) / before.abs() * 100).round();
    return '${pct >= 0 ? '+' : ''}$pct% จากช่วงก่อนหน้า';
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final days = (d?['days'] as List? ?? []).whereType<Map>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _periods.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: period == entry.key,
                onSelected: loading
                    ? null
                    : (_) {
                        setState(() => period = entry.key);
                        unawaited(load());
                      },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(onPressed: load, child: const Text('ลองอีกครั้ง')),
              ],
            ),
          ),
        if (d != null) ...[
          line(
            'ยอดขายสุทธิ',
            d['sales_net'],
            strong: true,
            hint: ['${d['orders'] ?? 0} ออเดอร์', ?change()].join(' · '),
          ),
          line('ค่าอาหาร', d['food']),
          line('ค่าส่ง', d['delivery']),
          line('ส่วนลด', d['discounts']),
          line(
            'คืนเงิน',
            d['refunds'],
            hint: '${d['refund_count'] ?? 0} ออเดอร์ (ตามวันที่คืนเงิน)',
          ),
          line('ค่าโฆษณา', d['ad_spend']),
          line('ส่วนลดที่ ZOKY ออกให้', d['platform_funded']),
          if ((num.tryParse('${d['gp']}') ?? 0) != 0) line('GP', d['gp']),
          const Divider(),
          line(
            'รายได้ร้าน',
            d['income'],
            strong: true,
            hint: 'ยอดขายสุทธิ − ค่าโฆษณา + ส่วนลดที่ ZOKY ออกให้ − GP',
          ),
          const SizedBox(height: 8),
          if ((num.tryParse('${d['pending_slip_count']}') ?? 0) > 0)
            line(
              'สลิปรอตรวจ',
              d['pending_slip_total'],
              hint: '${d['pending_slip_count']} ออเดอร์ ยังไม่นับในยอดขาย',
            ),
          if ((num.tryParse('${d['platform_owed']}') ?? 0) > 0)
            line(
              'ZOKY ค้างโอนให้ร้าน',
              d['platform_owed'],
              hint: 'ยอดปัจจุบัน ไม่ขึ้นกับช่วงเวลา',
            ),
          if (days.length > 1) ...[
            const SizedBox(height: 12),
            const Text('รายวัน', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final day in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('${day['day']}')),
                    Text('${day['orders'] ?? 0} ออเดอร์  '),
                    Text(
                      _baht(day['sales_net']),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Text(
            'นับตามเวลาไทย: ยอดขายตามเวลาที่ชำระเงิน คืนเงินตามเวลาที่คืน',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
          ),
        ],
      ],
    );
  }
}
