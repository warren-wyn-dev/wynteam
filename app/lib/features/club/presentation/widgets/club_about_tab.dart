import 'package:flutter/material.dart';

import '../../data/club.dart';
import '../../data/club_member.dart';
import '../../data/club_repository.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Screen 7 — About tab. Plain-text sections (Description/Category/
/// Privacy/Created date/Club Rules), with an Owner/Admin-only "แก้ไขกฎ"
/// action. See .wyn/docs/design/wyn-014-club-core.md, Screen 7.
class ClubAboutTab extends StatefulWidget {
  const ClubAboutTab({
    super.key,
    required this.clubRepository,
    required this.club,
    required this.myRole,
    required this.onChanged,
  });

  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onChanged;

  @override
  State<ClubAboutTab> createState() => _ClubAboutTabState();
}

class _ClubAboutTabState extends State<ClubAboutTab> {
  bool _isEditingRules = false;
  bool _isSavingRules = false;
  late final TextEditingController _rulesController;

  bool get _canManage => widget.myRole?.canManageClub ?? false;

  @override
  void initState() {
    super.initState();
    _rulesController = TextEditingController(text: widget.club.rules ?? '');
  }

  @override
  void didUpdateWidget(covariant ClubAboutTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditingRules && oldWidget.club.rules != widget.club.rules) {
      _rulesController.text = widget.club.rules ?? '';
    }
  }

  @override
  void dispose() {
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    setState(() => _isSavingRules = true);
    try {
      await widget.clubRepository.updateRules(
        clubId: widget.club.id,
        rules: _rulesController.text,
      );
      if (!mounted) return;
      setState(() => _isEditingRules = false);
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกกฎไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isSavingRules = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;

    return ListView(
      padding: const EdgeInsets.all(WynSpacing.space4),
      children: [
        _buildSection(
          label: 'คำอธิบาย',
          child: Text(
            (club.description != null && club.description!.isNotEmpty)
                ? club.description!
                : 'ยังไม่มีคำอธิบาย',
          ),
        ),
        _buildSection(
          label: 'หมวดหมู่',
          child: Text(club.category ?? 'ไม่ระบุ'),
        ),
        _buildSection(
          label: 'ความเป็นส่วนตัว',
          child: Row(
            children: [
              Icon(
                club.privacy == ClubPrivacy.private ? Icons.lock_outline : Icons.public,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(club.privacy == ClubPrivacy.private ? 'ส่วนตัว' : 'สาธารณะ'),
            ],
          ),
        ),
        _buildSection(
          label: 'สร้างเมื่อ',
          child: Text(_formatFullDate(club.createdAt)),
        ),
        _buildSection(
          label: 'กฎของ Club',
          child: _isEditingRules ? _buildRulesEditor() : _buildRulesText(club),
        ),
      ],
    );
  }

  Widget _buildRulesText(Club club) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (club.rules != null && club.rules!.isNotEmpty)
              ? club.rules!
              : 'Club นี้ยังไม่มีกฎ',
        ),
        if (_canManage) ...[
          const SizedBox(height: WynSpacing.space2),
          OutlinedButton(
            onPressed: () => setState(() => _isEditingRules = true),
            child: const Text('แก้ไขกฎ'),
          ),
        ],
      ],
    );
  }

  Widget _buildRulesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _rulesController,
          maxLines: 6,
          maxLength: 2000,
          enabled: !_isSavingRules,
          decoration: const InputDecoration(hintText: 'เขียนกฎของ Club'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSavingRules
                  ? null
                  : () => setState(() {
                        _isEditingRules = false;
                        _rulesController.text = widget.club.rules ?? '';
                      }),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: _isSavingRules ? null : _saveRules,
              child: _isSavingRules
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('บันทึก'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WynSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: WynSpacing.space1),
          child,
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
