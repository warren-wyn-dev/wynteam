import 'package:flutter/material.dart';

/// Shared by FeedScreen and PostDetailScreen so the confirmation copy
/// can't drift between the two places a post can be deleted from.
Future<bool> confirmDeletePost(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('ลบโพสต์นี้?'),
      content: const Text('ลบแล้วไม่สามารถกู้คืนได้'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('ลบ'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
