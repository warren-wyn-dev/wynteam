import 'package:flutter/material.dart';

import '../data/notification_settings_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// WYN-044 -- lets a user turn each of the 7 notification categories
/// (Master Spec section 21) on/off. Reached from SettingsScreen's
/// "การแจ้งเตือน" row. See
/// .wyn/docs/design/wyn-044-notification-settings.md.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.notificationSettingsRepository,
  });

  final NotificationSettingsRepository notificationSettingsRepository;

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

  @override
  void initState() {
    super.initState();
    _load();
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
}
