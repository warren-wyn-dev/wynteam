import 'package:flutter/material.dart';
import '../data/merchant_repository.dart';

const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayLabels = {
  'mon': 'จันทร์',
  'tue': 'อังคาร',
  'wed': 'พุธ',
  'thu': 'พฤหัสบดี',
  'fri': 'ศุกร์',
  'sat': 'เสาร์',
  'sun': 'อาทิตย์',
};

String _digits(String value) => value.replaceAll(RegExp(r'[\s-]'), '');

/// Same rule as food_stores_promptpay_id_format_check (the bridge rechecks).
String? promptPayError(String value) {
  final v = _digits(value);
  if (v.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(v) ||
      ![10, 13, 15].contains(v.length) ||
      (v.length == 10 && !v.startsWith('0'))) {
    return 'PromptPay ต้องเป็นเบอร์มือถือ 10 หลัก เลขบัตรประชาชน 13 หลัก หรือ e-Wallet 15 หลัก';
  }
  return null;
}

String? bankAccountError(String value) {
  final v = _digits(value);
  if (v.isEmpty) return null;
  if (!RegExp(r'^\d{10,15}$').hasMatch(v)) {
    return 'เลขบัญชีต้องเป็นตัวเลข 10–15 หลัก';
  }
  return null;
}

/// PromptPay, bank transfer and the store's own QR. Customers pay the store
/// directly; edits stay a local draft until saved and the bridge rechecks.
class PaymentChannelsPanel extends StatefulWidget {
  const PaymentChannelsPanel({
    super.key,
    required this.store,
    required this.enabled,
    required this.save,
    required this.pickQr,
    required this.error,
  });
  final Json store;
  final bool enabled;
  final Future<bool> Function(Json) save;
  final Future<bool> Function() pickQr;
  final String? Function() error;
  @override
  State<PaymentChannelsPanel> createState() => _PaymentChannelsPanelState();
}

class _PaymentChannelsPanelState extends State<PaymentChannelsPanel> {
  static const _fields = [
    'promptpay_name',
    'promptpay_id',
    'bank_name',
    'bank_account_name',
    'bank_account_number',
  ];
  late final Map<String, TextEditingController> fields = {
    for (final key in _fields) key: TextEditingController(),
  };
  bool saving = false;
  String? error;

  void readStore() {
    for (final key in _fields) {
      fields[key]!.text = '${widget.store[key] ?? ''}';
    }
  }

  @override
  void initState() {
    super.initState();
    readStore();
  }

  @override
  void didUpdateWidget(covariant PaymentChannelsPanel old) {
    super.didUpdateWidget(old);
    if (old.store['id'] != widget.store['id'] ||
        old.store['updated_at'] != widget.store['updated_at']) {
      readStore();
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<bool> Function() operation) async {
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await operation();
    if (!mounted) return;
    setState(() {
      saving = false;
      error = ok ? null : widget.error();
    });
  }

  Future<void> save() async {
    final invalid =
        promptPayError(fields['promptpay_id']!.text) ??
        bankAccountError(fields['bank_account_number']!.text);
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    await run(
      () => widget.save({
        for (final key in _fields) key: fields[key]!.text.trim(),
      }),
    );
  }

  Widget field(String key, String label, {bool number = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: fields[key],
      enabled: widget.enabled && !saving,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !saving;
    final qrUrl = widget.store['payment_qr_url'] as String?;
    final hasQr = widget.store['payment_qr_path'] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ช่องทางรับเงิน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const Text(
          'ลูกค้าโอนเข้าบัญชีร้านโดยตรง แล้วแนบสลิปให้ร้านตรวจ',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
        ),
        const SizedBox(height: 12),
        field('promptpay_name', 'ชื่อบัญชี PromptPay'),
        field('promptpay_id', 'เบอร์หรือเลข PromptPay', number: true),
        field('bank_name', 'ธนาคาร'),
        field('bank_account_name', 'ชื่อบัญชีธนาคาร'),
        field('bank_account_number', 'เลขบัญชี', number: true),
        const SizedBox(height: 4),
        Row(
          children: [
            if (hasQr && qrUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Image.network(
                  qrUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  semanticLabel: 'QR รับเงินของร้าน',
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.qr_code_2, size: 48),
                ),
              ),
            Expanded(
              child: Text(hasQr ? 'มี QR รับเงินแล้ว' : 'ยังไม่มี QR รับเงิน'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? () => run(widget.pickQr) : null,
              icon: const Icon(Icons.qr_code_2),
              label: Text(hasQr ? 'เปลี่ยน QR' : 'อัปโหลด QR'),
            ),
            if (hasQr)
              TextButton(
                onPressed: enabled
                    ? () => run(() => widget.save({'payment_qr_path': null}))
                    : null,
                child: const Text('ลบ QR'),
              ),
          ],
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          onPressed: enabled ? save : null,
          child: const Text('บันทึกช่องทางรับเงิน'),
        ),
      ],
    );
  }
}

/// Weekly opening hours plus special closed days (Asia/Bangkok dates).
class BusinessHoursPanel extends StatefulWidget {
  const BusinessHoursPanel({
    super.key,
    required this.store,
    required this.enabled,
    required this.save,
    required this.error,
  });
  final Json store;
  final bool enabled;
  final Future<bool> Function(Json) save;
  final String? Function() error;
  @override
  State<BusinessHoursPanel> createState() => _BusinessHoursPanelState();
}

class _BusinessHoursPanelState extends State<BusinessHoursPanel> {
  late Map<String, Json> days;
  late List<String> closed;
  bool saving = false;
  String? error;

  void readStore() {
    final weekly = (widget.store['business_schedule'] as Map?)?['weekly'];
    days = {
      for (final key in _dayKeys)
        key: weekly is Map && weekly[key] is Map
            ? Json.from(weekly[key] as Map)
            : {'enabled': true, 'open': '09:00', 'close': '21:00'},
    };
    closed = [
      for (final d in (widget.store['special_closed_dates'] as List? ?? []))
        '$d',
    ]..sort();
  }

  @override
  void initState() {
    super.initState();
    readStore();
  }

  @override
  void didUpdateWidget(covariant BusinessHoursPanel old) {
    super.didUpdateWidget(old);
    if (old.store['id'] != widget.store['id'] ||
        old.store['updated_at'] != widget.store['updated_at']) {
      readStore();
    }
  }

  TimeOfDay parse(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
  }

  String format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> pickTime(String day, String edge) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: parse('${days[day]![edge]}'),
      helpText: edge == 'open' ? 'เวลาเปิด' : 'เวลาปิด',
    );
    if (picked != null && mounted) {
      setState(() => days[day]![edge] = format(picked));
    }
  }

  Future<void> addClosedDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
      helpText: 'วันหยุดพิเศษ',
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (!closed.contains(value)) closed = [...closed, value]..sort();
    });
  }

  Future<void> save() async {
    if (days.values.every((d) => d['enabled'] != true)) {
      setState(() => error = 'ต้องเปิดร้านอย่างน้อย 1 วันต่อสัปดาห์');
      return;
    }
    if (closed.length > 60) {
      setState(() => error = 'เพิ่มวันหยุดพิเศษได้ไม่เกิน 60 วัน');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.save({
      'business_schedule': {
        'weekly': {
          for (final key in _dayKeys)
            key: {
              'enabled': days[key]!['enabled'] == true,
              'open': '${days[key]!['open']}',
              'close': '${days[key]!['close']}',
            },
        },
      },
      'special_closed_dates': closed,
    });
    if (!mounted) return;
    setState(() {
      saving = false;
      error = ok ? null : widget.error();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'เวลาเปิดร้าน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const Text(
          'เวลาไทย · ปิดหลังเที่ยงคืนได้ เช่น 18:00–02:00',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
        ),
        for (final key in _dayKeys)
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_dayLabels[key]!),
                  value: days[key]!['enabled'] == true,
                  onChanged: enabled
                      ? (v) => setState(() => days[key]!['enabled'] = v)
                      : null,
                ),
              ),
              if (days[key]!['enabled'] == true) ...[
                TextButton(
                  onPressed: enabled ? () => pickTime(key, 'open') : null,
                  child: Text(
                    '${days[key]!['open']}',
                    semanticsLabel:
                        'เวลาเปิดวัน${_dayLabels[key]} ${days[key]!['open']}',
                  ),
                ),
                const Text('–'),
                TextButton(
                  onPressed: enabled ? () => pickTime(key, 'close') : null,
                  child: Text(
                    '${days[key]!['close']}',
                    semanticsLabel:
                        'เวลาปิดวัน${_dayLabels[key]} ${days[key]!['close']}',
                  ),
                ),
              ] else
                const Text('ปิด', style: TextStyle(color: Color(0xFF6B6B76))),
            ],
          ),
        const SizedBox(height: 12),
        const Text(
          'วันหยุดพิเศษ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (closed.isEmpty)
          const Text(
            'ยังไม่มีวันหยุดพิเศษ',
            style: TextStyle(color: Color(0xFF6B6B76)),
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final d in closed)
              InputChip(
                label: Text(d),
                onDeleted: enabled
                    ? () => setState(() => closed = [...closed]..remove(d))
                    : null,
                deleteButtonTooltipMessage: 'ลบวันหยุด $d',
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? addClosedDay : null,
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('เพิ่มวันหยุดพิเศษ'),
          ),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          onPressed: enabled ? save : null,
          child: const Text('บันทึกเวลาเปิดร้าน'),
        ),
      ],
    );
  }
}
