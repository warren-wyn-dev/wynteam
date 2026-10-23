import 'dart:async';
import 'package:flutter/material.dart';
import '../data/merchant_repository.dart';

class PaymentReviewDialog extends StatefulWidget {
  const PaymentReviewDialog({
    super.key,
    required this.repository,
    required this.storeId,
    required this.order,
    this.store = const {},
    required this.save,
    required this.error,
  });
  final MerchantRepository repository;
  final String storeId;
  final Json order;
  final Json store;
  final Future<bool> Function(
    String status,
    String note,
    bool manualConfirmation,
  )
  save;
  final String? Function() error;
  @override
  State<PaymentReviewDialog> createState() => _PaymentReviewDialogState();
}

class _PaymentReviewDialogState extends State<PaymentReviewDialog> {
  final note = TextEditingController();
  late Future<String?> slip;
  bool saving = false,
      failed = false,
      slipVisible = false,
      manualConfirmed = false;
  bool get manualMode =>
      widget.order['payment_slip_path'] == null &&
      widget.order['payment_status'] == 'pending' &&
      widget.order['payment_provider'] != 'stripe' &&
      widget.order['stripe_checkout_session_id'] == null;
  String? error;
  @override
  void initState() {
    super.initState();
    slip = widget.order['payment_slip_path'] == null
        ? Future.value(null)
        : widget.repository.signedUrl(
            widget.storeId,
            widget.order['id'],
            'slip',
          );
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> save(String status) async {
    if (saving ||
        failed ||
        (status == 'paid' && !(manualMode ? manualConfirmed : slipVisible))) {
      return;
    }
    if (status == 'issue' && note.text.trim().isEmpty) {
      setState(() => error = 'กรุณาระบุปัญหาที่พบในสลิป');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.save(
      status,
      note.text.trim(),
      manualMode && manualConfirmed,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      saving = false;
      failed = true;
      error = widget.error() ?? 'บันทึกไม่สำเร็จ กรุณาปิดแล้วรีเฟรช';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('ตรวจการชำระเงิน'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ออเดอร์ #${widget.order['order_number']}'),
              Text(
                'ยอดที่ต้องได้รับ ฿${(num.tryParse('${widget.order['total']}') ?? 0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              if (widget.store['promptpay_name'] != null ||
                  widget.store['bank_account_name'] != null)
                Text(
                  'ชื่อผู้รับเงิน: ${widget.store['promptpay_name'] ?? widget.store['bank_account_name']}',
                ),
              const SizedBox(height: 12),
              if (manualMode) ...[
                const Text(
                  'ไม่มีสลิปจากลูกค้า ยืนยันได้เมื่อได้รับเงินจริงจากช่องทางอื่นแล้วเท่านั้น',
                ),
                CheckboxListTile(
                  value: manualConfirmed,
                  onChanged: saving || failed
                      ? null
                      : (value) =>
                            setState(() => manualConfirmed = value == true),
                  title: const Text('ตรวจสอบแล้วว่าได้รับเงินครบตามยอด'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                FilledButton(
                  onPressed: saving || failed || !manualConfirmed
                      ? null
                      : () => save('paid'),
                  child: const Text('ยืนยันว่ารับเงินแล้ว'),
                ),
              ] else
                FutureBuilder<String?>(
                  future: slip,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          Text(errorMessage(snapshot.error!)),
                          TextButton(
                            onPressed: () => setState(
                              () => slip = widget.repository.signedUrl(
                                widget.storeId,
                                widget.order['id'],
                                'slip',
                              ),
                            ),
                            child: const Text('โหลดสลิปใหม่'),
                          ),
                        ],
                      );
                    }
                    if (snapshot.data == null) {
                      return const Text('ยังไม่มีสลิปที่ตรวจสอบได้');
                    }
                    return Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 380),
                          child: InteractiveViewer(
                            child: Image.network(
                              snapshot.data!,
                              frameBuilder: (context, child, frame, sync) {
                                if (frame != null && !slipVisible) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      setState(() => slipVisible = true);
                                    }
                                  });
                                }
                                return child;
                              },
                              fit: BoxFit.contain,
                              errorBuilder: (_, e, stack) => const Text(
                                'โหลดรูปสลิปไม่สำเร็จ กรุณารีเฟรช',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'ตรวจชื่อผู้รับ ยอดเงิน และวันเวลาก่อนยืนยัน',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: saving || failed || !slipVisible
                              ? null
                              : () => save('paid'),
                          child: Text(
                            saving ? 'กำลังบันทึก…' : 'ยืนยันว่ารับเงินแล้ว',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              TextField(
                controller: note,
                maxLength: 800,
                enabled: !saving && !failed,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ / ปัญหาที่พบ',
                ),
              ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
        OutlinedButton(
          onPressed: saving || failed || manualMode
              ? null
              : () => save('issue'),
          child: const Text('แจ้งปัญหาสลิป'),
        ),
      ],
    ),
  );
}

class DeliveryProofDialog extends StatefulWidget {
  const DeliveryProofDialog({
    super.key,
    required this.repository,
    required this.storeId,
    required this.orderId,
    required this.save,
    required this.error,
  });
  final MerchantRepository repository;
  final String storeId, orderId;
  final Future<bool> Function(String method, String path, String? note) save;
  final String? Function() error;
  @override
  State<DeliveryProofDialog> createState() => _DeliveryProofDialogState();
}

class _DeliveryProofDialogState extends State<DeliveryProofDialog> {
  final note = TextEditingController();
  String method = 'direct';
  Json? photo;
  String? error;
  bool selecting = false, saving = false;
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
    note.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    if (selecting || saving) return;
    setState(() {
      selecting = true;
      error = null;
    });
    try {
      final value = await widget.repository.pickDeliveryPhoto(
        widget.storeId,
        widget.orderId,
      );
      if (value != null) {
        if (!mounted) {
          await widget.repository.releaseDeliveryPhoto(
            widget.storeId,
            widget.orderId,
            value['path'],
          );
        } else {
          final previous = photo;
          setState(() => photo = value);
          if (previous != null) {
            await widget.repository.releaseDeliveryPhoto(
              widget.storeId,
              widget.orderId,
              previous['path'],
            );
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  Future<void> save() async {
    if (selecting || saving) return;
    if (photo == null) {
      setState(() => error = 'กรุณาแนบรูปหลักฐานส่งสำเร็จ');
      return;
    }
    if (method == 'dropoff' && note.text.trim().isEmpty) {
      setState(() => error = 'กรุณาระบุจุดวางอาหาร');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.save(
      method,
      photo!['path'],
      method == 'dropoff' ? note.text.trim() : null,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      saving = false;
      error = widget.error() ?? 'บันทึกไม่สำเร็จ กรุณาปิดแล้วรีเฟรช';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !selecting,
    child: AlertDialog(
      title: const Text('ยืนยันส่งสำเร็จ'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'วิธีส่ง'),
                items: const [
                  DropdownMenuItem(
                    value: 'direct',
                    child: Text('ส่งให้ผู้รับโดยตรง'),
                  ),
                  DropdownMenuItem(
                    value: 'dropoff',
                    child: Text('วางอาหารตามจุดนัดหมาย'),
                  ),
                ],
                onChanged: saving || selecting
                    ? null
                    : (value) => setState(() => method = value!),
              ),
              const SizedBox(height: 16),
              if (method == 'dropoff')
                TextField(
                  controller: note,
                  enabled: !saving,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'จุดวางอาหาร (จำเป็น)',
                  ),
                ),
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child:
                        photo!['previewUrl'] is! String ||
                            (photo!['previewUrl'] as String).isEmpty
                        ? const Text('แนบรูปแล้ว แต่แสดงตัวอย่างไม่ได้')
                        : Image.network(
                            photo!['previewUrl'] as String,
                            fit: BoxFit.contain,
                            errorBuilder: (_, e, stack) =>
                                const Text('แนบรูปแล้ว แต่แสดงตัวอย่างไม่ได้'),
                          ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: saving || selecting ? null : pick,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  selecting
                      ? 'กำลังตรวจรูป…'
                      : photo == null
                      ? 'แนบรูปหลักฐาน (จำเป็น)'
                      : 'เปลี่ยนรูปหลักฐาน',
                ),
              ),
              const Text(
                'JPEG, PNG หรือ WebP ไม่เกิน 8 MB\nรูปเป็นหลักฐานส่วนตัวของออเดอร์ ลูกค้าจะได้รับแจ้งเมื่อบันทึกสำเร็จ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving || selecting ? null : () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
        FilledButton(
          onPressed: saving || selecting ? null : save,
          child: Text(saving ? 'กำลังบันทึก…' : 'ยืนยันส่งสำเร็จ'),
        ),
      ],
    ),
  );
}

Future<String?> requestCancellation(
  BuildContext context,
  String orderNumber,
  bool paid,
) => showDialog<String>(
  context: context,
  builder: (_) => _CancellationDialog(orderNumber: orderNumber, paid: paid),
);

class _CancellationDialog extends StatefulWidget {
  const _CancellationDialog({required this.orderNumber, required this.paid});
  final String orderNumber;
  final bool paid;
  @override
  State<_CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<_CancellationDialog> {
  final note = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('ยกเลิก #${widget.orderNumber}'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.paid)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'ออเดอร์นี้ชำระแล้ว ระบบจะเปิดรายการรอคืนเงิน การยกเลิกไม่ได้คืนเงินอัตโนมัติ',
              ),
            ),
          TextFormField(
            controller: note,
            maxLength: 800,
            decoration: const InputDecoration(labelText: 'เหตุผลที่ยกเลิก'),
            validator: (v) => (v ?? '').trim().length < 3
                ? 'กรุณาระบุเหตุผลอย่างน้อย 3 ตัวอักษร'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('กลับ'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, note.text.trim());
          }
        },
        child: const Text('ยืนยันยกเลิก'),
      ),
    ],
  );
}
