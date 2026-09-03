import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../data/push_token_repository.dart';
import 'push_notification_service.dart';

/// The in-app explainer that has to come *before* the OS notification
/// prompt -- Beta4 §11.2: "ห้ามขอ Permission ทันทีโดยไม่มี UX ที่เหมาะสม".
///
/// Shown at the top of the Notifications list, and nowhere else. That
/// placement is the whole point of the pattern: a person who has just
/// opened the screen whose entire purpose is notifications has already
/// told you they care about notifications, and the card is asking about
/// the thing they are currently looking at. Compare the old behaviour,
/// which fired the OS dialog from `RootShell.initState` the moment
/// onboarding finished -- a system alert about "notifications" over a
/// feed the user had not read one post of yet.
///
/// Two states are visible, and only two:
/// * [PushPermissionState.notDetermined] -- the ask, with a reason and
///   a "ไม่ใช่ตอนนี้" that dismisses for this visit. The OS prompt
///   appears only after the person taps "เปิดการแจ้งเตือน".
/// * [PushPermissionState.denied] -- a short, non-repeating note that
///   the switch now lives in system settings. Neither iOS nor any
///   browser will re-show the prompt after a refusal, so a button here
///   would do nothing; saying where the control actually is beats a
///   button that silently fails.
///
/// [PushPermissionState.granted] and [PushPermissionState.unsupported]
/// render nothing at all -- there is no ask left to make in the first,
/// and nothing to ask *for* in the second (no Firebase config, or a web
/// build without a VAPID key; see [PushEnv]). Rendering an offer the
/// app cannot honour is worse than rendering nothing.
class PushPermissionCard extends StatefulWidget {
  const PushPermissionCard({super.key, this.pushNotificationService});

  /// Optional/defaulted, the convention every repository param in this
  /// app follows -- tests inject a fake instead of reaching a real
  /// Firebase/Supabase.
  final PushNotificationService? pushNotificationService;

  @override
  State<PushPermissionCard> createState() => _PushPermissionCardState();
}

class _PushPermissionCardState extends State<PushPermissionCard> {
  late final PushNotificationService _service = widget.pushNotificationService ??
      PushNotificationService(PushTokenRepository(Supabase.instance.client));

  /// Null while the first read is in flight -- the card renders nothing
  /// rather than flashing an ask that may turn out to be unnecessary.
  PushPermissionState? _state;

  /// "ไม่ใช่ตอนนี้". Deliberately per-visit state, not persisted: this
  /// screen is remounted on every visit to the Notifications tab (see
  /// RootShell's `_notificationsVisitKey`), so dismissing hides the card
  /// now and it returns next time. Persisting the dismissal would mean
  /// one reflexive tap permanently removes the only entry point to
  /// enabling push, which is the exact failure mode this whole card
  /// exists to avoid.
  bool _dismissed = false;

  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await _service.currentPermissionState();
    if (!mounted) return;
    setState(() => _state = state);
  }

  Future<void> _request() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    final state = await _service.requestPermissionAndRegister();
    if (!mounted) return;
    setState(() {
      _state = state;
      _isRequesting = false;
    });
    if (state == PushPermissionState.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดการแจ้งเตือนแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return switch (_state) {
      PushPermissionState.notDetermined => _buildAsk(),
      PushPermissionState.denied => _buildDeniedNote(),
      // granted / unsupported / still-loading -- see the class doc.
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildAsk() {
    return Container(
      key: const Key('push_permission_ask'),
      margin: const EdgeInsets.fromLTRB(WynSpacing.space4, WynSpacing.space3,
          WynSpacing.space4, WynSpacing.space1),
      padding: const EdgeInsets.all(WynSpacing.space4),
      decoration: BoxDecoration(
        border: Border.all(color: WynColors.hairline),
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 18, color: WynColors.sapphire),
              SizedBox(width: WynSpacing.space2),
              Expanded(
                child: Text(
                  'เปิดการแจ้งเตือนบนเครื่องนี้',
                  style: _cardTitleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: WynSpacing.space2),
          const Text(
            'รู้ทันทีเมื่อมีคนถูกใจ คอมเมนต์ ติดตามคุณ '
            'หรือมีความเคลื่อนไหวใน Club — เลือกได้ว่าจะรับเรื่องไหนบ้าง '
            'ที่ ตั้งค่า → การแจ้งเตือน',
            style: _cardBodyStyle,
          ),
          const SizedBox(height: WynSpacing.space3),
          Row(
            children: [
              FilledButton(
                key: const Key('push_permission_enable_button'),
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: WynColors.sapphire,
                  foregroundColor: WynColors.paper,
                  padding: const EdgeInsets.symmetric(
                    horizontal: WynSpacing.space5,
                    vertical: WynSpacing.space2 + 2,
                  ),
                ),
                onPressed: _isRequesting ? null : _request,
                child: _isRequesting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: WynColors.paper),
                      )
                    : const Text('เปิดการแจ้งเตือน',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: WynSpacing.space2),
              TextButton(
                key: const Key('push_permission_dismiss_button'),
                style: TextButton.styleFrom(foregroundColor: WynColors.graphite),
                onPressed:
                    _isRequesting ? null : () => setState(() => _dismissed = true),
                child: const Text('ไม่ใช่ตอนนี้',
                    style: TextStyle(fontSize: 15, color: WynColors.graphite)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeniedNote() {
    return const Padding(
      key: Key('push_permission_denied'),
      padding: EdgeInsets.fromLTRB(WynSpacing.space4, WynSpacing.space3,
          WynSpacing.space4, WynSpacing.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 16, color: WynColors.graphite),
          SizedBox(width: WynSpacing.space2),
          Expanded(
            child: Text(
              'การแจ้งเตือนบนเครื่องนี้ถูกปิดอยู่ '
              'เปิดใหม่ได้ที่การตั้งค่าของระบบ (หรือการตั้งค่าเว็บไซต์ในเบราว์เซอร์) '
              'การแจ้งเตือนในแอปยังแสดงที่หน้านี้ตามปกติ',
              style: _cardBodyStyle,
            ),
          ),
        ],
      ),
    );
  }
}

const _cardTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: WynColors.ink,
);

const _cardBodyStyle = TextStyle(
  fontSize: 13,
  color: WynColors.graphite,
  height: 1.45,
);
