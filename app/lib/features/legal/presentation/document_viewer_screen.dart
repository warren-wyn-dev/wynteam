import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../data/platform_document_repository.dart';

/// Generic read-only viewer for any of the 6 platform document types
/// (WYN-046) -- one screen, reused for all 6, per the Design spec's
/// Design Rule #1 ("ห้ามสร้าง 6 หน้าแยก"). Opened from
/// DocumentAcceptanceScreen's 3 document links, or from SettingsScreen's
/// "กฎหมาย" section (all 6). Always loads the *latest* version of
/// [documentType] -- there is no way to view an older version from this
/// screen.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.documentType,
    required this.platformDocumentRepository,
  });

  final PlatformDocumentType documentType;
  final PlatformDocumentRepository platformDocumentRepository;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isLoading = true;
  String? _error;
  PlatformDocument? _document;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final document =
          await widget.platformDocumentRepository.fetchLatest(widget.documentType);
      if (!mounted) return;
      setState(() => _document = document);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดเอกสารไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return Scaffold(
      appBar: AppBar(title: Text(document?.title ?? '')),
      body: _buildBody(document),
    );
  }

  Widget _buildBody(PlatformDocument? document) {
    if (_isLoading) {
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

    if (document == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(WynSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เวอร์ชัน ${document.version} · มีผลตั้งแต่ ${dateLabel(document.effectiveAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: WynSpacing.space4),
          Text(
            document.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
