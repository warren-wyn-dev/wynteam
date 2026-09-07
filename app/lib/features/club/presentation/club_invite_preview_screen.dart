import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/empty_state_block.dart';
import '../../auth/presentation/widgets/guest_gate.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/club_invite_link.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import 'club_page.dart';

/// WYN-130 -- opened from a `/club-invite/:code` deep link
/// (`DeepLinkService`). Never opens `ClubPage` directly: the link's own
/// status (valid/expired/revoked/exhausted/not_found) has to be checked
/// first, since a bare "go to this club_id" would either 404 on a
/// revoked/expired link or (worse) silently skip the whole point of this
/// screen -- confirming the person actually wants to join before
/// `redeem_club_invite_link()` runs. See
/// .wyn/docs/design/wyn-130-club-invite-link.md.
class ClubInvitePreviewScreen extends StatefulWidget {
  const ClubInvitePreviewScreen({
    super.key,
    required this.code,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final String code;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<ClubInvitePreviewScreen> createState() => _ClubInvitePreviewScreenState();
}

class _ClubInvitePreviewScreenState extends State<ClubInvitePreviewScreen> {
  ClubInvitePreview? _preview;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _joinError = null;
    });
    try {
      final preview = await widget.clubRepository.previewInviteLink(widget.code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (_) {
      if (!mounted) return;
      setState(() => _preview = const ClubInvitePreview(status: ClubInviteLinkStatus.notFound));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _join() async {
    // WYN-072/119: a guest (Anonymous Sign-In) needs a real account
    // before this action means anything -- same gate every other real
    // action in this app already uses, no new mechanism here.
    if (!await requireRealAccount(context) || !mounted) return;

    setState(() {
      _isJoining = true;
      _joinError = null;
    });
    try {
      final clubId = await widget.clubRepository.redeemInviteLink(widget.code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ClubPage(
            clubRepository: widget.clubRepository,
            clubPostRepository: widget.clubPostRepository,
            clubId: clubId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _joinError = 'เข้าร่วมไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
    );
  }

  Widget _buildBody() {
    final preview = _preview;
    if (preview == null || preview.status != ClubInviteLinkStatus.valid) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyStateBlock(
              icon: Icons.link_off,
              title: 'ลิงก์เชิญใช้งานไม่ได้',
              subtitle: _statusMessage(preview?.status ?? ClubInviteLinkStatus.notFound),
            ),
            const SizedBox(height: WynSpacing.space4),
            TextButton(onPressed: _goHome, child: const Text('ไปที่ WYN')),
          ],
        ),
      );
    }

    final isPrivate = preview.clubPrivacy == 'private';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarCircle(
            imageUrl: preview.clubIconUrl,
            fallbackText: preview.clubName ?? '',
            radius: 48,
          ),
          const SizedBox(height: WynSpacing.space4),
          Text(
            preview.clubName ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: WynSpacing.space2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isPrivate ? Icons.lock_outline : Icons.public, size: 16),
              const SizedBox(width: 6),
              Text(isPrivate ? 'Private Club' : 'Public Club'),
            ],
          ),
          const SizedBox(height: WynSpacing.space6),
          if (_joinError != null) ...[
            Text(
              _joinError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: WynSpacing.space3),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isJoining ? null : _join,
              child: _isJoining
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('เข้าร่วม'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusMessage(ClubInviteLinkStatus status) => switch (status) {
        ClubInviteLinkStatus.expired => 'ลิงก์เชิญนี้หมดอายุแล้ว',
        ClubInviteLinkStatus.revoked => 'ลิงก์เชิญนี้ถูกเพิกถอนแล้ว',
        ClubInviteLinkStatus.exhausted => 'ลิงก์เชิญนี้ถูกใช้งานครบจำนวนแล้ว',
        ClubInviteLinkStatus.notFound => 'ไม่พบลิงก์เชิญนี้',
        ClubInviteLinkStatus.valid => '',
      };
}
