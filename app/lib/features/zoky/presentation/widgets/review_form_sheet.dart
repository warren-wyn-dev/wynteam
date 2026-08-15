import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../data/review.dart';
import '../../data/zoky_repository.dart';
import 'star_rating.dart';

/// Opens ReviewFormSheet as a modal bottom sheet, same hosting pattern
/// as showPopCommentSheet (WYN-006). Returns true when the sheet's
/// caller should refresh (a review was written/edited/deleted), false
/// when dismissed without any change.
Future<bool> showReviewFormSheet(
  BuildContext context, {
  required ZokyRepository zokyRepository,
  required String orderItemId,
  required String productId,
  Review? existingReview,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ReviewFormSheet(
      zokyRepository: zokyRepository,
      orderItemId: orderItemId,
      productId: productId,
      existingReview: existingReview,
    ),
  );
  return result ?? false;
}

/// Screen: ReviewFormSheet (ZOKY-004) -- star rating (required) +
/// optional text, used for both writing a new review and editing an
/// existing one (pre-filled via [existingReview]). See
/// .wyn/docs/design/zoky-004-review.md.
class ReviewFormSheet extends StatefulWidget {
  const ReviewFormSheet({
    super.key,
    required this.zokyRepository,
    required this.orderItemId,
    required this.productId,
    this.existingReview,
  });

  final ZokyRepository zokyRepository;
  final String orderItemId;
  final String productId;
  final Review? existingReview;

  @override
  State<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<ReviewFormSheet> {
  late int _rating = widget.existingReview?.rating ?? 0;
  late final _textController =
      TextEditingController(text: widget.existingReview?.textContent ?? '');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingReview != null;

  Future<void> _submit() async {
    if (_rating == 0) return;

    setState(() => _isSubmitting = true);
    try {
      final text = _textController.text.trim();
      if (_isEditing) {
        await widget.zokyRepository.editReview(
          reviewId: widget.existingReview!.id,
          rating: _rating,
          textContent: text.isEmpty ? null : text,
        );
      } else {
        await widget.zokyRepository.addReview(
          orderItemId: widget.orderItemId,
          productId: widget.productId,
          rating: _rating,
          textContent: text.isEmpty ? null : text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกรีวิวแล้ว')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกรีวิวไม่สำเร็จ ลองใหม่อีกครั้ง')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDeletePost(context, itemLabel: 'รีวิว');
    if (!confirmed) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.zokyRepository.deleteReview(widget.existingReview!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ลบรีวิวแล้ว')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ลบรีวิวไม่สำเร็จ ลองใหม่อีกครั้ง')));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'แก้ไขรีวิว' : 'เขียนรีวิว',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Center(
              child: StarRatingInput(
                rating: _rating,
                onChanged: (value) {
                  if (!_isSubmitting) setState(() => _rating = value);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              enabled: !_isSubmitting,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'เล่าประสบการณ์การใช้สินค้านี้ (ไม่บังคับ)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_rating > 0 && !_isSubmitting) ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'บันทึกการแก้ไข' : 'ส่งรีวิว'),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('ลบรีวิว'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
