import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../data/push_token_repository.dart';
import 'push_notification_service.dart';

/// Shows [PushDiagnosticsSheet].
Future<void> showPushDiagnosticsSheet(
  BuildContext context, {
  PushNotificationService? pushNotificationService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WynColors.paper,
    builder: (_) => PushDiagnosticsSheet(
      pushNotificationService: pushNotificationService,
    ),
  );
}

/// Why a push is not arriving, answered on the device rather than
/// guessed at.
///
/// A push that never appears leaves no trace a person can inspect: the
/// server records that Firebase accepted it, the device records
/// nothing, and every step in between is invisible from both ends. The
/// gap that costs the most time is the narrowest one -- whether the
/// account being watched is registered on the device being held -- and
/// answering it previously meant reading system settings aloud and
/// cross-checking database rows by hand.
///
/// Each row here is one link in that chain, in the order a push travels,
/// so the first row that is not ✓ is the thing to fix. No row offers an
/// action: this screen exists to end an argument about facts, and the
/// actions all live elsewhere already (the permission ask on the
/// Notifications tab, everything else in system settings).
class PushDiagnosticsSheet extends StatefulWidget {
  const PushDiagnosticsSheet({super.key, this.pushNotificationService});

  /// Optional/defaulted, the convention every repository param in this
  /// app follows -- tests inject a fake instead of reaching a real
  /// Firebase/Supabase.
  final PushNotificationService? pushNotificationService;

  @override
  State<PushDiagnosticsSheet> createState() => _PushDiagnosticsSheetState();
}

class _PushDiagnosticsSheetState extends State<PushDiagnosticsSheet> {
  late final PushNotificationService _service = widget.pushNotificationService ??
      PushNotificationService(PushTokenRepository(Supabase.instance.client));

  PushDiagnostics? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.collectDiagnostics();
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WynSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ตรวจสอบการแจ้งเตือน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: WynColors.ink,
              ),
            ),
            const SizedBox(height: WynSpacing.space1),
            const Text(
              'แต่ละบรรทัดคือหนึ่งขั้นตอนที่การแจ้งเตือนต้องผ่าน '
              'บรรทัดแรกที่ไม่ผ่านคือจุดที่ต้องแก้',
              style: TextStyle(fontSize: 13, color: WynColors.graphite),
            ),
            const SizedBox(height: WynSpacing.space3),
            if (result == null)
              const Padding(
                key: Key('push_diagnostics_loading'),
                padding: EdgeInsets.symmetric(vertical: WynSpacing.space4),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._rows(result),
            const SizedBox(height: WynSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('push_diagnostics_close'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ปิด'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(PushDiagnostics result) {
    return [
      _CheckRow(
        key: const Key('push_diagnostics_configured'),
        ok: result.firebaseReady && result.webPushConfigured,
        label: 'แอปเวอร์ชันนี้รองรับการแจ้งเตือน',
        detail: result.firebaseReady && result.webPushConfigured
            ? null
            : 'เวอร์ชันนี้ไม่ได้ตั้งค่าไว้ — ต้องแก้ที่ฝั่ง build ไม่ใช่ที่เครื่อง',
      ),
      _CheckRow(
        key: const Key('push_diagnostics_permission'),
        ok: result.permission == PushPermissionState.granted,
        label: 'เครื่องนี้อนุญาตให้แจ้งเตือน',
        detail: switch (result.permission) {
          PushPermissionState.granted => null,
          PushPermissionState.notDetermined =>
            'ยังไม่ได้กดอนุญาต — เปิดได้ที่แท็บการแจ้งเตือน',
          PushPermissionState.denied =>
            'ถูกปฏิเสธไว้ — เปิดใหม่ได้ที่การตั้งค่าของระบบเท่านั้น',
          PushPermissionState.unsupported =>
            'เครื่องนี้หรือเบราว์เซอร์นี้ไม่รองรับ — บน iPhone/iPad '
                'ต้องเปิดจากไอคอนบนหน้าจอโฮม ไม่ใช่จาก Safari',
        },
      ),
      _CheckRow(
        key: const Key('push_diagnostics_token'),
        ok: result.hasToken,
        label: 'เครื่องนี้ได้รับรหัสอุปกรณ์แล้ว',
        detail: result.hasToken
            ? (result.tokenTail == null ? null : 'ลงท้ายด้วย ${result.tokenTail}')
            : 'ยังไม่ได้รับ — ปกติเกิดจากสองข้อบน',
      ),
      _CheckRow(
        key: const Key('push_diagnostics_registered'),
        ok: result.thisDeviceRegistered,
        label: 'บัญชีนี้ผูกกับเครื่องนี้แล้ว',
        // The row the whole sheet exists for: an account can be
        // registered on another device entirely, which looks identical
        // to a broken push from where the person is standing.
        detail: result.thisDeviceRegistered
            ? 'บัญชีนี้ลงทะเบียนไว้ ${result.registeredDeviceCount} เครื่อง '
                'รวมเครื่องนี้'
            : result.registeredDeviceCount == 0
                ? 'บัญชีนี้ยังไม่ได้ลงทะเบียนเครื่องไหนเลย'
                : 'บัญชีนี้ลงทะเบียนไว้ ${result.registeredDeviceCount} เครื่อง '
                    'แต่ไม่มีเครื่องนี้ — การแจ้งเตือนกำลังไปเด้งที่เครื่องอื่น',
      ),
      if (result.failure != null)
        Padding(
          key: const Key('push_diagnostics_failure'),
          padding: const EdgeInsets.only(top: WynSpacing.space2),
          child: Text(
            'รายละเอียดข้อผิดพลาด: ${result.failure}',
            style: const TextStyle(fontSize: 12, color: WynColors.graphite),
          ),
        ),
      Padding(
        key: const Key('push_diagnostics_summary'),
        padding: const EdgeInsets.only(top: WynSpacing.space3),
        child: Text(
          result.isReadyToReceive
              ? 'เครื่องนี้พร้อมรับการแจ้งเตือนแล้ว ถ้ายังไม่เด้ง '
                  'ให้ดูที่การตั้งค่าการแจ้งเตือนของระบบสำหรับ WYNOS Beta'
              : 'ยังรับการแจ้งเตือนไม่ได้ — ดูบรรทัดแรกที่ยังไม่ผ่านด้านบน',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color:
                result.isReadyToReceive ? WynColors.sapphire : WynColors.graphite,
          ),
        ),
      ),
    ];
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    super.key,
    required this.ok,
    required this.label,
    this.detail,
  });

  final bool ok;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WynSpacing.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: ok ? WynColors.sapphire : WynColors.graphite,
          ),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: WynColors.ink),
                ),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: WynColors.graphite,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
