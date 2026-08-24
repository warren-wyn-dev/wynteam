import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/platform_document_repository.dart';
import 'document_viewer_screen.dart';

/// Screen: `DocumentAcceptanceScreen` (WYN-046). Forces acceptance of
/// the 3 mandatory documents (ToS/Privacy/Community Guidelines) before
/// the app can be used at all -- rendered *as* AuthGate's own route
/// (like WelcomeScreen/UsernameSetupScreen/AccountRestrictedScreen),
/// not pushed on top of it, and positioned after the moderation-status
/// check and before the username check (see AuthGate's own comment for
/// why). No AppBar and no way to skip/dismiss -- mirrors
/// WelcomeScreen/AccountRestrictedScreen's "forced decision point"
/// shape. See .wyn/docs/design/wyn-046-platform-documents-acceptance.md.
class DocumentAcceptanceScreen extends StatefulWidget {
  const DocumentAcceptanceScreen({
    super.key,
    required this.platformDocumentRepository,
    required this.onAccepted,
  });

  final PlatformDocumentRepository platformDocumentRepository;

  /// Called after acceptMandatoryDocuments() succeeds. AuthGate owns
  /// what happens next (re-checking hasAcceptedMandatoryDocuments and
  /// rendering the next screen as its own child) -- this screen must
  /// not navigate on its own, same "rendered as AuthGate's route, not
  /// pushed on top of it" reasoning as UsernameSetupScreen.onUsernameSet.
  final VoidCallback onAccepted;

  @override
  State<DocumentAcceptanceScreen> createState() =>
      _DocumentAcceptanceScreenState();
}

class _DocumentAcceptanceScreenState extends State<DocumentAcceptanceScreen> {
  bool _isChecked = false;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_isChecked || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.platformDocumentRepository.acceptMandatoryDocuments();
      widget.onAccepted();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยอมรับไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openDocument(PlatformDocumentType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          documentType: type,
          platformDocumentRepository: widget.platformDocumentRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _isChecked && !_isSubmitting;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text(
                'ก่อนเริ่มใช้งาน WYN',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: WynSpacing.space3),
              Text(
                'กรุณาอ่านและยอมรับเอกสารต่อไปนี้ก่อนใช้งาน WYN',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: WynSpacing.space4),
              TextButton(
                onPressed: () =>
                    _openDocument(PlatformDocumentType.termsOfService),
                child: const Text(
                  'ข้อกำหนดการใช้งาน',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openDocument(PlatformDocumentType.privacyPolicy),
                child: const Text(
                  'นโยบายความเป็นส่วนตัว',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openDocument(PlatformDocumentType.communityGuidelines),
                child: const Text(
                  'แนวทางชุมชน',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
              const Spacer(flex: 1),
              CheckboxListTile(
                value: _isChecked,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _isChecked = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'ฉันได้อ่านและยอมรับข้อกำหนดการใช้งาน นโยบายความเป็นส่วนตัว '
                  'และแนวทางชุมชนของ WYN',
                ),
              ),
              const SizedBox(height: WynSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  label: canSubmit
                      ? 'ยอมรับและดำเนินการต่อ'
                      : 'ยอมรับและดำเนินการต่อ ปิดใช้งานจนกว่าจะติ๊กยอมรับ',
                  excludeSemantics: true,
                  child: FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ยอมรับและดำเนินการต่อ'),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
