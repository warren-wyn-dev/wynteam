import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/notification_settings.dart';
import '../data/notification_settings_repository.dart';

/// Screen 2 of .wyn/docs/design/wyn-044-notification-settings.md -- 6
/// SwitchListTile toggles, one per NotificationCategory, reached from
/// SettingsScreen's new "การแจ้งเตือน" section.
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
  bool _isLoading = true;
  NotificationSettings _settings = NotificationSettings.allEnabled;

  /// Tracks which categories are mid-save, per-category rather than one
  /// shared bool -- toggling one row must not disable the other 5 while
  /// its own request is in flight (Design spec's "Toggling" state).
  final Set<NotificationCategory> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final settings =
          await widget.notificationSettingsRepository.fetchSettings();
      if (!mounted) return;
      setState(() => _settings = settings);
    } catch (_) {
      // Fail-open (Design spec's Screen 2 "Interactions"): show every
      // category as enabled rather than risk a failed fetch reading as
      // "the user turned these off". _settings already defaults to
      // NotificationSettings.allEnabled, so nothing to reset here.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('โหลดค่าปัจจุบันไม่สำเร็จ ลองรีเฟรชหน้านี้ใหม่'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggle(NotificationCategory category, bool value) async {
    final previous = _settings;
    setState(() {
      _settings = _settings.copyWith(category, value);
      _saving.add(category);
    });
    try {
      await widget.notificationSettingsRepository
          .updateCategory(category, value);
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
      appBar: AppBar(title: const Text('ตั้งค่าการแจ้งเตือน')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  _tile(
                    category: NotificationCategory.likes,
                    icon: Icons.favorite_border,
                    title: 'ถูกใจและ ReDrop',
                    subtitle: 'เมื่อมีคนถูกใจหรือ ReDrop เนื้อหาของคุณ',
                  ),
                  _tile(
                    category: NotificationCategory.comments,
                    icon: Icons.comment_outlined,
                    title: 'คอมเมนต์และการกล่าวถึง',
                    subtitle: 'เมื่อมีคนคอมเมนต์หรือกล่าวถึง (@mention) คุณ',
                  ),
                  _tile(
                    category: NotificationCategory.follows,
                    icon: Icons.person_add_alt,
                    title: 'การติดตาม',
                    subtitle: 'เมื่อมีคนติดตามคุณ หรือขอ/ตอบรับการติดตาม',
                  ),
                  _tile(
                    category: NotificationCategory.messages,
                    icon: Icons.mail_outline,
                    title: 'ข้อความ',
                    subtitle: 'เมื่อมีคำขอส่งข้อความใหม่',
                  ),
                  _tile(
                    category: NotificationCategory.club,
                    icon: Icons.groups_outlined,
                    title: 'Club',
                    subtitle: 'เมื่อมีคำขอเข้าร่วมหรือได้รับอนุมัติเข้า Club',
                  ),
                  _tile(
                    category: NotificationCategory.system,
                    icon: Icons.campaign_outlined,
                    title: 'ประกาศจากระบบ',
                    subtitle:
                        'ประกาศด้านความปลอดภัยหรือนโยบายจากทีมงาน WYN',
                  ),
                  const SizedBox(height: WynSpacing.space4),
                ],
              ),
            ),
    );
  }

  Widget _tile({
    required NotificationCategory category,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSaving = _saving.contains(category);
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: _settings[category],
      onChanged: isSaving ? null : (value) => _toggle(category, value),
    );
  }
}
