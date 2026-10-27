import 'dart:async';
import 'package:flutter/material.dart';
import '../data/merchant_repository.dart';
import 'growth_panels.dart';

String _baht(dynamic value) =>
    '฿${(num.tryParse('$value') ?? 0).toStringAsFixed(2)}';
const _muted = TextStyle(fontSize: 12, color: Color(0xFF6B6B76));

/// YYYY-MM-DD (a Bangkok calendar day) as d/m/BE year.
String billingDay(dynamic value) {
  final d = DateTime.tryParse('$value');
  if (d == null) return '—';
  return '${d.day}/${d.month}/${d.year + 543}';
}

const billingStatusLabel = {
  'unpaid': 'รอชำระ',
  'slip_submitted': 'รอ ZOKY ตรวจสลิป',
  'paid': 'ชำระแล้ว',
  'rejected': 'สลิปไม่ผ่าน แนบใหม่ได้',
  'waived': 'ZOKY ยกเว้นให้',
};

/// Open invoices the store still has to pay (unpaid or slip rejected).
List<Map> openBillingInvoices(Json? data) => [
  for (final i in (data?['invoices'] as List? ?? []).whereType<Map>())
    if (i['status'] == 'unpaid' || i['status'] == 'rejected') i,
];

/// ZOKY-BILLING-001: the store's monthly ZOKY fee (merchant_billing), for
/// owner/admin. Pay by transfer to ZOKY, attach the slip, ZOKY confirms and
/// the receipt opens from a paid invoice.
class BillingPanel extends StatefulWidget {
  const BillingPanel({
    super.key,
    required this.repository,
    required this.storeId,
    required this.openReceipt,
    this.refreshedAt,
  });
  final MerchantRepository repository;
  final String storeId;
  final void Function(String invoiceId) openReceipt;
  final DateTime? refreshedAt;
  @override
  State<BillingPanel> createState() => _BillingPanelState();
}

class _BillingPanelState extends State<BillingPanel>
    with ServerPanel<BillingPanel> {
  @override
  Future<Json> read() => widget.repository.billing(widget.storeId);
  @override
  DateTime? get refreshedAt => widget.refreshedAt;
  @override
  void didUpdateWidget(covariant BillingPanel old) {
    super.didUpdateWidget(old);
    reloadIfRefreshed(old.refreshedAt);
  }

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> attachSlip(Map invoice) => write(
    () => widget.repository.pickBillingSlip(widget.storeId, '${invoice['id']}'),
    'ส่งสลิปแล้ว รอ ZOKY ตรวจ',
  );

  Widget account(Json d) {
    final a = (d['account'] as Map?) ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('โอนเข้าบัญชีของ ZOKY', style: _muted),
        if (a['promptpay_id'] != null) ...[
          Text('PromptPay ${a['promptpay_name'] ?? ''}'.trim()),
          SelectableText(
            '${a['promptpay_id']}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
        if (a['bank_account_number'] != null) ...[
          Text(
            '${a['bank_name'] ?? ''} ${a['bank_account_name'] ?? ''}'.trim(),
          ),
          SelectableText(
            '${a['bank_account_number']}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  Widget invoiceTile(Map i, bool enabled) {
    final status = '${i['status']}';
    final overdue = num.tryParse('${i['overdue_days']}') ?? 0;
    final open = status == 'unpaid' || status == 'rejected';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'รอบ ${billingDay(i['period_start'])} – ${billingDay(i['period_end'])}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _baht(i['amount']),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            [
              billingStatusLabel[status] ?? status,
              if (open) 'ครบกำหนด ${billingDay(i['due_on'])}',
              if (open && overdue > 0) 'เลยกำหนด $overdue วัน',
              if (i['receipt_no'] != null) 'ใบเสร็จ ${i['receipt_no']}',
            ].join(' · '),
            style: TextStyle(
              color: open && overdue > 0 ? Colors.red : const Color(0xFF6B6B76),
            ),
          ),
          if (i['note'] != null && status != 'paid')
            Text('หมายเหตุจาก ZOKY: ${i['note']}', style: _muted),
          if (open)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: enabled ? () => attachSlip(i) : null,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  status == 'rejected' ? 'แนบสลิปใหม่' : 'แนบสลิปการโอน',
                ),
              ),
            ),
          if (status == 'paid')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => widget.openReceipt('${i['id']}'),
                icon: const Icon(Icons.download_outlined),
                label: const Text('ดูและบันทึกใบเสร็จ'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final enabled = !busy && !loading;
    final invoices = (d?['invoices'] as List? ?? []).whereType<Map>().toList();
    final hasOpen = openBillingInvoices(d).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...messages(),
        if (d != null) ...[
          if (d['enabled'] != true && invoices.isEmpty)
            const Text('ZOKY ยังไม่เริ่มเก็บค่าบริการรายเดือน')
          else ...[
            if (d['monthly_fee'] != null)
              Text(
                'ค่าบริการ ${_baht(d['monthly_fee'])} ต่อเดือน',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (d['in_trial'] == true)
              Text(
                'ทดลองใช้ฟรีถึง ${billingDay(d['trial_ends_on'])} · ใบแจ้งหนี้แรกออกวันที่ ${billingDay(d['next_cycle_on'])}',
              )
            else if (d['next_cycle_on'] != null)
              Text('รอบถัดไป ${billingDay(d['next_cycle_on'])}'),
            const Text(
              'ใบแจ้งหนี้ออกเมื่อเริ่มรอบ ครบกำหนด 7 วันหลังออก · ร้านที่ค้างชำระอาจถูกระงับจนกว่าจะชำระครบ',
              style: _muted,
            ),
            if (hasOpen) ...[const SizedBox(height: 12), account(d)],
            const Divider(height: 32),
            const Text(
              'ใบแจ้งหนี้',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (invoices.isEmpty)
              const Text('ยังไม่มีใบแจ้งหนี้', style: _muted)
            else
              for (final i in invoices) invoiceTile(i, enabled),
          ],
        ],
      ],
    );
  }
}

/// Home banner while an invoice waits for payment (owner/admin only).
class BillingDueBanner extends StatefulWidget {
  const BillingDueBanner({
    super.key,
    required this.repository,
    required this.storeId,
    required this.onOpen,
    this.refreshedAt,
  });
  final MerchantRepository repository;
  final String storeId;
  final VoidCallback onOpen;
  final DateTime? refreshedAt;
  @override
  State<BillingDueBanner> createState() => _BillingDueBannerState();
}

class _BillingDueBannerState extends State<BillingDueBanner> {
  Map? invoice;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void didUpdateWidget(covariant BillingDueBanner old) {
    super.didUpdateWidget(old);
    if (old.refreshedAt != widget.refreshedAt) unawaited(load());
  }

  Future<void> load() async {
    final g = ++_generation;
    Map? next;
    try {
      final open = openBillingInvoices(
        await widget.repository.billing(widget.storeId),
      );
      next = open.isEmpty ? null : open.last;
    } catch (_) {
      // The banner is a hint only; the billing page shows the error.
      next = null;
    }
    if (mounted && g == _generation) setState(() => invoice = next);
  }

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    if (i == null) return const SizedBox.shrink();
    final overdue = num.tryParse('${i['overdue_days']}') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: overdue > 0 ? const Color(0xFFFDECEC) : const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: widget.onOpen,
          leading: Icon(
            Icons.receipt_long_outlined,
            color: overdue > 0 ? Colors.red : const Color(0xFFE07A00),
          ),
          title: Text(
            overdue > 0
                ? 'ค่าบริการ ZOKY เลยกำหนด $overdue วัน'
                : 'ค่าบริการ ZOKY ${_baht(i['amount'])} ครบกำหนด ${billingDay(i['due_on'])}',
          ),
          subtitle: const Text('แตะเพื่อดูวิธีชำระและแนบสลิป'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
