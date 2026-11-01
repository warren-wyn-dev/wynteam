import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/merchant_repository.dart';

const _muted = TextStyle(fontSize: 12, color: Color(0xFF6B6B76));

/// Founder 2026-11-01: the legacy store editor inside the new Merchant, so the
/// readiness checklist and settings never jump to the old page. Every field
/// is validated again by the bridge and the database before it is saved.
class StoreProfilePanel extends StatefulWidget {
  const StoreProfilePanel({
    super.key,
    required this.store,
    required this.enabled,
    required this.save,
    required this.pickImage,
    required this.setPublished,
    required this.locate,
    required this.checkArea,
    required this.error,
  });
  final Json store;
  final bool enabled;
  final Future<bool> Function(Json values) save;
  final Future<bool> Function(String kind) pickImage;
  final Future<bool> Function(bool published) setPublished;
  final Future<Json> Function() locate;
  final Future<bool?> Function(num lat, num lng) checkArea;
  final String? Function() error;
  @override
  State<StoreProfilePanel> createState() => _StoreProfilePanelState();
}

class _StoreProfilePanelState extends State<StoreProfilePanel> {
  final _form = GlobalKey<FormState>();
  final c = <String, TextEditingController>{};
  num? lat, lng, pickupLat, pickupLng;
  DateTime? closedUntil;
  bool scheduled = false, taxInvoice = false, saving = false;
  bool? insideArea;
  String? message;

  static const _textKeys = [
    'name',
    'description',
    'phone',
    'address',
    'business_hours',
    'delivery_area',
    'delivery_fee',
    'minimum_order',
    'delivery_radius_km',
    'delivery_base_km',
    'delivery_fee_per_km',
    'pickup_note',
    'temporary_closed_reason',
    'scheduled_min_notice_minutes',
    'scheduled_max_days',
    'tax_legal_name',
    'tax_id',
    'tax_branch',
    'tax_address',
  ];

  String _initial(String key) {
    final s = widget.store;
    final defaults = {
      'delivery_fee': '0',
      'minimum_order': '0',
      'delivery_radius_km': '5',
      'delivery_base_km': '2',
      'delivery_fee_per_km': '0',
      'scheduled_min_notice_minutes': '30',
      'scheduled_max_days': '7',
    };
    final v = s[key];
    if (v == null) return defaults[key] ?? '';
    if (v is num && v == v.roundToDouble()) return '${v.toInt()}';
    return '$v';
  }

  num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

  void readStore() {
    for (final key in _textKeys) {
      (c[key] ??= TextEditingController()).text = _initial(key);
    }
    final s = widget.store;
    lat = _num(s['latitude']);
    lng = _num(s['longitude']);
    pickupLat = _num(s['pickup_latitude']);
    pickupLng = _num(s['pickup_longitude']);
    final until = DateTime.tryParse('${s['temporary_closed_until'] ?? ''}');
    closedUntil = until != null && until.isAfter(DateTime.now())
        ? until.toLocal()
        : null;
    scheduled = s['scheduled_orders_enabled'] == true;
    taxInvoice = s['tax_invoice_enabled'] == true;
  }

  @override
  void initState() {
    super.initState();
    readStore();
  }

  @override
  void didUpdateWidget(covariant StoreProfilePanel old) {
    super.didUpdateWidget(old);
    // A different store resets the draft; a refresh of the same store keeps it.
    if (old.store['id'] != widget.store['id']) readStore();
  }

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String t(String key) => c[key]!.text.trim();

  Future<void> run(Future<bool> Function() action, String done) async {
    setState(() {
      saving = true;
      message = null;
    });
    final ok = await action();
    if (!mounted) return;
    setState(() {
      saving = false;
      message = ok ? done : (widget.error() ?? 'บันทึกไม่สำเร็จ');
    });
  }

  Future<void> save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final values = <String, dynamic>{
      'name': t('name'),
      'description': t('description'),
      'phone': t('phone'),
      'address': t('address'),
      'business_hours': t('business_hours'),
      'delivery_area': t('delivery_area'),
      'delivery_fee': num.parse(t('delivery_fee')),
      'minimum_order': num.parse(t('minimum_order')),
      'delivery_radius_km': num.parse(t('delivery_radius_km')),
      'delivery_base_km': num.parse(t('delivery_base_km')),
      'delivery_fee_per_km': num.parse(t('delivery_fee_per_km')),
      'latitude': lat,
      'longitude': lng,
      'pickup_latitude': pickupLat,
      'pickup_longitude': pickupLng,
      'pickup_note': t('pickup_note'),
      'temporary_closed_until': closedUntil?.toUtc().toIso8601String(),
      'temporary_closed_reason': closedUntil == null
          ? ''
          : t('temporary_closed_reason'),
      'scheduled_orders_enabled': scheduled,
      'scheduled_min_notice_minutes': int.parse(
        t('scheduled_min_notice_minutes'),
      ),
      'scheduled_max_days': int.parse(t('scheduled_max_days')),
      'tax_invoice_enabled': taxInvoice,
      'tax_legal_name': t('tax_legal_name'),
      'tax_id': t('tax_id'),
      'tax_branch': t('tax_branch'),
      'tax_address': t('tax_address'),
    };
    await run(() => widget.save(values), 'บันทึกข้อมูลร้านแล้ว');
  }

  Future<void> locate({required bool pickup}) async {
    setState(() => message = 'กำลังหาตำแหน่ง…');
    try {
      final p = await widget.locate();
      final la = _num(p['latitude']), lo = _num(p['longitude']);
      if (la == null || lo == null) throw StateError('no position');
      if (!mounted) return;
      setState(() {
        if (pickup) {
          pickupLat = la;
          pickupLng = lo;
        } else {
          lat = la;
          lng = lo;
          insideArea = null;
        }
        message = 'ปักหมุดแล้ว อย่าลืมกดบันทึก';
      });
      if (!pickup) {
        final inside = await widget.checkArea(la, lo);
        if (mounted) setState(() => insideArea = inside);
      }
    } catch (e) {
      if (mounted) setState(() => message = errorMessage(e));
    }
  }

  Widget numberField(
    String key,
    String label, {
    required num min,
    required num max,
    bool integer = false,
    String? suffix,
  }) => TextFormField(
    controller: c[key],
    enabled: widget.enabled && !saving,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    validator: (v) {
      final n = integer
          ? int.tryParse((v ?? '').trim())
          : num.tryParse((v ?? '').trim());
      if (n == null || n < min || n > max) return 'ใส่ตัวเลข $min–$max';
      return null;
    },
  );

  Widget textField(
    String key,
    String label, {
    int max = 200,
    int lines = 1,
    bool required = false,
    String? Function(String)? check,
  }) => TextFormField(
    controller: c[key],
    enabled: widget.enabled && !saving,
    maxLength: max,
    minLines: lines,
    maxLines: lines == 1 ? 1 : lines + 2,
    decoration: InputDecoration(labelText: label, counterText: ''),
    validator: (v) {
      final value = (v ?? '').trim();
      if (required && value.isEmpty) return 'กรุณากรอก$label';
      return check?.call(value);
    },
  );

  Widget section(String title, List<Widget> children, {String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (hint != null) Text(hint, style: _muted),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      );

  Widget image(String kind, String label) {
    final url = kind == 'logo'
        ? widget.store['image_url']
        : widget.store['cover_url'];
    final has =
        widget.store[kind == 'logo' ? 'logo_path' : 'cover_path'] != null;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: kind == 'logo' ? 56 : 96,
            height: 56,
            child: url is String && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => const ColoredBox(
                      color: Color(0xFFF3EFF1),
                      child: Icon(Icons.image_outlined),
                    ),
                  )
                : const ColoredBox(
                    color: Color(0xFFF3EFF1),
                    child: Icon(Icons.image_outlined),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(has ? '$label · อัปโหลดแล้ว' : '$label · ยังไม่มีรูป'),
        ),
        TextButton(
          onPressed: widget.enabled && !saving
              ? () => run(() => widget.pickImage(kind), 'อัปโหลด$labelแล้ว')
              : null,
          child: Text(has ? 'เปลี่ยน' : 'เลือกรูป'),
        ),
        if (has)
          TextButton(
            onPressed: widget.enabled && !saving
                ? () => run(
                    () => widget.save({
                      kind == 'logo' ? 'logo_path' : 'cover_path': null,
                    }),
                    'ลบ$labelแล้ว',
                  )
                : null,
            child: const Text('ลบ'),
          ),
      ],
    );
  }

  Widget pin(String label, num? la, num? lo, {required bool pickup}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        la == null || lo == null
            ? '$label · ยังไม่ปักหมุด'
            : '$label · ${la.toStringAsFixed(5)}, ${lo.toStringAsFixed(5)}',
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: widget.enabled && !saving
                ? () => locate(pickup: pickup)
                : null,
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('ใช้ตำแหน่งปัจจุบัน'),
          ),
          if (la != null && lo != null) ...[
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$la,$lo',
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('ดูบนแผนที่'),
            ),
            TextButton(
              onPressed: widget.enabled && !saving
                  ? () => setState(() {
                      if (pickup) {
                        pickupLat = pickupLng = null;
                      } else {
                        lat = lng = null;
                        insideArea = null;
                      }
                    })
                  : null,
              child: const Text('ล้างหมุด'),
            ),
          ],
        ],
      ),
    ],
  );

  Future<void> pickClosedUntil() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'พักร้านถึงวันที่',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'เปิดอีกครั้งเวลา',
    );
    if (time == null || !mounted) return;
    final until = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (!until.isAfter(DateTime.now())) {
      setState(() => message = 'เวลาพักร้านต้องอยู่ในอนาคต');
      return;
    }
    setState(() => closedUntil = until);
  }

  String two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final published = widget.store['is_published'] == true;
    final editable = widget.enabled && !saving;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ข้อมูลร้าน',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('เผยแพร่ร้านบน ZOKY'),
            subtitle: Text(
              published
                  ? 'ลูกค้าเห็นร้านแล้ว'
                  : 'ระบบตรวจความพร้อมร้านก่อนเผยแพร่',
            ),
            value: published,
            onChanged: editable
                ? (v) => run(
                    () => widget.setPublished(v),
                    v ? 'เผยแพร่ร้านแล้ว' : 'ซ่อนร้านแล้ว',
                  )
                : null,
          ),
          section('รูปร้าน', [
            image('logo', 'โลโก้'),
            const SizedBox(height: 8),
            image('cover', 'รูปปก'),
          ], hint: 'อัปโหลดทันทีเมื่อเลือกรูป (JPG, PNG, WebP ไม่เกิน 8 MB)'),
          section('ข้อมูลทั่วไป', [
            textField('name', 'ชื่อร้าน', max: 120, required: true),
            textField('description', 'คำอธิบายร้าน', max: 1000, lines: 2),
            textField('phone', 'เบอร์โทร', max: 50, required: true),
            textField(
              'address',
              'ที่อยู่ร้าน',
              max: 800,
              lines: 2,
              required: true,
            ),
            textField('business_hours', 'เวลาเปิด-ปิด (ข้อความ)', max: 200),
          ]),
          section('การจัดส่ง', [
            textField('delivery_area', 'พื้นที่จัดส่ง', max: 500, lines: 2),
            numberField(
              'delivery_fee',
              'ค่าส่งเริ่มต้น',
              min: 0,
              max: 9999,
              suffix: '฿',
            ),
            numberField(
              'minimum_order',
              'ยอดสั่งขั้นต่ำ',
              min: 0,
              max: 99999,
              suffix: '฿',
            ),
            numberField(
              'delivery_radius_km',
              'ระยะส่งสูงสุด',
              min: 0.5,
              max: 100,
              suffix: 'กม.',
            ),
            numberField(
              'delivery_base_km',
              'ระยะที่รวมในค่าส่งเริ่มต้น',
              min: 0,
              max: 100,
              suffix: 'กม.',
            ),
            numberField(
              'delivery_fee_per_km',
              'ค่าส่งต่อกม. ที่เกิน',
              min: 0,
              max: 999,
              suffix: '฿',
            ),
          ]),
          section('ตำแหน่งร้าน', [
            pin('ตำแหน่งร้าน (ใช้คิดระยะส่ง)', lat, lng, pickup: false),
            if (insideArea == false)
              const Text(
                'ตำแหน่งนี้อยู่นอกพื้นที่ให้บริการของ ZOKY',
                style: TextStyle(color: Color(0xFF9A2525)),
              ),
            if (insideArea == true)
              const Text(
                'อยู่ในพื้นที่ให้บริการ ✓',
                style: TextStyle(color: Color(0xFF1F8A4C)),
              ),
            const SizedBox(height: 8),
            pin('จุดให้ลูกค้ามารับเอง', pickupLat, pickupLng, pickup: true),
            textField('pickup_note', 'คำแนะนำจุดรับ', max: 300),
          ], hint: 'ยืนที่ร้านแล้วกด "ใช้ตำแหน่งปัจจุบัน"'),
          section('พักร้านชั่วคราว', [
            Text(
              closedUntil == null
                  ? 'ไม่ได้พักร้าน'
                  : 'พักร้านถึง ${closedUntil!.day}/${closedUntil!.month}/${closedUntil!.year + 543} ${two(closedUntil!.hour)}:${two(closedUntil!.minute)}',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: editable ? pickClosedUntil : null,
                  child: Text(
                    closedUntil == null ? 'ตั้งเวลาพักร้าน' : 'เปลี่ยนเวลา',
                  ),
                ),
                if (closedUntil != null)
                  TextButton(
                    onPressed: editable
                        ? () => setState(() => closedUntil = null)
                        : null,
                    child: const Text('ยกเลิกการพักร้าน'),
                  ),
              ],
            ),
            if (closedUntil != null)
              textField(
                'temporary_closed_reason',
                'เหตุผล (ลูกค้าเห็น)',
                max: 200,
              ),
          ]),
          section('สั่งล่วงหน้า', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('รับออเดอร์ล่วงหน้า'),
              value: scheduled,
              onChanged: editable ? (v) => setState(() => scheduled = v) : null,
            ),
            if (scheduled) ...[
              numberField(
                'scheduled_min_notice_minutes',
                'สั่งล่วงหน้าอย่างน้อย',
                min: 15,
                max: 1440,
                integer: true,
                suffix: 'นาที',
              ),
              numberField(
                'scheduled_max_days',
                'สั่งล่วงหน้าได้ไม่เกิน',
                min: 1,
                max: 30,
                integer: true,
                suffix: 'วัน',
              ),
            ],
          ]),
          section('ใบกำกับภาษี', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ออกใบกำกับภาษีให้ลูกค้า'),
              value: taxInvoice,
              onChanged: editable
                  ? (v) => setState(() => taxInvoice = v)
                  : null,
            ),
            if (taxInvoice) ...[
              textField(
                'tax_legal_name',
                'ชื่อผู้เสียภาษี',
                max: 200,
                required: true,
              ),
              textField(
                'tax_id',
                'เลขประจำตัวผู้เสียภาษี 13 หลัก',
                max: 17,
                required: true,
                check: (v) =>
                    RegExp(
                      r'^\d{13}$',
                    ).hasMatch(v.replaceAll(RegExp(r'[\s-]'), ''))
                    ? null
                    : 'ต้องเป็นตัวเลข 13 หลัก',
              ),
              textField('tax_branch', 'สาขา', max: 60),
              textField('tax_address', 'ที่อยู่ตามใบกำกับ', max: 500, lines: 2),
            ],
          ]),
          const SizedBox(height: 16),
          if (message != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(message!),
              ),
            ),
          FilledButton(
            onPressed: editable ? save : null,
            child: Text(saving ? 'กำลังบันทึก…' : 'บันทึกข้อมูลร้าน'),
          ),
        ],
      ),
    );
  }
}
