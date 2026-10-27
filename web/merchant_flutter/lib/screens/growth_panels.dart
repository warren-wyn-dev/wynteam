import 'dart:async';
import 'package:flutter/material.dart';
import '../data/merchant_repository.dart';

String _baht(dynamic value) =>
    '฿${(num.tryParse('$value') ?? 0).toStringAsFixed(2)}';
num _num(dynamic value) => num.tryParse('$value') ?? 0;
const _muted = TextStyle(fontSize: 12, color: Color(0xFF6B6B76));

/// Shared load/write cycle: every write is followed by a fresh server read,
/// then that write's own success or error message is shown.
mixin _ServerPanel<T extends StatefulWidget> on State<T> {
  Json? data;
  bool loading = false, busy = false;
  String? error, notice;
  int _generation = 0;
  Future<Json> read();
  DateTime? get refreshedAt;

  /// Re-read on every page refresh, unless a write is in flight (it reloads itself).
  void reloadIfRefreshed(DateTime? before) {
    if (before != refreshedAt && !busy) unawaited(load());
  }

  Future<void> load() async {
    final g = ++_generation;
    setState(() => loading = true);
    try {
      final result = await read();
      if (!mounted || g != _generation) return;
      setState(() {
        data = result;
        error = null;
      });
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

  /// [operation] returns false when the person cancelled (nothing changed).
  Future<void> write(Future<bool> Function() operation, String done) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    String? failed;
    var changed = false;
    try {
      changed = await operation();
    } catch (e) {
      failed = errorMessage(e);
    }
    if (!mounted) return;
    setState(() => busy = false);
    await load();
    if (!mounted) return;
    setState(() {
      if (failed != null) {
        error = failed;
      } else if (changed && error == null) {
        notice = done;
      }
    });
  }

  List<Widget> messages() => [
    if (loading) const LinearProgressIndicator(),
    if (error != null)
      Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            if (data == null)
              TextButton(onPressed: load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      ),
    if (notice != null)
      Semantics(
        liveRegion: true,
        child: Text(notice!, style: const TextStyle(color: Color(0xFF1F8A4C))),
      ),
  ];
}

/// Same order as the legacy page: `live` (server: active and enough credit)
/// decides "showing"; `status` only drives the start/pause button.
String adStatusLabel(Map d) {
  final status = '${d['status'] ?? 'none'}';
  if (status == 'stopped') return 'ทีม ZOKY หยุดไว้';
  if (d['live'] == true) return 'กำลังแสดง';
  if (status == 'paused') return 'หยุดชั่วคราว';
  if (_num(d['balance']) < _num(d['cost_per_click'])) return 'เครดิตไม่พอ';
  return 'ยังไม่เริ่ม';
}

const _topupStatus = {
  'pending': 'รอตรวจ',
  'approved': 'เติมแล้ว',
  'rejected': 'ไม่ผ่าน',
};

/// Pay-per-click ads (merchant_ad_account). Credit is topped up by transfer
/// to ZOKY's PromptPay plus a slip that ZOKY Admin reviews.
class AdsPanel extends StatefulWidget {
  const AdsPanel({
    super.key,
    required this.repository,
    required this.storeId,
    this.refreshedAt,
  });
  final MerchantRepository repository;
  final String storeId;
  final DateTime? refreshedAt;
  @override
  State<AdsPanel> createState() => _AdsPanelState();
}

class _AdsPanelState extends State<AdsPanel> with _ServerPanel<AdsPanel> {
  final amount = TextEditingController();
  @override
  Future<Json> read() => widget.repository.ads(widget.storeId);
  @override
  DateTime? get refreshedAt => widget.refreshedAt;
  @override
  void didUpdateWidget(covariant AdsPanel old) {
    super.didUpdateWidget(old);
    reloadIfRefreshed(old.refreshedAt);
  }

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> topUp() async {
    final value = num.tryParse(amount.text.trim());
    final min = _num(data?['min_topup']);
    if (value == null ||
        value <= 0 ||
        value > 100000 ||
        ((value * 100) - (value * 100).round()).abs() > 1e-6) {
      setState(
        () => error = 'กรุณาใส่จำนวนเงินเป็นบาท (ทศนิยมไม่เกิน 2 ตำแหน่ง)',
      );
      return;
    }
    if (value < min) {
      setState(() => error = 'ยอดเติมขั้นต่ำ ${_baht(min)}');
      return;
    }
    await write(() async {
      final sent = await widget.repository.pickAdSlip(widget.storeId, value);
      if (sent) amount.clear();
      return sent;
    }, 'ส่งสลิปแล้ว รอทีม ZOKY ตรวจ');
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final enabled = !busy && !loading;
    final status = '${d?['status'] ?? 'none'}';
    final cpc = _num(d?['cost_per_click']);
    final topups = (d?['topups'] as List? ?? []).whereType<Map>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...messages(),
        if (d != null) ...[
          const Text('เครดิตโฆษณา', style: _muted),
          Text(
            _baht(d['balance']),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          if (cpc > 0)
            Text(
              'พอสำหรับประมาณ ${(_num(d['balance']) / cpc).floor()} คลิก · คลิกละ ${_baht(cpc)}',
              style: _muted,
            ),
          const SizedBox(height: 12),
          Text(
            'สถานะ: ${adStatusLabel(d)} · วันนี้ ${d['clicks_today'] ?? 0} คลิก · 7 วัน ${d['clicks_7d'] ?? 0} คลิก',
          ),
          if (status == 'stopped')
            Text(
              d['stop_reason'] != null
                  ? 'เหตุผล: ${d['stop_reason']}'
                  : 'ติดต่อทีม ZOKY',
              style: const TextStyle(color: Colors.red),
            ),
          if (status == 'active' || status == 'paused')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: enabled
                    ? () => write(
                        () async {
                          await widget.repository.setAdActive(
                            widget.storeId,
                            status != 'active',
                          );
                          return true;
                        },
                        status == 'active' ? 'หยุดโฆษณาแล้ว' : 'เริ่มโฆษณาแล้ว',
                      )
                    : null,
                child: Text(
                  status == 'active' ? 'หยุดโฆษณาชั่วคราว' : 'เริ่มแสดงโฆษณา',
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'แสดงเป็นร้านแนะนำบนหน้าแรกและบนสุดตอนค้นหา มีป้าย “โฆษณา” · คิดเงินเมื่อลูกค้ากดเข้าร้าน คนเดิมกดซ้ำในวันเดียวกันคิดครั้งเดียว',
            style: _muted,
          ),
          const Divider(height: 32),
          const Text(
            'เติมเครดิต',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (d['ads_enabled'] == true && d['wynos_promptpay_id'] != null) ...[
            Text(
              'โอนเข้า PromptPay ของ ZOKY ${d['wynos_promptpay_name'] ?? ''}'
                  .trim(),
            ),
            SelectableText(
              '${d['wynos_promptpay_id']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: amount,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'จำนวนเงินที่โอน (ขั้นต่ำ ${_baht(d['min_topup'])})',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: enabled ? topUp : null,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('แนบสลิปและส่งให้ ZOKY ตรวจ'),
            ),
          ] else
            const Text('ระบบโฆษณายังไม่เปิดรับเติมเครดิต', style: _muted),
          if (topups.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'ประวัติการเติม',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final t in topups)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_topupStatus[t['status']] ?? '${t['status']}'),
                subtitle: t['note'] != null ? Text('${t['note']}') : null,
                trailing: Text(_baht(t['amount'])),
              ),
          ],
        ],
      ],
    );
  }
}

String campaignTerms(Map c) {
  final parts = <String>[];
  switch ('${c['campaign_type']}') {
    case 'percentage':
      parts.add('ลด ${_num(c['discount_value'])}%');
      if (_num(c['max_discount']) > 0) {
        parts.add('สูงสุด ${_baht(c['max_discount'])}');
      }
    case 'fixed':
      parts.add('ลด ${_baht(c['discount_value'])}');
    default:
      parts.add('ส่งฟรี');
  }
  final terms = parts.join(' ');
  return _num(c['min_subtotal']) > 0
      ? '$terms · ขั้นต่ำ ${_baht(c['min_subtotal'])}'
      : terms;
}

/// ZOKY campaigns (merchant_platform_campaigns). The store sees who pays what
/// before joining; ZOKY's share is owed back to the store.
class PlatformCampaignsPanel extends StatefulWidget {
  const PlatformCampaignsPanel({
    super.key,
    required this.repository,
    required this.storeId,
    this.refreshedAt,
  });
  final MerchantRepository repository;
  final String storeId;
  final DateTime? refreshedAt;
  @override
  State<PlatformCampaignsPanel> createState() => _PlatformCampaignsPanelState();
}

class _PlatformCampaignsPanelState extends State<PlatformCampaignsPanel>
    with _ServerPanel<PlatformCampaignsPanel> {
  @override
  Future<Json> read() => widget.repository.platformCampaigns(widget.storeId);
  @override
  DateTime? get refreshedAt => widget.refreshedAt;
  @override
  void didUpdateWidget(covariant PlatformCampaignsPanel old) {
    super.didUpdateWidget(old);
    reloadIfRefreshed(old.refreshedAt);
  }

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> setJoined(Map c, bool join) async {
    final zoky = _num(c['platform_share_percent']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          join ? 'เข้าร่วม “${c['name']}”?' : 'ออกจาก “${c['name']}”?',
        ),
        content: Text(
          join
              ? '${campaignTerms(c)}\nทุกออเดอร์ที่ใช้แคมเปญนี้ ZOKY ออกส่วนลดให้ $zoky% ร้านออก ${100 - zoky}%'
              : 'ออเดอร์ใหม่จะไม่ได้ส่วนลดจากแคมเปญนี้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(join ? 'เข้าร่วม' : 'ออกจากแคมเปญ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await write(() async {
      await widget.repository.joinPlatformCampaign(
        widget.storeId,
        '${c['id']}',
        join,
      );
      return true;
    }, join ? 'เข้าร่วม “${c['name']}” แล้ว' : 'ออกจาก “${c['name']}” แล้ว');
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final enabled = !busy && !loading && d?['can_manage'] == true;
    final campaigns = (d?['campaigns'] as List? ?? [])
        .whereType<Map>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...messages(),
        if (d != null) ...[
          if (_num(d['owed']) > 0)
            Text(
              'ZOKY ค้างโอนให้ร้าน ${_baht(d['owed'])} (${d['owed_orders'] ?? 0} ออเดอร์)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (campaigns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('ยังไม่มีแคมเปญของ ZOKY ให้เข้าร่วม', style: _muted),
            ),
          for (final c in campaigns)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${c['name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (c['description'] != null) Text('${c['description']}'),
                    Text(campaignTerms(c)),
                    Text(
                      'ZOKY ออกให้ ${_num(c['platform_share_percent'])}% ของส่วนลด · ร้านออก ${100 - _num(c['platform_share_percent'])}%'
                      '${c['first_order_only'] == true ? ' · เฉพาะออเดอร์แรกของลูกค้า' : ''}',
                      style: _muted,
                    ),
                    if (c['joined'] == true)
                      Text(
                        'เข้าร่วมแล้ว · ออเดอร์สำเร็จ ${c['delivered_orders'] ?? 0} · ส่วนลดรวม ${_baht(c['discount_total'])}'
                        ' · ZOKY ออกให้ ${_baht(c['platform_funded_total'])} · ร้านรับผิดชอบ ${_baht((_num(c['discount_total']) - _num(c['platform_funded_total'])).clamp(0, double.infinity))}',
                        style: const TextStyle(color: Color(0xFF1F8A4C)),
                      ),
                    const SizedBox(height: 8),
                    if (c['joined'] == true)
                      OutlinedButton(
                        onPressed: enabled ? () => setJoined(c, false) : null,
                        child: const Text('ออกจากแคมเปญ'),
                      )
                    else if (c['join_open'] == true)
                      FilledButton(
                        onPressed: enabled ? () => setJoined(c, true) : null,
                        child: const Text('เข้าร่วมแคมเปญ'),
                      )
                    else
                      const Text('ปิดรับร้านแล้ว', style: _muted),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
