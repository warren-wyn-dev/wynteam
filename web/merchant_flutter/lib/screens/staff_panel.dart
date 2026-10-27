import 'dart:async';
import 'package:flutter/material.dart';
import '../data/merchant_repository.dart';

const staffRoles = {
  'admin': 'แอดมิน',
  'manager': 'ผู้จัดการ',
  'orders': 'รับออเดอร์',
  'support': 'ดูแลลูกค้า',
  'delivery': 'ส่งอาหาร',
};
const _roleLabels = {'owner': 'เจ้าของร้าน', ...staffRoles};

/// The store's team (merchant_staff_members). Owner/admin add people by
/// @username and change roles or access; nobody edits their own row and the
/// owner row never changes. Every write is followed by a fresh server read.
class StaffPanel extends StatefulWidget {
  const StaffPanel({
    super.key,
    required this.repository,
    required this.storeId,
  });
  final MerchantRepository repository;
  final String storeId;
  @override
  State<StaffPanel> createState() => _StaffPanelState();
}

class _StaffPanelState extends State<StaffPanel> {
  final username = TextEditingController();
  String role = 'orders';
  List<Json> members = [];
  bool canManage = false, loading = false, busy = false;
  String? error, notice;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    username.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final g = ++_generation;
    setState(() => loading = true);
    try {
      final data = await widget.repository.staff(widget.storeId);
      if (!mounted || g != _generation) return;
      setState(() {
        members = [
          for (final m in (data['members'] as List? ?? [])) Json.from(m as Map),
        ];
        canManage = data['canManage'] == true;
        error = null;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        members = [];
        canManage = false;
        error = errorMessage(e);
      });
    } finally {
      if (mounted && g == _generation) setState(() => loading = false);
    }
  }

  Future<void> write(Future<void> Function() operation, String done) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    String? failed;
    try {
      await operation();
    } catch (e) {
      failed = errorMessage(e);
    }
    if (!mounted) return;
    setState(() => busy = false);
    // Always re-read the team, then report this write's own outcome.
    await load();
    if (!mounted) return;
    setState(() {
      if (failed != null) {
        error = failed;
      } else if (error == null) {
        notice = done;
      }
    });
  }

  Future<void> add() async {
    final name = username.text.trim();
    if (!RegExp(r'^@?[A-Za-z0-9_.]{2,40}$').hasMatch(name)) {
      setState(() => error = 'กรุณาใส่ @username ของบัญชี WYNOS');
      return;
    }
    await write(
      () => widget.repository.addStaff(widget.storeId, name, role),
      'เพิ่มทีมงานแล้ว',
    );
    if (mounted && error == null) username.clear();
  }

  Future<void> toggle(Json m) async {
    final active = m['active'] == true;
    if (active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ปิดสิทธิ์ทีมงาน?'),
          content: Text(
            '${name(m)} จะเข้าร้านนี้ไม่ได้จนกว่าจะเปิดสิทธิ์อีกครั้ง',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ปิดสิทธิ์'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await write(
      () => widget.repository.updateStaff(
        widget.storeId,
        '${m['user_id']}',
        '${m['role']}',
        !active,
      ),
      active ? 'ปิดสิทธิ์ทีมงานแล้ว' : 'เปิดสิทธิ์ทีมงานแล้ว',
    );
  }

  String name(Json m) =>
      '${m['display_name'] ?? m['username'] ?? 'ผู้ใช้ WYNOS'}';

  @override
  Widget build(BuildContext context) {
    final enabled = canManage && !busy && !loading;
    final activeCount = members.where((m) => m['active'] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$activeCount คนที่ใช้งานอยู่',
          style: const TextStyle(color: Color(0xFF6B6B76)),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (notice != null)
          Semantics(
            liveRegion: true,
            child: Text(
              notice!,
              style: const TextStyle(color: Color(0xFF1F8A4C)),
            ),
          ),
        if (canManage) ...[
          const SizedBox(height: 12),
          TextField(
            controller: username,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'บัญชี WYNOS',
              hintText: '@username',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'สิทธิ์'),
            items: [
              for (final e in staffRoles.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: enabled ? (v) => setState(() => role = v!) : null,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: enabled ? add : null,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('เพิ่มทีมงาน'),
          ),
        ] else if (!loading && error == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('เฉพาะเจ้าของร้านและแอดมินที่เพิ่มหรือแก้ไขทีมงานได้'),
          ),
        const SizedBox(height: 12),
        for (final m in members)
          Opacity(
            opacity: m['active'] == true ? 1 : 0.55,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text(name(m) + (m['self'] == true ? ' (คุณ)' : '')),
              subtitle: Text(
                [
                  if (m['username'] != null) '@${m['username']}',
                  _roleLabels[m['role']] ?? '${m['role']}',
                  if (m['active'] != true) 'ปิดสิทธิ์อยู่',
                ].join(' · '),
              ),
              trailing: !canManage || m['role'] == 'owner' || m['self'] == true
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          enabled: enabled,
                          tooltip: 'เปลี่ยนสิทธิ์ ${name(m)}',
                          icon: const Icon(Icons.manage_accounts_outlined),
                          onSelected: (next) => write(
                            () => widget.repository.updateStaff(
                              widget.storeId,
                              '${m['user_id']}',
                              next,
                              m['active'] == true,
                            ),
                            'อัปเดตสิทธิ์ทีมงานแล้ว',
                          ),
                          itemBuilder: (_) => [
                            for (final e in staffRoles.entries)
                              CheckedPopupMenuItem(
                                value: e.key,
                                checked: m['role'] == e.key,
                                child: Text(e.value),
                              ),
                          ],
                        ),
                        TextButton(
                          onPressed: enabled ? () => toggle(m) : null,
                          child: Text(
                            m['active'] == true ? 'ปิดสิทธิ์' : 'เปิดสิทธิ์',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
