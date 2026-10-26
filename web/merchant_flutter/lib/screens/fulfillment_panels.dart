import 'dart:async';
import 'package:flutter/material.dart';
import '../data/merchant_repository.dart';

class FulfillmentSettingsPanel extends StatefulWidget {
  const FulfillmentSettingsPanel({
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
  State<FulfillmentSettingsPanel> createState() =>
      _FulfillmentSettingsPanelState();
}

class _FulfillmentSettingsPanelState extends State<FulfillmentSettingsPanel> {
  late bool pickup, delivery, cod;
  late final TextEditingController prep;
  bool saving = false;
  String? error;
  void readStore() {
    pickup = widget.store['pickup_enabled'] == true;
    delivery = widget.store['delivery_enabled'] != false;
    cod = widget.store['cod_enabled'] == true;
  }

  @override
  void initState() {
    super.initState();
    readStore();
    prep = TextEditingController(text: '${widget.store['prep_minutes'] ?? 15}');
  }

  @override
  void didUpdateWidget(covariant FulfillmentSettingsPanel old) {
    super.didUpdateWidget(old);
    if (old.store['id'] != widget.store['id'] ||
        old.store['updated_at'] != widget.store['updated_at']) {
      readStore();
      prep.text = '${widget.store['prep_minutes'] ?? 15}';
    }
  }

  @override
  void dispose() {
    prep.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final minutes = int.tryParse(prep.text);
    if (minutes == null || minutes < 5 || minutes > 120) {
      setState(() => error = 'เวลาเตรียมอาหารต้องเป็นจำนวนเต็ม 5–120 นาที');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.save({
      'pickup': pickup,
      'delivery': delivery,
      'cod': cod && delivery,
      'prepMinutes': minutes,
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
        SwitchListTile(
          title: const Text('ร้านจัดส่งเอง'),
          value: delivery,
          onChanged: enabled
              ? (v) => setState(() {
                  delivery = v;
                  if (!v) cod = false;
                })
              : null,
        ),
        SwitchListTile(
          title: const Text('รับเองที่ร้าน'),
          value: pickup,
          onChanged: enabled ? (v) => setState(() => pickup = v) : null,
        ),
        SwitchListTile(
          title: const Text('เก็บเงินปลายทาง'),
          subtitle: const Text('ใช้ได้เฉพาะร้านจัดส่งเอง'),
          value: cod,
          onChanged: enabled && delivery
              ? (v) => setState(() => cod = v)
              : null,
        ),
        TextField(
          controller: prep,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'เวลาเตรียมอาหาร (นาที)',
          ),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          onPressed: enabled ? save : null,
          child: const Text('บันทึกรูปแบบรับอาหาร'),
        ),
      ],
    );
  }
}

class RefundSlipDialog extends StatefulWidget {
  const RefundSlipDialog({
    super.key,
    required this.repository,
    required this.storeId,
    required this.orderId,
    required this.save,
    required this.error,
  });
  final MerchantRepository repository;
  final String storeId, orderId;
  final Future<bool> Function(String) save;
  final String? Function() error;
  @override
  State<RefundSlipDialog> createState() => _RefundSlipDialogState();
}

class _RefundSlipDialogState extends State<RefundSlipDialog> {
  Json? photo;
  bool busy = false, confirmed = false;
  String? error;
  @override
  void dispose() {
    if (photo != null) {
      unawaited(
        widget.repository
            .releaseDeliveryPhoto(
              widget.storeId,
              widget.orderId,
              photo!['path'],
            )
            .catchError((_) {}),
      );
    }
    super.dispose();
  }

  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final value = await widget.repository.pickRefundSlip(
        widget.storeId,
        widget.orderId,
      );
      if (!mounted) {
        if (value != null) {
          await widget.repository.releaseDeliveryPhoto(
            widget.storeId,
            widget.orderId,
            value['path'],
          );
        }
        return;
      }
      if (value != null) setState(() => photo = value);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (photo == null || !confirmed || busy) return;
    setState(() => busy = true);
    final ok = await widget.save(photo!['path']);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      busy = false;
      error = widget.error();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('โอนคืนแล้ว + แนบสลิป'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('โอนเงินคืนลูกค้าด้วยแอปธนาคารก่อนแนบสลิป'),
              if (photo != null)
                Image.network(
                  photo!['previewUrl'],
                  height: 220,
                  errorBuilder: (_, e, stack) =>
                      const Text('แนบรูปแล้ว แต่แสดงตัวอย่างไม่ได้'),
                ),
              OutlinedButton(
                onPressed: busy ? null : pick,
                child: const Text('แนบสลิปคืนเงิน'),
              ),
              CheckboxListTile(
                title: const Text('โอนเงินคืนครบแล้ว'),
                value: confirmed,
                onChanged: busy
                    ? null
                    : (v) => setState(() => confirmed = v == true),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
        FilledButton(
          onPressed: busy || photo == null || !confirmed ? null : save,
          child: const Text('ยืนยันคืนเงิน'),
        ),
      ],
    ),
  );
}
