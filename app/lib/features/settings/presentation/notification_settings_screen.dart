import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notification_settings_repository.dart';
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_diagnostics_sheet.dart';
import '../../push/presentation/push_notification_service.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';

/// WYN-044 -- lets a user turn each of the 7 notification categories
/// (Master Spec section 21) on/off. Reached from SettingsScreen's
/// "การแจ้งเตือน" row. See
/// .wyn/docs/design/wyn-044-notification-settings.md.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.notificationSettingsRepository,
    this.pushNotificationService,
  });

  final NotificationSettingsRepository notificationSettingsRepository;

  /// Beta4 §11.2 -- optional/defaulted, the convention every repository
  /// param in this app follows. Only injected by tests; production lets
  /// this screen build the real service.
  final PushNotificationService? pushNotificationService;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationSettings _settings = const NotificationSettings();
  bool _isLoadingInitial = true;
  String? _error;

  /// Design Rule #1: a Set of category keys currently mid-save, NOT one
  /// shared bool -- a shared flag would disable every row's Switch
  /// whenever any single row is saving, which is exactly the UX bug the
  /// Design spec calls out explicitly (unlike SettingsScreen's own
  /// Private Account toggle, which only ever has 1 toggle to begin
  /// with, so a shared flag there is harmless).
  final Set<String> _saving = {};

  late final PushNotificationService _pushService =
      widget.pushNotificationService ??
          PushNotificationService(PushTokenRepository(Supabase.instance.client));

  /// Beta4 §11.2. Null while the first read is in flight -- the device
  /// row renders a disabled placeholder rather than guessing "off" and
  /// flipping a moment later.
  PushPermissionState? _pushState;
  bool _isRequestingPush = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPushState();
  }

  Future<void> _loadPushState() async {
    final state = await _pushService.currentPermissionState();
    if (!mounted) return;
    setState(() => _pushState = state);
  }

  /// The second, deliberate entry point to the OS prompt (the first is
  /// [PushPermissionCard] on the Notifications screen).
  ///
  /// The 7 category switches below have always governed *which*
  /// notifications exist -- they gate the `notifications` row insert
  /// itself, server-side, so push inherits them for free. What no
  /// screen said, before Beta4, was whether this device could receive a
  /// push at all: a person could have all 7 categories on and still
  /// never see a notification because the OS permission had never been
  /// granted, with nothing anywhere to tell them so or to fix it. This
  /// row is that missing state, on the screen where someone goes
  /// looking for it.
  Future<void> _enablePush() async {
    if (_isRequestingPush) return;
    setState(() => _isRequestingPush = true);
    final state = await _pushService.requestPermissionAndRegister();
    if (!mounted) return;
    setState(() {
      _pushState = state;
      _isRequestingPush = false;
    });
    if (state == PushPermissionState.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เปิดการแจ้งเตือนได้ที่การตั้งค่าของระบบ'),
        ),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final settings = await widget.notificationSettingsRepository.fetch();
      if (!mounted) return;
      setState(() => _settings = settings);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดการตั้งค่าไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _toggle(String category, bool value) async {
    final previous = _settings;
    setState(() {
      _settings = _settings.copyWithCategory(category, value);
      _saving.add(category);
    });
    try {
      await widget.notificationSettingsRepository.upsertCategory(
        category: category,
        value: value,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _settings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(category));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    return ListView(
      children: [
        _buildDeviceSection(),
        _buildDiagnosticsRow(),
        _buildCategoryHeader(),
        SwitchListTile(
          secondary: const Icon(Icons.favorite_border),
          title: const Text('ถูกใจ'),
          // WYN-102: was "...โพสต์, Pop หรือรีโพสต์..." -- the setting
          // still governs Pop-like notifications too (unchanged), just
          // no longer names Pop in UI copy.
          subtitle: const Text('เมื่อมีคนถูกใจโพสต์หรือรีโพสต์ของคุณ'),
          value: _settings.likes,
          onChanged:
              _saving.contains('likes') ? null : (v) => _toggle('likes', v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.mode_comment_outlined),
          title: const Text('คอมเมนต์'),
          subtitle: const Text('เมื่อมีคนแสดงความคิดเห็นหรือกล่าวถึงคุณในโพสต์'),
          value: _settings.comments,
          onChanged: _saving.contains('comments')
              ? null
              : (v) => _toggle('comments', v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.person_add_outlined),
          title: const Text('ผู้ติดตาม'),
          subtitle: const Text('เมื่อมีคนติดตามคุณ หรือส่ง/ยอมรับคำขอติดตาม'),
          value: _settings.follows,
          onChanged: _saving.contains('follows')
              ? null
              : (v) => _toggle('follows', v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.mail_outline),
          title: const Text('ข้อความ'),
          subtitle: const Text('เมื่อมีคนที่ไม่ได้ติดตามกันส่งคำขอข้อความถึงคุณ'),
          value: _settings.messages,
          onChanged: _saving.contains('messages')
              ? null
              : (v) => _toggle('messages', v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.groups_outlined),
          title: const Text('Club'),
          subtitle: const Text(
              'เมื่อมีความเคลื่อนไหวใน Club ที่คุณเป็นเจ้าของหรือเป็นสมาชิก (โพสต์, คำขอเข้าร่วม, การกล่าวถึง)'),
          value: _settings.club,
          onChanged:
              _saving.contains('club') ? null : (v) => _toggle('club', v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.trending_up),
          title: const Text('กำลังนิยม'),
          subtitle: const Text('เมื่อโพสต์ของคุณกำลังเป็นที่นิยมหรือติด WYN Top 100'),
          value: _settings.trending,
          onChanged: _saving.contains('trending')
              ? null
              : (v) => _toggle('trending', v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.campaign_outlined),
          title: const Text('ระบบ'),
          subtitle: const Text('ประกาศทั่วไปจากทีมงาน WYN'),
          value: _settings.system,
          onChanged:
              _saving.contains('system') ? null : (v) => _toggle('system', v),
        ),
      ],
    );
  }

  /// Beta4 §11.2: "การแจ้งเตือนบนเครื่องนี้" -- the device-permission
  /// state, above the 7 category switches because it gates all of them.
  /// A category being on means nothing if this device cannot receive a
  /// push.
  ///
  /// Rendered as a row per state rather than a `Switch`, because a
  /// switch would lie in three of the four: nothing in this app (or any
  /// app) can turn an OS notification permission back *off*, and a
  /// denied permission cannot be turned on from here either.
  Widget _buildDeviceSection() {
    return switch (_pushState) {
      null => const ListTile(
          leading: Icon(Icons.notifications_outlined, color: WynColors.faint),
          title: Text('การแจ้งเตือนบนเครื่องนี้'),
          subtitle: Text('กำลังตรวจสอบ...'),
          enabled: false,
        ),
      PushPermissionState.granted => const ListTile(
          key: Key('push_device_granted'),
          leading: Icon(Icons.notifications_active_outlined,
              color: WynColors.sapphire),
          title: Text('การแจ้งเตือนบนเครื่องนี้'),
          subtitle: Text('เปิดอยู่ — เครื่องนี้จะได้รับการแจ้งเตือนตามหมวดหมู่ด้านล่าง'),
          trailing: Icon(Icons.check_circle, color: WynColors.sapphire),
        ),
      PushPermissionState.notDetermined => ListTile(
          key: const Key('push_device_enable'),
          leading: const Icon(Icons.notifications_outlined,
              color: WynColors.graphite),
          title: const Text('เปิดการแจ้งเตือนบนเครื่องนี้'),
          subtitle: const Text(
              'ยังไม่ได้เปิด — แตะเพื่ออนุญาต แล้วเลือกหมวดหมู่ที่ต้องการด้านล่าง'),
          trailing: _isRequestingPush
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right, color: WynColors.faint),
          onTap: _isRequestingPush ? null : _enablePush,
        ),
      // No action offered on purpose: once refused, neither iOS nor any
      // browser will show the prompt again, so a tappable row here would
      // do nothing at all -- see PushPermissionState.denied.
      PushPermissionState.denied => const ListTile(
          key: Key('push_device_denied'),
          leading:
              Icon(Icons.notifications_off_outlined, color: WynColors.graphite),
          title: Text('การแจ้งเตือนบนเครื่องนี้'),
          subtitle: Text(
              'ปิดอยู่ — เปิดใหม่ได้ที่การตั้งค่าของระบบเท่านั้น '
              'การแจ้งเตือนในแอปยังทำงานตามปกติ'),
        ),
      // Nothing to show: this build has no push capability at all (no
      // Firebase config, or web without a VAPID key). The category
      // switches below still matter -- they govern in-app notifications
      // too, which work regardless.
      PushPermissionState.unsupported => const SizedBox.shrink(),
    };
  }

  /// Shown in every state, including [PushPermissionState.unsupported]
  /// where the row above renders nothing: "unsupported" is exactly when
  /// a person most needs to be told why, and it is the one state whose
  /// cause (a browser that cannot receive push, or a web app opened
  /// outside the Home Screen on iOS) is invisible from here.
  Widget _buildDiagnosticsRow() {
    return ListTile(
      key: const Key('push_diagnostics_entry'),
      leading: const Icon(Icons.help_outline, color: WynColors.graphite),
      title: const Text('ไม่ได้รับการแจ้งเตือน?'),
      subtitle: const Text('ตรวจสอบทีละขั้นว่าติดตรงไหน'),
      trailing: const Icon(Icons.chevron_right, color: WynColors.faint),
      onTap: () => showPushDiagnosticsSheet(
        context,
        pushNotificationService: widget.pushNotificationService,
      ),
    );
  }

  /// Names what the switches below actually control, now that a
  /// device-level row sits above them -- without it the two groups read
  /// as one flat list and "ถูกใจ" looks like a sibling of "การแจ้งเตือน
  /// บนเครื่องนี้" rather than something it depends on.
  Widget _buildCategoryHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(WynSpacing.space4, WynSpacing.space4,
          WynSpacing.space4, WynSpacing.space2),
      child: Text(
        'รับการแจ้งเตือนเรื่องไหนบ้าง',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: WynColors.graphite,
        ),
      ),
    );
  }
}
