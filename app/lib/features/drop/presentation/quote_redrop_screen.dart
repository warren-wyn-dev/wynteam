import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/drop.dart';
import '../data/drop_repository.dart';

/// Screen 2 (WYN-034) -- write a comment to go with a ReDrop. See
/// .wyn/docs/design/wyn-034-redrop.md, Screen 2.
///
/// The original Drop is shown read-only below the text field, exactly
/// as passed in -- the caller already has the full [Drop] in hand
/// (this screen is only ever opened from a card/detail screen already
/// displaying it), so there is no fetch here, unlike WYN-033's
/// shared-content preview which resolves lazily because it doesn't
/// have the object up front.
class QuoteRedropScreen extends StatefulWidget {
  const QuoteRedropScreen({
    super.key,
    required this.dropRepository,
    required this.drop,
  });

  final DropRepository dropRepository;
  final Drop drop;

  @override
  State<QuoteRedropScreen> createState() => _QuoteRedropScreenState();
}

class _QuoteRedropScreenState extends State<QuoteRedropScreen> {
  static const _maxLength = 500;

  final _textController = TextEditingController();
  bool _isPosting = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canPost =>
      !_isPosting && _textController.text.trim().isNotEmpty;

  Future<void> _post() async {
    if (!_canPost) return;
    setState(() {
      _isPosting = true;
      _error = null;
    });
    try {
      await widget.dropRepository.quoteRedrop(
        dropId: widget.drop.id,
        quoteText: _textController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPosting = false;
        _error = 'โพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quote ReDrop'),
        actions: [
          TextButton(
            onPressed: _canPost ? _post : null,
            child: _isPosting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('โพสต์'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WynSpacing.space4),
        children: [
          TextField(
            controller: _textController,
            maxLength: _maxLength,
            maxLines: 6,
            minLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'เพิ่มความคิดเห็น...',
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: WynSpacing.space2),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          _OriginalDropPreview(drop: widget.drop),
        ],
      ),
    );
  }
}

/// Read-only preview of the Drop being quoted -- not removable, not
/// tappable (unlike WYN-033's preview cards) since the user is
/// currently composing this post, not reading a finished message.
class _OriginalDropPreview extends StatelessWidget {
  const _OriginalDropPreview({required this.drop});

  final Drop drop;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(WynSpacing.space2),
            child: Row(
              children: [
                AvatarCircle(
                  imageUrl: drop.authorAvatarUrl,
                  fallbackText: drop.authorUsername,
                  radius: 14,
                ),
                const SizedBox(width: WynSpacing.space2),
                Text(
                  drop.authorNameOrUsername,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(drop.imageUrl, fit: BoxFit.cover),
          ),
          if (drop.caption != null && drop.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(WynSpacing.space2),
              child: Text(drop.caption!),
            ),
        ],
      ),
    );
  }
}
