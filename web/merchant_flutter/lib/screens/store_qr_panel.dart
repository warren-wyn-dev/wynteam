import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/merchant_repository.dart';

const _brand = Color(0xFFD61256);
const _sub = Color(0xFF6B6B76);
const _soft = Color(0xFFFFEFF5);

/// Founder 2026-11-04 ("ทำ ก+ข"): the store's ZOKY QR poster. The QR opens
/// the store's ZOKY web link (LINE removed 2026-11-12); the poster is rendered by
/// the web host so ZOKY and Merchant print the same design.
class StoreQrPanel extends StatefulWidget {
  const StoreQrPanel({
    super.key,
    required this.repository,
    required this.storeId,
    required this.onNotice,
  });
  final MerchantRepository repository;
  final String storeId;
  final void Function(String message) onNotice;

  @override
  State<StoreQrPanel> createState() => _StoreQrPanelState();
}

class _StoreQrPanelState extends State<StoreQrPanel> {
  Json? data;
  Uint8List? image;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void didUpdateWidget(covariant StoreQrPanel old) {
    super.didUpdateWidget(old);
    if (old.storeId != widget.storeId ||
        !identical(old.repository, widget.repository)) {
      setState(() {
        data = null;
        image = null;
        error = null;
      });
      unawaited(load());
    }
  }

  Future<void> load() async {
    final storeId = widget.storeId;
    try {
      final next = await widget.repository.storeQr(storeId);
      final raw = '${next['image'] ?? ''}';
      final comma = raw.indexOf(',');
      final bytes = raw.startsWith('data:image/png;base64,') && comma > 0
          ? base64Decode(raw.substring(comma + 1))
          : null;
      if (!mounted || storeId != widget.storeId) return;
      setState(() {
        data = next;
        image = bytes;
        error = bytes == null ? 'สร้าง QR ไม่สำเร็จ' : null;
      });
    } catch (e) {
      if (!mounted || storeId != widget.storeId) return;
      setState(() => error = 'สร้าง QR ไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.repository.saveStoreQr(widget.storeId);
      if (result == 'downloaded') widget.onNotice('บันทึกรูป QR แล้ว');
      if (result == 'not_ready' || result == 'failed') {
        widget.onNotice('บันทึกไม่สำเร็จ กดค้างที่รูปเพื่อบันทึก');
      }
    } catch (_) {
      widget.onNotice('บันทึกไม่สำเร็จ กดค้างที่รูปเพื่อบันทึก');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> shareLink() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.repository.shareStoreLink(widget.storeId);
      if (result == 'copied') widget.onNotice('คัดลอกลิงก์แล้ว');
      if (result == 'failed' || result == 'not_ready') {
        widget.onNotice('แชร์ไม่สำเร็จ');
      }
    } catch (_) {
      widget.onNotice('แชร์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget stat(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _brand,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: _sub)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final current = data;
    if (error != null && image == null) {
      return Column(
        children: [
          Text(error!, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: load, child: const Text('ลองอีกครั้ง')),
        ],
      );
    }
    if (current == null || image == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Semantics(
            label: 'กำลังสร้าง QR',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    final stats = current['stats'];
    final ready = data != null && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current['published'] != true)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ร้านยังไม่เผยแพร่ ลูกค้าที่สแกนจะยังสั่งไม่ได้',
              style: TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Semantics(
                image: true,
                label: 'ป้าย QR ร้าน',
                child: Image.memory(image!, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'ลูกค้าสแกนแล้วเปิดร้านคุณใน ZOKY สั่งได้ทันที',
          textAlign: TextAlign.center,
          style: TextStyle(color: _sub, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: ready ? save : null,
                icon: const Icon(Icons.download_rounded),
                label: const Text('บันทึกรูป'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: _brand,
                  side: const BorderSide(color: _brand),
                ),
                onPressed: ready ? shareLink : null,
                icon: const Icon(Icons.share_outlined),
                label: const Text('แชร์ลิงก์'),
              ),
            ),
          ],
        ),
        if (stats is Map) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '7 วันที่ผ่านมา จากลิงก์และ QR นี้',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    stat('${stats['opens'] ?? 0}', 'คนเปิดดู'),
                    stat('${stats['orders'] ?? 0}', 'ออเดอร์'),
                    stat(
                      '฿${(num.tryParse('${stats['sales']}') ?? 0).toStringAsFixed(0)}',
                      'ยอดขาย',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
